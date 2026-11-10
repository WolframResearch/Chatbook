Code blocks in various languages:

```wl
Table[i^2, {i, 5}]
```

```wolfram
Map[f, {a, b}]
```

```mathematica
Integrate[1/x, x]
```

```Wolfram Language
StringLength["hello"]
```

```WL
1 + 1
```

```text
Plain text output, not code.
  Indented line.
```

```plaintext
C:\\Users\\name\\file.txt
```

```json
{"name": "Chatbook", "version": "2.0", "tags": ["llm", "notebooks"]}
```

```python
def greet(name: str) -> str:
    return f"Hello, {name}!"
```

```bash
for f in *.wl; do wolframscript -f "$f"; done
```

```sh
export PATH="$HOME/bin:$PATH"
```

```javascript
const sum = [1, 2, 3].reduce((a, b) => a + b, 0);
```

```js
console.log("short js tag")
```

```sql
SELECT * FROM users WHERE id = 1;
```

```r
mean(c(1, 2, 3))
```

```julia
println(sum(1:10))
```

```ruby
puts [1, 2, 3].map { |x| x * 2 }.inspect
```

```toml
[package]
name = "example"
```

```
No language specified
```

```wl  
Trailing spaces after the language tag
```

````markdown
A fenced block that contains another fence:
```wl
nested[]
```
````

```wl
    Indented[code];
    Every[line, is, indented]
```

```
| a | b |
|---|---|
| 1 | 2 |
```

```wl
(* comment only *)
```

Inline triple backticks: ```Range[10]``` should be inline code.
