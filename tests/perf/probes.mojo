"""Matched-control performance probes for the compiled Expr API.

Run with `pixi run perf-probes`.  The task builds this program, prints the host
and revision header, then runs it.  Measurements are back-to-back in one
process, so the *ratios* are meaningful while absolute values stay
load-dependent.  Fixed-cost rows report ns/call; the 100,000-element rows report
ns/element.

The controls are deliberately redundant: they bound the same work below the
library so a change in the library can be attributed instead of guessing.
"""
from std.collections import List
from std.time import perf_counter_ns

from mojj.nouns import Noun, NounDType
from mojj.strings import Expr
from mojj.verbs import Verb, Plus, Insert, ATOM_RANK


comptime ELEMENTS = 100_000
comptime BULK_REPS = 100
comptime CALL_REPS = 20_000
comptime WIDTH = 4


struct PlainPlus(Verb):
    """Control verb with no Float64 kernels: forces the generic Noun path."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Plus.monad(y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Plus.dyad(x, y)

    @staticmethod
    def describe() -> String:
        return "plain+"

    @staticmethod
    def monad_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def left_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def right_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        return Plus.insert_identity(dtype)


def make_data(size: Int) raises -> List[Float64]:
    var values = List[Float64](length=size, fill=0.0)
    for index in range(size):
        values[index] = Float64(index % 97) / 16.0
    return values^


def raw_index_loop(data: List[Float64]) raises -> Float64:
    var total = 0.0
    for index in range(len(data)):
        total += data[index] * 2.0
    return total


def raw_ptr_loop(data: List[Float64]) raises -> Float64:
    var total = 0.0
    var values = data.unsafe_ptr()
    for index in range(len(data)):
        total += values[unsafe_offset=index] * 2.0
    return total


def raw_simd_loop(data: List[Float64]) raises -> Float64:
    var size = len(data)
    var output = List[Float64](length=size, fill=0.0)
    var source = data.unsafe_ptr()
    var target = output.unsafe_ptr()
    var index = 0
    var stop = size - (size % WIDTH)
    while index < stop:
        var cells = source.unsafe_load[width=WIDTH](index)
        target.unsafe_store[width=WIDTH](index, cells + cells)
        index += WIDTH
    while index < size:
        var value = source[unsafe_offset=index]
        target[unsafe_offset=index] = value + value
        index += 1
    return target[unsafe_offset=0] + Float64(size)


def serial_fold(data: List[Float64]) raises -> Float64:
    var total = 0.0
    var values = data.unsafe_ptr()
    for index in range(len(data)):
        total += values[unsafe_offset=index]
    return total


def blocked_fold8(data: List[Float64]) raises -> Float64:
    var size = len(data)
    var values = data.unsafe_ptr()
    var accumulators = SIMD[DType.float64, 8](0.0)
    var index = 0
    var stop = size - (size % 8)
    while index < stop:
        accumulators += values.unsafe_load[width=8](index)
        index += 8
    var total = accumulators.reduce_add()
    while index < size:
        total += values[unsafe_offset=index]
        index += 1
    return total


def noun_at_loop(data: List[Float64]) raises -> Float64:
    var noun = Noun(data)
    var total = 0.0
    for index in range(noun.length()):
        total += noun.at(index).as_float()
    return total


def boxed_dyad_fold(data: List[Float64]) raises -> Float64:
    var accumulator = Noun(0.0)
    for index in range(len(data)):
        accumulator = Plus.dyad(Noun(data[index]), accumulator)
    return accumulator.as_float()


def noun_copy(data: List[Float64]) raises -> Float64:
    var noun = Noun(data)
    return noun.float_values[0]


def expr_double(data: List[Float64]) raises -> Float64:
    return Expr["+:"].monad(Noun(data)).at(0).as_float()


def expr_sum(data: List[Float64]) raises -> Float64:
    return Expr["+/"].monad(Noun(data)).as_float()


def expr_rms(data: List[Float64]) raises -> Float64:
    return Expr["%: @: (+/ % #) @: *:"].monad(Noun(data)).as_float()


def insert_plus(data: List[Float64]) raises -> Float64:
    return Insert[Plus].monad(Noun(data)).as_float()


def generic_insert(data: List[Float64]) raises -> Float64:
    return Insert[PlainPlus].monad(Noun(data)).as_float()


def bench_bulk(label: String, value: Float64, start: Int) raises:
    var elapsed = Float64(perf_counter_ns() - start) / Float64(BULK_REPS)
    print(
        "  " + label + " ns/element="
        + String(elapsed / Float64(ELEMENTS))
    )


def bulk_section(data: List[Float64]) raises:
    print("bulk controls and API paths, elements=" + String(len(data)))
    var sink = 0.0

    var start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += raw_index_loop(data)
    bench_bulk("control raw_index_loop", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += raw_ptr_loop(data)
    bench_bulk("control raw_ptr_loop", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += raw_simd_loop(data)
    bench_bulk("control raw_simd_loop", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += serial_fold(data)
    bench_bulk("control serial_fold", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += blocked_fold8(data)
    bench_bulk("control blocked_fold8", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += noun_at_loop(data)
    bench_bulk("control noun_at_loop", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS // 10):
        sink += boxed_dyad_fold(data)
    var boxed_ns = Float64(perf_counter_ns() - start) / Float64(BULK_REPS // 10)
    print("  control boxed_dyad_fold ns/element=" + String(boxed_ns / Float64(ELEMENTS)))

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += noun_copy(data)
    bench_bulk("control noun_copy", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += expr_double(data)
    bench_bulk("Expr[\"+:\"]", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += expr_sum(data)
    bench_bulk("Expr[\"+/\"], kernel fold", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS // 10):
        sink += generic_insert(data)
    var generic_ns = Float64(perf_counter_ns() - start) / Float64(BULK_REPS // 10)
    print(
        "  Insert[PlainPlus], generic fold ns/element="
        + String(generic_ns / Float64(ELEMENTS))
    )

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += insert_plus(data)
    bench_bulk("Insert[Plus]", sink, start)

    start = perf_counter_ns()
    for _ in range(BULK_REPS):
        sink += expr_rms(data)
    bench_bulk("Expr RMS", sink, start)

    print("  sink=" + String(sink))


def fixed_section() raises:
    print("fixed-cost cases, ns/call")
    var sizes: List[Int] = [0, 1, 4, 16]
    for size in sizes:
        var values = List[Float64](length=size, fill=2.0)
        var noun = Noun(values)
        var sink = 0.0
        var start = perf_counter_ns()
        for _ in range(CALL_REPS):
            sink += Expr["+/"].monad(noun).as_float()
        var sum_ns = Float64(perf_counter_ns() - start) / Float64(CALL_REPS)

        start = perf_counter_ns()
        for _ in range(CALL_REPS):
            var mapped = Expr["+:"].monad(noun)
            if size > 0:
                sink += mapped.at(0).as_float()
            else:
                sink += Float64(mapped.length())
        var double_ns = Float64(perf_counter_ns() - start) / Float64(CALL_REPS)

        start = perf_counter_ns()
        for _ in range(CALL_REPS):
            sink += Expr["%: @: (+/ % #) @: *:"].monad(noun).as_float()
        var rms_ns = Float64(perf_counter_ns() - start) / Float64(CALL_REPS)

        print(
            "  n=" + String(size) + " sum=" + String(sum_ns)
            + " double=" + String(double_ns) + " rms=" + String(rms_ns)
            + " sink=" + String(sink)
        )


def main() raises:
    bulk_section(make_data(ELEMENTS))
    fixed_section()
