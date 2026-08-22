//
//  ContentView.swift
//  VisualAlarm
//
//  Created by Denis on 14.08.2026.
//

import SwiftUI

struct ContentView: View {
    @State var isTorchOn = false
    
    private var torchController = TorchController()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            
            Button(torchButtonTitle) {
                toggleTorch()
            }
        }
        .padding()
    }
    
    private var torchButtonTitle: String {
        isTorchOn ? "Turn Off" : "Turn On"
    }
    
    private func toggleTorch() {
        let toggleSuccess = torchController.setTorch(on: !isTorchOn)
        
        if toggleSuccess {
            isTorchOn.toggle()
        }
    }
}

#Preview {
    ContentView()
}
