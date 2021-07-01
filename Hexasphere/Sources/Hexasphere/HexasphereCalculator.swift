//
//  HexasphereCalculator.swift
//  
//
//  Created by Michael Rockhold on 6/27/21.
//

import Foundation
import KDTree

struct HexasphereCalculator {
    public let radius: Double
    public let numDivisions: Int
    public let hexSize: Double
    
    let familyID: String
    let reduceQueue: DispatchQueue
    
    init(radius r: Double, numDivisions nd: Int, hexSize hs: Double) {
        radius = r
        numDivisions = nd
        hexSize = hs
        familyID = UUID().uuidString
        reduceQueue = DispatchQueue(label: "Hexasphere.\(familyID).reduce")
    }
    
    func run() -> (TileSet, TileNeighborMap) {
        // 512 => World tiles: 2621442; vertices: 15728640; indices: 31457268

        let tiles = calculateTiles(radius: radius,
                                   numDivisions: numDivisions,
                                   hexSize: hexSize)
        let tileNeighbors = findAllNeighbors(for: tiles,
                                             taskCount: Int(Double(tiles.count).squareRoot().rounded()))
        
        return (tiles, tileNeighbors)
    }
    
    // Find each tile's immediate neighbors
    private func findAllNeighbors(for tiles: TileSet, taskCount: Int) -> TileNeighborMap {
        
        let waitGroup = DispatchGroup()
        let workQueue = DispatchQueue(label: "Hexasphere.\(familyID).neighborwork",
                                      attributes: .concurrent)
        var returnValue = TileNeighborMap()
        
        func indexOneSegment(_ first: Int, _ last: Int) {
            waitGroup.enter()
            workQueue.async(qos: .utility) {
                var workingMap = TileNeighborMap()
                for i in first..<last {
                    let indexedTile = indexedTiles[i]
                    workingMap[indexedTile.idx] = indexedTile.findNeighborsIndices(population: indexedTilesTree)
                }
                reduceQueue.sync {
                    returnValue.merge(workingMap) { (_, newElement) in newElement }
                }
                waitGroup.leave()
            }
        }
        
        status("Calculating neighborhoods for all \(tiles.count) tiles")
        let startTime = Date.timeIntervalSinceReferenceDate
        defer {
            status("Tile Neighborhood count time \(Date.timeIntervalSinceReferenceDate - startTime)")
        }
        
        let indexedTiles = tiles.enumerated().map { IndexedTile(idx: $0.offset, baseTile: $0.element)}
        let indexedTilesTree = KDTree(values: indexedTiles)
        
        let segmentSize = indexedTiles.count / taskCount
        let extras = indexedTiles.count % taskCount
        
        var first = 0
        var last = segmentSize + extras
        
        for _ in 0..<taskCount {
            indexOneSegment(first, last)
            
            first = last
            last = last + segmentSize
        }
        
        status("...[waiting for all neighborhood calculations to finish]...")
        waitGroup.wait()
        return returnValue
    }
    
    private func calculateTileCentres(numDivisions: Int,
                                      pointSource: PointSource,
                                      faceRegistry: CentreRegistry) {
        
        status("Computing all tile centres...")
        let startTime = Date.timeIntervalSinceReferenceDate
        defer {
            status("Time to compute all tile centres: \(Date.timeIntervalSinceReferenceDate - startTime) for \(numDivisions) divisions.")
        }
        
        let PHI = (1.0 + .sqrt(5.0)) / 2.0
                
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
        
        for (fidx, face) in faces.enumerated() {
            subdivide(a: face.a, b: face.b, c: face.c,
                      numDivisions: numDivisions,
                      faceIndex: fidx,
                      points: pointSource,
                      registry: faceRegistry)
        }
    }
    
    private func subdivide(
        a: Point,
        b: Point,
        c: Point,
        numDivisions: Int,
        faceIndex: Int,
        points: PointSource,
        registry fr: CentreRegistry) {
        
        let startBuildOfFace = Date.timeIntervalSinceReferenceDate
        status("Starting computation of face \(faceIndex+1)")
        defer {
            status("Face \(faceIndex+1): computation time \(Date.timeIntervalSinceReferenceDate - startBuildOfFace)")
        }
        
        var bottom = [a]
        let left = a.subdivide(point: b, count: numDivisions, pointSource: points)
        let right = a.subdivide(point: c, count: numDivisions, pointSource: points)
        
        for i in 1...numDivisions {
            let prev = bottom
            bottom = left[i].subdivide(point: right[i], count: i, pointSource: points)
            
            for j in 0..<i {
                fr.enregister(face: Face(a: prev[j], b: bottom[j], c: bottom[j+1]))
                
                if (j > 0) {
                    fr.enregister(face: Face(a: prev[j-1], b: prev[j], c: bottom[j]))
                }
            }
        }
    }

    private func calculateTiles(radius: Double, numDivisions: Int, hexSize: Double) -> TileSet {
        
        let waitGroup = DispatchGroup()
        let workQueue = DispatchQueue(label: "Hexasphere.\(familyID).calculateTiles", attributes: .concurrent)
        var returnValue = TileSet()
        
        func processOneSegment(_ points: Slice<Set<Point>>, faceRegistry: CentreRegistry, sphereRadius: Double, hexSize: Double) {
            waitGroup.enter()
            workQueue.async(qos: .utility) {
                let workingSet = TileSet(points.map {
                    Tile(centre: $0,
                         faceRegistry:faceRegistry,
                         sphereRadius: radius,
                         hexSize: hexSize)
                })
                reduceQueue.sync {
                    for tile in workingSet {
                        returnValue.append(tile)
                    }
                }
                waitGroup.leave()
            }
        }
        
        
        status("Computing all tile coordinates...")
        let startTime = Date.timeIntervalSinceReferenceDate
        defer {
            status("Time to compute tile coordinates: \(Date.timeIntervalSinceReferenceDate - startTime) for \(numDivisions) divisions.")
        }
        
        guard numDivisions > 0 else {
            return TileSet()
        }
        
        // Plot points on the surface of a sphere by starting the pointy bits of 12 pentagons (an isohedron),
        // and then iteratively subdividing the lines between those points
        let faceRegistry = CentreRegistry()
        let pointSource = PointSource()

        calculateTileCentres(numDivisions: numDivisions, pointSource: pointSource, faceRegistry: faceRegistry)
        
        let tileCentres = pointSource.points
        
        status("Computing all tile edges from centres...")
        let taskCount = Int(Double(tileCentres.count).squareRoot().rounded())
        let segmentSize = tileCentres.count / taskCount
        let extras = tileCentres.count % taskCount
        
        var first = tileCentres.startIndex
        var last = tileCentres.index(first, offsetBy: segmentSize + extras)
        
        for _ in 0..<taskCount {
            processOneSegment(tileCentres[first..<last],
                              faceRegistry:faceRegistry,
                              sphereRadius: radius,
                              hexSize: hexSize)
            
            first = last
            if last < tileCentres.endIndex {
                last = tileCentres.index(last, offsetBy: segmentSize)
            }
        }
        
        status("...[waiting for all edge calculations to complete]...")
        waitGroup.wait()
        return returnValue
    }
}

//extension Face {
//    func subdivide(numDivisions: Int,
//                   faceIndex: Int,
//                   points: PointSource,
//                   registry fr: CentreRegistry) {
//
//        let startBuildOfFace = Date.timeIntervalSinceReferenceDate
//        status("Starting computation of face \(faceIndex+1)")
//        defer {
//            status("Face \(faceIndex+1): computation time \(Date.timeIntervalSinceReferenceDate - startBuildOfFace)")
//        }
//
//        var bottom = [self.a]
//        let left = self.a.subdivide(point: self.b, count: numDivisions, pointSource: points)
//        let right = self.a.subdivide(point: self.c, count: numDivisions, pointSource: points)
//
//        for i in 1...numDivisions {
//            let prev = bottom
//            bottom = left[i].subdivide(point: right[i], count: i, pointSource: points)
//
//            for j in 0..<i {
//                fr.enregister(face: Face(a: prev[j], b: bottom[j], c: bottom[j+1]))
//
//                if (j > 0) {
//                    fr.enregister(face: Face(a: prev[j-1], b: prev[j], c: bottom[j]))
//                }
//            }
//        }
//    }
//}
