# Compiled expressions

`Expr[source: StringLiteral]` parses at compile time and uses the typed numerical
core. It does not parse runtime strings or implement full J semantics.

## Vocabulary

| Word | Symbol | Meaning |
| --- | --- | --- |
| `identity` | `]` | Return a scalar unchanged |
| `negate` | `-` | Negate a scalar |
| `square` | `*:` | Square a scalar |
| `sqrt` | `%:` | Square root |
| `double` | `+:` | Multiply a scalar by two |
| `sum` | `+/` | Sum input values; empty input returns zero |
| `mean` | `(+/ % #)` | Mean input values; empty input raises |

The parenthesized mean spelling is one recognized pattern. `%` and `#` do not
have standalone meanings. Words and symbols can be mixed.

```text
expression := atom [(whitespace | "of" | "@:") expression]
atom       := primitive | "(" expression ")" | "group" expression "end"
```

Words are lowercase whole tokens. Separate adjacent words with ASCII whitespace;
punctuation can also delimit them. Whitespace is space, tab, CR, or LF.
Symbols do not require surrounding spaces. Unicode, numeric literal arguments,
unknown words, and unsupported operators are rejected.

Whitespace between atoms implies composition. `of` and `@:` are explicit aliases
and may be mixed with implicit composition. Leading/trailing whitespace and
whitespace before `)` or `end` do not compose anything. Adjacent atoms require
whitespace or an explicit operator: `square(square)` is rejected.

## Composition and categories

Composition is right-associative and applies the right side first.
`double square` squares and then doubles; `square double` doubles and then
squares. Parentheses or `group … end` override grouping.

- Scalar after scalar produces a scalar expression.
- Reduction after scalar transforms each input before reducing it.
- Scalar after reduction transforms the scalar result.
- Reduction after reduction is unsupported and rejected.

`sqrt mean square`, `sqrt of mean of square`, and `(sqrt mean) square` compute RMS and
describe themselves as `after(sqrt, mean(map(square, input)))`.

For scalar expressions, call `apply(Float64)` or `map(List[Float64])`.
For reductions, call `reduce(List[Float64])`. Wrong-category calls are compile
errors. `map` returns a fresh list; `reduce` inherits the core's empty-input,
left-to-right accumulation, and Float64 behavior.

## Validation and limits

`describe`, `apply`, `map`, and `reduce` validate the literal when instantiated.
Merely declaring an unused alias need not instantiate a method and is not a
validation guarantee. Syntax errors report `Mojj syntax at byte N:`; category
errors report `Mojj category at byte N:`. Positions are zero-based byte offsets
into the original literal, including leading whitespace.

Limits are 512 ASCII bytes, 64 AST nodes, and 16 nested recursive levels beyond
the root. Parentheses and composition both consume nesting depth. Limits bound
compile-time work rather than runtime input sizes.

The positive tests compare words, symbols, grouping, and direct typed/arithmetic
forms. The compiler-failure driver first compiles a valid control, then checks
rejection and an expected diagnostic for malformed, mismatched, wrong-category,
and oversized inputs. It uses a timeout for every compiler invocation.
