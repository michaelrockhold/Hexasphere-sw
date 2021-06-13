//
//  Face.swift
//  
//
//  Created by Michael Rockhold on 4/24/21.
//

import Foundation
import Numerics

struct Face {
    
    let a: Point
    let b: Point
    let c: Point
            
    func project(toRadius r: Double) -> Face {
        return Face(a: a.project(toRadius: r), b: b.project(toRadius: r), c: c.project(toRadius: r))
    }

    var centroid: Point {
        return Point(x: (a.x + b.x + c.x)/3.0, y: (a.y + b.y + c.y)/3.0, z: (a.z + b.z + c.z)/3.0)
    }

    // Faces are adjacent if they have two points in common; therefore subtracting one's points from the other's should leave 0 or 1
    func isAdjacent(to otherFace: Face) -> Bool {
        var commonCount = 0
        let epsilon = 0.01
        
        for p1 in [a, b, c] {
            for p2 in [otherFace.a, otherFace.b, otherFace.c] {
                if p1.distance(to: p2) < epsilon {
                    commonCount += 1
                }
                if commonCount > 1 { return true }
            }
        }
        
        return commonCount >= 2
    }
}

