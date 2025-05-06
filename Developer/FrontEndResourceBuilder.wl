(* ::Package:: *)

(* ::Title:: *)
(*Manage FE expression resources*)


(* ::Section::Closed:: *)
(*Package Header*)


BeginPackage["Wolfram`ChatbookFrontEndResourceBuilder`"]


ClearAll[ "`*" ];
ClearAll[ "`Private`*" ];


color;
WriteTextResource;
$ChatbookResources;
FEResource;


Begin["`Private`"]


(* ::Section::Closed:: *)
(*Paths*)


$inputFileName        = Replace[ $InputFileName, "" :> NotebookFileName[ ] ];
$pacletDirectory      = DirectoryName[ $inputFileName, 2 ];
$sourceDirectory      = FileNameJoin @ { $pacletDirectory, "Developer", "Resources", "FrontEndResources" };
$sourceDirectory2     = FileNameJoin @ { $pacletDirectory, "Developer", "Resources", "Icons" };
$resourceLocation     = FileNameJoin @ { $pacletDirectory, "FrontEnd", "TextResources", "ChatbookResources.tr" };
$resourceLocationDark = FileNameJoin @ { $pacletDirectory, "DarkModeSupport", "TextResources", "ChatbookResources.tr" };


(* ::Subsection::Closed:: *)
(*Load Paclet*)


PacletDirectoryLoad @ $pacletDirectory;
Get[ "Wolfram`Chatbook`" ];
Get[ FileNameJoin[ { $pacletDirectory, "Source", "Chatbook", "ColorData.wl" } ] ];
color = Wolfram`Chatbook`Common`color


(* ::Section::Closed:: *)
(*Load Resources*)


$resourceFiles = FileNames[ "*.wl", { $sourceDirectory, $sourceDirectory2 }, Infinity ];
$resourceNames = FileBaseName /@ $resourceFiles;
$ChatbookResources = AssociationThread[ $resourceNames, Import /@ $resourceFiles ];


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


WriteTextResource[ All ] :=
    Module[ { written },
        written = AssociationMap[
			Function[
				Quiet[
					Check[
						WriteTextResource[ # ],
						WriteTextResource[ #, "NewEntry" -> True ],
						WriteTextResource::badkey
					],
					WriteTextResource::badkey
				]
			],
			$resourceNames
		];
		If[ AllTrue[ written, SameAs[ $resourceLocation ] ],
			Success[ "Updated", <| "File" -> $resourceLocation, "Names" -> $resourceNames |> ],
			Failure[ "SomethingHappened", <| "File" -> $resourceLocation, "Results" -> written |> ]
		]
    ];


WriteTextResource[ All, "Dark" ] :=
	Block[ { $resourceLocation = $resourceLocationDark },
		WriteTextResource[ All ]
	] /; BoxForm`sufficientVersionQ[14.3]

WriteTextResource[ All, "Dark" ] := WriteTextResource[ All ]


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


toTextResourceString[g_Graphics] := toTextResourceString[ToBoxes[g]]


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
(*FEResource*)


FEResource[ name_String ] := Lookup[ $ChatbookResources, name ];


(* ::Section::Closed:: *)
(*Package Footer*)


End[];
EndPackage[];
