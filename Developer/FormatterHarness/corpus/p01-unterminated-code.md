Here's a function that computes the Collatz sequence for a given starting value:

```wl
collatz[1] := {1};
collatz[n_Integer?Positive] := Prepend[
  collatz[If[EvenQ[n], n/2, 3 n + 1]],
  n
];

collatz[27] // Length
(* 112 *)
```

To find the starting value under 10,000 with the longest sequence, we can use `MaximalBy`:

```wl
MaximalBy[Range[10000], Length @* coll