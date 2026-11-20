"""Borrowed one-dimensional Float64 input views."""

from std.collections import List
from .core import Identity, ScalarOp


struct StridedView[origin: Origin[mut=False]](Sized):
    """Read live Float64 atoms at start + index * stride.

    Positive, negative and zero strides are valid. An empty view may start
    one past the end. Owner edits and reallocations remain visible; reading
    a position removed from the owner raises.
    """

    # Borrow the list header so owner reallocations cannot invalidate reads.
    var _data: Pointer[List[Float64], Self.origin]
    var _start: Int
    var _count: Int
    var _stride: Int

    def __init__(
        out self, ref[Self.origin] data: List[Float64], start: Int, count: Int,
        stride: Int = 1,
    ) raises:
        if count < 0 or start < 0 or start > len(data):
            raise Error("invalid view bounds")
        if count > 0:
            if start == len(data):
                raise Error("invalid view bounds")
            if count > 1:
                var steps = count - 1
                # Compare by division before any multiplication can overflow.
                if (
                    stride > (len(data) - 1 - start) // steps
                    or stride < -(start // steps)
                ):
                    raise Error("invalid view bounds")
        self._data = Pointer(to=data)
        self._start = start
        self._count = count
        self._stride = stride

    def __len__(self) -> Int:
        return self._count

    def __getitem__(self, index: Int) raises -> Float64:
        if index < 0 or index >= len(self):
            raise Error("view index out of range")
        var position = self._start + index * self._stride
        if position >= len(self._data[]):
            raise Error("view source has shrunk")
        return self._data[][position]

    def materialize[Op: ScalarOp = Identity](self) raises -> List[Float64]:
        """Apply a scalar expression to each selected atom in logical order."""
        var result = List[Float64](capacity=len(self))
        for index in range(len(self)):
            result.append(Op.apply(self[index]))
        return result^
