import Testing
@testable import KartoffelchipsCore

// level1 fixture: emitter (5,3) facing down, receiver (10,8) rotation 3 (needs beam from left→right), 1 mirror
private let level1 = """
{"name": "Spiegel", "hint": "hint", "author": "test"}
################
################
####        ####
####        ####
####        ####
####        ####
####        ####
####        ####
####        ####
####        ####
################
################
L 5 3 2 0
X 10 8 3 #ff0000
M 1
"""

@Suite("GameEngine")
struct GameEngineTests {

    // Place the mirror at (5,8) rotation 0 so the downward beam deflects right
    private func makeLevel1Engine() throws -> GameEngine {
        let parsed = try LevelParser.parse(level1)
        let engine = GameEngine(level: parsed)

        // Place the single mirror at (5,8) rotation 0
        let mirror = try #require(parsed.tools.first(where: { $0 is Mirror }) as? Mirror)
        mirror.x = 5; mirror.y = 8; mirror.rotation = 0; mirror.isPlaced = true
        engine.map[5][8].block = mirror

        return engine
    }

    @Test("disableAllElements resets receiver input")
    func disableResets() throws {
        let engine = try makeLevel1Engine()
        // Manually set receiver on, then disable
        let receiver = engine.predefinedBlocks.first { $0 is Receiver } as! Receiver
        receiver.input.isOn = true
        receiver.input.color = .red
        receiver.isOn = true

        engine.disableAllElements()

        #expect(receiver.input.isOn == false)
        #expect(receiver.input.color == nil)
        #expect(receiver.isOn == false)
    }

    @Test("emitter stays on after disableAllElements")
    func emitterStaysOn() throws {
        let engine = try makeLevel1Engine()
        engine.disableAllElements()
        let emitter = engine.predefinedBlocks.first { $0 is Emitter } as! Emitter
        #expect(emitter.isOn == true)
        #expect(emitter.output.isOn == true)
        #expect(emitter.output.color == .red)
    }

    @Test("laser segments generated for clear cells")
    func laserSegmentsExist() throws {
        let engine = try makeLevel1Engine()
        engine.disableAllElements()
        let segments = engine.traceLasers()
        #expect(!segments.isEmpty)
    }

    @Test("mirror deflects beam correctly — receiver gets hit")
    func mirrorDeflectsToReceiver() throws {
        let engine = try makeLevel1Engine()
        engine.disableAllElements()
        _ = engine.traceLasers()
        engine.laterUpdate()

        let receiver = engine.predefinedBlocks.first { $0 is Receiver } as! Receiver
        #expect(receiver.isOn == true)
    }

    @Test("win detected when all receivers on")
    func winCondition() throws {
        let engine = try makeLevel1Engine()
        engine.disableAllElements()
        _ = engine.traceLasers()
        engine.laterUpdate()
        #expect(engine.checkWin(toolSelected: false) == true)
    }

    @Test("no win while tool is selected")
    func noWinWhileToolSelected() throws {
        let engine = try makeLevel1Engine()
        engine.disableAllElements()
        _ = engine.traceLasers()
        engine.laterUpdate()
        #expect(engine.checkWin(toolSelected: true) == false)
    }

    @Test("color mixing — red+green laser through prism produces yellow")
    func prismMixing() throws {
        // Build a minimal level: two emitters, one prism, one receiver expecting yellow
        // red emitter at (5,5) rotation 1 (right) → enters prism at (7,5) from left → entryFace 3
        // green emitter at (9,5) rotation 3 (left) → enters prism at (7,5) from right → entryFace 1
        // prism at (7,5) rotation 0 → output fires up → yellow receiver at (7,3) rotation 2

        let map: [[Cell]] = (0..<16).map { _ in (0..<12).map { _ in Cell() } }

        let redEmitter = Emitter()
        redEmitter.x = 5; redEmitter.y = 5; redEmitter.rotation = 1; redEmitter.color = .red
        redEmitter.output.isOn = true; redEmitter.output.color = .red; redEmitter.isPlaced = true
        map[5][5].block = redEmitter

        let greenEmitter = Emitter()
        greenEmitter.x = 9; greenEmitter.y = 5; greenEmitter.rotation = 3; greenEmitter.color = .green
        greenEmitter.output.isOn = true; greenEmitter.output.color = .green; greenEmitter.isPlaced = true
        map[9][5].block = greenEmitter

        let prism = Prism()
        prism.x = 7; prism.y = 5; prism.rotation = 0; prism.isPlaced = true
        map[7][5].block = prism

        let yellow = LaserColor.mix(.red, .green)
        let receiver = Receiver()
        receiver.x = 7; receiver.y = 3; receiver.rotation = 2; receiver.color = yellow
        receiver.isPlaced = true
        map[7][3].block = receiver

        // All cells clear
        for x in 0..<16 { for y in 0..<12 { map[x][y].tile = .clear } }

        let parsed = ParsedLevel(
            metadata: LevelMetadata(name: "test", hint: "", author: ""),
            map: map,
            predefinedBlocks: [redEmitter, greenEmitter, receiver],
            tools: [prism]
        )
        let engine = GameEngine(level: parsed)

        engine.disableAllElements()
        _ = engine.traceLasers()
        engine.laterUpdate()

        #expect(receiver.isOn == true)
    }
}
