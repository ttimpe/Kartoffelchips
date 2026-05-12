import Foundation

/// A drawable laser line segment in grid coordinates (0.0–16.0 / 0.0–12.0).
/// The renderer scales to pixel coordinates.
public struct LaserSegment: Sendable {
    public let x1, y1, x2, y2: Double
    public let color: LaserColor

    public init(x1: Double, y1: Double, x2: Double, y2: Double, color: LaserColor) {
        self.x1 = x1; self.y1 = y1; self.x2 = x2; self.y2 = y2; self.color = color
    }
}

/// Drives the game simulation. All laser state is recalculated from scratch every frame.
///
/// Per-frame call order (matches JS tick):
///   1. disableAllElements()
///   2. traceLasers()          — returns drawable segments, also mutates block states
///   3. laterUpdate()          — sets Receiver.isOn based on input state
///   4. checkWin(toolSelected:)
public final class GameEngine {

    public let gridWidth  = 16
    public let gridHeight = 12

    public private(set) var map: [[Cell]]
    public private(set) var predefinedBlocks: [any GameBlock]
    public private(set) var tools: [any GameBlock]

    private var emitters: [Emitter] = []
    private var portalOutputs: [PortalOutput] = []

    public init(level: ParsedLevel) {
        map = level.map
        predefinedBlocks = level.predefinedBlocks
        tools = level.tools
        emitters = level.predefinedBlocks.compactMap { $0 as? Emitter }
        portalOutputs = level.tools.compactMap { $0 as? PortalOutput }
    }

    // MARK: - Per-frame API

    /// Reset all per-frame laser state on every object. Must be called before traceLasers().
    public func disableAllElements() {
        for block in predefinedBlocks { block.reset() }
        for tool in tools { tool.reset() }
        // Re-apply permanent emitter state that reset() clears
        for emitter in emitters {
            emitter.isOn = true
            emitter.output.isOn = true
            emitter.output.color = emitter.color
        }
    }

    /// Trace all laser beams, mutate block/interface states, return drawable segments.
    public func traceLasers() -> [LaserSegment] {
        var segments: [LaserSegment] = []

        for emitter in emitters {
            let face = (emitter.rotation + 2) % 4
            traceBeam(fromX: emitter.x, fromY: emitter.y,
                      entryFace: face, color: emitter.color,
                      skipSource: true, segments: &segments)
        }

        // Portal outputs fire after primary beams — linkedInterface state is now set
        for po in portalOutputs where po.isPlaced {
            if let linked = po.linkedInterface, linked.isOn, let color = linked.color {
                po.isOn = true
                let face = (po.rotation + 2) % 4
                traceBeam(fromX: po.x, fromY: po.y,
                          entryFace: face, color: color,
                          skipSource: true, segments: &segments)
            }
        }

        return segments
    }

    /// Set Receiver.isOn based on whether the input face received the matching color.
    /// Called after traceLasers() each frame.
    public func laterUpdate() {
        for block in predefinedBlocks {
            if let r = block as? Receiver {
                r.isOn = r.input.isOn && r.input.color == r.color
            }
        }
    }

    /// True when all Receivers and Activators are on and no tool is held.
    public func checkWin(toolSelected: Bool) -> Bool {
        guard !toolSelected else { return false }
        return predefinedBlocks.allSatisfy { block in
            if let r = block as? Receiver  { return r.isOn }
            if let a = block as? Activator { return a.isOn }
            return true
        }
    }

    // MARK: - Laser tracing

    /// entryFace convention (matches JS `rotation` param in drawLaserBeamInCell):
    ///   0 = beam entered cell from TOP    → traveling down  (dx= 0, dy=+1)
    ///   1 = beam entered cell from RIGHT  → traveling left  (dx=-1, dy= 0)
    ///   2 = beam entered cell from BOTTOM → traveling up    (dx= 0, dy=-1)
    ///   3 = beam entered cell from LEFT   → traveling right (dx=+1, dy= 0)
    private static let travelDx = [ 0, -1,  0, +1]
    private static let travelDy = [+1,  0, -1,  0]

    private func traceBeam(fromX: Int, fromY: Int, entryFace: Int, color: LaserColor,
                           skipSource: Bool, segments: inout [LaserSegment]) {
        let dx = GameEngine.travelDx[entryFace]
        let dy = GameEngine.travelDy[entryFace]
        var x = fromX + (skipSource ? dx : 0)
        var y = fromY + (skipSource ? dy : 0)

        while x >= 0 && x < gridWidth && y >= 0 && y < gridHeight {
            guard processCell(x: x, y: y, entryFace: entryFace, color: color, segments: &segments)
            else { return }
            x += dx; y += dy
        }
    }

    /// Returns true to continue the beam, false to stop.
    /// Draws a segment and/or mutates block state depending on what occupies the cell.
    private func processCell(x: Int, y: Int, entryFace: Int, color: LaserColor,
                             segments: inout [LaserSegment]) -> Bool {
        let cell = map[x][y]

        if let block = cell.block, block.isPlaced {
            return block.isPredefined
                ? processPredefined(block: block, entryFace: entryFace, color: color)
                : processTool(block: block, x: x, y: y, entryFace: entryFace, color: color, segments: &segments)
        }

        guard cell.tile.isPassable else { return false }

        // Clear cell: draw full-width segment along the beam axis
        if entryFace == 0 || entryFace == 2 {
            segments.append(LaserSegment(x1: Double(x)+0.5, y1: Double(y),
                                         x2: Double(x)+0.5, y2: Double(y)+1, color: color))
        } else {
            segments.append(LaserSegment(x1: Double(x),   y1: Double(y)+0.5,
                                         x2: Double(x)+1, y2: Double(y)+0.5, color: color))
        }
        return true
    }

    private func processPredefined(block: any GameBlock, entryFace: Int, color: LaserColor) -> Bool {
        if let a = block as? Activator {
            a.isOn = true
            a.hitColor = color
            return false
        }
        if let r = block as? Receiver {
            // input.offset = 0 → hit when entryFace == receiver.rotation
            if entryFace == r.rotation {
                r.input.isOn = true
                r.input.color = color
            }
            return false
        }
        return false // Emitter or unknown predefined block: stop beam
    }

    private func processTool(block: any GameBlock, x: Int, y: Int, entryFace: Int, color: LaserColor,
                             segments: inout [LaserSegment]) -> Bool {
        if let mirror = block as? Mirror {
            return processMirror(mirror, x: x, y: y, entryFace: entryFace, color: color, segments: &segments)
        }
        if let prism = block as? Prism {
            return processPrism(prism, x: x, y: y, entryFace: entryFace, color: color, segments: &segments)
        }
        if let pi = block as? PortalInput {
            if entryFace == pi.rotation { // offset 0
                pi.isOn = true
                pi.input.isOn = true
                pi.input.color = color
            }
            return false
        }
        return false
    }

    private func processMirror(_ mirror: Mirror, x: Int, y: Int, entryFace: Int, color: LaserColor,
                               segments: inout [LaserSegment]) -> Bool {
        let exitFace = mirror.linkedInterface(entryFace)
        mirror.isOn = true
        mirror.interfaces[entryFace].isOn = true
        mirror.interfaces[entryFace].color = color
        mirror.interfaces[exitFace].isOn = true
        mirror.interfaces[exitFace].color = color

        // Fire deflected beam: exit face j → new entryFace = (j+2)%4
        let newEntryFace = (exitFace + 2) % 4
        traceBeam(fromX: x, fromY: y, entryFace: newEntryFace,
                  color: color, skipSource: true, segments: &segments)
        return false
    }

    private func processPrism(_ prism: Prism, x: Int, y: Int, entryFace: Int, color: LaserColor,
                              segments: inout [LaserSegment]) -> Bool {
        // inputs[0].offset=1, inputs[1].offset=3
        for input in prism.inputs {
            if entryFace == (prism.rotation + input.offset) % 4 {
                prism.isOn = true
                input.isOn = true
                input.color = color
            }
        }

        let in0 = prism.inputs[0]; let in1 = prism.inputs[1]
        if in0.isOn || in1.isOn {
            let outColor: LaserColor
            if in0.isOn && in1.isOn, let c0 = in0.color, let c1 = in1.color {
                outColor = LaserColor.mix(c0, c1)
            } else {
                outColor = (in0.color ?? in1.color)!
            }
            prism.output.isOn = true
            prism.output.color = outColor

            // Output fires in prism.rotation direction
            let outFace = (prism.rotation + 2) % 4
            traceBeam(fromX: x, fromY: y, entryFace: outFace,
                      color: outColor, skipSource: true, segments: &segments)
        }
        return false
    }
}
