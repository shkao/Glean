# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building and Testing
- **Full build and test**: `./buildscripts/build_and_test.sh`
- **Quiet build and test**: `./buildscripts/quiet_build_and_test.sh`
- **Manual Xcode builds**:
  - macOS: `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire -destination "platform=macOS,arch=arm64" build`
  - iOS: `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire-iOS -destination "platform=iOS Simulator,name=iPhone 17" build`
- **OllamaService tests**: `cd Modules/OllamaService && swift test`

### Setup
- First-time setup: Run `./setup.sh` to configure development environment and code signing
- Manual setup: Create `SharedXcodeSettings/DeveloperSettings.xcconfig` in parent directory

## Project Architecture

### High-Level Structure
Glean is a fork of NetNewsWire, an RSS reader extended with AI-powered reading features. It adds local LLM integration (Ollama), screenshot import via OCR, and Chrome tab batch import.

### Key Modules (in /Modules)
- **RSCore**: Core utilities, extensions, and shared infrastructure
- **RSParser**: Feed parsing (RSS, Atom, JSON Feed, RSS-in-JSON)
- **RSWeb**: HTTP networking, downloading, caching, and web services
- **RSDatabase**: SQLite database abstraction layer using FMDB
- **Account**: Account management (Local, Feedbin, Feedly, NewsBlur, Reader API, CloudKit, SavedPages)
- **Articles**: Article and author data models
- **ArticlesDatabase**: Article storage and search functionality
- **SyncDatabase**: Cross-device synchronization state management
- **Secrets**: Secure credential and API key management
- **OllamaService**: Local LLM integration via Ollama REST API (summarize, tag, Q&A)

### Glean-Specific Components
- **SavedPages account type** (`AccountType.savedPages = 30`): stores imported articles from screenshots and Chrome tabs
- **Shared/Importers/**: WebContentExtractor, ScreenshotImporter, URLExtractor, BulkURLImporter
- **Intents/ImportURLsIntent.swift**: AppIntents action for Shortcuts-based Chrome tab import
- **OllamaService**: Standalone Swift Package for LLM features (summarize, tag, Q&A with streaming)

### Platform-Specific Code
- **Mac/**: macOS-specific UI (AppKit), preferences, main window management
- **iOS/**: iOS-specific UI (UIKit), settings, navigation
- **Shared/**: Cross-platform business logic, article rendering, smart feeds

### Key Architectural Patterns
- **Account System**: Pluggable account delegates for different sync services
- **Feed Management**: Hierarchical folder/feed organization with OPML import/export
- **Article Rendering**: Template-based HTML rendering with custom CSS themes
- **Smart Feeds**: Virtual feeds (Today, All Unread, Starred) implemented as PseudoFeed protocol
- **Timeline/Detail**: Classic three-pane interface (sidebar, timeline, detail)
- **Extension Communication**: App group container for sharing data between main app and extensions

## Code Formatting

Prefer idiomatic modern Swift.

Prefer `if let x` and `guard let x` over `if let x = x` and `guard let x = x`.

Don't use `...` or `...` in Logger messages.

Guard statements should always put the return in a separate line.

Don't do force unwrapping of optionals.

## Things to Know

Just because unit tests pass doesn't mean a given bug is fixed. It may not have a test. It may not even be testable, it may require manual testing.

The Xcode project file (NetNewsWire.xcodeproj) retains the upstream name for merge compatibility. Product names and bundle IDs are set to "Glean" via xcconfig files.

Bundle IDs use `com.shkao.Glean.*` (configured in xcconfig/). App groups use `group.com.shkao.Glean.*`.
