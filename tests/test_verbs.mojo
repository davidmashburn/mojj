from std.collections import List
from std.testing import assert_equal, assert_raises, assert_true

from mojj.nouns import (
    Noun,
    NounDType,
    NounProvider,
    SCALAR_RANK,
    VECTOR_RANK,
    Float64NounProvider,
)
from mojj.verbs import (
    WHOLE_NOUN_RANK,
    Plus,
    Minus,
    Times,
    Divide,
    Squared,
    Doubled,
    Root,
    Left,
    Right,
    Tally,
    Insert,
    Hook,
    Fork,
    ComposeAll,
    Atop,
    BindLeft,
    BindRight,
    BindLeftNoun,
    BindRightNoun,
    Constant,
    ConstantNoun,
)


struct FloatVectorProvider(NounProvider):
    @staticmethod
    def value() raises -> Noun:
        var values: List[Float64] = [1.5, 2.5]
        return Noun(values)

    @staticmethod
    def describe() -> String:
        return "1.5 2.5"


def assert_int_scalar(value: Noun, expected: Int) raises:
    assert_equal(value.rank, SCALAR_RANK)
    assert_true(value.dtype == NounDType.INT)
    assert_equal(value.length(), 1)
    assert_equal(value.as_int(), expected)


def assert_float_scalar(value: Noun, expected: Float64) raises:
    assert_equal(value.rank, SCALAR_RANK)
    assert_true(value.dtype == NounDType.FLOAT64)
    assert_equal(value.length(), 1)
    var difference = abs(value.as_float() - expected)
    assert_true(difference <= 1.0e-12, "Float64 scalar differs")


def assert_int_vector(value: Noun, expected: List[Int]) raises:
    assert_equal(value.rank, VECTOR_RANK)
    assert_true(value.dtype == NounDType.INT)
    assert_equal(value.length(), len(expected))
    for index in range(len(expected)):
        assert_equal(value.at(index).as_int(), expected[index])


def assert_float_vector(value: Noun, expected: List[Float64]) raises:
    assert_equal(value.rank, VECTOR_RANK)
    assert_true(value.dtype == NounDType.FLOAT64)
    assert_equal(value.length(), len(expected))
    for index in range(len(expected)):
        var difference = abs(value.at(index).as_float() - expected[index])
        assert_true(difference <= 1.0e-12, "Float64 cell differs")


def test_noun_storage_rank_shape_and_reuse() raises:
    var scalar = Noun(7)
    assert_equal(scalar.rank, SCALAR_RANK)
    assert_true(scalar.dtype == NounDType.INT)
    assert_equal(scalar.length(), 1)
    assert_equal(scalar.at(0).as_int(), 7)

    var source_values: List[Int] = [2, 4, 6]
    var vector = Noun(source_values)
    source_values[0] = 99
    assert_int_vector(vector, List[Int]([2, 4, 6]))
    assert_equal(vector.at(1).rank, SCALAR_RANK)
    assert_equal(vector.at(1).as_int(), 4)

    var empty_int = Noun(List[Int]())
    var singleton_float = Noun(List[Float64]([3.5]))
    assert_equal(empty_int.rank, VECTOR_RANK)
    assert_equal(empty_int.length(), 0)
    assert_equal(singleton_float.rank, VECTOR_RANK)
    assert_equal(singleton_float.length(), 1)
    assert_true(singleton_float.at(0).dtype == NounDType.FLOAT64)

    with assert_raises(contains="noun index out of range"):
        _ = vector.at(3)
    with assert_raises(contains="as_float requires a scalar"):
        _ = vector.as_float()
    with assert_raises(contains="as_floats requires a vector"):
        _ = scalar.as_floats()

    var output = Minus.monad(vector)
    output.int_values[0] = 100
    assert_equal(vector.at(0).as_int(), 2)


def test_numeric_bool_promotion_and_agreement() raises:
    assert_int_scalar(Plus.dyad(Noun(True), Noun(True)), 2)
    assert_int_scalar(Minus.dyad(Noun(False), Noun(True)), -1)
    assert_int_scalar(Times.dyad(Noun(True), Noun(True)), 1)
    assert_float_scalar(Divide.dyad(Noun(False), Noun(False)), 0.0)

    var booleans: List[Bool] = [True, False, True]
    assert_int_vector(
        Plus.dyad(Noun(booleans), Noun(2)),
        List[Int]([3, 2, 3]),
    )
    assert_int_scalar(Insert[Plus].monad(Noun(booleans)), 2)
    assert_int_scalar(Insert[Plus].monad(Noun(List[Bool]())), 0)

    var ints: List[Int] = [1, 2, 3]
    assert_int_vector(
        Plus.dyad(Noun(1), Noun(ints)),
        List[Int]([2, 3, 4]),
    )
    with assert_raises(contains="shape agreement failed"):
        _ = Plus.dyad(Noun(List[Int]([1, 2])), Noun(List[Int]([3])))

    with assert_raises(contains="Int overflow"):
        _ = Plus.dyad(Noun(Int.MAX), Noun(True))


def test_hooks_forks_composition_and_reductions() raises:
    assert_int_scalar(Hook[Minus, Squared].monad(Noun(3)), -6)
    assert_int_scalar(ComposeAll[Minus, Squared].monad(Noun(3)), -9)
    assert_int_scalar(Fork[Squared, Plus, Doubled].monad(Noun(3)), 15)

    var values: List[Int] = [1, 2, 3]
    assert_int_scalar(Insert[Minus].monad(Noun(values)), 2)

    var mean_values: List[Int] = [1, 2, 3, 4]
    comptime Mean = Fork[Insert[Plus], Divide, Tally]
    assert_float_scalar(Mean.monad(Noun(mean_values)), 2.5)
    assert_float_scalar(Mean.monad(Noun(List[Int]())), 0.0)

    with assert_raises(contains="negative real"):
        _ = Root.monad(Noun(-1))
    with assert_raises(contains="Squared dyad is unsupported"):
        _ = Squared.dyad(Noun(1), Noun(1))
    with assert_raises(contains="Root dyad is unsupported"):
        _ = Root.dyad(Noun(2), Noun(2))
    with assert_raises(contains="Tally dyad is unsupported"):
        _ = Tally.dyad(Noun(1), Noun(1))


def test_atop_vs_compose_and_bound_ranks() raises:
    var x: List[Int] = [1, 2, 3, 4]
    var y: List[Int] = [7, 5, 3, 2]
    var per_cell = Atop[Insert[Times], Plus].dyad(Noun(x), Noun(y))
    var whole = ComposeAll[Insert[Times], Plus].dyad(Noun(x), Noun(y))
    assert_int_vector(per_cell, List[Int]([8, 7, 6, 6]))
    assert_int_scalar(whole, 2016)

    comptime AddTen = BindLeft[10, Plus]
    comptime SubtractTen = BindRight[Minus, 10]
    assert_equal(AddTen.monad_rank(), WHOLE_NOUN_RANK)
    assert_equal(SubtractTen.monad_rank(), WHOLE_NOUN_RANK)
    assert_int_vector(
        AddTen.monad(Noun(List[Int]([1, 2]))),
        List[Int]([11, 12]),
    )
    assert_int_scalar(SubtractTen.monad(Noun(3)), -7)

    var bound_product = Atop[Insert[Times], AddTen].monad(
        Noun(List[Int]([1, 2, 3]))
    )
    assert_int_scalar(bound_product, 1716)
    assert_int_vector(
        Atop[Insert[Times], Plus].monad(Noun(List[Int]([1, 2, 3]))),
        List[Int]([1, 2, 3]),
    )


def test_provider_bindings_and_constants() raises:
    comptime FloatPlus = BindLeftNoun[Float64NounProvider[2.5], Plus]
    comptime FloatMinus = BindRightNoun[Minus, Float64NounProvider[2.5]]
    assert_float_scalar(FloatPlus.monad(Noun(1)), 3.5)
    assert_float_scalar(FloatMinus.monad(Noun(1)), -1.5)

    comptime FloatVectorConstant = ConstantNoun[FloatVectorProvider]
    var first = FloatVectorConstant.monad(Noun(0))
    first.float_values[0] = 99.0
    var second = FloatVectorConstant.monad(Noun(0))
    assert_float_vector(second, List[Float64]([1.5, 2.5]))
    assert_equal(FloatVectorConstant.monad_rank(), WHOLE_NOUN_RANK)
    assert_equal(Constant[7].monad(Noun(0)).as_int(), 7)


def test_exact_overflow_and_unsupported_valences() raises:
    with assert_raises(contains="Int overflow"):
        _ = Squared.monad(Noun(Int.MAX))
    with assert_raises(contains="Int overflow"):
        _ = Doubled.monad(Noun(Int.MAX))
    with assert_raises(contains="Insert dyad is unsupported"):
        _ = Insert[Plus].dyad(Noun(1), Noun(2))
    with assert_raises(contains="BindLeft dyad is unsupported"):
        _ = BindLeft[10, Plus].dyad(Noun(1), Noun(2))
    with assert_raises(contains="BindRightNoun dyad is unsupported"):
        _ = BindRightNoun[Plus, Float64NounProvider[2.5]].dyad(
            Noun(1), Noun(2)
        )


def main() raises:
    var groups: Int = 0
    test_noun_storage_rank_shape_and_reuse()
    groups += 1
    test_numeric_bool_promotion_and_agreement()
    groups += 1
    test_hooks_forks_composition_and_reductions()
    groups += 1
    test_atop_vs_compose_and_bound_ranks()
    groups += 1
    test_provider_bindings_and_constants()
    groups += 1
    test_exact_overflow_and_unsupported_valences()
    groups += 1
    print("PASS test_verbs: ", groups, " test groups")
