# D1: 3 + 4.  Just SmallInteger>>+.
# The driver in examples/d1_add.bas hand-assembles the top-level
# bytecode that does PUSH_INT 3; PUSH_INT 4; SEND +,1; PRIM 5; HALT.

class SmallInteger
method +
  primitive 1
end
