//
//  SSLToolViewModel.swift
//  AIO SSL Tool
//

import SwiftUI
import Combine
import Security
import CryptoKit

@MainActor
class SSLToolViewModel: ObservableObject {
    @Published var saveDirectory: URL?
    @Published var certificateFile: URL?
    @Published var privateKeyFile: URL?
    @Published var keyPassphrase: String = ""
    @Published var pfxPassphrase: String = ""
    @Published var statusMessage: String = "Ready"
    @Published var isBuilding: Bool = false
    @Published var fullChainCreated: Bool = false
    @Published var pfxCreated: Bool = false
    @Published var hasError: Bool = false
    @Published var showingError: Bool = false
    @Published var showingSuccess: Bool = false
    @Published var errorMessage: String = ""
    @Published var successMessage: String = ""
    @Published var workingDirectoryFiles: [URL] = []
    
    var canCreatePFX: Bool {
        privateKeyFile != nil && fullChainCreated && !pfxPassphrase.isEmpty
    }
    
    func selectSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Save Location"
        
        if panel.runModal() == .OK {
            saveDirectory = panel.url
            statusMessage = "Save location set"
            hasError = false
            loadWorkingDirectoryFiles()
        }
    }
    
    func loadWorkingDirectoryFiles() {
        guard let directory = saveDirectory else {
            workingDirectoryFiles = []
            return
        }
        
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            
            // Filter for certificate files (common extensions)
            let certificateExtensions = ["cer", "crt", "pem", "der", "cert", "key", "pfx", "p12", "p7b"]
            workingDirectoryFiles = files.filter { url in
                let pathExtension = url.pathExtension.lowercased()
                return certificateExtensions.contains(pathExtension)
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            workingDirectoryFiles = []
            print("Error loading directory files: \(error)")
        }
    }
    
    func selectCertificateFromDirectory(_ url: URL) {
        certificateFile = url
        statusMessage = "Certificate loaded"
        hasError = false
    }
    
    func browseCertificate() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.x509Certificate, .data]
        panel.allowsOtherFileTypes = true
        panel.prompt = "Select Certificate"
        
        if panel.runModal() == .OK {
            certificateFile = panel.url
            statusMessage = "Certificate loaded"
            hasError = false
        }
    }
    
    func browsePrivateKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.prompt = "Select Private Key"
        panel.allowedContentTypes = [.data]
        
        if panel.runModal() == .OK {
            privateKeyFile = panel.url
            statusMessage = "Private key selected"
            hasError = false
        }
    }
    
    func createFullChain() {
        guard let certFile = certificateFile,
              let saveDir = saveDirectory else {
            showError("Missing certificate or save location")
            return
        }
        
        isBuilding = true
        statusMessage = "Building certificate chain..."
        
        Task {
            do {
                let certData = try Data(contentsOf: certFile)
                let certificates = try CertificateUtils.loadCertificates(from: certData)
                
                guard !certificates.isEmpty else {
                    throw SSLError.noCertificateFound
                }
                
                // Build chain by fetching issuers from system keychain
                var chain = certificates
                var current = chain.last!
                
                while !CertificateUtils.isSelfSigned(current) {
                    if let issuer = try? CertificateUtils.fetchIssuerFromKeychain(for: current) {
                        if !chain.contains(where: { CertificateUtils.certificatesMatch($0, issuer) }) {
                            chain.append(issuer)
                            current = issuer
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                
                // Save full chain
                let chainData = chain.map { $0.pemRepresentation }.joined(separator: "\n")
                let chainPath = saveDir.appendingPathComponent("FullChain.cer")
                try chainData.write(to: chainPath, atomically: true, encoding: .utf8)
                
                fullChainCreated = true
                statusMessage = "Full chain saved: FullChain.cer"
                isBuilding = false
                hasError = false
                
                // Archive: use first cert's subject as domain
                let domain = chain.first?.subject
                archiveFiles([chainPath], domain: domain)
            } catch {
                showError("Failed to build chain: \(error.localizedDescription)")
                isBuilding = false
            }
        }
    }
    
    func createPFX(options: PFXOptions = PFXOptions()) {
        guard let privateKey = privateKeyFile,
              let saveDir = saveDirectory,
              !pfxPassphrase.isEmpty else {
            showError("Missing private key, save location, or PFX password")
            return
        }
        
        Task {
            do {
                let chainPath = saveDir.appendingPathComponent("FullChain.cer")
                let chainData = try Data(contentsOf: chainPath)
                let certificates = try CertificateUtils.loadCertificates(from: chainData)
                
                let keyData = try Data(contentsOf: privateKey)
                
                let pfxData = try CertificateUtils.createPFX(
                    certificates: certificates,
                    privateKeyData: keyData,
                    keyPassword: keyPassphrase.isEmpty ? nil : keyPassphrase,
                    pfxPassword: pfxPassphrase,
                    options: options
                )
                
                let pfxPath = saveDir.appendingPathComponent("FullChain-pfx.pfx")
                try pfxData.write(to: pfxPath)
                
                pfxCreated = true
                statusMessage = "PFX created: FullChain-pfx.pfx"
                showSuccess("PFX file created successfully!")
                
                // Archive: use first cert's subject as domain
                let domain = certificates.first?.subject
                archiveFiles([pfxPath], domain: domain)
            } catch {
                showError("Failed to create PFX: \(error.localizedDescription)")
            }
        }
    }
    
    func generateCSR(details: CSRDetails) {
        guard let saveDir = saveDirectory else {
            showError("Save directory not set")
            return
        }
        
        Task {
            do {
                let (csr, privateKey) = try CertificateUtils.generateCSR(details: details)
                
                let csrPath = saveDir.appendingPathComponent("csr.pem")
                let keyPath = saveDir.appendingPathComponent("private_key.pem")
                
                try csr.write(to: csrPath, atomically: true, encoding: .utf8)
                try privateKey.write(to: keyPath, atomically: true, encoding: .utf8)
                
                privateKeyFile = keyPath
                keyPassphrase = details.keyPassword ?? ""
                statusMessage = "CSR + Key generated"
                showSuccess("CSR and private key generated successfully!")
                
                // Archive CSR + key using commonName as domain
                let domain = details.commonName.isEmpty ? nil : details.commonName
                archiveFiles([csrPath, keyPath], domain: domain)
                
                // Check if full chain exists to enable PFX creation
                let chainPath = saveDir.appendingPathComponent("FullChain.cer")
                if FileManager.default.fileExists(atPath: chainPath.path) {
                    fullChainCreated = true
                }
            } catch {
                showError("Failed to generate CSR: \(error.localizedDescription)")
            }
        }
    }
    
    func extractPrivateKey(pfxPath: URL, password: String, savePath: URL) {
        Task {
            do {
                let pfxData = try Data(contentsOf: pfxPath)
                let privateKeyPEM = try CertificateUtils.extractPrivateKey(
                    from: pfxData,
                    password: password
                )
                
                try privateKeyPEM.write(to: savePath, atomically: true, encoding: .utf8)
                showSuccess("Private key extracted successfully!")
            } catch {
                showError("Failed to extract private key: \(error.localizedDescription)")
            }
        }
    }
    
    func showError(_ message: String) {
        errorMessage = message
        statusMessage = "Error"
        hasError = true
        showingError = true
    }
    
    func showSuccess(_ message: String) {
        successMessage = message
        showingSuccess = true
    }
    
    // MARK: - Certificate Archive
    
    /// Archives generated files to .archive/{domain}/{timestamp}/ inside the working directory.
    /// Subdomains are nested under their root domain (e.g., .archive/example.com/sub.example.com/2026-02-21_143022/).
    func archiveFiles(_ filePaths: [URL], domain: String?) {
        guard let saveDir = saveDirectory,
              UserDefaults.standard.bool(forKey: "EnableCertificateArchive") else { return }
        
        let fileManager = FileManager.default
        let timestamp = Self.archiveTimestamp()
        let domainPath = Self.archiveDomainPath(for: domain)
        
        let folderName = (UserDefaults.standard.object(forKey: "HideArchiveFolder") as? Bool ?? true) ? ".archive" : "archive"
        let archiveDir = saveDir
            .appendingPathComponent(folderName)
            .appendingPathComponent(domainPath)
            .appendingPathComponent(timestamp)
        
        do {
            try fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)
            
            for file in filePaths where fileManager.fileExists(atPath: file.path) {
                let dest = archiveDir.appendingPathComponent(file.lastPathComponent)
                try fileManager.copyItem(at: file, to: dest)
            }
        } catch {
            print("Archive error: \(error.localizedDescription)")
        }
    }
    
    /// Returns a timestamp string for archive folder names (e.g., "2026-02-21_143022").
    static func archiveTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: Date())
    }
    
    /// Determines archive path from a domain string.
    /// - "example.com" → "example.com"
    /// - "sub.example.com" → "example.com/sub.example.com"
    /// - "deep.sub.example.com" → "example.com/deep.sub.example.com"
    /// - nil/empty/wildcard → "unknown"
    static func archiveDomainPath(for domain: String?) -> String {
        guard var clean = domain?.trimmingCharacters(in: .whitespaces),
              !clean.isEmpty else { return "unknown" }
        
        // Strip wildcard prefix (*.example.com → example.com)
        if clean.hasPrefix("*.") {
            clean = String(clean.dropFirst(2))
        }
        
        let parts = clean.lowercased().split(separator: ".")
        
        // If it's a root domain (2 parts like example.com) or single label
        if parts.count <= 2 {
            return clean.lowercased()
        }
        
        // Subdomain: extract root (last 2 parts) and nest subdomain under it
        let root = parts.suffix(2).joined(separator: ".")
        return "\(root)/\(clean.lowercased())"
    }
}

enum SSLError: LocalizedError {
    case noCertificateFound
    case invalidCertificate
    case chainBuildFailed
    case pfxCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .noCertificateFound:
            return "No valid certificate found in file"
        case .invalidCertificate:
            return "Invalid or corrupted certificate"
        case .chainBuildFailed:
            return "Failed to build certificate chain"
        case .pfxCreationFailed:
            return "Failed to create PFX file"
        }
    }
}
