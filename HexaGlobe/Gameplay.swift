//
//  Gameplay.swift
//  HexaGlobe
//
//  Created by Michael Rockhold on 6/20/21.
//
//

import SceneKit
import Hexasphere
import Combine

extension CGColor {
    static let red = CGColor.init(red: 1.0, green: 0, blue: 0, alpha: 1)
    static let green = CGColor.init(red: 0, green: 1.0, blue: 0, alpha: 1.0)
    static let blue = CGColor.init(red: 0, green: 0, blue: 1.0, alpha: 1.0)
    static let purple = CGColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0)
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


extension Hexasphere: CellInfoSource {
    
    public struct TileInfo: CellInfo {
        let cellID: Int
        let neighbors: Set<Int>
    }

    public typealias Element = TileInfo
    public typealias Index = TileSet.Index
    
    public var startIndex: TileSet.Index {
        return self.tiles.startIndex
    }
    
    public var endIndex: TileSet.Index {
        return self.tiles.endIndex
    }

    public subscript(position: TileSet.Index) -> TileInfo {
        return TileInfo(cellID: position, neighbors: self.tileNeighbors[position] ?? Set<Int>())
    }

    public func index(after i: TileSet.Index) -> TileSet.Index {
        return i+1
    }

    public struct TileInfoIterator: IteratorProtocol {
        
        typealias NeighborFunc = (Int)->Set<Int>

        var tileIterator: EnumeratedSequence<TileSet>.Iterator
        let neighborFunc: NeighborFunc

        public mutating func next() -> TileInfo? {
            guard let nextTileTuple = tileIterator.next() else {
                return nil
            }
            return TileInfo(cellID: nextTileTuple.offset, neighbors: neighborFunc(nextTileTuple.offset))
        }
    }


    public func makeIterator() -> TileInfoIterator {
        return TileInfoIterator(tileIterator: self.tiles.enumerated().makeIterator(), neighborFunc: { tileID in
            return self.tileNeighbors[tileID] ?? Set<Int>()
        })
    }
}

typealias HexasphereLifeGameState = LifeGameState<Hexasphere>

extension Hexasphere.Node {
    
    func initialLifeGameState(earth: Hexasphere, geoData: GeoData) -> HexasphereLifeGameState {
                
        var landIndices = IndexSet()
        for (tIdx, tile) in earth.tiles.enumerated() {
            if geoData.isLand(at: tile.coordinate) {
                landIndices.insert(tIdx)
            }
        }
                
        return LifeGameState(cellInfoSource: earth, liveCellIndices: landIndices)
    }

    func applyGameState(_ gameState: HexasphereLifeGameState) {
        let maxTileIndex = gameState.cellInfoSource.tiles.count - 1
        for idx in 0...maxTileIndex {
            updateTileTexture(forTileAt: idx, with: gameState.liveCellIndices.contains(idx) ? .green : .blue)
        }
        updateMaterialFromTexture()
    }
}

class SceneCoordinator: NSObject, SCNSceneRendererDelegate, ObservableObject {
    
    var showsStatistics: Bool = true
    var debugOptions: SCNDebugOptions = [
        //        .showCameras,
        //        .showBoundingBoxes,
        //        .showConstraints
    ]
    var cancellable: Combine.AnyCancellable?
    
    @Published var theScene = SCNScene()
    
    @Published var message = String()
    
    override init() {
        
        super.init()
        theScene.background.contents = NSColor.darkGray
        
        DispatchQueue.global(qos: .background).async {
            
            /*
             DIVISIONS|
             0 invalid
             1 all pentagons (12)
             2 1 hexagon between each of the 12 pentagons (total of 42 tiles)
             4 3 hexagons between pairs of pentagons (162 tiles)
             8 7 hexagons between, (642)
             16 15 hexs, (2562)
             64 World tiles: 40962; vertices: 245760; indices: 491508
             144: World tiles: 208486; vertices: 1244160; indices: 2481564
            288: World tiles: 831718; vertices: 4976640; indices: 9939612 (each tile roughly 613 km2, or 1/5 of Rhode Island)
             
             */
            let node: Hexasphere.Node
            var initialGameState: LifeGameState<Hexasphere>? = nil
            do {
                status = { [weak self] msg in
                    
                    // Update the status window with informative messages as the globe creation process proceeds.
                    DispatchQueue.main.async {
                        self?.message = msg
                        #if DEBUG
                        print(msg)
                        #endif
                    }
                }
                
                let earth = try Hexasphere(radius: HexaGlobeApp.GLOBE_RADIUS,
                                           numDivisions: 512,
                                           hexSize: 0.99)
                
                let geoData = ImageGeoData(imageFilename: "equirectangle_projection.png")

                node = try earth.buildNode(name: "Earth",
                                           initialColour: .blue,
                                           tileCount: earth.tiles.count)
                node.position = SCNVector3(0.0, 0.0, 0.0)
                                
                initialGameState = node.initialLifeGameState(earth: earth, geoData: geoData)
                guard var gameState = initialGameState else {
                    return
                }
                DispatchQueue.main.async {
                    // The planet is fully initialized; add it to the root node of the current scene, and let the user play with it
                    node.applyGameState(gameState)
                    node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi, z: 0, duration: 60.0)))
                    self.theScene.rootNode.addChildNode(node)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.cancellable = Timer.publish(every: 0.3, on: .main, in: .common)
                            .autoconnect()
                            .sink() { _ in
                                DispatchQueue.global(qos: .background).async {
                                    gameState = gameState.nextState()
                                    DispatchQueue.main.async {
                                        node.applyGameState(gameState)
                                    }
                                }
                        }
                    }

                }
            }
            catch  {
                print("Unexpected error: \(error).")
                fatalError()
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        renderer.showsStatistics = self.showsStatistics
        renderer.debugOptions = self.debugOptions
    }
}
