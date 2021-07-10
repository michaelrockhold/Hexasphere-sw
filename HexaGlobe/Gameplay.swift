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

protocol HexasphereGame {
    
    func startState(hexasphere: Hexasphere) -> LifeGameState<Hexasphere>
    
    func next(after state: LifeGameState<Hexasphere>) -> LifeGameState<Hexasphere>
    
    func apply(state: LifeGameState<Hexasphere>, to: Hexasphere.Node)
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
    
    init(game: HexasphereGame) {
        
        super.init()
        theScene.background.contents = NSColor.darkGray
        
        DispatchQueue.global(qos: .background).async {
            
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
                                           numDivisions: 16, // 262144 (2**18) should give tiles slightly smaller than a 10-lane olympic pool, or the footprint of a single-family home
                                           hexSize: 0.99)
                
                let node = try earth.buildNode(name: "Earth",
                                           initialColour: .blue,
                                           tileCount: earth.tiles.count)
                node.position = SCNVector3(0.0, 0.0, 0.0)
                                                
                var gameState = game.startState(hexasphere: earth)
                
                DispatchQueue.main.async {
                    // The planet is fully initialized; add it to the root node of the current scene, and let the user play with it
                    game.apply(state: gameState, to: node)
                    self.theScene.rootNode.addChildNode(node)
                    
                    node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi, z: 0, duration: 60.0)))

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.cancellable = Timer.publish(every: 0.3, on: .main, in: .common)
                        .autoconnect()
                        .sink() { _ in
                            DispatchQueue.global(qos: .background).async {
                                
                                gameState = game.next(after: gameState)
                                
                                DispatchQueue.main.async {
                                    game.apply(state: gameState, to: node)
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
