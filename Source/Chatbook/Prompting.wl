(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Prompting`" ];

(* TODO: select portions of base prompt during serialization as needed *)
`$basePrompt;
`$basePromptComponents;
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
    "CodeBlocks",
    "DoubleBackticks",
    "MathExpressions",
    "EscapedCharacters",
    "DocumentationLinkSyntax",
    "InlineSymbolLinks",
    "MessageConversionHeader",
    "ConversionLargeOutputs",
    "ConversionGraphics",
    "ConversionFormatting",
    "VisibleUserInput",
    "TrivialCode",
    "WolframSymbolCapitalization",
    "ModernMethods",
    "FunctionalStyle",
    "WolframLanguageStyle"
};

$basePromptClasses = <|
    "Notebooks"         -> { "NotebooksPreamble" },
    "WolframLanguage"   -> { "CodeBlocks", "DoubleBackticks", "WolframLanguageStyle" },
    "Math"              -> { "MathExpressions" },
    "Formatting"        -> { "CodeBlocks", "MathExpressions", "EscapedCharacters" },
    "MessageConversion" -> { "ConversionLargeOutputs", "ConversionGraphics", "ConversionFormatting" },
    "All"               -> $basePromptOrder
|>;

$basePromptDependencies = Append[ "GeneralInstructionsHeader" ] /@ <|
    "GeneralInstructionsHeader"   -> { },
    "NotebooksPreamble"           -> { },
    "AutoAssistant"               -> { "CodeBlocks", "DoubleBackticks" },
    "CodeBlocks"                  -> { },
    "DoubleBackticks"             -> { },
    "MathExpressions"             -> { "EscapedCharacters" },
    "EscapedCharacters"           -> { },
    "DocumentationLinkSyntax"     -> { },
    "InlineSymbolLinks"           -> { },
    "MessageConversionHeader"     -> { "NotebooksPreamble" },
    "ConversionLargeOutputs"      -> { "MessageConversionHeader" },
    "ConversionGraphics"          -> { "MessageConversionHeader" },
    "ConversionFormatting"        -> { "MessageConversionHeader" },
    "VisibleUserInput"            -> { },
    "TrivialCode"                 -> { },
    "WolframSymbolCapitalization" -> { },
    "ModernMethods"               -> { },
    "FunctionalStyle"             -> { },
    "WolframLanguageStyle"        -> { "DocumentationLinkSyntax", "InlineSymbolLinks" }
|>;

$collectedPromptComponents = AssociationMap[ Identity, $basePromptOrder ];

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

$basePromptComponents[ "CodeBlocks" ] = "\
* Whenever your response contains a block of code, surround it with three backticks and include the language when applicable:
```language
code
```";

$basePromptComponents[ "DoubleBackticks" ] = "\
* ALWAYS surround inline code with double backticks to avoid ambiguity with context names: ``MyContext`MyFunction[x]``";

$basePromptComponents[ "MathExpressions" ] = "\
* Write math expressions using LaTeX and surround them with dollar signs: $x^2 + y^2$";

$basePromptComponents[ "EscapedCharacters" ] = "\
* IMPORTANT! Whenever you write a literal backtick or dollar sign in text, ALWAYS escape it with a backslash. \
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

$basePromptComponents[ "ConversionLargeOutputs" ] = "\
	* Large outputs may be shortened: ``DynamicModule[<<4>>]``";

$basePromptComponents[ "ConversionGraphics" ] = "\
	* Rendered graphics will typically be replaced with the placeholder ``-Graphics-``";

$basePromptComponents[ "ConversionFormatting" ] = "\
	* Cell formatting is removed when converting to text, so \
``Cell[TextData[{StyleBox[\"Styled\", FontSlant -> \"Italic\"], \" message\"}], \"ChatInput\"]`` \
becomes \
``Styled message``.";

$basePromptComponents[ "VisibleUserInput" ] = "\
* The user can still see their input, so there's no need to repeat it in your response";

$basePromptComponents[ "TrivialCode" ] = "\
* Avoid suggesting trivial code that does not evaluate to anything";

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

buildPrompt[ ] := (
    expandPromptComponents[ ];
    StringRiffle[
        Values @ KeyTake[ $basePromptComponents, Values @ KeyTake[ $collectedPromptComponents, $basePromptOrder ] ],
        "\n"
    ]
);

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
needsBasePrompt[ list_List ] := needsBasePrompt /@ list;
needsBasePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    Null
];

End[ ];
EndPackage[ ];
