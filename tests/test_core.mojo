from std.collections import List
from std.math import sqrt
from std.testing import assert_equal, assert_raises, assert_true

import mojj as jj


struct Cube(jj.ScalarOp):
    @staticmethod
    def apply(x: Float64) -> Float64:
        return x * x * x

    @staticmethod
    def describe() -> String:
        return "cube"


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


def test_noncommuting_composition() raises:
    comptime AddThenScale = jj.Map[
        jj.Compose[jj.Scale[3], jj.Add[2]]
    ]
    comptime ScaleThenAdd = jj.Map[
        jj.Compose[jj.Add[2], jj.Scale[3]]
    ]

    var data: List[Float64] = [-2.0, 0.5, 3.0]
    var add_then_scale = jj.materialize[AddThenScale](data)
    var scale_then_add = jj.materialize[ScaleThenAdd](data)
    var expected_add_then_scale: List[Float64] = [0.0, 0.0, 0.0]
    var expected_scale_then_add: List[Float64] = [0.0, 0.0, 0.0]

    for index in range(len(data)):
        # These expectations deliberately spell out arithmetic independently
        # of Compose and its primitive ScalarOp implementations.
        expected_add_then_scale[index] = (data[index] + 2.0) * 3.0
        expected_scale_then_add[index] = data[index] * 3.0 + 2.0

    assert_list_close(
        add_then_scale,
        expected_add_then_scale,
        "Compose must apply its inner operation before its outer operation",
    )
    assert_list_close(
        scale_then_add,
        expected_scale_then_add,
        "reversing composition order must reverse the arithmetic order",
    )
    assert_true(
        add_then_scale[0] != scale_then_add[0],
        "noncommuting composition unexpectedly produced the same result",
    )


def test_nested_maps_match_manual_arithmetic() raises:
    comptime Nested = jj.Map[
        jj.Scale[3], jj.Map[jj.Add[2], jj.Map[jj.Square]]
    ]
    comptime Fused = jj.Map[
        jj.Compose[jj.Scale[3], jj.Compose[jj.Add[2], jj.Square]]
    ]

    var data: List[Float64] = [1.0, -2.0, 3.5, -4.0]
    var nested = jj.materialize[Nested](data)
    var fused = jj.materialize[Fused](data)
    var expected: List[Float64] = [0.0, 0.0, 0.0, 0.0]

    for index in range(len(data)):
        var squared = data[index] * data[index]
        var shifted = squared + 2.0
        expected[index] = shifted * 3.0

    assert_list_close(
        nested,
        expected,
        "nested lazy maps differ from independently spelled arithmetic",
    )
    assert_list_close(
        fused,
        expected,
        "scalar composition differs from independently spelled arithmetic",
    )


def test_identity_default_source_and_fresh_materialization() raises:
    comptime IdentityMap = jj.Map[jj.Identity]
    comptime ExplicitIdentityMap = jj.Map[jj.Identity, jj.Input]

    var data: List[Float64] = [4.0, -1.5, 0.0, 8.25]
    var before: List[Float64] = [4.0, -1.5, 0.0, 8.25]
    var output = jj.materialize[IdentityMap](data)
    var explicit_output = jj.materialize[ExplicitIdentityMap](data)

    assert_list_close(output, data, "default Map source is not Input")
    assert_list_close(
        explicit_output,
        data,
        "explicit Input source changed identity mapping",
    )

    # Mutating a materialized result must not mutate the borrowed input.
    output[0] = 999.0
    assert_equal(data[0], before[0], "materialize did not return a fresh result")
    for index in range(len(data)):
        assert_equal(data[index], before[index], "mapping changed its input")


def test_sum_mean_and_rms() raises:
    comptime SquaredMean = jj.Mean[jj.Map[jj.Square]]
    comptime RMS = jj.After[jj.Sqrt, SquaredMean]

    var data: List[Float64] = [1.0, -2.0, 3.0, -4.0]
    # Independent left-to-right expectations: sum=-2, square sum=30.
    var sum = jj.evaluate[jj.Sum[jj.Input]](data)
    var mean = jj.evaluate[SquaredMean](data)
    var rms = jj.evaluate[RMS](data)

    assert_equal(sum, -2.0)
    assert_close(mean, 7.5, "mean of lazily squared values is incorrect")
    assert_close(rms, sqrt(7.5), "RMS post-transform is incorrect")


def test_negation_and_default_reductions() raises:
    comptime PlainSum = jj.Sum[]
    comptime PlainMean = jj.Mean[]
    var data: List[Float64] = [-2.0, 0.5, 3.0]
    var expected: List[Float64] = [2.0, -0.5, -3.0]
    var negated = jj.materialize[jj.Map[jj.Negate]](data)
    assert_list_close(negated, expected, "negation changed the wrong values")
    assert_equal(jj.evaluate[PlainSum](data), 1.5)
    assert_equal(jj.evaluate[PlainMean](data), 0.5)
    assert_equal(jj.Add[-2].apply(0.5), -1.5)
    assert_equal(jj.Scale[-3].apply(0.5), -1.5)


def test_left_to_right_naive_accumulation() raises:
    comptime PlainSum = jj.Sum[jj.Input]
    # At Float64 precision, left-to-right naive addition loses the middle 1.
    var data: List[Float64] = [9007199254740992.0, 1.0, -9007199254740992.0]
    var value = jj.evaluate[PlainSum](data)
    assert_equal(value, 0.0)


def test_empty_map_sum_and_mean_error() raises:
    comptime EmptyMap = jj.Map[jj.Square]
    var empty: List[Float64] = []
    var mapped = jj.materialize[EmptyMap](empty)

    assert_equal(len(mapped), 0)
    assert_equal(jj.evaluate[jj.Sum[jj.Input]](empty), 0.0)
    with assert_raises(contains="mean requires nonempty input"):
        _ = jj.evaluate[jj.Mean[jj.Input]](empty)


def test_runtime_lengths_reuse_compile_time_plans() raises:
    comptime Pipeline = jj.Map[jj.Compose[jj.Scale[3], jj.Add[2]]]
    comptime RMS = jj.After[jj.Sqrt, jj.Mean[jj.Map[jj.Square]]]

    var short_data: List[Float64] = [1.0, -2.0]
    var long_data: List[Float64] = [-3.0, 0.0, 4.0, 5.0, -1.0]
    var short_output = jj.materialize[Pipeline](short_data)
    var long_output = jj.materialize[Pipeline](long_data)
    var short_expected: List[Float64] = [9.0, 0.0]
    var long_expected: List[Float64] = [-3.0, 6.0, 18.0, 21.0, 3.0]

    assert_list_close(
        short_output,
        short_expected,
        "pipeline failed for the first runtime length",
    )
    assert_list_close(
        long_output,
        long_expected,
        "pipeline failed for the second runtime length",
    )
    assert_close(
        jj.evaluate[RMS](short_data),
        sqrt(2.5),
        "RMS failed for the short runtime length",
    )
    assert_close(
        jj.evaluate[RMS](long_data),
        sqrt(51.0 / 5.0),
        "RMS failed for the long runtime length",
    )


def test_custom_scalar_extension() raises:
    comptime Cubed = jj.Map[Cube]
    comptime CubedSum = jj.Sum[Cubed]

    var data: List[Float64] = [-2.0, 0.5, 3.0]
    var output = jj.materialize[Cubed](data)
    var expected: List[Float64] = [-8.0, 0.125, 27.0]

    assert_list_close(
        output,
        expected,
        "custom Cube ScalarOp differs from independently calculated cubes",
    )
    assert_close(
        jj.evaluate[CubedSum](data),
        19.125,
        "reduction over a custom ScalarOp is incorrect",
    )


def test_compile_time_descriptions() raises:
    comptime Primitive = jj.Compose[jj.Scale[3], jj.Add[2]]
    comptime Pipeline = jj.Map[Primitive]
    comptime Nested = jj.Map[jj.Scale[3], jj.Map[jj.Add[2], jj.Map[jj.Square]]]
    comptime RMS = jj.After[jj.Sqrt, jj.Mean[jj.Map[jj.Square]]]
    comptime Cubed = jj.Map[Cube]

    comptime identity_text = jj.Identity.describe()
    comptime negate_text = jj.Negate.describe()
    comptime square_text = jj.Square.describe()
    comptime sqrt_text = jj.Sqrt.describe()
    comptime add_text = jj.Add[2].describe()
    comptime scale_text = jj.Scale[3].describe()
    comptime compose_text = Primitive.describe()
    comptime input_text = jj.Input.describe()
    comptime pipeline_text = Pipeline.describe()
    comptime nested_text = Nested.describe()
    comptime sum_text = jj.Sum[jj.Input].describe()
    comptime mean_text = jj.Mean[jj.Map[jj.Square]].describe()
    comptime rms_text = RMS.describe()
    comptime cube_text = Cube.describe()
    comptime cubed_text = Cubed.describe()

    assert_equal(identity_text, "identity")
    assert_equal(negate_text, "negate")
    assert_equal(square_text, "square")
    assert_equal(sqrt_text, "sqrt")
    assert_equal(add_text, "add[2]")
    assert_equal(scale_text, "scale[3]")
    assert_equal(compose_text, "compose(scale[3], add[2])")
    assert_equal(input_text, "input")
    assert_equal(pipeline_text, "map(compose(scale[3], add[2]), input)")
    assert_equal(nested_text, "map(scale[3], map(add[2], map(square, input)))")
    assert_equal(sum_text, "sum(input)")
    assert_equal(mean_text, "mean(map(square, input))")
    assert_equal(rms_text, "after(sqrt, mean(map(square, input)))")
    assert_equal(cube_text, "cube")
    assert_equal(cubed_text, "map(cube, input)")


def main() raises:
    var groups: Int = 0
    test_noncommuting_composition()
    groups += 1
    test_nested_maps_match_manual_arithmetic()
    groups += 1
    test_identity_default_source_and_fresh_materialization()
    groups += 1
    test_sum_mean_and_rms()
    groups += 1
    test_negation_and_default_reductions()
    groups += 1
    test_left_to_right_naive_accumulation()
    groups += 1
    test_empty_map_sum_and_mean_error()
    groups += 1
    test_runtime_lengths_reuse_compile_time_plans()
    groups += 1
    test_custom_scalar_extension()
    groups += 1
    test_compile_time_descriptions()
    groups += 1
    print("PASS test_core: ", groups, " test groups")
    print(
        "RESULT: composition, lazy maps, reductions, empty behavior, "
        "runtime lengths, preservation, descriptions, and custom Cube passed"
    )
