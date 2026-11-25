"""Typed numerical expressions and bounded J phrases."""

from .core import (
    Add, After, Compose, Identity, Input, Map, Mean, Moments, Negate, PopulationMoments,
    ReductionExpr, ScalarOp, Scale, SeriesExpr, Sqrt, Square, Sum,
    evaluate, materialize,
)
from .strings import Expr, jj

from .nouns import Noun
from .views import StridedView
from .reductions import MeanFold, SharedReduce, StreamingFold, SumFold
from .modifiers import Repeat
