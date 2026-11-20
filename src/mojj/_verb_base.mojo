"""Verb contract and shared numeric operations."""
from .nouns import Noun, NounDType


comptime WHOLE_NOUN_RANK = -1
comptime ATOM_RANK = 0


trait Verb:
    """An ambivalent typed verb with explicit supported ranks."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        ...

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        ...

    @staticmethod
    def describe() -> String:
        ...

    @staticmethod
    def monad_rank() -> Int:
        ...

    @staticmethod
    def left_rank() -> Int:
        ...

    @staticmethod
    def right_rank() -> Int:
        ...

    @staticmethod
    def monad_cell_rank(noun_rank: Int) -> Int:
        return _native_cell_rank(Self.monad_rank(), noun_rank)

    @staticmethod
    def left_cell_rank(noun_rank: Int) -> Int:
        return _native_cell_rank(Self.left_rank(), noun_rank)

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return _native_cell_rank(Self.right_rank(), noun_rank)

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        raise Error("Insert identity is unsupported for this verb")

    # Optional Float64 fast-path kernels.  The defaults declare that a verb has
    # no kernel, so evaluators fall back to the generic Noun path, which remains
    # the reference implementation and oracle.  A verb that overrides these must
    # reproduce its generic Float64 behavior exactly, including error messages.
    @staticmethod
    def has_float64_monad() -> Bool:
        return False

    @staticmethod
    def float64_monad(value: Float64) raises -> Float64:
        raise Error("this verb has no Float64 monad kernel")

    @staticmethod
    def has_float64_dyad() -> Bool:
        return False

    @staticmethod
    def float64_dyad(left: Float64, right: Float64) raises -> Float64:
        raise Error("this verb has no Float64 dyad kernel")


def _native_cell_rank(rank: Int, noun_rank: Int) -> Int:
    if rank == WHOLE_NOUN_RANK:
        return noun_rank
    return min(rank, noun_rank)


def _require_numeric(noun: Noun, operation: String) raises:
    """Validate the currently supported numeric dtype domain."""
    if (
        noun.dtype != NounDType.INT
        and noun.dtype != NounDType.FLOAT64
        and noun.dtype != NounDType.BOOL
    ):
        raise Error(operation + " received an unsupported noun dtype")


def _numeric_int(noun: Noun) raises -> Int:
    """Read Int/Bool as exact integer data without widening to Float64."""
    if noun.dtype == NounDType.INT:
        return noun.as_int()
    if noun.dtype == NounDType.BOOL:
        if noun.as_bool():
            return 1
        return 0
    raise Error("exact integer access requires an Int or Bool noun")


def _is_integer_numeric(dtype: NounDType) -> Bool:
    return dtype == NounDType.INT or dtype == NounDType.BOOL


def _checked_add(left: Int, right: Int, operation: String) raises -> Int:
    var wide: Int128 = Int128(left) + Int128(right)
    if wide > Int128(Int.MAX) or wide < Int128(Int.MIN):
        raise Error("Int overflow in " + operation)
    return Int(wide)


def _checked_sub(left: Int, right: Int, operation: String) raises -> Int:
    var wide: Int128 = Int128(left) - Int128(right)
    if wide > Int128(Int.MAX) or wide < Int128(Int.MIN):
        raise Error("Int overflow in " + operation)
    return Int(wide)


def _checked_mul(left: Int, right: Int, operation: String) raises -> Int:
    var wide: Int128 = Int128(left) * Int128(right)
    if wide > Int128(Int.MAX) or wide < Int128(Int.MIN):
        raise Error("Int overflow in " + operation)
    return Int(wide)


def _checked_neg(value: Int) raises -> Int:
    var wide: Int128 = -Int128(value)
    if wide > Int128(Int.MAX) or wide < Int128(Int.MIN):
        raise Error("Int overflow in negation")
    return Int(wide)


def _float_divide(numerator: Float64, denominator: Float64) -> Float64:
    # J specifies the indeterminate 0%0 case as 0.  Other zero denominators
    # retain IEEE division behavior (signed infinity where supported).
    if numerator == 0.0 and denominator == 0.0:
        return 0.0
    return numerator / denominator
