# One expression, two textual forms

Status: initial grammar implemented locally in `811f40c`; branching remains
proposed. Recorded 2026-11-02.

Update: `811f40c` is now published. The user wants to explore faithful J trains
as well as readable composition. See the [vocabulary roadmap](../plans/j-vocabulary.md):
the recommended compromise keeps `of` as `@:` and uses J rules for bare trains.
The current pipeline grammar remains a prototype, not J semantic compatibility.

Dense J-inspired symbols and space-separated word phrases should be alternate
ways of composing the same numerical operations. The readable form is explicit
syntax, not natural-language interpretation. Its vocabulary and grammar remain
small enough to learn and validate.

A compiled expression should retain enough structure for an honest description,
while the evaluator specializes typed operations over runtime data. Parsing,
inspection, and execution are separate responsibilities; sharing a semantic
model avoids letting each syntax acquire subtly different numerical behavior.

Implemented examples include `Expr["negate square"]` and
`Expr["sqrt mean square"]`, with matching symbolic forms.
Later branching phrases should expose tree boundaries clearly and be tested
against direct typed construction, including failures and error locations.

See the [staged implementation plan](../plans/foundation.md) and
[completed grammar slice](../plans/expression-strings.md). The initial slice is
built independently; it does not import the experimental parser.
