//
//  AIOSSLToolApp.swift
//  CMDLAB AIO SSL Tool
//
//  Modern macOS SSL Certificate Management Tool
//

import SwiftUI

@main
struct AIOSSLToolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 750)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}
