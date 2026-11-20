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
entry. The [ten SIMD experiments](https://github.com/davidmashburn/mojj/blob/f4467f1/tests/perf/simd/README.md)
selected four-wide SIMD for Float64 vector double (1.63× and 1.19× median paired
speedups in two M4 runs at 100,000 elements). Extending SIMD to another verb
requires its own matched public benchmark. A separately
named blocked sum remains a proposal for workloads that can accept different
rounding. See the [performance tuning plan](plans/expression-performance.md).

[The P3 vocabulary change](https://github.com/davidmashburn/mojj/commit/7233ced0d7ab8828bb02e51c79c6d5476c451bcb)
shipped the supported subsets of all 28 Include families. Its reference run met
117/117 expectations, including two documented differences from J. Array and
window results currently own their storage.

- [Shared reductions and stable moments](plans/foundation.md#slice-3-shared-reductions)
  — [The implementation](https://github.com/davidmashburn/mojj/commit/03a4576a0c8b609a05b998cc2a3514ae8fa5e6df) exposes the opt-in one-pass
  `PopulationMoments[Source]`. The corrected two-pass benchmark was faster in all
  48 matched square-map samples on M4. Source read cost and mean rounding
  matter when choosing a method. General sharing across arbitrary fork branches
  remains proposed.
- [Expr performance tuning](plans/expression-performance.md) — remaining candidates
  include input and identity copies, additional measured SIMD kernels, and an
  opt-in blocked sum if a workload justifies different rounding.
- [J vocabulary and semantics roadmap](plans/j-vocabulary.md) — the Include list
  through P3 has shipped. Items marked “Skip for now” remain deferred.
- [Views and portability](plans/foundation.md#slice-4-views-windows-and-evidence)
  — windows and shaped results have shipped. Strided views remain proposed. The locked test suite, demo,
  and package smoke passed on emulated Ubuntu x86-64. Native x86-64 performance
  and hosted Linux CI remain unverified.
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
