/// Reflects a laser 90°. Has 4 interfaces (top=0, right=1, bottom=2, left=3).
///
/// Which interface the beam exits through depends on rotation parity:
/// - Even rotation (0,2): even-index → next, odd-index → prev
/// - Odd rotation  (1,3): even-index → prev, odd-index → next
public final class Mirror: GameBlock, @unchecked Sendable {
    public var x: Int = 0
    public var y: Int = 0
    public var rotation: Int = 0
    public var isOn: Bool = false
    public var isPlaced: Bool = false
    public var typeName: String { "Mirror" }

    public var interfaces: [Interface] = [
        Interface(offset: 0, startX: 0.5, startY: 0.5, endX: 0.5, endY: 0.0),
        Interface(offset: 1, startX: 0.5, startY: 0.5, endX: 1.0, endY: 0.5),
        Interface(offset: 2, startX: 0.5, startY: 0.5, endX: 0.5, endY: 1.0),
        Interface(offset: 3, startX: 0.5, startY: 0.5, endX: 0.0, endY: 0.5),
    ]

    public init() {}

    /// Returns the exit interface index for a beam entering at `index`.
    public func linkedInterface(_ index: Int) -> Int {
        if rotation % 2 == 0 {
            return index % 2 == 0 ? (index + 1) % 4 : (index + 3) % 4
        } else {
            return index % 2 == 0 ? (index + 3) % 4 : (index + 1) % 4
        }
    }

    public func reset() {
        isOn = false
        interfaces.forEach { $0.reset() }
    }
}
