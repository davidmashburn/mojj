from std.collections import List
from std.memory import bitcast
from std.testing import assert_equal, assert_raises, assert_true
from mojj import Expr, Noun
from mojj.array_modifiers import Dot
from mojj.predicates import Equal
from mojj.verbs import Insert, Plus, Right, Times, Verb


struct _OrderedCell(Verb):
    @staticmethod
    def describe() -> String:
        return "ordered"

    @staticmethod
    def monad_rank() -> Int:
        return 0

    @staticmethod
    def left_rank() -> Int:
        return 0

    @staticmethod
    def right_rank() -> Int:
        return 0

    @staticmethod
    def monad(y: Noun) -> Noun:
        return y.copy()

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Noun(Self.float64_dyad(x.as_float(), y.as_float()))

    @staticmethod
    def has_float64_dyad() -> Bool:
        return True

    @staticmethod
    def float64_dyad(x: Float64, y: Float64) raises -> Float64:
        if y < 0.0:
            raise Error("negative right cell failed")
        if x == 2.0:
            raise Error("second cell failed")
        if x == 3.0:
            raise Error("third cell failed")
        return x * y


def _test_vector_matrix_dot() raises:
    var xs = Noun(List[Float64]([2., 3., 4.]))
    var matrix = Noun(List[Float64]([1., 2., 3., 4., 5., 6.])).with_shape([3, 2])
    var products = Dot[Right, Times].dyad(xs, matrix)
    assert_true(products.is_float64())
    assert_equal(products.dims(), List[Int]([3, 2]))
    assert_equal(products.as_floats(), List[Float64]([2., 4., 9., 12., 20., 24.]))

    var ones = Noun(List[Float64]([1., 1., 1.]))
    var cancellation = Noun(
        List[Float64]([1.0e16, 4., -1.0e16, 5., 1., 6.])
    ).with_shape([3, 2])
    var projected = Expr["+/ . *"].dyad(ones, cancellation)
    assert_true(projected.is_float64())
    assert_equal(projected.dims(), List[Int]([2]))
    assert_equal(projected.as_floats(), List[Float64]([0., 15.]))

    var one = Noun(List[Float64]([1.]))
    var single_row = Noun(List[Float64]([1., -0.])).with_shape([1, 2])
    var signs = Expr["+/ . *"].dyad(one, single_row)
    assert_equal(signs.dims(), List[Int]([2]))
    assert_equal(bitcast[DType.uint64](signs.float_values[1]), UInt64(0x8000000000000000))

    var empty = Noun(List[Float64]())
    var no_rows = empty.with_shape([0, 2])
    var identity = Expr["+/ . *"].dyad(empty, no_rows)
    assert_true(identity.is_float64())
    assert_equal(identity.dims(), List[Int]([2]))
    assert_equal(identity.as_floats(), List[Float64]([0., 0.]))
    var no_columns = empty.with_shape([3, 0])
    var empty_products = Dot[Right, Times].dyad(xs, no_columns)
    assert_true(empty_products.is_float64())
    assert_equal(empty_products.dims(), List[Int]([3, 0]))

    var ordered_left = Noun(List[Float64]([1., 2.]))
    var ordered_right = Noun(List[Float64]([1., -1., 2., 2.])).with_shape([2, 2])
    # Row-major evaluation reaches the negative right cell before the next left cell.
    with assert_raises(contains="negative right cell failed"):
        _ = Dot[Insert[Plus], _OrderedCell].dyad(ordered_left, ordered_right)


def main() raises:
    var x = Noun(List[Float64]([1.0e16, -1.0e16, 1.0]))
    var ones = Noun(List[Float64]([1.0, 1.0, 1.0]))
    # A left fold would produce one. The dot uses ordinary Insert's right fold.
    var sum = Expr["+/ . *"].dyad(x, ones)
    assert_true(sum.is_float64())
    assert_equal(sum.as_float(), 0.0)
    var singleton = Noun(List[Float64]([-0.0]))
    var one = Noun(List[Float64]([1.0]))
    assert_equal(bitcast[DType.uint64](Expr["+/ . *"].dyad(singleton, one).as_float()),
                 UInt64(0x8000000000000000))
    var empty = Noun(List[Float64]())
    assert_equal(Expr["+/ . *"].dyad(empty, empty).as_float(), 0.0)
    var mixed = Noun(List[Int]([1, 2, 3]))
    assert_equal(Expr["+/ . *"].dyad(mixed, ones).as_float(), 6.0)
    with assert_raises(contains="contracted axes"):
        _ = Expr["+/ . *"].dyad(singleton, ones)

    # A reduction other than Insert receives the intact vector of products.
    var xs = Noun(List[Float64]([1.0, 2.0, 3.0]))
    var products = Dot[Right, Times].dyad(xs, xs)
    assert_true(products.is_float64())
    assert_equal(products.dims(), List[Int]([3]))
    assert_equal(products.as_floats(), List[Float64]([1., 4., 9.]))
    var matches = Dot[Right, Equal].dyad(xs, ones)
    assert_true(matches.is_bool())
    assert_equal(matches.as_bools(), List[Bool]([True, False, False]))
    with assert_raises(contains="second cell failed"):
        _ = Dot[Insert[Plus], _OrderedCell].dyad(xs, ones)
    var matrix = Noun(List[Float64]([1.0e16, -1.0e16, 1., 4., 5., 6.])).with_shape([2, 3])
    var projected = Expr["+/ . *"].dyad(matrix, ones)
    assert_true(projected.is_float64())
    assert_equal(projected.dims(), List[Int]([2]))
    assert_equal(projected.as_floats(), List[Float64]([0., 15.]))
    var intact = Dot[Right, Times].dyad(matrix, ones)
    assert_equal(intact.dims(), List[Int]([2, 3]))
    assert_equal(intact.as_floats(), matrix.as_floats())
    var single_col = Noun(List[Float64]([1., -0.])).with_shape([2, 1])
    var signs = Expr["+/ . *"].dyad(single_col, one)
    assert_equal(bitcast[DType.uint64](signs.float_values[1]), UInt64(0x8000000000000000))
    var no_rows = Noun(List[Float64]()).with_shape([0, 3])
    var empty_products = Dot[Right, Times].dyad(no_rows, ones)
    assert_true(empty_products.is_float64())
    assert_equal(empty_products.dims(), List[Int]([0, 3]))
    var row_errors = Noun(List[Float64]([1., 3., 2., 4.])).with_shape([2, 2])
    with assert_raises(contains="third cell failed"):
        _ = Dot[Insert[Plus], _OrderedCell].dyad(row_errors, Noun(List[Float64]([1., 1.])))
    _test_vector_matrix_dot()
    print("PASS Float64 vector and matrix dot")
