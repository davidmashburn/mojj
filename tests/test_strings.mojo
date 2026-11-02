from std.collections import List
from std.math import sqrt
from std.testing import assert_equal, assert_raises, assert_true

from mojj.core import (
    After, Compose, Map, Mean, Negate, Scale, Sqrt, Square, Sum,
)
from mojj.strings import Expr


def assert_close(actual: Float64, expected: Float64, message: String) raises:
    var difference = abs(actual - expected)
    var tolerance = 1.0e-12 * (1.0 + abs(expected))
    assert_true(difference <= tolerance, message)


def assert_list_close(
    actual: List[Float64], expected: List[Float64], message: String
) raises:
    assert_equal(len(actual), len(expected), message)
    for index in range(len(actual)):
        assert_close(actual[index], expected[index], message)


def test_primitive_words_and_symbols() raises:
    comptime IdentityWord = Expr["identity"]
    comptime IdentitySymbol = Expr["]"]
    comptime NegateWord = Expr["negate"]
    comptime NegateSymbol = Expr["-"]
    comptime SquareWord = Expr["square"]
    comptime SquareSymbol = Expr["*:"]
    comptime SqrtWord = Expr["sqrt"]
    comptime SqrtSymbol = Expr["%:"]
    comptime DoubleWord = Expr["double"]
    comptime DoubleSymbol = Expr["+:"]

    assert_equal(IdentityWord.apply(-2.5), -2.5)
    assert_equal(IdentitySymbol.apply(3.25), 3.25)
    assert_equal(NegateWord.apply(-2.5), 2.5)
    assert_equal(NegateSymbol.apply(3.25), -3.25)
    assert_equal(SquareWord.apply(-2.5), 6.25)
    assert_equal(SquareSymbol.apply(3.25), 10.5625)
    assert_close(SqrtWord.apply(9.0), 3.0, "word sqrt is incorrect")
    assert_close(SqrtSymbol.apply(16.0), 4.0, "symbol sqrt is incorrect")
    assert_equal(DoubleWord.apply(2.5), 5.0)
    assert_equal(DoubleSymbol.apply(-2.5), -5.0)

    var data: List[Float64] = [1.0, -2.0, 3.0]
    assert_equal(Expr["+/"].reduce(data), 2.0)
    assert_close(
        Expr["(+/ % #)"].reduce(data),
        2.0 / 3.0,
        "the exact mean symbol pattern is incorrect",
    )


def test_scalar_order_and_map() raises:
    comptime DoubleOfSquare = Expr["double of square"]
    comptime SquareOfDouble = Expr["square of double"]
    comptime MixedSymbols = Expr["+: of *:"]

    # "of" is right-associative: the right operand runs first.
    assert_equal(DoubleOfSquare.apply(3.0), 18.0)
    assert_equal(SquareOfDouble.apply(3.0), 36.0)
    assert_equal(MixedSymbols.apply(-2.0), 8.0)

    var data: List[Float64] = [2.0, -3.0, 1.0]
    var mapped = MixedSymbols.map(data)
    var expected: List[Float64] = [8.0, 18.0, 2.0]
    assert_list_close(
        mapped,
        expected,
        "scalar map does not preserve composition order",
    )


def test_reduction_compositions() raises:
    comptime SumSquares = Expr["sum of square"]
    comptime SquareOfSum = Expr["square of sum"]
    comptime MeanSquares = Expr["mean of square"]
    comptime RMS = Expr["sqrt of mean of square"]
    comptime MeanNegatedSquares = Expr["mean of (negate of square)"]

    var data: List[Float64] = [1.0, -2.0, 3.0, -4.0]
    # Independently known values: sum=-2, square sum=30, mean square=7.5.
    assert_equal(SumSquares.reduce(data), 30.0)
    assert_equal(SquareOfSum.reduce(data), 4.0)
    assert_close(
        MeanSquares.reduce(data),
        7.5,
        "mean after a scalar map is incorrect",
    )
    assert_close(
        RMS.reduce(data),
        sqrt(7.5),
        "RMS reduction is incorrect",
    )
    assert_close(
        MeanNegatedSquares.reduce(data),
        -7.5,
        "mean of negate of square is incorrect",
    )


def test_grouping_equivalence() raises:
    comptime FlatRMS = Expr["sqrt of mean of square"]
    comptime ParenthesizedRMS = Expr["(sqrt of mean) of square"]
    comptime WordGroupedRMS = Expr["group sqrt of mean end of square"]
    comptime NegatedSquareMean = Expr["mean of (negate of square)"]
    comptime NegatedSquareMeanWithGroup = Expr[
        "mean of group negate of square end"
    ]

    var data: List[Float64] = [1.0, -2.0, 3.0]
    var expected_rms = sqrt(14.0 / 3.0)
    assert_close(
        ParenthesizedRMS.reduce(data),
        expected_rms,
        "parenthesized mixed grouping changed the reduction",
    )
    assert_close(
        WordGroupedRMS.reduce(data),
        expected_rms,
        "word grouping changed the reduction",
    )
    assert_close(
        FlatRMS.reduce(data),
        expected_rms,
        "ungrouped mixed composition is incorrect",
    )
    assert_close(
        NegatedSquareMeanWithGroup.reduce(data),
        NegatedSquareMean.reduce(data),
        "grouping changed a scalar map inside a reduction",
    )


def test_mixed_spelling_and_ascii_whitespace() raises:
    comptime WordRMS = Expr["sqrt of mean of square"]
    comptime MixedRMS = Expr["sqrt\t of\n (+/\r % #)\n of *:"]
    comptime AtRMS = Expr["%: @: ((+/ % #) @: *:)"]

    var data: List[Float64] = [2.0, -1.0, 4.0]
    assert_close(
        MixedRMS.reduce(data),
        WordRMS.reduce(data),
        "mixed word and symbol spelling changed the result",
    )
    assert_equal(
        MixedRMS.describe(),
        WordRMS.describe(),
        "ASCII tabs/newlines changed the expression description",
    )
    assert_close(
        AtRMS.reduce(data),
        WordRMS.reduce(data),
        "@: composition changed the mixed symbolic reduction",
    )
    assert_equal(
        AtRMS.describe(),
        WordRMS.describe(),
        "@: composition changed the expression description",
    )


def test_runtime_reuse_and_source_preservation() raises:
    comptime Pipeline = Expr["double of negate"]
    comptime SumPlan = Expr["sum"]
    comptime MeanPlan = Expr["mean"]
    comptime RMSPlan = Expr["sqrt of mean of square"]

    var short_data: List[Float64] = [1.0, -2.0]
    var long_data: List[Float64] = [-3.0, 0.0, 4.0, 5.0, -1.0]
    var short_before: List[Float64] = [1.0, -2.0]
    var long_before: List[Float64] = [-3.0, 0.0, 4.0, 5.0, -1.0]

    var short_output = Pipeline.map(short_data)
    var long_output = Pipeline.map(long_data)
    var short_expected: List[Float64] = [-2.0, 4.0]
    var long_expected: List[Float64] = [6.0, 0.0, -8.0, -10.0, 2.0]
    assert_list_close(
        short_output,
        short_expected,
        "the compiled scalar plan failed for the short list",
    )
    assert_list_close(
        long_output,
        long_expected,
        "the compiled scalar plan failed for the long list",
    )

    # Mapping must return fresh storage and leave both borrowed sources intact.
    short_output[0] = 999.0
    long_output[0] = 999.0
    assert_list_close(
        short_data,
        short_before,
        "mapping mutated the short source list",
    )
    assert_list_close(
        long_data,
        long_before,
        "mapping mutated the long source list",
    )

    var reused_output = Pipeline.map(short_data)
    assert_list_close(
        reused_output,
        short_expected,
        "reusing a compile-time plan after output mutation failed",
    )

    # Reductions reuse the same compile-time plans across runtime lengths too.
    assert_equal(SumPlan.reduce(short_data), -1.0)
    assert_equal(SumPlan.reduce(long_data), 5.0)
    assert_equal(MeanPlan.reduce(short_data), -0.5)
    assert_equal(MeanPlan.reduce(long_data), 1.0)
    assert_close(
        RMSPlan.reduce(short_data),
        sqrt(2.5),
        "RMS plan failed for the short list",
    )
    assert_close(
        RMSPlan.reduce(long_data),
        sqrt(51.0 / 5.0),
        "RMS plan failed for the long list",
    )


def test_empty_reductions() raises:
    comptime EmptySum = Expr["sum"]
    comptime EmptyMean = Expr["mean"]
    comptime EmptyRMS = Expr["sqrt of mean of square"]
    comptime EmptyMap = Expr["square"]

    var empty: List[Float64] = []
    var mapped = EmptyMap.map(empty)
    assert_equal(len(mapped), 0)
    assert_equal(EmptySum.reduce(empty), 0.0)
    with assert_raises(contains="mean requires nonempty input"):
        _ = EmptyMean.reduce(empty)
    with assert_raises(contains="mean requires nonempty input"):
        _ = EmptyRMS.reduce(empty)


def test_exact_compiletime_descriptions() raises:
    comptime StringIdentity = Expr["identity"].describe()
    comptime StringDouble = Expr["double"].describe()
    comptime StringSquare = Expr["square"].describe()
    comptime StringSumSquares = Expr["sum of square"].describe()
    comptime StringSquareOfSum = Expr["square of sum"].describe()
    comptime StringRMS = Expr["sqrt of mean of square"].describe()
    comptime StringNegatedSquareMean = Expr[
        "mean of (negate of square)"
    ].describe()

    comptime TypedSumSquares = Sum[Map[Square]]
    comptime TypedSquareOfSum = After[Square, Sum[]]
    comptime TypedRMS = After[Sqrt, Mean[Map[Square]]]
    comptime TypedNegatedSquareMean = Mean[
        Map[Compose[Negate, Square]]
    ]

    assert_equal(StringIdentity, "identity")
    assert_equal(StringIdentity, Expr["identity"].describe())
    assert_equal(StringDouble, Scale[2].describe())
    assert_equal(StringDouble, "scale[2]")
    assert_equal(StringSquare, Square.describe())
    assert_equal(StringSquare, "square")
    assert_equal(StringSumSquares, TypedSumSquares.describe())
    assert_equal(StringSumSquares, "sum(map(square, input))")
    assert_equal(StringSquareOfSum, TypedSquareOfSum.describe())
    assert_equal(StringSquareOfSum, "after(square, sum(input))")
    assert_equal(StringRMS, TypedRMS.describe())
    assert_equal(StringRMS, "after(sqrt, mean(map(square, input)))")
    assert_equal(
        StringNegatedSquareMean,
        TypedNegatedSquareMean.describe(),
    )
    assert_equal(
        StringNegatedSquareMean,
        "mean(map(compose(negate, square), input))",
    )


def test_whitespace_composition() raises:
    comptime Phrase = Expr["sqrt mean square"]
    comptime Explicit = Expr["sqrt of mean of square"]
    var data: List[Float64] = [3.0, 4.0]
    assert_close(Phrase.reduce(data), sqrt(12.5), "bare phrase RMS")
    assert_equal(Phrase.describe(), Explicit.describe())
    assert_equal(Expr["double square"].apply(3.0), 18.0)
    assert_equal(Expr["square double"].apply(3.0), 36.0)
    # Numerical function composition is associative; description checks the
    # authored parse tree, which must still associate to the right.
    assert_equal(
        Expr["negate double square"].describe(),
        "compose(negate, compose(scale[2], square))",
    )
    assert_equal(
        Expr["(negate double) square"].describe(),
        "compose(compose(negate, scale[2]), square)",
    )
    assert_equal(Expr["  square \t\r\n"].apply(3.0), 9.0)
    assert_equal(Expr["square\tdouble\r\nnegate"].apply(3.0), 36.0)
    assert_equal(Expr["negate of double square"].apply(3.0), -18.0)
    assert_equal(Expr["negate double @: square"].apply(3.0), -18.0)
    assert_equal(Expr["- +: *:"].apply(3.0), -18.0)
    assert_equal(
        Expr["group sqrt mean end square"].reduce(data), Phrase.reduce(data)
    )
    assert_equal(
        Expr["(sqrt mean ) square"].describe(), Phrase.describe()
    )
    assert_equal(
        Expr["group group negate end double end square"].apply(3.0), -18.0
    )


def main() raises:
    var groups: Int = 0
    test_primitive_words_and_symbols()
    groups += 1
    test_scalar_order_and_map()
    groups += 1
    test_reduction_compositions()
    groups += 1
    test_grouping_equivalence()
    groups += 1
    test_mixed_spelling_and_ascii_whitespace()
    groups += 1
    test_runtime_reuse_and_source_preservation()
    groups += 1
    test_empty_reductions()
    groups += 1
    test_exact_compiletime_descriptions()
    groups += 1
    test_whitespace_composition()
    groups += 1
    print("PASS test_strings: ", groups, " test groups")
    print(
        "RESULT: grammar primitives, composition categories, grouping, "
        "runtime reuse, empty reductions, and exact descriptions passed"
    )
