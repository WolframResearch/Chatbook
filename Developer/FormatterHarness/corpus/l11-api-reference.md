# Associations: A Complete Reference

[`Association`](paclet:ref/Association) is Wolfram Language's key-value data structure, similar to dictionaries in Python or maps in other languages. This reference covers creation, access, modification, and the functions that work with associations, along with performance notes.

---

## Creating associations

There are several ways to create an association:

```wl
a = <|"apple" -> 3, "banana" -> 5, "cherry" -> 7|>;
b = Association[{"x" -> 1, "y" -> 2}];
c = AssociationThread[{"a", "b", "c"}, {1, 2, 3}];
d = AssociationMap[StringLength, {"one", "three", "five"}];
e = Counts[{"a", "b", "a", "c", "a"}];
```

| Function | Input | Result |
|:---------|:------|:-------|
| `Association` | list of rules | `<\|"x" -> 1, "y" -> 2\|>` |
| `AssociationThread` | keys and values | `<\|"a" -> 1, "b" -> 2, "c" -> 3\|>` |
| `AssociationMap` | function and keys | `<\|"one" -> 3, "three" -> 5, "five" -> 4\|>` |
| `Counts` | list of elements | `<\|"a" -> 3, "b" -> 1, "c" -> 1\|>` |
| `GroupBy` | list and a function | groups as values |
| `PositionIndex` | list | positions as values |

> **Note:** Keys can be any expression, not just strings. `<|1 -> "one", {1, 2} -> "pair", f[x] -> "expr"|>` is a valid association.

---

## Accessing values

### By key

```wl
In[1]:= a["banana"]

Out[1]= 5

In[2]:= a["durian"]

Out[2]= Missing["KeyAbsent", "durian"]

In[3]:= Lookup[a, "durian", 0]

Out[3]= 0
```

Use [`Lookup`](paclet:ref/Lookup) when you need a default value, or when you want to look up several keys at once: `Lookup[a, {"apple", "cherry"}]` gives `{3, 7}`.

### By position

Associations are ordered, so you can also use `Part` with integer indices:

- `a[[1]]` gives the first *value*, `3`
- `a[[{1, 3}]]` gives a sub-association with the first and third entries
- `a[[Key["apple"]]]` is the same as `a["apple"]`
- `First[a]` and `Last[a]` give values, not rules

### Nested access

For nested associations, chain the keys:

```wl
config = <|"server" -> <|"host" -> "localhost", "port" -> 8080|>, "debug" -> True|>;
config["server", "port"]
(* 8080 *)
```

---

## Modifying associations

Associations are *immutable values*, but you can update a variable that holds one:

| Operation | Syntax | Effect |
|:----------|:-------|:-------|
| Add or update a key | `a["date"] = 9` | modifies `a` in place |
| Add several keys | `AssociateTo[a, {"fig" -> 2, "grape" -> 4}]` | modifies `a` in place |
| Remove a key | `KeyDropFrom[a, "fig"]` | modifies `a` in place |
| Return a new association | `Append[a, "kiwi" -> 1]` | `a` is unchanged |
| Remove keys (new value) | `KeyDrop[a, {"apple"}]` | `a` is unchanged |
| Keep only some keys | `KeyTake[a, {"apple", "cherry"}]` | `a` is unchanged |

For nested updates, use part assignment:

```wl
config["server", "port"] = 9090;
```

This works only if `config["server"]` already exists and is an association.

---

## Functions that work with associations

### Mapping and filtering

- **`Map`** applies a function to the values: `Map[#^2 &, a]`
  - The keys are unchanged
  - Use `KeyMap` to transform the keys instead
- **`KeyValueMap`** gives a list, applying the function to each key and value: `KeyValueMap[#1 <> ": " <> ToString[#2] &, a]`
- **`Select`** filters by value: `Select[a, # > 4 &]`
- **`KeySelect`** filters by key: `KeySelect[a, StringStartsQ["b"]]`
- **`DeleteCases`** removes values that match a pattern

### Sorting

| Function | Sorts by | Example |
|:---------|:---------|:--------|
| `Sort` | values | `Sort[a]` |
| `KeySort` | keys | `KeySort[a]` |
| `SortBy` | a function of the values | `SortBy[a, Minus]` |
| `ReverseSort` | values, descending | `ReverseSort[a]` |
| `TakeLargest` | the largest values | `TakeLargest[a, 2]` |

### Combining

`Merge` combines several associations, using a function to resolve duplicate keys:

```wl
Merge[{<|"a" -> 1, "b" -> 2|>, <|"b" -> 10, "c" -> 20|>}, Total]
(* <|"a" -> 1, "b" -> 12, "c" -> 20|> *)
```

`Join` simply lets later values override earlier ones:

```wl
Join[<|"a" -> 1, "b" -> 2|>, <|"b" -> 10|>]
(* <|"a" -> 1, "b" -> 10|> *)
```

### Queries

[`Query`](paclet:ref/Query) and `Dataset` work naturally with lists of associations:

```wl
people = {
  <|"name" -> "Ana", "age" -> 31, "city" -> "Lisbon"|>,
  <|"name" -> "Ben", "age" -> 25, "city" -> "Boston"|>,
  <|"name" -> "Chen", "age" -> 42, "city" -> "Boston"|>
};

Query[Select[#city == "Boston" &], "name"][people]
(* {"Ben", "Chen"} *)

Query[GroupBy["city"], Mean, "age"][people]
(* <|"Lisbon" -> 31, "Boston" -> 67/2|> *)
```

---

## Performance

Associations are implemented as hash tables, so key lookup is $O(1)$ on average regardless of size. Some operations, however, are linear in the size of the association:

| Operation | Complexity | Notes |
|----------:|:----------:|:------|
| `a[key]` | $O(1)$ | hash lookup |
| `a[key] = v` | $O(1)$ amortized | in-place update |
| `KeyExistsQ[a, key]` | $O(1)$ | faster than `MemberQ[Keys[a], key]` |
| `a[[i]]` | $O(1)$ | by position |
| `Append[a, k -> v]` | $O(n)$ | copies the association |
| `KeyDrop[a, key]` | $O(n)$ | copies the association |
| `Keys[a]`, `Values[a]` | $O(n)$ | creates a new list |

**Tip:** if you build an association incrementally in a loop, use `a[key] = value` or `AssociateTo`, not `a = Append[a, key -> value]`, which copies the entire association each time and leads to $O(n^2)$ total cost.

---

## Converting to and from other forms

1. To a list of rules: `Normal[a]`
2. To keys and values: `Keys[a]`, `Values[a]`
3. To JSON: `ExportString[a, "RawJSON"]`
   * Nested associations become nested JSON objects
   * Lists become JSON arrays
4. From JSON: `ImportString[json, "RawJSON"]` or `Developer`ReadRawJSONString[json]`
5. To a `Dataset`: `Dataset[a]`

```wl
In[10]:= ExportString[<|"name" -> "Ana", "tags" -> {"a", "b"}, "active" -> True|>, "RawJSON", "Compact" -> True]

Out[10]= "{\"name\":\"Ana\",\"tags\":[\"a\",\"b\"],\"active\":true}"
```

---

### See also

* [Associations guide](paclet:guide/Associations)
* [`Dataset`](paclet:ref/Dataset), [`Query`](paclet:ref/Query), [`GroupBy`](paclet:ref/GroupBy)
* [Elementary Introduction, Chapter 34: Associations](https://www.wolfram.com/language/elementary-introduction/3rd-ed/34-associations.html)
