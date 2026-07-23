# Pixel Observatory

Pixel Observatory is a pixel-realistic astronomy education game built with
Godot 4.7. It turns telescope operation into a playable learning loop:

1. Learn an optical idea through a short visual lesson.
2. Choose compatible equipment and assemble a telescope.
3. Aim with the naked eye, finder scope, and telescope view.
4. Adjust focus, magnification, alignment, tracking, and observing conditions.
5. Identify the object, record the result, and unlock the next lesson.

The project is designed as a game rather than a static sky map or a digital
worksheet. Story, equipment choices, environmental effects, observation
quality, rewards, and the Club Logbook are connected in one progression.

## Current Status

The repository contains the active Godot project, the web export workflow, and
the current educational content. The main systems include:

- Maya-led story and first-use teaching flow.
- Naked-eye, finder-scope, and telescope observation modes.
- Telescope assembly with compatible part families and nested tube assembly.
- Focus, magnification, seeing, clouds, drift, tracking, dark adaptation,
  light pollution, and observation-quality feedback.
- Mission observations and separate free observations for non-target objects.
- Dynamic celestial coordinates, altitude/azimuth guidance, and site-aware
  visibility rules.
- Learning Cards, Mission Complete results, and the Club Logbook.
- Touch input support for mobile-style controls and touch scrolling in the
  parts cabinet.
- A current campaign order maintained by `data/campaign_order.json`.

The project is still in active development. The strongest remaining work is
content consistency: every advanced target needs a clear purpose, first-use
guidance, correct artwork, compatible equipment requirements, and a meaningful
change in play rather than another copy of an earlier observation.

## Latest Verified Update

The latest update replaces the naked-eye limits teaching diagram with a larger
light-gathering diagram and gives Concept Brief its intended visual hierarchy.
The image keeps its aspect ratio and nearest-neighbour pixel rendering.

The parts cabinet now supports mobile touch swiping. A short tap selects a
card, while a vertical drag scrolls the list without accidentally equipping a
part. Mouse-wheel scrolling remains available on desktop.

Relevant files:

- `data/learning_cards.json`
- `assets/learning_diagrams/naked_eye_limits_light_gathering.png`
- `scripts/ui/learning_card.gd`
- `scripts/ui/parts_cabinet.gd`
- `tools/learning_card_diagram_test.gd`
- `tools/parts_cabinet_touch_test.gd`

## Technology

- Godot 4.7 stable
- GDScript
- JSON-driven levels, equipment, celestial objects, dialogue, and learning
  cards
- Godot Web export for browser play
- GitHub Actions for web build and GitHub Pages deployment
- Cloudflare configuration retained for the custom-domain delivery layer

## Repository Layout

| Path | Purpose |
| --- | --- |
| `scenes/` | Godot scenes for the base, assembly, teaching, sky, and telescope views |
| `scripts/ui/` | Screen construction and interaction logic |
| `scripts/systems/` | Save, mission, story, teaching, astronomy, and observation systems |
| `data/` | Levels, campaign order, parts, objects, dialogue, and learning cards |
| `assets/` | Backgrounds, UI art, telescope parts, celestial images, and diagrams |
| `tools/` | Headless tests, capture scripts, and acceptance checks |
| `docs/` | Status, deployment, progression, and release documentation |
| `.github/workflows/` | Automated web export and deployment workflow |

## Web Version

Play the current public build at:

<https://pixelobservatorygame.com/>

The repository is:

<https://github.com/tntsg1/Pixel-Observatory>

The checked-in workflow exports the Godot Web build and deploys it through
GitHub Pages. The custom domain is fronted by Cloudflare. See
`docs/WEBSITE.md` before changing the web deployment path.

## Development Notes

The project is bilingual, with English as the primary presentation language
and Chinese available through the language setting. New UI text should use the
shared localization helpers instead of embedding mixed-language strings.

When adding a new observation target or telescope family, update the data,
story, teaching card, equipment gate, artwork, and regression coverage
together. A new level is not complete until its requested operation is
visible and understandable to a first-time player.

## Validation

The repository includes focused tests and capture tools for teaching cards,
touch cabinet scrolling, progression, assembly, observation, and story flow.
The latest Agent report states that the focused tests and the broader
regression suites passed. A local Godot CLI is not installed in the current
development shell, so a fresh local runtime run must be performed by Godot or
the CI workflow before release.

## License and Project Status

This is an active educational game project and portfolio prototype. Asset
provenance and release history are documented in `docs/`.
