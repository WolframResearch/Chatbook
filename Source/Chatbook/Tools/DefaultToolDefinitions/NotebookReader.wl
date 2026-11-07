(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$notebookContextDisabledMessage = "\
The user has turned off notebook content for this chat, so their notebook cannot be read. \
Do not call this tool again unless the user turns notebook content back on.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Description*)
$notebookReaderDescription = "\
Read the current content of the user's notebook. \
Notebook content shown earlier in the conversation may be out of date, \
since the user can edit the notebook and move their selection at any time. \
Only call this tool when you actually need the current notebook content to respond. \
Do not call it routinely, and do not call it just because you were told that the notebook or the selection changed.
By default, this gives the cells around the user's current selection. \
Use scope 'all' to read the notebook from the beginning, one page at a time.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "NotebookReader" ] = <|
    toolDefaultData[ "NotebookReader" ],
    "ShortName"          -> "nb_read",
    (* TODO: give this tool its own icons instead of reusing the ones from CreateNotebook *)
    "Icon"               -> $createNotebookIcon,
    "CallIcon"           -> toolCallIconResource[ "CreateNotebook" ],
    "Description"        -> $notebookReaderDescription,
    (* Only the sidebar and the Notebook Assistant window have a user notebook to read: *)
    "Enabled"            :> TrueQ[ $WorkspaceChat || $SidebarChat ],
    "Function"           -> notebookReader,
    "FormattingFunction" -> toolAutoFormatter,
    "Hidden"             -> True,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "scope" -> <|
            "Interpreter" -> { "selection", "all" },
            "Help"        -> "Either 'selection' (default) for the cells around the user's current selection, \
or 'all' for the notebook from the beginning.",
            "Required"    -> False
        |>,
        "offset" -> <|
            "Interpreter" -> "Integer",
            "Default"     -> 1,
            "Help"        -> "Only for scope 'all': the 1-based index of the first cell to read (default 1). \
Use the offset given in a previous result to read the next cells.",
            "Required"    -> False
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookReader*)
notebookReader // beginDefinition;

notebookReader[ as_Association ] := Enclose[
    Module[ { settings },
        settings = ConfirmBy[ $ChatHandlerData[ "ChatNotebookSettings" ], AssociationQ, "Settings" ];
        (* Respect the user's choice to not include notebook content: *)
        If[ TrueQ @ settings[ "AllowSelectionContext" ],
            ConfirmBy[
                readUserNotebook[ settings, notebookReaderScope @ as[ "scope" ], notebookReaderOffset @ as[ "offset" ] ],
                StringQ,
                "Result"
            ],
            $notebookContextDisabledMessage
        ]
    ],
    throwInternalFailure
];

notebookReader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookReaderScope*)
notebookReaderScope // beginDefinition;
notebookReaderScope[ scope_String ] /; ToLowerCase @ StringTrim @ scope === "all" := "all";
notebookReaderScope[ _ ] := "selection";
notebookReaderScope // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookReaderOffset*)
notebookReaderOffset // beginDefinition;
notebookReaderOffset[ offset_Integer? Positive ] := offset;
notebookReaderOffset[ _ ] := 1;
notebookReaderOffset // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
