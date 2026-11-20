from std.benchmark import keep
from std.collections import List
from std.testing import assert_equal, assert_true
from std.time import perf_counter_ns
from mojj import Expr, Noun


def project[matrix_left: Bool](matrix: Noun, vector: Noun) raises -> Noun:
    comptime if matrix_left:
        return Expr["+/ . *"].dyad(matrix, vector)
    else:
        return Expr["+/ . *"].dyad(vector, matrix)


def measure[matrix_left: Bool](label: String, rows: Int, cols: Int, reps: Int) raises:
    var cells = List[Float64](capacity=rows * cols)
    for i in range(rows * cols):
        cells.append(Float64(i % 53 - 26) / 16.0)
    var matrix = Noun.from_owned_float64(cells^)
    matrix.set_shape([rows, cols])
    var inner = cols if matrix_left else rows
    var outputs = rows if matrix_left else cols
    var weights = List[Float64](capacity=inner)
    for i in range(inner):
        weights.append(Float64(i % 29 - 14) / 8.0)
    var vector = Noun.from_owned_float64(weights^)

    # Check each distinct timed input and every output outside the timed loop.
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

    var sink = 0.0
    var start = perf_counter_ns()
    for i in range(reps):
        vector.float_values[0] = Float64(i % 13)
        var result = project[matrix_left](matrix, vector)
        for value in result.float_values:
            sink += value
    var elapsed = perf_counter_ns() - start
    print(label, reps, elapsed, sink, sep=",")
    keep(sink)


def main() raises:
    measure[True]("mv-128x32", 128, 32, 26)
    measure[True]("mv-32x128", 32, 128, 26)
    measure[False]("vm-128x32", 128, 32, 26)
    measure[False]("vm-32x128", 32, 128, 26)
