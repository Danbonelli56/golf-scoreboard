# Voice Input Guide for Golf Scoreboard

## Natural Language Voice Input

The app now supports natural language voice input for entering scores! Simply speak naturally and the app will understand and fill in the scorecard.

## Voice Examples

### Player Name Recognition
The app supports **first names**, **last names**, or **full names**:
- **"Hole 1, Dan got a par"** ✅ - Uses first name
- **"Hole 1, Bonelli got a par"** ✅ - Uses last name  
- **"Hole 1, Dan Bonelli got a par"** ✅ - Uses full name
- **Case insensitive** - "dan" works the same as "Dan" or "DAN"

### Automatic Hole Detection 🆕
You can **skip the hole number** and the app will automatically use the first empty hole:
- **"Dan got a par"** - Automatically uses hole 1 (or next empty hole)
- **"Dave got a bogey"** - Automatically uses hole 1 (or next empty hole)
- **"Dan par Dave bogey"** - Both players on first empty hole

This makes it even faster to enter scores as you play!

### Single Player Score
- **"Hole 1, Dan got a par"** - Dan scores par
- **"Hole 5, Dave got a birdie"** - Dave scores one under par
- **"Hole 3, Bonelli got a bogey"** - Using last name
- **"Hole 7, Aginsky got an eagle"** - Using last name
- **"Hole 12, Mike got a double bogey"** - Mike scores two over par

### Multiple Players in One Sentence
- **"Hole 1 Dan got a par and Dave got a bogey"**
- **"Hole 5 John birdied and Jane parred"**
- **"Hole 9 Mike got an eagle and Tom got a double bogey"**

### Absolute Scores
- **"Hole 3 Dan scored 5"**
- **"Hole 7 Bonelli 4"** - Using last name
- **"Hole 12 John scored 6 and Jane 5"**

### Mixed Formats
- **"Hole 2 Dan got par and Dave scored 6"**
- **"Hole 8 John birdied and Mike 5"**

### When Multiple Players Have the Same First Name
- If you have "Dan Bonelli" and "Dan Johnson" playing, use last names:
  - **"Hole 1 Bonelli par"**
  - **"Hole 1 Johnson bogey"**

## How to Use

1. Open the app and start a game
2. Tap the microphone button (🎤) at the bottom of the screen
3. Wait for the recording indicator (red microphone)
4. Speak your score naturally
5. The app will parse and fill in the scorecard automatically

## Supported Golf Terms

### Relative to Par:
- **Albatross / Double Eagle**: 3 under par
- **Eagle**: 2 under par
- **Birdie**: 1 under par
- **Par**: even with par
- **Bogey**: 1 over par
- **Double Bogey**: 2 over par
- **Triple Bogey**: 3 over par

### Variations Accepted:
- "bogey" or "bogie" - both work
- "got a par" or "parred" - both work
- "got a birdie" or "birdied" - both work

## Tips

- Speak clearly and naturally
- Include the hole number first (or skip it for the current hole)
- You can mention multiple players in one sentence
- The app automatically calculates scores from golf terms
- You can mix golf terms and absolute numbers in the same input

## Shot Tracking Voice Input 🆕

You can also use voice input on the **Shot Tracking** tab:

### Basic Shot Recording
- **"Dan driver 250 yards straight"** - Record a shot with details
- **"Hole 2 dave hit driver"** - Specify hole and club
- **"Bonelli 7 iron 150 yards left"** - Using last name

### Shot Results
- **"Dave hit driver right"** - Shot went right
- **"Dan putt straight"** - Putt went straight
- **"Dave hit 3 wood into hazard"** - Shot went into hazard
- **"Dan 9 iron sand trap"** - Shot went into bunker

### Complete Shot Examples
- **"Dan driver 280 yards right on hole 1"**
- **"Dave hit 7 iron 160 yards straight"**
- **"Bonelli putt 15 feet straight"**
- **"Dan driver out of bounds"**

All shot details are automatically extracted and saved!

## Example Conversation Flow

1. "Hole 1 Dan got a par"
2. "Hole 1 Dave got a bogey" 
3. "Hole 2 Dan birdied and Dave parred"
4. "Hole 3 Dan scored 6 and Dave 5"

Or even faster:
- "Hole 1 Dan par Dave bogey"
- "Hole 2 Dan birdie Dave par"

The app is smart enough to understand these natural patterns!

