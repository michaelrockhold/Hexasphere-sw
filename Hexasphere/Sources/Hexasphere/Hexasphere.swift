import Foundation
import MapKit
import KDTree
import Collections

public protocol GeoData {
    var pixelsWide: Int { get }
    var pixelsHigh: Int { get }
    func isLand(at: CLLocationCoordinate2D) -> Bool
}

public typealias StatusFn = (String)->(Void)

public typealias TileSet = OrderedSet<Tile>
public typealias TileNeighborMap = [Tile.TileIndex : Set<Tile.TileIndex>]

extension Face {
    func subdivide(numDivisions: Int,
                   faceIndex: Int,
                   points: PointSource,
                   registry fr: CentreRegistry,
                   status: StatusFn) {
        
        let startBuildOfFace = Date.timeIntervalSinceReferenceDate
        status("Starting computation of face \(faceIndex+1)")
        defer {
            let endBuildOfFace = Date.timeIntervalSinceReferenceDate
            status("Face \(faceIndex+1): computation time \(endBuildOfFace - startBuildOfFace)")
        }
                    
        var bottom = [self.a]
        let left = self.a.subdivide(point: self.b, count: numDivisions, pointSource: points)
        let right = self.a.subdivide(point: self.c, count: numDivisions, pointSource: points)
        
        for i in 1...numDivisions {
            let prev = bottom
            bottom = left[i].subdivide(point: right[i], count: i, pointSource: points)
            
            // New faces are retained by the points that participate in them, so no need to
            // keep a reference to them after they're created
            for j in 0..<i {
                fr.enregister(face: Face(a: prev[j], b: bottom[j], c: bottom[j+1]))
                
                if (j > 0) {
                    fr.enregister(face: Face(a: prev[j-1], b: prev[j], c: bottom[j]))
                }
            }
        }
    }
}

@available(macOS 10.15, *)
public class Hexasphere {
    public enum HexasphereError: Error {
        case InvalidArgument
    }
    
    public let radius: Double
    public let numDivisions: Int
    public let hexSize: Double
    let status: StatusFn
    public let tiles: TileSet
    public let tileNeighbors: TileNeighborMap
            
    /// Initialises a Hexasphere
    /// - Parameters:
    ///   - radius: logical radius of the sphere
    ///   - numDivisions: level of detail
    ///   - hexSize: size of each hex where 1.0 has all hexes touching their * neighbours.
    public init(radius r: Double,
                numDivisions d: Int,
                hexSize s: Double,
                status sf: @escaping StatusFn) throws {
        
        guard d >= 1 else {
            throw HexasphereError.InvalidArgument
        }
        
        radius = r
        numDivisions = d
        hexSize = s
        status = sf
        
        status("Hexasphere building tiles array.")
        var startTime = Date.timeIntervalSinceReferenceDate
        tiles = Hexasphere.calculateTiles(radius: radius, numDivisions: numDivisions, hexSize: hexSize, status: status)
        status("Tile Computation time \(Date.timeIntervalSinceReferenceDate - startTime) for \(numDivisions) divisions yielding \(tiles.count) tiles")

        // Find each tile's immediate neighbors
        status("Calculating neighborhoods for all \(tiles.count) tiles")
        startTime = Date.timeIntervalSinceReferenceDate
        let allTiles = tiles.enumerated().map { IndexedTile(idx: $0.offset, baseTile: $0.element)}
        let allTilesTree = KDTree(values: allTiles)
        var workingMap = TileNeighborMap()
        allTiles.forEach { indexedTile in
            workingMap[indexedTile.idx] = indexedTile.findNeighborsIndices(population: allTilesTree)
        }
        tileNeighbors = workingMap
        status("Tile Neighborhood count time \(Date.timeIntervalSinceReferenceDate - startTime)")

    }

    
    private static func makePoints(numDivisions: Int, status: @escaping StatusFn) -> (Set<Point>, CentreRegistry) {
        
        let PHI = (1.0 + .sqrt(5.0)) / 2.0
        
        let pointSource = PointSource()

        // We start with the corners of the 12 original pentagons

        let initialPoints = [
            /* 0 */    ( 1.0,  PHI,  0.0),
            /* 1 */    (-1.0,  PHI,  0.0),
            /* 2 */    ( 1.0, -PHI,  0.0),
            
            /* 3 */    (-1.0, -PHI,  0.0),
            /* 4 */    ( 0.0,  1.0,  PHI),
            /* 5 */    ( 0.0, -1.0,  PHI),
            
            /* 6 */    ( 0.0,  1.0, -PHI),
            /* 7 */    ( 0.0, -1.0, -PHI),
            /* 8 */    ( PHI,  0.0,  1.0),
            
            /* 9 */    (-PHI,  0.0,  1.0),
            /* 10*/    ( PHI,  0.0,  -1.0),
            /* 11*/    (-PHI,  0.0,  -1.0)
        ].map { t in
            pointSource.newPoint(t.0, t.1, t.2)
        }
        
        
        // Now we assign those original points to some triangular faces.
        // Each of the original twelve points 'participates' in five
        // different faces
        let faces = [
            (0, 1, 4),
            (1, 9, 4),
            (4, 9, 5),
            (5, 9, 3),
            (2, 3, 7),
            
            (3, 2, 5),
            (7, 10, 2),
            (0, 8, 10),
            (0, 4, 8),
            (8, 2, 10),
            
            (8, 4, 5),
            (8, 5, 2),
            (1, 0, 6),
            (11, 1, 6),
            (3, 9, 11),
            
            (6, 10, 7),
            (3, 11, 7),
            (11, 6, 7),
            (6, 0, 10),
            (9, 1, 11)
        ].map {
            return Face(a: initialPoints[$0], b: initialPoints[$1], c: initialPoints[$2])
        }
        
        let centersRegistry = CentreRegistry()
        
        for (fidx, face) in faces.enumerated() {
            face.subdivide(numDivisions: numDivisions, faceIndex: fidx, points: pointSource, registry: centersRegistry, status: status)
        }
        
        return (pointSource.points, centersRegistry)
    }
    
    private static func calculateTiles(radius: Double, numDivisions: Int, hexSize: Double, status: @escaping StatusFn) -> TileSet {
        
        guard numDivisions > 0 else {
            return TileSet()
        }
        
        // Plot points on the surface of a sphere by starting the pointy bits of 12 pentagons (an isohedron),
        // and then iteratively subdividing the lines between those points
        let (points, centers) = makePoints(numDivisions: numDivisions, status: status)
        
        // Now we can create a Tile for each point we've plotted
        return TileSet(points.map {
            Tile(centre: $0, faceRegistry:centers, sphereRadius: radius, hexSize: hexSize)
        })
    }
    
}
