(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];
Needs[ "Wolfram`Chatbook`ACP`Common`"       ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* How long one blob takes to collapse, and how long the handoff waits for the sidebar before giving up: *)
$handoffBlobDuration   = 0.35;
$handoffSidebarTimeout = 30;

(* How many consecutive polling ticks (0.25 s apart) a phase's cells must look ready and quiet before it writes.
   The kernel's view of the front end's formatting state is a snapshot, so a single quiet reading can still fall
   inside the sidebar's first format burst; a state that holds for a second has settled: *)
$handoffSettleTicks = 4;

(* How many ticks the sidebar's new message cell gets for its layout before its blob; this also lets the chat
   cells' blob finish first, since the front end keeps one visual cue at a time: *)
$handoffFlashTicks = 2;

(* handoff id -> the handoff's notebook, input, and polling task *)
If[ ! AssociationQ @ $chatbarHandoffs, $chatbarHandoffs = <| |> ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Description*)
$notebookEditHandoffDescription = "\
Hand the user's message off to the notebook-editing assistant in the notebook's sidebar. \
Call this tool, before answering, whenever the message asks you to change the notebook itself: \
writing, deleting, moving, or rewriting cells or sections, or changing text or code that is in the notebook. \
Examples: 'delete the first three cells in this notebook', \
'change all mentions of Paris in the notebook to London', \
'would you be able to add a section on Laguerre polynomials?'. \
Do not call it when the message only asks a question or asks for an explanation or a computation that leaves \
the notebook's content alone, such as 'could you explain what the Bessel function of the first order is used for?'. \
Once this tool is called, the sidebar's assistant answers the request, so do not answer it yourself.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "NotebookEditHandoff" ] = <|
    toolDefaultData[ "NotebookEditHandoff" ],
    "ShortName"          -> "nb_edit_handoff",
    "Description"        -> $notebookEditHandoffDescription,
    "Enabled"            :> TrueQ @ $ChatbarChat,
    "Function"           -> notebookEditHandoff,
    "FormattingFunction" -> toolAutoFormatter,
    "Hidden"             -> True,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "request" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The user's notebook-editing request, restated word for word.",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookEditHandoff*)
(* The chatbar's chat calls this when it classifies its prompt as a notebook-editing request. The tool only records
   what to hand off; the handoff itself runs in a polling task once the chat has stopped ("SendToolResponse" ->
   False below ends it), since it deletes the chat's own input and output cells. *)
notebookEditHandoff // beginDefinition;

notebookEditHandoff[ as_Association ] := Enclose[
    Module[ { inputCell, nbo, outputCell, input },
        inputCell  = ConfirmMatch[ $ChatEvaluationCell, _CellObject, "InputCell" ];
        nbo        = ConfirmMatch[ parentNotebook @ inputCell, _NotebookObject, "Notebook" ];
        outputCell = Replace[ $lastCellObject, Except[ _CellObject ] -> Nothing ];
        input      = handoffInput[ inputCell, as ];
        startChatbarHandoff[ nbo, { inputCell, outputCell }, input ];
        <|
            "String"           -> "The request was handed to the notebook-editing assistant in the sidebar.",
            "SendToolResponse" -> False
        |>
    ],
    throwInternalFailure
];

notebookEditHandoff // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handoffInput*)
(* The sidebar gets the same prompt again: the chat input cell's own content when it can be read, and otherwise the
   model's restatement of it from the tool call's parameter: *)
handoffInput // beginDefinition;

handoffInput[ inputCell_CellObject, as_Association ] :=
    Replace[
        NotebookRead @ inputCell,
        {
            Cell[ content_, ___ ] :> content,
            _ :> Replace[ as[ "request" ], Except[ _String? StringQ ] -> "" ]
        }
    ];

handoffInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*startChatbarHandoff*)
(* Records the handoff and starts its polling task; the task does the work once the chat has stopped. The handoff
   runs in three phases, each gated on the front end being done formatting the cells it touches, since a kernel
   write or delete that lands while a cell's contents are formatting corrupts its boxes (the sidebar submit crashed
   the front end this way): "OpenSidebar" opens the sidebar with notebook editing requested, leaving the chat's
   cells in place, so the prompt visibly moves from them into the open sidebar; "Submit" waits for the sidebar (its
   first initialization and format take seconds), collapses blobs over the chat's cells, removes them, and enters
   the prompt; "FlashMessage" blobs the sidebar's new message cell. Every deferred step runs in this one recurring
   task: a one-shot ScheduledTask can deadlock the 15.0.1 kernel's scheduler for good (ACPLink's UPSTREAM-NOTES.md,
   "Kernel scheduler deadlocks", and acp-window.md rule R5), and an overdue one can fire into a main link
   evaluation's front end work, which rule R9 forbids (see chatbarHandoffStep). *)
startChatbarHandoff // beginDefinition;

startChatbarHandoff[ nbo_NotebookObject, cells: { ___CellObject }, input_ ] := Enclose[
    Module[ { id },
        id = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];
        $chatbarHandoffs[ id ] = <|
            "Notebook" -> nbo,
            "Cells"    -> cells,
            "Input"    -> input,
            "Phase"    -> "OpenSidebar",
            "Started"  -> AbsoluteTime[ ]
        |>;
        $chatbarHandoffs[ id, "Task" ] = SessionSubmit @ ScheduledTask[ chatbarHandoffStep @ id, 0.25 ];
        id
    ],
    throwInternalFailure
];

startChatbarHandoff // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarHandoffStep*)
chatbarHandoffStep // beginDefinition;

(* A tick that interrupts a main link evaluation's front end work does nothing (rule R9): its front end calls would
   go over the service link and deadlock against the main link's unread answer (acpMainLinkFrontEndCall). The
   attachment preparation of the prompt this handoff submits runs on the main link exactly that way: *)
chatbarHandoffStep[ _String ] /; acpMainLinkFrontEndCallQ[ ] := Null;

(* The task can fire once more while the handoff's last step is removing it: *)
chatbarHandoffStep[ id_String ] /; ! KeyExistsQ[ $chatbarHandoffs, id ] := Null;

chatbarHandoffStep[ id_String ] := Enclose[
    Module[ { data },
        data = ConfirmBy[ $chatbarHandoffs[ id ], AssociationQ, "Data" ];
        Which[
            AbsoluteTime[ ] - data[ "Started" ] > $handoffSidebarTimeout,
                endChatbarHandoff @ id,
            data[ "Phase" ] === "OpenSidebar",
                handoffOpenSidebarStep[ id, data ],
            data[ "Phase" ] === "Submit",
                handoffSubmitStep[ id, data ],
            True,
                handoffFlashMessageStep[ id, data ]
        ]
    ],
    throwInternalFailure
];

chatbarHandoffStep // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handoffOpenSidebarStep*)
(* The sidebar opens first, so the chat's cells are still in place while it appears and the prompt visibly moves
   from them into it; the docked sidebar cell is a kernel write too, so it waits for the front end to be done
   formatting the chat's cells (the output cell was rewritten when the chat stopped moments ago): *)
handoffOpenSidebarStep // beginDefinition;

handoffOpenSidebarStep[ id_String, data_Association ] :=
    If[ handoffSettledQ @ id,
        ShowNotebookAssistance[ data[ "Notebook" ], "Sidebar", "ChatNotebookSettings" -> <| "NotebookEditing" -> True |> ];
        $chatbarHandoffs[ id, "Phase" ] = "Submit";
        $chatbarHandoffs[ id, "ReadyTicks" ] = 0
    ];

handoffOpenSidebarStep // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handoffDeleteCells*)
(* The chat's output cell recorded when the tool ran can be stale by now, since the streaming output cell is
   replaced when the chat stops, so the live output is the chat-output cell right after the input: *)
handoffDeleteCells // beginDefinition;

handoffDeleteCells[ cells: { inputCell_CellObject, ___ } ] := DeleteDuplicates @ Join[
    cells,
    Select[ { NextCell @ inputCell }, chatOutputStyleQ ]
];

handoffDeleteCells[ cells_List ] := cells;

handoffDeleteCells // endDefinition;

chatOutputStyleQ // beginDefinition;
chatOutputStyleQ[ cell_CellObject ] := MatchQ[ Quiet @ Developer`CellInformation @ cell, KeyValuePattern[ "Style" -> "ChatOutput" ] ];
chatOutputStyleQ[ _ ] := False;
chatOutputStyleQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handoffSubmitStep*)
(* The sidebar initializes asynchronously on its first open, so the polling task waits for its cell, its settings,
   and its formatting to finish; the chat's cells then collapse as the same prompt goes into the sidebar: *)
handoffSubmitStep // beginDefinition;

handoffSubmitStep[ id_String, data_Association ] := Module[ { nbo, sidebarCell },
    nbo         = data[ "Notebook" ];
    sidebarCell = sidebarCellObject @ nbo;
    Which[
        ! MatchQ[ sidebarCell, _CellObject ],
            handoffNotReady @ id, (* the sidebar is still opening *)
        CurrentValue[ sidebarCell, { TaggingRules, "ChatNotebookSettings", "SidebarChat" } ] === Inherited,
            handoffNotReady @ id, (* the sidebar has not initialized its settings yet *)
        ! handoffSettledQ @ id,
            Null, (* ready, but not for long enough yet *)
        True,
            (* ShowNotebookAssistance requested the editing switch, but only the sidebar's asynchronous
               initialization applies it, so make sure here before the prompt goes in: *)
            If[ ! TrueQ @ CurrentValue[ sidebarCell, { TaggingRules, "ChatNotebookSettings", "NotebookEditing" } ],
                CurrentChatSettings[ sidebarCell, "NotebookEditing" ] = True
            ];
            Module[ { cells = handoffDeleteCells @ data[ "Cells" ] },
                flashCellBlobs @ cells;
                NotebookDelete @ cells
            ];
            submitHandoffInput[ nbo, sidebarCell, data[ "Input" ] ];
            $chatbarHandoffs[ id, "Phase" ] = "FlashMessage";
            $chatbarHandoffs[ id, "SidebarCell" ] = sidebarCell;
            $chatbarHandoffs[ id, "ReadyTicks" ] = 0
    ]
];

handoffSubmitStep // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handoffFlashMessageStep*)
(* The blob on the sidebar's new message cell, marking where the prompt landed. It waits $handoffFlashTicks ticks
   with the cell in sight: the front end lays the cell out meanwhile, and the chat cells' blob finishes first: *)
handoffFlashMessageStep // beginDefinition;

handoffFlashMessageStep[ id_String, data_Association ] := Module[ { cells },
    cells = lastSidebarUserMessageCells @ data[ "SidebarCell" ];
    Which[
        cells === { },                              handoffNotReady @ id,
        handoffSettledQ[ id, $handoffFlashTicks ],  endChatbarHandoff @ id; flashCellBlobs @ cells,
        True,                                       Null
    ]
];

handoffFlashMessageStep // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handoffSettledQ*)
(* True once the phase's gates have held for $handoffSettleTicks consecutive ticks; handoffNotReady resets the
   count when a gate fails: *)
handoffSettledQ // beginDefinition;

handoffSettledQ[ id_String ] := handoffSettledQ[ id, $handoffSettleTicks ];

handoffSettledQ[ id_String, required_Integer ] := With[
    { ticks = Replace[ $chatbarHandoffs[ id, "ReadyTicks" ], Except[ _Integer ] -> 0 ] + 1 },
    $chatbarHandoffs[ id, "ReadyTicks" ] = ticks;
    ticks >= required
];

handoffSettledQ // endDefinition;

handoffNotReady // beginDefinition;
handoffNotReady[ id_String ] := ( $chatbarHandoffs[ id, "ReadyTicks" ] = 0; Null );
handoffNotReady // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*endChatbarHandoff*)
endChatbarHandoff // beginDefinition;

endChatbarHandoff[ id_String ] := (
    Quiet @ TaskRemove @ $chatbarHandoffs[ id, "Task" ];
    KeyDropFrom[ $chatbarHandoffs, id ]
);

endChatbarHandoff // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitHandoffInput*)
(* The same prompt goes into the sidebar's chat, which routes it to the notebook-editing agent (the editing switch
   is on by now); the "FlashMessage" phase then blobs the new message cell: *)
submitHandoffInput // beginDefinition;

submitHandoffInput[ nbo_NotebookObject, sidebarCell_CellObject, input_ ] := Module[ { cellObject },
    evaluateSidebarChat[ nbo, sidebarCell, input, Dynamic @ cellObject ]
];

submitHandoffInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*lastSidebarUserMessageCells*)
(* The last user message in the sidebar, as a list for flashCellBlobs: the message cells are inline cells of the
   sidebar's scrolling content cell, found by their tag (a style query on the sidebar cell doesn't reach them): *)
lastSidebarUserMessageCells // beginDefinition;

lastSidebarUserMessageCells[ sidebarCell_CellObject ] :=
    lastSidebarUserMessageCells[
        sidebarCell,
        First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], $Failed ]
    ];

lastSidebarUserMessageCells[ _, scroll_CellObject ] :=
    Replace[
        Select[
            Cells[ scroll, CellTags -> "SidebarTopCell" ],
            MatchQ[ Quiet @ Developer`CellInformation @ #, KeyValuePattern[ "Style" -> "NotebookAssistant`Sidebar`ChatInput" ] ] &
        ],
        { { ___, last_ } :> { last }, _ :> { } }
    ];

lastSidebarUserMessageCells[ _, _ ] := { };

lastSidebarUserMessageCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*flashCellBlobs*)
(* The front end's collapsing-blob cue over each cell's contents: the cells' content has gone somewhere else. One
   call covers all the cells, since the front end keeps only one visual cue at a time. Front ends without the packet
   just show no blob: *)
flashCellBlobs // beginDefinition;
flashCellBlobs[ { } ] := Null;
flashCellBlobs[ cells: { __CellObject } ] :=
    Quiet @ FrontEndExecute @ FrontEnd`FlashCellBlob[ cells, "Duration" -> $handoffBlobDuration ];
flashCellBlobs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
