/// Triggered when hit by any laser. Also a win-condition (must be on to win).
public final class Activator: GameBlock, @unchecked Sendable {
    public var x: Int = 0
    public var y: Int = 0
    public var rotation: Int = 0
    public var isOn: Bool = false
    public var isPlaced: Bool = false
    public var isPredefined: Bool { true }
    public var typeName: String { "Activator" }

    public var hitColor: LaserColor? = nil

    public init() {}

    public func reset() {
        isOn = false
        hitColor = nil
    }
}
