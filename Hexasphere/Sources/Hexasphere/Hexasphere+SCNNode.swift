//
//  Hexasphere+SCNNode.swift
//  
//
//  Created by Michael Rockhold on 5/18/21.
//

import SceneKit

extension SCNVector3 {
    init(point p: Point) {
        self = SCNVector3Make(CGFloat(p.x), CGFloat(p.y), CGFloat(p.z))
    }
    
    init(glkvector: GLKVector3) {
        self = SCNVector3FromGLKVector3(glkvector)
    }
}

extension GLKVector3 {
    init(point p: Point) {
        self = GLKVector3Make(Float(p.x), Float(p.y), Float(p.z))
    }
}

private func normal_(_ p1: Point, _ p2: Point, _ p3: Point) -> SCNVector3 {
    return normal_(GLKVector3(point: p1), GLKVector3(point: p2), GLKVector3(point: p3))
}

/*!
 * Comment from author of ObjC original:
 * Is supposed the compute the normal for three vectors. Not entirely convinced it works as expected.
 */
private func normal_(_ v1: GLKVector3, _ v2: GLKVector3, _ v3: GLKVector3) -> SCNVector3 {
    return SCNVector3(glkvector: GLKVector3Normalize(GLKVector3CrossProduct(GLKVector3Subtract(v2, v1), GLKVector3Subtract(v3, v1))))
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
        
        public func updateTiles(forIndices tileIndices: IndexSet, with color: CGColor) {
            tileTexture.setPixel(forIndices: tileIndices, to: color)
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
    
    public func buildNode(name: String,
                          initialColour: CGColor,
                          tileCount: Int) throws -> Node {
        
        let startBuild = Date.timeIntervalSinceReferenceDate
        status("Started at \(startBuild)")
        defer {
            let endBuild = Date.timeIntervalSinceReferenceDate
            status("build time taken: \(endBuild - startBuild)")
        }
        
        // We colour each tile individually by using a texture and mapping each tile ID to
        // a coordinate that can be derived from the tile ID.
        // Create the default texture
        let tileTexture = try MutableTileTexture(tileCount: tileCount)
        
        var oneMeshIndices = [UInt32]()
        var oneMeshNormals = [SCNVector3]()
        var oneMeshVertices = [SCNVector3]()
        var oneMeshTextureCoordinates = [CGPoint]()
        
        func createGeometry() -> SCNGeometry {
            
            // Once we have all the data, populate the various SceneKit structures ahead of creating
            // the geometry.
            
            // Create a source specifying the normal of each vertex.
            let oneMeshNormalSource = SCNGeometrySource(normals: oneMeshNormals)
            
            // Create a source of the vertices.
            let oneMeshVerticeSource = SCNGeometrySource(vertices: oneMeshVertices)
            
            // Create a texture map that tells SceneKit where in the material to get colour information for
            // each vertex.
            let textureMappingSource = SCNGeometrySource(textureCoordinates: oneMeshTextureCoordinates)
            
            return SCNGeometry(sources: [oneMeshVerticeSource,
                                         oneMeshNormalSource,
                                         textureMappingSource],
                               
                               // Create a mesh of triangles using the indices that map the coordinates of
                               // each triangle to vertices
                               elements: [SCNGeometryElement(indices: oneMeshIndices, primitiveType: .triangles)])
        }
        
        
        var vertexIndex = 0
        
        for (tileIdx, tile) in tiles.enumerated() {
            
            let normal = normal_(tile.boundaries[0], tile.boundaries[1], tile.boundaries[2])
            let textureCoord = tileTexture.textureCoord(forTileIndex: tileIdx, normalised: true)
            
            for boundary in tile.boundaries {
                oneMeshVertices.append(SCNVector3(point: boundary))
                oneMeshNormals.append(normal)
                oneMeshTextureCoordinates.append(textureCoord)
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
        
        let material = SCNMaterial()
        material.diffuse.contents = tileTexture.tileTextureImage
        material.isDoubleSided = true
        material.locksAmbientWithDiffuse = true
        
        let geometry = createGeometry()
        geometry.materials = [material]
        
        return Node(geometry: geometry, tileTexture: tileTexture, oneMeshMaterial: material, name: name)
    }
}
