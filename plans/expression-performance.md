# Expr performance tuning

Status: proposed, 2026-11-06. No optimization is implemented by this plan.
Implementation baseline: [`09cf8d4`](https://github.com/davidmashburn/mojj/commit/09cf8d4df865581b60727b11ecddb512de3dcc13).
Keep this proposal on `project-planning`; implement accepted slices from `main`.

## Aim and evidence

Reduce overhead in the compiled `Expr` API while preserving its current noun,
rank, dtype, error, evaluation-order and description contracts. First measure
where time goes; then remove one demonstrated cost at a time. Do not promise J
performance parity or a speedup factor.

The [recorded comparison](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/tests/reference/RESULTS.md)
found J faster on all nine Float64 double, sum and RMS benchmarks (1k–100k
items). Final median ratios were approximately 19–219×, but host contention and
run variability make their magnitudes provisional. The measured library was
`f6b05c82ac3251876a2e8a8af394f52581ebfcee`; `09cf8d4` adds the harness and results
without changing library code. These are API timings, including allocation and
destruction, not a comparison of bare arithmetic kernels.

Confidence is moderate that these workloads have a repeatable performance gap,
and low in any particular cause or portable ratio. Profiling, generated-code
inspection and quieter repeated measurements could change the priorities below.
The existing 33 reference expectations are selected-case evidence, not proof of
full parity with J or even exhaustive coverage of the supported subset.

## Likely targets, in order

| Priority | Code evidence and proposed experiment | Tradeoff and acceptance gate |
| --- | --- | --- |
| 1. Establish a useful baseline | Retain the existing end-to-end benchmarks; add matched direct Float64 loops and direct verb calls to distinguish kernel, noun/API and expression overhead. Measure loop/mutation/consumption overhead separately. | Extra harness work first prevents tuning noise. Keep outputs observable and inputs changing; inspect generated code for one representative case. Do not subtract noisy overhead to manufacture a speedup. |
| 2. Remove unnecessary vector copies | [Vector noun constructors](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/src/mojj/nouns.mojo#L92) explicitly copy lists; verbs construct a fresh result list and then wrap it in `Noun`. Measure those paths, then try an internal ownership-taking result constructor. | Preserve public copying constructors and independent input ownership. Transfer only freshly owned temporaries; demonstrate fewer allocations/copies and an end-to-end improvement. Compiler elimination must be measured, not assumed absent. |
| 3. Use typed element loops | [Double and square](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/src/mojj/verbs.mojo#L385) access each element through `at()` and scalar conversions. Dispatch dtype/rank outside a Float64 loop and read typed storage directly. Start with double as a small slice. | Less generic code may duplicate logic. Keep generic fallbacks; extend only where measurements justify it. Scalar nouns have inline values and empty lists: do not assume each scalar cell heap-allocates. |
| 4. Specialize hot reductions | [Insert](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/src/mojj/verbs.mojo#L598) creates scalar cells and invokes a generic dyad at every step. Trial a Float64 sum accumulator reading storage directly, from the last element backwards. | Preserve the current right fold, including the initial last element, scalar/singleton behavior and empty identity. Parallel/tree summation changes rounding; checked integer operations need separate treatment. |
| 5. Fuse a bounded pure path | [Composition](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/src/mojj/verbs.mojo#L755) passes complete inner results to outer verbs. If profiling still shows materialization dominating RMS, trial square-plus-right-sum fusion followed by division and square root. | Fusion adds maintenance and can change error order. Start only with proven-safe Float64 cases, preserve scalar operation order and the authored `describe()` tree, and retain the generic path. No general optimizer yet. |
| 6. Consider SIMD where safe | After eliminating demonstrated abstraction/copy overhead, inspect whether elementwise Float64 loops vectorize. Compare an explicit SIMD kernel only if they do not. | Code size and tail handling may outweigh gains on small inputs. No blanket fast-math or reduction reassociation. Defer threading/GPU work. |

The parser and `_Verb` dispatch use compile-time syntax nodes
([source](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/src/mojj/strings.mojo#L86)); parsing is not an established runtime
hotspot. Investigate specialization/inlining only if generated code or a profile
shows residual dispatch overhead. Do not start by redesigning the parser or noun
representation. A matched legacy lazy-API benchmark is useful context if cheap,
but must be labeled separately and must not replace the `Expr` result.

## First implementation slice

Make the benchmark baseline reliable before editing library behavior. Extend
`tests/reference/compare.py` and its harness tests with the smallest useful
matched controls; keep J a development-only dependency. Use the pinned toolchain
and reference runtime. Record exact source/harness revisions, compiler flags,
hardware, input dtype/shape, batch samples, repetitions and host load.

Run before/after binaries on the same quiet host, alternating or balancing order
across repeats. Record contention and report distributions; do not silently drop
unfavorable runs or stop unrelated processes. Retain the current 1k/10k/100k
cases and add scalar, empty and short vectors to catch fixed-cost regressions.
Measure allocations/copies where tooling permits; distinguish source-level copy
sites from copies proven to survive compilation. If profiling is unavailable,
record that limitation and use controlled experiments, not inferred percentages.

Deliver a short bottleneck report plus raw results. Choose **one** subsequent
optimization from the table using those results. Proceed only when the effect
exceeds observed repeat variability and repeats in an independent run; otherwise
report the result as inconclusive. Investigate regressions on any retained case
before accepting a change. No fixed speedup target is justified yet.

## Correctness gates for each library slice

- Run `pixi run test`, `pixi run demo`, `pixi run package-smoke`, and the documented
  [live J comparison](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/tests/reference/README.md).
  Preserve all 33 current expectations and all nine benchmark value, shape and
  dtype checks; add focused cases for whichever path changes.
- Cover atoms versus singleton vectors, empty identities and dtype, scalar
  extension versus unequal vector lengths, Boolean promotion, exact integers
  above 2**53, overflow and unsupported valences. Keep Mojj's documented
  differences from J; performance work must not silently alter compatibility.
- Check subtraction's right fold, cancellation-sensitive floating sums, signed
  zero, NaN/infinity and domain failures against the existing implementation's
  contract. Reference tolerance alone cannot establish unchanged rounding or
  failure behavior; add exact same-implementation checks where appropriate.
- Reuse the same input across repeated calls and sizes; verify inputs remain
  unchanged, returned values remain independent, and descriptions preserve
  expression structure. Keep the generic path as a comparison oracle during
  development, supplemented by independent expected values.

## Boundaries and handoff

No additional vocabulary, general array ranks, public mutation/buffer API,
toolchain upgrade, threads, GPU backend, approximate arithmetic, or broad cleanup
belongs in this effort. Benchmark diagnostics and focused tests belong beside
implementation; update this plan against actual commits as slices land.
The orchestrator reviews each slice, checks outgoing content and handles any
separately authorized implementation commit/push.

Planning validation on 2026-11-06: inspected the pinned implementation, recorded
comparison and planning history; checked local link targets and the documentation
diff. Existing test results above are inherited evidence. No new benchmarks,
profiling, assembly audit, runtime tests, Linux checks or remote CI were run for
this documentation-only change. Main remains unchanged; no performance result
or release approval is implied by publishing this proposal.
