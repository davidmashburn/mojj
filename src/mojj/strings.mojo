"""Compile bounded expression strings into Mojj's typed core operations."""

from std.collections import List

from ._syntax import parse
from .core import (
    After,
    Compose,
    Identity,
    Input,
    Map,
    Mean,
    Negate,
    ReductionExpr,
    ScalarOp,
    Scale,
    SeriesExpr,
    Sqrt,
    Square,
    Sum,
    evaluate,
    materialize,
)


struct _Syntax[source: StringLiteral]:
    comptime ast = parse(String(Self.source))


struct _Scalar[source: StringLiteral, node: Int](ScalarOp):
    """Lower one valid scalar subtree to the existing ScalarOp types."""

    @staticmethod
    def apply(x: Float64) -> Float64:
        comptime ast = _Syntax[Self.source].ast
        comptime if ast.error != "":
            return x
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == 1:
            return Identity.apply(x)
        elif current.kind == 2:
            return Negate.apply(x)
        elif current.kind == 3:
            return Square.apply(x)
        elif current.kind == 4:
            return Sqrt.apply(x)
        elif current.kind == 5:
            return Scale[2].apply(x)
        elif current.kind == 40:
            return Compose[
                _Scalar[Self.source, current.left],
                _Scalar[Self.source, current.right],
            ].apply(x)
        else:
            return x

    @staticmethod
    def describe() -> String:
        comptime ast = _Syntax[Self.source].ast
        comptime if ast.error != "":
            return ""
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == 1:
            return Identity.describe()
        elif current.kind == 2:
            return Negate.describe()
        elif current.kind == 3:
            return Square.describe()
        elif current.kind == 4:
            return Sqrt.describe()
        elif current.kind == 5:
            return Scale[2].describe()
        elif current.kind == 40:
            return Compose[
                _Scalar[Self.source, current.left],
                _Scalar[Self.source, current.right],
            ].describe()
        else:
            return ""


struct _Reduction[
    source: StringLiteral,
    node: Int,
    Source: SeriesExpr = Input,
](ReductionExpr):
    """Lower one valid reduction subtree through core reducers and maps."""

    @staticmethod
    def evaluate(data: List[Float64]) raises -> Float64:
        comptime ast = _Syntax[Self.source].ast
        comptime if ast.error != "":
            return 0.0
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == 20:
            return Sum[Self.Source].evaluate(data)
        elif current.kind == 21:
            return Mean[Self.Source].evaluate(data)
        elif current.kind == 40:
            comptime lhs = ast.nodes[current.left]
            comptime if lhs.category == 1:
                return _Reduction[
                    Self.source,
                    current.left,
                    Map[_Scalar[Self.source, current.right], Self.Source],
                ].evaluate(data)
            else:
                return After[
                    _Scalar[Self.source, current.left],
                    _Reduction[Self.source, current.right, Self.Source],
                ].evaluate(data)
        else:
            return 0.0

    @staticmethod
    def describe() -> String:
        comptime ast = _Syntax[Self.source].ast
        comptime if ast.error != "":
            return ""
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == 20:
            return Sum[Self.Source].describe()
        elif current.kind == 21:
            return Mean[Self.Source].describe()
        elif current.kind == 40:
            comptime lhs = ast.nodes[current.left]
            comptime if lhs.category == 1:
                return _Reduction[
                    Self.source,
                    current.left,
                    Map[_Scalar[Self.source, current.right], Self.Source],
                ].describe()
            else:
                return After[
                    _Scalar[Self.source, current.left],
                    _Reduction[Self.source, current.right, Self.Source],
                ].describe()
        else:
            return ""


struct Expr[source: StringLiteral]:
    """Compile one literal expression and expose category-specific consumers."""

    comptime ast = _Syntax[Self.source].ast

    @staticmethod
    def describe() -> String:
        comptime if Self.ast.error != "":
            comptime assert False, Self.ast.error
        else:
            comptime current = Self.ast.nodes[Self.ast.root]
            comptime if current.category == 0:
                return _Scalar[Self.source, Self.ast.root].describe()
            else:
                return _Reduction[Self.source, Self.ast.root, Input].describe()
        return ""

    @staticmethod
    def apply(x: Float64) -> Float64:
        comptime if Self.ast.error != "":
            comptime assert False, Self.ast.error
        else:
            comptime current = Self.ast.nodes[Self.ast.root]
            comptime if current.category != 0:
                comptime assert False, (
                    "Mojj category at byte "
                    + String(current.position)
                    + ": apply requires a scalar expression"
                )
            else:
                return _Scalar[Self.source, Self.ast.root].apply(x)
        return x

    @staticmethod
    def map(data: List[Float64]) -> List[Float64]:
        comptime if Self.ast.error != "":
            comptime assert False, Self.ast.error
        else:
            comptime current = Self.ast.nodes[Self.ast.root]
            comptime if current.category != 0:
                comptime assert False, (
                    "Mojj category at byte "
                    + String(current.position)
                    + ": map requires a scalar expression"
                )
            else:
                return materialize[
                    Map[_Scalar[Self.source, Self.ast.root], Input]
                ](data)
        return List[Float64]()

    @staticmethod
    def reduce(data: List[Float64]) raises -> Float64:
        comptime if Self.ast.error != "":
            comptime assert False, Self.ast.error
        else:
            comptime current = Self.ast.nodes[Self.ast.root]
            comptime if current.category != 1:
                comptime assert False, (
                    "Mojj category at byte "
                    + String(current.position)
                    + ": reduce requires a reduction expression"
                )
            else:
                return evaluate[
                    _Reduction[Self.source, Self.ast.root, Input]
                ](data)
        return 0.0
