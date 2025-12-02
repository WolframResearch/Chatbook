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


(*Syntax informations to check System functions arguments*)
$syntargs := $syntargs = 	{Import[PacletObject["Wolfram/Chatbook"]["AssetLocation", "SyntaxInformation"], "WXF"]
							(*temporarily adding missing info from SyntaxInformation*)
							,"With" -> {__}
							,"EchoLabel" -> {_}
							,"EchoFunction"->{_,_:""}
							} // Association

$systemOptions := $systemOptions = Import[PacletObject["Wolfram/Chatbook"]["AssetLocation", "SyntaxOptions"], "WXF"]

$FixRecursionLimit=10;

(*Possible targets*)
$AssistantPattern="Assistant";
$EvaluatorPattern="Evaluator";

Options[CodeCheckFix] = {"Target"->$AssistantPattern}

CodeCheckFix[code_String, OptionsPattern[]]:= (
	Needs[ "CodeInspector`" -> None ];
	Needs[ "CodeParser`" -> None ];
	Block[{niter=0, recursionLimit=$FixRecursionLimit, $target=OptionValue["Target"]},
	CodeCheck[$target][code] // {#
								,
								CodeFix[$target][code,#]
								,
								"OriginalCode"->code
								}&
	]
	// Association
)

(* ::Section:: *)
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
										}
					,
					SourceConvention -> "SourceCharacterIndex"
					,
					"AbstractRules" -> <|
										pSingleSnakeInSet -> scanSingleSnakeInSet (* detect bad single snake usage inside Set *),
										pMultiSnake -> scanMultiSnake (* detect bad multiple snake usage anywhere *)
										|>
						};


CodeCheck[target_][code_String, OptionsPattern[]]:=
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

CodeFix[target_][
		code_String
		,kvCI:KeyValuePattern[{"ErrorsDetected"->True, "CodeInspector"->_}]
		,params_:<||>
		]:=
		CodeFix[target][{}, fixPattern[target][code, generatePatternFromCodeCheck[kvCI]//EchoLabel["generatePatternFromCodeCheck"]]]

CodeFix[target_][
		code_String
		,kvCI:KeyValuePattern[{"ErrorsDetected"->False}]
		,params_:<||>
		]:= {"FixedCode"->Missing["No errors detected"]}


CodeFix[target_][kvFixPrev_, kvFixNew:KeyValuePattern[{"Success"->True|False}]]:=
	With[{merged=mergeFixes[kvFixPrev, kvFixNew]},
		If[	MatchQ[	kvFixNew	,Alternatives[	 KeyValuePattern[{"Success"->False}]
												,KeyValuePattern[{"Success"->True, "LikelyFalsePositive"->True}]
												,KeyValuePattern[{"Success"->True, "FixedCode"->_Missing}]]
			]
			,
			merged
			,
			generatePatternFromCodeCheck@CodeCheck[target][merged["FixedCode"]]
			//	If[	 niter > recursionLimit
					,
					{merged, "Success"->False, "RecursionLimitExceeded"->True}
					,
					If[#==={}, merged, (niter++; CodeFix[target][merged, fixPattern[target][merged["FixedCode"],#]])]
				]&
		]
	]

generatePatternFromCodeCheck[kv:KeyValuePattern[{"ErrorsDetected"->True, "CodeInspector"->KeyValuePattern[{"InspectionObjects"->ios_}]}]]:=
	 ios // Map[extractPatternFromInspectionObject] // Sort

generatePatternFromCodeCheck[KeyValuePattern[{"ErrorsDetected"->False}]]:={}

extractPatternFromInspectionObject[io:InspectionObject["BadSetSnakeUsage"|"BadSnakeUsage",__]]:=Apply[Sequence,io]//({#3,#1}->#4[Source])&
extractPatternFromInspectionObject[io_]:=Apply[Sequence,io]//{#3,#1}&

lengthErrors[code_]:=CodeCheck[$target][code]//generatePatternFromCodeCheck//Length
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
	} // Flatten // Association
(* ::Subsection:: *)
(*Fixes*)

(* FIX PATTERN ----------------------------------------------------------------------- *)

$patternErrorCommaFatalExpectedOperand={{"Error", "Comma"}.., {"Fatal", "ExpectedOperand"}..}
fixPattern[target_][code_String, pat:$patternErrorCommaFatalExpectedOperand]:=
	(* try fix the error comma first*)
		fixPattern[target][code, Cases[pat, {"Error", "Comma"}], (*ignore:*){"Fatal", "ExpectedOperand"}]

(* FIX PATTERN ----------------------------------------------------------------------- *)
$patternErrorComma={{"Error","Comma"}..};
fixPattern[target_][code_String, pat:$patternErrorComma, patToIgnore_:{}]:=
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
fixPattern[target_][code_String, pat:$patternFatalExpectedOperand, patToIgnore_:{}]:=
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

fixPattern[target_][code_String, pat:$patternFatalExpectedOperandFatalOpenSquare, patToIgnore_:{}]:=
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

fixPattern[target_][code_String, pat : $patternFatalGroupMissingCloserFatalUnexpectedCloser, patToIgnore_ : {}] :=
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
    			success = 	And[ 	Not@FailureQ@codeFixed
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
$patternFatalUnexpectedCloser = {___, {"Fatal", "UnexpectedCloser"}, ___};

fixPattern[$EvaluatorPattern][code_String, pat : $patternFatalUnexpectedCloser, patToIgnore_ : {}] :=
	Module[{success,fixedCode,allCodeScore,allCodeNoScore},
	With[
		{
		ccp=CodeConcreteParse[code,SourceConvention->"SourceCharacterIndex"],
		codetoken=CodeTokenize[code,SourceConvention->"SourceCharacterIndex"]
		}
		,
		{errorNode=Cases[ccp,f_[___,Token`Error`UnexpectedCloser,___],Infinity]//If[MatchQ[#,{__}],First@#,{}]&}
		,
		{bracket=errorNode[[2]]}
		,
		{allbrackets=Cases[codetoken,LeafNode[_,bracket,so_]:>so]//Select[#[[1,2]]<=errorNode[[3,1,1]]&]}
		,
		{
		excludedRanges=Cases[ccp,GroupNode[Except[bracket/.{"]"->GroupSquare,")"->GroupParen,"}"->List},_],_,so_]:>so,Infinity]
						//Select[#[[1,2]]<errorNode[[3,1,1]]&]}
		,
		{
		finalBrackets=Select[allbrackets, Not[Or@@IntervalMemberQ[Map[Interval@#[Source]&,excludedRanges],#[[1,1]]]]&]
		}
		,
		fixedCode=
					Map[(DeleteCases[codetoken,LeafNode[_,bracket,#]]//Map[ToSourceCharacterString]//StringJoin)&,finalBrackets]
					//
					DeleteDuplicates // dechofunction["Number of possible fixes",Length]
					//
					Reverse // (allCodeNoScore=#)&
					//
					(allCodeScore=scoreAndSort[#])& (*Adding scores*)
					//
					SelectFirst[#,CodeInspect[#[[2]], Sequence@@Options[CodeCheck]]==={}&, {Missing["No valid fix"]} ]&//
					decholabel["final fix:"]//
					Last

		;success=If[MissingQ@fixedCode,False,True]
		;
		{ "Success" -> success
		, "TotalFixes" -> If[success, 1, 0]
		, "LikelyFalsePositive" -> If[success, False, True]
		, "SafeToEvaluate" -> If[success, True, False]
		, "FixedPattern" -> pat
		, "FixedCode" -> fixedCode
		, If[TrueQ@Wolfram`Chatbook`CodeCheck`$CodeCheckDebug,
			{"AllCodeScore" -> Iconize@allCodeScore, "AllCodeNoScore" -> Iconize@allCodeNoScore},{}]
		} // Flatten // Association
]]


(* FIX PATTERN ----------------------------------------------------------------------- *)
$patternFatalGroupMissingCloser = {___, {"Fatal", "GroupMissingCloser"}, ___};

fixPattern[$EvaluatorPattern][code_String, pat : $patternFatalGroupMissingCloser, patToIgnore_ : {}] :=
	Module[	{
			 fixedCode=Missing[]
			,success=False
			,finalgnso
			,allCodeScore
			,allCodeNoScore
			}
			,
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
					Cases[#, _GroupMissingCloserNode,Infinity]&//dechofunction["Number of GMCs:", Length]//First
			}
			,
			{
			gnsoSameType=	gmcn//
							ReplaceAll[GroupNode[Except[missingBracketType,_],__]:>Nothing]//
							Cases[#,GroupNode[missingBracketType,__,so_]:>so,Infinity]&,

			gnsoOtherType=	gmcn//
							ReplaceAll[GroupNode[t_,__,Except[<|Source->{_,gmcn[[-1,-1,-1]]}|>,so_]]:>{"get",t,so}]//
							Cases[#,{"get",Except[missingBracketType,t_],so_}:>so,Infinity]&
			}
			,
			finalgnso = Join[gnsoOtherType, gnsoSameType]//If[#==={}, {gmcn[[3]]}, #]&;

			fixedCode=	Map[
							(
								StringInsert[ codeF
											, gmcn[[1]] /. {GroupSquare -> "]", GroupParen -> ")", List -> "}"}
											, #[[ -1, -1]] + 1
											] //
								StringTake[#,{2+If[MatchQ[missingBracketType,List|GroupParen],1,0],-2}] &
							)&
							, finalgnso
							]//
						DeleteDuplicates // dechofunction["Number of possible fixes",Length] //
						Reverse // (allCodeNoScore=#)& //
						(allCodeScore=scoreAndSort[#])&//  (*Adding scores*)
						SelectFirst[#,CodeInspect[#[[2]], Sequence@@Options[CodeCheck]]==={}&, {Missing["No valid fix"]} ]&//
						decholabel["final fix:"]//
						Last

			;success=If[MissingQ@fixedCode,False,True]
			;
			{ "Success" -> success
			, "TotalFixes" -> If[success, 1, 0]
			, "LikelyFalsePositive" -> If[success, False, True]
			, "SafeToEvaluate" -> If[success, True, False]
			, "FixedPattern" -> pat
			, "FixedCode" -> fixedCode
			, If[TrueQ@Wolfram`Chatbook`CodeCheck`$CodeCheckDebug,
				{"AllCodeScore" -> Iconize@allCodeScore, "AllCodeNoScore" -> Iconize@allCodeNoScore},{}]
			} // Flatten // Association
	]]


scoreAndSort[codes:{_String..}]:=Map[{scoreArgs@#,#}&,codes]//ReverseSortBy[{First}]

scoreArgs[code_String]:=Cases[CodeConcreteParse[code//EchoLabel["fixed code to score:"]], CallNode[List@LeafNode[_, funcname_, _], _, _], {0, Infinity}] //
						scoreArgsCallNode

scoreArgsCallNode[cn:{_CallNode..}]:=scoreArgsCallNode/@cn //dechofunction["callnodes subscores:",{#,Total@#}&]//Total
scoreArgsCallNode[cn_CallNode]:=$syntargs[funcNameCallNode[cn]//EchoLabel["function:"]]//EchoLabel["syntargs"]//
								If[MissingQ@#, Nothing, scoreArgsPattern[argsCallNode@cn,#, funcNameCallNode[cn]]]&//
								If[#===0,decho[funcNameCallNode[cn],"Score: failed match:"];#,#]&

(* scoreArgsPattern[expr:{___,Rule..}, pattern:{___,Verbatim[Rule...]}]:=
	Block[{$rules,$whole},
			With[
				{
					pattRules=	(pattern /. { Verbatim[Rule...]	:>Pattern[$rules, Rule...]
										  	, Verbatim[_:"def"] :>Optional[Except[Rule, _], "def"]
										  	} //Pattern[$whole,#]&
								):> {$whole,Length@{$rules}}
				},
				Cases[expr,pattRules,{0}]]//
				ReplaceAll[{{}->0,{{_,len_}}:>1+len/4.}]] *)

scoreArgsPattern[expr:{___,_Rule..},pattern:{___,Verbatim[Rule...]}, funcname_String]:=
	Block[{$rules,$whole},
			With[
				{pattRules= (pattern/. 	{Verbatim[Rule...]:>Pattern[$rules,_Rule...]
										,Verbatim[_:"def"]:>Optional[Except[_Rule,_],"def"]
										}//Pattern[$whole,#]&
							):>{$whole,{$rules}//Map[Last]//EchoLabel["scoreArgsPattern"]//Select[MemberQ[$systemOptions[funcname],#]&]//Length}
				}
				,
				Cases[expr,pattRules,{0}]] // ReplaceAll[{{}->0,{{_,len_}}:>1+len/4.}]]


scoreArgsPattern[expr_, pattern_, _]:= MatchQ[expr, pattern]//Boole

argsCallNode[CallNode[_,GroupNode[GroupSquare,{LeafNode[Token`OpenSquare,"[",so_],___, InfixNode[Comma, a_List, _], __},_],_]]:= argsCallNode[a]

argsCallNode[CallNode[_,GroupNode[GroupSquare,{LeafNode[Token`OpenSquare,"[",so_],a___,LeafNode[Token`CloseSquare,"]",_]},_],_]]:= argsCallNode[{a}]

(* argsCallNode[args_List]:=
(
	args
	//
	DeleteCases[#,LeafNode[Token`Comma|Whitespace|Token`Newline|Token`Comment,__],Infinity]&
	//
	Replace[#,{BinaryNode[Rule|RuleDelayed,{_,_,_},_]->Rule} ,Infinity]&
	//
	Replace[#,GroupNode[List,{LeafNode[Token`OpenCurly,"{",_],Rule,LeafNode[Token`CloseCurly,"}",_]},_]:>Rule,Infinity]&
	//
	Replace[#,Except[Rule,_]->"arg",Infinity]&
) *)

argsCallNode[args_List]:=
(
	args
	//
	DeleteCases[#, LeafNode[Token`Comma | Whitespace | Token`Newline| Token`Comment, __], Infinity]&
	//
	Replace[#, {BinaryNode[Rule | RuleDelayed, {LeafNode[_,optname_,_], _, _}, _] :> (Rule->optname)}, Infinity]&
	//
	Replace[#, GroupNode[List, {
								  LeafNode[Token`OpenCurly, "{", _]
								, opt_Rule
								, LeafNode[Token`CloseCurly, "}", _]
								}
							,
							_
						]
						:> opt ,Infinity]&
	//
	Replace[#,GroupNode[List,	{
								  LeafNode[Token`OpenCurly,"{",_]
								, InfixNode[Comma,{r:(Rule->_)..},_]
								, LeafNode[Token`CloseCurly,"}",_]
								}
							,_
						]
						:> r, {1}]&
	//
	Replace[#, Except[_Rule, _] -> "arg", {1}]&
	//EchoLabel["argsCallNode"]
)

funcNameCallNode[CallNode[{LeafNode[_,funcname_,_]}, _,_]]=funcname;

(*---------------------------------------------------*)

checkFunctionsSyntax[code_String]:=
	Module[{cpp=CodeConcreteParse[code]},
		code//
		CodeParse//
		Cases[#,CallNode[LeafNode[_,funcname_,_], _,_],{0,Infinity}]&//
		Map[If[scoreArgsCallNodeCP[#]===False,#,Nothing]&]//
		ReplaceAll[CallNode[_,_,so_]:>so]//decholabel["all so:"]//
		dechofunction["Number of syntax problems found:", Length]//
		Map[(Cases[cpp, cn:Alternatives[
							_[{LeafNode[Symbol,funcname_String,_]},_,#],
							_[_,{LeafNode[Symbol,funcname_String,_], ___},#], 	(*BinaryNode*)
							_[funcname_,_,#]									(*BinaryNode*)
						]:>{funcname,ToSourceCharacterString@cn},Infinity]//
			First)&]
	]

scoreArgsCallNodeCP[cn:{_CallNode..}]:=scoreArgsCallNodeCP/@cn //Total
scoreArgsCallNodeCP[cn_CallNode]:=checkArgsCallNodeCP[cn]
checkArgsCallNodeCP[cn_CallNode]:=$syntargs@funcNameCallNodeCP[cn]//If[MissingQ@#,Null,MatchQ[argsCallNodeCP@cn,#]]&

argsCallNodeCP[CallNode[LeafNode[Symbol,funcname_,_],args_List,_]]:=
	Replace[args,CallNode[LeafNode[Symbol,"List",_],a_List,_]:>a,Infinity]//
	Replace[#,CallNode[LeafNode[Symbol,"Rule"|"RuleDelayed",_],__]:>Rule,Infinity]&//
	Replace[#,{Rule}:>Rule,Infinity]&//
	Replace[#,{a__,CallNode[LeafNode[Symbol, "BlankNullSequence", <||>], {}, _]}:>{a,Rule}]&//
	Replace[#,Except[Rule,_]->"arg",Infinity]&;

funcNameCallNodeCP[CallNode[LeafNode[Symbol,funcname_,_],_,_]]=funcname


(* FIX PATTERN ----------------------------------------------------------------------- *)
$patternBadSetSnakeUsage = {___, {"Fatal", "BadSetSnakeUsage"}->_, ___};

fixPattern[target_][code_String, pat : {___, {"Fatal", "BadSetSnakeUsage"}->so_, ___}, patToIgnore_ : {}] :=
	Module[	{
			 fixedCode=Missing[]
			,success=False
			,finalgnso
			}
			,
			Echo["FIX BadSetSnakeUsage "];
			With[
				{
				ccp = CodeConcreteParse[code,SourceConvention->"SourceCharacterIndex"]
				}
				,
				{
				nodeCCP = FirstCase[ccp, _[_, _, <|Source -> so|>], Missing[], Infinity]
				}
				,
				{
				newName = 	Cases[nodeCCP, _String, Infinity] //
							ReplaceRepeated[{a___, PatternSequence["_" | "__" | "___", x_String], b___} :> {a, Capitalize[x], b}] //
							StringJoin
				}
				,
				fixedCode=ReplaceAll[ccp, (nodeCCP /. _Association -> _) -> LeafNode[Symbol, newName, <||>]] // ToSourceCharacterString
			]
			;success=If[FailureQ@fixedCode,False,True]
			;
			{ "Success" -> success
			, "TotalFixes" -> If[success, 1, 0]
			, "LikelyFalsePositive" -> If[success, False, True]
			, "SafeToEvaluate" -> If[success, True, False]
			, "FixedPattern" -> pat
			, "FixedCode" -> fixedCode
			} // Flatten // Association

	]



(* BAD SNAKE USAGE*)
pSingleSnakeInSet=
	Alternatives[
				CallNode[LeafNode[Symbol,"Set",<||>],{CallNode[LeafNode[Symbol,"Pattern",<||>],{LeafNode[Symbol,_,_],CallNode[LeafNode[Symbol,"Blank"|"BlankSequence"|"BlankNullSequence",<||>],{LeafNode[Symbol,_,_]},_]},_],__},_]
				,
				CallNode[LeafNode[Symbol,"Set",<||>],{CallNode[LeafNode[Symbol,"Times",<||>],{CallNode[LeafNode[Symbol,"Pattern",<||>],{LeafNode[Symbol,_,_],CallNode[LeafNode[Symbol,"Blank"|"BlankSequence"|"BlankNullSequence",<||>],{},_]},_],LeafNode[Integer,_,_]},_],__},_]
				,
				CallNode[LeafNode[Symbol,"Set",<||>],{CallNode[LeafNode[Symbol,"Times",<||>],{CallNode[LeafNode[Symbol,"Pattern",<||>],{LeafNode[Symbol,_,_],CallNode[LeafNode[Symbol,"Blank"|"BlankSequence"|"BlankNullSequence",<||>],{},_]},_],LeafNode[Integer,_,_],LeafNode[Symbol,_,_]},_],__},_]
	]

scanSingleSnakeInSet // ClearAll;
scanSingleSnakeInSet[pos_, ast_] :=
(
  	Echo["SET BAD SNAKE"];
  	If[
		Extract[ast,Flatten[{pos, 2, 1, 2}]] //
					Cases[#, (LeafNode | CallNode)[__, <|Source -> {s1_, s2_}|>] :> {s1-1, s2}, {1}] & //
					BlockMap[#[[1, 2]] === #[[2, 1]] &, #, 2, 1] & //
					Replace[{}->{False}]//Apply[And] // TrueQ
		,
   		CodeInspector`InspectionObject["BadSetSnakeUsage","Bad Snake Usage", "Fatal",
										Association@{ConfidenceLevel -> 1,Extract[ast, Join[pos, {2, 1, -1}]]}]
		,
   		Nothing
   ]
)
(* -------- *)
$patternBadSnakeUsage = {___, {"Fatal", "BadSnakeUsage"}->_, ___};

fixPattern[target_][code_String, pat : {___, {"Fatal", "BadSnakeUsage"}->so_, ___}, patToIgnore_ : {}] :=
	Module[	{
			 fixedCode=Missing[]
			,success=True
			,finalgnso
			}
			,
			Echo["FIX BadSnakeUsage "];
			With[
				{
				ccp = CodeConcreteParse[code,SourceConvention->"SourceCharacterIndex"]
				}
				,
				{
				nodeCCP =FirstCase[ccp, _[_, _, <|Source -> so|>], Missing[], Infinity]
				}
				,
				{
				newNode = 	Cases[nodeCCP, _LeafNode, Infinity] //
							Replace[{pMulti : Longest@PatternSequence[LeafNode[Except[Token`Comment | Whitespace], __] ..], r___} :>
									{Cases[{pMulti}, _String, {2}] //
							ReplaceRepeated[{a___, PatternSequence["_" | "__" | "___", x_String], b___} :> {a, Capitalize[x], b}] // StringJoin //
							LeafNode[Symbol, #, <||>] &, r}] // InfixNode[Times, #, _] &
				}
				,
				fixedCode=ccp /. (nodeCCP /. _Association->_) -> newNode // ToSourceCharacterString
			]
			;success=If[FailureQ@fixedCode,False,True]
			;
			{ "Success" -> success
			, "TotalFixes" -> If[success, 1, 0]
			, "LikelyFalsePositive" -> If[success, False, True]
			, "SafeToEvaluate" -> If[success, True, False]
			, "FixedPattern" -> pat
			, "FixedCode" -> fixedCode
			} // Flatten // Association

	]

pMultiSnake=
	CallNode[LeafNode[Symbol, "Times", _]
    		,
    		{
          	CallNode[LeafNode[Symbol, "Pattern", <||>],{LeafNode[Symbol, _, _]
													   ,CallNode[LeafNode[Symbol, "Blank" | "BlankSequence" | "BlankNullSequence",<||>],{},_ ]
													   },_]|
			CallNode[LeafNode[Symbol, "Pattern", <||>],{ LeafNode[Symbol, _, _]
														,CallNode[LeafNode[Symbol, "Blank" | "BlankSequence" | "BlankNullSequence",<||>],{LeafNode[Symbol, _, _]},_]},_]
        	,
          	(
                CallNode[LeafNode[Symbol, "Pattern", <||>],{ LeafNode[Symbol, _, _]
															,CallNode[LeafNode[Symbol, "Blank" | "BlankSequence" | "BlankNullSequence",<||>],{LeafNode[Symbol, _, _]},_]},_]|
				LeafNode[Integer, _, _] |
				CallNode[LeafNode[Symbol, "Blank" | "BlankSequence" | "BlankNullSequence",<||>],{},_] |
				CallNode[LeafNode[Symbol, "Blank" | "BlankSequence" | "BlankNullSequence",<||>],{LeafNode[Symbol, _, _]},_] |
				LeafNode[Symbol, _, _]
            ) ..
  			}
     		,_
	]
pMultiSnake2=
	CallNode[LeafNode[Symbol, "Times", _]
    		,
    		{
          	CallNode[LeafNode[Symbol, "Pattern", <||>],{LeafNode[Symbol, _, _]
													   ,CallNode[LeafNode[Symbol, "Blank" | "BlankSequence" | "BlankNullSequence",<||>]
													   			, {} | {LeafNode[Symbol, _, _]} ,_ ]
													   },_]
        	,
          	(
          	CallNode[LeafNode[Symbol, "Pattern", <||>],{LeafNode[Symbol, _, _]
													   ,CallNode[LeafNode[Symbol, "Blank" | "BlankSequence" | "BlankNullSequence",<||>]
													   			, {} | {LeafNode[Symbol, _, _]} ,_ ]
													   },_] |
			LeafNode[Integer | Symbol , _, _] |
			CallNode[LeafNode[Symbol, "Blank" | "BlankSequence" | "BlankNullSequence",<||>],{} | {LeafNode[Symbol, _, _]},_]
            ) ..
  			}
     		,_
	]

pFalsePositiveMulti=CallNode[LeafNode[Symbol, "Times", <||>], {_, LeafNode[Symbol | Integer, _, _] ..}, _]
PTruePositiveSingle=
	CallNode[LeafNode[Symbol, "Times", _]
    		,
    		{
          	CallNode[LeafNode[Symbol, "Pattern", <||>],{LeafNode[Symbol, _, _]
													   ,CallNode[LeafNode[Symbol, "Blank" | "BlankSequence" | "BlankNullSequence",<||>],{},_ ]
													   }
													   ,<|Source -> {_, x_}|>]
			,
			LeafNode[Integer, _, <|Source -> {y_, _}|>]
			,___
			}
			,_
	] /; (x+1==y)
scanMultiSnake // ClearAll;
scanMultiSnake[pos_, ast_] :=
(
    Echo["BAD MULTI SNAKE"];
    Extract[ast, pos]//If[Not@MatchQ[#,PTruePositiveSingle] && MatchQ[#, pFalsePositiveMulti]
   		,Echo["Rejected!"]; Nothing(* CodeInspector`InspectionObject["TagTimesInSet", "Tag Times Protected","Fatal",#]& *)
		,CodeInspector`InspectionObject["BadSnakeUsage", "Bad Snake Usage","Fatal",
			Association@{ConfidenceLevel -> 1, Extract[ast, Join[pos, {-1}]]}]]&
);

(* FIX PATTERN ----------------------------------------------------------------------- *)

fixPattern[target_][_String, pat_]:=
							{ "Success" -> False
							, "TotalFixes" -> 0
							, "LikelyFalsePositive" -> False
							, "SafeToEvaluate" -> False
							, "FixedPattern" -> pat
							, "FixedCode" -> Missing["Pattern not handled",pat]
							} // Association

(* ----------------------------------------------------------------------------------- *)


(*------- For debugging*)
decho[x_,mess___]:=If[TrueQ[Wolfram`Chatbook`CodeCheck`$CodeCheckDebug],Echo[x, mess], x]

decholabel[mess_String][x_]:=If[TrueQ[Wolfram`Chatbook`CodeCheck`$CodeCheckDebug],EchoLabel[mess][x],x]

dechofunction[a__][b_]:=If[TrueQ[Wolfram`Chatbook`CodeCheck`$CodeCheckDebug],EchoFunction[a][b],b]

Wolfram`Chatbook`CodeCheck`$CodeCheckDebug=False

(* ::Chapter::Closed:: *)
(*End*)

(* :!CodeAnalysis::EndBlock:: *)


(* ::Section::Closed:: *)
(*End Private*)

ifn = $InputFileName
End[ ];


(* ::Section::Closed:: *)
(*End Package*)


EndPackage[ ];