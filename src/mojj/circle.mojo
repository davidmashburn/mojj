"""Pi-times and real circular and hyperbolic functions."""

from std.ffi import external_call
from std.math import isnan, sqrt
from std.sys import llvm_intrinsic

from ._atomic import AtomicKernel
from .nouns import Noun, NounDType

comptime PI = 3.14159265358979323846
comptime _TRIG_LIMIT: Float64 = 5.9631365372958016e8
comptime _LARGE_ROOT_ARGUMENT: Float64 = 1.0e8


def _trig(selector: Float64, value: Float64) raises -> Float64:
    if not (abs(value) <= _TRIG_LIMIT):
        raise Error("circle trigonometric argument exceeds the supported magnitude")
    if selector == 1.0:
        return llvm_intrinsic["llvm.sin.f64", Float64](value)
    if selector == 2.0:
        return llvm_intrinsic["llvm.cos.f64", Float64](value)
    return llvm_intrinsic["llvm.tan.f64", Float64](value)


struct Circle(AtomicKernel):
    @staticmethod
    def describe() -> String:
        return "circle"

    @staticmethod
    def monad_dtype(y: NounDType) -> NounDType:
        return NounDType.FLOAT64

    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) -> NounDType:
        return NounDType.FLOAT64

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        return Noun(Float64(PI) * y.as_float())

    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        var k = x.as_float()
        var v = y.as_float()
        if k == 9 or k == -9 or k == -10:
            return Noun(v)
        if k == 10:
            return Noun(-v if v < 0.0 else v)
        if k == 11:
            return Noun(0.0)
        if k == 12:
            return Noun(0.0 if v >= 0.0 else Float64(PI))
        if k == -11 and v == 0:
            return Noun(0.0)
        if k == -12 and v == 0:
            return Noun(1.0)
        if k == 1 or k == 2 or k == 3:
            return Noun(_trig(k, v))
        # Use the platform's scalar libm functions for inverse and hyperbolic
        # cases, including finite sinh/cosh between exp overflow and 710.475….
        if k == 5:
            return Noun(external_call["sinh", Float64](v))
        if k == 6:
            return Noun(external_call["cosh", Float64](v))
        if k == 7:
            return Noun(external_call["tanh", Float64](v))
        if k == -3:
            if isnan(v):
                raise Error("circle arctangent requires a non-NaN argument")
            return Noun(external_call["atan", Float64](v))
        if k == -5:
            return Noun(external_call["asinh", Float64](v))
        if k == -6 and v >= 1:
            return Noun(external_call["acosh", Float64](v))
        if k == -7 and abs(v) <= 1:
            return Noun(external_call["atanh", Float64](v))
        if k == -1 and abs(v) <= 1:
            return Noun(external_call["asin", Float64](v))
        if k == -2 and abs(v) <= 1:
            return Noun(external_call["acos", Float64](v))
        if k == 0 and abs(v) <= 1:
            return Noun(sqrt((1.0 - v) * (1.0 + v)))
        if k == 4:
            if abs(v) > _LARGE_ROOT_ARGUMENT:
                return Noun(abs(v))
            return Noun(sqrt(1.0 + v * v))
        if k == -4 and abs(v) >= 1:
            if abs(v) > _LARGE_ROOT_ARGUMENT:
                return Noun(v)
            if v == -1.0:
                return Noun(0.0)
            var magnitude = sqrt((abs(v) - 1.0) * (abs(v) + 1.0))
            if v < 0.0:
                return Noun(-magnitude)
            return Noun(magnitude)
        raise Error("circle requires a supported selector and real result")
