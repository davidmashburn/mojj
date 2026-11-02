# Mojj planning

Implementation branch: `main`. This orphan `project-planning` branch contains
proposals and design reasoning only; never merge it into implementation history.

## Active plan

- [Build a small compositional numerical library](plans/foundation.md)
- [Compile expression strings](plans/expression-strings.md)

## Ideas

- [One expression, two textual forms](ideas/expression-frontends.md)

Implementation starts from `main`. Usage documentation, implemented contracts,
and behavioral tests belong with the code. Update this index and each proposal
against actual commits as slices land.

Publication policy: make the first implementation commit locally, then obtain
explicit approval for the initial public repository push. Subsequent development
stays local until a later publication instruction. This planning branch is also
local unless explicitly included in that approval.

The initial `main` commit `9f745a0` was approved and published to
[davidmashburn/mojj](https://github.com/davidmashburn/mojj). All further work,
including this planning branch, remains local until separately authorized.

Local `main` now includes `811f40c`, the verified expression-string slice.
Its readable phrases and symbolic forms share compile-time parsing and typed
lowering. See the expression plan for exact scope and validation evidence.
