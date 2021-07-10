//
//  File.swift
//  
//
//  Created by Michael Rockhold on 6/11/21.
//

import Foundation

class PointSource {
    var points = Set<Point>()
    
    func newPoint(_ x: Double, _ y: Double, _ z: Double) -> Point {
        let p = Point(x: x, y: y, z: z)
        let (_, pp) = points.insert(p)
        return pp
    }
            
    func checkPoint(_ p: Point) -> Point {
        let (_, pp) = points.insert(p)
        return pp
    }
    
    func reproject(radius: Double) {
        for p in points {
            p.project(toRadius: radius)
        }
    }
}
