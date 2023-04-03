(*
	This package contains utility functions that are not tied to Chatbook
	directly in any way.
*)

BeginPackage["ConnorGray`Chatbook`Utils`"]

CellPrint2

Begin["`Private`"]

Needs["ConnorGray`Chatbook`ErrorUtils`"]
Needs["ConnorGray`Chatbook`UI`"]

(*====================================*)

SetFallthroughError[CellPrint2]

(*
	Alternative to CellPrint[] where the first argument is an evaluation input
	cell, and the new cell will be printed after any existing output cells.

	`CellPrint[arg]` is conceptually `CellPrint2[EvaluationCell[], arg]`.
*)
CellPrint2[
	evalCell_CellObject,
	Cell[cellData_, cellStyles___?StringQ, cellOpts___?OptionQ]
] := With[{
	uuid = CreateUUID[]
}, Module[{
	cell = Cell[
		cellData,
		cellStyles,
		GeneratedCell -> True,
		CellAutoOverwrite -> True,
		ExpressionUUID -> uuid,
		cellOpts
	],
	obj
},
	RaiseAssert[
		Experimental`CellExistsQ[evalCell],
		"Unable to print cell: evaluation cell does not exist."
	];

	ConnorGray`Chatbook`UI`Private`moveAfterPreviousOutputs[evalCell];

	RaiseConfirm @ NotebookWrite[ParentNotebook[evalCell], cell];

	obj = CellObject[uuid];

	RaiseAssert[
		Experimental`CellExistsQ[obj],
		<| "CellExpression" -> cell |>,
		"Error printing cell: written cell was not created or could not be found."
	];

	obj
]]

(*====================================*)

End[]

EndPackage[]
