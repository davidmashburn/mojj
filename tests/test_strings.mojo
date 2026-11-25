"""J semantic fixtures through the public compile-time string facade."""
from std.collections import List
from std.math import abs, sqrt
from std.memory import bitcast
from std.testing import assert_equal, assert_true, assert_raises
from mojj import jj
from mojj.modifiers import Repeat
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
    assert_equal(Expr["*:"].dyad(Noun(1), Noun(1)).as_bool(), False)


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
    var identity = Expr["]"].map(short)
    short[1] = 7.0
    assert_equal(identity[1], -2.0)
    identity[0] = 4.0
    assert_equal(short[0], 1.0)
    assert_equal(len(Expr["]"].map(List[Float64]())), 0)
    assert_equal(Expr["2 3 & ["].map(short)[1], 3.0)
    assert_equal(Expr["0 1 & ["].map(short)[1], 1.0)
    # Consumers check result rank rather than pretending all verbs are maps.
    with assert_raises():
        _ = Expr["sum"].map(short)
    with assert_raises():
        _ = Expr["square"].reduce(short)


def test_double_map_bits() raises:
    var samples: List[UInt64] = [
        0x0000000000000000,  # positive zero
        0x8000000000000000,  # negative zero
        0x0000000000000001,  # smallest positive subnormal
        0x8000000000000001,  # smallest negative subnormal
        0x000fffffffffffff,  # largest positive subnormal
        0x800fffffffffffff,  # largest negative subnormal
        0x0010000000000000,  # smallest positive normal
        0x8010000000000000,  # smallest negative normal
        0x7fefffffffffffff,  # largest positive finite value
        0xffefffffffffffff,  # largest negative finite magnitude
        0x7ff0000000000000,  # positive infinity
        0xfff0000000000000,  # negative infinity
        0x7ff8000000000123,  # positive quiet NaN with payload
        0xfff8000000000456,  # negative quiet NaN with payload
        0x7ff0000000000789,  # positive signaling NaN with payload
        0xfff0000000000abc,  # negative signaling NaN with payload
        0x3ff0000000000000,  # 1.0
        0xbff4000000000000,  # -1.25
    ]
    # Include empty and short vectors, then every tail for widths 2, 4 and 8.
    for length in range(len(samples) + 8):
        var data = List[Float64](length=length, fill=0.0)
        for index in range(length):
            data[index] = bitcast[DType.float64](samples[index % len(samples)])

        var result = Expr["+:"].map(data)
        assert_equal(len(result), length)
        for index in range(length):
            var bits = samples[index % len(samples)]
            var expected = Expr["+:"].apply(bitcast[DType.float64](bits))
            assert_equal(
                bitcast[DType.uint64](result[index]),
                bitcast[DType.uint64](expected),
            )
            assert_equal(bitcast[DType.uint64](data[index]), bits)

        if length > 0:
            result[0] = 123.0
            assert_equal(bitcast[DType.uint64](data[0]), samples[0])
            data[0] = 42.0
            assert_equal(result[0], 123.0)


def test_owned_consumers() raises:
    var data: List[Float64] = [1.0, -2.0, 3.0, -4.0, 5.0]
    assert_equal(Expr["+:"].map_owned(data^), [2.0, -4.0, 6.0, -8.0, 10.0])
    assert_equal(Expr["2 3 & ["].map_owned([7.0]), [2.0, 3.0])

    # Compare bits on a cancellation-sensitive input to check the strict fold.
    var cancellation: List[Float64] = [1.0e16, -1.0e16, 1.0]
    var expected = bitcast[DType.uint64](Expr["+/"].reduce(cancellation))
    assert_equal(bitcast[DType.uint64](Expr["+/"].reduce_owned(cancellation^)), expected)
    assert_equal(Expr["+/"].reduce_owned(List[Float64]()), 0.0)

    with assert_raises(contains="Expr.map requires a vector result"):
        _ = Expr["sum"].map_owned([1.0, 2.0])
    with assert_raises(contains="as_float requires a scalar noun"):
        _ = Expr["square"].reduce_owned([1.0, 2.0])
    with assert_raises(contains="Root monad rejects negative real values"):
        _ = Expr["%:"].map_owned([-1.0])


def check_owned_identity[source: StringLiteral]() raises:
    var negative_zero = UInt64(0x8000000000000000)
    var nan_payload = UInt64(0x7ff8000000000123)
    var input: List[Float64] = [
        bitcast[DType.float64](negative_zero),
        bitcast[DType.float64](nan_payload),
    ]
    var transferred = input.copy()
    var original_address = UInt(transferred.unsafe_ptr())
    var moved = Expr[source].map_owned(transferred^)
    assert_equal(UInt(moved.unsafe_ptr()), original_address)

    var output = Expr[source].map_owned(input.copy())
    assert_equal(len(output), 2)
    assert_equal(bitcast[DType.uint64](output[0]), negative_zero)
    assert_equal(bitcast[DType.uint64](output[1]), nan_payload)
    input[0] = 1.0
    assert_equal(bitcast[DType.uint64](output[0]), negative_zero)
    output[1] = 2.0
    assert_equal(bitcast[DType.uint64](input[1]), nan_payload)
    assert_equal(len(Expr[source].map_owned(List[Float64]())), 0)


def test_owned_identity() raises:
    check_owned_identity["]"]()
    check_owned_identity["["]()
    check_owned_identity["identity"]()
    check_owned_identity["right"]()
    check_owned_identity["left"]()
    check_owned_identity["(])"]()


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


def test_repeat() raises:
    assert_equal(Expr["+:^:3"].describe(), Repeat[Doubled, 3].describe())
    assert_equal(Expr["double repeat 3"].describe(), Expr["+:^:3"].describe())
    assert_equal(Expr["+:^:3"].apply(2.0), 16.0)
    assert_equal(Expr["+:^:0"].apply(2.0), 2.0)
    assert_equal(Expr["+:^:1"].apply(2.0), 4.0)
    assert_equal(Expr["3 +^:(4) 2"].value().as_int(), 14)
    assert_equal(Expr["(1&+)^:1024"].monad(Noun(0)).as_int(), 1024)
    assert_equal(Expr["+/@:(+:^:3)"].reduce([1.0, 2.0, 3.0]), 48.0)
    close(Expr["2 ^ 3"].value().as_float(), 8.0)
    close(Expr["2 ^. 8"].value().as_float(), 3.0)


def test_jj_data() raises:
    assert_equal(jj(1).as_int(), 1)
    assert_equal(jj(True).as_bool(), True)
    assert_equal(jj(2.5).as_float(), 2.5)
    assert_equal(jj([1]).as_ints(), List[Int]([1]))
    assert_equal(jj([False, True]).as_bools(), List[Bool]([False, True]))
    assert_equal(jj([2.5, -0.5]).as_floats(), List[Float64]([2.5, -0.5]))

    var samples: List[Int] = [2, 4]
    var v = jj(samples)
    samples[0] = 9
    assert_equal(v.as_ints(), List[Int]([2, 4]))
    assert_equal(jj(List[Int]()).as_ints(), List[Int]())


def test_jj_call_arity() raises:
    var y = jj["3 4"]()
    assert_equal(jj["-"](y).as_ints(), List[Int]([-3, -4]))
    assert_equal(jj["-"](jj(10), y).as_ints(), List[Int]([7, 6]))
    with assert_raises():
        _ = jj["%:"](Noun(-1))


def main() raises:
    test_jj_data()
    test_jj_call_arity()
    test_trains_and_composition()
    test_reductions_and_rms()
    test_binding_and_sentences()
    test_rank_and_modifier_binding()
    test_domains_and_reuse()
    test_aliases()
    test_repeat()
    test_exact_nouns()
    test_double_map_bits()
    test_owned_consumers()
    test_owned_identity()
    print("PASS test_strings: 13 J semantic test groups")
