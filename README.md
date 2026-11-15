# Mojj planning

Implementation branch: `main`. This orphan `project-planning` branch contains
proposals and design reasoning only; never merge it into implementation history.

## Active plan

Next proposed step (2026-11-15): **remove the measured per-element `Noun` tax in
the compiled `Expr` paths, then decide the reduction-order contract.** See the
[performance tuning plan](plans/expression-performance.md) and its
[measured baseline](plans/evidence/performance-baseline.md).

The baseline rerun reproduced the comparison on this host (33/33 conformance
expectations, nine benchmarks) and attributed the 17–177× gap by controlled
experiment: boxing each cell in a `Noun` costs 13× on maps and 16–23× on
reductions, while a strict floating-point fold has a hardware floor around
1 ns/element. Removing the boxing is semantics-preserving and is the first
implementation slice. Matching J's sum timings additionally requires abandoning
the strict fold, because J reassociates float reductions; that is a documented
API decision, not tuning. The plan recommends a separately named blocked
reduction and leaves the strict fold as the default and oracle.


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
