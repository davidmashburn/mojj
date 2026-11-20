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

## Reproduction

To reproduce, set `BASE_SRC` and `CANDIDATE_SRC` to the source directories containing `mojj/` and choose a fresh output path.

```sh
pixi run mojo build --fp-mode contract=off -I "$BASE_SRC" tests/perf/dot/rectangular.mojo -o /tmp/mojj-rect-base
pixi run mojo build --fp-mode contract=off -I "$CANDIDATE_SRC" tests/perf/dot/rectangular.mojo -o /tmp/mojj-rect-candidate
python3 tests/perf/dot/compare.py --rectangular /tmp/mojj-rect-base /tmp/mojj-rect-candidate /tmp/mojj-rect.csv
```
