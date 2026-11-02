# One expression, two textual forms

Status: proposed. Recorded 2026-11-02.

Dense J-inspired symbols and space-separated word phrases should be alternate
ways of composing the same numerical operations. The readable form is explicit
syntax, not natural-language interpretation. Its vocabulary and grammar remain
small enough to learn and validate.

A compiled expression should retain enough structure for an honest description,
while the evaluator specializes typed operations over runtime data. Parsing,
inspection, and execution are separate responsibilities; sharing a semantic
model avoids letting each syntax acquire subtly different numerical behavior.

Candidate examples include `negate of square` and eventually
`sqrt of mean of square`. They are design examples, not shipped Mojj APIs.
Later branching phrases should expose tree boundaries clearly and be tested
against direct typed construction, including failures and error locations.

See [the staged implementation plan](../plans/foundation.md). Begin with one
useful grammar slice rather than importing the entire experimental parser.
