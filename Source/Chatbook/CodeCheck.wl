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

Begin[ "`Private`" ];

(* ::Chapter:: *)
(*Functions*)


(* ::Text:: *)
(*"SafeToEvaluate" -> False if there are any placeholders / comments*)


(* ::Section:: *)
(*CodeCheckFix*)

$FixRecursionLimit=10;

CodeCheckFix[code_String]:= (
	Needs[ "CodeInspector`" -> None ];
	Needs[ "CodeParser`" -> None ];
	CodeCheck[code] // { #
						,Block[{niter=0,recursionLimit=$FixRecursionLimit},CodeFix[code,#]]
						,"OriginalCode"->code
						}&
	// Association
)

(* ::Section:: *)
(*CodeCheck*)


Options[CodeCheck]={"SeverityExclusions" ->{(*(*4/4*)"Fatal", (*3/4*)"Error"*)
												 (*2/4*)"Warning"
												,(*1/4*)"Remark"
												,(*0/4*)"ImplicitTimes","Formatting" ,"Scoping"
												},
					"TagExclusions" -> {"SetInfixInequality" 		(* cases like: a = b==c *)
										,"ImplicitTimesPseudoCall"	(* cases like: a (b+c)*)
										},
					SourceConvention -> "SourceCharacterIndex"
						};


CodeCheck[code_String, OptionsPattern[]]:=
	(
		 CodeInspect[code, Sequence@@Options[CodeCheck]]
		 //
		 {"ErrorsDetected"->#=!={}
		 ,"CodeInspector" -> Association@@{"InspectionObjects"->#,"OverallSeverity"->codeInspectOverallSeverityLevel[#]}
		 }&
	)

(* ::Subsection::Closed:: *)
(*Helpers*)


codeInspectOverallSeverityLevel[ios:{__InspectionObject}]:=ios[[All,3]]//ReplaceAll[ruleCodeInspectSeverityToLevel]//Max
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


(* ::Section:: *)
(*CodeFix*)

(* CodeFix[code_String]:=CodeFix[code, CodeCheck[code]] *)

CodeFix[
		code_String
		,kvCI:KeyValuePattern[{"ErrorsDetected"->True, "CodeInspector"->_}]
		,params_:<||>
		]:=
		CodeFix[{}, fixPattern[code, generatePatternFromCodeCheck[kvCI]]]

CodeFix[
		code_String
		,kvCI:KeyValuePattern[{"ErrorsDetected"->False}]
		,params_:<||>
		]:= {"FixedCode"->Missing["No errors detected"]}


CodeFix[kvFixPrev_, kvFixNew:KeyValuePattern[{"Success"->True|False}]]:=
	With[{merged=mergeFixes[kvFixPrev, kvFixNew]},
		If[	MatchQ[	kvFixNew	,Alternatives[	 KeyValuePattern[{"Success"->False}]
												,KeyValuePattern[{"Success"->True, "LikelyFalsePositive"->True}]
												,KeyValuePattern[{"Success"->True, "FixedCode"->_Missing}]]
			]
			,
			merged
			,
			generatePatternFromCodeCheck@CodeCheck[merged["FixedCode"]]
			//	If[	 niter > recursionLimit
					,
					{merged, "Success"->False, "RecursionLimitExceeded"->True}
					,
					If[#==={}, merged, (niter++; CodeFix[merged, fixPattern[merged["FixedCode"],#]])]
				]&
		]
	]

generatePatternFromCodeCheck[kv:KeyValuePattern[{"ErrorsDetected"->True, "CodeInspector"->KeyValuePattern[{"InspectionObjects"->ios_}]}]]:=
	 ios // Map[Apply[List]] // #[[All,{3,1}]]& // Sort

generatePatternFromCodeCheck[KeyValuePattern[{"ErrorsDetected"->False}]]:={}

lengthErrors[code_]:=CodeCheck[code]//generatePatternFromCodeCheck//Length
lengthErrors[f_Failure]:=f


mergeFixes[{}, newFix_] := {KeyDrop[newFix,"FixedPattern"], "FixedPatterns" ->{newFix["FixedPattern"]}} // Association

mergeFixes[prevFix_, newFix_] :=
 	{
		"Success" -> newFix["Success"],
		"TotalFixes" -> Plus[prevFix[#], Lookup[newFix,#,0]] &@"TotalFixes",
		"LikelyFalsePositive" -> Or[prevFix[#],Lookup[newFix,#,False]] &@"LikelyFalsePositive",
		"SafeToEvaluate" -> And[prevFix[#], Lookup[newFix,#,False]] &@"SafeToEvaluate",
		"FixedPatterns" -> Append[prevFix["FixedPatterns"],Lookup[newFix,"FixedPattern"]],
		"FixedCode" -> newFix["FixedCode"]
	} // Association

(* ::Subsection:: *)
(*Fixes*)

(* FIX PATTERN ----------------------------------------------------------------------- *)

$patternErrorCommaFatalExpectedOperand={{"Error", "Comma"}.., {"Fatal", "ExpectedOperand"}..}
fixPattern[code_String, pat:$patternErrorCommaFatalExpectedOperand]:=
	(* try fix the error comma first*)
		fixPattern[code, Cases[pat, {"Error", "Comma"}], (*ignore:*){"Fatal", "ExpectedOperand"}]

(* FIX PATTERN ----------------------------------------------------------------------- *)
$patternErrorComma={{"Error","Comma"}..};
fixPattern[code_String, pat:$patternErrorComma, patToIgnore_:{}]:=
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
						CodeCheck[#] // generatePatternFromCodeCheck // DeleteCases[patToIgnore]
				   		// 	Switch[#
									(* ----------------- *)
				   			  		, {}
							  		, success=True; safe=True; falsePositive=False;
							  		(* ----------------- *)
							  		, $patternErrorComma
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
   			, "FixedPattern" -> pat
   			, "FixedCode" -> fixedCode
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
$patternFatalExpectedOperand={{"Fatal","ExpectedOperand"}..};
fixPattern[code_String, pat:$patternFatalExpectedOperand, patToIgnore_:{}]:=
	Module[
			{
			 fixedCode=Missing["Expected Operand (no place holder(s) detected)"]
			,lenPat=Length@pat
			,falsePositive=Missing[]
			,safe=Missing[]
			,success=False
			}
			,
			Length@Cases[CodeConcreteParse[code],patExtraOperandEllipsisComment,Infinity]
			//
			If[#===lenPat
				, success=True; safe=False; falsePositive=True; fixedCode=code;
			]&
			;
			{ "Success" -> success
   			, "TotalFixes" -> 0
   			, "LikelyFalsePositive" -> falsePositive
   			, "SafeToEvaluate" -> safe
   			, "FixedPattern" -> pat
   			, "FixedCode" -> fixedCode
   			} // Association
	]



patExtraOperandEllipsisComment=
	Alternatives[
			{__,PostfixNode[RepeatedNull,{ErrorNode[Token`Error`ExpectedOperand,"",_],LeafNode[Token`DotDotDot,"...",_]},_],___}
			,
			BinaryNode[_,{__,LeafNode[Token`Comment,_,_],___(* white space and newline mixed*),ErrorNode[Token`Error`ExpectedOperand,"",_]},_]
	]


(* FIX PATTERN ----------------------------------------------------------------------- *)
$patternFatalExpectedOperandFatalOpenSquare={{"Error", "ImplicitTimesFunction"}...,{"Fatal", "ExpectedOperand"}.., {"Fatal", "OpenSquare"}..};

fixPattern[code_String, pat:$patternFatalExpectedOperandFatalOpenSquare, patToIgnore_:{}]:=
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
			, "FixedPattern"->pat
			} // Association
	]

(* FIX PATTERN ----------------------------------------------------------------------- *)
$patternFatalGroupMissingCloserFatalUnexpectedCloser = {___, {"Fatal","GroupMissingCloser"}, ___, {"Fatal", "UnexpectedCloser"}, ___};

fixPattern[code_String, pat : $patternFatalGroupMissingCloserFatalUnexpectedCloser, patToIgnore_ : {}] :=
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
   			, codeFixed = Missing[]
   			, success = False
   			}
  			,

  			allGMCpos = Position[ccp, _GroupMissingCloserNode];

  			(* looping on all GMC positions *)
  			Catch@
			Do[
    			posGMC = allGMCpos[[iGMCpos]];
    			gmc = Extract[ccp, posGMC];
    			newClosingBracket =	gmc[[1]] /.  {GroupSquare -> "]", GroupParen -> ")", List -> "}"};
    			wrongClosingBrackets = Alternatives["]", ")", "}"] // DeleteCases[newClosingBracket];
    			posUC = Position[gmc, Token`Error`UnexpectedCloser];

    			codeFixed =
					If[	posUC === {}
       					,
       					(* UC outside GMC *)
							codeTokenized = CodeTokenize[code, SourceConvention -> "SourceCharacterIndex"]
							;wrongLeafNode = SelectFirst[codeTokenized, 	And[ #[[-1, 1, 2]] > gmc[[-1, 1, 2]]
																				,MatchQ[#[[2]], wrongClosingBrackets]] &]
							;ccp // ReplaceAll[wrongLeafNode -> (wrongLeafNode /. {wrongLeafNode[[2]] -> newClosingBracket})]
       					,
       					(* UC inside GMC *)
							ReplaceAll[ccp,Extract[gmc, Most@posUC[[1]]] -> ErrorNode[Token`Error`UnexpectedCloser, newClosingBracket, _]]
       				] // ToSourceCharacterString
				;
    			success = 	And[ 	codeFixed =!= FailureQ
									,
									MatchQ[
											SequenceAlignment[code, codeFixed] // DeleteCases[#, _String, {1}] &
											,
											{{wrongClosingBrackets, newClosingBracket}}
									]
									(* //EchoLabel["Diff bracket edit"] *)
        					]
				;
				If[success, Throw[Null]]
				;
    		,
			{iGMCpos, Length@allGMCpos}
			]
			;
  			{ "Success" -> success
   			, "TotalFixes" -> If[success, 1, 0]
   			, "LikelyFalsePositive" -> False
   			, "SafeToEvaluate" -> If[success, True, False]
   			, "FixedPattern" -> pat
   			, "FixedCode" -> codeFixed
   			} // Association
	]


(* FIX PATTERN ----------------------------------------------------------------------- *)

fixPattern[_String, pat_]:=
							{ "Success" -> False
							, "TotalFixes" -> 0
							, "LikelyFalsePositive" -> False
							, "SafeToEvaluate" -> False
							, "FixedPattern" -> pat
							, "FixedCode" -> Missing["Pattern not handled",pat]
							} // Association
(*---------------------------------------------------*)

(* ::Chapter::Closed:: *)
(*End*)

(* :!CodeAnalysis::EndBlock:: *)


(* ::Section::Closed:: *)
(*End Private*)


End[ ];


(* ::Section::Closed:: *)
(*End Package*)


EndPackage[ ];