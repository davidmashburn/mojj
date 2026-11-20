from std.collections import List
from std.math import copysign, inf, isnan, nan
from std.testing import assert_equal, assert_raises, assert_true

from mojj.nouns import Noun, NounDType
from mojj.real_verbs import (
    CeilingMax,
    FloorMin,
    Logarithm,
    MagnitudeResidue,
    NthRoot,
    Power,
)
from mojj.verbs import Insert


def _assert_close(actual: Float64, expected: Float64) raises:
    assert_true(
        abs(actual - expected) <= 1.0e-13 * (1.0 + abs(expected)),
        "Float64 value differs",
    )


def _test_floor_ceiling_and_extrema() raises:
    var near_negative = Noun(-1.00000000000001)
    var near_positive = Noun(1.00000000000001)
    assert_equal(FloorMin.monad(near_negative).as_int(), -1)
    assert_equal(CeilingMax.monad(near_positive).as_int(), 1)
    assert_equal(FloorMin.monad(Noun(-1.0000000001)).as_int(), -2)
    assert_equal(CeilingMax.monad(Noun(1.0e-14)).as_int(), 1)
    assert_equal(FloorMin.monad(Noun(Int.MAX)).as_int(), Int.MAX)
    assert_true(CeilingMax.monad(Noun(True)).as_bool())

    var infinity = inf[DType.float64]()
    var rounded = FloorMin.monad(Noun(List[Float64]([1.2, infinity, -2.2])))
    assert_true(rounded.is_vector() and rounded.is_float64())
    assert_equal(rounded.at(0).as_float(), 1.0)
    assert_equal(rounded.at(1).as_float(), infinity)
    assert_equal(rounded.at(2).as_float(), -3.0)
    assert_true(isnan(FloorMin.monad(Noun(nan[DType.float64]())).as_float()))
    assert_true(FloorMin.monad(Noun(List[Float64]())).is_int())

    var exact = Noun(List[Int]([9007199254740993, 9007199254740995]))
    var limit = Noun(9007199254740994)
    assert_equal(FloorMin.dyad(exact, limit).at(0).as_int(), 9007199254740993)
    assert_equal(CeilingMax.dyad(exact, limit).at(1).as_int(), 9007199254740995)
    assert_equal(FloorMin.dyad(near_positive, Noun(1.0)).as_float(), 1.0)
    assert_equal(CeilingMax.dyad(Noun(1.0), near_positive).as_float(), near_positive.as_float())
    assert_equal(Insert[FloorMin].monad(exact).as_int(), 9007199254740993)
    assert_equal(Insert[CeilingMax].monad(exact).as_int(), 9007199254740995)
    assert_equal(Insert[FloorMin].monad(Noun(List[Int]())).as_float(), infinity)
    assert_equal(Insert[CeilingMax].monad(Noun(List[Int]())).as_float(), -infinity)


def _test_magnitude_and_residue() raises:
    assert_equal(MagnitudeResidue.monad(Noun(-9007199254740993)).as_int(), 9007199254740993)
    assert_equal(MagnitudeResidue.monad(Noun(Int.MIN)).as_float(), -Float64(Int.MIN))
    assert_equal(MagnitudeResidue.dyad(Noun(-3), Noun(5)).as_int(), -1)
    assert_equal(MagnitudeResidue.dyad(Noun(3), Noun(-5)).as_int(), 1)
    assert_equal(MagnitudeResidue.dyad(Noun(0), Noun(Int.MIN)).as_int(), Int.MIN)
    assert_equal(MagnitudeResidue.dyad(Noun(-1), Noun(Int.MIN)).as_int(), 0)
    assert_equal(MagnitudeResidue.dyad(Noun(Int.MIN), Noun(1)).as_int(), Int.MIN + 1)
    assert_equal(MagnitudeResidue.dyad(Noun(3.0), Noun(2.99999999999999)).as_float(), 0.0)
    _assert_close(MagnitudeResidue.dyad(Noun(-3.0), Noun(-4.5)).as_float(), -1.5)
    assert_equal(copysign(1.0, MagnitudeResidue.monad(Noun(-0.0)).as_float()), -1.0)
    assert_equal(MagnitudeResidue.dyad(Noun(inf[DType.float64]()), Noun(3)).as_float(), 3.0)
    with assert_raises(contains="infinite dividend"):
        _ = MagnitudeResidue.dyad(Noun(3), Noun(inf[DType.float64]()))


def _test_power_logarithm_and_root() raises:
    var infinity = inf[DType.float64]()
    _assert_close(Power.monad(Noun(50)).as_float(), 5.184705528587072e21)
    assert_equal(Power.dyad(Noun(-1), Noun(9007199254740993)).as_float(), -1.0)
    assert_equal(Power.dyad(Noun(Int.MAX), Noun(True)).as_int(), Int.MAX)
    assert_equal(Power.dyad(Noun(0), Noun(False)).as_int(), 1)
    assert_equal(Power.dyad(Noun(-2), Noun(3)).as_float(), -8.0)
    assert_equal(Power.dyad(Noun(0), Noun(-3)).as_float(), infinity)
    assert_equal(Power.dyad(Noun(-0.0), Noun(-3.0)).as_float(), infinity)
    assert_equal(Power.dyad(Noun(-0.0), Noun(-3)).as_float(), -infinity)
    with assert_raises(contains="requires Complex"):
        _ = Power.dyad(Noun(-2), Noun(2.00000000000001))

    _assert_close(Logarithm.monad(Noun(50)).as_float(), 3.912023005428146)
    _assert_close(Logarithm.dyad(Noun(2), Noun(8)).as_float(), 3.0)
    assert_equal(Logarithm.monad(Noun(0)).as_float(), -infinity)
    assert_equal(Logarithm.monad(Noun(infinity)).as_float(), infinity)
    assert_equal(Logarithm.dyad(Noun(1), Noun(1)).as_float(), 0.0)
    with assert_raises(contains="infinite logarithms"):
        _ = Logarithm.dyad(Noun(0), Noun(0))
    with assert_raises(contains="requires Complex"):
        _ = Logarithm.monad(Noun(-1))

    var roots = NthRoot.dyad(Noun(3), Noun(List[Int]([8, 27, 64])))
    _assert_close(roots.at(0).as_float(), 2.0)
    _assert_close(roots.at(1).as_float(), 3.0)
    _assert_close(roots.at(2).as_float(), 4.0)
    assert_equal(NthRoot.dyad(Noun(0), Noun(2)).as_float(), infinity)
    assert_equal(NthRoot.dyad(Noun(-1), Noun(-2)).as_float(), -0.5)
    assert_equal(copysign(1.0, NthRoot.dyad(Noun(2), Noun(-0.0)).as_float()), 1.0)
    with assert_raises(contains="requires Complex"):
        _ = NthRoot.dyad(Noun(3), Noun(-8))


def main() raises:
    _test_floor_ceiling_and_extrema()
    _test_magnitude_and_residue()
    _test_power_logarithm_and_root()
    print("Real verb tests passed")
