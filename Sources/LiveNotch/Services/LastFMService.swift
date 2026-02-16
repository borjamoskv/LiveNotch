//
//  LastFMService.swift
//  LiveNotch
//
//  Created by NotchPro Enhancement on 2026-02-04.
//  Artwork fallback service using Last.fm API
//

import AppKit
import Foundation
import SwiftUI

/// Service for fetching album artwork from Last.fm when native sources fail
@MainActor
class LastFMService: ObservableObject {
    static let shared = LastFMService()
    
    // Last.fm API key - demo key
    private let apiKey = "b25b959554ed76058ac220b7b2e0a026"
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    
    // Cache to avoid redundant API calls
    private var artworkCache: [String: NSImage] = [:]
    
    private init() {}
    
    /// Fetches album artwork from Last.fm for a given track
    func fetchArtwork(artist: String, track: String) async -> NSImage? {
        // Check cache first
        let cacheKey = "\(artist.lowercased())-\(track.lowercased())"
        if let cached = artworkCache[cacheKey] {
            return cached
        }
        
        // Clean and encode parameters
        guard let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedTrack = track.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !artist.isEmpty, !track.isEmpty else {
            return nil
        }
        
        // Build API URL for track.getInfo
        let urlString = "\(baseURL)?method=track.getInfo&api_key=\(apiKey)&artist=\(encodedArtist)&track=\(encodedTrack)&format=json"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            // Parse JSON response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let trackInfo = json["track"] as? [String: Any],
               let album = trackInfo["album"] as? [String: Any],
               let images = album["image"] as? [[String: Any]] {
                
                // Get the largest image (extralarge or large)
                let imageURL = images
                    .first { ($0["size"] as? String) == "extralarge" }?["#text"] as? String
                    ?? images.first { ($0["size"] as? String) == "large" }?["#text"] as? String
                    ?? images.last?["#text"] as? String
                
                if let imageURLString = imageURL,
                   !imageURLString.isEmpty,
                   let imageURL = URL(string: imageURLString) {
                    
                    // Fetch the actual image
                    let (imageData, _) = try await URLSession.shared.data(from: imageURL)
                    if let image = NSImage(data: imageData) {
                        artworkCache[cacheKey] = image
                        return image
                    }
                }
            }
        } catch {
            print("[LastFMService] Error fetching artwork: \(error.localizedDescription)")
        }
        
        return nil
    }
}
