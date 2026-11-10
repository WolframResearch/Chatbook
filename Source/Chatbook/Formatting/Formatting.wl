(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"           ];
Needs[ "Wolfram`Chatbook`Common`"    ];
Needs[ "Wolfram`Chatbook`CodeCheck`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$customToolFormatter = None;
$dynamicImageScale   = 0.25;
$maxImageSize        = 800;
$maxDynamicImageSize = Ceiling[ $maxImageSize * $dynamicImageScale ];

$wlCodeString = Longest @ Alternatives[
    "Wolfram Language",
    "Wolfram_Language_Evaluator",
    "Wolfram_Language",
    "WolframLanguage",
    "Wolfram",
    "Mathematica",
    "WL"
];

$resultCellCache         = <| |>;
$staticCodeBlockCache    = <| |>;
$useStaticCodeBlockCache = False;

(* When True, \[FreeformPrompt] inputs are formatted without a Wolfram|Alpha call, as they are while streaming: *)
$useFastNLInputFormatting = False;

sectionStyle[ 1 ] := "Title";
sectionStyle[ 2 ] := "Section";
sectionStyle[ 3 ] := "Subsection";
sectionStyle[ 4 ] := "Subsubsection";
sectionStyle[ 5 ] := "Subsubsubsection";
sectionStyle[ _ ] := "Subsubsubsubsection";

$externalLanguages = {
    "Java",
    "Julia",
    "Jupyter",
    "NodeJS",
    "Octave",
    "Python",
    "R",
    "Ruby",
    "Shell",
    "SQL-JDBC",
    "SQL",
    "SQLite"
};

$$externalLanguage = Alternatives @@ $externalLanguages;

$externalLanguageRules = Replace[
    Flatten @ {
        "JS"         -> "NodeJS",
        "Javascript" -> "NodeJS",
        "NPM"        -> "NodeJS",
        "Node"       -> "NodeJS",
        "Bash"       -> "Shell",
        "SH"         -> "Shell",
        Cases[ $externalLanguages, lang_ :> (lang -> lang) ]
    },
    HoldPattern[ lhs_ -> rhs_ ] :> (StartOfString~~lhs~~EndOfString -> rhs),
    { 1 }
];

$chatGeneratedCellTag = "ChatGeneratedCell";

$simpleToolMethod := $ChatHandlerData[ "ChatNotebookSettings", "ToolMethod" ] === "Simple";

$autoOperatorRenderings = <|
    "|->" -> "\[Function]",
    "->"  -> "\[Rule]",
    ":>"  -> "\[RuleDelayed]",
    "<="  -> "\[LessEqual]",
    ">="  -> "\[GreaterEqual]",
    "!="  -> "\[NotEqual]",
    "=="  -> "\[Equal]",
    "<->" -> "\[TwoWayRule]",
    "[["  -> "\[LeftDoubleBracket]",
    "]]"  -> "\[RightDoubleBracket]",
    "<|"  -> "\[LeftAssociation]",
    "|>"  -> "\[RightAssociation]"
 |>;

 $expressionURIPlaceholder = "\[LeftSkeleton]\[Ellipsis]\[RightSkeleton]";
 $freeformPromptBox        = StyleBox[ "\[FreeformPrompt]", FontColor -> color @ "NA_ChatOutputFreeFormFont", FontSize -> 9 ];


 $delimiterCell = Cell[
    BoxData @ TagBox[
        GridBox[
            { { TemplateBox[ { 0 }, "Spacer1" ] }, { TemplateBox[ { 0 }, "Spacer1" ] } },
            AutoDelete      -> False,
            GridBoxDividers -> { "Columns" -> { False, { True }, False }, "Rows" -> { False, { True }, False } },
            GridBoxItemSize -> { "Columns" -> { { Fit } }, "Rows" -> { { Automatic } } },
            FrameStyle      -> Directive[ color @ "ChatDelimiterCellFrame", AbsoluteThickness[ 1 ] ]
        ],
        "Grid"
    ],
    "MarkdownDelimiter",
    Background           -> None,
    ShowStringCharacters -> False
];

(* ::**************************************************************************************************************:: *)
 (* ::Section::Closed:: *)
 (*StringToBoxes*)
StringToBoxes // beginDefinition;
StringToBoxes[ string_String? StringQ ] := catchAlways[ stringToBoxes @ string, StringToBoxes ];
StringToBoxes[ string_String? StringQ, "WL" ] := catchAlways[ wlStringToBoxes @ string, StringToBoxes ];
StringToBoxes // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CachedBoxes*)
CachedBoxes // beginDefinition;
CachedBoxes[ expr_ ] := catchMine @ cachedBoxes @ Unevaluated @ expr;
CachedBoxes // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DisplayBase64Boxes*)
DisplayBase64Boxes // beginDefinition;
DisplayBase64Boxes[ b64_String ] := catchMine @ displayBase64Boxes @ b64;
DisplayBase64Boxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Output Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FormatChatOutput*)
FormatChatOutput // beginDefinition;

FormatChatOutput[ output_ ] :=
    FormatChatOutput[ output, <| "Status" -> If[ TrueQ @ $dynamicText, "Streaming", "Finished" ] |> ];

FormatChatOutput[ output_, as_Association ] :=
    formatChatOutput[ output, Lookup[ as, "Status", "Finished" ] ];

FormatChatOutput // endDefinition;
(* TODO: actual error handling for invalid arguments *)

formatChatOutput // beginDefinition;

formatChatOutput[ output: $$progressIndicator, _ ] :=
    output;

formatChatOutput[ output_, "Waiting" ] :=
    ProgressIndicator[ Appearance -> "Percolate" ];

formatChatOutput[ output_String, "Streaming" ] :=
    Block[ { $dynamicText = True }, RawBoxes @ Cell @ TextData @ reformatTextData @ output ];

formatChatOutput[ output_String, "Finished" ] :=
    Block[ { $dynamicText = False }, RawBoxes @ Cell @ TextData @ reformatTextData @ output ];

formatChatOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FormatToolCall*)
FormatToolCall // beginDefinition;

FormatToolCall[ string_String, parsed_ ] :=
    FormatToolCall[ string, parsed, <| "Status" -> If[ TrueQ @ $dynamicText, "Streaming", "Finished" ] |> ];

FormatToolCall[ string_String, parsed_, info_Association ] :=
    formatToolCall[ string, parsed, Lookup[ info, "Status", "Finished" ] ];

FormatToolCall // endDefinition;


formatToolCall // beginDefinition;

formatToolCall[ string_String, parsed_, "Streaming" ] :=
    Block[ { $dynamicText = True }, formatToolCall0[ string, parsed ] ];

formatToolCall[ string_String, parsed_, "Finished" ] :=
    Block[ { $dynamicText = False }, formatToolCall0[ string, parsed ] ];

formatToolCall // endDefinition;


formatToolCall0 // beginDefinition;

formatToolCall0[ string_String, as_Association ] := makeToolCallBoxLabel @ as;

formatToolCall0[ string_String, failed_Failure ] := Framed[
    failed,
    Background   -> color @ "NA_ChatOutputToolCallFailureBackground",
    BaseStyle    -> "Output",
    FrameMargins -> 10,
    FrameStyle   -> color @ "NA_ChatOutputToolCallFailureFrame",
    ImageMargins -> { { 0, 0 }, { 10, 10 } }
];

formatToolCall0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session Caches*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addToCache*)
addToCache // beginDefinition;
addToCache // Attributes = { HoldFirst };

(* Stores value for key in the association held by cache and gives value. The formatter's caches live for the whole
   session, so when a cache has size entries, its oldest half is discarded first (as for $tokenCountCache in
   ChatMessages.wl). Callers look the key up first, as in Lookup[ cache, key, addToCache[ cache, size, key, value ] ],
   so that the value is only computed when it is missing: *)
addToCache[ cache_Symbol, size_Integer, key_, value_ ] := (
    If[ Length @ cache >= size, cache = Take[ cache, -Floor[ size / 2 ] ] ];
    cache[ key ] = value
);

addToCache // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Files*)
(* Rules.wl comes first, since Pipeline.wl and Tables.wl use its patterns while they load: *)
Get[ "Wolfram`Chatbook`Formatting`Rules`"            ];
Get[ "Wolfram`Chatbook`Formatting`Pipeline`"         ];
Get[ "Wolfram`Chatbook`Formatting`Blocks`"           ];
Get[ "Wolfram`Chatbook`Formatting`Tables`"           ];
Get[ "Wolfram`Chatbook`Formatting`Inline`"           ];
Get[ "Wolfram`Chatbook`Formatting`CodeBlocks`"       ];
Get[ "Wolfram`Chatbook`Formatting`CodeBlockButtons`" ];
Get[ "Wolfram`Chatbook`Formatting`ToolCalls`"        ];
Get[ "Wolfram`Chatbook`Formatting`WLBoxes`"          ];
Get[ "Wolfram`Chatbook`Formatting`Images`"           ];
Get[ "Wolfram`Chatbook`Formatting`MessageBoxes`"     ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $languageIcons;
];

End[ ];
EndPackage[ ];
