/// Tile types. Raw values match the JS Tiles enum — they are used directly as
/// sprite frame indices into map.png (a 10-frame horizontal strip, 64 px per frame).
public enum TileType: Int, Sendable {
    case cornerLeftTop     = 0
    case cornerLeftBottom  = 1
    case cornerRightTop    = 2
    case cornerRightBottom = 3
    case borderLeft        = 4
    case borderRight       = 5
    case borderTop         = 6
    case borderBottom      = 7
    case clear             = 8
    case full              = 9

    public var isPassable: Bool { self == .clear }
}
