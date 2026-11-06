"""Typed J verbs and the small modifier set used by the P1 semantic core."""

from std.collections import List
from std.math import sqrt

from .nouns import (
    Noun,
    NounDType,
    NounProvider,
    SCALAR_RANK,
    VECTOR_RANK,
    agreement_length,
    agreed_at,
)


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
    def insert_identity(dtype: NounDType) raises -> Noun:
        raise Error("Insert identity is unsupported for this verb in P1")


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


struct Plus(Verb):
    """Conjugate/plus: identity as a monad and checked addition as a dyad."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        _require_numeric(y, "Plus monad")
        return y.copy()

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        _require_numeric(x, "Plus dyad")
        _require_numeric(y, "Plus dyad")
        var output_length = agreement_length(x, y)
        if _is_integer_numeric(x.dtype) and _is_integer_numeric(y.dtype):
            if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
                return Noun(_checked_add(_numeric_int(x), _numeric_int(y), "addition"))
            var result = List[Int](length=output_length, fill=0)
            for index in range(output_length):
                result[index] = _checked_add(
                    _numeric_int(agreed_at(x, index)),
                    _numeric_int(agreed_at(y, index)),
                    "addition",
                )
            return Noun(result)
        if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
            return Noun(x.as_float() + y.as_float())
        var float_result = List[Float64](length=output_length, fill=0.0)
        for index in range(output_length):
            float_result[index] = (
                agreed_at(x, index).as_float() + agreed_at(y, index).as_float()
            )
        return Noun(float_result)

    @staticmethod
    def describe() -> String:
        return "+"

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
        if dtype == NounDType.INT or dtype == NounDType.BOOL:
            return Noun(0)
        if dtype == NounDType.FLOAT64:
            return Noun(0.0)
        raise Error("Plus insert identity received an unsupported dtype")


struct Minus(Verb):
    """Negate as a monad and checked subtraction as a dyad."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        _require_numeric(y, "Minus monad")
        if y.rank == SCALAR_RANK:
            if _is_integer_numeric(y.dtype):
                return Noun(_checked_neg(_numeric_int(y)))
            return Noun(-y.as_float())
        if _is_integer_numeric(y.dtype):
            var result = List[Int](length=y.length(), fill=0)
            for index in range(y.length()):
                result[index] = _checked_neg(_numeric_int(y.at(index)))
            return Noun(result)
        var float_result = List[Float64](length=y.length(), fill=0.0)
        for index in range(y.length()):
            float_result[index] = -y.at(index).as_float()
        return Noun(float_result)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        _require_numeric(x, "Minus dyad")
        _require_numeric(y, "Minus dyad")
        var output_length = agreement_length(x, y)
        if _is_integer_numeric(x.dtype) and _is_integer_numeric(y.dtype):
            if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
                return Noun(_checked_sub(_numeric_int(x), _numeric_int(y), "subtraction"))
            var result = List[Int](length=output_length, fill=0)
            for index in range(output_length):
                result[index] = _checked_sub(
                    _numeric_int(agreed_at(x, index)),
                    _numeric_int(agreed_at(y, index)),
                    "subtraction",
                )
            return Noun(result)
        if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
            return Noun(x.as_float() - y.as_float())
        var float_result = List[Float64](length=output_length, fill=0.0)
        for index in range(output_length):
            float_result[index] = (
                agreed_at(x, index).as_float() - agreed_at(y, index).as_float()
            )
        return Noun(float_result)

    @staticmethod
    def describe() -> String:
        return "-"

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
        if dtype == NounDType.INT or dtype == NounDType.BOOL:
            return Noun(0)
        if dtype == NounDType.FLOAT64:
            return Noun(0.0)
        raise Error("Minus insert identity received an unsupported dtype")


struct Times(Verb):
    """Signum as a monad and checked multiplication as a dyad."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        _require_numeric(y, "Times monad")
        if y.rank == SCALAR_RANK:
            if _is_integer_numeric(y.dtype):
                var value = _numeric_int(y)
                if value < 0:
                    return Noun(-1)
                if value == 0:
                    return Noun(0)
                return Noun(1)
            var float_value = y.as_float()
            if float_value < 0.0:
                return Noun(-1.0)
            if float_value == 0.0:
                return Noun(0.0)
            return Noun(1.0)
        if _is_integer_numeric(y.dtype):
            var int_result = List[Int](length=y.length(), fill=0)
            for index in range(y.length()):
                var value = _numeric_int(y.at(index))
                if value < 0:
                    int_result[index] = -1
                elif value == 0:
                    int_result[index] = 0
                else:
                    int_result[index] = 1
            return Noun(int_result)
        var float_result = List[Float64](length=y.length(), fill=0.0)
        for index in range(y.length()):
            var value = y.at(index).as_float()
            if value < 0.0:
                float_result[index] = -1.0
            elif value == 0.0:
                float_result[index] = 0.0
            else:
                float_result[index] = 1.0
        return Noun(float_result)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        _require_numeric(x, "Times dyad")
        _require_numeric(y, "Times dyad")
        var output_length = agreement_length(x, y)
        if _is_integer_numeric(x.dtype) and _is_integer_numeric(y.dtype):
            if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
                return Noun(_checked_mul(_numeric_int(x), _numeric_int(y), "multiplication"))
            var result = List[Int](length=output_length, fill=0)
            for index in range(output_length):
                result[index] = _checked_mul(
                    _numeric_int(agreed_at(x, index)),
                    _numeric_int(agreed_at(y, index)),
                    "multiplication",
                )
            return Noun(result)
        if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
            return Noun(x.as_float() * y.as_float())
        var float_result = List[Float64](length=output_length, fill=0.0)
        for index in range(output_length):
            float_result[index] = (
                agreed_at(x, index).as_float() * agreed_at(y, index).as_float()
            )
        return Noun(float_result)

    @staticmethod
    def describe() -> String:
        return "*"

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
        if dtype == NounDType.INT or dtype == NounDType.BOOL:
            return Noun(1)
        if dtype == NounDType.FLOAT64:
            return Noun(1.0)
        raise Error("Times insert identity received an unsupported dtype")


struct Divide(Verb):
    """Reciprocal as a monad and J-compatible real division as a dyad."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        _require_numeric(y, "Divide monad")
        if y.rank == SCALAR_RANK:
            return Noun(_float_divide(1.0, y.as_float()))
        var result = List[Float64](length=y.length(), fill=0.0)
        for index in range(y.length()):
            result[index] = _float_divide(1.0, y.at(index).as_float())
        return Noun(result)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        _require_numeric(x, "Divide dyad")
        _require_numeric(y, "Divide dyad")
        var output_length = agreement_length(x, y)
        if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
            return Noun(_float_divide(x.as_float(), y.as_float()))
        var result = List[Float64](length=output_length, fill=0.0)
        for index in range(output_length):
            result[index] = _float_divide(
                agreed_at(x, index).as_float(), agreed_at(y, index).as_float()
            )
        return Noun(result)

    @staticmethod
    def describe() -> String:
        return "%"

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
        if dtype == NounDType.INT or dtype == NounDType.BOOL:
            return Noun(1)
        if dtype == NounDType.FLOAT64:
            return Noun(1.0)
        raise Error("Divide insert identity received an unsupported dtype")


struct Squared(Verb):
    """The monadic square verb; its Boolean dyad is intentionally deferred."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        _require_numeric(y, "Squared monad")
        if y.rank == SCALAR_RANK:
            if _is_integer_numeric(y.dtype):
                var value = _numeric_int(y)
                return Noun(_checked_mul(value, value, "square"))
            return Noun(y.as_float() * y.as_float())
        if _is_integer_numeric(y.dtype):
            var result = List[Int](length=y.length(), fill=0)
            for index in range(y.length()):
                var value = _numeric_int(y.at(index))
                result[index] = _checked_mul(value, value, "square")
            return Noun(result)
        var float_result = List[Float64](length=y.length(), fill=0.0)
        for index in range(y.length()):
            var value = y.at(index).as_float()
            float_result[index] = value * value
        return Noun(float_result)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("Squared dyad is unsupported in P1 (Boolean nand is deferred)")

    @staticmethod
    def describe() -> String:
        return "*:"

    @staticmethod
    def monad_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def left_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def right_rank() -> Int:
        return ATOM_RANK


struct Doubled(Verb):
    """The monadic double verb; its Boolean dyad is intentionally deferred."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        _require_numeric(y, "Doubled monad")
        if y.rank == SCALAR_RANK:
            if _is_integer_numeric(y.dtype):
                var value = _numeric_int(y)
                return Noun(_checked_add(value, value, "double"))
            return Noun(y.as_float() + y.as_float())
        if _is_integer_numeric(y.dtype):
            var result = List[Int](length=y.length(), fill=0)
            for index in range(y.length()):
                var value = _numeric_int(y.at(index))
                result[index] = _checked_add(value, value, "double")
            return Noun(result)
        var float_result = List[Float64](length=y.length(), fill=0.0)
        for index in range(y.length()):
            var value = y.at(index).as_float()
            float_result[index] = value + value
        return Noun(float_result)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("Doubled dyad is unsupported in P1 (Boolean nor is deferred)")

    @staticmethod
    def describe() -> String:
        return "+:"

    @staticmethod
    def monad_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def left_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def right_rank() -> Int:
        return ATOM_RANK


struct Root(Verb):
    """Real square root; negative and root-degree cases are explicit errors."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        _require_numeric(y, "Root monad")
        if y.rank == SCALAR_RANK:
            var value = y.as_float()
            if value < 0.0:
                raise Error("Root monad rejects negative real values without Complex")
            return Noun(sqrt(value))
        var result = List[Float64](length=y.length(), fill=0.0)
        for index in range(y.length()):
            var value = y.at(index).as_float()
            if value < 0.0:
                raise Error("Root monad rejects negative real values without Complex")
            result[index] = sqrt(value)
        return Noun(result)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("Root dyad is unsupported in P1 (root degree is deferred)")

    @staticmethod
    def describe() -> String:
        return "%:"

    @staticmethod
    def monad_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def left_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def right_rank() -> Int:
        return ATOM_RANK


struct Left(Verb):
    """The left selector: identity as a monad and left argument as a dyad."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return y.copy()

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return x.copy()

    @staticmethod
    def describe() -> String:
        return "["

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct Right(Verb):
    """The right selector: identity as a monad and right argument as a dyad."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return y.copy()

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return y.copy()

    @staticmethod
    def describe() -> String:
        return "]"

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct Tally(Verb):
    """Count items exactly as Int; the copy dyad is deferred."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Noun(y.length())

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("Tally dyad is unsupported in P1 (copy is deferred)")

    @staticmethod
    def describe() -> String:
        return "#"

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct Insert[Op: Verb](Verb):
    """Right-grouped insertion/reduction over a scalar or vector noun.

    P1 intentionally supports only the monadic reduction case.  The dyadic
    table/outer-product form needs shaped rank-2 nouns and is kept as an
    explicit unsupported valence.
    """

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        if y.rank == SCALAR_RANK:
            return y.copy()
        if y.length() == 0:
            return Self.Op.insert_identity(y.dtype)
        var result = y.at(y.length() - 1)
        var index = y.length() - 1
        while index > 0:
            index -= 1
            var left = y.at(index)
            result = Self.Op.dyad(left, result)
            if result.rank != SCALAR_RANK:
                raise Error("Insert operand must produce scalar results in P1")
        return result^

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("Insert dyad is unsupported in P1 (table rank is deferred)")

    @staticmethod
    def describe() -> String:
        return "insert(" + Self.Op.describe() + ")"

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


def _empty_mapped_vector[Op: Verb](sample: Noun) raises -> Noun:
    """Infer an empty per-cell result dtype from one representative cell."""
    var mapped = Op.monad(sample)
    if mapped.rank != SCALAR_RANK:
        raise Error("Atop per-cell application requires scalar cell results")
    if mapped.dtype == NounDType.INT:
        return Noun(List[Int]())
    if mapped.dtype == NounDType.FLOAT64:
        return Noun(List[Float64]())
    if mapped.dtype == NounDType.BOOL:
        return Noun(List[Bool]())
    raise Error("Atop per-cell results have an unsupported dtype")


def _map_monad_per_cell[Op: Verb](value: Noun) raises -> Noun:
    """Apply a monad to each scalar cell, preserving a fresh vector result."""
    if value.rank == SCALAR_RANK:
        return Op.monad(value)
    if value.length() == 0:
        if value.dtype == NounDType.INT:
            return _empty_mapped_vector[Op](Noun(0))
        if value.dtype == NounDType.FLOAT64:
            return _empty_mapped_vector[Op](Noun(0.0))
        return _empty_mapped_vector[Op](Noun(False))

    var first = Op.monad(value.at(0))
    if first.rank != SCALAR_RANK:
        raise Error("Atop per-cell application requires scalar cell results")
    if first.dtype == NounDType.INT:
        var result = List[Int](length=value.length(), fill=0)
        result[0] = first.as_int()
        for index in range(1, value.length()):
            var item = Op.monad(value.at(index))
            if item.rank != SCALAR_RANK or item.dtype != NounDType.INT:
                raise Error("Atop per-cell results must have one dtype")
            result[index] = item.as_int()
        return Noun(result)
    if first.dtype == NounDType.FLOAT64:
        var float_result = List[Float64](length=value.length(), fill=0.0)
        float_result[0] = first.as_float()
        for index in range(1, value.length()):
            var item = Op.monad(value.at(index))
            if item.rank != SCALAR_RANK or item.dtype != NounDType.FLOAT64:
                raise Error("Atop per-cell results must have one dtype")
            float_result[index] = item.as_float()
        return Noun(float_result)
    var bool_result = List[Bool](length=value.length(), fill=False)
    bool_result[0] = first.as_bool()
    for index in range(1, value.length()):
        var item = Op.monad(value.at(index))
        if item.rank != SCALAR_RANK or item.dtype != NounDType.BOOL:
            raise Error("Atop per-cell results must have one dtype")
        bool_result[index] = item.as_bool()
    return Noun(bool_result)


struct Hook[F: Verb, G: Verb](Verb):
    """A two-verb J hook: ``y F (G y)`` and ``x F (G y)``."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.F.dyad(y, Self.G.monad(y))

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Self.F.dyad(x, Self.G.monad(y))

    @staticmethod
    def describe() -> String:
        return "hook(" + Self.F.describe() + ", " + Self.G.describe() + ")"

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct Fork[F: Verb, G: Verb, H: Verb](Verb):
    """A three-verb J fork: ``(F y) G (H y)`` or its dyad analogue."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.G.dyad(Self.F.monad(y), Self.H.monad(y))

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Self.G.dyad(Self.F.dyad(x, y), Self.H.dyad(x, y))

    @staticmethod
    def describe() -> String:
        return "fork(" + Self.F.describe() + ", " + Self.G.describe() + ", " + Self.H.describe() + ")"

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct ComposeAll[F: Verb, G: Verb](Verb):
    """The ``@:`` conjunction: apply the outer monad to the whole inner result."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.F.monad(Self.G.monad(y))

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Self.F.monad(Self.G.dyad(x, y))

    @staticmethod
    def describe() -> String:
        return "compose_all(" + Self.F.describe() + ", " + Self.G.describe() + ")"

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct Atop[F: Verb, G: Verb](Verb):
    """The ``@`` conjunction with the inner verb's finite cell ranks."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        var inner = Self.G.monad(y)
        if Self.G.monad_rank() == WHOLE_NOUN_RANK:
            return Self.F.monad(inner)
        if Self.G.monad_rank() == ATOM_RANK:
            return _map_monad_per_cell[Self.F](inner)
        raise Error("Atop monad does not support the inner verb's rank")

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        var inner = Self.G.dyad(x, y)
        if Self.G.left_rank() == WHOLE_NOUN_RANK and Self.G.right_rank() == WHOLE_NOUN_RANK:
            return Self.F.monad(inner)
        if Self.G.left_rank() == ATOM_RANK and Self.G.right_rank() == ATOM_RANK:
            return _map_monad_per_cell[Self.F](inner)
        raise Error("Atop dyad does not support mixed inner ranks")

    @staticmethod
    def describe() -> String:
        return "atop(" + Self.F.describe() + ", " + Self.G.describe() + ")"

    @staticmethod
    def monad_rank() -> Int:
        return Self.G.monad_rank()

    @staticmethod
    def left_rank() -> Int:
        return Self.G.left_rank()

    @staticmethod
    def right_rank() -> Int:
        return Self.G.right_rank()


struct BindLeft[value: Int, Op: Verb](Verb):
    """The integer convenience form of ``value&Op``."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.Op.dyad(Noun(Self.value), y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("BindLeft dyad is unsupported: the bound noun consumes the left slot")

    @staticmethod
    def describe() -> String:
        return String(Self.value) + "&" + Self.Op.describe()

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return Self.Op.left_rank()

    @staticmethod
    def right_rank() -> Int:
        return Self.Op.right_rank()


struct BindRight[Op: Verb, value: Int](Verb):
    """The integer convenience form of ``Op&value``."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.Op.dyad(y, Noun(Self.value))

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("BindRight dyad is unsupported: the bound noun consumes the right slot")

    @staticmethod
    def describe() -> String:
        return Self.Op.describe() + "&" + String(Self.value)

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return Self.Op.left_rank()

    @staticmethod
    def right_rank() -> Int:
        return Self.Op.right_rank()


struct BindLeftNoun[Value: NounProvider, Op: Verb](Verb):
    """Bind a provider-produced noun into the left dyadic slot."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.Op.dyad(Self.Value.value(), y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("BindLeftNoun dyad is unsupported: the bound noun consumes the left slot")

    @staticmethod
    def describe() -> String:
        return Self.Value.describe() + "&" + Self.Op.describe()

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return Self.Op.left_rank()

    @staticmethod
    def right_rank() -> Int:
        return Self.Op.right_rank()


struct BindRightNoun[Op: Verb, Value: NounProvider](Verb):
    """Bind a provider-produced noun into the right dyadic slot."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.Op.dyad(y, Self.Value.value())

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("BindRightNoun dyad is unsupported: the bound noun consumes the right slot")

    @staticmethod
    def describe() -> String:
        return Self.Op.describe() + "&" + Self.Value.describe()

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return Self.Op.left_rank()

    @staticmethod
    def right_rank() -> Int:
        return Self.Op.right_rank()


struct Constant[value: Int](Verb):
    """The integer convenience constant verb used by numeric noun trains."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Noun(Self.value)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Noun(Self.value)

    @staticmethod
    def describe() -> String:
        return String(Self.value)

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct ConstantNoun[Value: NounProvider](Verb):
    """A constant verb whose noun can be supplied by a typed provider."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.Value.value()

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Self.Value.value()

    @staticmethod
    def describe() -> String:
        return Self.Value.describe()

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK
