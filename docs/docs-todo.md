## Developer documentation pages needed

* [ ] Settings
  - Source: `Source/Chatbook/Settings.wl`
  - [x] Listing of available settings
  - [ ] Settings resolution for `Automatic` values (relevant: `AbsoluteCurrentChatSettings`)
  - [x] How to add support for new models

* [ ] Citations
  - Source: `Source/Chatbook/Citations.wl`

* [ ] Base prompts
  - Source: `Source/Chatbook/Prompting.wl`
  - [ ] Base prompt component listing and ordering (`$basePromptOrder`)
  - [ ] On-demand base prompts (`$disabledBasePrompts`, `"EnabledBasePrompts"` setting)
  - [ ] Base prompt dependencies (`$basePromptDependencies`)

* [ ] Prompt generators
  - [ ] Related documentation
    - Source: `Source/Chatbook/PromptGenerators/RelatedDocumentation.wl`
  - [ ] Related Wolfram Alpha results
  - [ ] Vector databases
  - [ ] Building vector databases

* [ ] Tools
  - [ ] DocumentationLookup
  - [ ] DocumentationSearcher
  - [ ] WolframAlpha
  - [ ] WolframLanguageEvaluator
  - [ ] CreateNotebook
  - [ ] WebFetcher
  - [ ] WebImageSearcher
  - [ ] WebSearcher

* [ ] Personas
  - [ ] CodeAssistant
  - [ ] PlainChat
  - [ ] RawModel
  - [ ] AgentOne
  - [ ] AgentOneCoder
  - [ ] NotebookAssistant
  - [ ] WolframAlpha

* [ ] Notebook Assistant
  - Source: `Source/Chatbook/ChatModes/ShowNotebookAssistance.wl`
  - [ ] Programmatic use of Notebook Assistant

* [ ] Footer Chat
  - Sources: `Source/Chatbook/ChatModes/UI.wl`, `Source/Chatbook/ChatModes/Evaluate.wl`
  - Resources: `Developer/Resources/DynamicContent/FooterChat/`
  - [ ] Footer and midline chat input cell UI
  - [ ] Inline chat evaluation

* [ ] Markdown conversion
  - [ ] Converting notebook content to Markdown
    - Source: `Source/Chatbook/Serialization.wl`
  - [ ] Converting Markdown to notebook content
    - Source: `Source/Chatbook/Formatting.wl`

* [ ] Handler functions
  - Source: `Source/Chatbook/Handlers.wl`

* [ ] Downstream dependencies
  - [ ] Paclets
    - PromptResource
    - Wolfram/LLMFunctions
    - Wolfram/MCPServer
    - Wolfram/NotebookAssistantCloudResources
    - Wolfram/NotebookAssistantRAGData
    - WolframChatbookInstaller
  - [ ] Resource Functions
    - ImportMarkdownString
    - ExportMarkdownString

* [ ] Symbols
  - [ ] AbsoluteCurrentChatSettings
  - [ ] AgentEvaluate
  - [ ] CellToString
  - [ ] ChatbookFilesDirectory
  - [ ] CurrentChatSettings
  - [ ] ExplodeCell
  - [ ] FormatChatOutput
  - [ ] GenerateLLMConfiguration
  - [ ] GetAttachments
  - [ ] GetExpressionURI
  - [ ] GetExpressionURIs
  - [ ] InstallVectorDatabases
  - [ ] LoadAttachments
  - [ ] LogChatTiming
  - [ ] ProcessNotebookForRAG
  - [ ] RegisterVectorDatabase
  - [ ] RelatedDocumentation
  - [ ] RelatedWolframAlphaQueries
  - [ ] RelatedWolframAlphaResults
  - [ ] ShowNotebookAssistance
  - [ ] StringToBoxes
  - [ ] WolframLanguageToolEvaluate
  - [ ] $AvailableTools
  - [ ] $ChatbookFilesDirectory
  - [ ] $ChatHandlerData
  - [ ] $ChatNotebookEvaluation
  - [ ] $ChatTimingData
  - [ ] $DefaultTools

## Creating new documentation pages

Create new developer documentation pages as Markdown files in the `docs` directory. If there are subitems, create a directory in the `docs` directory for them. Each directory should have a `README.md` file that summarizes the contents of the directory.

Before writing the new page, thoroughly explore and review the relevant source code to ensure that all the relevant information is understood. Ask clarifying questions if needed.

Link to other relevant documentation pages as needed.