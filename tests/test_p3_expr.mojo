"""P3 array verbs and modifiers through the public expression facade."""

from std.collections import List
from std.testing import assert_equal, assert_raises

from mojj import Expr, Noun


def aliases[words: StringLiteral, symbols: StringLiteral]() raises:
    assert_equal(Expr[words].describe(), Expr[symbols].describe())


def check_array(value: Noun, dims: List[Int], atoms: List[Int]) raises:
    assert_equal(value.dims(), dims)
    assert_equal(value.as_ints(), atoms)


def test_array_verbs() raises:
    aliases["shape", "$"]()
    aliases["reshape", "$"]()
    aliases["iota", "i."]()
    aliases["ravel", ","]()
    aliases["append", ","]()
    aliases["stitch", ",."]()
    aliases["laminate", ",:"]()
    aliases["gather", "{"]()
    aliases["head", "{."]()
    aliases["tail", "{:"]()
    aliases["take", "{."]()
    aliases["drop", "}."]()
    aliases["curtail", "}:"]()
    aliases["reverse", "|."]()
    aliases["rotate", "|."]()
    aliases["transpose", "|:"]()
    aliases["copy", "#"]()
    aliases["filter", "#"]()

    check_array(Expr["2 3 $ i.6"].value(), [2, 3], [0, 1, 2, 3, 4, 5])
    check_array(Expr["10 20 + i.2 3"].value(), [2, 3], [10, 11, 12, 23, 24, 25])
    var comparison = Expr["1 4 < i.2 3"].value()
    assert_equal(comparison.dims(), List[Int]([2, 3]))
    assert_equal(
        comparison.as_bools(),
        List[Bool]([False, False, True, False, False, True]),
    )
    with assert_raises(contains="shape agreement failed"):
        _ = Expr["1 2 3 + i.2 3"].value()
    check_array(Expr["|: i.2 3"].value(), [3, 2], [0, 3, 1, 4, 2, 5])
    check_array(Expr["_4 {. 2 3"].value(), [4], [0, 0, 2, 3])
    check_array(Expr["1 0 1 # 2 3 4"].value(), [2], [2, 4])
    assert_equal(Expr["2 { 3 4 5"].value().as_int(), 5)
    assert_equal(Expr["(i.2 3) -: i.3 2"].value().as_bool(), False)
    with assert_raises():
        _ = Expr["2 2&$"].map([1.0, 2.0, 3.0, 4.0])


def test_rank() raises:
    aliases["sum rank 1", '+/"1']()
    aliases["tally rank _1", '#"_1']()
    aliases["tally rank _", '#"_']()

    check_array(Expr['(+/"1) i.2 3'].value(), [2], [3, 12])
    check_array(Expr['(#"0 1) i.2 3'].value(), [2], [3, 3])
    check_array(Expr['(#"0 1 2) i.2 3'].value(), [2, 3], [1, 1, 1, 1, 1, 1])
    check_array(Expr['(#"_1) i.2 3'].value(), [2], [3, 3])
    check_array(Expr['(#"1.0) i.2 3'].value(), [2], [3, 3])
    check_array(Expr['(#"1.00000000000001) i.2 3'].value(), [2], [3, 3])
    check_array(
        Expr['(#"_9223372036854775808.0) i.2 3'].value(),
        [2, 3],
        [1, 1, 1, 1, 1, 1],
    )
    assert_equal(Expr['(#"_) i.2 3'].value().as_int(), 2)


def test_segments_and_products() raises:
    aliases["sum prefix", "+/\\"]()
    aliases["sum scan", "+/\\"]()
    aliases["sum suffix", "+/\\."]()
    aliases["times table", "*/"]()
    aliases["dot", "+/ . *"]()
    aliases["+/.*", "+/ . *"]()

    check_array(Expr["+/\\ 1 2 3 4"].value(), [4], [1, 3, 6, 10])
    check_array(Expr["+/\\. 1 2 3 4"].value(), [4], [10, 9, 7, 4])
    check_array(Expr["2 +/\\ 1 2 3 4"].value(), [3], [3, 5, 7])
    check_array(Expr["_2 +/\\ 1 2 3 4 5"].value(), [3], [3, 7, 5])
    check_array(Expr["2 +/\\. 1 2 3 4"].value(), [3], [7, 5, 3])
    check_array(Expr["2 3 */ 4 5 6"].value(), [2, 3], [8, 10, 12, 12, 15, 18])
    assert_equal(Expr["1 2 3 +/ . * 4 5 6"].value().as_int(), 32)
    check_array(
        Expr["(2 3 $ 1 2 3 4 5 6) +/ . * (3 2 $ 7 8 9 10 11 12)"].value(),
        [2, 2],
        [58, 64, 139, 154],
    )


def main() raises:
    test_array_verbs()
    test_rank()
    test_segments_and_products()
    print("PASS test_p3_expr")
