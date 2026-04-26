#!/usr/bin/awk -f
# stc.awk - COR24 Smalltalk source compiler for v0
#
# Reads a .st file on stdin, writes an image_*.bas file to stdout.
# Output format matches what src/vm.bas's read_and_install_methods
# (line 10800) consumes: a bootstrap GOSUB header plus DATA records
# of <class> <selector> <bytecount> <bytes...> terminated by -1.
#
# Syntax (subset, see docs/st-source.md):
#   class CLASSNAME [extends PARENT] [slots VAR1 VAR2 ...]
#   method SELECTOR
#     [args ARG1 ARG2 ...]
#     <statement>
#     <statement>
#   method ...
#   class ...
#   end
#
# Statements:
#   ^ <expr>            (return)
#   var := <expr>       (assign to slot)
#   primitive N         (primitive method body shortcut)
#   if <expr>           (guard the next ^ with JUMP_IF_FALSE)
#
# Expressions:
#   expr   = unary { binop unary }       (binary, left-to-right)
#   unary  = atom { unary-id }            (unary, left-to-right, tighter than binary)
#   atom   = self | int | name | "(" expr ")"
#   binop  in { + - * < = }
#   unary-id = identifier in selector table (and not a binop, not keyword)

BEGIN {
  # Selector ID table.  Keep aligned with docs/st-source.md.
  sel["+"]                = 1
  sel["-"]                = 2
  sel["*"]                = 3
  sel["<"]                = 4
  sel["print"]            = 5
  sel["init"]             = 6
  sel["incr"]             = 7
  sel["value"]            = 8
  sel["ifTrue:ifFalse:"]  = 9
  sel["at:"]              = 10
  sel["at:put:"]          = 11
  sel["="]                = 12
  sel["new"]              = 13
  sel["max:"]             = 14
  sel["fact"]             = 15

  is_binary["+"] = 1
  is_binary["-"] = 1
  is_binary["*"] = 1
  is_binary["<"] = 1
  is_binary["="] = 1

  # Class ID table.
  cls["Object"]            = 0
  cls["Class"]             = 1
  cls["SmallInteger"]      = 2
  cls["True"]              = 3
  cls["False"]             = 4
  cls["UndefinedObject"]   = 5
  cls["Array"]             = 6
  cls["Symbol"]            = 7
  cls["Method"]            = 8
  cls["Block"]             = 9
  cls["Counter"]           = 10
  cls["BoundedCounter"]    = 11

  # Compiler state.
  cur_class = ""
  cur_slot_n = 0
  cur_method = ""
  cur_arg_n = 0
  body_n = 0
  meth_n = 0
  if_pending = -1
  super_n = 0
}

# Strip comments and trailing periods; normalise whitespace; split parens.
{
  sub(/#.*$/, "")
  gsub(/\./, "")
  gsub(/\t/, " ")
  gsub(/\(/, " ( ")
  gsub(/\)/, " ) ")
  sub(/^[ ]+/, "")
  sub(/[ ]+$/, "")
}

NF == 0 { next }

# class CLASSNAME [extends PARENT] [slots V1 V2 ...]
$1 == "class" {
  finish_method()
  finish_class()
  cur_class = $2
  if (!(cur_class in cls)) {
    print "stc: unknown class: " cur_class > "/dev/stderr"
    exit 1
  }
  cur_slot_n = 0
  i = 3
  if (i <= NF && $i == "extends") {
    parent = $(i+1)
    if (!(parent in cls)) {
      print "stc: unknown parent class: " parent > "/dev/stderr"
      exit 1
    }
    if (parent in class_slots_str) {
      n = split(class_slots_str[parent], inherited, " ")
      for (k = 1; k <= n; k++) {
        if (inherited[k] != "") cur_slots[cur_slot_n++] = inherited[k]
      }
    }
    super_child[super_n] = cls[cur_class]
    super_parent[super_n] = cls[parent]
    super_n++
    i += 2
  }
  if (i <= NF && $i == "slots") {
    for (j = i+1; j <= NF; j++) cur_slots[cur_slot_n++] = $j
  }
  s = ""
  for (k = 0; k < cur_slot_n; k++) s = (k == 0 ? cur_slots[k] : s " " cur_slots[k])
  class_slots_str[cur_class] = s
  next
}

# method SELECTOR
$1 == "method" {
  finish_method()
  cur_method = $2
  if (!(cur_method in sel)) {
    print "stc: unknown selector: " cur_method > "/dev/stderr"
    exit 1
  }
  body_n = 0
  cur_arg_n = 0
  if_pending = -1
  next
}

# args ARG1 ARG2 ...
$1 == "args" {
  for (i = 2; i <= NF; i++) cur_args[cur_arg_n++] = $i
  next
}

# end
$1 == "end" {
  finish_method()
  finish_class()
  next
}

# primitive N
$1 == "primitive" {
  body[body_n++] = 13           # PRIMITIVE
  body[body_n++] = $2 + 0
  body[body_n++] = 8            # RETURN_TOP
  next
}

# if <expr>
$1 == "if" {
  parse_expr(2)
  body[body_n++] = 11           # JUMP_IF_FALSE
  body[body_n++] = 0            # placeholder
  if_pending = body_n - 1
  next
}

# ^ <expr>
$1 == "^" {
  parse_expr(2)
  body[body_n++] = 8            # RETURN_TOP
  if (if_pending >= 0) {
    body[if_pending] = body_n - (if_pending + 1)
    if_pending = -1
  }
  next
}

# var := <expr>
$2 == ":=" {
  parse_expr(3)
  body[body_n++] = 6            # STORE_FIELD
  body[body_n++] = slot_index($1)
  next
}

{
  print "stc: cannot compile line: " $0 > "/dev/stderr"
  exit 1
}

function finish_method(    i) {
  if (cur_method == "") return
  if (if_pending >= 0) {
    print "stc: method ended with unresolved 'if' guard" > "/dev/stderr"
    exit 1
  }
  m_class[meth_n] = cls[cur_class]
  m_sel[meth_n] = sel[cur_method]
  m_len[meth_n] = body_n
  for (i = 0; i < body_n; i++) m_body[meth_n, i] = body[i]
  meth_n++
  cur_method = ""
  body_n = 0
  cur_arg_n = 0
}

function finish_class() {
  cur_class = ""
  cur_slot_n = 0
}

# expr -> unary { binop unary }   left-to-right.  Returns next-position.
function parse_expr(idx,    cur, op) {
  cur = parse_unary(idx)
  while (cur <= NF && ($cur in is_binary)) {
    op = $cur
    cur = parse_unary(cur + 1)
    body[body_n++] = 7          # SEND
    body[body_n++] = sel[op]
    body[body_n++] = 1          # argc 1
  }
  return cur
}

# unary -> atom { unary-id }
function parse_unary(idx,    cur, name) {
  cur = parse_atom(idx)
  while (cur <= NF) {
    name = $cur
    if (name == ")" || name == "(") break
    if (name in is_binary) break
    if (name ~ /:/) break
    if (!(name in sel)) break
    body[body_n++] = 7          # SEND
    body[body_n++] = sel[name]
    body[body_n++] = 0          # argc 0
    cur++
  }
  return cur
}

function parse_atom(idx,    a, n, cur) {
  a = $idx
  if (a == "(") {
    cur = parse_expr(idx + 1)
    if (cur > NF || $cur != ")") {
      print "stc: missing close paren in: " $0 > "/dev/stderr"
      exit 1
    }
    return cur + 1
  }
  if (a == "self") {
    body[body_n++] = 1          # PUSH_SELF
    return idx + 1
  }
  if (a ~ /^-?[0-9]+$/) {
    body[body_n++] = 12         # PUSH_INT
    body[body_n++] = a + 0
    return idx + 1
  }
  for (n = 0; n < cur_arg_n; n++) {
    if (cur_args[n] == a) {
      body[body_n++] = 3        # PUSH_TEMP
      body[body_n++] = n
      return idx + 1
    }
  }
  n = slot_index(a)
  if (n >= 0) {
    body[body_n++] = 5          # PUSH_FIELD
    body[body_n++] = n
    return idx + 1
  }
  print "stc: unknown atom: " a > "/dev/stderr"
  exit 1
}

function slot_index(name,    i) {
  for (i = 0; i < cur_slot_n; i++) if (cur_slots[i] == name) return i
  return -1
}

END {
  finish_method()
  finish_class()

  print "100 REM === IMAGE GENERATED BY tools/stc.awk =================="
  print "110 GOSUB 10100"
  print "115 GOSUB 10700"
  ln = 120
  for (i = 0; i < super_n; i++) {
    print ln " LET K(" super_child[i] ") = " super_parent[i]
    ln += 1
  }
  print ln " RESTORE"           ; ln += 1
  print ln " GOSUB 10800"       ; ln += 1
  print ln " RETURN"

  ln = 500
  for (i = 0; i < meth_n; i++) {
    # Build a flat list of values for this method's record:
    # <class> <sel> <bytecount> <byte0> <byte1> ... <byteN-1>
    n_items = 3 + m_len[i]
    items[0] = m_class[i]
    items[1] = m_sel[i]
    items[2] = m_len[i]
    for (j = 0; j < m_len[i]; j++) items[3 + j] = m_body[i, j]

    # Emit DATA lines, chunking to stay under BASIC's 80-char input
    # limit.  read_and_install_methods at vm.bas:10800 doesn't care
    # which DATA line a value comes from; the reader walks every
    # DATA line in source order.
    k = 0
    while (k < n_items) {
      line = ""
      content_len = 0
      while (k < n_items) {
        v = items[k] ""
        sep_len = (line == "" ? 0 : 2)
        if (content_len + sep_len + length(v) > 65 && line != "") break
        line = (line == "" ? v : line ", " v)
        content_len += sep_len + length(v)
        k++
      }
      print ln " DATA " line
      ln += 1
    }
  }
  print ln " DATA -1, 0, 0"
}
