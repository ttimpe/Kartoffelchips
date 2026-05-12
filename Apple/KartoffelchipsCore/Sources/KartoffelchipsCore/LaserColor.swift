import Foundation

/// A laser beam color, stored as full-intensity RGB channels.
/// All colors are in the range 0–255.
public struct LaserColor: Equatable, Hashable, Sendable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public static let red   = LaserColor(r: 255, g: 0,   b: 0)
    public static let green = LaserColor(r: 0,   g: 255, b: 0)
    public static let blue  = LaserColor(r: 0,   g: 0,   b: 255)

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r; self.g = g; self.b = b
    }

    /// Parse a "#rrggbb" hex string.
    public init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let value = UInt32(h, radix: 16) else { return nil }
        r = UInt8((value >> 16) & 0xFF)
        g = UInt8((value >> 8)  & 0xFF)
        b = UInt8( value        & 0xFF)
    }

    public var hexString: String {
        String(format: "#%02x%02x%02x", r, g, b)
    }

    /// RGB average then normalize so max(r,g,b) == 255.
    /// Matches JS mixColors() exactly — integer division then float scale truncated.
    public static func mix(_ a: LaserColor, _ b: LaserColor) -> LaserColor {
        let rr = (Int(a.r) + Int(b.r)) / 2
        let gg = (Int(a.g) + Int(b.g)) / 2
        let bb = (Int(a.b) + Int(b.b)) / 2
        let maxCh = max(rr, gg, bb)
        guard maxCh > 0 else { return LaserColor(r: 0, g: 0, b: 0) }
        let factor = 255.0 / Double(maxCh)
        return LaserColor(
            r: UInt8(min(255, Int(Double(rr) * factor))),
            g: UInt8(min(255, Int(Double(gg) * factor))),
            b: UInt8(min(255, Int(Double(bb) * factor)))
        )
    }
}
