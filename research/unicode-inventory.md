# A reading inventory for Mojj glyphs

Design assessment, 2026-11-25. Proposed spellings throughout. I would take **four math signs and one APL pair** into a reader trial. I would give **🔁** its own trial against the word `repeat`. I would reserve several attractive signs because an experienced reader can make a confident, consequential mistake with them. The existing words are the entry method and the control condition for every candidate.

## Reconsidering the one-argument / two-argument pairing

The [valence design study](verb-valence.md) supersedes the inherited-valence shortlist for the opt-in dialect. It includes compatibility measurements, exceptions worth keeping, and call rules for derived verbs.

The inventory below tests a compatibility assumption: every glyph inherits all the meanings of its J verb. For a new notation, compare that design with one where the author chooses the operation explicitly. Under this proposal, words and glyphs for the same operation carry the same argument-count restriction. Existing Mojj phrases keep their contract; the alternative needs a distinct opt-in entry point so a mixed phrase has one interpretation.

| Candidate | Inherited reading | Alternative to test |
|---|---|---|
| ≤ | Decrement or compare | Binary “at most”; use unary `decrement` to subtract one |
| × | Sign or multiply | Binary multiply; use unary `sign` |
| √ | Square root or indexed root | Unary square root; use binary `root` for the indexed operation |
| ⌊ | Floor or minimum | Unary floor; use binary `min` |
| 🔄 | Reverse or rotate | Evaluate against just one candidate meaning at a time. Test the competing “refresh” interpretation even after splitting them. |
| − | Negate or subtract | Compare keeping the familiar arithmetic pairing with explicit `negate` and `subtract` |

A hook or fork can still determine how many arguments each component receives. The unary fork `(square plus double) 3` uses unary square, binary addition and unary double to produce 15. Reduction also still works: applying binary addition between successive items produces a unary sum. Conversely, a unary-only `square` used as the combining verb in a reduction must report an argument-count error. Today its binary behavior is NAND. Merely mapping two spellings to the same unrestricted verb would lose the distinction inside the derived expression. Carry the restriction until the call is resolved, including calls selected by trains and modifiers.

For the reader trial, present matched cards for the inherited and restricted designs, counterbalanced across readers. Include a valid binary comparison, a missing operand, a deliberately unary decrement, a fork, and a reduction. Count silent wrong answers prevented, useful expressions made harder to write, and time to diagnose a mistake. Test the familiar minus pairing separately. Revisit the semantic shortlist before spending time on typography; entries with an argument-count objection may improve once it is removed.

## How the inventory was screened

ICAO's spelling-alphabet designers specified recognition and transmission criteria, then revised the alphabet after actual users encountered confusion under poor reception. Speakers from 31 countries participated in the re-examination. The transferable idea is to test *substitutions within the repertoire* under realistic conditions. A drawing can be memorable by itself and still be the wrong choice beside its neighbors. [ICAO history](https://www.icao.int/sites/default/files/postalhistory/annex_10_aeronautical_telecommunications.htm)

I extracted the 89 distinct word spellings in the tokenizer, grouped aliases by behavior, and inspected its punctuation-only forms, literal syntax, and CLI assignment. For each family I asked what the sign suggests, what Mojj actually does at each supported argument count, what adjacent token or operation could be substituted, and whether that substitution yields plausible output. APL precedent counts in favor only where the relevant axes, argument order and supported cases agree. The remaining gates are visual and spoken discrimination, reliable entry, and recovery by word search. The classifications below are desk decisions about what to **test**, with no measured reader accuracy yet. [Mojj tokenizer](https://github.com/davidmashburn/mojj/blob/63af496/src/mojj/_syntax.mojo) · [Mojj syntax](https://github.com/davidmashburn/mojj/blob/63af496/docs/SYNTAX.md) · [Dyalog glyph reference](https://docs.dyalog.com/20.0/files/Dyalog_APL_Language_Reference_Guide.pdf)

The tables use representative word names. The tokenizer also accepts these synonyms for the same families: `eq/ne/lt/gt/le/ge` for the six comparisons, `ceil/max/maximum` and `min/minimum` for ceiling and floor, `pow` and `log` for power and logarithm, and `nand` and `nor` for square and double. J punctuation and word aliases share verb behavior even when a name cues only one valence.

## First reading trial

Each spoken cue is also an existing, keyboard-enterable Mojj word.

| Exact sign | Spoken cue / existing punctuation | Reason to try it | Test most likely to disqualify it |
|---|---|---|---|
| ≠ U+2260 | unequal / `~:` | Recognizable elementwise comparison | Ask what comparing two vectors returns. “One Boolean for the entire array” confuses it with negated whole-array match. Ask readers to enter it from dictation. |
| √ U+221A | root / `%:` | The radical cues the root operation in both uses | Read `√ 9`, `3 √ 8` and `√ 9 + 7`. Score index order and extent of the radical. The last is 4 under Mojj grouping. |
| ÷ U+00F7 | divide / `%` | Names division and frees a reader from J’s percent sign | Compare `÷ 4` (0.25) and `12 ÷ 4` (3). Ask for `10 ÷ 3 + 2` (2), which mathematical precedence would read differently. |
| ∘ U+2218 | of / `@:` | Separates whole-result composition from a bare train | Distinguish it from rank-sensitive `atop`, the letter o, a degree sign and the APL jot used in other constructions. Reserve the other circle signs. |
| ⌊ U+230A | floor / `<.` | APL gives the single sign the same floor/minimum pairing | Dictate “floor”; then show `2 ⌊ 5`. Test whether a reader waits for a closing bracket or predicts rounding the right argument. |
| ⌈ U+2308 | ceiling / `>.` | Same precedent for ceiling/maximum | Present beside floor at normal editor size, then on another line. A flipped corner silently changes min to max. Advance or withdraw these two together. |

## Rest of the mathematical and array vocabulary

“Reserve” means a candidate merits a specific follow-up if there is demand. “Keep word” records the rejected alternative or the reason the existing spelling wins. Multiple words in a row can name distinct operations; only the explicit mappings below propose equivalence.

| Mojj operation(s) | Candidate and disposition | Deciding ambiguity |
|---|---|---|
| plus, minus/negate | Keep `+` and `-`; reserve typographic minus `−` for pasted prose only | A leading minus is a verb in Mojj. The sign in a negative numeral is an underscore. A typography fix can change the parse of a numeric strand. |
| times | Reserve × | Dyad multiplies, monad computes sign. Visually confusable with the legal session name `x`. Test `× x` in the neural-step example’s naming context. |
| equal, less, greater | Keep `=`, `<`, `>` | Already recognizable, same keyboard spelling. `≡` suggests structural equality, which is a different operation. |
| less_equal/decrement, greater_equal/increment | Reserve ≤ and ≥ as a pair | Excellent comparisons; `≤ 3` gives 2 and `≥ 3` gives 4. A predicate-only reading fails for both. |
| and, or | Reserve ∧ and ∨ together | Good for Boolean dyads. Read aloud, distinguish the wedge pair and `v`, and check whether users predict min/max on arbitrary numbers. |
| complement/not | Keep word over ¬ | One minus the argument also applies to numbers. Boolean negation predicts the wrong answer there. |
| square/nand, double/nor | Keep words over ² and ➿ | A superscript invites postfix power; Mojj has prefix verbs and a dyadic Boolean meaning here. A double loop conveys neither doubling nor NOR reliably. |
| halve/match | Keep words over ½ and ≡ | One looks like a literal, the other suggests equality; neither explains both uses. |
| abs/residue | Keep words or existing vertical bar | Paired magnitude bars invite a closing delimiter; dyadic residue has an argument order to learn. |
| power, logarithm, circle, sin, cos | Keep words over ↑, ㏒, ○, π, 🌊 | Power also means exponential; log’s left operand supplies its base. Circle multiplies by π or selects a function by number. π suggests a constant; a wave does not distinguish sine from cosine. |
| sum, mean | Reserve ∑ for sum; keep mean | ∑ suggests a scalar grand total, limits or an index binder. Mojj sums leading items and its dyad is an addition table. An overbar needs an operand to attach to and implies no dyadic mean. |
| shape/reshape, iota | Reserve ⍴ and ⍳ | Genuine array notation with distinctive semantics, but easily entered as Greek ρ or ι. Ask for the result of `iota 2 3`, including shape and index origin. |
| reverse/rotate | Reserve ⊖ | Compare across rows on a non-square matrix. Mojj reverses leading items; APL ⌽ defaults to the last axis, while ⊖ uses the first. Circled minus also suggests subtraction. |
| transpose | Reserve ⍉ | Meaningful on a matrix; test a non-self-inverse three-axis permutation before borrowing a dyadic convention. Easy to confuse with the reverse/rotate family. |
| head/take, behead/drop | Reserve ↑ and ↓ as a pair | Strong dyadic APL precedent for take/drop. Test first item versus mix and drop-first versus split in monadic use. Arrows can also suggest sort order. |
| identity/right, left | Reserve ⊢ and ⊣ together | Different dyadic projections; same monadic identity. Ask which operand survives using unequal operands. Small mirrored marks raise the cost of a slip. |
| tally/copy/filter | Keep words or # | A counting icon misses replicate/filter. Counts greater than one distinguish replication from selection. |
| ravel/append, stitch, laminate | Keep words over ∥, 🧵, 🥞 | “Join” leaves axis and result rank unspecified. Test a matrix as well as two vectors before considering a single picture. |
| gather, tail, curtail | Keep words over ☞, ⏭️, ✂️ | Picking by index differs from taking a count. Returning the last item differs from removing it. A transport button could mean advancing the input. |
| cap | Keep cap or `[:` | Valid only as a fork’s left branch. ∩ already suggests intersection. |

## Composition, modifiers and grammar

| Mojj operation(s) | Disposition | Deciding ambiguity |
|---|---|---|
| atop, bind | Keep words or @ and & | A second small circle creates a wrong-rank near twin for ∘. 🔗 could mean either composition or binding. |
| insert/table, prefix/infix/scan, suffix/outfix | Keep words | ∑ implies addition only. Scanning, taking windows, and removing windows can all look like a moving frame. The left operand and verb matter. |
| repeat | Trial 🔁 separately; reserve APL ⍣ | Repetition is recognizable. The media button suggests endless playback, and APL power has broader uses. The Mojj count is a bounded integer literal, including zero. |
| reflex | Keep word over ⇄ or 🔀 | Swapping dyadic operands is deterministic; monadic reflex duplicates its argument. Shuffle implies randomness. |
| rank | Reserve ⍤ | APL precedent; two dots disappear at small sizes. Double quotes already mark rank in Mojj. 📐 suggests physical dimensions or shape. |
| dot, and the general dot conjunction | Keep word and existing period | `dot` expands to `+/ . *`; plain period takes two verbs. A centered dot · or ⋅ could mean either of those or elementwise multiplication. |
| group/end, hooks, forks, trains | Keep parentheses and existing adjacency | A fork icon would suggest an extra explicit token where grouping already determines the tree. |
| negative literals, infinities, numeric constant verbs, CLI assignment | Keep the existing grammar; reserve ∞ only for a separate literal study | `_` participates in negative numbers, infinity and whole-argument rank. A left arrow suggests assignment to APL users and selection to others. Changing literal or naming rules adds a separate learning problem. |

## Emoji panel

The strongest standalone emoji proposal is 🔁 because it can cue a real modifier and works in a complete phrase. Try the runner-up 🔄 as an adversarial comparison. The other candidates below are useful controls or tutorial illustrations. None has earned a production token.

| Candidate | Proposed meaning | Competing reading to elicit |
|---|---|---|
| 🔁 / 🔂 | repeat | Loop forever / repeat once or one track. Ask for zero and three applications, and which noun changes on each step. |
| 🔄 / 🔃 | reverse or rotate | Refresh, retry, or turn the whole array. Show a one-argument reversal and a signed rotation on three distinct items. |
| 🪞 / 🔀 | reflex | Mirror the array or shuffle it; either gives the wrong behavior for subtraction with swapped arguments. |
| ➕ ➖ ✖️ ➗ | arithmetic | Familiar button labels, but visually duplicate existing signs. ✖️ also reads as close/cancel; ❌ as error. Compare × and the variable x. |
| 📐 / 📏 | shape, rank or tally | Angle, dimensions, number of axes and leading-item count are four different answers. Ask about a 2-by-3 array. |
| 🪟 / 🔍 | sliding window or gather | A window can mean a GUI object; search finds a value, gather uses an index. Neither conveys prefix versus infix. |
| ✂️ / 🧲 | drop or filter | Cutting could split or truncate. A magnet might collect matching values, while Mojj copy can also duplicate them. |
| 🧵 / 🥞 / 📎 | stitch, laminate or append | All suggest joining. Score the output shape when combining two distinct vectors. |
| 🔗 / 🎯 | bind or dot | Chaining suggests composition. “Dot” as a target encodes the English word while obscuring contraction. |
| 🧮 / 📊 | sum or mean | Calculation or charting says little about which statistic or which axis. |

## Mechanical screen and discriminating examples

I screened 69 distinct strings, including everyday distractors, by NFD decomposition, per-scalar mapping through Unicode’s confusables data, then NFD again. This narrow string comparison uses Python Unicode 16 normalization and Unicode 18 confusables. It is a source-spelling check, not a font-rendering or full bidirectional security test. The equality classes with more than one member were these:

- `∘ ○ °`, `× x`, `⍴ ρ`, `⍳ ι`, `∑ Σ`, `· ⋅`.
- `÷ ➗`, `− - ➖`, `＋ + ➕`, and ASCII vertical bar with `∣`.

Exact source set, whitespace-separated: `≠ √ ÷ ⌊ ⌈ ∘ ∧ ∨ × ≤ ≥ ⍴ ⍳ ⊖ ⍉ ∑ Σ · ⋅ ○ ⌽ x ρ ι ⍤ ⍣ ⌿ ↑ ↓ ⊢ ⊣ ∞ − - o ° . 0 | ∣ ＋ + ² 2 ⊗ 🔄 🔁 🔂 ➗ ➕ ➖ ✖️ ✖ ❌ 🔀 🪞 📐 🧮 🧲 🪟 🔍 ✂️ 📎 🎯 📊 🥞 🧵 🔗 ⇄`. Confusables data SHA-256 `6ed3ee967c9dfdf6677d563c9985182fbc50a2efb7d6059cd57b2e2ce18f5b92`. [Unicode confusables data](https://www.unicode.org/Public/security/latest/confusables.txt)

Use exact spellings in a prototype; suggest the intended word when rejecting a lookalike. Blanket compatibility normalization turns ² into 2. Even ≠ has a canonically equivalent decomposed sequence (equals plus combining long solidus overlay); decide explicitly whether to accept both and test their source offsets. ✖ and ✖️ differ by a presentation selector. Check actual editor, terminal, clipboard and speech output before assigning distinct meanings on appearance alone. [Unicode emoji presentation sequences](https://www.unicode.org/reports/tr51/#Emoji_Presentation_Sequences)

I ran these word-form controls through the local Mojj CLI. The inputs give different results under the predicted misreadings. They can serve as answer keys for glyph cards.

| Input(s) in current Mojj | Observed result, in order | Confusion exposed |
|---|---|---|
| `10 divide 3 plus 2`; `divide 4`; `3 root 8` | 2.0; 0.25; 2.0 | Precedence, reciprocal, root index |
| `less_equal 3`; `3 less_equal 4` | 2; True | Decrement versus comparison |
| `floor 2.8`; `2 floor 5` | 2; 2 | Rounding versus minimum; ask which operation produced each answer |
| `reverse 1 2 3`; `1 rotate 1 2 3` | [3,2,1]; [2,3,1] | Reversal versus rotation |
| `1 2 3 dot 4 5 6`; `1 2 3 times 4 5 6` | 32; [4,10,18] | Contraction versus elementwise multiply |
| `1 2 3 (times insert of plus) 3 2 1`; replace `of` with `atop` | 64; [4,4,4] | Whole-result versus cellwise composition |
| `(plus of minus) 3`; `(plus circle minus) 3` | −3; 0.1425465430742778 | Substituting ○ for ∘ would turn composition into a valid trigonometric fork if both were admitted |
| `reverse A`; `reverse rank 1 A`, where `A =: 2 3 reshape 0 1 2 3 4 5` | Rows 345/012; rows 210/543, each shape 2 by 3 | A vector hides a first-axis versus last-axis mistake |
| `sqrt 9 plus 7`; `2 floor 7`; `2 ceiling 7` | 4.0; 2; 7 | Root extent and mirrored corners |
| `(double repeat 0) 3`; `(double repeat 3) 3` | 3; 24 | Fixed-count repeat includes doing nothing |

## Reader trial and revision rule

1. Recruit J/APL users, programmers without array-language experience, and people who read mathematics but seldom code. Include several language backgrounds and users who rely on speech or different input methods. Record experience, language, editor, font, platform and input method. An English-only pilot can reveal a collision; it cannot establish international recognition.
2. Give blind, randomized cards with a word, a single glyph, or a complete phrase. First collect an open-ended prediction, expected shape, spoken name and confidence without a legend. Then teach a one-page key and use *new* matched items. Rotate condition order and operand values so nobody answers from memory.
3. Include listening and typing from dictation, search by spoken word, delayed recall, small monochrome diffs, terminal fallback, speech navigation, and paste/save/reopen. Include near neighbors that should be rejected. Ask a second participant to recover the first participant’s intended expression. Record exact inserted code points when a transcription fails.
4. Build a confusion matrix with intended token as row and interpreted token **or operation** as column. Give “unknown,” “other,” and “could not enter” separate columns. Record denominators, high-confidence wrong results, time, lookups and input failures by cohort and channel. Separate parse failures from silent substitutions. Compare with matched word and J baselines, including cases where the word itself is misunderstood.
5. For a formative screen, hold a glyph after one reproducible silent substitution that the word control avoids. Revise the glyph or remove its competitor, then retest with new readers and unseen phrases. Advance only candidates whose intended reading survives both valences where applicable and whose entry and readback work in the tested channels. A small clean pilot justifies a prototype; it does not establish a population error rate.

The desk screen and CLI controls are complete. Reader confusion rates, rendered-font discrimination, speech output, and entry across platforms remain unmeasured.
