# One expression, two textual forms

Status: shared word/symbol semantic model implemented; a separate pipeline DSL
remains an idea. Reconciled 2026-11-06 against published `main` at
[`09cf8d4`](https://github.com/davidmashburn/mojj/commit/09cf8d4df865581b60727b11ecddb512de3dcc13).

Readable words are explicit syntax, not natural-language interpretation. They
normalize to the same tokens as J symbols, sharing bounded parsing, typed
execution and inspectable expression trees. This preserves the original reason
for two spellings without introducing two numerical interpreters.

The prototype in `811f40c` treated whitespace as composition. That historical
choice was replaced in `f6b05c8`: bare sequences now form J trains, while `of`
is the explicit alias for `@:`. The earlier examples must be read accordingly:

| Current phrase | Meaning |
| --- | --- |
| `negate square` / `- *:` | Hook; at 3, produces -6. |
| `negate of square` / `- @: *:` | Composition; at 3, produces -9. |
| `sqrt of mean of square` / `%: @: (+/ % #) @: *:` | RMS. |
| `sqrt mean square` | Fork requiring an unsupported dyadic mean; not RMS. |

Branching is now implemented through hooks/forks, cap and longer trains.
[Tests](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/tests/test_strings.mojo#L24) compare descriptions and behavior with
typed construction, and distinguish grouped trains from ordinary noun sentences.
A separate, explicitly named pipeline entrypoint remains optional and unbuilt;
there is no implicit mode chosen by word versus symbol spelling.

See the [current syntax/migration guide](https://github.com/davidmashburn/mojj/blob/09cf8d4df865581b60727b11ecddb512de3dcc13/docs/SYNTAX.md),
[reconciled vocabulary roadmap](../plans/j-vocabulary.md), and
[historical prototype contract](../plans/expression-strings.md).
This update inspected source and tests but reran no compiler/runtime checks.
It records implemented semantics, not full J compatibility or optimization.
