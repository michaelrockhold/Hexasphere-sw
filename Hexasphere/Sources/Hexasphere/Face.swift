//
//  Face.swift
//  
//
//  Created by Michael Rockhold on 4/24/21.
//

import Foundation
import Numerics

class Face {
    
    unowned let a: Point
    unowned let b: Point
    unowned let c: Point
    
    init(a: Point, b: Point, c: Point, andRegister r: Bool = true) {
        self.a = a; self.b = b; self.c = c
        
        if r {
            self.a.faces.append(self)
            self.b.faces.append(self)
            self.c.faces.append(self)
        }
    }
    
    var centroid: Point {
        return Point(x: (a.x + b.x + c.x)/3.0, y: (a.y + b.y + c.y)/3.0, z: (a.z + b.z + c.z)/3.0)
    }

    // Faces are adjacent if they have two points in common
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
        return false
    }
}
