<|
    "BasePrompt"       -> { ParentList, "Notebooks", "WolframLanguageStyle" },
    "Description"      -> "Help with writing and generating Wolfram Language code",
    "DisplayName"      -> Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", "PersonaNameCodeAssistant" ],
    "Icon"             -> RawBoxes @ TemplateBox[ { }, "ChatIconCodeAssistant" ],
	"PromptGenerators" -> { "RelatedDocumentation", ParentList },
    "Tools"            -> { "WolframLanguageEvaluator", "DocumentationSearcher", "WolframAlpha", ParentList }
|>