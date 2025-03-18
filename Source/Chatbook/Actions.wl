(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Actions`" ];

(* TODO: these probably aren't needed as exported symbols since all hooks are going through ChatbookAction *)
`AskChat;
`AttachCodeButtons;
`AIAutoAssist;
`CopyChatObject;
`EvaluateChatInput;
`ExclusionToggle;
`OpenChatMenu;
`StopChat;
`WidgetSend;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                ];
Needs[ "Wolfram`Chatbook`Common`"         ];
Needs[ "Wolfram`Chatbook`PersonaManager`" ];
Needs[ "Wolfram`Chatbook`ToolManager`"    ];

HoldComplete[
    System`GenerateLLMToolResponse,
    System`LLMToolRequest,
    System`LLMToolResponse
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$ChatEvaluationCell*)
$ChatEvaluationCell = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatCellEvaluate*)
ChatCellEvaluate // ClearAll;

ChatCellEvaluate[ ] :=
    catchMine @ ChatCellEvaluate @ topParentCell @ EvaluationCell[ ];

ChatCellEvaluate[ cell_CellObject ] :=
    catchMine @ ChatCellEvaluate[ cell, parentNotebook @ cell ];

ChatCellEvaluate[ cell_CellObject, nbo_NotebookObject ] :=
    catchMine @ Block[ { cellPrint = cellPrintAfter @ cell },
        Replace[
            Reap[ EvaluateChatInput[ cell, nbo ], $chatObjectTag ],
            {
                { _, { { chat: HoldPattern[ _ChatObject ] } } } :> chat,
                ___ :> Null
            }
        ]
    ];

ChatCellEvaluate[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", ChatCellEvaluate, HoldForm @ ChatCellEvaluate @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatbookAction*)
ChatbookAction[ "AccentIncludedCells"          , args___ ] := catchMine @ accentIncludedCells @ args;
ChatbookAction[ "AIAutoAssist"                 , args___ ] := catchMine @ AIAutoAssist @ args;
ChatbookAction[ "Ask"                          , args___ ] := catchMine @ AskChat @ args;
ChatbookAction[ "AssistantMessageLabel"        , args___ ] := catchMine @ assistantMessageLabel @ args;
ChatbookAction[ "AttachAssistantMessageButtons", args___ ] := catchMine @ attachAssistantMessageButtons @ args;
ChatbookAction[ "AttachCodeButtons"            , args___ ] := catchMine @ AttachCodeButtons @ args;
ChatbookAction[ "AttachWorkspaceChatInput"     , args___ ] := catchMine @ attachWorkspaceChatInput @ args;
ChatbookAction[ "CopyChatObject"               , args___ ] := catchMine @ CopyChatObject @ args;
ChatbookAction[ "CopyExplodedCells"            , args___ ] := catchMine @ CopyExplodedCells @ args;
ChatbookAction[ "CopyImage"                    , args___ ] := catchMine @ copyImage @ args;
ChatbookAction[ "CopyPlainText"                , args___ ] := catchMine @ copyPlainText @ args;
ChatbookAction[ "DisableAssistance"            , args___ ] := catchMine @ DisableAssistance @ args;
ChatbookAction[ "DisplayInlineChat"            , args___ ] := catchMine @ displayInlineChat @ args;
ChatbookAction[ "EvaluateChatInput"            , args___ ] := catchMine @ EvaluateChatInput @ args;
ChatbookAction[ "EvaluateInlineChat"           , args___ ] := catchMine @ evaluateInlineChat @ args;
ChatbookAction[ "EvaluateWorkspaceChat"        , args___ ] := catchMine @ evaluateWorkspaceChat @ args;
ChatbookAction[ "ExclusionToggle"              , args___ ] := catchMine @ ExclusionToggle @ args;
ChatbookAction[ "ExplodeDuplicate"             , args___ ] := catchMine @ ExplodeDuplicate @ args;
ChatbookAction[ "ExplodeInPlace"               , args___ ] := catchMine @ ExplodeInPlace @ args;
ChatbookAction[ "InsertCodeBelow"              , args___ ] := catchMine @ insertCodeBelow @ args;
ChatbookAction[ "InsertInlineReference"        , args___ ] := catchMine @ InsertInlineReference @ args;
ChatbookAction[ "MakeWorkspaceChatDockedCell"  , args___ ] := catchMine @ makeWorkspaceChatDockedCell @ args;
ChatbookAction[ "MoveToChatInputField"         , args___ ] := catchMine @ moveToChatInputField @ args;
ChatbookAction[ "OpenChatBlockSettings"        , args___ ] := catchMine @ OpenChatBlockSettings @ args;
ChatbookAction[ "OpenChatMenu"                 , args___ ] := catchMine @ OpenChatMenu @ args;
ChatbookAction[ "PersonaManage"                , args___ ] := catchMine @ PersonaManage @ args;
ChatbookAction[ "RegenerateAssistantMessage"   , args___ ] := catchMine @ regenerateAssistantMessage @ args;
ChatbookAction[ "RemoveCellAccents"            , args___ ] := catchMine @ removeCellAccents @ args;
ChatbookAction[ "Send"                         , args___ ] := catchMine @ SendChat @ args;
ChatbookAction[ "SendFeedback"                 , args___ ] := catchMine @ SendFeedback @ args;
ChatbookAction[ "StopChat"                     , args___ ] := catchMine @ StopChat @ args;
ChatbookAction[ "TabLeft"                      , args___ ] := catchMine @ TabLeft @ args;
ChatbookAction[ "TabRight"                     , args___ ] := catchMine @ TabRight @ args;
ChatbookAction[ "ToggleFormatting"             , args___ ] := catchMine @ ToggleFormatting @ args;
ChatbookAction[ "ToolManage"                   , args___ ] := catchMine @ ToolManage @ args;
ChatbookAction[ "UpdateDynamics"               , args___ ] := catchMine @ updateDynamics @ args;
ChatbookAction[ "UserMessageLabel"             , args___ ] := catchMine @ userMessageLabel @ args;
ChatbookAction[ "WidgetSend"                   , args___ ] := catchMine @ WidgetSend @ args;
ChatbookAction[ args___                                  ] := catchMine @ throwInternalFailure @ ChatbookAction @ args;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*regenerateAssistantMessage*)
regenerateAssistantMessage // beginDefinition;

regenerateAssistantMessage[ chatOutput_CellObject ] := Enclose[
    Catch @ Module[ { chatInput, nbo },
        chatInput = PreviousCell[ chatOutput, CellStyle -> "ChatInput" ];
        If[ ! MatchQ[ chatInput, _CellObject ], Throw @ Null ];
        nbo = ConfirmMatch[ parentNotebook @ chatInput, _NotebookObject, "Notebook" ];
        NotebookDelete @ chatOutput;
        SelectionMove[ chatInput, All, Cell, AutoScroll -> True ];
        FrontEndTokenExecute[ nbo, "EvaluateCells" ];
    ],
    throwInternalFailure
];

regenerateAssistantMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SendFeedback*)
SendFeedback // beginDefinition;

SendFeedback[ cellObject0_, positive: True|False ] := Enclose[
    Module[ { cellObject },
        cellObject = ConfirmMatch[ ensureChatOutputCell @ cellObject0, _CellObject, "CellObject" ];
        ConfirmMatch[ sendFeedback[ cellObject, positive ], _NotebookObject, "SendFeedbackDialog" ]
    ],
    throwInternalFailure[ SendFeedback[ cellObject0, positive ], ## ] &
];

SendFeedback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*copyImage*)
copyImage // beginDefinition;

copyImage[ cellObject0_ ] := Enclose[
    Module[ { cellObject, image },
        cellObject = ConfirmMatch[ ensureChatOutputCell @ cellObject0, _CellObject, "CellObject" ];
        image      = ConfirmBy[ rasterize @ cellObject, image2DQ, "Image" ];
        CopyToClipboard @ image
    ],
    throwInternalFailure
];

copyImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*copyPlainText*)
copyPlainText // beginDefinition;

copyPlainText[ cellObject0_ ] := Enclose[
    Module[ { cellObject, text },
        cellObject = ConfirmMatch[ ensureChatOutputCell @ cellObject0, _CellObject, "CellObject" ];
        text       = ConfirmBy[ CellToString @ cellObject, StringQ, "String" ];
        CopyToClipboard @ text
    ],
    throwInternalFailure
];

copyPlainText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CopyExplodedCells*)
CopyExplodedCells // beginDefinition;

CopyExplodedCells[ cellObject0_ ] := Enclose[
    Module[ { cellObject, exploded },
        cellObject = ConfirmMatch[ ensureChatOutputCell @ cellObject0, _CellObject, "CellObject" ];
        exploded   = ConfirmMatch[ explodeCell @ cellObject, { ___Cell }, "ExplodeCell" ];
        CopyToClipboard @ exploded
    ],
    throwInternalFailure
];

CopyExplodedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ExplodeDuplicate*)
ExplodeDuplicate // beginDefinition;

ExplodeDuplicate[ cellObject0_ ] := Enclose[
    Module[ { cellObject, exploded, nbo },
        cellObject = ConfirmMatch[ ensureChatOutputCell @ cellObject0, _CellObject, "CellObject" ];
        exploded   = ConfirmMatch[ explodeCell @ cellObject, { __Cell }, "ExplodeCell" ];
        SelectionMove[ cellObject, After, Cell, AutoScroll -> False ];
        nbo = ConfirmMatch[ parentNotebook @ cellObject, _NotebookObject, "ParentNotebook" ];
        ConfirmMatch[ NotebookWrite[ nbo, exploded ], Null, "NotebookWrite" ]
    ],
    throwInternalFailure
];

ExplodeDuplicate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ExplodeInPlace*)
ExplodeInPlace // beginDefinition;

ExplodeInPlace[ cellObject0_ ] := Enclose[
    Module[ { cellObject, exploded },
        cellObject = ConfirmMatch[ ensureChatOutputCell @ cellObject0, _CellObject, "CellObject" ];
        exploded   = ConfirmMatch[ explodeCell @ cellObject, { __Cell }, "ExplodeCell" ];
        ConfirmMatch[ NotebookWrite[ cellObject, exploded ], Null, "NotebookWrite" ]
    ],
    throwInternalFailure
];

ExplodeInPlace // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ToggleFormatting*)
ToggleFormatting // beginDefinition;

ToggleFormatting[ cellObject0_ ] := Enclose[
    Module[ { cellObject, cell, toggled },
        cellObject = ConfirmMatch[ ensureChatOutputCell @ cellObject0, _CellObject, "CellObject" ];
        cell = ConfirmMatch[ notebookRead @ cellObject, _Cell, "NotebookRead" ];
        toggled = ConfirmMatch[ toggleFormatting @ cell, _Cell, "Toggled" ];
        ConfirmMatch[ NotebookWrite[ cellObject, toggled ], Null, "NotebookWrite" ]
    ],
    throwInternalFailure
];

ToggleFormatting // endDefinition;

(* TODO: If the chat output is just a plain string with no markdown, toggling formatting is a no-op.
         Should this display a message dialog in this case explaining that there's nothing to toggle? *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toggleFormatting*)
toggleFormatting // beginDefinition;
(* FIXME: define an "Unformatted" mix-in style (with different background) that's added/removed when toggling *)
(* Convert a plain string to formatted TextData: *)
toggleFormatting[ Cell[ content_String, rest___ ] ] := Cell[ TextData @ reformatTextData @ content, rest ];
(* Convert formatted TextData to a plain string: *)
toggleFormatting[ Cell[ content_TextData, rest___ ] ] := Cell[ CellToString @ Cell[ content, "ChatOutput" ], rest ];
toggleFormatting // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DisableAssistance*)
DisableAssistance // beginDefinition;
DisableAssistance[ cell_ ] := disableAssistance @ ensureChatOutputCell @ cell;
DisableAssistance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*disableAssistance*)
disableAssistance // beginDefinition;

disableAssistance[ cell_CellObject ] := (
    disableAssistance @ parentNotebook @ cell;
    NotebookDelete @ parentCell @ cell;
    NotebookDelete @ cell;
);

disableAssistance[ nbo_NotebookObject ] := (
    CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings", "Assistance" } ] = False
);

disableAssistance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InsertInlineReference*)
InsertInlineReference // beginDefinition;

InsertInlineReference[ type_, cell_ ] :=
    insertInlineReference[ type, loadDefinitionNotebook @ ensureChatInputCell @ cell ];

InsertInlineReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*insertInlineReference*)
insertInlineReference // beginDefinition;

(* FIXME: these four are unused, need to remove relevant definitions *)
insertInlineReference[ "Persona"         , args___ ] := insertPersonaInputBox @ args;
insertInlineReference[ "TrailingFunction", args___ ] := insertTrailingFunctionInputBox @ args;
insertInlineReference[ "Function"        , args___ ] := insertFunctionInputBox @ args;
insertInlineReference[ "Modifier"        , args___ ] := insertModifierInputBox @ args;

insertInlineReference[ "PersonaTemplate" , args___ ] := insertPersonaTemplate @ args;
insertInlineReference[ "FunctionTemplate", args___ ] := insertFunctionTemplate @ args;
insertInlineReference[ "ModifierTemplate", args___ ] := insertModifierTemplate @ args;
insertInlineReference[ "WLTemplate"      , args___ ] := insertWLTemplate @ args;

insertInlineReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadDefinitionNotebook*)

(* TODO: hook up to other actions that might need this *)
loadDefinitionNotebook // beginDefinition;

loadDefinitionNotebook[ cell_ ] /; $definitionNotebookLoaded := cell;

loadDefinitionNotebook[ cell_CellObject? definitionNotebookCellQ ] :=
    With[ { nbo = parentNotebook @ cell },
        DefinitionNotebookClient`LoadDefinitionNotebook @ nbo;
        PromptResource`DefinitionNotebook`RescrapeLLMEvaluator @ nbo;
        $definitionNotebookLoaded = True;
        cell
    ];

loadDefinitionNotebook[ cell_ ] := cell;

loadDefinitionNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*definitionNotebookCellQ*)
definitionNotebookCellQ[ cell_CellObject ] := definitionNotebookCellQ[ cell ] =
    CurrentValue[ cell, { TaggingRules, "ResourceType" } ] === "Prompt";

definitionNotebookCellQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*PersonaManage*)
PersonaManage[ a___ ] := Enclose[
    ConfirmMatch[ CreatePersonaManagerDialog[ ], _NotebookObject, "createPersonaManagerDialog" ],
    throwInternalFailure[ PersonaManage @ a, ## ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ToolManage*)
ToolManage[ a___ ] := Enclose[
    ConfirmMatch[ CreateLLMToolManagerDialog[ ], _NotebookObject, "CreateLLMToolManagerDialog" ],
    throwInternalFailure[ ToolManage @ a, ## ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TabLeft*)
TabLeft // beginDefinition;
TabLeft[ cell_ ] := rotateTabPage[ ensureChatOutputCell @ cell, -1 ];
TabLeft // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TabRight*)
TabRight // beginDefinition;
TabRight[ cell_ ] := rotateTabPage[ ensureChatOutputCell @ cell, 1 ];
TabRight // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*rotateTabPage*)
rotateTabPage // beginDefinition;

rotateTabPage[ cell_CellObject, n_Integer ] := Enclose[
    Module[ { pageData, pageCount, currentPage, newPage, encoded, content },

        pageData    = ConfirmBy[ <| CurrentValue[ cell, { TaggingRules, "PageData" } ] |>, AssociationQ, "PageData" ];
        pageCount   = ConfirmBy[ pageData[ "PageCount"   ], IntegerQ, "PageCount"   ];
        currentPage = ConfirmBy[ pageData[ "CurrentPage" ], IntegerQ, "CurrentPage" ];
        newPage     = Mod[ currentPage + n, pageCount, 1 ];
        encoded     = ConfirmMatch[ pageData[ "Pages", newPage ], _String, "EncodedContent" ];
        content     = ConfirmMatch[ BinaryDeserialize @ BaseDecode @ encoded, TextData[ $$textData ], "Content" ];

        writePageContent[ cell, newPage, content ]
    ],
    throwInternalFailure[ rotateTabPage[ cell, n ], ## ] &
];

rotateTabPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writePageContent*)
writePageContent // beginDefinition;

writePageContent[ cell_CellObject, newPage_Integer, content: TextData[ $$textData ] ] /; $cloudNotebooks := (
    CurrentValue[ cell, { TaggingRules, "PageData", "CurrentPage" } ] = newPage;
    CurrentValue[ cell, TaggingRules ] = GeneralUtilities`ToAssociations @ CurrentValue[ cell, TaggingRules ];
    NotebookWrite[ cell, ReplacePart[ NotebookRead @ cell, 1 -> content ] ];
)

writePageContent[ cell_CellObject, newPage_Integer, content: TextData[ $$textData ] ] := (
    SelectionMove[ cell, All, CellContents, AutoScroll -> False ];
    NotebookWrite[ parentNotebook @ cell, content, None, AutoScroll -> False ];
    SelectionMove[ cell, After, Cell, AutoScroll -> False ];
    CurrentValue[ cell, { TaggingRules, "PageData", "CurrentPage" } ] = newPage;
    SetOptions[ cell, CellAutoOverwrite -> True, GeneratedCell -> True ]
);

writePageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EvaluateChatInput*)
EvaluateChatInput // beginDefinition;

EvaluateChatInput[ ] := EvaluateChatInput @ rootEvaluationCell[ ];

EvaluateChatInput[ evalCell_CellObject? chatInputCellQ ] :=
    If[ chatExcludedQ @ evalCell,
        Null,
        EvaluateChatInput[ evalCell, parentNotebook @ evalCell ]
    ];

EvaluateChatInput[ source: _CellObject | $Failed ] :=
    With[ { evalCell = rootEvaluationCell @ source },
        EvaluateChatInput @ evalCell /; chatInputCellQ @ evalCell
    ];

EvaluateChatInput[ evalCell_CellObject, nbo_NotebookObject ] :=
    withChatState @ EvaluateChatInput[ evalCell, nbo, resolveAutoSettings @ currentChatSettings @ evalCell ];

EvaluateChatInput[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    withChatStateAndFEObjects[
        { evalCell, nbo },
        setServiceCaller @ Block[ { $AutomaticAssistance = False, $aborted = False },
            $lastCellObject     = None;
            $lastChatString     = None;
            $lastMessages       = None;
            $nextTaskEvaluation = None;
            $enableLLMServices  = settings[ "EnableLLMServices" ];
            clearMinimizedChats @ nbo;

            (* Send chat while listening for an abort: *)
            CheckAbort[
                sendChat[ evalCell, nbo, settings ] // LogChatTiming[ "SendChat" ];
                waitForLastTask @ settings
                ,
                (* The user has issued an abort: *)
                $aborted = True;
                (* Clean up the current chat evaluation: *)
                With[ { cell = $lastCellObject },
                    If[ MatchQ[ cell, _CellObject ],
                        StopChat @ cell,
                        removeTask @ $lastTask
                    ]
                ]
                ,
                PropagateAborts -> False
            ];

            blockChatObject[
                If[ ListQ @ $lastMessages && StringQ @ $lastChatString,
                    With[
                        {
                            chat = constructChatObject @ mergeToolCallMessages @ Append[
                                $lastMessages,
                                <| "Role" -> "Assistant", "Content" -> $lastChatString |>
                            ] // LogChatTiming[ "ConstructChatObject" ]
                        },
                        If[ TrueQ @ settings[ "AutoSaveConversations" ],
                            SaveChat[ nbo, chat, settings, "AutoSaveOnly" -> True ]
                        ];
                        applyChatPost[ chat, settings, nbo, $aborted ]
                    ],
                    applyChatPost[ None, settings, nbo, $aborted ];
                    Null
                ];
            ]
        ]
    ];

EvaluateChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mergeToolCallMessages*)
mergeToolCallMessages // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::KernelBug:: *)
mergeToolCallMessages[ {
    a___,
    KeyValuePattern[ "ToolRequest" -> True ],
    KeyValuePattern[ "ToolResponse" -> True ],
    b: KeyValuePattern[ "Role" -> "Assistant" ],
    c___
} ] := mergeToolCallMessages @ { a, b, c };
(* :!CodeAnalysis::EndBlock:: *)

mergeToolCallMessages[ messages_List ] :=
    messages;

mergeToolCallMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyChatPost*)
applyChatPost // beginDefinition;

applyChatPost[ chat_, settings_, nbo_, aborted: True|False ] := (
    If[ aborted,
        applyHandlerFunction[ settings, "ChatAbort", <| "ChatObject" -> chat, "NotebookObject" -> nbo |> ],
        applyHandlerFunction[ settings, "ChatPost" , <| "ChatObject" -> chat, "NotebookObject" -> nbo |> ]
    ];
    Sow[ chat, $chatObjectTag ]
);

applyChatPost // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*blockChatObject*)
blockChatObject // beginDefinition;
blockChatObject // Attributes = { HoldFirst };
blockChatObject[ eval_ ] /; Quiet @ PacletNewerQ[ PacletObject[ "Wolfram/LLMFunctions" ], "1.1.0" ] := eval;
blockChatObject[ eval_ ] := Block[ { chatObject = delayedChatObject, delayedChatObject }, eval ];
blockChatObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*delayedChatObject*)
delayedChatObject // beginDefinition;
delayedChatObject[ args___ ] := delayedChatObject[ args ] = System`ChatObject @ args;
delayedChatObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatInputCellQ*)
chatInputCellQ[ cell_CellObject ] := chatInputCellQ[ cell ] = chatInputCellQ[ cell, Developer`CellInformation @ cell ];
chatInputCellQ[ cell_, KeyValuePattern[ "Style" -> $$chatInputStyle ] ] := True;
chatInputCellQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureChatInputCell*)
ensureChatInputCell // beginDefinition;

ensureChatInputCell[ cell_CellObject? chatInputCellQ ] :=
    ensureChatInputCell[ cell ] = cell;

ensureChatInputCell[ cell_ ] :=
    ensureChatInputCell[ cell, rootEvaluationCell @ cell ];

ensureChatInputCell[ cell_CellObject, new_CellObject? chatInputCellQ ] :=
    ensureChatInputCell[ cell ] = ensureChatInputCell[ new ] = new;

ensureChatInputCell[ cell_, new_CellObject? chatInputCellQ ] :=
    ensureChatInputCell[ new ] = new;

ensureChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatOutputCellQ*)
chatOutputCellQ[ cell_CellObject ] := chatOutputCellQ[ cell ] =
    chatOutputCellQ[ cell, Developer`CellInformation @ cell ];

chatOutputCellQ[ cell_, KeyValuePattern[ "Style" -> $$chatOutputStyle ] ] :=
    True;

chatOutputCellQ[ cell_CellObject, KeyValuePattern[ "Style" -> "Output" ] ] /; $cloudNotebooks :=
    MatchQ[ CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", "CellObject" } ], _CellObject ];

chatOutputCellQ[ ___ ] :=
    False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureChatOutputCell*)
ensureChatOutputCell // beginDefinition;

ensureChatOutputCell[ cell_CellObject? chatOutputCellQ ] :=
    ensureChatOutputCell[ cell ] = cell;

ensureChatOutputCell[ cell_ ] :=
    ensureChatOutputCell[ cell, topParentCell @ cell ];

ensureChatOutputCell[ cell_CellObject, new_CellObject? chatOutputCellQ ] :=
    ensureChatOutputCell[ cell ] = ensureChatOutputCell[ new ] = new;

ensureChatOutputCell[ cell_, new_CellObject? chatOutputCellQ ] :=
    ensureChatOutputCell[ new ] = new;

ensureChatOutputCell[ cell_, new_CellObject? chatInputCellQ ] :=
    ensureChatOutputCell[ cell, nextChatOutput @ new ];

ensureChatOutputCell[ cell_, None ] :=
    None;

ensureChatOutputCell[ _, _ ] :=
    None;

ensureChatOutputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*waitForLastTask*)
waitForLastTask // beginDefinition;

waitForLastTask[ settings_Association ] :=
    Module[ { timeConstraint },
        timeConstraint = settings[ "TimeConstraint" ];
        If[ TrueQ @ Positive @ timeConstraint,
            TimeConstrained[ waitForLastTask @ $lastTask, timeConstraint, StopChat[ ] ],
            waitForLastTask @ $lastTask
        ]
    ];

waitForLastTask[ $Canceled ] := $Canceled;

waitForLastTask[ None ] :=
    While[ MatchQ[ $nextTaskEvaluation, _Hold ],
           runNextTask @ $nextTaskEvaluation
    ];

waitForLastTask[ task_TaskObject ] := LogChatTiming[
    TaskWait @ task;
    runNextTask[ ];
    If[ $lastTask =!= task, waitForLastTask @ $lastTask ],
    "WaitForLastTask"
];

waitForLastTask[ HoldPattern[ $lastTask ] ] := Null;

waitForLastTask // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*runNextTask*)
runNextTask // beginDefinition;
runNextTask[ ] := runNextTask @ $nextTaskEvaluation;
runNextTask[ Hold[ eval_ ] ] := ($nextTaskEvaluation = None; eval);
runNextTask[ None ] := Null;
runNextTask // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AIAutoAssist*)
AIAutoAssist // beginDefinition;

AIAutoAssist[ cell_ ] /; $cloudNotebooks := Null;

AIAutoAssist[ cell_CellObject ] :=
    Block[ { $inEpilog = True },
        With[ { root = checkEvaluationCell @ cell },
            AIAutoAssist[ root, parentNotebook @ root ]
        ]
    ];

AIAutoAssist[ cell_CellObject, nbo_NotebookObject ] := withChatState @
    Module[ { settings },
        settings = resolveAutoSettings @ currentChatSettings @ cell;
        If[ autoAssistQ @ settings,
            Block[ { $AutomaticAssistance = True },
                needsBasePrompt[ "AutoAssistant" ];
                SendChat[ cell, parentNotebook @ cell, settings ]
            ],
            Null
        ]
    ];

AIAutoAssist // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*autoAssistQ*)
autoAssistQ // beginDefinition;

autoAssistQ[ settings_Association ] :=
    TrueQ @ settings[ "Assistance" ];

autoAssistQ[ cell_CellObject, nbo_NotebookObject ] :=
    autoAssistQ @ cell;

autoAssistQ[ cell_CellObject ] := And[
    (* Don't run auto-assist for cells that already have a chat evaluation function defined (e.g. ChatInput) *)
    FreeQ[ CurrentValue[ cell, CellEvaluationFunction ], "Wolfram`Chatbook`ChatbookAction"|ChatbookAction ],
    (* TODO: If value is Automatic, then there could be a one-time dialog asking for approval to run auto-assistance.
             For now, only run assistance if setting is explicitly true *)
    TrueQ @ currentChatSettings[ cell, "Assistance" ]
];

(* Determine if auto assistance is enabled generally within a FE or Notebook. *)
autoAssistQ[ target: _FrontEndObject | $FrontEndSession | _NotebookObject ] :=
    TrueQ @ currentChatSettings[ target, "Assistance" ];

autoAssistQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*StopChat*)
StopChat // beginDefinition;

StopChat[ ] :=
    With[ { cell = $lastCellObject },
        StopChat @ cell /; chatOutputCellQ @ cell
    ];

StopChat[ ] :=
    With[ { cell = $ChatEvaluationCell },
        StopChat @ cell /; chatInputCellQ @ cell
    ];

StopChat[ ] :=
    StopChat @ rootEvaluationCell[ ];

StopChat[ cell_CellObject ] :=
    With[ { parent = parentCell @ cell },
        StopChat @ parent /; MatchQ[ parent, Except[ cell, _CellObject ] ]
    ];

StopChat[ cell0_CellObject ] := Enclose[
    Catch @ Module[ { finish, cell, settings, container, content },
        finish = Function[ $ChatEvaluationCell = None; removeTask @ $lastTask; Throw @ Null ];
        cell = ConfirmMatch[ ensureChatOutputCell @ cell0, _CellObject|None, "ParentCell" ];
        If[ cell === None, finish[ ] ];
        settings = ConfirmMatch[ currentChatSettings @ cell, _Association|_Missing, "ChatNotebookSettings" ];
        If[ MissingQ @ settings, finish[ ] ];
        removeTask @ Lookup[ settings, "Task", None ];
        container = ConfirmMatch[ Lookup[ settings, "Container", None ], _Association|_Symbol, "Container" ];
        If[ MatchQ[ container, _Symbol ], finish[ ] ];
        content = ConfirmMatch[ Lookup[ container, "FullContent" ], _String|$$progressIndicator, "Content" ];
        FinishDynamic[ ];
        Block[ { createFETask = # & }, writeReformattedCell[ settings, content, cell ] ]
    ],
    throwInternalFailure
];

StopChat[ $Failed ] :=
    With[ { cell = rootEvaluationCell[ ] },
        If[ MatchQ[ cell, _CellObject ], StopChat @ cell ]
    ];

StopChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*nextChatOutput*)
nextChatOutput // beginDefinition;
nextChatOutput[ cell_CellObject? chatOutputCellQ ] := cell;
nextChatOutput[ cell_CellObject ] /; $cloudNotebooks := cloudNextChatOutput @ cell;
nextChatOutput[ cell_CellObject ] := NextCell[ cell, CellStyle -> "ChatOutput" ];
nextChatOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNextChatOutput*)
cloudNextChatOutput // beginDefinition;
cloudNextChatOutput[ cell_CellObject ] := cloudNextChatOutput[ cell, parentNotebook @ cell ];
cloudNextChatOutput[ cell_CellObject, nbo_NotebookObject ] := cloudNextChatOutput[ cell, Cells @ nbo ];
cloudNextChatOutput[ cell_, { ___, cell_, cells___CellObject } ] := SelectFirst[ { cells }, chatOutputCellQ, None ];
cloudNextChatOutput[ cell_, _ ] := None;
cloudNextChatOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeTask*)
removeTask // beginDefinition;
removeTask[ task_TaskObject ] := Quiet[ TaskRemove @ task, TaskRemove::timnf ];
removeTask[ _Symbol ] := Null; (* undefined Module symbol -- task hasn't been created yet *)
removeTask // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CopyChatObject*)
CopyChatObject // beginDefinition;

CopyChatObject[ cell0_ ] := Enclose[
    Module[ { cell, encodedString, chatData, messages, chatObject },

        Quiet[ PacletInstall[ "Wolfram/LLMFunctions" ]; Needs[ "Wolfram`LLMFunctions`" -> None ] ];
        cell = ConfirmMatch[ ensureChatOutputCell @ cell0, _CellObject, "CellObject" ];

        encodedString = ConfirmMatch[
            CurrentValue[ cell, { TaggingRules, "ChatData" } ],
            _String|Inherited,
            "EncodedString"
        ];

        If[ encodedString === Inherited, throwMessageDialog[ "ChatObjectNotAvailable" ] ];

        chatData   = ConfirmBy[ BinaryDeserialize @ BaseDecode @ encodedString, AssociationQ, "ChatData" ];
        messages   = ConfirmMatch[ chatData[ "Data", "Messages" ], { __Association? AssociationQ }, "Messages" ];
        chatObject = Confirm[ constructChatObject @ messages, "ChatObject" ];

        CopyToClipboard @ chatObject
    ],
    throwInternalFailure
];

CopyChatObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*constructChatObject*)
constructChatObject // beginDefinition;

constructChatObject[ messages_List ] :=
    With[ { chat = Quiet[ chatObject @ checkMultimodal @ standardizeMessageKeys @ messages, ChatObject::bdprompt ] },
        chat /; MatchQ[ chat, _chatObject ]
    ];

constructChatObject[ messages_List ] :=
    Dataset[ KeyMap[ Capitalize ] /@ messages ];

constructChatObject // endDefinition;

chatObject := chatObject = Symbol[ "System`ChatObject" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkMultimodal*)
(* TODO: this is temporary until ChatObject supports multimodal content: *)
checkMultimodal // beginDefinition;
checkMultimodal[ messages_ ] := checkMultimodal[ messages, multimodalPacletsAvailable[ ] ];
checkMultimodal[ messages_, False ] := revertMultimodalContent @ messages;
checkMultimodal[ messages_, True  ] := messages;
checkMultimodal // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*revertMultimodalContent*)
revertMultimodalContent // beginDefinition;

revertMultimodalContent[ messages_List ] :=
    revertMultimodalContent /@ messages;

revertMultimodalContent[ as: KeyValuePattern[ "Content" -> content_List ] ] := <|
    as,
    "Content" -> StringJoin @ Cases[
        content,
        s_String | KeyValuePattern @ { "Type" -> "Text", "Data" -> s_String } :> s
    ]
|>;

revertMultimodalContent[ as: KeyValuePattern[ "Content" -> content_Association ] ] :=
    revertMultimodalContent[ <| as, "Content" -> { content } |> ];

revertMultimodalContent[ as: KeyValuePattern[ "Content" -> _String ] ] :=
    as;

revertMultimodalContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*standardizeMessageKeys*)
standardizeMessageKeys // beginDefinition;
standardizeMessageKeys[ message_Association ] := standardizeMessageKeys0 @ KeyMap[ Capitalize, message ];
standardizeMessageKeys[ messages_List ] := standardizeMessageKeys /@ messages;
standardizeMessageKeys // endDefinition;


standardizeMessageKeys0 // beginDefinition;

standardizeMessageKeys0[ message: KeyValuePattern[ "Role" -> role_String ] ] :=
    Insert[ message, "Role" -> Capitalize @ role, Key[ "Role" ] ];

standardizeMessageKeys0[ message_Association ] :=
    message;

standardizeMessageKeys0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenChatBlockSettings*)
OpenChatBlockSettings // beginDefinition;
OpenChatBlockSettings[ cell_CellObject ] := OpenChatMenu[ "ChatSection", cell ];
OpenChatBlockSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenChatMenu*)
OpenChatMenu // beginDefinition;
OpenChatMenu[ "AssistantOutput", cell_CellObject ] := openChatOutputMenu @ cell;
OpenChatMenu[ "ChatOutput"     , cell_CellObject ] := openChatOutputMenu @ cell;
OpenChatMenu[ "ChatSection"    , cell_CellObject ] := openChatSectionDialog @ cell;
OpenChatMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openChatOutputMenu*)
openChatOutputMenu // beginDefinition;

openChatOutputMenu[ cell_CellObject ] := AttachCell[
    parentCell @ cell,
    RawBoxes @ TemplateBox[ { }, "ChatOutputMenu" ],
    { Right, Top },
    Offset[ { -7, -7 }, { 0, 0 } ],
    { Right, Top },
    RemovalConditions -> { "EvaluatorQuit", "MouseClickOutside" }
];

openChatOutputMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openChatSectionDialog*)
openChatSectionDialog // beginDefinition;
openChatSectionDialog[ cell0_CellObject ] := createChatContextDialog @ parentCell @ cell0;
openChatSectionDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createChatContextDialog*)
createChatContextDialog // beginDefinition;

createChatContextDialog[ cell_CellObject ] :=
    Module[ { text, textCell, cellFunc, cellFuncCell, postFunc, postFuncCell, cells, nbo },

        text = AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", "ChatContextPreprompt" } ];
        textCell = If[ StringQ @ text, Cell[ text, "Text", CellID -> 1, CellTags -> { "NonDefault" } ], Missing[ ] ];

        cellFunc = AbsoluteCurrentValue[
            cell,
            { TaggingRules, "ChatNotebookSettings", "CellToMessageFunction" }
        ];
        cellFuncCell = Cell[ BoxData @ ToBoxes @ cellFunc, "Input", CellID -> 2, CellTags -> { "NonDefault" } ];

        postFunc     = AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", "ChatPost" } ];
        postFuncCell = Cell[ BoxData @ ToBoxes @ postFunc, "Input", CellID -> 3, CellTags -> { "NonDefault" } ];

        cells = TemplateApply[
            $chatContextDialogTemplateCells,
            DeleteMissing @ <|
                "ChatContextPreprompt"  -> textCell,
                "CellToMessageFunction" -> cellFuncCell,
                "ChatPost"              -> postFuncCell,
                "DialogButtons"         -> chatContextDialogButtons @ cell
            |>
        ];

        nbo = NotebookPut @ Notebook[
            cells,
            StyleDefinitions -> $chatContextDialogStyles,
            CreateCellID     -> True,
            Saveable         -> False
        ];

        SelectionMove[ nbo, After, Notebook, AutoScroll -> False ]
    ];

createChatContextDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatContextDialogButtons*)
chatContextDialogButtons // beginDefinition;

chatContextDialogButtons[ cell_CellObject ] := Cell[
    BoxData @ $chatContextDialogButtons[
        DialogReturn @ setChatSectionSettings[ cell, scrapeChatContextDialog @ EvaluationNotebook[ ] ],
        DialogReturn @ $Canceled
    ],
    "DialogButtons"
];

chatContextDialogButtons // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setChatSectionSettings*)
setChatSectionSettings // beginDefinition;

setChatSectionSettings[ cell_CellObject, settings_Association ] :=
    Module[ { cellSettings, nbSettings, newSettings },
        KeyValueMap[ Function[ CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", #1 } ] = #2 ], settings ];

        (* The rest of this is a workaround for bug 435058 *)
        cellSettings = CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ];
        nbSettings   = CurrentValue[ parentNotebook @ cell, { TaggingRules, "ChatNotebookSettings" } ];
        newSettings  = Complement[ cellSettings, nbSettings ];
        CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ] = newSettings;
    ];

setChatSectionSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatContextDialogButtons*)
$chatContextDialogButtons := getAsset[ "ChatContextDialogButtons" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatContextDialogTemplateCells*)
$chatContextDialogTemplateCells := getAsset[ "ChatContextDialogCellsTemplate" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatContextDialogStyles*)
$chatContextDialogStyles := getAsset[ "ChatContextDialogStyles" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*scrapeChatContextDialog*)
scrapeChatContextDialog // beginDefinition;

scrapeChatContextDialog[ nbo_NotebookObject ] :=
    Enclose @ Module[ { text, cellProcFunction, postFunction },

        text = ConfirmMatch[ scrape[ nbo, "ChatContextPreprompt", "Strings" ], { ___String } ];

        cellProcFunction = ConfirmMatch[
            scrape[
                nbo,
                "CellToMessageFunction",
                "Expression",
                KeyTake @ { "Result", "Definitions" },
                "TargetContext"      -> $Context,
                "IncludeDefinitions" -> True
            ],
            KeyValuePattern[ "Result" -> _ ]
        ];

        postFunction = ConfirmMatch[
            scrape[
                nbo,
                "ChatPost",
                "Expression",
                KeyTake @ { "Result", "Definitions" },
                "TargetContext"      -> $Context,
                "IncludeDefinitions" -> True
            ],
            KeyValuePattern[ "Result" -> _ ]
        ];

        DeleteMissing @ <|
            "ChatContextPreprompt"  -> StringRiffle[ text, "\n\n" ],
            "CellToMessageFunction" -> cellProcFunction[ "Result" ],
            "ChatPost"              -> postFunction[ "Result" ]
        |>
    ];

scrapeChatContextDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*scrape*)
scrape // beginDefinition;

scrape[ nbo_, prop_, validator__ ] :=
    DefinitionNotebookClient`GeneralValidator[ "ChatContextDialog", validator ][
        <|
            "Metadata" -> <| "NotebookObject" -> nbo |>,
            "Content"  -> DefinitionNotebookClient`ScrapeSection[ "ChatContextDialog", nbo, prop ]
        |>
    ];

scrape // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AttachCodeButtons*)
AttachCodeButtons // beginDefinition;

AttachCodeButtons[ Dynamic[ attached_ ], cell_CellObject? chatCodeBlockQ, string_, lang_ ] :=
    Block[ { $InlineChat = inlineChatQ @ cell },
        attached = AttachCell[
            cell,
            floatingButtonGrid[ attached, cell, lang ],
            { Left, Bottom },
            Offset[ { 0, 0 }, Automatic ],
            { Left, Bottom }, (* attaches to ChatCodeBlockTemplate's bottom ImageMargins, not the cell content *)
            RemovalConditions -> { }
        ]
    ];

AttachCodeButtons[ attached_, cell_CellObject, string_, lang_ ] := Enclose[
    Catch @ Module[ { parent, evalCell, newParent },
        parent = parentCell @ cell;

        (* The parent cell is the chat code block as expected, so attach there *)
        If[ chatCodeBlockQ @ parent, Throw @ AttachCodeButtons[ attached, parent, string, lang ] ];

        (* Otherwise, we have an EvaluationCell[] failure, so try to recover by retrying EvaluationCell[] *)
        evalCell = ConfirmMatch[ (FinishDynamic[ ]; EvaluationCell[ ]), _CellObject, "EvaluationCell" ];

        (* The chat code block should be the parent of the current evaluation cell *)
        newParent = If[ chatCodeBlockQ @ evalCell, evalCell, parentCell @ evalCell ];

        (* Finish attaching now that we have the correct cell *)
        If[ chatCodeBlockQ @ newParent,
            AttachCodeButtons[ attached, newParent, string, lang ]
        ]
    ],
    throwInternalFailure
];

AttachCodeButtons // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineChatQ*)
inlineChatQ // beginDefinition;
inlineChatQ[ cell_CellObject ] := inlineChatQ[ cell ] = currentChatSettings[ cell, "InlineChat" ];
inlineChatQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatCodeBlockQ*)
chatCodeBlockQ // beginDefinition;

(* Many operations that return cell objects can return $Failed, but error handling should be done elsewhere: *)
chatCodeBlockQ[ $Failed ] := False;

(* Cache the result, since we might be calling this multiple times on the same cell in AttachCodeButtons: *)
chatCodeBlockQ[ cell_CellObject ] := chatCodeBlockQ[ cell ] = chatCodeBlockQ[ cell, Developer`CellInformation @ cell ];

(* The expected style of a chat code block cell: *)
chatCodeBlockQ[ cell_, KeyValuePattern[ "Style" -> "ChatCodeBlock" ] ] := True;

(* Anything else means it's not a chat block: *)
chatCodeBlockQ[ cell_, _ ] := False;

chatCodeBlockQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ExclusionToggle*)
ExclusionToggle // beginDefinition;

ExclusionToggle[ _, { } ] := Null;

ExclusionToggle[ nbo_NotebookObject, cellObjects: { __CellObject } ] :=
    Enclose @ Module[ { cells, excluded, toggled },
        SelectionMove[ Confirm @ First[ cellObjects, $Failed ], Before, Cell, AutoScroll -> False ];
        cells    = ConfirmMatch[ NotebookRead @ cellObjects, { __Cell } ];
        excluded = MatchQ[ cells, { Cell[ __, "ChatExcluded", ___ ], ___ } ];
        toggled  = ConfirmMatch[ If[ excluded, includeChatCells @ cells, excludeChatCells @ cells ], { __Cell } ];
        CurrentValue[ cellObjects, Deletable ] = True;
        NotebookDelete @ cellObjects;
        NotebookWrite[ nbo, toggled, All ]
    ];

ExclusionToggle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*includeChatCells*)
includeChatCells // beginDefinition;
includeChatCells[ cells_List ] := includeChatCells /@ cells;
includeChatCells[ cell_Cell ] := DeleteCases[ cell, "ChatExcluded" ];
includeChatCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*excludeChatCells*)
excludeChatCells // beginDefinition;
excludeChatCells[ cells_List ] := excludeChatCells /@ cells;
excludeChatCells[ cell: Cell[ __, "ChatExcluded", ___ ] ] := cell;
excludeChatCells[ Cell[ a_, b___String, c: OptionsPattern[ ] ] ] := Cell[ a, b, "ChatExcluded", c ];
excludeChatCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WidgetSend*)
WidgetSend // beginDefinition;

WidgetSend[ cell_CellObject ] := withChatState @
    Block[ { $alwaysOpen = True, cellPrint = cellPrintAfter @ cell, $finalCell = cell, $AutomaticAssistance = True },
        (* TODO: this is currently the only UI method to turn this back on *)
        CurrentValue[ parentNotebook @ cell, { TaggingRules, "ChatNotebookSettings", "Assistance" } ] = True;
        SendChat @ cell
    ];

WidgetSend[ $Failed ] :=
    WidgetSend @ rootEvaluationCell[ ];

WidgetSend // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AskChat*)
AskChat // beginDefinition;

AskChat[ ] := AskChat[ InputNotebook[ ] ];

AskChat[ nbo_NotebookObject ] := AskChat[ nbo, SelectedCells @ nbo ];

AskChat[ nbo_NotebookObject, { selected_CellObject } ] := withChatState @
    Catch @ Module[ { selection, cell, obj },

        selection = Replace[
            NotebookRead @ nbo,
            "" | { } :> (
                SelectionMove[ selected, All, CellContents ];
                NotebookRead @ nbo
            )
        ];

        If[ MatchQ[ selection, "" | { } ], Throw @ Null ];

        cell = chatQueryCell @ selection;
        SelectionMove[ selected, After, Cell ];
        obj = cellPrint @ cell;
        SelectionMove[ obj, All, Cell ];
        selectionEvaluateCreateCell @ nbo
    ];

AskChat[ nbo_NotebookObject, { } ] := Null; (* No cells selected *)

AskChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatQueryCell*)
chatQueryCell // beginDefinition;
chatQueryCell[ s_String      ] := chatQueryCell0 @ StringTrim @ s;
chatQueryCell[ content_List  ] := chatQueryCell0 @ TextData @ content;
chatQueryCell[ text_TextData ] := chatQueryCell0 @ text;
chatQueryCell[ boxes_BoxData ] := chatQueryCell0 @ TextData @ Cell @ boxes;
chatQueryCell[ cell_Cell     ] := chatQueryCell0 @ TextData @ cell;
chatQueryCell[ boxes_        ] := chatQueryCell0 @ BoxData @ boxes;
chatQueryCell // endDefinition;

chatQueryCell0[ content_ ] := Cell[ content, "ChatQuery", GeneratedCell -> False, CellAutoOverwrite -> False ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SendChat*)
SendChat // beginDefinition;

SendChat[ ] := SendChat @ rootEvaluationCell[ ];

SendChat[ evalCell_CellObject? chatExcludedQ, ___ ] := Null;

SendChat[ evalCell_CellObject ] := SendChat[ evalCell, parentNotebook @ evalCell ];

SendChat[ evalCell_CellObject, nbo_NotebookObject? queuedEvaluationsQ ] := Null;

SendChat[ evalCell_CellObject, nbo_NotebookObject ] :=
    withChatState @ SendChat[ evalCell, nbo, resolveAutoSettings @ currentChatSettings @ evalCell ];

SendChat[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    SendChat[ evalCell, nbo, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] /; $cloudNotebooks :=
    SendChat[ evalCell, nbo, settings, False ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] := withChatStateAndFEObjects[
    { evalCell, nbo },
    With[ { styles = cellStyles @ evalCell },
        Block[ { $autoOpen, $alwaysOpen = $alwaysOpen },
            $autoOpen = MemberQ[ styles, $$chatInputStyle ];
            $alwaysOpen = TrueQ[ $alwaysOpen || $autoOpen ];
            $enableLLMServices  = settings[ "EnableLLMServices" ];
            sendChat[ evalCell, nbo, addCellStyleSettings[ settings, styles ] ]
        ]
    ]
];

SendChat[ evalCell_, nbo_, settings_, minimized_ ] := withChatStateAndFEObjects[
    { evalCell, nbo },
    Block[ { $alwaysOpen = alwaysOpenQ[ settings, minimized ] },
        $enableLLMServices  = settings[ "EnableLLMServices" ];
        sendChat[ evalCell, nbo, addCellStyleSettings[ settings, evalCell ] ]
    ]
];

SendChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addCellStyleSettings*)
addCellStyleSettings // beginDefinition;
addCellStyleSettings[ settings_, cell_CellObject ] := addCellStyleSettings[ settings, cellStyles @ cell ];
addCellStyleSettings[ settings_, $$excludeHistoryStyle ] := Association[ settings, "IncludeHistory" -> False ];
addCellStyleSettings[ settings_, _ ] := settings;
addCellStyleSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*queuedEvaluationsQ*)
queuedEvaluationsQ[ nbo_NotebookObject ] :=
    TrueQ[ Count[ Lookup[ Developer`CellInformation @ Cells @ nbo, "Evaluating" ], True ] > 1 ];

queuedEvaluationsQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*alwaysOpenQ*)
alwaysOpenQ // beginDefinition;
alwaysOpenQ[ _, _ ] /; $alwaysOpen := True;
alwaysOpenQ[ as_, True  ] := False;
alwaysOpenQ[ as_, False ] := True;
alwaysOpenQ[ as_, _     ] := StringQ @ as[ "BasePrompt" ] && StringFreeQ[ as[ "BasePrompt" ], $$severityTag ];
alwaysOpenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clearMinimizedChats*)
clearMinimizedChats // beginDefinition;

clearMinimizedChats[ nbo_NotebookObject ] := clearMinimizedChats[ nbo, Cells @ nbo ];

clearMinimizedChats[ nbo_, cells_ ] /; $cloudNotebooks := cells;

clearMinimizedChats[ nbo_NotebookObject, cells_List ] :=
    Module[ { outCells, closed, attached },
        outCells = Cells[ nbo, CellStyle -> $chatOutputStyles ];
        closed = Keys @ Select[ AssociationThread[ outCells -> CurrentValue[ outCells, CellOpen ] ], Not ];
        attached = Cells[ nbo, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ];
        removeTask /@ CurrentValue[ closed, { TaggingRules, "ChatNotebookSettings", "Task" } ];
        NotebookDelete @ Flatten @ { closed, attached };
        DeleteCases[ cells, Alternatives @@ closed ]
    ];

clearMinimizedChats // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clearMinimizedChat*)
clearMinimizedChat // beginDefinition;

clearMinimizedChat[ attached_CellObject, parentCell_CellObject ] :=
    Module[ { next },
        NotebookDelete @ attached;
        next = NextCell @ parentCell;
        If[ MemberQ[ cellStyles @ next, $$chatOutputStyle ] && TrueQ[ ! CurrentValue[ next, CellOpen ] ],
            NotebookDelete @ next;
            next,
            Nothing
        ]
    ];

clearMinimizedChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toAPIKey*)
(* TODO: All this API key stuff can go away once LLMServices is available *)
toAPIKey[ key_String ] := key;

toAPIKey[ Automatic ] := toAPIKey[ Automatic, None ];

toAPIKey[ Automatic, id_ ] := checkAPIKey @ FirstCase[
    Unevaluated @ {
        systemCredential[ "OPENAI_API_KEY" ],
        Environment[ "OPENAI_API_KEY" ],
        apiKeyDialog[ ]
    },
    e_ :> With[ { key = e }, key /; MatchQ[ key, _? StringQ | Missing[ "DialogInputNotAllowed" ] ] ],
    throwFailure[ "NoAPIKey" ]
];

toAPIKey[ other___ ] := throwFailure[ "InvalidAPIKey", other ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*systemCredential*)
systemCredential // beginDefinition;
systemCredential[ name_String ] /; $CloudEvaluation := cloudSystemCredential @ name;
systemCredential[ name_String ] := SystemCredential @ name;
systemCredential // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*cloudSystemCredential*)

(* FIXME: move all cloud workarounds to separate file and define global flag to turn off workarounds *)
cloudSystemCredential // beginDefinition;

(* Workaround for CLOUD-22865 *)
cloudSystemCredential[ name_String ] :=
    cloudSystemCredential[ name, PersistentSymbol[ "Chatbook/SystemCredential/" <> name ] ];

cloudSystemCredential[ name_, _Missing ] :=
    Missing[ "NotAvailable" ];

cloudSystemCredential[ name_, credential: HoldPattern[ _EncryptedObject ] ] :=
    cloudSystemCredential[ name, Decrypt[ $cloudEncryptHash, credential ] ];

cloudSystemCredential[ name_, credential_String ] :=
    credential;

cloudSystemCredential // endDefinition;


$cloudEncryptHash := Hash[ $CloudUserUUID, "SHA256", "HexString" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setSystemCredential*)
setSystemCredential // beginDefinition;
setSystemCredential[ name_, value_ ] /; $CloudEvaluation := setCloudSystemCredential[ name, value ];
setSystemCredential[ name_, value_ ] := (SystemCredential[ name ] = value);
setSystemCredential // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*setCloudSystemCredential*)
setCloudSystemCredential // beginDefinition;

setCloudSystemCredential[ name_, value_ ] := Enclose[
    Module[ { encrypted },
        encrypted = ConfirmMatch[ Encrypt[ $cloudEncryptHash, value ], _EncryptedObject, "Encrypt" ];
        PersistentSymbol[ "Chatbook/SystemCredential/" <> name ] = encrypted;
        ConfirmAssert[ cloudSystemCredential[ name ] === value, "CheckStoredCredential" ];
    ],
    throwInternalFailure[ setCloudSystemCredential[ name, value ], ## ] &
];

setCloudSystemCredential // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkAPIKey*)
checkAPIKey // beginDefinition;
checkAPIKey[ Missing[ "DialogInputNotAllowed" ] ] := Missing[ "DialogInputNotAllowed" ];
checkAPIKey[ key_String ] /; MatchQ[ getModelList @ key, { __String } ] := checkAPIKey[ key ] = key;
checkAPIKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*apiKeyDialog*)
apiKeyDialog // beginDefinition;

apiKeyDialog[ ] /; $dialogInputAllowed :=
    Enclose @ Module[ { result, key },
        result = ConfirmBy[ showAPIKeyDialog[ ], AssociationQ ];
        key    = ConfirmBy[ result[ "APIKey" ], StringQ ];

        If[ result[ "Save" ], setSystemCredential[ "OPENAI_API_KEY", key ] ];
        updateDynamics[ "Models" ];

        key
    ];

apiKeyDialog[ ] /; ! TrueQ @ $dialogInputAllowed :=
    Missing[ "DialogInputNotAllowed" ];

apiKeyDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showAPIKeyDialog*)
showAPIKeyDialog // beginDefinition;

showAPIKeyDialog[ ] := AuthenticationDialog[
    FormObject[
        {
            "APIKey" -> <|
                "Masked"  -> True,
                "Label"   -> tr[ "ActionsAPIKeyDialogAPIKey" ],
                "Control" -> Function[
                    InputField[
                        ##,
                        FieldMasked           -> True,
                        FieldHint             -> "sk-...XXXX",
                        DefaultBaseStyle      -> "FormField",
                        DefaultFieldHintStyle -> "FormFieldHint",
                        ImageSize             -> { Scaled[ 1 ], Automatic }
                    ]
                ]
            |>,
            "Save" -> <| "Interpreter" -> "Boolean", "Label" -> tr[ "ActionsAPIKeyDialogSave" ] |>
        },
        AppearanceRules -> {
            "Title"       -> tr[ "ActionsAPIKeyDialogTitle" ],
            "Description" -> getAsset[ "APIKeyDialogDescription" ]
        }
    ],
    WindowSize     -> { 400, All },
    WindowElements -> { "StatusArea" }
];

showAPIKeyDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet Assets*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAsset*)
getAsset // beginDefinition;

getAsset[ name0_String? StringQ ] := Enclose[
    Module[ { name, dir, file, expr },
        name = StringDelete[ name0, ".wl"~~EndOfString ] <> ".wl";
        dir  = ConfirmBy[ $thisPaclet[ "AssetLocation", "AIAssistant" ], DirectoryQ, "Directory" ];
        file = ConfirmBy[ FileNameJoin @ { dir, name }, FileExistsQ, "File" ];
        expr = Confirm[ getAssetFile @ file, "Expression" ];
        getAsset[ name ] = expr
    ],
    throwInternalFailure
];

getAsset // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAssetFile*)
getAssetFile // beginDefinition;

getAssetFile[ file_? FileExistsQ ] :=
    Block[
        {
            $Context     = "Wolfram`ChatNB`",
            $ContextPath = { "Wolfram`ChatNB`", "Wolfram`Chatbook`Common`", "System`" }
        },
        Get @ file
    ];

getAssetFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
