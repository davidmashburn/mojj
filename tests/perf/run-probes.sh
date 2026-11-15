#!/bin/sh
# Build and run the matched-control probes with a reproducible header.
set -eu
mkdir -p build/perf
echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "host: $(uname -sm)"
echo "cpu: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
echo "load: $(uptime | sed 's/.*load averages*: //')"
echo "revision: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "modified paths: $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
echo "mojo: $(mojo --version | head -1)"
echo "flags: --fp-mode contract=off"
mojo build --fp-mode contract=off -I src tests/perf/probes.mojo -o build/perf/probes
./build/perf/probes
