BeginPackage["Wolfram`LLMTools`OpenAILink`Files`"];

CreateOpenAIFile

Begin["`Private`"];

Needs["Wolfram`LLMTools`OpenAILink`"]
Needs["Wolfram`LLMTools`OpenAILink`Constants`"]
Needs["Wolfram`LLMTools`OpenAILink`Request`"]



$purposeReplacements = {
	"fine-tune" -> "FineTuning"
};



(***********************************************************************************)
(********************************* File operations *********************************)
(***********************************************************************************)


(*
	OpenAIFileUpload[file, purpose]
		uploads a file to the OpenAI servers with the specified purpose.
*)

Options[OpenAIFileUpload] = {
	OpenAIKey  :> $OpenAIKey,
	OpenAIUser :> $OpenAIUser
};

OpenAIFileUpload[file_, purpose_, opts:OptionsPattern[]] :=
	Enclose[
	With[{apiKey = OptionValue[OpenAIFileUpload, opts, OpenAIKey]},

		ConfirmBy[apiKey, StringQ,
			Message[OpenAIFileUpload::invalidOpenAIAPIKey, apiKey];
			Failure["InvalidOpenAIKey", <|
				"MessageTemplace" :> OpenAIFileUpload::invalidOpenAIAPIKey.
				"MessageParameters" -> {apiKey}
			|>]
		];

		conformUploadResponse[
			Confirm@URLRead[
				<|
					"Scheme" -> "https",
					"Domain" -> "api.openai.com",
					"Method" -> "POST",
					"Path" -> {"v1", "files"},
					"Body" -> {
							"file" -> File[ExpandFileName[file]],
							"purpose" -> Replace[purpose, Reverse/@$purposeReplacements]
						},
					"Headers" -> {
						"Authorization" -> "Bearer " <> apiKey
					}
				|>
			]
		]

	],
	"InheritedFailure"]


conformUploadResponse[data_] :=
	Enclose[CreateOpenAIFile@Confirm@ConformResponse[OpenAIFileUpload, data], "InheritedFailure"]



(*
	OpenAIFileDelete[file]
		deletes and OpenAIFile object.
*)

Options[OpenAIFileDelete] = {
	OpenAIKey  :> $OpenAIKey,
	OpenAIUser :> $OpenAIUser
};

OpenAIFileDelete[file_OpenAIFile, opts:OptionsPattern[]] :=
	Enclose[
	With[{apiKey = OptionValue[OpenAIFileUpload, opts, OpenAIKey]},

		ConfirmBy[apiKey, StringQ,
			Message[OpenAIFileUpload::invalidOpenAIAPIKey, apiKey];
			Failure["InvalidOpenAIKey", <|
				"MessageTemplace" :> OpenAIFileUpload::invalidOpenAIAPIKey.
				"MessageParameters" -> {apiKey}
			|>]
		];

		conformDeleteResponse[
			URLRead[
				<|
					"Scheme" -> "https",
					"Domain" -> "api.openai.com",
					"Method" -> "DELETE",
					"Path" -> {"v1", "files", file["ID"]},
					"Headers" -> {
						"Authorization" -> "Bearer " <> apiKey
					}
				|>
			]
		]

	],
	"InheritedFailure"]


conformDeleteResponse[data_] :=
	Enclose[
		With[{resp = Confirm@ConformResponse[OpenAIFileUpload, data]},
			If[TrueQ[resp["deleted"]],
				Success["OpenAIFileDeleted", <|
					"MessageTemplate" -> "OpenAIFile with ID `1` successfully deleted.",
					"MessageParameters" -> resp["id"]
				|>],
				Failure["OpenAIFileDeletion", <|
					"MessageTemplate" -> "OpenAIFile not deleted successfully.",
					"Response" -> resp
				|>]
			]
		],
	"InheritedFailure"]



(*
	OpenAIFileInformation[]
		Lists files on the OpenAI servers.

	OpenAIFileInformation[file]
		Gives information about the specified file.
*)

Options[OpenAIFileInformation] = {
	OpenAIKey  :> $OpenAIKey,
	OpenAIUser :> $OpenAIUser
};

OpenAIFileInformation[opts:OptionsPattern[]] :=
	Enclose[CreateOpenAIFile/@Confirm[Confirm[OpenAIRequest[{"v1", "files"}, None, opts, OpenAIFileInformation]]["data"]], "InheritedFailure"]



(***********************************************************************************)
(******************************** OpenAIFile objects *******************************)
(***********************************************************************************)


(*
	OpenAIFile[...]
		Represents a file on the OpenAI servers.
*)

OpenAIFile[data:Except[KeyValuePattern[{
		"ID" -> _String,
		"FileName" -> _String,
		"CreationDate" -> _?DateObjectQ,
		"Purpose" -> _String,
		"FileByteCount" -> _Integer
	}]]] :=
	Failure["InvalidOpenAIFile", <|
		"MessageTemplate" :> OpenAIFile::invOpenAIFile,
		"MessageParameters" -> {data},
		"Data" -> data
	|>]


HoldPattern[OpenAIFile][data_][All] := data
file_OpenAIFile[prop_] := file[All][prop]
file_OpenAIFile["FileSize"] := Quantity[file["FileByteCount"], "Bytes"]


OpenAIFile /: MakeBoxes[file_OpenAIFile, StandardForm] :=
	BoxForm`ArrangeSummaryBox[
		OpenAIFile,
		file,
		None,
		{
			BoxForm`SummaryItem@{"file name: ", file["FileName"]},
			BoxForm`SummaryItem@{"id: ", file["ID"]}
		},
		{
			BoxForm`SummaryItem@{"file size: ", file["FileSize"]}
		},
		StandardForm
	]



(*
	CreateOpenAIFile[data]
		creates and OpenAIFile object from an OpenAI file JSON specification (as returned by the API).
*)

CreateOpenAIFile[data:KeyValuePattern[{
		"object" -> "file",
		"id" ->id_String,
		"filename" -> name_String,
		"purpose" -> purpose_String,
		"created_at" -> timestamp_Integer,
		"bytes" -> byteCount_Integer
	}]] :=
	OpenAIFile[<|
		"ID" -> id,
		"Purpose" -> Replace[purpose, $purposeReplacements],
		"FileName" -> name,
		"FileByteCount" -> byteCount,
		"CreationDate" -> FromUnixTime[timestamp]
	|>]

CreateOpenAIFile[data_] :=
	Failure["InvalidOpenAIFile", <|
		"MessageTemplate" :> OpenAIFile::invOpenAIFile,
		"MessageParameters" -> {data},
		"Data" -> data
	|>]



End[];
EndPackage[];
