#!/usr/bin/awk -f
# stc.awk - COR24 Smalltalk source compiler for v0
#
# Reads a .st file on stdin, writes a complete BAS file on stdout
# that, when concatenated with src/vm.bas, runs the program end
# to end.
#
# Output sections:
#   1..99       driver stub: init E/S/F, GOSUB image install, load
#               main bytecode from DATA into O(64..), set M/L/P/R,
#               GOSUB 12000, end
#   100..150    image bootstrap header (GOSUBs to install_singletons,
#               init_methdict, optional class_super POKEs, then
#               read_and_install_methods)
#   500..       method-dictionary DATA records
#   600..       main-block bytecode DATA
#   trailing    RUN / BYE
#
# Syntax (subset, see docs/st-source.md):
#   class CLASSNAME [extends PARENT] [slots VAR1 VAR2 ...]
#   method SELECTOR
#     [args ARG1 ARG2 ...]
#     <statement>
#     <statement>
#   ...
#   main
#     <value-statement>      (each one printed=last or POP'd)
#     <value-statement>
#     ...
#   end
#
# Statements (in methods):
#   ^ <expr>            (return)
#   var := <expr>       (assign to slot)
#   primitive N         (primitive method body shortcut)
#   if <expr>           (guard the next ^ with JUMP_IF_FALSE)
#
# Statements (in main):
#   <expr>              (value statement; last is auto-printed,
#                        others are POP'd)
#
# Expressions:
#   expr   = unary { binop unary } { keyword arg }
#   unary  = atom { unary-id }
#   atom   = self | int | name | "(" expr ")" | classname "new"
#   binop  in { + - * < = }
#   keyword = identifier ending in ":" (one or more parts make
#             one selector like ifTrue:ifFalse:)

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

  # Default ivar counts for built-in classes (zero unless user
  # redeclares with slots).  Counter and BoundedCounter get
  # populated by the user's class declaration.
  for (k in cls) class_ivar_n[k] = 0

  cur_class = ""
  cur_slot_n = 0
  cur_method = ""
  cur_arg_n = 0
  body_n = 0
  meth_n = 0
  if_pending = -1
  super_n = 0
  in_main = 0
  main_n = 0
  main_last_pop_pos = -1
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
  class_ivar_n[cur_class] = cur_slot_n
  next
}

# method SELECTOR
$1 == "method" {
  finish_method()
  finish_main()
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

# main
$1 == "main" {
  finish_method()
  finish_main()
  in_main = 1
  body_n = 0
  cur_arg_n = 0
  if_pending = -1
  main_last_pop_pos = -1
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
  finish_main()
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
  if (in_main) {
    print "stc: 'if' not allowed in main (yet); use a method" > "/dev/stderr"
    exit 1
  }
  parse_expr_or_keyword(2)
  body[body_n++] = 11           # JUMP_IF_FALSE
  body[body_n++] = 0
  if_pending = body_n - 1
  next
}

# ^ <expr>
$1 == "^" {
  if (in_main) {
    print "stc: '^' not allowed in main; just write the expression" > "/dev/stderr"
    exit 1
  }
  parse_expr_or_keyword(2)
  body[body_n++] = 8            # RETURN_TOP
  if (if_pending >= 0) {
    body[if_pending] = body_n - (if_pending + 1)
    if_pending = -1
  }
  next
}

# var := <expr>
$2 == ":=" {
  if (in_main) {
    print "stc: ':=' not allowed in main (yet); chain unary sends" > "/dev/stderr"
    exit 1
  }
  parse_expr_or_keyword(3)
  body[body_n++] = 6            # STORE_FIELD
  body[body_n++] = slot_index($1)
  next
}

# anything else: in main, treat as a value statement
{
  if (in_main) {
    parse_expr_or_keyword(1)
    body[body_n++] = 9          # POP (will be backpatched if last)
    main_last_pop_pos = body_n - 1
    next
  }
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

function finish_main(    i) {
  if (!in_main) return
  # Replace the trailing POP with PRIMITIVE 5 (print) + HALT so the
  # last value-statement's result is printed.
  if (main_last_pop_pos >= 0) {
    body[main_last_pop_pos] = 13   # PRIMITIVE
    body[main_last_pop_pos + 1] = 5
    body_n = main_last_pop_pos + 2
  }
  body[body_n++] = 0              # HALT
  main_n = body_n
  for (i = 0; i < body_n; i++) main_body[i] = body[i]
  body_n = 0
  in_main = 0
  main_last_pop_pos = -1
}

function finish_class() {
  cur_class = ""
  cur_slot_n = 0
}

# expr_or_keyword: parse_expr (unary+binary) then optional keyword tail.
function parse_expr_or_keyword(idx,    cur, sel_str, argc) {
  cur = parse_expr(idx)
  if (cur > NF) return cur
  if ($cur !~ /:$/) return cur
  sel_str = ""
  argc = 0
  while (cur <= NF && $cur ~ /:$/) {
    sel_str = sel_str $cur
    cur = parse_expr(cur + 1)
    argc++
  }
  if (!(sel_str in sel)) {
    print "stc: unknown keyword selector: " sel_str > "/dev/stderr"
    exit 1
  }
  body[body_n++] = 7              # SEND
  body[body_n++] = sel[sel_str]
  body[body_n++] = argc
  return cur
}

# expr: unary { binop unary }
function parse_expr(idx,    cur, op) {
  cur = parse_unary(idx)
  while (cur <= NF && ($cur in is_binary)) {
    op = $cur
    cur = parse_unary(cur + 1)
    body[body_n++] = 7
    body[body_n++] = sel[op]
    body[body_n++] = 1
  }
  return cur
}

# unary: atom { unary-id }
function parse_unary(idx,    cur, name) {
  cur = parse_atom(idx)
  while (cur <= NF) {
    name = $cur
    if (name == ")" || name == "(") break
    if (name in is_binary) break
    if (name ~ /:$/) break
    if (!(name in sel)) break
    body[body_n++] = 7
    body[body_n++] = sel[name]
    body[body_n++] = 0
    cur++
  }
  return cur
}

function parse_atom(idx,    a, n, cur) {
  a = $idx
  if (a == "(") {
    cur = parse_expr_or_keyword(idx + 1)
    if (cur > NF || $cur != ")") {
      print "stc: missing close paren in: " $0 > "/dev/stderr"
      exit 1
    }
    return cur + 1
  }
  if (a == "self") {
    body[body_n++] = 1
    return idx + 1
  }
  if (a ~ /^-?[0-9]+$/) {
    body[body_n++] = 12
    body[body_n++] = a + 0
    return idx + 1
  }
  if (a in cls) {
    if (idx + 1 > NF || $(idx + 1) != "new") {
      print "stc: bare class name '" a "' must be followed by 'new'" > "/dev/stderr"
      exit 1
    }
    body[body_n++] = 12           # PUSH_INT class-id
    body[body_n++] = cls[a]
    body[body_n++] = 12           # PUSH_INT ivar-count
    body[body_n++] = class_ivar_n[a]
    body[body_n++] = 13           # PRIMITIVE
    body[body_n++] = 6            # 6 = ALLOC
    return idx + 2
  }
  for (n = 0; n < cur_arg_n; n++) {
    if (cur_args[n] == a) {
      body[body_n++] = 3          # PUSH_TEMP
      body[body_n++] = n
      return idx + 1
    }
  }
  n = slot_index(a)
  if (n >= 0) {
    body[body_n++] = 5            # PUSH_FIELD
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

function emit_data_chunked(items, n_items, start_line,    k, line, content_len, v, sep_len, ln) {
  ln = start_line
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
  return ln
}

END {
  finish_method()
  finish_main()
  finish_class()

  meth_total = 0
  for (i = 0; i < meth_n; i++) meth_total += m_len[i]
  if (meth_total > 64) {
    print "stc: method bytecode total " meth_total " exceeds 64 bytes" > "/dev/stderr"
    exit 1
  }
  if (main_n > 64) {
    print "stc: main bytecode " main_n " exceeds 64 bytes" > "/dev/stderr"
    exit 1
  }

  # MODE=methods_only suppresses the driver stub + main DATA so a
  # legacy hand-assembled .bas driver can supply its own top-level
  # bytecode (D8 stepper, D5 calc REPL).  Default is the full
  # form (driver stub + image + main DATA) used by run-st.sh.
  if (MODE != "methods_only") {
    # Driver stub at lines 1..99.
    print "1 REM === DRIVER STUB GENERATED BY tools/stc.awk ============"
    print "5 LET E=0"
    print "10 LET S=0"
    print "15 LET F=0"
    print "20 GOSUB 100"
    print "25 IF E<>0 THEN GOTO 99"
    if (main_n > 0) {
      print "30 RESTORE 600"
      print "35 FOR I=0 TO " main_n - 1
      print "40 READ V"
      print "45 LET O(64+I)=V"
      print "50 NEXT I"
      print "55 LET M=64"
      print "60 LET L=" main_n
      print "65 LET P=0"
      print "70 LET R=0"
      print "75 GOSUB 12000"
      print "80 IF E<>0 THEN PRINT \"?STERR \";E"
    }
    print "99 END"
  }

  # Image bootstrap header at lines 100..150.
  print "100 REM === IMAGE BOOTSTRAP =================================="
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

  # Method DATA records at line 500+.
  ln = 500
  for (i = 0; i < meth_n; i++) {
    n_items = 3 + m_len[i]
    items[0] = m_class[i]
    items[1] = m_sel[i]
    items[2] = m_len[i]
    for (j = 0; j < m_len[i]; j++) items[3 + j] = m_body[i, j]
    ln = emit_data_chunked(items, n_items, ln)
  }
  print ln " DATA -1, 0, 0"

  # Main bytecode DATA at line 600+.  Suppressed in methods_only.
  if (MODE != "methods_only" && main_n > 0) {
    n_items = main_n
    for (j = 0; j < main_n; j++) items[j] = main_body[j]
    emit_data_chunked(items, n_items, 600)
  }
  # NOTE: RUN/BYE are NOT emitted here.  The caller (run-st.sh)
  # cats this output with src/vm.bas first, then appends RUN/BYE,
  # so all numbered lines (driver stub + image + DATA + vm.bas
  # helpers) are stored before RUN starts execution.
}
