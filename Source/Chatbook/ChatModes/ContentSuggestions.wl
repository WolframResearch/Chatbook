(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`ContentSuggestions`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$suggestionsService        = "OpenAI";
$suggestionsAuthentication = Automatic;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Wolfram Language Suggestions*)
$wlSuggestionsModel       = "gpt-4o";
$wlSuggestionsMultimodal  = False;
$wlSuggestionsCount       = 3;
$wlSuggestionsMaxTokens   = 128;
$wlSuggestionsTemperature = 1.0;
$wlPlaceholderString      = "<placeholder>";

$wlSuggestionsPrompt = StringTemplate[ "\
Complete the following Wolfram Language code by writing text that can be inserted into %%Placeholder%%.
Do your best to match the existing style (whitespace, line breaks, etc.).
Your suggested text will be inserted into %%Placeholder%%, so be careful not to repeat the immediately surrounding text.
Use `%` to refer to the previous output or `%n` for earlier outputs (where n is an output number) when appropriate.
Respond with the completion text and nothing else.
Do not include any formatting in your response. Do not include outputs or `In[]:=` cell labels.",
Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TextData Suggestions*)
$textSuggestionsModel       = "gpt-4o";
$textSuggestionsMultimodal  = False;
$textSuggestionsCount       = 3;
$textSuggestionsMaxTokens   = 256;
$textSuggestionsTemperature = 1.0;
$textPlaceholderString      = "<placeholder>";

$textSuggestionsPrompt = StringTemplate[ "\
Complete the following by writing text that can be inserted into %%Placeholder%%.
The current cell style is \"%%Style%%\", so only write content that would be appropriate for this cell type.
Do your best to match the existing style (whitespace, line breaks, etc.).
Your suggested text will be inserted into %%Placeholder%%, so be careful not to repeat the immediately surrounding text.
Respond with the completion text and nothing else.",
Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Notebook Content Suggestions*)
(* TODO: between cells suggestions *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Patterns*)
$$emptyItem       = "" | { } | { "" };
$$emptySuggestion = $$emptyItem | BoxData @ $$emptyItem | TextData @ $$emptyItem;

$$inLabel  = "In["  ~~ DigitCharacter... ~~ "]" ~~ WhitespaceCharacter... ~~ ":=";
$$outLabel = "Out[" ~~ DigitCharacter... ~~ "]" ~~ WhitespaceCharacter... ~~ ("="|"//");

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowContentSuggestions*)
ShowContentSuggestions // beginDefinition;
ShowContentSuggestions[ ] := catchMine @ showContentSuggestions @ InputNotebook[ ];
ShowContentSuggestions[ nbo_NotebookObject ] := catchMine @ showContentSuggestions @ nbo;
ShowContentSuggestions // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showContentSuggestions*)
showContentSuggestions // beginDefinition;

showContentSuggestions[ $Failed ] :=
    Null;

showContentSuggestions[ nbo_NotebookObject ] :=
    showContentSuggestions[ nbo, SelectedCells @ nbo ];

showContentSuggestions[ nbo_NotebookObject, { selected_CellObject } ] :=
    showContentSuggestions0[ nbo, selected ];

showContentSuggestions[ nbo_NotebookObject, { } ] := Enclose[
    Module[ { selected },
        (* FIXME: this is where notebook content suggestions should come in *)
        SelectionMove[ nbo, After, Cell ];
        NotebookWrite[ nbo, "", All ];
        selected = ConfirmMatch[ SelectedCells @ nbo, { _CellObject }, "Selected" ];
        showContentSuggestions0[ nbo, First @ selected ]
    ],
    throwInternalFailure
];

showContentSuggestions[ _NotebookObject, _ ] :=
    Null;

showContentSuggestions // endDefinition;


showContentSuggestions0 // beginDefinition;

showContentSuggestions0[ nbo_NotebookObject, root_CellObject ] := Enclose[
    Module[ { selectionInfo },

        NotebookDelete @ Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedContentSuggestions" ];

        selectionInfo = ConfirmMatch[
            getSelectionInfo @ root,
            None | KeyValuePattern[ "CursorPosition" -> { _Integer, _Integer } ],
            "SelectionInfo"
        ];

        $lastSelectionInfo = selectionInfo;

        ConfirmMatch[
            setServiceCaller[ showContentSuggestions0[ nbo, root, selectionInfo ], "ContentSuggestions" ],
            _CellObject | Null,
            "ShowContentSuggestions"
        ]
    ],
    throwInternalFailure
];

showContentSuggestions0[ nbo_NotebookObject, root_CellObject, selectionInfo_Association ] := Enclose[
    Catch @ Module[ { suggestionsContainer, attached, settings, context },

        If[ ! MatchQ[ selectionInfo, KeyValuePattern[ "CursorPosition" -> { _Integer, _Integer } ] ], Throw @ Null ];

        suggestionsContainer = ProgressIndicator[ Appearance -> "Necklace" ];
        attached = ConfirmMatch[
            AttachCell[
                NotebookSelection @ nbo,
                contentSuggestionsCell[ Dynamic[ suggestionsContainer ] ],
                { "WindowCenter", Bottom },
                0,
                { Center, Top },
                RemovalConditions -> { "EvaluatorQuit", "MouseClickOutside", "SelectionExit" }
            ],
            _CellObject,
            "Attached"
        ];

        ClearAttributes[ suggestionsContainer, Temporary ];

        settings = ConfirmBy[ AbsoluteCurrentChatSettings @ root, AssociationQ, "Settings" ];

        context = ConfirmBy[
            getContextFromSelection[ None, nbo, settings, "NotebookInstructionsPrompt" -> False ],
            StringQ,
            "Context"
        ];

        ConfirmMatch[
            generateSuggestions[ selectionInfo, Dynamic[ suggestionsContainer ], nbo, root, context, settings ],
            _Pane,
            "Submit"
        ];

        attached
    ],
    throwInternalFailure
];

showContentSuggestions0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*contentSuggestionsCell*)
contentSuggestionsCell // beginDefinition;

contentSuggestionsCell[ Dynamic[ container_Symbol ] ] := Cell[
    BoxData @ ToBoxes @ Framed[
        Dynamic[ container(*, Deinitialization :> Quiet @ Remove @ container*) ],
        Background     -> GrayLevel[ 0.95 ],
        FrameStyle     -> GrayLevel[ 0.75 ],
        RoundingRadius -> 5
    ],
    "AttachedContentSuggestions"
];

contentSuggestionsCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateSuggestions*)
generateSuggestions // beginDefinition;
generateSuggestions[ selectionInfo_Association, args__ ] := generateSuggestions[ selectionInfo[ "ContentData" ], args ];
generateSuggestions[ BoxData, args__ ] := generateWLSuggestions @ args;
generateSuggestions[ TextData, args__ ] := generateTextSuggestions @ args;
generateSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generateWLSuggestions*)
generateWLSuggestions // beginDefinition;

generateWLSuggestions[ Dynamic[ container_ ], nbo_, root_CellObject, context0_String, settings_ ] := Enclose[
    Module[ { context, instructions, response, suggestions },

        context = ConfirmBy[
            StringReplace[
                context0,
                Shortest[ $leftSelectionIndicator~~___~~$rightSelectionIndicator ] :> $wlPlaceholderString
            ],
            StringQ,
            "Context"
        ];

        If[ TrueQ @ $wlSuggestionsMultimodal,
            context = ConfirmMatch[ GetExpressionURIs @ context, { (_String|_Image)... }, "MultimodalContext" ]
        ];

        $lastSuggestionContext = context;

        instructions = ConfirmBy[
            TemplateApply[ $wlSuggestionsPrompt, <| "Placeholder" -> $wlPlaceholderString |> ],
            StringQ,
            "Instructions"
        ];

        response = setServiceCaller @ ServiceExecute[
            $suggestionsService,
            "Chat",
            {
                "Messages" -> {
                    <| "Role" -> "System", "Content" -> instructions |>,
                    <| "Role" -> "User"  , "Content" -> context      |>
                },
                "Model"       -> $wlSuggestionsModel,
                "N"           -> $wlSuggestionsCount,
                "MaxTokens"   -> $wlSuggestionsMaxTokens,
                "Temperature" -> $wlSuggestionsTemperature
            },
            Authentication -> $suggestionsAuthentication
        ];

        $lastSuggestionsResponse = response;

        suggestions = DeleteDuplicates @ ConfirmMatch[ getWLSuggestions @ response, { __BoxData }, "Suggestions" ];

        $lastSuggestions = suggestions;

        container = formatSuggestions[ Dynamic[ container ], suggestions, nbo, root, context, settings ]
    ],
    throwInternalFailure
];

generateWLSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getWLSuggestions*)
getWLSuggestions // beginDefinition;
getWLSuggestions[ content_ ] := postProcessWLSuggestions @ getSuggestions @ content;
getWLSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postProcessWLSuggestions*)
postProcessWLSuggestions // beginDefinition;

postProcessWLSuggestions[ suggestions_List ] :=
    postProcessWLSuggestions /@ suggestions;

postProcessWLSuggestions[ suggestion_String ] := Enclose[
    Module[ { noOutputs, noBlocks, noLabels },

        noOutputs = StringDelete[
            StringDelete[
                suggestion,
                "```" ~~ Except[ "\n" ]... ~~ WhitespaceCharacter... ~~ $$outLabel ~~ ___ ~~ EndOfString
            ],
            $$outLabel ~~ ___ ~~ EndOfString
        ];

        noBlocks = StringTrim @ StringDelete[
            If[ StringContainsQ[ noOutputs, "```"~~__~~"```" ],
                ConfirmBy[
                    First @ StringCases[ noOutputs, "```" ~~ Except[ "\n" ]... ~~ "\n" ~~ code___ ~~ "```" :> code, 1 ],
                    StringQ,
                    "NoBlocks"
                ],
                noOutputs
            ],
            {
                StartOfLine ~~ WhitespaceCharacter... ~~ "```" ~~ Except[ "\n" ]... ~~ EndOfLine,
                "```" ~~ WhitespaceCharacter... ~~ EndOfLine
            }
        ];

        noLabels = StringTrim @ StringDelete[ noBlocks, $$inLabel ];

        ConfirmMatch[ StripBoxes @ stringToBoxes @ noLabels, _BoxData, "Result" ]
    ],
    throwInternalFailure
];

postProcessWLSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generateTextSuggestions*)
generateTextSuggestions // beginDefinition;

generateTextSuggestions[ Dynamic[ container_ ], nbo_, root_CellObject, context0_String, settings_ ] := Enclose[
    Module[ { style, context, instructions, response, suggestions },

        style = First[ ConfirmMatch[ cellStyles @ root, { ___String }, "Styles" ], "Text" ];

        context = ConfirmBy[
            StringReplace[
                context0,
                Shortest[ $leftSelectionIndicator~~___~~$rightSelectionIndicator ] :> $textPlaceholderString
            ],
            StringQ,
            "Context"
        ];

        If[ TrueQ @ $textSuggestionsMultimodal,
            context = ConfirmMatch[ GetExpressionURIs @ context, { (_String|_Image)... }, "MultimodalContext" ]
        ];

        $lastSuggestionContext = context;

        instructions = ConfirmBy[
            TemplateApply[ $textSuggestionsPrompt, <| "Placeholder" -> $textPlaceholderString, "Style" -> style |> ],
            StringQ,
            "Instructions"
        ];

        $lastInstructions = instructions;

        response = setServiceCaller @ ServiceExecute[
            $suggestionsService,
            "Chat",
            {
                "Messages" -> {
                    <| "Role" -> "System", "Content" -> instructions |>,
                    <| "Role" -> "User"  , "Content" -> context      |>
                },
                "Model"       -> $textSuggestionsModel,
                "N"           -> $textSuggestionsCount,
                "MaxTokens"   -> $textSuggestionsMaxTokens,
                "Temperature" -> $textSuggestionsTemperature,
                "StopTokens"  -> { "\n\n" }
            },
            Authentication -> $suggestionsAuthentication
        ];

        $lastSuggestionsResponse = response;

        suggestions = DeleteDuplicates @ ConfirmMatch[ getTextSuggestions @ response, { __TextData }, "Suggestions" ];

        $lastSuggestions = suggestions;

        container = formatSuggestions[ Dynamic[ container ], suggestions, nbo, root, context, settings ]
    ],
    throwInternalFailure
];

generateTextSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getTextSuggestions*)
getTextSuggestions // beginDefinition;
getTextSuggestions[ content_ ] := postProcessTextSuggestions @ getSuggestions @ content;
getTextSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postProcessTextSuggestions*)
postProcessTextSuggestions // beginDefinition;
postProcessTextSuggestions[ suggestions_List ] := postProcessTextSuggestions /@ suggestions;
postProcessTextSuggestions[ s_String ] := postProcessTextSuggestions[ s, FormatChatOutput @ s ];
postProcessTextSuggestions[ s_, RawBoxes[ cell_Cell ] ] := postProcessTextSuggestions[ s, ExplodeCell @ cell ];
postProcessTextSuggestions[ s_, { cell_Cell, ___ } ] := toTextData @ cell;
postProcessTextSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toTextData*)
toTextData // beginDefinition;
toTextData[ Cell[ text_, ___ ] ] := toTextData @ text;
toTextData[ text_TextData ] := text;
toTextData[ text: $$textData ] := TextData @ Flatten @ { text };
toTextData[ boxes_BoxData ] := TextData @ { Cell[ postProcessWLSuggestions @ CellToString @ boxes, "InlineCode" ] };
toTextData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSuggestions*)
getSuggestions // beginDefinition;
getSuggestions[ KeyValuePattern[ "Content"|"content"|"choices"|"message" -> data_ ] ] := getSuggestions @ data;
getSuggestions[ content_String ] := content;
getSuggestions[ items_List ] := DeleteCases[ getSuggestions /@ items, $$emptySuggestion ];
getSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatSuggestions*)
formatSuggestions // beginDefinition;

formatSuggestions[
    container_,
    suggestions: { __ },
    nbo_NotebookObject,
    root_CellObject,
    context_,
    settings_
] := Enclose[
    Module[ { styles, formatted },
        styles = ConfirmMatch[ cellStyles @ root, { ___String }, "Styles" ];
        formatted = ConfirmMatch[ formatSuggestion[ root, nbo, styles ] /@ suggestions, { __Button }, "Formatted" ];
        Pane[ Column[ formatted, Spacings -> 0 ] ]
    ],
    throwInternalFailure
];

formatSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatSuggestion*)
formatSuggestion // beginDefinition;

formatSuggestion[ root_CellObject, nbo_NotebookObject, styles_ ] :=
    formatSuggestion[ root, nbo, styles, # ] &;

formatSuggestion[ root_CellObject, nbo_NotebookObject, { styles___String }, suggestion_BoxData ] := Button[
    RawBoxes @ Cell[
        suggestion,
        styles,
        If[ MemberQ[ { styles }, "Input"|"Code" ],
            Sequence @@ {
                ShowStringCharacters -> True,
                ShowAutoStyles       -> True,
                LanguageCategory     -> "Input"
            },
            Sequence @@ { }
        ]
    ],
    NotebookDelete @ EvaluationCell[ ];
    NotebookWrite[ nbo, suggestion, After ],
    Alignment -> Left
];

formatSuggestion[ root_CellObject, nbo_NotebookObject, { styles___String }, suggestion_TextData ] := Button[
    RawBoxes @ Cell[ suggestion, styles, Deployed -> True, Selectable -> False ],
    NotebookDelete @ EvaluationCell[ ];
    NotebookWrite[ nbo, suggestion, After ],
    Alignment -> Left
];

formatSuggestion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
