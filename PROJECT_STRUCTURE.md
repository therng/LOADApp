# Project Structure

This document outlines the structure of the LOADApp project directory.

## Folder Structure

```
- /Artist          # Contains artist-related components and views
- /Search          # Components and views for the search functionality
- /TrackFeed       # Manages the track feed feature
- /Components      # Reusable UI components used throughout the app
- /Services        # Includes service classes like APIService and AudioPlayerService
- /Models          # Data models for handling app data
- GEMINI.md        # Documentation or guidelines for the project
- .gitignore       # Files and directories to ignore in the Git repository
```

## Guidelines

1. Follow the modular structure: each feature should reside within its respective folder.
2. Reuse components from the `Components` folder wherever applicable.
3. Keep services and models lightweight and focused on their respective tasks.