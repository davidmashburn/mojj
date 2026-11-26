"""Focused checks for the offline documentation renderer; no Mojo needed."""

from html.parser import HTMLParser
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from render_docs import Role, code_fragments, github_markdown, pandoc, reader_markdown, render, transform


class CodeText(HTMLParser):
    """Read visible code and semantic spans without depending on a browser."""
    def __init__(self):
        super().__init__()
        self.code = []
        self.current = None
        self.style = ""
        self.links = []
        self.images = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "code":
            self.current = []
            self.code.append(self.current)
        elif tag == "span" and self.current is not None:
            self.style = attrs.get("class", "")
        elif tag == "a":
            self.links.append(attrs.get("href"))
        elif tag == "img":
            self.images.append(attrs.get("src"))

    def handle_endtag(self, tag):
        if tag == "code":
            self.current = None
        elif tag == "span":
            self.style = ""

    def handle_data(self, data):
        if self.current is not None:
            self.current.append((self.style, data))

    @property
    def text(self):
        return ["".join(text for _, text in fragments) for fragments in self.code]


class FragmentTests(unittest.TestCase):
    def check_source(self, source, language):
        fragments = code_fragments(source, language)
        self.assertEqual("".join(text for _, text in fragments), source)
        return fragments

    def test_raw_multiline_and_symbols_share_prompt_roles(self):
        source = 'windows =: (# taps) ]\\ samples\nfiltered =: windows +/ . * (|. taps)'
        fragments = self.check_source(source, "mojj")
        self.assertIn((Role.VERB.value, "|."), fragments)
        self.assertIn((Role.MODIFIER.value, "\\"), fragments)
        self.assertIn((Role.NOUN.value, "windows"), fragments)

    def test_mojo_embeds_phrases_without_coloring_host_or_comments(self):
        source = '''# jj["fake"]\nvar text = 'Expr["fake"]'\nprint(jj["sum rank 1"](values)) # preserve sum\ncomptime F = jj.Expr["sqrt of mean of square"]\nprint(jj["""sum rank 1 (\n    2 2 reshape\n    2 4 6 8\n)"""]())'''
        fragments = self.check_source(source, "mojo")
        styled = [(style, text) for style, text in fragments if style]
        self.assertIn((Role.MODIFIER.value, "rank"), styled)
        self.assertIn((Role.VERB.value, "reshape"), styled)
        self.assertNotIn((Role.NOUN.value, "fake"), styled)
        self.assertTrue(any("# preserve sum" in text for style, text in fragments if not style))

    def test_escaped_host_symbols_keep_their_original_spelling(self):
        source = r'print(jj["+/\"1 |. \\"]())'
        fragments = self.check_source(source, "mojo")
        self.assertIn((Role.MODIFIER.value, '\\"'), fragments)
        self.assertIn((Role.MODIFIER.value, "\\\\"), fragments)
        self.assertIn((Role.VERB.value, "|."), fragments)

    def test_cli_colors_only_input_and_continuations(self):
        source = 'mojj> A =: (2 2 reshape\n... 1 2 3 4)\nmojj> sum rank 1 A\n[3, 7]\nshape [2] [3, 7]'
        fragments = self.check_source(source, "text")
        self.assertIn((Role.PLAIN.value, "[3, 7]\n"), fragments)
        self.assertIn((Role.PLAIN.value, "shape [2] [3, 7]"), fragments)
        self.assertIn((Role.MODIFIER.value, "rank"), fragments)
        self.assertNotIn((Role.NOUN.value, "mojj"), fragments)

    def test_unrecognized_language_is_plain(self):
        source = "sum(xs) # not a Mojj sentence"
        self.assertEqual(self.check_source(source, "python"), [(Role.PLAIN.value, source)])

    def test_github_emphasis_round_trips_source(self):
        source = ('''```text
mojj> sum rank 1 A
[3, 12]
```

| NumPy | Mojj words | Mojj symbols | J |
| --- | --- | --- | --- |
| `np.flip(A)` | `jj["reverse"](A)` | `jj["\\|."](A)` | `\\|. A` |
''')
        formatted = github_markdown(source)
        self.assertIn("<strong>sum</strong> <ins>rank</ins> <em>1</em> <em>A</em>", formatted)
        self.assertIn("\n[3, 12]</code></pre>", formatted)
        self.assertIn('jj&#91;"<strong>reverse</strong>"&#93;(A)', formatted)
        self.assertIn("`np.flip(A)`", formatted)
        self.assertEqual(reader_markdown(formatted), source)
        self.assertEqual(github_markdown(formatted), formatted)


@unittest.skipUnless(shutil.which("pandoc"), "Pandoc must be on PATH")
class PandocTests(unittest.TestCase):
    def parsed(self, markdown):
        ast = json.loads(pandoc(["-f", "gfm+tex_math_dollars", "-t", "json"], markdown))
        ast = transform(ast, ROOT / "docs" / "sample.md", ROOT / "build" / "docs" / "docs" / "sample.html", {})
        result = pandoc(["-f", "json", "-t", "html5", "--mathml", "--syntax-highlighting=none"], json.dumps(ast))
        parsed = CodeText()
        parsed.feed(result)
        return result, parsed

    def test_horizontal_and_vertical_tables_and_gfm_pipes(self):
        result, parsed = self.parsed('''| NumPy | Mojj words | Mojj symbols | J |
| --- | --- | --- | --- |
| `np.flip(taps)` | `reverse taps` | `\\|. taps` | `\\|. taps` |

| Environment | Calculation |
| --- | --- |
| NumPy | `np.sum(x)` |
| Mojj words | `sum x` |
| J | `+/ x` |
''')
        self.assertEqual(parsed.text, ["np.flip(taps)", "reverse taps", "|. taps", "|. taps", "np.sum(x)", "sum x", "+/ x"])
        self.assertIn(("host-name", "np"), parsed.code[0])
        self.assertIn(("host-name", "np"), parsed.code[4])
        self.assertIn(("mojj-verb", "reverse"), parsed.code[1])
        self.assertIn(("mojj-verb", "|."), parsed.code[2])
        self.assertIn(("mojj-modifier", "/"), parsed.code[-1])
        self.assertIn('class="table-scroll"', result)

    def test_j_result_column_stays_plain(self):
        _, parsed = self.parsed('''| Expression | Mojj | J |
| --- | --- | --- |
| `%: _1` | Raises a domain error. | Complex `0j1`. |
''')
        self.assertIn(("mojj-verb", "%:"), parsed.code[0])
        self.assertEqual(parsed.code[1], [("", "0j1")])

    def test_embedded_table_code_uses_both_grammars(self):
        _, parsed = self.parsed('''| Task | Mojj words | Mojj symbols | J |
| --- | --- | --- | --- |
| Sum | `jj["sum rank 1"](A).as_ints()` | `jj["+/\\"1"](A)` | `+/"1 A` |
''')
        self.assertEqual(parsed.text[0], 'jj["sum rank 1"](A).as_ints()')
        self.assertIn(("host-name", "jj"), parsed.code[0])
        self.assertIn(("mojj-verb", "sum"), parsed.code[0])
        self.assertIn(("host-name", "A"), parsed.code[0])
        self.assertIn(("mojj-modifier", '\\"'), parsed.code[1])

    def test_language_fences_and_comparison_labels(self):
        _, parsed = self.parsed("""```py
for x in xs:
    print(x)
```

| MATLAB (row vectors) | NuMojo | Wolfram Language |
| --- | --- | --- |
| `A.'` | `var x = 2` | `Dot[x, y]` |

| Environment | Code |
| --- | --- |
| Wolfram Language (Mathematica) | `Dot[x, y]` |
""")
        self.assertEqual(parsed.text, ["for x in xs:\n    print(x)", "A.'", "var x = 2", "Dot[x, y]", "Dot[x, y]"])
        self.assertIn(("host-keyword", "for"), parsed.code[0])
        self.assertIn(("host-operator", "'"), parsed.code[1])
        self.assertIn(("host-keyword", "var"), parsed.code[2])
        self.assertIn(("host-name", "Dot"), parsed.code[3])
        self.assertEqual(parsed.code[3], parsed.code[4])

    def test_output_is_offline_mathml_and_rewrites_reader_links(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, other = root / "README.md", root / "other.md"
            destination, other_output = root / "out" / "README.html", root / "out" / "other.html"
            source.write_text('# Sample\n\n[Next](other.md#section)\n\n$y_i = x_i^2$\n\n![dot](dot.svg)\n\n```mojo\nprint(jj["sum"](v))\n```\n')
            (root / "dot.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>')
            render(source, destination, {source: destination, other: other_output})
            result = destination.read_text()
            parsed = CodeText()
            parsed.feed(result)
            self.assertIn("other.html#section", parsed.links)
            self.assertIn("<math", result)
            self.assertNotIn("<script", result)
            self.assertTrue(parsed.images[0].startswith("data:image/svg+xml;base64,"))
            self.assertEqual(parsed.text, ['print(jj["sum"](v))'])
            self.assertIn(("mojj-verb", "sum"), parsed.code[0])


if __name__ == "__main__":
    unittest.main()
