(* ::Package:: *)

(* ::Title:: *)
(*Manage FE expression resources*)


(* ::Section::Closed:: *)
(*Package Header*)


BeginPackage["Wolfram`ChatbookFrontEndResourceBuilder`"]


ClearAll[ "`*" ];
ClearAll[ "`Private`*" ];


WriteTextResource;
FEResource;


Begin["`Private`"]


(* ::Section::Closed:: *)
(*Paths*)


$resourceLocation = FileNameJoin @ { If[# === "", DirectoryName @ NotebookDirectory[], DirectoryName @ DirectoryName @ #]&[$InputFileName], "FrontEnd", "TextResources", "ChatbookResources.tr"};


(* ::Section::Closed:: *)
(*WriteTextResource*)


WriteTextResource::nores = "The file `1` doesn't contain a resource with name `2`.";
WriteTextResource::badkey = "Key `1` not found. Continuing without writing the new value.";
WriteTextResource::fallthru = "Using the InputForm string for unknown expression type: `1`";
WriteTextResource::badLang = "Unrecognized localization language: `1`";
WriteTextResource::badLangPath = "Localization filepath `1` does not match the intended language `2`";
WriteTextResource::badNewEntry = "Value of option \"NewEntry\" must be True, False, or a string.";
WriteTextResource::repeatNewEntry = "Trying to add an entry that already exists. Continuing without writing the new value.";


Options[WriteTextResource] = {"NewEntry" -> False, "NewEntryPrefix" -> "\n"};
Options[doWriteTextResource] = {"NewEntry" -> False, "NewEntryPrefix" -> "\n"};


WriteTextResource[name_String, opts:OptionsPattern[]] := WriteTextResource[name -> FEResource[name], opts]


WriteTextResource[name_String -> data_, opts:OptionsPattern[]] :=
Module[{absfile, reducedOpts},

	absfile = $resourceLocation;
	If[FailureQ[absfile], Return[absfile]];
		
	reducedOpts = Sequence @@ FilterRules[DeleteDuplicatesBy[First][Join[{opts}, Options[WriteTextResource]]], Options[doWriteTextResource]];
	
	doWriteTextResource[{absfile, "@@resource ChatbookExpressions"} -> name -> data, reducedOpts]
]


doWriteTextResource[{file_, resourceLine_} -> data_, opts:OptionsPattern[]] :=
Module[{lines, resources, newresources, st},
	(* read in all the lines of the resource file *)
	If[FileExistsQ[file], lines = Import[file, "Lines"], Message[WriteTextResource::fnfnd, file]; Return[$Failed]];
	(* group the lines for each resource together *)
	resources = Split[lines, !StringStartsQ[StringTrim[#2], "@@resource " | "@|"]&];
	Which[
		MemberQ[resources, {resourceLine, __String}],
			(* replace the indicated resource's old lines with the new ones *)
			newresources = resources /. {resourceLine, oldlines__} :> {resourceLine,
				Switch[data,
					_String, data,
					_String -> _, replaceKeyValueInString[StringRiffle[{oldlines}, "\n"], data, opts],
					_, toTextResourceString[data]
				]},
		MatchQ[resources, {{__}}],
			(* the file only defines one resource, without the @@resource line *)
			newresources = {
				Switch[data,
					_String, data,
					_String -> _, replaceKeyValueInString[StringRiffle[Flatten[resources], "\n"], data, opts],
					_, toTextResourceString[data]]},
		True,
			Message[WriteTextResource::nores, file, resourceLine];
			Return[$Failed]
		];
	(* write all the lines back into the file *)
	st = OpenWrite[file];
	WriteString[st, StringRiffle[Flatten[newresources], {"", "\n", "\n"}]];
	Close[st]
]


(* ::Subsubsection::Closed:: *)
(*replaceKeyValueInString*)


Options[replaceKeyValueInString] = {"NewEntry" -> False, "NewEntryPrefix" -> "\n"};
replaceKeyValueInString[str_String, key_String -> value_, OptionsPattern[]] :=
	Replace[OptionValue["NewEntry"], {
		False :> changeKeyValueInString[str, key -> value],
		newEntry_ :> addKeyValueInString[str, key -> value, newEntry, 
			Replace[OptionValue["NewEntryPrefix"], Except[_String] -> "\n"]
		]
	}]


(*
changeKeyValueInString is a hack, but a useful one. It looks through the string for
the first substring that looks like "key -> ". It then uses SyntaxLength to determine
the extent of the old value, and replaces it with the new.

This may fail spectacularly, but in practice it works remarkably well with strings
extracted from tr files.
*)

changeKeyValueInString[str_String, key_String -> value_] :=
	Module[{keypos, valueLength, pre, post},
		keypos = StringPosition[str, "\"" <> key <> "\"" ~~ (WhitespaceCharacter...) ~~ "->"];
		If[MatchQ[keypos, {{_,_}}],
			keypos = First[keypos],
			Message[WriteTextResource::badkey, key];
			Return[str]
		];
		valueLength = SyntaxLength[StringDrop[str, Last[keypos]]];
		(* FIXME: check value length?? *)
		
		(* remember the whitespace used on either side of the old value, and add it to the new value *)
		With[{valueStr = StringTake[StringDrop[str, Last[keypos]], valueLength]},
			pre = Replace[StringJoin[StringCases[valueStr, StartOfString ~~ Whitespace]], Except[_String] :> ""];
			post = Replace[StringJoin[StringCases[valueStr, Whitespace ~~ EndOfString]], Except[_String] :> ""];
		];
		StringJoin[
			StringTake[str, First[keypos] - 1],
			"\"" <> key <> "\" ->",
			pre,
			toTextResourceString[value],
			post,
			StringDrop[str, Last[keypos] + valueLength]
		]
]


(*
Update: SyntaxLength does not perform well with localized text that involves unicode
e.g. \:#### found in ChineseSimplified, ChineseTraditional, and Japanese, so we
now use ToExpression on lists of key-value pairs to determine the next key starting
position.

If the key is not found, the option "NewEntry"->_String allows creating a key. An empty
string creates the entry at the end of the list, but a longer string can be provided to place 
it elsewhere within the list. The more specific the hint, the more accurate the placement. 
"NewEntry"->False is the default to prevent overwriting the file if the key is not found.

Examples for MiscStrings.tr's FEStrings:

	"KeyHint" -> "specialChars"       inserts after "specialCharsTitle" (* end of group *)
	"KeyHint" -> "specialCharsStruck" inserts after "specialCharsStruckTooltip" (* within group *)
*)

findNextKey[str_String, key_String, startOfString_:None] :=
	Module[{expr, keypos},
		expr = ToExpression[str];
		keypos = Position[expr, If[startOfString === None, HoldPattern[key -> _], HoldPattern[k_String -> _] /; StringStartsQ[k, startOfString]]];
		If[MatchQ[keypos, {{_}..}], keypos = Last[Last[keypos]], Return[None]];
		(* at this point keypos should be an integer *)
		If[keypos + 1 > Length[expr], None, Replace[expr[[keypos + 1]], {HoldPattern[k_String -> _] :> k, _ -> None}]]
	]


(* assume no indentation in key-value lists *)
insertAndWrapKeyValue[str_String, pre_, key_ -> value_, post_, {start_, stop_}] := 
	StringJoin[
		StringTake[str, start - 1],
		{pre, "\"" <> key <> "\"", " -> ", toTextResourceString[value], post},
		StringDrop[str, stop - 1]
	]

addToEnd[str_String, newEntryPrefix_, key_ -> value_, {start_, stop_}] :=
	insertAndWrapKeyValue[str, ",\n" <> newEntryPrefix, key -> value, "", {start, stop}]

addToMiddle[str_String, newEntryPrefix_, key_ -> value_, {start_, stop_}] :=
	insertAndWrapKeyValue[str, "\n" <> newEntryPrefix, key -> value, ",", {start, stop}];
	
replaceInMiddle[str_String, key_ -> value_, {start_, stop_}] :=
	insertAndWrapKeyValue[str, "", key -> value, "", {start, stop}]


(* create a new entry *)
addKeyValueInString[str_String, key_String -> value_, newEntry_, newEntryPrefix_] :=
	Module[{keypos, nextKey, nextKeyPos},
		keypos = StringPosition[str, "\"" <> key <> "\"" ~~ (WhitespaceCharacter...) ~~ "->"];
		keypos = If[MatchQ[keypos, {{_, _}}], First[First[keypos]], None];
		If[keypos === None,
			Which[
				newEntry === False, 
					Message[WriteTextResource::badkey, key]; Return[str],
				StringQ[newEntry] || TrueQ[newEntry], 
					(* Place new text near "key families". If no key family inferred from the newEntry string, then default to the end of the list. *)
					nextKey = findNextKey[str, key, If[TrueQ[newEntry], "", newEntry]];
					If[nextKey === None,
						nextKeyPos = First @ First @ StringPosition[str, (WhitespaceCharacter...) ~~ "}" ~~ (WhitespaceCharacter...) ~~ EndOfString];
						addToEnd[str, newEntryPrefix, key -> value, {nextKeyPos, nextKeyPos}]
						, 
						nextKeyPos = First @ First @ StringPosition[str, (WhitespaceCharacter...) ~~ "\"" <> nextKey <> "\"" ~~ (WhitespaceCharacter...) ~~ "->"];
						addToMiddle[str, newEntryPrefix, key -> value, {nextKeyPos, nextKeyPos}]
					],
				True,
					Message[WriteTextResource::badNewEntry]; Return[str]
			]
			, (* else replace existing key *)
			If[newEntry === False,
				nextKey = findNextKey[str, key];
				If[nextKeyPos === None,
					nextKeyPos = First @ First @ StringPosition[str, (WhitespaceCharacter...) ~~ "}" ~~ (WhitespaceCharacter...) ~~ EndOfString];
					addToEnd[str, newEntryPrefix, key -> value, {nextKeyPos, nextKeyPos}]
					, (* else common case of key-value somewhere in the middle *)
					nextKeyPos = First @ First @ StringPosition[str, "," ~~ (WhitespaceCharacter...) ~~ "\"" <> nextKey <> "\"" ~~ (WhitespaceCharacter...) ~~ "->"];
					replaceInMiddle[str, key -> value, {keypos, nextKeyPos}]
				]
				,
				Message[WriteTextResource::repeatNewEntry]; Return[str]
			]
		]
]


(* ::Subsubsection::Closed:: *)
(*toTextResourceString*)


toTextResourceString[CompressResourceValue[expr_]] := 
	"CompressedData[\n" <> ToString[Compress[expr], InputForm, PageWidth -> 80] <> "\n]"


(*
This stylesheet is intended to prevent dynamics from firing while processing
cells and boxes. It's not bulletproof, and may not always be desireable, but
for now, we use it unconditionally.
*)
$exportPacketStyleDefinitions = StyleDefinitions -> Notebook[
	{
		Cell[StyleData[StyleDefinitions -> "Default.nb"]],
		Cell[StyleData["Notebook"], DynamicUpdating -> False],
		Cell[StyleData["SystemDockedCell"], DynamicUpdating -> False]
	},
	StyleDefinitions -> "PrivateStylesheetFormatting.nb"
];


toTextResourceString[cell_Cell] := 
	Module[{nb, str, start},
		nb = FEPrivate`WithContext[$Context, Notebook[{cell}, $exportPacketStyleDefinitions]];
		str = First @ MathLink`CallFrontEnd[FrontEnd`ExportPacket[nb, "NotebookString"]];
		start = Replace[StringPosition[str, StartOfLine ~~ "Cell["], {
			{{start_, _}, ___} :> start,
			_ -> None
		}];
		str = StringDrop[str, start-1];
		StringTake[str, SyntaxLength[str]] // StringTrim
	];


toTextResourceString[cell_ExpressionCell] := 
	toTextResourceString[ToBoxes[Append[cell, StripOnInput -> True]]]


toTextResourceString[cells: {(_Cell | _ExpressionCell)..}] := StringJoin[
	"{\n",
	StringRiffle[toTextResourceString /@ cells, ",\n"],
	"\n}"
]


(* use the front end to beautify box expressions, keep packed arrays compressed, etc *)
toTextResourceString[RawBoxes[boxExpression: head_[args___]]] := 
	Module[{nb, str, start},
		nb = FEPrivate`WithContext[$Context, Notebook[{Cell @ BoxData @ boxExpression}, $exportPacketStyleDefinitions]];
		str = First @ MathLink`CallFrontEnd[FrontEnd`ExportPacket[nb, "NotebookString"]];
		start = Replace[StringPosition[str, ToString[head] <> "["], {
			{{start_, _}, ___} :> start,
			_ -> None
		}];
		str = StringDrop[str, start-1];
		StringTake[str, SyntaxLength[str]] // StringTrim
	]

(* automatically switch to FE formatting for known boxes *)
toTextResourceString[head_[args___]] := toTextResourceString[RawBoxes[head[args]]] /;
	MemberQ[{GraphicsBox}, head]


(* automatically switch to FE formatting for known expression heads *)
toTextResourceString[head_[args___]] := 
	Module[{nb, str, end},
		nb = FEPrivate`WithContext[$Context, Notebook[{}, TaggingRules :> head[args]]];
		str = First @ MathLink`CallFrontEnd[FrontEnd`ExportPacket[nb, "NotebookString"]];
		end = Replace[StringPosition[str, StartOfLine ~~ "TaggingRules:>"], {
			{{_, end_}, ___} :> end,
			_ -> None
		}];
		str = StringDrop[str, end];
		StringTake[str, SyntaxLength[str]] // StringTrim
	] /; MemberQ[{Function}, head]


(*
SyntaxLength doesn't trim ending comments, and 
"NotebookString" doesn't prevent the outline cache comments from being written.
So for notebooks, we do something a bit more hacky still.....
*)

toTextResourceString[nbExpr_Notebook] := 
	Module[{nb, str},
		nb = FEPrivate`WithContext[$Context, nbExpr];
		str = First @ MathLink`CallFrontEnd[FrontEnd`ExportPacket[nb, "NotebookString"]];
		Replace[
			StringSplit[str, {
				StartOfLine ~~ "(* Beginning of Notebook Content *)" ~~ EndOfLine,
				StartOfLine ~~ "(* End of Notebook Content *)" ~~ EndOfLine
			}],
			{
				{pre_, nbstr_, post_} :> nbstr,
				_ -> $Failed
			}
		] // StringTrim
	]


toTextResourceString[str_String] := str


toTextResourceString[other_] := (
	Message[WriteTextResource::fallthru, Head[other]];
	ToString[other, InputForm, PageWidth -> 80]
);


(* ::Section::Closed:: *)
(*Send/Stop Button*)


(* ::Subsection::Closed:: *)
(*ChatEvaluatingSpinner*)


(*
	#1 -> ImageSize,
	#2 -> base ring color,
	#3 -> moving color *)
FEResource["ChatEvaluatingSpinner"] := 
Function[
	DynamicBox[
		If[ TrueQ @ $CloudEvaluation,
			GraphicsBox[
				{ Thickness[ 0.05 ], #2, CircleBox[ { 0, 0 }, 1 ] },
				PlotRange -> 1.1,
				ImageSize -> #1
			],
			DynamicModuleBox[
				{ Typeset`i },
				OverlayBox[
					{
						PaneBox[
							AnimatorBox[
								Dynamic @ Typeset`i,
								{ 1, 30, 1 },
								AutoAction -> False,
								AnimationRate -> Automatic,
								DisplayAllSteps -> True,
								DefaultDuration -> 2,
								AppearanceElements -> None
							],
							ImageSize -> { 0, 0 }
						],
						GraphicsBox[
							{ Thickness[ 0.05 ], #2, CircleBox[ { 0, 0 }, 1, { 0.0, 6.2832 } ] },
							PlotRange -> 1.1,
							ImageSize -> #1
						],
						PaneSelectorBox[
							{
								1 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.5332, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								2 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.5151, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								3 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.4611, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								4 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.3713, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								5 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.2463, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								6 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.0869, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								7 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 3.894, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								8 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 3.6686, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								9 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 3.412, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								10 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 3.1258, 4.924 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								11 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 2.8116, 4.8802 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								12 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 2.4711, 4.8006 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								13 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 2.1064, 4.6856 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								14 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 1.7195, 4.5359 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								15 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 1.3127, 4.3525 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								16 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 0.88824, 4.1362 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								17 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 0.44865, 3.8884 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								18 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -0.0035846, 3.6105 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								19 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -0.46585, 3.3041 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								20 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -0.9355, 2.9709 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								21 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.4098, 2.6129 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								22 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 2.2322 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								23 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 1.8308 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								24 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 1.4112 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								25 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 0.97565 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								26 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 0.52676 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								27 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 0.067093 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								28 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, -0.40072 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								29 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, -0.87399 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								30 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, -1.35 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									]
							},
							Dynamic @ Typeset`i,
							ContentPadding -> False,
							FrameMargins -> 0,
							ImageSize -> All,
							Alignment -> Automatic,
							BaseStyle -> None,
							TransitionDirection -> Horizontal,
							TransitionDuration -> 0.5,
							TransitionEffect -> Automatic
						]
					},
					ContentPadding -> False,
					FrameMargins -> 0
				],
				DynamicModuleValues :> { }
			]
		],
		SingleEvaluation -> True
	]
]


(* ::Subsection::Closed:: *)
(*StopChatButtonLabel*)


(*
	#1 -> FrameStyle,
	#2 -> Background,
	#3 -> ImageSize of spinner *)
FEResource["StopChatButtonLabel"] := Function[ Evaluate @ ToBoxes @
	MouseAppearance[
		Mouseover[
			Framed[
				Overlay[
					{
						RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatEvaluatingSpinner" ][ #3, GrayLevel[ 0.9 ], GrayLevel[ 0.7 ] ] ],
						Graphics[
							{ RGBColor["#3383AC"], Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
							ImageSize -> #3,
							PlotRange -> 1.1
						]
					},
					Alignment -> { Center, Center }
				],
				FrameStyle -> GrayLevel[ 1 ],
				Background -> GrayLevel[ 1 ],
				RoundingRadius -> 3,
				FrameMargins -> 1
			],
			Framed[
				Overlay[
					{
						RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatEvaluatingSpinner" ][ #3, GrayLevel[ 0.9 ], GrayLevel[ 0.7 ] ] ],
						Graphics[
							{ RGBColor["#3383AC"], Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
							ImageSize -> #3,
							PlotRange -> 1.1
						]
					},
					Alignment -> { Center, Center }
				],
				FrameStyle -> #1,
				Background -> #2,
				RoundingRadius -> 3,
				FrameMargins -> 1
			]
		],
		"LinkHand"
	]
]


(* ::Subsection::Closed:: *)
(*SendChatButtonLabel*)


(*
	#1 -> FaceForm,
	#2 -> Background,
	#3 -> ImageSize *)
FEResource["SendChatButtonLabel"] := Function[ Evaluate @ ToBoxes @
	MouseAppearance[
		Mouseover[
			Framed[
				Graphics[
					{
						Thickness[ 0.055556 ],
						FaceForm[ #1 ],
						FilledCurve[
							{
								{
									{ 0, 2, 0 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 }
								}
							},
							{
								{
									{ 16.027, 14.999 },
									{ 1.9266, 14.502 },
									{ 1.0396, 14.472 },
									{ 0.6156, 13.398 },
									{ 1.2516, 12.793 },
									{ 4.3856, 9.8123 },
									{ 4.6816, 9.5303 },
									{ 5.1256, 9.4603 },
									{ 5.5026, 9.6363 },
									{ 9.1226, 11.324 },
									{ 9.3736, 11.441 },
									{ 9.6716, 11.336 },
									{ 9.7866, 11.088 },
									{ 9.9026, 10.84 },
									{ 9.7916, 10.545 },
									{ 9.5406, 10.428 },
									{ 5.9206, 8.7393 },
									{ 5.5436, 8.5643 },
									{ 5.3116, 8.1793 },
									{ 5.3376, 7.7713 },
									{ 5.6066, 3.4543 },
									{ 5.6606, 2.5783 },
									{ 6.7556, 2.2123 },
									{ 7.3496, 2.8723 },
									{ 16.794, 13.354 },
									{ 17.382, 14.007 },
									{ 16.905, 15.03 },
									{ 16.027, 14.999 }
								}
							}
						]
					},
					AspectRatio -> Automatic,
					ImageSize -> #3,
					PlotRange -> { { -0.5, 18.5 }, { -0.5, 18.5 } }
				],
				FrameStyle -> GrayLevel[ 1 ],
				Background -> GrayLevel[ 1 ],
				RoundingRadius -> 3,
				FrameMargins -> 1
			],
			Framed[
				Graphics[
					{
						Thickness[ 0.055556 ],
						FaceForm[ #1 ],
						FilledCurve[
							{
								{
									{ 0, 2, 0 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 },
									{ 0, 1, 0 },
									{ 1, 3, 3 }
								}
							},
							{
								{
									{ 16.027, 14.999 },
									{ 1.9266, 14.502 },
									{ 1.0396, 14.472 },
									{ 0.6156, 13.398 },
									{ 1.2516, 12.793 },
									{ 4.3856, 9.8123 },
									{ 4.6816, 9.5303 },
									{ 5.1256, 9.4603 },
									{ 5.5026, 9.6363 },
									{ 9.1226, 11.324 },
									{ 9.3736, 11.441 },
									{ 9.6716, 11.336 },
									{ 9.7866, 11.088 },
									{ 9.9026, 10.84 },
									{ 9.7916, 10.545 },
									{ 9.5406, 10.428 },
									{ 5.9206, 8.7393 },
									{ 5.5436, 8.5643 },
									{ 5.3116, 8.1793 },
									{ 5.3376, 7.7713 },
									{ 5.6066, 3.4543 },
									{ 5.6606, 2.5783 },
									{ 6.7556, 2.2123 },
									{ 7.3496, 2.8723 },
									{ 16.794, 13.354 },
									{ 17.382, 14.007 },
									{ 16.905, 15.03 },
									{ 16.027, 14.999 }
								}
							}
						]
					},
					AspectRatio -> Automatic,
					ImageSize -> #3,
					PlotRange -> { { -0.5, 18.5 }, { -0.5, 18.5 } }
				],
				FrameStyle -> #1,
				Background -> #2,
				RoundingRadius -> 3,
				FrameMargins -> 1
			]
		],
		"LinkHand"
	]
]


(* ::Subsection::Closed:: *)
(*SendChatButton*)


(*
	#1 -> FaceForm / FrameStyle,
	#2 -> Background,
	#3 -> ImageSize *)
FEResource["SendChatButton"] := Function[ Evaluate @ ToBoxes @
	DynamicModule[ { Typeset`cell },
		PaneSelector[
			{
				False ->
					Button[
						Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButtonLabel" ][ #1, #2, #3 ] ],
						Wolfram`Chatbook`$ChatEvaluationCell = Typeset`cell;
						SelectionMove[ Typeset`cell, All, Cell ];
						FrontEndTokenExecute[ Notebooks @ Typeset`cell, "EvaluateCells" ],
						Appearance -> "Suppressed",
						FrameMargins -> 0,
						Method -> "Queued"
					],
				True ->
					Button[
						Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "StopChatButtonLabel" ][ #1, #2, #3 ] ],
						If[ Wolfram`Chatbook`$ChatEvaluationCell =!= Typeset`cell,
							NotebookWrite[ Typeset`cell, NotebookRead @ Typeset`cell, None, AutoScroll -> False ],
							Needs[ "Wolfram`Chatbook`" -> None ];
							Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ]
						],
						Appearance -> "Suppressed",
						FrameMargins -> 0
					]
			},
			Dynamic[ Wolfram`Chatbook`$ChatEvaluationCell === Typeset`cell ],
			Alignment -> { Automatic, Baseline },
			ImageSize -> Automatic
		], (* TODO: what is this x?? *)
		Initialization :> (Typeset`cell = If[ $CloudEvaluation, x; EvaluationCell[ ], ParentCell @ EvaluationCell[ ] ]),
		DynamicModuleValues :> { },
		UnsavedVariables :> { Typeset`cell }
	]
]


(* ::Section::Closed:: *)
(*Package Footer*)


End[];
EndPackage[];
