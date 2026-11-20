"""Bounded J parse-table subset, evaluated only at compile time.

Words normalize to the same terms as symbols. Reductions build syntax nodes;
no user noun sentence is executed by the parser.
"""
from std.collections import List
from std.math import isinf, round
from std.memory import bitcast

from .modifiers import MAX_REPEAT_COUNT
from .predicates import tolerant_equal


struct Part(ImplicitlyCopyable, Equatable):
    var code: Int

    def __init__(out self, code: Int):
        self.code = code

    comptime MARK = Self(0)
    comptime VERB = Self(1)
    comptime NOUN = Self(2)
    comptime ADVERB = Self(3)
    comptime CONJUNCTION = Self(4)
    comptime OPEN = Self(5)
    comptime CLOSE = Self(6)

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return not self == other


struct Kind(ImplicitlyCopyable, Equatable):
    var code: Int

    def __init__(out self, code: Int):
        self.code = code

    comptime RIGHT = Self(0)
    comptime LEFT = Self(1)
    comptime PLUS = Self(2)
    comptime MINUS = Self(3)
    comptime TIMES = Self(4)
    comptime DIVIDE = Self(5)
    comptime SQUARE = Self(6)
    comptime DOUBLE = Self(7)
    comptime SQRT = Self(8)
    comptime TALLY = Self(9)
    comptime CAP = Self(10)
    comptime LITERAL = Self(11)
    comptime INSERT = Self(12)
    comptime COMPOSE = Self(13)
    comptime ATOP = Self(14)
    comptime BIND = Self(15)
    comptime HOOK = Self(16)
    comptime FORK = Self(17)
    comptime BIND_LEFT = Self(18)
    comptime BIND_RIGHT = Self(19)
    comptime CONSTANT = Self(20)
    comptime MONAD = Self(21)
    comptime DYAD = Self(22)
    comptime EQUAL = Self(23)
    comptime UNEQUAL = Self(24)
    comptime LESS = Self(25)
    comptime GREATER = Self(26)
    comptime LESS_EQUAL = Self(27)
    comptime GREATER_EQUAL = Self(28)
    comptime MATCH_HALVE = Self(29)
    comptime COMPLEMENT = Self(30)
    comptime OR = Self(31)
    comptime AND = Self(32)
    comptime FLOOR_MIN = Self(33)
    comptime CEILING_MAX = Self(34)
    comptime MAGNITUDE_RESIDUE = Self(35)
    comptime POWER = Self(36)
    comptime LOGARITHM = Self(37)
    comptime CIRCLE = Self(38)
    comptime BOND_VERBS = Self(39)
    comptime REFLEX = Self(40)
    comptime SHAPE_RESHAPE = Self(41)
    comptime IOTA = Self(42)
    comptime RAVEL_APPEND = Self(43)
    comptime STITCH = Self(44)
    comptime LAMINATE = Self(45)
    comptime GATHER = Self(46)
    comptime HEAD = Self(47)
    comptime TAIL = Self(48)
    comptime DROP = Self(49)
    comptime CURTAIL = Self(50)
    comptime REVERSE_ROTATE = Self(51)
    comptime TRANSPOSE = Self(52)
    comptime RANK = Self(53)
    comptime PREFIX = Self(54)
    comptime SUFFIX = Self(55)
    comptime DOT = Self(56)
    comptime REPEAT = Self(57)

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return not self == other


struct NumberKind(ImplicitlyCopyable, Equatable):
    var code: Int

    def __init__(out self, code: Int):
        self.code = code

    comptime BOOLEAN = Self(0)
    comptime INTEGER = Self(1)
    comptime REAL = Self(2)

    def __eq__(self, other: Self) -> Bool:
        return self.code == other.code

    def __ne__(self, other: Self) -> Bool:
        return not self == other


struct Number(ImplicitlyCopyable):
    var kind: NumberKind
    var integer: Int
    var real: Float64

    def __init__(out self, kind: NumberKind, integer: Int, real: Float64):
        self.kind = kind
        self.integer = integer
        self.real = real


struct Node(ImplicitlyCopyable):
    var kind: Kind
    var position: Int
    var a: Int
    var b: Int
    var c: Int
    var depth: Int

    def __init__(out self, kind: Kind, position: Int, a: Int = 0, b: Int = 0, c: Int = 0, depth: Int = 0):
        self.kind = kind
        self.position = position
        self.a = a
        self.b = b
        self.c = c
        self.depth = depth


struct Term(ImplicitlyCopyable):
    var part: Part
    var node: Int
    var kind: Kind
    var position: Int

    def __init__(out self, part: Part, position: Int = 0, node: Int = 0, kind: Kind = Kind.RIGHT):
        self.part = part
        self.node = node
        self.kind = kind
        self.position = position


def _digit(ch: Int) -> Bool:
    return ch >= 48 and ch <= 57


def _letter(ch: Int) -> Bool:
    return (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122)


def _space(ch: Int) -> Bool:
    return ch == 32 or ch == 9 or ch == 10 or ch == 13


def _vn(part: Part) -> Bool:
    return part == Part.VERB or part == Part.NOUN


def _edge(part: Part) -> Bool:
    return part == Part.MARK or part == Part.OPEN


def _edge_avn(part: Part) -> Bool:
    return _edge(part) or _vn(part) or part == Part.ADVERB


struct Syntax:
    var source: String
    var position: Int
    var nodes: List[Node]
    var numbers: List[Number]
    var tokens: List[Term]
    var stack: List[Term]
    var root: Int
    var part: Part
    var error: String

    def __init__(out self, var source: String):
        self.source = source^
        self.position = 0
        self.nodes = [Node(Kind.RIGHT, 0)]
        self.numbers = List[Number]()
        self.tokens = [Term(Part.MARK)]
        self.stack = [Term(Part.MARK), Term(Part.MARK), Term(Part.MARK), Term(Part.MARK)]
        self.root = 0
        self.part = Part.VERB
        self.error = ""

    def byte(self, index: Int) -> Int:
        if index < 0 or index >= self.source.byte_length():
            return -1
        return Int(self.source.as_bytes()[index])

    def skip(mut self):
        while _space(self.byte(self.position)):
            self.position += 1

    def fail(mut self, position: Int, message: String):
        if self.error == "":
            self.error = "Mojj syntax at byte " + String(position) + ": " + message

    def add(mut self, kind: Kind, position: Int, a: Int = 0, b: Int = 0, c: Int = 0) -> Int:
        if self.error != "":
            return 0
        if len(self.nodes) >= 65:
            self.fail(position, "expression exceeds 64 AST nodes")
            return 0
        var depth = 0
        if kind != Kind.LITERAL:
            depth = max(self.nodes[a].depth, max(self.nodes[b].depth, self.nodes[c].depth))
            if a != 0 or b != 0 or c != 0:
                depth += 1
        if depth > 16:
            self.fail(position, "expression nesting exceeds 16 levels")
            return 0
        self.nodes.append(Node(kind, position, a, b, c, depth))
        return len(self.nodes) - 1

    def verb(mut self, kind: Kind, position: Int):
        var node = self.add(kind, position)
        self.tokens.append(Term(Part.VERB, position, node, kind))

    def derived(mut self, mean: Bool, position: Int):
        var plus = self.add(Kind.PLUS, position)
        var insert = self.add(Kind.INSERT, position, plus)
        var result = insert
        if mean:
            var divide = self.add(Kind.DIVIDE, position)
            var tally = self.add(Kind.TALLY, position)
            result = self.add(Kind.FORK, position, insert, divide, tally)
        self.tokens.append(Term(Part.VERB, position, result))

    def bound_circle(mut self, selector: Int, position: Int):
        var number = len(self.numbers)
        var kind = NumberKind.INTEGER
        if selector == 1:
            kind = NumberKind.BOOLEAN
        self.numbers.append(Number(kind, selector, Float64(selector)))
        var left = self.add(Kind.LITERAL, position, number, 1)
        var right = self.add(Kind.CIRCLE, position)
        var result = self.add(Kind.BIND_LEFT, position, left, right)
        self.tokens.append(Term(Part.VERB, position, result))

    def dot(mut self, position: Int):
        var plus = self.add(Kind.PLUS, position)
        var insert = self.add(Kind.INSERT, position, plus)
        var times = self.add(Kind.TIMES, position)
        var result = self.add(Kind.DOT, position, insert, times)
        self.tokens.append(Term(Part.VERB, position, result))

    def number_start(self) -> Bool:
        var ch = self.byte(self.position)
        return (
            _digit(ch)
            or ch == 95
            or (ch == 46 and _digit(self.byte(self.position + 1)))
        )

    def number(mut self):
        var start = self.position
        var negative = self.byte(self.position) == 95
        if negative:
            self.position += 1
            var next = self.byte(self.position)
            if not _digit(next) and next != 46:
                var infinity = bitcast[DType.float64](
                    UInt64(0x7FF0000000000000)
                )
                if next == 95:
                    self.position += 1
                    infinity = -infinity
                var after = self.byte(self.position)
                if _letter(after) or _digit(after) or after == 95:
                    self.fail(start, "invalid infinity literal")
                self.numbers.append(Number(NumberKind.REAL, 0, infinity))
                return
        # Accumulate integer magnitudes negatively to include Int.MIN exactly.
        var integer: Int = 0
        var real: Float64 = 0.0
        var overflow = False
        var digits = 0
        while _digit(self.byte(self.position)):
            var digit = self.byte(self.position) - 48
            if integer < -922337203685477580 or (
                integer == -922337203685477580 and digit > 7 + Int(negative)
            ):
                overflow = True
            if not overflow:
                integer = integer * 10 - digit
            real = real * 10.0 + Float64(digit)
            self.position += 1
            digits += 1
        if not overflow:
            # Convert the integer part once to avoid rounding each decimal digit.
            real = -Float64(integer)
        var is_real = False
        if self.byte(self.position) == 46:
            is_real = True
            self.position += 1
            var factor: Float64 = 0.1
            while _digit(self.byte(self.position)):
                real += Float64(self.byte(self.position) - 48) * factor
                factor *= 0.1
                self.position += 1
                digits += 1
        if digits == 0:
            self.fail(start, "invalid numeric literal")
        if self.byte(self.position) == 101 or self.byte(self.position) == 69:
            is_real = True
            self.position += 1
            var exponent_negative = (
                self.byte(self.position) == 95 or self.byte(self.position) == 45
            )
            if exponent_negative or self.byte(self.position) == 43:
                self.position += 1
            var exponent = 0
            var exponent_digits = 0
            while _digit(self.byte(self.position)):
                exponent = min(
                    309, exponent * 10 + self.byte(self.position) - 48
                )
                exponent_digits += 1
                self.position += 1
            if exponent_digits == 0 or exponent > 308:
                self.fail(
                    start, "numeric exponent must be between -308 and 308"
                )
            for _ in range(exponent):
                if exponent_negative:
                    real /= 10.0
                else:
                    real *= 10.0
        if not negative:
            integer = -integer
        else:
            real = -real
        if is_real:
            if isinf(real):
                self.fail(start, "finite numeric literal exceeds Float64 range")
            self.numbers.append(Number(NumberKind.REAL, 0, real))
        else:
            if overflow:
                self.fail(start, "integer literal exceeds Int64 range")
            var kind = NumberKind.INTEGER
            if integer == 0 or integer == 1:
                kind = NumberKind.BOOLEAN
            self.numbers.append(Number(kind, integer, Float64(integer)))

    def noun(mut self):
        var position = self.position
        var start = len(self.numbers)
        self.number()
        var end = self.position
        self.skip()
        while self.error == "" and self.position > end and self.number_start():
            self.number()
            end = self.position
            self.skip()
        var count = len(self.numbers) - start
        var node = self.add(Kind.LITERAL, position, start, count)
        if count == 1 and self.byte(end) == 58:
            self.position = end + 1
            node = self.add(Kind.CONSTANT, position, node)
            self.tokens.append(Term(Part.VERB, position, node))
        else:
            self.tokens.append(Term(Part.NOUN, position, node))

    def tokenize(mut self):
        var nesting = 0
        while self.error == "":
            self.skip()
            var start = self.position
            var ch = self.byte(start)
            if ch == -1:
                break
            if self.number_start():
                self.noun()
                continue
            self.position += 1
            if (ch == 105 or ch == 111) and self.byte(self.position) == 46:
                self.position += 1
                self.verb(Kind.IOTA if ch == 105 else Kind.CIRCLE, start)
                continue
            if _letter(ch):
                var word = String(chr(ch))
                while (
                    _letter(self.byte(self.position))
                    or _digit(self.byte(self.position))
                    or self.byte(self.position) == 95
                ):
                    word += String(chr(self.byte(self.position)))
                    self.position += 1
                if word == "group":
                    ch = 40
                elif word == "end":
                    ch = 41
                elif word == "of":
                    self.tokens.append(
                        Term(Part.CONJUNCTION, start, kind=Kind.COMPOSE)
                    )
                    continue
                elif word == "atop":
                    self.tokens.append(
                        Term(Part.CONJUNCTION, start, kind=Kind.ATOP)
                    )
                    continue
                elif word == "bind":
                    self.tokens.append(
                        Term(Part.CONJUNCTION, start, kind=Kind.BIND)
                    )
                    continue
                elif word == "insert" or word == "table":
                    self.tokens.append(
                        Term(Part.ADVERB, start, kind=Kind.INSERT)
                    )
                    continue
                elif word == "reflex":
                    self.tokens.append(
                        Term(Part.ADVERB, start, kind=Kind.REFLEX)
                    )
                    continue
                elif word == "rank":
                    self.tokens.append(
                        Term(Part.CONJUNCTION, start, kind=Kind.RANK)
                    )
                    continue
                elif word == "repeat":
                    self.tokens.append(
                        Term(Part.CONJUNCTION, start, kind=Kind.REPEAT)
                    )
                    continue
                elif word == "prefix" or word == "infix" or word == "scan":
                    self.tokens.append(
                        Term(Part.ADVERB, start, kind=Kind.PREFIX)
                    )
                    continue
                elif word == "suffix" or word == "outfix":
                    self.tokens.append(
                        Term(Part.ADVERB, start, kind=Kind.SUFFIX)
                    )
                    continue
                elif word == "dot":
                    self.dot(start)
                    continue
                elif word == "mean" or word == "sum":
                    self.derived(word == "mean", start)
                    continue
                elif word == "sin":
                    self.bound_circle(1, start)
                    continue
                elif word == "cos":
                    self.bound_circle(2, start)
                    continue
                else:
                    var kind = Kind.RIGHT
                    if word == "identity" or word == "right":
                        kind = Kind.RIGHT
                    elif word == "left":
                        kind = Kind.LEFT
                    elif word == "plus":
                        kind = Kind.PLUS
                    elif word == "minus" or word == "negate":
                        kind = Kind.MINUS
                    elif word == "times":
                        kind = Kind.TIMES
                    elif word == "divide":
                        kind = Kind.DIVIDE
                    elif word == "square" or word == "nand":
                        kind = Kind.SQUARE
                    elif word == "double" or word == "nor":
                        kind = Kind.DOUBLE
                    elif word == "sqrt" or word == "root":
                        kind = Kind.SQRT
                    elif word == "tally" or word == "copy" or word == "filter":
                        kind = Kind.TALLY
                    elif word == "cap":
                        kind = Kind.CAP
                    elif word == "equal" or word == "eq":
                        kind = Kind.EQUAL
                    elif word == "unequal" or word == "ne":
                        kind = Kind.UNEQUAL
                    elif word == "less" or word == "lt":
                        kind = Kind.LESS
                    elif word == "greater" or word == "gt":
                        kind = Kind.GREATER
                    elif (
                        word == "less_equal"
                        or word == "decrement"
                        or word == "le"
                    ):
                        kind = Kind.LESS_EQUAL
                    elif (
                        word == "greater_equal"
                        or word == "increment"
                        or word == "ge"
                    ):
                        kind = Kind.GREATER_EQUAL
                    elif word == "match" or word == "halve":
                        kind = Kind.MATCH_HALVE
                    elif word == "complement" or word == "not":
                        kind = Kind.COMPLEMENT
                    elif word == "or":
                        kind = Kind.OR
                    elif word == "and":
                        kind = Kind.AND
                    elif word == "floor" or word == "min" or word == "minimum":
                        kind = Kind.FLOOR_MIN
                    elif (
                        word == "ceiling"
                        or word == "ceil"
                        or word == "max"
                        or word == "maximum"
                    ):
                        kind = Kind.CEILING_MAX
                    elif word == "abs" or word == "residue":
                        kind = Kind.MAGNITUDE_RESIDUE
                    elif word == "power" or word == "pow":
                        kind = Kind.POWER
                    elif word == "logarithm" or word == "log":
                        kind = Kind.LOGARITHM
                    elif word == "circle":
                        kind = Kind.CIRCLE
                    elif word == "shape" or word == "reshape":
                        kind = Kind.SHAPE_RESHAPE
                    elif word == "iota":
                        kind = Kind.IOTA
                    elif word == "ravel" or word == "append":
                        kind = Kind.RAVEL_APPEND
                    elif word == "stitch":
                        kind = Kind.STITCH
                    elif word == "laminate":
                        kind = Kind.LAMINATE
                    elif word == "gather":
                        kind = Kind.GATHER
                    elif word == "head" or word == "take":
                        kind = Kind.HEAD
                    elif word == "tail":
                        kind = Kind.TAIL
                    elif word == "drop" or word == "behead":
                        kind = Kind.DROP
                    elif word == "curtail":
                        kind = Kind.CURTAIL
                    elif word == "reverse" or word == "rotate":
                        kind = Kind.REVERSE_ROTATE
                    elif word == "transpose":
                        kind = Kind.TRANSPOSE
                    else:
                        self.fail(start, "unknown word '" + word + "'")
                    self.verb(kind, start)
                    continue
            if ch == 40 or ch == 41:
                var part = Part.OPEN
                if ch == 40:
                    nesting += 1
                    if nesting > 16:
                        self.fail(start, "expression nesting exceeds 16 levels")
                else:
                    part = Part.CLOSE
                    nesting -= 1
                    if nesting < 0:
                        self.fail(start, "unexpected closing group")
                self.tokens.append(Term(part, start))
            elif ch == 64:
                var kind = Kind.ATOP
                if self.byte(self.position) == 58:
                    kind = Kind.COMPOSE
                    self.position += 1
                self.tokens.append(Term(Part.CONJUNCTION, start, kind=kind))
            elif ch == 38:
                self.tokens.append(
                    Term(Part.CONJUNCTION, start, kind=Kind.BIND)
                )
            elif ch == 47:
                self.tokens.append(Term(Part.ADVERB, start, kind=Kind.INSERT))
            elif ch == 92:
                var kind = Kind.PREFIX
                if self.byte(self.position) == 46:
                    self.position += 1
                    kind = Kind.SUFFIX
                self.tokens.append(Term(Part.ADVERB, start, kind=kind))
            elif ch == 34:
                self.tokens.append(
                    Term(Part.CONJUNCTION, start, kind=Kind.RANK)
                )
            elif ch == 94 and self.byte(self.position) == 58:
                self.position += 1
                self.tokens.append(
                    Term(Part.CONJUNCTION, start, kind=Kind.REPEAT)
                )
            elif ch == 46:
                self.tokens.append(Term(Part.CONJUNCTION, start, kind=Kind.DOT))
            elif ch == 126 and self.byte(self.position) != 58:
                self.tokens.append(Term(Part.ADVERB, start, kind=Kind.REFLEX))
            else:
                var kind = Kind.RIGHT
                var colon = self.byte(self.position) == 58
                var dot = self.byte(self.position) == 46
                if ch == 43:
                    kind = Kind.PLUS
                    if colon:
                        kind = Kind.DOUBLE
                        self.position += 1
                    elif dot:
                        kind = Kind.OR
                        self.position += 1
                elif ch == 45:
                    kind = Kind.MINUS
                    if colon:
                        kind = Kind.MATCH_HALVE
                        self.position += 1
                    elif dot:
                        kind = Kind.COMPLEMENT
                        self.position += 1
                elif ch == 42:
                    kind = Kind.TIMES
                    if colon:
                        kind = Kind.SQUARE
                        self.position += 1
                    elif dot:
                        kind = Kind.AND
                        self.position += 1
                elif ch == 37:
                    kind = Kind.DIVIDE
                    if colon:
                        kind = Kind.SQRT
                        self.position += 1
                elif ch == 35:
                    kind = Kind.TALLY
                elif ch == 91:
                    kind = Kind.LEFT
                    if colon:
                        kind = Kind.CAP
                        self.position += 1
                elif ch == 93:
                    kind = Kind.RIGHT
                elif ch == 61:
                    kind = Kind.EQUAL
                elif ch == 126:
                    kind = Kind.UNEQUAL
                    self.position += 1
                elif ch == 60:
                    kind = Kind.LESS
                    if colon:
                        kind = Kind.LESS_EQUAL
                        self.position += 1
                    elif dot:
                        kind = Kind.FLOOR_MIN
                        self.position += 1
                elif ch == 62:
                    kind = Kind.GREATER
                    if colon:
                        kind = Kind.GREATER_EQUAL
                        self.position += 1
                    elif dot:
                        kind = Kind.CEILING_MAX
                        self.position += 1
                elif ch == 124:
                    kind = Kind.MAGNITUDE_RESIDUE
                    if dot:
                        kind = Kind.REVERSE_ROTATE
                        self.position += 1
                    elif colon:
                        kind = Kind.TRANSPOSE
                        self.position += 1
                elif ch == 36:
                    kind = Kind.SHAPE_RESHAPE
                elif ch == 44:
                    kind = Kind.RAVEL_APPEND
                    if dot:
                        kind = Kind.STITCH
                        self.position += 1
                    elif colon:
                        kind = Kind.LAMINATE
                        self.position += 1
                elif ch == 123:
                    kind = Kind.GATHER
                    if dot:
                        kind = Kind.HEAD
                        self.position += 1
                    elif colon:
                        kind = Kind.TAIL
                        self.position += 1
                elif ch == 125 and (dot or colon):
                    kind = Kind.DROP if dot else Kind.CURTAIL
                    self.position += 1
                elif ch == 94:
                    kind = Kind.POWER
                    if dot:
                        kind = Kind.LOGARITHM
                        self.position += 1
                else:
                    self.fail(start, "unsupported token")
                self.verb(kind, start)
        if nesting != 0:
            self.fail(self.position, "unclosed group")

    def top(self, offset: Int) -> Term:
        return self.stack[len(self.stack) - 1 - offset]

    def replace(mut self, offset: Int, count: Int, result: Term):
        var next = List[Term]()
        var first = len(self.stack) - offset - count
        var last = len(self.stack) - offset
        for index in range(len(self.stack)):
            if index == first:
                next.append(result)
            if index < first or index >= last:
                next.append(self.stack[index])
        self.stack = next^

    def is_cap(self, term: Term) -> Bool:
        return term.part == Part.VERB and self.nodes[term.node].kind == Kind.CAP

    def valid_rank_operand(self, term: Term) -> Bool:
        if term.part != Part.NOUN:
            return False
        var literal = self.nodes[term.node]
        if literal.kind != Kind.LITERAL or literal.b < 1 or literal.b > 3:
            return False
        for index in range(literal.b):
            var number = self.numbers[literal.a + index]
            if number.kind != NumberKind.REAL or isinf(number.real):
                continue
            var nearest = round(number.real)
            if not (
                nearest >= Float64(Int.MIN)
                and nearest < Float64(Int.MAX)
                and tolerant_equal(nearest, number.real)
            ):
                return False
        return True

    def rank_value(self, literal_node: Int, slot: Int) -> Int:
        # Unselected lowering candidates have no rank literal.
        var literal = self.nodes[literal_node]
        if literal.kind != Kind.LITERAL or literal.b < 1 or literal.b > 3:
            return 0
        var index = slot
        if literal.b == 1:
            index = 0
        elif literal.b == 2:
            index = 0 if slot == 1 else 1
        var number = self.numbers[literal.a + index]
        if number.kind != NumberKind.REAL:
            return number.integer
        if isinf(number.real):
            return Int.MAX if number.real > 0.0 else Int.MIN
        var nearest = round(number.real)
        if nearest >= Float64(Int.MIN) and nearest < Float64(Int.MAX):
            return Int(nearest)
        return 0

    def repeat_count(self, literal_node: Int) -> Int:
        var literal = self.nodes[literal_node]
        if literal.kind == Kind.LITERAL and literal.b == 1:
            var number = self.numbers[literal.a]
            if number.kind != NumberKind.REAL:
                return number.integer
        return -1

    def supported_dot(self, left: Term, right: Term) -> Bool:
        if left.part != Part.VERB or right.part != Part.VERB:
            return False
        var reduction = self.nodes[left.node]
        return (
            reduction.kind == Kind.INSERT
            and self.nodes[reduction.a].kind == Kind.PLUS
            and self.nodes[right.node].kind == Kind.TIMES
        )

    def reduce_once(mut self) -> Bool:
        var p = self.top(0)
        var q = self.top(1)
        var r = self.top(2)
        var s = self.top(3)
        # Rule order is significant: these are the retained rows of J's table.
        if _edge(p.part) and q.part == Part.VERB and r.part == Part.NOUN:
            if self.is_cap(q):
                self.fail(
                    q.position,
                    "cap is only supported as the left verb of a fork",
                )
            var node = self.add(Kind.MONAD, q.position, q.node, r.node)
            self.replace(1, 2, Term(Part.NOUN, q.position, node))
        elif (
            _edge_avn(p.part)
            and q.part == Part.VERB
            and r.part == Part.VERB
            and s.part == Part.NOUN
        ):
            if self.is_cap(r):
                self.fail(
                    r.position,
                    "cap is only supported as the left verb of a fork",
                )
            var node = self.add(Kind.MONAD, r.position, r.node, s.node)
            self.replace(2, 2, Term(Part.NOUN, r.position, node))
        elif (
            _edge_avn(p.part)
            and q.part == Part.NOUN
            and r.part == Part.VERB
            and s.part == Part.NOUN
        ):
            if self.is_cap(r):
                self.fail(
                    r.position,
                    "cap is only supported as the left verb of a fork",
                )
            var node = self.add(Kind.DYAD, r.position, r.node, q.node, s.node)
            self.replace(1, 3, Term(Part.NOUN, r.position, node))
        elif _edge_avn(p.part) and _vn(q.part) and r.part == Part.ADVERB:
            if q.part != Part.VERB or self.is_cap(q):
                if r.kind == Kind.INSERT:
                    self.fail(r.position, "insertion requires a supported verb")
                elif r.kind == Kind.REFLEX:
                    self.fail(r.position, "reflex requires a supported verb")
                else:
                    self.fail(
                        r.position, "prefix or suffix requires a supported verb"
                    )
            var node = self.add(r.kind, r.position, q.node)
            self.replace(1, 2, Term(Part.VERB, r.position, node))
        elif (
            _edge_avn(p.part)
            and _vn(q.part)
            and r.part == Part.CONJUNCTION
            and _vn(s.part)
        ):
            var kind = r.kind
            if kind == Kind.BIND:
                if q.part == Part.NOUN and s.part == Part.VERB:
                    kind = Kind.BIND_LEFT
                elif q.part == Part.VERB and s.part == Part.NOUN:
                    kind = Kind.BIND_RIGHT
                elif q.part == Part.VERB and s.part == Part.VERB:
                    kind = Kind.BOND_VERBS
                else:
                    self.fail(r.position, "bond requires at least one verb")
            elif kind == Kind.RANK:
                if q.part != Part.VERB or not self.valid_rank_operand(s):
                    self.fail(
                        r.position,
                        (
                            "rank requires a verb and one to three integer rank"
                            " literals"
                        ),
                    )
            elif kind == Kind.REPEAT:
                var count = self.repeat_count(s.node)
                if q.part != Part.VERB or count < 0 or count > MAX_REPEAT_COUNT:
                    self.fail(
                        r.position,
                        "repeat requires a verb and a nonnegative integer literal"
                        " count at most " + String(MAX_REPEAT_COUNT),
                    )
            elif kind == Kind.DOT:
                if not self.supported_dot(q, s):
                    self.fail(
                        r.position,
                        "dot requires +/ on the left and * on the right",
                    )
            elif q.part != Part.VERB or s.part != Part.VERB:
                self.fail(r.position, "composition requires two verbs")
            if self.is_cap(q) or self.is_cap(s):
                self.fail(
                    r.position,
                    "cap is only supported as the left verb of a fork",
                )
            var node = self.add(kind, r.position, q.node, s.node)
            self.replace(1, 3, Term(Part.VERB, r.position, node))
        elif (
            _edge_avn(p.part)
            and _vn(q.part)
            and r.part == Part.VERB
            and s.part == Part.VERB
        ):
            var node: Int
            if self.is_cap(r) or self.is_cap(s):
                self.fail(
                    r.position,
                    "cap is only supported as the left verb of a fork",
                )
            if self.is_cap(q):
                node = self.add(Kind.COMPOSE, q.position, r.node, s.node)
            else:
                var left = q.node
                if q.part == Part.NOUN:
                    left = self.add(Kind.CONSTANT, q.position, q.node)
                node = self.add(Kind.FORK, q.position, left, r.node, s.node)
            self.replace(1, 3, Term(Part.VERB, q.position, node))
        elif _edge(p.part) and q.part == Part.VERB and r.part == Part.VERB:
            if self.is_cap(q) or self.is_cap(r):
                self.fail(
                    q.position,
                    "cap is only supported as the left verb of a fork",
                )
            var node = self.add(Kind.HOOK, q.position, q.node, r.node)
            self.replace(1, 2, Term(Part.VERB, q.position, node))
        elif p.part == Part.OPEN and _vn(q.part) and r.part == Part.CLOSE:
            self.replace(0, 3, q)
        else:
            return False
        return True

    def parse(mut self):
        if self.source.byte_length() > 512:
            self.fail(512, "expression exceeds 512 ASCII bytes")
            return
        for index in range(self.source.byte_length()):
            if self.byte(index) > 127:
                self.fail(index, "only ASCII syntax is supported")
                return
        self.tokenize()
        if len(self.tokens) == 1:
            self.fail(0, "expected an expression")
        var next = len(self.tokens) - 1
        while self.error == "":
            if self.reduce_once():
                continue
            if next < 0:
                break
            self.stack.append(self.tokens[next])
            next -= 1
        if self.error != "":
            return
        if len(self.stack) != 6 or self.top(0).part != Part.MARK or not _vn(self.top(1).part):
            self.fail(self.top(1).position, "incomplete or unsupported J phrase")
            return
        var result = self.top(1)
        if self.is_cap(result):
            self.fail(result.position, "cap is only supported as the left verb of a fork")
            return
        self.root = result.node
        self.part = result.part


def parse(var source: String) -> Syntax:
    var result = Syntax(source^)
    result.parse()
    return result^
