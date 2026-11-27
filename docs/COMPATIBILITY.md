# J compatibility ledger

Mojj implements a compiled, numerical subset of J. This ledger separates supported behavior, intentional differences from J, and the limits of the recorded checks. For phrase syntax, see the [syntax guide](SYNTAX.md).

## Contract

| Surface | Supported contract | Explicit boundary |
| --- | --- | --- |
| Nouns | Value-owned homogeneous arrays; Boolean, Int64, Float64 | No complex, extended integers, or boxed nouns |
| Arithmetic | <code data-mojj><strong>+</strong> <strong>-</strong> <strong>&#42;</strong> <strong>%</strong></code>, real powers/logs/roots, residue, min/max, comparisons, circle and Boolean verbs | Unsupported valences raise; negative square root raises |
| Trains | Hooks, forks, cap, longer verb trains, constant noun branches | Verb trains only; no arbitrary adverb/conjunction trains |
| Modifiers | <code data-mojj><ins>@:</ins></code>, rank-sensitive <code data-mojj><ins>@</ins></code>, noun and verb bond, reflex, rank, insertion/table, prefix/suffix, dot and fixed verb repetition (<code data-mojj><ins>^:</ins></code>) | Repetition takes one integer literal from 0 through 1024. Inverse, convergence and array-of-count forms are unsupported. A noun-bound verb supports monadic use only |
| Grammar | Relevant J parse-table rows, numeric nouns and sentences, groups | No assignment or names within standalone literals; no foreigns, control flow, or dynamic evaluation |
| Aliases | Words and symbols normalize before parsing | No whitespace pipeline mode |
| Execution | Literal-specialized typed verbs; fresh result storage | No promised fusion, allocation optimization, or performance parity |

`Noun.rank` distinguishes an atom from a singleton vector. Atomic arithmetic
uses J prefix agreement. For example, a length-two vector extends along the rows of a two-by-three matrix.
Tally returns an exact integer count. Integer arithmetic checks overflow and
raises; it does not wrap or silently approximate. This intentionally differs
from J's overflow promotion. Arithmetic on Boolean nouns promotes to integer
storage where required; mixing integers with Float64 uses Float64. Division and
square root use Float64. This is a documented storage policy, not a claim of
matching every J result type.

Hooks, forks, whole-result composition, and noun binding have infinite monadic
rank. `@` inherits the inner verb's ranks. Explicit rank selects trailing cells and agrees the leading frames. A negative rank is relative to the argument when the verb runs. Enclosing modifiers see that rank as infinite. Noun binding's
dyadic repeated-application meaning remains outside the supported vocabulary.

Insertion is grouped from the right, including for non-associative operations.
The empty identities for retained arithmetic are zero for addition/subtraction
and one for multiplication/division. Unsupported identity inference raises.
The derived mean is a fork, and its empty result is zero because J defines
zero divided by zero as zero.

The typed composition API in `core.mojo` has a separate contract. Its lazy Float64 `Sum`
and `Mean` accumulate left to right; its empty `Mean` raises. Its tree
representations and policies must not be used as a description of the new
J verb API.

## Numerical evidence and limitations

Discriminating fixtures cover hooks versus composition, forks, derived mean,
right-grouped subtraction, left/right binding, noun-sentence evaluation,
rank-sensitive composition, modifier binding, zero division, and unsupported
complex-producing input. Typed and string tests also cover exact integers above
2**53, overflow, empty vectors, dtype transitions, shape disagreement, and reuse.

Floating results use Float64 with contraction disabled in the provided tasks.
Checks use exact equality for exact small results and absolute tolerance 1e-12
for the small reference fixtures. This is not a general error bound or a bitwise
portability claim. J may use different reduction kernels and accumulation orders;
right grouping alone does not promise matching floating cancellation behavior.
Real circular and hyperbolic verbs use Float64 LLVM intrinsics and platform math functions. The circular selectors for sine, cosine, and tangent reject magnitudes above 596313653.72958016, matching the pinned runtime. Exhaustive IEEE behavior across platforms remains unverified.

Rank and window operations infer empty result shapes by evaluating representative cells. For a ranked dyad, a nonempty argument frame contributes its first actual cell, including when the other frame is empty. An empty argument frame contributes a fill cell. Its evaluation can report a domain error. Shaped results own their storage, and windows can materialize intermediate cells. Dyadic dot supports rank-zero cell verbs, including multiplication for vector and matrix products. The determinant monad is outside the supported subset.

The locked Mojo 1.1.0 toolchain passed the full test suite, demo, and compiled-package smoke tests on macOS arm64 and in Ubuntu 24.04 x86-64 under Docker Desktop emulation on Apple M4. The Linux run included the linked parser control and 46 expected compilation failures. The [hosted native Ubuntu suite](https://github.com/davidmashburn/mojj/actions/runs/44793497240) also passed. The [native square SIMD trial](https://github.com/davidmashburn/mojj/actions/runs/44794466778) measured public square and RMS calls on one hosted x86-64 runner.

## Reference execution

The reference corpus contains 142 expectations against pinned J 9.6.3 for macOS arm64 and Linux x86-64. It compares every result axis, checks integer and Boolean values exactly, and records dtype differences separately. It exercises vector and matrix products, zero-length axes, negative windows, prefix frame agreement, shape errors, and fixed-count repetition. Two expected differences cover checked integer overflow and complex-producing square root. See the [cases and reproduction command](../tests/reference/README.md).

The [historical performance report](../tests/reference/RESULTS.md) used the original 33 fixtures. J is a development reference and is independent of the library runtime.
