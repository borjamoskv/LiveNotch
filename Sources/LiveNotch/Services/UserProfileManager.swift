import SwiftUI
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 👤 User Profile Manager
// ═══════════════════════════════════════════════════
// Manages user identity, preferences, and context-aware settings.

public class UserProfileManager: ObservableObject {
    @Published var currentProfile: UserProfile
    
    static let shared = UserProfileManager()
    
    init() {
        // Load from persistence or default
        let savedAccent = NotchPersistence.shared.string(.userProfileAccent, default: "yinmn")
        self.currentProfile = UserProfile(accentColor: savedAccent)
    }
    
    func updateAccentColor(_ colorName: String) {
        currentProfile.accentColor = colorName
        NotchPersistence.shared.set(.userProfileAccent, value: colorName)
        objectWillChange.send()
    }
}

public struct UserProfile {
    var accentColor: String
    // Add more profile properties here (name, avatar, etc.)
}
