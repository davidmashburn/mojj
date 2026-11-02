# Working on Mojj

- Keep changes small and independently testable. Use Conventional Commits.
- This is a pure Mojo library. Pin the supported toolchain in `pixi.toml`.
- Public imports use `mojj`, usually aliased to `jj`.
- Preserve expression structure for both evaluation and description.
- Do not claim automatic optimization or performance wins without measurements.
- Run `pixi run test`, `pixi run demo`, and `pixi run package-smoke` for core changes.
- Keep proposed features on the separate `project-planning` branch; do not merge
  its orphan history into `main`.
- Agents implement bounded tasks; the orchestrator reviews, commits, and handles
  remote actions. Never push without the user's authorization for that push.
