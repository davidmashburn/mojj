# Numerical composition: expressiveness and measured performance

The recorded experiments compare Mojj with J and NuMojo on Float64 vector
maps, sums, and root mean square (RMS). They support workload-specific
observations about cost and semantics. They do not establish a general library
ranking or a performance comparison with NumPy or Numba.

The original assessment was written on November 15, 2026. Its numerical
scores combined measurements, source inspection, and subjective judgments.
This version separates those kinds of evidence and links to later experiments
where the implementation has changed.

## What the measurements establish

| Comparison | Recorded observation | Limit |
| --- | --- | --- |
| Mojj and J | After Float64 specialization, Mojj/J elapsed-time ratios ranged from 1.04× to 10.97× across nine map, sum, and RMS workloads. J was faster in each. | One loaded Apple M1 session; costs include allocation and input copying. |
| Mojj and NuMojo 0.11.0 | At 100,000 elements, Mojj double cost 0.36 ns/element and NuMojo addition cost 0.53. Mojj strict sum cost 0.94 and NuMojo sum cost 0.47. RMS cost 1.33 and 1.34 respectively. | A same-binary scratch diagnostic; its harness was not committed. Sum semantics differ. |
| Mojj and bare Mojo controls | Specialized Float64 sum was close to the serial-fold control and much faster than the generic boxed fold in the recorded session. | Matched controls help identify costs; they do not prove an absolute performance floor. |
| Mojj and NumPy or Numba | No matched timing experiment is recorded in this comparison. | No latency or throughput ranking is supported. |

See the [probe method and J ratios](README.md), the
[NuMojo diagnostic](numojo-comparison.md), and the earlier
[33-case J report](../reference/RESULTS.md). These reports cover different
revisions and sessions; their absolute times should not be combined into a
single ranking.

Later work separately measured the [public map boundary](README.md#public-float64-map-boundary-2026-11-20),
[input ownership](ownership.md), [double SIMD](simd/README.md),
[square SIMD](simd/square/README.md), and [dot products](dot/README.md).
The square trial retained the scalar path. A promising first run alone did
not justify selecting a SIMD implementation.

## How to assess expressiveness

Expressiveness depends on the reader and the task. Use these questions to
compare concrete implementations rather than assigning an overall score:

- **Clarity:** Can the intended reader predict the result and the effect of a
  likely edit? Include indexing, shape agreement, and modifier binding.
- **Composition:** Can an intermediate calculation be named, inspected, and
  reused without changing its meaning?
- **Concision:** Which notation expresses the required decision with the least
  reading effort? Count required vocabulary and setup as well as characters.
- **Extension:** Can a user-defined operation compose through the same public
  interface? Check its behavior and cost before assuming built-in parity.
- **Numerical contract:** Are accumulation order, dtype transitions, empty-input
  behavior, and errors clear enough to test?

The [side-by-side recipes](../../docs/SHOWCASE.md) provide examples in NumPy,
MATLAB, NuMojo, Mojj, and J. The [algorithm walkthrough](../../docs/ALGORITHMS.md)
uses a filter and a training step to show which decisions each notation makes
visible. Those examples support a reading comparison, not a speed ranking.

Mojj's `describe()` retains expression structure. Its word and symbolic
spellings share a parser and typed verb model. These are inspectability and
composition features; neither guarantees that a new reader will find a phrase
clearer than familiar array code.

## Semantics constrain optimization

The compiled J expression API groups insertion from the right. Its Float64
sum therefore cannot use arbitrary reassociation while promising the same
answer. The NuMojo diagnostic records a cancellation-sensitive input on which
its sum and Mojj's strict sum differ. Comparing their elapsed times does not
make them interchangeable implementations of one numerical contract.

The typed composition API is separate: `Sum` and `Mean` accumulate from left
to right, and typed `Mean` rejects empty input. Derived J mean returns zero on
an empty vector. See the [compatibility ledger](../../docs/COMPATIBILITY.md)
for supported domains and intentional differences from J.

A blocked reduction could trade strict ordering for parallel accumulation,
but it would need a separate contract and measurements. Proposed complex
storage, broader algorithms, or other future features cannot count toward the
capability of the current package.

## Confidence and remaining questions

Confidence is high that the reports record the stated workload outcomes,
moderate in their attribution of costs, and low in any portable performance
ratio. A quiet-host repeat, a changed implementation, or different input sizes
could change the performance assessment. The scratch NuMojo harness limits
independent verification of that comparison.

A broader choice of library needs evidence beyond map, sum, and RMS: the
required algorithms and dtypes, integration with the surrounding application,
and the team's familiarity with the notation. None of the recorded timings
settles those questions. A NumPy or Numba performance claim would require
matched implementations with explicit numerical contracts and timing methods.
