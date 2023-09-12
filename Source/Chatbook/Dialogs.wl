(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Dialogs`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`$baseStyle;

`$inDialog;
`createDialog;

`acv;
`cv;
`cvExpand;
`setCV;
`unsetCV;

`headerStyle;
`dialogHeader;
`dialogSubHeader;
`dialogBody;

`grayDialogButtonLabel;
`redDialogButtonLabel;

(* TODO: create a Dialogs.wl file containing definitions to share between this and the persona dialog *)

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$dialogHeaderMargins    = { { 30, 30 }, { 13, 9 } };
$dialogSubHeaderMargins = { { 30, 30 }, {  0, 9 } };
$dialogBodyMargins      = { { 30, 30 }, { 13, 5 } };

$baseStyle = { FontFamily -> "Source Sans Pro", FontSize -> 14 };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Create Dialogs*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createDialog*)
createDialog // beginDefinition;
createDialog // Attributes = { HoldFirst };

createDialog[ expr_, opts: OptionsPattern[ ] ] := Block[ { $inDialog = True }, CreateDialog[
    ExpressionCell[ expr, CellMargins -> 0 ],
    opts,
    Background             -> White,
    CellInsertionPointCell -> None,
    StyleDefinitions       -> $dialogStyles,
    WindowFrameElements    -> { "CloseBox" },
    NotebookEventActions -> {
        "EscapeKeyDown"                        :> (findAndClickCancel[ ]; channelCleanup[ ]; DialogReturn @ $Canceled),
        "WindowClose"                          :> (findAndClickCancel[ ]; channelCleanup[ ]; DialogReturn @ $Canceled),
        "ReturnKeyDown"                        :> findAndClickDefault[ ],
        { "MenuCommand", "EvaluateCells"     } :> findAndClickDefault[ ],
        { "MenuCommand", "EvaluateNextCell"  } :> findAndClickDefault[ ],
        { "MenuCommand", "HandleShiftReturn" } :> findAndClickDefault[ ]
    }
] ];

createDialog // endDefinition;

findAndClickDefault[ ] := FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ];
findAndClickCancel[ ] := FE`Evaluate @ FEPrivate`FindAndClickCancelButton[ ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Dialog Styling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$toolDialogStyles*)
$dialogStyles = Notebook[
    {
        Cell @ StyleData[ StyleDefinitions -> "Dialog.nb" ],
        Cell[ StyleData[ "HyperlinkActive" ], FontColor -> RGBColor[ 0.2392, 0.7960, 1.0000 ] ],
        Cell[ StyleData[ "Hyperlink"       ], FontColor -> RGBColor[ 0.0862, 0.6196, 0.8156 ] ]
    },
    StyleDefinitions -> "PrivateStylesheetFormatting.nb"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text Styling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*headerStyle*)
headerStyle // beginDefinition;
headerStyle[ expr_, opts___ ] := Style[ expr, FontWeight -> Bold, opts ];
headerStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogHeader*)
dialogHeader // beginDefinition;

dialogHeader[ expr_ ] :=
    dialogHeader[ expr, Automatic ];

dialogHeader[ expr_, margins_ ] :=
    spanAcross @ Pane[ expr, BaseStyle -> "DialogHeader", FrameMargins -> dialogHeaderMargins @ margins ];

dialogHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogSubHeader*)
dialogSubHeader // beginDefinition;

dialogSubHeader[ expr_ ] :=
    dialogSubHeader[ expr, Automatic ];

dialogSubHeader[ expr_, margins_ ] :=
    spanAcross @ Pane[
        expr,
        BaseStyle -> { FontSize -> 14, FontWeight -> "DemiBold" },
        FrameMargins -> dialogSubHeaderMargins @ margins
    ];

dialogSubHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogBody*)
dialogBody // beginDefinition;

dialogBody[ expr_ ] :=
    dialogBody[ expr, Automatic ];

dialogBody[ expr_, margins_ ] :=
    spanAcross @ Pane[ expr, BaseStyle -> "DialogBody", FrameMargins -> dialogBodyMargins @ margins ];

dialogBody // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*spanAcross*)
spanAcross // beginDefinition;
spanAcross[ expr_ ] := { expr, SpanFromLeft };
spanAcross // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogBodyMargins*)
dialogBodyMargins // beginDefinition;
dialogBodyMargins[ margins_ ] := dialogBodyMargins[ margins ] = autoMargins[ margins, $dialogBodyMargins ];
dialogBodyMargins // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogHeaderMargins*)
dialogHeaderMargins // beginDefinition;
dialogHeaderMargins[ margins_ ] := dialogHeaderMargins[ margins ] = autoMargins[ margins, $dialogHeaderMargins ];
dialogHeaderMargins // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogSubHeaderMargins*)
dialogSubHeaderMargins // beginDefinition;
dialogSubHeaderMargins[ margins_ ] := dialogSubHeaderMargins[ margins ] = autoMargins[ margins, $dialogSubHeaderMargins ];
dialogSubHeaderMargins // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoMargins*)
autoMargins // beginDefinition;
autoMargins[ Automatic, defaults_ ] := autoMargins[ ConstantArray[ Automatic, { 2, 2 } ], defaults ];
autoMargins[ { w: Automatic|_Integer, h_ }, defaults_ ] := autoMargins[ { { w, w }, h }, defaults ];
autoMargins[ { w_, h: Automatic|_Integer }, defaults_ ] := autoMargins[ { w, { h, h } }, defaults ]
autoMargins[ spec: { { _, _ }, { _, _ } }, default: { { _, _ }, { _, _ } } ] := autoMargins0[ spec, default ];
autoMargins // endDefinition;

autoMargins0 // beginDefinition;
autoMargins0 // Attributes = { Listable };
autoMargins0[ Automatic, m: Automatic|_Integer ] := m;
autoMargins0[ m_Integer, _ ] := m;
autoMargins0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Button Labels*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*grayDialogButtonLabel*)
grayDialogButtonLabel // beginDefinition;

grayDialogButtonLabel[ { normal_, hover_, pressed_ } ] :=
    NotebookTools`Mousedown[
        Framed[ normal , BaseStyle -> "ButtonGray1Normal" , BaselinePosition -> Baseline ],
        Framed[ hover  , BaseStyle -> "ButtonGray1Hover"  , BaselinePosition -> Baseline ],
        Framed[ pressed, BaseStyle -> "ButtonGray1Pressed", BaselinePosition -> Baseline ],
        BaseStyle -> "DialogTextBasic"
    ];

grayDialogButtonLabel[ { normal_, hover_ } ] := grayDialogButtonLabel[ { normal, hover, hover } ];

grayDialogButtonLabel[ label_ ] := grayDialogButtonLabel[ { label, label, label } ];

grayDialogButtonLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*redDialogButtonLabel*)
redDialogButtonLabel // beginDefinition;

redDialogButtonLabel[ { normal_, hover_, pressed_ } ] :=
    NotebookTools`Mousedown[
        Framed[ normal , BaseStyle -> "ButtonRed1Normal" , BaselinePosition -> Baseline ],
        Framed[ hover  , BaseStyle -> "ButtonRed1Hover"  , BaselinePosition -> Baseline ],
        Framed[ pressed, BaseStyle -> "ButtonRed1Pressed", BaselinePosition -> Baseline ],
        BaseStyle -> "DialogTextBasic"
    ];

redDialogButtonLabel[ { normal_, hover_ } ] := redDialogButtonLabel[ { normal, hover, hover } ];

redDialogButtonLabel[ label_ ] := redDialogButtonLabel[ { label, label, label } ];

redDialogButtonLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentValue Tools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cvExpand*)
cvExpand // beginDefinition;
cvExpand // Attributes = { HoldFirst };
cvExpand[ expr_ ] := expr /. $cvRules;
cvExpand // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$cvRules*)
$cvRules := $cvRules = Dispatch @ Flatten @ {
    DownValues @ acv,
    DownValues @ cv,
    DownValues @ setCV,
    DownValues @ unsetCV
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acv*)
acv // beginDefinition;
acv[ scope_, keys___ ] := AbsoluteCurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", keys } ];
acv // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cv*)
cv // beginDefinition;
cv[ scope_, keys___ ] := CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", keys } ];
cv // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setCV*)
setCV // beginDefinition;
setCV[ scope_, keys___, value_ ] := CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", keys } ] = value;
setCV // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unsetCV*)
unsetCV // beginDefinition;
unsetCV[ scope_, keys___ ] := CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", keys } ] = Inherited;
unsetCV // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $cvRules;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
