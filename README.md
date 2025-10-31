# Golf Scoreboard - iOS App

A comprehensive golf score tracking app for iPhone and iPad built with SwiftUI and SwiftData.

## Features

### 📊 Scorecard Management
- Create and manage multiple golf courses with hole details (par, handicap, tee distances)
- Store course information including slope rating and course rating
- Track scores for up to multiple players simultaneously

### 🎯 Score Tracking
- Input scores via text or voice recognition
- Automatic calculation of:
  - Front 9 scores (holes 1-9)
  - Back 9 scores (holes 10-18)
  - Total 18-hole scores
  - Gross and Net scores (with handicap adjustment)

### 🗣️ Voice Recognition
- Hands-free score input using natural language
- Golf term recognition (par, birdie, bogey, eagle, etc.)
- Multiple players in one sentence: "Hole 1 Dan got a par and Dave got a bogey"
- Absolute score input: "Hole 5 John scored 6"
- Smart parsing automatically calculates scores from golf terms
- Microphone and speech recognition permissions included

### 🏌️ Shot Tracking
- Detailed shot-by-shot tracking for each hole
- Capture:
  - Distance to the hole
  - Club used
  - Shot result (straight, right, left, out of bounds, hazard, trap)
  - Number of putts
- Shot analysis and summaries per game and across multiple games

### 👥 Player Management
- Add and manage players with custom handicaps
- Set current user for default shot tracking
- Player statistics and scoring history

### 📈 Data Analysis
- Shot summaries by club, result, and distance
- Statistics tracking across multiple rounds
- Visual scorecard interface

## App Structure

### Tab Navigation
1. **Scorecard** - Main score tracking interface
2. **Shots** - Detailed shot tracking and analysis
3. **Courses** - Golf course management
4. **Players** - Player roster and handicaps

### Data Models

#### GolfCourse
- Course name, slope rating, course rating
- 18 holes with par and handicap
- Tee distances by color/type

#### Player
- Name and handicap
- Current user designation

#### Game
- Links to course and players
- Hole-by-hole scores
- Automatic front/back 9 and total calculations

#### Shot
- Detailed shot information
- Distance, club, result
- Putt tracking

## Getting Started

### Setting Up a Game

1. **Add a Course** (Courses tab → Add Course)
   - Enter course name
   - Set slope and rating
   - Default 18 holes will be created automatically

2. **Add Players** (Players tab → Add Player)
   - Enter player name
   - Set handicap
   - Mark as "Current User" for default shot tracking

3. **Start a Game** (Scorecard tab → New Game)
   - Select course
   - Choose players
   - Start tracking

### Entering Scores

#### Voice Input
Tap the microphone button and say:
- "Hole 5, John, 4"
- "Hole 8, Jane, 5"

#### Text Input
Type in the format: `Hole [number], [Player name], [score]`

#### Manual Entry
Tap any cell on the scorecard to enter scores manually

### Tracking Shots

1. Go to Shots tab
2. Select game and hole
3. Tap "Add Shot" for each shot taken
4. Enter:
   - Player
   - Shot number
   - Distance to hole
   - Club used
   - Shot result
   - Mark if it's a putt

## Technical Details

### Requirements
- iOS 17.0+
- Swift 5.9+
- Xcode 15+

### Permissions
- Microphone access for voice recognition
- Speech recognition permission

### Data Storage
- SwiftData for local data persistence
- All data stored locally on device

## Future Enhancements

### Planned Features (Version 2.0)
- Game types: Best Ball, Skins, Match Play
- Advanced statistics and trends
- Course comparison across multiple rounds
- Handicap calculations based on course slope
- Leaderboards and competitive tracking
- Export scores to PDF
- Share scorecards with other players

## Voice Command Examples

- "Hole 1, John, 4"
- "Hole 5, Mike, 6"  
- "Hole 10, player name, 5"

The app intelligently parses natural language to extract:
- Hole number
- Player name
- Score

## Support

For issues or feature requests, please refer to the project documentation or contact support.

## License

Copyright © 2025 Daniel Bonelli. All rights reserved.

