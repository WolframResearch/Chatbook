To plot a function in Wolfram Language, use [`Plot`](paclet:ref/Plot) with the function and a range for the variable:

```wl
Plot[Sin[x], {x, 0, 2 Pi}]
```

You can plot several functions together by giving a list, and add a legend with `PlotLegends`:

```wl
Plot[{Sin[x], Cos[x]}, {x, 0, 2 Pi}, PlotLegends -> "Expressions"]
```
