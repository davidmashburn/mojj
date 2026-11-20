"""Typed scalar/vector predicate and Boolean verb checks."""

from std.collections import List
from std.memory import bitcast
from std.testing import assert_equal, assert_raises, assert_true

from mojj.nouns import Noun
from mojj.predicates import (
    And,
    Complement,
    Equal,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    MatchHalve,
    Nand,
    Nor,
    Or,
    Unequal,
)
from mojj.verbs import Atop, Insert, Tally


def assert_bool_scalar(noun: Noun, expected: Bool) raises:
    assert_true(noun.is_scalar())
    assert_true(noun.is_bool())
    assert_equal(noun.as_bool(), expected)


def assert_bool_vector(noun: Noun, expected: List[Bool]) raises:
    assert_true(noun.is_vector())
    assert_true(noun.is_bool())
    assert_equal(noun.as_bools(), expected)


def test_comparisons() raises:
    var large = Int(9_007_199_254_740_992)
    assert_bool_scalar(Equal.dyad(Noun(large), Noun(large + 1)), False)
    assert_bool_scalar(Less.dyad(Noun(large), Noun(large + 1)), True)
    assert_bool_scalar(Unequal.dyad(Noun(large), Noun(large + 1)), True)
    assert_bool_scalar(Equal.dyad(Noun(large + 1), Noun(Float64(large))), True)
    assert_bool_scalar(Equal.dyad(Noun(True), Noun(1)), True)
    assert_bool_scalar(Equal.dyad(Noun(0.0), Noun(-0.0)), True)
    assert_bool_scalar(Equal.dyad(Noun(0.0), Noun(1.0e-20)), False)
    assert_bool_scalar(Equal.dyad(Noun(1.0), Noun(1.0000000000000568)), False)
    assert_bool_scalar(Equal.dyad(Noun(1.0), Noun(1.0000000000000566)), True)

    var close = Noun(2.0000000000001)
    var far = Noun(2.0000000000002)
    assert_bool_scalar(Equal.dyad(Noun(2.0), close), True)
    assert_bool_scalar(Equal.dyad(Noun(2.0), far), False)
    assert_bool_scalar(Less.dyad(Noun(2.0), close), False)
    assert_bool_scalar(Less.dyad(Noun(2.0), far), True)
    assert_bool_scalar(Greater.dyad(close, Noun(2.0)), False)
    assert_bool_scalar(Greater.dyad(far, Noun(2.0)), True)
    assert_bool_scalar(LessEqual.dyad(close, Noun(2.0)), True)
    assert_bool_scalar(LessEqual.dyad(far, Noun(2.0)), False)
    assert_bool_scalar(GreaterEqual.dyad(Noun(2.0), close), True)
    assert_bool_scalar(GreaterEqual.dyad(Noun(2.0), far), False)
    assert_bool_vector(
        Less.dyad(Noun(2), Noun(List[Int]([1, 3, 2]))), [False, True, False]
    )
    assert_bool_vector(
        Greater.dyad(Noun(List[Int]([1, 3, 2])), Noun(2)), [False, True, False]
    )
    assert_bool_vector(Equal.dyad(Noun(List[Int]()), Noun(2)), [])
    with assert_raises(contains="shape agreement failed"):
        _ = Equal.dyad(Noun(List[Int]([1])), Noun(List[Int]([1, 2])))
    with assert_raises(contains="unsupported"):
        _ = Equal.monad(Noun(List[Int]()))


def test_special_values() raises:
    var infinity = Noun(bitcast[DType.float64](UInt64(0x7FF0000000000000)))
    var nan = Noun(bitcast[DType.float64](UInt64(0x7FF8000000000000)))
    assert_bool_scalar(Equal.dyad(infinity, infinity), True)
    assert_bool_scalar(Equal.dyad(infinity, Noun(10.0)), False)
    assert_bool_scalar(Greater.dyad(infinity, Noun(10.0)), True)
    assert_bool_scalar(Equal.dyad(nan, nan), False)
    assert_bool_scalar(Unequal.dyad(nan, nan), True)
    assert_bool_scalar(LessEqual.dyad(nan, Noun(0.0)), False)
    assert_bool_scalar(GreaterEqual.dyad(Noun(0.0), nan), False)
    assert_bool_scalar(MatchHalve.dyad(nan, Noun(3.0)), True)


def test_match_and_numeric_monads() raises:
    var integers = Noun(List[Int]([2, 3]))
    assert_bool_scalar(
        MatchHalve.dyad(integers, Noun(List[Float64]([2.0000000000001, 3.0]))),
        True,
    )
    assert_bool_scalar(
        MatchHalve.dyad(integers, Noun(List[Int]([2, 4]))), False
    )
    assert_bool_scalar(MatchHalve.dyad(Noun(2), Noun(List[Int]([2]))), False)
    assert_bool_scalar(MatchHalve.dyad(integers, Noun(List[Int]([2]))), False)
    assert_bool_scalar(
        MatchHalve.dyad(Noun(List[Int]()), Noun(List[Float64]())), True
    )
    var atom_counts = Atop[Tally, Equal].dyad(integers, integers)
    assert_equal(atom_counts.as_ints(), List[Int]([1, 1]))
    assert_equal(Atop[Tally, MatchHalve].dyad(integers, integers).as_int(), 1)
    assert_equal(
        MatchHalve.monad(integers).as_floats(), List[Float64]([1.0, 1.5])
    )
    assert_equal(MatchHalve.monad(Noun(2)).as_float(), 1.0)
    assert_equal(
        LessEqual.monad(Noun(List[Bool]([False, True]))).as_ints(),
        List[Int]([-1, 0]),
    )
    assert_equal(
        GreaterEqual.monad(Noun(List[Bool]([False, True]))).as_ints(),
        List[Int]([1, 2]),
    )
    assert_equal(LessEqual.monad(Noun(2.5)).as_float(), 1.5)
    assert_equal(GreaterEqual.monad(Noun(2.5)).as_float(), 3.5)
    with assert_raises(contains="Int overflow"):
        _ = LessEqual.monad(Noun(Int.MIN))
    with assert_raises(contains="Int overflow"):
        _ = GreaterEqual.monad(Noun(Int.MAX))


def test_boolean_verbs_and_insert() raises:
    var flags = Noun(List[Bool]([True, False, True]))
    assert_bool_vector(Complement.monad(flags), [False, True, False])
    assert_equal(
        Complement.monad(Noun(List[Int]([2, 3]))).as_ints(), List[Int]([-1, -2])
    )
    assert_equal(Complement.monad(Noun(0.25)).as_float(), 0.75)
    assert_bool_vector(Or.dyad(flags, Noun(False)), [True, False, True])
    assert_bool_vector(And.dyad(Noun(1), flags), [True, False, True])
    assert_bool_vector(Nor.dyad(flags, Noun(0.0)), [False, True, False])
    assert_bool_vector(
        Nand.dyad(Noun(1.000000000000001), flags), [False, True, False]
    )
    assert_bool_vector(Nand.dyad(Noun(3), Noun(List[Bool]())), [])
    with assert_raises(contains="requires values of 0 or 1"):
        _ = And.dyad(Noun(False), Noun(2))
    with assert_raises(contains="requires values of 0 or 1"):
        _ = Nor.dyad(Noun(True), Noun(1.0e-20))
    with assert_raises(contains="unsupported"):
        _ = Complement.dyad(Noun(True), Noun(True))

    var empty = Noun(List[Float64]())
    assert_bool_scalar(Insert[Or].monad(empty), False)
    assert_bool_scalar(Insert[And].monad(empty), True)
    assert_bool_scalar(Insert[Less].monad(empty), False)
    assert_bool_scalar(Insert[Greater].monad(empty), False)
    assert_bool_scalar(Insert[Equal].monad(empty), True)
    assert_bool_scalar(Insert[Unequal].monad(empty), False)
    assert_bool_scalar(Insert[LessEqual].monad(empty), True)
    assert_bool_scalar(Insert[GreaterEqual].monad(empty), True)
    assert_bool_scalar(Insert[Or].monad(flags), True)
    assert_bool_scalar(Insert[And].monad(flags), False)
    with assert_raises(contains="identity"):
        _ = Insert[Nor].monad(empty)
    with assert_raises(contains="identity"):
        _ = Insert[Nand].monad(empty)
    with assert_raises(contains="identity"):
        _ = Insert[MatchHalve].monad(empty)


def main() raises:
    test_comparisons()
    test_special_values()
    test_match_and_numeric_monads()
    test_boolean_verbs_and_insert()
