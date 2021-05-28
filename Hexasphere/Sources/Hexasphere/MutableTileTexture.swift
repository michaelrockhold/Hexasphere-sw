//
//  File.swift
//  
//
//  Created by Michael Rockhold on 4/27/21.
//

import Foundation
import CoreGraphics

class MutableTileTexture {
    
    static let bytesPerPixel = 4
    static let bitsPerComponent = 8
    
    let width: Int
    let height: Int
    let context: CGContext
    var bitmapData: [UInt8]
    
    init(width w: Int, height h: Int) throws {
        
        width = w
        height = h
        bitmapData = MutableTileTexture.makeBitmapData(count: MutableTileTexture.bytesPerPixel * w * h)
        context = MutableTileTexture.makeContext(data: &bitmapData,
                                                 width: w, height: h,
                                                 bytesPerRow: MutableTileTexture.bytesPerPixel * w)
    }
    
    private static func makeBitmapData(count: Int) -> [UInt8] {
        return [UInt8](repeating: 0xFF, count: count)
    }
    
    private static func makeContext(data: inout [UInt8], width: Int, height: Int, bytesPerRow: Int) -> CGContext {
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
        
        var bitmapInfo0: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo0 |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        guard let cntxt = CGContext(data: &data,
                                    width: width, height: height,
                                    bitsPerComponent: MutableTileTexture.bitsPerComponent,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: bitmapInfo0) else {
            fatalError()
        }
        
        cntxt.interpolationQuality = .none
        cntxt.setAllowsAntialiasing(false)
        cntxt.setShouldAntialias(false)
        return cntxt
    }
    
    var tileTextureImage: CGImage {
        get {
            return context.makeImage()!
        }
    }
    
    func setPixel(forIndex tileIndex: Int, to color: CGColor) {
        setPixel(forIndices: IndexSet(integer: tileIndex), to: color)
    }
    
    func setPixel(forIndices tileIndices: IndexSet, to color: CGColor) {
        
        let components = color.components!
        let r = UInt8(components[0] * 255.0)
        let g = UInt8(components[1] * 255.0)
        let b = UInt8(components[2] * 255.0)
        let a = UInt8(components[3] * 255.0)
        
        for x in tileIndices {
            
            let coord = textureCoord(forTileIndex:x, normalised: false)
            
            let byteIndex = (width * Int(coord.y) + Int(coord.x)) * 4 //the offset of pixel(x,y) into the 1d array of pixel components
            
            guard byteIndex+4 <= bitmapData.count else {
                continue
            }
            bitmapData[byteIndex] = r
            bitmapData[byteIndex + 1] = g
            bitmapData[byteIndex + 2] = b
            bitmapData[byteIndex + 3] = a
        }
    }
    
    func textureCoord(forTileIndex tileIndex: Int, normalised: Bool) -> CGPoint {
        let wf = width / 4
        let hf = height / 4
        
        let x = Double(tileIndex % wf) * 4
        let y = Double(tileIndex / hf) * 4
        
        return normalised ? CGPoint(x: CGFloat((x + 0.5) / Double(width)),
                                    y: CGFloat((y + 0.5) / Double(height)))
            
            : CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
}
