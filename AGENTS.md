# Repository Guidelines

## Project Structure & Module Organization
- `LOAD/LOADApp.swift` is the app entry and root environment setup.
- `LOAD/Views/` holds SwiftUI screens and reusable view components.
- `LOAD/Services/` contains networking, audio, and persistence helpers.
- `LOAD/Models/` defines shared data types like `Track`.
- `LOAD/Assets.xcassets/` stores images, icons, and colors.
- `LOAD/Info.plist` and `LOAD.xcodeproj` keep app and project metadata.

## Build, Test, and Development Commands
- `open LOAD.xcodeproj` to run in Xcode (preferred for simulator/device).
- `xcodebuild -project LOAD.xcodeproj -scheme LOAD -destination 'platform=iOS Simulator,name=iPhone 15' build` to compile from the CLI.
- `xcodebuild -project LOAD.xcodeproj -scheme LOAD -destination 'platform=iOS Simulator,name=iPhone 15' test` once a test target exists.

## Coding Style & Naming Conventions
- Use 4-space indentation, SwiftUI patterns, and `// MARK:` section labels.
- Types and files use PascalCase (`AudioPlayerService.swift`); properties and methods use lowerCamelCase.
- Services commonly use a `static let shared` singleton; keep new services consistent with that pattern.
- Keep API endpoints centralized in `LOAD/Services/APIService.swift`.

## Testing Guidelines
- No unit or UI tests are currently checked in.
- If adding tests, create `LOADTests` and/or `LOADUITests` targets and name files `*Tests.swift`.
- Prioritize coverage of service logic and models before UI-only tests.

## Commit & Pull Request Guidelines
- Commit messages in history are short, lowercase, and descriptive; follow the same style.
- PRs should include a brief summary, UI screenshots for view changes, and any API or endpoint notes.
- Confirm the app builds in Xcode before requesting review.

## Configuration Notes
- The backend base URL lives in `LOAD/Services/APIService.swift`; avoid committing secrets or tokens.
- Asset changes should update `Assets.xcassets` and keep icon sizes intact.
