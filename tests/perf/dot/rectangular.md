# Float64 rectangular dot

The benchmark calls `Expr["+/ . *"].dyad` with a Float64 matrix and vector in both operand orders. Each sample makes 26 calls, varying the first vector element over 13 values twice and summing every output element. Before timing, each binary checks the output shape, dtype and every element against a scalar right-fold oracle for all 13 inputs. The matrices contain exactly representable binary fractions.

Each of eight blocks runs the baseline and candidate once, alternating their order. Each matrix has 4,096 elements. The matrix-on-left cases qualify individually when the candidate wins at least seven blocks and its median paired elapsed time is at most 90% of baseline. Matrix-on-right controls exercise the existing implementation.

## Apple M4 results

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

## Linux x86-64 results

Two eight-block comparisons ran on Ubuntu 24.04 with an Intel Xeon 6975P-C and Mojo 1.1.0 (8189361e). Each optimization was measured against its immediate parent. Every target shape won all eight paired blocks in each repeat. The table gives median candidate time divided by baseline time. [Hosted comparison](https://github.com/davidmashburn/mojj/actions/runs/44807036089)

| Optimization | Matrix shape | First run | Repeat |
| --- | ---: | ---: | ---: |
| Matrix × vector | 128 × 32 | 0.0590 | 0.0646 |
| Matrix × vector | 32 × 128 | 0.0408 | 0.0525 |
| Vector × matrix | 128 × 32 | 0.5013 | 0.4172 |
| Vector × matrix | 32 × 128 | 0.3971 | 0.3924 |

For the row optimization, the unchanged reverse orientation had median ratios of 1.0375 and 1.0281 on the tall matrix and 0.9992 and 1.0041 on the wide matrix. For the column optimization, the control medians ranged from 0.9848 to 1.0932. These samples resolve the large target effects more clearly than small changes in either control. Raw samples are available for [rows](rectangular-linux-row-first.csv), [row repeat](rectangular-linux-row-repeat.csv), [columns](rectangular-linux-column-first.csv) and [column repeat](rectangular-linux-column-repeat.csv).

## Reproduction

To reproduce, set `BASE_SRC` and `CANDIDATE_SRC` to the source directories containing `mojj/` and choose a fresh output path.

```sh
pixi run mojo build --fp-mode contract=off -I "$BASE_SRC" tests/perf/dot/rectangular.mojo -o /tmp/mojj-rect-base
pixi run mojo build --fp-mode contract=off -I "$CANDIDATE_SRC" tests/perf/dot/rectangular.mojo -o /tmp/mojj-rect-candidate
python3 tests/perf/dot/compare.py --rectangular /tmp/mojj-rect-base /tmp/mojj-rect-candidate /tmp/mojj-rect.csv
```
