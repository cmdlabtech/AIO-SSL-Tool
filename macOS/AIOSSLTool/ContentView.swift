//
//  ContentView.swift
//  AIO SSL Tool
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SSLToolViewModel()
    @State private var selectedTool: Tool? = .home
    
    enum Tool: String, CaseIterable, Identifiable {
        case home = "Home"
        case csrGenerator = "CSR Generator"
        case chainBuilder = "Chain Builder"
        case pfxGenerator = "PFX Generator"
        case keyExtractor = "Key Extractor"
        case settings = "Settings"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .csrGenerator: return "doc.badge.plus"
            case .chainBuilder: return "link.circle.fill"
            case .pfxGenerator: return "shippingbox.fill"
            case .keyExtractor: return "key.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Tool.allCases, selection: $selectedTool) { tool in
                NavigationLink(value: tool) {
                    Label(tool.rawValue, systemImage: tool.icon)
                        .padding(.vertical, 8)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
            .listStyle(.sidebar)
            .navigationTitle("SSL Suite")
        } detail: {
            Group {
                if let tool = selectedTool {
                    switch tool {
                    case .home:
                        HomeView(viewModel: viewModel)
                    case .csrGenerator:
                        CSRGenerationView(viewModel: viewModel)
                    case .chainBuilder:
                        ChainBuilderView(viewModel: viewModel)
                    case .pfxGenerator:
                        PFXGeneratorView(viewModel: viewModel)
                    case .keyExtractor:
                        ExtractPFXView(viewModel: viewModel)
                    case .settings:
                        SettingsView()
                    }
                } else {
                    ContentUnavailableView("Select a Tool", systemImage: "wrench.and.screwdriver")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 900, minHeight: 750)
    }
}
