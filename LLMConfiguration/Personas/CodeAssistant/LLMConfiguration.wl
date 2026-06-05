<|
    "BasePrompt"       -> { ParentList, "Notebooks", "WolframLanguageStyle" },
    "Description"      -> "Help with writing and generating Wolfram Language code",
    "DisplayName"      -> Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", "PersonaNameCodeAssistant" ],
    "Hidden"           -> True,
    "Icon"             -> Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatOutputCellDingbat" ],
	"PromptGenerators" -> { "RelatedDocumentation", ParentList },
    "Tools"            -> {
        "WolframLanguageEvaluator",
        "DocumentationSearcher",
        "WolframAlpha",
        "WebFetcher",
        ParentList
    }
|>