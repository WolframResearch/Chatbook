#!/usr/bin/env wolframscript
(* ::**************************************************************************************************************:: *)
(* CheckReasoningEfforts.wls

   Probe OpenAI's API for the reasoning effort levels each model accepts, and the level it uses when a
   request names none, on both the Responses endpoint (/v1/responses) and the Chat Completions
   endpoint (/v1/chat/completions). Also report the "Reasoning" setting Chatbook currently resolves
   for each model -- what it would actually send when "Reasoning" is Automatic -- on this checkout and
   on a comparison branch.

   This script only reports data. It does not compare against, or write to, any Chatbook model auto
   setting: the design for recording these properties inside Chatbook (PR #362 review S15/S16) is not
   settled yet. See ChatbookDevelopment`LLMData` in AIAssistantBenchmarking for a place to keep the
   observed data meanwhile.

   Usage:
       wolframscript -f Scripts/CheckReasoningEfforts.wls [all] [out=<file>] [compare=<dir>] [<model> ...]

       (no arguments)  check the models in $models below
       all             also check every gpt-5*/gpt-6* alias the key can list at /v1/models
       out=<file>      Put the per-model results (a list of associations) into <file>
       compare=<dir>   Also resolve "Reasoning" from the Chatbook checkout at <dir> (e.g. a second
                       git worktree on main), for the "resolved (compare)" column. Defaults to none.
       <model>         check only the named models, e.g. gpt-5.4 gpt-5.5-pro

   Arguments are plain words: wolframscript consumes --flags before the script sees them.

   Requirements: network access and SystemCredential[ "OPENAI_API_KEY" ]. It is therefore a maintenance
   script rather than a test. Each model costs a handful of small requests: rejected ones for the
   levels, plus one short generation per endpoint for the default (up to 4000 completion tokens on
   Chat Completions, see below), plus one wolframscript subprocess per checkout being compared.

   How each property is found:
     * Levels: a request with a level that is schema-valid but absent from the model ("minimal" for
       anything after gpt-5.0, otherwise "max") is rejected, and the error message enumerates the
       model's own supported values. Both endpoints behave this way. This could change in future.
     * Default on Responses: a request without "reasoning" returns the effort it used in the
       response's "reasoning" field.
     * Default on Chat Completions: the response does not report the effort. A request without
       "reasoning_effort" on a prompt that needs some reasoning uses zero reasoning tokens when the
       default is "none", but some models also use none at a stated level on some requests (the
       gpt-5.6 line through Chat Completions often reports zero even at "high"). So the default is
       reported as "none" only when $samples requests without an effort all use zero reasoning
       tokens and $samples requests at the weakest level other than "none" all use some, and as
       Missing[ "NotReported" ] otherwise. Token counts do not reliably tell the other levels apart.
     * Resolved (this checkout) / Resolved (compare): each is fetched from a fresh wolframscript
       subprocess running Scripts/ResolvedReasoningDefault.wl against the named checkout, calling
       autoModelSetting[ ..., "Reasoning" ] on the resolved model spec -- the same value
       AbsoluteCurrentChatSettings would report for "Reasoning" -> Automatic.

   Output: per model, one line per endpoint (levels, default, and the snapshot the alias resolves to),
   then one line with the two resolved-default columns. Neither endpoint being able to check a model
   is reported as a Missing[ ... ] status rather than blank:
     Missing[ "NoAccess" ]            the key cannot use the model
     Missing[ "Deprecated" ]          the model is deprecated
     Missing[ "NotOnEndpoint" ]       the endpoint does not serve the model
     Missing[ "NoReasoningEffort" ]   the model accepts no reasoning effort parameter

   To save the observed data into ChatbookDevelopment`LLMData` (AIAssistantBenchmarking), run this
   script with out=<file> and pass the file to ChatbookDevelopment`LLMData`ImportReasoningEffortProbe;
   see that function's usage for the spreadsheet export.
*)

BeginPackage[ "Wolfram`ChatbookScripts`" ];

Begin[ "`Private`" ];

$models = {
    "gpt-5", "gpt-5-mini", "gpt-5-nano", "gpt-5-pro",
    "gpt-5.1", "gpt-5.2", "gpt-5.2-pro", "gpt-5.3-codex",
    "gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano", "gpt-5.4-pro",
    "gpt-5.5", "gpt-5.5-pro",
    "gpt-5.6", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.6-cyber",
    "gpt-6-astra", "gpt-6-sol", "gpt-6-luna"
};

$endpoints = { "Responses", "ChatCompletions" };

(* A prompt that needs a little reasoning, so that only a "none" default produces zero reasoning tokens: *)
$reasoningPrompt = "A bat and a ball cost $1.10 in total. The bat costs $1.00 more than the ball. Three friends each \
buy one bat and two balls; how much do they spend in total? Reply with the number only.";

(* Requests per side when deciding whether a Chat Completions default is "none": *)
$samples = 3;

$key := $key = SystemCredential[ "OPENAI_API_KEY" ];

(* ::**************************************************************************************************************:: *)
(* Requests *)

request[ path_String, body_ ] :=
    Module[ { response },
        response = URLRead @ HTTPRequest[
            "https://api.openai.com/v1/" <> path,
            <|
                "Method"      -> If[ body === None, "GET", "POST" ],
                "Headers"     -> { "Authorization" -> "Bearer " <> $key },
                "ContentType" -> "application/json",
                If[ body === None, Nothing, "Body" -> ExportString[ body, "RawJSON" ] ]
            |>
        ];
        Quiet @ Replace[ ImportString[ response[ "Body" ], "RawJSON" ], Except[ _Association ] -> <| |> ]
    ];

(* The request body for each endpoint, with an optional effort level and completion-token cap: *)
body[ "Responses", model_, effort_, prompt_, max_ ] := <|
    "model"             -> model,
    "input"             -> prompt,
    "max_output_tokens" -> max,
    If[ effort === None, Nothing, "reasoning" -> <| "effort" -> effort |> ]
|>;

body[ "ChatCompletions", model_, effort_, prompt_, max_ ] := <|
    "model"                 -> model,
    "messages"              -> { <| "role" -> "user", "content" -> prompt |> },
    "max_completion_tokens" -> max,
    If[ effort === None, Nothing, "reasoning_effort" -> effort ]
|>;

path[ "Responses"       ] := "responses";
path[ "ChatCompletions" ] := "chat/completions";

call[ endpoint_, model_, effort_, prompt_: "hi", max_: 16 ] :=
    request[ path @ endpoint, body[ endpoint, model, effort, prompt, max ] ];

errorMessage[ response_Association ] :=
    Replace[ response[ "error" ], { KeyValuePattern[ "message" -> m_String ] :> m, _ -> None } ];

(* Why an endpoint cannot check a model at all, or None when it can: *)
unavailable[ message_String ] := Which[
    StringContainsQ[ message, "does not exist or you do not have access" ]            , Missing[ "NoAccess" ],
    StringContainsQ[ message, "has been deprecated" ]                                 , Missing[ "Deprecated" ],
    StringContainsQ[ message, "not supported with the Responses API" ]                , Missing[ "NotOnEndpoint" ],
    StringContainsQ[ message, "only supported in v1/responses" ]                      , Missing[ "NotOnEndpoint" ],
    StringContainsQ[ message, "not supported in the v1/chat/completions endpoint" ]   , Missing[ "NotOnEndpoint" ],
    StringContainsQ[ message, "Unrecognized request argument supplied: reasoning" ]   , Missing[ "NoReasoningEffort" ],
    True, None
];
unavailable[ _ ] := None;

(* One of the reasons above, as opposed to a property that merely was not reported: *)
unavailableQ[ value_ ] := MatchQ[ value, Missing[ "NoAccess" | "Deprecated" | "NotOnEndpoint" | "NoReasoningEffort" ] ];

sameQ[ a_List, b_List ] := ToLowerCase /@ a === ToLowerCase /@ b;
sameQ[ a_String, b_String ] := ToLowerCase @ a === ToLowerCase @ b;
sameQ[ _, _ ] := False;

(* Every gpt-5*/gpt-6* alias the key can list, without dated snapshots: *)
listedModels[ ] :=
    Select[
        Replace[ request[ "models", None ][ "data" ], { l_List :> Lookup[ l, "id" ], _ -> { } } ],
        StringStartsQ[ #, "gpt-5" | "gpt-6" ] && ! StringMatchQ[ #, ___ ~~ "-" ~~ Repeated[ DigitCharacter, { 4 } ] ~~ "-" ~~ DigitCharacter.. ~~ "-" ~~ DigitCharacter.. ] &
    ];

(* ::**************************************************************************************************************:: *)
(* Probes *)

(* The levels the endpoint reports for one model, lowercase, in the order it lists them: *)
apiLevels[ endpoint_, model_String ] :=
    Module[ { message },
        Do[
            message = errorMessage @ call[ endpoint, model, effort ];
            If[ MissingQ @ unavailable @ message, Return[ unavailable @ message, Module ] ];
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

(* The effort the endpoint uses when the request names none, and the snapshot the alias resolves to: *)
apiDefault[ "Responses", model_String ] :=
    Module[ { response, message },
        response = call[ "Responses", model, None ];
        message  = errorMessage @ response;
        Which[
            MissingQ @ unavailable @ message, { unavailable @ message, unavailable @ message },
            StringQ @ message, { $Failed, $Failed },
            True, {
                Replace[ response[ "reasoning" ], { KeyValuePattern[ "effort" -> e_String ] :> e, _ -> $Failed } ],
                Replace[ response[ "model" ], Except[ _String ] -> $Failed ]
            }
        ]
    ];

reasoningTokens[ response_Association ] :=
    Quiet @ Replace[ response[ "usage", "completion_tokens_details", "reasoning_tokens" ], Except[ _Integer ] -> $Failed ];

apiDefault[ "ChatCompletions", model_String ] :=
    apiDefault[ "ChatCompletions", model, apiLevels[ "ChatCompletions", model ] ];

apiDefault[ "ChatCompletions", model_String, levels_ ] :=
    Module[ { response, message, weakest, usage },
        response = call[ "ChatCompletions", model, None, $reasoningPrompt, 4000 ];
        message  = errorMessage @ response;
        (* The weakest level other than "none", which must be told apart from "none" on this prompt: *)
        weakest  = SelectFirst[ Replace[ levels, Except[ _List ] -> { } ], ! sameQ[ #, "none" ] &, None ];
        usage[ effort_ ] := reasoningTokens @ call[ "ChatCompletions", model, effort, $reasoningPrompt, 4000 ];
        Which[
            MissingQ @ unavailable @ message, { unavailable @ message, unavailable @ message },
            StringQ @ message, { $Failed, $Failed },
            True, {
                If[ And[
                        MemberQ[ ToLowerCase /@ Replace[ levels, Except[ _List ] -> { } ], "none" ],
                        StringQ @ weakest,
                        reasoningTokens @ response === 0,
                        AllTrue[ Table[ usage @ None, $samples - 1 ], # === 0 & ],
                        AllTrue[ Table[ usage @ weakest, $samples ], MatchQ[ #, _Integer? Positive ] & ]
                    ],
                    "none",
                    Missing[ "NotReported" ]
                ],
                Replace[ response[ "model" ], Except[ _String ] -> $Failed ]
            }
        ]
    ];

probe[ endpoint_, model_String ] :=
    Module[ { levels, default, snapshot },
        levels                = apiLevels[ endpoint, model ];
        { default, snapshot } = If[ endpoint === "ChatCompletions",
                                    apiDefault[ endpoint, model, levels ],
                                    apiDefault[ endpoint, model ]
                                ];
        (* An endpoint that cannot check the model says so in every field: *)
        Which[
            unavailableQ @ levels , { default, snapshot } = { levels, levels },
            unavailableQ @ default, { levels, snapshot } = { default, default }
        ];
        <| "Levels" -> levels, "Default" -> default, "ResolvedModel" -> snapshot |>
    ];

(* ::**************************************************************************************************************:: *)
(* What Chatbook currently resolves, per checkout *)

(* Run the resolver against one checkout, in its own subprocess, for every model at once: *)
resolvedReasoning[ dir_String, models_List ] :=
    Module[ { result },
        result = RunProcess[
            Flatten @ { "wolframscript", "-f", FileNameJoin @ { DirectoryName @ $InputFileName, "ResolvedReasoningDefault.wl" }, dir, models },
            "StandardOutput"
        ];
        Replace[
            Quiet @ ToExpression @ result,
            { assoc_Association :> assoc, _ :> AssociationMap[ $Failed &, models ] }
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* Check *)

check[ model_String, thisResolved_Association, compareResolved_Association ] :=
    Module[ { api, result },
        api = AssociationMap[ probe[ #, model ] &, $endpoints ];
        result = <|
            "Name"                  -> model,
            "Responses"             -> api[ "Responses" ],
            "ChatCompletions"       -> api[ "ChatCompletions" ],
            "ResolvedReasoning"     -> Lookup[ thisResolved, model, Missing[ "NotChecked" ] ],
            "ResolvedReasoningCompare" -> Lookup[ compareResolved, model, Missing[ "NotChecked" ] ]
        |>;
        printResult @ result;
        result
    ];

$columns = { 20, 24, 24, 42, 24 };

row[ cells_List ] := Print @ StringJoin[
    MapThread[ StringPadRight[ ToString @ #1, #2 ] &, { Take[ cells, UpTo @ Length @ $columns ], Take[ $columns, UpTo @ Length @ cells ] } ],
    ToString /@ Drop[ cells, UpTo @ Length @ $columns ]
];

printResult[ r_Association ] := (
    Do[
        row @ {
            If[ e === "Responses", r[ "Name" ], "" ],
            e,
            r[ e, "ResolvedModel" ],
            r[ e, "Levels" ],
            r[ e, "Default" ]
        },
        { e, $endpoints }
    ];
    row @ { "", "resolved (this checkout)", r[ "ResolvedReasoning" ] };
    row @ { "", "resolved (compare)", r[ "ResolvedReasoningCompare" ] }
);

End[ ];

EndPackage[ ];

(* ::**************************************************************************************************************:: *)
(* Main *)

(* Load the repo this script lives in: *)
Wolfram`ChatbookScripts`Private`$thisDir = ParentDirectory @ DirectoryName @ $InputFileName;
PacletDirectoryLoad @ Wolfram`ChatbookScripts`Private`$thisDir;
Needs[ "Wolfram`Chatbook`" ];

Wolfram`ChatbookScripts`Private`$arguments = Rest @ $ScriptCommandLine;

Wolfram`ChatbookScripts`Private`$checked =
    With[ { named = Select[ Wolfram`ChatbookScripts`Private`$arguments, # =!= "all" && ! StringContainsQ[ #, "=" ] & ] },
        Which[
            named =!= { }, named,
            MemberQ[ Wolfram`ChatbookScripts`Private`$arguments, "all" ],
                DeleteDuplicates @ Join[
                    Wolfram`ChatbookScripts`Private`$models,
                    Sort @ Wolfram`ChatbookScripts`Private`listedModels[ ]
                ],
            True, Wolfram`ChatbookScripts`Private`$models
        ]
    ];

Wolfram`ChatbookScripts`Private`$compareDir =
    Replace[
        SelectFirst[ Wolfram`ChatbookScripts`Private`$arguments, StringStartsQ[ #, "compare=" ] & ],
        { arg_String :> StringDrop[ arg, 8 ], _ -> None }
    ];

Print[ "Chatbook loaded from: ", PacletObject[ "Wolfram/Chatbook" ][ "Location" ] ];
Print[ "" ];
Wolfram`ChatbookScripts`Private`row @ { "model", "endpoint", "resolves to", "levels", "default" };

Wolfram`ChatbookScripts`Private`$thisResolved =
    Wolfram`ChatbookScripts`Private`resolvedReasoning[
        Wolfram`ChatbookScripts`Private`$thisDir,
        Wolfram`ChatbookScripts`Private`$checked
    ];

Wolfram`ChatbookScripts`Private`$compareResolved =
    If[ Wolfram`ChatbookScripts`Private`$compareDir === None,
        AssociationMap[ Missing[ "NotCompared" ] &, Wolfram`ChatbookScripts`Private`$checked ],
        Wolfram`ChatbookScripts`Private`resolvedReasoning[
            Wolfram`ChatbookScripts`Private`$compareDir,
            Wolfram`ChatbookScripts`Private`$checked
        ]
    ];

Wolfram`ChatbookScripts`Private`$results =
    Wolfram`ChatbookScripts`Private`check[
        #,
        Wolfram`ChatbookScripts`Private`$thisResolved,
        Wolfram`ChatbookScripts`Private`$compareResolved
    ] & /@ Wolfram`ChatbookScripts`Private`$checked;

Replace[
    SelectFirst[ Wolfram`ChatbookScripts`Private`$arguments, StringStartsQ[ #, "out=" ] & ],
    arg_String :> (
        Put[ Wolfram`ChatbookScripts`Private`$results, StringDrop[ arg, 4 ] ];
        Print[ "\nResults written to ", StringDrop[ arg, 4 ] ]
    )
];

Print[ "\nDone. This script only reports data; it does not compare against or modify any Chatbook setting." ];

Exit[ 0 ]
