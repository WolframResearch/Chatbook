(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Prompting`" ];

`$basePrompt;
`$basePromptComponents;
`$fullBasePrompt;
`needsBasePrompt;
`withBasePromptBuilder;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

$basePromptOrder = {
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
    "ConversionLargeOutputs",
    "ConversionGraphics",
    "MarkdownImageBox",
    "Checkboxes",
    "CheckboxesIndeterminate",
    "ConversionFormatting",
    "SpecialURI",
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
    "WolframLanguageEvaluatorTool"
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
    "GeneralInstructionsHeader"    -> { },
    "NotebooksPreamble"            -> { },
    "AutoAssistant"                -> { "CodeBlocks", "DoubleBackticks" },
    "CodeBlocks"                   -> { },
    "CellLabels"                   -> { "CodeBlocks", "Notebooks" },
    "CheckboxesIndeterminate"      -> { "Checkboxes" },
    "DoubleBackticks"              -> { },
    "MathExpressions"              -> { "EscapedCharacters" },
    "EscapedCharacters"            -> { },
    "DocumentationLinkSyntax"      -> { },
    "InlineSymbolLinks"            -> { },
    "MessageConversionHeader"      -> { "NotebooksPreamble" },
    "ChatInputIndicator"           -> { "MessageConversionHeader" },
    "ConversionLargeOutputs"       -> { "MessageConversionHeader" },
    "ConversionGraphics"           -> { "MessageConversionHeader" },
    "MarkdownImageBox"             -> { "MessageConversionHeader" },
    "ConversionFormatting"         -> { "MessageConversionHeader" },
    "SpecialURI"                   -> { },
    "SpecialURIAudio"              -> { "SpecialURI" },
    "SpecialURIVideo"              -> { "SpecialURI" },
    "SpecialURIDynamic"            -> { "SpecialURI" },
    "VisibleUserInput"             -> { },
    "TrivialCode"                  -> { },
    "WolframSymbolCapitalization"  -> { },
    "ModernMethods"                -> { },
    "FunctionalStyle"              -> { },
    "WolframLanguageStyle"         -> { "DocumentationLinkSyntax", "InlineSymbolLinks" },
    "WolframLanguageEvaluatorTool" -> { "WolframLanguageStyle" }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Base Prompt Components*)
$basePromptComponents = <| |>;

$basePromptComponents[ "GeneralInstructionsHeader" ] = "\
# General Instructions
";

$basePromptComponents[ "NotebooksPreamble" ] = "\
You are interacting with a user through a Wolfram Notebook interface. \
The messages you receive from the user have been converted to plain text from notebook content. \
Similarly, your messages are automatically converted from plain text before being displayed to the user. \
For this to work correctly, you must adhere to the following guidelines:
";

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

$basePromptComponents[ "ConversionLargeOutputs" ] = "\
	* Large outputs may be shortened: ``DynamicModule[<<4>>]``";

$basePromptComponents[ "ConversionGraphics" ] = "\
	* Rendered graphics will typically be replaced with a shortened box representation: \\!\\(\\*GraphicsBox[<<>>]\\)";

$basePromptComponents[ "MarkdownImageBox" ] = "\
	* If there are images embedded in the notebook, they will be replaced by a box representation in the \
form ``MarkdownImageBox[\"![label](uri)\"]``. You will also receive the original image immediately after this. \
You can use the markdown from this box ``![label](uri)`` in your responses if you want to display the original image.";

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

$basePromptComponents[ "SpecialURI" ] = "\
* You will occasionally see markdown links with special URI schemes, e.g. ![label](scheme://content-id) that represent \
interactive interface elements. You can use these in your responses to display the same elements to the user, but they \
must be formatted as image links (include the '!' at the beginning). If you do not include the '!', the link will fail.";

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
* Prefer modern Wolfram Language symbols and methods
* Many new symbols have been added to WL since your knowledge cutoff date, so check documentation as needed
* When creating plots, add options such as labels and legends to make them easier to understand";

$basePromptComponents[ "WolframLanguageEvaluatorTool" ] = "\
* If the user is asking for a result instead of code to produce that result, use the wolfram_language_evaluator tool";

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
        ordered = ConfirmMatch[ Values @ KeyTake[ $basePromptComponents, keys ], { ___String }, "Ordered" ];
        string = ConfirmBy[ StringRiffle[ ordered, "\n" ], StringQ, "String" ];
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
    Module[ { class, dependencies, needs },
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
needsBasePrompt[ Automatic|Inherited|_Missing ] := Null;
needsBasePrompt[ None ] := $collectedPromptComponents = <| |>;
needsBasePrompt[ KeyValuePattern[ "BasePrompt" -> base_ ] ] := needsBasePrompt @ base;
needsBasePrompt[ KeyValuePattern[ "LLMEvaluator" -> as_Association ] ] := needsBasePrompt @ as;
needsBasePrompt[ _Association ] := Null;
needsBasePrompt[ list_List ] := needsBasePrompt /@ list;
needsBasePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
$collectedPromptComponents = AssociationMap[
    Identity,
    Keys @ Association[ KeyTake[ $basePromptComponents, $basePromptOrder ], $basePromptComponents ]
];

$fullBasePrompt = $basePrompt;

If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
