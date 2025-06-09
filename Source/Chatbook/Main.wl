(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Declare Symbols*)
`$AutomaticAssistance;
`$AvailableTools;
`$ChatAbort;
`$ChatbookContexts;
`$ChatbookFilesDirectory;
`$ChatbookNames;
`$ChatbookProtectedNames;
`$ChatEvaluationCell;
`$ChatHandlerData;
`$ChatNotebookEvaluation;
`$ChatPost;
`$ChatPre;
`$ChatTimingData;
`$ContentSuggestions;
`$CurrentChatSettings;
`$DefaultChatHandlerFunctions;
`$DefaultChatProcessingFunctions;
`$DefaultModel;
`$DefaultToolOptions;
`$DefaultTools;
`$IncludedCellWidget;
`$InlineChat;
`$InstalledTools;
`$LastChatbookFailure;
`$LastChatbookFailureText;
`$LastInlineReferenceCell;
`$NotebookAssistanceInputs;
`$RelatedDocumentationSources;
`$SandboxKernel;
`$ToolFunctions;
`$WorkspaceChat;
`$WorkspaceChatInput;
`AbsoluteCurrentChatSettings;
`AddChatToSearchIndex;
`AppendURIInstructions;
`BasePrompt;
`CachedBoxes;
`CellToChatMessage;
`CellToString;
`Chatbook;
`ChatbookAction;
`ChatbookFilesDirectory;
`ChatCellEvaluate;
`ChatMessageToCell;
`ConvertChatNotebook;
`CreateChatDrivenNotebook;
`CreateChatNotebook;
`CurrentChatSettings;
`DeleteChat;
`DisplayBase64Boxes;
`EnableNotebookAssistance;
`ExplodeCell;
`FormatChatOutput;
`FormatToolCall;
`FormatToolResponse;
`FormatWolframAlphaPods;
`GenerateChatTitle;
`GenerateChatTitleAsynchronous;
`GetAttachments;
`GetChatHistory;
`GetExpressionURI;
`GetExpressionURIs;
`GetFocusedNotebook;
`InlineTemplateBoxes;
`InstallVectorDatabases;
`InvalidateServiceCache;
`ListSavedChats;
`LoadChat;
`LogChatTiming;
`MakeExpressionURI;
`ProcessNotebookForRAG;
`RebuildChatSearchIndex;
`RegisterVectorDatabase;
`RelatedDocumentation;
`RelatedWolframAlphaResults;
`RelatedWolframAlphaQueries;
`RemoveChatFromSearchIndex;
`SandboxLinguisticAssistantData;
`SaveAsChatNotebook;
`SaveChat;
`SearchChats;
`SetModel;
`SetToolOptions;
`ShowCodeAssistance;
`ShowContentSuggestions;
`ShowNotebookAssistance;
`SourceNotebookObjectInformation;
`StringToBoxes;
`ToggleChatInclusion;
`ToggleCloudNotebookAssistantMenu;
`WolframLanguageToolEvaluate;
`WriteChatOutputCell;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Begin Private Context*)
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`Common`" ];

(* Avoiding context aliasing due to bug 434990: *)
Needs[ "GeneralUtilities`" -> None ];

(* Clear subcontexts from `$Packages` to force `Needs` to run again: *)
WithCleanup[
    Unprotect @ $Packages,
    $Packages = Select[ $Packages, Not @* StringStartsQ[ "Wolfram`Chatbook`"~~__~~"`" ] ],
    Protect @ $Packages
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Usage Messages*)
GeneralUtilities`SetUsage[ CreateChatNotebook, "\
CreateChatNotebook[] creates an empty chat notebook and opens it in the front end.\
" ];

GeneralUtilities`SetUsage[ Chatbook, "\
Chatbook is a symbol for miscellaneous chat notebook messages.\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Files*)
$ChatbookContexts = {
    "Wolfram`Chatbook`",
    "Wolfram`Chatbook`Actions`",
    "Wolfram`Chatbook`ChatbookFiles`",
    "Wolfram`Chatbook`ChatGroups`",
    "Wolfram`Chatbook`ChatHistory`",
    "Wolfram`Chatbook`ChatMessages`",
    "Wolfram`Chatbook`ChatMessageToCell`",
    "Wolfram`Chatbook`ChatModes`",
    "Wolfram`Chatbook`ChatState`",
    "Wolfram`Chatbook`ChatTitle`",
    "Wolfram`Chatbook`CloudToolbar`",
    "Wolfram`Chatbook`CodeCheck`",
    "Wolfram`Chatbook`ColorData`",
    "Wolfram`Chatbook`Common`",
    "Wolfram`Chatbook`ConvertChatNotebook`",
    "Wolfram`Chatbook`CreateChatNotebook`",
    "Wolfram`Chatbook`Dialogs`",
    "Wolfram`Chatbook`Dynamics`",
    "Wolfram`Chatbook`Errors`",
    "Wolfram`Chatbook`ErrorUtils`",
    "Wolfram`Chatbook`Explode`",
    "Wolfram`Chatbook`Feedback`",
    "Wolfram`Chatbook`Formatting`",
    "Wolfram`Chatbook`FrontEnd`",
    "Wolfram`Chatbook`Graphics`",
    "Wolfram`Chatbook`Handlers`",
    "Wolfram`Chatbook`InlineReferences`",
    "Wolfram`Chatbook`LLMUtilities`",
    "Wolfram`Chatbook`Menus`",
    "Wolfram`Chatbook`Models`",
    "Wolfram`Chatbook`PersonaManager`",
    "Wolfram`Chatbook`Personas`",
    "Wolfram`Chatbook`PreferencesContent`",
    "Wolfram`Chatbook`PreferencesUtils`",
    "Wolfram`Chatbook`PromptGenerators`",
    "Wolfram`Chatbook`Prompting`",
    "Wolfram`Chatbook`ResourceInstaller`",
    "Wolfram`Chatbook`Sandbox`",
    "Wolfram`Chatbook`Search`",
    "Wolfram`Chatbook`SendChat`",
    "Wolfram`Chatbook`Serialization`",
    "Wolfram`Chatbook`Services`",
    "Wolfram`Chatbook`Settings`",
    "Wolfram`Chatbook`Storage`",
    "Wolfram`Chatbook`TeXBoxes`",
    "Wolfram`Chatbook`ToolManager`",
    "Wolfram`Chatbook`Tools`",
    "Wolfram`Chatbook`UI`",
    "Wolfram`Chatbook`Utils`"
};

Scan[ Needs[ # -> None ] &, $ChatbookContexts ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Names*)
$ChatbookNames := $ChatbookNames =
    Block[ { $Context, $ContextPath },
        Union[ Names[ "Wolfram`Chatbook`*" ], Names[ "Wolfram`Chatbook`*`*" ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Protected Symbols*)
$ChatbookProtectedNames = "Wolfram`Chatbook`" <> # & /@ {
    "$AutomaticAssistance",
    "$ChatbookContexts",
    "$ChatbookFilesDirectory",
    "$ChatNotebookEvaluation",
    "$ChatTimingData",
    "$ContentSuggestions",
    "$CurrentChatSettings",
    "$DefaultChatHandlerFunctions",
    "$DefaultChatProcessingFunctions",
    "$DefaultModel",
    "$DefaultToolOptions",
    "$DefaultTools",
    "$InlineChat",
    "$InstalledTools",
    "$LastChatbookFailure",
    "$LastChatbookFailureText",
    "$NotebookAssistanceInputs",
    "$ToolFunctions",
    "$WorkspaceChat",
    "AbsoluteCurrentChatSettings",
    "AddChatToSearchIndex",
    "AppendURIInstructions",
    "BasePrompt",
    "CachedBoxes",
    "CellToChatMessage",
    "CellToString",
    "Chatbook",
    "ChatbookAction",
    "ChatbookFilesDirectory",
    "ChatCellEvaluate",
    "ChatMessageToCell",
    "ConvertChatNotebook",
    "CreateChatDrivenNotebook",
    "CreateChatNotebook",
    "CurrentChatSettings",
    "DeleteChat",
    "DisplayBase64Boxes",
    "EnableNotebookAssistance",
    "ExplodeCell",
    "FormatChatOutput",
    "FormatToolCall",
    "FormatToolResponse",
    "FormatWolframAlphaPods",
    "GenerateChatTitle",
    "GenerateChatTitleAsynchronous",
    "GetAttachments",
    "GetChatHistory",
    "GetExpressionURI",
    "GetExpressionURIs",
    "GetFocusedNotebook",
    "InlineTemplateBoxes",
    "InstallVectorDatabases",
    "ListSavedChats",
    "LoadChat",
    "LogChatTiming",
    "MakeExpressionURI",
    "ProcessNotebookForRAG",
    "RebuildChatSearchIndex",
    "RegisterVectorDatabase",
    "RelatedDocumentation",
    "RelatedWolframAlphaQueries",
    "RemoveChatFromSearchIndex",
    "SandboxLinguisticAssistantData",
    "SaveAsChatNotebook",
    "SaveChat",
    "SearchChats",
    "SetModel",
    "SetToolOptions",
    "ShowCodeAssistance",
    "ShowContentSuggestions",
    "ShowNotebookAssistance",
    "SourceNotebookObjectInformation",
    "StringToBoxes",
    "ToggleChatInclusion",
    "WolframLanguageToolEvaluate",
    "WriteChatOutputCell"
};

Protect @@ $ChatbookProtectedNames;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $ChatbookContexts;
    $ChatbookNames;
    SetAttributes[ Evaluate @ Names[ "Wolfram`Chatbook`*" ], ReadProtected ];
];

mxInitialize[ ];

End[ ];
EndPackage[ ];
