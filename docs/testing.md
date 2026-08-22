# Writing and Running Tests

This guide covers how to write and run tests for Chatbook.

## Test File Format

Tests use `VerificationTest` with the following format:

```wl
VerificationTest[
    input,
    expected,
    SameTest -> MatchQ,
    TestID   -> "AnAppropriateTestID"
]
```

You can optionally include expected messages:

```wl
VerificationTest[
    input,
    expected,
    { Chatbook::Tag, ... },
    SameTest -> MatchQ,
    TestID   -> "AnAppropriateTestID"
]
```

### Creating New Test Files

Always start new test files with the following boilerplate:

```wl
(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Name of First Section*)
```

The first test defines some helper functions and ensures that the paclet is loaded from the correct directory. The second test puts the main context into scope.

## TestID Conventions

- Every test should have a `TestID` specification
- If the test corresponds to a GitHub issue, you should include the issue number in the test ID, e.g. `"AnAppropriateTestID-GH#123"`
- Do not manually write the trailing `@@path/to/file.wlt:l,c` suffix
- This location suffix is automatically generated on commit by `Scripts/FormatFiles.wls`

To enable automatic TestID annotation, configure the git hook:

```bash
git config --local core.hooksPath Scripts/.githooks
```

## Running Tests with the TestReport MCP Tool

If you're using an AI coding agent with the Wolfram MCP server, you can run tests using the `TestReport` tool on the `Tests/` directory.

## Running Tests with `wolframscript`

> Note: Only use `wolframscript` for running tests if the TestReport MCP tool is not available.

Run all tests:

```bash
wolframscript -f Scripts/TestPaclet.wls
```

## Unit Tests for Private Symbols

You can write unit tests for private symbols. Suppress linting errors by wrapping the test file content:

```wl
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Your tests here *)

(* :!CodeAnalysis::EndBlock:: *)
```

## Endpoint and Reasoning Tests (`Tests/ResponsesEndpoint.wlt`)

`Tests/ResponsesEndpoint.wlt` covers the OpenAI Responses endpoint path: the endpoint resolver's
decision table (`responsesEndpointQ`, `resolveChatEndpoint`), the reasoning effort clamp
(`resolveReasoningEffort`), the summary request (`requestReasoningSummary`), and the mapping of
structured reasoning onto the `<think>` envelope (`extractBodyChunks`).

### Keep these tests network-free *and* gate-free

This is the constraint that shapes the whole file, and it is easy to break by accident.

`Build.yml` runs in the `wolframengine:14.3.0` container against a *released* `Wolfram/LLMFunctions`.
There:

- `$responsesEndpointAvailable` is `False`, because the released paclet predates the version that
  provides the endpoint.
- `LLMServices`RegisteredServiceQ` does not work.
- `LLMServices`Response` and `LLMServices`ResponseSubmit` do not exist at all.

So a test may not depend on the compatibility gate being open, and **forcing the flag is not enough**
— the registry lookup underneath it fails too. Any new test here must pass with the gate shut.

### Stub the service check, do not try to satisfy it

`responsesEndpointQ` reaches the environment through exactly one function, `responsesServiceQ`.
Give that an `OwnValue` for the duration of the test, which shadows its `DownValues`:

```wl
Block[ { Wolfram`Chatbook`SendChat`Private`responsesServiceQ = Function[ # === "OpenAI" ] },
    Wolfram`Chatbook`Common`responsesEndpointQ[ Automatic, "OpenAI", "GPT54Plus" ]
]
```

Everything below that function — the paclet version check, the registry lookup, the endpoint symbols
— is then irrelevant to the test.

### Test the effort clamp through its two-argument form

`resolveReasoningEffort[ settings ]` looks the family's levels up through `autoModelSetting`, which
means `resolveFullModelSpec` and the model list. Use the two-argument form instead, which takes the
declared levels directly and is pure:

```wl
Wolfram`Chatbook`Common`resolveReasoningEffort[ "None", { "Low", "Medium", "High" } ]  (* -> "Low" *)
```

### Compare endpoint pairs, not service symbol names

Naming `LLMServices`Response` in a test would autoload the paclet, and the symbol is absent in CI
anyway. Compare against the endpoint associations themselves:

```wl
Wolfram`Chatbook`SendChat`Private`resolveChatEndpoint @ settings ===
    Wolfram`Chatbook`SendChat`Private`$responsesEndpoint
```

### Verify gate-independence locally before committing

Re-run the file in a kernel where the gate is shut, and confirm the count is unchanged:

```wl
(* a plain assignment, NOT Block *)
Wolfram`Chatbook`Common`$responsesEndpointAvailable = False;
TestReport[ "Tests/ResponsesEndpoint.wlt" ]
```

Use an assignment rather than `Block`. `Block` makes the symbol local, the paclet's load-time
`ClearAll` then trips over it, and tests start failing with a spurious `ClearAll::clloc` message
failure whose actual and expected output are identical — a confusing result that has nothing to do
with the behaviour under test.

### What does not belong in this file

- **Anything that calls a provider.** A live reasoning summary is not guaranteed even when requested:
  turns that emit a tool call, and turns where the model did little thinking, legitimately return a
  reasoning part with no summary text. A test asserting `<think>` on a real response is flaky by
  construction.
- **Anything driving `LLMServices`ResponseSubmit`.** Streaming *does* honour `$MockAPICalls`, but the
  symbol does not exist in the CI container. Cover streaming behaviour by feeding `extractBodyChunks`
  one chunk at a time, the way the submit handlers do, including a final `"FinishReason"` chunk.
- **Tool-request rendering.** `toolRequestsToStrings` needs `$ChatHandlerData` and a populated tool
  registry. Verify that end to end by hand instead.
- **Anything building real request messages.** `constructMessages` fails without a front end, so such
  a test would need wrapping in `UsingFrontEnd[ ... ]`.
