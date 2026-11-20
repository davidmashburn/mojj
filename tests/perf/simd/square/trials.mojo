"""Matched timings for square map and RMS through the public Expr API."""

from std.benchmark import keep
from std.collections import List
from std.math import sqrt
from std.memory import bitcast
from std.sys import argv
from std.testing import assert_equal, assert_raises, assert_true
from std.time import perf_counter_ns

from mojj.nouns import Noun
from mojj.strings import Expr


comptime Square = Expr["*:"]
comptime Rms = Expr["sqrt of mean of square"]
comptime MAP_LABEL = "square"
comptime RMS_LABEL = "rms"
comptime PUBLIC_WIDTH = 0
comptime PUBLIC_MODE = "public"
comptime SMOKE_MODE = "smoke"


@no_inline
def scalar_square(value: Float64) -> Float64:
    return value * value


def check_bits(actual: Float64, expected: Float64) raises:
    assert_equal(
        bitcast[DType.uint64, 1](actual), bitcast[DType.uint64, 1](expected)
    )


def check_square() raises:
    var patterns: List[UInt64] = [
        0x0000000000000000, 0x8000000000000000,
        0x7FF0000000000000, 0xFFF0000000000000,
        0x7FF8000000000042, 0xFFF8000000000043, 0x7FF0000000000044,
        0x0000000000000001, 0x8000000000000001, 0x000FFFFFFFFFFFFF,
        0x2000000000000000, 0x9FF0000000000000,
        0x7FEFFFFFFFFFFFFF, 0xFFEFFFFFFFFFFFFF,
        0x3FF8000000000000, 0xC004000000000000,
    ]
    # Rotate every value through every lane and every scalar tail position.
    for size in range(2 * len(patterns) + 1):
        for offset in range(len(patterns)):
            var data = List[Float64](capacity=size)
            for index in range(size):
                var pattern = patterns[(index + offset) % len(patterns)]
                data.append(bitcast[DType.float64, 1](pattern))
            var actual = Square.map(data)
            assert_equal(len(actual), size)
            for index in range(size):
                var pattern = patterns[(index + offset) % len(patterns)]
                var value = bitcast[DType.float64, 1](pattern)
                check_bits(actual[index], scalar_square(value))
                assert_equal(bitcast[DType.uint64, 1](data[index]), pattern)

    var atom = Square.monad(Noun(-0.0))
    assert_true(atom.is_float64() and atom.is_scalar())
    check_bits(atom.as_float(), 0.0)
    var singleton = Square.monad(Noun(List[Float64]([-0.0])))
    assert_true(singleton.is_float64() and singleton.is_vector())
    var empty = Square.monad(Noun(List[Float64]()))
    assert_true(empty.is_float64() and empty.is_vector() and empty.length() == 0)
    var matrix_data: List[Float64] = [-1.0, -2.0, -3.0, -4.0, -5.0, -6.0]
    var matrix = Square.monad(Noun(matrix_data).with_shape([2, 3]))
    assert_true(matrix.is_float64())
    assert_equal(matrix.dims(), List[Int]([2, 3]))
    assert_equal(matrix.as_floats(), List[Float64]([1.0, 4.0, 9.0, 16.0, 25.0, 36.0]))
    assert_equal(
        Square.monad(Noun(List[Bool]([True, False]))).as_ints(), List[Int]([1, 0])
    )
    assert_equal(
        Square.monad(Noun(List[Int]([94_906_265]))).as_ints(),
        List[Int]([9_007_199_136_250_225]),
    )
    with assert_raises():
        _ = Square.monad(Noun(List[Int]([Int.MAX])))
    assert_equal(Square.dyad(Noun(1), Noun(1)).as_bool(), False)
    assert_equal(Square.describe(), "*:")
    assert_equal(Rms.describe(), Expr["%: @: (+/ % #) @: *:"].describe())

    var data: List[Float64] = [1.0, -2.0, 3.0, -4.0, 5.0, -6.0, 7.0, -8.0, 9.0]
    var first = Square.map(data)
    var second = Square.map(data)
    first[0] = 100.0
    assert_equal(second[0], 1.0)
    assert_equal(data[0], 1.0)
    data[1] = 200.0
    assert_equal(first[1], 4.0)
    assert_equal(second[1], 4.0)


def check_rms(data: List[Float64]) raises:
    var count = len(data)
    if count == 0:
        check_bits(Rms.reduce(data), 0.0)
        return
    var sum = scalar_square(data[count - 1])
    for index in range(count - 2, -1, -1):
        sum = scalar_square(data[index]) + sum
    check_bits(Rms.reduce(data), sqrt(sum / Float64(count)))


def calls[use_rms: Bool](data: List[Float64], reps: Int) raises -> Float64:
    var sink: Float64 = 0.0
    var last = len(data) - 1
    for _ in range(reps):
        comptime if use_rms:
            sink += Rms.reduce(data)
        else:
            var result = Square.map(data)
            keep(result.unsafe_ptr())
            sink += result[last]
    return sink


def measure[use_rms: Bool](data: List[Float64], reps: Int) raises:
    keep(calls[use_rms](data, max(2, reps // 20)))
    var start = perf_counter_ns()
    var sink = calls[use_rms](data, reps)
    var time_ns = Float64(perf_counter_ns() - start) / Float64(reps)
    var label = String(RMS_LABEL) if use_rms else String(MAP_LABEL)
    print(label, len(data), PUBLIC_WIDTH, time_ns, sink, reps, sep=",")


def main() raises:
    var args = argv()
    if len(args) != 3 or (args[1] != PUBLIC_MODE and args[1] != SMOKE_MODE):
        raise Error("Expected [public|smoke] [block-order-offset]")
    var smoke = args[1] == SMOKE_MODE
    var rms_first = args[2] == "1" or args[2] == "3"
    check_square()
    check_rms(List[Float64]())
    check_rms([134_217_728.0, -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
    print("label,size,width,time_ns,sink,reps")
    var sizes: List[Int] = [1, 3, 4, 5, 6, 7, 16, 1024, 100000, 100003, 1048576]
    for size in sizes:
        var data = List[Float64](length=size, fill=0.0)
        for index in range(size):
            data[index] = Float64(index % 97 - 48) / 16.0
        check_rms(data)
        var reps = max(24, min(250_000, 16_000_000 // size))
        if smoke:
            reps = 2
        if rms_first:
            measure[True](data, reps)
            measure[False](data, reps)
        else:
            measure[False](data, reps)
            measure[True](data, reps)
