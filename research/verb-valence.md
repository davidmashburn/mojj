# When should one Mojj spelling accept two argument counts?

**Working hypothesis, 2026-11-25.** Give a primitive spelling one operation by default. Allow a shared spelling when the two calls express a familiar relationship and there is concrete value in passing that spelling around as a verb. Let a derived phrase accept every argument count its components can support. Choose the dialect explicitly for an entire phrase or session. Existing J-mode expressions are the compatibility baseline.

This changes the [glyph inventory](unicode-inventory.md). Binary ×, ÷, ≤ and ≥ become better candidates once a reader can infer what they do regardless of surrounding syntax. The J-vocabulary spelling table remains useful for translating programs. Its rows need not be the design units for a new language.

## What the evidence says

I inspected local main at [09028cb](https://github.com/davidmashburn/mojj/tree/09028cbf04f9db4533e1cc13fe6e797a948a8052). I ran the current CLI and extracted syntax trees using Mojj’s own parser. A temporary checker applied a trial argument-count policy to those trees. It covered the forms in the two bundled scripts and targeted controls, with named expansions such as dot treated as operations with declared contracts. This was a vocabulary experiment, not a functioning dialect.

| Current expression | Observed or source-verified behavior | Consequence for the design |
|---|---|---|
| `less_equal 3`, `3 less_equal 4` | CLI returned 2 and True. The parser rejected `3 less_equal` as incomplete. | Correcting the earlier sketch: deleting the **left** operand is the silent error. Deleting the right operand already fails. Reserve the comparison name for two arguments and name decrement separately. |
| `(square insert) 1 1`, `(square insert) 1` | CLI returned False and True. The former combines two Booleans with NAND. The latter returns its scalar input unchanged. | A check inside the primitive kernel misses the second case. The combining verb must support two arguments even when the data happens to need zero calls. Write `nand insert` to request that fold. |
| `(square plus double) 3` | CLI returned 15. The fork calls square and double with one argument, then adds their results. | A strict vocabulary can keep this train exactly as written. Calling that same train with two arguments would require binary branches; the proposed square and double reject that use. |
| `(minus square) 3`, `10 (minus square) 3` | CLI returned −6 and 1. Both call binary subtraction and unary square. | One derived verb can accept either count even if each primitive has a fixed role. A universal ban on two-signature verbs would lose both brevity and reuse. |
| `(minus bind square) 3`, `4 (minus bind square) 3` | Existing tests assert −9 and 7 for equivalent punctuation. Unary use negates the square. Binary use subtracts the squares. | Here the *same minus occurrence* actually needs both meanings if one phrase is to serve both calls. Preserve the familiar minus pairing in the trial. Purely unary negate or binary subtract should still be available separately. |
| `(plus insert) 2 3`, `2 3 (plus table) 4 5` | CLI returned 5 and the matrix with rows [6,7] and [7,8]. | The operand is binary addition in both. Split the modifier spellings so that “insert” names the fold and “table” names the pairwise table. |
| `(plus repeat 0) 9`, `3 (plus repeat 0) 9` | Both returned 9. Current zero-repeat bypasses the operand. | In the trial, repeat preserves the operand’s supported counts even at zero. With binary-only plus, only the second form is legal. Verify separately that legal zero-repeat never evaluates its operand. |

There is a genuine cost to removing primitive ambivalence. Another existing test uses the same rank-sensitive composition with unary plus as identity and binary plus as addition. Reserving plus for addition would require two phrases for that behavior, or using the existing J entry point. Keep the cost visible when recruiting J users. If a real caller repeatedly needs a single value combining two independently named functions, try an explicit unary/binary pair before adding exceptions across the dictionary. [Arithmetic bond examples](https://github.com/davidmashburn/mojj/blob/09028cb/tests/test_p2_expr.mojo#L88) · [Rank-sensitive composition test](https://github.com/davidmashburn/mojj/blob/09028cb/tests/test_verbs.mojo#L222)

APL itself provides a precedent for distinguishing an operator’s operand count from the argument count of the function it produces. A modifier taking one verb can produce a unary, binary, or ambivalent function. Mojj can exploit that distinction whichever glyphs are chosen. [Dyalog function and operator model syntax](https://docs.dyalog.com/21.0/programming-reference-guide/defined-functions-and-operators/traditional-functions-and-operators/model-syntax/)

## Apply the decision across the vocabulary

The table assigns **meanings** before symbols. Some labels describe proposed names. An entry here does not add a new kernel or change a domain, shape rule or numeric tolerance.

| Family | One-argument operation | Two-argument operation | Trial policy |
|---|---|---|---|
| Arithmetic | Identity, negate, sign, reciprocal | Add, subtract, multiply, divide | Plus, × and ÷ binary. Retain shared minus alongside explicit negate/subtract. Keep J negative numeral syntax for this experiment. |
| Powers, roots and logs | Square, double, square root, exp, natural log | NAND, NOR, nth root, power, log to a base | Split. Test √ as unary. Use a named binary root so the index order is searchable. |
| Comparisons and rounding | Decrement, increment, halve, floor, ceiling | At most, at least, whole-array match, minimum, maximum | Split. Test ≤ and ≥ as a pair. Test ⌊ and ⌈ only for rounding. Keep elementwise equality distinct from whole-array match. |
| Magnitude and circular functions | Absolute value, multiply by π, sine, cosine | Residue, circular-function selector | Split magnitude/residue. Keep sin/cos unary. Leave the low-level selector as a word so π can never ambiguously mean a value or a dispatched function. |
| Logical and relational | Numeric complement | Equal, unequal, less, greater, AND, OR | Keep supported counts. An accurate signature cannot fix a misleading domain name: “not” also needs testing on non-Booleans. |
| Projections and constants | Identity; constant | Left, right; constant | Use explicit names for projection. Constants already return the same value independently of their arguments, so permit both counts and explain the ignored arguments. |
| Dimensions and selection | Shape, tally, iota, head, tail, drop first, drop last | Reshape, replicate/filter, gather, take, drop | Split by operation. Counts greater than one retain replication semantics. A Boolean-only filter would be a separate domain proposal. |
| Joining | Ravel, make a table from one noun, add a leading axis | Append, stitch, laminate | Distinguish each transformation. Use an unambiguous word for monadic table formation; reserve the modifier word “table” for pairwise application. |
| Reordering | Reverse leading items; reverse axis order | Rotate leading items; reorder specified axes | Split reverse/rotate. Test transpose as a possible default-argument exception, but first compare it with explicit axis order on three-dimensional input. |
| Named derived verbs | Sum, mean, sin, cos | Dot product | Give the public spelling its advertised count. Preserve the expansion for inspection. Use an explicit table of addition or an explicitly constructed fork for the less obvious inherited cases. |

This makes **≤ ≥ ≠ × ÷ √** the initial semantic trial. Test them in expressions containing the variable `x`, multi-operation phrases, and vectors. Splitting sign/multiply fixes one hazard of × but leaves its visual similarity to x. Splitting root leaves the extent of √ under right-to-left evaluation as a separate question. Test **−** against explicit words as the exception, **∘** separately for rank and visual confusion, and **🔁** for fixed-count repetition. For **🔄**, first see whether readers distinguish rotate from reverse and refresh *even when taught a single meaning*. No additional emoji becomes safe solely because it has one argument count.

## What survives inside derived expressions

Infer supported counts bottom-up from the parsed expression. For a given call, check the required branch at each node. `F₁` means F can take one argument and `F₂` means it can take two. These are argument counts, independent of array rank and input dtype.

| Form | To call the result with one argument | To call the result with two |
|---|---|---|
| Hook F G | F₂ and G₁ | F₂ and G₁ |
| Fork F G H | F₁, G₂, H₁ | F₂, G₂, H₂ |
| F of G / F atop G | F₁ and G₁ | F₁ and G₂. The two compositions retain their different rank rules. |
| F bind G, both verbs | F₁ and G₁ | F₂ and G₁. G transforms each argument. |
| Bind a noun to one side of F | F₂ | Unsupported for the noun-bound forms |
| F insert / F table | Insert requires F₂ | Table requires F₂ |
| F prefix / F infix; F suffix / F outfix | Prefix or suffix requires F₁ | Infix or outfix requires F₁; the left noun controls window size |
| F reflex | F₂, invoked with the argument twice | F₂, invoked with swapped arguments. Trial explicit words for duplicate versus swap. |
| F rank, F repeat | F₁ | F₂. Preserve rank values and the fixed left argument of binary repeat. |
| General contraction R . C | Unsupported | R₁ and C₂. Rank-zero cell and shape requirements still apply. |

A verb with only a unary interpretation remains valid as a standalone phrase. A train with no possible interpretation should fail when constructed. A valid train used at an unsupported count should fail when that count is requested. For a conventional J shortcut like cap in the left branch of a fork, check the composition it actually lowers to. For sum and mean, constrain the spelling *and* validate the expansion. Fast paths, empty inputs and compiler specialization must all respect that constraint. [Train and fold implementations](https://github.com/davidmashburn/mojj/blob/09028cb/src/mojj/verbs.mojo#L660) · [Modifier implementations](https://github.com/davidmashburn/mojj/blob/09028cb/src/mojj/modifiers.mojo) · [Rank and window operations](https://github.com/davidmashburn/mojj/blob/09028cb/src/mojj/array_modifiers.mojo)

## How much existing code moves?

I parsed every nonblank sentence in the two bundled algorithm scripts, stripping only the CLI assignment target. The checker treated the existing `*` as a binary arithmetic spelling and shared minus as the trial exception. All **18 of 18** neural-step sentences passed, including `x times table dz` and the max-based activation. **4 of 5** FIR sentences passed. Its one conflict is informative:

```text
windows =: (tally taps) (identity prefix) samples
windows =: (tally taps) (identity infix) samples
```

Both run in current Mojj. The second names what the program wants: windows whose width is the number of taps. Both versions returned [11,22,44]. The unchanged neural step returned losses 2.0 and 0.04500000000000001. These counts measure the compatibility of a small, known code sample. They do not estimate migration costs for external programs, trained J readers, or every possible composition.

## What a prototype could test

1. **Start with words.** Expose an explicitly selected experimental phrase mode and a matching CLI/session mode. Use the same grammar, right-to-left evaluation and train formation. Do not infer dialect from the first glyph: `square insert` is entirely ASCII and is precisely where the dialects should disagree. Prototype square/NAND, decrement/comparison, sign/multiply, minus, insert/table and composition first.
2. **Retain what the author chose through parsing.** Today aliases become shared kinds before evaluation, and derived words can expand to multiple nodes at the same source position. Record spelling-specific argument-count contracts alongside the existing tree or in the parser’s derived metadata. Preserve source byte positions. Reuse existing typed execution after validation. Keep operation descriptions and rank information accurate for the selected interpretation.
3. **Validate at every language entry point.** Check calls inside noun sentences, saved-session expressions, and host calls including zero-argument complete sentences and the unary and binary verb consumers. Host conveniences such as `Expr.reduce` actually call the phrase *monad* and require a scalar result; the insert modifier separately needs a binary combining verb. Diagnostics should name the original word, its role, the count required, and a suggested spelling where clear. Domain and shape errors remain distinguishable. [Host consumers](https://github.com/davidmashburn/mojj/blob/09028cb/src/mojj/strings.mojo#L236) · [Session evaluation](https://github.com/davidmashburn/mojj/blob/09028cb/src/mojj/_session.mojo#L43)
4. **Test semantics independently of glyphs.** Counterbalance inherited versus restricted word forms first; then compare words versus glyphs *under the same contracts*. Include users familiar and unfamiliar with J. Use unfamiliar operands, lost-left-argument edits, folds of length zero/one/many, both calls of a bond, and a fixed-width FIR edit. Record output and shape predictions, confident silent errors, edits completed, and occasions when readers must duplicate a useful verb. A parser rejection that lets someone repair the program is a different outcome from an unexplained rejection that prevents completion.
5. **Decide based on the disagreement.** Advance splitting if users prevent or repair silent mistakes while still completing the algorithm edits. Keep shared minus if people can predict both bond uses and benefit from reusing the phrase. If explicit inheritance or pairing is repeatedly necessary for recognizable user tasks, broaden the ambivalence mechanism. If the word-only design provides all the observed benefit, ship decisions about glyphs separately.

Confidence is high in the parser and execution distinctions, moderate in the vocabulary recommendation. The examples favor a small opt-in trial. No Unicode dialect was implemented, no external projects or readers were tested, and the full Mojo regression suite was outside this design study.
