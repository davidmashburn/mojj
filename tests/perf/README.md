# Performance probes and bottleneck report

These microbenchmarks compare the compiled `Expr` API with matched controls
to help identify where evaluation time goes: each library path is printed
next to a bare-Mojo loop that does the same arithmetic, in one process, on one
host. This is a diagnostic, not a test; `pixi run test` does not run it.

```sh
pixi run perf-probes          # builds tests/perf/probes.mojo and runs it
pixi run compare-j            # separate: live-J conformance and timings
```

`perf-probes` prints a header with date, host, CPU, load average, git revision,
dirty-path count, Mojo version and flags before the numbers. Record the header
with any result you quote; absolute values are not portable and move with host
load.

## What the rows mean

- `control raw_*` — bare `List[Float64]` loops: indexing, `unsafe_ptr`, 4-wide
  `SIMD`, a strict serial fold, an 8-accumulator blocked fold, `Noun.at()`
  boxing, a direct boxed `Plus.dyad` fold, and one `Noun(list)` copy. These
  bound what the library can cost on the same host.
- `Insert[PlainPlus]` — a verb with no Float64 kernel in the same binary, so it
  runs the generic `Noun` path. It is the fast path's matched control.
- `Expr[...]` rows — the compiled expression API, which is what the reference
  harness measures.
- Fixed-cost rows at 0/1/4/16 elements catch per-call regressions that are
  invisible at 100,000 elements.

## Method

- Apple M1, 8 cores, macOS 26.2, Mojo 1.1.0, `--fp-mode contract=off`.
- Built with `mojo build`; 100,000-element rows are the mean of 100 timed calls
  after one warm-up, fixed-cost rows the mean of 20,000 calls. The first result
  cell is consumed to reduce the opportunity for dead-code elimination.
- The host is shared, not quiet. Load averages during these runs were 2–6 with
  other applications active. The bare controls moved up 30–50% between the
  baseline session and the post-change session, so only same-session ratios
  support a conclusion.
- J ratios come from `pixi run compare-j` in the same session, pinned J 9.6.3
  build 96, 33/33 conformance expectations and all nine benchmark value, shape
  and dtype checks.

## End-to-end against J, 2026-11-15

Ratios are Mojj/J; lower is better. "Before" is the recorded baseline from the
same M1 session before the unboxing slices; "after" is the same harness after
the Float64 map path and right fold landed. Both columns include allocation,
destruction and the input `Noun` copy.

| Workload | Elements | before | after |
| --- | ---: | ---: | ---: |
| double `+:` | 1,000 | 17.1× | 1.04× |
| double `+:` | 10,000 | 26.3× | 1.30× |
| double `+:` | 100,000 | 37.5× | 2.10× |
| sum `+/` | 1,000 | 39.6× | 2.35× |
| sum `+/` | 10,000 | 177× | 10.97× |
| sum `+/` | 100,000 | 147× | 9.44× |
| RMS | 1,000 | 35.9× | 2.32× |
| RMS | 10,000 | 48.9× | 3.55× |
| RMS | 100,000 | 65.4× | 3.97× |

Mojj's per-element cost fell from 7.6 to 0.5–0.6 ns for `+:`, from 15.7 to
0.9–1.1 ns for `+/`, and from 23 to 1.3–1.5 ns for RMS.
The strict right fold is consistent with a remaining sum bottleneck: J can
reassociate floating `+/`, while Mojj preserves right grouping. The serial
controls and assembly check below support that interpretation, but do not
establish the cause of the entire gap. A blocked reduction would need a
separate numerical contract because reassociation can change results.

## Attribution at 100,000 elements, after the slices

| Path | ns/element |
| --- | ---: |
| control raw index loop | 1.45–1.50 |
| control raw `unsafe_ptr` loop | 1.14–1.47 |
| control raw 4-wide `SIMD` loop | 0.25–0.36 |
| control strict serial fold | 0.95–1.51 |
| control 8-accumulator blocked fold | 0.12–0.17 |
| control `Noun.at()` loop | 6.95–7.18 |
| control boxed `Plus.dyad` fold | 26.2–28.8 |
| control `Noun(list)` copy | 0.17–0.19 |
| `Expr["+:"]` | 0.50–0.59 |
| `Expr["+/"]` | 0.88–1.19 |
| `Insert[PlainPlus]` (generic fold control) | 24.6–33.6 |
| `Insert[Plus]` | 0.88–1.12 |
| `Expr["%: @: (+/ % #) @: *:"]` | 1.33–1.50 |

The map path now sits at the bare typed-loop cost plus one result-list
allocation. The fold is close to the measured strict serial-fold control.
The assembly shows a dependent `fadd` chain, which limits opportunities for parallel
accumulation while preserving order.
The RMS row is `square` (map) plus `sum` (fold) plus two scalar steps.

## Fixed-cost rows, ns/call

| Elements | `+/` | `+:` | RMS |
| ---: | ---: | ---: | ---: |
| 0 | 5.4 | 5.5 | 21.8 |
| 1 | 5.5 | 64.1 | 76.0 |
| 4 | 6.1 | 67.0 | 78.5 |
| 16 | 9.7 | 75.6 | 92.9 |

Scalar reductions cost about 6 ns. Vector-returning maps cost about 65 ns even
for one element, because the call allocates a result list and constructs a
`Noun`. On this host one small `List[Float64]` allocation measured 51–77 ns
under load, consistent with allocation and `Noun` construction contributing
much of the fixed cost. These controls do not isolate every component. See the later
[ownership probe](ownership.md) for input-transfer and identity-map results.

## Assembly check

`mojo build --fp-mode contract=off -I src --emit asm <program> -o probe.s` for a
program containing only `Expr["+/"].monad(...)` shows the fold as a dependent
scalar `fadd d13, d13, ...` chain inside the loop, with no `SIMD` accumulate.
That is the expected and required shape for a strict right fold; if a future
change makes this vectorized, the fold order changed.

## Limits

- These are single-host, single-session measurements on a loaded machine. They
  support before/after ratios and path attribution, not cross-machine claims.
- The probes time the API call; they do not separate allocation from arithmetic
  beyond the controls listed here.
- Values, dtype, rank, descriptions and errors are checked by
  `pixi run test` (`test_float64_kernel_fast_paths` and the existing suites),
  not by this program. `pixi run compare-j` covers live-J conformance.
- What would change the conclusion: a quiet-host rerun where the bare controls
  land within 10% of the recorded baseline, or a change in the sum ratio
  without a change in fold order.

## Public Float64 map boundary, 2026-11-20

The boundary probe compares `Expr["+:"].map(data)` with the previous
implementation, `Expr["+:"].monad(Noun(data)).as_floats()`. Both copy the
caller’s list on entry, perform the same elementwise double and consume one
indexed result per call. The public path transfers the owned Float64 result
list on exit. The control allocates and fills a second output list.

| Elements | Explicit result copy, median per call | Public map, median per call |
| ---: | ---: | ---: |
| 1 | 382 ns | 252 ns |
| 16 | 510 ns | 313 ns |
| 100,000 | 492 µs | 91 µs |

Measured on Darwin arm64, Apple M4, Mojo 1.1.0 (8189361e),
`--fp-mode contract=off`, at 08:14 UTC on November 20. The working tree
was based on `13336b8` with the map and probe edits. Initial load averages
were 37.21, 27.65 and 27.70. Three invocations of the same binary each timed
two batches per path in reversed order. Each short-vector batch used 20,000
calls and each large-vector batch used 100. At 100,000 elements the six copy
batches ranged from 377–519 µs and the six transfer batches from 72–116 µs.
Short-vector timings were noisier. These results apply to the list-returning
map API. The J comparison calls the noun API directly.

## Float64 double SIMD trials

[Ten matched comparisons](simd/README.md) cover raw kernels, the public map
boundary, scalar tails and width selection on an Apple M4. The report includes
the selection rule, paired measurements and reproduction command.

## Shared mean and population variance

Run `pixi run perf-moments` to check numerical fixtures and time three ways
to compute the mean and population variance of a lazy Float64 square map.

- **Independent** runs the existing left-to-right `Mean`, then reads the source again for the variance from `PopulationMoments`.
- **Shared** calls the public `PopulationMoments[Source].evaluate(data)` once. Welford's recurrence retains the rounding residual of each mean update. For adjacent values `1e16` and `1e16 + 2`, the returned mean rounds to `1e16` and the variance is exactly one.
- **Corrected two-pass** calls the existing `Mean`, then sums squared deviations and residuals in a second pass. Subtracting the squared average residual corrects the variance around the rounded mean. The method is a benchmark control. Its subtraction can lose precision when the variance is small relative to the correction.

All three read the same inputs and return both outputs. The independent and
two-pass means match the existing `Mean` rounding. For `[1e16, 1, 1]`, that
mean is `3333333333333333.5` and the shared mean is `3333333333333334.0`.
The benchmark checks a shifted reference and analytical constant, cluster and
outlier fixtures. Each timed call perturbs one input and consumes both outputs.
Each size has 12 matched samples covering all six orders twice.

Median microseconds per call on Apple M4, macOS 27.2 arm64, Mojo 1.1.0
(8189361e), main at `7233ced` plus these changes, with contraction disabled:

| Run (seed) | Elements | Independent | Shared | Corrected two-pass |
| --- | ---: | ---: | ---: | ---: |
| A (906) | 1,000 | 11.55 | 10.15 | 2.37 |
| A (906) | 100,000 | 1,160.63 | 1,001.14 | 231.01 |
| B (81) | 1,000 | 11.84 | 10.19 | 2.22 |
| B (81) | 100,000 | 1,373.33 | 1,170.88 | 311.30 |

The two-pass control beat the shared kernel in all 48 matched samples. Its
median paired speedup ranged from 3.80× to 4.56× across runs and sizes. The
public one-pass operation suits callers who need exactly one source evaluation
per element. A more expensive map changes the cost of that second evaluation.
[Run A samples](moments-samples.csv) and [run B samples](moments-repeat.csv)
include order and checksums.

The [original prototype experiment](moments-prototype-samples.csv) compared an
uncompensated online mean with independent reductions (seed 652). Its 1.18× and
1.16× speedups predate the adjacent-value fix and the two-pass control.

The [Float64 vector dot report](dot/README.md) measures public dot products with a typed intermediate and includes the paired samples and reproduction commands.
