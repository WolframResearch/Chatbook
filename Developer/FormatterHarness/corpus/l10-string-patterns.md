String patterns in Wolfram Language come in two flavors: **symbolic string patterns** built from `StringExpression` (`~~`), and **regular expressions** given with `RegularExpression`. You can mix them freely.

## Symbolic patterns

The basic building blocks are:

| Pattern | Matches |
|:--------|:--------|
| `"abc"` | the literal string `abc` |
| `_` | any single character |
| `__` | one or more characters |
| `___` | zero or more characters |
| `DigitCharacter` | a single digit `0`–`9` |
| `LetterCharacter` | a single letter |
| `WhitespaceCharacter` | a space, tab, or newline |
| `Except["x"]` | any character other than `x` |

Combine them with `~~`:

```wl
In[1]:= StringCases["Order #123 shipped, order #4567 pending", "#" ~~ DigitCharacter ..]

Out[1]= {"#123", "#4567"}
```

Name the parts of a pattern to extract them:

```wl
StringCases["key1=value1; key2=value2", k : WordCharacter .. ~~ "=" ~~ v : WordCharacter .. :> (k -> v)]
(* {"key1" -> "value1", "key2" -> "value2"} *)
```

## Regular expressions

The same extraction with a regular expression looks like this:

```wl
StringCases["Order #123 shipped, order #4567 pending", RegularExpression["#\\d+"]]
```

Note the **double backslash**: inside a Wolfram Language string, `\\` represents a single backslash, so `"#\\d+"` is the regex `#\d+`. This is the most common source of confusion with `RegularExpression`.

Some useful regex constructs:

- `\\d`, `\\w`, `\\s` — digit, word character, whitespace
- `\\b` — word boundary
- `(?i)` — case-insensitive matching, e.g. `RegularExpression["(?i)hello"]`
- `$1`, `$2` — references to captured groups in the replacement

```wl
StringReplace["2024-03-14", RegularExpression["(\\d{4})-(\\d{2})-(\\d{2})"] -> "$3/$2/$1"]
(* "14/03/2024" *)
```

> In the replacement string, `"$3/$2/$1"` refers to the captured groups. To get a literal dollar sign, write `"\\$"`.

## Escaping special characters

When you write about patterns in plain text, characters like \* and \_ have special meaning in Markdown, so I've escaped them here. In Wolfram Language itself:

- `*` is just a character in string patterns, but it's a wildcard in `StringMatchQ["abc", "a*"]` (the "abbreviated" string pattern form, where `*` matches zero or more characters and `@` matches non-uppercase characters).
- `\` must be written as `"\\"` inside a string.
- `"` must be written as `"\""` inside a string.

For example, to match a literal asterisk with `StringMatchQ` and a string containing a quote:

```wl
StringMatchQ["a*b", "a" ~~ "*" ~~ "b"]
(* True *)

StringLength["He said \"hi\""]
(* 12 *)
```

If you need to match a literal backslash with a regex, you need four backslashes: `RegularExpression["\\\\"]`.

## Practical examples

### Splitting CSV-like lines with quoted fields

```wl
splitCSVLine[line_String] := StringCases[
  line,
  ("\"" ~~ f : Except["\""] ... ~~ "\"") | (f : Except[","] ..) :> f
]

splitCSVLine["apple,\"banana, ripe\",cherry"]
(* {"apple", "banana, ripe", "cherry"} *)
```

### Validating an email address (roughly)

```wl
emailQ[s_String] := StringMatchQ[s,
  RegularExpression["[\\w.+-]+@[\\w-]+\\.[\\w.-]+"]]

emailQ /@ {"alice@example.com", "bob@", "carol.smith+news@mail.co.uk"}
(* {True, False, True} *)
```

### Replacing with a function

`StringReplace` accepts `RuleDelayed` (`:>`) so you can compute the replacement:

```wl
StringReplace["The price is 100 dollars and 250 dollars",
  n : DigitCharacter .. :> ToString[1.1 ToExpression[n]]]
(* "The price is 110. dollars and 275. dollars" *)
```

## Performance notes

* Symbolic patterns are compiled to regular expressions internally, so there's usually no speed difference.
* `StringContainsQ` and `StringStartsQ` are much faster than `StringMatchQ[s, ___ ~~ "x" ~~ ___]` for simple checks.
* For many literal replacements at once, give `StringReplace` a list of rules, which is faster than applying the rules one at a time with `Fold`.

Use `StringPattern`StringPatternToRegularExpression`... actually, the supported way to see the regex that a symbolic pattern compiles to is ``StringPattern`PatternConvert["#" ~~ DigitCharacter ..]``, which returns `{"(?ms)#\\d+", {}, {}, Hold[None]}`.
