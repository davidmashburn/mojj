from std.collections import List
from std.math import copysign, inf, isnan, nan
from std.testing import assert_equal, assert_raises, assert_true

from mojj.circle import Circle
from mojj.nouns import Noun


def _close(actual: Float64, expected: Float64) raises:
    assert_true(
        abs(actual - expected) <= 1.0e-13 * abs(expected),
        "Circle result differs from pinned J",
    )


def main() raises:
    _close(Circle.monad(Noun(2)).as_float(), 6.283185307179586)
    var selectors = Noun(List[Int]([1, 2, 3]))
    var trig_boundary = Noun(596313653.72958016)
    var trig = Circle.dyad(selectors, trig_boundary)
    _close(trig.at(0).as_float(), -0.70377352858837749)
    _close(trig.at(1).as_float(), -0.71042439461090034)
    _close(trig.at(2).as_float(), 0.9906381789913542)
    _close(Circle.dyad(Noun(3), Noun(1.5707963267948963)).as_float(), 3530114321217157.5)
    with assert_raises(contains="supported magnitude"):
        _ = Circle.dyad(Noun(1), Noun(596313653.72958028))

    var infinity = inf[DType.float64]()
    _close(Circle.dyad(Noun(5), Noun(710)).as_float(), 1.1169973830808555e308)
    _close(Circle.dyad(Noun(6), Noun(710)).as_float(), 1.1169973830808555e308)
    assert_equal(Circle.dyad(Noun(5), Noun(-711)).as_float(), -infinity)
    assert_equal(Circle.dyad(Noun(6), Noun(-711)).as_float(), infinity)
    assert_equal(Circle.dyad(Noun(7), Noun(infinity)).as_float(), 1.0)
    _close(Circle.dyad(Noun(-5), Noun(-1e200)).as_float(), -461.21016577936911)
    _close(Circle.dyad(Noun(-6), Noun(1e200)).as_float(), 461.21016577936911)
    assert_equal(Circle.dyad(Noun(-7), Noun(1)).as_float(), infinity)
    assert_equal(Circle.dyad(Noun(-7), Noun(-1)).as_float(), -infinity)

    _close(Circle.dyad(Noun(-4), Noun(-1.0000000000000002)).as_float(), -2.1073424255447017e-8)
    assert_equal(copysign(1.0, Circle.dyad(Noun(-4), Noun(-1)).as_float()), 1.0)
    assert_equal(copysign(1.0, Circle.dyad(Noun(10), Noun(-0.0)).as_float()), -1.0)
    assert_true(isnan(Circle.dyad(Noun(5), Noun(nan[DType.float64]())).as_float()))
    with assert_raises(contains="supported selector and real result"):
        _ = Circle.dyad(Noun(-1), Noun(1.00000000000001))
    with assert_raises(contains="supported selector and real result"):
        _ = Circle.dyad(Noun(1.00000000000001), Noun(0.4))
    with assert_raises(contains="supported selector and real result"):
        _ = Circle.dyad(Noun(-12), Noun(1))
    assert_equal(Circle.dyad(Noun(-12), Noun(0)).as_float(), 1.0)
    print("Circle tests passed")
