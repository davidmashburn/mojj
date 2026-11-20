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
        if x == 2.0:
            raise Error("second cell failed")
        if x == 3.0:
            raise Error("third cell failed")
        return x * y


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
    print("PASS Float64 vector dot")
