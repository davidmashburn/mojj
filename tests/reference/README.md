# Bounded comparison with J

This corpus compares Mojj's compiled `Expr` API against a checksum-pinned J
9.6.3 runtime. It establishes agreement on selected scalar/vector examples,
not parity with the J language or every input in the supported grammar.
J remains a development-only reference; library consumers do not need it.

## Reproduce

On macOS arm64, with Pixi installed:

```sh
pixi install --locked
pixi run test-reference-harness
pixi run compare-j --fetch-j --output build/reference/results.json
```

The checked-in final report is `tests/reference/results.json`. The command above
writes a fresh result under `build/` so it does not silently replace that report.

The first comparison downloads the official J archive into ignored
`build/reference/runtime`. Later runs can omit `--fetch-j`. Alternatively,
`--jconsole /path/to/j64/jconsole` accepts an existing runtime only when its
executable and both libraries match `runtime.json`. A Java `jconsole` is not
suitable. The archive URL uses a mutable release tag, so both the archive and
individual files are checked against SHA-256 pins; changed downloads fail closed.
Linux and other J releases are not covered by this pin.

The default `pixi run test` runs the Python harness checks without downloading
or executing J. The live comparison is an explicit task. Python, Mojo, and
other development dependencies resolve through `pixi.lock`.

## Conformance scope

`cases.json` contains 33 named cases: 30 successful value/shape agreements, one
shared shape error, and two deliberate domain differences (integer overflow
and complex-producing square root). It exercises hooks, forks, composition,
modifier binding, noun sentences, left/right binding, scalar extension, empty
reductions, Boolean arithmetic, and exact large integers. Read each input and
observed output in [results.json](results.json).

Values compare exactly whenever either output uses integer or Boolean storage,
including cross-dtype comparisons. Otherwise floating values use absolute and
relative tolerances of 1e-12; rank and element count must agree. Dtype is recorded separately: empty
sum/product have equal numeric identities but J returns Boolean and Mojj returns
Float64. Expected success/error status is explicit for each runtime, so a shared
unexpected failure cannot pass as an agreement. Error messages/categories are
not compared. Complex values are recorded only to demonstrate the unsupported
domain. NaN, infinity, signed zero, cancellation-sensitive sums, matrices, and
other unlisted J features are outside this corpus.

## Performance method

Three operations use the same Float64 inputs at 1,000, 10,000, and 100,000 elements:

- Double: `+:`
- Sum: `+/`
- Root mean square: `%: @: (+/ % #) @: *:`

Every output is compared before timing; benchmark dtypes must also match.
Each benchmark row records both output dtypes, ranks, and lengths. Inputs start at `(i mod 97) / 16`.
Each iteration changes the first cell to `(iteration mod 17) / 16`, applies the
operation, and consumes the first result cell in a checksum printed afterward.
The Mojo batch is marked `@no_inline`. These measures reduce the opportunity
for the compiler to remove repeated work; generated assembly was not audited.

Input construction, compilation, process startup, and output serialization are
outside the timers. Timings include the batch loop, first-cell update, operation,
result consumption, allocation, and destruction. This is an API workload
comparison, not an isolated kernel measurement. Runtime-specific mutation and
loop costs remain included. J may recognize and optimize derived expressions;
no attempt is made to disable its normal optimizations.

Each workload warms up twice, then doubles repetitions until a batch reaches
50 ms or 65,536 repetitions. Five subsequent batches provide raw per-call timings
and their median. A fast workload can reach the repetition cap before 50 ms.
All Mojj workloads run first, then all J workloads, without concurrency. These
are warm-cache measurements from one machine/session; there is no randomized
order, CPU affinity control, distribution study, or cross-platform validation.
Small workloads are especially sensitive to harness overhead. The legacy lazy
`core.mojo` API is not benchmarked.

Mojj is compiled with the pinned Mojo toolchain and `--fp-mode contract=off`;
J uses its published binary. Compiler settings and floating reduction kernels
are not identical. Results describe these implementations and workloads, not
Mojo versus J generally. Allocation/scalar traversal may explain some of the
gap, but no profiler evidence here establishes the cause.

[RESULTS.md](RESULTS.md) summarizes the initial and final runs, and retains the intervening noisy
repeat as evidence of variability and the limits on numerical speed claims. The JSON includes all five
samples, repetition counts, runtime hashes, hardware/toolchain metadata, source
revision, and SHA-256 fingerprints for the measured source and harness. The
revision is the checkout's base HEAD at measurement time; file fingerprints
identify the new harness and task configuration before their eventual commit.
Generated scripts, binaries, and full benchmark output stay in ignored
`build/reference`; no J binaries are committed.

Reference documentation: [official pinned release](https://github.com/jsoftware/jsource/releases/tag/build96),
[J timing primitives](https://www.jsoftware.com/help/dictionary/dx006.htm),
[J datatype query](https://www.jsoftware.com/docs/help807/dictionary/dx003.htm),
[J output controls](https://www.jsoftware.com/docs/help804/dictionary/dx009.htm),
and [Mojo monotonic timer](https://mojolang.org/docs/std/time/time/perf_counter_ns/).
