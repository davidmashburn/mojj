# J vocabulary and semantics roadmap

Status: proposed; no new primitives implemented by this plan.
Observed 2026-11-02. Implementation baseline:
[`811f40c4d7a31df41a771a0200bc5937cae0b642`](https://github.com/davidmashburn/mojj/commit/811f40c4d7a31df41a771a0200bc5937cae0b642),
now published on `main`. Planning remains on the separate local
`project-planning` branch.

## Intent and recommendation

Preserve the parts of J that make numerical composition interesting: ambivalent
verbs, hooks/forks, modifiers, rank, array operations, and algebraic combinations.
Use Mojo for ordinary software structure, effects and integration. Readable
words should make J easier to spell, not silently change its grammar.

Recommended direction: **one J-inspired semantic model, two spellings**.
A readable word denotes the same verb/adverb/conjunction as its symbol.
Keep `of` as a proposed word alias for `@:`; bare sequences form J trains.
For example, `minus square` would spell the hook `- *:`, whereas
`minus of square` would spell `- @: *:`.
Their monadic results at 3 should be -6 and -9 respectively.

The user remains open to a separate pipeline DSL. Preserve that as an alternative,
not a settled rejection: it could reuse the same typed execution nodes through a
separately named entrypoint. Do not infer the mode from whether words or symbols
appear, or overload one bare phrase with two meanings. No new entrypoint name is
promised here. Resolve the public facade before replacing the existing parser.

Confidence is high that this keeps the distinctive compositional value while
avoiding a second host runtime. Confidence in detailed J compatibility is
provisional until a pinned J reference runner validates the retained subset.
Evidence that would change the recommendation: useful user phrases that remain
substantially clearer under a separate pipeline grammar, or reference tests
showing that the proposed limited noun/rank model cannot preserve their meaning.

## What exists, and what must change

Current [core](https://github.com/davidmashburn/mojj/blob/811f40c/src/mojj/core.mojo)
and [parser](https://github.com/davidmashburn/mojj/blob/811f40c/src/mojj/_syntax.mojo)
were inspected. They provide Float64 scalar operations, length-preserving list
maps, sum/mean, descriptions, and a bounded composition parser. Typed integer
Add/Scale parameters are not general binary verbs or noun binding.

The parser currently treats whitespace, `of`, and `@:` as composition.
It recognizes `+/` and `(+/ % #)` as special patterns, not as insertion and a
fork built from general operations. It has no J train, general valence, noun,
or rank model. Those are prototype limitations, not the intended J-compatible
contract. The current source tests establish its own behavior only.

Do not change the already-published parser silently. The first semantic
implementation needs a migration note, updated examples, and a breaking-change
commit where appropriate. Existing `sqrt mean square` must not continue to be
advertised as RMS under J train parsing. Use explicit composition such as
`sqrt of mean of square`, with `mean` expanding to the grouped J phrase.
Keep the original implementation evidence as historical evidence.

## Compatibility rules

1. Follow J's relevant [parsing rules](https://www.jsoftware.com/help/dictionary/dicte.htm)
   and [train rules](https://www.jsoftware.com/help/dictionary/dictf.htm).
   “Right to left” alone does not specify modifier binding or trains.
   Word aliases normalize to tokens before parsing; they do not choose a different grammar.
2. Represent a verb's supported monadic/dyadic cases and ranks. A name such as
   `minus` denotes the J verb with both meanings, not merely a unary negate node.
   Unsupported valences fail explicitly. Do not misreport a partially supported primitive.
3. Separate noun shape/dtype, verb valence/rank, and execution strategy.
   The current scalar-versus-reduction category is not a substitute for these.
   Typed construction and string construction must describe and execute the same tree.
4. Preserve [rank and frame agreement](https://www.jsoftware.com/help/dictionary/dictb.htm).
   J's `@` and `@:` are [not interchangeable](https://www.jsoftware.com/help/dictionary/d622.htm).
   Do not substitute NumPy broadcasting or map every verb elementwise by default.
5. Specify numerical compatibility, including J's
   [tolerant equality](https://www.jsoftware.com/help/dictionary/d000.htm),
   [floor](https://www.jsoftware.com/help/dictionary/d011.htm), and
   [division](https://www.jsoftware.com/help/dictionary/d130.htm).
   For example, J defines `0 % 0` as 0. Therefore the empty `(+/ % #)` phrase
   needs a reference test; current Mojj's empty-mean exception is not a faithful
   implementation of that phrase. Complex-producing cases of
   [square root](https://www.jsoftware.com/help/dictionary/d132.htm) must be
   rejected until complex values exist, rather than quietly changing their meaning.
6. Distinguish semantic grouping from optimization. Test insertion with
   non-associative verbs. Current left-to-right Float64 accumulation is not a
   specification for arbitrary J `u/`. Document floating-point differences;
   do not claim bitwise parity or reassociate reductions without evidence.
7. Retain bounded compile-time parsing, useful byte-offset diagnostics and
   no runtime interpreter. Raise explicit unsupported-domain/feature errors.
   Limits may need revision for J parsing, but remain tested and documented.

## Vocabulary decisions

**Include** means a planned supported subset, not “implemented.”
**Skip for now** means worthwhile but waiting on the stated prerequisite.
**Exclude** means deliberately use Mojo instead for this product scope.
A primitive can occur in more than one row when its valences or operand forms
deserve different decisions. Proposed word aliases are illustrative.

This is a family-level roadmap across the official
[J vocabulary index](https://www.jsoftware.com/help/dictionary/vocabul.htm),
not a promise to cover every foreign, modifier variant, numeric domain or J
release extension. Each row links to an actual J definition. The wiki returned
403 during research; the accessible official dictionary supplies the references.

Phases: P1 = semantic foundation; P2 = numeric breadth and reusable reductions;
P3 = shaped arrays, rank and traversal. A restricted earlier implementation must
reject cases whose prerequisites have not landed.

| J vocabulary / form | Decision | Proposed support or prerequisite | Why |
| --- | --- | --- | --- |
| [Hooks, forks, longer verb trains](https://www.jsoftware.com/help/dictionary/dictf.htm) | **Include** · P1 | Word sequences follow J train rules; named branch trees remain inspectable. | This is the compositional character the user wants. Current whitespace pipelines are not compatible. |
| [Monads, dyads, modifier binding](https://www.jsoftware.com/help/dictionary/dicte.htm) | **Include** · P1 | Implement the relevant J parse-table rules, not a generic right-associative chain. | Valence and modifier precedence determine meaning before numerical execution. |
| [@: composition](https://www.jsoftware.com/help/dictionary/d622.htm) | **Include** · P1 | Keep `of` as its proposed word alias; existing prototype supports restricted composition. | Readable composition without redefining bare trains. Preserve whole-result application. |
| [@ composition](https://www.jsoftware.com/help/dictionary/d620.htm) | **Include** · P1/P3 | `atop`; implement rank-aware behavior, with explicit restrictions before general arrays. | Do not alias @ to @:. Their rank difference is meaningful, not disposable syntax. |
| [[ and ]](https://www.jsoftware.com/help/dictionary/d500.htm) | **Include** · P1 | Identity monads and left/right dyadic selectors; only ] monad exists now. | Selectors make useful hooks and forks. Words must denote the whole ambivalent verb. |
| [[: cap](https://www.jsoftware.com/help/dictionary/d502.htm) | **Include** · P1 | `cap` in trains, with J's capped-fork behavior. | Useful structural shorthand; do not treat cap as an ordinary identity function. |
| [+ and -](https://www.jsoftware.com/help/dictionary/d100.htm) | **Include** · P1 | Arithmetic dyads; real-domain monads. Negation exists; Add[Int] is only a bound typed operation. | Binary arithmetic unlocks forks. Link for subtraction: [−](https://www.jsoftware.com/help/dictionary/d120.htm). |
| [* and %](https://www.jsoftware.com/help/dictionary/d110.htm) | **Include** · P1 | Times/divide and sign/reciprocal on supported real values. | Essential binary kernels. Division must account for J's special cases: [%](https://www.jsoftware.com/help/dictionary/d130.htm). |
| [*: and +:](https://www.jsoftware.com/help/dictionary/d112.htm) | **Include** · P1/P2 | Existing square/double monads; add their Boolean dyads when Boolean nouns land. | Do not label an entire primitive supported after implementing only its familiar monad. [+:](https://www.jsoftware.com/help/dictionary/d102.htm) |
| [-:, <: and >:](https://www.jsoftware.com/help/dictionary/d122.htm) | **Include** · P2 | Halve, decrement, increment; also match and ordered comparisons within supported types. | Cheap useful kernels, but monadic and dyadic meanings need separate tests. [<:](https://www.jsoftware.com/help/dictionary/d012.htm), [>:](https://www.jsoftware.com/help/dictionary/d022.htm) |
| [%:, ^ and ^.](https://www.jsoftware.com/help/dictionary/d132.htm) | **Include** · P2 | Real-domain roots, powers, exponentials, logarithms; sqrt is partial today. | Core numerical vocabulary. Reject unsupported complex results explicitly. [^](https://www.jsoftware.com/help/dictionary/d200.htm), [^.](https://www.jsoftware.com/help/dictionary/d201.htm) |
| [Magnitude/residue and floor/min, ceiling/max](https://www.jsoftware.com/help/dictionary/d230.htm) | **Include** · P2 | Absolute value and signed residue; both valences of <. and >. on supported reals. | Useful normalization and clipping. Preserve J's sign/tolerance rules. [<.](https://www.jsoftware.com/help/dictionary/d011.htm), [>.](https://www.jsoftware.com/help/dictionary/d021.htm) |
| [=, ~:, <, >, <: and >: comparisons](https://www.jsoftware.com/help/dictionary/d000.htm) | **Include** · P2 | Boolean results and J-compatible comparison tolerance for supported numeric nouns. | Needed for predicates; equality cannot silently become exact Float64 comparison. Monadic classification/boxing is separate. [~:](https://www.jsoftware.com/help/dictionary/d222.htm), [<](https://www.jsoftware.com/help/dictionary/d010.htm), [>](https://www.jsoftware.com/help/dictionary/d020.htm) |
| [-., +., *. Boolean cases](https://www.jsoftware.com/help/dictionary/d121.htm) | **Include** · P2 | Complement and Boolean dyads first; numeric gcd/lcm remain deferred. | Useful predicate algebra. Not is 1-y in J, not generic truthiness. [+.](https://www.jsoftware.com/help/dictionary/d101.htm), [*.](https://www.jsoftware.com/help/dictionary/d111.htm) |
| [& noun binding and verb composition](https://www.jsoftware.com/help/dictionary/d630n.htm) | **Include** · P1/P2 | Typed bind-left/right first; literals and word aliases use the same nodes. | Captures parameterized kernels without adding runtime environments. Preserve operand order and distinguish [verb/verb composition](https://www.jsoftware.com/help/dictionary/d630v.htm). |
| [~ with verb operand](https://www.jsoftware.com/help/dictionary/d220v.htm) | **Include** · P2 | Reflex and swapped arguments; no name lookup through noun operands. | Tiny combinator with large reuse value; subtraction/division expose ordering bugs. |
| [/ insertion and # tally](https://www.jsoftware.com/help/dictionary/d420.htm) | **Include** · P1/P2 | General numeric insertion with specified identities; tally as an actual verb. +/ exists only as a token today. | Replace special-case sum/mean parsing with derivation. Preserve J grouping for non-associative reducers. [#](https://www.jsoftware.com/help/dictionary/d400.htm) |
| [Mean phrase (+/ % #)](https://www.jsoftware.com/help/dictionary/dictf.htm) | **Include** · P1 | Make `mean` a grouped named phrase over insert, divide, tally and fork. | Useful proof that the machinery composes. Today's special-case Mean raises on empty input; that is not evidence of J parity. |
| [Numeric nouns and constant verbs](https://www.jsoftware.com/help/dictionary/dconsf.htm) | **Include** · P1/P2 | Bounded real/Boolean/integer literals and small arrays; constant verbs, with proper lexical distinction. | Needed by bond and rank; no arbitrary source execution. J negative literal spelling is [distinct from subtraction](https://www.jsoftware.com/help/dictionary/d120.htm). |
| [$ and i. array construction](https://www.jsoftware.com/help/dictionary/d210.htm) | **Include** · P3 | Shape/reshape and integer generation, with checked shapes and explicit supported ranks. | Needed for useful array algebra; shape is not just list length. [i.](https://www.jsoftware.com/help/dictionary/didot.htm) Index-of is deferred. |
| [Rank conjunction "](https://www.jsoftware.com/help/dictionary/d600v.htm) | **Include** · P3 | Numeric rank operands, cell/frame agreement and tested result assembly. | Central J machinery worth preserving. Higher-rank cases stay unsupported until the noun model can represent them honestly. |
| [,, ,. and ,:](https://www.jsoftware.com/help/dictionary/d320.htm) | **Include** · P3 | Numeric ravel/append, stitch and laminate after shapes exist. | Useful construction primitives; specify axes and fill behavior rather than treating them all as concatenation. [,.](https://www.jsoftware.com/help/dictionary/d321.htm), [,:](https://www.jsoftware.com/help/dictionary/d322.htm) |
| [{, {., {:, }., }:](https://www.jsoftware.com/help/dictionary/d520.htm) | **Include** · P3 | Numeric gather, head/tail, take/drop and curtail; bounded views where valid. | High practical value for data pipelines. Test negative indices, overtake/fill and empty results. [{.](https://www.jsoftware.com/help/dictionary/d521.htm), [{:](https://www.jsoftware.com/help/dictionary/d522.htm), [}.](https://www.jsoftware.com/help/dictionary/d531.htm), [}:](https://www.jsoftware.com/help/dictionary/d532.htm) |
| [\|. and \|:](https://www.jsoftware.com/help/dictionary/d231.htm) | **Include** · P3 | Reverse/rotate and numeric transpose; typed views where possible. | Index transformations compose well and expose strides without a new language runtime. [Transpose](https://www.jsoftware.com/help/dictionary/d232.htm) |
| [# copy/filter](https://www.jsoftware.com/help/dictionary/d400.htm) | **Include** · P3 | Boolean masks and nonnegative integer repetition counts first. | Makes predicates useful. Output length changes require a new series contract; complex-count fill is deferred. |
| [\ prefix/infix and \. suffix/outfix](https://www.jsoftware.com/help/dictionary/d430.htm) | **Include** · P3 | Scans and windows with J segment rules; suffix/outfix follow after prefix coverage. | High-value signal/statistics operations. Negative window sizes are not ordinary sliding windows. [Suffix/outfix](https://www.jsoftware.com/help/dictionary/d431.htm) |
| [/ table and +/ . * dot](https://www.jsoftware.com/help/dictionary/d420.htm) | **Include** · P3 | Outer products and vector dot first, then matrix products when shape rules pass. | Useful pairwise algebra. General determinant/permanent forms remain deferred. [Dot](https://www.jsoftware.com/help/dictionary/d300.htm) |
| [o. real numerical cases](https://www.jsoftware.com/help/dictionary/dodot.htm) | **Include** · P2 | Pi-times plus documented real trigonometric selector cases; friendly sin/cos names can expand to bound verbs. | Useful math without losing the J derivation; do not claim complex selector coverage. |
| [/. key and oblique](https://www.jsoftware.com/help/dictionary/d421.htm) | **Skip for now** · After P3 | Revisit after shaped arrays, grouping outputs and equality semantics are stable. | Useful grouped reductions/convolution, but result shape and grouping make this more than another fold. |
| [~., monadic ~:, monadic =](https://www.jsoftware.com/help/dictionary/d221.htm) | **Skip for now** · After P3 | Unique, uniqueness masks and classification after order/tolerance rules are fixed. | Do not accidentally use hashing that disagrees with J equality. [~:](https://www.jsoftware.com/help/dictionary/d222.htm), [=](https://www.jsoftware.com/help/dictionary/d000.htm) |
| [/: and \:](https://www.jsoftware.com/help/dictionary/d422.htm) | **Skip for now** · After P3 | Grade/sort after ordering, NaNs and stable tie behavior have a tested contract. | Useful but separate from the first composition kernels. [Descending](https://www.jsoftware.com/help/dictionary/d432.htm) |
| [e., E., dyadic i./i:, I., dyadic -.](https://www.jsoftware.com/help/dictionary/dedot.htm) | **Skip for now** · After P3 | Membership, search, index-of, interval lookup and set difference. | Need coherent index/result types, not Float64 stand-ins. [E.](https://www.jsoftware.com/help/dictionary/decapdot.htm), [i:](https://www.jsoftware.com/help/dictionary/dico.htm), [I.](https://www.jsoftware.com/help/dictionary/dicapdot.htm), [less](https://www.jsoftware.com/help/dictionary/d121.htm) |
| [;. cut](https://www.jsoftware.com/help/dictionary/d331.htm) | **Skip for now** · After views | Revisit fixed numeric partition cases after ordinary windows. | Boundary markers and variable-size partitions deserve explicit shape semantics. |
| [} amend](https://www.jsoftware.com/help/dictionary/d530n.htm) | **Skip for now** · After nouns | Consider a pure result-producing update, then separately optimize storage reuse. | Useful J operation; ownership, aliasing and repeated-index semantics need care. It is not automatically in-place mutation. |
| [%. and general u . v](https://www.jsoftware.com/help/dictionary/d131.htm) | **Skip for now** · After P3 | Matrix solving and generalized products/determinants. | Require numerical algorithm/backend choices and conditioning tests. Vector dot need not wait for this. |
| [^: bounded repetition](https://www.jsoftware.com/help/dictionary/d202n.htm) | **Skip for now** · After P2 | Nonnegative integer repeat with execution and compilation limits. | Useful combinator; inverse, convergence and array-of-powers cases need separate treatment. |
| [&., &.: and :. transformations](https://www.jsoftware.com/help/dictionary/d631.htm) | **Skip for now** · After P2 | Explicit inverse/obverse pairs first, no speculative automatic inverse engine. | Mathematically valuable and compositional, but domain restrictions matter. [&.:](https://www.jsoftware.com/help/dictionary/d631c.htm), [:.](https://www.jsoftware.com/help/dictionary/d311.htm) |
| [&: appose](https://www.jsoftware.com/help/dictionary/d632.htm) | **Skip for now** · After P2 | Preserve its distinct rank behavior when binary composition is stable. | Do not add a misleading alias just because current scalars make it appear equivalent. |
| [@., ` and `:](https://www.jsoftware.com/help/dictionary/d621.htm) | **Skip for now** · After branch nodes | Static branch selection and finite gerund forms only initially. | Useful structured control over expressions; general gerund forms broaden parsing/result kinds. [Tie](https://www.jsoftware.com/help/dictionary/d610.htm), [evoke](https://www.jsoftware.com/help/dictionary/d612.htm) |
| [!. customization](https://www.jsoftware.com/help/dictionary/d411.htm) | **Skip for now** · After P2 | Small documented tolerance/fill cases, not an arbitrary options DSL. | Default J tolerance/fill still matters before exposing this modifier; it is not permission to ignore defaults. |
| [Complex numbers, j., r., complex +./*.](https://www.jsoftware.com/help/dictionary/djdot.htm) | **Skip for now** · When needed | Add a complex dtype and promotion rules together. | Useful numerical extension; currently reject unsupported domains rather than substitute real results. [r.](https://www.jsoftware.com/help/dictionary/drdot.htm) |
| [$. sparse](https://www.jsoftware.com/help/dictionary/d211.htm) | **Skip for now** · When needed | A separate sparse representation and algorithms. | Worth considering for workloads; cannot be implemented faithfully by renaming dense list operations. |
| [GCD/LCM, #., #:, b.](https://www.jsoftware.com/help/dictionary/d101.htm) | **Skip for now** · After integer nouns | Exact integer kernels and base/bit operations after a real integer type exists. | Float64 cannot carry arbitrary integer semantics safely. [LCM](https://www.jsoftware.com/help/dictionary/d111.htm), [#.](https://www.jsoftware.com/help/dictionary/d401.htm), [#:](https://www.jsoftware.com/help/dictionary/d402.htm), [b.](https://www.jsoftware.com/help/dictionary/dbdotn.htm) |
| [!, p., p.., p:, q:, H.](https://www.jsoftware.com/help/dictionary/d410.htm) | **Skip for now** · Demand-led | Combinatorics, polynomials, primes and special functions as later numerical modules. | Useful specialist math, low priority for validating composition. [p.](https://www.jsoftware.com/help/dictionary/dpdot.htm), [p..](https://www.jsoftware.com/help/dictionary/dpdotdot.htm), [p:](https://www.jsoftware.com/help/dictionary/dpco.htm), [q:](https://www.jsoftware.com/help/dictionary/dqco.htm), [H.](https://www.jsoftware.com/help/dictionary/dhcapdot.htm) |
| [d., D., D:, t., t:, T.](https://www.jsoftware.com/help/dictionary/ddcapdot.htm) | **Skip for now** · Research | Differentiation and Taylor operations after expression semantics stabilize. | Inspectable structure makes this interesting; a real differentiation design is needed, not merely kernel compilation. [d.](https://www.jsoftware.com/help/dictionary/dddot.htm), [D:](https://www.jsoftware.com/help/dictionary/ddcapco.htm), [t.](https://www.jsoftware.com/help/dictionary/dtdotu.htm), [t:](https://www.jsoftware.com/help/dictionary/dtco.htm), [T.](https://www.jsoftware.com/help/dictionary/dtcapdot.htm) |
| [A., C., .. and .:](https://www.jsoftware.com/help/dictionary/dacapdot.htm) | **Skip for now** · Demand-led | Permutation algebra and even/odd function transformations. | Compositional but not needed for the first real workloads. [C.](https://www.jsoftware.com/help/dictionary/dccapdot.htm), [../.:](https://www.jsoftware.com/help/dictionary/d301.htm) |
| [< and > monads; ; and boxed traversal](https://www.jsoftware.com/help/dictionary/d010.htm) | **Skip for now** · Separate noun design | Box/open, raze/link, {::, L., L:, S: only with a coherent heterogeneous noun design. | Boxing is powerful J, not silly; postpone it rather than pretending numeric arrays cover it. [>](https://www.jsoftware.com/help/dictionary/d020.htm), [;](https://www.jsoftware.com/help/dictionary/d330.htm), [{::](https://www.jsoftware.com/help/dictionary/d523.htm), [L.](https://www.jsoftware.com/help/dictionary/dlcapdot.htm), [L:](https://www.jsoftware.com/help/dictionary/dlcapco.htm), [S:](https://www.jsoftware.com/help/dictionary/dscapco.htm) |
| [=. and =:; locales and dynamic names](https://www.jsoftware.com/help/dictionary/d001.htm) | **Exclude** · Host Mojo | Keep binding, modules and scope in Mojo; permit only explicit compile-time expression registrations. | Mojj should be an embedded numerical language, not another environment inside the host. |
| [: explicit definitions; control sentences; $: recursion](https://www.jsoftware.com/help/dictionary/d310n.htm) | **Exclude** · Host Mojo | Write function bodies, loops and recursion in Mojo. | These duplicate the host rather than improve numerical composition. [Controls](https://www.jsoftware.com/help/dictionary/ctrl.htm), [$:](https://www.jsoftware.com/help/dictionary/d212.htm) |
| [: monad/dyad pairing](https://www.jsoftware.com/help/dictionary/d310v.htm) | **Skip for now** · After valence model | Retain as a possible pure combinator distinct from explicit-definition syntax. | It combines verb meanings rather than recreating a scripting language. |
| [!: foreigns](https://www.jsoftware.com/help/dictionary/d412.htm) | **Exclude** · Host Mojo | Use Mojo/library APIs for files, OS calls, FFI and other external effects. | No effectful escape hatch inside inspectable numerical phrases. |
| [". execution; noun~ name invocation; f. fix](https://www.jsoftware.com/help/dictionary/d601.htm) | **Exclude** · Host Mojo | No dynamic source evaluation or runtime lookup of J names. | Compile-time literals and explicit registrations keep dependencies visible. [Noun~](https://www.jsoftware.com/help/dictionary/d220n.htm), [f.](https://www.jsoftware.com/help/dictionary/dfdot.htm) |
| [": formatting; ;: tokenizer; a., u:, s:](https://www.jsoftware.com/help/dictionary/d602.htm) | **Exclude** · Host Mojo | Use host formatting, text processing, Unicode and string/symbol facilities. | Separate text libraries are more useful than duplicating J's text runtime. [;:](https://www.jsoftware.com/help/dictionary/d332.htm), [a.](https://www.jsoftware.com/help/dictionary/dadot.htm), [u:](https://www.jsoftware.com/help/dictionary/duco.htm), [s:](https://www.jsoftware.com/help/dictionary/dsco.htm) |
| [? and ?.](https://www.jsoftware.com/help/dictionary/d640.htm) | **Exclude** · Host Mojo | Generate random inputs through an explicitly seeded host API. | Hidden/random state would complicate pure expression reuse. A future explicit-state RNG adapter is a separate proposal. [?.](https://www.jsoftware.com/help/dictionary/d641.htm) |
| [M. memo and :: adverse](https://www.jsoftware.com/help/dictionary/dmcapdot.htm) | **Exclude** · Host Mojo | Keep caching and exception/recovery policy in Mojo. | Hidden caches and catch-all recovery obscure evaluation and failure behavior. [::](https://www.jsoftware.com/help/dictionary/d312.htm) |
| [NB. inside literals](https://www.jsoftware.com/help/dictionary/dnb.htm) | **Exclude** · Host comments | Use Mojo comments adjacent to the expression; keep literals focused. | Low compositional value; can revisit only if multiline expression authoring needs it. |
| [x: extended/rational arithmetic](https://www.jsoftware.com/help/dictionary/dxco.htm) | **Skip for now** · Separate dtype work | Consider through a future explicit dtype/backend proposal. | Mathematically useful, but a new exact-number system is outside the first numerical core. |
| [_, _. and _: special constants](https://www.jsoftware.com/help/dictionary/d030.htm) | **Skip for now** · Numeric policy | Negative-number spelling belongs in P1; infinity/indeterminate syntax waits for special-value tests. | Do not confuse literal notation with a new operator or promise J special arithmetic prematurely. [_.](https://www.jsoftware.com/help/dictionary/d031.htm), [_:](https://www.jsoftware.com/help/dictionary/d032.htm) |

## Delivery order and acceptance gates

### P0 — establish semantic fixtures before adding vocabulary

Create a compatibility ledger of supported valences, ranks, dtypes, edge cases
and documented deviations. Pin a J executable/version for development-only
reference tests; do not assume the system command named `jconsole` is J.
The compiled library must not depend on J or Python at runtime.

Next implementation task should produce a small, reviewed parser/noun/verb
contract and reference fixtures, not a bulk vocabulary port. It should resolve
the proposed `of` alias and the migration from current whitespace pipelines.
Do not expand the current composition grammar piecemeal into accidental J.

### P1 — enough J to compose real verbs

Implement a bounded grammar for the retained parts of speech, parentheses,
monadic/dyadic verb application, hooks/forks/longer verb trains, `[:`, `@:`,
rank-correct supported cases of `@`, noun binding, numeric literals, `/`
and `#`. Start with scalar and simple vector inputs and a small arithmetic
set. Add Boolean/integer noun kinds when needed; do not store indices/counts as
approximate Float64 values. This is several small commits, not one large parser
rewrite.

Use these discriminating fixtures (expected values below are mathematical
expectations; no J executable was run during this planning task):

| Case | Expected distinction |
| --- | --- |
| `(- *:) 3` versus `(- @: *:) 3` | Hook gives -6; explicit composition gives -9. |
| `(*: + +:) 3` | Fork gives 15, not sequential application of three monads. |
| `(+/ % #) 1 2 3 4` | Mean is derived as a fork and gives 2.5; no special parser pattern. |
| `-/ 1 2 3` | Right-grouped subtraction gives 2; a left fold would give -4. |
| `10&-` versus `-&10`, applied to 3 | Results 7 and -7 distinguish binding sides. |
| `10 % 3 + 2` | Ordinary noun sentence gives 2; conventional arithmetic precedence would differ. |
| Dyadic `*/ @: +` versus `*/ @ +` on 1 2 3 4 and 7 5 3 2 | Whole-result product 2016 versus per-cell results 8 7 6 6. |
| `0 % 0`, empty mean, negative square root | Pin special-value/domain behavior, not only happy-path numerics. |
| Words versus symbolic spelling for every case | Same tree, valence, rank behavior, values and failures. |
| Malformed/truncated phrases and bounded generated expressions | Controlled compile errors; no compiler crashes or unbounded specialization. |

The [composition reference](https://www.jsoftware.com/help/dictionary/d620.htm)
also supplies modifier-binding examples such as `*:@(+/)` versus `*:@+/`;
retain those distinctions instead of flattening every phrase into a pipeline.

### P2 — useful numerical breadth and shared evaluation

Add the included scalar math and comparisons with documented domains. Build
product/min/max/all/any and mean from general operations where appropriate.
Implement branch-local maps and explicit shared traversal for compatible
reduction forks; benchmark before claiming fusion. Stable moments may be
Mojj-specific numerical nodes, clearly distinguished from J vocabulary aliases.

Keep exact integer/Boolean fixtures exact. For floating computations use a
documented reference tolerance and test cancellation, NaNs, infinities, signed
zero, empty inputs, and error behavior where supported. Test reuse across runtime
sizes and prove no accumulator state leaks between evaluations.

### P3 — arrays, rank, views and windows

Introduce numeric shapes/cells, then rank and agreement, reshape, gather,
take/drop, transpose, masks, scans, windows, outer products and dot products.
Current `SeriesExpr.read(data,index)` assumes the original input length;
length-changing and shaped operations require an explicit output-shape contract.
Define ownership and partial-write behavior before exposing mutable consumers.

Use fixtures distinguishing atoms from singleton vectors, row versus whole-array
reduction, empty axes, negative indices, fills, mismatched frames, and J's
negative-infix rules. General rank is an architectural milestone, not a token
alias to be shipped ahead of its semantics.

## Boundaries and verification record

This task creates a plan only. Future implementation is confined to Mojj's typed
nodes, parser, consumers, examples and tests, with planning evidence updated
separately. No prototype code/history is imported from jnumpy. No full J runtime,
dynamic evaluation, I/O language, automatic optimizer, or performance claim is
authorized by the vocabulary list.

Inspected current source and official references in this task. The preceding
implementation run reported 19 positive test groups, 25 negative compiler
fixtures, demos and precompiled-package checks passing on macOS arm64. Those
were not rerun for this documentation-only task and are not J conformance tests.
Linux, remote CI, a J reference execution, and performance parity remain
unverified. Publication of main at `811f40c` was verified against the remote.

Checked all 58 table rows for consistent columns and all relative links for
existing targets. Of 122 distinct J dictionary links, 119 match links from the
official vocabulary index; the remaining three grammar pages were opened
directly. This validates destinations, not every proposed semantic case.

See [foundation](foundation.md) for the original staged rationale. This roadmap
puts semantic fidelity work ahead of extending its previously proposed shared
reductions and views; those remain useful subsequent stages.
