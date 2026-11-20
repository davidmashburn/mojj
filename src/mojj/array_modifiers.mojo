"""Cell rank, segments, tables, and inner products for shaped nouns."""

from std.collections import List
from std.math import isfinite, isnan, round

from ._atomic import _append, _empty
from ._verb_base import Verb, ATOM_RANK, WHOLE_NOUN_RANK, _checked_add
from .nouns import Noun, NounDType, shape_size
from .predicates import tolerant_equal


def _axes(dims: List[Int], start: Int, end: Int) -> List[Int]:
    var result = List[Int]()
    for axis in range(start, end):
        result.append(dims[axis])
    return result^


def _join(left: List[Int], right: List[Int]) -> List[Int]:
    var result = left.copy()
    for axis in range(len(right)):
        result.append(right[axis])
    return result^


def _zero(dtype: NounDType) -> Noun:
    if dtype == NounDType.FLOAT64:
        return Noun(0.0)
    if dtype == NounDType.INT:
        return Noun(0)
    return Noun(False)


def _fill(dtype: NounDType, dims: List[Int]) raises -> Noun:
    var result = _empty(dtype)
    var size = shape_size(dims)
    for _ in range(size):
        _append(result, _zero(dtype))
    result.set_shape(dims)
    return result^


def _cell(noun: Noun, start: Int, dims: List[Int]) raises -> Noun:
    if len(dims) == 0:
        return noun.at(start)
    var result = _empty(noun.dtype)
    var size = shape_size(dims)
    for index in range(size):
        _append(result, noun.at(start + index))
    result.set_shape(dims)
    return result^


def _prototype_cell(noun: Noun, frame_rank: Int, cell_dims: List[Int]) raises -> Noun:
    # Even a zero-atom cell exists if every axis in its frame is nonempty.
    for axis in range(frame_rank):
        if noun.axis_length(axis) == 0:
            return _fill(noun.dtype, cell_dims)
    return _cell(noun, 0, cell_dims)


def _assemble(
    frame: List[Int], cells: List[Noun], prototype: Noun
) raises -> Noun:
    if len(cells) == 0:
        var result = _empty(prototype.dtype)
        result.set_shape(_join(frame, prototype.dims()))
        return result^

    var rank = 0
    for i in range(len(cells)):
        rank = max(rank, cells[i].rank)
    var dims = List[Int](length=rank, fill=0)
    for i in range(len(cells)):
        var offset = rank - cells[i].rank
        for axis in range(rank):
            var dim = 1 if axis < offset else cells[i].axis_length(axis - offset)
            dims[axis] = max(dims[axis], dim)

    var shape = _join(frame, dims)
    _ = shape_size(shape)
    var cell_size = shape_size(dims)
    var result = _empty(cells[0].dtype)
    for i in range(len(cells)):
        var cell_dims = cells[i].dims()
        if cell_dims == dims:
            for index in range(cells[i].length()):
                _append(result, cells[i].at(index))
            continue
        var offset = rank - len(cell_dims)
        for index in range(cell_size):
            var position = index
            var source = 0
            var stride = 1
            var inside = True
            for axis in range(rank - 1, -1, -1):
                var coord = position % dims[axis]
                position //= dims[axis]
                var size = 1 if axis < offset else cell_dims[axis - offset]
                if coord >= size:
                    inside = False
                    break
                source += coord * stride
                stride *= size
            if inside:
                _append(result, cells[i].at(source))
            else:
                _append(result, _zero(cells[i].dtype))
    result.set_shape(shape)
    return result^


def _rank_operand(rank: Int, noun_rank: Int) -> Int:
    if rank < 0:
        return max(0, noun_rank + rank)
    return min(rank, noun_rank)


def rank_monad[Op: Verb](y: Noun, cell_rank: Int) raises -> Noun:
    var frame_rank = y.rank - cell_rank
    if frame_rank == 0:
        return Op.monad(y)
    var dims = y.dims()
    var frame = _axes(dims, 0, frame_rank)
    var cell_dims = _axes(dims, frame_rank, y.rank)
    var count = shape_size(frame)
    var cells = List[Noun]()
    if count == 0:
        return _assemble(frame, cells, Op.monad(_fill(y.dtype, cell_dims)))
    var cell_size = shape_size(cell_dims)
    for index in range(count):
        cells.append(Op.monad(_cell(y, index * cell_size, cell_dims)))
    return _assemble(frame, cells, _zero(y.dtype))


def rank_dyad[Op: Verb](
    x: Noun, y: Noun, left_rank: Int, right_rank: Int
) raises -> Noun:
    var left_frame_rank = x.rank - left_rank
    var right_frame_rank = y.rank - right_rank
    if left_frame_rank == 0 and right_frame_rank == 0:
        return Op.dyad(x, y)

    var left_dims = x.dims()
    var right_dims = y.dims()
    for axis in range(min(left_frame_rank, right_frame_rank)):
        if left_dims[axis] != right_dims[axis]:
            raise Error("rank frame agreement failed")
    var frame = _axes(left_dims, 0, left_frame_rank)
    if right_frame_rank > left_frame_rank:
        frame = _axes(right_dims, 0, right_frame_rank)
    var left_cell = _axes(left_dims, left_frame_rank, x.rank)
    var right_cell = _axes(right_dims, right_frame_rank, y.rank)
    var count = shape_size(frame)
    var cells = List[Noun]()
    if count == 0:
        var prototype = Op.dyad(
            _prototype_cell(x, left_frame_rank, left_cell),
            _prototype_cell(y, right_frame_rank, right_cell),
        )
        return _assemble(frame, cells, prototype)

    var left_repeat = shape_size(_axes(frame, left_frame_rank, len(frame)))
    var right_repeat = shape_size(_axes(frame, right_frame_rank, len(frame)))
    var left_size = shape_size(left_cell)
    var right_size = shape_size(right_cell)
    for index in range(count):
        cells.append(
            Op.dyad(
                _cell(x, index // left_repeat * left_size, left_cell),
                _cell(y, index // right_repeat * right_size, right_cell),
            )
        )
    return _assemble(frame, cells, _zero(y.dtype))


struct Rank[Op: Verb, M: Int, L: Int = M, R: Int = L](Verb):
    """Apply the verb to cells selected by the explicit ranks."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return rank_monad[Self.Op](y, _rank_operand(Self.M, y.rank))

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return rank_dyad[Self.Op](x, y, _rank_operand(Self.L, x.rank), _rank_operand(Self.R, y.rank))

    @staticmethod
    def describe() -> String:
        var result = Self.Op.describe() + ' " ' + _rank_text(Self.M)
        if Self.L != Self.M or Self.R != Self.M:
            result += " " + _rank_text(Self.L) + " " + _rank_text(Self.R)
        return result

    @staticmethod
    def monad_rank() -> Int:
        return _reported_rank(Self.M)

    @staticmethod
    def left_rank() -> Int:
        return _reported_rank(Self.L)

    @staticmethod
    def right_rank() -> Int:
        return _reported_rank(Self.R)


def _reported_rank(rank: Int) -> Int:
    # Derived verbs see relative ranks as unbounded. Rank resolves them
    # internally when it receives an argument.
    if rank < 0 or rank == Int.MAX:
        return WHOLE_NOUN_RANK
    return rank


def _rank_text(rank: Int) -> String:
    if rank == Int.MAX:
        return "_"
    if rank < 0:
        return "_" + String(-Int128(rank))
    return String(rank)


def _segment(
    y: Noun, items: Int, start: Int, width: Int, outfix: Bool
) raises -> Noun:
    var dims = y.dims()
    if y.is_scalar():
        dims.append(1)
    var item_size = shape_size(_axes(dims, 1, len(dims)))
    if not outfix:
        dims[0] = width
        return _cell(y, start * item_size, dims)
    dims[0] = items - width
    var result = _empty(y.dtype)
    for index in range(start * item_size):
        _append(result, y.at(index))
    for index in range((start + width) * item_size, y.length()):
        _append(result, y.at(index))
    result.set_shape(dims)
    return result^


def _segments_monad[Op: Verb](y: Noun, suffix: Bool) raises -> Noun:
    var items = 1 if y.is_scalar() else y.axis_length(0)
    var frame = List[Int]([items])
    var cells = List[Noun]()
    if items == 0:
        return _assemble(frame, cells, Op.monad(y))
    for index in range(items):
        var start = index if suffix else 0
        var width = items - index if suffix else index + 1
        cells.append(Op.monad(_segment(y, items, start, width, False)))
    return _assemble(frame, cells, _zero(y.dtype))


def _window_count(window: Noun, items: Int) raises -> Int128:
    if not window.is_float64():
        if window.is_int():
            return Int128(window.as_int())
        return Int128(window.as_bool())
    var value = window.as_float()
    if isnan(value):
        raise Error("window width must be an integer")
    if not isfinite(value):
        return Int128(items) + 1 if value > 0.0 else -Int128(items) - 1
    var nearest = round(value)
    if not tolerant_equal(value, nearest):
        raise Error("window width must be an integer")
    if Float64(Int.MIN) <= nearest < Float64(Int.MAX):
        return Int128(Int(nearest))
    raise Error("window width exceeds Int range")


def _segments_dyad[Op: Verb](x: Noun, y: Noun, outfix: Bool) raises -> Noun:
    var items = 1 if y.is_scalar() else y.axis_length(0)
    var signed_width = _window_count(x, items)
    var chunks = signed_width < 0
    var width = abs(signed_width)
    var count = 0
    if chunks:
        count = Int((Int128(items) + width - 1) // width)
    elif width <= Int128(items):
        count = _checked_add(items - Int(width), 1, "window count")
    var frame = List[Int]([count])
    var cells = List[Noun]()
    if count == 0:
        var prototype_dims = y.dims()
        if y.is_scalar():
            prototype_dims.append(1)
        prototype_dims[0] = 0
        if not chunks and not outfix and width <= Int128(Int.MAX):
            prototype_dims[0] = Int(width)
        return _assemble(frame, cells, Op.monad(_fill(y.dtype, prototype_dims)))
    for index in range(count):
        var start = Int(Int128(index) * width) if chunks else index
        var length = Int(min(width, Int128(items - start)))
        cells.append(Op.monad(_segment(y, items, start, length, outfix)))
    return _assemble(frame, cells, _zero(y.dtype))


struct Prefix[Op: Verb](Verb):
    """Apply a monad to prefixes or to windows of the requested width."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return _segments_monad[Self.Op](y, False)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        if x.is_scalar():
            return _segments_dyad[Self.Op](x, y, False)
        return rank_dyad[Self](x, y, ATOM_RANK, y.rank)

    @staticmethod
    def describe() -> String:
        return Self.Op.describe() + "\\"

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct Suffix[Op: Verb](Verb):
    """Apply a monad to suffixes or to complements of windows."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return _segments_monad[Self.Op](y, True)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        if x.is_scalar():
            return _segments_dyad[Self.Op](x, y, True)
        return rank_dyad[Self](x, y, ATOM_RANK, y.rank)

    @staticmethod
    def describe() -> String:
        return Self.Op.describe() + "\\."

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return ATOM_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


struct Table[Op: Verb](Verb):
    """Apply a dyad between each left cell and the entire right noun."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        raise Error("Table is available as the dyad of Insert")

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return rank_dyad[Self.Op](x, y, Self.Op.left_cell_rank(x.rank), y.rank)

    @staticmethod
    def describe() -> String:
        return Self.Op.describe() + "/"

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


def _dot_cell[Reduction: Verb, Cell: Verb](
    x: Noun, y: Noun, left_start: Int, width: Int, right_shape: List[Int]
) raises -> Noun:
    if (
        Cell.has_float64_dyad() and (x.is_vector() or x.rank == 2) and y.is_vector()
        and x.is_float64() and y.is_float64() and width > 0
    ):
        var values = List[Float64](capacity=width)
        for index in range(width):
            values.append(Cell.float64_dyad(x.float_values[left_start + index], y.float_values[index]))
        return Reduction.monad(Noun.from_owned_float64(values^))
    var count = shape_size(right_shape)
    var products = List[Noun]()
    if count == 0:
        var prototype = Cell.dyad(_zero(x.dtype), _zero(y.dtype))
        return Reduction.monad(_assemble(right_shape, products, prototype))
    var repeat = count // width
    for index in range(count):
        var left = x.at(0 if x.is_scalar() else left_start + index // repeat)
        var right = y.at(0 if y.is_scalar() else index)
        products.append(Cell.dyad(left, right))
    return Reduction.monad(_assemble(right_shape, products, _zero(y.dtype)))


struct Dot[Reduction: Verb, Cell: Verb](Verb):
    """Reduce rank-zero pairwise results along the contracted axis."""

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        raise Error("Dot monad is unsupported")

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        if (
            Self.Cell.left_cell_rank(x.rank) != ATOM_RANK
            or Self.Cell.right_cell_rank(y.rank) != ATOM_RANK
        ):
            raise Error("Dot requires a rank-zero cell verb")
        if x.is_scalar() and y.is_scalar():
            return Self.Reduction.monad(Self.Cell.dyad(x, y))
        var width = y.axis_length(0) if x.is_scalar() else x.axis_length(x.rank - 1)
        if not y.is_scalar() and width != y.axis_length(0):
            raise Error("Dot contracted axes must have the same length")
        var left_frame = _axes(x.dims(), 0, max(0, x.rank - 1))
        var right_shape = List[Int]([width]) if y.is_scalar() else y.dims()
        var count = shape_size(left_frame)
        if len(left_frame) == 0:
            return _dot_cell[Self.Reduction, Self.Cell](x, y, 0, width, right_shape)
        var cells = List[Noun]()
        if count == 0:
            var left_fill = _fill(x.dtype, List[Int]([width]))
            var prototype = _dot_cell[Self.Reduction, Self.Cell](left_fill, y, 0, width, right_shape)
            return _assemble(left_frame, cells, prototype)
        for index in range(count):
            cells.append(_dot_cell[Self.Reduction, Self.Cell](x, y, index * width, width, right_shape))
        return _assemble(left_frame, cells, _zero(y.dtype))

    @staticmethod
    def describe() -> String:
        return Self.Reduction.describe() + " . " + Self.Cell.describe()

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK
