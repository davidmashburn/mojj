from std.collections import List
from std.testing import assert_equal, assert_raises, assert_true

from mojj.array_modifiers import Dot, Prefix, Rank, Suffix, Table
from mojj.nouns import Noun
from mojj.verbs import Atop, Insert, Minus, Plus, Right, Times


def _assert_int_array(noun: Noun, dims: List[Int], values: List[Int]) raises:
    assert_true(noun.is_int())
    assert_true(noun.dims() == dims)
    assert_equal(noun.length(), len(values))
    for index in range(len(values)):
        assert_equal(noun.at(index).as_int(), values[index])


def _test_rank() raises:
    var matrix = Noun(List[Int]([1, 2, 3, 4, 5, 6])).with_shape([2, 3])
    _assert_int_array(Rank[Insert[Plus], 1].monad(matrix), [2], [6, 15])
    _assert_int_array(Rank[Insert[Plus], -1].monad(matrix), [2], [6, 15])
    _assert_int_array(Atop[Insert[Plus], Rank[Right, -1]].monad(matrix), [3], [5, 7, 9])
    _assert_int_array(Rank[Insert[Plus], Int.MAX].monad(matrix), [3], [5, 7, 9])
    assert_equal(Rank[Insert[Plus], -1].monad_cell_rank(matrix.rank), 2)
    assert_equal(Rank[Insert[Plus], Int.MAX].describe(), "insert(+) \" _")
    var added = Rank[Plus, 0, 0, 1].dyad(Noun(List[Int]([10, 20])), matrix)
    _assert_int_array(added, [2, 3], [11, 12, 13, 24, 25, 26])
    var empty = Noun(List[Int]()).with_shape([0, 3])
    _assert_int_array(Rank[Insert[Plus], 1].monad(empty), [0], [])
    with assert_raises(contains="rank frame agreement failed"):
        _ = Rank[Plus, 0, 0, 1].dyad(Noun(List[Int]([1, 2, 3])), matrix)


def _test_segments() raises:
    var values = Noun(List[Int]([1, 2, 3, 4, 5]))
    _assert_int_array(Prefix[Insert[Plus]].monad(values), [5], [1, 3, 6, 10, 15])
    _assert_int_array(Suffix[Insert[Plus]].monad(values), [5], [15, 14, 12, 9, 5])
    _assert_int_array(Prefix[Insert[Minus]].dyad(Noun(2), values), [4], [-1, -1, -1, -1])
    _assert_int_array(Prefix[Insert[Plus]].dyad(Noun(-2), values), [3], [3, 7, 5])
    _assert_int_array(Prefix[Insert[Plus]].dyad(Noun(0), values), [6], [0, 0, 0, 0, 0, 0])
    _assert_int_array(Prefix[Right].dyad(Noun(6), values), [0, 6], [])
    _assert_int_array(Suffix[Right].dyad(Noun(6), values), [0, 0], [])
    _assert_int_array(
        Suffix[Right].dyad(Noun(-2), values),
        [3, 4],
        [3, 4, 5, 0, 1, 2, 5, 0, 1, 2, 3, 4],
    )
    _assert_int_array(
        Prefix[Insert[Plus]].dyad(Noun(List[Int]([2, 3])), values),
        [2, 4],
        [3, 5, 7, 9, 6, 9, 12, 0],
    )
    _assert_int_array(Prefix[Right].monad(Noun(7)), [1, 1], [7])
    _assert_int_array(Prefix[Right].monad(Noun(List[Int]())), [0, 0], [])
    with assert_raises(contains="window width must be an integer"):
        _ = Prefix[Right].dyad(Noun(2.5), values)


def _test_table_and_dot() raises:
    comptime Product = Dot[Insert[Plus], Times]
    var xs = Noun(List[Int]([1, 2]))
    var ys = Noun(List[Int]([3, 4, 5]))
    _assert_int_array(Table[Times].dyad(xs, ys), [2, 3], [3, 4, 5, 6, 8, 10])
    _assert_int_array(Table[Times].dyad(Noun(List[Int]()), ys), [0, 3], [])
    _assert_int_array(Product.dyad(xs, Noun(List[Int]([10, 20]))), [], [50])
    _assert_int_array(Product.dyad(Noun(2), ys), [], [24])
    _assert_int_array(Product.dyad(ys, Noun(2)), [], [24])
    var a = Noun(List[Int]([1, 2, 3, 4])).with_shape([2, 2])
    var b = Noun(List[Int]([5, 6, 7, 8, 9, 10])).with_shape([2, 3])
    _assert_int_array(
        Table[Rank[Right, 0, -1, Int.MAX]].dyad(a, ys),
        [2, 3],
        [3, 4, 5, 3, 4, 5],
    )
    with assert_raises(contains="rank frame agreement failed"):
        _ = Table[Rank[Right, -1]].dyad(a, ys)
    _assert_int_array(Product.dyad(a, b), [2, 3], [21, 24, 27, 47, 54, 61])
    _assert_int_array(Product.dyad(xs, b), [3], [21, 24, 27])
    _assert_int_array(Product.dyad(a, xs), [2], [5, 11])
    _assert_int_array(Product.dyad(Noun(List[Int]()).with_shape([0, 2]), b), [0, 3], [])
    _assert_int_array(
        Product.dyad(
            Noun(List[Int]()).with_shape([2, 0]),
            Noun(List[Int]()).with_shape([0, 3]),
        ),
        [2, 3],
        [0, 0, 0, 0, 0, 0],
    )
    with assert_raises(contains="contracted axes"):
        _ = Product.dyad(xs, ys)


def main() raises:
    _test_rank()
    _test_segments()
    _test_table_and_dot()
    print("Array modifier tests passed")
