"""Real math verbs with exact integer kernels where the result permits."""

from std.math import ceil, floor, inf, isfinite, isinf, isnan, sqrt, trunc
from std.sys import llvm_intrinsic

from ._atomic import AtomicKernel
from ._verb_base import _float_divide, _numeric_int
from .nouns import Noun, NounDType
from .predicates import tolerant_equal


comptime _POSITIVE_INFINITY = inf[DType.float64]()


def _common_numeric_dtype(x: NounDType, y: NounDType) -> NounDType:
    if x == NounDType.FLOAT64 or y == NounDType.FLOAT64:
        return NounDType.FLOAT64
    if x == NounDType.INT or y == NounDType.INT:
        return NounDType.INT
    return NounDType.BOOL


def _tolerant_round(value: Float64, upward: Bool) -> Float64:
    var lower = floor(value)
    var upper = ceil(value)
    if upward:
        return lower if tolerant_equal(value, lower) else upper
    return upper if tolerant_equal(value, upper) else lower


def _rounded_noun(y: Noun, upward: Bool) raises -> Noun:
    if y.dtype != NounDType.FLOAT64:
        return y.copy()
    var rounded = _tolerant_round(y.as_float(), upward)
    # Float64(Int.MAX) rounds up to 2^63, which cannot convert back to Int.
    if Float64(Int.MIN) <= rounded < Float64(Int.MAX):
        return Noun(Int(rounded))
    return Noun(rounded)


def _extremum(x: Noun, y: Noun, choose_min: Bool) raises -> Noun:
    var dtype = _common_numeric_dtype(x.dtype, y.dtype)
    if dtype == NounDType.BOOL:
        var left = x.as_bool()
        var right = y.as_bool()
        return Noun(left and right if choose_min else left or right)
    if dtype == NounDType.INT:
        var left = _numeric_int(x)
        var right = _numeric_int(y)
        return Noun(min(left, right) if choose_min else max(left, right))
    var left = x.as_float()
    var right = y.as_float()
    var take_left = left < right if choose_min else left > right
    return Noun(left if take_left else right)


struct FloorMin(AtomicKernel):
    """Tolerant floor and strict dyadic minimum."""

    @staticmethod
    def describe() -> String:
        return "<."

    @staticmethod
    def monad_dtype(y: NounDType) -> NounDType:
        return NounDType.INT if y == NounDType.FLOAT64 else y

    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) -> NounDType:
        return _common_numeric_dtype(x, y)

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        return _rounded_noun(y, False)

    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        return _extremum(x, y, True)

    @staticmethod
    def insert_identity(dtype: NounDType) -> Noun:
        return Noun(_POSITIVE_INFINITY)


struct CeilingMax(AtomicKernel):
    """Tolerant ceiling and strict dyadic maximum."""

    @staticmethod
    def describe() -> String:
        return ">."

    @staticmethod
    def monad_dtype(y: NounDType) -> NounDType:
        return NounDType.INT if y == NounDType.FLOAT64 else y

    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) -> NounDType:
        return _common_numeric_dtype(x, y)

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        return _rounded_noun(y, True)

    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        return _extremum(x, y, False)

    @staticmethod
    def insert_identity(dtype: NounDType) -> Noun:
        return Noun(-_POSITIVE_INFINITY)


def _float_residue(divisor: Float64, dividend: Float64) raises -> Float64:
    if divisor == 0.0:
        return dividend
    if isnan(divisor) or isnan(dividend):
        return divisor + dividend
    if isinf(dividend):
        raise Error("Residue is undefined for an infinite dividend and nonzero divisor")
    if isinf(divisor):
        if dividend == 0.0 or (divisor > 0.0) == (dividend > 0.0):
            return dividend
        return divisor

    var quotient = dividend / divisor
    if not isfinite(quotient) or (
        _tolerant_round(quotient, False) == _tolerant_round(quotient, True)
    ):
        return 0.0
    return dividend % divisor


struct MagnitudeResidue(AtomicKernel):
    """Absolute value and residue with the sign of the divisor."""

    @staticmethod
    def describe() -> String:
        return "|"

    @staticmethod
    def monad_dtype(y: NounDType) -> NounDType:
        return y

    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) -> NounDType:
        return _common_numeric_dtype(x, y)

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        if y.dtype == NounDType.BOOL:
            return y.copy()
        if y.dtype == NounDType.FLOAT64:
            var value = y.as_float()
            return Noun(-value if value < 0.0 else value)
        var value = y.as_int()
        if value == Int.MIN:
            return Noun(-Float64(value))
        return Noun(abs(value))

    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        var dtype = Self.dyad_dtype(x.dtype, y.dtype)
        if dtype == NounDType.BOOL:
            return Noun(not x.as_bool() and y.as_bool())
        if dtype == NounDType.FLOAT64:
            return Noun(_float_residue(x.as_float(), y.as_float()))
        var divisor = _numeric_int(x)
        var dividend = _numeric_int(y)
        if divisor == 0:
            return Noun(dividend)
        # Widen to handle Int.MIN divided by -1.
        return Noun(Int(Int128(dividend) % Int128(divisor)))

    @staticmethod
    def insert_identity(dtype: NounDType) -> Noun:
        if dtype == NounDType.FLOAT64:
            return Noun(0.0)
        if dtype == NounDType.BOOL:
            return Noun(False)
        return Noun(0)


def _real_power(base: Float64, exponent: Float64, odd: Bool) raises -> Float64:
    if base < 0.0 and not isnan(exponent):
        if not isfinite(exponent) or exponent != trunc(exponent):
            raise Error("Power requires Complex for a negative base and this exponent")
        var magnitude = llvm_intrinsic["llvm.pow.f64", Float64](-base, exponent)
        return -magnitude if odd else magnitude
    return llvm_intrinsic["llvm.pow.f64", Float64](base, exponent)


def _float_odd(value: Float64) -> Bool:
    return isfinite(value) and abs(value % 2.0) == 1.0


def _one(dtype: NounDType) -> Noun:
    if dtype == NounDType.FLOAT64:
        return Noun(1.0)
    if dtype == NounDType.BOOL:
        return Noun(True)
    return Noun(1)


struct Power(AtomicKernel):
    """Exponential and real power."""

    @staticmethod
    def describe() -> String:
        return "^"

    @staticmethod
    def monad_dtype(y: NounDType) -> NounDType:
        return NounDType.FLOAT64

    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) -> NounDType:
        return x if y == NounDType.BOOL else NounDType.FLOAT64

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        # Use scalar libm precision and special-value semantics through LLVM.
        return Noun(llvm_intrinsic["llvm.exp.f64", Float64](y.as_float()))

    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        if y.dtype == NounDType.BOOL:
            return x.copy() if y.as_bool() else _one(x.dtype)
        var exponent = y.as_float()
        var odd = _float_odd(exponent)
        var base = x.as_float()
        if y.dtype == NounDType.INT:
            odd = y.as_int() % 2 != 0
        elif base == 0.0:
            base = 0.0
        return Noun(_real_power(base, exponent, odd))

    @staticmethod
    def insert_identity(dtype: NounDType) -> Noun:
        return _one(dtype)


def _real_log(value: Float64) raises -> Float64:
    if value < 0.0:
        raise Error("Logarithm requires Complex for a negative argument")
    return llvm_intrinsic["llvm.log.f64", Float64](value)


struct Logarithm(AtomicKernel):
    """Natural logarithm and logarithm to a real base."""

    @staticmethod
    def describe() -> String:
        return "^."

    @staticmethod
    def monad_dtype(y: NounDType) -> NounDType:
        return NounDType.FLOAT64

    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) -> NounDType:
        return NounDType.FLOAT64

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        return Noun(_real_log(y.as_float()))

    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        var denominator = _real_log(x.as_float())
        var numerator = _real_log(y.as_float())
        if isinf(denominator) and isinf(numerator):
            raise Error("Logarithm is undefined for two infinite logarithms")
        return Noun(_float_divide(numerator, denominator))


struct NthRoot(AtomicKernel):
    """Real square root and principal root of the given degree."""

    @staticmethod
    def describe() -> String:
        return "%:"

    @staticmethod
    def monad_dtype(y: NounDType) -> NounDType:
        return NounDType.FLOAT64

    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) -> NounDType:
        return NounDType.FLOAT64

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        var value = y.as_float()
        if value < 0.0:
            raise Error("Root monad rejects negative real values without Complex")
        return Noun(sqrt(value))

    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        var degree = x.as_float()
        var radicand = y.as_float()
        if radicand == 0.0:
            radicand = 0.0
        if degree == 2.0:
            return Self.scalar_monad(Noun(radicand))
        var exponent = 1.0 / degree
        return Noun(_real_power(radicand, exponent, _float_odd(exponent)))

    @staticmethod
    def insert_identity(dtype: NounDType) -> Noun:
        return _one(dtype)
