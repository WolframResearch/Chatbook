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


CodeCheckFix[code_String]:= (
	Needs[ "CodeInspector`" -> None ];
	Needs[ "CodeParser`" -> None ];
	CodeCheck[code] // {#, CodeFix[code,#], "OriginalCode"->code}& // Association
);



(* ::Section:: *)
(*CodeCheck*)


Options[CodeCheck]={"SeverityExclusions" ->{(*(*4/4*)"Fatal", (*3/4*)"Error"*)
												 (*2/4*)"Warning"
												,(*1/4*)"Remark"
												,(*0/4*)"ImplicitTimes","Formatting" ,"Scoping"
												},
						 SourceConvention -> "SourceCharacterIndex"
						};


CodeCheck[code_String, OptionsPattern[]]:=
	(
		 CodeInspect[code, "SeverityExclusions"->OptionValue["SeverityExclusions"]]
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

CodeFix[
		code_String
		,kv:KeyValuePattern[{"ErrorsDetected"->True, "CodeInspector"->KeyValuePattern[{"InspectionObjects"->ios_}]}]
		,params_:<||>
		]:= fixPattern[code, generatePatternFromCodeCheck[kv]]

CodeFix[
		code_String
		,kv:KeyValuePattern[{"ErrorsDetected"->False}]
		,params_:<||>
		]:={"FixedCode"->Missing["No errors detected"]}

generatePatternFromCodeCheck[kv:KeyValuePattern[{"ErrorsDetected"->True, "CodeInspector"->KeyValuePattern[{"InspectionObjects"->ios_}]}]]:=
	 ios // Map[Apply[List]] // #[[All,{3,1}]]& // Sort (* //EchoLabel["CodeInspector pattern"] *)

generatePatternFromCodeCheck[KeyValuePattern[{"ErrorsDetected"->False}]]:={}

(* ::Subsection:: *)
(*Fixes*)

(*---------------------------------------------------*)

fixMixedPatterns[code_String, patList:{{_String, _String}..}]:=
 (Null (*todo*));

$patternErrorCommaFatalExpectedOperand={{"Error", "Comma"}.., {"Fatal", "ExpectedOperand"}..}
fixPattern[code_String, pat:$patternErrorCommaFatalExpectedOperand]:=
	Module[
			{fixComma},
			(* try fix the error comma first*)
			fixComma=fixPattern[code, Cases[pat, {"Error", "Comma"}], (*ignore:*){"Fatal", "ExpectedOperand"}]//Association(* //EchoLabel["Fixed comma"] *);
			If[
					fixComma["Success"]
				,	fixPattern[fixComma["FixedCode"], Cases[pat, {"Fatal", "ExpectedOperand"}]]//Association
				//	mergeFixes[fixComma,#]& (* //EchoLabel["Fixed operand"] *)
				,	fixComma
			]
	]

mergeFixes[a_, b_] :=
	With[{ratio = Plus[a["SuccessRatio"], b["SuccessRatio"]]},
 			{
			"FixedCode" -> b["FixedCode"],
   			"Success" -> (Rational @@ ratio === 1),
   			"SuccessRatio" -> ratio,
  			"LikelyFalsePositive" -> Or[a["LikelyFalsePositive"], b["LikelyFalsePositive"]],
   			"SafeToEvaluate" -> And[a["SafeToEvaluate"], b["SafeToEvaluate"]]
   			}
	]

(*---------------------------------------------------*)

$patternErrorComma={{"Error","Comma"}..};
fixPattern[code_String, pat:$patternErrorComma, patToIgnore_:{}]:=
	Module[
			{fixedCode, lenPat=Length@pat, ratio, falsePositive=Missing[], safe=Missing[], replaced=False, newPattern=Missing[]}
			,
			(* Echo[pat,"Pattern:"]; *)

			fixedCode =
				CodeConcreteParse[code]
				// 	ReplaceRepeated[
						{
							{a___,LeafNode[Token`Comma,",",_],(LeafNode[Whitespace," ",_]...),ErrorNode[Token`Error`InfixImplicitNull,"",_]}
							:>((* Echo["deleting comma"]; *)replaced=True;{a})
							,
							InfixNode[Comma,{a___,LeafNode[Token`Comma,",",_],(LeafNode[Whitespace," ",_]...),ErrorNode[Token`Error`InfixImplicitNull,"",_],LeafNode[Token`Comma,",",_],b__},_]
							:>((* Echo["deleting comma inside"]; *)replaced=True;InfixNode[Comma,{a,LeafNode[Token`Comma,",",_],b},_])
							,
							InfixNode[Comma,{ErrorNode[Token`Error`PrefixImplicitNull,"",_],LeafNode[Token`Comma,",",_],b__},_]
							:>((* Echo["deleting comma start"]; *)replaced=True;InfixNode[Comma,{b},_])
						}
					]
				//	ToSourceCharacterString
			;

			fixedCode
			// If[FailureQ@#
				 	,	ratio={0,lenPat}
				 	,	(
						CodeCheck[#]
				 		// 	generatePatternFromCodeCheck // DeleteCases[patToIgnore]
				   		// 	Switch[#
									(* ############# *)
				   			  		, {}
							  		, ratio={lenPat,lenPat}; safe=True; falsePositive=False;
							  		(* ############# *)
							  		, $patternErrorComma
									, ratio={lenPat-Length@#,lenPat}
									(* ; containsCommentsQ[fixedCode] *)(* //EchoLabel["contains comments"] *)
									; lengthErrors[replaceCommaComments[fixedCode]](* //EchoLabel["replaced comments length"] *)
										//If[!FailureQ@#(* //EchoLabel["Failure"] *)
											, If[(lenPat-#)>ratio[[1]], safe=False; falsePositive=True; ratio={lenPat-#,lenPat}];
										]&
							 		(* ############# *)
							  		,_ ,newPattern=#(* //EchoLabel["newPattern:"] *); fixedCode=Missing["New pattern after fix",newPattern];
							]&
						)
				]&
			;
			{ "FixedCode"->fixedCode
			, "Success"->(Rational@@ratio === 1)
			, "SuccessRatio"->ratio
			, "LikelyFalsePositive"->falsePositive
			, "SafeToEvaluate"->safe
			}
			(* || (falsePositive=containsCommentsQ[#]), {#,falsePositive}, Missing["Failure","PatternToFix"->pat]]]& *)
	]

replaceCommaComments[code_]:=
	With[
		{ccp=CodeConcreteParse[code]}
		,
		{
		posComments=Select[
							Position[ccp, LeafNode[Token`Comment,comment_,_]]
							,MatchQ[ccp[[Sequence@@Drop[#,-2]]],ruleCommaComment]&
					]
		}
		,
		ReplaceAt[ccp,LeafNode[Token`Comment,comment_,s_]:>LeafNode[Symbol,"xxxx",s],posComments] // ToSourceCharacterString
	]

ruleCommaComment=	Alternatives[
							InfixNode[	Comma,{___,LeafNode[Token`Comma,",",_]
										,(LeafNode[Whitespace," ",_]...)
										,LeafNode[Token`Comment,comment_,_]
										,(LeafNode[Whitespace," ",_]...)
										,ErrorNode[Token`Error`InfixImplicitNull,"",_]
										,LeafNode[Token`Comma,",",_],___},_]
							,
							InfixNode[	Comma,{___,LeafNode[Token`Comma,",",_]
										,(LeafNode[Whitespace," ",_]...)
										,LeafNode[Token`Comment,comment_,_]
										,(LeafNode[Whitespace," ",_]...)
										,ErrorNode[Token`Error`InfixImplicitNull,"",_],___},_]
					]

(*---------------------------------------------------*)
$patternFatalExpectedOperand={{"Fatal","ExpectedOperand"}..};
fixPattern[code_String, pat:$patternFatalExpectedOperand, patToIgnore_:{}]:=
	Module[
			{fixedCode=Missing["Expected Operand (no place holder(s) detected)"], lenPat=Length@pat, ratio, falsePositive=Missing[], safe=Missing[]}
			,
			Length@Cases[CodeConcreteParse[code],patExtraOperandEllipsisComment,Infinity]
			//
			If[#===lenPat
				, ratio={lenPat,lenPat}; safe=False; falsePositive=True; fixedCode=code;
				, ratio={#,lenPat};
			]&
			;
			{ "FixedCode"->fixedCode
			, "Success"->(Rational@@ratio === 1)
			, "SuccessRatio"->ratio
			, "LikelyFalsePositive"->falsePositive
			, "SafeToEvaluate"->safe
			}
			(* || (falsePositive=containsCommentsQ[#]), {#,falsePositive}, Missing["Failure","PatternToFix"->pat]]]& *)
	]



patExtraOperandEllipsisComment=
	Alternatives[
			{__,PostfixNode[RepeatedNull,{ErrorNode[Token`Error`ExpectedOperand,"",_],LeafNode[Token`DotDotDot,"...",_]},_],___}
			,
			BinaryNode[_,{__,LeafNode[Token`Comment,_,_],___(* white space and newline mixed*),ErrorNode[Token`Error`ExpectedOperand,"",_]},_]
	]

(*---------------------------------------------------*)

lengthErrors[code_]:=CodeCheck[code]//generatePatternFromCodeCheck//Length
lengthErrors[f_Failure]:=f

fixPattern[_String, pat_]:={"FixedCode"->Missing["Pattern not handled",pat],"Success"->False}


containsCommentsQ[s_String]:=StringContainsQ[s,","~~"(*"~~Except["("]~~Except["*"]~~__~~"*)"] (*TEMPORARY BAD TEST!!!!!! *)


(* ::Chapter::Closed:: *)
(*End*)

(* :!CodeAnalysis::EndBlock:: *)


(* ::Section::Closed:: *)
(*End Private*)


End[ ];


(* ::Section::Closed:: *)
(*End Package*)


EndPackage[ ];