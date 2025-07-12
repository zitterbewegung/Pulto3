// Model3DPlaceholderView.swift
// Pulto3
//
// Created by Joshua Herman on 7/12/25.
// Copyright 2025 Apple. All rights reserved.

import SwiftUI
import RealityKit

struct Model3DPlaceholderView: View {
    let modelURL: URL?  // Direct URL (local or remote), if provided
    let usdzBookmark: Data?  // Bookmark data for security-scoped local file access, if needed instead of URL
    let windowID: Int

    @State private var resolvedURL: URL?  // The final URL to load, resolved if bookmark was provided
    @State private var errorMessage: String?  // For displaying any resolution errors

    init(modelURL: URL? = nil, usdzBookmark: Data? = nil, windowID: Int) {
        self.modelURL = modelURL
        self.usdzBookmark = usdzBookmark
        self.windowID = windowID
    }

    var body: some View {
        Group {
            if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let url = resolvedURL {
                Model3D(url: url) { model in
                    model
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    VStack {
                        ProgressView()
                            .scaleEffect(2)
                        Text("Loading USDZ Model...")
                            .padding(.top)
                            .font(.headline)
                    }
                }
            } else {
                VStack {
                    ProgressView()
                        .scaleEffect(2)
                    Text("Resolving Model...")
                        .padding(.top)
                        .font(.headline)
                }
            }
        }
        .onAppear {
            resolveURLIfNeeded()
        }
        .onDisappear {
            // Stop accessing if we started it
            resolvedURL?.stopAccessingSecurityScopedResource()
        }
    }

    private func resolveURLIfNeeded() {
        if let url = modelURL {
            // Direct URL provided; use it as-is
            resolvedURL = url
            return
        }

        guard let bookmark = usdzBookmark else {
            errorMessage = "No URL or bookmark provided."
            return
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)

            if isStale {
                // Optionally, handle recreating the bookmark if stale, but for now, proceed
                print("Bookmark is stale; consider refreshing.")
            }

            if url.startAccessingSecurityScopedResource() {
                resolvedURL = url
            } else {
                errorMessage = "Failed to start security-scoped access."
            }
        } catch {
            errorMessage = "Failed to resolve bookmark: \(error.localizedDescription)"
        }
    }
}