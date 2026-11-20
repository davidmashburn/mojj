"""Value-owned array construction and item selection over numeric nouns."""

from std.collections import List
from std.math import clamp, isfinite, isinf, round
from std.sys import size_of

from ._atomic import _empty
from ._verb_base import Verb, ATOM_RANK, WHOLE_NOUN_RANK, _checked_add, _numeric_int
from .array_modifiers import rank_dyad, rank_monad
from .nouns import Noun, NounDType, VECTOR_RANK, shape_size
from .predicates import tolerant_equal


def _tail(dims: List[Int]) -> List[Int]:
    var result = List[Int]()
    for axis in range(1, len(dims)):
        result.append(dims[axis])
    return result^


def _integer_control(atom: Noun, name: String) raises -> Int:
    if not atom.is_float64():
        return _numeric_int(atom)
    var value = atom.as_float()
    var nearest = round(value)
    if isfinite(value) and tolerant_equal(value, nearest) and Float64(Int.MIN) <= nearest < Float64(Int.MAX):
        return Int(nearest)
    raise Error(name + " requires an integer within Int64 range")


def _control(noun: Noun, name: String) raises -> List[Int]:
    if noun.rank > VECTOR_RANK:
        raise Error(name + " requires an integer atom or list")
    var result = List[Int]()
    for i in range(noun.length()):
        result.append(_integer_control(noun.at(i), name))
    return result^


def _magnitude(value: Int) raises -> Int:
    if value == Int.MIN:
        raise Error("array extent exceeds Int64 range")
    return abs(value)


def _promote(x: NounDType, y: NounDType) -> NounDType:
    if x == NounDType.FLOAT64 or y == NounDType.FLOAT64:
        return NounDType.FLOAT64
    if x == NounDType.INT or y == NounDType.INT:
        return NounDType.INT
    return NounDType.BOOL


def _output_size(dims: List[Int], dtype: NounDType) raises -> Int:
    var size = shape_size(dims)
    var atom_bytes = size_of[Bool]()
    if dtype == NounDType.INT:
        atom_bytes = size_of[Int]()
    elif dtype == NounDType.FLOAT64:
        atom_bytes = size_of[Float64]()
    if size > Int.MAX // atom_bytes:
        raise Error("array storage byte count overflows Int")
    return size


def _append_atom(mut output: Noun, atom: Noun) raises:
    if output.is_float64():
        output.float_values.append(atom.as_float())
    elif output.is_int():
        output.int_values.append(_numeric_int(atom))
    else:
        output.bool_values.append(atom.as_bool())


def _fill_atom(mut output: Noun):
    if output.is_float64():
        output.float_values.append(0.0)
    elif output.is_int():
        output.int_values.append(0)
    else:
        output.bool_values.append(False)


def _reshape(dims: List[Int], y: Noun) raises -> Noun:
    var output_dims = dims.copy()
    output_dims.extend(_tail(y.dims()))
    var size = _output_size(output_dims, y.dtype)
    var result = _empty(y.dtype)
    if y.length() == 0 and size > 0:
        raise Error("cannot reshape empty data to a nonempty shape")
    for flat in range(size):
        _append_atom(result, y.at(flat % y.length()))
    return result.with_shape(output_dims)


def _iota(y: Noun) raises -> Noun:
    var extents = _control(y, "iota")
    var dims = List[Int]()
    for extent in extents:
        dims.append(_magnitude(extent))
    var size = _output_size(dims, NounDType.INT)
    var data = List[Int](length=size, fill=0)
    for flat in range(size):
        var remaining = flat
        var stride = 1
        var reversed = 0
        for axis in range(len(dims) - 1, -1, -1):
            var coord = remaining % dims[axis]
            remaining //= dims[axis]
            if extents[axis] < 0:
                coord = dims[axis] - 1 - coord
            reversed += stride * coord
            stride *= dims[axis]
        data[flat] = reversed
    return Noun(data).with_shape(dims)


def _sliced(
    y: Noun, input_dims: List[Int], output_dims: List[Int], offsets: List[Int],
) raises -> Noun:
    var size = _output_size(output_dims, y.dtype)
    var result = _empty(y.dtype)
    if y.length() == 0:
        for _ in range(size):
            _fill_atom(result)
        return result.with_shape(output_dims)
    for flat in range(size):
        var remaining = flat
        var index = 0
        var stride = 1
        var inside = True
        for axis in range(len(output_dims) - 1, -1, -1):
            var coord = remaining % output_dims[axis] + offsets[axis]
            remaining //= output_dims[axis]
            if coord < 0 or coord >= input_dims[axis]:
                inside = False
                break
            index += stride * coord
            stride *= input_dims[axis]
        if inside:
            _append_atom(result, y.at(index))
        else:
            _fill_atom(result)
    return result.with_shape(output_dims)


def _take_drop(counts: List[Int], y: Noun, take: Bool) raises -> Noun:
    var input_dims = y.dims()
    if y.is_scalar():
        input_dims = List[Int](length=len(counts), fill=1)
    if len(counts) > len(input_dims):
        raise Error("take/drop count has too many axes")
    var output_dims = input_dims.copy()
    var offsets = List[Int](length=len(input_dims), fill=0)
    for axis in range(len(counts)):
        if take:
            var extent = _magnitude(counts[axis])
            output_dims[axis] = extent
            if counts[axis] < 0:
                offsets[axis] = input_dims[axis] - extent
        else:
            var limit = input_dims[axis]
            var removed = abs(clamp(counts[axis], -limit, limit))
            output_dims[axis] -= removed
            if counts[axis] > 0:
                offsets[axis] = removed
    return _sliced(y, input_dims, output_dims, offsets)


def _head_tail(y: Noun, tail: Bool) raises -> Noun:
    if y.is_scalar():
        return y.copy()
    var count = 1
    if tail:
        count = -1
    return _take_drop([count], y, True).with_shape(_tail(y.dims()))


def _take_drop_dyad(x: Noun, y: Noun, take: Bool) raises -> Noun:
    var count = x.length()
    if not y.is_scalar() and count > y.rank:
        raise Error("take/drop count has too many axes")
    var extents = List[Int]()
    for axis in range(count):
        var atom = x.at(axis)
        if atom.is_float64() and isinf(atom.as_float()):
            var width = 1 if y.is_scalar() else y.axis_length(axis)
            extents.append(width if atom.as_float() > 0 else -width)
        else:
            extents.append(_integer_control(atom, "take/drop"))
    return _take_drop(extents, y, take)


def _gather(x: Noun, y: Noun) raises -> Noun:
    var y_dims = y.dims()
    var item_dims = _tail(y_dims)
    var items = 1
    if not y.is_scalar():
        items = y_dims[0]
    var dims = x.dims()
    dims.extend(item_dims.copy())
    _ = _output_size(dims, y.dtype)
    var result = _empty(y.dtype)
    if x.length() == 0:
        return result.with_shape(dims)
    var item_size = shape_size(item_dims)
    for flat in range(x.length()):
        var index = _integer_control(x.at(flat), "gather")
        if index < 0:
            index += items
        if index < 0 or index >= items:
            raise Error("gather index out of range")
        for offset in range(item_size):
            _append_atom(result, y.at(index * item_size + offset))
    return result.with_shape(dims)


def _rotate(counts: List[Int], y: Noun, reverse: Bool) raises -> Noun:
    if y.is_scalar():
        if len(counts) > 1:
            return y.with_shape(List[Int](length=len(counts), fill=1))
        return y.copy()
    var dims = y.dims()
    if len(counts) > len(dims):
        raise Error("rotate count has too many axes")
    var shifts = List[Int](length=len(dims), fill=0)
    if y.length() == 0:
        return y.copy()
    for axis in range(len(counts)):
        var shift = counts[axis] % dims[axis]
        if shift < 0:
            shift += dims[axis]
        shifts[axis] = shift
    var result = _empty(y.dtype)
    for flat in range(y.length()):
        var remaining = flat
        var index = 0
        var stride = 1
        for axis in range(len(dims) - 1, -1, -1):
            var coord = remaining % dims[axis]
            remaining //= dims[axis]
            if reverse and axis == 0:
                coord = dims[axis] - 1 - coord
            else:
                var wrap_at = dims[axis] - shifts[axis]
                if coord >= wrap_at:
                    coord -= wrap_at
                else:
                    coord += shifts[axis]
            index += stride * coord
            stride *= dims[axis]
        _append_atom(result, y.at(index))
    return result.with_shape(dims)


def _transpose(y: Noun, order: List[Int]) raises -> Noun:
    var source = y.dims()
    var dims = List[Int]()
    var strides = List[Int](length=len(source), fill=0)
    var stride = 1
    for axis in range(len(source) - 1, -1, -1):
        strides[axis] = stride
        if y.length() != 0:
            stride *= source[axis]
    for axis in order:
        dims.append(source[axis])
    var result = _empty(y.dtype)
    for flat in range(y.length()):
        var index = 0
        var remaining = flat
        for axis in range(len(dims) - 1, -1, -1):
            index += remaining % dims[axis] * strides[order[axis]]
            remaining //= dims[axis]
        _append_atom(result, y.at(index))
    return result.with_shape(dims)


def _transpose_axes(x: Noun, y: Noun) raises -> Noun:
    var pending = _control(x, "transpose")
    var moved = List[Bool](length=y.rank, fill=False)
    for i in range(len(pending)):
        var axis = pending[i]
        if axis < 0:
            axis += y.rank
        if axis < 0 or axis >= y.rank or moved[axis]:
            raise Error("transpose axes must be distinct and in range")
        moved[axis] = True
        pending[i] = axis
    var order = List[Int]()
    for axis in range(y.rank):
        if not moved[axis]:
            order.append(axis)
    order.extend(pending^)
    return _transpose(y, order)


def _replicate(x: Noun, y: Noun) raises -> Noun:
    var counts = _control(x, "copy")
    var dims = y.dims()
    if y.is_scalar():
        dims.append(1)
    var items = dims[0]
    if y.is_scalar() and not x.is_scalar():
        items = len(counts)
    elif not x.is_scalar() and len(counts) != items:
        raise Error("copy count and item lengths disagree")
    var total = 0
    for count in counts:
        if count < 0:
            raise Error("copy counts must be nonnegative")
        if not x.is_scalar():
            total = _checked_add(total, count, "copy")
    if x.is_scalar():
        var product = Int128(counts[0]) * Int128(items)
        if product > Int128(Int.MAX):
            raise Error("copy result exceeds Int64 range")
        total = Int(product)
    dims[0] = total
    var size = _output_size(dims, y.dtype)
    var result = _empty(y.dtype)
    if size != 0:
        var item_size = shape_size(_tail(dims))
        for item in range(items):
            var count = counts[0] if x.is_scalar() else counts[item]
            var start = 0 if y.is_scalar() else item * item_size
            for _ in range(count):
                for offset in range(item_size):
                    _append_atom(result, y.at(start + offset))
    return result.with_shape(dims)


def _append_dims(input: List[Int], other: List[Int], rank: Int) -> List[Int]:
    var dims = List[Int](length=rank - len(input), fill=1)
    if len(input) == 0 and len(other) != 0:
        dims = [1]
        dims.extend(_tail(other))
    else:
        dims.extend(input.copy())
    return dims^


def _source_index(
    flat: Int, output: List[Int], input: List[Int],
) -> Int:
    var remaining = flat
    var index = 0
    var stride = 1
    for axis in range(len(output) - 1, -1, -1):
        var coord = remaining % output[axis]
        if coord >= input[axis]:
            return -1
        remaining //= output[axis]
        index += coord * stride
        stride *= input[axis]
    return index


def _append_result_dims(x_dims: List[Int], y_dims: List[Int]) raises -> List[Int]:
    var dims = x_dims.copy()
    dims[0] = _checked_add(x_dims[0], y_dims[0], "append")
    for axis in range(1, len(dims)):
        dims[axis] = max(x_dims[axis], y_dims[axis])
    return dims^


def _append_shaped(x: Noun, y: Noun) raises -> Noun:
    var rank = max(1, max(x.rank, y.rank))
    var x_dims = _append_dims(x.dims(), y.dims(), rank)
    var y_dims = _append_dims(y.dims(), x.dims(), rank)
    var dims = _append_result_dims(x_dims, y_dims)
    var dtype = _promote(x.dtype, y.dtype)
    var size = _output_size(dims, dtype)
    var result = _empty(dtype)
    if size != 0:
        var cell_size = shape_size(_tail(dims))
        var x_boundary = x_dims[0] * cell_size
        for flat in range(size):
            if flat < x_boundary:
                var index = _source_index(flat, dims, x_dims)
                if index < 0:
                    _fill_atom(result)
                else:
                    _append_atom(result, x.at(0 if x.is_scalar() else index))
            else:
                var index = _source_index(flat - x_boundary, dims, y_dims)
                if index < 0:
                    _fill_atom(result)
                else:
                    _append_atom(result, y.at(0 if y.is_scalar() else index))
    return result.with_shape(dims)


def _itemize(y: Noun) raises -> Noun:
    var dims: List[Int] = [1]
    dims.extend(y.dims())
    return y.with_shape(dims)


def _laminate(x: Noun, y: Noun) raises -> Noun:
    var left = x.copy()
    var right = y.copy()
    if x.is_scalar() and not y.is_scalar():
        left = _reshape(y.dims(), x)
    elif y.is_scalar() and not x.is_scalar():
        right = _reshape(x.dims(), y)
    return _append_shaped(_itemize(left), _itemize(right))


def _stitch(x: Noun, y: Noun) raises -> Noun:
    # Complementary item-wise append for equal leading frames, or atom extension.
    var x_dims = x.dims()
    var y_dims = y.dims()
    var items = 1
    if not x.is_scalar():
        items = x_dims[0]
    if not y.is_scalar():
        if not x.is_scalar() and y_dims[0] != items:
            raise Error("stitch requires agreeing leading item counts")
        items = y_dims[0]
    var left_dims = _tail(x_dims)
    var right_dims = _tail(y_dims)
    var cell_rank = max(1, max(len(left_dims), len(right_dims)))
    var left_layout = _append_dims(left_dims, right_dims, cell_rank)
    var right_layout = _append_dims(right_dims, left_dims, cell_rank)
    var dims = List[Int]()
    if not (x.is_scalar() and y.is_scalar()):
        dims.append(items)
    dims.extend(_append_result_dims(left_layout, right_layout))
    var dtype = _promote(x.dtype, y.dtype)
    var size = _output_size(dims, dtype)
    var result = _empty(dtype)
    if size == 0:
        return result.with_shape(dims)
    var left_size = shape_size(left_dims)
    var right_size = shape_size(right_dims)
    for item in range(items):
        var a = _empty(x.dtype)
        for offset in range(left_size):
            _append_atom(a, x.at(0 if x.is_scalar() else item * left_size + offset))
        var b = _empty(y.dtype)
        for offset in range(right_size):
            _append_atom(b, y.at(0 if y.is_scalar() else item * right_size + offset))
        var row = _append_shaped(a.with_shape(left_dims), b.with_shape(right_dims))
        for flat in range(row.length()):
            _append_atom(result, row.at(flat))
    return result.with_shape(dims)


struct _ArrayKind:
    comptime SHAPE = 0
    comptime IOTA = 1
    comptime RAVEL = 2
    comptime STITCH = 3
    comptime LAMINATE = 4
    comptime GATHER = 5
    comptime HEAD = 6
    comptime TAIL = 7
    comptime DROP = 8
    comptime CURTAIL = 9
    comptime ROTATE = 10
    comptime TRANSPOSE = 11
    comptime COPY = 12


struct _Array[kind: Int](Verb):
    @staticmethod
    def monad(y: Noun) raises -> Noun:
        comptime if Self.kind == _ArrayKind.SHAPE:
            return Noun(y.dims())
        elif Self.kind == _ArrayKind.IOTA:
            if y.rank > VECTOR_RANK:
                return rank_monad[Self](y, VECTOR_RANK)
            return _iota(y)
        elif Self.kind == _ArrayKind.RAVEL:
            return y.with_shape([y.length()])
        elif Self.kind == _ArrayKind.STITCH:
            if y.is_scalar():
                return y.with_shape([1, 1])
            var dims = y.dims()
            return y.with_shape([dims[0], shape_size(_tail(dims))])
        elif Self.kind == _ArrayKind.LAMINATE:
            return _itemize(y)
        elif Self.kind == _ArrayKind.HEAD:
            return _head_tail(y, False)
        elif Self.kind == _ArrayKind.TAIL:
            return _head_tail(y, True)
        elif Self.kind == _ArrayKind.DROP:
            return _take_drop([1], y, False)
        elif Self.kind == _ArrayKind.CURTAIL:
            return _take_drop([-1], y, False)
        elif Self.kind == _ArrayKind.ROTATE:
            return _rotate(List[Int](), y, True)
        elif Self.kind == _ArrayKind.TRANSPOSE:
            var order = List[Int]()
            for axis in range(y.rank - 1, -1, -1):
                order.append(axis)
            return _transpose(y, order)
        elif Self.kind == _ArrayKind.COPY:
            return Noun(1 if y.is_scalar() else y.dims()[0])
        else:
            raise Error("unsupported array monad")

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        if Self.left_rank() == VECTOR_RANK and x.rank > VECTOR_RANK:
            return rank_dyad[Self](x, y, VECTOR_RANK, y.rank)
        comptime if Self.kind == _ArrayKind.SHAPE:
            return _reshape(_control(x, "reshape"), y)
        elif Self.kind == _ArrayKind.RAVEL:
            return _append_shaped(x, y)
        elif Self.kind == _ArrayKind.STITCH:
            return _stitch(x, y)
        elif Self.kind == _ArrayKind.LAMINATE:
            return _laminate(x, y)
        elif Self.kind == _ArrayKind.GATHER:
            return _gather(x, y)
        elif Self.kind == _ArrayKind.HEAD:
            return _take_drop_dyad(x, y, True)
        elif Self.kind == _ArrayKind.DROP:
            return _take_drop_dyad(x, y, False)
        elif Self.kind == _ArrayKind.ROTATE:
            return _rotate(_control(x, "rotate"), y, False)
        elif Self.kind == _ArrayKind.TRANSPOSE:
            return _transpose_axes(x, y)
        elif Self.kind == _ArrayKind.COPY:
            return _replicate(x, y)
        else:
            raise Error("unsupported array dyad")

    @staticmethod
    def describe() -> String:
        comptime if Self.kind == _ArrayKind.SHAPE:
            return "shape-reshape"
        elif Self.kind == _ArrayKind.IOTA:
            return "iota"
        elif Self.kind == _ArrayKind.RAVEL:
            return "ravel-append"
        elif Self.kind == _ArrayKind.STITCH:
            return "stitch"
        elif Self.kind == _ArrayKind.LAMINATE:
            return "laminate"
        elif Self.kind == _ArrayKind.GATHER:
            return "gather"
        elif Self.kind == _ArrayKind.HEAD:
            return "head-take"
        elif Self.kind == _ArrayKind.TAIL:
            return "tail"
        elif Self.kind == _ArrayKind.DROP:
            return "drop"
        elif Self.kind == _ArrayKind.CURTAIL:
            return "curtail"
        elif Self.kind == _ArrayKind.ROTATE:
            return "reverse-rotate"
        elif Self.kind == _ArrayKind.TRANSPOSE:
            return "transpose"
        else:
            return "copy"

    @staticmethod
    def monad_rank() -> Int:
        comptime if Self.kind == _ArrayKind.IOTA:
            return VECTOR_RANK
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        comptime if (
            Self.kind == _ArrayKind.SHAPE or Self.kind == _ArrayKind.HEAD
            or Self.kind == _ArrayKind.DROP or Self.kind == _ArrayKind.ROTATE
            or Self.kind == _ArrayKind.TRANSPOSE or Self.kind == _ArrayKind.COPY
        ):
            return VECTOR_RANK
        elif Self.kind == _ArrayKind.GATHER:
            return ATOM_RANK
        return WHOLE_NOUN_RANK

    @staticmethod
    def right_rank() -> Int:
        return WHOLE_NOUN_RANK


comptime ShapeReshape = _Array[_ArrayKind.SHAPE]
comptime Iota = _Array[_ArrayKind.IOTA]
comptime RavelAppend = _Array[_ArrayKind.RAVEL]
comptime Stitch = _Array[_ArrayKind.STITCH]
comptime Laminate = _Array[_ArrayKind.LAMINATE]
comptime Gather = _Array[_ArrayKind.GATHER]
comptime Head = _Array[_ArrayKind.HEAD]
comptime Take = Head
comptime Tail = _Array[_ArrayKind.TAIL]
comptime Drop = _Array[_ArrayKind.DROP]
comptime Curtail = _Array[_ArrayKind.CURTAIL]
comptime ReverseRotate = _Array[_ArrayKind.ROTATE]
comptime Transpose = _Array[_ArrayKind.TRANSPOSE]
comptime Copy = _Array[_ArrayKind.COPY]
