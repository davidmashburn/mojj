"""Value-owned, homogeneous nouns with row-major storage."""

from std.collections import List


comptime SCALAR_RANK = 0
comptime VECTOR_RANK = 1


struct NounDType(Equatable, ImplicitlyCopyable):
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
    """A scalar or shaped array with exact Int/Float64/Bool storage."""

    var rank: Int
    var dtype: NounDType
    var _dimensions: List[Int]

    var int_value: Int
    var float_value: Float64
    var bool_value: Bool

    var int_values: List[Int]
    var float_values: List[Float64]
    var bool_values: List[Bool]

    def __init__(out self, value: Int):
        self.rank = SCALAR_RANK
        self.dtype = NounDType.INT
        self._dimensions = List[Int]()
        self.int_value = value
        self.float_value = 0.0
        self.bool_value = False
        self.int_values = List[Int]()
        self.float_values = List[Float64]()
        self.bool_values = List[Bool]()

    def __init__(out self, value: Float64):
        self.rank = SCALAR_RANK
        self.dtype = NounDType.FLOAT64
        self._dimensions = List[Int]()
        self.int_value = 0
        self.float_value = value
        self.bool_value = False
        self.int_values = List[Int]()
        self.float_values = List[Float64]()
        self.bool_values = List[Bool]()

    def __init__(out self, value: Bool):
        self.rank = SCALAR_RANK
        self.dtype = NounDType.BOOL
        self._dimensions = List[Int]()
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = value
        self.int_values = List[Int]()
        self.float_values = List[Float64]()
        self.bool_values = List[Bool]()

    def __init__(out self, values: List[Int]):
        self.rank = VECTOR_RANK
        self.dtype = NounDType.INT
        self._dimensions = List[Int]()
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = False
        self.int_values = values.copy()
        self.float_values = List[Float64]()
        self.bool_values = List[Bool]()

    def __init__(out self, values: List[Float64]):
        self.rank = VECTOR_RANK
        self.dtype = NounDType.FLOAT64
        self._dimensions = List[Int]()
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = False
        self.int_values = List[Int]()
        self.float_values = values.copy()
        self.bool_values = List[Bool]()

    def __init__(out self, values: List[Bool]):
        self.rank = VECTOR_RANK
        self.dtype = NounDType.BOOL
        self._dimensions = List[Int]()
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = False
        self.int_values = List[Int]()
        self.float_values = List[Float64]()
        self.bool_values = values.copy()

    @staticmethod
    def from_owned_float64(var values: List[Float64]) -> Noun:
        """Build a Float64 vector noun from a freshly built list without copying.

        This is an internal convenience for evaluators that have just filled a
        result list.  It is not a public ownership escape hatch: callers pass a
        local they no longer use, and the list contents are not shared.
        """
        var noun = Noun(0.0)
        noun.rank = VECTOR_RANK
        noun.float_values = values^
        return noun^

    def is_scalar(self) -> Bool:
        return self.rank == SCALAR_RANK

    def is_vector(self) -> Bool:
        return self.rank == VECTOR_RANK

    def dims(self) -> List[Int]:
        """Return an independent copy of the axis lengths."""
        if self.is_vector():
            return [self.length()]
        return self._dimensions.copy()

    def axis_length(self, axis: Int) raises -> Int:
        if axis < 0 or axis >= self.rank:
            raise Error("noun axis out of range")
        return self._axis_length(axis)

    def _axis_length(self, axis: Int) -> Int:
        if self.is_vector():
            return self.length()
        return self._dimensions[axis]

    def same_shape(self, other: Self) -> Bool:
        if self.rank != other.rank:
            return False
        for axis in range(self.rank):
            if self._axis_length(axis) != other._axis_length(axis):
                return False
        return True

    def with_shape(self, dims: List[Int]) raises -> Self:
        """Copy the noun and reinterpret its storage with the given axes."""
        var result = self.copy()
        result.set_shape(dims)
        return result^

    def set_shape(mut self, dims: List[Int]) raises:
        """Set the axis lengths without changing the atom count or order."""
        if shape_size(dims) != self.length():
            raise Error("shape does not match noun atom count")
        var new_rank = len(dims)
        if self.is_scalar() and new_rank > SCALAR_RANK:
            if self.is_int():
                self.int_values.append(self.int_value)
            elif self.is_float64():
                self.float_values.append(self.float_value)
            else:
                self.bool_values.append(self.bool_value)
        elif not self.is_scalar() and new_rank == SCALAR_RANK:
            if self.is_int():
                self.int_value = self.int_values[0]
                self.int_values = List[Int]()
            elif self.is_float64():
                self.float_value = self.float_values[0]
                self.float_values = List[Float64]()
            else:
                self.bool_value = self.bool_values[0]
                self.bool_values = List[Bool]()
        self.rank = new_rank
        if new_rank > VECTOR_RANK:
            self._dimensions = dims.copy()
        else:
            self._dimensions = List[Int]()

    def is_int(self) -> Bool:
        return self.dtype == NounDType.INT

    def is_float64(self) -> Bool:
        return self.dtype == NounDType.FLOAT64

    def is_bool(self) -> Bool:
        return self.dtype == NounDType.BOOL

    def length(self) -> Int:
        """Return the total atom count across every axis."""
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
        """Return a copy of the flat storage of an Int array."""
        if self.is_scalar():
            raise Error("as_ints requires a vector noun")
        if self.dtype != NounDType.INT:
            raise Error("as_ints requires an Int vector")
        return self.int_values.copy()

    def as_floats(self) raises -> List[Float64]:
        """Return a flat Float64 copy of the atoms of an array."""
        if self.is_scalar():
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
        """Return a copy of the flat storage of a Boolean array."""
        if self.is_scalar():
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
        var result = Noun(False)
        result.rank = self.rank
        result.dtype = self.dtype
        result._dimensions = self._dimensions.copy()
        if self.dtype == NounDType.INT:
            result.int_values = self.int_values.copy()
        elif self.dtype == NounDType.FLOAT64:
            result.float_values = self.float_values.copy()
        else:
            result.bool_values = self.bool_values.copy()
        return result^

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
        if self.rank > VECTOR_RANK:
            for axis in range(self.rank):
                if axis > 0:
                    result += " "
                result += String(self._axis_length(axis))
            result += "$"
            if self.length() == 0:
                result += "0"
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


def shape_size(dims: List[Int]) raises -> Int:
    """Return the validated atom count, including zero-length axes."""
    var has_zero = False
    for index in range(len(dims)):
        var dim = dims[index]
        if dim < 0:
            raise Error("shape axes must be nonnegative")
        has_zero = has_zero or dim == 0
    if has_zero:
        return 0
    var size = 1
    for index in range(len(dims)):
        var dim = dims[index]
        if size > Int.MAX // dim:
            raise Error("shape atom count overflows Int")
        size *= dim
    return size


def _check_agreement(left: Noun, right: Noun) raises:
    for axis in range(min(left.rank, right.rank)):
        var left_dim = left._axis_length(axis)
        var right_dim = right._axis_length(axis)
        if left_dim != right_dim:
            if left.is_vector() and right.is_vector():
                raise Error(
                    "shape agreement failed: vector lengths "
                    + String(left_dim)
                    + " and "
                    + String(right_dim)
                    + " differ"
                )
            raise Error(
                "shape agreement failed: axis "
                + String(axis)
                + " has lengths "
                + String(left_dim)
                + " and "
                + String(right_dim)
            )


def agreement_length(left: Noun, right: Noun) raises -> Int:
    """Return the atom count of the longer of two agreed prefix shapes."""
    _check_agreement(left, right)
    if left.rank >= right.rank:
        return left.length()
    return right.length()


def agreement_dims(left: Noun, right: Noun) raises -> List[Int]:
    """Return the longer shape when the shorter shape matches its prefix."""
    _check_agreement(left, right)
    if left.rank >= right.rank:
        return left.dims()
    return right.dims()


def agreed_atom(noun: Noun, partner: Noun, index: Int) raises -> Noun:
    """Read a flat atom under previously validated prefix agreement."""
    if noun.rank >= partner.rank:
        return noun.at(index)
    var output_length = partner.length()
    if index < 0 or index >= output_length:
        raise Error("noun index out of range")
    if noun.is_scalar():
        return noun.copy()
    var repeat = output_length // noun.length()
    return noun.at(index // repeat)


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
