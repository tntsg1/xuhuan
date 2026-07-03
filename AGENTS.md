You are building a 2D pixel-art astronomy education game called **Pixel Observatory (像素观测站)** in Godot 4.7. The project is at `E:\godot\ai-game-0628`. Your job is to continue development from ~80% MVP completion to a fully playable 8-level prototype.

---

## GAME CONCEPT

Middle/high school students learn astronomy by **physically assembling a telescope from parts** (tripod, mount, tube, objective lens, eyepiece, finder scope), then using it to observe celestial objects. Assembly quality and part choice directly affect what they see through the telescope view. The core loop:

```
Observatory Room → Mission Board (accept level)
  → Parts Workshop (assemble telescope)
  → Observatory Room → Telescope Pad (click to observe)
  → Sky Observation (find target in starfield)
  → Telescope View (observe through scope, see effects based on assembly quality)
  → Identify target → Learning Card → Journal entry → Next level
```

---

## TECH STACK & CONSTRAINTS

- **Engine**: Godot 4.7 stable, path: `C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`
- **Language**: GDScript (strict mode — warnings are errors)
- **UI**: All scenes use `Control`-based programmatic UI (ColorRect, TextureRect, Label, Button, VBoxContainer). NO Node2D scene tree for UI screens.
- **Renderer**: Forward+ d3d12, but it's 2D-only. Pixel art filter set to nearest-neighbor in project.godot.
- **Resolution**: 1024×768, no fullscreen required.
- **Language**: Bilingual EN/中文. Use `GameManager.text("English", "中文")` for all user-facing strings.

### Critical GDScript Pitfalls (Godot 4.7 strict mode):

```gdscript
# ❌ BROKEN — Dictionary.get() returns Variant, can't use :=
var path := SPRITE_MAP.get(type, "")

# ✅ FIX — explicit type
var path: String = SPRITE_MAP.get(type, "")

# ❌ BROKEN — % operator only works with int, NOT float
var y := 48.0 + (i * 93.0) % 700

# ✅ FIX — use fmod()
var y := 48.0 + fmod(i * 93.0, 700.0)

# ❌ BROKEN — class_name in autoload scripts (load order issues)
class_name MyManager

# ✅ FIX — use const preload in the consuming script
const MyManagerScript = preload("res://scripts/systems/my_manager.gd")

# ❌ BROKEN — lambda captures loop variable by reference
for i in range(3):
    btn.pressed.connect(func(): use(i))  # all use i=2

# ✅ FIX — capture a local copy
for i in range(3):
    var captured := i
    btn.pressed.connect(func(): use(captured))
```

---

## PROJECT STRUCTURE

```
E:\godot\ai-game-0628\
├── project.godot                    # Config: autoloads, input map, window 1024x768
├── scenes/
│   ├── main_menu.tscn               # → scripts/ui/main_menu.gd
│   ├── observatory_room.tscn         # → scripts/ui/observatory_room.gd
│   ├── telescope_assembly.tscn      # → scripts/ui/telescope_assembly_screen.gd
│   ├── sky_observation.tscn          # → scripts/ui/sky_observation.gd
│   ├── telescope_view.tscn           # → scripts/ui/telescope_view.gd
│   ├── learning_journal.tscn         # → scripts/ui/learning_journal.gd
│   └── learning_card.tscn            # → scripts/ui/learning_card.gd
├── scripts/
│   ├── systems/
│   │   ├── game_manager.gd           # Autoload: GameManager — central state, scene switching, data loading
│   │   ├── save_manager.gd           # Autoload: SaveManager — user://savegame.json
│   │   ├── mission_manager.gd        # Autoload: MissionManager — level progression
│   │   ├── telescope_math.gd         # class_name TelescopeMath — stats calculation
│   │   ├── assembly_manager.gd       # class_name AssemblyManager — order check, completeness
│   │   ├── observation_system.gd     # class_name ObservationSystem — observation evaluation
│   │   └── localization.gd           # class_name Localization — EN/ZH text switching
│   └── ui/
│       ├── main_menu.gd
│       ├── observatory_room.gd       # MAIN HUB — floating island with interactive zones
│       ├── telescope_assembly_screen.gd
│       ├── sky_observation.gd
│       ├── telescope_view.gd
│       ├── learning_journal.gd
│       └── learning_card.gd
├── data/
│   ├── telescope_parts.json          # 6 parts (tripod, mount, tube, objective, eyepiece, finder_scope)
│   ├── celestial_objects.json        # 8 objects (moon, polaris, sirius, mars, jupiter, betelgeuse, orion_nebula, andromeda)
│   └── levels.json                   # 6 levels (NEEDS: +2 more for orion_nebula and andromeda)
└── assets/
    ├── pixel_observatory/            # Telescope part PNGs (tripod, mount, tube, objective, eyepiece, etc.)
    ├── ui_extracted/                  # Cut-out props from reference mockup (top_hud_frame, bottom_action_bar, brass_label_plate, etc.)
    ├── sprout_lands/                  # Sprout Lands asset pack (trees, grass, fences, furniture, character)
    ├── tiny_swords/                   # Tiny Swords asset pack (trees, clouds, rocks, water tiles)
    └── reference/                     # Reference mockup images
```

### Autoloads (in project.godot):
```
GameManager="*res://scripts/systems/game_manager.gd"
SaveManager="*res://scripts/systems/save_manager.gd"
MissionManager="*res://scripts/systems/mission_manager.gd"
```

### Input Map:
- `move_up/down/left/right` = WASD + arrow keys
- `dodge` = Shift
- `skill` = Space
- `interact` = E
- `pause` = Esc
- `info` = Tab

---

## CURRENT STATE: WHAT'S ALREADY DONE

### ✅ Working Systems:
1. **GameManager** — Scene switching via `GameManager.go("observatory")`, progress tracking, parts data loading, telescope readiness check, stats calculation, mission completion
2. **SaveManager** — JSON save/load to `user://savegame.json`
3. **MissionManager** — Level data loading, progression tracking
4. **TelescopeMath** — Magnification, Light Score, Stability, Clarity, Field of View, Assembly Score calculations (matches spec formulas)
5. **AssemblyManager** — Install order validation (tripod→mount→tube→objective→eyepiece), completeness check, alignment scoring
6. **ObservationSystem** — Evaluates telescope stats vs celestial object requirements, returns quality (Excellent/Good/Fair/Poor/Failed), visual effects (clear/dim/blurry/shaky), feedback text
7. **Localization** — `text(en, zh, mode)` and `from_dict(data, base, mode)` for bilingual UI

### ✅ Working Scenes:
1. **Main Menu** — Stars background, New Game/Continue/Quit, language toggle (EN/EN+中文)
2. **Observatory Room** (v4) — Floating island with teal water, clouds, fences, cliff, path, trees. 6 interactive zones with name plates (📋 Mission Board, 🔧 Parts Workshop, 🔭 Telescope Pad, 📖 Journal, 💻 Status). Player (white pixel character, WASD movement, E to interact). Blue ribbon top UI bar (credits, telescope status, level title). Bottom bar (focus prompt + feedback).
3. **Telescope Assembly** — Left panel (parts list with icons), center workbench (telescope outline + glowing slot markers), right panel (stats + selected part preview + feedback). Click part → click slot (order enforced, wrong match rejected, alignment score based on wrong attempts).
4. **Sky Observation** — Starfield with celestial object buttons (✦ markers), right info panel (level title, hint, selected target, Finder Scope status), Observe button.
5. **Telescope View** — Circular scope visual (black ring, inner colored lens area), quality indicator with color-coded badge, feedback text, stats display, identify choices (4 celestial object name buttons), retry/back buttons. Visual effects: dim (dark inner), blurry (fuzzy + "..."), shaky (offset), clear (normal).
6. **Learning Card** — Object name, type, learning text, mission complete, observation quality, continue/journal buttons.
7. **Learning Journal** — Scrollable card list. Each card: color-coded left accent bar (green=Excellent, yellow=Good, orange=Fair, red=Poor/Failed), entry number, object name EN/中文, quality badge, assembly score, learning text EN+中文. Empty state message when no entries.

### ✅ Data Files:
- `telescope_parts.json` — 6 parts with spec-compliant attributes
- `celestial_objects.json` — 8 objects with required stats, hints, learning texts
- `levels.json` — 6 levels (Level 1-6, target = moon→polaris→sirius→mars→betelgeuse, with finder_scope required in level 5)

---

## WHAT NEEDS TO BE DONE

### PRIORITY 0 — Make the game actually playable end-to-end:

**P0.1 — Add missing levels 7 and 8 to levels.json:**
```json
Level 7: "Collect More Light" → target: orion_nebula, requires ~70 assembly score, teaches: dark objects need larger aperture
Level 8: "Deep Sky Challenge" → target: andromeda, requires ~75 assembly score, teaches: faint galaxies need light gathering
```
Both Orion Nebula and Andromeda data already exist in celestial_objects.json.

**P0.2 — Fix celestial object sprite display:**
The sky_observation scene shows celestial objects as button text "✦". Instead, each object should display a different symbol based on its type:
- moon → "◐", mars → "●", jupiter → "◎", orion_nebula → "░", andromeda → "◇", stars → "✦"
This is already partially implemented in telescope_view.gd's `_target_symbol()` but not in sky_observation.gd.

**P0.3 — Playtest the full 6-level flow:**
1. Start game → New Game
2. Observatory → walk to Mission Board (E) → read level goal
3. Walk to Parts Workshop (E) → enter assembly
4. Click parts on left, click matching slots on workbench
5. Finish assembly → back to observatory
6. Walk to Telescope Pad (E) → if ready, enter sky observation
7. Find target star → click Observe
8. In telescope view → Identify target
9. On success → Learning Card → Continue → back to observatory
10. Repeat for next level
Find and fix any broken transitions, missing feedback, or logic bugs.

### PRIORITY 1 — Visual consistency and polish:

**P1.1 — Update telescope_assembly_screen.gd visual style:**
The assembly screen still uses a plain dark theme. Update it to match the observatory room's richer visual style:
- Add a subtle grid/pattern background
- Use brass/gold accent lines on panels
- Add part name labels next to the workbench slots
- Show an animated "part snapping" effect when installed correctly

**P1.2 — Improve telescope view scope visual:**
Currently uses colored rectangles. Instead:
- Add a subtle starfield inside the scope circle
- Make the quality effects more dramatic (blurry = actual blur-like dithering, dim = lower brightness)
- Add scope crosshair overlays
- Show a small telescope stats summary below the scope

**P1.3 — Add direction-based player sprites:**
The player character currently only has idle/move (left-facing from spritesheet). The `assets/characters/` folder has `player_observer_4dir_clean.png` — a 4-directional spritesheet. Implement directional facing:
- Moving right → flip the sprite horizontally (set `flip_h = true`)
- Moving up/down → use different row from the 4dir spritesheet

**P1.4 — Use ui_extracted assets:**
The `assets/ui_extracted/` folder contains beautiful pre-cut props from a detailed reference mockup. These are currently UNUSED. Integrate them:
- `top_hud_frame.png` (1304×82) — Replace the current blue ribbon bar with this ornate gold-framed dark panel
- `bottom_action_bar.png` (1006×72) — Replace the current bottom bar with this gold-trimmed bar
- `brass_label_plate.png` (207×36) — Use for zone name labels instead of plain text
- `mission_board_prop.png`, `parts_cabinet_prop.png`, `assembly_table_prop.png`, `observation_pad_prop.png`, `learning_journal_prop.png`, `stats_terminal_prop.png` — Replace the current furniture/house/chest sprites with these detailed props at their native sizes

### PRIORITY 2 — Gameplay improvements:

**P2.1 — Finder Scope calibration mechanic:**
Currently `calibration_required: false` in telescope_parts.json. Level 5 requires finder scope installation. Add a simple calibration minigame:
- When finder scope is installed, prompt player to "calibrate"
- Show a small alignment UI (crosshair that needs to be centered with arrow keys)
- Calibrated finder scope → larger aim assist area in sky observation (easier to find targets)
- Uncalibrated → slightly better than nothing, but aim assist is small

**P2.2 — Parts upgrade system:**
Currently only one part per type is unlocked. Add more parts and an upgrade path:
- `objective_100mm` (aperture 100, unlock level 7) — for deep space
- `eyepiece_10mm` (high magnification, unlock level 6) — for planetary detail
- `stable_mount` (stability 70, unlock level 7) — reduces shake at high magnification
- Parts cabinet should show all unlocked parts with stats comparison

**P2.3 — Level 9: Student Astronomer Final Test:**
A free-form final level where the player must complete 3 observations (one bright object, one planet, one deep space object) with no step-by-step guidance. Tests whether they've internalized the concepts.

### PRIORITY 3 — Polish and juice:

**P3.1 — Sound effects:**
- Click/interact: soft click
- Part installed correctly: satisfying snap
- Part installed wrong: error buzz
- Telescope observation: subtle ambient hum
- Mission complete: victory chime
- Learning card appear: paper flip
All sounds should be quiet, scholarly, "late night observatory" vibes. Use Godot's AudioStreamPlayer.

**P3.2 — Screen transitions:**
Add a simple fade-to-black transition between scenes instead of instant cuts:
```gdscript
# In GameManager.go()
var tween := create_tween()
tween.tween_property(fade_rect, "color:a", 1.0, 0.3)
tween.tween_callback(_actually_change_scene.bind(scene_key))
```

**P3.3 — Badge display:**
Badges are collected but never shown anywhere besides the save data. Add a badge gallery accessible from the observatory room or learning journal.

---

## HOW TO TEST

```bash
# Compile check
cd E:\godot\ai-game-0628
"C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" --headless --quit 2>&1
# Should show NO "SCRIPT ERROR" lines

# Run a specific scene for 8 seconds
timeout 8 "C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" --headless "res://scenes/observatory_room.tscn" 2>&1
```

---

## CRITICAL RULES

1. **Never change the GameManager autoload structure.** All scenes depend on it.
2. **All UI is programmatic** — scenes are mostly empty Control nodes with scripts. Build UI in `_build()` functions.
3. **Use `GameManager.text("EN", "中文")` for all user-facing strings** — don't hardcode one language.
4. **Don't use class_name in autoload scripts.** Use `const X = preload(...)` pattern.
5. **Never use `%` with float operands.** Use `fmod()` instead.
6. **Save after every state change** — call `GameManager.save()`.
7. **The game must run locally with zero network access.**
8. **Keep learning text short** — 2-4 sentences, middle school reading level.
9. **Don't remove existing data files** — only add to them.
10. **Test compilation after every change** with the headless command above.

---

## REFERENCES

The full game design spec is at `C:\Users\tntsg\Downloads\2D Pixel Telescope Game Spec.docx`. Key sections:
- §10: Telescope Assembly Table design
- §11-14: Assembly quality + telescope performance formulas
- §15-16: Sky Observation + Telescope View design
- §18: Level design (9 levels total)
- §28: MVP checklist
- §30: Agent development order (you're at steps 16-19)
- §33: Core function signatures
- §36: Completion criteria
