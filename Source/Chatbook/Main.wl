(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Declare Symbols*)
`$ChatContextCellStyles;
`$ChatInputPost;
`$ChatSystemPre;
`$DefaultChatInputPost;
`$DefaultChatSystemPre;
`$ChatPost;
`$ChatPre;
`$DefaultModel;
`$DefaultToolOptions;
`$DefaultTools;
`$InstalledTools;
`$ToolFunctions;
`Chatbook;
`ChatbookAction;
`CreateChatNotebook;
`FormatToolResponse;
`GetExpressionURI;
`GetExpressionURIs;
`MakeExpressionURI;
`SetModel;
`SetToolOptions;

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

GeneralUtilities`SetUsage[ $ChatSystemPre, "\
$ChatSystemPre is a string that is prepended to the beginning of a chat input as the \"system\" role.
Overriding this value may cause some Chatbook functionality to behave unexpectedly.\
" ];

(* TODO: Rename this to $ChatUserPost *)
GeneralUtilities`SetUsage[ $ChatInputPost, "\
$ChatInputPost is a string that is appended to the end of a chat input.\
" ];

GeneralUtilities`SetUsage[ $DefaultChatSystemPre, "\
$DefaultChatSystemPre is the default value of $ChatSystemPre\
" ];

GeneralUtilities`SetUsage[ $DefaultChatInputPost, "\
$ChatInputPost is the default value of $ChatInputPost\
" ];

GeneralUtilities`SetUsage[ $ChatContextCellStyles, "\
$ChatContextCellStyles specifies additional cell styles to include as context to a chat input.
Cells with one of the built-in chat cell styles are always included as context.\
" ];

GeneralUtilities`SetUsage[ Chatbook, "\
Chatbook is a symbol for miscellaneous chat notebook messages.\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Files*)
Block[ { $ContextPath },
    Get[ "Wolfram`Chatbook`Common`"               ];
    Get[ "Wolfram`Chatbook`Debug`"                ];
    Get[ "Wolfram`Chatbook`ErrorUtils`"           ];
    Get[ "Wolfram`Chatbook`Errors`"               ];
    Get[ "Wolfram`Chatbook`CreateChatNotebook`"   ];
    Get[ "Wolfram`Chatbook`Dynamics`"             ];
    Get[ "Wolfram`Chatbook`Streaming`"            ];
    Get[ "Wolfram`Chatbook`Utils`"                ];
    Get[ "Wolfram`Chatbook`FrontEnd`"             ];
    Get[ "Wolfram`Chatbook`Serialization`"        ];
    Get[ "Wolfram`Chatbook`UI`"                   ];
    Get[ "Wolfram`Chatbook`Sandbox`"              ];
    Get[ "Wolfram`Chatbook`Tools`"                ];
    Get[ "Wolfram`Chatbook`Formatting`"           ];
    Get[ "Wolfram`Chatbook`Prompting`"            ];
    Get[ "Wolfram`Chatbook`Explode`"              ];
    Get[ "Wolfram`Chatbook`ChatGroups`"           ];
    Get[ "Wolfram`Chatbook`SendChat`"             ];
    Get[ "Wolfram`Chatbook`Actions`"              ];
    Get[ "Wolfram`Chatbook`Menus`"                ];
    Get[ "Wolfram`Chatbook`ResourceInstaller`"    ];
    Get[ "Wolfram`Chatbook`Personas`"             ];
    Get[ "Wolfram`Chatbook`InlineReferences`"     ];
    Get[ "Wolfram`Chatbook`ServerSentEventUtils`" ];
    Get[ "Wolfram`Chatbook`PreferencesUtils`"     ];
    Get[ "Wolfram`Chatbook`Models`"               ];
    Get[ "Wolfram`Chatbook`Dialogs`"              ];
    Get[ "Wolfram`Chatbook`ToolManager`"          ];
    Get[ "Wolfram`Chatbook`PersonaManager`"       ];
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Set Definitions*)

(* This preprompting to wrap code in ``` is necessary for the parsing of code
   blocks into printed output cells to work. *)
$DefaultChatSystemPre  = "Wrap any code using ```. Tag code blocks with the name of the programming language.";
$DefaultChatInputPost  = "";
$ChatSystemPre         = $DefaultChatSystemPre;
$ChatInputPost         = $DefaultChatInputPost;
$ChatContextCellStyles = <| |>;
$ChatPost      = None;
$ChatPre       = None;
$DefaultModel := If[ $VersionNumber >= 13.3, "gpt-4", "gpt-3.5-turbo" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
