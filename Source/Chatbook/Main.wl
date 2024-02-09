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
`$ChatHandlerData;
`$ChatNotebookEvaluation;
`$ChatPost;
`$ChatPre;
`$DefaultChatHandlerFunctions;
`$DefaultChatProcessingFunctions;
`$DefaultModel;
`$DefaultToolOptions;
`$DefaultTools;
`$IncludedCellWidget;
`$InstalledTools;
`$SandboxKernel;
`$ToolFunctions;
`CellToChatMessage;
`Chatbook;
`ChatbookAction;
`ChatCellEvaluate;
`CreateChatDrivenNotebook;
`CreateChatNotebook;
`CurrentChatSettings;
`FormatChatOutput;
`FormatToolCall;
`FormatToolResponse;
`GetChatHistory;
`GetExpressionURI;
`GetExpressionURIs;
`InvalidateServiceCache;
`MakeExpressionURI;
`SetModel;
`SetToolOptions;
`WriteChatOutputCell;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Begin Private Context*)
Begin[ "`Private`" ];

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
Block[ { $ContextPath },
    Get[ "Wolfram`Chatbook`Common`"             ];
    Get[ "Wolfram`Chatbook`Settings`"           ];
    Get[ "Wolfram`Chatbook`ErrorUtils`"         ];
    Get[ "Wolfram`Chatbook`Errors`"             ];
    Get[ "Wolfram`Chatbook`CreateChatNotebook`" ];
    Get[ "Wolfram`Chatbook`Dynamics`"           ];
    Get[ "Wolfram`Chatbook`Utils`"              ];
    Get[ "Wolfram`Chatbook`FrontEnd`"           ];
    Get[ "Wolfram`Chatbook`Serialization`"      ];
    Get[ "Wolfram`Chatbook`UI`"                 ];
    Get[ "Wolfram`Chatbook`Sandbox`"            ];
    Get[ "Wolfram`Chatbook`Tools`"              ];
    Get[ "Wolfram`Chatbook`Formatting`"         ];
    Get[ "Wolfram`Chatbook`Prompting`"          ];
    Get[ "Wolfram`Chatbook`Explode`"            ];
    Get[ "Wolfram`Chatbook`ChatGroups`"         ];
    Get[ "Wolfram`Chatbook`ChatMessages`"       ];
    Get[ "Wolfram`Chatbook`Services`"           ];
    Get[ "Wolfram`Chatbook`SendChat`"           ];
    Get[ "Wolfram`Chatbook`Feedback`"           ];
    Get[ "Wolfram`Chatbook`Actions`"            ];
    Get[ "Wolfram`Chatbook`Menus`"              ];
    Get[ "Wolfram`Chatbook`ResourceInstaller`"  ];
    Get[ "Wolfram`Chatbook`Personas`"           ];
    Get[ "Wolfram`Chatbook`InlineReferences`"   ];
    Get[ "Wolfram`Chatbook`PreferencesUtils`"   ];
    Get[ "Wolfram`Chatbook`Models`"             ];
    Get[ "Wolfram`Chatbook`Dialogs`"            ];
    Get[ "Wolfram`Chatbook`ToolManager`"        ];
    Get[ "Wolfram`Chatbook`PersonaManager`"     ];
    Get[ "Wolfram`Chatbook`ChatHistory`"        ];
    Get[ "Wolfram`Chatbook`CloudToolbar`"       ];
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Protected Symbols*)
Protect[
    $AutomaticAssistance,
    $ChatNotebookEvaluation,
    $DefaultChatHandlerFunctions,
    $DefaultChatProcessingFunctions,
    $DefaultModel,
    $DefaultToolOptions,
    $DefaultTools,
    $InstalledTools,
    $ToolFunctions,
    CellToChatMessage,
    Chatbook,
    ChatbookAction,
    ChatCellEvaluate,
    CreateChatDrivenNotebook,
    CreateChatNotebook,
    CurrentChatSettings,
    FormatChatOutput,
    FormatToolCall,
    FormatToolResponse,
    GetChatHistory,
    GetExpressionURI,
    GetExpressionURIs,
    MakeExpressionURI,
    SetModel,
    SetToolOptions,
    WriteChatOutputCell
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Subcontexts*)
$ChatbookContexts := $ChatbookContexts = Select[ Contexts[ "Wolfram`Chatbook`*" ], StringFreeQ[ "`Private`" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $ChatbookContexts;
];

End[ ];
EndPackage[ ];
