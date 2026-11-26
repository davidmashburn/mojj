"""End-to-end coverage through one real Mojo REPL, including recovery."""
import re
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
from mojj_prompt import GROUP_WORDS, MODIFIER_WORDS, VERB_WORDS, Role, highlight


class HighlightTest(unittest.TestCase):
    def check_roles(self, line, expected):
        fragments = highlight(line)
        self.assertEqual("".join(token for _, token in fragments), line)
        self.assertEqual([(token, Role(style)) for style, token in fragments if style], expected)

    def test_words_and_names(self):
        self.check_roles("samples2 =: (sum rank 1 readings_2", [
            ("samples2", Role.NOUN), ("sum", Role.VERB), ("rank", Role.MODIFIER),
            ("1", Role.NOUN), ("readings_2", Role.NOUN),
        ])
        self.check_roles("x times table dz", [
            ("x", Role.NOUN), ("times", Role.VERB), ("table", Role.MODIFIER), ("dz", Role.NOUN),
        ])
        self.check_roles("group v dot w end", [
            ("v", Role.NOUN), ("dot", Role.VERB), ("w", Role.NOUN),
        ])

    def test_symbols_and_numbers(self):
        self.check_roles('(+/ . *)i.2', [
            ("+", Role.VERB), ("/", Role.MODIFIER), (".", Role.MODIFIER),
            ("*", Role.VERB), ("i.", Role.VERB), ("2", Role.NOUN),
        ])
        self.check_roles('3: @: o. "1', [
            ("3:", Role.VERB), ("@:", Role.MODIFIER), ("o.", Role.VERB),
            ('"', Role.MODIFIER), ("1", Role.NOUN),
        ])
        self.check_roles("_1.2e_3 .5 _ __", [
            ("_1.2e_3", Role.NOUN), (".5", Role.NOUN), ("_", Role.NOUN), ("__", Role.NOUN),
        ])
        self.check_roles(":quit", [])

    def test_all_parser_word_aliases_have_a_role(self):
        source = (ROOT / "src/mojj/_syntax.mojo").read_text()
        reserved = set(re.findall(r'word == "([a-z_]+)"', source))
        self.assertSetEqual(VERB_WORDS | MODIFIER_WORDS | GROUP_WORDS, reserved)


class CliTest(unittest.TestCase):
    def test_session(self):
        commands = """v =: 1 2 3 4
snapshot =: v
v =: v + v
sum v
snapshot
A =: (2 2 reshape
    v)
A
(+/"1) A
v =: sqrt _1
v =: (
    3 + )
sum v
unknown
sum =: 9
3 = 3
"""
        cli = Path(__file__).resolve().parents[1] / "bin" / "mojj"
        result = subprocess.run([cli], input=commands, text=True, capture_output=True, timeout=180)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            "20", "[1, 2, 3, 4]", "shape [2, 2] [2, 4, 6, 8]", "[6, 14]", "20", "True",
        ], result.stderr)
        for message in ("negative", "Mojj syntax", "undefined name: unknown", "reserved or invalid name: sum"):
            self.assertIn(message, result.stderr)


if __name__ == "__main__":
    unittest.main()
