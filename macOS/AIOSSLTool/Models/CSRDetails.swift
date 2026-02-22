//
//  CSRDetails.swift
//  AIO SSL Tool
//
//  CSR generation model following industry standards:
//  - RFC 2986 (PKCS #10: Certification Request Syntax)
//  - RFC 5280 (X.509 Public Key Infrastructure Certificate and CRL Profile)
//  - NIST SP 800-57 (Recommendation for Key Management)
//  - FIPS 186-4 (Digital Signature Standard)
//

import Foundation

enum KeyType: String, CaseIterable {
    case rsa = "RSA"
    case ecc = "ECC"
    
    var minKeySize: Int {
        switch self {
        case .rsa: return 2048  // NIST SP 800-57: minimum 2048 bits for RSA
        case .ecc: return 256   // NIST SP 800-57: P-256 minimum
        }
    }
}

enum ECCCurve: String, CaseIterable {
    case prime256v1 = "prime256v1"  // P-256 (NIST: FIPS 186-4, SECG: secp256r1)
    case secp384r1 = "secp384r1"    // P-384 (NIST: FIPS 186-4)
    case secp521r1 = "secp521r1"    // P-521 (NIST: FIPS 186-4)
    
    var displayName: String {
        switch self {
        case .prime256v1: return "P-256 (prime256v1)"
        case .secp384r1: return "P-384 (secp384r1)"
        case .secp521r1: return "P-521 (secp521r1)"
        }
    }
    
    // Security strength in bits (per NIST SP 800-57)
    var securityStrength: Int {
        switch self {
        case .prime256v1: return 128
        case .secp384r1: return 192
        case .secp521r1: return 256
        }
    }
}

struct CSRDetails {
    var commonName: String = ""
    var country: String = ""
    var state: String = ""
    var locality: String = ""
    var organization: String = ""
    var organizationalUnit: String = ""
    var email: String = ""
    var sans: [String] = []
    var keyType: KeyType = .rsa
    var keySize: Int = 2048           // Used for RSA
    var eccCurve: ECCCurve = .prime256v1  // Used for ECC
    var keyPassword: String? = nil
}
