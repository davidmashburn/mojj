"""Small, value-owned nouns for the typed J semantic core.

The first semantic slice deliberately models atoms and one-dimensional vectors
only.  A noun keeps its element dtype and rank explicit; verbs are responsible
for applying the scalar-extension/vector-agreement rules exposed below.
"""

from std.collections import List


comptime SCALAR_RANK = 0
comptime VECTOR_RANK = 1


struct NounDType(ImplicitlyCopyable, Equatable):
    """The exact element type carried by a :class:`Noun`."""

    var tag: Int

    def __init__(out self, tag: Int):
        self.tag = tag

    def __eq__(self, other: Self) -> Bool:
        return self.tag == other.tag

    def __ne__(self, other: Self) -> Bool:
        return not self == other

    def describe(self) -> String:
        if self == Self.INT:
            return "Int"
        if self == Self.FLOAT64:
            return "Float64"
        return "Bool"

    comptime INT = Self(0)
    comptime FLOAT64 = Self(1)
    comptime BOOL = Self(2)


struct Noun:
    """A copyable scalar or vector with exact Int/Float64/Bool storage.

    Scalars have rank ``SCALAR_RANK`` and length one.  Vectors have rank
    ``VECTOR_RANK`` and may be empty.  The inactive storage fields are kept
    initialized so ordinary struct value semantics remain sufficient for
    copying a noun.
    """

    var rank: Int
    var dtype: NounDType

    var int_value: Int
    var float_value: Float64
    var bool_value: Bool

    var int_values: List[Int]
    var float_values: List[Float64]
    var bool_values: List[Bool]

    def __init__(out self, value: Int):
        self.rank = SCALAR_RANK
        self.dtype = NounDType.INT
        self.int_value = value
        self.float_value = 0.0
        self.bool_value = False
        self.int_values = List[Int]()
        self.float_values = List[Float64]()
        self.bool_values = List[Bool]()

    def __init__(out self, value: Float64):
        self.rank = SCALAR_RANK
        self.dtype = NounDType.FLOAT64
        self.int_value = 0
        self.float_value = value
        self.bool_value = False
        self.int_values = List[Int]()
        self.float_values = List[Float64]()
        self.bool_values = List[Bool]()

    def __init__(out self, value: Bool):
        self.rank = SCALAR_RANK
        self.dtype = NounDType.BOOL
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = value
        self.int_values = List[Int]()
        self.float_values = List[Float64]()
        self.bool_values = List[Bool]()

    def __init__(out self, values: List[Int]):
        self.rank = VECTOR_RANK
        self.dtype = NounDType.INT
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = False
        self.int_values = values.copy()
        self.float_values = List[Float64]()
        self.bool_values = List[Bool]()

    def __init__(out self, values: List[Float64]):
        self.rank = VECTOR_RANK
        self.dtype = NounDType.FLOAT64
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = False
        self.int_values = List[Int]()
        self.float_values = values.copy()
        self.bool_values = List[Bool]()

    def __init__(out self, values: List[Bool]):
        self.rank = VECTOR_RANK
        self.dtype = NounDType.BOOL
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = False
        self.int_values = List[Int]()
        self.float_values = List[Float64]()
        self.bool_values = values.copy()

    def is_scalar(self) -> Bool:
        return self.rank == SCALAR_RANK

    def is_vector(self) -> Bool:
        return self.rank == VECTOR_RANK

    def is_int(self) -> Bool:
        return self.dtype == NounDType.INT

    def is_float64(self) -> Bool:
        return self.dtype == NounDType.FLOAT64

    def is_bool(self) -> Bool:
        return self.dtype == NounDType.BOOL

    def length(self) -> Int:
        if self.rank == SCALAR_RANK:
            return 1
        if self.dtype == NounDType.INT:
            return len(self.int_values)
        if self.dtype == NounDType.FLOAT64:
            return len(self.float_values)
        return len(self.bool_values)

    def as_int(self) raises -> Int:
        """Return a scalar integer, rejecting vectors and non-Int dtypes."""
        if self.rank != SCALAR_RANK:
            raise Error("as_int requires a scalar noun")
        if self.dtype != NounDType.INT:
            raise Error("as_int requires an Int noun")
        return self.int_value

    def as_float(self) raises -> Float64:
        """Return a scalar real value, rejecting vectors."""
        if self.rank != SCALAR_RANK:
            raise Error("as_float requires a scalar noun")
        if self.dtype == NounDType.INT:
            return Float64(self.int_value)
        if self.dtype == NounDType.FLOAT64:
            return self.float_value
        if self.bool_value:
            return 1.0
        return 0.0

    def as_bool(self) raises -> Bool:
        """Return a scalar Boolean, rejecting vectors and non-Bool dtypes."""
        if self.rank != SCALAR_RANK:
            raise Error("as_bool requires a scalar noun")
        if self.dtype != NounDType.BOOL:
            raise Error("as_bool requires a Bool noun")
        return self.bool_value

    def as_ints(self) raises -> List[Int]:
        """Return a copied Int vector, rejecting scalar or non-Int nouns."""
        if self.rank != VECTOR_RANK:
            raise Error("as_ints requires a vector noun")
        if self.dtype != NounDType.INT:
            raise Error("as_ints requires an Int vector")
        return self.int_values.copy()

    def as_floats(self) raises -> List[Float64]:
        """Return a copied Float64 vector, rejecting scalar nouns."""
        if self.rank != VECTOR_RANK:
            raise Error("as_floats requires a vector noun")
        var result = List[Float64](length=self.length(), fill=0.0)
        if self.dtype == NounDType.FLOAT64:
            for index in range(len(self.float_values)):
                result[index] = self.float_values[index]
        elif self.dtype == NounDType.INT:
            for index in range(len(self.int_values)):
                result[index] = Float64(self.int_values[index])
        else:
            for index in range(len(self.bool_values)):
                if self.bool_values[index]:
                    result[index] = 1.0
                else:
                    result[index] = 0.0
        return result^

    def as_bools(self) raises -> List[Bool]:
        """Return a copied Boolean vector, rejecting scalar or non-Bool nouns."""
        if self.rank != VECTOR_RANK:
            raise Error("as_bools requires a vector noun")
        if self.dtype != NounDType.BOOL:
            raise Error("as_bools requires a Bool vector")
        return self.bool_values.copy()

    def at(self, index: Int) raises -> Noun:
        """Return one scalar cell without mutating the source noun."""
        if index < 0 or index >= self.length():
            raise Error("noun index out of range")
        if self.rank == SCALAR_RANK:
            return self.copy()
        if self.dtype == NounDType.INT:
            return Noun(self.int_values[index])
        if self.dtype == NounDType.FLOAT64:
            return Noun(self.float_values[index])
        return Noun(self.bool_values[index])

    def copy(self) -> Noun:
        """Return an independent value copy."""
        if self.rank == SCALAR_RANK:
            if self.dtype == NounDType.INT:
                return Noun(self.int_value)
            if self.dtype == NounDType.FLOAT64:
                return Noun(self.float_value)
            return Noun(self.bool_value)
        if self.dtype == NounDType.INT:
            return Noun(self.int_values)
        if self.dtype == NounDType.FLOAT64:
            return Noun(self.float_values)
        return Noun(self.bool_values)

    def describe(self) -> String:
        if self.rank == SCALAR_RANK:
            if self.dtype == NounDType.INT:
                return String(self.int_value)
            if self.dtype == NounDType.FLOAT64:
                return String(self.float_value)
            if self.bool_value:
                return "1"
            return "0"

        var result = ""
        for index in range(self.length()):
            if index > 0:
                result += " "
            if self.dtype == NounDType.INT:
                result += String(self.int_values[index])
            elif self.dtype == NounDType.FLOAT64:
                result += String(self.float_values[index])
            elif self.bool_values[index]:
                result += "1"
            else:
                result += "0"
        return result


def agreement_length(left: Noun, right: Noun) raises -> Int:
    """Return the result length under scalar extension and vector agreement."""
    if left.rank == VECTOR_RANK and right.rank == VECTOR_RANK:
        if left.length() != right.length():
            raise Error(
                "shape agreement failed: vector lengths "
                + String(left.length())
                + " and "
                + String(right.length())
                + " differ"
            )
        return left.length()
    if left.rank == VECTOR_RANK:
        return left.length()
    if right.rank == VECTOR_RANK:
        return right.length()
    return 1


def agreed_at(noun: Noun, index: Int) raises -> Noun:
    """Return the scalar value at an agreed output index."""
    if noun.rank == SCALAR_RANK:
        return noun.copy()
    return noun.at(index)


trait NounProvider:
    """Compile-time provider for a noun used by bound verbs and constants."""

    @staticmethod
    def value() raises -> Noun:
        ...

    @staticmethod
    def describe() -> String:
        ...


struct IntNounProvider[literal: Int](NounProvider):
    """Convenience provider for a scalar integer noun literal."""

    @staticmethod
    def value() raises -> Noun:
        return Noun(Self.literal)

    @staticmethod
    def describe() -> String:
        return String(Self.literal)


struct Float64NounProvider[literal: Float64](NounProvider):
    """Convenience provider for a scalar Float64 noun literal."""

    @staticmethod
    def value() raises -> Noun:
        return Noun(Self.literal)

    @staticmethod
    def describe() -> String:
        return String(Self.literal)
