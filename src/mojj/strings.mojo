"""Compile literal J phrases into the same typed verbs used by Mojo callers."""
from std.collections import List
from ._syntax import Kind, NumberKind, Part, parse
from .array_modifiers import Dot, Prefix, Rank, Suffix
from .arrays import (
    ShapeReshape, Iota, RavelAppend, Stitch, Laminate, Gather, Head, Tail,
    Drop, Curtail, ReverseRotate, Transpose,
)
from .circle import Circle
from .modifiers import BondVerbs, Reflex, Repeat
from .nouns import Noun, NounDType, NounProvider
from .predicates import (
    Equal, Unequal, Less, Greater, LessEqual, GreaterEqual, MatchHalve,
    Complement, Or, And,
)
from .real_verbs import FloorMin, CeilingMax, MagnitudeResidue, Power, Logarithm
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


struct _VerbAt[index: Int, *candidates: Verb]:
    comptime Type = Self.candidates[Self.index]


struct _Verb[source: StringLiteral, node: Int](Verb):
    comptime ast = _Syntax[Self.source].ast
    comptime current = Self.ast.nodes[Self.node]
    comptime rank_operand = Self.current.b if Self.current.kind == Kind.RANK else 0
    comptime repeat_count = Self.ast.repeat_count(Self.current.b) if Self.current.kind == Kind.REPEAT else 0
    # Match Kind's indices. Parser-only kinds occupy slots but never execute as
    # verbs. Each selected type keeps its own ranks, kernels, and description.
    comptime Implementation = _VerbAt[
        Self.current.kind.code,
        Right,
        Left,
        Plus,
        Minus,
        Times,
        Divide,
        Squared,
        Doubled,
        Root,
        Tally,
        Right,  # CAP
        Right,  # LITERAL
        Insert[_Verb[Self.source, Self.current.a]],
        ComposeAll[_Verb[Self.source, Self.current.a], _Verb[Self.source, Self.current.b]],
        Atop[_Verb[Self.source, Self.current.a], _Verb[Self.source, Self.current.b]],
        Right,  # BIND
        Hook[_Verb[Self.source, Self.current.a], _Verb[Self.source, Self.current.b]],
        Fork[_Verb[Self.source, Self.current.a], _Verb[Self.source, Self.current.b], _Verb[Self.source, Self.current.c]],
        BindLeftNoun[_Value[Self.source, Self.current.a], _Verb[Self.source, Self.current.b]],
        BindRightNoun[_Verb[Self.source, Self.current.a], _Value[Self.source, Self.current.b]],
        ConstantNoun[_Value[Self.source, Self.current.a]],
        Right,  # MONAD
        Right,  # DYAD
        Equal,
        Unequal,
        Less,
        Greater,
        LessEqual,
        GreaterEqual,
        MatchHalve,
        Complement,
        Or,
        And,
        FloorMin,
        CeilingMax,
        MagnitudeResidue,
        Power,
        Logarithm,
        Circle,
        BondVerbs[_Verb[Self.source, Self.current.a], _Verb[Self.source, Self.current.b]],
        Reflex[_Verb[Self.source, Self.current.a]],
        ShapeReshape,
        Iota,
        RavelAppend,
        Stitch,
        Laminate,
        Gather,
        Head,
        Tail,
        Drop,
        Curtail,
        ReverseRotate,
        Transpose,
        Rank[
            _Verb[Self.source, Self.current.a],
            Self.ast.rank_value(Self.rank_operand, 0),
            Self.ast.rank_value(Self.rank_operand, 1),
            Self.ast.rank_value(Self.rank_operand, 2),
        ],
        Prefix[_Verb[Self.source, Self.current.a]],
        Suffix[_Verb[Self.source, Self.current.a]],
        Dot[_Verb[Self.source, Self.current.a], _Verb[Self.source, Self.current.b]],
        Repeat[_Verb[Self.source, Self.current.a], Self.repeat_count],
    ].Type

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.Implementation.monad(y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Self.Implementation.dyad(x, y)

    @staticmethod
    def has_float64_monad() -> Bool:
        return Self.Implementation.has_float64_monad()

    @staticmethod
    def float64_monad(value: Float64) raises -> Float64:
        return Self.Implementation.float64_monad(value)

    @staticmethod
    def has_float64_dyad() -> Bool:
        return Self.Implementation.has_float64_dyad()

    @staticmethod
    def float64_dyad(left: Float64, right: Float64) raises -> Float64:
        return Self.Implementation.float64_dyad(left, right)

    @staticmethod
    def describe() -> String:
        return Self.Implementation.describe()

    @staticmethod
    def monad_rank() -> Int:
        return Self.Implementation.monad_rank()

    @staticmethod
    def left_rank() -> Int:
        return Self.Implementation.left_rank()

    @staticmethod
    def right_rank() -> Int:
        return Self.Implementation.right_rank()

    @staticmethod
    def monad_cell_rank(noun_rank: Int) -> Int:
        return Self.Implementation.monad_cell_rank(noun_rank)

    @staticmethod
    def left_cell_rank(noun_rank: Int) -> Int:
        return Self.Implementation.left_cell_rank(noun_rank)

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return Self.Implementation.right_cell_rank(noun_rank)

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        return Self.Implementation.insert_identity(dtype)


struct Expr[source: StringLiteral]:
    """One bounded literal phrase: a verb or a noun-producing sentence.

    Use monad/dyad with explicit Nouns, or value for a complete sentence.
    apply/map/reduce are Float64 convenience consumers with checked result rank.
    map_owned/reduce_owned accept a transferred Float64 list.
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
        return Self._map(Noun(data))

    @staticmethod
    def map_owned(var data: List[Float64]) raises -> List[Float64]:
        """Map a transferred Float64 list without copying it on entry."""
        comptime if Self.ast.error == "" and Self.ast.part == Part.VERB:
            comptime kind = Self.ast.nodes[Self.ast.root].kind
            comptime if kind == Kind.LEFT or kind == Kind.RIGHT:
                return data^
        return Self._map(Noun.from_owned_float64(data^))

    @staticmethod
    def _map(data: Noun) raises -> List[Float64]:
        var result = Self.monad(data)
        if not result.is_vector():
            raise Error("Expr.map requires a vector result")
        if result.dtype == NounDType.FLOAT64:
            var values = result.float_values^
            result.float_values = List[Float64]()
            return values^
        return result.as_floats()

    @staticmethod
    def reduce(data: List[Float64]) raises -> Float64:
        return Self.monad(Noun(data)).as_float()

    @staticmethod
    def reduce_owned(var data: List[Float64]) raises -> Float64:
        """Reduce a transferred Float64 list without copying it on entry."""
        return Self.monad(Noun.from_owned_float64(data^)).as_float()


# Infer the element type before selecting a Noun constructor so bracket
# literals such as [2, 4] resolve as vectors of their native Mojo type.
def jj[T: Copyable, //](x: T) -> Noun where T == Int or T == Float64 or T == Bool:
    """Wrap a Mojo numeric or Boolean scalar as a noun."""
    comptime if T == Int:
        return Noun(rebind[Int](x))
    elif T == Float64:
        return Noun(rebind[Float64](x))
    else:
        return Noun(rebind[Bool](x))


def jj[T: Copyable, //](x: List[T]) -> Noun where T == Int or T == Float64 or T == Bool:
    """Copy a Mojo list into a vector noun with the same element type."""
    comptime if T == Int:
        return Noun(rebind[List[Int]](x))
    elif T == Float64:
        return Noun(rebind[List[Float64]](x))
    else:
        return Noun(rebind[List[Bool]](x))


def jj[source: StringLiteral]() raises -> Noun:
    """Evaluate a complete noun sentence."""
    return Expr[source].value()


def jj[source: StringLiteral](y: Noun) raises -> Noun:
    """Apply the compiled verb to one noun."""
    return Expr[source].monad(y)


def jj[source: StringLiteral](x: Noun, y: Noun) raises -> Noun:
    """Apply the compiled verb to a left and a right noun."""
    return Expr[source].dyad(x, y)
