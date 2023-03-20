BeginPackage["ConnorGray`Chatbook`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[CreateChatNotebook, "CreateChatNotebook[] creates an empty chat notebook and opens it in the front end."]


Begin["`Private`"]


CreateChatNotebook[] :=
	NotebookPut[
		Notebook[{},
			StyleDefinitions -> Notebook[{
				Cell[StyleData[StyleDefinitions -> "Chatbook.nb"]]
			}]
		]
	]


End[] (* End `Private` *)

EndPackage[]
