There are a few equivalent ways to apply a function to every element of a list:

- `Map[f, {a, b, c}]` gives `{f[a], f[b], f[c]}`
- `f /@ {a, b, c}` is the operator form of `Map`
- `Table[f[x], {x, {a, b, c}}]` iterates explicitly

If your function is *listable* (like `Sin` or `Plus`), you can simply write `Sin[{1, 2, 3}]` and it threads automatically. For pure functions, use `#` and `&`, for example `#^2 & /@ Range[5]` returns `{1, 4, 9, 16, 25}`.

To apply a function to the *arguments* instead, use `Apply` (`@@`): `Plus @@ {1, 2, 3}` evaluates to `6`. Rules like `x -> 2` and delayed rules like `f[x_] :> x^2` work with `ReplaceAll` (`/.`).
