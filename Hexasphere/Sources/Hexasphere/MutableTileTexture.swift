//
//  File.swift
//  
//
//  Created by Michael Rockhold on 4/27/21.
//

import Foundation
import CoreGraphics

class MutableTileTexture {
    
    let width: Int
    let height: Int
    let context: CGContext
    var bitmapData: [UInt8]
            
    init() throws {
        
        width = 1024 //image.width
        height = 1024 //image.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapByteCount = bytesPerRow * height
                
        bitmapData = [UInt8](repeating: 0xFF, count: bitmapByteCount)

        // kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big

        var bitmapInfo0: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo0 |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue

        guard let context = CGContext(data: &bitmapData,
                                  width: width, height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo0) else {
            fatalError()
        }
        self.context = context
        
        context.interpolationQuality = .none
        context.setAllowsAntialiasing(false)
        context.setShouldAntialias(false)
    }
    
    var tileTextureImage: CGImage {
        get {
            return context.makeImage()!
        }
    }
    
    func setPixel(forIndex tileIndex: Int, to color: CGColor) {
        self.setPixel(forIndices: IndexSet(integer: tileIndex), to: color)
    }
    
    func setPixel(forIndices tileIndices: IndexSet, to color: CGColor) {
        
        let components = color.components!
        let r = components[0] * 255.0
        let g = components[1] * 255.0
        let b = components[2] * 255.0
        let a = components[3] * 255.0
        
        for (_, x) in tileIndices.enumerated() {
            
            let coord = Self.textureCoord(forTileIndex:x, normalised: false)
            
            let byteIndex = (self.width * Int(coord.y) + Int(coord.x)) * 4 //the index of pixel(x,y) in the 1d array pixels
            
            guard byteIndex < bitmapData.count else {
                continue
            }
            bitmapData[byteIndex] = UInt8(r)
            bitmapData[byteIndex + 1] = UInt8(g)
            bitmapData[byteIndex + 2] = UInt8(b)
            bitmapData[byteIndex + 3] = UInt8(a)
        }
    }
    
    static func textureCoord(forTileIndex tileIndex: Int, normalised: Bool) -> CGPoint {
        
        var x = CGFloat((tileIndex % 256) * 4)
        var y = CGFloat((tileIndex / 256) * 4)
        
        if normalised {
            x += 0.5
            x /= 1024.0
            y += 0.5
            y /= 1024.0
        }
        
        return CGPoint(x: x, y: y)
    }
    
}
