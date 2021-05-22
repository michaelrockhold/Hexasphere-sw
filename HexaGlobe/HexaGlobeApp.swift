//
//  HexaGlobeApp.swift
//  HexaGlobe
//
//  Created by Michael Rockhold on 4/22/21.
//  Copyright © 2021 PKCLsoft. All rights reserved.
//

import SwiftUI
import SceneKit
import Hexasphere

extension CGColor {
    static let red = CGColor.init(red: 1.0, green: 0, blue: 0, alpha: 1)
    static let green = CGColor.init(red: 0, green: 1.0, blue: 0, alpha: 1.0)
    static let blue = CGColor.init(red: 0, green: 0, blue: 1.0, alpha: 1.0)
    static let purple = CGColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0)
}

class ImageGeoData: GeoData {
    
    let image: NSImage
    let imageRep: NSBitmapImageRep
    
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

func updateFromGeo(earth: Hexasphere, node: Hexasphere.Node, geoData: GeoData) {
    defer {
        node.updateMaterialFromTexture()
    }
    for (tIdx, tile) in earth.tiles.enumerated() {
        let tileColour: CGColor
        if geoData.isLand(at: tile.coordinate) {
            tileColour = .green
        } else {
            tileColour = .blue
        }
        node.updateTileTexture(forTileAt: tIdx, with: tileColour)
    }
    // Right, and just to show that the tiles know their neighbors (That's cool, right?),
    // let's get out the highlighter and colour some more tiles.
    for tileIdx in 0..<12 {
        let t = earth.tiles[tileIdx]
        node.updateTileTexture(forTileAt: tileIdx, with: .red)
        for nIdx in t.neighbors {
            node.updateTileTexture(forTileAt: nIdx, with: .purple)
        }
    }
}


class SceneCoordinator: NSObject, SCNSceneRendererDelegate, ObservableObject {
    
    var showsStatistics: Bool = true
    var debugOptions: SCNDebugOptions = [
        //        .showCameras,
        //        .showBoundingBoxes,
        //        .showConstraints
    ]
    
    @Published var theScene = SCNScene()
    
    @Published var message = String()
    
    override init() {
        
        super.init()
        theScene.background.contents = NSColor.darkGray
        
        DispatchQueue.global(qos: .background).async {
            
            
            let node: Hexasphere.Node
            do {
                let earth = try Hexasphere(radius: HexaGlobeApp.GLOBE_RADIUS,
                                           numDivisions: 32,
                                           hexSize: 0.99) { [weak self] msg in
                    
                    // Update the status window with informative messages as the globe creation process proceeds.
                    DispatchQueue.main.async {
                        self?.message = msg
                        #if DEBUG
                        print(msg)
                        #endif
                    }
                }
                
                node = try earth.buildNode(name: "Earth", initialColour: .green)
                node.position = SCNVector3(0.0, 0.0, 0.0)
                
                // Just for fun, let's put a big yellow sphere in the center of the slowly spinning cloud
                // of tiles. I dunno, it just seems cool. It's cool! Cool yellow mini-sun in the center of
                // the world. Why not?
                node.addChildNode(SCNNode(geometry: {
                                            let geom = SCNSphere(radius: CGFloat(earth.radius*0.95))
                                            geom.firstMaterial = {
                                                let material = SCNMaterial()
                                                material.diffuse.contents = NSColor.yellow
                                                return material
                                            }()
                                            return geom }()))
                
                // OK, so now let's color the tiles in a fun way. Yes, this is fun too. Maybe
                // even more than the yellow-ball-in-the-middle-of-the-world thing. Check it out
                updateFromGeo(earth: earth, node: node, geoData: ImageGeoData(imageFilename: "equirectangle_projection.png"))
            }
            catch {
                fatalError()
            }
            
            DispatchQueue.main.async {
                // The planet is fully initialized; add it to the root node of the current scene, and let the user play with it

                //            scene.rootNode.addChildNode(earth.node)
                //            self.theScene = scene
                node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi, z: 0, duration: 60.0)))
                self.theScene.rootNode.addChildNode(node)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        renderer.showsStatistics = self.showsStatistics
        renderer.debugOptions = self.debugOptions
    }
}

@main
struct HexaGlobeApp: App {
    static let GLOBE_RADIUS: Double = 2.0
    
    @StateObject var earthCoordinator = SceneCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(earthCoordinator)
        }
    }
}
