# D2: Counter, the canonical user-defined-class demo.
# Compiles to a complete program (image + main + driver stub).
# Run with: ./scripts/run-st.sh examples/d2_counter.st

class SmallInteger
method +
  primitive 1

class Counter slots value
method init
  value := 0.
  ^ self
method incr
  value := value + 1.
  ^ self
method value
  ^ value

main
  Counter new init incr incr value
end
