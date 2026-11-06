# Recorded J comparison

All **33 conformance expectations passed** in the final run: 30 successful
value/shape agreements, one shared shape error, and two intentional differences.
J promotes the overflow example to floating point and produces a complex square
root; Mojj rejects both. Empty sum/product also differ in dtype (J Boolean, Mojj
Float64). This is selected-case evidence, not full subset or language parity.

Measured source revision: `f6b05c82ac3251876a2e8a8af394f52581ebfcee`.
Final run: `2026-11-06T22:04:24.391558+00:00`. Earlier run: `2026-11-06T21:48:40.920477+00:00`.
Host: Apple M4, macOS 27.0.1, arm64; Mojo 1.1.0 (8189361e).
Reference: J 9.6.3, with exact archive/binary hashes in each JSON report.

## Performance observations

J was faster in all nine comparisons in all three runs. An intermediate repeat
was heavily variable. A host check immediately after that repeat showed load averages of 114.76, 43.71, and 20.87
(one, five, and fifteen minutes). No unrelated processes were stopped.
The initial run did not record host load, so it is not proven idle either.
The final run records load averages before and after the comparison in its JSON.
It follows the review fixes for mixed integer/float equality and benchmark dtype
validation; all nine output dtypes also match.

**Treat these ratios as provisional observations, not stable performance claims.**
Confidence is high in the recorded case outcomes, moderate in the direction of
the performance gap for these workloads, and low in a portable numerical ratio.
An isolated, repeatable benchmark on a quiet host could change the magnitude
assessment; broader conformance cases could expose additional semantic gaps.

Median microseconds per API call (five batches each); Mojj/J greater than one
means J was faster:

| Operation | Elements | Initial Mojj µs | Initial J µs | Initial Mojj/J | Final Mojj µs | Final J µs | Final Mojj/J |
|---|---:|---:|---:|---:|---:|---:|---:|
| double | 1,000 | 5.79 | 0.37 | 15.5× | 7.26 | 0.37 | 19.4× |
| double | 10,000 | 56.76 | 1.83 | 31.1× | 69.84 | 2.27 | 30.8× |
| double | 100,000 | 570.85 | 16.25 | 35.1× | 743.44 | 21.69 | 34.3× |
| sum | 1,000 | 11.43 | 0.26 | 43.7× | 14.74 | 0.35 | 42.0× |
| sum | 10,000 | 113.80 | 0.65 | 174.9× | 188.93 | 0.86 | 219.0× |
| sum | 100,000 | 1147.42 | 7.42 | 154.7× | 1601.09 | 10.64 | 150.5× |
| rms | 1,000 | 17.49 | 0.46 | 37.8× | 23.10 | 0.52 | 44.6× |
| rms | 10,000 | 173.33 | 2.26 | 76.7× | 201.77 | 2.43 | 82.9× |
| rms | 100,000 | 1723.25 | 25.65 | 67.2× | 2232.22 | 25.76 | 86.6× |

All nine benchmark outputs agreed before timing in every run. Inputs are Float64
vectors. Timings include mutation, API evaluation, allocation/destruction, and
checksum consumption; compilation, startup, input setup, and serialization are
excluded. This is the compiled `Expr` API, not the legacy lazy API or a general
Mojo-versus-J comparison. No profiling or assembly audit establishes the cause.

[Final raw samples and conformance outputs](results.json) and
[initial raw run](results-initial.json) retain individual samples and fingerprints.
The [noisy intermediate run](results-noisy.json) is preserved too.
The initial run preceded added expected-status assertions and harness tests/task
configuration, so its harness fingerprints intentionally differ from the final
files. The final run also fixes cross-dtype integer comparison and records and
enforces benchmark dtype equality. The timed workload logic is the same; timing
constants were centralized. Source library fingerprints are identical across runs.

## Validation and limits

`pixi run test`, `pixi run demo`, and `pixi run package-smoke` passed in an
isolated checkout. This includes 36 negative compiler fixtures; all 11 Python harness checks also passed after
review fixes. The runtime was downloaded and checksum-verified, and the final
explicit live task reverified its files, passed 33/33 expectations, and checked all nine benchmark outputs.
The compiler still emits existing unreachable-code warnings for compile-time
assertion branches.

No Linux execution, remote CI, exhaustive IEEE tests, full-J suite, memory
profiling, assembly audit, or quiet-host timing study was performed. General
arrays, additional J grammar, other J versions, and the legacy API remain
outside this comparison. See [method and reproduction steps](README.md).
