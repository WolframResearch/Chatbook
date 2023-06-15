(*
	This file contains utilities for constructing Chatbook menus.

*)

BeginPackage["Wolfram`Chatbook`Menus`"]

Needs["GeneralUtilities`" -> None]

GeneralUtilities`SetUsage[MakeMenu, "
MakeMenu[$$] returns an expression representing a menu of actions.

The generated menu expression may depend on styles from the Chatbook stylesheet.
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
	With[ { icon = $chatbookIcons[ name ] },
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
			NotebookDelete @ $CellContext`cell;
			Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
			Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ action, $CellContext`root ]
		]
	];

menuItem[ None, content_, None ] :=
	content;

menuItem[ icon_, label_, None ] :=
	menuItem[
		icon,
		label,
		Hold[
			NotebookDelete @ EvaluationCell[ ];
			MessageDialog[ "Not Implemented" ]
		]
	];

menuItem[ icon_, label_, code_ ] :=
	RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label, code }, "ChatMenuItem" ];

(*========================================================*)

If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[]

EndPackage[]