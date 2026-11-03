# Mojj planning

Implementation branch: `main`. This orphan `project-planning` branch contains
proposals and design reasoning only; never merge it into implementation history.

## Active plan

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
Remote `main` was verified at `811f40c` on 2026-11-02. This planning branch
remains local; the later push approval covered the implementation commit.

The new roadmap recommends J train rules for bare phrases and `of` as a word
alias for `@:`. A separate pipeline grammar remains an option, not an implemented
decision. No parser changes accompany this planning update.
