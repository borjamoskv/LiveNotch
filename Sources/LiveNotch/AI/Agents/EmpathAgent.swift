import SwiftUI

// ═══════════════════════════════════════════════════
// MARK: - 💚 Empath Agent (Mood & Wellbeing)
// ═══════════════════════════════════════════════════

struct EmpathAgent: NotchAgent {
    let name = "Empath"
    let emoji = "💚"
    let domain = "Wellbeing & Flow"
    
    private let wellbeingKeywords = ["tired", "stressed", "break", "focus", "flow",
                                      "cansado", "estresado", "descanso", "animo",
                                      "how am i", "mood", "energy", "burnout",
                                      "motivation", "pomodoro", "breathe", "respirar"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let lowered = query.lowercased()
        var score = 0.0
        let matches = wellbeingKeywords.filter { lowered.contains($0) }.count
        score += Double(matches) * 0.2
        
        // High CPU + late night = empathy trigger
        if context.cpuUsage > 60 && (context.timeOfDay == .night || context.timeOfDay == .lateNight) {
            score += 0.25
        }
        
        // Stressed mood
        if context.currentMood == "stressed" { score += 0.3 }
        
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) async -> AgentResponse {
        // Dynamic Time Greeting
        let timeGreeting = getTimeGreeting(for: context.timeOfDay)
        
        // Stress Analysis
        let stressScore = calculateStress(context: context)
        let isHighStress = stressScore > 0.7
        
        var response = "\(timeGreeting)\n"
        
        if query.lowercased().contains("breathe") || query.lowercased().contains("respirar") || isHighStress {
            response += "\n🌬 **Guided Box Breathing (4-4-4-4):**"
            response += "\n1. Inhale (Hold Shift)... [====]"
            response += "\n2. Hold...               [----]"
            response += "\n3. Exhale...             [====]"
            response += "\n4. Pause...              [----]"
            response += "\n*Repeat 4 times to lower cortisol.*"
        
        } else if context.currentMood == "flow" {
            response += "\n🌊 **Flow State Detected.**"
            response += "\n• Notifications: Silenced"
            response += "\n• Momentum: High"
            response += "\n*Keep pushing, but drink water.*"
            
        } else {
            response += "\n**Neural Dashboard:**"
            response += "\n• System Load: \(Int(context.cpuUsage))%"
            response += "\n• Bat Energy: \(context.batteryLevel)%" // Simulated until IOKit
            response += "\n• Digital Stress: \(Int(stressScore * 100))%"
            
            if isHighStress {
                response += "\n\n⚠️ **High Intensity Detected.** Consider a 5 min break away from screens."
            } else {
                response += "\n\n✅ Systems Nominal. You are operating within sustainable parameters."
            }
        }
        
        return AgentResponse(text: response, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
    
    private func getTimeGreeting(for time: SensorFusion.TimeOfDay) -> String {
        switch time {
        case .morning: return "☕️ Good morning. Objectives aligned?"
        case .afternoon: return "☀️ Afternoon status. Hydration check."
        case .evening: return "🌅 Evening flow. Wrapping up or just starting?"
        case .night: return "🌙 Night mode active. Reduce blue light."
        case .lateNight: return "🦉 Late night operations. Sleep is critical for consolidation."
        }
    }
    
    private func calculateStress(context: SensorFusion) -> Double {
        var stress = 0.0
        if context.cpuUsage > 70 { stress += 0.4 }
        if context.timeOfDay == .lateNight { stress += 0.3 }
        return min(1.0, stress)
    }
}
