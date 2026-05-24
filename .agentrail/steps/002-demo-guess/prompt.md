# Step: demo-guess

Port the guess-the-number game from `../sw-cor24-basic/examples/guess.bas`
to Smalltalk. The BASIC version uses a driver loop; the Smalltalk version
should use methods that print "higher" / "lower" / "got it in N guesses"
via Transcript.

## Requirements

- Create `examples/guess.st`
- The game picks a secret number (hardcoded is fine for now — no random primitive)
- A `GuessGame` class with methods like `check:` that prints feedback
- Demonstrate the game with a few guesses from a main block
- All existing demos (D1..D8 + hello.st) must regress-pass

## Definition of done

- `examples/guess.st` compiles and runs via `scripts/run-st.sh`
- Output shows "higher", "lower", and "got it" messages
- D1..D8 + hello.st still pass