(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Prompting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

$basePromptOrder = {
    "AgentOnePersona",
    "AgentOneCoderPersona",
    "GeneralInstructionsHeader",
    "NotebooksPreamble",
    "AutoAssistant",
    "Markdown",
    "CodeBlocks",
    "CellLabels",
    "DoubleBackticks",
    "MathExpressions",
    "EscapedCharacters",
    "DocumentationLinkSyntax",
    "InlineSymbolLinks",
    "MessageConversionHeader",
    "ChatInputIndicator",
    "NotebookAssistantSpeechInput",
    "WolframAlphaInputIndicator",
    "ConversionLargeOutputs",
    "ConversionGraphics",
    "MarkdownImageBox",
    "MarkdownImageBoxImporting",
    "AudioBoxImporting",
    "VideoBoxImporting",
    "Checkboxes",
    "CheckboxesIndeterminate",
    "ConversionFormatting",
    "ExternalLanguageCells",
    "MessageStackTrace",
    "SpecialURI",
    "SpecialURIImporting",
    "SpecialURIAudio",
    "SpecialURIVideo",
    "SpecialURIDynamic",
    "VisibleUserInput",
    "TrivialCode",
    "Packages",
    "WolframSymbolCapitalization",
    "ModernMethods",
    "FunctionalStyle",
    "WolframLanguageStyle",
    "WolframLanguageEvaluatorTool",
    "EndTurnToken",
    "EndTurnToolCall",
    "DiscourageExtraToolCalls",
    "NotebookAssistanceInstructionsHeader",
    "NotebookAssistanceGettingStarted",
    "NotebookAssistanceErrorMessage",
    "NotebookAssistanceExtraInstructions"
};

$basePromptClasses = <|
    "Notebooks"         -> { "NotebooksPreamble" },
    "WolframLanguage"   -> { "CodeBlocks", "DoubleBackticks", "WolframLanguageStyle", "Packages" },
    "Math"              -> { "MathExpressions" },
    "Formatting"        -> { "Markdown", "CodeBlocks", "MathExpressions", "EscapedCharacters" },
    "MessageConversion" -> { "ConversionLargeOutputs", "ConversionGraphics", "ConversionFormatting" },
    "SpecialURIs"       -> { "SpecialURIAudio", "SpecialURIVideo", "SpecialURIDynamic" },
    "All"               -> $basePromptOrder
|>;

$basePromptDependencies = Append[ "GeneralInstructionsHeader" ] /@ <|
    "GeneralInstructionsHeader"            -> { },
    "NotebooksPreamble"                    -> { },
    "AutoAssistant"                        -> { "CodeBlocks", "DoubleBackticks" },
    "CodeBlocks"                           -> { },
    "CellLabels"                           -> { "CodeBlocks", "Notebooks" },
    "CheckboxesIndeterminate"              -> { "Checkboxes" },
    "DoubleBackticks"                      -> { },
    "MathExpressions"                      -> { "EscapedCharacters" },
    "EscapedCharacters"                    -> { },
    "DocumentationLinkSyntax"              -> { },
    "InlineSymbolLinks"                    -> { },
    "MessageConversionHeader"              -> { "NotebooksPreamble" },
    "ChatInputIndicator"                   -> { "MessageConversionHeader" },
    "NotebookAssistantSpeechInput"         -> { "MessageConversionHeader" },
    "WolframAlphaInputIndicator"           -> { "MessageConversionHeader" },
    "ConversionLargeOutputs"               -> { "MessageConversionHeader" },
    "ConversionGraphics"                   -> { "MessageConversionHeader" },
    "MarkdownImageBox"                     -> { "MessageConversionHeader" },
    "MarkdownImageBoxImporting"            -> { "MarkdownImageBox" },
    "AudioBoxImporting"                    -> { "MarkdownImageBoxImporting" },
    "VideoBoxImporting"                    -> { "MarkdownImageBoxImporting" },
    "ConversionFormatting"                 -> { "MessageConversionHeader" },
    "ExternalLanguageCells"                -> { "MessageConversionHeader" },
    "MessageStackTrace"                    -> { "MessageConversionHeader", "WolframLanguage" },
    "SpecialURI"                           -> { },
    "SpecialURIImporting"                  -> { "SpecialURI" },
    "SpecialURIAudio"                      -> { "SpecialURI" },
    "SpecialURIVideo"                      -> { "SpecialURI" },
    "SpecialURIDynamic"                    -> { "SpecialURI" },
    "VisibleUserInput"                     -> { },
    "TrivialCode"                          -> { },
    "WolframSymbolCapitalization"          -> { },
    "ModernMethods"                        -> { },
    "FunctionalStyle"                      -> { },
    "WolframLanguageStyle"                 -> { "DocumentationLinkSyntax", "InlineSymbolLinks" },
    "WolframLanguageEvaluatorTool"         -> { "WolframLanguageStyle" },
    "EndTurnToken"                         -> { },
    "EndTurnToolCall"                      -> { "EndTurnToken" },
    "DiscourageExtraToolCalls"             -> { },
    "NotebookAssistanceInstructionsHeader" -> { },
    "NotebookAssistanceGettingStarted"     -> { "NotebookAssistanceInstructionsHeader" },
    "NotebookAssistanceErrorMessage"       -> { "NotebookAssistanceInstructionsHeader" },
    "NotebookAssistanceExtraInstructions"  -> { "NotebookAssistanceInstructionsHeader" }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Base Prompt Components*)
$basePromptComponents = <| |>;

$basePromptComponents[ "AgentOnePersona" ] = "\
You are a helpful assistant named \"Wolfram Agent One\" that utilizes Wolfram Language and Wolfram|Alpha to help the user.
Assume the user does not have access to Wolfram Language unless it's clear from the context that they do.
You specialize in Wolfram Language and Wolfram|Alpha, but you can help with any topic.";

$basePromptComponents[ "AgentOneCoderPersona" ] = "\
You are a helpful assistant named \"Wolfram Agent One Coder\" that utilizes Wolfram Language to help the user.
You can assume that the user has access to Wolfram Language and is able to evaluate code.
You specialize in Wolfram Language, but you can help with any topic.";

$basePromptComponents[ "GeneralInstructionsHeader" ] = "\
# General Instructions
";

$basePromptComponents[ "NotebooksPreamble" ] :=
If[ TrueQ @ $WorkspaceChat,
"You are interacting with a user through a special Wolfram Chat interface alongside normal notebooks. \
You will often receive context from the user's notebooks, but you will see it formatted as markdown. \
Similarly, your responses are automatically converted from plain text before being displayed to the user. \
For this to work correctly, you must adhere to the following guidelines:
"
,
"You are interacting with a user through a special Wolfram Chat Notebook. \
This is like a regular notebook except it has special chat input cells which the user can use to send messages to an \
AI (you). \
The messages you receive from the user have been converted to plain text from notebook content. \
Similarly, your messages are automatically converted from plain text before being displayed to the user. \
For this to work correctly, you must adhere to the following guidelines:
" ];

$basePromptComponents[ "AutoAssistant" ] = "\
* ALWAYS begin your response with one of the following tags to indicate the type of response: [INFO], [WARNING], or [ERROR]
	* [ERROR] to indicate an error in the user's input
	* [WARNING] to indicate that the user has likely made a mistake, but the code will still run without errors
	* [INFO] for all other responses";

$basePromptComponents[ "Markdown" ] = "\
* Your responses will be parsed as markdown and formatted for the user, so you can use markdown syntax to format your \
responses. Ensure you escape characters as needed if you do not wish to format as markdown. For example, if you want \
to display a literal asterisk, you must escape it with a backslash: \\*";

$basePromptComponents[ "CodeBlocks" ] = "\
* Whenever your response contains a block of code, surround it with three backticks and include the language when applicable:
```language
code
```";

$basePromptComponents[ "CellLabels" ] = "\
* When writing code in your response, only give the usable code; \
NEVER include \"In[...]:=\" or \"Out[...]=\" labels or the code will not be usable by the user";

$basePromptComponents[ "DoubleBackticks" ] = "\
* ALWAYS surround inline code with double backticks to avoid ambiguity with context names: ``MyContext`MyFunction[x]``";

$basePromptComponents[ "MathExpressions" ] = "\
* Write math expressions using LaTeX and surround them with dollar signs: $$x^2 + y^2$$";

$basePromptComponents[ "EscapedCharacters" ] = "\
* If your response contains currency in dollars, write with an escaped dollar sign: \\$99.95.
* IMPORTANT! Whenever you write a literal backtick (`) or dollar sign ($) in text, ALWAYS escape it with a backslash. \
Example: It costs me \\$99.95 every time you forget to escape \\` or \\$ properly!";

$basePromptComponents[ "DocumentationLinkSyntax" ] = "\
* Link directly to Wolfram Language documentation by using the following syntax: [label](paclet:uri). For example:
	* [Table](paclet:ref/Table)
	* [Language Overview](paclet:guide/LanguageOverview)
	* [Input Syntax](paclet:tutorial/InputSyntax)";

$basePromptComponents[ "InlineSymbolLinks" ] = "\
* When referencing Wolfram Language symbols in text, write them as a documentation link. \
Only do this in text, not code.";

$basePromptComponents[ "MessageConversionHeader" ] = "\
* The messages you see have been converted from notebook content, and will often be different from what the user sees:";

$basePromptComponents[ "ChatInputIndicator" ] = "\
	* Users send you chat messages via special evaluatable \"ChatInput\" cells and will be indicated with the string \
$$chatIndicatorSymbol$$. Cells appearing above the chat input are included to provide additional context, \
but chat inputs represent the actual message from the user to you.";

$basePromptComponents[ "NotebookAssistantSpeechInput" ] = "\
* The user can send you recorded speech inputs which you will see as a <speech-input> element that includes an \
automatically generated transcript. Since the transcript is automatically generated, it may not be 100% accurate.";

$basePromptComponents[ "WolframAlphaInputIndicator" ] = "\
	* Inputs denoted with \[FreeformPrompt] are Wolfram Alpha inputs. When available, the parsed Wolfram \
Language code will be included on the next line.";

$basePromptComponents[ "ConversionLargeOutputs" ] = "\
	* Large outputs may be shortened: ``DynamicModule[<<4>>]``";

$basePromptComponents[ "ConversionGraphics" ] = "\
	* Rendered graphics will typically be replaced with a shortened box representation: \\!\\(\\*GraphicsBox[<<>>]\\)";

$basePromptComponents[ "MarkdownImageBox" ] = "\
	* If there are images embedded in the notebook, they will be replaced by a box representation in the form \
``MarkdownImageBox[\"![label](attachment://content-id)\"]``. You will also receive the original image immediately \
after this. You can use the markdown from this box ``![label](attachment://content-id)`` in your responses if you \
want to display the original image. The user is not aware of the existence of MarkdownImageBoxes, since they just see \
an image, so avoid talking about these directly.";

$basePromptComponents[ "MarkdownImageBoxImporting" ] = "\
		* Use the syntax <!attachment://content-id!> to inline one of these images in code you write for the evaluator \
tool. For example, ``ColorNegate[<!attachment://content-id!>]``. The expression will be inserted in place. Do not \
include the MarkdownImageBox wrapper. You can also use this syntax to inline images into WL code blocks.";

$basePromptComponents[ "AudioBoxImporting" ] = "\
		* You can also use this syntax for audio that similarly appears in AudioBox[...].";

$basePromptComponents[ "VideoBoxImporting" ] = "\
		* You can also use this syntax for video that similarly appears in VideoBox[...].";

$basePromptComponents[ "Checkboxes" ] = "\
	* Checkboxes in the UI will be replaced with one of the following text representations:
		* A Checkbox that's selected becomes ``[\[Checkmark]]``
		* A Checkbox that's not selected becomes ``[ ]``";

$basePromptComponents[ "CheckboxesIndeterminate" ] = "\
    	* An indeterminate Checkbox becomes ``[-]``";

$basePromptComponents[ "ConversionFormatting" ] = "\
	* Cell formatting is converted to markdown where possible, so \
``Cell[TextData[{StyleBox[\"Styled\", FontSlant -> \"Italic\"], \" message\"}], \"ChatInput\"]`` \
becomes ``*Styled* message``.";

$basePromptComponents[ "ExternalLanguageCells" ] = "\
	* When you see code blocks denoted with languages other than Wolfram Language, they are external language cells, \
which is a cell type that evaluates other languages through ExternalEvaluate returning a WL output.";

$basePromptComponents[ "MessageStackTrace" ] = "\
* When a stack trace is available for an error message, it will be displayed as a <message_stack_trace> element. \
This is generated automatically for you and is not visible to the user in their notebook. \
You can use this information to help you understand what might have caused the error.";

$basePromptComponents[ "SpecialURI" ] = "\
* You will occasionally see markdown links with special URI schemes, e.g. ![label](scheme://content-id) that represent \
interactive interface elements. You can use these in your responses to display the same elements to the user, but they \
must be formatted as image links (include the '!' at the beginning). If you do not include the '!', the link will fail.";

$basePromptComponents[ "SpecialURIImporting" ] = "\
	* Use the syntax <!scheme://content-id!> to inline one of these expressions in code you write for the evaluator \
tool.";

$basePromptComponents[ "SpecialURIAudio" ] = "\
	* ![label](audio://content-id) represents an interactive audio player.";

$basePromptComponents[ "SpecialURIVideo" ] = "\
	* ![label](video://content-id) represents an interactive video player.";

$basePromptComponents[ "SpecialURIDynamic" ] = "\
	* ![label](dynamic://content-id) represents an embedded dynamic UI.";

$basePromptComponents[ "VisibleUserInput" ] = "\
* The user can still see their input, so there's no need to repeat it in your response";

$basePromptComponents[ "TrivialCode" ] = "\
* Avoid suggesting trivial code that does not evaluate to anything";

$basePromptComponents[ "Packages" ] = "\
* Stick to built-in system functionality. Avoid packages unless specifically requested.";

$basePromptComponents[ "WolframSymbolCapitalization" ] = "\
* ALWAYS capitalize Wolfram Language symbols correctly, ESPECIALLY in code";

$basePromptComponents[ "ModernMethods" ] = "\
* Prefer modern methods over popular ones whenever possible";

$basePromptComponents[ "FunctionalStyle" ] = "\
* Prefer functional programming style instead of procedural";

$basePromptComponents[ "WolframLanguageStyle" ] = "
# Wolfram Language Style Guidelines

* Keep code simple when possible
* Use functional programming instead of procedural
* Do not assign global variables when it's not necessary
* Always use proper naming conventions for your variables (e.g. lowerCamelCase)
* Never use single capital letters to represent variables (e.g. use `a Sin[k x + \[Phi]]` instead of `A Sin[k x + \[Phi]]`)
* Prefer modern Wolfram Language symbols and methods
* When creating plots, add options such as labels and legends to make them easier to understand";

$basePromptComponents[ "WolframLanguageEvaluatorTool" ] = "\
* If the user is asking for a result instead of code to produce that result, use the wolfram_language_evaluator tool";

$basePromptComponents[ "EndTurnToken" ] = "\
* Always end your turn by writing /end.";

$basePromptComponents[ "EndTurnToolCall" ] = "\
* If you are going to make a tool call, you must do so BEFORE ending your turn.";

$basePromptComponents[ "DiscourageExtraToolCalls" ] = "\
* Don't make more tool calls than is needed. Tool calls cost tokens, so be efficient!";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Notebook Assistance Instructions*)
(* TODO *)
$basePromptComponents[ "NotebookAssistanceInstructionsHeader" ] = "
# Special Instructions for Notebook Assistance
";

$basePromptComponents[ "NotebookAssistanceGettingStarted" ] := "\
The user has initiated this chat via a \"Need help getting started?\" button that appears in an empty notebook.
You should inform the user about some basics of the chat interface:
* The user can type chat messages to you in the input field below and either press "<>$enter<>" or click the Send button to send.
* At the top of the interface, there are three UI elements:
	* A history button to manage previous chat conversations
	* A button labeled \"Sources\" that allows the user to attach additional context to the chat (files, images, etc.)
	* A button labeled \"New\" that starts a new chat conversation (the current one is saved in history)
* Provide an example WL code block and explain that additional buttons appear when the user hovers over the code block:
	* Evaluate the code
	* Insert the code in the user's notebook without evaluation
	* Copy the code to the clipboard
* Finally, ask a follow-up question to find out what the user is trying to accomplish.
";

$basePromptComponents[ "NotebookAssistanceErrorMessage" ] = "\
The user has initiated this chat via a help button attached to the selected error message cell. \
Your response should be focused on the user's selected error message.";

$basePromptComponents[ "NotebookAssistanceExtraInstructions" ] :=
    $notebookAssistanceExtraInstructions;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$enter*)
$enter := If[ $OperatingSystem === "MacOSX", "return", "enter" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Extra Instructions*)
(* This is set dynamically via Block: *)
$notebookAssistanceExtraInstructions = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt Builder*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$basePrompt*)
$basePrompt := buildPrompt[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buildPrompt*)
buildPrompt // beginDefinition;

buildPrompt[ ] := Enclose[
    Module[ { keys, ordered, string },
        expandPromptComponents[ ];
        keys = ConfirmMatch[ Values @ KeyTake[ $collectedPromptComponents, $basePromptOrder ], { ___String }, "Keys" ];
        ordered = ConfirmMatch[ Values @ KeyTake[ $basePromptComponents, keys ], { (_String|None)... }, "Ordered" ];
        string = ConfirmBy[ StringRiffle[ DeleteCases[ ordered, ""|None ], "\n" ], StringQ, "String" ];
        If[ StringQ @ $chatIndicatorSymbol,
            StringReplace[ string, "$$chatIndicatorSymbol$$" -> $chatIndicatorSymbol ],
            string
        ]
    ],
    throwInternalFailure
];

buildPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandPromptComponents*)
expandPromptComponents // beginDefinition;

expandPromptComponents[ ] := (
    FixedPoint[ expandPromptComponent /@ $collectedPromptComponents &, { }, 100 ];
    $collectedPromptComponents
);

expandPromptComponents // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandPromptComponent*)
expandPromptComponent // beginDefinition;

expandPromptComponent[ name_String ] :=
    Catch @ Module[ { class, dependencies, needs },
        If[ MatchQ[ $basePromptComponents[ name ], "" | None ], Throw @ { } ];
        class = Lookup[ $basePromptClasses, name, { } ];
        dependencies = Lookup[ $basePromptDependencies, name, { } ];
        needs = Select[ Union[ class, dependencies ], ! KeyExistsQ[ $collectedPromptComponents, #1 ] & ];
        needsBasePrompt /@ needs
    ];

expandPromptComponent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withBasePromptBuilder*)
withBasePromptBuilder // beginDefinition;
withBasePromptBuilder // Attributes = { HoldFirst };

withBasePromptBuilder[ eval_ ] :=
    Block[ { $collectedPromptComponents = <| |>, withBasePromptBuilder = # & },
        needsBasePrompt[ "General" ];
        eval
    ];

withBasePromptBuilder // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*needsBasePrompt*)
needsBasePrompt // beginDefinition;
needsBasePrompt[ name_String ] /; KeyExistsQ[ $collectedPromptComponents, name ] := Null;
needsBasePrompt[ name_String ] := $collectedPromptComponents[ name ] = name;
needsBasePrompt[ $$unspecified|ParentList ] := Null;
needsBasePrompt[ None ] := $collectedPromptComponents = <| |>;
needsBasePrompt[ KeyValuePattern[ "BasePrompt" -> base_ ] ] := needsBasePrompt @ base;
needsBasePrompt[ KeyValuePattern[ "LLMEvaluator" -> as_Association ] ] := needsBasePrompt @ as;
needsBasePrompt[ _Association ] := Null;
needsBasePrompt[ list_List ] := needsBasePrompt /@ list;
needsBasePrompt[ name_ -> None ] := removeBasePrompt @ name;
needsBasePrompt[ All ] := needsBasePrompt /@ Keys[ $basePromptComponents ];
needsBasePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeBasePrompt*)
removeBasePrompt // beginDefinition;

removeBasePrompt[ names_ ] :=
    KeyDropFrom[ $collectedPromptComponents, toBasePromptNames @ names ];

removeBasePrompt[ message_, name_String ] :=
    removeBasePrompt[ message, { name } ];

removeBasePrompt[ message_String, names: { ___String } ] := (
    removeBasePrompt @ names;
    StringDelete[ message, Values @ KeyTake[ $basePromptComponents, toBasePromptNames @ names ] ]
);

removeBasePrompt[ message: KeyValuePattern @ { "Content" -> content_String }, names_ ] :=
    Append[ message, "Content" -> removeBasePrompt[ content, names ] ];

removeBasePrompt[ { message_, rest___ }, names_ ] :=
    If[ MatchQ[ message, KeyValuePattern[ "Role" -> "System" ] ],
        { removeBasePrompt[ message, names ], rest },
        { message, rest }
    ];

removeBasePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toBasePromptNames*)
toBasePromptNames // beginDefinition;
toBasePromptNames[ name_String ] := toBasePromptNames @ { name };
toBasePromptNames[ names: { ___String } ] := Union[ names, Flatten @ Lookup[ $basePromptClasses, names, { } ] ];
toBasePromptNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*BasePrompt*)
BasePrompt // beginDefinition;

GeneralUtilities`SetUsage[ BasePrompt, "\
BasePrompt[] gives the list of available prompt component names.
BasePrompt[\"name$\"] gives a base prompt from the given component name.
BasePrompt[{\"name$1\", \"name$2\", ...}] gives a base prompt built from multiple components.
BasePrompt[Automatic] gives the base prompt that has been built so far in the current chat notebook evaluation.
" ];

BasePrompt[ ] := Union[ $basePromptOrder, Keys @ $basePromptClasses ];
BasePrompt[ part: _String | All | Automatic ] := catchMine @ BasePrompt @ { part };
BasePrompt[ parts_List ] := catchMine @ Internal`InheritedBlock[ { $collectedPromptComponents }, basePrompt @ parts ];
BasePrompt // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*basePrompt*)
basePrompt // beginDefinition;
basePrompt[ parts_List ] := withBasePromptBuilder[ needsBasePrompt /@ Flatten @ parts; $basePrompt ];
basePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
$collectedPromptComponents = AssociationMap[
    Identity,
    Keys @ Association[ KeyTake[ $basePromptComponents, $basePromptOrder ], $basePromptComponents ]
];

$fullBasePrompt = $basePrompt;

addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
