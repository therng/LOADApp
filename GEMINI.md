# Project Overview

**LOADApp** is an iOS application built with **SwiftUI** designed for streaming and managing audio tracks. It connects to a custom backend for search and track metadata, while also supporting local file playback and iTunes artwork integration.

## Key Features

*   **Audio Streaming:** Streams audio from a remote source (`nplay.idmp3s.xyz`).
*   **Search & Discovery:** Search for tracks via a dedicated backend API.
*   **History:** Tracks search and playback history.
*   **Local Playback:** Support for playing locally stored audio files.
*   **Visualizer:** Integrated audio visualization.
*   **Background Audio:** configured to continue playing audio when the app is in the background.

## Architecture

The project follows a standard SwiftUI architecture with a separation of concerns:

*   **Views:** Located in `LOAD/Views/`. Contains the UI components (`ContentView`, `QueueView`, `HistoryView`, etc.).
*   **Services:** Located in `LOAD/Services/`.
    *   `APIService`: Singleton responsible for all network interactions (Search, History, Beatport ID lookup).
    *   `AudioPlayerService`: Manages audio playback state and logic.
*   **Models:** Located in `LOAD/Models/`.
    *   `Track`: Core data model representing an audio track (supports both stream and local URLs).
*   **Entry Point:** `LOAD/LOADApp.swift` initializes the app and injects the `AudioPlayerService` into the environment.

## Backend Integration

*   **Primary API:** The app currently points to a development endpoint: `https://postauditory-unmanoeuvred-lizette.ngrok-free.dev`.
*   **Streaming Endpoint:** Audio is streamed from `https://nplay.idmp3s.xyz`.
*   **Artwork:** Fetches high-resolution artwork from the iTunes Search API if not provided.

## Development

### Requirements
*   Xcode 15+ (inferred from modern concurrency usage).
*   iOS 16+ (inferred from structure, though specific deployment target is in project settings).

### Building and Running
This is a standard Xcode project.

1.  Open `LOAD.xcodeproj`.
2.  Select the target device or simulator.
3.  Run (Cmd+R).

### Code Conventions
*   **Concurrency:** Heavy reliance on Swift's `async/await` pattern, particularly in `APIService`.
*   **State Management:** Uses `@StateObject` for services and `@EnvironmentObject` for dependency injection into views.
*   **Parsing:** Uses a custom `StringParsing` utility module.
