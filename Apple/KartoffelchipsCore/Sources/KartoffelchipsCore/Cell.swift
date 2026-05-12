/// One cell in the 16×12 grid.
public final class Cell: @unchecked Sendable {
    public var tile: TileType = .clear
    public weak var block: (any GameBlock)? = nil

    public init() {}
}
