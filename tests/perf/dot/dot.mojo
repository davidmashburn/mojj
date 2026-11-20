from std.benchmark import keep
from std.collections import List
from std.time import perf_counter_ns
from mojj import Expr, Noun


def measure(size: Int, reps: Int) raises:
    var left = List[Float64](capacity=size)
    var right = List[Float64](capacity=size)
    for i in range(size):
        left.append(Float64(i % 53 - 26) / 16.0)
        right.append(Float64(i % 29 - 14) / 8.0)
    var x = Noun.from_owned_float64(left^)
    var y = Noun.from_owned_float64(right^)
    for i in range(4):
        keep(Expr["+/ . *"].dyad(x, y).as_float())
    var sink = 0.0
    var start = perf_counter_ns()
    for i in range(reps):
        # Change one input and consume every result so calls cannot be hoisted.
        x.float_values[0] = Float64(i % 13)
        sink += Expr["+/ . *"].dyad(x, y).as_float()
    var elapsed = perf_counter_ns() - start
    print(size, reps, elapsed, sink, sep=",")
    keep(sink)


def main() raises:
    measure(1, 10000)
    measure(8, 2500)
    measure(128, 180)
    measure(4096, 8)
    measure(32768, 3)
