"""Scalar extension and homogeneous result assembly for atomic real verbs."""
from std.collections import List
from .nouns import Noun, NounDType, VECTOR_RANK, agreement_length, agreed_atom, agreement_dims
from ._verb_base import Verb, ATOM_RANK, _numeric_int


def _empty(dtype: NounDType) -> Noun:
    var result = Noun(False)
    result.rank = VECTOR_RANK
    result.dtype = dtype
    return result^


def _append(mut result: Noun, item: Noun) raises:
    if not item.is_scalar():
        raise Error("atomic verb must return a scalar per cell")
    if result.length() == 0:
        result.dtype = item.dtype
    if item.dtype == NounDType.FLOAT64 and result.dtype != NounDType.FLOAT64:
        result.float_values = result.as_floats()
        result.int_values = List[Int]()
        result.bool_values = List[Bool]()
        result.dtype = NounDType.FLOAT64
    if item.dtype == NounDType.INT and result.dtype == NounDType.BOOL:
        for index in range(len(result.bool_values)):
            result.int_values.append(Int(result.bool_values[index]))
        result.bool_values = List[Bool]()
        result.dtype = NounDType.INT
    if result.dtype == NounDType.FLOAT64:
        result.float_values.append(item.as_float())
    elif result.dtype == NounDType.INT:
        result.int_values.append(_numeric_int(item))
    else:
        result.bool_values.append(item.as_bool())


trait AtomicKernel(Verb):
    @staticmethod
    def scalar_monad(y: Noun) raises -> Noun:
        raise Error("unsupported monad")
    @staticmethod
    def scalar_dyad(x: Noun, y: Noun) raises -> Noun:
        raise Error("unsupported dyad")
    @staticmethod
    def monad_dtype(y: NounDType) raises -> NounDType:
        raise Error("unsupported monad")
    @staticmethod
    def dyad_dtype(x: NounDType, y: NounDType) raises -> NounDType:
        raise Error("unsupported dyad")
    @staticmethod
    def monad_rank() -> Int:
        return ATOM_RANK
    @staticmethod
    def left_rank() -> Int:
        return ATOM_RANK
    @staticmethod
    def right_rank() -> Int:
        return ATOM_RANK
    @staticmethod
    def monad(y: Noun) raises -> Noun:
        return atomic_monad[Self](y)
    @staticmethod
    def dyad(x: Noun, y: Noun) raises -> Noun:
        return atomic_dyad[Self](x, y)


def atomic_monad[Op: AtomicKernel](y: Noun) raises -> Noun:
    if y.is_scalar():
        return Op.scalar_monad(y)
    var result = _empty(Op.monad_dtype(y.dtype))
    for i in range(y.length()):
        _append(result, Op.scalar_monad(y.at(i)))
    if y.rank > 1:
        result.set_shape(y.dims())
    return result^


def atomic_dyad[Op: AtomicKernel](x: Noun, y: Noun) raises -> Noun:
    if x.is_scalar() and y.is_scalar():
        return Op.scalar_dyad(x, y)
    var size = agreement_length(x, y)
    var result = _empty(Op.dyad_dtype(x.dtype, y.dtype))
    for i in range(size):
        _append(result, Op.scalar_dyad(agreed_atom(x, y, i), agreed_atom(y, x, i)))
    if x.rank > 1 or y.rank > 1:
        result.set_shape(agreement_dims(x, y))
    return result^
