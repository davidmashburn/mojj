# Float64 rectangular dot

The benchmark calls `Expr["+/ . *"].dyad` with a Float64 matrix and vector in both operand orders. Each sample makes 26 calls, varying the first vector element over 13 values twice and summing every output element. Before timing, each binary checks the output shape, dtype and every element against a scalar right-fold oracle for all 13 inputs. The matrices contain exactly representable binary fractions.

Each of eight blocks runs the baseline and candidate once, alternating their order. Each matrix has 4,096 elements. The matrix-on-left cases qualify individually when the candidate wins at least seven blocks and its median paired elapsed time is at most 90% of baseline. Matrix-on-right controls exercise the existing implementation.

## Implementation decision

Mojj retains the guarded **matrix × vector** specialization from `c06d309`. Vector × matrix uses generic product assembly. Both candidate directions were first measured independently, then tested again after adding checks for shortened matrix storage. The final isolated M4 trial selected the implementation. The tables below distinguish that decision from preliminary timings.

| Isolated change | Matrix shape | M4 | Linux first | Linux repeat |
| --- | ---: | ---: | ---: | ---: |
| Matrix × vector | 128 × 32 | 0.0526 (8/8) | 0.0805 (8/8) | 0.0625 (8/8) |
| Matrix × vector | 32 × 128 | 0.0365 (8/8) | 0.0530 (8/8) | 0.0429 (8/8) |
| Vector × matrix | 128 × 32 | 0.2790 (8/8) | 0.4284 (8/8) | 0.3976 (8/8) |
| Vector × matrix | 32 × 128 | 0.3518 (6/8) | 0.3910 (8/8) | 0.3966 (8/8) |

Entries give median candidate/baseline elapsed time and paired wins. The guarded row change met the gate for both shapes on each host. Its opposite-orientation tall control took 5.7% and 5.4% longer in the Linux repeats, with zero candidate wins in both. The wide control medians increased by 0.7% and 1.2%. On M4 the control medians were 0.9782 and 1.0762. Allow for the Linux tall-control cost when assessing a mixed workload. The isolated column candidate missed the wide M4 gate. The hosts were Apple M4 and Intel Xeon 6975P-C, running Mojo 1.1.0.

Row samples: [M4](isolated-row-m4.csv), [Linux first](isolated-row-linux-first.csv), [Linux repeat](isolated-row-linux-repeat.csv). Column samples: [M4](isolated-column-m4.csv), [Linux first](isolated-column-linux-first.csv), [Linux repeat](isolated-column-linux-repeat.csv). [Hosted run](https://github.com/davidmashburn/mojj/actions/runs/44808598971)

## Preliminary Apple M4 results

On macOS 27.2 arm64 with Mojo 1.1.0 (8189361e), the row optimization met the gate for both matrix-on-left shapes against `fbf830b`. The two builds produced equal sinks in every pair. Load varied during measurement, and timings for the unchanged controls varied by more than a factor of two in both directions. [Raw samples](rectangular-samples.csv)

| Matrix position | Matrix shape | Median candidate / baseline | Paired range | Candidate wins |
| --- | ---: | ---: | ---: | ---: |
| Left | 128 × 32 | 0.0122 | 0.0055–0.0624 | 8/8 |
| Left | 32 × 128 | 0.0208 | 0.0019–0.0268 | 8/8 |
| Right | 128 × 32 | 0.8476 | 0.2428–2.4619 | 6/8 |
| Right | 32 × 128 | 0.8803 | 0.2048–2.2088 | 5/8 |

The second comparison used the row optimization as its baseline. Collecting the right matrix's products in Float64 storage met the same gate for both matrix-on-right shapes. The matrix-on-left implementation was identical between these builds. [Raw samples](rectangular-column-samples.csv)

| Matrix position | Matrix shape | Median candidate / baseline | Paired range | Candidate wins |
| --- | ---: | ---: | ---: | ---: |
| Left (control) | 128 × 32 | 1.0625 | 0.9374–3.9111 | 2/8 |
| Left (control) | 32 × 128 | 0.9137 | 0.3650–1.4952 | 6/8 |
| Right | 128 × 32 | 0.3202 | 0.0420–0.7400 | 8/8 |
| Right | 32 × 128 | 0.2401 | 0.1155–0.9714 | 8/8 |

## Preliminary Linux x86-64 results

Two eight-block comparisons ran on Ubuntu 24.04 with an Intel Xeon 6975P-C and Mojo 1.1.0 (8189361e). Each optimization was measured against its immediate parent. Every target shape won all eight paired blocks in each repeat. The table gives median candidate time divided by baseline time. [Hosted comparison](https://github.com/davidmashburn/mojj/actions/runs/44807036089)

| Optimization | Matrix shape | First run | Repeat |
| --- | ---: | ---: | ---: |
| Matrix × vector | 128 × 32 | 0.0590 | 0.0646 |
| Matrix × vector | 32 × 128 | 0.0408 | 0.0525 |
| Vector × matrix | 128 × 32 | 0.5013 | 0.4172 |
| Vector × matrix | 32 × 128 | 0.3971 | 0.3924 |

For the row optimization, the unchanged reverse orientation had median ratios of 1.0375 and 1.0281 on the tall matrix and 0.9992 and 1.0041 on the wide matrix. For the column optimization, the control medians ranged from 0.9848 to 1.0932. These samples resolve the large target effects more clearly than small changes in either control. Raw samples are available for [rows](rectangular-linux-row-first.csv), [row repeat](rectangular-linux-row-repeat.csv), [columns](rectangular-linux-column-first.csv) and [column repeat](rectangular-linux-column-repeat.csv).

## Guarded matrix storage and row-copy follow-up

The guarded implementation at `ec76c11` falls back to ordinary element access if the caller shortens a matrix's public Float64 storage. This preserves the catchable bounds error and any earlier cell error. Comparing both guarded paths together against the original implementation produced these results. Each entry is the median candidate/baseline time, followed by paired wins out of eight.

| Public call | Matrix shape | Apple M4 | Linux first | Linux repeat |
| --- | ---: | ---: | ---: | ---: |
| Matrix × vector | 128 × 32 | 0.0210 (8) | 0.0716 (8) | 0.0558 (8) |
| Matrix × vector | 32 × 128 | 0.0194 (8) | 0.0518 (8) | 0.0517 (8) |
| Vector × matrix | 128 × 32 | 0.5894 (6) | 0.5825 (8) | 0.5971 (8) |
| Vector × matrix | 32 × 128 | 0.3295 (7) | 0.3916 (8) | 0.3903 (8) |

[M4 samples](guarded-dot-m4.csv) · [Linux first](guarded-dot-linux-first.csv) · [Linux repeat](guarded-dot-linux-repeat.csv) · [Hosted run](https://github.com/davidmashburn/mojj/actions/runs/44808048458)

A three-second M4 sample of tall vector × matrix implicated the first-axis reduction, including row extraction and addition. Six rotated timing blocks on each shape compared the public call, building products with `Dot[Right,Times]`, and `Insert[Plus]` on precomputed products. Median elapsed times per call were respectively 1,236, 20 and 773 µs (128 × 32), and 662, 35 and 615 µs (32 × 128). Each method verified its outputs outside the timer. The timings have different result-handling costs and cannot be added to reconstruct the public call.

A follow-up candidate at `8bc5f7b` copied each Float64 matrix row directly for the existing reduction. Its guarded implementation missed the seven-win requirement on the wide M4 case and was removed. Both Linux repeats met the criterion. The candidate and its parent remain available for reproduction.

| Vector × matrix | Apple M4 | Linux first | Linux repeat |
| --- | ---: | ---: | ---: |
| 128 × 32 | 0.5599 (7) | 0.7332 (7) | 0.7181 (7) |
| 32 × 128 | 0.8564 (5) | 0.6486 (8) | 0.7362 (7) |

[M4 samples](row-copy-m4.csv) · [Linux first](row-copy-linux-first.csv) · [Linux repeat](row-copy-linux-repeat.csv)

## Reproduction

To reproduce, set `BASE_SRC` and `CANDIDATE_SRC` to the source directories containing `mojj/` and choose a fresh output path.

```sh
pixi run mojo build --fp-mode contract=off -I "$BASE_SRC" tests/perf/dot/rectangular.mojo -o /tmp/mojj-rect-base
pixi run mojo build --fp-mode contract=off -I "$CANDIDATE_SRC" tests/perf/dot/rectangular.mojo -o /tmp/mojj-rect-candidate
python3 tests/perf/dot/compare.py --rectangular /tmp/mojj-rect-base /tmp/mojj-rect-candidate /tmp/mojj-rect.csv
```
