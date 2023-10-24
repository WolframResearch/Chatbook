(*
	This file contains utilities for constructing Chatbook menus.

*)

BeginPackage["Wolfram`Chatbook`Menus`"]

Needs["GeneralUtilities`" -> None]

GeneralUtilities`SetUsage[MakeMenu, "
MakeMenu[$$] returns an expression representing a menu of actions.

The generated menu expression may depend on styles from the Chatbook stylesheet.
"]

GeneralUtilities`SetUsage[AttachSubmenu, "
AttachSubmenu[parentMenu$, submenu$] attaches submenu$ to parentMenu$, taking
care to attach to the left or right side based on heuristic for available space.
"]

Begin["`Private`"]

Needs["Wolfram`Chatbook`Common`"]
Needs["Wolfram`Chatbook`ErrorUtils`"]

(*========================================================*)

SetFallthroughError[MakeMenu]

MakeMenu[
	items_List,
	frameColor_,
	width_
] :=
	Pane[
		RawBoxes @ TemplateBox[
			{
				ToBoxes @ Column[ menuItem /@ items, ItemSize -> Automatic, Spacings -> 0, Alignment -> Left ],
				FrameMargins   -> 3,
				Background     -> GrayLevel[ 0.98 ],
				RoundingRadius -> 3,
				FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
				ImageMargins   -> 0
			},
			"Highlighted"
		],
		ImageSize -> { width, Automatic }
	];

(*====================================*)

SetFallthroughError[menuItem]

menuItem[ { args__ } ] := menuItem @ args;

menuItem[ Delimiter ] := RawBoxes @ TemplateBox[ { }, "ChatMenuItemDelimiter" ];

menuItem[ label_ :> action_ ] := menuItem[Graphics[{}, ImageSize -> 0], label, Hold[action]]

menuItem[ section_ ] := RawBoxes @ TemplateBox[ { ToBoxes @ section }, "ChatMenuSection" ];

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
	menuItem[
		icon,
		label,
		Hold[
			MessageDialog[ "Not Implemented" ];
			NotebookDelete @ EvaluationCell[ ];
		]
	];

menuItem[ icon_, label_, code_ ] :=
	RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label, code }, "ChatMenuItem" ];

(*========================================================*)

AttachSubmenu[
	parentMenu_CellObject,
	submenu_
] := With[{
	mouseX = MousePosition["WindowScaled"][[1]]
}, {
	(* Note: Depending on the X coordinate of the users mouse
		when they click the 'Advanced Settings' button, either
		show the attached submenu to the left or right of the
		outer menu. This ensures that this submenu doesn't touch
		the right edge of the notebook window when it is opened
		from the 'Chat Settings' notebook toolbar. *)
	positions = If[
		TrueQ[mouseX < 0.5],
		{
			{Right, Bottom},
			{Left, Bottom}
		},
		{
			{Left, Bottom},
			{Right, Bottom}
		}
	]
},
	AttachCell[
		EvaluationCell[],
		submenu,
		positions[[1]],
		{50, 50},
		positions[[2]],
		RemovalConditions -> "MouseExit"
	]
]

(*========================================================*)

If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[]

EndPackage[]