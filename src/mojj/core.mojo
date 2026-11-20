"""Typed, lazy Float64 expressions for small CPU computations.

Expression types retain their structure for inspection while evaluators choose
the runtime traversal.  Series expressions are read lazily, so nested maps do
not allocate mapped temporaries.
"""

from std.collections import List
from std.math import isfinite, sqrt


trait ScalarOp:
    """A compile-time scalar operation over Float64 values."""

    @staticmethod
    def apply(x: Float64) -> Float64:
        ...

    @staticmethod
    def describe() -> String:
        ...


struct Identity(ScalarOp):
    """Return each input value unchanged."""

    @staticmethod
    def apply(x: Float64) -> Float64:
        return x

    @staticmethod
    def describe() -> String:
        return "identity"


struct Negate(ScalarOp):
    """Negate each input value."""

    @staticmethod
    def apply(x: Float64) -> Float64:
        return -x

    @staticmethod
    def describe() -> String:
        return "negate"


struct Square(ScalarOp):
    """Square each input value."""

    @staticmethod
    def apply(x: Float64) -> Float64:
        return x * x

    @staticmethod
    def describe() -> String:
        return "square"


struct Sqrt(ScalarOp):
    """Take the square root of each input value."""

    @staticmethod
    def apply(x: Float64) -> Float64:
        return sqrt(x)

    @staticmethod
    def describe() -> String:
        return "sqrt"


struct Add[amount: Int](ScalarOp):
    """Add a compile-time integer amount to each value."""

    @staticmethod
    def apply(x: Float64) -> Float64:
        return x + Float64(Self.amount)

    @staticmethod
    def describe() -> String:
        return "add[" + String(Self.amount) + "]"


struct Scale[factor: Int](ScalarOp):
    """Multiply each value by a compile-time integer factor."""

    @staticmethod
    def apply(x: Float64) -> Float64:
        return x * Float64(Self.factor)

    @staticmethod
    def describe() -> String:
        return "scale[" + String(Self.factor) + "]"


struct Compose[Outer: ScalarOp, Inner: ScalarOp](ScalarOp):
    """Apply ``Inner`` first, followed by ``Outer``."""

    @staticmethod
    def apply(x: Float64) -> Float64:
        return Self.Outer.apply(Self.Inner.apply(x))

    @staticmethod
    def describe() -> String:
        return "compose(" + Self.Outer.describe() + ", " + Self.Inner.describe() + ")"


trait SeriesExpr:
    """A lazy indexed series; evaluators supply valid input indices."""

    @staticmethod
    def read(data: List[Float64], index: Int) -> Float64:
        """Internal traversal hook, not a bounds-checked public accessor."""
        ...

    @staticmethod
    def describe() -> String:
        ...


struct Input(SeriesExpr):
    """The source series supplied to an evaluator."""

    @staticmethod
    def read(data: List[Float64], index: Int) -> Float64:
        return data[index]

    @staticmethod
    def describe() -> String:
        return "input"


struct Map[Op: ScalarOp, Source: SeriesExpr = Input](SeriesExpr):
    """Apply a scalar operation lazily to a source series."""

    @staticmethod
    def read(data: List[Float64], index: Int) -> Float64:
        return Self.Op.apply(Self.Source.read(data, index))

    @staticmethod
    def describe() -> String:
        return "map(" + Self.Op.describe() + ", " + Self.Source.describe() + ")"


trait ReductionExpr:
    """A lazy reduction evaluated in input order over a runtime-length list."""

    @staticmethod
    def evaluate(data: List[Float64]) raises -> Float64:
        ...

    @staticmethod
    def describe() -> String:
        ...


struct Sum[Source: SeriesExpr = Input](ReductionExpr):
    """Sum a source series with a left-to-right Float64 accumulator."""

    @staticmethod
    def evaluate(data: List[Float64]) raises -> Float64:
        var total: Float64 = 0.0
        for index in range(len(data)):
            total += Self.Source.read(data, index)
        return total

    @staticmethod
    def describe() -> String:
        return "sum(" + Self.Source.describe() + ")"


struct Mean[Source: SeriesExpr = Input](ReductionExpr):
    """Average a source series with a left-to-right Float64 accumulator."""

    @staticmethod
    def evaluate(data: List[Float64]) raises -> Float64:
        if len(data) == 0:
            raise Error("mean requires nonempty input")
        var total: Float64 = 0.0
        for index in range(len(data)):
            total += Self.Source.read(data, index)
        return total / Float64(len(data))

    @staticmethod
    def describe() -> String:
        return "mean(" + Self.Source.describe() + ")"


@fieldwise_init
struct Moments(ImplicitlyCopyable):
    """Mean and population variance from one evaluation."""

    var mean: Float64
    var variance: Float64


struct PopulationMoments[Source: SeriesExpr = Input]:
    """Evaluate Welford's running mean and population variance in one pass."""

    @staticmethod
    def evaluate(data: List[Float64]) raises -> Moments:
        if len(data) == 0:
            raise Error("population moments require at least one value")

        var mean = Self.Source.read(data, 0)
        var mean_residual: Float64 = 0.0
        var m2: Float64 = 0.0
        for index in range(1, len(data)):
            var value = Self.Source.read(data, index)
            var delta = (value - mean) - mean_residual
            var increment = mean_residual + delta / Float64(index + 1)
            var next_mean = mean + increment
            # TwoSum retains the part of the updated mean below one Float64
            # ulp. It matters for variance even when the returned mean rounds.
            var applied = next_mean - mean
            mean_residual = (mean - (next_mean - applied)) + (increment - applied)
            mean = next_mean
            m2 += delta * ((value - mean) - mean_residual)
        if not isfinite(mean) or not isfinite(m2):
            raise Error("population moments require finite values and intermediates")
        return Moments(mean, m2 / Float64(len(data)))

    @staticmethod
    def describe() -> String:
        return "population_moments(" + Self.Source.describe() + ")"


struct After[Op: ScalarOp, Source: ReductionExpr](ReductionExpr):
    """Apply a scalar operation to a reduction's scalar result."""

    @staticmethod
    def evaluate(data: List[Float64]) raises -> Float64:
        return Self.Op.apply(Self.Source.evaluate(data))

    @staticmethod
    def describe() -> String:
        return "after(" + Self.Op.describe() + ", " + Self.Source.describe() + ")"


def materialize[Expr: SeriesExpr](data: List[Float64]) -> List[Float64]:
    """Return a fresh list populated by one left-to-right source traversal."""
    var result = List[Float64](length=len(data), fill=0.0)
    for index in range(len(data)):
        result[index] = Expr.read(data, index)
    return result^


def evaluate[Expr: ReductionExpr](data: List[Float64]) raises -> Float64:
    """Evaluate a reduction over the supplied runtime-length data."""
    return Expr.evaluate(data)
