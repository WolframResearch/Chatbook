# Creating and Customizing Plots in Wolfram Language

Wolfram Language has a large family of plotting functions that share a common set of options. Below is an overview of the ones you'll use most often, how to customize them, and some common pitfalls.

## Basic Function Plots

The simplest way to visualize a function of one variable is with [`Plot`](paclet:ref/Plot):

```wl
Plot[Sin[x], {x, 0, 2 Pi}]
```

You can plot several functions at once by passing a list. Each function gets its own color automatically:

```wl
Plot[{Sin[x], Cos[x], Sin[x] Cos[x]}, {x, 0, 2 Pi},
  PlotLegends -> "Expressions"]
```

### Common Options

Most plotting functions accept the same options. The most useful ones are:

| Option | Description | Example value |
|:-------|:------------|--------------:|
| `PlotRange` | The range of values to include | `{-1, 1}` |
| `PlotStyle` | Styles for each curve | `{Red, Dashed}` |
| `AxesLabel` | Labels for the axes | `{"x", "y"}` |
| `PlotLegends` | Adds a legend | `"Expressions"` |
| `ImageSize` | Size of the final graphic | `Large` |
| `PlotTheme` | A predefined collection of styles | `"Scientific"` |

Here's an example combining several of these:

```wl
Plot[
  {Sin[x], Cos[x]},
  {x, 0, 2 Pi},
  PlotStyle -> {Directive[Thick, Blue], Directive[Dashed, Red]},
  AxesLabel -> {"x", "f(x)"},
  PlotLabel -> "Trigonometric functions",
  PlotLegends -> {"sin", "cos"},
  ImageSize -> Medium
]
```

**Note:** `PlotRange -> All` shows every computed point, while the default `PlotRange -> Automatic` may clip outliers. If part of your curve seems to be missing, try `PlotRange -> All` first.

## Plotting Data

For discrete data, use [`ListPlot`](paclet:ref/ListPlot) or [`ListLinePlot`](paclet:ref/ListLinePlot). Here's a quick session that creates some noisy data:

```wl
In[1]:= SeedRandom[42];
        data = Table[{x, x^2 + RandomReal[{-5, 5}]}, {x, 0, 10, 0.5}];

In[2]:= Length[data]

Out[2]= 21

In[3]:= Take[data, 3]

Out[3]= {{0., 3.21}, {0.5, -1.87}, {1., 4.6}}
```

Then plot it:

```wl
ListPlot[data, PlotMarkers -> Automatic, Joined -> False]
```

> **Tip:** If your data is a flat list of $y$ values like `{1, 4, 9, 16}`, `ListPlot` automatically uses $x = 1, 2, 3, \ldots$ for the horizontal coordinates.

### Fitting a curve to the data

1. Define the model with [`Fit`](paclet:ref/Fit) or [`NonlinearModelFit`](paclet:ref/NonlinearModelFit).
2. Evaluate the fitted model to see its symbolic form.
3. Show the data and the model together using `Show`:
   ```wl
   fit = Fit[data, {1, x, x^2}, x];
   Show[ListPlot[data], Plot[fit, {x, 0, 10}, PlotStyle -> Red]]
   ```
4. Check the residuals:
   - Use `model["FitResiduals"]` when you used `NonlinearModelFit`
   - Or compute them directly with `data[[All, 2]] - (fit /. x -> data[[All, 1]])`
   - Plot them with `ListPlot` to look for patterns

For a model with parameters, `NonlinearModelFit` gives you much more information:

```wl
model = NonlinearModelFit[data, a x^2 + b x + c, {a, b, c}, x];
model["ParameterTable"]
```

The fitted function is $\hat{y}(x) = a x^2 + b x + c$, and `model["RSquared"]` gives the coefficient of determination $R^2$.

## 3D Plots

For functions of two variables, use [`Plot3D`](paclet:ref/Plot3D):

```wl
Plot3D[Sin[x y], {x, -2, 2}, {y, -2, 2},
  ColorFunction -> "Rainbow",
  Mesh -> None,
  PlotPoints -> 50]
```

Other useful functions for visualizing $f(x, y)$ include:

- **`ContourPlot`** — shows level curves of $f(x, y)$
- **`DensityPlot`** — color-coded values on a grid
- **`ParametricPlot3D`** — surfaces given by parametric equations
  - Use it for spheres, tori, and similar shapes
  - Example: `ParametricPlot3D[{Cos[u] Sin[v], Sin[u] Sin[v], Cos[v]}, {u, 0, 2 Pi}, {v, 0, Pi}]`
- **`RegionPlot3D`** — regions defined by inequalities such as $x^2 + y^2 + z^2 \leq 1$

### Contour plots with labels

```wl
ContourPlot[x^2 - y^2, {x, -2, 2}, {y, -2, 2},
  Contours -> 10,
  ContourLabels -> True,
  ColorFunction -> "TemperatureMap"]
```

## Combining and Arranging Plots

There are two different ideas here, and they're easy to confuse:

* `Show[p1, p2]` **overlays** plots in the same coordinate system.
* `GraphicsRow`, `GraphicsColumn`, and `GraphicsGrid` **arrange** separate plots next to each other.

```wl
p1 = Plot[Sin[x], {x, 0, 2 Pi}];
p2 = Plot[Cos[x], {x, 0, 2 Pi}, PlotStyle -> Orange];
GraphicsRow[{p1, p2, Show[p1, p2]}, ImageSize -> Large]
```

## Exporting

To save a plot as a raster image at print resolution:

```wl
p = Plot[Sin[x], {x, 0, 10}];
Export["sine.png", p, ImageResolution -> 300]
```

You can also export to vector formats such as PDF or SVG, which scale without losing quality:

```wl
Export["sine.pdf", p]
Export["sine.svg", p]
```

---

### Summary

| Task | Function |
|------|----------|
| Function of one variable | `Plot` |
| Discrete data | `ListPlot`, `ListLinePlot` |
| Function of two variables | `Plot3D`, `ContourPlot` |
| Parametric curves | `ParametricPlot` |
| Combining plots | `Show`, `GraphicsRow` |

For more details, see the [Visualization and Graphics guide](paclet:guide/VisualizationAndGraphics) or the online documentation at https://reference.wolfram.com/language/guide/FunctionVisualization.html.
