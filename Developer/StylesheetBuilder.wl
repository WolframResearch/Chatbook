(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`ChatbookStylesheetBuilder`" ];

ClearAll[ "`*" ];
ClearAll[ "`Private`*" ];

$ChatbookStylesheet;
BuildChatbookStylesheet;

System`LinkedItems;
System`MenuAnchor;
System`MenuItem;
System`RawInputForm;
System`ToggleMenuItem;
System`Scope;

Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paths*)
$assetLocation    = FileNameJoin @ { DirectoryName @ $InputFileName, "Resources" };
$iconDirectory    = FileNameJoin @ { $assetLocation, "Icons" };
$styleDataFile    = FileNameJoin @ { $assetLocation, "Styles.wl" };
$styleSheetTarget = FileNameJoin @ { DirectoryName[ $InputFileName, 2 ], "FrontEnd", "StyleSheets", "Chatbook.nb" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Resources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$suppressButtonAppearance*)
$suppressButtonAppearance = Dynamic @ FEPrivate`FrontEndResource[
    "FEExpressions",
    "SuppressMouseDownNinePatchAppearance"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$icons*)
$icons := $icons = Association @ Map[
    FileBaseName @ # -> Import @ # &,
    FileNames[ All, $iconDirectory ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$askMenuItem*)
$askMenuItem = MenuItem[
    "Ask AI Assistant",
    KernelExecute[
        With[
            { $CellContext`nbo = InputNotebook[ ] },
            { $CellContext`cells = SelectedCells @ $CellContext`nbo },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "Ask", $CellContext`nbo, $CellContext`cells ]
        ]
    ],
    MenuEvaluator -> Automatic,
    Method        -> "Queued"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$excludeMenuItem*)
$excludeMenuItem = MenuItem[
    "Include/Exclude From AI Chat",
    KernelExecute[
        With[
            { $CellContext`nbo = InputNotebook[ ] },
            { $CellContext`cells = SelectedCells @ $CellContext`nbo },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ExclusionToggle", $CellContext`nbo, $CellContext`cells ]
        ]
    ],
    MenuEvaluator -> Automatic,
    Method        -> "Queued"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*contextMenu*)
contextMenu[ a___, name_String, b___ ] := contextMenu[ a, FrontEndResource[ "ContextMenus", name ], b ];
contextMenu[ a___, list_List, b___ ] := contextMenu @@ Flatten @ { a, list, b };
contextMenu[ a___ ] := Flatten @ { a };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuInitializer*)
menuInitializer[ name_String, color_ ] :=
    With[ { attach = Cell[ BoxData @ TemplateBox[ { name, color }, "ChatMenuButton" ], "ChatMenu" ] },
        Initialization :> With[ { $CellContext`cell = EvaluationCell[ ] },
            NotebookDelete @ Cells[ $CellContext`cell, AttachedCell -> True, CellStyle -> "ChatMenu" ];
            AttachCell[
                $CellContext`cell,
                attach,
                { Right, Top },
                Offset[ { -7, -7 }, { Right, Top } ],
                { Right, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineResources*)
inlineResources[ expr_ ] := expr /. {
    HoldPattern[ $icons[ name_String ] ]    :> RuleCondition @ $icons @ name,
    HoldPattern @ $askMenuItem              :> RuleCondition @ $askMenuItem,
    HoldPattern @ $defaultChatbookSettings  :> RuleCondition @ $defaultChatbookSettings,
    HoldPattern @ $suppressButtonAppearance :> RuleCondition @ $suppressButtonAppearance
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$styleDataCells*)
$styleDataCells := $styleDataCells = inlineResources @ Cases[ ReadList @ $styleDataFile, _Cell ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Default Settings*)
$defaultChatbookSettings := (
    Needs[ "Wolfram`Chatbook`" -> None ];
    KeyMap[ ToString, Association @ Options @ Wolfram`Chatbook`CreateChatNotebook ]
);

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$ChatbookStylesheet*)
$ChatbookStylesheet = Notebook[
    Flatten @ {
        Cell @ StyleData[ StyleDefinitions -> "Default.nb" ],
        $styleDataCells
    },
    StyleDefinitions -> "PrivateStylesheetFormatting.nb"
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*BuildChatbookStylesheet*)
BuildChatbookStylesheet[ ] := BuildChatbookStylesheet @ $styleSheetTarget;

BuildChatbookStylesheet[ target_ ] :=
    Module[ { exported },
        exported = Export[ target, $ChatbookStylesheet, "NB" ];
        PacletInstall[ "Wolfram/PacletCICD" ];
        Needs[ "Wolfram`PacletCICD`" -> None ];
        Wolfram`PacletCICD`FormatNotebooks @ exported;
        exported
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];