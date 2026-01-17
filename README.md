# Kanji Memory iOS App

A native iOS app for learning Japanese kanji using WaniKani's spaced repetition system and AI-powered mnemonics.

## Features

- **2000+ Kanji** - All WaniKani levels 1-60 bundled
- **499 Radicals** - Complete radical library
- **6650+ Vocabulary** - Extensive vocabulary coverage
- **WaniKani Sync** - Sync progress with your WaniKani account
- **SRS Reviews** - Spaced repetition review system
- **AI Mnemonics** - Generate custom mnemonics using AI
- **AI Images** - Create visual memory aids with DALL-E
- **Offline Support** - Works without internet connection

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

### 1. Install XcodeGen (if not already installed)

```bash
brew install xcodegen
```

### 2. Generate Xcode Project

```bash
cd kanji-memory-ios
xcodegen generate
```

### 3. Open in Xcode

```bash
open KanjiMemory.xcodeproj
```

### 4. Configure Signing

1. Open project settings in Xcode
2. Select the KanjiMemory target
3. Go to "Signing & Capabilities"
4. Select your development team
5. Enable "Sign in with Apple" capability

### 5. Run the App

Select a simulator or device and press Cmd+R to run.

## Project Structure

```
kanji-memory-ios/
├── KanjiMemory/
│   ├── App/
│   │   ├── KanjiMemoryApp.swift      # App entry point
│   │   └── ContentView.swift          # Main tab view
│   ├── Models/
│   │   ├── Kanji.swift                # Kanji model + SwiftData
│   │   ├── Radical.swift              # Radical model
│   │   ├── Vocabulary.swift           # Vocabulary model
│   │   └── User.swift                 # User settings + preferences
│   ├── Services/
│   │   ├── DataManager.swift          # Bundled data loader
│   │   ├── WaniKaniService.swift      # WaniKani API client
│   │   ├── APIService.swift           # Backend API client
│   │   └── SRSCalculator.swift        # SRS algorithm
│   ├── Views/
│   │   ├── Home/
│   │   │   └── HomeView.swift
│   │   ├── Levels/
│   │   │   ├── LevelsView.swift
│   │   │   └── LevelDetailView.swift
│   │   ├── KanjiDetail/
│   │   │   ├── KanjiDetailView.swift
│   │   │   ├── RadicalDetailView.swift
│   │   │   └── VocabularyDetailView.swift
│   │   ├── Reviews/
│   │   │   ├── ReviewsView.swift
│   │   │   └── ReviewSessionView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── Storage/                        # SwiftData configuration
│   ├── Utilities/
│   └── Resources/
│       ├── Assets.xcassets
│       └── Data/
│           ├── kanji_all.json          # 2083 kanji
│           ├── radicals_all.json       # 499 radicals
│           ├── vocabulary_all.json     # 6650 vocabulary
│           ├── radical_char_map.json   # Radical name → character
│           └── metadata.json
├── scripts/
│   └── convert-data.js                 # Data conversion script
├── project.yml                         # XcodeGen configuration
└── README.md
```

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS App (SwiftUI)                      │
├─────────────────────────────────────────────────────────────┤
│  • Local SwiftData for kanji/progress cache                 │
│  • Direct WaniKani API calls                                │
│  • SRS review system                                        │
│  • Native UI/UX                                             │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Slim API (Vercel/Next.js)                  │
├─────────────────────────────────────────────────────────────┤
│  • AI mnemonic generation (Gemini)                          │
│  • AI image generation (DALL-E)                             │
│  • Image storage (Vercel Blob)                              │
│  • User data sync (PostgreSQL)                              │
└─────────────────────────────────────────────────────────────┘
```

### State Management

- **SwiftData** for persistent storage
- **@Observable** for view models
- **@StateObject** for shared services

### Key Technologies

- SwiftUI + SwiftData
- Async/await for networking
- Sign in with Apple
- StoreKit 2 for IAP

## API Endpoints

The app communicates with a slim backend for AI features:

### Authentication
```
POST /api/auth/apple
  Body: { identityToken, authorizationCode }
  → Returns: { userId, accessToken, user }
```

### AI Generation
```
POST /api/ai/mnemonic
  Body: { character, meanings, readings, style, interests }
  → Returns: { mnemonic }

POST /api/ai/image
  Body: { character, mnemonic, style }
  → Returns: { imageUrl }
```

### User Data
```
GET  /api/user/profile
PUT  /api/user/preferences
GET  /api/images/{character}
POST /api/images/upload
```

## Updating Bundled Data

To regenerate the bundled JSON files from the web app:

```bash
cd scripts
node convert-data.js
```

This will read from the Next.js web app's data and generate optimized JSON files for the iOS app.

## Testing

```bash
# Run unit tests
xcodebuild test -scheme KanjiMemory -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -scheme KanjiMemory -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:KanjiMemoryUITests
```

## Deployment

1. Update version in project.yml
2. Generate project: `xcodegen generate`
3. Archive in Xcode: Product → Archive
4. Upload to App Store Connect

## License

MIT License - See LICENSE file for details.
