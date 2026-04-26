# D6: 5 fact -> 120 via real recursive SmallInteger>>fact.
# Uses the if-guard JUMP_IF_FALSE lowering so the recursive
# branch is genuinely skipped at the base case (eager-arg
# ifTrue:ifFalse: would loop forever).

class SmallInteger
method +
  primitive 1
method -
  primitive 2
method *
  primitive 3
method <
  primitive 4

method fact
  if 0 < self
  ^ self * (self - 1) fact
  ^ 1

main
  5 fact
end
