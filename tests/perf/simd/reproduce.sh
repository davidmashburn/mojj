#!/bin/sh
# Run from the project root with a fresh output directory.
set -eu
out=${1:?usage: sh tests/perf/simd/reproduce.sh NEW_OUTPUT_DIRECTORY}
mkdir "$out"
for variant in baseline width2 width4 width8; do
    dir="$out/$variant"
    mkdir "$dir"
    ref=e0ed509
    if [ "$variant" = baseline ]; then ref=1e042d2; fi
    git archive -o "$dir/src.tar" "$ref" src
    tar -xf "$dir/src.tar" -C "$dir"
    if [ "$variant" = width2 ] || [ "$variant" = width8 ]; then
        python3 - "$dir/src/mojj/verbs.mojo" "${variant#width}" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
needle = "comptime width = 4"
assert source.count(needle) == 1
path.write_text(source.replace(needle, f"comptime width = {sys.argv[2]}"))
PY
    fi
    pixi run mojo build --fp-mode contract=off -I "$dir/src" \
        tests/perf/simd/trials.mojo -o "$dir/trials"
done
python3 tests/perf/simd/run.py "$out/baseline/trials" "$out/width2/trials" \
    "$out/width4/trials" "$out/width8/trials" --output-dir "$out/results"
