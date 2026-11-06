# Compiled J phrases

`Expr[source: StringLiteral]` parses a bounded J subset at compile time. Readable
words and symbols produce the same typed verbs. Runtime inputs are `Noun` values;
there is no runtime string parser or language interpreter.

## Migration from 0.1

**Breaking change:** bare verb sequences form J trains. Whitespace no longer
means composition. Use `of` or `@:` explicitly:

| Phrase | At 3 | Structure |
| --- | --- | --- |
| `minus square` / `- *:` | -6 | Hook: `y - square(y)` |
| `minus of square` / `- @: *:` | -9 | Composition: `-square(y)` |
| `square plus double` / `*: + +:` | 15 | Fork: `square(y) + double(y)` |

RMS is `sqrt of mean of square`. `sqrt mean square` is a fork whose middle
verb is mean; its required dyadic mean is unsupported. It is not an RMS alias.
`negate` is retained as an alias for the ambivalent verb `minus`.

Descriptions now expose J verb trees instead of the old map/reduction lowering.
`apply` and `map` can raise domain or result-rank errors and callers need `raises`
or error handling. Empty derived mean returns zero. The original typed
`Mean[Source]` still rejects empty inputs, and `Sum[Source]` still accumulates
left to right. Those legacy APIs keep their original contract.

## Vocabulary and valences

| Words | Symbols | Monad | Dyad |
| --- | --- | --- | --- |
| `identity`, `right` | `]` | Identity | Right argument |
| `left` | `[` | Identity | Left argument |
| `plus` | `+` | Identity for real nouns | Addition |
| `minus`, `negate` | `-` | Negation | Subtraction |
| `times` | `*` | Sign | Multiplication |
| `divide` | `%` | Reciprocal | Division; zero divided by zero is zero |
| `square` | `*:` | Square | Unsupported |
| `double` | `+:` | Double | Unsupported |
| `sqrt` | `%:` | Real square root | Unsupported |
| `tally` | `#` | Exact integer item count | Unsupported |
| `cap` | `[:` | Only the left branch of a fork | Same restriction |
| `sum` | `+/` | Insertion of plus | Table unsupported |
| `mean` | `(+/ % #)` | Derived fork | Unsupported |

`mean` expands to insertion, division, and tally; it is not a special parsed
symbolic pattern. Unsupported valences fail explicitly. Boolean dyads of `*:`
and `+:`, complex values, root degree, copy, and insertion tables are outside
this scalar/vector milestone.

## Parsing and modifiers

The parser implements the retained rows of the
[J parse table](https://www.jsoftware.com/help/dictionary/dicte.htm), including
noun sentences, hooks, forks, longer verb trains, parentheses, adverbs, and
conjunctions. It has no conventional arithmetic precedence: `10 % 3 + 2` is 2.
A train used in a sentence needs grouping: `(- *:) 3` is -6, while `- *: 3` is -9.

| Word | Symbol | Meaning |
| --- | --- | --- |
| `of` | `@:` | Whole-result composition, with infinite ranks |
| `atop` | `@` | Composition at the right verb's ranks |
| `insert` | `/` | Right-grouped monadic insertion |
| `bind` | `&` | Bind a noun on either side of a verb; monadic application only |
| `group … end` | `( … )` | Group a phrase |

Modifiers bind according to J, including to a preceding derived verb.
`*:@(+/)` squares the sum; `*:@+/` inserts the dyad `*:@+`. On `1 2 3 4`
they produce 100 and 6770404. `-/ 1 2 3` is `1 - (2 - 3)` = 2.

`@` and `@:` differ in rank. With vectors `1 2 3 4` and `7 5 3 2`,
`*/ @: +` returns 2016; `*/ @ +` returns `8 7 6 6`.
Scalar extension and equal-length vector agreement are supported. A length-one
vector is not an atom and does not broadcast to a longer vector.

Numeric literals include signed Int64 integers, decimal Float64 values, and
bounded decimal exponents. J's underscore denotes a negative literal: `_3.5`,
`1e_2`. Whitespace-separated numbers form a vector. Literal 0 and 1 use Boolean
storage where appropriate; counts and integer arithmetic retain integer storage.
`2:` denotes a constant verb. A noun at the left of a fork also denotes a
constant branch. Noun binding supports scalar/vector nouns and noun sentences:
`10&-`, `-&10`, `0.5&*`, `(10 + 2)&-`.

Words are lowercase whole tokens. Space, tab, CR, and LF are whitespace;
punctuation delimits words. Words and symbols may be mixed. Unsupported
operators, names, assignments, Unicode, higher-rank nouns, and arbitrary
modifier trains are rejected rather than reinterpreted.

## Consumers

```mojo
from mojj import Expr, Noun

var hook = Expr["minus square"].monad(Noun(3))
var difference = Expr["minus"].dyad(Noun(10), Noun(3))
var sentence = Expr["10 divide 3 plus 2"].value()
```

`monad`/`dyad` consume verbs and return a `Noun`; `value` evaluates a complete
noun sentence. A wrong consumer is a compile-time error. `describe()` works
at compile time for either kind of phrase.

Float64 convenience methods `apply(value)`, `map(data)`, and `reduce(data)`
check that the result is respectively a scalar, vector, or scalar. `map`
applies the verb to the whole vector; it does not force an arbitrary verb to
be elementwise. Each result owns fresh storage, and inputs remain unchanged.
Domain, unsupported-valence, shape, and result-rank failures are runtime errors.
Negative real square roots fail explicitly until complex nouns are supported.

## Bounds and validation

Limits are 512 ASCII source bytes, 64 AST nodes, 16 nested groups, and 16 derived
AST levels. Alias expansions count toward the node limit. Runtime vector lengths
are independent of these parser bounds. Syntax errors include a zero-based byte
offset into the original literal. A merely declared, unused alias need not
instantiate a method and is not itself a validation guarantee.

Tests compare typed, word, and symbolic trees and values; exercise J's semantic
discriminators; and check malformed/truncated inputs and exact parser bounds.
The compiler-failure driver first compiles a valid control and uses a timeout
for every compiler invocation. See [compatibility](COMPATIBILITY.md) for the
reference-validation status and numerical limits.
