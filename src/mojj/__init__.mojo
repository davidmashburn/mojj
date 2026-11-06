"""Typed numerical expressions and bounded J phrases."""

from .core import (
    Add, After, Compose, Identity, Input, Map, Mean, Negate,
    ReductionExpr, ScalarOp, Scale, SeriesExpr, Sqrt, Square, Sum,
    evaluate, materialize,
)
from .strings import Expr

from .nouns import Noun
