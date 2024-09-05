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
$wlSuggestionsModel       = "gpt-4-turbo";
$wlSuggestionsCount       = 3;
$wlSuggestionsMaxTokens   = 128;
$wlSuggestionsTemperature = 1.0;

$wlSuggestionsPrompt = "\
Complete the following Wolfram Language code by writing text that can be inserted into `Placeholder`. \
Do your best to match the existing style (whitespace, line breaks, etc.). \
Respond with the completion text and nothing else. \
Do not include any formatting in your response. Do not include outputs or `In[]:=` cell labels.";

(* TODO: need to also handle TextData cells *)

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
showContentSuggestions[ $Failed ] := Null;
showContentSuggestions[ nbo_NotebookObject ] := showContentSuggestions[ nbo, SelectedCells @ nbo ];
showContentSuggestions[ nbo_NotebookObject, { selected_CellObject } ] := showContentSuggestions0[ nbo, selected ];
showContentSuggestions[ _NotebookObject, _ ] := Null;
showContentSuggestions // endDefinition;


showContentSuggestions0 // beginDefinition;

showContentSuggestions0[ a__ ] := Enclose[
    ConfirmMatch[
        setServiceCaller[ showContentSuggestions1 @ a, "ContentSuggestions" ],
        _CellObject | Null,
        "ShowContentSuggestions"
    ],
    throwInternalFailure
];

showContentSuggestions0 // endDefinition;


showContentSuggestions1 // beginDefinition;

showContentSuggestions1[ nbo_NotebookObject, root_CellObject ] := Enclose[
    Catch @ Module[ { selectionInfo, suggestionsContainer, attached, settings, context },

        NotebookDelete @ Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedContentSuggestions" ];

        selectionInfo = ConfirmMatch[
            getSelectionInfo @ root,
            None | KeyValuePattern[ "CursorPosition" -> { _Integer, _Integer } ],
            "SelectionInfo"
        ];

        (* TODO: need to support TextData suggestions: *)
        If[ ! MatchQ[ selectionInfo[ "ContentData" ], BoxData|"BoxData"|_Missing ], Throw @ Null ];

        (* Only show autocomplete if the selection is between characters: *)
        If[ ! MatchQ[ selectionInfo, KeyValuePattern[ "CursorPosition" -> { n_Integer, n_Integer } ] ], Throw @ Null ];

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
        context  = ConfirmBy[ getContextFromSelection[ None, nbo, settings ], StringQ, "Context" ];

        ConfirmMatch[
            generateWLSuggestions[ Dynamic[ suggestionsContainer ], nbo, root, context, settings ],
            _Pane,
            "Submit"
        ];

        attached
    ],
    throwInternalFailure
];

showContentSuggestions1 // endDefinition;

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
(* ::Subsubsection::Closed:: *)
(*generateWLSuggestions*)
generateWLSuggestions // beginDefinition;

generateWLSuggestions[ Dynamic[ container_ ], nbo_, root_CellObject, context_String, settings_ ] := Enclose[
    Module[ { placeholder, instructions, response, suggestions },

        placeholder = ConfirmBy[ $leftSelectionIndicator<>$rightSelectionIndicator, StringQ, "Placeholder" ];

        instructions = ConfirmBy[
            TemplateApply[ $wlSuggestionsPrompt, <| "Placeholder" -> placeholder |> ],
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

        suggestions = DeleteDuplicates @ ConfirmMatch[ getSuggestions @ response, { __String }, "Suggestions" ];

        container = formatSuggestions[ Dynamic[ container ], suggestions, nbo, root, context, settings ]
    ],
    throwInternalFailure
];

generateWLSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSuggestions*)
getSuggestions // beginDefinition;
getSuggestions[ KeyValuePattern[ "Content"|"content"|"choices"|"message" -> content_ ] ] := getSuggestions @ content;
getSuggestions[ content_String ] := content;
getSuggestions[ items_List ] := getSuggestions /@ items;
getSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatSuggestions*)
formatSuggestions // beginDefinition;

formatSuggestions[
    container_,
    suggestions: { __String },
    nbo_NotebookObject,
    root_CellObject,
    context_,
    settings_
] := Enclose[
    Module[ { formatted },
        formatted = ConfirmMatch[ formatSuggestion[ root, nbo ] /@ suggestions, { __Button }, "Formatted" ];
        Pane[ Column[ formatted, Spacings -> 0 ] ]
    ],
    throwInternalFailure
];

formatSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatSuggestion*)
formatSuggestion // beginDefinition;

formatSuggestion[ root_CellObject, nbo_NotebookObject ] :=
    formatSuggestion[ root, nbo, # ] &;

formatSuggestion[ root_CellObject, nbo_NotebookObject, suggestion_String ] := Button[
    suggestion,
    NotebookDelete @ EvaluationCell[ ];
    NotebookWrite[ nbo, suggestion, After ],
    BaseStyle -> { "Input" },
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
