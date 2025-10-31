# Troubleshooting Guide

## Issue: Scores Not Appearing on Scorecard

### Most Common Causes:

1. **Player Name Mismatch**
   - The parser now supports both first names and full names
   - For players "Dan Bonelli" and "Dave Aginsky", you can say:
     - "Hole 1 Dan par" ✅ (uses first name)
     - "Hole 1 Dan Bonelli par" ✅ (uses full name)
     - "Hole 1 dave bogey" ✅ (case insensitive)

2. **No Active Game**
   - Make sure you've created and started a game
   - Check that the game is selected on the scorecard screen

3. **Players Not Added to Game**
   - When creating a new game, make sure to select players
   - The "Start" button will be disabled if no players are selected

### Debugging:

The app now includes detailed console logging. To see what's happening:

1. Run the app in Xcode
2. Open the Console (View → Debug Area → Console)
3. Type your input and submit
4. Look for debug messages with emojis:
   - 🔍 = Parsing started
   - 👤 = Checking players
   - ✅ = Success
   - ❌ = Problem found
   - 💾 = Saving score

### Example Console Output (Success):

```
🔍 Parsing: 'hole 1 dan par'
🎮 Game has 2 players: ["Dan Bonelli", "Dave Aginsky"]
✅ Hole number: 1
⛳ Hole 1 is par 4
👤 Checking player: 'Dan Bonelli' (first name: 'dan')
  ✅ Found player 'Dan Bonelli' in text
  ✅ Found relative score: par = 4
  💾 Saving score: Dan Bonelli -> 4
  📝 Creating new hole score
  ✅ Score saved successfully!
👤 Checking player: 'Dave Aginsky' (first name: 'dave')
  ❌ Player 'Dave Aginsky' not found in text
```

### If Still Not Working:

1. Check the console output to see where it's failing
2. Make sure the player names in your input match the first name or full name
3. Verify the hole number and golf term are correct
4. Ensure you have an active game with the course and players set up

