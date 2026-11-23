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
    "GetSelection"   -> "nb_selection",
    "EditInCell"     -> "nb_edit",
    "SetCells"       -> "nb_set",
    "InsertCells"    -> "nb_insert",
    "DeleteCells"    -> "nb_delete",
    "ShowChanges"    -> "nb_show",
    "CloseNotebook"  -> "nb_close"
|>;

(* The machine names that differ from toolDefaultData's: toMachineToolName gives "edit_incell" for EditInCell, whose
   canonical name "EditIncell" is not its key, so getToolByName would not find it *)
$notebookToolNames = <| "EditInCell" -> "edit_in_cell" |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Specs*)

(* The notebook editing tools ($notebookToolSpecs: ListNotebooks, OpenNotebook, GetOutline, ReadCells, SearchNotebook,
   GetSelection, EditInCell, SetCells, InsertCells, DeleteCells, ShowChanges, CloseNotebook). They edit the user's
   notebooks, so they are only enabled in the sidebar and the Notebook Assistant window, on 16.0+ with a front end that
   has the agent notebook packets (the cheap checks first). *)
KeyValueMap[
    Function[ { name, spec },
        $defaultChatTools0[ name ] = <|
            toolDefaultData[ name ],
            "Name"               -> Lookup[ $notebookToolNames, name, toMachineToolName @ name ],
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
