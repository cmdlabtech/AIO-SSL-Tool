//
//  ChainBuilderView.swift
//  AIO SSL Tool
//

import SwiftUI

struct ChainBuilderView: View {
    @ObservedObject var viewModel: SSLToolViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                VStack(alignment: .leading) {
                    Text("Chain Builder")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Build complete certificate chains and create PFX files")
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Working Directory Indicator
                HStack {
                    Image(systemName: "folder")
                    if let path = viewModel.saveDirectory?.path {
                        Text(shortenPath(path))
                            .font(.caption)
                            .monospaced()
                    } else {
                        Text("No Save Location Set")
                            .font(.caption)
                            .italic()
                    }
                }
                .padding(8)
                .background(.regularMaterial)
                .cornerRadius(8)
            }
            .padding()
            .background(.thinMaterial)
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    if viewModel.saveDirectory == nil {
                        ContentUnavailableView {
                            Label("Select working directory", systemImage: "folder.badge.plus")
                        } description: {
                            Text("Start by choosing where to save your certificates.")
                            Button("Select Directory", action: { viewModel.selectSaveDirectory() })
                                .buttonStyle(.borderedProminent)
                                .padding(.top)
                        }
                        .frame(height: 300)
                    } else {
                        // Main Workflow Card
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            
                            // Input Card
                            WorkflowCard(title: "Certificate", icon: "certificate", color: .blue) {
                                VStack(alignment: .leading, spacing: 10) {
                                    if let cert = viewModel.certificateFile {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text(cert.lastPathComponent)
                                                .font(.headline)
                                        }
                                        Text("Loaded")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Button(action: { viewModel.browseCertificate() }) {
                                            VStack {
                                                Image(systemName: "arrow.up.doc")
                                                    .font(.largeTitle)
                                                Text("Select Certificate")
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 100)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // Chain Status Card
                            WorkflowCard(title: "Chain Status", icon: "link", color: .orange) {
                                VStack {
                                    if viewModel.fullChainCreated {
                                        HStack {
                                            Image(systemName: "checkmark.shield.fill")
                                                .font(.largeTitle)
                                                .foregroundColor(.green)
                                            VStack(alignment: .leading) {
                                                Text("Chain Built")
                                                    .font(.headline)
                                                Text("FullChain.cer ready")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 100)
                                    } else {
                                        if viewModel.isBuilding {
                                            ProgressView("Building Chain...")
                                        } else {
                                            Button("Build Full Chain") {
                                                viewModel.createFullChain()
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(viewModel.certificateFile == nil)
                                            .controlSize(.large)
                                        }
                                    }
                                }
                            }
                            
                            // Private Key Card
                            WorkflowCard(title: "Private Key", icon: "key", color: .purple) {
                                VStack(alignment: .leading) {
                                    if let key = viewModel.privateKeyFile {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text(key.lastPathComponent)
                                                .font(.headline)
                                        }
                                        SecureField("Key Passphrase (Optional)", text: $viewModel.keyPassphrase)
                                            .textFieldStyle(.roundedBorder)
                                    } else {
                                        Button(action: { viewModel.browsePrivateKey() }) {
                                            VStack {
                                                Image(systemName: "lock.doc")
                                                    .font(.largeTitle)
                                                Text("Select Private Key")
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 80)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    if viewModel.privateKeyFile != nil {
                                        Button("Change") { viewModel.browsePrivateKey() }
                                            .font(.caption)
                                            .buttonStyle(.link)
                                    }
                                }
                            }
                            
                            // Output PFX Card
                            WorkflowCard(title: "Output PFX", icon: "shippingbox.fill", color: .pink) {
                                VStack(spacing: 12) {
                                    SecureField("PFX Password (Required)", text: $viewModel.pfxPassphrase)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    Button(action: { viewModel.createPFX() }) {
                                        Label("Create PFX File", systemImage: "sparkles")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!viewModel.canCreatePFX)
                                    .controlSize(.large)
                                    
                                    if viewModel.pfxCreated {
                                        Text("PFX Created Successfully!")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                            .bold()
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    func shortenPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 2 {
            return ".../" + components.suffix(2).joined(separator: "/")
        }
        return path
    }
}

struct WorkflowCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 4)
            
            content
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}
