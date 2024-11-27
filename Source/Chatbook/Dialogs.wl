(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Dialogs`" ];
Begin[ "`Private`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$inDialog               = False;
$dialogHeaderMargins    = { { 30, 30 }, { 13, 9 } };
$dialogSubHeaderMargins = { { 30, 30 }, {  0, 9 } };
$dialogBodyMargins      = { { 30, 30 }, { 13, 5 } };
$paneHeaderMargins      = { {  5, 30 }, { 13, 9 } };
$paneSubHeaderMargins   = { {  5, 30 }, {  0, 9 } };
$paneBodyMargins        = { {  5, 30 }, { 13, 5 } };
$baseStyle             := $baseStyles[ "Default" ];

$baseStyles = <|
    "Default"         -> { FontFamily -> "Source Sans Pro", FontSize -> 14 },
    "DialogSubHeader" -> { FontSize -> 14, FontWeight -> "DemiBold" }
|>;

$headerMargins    := If[ TrueQ @ $inDialog, $dialogHeaderMargins   , $paneHeaderMargins    ];
$subHeaderMargins := If[ TrueQ @ $inDialog, $dialogSubHeaderMargins, $paneSubHeaderMargins ];
$bodyMargins      := If[ TrueQ @ $inDialog, $dialogBodyMargins     , $paneBodyMargins      ];

(* Copied from Dialog.nb stylesheet in order for buttons to render correctly on Cloud *)
$buttonCommonOptions = {
    Alignment        -> Center,
    BaselinePosition -> Baseline, (* added since it's repeatedly used everywhere *)
    FrameMargins     -> 4,
    FrameStyle       -> None,
    ImageSize        -> { { 38, Full }, { 19.5, Full } },
    RoundingRadius   -> 3
};

$dialogTextBasic = {
    FontFamily         -> "Source Sans Pro",
    FontSize           -> 13,
    PrivateFontOptions -> { "OperatorSubstitution" -> False }
}

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
dialogHeader[ expr_           ] := dialogHeader[ expr, Automatic ];
dialogHeader[ expr_, margins_ ] := dialogPane[ expr, "DialogHeader", margins ];
dialogHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogSubHeader*)
dialogSubHeader // beginDefinition;
dialogSubHeader[ expr_           ] := dialogSubHeader[ expr, Automatic ];
dialogSubHeader[ expr_, margins_ ] := dialogPane[ expr, "DialogSubHeader", margins ];
dialogSubHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogBody*)
dialogBody // beginDefinition;
dialogBody[ expr_           ] := dialogBody[ expr, Automatic ];
dialogBody[ expr_, margins_ ] := dialogPane[ expr, "DialogBody", margins ];
dialogBody // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*spanAcross*)
spanAcross // beginDefinition;
spanAcross[ expr_ ] := { expr, SpanFromLeft };
spanAcross // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogPane*)
dialogPane // beginDefinition;

dialogPane[ expr_ ] := dialogPane[ expr, "DialogBody" ];
dialogPane[ expr_, style_ ] := dialogPane[ expr, style, Automatic ];
dialogPane[ expr_, style_, margins_ ] := dialogPane[ expr, style, margins, $inDialog ];

dialogPane[ exprs_List, style_, margins_, inDialog_ ] := dialogPane[ exprs, style, margins, inDialog ] =
    dialogPane0[ #, style, margins ] & /@ exprs;

dialogPane[ expr_, style_, margins_, inDialog_ ] := dialogPane[ expr, style, margins, inDialog ] =
    { dialogPane0[ expr, style, margins ], SpanFromLeft };

dialogPane // endDefinition;


dialogPane0 // beginDefinition;

dialogPane0[ expr_, style_, margins_ ] :=
    Pane[
        expr,
        BaseStyle    -> dialogBaseStyle @ style,
        FrameMargins -> dialogMargins[ style, margins ]
    ];

dialogPane0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogBaseStyle*)
dialogBaseStyle // beginDefinition;
dialogBaseStyle[ "DialogSubHeader" ] := { FontSize -> 14, FontWeight -> "DemiBold" };
dialogBaseStyle[ name_String ] := Lookup[ $baseStyles, name, name ];
dialogBaseStyle[ style_ ] := style;
dialogBaseStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogMargins*)
dialogMargins // beginDefinition;
dialogMargins[ "DialogBody"     , margins_ ] := autoMargins[ margins, $bodyMargins      ];
dialogMargins[ "DialogHeader"   , margins_ ] := autoMargins[ margins, $headerMargins    ];
dialogMargins[ "DialogSubHeader", margins_ ] := autoMargins[ margins, $subHeaderMargins ];
dialogMargins[ _                , margins_ ] := margins;
dialogMargins // endDefinition;

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

grayDialogButtonLabel[ { normal_, hover_, pressed_ }, optsOverrides: OptionsPattern[ ] ] /; $cloudNotebooks :=
    Mouseover[
        Framed[ normal , Sequence @@ Join[ Flatten @ { optsOverrides }, { BaseStyle -> { FontColor -> GrayLevel[ 20/51 ] }, Background -> GrayLevel[ 229/255 ] }, $buttonCommonOptions ] ],
        Framed[ hover  , Sequence @@ Join[ Flatten @ { optsOverrides }, { BaseStyle -> { FontColor -> GrayLevel[ 20/51 ] }, Background -> GrayLevel[   49/51 ], FrameStyle -> GrayLevel[ 229/255 ] }, $buttonCommonOptions ] ],
        BaseStyle      -> $dialogTextBasic,
        ContentPadding -> False,
        ImageSize      -> All
    ];

grayDialogButtonLabel[ { normal_, hover_, pressed_ }, optsOverrides: OptionsPattern[ ] ] :=
    NotebookTools`Mousedown[
        Framed[ normal , optsOverrides, BaseStyle -> "ButtonGray1Normal" , BaselinePosition -> Baseline ],
        Framed[ hover  , optsOverrides, BaseStyle -> "ButtonGray1Hover"  , BaselinePosition -> Baseline ],
        Framed[ pressed, optsOverrides, BaseStyle -> "ButtonGray1Pressed", BaselinePosition -> Baseline ],
        BaseStyle -> "DialogTextBasic"
    ];

grayDialogButtonLabel[ { normal_, hover_ }, opts: OptionsPattern[ ] ] := grayDialogButtonLabel[ { normal, hover, hover }, opts ];

grayDialogButtonLabel[ label_, opts: OptionsPattern[ ] ] := grayDialogButtonLabel[ { label, label, label }, opts ];

grayDialogButtonLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*redDialogButtonLabel*)
redDialogButtonLabel // beginDefinition;

redDialogButtonLabel[ { normal_, hover_, pressed_ }, optsOverrides: OptionsPattern[ ] ] /; $cloudNotebooks :=
    Mouseover[
        Framed[ normal , Sequence @@ Join[ Flatten @ { optsOverrides }, { BaseStyle -> { FontColor -> GrayLevel[ 1 ] }, Background -> RGBColor[   13/15, 1/15, 0 ] }, $buttonCommonOptions ] ],
        Framed[ hover  , Sequence @@ Join[ Flatten @ { optsOverrides }, { BaseStyle -> { FontColor -> GrayLevel[ 1 ] }, Background -> RGBColor[ 254/255,    0, 0 ] }, $buttonCommonOptions ] ],
        BaseStyle      -> $dialogTextBasic,
        ContentPadding -> False,
        ImageSize      -> All
    ];

redDialogButtonLabel[ { normal_, hover_, pressed_ }, optsOverrides: OptionsPattern[ ] ] :=
    NotebookTools`Mousedown[
        Framed[ normal , optsOverrides, BaseStyle -> "ButtonRed1Normal" , BaselinePosition -> Baseline ],
        Framed[ hover  , optsOverrides, BaseStyle -> "ButtonRed1Hover"  , BaselinePosition -> Baseline ],
        Framed[ pressed, optsOverrides, BaseStyle -> "ButtonRed1Pressed", BaselinePosition -> Baseline ],
        BaseStyle -> "DialogTextBasic"
    ];

redDialogButtonLabel[ { normal_, hover_ }, opts: OptionsPattern[ ] ] := redDialogButtonLabel[ { normal, hover, hover }, opts ];

redDialogButtonLabel[ label_, opts: OptionsPattern[ ] ] := redDialogButtonLabel[ { label, label, label }, opts ];

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
cvExpand /: SetDelayed[ lhs_, cvExpand[ rhs_ ] ] := Unevaluated @ SetDelayed[ lhs, rhs ] /. $cvRules;
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
addToMXInitialization[
    $cvRules;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
