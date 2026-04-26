# D4: 5 max: 3 -> 5.  SmallInteger>>max: uses if-guarded ^ for
# real conditional control flow inside a user method; not the D3
# eager-arg cheat.
#
# Equivalent Smalltalk-80 source (post-v1):
#   max: n
#     ^ (n < self) ifTrue: [self] ifFalse: [n]
#
# v0 lowering: 'if EXPR' guards the next ^ with JUMP_IF_FALSE,
# falling through to the second ^ on miss.

class SmallInteger
method <
  primitive 4

method max:
  args n
  if n < self
  ^ self
  ^ n
end
