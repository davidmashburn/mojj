"""End-to-end coverage through one real Mojo REPL, including recovery."""
import subprocess
import unittest
from pathlib import Path


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
