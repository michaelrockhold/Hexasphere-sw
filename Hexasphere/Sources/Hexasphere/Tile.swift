//
//  File.swift
//  
//
//  Created by Michael Rockhold on 4/24/21.
//

import Foundation
import Algorithms
import Numerics
import MapKit // for CLLocationCoordinate2D
import KDTree

public struct Tile {
    public typealias TileIndex = Int

    let centre: Point
    var boundaries: [Point]
    public let coordinate: CLLocationCoordinate2D
    
    init(centre: Point, faceRegistry: CentreRegistry, sphereRadius: Double, hexSize: Double) {
        
        self.init(centre: centre,
                  facesInAdjacencyOrder: faceRegistry.facesInAdjacencyOrder(forCentre: centre),
                  sphereRadius: sphereRadius,
                  hexSize: hexSize)
    }

    init(centre c: Point,
         facesInAdjacencyOrder faces: [Face],
         sphereRadius: Double,
         hexSize: Double) {
        
        func segment(centroid: Point, to point: Point, percent: Double) -> Point {
            
            let d = 1.0 - percent
            return Point(x: point.x * d + centroid.x * percent,
                          y: point.y * d + centroid.y * percent,
                          z: point.z * d + centroid.z * percent)
        }
        
        centre = c.project(toRadius: sphereRadius)
        coordinate = Tile.getCoordinate(forRadius: sphereRadius, at: centre)
        boundaries = faces.map {
            return segment(centroid: $0.project(toRadius: sphereRadius).centroid, to: c, percent: .maximum(0.01, .minimum(1.0, hexSize)))
        }
    }
    
    static func getCoordinate(forRadius radius: Double, at v: Point) -> CLLocationCoordinate2D {
        let phi: Double = .acos(v.y / radius) //lat
        let theta: Double = (.atan2(y:v.x, x:v.z) + .pi).truncatingRemainder(dividingBy: .pi * 2.0) - .pi // lon
        
        return CLLocationCoordinate2D(latitude: 180.0 * phi / .pi - 90,
                                      longitude: 180.0 * theta / .pi)
    }
}

extension Tile: Hashable {
    public static func == (lhs: Tile, rhs: Tile) -> Bool {
        return lhs.centre == rhs.centre
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(centre)
        hasher.combine(boundaries)
    }
}

public struct IndexedTile {
    let idx: Int
    let baseTile: Tile
    
    func findNeighborsIndices(population: KDTree<IndexedTile>) -> Set<Tile.TileIndex> {
        
        return Set<Tile.TileIndex>( population.nearestK(self.baseTile.boundaries.count+1, to: self).map {
            return $0.idx
        }[1...]
        .map { $0 })
    }
}

extension IndexedTile : KDTreePoint {
    
    public static var dimensions: Int {
        return 3
    }
    
    public func kdDimension(_ dimension: Int) -> Double {
        switch dimension {
        case 0:
            return baseTile.centre.x
        case 1:
            return baseTile.centre.y
        case 2:
            return baseTile.centre.z
        default:
            fatalError()
        }
    }
    
    public func squaredDistance(to otherPoint: IndexedTile) -> Double {
        return baseTile.centre.squaredDistance(to: otherPoint.baseTile.centre)
    }
    
    public static func == (lhs: IndexedTile, rhs: IndexedTile) -> Bool {
        return lhs.idx == rhs.idx
    }
}
