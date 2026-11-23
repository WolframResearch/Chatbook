(* ::Package:: *)

(*
	Notebook Diff producer for the cell-local CellDiff view.

	Load and create:

		Get["/path/to/FrontEnd/docs/CellDiffNotebookDiff.wl"];
		diff = CellDiffNotebookDiff`CreateNotebookDiff["/path/to/old.nb", "/path/to/new.nb"];

	old and new are notebook paths, NotebookObjects, or Notebook expressions; an optional third argument chooses
	"Lines" (the default) or "Inline". NotebookDiffExpression gives the same notebook as an expression without a
	front end. A path is read without evaluating anything outside its Notebook expression, unlike Get, but that
	expression itself is evaluated, as a NotebookGet result is.

	Show a notebook the user has open as a diff against an edited copy of it, in its own window:

		CellDiffNotebookDiff`ShowNotebookDiff[notebook, snapshot];

	The source is a NotebookObject, or a notebook path, which is opened. Old is the notebook as it is, unsaved changes
	included, and new is the snapshot, an open notebook such as the hidden copy an agent edited, or a notebook path; the
	snapshot's notebook options are not used. The diff replaces the source's cells in one undoable NotebookWrite and
	keeps its window, file, and options, except that its stylesheet gains the CellDiff control styles and its dynamic
	expression attaches the toolbar. The result is the source NotebookObject, or a Failure when the snapshot or the
	source is not a notebook, or the source already shows a diff.

	The generated notebook is the new notebook in new order, with its cell groups open or closed as they were saved.
	A cell whose content changed becomes a CellDiff host holding its saved old cell, an inserted cell becomes a host
	with an empty old cell, and a deleted cell becomes an empty host holding the old cell, placed after the cell it
	followed in the old notebook and in that cell's group. A changed cell that switches between text and boxes is
	shown as a deletion and an insertion, and a changed cell that neither editor can diff is shown whole behind a red
	or green left frame. Unchanged cells are left alone, so a cell that only moved is not marked. A cell whose only
	change is its cell tags, such as the target of a new hyperlink, is written as the new cell and not marked: tags
	are not shown, and resolving a host keeps its new tags whichever side it takes.

	A toolbar at the top right of the window, attached as the find toolbar is, steps the selection to the previous or
	next changed cell and accepts or rejects every change. Accept All keeps each host's live cell and Reject All puts
	back its saved old cell, both without the CellDiff options and the diff tags; Accept All removes the cells that only
	show a deletion and Reject All those that only show an insertion, and framed cells lose their frame. That leaves the
	new or the old notebook, as one undo step, and the toolbar then restores the stylesheet and dynamic expression the
	notebook had and goes. In a generated notebook, the toolbar's close button removes it and leaves the changes
	unresolved. The toolbar finds its cells by the "NotebookDiff" cell tags and needs no package in the evaluating
	kernel. Attached cells are not saved, so the notebook's dynamic expression attaches the toolbar again whenever the
	notebook is open and still shows a change. Resolving a cell's last change with its own controls drops the CellDiff
	options and the diff tags too, so the toolbar no longer finds it.

	Cells are matched by ExpressionUUID, CellUUID, or CellID first. Cells without a shared identity, such as
	re-evaluated outputs, are aligned in order by content, and the differing cells between two aligned neighbors are
	paired when they share at least half of their words and box tokens.

	The control styles come from Core.nb. The diff colors, the toolbar buttons, and the accept and reject glyphs come
	from CellDiffControlStyles.wl.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "CellDiffControlStyles.wl"}]];

BeginPackage["CellDiffNotebookDiff`", {"CellDiffControlStyles`"}];

CreateNotebookDiff::usage =
	"CreateNotebookDiff[old, new, mode] opens the notebook given by NotebookDiffExpression[old, new, mode].";

NotebookDiffExpression::usage =
	"NotebookDiffExpression[old, new, mode] gives new as a Notebook expression whose changed, inserted, and deleted " <>
	"cells are Inline or Lines CellDiff hosts. old and new are notebook paths, objects, or expressions.";

ShowNotebookDiff::usage =
	"ShowNotebookDiff[source, snapshot, mode] replaces the cells of the open notebook or notebook file source by " <>
	"the notebook diff of its current content against snapshot, an open notebook or a notebook file, keeping its " <>
	"window, file, and options, and gives its NotebookObject.";

Begin["`Private`"];

$identityOptions = ExpressionUUID | System`CellUUID | CellID;
$volatileOptions = $identityOptions | CellChangeTimes | CellLabel;

(* Every cell showing a change carries $diffTag; a cell that exists only to show one side also carries that side. *)
$diffTag = "NotebookDiff";
$deletedTag = "NotebookDiffDeleted";
$insertedTag = "NotebookDiffInserted";
(* The toolbar, attached to the notebook's window at its top right. *)
$toolbarTag = "NotebookDiffToolbar";

(* NotebookGet leaves out ExpressionUUIDs unless asked. A file is read without evaluating anything outside its one
   Notebook expression, unlike Get; like a NotebookGet result, that expression is still evaluated. *)
notebookExpression[notebook_Notebook] := notebook;
notebookExpression[notebook_NotebookObject] := Quiet[NotebookGet[notebook, "IncludeUUIDs" -> True]];
notebookExpression[path_String] := Replace[
	DeleteCases[Quiet[ReadList[path, Hold[Expression]]], Hold[Null]],
	{{Hold[notebook : Notebook[_List, ___]]} :> notebook, _ -> $Failed}];
notebookExpression[_] := $Failed;

leafCells[Cell[CellGroupData[cells_List, ___], ___]] := leafCells[cells];
leafCells[cells_List] := Flatten[leafCells /@ cells];
leafCells[cell_Cell] := {cell};

(* Identity, timestamps, and evaluation labels change without the cell itself changing. *)
stableCell[cell_Cell] := DeleteCases[cell, $volatileOptions -> _, Infinity];

(* The strongest identity a cell carries, whichever order its options are in. *)
cellIdentity[cell_Cell] := First[
	Flatten[Cases[cell, (# -> identity_) :> identity, {1}] & /@ List @@ $identityOptions, 1],
	Missing["Identity"]];

(* The editors that can host a CellDiff view. *)
cellEditor[Cell[_String | _TextData, ___]] := "StyledText";
cellEditor[Cell[_BoxData, ___]] := "MathEdit";
cellEditor[_] := None;

(* The saved host of the producer contract: the new cell carrying its view options and its saved old cell. *)
withoutCellDiff[cell_Cell] := DeleteCases[cell, (System`CellDiffOptions | System`CellDiff) -> _, Infinity];

hostCell[new_Cell, old_Cell, mode_String] := Replace[
	withoutCellDiff[new],
	Cell[arguments___] :> Cell[arguments,
		System`CellDiffOptions -> {
			"ViewMode" -> mode, "ShowCarets" -> False,
			"HunkControls" -> Automatic, "CellControls" -> Automatic},
		System`CellDiff -> FE`CellDiffData[1, withoutCellDiff[old]]]];

emptyCell[Cell[_BoxData, rest___]] := stableCell @ Cell[BoxData[""], rest];
emptyCell[Cell[_, rest___]] := stableCell @ Cell[TextData[""], rest];

taggedCell[Cell[arguments___], tags___String] := Cell[
	Sequence @@ DeleteCases[{arguments}, CellTags -> _],
	CellTags -> Flatten[{Cases[{arguments}, (CellTags -> existing_) :> existing], $diffTag, tags}]];

(* A cell no editor can diff is shown whole behind a colored left frame. *)
framedCell[Cell[arguments___], color_, tag_] :=
	taggedCell[Cell[arguments, CellFrame -> {{3, 0}, {0, 0}}, CellFrameColor -> color], tag];

insertedCell[new_Cell] := If[cellEditor[new] === None,
	framedCell[new, RGBColor[0.1, 0.83, 0], $insertedTag],
	host[new, emptyCell[new], $insertedTag]];

deletedCell[old_Cell] := If[cellEditor[old] === None,
	framedCell[old, RGBColor[1, 0.34, 0.34], $deletedTag],
	host[emptyCell[old], old, $deletedTag]];

withoutTags[cell_Cell] := DeleteCases[stableCell[cell], CellTags -> _];

pairedCells[old_Cell, new_Cell] := Which[
	withoutTags[old] === withoutTags[new], new,
	cellEditor[old] =!= None && cellEditor[old] === cellEditor[new], host[new, old],
	True, {deletedCell[old], insertedCell[new]}];

uniqueIdentityIndex[cells_List] :=
	First /@ Select[KeyDrop[PositionIndex[cellIdentity /@ cells], Missing["Identity"]], Length[#] === 1 &];

identityPairs[oldCells_List, newCells_List] :=
	Values @ Merge[KeyIntersection[uniqueIdentityIndex /@ {oldCells, newCells}], Identity];

tokenCounts[cell_Cell] := Counts @ Flatten @ StringSplit @ Cases[First[cell], _String, {0, Infinity}];

tokenSimilarity[old_Association, new_Association] :=
	2 Total[Merge[KeyIntersection[{old, new}], Min]] / Max[1, Total[old] + Total[new]];

(* Takes the most similar remaining pair first, so cells reordered between two aligned neighbors still pair. *)
similarPairs[oldCells_List, newCells_List] :=
	With[{oldTokens = tokenCounts /@ oldCells, newTokens = tokenCounts /@ newCells},
		Fold[
			Function[{pairs, pair},
				If[NoneTrue[pairs, First[#] === First[pair] || Last[#] === Last[pair] &], Append[pairs, pair], pairs]],
			{},
			Keys @ SortBy[
				Select[
					Association @ Flatten @ Table[
						{old, new} -> tokenSimilarity[oldTokens[[old]], newTokens[[new]]],
						{old, Length[oldCells]}, {new, Length[newCells]}],
					GreaterEqualThan[1/2]],
				Minus]]];

(* Identity pairs share a key wherever they sit; every other cell is keyed by content. SequenceAlignment gives runs
   of common keys, which pair in order, and {old run, new run} differences, whose unpaired cells pair by similarity. *)
matchedPairs[oldCells_List, newCells_List] :=
	Module[{identity = identityPairs[oldCells, newCells], identityKeys, alignment, ends},
		identityKeys = -Range[Length[identity]];
		alignment = SequenceAlignment[
			ReplacePart[Hash /@ stableCell /@ oldCells, Thread[identity[[All, 1]] -> identityKeys]],
			ReplacePart[Hash /@ stableCell /@ newCells, Thread[identity[[All, 2]] -> identityKeys]]];
		ends = Accumulate @ Replace[
			alignment,
			{{old_List, new_List} :> {Length[old], Length[new]}, common_List :> {Length[common], Length[common]}},
			{1}];
		Union[
			identity,
			Join @@ MapThread[
				Function[{segment, start, end},
					With[{
							old = Complement[Range[start[[1]] + 1, end[[1]]], identity[[All, 1]]],
							new = Complement[Range[start[[2]] + 1, end[[2]]], identity[[All, 2]]]},
						If[MatchQ[segment, {_List, _List}],
							{old[[#1]], new[[#2]]} & @@@ similarPairs[oldCells[[old]], newCells[[new]]],
							Transpose[{old, new}]]]],
				{alignment, Most @ Prepend[ends, {0, 0}], ends}]]];

(* The positions a group lists as visible, moved to the cells that show those members. *)
groupOpen[positions : {__Integer}, members_List] :=
	Join @@ MapThread[Range, {Most @ Prepend[#, 0] + 1, #} & @ Accumulate[Length /@ members]][[positions]];
groupOpen[open_, _] := open;

(* A cell tree with each leaf replaced by the cells that show it, as one list of cells per top-level cell. *)
regroupedCells[cells_List, shown_List] :=
	MapThread[regroupedCell, {cells, TakeList[shown, Length @* leafCells /@ cells]}];

regroupedCell[Cell[CellGroupData[cells_List, open_ : Open], options___], shown_List] :=
	With[{members = regroupedCells[cells, shown]},
		{Cell[CellGroupData[Join @@ members, groupOpen[open, members]], options]}];
regroupedCell[_Cell, {shown_}] := Flatten[{shown}];

(* New order is the spine and keeps its groups. A deleted old cell follows the new partner of the nearest matched old
   cell before it. *)
diffCells[oldCells_List, newCells_List, mode_String] :=
	Module[{old = leafCells[oldCells], new = leafCells[newCells], pairs, newIndex, oldIndex, anchors, deletedAfter},
		pairs = matchedPairs[old, new];
		newIndex = Association[Rule @@@ pairs];
		oldIndex = Association[Rule @@@ Reverse /@ pairs];
		anchors = Rest @ FoldList[Lookup[newIndex, #2, #1] &, 0, Range[Length[old]]];
		deletedAfter = Map[
			deletedCell /@ old[[#]] &,
			GroupBy[Complement[Range[Length[old]], Keys[newIndex]], anchors[[#]] &]];
		Join[
			Lookup[deletedAfter, 0, {}],
			Join @@ regroupedCells[
				newCells,
				Table[
					{
						If[KeyExistsQ[oldIndex, index],
							pairedCells[old[[oldIndex[index]]], new[[index]]],
							insertedCell[new[[index]]]],
						Lookup[deletedAfter, index, {}]
					},
					{index, Length[new]}]]] /.
			host[newCell_, oldCell_, tags___] :> taggedCell[hostCell[newCell, oldCell, mode], tags]
	];

$toolbarInk = LightDarkSwitched[GrayLevel[0.25], GrayLevel[0.85]];
$toolbarBackground = LightDarkSwitched[RGBColor["#FFFDEB"], RGBColor["#454029"]];
$toolbarFrame = Directive[AbsoluteThickness[0.5], LightDarkSwitched[GrayLevel[0.8], GrayLevel[0.4]]];

(* A stroked 12-point icon in the weight of the CellDiff accept and reject glyphs. *)
strokeGlyph[lines__] := With[{
		strokes = {$toolbarInk, AbsoluteThickness[1.5], CapForm["Round"], JoinForm["Round"], LineBox /@ {lines}}},
	GraphicsBox[strokes,
		ImageSize -> {12, 12}, PlotRange -> {{0, 12}, {0, 12}},
		PlotRangePadding -> None, ImagePadding -> 0, AspectRatio -> Automatic]];

$closeGlyph = strokeGlyph[{{3, 3}, {9, 9}}, {{3, 9}, {9, 3}}];
$previousGlyph = strokeGlyph[{{2.5, 4.25}, {6, 7.75}, {9.5, 4.25}}];
$nextGlyph = strokeGlyph[{{2.5, 7.75}, {6, 4.25}, {9.5, 7.75}}];

labeledGlyph[glyph_, label_] := GridBox[
	{{glyph, StyleBox[ToString[label, InputForm], FontSize -> 12, FontColor -> $toolbarInk]}},
	GridBoxAlignment -> {"Columns" -> {{Center}}, "Rows" -> {{Center}}},
	GridBoxSpacings -> {"Columns" -> {{0.5}}, "Rows" -> {{0}}}];

(* The compact button of the CellDiff toolbars, as wide as its content. *)
toolbarButton[content_, tooltip_, options___] := TooltipBox[
	CellDiffToolbarButton[content, Automatic, Automatic, options],
	ToString[tooltip, InputForm], TooltipStyle -> "TextStyling"];

findButton[glyph_, direction_, tooltip_] := With[{tag = $diffTag},
	toolbarButton[glyph, tooltip,
		ButtonFunction :> FrontEndExecute[{FrontEnd`NotebookFind[
			FrontEnd`ButtonNotebook[], tag, direction, CellTags, AutoScroll -> True, WrapAround -> True]}],
		Evaluator -> None, Method -> "Preemptive"]];

(* The cell a changed cell resolves to. A host accepts as its live cell and rejects as its saved old cell, and any
   other changed cell keeps its own; each loses the CellDiff options, the diff tags, and the frame of a cell that shows
   only one side. The toolbar's kernel need not have this package, so these are pure functions, and the CellDiff
   option names, which need not be System symbols there, are matched by name. *)
$acceptedCell = With[{diffTags = $diffTag | $deletedTag | $insertedTag, sideTags = $deletedTag | $insertedTag},
	Function[Replace[#, Cell[contents_, options___] :> With[{
			tags = DeleteCases[Flatten[Cases[{options}, (CellTags -> cellTags_) :> cellTags]], diffTags],
			frame = If[FreeQ[{options}, FE`CellDiffData] && !FreeQ[{options}, sideTags], CellFrame | CellFrameColor, None]},
		Cell[contents, Sequence @@ Join[
			DeleteCases[{options},
				(name_Symbol -> _) /; StringStartsQ[SymbolName[name], "CellDiff"] || MatchQ[name, CellTags | frame]],
			If[tags === {}, {}, {CellTags -> tags}]]]]]]];

$rejectedCell = With[{accepted = $acceptedCell},
	Function[Replace[#, {Cell[___, _ -> FE`CellDiffData[_, old_Cell], ___] :> old, cell_ :> accepted[cell]}]]];

(* The writes of one kernel evaluation are one undo step. NotebookRead leaves out ExpressionUUIDs unless asked. The
   cells are read in one call and written by one list of front end packets without scrolling, so the window is drawn
   once rather than after every cell. The notebook's own stylesheet and dynamic expression, given as restore, come
   back afterwards, and the toolbar goes. *)
resolveButton[glyph_, label_, obsoleteTag_, resolved_, restore_, tooltip_] := With[{tag = $diffTag, toolbarTag = $toolbarTag},
	CellDiffToolbarGroup @ toolbarButton[labeledGlyph[glyph, label], tooltip,
		ButtonFunction :> With[{notebook = EvaluationNotebook[]},
			NotebookDelete[Cells[notebook, CellTags -> obsoleteTag]];
			With[{cells = Cells[notebook, CellTags -> tag]},
				FrontEndExecute[MapThread[FrontEnd`NotebookWrite[#1, resolved[#2], AutoScroll -> False] &,
					{cells, NotebookRead[cells, "IncludeUUIDs" -> True]}]]];
			SetOptions[notebook, restore];
			NotebookDelete[Cells[notebook, AttachedCell -> True, CellTags -> toolbarTag]]],
		BoxID -> tag <> StringDelete[label, " "], Evaluator -> Automatic, Method -> "Queued"]];

(* The toolbar is a panel attached to the top right of the notebook's window, as the find toolbar is, so the notebook
   shows through beside it. Close, which only a generated notebook has, ends the panel; it removes the toolbar and the
   dynamic expression that brings it back. *)
diffToolbar[restore_, closable_] := With[{toolbarTag = $toolbarTag}, Cell[
	BoxData @ FrameBox[
		GridBox[{{
			resolveButton[CellDiffAcceptGlyph[], "Accept All", $deletedTag, $acceptedCell, restore,
				"Accept every change, leaving the new notebook"],
			resolveButton[CellDiffRejectGlyph[], "Reject All", $insertedTag, $rejectedCell, restore,
				"Reject every change, leaving the old notebook"],
			CellDiffToolbarGroup[
				findButton[$previousGlyph, Previous, "Select the previous changed cell"],
				findButton[$nextGlyph, Next, "Select the next changed cell"]],
			If[closable,
				CellDiffToolbarGroup @ toolbarButton[$closeGlyph, "Close this toolbar",
					ButtonFunction :> With[{notebook = EvaluationNotebook[]},
						SetOptions[notebook, Select[restore, MatchQ[#, NotebookDynamicExpression -> _] &]];
						NotebookDelete[Cells[notebook, AttachedCell -> True, CellTags -> toolbarTag]]],
					Evaluator -> Automatic, Method -> "Queued"],
				Nothing]
		}},
			GridBoxAlignment -> {"Columns" -> {{Left}}, "Rows" -> {{Center}}},
			GridBoxSpacings -> {"Columns" -> {{0.6}}, "Rows" -> {{0}}}],
		Background -> $toolbarBackground, FrameStyle -> $toolbarFrame, FrameMargins -> {{8, 8}, {6, 6}},
		RoundingRadius -> 6],
	CellTags -> toolbarTag, CellMargins -> 0, CellFrame -> 0, CellFrameMargins -> 0, Background -> None,
	ShowCellBracket -> False, Magnification -> 1]];

(* Attaches the toolbar to a notebook that shows a change and has none. A pure function, since it also runs from the
   notebook's dynamic expression, which needs no package in the evaluating kernel. *)
$attachToolbar = With[{tag = $diffTag, toolbarTag = $toolbarTag},
	Function[{notebook, toolbar},
		If[Cells[notebook, CellTags -> tag] =!= {} && Cells[notebook, AttachedCell -> True, CellTags -> toolbarTag] === {},
			AttachCell[notebook, toolbar, {Right, Top}, {-20, -8}, {Right, Top}, RemovalConditions -> None]];]];

(* The stylesheet and dynamic expression a notebook had, which the toolbar restores. *)
restoreOptions[options_List] := {
	StyleDefinitions -> Lookup[options, StyleDefinitions, "Default.nb"],
	NotebookDynamicExpression -> Lookup[options, NotebookDynamicExpression, Inherited]};

(* A diff adds the CellDiff control styles to the notebook's own stylesheet. Attached cells are not saved, so its
   dynamic expression attaches the toolbar when the notebook opens, after save and reopen too; setting it does not
   evaluate it in an open notebook, so ShowNotebookDiff attaches the toolbar itself. *)
diffOptions[restore_List, toolbar_Cell] := With[{attach = $attachToolbar}, {
	StyleDefinitions -> CellDiffStyleDefinitions[Lookup[restore, StyleDefinitions]],
	NotebookDynamicExpression -> Dynamic[Refresh[attach[EvaluationNotebook[], toolbar], None]]}];

(* Shows the diff options and the toolbar in an open notebook, before the packets that write the diff. *)
showDiffPackets[notebook_NotebookObject, options_List, packets_List] := With[{restore = restoreOptions[options]},
	With[{toolbar = diffToolbar[restore, False]},
		FrontEndExecute[Prepend[packets, FrontEnd`SetOptions[notebook, diffOptions[restore, toolbar]]]];
		$attachToolbar[notebook, toolbar]]];

NotebookDiffExpression[old_, new_, mode : "Inline" | "Lines" : "Lines"] :=
	Replace[
		notebookExpression /@ {old, new},
		{
			{Notebook[oldCells_List, ___], Notebook[newCells_List, options___]} :> With[{restore = restoreOptions[{options}]}, Notebook[
				diffCells[oldCells, newCells, mode],
				WindowTitle -> "Notebook Diff",
				Sequence @@ diffOptions[restore, diffToolbar[restore, True]],
				Sequence @@ DeleteCases[{options}, _[WindowTitle | StyleDefinitions | NotebookDynamicExpression, _]]]],
			_ :> Failure["InvalidNotebook",
				<|"MessageTemplate" -> "Both arguments must be notebook paths, objects, or expressions."|>]
		}];

CreateNotebookDiff[arguments__] :=
	Replace[NotebookDiffExpression[arguments], notebook_Notebook :> NotebookPut[notebook]];

failure[tag_, template_, parameter_] :=
	Failure[tag, <|"MessageTemplate" -> template, "MessageParameters" -> {parameter}|>];

openedNotebook[notebook_NotebookObject] := notebook;
openedNotebook[path_String] := If[FileExistsQ[path], NotebookOpen[path], $Failed];
openedNotebook[_] := $Failed;

(* The same comparison as edits of the old cells: {"Keep", positions} for runs of old cells that stay as they are, and
   {"Change", positions, cells} for runs of old cells (none for an insertion) that the cells showing the changes
   replace, in document order. Only the changes need to be written: in a notebook of thousands of cells, rewriting all
   of them was almost all of the time. *)
diffSpans[oldCells_List, newCells_List, mode_String] := changeSpans[diffEntries[leafCells[oldCells], leafCells[newCells]], mode];

(* {old positions, cells shown, whether the old cell stays} for lists of leaf cells, in the order shown *)
diffEntries[old_List, new_List] :=
	Module[{pairs, newIndex, oldIndex, anchors, deletedAfter},
		pairs = matchedPairs[old, new];
		newIndex = Association[Rule @@@ pairs];
		oldIndex = Association[Rule @@@ Reverse /@ pairs];
		anchors = Rest @ FoldList[Lookup[newIndex, #2, #1] &, 0, Range[Length[old]]];
		deletedAfter = GroupBy[Complement[Range[Length[old]], Keys[newIndex]], anchors[[#]] &];
		Join[
			{{Lookup[deletedAfter, 0, {}], deletedCell /@ old[[Lookup[deletedAfter, 0, {}]]], False}},
			Join @@ Table[
				With[{o = Lookup[oldIndex, index, None], deleted = Lookup[deletedAfter, index, {}]},
					{
						Which[
							o === None, {{}, {insertedCell[new[[index]]]}, False},
							stableCell[old[[o]]] === stableCell[new[[index]]], {{o}, {}, True},
							True, {{o}, Flatten[{pairedCells[old[[o]], new[[index]]]}], False}],
						{deleted, deletedCell /@ old[[deleted]], False}
					}],
				{index, Length[new]}]]
	];

(* Entries {old positions, cells shown, whether the old cell stays}, in the order shown, as spans *)
changeSpans[entries_List, mode_String] := DeleteCases[
	If[TrueQ[#[[1, 3]]],
		{"Keep", Join @@ #[[All, 1]]},
		{"Change", Sort[Join @@ #[[All, 1]]], Flatten[#[[All, 2]]]}] & /@ SplitBy[entries, Last],
	{"Change", {}, {}}] /. host[newCell_, oldCell_, tags___] :> taggedCell[hostCell[newCell, oldCell, mode], tags];

(* The spans of an open notebook and its edited snapshot when the edits are known: the snapshot keeps its cells'
   ExpressionUUIDs (CellObject[uuid, ...]), so of the cells both have only the edited ones can differ. Between two of
   those, the cells only one of them has are compared as the whole comparison compares them, so that an output written
   again by an evaluation, which has a new uuid, stays when it comes out the same. Only those cells are read: no
   NotebookGet of either notebook, and no comparison of the others. {spans, the notebook's cells}, or None if the cells
   do not line up (no uuids, the same uuid twice, or cells in another order). *)
editedSpans[notebook_NotebookObject, snapshot_NotebookObject, edited_List, mode_String] :=
	Module[{old = Cells[notebook], new = Cells[snapshot], oldIDs, newIDs, oldIndex, editedQ, readOld, readNew, next = 1,
			inserted = {}, entries = {}, unmatched},
		{oldIDs, newIDs} = Map[Replace[#, {CellObject[id_String, ___] :> id, _ -> None}] &, {old, new}, {2}];
		If[MemberQ[Join[oldIDs, newIDs], None] || !DuplicateFreeQ[oldIDs] || !DuplicateFreeQ[newIDs], Return[None, Module]];
		oldIndex = AssociationThread[oldIDs -> Range[Length[old]]];
		If[!OrderedQ[Lookup[oldIndex, Select[newIDs, KeyExistsQ[oldIndex, #] &]]], Return[None, Module]];
		editedQ = AssociationThread[edited -> True];
		readOld = Select[Range[Length[old]], !MemberQ[newIDs, oldIDs[[#]]] || KeyExistsQ[editedQ, oldIDs[[#]]] &];
		readNew = Select[Range[Length[new]], !KeyExistsQ[oldIndex, newIDs[[#]]] || KeyExistsQ[editedQ, newIDs[[#]]] &];
		readOld = AssociationThread[readOld -> If[readOld === {}, {}, NotebookRead[old[[readOld]]]]];
		readNew = AssociationThread[readNew -> If[readNew === {}, {}, NotebookRead[new[[readNew]]]]];
		unmatched[upTo_] := (
			entries = Join[entries,
				{next - 1 + #1, #2, #3} & @@@ diffEntries[Lookup[readOld, Range[next, upTo]], Lookup[readNew, inserted]]];
			next = upTo + 1;
			inserted = {});
		Do[
			With[{p = Lookup[oldIndex, newIDs[[j]], None]},
				If[p === None,
					AppendTo[inserted, j],
					unmatched[p - 1];
					AppendTo[entries, Which[
						!KeyExistsQ[editedQ, newIDs[[j]]] || stableCell[readOld[p]] === stableCell[readNew[j]], {{p}, {}, True},
						True, {{p}, Flatten[{pairedCells[readOld[p], readNew[j]]}], False}]];
					next = p + 1]],
			{j, Length[new]}];
		unmatched[Length[old]];
		{changeSpans[entries, mode], old}];

(* The packets that write the changes of spans into a notebook whose cells are objects (Cells[notebook], one per old
   cell): each run of changed old cells is replaced where it stands, and an insertion goes after the kept cell before
   it (or before the kept cell after it). None unless the spans list every old cell once, in order (cells that moved
   past kept ones, which only the whole rewrite shows), or if most cells change, where one write of all of them is
   faster than one write per run. *)
spanPackets[notebook_NotebookObject, spans_List, objects_List] :=
	Module[{packets = {}, kept},
		If[Join @@ spans[[All, 2]] =!= Range[Length[objects]], Return[None, Module]];
		If[2 Total[Length[#[[2]]] & /@ Cases[spans, {"Change", __}]] > Length[objects], Return[None, Module]];
		Do[
			With[{span = spans[[i]]},
				If[span[[1]] === "Change",
					Which[
						span[[2]] =!= {},
							packets = Join[packets,
								{FrontEnd`SelectionMove[objects[[First[span[[2]]]]], All, Cell, AutoScroll -> False],
									FrontEnd`NotebookWrite[notebook, span[[3]], After, AutoScroll -> False]},
								Join @@ ({FrontEnd`SelectionMove[objects[[#]], All, Cell, AutoScroll -> False],
									FrontEnd`NotebookDelete[notebook, AutoScroll -> False]} & /@ Rest[span[[2]]])],
						True,
							kept = Which[
								i > 1, {objects[[Last[spans[[i - 1, 2]]]]], After},
								i < Length[spans], {objects[[First[spans[[i + 1, 2]]]]], Before},
								True, Return[None, Module]];
							packets = Join[packets,
								{FrontEnd`SelectionMove[kept[[1]], kept[[2]], Cell, AutoScroll -> False],
									FrontEnd`NotebookWrite[notebook, span[[3]], After, AutoScroll -> False]}]]]],
			{i, Length[spans]}];
		packets];

(* One NotebookWrite replaces the cells, as one undo step that keeps the window, file, and options. NotebookPut would
   replace the options too, and it cannot be undone: it clears the notebook's undo history, and Undo after it leaves
   the notebook empty. The options, the selection and the write go to the front end as one list of packets, so that it
   lays out and draws the notebook once, rather than the old cells in the new stylesheet first. *)
ShowNotebookDiff[source_, snapshot_, mode : "Inline" | "Lines" : "Lines"] := Replace[notebookExpression[snapshot], {
	Notebook[newCells_List, ___] :> With[{notebook = openedNotebook[source]},
		Replace[notebookExpression[notebook], {
			_Notebook /; Cells[notebook, CellTags -> $diffTag] =!= {} :>
				failure["DiffShown", "`1` already shows a notebook diff.", notebook],
			Notebook[oldCells_List, oldOptions___] :> With[{objects = Cells[notebook]},
				showDiffPackets[notebook, {oldOptions}, Join[
					Replace[
						If[Length[objects] === Length[leafCells[oldCells]],
							spanPackets[notebook, diffSpans[oldCells, newCells, mode], objects],
							None],
						None :> {
							FrontEnd`SelectionMove[notebook, All, Notebook, 1, AutoScroll -> False],
							FrontEnd`NotebookWrite[notebook, diffCells[oldCells, newCells, mode], After, AutoScroll -> False]}],
					{FrontEnd`SelectionMove[notebook, Before, Notebook, 1, AutoScroll -> True]}]];
				SetSelectedNotebook[notebook];
				notebook],
			_ :> failure["InvalidSource", "`1` is not an open notebook or a notebook file.", source]}]],
	_ :> failure["InvalidSnapshot", "`1` is not an open notebook or a notebook file.", snapshot]}];

(* With the ExpressionUUIDs of the snapshot's edited cells (the producer knows them), only the cells that changed are
   read and written; anything that does not line up falls back to the whole comparison above. *)
ShowNotebookDiff[source_, snapshot_NotebookObject, mode : "Inline" | "Lines", edited : {___String}] :=
	With[{notebook = openedNotebook[source]},
		Which[
			Head[notebook] =!= NotebookObject, ShowNotebookDiff[source, snapshot, mode],
			Cells[notebook, CellTags -> $diffTag] =!= {}, failure["DiffShown", "`1` already shows a notebook diff.", notebook],
			True,
				Replace[editedSpans[notebook, snapshot, edited, mode], {
					{spans_, objects_} :> Replace[spanPackets[notebook, spans, objects], {
						None :> ShowNotebookDiff[notebook, snapshot, mode],
						packets_List :> (
							showDiffPackets[notebook, Options[notebook, {StyleDefinitions, NotebookDynamicExpression}],
								Append[packets, FrontEnd`SelectionMove[notebook, Before, Notebook, 1, AutoScroll -> True]]];
							SetSelectedNotebook[notebook];
							notebook)}],
					None :> ShowNotebookDiff[notebook, snapshot, mode]}]]];

End[];

EndPackage[];
