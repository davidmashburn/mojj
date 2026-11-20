from std.collections import List
from std.math import inf, nan
from std.testing import assert_equal, assert_raises
from mojj import Input, Map, Mean, PopulationMoments, Square


def main() raises:
    var data: List[Float64] = [-1.0, 1.0, -3.0, 3.0]
    var mapped = PopulationMoments[Map[Square]].evaluate(data)
    assert_equal(mapped.mean, 5.0)
    assert_equal(mapped.variance, 16.0)
    assert_equal(PopulationMoments[].evaluate(data).variance, 5.0)

    # The known variance is tiny compared with the squares of the observations.
    var offset: Float64 = 1.0e12
    var shifted: List[Float64] = [offset - 3, offset - 1, offset + 1, offset + 3]
    var large = PopulationMoments[].evaluate(shifted)
    assert_equal(large.mean, offset)
    assert_equal(large.variance, 5.0)

    # The exact midpoint is unrepresentable. Centered differences are ±1.
    var adjacent: List[Float64] = [1.0e16, 1.0e16 + 2.0]
    var nearby = PopulationMoments[].evaluate(adjacent)
    assert_equal(nearby.mean, 1.0e16)
    assert_equal(nearby.variance, 1.0)

    # Reusing Welford's mean changes the rounding of the existing Mean API.
    var rounding: List[Float64] = [1.0e16, 1.0, 1.0]
    assert_equal(Mean[Input].evaluate(rounding), 3333333333333333.5)
    assert_equal(PopulationMoments[].evaluate(rounding).mean, 3333333333333334.0)

    var single: List[Float64] = [7.0]
    var one = PopulationMoments[].evaluate(single)
    assert_equal(one.mean, 7.0)
    assert_equal(one.variance, 0.0)
    var constant: List[Float64] = [3.0, 3.0, 3.0]
    assert_equal(PopulationMoments[].evaluate(constant).variance, 0.0)
    with assert_raises(contains="at least one"):
        _ = PopulationMoments[].evaluate(List[Float64]())
    var invalid: List[Float64] = [inf[DType.float64](), nan[DType.float64]()]
    for value in invalid:
        with assert_raises(contains="finite"):
            _ = PopulationMoments[].evaluate([value])
    var overflowing: List[Float64] = [-1.0e308, 1.0e308]
    with assert_raises(contains="finite"):
        _ = PopulationMoments[].evaluate(overflowing)
    assert_equal(
        PopulationMoments[Map[Square]].describe(), "population_moments(map(square, input))"
    )
    print("PASS population moments checks")
