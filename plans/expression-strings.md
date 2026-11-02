# Compile expression strings

Status: implemented and verified locally; not pushed. Observed 2026-11-02.
Implementation: `811f40c4d7a31df41a771a0200bc5937cae0b642` on `main`.
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
expression := atom [(whitespace | "of" | "@:") expression]
atom       := primitive | "(" expression ")" | "group" expression "end"
primitive  := identity | negate | square | sqrt | double | sum | mean
```

Symbolic primitive aliases: `]` identity, `-` negate, `*:` square, `%:` sqrt,
`+:` double, `+/` sum. Additionally the exact token pattern `(+/ % #)` means
mean, allowing ASCII whitespace between its tokens. The `%` and `#` tokens have
no standalone meaning in this slice. This is an explicitly limited J-inspired
grammar, not full J evaluation or precedence.

Whitespace between atoms implies composition; `of` and `@:` remain optional
explicit aliases. Leading/trailing whitespace and whitespace before `)` or `end`
do not compose anything. Adjacent atoms require whitespace or an explicit
operator. Composition is right-associative and evaluates its right operand first.
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

## Implementation evidence

Two GPT-5.6-Luna workers at max effort implemented the parser/lowering and
independent tests. The orchestrator reviewed both, integrated exports, tasks,
documentation, and the example, and tightened the resource-bound checks.

Verified on macOS arm64 with pinned Mojo 1.1.0:

- `pixi install --locked` succeeded without a lockfile change.
- `pixi run test` passed ten core groups and nine expression groups.
- The compiler driver accepted a control exercising every entrypoint plus
  valid 512-byte, depth-16, and 63-node expressions. Binary composition trees
  have odd node counts, so 63 is the largest valid tree below the 64-node cap.
- All twenty-five negative fixtures failed with expected diagnostics, including
  specific limit messages for 513 bytes, depth 17, and 65 AST nodes.
- Both demos and `pixi run package-smoke` passed; the latter reran all nine
  expression groups through the precompiled package.
- Staged whitespace checks passed and the implementation checkout was clean
  after the commit.

Linux execution, remote CI, performance/assembly measurements, and exhaustive
IEEE special-value behavior remain unverified. Public `main` remains at the
approved foundation commit; this parser commit and planning updates stay local.

The user requested implicit whitespace composition before publication. The
implementation commit was amended, and the orchestrator reran the full suite,
both demos, and package checks. Added coverage verifies bare phrases, mixed
explicit/implicit operators, right-associative descriptions, group terminators,
whole-word boundaries, and implicit composition category/depth failures.
