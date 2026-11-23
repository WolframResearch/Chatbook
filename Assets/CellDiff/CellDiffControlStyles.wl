(* ::Package:: *)

(*
	The CellDiff review colors and toolbar chrome.

	Core.nb defines the CellDiffHunkControls, CodeReviewHunkToolbar, CellDiffControls, and CellDiffToolbar styles;
	SystemFiles/Source/CellDiffStyles.wl generates them. CellDiffStyleDefinitions[base] gives a private stylesheet
	that adds the diff colors to a named or private stylesheet. CellDiffToolbarButton and CellDiffToolbarGroup build
	buttons and their frame in the look of those templates, for a toolbar that is not a template of the stylesheet,
	such as the docked toolbar of CellDiffNotebookDiff.wl.

	Loaded by CellDiffViewExplorer.wl and CellDiffNotebookDiff.wl.
*)

BeginPackage["CellDiffControlStyles`"];

CellDiffStyleDefinitions::usage =
	"CellDiffStyleDefinitions[base] gives a private stylesheet that adds the CellDiff review colors to the " <>
	"named or private stylesheet base.";

CellDiffAcceptGlyph::usage =
	"CellDiffAcceptGlyph[] gives the boxes of the accept checkmark used by the CellDiff toolbars.";

CellDiffRejectGlyph::usage =
	"CellDiffRejectGlyph[] gives the boxes of the reject cross used by the CellDiff toolbars.";

CellDiffToolbarButton::usage =
	"CellDiffToolbarButton[content, width, hoverBackground, options] gives the boxes of the frameless 20-point-high " <>
	"toolbar button whose content tints under the mouse. width is in points, or Automatic for a padded button as " <>
	"wide as its content; hoverBackground Automatic gives the neutral tint; options are ButtonBox options.";

CellDiffToolbarGroup::usage =
	"CellDiffToolbarGroup[buttons] gives the boxes of buttons sharing one rounded frame, separated by hairlines.";

Begin["`Private`"];

(* Native vector paths and colors from the supplied Accept and Reject SVGs.
   Coordinates are flipped vertically from SVG's top-left origin; the icons remain sharp at any magnification. *)
CellDiffAcceptGlyph[] := GraphicsBox[{
	RGBColor[0, 0.666667, 0], AbsoluteThickness[1.5], CapForm["Round"],
	LineBox[{{0.75, 6.13192}, {4.04501, 2.04545}, {10.6356, 9.9541}}]},
	ImageSize -> {12, 11}, PlotRange -> {{0, 12}, {0, 11}},
	PlotRangePadding -> None, ImagePadding -> 0, AspectRatio -> Automatic];

CellDiffRejectGlyph[] := GraphicsBox[{
	RGBColor[0.933333, 0.364706, 0.364706], AbsoluteThickness[1.5], CapForm["Round"],
	LineBox[{{1.35791, 0.90234}, {9.55127, 9.095703}}],
	LineBox[{{9.55127, 0.90234}, {1.35791, 9.095703}}]},
	ImageSize -> {11, 10}, PlotRange -> {{0, 11}, {0, 10}},
	PlotRangePadding -> None, ImagePadding -> 0, AspectRatio -> Automatic];

$hairline = Directive[AbsoluteThickness[0.5], LightDarkSwitched[GrayLevel[0.85], GrayLevel[0.35]]];

CellDiffToolbarButton[content_, width_, Automatic, options___] :=
	CellDiffToolbarButton[content, width, LightDarkSwitched[GrayLevel[0.94], GrayLevel[0.22]], options];

CellDiffToolbarButton[content_, width_, hoverBackground_, options___] := ButtonBox[
	FrameBox[
		PaneBox[content, ImageSize -> {width, 20}, Alignment -> {Center, Center}, BaselinePosition -> Center],
		Background -> Dynamic[If[CurrentValue["MouseOver"], hoverBackground, None]],
		FrameStyle -> None, FrameMargins -> If[width === Automatic, {{5, 5}, {0, 0}}, 0], RoundingRadius -> 4],
	options, Appearance -> "Frameless", ContentPadding -> False, FrameMargins -> 0, ImageMargins -> 0];

CellDiffToolbarGroup[buttons__] := FrameBox[
	GridBox[{{buttons}},
		GridBoxAlignment -> {"Columns" -> {{Center}}, "Rows" -> {{Center}}},
		GridBoxSpacings -> {"Columns" -> {{0}}, "Rows" -> {{0}}},
		GridBoxDividers -> {"ColumnsIndexed" -> Table[column -> $hairline, {column, 2, Length[{buttons}]}]}],
	Background -> LightDarkSwitched[GrayLevel[1], RGBColor[0.10, 0.11, 0.13]],
	FrameStyle -> $hairline, FrameMargins -> 1, RoundingRadius -> 5];

(* The first definition of a style wins, so a private base stylesheet keeps every style it already defines. *)
CellDiffStyleDefinitions[Notebook[styles_List, options___]] := Notebook[Join[styles, {
	Cell[StyleData["Notebook"],
		System`CellDiffOptions -> {
			"AddedBorderColor" -> None,
			"RemovedBorderColor" -> None,
			"ModifiedBorderColor" -> None,
			"PartnerBorderColor" -> None,
			"LinesNewBackground" -> LightDarkSwitched[RGBColor["#DAFFD8"], RGBColor["#20372A"]],
			"LinesOldBackground" -> LightDarkSwitched[RGBColor["#FFF0F0"], RGBColor["#39282C"]],
			"AddedBackground" -> LightDarkSwitched[Hue[125/360, 0.40, 0.98], RGBColor["#315C40"]],
			"RemovedBackground" -> LightDarkSwitched[Hue[5/360, 0.26, 1.00], RGBColor["#63363D"]]}]
	}], options];

CellDiffStyleDefinitions[base_: "Default.nb"] := CellDiffStyleDefinitions[Notebook[
	{Cell[StyleData[StyleDefinitions -> base]]},
	Visible -> False, StyleDefinitions -> "PrivateStylesheetFormatting.nb"]];

End[];

EndPackage[];
