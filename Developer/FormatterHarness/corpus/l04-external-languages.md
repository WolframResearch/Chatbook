You can call code in other languages from Wolfram Language using [`ExternalEvaluate`](paclet:ref/ExternalEvaluate). Here's how to set it up and use it for the languages you mentioned.

## Python

First, make sure Wolfram Language can find a Python installation:

```wl
FindExternalEvaluators["Python"]
```

If nothing is found, install Python 3 and the `pyzmq` package, then register it:

```bash
python3 -m pip install --upgrade pyzmq numpy
which python3
```

```wl
RegisterExternalEvaluator["Python", "/usr/bin/python3"]
```

Now you can evaluate Python code directly:

```wl
ExternalEvaluate["Python", "import math; math.factorial(20)"]
```

For multi-line code, it's usually easier to start a session and reuse it:

```wl
session = StartExternalSession["Python"];
ExternalEvaluate[session, "
import numpy as np
def moving_average(x, n):
    return np.convolve(x, np.ones(n) / n, mode='valid')
"];
ExternalEvaluate[session, "moving_average([1, 2, 3, 4, 5, 6], 3).tolist()"]
```

The equivalent standalone Python script would be:

```python
import numpy as np

def moving_average(x, n):
    """Return the n-point moving average of x."""
    return np.convolve(x, np.ones(n) / n, mode="valid")

if __name__ == "__main__":
    print(moving_average([1, 2, 3, 4, 5, 6], 3).tolist())
    # [2.0, 3.0, 4.0, 5.0]
```

Remember to close the session when you're done with `DeleteObject[session]`.

## Shell commands

For shell commands, you can use either `ExternalEvaluate["Shell", ...]` or [`RunProcess`](paclet:ref/RunProcess):

```sh
ls -la ~/Documents | head -n 5
echo "Number of files: $(ls ~/Documents | wc -l)"
```

```wl
RunProcess[{"ls", "-la"}, "StandardOutput"]
```

`RunProcess` returns an association with the keys `"ExitCode"`, `"StandardOutput"`, and `"StandardError"`, which makes it easier to handle errors than `Run`.

## JavaScript (Node.js)

With Node.js installed, use `"NodeJS"` as the system:

```javascript
const fib = n => (n < 2 ? n : fib(n - 1) + fib(n - 2));
console.log([...Array(10).keys()].map(fib));
```

```wl
ExternalEvaluate["NodeJS", "[1, 2, 3].map(x => x * 2)"]
(* {2, 4, 6} *)
```

## SQL

To query a SQLite database, create a [`DatabaseReference`](paclet:ref/DatabaseReference) and use [`SQLExecute`](paclet:ref/SQLExecute) or `ExternalEvaluate`:

```sql
SELECT region, SUM(units * unit_price) AS revenue
FROM sales
WHERE order_date >= '2024-01-01'
GROUP BY region
ORDER BY revenue DESC;
```

```wl
db = DatabaseReference[File["sales.sqlite"]];
ExternalEvaluate[db, "SELECT COUNT(*) FROM sales"]
```

## R and Julia

R and Julia are also supported, as long as the corresponding runtimes are installed:

```r
x <- c(2.1, 3.4, 1.9, 5.6)
summary(x)
```

```julia
using Statistics
x = [2.1, 3.4, 1.9, 5.6]
println(mean(x), " ", std(x))
```

## Supported systems

| System | `ExternalEvaluate` name | Requirements |
|:-------|:------------------------|:-------------|
| Python | `"Python"` | Python 3.x with `pyzmq` |
| Node.js | `"NodeJS"` | Node.js 10+ |
| Shell | `"Shell"` | A POSIX shell |
| SQL | `DatabaseReference[...]` | A database driver |
| R | `"R"` | R with `rJava`-free setup |
| Julia | `"Julia"` | Julia 1.x with `ZMQ.jl` |
| Ruby | `"Ruby"` | Ruby with `ffi-rzmq` |

> **Tip:** You can create an external language cell in a notebook by typing `>` at the start of an empty cell. The cell's language is shown in the top left corner, and you can change it from the menu.

If you run into `ExternalEvaluate::nopythonevals` or similar errors, it usually means the evaluator isn't registered or a required package is missing. Run `FindExternalEvaluators[]` to see what's available on your system.
