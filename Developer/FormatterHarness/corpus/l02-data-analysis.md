Great question! Analyzing a CSV file in Wolfram Language usually follows the same pattern: **import**, **inspect**, **clean**, **summarize**, and **visualize**. I'll walk through each step using a sales dataset as an example.

## 1. Importing the data

Use [`Import`](paclet:ref/Import) with the `"Dataset"` element so that the column headers become keys:

```wl
sales = Import["sales_2024.csv", "Dataset", HeaderLines -> 1]
```

If the file uses a different delimiter (for example semicolons, which are common in European locales), specify it explicitly:

```wl
sales = Import["sales_2024.csv", {"CSV", "Dataset"},
  "FieldSeparators" -> ";",
  HeaderLines -> 1]
```

## 2. Inspecting the structure

Before doing any analysis, check what you've got:

```wl
In[3]:= Length[sales]

Out[3]= 1248

In[4]:= Keys[First[sales]] // Normal

Out[4]= {"Date", "Region", "Product", "Units", "UnitPrice", "Discount"}

In[5]:= sales[1 ;; 3]
```

The `Out[4]` result shows six columns. A quick way to see the distinct values in a categorical column is:

```wl
sales[DeleteDuplicates, "Region"]
```

### Column types

| Column | Type | Example | Notes |
|:-------|:-----|:--------|:------|
| `Date` | `DateObject` | `DateObject[{2024, 3, 14}, "Day"]` | Parsed automatically |
| `Region` | `String` | `"North"` | 4 distinct values |
| `Product` | `String` | `"Widget A"` | 12 distinct values |
| `Units` | `Integer` | `17` | Some values are missing |
| `UnitPrice` | `Real` | `24.99` | In US dollars |
| `Discount` | `Real` | `0.1` | Fraction, not percent |

## 3. Cleaning the data

Real-world data almost always has problems. In this dataset, some rows have an empty `Units` field, which `Import` represents as `""` or `Missing[]`, depending on the import options.

To drop rows with missing units:

```wl
clean = sales[Select[IntegerQ[#Units] &]];
Length[clean]
```

To *replace* missing values with zero instead:

```wl
clean = sales[All, <|#, "Units" -> Replace[#Units, Except[_Integer] -> 0]|> &];
```

> **Warning:** Don't use `DeleteMissing` on a `Dataset` of associations to remove rows. It removes *keys* with missing values from each association, which leaves rows with different shapes.

Next, add a computed column for revenue. The revenue for each row is

$$\text{revenue} = \text{units} \times \text{price} \times (1 - \text{discount})$$

```wl
clean = clean[All, <|#, "Revenue" -> #Units #UnitPrice (1 - #Discount)|> &];
```

## 4. Summarizing

Grouping and aggregation are where `Dataset` really shines. Total revenue by region:

```wl
clean[GroupBy["Region"], Total, "Revenue"]
```

Average units and total revenue per product, sorted by revenue:

```wl
clean[
  GroupBy["Product"],
  <|"AvgUnits" -> Mean[#[[All, "Units"]]], "Revenue" -> Total[#[[All, "Revenue"]]]|> &
][SortBy[-#Revenue &]]
```

Here's what the top of the result looks like:

| Product | AvgUnits | Revenue |
|:--------|---------:|--------:|
| Widget A | 18.4 | $48,213.50 |
| Gadget Pro | 9.7 | $41,880.00 |
| Widget B | 21.1 | $29,402.75 |
| Gizmo | 5.2 | $12,977.10 |

Monthly totals are a common request. You can group by a function of the date:

```wl
monthly = clean[GroupBy[DateValue[#Date, {"Year", "Month"}] &], Total, "Revenue"];
```

### Descriptive statistics

For numeric columns, these functions are handy:

- `Mean`, `Median`, `StandardDeviation`
- `Quantile[list, q]` for percentiles, e.g. `Quantile[units, 0.9]`
- `Counts` for frequency tables of categorical values
- `Correlation[x, y]` for the Pearson correlation coefficient $r$

```wl
units = Normal[clean[All, "Units"]];
<|"Mean" -> Mean[units], "Median" -> Median[units], "SD" -> StandardDeviation[units]|> // N
```

## 5. Visualizing

A bar chart of revenue by region:

```wl
BarChart[
  Normal @ clean[GroupBy["Region"], Total, "Revenue"],
  ChartLabels -> Automatic,
  AxesLabel -> {None, "Revenue (USD)"}
]
```

A time series of monthly revenue:

```wl
DateListPlot[
  KeyValueMap[{DateObject[#1, "Month"], #2} &, Normal[monthly]],
  Joined -> True,
  PlotMarkers -> Automatic,
  PlotLabel -> "Monthly revenue"
]
```

And a histogram of order sizes:

```wl
Histogram[units, {1}, AxesLabel -> {"Units", "Orders"}]
```

## Comparison with pandas

If you're coming from Python, here's how the same steps look with pandas:

```python
import pandas as pd

sales = pd.read_csv("sales_2024.csv", parse_dates=["Date"])
clean = sales.dropna(subset=["Units"])
clean["Revenue"] = clean["Units"] * clean["UnitPrice"] * (1 - clean["Discount"])
print(clean.groupby("Region")["Revenue"].sum())
```

| pandas | Wolfram Language |
|:-------|:-----------------|
| `pd.read_csv(...)` | `Import[..., "Dataset"]` |
| `df.dropna(subset=[...])` | `ds[Select[...]]` |
| `df.groupby("col")["x"].sum()` | `ds[GroupBy["col"], Total, "x"]` |
| `df.sort_values("x")` | `ds[SortBy["x"]]` |
| `df.describe()` | `Map[Mean, ...]`, `Quantile`, ... |

You can also run the pandas code from inside a notebook with `ExternalEvaluate["Python", ...]` if you have a Python environment configured.

---

Let me know if you'd like help with a specific part of your dataset, such as handling dates in a nonstandard format or exporting the summary back to Excel with `Export["summary.xlsx", ...]`.
