(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatHistory`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `accentIncludedCells;
    `chatExcludedQ;
    `extraCellHeight;
    `filterChatCells;
    `getCellsInChatHistory;
    `removeCellAccents;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"              ];
Needs[ "Wolfram`Chatbook`ChatMessages`" ];
Needs[ "Wolfram`Chatbook`Common`"       ];
Needs[ "Wolfram`Chatbook`FrontEnd`"     ];
Needs[ "Wolfram`Chatbook`Settings`"     ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$cellFrameColor = RGBColor[ "#a3c9f2" ];

$validChatHistoryProperties = {
    "CellObjects",
    "Cells",
    "ChatDelimiter",
    "ChatHistoryLength",
    "IncludeHistory",
    "Messages",
    "Settings"
};

$$validChatHistoryProperty  = Alternatives @@ $validChatHistoryProperties;
$$historyProperty           = All | $$validChatHistoryProperty | { $$validChatHistoryProperty... };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetChatHistory*)
GeneralUtilities`SetUsage[ GetChatHistory, "\
GetChatHistory[cell$] gives the list of cells that would be included in the chat history for the \
CellObject specified by cell$.
GetChatHistory[cell$,prop$] gives the specified property.

* The value for prop$ can be any of the following:
| All | all properties returned as an Association |
| \"CellObjects\" | the list of CellObjects that would be included in the chat history |
| \"Cells\" | the list of Cell[$$] expressions that would be included in the chat history |
| \"Messages\" | the chat history as a list of messages |
| \"ChatHistoryLength\" | the max number of cells that would be included in the chat history |
| \"IncludeHistory\" | whether or not chat history apart from the given cell would be included in the chat |
* The default value for prop$ is \"CellObjects\".
* \"IncludeHistory\" and \"ChatHistoryLength\" can be used to determine why the returned list of cells might be limited.\
" ];

GetChatHistory[ cell_CellObject ] :=
    catchMine @ GetChatHistory[ cell, "CellObjects" ];

GetChatHistory[ cell_CellObject, "CellObjects" ] :=
    catchMine @ getCellsInChatHistory @ cell;

GetChatHistory[ cell_CellObject, property: $$historyProperty ] := catchMine @ Enclose[
    Module[ { cells, data, as },
        { cells, data } = Reap[ getCellsInChatHistory @ cell, $chatHistoryTag ];
        ConfirmMatch[ cells, { ___CellObject }, "CellObjects" ];
        as = ConfirmBy[ <| data, "CellObjects" -> cells |>, AssociationQ, "Data" ];
        ConfirmMatch[ selectProperties[ as, property ], Except[ _selectProperties ], "SelectedProperties" ]
    ],
    throwInternalFailure[ GetChatHistory[ cell, property ], ## ] &
];

GetChatHistory[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", GetChatHistory, HoldForm @ GetChatHistory @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*selectProperties*)
selectProperties // beginDefinition;
selectProperties[ as_Association, All ] := selectProperties[ as, $validChatHistoryProperties ];
selectProperties[ as_Association, props: { ___String } ] := AssociationMap[ selectProperties[ as, # ] &, props ];
selectProperties[ as_Association, prop_String ] /; KeyExistsQ[ as, prop ] := as[ prop ];
selectProperties[ as_Association, "ChatHistoryLength" ] := as[ "Settings", "ChatHistoryLength" ];
selectProperties[ as_Association, "IncludeHistory" ] := as[ "Settings", "IncludeHistory" ];
selectProperties[ as_Association, "Cells" ] := getCellExpressions @ as;
selectProperties[ as_Association, "Messages" ] := constructMessages[ as, as[ "CellObjects" ] ];
selectProperties // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getCellExpressions*)
getCellExpressions // beginDefinition;
getCellExpressions[ KeyValuePattern[ "CellObjects" -> cells_ ] ] := getCellExpressions @ cells;
getCellExpressions[ cells: { ___CellObject } ] := NotebookRead @ cells;
getCellExpressions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getCellsInChatHistory*)
getCellsInChatHistory // beginDefinition;

getCellsInChatHistory[ cell_CellObject ] :=
    getCellsInChatHistory[ topParentCell @ cell, parentNotebook @ cell ];

getCellsInChatHistory[ cell_CellObject, nbo_NotebookObject ] :=
    getCellsInChatHistory[
        cell,
        sowHistoryData[ "ChatDelimiter", getPrecedingDelimiter[ cell, nbo ] ],
        nbo,
        Cells @ nbo
    ];

getCellsInChatHistory[
    cell_CellObject,
    delimiter_CellObject,
    nbo_NotebookObject,
    { ___, delimiter_, history___, cell_, ___ }
] := selectChatHistoryCells[ sowHistoryData[ "Settings", currentChatSettings @ cell ], { history, cell }, cell ];

getCellsInChatHistory[
    cell_CellObject,
    _Missing,
    nbo_NotebookObject,
    { history___, cell_, ___ }
] := selectChatHistoryCells[ sowHistoryData[ "Settings", currentChatSettings @ cell ], { history, cell }, cell ];

getCellsInChatHistory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sowHistoryData*)
sowHistoryData // beginDefinition;
sowHistoryData[ key_String, value_ ] := (Sow[ key -> value, $chatHistoryTag ]; value);
sowHistoryData[ value_Association ] := Sow[ value, $chatHistoryTag ];
sowHistoryData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectChatHistoryCells*)
selectChatHistoryCells // beginDefinition;

selectChatHistoryCells[ settings_Association, cells: { ___CellObject }, cell_CellObject ] :=
    selectChatHistoryCells[
        settings[ "IncludeHistory"    ],
        settings[ "ChatHistoryLength" ],
        filterChatCells @ sowHistoryData[ "CellInformation", cellInformation @ cells ],
        cell
    ];

selectChatHistoryCells[ False, max_, info: { ___Association }, cell_CellObject ] :=
    If[ MemberQ[ info, KeyValuePattern[ "CellObject" -> cell ] ],
        { cell },
        { }
    ];

selectChatHistoryCells[ include_, max_? Positive, info: { ___Association }, cell_CellObject ] :=
    Module[ { take },
        take = Take[ Reverse @ info, UpTo @ max ];
        If[ MemberQ[ take, KeyValuePattern[ "CellObject" -> cell ] ],
            Cases[ Reverse @ take, KeyValuePattern[ "CellObject" -> c_ ] :> c ],
            { }
        ]
    ];

selectChatHistoryCells[ include_, $$unspecified, info_, cell_ ] :=
    selectChatHistoryCells[ include, Infinity, info, cell ];

selectChatHistoryCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatExcludedQ*)
chatExcludedQ // beginDefinition;

chatExcludedQ[ cell_CellObject ] := chatExcludedQ @ cellInformation @ cell;

chatExcludedQ[ Cell[ __, $$chatIgnoredStyle, ___ ] ] := True;
chatExcludedQ[ Cell[ __, TaggingRules -> tags_, ___ ] ] := chatExcludedQ @ tags;
chatExcludedQ[ Cell[ ___ ] ] := False;

chatExcludedQ[ KeyValuePattern[ "Style" -> $$chatIgnoredStyle ] ] := True;
chatExcludedQ[ KeyValuePattern[ "ChatNotebookSettings" -> settings_ ] ] := chatExcludedQ @ settings;
chatExcludedQ[ KeyValuePattern[ "ExcludeFromChat" -> exclude_ ] ] := TrueQ @ exclude;
chatExcludedQ[ KeyValuePattern[ { } ] ] := False;

chatExcludedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*filterChatCells*)
filterChatCells // beginDefinition;
filterChatCells[ cellInfo: { ___Association } ] := Select[ cellInfo, Not @* chatExcludedQ ];
filterChatCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Included Cell Highlighting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*accentIncludedCells*)
accentIncludedCells // beginDefinition;

accentIncludedCells[ ___ ] /; insufficientVersionQ[ "AccentedCells" ] := Null;

accentIncludedCells[ cell_CellObject ] :=
    accentIncludedCells[ topParentCell @ cell, parentNotebook @ cell ];

accentIncludedCells[ cell_CellObject, nbo_NotebookObject ] :=
    accentIncludedCells0[ nbo, getCellsInChatHistory[ cell, nbo ] ];

accentIncludedCells // endDefinition;



accentIncludedCells0 // beginDefinition;

accentIncludedCells0[ nbo_NotebookObject, cells: { ___CellObject } ] :=
    FE`Evaluate @ FEPrivate`AccentedCellsSet[ nbo, cells ];

accentIncludedCells0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeCellAccents*)
removeCellAccents // beginDefinition;
removeCellAccents[ ___ ] /; insufficientVersionQ[ "AccentedCells" ] := Null;
removeCellAccents[ nbo_NotebookObject ] := FE`Evaluate @ FEPrivate`AccentedCellsSet[ nbo, { } ];
removeCellAccents[ cell_CellObject ] := removeCellAccents @ parentNotebook @ cell;
removeCellAccents // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$includedCellWidget*)
$IncludedCellWidget = With[ { color = $cellFrameColor },
    DynamicModule[ { cell, extra },
        Dynamic @ Framed[
            "",
            Background   -> color,
            ImageSize    -> { 2, AbsoluteCurrentValue[ cell, { "CellSize", 2 } ] + extra },
            FrameStyle   -> None,
            FrameMargins -> -1,
            ImageMargins -> 0
        ],
        Initialization   :> (cell = topParentCell @ EvaluationCell[ ]; extra = extraCellHeight @ cell),
        UnsavedVariables :> { cell, extra }
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extraCellHeight*)
extraCellHeight // beginDefinition;

extraCellHeight[ cell_CellObject ] := extraCellHeight[ cell ] = Max[
    0,
    extraCellHeight[
        AbsoluteCurrentValue[ cell, { CellFrame       , 2 } ],
        AbsoluteCurrentValue[ cell, { CellFrameMargins, 2 } ]
    ]
];

extraCellHeight[ f_Integer, margins_ ] := extraCellHeight[ { f, f }, margins ];
extraCellHeight[ frame_, m_Integer ] := extraCellHeight[ frame, { m, m } ];
extraCellHeight[ { 0, fT_Integer }, { mB_Integer, mT_Integer } ] := fT + mT;
extraCellHeight[ { fB_Integer, 0 }, { mB_Integer, mT_Integer } ] := fB + mB;
extraCellHeight[ { 0, 0 }, { mB_Integer, mT_Integer } ] := 0;
extraCellHeight[ { fB_Integer, fT_Integer }, { mB_Integer, mT_Integer } ] := fB + fT + mB + mT;
extraCellHeight[ { Except[ _Integer ], ft_Integer }, margins_ ] := extraCellHeight[ { 0, ft }, margins ];
extraCellHeight[ ___ ] := 0;

extraCellHeight // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
