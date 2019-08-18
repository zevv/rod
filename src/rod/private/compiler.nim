#--
# the rod scripting language
# copyright (C) iLiquid, 2019
# licensed under the MIT license
#--

import macros
import tables

import chunk
import common
import parser
import types
import value

type
  VariableKind = enum
    vkGlobal
    vkLocal
  Variable = object
    ty: RodType
    name: string
    isMutable, isSet: bool
    case kind: VariableKind
    of vkGlobal:
      discard
    of vkLocal:
      stackPos, scope: int
  Loop = object
    before: int
    breaks: seq[int]
  Compiler* = object
    types: Table[string, RodType]
    globals: Table[string, Variable]
    locals: seq[Variable]
    scope: int
    localVars: seq[int]
    loops: seq[Loop]

proc error(node: Node, msg: string) =
  raise (ref RodError)(kind: reCompile, ln: node.ln, col: node.col,
                       msg: node.file & " " & $node.ln & ':' & $node.col & ' ' &
                            msg)

proc addType*(compiler: var Compiler, name: string) =
  let ty = (id: compiler.types.len + 1, name: name)
  compiler.types.add(name, ty)

template compilerGuard(body) =
  chunk.ln = node.ln
  chunk.col = node.col
  body

macro compiler(pc) =
  pc[3].insert(1,
    newIdentDefs(ident"chunk", newNimNode(nnkVarTy).add(ident"Chunk")))
  pc[3].insert(1,
    newIdentDefs(ident"compiler", newNimNode(nnkVarTy).add(ident"Compiler")))
  if pc[6].kind != nnkEmpty:
    pc[6] = newCall("compilerGuard", pc[6])
  result = pc

proc getConst(chunk: var Chunk, val: RodValue): uint16 =
  for i, c in chunk.consts[val.kind]:
    if c == val: return i.uint16
  result = chunk.consts[val.kind].len.uint16
  chunk.consts[val.kind].add(val)

proc pushScope(compiler: var Compiler) =
  inc(compiler.scope)
  compiler.localVars.add(0)

proc popScope(compiler: var Compiler, chunk: var Chunk) =
  let v = compiler.localVars[^1]
  compiler.locals.setLen(compiler.locals.len - v)
  dec(compiler.scope)
  if v > 0:
    chunk.emit(opcNDiscard)
    chunk.emit(v.uint8)
  discard compiler.localVars.pop()

proc declareVar(compiler: var Compiler, name: string, mut: bool, ty: RodType) =
  if compiler.scope > 0:
    compiler.locals.add(Variable(name: name, isMutable: mut, ty: ty,
                                 kind: vkLocal, stackPos: compiler.locals.len,
                                 scope: compiler.scope))
    inc(compiler.localVars[^1])
  else:
    compiler.globals.add(name, Variable(name: name, isMutable: mut, ty: ty,
                                        kind: vkGlobal))

proc getVar(compiler: Compiler, node: Node): Variable =
  if compiler.scope > 0:
    for i in countdown(compiler.locals.len - 1, 0):
      if compiler.locals[i].name == node.ident:
        return compiler.locals[i]
  else:
    if compiler.globals.hasKey(node.ident):
      return compiler.globals[node.ident]
  node.error("Attempt to reference undeclared variable '" & node.ident & '\'')

proc popVar(compiler: var Compiler, chunk: var Chunk, node: Node) =
  var
    variable: Variable
    localIndex: int
  if compiler.scope > 0:
    for i in countdown(compiler.locals.len - 1, 0):
      if compiler.locals[i].name == node.ident:
        variable = compiler.locals[i]
        localIndex = i
        break
  else:
    if compiler.globals.hasKey(node.ident):
      variable = compiler.globals[node.ident]
  if not variable.isMutable and variable.isSet:
    node.error("Attempt to assign to 'let' variable '" & node.ident & '\'')
  else:
    if variable.kind == vkLocal:
      if variable.isSet:
        chunk.emit(opcPopL)
        chunk.emit(variable.stackPos.uint8)
      compiler.locals[localIndex].isSet = true
    else:
      chunk.emit(opcPopG)
      chunk.emit(chunk.getConst(node.ident.rod))
      compiler.globals[node.ident].isSet = true
    return
  node.error("Attempt to assign to undeclared variable '" & node.ident & '\'')

proc pushVar(compiler: Compiler, chunk: var Chunk, variable: Variable) =
  if variable.kind == vkLocal:
    chunk.emit(opcPushL)
    chunk.emit(variable.stackPos.uint8)
  else:
    chunk.emit(opcPushG)
    chunk.emit(chunk.getConst(variable.name.rod))

proc compileExpr(node: Node): RodType {.compiler.}

proc pushConst(node: Node): RodType {.compiler.} =
  case node.kind
  of nkBool:
    if node.boolVal == true: chunk.emit(opcPushTrue)
    else: chunk.emit(opcPushFalse)
    result = compiler.types["bool"]
  of nkNumber:
    chunk.emit(opcPushN)
    chunk.emit(chunk.getConst(node.numberVal.rod))
    result = compiler.types["number"]
  else: discard

proc prefix(node: Node): RodType {.compiler.} =
  var
    typeMismatch = false
  let ty = compiler.compileExpr(chunk, node[1])
  if ty == compiler.types["number"]:
    case node[0].ident
    of "+": discard # + is a noop
    of "-": chunk.emit(opcNegN)
    else: typeMismatch = true
    if not typeMismatch: result = ty
  elif ty == compiler.types["bool"]:
    case node[0].ident
    of "not": chunk.emit(opcInvB)
    else: typeMismatch = true
    if not typeMismatch: result = ty
  else: typeMismatch = true
  if typeMismatch:
    node.error("No overload of '" & node[0].ident & "' available for <" &
                ty.name & ">")

proc infix(node: Node): RodType {.compiler.} =
  if node[0].ident notin ["=", "or", "and"]:
    var typeMismatch = false
    let
      aTy = compiler.compileExpr(chunk, node[1])
      bTy = compiler.compileExpr(chunk, node[2])
    if aTy == compiler.types["number"] and bTy == compiler.types["number"]:
      case node[0].ident
      of "+": chunk.emit(opcAddN)
      of "-": chunk.emit(opcSubN)
      of "*": chunk.emit(opcMultN)
      of "/": chunk.emit(opcDivN)
      of "==": chunk.emit(opcEqN)
      of "!=": chunk.emit(opcEqN); chunk.emit(opcInvB)
      of "<": chunk.emit(opcLessN)
      of "<=": chunk.emit(opcLessEqN)
      of ">": chunk.emit(opcGreaterN)
      of ">=": chunk.emit(opcGreaterEqN)
      else: typeMismatch = true
      if not typeMismatch: result =
        case node[0].ident
        of "+", "-", "*", "/": compiler.types["number"]
        of "==", "!=", "<", "<=", ">", ">=": compiler.types["bool"]
        else: compiler.types["void"]
    elif aTy == compiler.types["bool"] and bTy == compiler.types["bool"]:
      case node[0].ident
      of "==": chunk.emit(opcEqB)
      of "!=": chunk.emit(opcEqB); chunk.emit(opcInvB)
      else: typeMismatch = true
      if not typeMismatch: result = aTy
    else: typeMismatch = true
    if typeMismatch:
      node.error("No overload of '" & node[0].ident & "' available for <" &
                 aTy.name & ", " & bTy.name & ">")
  else:
    case node[0].ident
    of "=":
      case node[1].kind
      of nkIdent:
        var variable = compiler.getVar(node[1])
        let valTy = compiler.compileExpr(chunk, node[2])
        if valTy == variable.ty:
          compiler.popVar(chunk, node[1])
        else:
          node.error("Type mismatch: cannot assign value of type <" &
                     valTy.name & "> to a variable of type <" &
                     variable.ty.name & ">")
        result = compiler.types["void"]
      else: node.error("Cannot assign to '" & ($node.kind)[2..^1] & "'")
    of "or":
      let aTy = compiler.compileExpr(chunk, node[1])
      chunk.emit(opcJumpFwdT)
      let hole = chunk.emitHole(2)
      chunk.emit(opcDiscard)
      let bTy = compiler.compileExpr(chunk, node[2])
      if aTy != compiler.types["bool"] or bTy != compiler.types["bool"]:
        node.error("Operands of 'or' must be booleans")
      chunk.fillHole(hole, uint16(chunk.code.len - hole + 1))
      result = compiler.types["bool"]
    of "and":
      let aTy = compiler.compileExpr(chunk, node[1])
      chunk.emit(opcJumpFwdF)
      let hole = chunk.emitHole(2)
      chunk.emit(opcDiscard)
      let bTy = compiler.compileExpr(chunk, node[2])
      if aTy != compiler.types["bool"] or bTy != compiler.types["bool"]:
        node.error("Operands of 'and' must be booleans")
      chunk.fillHole(hole, uint16(chunk.code.len - hole + 1))
      result = compiler.types["bool"]
    else: discard

proc compileBlock(node: Node, isStmt: bool): RodType {.compiler.}

proc compileIf(node: Node, isStmt: bool): RodType {.compiler.} =
  var
    pos = 0
    jumpsToEnd: seq[int]
    ifTy: RodType
    hadElse = false
  while pos < node.children.len:
    if node[pos].kind != nkBlock:
      if compiler.compileExpr(chunk, node[pos]) != compiler.types["bool"]:
        node[pos].error("'if' condition must be a boolean")
      inc(pos)
      chunk.emit(opcJumpFwdF)
      let afterBlock = chunk.emitHole(2)
      chunk.emit(opcDiscard)
      let blockTy = compiler.compileBlock(chunk, node[pos], isStmt)
      if not isStmt:
        if ifTy.id == 0:
          ifTy = blockTy
        else:
          if blockTy != ifTy:
            node[pos].error("Type mismatch: <" & ifTy.name & "> expected, " &
                            "but got <" & blockTy.name & ">")
      if pos < node.children.len - 1:
        chunk.emit(opcJumpFwd)
        jumpsToEnd.add(chunk.emitHole(2))
      inc(pos)
      chunk.fillHole(afterBlock, uint16(chunk.code.len - afterBlock + 1))
    else:
      chunk.emit(opcDiscard)
      let blockTy = compiler.compileBlock(chunk, node[pos], isStmt)
      if not isStmt:
        if blockTy != ifTy:
          node[pos].error("Type mismatch: <" & ifTy.name & "> expected, but " &
                          "got <" & blockTy.name & ">")
      hadElse = true
      inc(pos)
  if not hadElse:
    chunk.emit(opcDiscard)
  for hole in jumpsToEnd:
    chunk.fillHole(hole, uint16(chunk.code.len - hole + 1))
  result =
    if isStmt: compiler.types["void"]
    else: compiler.types["void"]

proc compileExpr(node: Node): RodType {.compiler.} =
  case node.kind
  of nkBool, nkNumber:
    result = compiler.pushConst(chunk, node)
  of nkIdent:
    var variable = compiler.getVar(node)
    compiler.pushVar(chunk, variable)
    result = variable.ty
  of nkPrefix:
    result = compiler.prefix(chunk, node)
  of nkInfix:
    result = compiler.infix(chunk, node)
  of nkIf:
    result = compiler.compileIf(chunk, node, false)
  else: node.error("Value does not have a valid type")

proc compileWhile(node: Node) {.compiler.} =
  var
    isWhileTrue = false
    afterLoop: int
  let beforeLoop = chunk.code.len
  compiler.loops.add(Loop(before: beforeLoop))
  if node[0].kind == nkBool:
    if node[0].boolVal == true: isWhileTrue = true
    else: return # while false is a noop
  if not isWhileTrue:
    if compiler.compileExpr(chunk, node[0]) != compiler.types["bool"]:
      node[0].error("'while' condition must be a boolean")
    chunk.emit(opcJumpFwdF)
    afterLoop = chunk.emitHole(2)
    chunk.emit(opcDiscard)
  discard compiler.compileBlock(chunk, node[1], true)
  chunk.emit(opcJumpBack)
  chunk.emit(uint16(chunk.code.len - beforeLoop - 1))
  if not isWhileTrue:
    chunk.fillHole(afterLoop, uint16(chunk.code.len - afterLoop + 1))
  discard compiler.loops.pop()

proc compileBreak(node: Node) {.compiler.} =
  if compiler.loops.len == 0:
    node.error("'break' can only be used in a loop")
  chunk.emit(opcNDiscard)
  chunk.emit(compiler.localVars[^1].uint8)
  chunk.emit(opcJumpFwd)
  compiler.loops[^1].breaks.add(chunk.emitHole(2))

proc compileContinue(node: Node) {.compiler.} =
  if compiler.loops.len == 0:
    node.error("'continue' can only be used in a loop")
  chunk.emit(opcNDiscard)
  chunk.emit(compiler.localVars[^1].uint8)
  chunk.emit(opcJumpBack)
  chunk.emit(uint16(chunk.code.len - compiler.loops[^1].before))

proc compileStmt(node: Node) {.compiler.} =
  case node.kind
  of nkLet, nkVar:
    for decl in node.children:
      compiler.declareVar(decl[1].ident, node.kind == nkVar,
                          compiler.compileExpr(chunk, decl[2]))
      compiler.popVar(chunk, decl[1])
  of nkBlock: discard compiler.compileBlock(chunk, node, true)
  of nkIf: discard compiler.compileIf(chunk, node, true)
  of nkWhile: compiler.compileWhile(chunk, node)
  of nkBreak: compiler.compileBreak(chunk, node)
  of nkContinue: compiler.compileContinue(chunk, node)
  else:
    let ty = compiler.compileExpr(chunk, node)
    if ty != compiler.types["void"]:
      chunk.emit(opcDiscard)

proc compileBlock(node: Node, isStmt: bool): RodType {.compiler.} =
  compiler.pushScope()
  for i, s in node.children:
    if isStmt:
      compiler.compileStmt(chunk, s)
    else:
      if i < node.children.len - 1:
        compiler.compileStmt(chunk, s)
      else:
        result = compiler.compileExpr(chunk, s)
  compiler.popScope(chunk)
  if isStmt: result = compiler.types["void"]

proc compileScript*(node: Node) {.compiler.} =
  for s in node.children:
    compiler.compileStmt(chunk, s)
  chunk.emit(opcHalt)

proc initTypes(compiler: var Compiler) =
  compiler.addType("void")
  compiler.addType("bool")
  compiler.addType("number")

proc initCompiler*(): Compiler =
  result = Compiler()
  result.initTypes()
