import Foundation
import KartoffelchipsCore

// MARK: - Alert

struct AlertData {
    let title: String
    let message: String
    let subtext: String
    let rightSubtext: String
    let buttons: [AlertButton]
}

struct AlertButton {
    let title: String
    let action: () -> Void
}

// MARK: - GameController

/// Manages level lifecycle, tool inventory, and scoring.
/// The SpriteKit scene owns one instance and calls it per interaction.
final class GameController {

    static let levelSequence = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,50]

    // Current level
    private(set) var levelID: Int = 0
    private(set) var parsedLevel: ParsedLevel?
    private(set) var engine: GameEngine?

    // Tool inventory
    private(set) var toolTypes: [String] = []               // ordered by first appearance
    private(set) var toolsByType: [String: [any GameBlock]] = [:]
    private(set) var selectedTool: (any GameBlock)? = nil

    // Score
    private(set) var score: Int = 0
    private(set) var totalScore: Int = 0
    private var levelStartTime: Date? = nil
    private(set) var elapsedSeconds: Double = 0

    var toolSelected: Bool { selectedTool != nil }
    var currentLevelMeta: LevelMetadata? { parsedLevel?.metadata }

    // Called when a level finishes loading
    var onLevelLoaded: (() -> Void)?

    // MARK: - Level loading

    func loadLevel(_ id: Int) {
        guard let url = Bundle.main.url(forResource: "level\(id)", withExtension: "txt", subdirectory: "levels"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let level = try? LevelParser.parse(text)
        else {
            print("[GameController] Failed to load level \(id)")
            return
        }

        parsedLevel = level
        engine = GameEngine(level: level)
        levelID = id
        selectedTool = nil

        // Build toolsByType in declaration order
        toolTypes = []
        toolsByType = [:]
        for tool in level.tools {
            let name = tool.typeName
            if toolsByType[name] == nil {
                toolTypes.append(name)
                toolsByType[name] = []
            }
            toolsByType[name]!.append(tool)
        }

        // Park all tools in the sidebar (column 15)
        for (typeIndex, typeName) in toolTypes.enumerated() {
            for tool in toolsByType[typeName] ?? [] {
                tool.x = 15
                tool.y = typeIndex + 1
                tool.rotation = 0
                tool.isPlaced = false
            }
        }

        startTimer()
        onLevelLoaded?()
    }

    func resetLevel() {
        guard levelID > 0 else { return }
        stopTimer()
        totalScore -= score
        score = 0
        loadLevel(levelID)
    }

    func nextLevel() {
        guard let idx = Self.levelSequence.firstIndex(of: levelID),
              idx + 1 < Self.levelSequence.count
        else { return }
        loadLevel(Self.levelSequence[idx + 1])
    }

    // MARK: - Timer / Score

    func startTimer() {
        levelStartTime = Date()
        elapsedSeconds = 0
    }

    func updateTimer() {
        guard let start = levelStartTime else { return }
        elapsedSeconds = Date().timeIntervalSince(start)
    }

    func stopTimer() {
        guard let start = levelStartTime else { return }
        elapsedSeconds = Date().timeIntervalSince(start)
        levelStartTime = nil
        score = min(Int(10_000.0 / max(elapsedSeconds, 0.001)), 10_000)
        totalScore += score
    }

    var timeString: String {
        let m  = Int(elapsedSeconds) / 60
        let s  = Int(elapsedSeconds) % 60
        let ms = Int(elapsedSeconds.truncatingRemainder(dividingBy: 1) * 100)
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }

    // MARK: - Tool management

    /// Returns the first unplaced tool of the type at the given sidebar slot, or nil.
    func selectFromToolbox(slotIndex: Int) -> (any GameBlock)? {
        guard slotIndex >= 0, slotIndex < toolTypes.count else { return nil }
        let typeName = toolTypes[slotIndex]
        let tool = toolsByType[typeName]?.first { !$0.isPlaced }
        selectedTool = tool
        return tool
    }

    func deselectTool() {
        guard let tool = selectedTool else { return }
        parkInToolbox(tool)
        selectedTool = nil
    }

    /// Place the currently selected tool at (x, y). Returns true on success.
    @discardableResult
    func placeSelected(at x: Int, y: Int) -> Bool {
        guard let tool = selectedTool,
              let map = parsedLevel?.map else { return false }
        guard x >= 0, x < 15, y >= 0, y < 12 else { return false }
        guard map[x][y].tile.isPassable, map[x][y].block == nil else { return false }

        tool.x = x; tool.y = y; tool.isPlaced = true
        map[x][y].block = tool
        selectedTool = nil
        return true
    }

    /// Pick up a placed tool and make it the selected tool.
    func pickUp(_ tool: any GameBlock) {
        guard !tool.isPredefined, tool.isPlaced,
              let map = parsedLevel?.map else { return }
        map[tool.x][tool.y].block = nil
        tool.isPlaced = false
        selectedTool = tool
    }

    func rotateBlock(_ block: any GameBlock, clockwise: Bool) {
        guard !block.isPredefined else { return }
        block.rotation = clockwise
            ? (block.rotation + 1) % 4
            : (block.rotation + 3) % 4
    }

    func unplacedCount(for typeName: String) -> Int {
        toolsByType[typeName]?.filter { !$0.isPlaced }.count ?? 0
    }

    // MARK: - Helpers

    private func parkInToolbox(_ tool: any GameBlock) {
        if let typeIndex = toolTypes.firstIndex(of: tool.typeName) {
            tool.x = 15; tool.y = typeIndex + 1
        }
        tool.isPlaced = false
    }
}
