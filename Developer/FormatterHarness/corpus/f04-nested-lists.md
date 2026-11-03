Here's how the evaluation process works, step by step:

- **Parsing**: the input string is converted into an expression
  - Operators are converted to their full forms, e.g. `a + b` becomes `Plus[a, b]`
  - Special characters like `\[Alpha]` are interpreted
    - Unknown named characters cause a syntax error
    - Unicode characters are kept as they are
- **Evaluation**: the expression is evaluated using the standard evaluation sequence
  * The head is evaluated first
  * Then the arguments, unless the function has a `Hold` attribute
* **Formatting**: the result is converted to boxes for display

Numbered steps with nested bullets:

1. Evaluate the head
2. Evaluate each argument in order
   - Skip arguments that are held
   - Flatten `Sequence` objects
3. Apply transformation rules
   1. User-defined rules first
   2. Then built-in rules
4. Repeat until the expression no longer changes

A list with code inside an item:

- Define a function:
  ```wl
  f[x_] := x^2
  ```
- Call it: `f[3]` returns `9`
- Done

Tab-indented items:

-	first (tab after marker)
	- second (tab indent)
