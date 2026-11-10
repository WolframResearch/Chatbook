Here's a comparison of the three rounding functions:

| Function | `2.5` | `-2.5` | `3.7` |
|:---------|:-----:|:------:|------:|
| `Round`  | 2     | -2     | 4     |
| `Floor`  | 2     | -3     | 3     |
| `Ceiling`| 3     | -2     | 4     |

Note that `Round` uses *banker's rounding* for exact halves, rounding to the nearest even integer.
