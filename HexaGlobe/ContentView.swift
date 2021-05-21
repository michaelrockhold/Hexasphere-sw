//
//  ContentView.swift
//  HexaGlobe
//
//  Created by Michael Rockhold on 4/22/21.
//  Copyright © 2021 Michael Rockhold. All rights reserved.
//

import SwiftUI
import Combine
import CoreData
import SceneKit
import Hexasphere

struct ContentView: View {
    
    @EnvironmentObject var coordinator: SceneCoordinator
    
    var cameraNode: SCNNode? {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.name = "Camera 1"
        cameraNode.position = SCNVector3(0.0, 0.0, 4.0)
        return cameraNode
    }
    
    var body: some View {
        VStack {
            SceneView(
                scene: coordinator.theScene,
                pointOfView: cameraNode,
                options: [
                    .allowsCameraControl
                ],
                delegate: coordinator
            );
            Text(coordinator.message)
        }
    }
}
