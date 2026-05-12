# Swift Port — Implementation Plan

Full native port of Kartoffelchips to Swift for **iOS (iPhone + iPad)**, **macOS**, and **tvOS**.

---

## Architecture Overview

```
KartoffelchipsCore/          ← Swift Package, zero UI dependencies
    Models/
    Engine/
    LevelParser/
    Audio/

KartoffelchipsApp/           ← Xcode project
    Shared/                  ← SpriteKit scenes, shared UI
    iOS/                     ← iOS-specific entry point & input
    macOS/                   ← macOS-specific entry point & input
    tvOS/                    ← tvOS-specific entry point & input
```

`KartoffelchipsCore` contains everything that can be unit-tested without a device. Platform targets import it and add rendering + input on top.

---

## Phase 1 — Xcode Project Setup

- Create a new Xcode project with three targets: `Kartoffelchips iOS`, `Kartoffelchips macOS`, `Kartoffelchips tvOS`
- Create a local Swift Package `KartoffelchipsCore` and add it as a dependency to all three targets
- Add SpriteKit to all targets
- Copy `levels/`, `textures/`, `sounds/`, `fonts/`, `lang/` into the Xcode project bundle, shared across all targets
- Set deployment targets: iOS 17+, macOS 14+, tvOS 17+

---

## Phase 2 — Core Data Models (`KartoffelchipsCore/Models/`)

Exact JS-to-Swift mapping. All types are `struct` unless they need identity (nothing does).

```swift
enum GameState: Int {
    case inMenu, isPlaying, hasWon, inOptions, inCredits, inLegend
}

enum TileType { case clear, full, borderTop, borderBottom, borderLeft,
                     borderRight, cornerLeftTop, cornerRightTop,
                     cornerLeftBottom, cornerRightBottom }

enum Rotation: Int { case up = 0, right = 1, down = 2, left = 3
    var opposite: Rotation { Rotation(rawValue: (rawValue + 2) % 4)! }
    var next: Rotation     { Rotation(rawValue: (rawValue + 1) % 4)! }
}

struct LaserColor: Equatable {   // wraps hex string "#rrggbb"
    let r, g, b: UInt8
    static func mix(_ a: LaserColor, _ b: LaserColor) -> LaserColor
    // RGB average then normalize: scale so max(r,g,b) == 255
}

struct Interface {
    var isOn: Bool = false
    var color: LaserColor? = nil
    let offset: Rotation          // direction relative to owning block
}

struct Cell {
    var tile: TileType = .clear
    var block: (any GameBlock)? = nil
}
```

Define a `GameBlock` protocol:

```swift
protocol GameBlock: AnyObject {
    var x: Int { get set }
    var y: Int { get set }
    var rotation: Rotation { get set }
    var isOn: Bool { get set }
    var isPredefined: Bool { get }
}
```

Then one class per block type: `Emitter`, `Receiver`, `Activator`, `Mirror`, `Prism`, `PortalInput`, `PortalOutput`. Use `class` (not `struct`) because `map[x][y].block` and `tools[]` both need to reference the same object instance.

**Mirror-specific — `getLinkedInterface(_ index: Int) -> Int`:**
- Even rotation: even index → `(index+1)%4`, odd index → `(index-1+4)%4`
- Odd rotation: even index → `(index-1+4)%4`, odd index → `(index+1)%4`

**PortalOutput:** holds a reference `var linkedInterface: Interface?` — set after level parse, points directly at the matching `PortalInput`'s `input` Interface (same as JS).

---

## Phase 3 — Level Parser (`KartoffelchipsCore/LevelParser/`)

Input: the raw text of a `levelN.txt` file (loaded via `Bundle.main.url(forResource:)`).

```swift
struct LevelMetadata: Decodable { let name, hint, author: String }

struct ParsedLevel {
    let metadata: LevelMetadata
    let map: [[Cell]]                    // [x][y], 16×12
    let predefinedBlocks: [any GameBlock]
    let tools: [any GameBlock]
    let portalInputsByColor: [LaserColor: PortalInput]
}
```

Parser steps:
1. Split on newlines, ignore empties
2. Decode line 0 as `LevelMetadata` via `JSONDecoder`
3. Lines 1–12: walk each character, assign `TileType` based on position (corners, edges, full, clear) — exact same position logic as JS `loadLevel()`
4. Remaining lines: `split(separator: " ")`, switch on first token (`L`, `X`, `A`, `M`, `P`, `PL-I`, `PL-O`)
5. After full parse: link portals — for each `PortalOutput`, find the `PortalInput` by color and assign `portalOutput.linkedInterface = portalInput.input`

Emitter color mapping: `0 → #ff0000`, `1 → #00ff00`, `2 → #0000ff`.

---

## Phase 4 — Game Engine (`KartoffelchipsCore/Engine/`)

```swift
final class GameEngine {
    var map: [[Cell]]
    var predefinedBlocks: [any GameBlock]
    var tools: [any GameBlock]
    // ...

    func disableAllElements()
    func traceLasers()           // replaces Drawing.drawLaserBeam()
    func laterUpdate()
    func checkWin() -> Bool
}
```

`traceLasers()` contains the same logic as `drawLaserBeam` + `drawLaserBeamInCell` + `drawLaserBeamFromPosition`, but **without any drawing** — it only mutates `isOn`/`color` on game objects. Rendering reads from those fields afterwards.

`traceBeam(from x: Int, y: Int, direction: Rotation, color: LaserColor) -> [LaserSegment]`

Returns an array of `LaserSegment { start: CGPoint, end: CGPoint, color: LaserColor }` that the renderer draws. This separates logic from rendering cleanly.

**Win condition:** all `Receiver` and `Activator` instances in `predefinedBlocks` have `isOn == true`, and no tool is currently held.

**Score:** `min(floor(10000 / elapsedSeconds), 10000)` — preserve exactly.

---

## Phase 5 — SpriteKit Rendering (`Shared/`)

### Scene structure

```
GameScene: SKScene
├── boardLayer: SKNode      ← tile sprites
├── blockLayer: SKNode      ← predefined blocks
├── laserLayer: SKNode      ← laser line segments (SKShapeNode)
├── toolLayer: SKNode       ← placed tools
├── uiLayer: SKNode         ← toolbox, action buttons, alert
└── cursorLayer: SKNode     ← cursor / ghost preview (iOS/macOS only)
```

### Sprite sheets

Each `textures/*.png` is a horizontal strip of 64px frames. Load with `SKTexture(imageNamed:)` and slice via `SKTexture(rect:in:)`:

```swift
func frame(_ index: Int, from sheet: SKTexture, frameWidth: CGFloat = 64) -> SKTexture {
    let total = sheet.size().width
    let w = frameWidth / total
    let x = CGFloat(index) * w
    return SKTexture(rect: CGRect(x: x, y: 0, width: w, height: 1), in: sheet)
}
```

Sprite index = `rotation.rawValue + (isOn ? 4 : 0)`. Activator: `isOn ? 1 : 0`.

### Laser drawing

Each frame, remove all children from `laserLayer` and add new `SKShapeNode` lines from the `LaserSegment` array returned by `GameEngine.traceLasers()`. Line width 2pt.

### Per-frame update

```swift
override func update(_ currentTime: TimeInterval) {
    engine.disableAllElements()
    let segments = engine.traceLasers()
    engine.laterUpdate()
    if engine.checkWin() { transitionToWin() }
    renderLasers(segments)
    renderBlockStates()
}
```

---

## Phase 6 — Input Handling

### iOS (touch)

| Gesture | Action |
|---|---|
| Tap empty cell (tool selected) | Place tool |
| Tap block | Rotate |
| Long-press block | Pick up (return to inventory) |
| Tap toolbox row | Select tool |
| Swipe on block | Rotate direction |
| Two-finger tap | Deselect / return tool |

No pointer lock needed. Ghost preview follows a dragging finger when placing.

### macOS (mouse + keyboard)

Match JS behaviour as closely as possible:
- Left-click: place / rotate / select from toolbox
- Shift+left-click block: pick up
- Right-click: deselect
- `R` / `Shift+R`: rotate / counter-rotate block under cursor
- `1`–`9`, `0`: select inventory slot
- Cursor hidden while over game area; restore on menu screens

### tvOS (remote / gamepad)

- D-pad / left stick: move a cursor node around the grid
- Select/A button: place tool or rotate block
- Play/Pause or Menu: back / pause
- No pointer lock, no hover state
- Toolbox navigable as a focused list on the side
- Support `GCController` for gamepad

---

## Phase 7 — UI Screens

All screens rendered in SpriteKit (consistent with game rendering). Use `SKLabelNode` with the custom `TkachenkoSketch4F` font (already in `fonts/`).

| Screen | Notes |
|---|---|
| Main menu | Horizontal layout with 5° slant — match JS exactly |
| Options | Toggles via `UserDefaults` (replaces `localStorage`) |
| Credits | Names + links; links open in `SFSafariViewController` on iOS/macOS |
| Legend | Sprite + name + description for each block type |
| Win screen | Score, total score, time; `wonPotato` sprite |
| Alert/hint | Modal overlay; supports multi-line word-wrapped text |
| Pointer lock warning | Not needed — remove this screen |

---

## Phase 8 — Audio (`KartoffelchipsCore/Audio/`)

Use `AVAudioEngine`:

```swift
final class AudioEngine {
    func play(_ sound: SoundEffect)
    func startLaserLoop()
    func stopLaserLoop()
}

enum SoundEffect { case select, laser }
```

- `select.wav` — one-shot, plays on tool selection
- `laser.ogg`/`.wav` — looping during `IS_PLAYING`; this was broken in JS, implement it properly with `AVAudioPlayerNode` + `scheduleBuffer(_:at:options:completionHandler:)` in loop mode

---

## Phase 9 — Localization

Convert `lang/en.js` and `lang/de.js` to `Localizable.strings` files (or a `Codable` JSON, which is cleaner). `Translation.swift` wraps `NSLocalizedString` with the same key names as the JS string maps.

Language selection persists via `UserDefaults`. On tvOS, follow system language rather than offering a manual picker.

---

## Phase 10 — Platform Polish

**iOS:**
- Support both portrait (iPhone) and landscape (iPad) — game area scales to fit, toolbox repositions
- `UIApplication.supportedInterfaceOrientations`: landscape-only on iPhone, all on iPad

**macOS:**
- Fixed 1024×768 window minimum; resizable with aspect-lock
- Menu bar: File → New Game, Back to Menu; standard Quit/About

**tvOS:**
- Scale game area to 1920×1080; toolbox as side panel
- Focus engine drives all navigation; no custom cursor
- Top-shelf image in asset catalog

---

## Implementation Order

1. `KartoffelchipsCore` package with models + level parser (no UI, fully testable)
2. Unit tests for level parser, laser tracing, color mixing, mirror linking, win detection
3. iOS target: SpriteKit scene + game engine integration
4. Input for iOS touch
5. macOS target: reuse same scene, add mouse/keyboard input
6. tvOS target: reuse same scene, add focus/gamepad input
7. All UI screens
8. Audio
9. Localization (EN + DE)
10. Platform polish, App Store assets

---

## Critical Algorithms — Do Not Change

These must produce identical results to the JS original:

1. **Laser tracing** — stateless, full recalc per frame from each Emitter; `disableAllElements` before every trace
2. **Color mixing** — RGB average then normalize: `factor = 255 / max(r,g,b)`; scale all channels by factor
3. **Mirror interface linking** — even/odd rotation switches the linking direction; see Phase 2 formula
4. **Portal linking** — `PortalOutput.linkedInterface` points directly at matching `PortalInput.input` after level parse
5. **Sprite index** — `rotation + (isOn ? 4 : 0)`; Activator is `isOn ? 1 : 0`
6. **Win check** — requires ALL Receivers AND Activators to be on, AND no tool currently held
7. **Score** — `min(floor(10000 / elapsedSeconds), 10000)`
