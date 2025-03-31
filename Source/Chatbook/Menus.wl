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

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ErrorUtils`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$submenuItems = False;

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
    resizeMenuIcon @ Lookup[ spec, "Icon", Graphics[ Background -> Red ] ]
    ,
    Row[ {
        Switch[ Lookup[ spec, "Check", False ],
            True,      Style[ "\[Checkmark]", FontColor -> color @ "ChatMenuItemCheckmarkTrue" ],
            Inherited, Style[ "\[Checkmark]", FontColor -> color @ "ChatMenuItemCheckmarkInherited" ],
            _,         Style[ "\[Checkmark]", ShowContents -> False ]
        ],
        " ",
        resizeMenuIcon @ Lookup[ spec, "Icon", Graphics[ Background -> Red ] ] } ]
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
                    Lookup[ spec, "InitialMenu", {} ]
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