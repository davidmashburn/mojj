from std.collections import List
from std.os import abort
from std.time import perf_counter_ns
from mojj import Expr

@no_inline
def direct_identity(var input: List[Float64]) raises -> List[Float64]:
    return Expr["]"].map_owned(input^)

def measure(size: Int, reps: Int, batch: Int) raises:
    var inputs = List[List[Float64]](capacity=reps)
    for i in range(reps):
        inputs.append(List[Float64](length=size, fill=Float64(i + 1)))
    var sink = 0.0
    var start = perf_counter_ns()
    for i in range(reps):
        var output = direct_identity(inputs.pop())
        sink += output[(i * 521) % size]
    var elapsed = perf_counter_ns() - start
    if sink != Float64(reps * (reps + 1) // 2):
        abort("unmatched identity sink")
    print(size, ",", reps, ",", batch, ",", elapsed)

def main() raises:
    measure(16, 20000, 0)
    measure(100000, 75, 0)
    for batch in range(1, 5):
        measure(16, 20000, batch)
        measure(100000, 75, batch)
