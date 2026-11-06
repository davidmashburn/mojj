# Build a small compositional numerical library

Status: slices 1–2 implemented; slice 2's original grammar superseded. Slice 3
is partial; slice 4 remains proposed apart from initial benchmark evidence.
Reconciled 2026-11-06 against published `main` at
[`09cf8d4`](https://github.com/davidmashburn/mojj/commit/09cf8d4df865581b60727b11ecddb512de3dcc13),
with no uncommitted implementation changes.

| Slice | Current evidence | Remaining work |
| --- | --- | --- |
| 1. Typed foundation | [Core](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/src/mojj/core.mojo) and [tests](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/tests/test_core.mojo) retain composition, lazy maps, sum/mean, RMS, descriptions, custom scalar extension, empty policies and runtime-size reuse. | No new foundation feature is pending. Linux and exhaustive IEEE behavior remain unverified. |
| 2. Textual front ends | `811f40c` shipped the prototype; `f6b05c8` replaced whitespace composition with J trains, typed verbs/nouns and explicit `of`/`@:`. [Migration and current grammar](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/docs/SYNTAX.md). | The historical grammar below is not the current contract. No separate pipeline entrypoint exists. |
| 3. Shared reductions | [Fork](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/src/mojj/verbs.mojo#L727), branch composition and derived mean exist, with [typed tests](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/tests/test_verbs.mojo#L141). | Fork branches evaluate independently. Shared traversal, stable moments and an optimized shared reduction API are still proposed; semantic forks do not complete this slice. |
| 4. Views, windows and evidence | [Recorded J comparisons](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/tests/reference/RESULTS.md) now provide nine API timings and selected conformance evidence. | Views/windows, shaped output contracts, direct-loop/materialized controls, compile-time measurements, assembly inspection and Linux verification remain open. |

The [performance plan](expression-performance.md) is the active next step; this
reconciliation does not reprioritize the remaining vocabulary/array proposals.
The library remains pure Mojo; Python and pinned J are development-only tools.
Legacy `Mean` still rejects empty input and accumulates left to right; the new
J-derived mean returns zero on empty input and uses right-grouped insertion.

Source and focused tests were inspected for this reconciliation; no runtime
checks were rerun. Passing macOS tests/demo/package checks and reference outcomes
are inherited from the linked record, not fresh validation. Confidence is high
in these implementation statuses, not in full J parity or performance causation;
new failing cases or profiling evidence could change the assessment.

## Historical foundation proposal and verification — 2026-11-02

Everything below is the original dated record; use the reconciliation above
for current implementation and verification status.

Status: foundation and textual-front-end prototype published after approval.
Later slices remain proposed. The [J vocabulary roadmap](j-vocabulary.md) now
prioritizes semantic fidelity before adding shared reductions and views.
Observed: 2026-11-02. Implementation ref: `main` at
`811f40c4d7a31df41a771a0200bc5937cae0b642` (published).
Published foundation: `9f745a0471406c556a3c35146a9c8fa5113c3c41`.

## Intent

Build Mojj as an independent, pure Mojo library for numerical composition.
Small operations form inspectable expressions; explicit consumers evaluate them
over runtime data. Typed construction comes first, followed by a bounded
J-inspired string syntax and readable word phrases sharing one semantic model.

The source of truth for each shipped slice is its `main` implementation and
behavioral tests. Prior prototype results motivate experiments but do not prove
this new implementation correct or fast.

## Boundaries and decisions

- Start with Float64 CPU execution and Mojo 1.1.0, pinned with Pixi.
- Public package `mojj`, conventional local alias `jj`.
- Author expression structure explicitly. Do not infer algebra from arbitrary
  functions or claim a general optimizer.
- Keep library, demonstration, and behavioral tests pure Mojo. No NumPy or
  NuMojo dependency in the foundation.
- New repository and history; do not transplant the prototype repository or
  its generated measurements into a public tree.
- No full J compatibility, arbitrary tensor framework, GPU backend, automatic
  differentiation, or dynamic visual editor in the initial stages.
- Use bounded Luna agents at max effort for implementation and test work.
  The orchestrator owns specifications, integration, verification, and Git.

## Slice 1: typed foundation

Implement scalar operations, composition, lazy maps, sums, means, scalar
post-processing, materialization, and descriptions. One library package, one
demonstration, and one focused behavioral test program are sufficient.

Acceptance criteria:

- A composed `(x + 2) * 3` map agrees with direct arithmetic, including inputs
  that distinguish composition order.
- A nested map agrees with scalar composition without mutating input.
- RMS is expressed as `After[Sqrt, Mean[Map[Square]]]`, evaluated on runtime
  lists, and described as `after(sqrt, mean(map(square, input)))`.
- Empty map/sum and the empty-mean exception have explicit tested policies.
- The same expression works at different runtime lengths.
- A custom scalar operation satisfies the public extension contract.
- A precompiled package runs the same example as the source import.
- The README matches the implemented API and states verification limits.

Verification commands: `pixi install --locked`, `pixi run test`, `pixi run demo`,
and `pixi run package-smoke`. Compare numerical results against independent
arithmetic, not only one expression spelling against another.

Checkpoint: commit this slice on `main`, show the exact commit and publication
operation, and request approval before pushing to public `davidmashburn/mojj`.
Do not infer permission to push later commits from approval of this first one.

## Slice 2: bounded textual front ends

Start with scalar expression literals and composition, then add reducers.
Support both readable words (such as `negate of square`) and selected J-inspired
symbols. Both must lower to the same inspected structure and evaluation path.
Specify the grammar, whitespace, precedence, error spans, and resource bounds
before implementation. Reject unsupported forms at compile time, with bounded
negative fixtures for malformed, unknown, truncated, and oversized input.

Implemented as `Expr[source: StringLiteral]`. See the
[grammar contract and verification evidence](expression-strings.md).

## Slice 3: shared reductions

Introduce explicit forks, branch-local maps, and stable moments. Check each
branch against an independent implementation and define empty-input and error
behavior before optimizing traversals. Keep state per evaluation; prove that
reuse across input sizes does not retain accumulator state.

## Slice 4: views, windows, and evidence

Add runtime views and windows only after the core model is stable. Validate
shape, bounds, strides, and output capacity before writes. Define partial-write
behavior for user-code failures separately from validation failures.

Benchmark representative compositions against handwritten loops and deliberately
materialized references; record compile times and inspect generated code.
Source-level absence of temporaries is not proof of compiler allocation behavior.
Investigate Linux CI and packaging as a separately verified portability step.

## Current unknowns

- MIT is included in the approved first public commit.
- No CI, benchmark, or Linux runtime result exists for Mojj yet.
- This plan is a sequence of reviewable slices, not a claim that later APIs or
  performance outcomes are already settled.

## Slice 1 verification

The orchestrator reviewed the implementation and tests, then verified with the
new repository's pinned Mojo 1.1.0 environment on macOS arm64:

- `pixi install --locked` succeeded.
- `pixi run test` passed ten groups, including default reducer binding with
  `Sum[]` and `Mean[]` and explicit left-to-right accumulation behavior.
- `pixi run demo` and `pixi run package-smoke` produced the same mapped values,
  descriptions, and RMS result.
- Both README Mojo examples were compiled and executed through `pixi run`.
- Staged whitespace checks passed; the implementation checkout is clean.

Two GPT-5.6-Luna agents at max effort implemented the core/example and independent
tests. The orchestrator added the default-source/negation checks and reviewed
the final contents before committing. Linux, CI, performance benchmarks, and
exhaustive IEEE special values were not tested.

The user approved the initial public push. GitHub `main` was verified at the
published foundation commit. Planning and all later implementation commits
remain local. See [the next slice contract](expression-strings.md).

Subsequent publication update, 2026-11-02: the user approved pushing `811f40c`,
and remote main was verified at that revision. Planning remains local. The
earlier verification above describes the foundation checkpoint, not current
publication state.
