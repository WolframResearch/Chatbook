BeginPackage["ConnorGray`Chatbook`Errors`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[ChatbookError, "ChatbookError represents an error in a Chatbook operation"]

ChatbookWarning

Begin["`Private`"]

Needs["ConnorGray`Chatbook`ErrorUtils`"]

CreateErrorType[ChatbookError, {}]

(*====================================*)

SetFallthroughError[ChatbookWarning]

ChatbookWarning[formatStr_?StringQ, args___] :=
	Print[
		Style["warning: ", Darker[Yellow]],
		ToString @ StringForm[formatStr, args]
	]

End[]

EndPackage[]