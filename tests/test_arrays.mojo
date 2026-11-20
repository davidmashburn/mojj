"""Numeric array vocabulary and shape-preserving operation tests."""

from std.collections import List
from std.testing import assert_equal, assert_raises

from mojj import Expr, Noun
from mojj.arrays import (
    ShapeReshape, Iota, RavelAppend, Stitch, Laminate, Gather, Head, Tail,
    Drop, Curtail, ReverseRotate, Transpose, Copy,
)


def ints(values: List[Int]) -> Noun:
    return Noun(values)


def shape(value: Noun, expected: List[Int]) raises:
    var dims = value.dims()
    assert_equal(len(dims), len(expected))
    assert_equal(value.rank, len(expected))
    for axis in range(len(dims)):
        assert_equal(dims[axis], expected[axis])


def array(value: Noun, dims: List[Int], atoms: List[Int]) raises:
    shape(value, dims)
    assert_equal(value.length(), len(atoms))
    for i in range(len(atoms)):
        assert_equal(value.at(i).as_int(), atoms[i])


def test_construction() raises:
    var matrix = Iota.monad(ints([2, 3]))
    array(matrix, [2, 3], [0, 1, 2, 3, 4, 5])
    array(ShapeReshape.monad(matrix), [2], [2, 3])
    array(Iota.monad(ints([-2, 3])), [2, 3], [3, 4, 5, 0, 1, 2])
    array(Iota.monad(ints([])), [], [0])
    array(Iota.monad(Noun(2.00000000000001)), [2], [0, 1])
    array(Iota.monad(ints([2, 2, 2, 2]).with_shape([2, 2])), [2, 2, 2], [0, 1, 2, 3, 0, 1, 2, 3])
    array(ShapeReshape.dyad(Noun(3), matrix), [3, 3], [0, 1, 2, 3, 4, 5, 0, 1, 2])
    array(ShapeReshape.dyad(ints([2, 2]), matrix), [2, 2, 3], [0, 1, 2, 3, 4, 5, 0, 1, 2, 3, 4, 5])
    array(ShapeReshape.dyad(ints([]), matrix), [3], [0, 1, 2])
    array(ShapeReshape.dyad(ints([2, 3]).with_shape([2, 1]), ints([4, 5, 6])), [2, 3], [4, 5, 0, 4, 5, 6])
    array(ShapeReshape.dyad(Noun(3), Iota.monad(ints([0, 0]))), [3, 0], [])
    array(RavelAppend.monad(matrix), [6], [0, 1, 2, 3, 4, 5])
    array(RavelAppend.dyad(Noun(9), matrix), [3, 3], [9, 9, 9, 0, 1, 2, 3, 4, 5])
    array(Stitch.monad(ints([1, 2, 3])), [3, 1], [1, 2, 3])
    array(Stitch.dyad(ints([1, 2]), ints([3, 4])), [2, 2], [1, 3, 2, 4])
    array(Laminate.monad(matrix), [1, 2, 3], [0, 1, 2, 3, 4, 5])
    array(Laminate.dyad(ints([1, 2]), ints([3, 4, 5])), [2, 3], [1, 2, 0, 3, 4, 5])
    var typed = RavelAppend.dyad(Noun(True), Noun(9007199254740993))
    array(typed, [2], [1, 9007199254740993])
    with assert_raises():
        _ = ShapeReshape.dyad(Noun(3), ints([]))
    with assert_raises():
        _ = ShapeReshape.dyad(ints([2, Int.MAX]), Noun(1))
    with assert_raises():
        _ = Iota.monad(Noun(Int.MIN))
    with assert_raises():
        _ = Iota.monad(Noun(Int.MAX))
    with assert_raises():
        _ = Iota.monad(Noun(2.5))


def test_selection_and_transforms() raises:
    var matrix = Iota.monad(ints([2, 3]))
    array(Head.monad(matrix), [3], [0, 1, 2])
    array(Tail.monad(matrix), [3], [3, 4, 5])
    array(Head.monad(Iota.monad(ints([0, 2]))), [2], [0, 0])
    array(Head.dyad(ints([-3, 4]), matrix), [3, 4], [0, 0, 0, 0, 0, 1, 2, 0, 3, 4, 5, 0])
    array(Expr["_ 2 {. i.2 3"].value(), [2, 2], [0, 1, 3, 4])
    array(Drop.dyad(ints([1, -1]), Iota.monad(ints([3, 4]))), [2, 3], [4, 5, 6, 8, 9, 10])
    array(Drop.dyad(Noun(Int.MIN), matrix), [0, 3], [])
    array(Curtail.monad(matrix), [1, 3], [0, 1, 2])
    array(Gather.dyad(ints([2, 0, 2, -1]), Iota.monad(ints([3, 2]))), [4, 2], [4, 5, 0, 1, 4, 5, 4, 5])
    array(ReverseRotate.monad(matrix), [2, 3], [3, 4, 5, 0, 1, 2])
    array(ReverseRotate.dyad(ints([-1, 1]), matrix), [2, 3], [4, 5, 3, 1, 2, 0])
    array(Transpose.monad(matrix), [3, 2], [0, 3, 1, 4, 2, 5])
    array(Transpose.dyad(Noun(0), matrix), [3, 2], [0, 3, 1, 4, 2, 5])
    array(Transpose.dyad(Noun(-1), matrix), [2, 3], [0, 1, 2, 3, 4, 5])
    var mask: List[Bool] = [False, True]
    array(Copy.dyad(Noun(mask), matrix), [1, 3], [3, 4, 5])
    array(Copy.dyad(ints([2, 0, 1]), Iota.monad(ints([3, 2]))), [3, 2], [0, 1, 0, 1, 4, 5])
    array(Copy.dyad(Noun(0), matrix), [0, 3], [])
    with assert_raises():
        _ = Gather.dyad(Noun(-3), matrix)
    with assert_raises():
        _ = Copy.dyad(Noun(-1), matrix)
    with assert_raises():
        _ = Copy.dyad(ints([1, 0, 1]), matrix)
    with assert_raises():
        _ = Transpose.dyad(ints([0, 0]), matrix)
    with assert_raises():
        _ = Expr["laminate"].map([1.0, 2.0])


def main() raises:
    test_construction()
    test_selection_and_transforms()
    print("PASS test_arrays")
