//
//  ExtractPFXView.swift
//  AIO SSL Tool
//

import SwiftUI

struct ExtractPFXView: View {
    @ObservedObject var viewModel: SSLToolViewModel
    
    @State private var pfxPath: URL?
    @State private var password = ""
    @State private var savePath: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Key Extractor")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Extract private keys from PFX/P12 files")
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: clearFields) {
                    Text("Clear")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(pfxPath == nil && savePath == nil && password.isEmpty)
            }
            .padding()
            .background(.thinMaterial)
            
            ScrollView {
                VStack(spacing: 30) {
                    
                    // Input Card
                    VStack(spacing: 16) {
                        Image(systemName: "lock.doc.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Source PFX File")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Button(action: selectPFXFile) {
                            HStack {
                                if let pfx = pfxPath {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(pfx.lastPathComponent)
                                } else {
                                    Text("Select .pfx or .p12 file")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        SecureField("PFX Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    Image(systemName: "arrow.down")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    // Output Card
                    VStack(spacing: 16) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        Text("Destination Private Key")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Button(action: selectSaveLocation) {
                            HStack {
                                if let save = savePath {
                                    Image(systemName: "folder.fill")
                                    Text(save.path)
                                        .truncationMode(.middle)
                                } else {
                                    Text("Choose Output Location")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    Button(action: extractKey) {
                        Label("Extract Private Key", systemImage: "arrow.right.circle.fill")
                            .font(.title3)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(pfxPath == nil || password.isEmpty || savePath == nil)
                    .padding(.top)
                }
                .padding(40)
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Success", isPresented: $viewModel.showingSuccess) {
            Button("OK") { }
        } message: {
            Text(viewModel.successMessage)
        }
    }
    
    private func selectPFXFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select PFX/P12 File"
        panel.allowedContentTypes = [.data]
        panel.allowsOtherFileTypes = true
        
        if panel.runModal() == .OK {
            pfxPath = panel.url
        }
    }
    
    private func selectSaveLocation() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "private_key.pem"
        panel.prompt = "Save Private Key"
        
        if let saveDir = viewModel.saveDirectory {
            panel.directoryURL = saveDir
        }
        
        if panel.runModal() == .OK {
            savePath = panel.url
        }
    }
    
    private func extractKey() {
        guard let pfx = pfxPath, let save = savePath else { return }
        viewModel.extractPrivateKey(pfxPath: pfx, password: password, savePath: save)
    }
    
    private func clearFields() {
        pfxPath = nil
        password = ""
        savePath = nil
    }
    
    // Helper for dashed border
    func strokeBorder(col: Color, style: StrokeStyle) -> some ShapeStyle {
        return col
    }
}
