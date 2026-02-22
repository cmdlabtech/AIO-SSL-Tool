//
//  CertificateUtils.swift
//  AIO SSL Tool
//
//  Certificate management utilities using Security framework
//

import Foundation
import Security
import CryptoKit

struct Certificate {
    let secCertificate: SecCertificate
    let data: Data
    
    var pemRepresentation: String {
        let base64 = data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----"
    }
    
    var subject: String {
        if let summary = SecCertificateCopySubjectSummary(secCertificate) as String? {
            return summary
        }
        return ""
    }
}

enum CertificateUtils {
    
    // MARK: - Certificate Loading
    
    static func loadCertificates(from data: Data) throws -> [Certificate] {
        var certificates: [Certificate] = []
        
        // Try to load as PEM
        if let pemString = String(data: data, encoding: .utf8) {
            certificates = loadPEMCertificates(pemString)
        }
        
        // Try to load as DER if PEM failed
        if certificates.isEmpty {
            if let cert = loadDERCertificate(data) {
                certificates.append(cert)
            }
        }
        
        if certificates.isEmpty {
            throw SSLError.noCertificateFound
        }
        
        return certificates
    }
    
    private static func loadPEMCertificates(_ pemString: String) -> [Certificate] {
        var certificates: [Certificate] = []
        let pattern = "-----BEGIN CERTIFICATE-----([^-]+)-----END CERTIFICATE-----"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        
        let range = NSRange(pemString.startIndex..., in: pemString)
        let matches = regex.matches(in: pemString, range: range)
        
        for match in matches {
            if match.numberOfRanges >= 2,
               let base64Range = Range(match.range(at: 1), in: pemString) {
                let base64String = String(pemString[base64Range])
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                    .replacingOccurrences(of: " ", with: "")
                
                if let certData = Data(base64Encoded: base64String),
                   let secCert = SecCertificateCreateWithData(nil, certData as CFData) {
                    certificates.append(Certificate(secCertificate: secCert, data: certData))
                }
            }
        }
        
        return certificates
    }
    
    private static func loadDERCertificate(_ data: Data) -> Certificate? {
        if let secCert = SecCertificateCreateWithData(nil, data as CFData) {
            return Certificate(secCertificate: secCert, data: data)
        }
        return nil
    }
    
    // MARK: - Certificate Chain Building
    
    static func isSelfSigned(_ certificate: Certificate) -> Bool {
        let cert = certificate.secCertificate
        
        // Create a trust object
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        
        let status = SecTrustCreateWithCertificates(cert, policy, &trust)
        guard status == errSecSuccess, let trust = trust else {
            return false
        }
        
        // Try to get certificate values
        if let values = SecCertificateCopyValues(cert, nil, nil) as? [String: Any] {
            let issuer = values["Issuer"] as? String
            let subject = values["Subject"] as? String
            if let i = issuer, let s = subject {
                return i == s
            }
        }
        
        // Fallback: compare subject and issuer summaries
        if let subject = SecCertificateCopySubjectSummary(cert) as String?,
           let issuer = getIssuerSummary(cert) {
            return subject == issuer
        }
        
        return false
    }
    
    private static func getIssuerSummary(_ certificate: SecCertificate) -> String? {
        var error: Unmanaged<CFError>?
        guard let values = SecCertificateCopyValues(certificate, nil, &error) as? [String: Any] else {
            return nil
        }
        
        // Try to extract issuer common name
        if let issuerDict = values[kSecOIDX509V1IssuerName as String] as? [String: Any],
           let issuerValue = issuerDict[kSecPropertyKeyValue as String] as? [[String: Any]] {
            for item in issuerValue {
                if let label = item[kSecPropertyKeyLabel as String] as? String,
                   label.contains("CN") || label.contains("Common"),
                   let value = item[kSecPropertyKeyValue as String] as? String {
                    return value
                }
            }
        }
        
        return nil
    }
    
    static func fetchIssuerFromKeychain(for certificate: Certificate) throws -> Certificate? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let certificates = result as? [SecCertificate] else {
            return nil
        }
        
        // Look for matching issuer
        for secCert in certificates {
            if let certData = SecCertificateCopyData(secCert) as Data? {
                let candidate = Certificate(secCertificate: secCert, data: certData)
                
                if isIssuerOf(candidate, for: certificate) {
                    return candidate
                }
            }
        }
        
        return nil
    }
    
    static func isIssuerOf(_ issuer: Certificate, for certificate: Certificate) -> Bool {
        // Create trust with issuer as anchor
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        
        let status = SecTrustCreateWithCertificates(
            certificate.secCertificate,
            policy,
            &trust
        )
        
        guard status == errSecSuccess, let trust = trust else {
            return false
        }
        
        // Set issuer as anchor certificate
        SecTrustSetAnchorCertificates(trust, [issuer.secCertificate] as CFArray)
        
        // Evaluate trust
        var error: CFError?
        return SecTrustEvaluateWithError(trust, &error)
    }
    
    static func certificatesMatch(_ cert1: Certificate, _ cert2: Certificate) -> Bool {
        return cert1.data == cert2.data
    }
    
    // MARK: - CSR Generation
    
    /// Generate a Certificate Signing Request (CSR) and private key
    /// - Following RFC 2986 (PKCS #10) and RFC 5280 (X.509 PKI)
    /// - Supports RSA (2048-4096 bits) and ECC (P-256, P-384, P-521)
    /// - Uses SHA-256 signature algorithm per NIST SP 800-57
    /// - Optional AES-256 encryption for private keys
    /// - Implements proper key usage extensions per RFC 5280 Section 4.2.1.3
    static func generateCSR(details: CSRDetails) throws -> (csr: String, privateKey: String) {
        let tempDir = NSTemporaryDirectory()
        let uuid = UUID().uuidString
        let keyPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid).key")
        let csrPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid).csr")
        let configPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid).conf")
        
        defer {
            // Clean up temporary files
            try? FileManager.default.removeItem(atPath: keyPath)
            try? FileManager.default.removeItem(atPath: csrPath)
            try? FileManager.default.removeItem(atPath: configPath)
        }
        
        // Create OpenSSL config file for SANs
        let config = createOpenSSLConfig(details: details)
        try config.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)
        
        // Generate private key and CSR using OpenSSL
        if details.keyType == .rsa {
            try generateRSAKeyAndCSR(details: details, keyPath: keyPath, csrPath: csrPath, configPath: configPath)
        } else {
            try generateECCKeyAndCSR(details: details, keyPath: keyPath, csrPath: csrPath, configPath: configPath)
        }
        
        // Read generated CSR and private key
        guard let csrData = try? Data(contentsOf: URL(fileURLWithPath: csrPath)),
              let csrPEM = String(data: csrData, encoding: .utf8) else {
            throw NSError(
                domain: "CertificateUtils",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read generated CSR"]
            )
        }
        
        guard let keyData = try? Data(contentsOf: URL(fileURLWithPath: keyPath)),
              var keyPEM = String(data: keyData, encoding: .utf8) else {
            throw NSError(
                domain: "CertificateUtils",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read generated private key"]
            )
        }
        
        // Set secure file permissions on generated keys (0600)
        let keyURL = URL(fileURLWithPath: keyPath)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        
        // Encrypt private key if password is provided
        if let password = details.keyPassword, !password.isEmpty {
            keyPEM = try encryptPrivateKey(keyPEM: keyPEM, password: password, keyType: details.keyType)
        }
        
        return (csrPEM, keyPEM)
    }
    
    private static func generateRSAKeyAndCSR(details: CSRDetails, keyPath: String, csrPath: String, configPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        
        // Build subject DN
        var subject = ""
        if !details.country.isEmpty { subject += "/C=\(details.country)" }
        if !details.state.isEmpty { subject += "/ST=\(details.state)" }
        if !details.locality.isEmpty { subject += "/L=\(details.locality)" }
        if !details.organization.isEmpty { subject += "/O=\(details.organization)" }
        if !details.organizationalUnit.isEmpty { subject += "/OU=\(details.organizationalUnit)" }
        if !details.commonName.isEmpty { subject += "/CN=\(details.commonName)" }
        if !details.email.isEmpty { subject += "/emailAddress=\(details.email)" }
        
        var arguments = [
            "req",
            "-new",
            "-newkey", "rsa:\(details.keySize)",
            "-nodes",  // Don't encrypt the key (we'll do it separately if needed)
            "-sha256",  // Use SHA-256 signature algorithm (RFC 5280, NIST SP 800-57)
            "-keyout", keyPath,
            "-out", csrPath,
            "-subj", subject
        ]
        
        // Add config file if SANs are present
        if !details.sans.isEmpty {
            arguments.append(contentsOf: ["-config", configPath])
        }
        
        process.arguments = arguments
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw NSError(
                    domain: "CertificateUtils",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to generate RSA CSR: \(errorString)"]
                )
            }
        } catch let error as NSError where error.domain == "CertificateUtils" {
            throw error
        } catch {
            throw NSError(
                domain: "CertificateUtils",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to execute OpenSSL: \(error.localizedDescription)"]
            )
        }
    }
    
    private static func generateECCKeyAndCSR(details: CSRDetails, keyPath: String, csrPath: String, configPath: String) throws {
        // First, generate the ECC private key
        let keyGenProcess = Process()
        keyGenProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        keyGenProcess.arguments = [
            "ecparam",
            "-name", details.eccCurve.rawValue,
            "-genkey",
            "-noout",
            "-out", keyPath
        ]
        
        let keyErrorPipe = Pipe()
        keyGenProcess.standardError = keyErrorPipe
        keyGenProcess.standardOutput = Pipe()
        
        do {
            try keyGenProcess.run()
            keyGenProcess.waitUntilExit()
            
            if keyGenProcess.terminationStatus != 0 {
                let errorData = keyErrorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw NSError(
                    domain: "CertificateUtils",
                    code: Int(keyGenProcess.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to generate ECC key: \(errorString)"]
                )
            }
        } catch let error as NSError where error.domain == "CertificateUtils" {
            throw error
        } catch {
            throw NSError(
                domain: "CertificateUtils",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to execute OpenSSL for key generation: \(error.localizedDescription)"]
            )
        }
        
        // Now generate the CSR using the ECC key
        let csrProcess = Process()
        csrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        
        // Build subject DN
        var subject = ""
        if !details.country.isEmpty { subject += "/C=\(details.country)" }
        if !details.state.isEmpty { subject += "/ST=\(details.state)" }
        if !details.locality.isEmpty { subject += "/L=\(details.locality)" }
        if !details.organization.isEmpty { subject += "/O=\(details.organization)" }
        if !details.organizationalUnit.isEmpty { subject += "/OU=\(details.organizationalUnit)" }
        if !details.commonName.isEmpty { subject += "/CN=\(details.commonName)" }
        if !details.email.isEmpty { subject += "/emailAddress=\(details.email)" }
        
        var arguments = [
            "req",
            "-new",
            "-key", keyPath,
            "-sha256",  // Use SHA-256 signature algorithm (RFC 5280, NIST SP 800-57)
            "-out", csrPath,
            "-subj", subject
        ]
        
        // Add config file if SANs are present
        if !details.sans.isEmpty {
            arguments.append(contentsOf: ["-config", configPath])
        }
        
        csrProcess.arguments = arguments
        
        let csrErrorPipe = Pipe()
        csrProcess.standardError = csrErrorPipe
        csrProcess.standardOutput = Pipe()
        
        do {
            try csrProcess.run()
            csrProcess.waitUntilExit()
            
            if csrProcess.terminationStatus != 0 {
                let errorData = csrErrorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw NSError(
                    domain: "CertificateUtils",
                    code: Int(csrProcess.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to generate ECC CSR: \(errorString)"]
                )
            }
        } catch let error as NSError where error.domain == "CertificateUtils" {
            throw error
        } catch {
            throw NSError(
                domain: "CertificateUtils",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to execute OpenSSL for CSR generation: \(error.localizedDescription)"]
            )
        }
    }
    
    private static func createOpenSSLConfig(details: CSRDetails) -> String {
        var config = """
        [ req ]
        default_bits = \(details.keySize)
        distinguished_name = req_distinguished_name
        req_extensions = v3_req
        prompt = no
        
        [ req_distinguished_name ]
        """
        
        if !details.country.isEmpty { config += "\nC = \(details.country)" }
        if !details.state.isEmpty { config += "\nST = \(details.state)" }
        if !details.locality.isEmpty { config += "\nL = \(details.locality)" }
        if !details.organization.isEmpty { config += "\nO = \(details.organization)" }
        if !details.organizationalUnit.isEmpty { config += "\nOU = \(details.organizationalUnit)" }
        if !details.commonName.isEmpty { config += "\nCN = \(details.commonName)" }
        if !details.email.isEmpty { config += "\nemailAddress = \(details.email)" }
        
        config += """
        
        
        [ v3_req ]
        basicConstraints = CA:FALSE
        keyUsage = critical, digitalSignature, keyEncipherment
        extendedKeyUsage = serverAuth, clientAuth
        """
        
        if !details.sans.isEmpty {
            config += "\nsubjectAltName = @alt_names\n\n[ alt_names ]\n"
            for (index, san) in details.sans.enumerated() {
                let prefix = Self.isIPAddress(san) ? "IP" : "DNS"
                config += "\(prefix).\(index + 1) = \(san)\n"
            }
        }
        
        return config
    }
    
    private static func isIPAddress(_ san: String) -> Bool {
        let trimmed = san.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // IPv4 pattern
        let ipv4Pattern = #"^(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$"#
        if NSPredicate(format: "SELF MATCHES %@", ipv4Pattern).evaluate(with: trimmed) {
            return true
        }
        
        // IPv6 simplified pattern
        let ipv6Pattern = #"^((?:[0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}|(?:[0-9A-Fa-f]{1,4}:){1,7}:|(?:[0-9A-Fa-f]{1,4}:){1,6}:[0-9A-Fa-f]{1,4}|(?:[0-9A-Fa-f]{1,4}:){1,5}(?::[0-9A-Fa-f]{1,4}){1,2}|(?:[0-9A-Fa-f]{1,4}:){1,4}(?::[0-9A-Fa-f]{1,4}){1,3}|(?:[0-9A-Fa-f]{1,4}:){1,3}(?::[0-9A-Fa-f]{1,4}){1,4}|(?:[0-9A-Fa-f]{1,4}:){1,2}(?::[0-9A-Fa-f]{1,4}){1,5}|[0-9A-Fa-f]{1,4}:(?::[0-9A-Fa-f]{1,4}){1,6}|:(?::[0-9A-Fa-f]{1,4}){1,7}|::)$"#
        return NSPredicate(format: "SELF MATCHES %@", ipv6Pattern).evaluate(with: trimmed)
    }
    
    private static func encryptPrivateKey(keyPEM: String, password: String, keyType: KeyType) throws -> String {
        let tempDir = NSTemporaryDirectory()
        let uuid = UUID().uuidString
        let unencryptedKeyPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid)_unenc.key")
        let encryptedKeyPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid)_enc.key")
        
        defer {
            try? FileManager.default.removeItem(atPath: unencryptedKeyPath)
            try? FileManager.default.removeItem(atPath: encryptedKeyPath)
        }
        
        // Write unencrypted key to temp file
        try keyPEM.write(to: URL(fileURLWithPath: unencryptedKeyPath), atomically: true, encoding: .utf8)
        
        // Encrypt using OpenSSL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        
        let algorithm = keyType == .rsa ? "rsa" : "ec"
        process.arguments = [
            algorithm,
            "-in", unencryptedKeyPath,
            "-out", encryptedKeyPath,
            "-aes256",
            "-passout", "pass:\(password)"
        ]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw NSError(
                    domain: "CertificateUtils",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encrypt private key: \(errorString)"]
                )
            }
            
            guard let encryptedData = try? Data(contentsOf: URL(fileURLWithPath: encryptedKeyPath)),
                  let encryptedPEM = String(data: encryptedData, encoding: .utf8) else {
                throw NSError(
                    domain: "CertificateUtils",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to read encrypted private key"]
                )
            }
            
            return encryptedPEM
        } catch let error as NSError where error.domain == "CertificateUtils" {
            throw error
        } catch {
            throw NSError(
                domain: "CertificateUtils",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to execute OpenSSL for encryption: \(error.localizedDescription)"]
            )
        }
    }
    
    private static func generatePrivateKeyPEM(_ keyData: Data, password: String?) -> String {
        let base64 = keyData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        
        // Note: For encrypted keys, you'd need to implement PKCS#8 encryption
        // For simplicity, we're creating unencrypted keys here
        // In production, consider using OpenSSL or CryptoKit for proper encryption
        
        return "-----BEGIN RSA PRIVATE KEY-----\n\(base64)\n-----END RSA PRIVATE KEY-----"
    }
    
    private static func createCSRPEM(details: CSRDetails, publicKey: SecKey, privateKey: SecKey) throws -> String {
        // Build subject DN
        var subjectComponents: [String] = []
        if !details.country.isEmpty { subjectComponents.append("C=\(details.country)") }
        if !details.state.isEmpty { subjectComponents.append("ST=\(details.state)") }
        if !details.locality.isEmpty { subjectComponents.append("L=\(details.locality)") }
        if !details.organization.isEmpty { subjectComponents.append("O=\(details.organization)") }
        if !details.organizationalUnit.isEmpty { subjectComponents.append("OU=\(details.organizationalUnit)") }
        if !details.commonName.isEmpty { subjectComponents.append("CN=\(details.commonName)") }
        
        let subject = subjectComponents.joined(separator: ", ")
        
        // For a full implementation, you'd need to construct the CSR using ASN.1 encoding
        // This is a simplified version - in production, use a proper crypto library
        let csrContent = """
        Certificate Request:
            Subject: \(subject)
            Public Key Algorithm: RSA
            Key Size: \(details.keySize)
        """
        
        let csrData = csrContent.data(using: .utf8) ?? Data()
        let base64 = csrData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        
        return "-----BEGIN CERTIFICATE REQUEST-----\n\(base64)\n-----END CERTIFICATE REQUEST-----"
    }
    
    // MARK: - PFX Operations
    
    static func createPFX(certificates: [Certificate], privateKeyData: Data, keyPassword: String?, pfxPassword: String, options: PFXOptions = PFXOptions()) throws -> Data {
        let tempDir = NSTemporaryDirectory()
        let uuid = UUID().uuidString
        let certPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid).crt")
        let keyPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid).key")
        let pfxPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid).pfx")
        let keyPassFilePath = (tempDir as NSString).appendingPathComponent("temp_\(uuid)_keypass.txt")
        let pfxPassFilePath = (tempDir as NSString).appendingPathComponent("temp_\(uuid)_pfxpass.txt")
        
        defer {
            // Clean up temporary files
            try? FileManager.default.removeItem(atPath: certPath)
            try? FileManager.default.removeItem(atPath: keyPath)
            try? FileManager.default.removeItem(atPath: pfxPath)
            try? FileManager.default.removeItem(atPath: keyPassFilePath)
            try? FileManager.default.removeItem(atPath: pfxPassFilePath)
        }
        
        // Write certificate chain to file
        let chainPEM = certificates.map { $0.pemRepresentation }.joined(separator: "\n")
        try chainPEM.write(to: URL(fileURLWithPath: certPath), atomically: true, encoding: .utf8)
        
        // Write private key to file
        try privateKeyData.write(to: URL(fileURLWithPath: keyPath))
        
        // Write PFX password to file
        try pfxPassword.write(to: URL(fileURLWithPath: pfxPassFilePath), atomically: true, encoding: .utf8)
        
        // Build OpenSSL command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        
        var arguments = [
            "pkcs12",
            "-export",
            "-out", pfxPath,
            "-inkey", keyPath,
            "-in", certPath,
            "-passout", "file:\(pfxPassFilePath)"
        ]
        
        // Add custom PFX options (encryption algorithm, MAC algorithm, etc.)
        arguments.append(contentsOf: options.opensslArguments)
        
        // Add key password if provided
        if let keyPass = keyPassword, !keyPass.isEmpty {
            try keyPass.write(to: URL(fileURLWithPath: keyPassFilePath), atomically: true, encoding: .utf8)
            arguments.append(contentsOf: ["-passin", "file:\(keyPassFilePath)"])
        } else {
            arguments.append(contentsOf: ["-passin", "pass:"])
        }
        
        process.arguments = arguments
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                
                throw NSError(
                    domain: "CertificateUtils",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create PFX file: \(errorString)"]
                )
            }
            
            // Read the created PFX file
            guard FileManager.default.fileExists(atPath: pfxPath),
                  let pfxData = try? Data(contentsOf: URL(fileURLWithPath: pfxPath)) else {
                throw NSError(
                    domain: "CertificateUtils",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to read created PFX file."]
                )
            }
            
            return pfxData
            
        } catch let error as NSError where error.domain == "CertificateUtils" {
            throw error
        } catch {
            throw NSError(
                domain: "CertificateUtils",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to execute OpenSSL: \(error.localizedDescription)"]
            )
        }
    }
    
    static func extractPrivateKey(from pfxData: Data, password: String) throws -> String {
        // Use OpenSSL command-line tool for extraction
        // This bypasses Security framework restrictions and works with any PKCS#12 file
        return try extractPrivateKeyWithOpenSSL(pfxData: pfxData, password: password)
    }
    
    private static func extractPrivateKeyWithOpenSSL(pfxData: Data, password: String) throws -> String {
        let tempDir = NSTemporaryDirectory()
        let uuid = UUID().uuidString
        let pfxPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid).pfx")
        let keyPath = (tempDir as NSString).appendingPathComponent("temp_\(uuid).key")
        let passFilePath = (tempDir as NSString).appendingPathComponent("temp_\(uuid).pass")
        
        defer {
            // Clean up temporary files
            try? FileManager.default.removeItem(atPath: pfxPath)
            try? FileManager.default.removeItem(atPath: keyPath)
            try? FileManager.default.removeItem(atPath: passFilePath)
        }
        
        // Write PFX data to temporary file
        try pfxData.write(to: URL(fileURLWithPath: pfxPath))
        
        // Write password to file for secure passing to OpenSSL
        try password.write(to: URL(fileURLWithPath: passFilePath), atomically: true, encoding: .utf8)
        
        // Use OpenSSL to extract private key
        // -nodes means no encryption on output (plain text PEM)
        // -passin file: reads password from file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "pkcs12",
            "-in", pfxPath,
            "-nocerts",
            "-nodes",
            "-passin", "file:\(passFilePath)",
            "-out", keyPath
        ]
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                
                if errorString.contains("invalid password") || errorString.contains("bad password") {
                    throw NSError(
                        domain: "CertificateUtils",
                        code: Int(errSecAuthFailed),
                        userInfo: [NSLocalizedDescriptionKey: "Incorrect password for PFX file."]
                    )
                } else {
                    throw NSError(
                        domain: "CertificateUtils",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "OpenSSL extraction failed: \(errorString)"]
                    )
                }
            }
            
            // Read the extracted key
            guard FileManager.default.fileExists(atPath: keyPath),
                  let keyData = try? Data(contentsOf: URL(fileURLWithPath: keyPath)),
                  let keyPEM = String(data: keyData, encoding: .utf8) else {
                throw NSError(
                    domain: "CertificateUtils",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to read extracted private key."]
                )
            }
            
            // Clean up and return the key
            return keyPEM.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch let error as NSError where error.domain == "CertificateUtils" {
            throw error
        } catch {
            throw NSError(
                domain: "CertificateUtils",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to execute OpenSSL: \(error.localizedDescription)"]
            )
        }
    }
    
    private static func extractPrivateKeyDirect(pfxData: Data, password: String) throws -> String {
        // Direct extraction without temporary keychain
        var items: CFArray?
        let importOptions = [kSecImportExportPassphrase as String: password] as CFDictionary
        
        let status = SecPKCS12Import(pfxData as CFData, importOptions, &items)
        
        guard status == errSecSuccess else {
            if status == errSecAuthFailed {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "Incorrect password for PFX file."]
                )
            } else {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to import PFX file. Status: \(status)"]
                )
            }
        }
        
        guard let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first,
              let identityRef = firstItem[kSecImportItemIdentity as String] else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(errSecInvalidKeyAttributeMask),
                userInfo: [NSLocalizedDescriptionKey: "No identity found in PFX file."]
            )
        }
        
        let identity = identityRef as! SecIdentity
        
        // Extract the private key from identity
        var privateKey: SecKey?
        let keyStatus = SecIdentityCopyPrivateKey(identity, &privateKey)
        
        guard keyStatus == errSecSuccess, let key = privateKey else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(keyStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to extract private key from identity."]
            )
        }
        
        // Try direct export
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            let errorDescription = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(errSecInvalidKeyAttributeMask),
                userInfo: [NSLocalizedDescriptionKey: "Unable to export private key: \(errorDescription). The key may have non-exportable attributes."]
            )
        }
        
        // Determine key type
        let keyAttributes = SecKeyCopyAttributes(key) as? [String: Any]
        let keyType = keyAttributes?[kSecAttrKeyType as String] as? String
        
        let base64 = keyData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        
        if keyType as CFString? == kSecAttrKeyTypeRSA {
            return "-----BEGIN RSA PRIVATE KEY-----\n\(base64)\n-----END RSA PRIVATE KEY-----"
        } else if keyType as CFString? == kSecAttrKeyTypeEC || keyType as CFString? == kSecAttrKeyTypeECSECPrimeRandom {
            return "-----BEGIN EC PRIVATE KEY-----\n\(base64)\n-----END EC PRIVATE KEY-----"
        } else {
            return "-----BEGIN PRIVATE KEY-----\n\(base64)\n-----END PRIVATE KEY-----"
        }
    }
    
    private static func extractPrivateKeyData(from pem: String) -> Data? {
        let pattern = "-----BEGIN.*?PRIVATE KEY-----([^-]+)-----END.*?PRIVATE KEY-----"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        
        let range = NSRange(pem.startIndex..., in: pem)
        guard let match = regex.firstMatch(in: pem, range: range),
              match.numberOfRanges >= 2,
              let base64Range = Range(match.range(at: 1), in: pem) else {
            return nil
        }
        
        let base64String = String(pem[base64Range])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        return Data(base64Encoded: base64String)
    }
}
