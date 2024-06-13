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

MakeMenu[ items_List ] :=
    MakeMenu[ items, Automatic ];

MakeMenu[ items_List, frameColor_ ] :=
    MakeMenu[ items, frameColor, Automatic ];

MakeMenu[ items_List, Automatic, width_ ] :=
    MakeMenu[ items, GrayLevel[ 0.85 ], width ];

MakeMenu[ items_List, frameColor_, Automatic ] :=
    MakeMenu[ items, frameColor, 200 ];

MakeMenu[ items_List, frameColor_, width_ ] /;
    ! $submenuItems && MemberQ[ items, KeyValuePattern[ "Type" -> "Submenu" ] ] :=
        Block[ { $submenuItems = True }, MakeMenu[ items, frameColor, width ] ];

MakeMenu[ items_List, frameColor_, width_ ] :=
    RawBoxes @ TemplateBox[
        {
            ToBoxes @ Pane[
                Column[ menuItem /@ items, ItemSize -> Automatic, Spacings -> 0, Alignment -> Left ],
                AppearanceElements -> None,
                ImageSize          -> { width, UpTo[ 450 ] },
                Scrollbars         -> { False, Automatic }
            ],
            Background     -> GrayLevel[ 0.98 ],
            FrameMargins   -> 3,
            FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
            ImageMargins   -> 0,
            RoundingRadius -> 3
        },
        "Highlighted"
    ];

MakeMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*menuItem*)
menuItem // beginDefinition;

menuItem[ spec: KeyValuePattern[ "Data" -> content_ ] ] :=
    menuItem @ <| spec, "Data" :> content |>;

menuItem[ spec: KeyValuePattern @ { "Type" -> "Submenu", "Data" :> content_ } ] :=
    EventHandler[
        Block[ { $submenuItems = False },
            menuItem[
                Lookup[ spec, "Icon", Spacer[ 0 ] ],
                submenuLabel @ Lookup[ spec, "Label", "" ],
                None
            ]
        ],
        {
            "MouseEntered" :> With[ { root = EvaluationBox[ ] }, AttachSubmenu[ root, content ] ],
            "MouseDown"    :> With[ { root = EvaluationBox[ ] }, AttachSubmenu[ root, content ] ]
        }
    ];

menuItem[ { args__ } ] :=
    menuItem @ args;

menuItem[ Delimiter ] :=
    addSubmenuHandler @ RawBoxes @ TemplateBox[ { }, "ChatMenuItemDelimiter" ];

menuItem[ label_ :> action_ ] :=
    menuItem[ Graphics[ { }, ImageSize -> 0 ], label, Hold @ action ];

menuItem[ section_ ] :=
    addSubmenuHandler @ RawBoxes @ TemplateBox[ { ToBoxes @ section }, "ChatMenuSection" ];

menuItem[ name_String, label_, code_ ] :=
    With[ { icon = chatbookIcon @ name },
        If[ MissingQ @ icon,
            menuItem[ RawBoxes @ TemplateBox[ { name }, "ChatMenuItemToolbarIcon" ], label, code ],
            menuItem[ icon, label, code ]
        ]
    ];

menuItem[ icon_, label_, action_String ] :=
    menuItem[
        icon,
        label,
        Hold @ With[
            { $CellContext`cell = EvaluationCell[ ] },
            { $CellContext`root = ParentCell @ $CellContext`cell },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ action, $CellContext`root ];
            NotebookDelete @ $CellContext`cell;
        ]
    ];

menuItem[ None, content_, None ] :=
    addSubmenuHandler @ content;

menuItem[ icon_, label_, None ] :=
    menuItem[ icon, label, Hold @ Null ];

menuItem[ icon_, label_, code_ ] :=
    addSubmenuHandler @ RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label, code }, "ChatMenuItem" ];

menuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addSubmenuHandler*)
addSubmenuHandler // beginDefinition;

addSubmenuHandler[ expr_ ] /; $submenuItems := EventHandler[
    expr,
    {
        "MouseEntered" :> NotebookDelete @ Cells[
            EvaluationCell[ ],
            AttachedCell -> True,
            CellStyle    -> "AttachedChatMenu"
        ]
    }
];

addSubmenuHandler[ expr_ ] := expr;

addSubmenuHandler // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*submenuLabel*)
submenuLabel // beginDefinition;

submenuLabel[ label_ ] := Grid[
    { { Item[ label, ItemSize -> Fit, Alignment -> Left ], RawBoxes @ TemplateBox[ { }, "Triangle" ] } },
    Spacings -> 0
];

submenuLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AttachSubmenu*)
AttachSubmenu // beginDefinition;

AttachSubmenu[ parentMenu_, submenu: Cell[ __, "AttachedChatMenu", ___ ] ] := Enclose[
    Module[ { parentInfo, root, pos, oPos, offsetX, offsetY, magnification, tags, attached },

        NotebookDelete @ Cells[ parentMenu, AttachedCell -> True, CellStyle -> "AttachedChatMenu" ];

        parentInfo = Replace[
            Association @ CurrentValue[ parentMenu, { TaggingRules, "MenuData" } ],
            Except[ _? AssociationQ ] :> <| |>
        ];

        { pos, oPos } = ConfirmMatch[ determineAttachmentPosition @ parentInfo, { { _, _ }, { _, _ } }, "Position" ];
        offsetX = If[ MatchQ[ pos, { Left, _ } ], -3, 3 ];
        offsetY = If[ MatchQ[ pos, { _, Top } ], 5, -5 ];

        magnification = Replace[
            Lookup[ parentInfo, "Magnification", AbsoluteCurrentValue[ parentMenu, Magnification ] ],
            Except[ _? NumberQ ] :> If[ $OperatingSystem === "Windows", 0.75, 1 ]
        ];

        tags = <| "MenuData" -> <| parentInfo, "Magnification" -> magnification, "Position" -> { pos, oPos } |> |>;

        attached = AttachCell[
            parentMenu,
            Append[ submenu, Unevaluated @ Sequence[ Magnification -> magnification, TaggingRules -> tags ] ],
            pos,
            Offset[ { offsetX, offsetY }, { 0, 0 } ],
            oPos,
            RemovalConditions -> { "MouseClickOutside", "EvaluatorQuit" }
        ];

        If[ ! MatchQ[ tags[ "MenuData", "Root" ], _CellObject ],
            CurrentValue[ attached, { TaggingRules, "MenuData", "Root" } ] = attached;
        ];

        attached
    ],
    throwInternalFailure
];

AttachSubmenu[ parentMenu_, Cell[ boxes_, style__String, opts: OptionsPattern[ ] ] ] :=
    AttachSubmenu[ parentMenu, Cell[ boxes, style, "AttachedChatMenu", opts ] ];

AttachSubmenu[ parentMenu_, expr: Except[ _Cell ] ] :=
    AttachSubmenu[ parentMenu, Cell[ BoxData @ ToBoxes @ expr, "AttachedChatMenu" ] ];

AttachSubmenu[ expr_ ] :=
    AttachSubmenu[ EvaluationCell[ ], expr ];

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
(* ::Subsection::Closed:: *)
(*attachMenuCell*)
attachMenuCell // beginDefinition;

attachMenuCell[ parent: $$feObj, args___ ] :=
    Module[ { attached, root },
        attached = AttachCell[ parent, args ];

        root = Replace[
            CurrentValue[ parent, { TaggingRules, "MenuData", "Root" } ],
            Except[ _CellObject ] :> attached
        ];

        CurrentValue[ attached, { TaggingRules, "MenuData", "Root" } ] = root;

        attached
    ];

attachMenuCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];