(* ::Package:: *)

(* ::Title:: *)
(*Chat code check & fix*)


(* ::Chapter:: *)
(*Init*)


(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::DifferentLine:: *)

BeginPackage["Wolfram`Chatbook`CodeCheck`"]; (**)

Needs["CodeInspector`"]
Needs["CodeParser`"]

`CodeCheckFix
`$UserDefinedFunctionsQ=<||>
`$MaxIterateTimeBracketsFix=1. (*seconds*)
`$MaxIterationsBracketsFix=10	(*iterations*)

codeCheckIgnoreMessage=(CodeInspector`Utils`conventionAgnosticSourceOrdering::unhandled)

Begin[ "`Private`" ];


(* ::Chapter:: *)
(*Main functions*)


(* ::Section::Closed:: *)
(*CodeCheckFix*)


$FixRecursionLimit=10;

(*Possible targets*)
$AssistantPattern="Assistant";
$EvaluatorPattern="Evaluator";

Options[CodeCheckFix] = {"Target"->$AssistantPattern}

CodeCheckFix[code_String, OptionsPattern[]]:= (
	Needs[ "CodeInspector`" -> None ];
	Needs[ "CodeParser`" -> None ];
	Block[ {niter=0, recursionLimit=$FixRecursionLimit, $target=OptionValue["Target"]}
			,
			With[	{
						aCodeCheckInitial	=	CodeCheck[$target][code]
					}
					,
					{	errorsDetectedQ		=	(aCodeCheckInitial["InspectionObjects"] =!= {}),
					 	aCodeFix			=	CodeFix[$target][code,aCodeCheckInitial]
					}
					,
					{	aCodeCheckFinal		=	CodeCheck[$target][aCodeFix["FixedCode"]],
						success				=	Lookup[aCodeFix, "Success", None]
					}
					,
					(* --------------  Output in order--------------------------------*)
					{
					"ErrorsDetected"		-> errorsDetectedQ,									(* always available *)
					"Success"				-> success,
					"Failure"				-> Lookup[aCodeFix, "Failure", None], 				(* only added when Success -> False*)
					"SafeToEvaluate"		-> If[errorsDetectedQ && Not@TrueQ@success && Not@Lookup[aCodeFix, "StopCodeFix", False]
													, Missing["Failure"]
													, Lookup[aCodeFix, "SafeToEvaluate", None]],
					"RecursionLimitExceeded"-> Lookup[aCodeFix, "RecursionLimitExceeded", None],(* only added when Recursion detected*)
					"TotalFixes"			-> Lookup[aCodeFix, "TotalFixes", None],
					"LikelyFalsePositive"	-> Lookup[aCodeFix, "LikelyFalsePositive", None],
					"PatternLogs"			-> Lookup[aCodeFix, "PatternLogs", None],
					"CodeInspector"			-> If[errorsDetectedQ
													,	Association @@
																Replace[
																		{
																		"InitialState"	-> aCodeCheckInitial,
																		"FinalState"	-> Replace[	aCodeCheckFinal
																									, _Missing->aCodeCheckInitial]
																		}
																		,
																		{a_->same_ ,b_->same_} :> {a -> Inherited, b -> same}
																]
													,	None
												],
					"OriginalCode"			-> code,											(* always available *)
					"FixedCode"				-> Lookup[aCodeFix, "FixedCode", Missing["No errors detected"]]
					}
			]
			// Apply[Association]
			// DeleteCases[None]
			// If[Not@TrueQ[Wolfram`Chatbook`CodeCheck`$CodeCheckDebug], KeyDrop[#, "PatternLogs"], #]&
	]
)



(* ::Section::Closed:: *)
(*CodeCheck*)


Options[CodeCheck]={"SeverityExclusions" ->{(*(*4/4*)"Fatal", (*3/4*)"Error"*)
												 (*2/4*)"Warning"
												,(*1/4*)"Remark"
												,(*0/4*)"ImplicitTimes","Formatting" ,"Scoping"
												}
					,
					"TagExclusions" -> {"SetInfixInequality" 		(* cases like: a = b==c *)
										,"ImplicitTimesPseudoCall"	(* cases like: a (b+c)*)
										,"ImplicitTimesBlanks"
										,"TimesString"				(* ex: "Meters"*"Second" in Quantity*)
										,"TopLevelDefinitionCompoundExpression" (* ex: f[x_]:x= ; 2*)
										}
					,
					SourceConvention -> "SourceCharacterIndex"
					,
					(*---------------------- Custom checks --------------------------*)
					"AbstractRules" ->	<|
										CodeInspector`AbstractRules`$DefaultAbstractRules,
										pSingleSnake -> scanSingleSnake (* detect bad single snake usage inside Set *),
										pQuantityUnitName -> scanQuantityUnitName,
										pSuspiciousFunctionSymbol -> scanSuspiciousSymbol
										|>
					,
					"SequenceTokenRules" ->	{pSnakeAll->scanSnakeMulti}
					,
					"StringScans"-> {scanTrailingStarCommentCloser}
					};


CodeCheck[target_][code_String, OptionsPattern[]]:=
	Quiet[

		Flatten@List[
			CodeInspectTokenSequence[code,Sequence@@Options[CodeCheck]]
			,
			CodeInspect[code, Sequence@@FilterRules[Options[CodeCheck],Options[CodeInspect]]]
			,
			stringScans[code, OptionValue[Options[CodeCheck],"StringScans"]]
		]
		//
		Association@@{"InspectionObjects"->#,"OverallSeverity"->codeInspectOverallSeverityLevel[#]}&
	,
		Evaluate@codeCheckIgnoreMessage
	]

CodeCheck[target_][x_, OptionsPattern[]]:=x

(* --- *)

CodeInspectTokenSequence[code_String, OptionsPattern[{}]]:=
	With[
		{ct=CodeTokenize[code, SourceConvention->OptionValue[SourceConvention]]}
		,
		OptionValue["SequenceTokenRules"]
		//
		ReplaceAll[	HoldPattern[Rule[pattern_,scan_]]	:>
					Replace[	MySequencePosition[ct, pattern]
								,
								p:{__} :> scan[ct,p]
					]
		]
	]

MySequencePosition[codeTokenized_List, pattern_]:=
(
		Position[codeTokenized, Alternatives@@Union@Cases[pattern, _LeafNode, {1, Infinity}]]
	//	Flatten // Split[#, #1 + 1 == #2 &] &
	//	Replace[#, {{_} -> Nothing, x_List :> x[[{1, -1}]]}, {1}] &
	//	Map[ Function[pos, SequencePosition[codeTokenized[[Span @@ pos]], pattern, Overlaps -> False] + First@pos - 1] ]
	//	Flatten[#, 1] &
)

stringScans[code_String, scans:{__}]:= Map[#[code]&, scans]


(* ::Subsection:: *)
(*Helpers*)


codeInspectOverallSeverityLevel[ios:{__InspectionObject}]:=
	ios[[All,3]] // StringReplace[#, StringTrim[#, Alternatives @@ ruleCodeInspectSeverityToLevel[[All, 1]]] -> ""]&//
	ReplaceAll[ruleCodeInspectSeverityToLevel]//Max

codeInspectOverallSeverityLevel[{}]:=None

ruleCodeInspectSeverityToLevel={"Fatal"->4,"Error"->3,"Warning"->2,"Remark"->1,"ImplicitTimes"|"Formatting"|"Scoping"->0};

(*codeInspectOverallSeverityLevel[ios:{__InspectionObject}]:=ios[[All,3]]//ReplaceAll[ruleCodeInspectSeverityToLevel]//Max//Replace[ruleCodeInspectSeverityLevelToOverallSeverity]*)
(*ruleCodeInspectSeverityLevelToOverallSeverity={4->"4/4", 3->"3/4",2->"2/4",1->"1/4",0->"0/4"};*)



(* ::Text:: *)
(*from CodeInspector/ Kernel/ Utils.wl:*)
(*severityToInteger["ImplicitTimes" | "Formatting" | "Scoping"] = 0*)
(*severityToInteger["Remark"] = 1*)
(*severityToInteger["Warning"] = 2*)
(*severityToInteger["Error"] = 3*)
(*severityToInteger["Fatal"] = 4*)
(**)


(* ::Section::Closed:: *)
(*CodeFix*)


(* CodeFix[code_String]:=CodeFix[code, CodeCheck[code]] *)

CodeFix[target_][
		code_String
		,kvCI:KeyValuePattern[{"InspectionObjects"->{__}}]
		,params_:<||>
		]:=
		CodeFix[target][<||>, fixPattern[target][code, generatePatternFromCodeCheck[kvCI]]]

CodeFix[target_][
		code_String
		,kvCI:KeyValuePattern["InspectionObjects"->{}]
		,params_:<||>
		]:= <||>


CodeFix[target_][kvFixPrev_, kvFixNew:KeyValuePattern[{"Success"->True|False}]]:=
	With[{merged=mergeFixes[kvFixPrev, kvFixNew]},
		If[	MatchQ[	kvFixNew	,Alternatives[	 KeyValuePattern[{"Success"->False}]
												,KeyValuePattern[{"Success"->True, "LikelyFalsePositive"->True}]
												,KeyValuePattern[{"Success"->True, "FixedCode"->_Missing}]
												,KeyValuePattern[{"StopCodeFix"->True}]]
			]
			,
			merged
			,
			generatePatternFromCodeCheck@CodeCheck[target][merged["FixedCode"]]
			//	If[	 And[niter > recursionLimit, Subtract @@ (Length/@merged["PatternLogs"][[{-1, -2}]]) >= 0]
					,
					Association@@{merged, "Success"->False, "RecursionLimitExceeded"->True}
					,
					If[#==={}, merged, (niter++; CodeFix[target][merged, fixPattern[target][merged["FixedCode"],#]])]
				]&
		]
	]


generatePatternFromCodeCheck[KeyValuePattern[{"InspectionObjects"->{}}]]:={}

generatePatternFromCodeCheck[kv:KeyValuePattern[{"InspectionObjects"->ios_}]]:= ios // Map[extractPatternFromInspectionObject] // Sort //groupPattern

extractPatternFromInspectionObject[
	io:InspectionObject[
				Alternatives[	"BadSingleSnakeUsage"
							,	"BadMultiSnakeUsage"
							,	"SuspiciousQuantityUnitName"
							,	"EntityClassBadSyntax"
							,	"BadEntityType"
							,	"SuspiciousFunctionSymbol"
							,	"GlobalCapitalizedSymbol"
							,	"TrailingStarCallFalseCommentCloser"]
				,__]]:=	Apply[Sequence,io]//({#3,#1}->#4[Source])&

extractPatternFromInspectionObject[io_]:=Apply[Sequence,io]//{#3,#1}&

patternsToGroup={_,"BadSingleSnakeUsage"};
groupPattern[patterns_]:=
	patterns // ReplaceRepeated[{a___, gg : Longest[(x : patternsToGroup -> _) ..], b___} :> {a, Hold[gg], b}] //
 	ReplaceAll[Hold->List] //
	ReplaceAll[h : List[(pg : patternsToGroup -> {{_, _} ..}) ..] :> (pg -> Sort@*Join @@ h[[All, 2]])]


lengthErrors[code_]:=CodeCheck[$target][code]//generatePatternFromCodeCheck//Length
lengthErrors[f_Failure]:=f


initFix=<|"Success"-> True, "TotalFixes"-> 0, "LikelyFalsePositive"->False, "SafeToEvaluate"->True, "PatternLogs"->{}, "FixedCode"->Missing["No fixed code"]|>;

mergeFixes[<||>, newFix:KeyValuePattern["PatternLogs"->_]]:=newFix
mergeFixes[<||>, newFix_]:=	mergeFixes[initFix, newFix] // If[TrueQ@Wolfram`Chatbook`CodeCheck`$CodeCheckDebug, Association@@{newFix,#},#]&

mergeFixes[prevFix_, newFix_] :=
 	{
		"Success"				-> And[newFix[#], prevFix[#]]& @ "Success",
		"TotalFixes"			-> Plus[prevFix[#], newFix[#]]& @"TotalFixes",
		"LikelyFalsePositive" 	-> Or[prevFix[#], newFix[#]]& @"LikelyFalsePositive",
		"SafeToEvaluate"		-> And[prevFix[#], newFix[#]]& @"SafeToEvaluate",
		"FixedCode" 			-> (newFix["FixedCode"] // If[MissingQ@# && StringQ@prevFix["FixedCode"]
																		, prevFix["FixedCode"]
																		, #]&),
		"PatternLogs" 			-> Append[	prevFix["PatternLogs"], Lookup[newFix,"Pattern",Lookup[newFix, "PatternLogs",Missing["Pattern"]]]],
		"Failure"				-> If[newFix["Success"]===True, None, newFix["FixedCode"]],
		"StopCodeFix"			-> Lookup[newFix,"StopCodeFix",False]
	} // Flatten // Association


(* ::Chapter:: *)
(*Fix functions*)


(* ::Section:: *)
(*Brackets Fix*)

(* FIX PATTERN ----------------------------------------------------------------------- *)
$$TrailingStarCallFalseCommentCloser = HoldPattern[{___, {"Fatal", "TrailingStarCallFalseCommentCloser"}->#, ___}]&;

fixPattern[target_][code_String, pat : $$TrailingStarCallFalseCommentCloser[so_], patToIgnore_ : {}] :=
	Module[	{
			fixedCode=Missing["TrailingStarCallFalseCommentCloser","No fix found"]
			,success=False
			}
			,
			StringInsert[code, " ", Last /@ so]
			//
			If[	And[StringQ@#, balancedCommentQ@#]
				,
				success=True;fixedCode=#
			]&
			;
			{ "Success" -> success
			, "TotalFixes" -> If[success, Length@so, 0]
			, "LikelyFalsePositive" -> If[success, False, True]
			, "SafeToEvaluate" -> If[success, True, False]
			, "Pattern" -> pat
			, "FixedCode" -> fixedCode
			, "StopCodeFix" -> True
			} // Flatten // Association
	]

balancedCommentQ[code_String]:=
	listCommentCloser[code][[All,2]] // ReplaceRepeated[{a___, "(*", "*)", b___} :> {a, b}] // Replace[{}->True] // TrueQ

scanTrailingStarCommentCloser[code_String]:=
	Catch[
	With[
		{	(* Stops evaluation if no comments  *)
			posCommentCloserAndtype = listCommentCloser[code] /. _Missing :> Throw[{}]}
		,
		{
			posTrailingStarCall =
				(	(* Stops evaluation if all comments closer are balanced *)
					ReplaceRepeated[	posCommentCloserAndtype[[All,2]]
										,{a___, "(*", "*)", b___} :> {a, b}] /. {}:>Throw[{}]
					;
					(* Stops evaluation if no trailing star call found *)
					StringPosition[code, pTrailingStarCall] /. {} :> Throw[{}]
				)
		}
		,
		Select[posTrailingStarCall, MatchQ[posCommentCloserAndtype , {___, {{_, #[[2]]}, "*)"}, {{_, _}, "*)"}, ___}] &]
		//
		Replace[	{
					p:{___} :>	CodeInspector`InspectionObject[		"TrailingStarCallFalseCommentCloser"
																,	"Trailing star call inside comment "
																,	"Fatal"
																,	Association@{ConfidenceLevel -> 1, Source->p}]
					,
					_ -> {}
					}
		]
	]]

pNonParen = Repeated[Except["(" | ")"], {0, Infinity}];
pTrailingStarCall = "(" ~~ Except["*"] ~~ Shortest[pNonParen] ~~ Verbatim["*"] ~~ ")";

listCommentCloser[code_String]:=
Catch[
	With[
		{
			posStrings =	StringPosition[code, "\""]
						//	If[EvenQ@Length@# ,Partition[#,2], Throw[Missing["Unbalanced strings"]]]& // Map[#[[All,1]]&]
		}
		,
		{
			posCommentCloser =	Select[	StringPosition[code, "(*" | "*)", Overlaps->False],
										Not[Or @@ IntervalMemberQ[Interval /@ posStrings, Interval@#]] &]
		}
		,
		{#, StringTake[code, #]} & /@ posCommentCloser

	]
]

(* FIX PATTERN ----------------------------------------------------------------------- *)
$$UnbalancedCommentsOrString = HoldPattern[{___, {"Fatal", "UnexpectedCommentCloser"}|{"Fatal", "UnterminatedString"}, ___}];

fixPattern[target_][code_String, pat : $$UnbalancedCommentsOrString, patToIgnore_ : {}] :=
	Module[	{
			fixedCode=Missing["UnbalancedCommentsOrString"]
			,success=False
			}
			,
			{ "Success" -> success
			, "TotalFixes" -> 0
			, "LikelyFalsePositive" -> False
			, "SafeToEvaluate" -> False
			, "Pattern" -> pat
			, "FixedCode" -> fixedCode
			, "StopCodeFix" -> True
			} // Flatten // Association
	]


(* FIX PATTERN ----------------------------------------------------------------------- *)
$$FatalGroupMissingCloserORANDFatalUnexpectedCloser = {___, {"Fatal","GroupMissingCloser"}|{"Fatal", "UnexpectedCloser"}, ___};

fixPattern[target_][code_String, pat : $$FatalGroupMissingCloserORANDFatalUnexpectedCloser, patToIgnore_ : {}] := fixBrackets[target][code, pat]

fixBrackets[target_][code_String, pat : $$FatalGroupMissingCloserORANDFatalUnexpectedCloser, patToIgnore_ : {}]:=
(
	With[
		{fix = iterateBracketFixes[code, pat]}
		,
		{success = MatchQ[fix, KeyValuePattern[{"Code"->_String, "Status"->"Fixed"}]]}
		,
		{ "Success" -> success
		, "TotalFixes" -> If[success, Length@Keys@Lookup[fix, "Fixes", <||>], Missing["No fix found"]]
		, "LikelyFalsePositive" -> False
		, "SafeToEvaluate" -> If[success, True, False]
		, "Pattern" -> pat
		, "FixedCode" -> If[success, fix["Code"], If[MissingQ@fix, fix, Missing["Bracket fix"]]]
		} // Association


	]
)

iterateBracketFixes[code_, pattern_, extraiter_ : 1] :=
 Catch[
	TimeConstrained[
		Block[	{$fixed = <||>}
		,
		Module[{iter = 0, success, res, resFixed, resSyntax}
			,
			res =	NestWhile[	(
								decho[iter = iter + 1, "iter====================================="];
								ReplaceAll[#, asc : KeyValuePattern[{"Code" -> _String, "Status" -> "ToFix"|"Failed"}] :> generateBracketFixes[asc]]
								)&
								,
								(* initial expression-association to fix*)
								<|"Code" -> code, "Pattern"-> pattern, "Status" -> "ToFix", "Fixes" -> <||>, "RemainingErrors"-> <||>|>
								,
								(* Condition to stop iteration: by default as soon as 1 fix is found *)
								(Not[(success = (Length@Keys@$fixed === extraiter))] &)
								, 0
								, $MaxIterationsBracketsFix
					];

			decho[iter, "number of iterations"]
			;
			resFixed=	( 	Flatten[res] // dechofunction["final: raw number", Length] //
							Select[#Status === "Fixed" &]
							// dechofunction["final: fixed", Length]
							// dechofunction["see fixed cases in: Wolfram`Chatbook`CodeCheck`Private`$resFixed",($resFixed=#;"")&]
						)
			;
			resSyntax= resFixed // Select[SyntaxQ @ #Code &] // dechofunction["final: SyntaxQ", Length]
			;
			If[success && (Length@resSyntax>0), selectFixWithHighestScore[resSyntax], Missing["Bracket Fix", "No SyntaxQ"]]
		]
		]
		, $MaxIterateTimeBracketsFix , Throw[Missing["Time limit exceeded"]] (*TimeConstrained*)
	]
 ]


selectFixWithHighestScore[listAsc_, multiple_:False] :=
(		listAsc
	//	ReverseSortBy[#DefaultScore &] // DeleteDuplicatesBy[#Code &]
	//	dechofunction["final: without duplicates", Length]
	//	With[{maxscore = Max[#[[All, "Score"]]]}, Select[#, #Score == maxscore &]] &
	//	dechofunction["Final number with max score:", Length]
	//	With[{maxsdefscore = Max[#[[All, "DefaultScore"]]]}, Select[#, #DefaultScore == maxsdefscore &]] &
	//	dechofunction["Final number with max score + highest default score :", Length]
	//	Replace[	{{asc_}:>asc, m:{__}:>If[multiple, m, Missing["Bracket fix","Multiple fixes found"]]
				,	{}->Missing["Bracket fix", "No Highest score"]}]
)

generateBracketFixes[ascode : KeyValuePattern[{"Status" -> "Failed"}]]:=Nothing

generateBracketFixes[ascode : KeyValuePattern[{"Status" -> "ToFix", "Code" -> code_String, "Pattern"->pattern_}]]:=
(	decho[Keys@ascode["Fixes"],"Fix ID: "];
	generateBracketFixes[ascode, fixPatternBrackets[""][code,pattern]]
)

generateBracketFixes[ascode : KeyValuePattern[{"Status" -> "ToFix"}], _Missing] := Association@@{ascode, "Status" -> "Failed"}

generateBracketFixes[ascode : KeyValuePattern[{"Status" -> "ToFix"}], fixes_] :=
	Module[{asc}
		,
		With[
			{nfixes = Length@fixes}
			,
			Table[
				With[
					{fixed = fixes[[ifix]](*//EchoLabel["fixed"]*)}
					,
					asc = ascode
					;
					asc["DefaultScore"] = Lookup[asc, "DefaultScore", 0] + Lookup[fixed, "DefaultScore", 0]
					;
					asc["Iteration"] = Lookup[asc, "Iteration", 0] + 1
					;
					asc["Fixes", {asc["Iteration"], {ifix, nfixes}}] = KeyTake[fixed, {"DefaultScore", "Pattern", "Type"}]
					;
					asc["Pattern"] = generatePatternFromCodeCheck@CodeCheck[$EvaluatorPattern]@fixed["Code"]
					;
					asc["RemainingErrors", asc["Iteration"]] = Count[asc["Pattern"], {_, "GroupMissingCloser" | "UnexpectedCloser"}]
					;
					(**)
					asc["Status"] = Replace[	asc["RemainingErrors", asc["Iteration"]]
													,
													{	0	-> 	"Fixed",

														x_	:> 	If[	TrueQ[	(x - asc["RemainingErrors", asc["Iteration"]-1]) >= 0 ]
																	,
																	"Failed"
																	,
																	"ToFix"
																]
													}
									]
					;
					If[	asc["Status"] === "Fixed"
						,	$fixed[asc["Iteration"]] = (True // decholabel["fixed:"])
							;
							asc["Score"] = scoreCode@fixed["Code"]
					]
					;
					asc["Code"] = fixed["Code"]
					;
					asc
				]
			, {ifix, nfixes}
			]
		]
	]

countMCUCerrors[patterns_]:=Count[patterns["InspectionObjects"], CodeInspector`InspectionObject["GroupMissingCloser" | "UnexpectedCloser", _, __]]

(* ::Subsection::Closed:: *)
(*Patterns*)


$$AllBracketsPatterns= Alternatives[$$FatalGroupMissingCloserFatalUnexpectedCloser, $$FatalUnexpectedCloser, $$FatalGroupMissingCloser]

(* ::Subsection:: *)
(*MCUC*)


$$FatalGroupMissingCloserFatalUnexpectedCloser = {___, {"Fatal","GroupMissingCloser"}, ___, {"Fatal", "UnexpectedCloser"}, ___};

fixPatternBrackets[target_][code_String, pat : $$FatalGroupMissingCloserFatalUnexpectedCloser, patToIgnore_ : {}] :=
 	Module[	{
   			  ccp = CodeConcreteParse[code, SourceConvention -> "SourceCharacterIndex"]
   			, allGMCpos
   			, posGMC
   			, gmc
   			, posUC
   			, newClosingBracket
   			, wrongClosingBrackets
   			, codeTokenized
   			, wrongLeafNode
   			, extraLeafNodePat
   			, extraBracketType
   			, extraLeafNodes
   			, fix1, fix2, fix3
   			, codeFixed = Missing[]
   			, success = False
   			}
  			,
  			decho["********** MCUC **********"];

  			allGMCpos = Position[ccp, _GroupMissingCloserNode];

  			(* looping on all GMC positions *)
  			Catch@
			Do[
    			posGMC = allGMCpos[[iGMCpos]];
    			gmc = Extract[ccp, posGMC];
    			newClosingBracket =	gmc[[1]] /.  {GroupSquare -> "]", GroupParen -> ")", List -> "}", Association -> "|>"};
    			wrongClosingBrackets = Alternatives["]", ")", "}", "|>"] // DeleteCases[newClosingBracket];
    			posUC = Position[gmc, Token`Error`UnexpectedCloser];

    			codeFixed =
					If[	posUC === {}
       					,
       						(* UC outside GMC *)
       						decho["UC outside GMC"];
       							(* 1st solution: replace the bad closing bracket type with the expected type *)
								codeTokenized = CodeTokenize[code, SourceConvention -> "SourceCharacterIndex"];
								wrongLeafNode = SelectFirst[codeTokenized, 	And[ #[[-1, 1, 2]] > gmc[[-1, 1, 2]]
																				,MatchQ[#[[2]], wrongClosingBrackets]] &]//
												(*EchoLabel["wrongleaf"]//*)Replace[x_Missing->Missing["",LeafNode["Missing"]]];
								fix1=(ccp//ReplaceAll[wrongLeafNode->(wrongLeafNode/. {wrongLeafNode[[2]]->newClosingBracket})]
										//ToSourceCharacterString//Replace[_Failure :> Failure["ToSourceCharacterString","MCUC"]]
										//<|"Code"->#, "DefaultScore"->1,"Pattern"->"MCUC", "Type"->"R1"|>&//List)(*//EchoLabel["fix1"]*)

								; (* 2nd solution: delete the bad type bracket or previous ones *)
								extraLeafNodePat=wrongLeafNode//ReplaceAll[<|__|>->_];
								extraBracketType=wrongLeafNode[[2]] /.{"]"->GroupSquare,")"->GroupParen,"}"->List,"|>"->Association};
								extraLeafNodes=gmc//ReplaceAll[GroupNode[Except[extraBracketType,_],__]:>Nothing]
									//Cases[#,GroupNode[extraBracketType,lfn__,so_]:>(Cases[lfn,extraLeafNodePat]//Last),Infinity]&(*//EchoLabel["cases:"]*)//
									If[Length@#>=1,{Last@#},{}]&; (*only accept the last node*)
								fix2=Map[(ReplaceAll[ccp, # -> Nothing]
										//ToSourceCharacterString//Replace[_Failure :> Failure["ToSourceCharacterString","MCUC"]]
										)&
									,Join[extraLeafNodes,{wrongLeafNode}]
								] // Map[<|"Code"->#,"Pattern"->"MCUC", "Type"->"D","DefaultScore"->0|>&]//MapAt[0.5&,{-1,"DefaultScore"}]//DeleteDuplicates (*//EchoLabel["fix2"]*)
								(*fix2=ReplaceAll[ccp,extraLeafNodes->Nothing]//ToSourceCharacterString//List//EchoLabel["fix2"]*)

								; (* 3rd solution: add missing closer *)
								fix3=fixPatternBrackets[$EvaluatorPattern][code,$$FatalGroupMissingCloser]//MapAt[StringJoin["MCUC/",#]&, {All,"Pattern"}](*//EchoLabel["fix3"]*)
								;
								Join[fix1,fix2,fix3] // Replace[{_Failure..} :> Failure["ToSourceCharacterString","MCUC"]]
       					,
       						(* UC inside GMC *)
       						decho["UC inside GMC"];
								fix1=
								(
								ccp
								//
								If[gmc[[1]] === Association
									,
									deleteTokenBarBeforeClosingBracket[#, Extract[gmc, Most@posUC[[1]]]]
									,
									#
								]&
								// ReplaceAll[Extract[gmc, Most@posUC[[1]]] -> ErrorNode[Token`Error`UnexpectedCloser, newClosingBracket, _]]
       							// ToSourceCharacterString // Replace[Failure[x_,___]:>Failure["ToSourceCharacterString","MCUC"]]
       							)//<|"Code"->#,"DefaultScore"->1,"Type"->"R2", "Pattern"->"MCUC"|>&//List;

								fix3=fixPatternBrackets[$EvaluatorPattern][code,$$FatalGroupMissingCloser]//MapAt[StringJoin["MCUC/",#]&, {All,"Pattern"}]
       							;
       							Join[fix1,fix3] // Replace[{_Failure..} :> Failure["ToSourceCharacterString","MCUC"]]
       				]
					;
    				success = Not@FailureQ@codeFixed
					;
					If[success, Throw[Null]]
					;
    			,
				{iGMCpos, Length@allGMCpos}
			]
			;
   			codeFixed // Replace[x_String :> {x}] //dechofunction["MCUC: Number of possible fixes",Length]
	]

deleteTokenBarBeforeClosingBracket[cst_, errorNode_]:=
	ReplaceAll[cst, {	a___
					,	LeafNode[Token`Bar, "|", _]
					,	ErrorNode[Token`Error`ExpectedOperand, "", _]
					,	uc : errorNode
					,	b___
					} :> {a, uc, b}
	]



(* ::Subsection::Closed:: *)
(*UC*)


(* FIX PATTERN ----------------------------------------------------------------------- *)
$$FatalUnexpectedCloser = {___, {"Fatal", "UnexpectedCloser"}, ___};

fixPatternBrackets[_][code_String, pat : $$FatalUnexpectedCloser, patToIgnore_ : {}] :=
	Module[{success,fixedCode,allCodeScore,allCodeNoScore},
	decho["**********  UC  **********"];
	With[
		{
		ccp=CodeConcreteParse[code,SourceConvention->"SourceCharacterIndex"],
		codetoken=CodeTokenize[code,SourceConvention->"SourceCharacterIndex"]
		}
		,
		{errorNode=Cases[ccp,f_[___,Token`Error`UnexpectedCloser,___],Infinity]//If[MatchQ[#,{__}],First@#,{}]&(*//EchoLabel["UC error node:"]*)
		}
		,
		{bracket=errorNode[[2]]}
		,
		{allbrackets=Cases[codetoken,LeafNode[_,bracket,so_]:>so]//Select[#[[1,2]]<=errorNode[[3,1,1]]&](*//EchoLabel["UC allbrackets"]*)}
		,
		{
		excludedRanges=Cases[ccp,GroupNode[Except[bracket/.{"]"->GroupSquare,")"->GroupParen,"}"->List,"|>"->Association},_],_,so_]:>so,Infinity]
						//Select[#[[1,2]]<errorNode[[3,1,1]]&]
		}
		,
		{
		finalBrackets=Select[allbrackets, Not[Or@@IntervalMemberQ[Map[Interval@#[Source]&,excludedRanges],#[[1,1]]]]&]//SortBy[#[[-1,-1]]&]//decholabel["UC finalBrackets:"]
		}
		,
		If[ finalBrackets==={}
			,
			Missing["UC: No fixes"]
			,
			Map[(DeleteCases[codetoken,LeafNode[_,bracket,#]]//Map[ToSourceCharacterString]//StringJoin)&,finalBrackets]
			//
			Map[<|"Code"->#,"DefaultScore"->0,"Type"->"D", "Pattern"->"UC"|>&]// MapAt[1&,{-1,"DefaultScore"}]
			//
			DeleteDuplicates //dechofunction["UC: Number of possible fixes",Length]
		]
]]



(* ::Subsection::Closed:: *)
(*MC*)


(* FIX PATTERN ----------------------------------------------------------------------- *)
$$FatalGroupMissingCloser = {___, {"Fatal", "GroupMissingCloser"}, ___};

fixPatternBrackets[_][code_String, pat : $$FatalGroupMissingCloser, patToIgnore_ : {}] :=
	Module[{
			 fixedCode=Missing[]
			,finalgnso
			}
			,
			decho["**********  MC  **********"]
			;
			With[
			{
			bracketTypes={GroupSquare -> ("f["<>#<>"]"&), List -> ("{"<>#<>"}"&)},
			missingBracketType=Cases[CodeConcreteParse@code, _GroupMissingCloserNode,Infinity]//#[[1,1]]&
			}
			,
			{
			codeF=DeleteCases[bracketTypes,missingBracketType->_] // #[[1,2]]& // #[code]&
			}
			,
			{
			gmcn= 	codeF//
					CodeConcreteParse[#,SourceConvention->"SourceCharacterIndex"]& //
					Cases[#, _GroupMissingCloserNode,Infinity]& // dechofunction["MC: all GMCs source",#[[All,-1]]&] //
					First // dechofunction["MC: GMC selected",Last@#&]
			}
			,
			{
			gnsoSameType=	gmcn//
							ReplaceAll[GroupNode[Except[missingBracketType,_],__]:>Nothing]//
							Cases[#,GroupNode[missingBracketType,__,so_]:>so,Infinity]&,

			gnsoOtherType=	gmcn//
							ReplaceAll[GroupNode[t_,__,(* Except[<|Source->{_,gmcn[[-1,-1,-1]]}|>,so_] *)so_]:>{"get",t,so}]//
							Cases[#,{"get",Except[missingBracketType,t_],so_}:>so,Infinity]&
			}
			,
			finalgnso = Join[gnsoOtherType, gnsoSameType]//If[#==={}, {gmcn[[3]]}, #]& // SortBy[#[[-1,-1]]&] (*// EchoLabel["finalgnso"]*);

			fixedCode=	Map[
							(
								StringInsert[ codeF
											, gmcn[[1]] /. {GroupSquare -> "]", GroupParen -> ")", List -> "}",Association -> "|>"}
											, #[[ -1, -1]] + 1
											] //
								StringTake[#,{2+If[MatchQ[missingBracketType,List|GroupParen|Association],1,0],-2}] & //
								{"Code"->#,"Pattern"->"MC", "Type"->"A","DefaultScore"->0}& //
								Association
							)&
							, finalgnso
							]//MapAt[1&,{-1,"DefaultScore"}]//
						DeleteDuplicates //dechofunction["MC: Number of possible fixes",Length]
	]]



(* ::Subsection::Closed:: *)
(*Default fix*)


fixPatternBrackets[_][code_String, pat:{__}]:={<|"Code"->code, "Status"->"Failed"|>}


fixPatternBrackets[_][code_String, {}]:= {<|"Code"->code, "Status"->"Fixed"|>}


(* ::Section:: *)
(*Scoring*)


(*Syntax informations to check System functions arguments*)
$syntargs := $syntargs = 	{Import[PacletObject["Wolfram/Chatbook"]["AssetLocation", "SyntaxInformation"], "WXF"]
							(*temporarily adding missing info from SyntaxInformation*)
							,"With" -> {__}
							,"EchoLabel" -> {_}
							,"EchoFunction"->{_,_:""}
							} // Association

$systemOptions := $systemOptions = Import[PacletObject["Wolfram/Chatbook"]["AssetLocation", "SyntaxOptions"], "WXF"]


(*$syntargs=Import["/Users/chris/Wolfram-Workspace/Stash/chatbook/Assets/SyntaxArguments.wxf"];
$systemOptions=Import["/Users/chris/Wolfram-Workspace/Stash/chatbook/Assets/SyntaxOptions.wxf"];*)
$funcsSyntax={};


(*updating SyntaxInformation*)
newsyntax=
{
	"Table"->{_,Alternatives["List"->_, Integer]...},
	"N"->Alternatives[{_,Repeated[Integer| Real,{0,1}]}],
	"FaceForm"->Alternatives[{},{_},{_,Except["EdgeForm"->_]}],
	"Prepend"->Alternatives[{_},{_,_}],
	"Column"->{"List" -> {_, __}} | {"List" -> {_, __}, Symbol -> _} | {"List" -> {_, __}, Symbol -> _, _},
	"D"->{_,__,"Rule"...}
};
Map[($syntargs[#[[1]]]=#[[2]])&,newsyntax];


scoreCode[code_String]:=
	With[
		{cns = Cases[CodeParse[code], CallNode[LeafNode[Symbol,Except[funcsNotToScore],Except[<||>]],__], Infinity]}
		,
		{allpat=Map[funcnameCN,cns]//Union//Map[#->getSyntaxPattern@#&]}
		,
		Block[{$funcsSyntax=allpat},
			(*Echo[$funcsSyntax,"$funcsSyntax"];*)
			Total@Map[scoreCallNode, cns] - countErrors[code]

		]
	]

(* :!CodeAnalysis::Disable::KernelBug:: *)
countErrors[code_String]:=
	(
	CodeInspect[code]	//	ReplaceAll[	{
										InspectionObject[	___,
															"UnusedVariable", ___,
															"Scoping", ___,
															KeyValuePattern["Argument" -> "Module"],
															___
										]	->	1
										,
										InspectionObject[	"Arguments",
															_,
															"Error",
															KeyValuePattern["Argument" -> _String]
										]	->	Infinity
										,
										InspectionObject[__] ->	0
										}
							]
						// Total
	)

funcsNotToScore=Alternatives["Rule","List","Plus","Times","Power"]

scoreCallNode[cn_CallNode]:=
Catch[
	With[
		{
		syntaxPattern=(funcnameCN[cn] // (* decholabel["scoring: funcname"]// *)ReplaceAll[ $funcsSyntax ] // Replace[f_String :> getSyntaxPattern@f])
		}
		,
		If[MissingQ[syntaxPattern](*//EchoLabel["syntaxPattern MissingQ"]*), Throw[0]];
		(
		Sequence@@getCallNodeArgs[cn]
		//
		Function[{funcname,args},
			If[MatchQ[args,syntaxPattern](*//EchoLabel["MatchQ"]*)
				,
				Replace[args ,	{
								HoldPattern[Rule]["Rule",{optionName_,_}]:>
									If[MemberQ[$systemOptions[funcname]/.{_Missing->{}}, optionName]
										, 2
										, 0
									]
								(* ,
								HoldPattern[Rule]["List", a:{__}] :> Length@a *)
								,
								Except[_Integer]:>1
								}
						,{1}
				](*//EchoLabel["After options check"]*)
				//Total
				,
				0
			]
		](* //decholabel["scoring: score"] *)
		)
	]
]

getCallNodeArgs[cn_CallNode]:=
(
	Replace[	cn
				,
				CallNode[LeafNode[Symbol,funcname_,_],args_List,_]:>
					Rule[	funcname
							,
							(
								args//If[funcname=!="Rule"
										, ReplaceAll[#, {LeafNode[Symbol, name_, _] :> (Symbol -> name), LeafNode[type_, _, _] :> type}]
										, ReplaceAll[#,{LeafNode[Symbol,name_,_],__}:>{name, _}]
									]&
							)
					]
	, {0, Infinity}
	]
	//
	Replace[#, _Rule->_, {2*2}]&(*//EchoLabel["args:"]*)
)

getSyntaxPattern[cn_CallNode]:=getSyntaxPattern[funcnameCN[cn](*//EchoLabel["funcname"]*)]

getSyntaxPattern[funcname_String]:=
(
	$syntargs[funcname]
	//
	If[	MissingQ@#
		,#
		,(#	//ReplaceAll[#,Verbatim[RepeatedNull][s_String]:>RepeatedNull@Alternatives[s->_,s]]&
			//ReplaceAll[Verbatim[_:"def"]->RepeatedNull[_,1]]
			//Replace[#,Symbol->(Symbol->_),{1}]&
		)
	]&(*//EchoLabel["SyntaxPattern"]*)
)

funcnameCN[CallNode[LeafNode[Symbol,funcname_,_],_,_]]:=funcname


(* ::Section::Closed:: *)
(*Other Fixes*)


(* FIX PATTERN ----------------------------------------------------------------------- *)

$$ErrorCommaFatalExpectedOperand={{"Error", "Comma"}.., {"Fatal", "ExpectedOperand"}..}
fixPattern[target_][code_String, pat:$$ErrorCommaFatalExpectedOperand]:=
	(* try fix the error comma first*)
		fixPattern[target][code, Cases[pat, {"Error", "Comma"}], (*ignore:*){"Fatal", "ExpectedOperand"}]

(* FIX PATTERN ----------------------------------------------------------------------- *)
$$ErrorComma={{"Error","Comma"}..};
fixPattern[target_][code_String, pat:$$ErrorComma, patToIgnore_:{}]:=
	Module[
			{fixedCode, success=False, lenPatLeft, falsePositive=Missing[], safe=Missing[], totalFixes=0}
			,
			(* Echo[pat,"Pattern:"]; *)

			fixedCode =
				CodeConcreteParse[code]
				// 	ReplaceRepeated[
						{
							{a___,LeafNode[Token`Comma,",",_], LeafNode[Whitespace | Token`Newline, __]... ,ErrorNode[Token`Error`InfixImplicitNull,"",_]}
							:>((* Echo["deleting comma"]; *)totalFixes++;{a})
							,
							InfixNode[Comma,{a___,LeafNode[Token`Comma,",",_], LeafNode[Whitespace | Token`Newline, __]..., ErrorNode[Token`Error`InfixImplicitNull,"",_],LeafNode[Token`Comma,",",_],b__},_]
							:>((* Echo["deleting comma inside"]; *)totalFixes++;InfixNode[Comma,{a,LeafNode[Token`Comma,",",_],b},_])
							,
							InfixNode[Comma,{ErrorNode[Token`Error`PrefixImplicitNull,"",_],LeafNode[Token`Comma,",",_],b__},_]
							:>((* Echo["deleting comma start"]; *)totalFixes++;InfixNode[Comma,{b},_])
						}
					]
				//	ToSourceCharacterString
			;

			fixedCode
			// If[FailureQ@#
				 	,	fixedCode=Missing["Fix failure"];
				 	,	(
						CodeCheck[target][#] // generatePatternFromCodeCheck // DeleteCases[patToIgnore] // decholabel["Comma check:"]
				   		// 	Switch[#
									(* ----------------- *)
				   			  		, {}
							  		, success=True; safe=True; falsePositive=False;
							  		(* ----------------- *)
							  		, $$ErrorComma
									, (lenPatLeft=Length@#)
										; lengthErrors[replaceCommaComments[fixedCode]]
										//If[!FailureQ@#
											, If[#===0, safe=False; falsePositive=True; success=True, fixedCode=Missing["Problem with the comments"]];
										]&

							]&
						)
				]&
			;
  			{ "Success" -> success
   			, "TotalFixes" -> totalFixes
   			, "LikelyFalsePositive" -> falsePositive
   			, "SafeToEvaluate" -> safe
   			, "Pattern" -> pat
   			, "FixedCode" -> If[code===fixedCode, Missing["Comma: No need to fix"], fixedCode]
   			} // Association
	]

replaceCommaComments[code_]:=	(
								CodeConcreteParse[code]
								//
							  	ReplaceRepeated[
									InfixNode[Comma, {	a___, LeafNode[Token`Comma, ",", _],
														PatternSequence[LeafNode[Whitespace | Token`Newline, __] ...,
																		LeafNode[Token`Comment, _, _],
																		LeafNode[Whitespace | Token`Newline, __] ...
																		]..,
														ErrorNode[Token`Error`InfixImplicitNull, "", _],
														b___
													}
													, s_
									] :>
									InfixNode[Comma, {a, LeafNode[Token`Comma, ",", {}], LeafNode[Symbol, "xxxx", {}], b}, s]
								]
								//
								ToSourceCharacterString
								)

(* FIX PATTERN ----------------------------------------------------------------------- *)
$$FatalExpectedOperandFatalOpenSquare={{"Error", "ImplicitTimesFunction"}...,{"Fatal", "ExpectedOperand"}.., {"Fatal", "OpenSquare"}..};

fixPattern[target_][code_String, pat:$$FatalExpectedOperandFatalOpenSquare, patToIgnore_:{}]:=
	Module[
			{fixedCode=Missing[], success=False, falsePositive=Missing[], safe=Missing[], totalFixes=Missing[]}
			,
			Length@StringCases[	code,	Alternatives[ 	 StringExpression["![", __, "](attachment://", __]
														,StringExpression[__, "[", __, "](paclet:", __]
										]]
			//
			If[#=!=0
				, success=True; fixedCode=Missing["Not WL code"]; safe=False; falsePositive=False; totalFixes=0;
				, success=False; fixedCode=Missing["Unhandled subcase", pat];
			]&
			;
			{ "FixedCode"->fixedCode
			, "Success"->success
			, "TotalFixes"->totalFixes
			, "LikelyFalsePositive"->falsePositive
			, "SafeToEvaluate"->safe
			, "Pattern"->pat
			} // Association
	]

(* FIX PATTERN ----------------------------------------------------------------------- *)
$$BadSnakeUsage = HoldPattern[{___, {"Fatal", "BadMultiSnakeUsage"}->#, ___}]&;

fixPattern[target_][code_String, pat : $$BadSnakeUsage[so_], patToIgnore_ : {}] :=
	Module[	{
			fixedCode=Missing["BadMultiSnakeUsage","No fix found"]
			,success=False
			}
			,

			{formatSnake@StringTake[code, #], #} & /@ so // Transpose // StringReplacePart[code, Sequence @@ #] &
			// If[success=StringQ@#, fixedCode=#]&
			;
			{ "Success" -> success
			, "TotalFixes" -> If[success, Length@so, 0]
			, "LikelyFalsePositive" -> If[success, False, True]
			, "SafeToEvaluate" -> If[success, True, False]
			, "Pattern" -> pat
			, "FixedCode" -> fixedCode
			} // Flatten // Association
	]

formatSnake[s_String] := StringSplit[s, "_"] // {First@#, Capitalize@Rest@#} & // Flatten // StringJoin;

scanSnakeMulti[codeTokenized_, tokenPositions_List]:=
(
	With[	{
			stringPositions =	tokenPositions // Select[Not@MatchQ[codeTokenized[[Span @@ #]], pSnakeSingleTokens] &] //
								Map[{codeTokenized[[First@#, -1, Key@Source, 1]], codeTokenized[[Last@#, -1, Key@Source, -1]]} &]
			}
			,
			If[
				stringPositions === {}
				,
				Nothing
				,
					checkSnakeInSetDelayed[codeTokenized, stringPositions] //
					CodeInspector`InspectionObject["BadMultiSnakeUsage","Bad Snake Usage", "Fatal",
											Association@{ConfidenceLevel -> 1, Source->#}]&
			]
	]
)

(* checking for for bad snake arguments in SetDelayed definitions*)
checkSnakeInSetDelayed[codeTokenized_, stringPositions_List]:=
	With[
			{codeStringFromCT = codeTokenized[[All, 2]] // StringJoin}
			,
			{cp = CodeParse[codeStringFromCT, SourceConvention -> "SourceCharacterIndex"]}
			,
			{posSDWithUnder = Position[cp, pSnakeUnderInSetDelayed]}
			,
			If[	posSDWithUnder==={}
				,
				stringPositions
				,
				Table[	Cases[	Extract[cp,posSDWithUnder[[i]]][[2,1]] (* checking LHS *)
								,
								u:pSnakeUnder :>(	u[[-1,Key@Source]] //
													(
													#->	(		StringTake[codeStringFromCT,#]
															//	StringDrop[#,-1]&
															//	CodeParse
															//	#[[2,1]]&
															//	ReplaceAll[<|__|>->_]
															//	Cases[	Extract[cp,posSDWithUnder[[i]]][[2,2]] (* checking RHS*)
																		,
																		x:#	:>x[[-1,Key@Source]]
																		,Infinity
																]&
														)
													)&
												)
								,Infinity
						]
						,
						{i,Length@posSDWithUnder}
				]
				//
				Join[
						ReplaceAll[stringPositions,	Cases[#, HoldPattern[Rule[x_, _]] :> x -> (x + {0, -1}), Infinity]]
						,
						Cases[#, HoldPattern[Rule[_, y_]] :> y, Infinity] // Flatten[#, 1] &
				]&
			]
	];


pSnakeUnder=CallNode[LeafNode[Symbol,"Times",<||>],{__,CallNode[LeafNode[Symbol,"Blank",<||>],{},_]},_];
pSnakeUnderInSetDelayed= CallNode[LeafNode[Symbol,"SetDelayed",<||>],{CallNode[LeafNode[Symbol,_,_],{___,pSnakeUnder,___},_],_},_];

scanSnakeAllButSingle[codeTokenized_, positions_List]:=
(
		positions
		//
		Select[Not@MatchQ[codeTokenized[[Span @@ #]], pSnakeSingleTokens] &]
		//
		Map[{codeTokenized[[First@#, -1, Key@Source, 1]], codeTokenized[[Last@#, -1, Key@Source, -1]]} &]
		//
		Replace[	{	{}	->	Nothing
						,
						p:{__} :>	CodeInspector`InspectionObject["BadMultiSnakeUsage","Bad Snake Usage", "Fatal",
										Association@{ConfidenceLevel -> 1, Source->p}]
					}
		]
)

(* all snakes: "a_b", "a_1" "a_b__1_a2___" *)
pSnakeAll={$lnSymbol,$lnUnders,($lnSymbol|$lnInteger|$lnUnders)..,Repeated[$lnOpensquare,{0,1}]};

(* a_b but not a_b_ nor a_b[ *)
pSnakeSingleTokens={$lnSymbol,$lnUnders,$lnSymbol,Repeated[Except[$lnUnders|$lnOpensquare],{0,1}]};

$lnSymbol=LeafNode[Symbol,_,_];
$lnInteger=LeafNode[Integer,_,_];
$lnUnders=LeafNode[Token`Under|Token`UnderUnder|Token`UnderUnderUnder,__];
$lnOpensquare=LeafNode[Token`OpenSquare,__];

(* FIX PATTERN ----------------------------------------------------------------------- *)
$$BadSingleSnakeUsage = HoldPattern[{___, {"Fatal", "BadSingleSnakeUsage"}->#, ___}]&;

fixPattern[target_][code_String, pat:$$BadSingleSnakeUsage[so_], patToIgnore_ : {}] :=
	Module[	{
			 fixedCode=Missing["BadSingleSnakeUsage","No fix found"]
			,success=False
			}
			,
			{formatSnake@StringTake[code, #], #} & /@ so // Transpose // StringReplacePart[code, Sequence @@ #] &
			// If[success=StringQ@#, fixedCode=#]&
			;
			{ "Success" -> success
			, "TotalFixes" -> If[success, 1, 0]
			, "LikelyFalsePositive" -> If[success, False, True]
			, "SafeToEvaluate" -> If[success, True, False]
			, "Pattern" -> pat
			, "FixedCode" -> fixedCode
			} // Flatten // Association

	]

pSingleSnake=
	(* a_b = ...*)
	CallNode[LeafNode[Symbol,"Set",<||>],{CallNode[LeafNode[Symbol,"Pattern",<||>],{LeafNode[Symbol,_,_],CallNode[LeafNode[Symbol,"Blank"|"BlankSequence"|"BlankNullSequence",<||>],{LeafNode[Symbol,_,_]},_]},_],__},_]

scanSingleSnake // ClearAll;
scanSingleSnake[pos_, ast_] :=
(
	Cases[ast, cn : (Extract[ast,pos][[2,1]] /. <|__|> -> _) :> cn[[-1, Key@Source]], Infinity] //
	CodeInspector`InspectionObject["BadSingleSnakeUsage","Bad Snake Usage", "Fatal",
									Association@{ConfidenceLevel -> 1, <|Source->#|>}]&
)
(* -------- *)

(* FIX PATTERN ----------------------------------------------------------------------- *)
$$SuspiciousQuantityUnitName = HoldPattern[{___, {"Fatal", "SuspiciousQuantityUnitName"}->#, ___}]&;

fixPattern[target_][code_String, pat:$$SuspiciousQuantityUnitName[so_], patToIgnore_ : {}] :=
	Module[	{
			 fixedCode=Missing[]
			,success=False
			,stringEnds={1,-1}
			}
			,
			StringTake[code, so + stringEnds] // parseUnits (* //EchoLabel["parsed"] *)
			//
			If[	MissingQ@#
				,	success=False ; fixedCode=#;
				, 	success=True
					;	fixedCode = StringReplacePart[		code
														,	Replace[#,x:Except[_String]:>(stringEnds={0,0}; ToString[x,InputForm])]
														,	so + stringEnds
									]

			]&
			;
			{ "Success" -> success
			, "TotalFixes" -> If[success, 1, 0]
			, "LikelyFalsePositive" -> False (* -> pQuantityUnitName *)
			, "SafeToEvaluate" -> True (* the unit is a String *)
			, "Pattern" -> pat
			, "FixedCode" -> fixedCode
			} // Flatten // Association
	]

(*---*)

(* the list of supported units -> Todo: update with Entity list ?*)
ascValidUnits := ascValidUnits =
(
	{
	Select[QuantityUnits`$UnitList, quantityCamelCaseLikeQ],
    Select[Keys@QuantityUnits`$UnitAlternateStandardNameReplacements, quantityCamelCaseLikeQ]
	}
	// Apply[Union]
	//	{
		Thread[# -> True],
		Thread[{"Cubic", "Cubed", "Square", "Squared", "Per"} -> True]
		}&
	// Apply[Association]
)


Clear[validUnitQ,quantityCamelCaseLikeQ, splitCamel,groupUnits]

validUnitQ[unit_String]:=
			Or[	 Lookup[ascValidUnits, unit, False]
				,Lookup[ascValidUnits, unit <> "s", False]]

validUnit[unit_String] :=
	Block[	{vu}
			,
			Or[	 Lookup[ascValidUnits, vu = unit, False]
				,Lookup[ascValidUnits, vu = (unit <> "s"), False]]
			// If[#, vu, Missing[unit]] &
	]

(* Todo : support "$" *)
quantityCamelCaseLikeQ[s_String]:=StringMatchQ[s, StringExpression[ _?UpperCaseQ,(_?UpperCaseQ|_?LowerCaseQ|DigitCharacter)...]]
quantityCamelCaseLikeQ[__]:=False

splitCamel[s_String] :=
	StringReplace[	s
					,
					{	StringExpression[	 a : (_?LowerCaseQ | DigitCharacter | StartOfString)
											,b : (_?UpperCaseQ) ..
						] :> StringJoin[a, " ", StringRiffle@Characters@b]
					}
	] // StringSplit // Replace[{x_String} :> x]

groupUnits[cc : {_String ..}] :=
	With[
		{n = Length@cc}
		,
		{
		paths = Table[	If[	validUnitQ@StringJoin@cc[[i ;; i + j]]
							, {i, i + j}
							, Nothing
						], {j, 0, n - 2}, {i, 1, n - j}
				] // Flatten[#, 1] & //	GroupBy[First] // Association @@ {#, _ -> {"stop"}} & // Normal
	 	}
		,
  		{
		groups =		Map[List, (1 /. paths)]
					//	ReplaceRepeated[{ij : {a___, {i_Integer, j_Integer}} :> Outer[Append, {ij}, (j + 1) /. paths, 1]}]
					//	Cases[#, ij : {a___, {i_Integer, n}, "stop"} :> Most@ij, Infinity] &
		}
		,
		(* Selecting the solution with the less number of compound names (==longer names) and not being an $$InvalidGroup*)
  		SortBy[groups, Length]
		//
		Catch[	Map[	(buildGroupNames[cc, #] // If[ Not@MatchQ[#, $$InvalidGroupNames], Throw[#] ]&) &, #]
				;
				{}
		]&
	]


buildGroupNames[cc_, group_]:=Map[validUnit@StringJoin@cc[[Span @@ #]] &,group];
$$InvalidGroupNames={___, aPrefix, _?(StringContainsQ[#, "Per"] &), ___} | {___, _?(StringContainsQ[#, "Per"] &), aSuffix, ___};

rPowers2Int	=	{"Cubic"|"Cubed"->3, "Square"|"Squared"->2};
aPowers		=	"Cubic"|"Cubed"|"Square"|"Squared";
aPrefix		=	Alternatives["Cubic","Square"];
aSuffix		=	Alternatives["Cubed","Squared"];

Clear@parseUnits

parseUnits[w_String?quantityCamelCaseLikeQ] :=
	Catch[
			splitCamel[w]
		// 	If[# === w, If[validUnitQ@#, Throw@validUnit@#, Throw[Missing["Unknown unit",w]]], #]&
		//	Replace[x_String :> {x}]
		(*	----- testing / selection a combination of valid compound unit names  *)
		//	groupUnits // If[# === {}, Throw@Missing["Unknown unit",w], #]&
		//	Map[validUnit]
		(* 	----- processing pre & suf - fixes and "Per" keywords *)
		//	SplitBy[#, # === "Per" &] & //	ReplaceAll[{"Per"} -> "Per"]
		//	ReplaceAll[{a___, prefix : aPrefix, b__} :> {Replace[{a}, {} ->Nothing], {prefix, {b}}}]
		//	ReplaceAll[{a__, suffix : aSuffix, b___} :> {{{a}, suffix}, Replace[{b}, {} -> Nothing]}]
		//	ReplaceAll[us : {_String ..} :> Times @@ us]
		//	ReplaceAll[{{ut_, pow : aPowers} | {pow : aPowers, ut_} :> ut^(pow /. rPowers2Int)}]
		//	ReplaceAll[us : {(Except["Per", _String] | _Power | _Times) ..} :> Times @@ us]
		//	ReplaceRepeated[{{a_, "Per", b_} :> a/b , {a_, "Per", b_, c__} :> {a/b, c}}]
		//	ReplaceAll[{x_} :> x]
		(*	----- final check*)
		//	If[	MatchQ[#,
						HoldPattern[Times][	OrderlessPatternSequence[HoldPattern[Power][_String, _Integer] ...
											,Except[aPowers | "Per", _String] ...
													]] |
						HoldPattern[Power][_String, _Integer]
				]
				, #, Missing["parseUnits", w]
			] &
]

(*---*)

suspiciousUnitQ[unit_String?(quantityCamelCaseLikeQ[StringTrim[#, "\""]]&)]:=
	Not@Lookup[ascValidUnits, StringTrim[unit, "\""], False]
suspiciousUnitQ[__]:=False

pQuantityUnitName =
	CallNode[LeafNode[Symbol, "Quantity", _], {_LeafNode (*number*), LeafNode[String, _?suspiciousUnitQ (*unit name)*), _]}, _]

scanQuantityUnitName // ClearAll;

scanQuantityUnitName[pos_, ast_] :=
(
	(* Echo["Checking Quantity name"]; *)
	FirstCase[Extract[ast, pos], LeafNode[String, unitName_String,so : <|Source -> _|>] :> so, {}, Infinity] //
	CodeInspector`InspectionObject["SuspiciousQuantityUnitName","Suspicious Quantity Unit Name", "Fatal",
				Association@{ConfidenceLevel -> 1, #}]&
)

(* FIX PATTERN (Default) -> WARN PATTERN ------------------------------------------------------------- *)

fixPattern[target_][code_String, pat_]:=
	((* Echo["START WARN"]; *)
	Fold[mergeFixes[#1, warnPattern[target][code,#2]] &, <||>, Split@Sort@pat]//
	Association@@{#,"StopCodeFix"->True}&
	)

(* ----------------------------------------------------------------------------------- *)

(* WARNING PATTERN ----------------------------------------------------------------------- *)
$$SuspiciousSymbol = HoldPattern[{___, {"WarningChatbook", "SuspiciousFunctionSymbol"}->#, ___}]&;
(* $$BadSymbol = HoldPattern[{___, {"RemarkChatbook", "GlobalCapitalizedSymbol"}->#, ___}]&; *)

warnPattern[target_][code_String, pat:($$SuspiciousSymbol[so_](* |$$BadSymbol[so_] *)), patToIgnore_ : {}] :=
	{ "Success" -> True
	, "TotalFixes" -> 0
	, "LikelyFalsePositive" -> False
	, "SafeToEvaluate" -> True
	, "Pattern" -> pat
	, "FixedCode" -> Missing["Warning only"]
	} // Association

(*---*)
pSetDelayedFunction[funcname_] :=
 CallNode[LeafNode[Symbol,"SetDelayed", _], {subvalFunc[funcname], __}, _]

subvalFunc[funcname_] := (svf = CallNode[x_, _, _] /; MatchQ[x, LeafNode[Symbol, funcname, _] | svf])

pSetFunction[funcname_] :=
				CallNode[
					LeafNode[Symbol, "Set", <||>]
					, {CallNode[LeafNode[Symbol, funcname, _]
								, {___, CallNode[ LeafNode[Symbol, "Pattern", <||>]
											, {LeafNode[Symbol, __], CallNode[LeafNode[Symbol, "Blank", <||>], __]}
											, _], ___}
								, _]
						, __}
					, _]

pSuspiciousFunctionSymbol = CallNode[LeafNode[Symbol, _?suspiciousFunctionSymbolQ, _], _, _];

suspiciousFunctionSymbolQ[name_String] :=
(
	(* Echo["function exists?"]; *)
	(StringSplit[name, "`"] // Map[StringStartsQ[_?UpperCaseQ]] // Apply[And])
	&&
	Not[TrueQ@$UserDefinedFunctionsQ[name]]
	&&
	Not[NameQ[name] && ((Context[name] === "System`") || ToExpression[name, InputForm, System`Private`HasAnyEvaluationsQ])]
)

scanSuspiciousSymbol[pos_, ast_] :=
(
	(* Echo["Scan suspicious symbol"]; *)
	With[	{node = Extract[ast, pos]}
			,
			{name = node[[1, 2]]}
			,
			{funcnode=FirstCase[ast, pSetDelayedFunction[name] | pSetFunction[name], Missing[], Infinity]}
			,
			If[	MissingQ@funcnode
				,	CodeInspector`InspectionObject["SuspiciousFunctionSymbol","Suspicious Function Name: " <> name, "WarningChatbook",
   						Association@{ConfidenceLevel -> 2,(*Source*)node[[-1]]}]
				,	$UserDefinedFunctionsQ[name]=True
					;
					Nothing
					(* ;
					CodeInspector`InspectionObject["GlobalCapitalizedSymbol","Bad Function Name: " <> name, "RemarkChatebook",
   						Association@{ConfidenceLevel -> 1,(*Source*)funcnode[[-1]]}] *)
			]
	]
)

(* WARNING PATTERN ----------------------------------------------------------------------- *)
$$FatalExpectedOperand={{"Fatal","ExpectedOperand"}..};
warnPattern[target_][code_String, pat:$$FatalExpectedOperand, patToIgnore_:{}]:=
	Module[
			{
			 fixedCode=Missing["Expected Operand: no place holder(s) detected"]
			,lenPat=Length@pat
			,falsePositive=False
			,safe=Failure["Expected Operand: no place holder(s) detected",<||>]
			,success=False
			}
			,
			Length@Cases[CodeConcreteParse[code],patExtraOperandEllipsisComment,Infinity]
			//
			If[#===lenPat
				, success=True; safe=False; falsePositive=True; fixedCode=Missing["No fix needed"];
			]&
			;
			{ "Success" -> success
   			, "TotalFixes" -> 0
   			, "LikelyFalsePositive" -> falsePositive
   			, "SafeToEvaluate" -> safe
   			, "Pattern" -> pat
   			, "FixedCode" -> fixedCode
   			} // Association
	]

patExtraOperandEllipsisComment=
	Alternatives[
			{__,PostfixNode[RepeatedNull,{ErrorNode[Token`Error`ExpectedOperand,"",_],LeafNode[Token`DotDotDot,"...",_]},_],___}
			,
			BinaryNode[_,{__,LeafNode[Token`Comment,_,_],___(* white space and newline mixed*),ErrorNode[Token`Error`ExpectedOperand,"",_]},_]
	]

(* WARN PATTERN (Default) ------------------------------------------------------------- *)
warnPattern[target_][_String, pat_]:=
	{ "Success" -> False
	, "TotalFixes" -> 0
	, "LikelyFalsePositive" -> False
	, "SafeToEvaluate" -> False
	, "Pattern" -> Missing["Warn",pat]
	, "FixedCode" -> Missing["No pattern", pat]
	} // Association

(* ----------------------------------------------------------------------------------- *)


(* ::Section:: *)
(*Debug*)


(*------- For debugging*)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
decho[x_,mess___]:=If[TrueQ[Wolfram`Chatbook`CodeCheck`$CodeCheckDebug],Echo[x, mess], x]

decholabel[mess_String][x_]:=If[TrueQ[Wolfram`Chatbook`CodeCheck`$CodeCheckDebug],EchoLabel[mess][x],x]

dechofunction[a__][b_]:=If[TrueQ[Wolfram`Chatbook`CodeCheck`$CodeCheckDebug],EchoFunction[a][b],b]

Wolfram`Chatbook`CodeCheck`$CodeCheckDebug=False



(* ::Chapter::Closed:: *)
(*End*)


(* :!CodeAnalysis::EndBlock:: *)


(* ::Section:: *)
(*End Private*)


ifn = $InputFileName
End[ ];


(* ::Section:: *)
(*End Package*)


EndPackage[ ];
