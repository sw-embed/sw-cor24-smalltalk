# D7: BoundedCounter caps at 5.  init / value inherited from Counter
# via the superclass walk in src/vm.bas's LOOKUP; only incr is
# overridden on the subclass.

class SmallInteger
method +
  primitive 1
method <
  primitive 4

class Counter slots value
method init
  value := 0.
  ^ self
method value
  ^ value

class BoundedCounter extends Counter
method incr
  if value < 5
  value := value + 1.
  ^ self
  ^ self
end
