# Pixel Observatory: Project Status

**Status date:** 2026-07-22

## Project Overview

Pixel Observatory is a Godot 4.7 pixel-realistic astronomy learning game.
The player joins an astronomy club, learns from Maya, assembles optical
equipment, navigates the sky, observes celestial targets, and records the
results in a Club Logbook.

The project is intentionally different from a static astronomy tool. It has
story, equipment compatibility, assembly decisions, optical feedback,
environmental conditions, observation quality, rewards, progression, and
optional free observation. Astronomy concepts are taught immediately before
the player must use them.

## Current Gameplay Loop

1. Read the current mission and follow the highlighted base objective.
2. Complete the relevant story or Concept Brief on first use.
3. Select a compatible telescope family and equipment configuration.
4. Assemble the required parts, including nested optical-tube components when
   the family requires them.
5. Enter the sky view and use the appropriate observation mode.
6. Aim using azimuth, altitude, DMS guidance, and the active reticle.
7. Adjust focus, magnification, tracking, alignment, and environmental
   technique.
8. Identify the mission object or inspect a non-mission object in free mode.
9. Review the result, reward, concept, and process record in the Club Logbook.

## Systems Already Present

### Story and Teaching

Maya introduces the club, the observatory, observation practice, optical
principles, equipment changes, and the reason a player must perform each
operation. `StoryManager` and `TeachingFlowManager` keep story events,
Concept Briefs, and completed learning records separate so first-use lessons
do not repeat unnecessarily.

### Observatory Base

The room provides the Mission Board, Parts Cabinet, Assembly Table,
Observation Pad, Learning Journal, Observatory Door, and Stats Terminal.
Interactions are proximity-based and use the same player position for keyboard
and touch input. Route highlighting is used to make the next objective visible.

### Assembly

The assembly flow supports compatible part families, recommended parts,
equipment status, assembly hints, nested optical-tube assembly, snap slots,
installed-part artwork, and configuration-dependent telescope statistics.
The parts cabinet has family filters and mobile touch scrolling. The latest
touch update distinguishes a tap from a vertical drag to avoid accidental
equipment changes.

### Observation

The sky view contains naked-eye, finder-scope, and telescope modes. It supports
target selection, azimuth and altitude guidance, real-coordinate data where
available, focus control, magnification trade-offs, seeing, clouds, drift,
tracking rate, dark adaptation, light pollution, and target identification.

Mission targets use the mission flow. Other visible objects can be selected as
free observations without completing or changing the current mission. Free
observation details can be reviewed in a scrollable panel and recorded
separately.

### Mobile Input

Mobile Controller Mode provides a virtual joystick, interaction controls,
scope switching, focus controls, calibration controls, and touch observation
input. The parts cabinet also supports touch swipe scrolling while preserving
mouse-wheel support on desktop.

## Content Structure

The repository contains a data-driven campaign and multiple data packages.
`data/campaign_order.json` is the source for the active sequence. The level
data is split across the base, advanced, and expansion files, so the numeric
ID alone should not be used to infer the current playable order.

The educational arc begins with naked-eye observation, introduces refractor
assembly and focus, develops aiming and observing technique, then expands into
reflector and advanced observation systems. The advanced content still needs
continued content review so later telescope families feel distinct and do not
repeat the same target, concept, or interaction too many times.

## Latest Verified Change

The latest Agent update made two focused changes:

- Replaced the `naked_eye_limits` concept diagram with a larger light-gathering
  diagram and enlarged the Concept Brief image area without stretching it.
- Added touch swipe scrolling to the Parts Cabinet, with tap-versus-drag
  separation and protection against accidental Equip clicks.

The new diagram exists at:

`assets/learning_diagrams/naked_eye_limits_light_gathering.png`

The focused tests are:

- `tools/learning_card_diagram_test.gd`
- `tools/parts_cabinet_touch_test.gd`
- `tools/capture_r31_verification.gd`

## Known Limitations

- The local shell used for this snapshot does not have a Godot CLI available;
  a fresh local runtime test must be run in Godot or confirmed by CI.
- The Concept Brief header and subtitle still contain hard-coded English and
  should be routed through the language helper in a later polish pass.
- The previous diagram remains as an unused asset and should be archived or
  removed only after a deliberate asset cleanup review.
- Advanced telescope families and their artwork still need consistency review.
- Mobile behavior must still be checked on real Android hardware across
  different aspect ratios, safe areas, and touch sizes.
- The public web build must be regenerated and deployed after source changes;
  GitHub source updates alone do not change the live game.

## Release and Website Status

The public website is:

<https://pixelobservatorygame.com/>

It currently serves a Godot Web player and returned HTTP 200 during the latest
check. The repository workflow exports the Web build and deploys GitHub Pages.
Cloudflare configuration is also present for the custom-domain delivery layer.
See `docs/WEBSITE.md` for the exact publishing path and release checklist.

## Next Priorities

1. Run the latest update on a real Godot runtime and test the Concept Brief and
   touch cabinet on desktop and Android.
2. Finish the advanced-family asset audit and replace remaining placeholders.
3. Review the active campaign for repeated targets, repeated concept cards,
   missing first-use guidance, and equipment gates that do not match the
   player's unlock state.
4. Improve the world-location transition, horizon layers, and target visibility
   feedback as one coherent observation flow.
5. Re-export the Web build and verify the live domain after CI deployment.
