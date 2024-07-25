(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];
Needs[ "Wolfram`Chatbook`Serialization`"     ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$usableChatSettingsKeys = {
    "Assistance",
    "ChatHistoryLength",
    "LLMEvaluator",
    "MaxCellStringLength",
    "MergeMessages",
    "Model",
    "Prompts",
    "Temperature",
    "ToolCallFrequency",
    "Tools"
};

$$scope = _NotebookObject | $FrontEnd;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Preferences*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Description*)
$chatPreferencesDescription = "\
Get and set current chat preferences.

Getting chat preferences
* When getting, the `key` parameter is optional and the `value` parameter is unused.
* If `key` is omitted, all available chat preferences will be returned.
* When getting chat preferences, you'll receive the current values along with additional information about possible values.

Setting chat preferences
* When setting, both the `key` parameter and the `value` parameter are required.

Key descriptions
| key                 | type       | default         | description |
| ------------------- | ---------- | --------------- | ----------- |
| Assistance          | boolean    | false           | Whether to enable automatic AI assistance for normal input cell evaluations. |
| ChatHistoryLength   | integer    | 100             | The maximum number of cells to include in chat history. |
| LLMEvaluator        | string     | 'CodeAssistant' | The name of the LLM evaluator (aka persona) to use for chat. Use the 'get' action for available names. |
| MaxCellStringLength | integer    | 0               | The maximum number of characters to include in a cell's string representation. A 0 means determine automatically. |
| MergeMessages       | boolean    | true            | Whether to merge consecutive messages from the same user into a single message. |
| Model               | string     | 'gpt-4'         | The name of the model to use for AI assistance. |
| Prompts             | [ string ] | [ ]             | A list of instructions to append to the system prompt. |
| Temperature         | real       | 0.7             | The temperature to use for the LLM. Values should be a real between 0 and 2. |
| ToolCallFrequency   | real       | 0.5             | The frequency with which to use tools. Values should be a number between 0 and 1. |
| Tools               | [ string ] |                 | The list of currently enabled tools. Use the 'get' action for available names. |
";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatPreferences*)
chatPreferences // beginDefinition;
chatPreferences[ args_Association ] := chatPreferences[ args[ "action" ], args ];
chatPreferences[ "get", args_Association ] := getChatPreferences @ args;
chatPreferences[ "set", args_Association ] := setChatPreferences @ args;
chatPreferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getChatPreferences*)
getChatPreferences // beginDefinition;

getChatPreferences[ as_Association ] :=
    getChatPreferences[ toScope @ as[ "scope" ], as[ "key" ] ];

getChatPreferences[ scope: $$scope, key_String ] :=
    CurrentChatSettings[ scope, key ];

(* TODO: format as JSON *)
getChatPreferences[ scope: $$scope, _Missing ] :=
    KeyTake[ CurrentChatSettings @ scope, $usableChatSettingsKeys ];

getChatPreferences[ args___ ] :=
    Failure[
        "NotImplemented",
        <| "MessageTemplate" -> "Method is not implemented yet.", "MessageParameters" -> { args } |>
    ];

getChatPreferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setChatPreferences*)
setChatPreferences // beginDefinition;
setChatPreferences[ as_Association ] := setChatPreferences[ as[ "scope" ], as[ "key" ], as[ "value" ] ];
setChatPreferences[ scope_, key_, value_ ] := setChatPreferences0[ toScope @ scope, key, interpretValue[ key, value ] ];
setChatPreferences // endDefinition;

setChatPreferences0 // beginDefinition;
setChatPreferences0[ failure_Failure, key_, value_ ] := failure;
setChatPreferences0[ scope_, key_, failure_Failure ] := failure;
setChatPreferences0[ scope_, key_, value_          ] := setChatPreferences1[ scope, key, value ];
setChatPreferences0 // endDefinition;

setChatPreferences1 // beginDefinition;
setChatPreferences1[ scope: $FrontEnd|_NotebookObject, key_String, value: Except[ _Failure ] ] := (
    CurrentChatSettings[ scope, key ] = value
);
setChatPreferences1 // endDefinition;

(* TODO: return something indicating success instead of the value *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*interpretValue*)
interpretValue // beginDefinition;
interpretValue[ key_String, value_String ] := $interpreters[ key ][ value ];
interpretValue // endDefinition;

$interpreters = Interpreter /@ <|
    "Assistance"          -> "Boolean",
    "ChatHistoryLength"   -> "Integer",
    "LLMEvaluator"        -> interpretLLMEvaluator,
    "MaxCellStringLength" -> "Integer",
    "MergeMessages"       -> "Boolean",
    "Model"               -> interpretModel,
    "Prompts"             -> RepeatingElement[ "String" ],
    "Temperature"         -> Restricted[ "Number", { 0, 2 } ],
    "ToolCallFrequency"   -> Restricted[ "Number", { 0, 1 } ],
    "Tools"               -> interpretTools
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*interpretLLMEvaluator*)
interpretLLMEvaluator // beginDefinition;

interpretLLMEvaluator[ name_String ] :=
    With[ { personas = Keys @ GetCachedPersonaData[ ] },
        If[ MemberQ[ personas, name ],
            name,
            Failure[
                "InvalidLLMEvaluator",
                <|
                    "MessageTemplate"   -> "`1` is not among the list of available personas: `2`",
                    "MessageParameters" -> personas
                |>
            ]
        ]
    ];

interpretLLMEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*interpretModel*)
interpretModel // beginDefinition;

interpretModel[ name_String ] :=
    With[ { models = Select[ getModelList[ ], chatModelQ ] },
        If[ MemberQ[ models, ToLowerCase @ name ],
            ToLowerCase @ name,
            Failure[
                "InvalidModel",
                <|
                    "MessageTemplate"   -> "`1` is not among the list of available models: `2`",
                    "MessageParameters" -> models
                |>
            ]
        ]
    ];

interpretModel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*interpretTools*)
interpretTools // beginDefinition;

interpretTools[ name_String ] :=
    With[ { tools = Keys @ $AvailableTools },
        If[ MemberQ[ tools, name ],
            name,
            Failure[
                "InvalidTool",
                <|
                    "MessageTemplate"   -> "`1` is not among the list of available tools: `2`",
                    "MessageParameters" -> tools
                |>
            ]
        ]
    ];

interpretTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toScope*)
toScope // beginDefinition;
toScope[ "global"        ] := $FrontEnd;
toScope[ "notebook"      ] := EvaluationNotebook[ ];
toScope[ _Missing        ] := toScope[ "notebook" ];
toScope[ failure_Failure ] := failure;
toScope // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setPrefChatAssistance*)
setPrefChatAssistance // beginDefinition;
setPrefChatAssistance[ scope: $$scope, value: True|False ] := CurrentChatSettings[ scope, "Assistance" ] = value;
setPrefChatAssistance[ scope_, failure_Failure ] := failure;
setPrefChatAssistance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setPrefModel*)
setPrefModel // beginDefinition;
setPrefModel[ scope: $$scope, value_String ] := CurrentChatSettings[ scope, "Model" ] = value;
setPrefModel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
