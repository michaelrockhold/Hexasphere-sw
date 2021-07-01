import Foundation
import MapKit
import Collections

public protocol GeoData {
    var pixelsWide: Int { get }
    var pixelsHigh: Int { get }
    func isLand(at: CLLocationCoordinate2D) -> Bool
}

public typealias TileSet = OrderedSet<Tile>
public typealias TileNeighborMap = [Tile.TileIndex : Set<Tile.TileIndex>]
public typealias StatusFn = (String)->(Void)

public var status: StatusFn = { msg in
    // do nothing
}

@available(macOS 10.15, *)
public class Hexasphere {
    public enum HexasphereError: Error {
        case InvalidArgument
    }
    
    public let radius: Double
    public let numDivisions: Int
    public let hexSize: Double
    public let tiles: TileSet
    public let tileNeighbors: TileNeighborMap

    /// Initialises a Hexasphere
    /// - Parameters:
    ///   - radius: logical radius of the sphere
    ///   - numDivisions: level of detail
    ///   - hexSize: size of each hex where 1.0 has all hexes touching their * neighbours.
    public init(radius r: Double,
                numDivisions d: Int,
                hexSize s: Double) throws {
        
        guard d >= 1 else {
            throw HexasphereError.InvalidArgument
        }
        let startTime = Date.timeIntervalSinceReferenceDate
        defer {
            status("Total time to calculate hexagon (\(radius), \(numDivisions), \(hexSize)): \(Date.timeIntervalSinceReferenceDate - startTime)")
        }

        radius = r
        numDivisions = d
        hexSize = s
        
        let calculator = HexasphereCalculator(radius: r, numDivisions: d, hexSize: s)
        (tiles, tileNeighbors) = calculator.run()
    }
}
