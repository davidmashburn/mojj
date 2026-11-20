# Float64 dot with mixed operand orders

This benchmark compares the retained matrix × vector optimization (`c06d309`) with its baseline (`15a1b77`) through the public `+/ . *` expression. Each timed batch uses one matrix shape and makes 100 calls. For each share shown below, that many calls use the matrix on the left, evenly spaced among the vector × matrix calls. The measured loop varies the first vector element and sums every output. Before timing, the driver checks the dtype, shape and every output element against a scalar right fold for all 13 input variants in both directions.

## Estimates from isolated timings

For each [isolated pair](rectangular.md), let S be the matrix × vector time saved per call and C the extra vector × matrix time per call. S was positive in every pair. Assuming the two costs add, the break-even matrix × vector share is C / (C + S) when C is positive and zero otherwise. Above the seventh sorted threshold the candidate would win at least seven of the eight observed pairs under that assumption.

| Sample | Shape | Median threshold | Seventh threshold |
| --- | --- | ---: | ---: |
| Linux first | 128 × 32 | 7.31% | 18.94% |
| Linux repeat | 128 × 32 | 7.61% | 8.05% |
| M4 | 128 × 32 | 14.92% | 49.39% |
| Linux first | 32 × 128 | 1.11% | 1.25% |
| Linux repeat | 32 × 128 | 1.99% | 5.13% |
| M4 | 32 × 128 | 16.52% | 57.51% |

## Measured batches

Each cell reports the median candidate/baseline elapsed-time ratio and the number of faster candidate batches out of eight paired trials. A ratio below 1 favors the retained implementation. Build order alternates across pairs. Both Linux samples used Mojo 1.1.0 on the same Intel Xeon 6975P-C runner in succession. The Apple M4 host was under heavy load (one-minute load averages of 191 before timing and 201 afterward).

| Shape | Matrix × vector calls per 100 | Linux first | Linux repeat | M4 |
| --- | ---: | ---: | ---: | ---: |
| 128 × 32 | 0 | 0.993 (5/8) | 1.011 (2/8) | 0.918 (5/8) |
| 128 × 32 | 5 | 0.962 (7/8) | 0.978 (7/8) | 2.507 (3/8) |
| 128 × 32 | 10 | 0.930 (7/8) | 0.942 (7/8) | 1.176 (3/8) |
| 128 × 32 | 50 | 0.617 (8/8) | 0.626 (8/8) | 0.552 (6/8) |
| 32 × 128 | 0 | 0.979 (5/8) | 1.007 (3/8) | 0.618 (6/8) |
| 32 × 128 | 5 | 0.961 (7/8) | 0.971 (7/8) | 0.545 (6/8) |
| 32 × 128 | 10 | 0.929 (7/8) | 0.945 (8/8) | 0.687 (6/8) |
| 32 × 128 | 50 | 0.621 (8/8) | 0.633 (8/8) | 0.551 (5/8) |

[Linux first](mixed-linux-first.csv) · [Linux repeat](mixed-linux-repeat.csv) · [Apple M4](mixed-m4.csv) · [Hosted run](https://github.com/davidmashburn/mojj/actions/runs/44816253874)

On Linux, five matrix × vector calls per hundred was the smallest tested share with seven faster pairs on both shapes in both runs. At zero the median moved across parity between runs. The measured batches therefore do not establish an exact crossover. At an even split the Linux median time fell by 37–38% on both shapes. No M4 mix reached seven faster pairs. An application estimate needs its observed shape and operand-order frequencies, and an M4 estimate needs a quieter repeat.

## Linux replication

A [second hosted run](https://github.com/davidmashburn/mojj/actions/runs/44831504715) used the same archived implementations and driver after the comparison runner began validating pairs before saving them. At five matrix × vector calls per hundred, both shapes won 8/8 in the first sample. In the repeat the tall shape won 8/8 and the wide shape won 6/8. At ten and fifty calls both shapes won 8/8 in both samples. Across all four Linux samples, ten was the smallest tested share that won at least seven pairs on both shapes every time. The exact crossover between tested shares remains unknown.

[Replication first](mixed-linux-confirm-first.csv) · [Replication repeat](mixed-linux-confirm-repeat.csv)

## Reproduction

Use the pinned Pixi environment. Set `BASE_SRC` and `CANDIDATE_SRC` to the respective archived `src` directories and choose a fresh CSV path.

```sh
pixi run mojo build --fp-mode contract=off -I "$BASE_SRC" tests/perf/dot/mixed.mojo -o /tmp/mojj-mixed-base
pixi run mojo build --fp-mode contract=off -I "$CANDIDATE_SRC" tests/perf/dot/mixed.mojo -o /tmp/mojj-mixed-candidate
python3 tests/perf/dot/compare.py --mixed /tmp/mojj-mixed-base /tmp/mojj-mixed-candidate /tmp/mojj-mixed.csv
```
