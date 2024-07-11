(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`WorkspaceChat`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"               ];
Needs[ "Wolfram`Chatbook`Common`"        ];
Needs[ "Wolfram`Chatbook`Serialization`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxCellsBeforeSelection = 100;
$maxCellsAfterSelection  = 10;

$currentSelectionIndicator = { "\\["<>"BeginSelection"<>"]", "\\["<>"EndSelection"<>"]" };

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
(*getWorkspacePrompt*)
getWorkspacePrompt // beginDefinition;

getWorkspacePrompt[ settings_Association ] :=
    If[ TrueQ @ $WorkspaceChat,
        getContextFromSelection[ $evaluationNotebook, settings ],
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

getContextFromSelection[ chatNB_NotebookObject, nbo_NotebookObject, settings_Association ] := Enclose[
    Catch @ Module[ { selectionData, cellObjects, cells, len1, len2, before, selected, after, marked, string },

        selectionData = selectContextCells @ nbo;
        cellObjects = ConfirmMatch[ Flatten @ Values @ selectionData, { ___CellObject }, "CellObjects" ];
        cells = ConfirmMatch[ notebookRead @ cellObjects, { ___Cell }, "Cells" ];

        len1 = Length @ ConfirmMatch[ selectionData[ "Before"   ], { ___CellObject }, "BeforeLength"   ];
        len2 = Length @ ConfirmMatch[ selectionData[ "Selected" ], { ___CellObject }, "SelectedLength" ];

        before   = ConfirmMatch[ cells[[ 1 ;; len1 ]]              , { ___Cell }, "BeforeCells"   ];
        selected = ConfirmMatch[ cells[[ len1 + 1 ;; len1 + len2 ]], { ___Cell }, "SelectedCells" ];
        after    = ConfirmMatch[ cells[[ len1 + len2 + 1 ;; All ]] , { ___Cell }, "AfterCells"    ];

        marked = ConfirmMatch[ insertSelectionIndicator @ { before, selected, after }, { ___Cell }, "Marked" ];
        (* FIXME: set appropriate content types and adhere to existing token budgets *)
        string = ConfirmBy[ CellToString[ Notebook @ marked, "ContentTypes" -> { "Text" } ], StringQ, "String" ];
        applyNotebookContextTemplate @ string
    ],
    throwInternalFailure
];

getContextFromSelection // endDefinition;

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

selectContextCells[ cells: { ___CellObject } ] :=
    selectContextCells @ cellInformation @ cells;

selectContextCells[ { a: KeyValuePattern[ "CursorPosition" -> "AboveCell" ], after___ } ] :=
    selectContextCells0 @ <| "Before" -> { }, "Selected" -> { }, "After" -> { after } |>;

selectContextCells[ { before___, a: KeyValuePattern[ "CursorPosition" -> "BelowCell" ], after___ } ] :=
    selectContextCells0 @ <| "Before" -> { before, a }, "Selected" -> { }, "After" -> { after } |>;

selectContextCells[ { before___, a: KeyValuePattern[ "CursorPosition" -> _List ], after___ } ] :=
    selectContextCells0 @ <| "Before" -> { before }, "Selected" -> { a }, "After" -> { after } |>;

selectContextCells[ { before___, a: Longest[ KeyValuePattern[ "CursorPosition" -> "CellBracket" ].. ], after___ } ] :=
    selectContextCells0 @ <| "Before" -> { before }, "Selected" -> { a }, "After" -> { after } |>;

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
(* ::Subsubsection::Closed:: *)
(*includedTagsQ*)
includedTagsQ // beginDefinition;
includedTagsQ[ KeyValuePattern[ "ExcludeFromChat" -> True ] ] := False;
includedTagsQ[ KeyValuePattern[ "WorkspaceChat" -> True ] ] := False;
includedTagsQ[ _ ] := True;
includedTagsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
