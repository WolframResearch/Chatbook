To write a literal asterisk in Markdown, escape it with a backslash: \*not italic\*. The same goes for underscores like \_this\_ and for \# at the start of a line.

\# This is not a heading

Other escapes: \[brackets\], a pipe \| character, a backtick \`, and a dollar sign: the price is \$5, not math. A literal backslash is written \\.

Escapes inside inline code are not processed: `\*` stays as typed, and `a\_b` too.

```wl
StringReplace["a*b", "*" -> "\\*"]
```

Mixed: **bold with \* inside** and *italic with \_ inside*.

| Column \| with pipe | Value |
|---|---|
| a\*b | 1 |
