//
//  PrivateCAChainView.swift
//  AIO SSL Tool
//

import SwiftUI
import UniformTypeIdentifiers

struct PrivateCAChainView: View {
    @ObservedObject var viewModel: SSLToolViewModel

    @State private var serverCertURL: URL?
    @State private var subCAURLs: [URL?] = [nil]
    @State private var rootCAURL: URL?
    @State private var serverCertTargeted = false
    @State private var subCATargeted: [Bool] = [false]
    @State private var rootCATargeted = false
    @State private var isBuilding = false
    @State private var buildError: String?
    @State private var showBuildError = false
    @State private var showBuildSuccess = false
    @State private var buildSuccessMessage = ""
    @State private var showInfoPopover = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    HStack(spacing: 8) {
                        Text("Private CA Chain")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                            .imageScale(.medium)
                            .onHover { hovering in showInfoPopover = hovering }
                            .popover(isPresented: $showInfoPopover, arrowEdge: .bottom) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Output: FullChain.cer")
                                        .fontWeight(.semibold)
                                    Text("Files are concatenated in order:\nServer Certificate → Sub CA(s) → Root CA.\nThe result is saved to your working directory.")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                .frame(maxWidth: 320)
                            }
                    }
                    Text("Assemble a full-chain certificate from local CA files")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.thinMaterial)

            ScrollView {
                if viewModel.saveDirectory == nil {
                    ContentUnavailableView(
                        "Save Location Required",
                        systemImage: "folder.badge.plus",
                        description: Text("Please select a save location in the Chain Builder tool first.")
                    )
                    .padding(.top, 50)
                } else {
                    VStack(alignment: .leading, spacing: 20) {

                        GroupBox(label: Label("Certificate Files", systemImage: "doc.on.doc.fill")) {
                            VStack(spacing: 16) {
                                CertFileDropRow(
                                    title: "Server Certificate",
                                    subtitle: "The end-entity certificate (required)",
                                    isOptional: false,
                                    fileURL: $serverCertURL,
                                    isTargeted: $serverCertTargeted
                                )

                                ForEach(Array(subCAURLs.enumerated()), id: \.offset) { index, _ in
                                    Divider()
                                    CertFileDropRow(
                                        title: subCAURLs.count == 1 ? "Subordinate CA" : "Sub CA \(index + 1)",
                                        subtitle: "Intermediate / sub-CA certificate — omit if not applicable",
                                        isOptional: true,
                                        onRemove: subCAURLs.count > 1 ? {
                                            subCAURLs.remove(at: index)
                                            subCATargeted.remove(at: index)
                                        } : nil,
                                        fileURL: Binding(
                                            get: { subCAURLs[index] },
                                            set: { subCAURLs[index] = $0 }
                                        ),
                                        isTargeted: Binding(
                                            get: { subCATargeted[index] },
                                            set: { subCATargeted[index] = $0 }
                                        )
                                    )
                                }

                                // Add Sub CA button (up to 3 sub CAs)
                                if subCAURLs.count < 3 {
                                    HStack(spacing: 12) {
                                        Color.clear.frame(width: 210)
                                        Spacer()
                                        Button(action: {
                                            subCAURLs.append(nil)
                                            subCATargeted.append(false)
                                        }) {
                                            Label("Add Sub CA", systemImage: "plus.circle.fill")
                                                .font(.callout)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.green)
                                        Spacer()
                                        Color.clear.frame(width: 88) // Browse + spacing + remove placeholder
                                    }
                                }

                                Divider()
                                CertFileDropRow(
                                    title: "Root CA",
                                    subtitle: "Root certificate authority (required)",
                                    isOptional: false,
                                    fileURL: $rootCAURL,
                                    isTargeted: $rootCATargeted
                                )
                            }
                            .padding()
                        }

                        HStack {
                            Spacer()
                            if isBuilding {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Button(action: buildChain) {
                                Label("Build Full Chain", systemImage: "link.badge.plus")
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(serverCertURL == nil || rootCAURL == nil || isBuilding)
                        }
                        .padding(.top)
                    }
                    .padding()
                }
            }
        }
        .alert("Error", isPresented: $showBuildError) {
            Button("OK") { }
        } message: {
            Text(buildError ?? "")
        }
        .alert("Success", isPresented: $showBuildSuccess) {
            Button("OK") {
                serverCertURL = nil
                subCAURLs = [nil]
                subCATargeted = [false]
                rootCAURL = nil
            }
        } message: {
            Text(buildSuccessMessage)
        }
    }

    private func buildChain() {
        guard let serverCert = serverCertURL,
              let rootCA = rootCAURL,
              let saveDir = viewModel.saveDirectory else { return }

        isBuilding = true

        Task {
            do {
                var pem = try String(contentsOf: serverCert, encoding: .utf8)
                if !pem.hasSuffix("\n") { pem += "\n" }

                for subCAURL in subCAURLs {
                    if let subCA = subCAURL {
                        var subPEM = try String(contentsOf: subCA, encoding: .utf8)
                        if !subPEM.hasSuffix("\n") { subPEM += "\n" }
                        pem += subPEM
                    }
                }

                var rootPEM = try String(contentsOf: rootCA, encoding: .utf8)
                if !rootPEM.hasSuffix("\n") { rootPEM += "\n" }
                pem += rootPEM

                let outputURL = saveDir.appendingPathComponent("FullChain.cer")
                try pem.write(to: outputURL, atomically: true, encoding: .utf8)

                viewModel.archiveFiles([outputURL], domain: nil)

                await MainActor.run {
                    isBuilding = false
                    buildSuccessMessage = "Full chain saved to:\n\(outputURL.path)"
                    showBuildSuccess = true
                }
            } catch {
                await MainActor.run {
                    isBuilding = false
                    buildError = error.localizedDescription
                    showBuildError = true
                }
            }
        }
    }
}

struct CertFileDropRow: View {
    let title: String
    let subtitle: String
    let isOptional: Bool
    var onRemove: (() -> Void)? = nil
    @Binding var fileURL: URL?
    @Binding var isTargeted: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .fontWeight(.semibold)
                    if isOptional {
                        Text("Optional")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 210, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [5])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isTargeted ? Color.accentColor.opacity(0.07) : Color.clear)
                    )

                if let url = fileURL {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.accentColor)
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button(action: { fileURL = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc")
                            .foregroundColor(.secondary)
                        Text("Drop file here")
                            .foregroundColor(.secondary)
                            .font(.callout)
                    }
                }
            }
            .frame(height: 44)
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        if let data = item as? Data,
                           let url = URL(dataRepresentation: data, relativeTo: nil) {
                            fileURL = url
                        }
                    }
                }
                return true
            }

            // Trailing buttons — fixed layout so all drop zones align
            HStack(spacing: 6) {
                Button("Browse") {
                    browseFile()
                }
                .controlSize(.small)

                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Invisible placeholder keeps drop zone width consistent
                    Color.clear.frame(width: 20)
                }
            }
        }
    }

    private func browseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select \(title)"
        panel.allowedContentTypes = [.x509Certificate, .data]
        panel.allowsOtherFileTypes = true
        panel.message = "Select a certificate file (PEM or DER format)"

        if panel.runModal() == .OK {
            fileURL = panel.url
        }
    }
}
