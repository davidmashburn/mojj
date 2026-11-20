"""Verb bond and reflex with rank-aware dyadic application."""
from .array_modifiers import rank_dyad
from ._verb_base import Verb, WHOLE_NOUN_RANK
from .verbs import Atop
from .nouns import Noun


struct Reflex[F: Verb](Verb):
    @staticmethod
    def describe() -> String:
        return "reflex(" + Self.F.describe() + ")"

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Self.F.dyad(y, y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Self.F.dyad(y, x)

    @staticmethod
    def monad_rank() -> Int:
        return WHOLE_NOUN_RANK

    @staticmethod
    def left_rank() -> Int:
        return Self.F.right_rank()

    @staticmethod
    def left_cell_rank(noun_rank: Int) -> Int:
        return Self.F.right_cell_rank(noun_rank)

    @staticmethod
    def right_rank() -> Int:
        return Self.F.left_rank()

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return Self.F.left_cell_rank(noun_rank)


struct _BondCell[F: Verb, G: Verb](Verb):
    @staticmethod
    def describe() -> String:
        return "bond(" + Self.F.describe() + ", " + Self.G.describe() + ")"

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Atop[Self.F, Self.G].monad(y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return Self.F.dyad(Self.G.monad(x), Self.G.monad(y))

    @staticmethod
    def monad_rank() -> Int:
        return Self.G.monad_rank()

    @staticmethod
    def monad_cell_rank(noun_rank: Int) -> Int:
        return Self.G.monad_cell_rank(noun_rank)

    @staticmethod
    def left_rank() -> Int:
        return Self.G.monad_rank()

    @staticmethod
    def left_cell_rank(noun_rank: Int) -> Int:
        return Self.G.monad_cell_rank(noun_rank)

    @staticmethod
    def right_rank() -> Int:
        return Self.G.monad_rank()

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return Self.G.monad_cell_rank(noun_rank)


struct BondVerbs[F: Verb, G: Verb](Verb):
    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return Atop[Self.F, Self.G].monad(y)

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return rank_dyad[_BondCell[Self.F, Self.G]](
            x, y, Self.G.monad_cell_rank(x.rank), Self.G.monad_cell_rank(y.rank)
        )

    @staticmethod
    def describe() -> String:
        return _BondCell[Self.F, Self.G].describe()

    @staticmethod
    def monad_rank() -> Int:
        return Self.G.monad_rank()

    @staticmethod
    def monad_cell_rank(noun_rank: Int) -> Int:
        return Self.G.monad_cell_rank(noun_rank)

    @staticmethod
    def left_rank() -> Int:
        return Self.G.monad_rank()

    @staticmethod
    def left_cell_rank(noun_rank: Int) -> Int:
        return Self.G.monad_cell_rank(noun_rank)

    @staticmethod
    def right_rank() -> Int:
        return Self.G.monad_rank()

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        return Self.G.monad_cell_rank(noun_rank)
