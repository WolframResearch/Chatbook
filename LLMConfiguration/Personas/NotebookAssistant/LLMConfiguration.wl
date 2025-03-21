<|
    "BasePrompt"       -> { "Notebooks", "WolframLanguageStyle" },
    "Description"      -> "Help with writing and generating Wolfram Language code",
    "DisplayName"      -> Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", "PersonaNameNotebookAssistant" ],
    "Hidden"           -> True,
    "Icon"             -> RawBoxes @ TemplateBox[ { }, "ChatIconNotebookAssistant" ],
    "PromptGenerators" -> { "RelatedDocumentation", "RelatedWolframAlphaResults", "WebSearch" },
    "Tools"            -> { "WolframAlpha", "WolframLanguageEvaluator", ParentList }
|>