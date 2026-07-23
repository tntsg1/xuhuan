# Pixel Observatory Changelog

This is the English-first release log. The earlier detailed Chinese archive is
preserved in [`VERSION_HISTORY.md`](VERSION_HISTORY.md) and has not been
deleted.

## 2026-07-22 - Learning Card and Mobile Parts Cabinet

- Replaced the `naked_eye_limits` teaching image with a larger diagram focused
  on eye pupil size, telescope aperture, light collection, and faint objects.
- Updated `data/learning_cards.json` to reference
  `naked_eye_limits_light_gathering.png`.
- Enlarged the Concept Brief diagram area while preserving aspect ratio and
  nearest-neighbour pixel rendering.
- Fixed the TextureRect property order so a large source image cannot force its
  raw pixel dimensions back into the layout.
- Added mobile swipe scrolling to the Parts Cabinet.
- Added tap-versus-drag detection so a swipe does not equip a part or trigger a
  second screen.
- Preserved desktop mouse-wheel scrolling and normal tap/click behavior.
- Added focused tests and verification captures for both changes.

## 2026-07-20 - Observation HUD and Feedback Baseline

- Archived the active project state and documented the observation HUD,
  reticles, coordinate lock feedback, focus feedback, environmental effects,
  and assembly texture behavior.
- Continued the English-first documentation and web release workflow.

## Earlier History

The full previous log remains in [`VERSION_HISTORY.md`](VERSION_HISTORY.md),
including the dated localization, story, teaching, assembly, observation,
mobile input, campaign, and advanced telescope updates. It is retained as the
historical record rather than rewritten or removed.
