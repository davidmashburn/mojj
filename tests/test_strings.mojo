"""J semantic fixtures through the public compile-time string facade."""
from std.collections import List
from std.math import abs, sqrt
from std.testing import assert_equal, assert_true, assert_raises
from mojj.strings import Expr
from mojj.nouns import Noun
from mojj.verbs import (
    Minus, Squared, Doubled, Plus, Divide, Tally, Insert, Hook, Fork,
    ComposeAll, Atop,
)


def close(actual: Float64, expected: Float64) raises:
    assert_true(abs(actual - expected) < 1e-12)


def vector(actual: Noun, expected: List[Float64]) raises:
    var values = actual.as_floats()
    assert_equal(len(values), len(expected))
    for index in range(len(values)):
        close(values[index], expected[index])


def test_trains_and_composition() raises:
    assert_equal(Expr["minus square"].apply(3.0), -6.0)
    assert_equal(Expr["minus of square"].apply(3.0), -9.0)
    assert_equal(Expr["- *:"].describe(), Hook[Minus, Squared].describe())
    assert_equal(Expr["- @: *:"].describe(), ComposeAll[Minus, Squared].describe())
    assert_equal(Expr["square plus double"].apply(3.0), 15.0)
    assert_equal(Expr["*: + +:"].describe(), Fork[Squared, Plus, Doubled].describe())
    assert_equal(Expr["cap minus square"].apply(3.0), -9.0)
    assert_equal(Expr["[: - *:"].describe(), Expr["minus of square"].describe())
    # Even and odd trains repeatedly resolve the rightmost fork.
    assert_equal(Expr["+ - * %"].describe(), Expr["+ (- * %)"].describe())
    assert_equal(Expr["+ - * % +"].describe(), Expr["+ - (* % +)"].describe())
    assert_equal(Expr["- *:"].dyad(Noun(10), Noun(3)).as_float(), 1.0)
    assert_equal(Expr["+ * -"].dyad(Noun(5), Noun(3)).as_float(), 16.0)


def test_reductions_and_rms() raises:
    var data: List[Float64] = [1.0, 2.0, 3.0, 4.0]
    assert_equal(Expr["mean"].reduce(data), 2.5)
    assert_equal(Expr["mean"].describe(), Expr["(+/ % #)"].describe())
    assert_equal(Expr["mean"].describe(), Fork[Insert[Plus], Divide, Tally].describe())
    assert_equal(Expr["minus insert"].reduce([1.0, 2.0, 3.0]), 2.0)
    assert_equal(Expr["-/"].reduce([1.0, 2.0, 3.0]), 2.0)
    close(Expr["sqrt of mean of square"].reduce(data), sqrt(7.5))
    assert_equal(Expr["sqrt of mean of square"].describe(), Expr["%: @: (+/ % #) @: *:"].describe())
    assert_true(Expr["sqrt mean square"].describe() != Expr["sqrt of mean of square"].describe())
    with assert_raises():
        _ = Expr["sqrt mean square"].reduce(data)
    var empty = List[Float64]()
    assert_equal(Expr["sum"].reduce(empty), 0.0)
    assert_equal(Expr["mean"].reduce(empty), 0.0)
    assert_equal(Expr["sqrt of mean of square"].reduce(empty), 0.0)


def test_binding_and_sentences() raises:
    assert_equal(Expr["10 bind minus"].apply(3.0), 7.0)
    assert_equal(Expr["minus bind 10"].apply(3.0), -7.0)
    assert_equal(Expr["10&-"].describe(), Expr["10 bind minus"].describe())
    assert_equal(Expr["-&10"].describe(), Expr["minus bind 10"].describe())
    assert_equal(Expr["10 % 3 + 2"].value().as_float(), 2.0)
    assert_equal(Expr["10 divide 3 plus 2"].describe(), Expr["10 % 3 + 2"].describe())
    assert_equal(Expr["(- *:) 3"].value().as_float(), -6.0)
    assert_equal(Expr["minus square 3"].value().as_float(), -9.0)
    assert_equal(Expr["group minus square end 3"].value().as_float(), -6.0)
    assert_equal(Expr["(10 + 2)&-"].apply(3.0), 9.0)
    assert_equal(Expr["0.5&*"].apply(3.0), 1.5)
    assert_equal(Expr["2:"].apply(3.0), 2.0)
    assert_equal(Expr["2 + *:"].apply(3.0), 11.0)
    assert_equal(Expr["1.25e2"].value().as_float(), 125.0)
    assert_equal(Expr["_3.5e_1"].value().as_float(), -0.35)
    vector(Expr["1 2 3 & +"].monad(Noun(10)), [11.0, 12.0, 13.0])
    vector(Expr["1 2 3 + 4 5 6"].value(), [5.0, 7.0, 9.0])


def test_rank_and_modifier_binding() raises:
    var x = Noun(List[Int]([1, 2, 3, 4]))
    var y = Noun(List[Int]([7, 5, 3, 2]))
    assert_equal(Expr["*/ @: +"].dyad(x, y).as_float(), 2016.0)
    vector(Expr["*/ @ +"].dyad(x, y), [8.0, 7.0, 6.0, 6.0])
    assert_equal(Expr["*/ @ +"].describe(), Expr["times insert atop plus"].describe())
    assert_equal(Expr["*:@(+/)"].reduce([1.0, 2.0, 3.0, 4.0]), 100.0)
    assert_equal(Expr["*:@+/"].reduce([1.0, 2.0, 3.0, 4.0]), 6770404.0)
    assert_true(Expr["*:@(+/)"].describe() != Expr["*:@+/"].describe())
    with assert_raises():
        _ = Expr["+"].dyad(Noun(List[Int]([1, 2])), Noun(List[Int]([1])))
    with assert_raises():
        _ = Expr["*:"].dyad(Noun(1), Noun(1))


def test_domains_and_reuse() raises:
    assert_equal(Expr["0 % 0"].value().as_float(), 0.0)
    with assert_raises():
        _ = Expr["%:"].apply(-1.0)
    var short: List[Float64] = [1.0, -2.0]
    var longer: List[Float64] = [1.0, -2.0, 3.0, -4.0, 5.0]
    var output = Expr["double of square"].map(short)
    assert_equal(output[0], 2.0)
    assert_equal(output[1], 8.0)
    output[0] = 999.0
    assert_equal(short[0], 1.0)
    assert_equal(Expr["double of square"].map(longer)[4], 50.0)
    assert_equal(Expr["double of square"].map(short)[0], 2.0)
    assert_equal(Expr["mean"].reduce(short), -0.5)
    assert_equal(Expr["mean"].reduce(longer), 0.6)
    assert_equal(Expr["mean"].reduce(short), -0.5)
    # Consumers check result rank rather than pretending all verbs are maps.
    with assert_raises():
        _ = Expr["sum"].map(short)
    with assert_raises():
        _ = Expr["square"].reduce(short)


def test_exact_nouns() raises:
    assert_equal(Expr["9007199254740993"].value().as_int(), 9007199254740993)
    assert_equal(Expr["9007199254740993 + 2"].value().as_int(), 9007199254740995)
    assert_equal(Expr["9223372036854775807"].value().as_int(), 9223372036854775807)
    assert_equal(Expr["_9223372036854775808"].value().as_int(), -9223372036854775808)
    assert_equal(Expr["# 1 2 3"].value().as_int(), 3)
    assert_equal(Expr["# 5"].value().as_int(), 1)
    assert_equal(Expr["1"].value().as_bool(), True)
    assert_equal(Expr["0 1 1"].value().as_bools()[0], False)
    # Materialize vector literals from the compile-time AST without losing dtype.
    assert_equal(Expr["9007199254740993 2"].value().as_ints()[0], 9007199254740993)
    vector(Expr["1 2.5 _3"].value(), [1.0, 2.5, -3.0])
    comptime integer_description = Expr["9007199254740993 2"].describe()
    comptime boolean_description = Expr["0 1 1"].describe()
    comptime float_description = Expr["1 2.5 _3"].describe()
    assert_equal(integer_description, "9007199254740993 2")
    assert_equal(boolean_description, "0 1 1")
    assert_equal(float_description, "1 2.5 -3")
    with assert_raises():
        _ = Expr["9223372036854775807 + 1"].value()
    with assert_raises():
        _ = Expr["- _9223372036854775808"].value()
    # Whole-noun rank of a bound verb must survive atop composition.
    assert_equal(Expr["*/ @ (10&+)"].reduce([1.0, 2.0, 3.0]), 1716.0)


def test_aliases() raises:
    assert_equal(Expr["identity"].describe(), Expr["]"].describe())
    assert_equal(Expr["left"].describe(), Expr["["].describe())
    assert_equal(Expr["negate"].describe(), Expr["minus"].describe())
    assert_equal(Expr["sqrt"].describe(), Expr["%:"].describe())
    assert_equal(Expr["double"].describe(), Expr["+:"].describe())
    assert_equal(Expr["square"].describe(), Expr["*:"].describe())
    assert_equal(Expr["tally"].describe(), Expr["#"].describe())
    assert_equal(Expr["sum"].describe(), Expr["plus insert"].describe())
    assert_equal(Expr["  square \t\r\n"].apply(3.0), 9.0)
    assert_equal(Expr["group minus square end"].describe(), Expr["(- *:)"].describe())


def main() raises:
    test_trains_and_composition()
    test_reductions_and_rms()
    test_binding_and_sentences()
    test_rank_and_modifier_binding()
    test_domains_and_reuse()
    test_aliases()
    test_exact_nouns()
    print("PASS test_strings: 7 J semantic test groups")
