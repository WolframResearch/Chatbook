BeginPackage["Wolfram`OpenAILink`Constants`"];

Begin["`Private`"];

Needs["Wolfram`OpenAILink`"]


(*
	OpenAI requires that API keys are loaded from the OPENAI_API_KEY environment variable by default:
	https://help.openai.com/en/articles/6684216-adding-your-api-client-to-the-community-libraries-page

	SystemCredential is more secure, so that is the top-priority option here.
*)

$OpenAIKey :=
	With[{key = getAPIKey[]},
		If[!MissingQ[key], $OpenAIKey = key, key]
	]

getAPIKey[] :=
	Catch@Module[{key},
		key = SystemCredential["OpenAIAPIKey"];
		If[!MissingQ[key], Throw[key]];

		key = SystemCredential["OPENAI_API_KEY"];
		If[!MissingQ[key], Throw[key]];

		key = Environment["OPENAI_API_KEY"];
		Replace[key, $Failed -> Missing["NoOpenAIAPIKey"]]
	]


(*
	The parameter to be passed to the "user" field for identifying end-users. Only needs to be specified
	for tracking end-user usage and is ignored if given None.
*)

$OpenAIUser = None;


End[];
EndPackage[];
