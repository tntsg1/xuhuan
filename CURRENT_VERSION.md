# Current Version

## Version Identity

- Version name: `current-version-2026-07-22`
- Updated: 2026-07-22
- Engine: Godot 4.7 stable
- Branch: `agent/current-version-2026-07-18`
- Remote: `origin` (`tntsg1/Pixel-Observatory`)

## Included in This Snapshot

- The current story, teaching, mission, assembly, observation, and logbook
  systems.
- Refractor, Newtonian, Dobsonian, infrared, radio, and advanced telescope
  frameworks present in the workspace, with some advanced families still
  requiring asset and content refinement.
- Three observation modes: naked eye, finder scope, and telescope.
- Focus, magnification, alignment, collimation, seeing, clouds, drift,
  tracking, dark adaptation, and light-pollution feedback.
- Dynamic target coordinates and site-aware visibility handling.
- The active campaign order in `data/campaign_order.json`.
- Mobile Controller Mode and touch-aware interaction paths.

## Latest Update: Learning Card and Parts Cabinet

The `naked_eye_limits` card now uses:

`res://assets/learning_diagrams/naked_eye_limits_light_gathering.png`

The Concept Brief layout gives the diagram a larger 896x500 content area,
keeps its aspect ratio, and uses nearest-neighbour filtering for crisp pixel
art. The diagram is loaded after the TextureRect sizing properties are set so
Godot does not restore the source image's raw minimum size and break the
layout.

The parts cabinet now supports touch swiping. A vertical gesture scrolls the
parts list, a tap selects a card, and a short tap on Equip remains an equip
action. Dragging does not trigger an accidental selection or equip event.

## Relevant Files

- `data/learning_cards.json`
- `assets/learning_diagrams/naked_eye_limits_light_gathering.png`
- `scripts/ui/learning_card.gd`
- `scripts/ui/parts_cabinet.gd`
- `tools/learning_card_diagram_test.gd`
- `tools/parts_cabinet_touch_test.gd`
- `tools/capture_r31_verification.gd`

## Validation State

The Agent reported passing the focused learning-card and parts-cabinet tests,
plus the existing project regression suites. The repository also contains
the corresponding verification capture files under `artifacts/r31_verification/`.

This shell does not currently have the Godot executable available, so I have
not claimed a fresh local Godot runtime run. Git diff checks, asset existence,
data references, and repository configuration were inspected before this
snapshot was prepared. CI remains the authoritative web-export validation.

## Web Status

- Public site: <https://pixelobservatorygame.com/>
- Repository: <https://github.com/tntsg1/Pixel-Observatory>
- Web build workflow: `.github/workflows/deploy-web.yml`
- Deployment details: `docs/WEBSITE.md`

The site currently serves a Godot Web player. Source changes become visible
online only after a new web export and successful deployment.
