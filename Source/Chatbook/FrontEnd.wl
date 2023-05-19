(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`FrontEnd`" ];

`$defaultChatSettings;
`$suppressButtonAppearance;
`cellInformation;
`cellOpenQ;
`cellPrint;
`cellPrintAfter;
`cellStyles;
`currentChatSettings;
`notebookRead;
`parentCell;
`parentNotebook;
`toCompressedBoxes;
`topParentCell;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentValue Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentChatSettings*)
currentChatSettings // beginDefinition;

currentChatSettings[ obj: _NotebookObject|_CellObject ] :=
    Association[
        $defaultChatSettings,
        Replace[
            Association @ CurrentValue[ obj, { TaggingRules, "ChatNotebookSettings" } ],
            Except[ _? AssociationQ ] :> <| |>
        ]
    ];

currentChatSettings[ obj: _NotebookObject|_CellObject, key_String ] := Replace[
    AbsoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", key } ],
    Inherited :> Lookup[ $defaultChatSettings, key, Inherited ]
];

currentChatSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$defaultChatSettings*)
$defaultChatSettings := Association @ Options @ CreateChatNotebook;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellInformation*)
cellInformation // beginDefinition;

cellInformation[ nbo_NotebookObject ] := cellInformation @ Cells @ nbo;

cellInformation[ cells: { ___CellObject } ] := Map[
    Association,
    Transpose @ {
        Thread[ "CellObject" -> cells ],
        Developer`CellInformation @ cells,
        Thread[ "CellAutoOverwrite" -> CurrentValue[ cells, CellAutoOverwrite ] ]
    }
];

cellInformation[ cell_CellObject ] := Association[
    "CellObject" -> cell,
    Developer`CellInformation @ cell,
    "CellAutoOverwrite" -> CurrentValue[ cell, CellAutoOverwrite ]
];

cellInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parentCell*)
parentCell // beginDefinition;
parentCell[ cell_CellObject ] /; CloudSystem`$CloudNotebooks := cell;
parentCell[ cell_CellObject ] := ParentCell @ cell;
parentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*topParentCell*)
topParentCell // beginDefinition;
topParentCell[ cell_CellObject ] := With[ { p = ParentCell @ cell }, topParentCell @ p /; MatchQ[ p, _CellObject ] ];
topParentCell[ cell_CellObject ] := cell;
topParentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellPrint*)
cellPrint // beginDefinition;
cellPrint[ cell_Cell ] /; CloudSystem`$CloudNotebooks := cloudCellPrint @ cell;
cellPrint[ cell_Cell ] := MathLink`CallFrontEnd @ FrontEnd`CellPrintReturnObject @ cell;
cellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellPrint*)
cloudCellPrint // beginDefinition;

cloudCellPrint[ cell0_Cell ] :=
    Enclose @ Module[ { cellUUID, nbUUID, cell },
        cellUUID = CreateUUID[ ];
        nbUUID   = ConfirmBy[ cloudNotebookUUID[ ], StringQ ];
        cell     = Append[ DeleteCases[ cell0, ExpressionUUID -> _ ], ExpressionUUID -> cellUUID ];
        CellPrint @ cell;
        CellObject[ cellUUID, nbUUID ]
    ];

cloudCellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookUUID*)
cloudNotebookUUID // beginDefinition;
cloudNotebookUUID[ ] := cloudNotebookUUID[ EvaluationNotebook[ ] ];
cloudNotebookUUID[ NotebookObject[ _, uuid_String ] ] := uuid;
cloudNotebookUUID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellPrintAfter*)
cellPrintAfter[ target_ ][ cell_ ] := cellPrintAfter[ target, cell ];

cellPrintAfter[ target_CellObject, cell: Cell[ __, ExpressionUUID -> uuid_, ___ ] ] := (
    SelectionMove[ target, After, Cell, AutoScroll -> False ];
    NotebookWrite[ parentNotebook @ target, cell ];
    CellObject @ uuid
);

cellPrintAfter[ target_CellObject, cell_Cell ] :=
    cellPrintAfter[ target, Append[ cell, ExpressionUUID -> CreateUUID[ ] ] ];

cellPrintAfter[ a_, b__ ] := throwInternalFailure @ cellPrintAfter[ a, b ];
cellPrintAfter[ a_ ][ b___ ] := throwInternalFailure @ cellPrintAfter[ a ][ b ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellOpenQ*)
cellOpenQ // beginDefinition;
cellOpenQ[ cell_CellObject ] /; CloudSystem`$CloudNotebooks := Lookup[ Options[ cell, CellOpen ], CellOpen, True ];
cellOpenQ[ cell_CellObject ] := CurrentValue[ cell, CellOpen ];
cellOpenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellStyles*)
cellStyles // beginDefinition;
cellStyles[ cells_ ] /; CloudSystem`$CloudNotebooks := cloudCellStyles @ cells;
cellStyles[ cells_ ] := CurrentValue[ cells, CellStyle ];
cellStyles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellStyles*)
cloudCellStyles // beginDefinition;
cloudCellStyles[ cells_ ] := Cases[ notebookRead @ cells, Cell[ _, style___String, OptionsPattern[ ] ] :> { style } ];
cloudCellStyles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parentNotebook*)
parentNotebook // beginDefinition;
parentNotebook[ cell_CellObject ] /; CloudSystem`$CloudNotebooks := Notebooks @ cell;
parentNotebook[ cell_CellObject ] := ParentNotebook @ cell;
parentNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookRead*)
notebookRead // beginDefinition;
notebookRead[ cells_ ] /; CloudSystem`$CloudNotebooks := cloudNotebookRead @ cells;
notebookRead[ cells_ ] := NotebookRead @ cells;
notebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookRead*)
cloudNotebookRead // beginDefinition;
cloudNotebookRead[ cells: { ___CellObject } ] := NotebookRead /@ cells;
cloudNotebookRead[ cell_ ] := NotebookRead @ cell;
cloudNotebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$suppressButtonAppearance*)
$suppressButtonAppearance = Dynamic @ FEPrivate`FrontEndResource[
    "FEExpressions",
    "SuppressMouseDownNinePatchAppearance"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toCompressedBoxes*)
toCompressedBoxes // beginDefinition;
toCompressedBoxes[ expr_ ] := compressRasterBoxes @ MakeBoxes @ expr;
toCompressedBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*compressRasterBoxes*)
compressRasterBoxes // beginDefinition;

compressRasterBoxes[ boxes_ ] :=
    ReplaceAll[
        boxes,
        {
            GraphicsBox[ TagBox[ RasterBox[ a: Except[ _String ], b___ ], c___ ], d___ ] :>
                With[ { compressed = Compress @ Unevaluated @ a },
                    GraphicsBox[ TagBox[ RasterBox[ CompressedData @ compressed, b ], c ], d ] /; True
                ],
            GraphicsBox[ RasterBox[ a: Except[ _String ], b___ ], c___ ] :>
                With[ { compressed = Compress @ Unevaluated @ a },
                    GraphicsBox[ RasterBox[ CompressedData @ compressed, b ], c ] /; True
                ]
        }
    ];

compressRasterBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    Null
];

End[ ];
EndPackage[ ];
