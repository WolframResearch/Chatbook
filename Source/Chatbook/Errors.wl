BeginPackage["Wolfram`Chatbook`Errors`"]

Needs["GeneralUtilities`" -> None]

GeneralUtilities`SetUsage[ChatbookError, "ChatbookError represents an error in a Chatbook operation"]

ChatbookWarning

Begin["`Private`"]

Needs["Wolfram`Chatbook`ErrorUtils`"]

CreateErrorType[ChatbookError, {}]

(*====================================*)

SetFallthroughError[ChatbookWarning]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
ChatbookWarning[formatStr_?StringQ, args___] :=
	Print[
		Style["warning: ", Darker[Yellow]],
		ToString @ StringForm[formatStr, args]
	]
(* :!CodeAnalysis::EndBlock:: *)

End[]

EndPackage[]