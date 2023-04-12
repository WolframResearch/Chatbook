Begin["Wolfram`ElevenLabsAPI`"] (* Begin Private Context *)


Begin["`Private`"](* Begin Private Context *)

(******************************* ElevenLabs *************************************)

(* Authentication information *)

ElevenLabsData[] = {
    "ServiceName" -> "ElevenLabs",
    "URLFetchFun" :> Function[
        Enclose @ With[{params = Lookup[{##2}, "Parameters", {}]},
            HTTPRequest[
                #1,
                Association @ FilterRules[{##2}, Except["Parameters" | "AudioStream"]] //
                    MapAt[Append["xi-api-key" -> Confirm @ Lookup[params, "key"]], "Headers"] //
                    KeyMap[Replace["BodyData" -> "Body"]] //
                    MapAt[DeleteCases[None], "Body"]
            ] // If[Lookup[params, "AudioStream", False],
                (* bad attempt at supporting audio streaming *)
                With[{file = CreateFile[]},
                    URLDownloadSubmit[#, file]; While[FileByteCount[file] == 0]; Audio[file]
                ] &,
                URLExecute
            ]
        ]
    ] ,
    "ClientInfo" :> Enclose @ ConfirmMatch[
        OAuthDialogDump`Private`MultipleKeyDialog[
            "ElevenLabs",
            {"API Key" -> "key"},
            "https://beta.elevenlabs.io/voice-lab",
            "https://beta.elevenlabs.io/terms"
        ],
        KeyValuePattern[{"key" -> _String}]
    ],
    "RawGets" -> {"RawVoices", "RawVoice", "RawVoiceSettings"},
    "RawPosts" -> {"RawTextToSpeech", "RawTextToSpeechStream", "RawVoiceAdd", "RawVoiceEdit", "RawVoiceDelete"},
    "Gets" -> {"Voices", "Voice", "VoiceSettings"},
    "Posts" -> {"TextToSpeech", "TextToSpeechStream", "VoiceAdd", "VoiceEdit"},
    "Information" -> "ElevenLabs connection for WolframLanguage"
}

$ElevenLabslogo = ImageResize[RemoveBackground @ Import["https://pbs.twimg.com/profile_images/1590865996532912131/Tkgaw9L1_400x400.jpg"], 24]
ElevenLabsData["icon"] := $ElevenLabslogo


importJson[json_Association] := Dataset @ json

importJson[json : {___Rule}] := importJson[json //. rules : {___Rule} :> RuleCondition[Association[rules]]]

importJson[json_String] := Enclose @ importJson @ ConfirmBy[ImportString[json, "RawJSON"], AssociationQ]


ElevenLabsData["RawVoices"] := {
    "URL"				-> "https://api.elevenlabs.io/v1/voices",
    "HTTPSMethod"		-> "GET",
    "Headers"			-> {"Content-Type" -> "application/json"}
}

ElevenLabsData["RawVoice"] := {
    "URL"				-> (URLBuild[{"https://api.elevenlabs.io/v1/voices", #1}] &),
    "HTTPSMethod"		-> "GET",
    "Headers"			-> {"Content-Type" -> "application/json"},
    "PathParameters"	-> {"VoiceID"},
    "RequiredParameters"-> {"VoiceID"}
}

ElevenLabsData["RawVoiceSettings"] := {
    "URL"				-> (URLBuild[{"https://api.elevenlabs.io/v1/voices", #1, "settings"}] &),
    "HTTPSMethod"		-> "GET",
    "Headers"			-> {"Content-Type" -> "application/json"},
    "PathParameters"	-> {"VoiceID"},
    "RequiredParameters"-> {"VoiceID"}
}

ElevenLabsData["RawVoiceAdd"] := {
    "URL"				-> "https://api.elevenlabs.io/v1/voices/add",
    "BodyData"		    -> {"ParameterlessBodyData" -> "Data"},
    "HTTPSMethod"		-> "POST",
    "Headers"			-> {"Content-Type" -> "multipart/form-data"},
    "Parameters"		-> {"Data"},
    "RequiredParameters"-> {"Data"}
}

ElevenLabsData["RawVoiceEdit"] := {
    "URL"				-> (URLBuild[{"https://api.elevenlabs.io/v1/voices", #1, "edit"}] &),
    "BodyData"		    -> {"ParameterlessBodyData" -> "Data"},
    "HTTPSMethod"		-> "POST",
    "Headers"			-> {"Content-Type" -> "multipart/form-data"},
    "PathParameters"	-> {"VoiceID"},
    "Parameters"		-> {"Data"},
    "RequiredParameters"-> {"VoiceID", "Data"}
}

ElevenLabsData["RawVoiceDelete"] := {
    "URL"				-> (URLBuild[{"https://api.elevenlabs.io/v1/voices", #1}] &),
    "HTTPSMethod"		-> "DELETE",
    "Headers"			-> {"Content-Type" -> "application/json"},
    "PathParameters"	-> {"VoiceID"},
    "RequiredParameters"-> {"VoiceID"}
}

ElevenLabsCookedData["Voices", id_, OptionsPattern[]] :=
    importJson[KeyClient`rawkeydata[id, "RawVoices"]]["voices", Association,
        #name -> <|
            "VoiceID" -> #["voice_id"],
            "Audio" -> Enclose[ConfirmBy[Audio[ConfirmBy[#["preview_url"], StringQ], Appearance -> "Minimal"], AudioQ], Missing[] &]
        |> &
    ]

ElevenLabsCookedData["Voice", id_, opts : OptionsPattern[]] := importJson[KeyClient`rawkeydata[id, "RawVoice", opts]][
    <|
        "VoiceID" -> #["voice_id"],
        "Name" -> #name,
        "Audio" -> Enclose[ConfirmBy[Audio[ConfirmBy[#["preview_url"], StringQ], Appearance -> "Minimal"], AudioQ], Missing[] &]
    |> &]

ElevenLabsCookedData["VoiceAdd", id_, opts : OptionsPattern[]] := Enclose @ importJson[
    KeyClient`rawkeydata[id, "RawVoiceAdd", {
        "Data" -> <|
            "name" -> ConfirmBy[Lookup[Flatten[{opts}], "Name"], StringQ],
            "files" -> Join[
                Replace[ConfirmMatch[Lookup[Flatten[{opts}], "Files"], {__ ? FileExistsQ}], fileName_String :> File[fileName], {1}],
                Replace[ConfirmMatch[Lookup[Flatten[{opts}], "Audios"], {__ ? AudioQ}], audio_Audio :> File[Export[CreateFile[], audio, "OGG"]], {1}]
            ],
            "labels" -> ConfirmMatch[Lookup[Flatten[{opts}], "Labels", None], _String | None]
        |>
    }]
]

ElevenLabsCookedData["VoiceEdit", id_, opts : OptionsPattern[]] := Enclose @ importJson[
    KeyClient`rawkeydata[id, "RawVoiceEdit", {
        "VoiceID" -> ConfirmBy[Lookup[Flatten[{opts}], "VoiceID"], StringQ],
        "Data" -> <|
            "name" -> ConfirmBy[Lookup[Flatten[{opts}], "Name"], StringQ],
            "files" -> ConfirmMatch[File /@ Lookup[Flatten[{opts}], "Files", {}], {___ ? FileExistsQ}],
            "labels" -> ConfirmMatch[Lookup[Flatten[{opts}], "Labels", None], _String | None]
        |>
    }]
]

ElevenLabsData["RawTextToSpeech"] := {
    "URL"				-> (URLBuild[{"https://api.elevenlabs.io/v1/text-to-speech", #1}] &),
    "BodyData"		    -> {"ParameterlessBodyData" -> "Data"},
    "HTTPSMethod"		-> "POST",
    "Headers"			-> {"Content-Type" -> "application/json"},
    "PathParameters"	-> {"VoiceID"},
    "Parameters"		-> {"Data"},
    "RequiredParameters"-> {"VoiceID", "Data"}
}

ElevenLabsData["RawTextToSpeechStream"] := {
    "URL"				-> (URLBuild[{"https://api.elevenlabs.io/v1/text-to-speech", #1, "stream"}] &),
    "BodyData"		    -> {"ParameterlessBodyData" -> "Data"},
    "HTTPSMethod"		-> "POST",
    "Headers"			-> {"Content-Type" -> "application/json"},
    "PathParameters"	-> {"VoiceID"},
    "Parameters"		-> {"Data", "AudioStream"},
    "RequiredParameters"-> {"VoiceID", "Data"}
}

ElevenLabsCookedData[request : "TextToSpeech" | "TextToSpeechStream", id_, opts : OptionsPattern[]] :=
Enclose @ KeyClient`rawkeydata[id, "Raw" <> request, {
    "VoiceID" -> ConfirmBy[
        Lookup[Flatten[{opts}], "VoiceID",
            ElevenLabsCookedData["Voices", id][Lookup[Flatten[{opts}], "Voice", "Elli"]]["VoiceID"]
        ],
        StringQ
    ],
    "Data" -> Developer`WriteRawJSONString @ <|
        "text" -> Confirm @ Lookup[Flatten[{opts}], "Text"],
        "voice_settings" -> <|
            "stability" -> ConfirmBy[Lookup[Flatten[{opts}], "Stability", 0], Between[{0, 1}]],
            "similarity_boost" -> ConfirmBy[Lookup[Flatten[{opts}], "SimilarityBoost", 0], Between[{0, 1}]]
        |>
    |>,
    "AudioStream" -> request === "TextToSpeechStream"
}]


ElevenLabsCookedData[___] := $Failed

ElevenLabsSendMessage[___] := $Failed


End[]

End[]

SetAttributes[{}, {ReadProtected, Protected}]

(* Return three functions to define Data, CookedData, SendMessage  *)

{
    Wolfram`ElevenLabsAPI`Private`ElevenLabsData,
    Wolfram`ElevenLabsAPI`Private`ElevenLabsCookedData,
    Wolfram`ElevenLabsAPI`Private`ElevenLabsSendMessage
}

