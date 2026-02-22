//
//  AIOSSLToolApp.swift
//  CMDLAB AIO SSL Tool
//
//  Modern macOS SSL Certificate Management Tool
//

import SwiftUI

@main
struct AIOSSLToolApp: App {
    @StateObject private var updaterViewModel = UpdaterViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 750)
                .onAppear {
                    // Check for updates on app launch
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        updaterViewModel.checkForUpdatesInBackground()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
        }
    }
}
