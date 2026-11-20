"""Typed arithmetic, selectors, reductions, and J verb trains."""

from std.collections import List
from std.math import sqrt

from .nouns import (
    Noun,
    NounDType,
    NounProvider,
    SCALAR_RANK,
    VECTOR_RANK,
    agreement_length,
    agreed_atom,
    agreement_dims,
    shape_size,
)


from ._atomic import _empty, _append
from .array_modifiers import Table, rank_monad, rank_dyad
from .arrays import Copy
from .predicates import Nand, Nor
from .real_verbs import NthRoot
from ._verb_base import (
    Verb, WHOLE_NOUN_RANK, ATOM_RANK, _require_numeric, _numeric_int,
    _is_integer_numeric, _checked_add, _checked_sub, _checked_mul,
    _checked_neg, _float_divide,
)


def _monad_shape(var result: Noun, source: Noun) raises -> Noun:
    if source.rank > 1:
        result.set_shape(source.dims())
    return result^


def _dyad_shape(var result: Noun, x: Noun, y: Noun) raises -> Noun:
    if x.rank > 1 or y.rank > 1:
        result.set_shape(agreement_dims(x, y))
    return result^


def _map_float64_vector[Op: Verb](values: List[Float64]) raises -> Noun:
    """Apply a verb's Float64 monad kernel to each element.

    Equivalent to mapping ``Op.monad`` over scalar cells, but without building a
    scalar Noun per cell.  Only verbs that advertise ``has_float64_monad`` reach
    this path.
    """
    var length = len(values)
    var result = List[Float64](length=length, fill=0.0)
    var source = values.unsafe_ptr()
    var target = result.unsafe_ptr()
    for index in range(length):
        target[unsafe_offset=index] = Op.float64_monad(
            source[unsafe_offset=index]
        )
    return Noun.from_owned_float64(result^)


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
                    _numeric_int(agreed_atom(x, y, index)),
                    _numeric_int(agreed_atom(y, x, index)),
                    "addition",
                )
            return _dyad_shape(Noun(result), x, y)
        if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
            return Noun(x.as_float() + y.as_float())
        var float_result = List[Float64](length=output_length, fill=0.0)
        for index in range(output_length):
            float_result[index] = (
                agreed_atom(x, y, index).as_float() + agreed_atom(y, x, index).as_float()
            )
        return _dyad_shape(Noun(float_result), x, y)

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

    @staticmethod
    def has_float64_monad() -> Bool:
        return True

    @staticmethod
    def float64_monad(value: Float64) raises -> Float64:
        return value

    @staticmethod
    def has_float64_dyad() -> Bool:
        return True

    @staticmethod
    def float64_dyad(left: Float64, right: Float64) raises -> Float64:
        return left + right


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
            return _monad_shape(Noun(result), y)
        return _monad_shape(_map_float64_vector[Minus](y.float_values), y)

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
                    _numeric_int(agreed_atom(x, y, index)),
                    _numeric_int(agreed_atom(y, x, index)),
                    "subtraction",
                )
            return _dyad_shape(Noun(result), x, y)
        if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
            return Noun(x.as_float() - y.as_float())
        var float_result = List[Float64](length=output_length, fill=0.0)
        for index in range(output_length):
            float_result[index] = (
                agreed_atom(x, y, index).as_float() - agreed_atom(y, x, index).as_float()
            )
        return _dyad_shape(Noun(float_result), x, y)

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

    @staticmethod
    def has_float64_monad() -> Bool:
        return True

    @staticmethod
    def float64_monad(value: Float64) raises -> Float64:
        return -value

    @staticmethod
    def has_float64_dyad() -> Bool:
        return True

    @staticmethod
    def float64_dyad(left: Float64, right: Float64) raises -> Float64:
        return left - right


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
            return _monad_shape(Noun(int_result), y)
        return _monad_shape(_map_float64_vector[Times](y.float_values), y)

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
                    _numeric_int(agreed_atom(x, y, index)),
                    _numeric_int(agreed_atom(y, x, index)),
                    "multiplication",
                )
            return _dyad_shape(Noun(result), x, y)
        if x.rank == SCALAR_RANK and y.rank == SCALAR_RANK:
            return Noun(x.as_float() * y.as_float())
        var float_result = List[Float64](length=output_length, fill=0.0)
        for index in range(output_length):
            float_result[index] = (
                agreed_atom(x, y, index).as_float() * agreed_atom(y, x, index).as_float()
            )
        return _dyad_shape(Noun(float_result), x, y)

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

    @staticmethod
    def has_float64_monad() -> Bool:
        return True

    @staticmethod
    def float64_monad(value: Float64) raises -> Float64:
        if value < 0.0:
            return -1.0
        if value == 0.0:
            return 0.0
        return 1.0

    @staticmethod
    def has_float64_dyad() -> Bool:
        return True

    @staticmethod
    def float64_dyad(left: Float64, right: Float64) raises -> Float64:
        return left * right


struct Divide(Verb):
    """Reciprocal as a monad and J-compatible real division as a dyad."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        _require_numeric(y, "Divide monad")
        if y.rank == SCALAR_RANK:
            return Noun(_float_divide(1.0, y.as_float()))
        if y.dtype == NounDType.FLOAT64:
            return _monad_shape(_map_float64_vector[Divide](y.float_values), y)
        var result = List[Float64](length=y.length(), fill=0.0)
        for index in range(y.length()):
            result[index] = _float_divide(1.0, y.at(index).as_float())
        return _monad_shape(Noun(result), y)

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
                agreed_atom(x, y, index).as_float(), agreed_atom(y, x, index).as_float()
            )
        return _dyad_shape(Noun(result), x, y)

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

    @staticmethod
    def has_float64_monad() -> Bool:
        return True

    @staticmethod
    def float64_monad(value: Float64) raises -> Float64:
        return _float_divide(1.0, value)

    @staticmethod
    def has_float64_dyad() -> Bool:
        return True

    @staticmethod
    def float64_dyad(left: Float64, right: Float64) raises -> Float64:
        return _float_divide(left, right)


struct Squared(Verb):
    """Square as a monad and Boolean NAND as a dyad."""

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
            return _monad_shape(Noun(result), y)
        return _monad_shape(_map_float64_vector[Squared](y.float_values), y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Nand.dyad(x, y)

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        return Nand.insert_identity(dtype)

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

    @staticmethod
    def has_float64_monad() -> Bool:
        return True

    @staticmethod
    def float64_monad(value: Float64) raises -> Float64:
        return value * value


struct Doubled(Verb):
    """Double as a monad and Boolean NOR as a dyad."""

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
            return _monad_shape(Noun(result), y)
        comptime width = 4
        var length = len(y.float_values)
        var result = List[Float64](length=length, fill=0.0)
        var source = y.float_values.unsafe_ptr()
        var target = result.unsafe_ptr()
        var index = 0
        var vector_end = length - length % width
        while index < vector_end:
            var values = source.unsafe_load[width=width](index)
            target.unsafe_store[width=width](index, values + values)
            index += width
        while index < length:
            var value = source[unsafe_offset=index]
            target[unsafe_offset=index] = value + value
            index += 1
        return _monad_shape(Noun.from_owned_float64(result^), y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Nor.dyad(x, y)

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        return Nor.insert_identity(dtype)

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

    @staticmethod
    def has_float64_monad() -> Bool:
        return True

    @staticmethod
    def float64_monad(value: Float64) raises -> Float64:
        return value + value


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
        if y.dtype == NounDType.FLOAT64:
            return _monad_shape(_map_float64_vector[Root](y.float_values), y)
        var result = List[Float64](length=y.length(), fill=0.0)
        for index in range(y.length()):
            var value = y.at(index).as_float()
            if value < 0.0:
                raise Error("Root monad rejects negative real values without Complex")
            result[index] = sqrt(value)
        return _monad_shape(Noun(result), y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return NthRoot.dyad(x, y)

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        return NthRoot.insert_identity(dtype)

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

    @staticmethod
    def has_float64_monad() -> Bool:
        return True

    @staticmethod
    def float64_monad(value: Float64) raises -> Float64:
        if value < 0.0:
            raise Error("Root monad rejects negative real values without Complex")
        return sqrt(value)


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
    """Count leading items or replicate them by nonnegative counts."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        if y.rank > 1:
            return Noun(y.axis_length(0))
        return Noun(y.length())

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Copy.dyad(x, y)

    @staticmethod
    def describe() -> String:
        return "#"

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return Copy.left_rank()

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


def _row(y: Noun, index: Int, shape: List[Int], width: Int) raises -> Noun:
    var cell = _empty(y.dtype)
    for offset in range(width):
        _append(cell, y.at(index * width + offset))
    cell.set_shape(shape)
    return cell^


struct Insert[Op: Verb](Verb):
    """Right-fold leading items as a monad and form a table as a dyad."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        if y.rank == SCALAR_RANK:
            return y.copy()
        if y.rank > 1:
            var cell_shape = y.dims()
            var rows = cell_shape.pop(0)
            var width = shape_size(cell_shape)
            if rows == 0:
                var identity = Self.Op.insert_identity(y.dtype)
                var cells = _empty(identity.dtype)
                for _ in range(width):
                    _append(cells, identity)
                cells.set_shape(cell_shape)
                return cells^
            var folded = _row(y, rows - 1, cell_shape, width)
            for step in range(1, rows):
                folded = Self.Op.dyad(_row(y, rows - 1 - step, cell_shape, width), folded)
            return folded^
        if y.length() == 0:
            return Self.Op.insert_identity(y.dtype)
        if y.dtype == NounDType.FLOAT64 and Self.Op.has_float64_dyad():
            # Same right fold as the generic path, but over unboxed elements.
            var length = y.length()
            var values = y.float_values.unsafe_ptr()
            var accumulator = values[unsafe_offset=length - 1]
            var index = length - 1
            while index > 0:
                index -= 1
                accumulator = Self.Op.float64_dyad(
                    values[unsafe_offset=index], accumulator
                )
            return Noun(accumulator)
        var result = y.at(y.length() - 1)
        var index = y.length() - 1
        while index > 0:
            index -= 1
            var left = y.at(index)
            result = Self.Op.dyad(left, result)
        return result^

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Table[Self.Op].dyad(x, y)

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
        var rank = Self.G.monad_cell_rank(y.rank)
        if rank == ATOM_RANK and y.is_float64() and Self.G.has_float64_monad() and Self.F.has_float64_monad() and not y.is_scalar():
            var inner = Self.G.monad(y)
            return _monad_shape(_map_float64_vector[Self.F](inner.float_values), y)
        return rank_monad[ComposeAll[Self.F, Self.G]](y, rank)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return rank_dyad[ComposeAll[Self.F, Self.G]](
            x, y, Self.G.left_cell_rank(x.rank), Self.G.right_cell_rank(y.rank)
        )

    @staticmethod
    def describe() -> String:
        return "atop(" + Self.F.describe() + ", " + Self.G.describe() + ")"

    @staticmethod
    def monad_rank() -> Int:
        return Self.G.monad_rank()

    @staticmethod
    def monad_cell_rank(noun_rank: Int) -> Int:
        return Self.G.monad_cell_rank(noun_rank)

    @staticmethod
    def left_rank() -> Int:
        return Self.G.left_rank()

    @staticmethod
    def left_cell_rank(noun_rank: Int) -> Int:
        return Self.G.left_cell_rank(noun_rank)

    @staticmethod
    def right_rank() -> Int:
        return Self.G.right_rank()

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return Self.G.right_cell_rank(noun_rank)


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
    def left_cell_rank(noun_rank: Int) -> Int:
        return Self.Op.left_cell_rank(noun_rank)

    @staticmethod
    def right_rank() -> Int:
        return Self.Op.right_rank()

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return Self.Op.right_cell_rank(noun_rank)


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
    def left_cell_rank(noun_rank: Int) -> Int:
        return Self.Op.left_cell_rank(noun_rank)

    @staticmethod
    def right_rank() -> Int:
        return Self.Op.right_rank()

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return Self.Op.right_cell_rank(noun_rank)


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
    def left_cell_rank(noun_rank: Int) -> Int:
        return Self.Op.left_cell_rank(noun_rank)

    @staticmethod
    def right_rank() -> Int:
        return Self.Op.right_rank()

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return Self.Op.right_cell_rank(noun_rank)


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
    def left_cell_rank(noun_rank: Int) -> Int:
        return Self.Op.left_cell_rank(noun_rank)

    @staticmethod
    def right_rank() -> Int:
        return Self.Op.right_rank()

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return Self.Op.right_cell_rank(noun_rank)


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
