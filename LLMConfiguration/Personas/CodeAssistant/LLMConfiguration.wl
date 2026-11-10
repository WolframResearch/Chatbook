<|
    "BasePrompt"       -> { ParentList, "Notebooks", "WolframLanguageStyle" },
    "Description"      -> "Help with writing and generating Wolfram Language code",
    "DisplayName"      -> Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", "PersonaNameCodeAssistant" ],
    "Hidden"           -> True,
    "Icon"             -> Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatOutputCellDingbat" ],
	"PromptGenerators" -> { "RelatedDocumentationList", ParentList },
    "Tools"            -> {
        "WolframLanguageEvaluator",
        "DocumentationSearcher",
        "DocumentationLookup",
        "WolframAlpha",
        "WebFetcher",
        "FileReader",
        ParentList
    }
|>