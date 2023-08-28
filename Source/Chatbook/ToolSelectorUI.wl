(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ToolSelectorUI`" ];

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
											Scrollbars -> {True, False}],

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
											Scrollbars -> {False, True},
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
prepTools[tools:{__Association}, Dynamic[{row_, column_}]] :=
	MapThread[
		EventHandler[
			Row[{
				PaneSelector[
					MapThread[
						Function[{val, colCog, colDelim},
							val -> Pane@Grid[
								{{Spacer[5], #1["Icon"], Spacer[5], #1["Name"], Dynamic@iconData["cog", colCog], Spacer[5], Dynamic@iconData["delim", colDelim]}},
								ItemSize -> {{{0}, Fit, 0, 0, 0}, 0}, Spacings -> {0,0}, Alignment -> Left]],
						{
							{{False, False}, {True, False}, {True, True}},
							{LineColor -> None, GrayLevel[.65], $activeBlue},
							{LineColor -> None, GrayLevel[.8], GrayLevel[.8]}}],
					Dynamic[{FEPrivate`SameQ[row, #2], FrontEnd`CurrentValue["MouseOver"]}],
					ImageSize -> {$toolsWidth, $rowHeight}, FrameMargins -> None, BaselinePosition -> (Center -> Center)],
				PaneSelector[
					MapThread[
						Function[{val, colBin, colDelim},
							val -> Grid[
								{{Spacer[5], deleteButton[colBin, #2, #1], Spacer[3], Dynamic@iconData["delim", colDelim]}},
								ItemSize -> {0, 0}, Spacings -> {0,0}]],
						{
							{{False, False}, {True, False}, {True, True}},
							{LineColor -> None, GrayLevel[.65], $activeBlue},
							{LineColor -> None, LineColor -> None, LineColor -> None}}],
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
		Dynamic@iconData["bin", colBin],
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
										{{Dynamic@iconData["allChecked", col], Spacer[3], label, Dynamic@iconData["downChevron", col]}},
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
									Dynamic@iconData["clear", col],
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
inWindow[expr_] :=
	CreateDialog[
		Cell[BoxData @ ToBoxes @ expr,
			CellFrameMargins -> {{0, -10}, {-2, 0}},
			CellFrame -> {{False, 1}, {1, False}},
			(* CellFrameMargins -> {{7, -1}, {-1, 4}},
			CellFrame -> {{1, 1}, {1, 1}}, *)
			CellFrameStyle -> White],
		(* Dialog opts *)
		WindowTitle -> "LLM Tools",
		Background -> White,
		Saveable -> False]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*linkedPane*)
linkedPane[expr_, size_, scrollPos_, opts___] :=
	Pane[expr, size, ScrollPosition -> scrollPos, opts]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Icons*)
(* TODO: create these icons as template boxes in the stylesheet *)
iconData["cog", col_] := Graphics[{col, JoinForm["Round"],Thickness[0.08`],JoinedCurve[{{{1,4,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{1,3,3},{1,3,3},{0,1,0},{1,3,3},{0,1,0}}},{{{9.529999732971191`,7.4499993324279785`},{9.449999809265137`,7.6399993896484375`},{9.350000381469727`,7.8199992179870605`},{9.25`,7.999999284744263`},{10.069999694824219`,8.859999418258667`},{10.3100004196167`,9.109999418258667`},{10.3100004196167`,9.499999284744263`},{10.069999694824219`,9.759999513626099`},{9.969999313354492`,9.869999408721924`},{9.860000610351562`,9.979999303817749`},{9.75`,10.079999446868896`},{9.5`,10.309999346733093`},{9.100000381469727`,10.309999346733093`},{8.850000381469727`,10.079999446868896`},{8.020000457763672`,9.299999475479126`},{8.020000457763672`,9.299999475479126`},{7.970000267028809`,9.279999494552612`},{7.950000286102295`,9.299999475479126`},{7.619999885559082`,9.499999284744263`},{7.269999980926514`,9.639999389648438`},{6.900000095367432`,9.739999532699585`},{6.87000036239624`,9.739999532699585`},{6.860000133514404`,9.769999504089355`},{6.850000381469727`,9.799999475479126`},{6.820000171661377`,10.939999341964722`},{6.820000171661377`,11.279999315738678`},{6.539999961853027`,11.559999346733093`},{6.190000057220459`,11.579999327659607`},{6.039999961853027`,11.579999327659607`},{5.880000114440918`,11.579999327659607`},{5.730000019073486`,11.579999327659607`},{5.390000343322754`,11.56999933719635`},{5.110000133514404`,11.289999306201935`},{5.099999904632568`,10.939999341964722`},{5.070000171661377`,9.749999523162842`},{4.87000036239624`,9.699999332427979`},{4.679999828338623`,9.639999389648438`},{4.480000019073486`,9.559999465942383`},{4.279999732971191`,9.479999303817749`},{4.110000133514404`,9.37999939918518`},{3.930000066757202`,9.279999494552612`},{3.069999933242798`,10.09999942779541`},{2.819999933242798`,10.339999318122864`},{2.430000066757202`,10.339999318122864`},{2.169999837875366`,10.09999942779541`},{2.059999942779541`,9.999999284744263`},{1.9500000476837158`,9.889999389648438`},{1.8499999046325684`,9.779999494552612`},{1.6200000047683716`,9.529999256134033`},{1.6200000047683716`,9.12999939918518`},{1.8499999046325684`,8.87999939918518`},{2.629999876022339`,8.049999475479126`},{2.629999876022339`,8.049999475479126`},{2.6499998569488525`,7.999999284744263`},{2.629999876022339`,7.979999303817749`},{2.430000066757202`,7.649999618530273`},{2.2899999618530273`,7.299999237060547`},{2.200000047683716`,6.929999351501465`},{2.200000047683716`,6.899999141693115`},{2.169999837875366`,6.8899993896484375`},{2.1399998664855957`,6.879999160766602`},{1.`,6.84999942779541`},{0.6600000262260437`,6.84999942779541`},{0.3799999952316284`,6.5699992179870605`},{0.36000001430511475`,6.219999313354492`},{0.36000001430511475`,6.0699992179870605`},{0.36000001430511475`,5.909999370574951`},{0.36000001430511475`,5.7599992752075195`},{0.3700000047683716`,5.419999122619629`},{0.6500000357627869`,5.1399993896484375`},{1.`,5.129999160766602`},{2.18999981880188`,5.099998950958252`},{2.240000009536743`,4.899999141693115`},{2.299999952316284`,4.7099995613098145`},{2.379999876022339`,4.5099992752075195`},{2.4600000381469727`,4.309999465942383`},{2.559999942779541`,4.1399993896484375`},{2.6599998474121094`,3.9599990844726562`},{1.8399999141693115`,3.09999942779541`},{1.600000023841858`,2.84999942779541`},{1.600000023841858`,2.4600000381469727`},{1.8399999141693115`,2.1999998092651367`},{1.940000057220459`,2.089999198913574`},{2.049999952316284`,1.9799995422363281`},{2.169999837875366`,1.8799991607666016`},{2.4200000762939453`,1.6499996185302734`},{2.819999933242798`,1.6499996185302734`},{3.069999933242798`,1.8799991607666016`},{3.9000000953674316`,2.6599998474121094`},{3.9000000953674316`,2.6599998474121094`},{3.950000047683716`,2.679999351501465`},{3.9700000286102295`,2.6599998474121094`},{4.300000190734863`,2.4600000381469727`},{4.650000095367432`,2.3199987411499023`},{5.019999980926514`,2.219999313354492`},{5.050000190734863`,2.219999313354492`},{5.059999942779541`,2.189999580383301`},{5.070000171661377`,2.1599998474121094`},{5.099999904632568`,1.0199995040893555`},{5.099999904632568`,0.6799993515014648`},{5.380000114440918`,0.39999961853027344`},{5.730000019073486`,0.37999916076660156`},{5.880000114440918`,0.37999916076660156`},{6.039999961853027`,0.37999916076660156`},{6.190000057220459`,0.37999916076660156`},{6.53000020980835`,0.3899993896484375`},{6.810000419616699`,0.6699991226196289`},{6.820000171661377`,1.0199995040893555`},{6.850000381469727`,2.2099990844726562`},{7.050000190734863`,2.2599992752075195`},{7.239999771118164`,2.3199987411499023`},{7.440000057220459`,2.3999996185302734`},{7.639999866485596`,2.479999542236328`},{7.810000419616699`,2.5799989700317383`},{7.990000247955322`,2.679999351501465`},{8.850000381469727`,1.859999656677246`},{9.100000381469727`,1.6199989318847656`},{9.489999771118164`,1.6199989318847656`},{9.75`,1.859999656677246`},{9.860000610351562`,1.9600000381469727`},{9.969999313354492`,2.0699987411499023`},{10.069999694824219`,2.179999351501465`},{10.300000190734863`,2.429999351501465`},{10.300000190734863`,2.8299989700317383`},{10.069999694824219`,3.0799989700317383`},{9.289999961853027`,3.909998893737793`},{9.289999961853027`,3.909998893737793`},{9.269999504089355`,3.9599990844726562`},{9.289999961853027`,3.97999906539917`},{9.489999771118164`,4.309999465942383`},{9.630000114440918`,4.659999370574951`},{9.729999542236328`,5.029999256134033`},{9.729999542236328`,5.059998989105225`},{9.760000228881836`,5.0699992179870605`},{9.789999961853027`,5.079998970031738`},{10.929999351501465`,5.109999179840088`},{11.269999504089355`,5.109999179840088`},{11.550000190734863`,5.3899993896484375`},{11.569999694824219`,5.739999294281006`},{11.569999694824219`,5.8899993896484375`},{11.569999694824219`,6.049999237060547`},{11.569999694824219`,6.1999993324279785`},{11.5600004196167`,6.539999008178711`},{11.279999732971191`,6.8199992179870605`},{10.929999351501465`,6.8299994468688965`},{9.739999771118164`,6.859999179840088`},{9.690000534057617`,7.059998989105225`},{9.630000114440918`,7.249999523162842`},{9.550000190734863`,7.4499993324279785`},{9.529999732971191`,7.4499993324279785`}}},CurveClosed->{1}],JoinedCurve[{{{1,4,3},{1,3,3},{1,3,3},{1,3,3}}},{{{7.5`,5.969999313354492`},{7.5`,5.119479656219482`},{6.810519695281982`,4.429999351501465`},{5.960000038146973`,4.429999351501465`},{5.109480857849121`,4.429999351501465`},{4.420000076293945`,5.119479656219482`},{4.420000076293945`,5.969999313354492`},{4.420000076293945`,6.820518493652344`},{5.109480857849121`,7.5099992752075195`},{5.960000038146973`,7.5099992752075195`},{6.810519695281982`,7.5099992752075195`},{7.5`,6.820518493652344`},{7.5`,5.969999313354492`}}},CurveClosed->{0}]},ImageSize->15 {1,1},PlotRange->{{0.`,11.929999351501465`},{0.`,11.929999351501465`}},AspectRatio->Automatic,ImagePadding->{{0,1},{1,0}},BaselinePosition->Scaled[0.25`]]

iconData["bin", col_] := Graphics[{col, CapForm["Butt"],JoinForm["Round"],Thickness[0.105`],JoinedCurve[{{{0,2,0},{0,1,0},{0,1,0},{0,1,0}}},{{{7.810000419616699`,0.3800010681152344`},{1.0800000429153442`,0.3800010681152344`},{0.44999998807907104`,8.920000553131104`},{8.4399995803833`,8.920000553131104`},{7.810000419616699`,0.3800010681152344`}}},CurveClosed->{1}],JoinedCurve[{{{0,2,0}}},{{{3.200000047683716`,7.020000457763672`},{3.200000047683716`,2.3800010681152344`}}},CurveClosed->{0}],JoinedCurve[{{{0,2,0}}},{{{5.559999942779541`,7.020000457763672`},{5.559999942779541`,2.3800010681152344`}}},CurveClosed->{0}],JoinedCurve[{{{0,2,0}}},{{{0.`,10.790000438690186`},{8.829999923706055`,10.790000438690186`}}},CurveClosed->{0}],JoinedCurve[{{{0,2,0}}},{{{6.039999961853027`,11.8100004196167`},{2.7799999713897705`,11.8100004196167`}}},CurveClosed->{0}]},ImageSize->{11.076923076923077`,16.`},PlotRange->{{0.`,8.829999923706055`},{0.`,12.3100004196167`}},AspectRatio->Automatic,ImagePadding->{{0,1},{1,0}},BaselinePosition->Scaled[0]]

iconData["delim", col_] := Graphics[{col, AbsoluteThickness[0.75`],Line[{{0,-1},{0,1}}]},AspectRatio->Full,ImagePadding->{{0,0},{6,4}},ImageSize->{2,30}]

(*iconData["allChecked", col_] := Graphics[{col, FilledCurve[{{{0, 2, 0}, {1, 3, 3}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}}}, {{{14.520000457763672, 14.510000228881836}, {8.039999961853027, 14.510000228881836}, {7.289999961853027, 14.510000228881836}, {6.639999866485596, 14.100000232458115}, {6.300000190734863, 13.490000247955322}, {6.37000036239624, 13.490000247955322}, {6.440000057220459, 13.510000228881836}, {6.510000228881836, 13.510000228881836}, {12.989999771118164, 13.510000228881836}, {14.100000381469727, 13.510000228881836}, {15.010000228881836, 12.610000133514404}, {15.010000228881836, 11.490000247955322}, {15.010000228881836, 5.010000228881836}, {15.010000228881836, 4.649999618530273}, {14.90999984741211, 4.310000419616699}, {14.739999771118164, 4.020000457763672}, {15.75, 4.130000114440918}, {16.540000915527344, 4.970000267028809}, {16.540000915527344, 6.010000228881836}, {16.540000915527344, 12.490000247955322}, {16.540000915527344, 13.600000202655792}, {15.640000343322754, 14.510000228881836}, {14.520000457763672, 14.510000228881836}}}], FilledCurve[{{{0, 2, 0}, {1, 3, 3}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}}}, {{{11.489999771118164, 12.510000228881836}, {5.010000228881836, 12.510000228881836}, {4.259999752044678, 12.510000228881836}, {3.609999895095825, 12.09000015258789}, {3.2699999809265137, 11.490000247955322}, {3.3499999046325684, 11.500000238418579}, {3.430000066757202, 11.510000228881836}, {3.509999990463257, 11.510000228881836}, {9.989999771118164, 11.510000228881836}, {11.100000381469727, 11.510000228881836}, {12.010000228881836, 10.610000133514404}, {12.010000228881836, 9.490000247955322}, {12.010000228881836, 3.010000228881836}, {12.010000228881836, 2.6499996185302734}, {11.90999984741211, 2.310000419616699}, {11.739999771118164, 2.020000457763672}, {12.739999771118164, 2.140000343322754}, {13.510000228881836, 2.9800004959106445}, {13.510000228881836, 4.010000228881836}, {13.510000228881836, 10.490000247955322}, {13.510000228881836, 11.600000143051147}, {12.610000610351562, 12.510000228881836}, {11.489999771118164, 12.510000228881836}}}], FilledCurve[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}}, {{1, 4, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {0, 1, 0}}}, {{{8.489999771118164, 10.510000228881836}, {2.0199999809265137, 10.510000228881836}, {0.9100000262260437, 10.510000228881836}, {0., 9.610000133514404}, {0., 8.490000247955322}, {0., 2.010000228881836}, {0., 0.8999996185302734}, {0.9000000357627869, -0.010000228881835938}, {2.0199999809265137, -0.010000228881835938}, {8.5, -0.010000228881835938}, {9.610000610351562, -0.010000228881835938}, {10.520000457763672, 0.8899993896484375}, {10.520000457763672, 2.010000228881836}, {10.520000457763672, 8.490000247955322}, {10.520000457763672, 9.599999904632568}, {9.620000839233398, 10.510000228881836}, {8.5, 10.510000228881836}, {8.489999771118164, 10.510000228881836}}, {{8.0600004196167, 7.820000171661377}, {6.390000343322754, 5.810000419616699}, {5.840000152587891, 4.689999580383301}, {4.410000324249268, 2.4499998092651367}, {4.310000419616699, 2.2899999618530273}, {4.110000133514404, 2.2100000381469727}, {3.799999952316284, 2.2100000381469727}, {3.490000009536743, 2.2100000381469727}, {3.299999952316284, 2.2200002670288086}, {3.240000009536743, 2.25}, {3.0899999141693115, 2.310000419616699}, {2.9200000762939453, 2.6499996185302734}, {2.7200000286102295, 3.2400007247924805}, {2.5, 3.8999996185302734}, {2.2100000381469727, 4.670000076293945}, {2.2100000381469727, 4.840000152587891}, {2.2100000381469727, 5.020000457763672}, {2.359999895095825, 5.189999580383301}, {2.6599998474121094, 5.359999656677246}, {2.8399999141693115, 5.470000267028809}, {3.009999990463257, 5.520000457763672}, {3.1499998569488525, 5.520000457763672}, {3.319999933242798, 5.520000457763672}, {3.450000047683716, 5.380000114440918}, {3.5399999618530273, 5.100000381469727}, {3.7100000381469727, 4.580000877380371}, {4.010000228881836, 3.9600000381469727}, {4.090000152587891, 3.9600000381469727}, {4.150000095367432, 3.9600000381469727}, {4.210000038146973, 4.}, {4.269999980926514, 4.090000152587891}, {5.480000019073486, 6.040000915527344}, {5.610000133514404, 6.619999885559082}, {6.650000095367432, 7.820000171661377}, {6.920000076293945, 8.130000114440918}, {7.340000152587891, 8.290000438690186}, {7.930000305175781, 8.290000438690186}, {8.069999694824219, 8.290000438690186}, {8.160000801086426, 8.28000020980835}, {8.210000038146973, 8.250000476837158}, {8.260000228881836, 8.230000495910645}, {8.279999732971191, 8.190000057220459}, {8.279999732971191, 8.150000095367432}, {8.279999732971191, 8.09000015258789}, {8.210000038146973, 7.970000267028809}, {8.0600004196167, 7.7900004386901855}, {8.0600004196167, 7.820000171661377}}}]}, ImageSize -> 20{17., 15.}/17, PlotRange -> {{0., 16.540000915527344}, {0., 14.510000228881836}},ImagePadding->{{0,1},{1,0}},AspectRatio -> Automatic, BaselinePosition->Scaled[.25]];*)

iconData["allChecked", col_] := Graphics[{col, FilledCurve[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}}, {{1, 4, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}}}, {{{8.489999771118164, 10.510000228881836}, {2.0199999809265137, 10.510000228881836}, {0.9100000262260437, 10.510000228881836}, {0., 9.610000133514404}, {0., 8.490000247955322}, {0., 2.010000228881836}, {0., 0.8999996185302734}, {0.9000000357627869, -0.009999275207519531}, {2.0199999809265137, -0.009999275207519531}, {8.5, -0.009999275207519531}, {9.610000610351562, -0.009999275207519531}, {10.520000457763672, 0.8900003433227539}, {10.520000457763672, 2.010000228881836}, {10.520000457763672, 8.490000247955322}, {10.520000457763672, 9.600000381469727}, {9.620000839233398, 10.510000228881836}, {8.5, 10.510000228881836}, {8.489999771118164, 10.510000228881836}}, {{9.25, 2.0399999618530273}, {9.25, 1.6100006103515625}, {8.899999618530273, 1.260000228881836}, {8.469999313354492, 1.260000228881836}, {2.0299999713897705, 1.260000228881836}, {1.600000023841858, 1.260000228881836}, {1.25, 1.6100006103515625}, {1.25, 2.0399999618530273}, {1.25, 8.480000495910645}, {1.25, 8.910000324249268}, {1.600000023841858, 9.260000228881836}, {2.0299999713897705, 9.260000228881836}, {8.469999313354492, 9.260000228881836}, {8.899999618530273, 9.260000228881836}, {9.25, 8.910000324249268}, {9.25, 8.480000495910645}, {9.25, 2.0399999618530273}}}],FilledCurve[{{{1, 4, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {1, 3, 3}, {0, 1, 0}}}, {{{7.960000038146973, 8.240000247955322}, {7.390000343322754, 8.240000247955322}, {6.800000190734863, 8.09000015258789}, {6.539999961853027, 7.780000686645508}, {5.519999980926514, 6.6100006103515625}, {5.400000095367432, 6.039999961853027}, {4.21999979019165, 4.140000343322754}, {4.159999847412109, 4.050000190734863}, {4.099999904632568, 4.010000228881836}, {4.050000190734863, 4.010000228881836}, {3.9800000190734863, 4.010000228881836}, {3.68999981880188, 4.6100006103515625}, {3.5199999809265137, 5.130001068115234}, {3.430000066757202, 5.399999618530273}, {3.309999942779541, 5.539999961853027}, {3.1399998664855957, 5.539999961853027}, {3., 5.539999961853027}, {2.8399999141693115, 5.4900007247924805}, {2.6599998474121094, 5.380000114440918}, {2.359999895095825, 5.220000267028809}, {2.2200000286102295, 5.050000190734863}, {2.2200000286102295, 4.869999885559082}, {2.2200000286102295, 4.710000038146973}, {2.5, 3.9499998092651367}, {2.7200000286102295, 3.310000419616699}, {2.9100000858306885, 2.7300004959106445}, {3.0799999237060547, 2.3999996185302734}, {3.2300000190734863, 2.3400001525878906}, {3.2899999618530273, 2.310000419616699}, {3.6499998569488525, 2.3000001907348633}, {3.950000047683716, 2.3000001907348633}, {4.25, 2.3000001907348633}, {4.450000286102295, 2.380000114440918}, {4.539999961853027, 2.530000686645508}, {5.930000305175781, 4.720000267028809}, {6.470000267028809, 5.810000419616699}, {8.100000381469727, 7.780000686645508}, {8.239999771118164, 7.950000286102295}, {8.3100004196167, 8.070000171661377}, {8.3100004196167, 8.130000114440918}, {8.3100004196167, 8.170000076293945}, {8.289999961853027, 8.200000286102295}, {8.239999771118164, 8.220000267028809}, {8.190000534057617, 8.240000247955322}, {8.100000381469727, 8.260000228881836}, {7.970000267028809, 8.260000228881836}, {7.960000038146973, 8.240000247955322}}}],FilledCurve[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}}}, {{{13.489999771118164, 15.0600004196167}, {7.010000228881836, 15.0600004196167}, {6.170000076293945, 15.0600004196167}, {5.450000286102295, 14.540000438690186}, {5.150000095367432, 13.8100004196167}, {13.469999313354492, 13.8100004196167}, {13.899999618530273, 13.8100004196167}, {14.25, 13.460000395774841}, {14.25, 13.030000448226929}, {14.25, 4.710000038146973}, {14.989999771118164, 5.010000228881836}, {15.510000228881836, 5.7300004959106445}, {15.510000228881836, 6.570000648498535}, {15.510000228881836, 13.040000438690186}, {15.510000228881836, 14.150000393390656}, {14.610000610351562, 15.0600004196167}, {13.489999771118164, 15.0600004196167}}}],FilledCurve[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}}}, {{{10.989999771118164, 12.790000438690186}, {4.510000228881836, 12.790000438690186}, {3.669999837875366, 12.790000438690186}, {2.950000047683716, 12.270000457763672}, {2.6499998569488525, 11.540000438690186}, {10.969999313354492, 11.540000438690186}, {11.399999618530273, 11.540000438690186}, {11.75, 11.190000534057617}, {11.75, 10.760000228881836}, {11.75, 2.439999580383301}, {12.489999771118164, 2.739999771118164}, {13.010000228881836, 3.4600000381469727}, {13.010000228881836, 4.300000190734863}, {13.010000228881836, 10.780000686645508}, {13.010000228881836, 11.890000581741333}, {12.110000610351562, 12.800000429153442}, {10.989999771118164, 12.800000429153442}, {10.989999771118164, 12.790000438690186}}}]}, ImageSize -> 20{17., 15.}/17, PlotRange -> {{0., 16.540000915527344}, {0., 14.510000228881836}},ImagePadding->{{0,1},{1,0}},AspectRatio -> Automatic, BaselinePosition->Scaled[.25]]

iconData["downChevron", col_] := Graphics[{col, CapForm["Round"], Thickness[.25], Line[{{-1,0},{0,-1},{1,0}}]}, AspectRatio -> Full, ImageSize -> {7,4}, ImagePadding->{{0,1},{1,0}}, BaselinePosition->Scaled[-.5]]

iconData["clear", col_] := Graphics[{col, Disk[{0, 0}, 2.5], White, Thickness[.13], CapForm["Round"], Line[{{{-1, -1}, {1, 1}},{{1, -1}, {-1, 1}}}]},ImageSize->14{1, 1}, ImagePadding->{{0,1},{1,0}}, BaselinePosition->Scaled[.1]]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
