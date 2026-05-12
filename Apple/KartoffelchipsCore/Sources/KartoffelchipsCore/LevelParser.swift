import Foundation

public struct LevelMetadata: Decodable, Sendable {
    public let name: String
    public let hint: String
    public let author: String
}

public struct ParsedLevel: Sendable {
    public let metadata: LevelMetadata
    /// map[x][y], x: 0–15, y: 0–11
    public let map: [[Cell]]
    public let predefinedBlocks: [any GameBlock]
    public let tools: [any GameBlock]
}

public struct LevelParseError: Error, Sendable {
    public let message: String
}

public enum LevelParser {

    public static func parse(_ text: String) throws -> ParsedLevel {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { throw LevelParseError(message: "Empty level file") }

        // Line 0: JSON metadata
        guard let data = lines[0].data(using: .utf8),
              let metadata = try? JSONDecoder().decode(LevelMetadata.self, from: data)
        else { throw LevelParseError(message: "Invalid metadata JSON on line 0") }

        // 16×12 grid, [x][y]
        let map: [[Cell]] = (0..<16).map { _ in (0..<12).map { _ in Cell() } }

        // Lines 1–12: grid rows (y = lineIndex - 1)
        for lineIndex in 1...12 {
            guard lineIndex < lines.count else { break }
            let row = lines[lineIndex]
            for x in 0..<min(16, row.count) {
                let idx = row.index(row.startIndex, offsetBy: x)
                if row[idx] == "#" {
                    map[x][lineIndex - 1].tile = tileType(x: x, y: lineIndex - 1)
                } else {
                    map[x][lineIndex - 1].tile = .clear
                }
            }
        }

        var predefined: [any GameBlock] = []
        var tools: [any GameBlock] = []
        var portalInputsByColor: [LaserColor: PortalInput] = [:]

        // Lines after the grid: object declarations
        let startLine = min(13, lines.count)
        for i in startLine..<lines.count {
            let parts = lines[i].split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard !parts.isEmpty else { continue }

            switch parts[0] {

            case "L": // Emitter
                guard parts.count >= 5 else { continue }
                let e = Emitter()
                e.x = Int(parts[1]) ?? 0
                e.y = Int(parts[2]) ?? 0
                e.rotation = Int(parts[3]) ?? 0
                e.color = colorFromIndex(Int(parts[4]) ?? 0)
                e.output.color = e.color
                e.output.isOn = true
                e.isPlaced = true
                map[e.x][e.y].block = e
                predefined.append(e)

            case "X": // Receiver
                guard parts.count >= 5 else { continue }
                let r = Receiver()
                r.x = Int(parts[1]) ?? 0
                r.y = Int(parts[2]) ?? 0
                r.rotation = Int(parts[3]) ?? 0
                r.color = LaserColor(hex: parts[4]) ?? .red
                r.isPlaced = true
                map[r.x][r.y].block = r
                predefined.append(r)

            case "A": // Activator
                guard parts.count >= 3 else { continue }
                let a = Activator()
                a.x = Int(parts[1]) ?? 0
                a.y = Int(parts[2]) ?? 0
                a.isPlaced = true
                map[a.x][a.y].block = a
                predefined.append(a)

            case "M": // Mirror(s)
                let count = Int(parts[1]) ?? 0
                for _ in 0..<count { tools.append(Mirror()) }

            case "P": // Prism(s)
                let count = Int(parts[1]) ?? 0
                for _ in 0..<count { tools.append(Prism()) }

            case "PL-I": // Portal input
                guard parts.count >= 2 else { continue }
                let pi = PortalInput()
                pi.color = LaserColor(hex: parts[1]) ?? .red
                portalInputsByColor[pi.color] = pi
                tools.append(pi)

            case "PL-O": // Portal output(s)
                guard parts.count >= 3 else { continue }
                let count = Int(parts[1]) ?? 0
                let color = LaserColor(hex: parts[2]) ?? .red
                for _ in 0..<count {
                    let po = PortalOutput()
                    po.color = color
                    tools.append(po)
                }

            default: break
            }
        }

        // Link portals: PortalOutput.linkedInterface → matching PortalInput.input
        for tool in tools {
            if let po = tool as? PortalOutput, let pi = portalInputsByColor[po.color] {
                po.linkedInterface = pi.input
            }
        }

        return ParsedLevel(metadata: metadata, map: map, predefinedBlocks: predefined, tools: tools)
    }

    // MARK: - Helpers

    private static func tileType(x: Int, y: Int) -> TileType {
        let top = y == 0; let bottom = y == 11
        let left = x == 0; let right = x == 15
        if top    && left  { return .cornerLeftTop }
        if top    && right { return .cornerRightTop }  // JS: CORNER_RIGHT_TOP = 2
        if bottom && left  { return .cornerLeftBottom } // JS: CORNER_LEFT_BOTTOM = 1
        if bottom && right { return .cornerRightBottom }
        if top             { return .borderTop }
        if bottom          { return .borderBottom }
        if left            { return .borderLeft }
        if right           { return .borderRight }
        return .full
    }

    private static func colorFromIndex(_ index: Int) -> LaserColor {
        switch index {
        case 1:  return .green
        case 2:  return .blue
        default: return .red
        }
    }
}
