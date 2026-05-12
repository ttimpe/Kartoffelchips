/// Portal entry point. Accepts a laser and passes its color to the linked PortalOutput.
///
/// Hit condition: entryFace == portalInput.rotation (offset 0).
public final class PortalInput: GameBlock, @unchecked Sendable {
    public var x: Int = 0
    public var y: Int = 0
    public var rotation: Int = 0
    public var isOn: Bool = false
    public var isPlaced: Bool = false
    public var typeName: String { "PortalInput" }

    public var color: LaserColor = .red
    public var input: Interface = Interface(offset: 0)

    public init() {}

    public func reset() {
        isOn = false
        input.reset()
    }
}
