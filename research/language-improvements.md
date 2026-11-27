# Evaluating changes to Mojj's language

Research baseline, 2026-11-27. Implementation at `69a6b9f` on `main`. Use the shipped language as the control. For each candidate, specify the intended reader, the task they should be able to do, the nearest existing spelling, and a case where two plausible readings give different answers.

## Rubric

| Criterion | Test | Decision rule |
| --- | --- | --- |
| Meaning and compatibility | Predict value, shape, type and failure behavior. Exercise an ordinary input, a boundary and an existing program using affected syntax or names. | A changed result or a newly rejected valid program fails compatibility. Any intended difference needs a stated contract. |
| Inspection | Ask a reader to identify the decisive operation, predict the effect of one edit and inspect the relevant intermediate. Examine the expression description where the interface exposes one. | Advance a readability claim only when the reader can explain and verify the edit. |
| Authoring | Give an unfamiliar author the same task, inputs and public docs for each spelling. Record their first attempt, mistakes, lookups and assistance. | Prefer the spelling that resolves a demonstrated difficulty. Character count is descriptive only. |
| Composition | Reuse the idea on a second task, change one operand and try it in the claimed interfaces. | Identify both what transfers and which new rule the author must learn. A domain-specific convenience can still qualify for a narrower scope. |
| Cost of adoption | Inventory reserved names, grammar and evaluator changes, migration, documentation and test obligations. Include a documentation-only control. | Prefer the least disruptive alternative with the demonstrated benefit. Require matched benchmarks only for speed or resource claims. |

Record each criterion as **gain**, **tie**, **loss** or **unknown** relative to the control, with a concrete observation. A mandatory compatibility failure can reject a spelling even while usability is unknown. To recommend adoption, require a demonstrated task gain, resolved semantic and compatibility checks, and an account of costs. Otherwise select a narrower trial, defer, or reject. Do not sum the ratings.

## First investigation

Compare the shipped `width (identity prefix) samples` with a proposed reserved dyadic verb `width windows samples`, and with a documentation-only alternative that explains the existing phrase. The shipped script already gives the resulting matrix a local name. The FIR example and the discussion in `docs/TERSENESS.md` identify this exact reading difficulty. The intended reader knows arrays and is new to Mojj.

1. Run the shipped FIR and its correlation edit. Predict first outputs 11 and 17 and inspect the windows. If the current spelling already isolates the edit, credit that to the baseline.
2. Test the proposed spelling's name against shipped script bindings and session naming rules. An existing legal binding that would become illegal rejects unconditional reservation.
3. Check whether a single phrase denotes only complete sliding windows across positive, zero and negative widths. Freeze the prediction that width 2 slides and width -2 takes disjoint blocks. Unexpected edge behavior requires explicit semantics before recommending a name.

## Results

Ran the shipped FIR script through `pixi run mojj` on macOS, then appended the sentences below in the same session. The final assignment was an intentional negative control and the launcher exited 1.

| Cycle | Sentence | Observed result |
| --- | --- | --- |
| 1 | Shipped script, ending in `filtered` | `[11, 22, 44]` |
| 1 | `windows` | Shape [3, 3], rows [1, 2, 4], [2, 4, 8], [4, 8, 16] |
| 1 | `windows dot taps` | `[17, 34, 68]` |
| 2 | Shipped assignment to `windows`, then `sum =: 42` | Existing noun bound successfully. Existing verb name failed with `reserved or invalid name: sum`. |
| 3 | `2 (identity prefix) samples` | Shape [4, 2], overlapping pairs [1, 2], [2, 4], [4, 8], [8, 16] |
| 3 | `_2 (identity prefix) samples` | Shape [3, 2], disjoint pairs [1, 2], [4, 8], [16, 0]. The final pair includes fill. |
| 3 | `0 (identity prefix) samples` | Shape [6, 0], six empty windows |

Replay from the implementation checkout at `69a6b9f`. The table groups observations by question. The command keeps the rejected assignment last so all results print before the session exits.

```sh
{
  cat examples/algorithms/fir.mojj
  cat <<'MOJJ'
windows
windows dot taps
2 (identity prefix) samples
_2 (identity prefix) samples
0 (identity prefix) samples
sum =: 42
MOJJ
} | pixi run mojj
```

**Decision.** Reject adding `windows` as an unconditionally reserved verb under the current naming contract. Compatibility is a **loss** with high confidence. The [shipped example](https://github.com/davidmashburn/mojj/blob/69a6b9f/examples/algorithms/fir.mojj) binds exactly this name and [session assignment](https://github.com/davidmashburn/mojj/blob/69a6b9f/src/mojj/_session.mojo) requires the parser to return a name. A proposal that preserves existing bindings would need its own resolution tests.

The existing named intermediate already supports the tap-order edit and inspection. An inspection or authoring **gain remains unknown** until readers try both spellings. For composition, a direct synonym inherits zero-width and filled-block behavior. A positive-width-only verb would introduce a distinct contract. Cross-task transfer remains **unknown**. Adoption cost is a **loss** for reservation because even the shipped example needs migration. No candidate implementation, human author trial, expression-description comparison, benchmark, or full suite was run.

### Proposed reader trial

Give each unfamiliar reader one version of the walkthrough. Both versions use the same FIR script. The revised version explains which samples enter each overlapping pair and shows how a final short block receives fill. Ask readers in both groups to change the FIR from convolution to correlation and predict its first output before execution.

For the transfer task, use fresh samples `3 5 8 13` and width `_3`. Ask for the matrix shape and final row before allowing execution. Keep the evaluator's expected shape [2, 3] and final row [13, 0, 0] out of the reader materials. Record the first prediction, documentation lookups, corrections and help for each task. This comparison can test a documentation improvement. The proposed verb would require a separate authoring trial.
