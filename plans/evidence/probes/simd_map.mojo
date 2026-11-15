"""Elementwise map: scalar versus 4-wide SIMD, plus a SIMD reduction floor."""
from std.collections import List
from std.time import perf_counter_ns


comptime REPS = 200
comptime W = 4


def make_data(size: Int) raises -> List[Float64]:
    var values = List[Float64]()
    for index in range(size):
        values.append(Float64(index % 97) / 16.0)
    return values^


def double_simd(data: List[Float64]) raises -> Float64:
    var n = len(data)
    var output = List[Float64](length=n, fill=0.0)
    var src = data.unsafe_ptr()
    var dst = output.unsafe_ptr()
    var index = 0
    var stop = n - (n % W)
    while index < stop:
        var cells = src.load[width=W](index)
        dst.store[width=W](index, cells + cells)
        index += W
    while index < n:
        var value = src[index]
        dst[index] = value + value
        index += 1
    return dst[0] + Float64(len(output))


def double_scalar(data: List[Float64]) raises -> Float64:
    var n = len(data)
    var output = List[Float64](length=n, fill=0.0)
    var src = data.unsafe_ptr()
    var dst = output.unsafe_ptr()
    for index in range(n):
        var value = src[index]
        dst[index] = value + value
    return dst[0] + Float64(len(output))


def sum_simd(data: List[Float64]) raises -> Float64:
    var n = len(data)
    var src = data.unsafe_ptr()
    var acc = SIMD[DType.float64, W](0.0)
    var index = 0
    var stop = n - (n % W)
    while index < stop:
        acc += src.load[width=W](index)
        index += W
    var total = acc.reduce_add()
    while index < n:
        total += src[index]
        index += 1
    return total


def main() raises:
    var sizes = List[Int]()
    sizes.append(1000)
    sizes.append(10000)
    sizes.append(100000)
    for size in sizes:
        var data = make_data(size)
        var d0 = double_scalar(data)
        var d1 = double_simd(data)
        var s1 = sum_simd(data)

        var start = perf_counter_ns()
        for _ in range(REPS):
            d0 += double_scalar(data)
        var t_d0 = Float64(perf_counter_ns() - start) / Float64(REPS)

        start = perf_counter_ns()
        for _ in range(REPS):
            d1 += double_simd(data)
        var t_d1 = Float64(perf_counter_ns() - start) / Float64(REPS)

        start = perf_counter_ns()
        for _ in range(REPS):
            s1 += sum_simd(data)
        var t_s1 = Float64(perf_counter_ns() - start) / Float64(REPS)

        print("size=" + String(size))
        print("  double_scalar ns=" + String(t_d0) + " ns/elem=" + String(t_d0 / Float64(size)) + " sink=" + String(d0))
        print("  double_simd   ns=" + String(t_d1) + " ns/elem=" + String(t_d1 / Float64(size)) + " sink=" + String(d1))
        print("  sum_simd      ns=" + String(t_s1) + " ns/elem=" + String(t_s1 / Float64(size)) + " sink=" + String(s1))
        print("")
