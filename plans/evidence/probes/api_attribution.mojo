"""Throwaway microbenchmarks isolating Mojj's per-call cost centers."""
from std.collections import List
from std.time import perf_counter_ns

from mojj.nouns import Noun
from mojj.strings import Expr
from mojj.verbs import Insert, Plus


comptime REPS = 200
comptime SCALAR_REPS = 20000


def make_data(size: Int) raises -> List[Float64]:
    var values = List[Float64]()
    for index in range(size):
        values.append(Float64(index % 97) / 16.0)
    return values^


def raw_sum(data: List[Float64]) raises -> Float64:
    var total = 0.0
    for index in range(len(data)):
        total += data[index]
    return total


def raw_sum_plus_copy(data: List[Float64]) raises -> Float64:
    var other = data.copy()
    var total = 0.0
    for index in range(len(other)):
        total += other[index]
    return total


def noun_construct(data: List[Float64]) raises -> Float64:
    var noun = Noun(data)
    return noun.float_values[0]


def noun_at_loop(data: List[Float64]) raises -> Float64:
    var noun = Noun(data)
    var total = 0.0
    for index in range(noun.length()):
        total += noun.at(index).as_float()
    return total


def insert_plus_direct(data: List[Float64]) raises -> Float64:
    return Insert[Plus].monad(Noun(data)).as_float()


def expr_sum(data: List[Float64]) raises -> Float64:
    return Expr["+/"].monad(Noun(data)).as_float()


def expr_double(data: List[Float64]) raises -> Float64:
    return Expr["+:"].monad(Noun(data)).at(0).as_float()


def scalar_noun_ctor_loop(size: Int) raises -> Float64:
    var total = 0.0
    for index in range(size):
        var noun = Noun(Float64(index))
        total += noun.as_float()
    return total

def bench_raw_sum(data: List[Float64]) raises:
    var sink = raw_sum(data)
    var start = perf_counter_ns()
    for _ in range(REPS):
        sink += raw_sum(data)
    var elapsed = perf_counter_ns() - start
    print("raw_sum size=" + String(len(data)) + " ns/call=" + String(Float64(elapsed) / Float64(REPS)) + " sink=" + String(sink))

def bench_raw_sum_plus_copy(data: List[Float64]) raises:
    var sink = raw_sum_plus_copy(data)
    var start = perf_counter_ns()
    for _ in range(REPS):
        sink += raw_sum_plus_copy(data)
    var elapsed = perf_counter_ns() - start
    print("raw_sum_plus_copy size=" + String(len(data)) + " ns/call=" + String(Float64(elapsed) / Float64(REPS)) + " sink=" + String(sink))

def bench_noun_construct(data: List[Float64]) raises:
    var sink = noun_construct(data)
    var start = perf_counter_ns()
    for _ in range(REPS):
        sink += noun_construct(data)
    var elapsed = perf_counter_ns() - start
    print("noun_construct size=" + String(len(data)) + " ns/call=" + String(Float64(elapsed) / Float64(REPS)) + " sink=" + String(sink))

def bench_noun_at_loop(data: List[Float64]) raises:
    var sink = noun_at_loop(data)
    var start = perf_counter_ns()
    for _ in range(REPS):
        sink += noun_at_loop(data)
    var elapsed = perf_counter_ns() - start
    print("noun_at_loop size=" + String(len(data)) + " ns/call=" + String(Float64(elapsed) / Float64(REPS)) + " sink=" + String(sink))

def bench_insert_plus_direct(data: List[Float64]) raises:
    var sink = insert_plus_direct(data)
    var start = perf_counter_ns()
    for _ in range(REPS):
        sink += insert_plus_direct(data)
    var elapsed = perf_counter_ns() - start
    print("insert_plus_direct size=" + String(len(data)) + " ns/call=" + String(Float64(elapsed) / Float64(REPS)) + " sink=" + String(sink))

def bench_expr_sum(data: List[Float64]) raises:
    var sink = expr_sum(data)
    var start = perf_counter_ns()
    for _ in range(REPS):
        sink += expr_sum(data)
    var elapsed = perf_counter_ns() - start
    print("expr_sum size=" + String(len(data)) + " ns/call=" + String(Float64(elapsed) / Float64(REPS)) + " sink=" + String(sink))

def bench_expr_double(data: List[Float64]) raises:
    var sink = expr_double(data)
    var start = perf_counter_ns()
    for _ in range(REPS):
        sink += expr_double(data)
    var elapsed = perf_counter_ns() - start
    print("expr_double size=" + String(len(data)) + " ns/call=" + String(Float64(elapsed) / Float64(REPS)) + " sink=" + String(sink))

def bench_scalar(size: Int) raises:
    var sink = scalar_noun_ctor_loop(size)
    var start = perf_counter_ns()
    for _ in range(SCALAR_REPS):
        sink += scalar_noun_ctor_loop(size)
    var elapsed = perf_counter_ns() - start
    print("scalar_noun_ctor_loop size=" + String(size) + " ns/call=" + String(Float64(elapsed) / Float64(SCALAR_REPS)) + " sink=" + String(sink))


def main() raises:
    var sizes = List[Int]()
    sizes.append(1000)
    sizes.append(10000)
    sizes.append(100000)
    for size in sizes:
        var data = make_data(size)
        bench_raw_sum(data)
        bench_raw_sum_plus_copy(data)
        bench_noun_construct(data)
        bench_noun_at_loop(data)
        bench_insert_plus_direct(data)
        bench_expr_sum(data)
        bench_expr_double(data)
        bench_scalar(size)
        print("")
