//
//  HexaGlobeApp.swift
//  HexaGlobe
//
//  Created by Michael Rockhold on 4/22/21.
//  Copyright © 2021 Michael Rockhold. All rights reserved.
//

import SwiftUI

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
