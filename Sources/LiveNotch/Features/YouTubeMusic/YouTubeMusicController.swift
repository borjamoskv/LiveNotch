//
//  YouTubeMusicController.swift
//  LiveNotch
//
//  Created by Alexander on 2025-03-30.
//  Modified for LiveNotch by Antigravity.
//

import Foundation
import Combine
import SwiftUI
import AppKit

final class YouTubeMusicController: ObservableObject {
    // MARK: - Published Properties
    @Published var currentTrack: Track?
    
    private var artworkFetchTask: Task<Void, Never>?
    
    // MARK: - Private Properties
    private let configuration: YouTubeMusicConfiguration
    private let httpClient: YouTubeMusicHTTPClient
    private let authManager: YouTubeMusicAuthManager
    private var webSocketClient: YouTubeMusicWebSocketClient?
    
    private var updateTimer: Timer?
    private var appStateObserver: Task<Void, Never>?
    private var reconnectDelay: TimeInterval = 1.0
    
    // MARK: - Initialization
    init(configuration: YouTubeMusicConfiguration = .default) {
        self.configuration = configuration
        self.httpClient = YouTubeMusicHTTPClient(baseURL: configuration.baseURL)
        self.authManager = YouTubeMusicAuthManager(httpClient: httpClient)
        
        setupAppStateObserver()
        
        Task {
            await initializeIfAppActive()
        }
    }
    
    // MARK: - Controls
    func play() async { await sendCommand(endpoint: "/play", method: "POST") }
    func pause() async { await sendCommand(endpoint: "/pause", method: "POST") }
    func togglePlay() async {
        if !isActive() { launchApp() }
        await sendCommand(endpoint: "/toggle-play", method: "POST")
    }
    func nextTrack() async { await sendCommand(endpoint: "/next", method: "POST") }
    func previousTrack() async { await sendCommand(endpoint: "/previous", method: "POST") }
    
    func seek(to time: Double) async {
        let payload = ["seconds": time]
        await sendCommand(endpoint: "/seek-to", method: "POST", body: payload)
    }

    func setVolume(_ level: Float) async {
        let volumePercentage = Int(level * 100)
        let payload = ["volume": volumePercentage]
        await sendCommand(endpoint: "/volume", method: "POST", body: payload)
    }

    func isActive() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == configuration.bundleIdentifier
        }
    }
    
    func updatePlaybackInfo() async {
        guard isActive() else {
            currentTrack = nil
            return
        }
        
        do {
            let token = try await authManager.authenticate()
            let response = try await httpClient.getPlaybackInfo(token: token)
            await updatePlaybackState(with: response)
        } catch YouTubeMusicError.authenticationRequired {
            await authManager.invalidateToken()
        } catch {
            print("[YouTubeMusicController] Failed to update playback info: \(error)")
        }
    }
    
    // MARK: - Private Methods
    private func setupAppStateObserver() {
        appStateObserver = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    let launchNotifications = NSWorkspace.shared.notificationCenter.notifications(
                        named: NSWorkspace.didLaunchApplicationNotification
                    )
                    for await notification in launchNotifications {
                        await self?.handleAppLaunched(notification)
                    }
                }
                
                group.addTask {
                    let terminateNotifications = NSWorkspace.shared.notificationCenter.notifications(
                        named: NSWorkspace.didTerminateApplicationNotification
                    )
                    for await notification in terminateNotifications {
                        await self?.handleAppTerminated(notification)
                    }
                }
            }
        }
    }
    
    private func handleAppLaunched(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == configuration.bundleIdentifier else {
            return
        }
        await initializeIfAppActive()
    }
    
    private func handleAppTerminated(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == configuration.bundleIdentifier else {
            return
        }
        
        await MainActor.run {
            stopPeriodicUpdates()
        }
        
        await webSocketClient?.disconnect()
        webSocketClient = nil
        currentTrack = nil
    }
    
    private func initializeIfAppActive() async {
        guard isActive() else { return }
        
        do {
            let token = try await authManager.authenticate()
            await setupWebSocketIfPossible(token: token)
            await startPeriodicUpdates()
            await updatePlaybackInfo()
        } catch {
            print("[YouTubeMusicController] Failed to initialize: \(error)")
            await scheduleReconnect()
        }
    }
    
    private func setupWebSocketIfPossible(token: String) async {
        guard let wsURL = WebSocketURLBuilder.buildURL(from: configuration.baseURL) else {
            return
        }
        
        let client = YouTubeMusicWebSocketClient(
            onMessage: { [weak self] data in
                await self?.handleWebSocketMessage(data)
            },
            onDisconnect: { [weak self] in
                await self?.handleWebSocketDisconnect()
            }
        )
        
        do {
            try await client.connect(to: wsURL, with: token)
            webSocketClient = client
            await MainActor.run {
                stopPeriodicUpdates()
            }
            reconnectDelay = configuration.reconnectDelay.lowerBound
        } catch {
            print("[YouTubeMusicController] WebSocket connection failed: \(error)")
            await scheduleReconnect()
        }
    }
    
    private func handleWebSocketMessage(_ data: Data) async {
        guard let message = WebSocketMessage(from: data) else {
            if let response = try? JSONDecoder().decode(PlaybackResponse.self, from: data) {
                await updatePlaybackState(with: response)
            }
            return
        }
        switch message.type {
        case .playerInfo, .videoChanged, .playerStateChanged:
            if let data = message.extractData(),
               let response = PlaybackResponse.from(websocketData: data) {
                await updatePlaybackState(with: response)
            }

        case .positionChanged:
            guard let data = message.extractData() else { return }
            var position: Double? = nil
            if let pos = data["position"] as? Double { position = pos }
            else if let elapsed = data["elapsedSeconds"] as? Double { position = elapsed }
            
            if let newPosition = position, var track = currentTrack {
                track.position = newPosition
                await MainActor.run { currentTrack = track }
            }

        case .volumeChanged:
            // Volume updates handled via main controller in LiveNotch
            break
            
        case .repeatChanged, .shuffleChanged:
            // Future implementation
            break
        }
    }
    
    private func handleWebSocketDisconnect() async {
        webSocketClient = nil
        await startPeriodicUpdates()
        await scheduleReconnect()
    }
    
    private func scheduleReconnect() async {
        try? await Task.sleep(for: .seconds(reconnectDelay))
        reconnectDelay = min(reconnectDelay * 2, configuration.reconnectDelay.upperBound)
        if isActive() {
            await initializeIfAppActive()
        }
    }
    
    private func startPeriodicUpdates() async {
        guard isActive() && webSocketClient == nil else { return }
        
        await MainActor.run {
            stopPeriodicUpdates()
            updateTimer = Timer.scheduledTimer(withTimeInterval: configuration.updateInterval, repeats: true) { [weak self] _ in
                Task { await self?.updatePlaybackInfo() }
            }
        }
    }
    
    private func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func sendCommand(
        endpoint: String,
        method: String = "POST",
        body: (any Codable & Sendable)? = nil,
        refresh: Bool = true
    ) async {
        do {
            let token = try await authManager.authenticate()
            _ = try await httpClient.sendCommand(
                endpoint: endpoint,
                method: method,
                body: body,
                token: token
            )
            if refresh && webSocketClient == nil {
                try? await Task.sleep(for: .milliseconds(100))
                await updatePlaybackInfo()
            }
        } catch YouTubeMusicError.authenticationRequired {
            await authManager.invalidateToken()
        } catch {
            print("[YouTubeMusicController] Command failed: \(error)")
        }
    }
    
    private func updatePlaybackState(with response: PlaybackResponse) async {
        let track = Track(
            title: response.title ?? "Unknown Title",
            artist: response.artist ?? "Unknown Artist",
            album: response.album ?? "",
            isPlaying: !response.isPaused,
            position: response.elapsedSeconds ?? 0,
            duration: response.songDuration ?? 0,
            source: .youtubeMusic
        )
        
        await MainActor.run {
            let oldArtURL = currentTrack?.artworkURL?.absoluteString
            currentTrack = track
            
            if let artworkURL = response.imageSrc, artworkURL != oldArtURL {
                currentTrack?.artworkURL = URL(string: artworkURL)
                fetchArtwork(url: artworkURL)
            }
        }
    }
    
    private func fetchArtwork(url: String) {
        artworkFetchTask?.cancel()
        guard let artworkURL = URL(string: url) else { return }
        
        artworkFetchTask = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: artworkURL)
                if let image = NSImage(data: data) {
                    await MainActor.run {
                        self.currentTrack?.artworkImage = image
                    }
                }
            } catch {
                print("[YouTubeMusicController] Failed to fetch artwork: \(error)")
            }
        }
    }
    
    private func launchApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: configuration.bundleIdentifier) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Adapter Interface
extension YouTubeMusicController: MusicAdapter {
    var source: TrackSource { .youtubeMusic }
    var isAvailable: Bool { isActive() }
    
    func getCurrentTrack() -> Track? { currentTrack }
    func play() { Task { await self.play() } }
    func pause() { Task { await self.pause() } }
    func next() { Task { await self.nextTrack() } }
    func previous() { Task { await self.previousTrack() } }
    func seek(to position: Double) {
        guard let track = currentTrack else { return }
        let target = position * track.duration
        Task { await self.seek(to: target) }
    }
    func setVolume(_ volume: Float) { Task { await self.setVolume(volume) } }
}
