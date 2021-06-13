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
    
    let context: CGContext
    var bitmapData: [UInt8]
    let pixelWidth: Int
    let pixelHeight: Int
    
    init(tileCount: Int) throws {
        
        pixelWidth = Int(sqrt(Double(tileCount)).rounded(.up))
        let h = tileCount / pixelWidth
        pixelHeight = h + (tileCount % pixelWidth > 0 ? 1 : 0)
        
        bitmapData = MutableTileTexture.makeBitmapData(count: MutableTileTexture.bytesPerPixel * pixelWidth * pixelHeight)
        context = MutableTileTexture.makeContext(data: &bitmapData,
                                                 width: pixelWidth,
                                                 height: pixelHeight,
                                                 bytesPerRow: MutableTileTexture.bytesPerPixel * pixelWidth)
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
    
    private func byteIndex(forTileIndex ti: Int) -> Int {
        return ti * MutableTileTexture.bytesPerPixel
    }

    func textureCoord(forTileIndex tileIndex: Int, normalised: Bool) -> CGPoint {
        
        let w = tileIndex % pixelWidth
        let h = tileIndex / pixelWidth
        
        let ret = CGPoint(x: CGFloat(w), y: CGFloat(h))
        if normalised {
            return CGPoint(x: CGFloat((ret.x + CGFloat(0.5)) / CGFloat(pixelWidth)),
                           y: CGFloat((ret.y + CGFloat(0.5)) / CGFloat(pixelHeight)))
        }
        
        return ret
    }

    private func byteIndex(forTextureCoord coord: CGPoint) -> Int {
        
        let x = Int(coord.x.rounded(.down))
        let y = Int(coord.y.rounded(.down))
        
        return (y * pixelWidth + x) * MutableTileTexture.bytesPerPixel
    }

    private func setPixel(atByteIndex byteIndex: Int, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        guard byteIndex+4 <= bitmapData.count else {
            print("ERROR could not calculate a valid byte index")
            return
        }
        
        bitmapData[byteIndex] = r
        bitmapData[byteIndex + 1] = g
        bitmapData[byteIndex + 2] = b
        bitmapData[byteIndex + 3] = a
    }
    
    func setPixel(forTextureCoord coord: CGPoint, to color: CGColor) {
        let components = color.components!
        setPixel(atByteIndex: byteIndex(forTextureCoord: coord),
                 r: UInt8(components[0] * 255.0),
                 g: UInt8(components[1] * 255.0),
                 b: UInt8(components[2] * 255.0),
                 a: UInt8(components[3] * 255.0))
    }
       
    func setPixel(forIndex ti: Int, to color: CGColor) {
        let components = color.components!
        let r = UInt8(components[0] * 255.0)
        let g = UInt8(components[1] * 255.0)
        let b = UInt8(components[2] * 255.0)
        let a = UInt8(components[3] * 255.0)
        
        setPixel(atByteIndex: byteIndex(forTileIndex: ti), r: r, g: g, b: b, a: a)
    }

    func setPixel(forIndices tileIndices: IndexSet, to color: CGColor) {
        let components = color.components!
        let r = UInt8(components[0] * 255.0)
        let g = UInt8(components[1] * 255.0)
        let b = UInt8(components[2] * 255.0)
        let a = UInt8(components[3] * 255.0)
        
        for ti in tileIndices {
            setPixel(atByteIndex: byteIndex(forTileIndex: ti), r: r, g: g, b: b, a: a)
        }
    }
}
