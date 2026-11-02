# Mojj

Inspectable numerical composition in Mojo.

Mojj builds calculations from small, typed operations. The same expression can
describe its structure and evaluate runtime data. This is a fresh, deliberately
small J-inspired library; it is not a J interpreter or a general array package.

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

## Run locally

Install [Pixi](https://pixi.sh/), then run these commands from this checkout:

```sh
pixi install --locked
pixi run test
pixi run demo
pixi run package-smoke
```

The toolchain is pinned to Mojo 1.1.0. `package-smoke` precompiles
`src/mojj` into `build/mojj.mojoc` and runs the example using that compiled
package. From another project, add this repository's `src` or precompiled
`build` directory to Mojo's import path with `-I`.

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

Use `Sum[]` or `Mean[]` to bind their default `Input` source, for example
`jj.evaluate[jj.Sum[]](data)`.

Built-in operations are pure. Extension traits are `ScalarOp`, `SeriesExpr`,
and `ReductionExpr`; custom implementations must preserve the documented
input length and lazy evaluation contract. `SeriesExpr.read` is an internal
traversal interface whose index must already be valid.

## Scope and numerical behavior

Reductions accumulate left to right with ordinary Float64 arithmetic. There
is no compensated summation, overflow protection, algebraic rewrite engine,
or general automatic fusion pass. The tasks disable floating-point contraction;
this is not a guarantee of bitwise portability. No speedup or compiler-level
allocation claim is made without measurements.

This first slice does not yet include string parsing, readable phrases, forks,
strides, windows, rank operations, GPU execution, or Python/NumPy integration.
Those belong to the separate `project-planning` branch. Numerical tests use
finite inputs; exhaustive IEEE special-value behavior is not established.

The manifest targets macOS arm64 and Linux x86-64. Initial local validation is
on macOS arm64; a resolved Linux lockfile is not evidence of Linux execution.

## License

[MIT](LICENSE).
