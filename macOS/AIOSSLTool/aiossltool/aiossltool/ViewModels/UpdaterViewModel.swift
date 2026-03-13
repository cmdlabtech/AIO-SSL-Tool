//
//  PreferencesViewModel.swift
//  AIO SSL Tool
//
//  App Store version — update checking removed.
//  Retained for preferences only.
//

import SwiftUI

final class UpdaterViewModel: ObservableObject {
    @Published var neverShowAdvancedOptionsWarning = false
    @Published var enableCertificateArchive = false
    @Published var hideArchiveFolder = true

    init() {
        loadPreferences()
    }

    // MARK: - Persistence

    private func loadPreferences() {
        neverShowAdvancedOptionsWarning = UserDefaults.standard.bool(forKey: "NeverShowAdvancedOptionsWarning")
        enableCertificateArchive = UserDefaults.standard.bool(forKey: "EnableCertificateArchive")
        hideArchiveFolder = UserDefaults.standard.object(forKey: "HideArchiveFolder") as? Bool ?? true
    }

    func savePreferences() {
        UserDefaults.standard.set(neverShowAdvancedOptionsWarning, forKey: "NeverShowAdvancedOptionsWarning")
        UserDefaults.standard.set(enableCertificateArchive, forKey: "EnableCertificateArchive")
        UserDefaults.standard.set(hideArchiveFolder, forKey: "HideArchiveFolder")
    }

    // MARK: - Version Info

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}
