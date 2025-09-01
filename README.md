# Bellows

A SwiftUI exercise tracking app that helps you fan the flames of your fitness journey.

## Features

- **Exercise Logging**: Track various types of physical activities with customizable units (minutes, reps, miles, steps)
- **Enjoyment & Intensity Ratings**: Rate each exercise on a 1-5 scale for both enjoyment and intensity
- **Streak Tracking**: Visual motivation with flame animations showing your consecutive days of activity
- **Daily Summaries**: View average enjoyment and intensity scores for each day
- **History View**: Browse past workouts and see patterns over time
- **Timestamp Display**: Each logged exercise shows when it was completed
- **Cross-Platform**: Native support for both macOS and iOS

## Screenshots

The app features a clean, native design with:
- Home view showing today's exercises and current streak
- Exercise entry sheets with picker controls
- History view for browsing past activities
- Detailed day views with exercise breakdowns

## Requirements

- macOS 14.0+ or iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/beforetheshoes/Bellows.git
cd Bellows
```

2. Open in Xcode:
```bash
open Bellows.xcodeproj
```

3. Select your target device (Mac or iOS Simulator)
4. Build and run (⌘R)

## Architecture

### Technology Stack
- **SwiftUI** for the user interface
- **SwiftData** for persistence and data modeling
- **Swift Testing** framework for comprehensive test coverage

### Key Components

#### Data Models
- `DayLog`: Represents a single day's exercise activities
- `ExerciseItem`: Individual exercise entry with amount, ratings, and timestamp
- `ExerciseType`: Types of exercises (Walk, Run, Yoga, etc.)
- `UnitType`: Measurement units (Minutes, Reps, Miles, etc.)

#### Views
- `HomeView`: Main dashboard showing today's exercises and streak
- `DayDetailView`: Detailed view of a specific day's activities
- `HistoryView`: Calendar-style navigation of past exercise logs
- `AppRootView`: Tab-based navigation container

#### Services
- `Analytics`: Streak calculation and statistics
- `SeedService`: Default data initialization
- `DedupService`: Data deduplication utilities

## Development

### Prerequisites
- Install `xcbeautify` for better formatted test output:
  ```bash
  brew install xcbeautify
  ```

### Running Tests
```bash
# Run all tests with formatted output
xcodebuild test -project Bellows.xcodeproj -scheme Bellows -destination 'platform=macOS' | xcbeautify

# Run specific test file
xcodebuild test -project Bellows.xcodeproj -scheme Bellows -destination 'platform=macOS' -only-testing:BellowsTests/HomeViewTests | xcbeautify
```

### Building
```bash
# Build with formatted output
xcodebuild build -project Bellows.xcodeproj -scheme Bellows -destination 'platform=macOS' | xcbeautify
```

## Contributing

We welcome contributions! Please follow these guidelines:

1. **Test-Driven Development**: Write tests before implementing features
2. **Code Style**: Follow existing patterns in the codebase
3. **Documentation**: Update relevant documentation with your changes
4. **Issues First**: Check existing issues or create one before starting work

### Development Process
1. Pick an issue from the GitHub issues page
2. Create a feature branch
3. Write tests for your feature
4. Implement the feature
5. Ensure all tests pass
6. Submit a pull request

## Features Roadmap

- [ ] Calendar view with exercise indicators
- [ ] Default units based on exercise type
- [ ] Water intake tracking
- [ ] Data export/import functionality
- [ ] Dark/light theme support
- [ ] Apple Health integration
- [ ] Exercise intensity affecting flame animations
- [ ] More prominent streak display

## License

This project is proprietary software. All rights reserved.

## Acknowledgments

Built with the assistance of Claude Code.

## Support

For issues, feature requests, or questions, please visit the [GitHub Issues](https://github.com/beforetheshoes/Bellows/issues) page.