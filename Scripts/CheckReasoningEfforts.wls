#!/usr/bin/env wolframscript
(* ::**************************************************************************************************************:: *)
(* CheckReasoningEfforts.wls

   Probe OpenAI's API for the reasoning effort levels each model accepts, and the level it uses when a
   request names none, on both the Responses endpoint (/v1/responses) and the Chat Completions
   endpoint (/v1/chat/completions). Also report what Chatbook does with each model's reasoning effort
   on each request method -- on this checkout and on a comparison branch -- and optionally write it all
   to Developer/OpenAIReasoningEfforts.wl.

   This script only reports data. It does not compare against, or write to, any Chatbook model auto
   setting: the design for recording these properties inside Chatbook is not settled yet. Meanwhile,
   out=<file> keeps the raw records and developer=<file> a readable copy.

   Usage:
       wolframscript -f Scripts/CheckReasoningEfforts.wls [all] [out=<file>] [compare=<dir>] [from=<file>]
                                                         [developer=<file>] [<model> ...]
       (no arguments)    check the models in $models below
       all               also check every gpt-5*/gpt-6* alias the key can list at /v1/models
       out=<file>        Put the per-model results (a list of associations) into <file>
       compare=<dir>     Also resolve Chatbook's side from the checkout at <dir> (e.g. a second git
                         worktree on main), for the "resolved (compare)" line. Defaults to none.
       from=<file>       Read OpenAI's side from <file>, an earlier run's out=<file>, instead of probing
                         the API, so no API calls are made: for example to rebuild the developer file
                         after a change to Chatbook. Checks the models in <file>, or the named ones in it.
       developer=<file>  Also write the results to <file> as a human-readable data file, normally
                         Developer/OpenAIReasoningEfforts.wl (see "Developer data file" below)
       <model>           check only the named models, e.g. gpt-5.4 gpt-5.5-pro
   Arguments are plain words: wolframscript consumes --flags before the script sees them. Relative file
   names are relative to the current directory.

   Requirements: network access and SystemCredential[ "OPENAI_API_KEY" ], except with from=<file>. It is
   therefore a maintenance script rather than a test. Each model costs a handful of small requests:
   rejected ones for the levels, plus one short generation per endpoint for the default (up to 4000
   completion tokens on Chat Completions, see below), plus one wolframscript subprocess per checkout
   being compared.

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
     * Chatbook's side, on this checkout and on the compare= checkout: each comes from a fresh
       wolframscript subprocess running Scripts/ResolvedReasoningDefault.wl against that checkout. It
       evaluates Chatbook's own functions for each request method: the declared levels, the value
       "Reasoning" -> Automatic resolves to (what AbsoluteCurrentChatSettings reports), and the value
       actually sent. See that script's usage comment for the full structure.

   Output: per model, one line per endpoint (levels, default, and the snapshot the alias resolves to),
   then one line per checkout with the request method Chatbook chooses and the "Reasoning" value it
   resolves on each request method. Neither endpoint being able to check a model is reported as a
   Missing[ ... ] status rather than blank:
     Missing[ "NoAccess" ]            the key cannot use the model
     Missing[ "Deprecated" ]          the model is deprecated
     Missing[ "NotOnEndpoint" ]       the endpoint does not serve the model
     Missing[ "NoReasoningEffort" ]   the model accepts no reasoning effort parameter

   Records written by out=<file>, one Association per model:
     "Name", "ProbeDate"              the model, and the date OpenAI's side was probed
     "Responses", "ChatCompletions"   <| "Levels", "Default", "ResolvedModel" |> as reported by the API
     "ResolvedReasoning"              the "Reasoning" value this checkout resolves on the request method it
                                      chooses; "ResolvedReasoningCompare" is the same for compare=<dir>
     "Chatbook", "ChatbookCompare"    the model's full entry from ResolvedReasoningDefault.wl, per checkout

   Developer data file (developer=<file>): one Association with the probe date and this checkout's commit,
   paclet versions and Responses gate, and per model OpenAI's levels and default in Chatbook's spellings,
   Chatbook's side, and where the two differ. Its header comment explains every key; it is filled in from
   Scripts/Resources/OpenAIReasoningEffortsHeader.wl. Nothing in Source/ reads the file.
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
(* What Chatbook does, per checkout *)

(* Run ResolvedReasoningDefault.wl against one checkout, in its own subprocess, for every model at once: *)
chatbookSide[ dir_String, models_List ] :=
    Module[ { output, start, result },
        output = RunProcess[
            Flatten @ { "wolframscript", "-f", FileNameJoin @ { DirectoryName @ $InputFileName, "ResolvedReasoningDefault.wl" }, dir, models },
            "StandardOutput"
        ];
        (* Skip anything printed before the result, such as download progress: *)
        start  = Replace[ StringPosition[ output, "<|", 1 ], { { { a_, _ } } :> a, _ :> 1 } ];
        result = Quiet @ ToExpression @ StringDrop[ output, start - 1 ];
        If[ AssociationQ @ result && AssociationQ @ result[ "Models" ],
            result,
            <| "Models" -> AssociationMap[ Missing[ "Failed" ] &, models ] |>
        ]
    ];

(* The "Reasoning" value a checkout resolves on the request method it chooses: *)
chosenReasoning[ side_Association ] :=
    Lookup[ Lookup[ side, side[ "RequestMethod" ], <| |> ], "Reasoning", Missing[ "NotDeclared" ] ];

chosenReasoning[ other_ ] := other;

(* ::**************************************************************************************************************:: *)
(* Check *)

(* OpenAI's side comes from saved (an earlier run's records, by model name) when it has the model, and from the API
   otherwise: *)
check[ model_String, thisModels_Association, compareModels_Association, saved_Association, date_String ] :=
    Module[ { api, this, compare, result },
        api = If[ KeyExistsQ[ saved, model ],
                  KeyTake[ saved @ model, $endpoints ],
                  AssociationMap[ probe[ #, model ] &, $endpoints ]
              ];
        this    = Lookup[ thisModels   , model, Missing[ "NotChecked" ] ];
        compare = Lookup[ compareModels, model, Missing[ "NotChecked" ] ];
        result = <|
            "Name"                     -> model,
            "ProbeDate"                -> Lookup[ Lookup[ saved, model, <| |> ], "ProbeDate", date ],
            "Responses"                -> api[ "Responses" ],
            "ChatCompletions"          -> api[ "ChatCompletions" ],
            "ResolvedReasoning"        -> chosenReasoning @ this,
            "ResolvedReasoningCompare" -> chosenReasoning @ compare,
            "Chatbook"                 -> this,
            "ChatbookCompare"          -> compare
        |>;
        printResult @ result;
        result
    ];

$columns = { 20, 26, 24, 42, 24 };

(* Cells are padded to their column but never cut short; a cell wider than its column keeps one space after it: *)
row[ cells_List ] := Print @ StringJoin[
    MapThread[
        With[ { s = ToString @ #1 }, StringPadRight[ s, Max[ #2, StringLength @ s + 1 ] ] ] &,
        { Take[ cells, UpTo @ Length @ $columns ], Take[ $columns, UpTo @ Length @ cells ] }
    ],
    ToString /@ Drop[ cells, UpTo @ Length @ $columns ]
];

(* The request method a checkout chooses, then the "Reasoning" value it resolves on each request method: *)
chatbookCells[ side_Association ] := {
    "uses " <> ToString @ side[ "RequestMethod" ],
    "Responses: " <> ToString @ side[ "Responses", "Reasoning" ],
    "ChatCompletions: " <> ToString @ side[ "ChatCompletions", "Reasoning" ]
};

chatbookCells[ other_ ] := { other };

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
    row @ Join[ { "", "resolved (this checkout)" }, chatbookCells @ r[ "Chatbook" ] ];
    row @ Join[ { "", "resolved (compare)" }, chatbookCells @ r[ "ChatbookCompare" ] ]
);

(* ::**************************************************************************************************************:: *)
(* Developer data file *)

(* The API's lowercase levels in Chatbook's spellings, taken from the checkout's $reasoningEffortScale: *)
spell[ scale_ ][ level_String ] := SelectFirst[ scale, StringMatchQ[ #, level, IgnoreCase -> True ] &, level ];
spell[ scale_ ][ levels_List  ] := spell[ scale ] /@ levels;
spell[ _      ][ other_       ] := other;

(* A request method the probe could not check (no access, not served, ...) is just its Missing status: *)
openAISide[ _ ][ KeyValuePattern @ { "Levels" -> m_Missing, "Default" -> m_Missing } ] := m;
openAISide[ scale_ ][ ep_Association ] :=
    <| "ReasoningEfforts" -> spell[ scale ] @ ep[ "Levels" ], "DefaultReasoning" -> spell[ scale ] @ ep[ "Default" ] |>;
openAISide[ _ ][ other_ ] := other;

effortOf[ scale_, level_String ]                              := spell[ scale ] @ level;
effortOf[ scale_, KeyValuePattern[ "effort" -> level_String ] ] := spell[ scale ] @ level;
effortOf[ _, _ ]                                              := None;

(* Where OpenAI's side and Chatbook's side disagree, per request method; the header template explains each key: *)
differences[ scale_, openAI_Association, chatbook_Association ] :=
    DeleteCases[ AssociationMap[ difference[ scale, openAI[ # ], chatbook, # ] &, $endpoints ], <| |> ];

differences[ _, _, _ ] := <| |>;

difference[ scale_, o_, chatbook_, method_ ] :=
    Module[ { c = chatbook[ method ], accepted, declared, sent, d = <| |> },
        Which[
            o === Missing[ "NotOnEndpoint" ] && chatbook[ "RequestMethod" ] === method,
                d[ "NotServed" ] = "ChosenByChatbook",
            o === Missing[ "NotOnEndpoint" ] && method === "ChatCompletions",
                d[ "NotServed" ] = "GateShutFallback",
            o === Missing[ "NoReasoningEffort" ] && ! MissingQ @ c[ "Sent" ],
                d[ "NoReasoningEffort" ] = True,
            AssociationQ @ o && ListQ @ o[ "ReasoningEfforts" ],
                accepted = o[ "ReasoningEfforts" ];
                declared = c[ "ReasoningEfforts" ];
                If[ ListQ @ declared,
                    If[ Complement[ declared, accepted ] =!= { },
                        d[ "DeclaredNotAccepted" ] = Select[ declared, ! MemberQ[ accepted, # ] & ]
                    ];
                    If[ Complement[ accepted, declared ] =!= { },
                        d[ "AcceptedNotDeclared" ] = Select[ accepted, ! MemberQ[ declared, # ] & ]
                    ]
                ];
                sent = effortOf[ scale, c[ "Sent" ] ];
                If[ StringQ @ sent && ! MemberQ[ accepted, sent ], d[ "DefaultNotAccepted" ] = sent ]
        ];
        d
    ];

developerEntry[ scale_ ][ r_Association ] :=
    With[ { openAI = AssociationMap[ openAISide[ scale ][ r[ # ] ] &, $endpoints ] },
        r[ "Name" ] -> <|
            "Snapshot"    -> FirstCase[ r /@ $endpoints, KeyValuePattern[ "ResolvedModel" -> s_String ] :> s,
                                        Missing[ "NotAvailable" ] ],
            "OpenAI"      -> openAI,
            "Chatbook"    -> r[ "Chatbook" ],
            "Differences" -> differences[ scale, openAI, r[ "Chatbook" ] ]
        |>
    ];

(* Pretty printing in Chatbook's source style: spaces inside brackets, aligned arrows, nested associations expanded,
   and anything else kept on one line when it fits in $width columns: *)
$width = 120;

pad[ n_Integer ] := StringRepeat[ " ", n ];

inline[ s_String ]           := ToString[ s, InputForm ];
inline[ { } ]                := "{ }";
inline[ l_List ]             := "{ " <> StringRiffle[ inline /@ l, ", " ] <> " }";
inline[ <| |> ]              := "<| |>";
inline[ as_Association ]     :=
    "<| " <> StringRiffle[ KeyValueMap[ inline[ #1 ] <> " -> " <> inline[ #2 ] &, as ], ", " ] <> " |>";
inline[ Missing[ args___ ] ] := "Missing[ " <> StringRiffle[ inline /@ { args }, ", " ] <> " ]";
inline[ expr_ ]              := ToString[ expr, InputForm, PageWidth -> Infinity ];

(* The + 1 leaves room for the comma that follows every value but the last: *)
fits[ expr_, column_ ] := column + StringLength @ inline @ expr + 1 <= $width;

pretty[ as_Association, column_, indent_ ] /; as =!= <| |> && ( AnyTrue[ as, AssociationQ ] || ! fits[ as, column ] ) :=
    With[ { keys = inline /@ Keys @ as },
        StringJoin[
            "<|\n",
            StringRiffle[
                MapThread[
                    With[ { lead = pad[ indent + 4 ] <> StringPadRight[ #1, Max[ StringLength /@ keys ] ] <> " -> " },
                        lead <> pretty[ #2, StringLength @ lead, indent + 4 ]
                    ] &,
                    { keys, Values @ as }
                ],
                ",\n"
            ],
            "\n", pad @ indent, "|>"
        ]
    ];

pretty[ l_List, column_, indent_ ] /; ! fits[ l, column ] := StringJoin[
    "{\n",
    StringRiffle[ pad[ indent + 4 ] <> pretty[ #, indent + 4, indent + 4 ] & /@ l, ",\n" ],
    "\n", pad @ indent, "}"
];

pretty[ expr_, _, _ ] := inline @ expr;

writeDeveloperFile[ file_String, results_List, side_Association, date_String ] :=
    Module[ { scale, template, header, data },
        scale    = Replace[ side[ "ReasoningEffortScale" ], Except[ { __String } ] ->
                       { "None", "Minimal", "Low", "Medium", "High", "XHigh", "Max" } ];
        template = Import[
            FileNameJoin @ { DirectoryName @ $InputFileName, "Resources", "OpenAIReasoningEffortsHeader.wl" },
            "Text"
        ];
        header = StringReplace[ template, {
            "{date}"           -> date,
            "{commit}"         -> Replace[ side[ "Checkout", "Commit" ], { c_String :> StringTake[ c, UpTo[ 8 ] ],
                                                                          _ -> "unknown" } ],
            "{sourcestate}"    -> If[ TrueQ @ side[ "Checkout", "SourceModified" ],
                                      "`Source/` had uncommitted changes, so the commit does not describe it fully.",
                                      "`Source/` had no uncommitted changes."
                                  ],
            "{llmfunctions}"   -> ToString @ side[ "Paclets", "LLMFunctions" ],
            "{llmconnections}" -> ToString @ side[ "Paclets", "LLMConnections" ],
            "{gate}"           -> If[ TrueQ @ side[ "Gate" ], "open", "shut" ]
        } ];
        data = <|
            "ProbeDate"              -> date,
            "ChatbookCommit"         -> side[ "Checkout", "Commit" ],
            "ChatbookSourceModified" -> side[ "Checkout", "SourceModified" ],
            "Paclets"                -> side[ "Paclets" ],
            "ResponsesGate"          -> side[ "Gate" ],
            "ReasoningEffortScale"   -> scale,
            "Models"                 -> Association[ developerEntry[ scale ] /@ results ]
        |>;
        Export[ file, StringTrim[ header, "\n".. ] <> "\n" <> pretty[ data, 0, 0 ] <> "\n", "Text",
                CharacterEncoding -> "UTF-8" ]
    ];

End[ ];

EndPackage[ ];

(* ::**************************************************************************************************************:: *)
(* Main *)

(* Load the repo this script lives in: *)
Wolfram`ChatbookScripts`Private`$thisDir = ParentDirectory @ DirectoryName @ $InputFileName;
PacletDirectoryLoad @ Wolfram`ChatbookScripts`Private`$thisDir;
Needs[ "Wolfram`Chatbook`" ];

Wolfram`ChatbookScripts`Private`$arguments = Rest @ $ScriptCommandLine;

(* The value of a name=<value> argument, or None: *)
Wolfram`ChatbookScripts`Private`argument[ name_String ] :=
    Replace[
        SelectFirst[ Wolfram`ChatbookScripts`Private`$arguments, StringStartsQ[ #, name <> "=" ] & ],
        { arg_String :> StringDrop[ arg, StringLength @ name + 1 ], _ -> None }
    ];

(* Saved records from from=<file>, by model name; empty when OpenAI's side is to be probed: *)
Wolfram`ChatbookScripts`Private`$fromFile = Wolfram`ChatbookScripts`Private`argument[ "from" ];
Wolfram`ChatbookScripts`Private`$saved =
    If[ Wolfram`ChatbookScripts`Private`$fromFile === None,
        <| |>,
        Replace[ Quiet @ Get @ ExpandFileName @ Wolfram`ChatbookScripts`Private`$fromFile, {
            records: { __Association } :> Association[ #[ "Name" ] -> # & /@ records ],
            _ :> (
                Print[ "Cannot read probe records from ", Wolfram`ChatbookScripts`Private`$fromFile ];
                Exit[ 1 ]
            )
        } ]
    ];

Wolfram`ChatbookScripts`Private`$checked =
    With[ { named = Select[ Wolfram`ChatbookScripts`Private`$arguments, # =!= "all" && ! StringContainsQ[ #, "=" ] & ] },
        Which[
            Wolfram`ChatbookScripts`Private`$fromFile =!= None && named =!= { },
                Select[ named, KeyExistsQ[ Wolfram`ChatbookScripts`Private`$saved, # ] & ],
            Wolfram`ChatbookScripts`Private`$fromFile =!= None,
                Keys @ Wolfram`ChatbookScripts`Private`$saved,
            named =!= { }, named,
            MemberQ[ Wolfram`ChatbookScripts`Private`$arguments, "all" ],
                DeleteDuplicates @ Join[
                    Wolfram`ChatbookScripts`Private`$models,
                    Sort @ Wolfram`ChatbookScripts`Private`listedModels[ ]
                ],
            True, Wolfram`ChatbookScripts`Private`$models
        ]
    ];

(* When OpenAI's side was probed: today, or for saved records their own "ProbeDate" (older records have none, so the
   file's date stands in): *)
Wolfram`ChatbookScripts`Private`$probeDate =
    If[ Wolfram`ChatbookScripts`Private`$fromFile === None,
        DateString[ "ISODate" ],
        Lookup[
            First[ Values @ Wolfram`ChatbookScripts`Private`$saved, <| |> ],
            "ProbeDate",
            DateString[ FileDate @ ExpandFileName @ Wolfram`ChatbookScripts`Private`$fromFile, "ISODate" ]
        ]
    ];

Wolfram`ChatbookScripts`Private`$compareDir = Wolfram`ChatbookScripts`Private`argument[ "compare" ];

Print[ "Chatbook loaded from: ", PacletObject[ "Wolfram/Chatbook" ][ "Location" ] ];
If[ Wolfram`ChatbookScripts`Private`$fromFile =!= None,
    Print[
        "OpenAI's side read from ", Wolfram`ChatbookScripts`Private`$fromFile,
        " (probed ", Wolfram`ChatbookScripts`Private`$probeDate, "); no API calls are made."
    ]
];
Print[ "" ];
Wolfram`ChatbookScripts`Private`row @ { "model", "endpoint", "resolves to", "levels", "default" };

Wolfram`ChatbookScripts`Private`$thisSide =
    Wolfram`ChatbookScripts`Private`chatbookSide[
        Wolfram`ChatbookScripts`Private`$thisDir,
        Wolfram`ChatbookScripts`Private`$checked
    ];

Wolfram`ChatbookScripts`Private`$compareModels =
    If[ Wolfram`ChatbookScripts`Private`$compareDir === None,
        AssociationMap[ Missing[ "NotCompared" ] &, Wolfram`ChatbookScripts`Private`$checked ],
        Wolfram`ChatbookScripts`Private`chatbookSide[
            Wolfram`ChatbookScripts`Private`$compareDir,
            Wolfram`ChatbookScripts`Private`$checked
        ][ "Models" ]
    ];

Wolfram`ChatbookScripts`Private`$results =
    Wolfram`ChatbookScripts`Private`check[
        #,
        Wolfram`ChatbookScripts`Private`$thisSide[ "Models" ],
        Wolfram`ChatbookScripts`Private`$compareModels,
        Wolfram`ChatbookScripts`Private`$saved,
        Wolfram`ChatbookScripts`Private`$probeDate
    ] & /@ Wolfram`ChatbookScripts`Private`$checked;

Replace[
    Wolfram`ChatbookScripts`Private`argument[ "out" ],
    file_String :> (
        Put[ Wolfram`ChatbookScripts`Private`$results, file ];
        Print[ "\nResults written to ", file ]
    )
];

Replace[
    Wolfram`ChatbookScripts`Private`argument[ "developer" ],
    file_String :> (
        Wolfram`ChatbookScripts`Private`writeDeveloperFile[
            ExpandFileName @ file,
            Wolfram`ChatbookScripts`Private`$results,
            Wolfram`ChatbookScripts`Private`$thisSide,
            Wolfram`ChatbookScripts`Private`$probeDate
        ];
        Print[ "\nDeveloper data file written to ", file ]
    )
];

Print[ "\nDone. This script only reports data; it does not compare against or modify any Chatbook setting." ];

Exit[ 0 ]
