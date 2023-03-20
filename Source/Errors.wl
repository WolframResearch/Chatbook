BeginPackage["ConnorGray`Chatbook`Errors`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[ChatbookError, "ChatbookError represents an error in a Chatbook operation"]

Begin["`Private`"]

Needs["ConnorGray`Chatbook`ErrorUtils`"]

CreateErrorType[ChatbookError, {}]


End[]

EndPackage[]