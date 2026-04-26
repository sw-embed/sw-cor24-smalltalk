# D2: Counter, the canonical user-defined-class demo.
# Compiles via tools/stc.awk to a DATA-record image equivalent to
# the hand-written src/image_d2.bas.

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
end
