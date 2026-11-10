## Reading a file line by line

Use `ReadList` or `Import` with the `"Lines"` element:

```wl
lines = Import["data.txt", "Lines"];
Length[lines]
```

For very large files, read one line at a time with a stream:

```wl
stream = OpenRead["data.txt"];
While[(line = ReadLine[stream]) =!= EndOfFile,
  If[StringContainsQ[line, "ERROR"], Print[line]]
];
Close[stream];
```

| Function | Reads | Memory |
|:---------|:------|-------:|
| `Import[..., "Lines"]` | all lines | high |
| `ReadLine` | one line | low |

* Files from Windows often have **CRLF** line endings.
* `ReadLine` strips the line terminator.

> Note: `ReadString` keeps the `\r` characters.

---

That's all you need for most cases.
