# AGENTS.md

This file provides guidance to AI agents (Claude Code, Cursor, etc.) when working with code in this repository.

## Project Overview

Chatbook (`Wolfram/Chatbook`) is a Wolfram Language paclet that adds LLM-powered notebook support to Wolfram. It integrates chat-based AI interactions directly into Wolfram notebooks, with tool use, prompt augmentation, persona management, and sandboxed code evaluation.

- **Language**: Wolfram Language (`.wl` files)
- **Requires**: Wolfram Engine 14.3+
- **Primary Context**: ``Wolfram`Chatbook` ``
- **License**: MIT

## Development

Always use the WolframLanguageContext tool when working with Wolfram Language code to ensure that you are aware of the latest documentation and other Wolfram resources.

When you make changes to paclet source code, you should also write and run tests for the changes you made using the TestReport tool and check your work with the CodeInspector tool.

If you need to test changes in the WolframLanguageEvaluator tool, you'll first need to evaluate:
```wl
PacletDirectoryLoad[ "path/to/Chatbook" ];
Get[ "Wolfram`Chatbook`" ]
```

Use fully qualified names for Chatbook symbols in the WolframLanguageEvaluator tool to avoid accidental shadowing with the global context.

Note: Using the TestReport tool is much more reliable for testing code changes.

If you've previously built an MX file for the paclet, you should delete it before testing your changes. You can find it in `Source/Chatbook/64Bit/Chatbook.mx`.

If a symbol appears to be undefined when you expected otherwise, check to see if it's in a different context than you expected:

```wl
Names[ "*`nameOfSymbol" ]
```

## Common Commands

```shell
# Build optimized MX (compiled binary) for package code
wolframscript -f Scripts/BuildMX.wls

# Build the full paclet (includes code check, MX build, unformatting)
wolframscript -f Scripts/BuildPaclet.wls

# Build paclet with specific options
wolframscript -f Scripts/BuildPaclet.wls --check=false --snippets=false --install=true

# Run tests (builds first if needed)
wolframscript -f Scripts/TestPaclet.wls

# Format/unformat source files
wolframscript -f Scripts/FormatFiles.wls
wolframscript -f Scripts/UnformatFiles.wls

# Check paclet integrity
wolframscript -f Scripts/CheckPaclet.wls
```

## Architecture

### Package Loading

The entry point is `Source/Chatbook/Chatbook.wl`, which either loads the pre-compiled MX file (`Source/Chatbook/64Bit/Chatbook.mx`) for fast startup or falls back to loading source via ``Get["Wolfram`Chatbook`Main`"]``. The MX file is rebuilt with `Scripts/BuildMX.wls`.

### Startup Ordering

PacletInfo.wl defines three kernel extensions loaded in order:
1. ``Wolfram`Chatbook`BeginStartup` `` (`Source/Startup/Begin/`) — pre-initialization
2. ``Wolfram`Chatbook` `` (`Source/Chatbook/`) — main package
3. ``Wolfram`Chatbook`EndStartup` `` (`Source/Startup/End/`) — cleanup, removes contexts from `$ContextPath`

### Source Organization (`Source/Chatbook/`)

- **Main.wl** — Public symbol declarations (the API surface)
- **Common.wl** — Shared utilities, error handling primitives, pattern definitions
- **CommonSymbols.wl** — Symbol declarations shared across subpackages
- **SendChat.wl** — Core chat message sending logic
- **Serialization.wl** — Chat data serialization/deserialization
- **Formatting.wl** — LLM response formatting for notebook display
- **ChatMessages.wl** / **ChatState.wl** — Message history and session state
- **Settings.wl** — User preferences management; **PreferencesContent.wl** — preferences UI
- **Sandbox.wl** — Sandboxed Wolfram Language evaluation for LLM-generated code
- **Storage.wl** — Persistent chat storage; **SearchChats.wl** / **Search.wl** — search
- **Models.wl** — LLM model definitions and family classification
- **Prompting.wl** — Base prompt component management and on-demand prompt system
- **Personas.wl** / **PersonaManager.wl** — LLM persona (system prompt) management
- **UI.wl** — Chat UI components; **Actions.wl** — User actions
- **CreateChatNotebook.wl** / **ConvertChatNotebook.wl** — Notebook creation/conversion

**Subdirectories:**
- **ChatModes/** — Chat mode extensions (Evaluate, UI, Context, NotebookAssistance, ContentSuggestions)
- **PromptGenerators/** — Prompt augmentation (RelatedDocumentation, WolframAlpha queries, VectorDatabases, NotebookChunking)
- **Tools/** — LLM tool definitions (WolframLanguageEvaluator, WebSearcher, WebFetcher, DocumentationSearcher, WolframAlpha, NotebookEditor, etc.)

### Error Handling Pattern

The codebase uses a structured exception system defined in `Common.wl`:
- `catchTop` / `catchTopAs` — Top-level error catching for public API functions
- `catchMine` — Catches errors from the current function
- `throwFailure` / `throwInternalFailure` — Throws structured `Failure` objects
- `messageFailure` — Creates failure objects with message formatting
- `beginDefinition` / `endDefinition` / `endExportedDefinition` — Function definition guards

### LLM Personas

Ten built-in personas in `LLMConfiguration/Personas/`: AgentOne, AgentOneCoder, Birdnardo, CodeAssistant, CodeWriter, NotebookAssistant, PlainChat, RawModel, Wolfie, WolframAlpha. Each has its own system prompt and configuration.

### Stylesheet

The Chatbook notebook stylesheet (`FrontEnd/StyleSheets/Chatbook.nb`) is generated programmatically:
1. Edit style definitions in `Developer/Resources/Styles.wl`
2. Load `Developer/StylesheetBuilder.wl`
3. Evaluate `BuildChatbookStylesheet[]`

### Assets

- `.wxf` files — Serialized Wolfram expressions (icons, display functions, syntax data)
- `Assets/Snippets/Streamable/` — Documentation snippets downloaded during build (not in repo)
- `Assets/Tokenizers/` — Token counting resources
- `Assets/AIAssistant/` — AI assistant configurations

## Code Conventions

- Source files use cell markers like `(* ::Section::Closed:: *)` for organization
- Private symbols go in `` `Private` `` context via ``Begin["`Private`"]`` / `End[]`
- Code analysis directives: `(* :!CodeAnalysis::BeginBlock:: *)` to suppress specific warnings
- Pattern variables use `$$` prefix for reusable patterns (e.g., `$$chatInputStyle`, `$$string`)
- Build scripts use ``Wolfram`PacletCICD` `` for CI/CD utilities

## Testing

Tests are in `Tests/` using Wolfram's `VerificationTest` framework. Tests require a FrontEnd (`UsingFrontEnd`) since Chatbook is a notebook-based tool. Test utilities in `Tests/Common.wl` provide `WithTestNotebook`, `CreateTestChatNotebook`, and `CreateChatCells` helpers.

## CI/CD

GitHub Actions workflows in `.github/workflows/`:
- **Build.yml** — PR validation: build + test (wolframengine:14.3.0 Docker container)
- **Release.yml** — Publish to Wolfram Paclet Repository on push to `release/paclet`
- **IncrementPacletVersion.yml** — Auto-increments version in PacletInfo.wl on main branch pushes

## Documentation

Developer documentation lives in the `docs/` directory:

- **[adding-model-support.md](docs/adding-model-support.md)** — Guide for adding support for new LLM models
- **[model-support-examples/](docs/model-support-examples/)** — Real-world case studies (e.g., GPT 5.4)
- **[settings/](docs/settings/)** — Complete settings reference with per-group documentation
- **[docs-todo.md](docs/docs-todo.md)** — Backlog of documentation still needed

## Special Considerations

The tools provided by the WolframLanguage MCP server are using Chatbook functions under the hood. For example:

- WolframLanguageContext uses `RelatedDocumentation` (`Source/Chatbook/PromptGenerators/RelatedDocumentation.wl`)
- WolframLanguageEvaluator uses `WolframLanguageToolEvaluate` (`Source/Chatbook/Sandbox.wl`)

Be aware that making changes to these functions or their dependencies and reloading the paclet in the WolframLanguageEvaluator tool may have unexpected effects on these tools.

As a fallback, you can write WL code in a temporary file and evaluate it with:
```bash
wolframscript -f "path/to/temporary.wl"
```

Or if it's very simple code:
```bash
wolframscript -code 'Print[1 + 1]'
```

Both of these will evaluate the code in an entirely separate process.
