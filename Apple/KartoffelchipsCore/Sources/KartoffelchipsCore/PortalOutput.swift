/// Portal exit point. When its linked PortalInput is hit, emits a new laser beam.
///
/// `linkedInterface` points directly at the matching PortalInput's `input` Interface —
/// set after level parse by color-matching (same pattern as JS portal linking).
public final class PortalOutput: GameBlock, @unchecked Sendable {
    public var x: Int = 0
    public var y: Int = 0
    public var rotation: Int = 0
    public var isOn: Bool = false
    public var isPlaced: Bool = false
    public var typeName: String { "PortalOutput" }

    public var color: LaserColor = .red
    public weak var linkedInterface: Interface? = nil

    public init() {}

    public func reset() {
        isOn = false
        // linkedInterface is structural, set once at level load — do not reset
    }
}
