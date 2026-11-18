(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* How long one blob takes to collapse, and how long the handoff waits for the sidebar before giving up: *)
$handoffBlobDuration   = 0.35;
$handoffSidebarTimeout = 30;

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
   what to hand off; the handoff itself runs in a scheduled task once the chat has stopped ("SendToolResponse" ->
   False below ends it), since it deletes the chat's own input and output cells. *)
notebookEditHandoff // beginDefinition;

notebookEditHandoff[ as_Association ] := Enclose[
    Module[ { inputCell, nbo, outputCell, input },
        inputCell  = ConfirmMatch[ $ChatEvaluationCell, _CellObject, "InputCell" ];
        nbo        = ConfirmMatch[ parentNotebook @ inputCell, _NotebookObject, "Notebook" ];
        outputCell = Replace[ $lastCellObject, Except[ _CellObject ] -> Nothing ];
        input      = handoffInput[ inputCell, as ];
        SessionSubmit @ ScheduledTask[
            startChatbarHandoff[ nbo, { inputCell, outputCell }, input ],
            { 0.1 }
        ];
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
(* The chat has stopped by now: collapse blobs over its input and output cells, remove them, open the sidebar with
   notebook editing switched on, and poll until the sidebar is ready for the prompt. The sidebar initializes
   asynchronously on its first open, so the polling task waits for its cell, its settings, and the editing switch: *)
startChatbarHandoff // beginDefinition;

startChatbarHandoff[ nbo_NotebookObject, cells: { ___CellObject }, input_ ] := Enclose[
    Module[ { id },
        flashCellBlobs @ cells;
        NotebookDelete @ cells;
        ShowNotebookAssistance[ nbo, "Sidebar", "ChatNotebookSettings" -> <| "NotebookEditing" -> True |> ];
        id = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];
        $chatbarHandoffs[ id ] = <| "Notebook" -> nbo, "Input" -> input, "Started" -> AbsoluteTime[ ] |>;
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

(* The task can fire once more while the handoff's last step is removing it: *)
chatbarHandoffStep[ id_String ] /; ! KeyExistsQ[ $chatbarHandoffs, id ] := Null;

chatbarHandoffStep[ id_String ] := Enclose[
    Module[ { data, nbo, sidebarCell },
        data        = ConfirmBy[ $chatbarHandoffs[ id ], AssociationQ, "Data" ];
        nbo         = data[ "Notebook" ];
        sidebarCell = sidebarCellObject @ nbo;
        Which[
            AbsoluteTime[ ] - data[ "Started" ] > $handoffSidebarTimeout,
                endChatbarHandoff @ id,
            ! MatchQ[ sidebarCell, _CellObject ],
                Null, (* the sidebar is still opening *)
            CurrentValue[ sidebarCell, { TaggingRules, "ChatNotebookSettings", "SidebarChat" } ] === Inherited,
                Null, (* the sidebar has not initialized its settings yet *)
            True,
                endChatbarHandoff @ id;
                (* ShowNotebookAssistance requested the editing switch, but only the sidebar's asynchronous
                   initialization applies it, so make sure here before the prompt goes in: *)
                If[ ! TrueQ @ CurrentValue[ sidebarCell, { TaggingRules, "ChatNotebookSettings", "NotebookEditing" } ],
                    CurrentChatSettings[ sidebarCell, "NotebookEditing" ] = True
                ];
                submitHandoffInput[ nbo, sidebarCell, data[ "Input" ] ]
        ]
    ],
    throwInternalFailure
];

chatbarHandoffStep // endDefinition;

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
(* The same prompt goes into the sidebar's chat, which routes it to the notebook-editing agent (the editing switch is
   on by now). The blob on the new message cell is flashed from a scheduled task, once the front end has laid the
   cell out: *)
submitHandoffInput // beginDefinition;

submitHandoffInput[ nbo_NotebookObject, sidebarCell_CellObject, input_ ] := Module[ { cellObject },
    evaluateSidebarChat[ nbo, sidebarCell, input, Dynamic @ cellObject ];
    SessionSubmit @ ScheduledTask[ flashCellBlobs @ lastSidebarUserMessageCells @ sidebarCell, { 0.2 } ]
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
