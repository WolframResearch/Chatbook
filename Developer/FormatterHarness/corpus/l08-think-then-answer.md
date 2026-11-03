<think>
The user wants to know why their `Module` variables seem to "leak" when they use them inside a `Dynamic`. Let me think about what is actually happening.

When you write `Module[{x = 0}, Dynamic[x]]`, the `Module` creates a symbol like `x$123`. The `Dynamic` is returned unevaluated with `x$123` inside it, so the front end keeps a reference to the symbol. Because the `Module` is finished, `x$123` has the attribute `Temporary`... but it isn't garbage collected since the output still references it.

The issues:
1. The value lives in the kernel session, so after a kernel restart the `Dynamic` shows `x$123` instead of a value.
2. If they save the notebook and reopen it, the values are gone.

The right answer is `DynamicModule`, which stores its variables in the front end, so they survive kernel restarts and are saved with the notebook.

I should also mention:
- `DynamicModule` variables are local to each *instance* of the output
- `Initialization` and `SaveDefinitions`
- the `UnsavedVariables` option

Maybe show a counter example. Something like:

```wl
DynamicModule[{n = 0}, Column[{Button["+1", n++], Dynamic[n]}]]
```

That's a nice minimal example. Also the difference in symbol names: `n$$` in the front end vs `n$123` for `Module`.
</think>
The behavior you're seeing comes from a difference between [`Module`](paclet:ref/Module) and [`DynamicModule`](paclet:ref/DynamicModule): they both create local variables, but they store them in different places.

## What `Module` does

When you evaluate

```wl
Module[{x = 0}, Dynamic[x]]
```

the `Module` creates a new symbol with a name like `x$123`, assigns it the value `0`, and returns `Dynamic[x$123]`. The `Module` has finished evaluating at this point, but the output still refers to `x$123`, which lives **in the kernel**. That has two consequences:

1. If you quit the kernel, the output displays `x$123` instead of a value, because the symbol no longer has a value.
2. If you save and reopen the notebook, the value is lost for the same reason.

## What `DynamicModule` does

`DynamicModule` variables are stored **in the front end**, as part of the output itself:

```wl
DynamicModule[{n = 0},
  Column[{
    Button["+1", n++],
    Dynamic[n]
  }]
]
```

Each time you evaluate this, you get an independent counter. The current value of `n` is saved with the notebook and restored when you reopen it. In the underlying boxes, the variable shows up as `n$$` rather than `n$123`.

### Comparison

| | `Module` | `DynamicModule` |
|:--|:--|:--|
| Where variables live | Kernel | Front end |
| Survives kernel restart | No | Yes |
| Saved with the notebook | No | Yes |
| Scoping | Lexical, per evaluation | Per output instance |
| Typical use | Programs | Interactive interfaces |

## When you need definitions too

If your interface calls functions that you defined elsewhere, those definitions are still in the kernel. Use the `Initialization` option or `SaveDefinitions -> True` (for `Manipulate`) so the output keeps working in a fresh session:

```wl
DynamicModule[{n = 5},
  Dynamic[f[n]],
  Initialization :> (f[k_] := Table[i^2, {i, k}])
]
```

> **Tip:** Use `UnsavedVariables -> {var}` for variables that hold large or temporary data that you don't want saved in the notebook.

## Common mistakes

- **Using `Module` inside a `Manipulate`**: `Manipulate` already localizes its control variables, so wrapping it in `Module` usually isn't needed.
- **Mixing `Module` and `DynamicModule` variables**: a `Module` variable inside a `DynamicModule` still lives in the kernel.
- **Very large `DynamicModule` values**: these are stored in the notebook file and can make it slow to open.

So for your example, replacing `Module` with `DynamicModule` should fix the problem:

```wl
DynamicModule[{x = 0}, {Slider[Dynamic[x]], Dynamic[x]}]
```
