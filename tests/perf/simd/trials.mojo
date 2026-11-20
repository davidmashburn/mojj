"""Matched Float64 double trials. Output is CSV with times in ns per call.

Build with `mojo build --fp-mode contract=off -I src tests/perf/simd/trials.mojo`.
Run as `simd_trials [all|raw|public|smoke] [raw-order-offset]`. Use the same
harness source and compiler flags with each checkout's `src` for public trials.
"""

from std.benchmark import keep
from std.collections import List
from std.memory import Pointer, bitcast
from std.sys import argv
from std.time import perf_counter_ns

from mojj.strings import Expr


comptime SCALAR_WIDTH = 1
comptime PUBLIC_WIDTH = 0
comptime GUARD_BITS = UInt64(0x7FF8000000000001)


struct Mode(Equatable, ImplicitlyCopyable):
    var code: Int

    def __init__(out self, code: Int):
        self.code = code

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    comptime ALL = Self(0)
    comptime RAW = Self(1)
    comptime PUBLIC = Self(2)
    comptime SMOKE = Self(3)

    comptime ALL_NAME = "all"
    comptime RAW_NAME = "raw"
    comptime PUBLIC_NAME = "public"
    comptime SMOKE_NAME = "smoke"


@no_inline
def double_scalar[
    origin: Origin[mut=True]
](source: Pointer[Float64, _], target: Pointer[Float64, origin], size: Int):
    for index in range(size):
        var value = source[unsafe_offset=index]
        target[unsafe_offset=index] = value + value


@no_inline
def double_simd[
    width: Int, *, origin: Origin[mut=True]
](source: Pointer[Float64, _], target: Pointer[Float64, origin], size: Int):
    var index = 0
    var stop = size - size % width
    while index < stop:
        var values = source.unsafe_load[width=width](index)
        target.unsafe_store[width=width](index, values + values)
        index += width
    while index < size:
        var value = source[unsafe_offset=index]
        target[unsafe_offset=index] = value + value
        index += 1


def verify_bits(
    expected: List[Float64], actual: List[Float64], size: Int
) raises:
    for index in range(size):
        if bitcast[DType.uint64, 1](actual[index]) != bitcast[DType.uint64, 1](
            expected[index]
        ):
            raise Error(
                "Float64 double mismatch at index "
                + String(index)
                + " for size "
                + String(size)
            )


def verify_raw[
    width: Int
](data: List[Float64], expected: List[Float64], size: Int) raises:
    # Guard both ends. Passing an offset also checks unaligned SIMD accesses.
    var guard = bitcast[DType.float64, 1](GUARD_BITS)
    var actual = List[Float64](length=size + 2, fill=guard)
    double_simd[width](
        data.unsafe_ptr(), actual.unsafe_ptr().unsafe_offset(1), size
    )
    for index in range(size):
        if bitcast[DType.uint64, 1](actual[index + 1]) != bitcast[
            DType.uint64, 1
        ](expected[index]):
            raise Error(
                "Raw double mismatch for width "
                + String(width)
                + " at index "
                + String(index)
                + " for size "
                + String(size)
            )
    if (
        bitcast[DType.uint64, 1](actual[0]) != GUARD_BITS
        or bitcast[DType.uint64, 1](actual[size + 1]) != GUARD_BITS
    ):
        raise Error(
            "Raw double overwrote a guard for width "
            + String(width)
            + " at size "
            + String(size)
        )


def verify_kernels(mode: Mode) raises:
    # +0/-0, signed infinities, quiet/signaling NaN payloads, subnormals,
    # finite overflow, and ordinary values of both signs.
    var patterns: List[UInt64] = [
        0x0000000000000000,
        0x8000000000000000,
        0x7FF0000000000000,
        0xFFF0000000000000,
        0x7FF8000000000042,
        0xFFF8000000000043,
        0x7FF0000000000044,
        0x0000000000000001,
        0x8000000000000001,
        0x000FFFFFFFFFFFFF,
        0x7FEFFFFFFFFFFFFF,
        0xFFEFFFFFFFFFFFFF,
        0x3FF8000000000000,
        0xC004000000000000,
    ]
    for size in range(4 * len(patterns) + 1):
        var data = List[Float64](length=size, fill=0.0)
        for index in range(size):
            data[index] = bitcast[DType.float64, 1](
                patterns[index % len(patterns)]
            )
        var expected = List[Float64](length=size, fill=0.0)
        double_scalar(data.unsafe_ptr(), expected.unsafe_ptr(), size)
        if mode != Mode.PUBLIC:
            verify_raw[2](data, expected, size)
            verify_raw[4](data, expected, size)
            verify_raw[8](data, expected, size)
        if mode != Mode.RAW:
            var actual = Expr["+:"].map(data)
            if len(actual) != size:
                raise Error(
                    "Public double returned the wrong length for size "
                    + String(size)
                )
            verify_bits(expected, actual, size)


def raw_calls[
    width: Int
](data: List[Float64], mut output: List[Float64], reps: Int) -> Float64:
    var source = data.unsafe_ptr()
    var target = output.unsafe_ptr()
    var size = len(data)
    var sink: Float64 = 0.0
    for _ in range(reps):
        comptime if width == SCALAR_WIDTH:
            double_scalar(source, target, size)
        else:
            double_simd[width](source, target, size)
        sink += target[unsafe_offset=size - 1]
    return sink


def public_calls(data: List[Float64], reps: Int) raises -> Float64:
    var sink: Float64 = 0.0
    var last = len(data) - 1
    for _ in range(reps):
        var result = Expr["+:"].map(data)
        # Make the buffer observable before normal destruction.
        keep(result.unsafe_ptr())
        sink += result[last]
    return sink


def report(
    mode: Mode, size: Int, width: Int, elapsed_ns: Int, sink: Float64, reps: Int
) raises:
    if elapsed_ns <= 0:
        raise Error("Measurement must have positive elapsed time")
    var label = String(Mode.RAW_NAME) if mode == Mode.RAW else String(
        Mode.PUBLIC_NAME
    )
    print(
        label,
        size,
        width,
        Float64(elapsed_ns) / Float64(reps),
        sink,
        reps,
        sep=",",
    )


def time_raw[
    width: Int
](data: List[Float64], mut output: List[Float64], reps: Int) raises:
    keep(raw_calls[width](data, output, max(2, reps // 20)))
    var start = perf_counter_ns()
    var sink = raw_calls[width](data, output, reps)
    var elapsed = Int(perf_counter_ns() - start)
    report(Mode.RAW, len(data), width, elapsed, sink, reps)


def time_public(data: List[Float64], reps: Int) raises:
    keep(public_calls(data, max(2, reps // 20)))
    var start = perf_counter_ns()
    var sink = public_calls(data, reps)
    var elapsed = Int(perf_counter_ns() - start)
    report(Mode.PUBLIC, len(data), PUBLIC_WIDTH, elapsed, sink, reps)


def main() raises:
    var args = argv()
    if len(args) > 3:
        raise Error("Expected [all|raw|public|smoke] [raw-order-offset]")
    var mode = Mode.ALL
    if len(args) > 1:
        if args[1] == Mode.RAW_NAME:
            mode = Mode.RAW
        elif args[1] == Mode.PUBLIC_NAME:
            mode = Mode.PUBLIC
        elif args[1] == Mode.SMOKE_NAME:
            mode = Mode.SMOKE
        elif args[1] != Mode.ALL_NAME:
            raise Error("Expected mode all, raw, public, or smoke")
    var order = 0
    if len(args) == 3:
        var offset = args[2]
        if offset.byte_length() != 1 or offset < "0" or offset > "3":
            raise Error("Expected raw order offset 0 through 3")
        order = ord(offset) - ord("0")

    verify_kernels(mode)
    print("label,size,width,time_ns,sink,reps")
    var sizes: List[Int] = [1, 3, 4, 5, 6, 7, 16, 1024, 100000, 100003, 1048576]
    for size in sizes:
        var data = List[Float64](length=size, fill=0.0)
        for index in range(size):
            data[index] = Float64(index % 97 + 1) / 16.0
        var reps = max(24, min(250_000, 16_000_000 // size))
        if mode == Mode.SMOKE:
            reps = 4096 if size < 1024 else (32 if size == 1024 else 2)
        if mode != Mode.PUBLIC:
            var output = List[Float64](length=size, fill=0.0)
            for variant in range(4):
                var width = 1 << ((variant + order) % 4)
                if width == SCALAR_WIDTH:
                    time_raw[SCALAR_WIDTH](data, output, reps)
                elif width == 2:
                    time_raw[2](data, output, reps)
                elif width == 4:
                    time_raw[4](data, output, reps)
                else:
                    time_raw[8](data, output, reps)
        if mode != Mode.RAW:
            time_public(data, reps)
