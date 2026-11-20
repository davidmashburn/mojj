# Float64 vector dot

On an Apple M4 running Darwin arm64 with Mojo 1.1.0 (8189361e), the candidate used less elapsed time than revision `5f160a4` for the public `Expr["+/ . *"].dyad` call in all 40 matched pairs of the first run and 39 of 40 in a second run. Both builds used the archived source tree, with only the candidate's Float64 vector path added. Each run used eight trials and alternated which binary ran first. Host load varied during these measurements.

The first run produced these paired elapsed-time ratios.

| Vector length | Calls per sample | Median candidate / baseline | Range |
|---:|---:|---:|---:|
| 1 | 10,000 | 0.403 | 0.244–0.762 |
| 8 | 2,500 | 0.101 | 0.015–0.311 |
| 128 | 180 | 0.044 | 0.003–0.084 |
| 4,096 | 8 | 0.024 | 0.013–0.343 |
| 32,768 | 3 | 0.014 | 0.001–0.029 |

The repeat produced median ratios of 0.448, 0.118, 0.038, 0.020, and 0.015 in increasing size order. The candidate took 1.19 times the baseline time in one length-eight sample.

Each sample starts with two prebuilt Float64 vectors and four warmup calls. The timed loop mutates one element before each call and accumulates every result. Sinks matched across all pairs. The specialized path still builds a product vector and transfers it to the usual reduction. It avoids constructing and assembling a separate Noun for each product. These observations describe this workload and host. The small number of repetitions for long vectors and wide ratio ranges limit estimates of the effect size.

To reproduce, set `BASE_SRC` and `CANDIDATE_SRC` to the two source directories that contain `mojj/` and run from the repository root. The driver requires a fresh output path.

```sh
pixi run mojo build --fp-mode contract=off -I "$BASE_SRC" tests/perf/dot/dot.mojo -o /tmp/mojj-dot-baseline
pixi run mojo build --fp-mode contract=off -I "$CANDIDATE_SRC" tests/perf/dot/dot.mojo -o /tmp/mojj-dot-candidate
python3 tests/perf/dot/compare.py /tmp/mojj-dot-baseline /tmp/mojj-dot-candidate /tmp/mojj-dot-samples.csv
```
