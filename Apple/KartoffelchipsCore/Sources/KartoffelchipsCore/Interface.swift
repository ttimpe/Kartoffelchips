/// A laser connection point on a game block.
///
/// `offset` is added to the block's rotation (mod 4) to determine which
/// entry face activates this interface — matching the JS `(block.rotation + input.offset) % 4` check.
///
/// `start`/`end` are sub-cell coordinates (0.0–1.0) used to draw the connector line
/// from the interface point to the block center.
public final class Interface: @unchecked Sendable {
    public var isOn: Bool = false
    public var color: LaserColor? = nil

    /// Direction offset relative to owning block's rotation (0–3).
    public let offset: Int

    public let startX: Double
    public let startY: Double
    public let endX: Double
    public let endY: Double

    public init(offset: Int, startX: Double = 0.5, startY: Double = 0.5,
                endX: Double = 0.5, endY: Double = 0.5) {
        self.offset = offset
        self.startX = startX; self.startY = startY
        self.endX   = endX;   self.endY   = endY
    }

    public func reset() {
        isOn = false
        color = nil
    }
}
