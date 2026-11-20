# Mojj planning

Implementation branch: `main`. This orphan `project-planning` branch contains
proposals and design reasoning only; never merge it into implementation history.

## Active plan

As of 2026-11-20, performance slices 1–3 have shipped on `main`. The
[November 15 post-change report](https://github.com/davidmashburn/mojj/blob/13336b8/tests/perf/README.md)
records 33/33 conformance expectations and nine benchmark output checks after
the unboxed Float64 maps and strict right fold landed.

[The ownership change](https://github.com/davidmashburn/mojj/commit/1e042d2) removes the measured Float64 output copy
at the public `Expr.map` list boundary. Caller-owned input still copies on
entry. The next planned kernel experiment is elementwise SIMD, with a
matched scalar control and a bit-identical output check. A separately
named blocked sum remains a proposal for workloads that can accept different
rounding. See the [performance tuning plan](plans/expression-performance.md).

The original reference-fixture next step has landed in
[`09cf8d4`](https://github.com/davidmashburn/mojj/commit/09cf8d4df865581b60727b11ecddb512de3dcc13):
33 selected conformance expectations passed, with documented differences from J,
and nine provisional performance comparisons were recorded. This does not prove
full subset parity. The vocabulary roadmap below retains its original baseline
and proposal history, with current status reconciled against code and tests.

- [Expr performance tuning](plans/expression-performance.md) — current next step;
  measured attribution, then one demonstrated cost per slice.
  [Baseline evidence](plans/evidence/performance-baseline.md) records the probes,
  the same-host J rerun and the reduction-order finding.
- [J vocabulary and semantics roadmap](plans/j-vocabulary.md) — bounded P0/P1
  implemented; P2 partial, P3 proposed. Full subset parity remains unverified.
- [Build a small compositional numerical library](plans/foundation.md) — foundation
  shipped; shared traversal/stable moments and views/windows remain open.
- [Compile expression strings](plans/expression-strings.md) — historical prototype
  shipped, then superseded by J train semantics; current migration links included.

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
