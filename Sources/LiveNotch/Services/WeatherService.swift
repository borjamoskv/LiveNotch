import Foundation
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 🌤️ Weather Service (via wttr.in — no API key)
// ═══════════════════════════════════════════════════
// Extracted from SystemServices.swift — weather fetching

final class WeatherService: ObservableObject {
    static let shared = WeatherService()
    
    @Published var temperature: String = "--"
    @Published var condition: String = "☀️"
    @Published var location: String = ""
    @Published var feelsLike: String = "--"
    
    private var timer: Timer?
    
    private init() {
        fetchWeather()
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func fetchWeather() {
        guard let url = URL(string: "https://wttr.in/?format=%t|%C|%l|%f") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("curl", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, let str = String(data: data, encoding: .utf8) else { return }
            let parts = str.split(separator: "|", omittingEmptySubsequences: false)
            
            DispatchQueue.main.async {
                if parts.count >= 3 {
                    self?.temperature = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let cond = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    self?.condition = self?.mapConditionToEmoji(cond) ?? "☀️"
                    self?.location = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if parts.count >= 4 {
                        self?.feelsLike = String(parts[3]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }.resume()
    }
    
    private func mapConditionToEmoji(_ condition: String) -> String {
        if condition.contains("sunny") || condition.contains("clear") { return "☀️" }
        if condition.contains("partly") || condition.contains("cloudy") { return "⛅️" }
        if condition.contains("overcast") { return "☁️" }
        if condition.contains("rain") || condition.contains("drizzle") { return "🌧️" }
        if condition.contains("thunder") || condition.contains("storm") { return "⛈️" }
        if condition.contains("snow") { return "❄️" }
        if condition.contains("fog") || condition.contains("mist") { return "🌫️" }
        if condition.contains("wind") { return "💨" }
        return "☀️"
    }
}
