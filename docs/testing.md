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
