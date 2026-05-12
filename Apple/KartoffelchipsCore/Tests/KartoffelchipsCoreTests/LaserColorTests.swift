import Testing
@testable import KartoffelchipsCore

@Suite("LaserColor")
struct LaserColorTests {

    @Test("hex parsing roundtrip")
    func hexRoundtrip() {
        let c = LaserColor(hex: "#ff0000")!
        #expect(c.r == 255 && c.g == 0 && c.b == 0)
        #expect(c.hexString == "#ff0000")
    }

    @Test("hex parsing without hash")
    func hexNoHash() {
        let c = LaserColor(hex: "00ff00")!
        #expect(c == .green)
    }

    @Test("invalid hex returns nil")
    func invalidHex() {
        #expect(LaserColor(hex: "nope") == nil)
        #expect(LaserColor(hex: "#gg0000") == nil)
    }

    @Test("red + green = yellow")
    func mixRedGreen() {
        let yellow = LaserColor.mix(.red, .green)
        #expect(yellow.r == 255)
        #expect(yellow.g == 255)
        #expect(yellow.b == 0)
    }

    @Test("red + blue = magenta")
    func mixRedBlue() {
        let magenta = LaserColor.mix(.red, .blue)
        #expect(magenta.r == 255)
        #expect(magenta.g == 0)
        #expect(magenta.b == 255)
    }

    @Test("green + blue = cyan")
    func mixGreenBlue() {
        let cyan = LaserColor.mix(.green, .blue)
        #expect(cyan.r == 0)
        #expect(cyan.g == 255)
        #expect(cyan.b == 255)
    }

    @Test("mix is commutative")
    func mixCommutative() {
        #expect(LaserColor.mix(.red, .green) == LaserColor.mix(.green, .red))
        #expect(LaserColor.mix(.red, .blue)  == LaserColor.mix(.blue,  .red))
    }
}
