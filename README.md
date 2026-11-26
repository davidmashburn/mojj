# Mojj

Inspectable numerical composition in Mojo.

Mojj builds calculations from small, typed operations. The same expression can
describe its structure and evaluate runtime data. This is a fresh, deliberately
small J-inspired library; it is not a J interpreter or a general array package.

Start with [Learn Mojj with words](docs/WORDS.md) for a hands-on walkthrough, or explore [Mojj by example](docs/SHOWCASE.md) for side-by-side NumPy, MATLAB, NuMojo, Mojj, and J recipes covering array shapes, reductions, windows, and composition.

Work through a [signal filter and a neural-network training step](docs/ALGORITHMS.md) to compare Mojj with mathematical notation and executable array code.

## Try the Mojj prompt

Run `pixi run mojj` from the repository root. It starts a Mojo REPL under the hood and accepts Mojj sentences directly.

```text
mojj> v =: 1 2 3 4
mojj> sum prefix v
[1, 3, 6, 10]
```

See [the command-line guide](docs/CLI.md) for assignment, multiline input, scripts, and the equivalent Mojo REPL code.

## First example

```mojo
from std.collections import List
import mojj as jj

def main() raises:
    comptime RMS = jj.After[jj.Sqrt, jj.Mean[jj.Map[jj.Square]]]
    comptime description = RMS.describe()
    var data: List[Float64] = [3.0, 4.0]
    print(description)
    print(jj.evaluate[RMS](data))  # approximately 3.5355339059327378
```

The description is `after(sqrt, mean(map(square, input)))`. `Map` computes each
square when `Mean` requests it; the source contains one reduction loop and no
intermediate squared list. `After` applies the square root to that result.

Composition applies its inner operation first:

```mojo
comptime Pipeline = jj.Map[jj.Compose[jj.Scale[3], jj.Add[2]]]
var output = jj.materialize[Pipeline](data)  # (x + 2) * 3
```

`materialize` creates a fresh result list. The source list is not changed.

## Compiled J phrases

Readable words and J symbols share one bounded grammar and typed verb model:

```mojo
comptime Words = jj.Expr["sqrt of mean of square"]
comptime Symbols = jj.Expr["%: @: (+/ % #) @: *:"]
var rms = Words.reduce(data)
```

Bare verb sequences form J trains. `Expr["minus square"].apply(3.0)` is -6;
`Expr["minus of square"].apply(3.0)` is -9. Composition requires `of` or `@:`.
Mean is the derived fork `(+/ % #)`, and its empty-vector result is zero.

The showcase imports the shorthand with `from mojj import jj`. Wrap Mojo data
with `jj(3)` or `jj([2, 4])`. For a scalar or typed list `x`, the explicit
spelling is `Noun(x)`. Write `jj["10 - 3"]()` for a complete sentence,
`jj["-"](y)` for negation, or `jj["-"](x, y)` for subtraction. All return
nouns. To use the module and the shorthand side by side, use `import mojj`
and `from mojj import jj`. You can then name an inspectable verb with
`comptime Negate = mojj.Expr["-"]`.

Use `monad(Noun)` or `dyad(Noun, Noun)` for verb application, and `value()`
for a complete noun sentence such as `10 divide 3 plus 2`. Nouns distinguish
atoms, vectors, and higher-rank arrays with Boolean, integer, or real storage.
For example, `Expr["3 | 10"].value()` computes a residue, and
`Expr["3 -~ 10"].value()` subtracts 3 from 10. The Float64
convenience consumers are `apply`, `map`, and `reduce`. When the input list
is disposable, `Expr["+:"].map_owned(data^)` or `Expr["+/"].reduce_owned(data^)`
transfers its storage into evaluation. Pass a temporary directly, or use
`map(data)` and `reduce(data)` to keep a named input. The phrase retains its
inspectable structure through `describe()`. See the
[input ownership probe](tests/perf/ownership.md).

See [syntax and migration](docs/SYNTAX.md) for the breaking changes from the
prototype and [compatibility](docs/COMPATIBILITY.md) for supported valences,
numerical policies, reference evidence, and limits. A bounded
[live comparison with J](tests/reference/RESULTS.md) records conformance and
performance for the compiled `Expr` API.

## Run locally

Install [Pixi](https://pixi.sh/), then run these commands from this checkout:

```sh
pixi install --locked
pixi run test
pixi run demo
pixi run strings-demo
pixi run package-smoke
```

On a minimal Ubuntu installation, install `gcc` and `libc6-dev` for the
syntax suite, which links a control executable. Each compiler invocation has
a 30-second timeout. On a heavily loaded host, use
`pixi run test-syntax --timeout-seconds 180` to allow more time per fixture.

The toolchain is pinned to Mojo 1.1.0. `package-smoke` precompiles
`src/mojj` into `build/mojj.mojoc` and runs the example using that compiled
package, then runs the expression tests against that package. Python is installed
in the development environment to drive bounded compiler-failure tests; the
library and numerical execution are pure Mojo. From another project, add this
repository's `src` or precompiled `build` directory to Mojo's import path with `-I`.

## Current contract

- Float64 values in contiguous `List` inputs, with runtime lengths and CPU
  evaluation.
- Scalar operations: `Identity`, `Negate`, `Square`, `Sqrt`, `Add[N]`,
  `Scale[N]`, and `Compose[Outer, Inner]`.
- Series expressions: `Input` and `Map[Operation, Source = Input]`.
- Reductions: `Sum[Source = Input]`, `Mean[Source = Input]`, and
  `After[Operation, Reduction]`.
- `evaluate[Reduction](data)` returns a scalar;
  `materialize[Series](data)` returns a new list.
- Empty maps produce an empty list; empty sums return zero; empty means raise
  `mean requires nonempty input`.
- Descriptions retain the authored tree. They do not reflect arbitrary Mojo
  function bodies or represent a runtime-editable graph.

Use `StridedView(data, start, count, stride)` to borrow selected elements of a
Float64 list. For example, `jj.StridedView(data, 4, 3, -2)` selects indices
4, 2 and 0. Index the view directly or call `view.materialize[jj.Square]()`
for an owned list of squared elements. A zero stride repeats one element.
A view observes edits and growth of its owner. Reading a selected position
after the list shrinks past it raises an error.

Use `Sum[]` or `Mean[]` to bind their default `Input` source, for example
`jj.evaluate[jj.Sum[]](data)`.

To compute two reductions from the same transformed input, pass a list or a
view to `SharedReduce`. For example, this computes the sum and mean square of
every other sample after adding one to each selected value.

```mojo
comptime Pair = jj.SharedReduce[jj.SumFold[], jj.MeanFold[jj.Square], jj.Add[1]]
var samples: List[Float64] = [2., 10., 4.]
var selected = jj.StridedView(samples, 0, 2, 2)
var pair = Pair.evaluate(selected)
print(pair[0], pair[1])  # 8.0, 17.0
```

`SharedReduce` applies the shared transform once per input, then updates the
left and right folds in order. Each evaluation starts with fresh state.
Implement `StreamingFold` to supply a custom accumulator. Errors propagate
from the first failing update or finish. J expression forks continue to use
their ordinary branch evaluation rules.

To compute a mean and population variance over the same source, use
`jj.PopulationMoments[Source].evaluate(data)`. For example:

```mojo
comptime Stats = jj.PopulationMoments[jj.Map[jj.Square]]
var data: List[Float64] = [-1.0, 1.0, -3.0, 3.0]
var result = Stats.evaluate(data)
print(result.mean, result.variance)  # 5.0, 16.0
```

`PopulationMoments[]` reads the input directly. It uses Welford's online
recurrence with a compensated mean update and divides by the population size. A finite singleton has zero
variance. Empty input, nonfinite mapped values, and overflow of the running
accumulators raise. Its online mean can round differently from `Mean[]`.
`Stats.describe()` retains the mapped expression.

Built-in operations are pure. Extension traits are `ScalarOp`, `SeriesExpr`,
and `ReductionExpr`; custom implementations must preserve the documented
input length and lazy evaluation contract. `SeriesExpr.read` is an internal
traversal interface whose index must already be valid.

## Scope and numerical behavior

The legacy typed reductions below accumulate left to right with ordinary Float64 arithmetic. There
is no compensated summation, overflow protection, algebraic rewrite engine,
or general automatic fusion pass. The tasks disable floating-point contraction;
this is not a guarantee of bitwise portability. No speedup or compiler-level
allocation claim is made without measurements.

The J verb API supports hooks, forks, shaped numeric arrays, rank agreement,
and windows. Shaped results own their storage. See the
[compatibility ledger](docs/COMPATIBILITY.md) for supported domains and limits.

The full test suite, demo, and compiled-package smoke tests passed on macOS
arm64 and Ubuntu 24.04 x86-64 under Docker Desktop emulation on Apple M4.
The [performance report](tests/perf/README.md#shared-mean-and-population-variance)
uses macOS arm64 timings.

## License

[MIT](LICENSE).
