"""Readable and symbolic literals compile to the same numerical composition."""

from std.collections import List
from std.testing import assert_equal
import mojj as jj


def main() raises:
    comptime Words = jj.Expr["sqrt mean square"]
    comptime Symbols = jj.Expr["%: @: ((+/ % #) @: *:)"]
    comptime Typed = jj.After[jj.Sqrt, jj.Mean[jj.Map[jj.Square]]]
    comptime description = Words.describe()
    var data: List[Float64] = [3.0, 4.0]

    var words = Words.reduce(data)
    var symbols = Symbols.reduce(data)
    var typed = jj.evaluate[Typed](data)
    assert_equal(words, symbols)
    assert_equal(words, typed)
    assert_equal(description, Typed.describe())
    print(description)
    print("RMS:", words)
    print("negated squares:", jj.Expr["negate square"].map(data))
