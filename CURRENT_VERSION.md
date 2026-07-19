# Current Version

- Version name: `current-version-2026-07-18`
- Snapshot date: 2026-07-18
- Godot version: 4.7 stable
- Base commit: `89b795a`
- Default branch at snapshot start: `main`
- Snapshot branch: `agent/current-version-2026-07-18`

## Included State

- Pixel Observatory progression and developer level controls through the current 45-level data set.
- Refractor, Newtonian, Dobsonian, Gregorian, multi-observation, collimation, and tube subassembly work currently present in the workspace.
- Refractor chromatic-aberration comparison and Newtonian observing progression.
- Observation UI asset integration from `C:/Users/tntsg/Downloads/tw/suc`.
- Dynamic azimuth and altitude texture scales with continuous 0/360-degree wrapping.
- Eye, Finder, and Scope mode visuals, target approach/lock feedback, focus/tracking controls, clouds, seeing, drift, and focus guidance.
- English/Chinese localization work currently present in the workspace.
- Current acceptance screenshots and regression tools under `artifacts/` and `tools/`.

## Validation Before Snapshot

- Godot headless editor/import: passed.
- Observation UI acceptance: passed.
- Sky view math/catalog: passed.
- Newtonian observation parity: passed.
- Environmental focus effects: passed.
- Identify quiz and scope layer: passed.
- Focus novice guidance: passed.
- Core task flow: passed.
- Full flow test: passed.

## Notes

- Original imported UI source art is preserved under `assets/ui/observation/suc/source/`.
- Processed runtime art and its source filename/SHA-256 mapping are stored under `assets/ui/observation/suc/`.
- Local saves, credentials, generated Godot caches, isolated test profiles, and temporary backup files are excluded from Git.
- This snapshot is the baseline immediately before the interaction-feedback animation system work.
