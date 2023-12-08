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
    `menuMagnification;
    `removeChatMenus;
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
Needs[ "Wolfram`Chatbook`FrontEnd`"   ];

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

MakeMenu[ items_List, frameColor_, width_ ] :=
    Pane[
        RawBoxes @ TemplateBox[
            {
                ToBoxes @ Column[ menuItem /@ items, ItemSize -> Automatic, Spacings -> 0, Alignment -> Left ],
                Background     -> GrayLevel[ 0.98 ],
                FrameMargins   -> 3,
                FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
                ImageMargins   -> 0,
                RoundingRadius -> 3
            },
            "Highlighted"
        ],
        ImageSize -> { width, Automatic }
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
        menuItem[
            Lookup[ spec, "Icon", Spacer[ 0 ] ],
            submenuLabel @ Lookup[ spec, "Label", "" ],
            None
        ],
        {
            "MouseEntered" :> With[ { root = EvaluationBox[ ] }, AttachSubmenu[ root, content ] ]
        }
    ];

menuItem[ { args__ } ] :=
    menuItem @ args;

menuItem[ Delimiter ] :=
    RawBoxes @ TemplateBox[ { }, "ChatMenuItemDelimiter" ];

menuItem[ label_ :> action_ ] :=
    menuItem[ Graphics[ { }, ImageSize -> 0 ], label, Hold @ action ];

menuItem[ section_ ] :=
    RawBoxes @ TemplateBox[ { ToBoxes @ section }, "ChatMenuSection" ];

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
    content;

menuItem[ icon_, label_, None ] :=
    menuItem[ icon, label, Hold @ Null ];

menuItem[ icon_, label_, code_ ] :=
    RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label, code }, "ChatMenuItem" ];

menuItem // endDefinition;

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
AttachSubmenu[ parentMenu_, submenu: Cell[ __, "AttachedChatMenu", ___ ] ] := Enclose[
    Module[ { pos, oPos, offsetX, offsetY, magnification },

        NotebookDelete @ Cells[ parentMenu, AttachedCell -> True, CellStyle -> "AttachedChatMenu" ];
        { pos, oPos } = ConfirmMatch[ determineAttachmentPosition[ ], { { _, _ }, { _, _ } }, "Position" ];
        offsetX = If[ MatchQ[ pos, { Left, _ } ], -3, 3 ];
        offsetY = If[ MatchQ[ pos, { _, Top } ], 5, -5 ];

        magnification = Replace[
            AbsoluteCurrentValue[ parentMenu, Magnification ],
            Except[ _? NumberQ ] :> If[ $OperatingSystem === "Windows", 0.75, 1 ]
        ];

        AttachCell[
            parentMenu,
            Append[ submenu, Magnification -> magnification ],
            pos,
            Offset[ { offsetX, offsetY }, { 0, 0 } ],
            oPos,
            RemovalConditions -> { "MouseClickOutside", "EvaluatorQuit" }
        ]
    ],
    throwInternalFailure
];

AttachSubmenu[ parentMenu_, Cell[ boxes_, style__String, opts: OptionsPattern[ ] ] ] :=
    AttachSubmenu[ parentMenu, Cell[ boxes, style, "AttachedChatMenu", opts ] ];

AttachSubmenu[ parentMenu_, expr: Except[ _Cell ] ] :=
    AttachSubmenu[ parentMenu, Cell[ BoxData @ ToBoxes @ expr, "AttachedChatMenu" ] ];

AttachSubmenu[ expr_ ] :=
    AttachSubmenu[ EvaluationCell[ ], expr ];

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
determineAttachmentPosition[ ] := determineAttachmentPosition @ MousePosition[ "WindowScaled" ];
determineAttachmentPosition[ pos_List ] := determineAttachmentPosition[ pos, quadrant @ pos ];
determineAttachmentPosition[ _, { h_, v_ } ] := { { Replace[ h, { Left -> Right, Right -> Left } ], v }, { h, Center } };
determineAttachmentPosition // endDefinition;

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
(*removeChatMenus*)
removeChatMenus // beginDefinition;

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
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];