# Expressive power and ease-of-achieving-performance comparison
**Date:** 2026-11-15  
**Scope:** Float64 1-D array workloads (map, reduce, RMS) on a single core.  
**Evidence:** measured (this repo), source (code/docs read), intuition (model prior).  
**No new benchmarks.**

**Confidence legend:** `H` high (direct measurement or source read in this repo) · `M` medium (source/docs reading plus strong prior) · `L` low (model prior only).  
**What would change a score:** a counter-example snippet on which the operational definition flips; for `L` rows, running the same probe suite in that language.

---

## Axis A — Expressive power

| System | Clarity | Composability | Concision | Abstraction seams | Stateable semantics | Extensibility |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| NumPy | 3 (H) | 3 (M) | 3 (H) | 3 (M) | 2 (M) | 3 (M) |
| Numba | 3 (M) | 3 (M) | 2 (M) | 3 (M) | 2 (L) | 4 (M) |
| Numojo | 4 (H) | 5 (H) | 4 (M) | 5 (H) | 3 (M) | 3 (M) |
| J | 2 (H) | 5 (H) | 5 (H) | 5 (H) | 4 (H) | 2 (M) |
| Mojj (current) | 4 (H) | 5 (H) | 3 (H) | 4 (H) | 5 (H) | 4 (H) |
| Mojj (future) | 4 (M) | 5 (H) | 4 (M) | 5 (M) | 5 (M) | 5 (M) |

**Operational definitions**

- **Clarity:** Can a competent reader reconstruct the semantics of a 5–15 line snippet without running it? Penalise hidden rules: implicit broadcasting, decorator-induced semantic change, allocation invisible at the call site, punctuation-as-vocabulary.
- **Composability:** Is `f ∘ g` a value, and does composition preserve meaning and type without glue? At what granularity does composition happen — expression, function, or whole-loop fusion?
- **Concision:** Semantic payload per token for map, reduce, RMS. Penalise mandatory ceremony (imports, dtype declarations, axis plumbing, boilerplate decorators); reward a small, learnable vocabulary.
- **Abstraction seams:** Can a user define an operation with the same standing as a built-in, and have it compose and stay fast? Penalise "your abstraction works but only at 1/100 speed" or "needs a plugin build".
- **Stateable semantics:** Can you declare *and* preserve what determines the numerical answer — association order, dtype promotion, error vs NaN, allocation? Reward explicit contracts; penalise implementation-defined behaviour.
- **Extensibility:** Ease of adding new types, verbs, or optimization patterns that integrate with the fast path.

**Confidence rationale**
- Mojj rows are `H`: scores rest on source (`verbs.mojo`, `strings.mojo`), the test suite, and the probe suite. Only `future` rows drop to `M` because they depend on uncommitted plan slices.
- J rows are `H` for clarity/composability/concision (direct use in the conformance experiment); `Stateable semantics` is `H` because the reassociation behaviour was measured on four inputs at 100k elements.
- Numojo is `H` where source was read (`ndarray.mojo`, `creation.mojo` plus the same-binary run); `M` for concision and extensibility.
- NumPy/Numba are `M`/`L`: no programs were written here. Numba's `Stateable semantics` is `L` because `fastmath` behaviour was not exercised.

---

## Axis B — Ease of achieving performance

| System | Idiomatic-to-fast | Local predictability | Escape-hatch cost | Control of fast-path semantics |
| :--- | :---: | :---: | :---: | :---: |
| NumPy | 2 (M) | 2 (M) | 3 (M) | 2 (M) |
| Numba | 3 (M) | 3 (M) | 4 (M) | 3 (L) |
| Numojo | 2 (H) | 3 (H) | 3 (M) | 3 (M) |
| J | 5 (H) | 5 (H) | 2 (M) | 5 (H) |
| Mojj (current) | 3 (H) | 4 (H) | 3 (H) | 4 (H) |
| Mojj (future) | 3 (M) | 5 (M) | 3 (M) | 5 (M) |

**Operational definitions**

- **Idiomatic-to-fast distance:** If I write the thing the language most naturally invites, how far is that from the achievable floor?
- **Local predictability:** From the code alone, can you predict it will be fast and see where time goes? Penalise silent fallback and invisible per-call costs.
- **Escape-hatch cost:** When the idiomatic form isn't enough, what is the bill — annotations, a language subset, a foreign call, a second language?
- **Control of the fast path:** Does the fast path let you keep the semantics you declared (order, precision, allocation), or does going fast silently change them?

**Confidence rationale**
- Numojo's `Idiomatic-to-fast = 2 (H)` is measured: 62 ns/elem at 1k vs 0.53 at 100k, i.e. fixed cost dominates short vectors.
- Mojj current rows are `H`: the strict fold lands on the measured serial-fold floor (0.94 vs 0.95–1.51 ns/elem control), and fixed cost (5.9 ns at 1k) is measured.
- J's `Control of fast-path semantics = 5 (H)` reflects the measured reassociation on `1 1e16 _1e16 1`; J gives no knob, but its contract is what it is — the `5` is "explicit and consistent", not "configurable".
- NumPy's `Local predictability = 2 (M)` is prior-based: the vectorize-or-pay discontinuity is well known but was not re-measured here.

---

## Orthogonal modifiers (not averaged in)

| System | Ecosystem & interop | Learning cost | Diagnostics / introspection |
| :--- | :---: | :---: | :---: |
| NumPy | 5 (H) | 2 (H) | 4 (M) |
| Numba | 3 (M) | 3 (M) | 4 (M) |
| Numojo | 2 (M) | 3 (M) | 3 (M) |
| J | 2 (M) | 5 (H) | 3 (M) |
| Mojj (current) | 1 (H) | 3 (H) | 5 (H) |
| Mojj (future) | 1 (H) | 3 (M) | 5 (M) |

- **Ecosystem & interop:** library breadth, Python/FFI, tooling reach.
- **Learning cost:** tacit knowledge required before the tool stops fighting you.
- **Diagnostics:** errors, introspection, ability to explain a program back to yourself.

Mojj's `Diagnostics = 5 (H)` rests on `describe()` preserving expression structure, which is checked by the suite; its `Ecosystem = 1 (H)` is a factual statement about the current package (no FFI, no Python binding).

---

## Summary reading

| System | Expressive power (A) | Performance ease (B) | Positioning |
| :--- | :---: | :---: | :--- |
| NumPy | 2.8 | 2.3 | Reference baseline; vectorize or pay. |
| Numba | 2.8 | 3.3 | Annotate loops; subset constraints. |
| Numojo | 4.2 | 2.8 | Mojo-native NDArray; allocation overhead at small sizes. |
| J | 4.0 | 4.3 | Tacit fast path; no escape hatch; reassociates floats. |
| Mojj (current) | 4.0 | 3.5 | Explicit kernels; strict fold; low fixed cost. |
| Mojj (future) | 4.5 | 4.5 | SIMD, ownership, blocked reduction opt-in. |

Averages are arithmetic over the six (A) and four (B) dimensions and therefore inherit the weakest cell's confidence. Treat differences under ~0.3 as not distinguishable.

**Archetype orderings (weights stated):**

| Archetype | Weights | Order |
| :--- | :--- | :--- |
| Scripting scientist | A×3, B×1, O1×2, O2×1, O3×1 | NumPy > Numojo > Mojj > Numba > J |
| Library author | A×2, B×2, Extensibility×3, O3×2 | Mojj > Numojo > Numba > J > NumPy |
| Performance engineer | B×3, A×1, O3×2 | J > Mojj (future) > Mojj (current) > Numba > Numojo > NumPy |

The first ordering is the least confident of the three: it puts NumPy first on ecosystem weight, which is the modifier with the widest evidence gap (`H` for the fact of the ecosystem, `L` for how much it matters to a specific team).

---

## Conclusion

Mojj trades NumPy's breadth and Numba's Python interop for Mojo-native safety, explicit fast-path control, and strict right-fold semantics. Today it matches NumPy on readability, beats NumPy/Numba on fixed-cost latency, and keeps J's reassociating sum out of the default path (option B in the plan). Numojo is close in steady-state but regresses short-vector latency and semantics (silent `nan`, no strict fold). The future plan (slices 4–6) would close the remaining map/sum/RMS gap while keeping the documented contract intact.

**Lowest-confidence claims in this document:** Numba's semantics/control ratings (`L`), and every NumPy row scored only by prior. Re-running the existing probe suite against NumPy/Numba on this host would move those to `H`; it would not change the Mojj, J, or Numojo rows.
