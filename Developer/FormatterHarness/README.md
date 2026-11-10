# Formatter differential testing and benchmarks

Tools for checking changes to the Chatbook markdown formatter (`Source/Chatbook/Formatting/`) against the
code on main: a corpus of realistic LLM responses, a golden snapshot of what the main formatter makes of them, a
comparison script that shows the first difference in each output, and benchmarks. `QUIRKS.md` lists current
formatter behavior that looks wrong, found while writing the `Tests/Formatting*.wlt` characterization tests.

Everything here runs against the Chatbook checkout named by `CHATBOOK_REPO` (default: the checkout that contains this
directory), so you can point it at a git worktree that holds a change. Nothing writes to that checkout. Golden files
and benchmark results are local (`.gitignore`): make them from main on your machine, as described below.

## Quick start

```bash
cd Developer/FormatterHarness

# Make the golden file and the benchmark baseline from main (once per machine; see "Regenerating the golden file"):
CHATBOOK_REPO=/path/to/main ./run.sh snapshot golden-main.wxf
CHATBOOK_REPO=/path/to/main ./run.sh bench --out=bench-main

# Compare a worktree with the golden snapshot of main (exit code 0 if everything is identical):
CHATBOOK_REPO=/path/to/worktree ./run.sh compare golden-main.wxf

# Only the CellToString serialization (what chat history and copy actions see):
CHATBOOK_REPO=/path/to/worktree ./run.sh compare golden-main.wxf --strings

# Some files only, and more than the default 50 printed differences:
CHATBOOK_REPO=/path/to/worktree ./run.sh compare golden-main.wxf --files='l0*,s01*' --max=200

# Everything except the slow long-lines file (30 s instead of 2 minutes):
CHATBOOK_REPO=/path/to/worktree ./run.sh compare golden-main.wxf --files='!a02*'

# Benchmark the worktree and compare with the main baseline:
CHATBOOK_REPO=/path/to/worktree ./run.sh bench --out=bench-rewrite --baseline=bench-main.wxf

# Run test files with a front end available:
./runtests.sh ../../Tests/FormattingBlocks.wlt ../../Tests/FormattingTables.wlt
```

Wolfram Language code blocks are formatted with a front end call (`FrontEnd`ReparseBoxStructurePacket`), so the
scripts need a kernel that can start a front end. `run.sh`, `runtests.sh` and `evalwl.sh` go through `withfe.sh`,
which uses `xvfb-run` on Linux when there is no display and filters the X11/segfault noise that the Xvfb front end
prints when it shuts down. A full snapshot or compare of the corpus takes about 2 minutes on main, 1.5 of them for
`a02-long-lines.md`, and the benchmark about 10 minutes. `--files` takes comma-separated file
name patterns with `*` wildcards; patterns starting with `!` exclude files.

## Files

| File | Purpose |
|:-----|:--------|
| `corpus/*.md` | 53 LLM responses (see "Corpus" below); `corpus/assets/` has two small PNGs that some responses show |
| `warmup.md` | warm-up document for the benchmark and profile (not part of the corpus) |
| `harness.wl` | shared code: loading, formatting entry points, streaming simulation, normalization, encoding, diffs |
| `snapshot.wls` | formats the corpus and writes a golden `.wxf` file |
| `compare.wls` | recomputes everything and compares with a golden file |
| `bench.wls` | timings per file (cold, first, warm, streaming sequence); writes `NAME.wxf` and `NAME.md` |
| `profile.wls` | hot-spot breakdown of the current formatter (self time per function and item type) |
| `run.sh` | runs one of the scripts with a front end |
| `runtests.sh`, `runtests.wls` | runs `.wlt` test files in one kernel with a front end, with a short failure report |
| `evalwl.sh` | evaluates a `.wl` file with Chatbook loaded from source and a front end (for probing behavior) |
| `withfe.sh` | runs a command so that its kernels can start a front end |
| `QUIRKS.md` | formatter behavior that looks wrong, with repros (not encoded in tests) |
| `RestructurePlan.md` | the plan that the formatter restructure PRs implement |
| `golden-*.wxf`, `bench-*.wxf`, `bench-*.md`, `profile-*.md` | local results (not committed) |

## What is compared

For each corpus file, `snapshot.wls` stores, and `compare.wls` checks:

| Check | What |
|:------|:-----|
| `Finished` | `FormatChatOutput[md, <\|"Status" -> "Finished"\|>]` |
| `Streaming` | `FormatChatOutput[md, <\|"Status" -> "Streaming"\|>]` on the whole text |
| `StreamSteps` | the simulated streaming display, step by step (below) |
| `StreamFinal` | the final cell written after the simulated stream |
| `FinishedString`, `StreamingString`, `StreamFinalString` | `CellToString` of the above, as stored in chat history |
| `Messages` | messages issued while formatting (each mode) |

A difference is printed with the corpus file, the check, the position and head path of the first (depth-first,
leftmost) differing subexpression, and both versions of it, truncated:

```
DIFF a01-crlf.md [Finished]
    position: {1, 1, 1, 1, 1, 1, 1, 4, 2}
    path:     RawBoxes[1] > Cell[1] > TextData[1] > {}[1] > Cell[1] > BoxData[1] > PaneBox[1] > StyleBox[4] > Rule[2]
    expected: 22
    actual:   23
```

`{}[k]` in the path is the k-th TextData item. For strings, the note shows where they start to differ; for
serializations, the first differing line with two lines of context. For `StreamSteps`, it shows how many steps
differ and the first one (with the number of characters streamed so far, and whether the static cells or the dynamic
display differ).

### Simulated streaming

`SimulateStream` in `harness.wl` reproduces what a chat shows while a response streams in, using the real SendChat
code with the front end writes stubbed out:

1. The text is split into 40-character chunks (whole characters, sent as UTF-8 byte strings like the LLM services
   deliver them).
2. Each chunk goes through `writeChunk0`, which appends it to the container (with `autoCorrect`), splits completed
   code blocks, images and tool calls out of the dynamic content (`splitDynamicContent`, `$dynamicSplitRules`), and
   formats them as static cells (`writeDynamicChunkAsStatic`: `reformatTextData` with `$dynamicText = False`,
   `$useStaticCodeBlockCache = True`, and code block templates switched to the "Active" variants). The cells that
   would be written to the notebook are recorded.
3. After each chunk, the dynamic content is formatted like the output cell's `Dynamic` does it
   (`dynamicTextDisplay`, which calls `FormatChatOutput` with `"Status" -> "Streaming"` and adds the progress
   indicator). The real display refreshes on a timer and skips some of these, which doesn't matter for comparisons.
4. At the end, the full content is formatted like `reformatCell` does it (Finished, with the static code block cache
   that step 2 filled in).

Not simulated: cloud notebooks, which format the whole content on every refresh without the static split. The
`Streaming` check covers formatting of complete documents in streaming mode.

### Normalization

Outputs are normalized before they are stored or compared (`NormalizeOutput` in `harness.wl`):

* generated symbols (`x$123`, `x$$123`, `$123`) become `GeneratedSymbol["x$N"]`
* `CellObject`, `BoxObject`, `NotebookObject` and `FrontEndObject` references
* UUID strings
* the "Thought for N seconds" label of literal `<think>` tags (it depends on how long formatting took while
  streaming), which becomes `"<ThoughtDurationLabel>"`
* formatted `Entity`/`EntityClass`/`EntityProperty` TemplateBoxes, which become the unformatted `RowBox` they hold.
  The harness runs offline, so an entity is only formatted if it's already in this machine's entity store cache.
  Before this was added, the golden file drifted from main once an entity got cached (f08, s10).

Both sides are also round-tripped through WXF, so they are compared in the same form. With the current code, only
the thinking label needed normalizing: two full compares of the golden file against the code it was made from were
100% identical, and so were compares of subsets (`--files`), where each file is formatted after different files
than in the golden run (this needed the `$CloudBase` and serialization fixes below).

### Environment the harness sets up

* `$AllowInternet` is `False` (scoped with `Block`; assigning it would persist), so that branches needing the network take their offline path on every machine. This
  affects `\[FreeformPrompt]["..."]` in finished WL code blocks (it asks WolframAlpha, and issues
  `WolframAlpha::offline`, which is recorded as an expected message for `s10-freeform.md` and
  `f08-inline-wl-specials.md`).
* `ClickToCopy`: when Chatbook is loaded from source rather than the MX build, the `ClickToCopy` resource function is
  downloaded the first time it's used (tool call parameters with the "Simple" tool method). The harness replaces it
  with an inert `FormatterHarness`ClickToCopyStub`.
* `$CloudBase` is set to its resolved default (`https://www.wolframcloud.com/`) if it is still `Automatic`. It is
  resolved as a side effect of formatting `ResourceFunction` boxes, and until then, images that fail to import issue
  `URLParse::invuri` (from `cloudURLQ`), so the messages for `l06-image-processing.md` depended on which files ran
  before it.
* Before each `CellToString` call, the memoized values of `serializeTraditionalForm` and
  `serializeStandardFormString` (Serialization.wl) are cleared. They cache results that depend on Block-scoped flags
  at the time of the first call, so the same math box serializes differently depending on where it was first seen
  in the session: `$O(1)$` in a table cell of `p04-mid-table.md` (streaming) gives `O(1)` normally, but `` ``O``(1) ``
  after `l11-api-reference.md`, which has `$O(1)$` in running text. That is also how it behaves in a real session.
* The attachments that the corpus refers to (`attachment://content-61m1i`, `content-yyd33`, `expression://...`) are
  registered with `MakeExpressionURI` before formatting.
* `$ChatHandlerData` gets `"ChatNotebookSettings"` (`"AutoFormat" -> True`, `"ToolMethod" -> "Service"`) and
  `"ToolShortNames"` for the default tools, so `/wl`-style simple tool calls are recognized.
  `f07-simple-toolcalls.md` uses `"ToolMethod" -> "Simple"` (`$fileSettings` in `harness.wl`).
* Before each document and mode, the state that SendChat resets for each response is reset: `$resultCellCache`,
  `$staticCodeBlockCache`, the thinking timers, and `$dynamicSplitChecked`. Session-level memoization
  (`importHTMLEntity`, `autoCorrectWLCodeBlock`, `$boxCache`, `importImage`, ...) is not reset, as in a real session.
* If `Source/Chatbook/64Bit/Chatbook.mx` exists in the checkout, it is loaded instead of the source files; the scripts
  print a warning. Delete it when testing source changes.

### Chatbook internals used by the harness

The harness only calls public functions for the one-shot formatting (`FormatChatOutput`, `CellToString`,
`MakeExpressionURI`). The streaming simulation and the environment setup use these internals, all in
`harness.wl`. If the rewrite renames one of them, update it there:

* ``Wolfram`Chatbook`SendChat`Private` ``: `writeChunk0`, `dynamicTextDisplay`, `getFormattingFunction`,
  `$dynamicSplit`, `$dynamicSplitChecked`, `openChatCell` (stubbed)
* ``Wolfram`Chatbook`Common` ``: `$resultCellCache`, `$staticCodeBlockCache`, `$useStaticCodeBlockCache`,
  `$dynamicText`, `$thinkingStart`, `$thinkingEnd`, `$alwaysOpen`, `toolShortName`, `clickToCopy`, `trRaw`,
  `$thisPaclet`
* ``Wolfram`Chatbook`Serialization`Private` ``: `serializeTraditionalForm`, `serializeStandardFormString` (memos
  cleared)

`profile.wls` instruments private functions of the `Formatting/` files by name; it is meant for the current code and
skips functions that don't exist.

## Benchmark

`./run.sh bench [--out=NAME] [--files=...] [--cold=default|all|none|pattern] [--reps=10] [--seq-reps=3] [--baseline=FILE.wxf]`

`NAME` (default `bench-latest`) is relative to this directory unless it is an absolute path; the benchmark writes
`NAME.wxf` and `NAME.md`.

Columns (times in ms):

| Column | Meaning |
|:-------|:--------|
| cold F | first `Finished` call in a fresh kernel, right after loading Chatbook (separate process) |
| cold seq | whole simulated streaming sequence as the first thing in a fresh kernel (separate process) |
| first F / first S | first `Finished` / `Streaming` call for this file in the benchmark kernel (warmed up on `warmup.md` and the files before it; this file's content is new, so session memoization doesn't help) |
| warm F / warm S | median of `--reps` repeated calls, per-response caches reset before each |
| seq first / seq warm | simulated streaming sequence (all chunks, display after each, final cell); first run and median of `--seq-reps` runs |
| disp/step | median time of one display update in the warm sequence |

Cold runs are only done for `--cold` files (default: `s01-plot-basic.md`, `l01-plotting-guide.md`,
`l03-equation-solving.md`, `l16-assistant-session.md`; `all` adds about 25 s per file). With `--baseline`, the report
ends with new/baseline ratios per file and in total (< 1 is faster).

Timings depend on what else the machine is doing. Compare runs
made close together, and rerun if a ratio looks surprising. Two runs of the same code agreed within about 5% on the warm columns
and 10% on totals; the "first" and "cold" columns are single measurements and vary more (up to 40% on small files).

## Profile

`./run.sh profile [--files=...] [--out=NAME]` writes a table of self time per instrumented function (and per
TextData item type for `makeResultCell0`) for Finished, Streaming, and the streaming sequence. It checks that the
instrumented code gives the same results as the uninstrumented code.

## Corpus

53 files, named by kind:

* `s*` short answers (one paragraph to a few blocks)
* `l*` long answers (2 to 9.5 KB, seven over 5 KB) with headings, nested lists, several WL code blocks and In/Out transcripts, Python and
  shell blocks, aligned tables, links, math, block quotes, rules, think tags, tool calls with results
* `p*` streaming prefixes: responses cut off inside a code block, think tag, tool call, table, bold text, math
* `f*` feature-focused: HTML entities, markdown escapes, block quotes and rules, nested lists, headings, code block
  languages, simple tool calls, special WL boxes, emphasis, auto-correction, Moonshot tool calls, In/Out labels
* `a*` adversarial: `\r\n` line endings, very long lines (18 KB with a 6 KB paragraph), unicode, unbalanced markers,
  odd whitespace, a tiny answer

Images use local files or attachment URIs, never http(s) URLs. Local files are written as
`{{CorpusAssets}}/name.png`, which `ReadCorpusFile` replaces with the absolute path of `corpus/assets`. That path ends
up in the outputs, so a golden file only works on the machine and checkout location it was made in.

### Regenerating the golden file

The golden file must be made with the main code. After adding or editing corpus files, regenerate it from a main
checkout, then check that it is deterministic:

```bash
CHATBOOK_REPO=/path/to/main ./run.sh snapshot golden-main.wxf
CHATBOOK_REPO=/path/to/main ./run.sh compare golden-main.wxf   # must be 100% identical
```

`compare.wls` warns when a corpus file changed after the golden file was made (the input hash is stored).
