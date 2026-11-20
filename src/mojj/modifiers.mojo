"""Typed verb modifiers."""
from .array_modifiers import rank_dyad
from ._verb_base import Verb, WHOLE_NOUN_RANK
from .verbs import Atop
from .nouns import Noun, NounDType


comptime MAX_REPEAT_COUNT = 1024


def _checked_repeat_count[count: Int]() -> Int:
    comptime assert 0 <= count <= MAX_REPEAT_COUNT, "Repeat count must be between 0 and 1024"
    return count


struct Repeat[Op: Verb, Count: Int](Verb):
    """Apply a verb a fixed number of times, holding the dyadic left noun fixed."""

    comptime _count = _checked_repeat_count[Self.Count]()

    @staticmethod
    def describe() -> String:
        return "repeat(" + Self.Op.describe() + ", " + String(Self._count) + ")"

    @staticmethod
    def monad(y: Noun) raises -> Noun:
        comptime if Self._count == 0:
            return y.copy()
        else:
            var result = Self.Op.monad(y)
            for _ in range(1, Self._count):
                result = Self.Op.monad(result)
            return result^

    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        comptime if Self._count == 0:
            return y.copy()
        else:
            var result = Self.Op.dyad(x, y)
            for _ in range(1, Self._count):
                result = Self.Op.dyad(x, result)
            return result^

    @staticmethod
    def insert_identity(dtype: NounDType) raises -> Noun:
        comptime if Self._count == 1:
            return Self.Op.insert_identity(dtype)
        else:
            raise Error("Insert identity is unsupported for this verb")

    @staticmethod
    def monad_rank() -> Int:
        comptime if Self._count == 1:
            return Self.Op.monad_rank()
        else:
            return WHOLE_NOUN_RANK

    @staticmethod
    def monad_cell_rank(noun_rank: Int) -> Int:
        comptime if Self._count == 1:
            return Self.Op.monad_cell_rank(noun_rank)
        else:
            return noun_rank

    @staticmethod
    def left_rank() -> Int:
        comptime if Self._count == 1:
            return Self.Op.left_rank()
        else:
            return WHOLE_NOUN_RANK

    @staticmethod
    def left_cell_rank(noun_rank: Int) -> Int:
        comptime if Self._count == 1:
            return Self.Op.left_cell_rank(noun_rank)
        else:
            return noun_rank

    @staticmethod
    def right_rank() -> Int:
        comptime if Self._count == 1:
            return Self.Op.right_rank()
        else:
            return WHOLE_NOUN_RANK

    @staticmethod
    def right_cell_rank(noun_rank: Int) -> Int:
        comptime if Self._count == 1:
            return Self.Op.right_cell_rank(noun_rank)
        else:
            return noun_rank


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
