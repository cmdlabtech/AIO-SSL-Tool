//
//  ClearPassView.swift
//  AIO SSL Tool
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ClearPass Models

struct ClearPassServer: Identifiable {
    let id: String   // UUID from API
    let name: String
    var isSelected: Bool = false
}

struct ClearPassCertInfo: Identifiable {
    let id = UUID()
    let serverUUID: String
    let serverName: String
    let subject: String
    let issuedBy: String
    let expiryDate: String
    let service: String

    /// Parses expiry into a Date for colour-coding (supports "YYYY-MM-DD HH:mm:ss" and "YYYY-MM-DD").
    var expiryParsed: Date? {
        let fmts = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "MM/dd/yyyy"]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in fmts {
            df.dateFormat = fmt
            if let d = df.date(from: expiryDate) { return d }
        }
        return nil
    }

    var daysUntilExpiry: Int? {
        guard let exp = expiryParsed else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: exp).day
    }

    var statusColor: Color {
        guard let days = daysUntilExpiry else { return .secondary }
        if days < 0 { return .red }
        if days < 30 { return .orange }
        return .green
    }

    var statusLabel: String {
        guard let days = daysUntilExpiry else { return expiryDate }
        if days < 0 { return "Expired \(abs(days))d ago" }
        if days == 0 { return "Expires today" }
        return "Expires in \(days)d"
    }
}

// MARK: - ClearPass View

struct ClearPassView: View {
    @ObservedObject var viewModel: SSLToolViewModel

    // Connection
    @State private var host = ""
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var verifySSL = true

    // Certificate
    @State private var pfxURL: URL?
    @State private var pfxPassphrase = ""
    @State private var pfxTargeted = false
    @State private var selectedService = "HTTPS(RSA)"
    let services = ["HTTPS(RSA)", "HTTP(ECC)", "RADIUS", "RadSec", "Database"]

    // Network interface for file serving
    @State private var availableIPs: [(iface: String, ip: String)] = []
    @State private var selectedIP = ""

    // Servers
    @State private var servers: [ClearPassServer] = []
    @State private var selectAll = false

    // Inspect
    @State private var inspectService = "HTTPS(RSA)"

    // State
    @State private var isConnecting = false
    @State private var isUploading = false
    @State private var isFetchingCerts = false
    @State private var accessToken: String?
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var uploadResults: [String] = []
    @State private var currentCerts: [ClearPassCertInfo] = []
    @State private var errorMessage = ""

    enum ConnectionStatus {
        case idle, connecting, connected, failed
        var label: String {
            switch self {
            case .idle: return ""
            case .connecting: return "Connecting…"
            case .connected: return "Connected"
            case .failed: return "Connection failed"
            }
        }
        var color: Color {
            switch self {
            case .idle: return .secondary
            case .connecting: return .yellow
            case .connected: return .green
            case .failed: return .red
            }
        }
    }

    var selectedServers: [ClearPassServer] {
        servers.filter { $0.isSelected }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("ClearPass")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Upload and replace certificates on Aruba ClearPass via REST API")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.thinMaterial)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Connection & Target Servers (merged)
                    GroupBox(label: Label("Connection & Target Servers", systemImage: "network")) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("ClearPass Host:")
                                    .frame(width: 150, alignment: .leading)
                                TextField("clearpass.example.com or IP address", text: $host)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            }
                            HStack {
                                Text("API Client ID:")
                                    .frame(width: 150, alignment: .leading)
                                TextField("API client ID", text: $clientID)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            }
                            HStack {
                                Text("Client Secret:")
                                    .frame(width: 150, alignment: .leading)
                                SecureField("API client secret", text: $clientSecret)
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack {
                                Toggle("Verify SSL Certificate", isOn: $verifySSL)
                                    .frame(width: 220, alignment: .leading)
                                Spacer()
                                if connectionStatus != .idle {
                                    HStack(spacing: 6) {
                                        if connectionStatus == .connecting {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Circle()
                                                .fill(connectionStatus.color)
                                                .frame(width: 8, height: 8)
                                        }
                                        Text(connectionStatus.label)
                                            .font(.callout)
                                            .foregroundColor(connectionStatus.color)
                                    }
                                }
                            }
                            if connectionStatus == .failed && !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.red.opacity(0.08))
                                    .cornerRadius(6)
                            }
                            HStack {
                                Spacer()
                                Button(action: connectAndDiscover) {
                                    Label("Connect & Discover Servers", systemImage: "antenna.radiowaves.left.and.right")
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(host.isEmpty || clientID.isEmpty || clientSecret.isEmpty || isConnecting)
                            }

                            if !servers.isEmpty {
                                Divider()
                                VStack(spacing: 0) {
                                    HStack {
                                        Toggle("Select All", isOn: $selectAll)
                                            .onChange(of: selectAll) { _, newVal in
                                                for i in servers.indices { servers[i].isSelected = newVal }
                                            }
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 4)

                                    Divider().padding(.vertical, 4)

                                    ForEach($servers) { $server in
                                        HStack {
                                            Toggle("", isOn: $server.isSelected)
                                                .labelsHidden()
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(server.name).fontWeight(.medium)
                                                Text(server.id)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .monospaced()
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                        Divider()
                                    }
                                }
                            } else if accessToken != nil {
                                Text("No servers found in cluster.")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                    }

                    // Certificate Section
                    GroupBox(label: Label("Certificate (PFX/P12)", systemImage: "lock.doc.fill")) {
                        VStack(spacing: 12) {
                            // PFX file drop/browse row
                            HStack(spacing: 12) {
                                Text("PFX File:")
                                    .frame(width: 150, alignment: .leading)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            pfxTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                                            style: StrokeStyle(lineWidth: pfxTargeted ? 2 : 1, dash: [5])
                                        )
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(pfxTargeted ? Color.accentColor.opacity(0.07) : Color.clear)
                                        )
                                    if let url = pfxURL {
                                        HStack {
                                            Image(systemName: "doc.fill").foregroundColor(.accentColor)
                                            Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                            Spacer()
                                            Button(action: { pfxURL = nil }) {
                                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                            }.buttonStyle(.plain)
                                        }.padding(.horizontal, 10)
                                    } else {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.down.doc").foregroundColor(.secondary)
                                            Text("Drop PFX file here").foregroundColor(.secondary).font(.callout)
                                        }
                                    }
                                }
                                .frame(height: 40)
                                .onDrop(of: [UTType.fileURL], isTargeted: $pfxTargeted) { providers in
                                    guard let provider = providers.first else { return false }
                                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                                        DispatchQueue.main.async {
                                            if let data = item as? Data,
                                               let url = URL(dataRepresentation: data, relativeTo: nil) {
                                                pfxURL = url
                                            }
                                        }
                                    }
                                    return true
                                }
                                Button("Browse") { browsePFX() }.controlSize(.small)
                            }

                            HStack {
                                Text("PFX Passphrase:")
                                    .frame(width: 150, alignment: .leading)
                                SecureField("Password protecting the PFX file", text: $pfxPassphrase)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Service:")
                                    .frame(width: 150, alignment: .leading)
                                Picker("Service", selection: $selectedService) {
                                    ForEach(services, id: \.self) { s in Text(s).tag(s) }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            HStack {
                                Text("Upload Interface:")
                                    .frame(width: 150, alignment: .leading)
                                if availableIPs.isEmpty {
                                    Text("Click refresh to detect")
                                        .foregroundColor(.secondary)
                                        .font(.callout)
                                } else {
                                    Picker("Interface", selection: $selectedIP) {
                                        ForEach(availableIPs, id: \.ip) { item in
                                            Text("\(item.iface) — \(item.ip)").tag(item.ip)
                                        }
                                    }
                                    .labelsHidden()
                                    .fixedSize()
                                }
                                Button(action: refreshInterfaces) {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Refresh network interfaces")
                                .padding(.leading, 6)
                                Spacer()
                            }
                        }
                        .padding()
                        .onAppear { refreshInterfaces() }
                    }

                    // Current Certificates Section
                    GroupBox(label: Label("Current Certificates", systemImage: "checkmark.shield.fill")) {
                        VStack(spacing: 0) {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Service:")
                                        .frame(width: 60, alignment: .leading)
                                    Picker("Service", selection: $inspectService) {
                                        ForEach(services, id: \.self) { s in Text(s).tag(s) }
                                    }
                                    .labelsHidden()
                                    .frame(width: 180)
                                    Spacer()
                                    if isFetchingCerts { ProgressView().controlSize(.small).padding(.trailing, 6) }
                                    Button(action: fetchCurrentCerts) {
                                        Label("Fetch", systemImage: "arrow.down.circle")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(servers.isEmpty || accessToken == nil || isFetchingCerts)
                                }
                                Text("Inspect and export the certificate currently installed on each server for the selected service.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()

                            if !currentCerts.isEmpty {
                                Divider()
                                ForEach(currentCerts) { cert in
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Circle()
                                                .fill(cert.statusColor)
                                                .frame(width: 10, height: 10)
                                                .padding(.top, 4)
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text(cert.serverName)
                                                        .fontWeight(.semibold)
                                                    Text("·")
                                                        .foregroundColor(.secondary)
                                                    Text(cert.service)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text(cert.statusLabel)
                                                        .font(.caption)
                                                        .foregroundColor(cert.statusColor)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(cert.statusColor.opacity(0.12))
                                                        .cornerRadius(4)
                                                }
                                                HStack(spacing: 4) {
                                                    Text("Subject:").fontWeight(.medium).font(.caption)
                                                    Text(cert.subject).font(.caption).monospaced()
                                                }
                                                .foregroundColor(.primary.opacity(0.85))
                                                HStack(spacing: 4) {
                                                    Text("Issuer:").fontWeight(.medium).font(.caption)
                                                    Text(cert.issuedBy).font(.caption).monospaced()
                                                }
                                                .foregroundColor(.secondary)
                                                HStack(spacing: 4) {
                                                    Text("Expires:").fontWeight(.medium).font(.caption)
                                                    Text(cert.expiryDate).font(.caption).monospaced()
                                                }
                                                .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 10)
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    // Upload Results
                    if !uploadResults.isEmpty {
                        GroupBox(label: Label("Upload Results", systemImage: "list.bullet.rectangle")) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(uploadResults, id: \.self) { result in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: result.hasPrefix("✓") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(result.hasPrefix("✓") ? .green : .red)
                                        Text(result)
                                            .font(.callout)
                                            .monospaced()
                                    }
                                }
                            }
                            .padding()
                        }
                    }

                    // Upload Button
                    HStack {
                        Spacer()
                        if isUploading {
                            ProgressView().padding(.trailing, 8)
                        }
                        Button(action: uploadCertificate) {
                            Label("Upload Certificate", systemImage: "arrow.up.circle.fill")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(
                            pfxURL == nil ||
                            selectedServers.isEmpty ||
                            accessToken == nil ||
                            isUploading
                        )
                    }
                    .padding(.top)
                }
                .padding()
            }
        }
    }

    // MARK: - Actions

    private func browsePFX() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select PFX File"
        panel.allowedContentTypes = [.data]
        panel.allowsOtherFileTypes = true
        panel.message = "Select a PFX or P12 certificate file"
        if let saveDir = viewModel.saveDirectory { panel.directoryURL = saveDir }
        if panel.runModal() == .OK { pfxURL = panel.url }
    }

    private func connectAndDiscover() {
        guard !host.isEmpty, !clientID.isEmpty, !clientSecret.isEmpty else { return }
        isConnecting = true
        connectionStatus = .connecting
        accessToken = nil
        servers = []
        uploadResults = []
        currentCerts = []

        Task {
            do {
                let token = try await fetchToken()
                let discovered = try await discoverServers(token: token)
                await MainActor.run {
                    accessToken = token
                    servers = discovered
                    isConnecting = false
                    connectionStatus = .connected
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    connectionStatus = .failed
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func uploadCertificate() {
        guard let token = accessToken,
              let pfxFile = pfxURL else { return }

        isUploading = true
        uploadResults = []

        Task {
            var results: [String] = []
            let targets = selectedServers

            // Copy PFX to temp directory and start Python HTTP server
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("aio-ssl-upload-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempFile = tempDir.appendingPathComponent("cert.pfx")
            do {
                try FileManager.default.copyItem(at: pfxFile, to: tempFile)
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = "Failed to prepare PFX file: \(error.localizedDescription)"
                    connectionStatus = .failed
                }
                return
            }

            let port = UInt16.random(in: 49152...65535)
            let serverProcess = Process()
            serverProcess.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            serverProcess.arguments = ["-m", "http.server", "\(port)", "--bind", "0.0.0.0", "--directory", tempDir.path]
            serverProcess.standardOutput = FileHandle.nullDevice
            serverProcess.standardError = FileHandle.nullDevice
            do {
                try serverProcess.run()
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = "Failed to start file server: \(error.localizedDescription)"
                    connectionStatus = .failed
                }
                try? FileManager.default.removeItem(at: tempDir)
                return
            }

            // Wait for server to be ready
            try? await Task.sleep(nanoseconds: 500_000_000)

            defer {
                serverProcess.terminate()
                try? FileManager.default.removeItem(at: tempDir)
            }

            let localIP = selectedIP.isEmpty ? (getLocalIPAddress() ?? "127.0.0.1") : selectedIP
            let pfxURLString = "http://\(localIP):\(port)/cert.pfx"

            // Self-test: verify our HTTP server is reachable
            do {
                let testURL = URL(string: pfxURLString)!
                let (testData, _) = try await URLSession.shared.data(from: testURL)
                if testData.isEmpty {
                    results.append("⚠ File server self-test: server returned empty data")
                } else {
                    results.append("✓ File server OK — serving \(testData.count) bytes at \(pfxURLString)")
                }
            } catch {
                results.append("✗ File server unreachable at \(pfxURLString): \(error.localizedDescription)")
                results.append("⚠ ClearPass must be able to reach this URL to download the certificate")
                await MainActor.run {
                    uploadResults = results
                    isUploading = false
                }
                return
            }

            for server in targets {
                do {
                    try await replaceCert(
                        token: token,
                        serverUUID: server.id,
                        service: selectedService,
                        pfxURLString: pfxURLString,
                        passphrase: pfxPassphrase
                    )
                    results.append("✓ \(server.name): certificate updated successfully")
                } catch {
                    results.append("✗ \(server.name): \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                uploadResults = results
                isUploading = false
            }
        }
    }

    private func fetchCurrentCerts() {
        guard let token = accessToken, !servers.isEmpty else { return }
        isFetchingCerts = true
        currentCerts = []
        let svc = inspectService

        Task {
            var results: [ClearPassCertInfo] = []
            for server in servers {
                do {
                    let info = try await fetchCertInfo(token: token, serverUUID: server.id, service: svc)
                    results.append(ClearPassCertInfo(
                        serverUUID: server.id,
                        serverName: server.name,
                        subject: info["subject"] ?? "—",
                        issuedBy: info["issued_by"] ?? "—",
                        expiryDate: info["expiry_date"] ?? "—",
                        service: svc
                    ))
                } catch {
                    results.append(ClearPassCertInfo(
                        serverUUID: server.id,
                        serverName: server.name,
                        subject: "Error: \(error.localizedDescription)",
                        issuedBy: "—",
                        expiryDate: "—",
                        service: svc
                    ))
                }
            }
            await MainActor.run {
                currentCerts = results
                isFetchingCerts = false
            }
        }
    }

    // MARK: - API Helpers

    private func baseURL() -> String {
        let h = host.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("http") { return h.hasSuffix("/") ? String(h.dropLast()) : h }
        return "https://\(h)"
    }

    private func urlSession() -> URLSession {
        if verifySSL { return URLSession.shared }
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: InsecureSSLDelegate(), delegateQueue: nil)
    }

    private func fetchToken() async throws -> String {
        let url = URL(string: "\(baseURL())/api/oauth")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "grant_type": "client_credentials",
            "client_id": clientID,
            "client_secret": clientSecret
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession().data(for: request)
        let http = response as? HTTPURLResponse
        let statusCode = http?.statusCode ?? 0
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let detail = body.isEmpty ? "HTTP \(statusCode)" : "HTTP \(statusCode): \(body.prefix(200))"
            throw ClearPassError.authFailed(detail)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["access_token"] as? String else {
            throw ClearPassError.authFailed("No access_token in response.")
        }
        return token
    }

    private func discoverServers(token: String) async throws -> [ClearPassServer] {
        let url = URL(string: "\(baseURL())/api/cluster/server")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession().data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            // Single-node deployment may not have cluster endpoint — return host as single server
            return [ClearPassServer(id: UUID().uuidString, name: host, isSelected: true)]
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["_embedded"] as? [String: Any]
        let serverList = items?["items"] as? [[String: Any]] ?? []

        if serverList.isEmpty {
            return [ClearPassServer(id: UUID().uuidString, name: host, isSelected: true)]
        }

        return serverList.compactMap { item -> ClearPassServer? in
            guard let uuid = item["server_uuid"] as? String ?? item["uuid"] as? String else { return nil }
            let name = item["name"] as? String ?? item["hostname"] as? String ?? uuid
            return ClearPassServer(id: uuid, name: name, isSelected: true)
        }
    }

    private func fetchCertInfo(token: String, serverUUID: String, service: String) async throws -> [String: String] {
        let encodedService = service.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? service
        let url = URL(string: "\(baseURL())/api/server-cert/name/\(serverUUID)/\(encodedService)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession().data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP error"
            throw ClearPassError.uploadFailed(msg)
        }
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        var result: [String: String] = [:]
        for key in ["subject", "issued_by", "expiry_date", "sha1_fingerprint", "serial_number"] {
            result[key] = json[key] as? String
        }
        // Capture service_id as the cert ID
        if let serviceId = json["service_id"] as? Int {
            result["id"] = String(serviceId)
        }
        return result
    }

    private func replaceCert(
        token: String,
        serverUUID: String,
        service: String,
        pfxURLString: String,
        passphrase: String
    ) async throws {
        let encodedService = service.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? service
        let url = URL(string: "\(baseURL())/api/server-cert/name/\(serverUUID)/\(encodedService)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: String] = [
            "pkcs12_file_url": pfxURLString,
            "pkcs12_passphrase": passphrase
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession().data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClearPassError.uploadFailed(msg)
        }
    }

    private func getLocalIPAddress() -> String? {
        return getAllLocalIPs().first?.ip
    }

    private func getAllLocalIPs() -> [(iface: String, ip: String)] {
        var results: [(iface: String, ip: String)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return results }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let ifa = ptr {
            let flags = Int32(ifa.pointee.ifa_flags)
            let addr = ifa.pointee.ifa_addr.pointee
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING),
               addr.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(ifa.pointee.ifa_addr, socklen_t(addr.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    let ifName = String(cString: ifa.pointee.ifa_name)
                    let ip = String(cString: hostname)
                    results.append((iface: ifName, ip: ip))
                }
            }
            ptr = ifa.pointee.ifa_next
        }
        return results
    }

    private func refreshInterfaces() {
        availableIPs = getAllLocalIPs()
        if !availableIPs.contains(where: { $0.ip == selectedIP }) {
            selectedIP = availableIPs.first?.ip ?? ""
        }
    }
}

// MARK: - Helpers

enum ClearPassError: LocalizedError {
    case authFailed(String)
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .authFailed(let m): return "Authentication Error: \(m)"
        case .uploadFailed(let m): return "Upload Error: \(m)"
        }
    }
}

class InsecureSSLDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}
