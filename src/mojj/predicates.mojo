"""Scalar comparisons, whole-noun match, and Boolean operations."""

from std.math import abs, isinf, isnan

from ._atomic import AtomicKernel
from ._verb_base import (
    WHOLE_NOUN_RANK,
    _checked_sub,
    _checked_add,
    _numeric_int,
)
from .nouns import Noun, NounDType


comptime COMPARISON_TOLERANCE: Float64 = 0.000000000000056843418860808015


def tolerant_equal(left: Float64, right: Float64) -> Bool:
    """Use J's default relative comparison tolerance of 2^-44."""
    if left == right:
        return True
    if (
        isnan(left)
        or isnan(right)
        or isinf(left)
        or isinf(right)
        or (left < 0.0) != (right < 0.0)
    ):
        return False
    var a = abs(left)
    var b = abs(right)
    # The pinned J comparison uses an open interval at the rounded bound.
    return min(a, b) > (1.0 - COMPARISON_TOLERANCE) * max(a, b)


@fieldwise_init
struct _Relation(Equatable, ImplicitlyCopyable):
    var tag: Int

    def __eq__(self, other: Self) -> Bool:
        return self.tag == other.tag

    comptime LESS = Self(-1)
    comptime EQUAL = Self(0)
    comptime GREATER = Self(1)
    comptime UNORDERED = Self(2)


def _compare(left: Noun, right: Noun) raises -> _Relation:
    if not left.is_float64() and not right.is_float64():
        var a = _numeric_int(left)
        var b = _numeric_int(right)
        if a == b:
            return _Relation.EQUAL
        return _Relation.LESS if a < b else _Relation.GREATER
    var a = left.as_float()
    var b = right.as_float()
    if tolerant_equal(a, b):
        return _Relation.EQUAL
    if a < b:
        return _Relation.LESS
    if a > b:
        return _Relation.GREATER
    return _Relation.UNORDERED


struct _ComparisonKind:
    comptime EQUAL = 0
    comptime UNEQUAL = 1
    comptime LESS = 2
    comptime GREATER = 3
    comptime LESS_EQUAL = 4
    comptime GREATER_EQUAL = 5


struct _Comparison[kind: Int](AtomicKernel):
    @staticmethod
    def describe() -> String:
        comptime if Self.kind == _ComparisonKind.EQUAL:
            return "equal"
        elif Self.kind == _ComparisonKind.UNEQUAL:
            return "unequal"
        elif Self.kind == _ComparisonKind.LESS:
            return "less"
        elif Self.kind == _ComparisonKind.GREATER:
            return "greater"
        elif Self.kind == _ComparisonKind.LESS_EQUAL:
            return "less-equal"
        else:
            return "greater-equal"

    @staticmethod
    def monad_dtype(y: NounDType) raises -> NounDType:
        comptime if (
            Self.kind == _ComparisonKind.LESS_EQUAL
            or Self.kind == _ComparisonKind.GREATER_EQUAL
        ):
            return (
                NounDType.FLOAT64 if y == NounDType.FLOAT64 else NounDType.INT
            )
        else:
            raise Error(Self.describe() + " monad is unsupported")

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        comptime if Self.kind == _ComparisonKind.LESS_EQUAL:
            if y.is_float64():
                return Noun(y.as_float() - 1.0)
            return Noun(_checked_sub(_numeric_int(y), 1, "decrement"))
        elif Self.kind == _ComparisonKind.GREATER_EQUAL:
            if y.is_float64():
                return Noun(y.as_float() + 1.0)
            return Noun(_checked_add(_numeric_int(y), 1, "increment"))
        else:
            raise Error(Self.describe() + " monad is unsupported")

    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) raises -> NounDType:
        return NounDType.BOOL

    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        var relation = _compare(x, y)
        comptime if Self.kind == _ComparisonKind.EQUAL:
            return Noun(relation == _Relation.EQUAL)
        elif Self.kind == _ComparisonKind.UNEQUAL:
            return Noun(relation != _Relation.EQUAL)
        elif Self.kind == _ComparisonKind.LESS:
            return Noun(relation == _Relation.LESS)
        elif Self.kind == _ComparisonKind.GREATER:
            return Noun(relation == _Relation.GREATER)
        elif Self.kind == _ComparisonKind.LESS_EQUAL:
            return Noun(
                relation == _Relation.LESS or relation == _Relation.EQUAL
            )
        else:
            return Noun(
                relation == _Relation.GREATER or relation == _Relation.EQUAL
            )

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        return Noun(
            Self.kind == _ComparisonKind.EQUAL
            or Self.kind == _ComparisonKind.LESS_EQUAL
            or Self.kind == _ComparisonKind.GREATER_EQUAL
        )


comptime Equal = _Comparison[_ComparisonKind.EQUAL]
comptime Unequal = _Comparison[_ComparisonKind.UNEQUAL]
comptime Less = _Comparison[_ComparisonKind.LESS]
comptime Greater = _Comparison[_ComparisonKind.GREATER]
comptime LessEqual = _Comparison[_ComparisonKind.LESS_EQUAL]
comptime GreaterEqual = _Comparison[_ComparisonKind.GREATER_EQUAL]


def _matches(left: Noun, right: Noun) raises -> Bool:
    # J's whole-noun comparison treats an unordered atom as a match.
    var relation = _compare(left, right)
    return relation == _Relation.EQUAL or relation == _Relation.UNORDERED


struct MatchHalve(AtomicKernel):
    """Halve each cell or compare two entire nouns for a shape and value match.
    """

    @staticmethod
    def describe() -> String:
        return "match"

    @staticmethod
    def monad_dtype(y: NounDType) raises -> NounDType:
        return NounDType.FLOAT64

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        return Noun(y.as_float() * 0.5)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        if not x.same_shape(y):
            return Noun(False)
        if x.is_scalar():
            return Noun(_matches(x, y))
        for index in range(x.length()):
            if not _matches(x.at(index), y.at(index)):
                return Noun(False)
        return Noun(True)

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct Complement(AtomicKernel):
    """Boolean not or the numeric complement 1-y."""

    @staticmethod
    def describe() -> String:
        return "complement"

    @staticmethod
    def monad_dtype(y: NounDType) raises -> NounDType:
        return y

    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        if y.is_bool():
            return Noun(not y.as_bool())
        if y.is_int():
            return Noun(_checked_sub(1, y.as_int(), "complement"))
        return Noun(1.0 - y.as_float())


def boolean_value(y: Noun) raises -> Bool:
    """Read Boolean-domain scalar data, including numeric 0 and 1."""
    if y.is_bool():
        return y.as_bool()
    if y.is_int():
        var value = y.as_int()
        if value == 0 or value == 1:
            return value == 1
    else:
        var value = y.as_float()
        if value == 0.0:
            return False
        if tolerant_equal(value, 1.0):
            return True
    raise Error("Boolean operation requires values of 0 or 1")


struct _BooleanKind:
    comptime OR = 0
    comptime AND = 1
    comptime NOR = 2
    comptime NAND = 3


struct _Boolean[kind: Int](AtomicKernel):
    @staticmethod
    def describe() -> String:
        comptime if Self.kind == _BooleanKind.OR:
            return "or"
        elif Self.kind == _BooleanKind.AND:
            return "and"
        elif Self.kind == _BooleanKind.NOR:
            return "nor"
        else:
            return "nand"

    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) raises -> NounDType:
        return NounDType.BOOL

    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        var left = boolean_value(x)
        var right = boolean_value(y)
        comptime if Self.kind == _BooleanKind.OR:
            return Noun(left or right)
        elif Self.kind == _BooleanKind.AND:
            return Noun(left and right)
        elif Self.kind == _BooleanKind.NOR:
            return Noun(not (left or right))
        else:
            return Noun(not (left and right))

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        comptime if Self.kind == _BooleanKind.OR:
            return Noun(False)
        elif Self.kind == _BooleanKind.AND:
            return Noun(True)
        else:
            raise Error(Self.describe() + " has no empty insertion identity")


comptime Or = _Boolean[_BooleanKind.OR]
comptime And = _Boolean[_BooleanKind.AND]
comptime Nor = _Boolean[_BooleanKind.NOR]
comptime Nand = _Boolean[_BooleanKind.NAND]
