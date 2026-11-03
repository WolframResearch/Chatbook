# Functional Programming in Wolfram Language

Wolfram Language supports many programming styles, but it's at its best when you write code in a **functional** style: building results by applying functions to whole expressions instead of modifying variables in loops. This guide covers the core ideas, the most important functions, and how to translate procedural code into functional code.

## Table of contents

1. Pure functions
2. Mapping and applying
3. Folding and nesting
4. Selecting and partitioning
5. Composition and operator forms
6. Translating loops
7. Performance considerations
8. Exercises

---

## 1. Pure functions

A *pure function* (also called an anonymous function or lambda) is a function without a name. There are three equivalent ways to write one:

```wl
Function[x, x^2 + 1]
Function[{x, y}, x^2 + y^2]
#^2 + 1 &
```

In the short form, `#` refers to the first argument, `#2` to the second, and `##` to all arguments as a sequence. The `&` marks the end of the function body.

```wl
In[1]:= (#^2 + 1 &)[3]

Out[1]= 10

In[2]:= (#1 + #2 &)[3, 4]

Out[2]= 7

In[3]:= (f[##] &)[a, b, c]

Out[3]= f[a, b, c]
```

You can also use `\[Function]` (typed as `|->`), which reads nicely in longer code: `x |-> x^2 + 1`.

> **Watch out for precedence.** The `&` has very low precedence, so `#^2 & /@ list` works as expected, but `x -> #^2 &` is parsed as `(x -> #^2) &`, a function that returns a rule. Use parentheses when in doubt.

### Named slots and associations

When the argument is an association, `#key` extracts a value by key:

```wl
people = {<|"name" -> "Ada", "born" -> 1815|>, <|"name" -> "Alan", "born" -> 1912|>};
#name <> " (" <> ToString[#born] <> ")" & /@ people
(* {"Ada (1815)", "Alan (1912)"} *)
```

---

## 2. Mapping and applying

### Map

[`Map`](paclet:ref/Map) (`/@`) applies a function to each element of a list:

```wl
Map[f, {a, b, c}]        (* {f[a], f[b], f[c]} *)
f /@ {a, b, c}           (* same thing *)
Map[f, {{a, b}, {c}}, {2}] (* {{f[a], f[b]}, {f[c]}} *)
```

The third argument is a *level specification*. Common values:

| Level spec | Meaning |
|:-----------|:--------|
| `{1}` | the elements of the list (default) |
| `{2}` | elements of the sublists |
| `{-1}` | the leaves (atoms) |
| `{0, Infinity}` | every subexpression, including the whole expression |
| `All` | every level except level 0 |

### MapIndexed and MapThread

- `MapIndexed[f, list]` passes the position as a second argument: `MapIndexed[#2[[1]] -> #1 &, {a, b}]` gives `{1 -> a, 2 -> b}`.
- `MapThread[f, {{a, b}, {c, d}}]` gives `{f[a, c], f[b, d]}`, like `zip` followed by `map`.
- `KeyValueMap[f, assoc]` applies `f[key, value]` to each entry of an association.

### Apply

[`Apply`](paclet:ref/Apply) (`@@`) replaces the head of an expression:

```wl
Apply[Plus, {1, 2, 3}]   (* 6 *)
Plus @@ {1, 2, 3}         (* 6 *)
f @@@ {{a, b}, {c, d}}    (* {f[a, b], f[c, d]} *)
```

The `@@@` form (apply at level 1) is extremely common for lists of pairs:

```wl
StringJoin @@@ {{"a", "b"}, {"c", "d"}}
(* {"ab", "cd"} *)
```

### Listable functions

Many built-in functions are `Listable`, meaning they automatically thread over lists. You don't need `Map` for these:

```wl
In[7]:= Sqrt[{1, 4, 9, 16}]

Out[7]= {1, 2, 3, 4}

In[8]:= {1, 2, 3} + {10, 20, 30}

Out[8]= {11, 22, 33}

In[9]:= Attributes[Sqrt]

Out[9]= {Listable, NumericFunction, Protected}
```

Listable operations on packed arrays are much faster than `Map`, often by a factor of 10–100.

---

## 3. Folding and nesting

### Fold and FoldList

[`Fold`](paclet:ref/Fold) combines elements one at a time with an accumulator. It's the functional equivalent of a loop that updates a single variable:

```wl
Fold[f, x, {a, b, c}]      (* f[f[f[x, a], b], c] *)
FoldList[f, x, {a, b, c}]  (* {x, f[x, a], f[f[x, a], b], f[f[f[x, a], b], c]} *)
```

For example, a running maximum:

```wl
FoldList[Max, {3, 1, 4, 1, 5, 9, 2, 6}]
(* {3, 3, 4, 4, 5, 9, 9, 9} *)
```

### Nest, NestList, and FixedPoint

`Nest[f, x, n]` applies `f` to `x` exactly $n$ times. `FixedPoint[f, x]` applies it until the result stops changing:

```wl
NestList[#/2 &, 100, 4]
(* {100, 50, 25, 25/2, 25/4} *)

FixedPoint[(# + 2/#)/2 &, 1.]
(* 1.41421 — Newton's method for Sqrt[2] *)
```

The Newton iteration above is $x_{k+1} = \frac{1}{2}\left(x_k + \frac{2}{x_k}\right)$, which converges quadratically to $\sqrt{2}$.

`NestWhile` and `NestWhileList` let you specify a stopping condition:

```wl
NestWhileList[If[EvenQ[#], #/2, 3 # + 1] &, 27, # != 1 &] // Length
(* 112 *)
```

---

## 4. Selecting and partitioning

| Function | Purpose | Example | Result |
|:---------|:--------|:--------|:-------|
| `Select` | keep elements that satisfy a test | `Select[Range[10], PrimeQ]` | `{2, 3, 5, 7}` |
| `Cases` | keep elements that match a pattern | `Cases[{1, a, 2.5, "s"}, _?NumberQ]` | `{1, 2.5}` |
| `DeleteCases` | remove elements that match | `DeleteCases[{1, 0, 2, 0}, 0]` | `{1, 2}` |
| `Pick` | select using a mask | `Pick[{a, b, c}, {True, False, True}]` | `{a, c}` |
| `GatherBy` | group by a function | `GatherBy[Range[6], EvenQ]` | `{{1, 3, 5}, {2, 4, 6}}` |
| `SplitBy` | split into runs | `SplitBy[{1, 1, 2, 2, 2, 1}, Identity]` | `{{1, 1}, {2, 2, 2}, {1}}` |
| `Partition` | fixed-size blocks | `Partition[Range[6], 2]` | `{{1, 2}, {3, 4}, {5, 6}}` |

`Select` uses a *function*, while `Cases` uses a *pattern*. They overlap a lot: `Select[list, IntegerQ]` and `Cases[list, _Integer]` give the same result.

---

## 5. Composition and operator forms

### Composition

`f @* g` is `Composition[f, g]`, which applies `g` first. `f /* g` is `RightComposition[f, g]`, which applies `f` first:

```wl
(Length @* Union)[{3, 1, 3, 2, 1}]     (* 3 *)
(Union /* Length)[{3, 1, 3, 2, 1}]     (* 3 *)
```

`RightComposition` is often easier to read for pipelines, since the functions appear in the order they're applied.

### Operator forms

Many functions have an *operator form*, where you give all arguments except the data:

```wl
Select[PrimeQ]                    (* a function that selects primes *)
Map[f]                            (* a function that maps f *)
SortBy[Last]                      (* a function that sorts by the last element *)
```

Operator forms combine nicely with `/*` and with `Query`:

```wl
process = Select[PrimeQ] /* Map[#^2 &] /* Total;
process[Range[20]]
(* 1027 *)
```

That's $2^2 + 3^2 + 5^2 + 7^2 + 11^2 + 13^2 + 17^2 + 19^2 = 1027$.

### The postfix and prefix forms

- `f @ x` is `f[x]` (prefix)
- `x // f` is `f[x]` (postfix)
- `x ~f~ y` is `f[x, y]` (infix)

Postfix `//` is handy at the end of an input: `Integrate[x^2, x] // TraditionalForm`.

---

## 6. Translating loops

Here are some common procedural patterns and their functional equivalents.

**Summing values:**

```wl
(* Procedural *)
total = 0;
Do[total += i^2, {i, 1, 100}];
total

(* Functional *)
Total[Range[100]^2]
Sum[i^2, {i, 100}]
```

**Building a list conditionally:**

```wl
(* Procedural *)
result = {};
Do[If[Mod[i, 3] == 0, AppendTo[result, i]], {i, 30}];

(* Functional *)
result = Select[Range[30], Mod[#, 3] == 0 &];
result = Range[3, 30, 3];
```

**Updating state over a sequence:**

```wl
(* Procedural *)
balance = 1000;
Do[balance = balance (1 + 0.05) - 100, {10}];

(* Functional *)
balance = Nest[# (1 + 0.05) - 100 &, 1000, 10];
```

**Finding the first element that satisfies a condition:**

```wl
(* Procedural *)
Catch[Do[If[PrimeQ[2^n - 1], Throw[n]], {n, 100, 200}]]

(* Functional *)
SelectFirst[Range[100, 200], PrimeQ[2^# - 1] &]
(* 107 *)
```

---

## 7. Performance considerations

Functional code is usually faster than procedural code in Wolfram Language, but not always. Some guidelines:

1. **Prefer listable operations** over `Map` when possible: `Sin[list]` is faster than `Sin /@ list`.
2. **Avoid `AppendTo` in loops**: it copies the list each time, giving $O(n^2)$ behavior. Use `Table`, `Map`, `Reap`/`Sow`, or `Internal`Bag` instead.
3. **Keep arrays packed**: mixing integers and reals, or including symbols, unpacks arrays and slows everything down.
4. **Beware of `ReplaceRepeated` with sequence patterns**: rules like `{a___, x_, x_, b___} :> {a, x, b}` are very slow on long lists.
5. **Use `Compile` or `FunctionCompile`** for numerical inner loops that can't be vectorized.

| Approach | Time for $n = 10^6$ |
|:---------|--------------------:|
| `Do` loop with `AppendTo` | (too slow to measure) |
| `Table[i^2, {i, n}]` | 0.041 s |
| `Map[#^2 &, Range[n]]` | 0.012 s |
| `Range[n]^2` | 0.003 s |

---

## 8. Exercises

Try these to practice:

1. Write a function that returns the sum of the digits of an integer without using `Total`. *(Hint: `Fold` and `IntegerDigits`.)*
2. Given a list of words, return an association from each first letter to the list of words starting with that letter. *(Hint: `GroupBy`.)*
3. Implement `myMap[f, list]` using only `Fold` and `Append`, then explain why it's slow.
4. Rewrite this loop functionally:
   ```wl
   x = 1; steps = 0;
   While[x < 1000, x = 2 x + 1; steps++];
   steps
   ```
5. Compute the first 20 rows of Pascal's triangle with `NestList`.

Solutions to exercises 1 and 5:

```wl
digitSum[n_Integer] := Fold[Plus, 0, IntegerDigits[n]]

pascal = NestList[Join[{1}, Total /@ Partition[#, 2, 1], {1}] &, {1}, 19];
pascal[[5]]
(* {1, 4, 6, 4, 1} *)
```

For more, see the [Functional Programming guide](paclet:guide/FunctionalProgramming) and the tutorial on [Functional Operations](paclet:tutorial/FunctionalOperations).
