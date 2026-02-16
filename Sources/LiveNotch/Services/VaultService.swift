import SwiftUI
import UniformTypeIdentifiers
import Combine

// ═══════════════════════════════════════════════════
// MARK: - VAULT SERVICE (Data Ingestion)
// ═══════════════════════════════════════════════════

struct VaultItem: Identifiable, Codable {
    let id: UUID
    let type: VaultType
    let content: String // URL, Text, or local file path
    let timestamp: Date
    
    enum VaultType: String, Codable {
        case fileUrl
        case webUrl
        case textSnippet
        case image
    }
}

class VaultService: ObservableObject {
    static let shared = VaultService()
    
    @Published var vaultItems: [VaultItem] = []
    
    // Limits
    private let maxItems = 50
    private let storageKey = "notch_vault_items"
    
    private init() {
        loadItems()
    }
    
    // MARK: - Drop Handling
    
    /// Returns true if the drop was handled successfully
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        
        // Dispatch group to handle concurrent loads if needed
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            
            // Priority 1: File URL (Scripts or generic files)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    defer { group.leave() }
                    guard let url = url, error == nil else { return }
                    
                    DispatchQueue.main.async {
                        // Check if it's a script for ScriptDropService
                        if ScriptDropService.isScript(url) {
                            // Let ScriptDropService handle it (or handle it here and delegate)
                            // For now, we assume NotchViews calls ScriptDropService if it's a script,
                            // OR we can make Vault smart enough to differentiate.
                            // Currently, standard is: Script -> Run directly. File -> Vault.
                            if !ScriptDropService.isScript(url) {
                                self.addToVault(type: .fileUrl, content: url.path)
                            }
                        } else {
                            // It's a regular file -> Vault
                            self.addToVault(type: .fileUrl, content: url.path)
                        }
                    }
                    handled = true
                }
            }
            // Priority 2: Web URL
            else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    defer { group.leave() }
                    guard let url = url, error == nil else { return }
                    
                    // Filter out file URLs if they slipped through
                    if !url.isFileURL {
                        DispatchQueue.main.async {
                            self.addToVault(type: .webUrl, content: url.absoluteString)
                        }
                        handled = true
                    }
                }
            }
            // Priority 3: Text
            else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                _ = provider.loadObject(ofClass: String.self) { text, error in
                    defer { group.leave() }
                    guard let text = text, error == nil else { return }
                    
                    DispatchQueue.main.async {
                        self.addToVault(type: .textSnippet, content: text)
                    }
                    handled = true
                }
            }
            // Priority 4: Image (experimental, usually file URL covers this if dragged from finder)
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
               // Loading images directly from NSPasteboard/Drag is heavier.
               // For now, if it's not a file, we might skip or implement later.
               group.leave()
            } else {
                group.leave()
            }
        }
        
        // Return true immediately implies we "accepted" the drop, 
        // processing happens async.
        return true
    }
    
    // MARK: - Storage
    
    private func addToVault(type: VaultItem.VaultType, content: String) {
        let item = VaultItem(id: UUID(), type: type, content: content, timestamp: Date())
        
        withAnimation {
            vaultItems.insert(item, at: 0)
            if vaultItems.count > maxItems {
                vaultItems.removeLast()
            }
        }
        
        saveItems()
        HapticManager.shared.play(.success)
        
        // 🔮 Future: Send to Laravel API here
        // API.sendToCortex(item)
    }
    
    private func saveItems() {
        NotchPersistence.shared.setCodable(.vaultItems, value: vaultItems)
    }
    
    private func loadItems() {
        if let decoded = NotchPersistence.shared.getCodable(.vaultItems, as: [VaultItem].self) {
            vaultItems = decoded
        }
    }
    
    func clearVault() {
        vaultItems.removeAll()
        saveItems()
    }
}
