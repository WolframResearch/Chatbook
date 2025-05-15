(* ::Package:: *)

(* ::Title:: *)
(*Chat code check*)


BeginPackage["Wolfram`Chatbook`CodeCheck`"];


CheckCodeString


(* ::Section:: *)
(*Begin Private*)


Begin[ "`Private`" ];


Needs["CodeInspector`"]


(* ::Section:: *)
(*CheckCodeString*)


Options[CheckCodeString]={"SeverityExclusions" ->{(*(*4/4*)"Fatal", (*3/4*)"Error"*)
												 (*2/4*)"Warning"
												,(*1/4*)"Remark"
												,(*0/4*)"ImplicitTimes","Formatting" ,"Scoping"
												},
						 SourceConvention -> "SourceCharacterIndex"
						};


CheckCodeString[s_String, OptionsPattern[]]:=(
											 CodeInspect[s, "SeverityExclusions"->OptionValue["SeverityExclusions"]]
											 //{"ErrorsDetected"->#=!={}
											   ,"CodeInspector"	->Association@{"InspectionObjects"->#
											   								 ,"OverallSeverity"->codeInspectOverallSeverityLevel[#]
																			 }
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


(* CheckCodeString["1+f[ ,2]]"]*)


(* ::Subsection:: *)
(*Helpers*)


codeInspectOverallSeverityLevel[ios:{__InspectionObject}]:=ios[[All,3]]//ReplaceAll[ruleCodeInspectSeverityToLevel]//Max


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


(*ruleCodeInspectSeverityLevelToOverallSeverity={4->"4/4", 3->"3/4",2->"2/4",1->"1/4",0->"0/4"};*)


(* ::Section::Closed:: *)
(*End Private*)


End[ ];


(* ::Section::Closed:: *)
(*End Package*)


EndPackage[ ];
