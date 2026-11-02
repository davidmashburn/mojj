"""Public typed, lazy Float64 composition API."""

from .core import (
    Add, After, Compose, Identity, Input, Map, Mean, Negate,
    ReductionExpr, ScalarOp, Scale, SeriesExpr, Sqrt, Square, Sum,
    evaluate, materialize,
)
from .strings import Expr
