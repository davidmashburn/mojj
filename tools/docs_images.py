"""Refresh GitHub's inline illustrations from the adjacent Markdown examples."""
import argparse
import re
from html import escape
from pathlib import Path

from render_docs import Language, code_fragments
from mojj_prompt import Role

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "docs/highlights"
EXAMPLE = re.compile(
    r"<!-- mojj-example: ([\w-]+) -->\n(.*?)^```(\w+)\n(.*?)\n```\n(.*?)<!-- /mojj-example -->",
    re.MULTILINE | re.DOTALL,
)
COMPARISON = re.compile(
    r"((?:^\|[^\n]*\|\n)+)\n<!-- mojj-comparison: ([\w-]+) -->\n(.*?)<!-- /mojj-comparison -->",
    re.MULTILINE | re.DOTALL,
)
CSS = """
svg { background: #f6f8fa; color: #24292f; }
text { fill: currentColor; font: 15px ui-monospace, SFMono-Regular, Consolas, monospace; }
.verb { fill: #006679; font-weight: bold; }
.noun { fill: #176337; }
.modifier { fill: #922477; text-decoration: underline; }
@media (prefers-color-scheme: dark) {
  svg { background: #171c22; color: #e6edf3; }
  .verb { fill: #80def0; } .noun { fill: #9be4aa; } .modifier { fill: #f2b4e4; }
}
""".strip()


def styled_lines(source, language):
    """Split already-classified fragments so multiline literals retain their roles."""
    lines = [[]]
    for style, text in code_fragments(source, language):
        for index, part in enumerate(text.split("\n")):
            if index:
                lines.append([])
            if part:
                lines[-1].append((style, part))
    return lines


def comparison_lines(table):
    rows = [
        [cell.strip().replace(r"\|", "|") for cell in re.split(r"(?<!\\)\|", row[1:-1])]
        for row in table.splitlines()
    ]
    headings = rows[0]
    columns = [i for i, h in enumerate(headings) if h in {"Mojj words", "Mojj symbols", "J"}]
    lines = []
    for row in rows[2:]:
        if columns:
            if columns[0] > 0 and headings[0] in {"Task", "Intent", "Task and result", "Step"}:
                lines.append([(Role.PLAIN.value, row[0].replace("`", ""))])
            examples = [(headings[i], row[i]) for i in columns]
        elif row[0] in {"Mojj words", "Mojj symbols", "J"}:
            examples = [(row[0], row[1])]
        else:
            continue
        for label, cell in examples:
            for line in re.findall(r"`([^`]+)`", cell):
                lang = Language.MOJO if line.startswith("jj[") else Language.MOJJ
                lines.append([(Role.PLAIN.value, f"{label:14}"), *code_fragments(line, lang.value)])
        lines.append([])
    if not lines:
        raise ValueError("Color comparison has no Mojj or J cells")
    return lines[:-1]


def svg(title, lines):
    width = max(sum(len(s) for _, s in row) for row in lines) * 9.2 + 24
    height = 22 * len(lines) + 14
    content = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{int(width + 1)}" height="{height}" '
        f'viewBox="0 0 {int(width + 1)} {height}" role="img">',
        f'<title>{escape(title)}</title>', f'<style>{CSS}</style>',
    ]
    for i, row in enumerate(lines):
        spans = []
        for style, value in row:
            role = Role(style)
            token = escape(value, quote=False)
            if role != Role.PLAIN:
                token = f'<tspan class="{role.name.lower()}">{token}</tspan>'
            spans.append(token)
        content.append(f'<text x="12" y="{22 * i + 22}" xml:space="preserve">{"".join(spans)}</text>')
    return "\n".join([*content, "</svg>", ""])


def illustrations():
    for path in [ROOT / "README.md", *sorted((ROOT / "docs").glob("*.md"))]:
        source = path.read_text()
        examples = EXAMPLE.findall(source)
        comparisons = COMPARISON.findall(source)
        for marker, matches in [("example", examples), ("comparison", comparisons)]:
            if (source.count(f"<!-- mojj-{marker}:") != len(matches)
                    or source.count(f"<!-- /mojj-{marker} -->") != len(matches)):
                raise ValueError(f"Malformed {marker} wrapper in {path.name}")
        for name, preview, lang, code, _ in examples:
            yield name, image_title(path, name, preview), styled_lines(code, lang)
        for table, name, preview in comparisons:
            yield name, image_title(path, name, preview), comparison_lines(table)


def image_title(page, name, preview):
    images = re.findall(r"!\[([^\]]+)\]\(([^)]+)\)", preview)
    if len(images) == 1:
        title, target = images[0]
        if (page.parent / target).resolve() == ASSETS / f"{name}.svg":
            return title
    raise ValueError(f"{page.name} must link its {name} example to the matching illustration")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Report stale illustrations without writing")
    args = parser.parse_args()
    ASSETS.mkdir(exist_ok=True)
    expected = set()
    for name, title, lines in illustrations():
        path = ASSETS / f"{name}.svg"
        if path in expected:
            raise ValueError(f"Duplicate illustration {name}")
        expected.add(path)
        rendered = svg(title, lines)
        if args.check:
            if not path.exists() or path.read_text() != rendered:
                raise SystemExit(f"Refresh {path.name} with pixi run docs-images")
        else:
            path.write_text(rendered)
    for path in sorted(set(ASSETS.glob("*.svg")) - expected):
        raise SystemExit(f"Unreferenced illustration {path.name}")


if __name__ == "__main__":
    main()
