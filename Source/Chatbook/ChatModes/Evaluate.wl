(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`Evaluate`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];
Needs[ "Wolfram`Chatbook`ACP`Common`"       ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluate Alternate Chat Inputs*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateWorkspaceChat*)
evaluateWorkspaceChat // beginDefinition;

evaluateWorkspaceChat[ nbo_NotebookObject, Dynamic[ input: _Symbol|_CurrentValue ] ] := Enclose[
    Catch @ Module[ { value, cellObject, result },

        value = input;

        (* The input cell no longer exists, e.g. a send that was queued behind a chat runs after "New Chat" replaced the
           input cell. Its text is in the new input cell, so nothing is sent or cleared (#1719): *)
        If[ value === $Failed, Throw @ Null ];

        (* $WorkspaceChatInput is a kernel-side copy of the input field text, so it is cleared along with the input: *)
        If[ ! validInputStringQ @ value, input = $WorkspaceChatInput = ""; Throw @ Null ];
        $WorkspaceChatInput = "";

        cellObject = ConfirmMatch[ writeWorkspaceChatInputCell[ nbo, Dynamic @ input ], _CellObject, "CellObject" ];
        result = ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ];

        If[ unansweredChatInputQ[ cellObject, result ],
            NotebookDelete @ cellObject;
            (* The input cell may have been moved to the bottom of the window since the chat was sent: *)
            restoreWorkspaceChatInput[ workspaceChatInput @ nbo, value ];
            (* Like "New Chat", an empty window has the input cell at the top. Note: this replaces the input cell, so a
               send that was queued behind this chat isn't sent, though its text is kept in the new input cell (#1719): *)
            If[ Cells @ nbo === { }, moveChatInputToTop @ nbo ]
        ];

        result
    ],
    throwInternalFailure
];

evaluateWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeWorkspaceChatInputCell*)

(* Writes the user message cell for the current input of a workspace window (and clears the input), moves the input field
   to the bottom of the window, and returns the new cell. Shared by the notebook assistance window and agent windows. *)
writeWorkspaceChatInputCell // beginDefinition;

writeWorkspaceChatInputCell[ nbo_NotebookObject, Dynamic[ input: _Symbol|_CurrentValue ] ] := Enclose[
    Catch @ Module[ { uuid, cell, cellObject },

        If[ ! validInputStringQ @ input, input = ""; Throw @ Missing[ "NoInput" ] ];
        uuid = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];
        cell = ConfirmMatch[ workspaceChatInputCellExpr[ input, uuid ], _Cell, "Cell" ];

        input = "";
        SelectionMove[ nbo, After, Notebook, AutoScroll -> True ];
        NotebookWrite[ nbo, cell ];
        moveChatInputToBottom @ nbo;
        cellObject = ConfirmMatch[ First[ Cells[ nbo, CellTags -> uuid ], $Failed ], _CellObject, "CellObject" ];
        setCurrentValue[ cellObject, CellTags, { } ];
        cellObject
    ],
    throwInternalFailure
];

writeWorkspaceChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*workspaceChatInputCellExpr*)

(* The user message cell for the input of a workspace window, tagged with uuid so it can be found after it is written.
   Shared by writeWorkspaceChatInputCell and the addressed write of agent windows (ACP/UI.wl). *)
workspaceChatInputCellExpr // beginDefinition;

workspaceChatInputCellExpr[ input_, uuid_String ] := Cell[
    BoxData @ TemplateBox[
        { Cell[ makeBoxesInputMoreTextLike @ input, Background -> None, Selectable -> True, Editable -> True ] },
        "UserMessageBox"
    ],
    "ChatInput",
    CellTags -> uuid
];

workspaceChatInputCellExpr // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreWorkspaceChatInput*)
restoreWorkspaceChatInput // beginDefinition;

restoreWorkspaceChatInput[ Dynamic[ input_ ], value_ ] :=
    If[ ! validInputStringQ @ input, input = $WorkspaceChatInput = value ];

restoreWorkspaceChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*appendCellToSidebarChat*)
appendCellToSidebarChat // beginDefinition;

appendCellToSidebarChat[ nbo_NotebookObject, sidebarCell_CellObject, cell_Cell, uuid_String ] := Enclose[
    Module[ { scrollablePaneCell, lastDockedCell, chatCells, lastContentCell, cellObject },
        (* find the last top cell, or docked cell if there are no content cells *)
        (* all old top-cells are within an inline cell that scrolls. Overwrite that cell if it exists, otherwise create it anew *)
        scrollablePaneCell = First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], Missing @ "NoScrollingContent" ];
        If[ MissingQ @ scrollablePaneCell,
            lastDockedCell = ConfirmMatch[ Last[ Cells[ sidebarCell, CellTags -> "SidebarDockedCell" ], $Failed ], _CellObject, "SidebarDockedCell" ];
            NotebookWrite[ NotebookLocationSpecifier[ lastDockedCell, "After" ], makeSidebarChatScrollingCell[ nbo, sidebarCell, { cell } ] ];
            scrollablePaneCell = ConfirmMatch[ First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], $Failed ], _CellObject, "UpdatedSidebarScrollableCell" ];
            , (* ELSE *)
            chatCells = Cells[ scrollablePaneCell, CellTags -> "SidebarTopCell" ];
            If[ chatCells === { }, (* rewrite the entire cell if it has no content; this removes the "AskAnything" content *)
                NotebookWrite[ scrollablePaneCell, makeSidebarChatScrollingCell[ nbo, sidebarCell, { cell } ] ];
                scrollablePaneCell = ConfirmMatch[ First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], $Failed ], _CellObject, "NoNewScrollingContentCell" ];
                ,
                lastContentCell = ConfirmMatch[ Last[ chatCells, $Failed ], _CellObject, "NoSidebarScrollingContentCell" ];
                NotebookWrite[ NotebookLocationSpecifier[ lastContentCell, "After" ], cell ]
            ]
        ];

        cellObject = ConfirmMatch[ Last[ Cells[ scrollablePaneCell, CellTags -> uuid ], $Failed ], _CellObject, "SidebarChatInputCellObject" ];
        setCurrentValue[ cellObject, CellTags, "SidebarTopCell" ];
        cellObject
    ],
    throwInternalFailure
];

appendCellToSidebarChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateSidebarChat*)
evaluateSidebarChat // beginDefinition;

(* With the sidebar's Notebook editing switch on, the conversation is the notebook agent's *)
evaluateSidebarChat[ nbo_NotebookObject, sidebarCell_CellObject, input_, Dynamic[ cellObject_ ], field_: None ] /;
    TrueQ @ CurrentChatSettings[ sidebarCell, "NotebookEditing" ] :=
        WithCleanup[ evaluateSidebarAgent[ nbo, sidebarCell, input ], releaseSidebarSelections @ sidebarCell ];

(* The input field is optional, since the sidebar input cell of a front end session that started with an older version
   of Chatbook doesn't give it.
   The sidebar input cell calls this directly, not through ChatbookAction like the workspace chat, so failures in the
   chat are caught here. Otherwise ChatCellEvaluate catches them and gives them as its result, and the ConfirmMatch
   below reports a second (internal) failure that hides where the first one happened (#1639): *)
evaluateSidebarChat[ nbo_NotebookObject, sidebarCell_CellObject, input_, Dynamic[ cellObject_ ], field_: None ] := catchTopAs[ ChatbookAction ] @ Enclose[
    WithCleanup[
        Module[ { text, uuid, cell, result },

            text = makeBoxesInputMoreTextLike @ input;
            uuid = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];

            cell = Cell[
                BoxData @ TemplateBox[
                    { Cell[ text, Background -> None, Selectable -> True, Editable -> True ] },
                    "NotebookAssistant`Sidebar`UserMessageBox"
                ],
                "NotebookAssistant`Sidebar`ChatInput",
                (* If we were writing this CellObject as a top-level cell then we could use ExpressoinUUID to coerce the front end use a pre-specified UUID.
                    However, the side bar is a more complicated Cell within a Cell and in that case the ExpressoinUUID is dropped. *)
                CellTags -> uuid
            ];

            cellObject = appendCellToSidebarChat[ nbo, sidebarCell, cell, uuid ];
            result = ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ];

            If[ unansweredChatInputQ[ cellObject, result ],
                NotebookDelete @ cellObject;
                restoreSidebarChatInput[ field, input ]
            ];

            result
        ],
        releaseSidebarSelections @ sidebarCell
    ],
    throwInternalFailure
];

evaluateSidebarChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreSidebarChatInput*)
restoreSidebarChatInput // beginDefinition;
restoreSidebarChatInput[ Dynamic[ field_ ], input_ ] := If[ ! validInputStringQ @ field, field = input ];
restoreSidebarChatInput[ None, _ ] := Null;
restoreSidebarChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*releaseSidebarSelections*)
(* The selections the sidebar took for a message are released once it has been answered: *)
releaseSidebarSelections // beginDefinition;

releaseSidebarSelections[ sidebarCell_CellObject ] :=
    With[ { selections = CurrentValue[ sidebarCell, { TaggingRules, "CurrentSelections" } ] },
        If[ AssociationQ @ selections, FE`Evaluate @ FEPrivate`ReleaseSelectionObjects @ selections ];
        setCurrentValue[ sidebarCell, { TaggingRules, "CurrentSelections" }, Inherited ]
    ];

releaseSidebarSelections // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sidebar Agent*)

(* The sidebar's conversation while its Notebook editing switch is on: the notebook agent of the ACP window, run as the
   speed trials run it (opencode, the model and effort of the sidebar's NotebookEditingModel and NotebookEditingEffort
   settings, the notebook tools over MCP, the notebook attached), with that window hidden as the engine. The sidebar
   draws each turn from the window's turn record in its own chat cells, and the window shows the turn's changes in the
   notebook as a diff when the turn ends. *)
$sidebarAgentCommand = { "/opt/homebrew/bin/opencode", "acp" };
$sidebarAgentTimeout = 1800;
(* the development checkouts the speed trials use: AgentTools (the notebook tools' MCP server), ACPLink, and the folder
   the agent works in *)
$sidebarAgentLLMEditing = "/System/Volumes/Data/Development/WRI/LLMEditing";

If[ ! AssociationQ @ $sidebarAgentWindows , $sidebarAgentWindows  = <| |> ]; (* user notebook -> hidden ACP window *)
If[ ! AssociationQ @ $sidebarAgentMessages, $sidebarAgentMessages = <| |> ]; (* agent cell UUID -> its turn's state *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateSidebarAgent*)
evaluateSidebarAgent // beginDefinition;

evaluateSidebarAgent[ nbo_NotebookObject, sidebarCell_CellObject, input_ ] := Enclose[
    Module[ { text, uuid, prompt, model, window, id },
        text = makeBoxesInputMoreTextLike @ input;
        uuid = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];
        appendCellToSidebarChat[
            nbo,
            sidebarCell,
            Cell[
                BoxData @ TemplateBox[
                    { Cell[ text, Background -> None, Selectable -> True, Editable -> True ] },
                    "NotebookAssistant`Sidebar`UserMessageBox"
                ],
                "NotebookAssistant`Sidebar`ChatInput",
                CellTags -> uuid
            ],
            uuid
        ];
        prompt = ConfirmBy[ CellToString @ Cell[ text, "Text" ], StringQ, "Prompt" ];
        model  = CurrentChatSettings[ sidebarCell, "NotebookEditingModel" ];
        window = ConfirmMatch[ sidebarAgentWindow[ nbo, model ], _NotebookObject, "Window" ];
        id     = ConfirmBy[ createUUID[ ], StringQ, "AgentCellUUID" ];
        $sidebarAgentMessages[ id ] = <|
            "Window"     -> window,
            "Notebook"   -> nbo,
            "Prompt"     -> prompt,
            "Model"      -> model,
            "Effort"     -> CurrentChatSettings[ sidebarCell, "NotebookEditingEffort" ],
            "ConfigSent" -> { },
            "ReEvaluate" -> CurrentChatSettings[ sidebarCell, "NotebookReEvaluate" ] =!= False,
            "State"      -> "Starting the agent\[Ellipsis]",
            "TurnID"     -> None,
            "Created"    -> AbsoluteTime[ ]
        |>;
        $sidebarAgentMessages[ id, "Cell" ] = appendCellToSidebarChat[ nbo, sidebarCell, sidebarAgentCell @ id, id ];
        $sidebarAgentMessages[ id, "Task" ] = SessionSubmit @ ScheduledTask[ sidebarAgentStep @ id, 0.25 ];
        id
    ],
    throwInternalFailure
];

evaluateSidebarAgent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sidebarAgentWindow*)

(* The notebook's hidden ACP window, made the first time with the given model: its agent works in the notebook's folder *)
sidebarAgentWindow // beginDefinition;

sidebarAgentWindow[ nbo_NotebookObject, model_ ] := Replace[
    Lookup[ $sidebarAgentWindows, nbo, None ],
    Except[ w_NotebookObject /; MemberQ[ Notebooks[ ], w ] ] :> Module[ { window },
        sidebarAgentSetup[ ];
        window = ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <|
            "ProjectDirectory"    -> $sidebarAgentLLMEditing,
            "ACPModel"            -> model,
            "ACPAgentCommandLine" -> $sidebarAgentCommand,
            "ACPMCPServer"        -> True
        |> ];
        If[ MatchQ[ window, _NotebookObject ],
            SetOptions[ window, Visible -> False ];
            SetSelectedNotebook @ nbo;
            $sidebarAgentWindows[ nbo ] = window
        ];
        window
    ]
];

sidebarAgentWindow // endDefinition;


(* What the speed trials set up before an agent window (Speed/harness/KernelRun.wl): AgentTools for the notebook tools'
   MCP server, loaded, and the server started; once per session *)
sidebarAgentSetup // beginDefinition;

sidebarAgentSetup[ ] := sidebarAgentSetup[ ] = (
    SetEnvironment @ {
        "AGENTTOOLS_DIRECTORY" -> FileNameJoin @ { $sidebarAgentLLMEditing, "agenttools" },
        "ACPLINK_DIRECTORY"    -> FileNameJoin @ { $sidebarAgentLLMEditing, "acplink", "ACPLink" }
    };
    acpMCPAvailableQ[ ];
    NotebookMCPServer[ ];
);

sidebarAgentSetup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sidebarAgentStep*)

(* One step of an agent message, every 0.25 s until its turn is over: once the window's agent is ready, its model and
   then its effort are set, one per step, and the prompt is sent with the notebook attached; when the turn has ended and
   the window's show job (the diff) is done, the message's cell is written once more without its live view. *)
sidebarAgentStep // beginDefinition;

sidebarAgentStep[ id_String ] := Module[ { msg = $sidebarAgentMessages[ id ], window, status, change, turn },
    window = msg[ "Window" ];
    status = acpWindowGet[ window, "Status", None ];
    Which[
        AbsoluteTime[ ] - msg[ "Created" ] > $sidebarAgentTimeout,
            sidebarAgentFinish[ id, "The agent did not finish in time." ],
        ! MemberQ[ Notebooks[ ], window ],
            sidebarAgentFinish[ id, "The agent's connection closed." ],
        msg[ "TurnID" ] === None && status =!= "Ready",
            $sidebarAgentMessages[ id, "State" ] = "Starting the agent\[Ellipsis]",
        msg[ "TurnID" ] === None,
            change = sidebarAgentConfigChange @ msg;
            Which[
                MatchQ[ change, { optionID_, _ } /; ! MemberQ[ msg[ "ConfigSent" ], optionID ] ],
                    $sidebarAgentMessages[ id, "ConfigSent" ] = Append[ msg[ "ConfigSent" ], First @ change ];
                    acpSetConfigOption[ window, Sequence @@ change ],
                change =!= None,
                    Null,
                True,
                    $acpNotebookReEvaluate = msg[ "ReEvaluate" ];
                    acpSetDraftAttachments[ window, { acpNotebookAttachmentRef @ msg[ "Notebook" ] } ];
                    CurrentValue[ window, { TaggingRules, "ACP", "Input" } ] = sidebarAgentPrompt @ msg;
                    evaluateACPChat @ window;
                    $sidebarAgentMessages[ id, "TurnID" ] = Replace[ acpWindowGet[ window, "CurrentTurn", None ], Except[ _String ] -> "pending" ];
                    $sidebarAgentMessages[ id, "State" ] = "Working\[Ellipsis]"
            ],
        msg[ "TurnID" ] === "pending",
            $sidebarAgentMessages[ id, "TurnID" ] = Replace[ acpWindowGet[ window, "CurrentTurn", None ], Except[ _String ] -> "pending" ],
        True,
            (* the window drops a turn's record once the turn is finalized: the last one seen is kept for the view *)
            turn = acpTurnGet @ msg[ "TurnID" ];
            If[ AssociationQ @ turn, $sidebarAgentMessages[ id, "Turn" ] = turn ];
            If[ (! AssociationQ @ turn || turn[ "Status" ] =!= "Running") &&
                    acpWindowGet[ window, "CurrentTurn", None ] === None &&
                    Wolfram`Chatbook`ACP`MCP`Private`$mcpJobs === { },
                sidebarAgentFinish[ id, None ]
            ]
    ]
];

sidebarAgentStep // endDefinition;


(* The prompt as the agent gets it: with Re-evaluate off it is told to write the outputs itself *)
sidebarAgentPrompt // beginDefinition;
sidebarAgentPrompt[ msg_Association ] := If[ TrueQ @ msg[ "ReEvaluate" ],
    msg[ "Prompt" ],
    msg[ "Prompt" ] <> "\n\n(Nothing is evaluated: write the outputs your edits change yourself, exactly as the code would \
give them, with InsertCells (style Output) after their Input cell, and delete the old ones.)"
];
sidebarAgentPrompt // endDefinition;


(* The first of the agent's model and reasoning effort options that the message wants changed, as { option id, value },
   or None; a value the agent doesn't offer is left as the agent has it *)
sidebarAgentConfigChange // beginDefinition;
sidebarAgentConfigChange[ msg_Association ] := With[
    { options = Replace[ acpWindowGet[ msg[ "Window" ], "ConfigOptions", { } ], Except[ _List ] -> { } ] },
    FirstCase[
        { { "model", msg[ "Model" ] }, { "thought_level", msg[ "Effort" ] } },
        { category_, value_ } :> With[ { option = acpFindConfigOption[ options, category ] },
            { option[ "id" ], value } /;
                AssociationQ @ option && Lookup[ option, "currentValue", None ] =!= value && MemberQ[ acpOptionValues @ option, value ]
        ],
        None
    ]
];
sidebarAgentConfigChange // endDefinition;


sidebarAgentFinish // beginDefinition;

sidebarAgentFinish[ id_String, failure_ ] := With[ { cell = $sidebarAgentMessages[ id, "Cell" ] },
    Quiet @ TaskRemove @ $sidebarAgentMessages[ id, "Task" ];
    $sidebarAgentMessages[ id, "State" ] = Replace[ failure, None -> "Done" ];
    $sidebarAgentMessages[ id, "Failure" ] = failure;
    If[ MatchQ[ cell, _CellObject ], NotebookWrite[ cell, sidebarAgentCell[ "SidebarTopCell", sidebarAgentView @ id ] ] ]
];

sidebarAgentFinish // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sidebarAgentCell*)

(* An agent message in the sidebar: its live view while the turn runs, then a static one *)
sidebarAgentCell // beginDefinition;

sidebarAgentCell[ id_String ] :=
    sidebarAgentCell[ id, Dynamic[ Refresh[ sidebarAgentView @ id, UpdateInterval -> 0.3, TrackedSymbols :> { } ] ] ];

(* tag: the message's id when it is appended, then the sidebar's own tag for its messages.
   ACPWindow marks it as an agent message, whose hover buttons have no Regenerate. *)
sidebarAgentCell[ tag_String, content_ ] := Cell[
    BoxData @ TemplateBox[
        { Cell[ BoxData @ ToBoxes @ content, Background -> None, Selectable -> True ] },
        "NotebookAssistant`Sidebar`AssistantMessageBox"
    ],
    "NotebookAssistant`Sidebar`ChatOutput",
    CellTags     -> tag,
    Editable     -> False,
    TaggingRules -> <| "ChatNotebookSettings" -> <| "ACPWindow" -> True |> |>
];

sidebarAgentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sidebarAgentView*)

(* A turn as the sidebar shows it: the agent's text, its tool calls with their status, permission requests to answer,
   and where the turn stands *)
sidebarAgentView // beginDefinition;

sidebarAgentView[ id_String ] := Module[ { msg = $sidebarAgentMessages[ id ], turn, rows },
    turn = Replace[ If[ StringQ @ msg[ "TurnID" ], acpTurnGet @ msg[ "TurnID" ], None ], Except[ _Association ] :> Lookup[ msg, "Turn", None ] ];
    rows = If[ AssociationQ @ turn,
        DeleteCases[ sidebarAgentEntityView[ msg[ "Window" ], turn[ "Entities", # ] ] & /@ turn[ "Order" ], None ],
        { }
    ];
    Column[
        Append[ rows, Style[ sidebarAgentStatus[ msg, turn ], "Text", FontSize -> 11, FontColor -> GrayLevel[ 0.5 ] ] ],
        BaseStyle -> { "Text", FontSize -> 13 },
        Spacings  -> 0.6
    ]
];

sidebarAgentView // endDefinition;


sidebarAgentStatus // beginDefinition;
sidebarAgentStatus[ msg_, turn_Association ] /; msg[ "State" ] === "Done" := Replace[
    turn[ "Error" ],
    { None -> "Done: the changes are shown in the notebook.", e_ :> "The agent stopped: " <> ToString @ Short[ e, 2 ] }
];
sidebarAgentStatus[ msg_, turn_Association ] := msg[ "State" ] <> " " <> ToString @ Round[ AbsoluteTime[ ] - msg[ "Created" ] ] <> " s";
sidebarAgentStatus[ msg_, _ ] := msg[ "State" ];
sidebarAgentStatus // endDefinition;


sidebarAgentEntityView // beginDefinition;

sidebarAgentEntityView[ _, KeyValuePattern @ { "Type" -> "Message", "Text" -> text_String, "Child" -> None } ] /;
    StringTrim @ text =!= "" := StringTrim @ text;

sidebarAgentEntityView[ _, entity: KeyValuePattern[ "Type" -> "Tool" ] ] := Row[
    {
        Style[ Replace[ entity[ "Status" ], { "completed" -> "\[Checkmark] ", "failed" -> "\[Times] ", _ -> "\[Ellipsis] " } ],
            FontColor -> Replace[ entity[ "Status" ], { "completed" -> RGBColor[ 0.2, 0.55, 0.3 ], "failed" -> RGBColor[ 0.75, 0.2, 0.2 ], _ -> GrayLevel[ 0.5 ] } ] ],
        Style[ StringDelete[ ToString @ FirstCase[ entity /@ { "Title", "Name", "RawName" }, _String, "tool" ], "WolframNotebooks_" ], FontSize -> 12, FontColor -> GrayLevel[ 0.35 ] ]
    }
];

sidebarAgentEntityView[ window_, entity: KeyValuePattern @ { "Type" -> "Permission", "Outcome" -> None } ] := Column[ {
    Style[ "The agent asks to: " <> ToString @ Replace[ entity[ "Title" ], Except[ _String ] -> "use a tool" ], FontSize -> 12 ],
    Row[
        With[ { w = window, request = entity[ "RequestID" ], option = Lookup[ #, "optionId", None ] },
            Button[ Lookup[ #, "name", Lookup[ #, "kind", "?" ] ], acpAnswerPermission[ w, request, option ], Method -> "Queued" ]
        ] & /@ entity[ "Options" ],
        " "
    ]
} ];

sidebarAgentEntityView[ _, KeyValuePattern @ { "Type" -> "Notice", "Text" -> text_String } ] :=
    Style[ text, FontSize -> 11, FontColor -> GrayLevel[ 0.5 ] ];

sidebarAgentEntityView[ _, _ ] := None;

sidebarAgentEntityView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeBoxesInputMoreTextLike*)
makeBoxesInputMoreTextLike // beginDefinition;

makeBoxesInputMoreTextLike[ input_String ] := input;

makeBoxesInputMoreTextLike[ boxes_ ] := Enclose[
    Module[ { simplerStringLikeBoxes, nonStringBoxPositions },
        (* Flatten input boxes *)
        simplerStringLikeBoxes =
            ReplaceRepeated[
                boxes,
                {
                    RowBox[ { a___, b1_String, b2_String, c___ } ] :> RowBox[ { a, StringJoin[ b1, b2 ], c} ],
                    RowBox[ { a___, RowBox[ { b___ } ],   c___ } ] :> RowBox[ { a, b, c } ]
                }
            ];

        (* wrap non-string box expressions in BoxData cells *)
        nonStringBoxPositions = Cases[ Position[ simplerStringLikeBoxes, Except[ RowBox | List, _Symbol ], Heads -> True ], { e___, 0 } :> { e } ];
        nonStringBoxPositions = Pick[ nonStringBoxPositions, Length /@ nonStringBoxPositions, Min[ Length /@ nonStringBoxPositions ] ];
        simplerStringLikeBoxes =
            ReplacePart[
                simplerStringLikeBoxes,
                Thread[
                    Rule[
                        nonStringBoxPositions,
                        Map[ Cell[ BoxData[ # ] ]&, Extract[ simplerStringLikeBoxes, nonStringBoxPositions ] ]
                    ]
                ]
            ];

        (* *)
        Switch[ simplerStringLikeBoxes,
            RowBox[ { _String } ], simplerStringLikeBoxes[[ 1, 1 ]],
            RowBox[ { __ } ],      TextData @@ simplerStringLikeBoxes,
            _List,                 TextData @ simplerStringLikeBoxes,
            _,                     Cell @ simplerStringLikeBoxes (* FIXME: should we throw an error instead? *)
        ]
    ],
    throwInternalFailure
];

makeBoxesInputMoreTextLike // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*unansweredChatInputQ*)
(* A chat that is stopped before its response arrives leaves no cell after its input, since StopChat removes the output
   cell. Its input would stay in the chat history, and the next message's response would answer it too (#1710). A
   regular ChatInput cell is left as it is, since it can be evaluated again or deleted. In the assistant window and the
   sidebar, the input is removed, and its text is put back in the input field (unless something was typed there since
   the chat was sent), where it can be edited and sent again.
   A chat that got a response gives a ChatObject, so the front end is only asked for the next cell otherwise. A failed
   request also gives Null, but it leaves an error cell (which isn't a chat output cell) after the input.
   Note: appendCellToSidebarChat writes new sidebar chats after the last "SidebarTopCell", which an error cell isn't, so
   after a failed request, later sidebar inputs are followed by the error cell and are kept even if stopped: *)
unansweredChatInputQ // beginDefinition;
unansweredChatInputQ[ _CellObject, _ChatObject ] := False;
unansweredChatInputQ[ cell_CellObject, Null ] := ! MatchQ[ NextCell @ cell, _CellObject ];
unansweredChatInputQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validInputStringQ*)
(* LLM-712: adding images as allowed input means we must be much more permissive in validating chat input *)
validInputStringQ // beginDefinition;
validInputStringQ[ "" ] := False;
validInputStringQ[ input_String? StringQ ] := ! StringMatchQ[ input, WhitespaceCharacter... ];
validInputStringQ[ Null ] := False;
validInputStringQ[ RowBox[ boxes_List ] ] := AnyTrue[ boxes, validInputStringQ ];
validInputStringQ[ boxes_ ] := True;
validInputStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
