# NuMojo comparison, 2026-11-15

This historical diagnostic compares Mojj with NuMojo 0.11.0, imported from
source into the same binary. It used Mojo 1.1.0 with
`--fp-mode contract=off` on an Apple M1, in one process and one session.
The harness was `build/numojo-bench/compare.mojo` in a scratch Pixi workspace;
it is not committed. The host was loaded, so the results support same-session
comparisons rather than portable absolute costs.

## Steady-state cost, 100,000 Float64 elements, ns/element

| Workload | Mojj | NuMojo |
| --- | ---: | ---: |
| map (`+:` / `array + array`) | 0.36 | 0.53 |
| square (`*:` / `array * array`) | 0.41 | 0.49 |
| strict right fold (`+/`) | 0.94 | n/a |
| `sum()` | n/a | 0.47 |
| RMS (`%: @: (+/ % #) @: *:` / `sqrt(mean(a*a))`) | 1.33 | 1.34 |

NuMojo is ~2x faster than Mojj's strict fold on `sum()`, and Mojj is ~1.4x
faster on the elementwise map. The recorded RMS costs are nearly equal at 100,000 elements.

## Reported fixed-cost estimates, ns/call

| Elements | Mojj `+/` | NuMojo `sum()` | Mojj `+:` | NuMojo `a+a` |
| ---: | ---: | ---: | ---: | ---: |
| 1,000 | 5.9 | 62 | 0.87 | 62 |
| 10,000 | 9.6 | 54 | 4.3 | 54 |

The original diagnostic labels these figures as fixed costs in ns/call,
but does not retain the harness or explain how fixed cost was separated
from per-element work. Treat them as unverified overhead estimates rather
than total call times. Object construction may contribute to the difference;
this report does not isolate that cost.

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

The tested NuMojo reduction is not a semantic replacement for Mojj’s strict
fold. Its recorded sum cost was about half Mojj’s at 100,000 elements, but
the cancellation fixture shows that the two can return different answers.
The faster sum alone does not justify replacing Mojj’s default reduction.

These results support retaining the strict fold as the default and reference
implementation. A reassociating reduction would need a separate, explicit
contract and new measurements. This scratch diagnostic does not establish
the cost of replacing the storage engine.
