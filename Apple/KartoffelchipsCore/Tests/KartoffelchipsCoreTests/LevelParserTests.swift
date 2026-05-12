import Testing
@testable import KartoffelchipsCore

// level1.txt embedded verbatim
private let level1 = """
{"name": "Spiegel", "hint": "Um ein Level abzuschließen, müssen alle Empfänger (die Quadrate mit dem X) mit der richtigen Farbe beschossen werden. Welche Farbe passt, erkennst du an der Kreuz- und Streifenfarbe, wobei der Streifen auch zeigt, aus welcher Richtung Laserstrahlen kommen müssen. Im Inventar (oben rechts) hast du einen Spiegel, welcher Laserstrahlen in andere Richtungen leiten kann. Durch einen Linksklick kannst du ihn platzieren.", "author": "Timon Ringwald"}
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

@Suite("LevelParser")
struct LevelParserTests {

    @Test("parses level1 metadata")
    func metadata() throws {
        let level = try LevelParser.parse(level1)
        #expect(level.metadata.name   == "Spiegel")
        #expect(level.metadata.author == "Timon Ringwald")
    }

    @Test("parses emitter correctly")
    func emitter() throws {
        let level = try LevelParser.parse(level1)
        let emitter = try #require(level.predefinedBlocks.first(where: { $0 is Emitter }) as? Emitter)
        #expect(emitter.x == 5)
        #expect(emitter.y == 3)
        #expect(emitter.rotation == 2)
        #expect(emitter.color == .red)
    }

    @Test("parses receiver correctly")
    func receiver() throws {
        let level = try LevelParser.parse(level1)
        let receiver = try #require(level.predefinedBlocks.first(where: { $0 is Receiver }) as? Receiver)
        #expect(receiver.x == 10)
        #expect(receiver.y == 8)
        #expect(receiver.rotation == 3)
        #expect(receiver.color == .red)
    }

    @Test("adds one mirror to tools")
    func mirror() throws {
        let level = try LevelParser.parse(level1)
        let mirrors = level.tools.filter { $0 is Mirror }
        #expect(mirrors.count == 1)
    }

    @Test("border tiles classified correctly")
    func tileBorders() throws {
        let level = try LevelParser.parse(level1)
        #expect(level.map[0][0].tile  == .cornerLeftTop)
        #expect(level.map[15][0].tile == .cornerRightTop)
        #expect(level.map[0][11].tile == .cornerLeftBottom)
        #expect(level.map[15][11].tile == .cornerRightBottom)
        #expect(level.map[1][0].tile  == .borderTop)
        #expect(level.map[0][1].tile  == .borderLeft)
    }

    @Test("interior clear cells")
    func clearCells() throws {
        let level = try LevelParser.parse(level1)
        // Columns 4–11, rows 2–9 are clear in level1
        #expect(level.map[5][5].tile == .clear)
        #expect(level.map[10][5].tile == .clear)
    }

    @Test("emitter placed in map")
    func emitterInMap() throws {
        let level = try LevelParser.parse(level1)
        #expect(level.map[5][3].block is Emitter)
    }
}
