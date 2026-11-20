#!/bin/sh
# Run from the repository root with a fresh output directory.
set -eu
out=${1:?usage: sh tests/perf/simd/square/build.sh NEW_OUTPUT_DIRECTORY}
ref=30fe2210d050a795018ddcdd70f6b43d26c89b72
mkdir "$out"
git archive -o "$out/src.tar" "$ref" src
for variant in baseline width2 width4 width8; do
    dir="$out/$variant"
    mkdir "$dir"
    tar -xf "$out/src.tar" -C "$dir"
    if [ "$variant" != baseline ]; then
        python3 - "$dir/src/mojj/verbs.mojo" "${variant#width}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
width = sys.argv[2]
source = path.read_text()
double_start = source.index("        comptime width = 4\n", source.index("struct Doubled("))
double_end = source.index("\n\n    @staticmethod", double_start)
square_dispatch = "        return _monad_shape(_map_float64_vector[Squared](y.float_values), y)"
assert source.count(square_dispatch) == 1
loop = source[double_start:double_end]
assert loop.count("values + values") == loop.count("value + value") == 1
loop = loop.replace("comptime width = 4", f"comptime width = {width}")
loop = loop.replace("values + values", "values * values").replace("value + value", "value * value")
path.write_text(source.replace(square_dispatch, loop))
PY
    fi
    pixi run mojo build --fp-mode contract=off -I "$dir/src" \
        tests/perf/simd/square/trials.mojo -o "$dir/trials"
done
