/// Win-condition block. Must receive a laser matching its color on the correct face.
///
/// Input offset 0 means: hit when entryFace == receiver.rotation.
public final class Receiver: GameBlock, @unchecked Sendable {
    public var x: Int = 0
    public var y: Int = 0
    public var rotation: Int = 0
    public var isOn: Bool = false
    public var isPlaced: Bool = false
    public var isPredefined: Bool { true }
    public var typeName: String { "Receiver" }

    public var color: LaserColor = .red
    public var input: Interface = Interface(offset: 0)

    public init() {}

    public func reset() {
        input.reset()
        isOn = false
    }
}
