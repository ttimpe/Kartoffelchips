/// Mixes two laser inputs into one output.
///
/// Input offsets: inputs[0]=1, inputs[1]=3.
/// Hit condition: entryFace == (prism.rotation + input.offset) % 4.
/// Output fires in direction prism.rotation.
public final class Prism: GameBlock, @unchecked Sendable {
    public var x: Int = 0
    public var y: Int = 0
    public var rotation: Int = 0
    public var isOn: Bool = false
    public var isPlaced: Bool = false
    public var typeName: String { "Prism" }

    public var inputs: [Interface] = [
        Interface(offset: 1),
        Interface(offset: 3),
    ]
    public var output: Interface = Interface(offset: 0)

    public init() {}

    public func reset() {
        isOn = false
        inputs.forEach { $0.reset() }
        output.reset()
    }
}
