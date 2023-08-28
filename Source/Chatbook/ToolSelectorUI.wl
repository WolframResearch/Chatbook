(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ToolSelectorUI`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`CreateLLMToolPalette;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$toolsWidth    = 240;
$personasWidth = 30;
$rightColWidth = 107;
$rowHeight     = 30;
$highlightCol  = GrayLevel[ 0.95 ];
$dividerCol    = GrayLevel[ 0.85 ];
$activeBlue    = Hue[ 0.59, 0.9, 0.93 ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateLLMToolPalette*)
CreateLLMToolPalette[tools_List, personas_List] :=
	Module[{preppedPersonas, preppedTools, personaNames, personaDisplayNames, toolNames, toolDefaultPersonas, gridOpts, $sectionSpacer, sectionHeading, indent},

		gridOpts = Sequence[Spacings -> {0, 0}, ItemSize -> {0, 0}, Dividers -> {None, {None, {GrayLevel[.9]}, None}}];
		$sectionSpacer = {Spacer[{0, 15}], SpanFromLeft};
		sectionHeading[heading_, pad_:{5, 10}] := {
			Pane[headerStyle[heading], FrameMargins -> {{0, 0}, pad}],
			SpanFromLeft};
		indent[expr:Except[_Integer]] := {Spacer[{10, 0}], expr};
		indent[i_Integer] := {Spacer[{i, 0}], #}&;

		inWindow @ DynamicModule[
			{
				sH = 0, sV = 0, w = 167, h = 258, row = None, column = None,
				scopeMode = $FrontEndSession &, scope = $FrontEndSession, notInherited = None, notInheritedStyle,
				toolLookup = Association @ MapThread[Rule, {Through[tools["Name"]], Range @ Length[tools]}]},

			preppedPersonas = prepPersonas[personas, Dynamic[{row, column}]];
			preppedTools = prepTools[tools, Dynamic[{row, column}]];
			personaNames = Through[personas["Name"]];
			personaDisplayNames = Through[personas["DisplayName"]];
			toolNames = Through[tools["Name"]];
			(* Produce an association whose keys are tool names, and values are all the personas which list that tool in their
				default tools to use. *)
			toolDefaultPersonas = With[
				{personaDefaults = #["Name"] -> Lookup[#, "DefaultTools", {}]& /@ personas},
				Association @ Map[
					Function[toolName, toolName -> (First /@ Select[personaDefaults, MemberQ[Last[#], toolName]&])],
					toolNames]];

			DynamicWrapper[
				Grid[
					{

						(* ----- Install Tools ----- *)
						sectionHeading["Install Tools", {5, 0}],
						indent @ Grid[
							{{
								Button["LLM Tool Repository \[UpperRightArrow]", Null, BaseStyle -> $baseStyle],
								Spacer[5],
								Button["Install From File...", Null, BaseStyle -> $baseStyle]}},
							Spacings -> {0, 0}],

						$sectionSpacer,

						(* ----- Configure and Enable Tools ----- *)
						sectionHeading["Manage and Enable Tools", {8, 15}],
						indent @ Row[{"Scope for enable/disable checkboxes:", Spacer[5], scopeSelector[Dynamic[scopeMode]]}],

						indent @ Spacer[{0, 17}],

						indent @ EventHandler[
							Grid[
								{
									Append[
										EventHandler[Pane[#, FrameMargins -> {{0, 0}, {2, 2}}], {"MouseEntered" :> FEPrivate`Set[{row, column}, {None, None}]}]& /@ {
											"Tool",
											Row[{Spacer[4], "Enabled for\[VeryThinSpace]:", Spacer[5], personaNameDisp[personaDisplayNames, Dynamic[column]]}]},
										SpanFromLeft],
									{
										"",
										(* Row of persona icons: *)
										linkedPane[
											Grid[
												{preppedPersonas},
												Background -> With[{c = $highlightCol}, Dynamic[{{column -> c}, {}}]],
												Alignment -> {Center, Center}, gridOpts],
											Dynamic[{w, Automatic}],
											Dynamic[{sH, 0}, FEPrivate`Set[sH, FEPrivate`Part[#, 1]]&],
											FrameMargins -> {{0, 0}, {0, 0}}],
										""},

									{
										(* Tools column: *)
										linkedPane[
											Grid[
												List /@ preppedTools,
												Background -> With[{c = $highlightCol}, Dynamic[{None, {row -> c}, notInheritedStyle}]],
												Alignment -> Left, gridOpts],
											Dynamic[{Automatic, h}],
											Dynamic[{0, sV}, FEPrivate`Set[sV, FEPrivate`Part[#, 2]]&],
											FrameMargins -> {{0, 0}, {15, 0}}],

										(* Checkbox grid: *)
										linkedPane[
											Grid[
												Table[
													enabledControl[{i, tools[[i]]["Name"]}, {j, personas[[j]]["Name"]}, Dynamic[{row, column}], Dynamic[scope], personaNames],
													{i, Length[tools]}, {j, Length[personas]}],
												Background -> With[{c = $highlightCol}, Dynamic[{{column -> c}, {row -> c}, notInheritedStyle}]],
												gridOpts],
											Dynamic[{w, h},
												(FEPrivate`Set[w,
													FEPrivate`If[
														FEPrivate`Greater[FEPrivate`Part[#, 1], 166],
														FEPrivate`Part[#, 1],
														167]];
												FEPrivate`Set[h,
													FEPrivate`If[
														FEPrivate`Greater[FEPrivate`Part[#, 2], 257],
														FEPrivate`Part[#, 2],
														258]])&],
											Dynamic[{sH, sV}],
											Scrollbars -> {Automatic, False}],

										(* All/None and clear column: *)
										linkedPane[
											Grid[
												MapThread[
													{rightColControl[{#1, #2}, Dynamic[{row, column}], Dynamic[scope], Dynamic[notInherited], toolDefaultPersonas[#2]]}&,
													{Range @ Length[tools], toolNames}],
												Background -> With[{c = $highlightCol}, Dynamic[{None, {row -> c}, notInheritedStyle}]],
												gridOpts],
											Dynamic[{Automatic, h}],
											Dynamic[{0, sV}, FEPrivate`Set[sV, FEPrivate`Part[#, 2]]&],
											FrameMargins -> {{0, 10}, {15, 0}},
											Scrollbars -> {False, Automatic},
											AppearanceElements -> None]}},

								Alignment -> {Left, Top},
								Dividers -> {
									{False, $dividerCol, $dividerCol, {False}},
									{False, False, $dividerCol, {False}}},
								Spacings -> {0, 0}, ItemSize -> {0, 0},
								BaseStyle -> $baseStyle],

							{"MouseExited" :> FEPrivate`Set[{row, column}, {None, None}]},
							PassEventsDown -> True]},

						ItemSize -> {Automatic, 0}, Spacings -> {0, 0}, BaseStyle -> $baseStyle, Alignment -> {Left, Top},
						Dividers -> {False, {False, False, False, $dividerCol, {False}}}],

					(* Resolve scope to $FrontEnd, a notebook object, or list of cell objects. *)
					scope = scopeMode[];
					(* Determine which tools have a value set at the current scope. This logic is too involved
						to do in the front end, but the code doesn't fire often so there's no significant
						disadvantage to running it in the kernel. *)
					Switch[scope,

						(* Compare notebook to $FrontEnd. *)
						_NotebookObject,
						notInherited = toolLookup /@ Keys @ DeleteCases[
							Merge[
								{
									AbsoluteCurrentValue[$FrontEndSession, {TaggingRules, "ToolsTest"}],
									AbsoluteCurrentValue[scope, {TaggingRules, "ToolsTest"}]},
								(* Inheriting if there are exactly two identical copies of a value. *)
								Length[#] === 2 && SameQ @@ # &],
							True];
						notInheritedStyle = {{#, #}, {1, -1}} -> Hue[0.59,0.48,1,.1] & /@ notInherited,

						(* Compare cell to parent notebook. *)
						{__CellObject},
						notInherited = toolLookup /@ Keys @ DeleteCases[
							Merge[
								{
									AbsoluteCurrentValue[ParentNotebook[First[scope]], {TaggingRules, "ToolsTest"}],
									Splice @ AbsoluteCurrentValue[scope, {TaggingRules, "ToolsTest"}]},
								(* Inheriting if there are exactly as many identical copies of a value as there are
									selected cells plus the parent scope. *)
								Length[#] === 1 + Length[scope] && SameQ @@ # &],
							True];
						notInheritedStyle = {{#, #}, {1, -1}} -> Hue[0.59,0.48,1,.1] & /@ notInherited,

						(* Otherwise we're looking at $FrontEnd (or no selection if scope is {}). *)
						_,
						notInherited = notInheritedStyle = None]],

			UnsavedVariables :> {sH, sV, w, h, row, column},
			Initialization :> (scopeMode = $FrontEndSession &)]]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Styles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$baseStyle*)
$baseStyle = {FontFamily->"Source Sans Pro", FontSize->14, FontColor->GrayLevel[.3]};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*headerStyle*)
headerStyle[expr_, opts___] := Style[expr, FontWeight -> Bold, opts];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overlays*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachOverlay*)

(* :!CodeAnalysis::Disable::NoVariables::DynamicModule:: *)
attachOverlay[expr_, opts___] :=
	AttachCell[
		EvaluationNotebook[],
		DynamicModule[{},
			Overlay[
				{
					Framed["",
						ImageSize -> {Full, Last @ AbsoluteCurrentValue[EvaluationNotebook[], WindowSize]},
						FrameStyle -> None, Background -> GrayLevel[.97, .85]],
					Framed[overlayGrid[expr],
						Background -> White, DefaultBaseStyle -> $baseStyle, RoundingRadius -> 4, FrameStyle -> GrayLevel[.85],
						opts]},
				{1, 2}, 2, Alignment -> {Center, Center}],
			InheritScope -> True],
		{Center, Center}, Automatic, {Center, Center},
		RemovalConditions -> {}]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*overlayGrid*)
overlayGrid[{title_, body_, {label1_, Hold[action1_], label2_, Hold[action2_]}}] :=
	Grid[
		{
			{headerStyle[title], SpanFromLeft},
			{body, SpanFromLeft},
			{
				"",
				Button[label1, action1, BaseStyle -> $baseStyle],
				Spacer[5],
				Button[label2, action2, BaseStyle -> $baseStyle]}},
		Spacings -> {0, .4}, ItemSize -> {{Fit, {0}}, 0}, Alignment -> Left]


overlayGrid[expr:Except[_List]] := expr

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prepTools*)

(* :!CodeAnalysis::Disable::DuplicateKeys::ListOfRules:: *)
prepTools[tools:{__Association}, Dynamic[{row_, column_}]] :=
	MapThread[
		EventHandler[
			Row[{
				PaneSelector[
					MapThread[
						Function[{val, colCog, colDelimiter},
							val -> Pane@Grid[
								{{Spacer[5], #1["Icon"], Spacer[5], #1["Name"], Dynamic@iconData["Cog", colCog], Spacer[5], Dynamic@iconData["Delimiter", colDelimiter]}},
								ItemSize -> {{{0}, Fit, 0, 0, 0}, 0}, Spacings -> {0,0}, Alignment -> Left]],
						{
							{{False, False}, {True, False}, {True, True}},
							{LineColor -> None, GrayLevel[.65], $activeBlue},
							{LineColor -> None, GrayLevel[.8], GrayLevel[.8]}}],
					Dynamic[{FEPrivate`SameQ[row, #2], FrontEnd`CurrentValue["MouseOver"]}],
					ImageSize -> {$toolsWidth, $rowHeight}, FrameMargins -> None, BaselinePosition -> (Center -> Center)],
				PaneSelector[
					MapThread[
						Function[{val, colBin, colDelimiter},
							val -> Grid[
								{{Spacer[5], deleteButton[colBin, #2, #1], Spacer[3], Dynamic@iconData["Delimiter", LineColor -> None]}},
								ItemSize -> {0, 0}, Spacings -> {0,0}]],
						{
							{{False, False}, {True, False}, {True, True}},
							{LineColor -> None, GrayLevel[.65], $activeBlue},
							{LineColor -> None, LineColor -> None, LineColor -> None}
                        }
                    ],
					Dynamic[{FEPrivate`SameQ[row, #2], FrontEnd`CurrentValue["MouseOver"]}],
					ImageSize -> {Automatic, $rowHeight}, FrameMargins -> None, BaselinePosition -> (Center -> Center)],
				Spacer[2]}],
			{"MouseEntered" :> FEPrivate`Set[{row, column}, {#2, None}]},
			PassEventsDown -> True]&,
		{tools, Range @ Length[tools]}]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deleteButton*)
deleteButton[colBin_, row_, tool_Association] :=
	Button[
		Dynamic@iconData["Bin", colBin],
		attachOverlay[
			{
				Style["Delete Tool", Bold],
				Row[{tool["Icon"], Spacer[3], tool["Name"]}],
				{
					"Cancel",
					Hold[NotebookDelete[EvaluationCell[]]],
					Style["Delete", Red],
					Hold[NotebookDelete[EvaluationCell[]]]}},
			FrameMargins -> {13{1, 1}, 10{1, 1}},
			ImageSize -> {300, Automatic}],
		Appearance -> "Suppressed", BaselinePosition -> (Center -> Center), ContentPadding -> False,
		ImageSize -> {Automatic, $rowHeight}, FrameMargins -> {{0, 0}, {2, 0}}]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prepPersonas*)
prepPersonas[personas:{__Association}, Dynamic[{row_, column_}]] :=
	MapThread[
		EventHandler[
			Framed[#1["Icon"],
				ImageSize -> {$personasWidth, $personasWidth}, FrameMargins -> None, FrameStyle -> None,
				Alignment -> {Center, Center}, BaseStyle -> {LineBreakWithin -> False}],
			{"MouseEntered" :> FEPrivate`Set[{column, row} = {#2, None}]},
			PassEventsDown -> True]&,
		{personas, Range @ Length[personas]}]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*enabledControl*)
enabledControl[{row_, toolName_}, {column_, personaName_}, Dynamic[{dRow_, dColumn_}], Dynamic[scope_], allPersonas_] :=
	EventHandler[
		Framed[
			If[toolName === "Proverb Lookup" && personaName =!= "SupportiveFriend", Checkbox[False, Enabled -> False], #]& @ Checkbox[
				Dynamic[
					FEPrivate`If[
						FEPrivate`SameQ[FEPrivate`Head[scope], List],
						FEPrivate`Which[
							(* No cells selected. *)
							FEPrivate`SameQ[#, {}],
							False,
							(* All cells have the same setting. *)
							FEPrivate`SameQ @@ #,
							FEPrivate`Or[FEPrivate`SameQ[FEPrivate`Part[#, 1], All], FEPrivate`MemberQ[FEPrivate`Part[#, 1], personaName]],
							(* Cells have different settings. *)
							True, {}],
						FEPrivate`Or[FEPrivate`SameQ[#, All], FEPrivate`MemberQ[#, personaName]]]&[
							FrontEnd`AbsoluteCurrentValue[scope, {TaggingRules, "ToolsTest", toolName}]],
					(CurrentValue[scope, {TaggingRules, "ToolsTest", toolName}] =
						With[
							{list = Replace[
								AbsoluteCurrentValue[
									(* If multiple cells are selected, take the settings of the first one to modify. *)
									If[Head[scope] === List, First[scope, {}], scope],
									{TaggingRules, "ToolsTest", toolName}],
								{None -> {}, All -> allPersonas, Except[_List] -> {}}]},
							If[#,
								DeleteDuplicates[Append[list, personaName]],
								DeleteCases[list, personaName]]])&],
				{False, True}],
			ImageSize -> {$personasWidth, $rowHeight},
			FrameMargins -> None, FrameStyle -> None,
			Background -> None, Alignment -> {Center, Center},
			BaseStyle -> {LineBreakWithin -> False}],
		{"MouseEntered" :> FEPrivate`Set[{dRow, dColumn}, {row, column}]},
		PassEventsDown -> True]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*rightColControl*)
rightColControl[{row_, toolName_}, Dynamic[{dRow_, dColumn_}], Dynamic[scope_], Dynamic[notInherited_], defaultPersonas_] :=
	EventHandler[
		Pane[
			Grid[
				{{
					PopupMenu[
						Dynamic[
							FEPrivate`Which[
								FEPrivate`SameQ[#, None], None,
								FEPrivate`SameQ[#, All], All,
								FEPrivate`SameQ[FEPrivate`Head[#], List], List,
								True, List]&[
									FrontEnd`AbsoluteCurrentValue[scope, {TaggingRules, "ToolsTest", toolName}]],
							FEPrivate`Which[
								(* If the new setting is All or None, then set the enabled personas to All or None. *)
								FEPrivate`MemberQ[{All, None}, #],
								FEPrivate`Set[FrontEnd`CurrentValue[scope, {TaggingRules, "ToolsTest", toolName}], #],
								(* If the new setting is a list (and the current setting is not a list), then set the enabled personas
									to the default set. In this sense, choosing "Enabled by persona" from the dropdown is equivalent to
									resetting how a tool is enabled, rather than just replacing None with {} or All with a list of all personas. *)
								FEPrivate`UnsameQ[FEPrivate`Head[FrontEnd`AbsoluteCurrentValue[scope, {TaggingRules, "ToolsTest", toolName}]], List],
								FEPrivate`Set[FrontEnd`CurrentValue[scope, {TaggingRules, "ToolsTest", toolName}], defaultPersonas]]&],
						{
							List -> "Enabled by persona",
							Delimiter,
							None -> "Never enabled",
							All -> "Always enabled"},
						"",
						PaneSelector[
							MapThread[
								Function[{val, label, col},
									val -> Grid[
										{{Dynamic@iconData["AllChecked", col], Spacer[3], label, Dynamic@iconData["DownChevron", col]}},
										ItemSize -> {0,0}, Spacings -> {0,0}]],
								{
									{{All, False}, {All, True}, {None, False}, {None, True}, {True, False}, {True, True}},
									Join[Nest[Unevaluated, Splice[{#, Spacer[5]}], 2]& /@ {"Always", "Always", "Never", "Never"}, {"", ""}],
									{GrayLevel[.65], $activeBlue, GrayLevel[.65], $activeBlue, GrayLevel[.65], $activeBlue}}],
							Dynamic[{
								FEPrivate`If[
									(* If there are cells selected, then check if they have the same settings. *)
									FEPrivate`And[
										FEPrivate`SameQ[FEPrivate`Head[scope], List],
										FEPrivate`SameQ @@ #],
									(* If the setting is All or None, return the setting (and display an "Always" or "Never" label next to the icon).
										Otherwise check if the row is currently hovered over (and just display the icon with no label if so). *)
									FEPrivate`If[FEPrivate`MemberQ[{All, None}, FEPrivate`Part[#, 1]], FEPrivate`Part[#, 1], FEPrivate`SameQ[dRow, row]],
									FEPrivate`If[FEPrivate`MemberQ[{All, None}, #], #, FEPrivate`SameQ[dRow, row]]],
								FrontEnd`CurrentValue["MouseOver"]}&[
									FrontEnd`AbsoluteCurrentValue[scope, {TaggingRules, "ToolsTest", toolName}]]],
							"",
							BaseStyle -> Append[$baseStyle, LineBreakWithin -> False],
							ImageSize -> {Automatic, $rowHeight}, Alignment -> {Left, Center}, FrameMargins -> {{5, 3}, {2, 0}}, BaselinePosition -> (Center -> Center)],
						Appearance -> "Frameless", BaseStyle -> $baseStyle, FrameMargins -> {{2, 0}, {0, 0}}, ContentPadding -> False, BaselinePosition -> (Center -> Center)],

					PaneSelector[
						MapThread[
							Function[{val, col},
								val -> Button[
									Dynamic@iconData["Clear", col],
									CurrentValue[scope, {TaggingRules, "ToolsTest", toolName}] = Inherited,
									ImageSize -> {20, $rowHeight}, Appearance -> "Suppressed"]],
							{
								{{True, False}, {True, True}},
								{GrayLevel[.5], $activeBlue}}],
						Dynamic[{FEPrivate`MemberQ[notInherited, row], FrontEnd`CurrentValue["MouseOver"]}],
						"",
						ImageSize -> {20, $rowHeight}, BaselinePosition -> (Center -> Center)]}},

				ItemSize -> {{Fit, {0}}, 0}, Spacings -> {0,0}, Alignment -> Left],

			{$rightColWidth, $rowHeight}, FrameMargins -> None],

		{"MouseEntered" :> FEPrivate`Set[{dRow, dColumn} = {row, None}]}]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*scopeSelector*)
scopeSelector[Dynamic[scopeMode_]] :=
	ActionMenu[
		Framed[
			Row[{
				PaneSelector[
					{
						$FrontEndSession & -> "Global",
						FE`Evaluate @* FEPrivate`LastActiveUserNotebook -> "Selected Notebook",
						SelectedCells @* FE`Evaluate @* FEPrivate`LastActiveUserNotebook -> "Selected Cells"},
					Dynamic[scopeMode],
					ImageSize -> Automatic, BaseStyle -> $baseStyle],
				" \[DownPointer]"}],
			FrameStyle -> GrayLevel[.85], RoundingRadius -> 2, FrameMargins -> {{Automatic, Automatic}, {2, 2}}],
		{
			"Global" :> (scopeMode = $FrontEndSession &),
			"Selected Notebook" :> (scopeMode = FE`Evaluate @* FEPrivate`LastActiveUserNotebook),
			"Selected Cells" :> (scopeMode = SelectedCells @* FE`Evaluate @* FEPrivate`LastActiveUserNotebook)},
		Appearance -> "Frameless"]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*personaNameDisp*)
personaNameDisp[personaNames_, Dynamic[column_]] :=
	With[{allowedIndices = Range @ Length[personaNames]},
		PaneSelector[
			{True -> Dynamic[FEPrivate`Part[personaNames, column]], False -> ""},
			Dynamic[FEPrivate`MemberQ[allowedIndices, column]],
			ImageSize -> Automatic,
			BaseStyle -> {FontColor -> GrayLevel[.5], $baseStyle}]]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inWindow*)
inWindow[ expr_ ] := CreateDialog[
    Cell[
        BoxData @ ToBoxes @ expr,
        CellFrame        -> { { False, 1 }, { 1, False } },
        CellFrameMargins -> { { 0, -10 }, { -2, 0 } },
        CellFrameStyle   -> White
    ],
    Background          -> White,
    Saveable            -> False,
    StyleDefinitions    -> $toolDialogStyles,
    WindowClickSelect   -> False,
    WindowFrameElements -> { "CloseBox", "ResizeArea" },
    WindowTitle         -> "LLM Tools"
];

$toolDialogStyles = Notebook[
    {
        Cell @ StyleData[ StyleDefinitions -> "Dialog.nb"   ],
        Cell @ StyleData[ StyleDefinitions -> "Chatbook.nb" ]
    },
    StyleDefinitions -> "PrivateStylesheetFormatting.nb"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*linkedPane*)
linkedPane[expr_, size_, scrollPos_, opts___] :=
	Pane[expr, size, ScrollPosition -> scrollPos, opts]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Icons*)
iconData // beginDefinition;
iconData[ name_String, color_ ] := Insert[ chatbookIcon[ "ToolSelectorUI"<>name ], color, { 1, 1, 1 } ];
iconData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
