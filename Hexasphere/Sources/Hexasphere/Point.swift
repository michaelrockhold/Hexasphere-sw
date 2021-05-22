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

public struct Vector {
    let x: Double
    let y: Double
    let z: Double
    
    func hypotenuse() -> Double {
        return .sqrt(x*x + y*y + z*z)
    }
    
    func distance(to b: Vector) -> Double {
        return Vector(x: b.x-x, y: b.y-y, z: b.z-z).hypotenuse()
    }
    
    func squaredDistance(to b: Vector) -> Double {
        return pow(b.x-x, 2) + pow(b.y-y, 2) + pow(b.z-z, 2)
    }
    
    func project(toRadius radius: Double, withPercentage percent: Double) -> Vector {
        let percent: Double = .maximum(0.0, .minimum(1.0, percent))
        let ratio = radius / hypotenuse()
        return Vector(x: x * ratio * percent, y: y * ratio * percent, z: z * ratio * percent)
    }
    
    func surfaceTangent() -> Vector {
        let theta: Double = .acos(z/hypotenuse())
        let phi: Double = .atan2(y: y, x: x)
        
        //then add pi/2 to theta or phi
        return Vector(x: sin(theta) * cos(phi), y: sin(theta) * sin(phi), z: cos(theta))
    }
    
    static func centroid(_ a: Vector, _ b: Vector, _ c: Vector) -> Vector {
        return Vector(x: (a.x + b.x + c.x)/3.0, y: (a.y + b.y + c.y)/3.0, z: (a.z + b.z + c.z)/3.0)
    }
    
    func comparisonValue() -> Int64 {
        return Int64(round(x*100.0)) * 1000000000 +
            Int64(round(y*100.0)) * 1000000 +
            Int64(round(z*100.0))
    }

}

class Point: NSObject {
        
    let pointID: Int
    
    var v: Vector
    var comparisonValue: Int64 = 0
    
    var faces = [Face]()
    
    
    init(_ pID: Int, x: Double, y: Double, z: Double) {
        pointID = pID
        
        v = Vector(x: x, y: y, z: z)
        super.init()
        recalculateComparisonValue()
    }
    
    deinit {
        faces.removeAll()
    }
    
    func remember(face: Face) {
        faces.append(face)
    }
    
    func distance(toPoint b: Point) -> Double {
        return v.distance(to: b.v)
    }

    var surfaceTangent: Vector {
        return v.surfaceTangent()
    }

    private func recalculateComparisonValue() {
        comparisonValue = v.comparisonValue()
    }
        
    override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? Point {
            return self.comparisonValue == other.comparisonValue
        } else {
            return false
        }
    }
        
    func subdivide(point p: Point, count: Int, pointSource: PointSource) -> [Point] {
        
        var segment = [Point]()
        segment.append(self)
        
        for i in 1..<count {
            let iOverCount = Double(i) / Double(count)
            let d = 1.0 - iOverCount
            let np = pointSource.newPoint(v.x * d + p.v.x * iOverCount,
                                          v.y * d + p.v.y * iOverCount,
                                          v.z * d + p.v.z * iOverCount)
            
            segment.append(pointSource.checkPoint(np))
        }
        
        segment.append(p)
        return segment
    }
    
    
    func project(toRadius radius: Double) {
        project(toRadius: radius, withPercentage: 1.0)
    }
    
    func project(toRadius radius: Double, withPercentage percent: Double) {
        v = v.project(toRadius: radius, withPercentage: percent)
        recalculateComparisonValue()
    }
}
