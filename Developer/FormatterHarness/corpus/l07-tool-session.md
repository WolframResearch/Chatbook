Let me look up the documentation for that function first.

TOOLCALL: DocumentationSearcher
{
	"query": "find the longest common subsequence of two strings"
}
ENDARGUMENTS
ENDTOOLCALL
RESULT
# Search Results

### LongestCommonSubsequence

LongestCommonSubsequence[s1, s2] finds the longest contiguous subsequence common to the strings or lists s1 and s2.

URI: paclet:ref/LongestCommonSubsequence

### LongestCommonSequence

LongestCommonSequence[s1, s2] finds the longest sequence of contiguous or disjoint elements common to s1 and s2.

URI: paclet:ref/LongestCommonSequence

### SequenceAlignment

SequenceAlignment[s1, s2] finds an optimal alignment of sequences of elements in s1 and s2.

URI: paclet:ref/SequenceAlignment
ENDRESULT(n0e5dq2l1)

There are two related functions, and the naming is a bit confusing:

- [`LongestCommonSubsequence`](paclet:ref/LongestCommonSubsequence) finds the longest **contiguous** run of characters.
- [`LongestCommonSequence`](paclet:ref/LongestCommonSequence) allows **gaps**, which is what's usually called the "longest common subsequence" in computer science.

Let me check this with your example strings.

TOOLCALL: WolframLanguageEvaluator
{
	"code": "{LongestCommonSubsequence[\"AGGTAB\", \"GXTXAYB\"], LongestCommonSequence[\"AGGTAB\", \"GXTXAYB\"]}"
}
ENDARGUMENTS
ENDTOOLCALL
RESULT
Out[1]= {"GT", "GTAB"}
ENDRESULT(7hd02kxpa)

As expected, the contiguous version gives `"GT"`, while the version with gaps gives `"GTAB"`, which has length 4.

Now let me plot how the length of the result grows for random strings of increasing length.

TOOLCALL: WolframLanguageEvaluator
{
	"code": "ListLinePlot[Table[StringLength[LongestCommonSequence[StringJoin[RandomChoice[{\"A\",\"C\",\"G\",\"T\"}, n]], StringJoin[RandomChoice[{\"A\",\"C\",\"G\",\"T\"}, n]]]], {n, 10, 200, 10}], DataRange -> {10, 200}]"
}
ENDARGUMENTS
ENDTOOLCALL
RESULT
Syntax::bktmcp: Expression "ListLinePlot[Table[StringLength[...], {n, 10, 200, 10}], DataRange -> {10, 200}" has no closing "]".
ENDRESULT(q1w2e3r4t)

/retry
TOOLCALL: WolframLanguageEvaluator
{
	"code": "SeedRandom[1]; rand[n_] := StringJoin[RandomChoice[{\"A\", \"C\", \"G\", \"T\"}, n]]; ListLinePlot[Table[{n, StringLength[LongestCommonSequence[rand[n], rand[n]]]}, {n, 10, 200, 10}], AxesLabel -> {\"n\", \"length\"}]"
}
ENDARGUMENTS
ENDTOOLCALL
RESULT
Out[2]= ![Plot of Sin](attachment://content-61m1i)
ENDRESULT(z9x8c7v6b)

The length grows roughly linearly with $n$. For random strings over a 4-letter alphabet, the expected length of the longest common subsequence is about $0.65 n$ (the [Chvátal–Sankoff constant](https://en.wikipedia.org/wiki/Chv%C3%A1tal%E2%80%93Sankoff_constants) for $k = 4$).

Finally, here's the population data you asked about.

TOOLCALL: WolframAlpha
{
	"input": "population of Brazil vs Argentina"
}
ENDARGUMENTS
ENDTOOLCALL
RESULT
Input interpretation: Brazil | Argentina | population
Results: Brazil | 216.4 million people (world rank: 7th) (2023 estimate)
Argentina | 46.65 million people (world rank: 33rd) (2023 estimate)
ENDRESULT(m5n6b7v8c)

## Summary

| Question | Answer |
|:---------|:-------|
| Contiguous common substring | `LongestCommonSubsequence` gives `"GT"` |
| Common subsequence with gaps | `LongestCommonSequence` gives `"GTAB"` |
| Growth for random DNA strings | about $0.65 n$ |
| Population ratio, Brazil : Argentina | about 4.6 : 1 |

Here's a reusable function based on the code above:

```wl
lcsLength[s1_String, s2_String] := StringLength @ LongestCommonSequence[s1, s2]
```
