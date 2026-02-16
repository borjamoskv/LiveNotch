import SwiftUI
import AppKit
import Combine
import UserNotifications

// ═══════════════════════════════════════════════════
// MARK: - 🤖 AI Controller
// ═══════════════════════════════════════════════════
// Extracted from NotchViewModel — owns AI query/response state.
// Single Responsibility: Chat with NotchIntelligence, streaming text.

@MainActor
final class AIController: ObservableObject {
    
    @Published var aiQuery: String = ""
    @Published var aiResponse: String = ""
    @Published var aiIsThinking: Bool = false
    @Published var showAIBar: Bool = false
    @Published var isLLMConnected: Bool = false
    
    private var streamingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Sync LLM connection state
        Task {
            await LLMService.shared.checkConnection()
            self.isLLMConnected = LLMService.shared.isConnected
        }
    }
    
    deinit {
        streamingTimer?.invalidate()
    }
    
    // ════════════════════════════════════════
    // MARK: - Query Handling
    // ════════════════════════════════════════
    
    func sendQuery() {
        let prompt = aiQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        aiIsThinking = true
        aiResponse = ""
        HapticManager.shared.play(.toggle)
        aiQuery = ""
        
        let context = NervousSystem.shared.currentAIContext
        let llm = LLMService.shared
        
        // Always use Swarm Intelligence (Deep Integration)
        Task {
            await NotchIntelligence.shared.process(query: prompt, context: context) { [weak self] partialResponse in
                Task { @MainActor in
                    self?.aiResponse = partialResponse
                    if partialResponse.count % 3 == 0 { HapticManager.shared.play(.subtle) }
                }
            }
        }
        
        NotchIntelligence.shared.$isThinking
            .receive(on: DispatchQueue.main)
            .assign(to: \.aiIsThinking, on: self)
            .store(in: &cancellables)
    }
    
    /// Process clipboard content with AI context
    func processClipboard(_ text: String) {
        aiIsThinking = true
        aiResponse = ""
        
        let context = NervousSystem.shared.currentAIContext
        let fullPrompt = "Context: \(context)\n\nClipboard Content: \(text)\n\nExplain this."
        
        Task {
            await NotchIntelligence.shared.process(query: fullPrompt, context: context) { [weak self] partial in
                Task { @MainActor in
                    self?.aiResponse = partial
                }
            }
        }
         
        NotchIntelligence.shared.$isThinking
            .receive(on: DispatchQueue.main)
            .assign(to: \.aiIsThinking, on: self)
            .store(in: &cancellables)
    }
    
    /// Streams text character by character for a "living" feel
    func streamText(_ fullText: String) {
        streamingTimer?.invalidate()
        aiResponse = ""
        
        let characters = Array(fullText)
        var currentIndex = 0
        
        streamingTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }
                
                if currentIndex < characters.count {
                    self.aiResponse.append(characters[currentIndex])
                    currentIndex += 1
                    if currentIndex % 3 == 0 {
                        HapticManager.shared.play(.subtle)
                    }
                } else {
                    timer.invalidate()
                    self.streamingTimer = nil
                }
            }
        }
    }
}
