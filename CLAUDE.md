# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Dev

```bash
# Install grunt and dependencies (one-time)
npm install

# Production build → dist/
grunt

# Dev: open directly in browser — no server needed
open index.html
```

There are no automated tests in this project.

The Grunt build order matters: `imagemin → uglify → cssmin → copy`. The uglify step concatenates `src/*.js` in a specific dependency order defined in `Gruntfile.js` — if you add a new file, add it to the `src` array there.

---

## Architecture

**Grid:** 16×12 cells, 64px each → 1024×768 canvas. Column 15 (rightmost) is reserved as the off-screen parking zone for unplaced tools and the sidebar UI — never place game objects there.

**State split:** `predefinedBlocks[]` = level-fixed objects (Emitters, Receivers, Activators). `tools[]` = player-placed objects (Mirrors, Prisms, Portals). Both arrays are merged into `blocks[]` after level load. `map[x][y].block` references whichever object occupies that cell.

### Game Loop (`Main.js` → `tick()`)

`requestAnimationFrame` drives everything. Per frame, for `IS_PLAYING`:
1. Draw board tiles
2. Draw predefined blocks
3. **`disableAllElements()`** — resets all `isOn`/`color` fields to blank
4. **`Drawing.drawLaserBeam()`** — traces + draws laser paths, mutates `isOn`/`color` on objects it hits as a side effect
5. Draw portal outputs, tools, toolbox
6. **`laterUpdate()`** — sets `Receiver.isOn = true` where `input.color === receiver.color`

Steps 3–6 are the laser simulation. It is **fully stateless and recalculated every frame** — there is no laser state that persists between frames.

### Laser Tracing

`Drawing.drawLaserBeamFromObject(emitter)` walks cells in the emit direction. Each cell is processed by `Drawing.drawLaserBeamInCell(color, rotation, x, y)` which returns `true` to continue or `false` to stop.

The `rotation` argument to `drawLaserBeamInCell` represents the **direction the beam is travelling** (incoming direction), not the object's facing. The convention is:

| value | direction |
|---|---|
| 0 | up (decreasing y) |
| 1 | right (increasing x) |
| 2 | down (increasing y) |
| 3 | left (decreasing x) |

Emitters use `(rotation + 2) % 4` to convert their facing to a travel direction.

### Mirror Interface Linking

Each Mirror has 4 interfaces (indices 0–3 = top, right, bottom, left). `getLinkedInterface(i)` determines which interface a beam exits through:

- **Even rotation (0, 2):** even index links to `(index+1)%4`, odd index links to `(index-1+4)%4`
- **Odd rotation (1, 3):** even index links to `(index-1+4)%4`, odd index links to `(index+1)%4`

This means rotation 0/2 reflects NW↔NE and SW↔SE; rotation 1/3 reflects differently. Test any change here against all 4 rotation states.

### Color Mixing (`mixColors` in `Main.js`)

RGB average, then **normalize so the brightest channel = 255**. This keeps mixed colors vivid rather than darkening them. The exact formula must be preserved in the Swift port.

### Portal Linking

After level parse, `PortalOutput.output` is set to point directly at the matching `PortalInput.input` (an `Interface` object), keyed by color string. When the portal input's `Interface.isOn` becomes true, the portal output reads it in `drawPortalOutputs()`. No separate portal-pair data structure exists.

### Sprite Index Formula

All sprite sheets are horizontal strips of 64px frames:
- Off state: index = `rotation` (0–3)
- On state: index = `rotation + 4`

Activator is the exception: 0 = off, 1 = on (no rotation).

### Input

Mouse requires **Pointer Lock** — the game won't draw until the pointer is locked. `Ctrl+Alt` unlocks. Mouse position is tracked via `movementX/Y` accumulation mapped to grid coords, stored in `mouseX/mouseY` (grid) and `fullMouseX/fullMouseY` (pixel).

`selectedTool` is an index into `tools[]` or `-1` for none. `selectedMenuItem` is reused across all non-playing states (menu, options, credits, alert) without being cleared on state transitions — this is a known bug.

### Level File Format

Line 1 is a JSON object `{name, hint, author}`. Lines 2–13 are the 16-char × 12-row grid (`#` = wall, space = clear). Remaining lines are object/tool declarations using single-letter codes (`L`=Emitter, `X`=Receiver, `A`=Activator, `M`=Mirror count, `P`=Prism count, `PL-I`=Portal input, `PL-O`=Portal output count+color). Emitter color is encoded as `0=red, 1=green, 2=blue`; Receiver color is a raw hex string.

---

## Known Bugs

| Location | Issue |
|---|---|
| `Main.js checkBrowserCompatibility()` | Returns `false` when canvas exists — logic is inverted, so the compatibility check never blocks |
| `Main.js` | `selectedMenuItem` reused across all screens without reset |
| `Drawing.js drawPredefinedBlocks()` line ~117 | Draws `index - offset` then `index` — first draw is always the off-state sprite, a visual no-op |
| `SoundEffects.js` | Laser loop does not work; commented out |

---

## Swift Port (`apple-native` branch)

The JavaScript source on `master` is the canonical reference implementation. When porting:

- **Preserve exactly:** laser tracing algorithm, color mixing formula, mirror interface linking, portal linking, sprite index offsets
- **Map to Swift:** `GameState` enum → `enum GameState: Int`, global vars in `Main.js` → `@Published` properties on `GameController: ObservableObject`, canvas drawing → SpriteKit `SKSpriteNode` or SwiftUI `Canvas`
- **Platform targets:** native macOS, native iOS (iPhone + iPad), native tvOS — no Mac Catalyst
- **Input target:** touch drag/tap on iOS/tvOS (remote/gamepad), `NSEvent` mouse on macOS
- **Level files:** keep same `.txt` format — `Codable` for metadata line, manual parse for grid + object lines
- **Audio:** `AVFoundation` / `AVAudioEngine`
