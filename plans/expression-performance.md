# Expr performance tuning

Reviewed 2026-11-20 against [main at 13336b8](https://github.com/davidmashburn/mojj/tree/13336b8).
Slices 1–3 landed in `5dc7477`, `f0b7994` and `7bc6930`. The
[post-change measurements](https://github.com/davidmashburn/mojj/blob/13336b8/tests/perf/README.md)
include the pinned J rerun. At 100,000 elements, the recorded Mojj/J ratios
fell to 2.10× for double, 9.44× for strict sum and 3.97× for RMS.

Slice 4 is partially implemented. The typed map already moves its result list
into a noun. [The ownership change](https://github.com/davidmashburn/mojj/commit/1e042d2) also transfers that list out of `Expr.map`. On an M4 the
matched 100k-element double fell from 492 µs to 91 µs per call (three runs).
See the [matched measurements](https://github.com/davidmashburn/mojj/blob/1e042d2/tests/perf/README.md#public-float64-map-boundary-2026-11-20) for the method.
The input list constructor and identity verbs still copy caller-owned or
borrowed data. Any change there needs its own measured workload and
independence checks. The [original
baseline](evidence/performance-baseline.md) and projections below describe
the implementation before slices 1–3.

The [ten SIMD experiments](https://github.com/davidmashburn/mojj/blob/f4467f1/tests/perf/simd/README.md)
evaluated slice 5 for Float64 vector double. [The implementation](https://github.com/davidmashburn/mojj/commit/e0ed509)
retains scalar tails and leaves other verbs on their existing paths. Width
four won all eight primary public comparisons against the scalar baseline
and seven of eight in a fresh build and timing repeat.
Width eight won three of eight head-to-head comparisons with width four.
Further kernel proposals need an end-to-end workload and per-verb contract
checks. Fast reduction remains contingent on a workload and a rounding decision.

## Input transfer and the next SIMD trial

[Owned Float64 map and reduce](https://github.com/davidmashburn/mojj/commit/c2d75a2)
accept a moved input list. The arm64 public-wrapper assembly shows the entry
payload copy disappears. Existing borrowing consumers preserve input ownership.
Measure direct identity separately because its monad still copies its result.

[The square trial](https://github.com/davidmashburn/mojj/commit/444db48)
compares four builds through public square and RMS calls. Require repeatable
paired evidence and check the Linux timing run before selecting a production
width. Keep native x86-64 and Apple Silicon findings separate.

## Aim and evidence

Reduce overhead in the compiled `Expr` API while preserving its noun, rank,
dtype, error, evaluation-order and description contracts. Measure where time
goes; then remove one demonstrated cost at a time. Do not promise J performance
parity or a speedup factor.

The [recorded comparison](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/tests/reference/RESULTS.md)
found J faster on all nine Float64 double, sum and RMS benchmarks (1k–100k
items), with final median ratios of roughly 19–219×. A same-host rerun on
2026-11-15 reproduced the direction and magnitude: 17–38× for double, 40–177×
for sum and 36–65× for RMS, with 33/33 conformance expectations still passing.
These are API timings, including allocation and destruction, not bare arithmetic
kernels.

The bottleneck report below is now measured rather than inferred, so the earlier
"likely targets" ordering has been replaced by an implementation order grounded
in those numbers. Confidence is high that per-element `Noun` construction and
generic verb dispatch dominate these three workloads. Confidence is moderate in
the projected post-fix figures, which are derived from raw-loop floors rather
than from an implemented change.

## Measured baseline, 2026-11-15

Apple M1 (8 cores), macOS 26.2, Mojo 1.1.0 (8189361e), `--fp-mode contract=off`,
release binaries. The host was not quiet (load average 2.1–6.4, other
applications using CPU), so absolute values are not portable; every comparison
below was run back-to-back in one process on the same host and session. Pinned
J 9.6.3 build 96 supplied the reference.

End-to-end medians from `pixi run compare-j --fetch-j`, per API call:

| Workload | 1,000 elements | 100,000 elements | Mojj / J at 100k |
| --- | ---: | ---: | ---: |
| double `+:` | 7.73 µs | 765 µs (7.65 ns/element) | 37× |
| sum `+/` | 15.74 µs | 1,614 µs (16.1 ns/element) | 147× |
| RMS | 23.90 µs | 2,284 µs (22.8 ns/element) | 65× |

J at 100k: 20.4 µs double, 11.0 µs sum, 34.9 µs RMS (0.20, 0.11 and
0.35 ns/element).

Controlled probes, 100,000 elements, same host:

| Path | Time | ns/element |
| --- | ---: | ---: |
| Bare Float64 loop, `List` indexing | 92 µs | 0.92 |
| Bare Float64 loop, `unsafe_ptr` | 59 µs | 0.59 |
| Bare Float64 loop, 4-wide `SIMD` | 47 µs | 0.47 |
| Serial add fold (either direction), `unsafe_ptr` | 100 µs | 1.00 |
| Serial fold, 8 independent accumulators | 12 µs | 0.12 |
| `noun.at(i).as_float()` loop | 690 µs | 6.90 |
| `Insert[Plus].monad` (boxed right fold) | 2,318 µs | 23.2 |
| `Expr["+/"].monad` | 2,493 µs | 24.9 |
| `Noun(list)` constructor (one copy) | 17 µs | 0.17 |
| Scalar `Noun` construction plus `as_float` | — | 1.0 |
| Dependency-chain calibration (`total += 1.0`) | 98 µs | 0.98 |

The measured cost is per element, not per call: Mojj's double workload costs
7.7 ns/element at both 1,000 and 100,000 elements. Fixed per-call overhead is
therefore not the problem, and small-input ratios are dominated by the same
per-element tax.

## Where the time goes

1. **Per-element `Noun` boxing and generic dispatch.** Map verbs construct one
   scalar `Noun` per input cell (and another per output cell); `Insert` builds
   two per step and re-enters `Verb.dyad`, which repeats dtype, rank and
   agreement checks. Measured tax relative to the typed loop: about 13× for
   map, 16× for sum, 23× for RMS. This is the dominant cost in all three
   workloads and the only change that moves all of them at once.
2. **Reduction order.** `Insert` is a strict right fold, one dependent
   floating-point add per element. A single accumulator cannot retire faster
   than add latency, measured at 0.98 ns/element on this host. At 100k that is
   ~100 µs, or ~9× J's 11 µs, no matter how the loop is written.
3. **Missing vectorization in elementwise loops.** Even the bare loop runs at
   0.59–0.92 ns/element, while 4-wide SIMD reaches 0.47. Small (2× at
   cache-resident sizes) next to the boxing tax, but it is what remains after
   the tax is removed.
4. **Copies.** `Noun(vector)` copies its argument, `as_floats()` copies the
   result, and some verbs copy whole vectors for identity. At 100k each copy is
   ~17 µs. Negligible today (2% of a 765 µs call) but up to ~25% of the
   projected post-fix map cost, so it belongs after the boxing fix, not before.
5. **Ruled out for now.** Parser and `Expr` compile-time dispatch add ~7%
   (`Expr["+/"]` 2,493 µs against a direct `Insert[Plus]` 2,318 µs), so
   rewriting parsing buys little. `List` indexing costs 0.33 ns/element more
   than `unsafe_ptr`, which matters only inside the vectorized kernels.

## The reduction-order decision

Mojj documents and tests a strict right fold. J does not preserve it for
floating-point sums. On a 4-element Float64 vector `1 1e16 _1e16 1`, J returns
`0`, while a strict right fold (and a strict left fold) returns `1`; J's answer
matches pairwise accumulation. On 100,000 elements J returns neither the strict
right-fold nor the strict left-fold result. J's float `+/` reassociates, and its
exact rounding depends on vector length and implementation.

Consequences:

- Removing boxing alone takes sum from 16.1 to ~1.0 ns/element: a 16× gain that
  still leaves ~9× against J.
- Reaching J-comparable sums (~0.12 ns/element) requires blocked, pairwise or
  SIMD accumulation, which changes results on cancellation-sensitive input.

This is a semantic choice, not a micro-optimization, and the plan does not
decide it silently:

| Option | Effect | Consequence |
| --- | --- | --- |
| A. Keep the strict right fold everywhere | Sum floor ~1.0 ns/element (~9× J at 100k) | No rounding change; sum stays visibly slower than J |
| B. Add a separately named blocked reduction; strict fold stays the default and the oracle | Sum ~0.12–0.2 ns/element, J-comparable | New documented surface; two summation answers exist |
| C. Make blocked accumulation the default | J-comparable, simplest surface | Changes Mojj's documented contract and existing expectations; must be a breaking change with migration notes |

Recommendation: **B**. It keeps the existing semantics and tests intact, makes
the faster rounding trade explicit in the API, and lets the blocked path be
cross-checked against the strict fold on cancellation-sensitive fixtures. Do not
adopt C without an explicit compatibility decision.

## Implementation order

Each slice is independently reviewable and gated on measurement. Stop after any
slice whose effect does not exceed the observed repeat variability.

1. **Harness v2 (no library change).** Add the matched controls used above
   (bare `List` loop, `unsafe_ptr` loop, SIMD loop, `at()` loop, direct boxed
   verb call) as a `pixi run perf-probes` task, keep the J comparison separate,
   and add scalar/empty/short-vector cases to catch fixed-cost regressions.
   Record host, load, compiler flags, samples and source revisions; inspect one
   hot kernel with `mojo build --emit asm`. Commit the probes and a short
   bottleneck report beside the implementation. *Gate:* reproduce the numbers
   above within repeat variability.
2. **Unboxed Float64 map path.** Give the arithmetic verbs an internal
   `Float64` monad kernel (`Squared`, `Doubled`, `Root`, plus the existing
   composition nodes) and make `Atop`/per-cell mapping fill a typed result list
   directly when the inner noun is Float64 and the verb has a kernel. Keep the
   generic `Noun` path as the oracle. *Projected:* double 7.65 → ~0.6–0.9
   ns/element, RMS 22.8 → ~1.0–1.5. *Gate:* identical values, dtype, rank,
   errors and descriptions on all existing and new cases.
3. **Unboxed Float64 right fold in `Insert`.** Read typed storage directly and
   call the verb's kernel, preserving the current fold order, initial element,
   singleton/scalar behavior and empty identity. *Projected:* sum 16.1 → ~1.0
   ns/element. *Gate:* bit-identical results to the generic path on
   cancellation-sensitive fixtures, not just within reference tolerance.
4. **Ownership and copies.** Add an internal move-taking noun constructor for
   freshly built result lists, stop copying in `as_floats()` consumers, and
   audit whole-vector copies in identity verbs. *Projected:* 17 µs per 100k
   call, plus allocation pressure. *Gate:* caller-owned input stays independent
   after the call; public copying constructors unchanged.
5. **Vectorized elementwise kernels.** Move the typed kernels to `unsafe_ptr`
   loops and 4-wide `SIMD` with scalar tails, where the assembly check shows it
   pays. *Projected:* 0.59 → 0.47 ns/element at 100k, 2× at cache-resident
   sizes. *Gate:* elementwise results stay bit-identical.
6. **Fast reduction (only if the reduction-order decision is B or C).** Blocked
   or multiple-accumulator summation behind the chosen surface, with fixtures
   showing exactly where it diverges from the strict fold. *Projected:*
   J-comparable at 100k.
7. **Re-measure and update `tests/reference/RESULTS.md`.** Report the ratio
   change, remaining gaps, and anything that did not reproduce. Do not remove
   the earlier baseline; keep it as history.

## Correctness gates for each library slice

- Run `pixi run test`, `pixi run demo`, `pixi run package-smoke`, and the
  documented [live J comparison](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/tests/reference/README.md).
  Preserve all 33 current expectations and all nine benchmark value, shape and
  dtype checks; add focused cases for whichever path changes.
- Cover atoms versus singleton vectors, empty identities and dtype, scalar
  extension versus unequal vector lengths, Boolean promotion, exact integers
  above 2**53, overflow and unsupported valences. Keep Mojj's documented
  differences from J; performance work must not silently alter compatibility.
- Keep the checked integer/Boolean paths out of the fast path. `Plus`, `Minus`
  and `Times` use `Int128` overflow checks per element; they are slower by
  design and must not inherit the Float64 kernel.
- Check subtraction's right fold, cancellation-sensitive floating sums, signed
  zero, NaN/infinity and domain failures against the existing implementation.
  Reference tolerance alone cannot establish unchanged rounding; compare the
  fast path bit-for-bit against the generic path.
- Reuse the same input across repeated calls and sizes; verify inputs remain
  unchanged, returned values remain independent, and descriptions preserve
  expression structure.

## Boundaries and handoff

No additional vocabulary, general array ranks, public mutation/buffer API,
toolchain upgrade, threads, GPU backend, approximate arithmetic, or broad
cleanup belongs in this effort. Benchmark diagnostics and focused tests belong
beside implementation; update this plan against actual commits as slices land.
The orchestrator reviews each slice, checks outgoing content and handles any
separately authorized implementation commit/push.

Planning validation on 2026-11-15: ran the pinned J comparison on this host
(33/33 expectations, nine benchmark comparisons), ran the probe programs and the
reduction-order check recorded in [the baseline evidence](evidence/performance-baseline.md),
and reran the existing test suite. No library source was changed, no profiler or
assembly audit was performed, and no Linux or CI result exists. Projections in
the implementation order are derived from measured raw-loop floors and are not
performance claims.
