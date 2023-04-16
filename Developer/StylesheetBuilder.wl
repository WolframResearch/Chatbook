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
(*$icons*)
$icons := $icons = Association @ Map[
    FileBaseName @ # -> Import @ # &,
    FileNames[ All, $iconDirectory ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$sendChatFunction*)
$sendChatFunction = Function[
    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "Send", # ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$askMenuItem*)
$askMenuItem = MenuItem[
    "Ask AI Assistant",
    KernelExecute[
        Function[
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "Ask", ## ]
        ][ InputNotebook[ ], SelectedCells @ InputNotebook[ ] ]
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
        Function[
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ExclusionToggle", ## ]
        ][ InputNotebook[ ], SelectedCells @ InputNotebook[ ] ]
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
(*inlineResources*)
inlineResources[ expr_ ] := expr /. {
    HoldPattern[ $icons[ name_String ] ]   :> RuleCondition @ $icons @ name,
    HoldPattern @ $askMenuItem             :> RuleCondition @ $askMenuItem,
    HoldPattern @ $defaultChatbookSettings :> RuleCondition @ $defaultChatbookSettings,
    HoldPattern @ $sendChatFunction        :> RuleCondition @ $sendChatFunction
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