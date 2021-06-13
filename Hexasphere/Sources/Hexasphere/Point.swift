//
//  Point.swift
//  
//
//  Created by Michael Rockhold on 4/24/21.
//

import Foundation
import Numerics

func distanceTo(xa: Double, ya: Double, za: Double, xb: Double, yb: Double, zb: Double) -> Double {
    return .sqrt(.pow(xb-xa, 2) + .pow(yb-ya, 2) + .pow(zb-za, 2))
}

public struct Point {
    let x: Double
    let y: Double
    let z: Double
    
    func hypotenuse() -> Double {
        return .sqrt(x*x + y*y + z*z)
    }
    
    func distance(to b: Point) -> Double {
        return Point(x: b.x-x, y: b.y-y, z: b.z-z).hypotenuse()
    }
    
    func squaredDistance(to b: Point) -> Double {
        return pow(b.x-x, 2) + pow(b.y-y, 2) + pow(b.z-z, 2)
    }
    
    func project(toRadius radius: Double) -> Point {
        return project(toRadius: radius, withPercentage: 1.0)
    }

    func project(toRadius radius: Double, withPercentage percent: Double) -> Point {
        let percent: Double = .maximum(0.0, .minimum(1.0, percent))
        let ratio = radius / hypotenuse()
        return Point(x: x * ratio * percent, y: y * ratio * percent, z: z * ratio * percent)
    }
    
    func surfaceTangent() -> Point {
        let theta: Double = .acos(z/hypotenuse())
        let phi: Double = .atan2(y: y, x: x)
        
        //then add pi/2 to theta or phi
        return Point(x: sin(theta) * cos(phi), y: sin(theta) * sin(phi), z: cos(theta))
    }
                
    func subdivide(point p: Point, count: Int, pointSource: PointSource) -> [Point] {
        
        var segment = [Point]()
        segment.append(self)
        
        for i in 1..<count {
            let iOverCount = Double(i) / Double(count)
            let d = 1.0 - iOverCount
            let np = pointSource.newPoint(x * d + p.x * iOverCount,
                                          y * d + p.y * iOverCount,
                                          z * d + p.z * iOverCount)
            
            segment.append(pointSource.checkPoint(np))
        }
        
        segment.append(p)
        return segment
    }
}

extension Point: Hashable {
    public static func == (lhs: Point, rhs: Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(z)
    }
}
