(*
	This package contains utility functions that are not tied to Chatbook
	directly in any way.
*)

(* cSpell: ignore deflatten *)

BeginPackage["Wolfram`Chatbook`Utils`"]

`associationKeyDeflatten;
`fixLineEndings;

CellPrint2

FirstMatchingPositionOrder::usage = "FirstMatchingPositionOrder[patterns][a, b] returns an ordering value based on the positions of the first pattern in patterns to match a and b."

Begin["`Private`"]

Needs["Wolfram`Chatbook`ErrorUtils`"]
Needs["Wolfram`Chatbook`Common`"]

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

	Wolfram`Chatbook`UI`Private`moveAfterPreviousOutputs[evalCell];

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

FirstMatchingPositionOrder[patterns_?ListQ][a_, b_] := Module[{
	aPos,
	bPos
},
	aPos = FirstPosition[patterns, _?(patt |-> MatchQ[a, patt]), None, {1}];
	bPos = FirstPosition[patterns, _?(patt |-> MatchQ[b, patt]), None, {1}];

	Replace[{aPos, bPos}, {
		(* If neither `a` nor `b` match, then they are already in order. *)
		{None, None} -> True,
		(* If only `a` matches, it's already in order. *)
		{Except[None], None} -> True,
		(* If only `b` matches, it should come earlier. *)
		{None, Except[None]} -> -1,
		(* If both `a` and `b` match, sort based on the position of the matched pattern. *)
		{{aIdx_?IntegerQ}, {bIdx_?IntegerQ}} :> Order[aIdx, bIdx],
		other_ :> FailureMessage[
			FirstMatchingPositionOrder::unexpected,
			"Unexpected position values: ``",
			{other}
		]
	}]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AssociationKeyDeflatten*)
(* https://resources.wolframcloud.com/FunctionRepository/resources/AssociationKeyDeflatten *)
importResourceFunction[ associationKeyDeflatten, "AssociationKeyDeflatten" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*fixLineEndings*)
fixLineEndings // beginDefinition;
fixLineEndings[ string_String? StringQ ] := StringReplace[ string, "\r\n" -> "\n" ];
fixLineEndings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
