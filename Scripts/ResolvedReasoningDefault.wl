(* ::**************************************************************************************************************:: *)
(* ResolvedReasoningDefault.wl

   Helper for Scripts/CheckReasoningEfforts.wls, run as a subprocess so it can load a branch's
   Chatbook (and the paclet directories it needs) independently of the caller's own kernel.

   Usage:
       wolframscript -f Scripts/ResolvedReasoningDefault.wl <ChatbookDir> <model> [<model> ...]

   Prints one WL expression to stdout: an Association from each model name to the "Reasoning"
   setting Chatbook resolves for it (what Chatbook would actually send when "Reasoning" is
   Automatic), or a Missing[ ... ] / $Failed when the model or the setting cannot be resolved.

   LLMFunctions and LLMConnections are loaded from checkouts next to the Chatbook checkout this script
   belongs to (see below), or from the installed paclets when a checkout is not there.
*)
dir = $ScriptCommandLine[[ 2 ]];
models = Drop[ $ScriptCommandLine, 2 ];

(* The Responses-endpoint gate ($responsesAPIAvailable) needs a modern-enough LLMFunctions and LLMConnections. Load the
   working-tree copies, assumed to be checked out next to the Chatbook checkout that holds this script, so that every
   checkout CheckReasoningEfforts.wls compares is resolved under the same paclet versions rather than whatever is
   installed:
       <parent>/Chatbook/Scripts/ResolvedReasoningDefault.wl
       <parent>/LLMFunctions/LLMFunctions/PacletInfo.wl
       <parent>/LLMConnections/LLMConnections/PacletInfo.wl
   A missing checkout is reported on stderr, and the installed paclet is used instead. *)
$siblingDirectory = ParentDirectory @ DirectoryName[ $InputFileName, 2 ];
Scan[
    With[ { pacletDir = FileNameJoin @ { $siblingDirectory, #, # } },
        If[ FileExistsQ @ FileNameJoin @ { pacletDir, "PacletInfo.wl" },
            Quiet @ PacletDirectoryLoad @ pacletDir,
            WriteString[ "stderr", "No ", #, " checkout at ", pacletDir, "; using the installed paclet.\n" ]
        ]
    ] &,
    { "LLMFunctions", "LLMConnections" }
];
PacletDirectoryLoad @ dir;
Needs[ "Wolfram`Chatbook`" ];

resolvedReasoning[ model_String ] :=
    Quiet @ Check[
        Wolfram`Chatbook`Common`autoModelSetting[
            <| "Model" -> Wolfram`Chatbook`Common`resolveFullModelSpec @ <| "Service" -> "OpenAI", "Name" -> model |> |>,
            "Reasoning"
        ],
        $Failed
    ];

WriteString[ "stdout", ToString[ AssociationMap[ resolvedReasoning, models ], InputForm ] ];
