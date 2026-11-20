# Float64 expression input ownership

`Expr.map` and `Expr.reduce` copy a caller's list into a noun on entry.
`Expr.map_owned(data^)` and `Expr.reduce_owned(data^)` transfer its storage
into the same evaluation path. With Mojo 1.1.0, passing a named list to an
owned method without `^` fails to compile, even at its last use. A temporary
list can be passed directly, and `data.copy()` is an explicit way to keep the
original. The string tests cover borrowed input and result independence,
owned results, strict sum order, and rank and domain errors.

## Inspecting the entry copy

The following probe keeps distinct functions for the public paths. Save it
as `public_paths.mojo` outside the source tree.

```mojo
from std.collections import List
from mojj import Expr

@no_inline
def copy_map(data: List[Float64]) raises -> List[Float64]:
    return Expr["double"].map(data)

@no_inline
def owned_map(var data: List[Float64]) raises -> List[Float64]:
    return Expr["double"].map_owned(data^)

@no_inline
def copy_reduce(data: List[Float64]) raises -> Float64:
    return Expr["sum"].reduce(data)

@no_inline
def owned_reduce(var data: List[Float64]) raises -> Float64:
    return Expr["sum"].reduce_owned(data^)

def main() raises:
    var data: List[Float64] = [1.0, 2.0, 3.0]
    var other = data.copy()
    print(copy_map(data)[0], copy_reduce(data), owned_map(data^)[0], owned_reduce(other^))
```

From the repository root, emit assembly with
`pixi run mojo build --fp-mode contract=off --emit asm -I src /path/to/public_paths.mojo -o /tmp/public_paths.s`.
Inspect the four wrapper bodies and the Float64 list overload of
`Noun.__init__`.

On Darwin arm64 (Apple M4, macOS 27.2, Mojo 1.1.0 build `8189361e`),
both borrowing wrappers call the list constructor before evaluation. For
a nonempty list, the constructor allocates storage and copies the input
elements. The owned wrappers place the incoming pointer, length, and
capacity into the noun before entering the same map or reduction
implementation. Each owned path removes one input payload copy in this probe.

## Direct identity maps

`Expr["]"].map_owned` returns the transferred vector storage. The same
route applies to direct `[`, their word aliases, and grouping around one
of these verbs. Other phrases evaluate through the noun path.

[`ownership_identity.mojo`](ownership_identity.mojo) times the public
`Expr["]"].map_owned` call on prebuilt Float64 lists. The timed interval
begins after input preparation and ends after the last result is consumed.
It includes popping each input from its batch, calling the public method,
reading one position from its result, and destroying the result.

| Elements | Owned input with identity copy | Direct transfer | Median paired ratio | Pairs faster |
| ---: | ---: | ---: | ---: | ---: |
| 16 | 224.7 ns | 68.5 ns | 0.340 | 14/16 |
| 100,000 | 75,560 ns | 673.3 ns | 0.010 | 16/16 |

Times are per-call medians from a single Apple M4 host on 2026-11-20,
using the same toolchain and flags as the assembly probe. The four paired
process blocks alternate order. Each process warms up each size once and
collects four batches of 20,000 or 75 calls for the two sizes respectively.
The 100,000-element paired ratios ranged from 0.004 to 0.080 and met the
predeclared gate of a median ratio at most 0.80 and at least 75% pair wins.
The 16-element ratios ranged from 0.036 to 1.350. System load averages
were 16.33, 13.80, 12.44 at the start and 19.99, 14.60, 12.73 at the end.
The ratios apply to this owned identity workload on this host.
[Raw batch timings](ownership_identity_samples.csv).

To reproduce, extract the baseline implementation from commit `c2d75a2`
and build the same probe against both source roots.

```sh
trial=$(mktemp -d)
git archive c2d75a2 src/mojj | tar -x -C "$trial"
pixi run mojo build --fp-mode contract=off -I "$trial/src" tests/perf/ownership_identity.mojo -o "$trial/baseline"
pixi run mojo build --fp-mode contract=off -I src tests/perf/ownership_identity.mojo -o "$trial/identity"
python3 tests/perf/ownership_identity.py "$trial/baseline" "$trial/identity" "$trial/samples.csv"
```
