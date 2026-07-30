//
//  ContentView.swift
//  DeploymentTargetTest
//
//  Created by Denis on 29.07.2026.
//

internal import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            if let globeImage = NSImage(named: "globe") {
                Image(nsImage: globeImage)
                    .resizable()
                    .scaledToFit()
            }
            Text("Hello, world!")
            
            Button("Brighter") {
                BrightnessController.setScreenBrightness(100)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
