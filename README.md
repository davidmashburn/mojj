# Mojj planning

Implementation branch: `main`. This orphan `project-planning` branch contains
proposals and design reasoning only; never merge it into implementation history.

## Current plan

All 28 vocabulary families marked Include through P3 have shipped within their
documented scope. The [vocabulary roadmap](plans/j-vocabulary.md) records the
deferred families. The original [expression grammar](plans/expression-strings.md)
was superseded by J train semantics.

- [Foundation](plans/foundation.md) and [streaming reductions](plans/streaming-reductions.md).
  Borrowed strided input, one-pass population moments and explicit paired folds
  are available. General recognition of shared work in arbitrary J forks would
  require a concrete caller and a design for evaluation and error order.
- [Expression performance](plans/expression-performance.md). Direct identity
  can return a transferred Float64 list. Double uses four-wide SIMD. Square
  stays scalar after the M4 repeat and the native Linux comparison. [Float64 vector
  dot](https://github.com/davidmashburn/mojj/blob/cafdc9c/tests/perf/dot/README.md)
  now collects typed cells. It won 79/80 matched M4 timings and 80/80 on native x86-64.
  [Rectangular Float64 dot](https://github.com/davidmashburn/mojj/blob/94df95e/tests/perf/dot/rectangular.md)
  uses typed product storage for matrix × vector. The vector × matrix and
  reduction-row candidates missed the wide-matrix M4 selection gate.
  In [mixed batches](https://github.com/davidmashburn/mojj/blob/db73eba/tests/perf/dot/mixed.md),
  five matrix × vector calls per hundred won seven of eight pairs on both shapes
  in both Linux runs. A quiet M4 repeat and application call counts remain open.
  A separately named blocked sum needs a workload with an explicit rounding tolerance.
- [Portability and compatibility](plans/streaming-reductions.md#implementation-evidence).
  Native Ubuntu CI runs the full suite, demo, package smoke and the pinned J
  corpus. Empty-frame rank now uses an available real cell. The [reference harness](https://github.com/davidmashburn/mojj/commit/e74c034)
  preserves explicit matrix shapes and declared input types.

## Ideas

- [One expression, two textual forms](ideas/expression-frontends.md) — shared
  word/symbol model and branching shipped; separate pipeline DSL remains an idea.

Implementation starts from `main`. Usage documentation, implemented contracts,
and behavioral tests belong with the code. Update this index and each proposal
against actual commits as slices land.

Publication policy: make the first implementation commit locally, then obtain
explicit approval for the initial public repository push. Subsequent development
stays local until a later publication instruction. This planning branch is also
local unless explicitly included in that approval.

## Reconciliation evidence

Observed 2026-11-06: local and remote `main` agree at
[`09cf8d4`](https://github.com/davidmashburn/mojj/commit/09cf8d4df865581b60727b11ecddb512de3dcc13);
the implementation checkout is clean. `f6b05c8` shipped the J semantic migration,
and `09cf8d4` shipped reference fixtures and results. Plans retain their original
reasoning under historical headings; those earlier publication/validation states
are not current status.

This reconciliation inspected implementation and focused tests, checked recorded
results and planning links, and changed no source. Tests, benchmarks, external
reference URLs, Linux execution and remote CI were not rerun. No new acceptance
or performance claim follows from updating a plan.
