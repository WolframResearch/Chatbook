(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                     ];
Needs[ "Wolfram`Chatbook`Common`"              ];
Needs[ "Wolfram`Chatbook`Tools`NotebookTools`" ];

(* The tools are implemented in their own context (Tools/NotebookTools.wl): *)
$ChatbookContexts = Union[ $ChatbookContexts, { "Wolfram`Chatbook`Tools`NotebookTools`" } ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* The commands of the Simple tool method: none of them starts with the command of another tool *)
$notebookToolShortNames = <|
    "ListNotebooks"  -> "nb_list",
    "OpenNotebook"   -> "nb_open",
    "GetOutline"     -> "nb_outline",
    "ReadCells"      -> "nb_cells",
    "SearchNotebook" -> "nb_find",
    "CloseNotebook"  -> "nb_close"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Specs*)

(* The notebook editing tools ($notebookToolSpecs: ListNotebooks, OpenNotebook, GetOutline, ReadCells, SearchNotebook,
   CloseNotebook). They read the user's notebooks, so they are only enabled in the
   sidebar and the Notebook Assistant window, on 16.0+ with a front end that makes snapshots (the cheap checks
   first). *)
KeyValueMap[
    Function[ { name, spec },
        $defaultChatTools0[ name ] = <|
            toolDefaultData[ name ],
            "ShortName"          -> $notebookToolShortNames[ name ],
            (* TODO: give these tools their own icons instead of reusing the ones from CreateNotebook *)
            "Icon"               -> $createNotebookIcon,
            "CallIcon"           -> toolCallIconResource[ "CreateNotebook" ],
            "Enabled"            :> TrueQ[ $WorkspaceChat || $SidebarChat ] && notebookToolsSupportedQ[ ],
            "FormattingFunction" -> toolAutoFormatter,
            "Hidden"             -> True,
            "Origin"             -> "BuiltIn",
            spec
        |>
    ],
    $notebookToolSpecs
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
