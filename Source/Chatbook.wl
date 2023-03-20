BeginPackage["ConnorGray`Chatbook`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[CreateChatNotebook, "CreateChatNotebook[] creates an empty chat notebook and opens it in the front end."]

GU`SetUsage[$ChatSystemPre, "
$ChatSystemPre is a string that is prepended to the beginning of a chat input as the \"system\" role.

Overriding this value may cause some Chatbook functionality to behave unexpectedly.
"]
(* TODO: Rename this to $ChatUserPost *)
GU`SetUsage[$ChatInputPost, "$ChatInputPost is a string that is appended to the end of a chat input."]

GU`SetUsage[$DefaultChatSystemPre, "$DefaultChatSystemPre is the default value of $ChatSystemPre"]
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
$DefaultChatSystemPre = "
Wrap any code using ```. Tag code blocks with the name of the programming language.
"

$DefaultChatInputPost = ""

Protect[{$DefaultChatSystemPre, $DefaultChatInputPost}]

$ChatSystemPre = $DefaultChatSystemPre
$ChatInputPost = $DefaultChatInputPost


End[] (* End `Private` *)

EndPackage[]
