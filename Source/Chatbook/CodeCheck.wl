(* ::Package:: *)

(* ::Title:: *)
(*Chat code check*)


BeginPackage["Wolfram`Chatbook`CodeCheck`"];


CheckCodeString
CheckCodeChat


(* ::Section:: *)
(*Begin Private*)


Begin[ "`Private`" ];


Needs["CodeInspector`"]


(* ::Section:: *)
(*CheckCodeChat*)


CheckCodeChat[chat_String]:=extractWLcodeFromString[chat]//Map[CheckCodeString]


(* Returns:
{
	<|
	"ErrorsDetected" -> True | False
	"CodeInspector"  -> {___InspectionObject}
	|>,
	<|
	"ErrorsDetected" -> True | False
	"CodeInspector"  -> {___InspectionObject}
	|>,
	...
*)


(* ::Subsection:: *)
(*Helpers*)


extractWLcodeFromString[stringcode_String]:=StringCases[stringcode,StringExpression["```wl",Shortest[code__],"```"]:>code]


(* ::Section:: *)
(*CheckCodeString*)


Options[CheckCodeString]={"SeverityExclusions" ->{(*(*4/4*)"Fatal", (*3/4*)"Error"*)
												 (*2/4*)"Warning"
												,(*1/4*)"Remark"
												,(*0/4*)"ImplicitTimes","Formatting" ,"Scoping"
												},
						 SourceConvention -> "SourceCharacterIndex"
						};


CheckCodeString[s_String, OptionsPattern[]]:=CodeInspect[s, "SeverityExclusions" -> OptionValue["SeverityExclusions"]]//
											{"ErrorsDetected"->#=!={},"CodeInspector"->#}& //
											Association


CheckCodeString[___]:= <|"ErrorsDetected" -> False, "CodeInspector"->{}|>


(* Returns:
<|
"ErrorsDetected" -> True | False
"CodeInspector"  -> {___InspectionObject}
|>
*)


(* CheckCodeString["1+f[ ,2]]"] *)


(* ::Section:: *)
(*CheckCodeString2*)


Options[CheckCodeString2]=Options[CheckCodeString];


CheckCodeString2[s_String, OptionsPattern[]]:=(
											 CodeInspect[s, "SeverityExclusions"->OptionValue["SeverityExclusions"]]
											 //{"ErrorsDetected"->#=!={}
											   ,"CodeInspector"->Association@{"InspectionObjects"->#,"OverallSeverity"->codeInspectOverallSeverityLevel[#]}
											   }&
											 // Association
											 )


(* Returns:
<|
"ErrorsDetected" -> True | False
"CodeInspector"  -> (* {___InspectionObject} *)
					<|
						"InspectionObjects" -> {___InspectionObject},
						"OverallSeverity"\[Rule] "4/4" | "3/4" | "2/4" | "1/4"
					|>
|>
*)


(* CheckCodeString2["1+f[ ,2]]"]*)


(* ::Subsection:: *)
(*Helpers*)


codeInspectOverallSeverityLevel[ios:{__InspectionObject}]:=ios[[All,3]]//ReplaceAll[ruleCodeInspectSeverityToLevel]//Max//Replace[ruleCodeInspectSeverityLevelToOverallSeverity]


codeInspectOverallSeverityLevel[{}]:=None


(* ::Text:: *)
(*from CodeInspector/ Kernel/ Utils.wl:*)
(*severityToInteger["ImplicitTimes" | "Formatting" | "Scoping"] = 0*)
(*severityToInteger["Remark"] = 1*)
(*severityToInteger["Warning"] = 2*)
(*severityToInteger["Error"] = 3*)
(*severityToInteger["Fatal"] = 4*)
(**)


ruleCodeInspectSeverityToLevel={"Fatal"->4,"Error"->3,"Warning"->2,"Remark"->1,"ImplicitTimes"|"Formatting"|"Scoping"->0};


ruleCodeInspectSeverityLevelToOverallSeverity={4->"4/4", 3->"3/4",2->"2/4",1->"1/4",0->"0/4"};


(* ::Section::Closed:: *)
(*End Private*)


End[ ];


(* ::Section::Closed:: *)
(*End Package*)


EndPackage[ ];
