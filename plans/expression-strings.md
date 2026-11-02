# Compile expression strings

Status: in progress locally. Observed 2026-11-02.
Baseline: `main` at `9f745a0471406c556a3c35146a9c8fa5113c3c41`.

## Intent and API

Add `Expr[source: StringLiteral]`, exported by `mojj`. Its static methods are:
`apply(Float64) -> Float64` and `map(List[Float64]) -> List[Float64]` for scalar
expressions; `reduce(List[Float64]) raises -> Float64` for reductions; and
`describe() -> String` for either category. Wrong-category calls are compile
errors. Validation occurs when an entrypoint is instantiated, not merely when
an unused alias is declared.

The parser produces a bounded compile-time tree, separate from numerical
evaluation. Lowering delegates to the existing operations, `Map`, `Sum`, `Mean`,
`After`, and consumers. It must not implement a second numerical interpreter.

## Grammar

```text
expression := atom [("of" | "@:") expression]
atom       := primitive | "(" expression ")" | "group" expression "end"
primitive  := identity | negate | square | sqrt | double | sum | mean
```

Symbolic primitive aliases: `]` identity, `-` negate, `*:` square, `%:` sqrt,
`+:` double, `+/` sum. Additionally the exact token pattern `(+/ % #)` means
mean, allowing ASCII whitespace between its tokens. The `%` and `#` tokens have
no standalone meaning in this slice. This is an explicitly limited J-inspired
grammar, not full J evaluation or precedence.

Composition is right-associative and evaluates its right operand first.
Words are whole lowercase tokens, separated from other words by ASCII whitespace
or punctuation boundaries. Whitespace is space, tab, CR, and LF. Mixed word and
symbol expressions are supported. Reject unknown words, dangling input, non-ASCII
bytes, mismatched groups, and unsupported punctuation.

Scalar after scalar yields a scalar. Reduction after scalar maps the input;
scalar after reduction transforms the result. Reduction after reduction is
rejected. Grouping may expose either valid mixed order, e.g.
`(sqrt of mean) of square` must agree with `sqrt of mean of square`.

Limits: 512 input bytes, 64 AST nodes, 16 recursive expression/group levels.
Bounds are checked before recursive descent or growth. Diagnostics identify a
zero-based byte offset and use `Mojj syntax at byte N:` or
`Mojj category at byte N:`. Wrong entrypoints say what category they require.

## Verification

- Compare scalar expressions, noncommuting operations, both grouping styles,
  mixed spelling, and whitespace against direct arithmetic and typed nodes.
- Compare sum, mean, and RMS on different runtime sizes and empty inputs.
- Require exact matching descriptions for equivalent typed/string forms.
- Reject malformed and oversized literals using compile-fail fixtures, with a
  timeout and expected diagnostic marker for each fixture. Compile a valid
  control first so a broken toolchain cannot masquerade as parser success.
- Run examples and positive tests against both source and precompiled imports.
- Preserve the original ten core test groups.

Out of scope: literal numeric arguments, forks, new reducers, views/windows,
rewrites, automatic differentiation, runtime parsing, and performance claims.
An optional Python-standard-library compiler-test driver is development tooling;
the library and numerical execution remain pure Mojo.
