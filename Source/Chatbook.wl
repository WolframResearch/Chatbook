BeginPackage["ConnorGray`Chatbook`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[CreateChatNotebook, "CreateChatNotebook[] creates an empty chat notebook and opens it in the front end."]

GU`SetUsage[$ChatInputPost, "$ChatInputPost is a string that is appended to the end of a chat input."]
GU`SetUsage[$DefaultChatInputPost, "$ChatInputPost is the default value of $ChatInputPost"]


Begin["`Private`"]

(*====================================*)

CreateChatNotebook[] :=
	NotebookPut[
		Notebook[{},
			StyleDefinitions -> Notebook[{
				Cell[StyleData[StyleDefinitions -> "Chatbook.nb"]]
			}]
		]
	]

(*====================================*)

(* This preprompting to wrap code in ``` is necessary for the parsing of code
   blocks into printed output cells to work. *)
$DefaultChatInputPost = "
Wrap any code using ```. Tag code blocks with the name of the programming language.
"

Protect[$DefaultChatInputPost]

$ChatInputPost = $DefaultChatInputPost


End[] (* End `Private` *)

EndPackage[]
