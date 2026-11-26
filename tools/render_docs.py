#!/usr/bin/env python3
"""Build offline HTML with Pandoc on PATH: python3 tools/render_docs.py.

The default destination is build/docs/README.html and build/docs/docs/*.html.
Run within the Pixi environment for the prompt's prompt-toolkit dependency.
"""

import argparse
import base64
import html
import json
import mimetypes
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from enum import Enum
from functools import lru_cache
from itertools import groupby
from operator import itemgetter
from urllib.parse import quote, unquote, urlsplit, urlunsplit

from pygments.lexers import get_lexer_by_name
from pygments.token import Comment, Keyword, Name, Number, Operator, String
from pygments.util import ClassNotFound

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
from mojj_prompt import Role, highlight


class Language(Enum):
    MOJO = "mojo"
    MOJJ = "mojj"
    TEXT = "text"
    J = "j"


# Match host strings and comments together, so a phrase in a comment or in an
# unrelated string cannot be mistaken for an embedded jj/Expr literal.
HOST_TOKEN = re.compile(
    r'''\#[^\n]*|"""(?:\\.|(?!""")[\s\S])*"""|'''
    r"'''(?:\\.|(?!''')[\s\S])*'''|"
    r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*' ''',
    re.VERBOSE,
)
PHRASE_PREFIX = re.compile(r"\b(?:jj|Expr)\s*\[\s*$")
PROMPT = re.compile(r"^(?:mojj>|\.\.\.)[ \t]?")
ESCAPE = re.compile(r"\\(?:[\\'\"abfnrtv]|x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4}|U[0-9a-fA-F]{8})|[\s\S]")
ESCAPES = dict(zip("\\'\"abfnrtv", "\\'\"\a\b\f\n\r\t\v"))
# GitHub preserves emphasis in code but strips author-defined CSS. Keep the
# input language on blocks so the offline reader can restore fenced Markdown.
ROLE_TAG = {Role.VERB: "strong", Role.NOUN: "em", Role.MODIFIER: "ins"}
BLOCK = re.compile(r'^<pre data-mojj="(\w+)"><code>(.*?)</code></pre>$', re.M | re.S)
CELL = re.compile(r'<code data-mojj>([^\n]*?)</code>')
ROLE_MARKUP = re.compile(r"</?(?:strong|em|ins)>")
# Inline HTML in a GFM table still undergoes Markdown parsing (e.g. jj["v"](x)
# can become a link). Character references keep the visible source literal.
TABLE_ESCAPES = str.maketrans({c: f"&#{ord(c)};" for c in r"[]*_`~\|$"})
MARKDOWN_EXAMPLE = re.compile(
    r"^```(?P<lang>[^\n`]*)\n(?P<code>.*?)^```[ \t]*$|(?P<table>(?:^\|[^\n]*\|(?:\n|$))+)",
    re.M | re.S,
)
PHRASE_COLUMNS = frozenset({"word", "words", "symbol", "symbols", "phrase", "expression", "mojj words", "mojj symbols", "in this sentence"})
COMPARISON_ROWS = frozenset({"mojj words", "mojj symbols", "j"})


def _literal_fragments(source):
    """Lex decoded literal characters, but return their exact host spelling."""
    decoded, spellings = [], []
    for match in ESCAPE.finditer(source):
        spelling = match[0]
        char = spelling
        if len(spelling) > 1 and spelling[0] == "\\":
            char = ESCAPES.get(spelling[1])
            if char is None:
                char = chr(int(spelling[2:], 16))
        decoded.append(char)
        spellings.append(spelling)
    fragments, offset = [], 0
    for style, token in highlight("".join(decoded)):
        fragments.append((style, "".join(spellings[offset:offset + len(token)])))
        offset += len(token)
    return fragments


def code_fragments(source: str, language: str) -> list[tuple[str, str]]:
    """Return prompt Role.value styles without changing the joined source.

    ``mojj`` (and supported ``j`` samples) color whole sentences; ``mojo``
    colors only literal phrases in jj[...] and Expr[...]. ``text`` recognizes
    Mojj transcript prompts and leaves result lines uncolored. Other languages
    remain plain. No compiler or evaluation is involved.
    """
    try:
        mode = Language(language.lower())
    except ValueError:
        return [(Role.PLAIN.value, source)]
    if mode in (Language.MOJJ, Language.J):
        return highlight(source)
    if mode is Language.TEXT:
        fragments = []
        for line in source.splitlines(keepends=True):
            prompt = PROMPT.match(line)
            if prompt:
                fragments.append((Role.PLAIN.value, prompt[0]))
                fragments.extend(highlight(line[prompt.end():]))
            else:
                fragments.append((Role.PLAIN.value, line))
        return fragments
    fragments, offset = [], 0
    for token in HOST_TOKEN.finditer(source):
        literal = token[0]
        if literal.startswith("#") or not PHRASE_PREFIX.search(source[:token.start()]):
            continue
        delimiter = literal[:3] if literal.startswith(('"""', "'''")) else literal[0]
        start, end = token.start() + len(delimiter), token.end() - len(delimiter)
        fragments.append((Role.PLAIN.value, source[offset:start]))
        fragments.extend(_literal_fragments(source[start:end]))
        offset = end
    fragments.append((Role.PLAIN.value, source[offset:]))
    return fragments


MOJJ_MODES = frozenset(item.value for item in Language)
HOST_LABELS = {
    "numpy": "python", "python": "python", "matlab": "matlab", "numojo": "mojo",
    "mojo": "mojo", "mojj entry point": "mojo", "wolfram language": "mathematica",
}
HOST_STYLES = {
    Comment: "comment", Keyword: "keyword", String: "string", Number: "number",
    Name.Builtin: "builtin", Name: "name", Operator: "operator",
}


@lru_cache
def host_lexer(language):
    if language in {Language.MOJJ.value, Language.J.value, Language.TEXT.value}:
        return None
    try:
        return get_lexer_by_name(language)
    except ClassNotFound:
        return None


def colored_code(source, language):
    """Color the original characters; embedded Mojj roles take priority over Mojo strings."""
    styles = [("", 0)] * len(source)
    lexer = host_lexer(language)
    if lexer is not None:
        for start, token, text in lexer.get_tokens_unprocessed(source):
            for category, style in HOST_STYLES.items():
                if token in category:
                    styles[start:start + len(text)] = [("host-" + style, start)] * len(text)
                    break
    offset = 0
    for role, text in code_fragments(source, language):
        if role:
            styles[offset:offset + len(text)] = [("mojj-" + Role(role).name.lower(), offset)] * len(text)
        offset += len(text)

    parts = []
    for (style, _start), run in groupby(zip(styles, source), key=itemgetter(0)):
        text = html.escape("".join(char for _, char in run), quote=False)
        parts.append(f'<span class="{style}">{text}</span>' if style else text)
    return "".join(parts)


def reader_markdown(source):
    """Recover ordinary fenced code and table code spans, preserving source spelling."""
    def plain(markup):
        return html.unescape(ROLE_MARKUP.sub("", markup))

    def block(match):
        return f"```{match[1]}\n{plain(match[2])}\n```"

    def cell(match):
        code = plain(match[1]).replace("|", r"\|")
        return f"`{code}`"

    return BLOCK.sub(block, CELL.sub(cell, source))


def github_code(code, language, *, inline=False):
    fragments = code_fragments(code, language)
    if not any(style for style, _ in fragments):
        return None
    parts = []
    for style, token in fragments:
        token = html.escape(token, quote=False)
        if inline:
            token = token.translate(TABLE_ESCAPES)
        tag = ROLE_TAG.get(Role(style))
        parts.append(f"<{tag}>{token}</{tag}>" if tag else token)
    content = "".join(parts)
    if inline:
        return f"<code data-mojj>{content}</code>"
    return f'<pre data-mojj="{language}"><code>{content}</code></pre>'


def phrase_cell(headers, label, index):
    if headers[index] in PHRASE_COLUMNS:
        return True
    if headers[index] == "j" and {"mojj words", "mojj symbols"}.intersection(headers):
        return True
    return index > 0 and (
        (headers[0] in {"environment", "notation"} and label in COMPARISON_ROWS)
        or (headers[0] == "surface" and label in {"arithmetic", "modifiers"})
    )


def github_markdown(source):
    """Refresh role markup from its text, also accepting ordinary Markdown examples."""
    def format_span(span):
        code = span[1].replace(r"\|", "|")
        return (github_code(code, Language.MOJO.value, inline=True)
                or github_code(code, Language.MOJJ.value, inline=True) or span[0])

    def format_example(match):
        if match["table"] is None:
            code = match["code"].removesuffix("\n")
            return github_code(code, match["lang"]) or match[0]
        rows = match["table"].splitlines(keepends=True)
        delimiter = re.compile(r"(?<!\\)\|")
        headers = [cell.strip().lower() for cell in delimiter.split(rows[0])[1:-1]]
        for i in range(2, len(rows)):
            cells = delimiter.split(rows[i])
            label = cells[1].strip().lower()
            for j, cell in enumerate(cells[1:-1]):
                if j < len(headers) and phrase_cell(headers, label, j):
                    cells[j + 1] = re.sub(r"`([^`]+)`", format_span, cell)
            rows[i] = "|".join(cells)
        return "".join(rows)

    return MARKDOWN_EXAMPLE.sub(format_example, reader_markdown(source))


def plain_text(value):
    if isinstance(value, dict):
        kind = value.get("t")
        if kind in ("Str", "Code"):
            return value["c"] if kind == "Str" else value["c"][1]
        if kind in ("Space", "SoftBreak", "LineBreak"):
            return " "
        return plain_text(value.get("c", []))
    if isinstance(value, list):
        return "".join(plain_text(item) for item in value)
    return ""


def _table_languages(table):
    """Select code cells by semantic headers, not by their punctuation."""
    head, bodies, foot = table[3:6]
    headers = [plain_text(cell[4]).strip().lower() for cell in head[1][0][1]] if head[1] else []
    rows = [row for body in bodies for row in body[2] + body[3]] + foot[1]
    for row in rows:
        cells = row[1]
        label = plain_text(cells[0][4]).strip().lower() if cells else ""
        for index, cell in enumerate(cells):
            if index < len(headers) and phrase_cell(headers, label, index):
                yield cell, Language.MOJJ.value
            elif index < len(headers):
                heading = label if index and headers[0] in {"environment", "notation"} else headers[index]
                language = HOST_LABELS.get(heading.split(" (", 1)[0])
                if language:
                    yield cell, language


def transform(document, source, destination, outputs):
    outputs = {original.resolve(): output for original, output in outputs.items()}

    def link(target):
        parts = urlsplit(target)
        if parts.scheme or parts.netloc or not parts.path:
            return target
        original = (source.parent / unquote(parts.path)).resolve()
        mapped = outputs.get(original, original)
        path = quote(Path(os.path.relpath(mapped, destination.parent)).as_posix())
        return urlunsplit(("", "", path, parts.query, parts.fragment))

    def walk(value, language=None):
        if isinstance(value, list):
            return [walk(item, language) for item in value]
        if not isinstance(value, dict):
            return value
        kind, content = value.get("t"), value.get("c")
        if kind == "Table":
            for cell, mode in _table_languages(content):
                cell[4] = walk(cell[4], mode)
            value["c"] = walk(content)
            return {"t": "Div", "c": [["", ["table-scroll"], [["tabindex", "0"], ["aria-label", "Scrollable table"]]], [value]]}
        if kind in ("Code", "CodeBlock"):
            attributes, code = content
            mode = language
            if kind == "CodeBlock":
                mode = attributes[1][0] if attributes[1] else None
            elif mode in (None, Language.MOJJ.value) and any(
                style for style, _ in code_fragments(code, Language.MOJO.value)
            ):
                mode = Language.MOJO.value
            if mode and (mode in MOJJ_MODES or host_lexer(mode)):
                rendered = colored_code(code, mode)
                css = "mojj-code" if mode in MOJJ_MODES else "host-code"
                if kind == "CodeBlock":
                    rendered = f'<pre class="{css}"><code class="language-{html.escape(mode, quote=True)}">{rendered}</code></pre>'
                    return {"t": "RawBlock", "c": ["html", rendered]}
                return {"t": "RawInline", "c": ["html", f'<code class="{css}">{rendered}</code>']}
            return value
        if kind == "Link":
            content[2][0] = link(content[2][0])
        if kind == "Image":
            target = urlsplit(content[2][0])
            if target.scheme or target.netloc:
                if target.scheme != "data":
                    raise ValueError(f"Offline reader cannot embed remote image: {content[2][0]}")
            else:
                image = (source.parent / unquote(target.path)).resolve()
                mime = mimetypes.guess_type(image.name)[0] or "application/octet-stream"
                content[2][0] = f"data:{mime};base64,{base64.b64encode(image.read_bytes()).decode()}"
        if content is not None:
            value["c"] = walk(content, language)
        return value

    document["blocks"] = walk(document["blocks"])
    return document


CSS = """
:root { color-scheme: light dark; --paper:#fff; --ink:#24292f; --muted:#57606a;
  --line:#d0d7de; --panel:#f6f8fa; --link:#075cad; --noun:#176b31;
  --verb:#006b78; --modifier:#953088; }
@media (prefers-color-scheme: dark) {
  :root { --paper:#111820; --ink:#e6edf3; --muted:#b0bdc9; --line:#495768;
    --panel:#1b2632; --link:#8cc8ff; --noun:#86dc96; --verb:#6ee7f2;
    --modifier:#efa4ef; }
}
* { box-sizing:border-box; }
body { margin:0; padding:2rem clamp(1rem,4vw,3rem) 4rem; color:var(--ink);
  background:var(--paper); font:17px/1.65 system-ui,-apple-system,sans-serif; }
body > header, main { max-width:76rem; margin:auto; }
body > header { border-bottom:1px solid var(--line); padding-bottom:1rem; }
nav { display:flex; flex-wrap:wrap; gap:.35rem 1rem; font-size:.9rem; }
a { color:var(--link); text-underline-offset:.16em; }
a[aria-current=page] { font-weight:700; }
main { padding-top:1rem; }
h1,h2,h3 { line-height:1.25; margin:1.6em 0 .6em; }
h1 { font-size:clamp(2rem,5vw,3rem); }
p,ul,ol,blockquote { max-width:80ch; }
code,pre { font-family:ui-monospace,SFMono-Regular,Consolas,monospace; font-size:.9em; }
code { background:var(--panel); border-radius:.2rem; padding:.1rem .25rem; }
pre { padding:1rem; background:var(--panel); border:1px solid var(--line);
  border-radius:.4rem; overflow:auto; line-height:1.6; tab-size:4; }
pre code { padding:0; border:0; font-size:1em; background:none; }
.host-keyword, .host-operator { color:var(--modifier); }
.host-keyword { font-weight:700; }
.host-string { color:var(--noun); }
.host-number, .host-builtin { color:var(--link); }
.host-name { color:var(--verb); }
.host-comment { color:var(--muted); font-style:italic; }
.mojj-noun { color:var(--noun); font-style:italic; }
.mojj-verb { color:var(--verb); font-weight:700; }
.mojj-modifier { color:var(--modifier); text-decoration:underline; text-underline-offset:.2em; }
.legend { color:var(--muted); font-size:.85rem; margin:.8rem 0 0; }
.table-scroll { max-width:100%; overflow:auto; margin:1.4rem 0; }
table { border-collapse:collapse; min-width:100%; font-size:.9rem; }
th,td { text-align:left; padding:.65rem .8rem; border:1px solid var(--line); vertical-align:top; }
th { background:var(--panel); }
td code { white-space:pre-wrap; }
td code.mojj-code { white-space:pre; }
blockquote { border-left:3px solid var(--line); padding-left:1rem; color:var(--muted); }
img { max-width:100%; height:auto; }
math { font-size:1.1em; }
math[display=block] { overflow-x:auto; padding:.8rem 0; }
:focus-visible { outline:3px solid var(--link); outline-offset:3px; }
@media print { body { padding:0; } nav,.legend { display:none; } pre,.table-scroll { overflow:visible; } }
"""


def pandoc(arguments, text):
    return subprocess.run(["pandoc", *arguments], input=text, text=True,
                          capture_output=True, check=True).stdout


def render(source, destination, outputs):
    parsed = json.loads(pandoc(["--from=gfm+tex_math_dollars", "--to=json"], reader_markdown(source.read_text())))
    title = next((plain_text(block["c"][2]) for block in parsed["blocks"] if block["t"] == "Header" and block["c"][0] == 1), source.stem)
    parsed = transform(parsed, source, destination, outputs)
    body = pandoc(["--from=json", "--to=html5", "--mathml", "--syntax-highlighting=none"], json.dumps(parsed))
    links = []
    for original, output in outputs.items():
        label = "Home" if original.name == "README.md" else original.stem.title()
        current = ' aria-current="page"' if original == source else ""
        href = quote(Path(os.path.relpath(output, destination.parent)).as_posix())
        links.append(f'<a href="{html.escape(href)}"{current}>{html.escape(label)}</a>')
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} · Mojj</title><style>{CSS}</style></head>
<body><header><nav aria-label="Documentation">{' '.join(links)}</nav>
<p class="legend">Mojj: <span class="mojj-verb">verbs</span> · <span class="mojj-noun">nouns</span> · <span class="mojj-modifier">modifiers</span>. Host code and results retain their source text.</p></header>
<main>{body}</main></body></html>
''')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build" / "docs")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--format", action="store_true", help="Refresh selectable GitHub role markup")
    modes.add_argument("--check", action="store_true", help="Report stale GitHub role markup")
    args = parser.parse_args()
    sources = [ROOT / "README.md", *sorted((ROOT / "docs").glob("*.md"))]
    if args.format or args.check:
        for path in sources:
            source = path.read_text()
            formatted = github_markdown(source)
            if formatted != source:
                if args.check:
                    parser.exit(1, f"Refresh {path.name} with pixi run docs-format\n")
                path.write_text(formatted)
        return
    if not shutil.which("pandoc"):
        parser.error("pandoc must be installed and available on PATH")
    outputs = {source.resolve(): args.output.resolve() / source.relative_to(ROOT).with_suffix(".html") for source in sources}
    try:
        for source, destination in outputs.items():
            render(source, destination, outputs)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        parser.exit(1, f"Documentation build failed: {detail}\n")
    print(f"Built {len(outputs)} pages: {outputs[sources[0].resolve()]}")


if __name__ == "__main__":
    main()
