# Repository Guidelines

## Project Structure & Module Organization
The app follows a lightweight MVVM layout. `LOADApp.swift` wires the SwiftUI scene to `HomeView`. UI components live in `Views/`, grouped by screen. Shared state and business logic sit in `ViewModels/`, with `HomeViewModel` coordinating playback state. `Services/` contains `APIService` for catalog fetching and `AudioPlayerService` for AVFoundation playback. Domain models reside in `Models/`, and static assets are managed in `Assets.xcassets`. Keep new files grouped by feature to preserve this separation.

## Build, Test, and Development Commands
Build locally with:
```sh
xcodebuild -project LOAD.xcodeproj -scheme LOAD -configuration Debug build
```
Run the UI in the simulator via Xcode or:
```sh
xcodebuild -project LOAD.xcodeproj -scheme LOAD -destination "platform=iOS Simulator,name=iPhone 15" build run
```
Execute unit tests (once added) with:
```sh
xcodebuild -project LOAD.xcodeproj -scheme LOAD -destination "platform=iOS Simulator,name=iPhone 15" test
```
Use `xed .` to open the project in Xcode when iterating quickly.

## Coding Style & Naming Conventions
Target Swift 5.9 and SwiftUI best practices. Prefer 4-space indentation and trailing commas in multi-line collections. Name views with a `View` suffix (e.g., `PlayerView`), state containers with `ViewModel`, and asynchronous services with a verb-oriented suffix (`AudioPlayerService`). Favor `struct` for immutable models and `final class` for `ObservableObject` view models. Keep modifiers ordered `.padding` → typography → colors for readability.

## Testing Guidelines
Adopt `XCTest` with a dedicated `LOADTests` target mirroring `LOAD/`. Name test cases `FeatureTests` and methods using `test_whenCondition_expectOutcome`. Stub network calls through injectable protocol abstractions on the services layer. When adding UI logic, consider SwiftUI previews plus unit tests for view models. Aim for high-value coverage around playback control and API serialization paths.

## Commit & Pull Request Guidelines
Use concise, imperative commit subjects (`Add audio session handling`), following the existing short-message history. Reference issues with `#ID` at the end when relevant. Pull requests should include: a one-paragraph summary, bullet list of key changes, simulator screenshots for UI updates, and explicit test evidence (`xcodebuild test` output). Request review from at least one teammate familiar with the feature area and wait for CI green before merging.

## Architecture Notes
Interactions flow View → ViewModel → Service → Model. Keep networking confined to `APIService` and expose async methods returning models. Route playback events exclusively through `AudioPlayerService` to avoid duplicate AVAudioPlayer instances. When introducing new features, extend the view model first, then back the UI updates with preview data to maintain testable seams.
