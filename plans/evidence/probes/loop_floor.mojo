"""Third probe: calibrate loop cost on this host and test List access paths."""
from std.collections import List
from std.time import perf_counter_ns


comptime REPS = 200


def make_data(size: Int) raises -> List[Float64]:
    var values = List[Float64]()
    for index in range(size):
        values.append(Float64(index % 97) / 16.0)
    return values^


def counter_1(n: Int) raises -> Float64:
    var total = 0.0
    for _ in range(n):
        total += 1.0
    return total


def counter_4(n: Int) raises -> Float64:
    var a0 = 0.0
    var a1 = 0.0
    var a2 = 0.0
    var a3 = 0.0
    var index = 0
    while index + 4 <= n:
        a0 += 1.0
        a1 += 1.0
        a2 += 1.0
        a3 += 1.0
        index += 4
    return (a0 + a1) + (a2 + a3)


def sum_indexed(data: List[Float64]) raises -> Float64:
    var total = 0.0
    for index in range(len(data)):
        total += data[index]
    return total


def sum_ptr(data: List[Float64]) raises -> Float64:
    var ptr = data.unsafe_ptr()
    var total = 0.0
    for index in range(len(data)):
        total += ptr[index]
    return total


def sum_ptr_8(data: List[Float64]) raises -> Float64:
    var ptr = data.unsafe_ptr()
    var a0 = 0.0
    var a1 = 0.0
    var a2 = 0.0
    var a3 = 0.0
    var a4 = 0.0
    var a5 = 0.0
    var a6 = 0.0
    var a7 = 0.0
    var index = 0
    var n = len(data)
    var stop = n - (n % 8)
    while index < stop:
        a0 += ptr[index]
        a1 += ptr[index + 1]
        a2 += ptr[index + 2]
        a3 += ptr[index + 3]
        a4 += ptr[index + 4]
        a5 += ptr[index + 5]
        a6 += ptr[index + 6]
        a7 += ptr[index + 7]
        index += 8
    while index < n:
        a0 += ptr[index]
        index += 1
    return ((a0 + a1) + (a2 + a3)) + ((a4 + a5) + (a6 + a7))


def report(name: String, ns: Float64, n: Int, sink: Float64) raises:
    print("  " + name + " ns=" + String(ns) + " ns/elem=" + String(ns / Float64(n)) + " sink=" + String(sink))


def main() raises:
    var sizes = List[Int]()
    sizes.append(1000)
    sizes.append(10000)
    sizes.append(100000)
    for size in sizes:
        var data = make_data(size)
        var c1 = counter_1(size)
        var c4 = counter_4(size)
        var s0 = sum_indexed(data)
        var s1 = sum_ptr(data)
        var s2 = sum_ptr_8(data)

        var start = perf_counter_ns()
        for _ in range(REPS):
            c1 += counter_1(size)
        var t_c1 = Float64(perf_counter_ns() - start) / Float64(REPS)

        start = perf_counter_ns()
        for _ in range(REPS):
            c4 += counter_4(size)
        var t_c4 = Float64(perf_counter_ns() - start) / Float64(REPS)

        start = perf_counter_ns()
        for _ in range(REPS):
            s0 += sum_indexed(data)
        var t_s0 = Float64(perf_counter_ns() - start) / Float64(REPS)

        start = perf_counter_ns()
        for _ in range(REPS):
            s1 += sum_ptr(data)
        var t_s1 = Float64(perf_counter_ns() - start) / Float64(REPS)

        start = perf_counter_ns()
        for _ in range(REPS):
            s2 += sum_ptr_8(data)
        var t_s2 = Float64(perf_counter_ns() - start) / Float64(REPS)

        print("size=" + String(size))
        report("counter_1", t_c1, size, c1)
        report("counter_4", t_c4, size, c4)
        report("sum_indexed", t_s0, size, s0)
        report("sum_ptr", t_s1, size, s1)
        report("sum_ptr_8", t_s2, size, s2)
        print("")
