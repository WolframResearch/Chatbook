(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Icon*)
$wolframLanguageEvaluatorIcon = chatbookIcon[ "ToolIconWolframLanguageEvaluator", False ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Description*)
$wolframLanguageEvaluatorDescription = "\
Evaluate Wolfram Language code for the user in a separate kernel. \
The user does not automatically see the result. \
Do not ask permission to evaluate code. \
You must include the result in your response in order for them to see it. \
If a formatted result is provided as a markdown link, use that in your response instead of typing out the output. \
The evaluator supports interactive content such as Manipulate. \
You have read access to local files.
Parse natural language input with `\[FreeformPrompt][\"query\"]`, which is analogous to ctrl-= input in notebooks. \
Natural language input is parsed before evaluation, so it works like macro expansion. \
You should ALWAYS use this natural language input to obtain things like `Quantity`, `DateObject`, `Entity`, etc.
";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "WolframLanguageEvaluator" ] = <|
    toolDefaultData[ "WolframLanguageEvaluator" ],
    "ShortName"          -> "wl",
    "Icon"               -> $wolframLanguageEvaluatorIcon,
    "Description"        -> $wolframLanguageEvaluatorDescription,
    "Enabled"            :> ! TrueQ @ $AutomaticAssistance,
    "FormattingFunction" -> sandboxFormatter,
    "Function"           -> sandboxEvaluate,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "code" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Wolfram Language code to evaluate",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*wolframLanguageEvaluator*)
wolframLanguageEvaluator // beginDefinition;

wolframLanguageEvaluator[ code_String ] :=
    Block[ { $ChatNotebookEvaluation = True }, wolframLanguageEvaluator[ code, sandboxEvaluate @ code ] ];

wolframLanguageEvaluator[ code_, result_Association ] :=
    KeyTake[ result, { "Result", "String" } ];

wolframLanguageEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
