# Mojj planning

Implementation branch: `main`. This orphan `project-planning` branch contains
proposals and design reasoning only; never merge it into implementation history.

## Active plan

Next proposed step (2026-11-06): **measure and reduce compiled `Expr` overhead**.
See the [performance tuning plan](plans/expression-performance.md) for prioritized
hypotheses, a bounded first slice and correctness gates.

The original reference-fixture next step has landed in
[`09cf8d4`](https://github.com/davidmashburn/mojj/commit/09cf8d4df865581b60727b11ecddb512de3dcc13):
33 selected conformance expectations passed, with documented differences from J,
and nine provisional performance comparisons were recorded. This does not prove
full subset parity. The vocabulary roadmap below retains its original baseline
and proposal history; consult current implementation docs for shipped behavior.

- [Expr performance tuning](plans/expression-performance.md) — current next step;
  measure first, then optimize one demonstrated cost at a time.
- [J vocabulary and semantics roadmap](plans/j-vocabulary.md) — current proposal;
  J trains and modifiers, readable aliases, and include/defer/exclude decisions.
- [Build a small compositional numerical library](plans/foundation.md)
- [Compile expression strings](plans/expression-strings.md) — published prototype;
  its whitespace-composition grammar is under reconsideration.

## Ideas

- [One expression, two textual forms](ideas/expression-frontends.md)

Implementation starts from `main`. Usage documentation, implemented contracts,
and behavioral tests belong with the code. Update this index and each proposal
against actual commits as slices land.

Publication policy: make the first implementation commit locally, then obtain
explicit approval for the initial public repository push. Subsequent development
stays local until a later publication instruction. This planning branch is also
local unless explicitly included in that approval.

Both `9f745a0` and the expression-string slice `811f40c` were approved and
published to [davidmashburn/mojj](https://github.com/davidmashburn/mojj).
Remote `main` was verified at `811f40c` on 2026-11-02. The user authorized
publishing this planning branch on 2026-11-03, including the next-step note.

The original roadmap recommends J train rules for bare phrases and `of` as a word
alias for `@:`. A separate pipeline grammar remains an option, not an implemented
decision. No parser changes accompany this planning update. The 2026-11-06 performance
proposal was explicitly authorized for commit and push to this planning branch.
