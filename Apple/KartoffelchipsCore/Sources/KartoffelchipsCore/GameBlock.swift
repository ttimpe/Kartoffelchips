/// Common interface for all objects that can occupy a grid cell.
///
/// `rotation` is 0–3 (0=up, 1=right, 2=down, 3=left), matching JS sprite conventions.
/// `isPredefined` distinguishes level-fixed objects from player-placed tools.
public protocol GameBlock: AnyObject, Sendable {
    var x: Int { get set }
    var y: Int { get set }
    var rotation: Int { get set }
    var isOn: Bool { get set }
    var isPlaced: Bool { get set }
    var isPredefined: Bool { get }
    var typeName: String { get }

    /// Reset all per-frame laser state (isOn, interface colors).
    func reset()
}

public extension GameBlock {
    var isPredefined: Bool { false }
}
