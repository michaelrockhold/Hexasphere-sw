//
//  Hexasphere+SCNNode.swift
//  
//
//  Created by Michael Rockhold on 5/18/21.
//

import SceneKit

extension Vector {
    func scn3() -> SCNVector3 {
        return SCNVector3Make(CGFloat(x), CGFloat(y), CGFloat(z))
    }
}

extension GLKVector3 {
    func scn3() -> SCNVector3 {
        return SCNVector3FromGLKVector3(self)
    }
}

@available(macOS 10.15, *)
extension Hexasphere {
    
    public class Node: SCNNode {
        
        private let tileTexture: MutableTileTexture
        private let oneMeshMaterial: SCNMaterial
        
        fileprivate init(geometry g: SCNGeometry, tileTexture tt: MutableTileTexture, oneMeshMaterial omm: SCNMaterial, name n: String) {
            tileTexture = tt
            oneMeshMaterial = omm
            super.init()
            self.geometry = g
            name = n
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public func updateTile(at tileIndex: Tile.TileIndex, with color: CGColor) {
            tileTexture.setPixel(forIndex: tileIndex, to: color)
            oneMeshMaterial.diffuse.contents = tileTexture.tileTextureImage
        }
        
        public func updateTileTexture(forTileAt tileIndex: Tile.TileIndex, with colour: CGColor) {
            tileTexture.setPixel(forIndex: tileIndex, to: colour)
        }
        public func updateMaterialFromTexture() {
            oneMeshMaterial.diffuse.contents = tileTexture.tileTextureImage
        }
    }

    // Now create a SceneKit node from the hexasphere, where all tiles become part of a single node,
    // rather than trying to get SceneKit to render thousands of nodes.
    
    public func buildNode(name: String, initialColour: CGColor) throws -> Node {
        
        let startBuild = Date.timeIntervalSinceReferenceDate
        status("Started at \(startBuild)")
        defer {
            let endBuild = Date.timeIntervalSinceReferenceDate
            status("build time taken: \(endBuild - startBuild)")
        }

        // We colour each tile individually by using a texture and mapping each tile ID to
        // a coordinate that can be derived from the tile ID.
        // Create the default texture
        let tileTexture = try MutableTileTexture()

        var oneMeshIndices = [UInt32]()
        var oneMeshNormals = [SCNVector3]()
        var oneMeshVertices = [SCNVector3]()
        var oneMeshTextureCoordinates = [CGPoint]()
                
        var vertexIndex = 0
        
        for (tileIdx, tile) in tiles.enumerated() {
            
            for boundary in tile.boundaries {
                oneMeshVertices.append(boundary.scn3())
                oneMeshNormals.append(tile.normal.scn3())
                oneMeshTextureCoordinates.append(MutableTileTexture.textureCoord(forTileIndex: tileIdx,
                                                                                 normalised: true))
            }
            
            // Sometimes there are pentagons (well, 12 times), but mostly it's hexagons.
            let indicesNeeded = (tile.boundaries.count - 2) * 3
                        
            for i in [0, 1, 2,
                      0, 2, 3,
                      0, 3, 4,
                      0, 4, 5][0..<indicesNeeded] {
                oneMeshIndices.append(UInt32(vertexIndex + i))
            }
            vertexIndex += tile.boundaries.count
            
            tileTexture.setPixel(forIndex: tileIdx, to: initialColour)
        }
        
        status("World tiles: \(tiles.count); vertices: \(vertexIndex); indices: \(oneMeshIndices.count)")
        
        let geometry = createGeometry(indices: oneMeshIndices,
                                           normals: oneMeshNormals,
                                           vertices: oneMeshVertices,
                                           textureCoordinates: oneMeshTextureCoordinates)
        let material = SCNMaterial()
        material.diffuse.contents = tileTexture.tileTextureImage
        material.isDoubleSided = true
        material.locksAmbientWithDiffuse = true
        geometry.materials = [material]

        return Node(geometry: geometry, tileTexture: tileTexture, oneMeshMaterial: material, name: name)
    }
    
    private func createGeometry(
        
        indices: [UInt32],
        normals: [SCNVector3],
        vertices: [SCNVector3],
        textureCoordinates: [CGPoint]
        ) -> SCNGeometry {
                
        // Now that we have all the data, populate the various SceneKit structures ahead of creating
        // the geometry.
        //
        // Create a mesh of triangles using the indices that map the coordinates of each triangle to vertices
        //
        let oneMeshElement = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        // Create a source specifying the normal of each vertex.
        let oneMeshNormalSource = SCNGeometrySource(normals: normals)
        
        // Create a source of the vertices.
        let oneMeshVerticeSource = SCNGeometrySource(vertices: vertices)
        
        // Create a texture map that tells SceneKit where in the material to get colour information for
        // each vertex.
        let textureMappingSource = SCNGeometrySource(textureCoordinates: textureCoordinates)
                
        // Create the geometry, at last.
        return SCNGeometry(sources: [oneMeshVerticeSource, oneMeshNormalSource, textureMappingSource], elements: [oneMeshElement])
    }
}
