## Warm-up document

This file is formatted once before benchmarking so that one-time initialization (front end connection, code check
setup, TeX boxes, tool icons) is not charged to the first corpus file. It is **not** part of the corpus.

Inline `Range[3]`, `Total`, *italic*, a [link](paclet:ref/Total), math $a^2 + b^2$ and $$\sum_{i=1}^n i$$.

```wl
In[1]:= Accumulate[Range[5]]

Out[1]= {1, 3, 6, 10, 15}
```

```wl
Table[Prime[k], {k, 5}]
```

```python
print([k * k for k in range(4)])
```

```text
plain
```

| A | B |
|:--|--:|
| `x` | 1 |

- item
  - subitem

> quoted

---

<think>
warming up
</think>

TOOLCALL: WolframLanguageEvaluator
{
	"code": "1 + 2"
}
ENDARGUMENTS
ENDTOOLCALL
RESULT
Out[2]= 3
ENDRESULT(w4rmup0001)

![warm](file://{{CorpusAssets}}/checker.png) and &amp; entity \* escape.
