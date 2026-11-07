# Formatter restructure plan

> This is the plan that the formatter restructure PRs implement, written before them (main at 375156fb). Quirk
> numbers refer to positions in `QUIRKS.md` (the n-th `###` entry). Benchmark numbers come from prototypes on one
> machine; each PR reports its own measurements. The user approved D1, D2 (B1–B5), D3 (a), D5 and D6; D4 was not
> taken up.

Three designs were written independently (a two-phase block/inline parser, a conservative restructure of the
rule-based approach, and a streaming-first incremental design), then scored and merged into this one. It covers
`Source/Chatbook/Formatting.wl` (3,890 lines, main at 375156fb). Inputs: `QUIRKS.md` (244 quirks, 52 encoded), the
harness (`README.md`), and the 864 tests in `Tests/Formatting*.wlt`. "Measured" means re-run while merging the
designs; other numbers come from the design named next to them.

## 0. Summary

* **Base: the conservative design.** It keeps the `StringSplit` rule tables that define today's behavior, names and
  documents them, merges the two escape paths into one, swaps three slow patterns for exact equivalents, and splits
  the file into `Source/Chatbook/Formatting/`. The box builders are moved, not rewritten. Its prototype passes all 864
  formatting tests and matches the golden output. It also scores best on reviewability, which the guidance weights
  most heavily.
* **Speed comes from about 30 changed lines, not from a new architecture.** The main per-chunk cost is a `StringSplit`
  that starts another `StringSplit` from inside a rule's right-hand side. `IgnoreCase` is not the cause, so
  the first profile of main got this wrong. Deferring the right-hand sides takes `formatTextString` from 16.1 ms to
  0.25 ms on the baseline example, with identical output (measured). Over the corpus, with all three exact fixes:
  warm Finished takes 0.49× as long as today, warm Streaming 0.15×, and the streaming sequence 0.10× (conservative
  bench). The cold first chat doesn't change (0.97×). Its cost is front end startup, CodeCheckFix and TeX, which no
  design touches.
* **Grafts:**
  * from the streaming design: the corrected hot-spot diagnosis; the rule that refactor PRs are 100% identical,
    behavior PRs list their diffs by category, and the golden file is regenerated after each one; the
    committed-block cache, kept on file as the next step if a measurement ever calls for it.
  * from the parser design: the fix that stops splitting inside an open think tag during streaming; a
    split-consistency test; the newline-consumption table, as documentation; the line-based block scanner, kept as an
    optional later phase.
* **Not adopted:** a new block parser now. It changes more behavior and puts precedence back into code a reviewer has
  to simulate. Replacing `$dynamicSplitRules` with a scanner. Per-file contexts.
* **Quirks (244):** the rewrite fixes 21 as a side effect (1 of them encoded). 18 more get fixed in 5 small follow-up
  PRs (recommended, none encoded). 4 are left to you (paragraph-level precedence). 172 are kept, and 29 are outside
  the formatter.
* **Plan: 7 code PRs after the test PR,** then up to 5 quirk PRs of 5–40 lines each. The largest hand-written diff
  is about 300 changed lines (PR 7). A reviewer can check it mechanically: the rule lists must have the same `Hash`
  before and after. The two move PRs are pure moves.

## 1. Scores

Weights: reviewability ×2, the rest ×1 (maximum 60).

| Criterion | Parser (two-phase) | Conservative (rule tables) | Streaming-first |
|:--|:--|:--|:--|
| (a) Readability | **7**: a declared block table and inert tokens, but Stage 0 shields and the first-line and run-edge rules are subtle | **6**: named rules and documented precedence, but you still have to reason about a leftmost-match `StringSplit` | **6**: clear block types, but it adds commit state, an incremental scan and separator rules to maintain |
| (b) Speed | **8**: linear block scan (a02 display update 495 → 2.7 ms), same inline fix; no end-to-end bench | **8**: benchmarked (warm S 0.15×, sequence 0.10×); long dynamic prose still about 1.7 ms/KB per refresh | **9**: flat 2–3 ms refreshes on long dynamic content plus final-cell reuse; typical answers no faster than the others |
| (c) Parity | **6**: PR 4 identity shown only as per-kind block counts; raw markers on block lines change; two behavior PRs | **9**: prototype 864/864 and golden-identical; the escape diffs are confined to 9 files, one category | **5**: the scanner prototype only round-trips (no masking yet); spacing rules re-derived in `breakItems`; SendChat split replaced |
| (d) Reviewability ×2 | **6**: PR 4 (+350/−150) rewrites precedence, hard to check by reading | **9**: 35-line perf PR, pure moves, rule-table PR checked by `Hash` equality | **4**: 10 PRs including +300 and +250/−400 core PRs; per-file contexts make the move non-pure |
| (e) Effort, blow-up risk | **6**: moderate; edge cases at run boundaries (its Q9, the shields) | **9**: prototypes already exist for both main code PRs | **4**: largest surface (scanner, commit logic, two caches, SendChat) |
| **Weighted total** | **39** | **50** | **32** |

### Claims verified while merging the designs

| Claim | Check | Result |
|:--|:--|:--|
| Inline cost comes from the re-entrant split, not `IgnoreCase` (conservative, streaming) | `formatTextString` on a one-paragraph example: current, outer split without `IgnoreCase`, right-hand sides deferred | 16.1 ms; 0.24 ms; **0.25 ms**, all three outputs identical. The conservative design found that removing `IgnoreCase` *everywhere* keeps it slow (15.9 ms). Re-entering the split is what costs. |
| Possessive `$$mdRow2` is exact and fast (conservative) | top-level split, current vs regex row, all 53 corpus files | a02 806 → **36 ms**; corpus 1007 → **102 ms**; **53/53 identical** splits |
| Conservative prototype matches golden (conservative) | compare log plus a fresh `compare` of unmodified main on f08/s10 | Its only 6 diffs also appear on main (the Entity label is now cached on this machine): **the harness needs a fix first** |
| A line classifier is fast (parser, streaming) | `StringSplit` into lines plus cheap per-line tests | a02 0.17 ms; whole corpus (119 K chars) 17 ms. That's faster still, but after the regex fix the gap is about 85 ms over 53 files. |
| ``` Shortest["``"~~code__~~"``"] ``` is equivalent (parser) | by hand | **Not exact**: ```` "``a```" ```` gives code `` "a`" `` today and `"a"` with `Shortest`. Dropped. |
| Streaming display on long prose (streaming) | 10 KB prose, 40-character steps, no static split, conservative prototype | last-10 refresh mean 24.6 → 16–18 ms; full 10 KB format 224 → 33 ms. `$resultCellCache` reaches 637 KB (157 KB of output); a02 without a split reaches 2.4 MB |
| Streaming scanner parity (streaming) | its `scan3.wl` and notes | Only round-trip is shown, and it doesn't yet mask code spans or block-line prefixes. Parity isn't established. |

## 2. Architecture

### 2.1 Pipeline and data between stages

The shape is today's, with one escape path (PR 3) and inert inline right-hand sides (PR 2):

```
FormatChatOutput[md, <|"Status" -> s|>]        Block[{$dynamicText = (s === "Streaming")}, ...]   (Formatting.wl)
 └ reformatTextData[md]                         same signature; SendChat, Actions, CreateChatNotebook call it (Pipeline.wl)
    1. autoCorrect                               SendChat.wl, unchanged
    2. escapes -> sentinels                      only if md contains \x for x in \ ` $ * _ # | [ ]   (PR 3: one path, now before step 3)
    3. importHTMLEntities                        whole text, unchanged order (entities are still decoded inside code: quirk 31, encoded)
    4. StringSplit[s, $textDataFormatRules, IgnoreCase -> True]    -> flat list {String | token[...]}
    5. discardBadToolCalls                       /retry -> discardedMaterial[...]
    6. makeResultCell /@ parts                   token -> boxes via makeResultCell0 dispatch; $resultCellCache while streaming;
                                                 restoreRawText on raw tokens + unescape output strings when step 2 ran
       └ String parts -> formatTextString        whole-fragment WL shortcut; trim dangling ```; "\n\n" edges -> "\n";
                                                 StringSplit[frag, $stringFormatRules (inert RHS), IgnoreCase -> True], then build
    7. joinAdjacentStrings                       join strings, " \n" front end workaround (fe31de80), trim both ends
```

Tokens between steps 4 and 6 are the existing inert heads: `thoughtsOpener[t, attrs]`, `thinkingOpener[t, attrs]`,
`speechCell[s]`, `codeBlockCell[lang, code]`, `tableCell[s]`, `inlineToolCallCell[s]`, `$discardPreviousToolCall`,
`discardedMaterial[parts...]`, `imageCell[alt, url]`, `bulletCell[indent, text]`, `sectionCell[n, text]`,
`delimiterCell[]`, `blockQuoteCell[s]`, `inlineCodeCell[s]` and `mathCell[s]`. `hyperlinkCell` is never produced and is
deleted (PR 4). Thoughts reuse the whole pipeline: `formatThoughts` calls `reformatTextData` with
`$textDataFormatRules` Block'd to `$thoughtsFormatRules`, which drops the think, tool call and `/retry` rules.

### 2.2 Recognition and precedence

`StringSplit` with a rule list scans left to right. The earliest match position wins, and among rules that match at
the same position, the first one in the list wins. Everything in NOTES follows from that: fences shield their
content, a bullet beats `* * *`, a table beats `> | a |`, a bullet line that starts before `TOOLCALL:` swallows it,
and `$$a\n\nb$$` stays one span. PR 6 moves all rule tables into `Rules.wl`. PR 7 gives each pattern a name, puts
each rule on one line, and adds the tables below as comments. **The lists stay the same expressions as today**, and the PR
proves it with `Hash`.

**Block level, `$textDataFormatRules`** (after PR 3):

| # | Rule → token | Behavior the tests depend on |
|--:|:--|:--|
| 1–5 | think tags: closed with attributes, `<think>`, `<thinking>`, unterminated with attributes, unterminated → `thoughtsOpener`/`thinkingOpener` | `Shortest`; literal closed forms need ≥1 character; the first matching closer wins, with no nesting; swallow fences |
| 6 | `<speech-input>…</speech-input>` → `speechCell` | |
| 7 | whitespace-delimited escaped `\[…\]` → `mathCell` (PR 3) | matches sentinels, so it only fires when the text had escapes |
| 8 | fence → `codeBlockCell` or `tableCell` | `/; toolCallStringFreeQ`; may open mid-line; closes at the next ```` ``` ```` or `EndOfString`; a body that is all table becomes `tableCell` |
| 9–11 | `TOOLCALL:` (optional fence prefix), simple `/cmd`, `/retry` (`$toolCallFormatRules`) | `simpleToolCallStringQ` reads `ToolShortNames` |
| 12 | image `![alt](url)` → `imageCell` | |
| 13 | bullet line → `bulletCell` | consumes **all** preceding `"\n"`; the indent string is kept verbatim |
| 14 | heading line → `sectionCell` | consumes all preceding `"\n"`; more than 6 `#` gives level 6 |
| 15 | thematic break → `delimiterCell` | whole line, unbroken run; consumes no `"\n"` |
| 16 | table `$$mdTable` → `tableCell` | leading `$$wsShortest` can span blank lines; not line-anchored; consumes the trailing `"\n"` |
| 17 | block quote → `blockQuoteCell` | `Longest` run of lines; consumes the trailing `"\n"` |
| 18–19 | ``[`ResourceFunction[…]`](url)`` → `inlineCodeCell`; ``[`label`](url)`` → text rewrite | |
| 20–22 | ` ``code`` `, `` `ctx` `` (`inlineSyntaxQ`), `` `code` `` → `inlineCodeCell` | at paragraph level, code wins over emphasis and link labels (quirks 38, 43) |
| 23–26 | `$$…$$` (can span blank lines, encoded), `\(…\)`, plain `\[…\]` (reachable only through `&#92;`), `$…$` (`probablyMathQ`) | |

**Inline level, `$stringFormatRules`**. It runs on each text fragment and on the text of list items, headings, quotes
and table cells. Order: ```` ``` ```` > `***` > `___` > `**` > `__` > `~~` > ` ``code`` ` > `` `ctx` `` > `` `code` `` >
`*` > `_` > `$$` > `\(` > `\[` > (escaped `\[…\]` with whitespace before it, PR 3) > `$` > image > `[label](url)` >
`\textit{}` > `\textbf{}` > `\[FreeformPrompt]` > `<!scheme://content-xxxxx!>`. Emphasis content can't contain its
marker or `"\n"`. Underscore markers need `WordBoundary`.

**Newline consumption** (documented in `Rules.wl`, the parser design's table): bullets and headings eat every
preceding `"\n"` and emit `{"\n", cell}`. Rules and quotes eat no preceding `"\n"`. Tables eat the blank lines before
them and their trailing `"\n"`. Quotes eat their trailing `"\n"`. `formatTextString` maps a leading or trailing
`"\n\n"` to `"\n"` at every fragment edge. `joinAdjacentStrings` adds `" \n"` before a cell and trims both ends.

Two traps (PR 4 removes the first, and PR 7 has to avoid the second):

* `$$ws` is defined twice (lines 73 and 884). Definitions made with `=` before line 884 (`$$mdRow1`,
  `$$blockQuoteLine`) captured the `Shortest` version; everything after it, and every runtime body, uses the plain
  one. PR 4 renames the first one to `$$wsShortest`, so load order no longer matters.
* `Condition` is `HoldAll`, so named patterns inside it must be inserted with `With`/`Evaluate`, as
  `$toolCallFormatRules` already does. The `Hash` check catches mistakes.

### 2.3 Inline right-hand sides (PR 2)

```wl
SetAttributes[ deferredFormat, HoldAllComplete ];
$stringFormatRulesDeferred = Replace[ $stringFormatRules, (l_ :> r_) :> (l :> deferredFormat[ r ]), { 1 } ];
formatTextString[ str_String ] :=
    Replace[ StringSplit[ prepared @ str, $stringFormatRulesDeferred, IgnoreCase -> True ], deferredFormat[ e_ ] :> e, { 1 } ];
```

The patterns, conditions (all pure), evaluation order and `IgnoreCase` stay the same, so the output is identical. Only
the timing of `styleBox`/`hyperlink`, which call `formatTextString` again, changes: they now run after the outer split
has finished.

### 2.4 Escapes: one path (PR 3)

1. `reformatTextData0` Blocks `$markdownEscapes = StringContainsQ[s, $$mdEscapedCharacter]`. When that's true, it
   replaces escapes with sentinels (`$mdEscapeRules`, one left-to-right pass, so `\\` is consumed first) **before**
   entity decoding. It then runs the same single split as plain text.
2. `makeResultCell1` sits between the cache and `makeResultCell0`. It calls `restoreRawText` on raw tokens
   (`codeBlockCell`, `inlineToolCallCell`, `thoughtsOpener`, `thinkingOpener`, `speechCell`): sentinel → `"\\" <> c`.
   The substitution is a bijection, so this gives back the exact raw text, so code, `ToolCall` TaggingRules and think
   text keep their backslashes. Every other token's output strings are unescaped right there (`$mdUnescapeRules`).
   This has to happen per token: discarded material and large openers are wrapped in `compressUntilViewed`, which a
   global `ReplaceAll` can't see into.
3. Inline code (`$mdUnescapeRules`) and math (`$texUnescapeRules`) keep restoring their own sentinels in
   `makeResultCell0`, as today.
4. The escaped-path `\[…\]` regex becomes block rule 7. Inside fragments it needs real whitespace before it
   (`(?<=\s)`). The first prototype used `(?<!\S)`, which turned `[\[x\]](url)` into math, and the tests caught it.
5. Deleted: `reformatTextDataEscaped(0)`, `reformatTextBeforeCodeBlock`, `textBeforeCodeBlock`,
   `splitToolCallSpacing(0,1)`, `toolCallPartQ`, `toolCallSpacing`, `$textDataFormatRulesNoMarkdownUnescape` and
   `$thoughtsFormatRulesNoMarkdownUnescape`.

Result: the NOTES invariant ("a document with an escape looks like the same document without it") now holds by
construction. 15 of the 16 escaped/plain pairs in QUIRKS.md match, against 1 of 16 today. During streaming, a static
chunk and the final cell can no longer take different paths, which today happens when one escape near the end sends
the final cell down the escaped path.

### 2.5 Streaming, `$dynamicText` and caches

* `$dynamicText` is unchanged. `formatChatOutput` Blocks it, and only the renderers read it (unparsed `BoxData` for WL
  code and inline WL, no CodeCheckFix or front end calls, `"TeXAssistantBoxes"`, `fakeOpenerView`, 200 px images,
  `StyleBox` expression links). Partial constructs come from the rules' `EndOfString` alternatives and the
  dangling-fence strip in `formatTextString`, as today.
* `$resultCellCache` (per response, keyed by `HoldComplete[token]`, reset by SendChat.wl at lines 259 and 391) and
  `$staticCodeBlockCache`/`$useStaticCodeBlockCache` (filled by `writeDynamicChunkAsStatic`, reused by `reformatCell`)
  keep their names and semantics. The tests and the harness Block them.
* Session memos without a bound (an AGENTS.md rule): `importHTMLEntity`, `autoCorrectWLCodeBlock`,
  `externalLanguageQ`, `importImage`, `resizeImage`, `$boxCache`, `displayBase64Boxes`/`$base64Cache` and
  `formatEntityBoxes`. PR 8 bounds them with the halving pattern of `$tokenCountCache` (ChatMessages.wl 773).
* Noted, not done: `$resultCellCache` gains an entry for the growing last part on every refresh (637 KB for a 10 KB
  answer; reset per response). A one-slot cache for the trailing part would bound it, but it needs one slot per
  nesting level because of thoughts. It isn't worth the code until memory shows up as a problem.

### 2.6 Streaming split points stay consistent with the parser

`splitDynamicContent` (SendChat.wl 1778) splits off finished fences, images and tool calls and formats them as static
cells. A split point that isn't also a token boundary makes the static cells differ from the final cell.

* In PR 7, `$dynamicSplitRules` is built from the same named pieces as the block rules (`$$codeFenceOpen`,
  `$$markdownImage`, `$$toolCallEnd`, `$$simpleToolCommand`, `toolCallStringFreeQ`, `simpleToolCallStringQ`). The only
  difference is termination: the split rules have no `EndOfString` alternative, and `TOOLCALL` appends `"\n"`. The
  invariant comment that `dynamicSplitSkipQ` relies on moves next to these definitions unchanged: every match ends
  with ```` ``` ````, `ENDRESULT` or `)`; no terminator is longer than `$dynamicSplitOverlap + 1`; no pattern looks
  past its match. `dynamicSplitSkipQ` doesn't change.
* New test in `DynamicSplit.wlt`, built from the parser and streaming designs: for a set of documents, at every split
  point, formatting the static and dynamic parts separately gives the same tokens as splitting the whole text. It also
  checks the "ends with ```` ``` ````/`ENDRESULT`/`)`" invariant.
* There's one known inconsistency: a fence inside an open `<think>` is a split point but not a token boundary (quirk
  202). Fix PR B3 makes `splitDynamicContent` decline a split whose static part has an unclosed `<think`/`<thinking>`
  opener, and sets `$dynamicSplitChecked` to `None` so the next chunk checks again (about 8 lines in SendChat). That
  fix costs a full split check on each chunk only while thinking text that contains a fence is streaming.

### 2.7 What must not change

* The Common interface (CommonSymbols.wl) defined here: `reformatTextData`, `$dynamicSplitRules`,
  `$resultCellCache`, `$staticCodeBlockCache`, `$useStaticCodeBlockCache`, `$customToolFormatter`,
  `$simpleToolMethod`, `floatingButtonGrid`, `insertCodeBelow`, `makeInteractiveCodeCell`, `toolAutoFormatter`,
  `toolShortNameQ`, `stringToBoxes`, `boxDataQ`, `assistantMessageBox(Active)` and `userMessageBox`.
* Box shapes that Serialization.wl, Explode.wl and Actions.wl match: the InlineSection PaneBox/StyleBox, the bullet
  `TextData` prefix, `TextTableForm` with the HeadedColumns TagBox, the `MarkdownImage` TagBox, the `ImageNotFound`
  template, `ChatCodeBlockTemplate` (plus the Sidebar variant), the three-argument
  `ThoughtsOpener`/`ThinkingOpener`/`EmptyThoughts` template, and the `InlineToolCall` TaggingRules. These are safe
  because the builders are moved, not rewritten.
* The harness internals in SendChat (`writeChunk0`, `dynamicTextDisplay`, `$dynamicSplit`, ...) are not touched.

### 2.8 Deliberately not in this plan (each has a trigger)

* **Line-based block scanner** (the parser design's Stage 1, about +350/−150). It's more readable for block
  constructs and linear on long lines. Trigger: you want many block quirk fixes (§5.2 D), or a measurement shows
  `$$mdRow2` on long pipe-free lines matters (still quadratic at regex speed: 133 ms on an 18 KB line). It would have
  to be golden-identical, with the shields that keep today's behavior.
* **Committed-block streaming cache** (the streaming design, PRs 5–7). Trigger: drive-frontend runs show refreshes
  matter for long dynamic content. Cloud notebooks have no static split, so they reformat the whole
  response on every refresh, about 1.7 ms/KB after PR 2. The streaming design measured 20.4 → 2.8 ms per refresh on
  10 KB of prose.
* **Replacing `$dynamicSplitRules` with a scanner, and final-cell reuse.** These depend on the block cache.

## 3. File layout: `Source/Chatbook/Formatting/`

Every file starts with ``BeginPackage["Wolfram`Chatbook`Formatting`"]; Begin["`Private`"]`` (the
`Tools/DefaultToolDefinitions` precedent). `Formatting/Formatting.wl` loads the rest with
``Get["Wolfram`Chatbook`Formatting`<File>`"]``, as `Tools/Tools.wl` does. Main.wl's ``"Wolfram`Chatbook`Formatting`"``
entry resolves to `Formatting/Formatting.wl`, as ``Tools` `` does. `BuildMX.wls` already collects files recursively
and dumps ``Wolfram`Chatbook` ``, so it needs no change. Rules:

* No new contexts, so the private symbols that tests and the harness use (42 references) keep working.
* Each symbol is defined in exactly one file: `beginDefinition` does `ClearAll`, so a second file's definitions would
  wipe the first.

| File | Contents (current lines) | ~Lines | How |
|:--|:--|--:|:--|
| `Formatting.wl` | header, config (`$maxImageSize`, `$wlCodeString`, `$externalLanguages`, `$delimiterCell`, ...), `StringToBoxes`, `CachedBoxes`, `DisplayBase64Boxes`, `FormatChatOutput`, `FormatToolCall`, sub-file `Get`s, MX init (1–232, 3881–3890) | 250 | moved |
| `Rules.wl` | escape sentinels (`esc`, `$md*Rules`), named patterns, predicates (`toolCallStringFreeQ`, `simpleToolCallStringQ`, `toolShortNameQ`, `inlineSyntaxQ`, `probablyMathQ`, `almostCertainlyWLCodeQ`, `nameQ`, `systemNameQ`), the rule tables (`$textDataFormatRules`, `$toolCallFormatRules`, `$thoughtsFormatRules`, `$stringFormatRules`, `$dynamicSplitRules`) with the precedence and newline tables as comments | 420 | moved in PR 6, restructured in PR 7 |
| `Pipeline.wl` | `reformatTextData(0)`, escape restore and unescape, `importHTMLEntities`, `discardBadToolCalls`, `makeResultCell` + cache + `makeResultCell0` dispatch, `formatTextString`, `joinAdjacentStrings`, `trimWhitespace*` | 300 | moved (the escape part was already rewritten in PR 3) |
| `Blocks.wl` | headings (`inlineSection`, `formatTextToBoxes`, margins, font sizes), bullet and block-quote builders (extracted from `makeResultCell0` in PR 7), thoughts (`thoughtsLabel`, `formatThoughts`), discarded material | 320 | moved |
| `Tables.wl` | `makeTableCell`, `alignTable`, `delimiterAlignment`, `textTableForm`, `formatRaw`, item predicates | 135 | moved |
| `Inline.wl` | `styleBox`, `hyperlink`, `makeInlineCodeCell`, `makeInlineWL`, math clauses, `toTeXBoxes`, `inlineInteractiveCodeCell` | 200 | moved |
| `CodeBlocks.wl` | `makeCodeBlockCell`, `cachedCodeBlockCell`, `stripCodePadding`, `makeInteractiveCodeCell`, `parseCellGroupBlock`, labeled blocks, `codeBlockFrame`, external languages | 330 | moved |
| `CodeBlockButtons.wl` | `floatingButtonGrid`, button labels, `insertCodeBelow` and the other actions, button primitives, `fancyTooltip` (984–1710) | 730 | moved |
| `WLBoxes.wl` | `wlStringToBoxes`, `autoCorrectWLCodeBlock`, `formatSpecialBoxes` and the PacletSymbol/Entity/DateObject/Placeholder/ResourceFunction/NL helpers, `stringToBoxes`, `reparseBoxStructurePacket`, `boxDataQ`, `adjustBoxSpacing` | 400 | moved |
| `ToolCalls.wl` | `inlineToolCall` … `toolAutoFormatter` (2047–2558) | 515 | moved |
| `Images.wl` | `image` … `cloudEmbeddedHTMLImage`, base64 and cloud boxes (3143–3535) | 400 | moved |
| `MessageBoxes.wl` | `assistantMessageBox`, `assistantMessageBoxActive`, `userMessageBox`, templates (3805–3880) | 85 | moved |

The total stays at about 3,900 lines: PR 3 removes about 100, dead code about 70, and package headers add about 15
per file. **The line count doesn't drop.** What improves is that the parsing core (`Rules.wl` + `Pipeline.wl`, about
720 lines) is separate from about 2,800 lines of box and UI code that someone reading the formatter never has to open.
Docs that name `Formatting.wl` (AGENTS.md line 102, `docs/docs-todo.md`, `docs/model-support-examples/gpt-5-4.md`) are
updated in PR 5.

## 4. Performance plan

### 4.1 Changes and measurements

| Hot spot (first profile of main) | Change | Measured |
|:--|:--|:--|
| #2 inline split re-entered from right-hand sides (60% of Streaming self time) | defer the right-hand sides (§2.3) | baseline example 16.1 → 0.25 ms, identical (measured); f09 warm F 145 → 2.2 ms, s04 display update 8.7 → 0.7 ms (conservative) |
| #1 `$$mdRow2` quadratic on long lines | possessive regex (below): it accepts the same strings and has a single possible end | a02 top-level split 806 → 36 ms; corpus 1007 → 102 ms; 53/53 identical (measured). Fuzz: 5,000 random strings identical (conservative) |
| #5 `almostCertainlyWLCodeQ` on every piece (23,542 calls) | test only the text before the first `[`, whitespace, `-` or `:` (no System name contains those; all 7,940 checked) | 871 → 285 ms over 26,701 arguments, identical (conservative) |
| #5 whole dynamic content reformatted on every refresh | unchanged; the three fixes cut its constant | 10 KB prose: 24.6 → 16–18 ms per refresh (measured); a02 sequence 102 s → 5.6 s, display update 142 → 9.1 ms (conservative) |
| #3/#4 CodeCheckFix, front end reparse, TeX, Entity/ResourceFunction boxes | renderers unchanged; session memos bounded (PR 8) | — |
| `autoCorrect` on the whole content on every chunk (SendChat, 5%) | outside the formatter; follow-up | — |

The row pattern replaces ``Except["\n"].. ~~ Repeated["|" ~~ Except["\n"]..., {2, ∞}] ~~ ("\n"|EndOfString)``:

```wl
$$mdRow2 = RegularExpression[ "[^\\n][^\\n|]*+\\|[^\\n|]*+\\|[^\\n]*+(?:\\n|\\z)" ];
```

**Totals, conservative prototype with the three fixes** (full `run.sh bench`, 53 files, against `bench-main.wxf`):

| | first F | warm F | first S | warm S | seq warm | disp/step |
|:--|--:|--:|--:|--:|--:|--:|
| main (ms) | 9834 | 3855 | 2384 | 2325 | 112429 | |
| prototype (ms) | 7364 | 1902 | 362 | 346 | 11093 | |
| ratio | 0.75 | **0.49** | 0.15 | **0.15** | **0.10** | 0.23 |
| ratio without `a*` files | | 0.61 | | 0.20 | 0.53 | |

Adversarial cases, Finished: a 10 KB single line 1814 → 80 ms; 300 bold bullets 2457 → 24 ms; a 200-row table with
bold cells 1646 → 28 ms; 7 KB of escaped prose 1081 → 57 ms. PR 3 measured within noise of PR 2.

### 4.2 Cold path and per-chunk rules (AGENTS.md)

* **Cold is unchanged.** First Finished call in a fresh kernel: 0.97×; cold sequence: 0.87×; first step 37–38 ms
  before and after; load 7.9 s both. Nothing new is loaded or added before the first token. The rule lists are
  constants stored in the MX. **This plan doesn't make the first chat in a fresh kernel noticeably faster**: that
  time is front end start, CodeCheckFix and TeX.
* Every code PR posts `./run.sh bench --baseline=bench-main.wxf` (cold F, cold seq, first F/S, warm F/S, seq,
  disp/step) and runs `TimeToFirstToken.wlt`, `StreamingDisplay.wlt` and `DynamicSplit.wlt`.

### 4.3 What stays slow

* A refresh still reformats all dynamic content: about 1.7 ms/KB for prose after PR 2. That's small for typical
  answers, because the static split keeps dynamic content under 1.6 KB across the corpus. Cloud notebooks don't
  split. The fix is the committed-block cache (§2.8).
* `$$mdRow2` is still quadratic at regex speed (an 18 KB pipe-free line takes 133 ms). The ` ``code`` ` rule is
  quadratic in text with many ` `` `. `parseToolCallString` takes about 0.8 s on a 10 KB one-line tool result; it's
  worth profiling as a follow-up, since there is probably another exact pattern fix there.
* The Finished-mode static writes during streaming (CodeCheckFix and the front end) and the final reformat (1–130 ms
  after a stream) are unchanged.

## 5. Parity strategy and quirk policy

### 5.1 Gates and rules

* **Gates for every PR:**
  * the 864 tests in `Tests/Formatting*.wlt` plus `DynamicSplit.wlt`, `StreamingDisplay.wlt`, `TimeToFirstToken.wlt`,
    `WriteResult.wlt` and `CodeBlockButtons.wlt` (`runtests.sh`);
  * `CHATBOOK_REPO=<worktree> ./run.sh compare golden-main.wxf`, all 8 checks (Finished, Streaming, StreamSteps,
    StreamFinal, three serializations, Messages);
  * CodeInspector on the touched files;
  * for the move PRs, `BuildMX.wls` + `TestPaclet.wls` against the MX build (then delete the MX).
* **Refactor PRs** must be 100% golden-identical and change no test. **Behavior PRs:**
  * list every golden diff by category (`--strings` separates serialization changes);
  * update only the tests that encode the changed behavior;
  * include one drive-frontend screenshot per visible category;
  * regenerate the golden file from the merged result, so the next PR is checked for identity again.
* **Prerequisite, before PR 2:** unmodified main already differs from the golden file in 6 checks (f08 and s10, where
  the `Entity["Country","France"]` label is now cached as a TemplateBox). Normalize Entity TemplateBoxes
  in `NormalizeOutput` (or block the entity store while formatting), regenerate the golden file from main, and confirm
  that main is 100% identical.
* **Cost of strict quirk-for-quirk parity:** skip PR 3. Every other PR is output-identical. You'd keep about 150 lines
  of dual-path code, the 21 quirks below, and static and final cells that can format differently while streaming.

### 5.2 Quirk policy (244)

Numbers are positions in QUIRKS.md (the n-th `###` entry).

**A. Fixed by the rewrite itself: 21 (16 fully, 5 partly; 1 encoded).** Preserving these would mean keeping the
escaped path.

* *Escaped path spacing* (PR 3):
  * line break lost after a code block (36 "Escaped-markdown path drops the line break after a code block", 141);
  * before a code block (150);
  * before a think tag (151);
  * after a think tag (152);
  * between two code blocks (153);
  * around think boxes and speech (203);
  * paragraph indentation after the last code block (171);
  * CRLF around code blocks (168);
  * "Three or more line breaks before a code block" (154, **encoded**: `Escapes-Text-Before-Code-Block-Extra-Newlines`
    flips to the plain result; `Tables-Escaped-Elsewhere` also changes).
* *`\[…\]` handling* (PR 3): whitespace lost around it (77, 156); pulled out of list items and headings (78); breaks a
  table (110, partly); escaped brackets parsed as math (79, 155, 63, partly: the spaces are kept, but it's still math).
* *Escapes in tables and entities* (PR 3): escaped pipes in fenced tables (108); fenced-table spacing and backslashes
  (161); `&#92;` acting as an escape only on the escaped path (160).
* *Speed* (PR 2): "Formatting a very long single line is very slow" (187, partly: long tool results still take about
  1 s in `parseToolCallString`).

**B. Recommended small fix PRs after parity: 18 quirks, 0 encoded, one PR per family (§6).**

* B1 *CRLF*: normalize `"\r\n"` → `"\n"` at the entry of `reformatTextData` (6): 1 "CRLF line endings: plain-text
  line breaks disappear…", 86, 99 (partly: the CRLF half; trailing whitespace on rows stays), 136, 181 "All-CRLF tool
  calls show 'Using'…", 208.
* B2 *HTML entities*: a whitelist decoder (named plus numeric, case-sensitive, bounded cache) and no second decode
  inside thoughts (6): 25 "Entity decoding lowercases arbitrary '&...;' text", 26, 27, 28 "&nbsp; … deleted", 29
  "decoded twice", 204.
* B3 *Streaming*: no split inside an open think tag (1): 202.
* B4 *One-liners* (3): 49 "Four-backtick inline code: raw inlineCodeCell head leaks"; 198 "Empty <think></think>
  shows as an in-progress Thinking box…"; 199 "A complete opening tag with nothing after it is shown as raw text".
* B5 *Lost newline after a block* (2): 10 "The newline after a block quote is lost", 96 "Text right after a table
  with no blank line renders on the same line".

**C. Your call: paragraph-level inline precedence (4), D4.** 38 "Emphasis around inline code at paragraph level is not
applied", 42 "Paragraph break next to inline code collapses", 43 "Link labels containing inline code break the link
at paragraph level", 75 "Top-level emphasis, strikethrough and links around math are broken". Fixing these means
sending paragraph text through the full inline rules. That changes 6–10 corpus files and the encoded 69
"[`code`](url) differs between paragraphs and list items", and it has to keep the encoded display-math spacing (89,
90).

**D. Kept as is: 172 (45 encoded).** The same rules and the same builders give the same output. Examples: no
CommonMark containers or setext headings (7, 8, 18–20, encoded); mid-line fences (37); `$$` across blank lines (89);
entities decoded inside code (31); the `" \n"` workaround (35); table detection quirks (97, 98, 100–107, 109, 111,
112, 118–121); tool call parsing (174–179, 182–185, 189–195); thinking labels (209–211, 213); most image quirks
(217–244 except 222). Many of these become small follow-up PRs once the rules are named, for example heading closing
hashes or `styleBox` styling every part.

**E. Outside the formatter: 29 (6 encoded). Out of scope.**

* Serialization.wl (23): 9, 60, 61, 62, 85, 92, 94, 113–117, 124, 133, 162–167, 180, 212, 222.
* TeXBoxes.wl (2): 83, 93.
* SpeechInput.wl (4): 173, 197, 214, 216.

Inline code unescaping (157) and the serializer re-escaping it (166) cancel each other out, so change both or neither.

## 6. PR plan

| # | PR | Scope | Size | Reviewer verifies by |
|--:|:--|:--|:--|:--|
| 1 | Characterization tests (done) | 9 `Formatting*.wlt` files, `Tests/Common.wl` helpers | ~13k test lines | tests pass on main; encoded quirks are marked |
| 2 | Exact performance fixes in `Formatting.wl` | deferred inline right-hand sides; possessive `$$mdRow2`; `almostCertainlyWLCodeQ` candidate. Tests: old-vs-new row pattern on 1,000 random strings, old-vs-new `almostCertainlyWLCodeQ` over all System names | +35/−11 code, +60 tests; 3 commits | golden 100% identical; tests; bench table (cold and warm) in the description |
| 3 | One escape path (D1) | §2.4; escape before entity decoding; property test: 30+ escaped/plain pairs (`escPair`) give equal `NormalizeTextData` | +40/−140 + test updates | golden diffs only in the 9 escaped files (a03 f02 f04 f06 l03 l10 l11 l16 l17), each "plain-path spacing"; 2 encoded tests flipped; 3 screenshots; golden regenerated |
| 4 | Prep and dead code | `$$ws` → `$$wsShortest` (early uses); delete `$tinyLineBreak`, 3-argument `inlineSection`, `reformatTextData0[other_]`, the `hyperlinkCell` clause, the `"TOOLCALL: "` branch of `makeCodeBlockCell`, `unescapeInlineMarkdown` | ~−70 | golden identical; tests; a coverage run (DownValues hit counts over tests + corpus) attached for each deletion |
| 5 | Move I | `git mv` to `Formatting/Formatting.wl`; extract `CodeBlockButtons`, `WLBoxes`, `ToolCalls`, `Images`, `MessageBoxes`; loader; doc paths | ~2,100 moved, ~80 header lines | `git diff -M --color-moved=dimmed-zebra`: only headers are new; golden identical; BuildMX + TestPaclet |
| 6 | Move II | extract `Rules`, `Pipeline`, `Blocks`, `Tables`, `Inline`, `CodeBlocks` | ~1,700 moved | same as PR 5 |
| 7 | Rule tables | named patterns, one rule per line, precedence and newline tables as comments, `$dynamicSplitRules` built from the shared pieces, bullet and quote builders pulled out of `makeResultCell0`, split-consistency test | ~300 changed in `Rules.wl`/`Pipeline.wl`/`Blocks.wl`, +40 tests | `Hash` of `$textDataFormatRules`, `$stringFormatRules`, `$thoughtsFormatRules` and `$dynamicSplitRules` printed before and after: equal; golden identical |
| 8 | Bounded session memos | one halving helper; the 8 memos in §2.5 | ~+60, +30 tests | golden identical; a test that each memo stops growing; bench shows no regression |
| 9–13 | Quirk fixes B1–B5 (D2) | one family each (§5.2) | 5–40 lines each + tests | golden diffs only in the named category; listed tests updated; screenshot for visible changes; golden regenerated |

* PR 2 is independent. It lands first and gives almost all of the speedup.
* PR 3 applies on top of PR 2, as its prototype does; drop it if you decline D1.
* PR 3 comes before the moves on purpose: its prototype diff applies to the unsplit file, and it deletes about 140
  lines (100 net) that would otherwise be moved and then deleted.
* PR 8 and B1–B4 can land any time after PR 2.
* B3 touches SendChat.wl. Every other PR stays inside `Formatting/`, apart from doc paths.

## 7. Risks

* **The PR 3 cache and sentinel interaction:**
  * Tokens that contain sentinels are separate `$resultCellCache` keys, so they're safe.
  * Text that already contains `\[EntityStart]` is still converted (quirk 170, kept).
  * `restoreRawText` must cover every raw token head. Add one test per head.
* **The `Condition`/`With` trap in PR 7** could change a rule without changing its output on the corpus. The `Hash`
  equality catches it, and PR 7 isn't mergeable without it.
* **Front end and PacletResource-specific tests** (the exact `RowBox` from the front end parser,
  `CodeBlocks-PacletSymbol-Repository`) can fail in a different CI image for reasons unrelated to the formatter.
* **The readability ceiling.** After this plan, explaining an odd output still means simulating a leftmost-match
  `StringSplit`. The rule tables and their comments make that a documented step, not a guessing game. A real block
  parser is still possible later (§2.8), and nothing here blocks it.

## 8. Decisions for the user

* **D1. One escape path (PR 3).** 9 of 53 corpus files change spacing, all toward what the same document looks like
  without escapes. 2 encoded tests flip, and `&#92;` stops acting as an escape. Options:
  * (a) accept;
  * (b) skip, for zero behavior change, keeping about 150 lines of dual-path code.

  *Recommendation: (a).* It's the largest quirk family (21), and it deletes the most special-case code.
* **D2. Which quirk fixes go in with the rewrite.** Options:
  * (a) none beyond D1;
  * (b) B1–B5 (18 quirks, five PRs of 5–40 lines);
  * (c) a subset.

  *Recommendation: (b), in the order B3, B1, B2, B4, B5.* B3 is a visible streaming bug. B1 and B2 are entry-point
  changes that fix 12 quirks and bound a cache.
* **D3. Restructure, or a full rewrite with a new parser.** This plan restructures: same rules, better organized, much
  faster. It does not make precedence simpler. Options:
  * (a) this plan only;
  * (b) add the line-based block scanner afterwards (+350/−150, golden-identical);
  * (c) also add the incremental streaming block cache.

  *Recommendation: (a) now.* Revisit (b) if block quirk fixes pile up, and (c) only if drive-frontend runs show slow
  refreshes on long answers (cloud has no static split).
* **D4. Paragraph-level inline precedence** (§5.2 C: literal `**` around `` `Plot` ``, link labels with code). Options:
  * (a) leave;
  * (b) a separate PR after PR 8 that sends paragraph text through the full inline rules (changes 6–10 corpus files
    and one encoded test).

  *Recommendation: (b), later and on its own, with screenshots.* In the corpus it mostly appears in list items, which
  already work.
* **D5. One shared ``Formatting`Private` `` context, or per-file contexts like ChatModes.** *Recommendation: shared.*
  The moves stay pure, the tests and harness need no edits, and `Tools/` already does it this way. Per-file contexts
  would need cross-file declarations and edits to about 30 test references.
* **D6. Should the harness and corpus go into the repo** (e.g. `Developer/FormatterHarness/`, not shipped)? Reviewers
  need them to check the golden claims. *Recommendation: commit the scripts and the corpus, and keep the 350 KB golden
  file local* (regenerated from main as README describes).
