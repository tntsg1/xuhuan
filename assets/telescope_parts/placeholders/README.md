# Advanced Telescope Placeholder Assets

`newtonian_reflector_tube_placeholder.png`

- Current use: L25-L27 Newtonian assembly blueprint.
- Status: temporary generated pixel-art placeholder (`is_placeholder: true` in data).
- Why temporary: it is a single assembled optical-tube visual, not a final modular sprite set for the mirror cell, primary mirror, secondary spider, focuser, and eyepiece.
- Recommended final size: 512x256 transparent PNG plus separate 128x128 component sprites.
- Art direction: dark navy metal, brass fittings, clearly visible spider vanes and side focuser; no embedded text.
- Future animation: optional 2-3 frame focus-rack movement and a subtle primary-mirror reflection shimmer.

`advanced_family_atlas_placeholder.png`

- Current use: L28-L42 advanced assembly blueprint art. It contains separate
  Dobsonian, Cassegrain, Gregorian, segmented infrared observatory, and FAST
  radio dish visuals.
- Status: temporary generated pixel-art atlas (`is_placeholder: true` for all
  associated parts in `data/advanced_telescope_parts.json`).
- Replacement plan: export transparent, independently layered PNGs for each
  tube, mount, mirror, receiver, detector, and thermal component so the bench
  can visually animate an installation rather than only reveal a completed rig.
- Recommended final source dimensions: 512x384 per family rig plus 128x128
  component cards, all at nearest-neighbor pixel scale and without text.
