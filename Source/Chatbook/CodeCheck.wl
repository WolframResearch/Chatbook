(* ::Package:: *)

(* ::Title:: *)
(*Chat code check & fix*)


(* ::Chapter:: *)
(*Init*)


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


CodeCheckFix[code_String]:=
	CodeCheck[code] // {#, CodeFix[code,#], "OriginalCode"->code}& // Association



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

CodeFix[code_String
			 ,kv:KeyValuePattern[{"ErrorsDetected"->True, "CodeInspector"->KeyValuePattern[{"InspectionObjects"->ios_}]}]
			 ,params_:<||>
		]:= fixPattern[code, generatePatternFromCodeCheck[kv]]

CodeFix[code_String
			 ,kv:KeyValuePattern[{"ErrorsDetected"->False}]
			 ,params_:<||>
		]:={"FixedCode"->Missing["No errors detected"]}

generatePatternFromCodeCheck[kv:KeyValuePattern[{"ErrorsDetected"->True, "CodeInspector"->KeyValuePattern[{"InspectionObjects"->ios_}]}]]:=
	 ios // Map[Apply[List]] // #[[All,{3,1}]]& // Sort (* //EchoLabel["CodeInspector pattern"] *)
generatePatternFromCodeCheck[KeyValuePattern[{"ErrorsDetected"->False}]]:={}

(* ::Subsection:: *)
(*Fixes*)

$patternErrorComma={{"Error","Comma"}...};
fixPattern[code_String, pat:$patternErrorComma]:=
	Module[
			{fixedcode, lenpat=Length@pat, ratio, falsepositive=Missing[], safe=Missing[], replaced=False, newpattern=Missing[]}
			,
			(* Echo[pat,"Pattern:"]; *)

			fixedcode =
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

			fixedcode
			// If[FailureQ@#
				 	,	ratio={0,lenpat}
				 	,	(
						CodeCheck[#]
				 		// 	generatePatternFromCodeCheck (* //EchoLabel["Remaining pattern"] *)
				   		// 	Switch[#
				   			  		, {}
							  		, ratio={lenpat,lenpat}; safe=True; falsepositive=False;
							  		(* ----- *)
							  		, $patternErrorComma
									, ratio={lenpat-Length@#,lenpat}
									; containsCommentsQ[fixedcode](* //EchoLabel["contains comments"] *)
									; lengthErrors[replaceCommaComments[fixedcode]](* //EchoLabel["replaced comments length"] *)
										//If[!FailureQ@#(* //EchoLabel["Failure"] *)
											, If[(lenpat-#)>ratio[[1]], safe=False; falsepositive=True; ratio={lenpat-#,lenpat}];
										]&
							 		(* ----- *)
							  		,_ ,newpattern=#(* //EchoLabel["newpattern:"] *); fixedcode=Missing["New pattern after fix",newpattern];
							]&
						)
				]&
			;
			{ "FixedCode"->fixedcode
			, "Success"->(Rational@@ratio === 1)
			, "SuccessRatio"->ratio
			, "LikelyFalsePositive"->falsepositive
			, "SafeToEvaluate"->safe
			}
			(* || (falsepositive=containsCommentsQ[#]), {#,falsepositive}, Missing["Failure","PatternToFix"->pat]]]& *)
	]

replaceCommaComments[code_]:=
	With[
		{ccp=CodeConcreteParse[code]}
		,
		{
		poscomments=Select[
							Position[ccp, LeafNode[Token`Comment,comment_,_]]
							,MatchQ[ccp[[Sequence@@Drop[#,-2]]],ruleCommaComment]&
					]
		}
		,
		ReplaceAt[ccp,LeafNode[Token`Comment,comment_,s_]:>LeafNode[Symbol,"xxxx",s],poscomments] // ToSourceCharacterString
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

lengthErrors[code_]:=CodeCheck[code]//generatePatternFromCodeCheck//Length
lengthErrors[f_Failure]:=f

fixPattern[_String, pat_]:={"FixedCode"->Missing["Pattern not handled",pat],"Success"->False}


containsCommentsQ[s_String]:=StringContainsQ[s,","~~"(*"~~Except["("]~~Except["*"]~~__~~"*)"] (*TEMPORARY BAD TEST!!!!!! *)


(* ::Chapter::Closed:: *)
(*End*)


(* ::Section::Closed:: *)
(*End Private*)


End[ ];


(* ::Section::Closed:: *)
(*End Package*)


EndPackage[ ];
