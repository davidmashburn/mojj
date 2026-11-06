"""Compile literal J phrases into the same typed verbs used by Mojo callers."""
from std.collections import List
from ._syntax import Kind, NumberKind, Part, parse
from .nouns import Noun, NounDType, NounProvider
from .verbs import (
    Verb, Plus, Minus, Times, Divide, Squared, Doubled, Root,
    Left, Right, Tally, Insert, Hook, Fork, ComposeAll, Atop,
    BindLeftNoun, BindRightNoun, ConstantNoun,
)


struct _Syntax[source: StringLiteral]:
    comptime ast = parse(String(Self.source))


struct _Value[source: StringLiteral, node: Int](NounProvider):
    @staticmethod
    def value() raises -> Noun:
        comptime ast = _Syntax[Self.source].ast
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == Kind.LITERAL:
            comptime first = current.a
            comptime count = current.b
            comptime if count == 1:
                comptime number = ast.numbers[first]
                comptime if number.kind == NumberKind.REAL:
                    return Noun(number.real)
                elif number.kind == NumberKind.BOOLEAN:
                    return Noun(Bool(number.integer))
                else:
                    return Noun(number.integer)
            else:
                var real = False
                var boolean = True
                comptime for index in range(count):
                    comptime number = ast.numbers[first + index]
                    real = real or number.kind == NumberKind.REAL
                    boolean = boolean and number.kind == NumberKind.BOOLEAN
                if real:
                    var values = List[Float64]()
                    comptime for index in range(count):
                        comptime number = ast.numbers[first + index]
                        values.append(number.real)
                    return Noun(values^)
                elif boolean:
                    var values = List[Bool]()
                    comptime for index in range(count):
                        comptime number = ast.numbers[first + index]
                        values.append(Bool(number.integer))
                    return Noun(values^)
                else:
                    var values = List[Int]()
                    comptime for index in range(count):
                        comptime number = ast.numbers[first + index]
                        values.append(number.integer)
                    return Noun(values^)
        elif current.kind == Kind.MONAD:
            return _Verb[Self.source, current.a].monad(_Value[Self.source, current.b].value())
        elif current.kind == Kind.DYAD:
            return _Verb[Self.source, current.a].dyad(_Value[Self.source, current.b].value(), _Value[Self.source, current.c].value())
        else:
            raise Error("Mojj internal: expected noun node")

    @staticmethod
    def describe() -> String:
        comptime ast = _Syntax[Self.source].ast
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == Kind.LITERAL:
            var result = String("")
            comptime for index in range(current.b):
                if index > 0:
                    result += " "
                comptime number = ast.numbers[current.a + index]
                if number.kind == NumberKind.REAL:
                    result += String(number.real)
                else:
                    result += String(number.integer)
            return result
        elif current.kind == Kind.MONAD:
            return "monad(" + _Verb[Self.source, current.a].describe() + ", " + _Value[Self.source, current.b].describe() + ")"
        elif current.kind == Kind.DYAD:
            return "dyad(" + _Verb[Self.source, current.a].describe() + ", " + _Value[Self.source, current.b].describe() + ", " + _Value[Self.source, current.c].describe() + ")"
        else:
            return "invalid noun"


struct _Verb[source: StringLiteral, node: Int](Verb):
    @staticmethod
    def monad(y: Noun) raises -> Noun:
        comptime ast = _Syntax[Self.source].ast
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == Kind.RIGHT:
            return Right.monad(y)
        elif current.kind == Kind.LEFT:
            return Left.monad(y)
        elif current.kind == Kind.PLUS:
            return Plus.monad(y)
        elif current.kind == Kind.MINUS:
            return Minus.monad(y)
        elif current.kind == Kind.TIMES:
            return Times.monad(y)
        elif current.kind == Kind.DIVIDE:
            return Divide.monad(y)
        elif current.kind == Kind.SQUARE:
            return Squared.monad(y)
        elif current.kind == Kind.DOUBLE:
            return Doubled.monad(y)
        elif current.kind == Kind.SQRT:
            return Root.monad(y)
        elif current.kind == Kind.TALLY:
            return Tally.monad(y)
        elif current.kind == Kind.INSERT:
            return Insert[_Verb[Self.source, current.a]].monad(y)
        elif current.kind == Kind.HOOK:
            return Hook[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].monad(y)
        elif current.kind == Kind.FORK:
            return Fork[_Verb[Self.source, current.a], _Verb[Self.source, current.b], _Verb[Self.source, current.c]].monad(y)
        elif current.kind == Kind.COMPOSE:
            return ComposeAll[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].monad(y)
        elif current.kind == Kind.ATOP:
            return Atop[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].monad(y)
        elif current.kind == Kind.BIND_LEFT:
            return BindLeftNoun[_Value[Self.source, current.a], _Verb[Self.source, current.b]].monad(y)
        elif current.kind == Kind.BIND_RIGHT:
            return BindRightNoun[_Verb[Self.source, current.a], _Value[Self.source, current.b]].monad(y)
        elif current.kind == Kind.CONSTANT:
            return ConstantNoun[_Value[Self.source, current.a]].monad(y)
        else:
            raise Error("Mojj internal: unsupported verb node")

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        comptime ast = _Syntax[Self.source].ast
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == Kind.RIGHT:
            return Right.dyad(x, y)
        elif current.kind == Kind.LEFT:
            return Left.dyad(x, y)
        elif current.kind == Kind.PLUS:
            return Plus.dyad(x, y)
        elif current.kind == Kind.MINUS:
            return Minus.dyad(x, y)
        elif current.kind == Kind.TIMES:
            return Times.dyad(x, y)
        elif current.kind == Kind.DIVIDE:
            return Divide.dyad(x, y)
        elif current.kind == Kind.SQUARE:
            return Squared.dyad(x, y)
        elif current.kind == Kind.DOUBLE:
            return Doubled.dyad(x, y)
        elif current.kind == Kind.SQRT:
            return Root.dyad(x, y)
        elif current.kind == Kind.TALLY:
            return Tally.dyad(x, y)
        elif current.kind == Kind.INSERT:
            return Insert[_Verb[Self.source, current.a]].dyad(x, y)
        elif current.kind == Kind.HOOK:
            return Hook[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].dyad(x, y)
        elif current.kind == Kind.FORK:
            return Fork[_Verb[Self.source, current.a], _Verb[Self.source, current.b], _Verb[Self.source, current.c]].dyad(x, y)
        elif current.kind == Kind.COMPOSE:
            return ComposeAll[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].dyad(x, y)
        elif current.kind == Kind.ATOP:
            return Atop[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].dyad(x, y)
        elif current.kind == Kind.BIND_LEFT:
            return BindLeftNoun[_Value[Self.source, current.a], _Verb[Self.source, current.b]].dyad(x, y)
        elif current.kind == Kind.BIND_RIGHT:
            return BindRightNoun[_Verb[Self.source, current.a], _Value[Self.source, current.b]].dyad(x, y)
        elif current.kind == Kind.CONSTANT:
            return ConstantNoun[_Value[Self.source, current.a]].dyad(x, y)
        else:
            raise Error("Mojj internal: unsupported verb node")

    @staticmethod
    def describe() -> String:
        comptime ast = _Syntax[Self.source].ast
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == Kind.RIGHT:
            return Right.describe()
        elif current.kind == Kind.LEFT:
            return Left.describe()
        elif current.kind == Kind.PLUS:
            return Plus.describe()
        elif current.kind == Kind.MINUS:
            return Minus.describe()
        elif current.kind == Kind.TIMES:
            return Times.describe()
        elif current.kind == Kind.DIVIDE:
            return Divide.describe()
        elif current.kind == Kind.SQUARE:
            return Squared.describe()
        elif current.kind == Kind.DOUBLE:
            return Doubled.describe()
        elif current.kind == Kind.SQRT:
            return Root.describe()
        elif current.kind == Kind.TALLY:
            return Tally.describe()
        elif current.kind == Kind.INSERT:
            return Insert[_Verb[Self.source, current.a]].describe()
        elif current.kind == Kind.HOOK:
            return Hook[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].describe()
        elif current.kind == Kind.FORK:
            return Fork[_Verb[Self.source, current.a], _Verb[Self.source, current.b], _Verb[Self.source, current.c]].describe()
        elif current.kind == Kind.COMPOSE:
            return ComposeAll[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].describe()
        elif current.kind == Kind.ATOP:
            return Atop[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].describe()
        elif current.kind == Kind.BIND_LEFT:
            return BindLeftNoun[_Value[Self.source, current.a], _Verb[Self.source, current.b]].describe()
        elif current.kind == Kind.BIND_RIGHT:
            return BindRightNoun[_Verb[Self.source, current.a], _Value[Self.source, current.b]].describe()
        elif current.kind == Kind.CONSTANT:
            return ConstantNoun[_Value[Self.source, current.a]].describe()
        else:
            return "invalid verb"

    @staticmethod
    def monad_rank() -> Int:
        comptime ast = _Syntax[Self.source].ast
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == Kind.RIGHT:
            return Right.monad_rank()
        elif current.kind == Kind.LEFT:
            return Left.monad_rank()
        elif current.kind == Kind.PLUS:
            return Plus.monad_rank()
        elif current.kind == Kind.MINUS:
            return Minus.monad_rank()
        elif current.kind == Kind.TIMES:
            return Times.monad_rank()
        elif current.kind == Kind.DIVIDE:
            return Divide.monad_rank()
        elif current.kind == Kind.SQUARE:
            return Squared.monad_rank()
        elif current.kind == Kind.DOUBLE:
            return Doubled.monad_rank()
        elif current.kind == Kind.SQRT:
            return Root.monad_rank()
        elif current.kind == Kind.TALLY:
            return Tally.monad_rank()
        elif current.kind == Kind.INSERT:
            return Insert[_Verb[Self.source, current.a]].monad_rank()
        elif current.kind == Kind.HOOK:
            return Hook[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].monad_rank()
        elif current.kind == Kind.FORK:
            return Fork[_Verb[Self.source, current.a], _Verb[Self.source, current.b], _Verb[Self.source, current.c]].monad_rank()
        elif current.kind == Kind.COMPOSE:
            return ComposeAll[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].monad_rank()
        elif current.kind == Kind.ATOP:
            return Atop[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].monad_rank()
        elif current.kind == Kind.BIND_LEFT:
            return BindLeftNoun[_Value[Self.source, current.a], _Verb[Self.source, current.b]].monad_rank()
        elif current.kind == Kind.BIND_RIGHT:
            return BindRightNoun[_Verb[Self.source, current.a], _Value[Self.source, current.b]].monad_rank()
        elif current.kind == Kind.CONSTANT:
            return ConstantNoun[_Value[Self.source, current.a]].monad_rank()
        else:
            return -1

    @staticmethod
    def left_rank() -> Int:
        comptime ast = _Syntax[Self.source].ast
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == Kind.RIGHT:
            return Right.left_rank()
        elif current.kind == Kind.LEFT:
            return Left.left_rank()
        elif current.kind == Kind.PLUS:
            return Plus.left_rank()
        elif current.kind == Kind.MINUS:
            return Minus.left_rank()
        elif current.kind == Kind.TIMES:
            return Times.left_rank()
        elif current.kind == Kind.DIVIDE:
            return Divide.left_rank()
        elif current.kind == Kind.SQUARE:
            return Squared.left_rank()
        elif current.kind == Kind.DOUBLE:
            return Doubled.left_rank()
        elif current.kind == Kind.SQRT:
            return Root.left_rank()
        elif current.kind == Kind.TALLY:
            return Tally.left_rank()
        elif current.kind == Kind.INSERT:
            return Insert[_Verb[Self.source, current.a]].left_rank()
        elif current.kind == Kind.HOOK:
            return Hook[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].left_rank()
        elif current.kind == Kind.FORK:
            return Fork[_Verb[Self.source, current.a], _Verb[Self.source, current.b], _Verb[Self.source, current.c]].left_rank()
        elif current.kind == Kind.COMPOSE:
            return ComposeAll[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].left_rank()
        elif current.kind == Kind.ATOP:
            return Atop[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].left_rank()
        elif current.kind == Kind.BIND_LEFT:
            return BindLeftNoun[_Value[Self.source, current.a], _Verb[Self.source, current.b]].left_rank()
        elif current.kind == Kind.BIND_RIGHT:
            return BindRightNoun[_Verb[Self.source, current.a], _Value[Self.source, current.b]].left_rank()
        elif current.kind == Kind.CONSTANT:
            return ConstantNoun[_Value[Self.source, current.a]].left_rank()
        else:
            return -1

    @staticmethod
    def right_rank() -> Int:
        comptime ast = _Syntax[Self.source].ast
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == Kind.RIGHT:
            return Right.right_rank()
        elif current.kind == Kind.LEFT:
            return Left.right_rank()
        elif current.kind == Kind.PLUS:
            return Plus.right_rank()
        elif current.kind == Kind.MINUS:
            return Minus.right_rank()
        elif current.kind == Kind.TIMES:
            return Times.right_rank()
        elif current.kind == Kind.DIVIDE:
            return Divide.right_rank()
        elif current.kind == Kind.SQUARE:
            return Squared.right_rank()
        elif current.kind == Kind.DOUBLE:
            return Doubled.right_rank()
        elif current.kind == Kind.SQRT:
            return Root.right_rank()
        elif current.kind == Kind.TALLY:
            return Tally.right_rank()
        elif current.kind == Kind.INSERT:
            return Insert[_Verb[Self.source, current.a]].right_rank()
        elif current.kind == Kind.HOOK:
            return Hook[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].right_rank()
        elif current.kind == Kind.FORK:
            return Fork[_Verb[Self.source, current.a], _Verb[Self.source, current.b], _Verb[Self.source, current.c]].right_rank()
        elif current.kind == Kind.COMPOSE:
            return ComposeAll[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].right_rank()
        elif current.kind == Kind.ATOP:
            return Atop[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].right_rank()
        elif current.kind == Kind.BIND_LEFT:
            return BindLeftNoun[_Value[Self.source, current.a], _Verb[Self.source, current.b]].right_rank()
        elif current.kind == Kind.BIND_RIGHT:
            return BindRightNoun[_Verb[Self.source, current.a], _Value[Self.source, current.b]].right_rank()
        elif current.kind == Kind.CONSTANT:
            return ConstantNoun[_Value[Self.source, current.a]].right_rank()
        else:
            return -1

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        comptime ast = _Syntax[Self.source].ast
        comptime current = ast.nodes[Self.node]
        comptime if current.kind == Kind.RIGHT:
            return Right.insert_identity(dtype)
        elif current.kind == Kind.LEFT:
            return Left.insert_identity(dtype)
        elif current.kind == Kind.PLUS:
            return Plus.insert_identity(dtype)
        elif current.kind == Kind.MINUS:
            return Minus.insert_identity(dtype)
        elif current.kind == Kind.TIMES:
            return Times.insert_identity(dtype)
        elif current.kind == Kind.DIVIDE:
            return Divide.insert_identity(dtype)
        elif current.kind == Kind.SQUARE:
            return Squared.insert_identity(dtype)
        elif current.kind == Kind.DOUBLE:
            return Doubled.insert_identity(dtype)
        elif current.kind == Kind.SQRT:
            return Root.insert_identity(dtype)
        elif current.kind == Kind.TALLY:
            return Tally.insert_identity(dtype)
        elif current.kind == Kind.INSERT:
            return Insert[_Verb[Self.source, current.a]].insert_identity(dtype)
        elif current.kind == Kind.HOOK:
            return Hook[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].insert_identity(dtype)
        elif current.kind == Kind.FORK:
            return Fork[_Verb[Self.source, current.a], _Verb[Self.source, current.b], _Verb[Self.source, current.c]].insert_identity(dtype)
        elif current.kind == Kind.COMPOSE:
            return ComposeAll[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].insert_identity(dtype)
        elif current.kind == Kind.ATOP:
            return Atop[_Verb[Self.source, current.a], _Verb[Self.source, current.b]].insert_identity(dtype)
        elif current.kind == Kind.BIND_LEFT:
            return BindLeftNoun[_Value[Self.source, current.a], _Verb[Self.source, current.b]].insert_identity(dtype)
        elif current.kind == Kind.BIND_RIGHT:
            return BindRightNoun[_Verb[Self.source, current.a], _Value[Self.source, current.b]].insert_identity(dtype)
        elif current.kind == Kind.CONSTANT:
            return ConstantNoun[_Value[Self.source, current.a]].insert_identity(dtype)
        else:
            raise Error("Mojj internal: unsupported verb node")


struct Expr[source: StringLiteral]:
    """One bounded literal phrase: a verb or a noun-producing sentence.

    Use monad/dyad with explicit Nouns, or value for a complete sentence.
    apply/map/reduce are Float64 convenience consumers with checked result rank.
    """
    comptime ast = _Syntax[Self.source].ast

    @staticmethod
    def describe() -> String:
        comptime if Self.ast.error != "":
            comptime assert False, Self.ast.error
            return ""
        elif Self.ast.part == Part.NOUN:
            return _Value[Self.source, Self.ast.root].describe()
        else:
            return _Verb[Self.source, Self.ast.root].describe()

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        comptime if Self.ast.error != "":
            comptime assert False, Self.ast.error
            return y.copy()
        elif Self.ast.part != Part.VERB:
            comptime assert False, "Mojj consumer: monad requires a verb; use value for a noun sentence"
            return y.copy()
        else:
            return _Verb[Self.source, Self.ast.root].monad(y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        comptime if Self.ast.error != "":
            comptime assert False, Self.ast.error
            return y.copy()
        elif Self.ast.part != Part.VERB:
            comptime assert False, "Mojj consumer: dyad requires a verb; use value for a noun sentence"
            return y.copy()
        else:
            return _Verb[Self.source, Self.ast.root].dyad(x, y)

    @staticmethod
    def value() raises -> Noun:
        comptime if Self.ast.error != "":
            comptime assert False, Self.ast.error
            return Noun(0)
        elif Self.ast.part != Part.NOUN:
            comptime assert False, "Mojj consumer: value requires a noun sentence; use monad or dyad for a verb"
            return Noun(0)
        else:
            return _Value[Self.source, Self.ast.root].value()

    @staticmethod
    def apply(x: Float64) raises -> Float64:
        return Self.monad(Noun(x)).as_float()

    @staticmethod
    def map(data: List[Float64]) raises -> List[Float64]:
        return Self.monad(Noun(data)).as_floats()

    @staticmethod
    def reduce(data: List[Float64]) raises -> Float64:
        return Self.monad(Noun(data)).as_float()
