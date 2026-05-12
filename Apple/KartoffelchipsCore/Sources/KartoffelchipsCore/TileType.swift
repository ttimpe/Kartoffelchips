/// Tile types matching the JS Tiles enum and the level parser's position-based classification.
public enum TileType: Int, Sendable {
    case clear            = 0
    case borderTop        = 1
    case borderBottom     = 2
    case borderLeft       = 3
    case borderRight      = 4
    case cornerLeftTop    = 5
    case cornerRightTop   = 6
    case cornerLeftBottom = 7
    case cornerRightBottom = 8
    case full             = 9

    public var isPassable: Bool { self == .clear }
}
