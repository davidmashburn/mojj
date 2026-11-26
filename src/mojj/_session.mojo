"""Noun bindings for the CLI's persistent Mojo REPL."""
from ._syntax import Kind, Part, Syntax, parse, _letter, _digit
from .strings import _Syntax, _Value, _Verb
from .nouns import Noun, NounDType


struct Session:
    var names: List[String]
    var values: List[Noun]

    def __init__(out self):
        self.names = List[String]()
        self.values = List[Noun]()

    def lookup(self, name: String) raises -> Noun:
        for i in range(len(self.names)):
            if self.names[i] == name:
                return self.values[i].copy()
        raise Error("undefined name: " + name)

    def assign(mut self, name: String, var value: Noun) raises:
        var ast = parse(name, True)
        if ast.error != "" or ast.nodes[ast.root].kind != Kind.NAME:
            raise Error("reserved or invalid name: " + name)
        for i in range(len(self.names)):
            if self.names[i] == name:
                self.values[i] = value^
                return
        self.names.append(name)
        self.values.append(value^)


def _name_at(ast: Syntax, var i: Int) -> String:
    var name = String()
    while _letter(ast.byte(i)) or _digit(ast.byte(i)) or ast.byte(i) == 95:
        name += String(chr(ast.byte(i)))
        i += 1
    return name


struct _Read[source: StringLiteral, node: Int]:
    @staticmethod
    def value(env: Session) raises -> Noun:
        comptime ast = _Syntax[Self.source, True].ast
        comptime n = ast.nodes[Self.node]
        comptime if n.kind == Kind.NAME:
            comptime name = _name_at(ast, n.position)
            return env.lookup(name)
        elif n.kind == Kind.MONAD:
            return _Verb[Self.source, n.a, True].monad(_Read[Self.source, n.b].value(env))
        elif n.kind == Kind.DYAD:
            return _Verb[Self.source, n.a, True].dyad(_Read[Self.source, n.b].value(env), _Read[Self.source, n.c].value(env))
        else:
            return _Value[Self.source, Self.node, True].value()


def evaluate[source: StringLiteral](env: Session) raises -> Noun:
    comptime ast = _Syntax[source, True].ast
    comptime assert ast.error == "", ast.error
    comptime assert ast.part == Part.NOUN, "expected a noun sentence"
    return _Read[source, ast.root].value(env)


def display(n: Noun) raises:
    if n.rank > 1:
        print("shape", n.dims(), end=" ")
    if n.dtype == NounDType.INT:
        if n.is_scalar():
            print(n.as_int())
        else:
            print(n.as_ints())
    elif n.dtype == NounDType.FLOAT64:
        if n.is_scalar():
            print(n.as_float())
        else:
            print(n.as_floats())
    elif n.is_scalar():
        print(n.as_bool())
    else:
        print(n.as_bools())
