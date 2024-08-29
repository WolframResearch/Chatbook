(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`Context`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];
Needs[ "Wolfram`Chatbook`Serialization`"    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxCellsBeforeSelection = 100;
$maxCellsAfterSelection  = 10;

$currentSelectionIndicator = { $leftSelectionIndicator, $rightSelectionIndicator };

$notebookContextTemplate = StringTemplate[ "\
IMPORTANT: Below is some context from the user's currently selected notebook. \
The location of the user's current selection is marked by %%SelectionIndicator%%. \
Use this to determine where the user is in the notebook.

%%NotebookContent%%", Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Context from other notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getInlineChatPrompt*)
getInlineChatPrompt // beginDefinition;

getInlineChatPrompt[ settings_ ] :=
    If[ TrueQ @ $InlineChat,
        getInlineChatPrompt0[ settings, $inlineChatState ],
        None
    ];

getInlineChatPrompt // endDefinition;


getInlineChatPrompt0 // beginDefinition;

getInlineChatPrompt0[ settings_, state_Association ] :=
    getInlineChatPrompt0[
        settings,
        state[ "SelectionInfo"  ],
        state[ "ParentCell"     ],
        state[ "ParentNotebook" ]
    ];

getInlineChatPrompt0[ settings_, info_, cell_CellObject, nbo_NotebookObject ] :=
    getInlineChatPrompt0[ settings, info, cell, Cells @ nbo ];

getInlineChatPrompt0[
    settings_,
    info_,
    cell_CellObject,
    { before___CellObject, cell_, after___CellObject }
] :=
    Block[ { $selectionInfo = info, $includeCellXML = TrueQ @ $notebookEditorEnabled },
        getContextFromSelection0[
            <|
                "Before"   -> { before },
                "Selected" -> { cell   },
                "After"    -> { after  }
            |>,
            settings
        ]
    ];

getInlineChatPrompt0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getWorkspacePrompt*)
getWorkspacePrompt // beginDefinition;

getWorkspacePrompt[ settings_Association ] :=
    If[ TrueQ @ $WorkspaceChat,
        Block[ { $includeCellXML = TrueQ @ $notebookEditorEnabled },
            getContextFromSelection[ $evaluationNotebook, settings ]
        ],
        None
    ];

getWorkspacePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getContextFromSelection*)
getContextFromSelection // beginDefinition;

getContextFromSelection[ chatNB_NotebookObject, settings_Association ] :=
    getContextFromSelection[ chatNB, getUserNotebook @ chatNB, settings ];

getContextFromSelection[ chatNB_NotebookObject, None, settings_Association ] :=
    None;

getContextFromSelection[ chatNB_, nbo_NotebookObject, settings_Association ] := Enclose[
    Catch @ Module[ { selectionData },
        selectionData = ConfirmMatch[ selectContextCells @ nbo, _Association|None, "SelectionData" ];
        If[ selectionData === None, Throw @ None ];
        ConfirmBy[ getContextFromSelection0[ selectionData, settings ], StringQ, "Context" ]
    ],
    throwInternalFailure
];

getContextFromSelection // endDefinition;


getContextFromSelection0 // beginDefinition;

getContextFromSelection0[ selectionData: KeyValuePattern[ "Selected" -> { cell_CellObject } ], settings_ ] /;
    ! MatchQ[ $selectionInfo, None|_Association ] :=
        Block[ { $selectionInfo = getSelectionInfo @ cell },
            getContextFromSelection0[ selectionData, settings ] /; MatchQ[ $selectionInfo, None|_Association ]
        ];

getContextFromSelection0[ selectionData_Association, settings_ ] := Enclose[
    Catch @ Module[ { cellObjects, cells, len1, len2, before, selected, after, marked, messages, string },

        cellObjects = ConfirmMatch[ Flatten @ Values @ selectionData, { ___CellObject }, "CellObjects" ];
        cells = ConfirmMatch[ notebookRead @ cellObjects, { ___Cell }, "Cells" ];

        len1 = Length @ ConfirmMatch[ selectionData[ "Before"   ], { ___CellObject }, "BeforeLength"   ];
        len2 = Length @ ConfirmMatch[ selectionData[ "Selected" ], { ___CellObject }, "SelectedLength" ];

        before   = ConfirmMatch[ cells[[ 1 ;; len1 ]]              , { ___Cell }, "BeforeCells"   ];
        selected = ConfirmMatch[ cells[[ len1 + 1 ;; len1 + len2 ]], { ___Cell }, "SelectedCells" ];
        after    = ConfirmMatch[ cells[[ len1 + len2 + 1 ;; All ]] , { ___Cell }, "AfterCells"    ];

        marked = ConfirmMatch[ insertSelectionIndicator @ { before, selected, after }, { ___Cell }, "Marked" ];
        messages = ConfirmMatch[ makeChatMessages[ settings, marked, False ], { ___Association }, "Messages" ];
        string = ConfirmBy[ messagesToString @ messages, StringQ, "String" ];

        $contextPrompt   = processContextPromptString @ string;
        $selectionPrompt = extractSelectionPrompt @ string;

        $lastContextPrompt   = $contextPrompt;
        $lastSelectionPrompt = $selectionPrompt;

        (* FIXME: pass $selectionPrompt instead of extracting again: *)
        postProcessNotebookContextString[ applyNotebookContextTemplate @ string, string ]
    ],
    throwInternalFailure
];

getContextFromSelection0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractSelectionPrompt*)
extractSelectionPrompt // beginDefinition;

extractSelectionPrompt[ prompt_String ] := Enclose[
    Catch @ Module[ { selections, selected },
        selections = StringCases[ prompt, $leftSelectionIndicator ~~ s___ ~~ $rightSelectionIndicator :> s, 1 ];
        If[ selections === { }, Throw @ None ];
        selected = StringTrim @ ConfirmBy[ First @ selections, StringQ, "Selected" ];
        If[ selected === "", Throw @ None, selected ]
    ],
    throwInternalFailure
];

extractSelectionPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processContextPromptString*)
processContextPromptString // beginDefinition;

processContextPromptString[ prompt_String ] := Enclose[
    Module[ { noXML, noSelection },
        noXML = ConfirmBy[ stripCellXML @ prompt, StringQ, "NoXML" ];
        noSelection = ConfirmBy[ (*stripSelectionIndicators @*) noXML, StringQ, "NoSelection" ];
        ConfirmBy[ mergeCodeBlocks @ noSelection, StringQ, "Merged" ]
    ],
    throwInternalFailure
];

processContextPromptString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*stripCellXML*)
stripCellXML // beginDefinition;
stripCellXML[ prompt_String ] := StringDelete[ prompt, { "<cell" ~~ Except[ "\n" ]... ~~ ">\n", "\n</cell>" } ];
stripCellXML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*stripSelectionIndicators*)
stripSelectionIndicators // beginDefinition;
stripSelectionIndicators[ s_String ] := StringDelete[ s, { $leftSelectionIndicator, $rightSelectionIndicator } ];
stripSelectionIndicators // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messagesToString*)
messagesToString // beginDefinition;
messagesToString[ messages_List ] := messagesToString[ messages, messageToString /@ revertMultimodalContent @ messages ];
messagesToString[ _, strings: { ___String } ] := StringRiffle[ strings, "\n\n" ];
messagesToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageToString*)
messageToString // beginDefinition;
messageToString[ KeyValuePattern[ "Content" -> content_ ] ] := messageToString @ content;
messageToString[ KeyValuePattern[ "Data" -> content_ ] ] := messageToString @ content;
messageToString[ { message___String } ] := StringJoin @ message;
messageToString[ message_String ] := message;
messageToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postProcessNotebookContextString*)
postProcessNotebookContextString // beginDefinition;

postProcessNotebookContextString[ prompt_String, string_String ] :=
    Module[ { selected, selectedString },
        selected = StringCases[ string, $leftSelectionIndicator ~~ s__ ~~ $rightSelectionIndicator :> s, 1 ];
        selectedString = First[ selected, None ];
        If[ StringQ @ selectedString && StringLength @ selectedString < 100,
            StringJoin[
                prompt,
                "\n\nReminder: The user's currently selected text is: \"",
                StringTrim @ selectedString,
                "\""
            ],
            prompt
        ]
    ];

postProcessNotebookContextString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyNotebookContextTemplate*)
applyNotebookContextTemplate // beginDefinition;

applyNotebookContextTemplate[ string_String ] :=
    applyNotebookContextTemplate[ string, $currentSelectionIndicator ];

applyNotebookContextTemplate[ string_String, { before_String, after_String } ] :=
    applyNotebookContextTemplate[ string, before <> "..." <> after ];

applyNotebookContextTemplate[ string_String, indicator_String ] := TemplateApply[
    $notebookContextTemplate,
    <|
        "SelectionIndicator" -> indicator,
        "NotebookContent" -> string
    |>
];

applyNotebookContextTemplate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*insertSelectionIndicator*)
insertSelectionIndicator // beginDefinition;

insertSelectionIndicator[ { { beforeCells___Cell }, { selectedCell_Cell }, { afterCells___Cell } } ] :=
    With[ { info = $selectionInfo },
        { beforeCells, insertSelectionMarkers[ selectedCell, info ], afterCells } /; AssociationQ @ info
    ];

insertSelectionIndicator[ cells_ ] :=
    insertSelectionIndicator[ cells, $currentSelectionIndicator ];

insertSelectionIndicator[
    { { beforeCells___Cell }, { selectedCells___Cell }, { afterCells___Cell } },
    { before_String, after_String }
] := {
    beforeCells,
    Cell @ Verbatim @ before,
    selectedCells,
    Cell @ Verbatim @ after,
    afterCells
};

insertSelectionIndicator[
    { { beforeCells___Cell }, { selectedCells___Cell }, { afterCells___Cell } },
    before_String
] := {
    beforeCells,
    Cell @ Verbatim @ before,
    selectedCells,
    afterCells
};

insertSelectionIndicator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*selectContextCells*)
selectContextCells // beginDefinition;

selectContextCells[ nbo_NotebookObject ] :=
    selectContextCells @ Cells @ nbo;

selectContextCells[ { } ] :=
    None;

selectContextCells[ cells: { __CellObject } ] :=
    selectContextCells @ cellInformation @ cells;

selectContextCells[ { a: KeyValuePattern[ "CursorPosition" -> "AboveCell" ], after___ } ] :=
    selectContextCells0 @ <| "Before" -> { }, "Selected" -> { }, "After" -> { after } |>;

selectContextCells[ { before___, a: KeyValuePattern[ "CursorPosition" -> "BelowCell" ], after___ } ] :=
    selectContextCells0 @ <| "Before" -> { before, a }, "Selected" -> { }, "After" -> { after } |>;

selectContextCells[ { before___, a: KeyValuePattern[ "CursorPosition" -> _List ], after___ } ] :=
    selectContextCells0 @ <| "Before" -> { before }, "Selected" -> { a }, "After" -> { after } |>;

selectContextCells[ { before___, a: Longest[ KeyValuePattern[ "CursorPosition" -> "CellBracket" ].. ], after___ } ] :=
    selectContextCells0 @ <| "Before" -> { before }, "Selected" -> { a }, "After" -> { after } |>;

selectContextCells[ { all: KeyValuePattern[ "CursorPosition" -> None ]... } ] :=
    selectContextCells0 @ <| "Before" -> { all }, "Selected" -> { }, "After" -> { } |>;

selectContextCells // endDefinition;


selectContextCells0 // beginDefinition;

selectContextCells0[ KeyValuePattern @ {
    "Before"   -> before0_List,
    "Selected" -> current_List,
    "After"    -> after0_List
} ] :=
    Module[ { before, after },
        before = Reverse @ Take[ Reverse @ before0, UpTo[ $maxCellsBeforeSelection ] ];
        after = Take[ after0, UpTo[ $maxCellsAfterSelection ] ];
        Map[
            Cases[ KeyValuePattern[ "CellObject" -> cell_CellObject ] :> cell ],
            <| "Before" -> before, "Selected" -> current, "After" -> after |>
        ]
    ];

selectContextCells0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getUserNotebook*)
getUserNotebook // beginDefinition;
getUserNotebook[ ] := FirstCase[ userNotebooks[ ], _NotebookObject, None ];
getUserNotebook[ chatNB_NotebookObject ] := FirstCase[ userNotebooks @ chatNB, _NotebookObject, None ];
getUserNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*userNotebooks*)
userNotebooks // beginDefinition;

userNotebooks[ chatNB_NotebookObject ] :=
    DeleteCases[ userNotebooks[ ], chatNB ];

userNotebooks[ ] :=
    userNotebooks @ Notebooks[ ];

userNotebooks[ notebooks: { ___NotebookObject } ] := Enclose[
    Module[ { noPalettes, visible, included },

        noPalettes = ConfirmMatch[
            selectByCurrentValue[ notebooks, WindowFrame, # =!= "Palette" & ],
            { ___NotebookObject },
            "NoPalettes"
        ];

        visible = ConfirmMatch[
            selectByCurrentValue[ noPalettes, Visible, TrueQ ],
            { ___NotebookObject },
            "Visible"
        ];

        included = ConfirmMatch[
            selectByCurrentValue[ visible, { TaggingRules, "ChatNotebookSettings" }, includedTagsQ ],
            { ___NotebookObject },
            "NotExcluded"
        ];

        included
    ],
    throwInternalFailure
];

userNotebooks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*userNotebookQ*)
userNotebookQ // beginDefinition;

userNotebookQ[ nbo_NotebookObject ] := TrueQ @ And[
    CurrentValue[ nbo, WindowFrame ] =!= "Palette",
    CurrentValue[ nbo, Visible ] === True,
    includedTagsQ @ AbsoluteCurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings" } ]
];

userNotebookQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*includedTagsQ*)
includedTagsQ // beginDefinition;
includedTagsQ[ KeyValuePattern[ "ExcludeFromChat" -> True ] ] := False;
includedTagsQ[ KeyValuePattern[ "WorkspaceChat" -> True ] ] := False;
includedTagsQ[ _ ] := True;
includedTagsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*insertSelectionMarkers*)
insertSelectionMarkers // beginDefinition;

insertSelectionMarkers[ cell_CellObject ] :=
    insertSelectionMarkers[ NotebookRead @ cell, cellInformation @ cell ];

insertSelectionMarkers[ cell_, KeyValuePattern[ "CursorPosition" -> pos_ ] ] :=
    insertSelectionMarkers[ cell, pos ];

insertSelectionMarkers[ cell: Cell[ content_, a___ ], { before0_Integer, after0_Integer } ] :=
    Module[ { before, after, result },
        before = before0;
        after = after0;
        result = Catch[ insertSelectionMarkers0[ { before, after }, content ], $insertTag ];
        If[ MissingQ @ result, fullSelection @ cell, Cell[ result, a ] ]
    ];

insertSelectionMarkers[ cell_, "CellBracket"|None ] :=
    fullSelection @ cell;

insertSelectionMarkers // endDefinition;


insertSelectionMarkers0 // beginDefinition;
insertSelectionMarkers0 // Attributes = { HoldFirst };

insertSelectionMarkers0[ state_, (h: BoxData|TextData|RowBox|StyleBox)[ box_, a___ ] ] :=
    h[ insertSelectionMarkers0[ state, box ], a ];

insertSelectionMarkers0[ { before_, after_ }, cell_Cell ] :=
    WithCleanup[
        cell,
        before -= 1;
        after  -= 1;
    ];

insertSelectionMarkers0[ state_, boxes_List ] :=
    insertSelectionMarkers0[ state, # ] & /@ boxes;

insertSelectionMarkers0[ { before_, after_ }, str_String ] :=
    With[ { len = StringLength @ str },
        WithCleanup[
            Which[
                (* selection caret is in range and between characters *)
                0 <= before <= len && before === after,
                WithCleanup[
                    StringInsert[ str, $leftSelectionIndicator<>$rightSelectionIndicator, before + 1 ],
                    before = after = -1
                ],

                (* both are in range of current string *)
                0 <= before <= len && 0 <= after <= len,
                WithCleanup[
                    StringInsert[
                        StringInsert[ str, $rightSelectionIndicator, after + 1 ],
                        $leftSelectionIndicator,
                        before + 1
                    ],
                    before = after = -1
                ],

                (* beginning of selection is in range *)
                0 <= before <= len,
                WithCleanup[
                    StringInsert[ str, $leftSelectionIndicator, before + 1 ],
                    before = -1
                ],

                (* end of selection is in range *)
                0 <= after <= len,
                WithCleanup[
                    StringInsert[ str, $rightSelectionIndicator, after + 1 ],
                    after = -1
                ],

                (* selection is not in range *)
                True,
                str
            ],

            (* update counters *)
            before -= len;
            after  -= len;
        ]
    ];

insertSelectionMarkers0[ { _? Negative, _? Negative }, box_ ] :=
    box;

insertSelectionMarkers0[ ___ ] :=
    Throw[ Missing[ "FullSelection" ], $insertTag ];

insertSelectionMarkers0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fullSelection*)
fullSelection // beginDefinition;
fullSelection[ Cell[ a_, b___ ] ] := Cell[ fullSelection @ a, b ];
fullSelection[ text_String ] := TextData @ { $leftSelectionIndicator, text, $rightSelectionIndicator };
fullSelection[ BoxData[ { a___ }, b___ ] ] := BoxData[ { $leftSelectionIndicator, a, $rightSelectionIndicator }, b ];
fullSelection[ BoxData[ a_, b___ ] ] := BoxData[ RowBox @ { $leftSelectionIndicator, a, $rightSelectionIndicator }, b ];
fullSelection[ TextData[ text_ ] ] := TextData @ Flatten @ { $leftSelectionIndicator, text, $rightSelectionIndicator };
fullSelection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
