from std.collections import List
from std.testing import assert_equal, assert_raises
import mojj as jj


def main() raises:
    var values: List[Float64] = [1., 2., 3., 4., 5.]
    var reverse = jj.StridedView(values, 4, 3, -2)
    assert_equal(reverse.materialize(), List[Float64]([5., 3., 1.]))
    assert_equal(jj.evaluate[jj.Sum[]](reverse.materialize[jj.Square]()), 35.)
    assert_equal(len(reverse), 3)
    assert_equal(reverse[1], 3.)
    assert_equal(jj.StridedView(values, 0, 3, 2).materialize(),
                 List[Float64]([1., 3., 5.]))
    assert_equal(jj.StridedView(values, 2, 3, 0).materialize(),
                 List[Float64]([3., 3., 3.]))
    assert_equal(jj.StridedView(values, 1, 1, Int.MIN)[0], 2.)
    assert_equal(len(jj.StridedView(values, 5, 0, Int.MAX)), 0)
    with assert_raises(contains="view index out of range"):
        _ = reverse[-1]
    with assert_raises(contains="view index out of range"):
        _ = reverse[3]
    with assert_raises(contains="invalid view bounds"):
        _ = jj.StridedView(values, 5, 1)
    with assert_raises(contains="invalid view bounds"):
        _ = jj.StridedView(values, 0, -1)
    with assert_raises(contains="invalid view bounds"):
        _ = jj.StridedView(values, -1, 0)
    with assert_raises(contains="invalid view bounds"):
        _ = jj.StridedView(values, 6, 0)
    with assert_raises(contains="invalid view bounds"):
        _ = jj.StridedView(values, 4, 2, Int.MIN)
    with assert_raises(contains="invalid view bounds"):
        _ = jj.StridedView(values, 0, Int.MAX, Int.MAX)

    var live: List[Float64] = [7.]
    var first = jj.StridedView(live, 0, 1)
    for i in range(64):
        live.append(Float64(i))
    live[0] = 9.
    assert_equal(first[0], 9.)
    live.clear()
    with assert_raises(contains="view source has shrunk"):
        _ = first[0]
