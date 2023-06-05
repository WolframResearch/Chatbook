BeginPackage["Wolfram`PreferencesUtils`"]

GeneralUtilities`SetUsage[PreferencesPane, "
PreferencesPane[items$, resetButton$] returns a pane suitable for presentation
as the main element of a Preferences window pane.

resetButton$ should be a button that resets any preferences configurable by
this pane back to their default values.
"]

GeneralUtilities`SetUsage[PreferencesSection, "
PreferencesSection[label$, content$] returns a delimited section suitable for
display in a Preferences window pane.
"]

GeneralUtilities`SetUsage[PreferencesResetButton, "
PreferencesResetButton[action$] returns a button that resets items from the current
Preferences panel back to their default values.
"]


Begin["`Private`"]

(*====================================*)

PreferencesPane[items_?ListQ, resetButton_] := Module[{
	grid
},
	grid = Grid[
		Append[
			Map[item |-> {"", item}, items],
			{Spacer[20], Item[resetButton, ItemSize -> Fit]}
		],
		ItemSize -> Automatic,
		Alignment -> Left,
		(* Show a horizontal divider at every position except before the first
			item and after the reset button. *)
		Dividers -> {False, {{{True}}, {1 -> False, -1 -> False}}},
		Spacings -> {0, {1.5, 1 -> 5}}
	];

	grid = Style[grid, GridBoxOptions -> {BaseStyle -> "defaultGrid"}];

	Pane[grid, ImageMargins -> {{0, 0}, {0, 12.5}}]
]

(*====================================*)

SetAttributes[PreferencesResetButton, HoldFirst];

PreferencesResetButton[
	action_,
	opts:OptionsPattern[Evaluator]
] := Module[{
	label
},
	label = Grid[
		{{
			Style[
				Dynamic[
					RawBoxes @ FEPrivate`FrontEndResource[
						"FEBitmaps",
						"SyntaxColorResetIcon"
					][RGBColor[0.3921, 0.3921, 0.3921]]
				],
				GraphicsBoxOptions -> {BaselinePosition -> Scaled[0.1]}
			],
			Dynamic[
				FEPrivate`FrontEndResource["PreferencesDialog", "ResetAllSettingsText"]
			]
		}},
		Alignment -> {Automatic, Baseline}
	];

	Button[
		label,
		action,
		BaseStyle -> {
			FontFamily -> Dynamic[FrontEnd`CurrentValue["ControlsFontFamily"]],
			FontSize -> Dynamic[FrontEnd`CurrentValue["ControlsFontSize"]],
			FontColor -> GrayLevel[0.]
		},
		ImageSize -> Automatic,
		opts
	]
]

(*====================================*)

PreferencesSection[label_, content_] :=
	Column[{label, content}, Spacings -> {0, 0.7}]

(*====================================*)

End[]

EndPackage[]