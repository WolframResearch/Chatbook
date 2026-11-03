(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"           ];
Needs[ "Wolfram`Chatbook`Common`"    ];
Needs[ "Wolfram`Chatbook`CodeCheck`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineToolCall*)
inlineToolCall // beginDefinition;

inlineToolCall[ string_String ] :=
    inlineToolCall[ string, parseToolCallString @ string ];

inlineToolCall[ string_String, as_ ] :=
    With[ { formatter = $ChatHandlerData[ "ChatNotebookSettings", "ProcessingFunctions", "FormatToolCall" ] },
        makeInlineToolCallCell[
            formatter[ string, as ],
            string,
            as
        ] /; MatchQ[ formatter, Except[ None | _Missing ] ]
    ];

inlineToolCall[ string_String, as_ ] :=
    makeInlineToolCallCell[
        FormatToolCall[ string, as, <| "Status" -> If[ TrueQ @ $dynamicText, "Streaming", "Finished" ] |> ],
        string,
        as
    ];

inlineToolCall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInlineToolCallCell*)
makeInlineToolCallCell // beginDefinition;

makeInlineToolCallCell[ expr_, string_, as_Association ] := Cell[
    BoxData @ inlineChatbookExpressions @ ToBoxes @ expr,
    "InlineToolCall",
    Background   -> None,
    TaggingRules -> KeyDrop[ as, { "Icon", "CallIcon", "Result" } ]
];

makeInlineToolCallCell[ expr_, string_String, failed_Failure ] := Cell[
    BoxData @ inlineChatbookExpressions @ ToBoxes @ expr,
    "FailedToolCall",
    Background   -> None,
    TaggingRules -> <| "ToolCall" -> string |>
];

makeInlineToolCallCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseToolCallString*)
parseToolCallString // beginDefinition;
parseToolCallString[ string_String ] := parseToolCallString[ parseToolCallID @ string, string ];
parseToolCallString[ id_String, string_String ] := parseFullToolCallString[ id, string ];
parseToolCallString[ _Missing, string_String ] := parsePartialToolCallString @ string;
parseToolCallString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parsePartialToolCallString*)
parsePartialToolCallString // beginDefinition;

(* TODO: define a `parsePartialSimpleToolCallString` that can also be used in `simpleToolRequestParser` *)

parsePartialToolCallString[ string_String ] /; $simpleToolMethod := Enclose[
    Catch @ Module[ { command, argString, tool, name, paramNames, params, result },
        command = First @ ConfirmMatch[
            StringCases[
                string,
                StartOfString ~~ $$ws ~~ ("/" ~~ cmd: $$cmd) ~~ $$eol ~~ ___ :> cmd,
                1
            ],
            { _String },
            "Command"
        ];

        If[ ! toolShortNameQ @ command,
            Throw @ Failure[
                "InvalidToolCall",
                <|
                    "MessageTemplate"   -> "No tool found that uses the command \"`1`\".",
                    "MessageParameters" -> { command }
                |>
            ]
        ];

        argString = First[
            StringCases[
                string,
                Shortest @ StringExpression[
                    StartOfString,
                    $$ws,
                    "/",
                    command,
                    WhitespaceCharacter...,
                    "\n",
                    a___,
                    "/exec"|EndOfString
                ] :> a,
                1
            ],
            Missing[ ]
        ];

        tool = ConfirmMatch[ $ChatHandlerData[ "ToolShortNames" ][ command ], _LLMTool, "Tool" ];
        name = ConfirmBy[ toolName @ tool, StringQ, "ToolName" ];

        If[ StringQ @ argString,
            paramNames = Keys @ ConfirmMatch[ tool[ "Parameters" ], KeyValuePattern @ { }, "ParameterNames" ];
            params = ConfirmBy[
                parseSimpleToolCallParameterStrings[ paramNames, argString ],
                AssociationQ,
                "Parameters"
            ]
            ,
            params = <| |>
        ];

        result = First[ StringCases[ string, "RESULT\n" ~~ r___ ~~ "\nENDRESULT" :> r ], "" ];

        DeleteMissing @ <|
            "Name"        -> name,
            "DisplayName" -> getToolDisplayName @ tool,
            "Icon"        -> getToolIcon @ tool,
            "CallIcon"    -> getToolCallIcon @ tool,
            "ToolCall"    -> StringTrim @ string,
            "Parameters"  -> params,
            "Result"      -> result
        |>
    ],
    throwInternalFailure
];

parsePartialToolCallString[ string_String ] /; StringMatchQ[ string, "TOOLCALL:"~~__~~"{"~~___ ] :=
    Module[ { noPrefix, noSuffix, name, tool, displayName, icon, callIcon, query, result },

        noPrefix    = StringDelete[ string, StartOfString~~"TOOLCALL:" ];
        noSuffix    = StringTrim @ StringDelete[ noPrefix, "ENDRESULT"~~___~~EndOfString ];
        name        = StringTrim @ StringDelete[ noSuffix, ("\n"|"{")~~___~~EndOfString ];
        tool        = getToolByName @ name;
        displayName = getToolDisplayName[ tool, name ];
        icon        = getToolIcon @ tool;
        callIcon    = getToolCallIcon @ tool;
        query       = First[ StringCases[ string, "TOOLCALL:" ~~ q___ ~~ "\nRESULT" :> q ], "" ];
        result      = First[ StringCases[ string, "RESULT\n" ~~ r___ ~~ "\nENDRESULT" :> r ], "" ];

        <|
            "Name"        -> name,
            "DisplayName" -> displayName,
            "Icon"        -> icon,
            "CallIcon"    -> callIcon,
            "ToolCall"    -> StringTrim @ string,
            "Parameters"  -> StringTrim @ query,
            "Result"      -> StringTrim @ result
        |>
    ];

parsePartialToolCallString[ string_String ] := <| "ToolCall" -> StringTrim @ string |>;

parsePartialToolCallString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseFullToolCallString*)
parseFullToolCallString // beginDefinition;

parseFullToolCallString[ id_String, string_String ] :=
    parseFullToolCallString[ id, $toolEvaluationResults[ id ], string ];

parseFullToolCallString[ id_, _Missing, string_String ] :=
    parsePartialToolCallString @ string;

parseFullToolCallString[ id_, failed_Failure, string_String ] :=
    failed;

parseFullToolCallString[ id_String, resp: HoldPattern[ _LLMToolResponse ], string_String ] :=
    parseFullToolCallString[
        id,
        resp[ "Tool" ],
        resp[ "InterpretedParameterValues" ],
        resp[ "Output" ],
        string
    ];

parseFullToolCallString[ id_String, tool: HoldPattern[ _LLMTool ], parameters_Association, output_, string_ ] :=
    $lastFullParsed = <|
        "ID"                 -> id,
        "Name"               -> toolName @ tool,
        "DisplayName"        -> getToolDisplayName @ tool,
        "Icon"               -> getToolIcon @ tool,
        "CallIcon"           -> getToolCallIcon @ tool,
        "FormattingFunction" -> getToolFormattingFunction @ tool,
        "ToolCall"           -> StringTrim @ string,
        "Parameters"         -> parameters,
        "Result"             -> output,
        "Open"               -> TrueQ @ $openToolCallBoxes
    |>;

parseFullToolCallString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*parseToolCallID*)
parseToolCallID // beginDefinition;

parseToolCallID[ string_String? StringQ ] :=
    Replace[
        StringReplace[
            string,
            {
                StringExpression[
                    StartOfString,
                    WhitespaceCharacter...,
                    Alternatives[
                        "TOOLCALL:",
                        StartOfLine ~~ "/" ~~ cmd: Except[ WhitespaceCharacter ].. ~~ WhitespaceCharacter... ~~ "\n"
                    ],
                    ___,
                    "ENDRESULT(",
                    hex: (LetterCharacter|DigitCharacter)..,
                    ")",
                    WhitespaceCharacter...,
                    EndOfString
                ] :> hex,
                StartOfString ~~ ___ ~~ EndOfString :> ""
            }
        ],
        "" -> Missing[ "NotAvailable" ]
    ];

parseToolCallID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*fullToolCallStringQ*)
fullToolCallStringQ // beginDefinition;
fullToolCallStringQ[ string_String? StringQ ] := StringQ @ parseToolCallID @ string;
fullToolCallStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallBoxLabel*)
makeToolCallBoxLabel // beginDefinition;

makeToolCallBoxLabel[ as: KeyValuePattern[ "DisplayName" -> name_String ] ] :=
    makeToolCallBoxLabel[ as, name ];

makeToolCallBoxLabel[ as: KeyValuePattern[ "Name" -> name_String ] ] :=
    makeToolCallBoxLabel[
        as,
        StringRiffle @ Capitalize @ StringSplit[
            StringDelete[ StringTrim @ name, (Whitespace|"{") ~~ ___ ~~ EndOfString ],
            "_"
        ]
    ];

makeToolCallBoxLabel[ as_Association ] := tr[ "FormattingToolUsingLoading" ];

makeToolCallBoxLabel[ as_Association, name_String ] /; $dynamicText :=
    fakeOpenerView @ makeToolCallBoxLabel0[ as, name, toolCallIcon[ as, $fakeOpenerColor ] ];

makeToolCallBoxLabel[ as0_Association, name_String ] :=
    With[ { as = resolveToolFormatter @ as0 },
        openerView[
            {
                Function[ col, makeToolCallBoxLabel0[ as, name, toolCallIcon[ as, col ] ] ],
                (*TODO: custom interface LLM 667 *)
                TabView[
                    {
                        "Raw"         -> makeToolCallRawView @ as,
                        "Interpreted" -> makeToolCallInterpretedView @ as
                    },
                    2,
                    ImageSize  -> Automatic,
                    LabelStyle -> { FontSize -> 12 }
                ],
                "Tool"
            },
            TrueQ @ as0[ "Open" ]
        ]
    ];

makeToolCallBoxLabel // endDefinition;


makeToolCallBoxLabel0 // beginDefinition;

makeToolCallBoxLabel0[ KeyValuePattern[ "Result" -> "" ], string_String, icon_ ] :=
With[ { col = $fakeOpenerColor },
    Flatten @ {
        toolCallIconPane @ icon,
        Style[ tr[ "FormattingToolUsing" ], FontColor -> col ],
        Style[ string, FontWeight -> "Plain", FontColor -> col ],
        activeToolProgressIndicator[ ]
    }
];

makeToolCallBoxLabel0[ as_, string_String, icon_ ] := Flatten @ {
    toolCallIconPane @ icon,
    tr[ "FormattingToolUsed" ],
    Style[ string, FontWeight -> "Plain" ]
};

makeToolCallBoxLabel0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolCallIcon*)
$fakeOpenerColor = RGBColor[ 0.53214525, 0.6238195470000001, 0.67275 ];

toolCallIcon // beginDefinition;
toolCallIcon[ KeyValuePattern[ "CallIcon" -> icon_Function ], color_ ] := icon @ color;
toolCallIcon[ _, color_ ] := getToolCallIcon[ None ][ color ];
toolCallIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*activeToolProgressIndicator*)
activeToolProgressIndicator // beginDefinition;

activeToolProgressIndicator[ ] :=
    RawBoxes @ TagBox[ ToBoxes @ chatbookIcon[ "PercolateProgressAnimation", False ], "ChatbookActiveToolProgress" ];

activeToolProgressIndicator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolCallIconPane*)
toolCallIconPane // beginDefinition;

toolCallIconPane[ icon_ ] := Pane[
    icon,
    Alignment        -> { Left, Center },
    BaselinePosition -> Scaled[ 0.27 ],
    ContentPadding   -> False,
    FrameMargins     -> { { 0, 0 }, { 0, 0 } },
    ImageMargins     -> { { 0, 2}, { 2, 2 } },
    ImageSize        -> { 20, 20 },
    ImageSizeAction  -> "ShrinkToFit"
];

toolCallIconPane // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeToolCallRawView*)
makeToolCallRawView // beginDefinition;

makeToolCallRawView[ KeyValuePattern[ "ToolCall" -> raw_String ] ] :=
    Framed[
        Framed[
            RawBoxes @ Cell[
                BoxData @ ToBoxes @ wideScrollPane @ raw,
                "Text", "RawToolCall",
                FontSize   -> 11,
                Background -> None
            ],
            Background   -> color @ "NA_ChatOutputToolCallBackground",
            FrameMargins -> 5,
            FrameStyle   -> None,
            ImageSize    -> { Scaled[ 1 ], Automatic },
            BaseStyle    -> "Text"
        ],
        Background   -> color @ "NA_ChatOutputToolCallBackground",
        FrameStyle   -> None,
        FrameMargins -> 10
    ];

makeToolCallRawView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeToolCallInterpretedView*)
makeToolCallInterpretedView // beginDefinition;

makeToolCallInterpretedView[ as_Association ] :=
    Framed[
        Column[
            {
                Item[
                    Pane[ Style[ (*FIXME:TR*)"INPUT", FontSize -> 11 ], FrameMargins -> { { 5, 5 }, { 1, 1 } } ],
                    ItemSize   -> Fit,
                    Background -> color @ "NA_ChatOutputToolCallHeaderBackground"
                ],
                Framed[
                    makeToolCallInputSection @ as,
                    Background   -> color @ "NA_ChatOutputToolCallBackground",
                    FrameMargins -> 5,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ],
                Item[
                    Pane[ Style[ (*FIXME:TR*)"OUTPUT", FontSize -> 11 ], FrameMargins -> { { 5, 5 }, { 1, 1 } } ],
                    ItemSize   -> Fit,
                    Background -> color @ "NA_ChatOutputToolCallHeaderBackground"
                ],
                Framed[
                    makeToolCallOutputSection @ as,
                    Background   -> color @ "NA_ChatOutputToolCallBackground",
                    FrameMargins -> 5,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ]
            },
            Alignment -> Left
        ],
        Background   -> color @ "NA_ChatOutputToolCallBackground",
        BaseStyle    -> { Editable -> False },
        FrameStyle   -> None,
        FrameMargins -> 10
    ];

makeToolCallInterpretedView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallInputSection*)
makeToolCallInputSection // beginDefinition;

makeToolCallInputSection[ as: KeyValuePattern[ "Parameters" -> params_Association ] ] := Enclose[
    Module[ { formatter },
        formatter = Confirm[ as[ "FormattingFunction" ], "FormattingFunction" ];
        Grid[
            KeyValueMap[ { #1, formatter[ #2, "Parameters", #1 ] } &, params ],
            Alignment  -> Left,
            BaseStyle  -> { "Text", LineBreakWithin -> Automatic },
            Dividers   -> All,
            FrameStyle -> color @ "NA_ChatOutputToolCallInputFrame",
            Spacings   -> 1
        ]
    ],
    throwInternalFailure[ makeToolCallInputSection @ as, ## ] &
];

makeToolCallInputSection[ KeyValuePattern[ "Parameters" -> query_String ] ] :=
    TextCell[ query, "Program", FontSize -> 0.75 * Inherited, Background -> None ];

makeToolCallInputSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveToolFormatter*)
resolveToolFormatter // beginDefinition;
resolveToolFormatter[ as_Association ] := Append[ as, "FormattingFunction" -> resolveToolFormatter0 @ as ];
resolveToolFormatter // endDefinition;

resolveToolFormatter0 // beginDefinition;
resolveToolFormatter0[ as_Association ] := resolveToolFormatter0 @ Lookup[ as, "FormattingFunction", Inherited ];
resolveToolFormatter0[ Automatic      ] := clickToCopy[ #1 ] &;
resolveToolFormatter0[ Inherited      ] := toolAutoFormatter;
resolveToolFormatter0[ None           ] := #1 &;
resolveToolFormatter0[ f_             ] := f;
resolveToolFormatter0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolAutoFormatter*)
toolAutoFormatter // beginDefinition;

toolAutoFormatter[ KeyValuePattern[ "Result" -> result_ ], "Result" ] :=
    toolAutoFormatter[ result, "Result" ];

toolAutoFormatter[ result_String, "Result" ] := RawBoxes @ Cell[
    TextData @ reformatTextData @ result,
    "Text",
    Background -> None
];

toolAutoFormatter[ parameter_, "Parameters", ___ ] := clickToCopy @ parameter;

toolAutoFormatter[ result_, ___ ] := result;

toolAutoFormatter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallOutputSection*)
makeToolCallOutputSection // beginDefinition;

makeToolCallOutputSection[ as: KeyValuePattern[ "Result" -> result_ ] ] := Enclose[
    Module[ { formatter },
        formatter = Confirm[ as[ "FormattingFunction" ], "FormattingFunction" ];
        TextCell[
            wideScrollPane @ ReplaceAll[ formatter[ result, "Result" ], Cell[ bd_BoxData, a___, "Input", b___ ] :> Cell[ bd, a, "Output", b ] ],
            "Text",
            Background      -> None,
            FrameBoxOptions -> { BaselinePosition -> Automatic },
            LineBreakWithin -> Automatic,
            PaneBoxOptions  -> { BaselinePosition -> Automatic }
        ]
    ],
    throwInternalFailure
];

makeToolCallOutputSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*wideScrollPane*)
wideScrollPane // beginDefinition;

(* This definition is similar to WorkspaceStyles.wl: "ChatCodeBlockTemplate" but has a wider minimum because it has more room initially *)
wideScrollPane[ expr_ ] := Pane[
    Pane[ expr, ImageSize -> Dynamic[ Function[ If[ # > 600, #, 600 ] ][ 0.9*AbsoluteCurrentValue[ { WindowSize, 1 } ] ] ] ],
    ImageSize          -> { Scaled[ 1 ], UpTo[ 400 ] },
    Scrollbars         -> Automatic,
    AppearanceElements -> None
];

wideScrollPane // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
