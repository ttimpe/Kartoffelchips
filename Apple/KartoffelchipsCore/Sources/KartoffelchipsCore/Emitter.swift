/// Fixed light source. Always on; fires a colored laser in the direction of its rotation.
public final class Emitter: GameBlock, @unchecked Sendable {
    public var x: Int = 0
    public var y: Int = 0
    public var rotation: Int = 0
    public var isOn: Bool = true
    public var isPlaced: Bool = false
    public var isPredefined: Bool { true }
    public var typeName: String { "Emitter" }

    public var color: LaserColor = .red
    public var output: Interface = Interface(offset: 0)

    public init() {}

    public func reset() {
        // Emitter always stays on; output color is set once at level load
    }
}
