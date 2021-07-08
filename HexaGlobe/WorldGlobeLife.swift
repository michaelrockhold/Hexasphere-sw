//
//  WorldGlobeLife.swift
//  HexaGlobe
//
//  Created by Michael Rockhold on 7/5/21.
//

import Foundation
import Hexasphere
import CoreGraphics
import MapKit

func applyRules(to cellInfo: CellInfo, liveCellIndices: IndexSet) -> Bool {
    var liveCellCount = liveCellIndices.contains(cellInfo.cellID) ? 1 : 0
    let liveNeighbors = cellInfo.neighbors.filter { liveCellIndices.contains($0) }
    liveCellCount += liveNeighbors.count
    
    if cellInfo.neighbors.count == 5 { // Pentagon: liveCellCount may range from 0 to 6
        return liveCellCount > 2 && liveCellCount < 5
    } else { // Hexagon: liveCellCount may range from 0 to 7
        return liveCellCount > 2 && liveCellCount < 6
    }
}

class WorldGlobeLife: HexasphereGame {
    
    func startState(hexasphere: Hexasphere) -> LifeGameState<Hexasphere> {
        let geoData = ImageGeoData(imageFilename: "equirectangle_projection.png")
        var landIndices = IndexSet()
        for (tIdx, tile) in hexasphere.tiles.enumerated() {
            if geoData.isLand(at: tile.coordinate) {
                landIndices.insert(tIdx)
            }
        }
        return LifeGameState(generation: 0,
                             cellInfoSource: hexasphere,
                             liveCellIndices: landIndices,
                             generationRule: applyRules)
    }
    
    func next(after state: LifeGameState<Hexasphere>) -> LifeGameState<Hexasphere> {
        return state.nextState()
    }
    
    func apply(state: LifeGameState<Hexasphere>, to node: Hexasphere.Node) {
        
        let maxTileIndex = state.cellInfoSource.tiles.count - 1
        for idx in 0...maxTileIndex {
            node.updateTileTexture(forTileAt: idx, with: state.liveCellIndices.contains(idx) ? .green : .blue)
        }
        node.updateMaterialFromTexture()
    }
}

class ImageGeoData: GeoData {
    
    let image: NSImage
    let imageRep: NSBitmapImageRep
    var pixelsWide: Int {
        return imageRep.pixelsWide
    }
    var pixelsHigh: Int {
        return imageRep.pixelsHigh
    }

    init(imageFilename: String) {
        image = NSImage(named:imageFilename)!
        imageRep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    }
    
    /*!
     * Returns YES if the specified latitude/longitude is considered to be land in the specified image.  This is signified by
     * a black pixel.
     */
    func isLand(at coord: CLLocationCoordinate2D) -> Bool {
        
        let color = imageRep.colorAt(x: Int(Double(imageRep.pixelsWide) * (coord.longitude + 180.0) / 360.0),
                                     y: Int(Double(imageRep.pixelsHigh) * (coord.latitude + 90.0) / 180.0)) ?? NSColor(red: 1.0, green: 0, blue: 0, alpha: 1.0)
        
        let pixelColor = GLubyte(color.redComponent * 255.0)
        
        return pixelColor == GLubyte(0)
    }
}
