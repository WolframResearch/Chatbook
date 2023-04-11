(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AIAssistant`" ];
Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$defaultAIAssistantSettings := <|
    "AIAssistantNotebook" -> True,
    "AssistantIcon"       -> Automatic,
    "AssistantTheme"      -> "Generic",
    "AutoFormat"          -> True,
    "ChatHistoryLength"   -> 25,
    "DynamicAutoFormat"   -> Automatic,
    "FrequencyPenalty"    -> 0.1,
    "MaxTokens"           -> Automatic,
    "MergeMessages"       -> True,
    "Model"               -> "gpt-3.5-turbo",
    "OpenAIKey"           -> Automatic,
    "PresencePenalty"     -> 0.1,
    "RolePrompt"          -> Automatic,
    "ShowMinimized"       -> Automatic,
    "Temperature"         -> 0.7,
    "TopP"                -> 1
|>;

$birdChatLoaded = True;
$maxChatCells   = $defaultAIAssistantSettings[ "ChatHistoryLength" ];

$$externalLanguage = "Java"|"Julia"|"Jupyter"|"NodeJS"|"Octave"|"Python"|"R"|"Ruby"|"Shell"|"SQL"|"SQL-JDBC";

$externalLanguageRules = Flatten @ {
    "JS"         -> "NodeJS",
    "Javascript" -> "NodeJS",
    "NPM"        -> "NodeJS",
    "Node"       -> "NodeJS",
    "Bash"       -> "Shell",
    "SH"         -> "Shell",
    Cases[ $$externalLanguage, lang_ :> (lang -> lang) ]
};

$closedBirdCellOptions = Sequence[
    CellMargins     -> -2,
    CellOpen        -> False,
    CellFrame       -> 0,
    ShowCellBracket -> False
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];