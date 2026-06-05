<|
    "BasePrompt"       -> { ParentList, "Notebooks", "WolframLanguageStyle" },
    "Description"      -> "Help with writing and generating Wolfram Language code",
    "DisplayName"      -> Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", "PersonaNameNotebookAssistant" ],
    "Hidden"           -> True,
    "Icon"             -> Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatOutputCellDingbat" ],
    "PromptGenerators" -> { "RelatedDocumentation", ParentList },
    "Tools"            -> {
        "WolframLanguageEvaluator",
        "DocumentationSearcher",
        "WolframAlpha",
        "CreateNotebook",
        "WebFetcher",
        ParentList
    }
|>