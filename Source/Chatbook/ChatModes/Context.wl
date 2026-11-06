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
(* The notebook context and NotebookReader pages are limited as if MaxContextTokens was at most this, so that they don't
   grow with larger chat budgets (e.g. the Notebook Assistant's): *)
$maxNotebookContextTokens   = 2^15;
$maxContextImages           = 5;
$contextPrompt              = None;
$selectionPrompt            = None;
$contextImages              = { };
$sidebarSelectionContext    = None;
$includeRelativeTimes       = True;
$notebookReaderPageSize     = 50;

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
(* ::Subsection::Closed:: *)
(*includedNotebookQ*)
includedNotebookQ // beginDefinition;

(* Gives True if nbo would be "Included" in SourceNotebookObjectInformation[ ], without getting info for other
   notebooks: *)
includedNotebookQ[ nbo_NotebookObject ] :=
    MatchQ[ notebookInformation @ { nbo }, { info_Association /; exclusionReason @ info === None } ];

includedNotebookQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveFocusedNotebook*)
resolveFocusedNotebook // beginDefinition;

resolveFocusedNotebook[ focused_ ] :=
    Module[ { info },
        If[ notebookObjectQ @ focused,
            info = notebookInformation @ focused;
            If[ MatchQ[ info, _Association ] && exclusionReason @ info === None,
                Return @ { focused, info }
            ]
        ];
        getUserNotebookInformation[ ]
    ];

resolveFocusedNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*contextNotebook*)
(* Gives { notebook, info } for the user's notebook that notebook context is taken from: the focused notebook in
   workspace chats, otherwise the notebook that contains the chat (e.g. the notebook with the sidebar): *)
contextNotebook // beginDefinition;
contextNotebook[ settings_Association ] /; TrueQ @ $WorkspaceChat := resolveFocusedNotebook @ settings[ "FocusedNotebook" ];
contextNotebook[ settings_Association ] := { $evaluationNotebook, Automatic };
contextNotebook // endDefinition;

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
        withNotebookContextBudget @ getContextFromSelection0[
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
(*getSidebarPrompt*)
getSidebarPrompt // beginDefinition;

getSidebarPrompt[ settings_Association ] :=
    If[ TrueQ @ $SidebarChat && TrueQ @ settings[ "AllowSelectionContext" ],
        Block[ { $includeCellXML = TrueQ @ $notebookEditorEnabled },
            getContextFromSelection[ $evaluationNotebook, settings ]
        ] // LogChatTiming[ "GetWorkspacePrompt" ],
        None
    ];

getSidebarPrompt // endDefinition;

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
    Module[ { userNotebook, info },
        { userNotebook, info } = contextNotebook @ settings;
        getContextFromSelection[ chatNB, userNotebook, info, settings, opts ]
    ];

getContextFromSelection[ _NotebookObject, None, _Association, OptionsPattern[ ] ] :=
    None;

getContextFromSelection[ chatNB_, nbo_NotebookObject, settings_Association, opts: OptionsPattern[ ] ] :=
    getContextFromSelection[ chatNB, nbo, Automatic, settings, opts ];

getContextFromSelection[ _, None, _, _Association, OptionsPattern[ ] ] :=
    None;

getContextFromSelection[
    _,
    nbo_NotebookObject,
    info: (Automatic | _Association),
    settings0_Association,
    OptionsPattern[ ]
] := Enclose[
    Catch @ Block[
        {
            $notebookInstructionsPrompt = OptionValue[ "NotebookInstructionsPrompt" ],
            $maxCellsBeforeSelection    = OptionValue[ "MaxCellsBeforeSelection"    ],
            $maxCellsAfterSelection     = OptionValue[ "MaxCellsAfterSelection"     ],
            $notebookMetadataString     = getNotebookMetadataString[ nbo, info ]
        },
        Module[ { settings, selectionData, string },
            settings = ConfirmBy[ downScaledSettings @ settings0, AssociationQ, "Settings" ];

            selectionData = ConfirmMatch[
                LogChatTiming @ selectContextCells @ nbo,
                _Association|None,
                "SelectionData"
            ];

            If[ selectionData === None, Throw @ None ];

            string = ConfirmBy[
                withNotebookContextBudget @ getContextFromSelection0[ selectionData, settings ],
                StringQ,
                "Context"
            ];

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

getContextFromSelection0[ selectionData_Association, settings0_ ] := Enclose[
    Catch @ Module[
        {
            images, settings, cellObjects, cells, len1, len2, before, selected, after, marked, messages, string,
            nbCtx
        },

        images   = contextImagesAllowedQ @ settings0;
        settings = <| settings0, "Multimodal" -> images |>;

        cellObjects = ConfirmMatch[ Flatten @ Values @ selectionData, { ___CellObject }, "CellObjects" ];
        cells = ConfirmMatch[ LogChatTiming @ notebookRead @ cellObjects, { ___Cell }, "Cells" ];

        len1 = Length @ ConfirmMatch[ selectionData[ "Before"   ], { ___CellObject }, "BeforeLength"   ];
        len2 = Length @ ConfirmMatch[ selectionData[ "Selected" ], { ___CellObject }, "SelectedLength" ];

        before   = ConfirmMatch[ cells[[ 1 ;; len1 ]]              , { ___Cell }, "BeforeCells"   ];
        selected = ConfirmMatch[ cells[[ len1 + 1 ;; len1 + len2 ]], { ___Cell }, "SelectedCells" ];
        after    = ConfirmMatch[ cells[[ len1 + len2 + 1 ;; All ]] , { ___Cell }, "AfterCells"    ];

        { before, selected, after } = DeleteCases[ #, _? chatExcludedQ ] & /@ { before, selected, after };

        marked = ConfirmMatch[ insertSelectionIndicator @ { before, selected, after }, { ___Cell }, "Marked" ];
        messages = ConfirmMatch[
            Block[ { $multimodalMessages = images, $countImageTokens = images },
                LogChatTiming @ makeChatMessages[ settings, marked, False ]
            ],
            { ___Association },
            "Messages"
        ];

        string = ConfirmBy[ messagesToString[ messages, "MessageTemplate" -> None ], StringQ, "String" ];

        $contextImages = ConfirmMatch[
            If[ images, selectContextImages[ messages, string ], { } ],
            { ___List },
            "ContextImages"
        ];

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
(*contextImagesAllowedQ*)
contextImagesAllowedQ // beginDefinition;

contextImagesAllowedQ[ settings_Association ] :=
    TrueQ @ settings[ "Multimodal" ] && contextImagesAllowedQ @ allowedMultimodalRoles @ settings;

contextImagesAllowedQ[ All ] := True;
contextImagesAllowedQ[ roles_List ] := MemberQ[ roles, "User" ];
contextImagesAllowedQ[ _ ] := False;

contextImagesAllowedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*contextImageParts*)
contextImageParts // beginDefinition;

contextImageParts[ messages_List ] := DeleteDuplicatesBy[
    Flatten[ contextImageParts /@ messages, 1 ],
    Replace[ #, { { link_String, _ } :> link, { None, img_ } :> img } ] &
];

contextImageParts[ KeyValuePattern[ "Content" -> content_List ] ] := SequenceCases[
    content,
    { text: Repeated[ $$contextTextPart, { 0, 1 } ], img: KeyValuePattern[ "Type" -> "Image" ] } :>
        { imageLink @ text, img }
];

contextImageParts[ _ ] :=
    { };

contextImageParts // endDefinition;

$$contextTextPart = _String | KeyValuePattern @ { "Type" -> "Text", "Data" -> _String };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectContextImages*)
selectContextImages // beginDefinition;

selectContextImages[ messages_List, context_String ] :=
    Module[ { parts, selection, links, positions, indexed },
        parts = contextImageParts @ messages;
        If[ Length @ parts <= $maxContextImages, Return @ parts ];

        selection = First[
            StringPosition[
                context,
                Shortest[ $leftSelectionIndicator ~~ ___ ~~ $rightSelectionIndicator ],
                1
            ],
            Missing[ "NotFound" ]
        ];
        If[ MissingQ @ selection, Return @ Take[ parts, $maxContextImages ] ];

        links = DeleteDuplicates @ Cases[ parts, { link_String, _ } :> link ];
        positions = If[ links === { },
            <| |>,
            GroupBy[ StringPosition[ context, Alternatives @@ links ], StringTake[ context, # ] & ]
        ];
        indexed = MapIndexed[
            { #1, First @ #2, contextImageDistance[ #1, selection, positions ] } &,
            parts
        ];
        First /@ Take[ SortBy[ indexed, { Last, #[[ 2 ]] & } ], $maxContextImages ]
    ];

selectContextImages // endDefinition;


contextImageDistance // beginDefinition;

contextImageDistance[ { link_String, _ }, selection_, positions_Association ] :=
    With[ { found = Lookup[ positions, link, { } ] },
        If[ found === { }, Infinity, Min[ intervalDistance[ #, selection ] & /@ found ] ]
    ];

contextImageDistance[ _, _, _Association ] :=
    Infinity;

contextImageDistance // endDefinition;


intervalDistance // beginDefinition;
intervalDistance[ { a1_Integer, a2_Integer }, { b1_Integer, b2_Integer } ] :=
    Max[ 0, Max[ a1, b1 ] - Min[ a2, b2 ] - 1 ];
intervalDistance // endDefinition;


imageLink // beginDefinition;

imageLink[ ] := None;

imageLink[ KeyValuePattern[ "Data" -> text_String ] ] := imageLink @ text;

imageLink[ text_String ] := Last[
    StringCases[ text, Shortest[ "![" ~~ Except[ "\n" ]... ~~ "](" ~~ Except[ ")" | "\n" ].. ~~ ")" ] ],
    None
];

imageLink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNotebookMetadataString*)
getNotebookMetadataString // beginDefinition;

getNotebookMetadataString[ nbo_NotebookObject ] :=
    getNotebookMetadataString[ nbo, Automatic ];

getNotebookMetadataString[ nbo_NotebookObject, Automatic ] :=
    getNotebookMetadataString[ nbo, notebookInformation @ nbo ];

getNotebookMetadataString[ _NotebookObject, info_Association ] := Enclose[
    ConfirmBy[ getNotebookMetadataString0 @ info, StringQ, "Metadata" ],
    throwInternalFailure
];

getNotebookMetadataString // endDefinition;


getNotebookMetadataString0 // beginDefinition;

getNotebookMetadataString0[ info_Association ] := Enclose[
    Module[ { modified, date, dateString, modificationInfo, nbo, nboString },

        modified = TrueQ @ info[ "ModifiedInMemory" ];
        date     = info[ "MemoryModificationTime" ];

        (* Relative times are left out where they would go stale, e.g. in NotebookReader tool results: *)
        dateString = If[ modified && DateObjectQ @ date,
                         ConfirmBy[
                             If[ TrueQ @ $includeRelativeTimes,
                                 DateString @ date <> " (" <> relativeTimeString @ date <> ")",
                                 DateString @ date
                             ],
                             StringQ,
                             "Date"
                         ],
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
    Floor[ $notebookContextLimitScale * KeyTake[ notebookContextLimits @ settings, $downScaledSettings ] ]
|>;

downScaledSettings // endDefinition;


notebookContextLimits // beginDefinition;

notebookContextLimits[ settings: KeyValuePattern[ "MaxContextTokens" -> n_? NumberQ ] ] :=
    <| settings, "MaxContextTokens" -> Min[ n, $maxNotebookContextTokens ] |>;

notebookContextLimits[ settings_Association ] := settings;

notebookContextLimits // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*withNotebookContextBudget*)
(* In a chat, the notebook context is serialized with what's left of the chat's token budget, but no more than
   $maxNotebookContextTokens: *)
withNotebookContextBudget // beginDefinition;
withNotebookContextBudget // Attributes = { HoldFirst };
withNotebookContextBudget[ eval_ ] := Block[ { $tokenBudget = Min[ $tokenBudget, $maxNotebookContextTokens ] }, eval ];
withNotebookContextBudget // endDefinition;

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

(* No selection markers, e.g. when the NotebookReader tool reads the notebook from the beginning: *)
insertSelectionIndicator[ { before_List, selected_List, after_List }, None ] :=
    Join[ before, selected, after ];

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

selectContextCells[ nbo_NotebookObject ] /; TrueQ @ $SidebarChat :=
    If[ savedSelectionContextQ @ $sidebarSelectionContext,
        removeMissingContextCells[ nbo, $sidebarSelectionContext ],
        With[ { context = selectSidebarContextCells @ nbo },
            If[ TrueQ @ $chatState, $sidebarSelectionContext = context ];
            context
        ]
    ];

selectContextCells[ nbo_NotebookObject ] :=
    selectContextCells @ Cells @ nbo;

selectContextCells[ { } ] :=
    None;

selectContextCells[ cells: { __CellObject } ] :=
    selectContextCells @ cellInformation @ cells;

selectContextCells[ info: { __Association } ] := Module[ { cursor, i, n },
    cursor = Lookup[ info, "CursorPosition", None ];
    Which[
        First @ cursor === "AboveCell",
            selectContextCells0 @ <| "Before" -> { }, "Selected" -> { }, "After" -> info |>,

        IntegerQ[ i = firstCursorIndex[ cursor, "BelowCell" ] ],
            selectContextCells0 @ <| "Before" -> Take[ info, i ], "Selected" -> { }, "After" -> Drop[ info, i ] |>,

        IntegerQ[ i = firstCursorIndex[ cursor, _List ] ],
            selectContextCells0 @ <|
                "Before"   -> Take[ info, i - 1 ],
                "Selected" -> { info[[ i ]] },
                "After"    -> Drop[ info, i ]
            |>,

        IntegerQ[ i = firstCursorIndex[ cursor, "CellBracket" ] ],
            n = LengthWhile[ Drop[ cursor, i - 1 ], # === "CellBracket" & ];
            selectContextCells0 @ <|
                "Before"   -> Take[ info, i - 1 ],
                "Selected" -> Take[ info, { i, i + n - 1 } ],
                "After"    -> Drop[ info, i + n - 1 ]
            |>,

        MatchQ[ cursor, { None... } ],
            selectContextCells0 @ <| "Before" -> info, "Selected" -> { }, "After" -> { } |>,

        True,
            throwInternalFailure @ selectContextCells @ info
    ]
];

selectContextCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*savedSelectionContextQ*)
savedSelectionContextQ // beginDefinition;
savedSelectionContextQ[ KeyValuePattern @ { "Before" -> _List, "Selected" -> _List, "After" -> _List } ] := True;
savedSelectionContextQ[ _ ] := False;
savedSelectionContextQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeMissingContextCells*)
removeMissingContextCells // beginDefinition;

removeMissingContextCells[ nbo_NotebookObject, context_Association ] :=
    With[ { existing = AssociationThread[ Cells @ nbo -> True ] },
        Select[ Lookup[ existing, #, False ] & ] /@ context
    ];

removeMissingContextCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectSidebarContextCells*)
selectSidebarContextCells // beginDefinition;

selectSidebarContextCells[ nbo_NotebookObject ] :=
Module[
    {
        sidebarCell, selectionAtTimeOfInputConfirmation, allCells, firstBeforeCell, selectedCells, firstAfterCell,
        currentSelections, context
    },
    (* The TaggingRules of the sidebar cell contains the selection objects at the time the sidebar input field content was confirmed *)
    sidebarCell = sidebarCellObject @ nbo;
    selectionAtTimeOfInputConfirmation = CurrentValue[ sidebarCell, { TaggingRules, "CurrentSelections" } ];
    currentSelections = FE`Evaluate @ FEPrivate`GetCurrentSelections @ nbo;

    allCells = Cells @ nbo;
    If[ Not @ AssociationQ @ selectionAtTimeOfInputConfirmation,
        Return @ boundedContextCells @ <| "Before" -> allCells, "Selected" -> { }, "After" -> { } |>
    ];

    WithCleanup[
        With[ { s = selectionAtTimeOfInputConfirmation[[2]] }, (* FIXME use Lookup instead of part to get remnant selection *)
            FE`Evaluate @ FEPrivate`SetCurrentSelections @ Association[ "ActiveSelection" -> s ]
        ];
        selectedCells   = SelectedCells @ nbo;
        firstBeforeCell = PreviousCell @ NotebookSelection @ nbo;
        firstAfterCell  = NextCell @ NotebookSelection @ nbo;
        ,
        With[ { s1 = currentSelections, s2 = selectionAtTimeOfInputConfirmation },
            FE`Evaluate @ FEPrivate`SetCurrentSelections @ s1;
            FE`Evaluate @ FEPrivate`ReleaseSelectionObjects @ s1;
            FE`Evaluate @ FEPrivate`ReleaseSelectionObjects @ s2;
            setCurrentValue[ sidebarCell, { TaggingRules, "CurrentSelections" }, Inherited ]
        ]
    ];

    (* It is possible that there is no main notebook selection: default to all cells as "Before" *)
    context = If[ firstBeforeCell === None && firstAfterCell === None && selectedCells === { },
        <| "Before" -> allCells, "Selected" -> { }, "After" -> { } |>,
        <|
            "Before" -> With[ { p = FirstPosition[ allCells, firstBeforeCell, None ] },
                If[ p =!= None, Extract[ allCells, { ;; p[[1]] } ], { } ] ],
            "Selected" -> selectedCells,
            "After" -> With[ { p = FirstPosition[ allCells, firstAfterCell, None ] },
                If[ p =!= None, Extract[ allCells, { p[[1]] ;; } ], { } ] ]
        |>
    ];
    boundedContextCells @ context
];

selectSidebarContextCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*boundedContextCells*)
boundedContextCells // beginDefinition;

boundedContextCells[ KeyValuePattern @ {
    "Before"   -> before_List,
    "Selected" -> selected_List,
    "After"    -> after_List
} ] := <|
    "Before"   -> Reverse @ takeIncludedCells[ Reverse @ before, $maxCellsBeforeSelection ],
    "Selected" -> includedCellObjects @ selected,
    "After"    -> takeIncludedCells[ after, $maxCellsAfterSelection ]
|>;

boundedContextCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*takeIncludedCells*)
takeIncludedCells // beginDefinition;

takeIncludedCells[ cells: { ___CellObject }, n: _Integer? NonNegative | Infinity ] :=
    Module[ { taken, rest, chunk },
        taken = { };
        rest  = cells;
        While[ Length @ taken < n && rest =!= { },
            chunk = Take[ rest, UpTo[ n ] ];
            rest  = Drop[ rest, Length @ chunk ];
            taken = Join[ taken, includedCellObjects @ chunk ]
        ];
        Take[ taken, UpTo[ n ] ]
    ];

takeIncludedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*includedCellObjects*)
includedCellObjects // beginDefinition;

includedCellObjects[ { } ] := { };

includedCellObjects[ cells: { __CellObject } ] :=
    Cases[ filterChatCells @ cellInformation @ cells, KeyValuePattern[ "CellObject" -> cell_CellObject ] :> cell ];

includedCellObjects // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectContextCells0*)
selectContextCells0 // beginDefinition;

selectContextCells0[ KeyValuePattern @ {
    "Before"   -> before0_List,
    "Selected" -> current_List,
    "After"    -> after0_List
} ] :=
    Module[ { before, after },
        before = Reverse @ Take[ Reverse @ filterChatCells @ before0, UpTo[ $maxCellsBeforeSelection ] ];
        after = Take[ filterChatCells @ after0, UpTo[ $maxCellsAfterSelection ] ];
        Map[
            Cases[ KeyValuePattern[ "CellObject" -> cell_CellObject ] :> cell ],
            <| "Before" -> before, "Selected" -> filterChatCells @ current, "After" -> after |>
        ]
    ];

selectContextCells0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*firstCursorIndex*)
firstCursorIndex // beginDefinition;
firstCursorIndex[ cursor_List, patt_ ] := First @ FirstPosition[ cursor, patt, { None }, { 1 }, Heads -> False ];
firstCursorIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getUserNotebook*)
getUserNotebook // beginDefinition;
getUserNotebook[ ] := FirstCase[ getUserNotebooks[ ], _NotebookObject, None ];
getUserNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getUserNotebookInformation*)
getUserNotebookInformation // beginDefinition;

getUserNotebookInformation[ ] := Enclose[
    FirstCase[
        ConfirmMatch[ SourceNotebookObjectInformation[ ], { ___Association }, "NotebookInformation" ],
        info: KeyValuePattern @ { "Included" -> True, "NotebookObject" -> nbo_NotebookObject } :> { nbo, info },
        { None, None }
    ],
    throwInternalFailure
];

getUserNotebookInformation // endDefinition;

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
(*Notebook Context with Prompt Cache Optimization*)
(* With prompt cache optimization, the notebook context of sidebar and workspace chats is not added to the system prompt
   of every request. Instead, it is sent once per conversation with the turn messages of the first input (see
   addTurnMessages in PromptCache.wl). Later inputs only get a short notice when the user's selection moved or the
   notebook changed since then, and the AI can read the current content with the NotebookReader tool if it needs to.
   Without the tool, the full context is sent again instead.

   The context message and the notices record the state of the notebook they describe ("NotebookContextState"), so the
   state the AI last heard about is the one in the latest of these messages in the history. If the history has no
   notebook context (e.g. because its turn records are gone after restarting the kernel), the full context is sent
   again. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Configuration*)
$notebookContextImagesLabel = "\
[Original images for the MarkdownImageBoxes in the notebook content above. Each image follows its markdown link.]";

$notebookChangeHintTemplate = StringTemplate[ "\
<system-hint>
Since your last response, `1`, so the notebook content you saw earlier may be out of date. `2`
</system-hint>" ];

(* The content hash also changes with some notebook options (e.g. the window size), so "Content" is worded neutrally: *)
$notebookChangeDescriptions = <|
    "Notebook"  -> "the user switched to a different notebook (`1`)",
    "Selection" -> "the user moved their selection in the notebook",
    "Content"   -> "the notebook has changed"
|>;

(* Users often refer to their selection without saying so (e.g. "And this one?"), so that case is spelled out: *)
$notebookReaderHint = StringTemplate[ "\
If the user's message refers to the notebook or to something they selected (for example \"this\", \"this cell\" or \
\"here\"), use the `1` tool to see its current state before you respond. Otherwise, ignore this notice and don't \
read the notebook." ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookContextTurnMessages*)
notebookContextTurnMessages // beginDefinition;

notebookContextTurnMessages[ settings_Association, messages_List ] /;
    TrueQ[ ($WorkspaceChat || $SidebarChat) && settings[ "AllowSelectionContext" ] ] :=
        LogChatTiming[ notebookContextTurnMessages0[ settings, messages ], "NotebookContextTurnMessages" ];

notebookContextTurnMessages[ settings_, messages_ ] :=
    { };

notebookContextTurnMessages // endDefinition;


notebookContextTurnMessages0 // beginDefinition;

notebookContextTurnMessages0[ settings_Association, messages_List ] := Enclose[
    Catch @ Module[ { data, previous, state, changes },
        data = ConfirmMatch[ notebookSelectionData @ settings, _Association|None, "Data" ];
        If[ data === None, Throw @ { } ];

        If[ ! MemberQ[ messages, KeyValuePattern[ "NotebookContext" -> True ] ],
            Throw @ fullNotebookContextMessages[ settings, data ]
        ];

        previous = Last[ Cases[ messages, KeyValuePattern[ "NotebookContextState" -> s_Association ] :> s ], None ];
        If[ ! AssociationQ @ previous, Throw @ { } ];

        changes = notebookContextChanges[ previous[ "Fingerprint" ], notebookFingerprint @ data ];

        If[ changes === { },
            (* Prompt generators use these for searches (see insertContextPrompt in VectorDatabases.wl): *)
            $contextPrompt   = previous[ "ContextPrompt"   ];
            $selectionPrompt = previous[ "SelectionPrompt" ];
            Throw @ { }
        ];

        (* Without the NotebookReader tool, the AI can't see the changes otherwise: *)
        If[ ! toolSelectedQ[ "NotebookReader" ], Throw @ fullNotebookContextMessages[ settings, data ] ];

        (* Update the prompts for searches with a smaller context around the current selection. It is not sent, so the
           base prompt components it needs are not kept: *)
        withoutCollectingBasePrompts @ contextFromSelectionData[
            data[ "Notebook" ],
            data[ "Info" ],
            selectionNeighborhood @ data,
            <| settings, "Multimodal" -> False |>
        ];

        state = ConfirmBy[ notebookContextState @ data, AssociationQ, "State" ];
        { notebookChangeHint[ changes, data, state ] }
    ],
    throwInternalFailure
];

notebookContextTurnMessages0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*contextFromSelectionData*)
(* Like getContextFromSelection, but for selection data that has already been determined: *)
contextFromSelectionData // beginDefinition;

contextFromSelectionData[ nbo_NotebookObject, info_, selectionData_Association, settings0_Association ] := Enclose[
    Block[
        {
            $includeCellXML         = TrueQ @ $notebookEditorEnabled,
            (* The context is sent again unchanged in later requests, where relative times would be out of date: *)
            $includeRelativeTimes   = False,
            $notebookMetadataString
        },
        (* Set here, since Block initializers are evaluated before $includeRelativeTimes is changed: *)
        $notebookMetadataString = getNotebookMetadataString[ nbo, info ];
        Module[ { settings, string },
            settings = ConfirmBy[ downScaledSettings @ settings0, AssociationQ, "Settings" ];
            string = ConfirmBy[
                withNotebookContextBudget @ getContextFromSelection0[ selectionData, settings ],
                StringQ,
                "Context"
            ];
            ConfirmBy[ mergeCodeBlocks @ string, StringQ, "Merged" ]
        ]
    ],
    throwInternalFailure
];

contextFromSelectionData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookSelectionData*)
notebookSelectionData // beginDefinition;

notebookSelectionData[ settings_Association ] := Enclose[
    Module[ { nbo, info, selectionData },
        { nbo, info } = contextNotebook @ settings;
        selectionData = If[ MatchQ[ nbo, _NotebookObject ], LogChatTiming @ selectContextCells @ nbo, None ];
        If[ AssociationQ @ selectionData,
            <| "Notebook" -> nbo, "Info" -> info, "SelectionData" -> selectionData |>,
            None
        ]
    ],
    throwInternalFailure
];

notebookSelectionData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fullNotebookContextMessages*)
fullNotebookContextMessages // beginDefinition;

fullNotebookContextMessages[ settings_, data_Association ] := Enclose[
    Block[ { $contextImages = { } },
        Module[ { context, images },
            context = ConfirmBy[
                contextFromSelectionData[ data[ "Notebook" ], data[ "Info" ], data[ "SelectionData" ], settings ],
                StringQ,
                "Context"
            ];
            images = ConfirmMatch[ $contextImages, { ___List }, "Images" ];
            Flatten @ {
                <|
                    "Role"                 -> "System",
                    "Content"              -> context,
                    "Temporary"            -> True,
                    "PromptCache"          -> True,
                    "NotebookContext"      -> True,
                    "NotebookContextState" -> ConfirmBy[ notebookContextState @ data, AssociationQ, "State" ]
                |>,
                If[ images === { }, Nothing, notebookContextImageMessage @ images ]
            }
        ]
    ],
    throwInternalFailure
];

fullNotebookContextMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookContextImageMessage*)
(* Images can't be part of system messages, so they are sent in a separate user message: *)
notebookContextImageMessage // beginDefinition;

notebookContextImageMessage[ images_List ] := <|
    "Role"            -> "User",
    "Content"         -> Flatten @ {
        <| "Type" -> "Text", "Data" -> $notebookContextImagesLabel |>,
        Replace[
            images,
            {
                { link_String, img_ } :> { <| "Type" -> "Text", "Data" -> "\n" <> link |>, img },
                { _, img_ } :> img
            },
            { 1 }
        ]
    },
    "Temporary"       -> True,
    "PromptCache"     -> True,
    "NotebookContext" -> True
|>;

notebookContextImageMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookContextState*)
(* What a context message or a notice tells the AI about the notebook, and the prompts used for searches with it: *)
notebookContextState // beginDefinition;

notebookContextState[ data_Association ] := <|
    "Fingerprint"     -> notebookFingerprint @ data,
    "ContextPrompt"   -> $contextPrompt,
    "SelectionPrompt" -> $selectionPrompt
|>;

notebookContextState // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookFingerprint*)
(* Cheap values that tell whether the user switched notebooks, moved their selection, or changed the notebook: *)
notebookFingerprint // beginDefinition;

notebookFingerprint[ KeyValuePattern @ { "Notebook" -> nbo_NotebookObject, "SelectionData" -> selection_Association } ] := <|
    "Notebook"  -> nbo,
    "Content"   -> notebookContentHash @ nbo,
    "Selection" -> {
        selection[ "Selected" ],
        Last[ selection[ "Before" ], None ],
        First[ selection[ "After" ], None ],
        Replace[ selection[ "Selected" ], { { cell_CellObject } :> cellInformation[ cell, { "CursorPosition" } ], _ -> None } ]
    }
|>;

notebookFingerprint // endDefinition;


notebookContentHash // beginDefinition;

(* NOTE: this also changes with some notebook options, e.g. when the window is resized: *)
notebookContentHash[ nbo_NotebookObject ] :=
    Replace[ FrontEndExecute @ FrontEnd`CryptoHash @ nbo, { KeyValuePattern[ "DirtiableContentsHash" -> h_ ] :> h, _ -> None } ];

notebookContentHash // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookContextChanges*)
notebookContextChanges // beginDefinition;

notebookContextChanges[ old_Association, new_Association ] :=
    If[ old[ "Notebook" ] =!= new[ "Notebook" ],
        { "Notebook" },
        Select[ { "Selection", "Content" }, old[ # ] =!= new[ # ] & ]
    ];

notebookContextChanges[ _, _ ] := { };

notebookContextChanges // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookChangeHint*)
notebookChangeHint // beginDefinition;

notebookChangeHint[ changes_List, data_Association, state_Association ] := <|
    "Role"                 -> "System",
    "Content"              -> TemplateApply[
        $notebookChangeHintTemplate,
        {
            StringRiffle[
                Replace[
                    Lookup[ $notebookChangeDescriptions, changes ],
                    s_String :> TemplateApply[ s, { notebookTitle @ data } ],
                    { 1 }
                ],
                " and "
            ],
            TemplateApply[ $notebookReaderHint, { catalogToolName[ "NotebookReader" ] } ]
        }
    ],
    "Temporary"            -> True,
    "PromptCache"          -> True,
    "NotebookContextState" -> state
|>;

notebookChangeHint // endDefinition;


notebookTitle // beginDefinition;
notebookTitle[ KeyValuePattern[ "Info" -> KeyValuePattern[ "WindowTitle" -> title_String ] ] ] := "\"" <> title <> "\"";
notebookTitle[ KeyValuePattern[ "Notebook" -> nbo_NotebookObject ] ] := ToString[ nbo, InputForm ];
notebookTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectionNeighborhood*)
(* A few cells around the selection, used to update the prompts for searches when the selection or content changed: *)
selectionNeighborhood // beginDefinition;

selectionNeighborhood[ KeyValuePattern[ "SelectionData" -> selection_Association ] ] := <|
    "Before"   -> Take[ selection[ "Before" ], -Min[ 3, Length @ selection[ "Before" ] ] ],
    "Selected" -> selection[ "Selected" ],
    "After"    -> Take[ selection[ "After" ], UpTo[ 1 ] ]
|>;

selectionNeighborhood // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*NotebookReader Tool*)
$noUserNotebookMessage = "There is no notebook to read: the user does not currently have a notebook open.";
$emptyUserNotebookMessage = "The user's notebook is empty.";

$notebookReaderPageTemplate = StringTemplate[ "\
Below is the content of the user's notebook, cells %%First%% to %%Last%% of %%Total%%.

<notebook>
<metadata>
%%NotebookMetadata%%
</metadata>
<content>
%%NotebookContent%%
</content>
</notebook>

%%Paging%%", Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readUserNotebook*)
(* Gives the current content of the user's notebook for the NotebookReader tool, from the same notebook and in the same
   format as the automatic notebook context: *)
readUserNotebook // beginDefinition;

readUserNotebook[ settings_Association, scope: "selection"|"all", offset_Integer? Positive ] :=
    readUserNotebook[ settings, scope, offset, contextNotebook @ settings ];

readUserNotebook[ settings_, scope_, offset_, { nbo_NotebookObject, info_ } ] :=
    Block[
        {
            (* Leave the chat's own notebook context state as it is: *)
            $contextImages, $contextPrompt, $selectionPrompt, $lastContextPrompt, $lastSelectionPrompt,
            (* Use the same format as getSidebarPrompt and getWorkspacePrompt: *)
            $includeCellXML = TrueQ @ $notebookEditorEnabled,
            $includeRelativeTimes = False
        },
        (* During a chat, serializing cells would otherwise use (and use up) what's left of the chat's token budget, so
           the size of the result would depend on how long the chat is: *)
        withTokenBudget[ downScaledSettings @ settings, readUserNotebook0[ nbo, info, settings, scope, offset ] ]
    ];

readUserNotebook[ _, _, _, _ ] :=
    $noUserNotebookMessage;

readUserNotebook // endDefinition;


readUserNotebook0 // beginDefinition;

(* The cells around the user's selection, as given by the automatic notebook context: *)
readUserNotebook0[ nbo_, info_, settings_, "selection", _ ] :=
    Replace[ getContextFromSelection[ None, nbo, info, settings ], None -> $emptyUserNotebookMessage ];

(* A page of cells from the notebook, without selection markers: *)
readUserNotebook0[ nbo_, info_, settings_, "all", offset_ ] := Enclose[
    Catch @ Module[ { cells, total, last, content, metadata },

        (* TODO: this reads cell information for every cell, which could be slow in very large notebooks *)
        cells = ConfirmMatch[ includedCellObjects @ Cells @ nbo, { ___CellObject }, "Cells" ];
        total = Length @ cells;

        If[ total === 0, Throw @ $emptyUserNotebookMessage ];
        If[ offset > total,
            Throw @ StringJoin[
                "The user's notebook has ", ToString @ total, " cells. Use an offset from 1 to ", ToString @ total, "."
            ]
        ];

        { content, last } = ConfirmMatch[
            readNotebookPage[
                cells,
                downScaledSettings @ settings,
                offset,
                Min[ total, offset + $notebookReaderPageSize - 1 ]
            ],
            { _String, _Integer },
            "Page"
        ];

        metadata = ConfirmBy[ getNotebookMetadataString[ nbo, info ], StringQ, "Metadata" ];

        TemplateApply[
            $notebookReaderPageTemplate,
            <|
                "First"            -> offset,
                "Last"             -> last,
                "Total"            -> total,
                "NotebookMetadata" -> metadata,
                "NotebookContent"  -> ConfirmBy[ mergeCodeBlocks @ content, StringQ, "Merged" ],
                "Paging"           -> If[ last < total,
                                          "To read the next cells, use scope \"all\" with offset " <>
                                              ToString[ last + 1 ] <> ".",
                                          "This is the end of the notebook."
                                      ]
            |>
        ]
    ],
    throwInternalFailure
];

readUserNotebook0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*readNotebookPage*)
(* Gives { content, last } for the cells from first to at most last. The token budget is spent from the last cell
   backwards, so cells that don't fit are excised from the start of the page, and nothing in the content says so.
   When that happens, the page is read again without as many cells at its end, until nothing is excised. This way the
   page always starts at first and the next offset comes right after the cells that were shown.
   NOTE: each retry serializes the page again. If retries turn out to be slow in practice, the page size could be
   lowered, or pages could be sized by serializing one cell at a time. *)
readNotebookPage // beginDefinition;

readNotebookPage[ cells: { __CellObject }, settings_Association, first_Integer, last_Integer ] := Enclose[
    Module[ { content, excised },
        Block[
            {
                (* Each try starts from the same budget: *)
                $cellStringBudget = $cellStringBudget, $tokenBudget = $tokenBudget, $tokenPressure = $tokenPressure,
                $notebookInstructionsPrompt = False, $currentSelectionIndicator = None, $lastMessageList = None
            },
            content = ConfirmBy[
                getContextFromSelection0[
                    <| "Before" -> cells[[ first ;; last ]], "Selected" -> { }, "After" -> { } |>,
                    settings
                ],
                StringQ,
                "Content"
            ];
            (* makeChatMessages0 sets $lastMessageList: *)
            excised = ConfirmMatch[ excisedCellCount @ $lastMessageList, _Integer, "Excised" ]
        ];
        If[ excised > 0 && last > first,
            readNotebookPage[ cells, settings, first, Max[ first, last - excised ] ],
            { content, last }
        ]
    ],
    throwInternalFailure
];

readNotebookPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*excisedCellCount*)
(* The number of cells excised from the start of a message list, which makeChatMessages0 combines into a leading
   "[n Cells Excised]" system message: *)
excisedCellCount // beginDefinition;

excisedCellCount[ { KeyValuePattern @ { "Role" -> "System", "Content" -> content_String }, ___ } ] := First[
    StringCases[
        content,
        StartOfString ~~ "[" ~~ n: DigitCharacter.. ~~ " Cells Excised]" ~~ EndOfString :> FromDigits @ n
    ],
    0
];

excisedCellCount[ _ ] := 0;

excisedCellCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
