//
//  PFXOptions.swift
//  AIO SSL Tool
//

import Foundation

struct PFXOptions {
    enum MACAlgorithm: String, CaseIterable, Identifiable {
        case sha256 = "SHA-256"
        case sha512 = "SHA-512"
        case sha1 = "SHA-1"
        
        var id: String { rawValue }
        
        var opensslArg: String {
            switch self {
            case .sha1: return "sha1"
            case .sha256: return "sha256"
            case .sha512: return "sha512"
            }
        }
        
        var isLegacy: Bool {
            self == .sha1
        }
    }
    
    enum EncryptionAlgorithm: String, CaseIterable, Identifiable {
        case default_ = "Default"
        case aes256 = "AES-256"
        case aes128 = "AES-128"
        case tripledes = "3DES"
        case legacy = "Legacy"
        
        var id: String { rawValue }
        
        var opensslArgs: [String] {
            switch self {
            case .default_: return []
            case .legacy: return ["-legacy"]
            case .aes128: return ["-certpbe", "AES-128-CBC", "-keypbe", "AES-128-CBC"]
            case .aes256: return ["-certpbe", "AES-256-CBC", "-keypbe", "AES-256-CBC"]
            case .tripledes: return ["-certpbe", "PBE-SHA1-3DES", "-keypbe", "PBE-SHA1-3DES"]
            }
        }
        
        var isLegacy: Bool {
            self == .legacy
        }
    }
    
    var macAlgorithm: MACAlgorithm = .sha256
    var encryptionAlgorithm: EncryptionAlgorithm = .default_
    var useAdvancedOptions: Bool = false
    
    var opensslArguments: [String] {
        var args: [String] = []
        
        // Add encryption algorithm args
        args.append(contentsOf: encryptionAlgorithm.opensslArgs)
        
        // Add MAC algorithm if not default
        if macAlgorithm != .sha256 {
            args.append(contentsOf: ["-macalg", macAlgorithm.opensslArg])
        }
        
        return args
    }
    
    var isUsingLegacyOptions: Bool {
        macAlgorithm.isLegacy || encryptionAlgorithm.isLegacy
    }
    
    var warningMessage: String? {
        if isUsingLegacyOptions {
            var warnings: [String] = []
            if macAlgorithm.isLegacy {
                warnings.append("SHA-1 MAC algorithm")
            }
            if encryptionAlgorithm.isLegacy {
                warnings.append("weak encryption")
            }
            return "Using " + warnings.joined(separator: " and ")
        }
        return nil
    }
}
