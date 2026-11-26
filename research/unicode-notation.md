# Unicode and emoji notation for Mojj

Open design experiment, assessed 2026-11-25 against clean local [main at da7dfd0](https://github.com/davidmashburn/mojj/tree/da7dfd073bf28fe61a0d8ba5696c1c5acb51f2bb). All glyph spellings below are proposed.

The [candidate inventory and confusion tests](unicode-inventory.md) extend this initial sketch with a vocabulary-wide screen, runnable word-form controls, and a revised reader shortlist. Use that shortlist for the next trial.

## What earns a glyph?

Mojj already supports [words and J punctuation in the same phrase](../ideas/expression-frontends.md). A third spelling is worth learning where it helps someone read the operation or see the structure. Try these three renderings of the same root-mean-square verb:

| Words | J punctuation | Mixed Unicode |
| --- | --- | --- |
| `sqrt of mean of square` | `%: @: (+/ % #) @: *:` | `√ ∘ mean ∘ square` |

The circles show the two composition boundaries and the words name the statistics. Dropping the circles forms a J train and changes the calculation. This example tests whether the notation helps someone edit an expression correctly, beyond recognizing its general subject.

Try four math aliases on paper first. Map `√` to `sqrt` (dyad takes a root), `∘` to `of` (explicit composition), `÷` to `divide` (monad takes a reciprocal), and `≠` to `unequal` (dyadic comparison). Read `÷ 4` beside `12 ÷ 4` and explain both. Expose the word equivalent for every glyph in the example key so readers can type and search by name.

Give emoji a separate trial on a real array operation. In the FIR example, compare `windows dot (reverse taps)` with `windows dot (🔄 taps)`. Then give the reader `1 🔄 taps`. Mojj uses the same verb to reverse a single argument and to rotate by a left argument. The icon may cue the second use better than the first. Keep emoji in a downloadable example or tutorial legend if they help readers remember operations but prove awkward to author. A comprehensive emoji vocabulary would require testing that bargain for every verb and modifier.

## Possible prototype

If the reading trial warrants a prototype, add the four math aliases at the shared tokenizer. Emit the existing verb or conjunction with its original source byte offset. Keep ASCII names and assignment, mixed spellings, J train and rank rules, expression descriptions and evaluation. Avoid whole-string substitution, which shifts error locations and can blur token boundaries.

The [parser](https://github.com/davidmashburn/mojj/blob/da7dfd0/src/mojj/_syntax.mojo) rejects non-ASCII bytes before tokenizing. Accept only exact UTF-8 spellings in the initial inventory. Count the existing 512-byte ceiling on original UTF-8 input, document that cost, and retain structural bounds. The [CLI](https://github.com/davidmashburn/mojj/blob/da7dfd0/bin/mojj) separately checks ASCII and quotes phrases into generated Mojo cells. Preserve literal escaping and the single-line transport. Verify the compiler receives the same glyph bytes from a file, pasted at the prompt, and inside a Mojo string literal. If an emoji graduates, specify accepted presentation sequences individually. Visually similar pasted text can carry a selector. [Unicode emoji presentation sequences](https://www.unicode.org/reports/tr51/#Emoji_Presentation_Sequences)

Compare descriptions, values, shapes and error behavior with word equivalents. Cover both valences, mixed and adjacent tokens, hooks versus explicit composition, session assignments, an unknown glyph after a multibyte token, and phrases at 512 and 513 bytes. Run the syntax and CLI tests, core suite, demo and package smoke on a prototype.

## Open question

Counterbalance the word, J, and mixed forms across readers familiar and unfamiliar with J. Ask them to explain RMS, change the FIR sentence, and enter a fresh expression using their usual editor. Record wrong predictions, successful edits, time and legend lookups. Include spoken navigation for anyone who uses it. Advance individual glyphs that reduce reading errors or time without recurring entry or editing failures. Keep the emoji trial independent so a win for mathematical composition cannot be mistaken for evidence for a pictographic language. This assessment used source inspection only.
