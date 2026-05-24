# Guess-the-number game.
# A GuessGame holds a secret; check: prints higher/lower/got it.
# Run with: ./scripts/run-st.sh examples/guess.st

class SmallInteger
method <
  primitive 4

class GuessGame slots secret
method init
  secret := 42.
  ^ self
method check:
  args guess
  if guess < secret
  ^ Transcript show: 'higher'
  if secret < guess
  ^ Transcript show: 'lower'
  ^ Transcript show: 'got it'

main
  GuessGame new init check: 20
  Transcript cr.
  GuessGame new init check: 50
  Transcript cr.
  GuessGame new init check: 42
end
