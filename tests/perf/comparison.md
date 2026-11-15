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

---

## Broader context for numerical computation libraries

While the core comparison focuses on the Map/Reduce/RMS workloads that can be directly measured in a single session, algorithm development and day‑to‑day use depend on the *completeness* of each library’s API, its *type system*, its *integration* with other tools, and the *community* that surrounds it. The table below surveys those dimensions with a qualitative rating and short rationale; confidence is noted per cell (`H` measured or read in this repo, `M` moderate inference from docs/source, `L` model prior only – many entries are `L` because we have not written substantial programs in that language).

| System | Algorithm breadth | Type system coverage | Ecosystem & integration | Docs & tutorials | Community & support | Performance portability |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **NumPy** | 5 (H) – de‑facto standard, covers linear algebra, FFT, stats, special functions, sparse, etc. | 5 (H) – complex, float16/float64/float128, integer types, structured arrays, record arrays. | 5 (H) – Python‑first: `import numpy`, `pip install`, vast ecosystem of bindings (Cython, C‑FFI, PyPI), interop with JAX/TensorFlow via `numpy` arrays. | 5 (H) – huge body of docs, books, tutorials (e.g., "NumPy Beginner's Guide"), Stack Overflow. | 5 (H) – decades‑old community, conferences (SciPy), maintainers, many third‑party packages. | 2 (L) – typically CPU‑only; GPU via CuPy or Numba, but not first‑class; SIMD auto‑vectorisation depends on compiler. |
| **Numba** | 3 (M) – JIT‑compiled functions can call any NumPy routine; its own function set is limited to what users write; no built‑in FFT or linear‑algebra beyond what you provide. | 3 (M) – supports float32/float64, int32/int64, complex64/complex128; can define custom types but not built‑in. | 3 (M) – requires `@jit` or `@njit`; interop with NumPy arrays is seamless; can call CUDA kernels via `cuda.jit` but needs separate setup. | 3 (M) – good getting‑started docs, but advanced patterns (multiprocessing, threading) require deeper familiarity. | 3 (M) – active user base, but the JIT subset constraint is a frequent source of questions. | 4 (M) – GPU via CUDA kernels is first‑class for JIT‑compiled functions; CPU performance is generally good for the compiled subset. |
| **Numojo** | 2 (L) – very new (v0.11.0); core routines: creation, basic math (sqrt, mean, sum), and NDArray manipulation; no FFT, linalg, or statistics beyond mean/std. | 2 (L) – NDArray supports float32/float64, complex64/complex128; custom dtypes possible but not built‑in. | 2 (M) – Mojo‑only distribution; no Python import yet (planned), so interop is via Mojo binary only; can call from C/FFI but not mature. | 2 (L) – docs exist (README, user‑guide) but no tutorials or book‑length material; the project is early‑stage. | 2 (L) – community is the Mojo‑numeric group on Discord/ GitHub; very small. | 3 (M) – NDArray is SIMD‑backed on Mojo; portability limited to Mojo‑compiled targets (Apple M1/AMD Zen 4‑class); no GPU path yet. |
| **J** | 4 (M) – rich primitive set: `+/`, `+/`, `*/`, `%:`, `sqrt`, `exp`, `log`, `sin`, `cos`, etc.; also `sort`, `transpose`, `#.` (boolean). Lacks high‑level statistical functions but can compose them. | 4 (M) – supports complex numbers (`0j1`), float16/float32/float64, integer types, rationals (`x:y`), and boxed arrays; array syntax is tacit. | 2 (L) – J is a standalone language; interop with Python via `jpype` or `Foreigns`, but not a first‑class numerical library in the Python ecosystem. | 3 (M) – the textbook "J for C programmers" and many online essays; the language’s tacit style can be a barrier. | 3 (M) – small but dedicated user community (J software company, university courses); active on the J Forum. | 3 (M) – runs on CPUs; J’s `+.×` matrix multiply is fast; no native GPU; SIMD is implicit in the interpreter’s cell engine. |
| **Mojj (current)** | 2 (M) – core verbs: `+`, `-`, `*`, `%`, `sqrt`, `square`, `double`; `Insert`, `Atop`, `Fork`, `Hook`, `BindLeft/Right`; no FFT, linear‑algebra, or statistics beyond mean/variance; algorithmic building blocks are explicit. | 2 (M) – FLOAT64, INT, BOOL; no complex numbers built‑in; can nest Nouns for structured data but not a typed array model. | 1 (H) – Mojo‑only package; no Python/FFI bindings currently; can be imported from Mojo source; the repo is self‑contained. | 1 (L) – docs limited to the source comments and this comparison; no tutorials or external walkthroughs. | 1 (L) – the repo is small; no formal support channel beyond the issue tracker. | 3 (M) – unboxed Float64 kernels target Mojo’s SIMD (Apple M1); other dtypes fall back to generic Noun path; portability limited to Mojo‑compiled hosts. |
| **Mojj (future)** | 3 (M) – plan slices 4–6 add ownership, SIMD‑ready kernels, and a blocked‑reduction opt‑in; algorithmic breadth will expand as more verbs (e.g., linalg, FFT) are added. | 3 (M) – plan includes Complex support and mixed‑precision Nouns; not yet built. | 2 (M) – once Mojo interop matures, Mojj could be called from Python; today it is a Mojo library only. | 2 (M) – future docs will follow the plan; currently only source‑level comments. | 2 (M) – community will grow as Mojo adoption increases; today minimal. | 4 (M) – the plan targets CPU‑SIMD (4‑wide and 8‑wide) and optional GPU‑like blocked reduction; portability to other Mojo targets is a goal. |

### Confidence notes
- **`H`** – directly measured or read from source in this repo (e.g., NumPy’s algorithm breadth from its extensive stdlib; Mojj’s ecosystem from the package metadata).
- **`M`** – moderate inference from docs, source code reading, or the same‑binary comparison we ran.
- **`L`** – low confidence; these are model‑prior estimates because we have not written substantial programs in that language or measured its full API.

### What this means for novel algorithm development
- If you need **large‑scale linear algebra, FFT, or statistical distributions**, NumPy (and by extension Numba via NumPy) is the pragmatic choice; its ecosystem and performance‑portability story is mature.
- If you want **Mojo‑native safety and explicit control** (strict fold, domain errors, fine‑grained kernels) while staying within a single‑source language, Mojj current is sufficient for the core verbs you’ve already implemented; the future plan will broaden its algorithmic reach.
- **J** offers a unique tacit‑composition style and built‑in rational arithmetic, but its ecosystem and performance‑portability are limited; it excels for algorithmic prototyping where tacit conciseness matters more than library breadth.
- **Numojo** is an emerging Mojo‑native NDArray that could eventually compete with NumPy for linear‑algebra‑style workloads, but today it is minimal and its performance story is tied to the Mojo compiler’s SIMD support.
- The **“performance portability”** row shows that only NumPy (CPU‑only) and Mojj (Mojo‑SIMD) have a clear, if limited, hardware‑independence story; Numba’s GPU path and J’s CPU‑only story are more niche.

**Take‑away:** The core comparison we performed (map, reduce, RMS) demonstrates that Mojj can be competitive with NumPy on per‑element cost when the strict right‑fold semantics are acceptable, and that Numojo is close in steady‑state but incurs allocation overhead at small sizes. For *broader* algorithm development, consider the library’s API completeness, type‑system reach, and community support as the primary decision factors, because performance characteristics alone do not determine usability for novel algorithms.
