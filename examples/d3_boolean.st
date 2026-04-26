# D3: 5 < 10 ifTrue: 42 ifFalse: 0
# Polymorphic dispatch on True / False classes.  Each one has its
# own ifTrue:ifFalse: method; True returns the first arg, False
# the second.  Eager-arg semantics in v0 (both branches evaluated
# at the call site by the driver before the SEND fires).

class SmallInteger
method <
  primitive 4

class True
method ifTrue:ifFalse:
  args t f
  ^ t

class False
method ifTrue:ifFalse:
  args t f
  ^ f
end
