from std.benchmark import keep
from std.collections import List
from std.testing import assert_equal, assert_true
from std.time import perf_counter_ns
from mojj import Noun
from rectangular import project


def weights(length: Int) raises -> Noun:
    var cells = List[Float64](capacity=length)
    for i in range(length):
        cells.append(Float64(i % 29 - 14) / 8.0)
    return Noun.from_owned_float64(cells^)


def check[matrix_left: Bool](matrix: Noun, mut vector: Noun, rows: Int, cols: Int) raises:
    var inner = cols if matrix_left else rows
    var outputs = rows if matrix_left else cols
    for variant in range(13):
        vector.float_values[0] = Float64(variant)
        var result = project[matrix_left](matrix, vector)
        assert_true(result.is_float64())
        assert_equal(result.dims(), List[Int]([outputs]))
        for out_idx in range(outputs):
            var expected = 0.0
            for k in reversed(range(inner)):
                var idx = out_idx * cols + k if matrix_left else k * cols + out_idx
                expected = matrix.float_values[idx] * vector.float_values[k] + expected
            assert_equal(result.float_values[out_idx], expected)


def measure(label: String, rows: Int, cols: Int, percent: Int) raises:
    var cells = List[Float64](capacity=rows * cols)
    for i in range(rows * cols):
        cells.append(Float64(i % 53 - 26) / 16.0)
    var matrix = Noun.from_owned_float64(cells^)
    matrix.set_shape([rows, cols])
    var right = weights(cols)
    var left = weights(rows)
    check[True](matrix, right, rows, cols)
    check[False](matrix, left, rows, cols)

    var sink = 0.0
    var start = perf_counter_ns()
    for i in range(100):
        # Cross a multiple of 100 exactly percent times, evenly spaced.
        var result: Noun
        if (i * percent) % 100 + percent >= 100:
            right.float_values[0] = Float64(i % 13)
            result = project[True](matrix, right)
        else:
            left.float_values[0] = Float64(i % 13)
            result = project[False](matrix, left)
        for value in result.float_values:
            sink += value
    var elapsed = perf_counter_ns() - start
    print(label + "-" + String(percent), 100, elapsed, sink, sep=",")
    keep(sink)


def main() raises:
    for percent in List[Int]([0, 5, 10, 50]):
        measure("tall", 128, 32, percent)
    for percent in List[Int]([0, 5, 10, 50]):
        measure("wide", 32, 128, percent)
