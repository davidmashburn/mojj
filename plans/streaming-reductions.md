# Streaming reductions over borrowed input

The foundation at [03a4576](https://github.com/davidmashburn/mojj/tree/03a4576)
can compute both population moments in one traversal. Independent reductions
over the same expensive scalar transform still evaluate that transform twice.
A caller extracting, for example, a sum and mean square from every other
sample also needs to copy the selected samples first.

## Implementation sequence

1. Add a read-only one-dimensional Float64 view with a runtime start, count
   and signed stride. Check positive and negative endpoints before arithmetic
   can overflow. Verify empty and singleton selections, reversal, repeated
   values, owner mutation and the lifetime of the borrow.
2. Add an explicit pair of streaming folds. Apply the shared scalar transform
   once to each selected input, then update each branch in logical order.
   Return two Float64 results. Give each evaluation fresh state and propagate
   branch errors. Keep left-to-right sum and mean compatible with the typed
   reducers, including empty inputs. Exercise a custom fold and a strided
   input through the packaged library.
3. Extend the API only if an actual caller needs additional arity, shaped
   input, or automatic recognition of common subexpressions in J forks.

## Related evidence

The [Linux workflow](https://github.com/davidmashburn/mojj/commit/30fe221)
runs tests, the demo and package imports on the locked native Ubuntu environment.
Track [the first hosted run](https://github.com/davidmashburn/mojj/actions/runs/44793497240)
independently of local Apple Silicon performance evidence.

## Implementation evidence

[StridedView](https://github.com/davidmashburn/mojj/commit/7446ed3) passed
bounds and live-owner tests on macOS arm64. Mojo permits the owner to grow
while a view exists, so the implementation borrows the list header. The
compiler rejected attempts to return a view of a local list or use the view
after moving its owner. The
[first hosted Linux check](https://github.com/davidmashburn/mojj/actions/runs/44793497240)
passed the full suite, demo and compiled-package smoke before the view landed.
Check each later revision independently.

The Linux reference runner now has a [pinned J
distribution](https://github.com/davidmashburn/mojj/commit/97327cd). A live
J probe during the empty-frame review exposed an incorrect output shape when
one argument to a ranked dyad still had a real cell. Add the three reproducers
to the cross-platform corpus with the fix.
