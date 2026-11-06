# J compatibility ledger

This change targets the roadmap's bounded P0/P1 semantic foundation.
It is a compiled Mojo library, not a full J implementation. Compatibility claims
are limited to the vocabulary, ranks, noun domains, and fixtures below.

## Contract

| Surface | Supported contract | Explicit boundary |
| --- | --- | --- |
| Nouns | Value-owned atoms and vectors; Boolean, Int64, Float64 | No higher-rank shapes, complex, extended integers, or boxed nouns |
| Arithmetic | `+ - * %`, monadic `*: +: %:`, selectors and tally | Unsupported valences raise; negative square root raises |
| Trains | Hooks, forks, cap, longer verb trains, constant noun branches | Verb trains only; no arbitrary adverb/conjunction trains |
| Modifiers | `@:`, supported atom/whole-noun `@`, monadic noun binding, insertion | No verb-verb bond, explicit rank operator, repeated bound application, or insertion tables |
| Grammar | Relevant J parse-table rows, numeric nouns and sentences, groups | No assignment, names, foreigns, control flow, or dynamic evaluation |
| Aliases | Words and symbols normalize before parsing | No whitespace pipeline mode |
| Execution | Literal-specialized typed verbs; fresh result storage | No promised fusion, allocation optimization, or performance parity |

`Noun.rank` distinguishes an atom from a singleton vector. Atomic arithmetic
extends a scalar to a vector and otherwise requires equal vector lengths.
Tally returns an exact integer count. Integer arithmetic checks overflow and
raises; it does not wrap or silently approximate. This intentionally differs
from J's overflow promotion. Arithmetic on Boolean nouns promotes to integer
storage where required; mixing integers with Float64 uses Float64. Division and
square root use Float64. This is a documented storage policy, not a claim of
matching every J result type.

Hooks, forks, whole-result composition, and noun binding have infinite monadic
rank. `@` inherits the inner verb's ranks. The supported finite rank is atomic;
results requiring higher-rank assembly are explicitly unsupported. Noun binding's
dyadic repeated-application meaning is outside P1.

Insertion is grouped from the right, including for non-associative operations.
The empty identities for retained arithmetic are zero for addition/subtraction
and one for multiplication/division. Unsupported identity inference raises.
The derived mean is a fork, and its empty result is zero because J defines
zero divided by zero as zero.

The older `core.mojo` API is independently retained. Its lazy Float64 `Sum`
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
Exhaustive NaN, infinity, signed-zero, underflow, and transcendental behavior is
outside the conformance claim.

Validation runs on macOS arm64 with the manifest-pinned Mojo toolchain. Linux
execution, remote CI, and performance comparisons are not implied by the lockfile
or these fixtures. P2 numerical breadth/shared traversal and P3 multidimensional
arrays remain separate work.

## Reference execution

A [bounded live-J runner](../tests/reference/README.md) pins J 9.6.3 for macOS
arm64 and records 33 conformance expectations plus nine matched performance
measurements. Thirty cases agree on successful values/shapes, one agrees on
failure, and two document intentional domain differences. Empty sum/product
also differ in dtype. This is evidence for the selected cases, not full J parity
or exhaustive agreement over the supported syntax. See the
[recorded results](../tests/reference/RESULTS.md) for performance and limitations.
J is not linked into the library or required by consumers or the default tests.
