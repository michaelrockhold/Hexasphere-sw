import Foundation
import MapKit
import KDTree

public protocol GeoData {
    var pixelsWide: Int { get }
    var pixelsHigh: Int { get }
    func isLand(at: CLLocationCoordinate2D) -> Bool
}

protocol PointSource {
    func newPoint(_ x: Double, _ y: Double, _ z: Double) -> Point
    
    func checkPoint(_ p: Point) -> Point
}

public typealias StatusFn = (String)->(Void)

@available(macOS 10.15, *)
public class Hexasphere {
    public enum HexasphereError: Error {
        case InvalidArgument
    }
    
    public let radius: Double
    public let numDivisions: Int
    public let hexSize: Double
    let status: StatusFn
            
    /// Initialises a Hexasphere
    /// - Parameters:
    ///   - radius: logical radius of the sphere
    ///   - numDivisions: level of detail
    ///   - hexSize: size of each hex where 1.0 has all hexes touching their * neighbours.
    public init(radius r: Double,
                numDivisions d: Int,
                hexSize s: Double,
                status sf: @escaping StatusFn) throws {
        
        guard d >= 1 && d <= 144 else {
            throw HexasphereError.InvalidArgument
        }
        
        radius = r
        numDivisions = d
        hexSize = s
        status = sf
    }
    
    private class Points: PointSource {
        private var nextPointID = 0
        var points = [Point]()
        
        func newPoint(_ x: Double, _ y: Double, _ z: Double) -> Point {
            defer { nextPointID += 1 }
            return Point(nextPointID, x: x, y: y, z: z)
        }
        
        func newFaces(_ tt: [(Int, Int, Int)]) -> [Face] {
            return tt.map {
                return Face(points[$0], points[$1], points[$2], registering: false)
            }
        }
        
        func checkPoint(_ p: Point) -> Point {
            for oldPoint in points {
                if p == oldPoint {
                    return oldPoint
                }
            }
            points.append(p)
            return p
        }
        
        func addPoints(_ tt: [(Double, Double, Double)]) {
            for t in tt {
                points.append(newPoint(t.0, t.1, t.2))
            }
        }
    }

    public lazy var tiles: [Tile] = {
        
        status("Hexasphere building tiles array.")
        defer {
            
        }

        return calculateTiles(radius: radius, numDivisions: numDivisions, hexSize: hexSize, status: status)
    }()

    func makePoints(radius r: Double, numDivisions: Int, status: @escaping StatusFn) -> [Point] {
        
        let TAO = 1.61803399
        
        let pointSource = Points()

        // We start with the corners of the 12 original pentagons
        pointSource.addPoints([
            /* 0 */    (       1000.0,  TAO * 1000.0,          0.0),
            /* 1 */    (      -1000.0,  TAO * 1000.0,          0.0),
            /* 2 */    (       1000.0, -TAO * 1000.0,          0.0),
            
            /* 3 */    (      -1000.0, -TAO * 1000.0,          0.0),
            /* 4 */    (          0.0,        1000.0,  TAO * 1000.0),
            /* 5 */    (          0.0,       -1000.0,  TAO * 1000.0),
            
            /* 6 */    (          0.0,        1000.0, -TAO * 1000.0),
            /* 7 */    (          0.0,       -1000.0, -TAO * 1000.0),
            /* 8 */    ( TAO * 1000.0,           0.0,        1000.0),
            
            /* 9 */    (-TAO * 1000.0,           0.0,        1000.0),
            /* 10*/    ( TAO * 1000.0,           0.0,       -1000.0),
            /* 11*/    (-TAO * 1000.0,           0.0,       -1000.0)
        ])
        
        // Now we assign those original points to some triangular faces.
        // Each of the original points 'participates' five ways in a number
        // of different faces
        let faces = pointSource.newFaces([
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
        ])
                
        for (fidx, face) in faces.enumerated() {
            
            let startBuildOfFace = Date.timeIntervalSinceReferenceDate
            status("Starting computation of face \(fidx+1) of \(faces.count)")
            defer {
                let endBuildOfFace = Date.timeIntervalSinceReferenceDate
                status("Face \(fidx+1) of \(faces.count): computation time \(endBuildOfFace - startBuildOfFace)")
            }
                        
            var bottom = [face.pA]
            let left = face.pA.subdivide(point: face.pB, count: numDivisions, pointSource: pointSource)
            let right = face.pA.subdivide(point: face.pC, count: numDivisions, pointSource: pointSource)
            
            for i in 1...numDivisions {
                let prev = bottom
                bottom = left[i].subdivide(point: right[i], count: i, pointSource: pointSource)
                
                // New faces are retained by the points that participate in them, so no need to
                // keep a reference to them after they're created
                for j in 0..<i {
                    _ = Face(prev[j],
                             bottom[j],
                             bottom[j+1])
                    
                    if (j > 0) {
                        _ = Face(prev[j-1],
                                 prev[j],
                                 bottom[j])
                    }
                }
            }
        }
        
        return pointSource.points
    }
    
    func calculateTiles(radius: Double, numDivisions: Int, hexSize: Double, status: @escaping StatusFn) -> [Tile] {
        var tileCount = 0
        let startBuild = Date.timeIntervalSinceReferenceDate
        defer {
            let endBuild = Date.timeIntervalSinceReferenceDate
            status("Computation time \(endBuild - startBuild) for \(numDivisions) divisions yielding \(tileCount) tiles")
        }
        
        guard numDivisions > 0 else {
            return [Tile]()
        }
        
        // Plot points on the surface of a sphere by starting the pointy bits of 12 pentagons (an isohedron),
        // and then iteratively subdividing the lines between those points
        let points = makePoints(radius: radius, numDivisions: numDivisions, status: status)
        // Why do this? Don't know much trigonometry
        points.forEach {
            $0.project(toRadius: radius)
        }
        
        // Now we can create a Tile for each point we've plotted
        let population = points.map {
            _Tile(centre: $0, sphereRadius: radius, hexSize: hexSize)
        }
        
        tileCount = population.count
        // This is as good a time as any to find each tile's immediate neighbors
        status("Calculating neighborhoods for all \(tileCount) tiles")
        let allTiles = population.enumerated().map { IndexedTile(idx: $0.offset, baseTile: $0.element)}
        let allTilesTree = KDTree(values: allTiles)
        return allTiles.map {
            return Tile(baseTile: $0.baseTile, neighbors: $0.findNeighborsIndices(population: allTilesTree))
        }
    }
    
}
