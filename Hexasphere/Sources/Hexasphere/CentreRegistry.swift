//
//  File.swift
//  
//
//  Created by Michael Rockhold on 6/11/21.
//

import Foundation

class CentreRegistry {
    
    var store = Dictionary<Point, [Face]>()
    
    func register(point: Point, face: Face) {
        if store[point] != nil {
            store[point]?.append(face)
        } else {
            store[point] = [face]
        }
    }
    
    func enregister(face: Face) {
        register(point: face.a, face: face)
        register(point: face.b, face: face)
        register(point: face.c, face: face)
    }

    func facesInAdjacencyOrder(forCentre c: Point) -> [Face] {
        
        var ret = [Face]()
        guard let faces = store[c] else {
            return ret
        }
        
        guard faces.count > 0 else {
            return ret
        }

        var workingArray = faces // copy
        
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
