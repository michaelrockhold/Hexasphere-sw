//
//  Face.swift
//  
//
//  Created by Michael Rockhold on 4/24/21.
//

import Foundation

class Face {
    
    // Contrary to what you might expect, the Points own the Faces
    // they are part of, not the other way around
    unowned let pA: Point
    unowned let pB: Point
    unowned let pC: Point

    private let pointIDSet: Set<Int>
    private let pointSet: Set<Int64>
    
    init(_ a: Point, _ b: Point, _ c: Point, registering: Bool = true) {
        
        pA = a
        pB = b
        pC = c
        
        pointIDSet = Set<Int>(arrayLiteral: pA.pointID, pB.pointID, pC.pointID)
        pointSet = Set<Int64>(arrayLiteral: pA.comparisonValue, pB.comparisonValue, pC.comparisonValue)

        if registering {
            pA.remember(face: self)
            pB.remember(face: self)
            pC.remember(face: self)
        }
    }
        
    var centroid: Vector {
        return Vector.centroid(pA.v, pB.v, pC.v)
    }

    // Faces are adjacent if they have two points in common; therefore subtracting one's points from the other's should leave 0 or 1
    func isAdjacent(to face: Face) -> Bool {
        let diff = pointIDSet.subtracting(face.pointIDSet)
//        let diff = pointSet.subtracting(face.pointSet)
        return diff.count < 2
    }

    static func sortedInAdjacencyOrder(_ faces: [Face]) -> [Face] {
        guard faces.count > 0 else {
            return [Face]()
        }

        var workingArray = faces // copy
        var ret = [Face]()
        
        ret.append(workingArray.removeFirst())
        while workingArray.count > 0 {
            var adjacentIdx = -1
            for (idx,f) in workingArray.enumerated() {
                if f.isAdjacent(to: ret.last!) {
                    adjacentIdx = idx
                    break
                }
            }
            if adjacentIdx < 0 {
                fatalError("error finding adjacent face") // or we loop forever now
            }
            ret.append(workingArray.remove(at: adjacentIdx))
        }
        return ret
    }
}

