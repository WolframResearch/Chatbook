(*
	This file contains utilities for constructing Chatbook menus.

*)

(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Menus`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `AttachSubmenu;
    `MakeMenu;
    `MakeSideBarMenu;
];

Needs[ "GeneralUtilities`" -> None ];

GeneralUtilities`SetUsage[MakeMenu, "
MakeMenu[$$] returns an expression representing a menu of actions.

The generated menu expression may depend on styles from the Chatbook stylesheet.
"];

GeneralUtilities`SetUsage[AttachSubmenu, "
AttachSubmenu[parentMenu$, submenu$] attaches submenu$ to parentMenu$, taking
care to attach to the left or right side based on heuristic for available space.
"];

GeneralUtilities`SetUsage[MakeSideBarMenu, "
MakeSideBarMenu[Dynamic[pane], $$] returns an expression representing a menu of actions where pane refers to the top-menu's state.
"];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ErrorUtils`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$submenuItems = False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MakeSideBarMenu*)
MakeSideBarMenu // beginDefinition;

MakeSideBarMenu[ sideBarCell_CellObject, items_List ] :=
With[ { en = EvaluationNotebook[ ], mag = If[$OperatingSystem =!= "MacOSX", 0.75, 1.] },
    DynamicModule[ { generatedMenu, aiPane, modelPaneLabel },
        PaneSelector[
            {
                "Main" -> 
                    Column[
                        {
                            linkTrailFrame[ "AI Settings", CurrentValue[ sideBarCell, CellTags ] = "ResetToMain" ],
                            scrollablePane[
                                Column[
                                    sideBarMenuItem[ #, generatedMenu, aiPane, modelPaneLabel, en ]& /@ items,
                                    Spacings -> { 0, 0 } ],
                                mag, 90, en ] },
                        ItemSize -> Automatic, Spacings -> { 0, 0 }, Alignment -> Left
                    ],
                "Services" ->
                    Dynamic @ Column[(* oddity: dynamic column doesn't get the spacings right, leaving a gap, so close the gap by hand *)
                        {
                            linkTrailFrame[ "Models", aiPane = "Main" ],
                            scrollablePane[
                                Column[
                                    sideBarMenuItem[ #, generatedMenu, aiPane, modelPaneLabel, en ]& /@ Wolfram`Chatbook`UI`Private`createServiceMenu[ en ],
                                    Spacings -> { 0, 0 } ],
                                mag, 90, en ] },
                        BaseStyle -> FontSize -> 1, ItemSize -> Automatic, Spacings -> { 0, -4 }, Alignment -> Left
                    ],
                "ModelNames" ->
                    Dynamic @ Column[
                        {
                            linkTrailFrame[ Dynamic[modelPaneLabel], aiPane = "Services" ],
                            scrollablePane[
                                Column[
                                    sideBarMenuItem[ #, generatedMenu, aiPane, modelPaneLabel, en ]& /@ generatedMenu,
                                    Spacings -> { 0, 0 } ],
                                mag, 90, en ] },
                        BaseStyle -> FontSize -> 1, ItemSize -> Automatic, Spacings -> { 0, -4 }, Alignment -> Left
                    ],

                (* some day this meny may depend on the model (service) and model name... *)
                "AdvancedSettings" ->
                    Column[
                        {
                            linkTrailFrame[ "Advanced Settings", aiPane = "Main" ],
                            scrollablePane[
                                Column[
                                    sideBarMenuItem[ #, generatedMenu, aiPane, modelPaneLabel, en ]& /@  Wolfram`Chatbook`UI`Private`createAdvancedSettingsMenu[ en ],
                                    Spacings -> { 0, 0 } ],
                                mag, 90, en ] },
                        ItemSize -> Automatic, Spacings -> { 0, 0 }, Alignment -> Left
                    ]
            },
            Dynamic @ aiPane,
            ImageSize -> Automatic
        ],
        Initialization :> (aiPane = "Main")
    ]
]

MakeSideBarMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*side bar UI elements*)


(* side bar is 15.0+ and thus supports LightDarkSwitched *)
$ControlFontColorDefault = LightDarkSwitched[ GrayLevel[ 0.2 ], GrayLevel[ 0.9613 ] ];
$ControlFontColorHover   = LightDarkSwitched[ RGBColor[ "#2FA7DC" ], RGBColor[ "#87D0F9" ] ];
$ControlFontColorPressed = LightDarkSwitched[ RGBColor[ "#0E7FB1" ], RGBColor[ "#4ABEF3" ] ];
$DividerColor            = LightDarkSwitched @ GrayLevel[ 0.9098 ];
$FrameColorDefault       = LightDarkSwitched[ GrayLevel[ 0.749 ], GrayLevel[ 0.5495 ] ];
$FrameColorHover         = LightDarkSwitched[ RGBColor[ "#8BCCE9" ], RGBColor[ "#7BBBD6" ] ];
$FrameColorPressed       = LightDarkSwitched[ RGBColor[ "#67A3BE" ], RGBColor[ "#6390A6" ] ];
$MainBackground          = LightDarkSwitched[ GrayLevel[ 0.97647 ], GrayLevel[ 0.17974 ] ];
$MatchContentBackground  = ThemeColor[ "Background" ];
$NavigationColorDefault  = LightDarkSwitched[ RGBColor[ "#2285C3" ], RGBColor[ "#8BCAF9" ] ];
$NavigationColorHover    = LightDarkSwitched[ RGBColor[ "#2FA7DC" ], RGBColor[ "#B2DCFB" ] ];
$NavigationColorPressed  = LightDarkSwitched[ RGBColor[ "#2285C3" ], RGBColor[ "#8BCAF9" ] ];
$ResetButtonHover        = LightDarkSwitched[ RGBColor[ "#2FA7DC" ], RGBColor[ "#87D0F9" ] ];
$ResetButtonPressed      = LightDarkSwitched[ RGBColor[ "#0E7FB1" ], RGBColor[ "#4ABEF3" ] ];
$TransparentBackground   = Transparent;


(* ::**************************************************************************************************************:: *)
backButtonAppearanceBasic // beginDefinition;

(* crossing streams a bit here with the NotebookToolbar paclet... *)
backButtonAppearanceBasic[ iconColor_, bgColor_, frameColor_ ] :=
Framed[
    Dynamic[ RawBoxes[ FEPrivate`FrontEndResource[ "NotebookToolbarExpressions", "NPBackArrowIcon" ][ iconColor ] ] ],
    Alignment        -> { Center, Center },
    Background       -> bgColor,
    BaselinePosition -> Baseline,
    FrameMargins     -> 0,
    FrameStyle       -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
    ImageSize        -> { 22, 22 },
    RoundingRadius   -> 4
]

backButtonAppearanceBasic // endDefinition;


(* ::**************************************************************************************************************:: *)
chatMenuItemAppearanceBasic // beginDefinition;

chatMenuItemAppearanceBasic[ icon_, text_, bgColor_, frameColor_, fontColor_, navIconColor_, includeNavArrowQ_ ] :=
Framed[
    Grid[
        { {
            icon,
            Spacer[ 12 ],
            If[ includeNavArrowQ,
                Item[ Style[ text, FontColor -> fontColor ], ItemSize -> Fit, Alignment -> Left ],
                Style[ text, FontColor -> fontColor ] ],
            If[ includeNavArrowQ,
                Dynamic[ RawBoxes[ FEPrivate`FrontEndResource[ "NotebookToolbarExpressions", "NPForwardArrowIcon" ][ navIconColor ] ] ],
                Nothing ]
        } },
        Alignment        -> { Left, Center },
        BaselinePosition -> { { 1, 3 }, Baseline },
        ItemSize         -> { { Automatic, Automatic, Automatic } },
        Spacings         -> { 0, 0 }
    ],
    Alignment        -> { Left, Center },
    Background       -> bgColor,
    BaselinePosition -> Baseline,
    FrameMargins     -> { { 4, 4 }, { 2, 2 } },
    FrameStyle       -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
    ImageMargins     -> { { 0, 7 }, { 0, 0 } },
    ImageSize        -> Scaled[ 1. ],
    RoundingRadius   -> 4
]

chatMenuItemAppearanceBasic // endDefinition;


chatMenuItemAppearance // beginDefinition;

(* crossing streams a bit here with the NotebookToolbar paclet... *)
chatMenuItemAppearance[ icon_, text_, includeNavArrowQ_:False ] :=
NotebookTools`Mousedown[
    chatMenuItemAppearanceBasic[ icon, text, $TransparentBackground,  $TransparentBackground, $ControlFontColorDefault, $NavigationColorDefault, includeNavArrowQ ],
    chatMenuItemAppearanceBasic[ icon, text, $MatchContentBackground, $FrameColorHover,       $ControlFontColorHover,   $NavigationColorHover,   includeNavArrowQ ],
    chatMenuItemAppearanceBasic[ icon, text, $MatchContentBackground, $FrameColorPressed,     $ControlFontColorPressed, $NavigationColorPressed, includeNavArrowQ ],
    BaselinePosition -> Baseline
]

chatMenuItemAppearance // endDefinition;


(* ::**************************************************************************************************************:: *)
linkTrailFrame // beginDefinition;

Attributes[ linkTrailFrame ] = { HoldRest };

linkTrailFrame[ text_, action_ ] :=
Overlay[
    {
        Framed[
            Grid[
                { {
                    Button[
                        NotebookTools`Mousedown[
                            backButtonAppearanceBasic[ $NavigationColorDefault, $MatchContentBackground, $FrameColorDefault ],
                            backButtonAppearanceBasic[ $NavigationColorHover,   $MatchContentBackground, $FrameColorHover ],
                            backButtonAppearanceBasic[ $NavigationColorPressed, $MatchContentBackground, $FrameColorPressed ],
                            BaselinePosition -> Baseline
                        ],
                        action,
                        Appearance       -> "Suppressed",
                        BaselinePosition -> Baseline,
                        ImageSize        -> Automatic,
                        Method           -> "Queued"
                    ],
                    text
                } },
                BaselinePosition -> { { 1, 2 }, Baseline },
                BaseStyle        -> { FontFamily -> "Source Sans Pro", FontSize -> 14 }
            ],
            Alignment        -> { Left, Center },
            Background       -> $MainBackground,
            BaselinePosition -> Baseline,
            FrameMargins     -> { { 9, 0 }, { 0, 0 } },
            FrameStyle       -> $MainBackground,
            ImageSize        -> { Scaled[ 1. ], 30 }
        ],
        Graphics[Background -> $DividerColor, ImageSize -> { Scaled[ 1 ], 1 }, AspectRatio -> Full ]
    },
    { 1, 2 },
    1,
    Alignment -> { Left, Bottom }
]


linkTrailFrame // endDefinition;

(* ::**************************************************************************************************************:: *)
scrollablePane // beginDefinition;

scrollablePane[ content_, mag_, extraHeightRemoved_, sideBarNotebook_NotebookObject ] :=
DynamicModule[ { height },
    DynamicWrapper[
        Pane[
            content,
            AppearanceElements -> { },
            FrameMargins       -> { { 0, 0 }, { 4, 0 } },
            Scrollbars         -> { False, Automatic },
            ImageSize          -> Dynamic[ { Scaled[ 1. ], height } ] ],
        
        (* only change the allowed height if dynamic updating is enabled *)
        If[ MatchQ[ CurrentValue[ sideBarNotebook, DynamicUpdating ], True | Automatic ],
            height = (AbsoluteCurrentValue[ "ViewSize" ][[ 2 ]]/mag - extraHeightRemoved) (* ViewSize is a 15.0 addition *)
        ]
    ]
]

scrollablePane // endDefinition;

(* ::**************************************************************************************************************:: *)
resetButtonAppearanceBasic // beginDefinition;

(* crossing streams a bit here with the NotebookToolbar paclet... *)
resetButtonAppearanceBasic[ iconColor_, bgColor_, frameColor_ ] :=
Framed[
    Dynamic[ RawBoxes[ FEPrivate`FrontEndResource[ "NotebookToolbarExpressions", "NPResetIcon" ][ iconColor ] ] ],
    Alignment        -> { Center, Center },
    Background       -> bgColor,
    BaselinePosition -> Baseline,
    FrameMargins     -> 0,
    FrameStyle       -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
    ImageSize        -> { 16, 16 },
    RoundingRadius   -> 4
]

resetButtonAppearanceBasic // endDefinition;

(* ::**************************************************************************************************************:: *)
resetButtonAppearance // beginDefinition;

resetButtonAppearance[ ] :=
NotebookTools`Mousedown[
    resetButtonAppearanceBasic[ $ResetButtonPressed, $TransparentBackground,  $TransparentBackground] ,
    resetButtonAppearanceBasic[ $ResetButtonHover,   $MatchContentBackground, $FrameColorHover ],
    resetButtonAppearanceBasic[ $ResetButtonPressed, $MatchContentBackground, $FrameColorPressed ],
    BaselinePosition -> Baseline
]

resetButtonAppearance // endDefinition;

(* ::**************************************************************************************************************:: *)
resetButton // beginDefinition;

(* 464865: dynamic conditions based on CurrentValue[..., {"Options", ...}] may not refresh so do it manually.
    The trigger is a DM variable external to this control because we must pass state between two grid elements. *)
resetButton[ Hold @ forceUpdate_, Hold @ condition_, Hold @ action_ ] :=
PaneSelector[
    {
        True ->
            fancyTooltip[
                Button[
                    resetButtonAppearance[ ],
                    action; forceUpdate = RandomReal[ ],
                    Appearance       -> "Suppressed",
                    BaselinePosition -> Baseline,
                    ImageSize        -> Automatic,
                    Method           -> "Queued"
                ],
                Dynamic[ FEPrivate`FrontEndResource[ "NotebookToolbarStrings", "NPResetInheritanceTooltip" ] ]
            ],
        False -> Graphics[ Background -> None, BaselinePosition -> (Center -> Center), ImageSize -> { 1, 1 } ] },
    Dynamic[ forceUpdate; condition ],
    BaselinePosition -> Baseline,
    FrameMargins     -> { { 9, 0 }, { 0, 0 } },
    ImageSize        -> { 25, Automatic }
]

resetButton // endDefinition;

(* ::**************************************************************************************************************:: *)
addResetButton // beginDefinition;

addResetButton[ spec_, content_ ] :=
If[ KeyExistsQ[ spec, "ResetCondition" ],
    DynamicModule[ { forceUpdate },
        Grid[
            {
                {
                    resetButton[ Hold @ forceUpdate, Lookup[ spec, "ResetCondition", Hold @ Null, Hold ], Lookup[ spec, "ResetAction", Hold @ Null, Hold ] ],
                    content } },
            BaseStyle        -> Lookup[ spec, "ResetCondition", Automatic, Function[ Null, Dynamic[ { FontWeight -> If[ #, Bold, Automatic ] } ], HoldFirst ] ],
            BaselinePosition -> { { 1, 1 }, Baseline },
            Spacings         -> { 0, 0 }
        ]
    ],
    Grid[
        { { Pane["", ImageSize -> { 25, Automatic } ], content } },
        BaselinePosition -> { { 1, 1 }, Baseline },
        Spacings         -> { 0, 0 } ]
]

addResetButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sideBarMenuItem*)
sideBarMenuItem // beginDefinition;

Attributes[ sideBarMenuItem ] = { HoldRest };

sideBarMenuItem[ spec: KeyValuePattern[ "Type" -> type_String ], generatedMenu_, aiPane_, modelPaneLabel_, sideBarNotebook_ ] :=
Switch[ type,
    "Button",    sideBarMenuItemButton[ spec, sideBarNotebook ],
    "Custom",    sideBarMenuItemCustom[ spec ],
    "Delayed",   sideBarMenuItemDelayed[ spec, generatedMenu, aiPane, modelPaneLabel, sideBarNotebook ],
    "Delimiter", sideBarMenuDelimiter[ ],
    "Header",    sideBarMenuSectionHeader[ spec ],
    "Refresh",   sideBarMenuRefresh[ spec, generatedMenu ],
    "Submenu",   sideBarMenuItemSubmenuGenerator[ spec, generatedMenu, aiPane, modelPaneLabel, sideBarNotebook ],
    "Setter",    sideBarMenuItemSetter[ spec, sideBarNotebook ],
    _,           None
]

sideBarMenuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarMenuItemButton*)
sideBarMenuItemButton // beginDefinition

Attributes[ sideBarMenuItemButton ] = { HoldRest };

sideBarMenuItemButton[ spec : KeyValuePattern[ "Action" :> eval_ ], sideBarNotebook_ ] :=
Module[ { icon, label },
    label = Lookup[ spec, "Label", "" ];
    icon = sideBarMenuItemIcon[ spec, sideBarNotebook ];
    
    addResetButton[
        spec, 
        Button[
            chatMenuItemAppearance[ icon, label ],
            eval,
            Appearance -> $suppressButtonAppearance,
            Evaluator  -> Lookup[ spec, "Evaluator", Automatic ],
            ImageSize  -> Automatic,
            Method     -> Lookup[ spec, "Method", "Queued" ]
        ]
    ]
]

sideBarMenuItemButton // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarMenuItemCustom*)
sideBarMenuItemCustom // beginDefinition

sideBarMenuItemCustom[ spec_Association?AssociationQ ] := addResetButton[ spec, Lookup[ spec, "Content", None ] ]

sideBarMenuItemCustom // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarMenuItemDelayed*)
sideBarMenuItemDelayed // beginDefinition

Attributes[ sideBarMenuItemDelayed ] = { HoldRest };

sideBarMenuItemDelayed[ spec : KeyValuePattern[ "FinalMenu" :> eval_ ], generatedMenu_, aiPane_, modelPaneLabel_, sideBarNotebook_ ] :=
DynamicModule[ { display },
    display =
        Column @
            Map[
                sideBarMenuItem[ #, generatedMenu, aiPane, modelPaneLabel, sideBarNotebook ]&,
                Lookup[ spec, "InitialMenu", { } ]
            ];

    Dynamic @ display,

    Initialization :> (
        display =
            Column @
                Map[
                    sideBarMenuItem[ #, generatedMenu, aiPane, modelPaneLabel, sideBarNotebook ]&,
                    eval
                ]
    ),

    SynchronousInitialization -> False,
    InheritScope -> True
]

sideBarMenuItemDelayed // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarMenuDelimiter*)
sideBarMenuDelimiter // beginDefinition

sideBarMenuDelimiter[ ] := RawBoxes @ TemplateBox[ { }, "ChatMenuItemDelimiter" ]

sideBarMenuDelimiter // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarMenuSectionHeader*)
sideBarMenuSectionHeader // beginDefinition

sideBarMenuSectionHeader[ spec_Association?AssociationQ ] :=
Module[ { label },
    label = Lookup[ spec, "Label", "" ];

    (* This is effectively the "ChatMenuSection" TemplateBox but with reduced margins *)
    Framed[
        Overlay[
            {
                Grid[
                    { {
                            Pane[
                                Style[ addResetButton[ spec, label ], "ChatMenuSectionLabel" ],
                                FrameMargins     -> { { 0, 0 }, { 0, 7 } },
                                ImageMargins     -> 0,
                                BaselinePosition -> Baseline,
                                ImageSize        -> Scaled[ 1. ]
                            ]
                    } },
                    Alignment -> { Left, Baseline },
                    Spacings  -> { 0, 0 }
                ],
                Graphics[ Background -> $DividerColor, ImageSize -> { Scaled[ 1 ], 1 }, AspectRatio -> Full ]
            },
            { 1, 2 },
            1,
            Alignment -> { Left, Top }
        ],
        Background       -> $TransparentBackground,
        BaselinePosition -> Baseline,
        FrameMargins     -> { { -1, 2 }, { 2, 2 } },
        FrameStyle       -> $TransparentBackground,
        ImageMargins     -> { { 0, 0 }, { 0, 0 } },
        ImageSize        -> Scaled[ 1. ],
        RoundingRadius   -> 0
    ]
]

sideBarMenuSectionHeader // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarMenuRefresh*)
sideBarMenuRefresh // beginDefinition

Attributes[ sideBarMenuRefresh ] = { HoldRest };

sideBarMenuRefresh[ spec : KeyValuePattern[ { "InitialMenu" :> start_, "FinalMenu" :> end_ } ], generatedMenu_ ] :=
Module[ { label },
    label = Lookup[ spec, "Label", "" ];
    
    Button[
        chatMenuItemAppearance[ "", label ],
        generatedMenu = start; generatedMenu = end,
        Appearance -> $suppressButtonAppearance,
        Evaluator  -> Lookup[ spec, "Evaluator", Automatic ],
        ImageSize  -> Automatic,
        Method     -> Lookup[ spec, "Method", "Queued" ]
    ]
]

sideBarMenuRefresh // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarMenuItemSubmenuGenerator*)
sideBarMenuItemSubmenuGenerator // beginDefinition

Attributes[ sideBarMenuItemSubmenuGenerator ] = { HoldRest };

sideBarMenuItemSubmenuGenerator[ spec : KeyValuePattern[ { "MenuTag" -> tag_String, "Menu" :> menu_, "Category" -> "Service" } ], generatedMenu_, aiPane_, modelPaneLabel_, sideBarNotebook_ ] :=
Module[ { icon, label },
    label = Lookup[ spec, "Label", "" ];
    icon = sideBarMenuItemIcon[ spec, sideBarNotebook ];
    
    addResetButton[
        spec,
        Button[
            chatMenuItemAppearance[ icon, label, True ],
            (
                generatedMenu = menu;
                aiPane = "ModelNames";
                modelPaneLabel = tag),
            Appearance -> $suppressButtonAppearance,
            Evaluator  -> Lookup[ spec, "Evaluator", Automatic ],
            ImageSize  -> Automatic,
            Method     -> Lookup[ spec, "Method", "Queued" ]
        ]
    ]
]

sideBarMenuItemSubmenuGenerator[ spec : KeyValuePattern[ "MenuTag" -> tag_String ], generatedMenu_, aiPane_, modelPaneLabel_, sideBarNotebook_ ] :=
Module[ { icon, label },
    label = Lookup[ spec, "Label", "" ];
    icon = sideBarMenuItemIcon[ spec, sideBarNotebook ];
    
    addResetButton[
        spec,
        Button[
            chatMenuItemAppearance[ icon, label, True ],
            aiPane = tag,
            Appearance -> $suppressButtonAppearance,
            Evaluator  -> Lookup[ spec, "Evaluator", Automatic ],
            ImageSize  -> Automatic,
            Method     -> Lookup[ spec, "Method", "Queued" ]
        ]
    ]
]

sideBarMenuItemSubmenuGenerator // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarMenuItemSetter*)
sideBarMenuItemSetter // beginDefinition

Attributes[ sideBarMenuItemSetter ] = { HoldRest };

sideBarMenuItemSetter[ spec : KeyValuePattern[ "Action" :> eval_ ], sideBarNotebook_ ] :=
Module[ { icon, label },
    label = Lookup[ spec, "Label", "" ];
    icon = sideBarMenuItemIcon[ spec, sideBarNotebook ];
    
    addResetButton[
        spec, 
        Button[
            chatMenuItemAppearance[ icon, label ],
            eval,
            Appearance -> $suppressButtonAppearance,
            Evaluator  -> Lookup[ spec, "Evaluator", Automatic ],
            ImageSize  -> Automatic,
            Method     -> Lookup[ spec, "Method", "Queued" ]
        ]
    ]
]

sideBarMenuItemSetter // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarMenuItemIcon*)
sideBarMenuItemIcon // beginDefinition

Attributes[ sideBarMenuItemIcon ] = { HoldRest };

(* The sideBar is persistent so keep the check marks up-to-date in all categories *)
(* Note: we've deemed it looks best to have the check mark always darker in color regardless of whether it's inherited *)
sideBarMenuItemIcon[ spec_Association?AssociationQ, sideBarNotebook_ ] :=
With[ { val = Lookup[ spec, "Value", None ], c1 = color @ "ChatMenuItemCheckmarkTrue", c2 = color @ "ChatMenuItemCheckmarkInherited" },
Row[ Flatten @ {
    Switch[ Lookup[ spec, "Category", None ],
        "Persona",
            Dynamic[
                Function[
                    If[ #1 === Inherited,
                        If[ #2 === val, Style[ "\[Checkmark]", FontColor -> c1 ], Style[ "\[Checkmark]", ShowContents -> False ] ],
                        If[ #1 === val, Style[ "\[Checkmark]", FontColor -> c1 ], Style[ "\[Checkmark]", ShowContents -> False ] ] ]
                ][
                    CurrentValue[ sideBarNotebook , { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ],
                    Wolfram`Chatbook`CurrentChatSettings[ sideBarNotebook , "LLMEvaluator" ] ]
            ],
        "Service",
            Dynamic[
                Function[
                    If[ #1 === Inherited,
                        If[ Lookup[ #2, "Service", None ] === val, Style[ "\[Checkmark]", FontColor -> c1 ], Style[ "\[Checkmark]", ShowContents -> False ] ],
                        If[ Lookup[ #1, "Service", None ] === val, Style[ "\[Checkmark]", FontColor -> c1 ], Style[ "\[Checkmark]", ShowContents -> False ] ] ]
                ][
                    CurrentValue[ sideBarNotebook , { TaggingRules, "ChatNotebookSettings", "Model" } ],
                    Wolfram`Chatbook`CurrentChatSettings[ sideBarNotebook , "Model" ] ]
            ],
        "ModelName",
            Dynamic[
                Function[
                    If[ #1 === Inherited,
                        If[ Lookup[ #2, "Name", None ] === val, Style[ "\[Checkmark]", FontColor -> c1 ], Style[ "\[Checkmark]", ShowContents -> False ] ],
                        If[ Lookup[ #1, "Name", None ] === val, Style[ "\[Checkmark]", FontColor -> c1 ], Style[ "\[Checkmark]", ShowContents -> False ] ] ]
                ][
                    CurrentValue[ sideBarNotebook , { TaggingRules, "ChatNotebookSettings", "Model" } ],
                    Wolfram`Chatbook`CurrentChatSettings[ sideBarNotebook , "Model" ] ]
            ],
        None,
            "" ],
    Lookup[ spec, "Icon", { " ", resizeMenuIcon @ Graphics[ Background -> Red ] }, Replace[ #, { None :> Nothing, _ :> { " ", resizeMenuIcon @ # } } ]& ]
} ]
]

sideBarMenuItemIcon // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MakeMenu*)
MakeMenu // beginDefinition;

Options[ MakeMenu ] = {
    CellFrameColor -> color @ "ChatMenuFrame",
    ImageSize      -> { 200, UpTo[ 450 ] },
    TaggingRules   -> <||>
};

MakeMenu[ items_List, OptionsPattern[] ] :=
Module[ { data, isRootMenu, rootCell, parentCell, menuWidth },
    data = Replace[ OptionValue @ TaggingRules, Except[ _Association ] -> <||> ];
    
    isRootMenu   = Lookup[ data, "IsRoot",   False, TrueQ ];
    parentCell   = Lookup[ data, "Anchor",   None ];
    rootCell     = Lookup[ data, "RootCell", Dynamic @ None, Dynamic ];
    
    menuWidth    = Replace[ Lookup[ data, "Width", OptionValue @ ImageSize ], { { n_?NumericQ, _ } :> n, n_?NumericQ :> n, _ :> 200 } ];
    
    Which[
        (* Case: modified root menu, spawned from default toolbar *)
        isRootMenu && parentCell === None,
            DynamicModule[ { rootMenuCell, subMenuCell = None },
                menuPane[
                    Map[ menuItem[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, Dynamic @ None, #, menuWidth ]&, items ],
                    OptionValue @ ImageSize
                ],
                Initialization :> (rootMenuCell = EvaluationCell[ ])
            ],
        (* Case: root menu attached to CellDingbat *)
        isRootMenu,
            With[
                {
                    pos = Replace[ MousePosition[ "WindowScaled" ], { { _, y_ } :> y, _ :> 0 } ],
                    mag = menuMagnification @ Lookup[ data, "ActionScope", EvaluationNotebook[ ], Replace[ #, Except[ _CellObject | _NotebookObject ] -> EvaluationNotebook[ ] ]& ]
                },
                AttachCell[
                    parentCell,
                    Cell[ BoxData @ ToBoxes @
                        DynamicModule[ { rootMenuCell, subMenuCell = None },
                            menuFrame[
                                Map[ menuItem[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, Dynamic @ None, #, menuWidth ]&, items ],
                                OptionValue @ ImageSize,
                                OptionValue @ CellFrameColor
                            ],
                            Initialization :> (rootMenuCell = EvaluationCell[ ])
                        ],
                        "AttachedChatMenu",
                        Magnification -> mag
                    ],
                    { Left, If[ pos < 0.5, Bottom, Top ] },
                    Offset[ { 0, 0 }, { Left, Top } ],
                    { Left, If[ pos < 0.5, Top, Bottom ] },
                    RemovalConditions -> { "MouseClickOutside", "EvaluatorQuit" }
                ]
            ],
        (* Case: submenu attached to parent menu *)
        True,
            AttachSubmenu[
                EvaluationBox[], 
                With[ { v = Unique[ "subMenuCell" ] },
                    DynamicModule[ { v = None },
                        menuFrame[
                            Map[ menuItem[ rootCell, Dynamic @ v, Dynamic @ None, #, menuWidth ]&, items ],
                            OptionValue @ ImageSize,
                            OptionValue @ CellFrameColor
                        ],
                        InheritScope   -> True (* very important such that child attached cells can reference the root CellObject *)
                    ]
                ],
                Lookup[ data, "MenuTag", "None" ]
            ]
    ]

]

    (* menuFrame[ menuItem /@ items, OptionValue @ ImageSize, OptionValue @ CellFrameColor ] *)

MakeMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*menuFrame*)
menuFrame // beginDefinition;

menuFrame[ resolvedItems_List, imageSize_, frameColor_ ] :=
Framed[
    menuPane[ resolvedItems, imageSize ],
    Background       -> color @ "ChatMenuItemBackground",
    BaselinePosition -> Baseline,
    FrameMargins     -> 3,
    FrameStyle       -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
    ImageMargins     -> 0,
    RoundingRadius   -> 3
];

menuFrame // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*menuPane*)
menuPane // beginDefinition;

menuPane[ resolvedItems_List, imageSize_ ] :=
Pane[
    Column[ resolvedItems, ItemSize -> Automatic, Spacings -> 0, Alignment -> Left ],
    AppearanceElements -> None,
    ImageSize          -> imageSize,
    Scrollbars         -> { False, Automatic }
];

menuPane // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*menuItem*)
menuItem // beginDefinition;

menuItem[ Dynamic[ rootMenuCell_ ], Dynamic[ subMenuCell_ ], Dynamic[ displayDMVariable_ ], spec: KeyValuePattern[ "Type" -> type_String ], menuWidth_ ] :=
Switch[ type,
    "Button",    menuItemButton[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, spec, menuWidth ],
    "Custom",    menuItemCustom[ Dynamic @ subMenuCell, spec ],
    "Delayed",   menuItemDelayed[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, Dynamic @ displayDMVariable, spec, menuWidth ],
    "Delimiter", menuDelimiter[ Dynamic @ subMenuCell ],
    "Header",    menuSectionHeader[ Dynamic @ subMenuCell, spec, menuWidth ],
    "Refresh",   menuRefresh[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, Dynamic @ displayDMVariable, spec, menuWidth ],
    "Submenu",   menuItemSubmenuGenerator[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, spec, menuWidth ],
    "Setter",    menuItemSetter[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, spec, menuWidth ],
    _,           None
]

menuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuItemIcon*)
menuItemIcon // beginDefinition

menuItemIcon[ spec_Association?AssociationQ ] :=
If[ Lookup[ spec, "Check", None ] === None,
    Lookup[ spec, "Icon", resizeMenuIcon @ Graphics[ Background -> Red ], Replace[ #, { None :> "", _ :> resizeMenuIcon @ # } ]& ]
    ,
    Row[ Flatten @ {
        Switch[ Lookup[ spec, "Check", False ],
            True,      Style[ "\[Checkmark]", FontColor -> color @ "ChatMenuItemCheckmarkTrue" ],
            Inherited, Style[ "\[Checkmark]", FontColor -> color @ "ChatMenuItemCheckmarkInherited" ],
            _,         Style[ "\[Checkmark]", ShowContents -> False ]
        ],
        Lookup[ spec, "Icon", { " ", resizeMenuIcon @ Graphics[ Background -> Red ] }, Replace[ #, { None :> Nothing, _ :> { " ", resizeMenuIcon @ # } } ]& ]
    } ]
]

menuItemIcon // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuItemCustom*)
menuItemCustom // beginDefinition

menuItemCustom[ Dynamic[ subMenuCell_ ], spec_Association?AssociationQ ] :=
addSubmenuHandler[
    Lookup[ spec, "Content", None ],
    Dynamic @ subMenuCell
]

menuItemCustom // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuItemDelayed*)
menuItemDelayed // beginDefinition

menuItemDelayed[ Dynamic[ rootMenuCell_ ], Dynamic[ subMenuCell_ ], Dynamic[ displayDMVariable_ ], spec : KeyValuePattern[ "FinalMenu" :> eval_ ], menuWidth_ ] :=
addSubmenuHandler[
    DynamicModule[ { display },
        display =
            Column @
                Map[
                    menuItem[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, Dynamic @ display, #, menuWidth ]&,
                    Lookup[ spec, "InitialMenu", { } ]
                ];

        Dynamic @ display,

        Initialization :> (
            display =
                Column @
                    Map[
                        menuItem[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, Dynamic @ display, #, menuWidth ]&,
                        eval
                    ]
        ),

        SynchronousInitialization -> False,
        InheritScope -> True
    ],
    Dynamic @ subMenuCell
]

menuItemDelayed // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuRefresh*)
menuRefresh // beginDefinition

menuRefresh[ Dynamic[ rootMenuCell_ ], Dynamic[ subMenuCell_ ], Dynamic[ displayDMVariable_ ], spec : KeyValuePattern[ { "InitialMenu" :> start_, "FinalMenu" :> end_ } ], menuWidth_ ] :=
Module[ { label },
    label = lineWrap[ Lookup[ spec, "Label", "" ], menuWidth ];
        
    Button[
        RawBoxes @ TemplateBox[ { ToBoxes @ Spacer[0], ToBoxes @ label }, "ChatMenuItem" ],
        displayDMVariable = Column @
            Map[
                menuItem[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, Dynamic @ displayDMVariable, #, menuWidth ]&,
                start
            ];
        displayDMVariable = Column @
            Map[
                menuItem[ Dynamic @ rootMenuCell, Dynamic @ subMenuCell, Dynamic @ displayDMVariable, #, menuWidth ]&,
                end
            ],
        Appearance -> $suppressButtonAppearance,
        Evaluator  -> Lookup[ spec, "Evaluator", Automatic ],
        Method     -> Lookup[ spec, "Method", "Queued" ]
    ]
]

menuRefresh // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuDelimiter*)
menuDelimiter // beginDefinition

menuDelimiter[ Dynamic[ subMenuCell_ ] ] :=
addSubmenuHandler[
    RawBoxes @ TemplateBox[ { }, "ChatMenuItemDelimiter" ],
    Dynamic @ subMenuCell
]

menuDelimiter // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuSectionHeader*)
menuSectionHeader // beginDefinition

menuSectionHeader[ Dynamic[ subMenuCell_ ], spec_Association?AssociationQ, menuWidth_ ] :=
Module[ { label },
    label = lineWrap[ Lookup[ spec, "Label", "" ], menuWidth ];

    addSubmenuHandler[
        RawBoxes @ TemplateBox[ { ToBoxes @ label }, "ChatMenuSection" ],
        Dynamic @ subMenuCell
    ]
]

menuSectionHeader // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuItemSetter*)
menuItemSetter // beginDefinition

menuItemSetter[ Dynamic[ rootMenuCell_ ], Dynamic[ subMenuCell_ ], spec : KeyValuePattern[ "Action" :> eval_ ], menuWidth_ ] :=
Module[ { icon, label },
    label = lineWrap[ Lookup[ spec, "Label", "" ], menuWidth - 60 ];
    icon = menuItemIcon @ spec;
    
    addSubmenuHandler[
        Button[
            RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label }, "ChatMenuItem" ],
            NotebookDelete @ rootMenuCell; eval,
            Appearance -> $suppressButtonAppearance,
            Evaluator  -> Lookup[ spec, "Evaluator", Automatic ],
            Method     -> Lookup[ spec, "Method", "Queued" ]
        ],
        Dynamic @ subMenuCell
    ]
]

menuItemSetter // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuItemButton*)
menuItemButton // beginDefinition

menuItemButton[ Dynamic[ rootMenuCell_ ], Dynamic[ subMenuCell_ ], spec : KeyValuePattern[ "Action" :> eval_ ], menuWidth_ ] :=
Module[ { icon, label },
    label = lineWrap[ Lookup[ spec, "Label", "" ], menuWidth ];
    icon = menuItemIcon @ spec;
    
    addSubmenuHandler[
        Button[
            RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label }, "ChatMenuItem" ],
            NotebookDelete @ rootMenuCell; eval,
            Appearance -> $suppressButtonAppearance,
            Evaluator  -> Lookup[ spec, "Evaluator", Automatic ],
            Method     -> Lookup[ spec, "Method", "Queued" ]
        ],
        Dynamic @ subMenuCell
    ]
]

menuItemButton // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuItemSubmenuGenerator*)
menuItemSubmenuGenerator // beginDefinition

menuItemSubmenuGenerator[ Dynamic[ rootMenuCell_ ], Dynamic[ subMenuCell_ ], spec : KeyValuePattern[ "Menu" :> action_ ], menuWidth_ ] :=
With[
    {
        label = submenuLabel @ Lookup[ spec, "Label", "" ],
        icon = menuItemIcon @ spec,
        newMenuSize = { Lookup[ spec, "Width", menuWidth ], UpTo[ 450 ] },
        menuTag = Lookup[ spec, "MenuTag", "None", Replace[ #, Except[ _String ] -> "None" ]& ] (* FIXME: Throw error if there's no menu tag? *)
    },
    
    EventHandler[
        RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label }, "ChatMenuItem" ],
        {
            "MouseEntered" :> (
                If[ subMenuCell =!= None,
                    If[ CurrentValue[ subMenuCell, { TaggingRules, "MenuTag" } ] =!= menuTag,
                        NotebookDelete @ subMenuCell;
                        subMenuCell = MakeMenu[ action, ImageSize -> newMenuSize, TaggingRules -> <| "MenuTag" -> menuTag, "RootCell" :> rootMenuCell |> ]
                    ]
                    ,
                    subMenuCell = MakeMenu[ action, ImageSize -> newMenuSize, TaggingRules -> <| "MenuTag" -> menuTag, "RootCell" :> rootMenuCell |> ]
                ]
            ),
            "MouseDown" :> (
                If[ subMenuCell =!= None,
                    If[ CurrentValue[ subMenuCell, { TaggingRules, "MenuTag" } ] =!= menuTag,
                        NotebookDelete @ subMenuCell;
                        subMenuCell = MakeMenu[ action, ImageSize -> newMenuSize, TaggingRules -> <| "MenuTag" -> menuTag, "RootCell" :> rootMenuCell |> ]
                    ]
                    ,
                    subMenuCell = MakeMenu[ action, ImageSize -> newMenuSize, TaggingRules -> <| "MenuTag" -> menuTag, "RootCell" :> rootMenuCell |> ]
                ]
            )
        },
        Method -> "Queued"
    ]
]

menuItemSubmenuGenerator // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*lineWrap*)

lineWrap // beginDefinition;

lineWrap[ content_, width_ : 170 ] :=
Pane[
    content,
    width,
    BaselinePosition -> Baseline, BaseStyle -> { LineBreakWithin -> Automatic, LineIndent -> -0.05, LinebreakAdjustments -> { 1, 10, 1, 0, 1 } } ]

lineWrap // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addSubmenuHandler*)
addSubmenuHandler // beginDefinition;

addSubmenuHandler[ expr_, Dynamic[ subMenuCell_ ] ] := EventHandler[
    expr,
    {
        "MouseEntered" :> (
            If[ subMenuCell =!= None, NotebookDelete @ subMenuCell; subMenuCell = None ]
        )
    }
];

addSubmenuHandler[ expr_ ] := expr;

addSubmenuHandler // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sideBarSubMenuLabel*)
sideBarSubMenuLabel // beginDefinition;

sideBarSubMenuLabel[ label_ ] := Grid[
    { {
        Item[ label, ItemSize -> Fit, Alignment -> Left ],
        Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "Triangle" ] } },
    Spacings -> 0
];

sideBarSubMenuLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*submenuLabel*)
submenuLabel // beginDefinition;

submenuLabel[ label_ ] := Grid[
    { { Item[ label, ItemSize -> Fit, Alignment -> Left ], Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "Triangle" ] } },
    Spacings -> 0
];

submenuLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AttachSubmenu*)
AttachSubmenu // beginDefinition;

AttachSubmenu[ parentMenu_, expr_, menuTag_String ] := Enclose[
    Module[ { parentInfo, root, pos, oPos, offsetX, offsetY, magnification, tags, attached },

        parentInfo = Replace[
            Association @ CurrentValue[ parentMenu, TaggingRules ],
            Except[ _? AssociationQ ] :> <| |>
        ];

        { pos, oPos } = ConfirmMatch[ determineAttachmentPosition @ parentInfo, { { _, _ }, { _, _ } }, "Position" ];
        offsetX = If[ MatchQ[ pos, { Left, _ } ], -3, 3 ];
        offsetY = If[ MatchQ[ pos, { _, Top } ], 5, -5 ];

        magnification = Replace[
            Lookup[ parentInfo, "Magnification", AbsoluteCurrentValue[ parentMenu, Magnification ] ],
            Except[ _? NumberQ ] :> If[ $OperatingSystem === "Windows", 0.75, 1 ]
        ];

        tags = <| parentInfo, "Magnification" -> magnification, "Position" -> { pos, oPos }, "MenuTag" -> menuTag |>;

        attached = AttachCell[
            parentMenu,
            Cell[ BoxData @ ToBoxes @ expr, "AttachedChatSubMenu", Magnification -> magnification, TaggingRules -> tags ],
            pos,
            Offset[ { offsetX, offsetY }, { 0, 0 } ],
            oPos
        ];

        attached
    ],
    throwInternalFailure
];

AttachSubmenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*menuMagnification*)
menuMagnification // beginDefinition;
menuMagnification[ obj_ ] := menuMagnification[ $OperatingSystem, AbsoluteCurrentValue[ obj, Magnification ] ];
menuMagnification[ "Windows", magnification_? NumberQ ] := Min[ magnification * 0.75, 1.5 ];
menuMagnification[ _, magnification_ ] := magnification;
menuMagnification // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*determineAttachmentPosition*)
determineAttachmentPosition // beginDefinition;

determineAttachmentPosition[ KeyValuePattern[ "Position" -> { { pH_, pV_ }, { oH_, oV_ } } ] ] :=
    { { pH, pV }, { oH, chooseVerticalOffset @ MousePosition[ "WindowScaled" ] } };

determineAttachmentPosition[ _Association ] :=
    determineAttachmentPosition @ MousePosition[ "WindowScaled" ];

determineAttachmentPosition[ pos_List ] :=
    determineAttachmentPosition[ pos, quadrant @ pos ];

determineAttachmentPosition[ { x_, y_ }, { h_, v_ } ] := {
    { Replace[ h, { Left -> Right, Right -> Left } ], v },
    { h, chooseVerticalOffset @ { x, y } }
};

determineAttachmentPosition[ None ] :=
    { { Right, Top }, { Left, Top } };

determineAttachmentPosition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chooseVerticalOffset*)
chooseVerticalOffset // beginDefinition;
chooseVerticalOffset[ { x_, y_ } ] /; y < 0.33 := Top;
chooseVerticalOffset[ { x_, y_ } ] /; y > 0.67 := Bottom;
chooseVerticalOffset[ { x_, y_ } ] := Center;
chooseVerticalOffset // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*quadrant*)
quadrant // beginDefinition;
quadrant[ None ] := None;
quadrant[ { x_? NumberQ, y_? NumberQ } ] := quadrant[ TrueQ[ x >= 0.5 ], TrueQ[ y >= 0.67 ] ];
quadrant[ True , True  ] := { Right, Bottom };
quadrant[ True , False ] := { Right, Top    };
quadrant[ False, True  ] := { Left , Bottom };
quadrant[ False, False ] := { Left , Top    };
quadrant // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attaching and Removing Menus*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeChatMenus*)
removeChatMenus // beginDefinition;

removeChatMenus[ obj: $$feObj ] :=
    With[ { root = CurrentValue[ obj, { TaggingRules, "MenuData", "Root" } ] },
        NotebookDelete @ root /; MatchQ[ root, _CellObject ]
    ];

removeChatMenus[ box_BoxObject ] :=
    removeChatMenus @ parentCell @ box;

removeChatMenus[ cell_CellObject ] /; MemberQ[ cellStyles @ cell, "AttachedChatMenu" ] :=
    removeChatMenus @ parentCell @ cell;

removeChatMenus[ cell_CellObject ] :=
    NotebookDelete @ Cells[ cell, AttachedCell -> True, CellStyle -> "AttachedChatMenu" ];

(* Cell has already been removed: *)
removeChatMenus[ $Failed ] :=
    Null;

removeChatMenus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];