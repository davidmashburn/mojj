"""Readable and symbolic J phrases compile to the same typed verbs."""
from std.collections import List
from std.testing import assert_equal
import mojj as jj
from mojj.verbs import ComposeAll, Root, Fork, Insert, Plus, Divide, Tally, Squared


def main() raises:
    comptime Words = jj.Expr["sqrt of mean of square"]
    comptime Symbols = jj.Expr["%: @: (+/ % #) @: *:"]
    comptime Typed = ComposeAll[ComposeAll[Root, Fork[Insert[Plus], Divide, Tally]], Squared]
    var data: List[Float64] = [3.0, 4.0]
    var words = Words.reduce(data)
    assert_equal(words, Symbols.reduce(data))
    assert_equal(Words.describe(), Typed.describe())
    print(Words.describe())
    print("RMS:", words)
    print("hook at 3:", jj.Expr["minus square"].apply(3.0))
    print("composition at 3:", jj.Expr["minus of square"].apply(3.0))
    print("negated squares:", jj.Expr["minus of square"].map(data))
    print("noun sentence:", jj.Expr["10 divide 3 plus 2"].value().as_float())
