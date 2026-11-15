# NuMojo comparison, 2026-11-15

Scratch diagnostic: NuMojo 0.11.0 (the release published for Mojo 1.1.0)
imported into the same binary as Mojj from source, `--fp-mode contract=off`,
Apple M1, one process, one session. The harness was
`build/numojo-bench/compare.mojo` in a scratch pixi workspace; it is not
committed. The host was loaded, so only same-session ratios support a
conclusion, not absolute values.

## Steady-state cost, 100,000 Float64 elements, ns/element

| Workload | Mojj | NuMojo |
| --- | ---: | ---: |
| map (`+:` / `array + array`) | 0.36 | 0.53 |
| square (`*:` / `array * array`) | 0.41 | 0.49 |
| strict right fold (`+/`) | 0.94 | n/a |
| `sum()` | n/a | 0.47 |
| RMS (`%: @: (+/ % #) @: *:` / `sqrt(mean(a*a))`) | 1.33 | 1.34 |

NuMojo is ~2x faster than Mojj's strict fold on `sum()`, and Mojj is ~1.4x
faster on the elementwise map. RMS converges to parity at 100k.

## Fixed cost, ns/call

| Elements | Mojj `+/` | NuMojo `sum()` | Mojj `+:` | NuMojo `a+a` |
| ---: | ---: | ---: | ---: | ---: |
| 1,000 | 5.9 | 62 | 0.87 | 62 |
| 10,000 | 9.6 | 54 | 4.3 | 54 |

NuMojo pays ~50-60 ns per call constructing `NDArray` objects, so it loses on
short vectors even when its steady-state loop is faster. Mojj's per-call fixed
cost is 5-10 ns.

## Semantics that differ

- Reduction order. NuMojo's `sum()` reassociates: on `1 1e16 _1e16 1` it
  returns `0`; Mojj's strict right fold returns `1`. On a 100,000-element
  alternating `1e16 1 -1e16 1` input both return `0`.
- Domain failures. `sqrt(-1.0)` raises in Mojj
  ("Root monad rejects negative real values without Complex"); NuMojo returns
  `nan` silently.
- Empty and singleton. Both return `0.0` for an empty sum and the element
  itself for a singleton.

## Conclusion

NuMojo is not a drop-in under Mojj today. Adopting it for the reduction path
would buy the ~2x sum speedup but discard the strict right fold (a documented
Mojj contract, tested bit-for-bit) and the explicit domain-error semantics,
and it would regress short-vector latency and the elementwise map.

The performance plan's recommendation stands: keep the strict fold as the
default and oracle, and if J-comparable sum speed is required, add a separately
named blocked reduction (option B) behind an explicit surface rather than
swapping the storage engine.
