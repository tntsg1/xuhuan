# Current Version

## Version Identity

- Version name: `current-version-2026-07-19`
- Updated: 2026-07-19
- Godot version: 4.7 stable
- Original snapshot commit: `cb9f5c8`
- Latest included feature commit: `c254d56`
- Branch: `agent/current-version-2026-07-18`
- Remote: `origin` (`tntsg1/Pixel-Observatory`)

## Included State

- Pixel Observatory progression and developer level controls through the current 45-level data set.
- Refractor, Newtonian, Dobsonian, Gregorian/Cassegrain, radio, infrared, multi-observation, collimation, and tube-subassembly frameworks currently present in the workspace.
- Refractor chromatic-aberration comparison, Vega art, Newtonian motivation/tutorial sequence, assembly, collimation, and observation progression.
- Complete observation HUD integration from `C:/Users/tntsg/Downloads/tw/suc`, including native-alpha replacement assets.
- Dynamic azimuth and altitude scales, 0/360-degree wrapping, live pointers, Eye/Finder/Scope mode art, focus and tracking controls.
- One-to-one `410x410` naked-eye reticle with a `196 px` outer field boundary and a visible `64 px` center lock boundary.
- Target approach and lock markers that follow the projected celestial object, remain transparent at center, and use compact target-derived sizing.
- Focus, seeing, clouds, chromatic aberration, Earth-rotation drift, tracking-rate, hold-progress, and observation-quality feedback.
- Collimation is now visible optical state: the bench previews asymmetric coma versus a symmetric Airy disc, while telescope targets retain score-driven coma, offset ghosting, and detail loss even at correct focus.
- Shared interaction animations, first-use guidance, reduced-motion support, assembly snap feedback, collimation feedback, and observation success/failure feedback.
- English/Chinese localization fixes, pre-quiz celestial-object guide, randomized A-D answers, and modal layer ordering fixes.
- Current acceptance screenshots and regression tools under `artifacts/` and `tools/`.

## Asset Provenance

- Original observation UI art is preserved under `assets/ui/observation/suc/source/`.
- Processed runtime art is stored under `assets/ui/observation/suc/processed/`.
- Source filename, SHA-256, dimensions, alpha state, crop rectangle, runtime mapping, and resize method are recorded in `assets/ui/observation/suc/asset_manifest.json`.
- Download-folder originals are not modified by the importer.

## Current Target Feedback Rules

- Approach and lock rings use the same projected target center and size.
- Eye mode uses screen-space centering: the visible `64 px` center ring is also the exact gameplay lock radius.
- Ring diameter is `target diameter + max(12 px, 25%)`.
- Minimum diameters are 40 px for Eye, 44 px for Finder, and 48 px for Scope.
- Approach uses a subtle cyan alpha pulse; lock uses a high-contrast gold ring.
- The ring center remains transparent and does not obscure the celestial texture.
- The visible ring and the target's pointer/click detection rectangle are identical.

## Validation

- Godot headless editor/import: passed.
- Observation UI acceptance: passed.
- L25 reticle regression: passed.
- Newtonian reticle regression: passed.
- Newtonian observation parity: passed.
- Identification quiz and scope layer tests: passed.
- Telescope modal layer regression: passed.
- Coordinate lock feedback: passed.
- Animation feedback and reduced-motion acceptance: passed.
- Environmental focus effects: passed.
- Collimation optics feedback: passed.
- Focus novice guidance: passed.
- Assembly texture regression: passed.
- Core task, story, teaching, and full-flow regressions: passed.

## Notes

- Core level order, story conditions, observation calculations, and save schema were not changed by the HUD and feedback integration.
- Local saves, credentials, generated Godot caches, isolated test profiles, and temporary backup files remain excluded from Git.
- Detailed release history is maintained in `docs/VERSION_HISTORY.md`.
- Detailed observation HUD evidence is maintained in `artifacts/observation_ui_acceptance/report.md`.
