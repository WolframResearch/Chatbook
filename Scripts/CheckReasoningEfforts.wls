#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

Begin[ "`Private`" ];

(* *********************************************************************************************** *)
(* OpenAI *)
(* Re-derive the reasoning effort levels each OpenAI model accepts and diff them against the
   "ReasoningEfforts" entries in $modelAutoSettings.

   Needs network access and SystemCredential[ "OPENAI_API_KEY" ], so this is a maintenance script
   rather than a test.

   This test relies on this particular behavior which could deviate in future:
   A level that is schema-valid but absent from the model -- "minimal" for anything after gpt-5.0
   -- is rejected by the model instead, and that error enumerates the model's own supported values.
*)

$models = {
    "gpt-5", "gpt-5.1", "gpt-5.4", "gpt-5.5",
    "gpt-5.6", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.6-cyber",
    "gpt-6-astra"
};

$key := $key = SystemCredential[ "OPENAI_API_KEY" ];

askEffort[ model_String, effort_String ] :=
    Module[ { response },
        response = URLRead @ HTTPRequest[
            "https://api.openai.com/v1/responses",
            <|
                "Method"      -> "POST",
                "Headers"     -> { "Authorization" -> "Bearer " <> $key },
                "ContentType" -> "application/json",
                "Body"        -> ExportString[
                    <|
                        "model"             -> model,
                        "input"             -> "hi",
                        "max_output_tokens" -> 16,
                        "reasoning"         -> <| "effort" -> effort |>
                    |>,
                    "RawJSON"
                ]
            |>
        ];
        Quiet @ Check[ ImportString[ response[ "Body" ], "RawJSON" ][[ "error", "message" ]], "" ]
    ];

(* The levels the service itself reports for one model, lowercase, in the order it lists them: *)
apiLevels[ model_String ] :=
    Module[ { message },
        Do[
            message = askEffort[ model, effort ];
            If[ StringQ @ message && StringContainsQ[ message, "Supported values are:" ],
                Return[
                    StringCases[
                        StringDrop[ message, StringPosition[ message, "Supported values are:" ][[ 1, 2 ]] ],
                        "'" ~~ value: Except[ "'" ].. ~~ "'" :> value
                    ],
                    Module
                ]
            ],
            { effort, { "minimal", "max" } }
        ];
        $Failed
    ];

declaredLevels[ model_String ] :=
    Wolfram`Chatbook`Common`autoModelSetting[
        <| "Model" -> Wolfram`Chatbook`Common`resolveFullModelSpec @ <|
            "Service" -> "OpenAI",
            "Name"    -> model
        |> |>,
        "ReasoningEfforts"
    ];

compare[ model_String ] :=
    Module[ { api, declared, match },
        api      = apiLevels @ model;
        declared = declaredLevels @ model;
        match    = ListQ @ api && ListQ @ declared && ToLowerCase /@ declared === ToLowerCase /@ api;
        Print[
            StringPadRight[ model, 16 ],
            StringPadRight[ ToString @ api, 42 ],
            StringPadRight[ ToString @ declared, 46 ],
            If[ match, "ok", "MISMATCH" ]
        ];
        match
    ];

End[ ];

EndPackage[ ];

(* Load the repo this script lives in, and report mismatch detected between the current API behavior
   and what's stored in Settings.wl. *)
PacletDirectoryLoad @ ParentDirectory @ DirectoryName @ $InputFileName;
Needs[ "Wolfram`Chatbook`" ];

Print[ "Chatbook loaded from: ", PacletObject[ "Wolfram/Chatbook" ][ "Location" ] ];
Print[ "" ];

Print[
    StringPadRight[ "model", 16 ],
    StringPadRight[ "service reports", 42 ],
    StringPadRight[ "$modelAutoSettings declares", 46 ],
    "match"
];

Wolfram`ChatbookScripts`result =
    If[ AllTrue[ Wolfram`ChatbookScripts`Private`compare /@ Wolfram`ChatbookScripts`Private`$models, TrueQ ],
        Print[ "\nEvery model matches." ]; 0,
        Print[ "\nAt least one model does not match; update \"ReasoningEfforts\" in Settings.wl." ]; 1
    ];

Wolfram`ChatbookScripts`result
