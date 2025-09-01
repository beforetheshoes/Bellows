# Bellows Project Instructions for Claude

## Project Overview
Bellows is a SwiftUI exercise tracking app for macOS and iOS that helps users log their daily physical activities with enjoyment and intensity ratings.

## Development Guidelines

### Test-Driven Development (TDD)
- Write tests FIRST before implementing features
- All new features must have corresponding tests
- Tests are located in `BellowsTests/` directory
- Use Swift Testing framework (not XCTest)

### Running Tests
```bash
# Run all tests with xcbeautify for better output
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild test -project Bellows.xcodeproj -scheme Bellows -destination 'platform=macOS' | xcbeautify

# Run all tests quietly (without xcbeautify)
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild test -project Bellows.xcodeproj -scheme Bellows -destination 'platform=macOS' -quiet

# Run specific test with xcbeautify
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild test -project Bellows.xcodeproj -scheme Bellows -destination 'platform=macOS' -only-testing:BellowsTests/[TestFile]/[testName] | xcbeautify
```

### Documentation Lookup
- Use the Sosumi MCP server for Swift and Apple platform documentation
- Access SwiftUI, UIKit, and other Apple framework documentation via:
  - `mcp__sosumi__search` for searching Apple documentation
  - `mcp__sosumi__fetch` for retrieving specific documentation pages
- This is preferred over web searches for Apple-specific APIs

### Building the Project
```bash
# Build with xcbeautify for formatted output
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild build -project Bellows.xcodeproj -scheme Bellows -destination 'platform=macOS' | xcbeautify

# Build quietly (without xcbeautify)
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild build -project Bellows.xcodeproj -scheme Bellows -destination 'platform=macOS' -quiet
```

## Code Style Guidelines

### SwiftUI Best Practices
- Use `@MainActor` for all View-related test functions
- Prefer computed properties over functions when possible
- Use `.modelContainer()` modifier for SwiftData injection
- Follow existing code patterns in the codebase
- **Always use SF Symbols instead of emojis** - The app uses SF Symbols throughout (e.g., "flame", "face.smiling", "figure.walk") for consistency and native platform integration

### Data Models
- All models use SwiftData (`@Model`)
- Models are in `Models.swift`
- Key models: `DayLog`, `ExerciseItem`, `ExerciseType`, `UnitType`
- Always handle optional relationships safely

### View Structure
- Main views: `HomeView`, `DayDetailView`, `HistoryView`, `AppRootView`
- Sheets: `AddExerciseItemSheet`, `EditExerciseItemSheet`
- Reusable components in separate files when appropriate
- Icons: Use SF Symbols via `Image(systemName:)` - never use text emojis
- Available fitness symbols are defined in `SFFitnessSymbols.swift`

## Testing Approach

### Test Organization
Each view has its own test file:
- `HomeViewTests.swift`
- `DayDetailViewTests.swift`
- `HistoryViewTests.swift`
- `ModelsTests.swift`
- etc.

### Test Structure
```swift
struct ViewNameTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    init() {
        // Setup in-memory container
    }
    
    @MainActor
    @Test func testName() {
        // Test implementation
    }
}
```

## Common Tasks

### Adding a New Feature
1. Review related GitHub issue
2. Look up relevant Swift/SwiftUI documentation using Sosumi MCP
3. Write tests first (TDD)
4. Implement the feature
5. Ensure all tests pass (use xcbeautify for readable output)
6. Build and verify

### Fixing Bugs
1. Write a test that reproduces the bug
2. Research the issue using Sosumi MCP for API documentation
3. Fix the bug
4. Verify test now passes
5. Run full test suite with xcbeautify

### Working with SwiftData
- Use in-memory configuration for tests
- Always save context after insertions
- Handle deduplication for ExerciseType and UnitType
- Clean up duplicates on app launch

## Important Notes

### UI Guidelines
- **Never use emoji characters in the UI** - always use SF Symbols
- The app maintains a consistent native look using system symbols
- Common symbols used:
  - `flame` for intensity
  - `face.smiling` for enjoyment
  - `figure.walk`, `figure.run`, etc. for exercise types
  - `plus.circle.fill` for add buttons
- Check `NewExerciseTypeSheet` for the full list of fitness-related SF Symbols

### Deduplication Services
The app includes services to handle duplicate data:
- `DedupService.cleanupDuplicateDayLogs()`
- `DedupService.cleanupDuplicateExerciseTypes()`
- `DedupService.cleanupDuplicateUnitTypes()`

### Seed Data
Default exercise types and units are seeded via:
- `SeedService.seedDefaultExercises()`
- `SeedService.seedDefaultUnits()`

### Date Handling
- Use `Date.startOfDay()` extension for day comparisons
- Store timestamps in `createdAt` fields
- Display times using `.short` timeStyle for locale support

## Version Control
- Do not auto-commit changes
- Wait for explicit user approval before committing
- Follow existing commit message style in the repository
- Test changes thoroughly before suggesting commits

## Platform Support
- iOS 17+
- macOS 14+
- Universal app using SwiftUI