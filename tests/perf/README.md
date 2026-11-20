# Performance probes and bottleneck report

Matched-control microbenchmarks for the compiled `Expr` API. They exist so a
change can be attributed instead of guessed at: each library path is printed
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
  cell is consumed so nothing is optimized away.
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
0.9–1.1 ns for `+/`, and from 23 to 1.3–1.5 ns for RMS. The remaining sum gap
is the strict right fold: J reassociates float `+/`, Mojj does not. The 10,000
and 100,000 sum rows are the honest cost of that documented choice, not a
regression. Closing them requires a separately named blocked reduction
(option B in the plan), not more unboxing.

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
allocation. The fold sits on the strict serial-fold floor: a dependent `fadd`
chain, which is a hardware limit for preserving order, not slack in the code.
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
under load, so the fixed cost is allocation and `Noun` scaffolding, not
arithmetic. That is slice 4 (ownership and copies), and it is the right place
to attack short-vector latency.

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
