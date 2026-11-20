from std.collections import List
from std.random import random_float64, seed
from std.testing import assert_equal, assert_raises
from mojj import (
    Add, Map, Mean, MeanFold, Negate, ScalarOp, Scale, SharedReduce, Square,
    StreamingFold, StridedView, Sum, SumFold,
)


struct Last(StreamingFold):
    var value: Float64

    def __init__(out self):
        self.value = -1.0

    def update(mut self, value: Float64):
        self.value = value

    def finish(self, count: Int) -> Float64:
        return self.value

    @staticmethod
    def describe() -> String:
        return "last"


struct _Draw(ScalarOp):
    @staticmethod
    def apply(x: Float64) -> Float64:
        return x + random_float64(0, 1)

    @staticmethod
    def describe() -> String:
        return "draw"


struct _Reject[message: StringLiteral](StreamingFold):
    def __init__(out self):
        pass

    def update(mut self, value: Float64) raises:
        raise Error(String(Self.message) + " update")

    def finish(self, count: Int) raises -> Float64:
        raise Error(String(Self.message) + " finish")

    @staticmethod
    def describe() -> String:
        return String(Self.message)


def test_shared_transform() raises:
    # Replay the same RNG stream to make each transform call observable.
    var values: List[Float64] = [1., 3., 7.]
    seed(37)
    var expected = 0.0
    for value in values:
        expected += _Draw.apply(value)
    var next_draw = random_float64(0, 1)

    seed(37)
    var result = SharedReduce[SumFold[], SumFold[], _Draw].evaluate(values)
    assert_equal(result[0], expected)
    assert_equal(result[1], expected)
    assert_equal(random_float64(0, 1), next_draw)


def test_error_order() raises:
    comptime Left = _Reject["left"]
    comptime Right = _Reject["right"]
    var singleton: List[Float64] = [1.]
    var empty = List[Float64]()
    with assert_raises(contains="left update"):
        _ = SharedReduce[Left, Right].evaluate(singleton)
    with assert_raises(contains="left finish"):
        _ = SharedReduce[Left, Right].evaluate(empty)
    with assert_raises(contains="right update"):
        _ = SharedReduce[SumFold[], Right].evaluate(singleton)
    with assert_raises(contains="right finish"):
        _ = SharedReduce[SumFold[], Right].evaluate(empty)


def main() raises:
    comptime Pair = SharedReduce[SumFold[Negate], MeanFold[Square], Add[1]]
    var values: List[Float64] = [1., -3., 5.]
    var pair = Pair.evaluate(values)
    assert_equal(pair[0], Sum[Map[Negate, Map[Add[1]]]].evaluate(values))
    assert_equal(pair[1], Mean[Map[Square, Map[Add[1]]]].evaluate(values))
    assert_equal(Pair.describe(), "shared_reduce(sum_fold(negate), mean_fold(square), add[1])")

    var subset = StridedView(values, 2, 2, -2)
    var on_view = SharedReduce[SumFold[], Last, Scale[2]].evaluate(subset)
    assert_equal(on_view[0], 12.)
    assert_equal(on_view[1], 2.)
    var empty = List[Float64]()
    var on_empty = SharedReduce[Last, SumFold[]].evaluate(empty)
    assert_equal(on_empty[0], -1.)
    assert_equal(on_empty[1], 0.)
    with assert_raises(contains="mean requires nonempty input"):
        _ = Pair.evaluate(empty)
    var singleton: List[Float64] = [2.]
    var again = Pair.evaluate(singleton)
    assert_equal(again[0], -3.)
    assert_equal(again[1], 9.)
    var cancellation: List[Float64] = [1.0e16, -1.0e16, 1.0]
    var ordered = SharedReduce[SumFold[], MeanFold[]].evaluate(cancellation)
    assert_equal(ordered[0], 1.)
    assert_equal(ordered[1], 1./3.)
    test_shared_transform()
    test_error_order()
    print("PASS shared reductions")
