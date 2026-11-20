"""Matched mean + population-variance timings over the same mapped source.

Run with:
  pixi run mojo run --fp-mode contract=off -I src tests/perf/moments.mojo

Each size has twelve matched samples: all six run orders, repeated twice.
Input construction and correctness checks are outside the measured regions.
Each measured call changes one input cell and makes the input and both outputs
observable, so a repeated reduction cannot be hoisted out of the repetition loop.
The common input-update and sink overhead remains included in all three timings.
"""

from std.benchmark import keep
from std.collections import List
from std.math import inf, isfinite, nan
from std.testing import assert_equal, assert_raises
from std.time import perf_counter_ns

from mojj import Map, Mean, Moments, PopulationMoments, Square


comptime Source = Map[Square]
comptime ORDER_PERMUTATIONS = 6
comptime SAMPLES = 2 * ORDER_PERMUTATIONS
comptime SMALL_SIZE = 1_000
comptime LARGE_SIZE = 100_000
comptime ELEMENTS_PER_SAMPLE = 10_000_000
comptime INDEPENDENT_NAME = "independent"
comptime SHARED_NAME = "shared"
comptime TWO_PASS_NAME = "two_pass"
comptime FLOAT64_EPSILON = 2.220446049250313e-16


struct Method(ImplicitlyCopyable, Equatable):
    var code: Int

    def __init__(out self, code: Int):
        self.code = code

    comptime INDEPENDENT = Self(0)
    comptime SHARED = Self(1)
    comptime TWO_PASS = Self(2)

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return not self == other

    def name(self) raises -> String:
        if self == Self.INDEPENDENT:
            return INDEPENDENT_NAME
        if self == Self.SHARED:
            return SHARED_NAME
        if self == Self.TWO_PASS:
            return TWO_PASS_NAME
        raise Error("unknown benchmark method")


def assert_close(actual: Float64, expected: Float64, label: String) raises:
    if not isfinite(actual) or abs(actual - expected) > 1.0e-10 * (
        1.0 + abs(expected)
    ):
        raise Error(label + ": got " + String(actual) + ", expected " + String(expected))


def reference(data: List[Float64]) -> Tuple[Float64, Float64]:
    # Independently shift the explicitly squared values by the first value.
    # This reference avoids summing a large common offset and does not reuse
    # either the production mean or the corrected second-moment formula.
    var origin = data[0] * data[0]
    var shifted_total: Float64 = 0.0
    for index in range(len(data)):
        shifted_total += data[index] * data[index] - origin
    var shifted_mean = shifted_total / Float64(len(data))
    var centered_total: Float64 = 0.0
    for index in range(len(data)):
        var difference = (data[index] * data[index] - origin) - shifted_mean
        centered_total += difference * difference
    return origin + shifted_mean, centered_total / Float64(len(data))


# Keep the independent reductions in separate calls. This also prevents an
# optimizer from sharing their source traversals across the benchmark boundary.
@no_inline
def mean_kernel(data: List[Float64]) raises -> Float64:
    return Mean[Source].evaluate(data)


@no_inline
def variance_kernel(data: List[Float64]) raises -> Float64:
    return PopulationMoments[Source].evaluate(data).variance


@no_inline
def shared_kernel(data: List[Float64]) raises -> Moments:
    return PopulationMoments[Source].evaluate(data)


def corrected_population_variance(
    centered_total: Float64, residual_total: Float64, count: Int,
) raises -> Float64:
    if not isfinite(centered_total) or not isfinite(residual_total):
        raise Error("two-pass moments require finite values and intermediates")
    var centered_average = centered_total / Float64(count)
    var residual_mean = residual_total / Float64(count)
    # Divide before squaring: residual_total**2 can overflow even when the
    # correction and the final population variance are both representable.
    # Subtracting similar terms can still lose a tiny variance if Mean is far
    # from the observations. These are ordinary, unscaled Float64 sums.
    var correction = residual_mean * residual_mean
    var variance = centered_average - correction
    if not isfinite(correction) or not isfinite(variance):
        raise Error("two-pass moments require finite values and intermediates")
    if variance < 0.0:
        # Both left-to-right accumulators can round. Clamp a negative result
        # only within a conservative O(n * epsilon) relative error allowance;
        # a larger inconsistency is an error rather than a zero variance.
        var relative_roundoff = 8.0 * Float64(count) * FLOAT64_EPSILON
        if centered_average <= 0.0 or -variance / centered_average > relative_roundoff:
            raise Error("two-pass variance is negative beyond roundoff")
        return 0.0
    return variance


@no_inline
def two_pass_kernel(data: List[Float64]) raises -> Moments:
    # Reuse the existing left-to-right Mean exactly, then traverse the lazy
    # mapped source again without allocating a mapped or centered temporary.
    var mean = Mean[Source].evaluate(data)
    if not isfinite(mean):
        raise Error("two-pass moments require finite values and intermediates")
    var centered_total: Float64 = 0.0
    var residual_total: Float64 = 0.0
    for index in range(len(data)):
        var difference = Source.read(data, index) - mean
        centered_total += difference * difference
        residual_total += difference
    return Moments(
        mean, corrected_population_variance(centered_total, residual_total, len(data))
    )


def verify(data: List[Float64]) raises:
    var expected = reference(data)
    var independent_mean = mean_kernel(data)
    var shared = shared_kernel(data)
    var two_pass = two_pass_kernel(data)
    assert_close(independent_mean, expected[0], "independent mean")
    assert_close(variance_kernel(data), expected[1], "independent variance")
    assert_close(shared.mean, expected[0], "shared mean")
    assert_close(shared.variance, expected[1], "shared variance")
    if two_pass.mean != independent_mean:
        raise Error("two-pass mean must preserve existing Mean rounding")
    assert_close(two_pass.variance, expected[1], "two-pass variance")


def verify_two_pass_numerics() raises:
    # Every mapped observation is exactly 1e16. A naive second pass around
    # the rounded left-to-right Mean reports 720815104 instead of zero.
    var constant = List[Float64](length=LARGE_SIZE, fill=1.0e8)
    var online = shared_kernel(constant)
    var centered = two_pass_kernel(constant)
    assert_equal(Source.read(constant, 0), 1.0e16)
    assert_equal(online.variance, 0.0)
    assert_equal(centered.variance, 0.0)
    verify(constant)

    # The represented mapped values are exactly 1e16 - 2 and 1e16 + 2,
    # equally frequent, so their population variance is exactly four.
    var clustered = List[Float64](length=LARGE_SIZE, fill=0.0)
    for index in range(LARGE_SIZE):
        clustered[index] = (
            99999999.99999999 if index % 2 == 0 else 100000000.00000001
        )
    assert_equal(Source.read(clustered, 0), 9999999999999998.0)
    assert_equal(Source.read(clustered, 1), 10000000000000002.0)
    assert_close(two_pass_kernel(clustered).variance, 4.0, "clustered variance")
    verify(clustered)

    # For n-1 observations a and one b, variance=(b-a)^2 * (n-1)/n^2.
    # This closed form is independent of either running-moment algorithm.
    var outlier = List[Float64](length=LARGE_SIZE, fill=1.0e8)
    outlier[LARGE_SIZE - 1] = 2.0e8
    var proportion = 1.0 / Float64(LARGE_SIZE)
    var expected_outlier = 9.0e32 * proportion * (1.0 - proportion)
    assert_close(
        two_pass_kernel(outlier).variance, expected_outlier, "outlier variance"
    )
    verify(outlier)

    # A second closed-form two-point fixture makes the residual sum large
    # enough that squaring it before division overflows, while M2 is finite.
    var low: Float64 = 1.0e81
    var high: Float64 = 1.0e81 + 1.0e70
    var large_clustered = List[Float64](length=LARGE_SIZE, fill=low)
    for index in range(1, LARGE_SIZE, 2):
        large_clustered[index] = high
    var large = two_pass_kernel(large_clustered)
    var half_gap = (high * high - low * low) / 2.0
    var expected_large = half_gap * half_gap
    var expected_residual_total = Float64(LARGE_SIZE // 2) * (
        (low * low - large.mean) + (high * high - large.mean)
    )
    if isfinite(expected_residual_total * expected_residual_total):
        raise Error("large-residual fixture must overflow before scaling")
    assert_equal(large.mean, mean_kernel(large_clustered))
    assert_close(large.variance, expected_large, "large-residual variance")
    assert_close(reference(large_clustered)[1], expected_large, "large reference")

    # Exercise the explicit negative-roundoff policy independently of data
    # that happens to yield exactly representable accumulation intermediates.
    assert_equal(
        corrected_population_variance(999.9999999999999, 1000.0, 1000), 0.0
    )
    with assert_raises(contains="negative beyond roundoff"):
        _ = corrected_population_variance(500.0, 1000.0, 1000)
    with assert_raises(contains="finite"):
        _ = corrected_population_variance(1.0, 1.0e200, 1)
    with assert_raises(contains="nonempty"):
        _ = two_pass_kernel(List[Float64]())
    var invalid: List[Float64] = [
        inf[DType.float64](), nan[DType.float64](), 1.0e200,
    ]
    for value in invalid:
        with assert_raises(contains="finite"):
            _ = two_pass_kernel([value])
    var mean_overflow: List[Float64] = [1.0e154, 1.0e154]
    with assert_raises(contains="finite"):
        _ = two_pass_kernel(mean_overflow)
    var moment_overflow: List[Float64] = [0.0, 1.0e100]
    with assert_raises(contains="finite"):
        _ = two_pass_kernel(moment_overflow)
    print(
        "# corrected_two_pass_checks=constant+clustered+outlier"
        "+large_residual+finite_errors+roundoff_policy"
    )
    print(
        "# constant_source_variance: shared=", online.variance,
        ", two_pass=", centered.variance, sep="",
    )


def make_data(size: Int, seed: Int) -> List[Float64]:
    var data = List[Float64](length=size, fill=0.0)
    for index in range(size):
        data[index] = Float64((index * 37 + seed) % 257 - 128) / 32.0
    return data^


def measure[method: Method](
    mut data: List[Float64], baseline: Float64, sample: Int, order: Int, reps: Int,
) raises -> Float64:
    var sink: Float64 = 0.0
    var start = perf_counter_ns()
    for iteration in range(reps):
        data[0] = baseline + Float64((iteration + sample * 13) % 31) / 128.0
        keep(data.unsafe_ptr())
        var mean: Float64
        var variance: Float64
        comptime if method == Method.SHARED:
            var result = shared_kernel(data)
            mean = result.mean
            variance = result.variance
        elif method == Method.INDEPENDENT:
            mean = mean_kernel(data)
            variance = variance_kernel(data)
        elif method == Method.TWO_PASS:
            var result = two_pass_kernel(data)
            mean = result.mean
            variance = result.variance
        else:
            raise Error("unknown benchmark method")
        keep(mean)
        keep(variance)
        sink += mean + variance
    var elapsed = Int(perf_counter_ns() - start)
    keep(sink)
    if elapsed <= 0 or not isfinite(sink):
        raise Error("invalid elapsed time or nonfinite benchmark sink")
    var label = method.name()
    var ns_per_call = Float64(elapsed) / Float64(reps)
    print(
        len(data), sample, order, label, reps, elapsed, ns_per_call,
        ns_per_call / Float64(len(data)), sink, sep=",",
    )
    return sink


def run_sample[first: Method, second: Method, third: Method](
    mut data: List[Float64], baseline: Float64, sample: Int, reps: Int,
) raises:
    var first_sink = measure[first](data, baseline, sample, 1, reps)
    var second_sink = measure[second](data, baseline, sample, 2, reps)
    var third_sink = measure[third](data, baseline, sample, 3, reps)
    assert_close(second_sink, first_sink, "matched sample second sink")
    assert_close(third_sink, first_sink, "matched sample third sink")


def run_size(size: Int, seed: Int) raises:
    var data = make_data(size, seed)
    var baseline = data[0]
    var reps = ELEMENTS_PER_SAMPLE // size
    verify(data)

    # Warm each kernel before collecting any path's samples.
    keep(mean_kernel(data))
    keep(variance_kernel(data))
    var warm_shared = shared_kernel(data)
    keep(warm_shared.mean)
    keep(warm_shared.variance)
    var warm_two_pass = two_pass_kernel(data)
    keep(warm_two_pass.mean)
    keep(warm_two_pass.variance)

    for sample in range(SAMPLES):
        var permutation = sample % ORDER_PERMUTATIONS
        if permutation == 0:
            run_sample[Method.INDEPENDENT, Method.SHARED, Method.TWO_PASS](
                data, baseline, sample, reps,
            )
        elif permutation == 1:
            run_sample[Method.INDEPENDENT, Method.TWO_PASS, Method.SHARED](
                data, baseline, sample, reps,
            )
        elif permutation == 2:
            run_sample[Method.SHARED, Method.INDEPENDENT, Method.TWO_PASS](
                data, baseline, sample, reps,
            )
        elif permutation == 3:
            run_sample[Method.SHARED, Method.TWO_PASS, Method.INDEPENDENT](
                data, baseline, sample, reps,
            )
        elif permutation == 4:
            run_sample[Method.TWO_PASS, Method.INDEPENDENT, Method.SHARED](
                data, baseline, sample, reps,
            )
        else:
            run_sample[Method.TWO_PASS, Method.SHARED, Method.INDEPENDENT](
                data, baseline, sample, reps,
            )
        verify(data)


def main() raises:
    var known: List[Float64] = [-2.0, -1.0, 0.0, 1.0, 2.0]
    verify(known)
    var known_result = shared_kernel(known)
    assert_close(known_result.mean, 2.0, "known mapped mean")
    assert_close(known_result.variance, 2.8, "known mapped population variance")
    var rounding_sensitive: List[Float64] = [1.0e8, 1.0, 1.0]
    verify(rounding_sensitive)
    verify_two_pass_numerics()

    # Runtime data prevents the compiler from precomputing the reductions.
    var seed = Int(perf_counter_ns() % 997)
    print("# source=" + Source.describe() + ", seed=" + String(seed))
    print(
        "# checks=known_fixture+independent_centered_reference"
        "+mean_rounding+corrected_two_pass_fixtures+three_way_sinks"
    )
    print("size,sample,order,path,repetitions,total_ns,ns_per_call,ns_per_element,sink")
    run_size(SMALL_SIZE, seed)
    run_size(LARGE_SIZE, seed)
