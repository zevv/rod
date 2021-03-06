---
layout: page
title: Manual
permalink: /manual
---

# Language documentation

#### Note

This documentation is still unfinished, and will grow with new language features
being added.

## Syntax

As mentioned, rod's syntax is similar to Nim, so learning it is very easy for
existing Nim users. The only major difference is that rod uses braces instead of
indentation, to make parsing simpler.

### Comments

Comments in rod look exactly as in C++. Only single-line comments are supported.

```rod
// This is a comment
```

### Literals

rod supports ordinary number and string literals.

```rod
3.141592        // This is a number literal
"Hello, world!" // This is a string literal
```

As of now, only basic literals (as shown above) are supported. So no scientific,
binary, hexadecimal, or octal numbers, and no escape sequences in strings.
This is subject to change, though.

### Identifiers

An identifier starts with a character from the set
`{'a'..'z', 'A'..'Z', '_', '\x7f'..'\xff'}` and continues with 0 or more
characters from the set `{'a'..'z', 'A'..'Z', '0'..'9', '_', '\x7f'..'\xff'}`.

Arbitrary sequences of characters (including reserved keywords) may be used as
identifiers provided that they're *stropped*. Stropping a sequence of characters
is done using backticks '\`'. Example:
```rod
var `if` = 0
```
Keep in mind that whitespace is ignored inside a stropped identifier, so this:
```rod
var `hello world` = 1
```
is the same as this:
```rod
var helloworld = 1
```
Stropping is rarely required though and should only be used in very specific
cases described later in the manual.

### Expressions

rod divides its syntax into expressions and statements. Expressions always have
a type, while statements do not (we denote the lack of a type as `void`).
Expressions in rod include literals, arithmetic and logic operations, both unary
and binary, calls, sequence and table indexing, object construction, and `if`.

#### Operator precedence

Unary operators always take precedence over binary operators. Unlike Nim, there
are *no exceptions to this rule*. In Nim the `@` operator binds stronger than
a primary suffix (that includes calls, dot syntax, array access, and such).
This rule does not apply in rod, to keep parsing simple. Binary operator
precedence follows [Nim's rules][nim-prec].

  [nim-prec]: https://nim-lang.org/docs/manual.html#syntax-precedence

### Statements

Statements in rod are pretty simple - they include all expressions, loops, and
declarations. Statements in rod are delimited with line breaks.

### Blocks

rod makes heavy use of blocks throughout the language's syntax, here's what they
look like:
```rod
{
  echo("Hello, world!")
}
```
Another, more compact style is also supported:
```rod
{ echo("Hello, world!")
  echo("Going compact!") } // notice how a line break isn't required here
```
The above syntax is an exception to the usual statement rules. In blocks, `}`
can also be used as a statement terminator.

## Variables

Variables are a very important part of any language. rod offers two ways of
declaring them:
```rod
// using var:
var a, b = 2
var c, d: string
// using let:
let x, y = 5
// let z, w: bool - error: 'let' variables must have a value.
```
The rules behind these two definition types are the same as in Nim: `var`
declares a regular variable, and `let` declares a single-assignment variable.
Attempting to assign to such a variable twice will result in a compile error:
```rod
let x = 2
x = 3 // error: attempt to reassign a 'let' variable
```
Even though `let` variables cannot be reassigned, that does not mean their value
cannot be changed: if their value is an object, its fields can be modified just
fine.

Variables in rod are statically typed. That means that a number variable will
always stay a number variable, until it goes out of scope. The type of a
variable cannot be changed.
```rod
var x = 3
x = "Hello, world!" // error: type mismatch, attempt to assign a string to a
                    // number variable
```
Currently there's no way of defining a variable without specifying a value,
but that's subject to change.

## Flow control

Flow control is achieved in rod through 3 basic constructs: `if`, `while`,
and `for`.

### `if` expression

In rod, `if` is an expression. That means it can be used in places like variable
values, proc arguments, etc.

The basic syntax of an `if` expression is like so:
```rod
if condition {
  // do things
} elif condition {
  // do things
} elif condition {
  // do things
} else {
  // do things
}
```
Each condition must be a boolean. If it's of a different type, an error is
raised.

An `if` expression executes all of its blocks sequentially, and stops whenever
one of the condition evaluates to `true`. If none of the expressions evaluate to
`true`, then the `else` branch is executed.

Here's an example of the `if` expression in action:
```rod
let respHi = 0
let respBye = 1
let respNone = 2

let in = readInputFromUser()
var response = respNone

if in == "hi" { response = respHi }
elif in == "bye" { response = respBye }

echo(if response == respHi { "Hello!" }
     elif response == respBye { "Goodbye!" }
     else { "..." })
```

The type of an `if` expression is inferred by the following conditions:

- If the `if` expression is used in statement context, its type is not inferred
  from anything and is `void`.
- If the `if` expression is used in expression context, its type is the type of
  the last expression of the first block. If that type is `void`, an error is
  raised. All other blocks must have that same type (also inferred from the last
  statement of their corresponding blocks).

#### `and` and `or` operators

These two operators are special, because they're *short-circuiting*. That means
if one of their operands makes the result 'obvious', the other operand will not
be evaluated. Example:

```rod
proc a() -> bool {
  echo("a")
  result = true
}

proc b() -> bool {
  echo("b")
  result = false
}

a() or b()
```
Output:
```
a
```
As you can see, the second operand is not evaluated, because if the first
operand is `true`, we know that the result will always be `true`, according to
the truth table of the `OR` logic operation:

| A | B | Output |
| --- | --- | --- |
| 0 | 0 | 0 |
| 0 | 1 | 1 |
| 1 | 0 | 1 |
| 1 | 1 | 1 |

A similar thing happens with `and`: if the first operand evaluates to `false`,
the second operand will not be evaluated, because we know that if one operand of
the `AND` logic operation is `false`, the output will always be `false`.

| A | B | Output |
| --- | --- | --- |
| 0 | 0 | 0 |
| 0 | 1 | 0 |
| 1 | 0 | 0 |
| 1 | 1 | 1 |


### `while` loop

A `while` loop is the simplest kind of loop. All it does is it executes its body
as long as its condition stays `true`.

The syntax of a `while` loop is like so:
```rod
while condition {
  // do things
}
```
An infinite loop may be created by setting the condition to a `true` constant.
```rod
while true {
  // do things indefinitely
}
```

A `while` loop can be stopped by using the `break` keyword.
```rod
var x = 0
while true {
  x = x + 1
  if x > 10 {
    break
  }
}
```
The `continue` keyword will cause the loop to jump back to the beginning of
the block.
```rod
// List even numbers from 0 to 100
var x = -1
while x <= 100 {
  x = x + 1
  if x mod 2 == 1 {
    continue
  }
  echo($x)
}
```

### `for` loop

The `for` loop is an advanced version of the `while` loop. Instead of iterating
as long as a condition is met, it uses *iterators*.
```rod
for variable in iterator {
  // do things
}
```

`for` loops support `break` and `continue`, just like `while` loops do.

rod currently doesn't have a way of defining custom iterators, but a few are
provided in its standard library. First of all, the range iterators:

```rod
// displays numbers from 0 to 100
for i in 0..100 {
  echo(i)
}
```

This is the inclusive range operator. It iterates over all numbers in the given
range, here from 0 to 100.

```rod
for i in 0..<100 {
  echo(i)
}
```

This exclusive range iterator is similar. The only difference is that it skips
the last number in the range, so the above example will print numbers
from 0 to 99 instead of 0 to 100.

Two more range iterators are available:

- `countup(min, max, step)` – counts numbers from `min` to `max`, skipping over
  `step` of them at a time. `step` may be any number, it doesn't have to be an
  integer. It *must* however be a positive number; otherwise an exception is
  raised.
- `countdown(max, min, step)` – the same as `countup`, but counts in the
  opposite direction. `step` must also be a positive number.

## Objects

Objects are homogenous containers of other values. They can contain any set of
values, and they can even form recursive data structures.

An object is declared like so:
```rod
object MyObject {
  a: string
  b: number
  x, y: bool
}
```
Objects are constructed using the following syntax:
```rod
var myObj = MyObject(a: "test", b: 3.1415926, x: true, y: false)
```
All fields of an object must be initialized to a value, although this is subject
to change.

Fields in objects can be read back from by using the dot syntax:
```rod
echo(myObj.a) // output: test
```
Fields can also be assigned to:
```rod
myObj.b = 42
echo($myObj.b) // output: 42
```

Note that even if you create a `let` variable with an object value, you can
still write to that object's fields, because the object itself is mutable. Only
the variable cannot be reassigned.
```rod
let myObj = MyObject(a: "test", b: 3.1415926, x: true, y: false)
myObj.x = false // this is legit
```

## Procedures

Procedures in rod are what other languages call 'functions'. Each procedure has
a name, arguments, and an optional return type.
In rod, procedures are declared like so:
```rod
proc myProcedure(arg1, arg2: string, arg3: number) -> string {
  // do things
}
```

There are a few things to note here:
- The procedure's arguments have what's called *type propagation*, which you can
  notice with `arg1` and `arg2`. It allows you to declare multiple arguments
  with a common type without having to repeat that type.
- Unlike Nim, rod uses `->` for specifying the return type. It works better with
  its brace-based syntax.

The return type of the procedure can be omitted. This will make the return type
`void`.
```rod
proc myProcedure() {
  // do things
}
```

Procedure arguments are not assignable. That means it's an error to do this:
```rod
proc myProcedure(x: number) {
  x = 2 // error!
}
```

To return a value from a procedure, the `return` statement is used. It halts the
execution of the procedure immediately, and returns the associated value (which
*can* be empty, in that case, the value returned is the value of the `result`
variable, which is described below).
```rod
proc theAnswer() -> number {
  return 42
}
```
It's important to note that the return statement is *always* the last statement
in a block. This means that this:
```rod
proc doSomeCalculations() -> number {
  return 2
  -42.sin
}
```
Is equivalent to this:
```rod
proc doSomeCalculations() -> number {
  return 2 - 42.sin
}
```

rod procedures can be called in 3 different ways:
- With regular call syntax – `someProc(arg1, arg2, ...)`
- With method call syntax – `arg1.someProc(arg2, ...)`
- With getter syntax – `arg1.someProc`

The two first examples are functionally equivalent. The third example is not
the same, because this syntax can only be used for calling procs which accept 1
parameter.

### The `result` variable

`result` is a special, implicitly declared variable present in all `proc`s with
a non-`void` return type. It is a convenience feature which helps avoid
unnecessary temporary variable declarations:
```rod
// without result
proc fac(n: number) -> number {
  var r = 1
  for i in 1..n {
    r = r * i
  }
  return r
}

// with result
proc fac(n: number) -> number {
  result = 1
  for i in 1..n {
    result = result * i
  }
}
```
Note how when we use `result` we don't need an extra `return` to actually
return the result of our operation. That is the main purpose of `result`: if
an accumulative operation is being done (eg. calculating the factorial of some
number), one can avoid an extra `return` statement at the end of the procedure.
In fact, `result` should be preferred over `return` whenever its flow control
capabilities are not required.

The initial value of `result` is dependent on the return type of the procedure.
It is always the default value for that type (eg. `0` for numbers).

### Setters

There's also another way of calling procs: that way is through assignment.
Only 'setters' can be called this way. A setter is declared by adding `=` to the
proc's name. Because `=` is not a valid identifier character, the name must be
stropped:
```rod
proc `someProperty=`(a: number, b: number) {
  // do things
}
```
Setters must always have two arguments. They can be called using the following
syntax:
```rod
a.someProperty = b
```
In a nutshell, they look exactly like an object field assignment. However, a
proc is called instead, and property setters can be declared for non-object
types like `number`s.

Object field assigmnents take precedence over setters:
```rod
object Vec2 {
  x, y: number
}

var myVec = Vec2(x: 1, y: 2)
myVec.x = 3 // sets the field directly

proc `x=`(vec: Vec2, val: number) {
  vec.x = val
}

myVec.x = 4 // also sets the field directly
```
To avoid this, the field must be declared with a different name. The idiomatic
way is to prefix the field with `f`:
```rod
object Vec2 {
  fX, fY: number
}

var myVec = Vec2(x: 1, y: 2)
myVec.fX = 3 // sets the field directly

proc `x=`(vec: Vec2, val: number) {
  vec.fX = val
}

myVec.x = 4 // calls the setter
```

### Operator overloading

All valid rod operators can be overloaded. Currently, this only includes
built-in operators, but support for custom operators is planned.

To overload an operator, simply name your proc with it:
```rod
object Vec2 {
  x, y: number
}

proc `+`(a, b: Vec2) -> Vec2 {
  result = Vec2(x: a.x + b.x, y: a.y + b.y)
}

var
  a = Vec2(x: 3, y: 2),
  b = Vec2(x: 2, y: 3),
  c = a + b // Vec2(x: 5, y: 5)
```
As shown above, this feature is most useful with mathematical types, like
vectors.

Overloaded unary operators accept one parameter, and binary operators accept
two parameters. `not` and `$` are unary-only operators.
