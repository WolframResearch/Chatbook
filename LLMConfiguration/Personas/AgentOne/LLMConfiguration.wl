<|
    "BasePrompt"       -> { ParentList, "AgentOnePersona", "WolframLanguageStyle" },
    "Hidden"           -> True,
    "PromptGenerators" -> { "RelatedDocumentationList", "RelatedWolframAlphaResults" },
    "Tools"            -> {
        "WolframLanguageEvaluator",
        "DocumentationSearcher",
        "DocumentationLookup",
        "WolframAlpha",
        ParentList
    }
|>