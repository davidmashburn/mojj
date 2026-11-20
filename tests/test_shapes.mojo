"""Shape, flat access, ownership, and prefix agreement on numeric nouns."""

from std.collections import List
from std.testing import assert_equal, assert_raises, assert_true

from mojj.nouns import (
    Noun,
    agreed_atom,
    agreement_dims,
    agreement_length,
    shape_size,
)
from mojj.predicates import MatchHalve


def test_dimensions_and_flat_access() raises:
    var flat = Noun(List[Int]([1, 2, 3, 4, 5, 6]))
    var matrix = flat.with_shape([2, 3])
    assert_equal(flat.dims(), List[Int]([6]))
    assert_equal(matrix.dims(), List[Int]([2, 3]))
    assert_equal(matrix.rank, 2)
    assert_equal(matrix.length(), 6)
    assert_equal(matrix.at(4).as_int(), 5)
    assert_equal(matrix.axis_length(1), 3)
    assert_equal(matrix.as_ints(), flat.as_ints())
    assert_equal(
        matrix.as_floats(), List[Float64]([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
    )
    assert_equal(matrix.describe(), "2 3$1 2 3 4 5 6")
    assert_true(not matrix.same_shape(flat))
    assert_true(not MatchHalve.dyad(matrix, flat.with_shape([3, 2])).as_bool())
    assert_true(MatchHalve.dyad(matrix, matrix.copy()).as_bool())
    with assert_raises(contains="noun index out of range"):
        _ = matrix.at(6)
    with assert_raises(contains="noun axis out of range"):
        _ = matrix.axis_length(-1)
    with assert_raises(contains="noun axis out of range"):
        _ = matrix.axis_length(2)


def test_shape_validation_and_ownership() raises:
    var dims: List[Int] = [2, 1, 2]
    var original = Noun(List[Bool]([True, False, False, True]))
    var cube = original.with_shape(dims)
    dims[0] = 4
    assert_equal(cube.dims(), List[Int]([2, 1, 2]))
    var dimensions_from_cube = cube.dims()
    dimensions_from_cube[0] = 1
    assert_equal(cube.dims(), List[Int]([2, 1, 2]))
    var copy = cube.copy()
    copy.set_shape([4])
    copy.bool_values[0] = False
    assert_equal(copy.dims(), List[Int]([4]))
    assert_equal(cube.dims(), List[Int]([2, 1, 2]))
    assert_equal(cube.as_bools(), List[Bool]([True, False, False, True]))
    assert_true(original.at(0).as_bool())
    with assert_raises(contains="shape does not match noun atom count"):
        copy.set_shape([3, 2])
    assert_equal(copy.dims(), List[Int]([4]))
    with assert_raises(contains="shape axes must be nonnegative"):
        _ = shape_size([0, -1])
    with assert_raises(contains="shape atom count overflows Int"):
        _ = shape_size([Int.MAX, 2])


def test_empty_and_singleton_shapes() raises:
    var vector = Noun(2.5).with_shape([1])
    assert_true(vector.is_vector())
    assert_equal(vector.at(0).as_float(), 2.5)
    var matrix = vector.with_shape([1, 1])
    var atom = matrix.with_shape([])
    assert_true(atom.is_scalar())
    assert_equal(atom.as_float(), 2.5)
    assert_equal(atom.dims(), List[Int]())
    assert_true(not atom.same_shape(vector))
    assert_equal(Noun(7).with_shape([1]).with_shape([]).as_int(), 7)
    assert_true(Noun(True).with_shape([1]).with_shape([]).as_bool())
    with assert_raises(contains="shape does not match noun atom count"):
        _ = Noun(List[Int]()).with_shape([])
    var empty = Noun(List[Float64]()).with_shape([3, 0, 4])
    assert_equal(empty.dims(), List[Int]([3, 0, 4]))
    assert_equal(empty.length(), 0)
    assert_equal(empty.as_floats(), List[Float64]())
    assert_equal(empty.describe(), "3 0 4$0")
    assert_equal(shape_size([Int.MAX, 2, 0]), 0)
    assert_true(
        not empty.same_shape(Noun(List[Float64]()).with_shape([0, 3, 4]))
    )


def test_prefix_agreement() raises:
    var rows = Noun(List[Int]([10, 20]))
    var matrix = Noun(List[Int]([1, 2, 3, 4, 5, 6])).with_shape([2, 3])
    var column = Noun(List[Int]([7, 8, 9]))
    assert_equal(agreement_dims(rows, matrix), List[Int]([2, 3]))
    assert_equal(agreement_dims(matrix, rows), List[Int]([2, 3]))
    assert_equal(agreement_length(matrix, rows), 6)
    assert_equal(agreement_length(Noun(True), matrix), 6)
    assert_equal(agreed_atom(rows, matrix, 2).as_int(), 10)
    assert_equal(agreed_atom(rows, matrix, 3).as_int(), 20)
    assert_equal(agreed_atom(matrix, rows, 3).as_int(), 4)
    assert_true(agreed_atom(Noun(True), matrix, 3).as_bool())
    with assert_raises(contains="shape agreement failed"):
        _ = agreement_dims(matrix, column)
    with assert_raises(contains="shape agreement failed"):
        _ = agreement_length(matrix, matrix.with_shape([3, 2]))
    var empty = Noun(List[Int]()).with_shape([2, 0])
    assert_equal(agreement_dims(rows, empty), List[Int]([2, 0]))
    assert_equal(agreement_length(rows, empty), 0)
    with assert_raises(contains="noun index out of range"):
        _ = agreed_atom(rows, empty, 0)


def main() raises:
    test_dimensions_and_flat_access()
    test_shape_validation_and_ownership()
    test_empty_and_singleton_shapes()
    test_prefix_agreement()
