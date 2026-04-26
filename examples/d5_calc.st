# D5: integer calculator REPL.  Methods are the same five SmallInt
# operations as D4 plus the four arithmetic primitives.  The REPL
# loop in examples/d5_calc.bas patches a fresh "PUSH_INT a; PUSH_INT
# b; SEND op,1; PRIM 5; HALT" template into the bytecode pool every
# iteration and dispatches it.

class SmallInteger
method +
  primitive 1
method -
  primitive 2
method *
  primitive 3
method <
  primitive 4

method max:
  args n
  if n < self
  ^ self
  ^ n
end
