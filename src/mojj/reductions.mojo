"""Explicit streaming reductions over one shared Float64 input."""

from std.collections import List
from .core import Identity, ScalarOp
from .views import StridedView


trait StreamingFold(Deinitable):
    """Per-evaluation state for a left-to-right Float64 reduction."""

    def __init__(out self):
        ...

    def update(mut self, value: Float64) raises:
        ...

    def finish(self, count: Int) raises -> Float64:
        ...

    @staticmethod
    def describe() -> String:
        ...


struct SumFold[Op: ScalarOp = Identity](StreamingFold):
    """Accumulate mapped values in order, starting at positive zero."""

    var _total: Float64

    def __init__(out self):
        self._total = 0.0

    def update(mut self, value: Float64):
        self._total += Self.Op.apply(value)

    def finish(self, count: Int) -> Float64:
        return self._total

    @staticmethod
    def describe() -> String:
        return "sum_fold(" + Self.Op.describe() + ")"


struct MeanFold[Op: ScalarOp = Identity](StreamingFold):
    """Average mapped values using the same accumulation order as Mean."""

    var _sum: SumFold[Self.Op]

    def __init__(out self):
        self._sum = SumFold[Self.Op]()

    def update(mut self, value: Float64):
        self._sum.update(value)

    def finish(self, count: Int) raises -> Float64:
        if count == 0:
            raise Error("mean requires nonempty input")
        return self._sum.finish(count) / Float64(count)

    @staticmethod
    def describe() -> String:
        return "mean_fold(" + Self.Op.describe() + ")"


struct SharedReduce[Left: StreamingFold, Right: StreamingFold, Op: ScalarOp = Identity]:
    """Transform each input once and pass that value to both folds."""

    @staticmethod
    def evaluate(data: List[Float64]) raises -> Tuple[Float64, Float64]:
        return Self.evaluate(StridedView(data, 0, len(data)))

    @staticmethod
    def evaluate[origin: Origin[mut=False]](
        view: StridedView[origin],
    ) raises -> Tuple[Float64, Float64]:
        var left = Self.Left()
        var right = Self.Right()
        for index in range(len(view)):
            var value = Self.Op.apply(view[index])
            left.update(value)
            right.update(value)
        var first = left.finish(len(view))
        return (first, right.finish(len(view)))

    @staticmethod
    def describe() -> String:
        return (
            "shared_reduce(" + Self.Left.describe() + ", " + Self.Right.describe()
            + ", " + Self.Op.describe() + ")"
        )
