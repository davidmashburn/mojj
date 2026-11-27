# Compiled J phrases

`Expr[source: StringLiteral]` parses a bounded J subset at compile time. Readable
words and symbols produce the same typed verbs. Runtime inputs are `Noun` values;
there is no runtime string parser or language interpreter.

<a id="migration-from-01"></a>

## Trains and composition

**Breaking change from the prototype:** bare verb sequences form J trains.
Whitespace no longer means composition. Use `of` or `@:` explicitly:

| Phrase | At 3 | Structure |
| --- | --- | --- |
| <code data-mojj><strong>minus</strong> <strong>square</strong></code> / <code data-mojj><strong>-</strong> <strong>&#42;:</strong></code> | -6 | Hook: `y - square(y)` |
| <code data-mojj><strong>minus</strong> <ins>of</ins> <strong>square</strong></code> / <code data-mojj><strong>-</strong> <ins>@:</ins> <strong>&#42;:</strong></code> | -9 | Composition: `-square(y)` |
| <code data-mojj><strong>square</strong> <strong>plus</strong> <strong>double</strong></code> / <code data-mojj><strong>&#42;:</strong> <strong>+</strong> <strong>+:</strong></code> | 15 | Fork: `square(y) + double(y)` |

RMS is `sqrt of mean of square`. `sqrt mean square` is a fork whose middle
verb applies mean dyadically. This has different domain and shape requirements.
`negate` is retained as an alias for the ambivalent verb `minus`.

Descriptions now expose J verb trees instead of the old map/reduction lowering.
`apply` and `map` can raise domain or result-rank errors and callers need `raises`
or error handling. Empty derived mean returns zero. The original typed
`Mean[Source]` still rejects empty inputs, and `Sum[Source]` still accumulates
left to right. Those legacy APIs keep their original contract.

## Vocabulary and valences

| Words | Symbols | Monad | Dyad |
| --- | --- | --- | --- |
| <code data-mojj><strong>identity</strong></code>, <code data-mojj><strong>right</strong></code> | <code data-mojj><strong>&#93;</strong></code> | Identity | Right argument |
| <code data-mojj><strong>left</strong></code> | <code data-mojj><strong>&#91;</strong></code> | Identity | Left argument |
| <code data-mojj><strong>plus</strong></code> | <code data-mojj><strong>+</strong></code> | Identity for real nouns | Addition |
| <code data-mojj><strong>minus</strong></code>, <code data-mojj><strong>negate</strong></code> | <code data-mojj><strong>-</strong></code> | Negation | Subtraction |
| <code data-mojj><strong>times</strong></code> | <code data-mojj><strong>&#42;</strong></code> | Sign | Multiplication |
| <code data-mojj><strong>divide</strong></code> | <code data-mojj><strong>%</strong></code> | Reciprocal | Division; zero divided by zero is zero |
| <code data-mojj><strong>square</strong></code> | <code data-mojj><strong>&#42;:</strong></code> | Square | Boolean NAND |
| <code data-mojj><strong>double</strong></code> | <code data-mojj><strong>+:</strong></code> | Double | Boolean NOR |
| <code data-mojj><strong>sqrt</strong></code> | <code data-mojj><strong>%:</strong></code> | Real square root | Principal real nth root |
| <code data-mojj><strong>tally</strong></code> | <code data-mojj><strong>#</strong></code> | Exact integer item count | Replicate or filter items |
| <code data-mojj><strong>cap</strong></code> | <code data-mojj><strong>&#91;:</strong></code> | Only the left branch of a fork | Same restriction |
| <code data-mojj><strong>sum</strong></code> | <code data-mojj><strong>+</strong><ins>/</ins></code> | Insertion of plus | Addition table |
| <code data-mojj><strong>mean</strong></code> | <code data-mojj>(<strong>+</strong><ins>/</ins> <strong>%</strong> <strong>#</strong>)</code> | Derived mean | Dyadic fork over table, divide, and copy |

| Words | Symbols | Monad | Dyad |
| --- | --- | --- | --- |
| <code data-mojj><strong>floor</strong></code>, <code data-mojj><strong>min</strong></code> | <code data-mojj><strong>&lt;.</strong></code> | Floor | Minimum |
| <code data-mojj><strong>ceiling</strong></code>, <code data-mojj><strong>max</strong></code> | <code data-mojj><strong>&gt;.</strong></code> | Ceiling | Maximum |
| <code data-mojj><strong>abs</strong></code>, <code data-mojj><strong>residue</strong></code> | <code data-mojj><strong>&#124;</strong></code> | Magnitude | Residue |
| <code data-mojj><strong>power</strong></code> | <code data-mojj><strong>^</strong></code> | Exponential | Power |
| <code data-mojj><strong>log</strong></code> | <code data-mojj><strong>^.</strong></code> | Natural logarithm | Logarithm with left base |
| <code data-mojj><strong>circle</strong></code> | <code data-mojj><strong>o.</strong></code> | Multiply by π | Select a real circular or hyperbolic function |
| <code data-mojj><strong>equal</strong></code>, <code data-mojj><strong>unequal</strong></code>, <code data-mojj><strong>less</strong></code>, <code data-mojj><strong>greater</strong></code> | <code data-mojj><strong>=</strong></code>, <code data-mojj><strong>&#126;:</strong></code>, <code data-mojj><strong>&lt;</strong></code>, <code data-mojj><strong>&gt;</strong></code> | Unsupported | Elementwise comparison |
| <code data-mojj><strong>decrement</strong></code>, <code data-mojj><strong>increment</strong></code> | <code data-mojj><strong>&lt;:</strong></code>, <code data-mojj><strong>&gt;:</strong></code> | Subtract or add one | At most or at least |
| <code data-mojj><strong>halve</strong></code>, <code data-mojj><strong>match</strong></code> | <code data-mojj><strong>-:</strong></code> | Halve | Whole-array match |
| <code data-mojj><strong>complement</strong></code> | <code data-mojj><strong>-.</strong></code> | One minus argument | Unsupported |
| <code data-mojj><strong>or</strong></code>, <code data-mojj><strong>and</strong></code> | <code data-mojj><strong>+.</strong></code>, <code data-mojj><strong>&#42;.</strong></code> | Unsupported | Boolean OR or AND |

`sin` and `cos` expand to `1&o.` and `2&o.`. The selectors 1 through 3 compute sine, cosine, and tangent. Selectors 5 through 7 compute their hyperbolic counterparts. Negative selectors compute inverse functions over their real domains. Expressions that require a complex noun raise a domain error.

## Array vocabulary

| Symbol | Monad | Dyad |
| --- | --- | --- |
| <code data-mojj><strong>&#36;</strong></code> | Shape | Reshape |
| <code data-mojj><strong>i.</strong></code> | Generate integer indices | Unsupported |
| <code data-mojj><strong>,</strong></code> | Ravel | Append |
| <code data-mojj><strong>,.</strong></code> | Make a table | Stitch |
| <code data-mojj><strong>,:</strong></code> | Add a leading axis | Laminate |
| <code data-mojj><strong>{</strong></code> | Unsupported | Gather leading items by integer index |
| <code data-mojj><strong>{.</strong></code>, <code data-mojj><strong>{:</strong></code> | Head, tail | `{.` takes items, filling beyond bounds |
| <code data-mojj><strong>}.</strong></code>, <code data-mojj><strong>}:</strong></code> | Drop first or last item | `}.` drops items |
| <code data-mojj><strong>&#124;.</strong></code>, <code data-mojj><strong>&#124;:</strong></code> | Reverse leading items, transpose axes | Rotate, reorder axes |

`i. 2 3` produces a two-row, three-column matrix. `+/ i. 2 3` sums the rows to produce `3 5 7`. Use `+/"1 i. 2 3` to sum each row separately and obtain `3 12`. `1 2 3 +/ . * 4 5 6` computes the dot product 32. The same expression accepts conforming matrices.

## Parsing and modifiers

The parser implements the retained rows of the
[J parse table](https://www.jsoftware.com/help/dictionary/dicte.htm), including
noun sentences, hooks, forks, longer verb trains, parentheses, adverbs, and
conjunctions. It has no conventional arithmetic precedence: `10 % 3 + 2` is 2.
A train used in a sentence needs grouping: `(- *:) 3` is -6, while `- *: 3` is -9.

| Word | Symbol | Meaning |
| --- | --- | --- |
| <code data-mojj><ins>of</ins></code> | <code data-mojj><ins>@:</ins></code> | Whole-result composition, with infinite ranks |
| <code data-mojj><ins>atop</ins></code> | <code data-mojj><ins>@</ins></code> | Composition at the right verb's ranks |
| <code data-mojj><ins>insert</ins></code> | <code data-mojj><ins>/</ins></code> | Right-grouped reduction or dyadic table |
| <code data-mojj><ins>bind</ins></code> | <code data-mojj><ins>&amp;</ins></code> | Bind a noun, or apply the right verb to each argument of the left verb |
| <code data-mojj><ins>repeat</ins></code> | <code data-mojj><ins>^:</ins></code> | Apply a verb a fixed number of times |
| <code data-mojj><ins>reflex</ins></code> | <code data-mojj><ins>&#126;</ins></code> | Apply a dyad to the same argument twice, or swap its arguments |
| <code data-mojj><ins>rank</ins></code> | <code data-mojj><ins>"</ins></code> | Apply a verb to cells of specified ranks |
| <code data-mojj><ins>prefix</ins></code> | <code data-mojj><ins>&#92;</ins></code> | Prefixes, sliding windows, or disjoint blocks |
| <code data-mojj><ins>suffix</ins></code> | <code data-mojj><ins>&#92;.</ins></code> | Suffixes or complements of windows |
| <code data-mojj><strong>dot</strong></code> | <code data-mojj><strong>+</strong><ins>/</ins> <ins>.</ins> <strong>&#42;</strong></code> | Contract the last left and first right axes |
| `group … end` | `( … )` | Group a phrase |

Use `u ^: n`, `u repeat n`, or the typed `jj.Repeat[Op, n]` for a literal integer
from 0 through 1024. Each step uses the noun produced by the previous step.
For example, `(+: ^: 3) 2` doubles three times and returns 16.
With two arguments, each step keeps the original left argument, so
`2 (+ ^: 3) 10` returns 16. At count zero either valence returns the right
argument without invoking the verb. The limit applies to each repetition
operator. Nested operators can do more work. At count one, the derived verb
retains the operand’s ranks. At zero and at counts above one it has infinite
rank in each argument. This matters when composing with rank-sensitive `@`.

Rank accepts one, two, or three literal integers. One sets all ranks. Two specify left and right ranks, and the monad uses the right rank. Three specify monad, left, and right in order. A negative rank counts back from the argument rank, and `_` selects the whole argument.

Modifiers bind according to J, including to a preceding derived verb.
`*:@(+/)` squares the sum; `*:@+/` inserts the dyad `*:@+`. On `1 2 3 4`
they produce 100 and 6770404. `-/ 1 2 3` is `1 - (2 - 3)` = 2.

`@` and `@:` differ in rank. With vectors `1 2 3 4` and `7 5 3 2`,
`*/ @: +` returns 2016; `*/ @ +` returns `8 7 6 6`.
Atomic dyads use prefix shape agreement. An atom extends over every axis. A length-one
vector is not an atom and does not broadcast to a longer vector.

Numeric literals include signed Int64 integers, decimal Float64 values, and
bounded decimal exponents. J's underscore denotes a negative literal: `_3.5`,
`1e_2`. Whitespace-separated numbers form a vector. Literal 0 and 1 use Boolean
storage where appropriate; counts and integer arithmetic retain integer storage.
`2:` denotes a constant verb. A noun at the left of a fork also denotes a
constant branch. Noun binding supports scalar/vector nouns and noun sentences:
`10&-`, `-&10`, `0.5&*`, `(10 + 2)&-`.

Words are lowercase whole tokens. Space, tab, CR, and LF are whitespace;
a triple-quoted Mojo string can span several lines within one phrase. Punctuation delimits words. Words and symbols may be mixed. Unsupported
operators, names, assignments, Unicode, and arbitrary
modifier trains are rejected in standalone phrase literals. The [Mojj CLI](CLI.md) adds session noun names and assignment.

## Consumers

<pre data-mojj="mojo"><code>from mojj import Expr, Noun

var hook = Expr["<strong>minus</strong> <strong>square</strong>"].monad(Noun(3))
var difference = Expr["<strong>minus</strong>"].dyad(Noun(10), Noun(3))
var sentence = Expr["<em>10</em> <strong>divide</strong> <em>3</em> <strong>plus</strong> <em>2</em>"].value()</code></pre>

`monad` applies a verb to one noun and `dyad` applies it to two; both return
a `Noun`. `value` evaluates a complete noun sentence. A wrong consumer is a compile-time error. `describe()` works
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
