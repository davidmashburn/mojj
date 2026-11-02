"""Bounded compile-time syntax tree for Mojj expression strings."""

from std.collections import List


def _is_ascii_letter(value: Int) -> Bool:
    return (value >= 65 and value <= 90) or (value >= 97 and value <= 122)


def _is_word_char(value: Int) -> Bool:
    return _is_ascii_letter(value) or (value >= 48 and value <= 57) or value == 95


def _is_space(value: Int) -> Bool:
    return value == 32 or value == 9 or value == 10 or value == 13


struct Node(ImplicitlyCopyable):
    """One bounded syntax node; categories are 0 for scalar and 1 for reduction."""

    var kind: Int
    var left: Int
    var right: Int
    var category: Int
    var position: Int

    def __init__(
        out self,
        kind: Int,
        position: Int,
        left: Int = -1,
        right: Int = -1,
        category: Int = 0,
    ):
        self.kind = kind
        self.position = position
        self.left = left
        self.right = right
        self.category = category


struct Syntax:
    """Mutable parser state held only while a compile-time tree is built."""

    var source: String
    var position: Int
    var nodes: List[Node]
    var root: Int
    var error: String

    def __init__(out self, var source: String):
        self.source = source^
        self.position = 0
        self.nodes = List[Node]()
        # A valid sentinel keeps every error path indexable while the compiler
        # type-checks generic code that is guarded by the parse result.
        self.nodes.append(Node(1, 0))
        self.root = 0
        self.error = ""

    def byte(self, index: Int) -> Int:
        if index < 0 or index >= self.source.byte_length():
            return -1
        return Int(self.source.as_bytes()[index])

    def skip(mut self):
        while _is_space(self.byte(self.position)):
            self.position += 1

    def matches(self, start: Int, end: Int, token: String) -> Bool:
        if start < 0 or end < start or end > self.source.byte_length():
            return False
        if end - start != token.byte_length():
            return False
        for index in range(end - start):
            if self.byte(start + index) != Int(token.as_bytes()[index]):
                return False
        return True

    def word(self, start: Int, token: String) -> Bool:
        var end = start + token.byte_length()
        if not self.matches(start, end, token):
            return False
        # A recognized word cannot be a prefix of another word token.
        return not _is_word_char(self.byte(end))

    def fail(mut self, position: Int, message: String, category: Bool = False):
        if self.error == "":
            var prefix = "Mojj syntax at byte "
            if category:
                prefix = "Mojj category at byte "
            self.error = prefix + String(position) + ": " + message

    def add(mut self, node: Node) -> Int:
        if self.error != "":
            return 0
        # The sentinel is not an AST node. Check before growth so an oversized
        # tree never appends and never needs an invalid child index.
        if len(self.nodes) >= 65:
            self.fail(node.position, "expression exceeds 64 AST nodes")
            return 0
        self.nodes.append(node)
        return len(self.nodes) - 1

    def leaf(mut self, kind: Int, position: Int, category: Int = 0) -> Int:
        return self.add(Node(kind, position, category=category))

    def mean_pattern_end(self, start: Int) -> Int:
        """Return the end of the exact ``(+/ % #)`` mean spelling."""
        var index = start
        while _is_space(self.byte(index)):
            index += 1
        if self.byte(index) != 43 or self.byte(index + 1) != 47:
            return -1
        index += 2
        while _is_space(self.byte(index)):
            index += 1
        if self.byte(index) != 37:
            return -1
        index += 1
        while _is_space(self.byte(index)):
            index += 1
        if self.byte(index) != 35:
            return -1
        index += 1
        while _is_space(self.byte(index)):
            index += 1
        if self.byte(index) != 41:
            return -1
        return index + 1

    def expression(mut self, depth: Int) -> Int:
        # The initial expression starts at depth 0. Every composition or group
        # checks its next depth before recursing, and this guard is retained as
        # the final safety net for every recursive entry.
        if depth > 16:
            self.fail(self.position, "expression nesting exceeds 16 levels")
            return 0

        var left = self.atom(depth)
        if self.error != "":
            return 0
        var atom_end = self.position
        self.skip()

        var operator_position = self.position
        var symbolic = self.byte(self.position) == 64 and self.byte(self.position + 1) == 58
        var verbal = self.word(self.position, "of")
        # Whitespace composes adjacent atoms, but never consumes a group's
        # terminator or turns trailing whitespace into a dangling operator.
        var implicit = (
            self.position > atom_end
            and self.byte(self.position) != -1
            and self.byte(self.position) != 41
            and not self.word(self.position, "end")
        )
        if not symbolic and not verbal and not implicit:
            return left

        if depth + 1 > 16:
            self.fail(operator_position, "expression nesting exceeds 16 levels")
            return 0
        if symbolic or verbal:
            self.position += 2
        var right = self.expression(depth + 1)
        if self.error != "":
            return 0

        # Both reduction operands are rejected before a composition node is
        # grown. The other three category combinations are valid.
        var lhs = self.nodes[left]
        var rhs = self.nodes[right]
        if lhs.category == 1 and rhs.category == 1:
            self.fail(
                operator_position,
                "reduction after reduction is unsupported",
                category=True,
            )
            return 0
        var category = 0
        if lhs.category == 1 or rhs.category == 1:
            category = 1
        return self.add(Node(40, operator_position, left, right, category))

    def atom(mut self, depth: Int) -> Int:
        self.skip()
        var start = self.position
        var value = self.byte(start)
        if value == -1:
            self.fail(start, "expected an expression")
            return 0

        var word_group = self.word(start, "group")
        if value == 40 or word_group:
            if depth + 1 > 16:
                self.fail(start, "expression nesting exceeds 16 levels")
                return 0

            if value == 40:
                var mean_end = self.mean_pattern_end(start + 1)
                if mean_end >= 0:
                    self.position = mean_end
                    return self.leaf(21, start, category=1)
                self.position += 1
            else:
                self.position += 5

            var result = self.expression(depth + 1)
            if self.error != "":
                return 0
            self.skip()
            if value == 40:
                if self.byte(self.position) != 41:
                    self.fail(self.position, "expected closing parenthesis")
                    return 0
                self.position += 1
            else:
                if not self.word(self.position, "end"):
                    self.fail(self.position, "expected end")
                    return 0
                self.position += 3
            return result

        # Symbolic primitive aliases.
        if value == 93:
            self.position += 1
            return self.leaf(1, start)
        if value == 45:
            self.position += 1
            return self.leaf(2, start)
        if value == 42 and self.byte(start + 1) == 58:
            self.position += 2
            return self.leaf(3, start)
        if value == 37 and self.byte(start + 1) == 58:
            self.position += 2
            return self.leaf(4, start)
        if value == 43 and self.byte(start + 1) == 58:
            self.position += 2
            return self.leaf(5, start)
        if value == 43 and self.byte(start + 1) == 47:
            self.position += 2
            return self.leaf(20, start, category=1)

        # Word primitives are deliberately exact lowercase tokens. The scan
        # still consumes digits, underscores, and uppercase letters so an
        # unknown compound token cannot be accepted as a valid prefix.
        if _is_ascii_letter(value):
            self.position += 1
            while _is_word_char(self.byte(self.position)):
                self.position += 1
            if self.matches(start, self.position, "identity"):
                return self.leaf(1, start)
            if self.matches(start, self.position, "negate"):
                return self.leaf(2, start)
            if self.matches(start, self.position, "square"):
                return self.leaf(3, start)
            if self.matches(start, self.position, "sqrt"):
                return self.leaf(4, start)
            if self.matches(start, self.position, "double"):
                return self.leaf(5, start)
            if self.matches(start, self.position, "sum"):
                return self.leaf(20, start, category=1)
            if self.matches(start, self.position, "mean"):
                return self.leaf(21, start, category=1)
            self.fail(start, "unknown word")
            return 0

        self.fail(start, "unsupported punctuation or token")
        return 0


def parse(var source: String) -> Syntax:
    var syntax = Syntax(source^)
    if syntax.source.byte_length() > 512:
        syntax.fail(512, "source exceeds 512 bytes")
        return syntax^

    for index in range(syntax.source.byte_length()):
        if syntax.byte(index) >= 128:
            syntax.fail(index, "only ASCII source is supported")
            return syntax^

    syntax.root = syntax.expression(0)
    syntax.skip()
    if syntax.error == "" and syntax.position != syntax.source.byte_length():
        syntax.fail(syntax.position, "unexpected trailing token")
    return syntax^
