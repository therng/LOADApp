# LOADApp Documentation

## Target Platform
**iOS 26+ (SwiftUI Deployment Target 26)**
This project is built using modern SwiftUI APIs available in iOS 26 and later. Legacy support code for earlier iOS versions is not required and should not be added.

## Architecture

### Views (`LOAD/Views/`)
- **ContentView**: Main entry point using the new `TabView` syntax with `Tab` struct and `.sidebarAdaptable` style.
- **SearchView**: Unified search interface that defaults to `HistoryView` when idle and pushes to `HistoryDetailView` on search result selection.
- **FullPlayerView / MiniPlayerView**: Audio playback controls.
- **ArtistDetailView / AlbumDetailView**: Content browsing views.

### Models (`LOAD/Models/`)
- **Track**: Core audio track model.
- **SearchResponse**: Structure for API search results.
- **iTunesSearchResult**: Structure for iTunes API results.

### Services (`LOAD/Services/`)
- **AudioPlayerService**: Singleton managing AVPlayer/AVAudioPlayer, queue, and playback state.
- **APIService**: Handles networking for custom backend and iTunes Search API.
- **Haptics**: Centralized haptic feedback engine.

### ViewModels (`LOAD/ViewModels/`)
- **SearchModel**: Manages search state, results, and navigation triggers.

## Key Features & Implementations

### Navigation
- Uses `NavigationStack` within tabs.
- **Search**: `SearchView` uses `.searchable` with `placement: .navigationBarDrawer`.
- **Transitions**: Uses `.navigationTransition(.zoom(...))` for player expansion (iOS 18+ API).

### Audio Playback
- **Dual Backend**: Supports both `AVPlayer` (streaming) and `AVAudioPlayer` (local files).
- **Background Audio**: Configured via `Info.plist` and `AVAudioSession`.
- **Lock Screen Controls**: Integrated with `MPRemoteCommandCenter`.

### API & Data
- **Custom Backend**: `https://postauditory-unmanoeuvred-lizette.ngrok-free.dev`
- **Streaming**: `https://nplay.idmp3s.xyz`
- **iTunes API**: Used for artwork and artist album fetching.

### UI Components
- **ArtworkView**: Unified component for displaying track/album art with consistent styling.
- **TrackRow**: Reusable row for track lists.
- **TrackActionMenuItems**: Context menu for track actions (Queue, Beatport Search, etc.).

## Development Guidelines

- **SwiftUI Only**: Avoid UIKit wrappers unless absolutely necessary (e.g., `SFSafariViewController`).
- **Concurrency**: Use `async/await` for all asynchronous operations.
- **State Management**: Use `@StateObject` for view-owned models and `@EnvironmentObject` for shared services.
- **Style**: Follow the "Sidebar Adaptable" pattern for `TabView` to ensure cross-device consistency (iPhone/iPad).
