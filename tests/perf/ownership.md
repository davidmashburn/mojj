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
implementation. Each owned path removes one input payload copy. This
inspection does not measure elapsed time.
