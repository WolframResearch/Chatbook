(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`Context`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxCellsBeforeSelection    = 100;
$maxCellsAfterSelection     = 50;
$notebookInstructionsPrompt = True;
$currentSelectionIndicator  = { $leftSelectionIndicator, $rightSelectionIndicator };
$notebookContextLimitScale  = 0.25;
$downScaledSettings         = { "MaxCellStringLength", "MaxContextTokens", "MaxOutputCellStringLength" };
$contextPrompt              = None;
$selectionPrompt            = None;

$notebookContextTemplate = StringTemplate[ "\
IMPORTANT: Below is some metadata and content from the user's currently selected notebook. \
The location of the user's current selection is marked by %%SelectionIndicator%%. \
Use this to determine where the user is in the notebook.

<notebook>
<metadata>%%NotebookMetadata%%</metadata>
<content>
%%NotebookContent%%
</content>
</notebook>", Delimiters -> "%%" ];

$$exclusionReason  = None | { __String };
$$exclusionReasons = { $$exclusionReason... };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ToggleChatInclusion*)
ToggleChatInclusion // beginDefinition;

ToggleChatInclusion[ ] :=
    catchMine @ ToggleChatInclusion @ InputNotebook[ ];

ToggleChatInclusion[ obj: _CellObject|_NotebookObject ] := catchMine @ Enclose[
    ToggleChatInclusion[ obj, ! ConfirmMatch[ currentlyIncludedQ @ obj, True|False, "Included" ] ],
    throwInternalFailure
];

ToggleChatInclusion[ obj: _CellObject|_NotebookObject, True ] := catchMine @ Enclose[
    ConfirmMatch[ includeInChatHistory @ obj, True, "Include" ],
    throwInternalFailure
];

ToggleChatInclusion[ obj: _CellObject|_NotebookObject, False ] := catchMine @ Enclose[
    ConfirmMatch[ excludeFromChatHistory @ obj, False, "Exclude" ],
    throwInternalFailure
];

ToggleChatInclusion // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentlyIncludedQ*)
currentlyIncludedQ // beginDefinition;
currentlyIncludedQ[ obj_ ] := currentlyIncludedQ[ obj, CurrentChatSettings[ obj, "ExcludeFromChat" ] ];
currentlyIncludedQ[ obj_, True ] := False;
currentlyIncludedQ[ obj_, False|$$unspecified ] := True;
currentlyIncludedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*includeInChatHistory*)
includeInChatHistory // beginDefinition;
includeInChatHistory[ obj_ ] := (CurrentChatSettings[ obj, "ExcludeFromChat" ] = Inherited; currentlyIncludedQ @ obj);
includeInChatHistory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*excludeFromChatHistory*)
excludeFromChatHistory // beginDefinition;
excludeFromChatHistory[ obj_ ] := (CurrentChatSettings[ obj, "ExcludeFromChat" ] = True; currentlyIncludedQ @ obj);
excludeFromChatHistory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SourceNotebookObjectInformation*)
SourceNotebookObjectInformation // beginDefinition;

SourceNotebookObjectInformation[ ] := catchMine @ Enclose[
    Select[
        ConfirmMatch[ sourceNotebookInformation[ ], { ___Association }, "NotebookInformation" ],
        #[ "Usable" ] &
    ],
    throwInternalFailure
];

SourceNotebookObjectInformation // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sourceNotebookInformation*)
sourceNotebookInformation // beginDefinition;

sourceNotebookInformation[ ] := Enclose[
    Catch @ Module[ { info, reasons, usable, included, index, transposed },

        info = ConfirmMatch[ DeleteMissing @ notebookInformation @ All, { ___Association }, "NotebookInformation" ];
        reasons = ConfirmMatch[ exclusionReason /@ info, $$exclusionReasons, "Reasons" ];

        usable   = Thread[ "Usable"   -> MatchQ[ None | { "Excluded" } ] /@ reasons ];
        included = Thread[ "Included" -> SameAs[ None ] /@ reasons ];
        index    = Thread[ "Index"    -> Range @ Length @ info ];

        transposed = ConfirmBy[
            Transpose @ { info, Thread[ "ExclusionReasons" -> reasons ], usable, included, index },
            ListQ,
            "Transposed"
        ];

        Association /@ transposed
    ],
    throwInternalFailure
];

sourceNotebookInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exclusionReason*)
exclusionReason // beginDefinition;

exclusionReason[ info_Association ] := Enclose[
    Module[ { tested, keys },
        tested = ConfirmBy[ Comap[ $exclusionTests, info ], AssociationQ, "Tested" ];
        keys = ConfirmMatch[ Keys @ Select[ tested, TrueQ ], { ___String }, "Keys" ];
        Replace[ keys, { } -> None ]
    ],
    throwInternalFailure
];

exclusionReason // endDefinition;


$exclusionTests = <|
    "Excluded"      -> Function[ #[ "ChatNotebookSettings", "ExcludeFromChat" ] === True ],
    "Invisible"     -> Function[ #[ "Visible" ] === False ],
    "WindowFrame"   -> Function[ MatchQ[ #[ "WindowFrame" ], Except[ "Normal" ] ] ],
    "WorkspaceChat" -> Function[ #[ "ChatNotebookSettings", "WorkspaceChat" ] ]
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Context from other notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getInlineChatPrompt*)
getInlineChatPrompt // beginDefinition;

getInlineChatPrompt[ settings_ ] :=
    If[ TrueQ @ $InlineChat && TrueQ @ settings[ "AllowSelectionContext" ],
        getInlineChatPrompt0[ settings, $inlineChatState ] // LogChatTiming[ "GetInlineChatPrompt" ],
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
    If[ TrueQ @ $WorkspaceChat && TrueQ @ settings[ "AllowSelectionContext" ],
        Block[ { $includeCellXML = TrueQ @ $notebookEditorEnabled },
            getContextFromSelection[ $evaluationNotebook, settings ]
        ] // LogChatTiming[ "GetWorkspacePrompt" ],
        None
    ];

getWorkspacePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getContextFromSelection*)
getContextFromSelection // beginDefinition;
getContextFromSelection // Options = {
    "NotebookInstructionsPrompt" -> True,
    "MaxCellsBeforeSelection"    :> $maxCellsBeforeSelection,
    "MaxCellsAfterSelection"     :> $maxCellsAfterSelection
};

getContextFromSelection[ chatNB_NotebookObject, settings_Association, opts: OptionsPattern[ ] ] :=
    Module[ { focused, userNotebook },
        focused = settings[ "FocusedNotebook" ];
        userNotebook = If[ notebookObjectQ @ focused, focused, getUserNotebook[ ] ];
        getContextFromSelection[ chatNB, userNotebook, settings, opts ]
    ];

getContextFromSelection[ chatNB_NotebookObject, None, settings_Association, opts: OptionsPattern[ ] ] :=
    None;

getContextFromSelection[ chatNB_, nbo_NotebookObject, settings0_Association, opts: OptionsPattern[ ] ] := Enclose[
    Catch @ Block[
        {
            $notebookInstructionsPrompt = OptionValue[ "NotebookInstructionsPrompt" ],
            $maxCellsBeforeSelection    = OptionValue[ "MaxCellsBeforeSelection"    ],
            $maxCellsAfterSelection     = OptionValue[ "MaxCellsAfterSelection"     ],
            $notebookMetadataString     = getNotebookMetadataString @ nbo,
            $countImageTokens           = countImageTokensQ @ settings0
        },
        Module[ { settings, selectionData, string },
            settings = ConfirmBy[ downScaledSettings @ settings0, AssociationQ, "Settings" ];

            selectionData = ConfirmMatch[
                LogChatTiming @ selectContextCells @ nbo,
                _Association|None,
                "SelectionData"
            ];

            If[ selectionData === None, Throw @ None ];

            string = ConfirmBy[ getContextFromSelection0[ selectionData, settings ], StringQ, "Context" ];

            ConfirmBy[ mergeCodeBlocks @ string, StringQ, "Merged" ]
        ]
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
    Catch @ Module[
        { cellObjects, cells, len1, len2, before, selected, after, marked, messages, string, nbCtx },

        cellObjects = ConfirmMatch[ Flatten @ Values @ selectionData, { ___CellObject }, "CellObjects" ];
        cells = ConfirmMatch[ LogChatTiming @ notebookRead @ cellObjects, { ___Cell }, "Cells" ];

        len1 = Length @ ConfirmMatch[ selectionData[ "Before"   ], { ___CellObject }, "BeforeLength"   ];
        len2 = Length @ ConfirmMatch[ selectionData[ "Selected" ], { ___CellObject }, "SelectedLength" ];

        before   = ConfirmMatch[ cells[[ 1 ;; len1 ]]              , { ___Cell }, "BeforeCells"   ];
        selected = ConfirmMatch[ cells[[ len1 + 1 ;; len1 + len2 ]], { ___Cell }, "SelectedCells" ];
        after    = ConfirmMatch[ cells[[ len1 + len2 + 1 ;; All ]] , { ___Cell }, "AfterCells"    ];

        marked = ConfirmMatch[ insertSelectionIndicator @ { before, selected, after }, { ___Cell }, "Marked" ];
        messages = ConfirmMatch[ LogChatTiming @ makeChatMessages[ settings, marked, False ], { ___Association }, "Messages" ];
        string = ConfirmBy[ messagesToString[ messages, "MessageTemplate" -> None ], StringQ, "String" ];

        $contextPrompt   = processContextPromptString @ string;
        $selectionPrompt = extractSelectionPrompt @ string;

        $lastContextPrompt   = $contextPrompt;
        $lastSelectionPrompt = $selectionPrompt;

        nbCtx = ConfirmBy[ applyNotebookContextTemplate @ string, StringQ, "NotebookContext" ];

        (* FIXME: pass $selectionPrompt instead of extracting again: *)
        postProcessNotebookContextString[ nbCtx, string ]
    ],
    throwInternalFailure
];

getContextFromSelection0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*countImageTokensQ*)
countImageTokensQ // beginDefinition;
countImageTokensQ[ settings_ ] := countImageTokensQ[ settings, allowedMultimodalRoles @ settings ];
countImageTokensQ[ settings_, All ] := True;
countImageTokensQ[ settings_, "System" ] := True;
countImageTokensQ[ settings_, { ___, "System", ___ } ] := True;
countImageTokensQ[ settings_, roles_ ] := False;
countImageTokensQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNotebookMetadataString*)
getNotebookMetadataString // beginDefinition;

getNotebookMetadataString[ nbo_NotebookObject ] := Enclose[
    ConfirmBy[ getNotebookMetadataString0 @ notebookInformation @ nbo, StringQ, "Metadata" ],
    throwInternalFailure
];

getNotebookMetadataString // endDefinition;


getNotebookMetadataString0 // beginDefinition;

getNotebookMetadataString0[ info_Association ] := Enclose[
    Module[ { modified, date, dateString, modificationInfo, nbo, nboString },

        modified = TrueQ @ info[ "ModifiedInMemory" ];
        date     = info[ "MemoryModificationTime" ];

        dateString = If[ modified && DateObjectQ @ date,
                         ConfirmBy[ DateString @ date <> " (" <> relativeTimeString @ date <> ")", StringQ, "Date" ],
                         Missing[ ]
                     ];

        modificationInfo = DeleteMissing @ <| "ModifiedInMemory" -> modified, "MemoryModificationTime" -> dateString |>;

        nbo = ConfirmMatch[ info[ "NotebookObject" ], _NotebookObject, "NotebookObject" ];

        nboString = ToString[ nbo, InputForm ] <> " (Use this to reference the user's notebook in the evaluator tool)";

        StringRiffle[
            KeyValueMap[
                ToString[ #1 ] <> ": " <> ToString[ #2 ] &,
                Association[
                    "NotebookObject" -> nboString,
                    KeyTake[ info, { "WindowTitle", "FileName" } ],
                    modificationInfo
                ]
            ],
            "\n"
        ]
    ],
    throwInternalFailure
];

getNotebookMetadataString0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downScaledSettings*)
downScaledSettings // beginDefinition;

downScaledSettings[ settings_Association ] := <|
    settings,
    Floor[ $notebookContextLimitScale * KeyTake[ settings, $downScaledSettings ] ]
|>;

downScaledSettings // endDefinition;

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
(*postProcessNotebookContextString*)
postProcessNotebookContextString // beginDefinition;

postProcessNotebookContextString[ prompt_String, string_String ] /; ! $notebookInstructionsPrompt :=
    prompt;

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

applyNotebookContextTemplate[ string_String ] /; ! $notebookInstructionsPrompt :=
    string;

applyNotebookContextTemplate[ string_String ] :=
    applyNotebookContextTemplate[ string, $currentSelectionIndicator ];

applyNotebookContextTemplate[ string_String, { before_String, after_String } ] :=
    applyNotebookContextTemplate[ string, before <> "..." <> after ];

applyNotebookContextTemplate[ string_String, indicator_String ] :=
    With[ { meta = $notebookMetadataString },
        TemplateApply[
            $notebookContextTemplate,
            <|
                "SelectionIndicator" -> indicator,
                "NotebookContent"    -> string,
                "NotebookMetadata"   -> If[ StringQ @ meta, "\n"<>meta<>"\n", "" ]
            |>
        ]
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
    { { beforeCells___Cell }, { }, { afterCells___Cell } },
    { before_String, after_String }
] := {
    beforeCells,
    Cell @ Verbatim[ before<>after ],
    afterCells
};

insertSelectionIndicator[
    { { beforeCells___Cell }, { selectedCells__Cell }, { afterCells___Cell } },
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
getUserNotebook[ ] := FirstCase[ getUserNotebooks[ ], _NotebookObject, None ];
getUserNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getUserNotebooks*)
getUserNotebooks // beginDefinition;

getUserNotebooks[ ] := Enclose[
    Cases[
        ConfirmMatch[ SourceNotebookObjectInformation[ ], { ___Association }, "NotebookInformation" ],
        KeyValuePattern @ { "Included" -> True, "NotebookObject" -> nbo_NotebookObject } :> nbo
    ],
    throwInternalFailure
];

getUserNotebooks // endDefinition;

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
fullSelection[ RawData[ s_String ] ] := RawData @ StringJoin[ $leftSelectionIndicator, s, $rightSelectionIndicator ];
fullSelection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
