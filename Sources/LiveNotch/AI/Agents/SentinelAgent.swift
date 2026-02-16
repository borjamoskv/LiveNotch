import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 🛡️ Sentinel Agent (Security & Privacy)
// ═══════════════════════════════════════════════════

struct SentinelAgent: NotchAgent {
    let name = "Sentinel"
    let emoji = "🛡️"
    let domain = "Security & Privacy"
    
    // Patterns that indicate sensitive data
    private let sensitivePatterns = [
        "sk-", "sk_live_", "sk_test_",           // API keys
        "AKIA", "ASIA",                            // AWS keys
        "ghp_", "gho_", "ghs_",                   // GitHub tokens
        "xoxb-", "xoxp-",                         // Slack tokens
        "-----BEGIN",                               // Private keys
        "password", "secret", "token",
        "Bearer ", "Authorization:"
    ]
    
    private let securityKeywords = ["security", "secure", "privacy", "password", "encrypt",
                                     "key", "token", "leak", "vulnerability", "audit",
                                     "seguridad", "privacidad", "contraseña"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        var score = 0.0
        
        let lowered = query.lowercased()
        let matches = securityKeywords.filter { lowered.contains($0) }.count
        score += Double(matches) * 0.2
        
        // Clipboard contains secrets?
        if let clip = context.clipboardContent {
            for pattern in sensitivePatterns {
                if clip.contains(pattern) {
                    score += 0.5 // High priority
                    break
                }
            }
        }
        
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse {
        // Proactive: Check clipboard for secrets
        var secretsDetected: [String] = []
        if let clip = context.clipboardContent {
            for pattern in sensitivePatterns {
                if clip.contains(pattern) {
                    secretsDetected.append(pattern)
                }
            }
        }
        
        let response: String
        
        if !secretsDetected.isEmpty {
            let masked = secretsDetected.map { "⚠️ Pattern `\($0)***`" }.joined(separator: "\n")
            response = """
            🚨 **ALERT: Sensitive data detected in clipboard!**
            
            \(masked)
            
            **Recommended Actions:**
            1. Clear clipboard immediately (`Cmd+Shift+V` in terminal)
            2. Rotate the exposed key/token
            3. Check `.env` files are in `.gitignore`
            4. Use macOS Keychain for secret storage
            
            *I have NOT transmitted this data anywhere. All processing is local.*
            """
        } else {
            response = """
            \(emoji) Sentinel active. No threats detected.
            
            **Security Posture:**
            • Clipboard: ✅ Clean
            • Active App: \(context.activeAppName)
            • Network: [Monitoring disabled — privacy first]
            
            I can help with:
            • 🔑 API key management best practices
            • 🔒 Encryption guidance
            • 📋 Clipboard security audit
            • 🛡️ .gitignore verification
            """
        }
        
        let action: AgentResponse.SuggestedAction? = secretsDetected.isEmpty
            ? nil
            : .showNotification("⚠️ Secret detected in clipboard!")
        
        return AgentResponse(text: response, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: action)
    }
}
