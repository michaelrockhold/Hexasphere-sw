//
//  File.swift
//  
//
//  Created by Michael Rockhold on 4/24/21.
//

import Foundation
import Algorithms
import Numerics
import GLKit // for GLKVector3 and its operators
import MapKit // for CLLocationCoordinate2D

extension GLKVector3 {
    static func fromVector(_ v: Vector) -> GLKVector3 {
        return GLKVector3Make(Float(v.x), Float(v.y), Float(v.z))
    }
}

/*!
 * Comment from author of ObjC original:
 * Is supposed the compute the normal for three vectors. Not entirely convinced it works as expected.
 */
func normal_(_ v1: Vector, _ v2: Vector, _ v3: Vector) -> GLKVector3 {
    return GLKVector3Normalize(GLKVector3CrossProduct(GLKVector3Subtract(.fromVector(v2), .fromVector(v1)), GLKVector3Subtract(.fromVector(v3), .fromVector(v1))))
}

struct _Tile {
    let centre: Vector
    var boundaries: [Vector]
    let coordinate: CLLocationCoordinate2D
    let normal: GLKVector3
    
    init(centre: Point, sphereRadius: Double, hexSize: Double) {
        
        self.init(centre: centre.v,
                  facesInAdjacencyOrder: Face.sortedInAdjacencyOrder(centre.faces),
                  sphereRadius: sphereRadius,
                  hexSize: hexSize)
    }

    init(centre c: Vector,
         facesInAdjacencyOrder faces: [Face],
         sphereRadius: Double,
         hexSize: Double) {
        
        func segment(centroid: Vector, to point: Vector, percent: Double) -> Vector {
            
            let d = 1.0 - percent
            return Vector(x: point.x * d + centroid.x * percent,
                          y: point.y * d + centroid.y * percent,
                          z: point.z * d + centroid.z * percent)
        }
        
        centre = c
        coordinate = _Tile.getCoordinate(forRadius: sphereRadius, at: centre)
        boundaries = faces.map { segment(centroid: $0.centroid, to: c, percent: .maximum(0.01, .minimum(1.0, hexSize))) }
        normal = normal_(boundaries[0], boundaries[1], boundaries[2])
    }
    
    static func getCoordinate(forRadius radius: Double, at v: Vector) -> CLLocationCoordinate2D {
        let phi: Double = .acos(v.y / radius) //lat
        let theta: Double = (.atan2(y:v.x, x:v.z) + .pi).truncatingRemainder(dividingBy: .pi * 2.0) - .pi // lon
        
        return CLLocationCoordinate2D(latitude: 180.0 * phi / .pi - 90,
                                      longitude: 180.0 * theta / .pi)
    }
    
    func findNeighborsIndices(population: [_Tile]) -> [Tile.TileIndex] {
                
        // We scan the provided array of tiles to find the 5 or 6 closest to outself.
        // We assume that self is in the list, and therefore will be the first closest,
        // and easy to ignore.
                
        // TODO: opportunities for parallelization here?
        return population.enumerated().map { otherTileTuple in
            
            return (idx: otherTileTuple.offset,
                    distanceToReferenceTile: otherTileTuple.element.centre.distance(to: self.centre))
            
        }.sorted { a, b in
            a.distanceToReferenceTile < b.distanceToReferenceTile
            
        }[1...self.boundaries.count]
        .map { $0.idx }
    }
}

public struct Tile {
    public typealias TileIndex = Int
    
    public let centre: Vector
    public let boundaries: [Vector]
    public let coordinate: CLLocationCoordinate2D
    public let normal: GLKVector3
    public let neighbors: [TileIndex]
    
    init(baseTile: _Tile, neighbors nn: [TileIndex]) {
        centre = baseTile.centre
        boundaries = baseTile.boundaries
        coordinate = baseTile.coordinate
        normal = baseTile.normal
        neighbors = nn
    }
}
