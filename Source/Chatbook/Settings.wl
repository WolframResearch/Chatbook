(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Settings`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `$defaultChatSettings;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$defaultChatSettings = <|
    "Assistance"               -> Automatic,
    "AutoFormat"               -> True,
    "BasePrompt"               -> Automatic,
    "CellToMessageFunction"    -> CellToChatMessage,
    "ChatContextPreprompt"     -> Automatic,
    "ChatDrivenNotebook"       -> False,
    "ChatFormattingFunction"   -> FormatChatOutput,
    "ChatHistoryLength"        -> 25,
    "DynamicAutoFormat"        -> Automatic,
    "EnableChatGroupSettings"  -> False,
    "EnableLLMServices"        -> Automatic, (* TODO: remove this once LLMServices is widely available *)
    "FrequencyPenalty"         -> 0.1,
    "HandlerFunctions"         :> $DefaultChatHandlerFunctions,
    "HandlerFunctionsKeys"     -> Automatic,
    "IncludeHistory"           -> Automatic,
    "LLMEvaluator"             -> "CodeAssistant",
    "MaxTokens"                -> Automatic,
    "MergeMessages"            -> True,
    "Model"                    :> $DefaultModel,
    "NotebookWriteMethod"      -> Automatic,
    "OpenAIKey"                -> Automatic, (* TODO: remove this once LLMServices is widely available *)
    "PresencePenalty"          -> 0.1,
    "ProcessingFunctions"      :> $DefaultChatProcessingFunctions,
    "ShowMinimized"            -> Automatic,
    "StreamingOutputMethod"    -> Automatic,
    "Temperature"              -> 0.7,
    "ToolOptions"              :> $DefaultToolOptions,
    "Tools"                    -> Automatic,
    "ToolsEnabled"             -> Automatic,
    "TopP"                     -> 1,
    "TrackScrollingWhenPlaced" -> Automatic
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Defaults*)
$ChatPost      = None;
$ChatPre       = None;
$DefaultModel := If[ $VersionNumber >= 13.3, "gpt-4", "gpt-3.5-turbo" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Handler Functions*)
$DefaultChatHandlerFunctions = <|
    "ChatPost" :> $ChatPost,
    "ChatPre"  :> $ChatPre
|>;

$DefaultChatHandlerFunctions // Protect;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Processing Functions*)
$DefaultChatProcessingFunctions = <|
    "CellToMessage"    -> CellToChatMessage, (* TODO: hook up to applyProcessingFunction *)
    "ChatMessages"     -> Identity, (* TODO *)
    "ChatSubmit"       -> Automatic,
    "OutputFormatting" -> FormatChatOutput (* TODO: hook up to applyProcessingFunction *)
|>;

$DefaultChatProcessingFunctions // Protect;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
