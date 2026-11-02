"""Show a compile-time-described map pipeline and lazy RMS reduction."""

from std.collections import List

import mojj as jj


def main() raises:
    comptime Pipeline = jj.Map[jj.Compose[jj.Scale[3], jj.Add[2]]]
    comptime RMS = jj.After[jj.Sqrt, jj.Mean[jj.Map[jj.Square]]]
    comptime pipeline_description = Pipeline.describe()
    comptime rms_description = RMS.describe()

    var data: List[Float64] = [1.0, -2.0, 3.0, -4.0, 5.0, -6.0]
    var output = jj.materialize[Pipeline](data)
    var value = jj.evaluate[RMS](data)

    print("pipeline:", pipeline_description)
    print("output:", output)
    print("rms:", rms_description)
    print("value:", value)
