(* ::**************************************************************************************************************:: *)
(* ResolvedReasoningDefault.wl

   Helper for Scripts/CheckReasoningEfforts.wls, run as a subprocess so it can load a branch's
   Chatbook (and the paclet directories it needs) independently of the caller's own kernel.

   Usage:
       wolframscript -f Scripts/ResolvedReasoningDefault.wl <ChatbookDir> <model> [<model> ...]

   Prints one WL expression to stdout: an Association from each model name to the "Reasoning"
   setting Chatbook resolves for it (what Chatbook would actually send when "Reasoning" is
   Automatic), or a Missing[ ... ] / $Failed when the model or the setting cannot be resolved.
*)
dir = $ScriptCommandLine[[ 2 ]];
models = Drop[ $ScriptCommandLine, 2 ];

(* The Responses-endpoint gate ($responsesAPIAvailable) needs a modern-enough LLMFunctions and LLMConnections; load the
   working-tree copies so both branches are compared under the same paclet versions rather than whatever is installed: *)
Quiet @ PacletDirectoryLoad[ "/Users/meng/WorkSpace-mengmaclap/Wolfram/AIDev/LLMFunctions/LLMFunctions" ];
Quiet @ PacletDirectoryLoad[ "/Users/meng/WorkSpace-mengmaclap/Wolfram/AIDev/LLMConnections/LLMConnections" ];
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
