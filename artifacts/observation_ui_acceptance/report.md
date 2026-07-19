# Observation UI Asset Integration

## Source handling

- Source directory: `C:/Users/tntsg/Downloads/tw/suc`
- Untouched copies: `assets/ui/observation/suc/source/`
- Runtime assets: `assets/ui/observation/suc/processed/`
- Full filename, SHA-256, source dimensions, alpha state, crop rectangle, runtime dimensions, and use mapping: `assets/ui/observation/suc/asset_manifest.json`
- All runtime textures use nearest-neighbor filtering.

The 14 individual controls were integrated: azimuth/altitude bars, pointers and knobs; Eye/Finder/Scope icons; approach/lock rings; focus knob; tracking knob; and tracking-enabled icon. The long `ChatGPT Image 2026...png` composite is archived only because it contains baked coordinates, Chinese instructions, a fixed reticle, and fixed values.

## Scale implementation

- Top shell: `Rect2(80, 33, 630, 66)`
- Live azimuth band: `Rect2(94, 42, 602, 42)`
- Azimuth values: current aim `+/- FOV/2`, wrapped continuously through `0..360`.
- Target pointer center range: screen X `118.08..671.92`.
- Left shell: `Rect2(8, 103, 76, 560)`
- Live altitude band: `Rect2(23, 120, 44, 530)`
- Altitude values: current aim `+/- FOV/2`, clipped to `0..90`.
- Target pointer center range: screen Y `141.2..628.8`.

The supplied bars do not contain a central pointer, but they do contain fixed decorative ticks. Runtime shell derivatives remove those ticks. Major/minor tick glyphs are cropped from the supplied art and placed at live angle positions, so the texture marks and dynamic labels move together. The separate target pointers are used once per axis; no duplicate pointer is drawn.

## Cropping and resizing

All 14 individual source controls were alpha-trimmed. RGB files had their baked neutral/checkerboard backgrounds recovered to transparency. Exact crop rectangles are in the manifest.

Derived scale files:

- `azimuth_scale_shell.png`: fixed ticks removed from processed bar.
- `altitude_scale_shell.png`: fixed ticks removed from processed bar.
- `azimuth_tick_major.png`: 2x9 source-art glyph.
- `azimuth_tick_minor.png`: 1x6 source-art glyph.
- `altitude_tick_major.png`: 9x2 source-art glyph.
- `altitude_tick_minor.png`: 6x1 source-art glyph.

Runtime maximums after nearest-neighbor resizing:

- Azimuth/altitude scale bars: 760x80 and 92x680.
- Pointers: 22x128 and 19x128.
- Azimuth/altitude knobs: 160x149 and 113x160.
- Focus/tracking knobs: 192x190 and 192x192.
- Mode icons: Eye 192x111, Finder 192x174, Scope 177x192.
- Target rings: approach 256x250, lock 255x256.
- Tracking-enabled icon: 160x152.

## Modes and effects

- Eye FOV: `120 x 70` degrees; smallest/dimmest target; faint open search reticle.
- Finder FOV: `28 x 18` degrees; medium target; cyan finder ring/crosshair; installation and IJKL calibration gates retained.
- Scope FOV: `6 x 4` degrees; largest target; circular aperture clipping and detailed scope reticle.

Clouds remain clipped to `VIEW_RECT (88, 103, 630, 560)` and cannot enter the right panel. No cloud or seeing art existed in `suc`, so the existing project cloud textures and turbulence mechanics remain in use. Focus and tracking knobs rotate with their real values.

At 1280x720, `canvas_items` uses aspect `keep`; the 1024x768 pixel canvas is scaled to 960x720 and centered with 160px side bars, avoiding non-uniform distortion.

## Verification

- Godot headless editor/import: exit 0.
- Observation UI acceptance: pass.
- Sky view math/catalog: pass.
- Newtonian observation parity: pass.
- Environmental focus effects: pass.
- Identify quiz and scope layer: pass.
- Focus novice guidance: pass.
- Core task flow: pass.
- Full flow test: pass.
- Real save restored and re-read at level 37.

Screenshots:

- `1024x768/ts_naked_eye.png`
- `1024x768/ts_finder.png`
- `1024x768/ts_telescope_centered.png`
- `1280x720/sky_finder_1280x720.png`
- `../chromatic_comparison/l27_newtonian_clean_vega.png` (focus knob and telescope view)

No new observation UI asset must be generated for this integration. Optional future art would be dedicated cloud/seeing overlays; none were supplied, so no placeholder was created.
