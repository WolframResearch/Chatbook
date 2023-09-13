(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Actions`" ];

(* cSpell: ignore TOOLCALL, ENDTOOLCALL, ENDRESULT, nodef *)

(* TODO: these probably aren't needed as exported symbols since all hooks are going through ChatbookAction *)
`AskChat;
`AttachCodeButtons;
`AIAutoAssist;
`CopyChatObject;
`EvaluateChatInput;
`ExclusionToggle;
`OpenChatMenu;
`SendChat;
`StopChat;
`WidgetSend;

`$settings;
`autoAssistQ;
`makeOutputDingbat;
`getModelList;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`Errors`"           ];
Needs[ "Wolfram`Chatbook`ErrorUtils`"       ];
Needs[ "Wolfram`Chatbook`PersonaInstaller`" ];
Needs[ "Wolfram`Chatbook`ToolManager`"      ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`Serialization`"    ];
Needs[ "Wolfram`Chatbook`Formatting`"       ];
Needs[ "Wolfram`Chatbook`Explode`"          ];
Needs[ "Wolfram`Chatbook`FrontEnd`"         ];
Needs[ "Wolfram`Chatbook`InlineReferences`" ];
Needs[ "Wolfram`Chatbook`Prompting`"        ];
Needs[ "Wolfram`Chatbook`Tools`"            ];

HoldComplete[
    System`GenerateLLMToolResponse,
    System`LLMToolRequest,
    System`LLMToolResponse
];

(* TODO: move some content from this file into separate files:
   SendChat.wl - a huge portion of this file would move here
   AutoAssistant.wl - code related to tagging, cell opening, etc.
   ChatBlocks.wl - chat history, chat block settings dialog, etc.
   Services.wl - authentication, etc.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatbookAction*)
ChatbookAction[ "AIAutoAssist"         , args___ ] := catchMine @ AIAutoAssist @ args;
ChatbookAction[ "Ask"                  , args___ ] := catchMine @ AskChat @ args;
ChatbookAction[ "AttachCodeButtons"    , args___ ] := catchMine @ AttachCodeButtons @ args;
ChatbookAction[ "CopyChatObject"       , args___ ] := catchMine @ CopyChatObject @ args;
ChatbookAction[ "CopyExplodedCells"    , args___ ] := catchMine @ CopyExplodedCells @ args;
ChatbookAction[ "DisableAssistance"    , args___ ] := catchMine @ DisableAssistance @ args;
ChatbookAction[ "EvaluateChatInput"    , args___ ] := catchMine @ EvaluateChatInput @ args;
ChatbookAction[ "ExclusionToggle"      , args___ ] := catchMine @ ExclusionToggle @ args;
ChatbookAction[ "ExplodeDuplicate"     , args___ ] := catchMine @ ExplodeDuplicate @ args;
ChatbookAction[ "ExplodeInPlace"       , args___ ] := catchMine @ ExplodeInPlace @ args;
ChatbookAction[ "InsertInlineReference", args___ ] := catchMine @ InsertInlineReference @ args;
ChatbookAction[ "OpenChatBlockSettings", args___ ] := catchMine @ OpenChatBlockSettings @ args;
ChatbookAction[ "OpenChatMenu"         , args___ ] := catchMine @ OpenChatMenu @ args;
ChatbookAction[ "PersonaManage"        , args___ ] := catchMine @ PersonaManage @ args;
ChatbookAction[ "ToolManage"           , args___ ] := catchMine @ ToolManage @ args;
ChatbookAction[ "Send"                 , args___ ] := catchMine @ SendChat @ args;
ChatbookAction[ "StopChat"             , args___ ] := catchMine @ StopChat @ args;
ChatbookAction[ "TabLeft"              , args___ ] := catchMine @ TabLeft @ args;
ChatbookAction[ "TabRight"             , args___ ] := catchMine @ TabRight @ args;
ChatbookAction[ "ToggleFormatting"     , args___ ] := catchMine @ ToggleFormatting @ args;
ChatbookAction[ "WidgetSend"           , args___ ] := catchMine @ WidgetSend @ args;
ChatbookAction[ name_String            , args___ ] := catchMine @ throwFailure[ "NotImplemented", name, args ];
ChatbookAction[ args___                          ] := catchMine @ throwInternalFailure @ ChatbookAction @ args;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CopyExplodedCells*)
CopyExplodedCells // beginDefinition;

CopyExplodedCells[ cellObject_CellObject ] := Enclose[
    Module[ { exploded },
        exploded = ConfirmMatch[ explodeCell @ cellObject, { ___Cell }, "ExplodeCell" ];
        CopyToClipboard @ exploded
    ],
    throwInternalFailure[ CopyExplodedCells @ cellObject, ## ] &
];

CopyExplodedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ExplodeDuplicate*)
ExplodeDuplicate // beginDefinition;

ExplodeDuplicate[ cellObject_CellObject ] := Enclose[
    Module[ { exploded, nbo },
        exploded = ConfirmMatch[ explodeCell @ cellObject, { __Cell }, "ExplodeCell" ];
        SelectionMove[ cellObject, After, Cell, AutoScroll -> False ];
        nbo = ConfirmMatch[ parentNotebook @ cellObject, _NotebookObject, "ParentNotebook" ];
        ConfirmMatch[ NotebookWrite[ nbo, exploded ], Null, "NotebookWrite" ]
    ],
    throwInternalFailure[ ExplodeDuplicate @ cellObject, ## ] &
];

ExplodeDuplicate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ExplodeInPlace*)
ExplodeInPlace // beginDefinition;

ExplodeInPlace[ cellObject_CellObject ] := Enclose[
    Module[ { exploded },
        exploded = ConfirmMatch[ explodeCell @ cellObject, { __Cell }, "ExplodeCell" ];
        ConfirmMatch[ NotebookWrite[ cellObject, exploded ], Null, "NotebookWrite" ]
    ],
    throwInternalFailure[ ExplodeInPlace @ cellObject, ## ] &
];

ExplodeInPlace // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ToggleFormatting*)
ToggleFormatting // beginDefinition;

ToggleFormatting[ cellObject_CellObject ] := Enclose[
    Module[ { nbo, content },
        nbo = ConfirmMatch[ parentNotebook @ cellObject, _NotebookObject, "ParentNotebook" ];
        SelectionMove[ cellObject, All, CellContents, AutoScroll -> False ];
        content = ConfirmMatch[ NotebookRead @ nbo, _String | _List, "NotebookRead" ];
        Confirm[ toggleFormatting[ cellObject, nbo, content ], "Toggle" ]
    ],
    throwInternalFailure[ ToggleFormatting @ cellObject, ## ] &
];

ToggleFormatting // endDefinition;

(* TODO: If the chat output is just a plain string with no markdown, toggling formatting is a no-op.
         Should this display a message dialog in this case explaining that there's nothing to toggle? *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toggleFormatting*)
toggleFormatting // beginDefinition;

(* Convert a plain string to formatted TextData: *)
toggleFormatting[ cellObject_CellObject, nbo_NotebookObject, string_String ] := Enclose[
    Module[ { textDataList },
        textDataList = ConfirmMatch[ reformatTextData @ string, $$textDataList, "ReformatTextData" ];
        Confirm[ SelectionMove[ cellObject, All, CellContents, AutoScroll -> False ], "SelectionMove" ];
        Confirm[ NotebookWrite[ nbo, TextData @ textDataList, None ], "NotebookWrite" ]
    ],
    throwInternalFailure[ toggleFormatting[ cellObject, nbo, string ], ## ] &
];

(* Convert formatted TextData to a plain string: *)
toggleFormatting[ cellObject_CellObject, nbo_NotebookObject, textDataList_List ] := Enclose[
    Module[ { string },
        string = ConfirmMatch[ CellToString @ Cell[ TextData @ textDataList, "ChatOutput" ], _String, "CellToString" ];
        Confirm[ SelectionMove[ cellObject, All, CellContents, AutoScroll -> False ], "SelectionMove" ];
        Confirm[ NotebookWrite[ nbo, TextData @ string, None ], "NotebookWrite" ]
    ],
    throwInternalFailure[ toggleFormatting[ cellObject, nbo, textDataList ], ## ] &
];

toggleFormatting // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DisableAssistance*)
DisableAssistance // beginDefinition;

DisableAssistance[ cell_CellObject ] := (
    DisableAssistance @ parentNotebook @ cell;
    NotebookDelete @ parentCell @ cell;
    NotebookDelete @ cell;
);

DisableAssistance[ nbo_NotebookObject ] := (
    CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings", "Assistance" } ] = False
);

DisableAssistance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InsertInlineReference*)
InsertInlineReference // beginDefinition;
InsertInlineReference[ type_, cell_CellObject ] := insertInlineReference[ type, loadDefinitionNotebook @ cell ];
InsertInlineReference // endDefinition;

insertInlineReference // beginDefinition;

insertInlineReference[ "Persona"         , args___ ] := insertPersonaInputBox @ args;
insertInlineReference[ "TrailingFunction", args___ ] := insertTrailingFunctionInputBox @ args;
insertInlineReference[ "Function"        , args___ ] := insertFunctionInputBox @ args;
insertInlineReference[ "Modifier"        , args___ ] := insertModifierInputBox @ args;

insertInlineReference[ "PersonaTemplate" , args___ ] := insertPersonaTemplate @ args;
insertInlineReference[ "FunctionTemplate", args___ ] := insertFunctionTemplate @ args;
insertInlineReference[ "ModifierTemplate", args___ ] := insertModifierTemplate @ args;

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
    ConfirmMatch[ createPersonaManagerDialog[ ], _NotebookObject, "createPersonaManagerDialog" ],
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
TabLeft[ cell_CellObject ] := rotateTabPage[ cell, -1 ];
TabLeft // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TabRight*)
TabRight // beginDefinition;
TabRight[ cell_CellObject ] := rotateTabPage[ cell, 1 ];
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
        content     = ConfirmMatch[ BinaryDeserialize @ BaseDecode @ encoded, TextData[ _String|_List ], "Content" ];

        writePageContent[ cell, newPage, content ]
    ],
    throwInternalFailure[ rotateTabPage[ cell, n ], ## ] &
];

rotateTabPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writePageContent*)
writePageContent // beginDefinition;

writePageContent[ cell_CellObject, newPage_Integer, content: TextData[ _String | _List ] ] /; $cloudNotebooks := (
    CurrentValue[ cell, { TaggingRules, "PageData", "CurrentPage" } ] = newPage;
    CurrentValue[ cell, TaggingRules ] = GeneralUtilities`ToAssociations @ CurrentValue[ cell, TaggingRules ];
    NotebookWrite[ cell, ReplacePart[ NotebookRead @ cell, 1 -> content ] ];
)

writePageContent[ cell_CellObject, newPage_Integer, content: TextData[ _String | _List ] ] := (
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
    EvaluateChatInput[ evalCell, parentNotebook @ evalCell ];

EvaluateChatInput[ source: _CellObject | $Failed ] :=
    With[ { evalCell = rootEvaluationCell @ source },
        EvaluateChatInput @ evalCell /; chatInputCellQ @ evalCell
    ];

EvaluateChatInput[ evalCell_CellObject, nbo_NotebookObject ] :=
    EvaluateChatInput[ evalCell, nbo, currentChatSettings @ nbo ];

EvaluateChatInput[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    withChatState @ Block[ { $autoAssistMode = False },
        $lastMessages       = None;
        $lastChatString     = None;
        $nextTaskEvaluation = None;
        clearMinimizedChats @ nbo;
        sendChat[ evalCell, nbo, settings ];
        waitForLastTask[ ];
        blockChatObject[
            If[ ListQ @ $lastMessages && StringQ @ $lastChatString,
                constructChatObject @ Append[
                    $lastMessages,
                    <| "role" -> "Assistant", "content" -> $lastChatString |>
                ],
                Null
            ];
        ]
    ];

EvaluateChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*blockChatObject*)
blockChatObject // beginDefinition;
blockChatObject // Attributes = { HoldFirst };
blockChatObject[ eval_ ] /; Quiet @ PacletNewerQ[ PacletObject[ "Wolfram/LLMFunctions" ], "1.1.0" ] := eval;
blockChatObject[ eval_ ]  := Block[ { chatObject = delayedChatObject, delayedChatObject }, eval ];
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
chatInputCellQ[ cell_CellObject, ___ ] := ($badCellObject = cell; $badCell = NotebookRead @ cell; False);
chatInputCellQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*waitForLastTask*)
waitForLastTask // beginDefinition;

waitForLastTask[ ] := waitForLastTask @ $lastTask;

waitForLastTask[ task_TaskObject ] := (
    TaskWait @ task;
    runNextTask[ ];
    If[ $lastTask =!= task, waitForLastTask @ $lastTask ]
);

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
    If[ autoAssistQ[ cell, nbo ],
        Block[ { $autoAssistMode = True }, needsBasePrompt[ "AutoAssistant" ]; SendChat @ cell ],
        Null
    ];

AIAutoAssist // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*autoAssistQ*)
autoAssistQ // beginDefinition;

autoAssistQ[ cell_CellObject, nbo_NotebookObject ] := autoAssistQ[ cellInformation @ cell, cell, nbo ];

autoAssistQ[ KeyValuePattern[ "Style" -> $$chatInputStyle ], _, _ ] := False;

autoAssistQ[ info_, cell_CellObject, nbo_NotebookObject ] :=
    autoAssistQ[
        currentChatSettings[ nbo, "Assistance" ],
        currentChatSettings[ cell, "Assistance" ]
    ];

autoAssistQ[ True|Automatic|Inherited, True|Automatic|Inherited ] := True;
autoAssistQ[ _, True|Automatic ] := True;
autoAssistQ[ _, _ ] := False;

(* Determine if auto assistance is enabled generally within a FE or Notebook. *)
autoAssistQ[
    target: _FrontEndObject | $FrontEndSession | _NotebookObject
] :=
    autoAssistQ[
        Inherited,
        currentChatSettings[ target, "Assistance" ]
    ]

autoAssistQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*StopChat*)
StopChat // beginDefinition;

StopChat[ cell0_CellObject ] := Enclose[
    Module[ { cell, settings, container, content },
        cell = ConfirmMatch[ parentCell @ cell0, _CellObject, "ParentCell" ];
        settings = ConfirmBy[ currentChatSettings @ cell, AssociationQ, "ChatNotebookSettings" ];
        removeTask @ Lookup[ settings, "Task" ];
        container = ConfirmBy[ Lookup[ settings, "Container" ], AssociationQ, "Container" ];
        content = ConfirmMatch[ Lookup[ container, "FullContent" ], _String|_ProgressIndicator, "Content" ];
        FinishDynamic[ ];
        Block[ { createFETask = # & }, writeReformattedCell[ settings, content, cell ] ]
    ],
    throwInternalFailure[ StopChat @ cell0, ## ] &
];

StopChat // endDefinition;

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

CopyChatObject[ cell_CellObject ] := Enclose[
    Module[ { encodedString, chatData, messages, chatObject },
        Quiet[ PacletInstall[ "Wolfram/LLMFunctions" ]; Needs[ "Wolfram`LLMFunctions`" -> None ] ];
        encodedString = ConfirmBy[ CurrentValue[ cell, { TaggingRules, "ChatData" } ], StringQ, "EncodedString" ];
        chatData      = ConfirmBy[ BinaryDeserialize @ BaseDecode @ encodedString, AssociationQ, "ChatData" ];
        messages      = ConfirmMatch[ chatData[ "Data", "Messages" ], { __Association? AssociationQ }, "Messages" ];
        chatObject    = Confirm[ constructChatObject @ messages, "ChatObject" ];
        CopyToClipboard @ chatObject
    ],
    throwInternalFailure[ HoldForm @ CopyChatObject @ cell, ## ] &
];

CopyChatObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*constructChatObject*)
constructChatObject // beginDefinition;

constructChatObject[ messages_List ] :=
    With[ { chat = chatObject[ MapAt[ Capitalize, KeyMap[ Capitalize ] /@ messages, { All, "Role" } ] ] },
        chat /; MatchQ[ chat, _chatObject ]
    ];

constructChatObject[ messages_List ] :=
    Dataset[ KeyMap[ Capitalize ] /@ messages ];

constructChatObject // endDefinition;

chatObject := chatObject = Symbol[ "System`ChatObject" ];

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
            { TaggingRules, "ChatNotebookSettings", "ChatContextCellProcessingFunction" }
        ];
        cellFuncCell = Cell[ BoxData @ ToBoxes @ cellFunc, "Input", CellID -> 2, CellTags -> { "NonDefault" } ];

        postFunc = AbsoluteCurrentValue[
            cell,
            { TaggingRules, "ChatNotebookSettings", "ChatContextPostEvaluationFunction" }
        ];
        postFuncCell = Cell[ BoxData @ ToBoxes @ postFunc, "Input", CellID -> 3, CellTags -> { "NonDefault" } ];

        cells = TemplateApply[
            $chatContextDialogTemplateCells,
            DeleteMissing @ <|
                "ChatContextPreprompt"              -> textCell,
                "ChatContextCellProcessingFunction" -> cellFuncCell,
                "ChatContextPostEvaluationFunction" -> postFuncCell,
                "DialogButtons"                     -> chatContextDialogButtons @ cell
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
$chatContextDialogButtons := $chatContextDialogButtons = Get @ FileNameJoin @ {
    PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "AIAssistant" ],
    "ChatContextDialogButtons.wl"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatContextDialogTemplateCells*)
$chatContextDialogTemplateCells := $chatContextDialogTemplateCells = Get @ FileNameJoin @ {
    PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "AIAssistant" ],
    "ChatContextDialogCellsTemplate.wl"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatContextDialogStyles*)
$chatContextDialogStyles := $chatContextDialogStyles = Get @ FileNameJoin @ {
    PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "AIAssistant" ],
    "ChatContextDialogStyles.wl"
};

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
                "ChatContextCellProcessingFunction",
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
                "ChatContextPostEvaluationFunction",
                "Expression",
                KeyTake @ { "Result", "Definitions" },
                "TargetContext"      -> $Context,
                "IncludeDefinitions" -> True
            ],
            KeyValuePattern[ "Result" -> _ ]
        ];

        DeleteMissing @ <|
            "ChatContextPreprompt"              -> StringRiffle[ text, "\n\n" ],
            "ChatContextCellProcessingFunction" -> cellProcFunction[ "Result" ],
            "ChatContextPostEvaluationFunction" -> postFunction[ "Result" ]
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

AttachCodeButtons[ attached_, cell0_CellObject, string_, lang_ ] :=
    With[ { cell = parentCell @ cell0 },
        AttachCodeButtons[ attached, cell, string, lang ] /; chatCodeBlockQ @ cell
    ];

AttachCodeButtons[ Dynamic[ attached_ ], cell_CellObject, string_, lang_ ] := (
    attached = AttachCell[
        cell,
        floatingButtonGrid[ attached, string, lang ],
        { Left, Bottom },
        Offset[ { 0, 13 }, { 0, 0 } ],
        { Left, Top },
        RemovalConditions -> { "MouseClickOutside", "MouseExit" }
    ]
);

AttachCodeButtons // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatCodeBlockQ*)
chatCodeBlockQ // beginDefinition;
chatCodeBlockQ[ cell_CellObject ] := chatCodeBlockQ[ cell, Developer`CellInformation @ cell ];
chatCodeBlockQ[ cell_, KeyValuePattern[ "Style" -> "ChatCodeBlock" ] ] := True;
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
    Block[ { $alwaysOpen = True, cellPrint = cellPrintAfter @ cell, $finalCell = cell, $autoAssistMode = True },
        (* TODO: this is currently the only UI method to turn this back on *)
        CurrentValue[ parentNotebook @ cell, { TaggingRules, "ChatNotebookSettings", "Assistance" } ] = True;
        SendChat @ cell
    ];

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

SendChat[ evalCell_CellObject, ___ ] /; MemberQ[ CurrentValue[ evalCell, CellStyle ], "ChatExcluded" ] := Null;

SendChat[ evalCell_CellObject ] := SendChat[ evalCell, parentNotebook @ evalCell ];

SendChat[ evalCell_CellObject, nbo_NotebookObject? queuedEvaluationsQ ] := Null;

SendChat[ evalCell_CellObject, nbo_NotebookObject ] :=
    SendChat[ evalCell, nbo, currentChatSettings @ nbo ];

SendChat[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    SendChat[ evalCell, nbo, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] /; $cloudNotebooks :=
    SendChat[ evalCell, nbo, settings, False ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] := withChatState @
    With[ { styles = cellStyles @ evalCell },
        Block[ { $autoOpen, $alwaysOpen = $alwaysOpen },
            $autoOpen = MemberQ[ styles, $$chatInputStyle ];
            $alwaysOpen = TrueQ[ $alwaysOpen || $autoOpen ];
            sendChat[ evalCell, nbo, addCellStyleSettings[ settings, styles ] ]
        ]
    ];

SendChat[ evalCell_, nbo_, settings_, minimized_ ] := withChatState @
    Block[ { $alwaysOpen = alwaysOpenQ[ settings, minimized ] },
        sendChat[ evalCell, nbo, addCellStyleSettings[ settings, evalCell ] ]
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
(* ::Subsection::Closed:: *)
(*sendChat*)
sendChat // beginDefinition;

sendChat[ evalCell_, nbo_, settings0_ ] := catchTopAs[ ChatbookAction ] @ Enclose[
    Module[ { cells0, cells, target, settings, id, key, req, data, persona, cell, cellObject, container, task },

        initFETaskWidget @ nbo;

        resolveInlineReferences @ evalCell;
        cells0 = ConfirmMatch[ selectChatCells[ settings0, evalCell, nbo ], { __CellObject }, "SelectChatCells" ];

        { cells, target } = ConfirmMatch[
            chatHistoryCellsAndTarget @ cells0,
            { { __CellObject }, _CellObject | None },
            "HistoryAndTarget"
        ];

        settings = ConfirmBy[
            resolveTools @ resolveAutoSettings @ inheritSettings[ settings0, cells, evalCell ],
            AssociationQ,
            "InheritSettings"
        ];

        id  = Lookup[ settings, "ID" ];
        key = toAPIKey[ Automatic, id ];

        If[ ! settings[ "IncludeHistory" ], cells = { evalCell } ];

        If[ ! StringQ @ key, throwFailure[ "NoAPIKey" ] ];

        settings[ "OpenAIKey" ] = key;

        { req, data } = Reap[
            ConfirmMatch[
                makeHTTPRequest[ settings, cells ],
                _HTTPRequest,
                "MakeHTTPRequest"
            ],
            $chatDataTag
        ];

        data = ConfirmBy[ Association @ Flatten @ data, AssociationQ, "Data" ];

        If[ data[ "RawOutput" ],
            persona = ConfirmBy[ GetCachedPersonaData[ "RawModel" ], AssociationQ, "NonePersona" ];
            If[ AssociationQ @ settings[ "LLMEvaluator" ],
                settings[ "LLMEvaluator" ] = Association[ settings[ "LLMEvaluator" ], persona ],
                settings = Association[ settings, persona ]
            ]
        ];

        AppendTo[ settings, "Data" -> data ];

        container = <|
            "DynamicContent" -> ProgressIndicator[ Appearance -> "Percolate" ],
            "FullContent"    -> ProgressIndicator[ Appearance -> "Percolate" ],
            "UUID"           -> CreateUUID[ ]
        |>;

        $reformattedCell = None;
        cell = activeAIAssistantCell[
            container,
            Association[ settings, "Container" :> container, "CellObject" :> cellObject, "Task" :> task ]
        ];

        Quiet[
            TaskRemove @ $lastTask;
            NotebookDelete @ $lastCellObject;
        ];

        $resultCellCache = <| |>;
        $debugLog = Internal`Bag[ ];

        If[ ! TrueQ @ $cloudNotebooks && chatInputCellQ @ evalCell,
            SetOptions[
                evalCell,
                CellDingbat -> Cell[ BoxData @ TemplateBox[ { }, "ChatInputCellDingbat" ], Background -> None ]
            ]
        ];

        cellObject = $lastCellObject = ConfirmMatch[
            createNewChatOutput[ settings, target, cell ],
            _CellObject,
            "CreateOutput"
        ];

        task = Confirm[ $lastTask = submitAIAssistant[ container, req, cellObject, settings ] ];

        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "CellObject" } ] = cellObject;
        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "Task"       } ] = task;
    ],
    throwInternalFailure[ sendChat[ evalCell, nbo, settings0 ], ## ] &
];

sendChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveAutoSettings*)
resolveAutoSettings // beginDefinition;

resolveAutoSettings[ settings: KeyValuePattern[ "ToolsEnabled" -> Automatic ] ] :=
    resolveAutoSettings @ Association[ settings, "ToolsEnabled" -> toolsEnabledQ @ settings ];

resolveAutoSettings[ settings_Association ] := settings;

resolveAutoSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolsEnabledQ*)
toolsEnabledQ[ KeyValuePattern[ "ToolsEnabled" -> enabled: True|False ] ] := enabled;
toolsEnabledQ[ KeyValuePattern[ "Model" -> model_String ] ] := toolsEnabledQ @ toModelName @ model;
toolsEnabledQ[ model_String ] := ! TrueQ @ StringStartsQ[ model, "gpt-3", IgnoreCase -> True ];
toolsEnabledQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getLLMEvaluator*)
getLLMEvaluator // beginDefinition;
getLLMEvaluator[ as_Association ] := getLLMEvaluator[ as, Lookup[ as, "LLMEvaluator" ] ];
getLLMEvaluator[ as_, name_String ] :=
    (* If there isn't any information on `name`, getNamedLLMEvaluator just
        returns `name`; if that happens, avoid infinite recursion by just
        returning *)
    Replace[getNamedLLMEvaluator[name], {
        name -> name,
        other_ :> getLLMEvaluator[as, other]
    }]
getLLMEvaluator[ as_, evaluator_Association ] := evaluator;
getLLMEvaluator[ _, _ ] := None;
getLLMEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNamedLLMEvaluator*)
getNamedLLMEvaluator // beginDefinition;
getNamedLLMEvaluator[ name_String ] := getNamedLLMEvaluator[ name, GetCachedPersonaData @ name ];
getNamedLLMEvaluator[ name_String, evaluator_Association ] := Append[ evaluator, "LLMEvaluatorName" -> name ];
getNamedLLMEvaluator[ name_String, _ ] := name;
getNamedLLMEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createNewChatOutput*)
createNewChatOutput // beginDefinition;
createNewChatOutput[ settings_, None, cell_Cell ] := cellPrint @ cell;
createNewChatOutput[ settings_, target_, cell_Cell ] /; settings[ "TabbedOutput" ] === False := cellPrint @ cell;
createNewChatOutput[ settings_, target_CellObject, cell_Cell ] := prepareChatOutputPage[ target, cell ];
createNewChatOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareChatOutputPage*)
prepareChatOutputPage // beginDefinition;

prepareChatOutputPage[ target_CellObject, cell_Cell ] := Enclose[
    Module[ { prevCellExpr, prevPage, encoded, pageData, newCellObject },

        prevCellExpr = ConfirmMatch[ NotebookRead @ target, _Cell, "NotebookRead" ];

        prevPage = ConfirmMatch[
            Replace[ First @ prevCellExpr, text_String :> TextData @ { text } ],
            _TextData,
            "PageContent"
        ];

        encoded = ConfirmBy[
            BaseEncode @ BinarySerialize[ prevPage, PerformanceGoal -> "Size" ],
            StringQ,
            "BaseEncode"
        ];

        pageData = ConfirmBy[
            Replace[
                prevCellExpr,
                {
                    Cell[ __, TaggingRules -> KeyValuePattern[ "PageData" -> data_ ], ___ ] :> Association @ data,
                    _ :> <| |>
                }
            ],
            AssociationQ,
            "PageData"
        ];

        If[ ! AssociationQ @ pageData[ "Pages" ], pageData[ "Pages" ] = <| 1 -> encoded |> ];
        If[ ! IntegerQ @ pageData[ "PageCount" ], pageData[ "PageCount" ] = 1 ];
        If[ ! IntegerQ @ pageData[ "CurrentPage" ], pageData[ "CurrentPage" ] = 1 ];
        pageData[ "PagedOutput" ] = True;

        newCellObject = cellPrint @ cell;
        CurrentValue[ newCellObject, { TaggingRules, "PageData" } ] = pageData;
        newCellObject
    ],
    throwInternalFailure[ prepareChatOutputPage[ target, cell ], ## ] &
];

prepareChatOutputPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatHistoryCellsAndTarget*)
chatHistoryCellsAndTarget // beginDefinition;

chatHistoryCellsAndTarget[ { before___CellObject, after_CellObject } ] :=
    If[ MatchQ[ cellInformation @ after, KeyValuePattern[ "Style" -> $$chatOutputStyle ] ],
        { { before }, after },
        { { before, after }, None }
    ];

chatHistoryCellsAndTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inheritSettings*)
inheritSettings // beginDefinition;

inheritSettings[ settings_, { first_CellObject, ___ }, evalCell_CellObject ] :=
    inheritSettings[ settings, cellInformation @ first, evalCell ];

inheritSettings[
    settings_Association,
    KeyValuePattern @ { "Style" -> $$chatDelimiterStyle, "CellObject" -> delimiter_CellObject },
    evalCell_CellObject
] := mergeSettings[ settings, currentChatSettings @ delimiter, currentChatSettings @ evalCell ];

inheritSettings[ settings_Association, _, evalCell_CellObject ] :=
    mergeSettings[ settings, <| |>, currentChatSettings @ evalCell ];

inheritSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeSettings*)
mergeSettings // beginDefinition;

mergeSettings[ settings_? AssociationQ, group_? AssociationQ, cell_? AssociationQ ] :=
    Module[ { as },
        as = Association[ settings, Complement[ group, settings ], Complement[ cell, settings ] ];
        Association[ as, "LLMEvaluator" -> getLLMEvaluator @ as ]
    ];\

mergeSettings // endDefinition;\

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
(*submitAIAssistant*)
submitAIAssistant // beginDefinition;
submitAIAssistant // Attributes = { HoldFirst };

submitAIAssistant[ container_, req_, cellObject_, settings_ ] :=
    With[
        {
            autoOpen     = TrueQ @ $autoOpen,
            alwaysOpen   = TrueQ @ $alwaysOpen,
            autoAssist   = $autoAssistMode,
            dynamicSplit = dynamicSplitQ @ settings
        },
        URLSubmit[
            req,
            HandlerFunctions -> <|
                "BodyChunkReceived" -> Function @ catchAlways[
                    Block[
                        {
                            $autoOpen       = autoOpen,
                            $alwaysOpen     = alwaysOpen,
                            $settings       = settings,
                            $autoAssistMode = autoAssist,
                            $dynamicSplit   = dynamicSplit
                        },
                        Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                        writeChunk[ Dynamic @ container, cellObject, #1 ]
                    ]
                ],
                "TaskFinished" -> Function @ catchAlways[
                    Block[
                        {
                            $autoOpen       = autoOpen,
                            $alwaysOpen     = alwaysOpen,
                            $settings       = settings,
                            $autoAssistMode = autoAssist,
                            $dynamicSplit   = dynamicSplit
                        },
                        Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                        checkResponse[ settings, Unevaluated @ container, cellObject, #1 ]
                    ]
                ]
            |>,
            HandlerFunctionsKeys -> { "BodyChunk", "StatusCode", "Task", "TaskStatus", "EventName" },
            CharacterEncoding    -> "UTF8"
        ]
    ];

submitAIAssistant // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dynamicSplitQ*)
dynamicSplitQ // beginDefinition;
dynamicSplitQ[ as_Association ] := dynamicSplitQ @ Lookup[ as, "StreamingOutputMethod", Automatic ];
dynamicSplitQ[ sym_Symbol ] := dynamicSplitQ @ SymbolName @ sym;
dynamicSplitQ[ "PartialDynamic"|"Automatic"|"Inherited" ] := True;
dynamicSplitQ[ "FullDynamic"|"Dynamic" ] := False;
dynamicSplitQ[ other_ ] := (messagePrint[ "InvalidStreamingOutputMethod", other ]; True);
dynamicSplitQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractMessageText*)
extractMessageText // beginDefinition;

extractMessageText[ KeyValuePattern[
    "choices" -> {
        KeyValuePattern[ "message" -> KeyValuePattern[ "content" -> message_String ] ],
        ___
    }
] ] := untagString @ message;

extractMessageText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*activeAIAssistantCell*)
activeAIAssistantCell // beginDefinition;
activeAIAssistantCell // Attributes = { HoldFirst };

activeAIAssistantCell[ container_, settings_Association? AssociationQ ] :=
    activeAIAssistantCell[ container, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

activeAIAssistantCell[
    container_,
    settings: KeyValuePattern[ "CellObject" :> cellObject_ ],
    minimized_
] /; $cloudNotebooks :=
    With[
        {
            label    = RawBoxes @ TemplateBox[ { }, "MinimizedChatActive" ],
            id       = $SessionID,
            reformat = dynamicAutoFormatQ @ settings,
            task     = Lookup[ settings, "Task" ]
        },
        Module[ { x = 0 },
            ClearAttributes[ { x, cellObject }, Temporary ];
            Cell[
                BoxData @ ToBoxes @
                    If[ TrueQ @ reformat,
                        Dynamic[
                            Refresh[
                                x++;
                                If[ MatchQ[ $reformattedCell, _Cell ],
                                    Pause[ 1 ];
                                    NotebookWrite[ cellObject, $reformattedCell ];
                                    Remove[ x, cellObject ];
                                    ,
                                    catchTop @ dynamicTextDisplay[ container, reformat ]
                                ],
                                TrackedSymbols :> { x },
                                UpdateInterval -> 0.4
                            ],
                            Initialization   :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ],
                            Deinitialization :> Quiet @ TaskRemove @ task
                        ],
                        Dynamic[
                            x++;
                            If[ MatchQ[ $reformattedCell, _Cell ],
                                Pause[ 1 ];
                                NotebookWrite[ cellObject, $reformattedCell ];
                                Remove[ x, cellObject ];
                                ,
                                catchTop @ dynamicTextDisplay[ container, reformat ]
                            ],
                            Initialization   :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ],
                            Deinitialization :> Quiet @ TaskRemove @ task
                        ]
                    ],
                "Output",
                "ChatOutput",
                Sequence @@ Flatten[ { $closedChatCellOptions } ],
                Selectable   -> False,
                Editable     -> False,
                CellDingbat  -> Cell[ BoxData @ makeActiveOutputDingbat @ settings, Background -> None ],
                TaggingRules -> <| "ChatNotebookSettings" -> settings |>
            ]
        ]
    ];

activeAIAssistantCell[
    container_,
    settings: KeyValuePattern[ "CellObject" :> cellObject_ ],
    minimized_
] :=
    With[
        {
            label    = RawBoxes @ TemplateBox[ { }, "MinimizedChatActive" ],
            id       = $SessionID,
            reformat = dynamicAutoFormatQ @ settings,
            task     = Lookup[ settings, "Task" ],
            uuid     = container[ "UUID" ]
        },
        Cell[
            BoxData @ TagBox[
                ToBoxes @ Dynamic[
                    $dynamicTrigger;
                    (* `$dynamicTrigger` is used to precisely control when the dynamic updates, otherwise we can get an
                       FE crash if a NotebookWrite happens at the same time. *)
                    catchTop @ dynamicTextDisplay[ container, reformat ],
                    TrackedSymbols   :> { $dynamicTrigger },
                    Initialization   :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ],
                    Deinitialization :> Quiet @ TaskRemove @ task
                ],
                "DynamicTextDisplay",
                BoxID -> uuid
            ]
            ,
            "Output",
            "ChatOutput",
            ShowAutoSpellCheck -> False,
            CodeAssistOptions -> { "AutoDetectHyperlinks" -> False },
            LanguageCategory -> None,
            LineIndent -> 0,
            If[ TrueQ @ $autoAssistMode && MatchQ[ minimized, True|Automatic ],
                Sequence @@ Flatten[ {
                    $closedChatCellOptions,
                    Initialization :> catchTop @ attachMinimizedIcon[ EvaluationCell[ ], label ]
                } ],
                Initialization -> None
            ],
            CellDingbat       -> Cell[ BoxData @ makeActiveOutputDingbat @ settings, Background -> None ],
            CellEditDuplicate -> False,
            Editable          -> True,
            Selectable        -> True,
            ShowCursorTracker -> False,
            TaggingRules      -> <| "ChatNotebookSettings" -> settings |>
        ]
    ];

activeAIAssistantCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*smallSettings*)
smallSettings // beginDefinition;
smallSettings[ as_Association ] := smallSettings[ as, as[ "LLMEvaluator" ] ];
smallSettings[ as_, KeyValuePattern[ "LLMEvaluatorName" -> name_String ] ] := Append[ as, "LLMEvaluator" -> name ];
smallSettings[ as_, _ ] := as;
smallSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dynamicAutoFormatQ*)
dynamicAutoFormatQ // beginDefinition;
dynamicAutoFormatQ[ KeyValuePattern[ "DynamicAutoFormat" -> format: (True|False) ] ] := format;
dynamicAutoFormatQ[ KeyValuePattern[ "AutoFormat" -> format_ ] ] := TrueQ @ format;
dynamicAutoFormatQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dynamicTextDisplay*)
dynamicTextDisplay // beginDefinition;
dynamicTextDisplay // Attributes = { HoldFirst };

dynamicTextDisplay[ container_, reformat_ ] /; $highlightDynamicContent :=
    Block[ { $highlightDynamicContent = False },
        Framed[ dynamicTextDisplay[ container, reformat ], FrameStyle -> Purple ]
    ];

dynamicTextDisplay[ container_, True ] /; StringQ @ container[ "DynamicContent" ] :=
    Block[ { $dynamicText = True },
        RawBoxes @ Cell @ TextData @ reformatTextData @ container[ "DynamicContent" ]
    ];

dynamicTextDisplay[ container_, False ] /; StringQ @ container[ "DynamicContent" ] :=
    RawBoxes @ Cell @ TextData @ container[ "DynamicContent" ];

dynamicTextDisplay[ _Symbol, _ ] := ProgressIndicator[ Appearance -> "Percolate" ];

dynamicTextDisplay[ other_, _ ] := other;

dynamicTextDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkResponse*)
checkResponse // beginDefinition;

checkResponse[ settings: KeyValuePattern[ "ToolsEnabled" -> False ], container_, cell_, as_Association ] :=
    If[ TrueQ @ $autoAssistMode,
        writeResult[ settings, container, cell, as ],
        $nextTaskEvaluation = Hold @ writeResult[ settings, container, cell, as ]
    ];

checkResponse[ settings_, container_? toolFreeQ, cell_, as_Association ] :=
    If[ TrueQ @ $autoAssistMode,
        writeResult[ settings, container, cell, as ],
        $nextTaskEvaluation = Hold @ writeResult[ settings, container, cell, as ]
    ];

checkResponse[ settings_, container_Symbol, cell_, as_Association ] :=
    If[ TrueQ @ $autoAssistMode,
        toolEvaluation[ settings, Unevaluated @ container, cell, as ],
        $nextTaskEvaluation = Hold @ toolEvaluation[ settings, Unevaluated @ container, cell, as ]
    ];

checkResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolEvaluation*)
toolEvaluation // beginDefinition;

toolEvaluation[ settings_, container_Symbol, cell_, as_Association ] := Enclose[
    Module[ { string, callPos, toolCall, toolResponse, output, messages, newMessages, req, toolID },

        string = ConfirmBy[ container[ "FullContent" ], StringQ, "FullContent" ];

        { callPos, toolCall } = ConfirmMatch[
            toolRequestParser[ convertUTF8[ string, False ] ],
            { _, _LLMToolRequest|_Failure },
            "ToolRequestParser"
        ];

        toolResponse = ConfirmMatch[
            If[ FailureQ @ toolCall,
                toolCall,
                GenerateLLMToolResponse[ $toolConfiguration, toolCall ]
            ],
            _LLMToolResponse | _Failure,
            "GenerateLLMToolResponse"
        ];

        output = ConfirmBy[ toolResponseString @ toolResponse, StringQ, "ToolResponseString" ];

        messages = ConfirmMatch[ settings[ "Data", "Messages" ], { __Association }, "Messages" ];

        newMessages = Join[
            messages,
            {
                <| "role" -> "assistant", "content" -> StringTrim @ string <> "\nENDTOOLCALL" |>,
                <| "role" -> "system"   , "content" -> ToString @ output |>
            }
        ];

        req = ConfirmMatch[ makeHTTPRequest[ settings, newMessages ], _HTTPRequest, "HTTPRequest" ];

        toolID = Hash[ toolResponse, Automatic, "HexString" ];
        $toolEvaluationResults[ toolID ] = toolResponse;

        appendToolResult[ container, output, toolID ];

        $lastTask = submitAIAssistant[ container, req, cell, settings ]
    ],
    throwInternalFailure[ toolEvaluation[ settings, container, cell, as ], ## ] &
];

toolEvaluation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*writeResult*)
writeResult // beginDefinition;

writeResult[ settings_, container_, cell_, as_Association ] :=
    Module[ { log, chunks, folded, body, data },

        log    = Internal`BagPart[ $debugLog, All ];
        chunks = Cases[ log, KeyValuePattern[ "BodyChunk" -> s: Except[ "", _String ] ] :> s ];
        folded = Fold[ StringJoin, chunks ];

        { body, data } = FirstCase[
            Flatten @ StringCases[
                folded,
                (StartOfString|"\n") ~~ "data: " ~~ s: Except[ "\n" ].. ~~ "\n" :> s
            ],
            s_String :> With[ { json = Quiet @ Developer`ReadRawJSONString @ s },
                            { s, json } /; MatchQ[ json, KeyValuePattern[ "error" -> _ ] ]
                        ],
            { Last[ folded, Missing[ "NotAvailable" ] ], Missing[ "NotAvailable" ] }
        ];

        If[ MatchQ[ as[ "StatusCode" ], Except[ 200, _Integer ] ] || AssociationQ @ data,
            writeErrorCell[ cell, $badResponse = Association[ as, "Body" -> body, "BodyJSON" -> data ] ],
            writeReformattedCell[ settings, container, cell ]
        ]
    ];

writeResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendToolResult*)
appendToolResult // beginDefinition;
appendToolResult // Attributes = { HoldFirst };

appendToolResult[ container_Symbol, output_String, id_String ] :=
    Module[ { append },
        append = "ENDTOOLCALL\nRESULT\n"<>output<>"\nENDRESULT(" <> id <> ")\n\n";
        container[ "FullContent"    ] = container[ "FullContent"    ] <> append;
        container[ "DynamicContent" ] = container[ "DynamicContent" ] <> append;
    ];

appendToolResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolResponseString*)
toolResponseString // beginDefinition;
toolResponseString[ HoldPattern @ LLMToolResponse[ as_, ___ ] ] := toolResponseString @ as;
toolResponseString[ failed_Failure ] := ToString @ failed[ "Message" ];
toolResponseString[ as: KeyValuePattern[ "Output" -> output_ ] ] := toolResponseString[ as, output ];
toolResponseString[ as_, KeyValuePattern[ "String" -> output_ ] ] := toolResponseString[ as, output ];
toolResponseString[ as_, output_String ] := output;
toolResponseString[ as_, output_ ] := makeToolResponseString @ output;
toolResponseString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolFreeQ*)
toolFreeQ // beginDefinition;
toolFreeQ[ KeyValuePattern[ "FullContent" -> s_ ] ] := toolFreeQ @ s;
toolFreeQ[ _ProgressIndicator ] := True;
toolFreeQ[ s_String ] := ! MatchQ[ toolRequestParser @ s, { _, _LLMToolRequest|_Failure } ];
toolFreeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeErrorCell*)
writeErrorCell // beginDefinition;
writeErrorCell[ cell_, as_ ] := createFETask @ NotebookWrite[ cell, errorCell @ as ];
writeErrorCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorCell*)
errorCell // beginDefinition;

errorCell[ as_ ] :=
    Cell[
        TextData @ Flatten @ {
            StyleBox[ "\[WarningSign] ", FontColor -> Darker @ Red, FontSize -> 1.5 Inherited ],
            errorText @ as,
            "\n\n",
            Cell @ BoxData @ errorBoxes @ as
        },
        "Text",
        "ChatOutput",
        GeneratedCell     -> True,
        CellAutoOverwrite -> True
    ];

errorCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorText*)
errorText // ClearAll;

errorText[ KeyValuePattern[ "BodyJSON" -> KeyValuePattern[ "error" -> KeyValuePattern[ "message" -> s_String ] ] ] ] :=
    errorText @ s;

errorText[ str_String ] /; StringMatchQ[ str, "The model: `" ~~ __ ~~ "` does not exist" ] :=
    Module[ { model, link, help, message },

        model = StringReplace[ str, "The model: `" ~~ m__ ~~ "` does not exist" :> m ];
        link  = textLink[ "here", "https://platform.openai.com/docs/models/overview" ];
        help  = { " Click ", link, " for information about available models." };

        message = If[ MemberQ[ getModelList[ ], model ],
                      "The specified API key does not have access to the model \"" <> model <> "\".",
                      "The model \"" <> model <> "\" does not exist or the specified API key does not have access to it."
                  ];

        Flatten @ { message, help }
    ];

(*
    Note the subtle difference here where `model` is not followed by a colon.
    This is apparently the best way we can determine the difference between a model that exists but isn't revealed
    to the user and one that actually does not exist. Yes, this is ugly and will eventually be wrong.
*)
errorText[ str_String ] /; StringMatchQ[ str, "The model `" ~~ __ ~~ "` does not exist" ] :=
    Module[ { model, link, help, message },

        model = StringReplace[ str, "The model `" ~~ m__ ~~ "` does not exist" :> m ];
        link  = textLink[ "here", "https://platform.openai.com/docs/models/overview" ];
        help  = { " Click ", link, " for information about available models." };

        message = If[ MemberQ[ getModelList[ ], model ],
                      "The specified API key does not have access to the model \"" <> model <> "\".",
                      "The model \"" <> model <> "\" does not exist."
                  ];

        Flatten @ { message, help }
    ];

errorText[ str_String ] := str;

errorText[ ___ ] := "An unexpected error occurred.";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*textLink*)
textLink // beginDefinition;

textLink[ url_String ] := textLink[ url, url ];

textLink[ label_, url_String ] := ButtonBox[
    label,
    BaseStyle  -> "Hyperlink",
    ButtonData -> { URL @ url, None },
    ButtonNote -> url
];

textLink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorBoxes*)
errorBoxes // ClearAll;

(* TODO: define error messages for other documented responses *)
errorBoxes[ as: KeyValuePattern[ "StatusCode" -> 429 ] ] :=
    ToBoxes @ messageFailure[ "RateLimitReached", as ];

errorBoxes[ as: KeyValuePattern[ "StatusCode" -> code: Except[ 200 ] ] ] :=
    ToBoxes @ messageFailure[ "UnknownStatusCode", as ];

errorBoxes[ as_ ] :=
    ToBoxes @ messageFailure[ "UnknownResponse", as ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeHTTPRequest*)
makeHTTPRequest // beginDefinition;

makeHTTPRequest[ settings_Association? AssociationQ, nbo_NotebookObject, cell_CellObject ] :=
    makeHTTPRequest[ settings, selectChatCells[ settings, cell, nbo ] ];

makeHTTPRequest[ settings_Association? AssociationQ, cells: { __CellObject } ] :=
    makeHTTPRequest[ settings, notebookRead @ cells ];

makeHTTPRequest[ settings_Association? AssociationQ, { cells___Cell, cell_Cell } ] /; $cloudNotebooks :=
    makeHTTPRequest[ settings, makeChatMessages[ settings, { cells, parseInlineReferences @ cell } ] ];

makeHTTPRequest[ settings_Association? AssociationQ, cells: { __Cell } ] :=
    makeHTTPRequest[ settings, makeChatMessages[ settings, cells ] ];

makeHTTPRequest[ settings_Association? AssociationQ, messages0: { __Association } ] :=
    Enclose @ Module[
        { messages, key, stream, model, tokens, temperature, topP, freqPenalty, presPenalty, data, body },

        If[ settings[ "AutoFormat" ], needsBasePrompt[ "Formatting" ] ];
        needsBasePrompt @ settings;
        messages = messages0 /. s_String :> RuleCondition @ StringReplace[ s, "%%BASE_PROMPT%%" -> $basePrompt ];
        $lastSettings = settings;
        $lastMessages = messages;

        key         = ConfirmBy[ Lookup[ settings, "OpenAIKey" ], StringQ ];
        stream      = True;

        (* model parameters *)
        model       = Lookup[ settings, "Model"           , "gpt-3.5-turbo" ];
        tokens      = Lookup[ settings, "MaxTokens"       , Automatic       ];
        temperature = Lookup[ settings, "Temperature"     , 0.7             ];
        topP        = Lookup[ settings, "TopP"            , 1               ];
        freqPenalty = Lookup[ settings, "FrequencyPenalty", 0.1             ];
        presPenalty = Lookup[ settings, "PresencePenalty" , 0.1             ];

        data = DeleteCases[
            <|
                "messages"          -> messages,
                "temperature"       -> temperature,
                "max_tokens"        -> tokens,
                "top_p"             -> topP,
                "frequency_penalty" -> freqPenalty,
                "presence_penalty"  -> presPenalty,
                "model"             -> toModelName @ model,
                "stream"            -> stream,
                "stop"              -> "ENDTOOLCALL"
            |>,
            Automatic|_Missing
        ];

        Sow[ <| "Messages" -> messages |>, $chatDataTag ];

        body = ConfirmBy[ Developer`WriteRawJSONString[ data, "Compact" -> True ], StringQ ];

        $lastRequest = HTTPRequest[
            "https://api.openai.com/v1/chat/completions",
            <|
                "Headers" -> <|
                    "Content-Type"  -> "application/json",
                    "Authorization" -> "Bearer "<>key
                |>,
                "Body"   -> body,
                "Method" -> "POST"
            |>
        ]
    ];

makeHTTPRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeChatMessages*)
makeChatMessages // beginDefinition;

makeChatMessages[ settings_, { cells___, cell_ ? promptFunctionCellQ } ] := (
    Sow[ <| "RawOutput" -> True |>, $chatDataTag ];
    makePromptFunctionMessages[ settings, { cells, cell } ]
);

makeChatMessages[ settings_, cells_List ] :=
    Module[ { role, message, history, messages, merged },
        role     = makeCurrentRole @ settings;
        message  = makeCurrentCellMessage[ settings, cells ];
        history  = Reverse[ makeCellMessage /@ Reverse @ Most @ cells ];
        messages = DeleteMissing @ Flatten @ { role, history, message };
        merged   = If[ TrueQ @ Lookup[ settings, "MergeMessages" ], mergeMessageData @ messages, messages ];
        merged
    ];

makeChatMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*promptFunctionCellQ*)
promptFunctionCellQ[ Cell[ boxes_, ___, "ChatInput", ___ ] ] := inlineFunctionReferenceBoxesQ @ boxes;
promptFunctionCellQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*inlineFunctionReferenceBoxesQ*)
inlineFunctionReferenceBoxesQ[ (BoxData|TextData)[ boxes_ ] ] := inlineFunctionReferenceBoxesQ @ boxes;
inlineFunctionReferenceBoxesQ[ { box_, ___ } ] := inlineFunctionReferenceBoxesQ @ box;
inlineFunctionReferenceBoxesQ[ Cell[ __, TaggingRules -> tags_, ___ ] ] := inlineFunctionReferenceBoxesQ @ tags;
inlineFunctionReferenceBoxesQ[ KeyValuePattern[ "PromptFunctionName" -> _String ] ] := True;
inlineFunctionReferenceBoxesQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePromptFunctionMessages*)
makePromptFunctionMessages // beginDefinition;

makePromptFunctionMessages[ settings_, { cells___, cell0_ } ] := Enclose[
    Module[ { modifiers, cell, name, arguments, filled, prompt, string },
        (* Ensure Wolfram/LLMFunctions is installed and loaded before calling System`LLMPrompt[..] *)
        initTools[ ];

        { modifiers, cell } = ConfirmMatch[ extractModifiers @ cell0, { _, _ }, "Modifiers" ];
        name      = ConfirmBy[ extractPromptFunctionName @ cell, StringQ, "PromptFunctionName" ];
        arguments = ConfirmMatch[ extractPromptArguments @ cell, { ___String }, "PromptArguments" ];
        filled    = ConfirmMatch[ replaceArgumentTokens[ name, arguments, { cells, cell } ], { ___String }, "Tokens" ];
        prompt    = ConfirmMatch[ Quiet[ getLLMPrompt @ name, OptionValue::nodef ], _TemplateObject, "LLMPrompt" ];
        string    = ConfirmBy[ Quiet[ TemplateApply[ prompt, filled ], OptionValue::nodef ], StringQ, "TemplateApply" ];

        (* FIXME: handle named slots *)
        Flatten @ {
            expandModifierMessages[ settings, modifiers, { cells }, cell ],
            <| "role" -> "user", "content" -> string |>
        }
    ],
    throwInternalFailure[ makePromptFunctionMessages[ settings, { cells, cell0 } ], ## ] &
];

makePromptFunctionMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*getLLMPrompt*)
getLLMPrompt // beginDefinition;

getLLMPrompt[ name_String ] :=
    getLLMPrompt[
        name,
        Quiet[
            Check[
                Block[ { PrintTemporary }, getLLMPrompt0 @ name ],
                (* TODO: a dialog might be better since a message could be missed in the messages window *)
                throwFailure[ "ResourceNotFound", name ],
                ResourceObject::notfname
            ],
            { ResourceObject::notfname, OptionValue::nodef }
        ]
    ];

getLLMPrompt[ name_String, prompt: _TemplateObject|_String ] := prompt;

getLLMPrompt // endDefinition;


getLLMPrompt0 // beginDefinition;
getLLMPrompt0[ name_ ] := With[ { t = Quiet @ System`LLMPrompt[ "Prompt: "<>name ] }, t /; MatchQ[ t, _TemplateObject ] ];
getLLMPrompt0[ name_ ] := System`LLMPrompt @ name;
getLLMPrompt0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*extractPromptFunctionName*)
extractPromptFunctionName // beginDefinition;
extractPromptFunctionName[ Cell[ boxes_, ___, "ChatInput", ___ ] ] := extractPromptFunctionName @ boxes;
extractPromptFunctionName[ (BoxData|TextData)[ boxes_ ] ] := extractPromptFunctionName @ boxes;
extractPromptFunctionName[ { box_, ___ } ] := extractPromptFunctionName @ box;
extractPromptFunctionName[ Cell[ __, TaggingRules -> KeyValuePattern[ "PromptFunctionName" -> name_ ], ___ ] ] := name;
extractPromptFunctionName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*extractPromptArguments*)
extractPromptArguments // beginDefinition;
extractPromptArguments[ Cell[ boxes_, ___, "ChatInput", ___ ] ] := extractPromptArguments @ boxes;
extractPromptArguments[ (BoxData|TextData)[ boxes_ ] ] := extractPromptArguments @ boxes;
extractPromptArguments[ { box_, ___ } ] := extractPromptArguments @ box;
extractPromptArguments[ Cell[ __, TaggingRules -> KeyValuePattern[ "PromptArguments" -> args_ ], ___ ] ] := args;
extractPromptArguments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*replaceArgumentTokens*)
$$promptArgumentToken = Alternatives[ ">", "^", "^^" ];

replaceArgumentTokens // beginDefinition;

replaceArgumentTokens[ name_String, args_List, { cells___, cell_ } ] :=
    Module[ { tokens, rules, arguments },
        tokens = Cases[ Union @ args, $$promptArgumentToken ];
        rules = AssociationMap[ argumentTokenToString[ #, name, { cells, cell } ] &, tokens ];
        arguments = Replace[ args, rules, { 1 } ];
        arguments
    ];

replaceArgumentTokens // endDefinition;

argumentTokenToString[
    ">",
    name_,
    {
        ___,
        Cell[
            TextData @ { ___, Cell[ __, TaggingRules -> KeyValuePattern[ "PromptFunctionName" -> name_ ], ___ ], a___ },
            "ChatInput",
            b___
        ]
    }
] := CellToString @ Cell[ TextData @ { a }, "ChatInput", b ];

argumentTokenToString[
    ">",
    name_,
    {
        ___,
        Cell[ TextData @ Cell[ __, TaggingRules -> KeyValuePattern[ "PromptFunctionName" -> name_ ], ___ ], "ChatInput", ___ ]
    }
] := "";

argumentTokenToString[ "^", name_, { ___, cell_, _ } ] := CellToString @ cell;

argumentTokenToString[ "^^", name_, { history___, _ } ] := StringRiffle[ CellToString /@ { history }, "\n\n" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toModelName*)
toModelName // beginDefinition;

toModelName[ name_String? StringQ ] := toModelName[ name ] =
    toModelName0 @ StringReplace[
        ToLowerCase @ StringReplace[
            name,
            a_? LowerCaseQ ~~ b_? UpperCaseQ :> a<>"-"<>b
        ],
        "gpt"~~n:$$modelVersion~~EndOfString :> "gpt-"<>n
    ];

toModelName // endDefinition;

$$modelVersion = DigitCharacter.. ~~ (("." ~~ DigitCharacter...) | "");

(* cSpell:ignore chatgpt *)
toModelName0 // beginDefinition;
toModelName0[ "chat-gpt"|"chatgpt"|"gpt-3"|"gpt-3.5" ] := "gpt-3.5-turbo";
toModelName0[ name_String ] := StringReplace[ name, "gpt"~~n:DigitCharacter :> "gpt-"<>n ];
toModelName0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCurrentRole*)
makeCurrentRole // beginDefinition;

makeCurrentRole[ as_Association? AssociationQ ] :=
    makeCurrentRole[ as, as[ "BasePrompt" ], as[ "LLMEvaluator" ] ];

makeCurrentRole[ as_, None, _ ] :=
    Missing[ ];

makeCurrentRole[ as_, role_String, _ ] :=
    <| "role" -> "system", "content" -> role |>;

makeCurrentRole[ as_, Automatic|Inherited|_Missing, name_String ] :=
    <| "role" -> "system", "content" -> namedRolePrompt @ name |>;

makeCurrentRole[ as_, _, KeyValuePattern[ "BasePrompt" -> None ] ] := (
    needsBasePrompt @ None;
    Missing[ ]
);

makeCurrentRole[ as_, base_, eval_Association ] := (
    needsBasePrompt @ base;
    needsBasePrompt @ eval;
    <| "role" -> "system", "content" -> buildSystemPrompt @ Association[ as, eval ] |>
);

makeCurrentRole[ as_, base_, _ ] := (
    needsBasePrompt @ base;
    <| "role" -> "system", "content" -> buildSystemPrompt @ as |>
);

makeCurrentRole // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buildSystemPrompt*)
buildSystemPrompt // beginDefinition;

buildSystemPrompt[ as_Association ] := StringReplace[
    StringTrim @ TemplateApply[
        $promptTemplate,
        Association[
            $promptComponents[ "Generic" ],
            Select[
                <|
                    "Pre"   -> getPrePrompt @ as,
                    "Post"  -> getPostPrompt @ as,
                    "Tools" -> getToolPrompt @ as,
                    "Base"  -> "%%BASE_PROMPT%%"
                |>,
                StringQ
            ]
        ]
    ],
    "\n\n\n\n" -> "\n\n"
];

buildSystemPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolPrompt*)
getToolPrompt // beginDefinition;

getToolPrompt[ KeyValuePattern[ "ToolsEnabled" -> False ] ] := "";

(* TODO: include tools defined by the persona! *)
getToolPrompt[ settings_ ] := Enclose[
    Module[ { config, string },
        config = ConfirmMatch[ makeToolConfiguration @ settings, _System`LLMConfiguration ];
        ConfirmBy[ TemplateApply[ config[ "ToolPrompt" ], config[ "Data" ] ], StringQ ]
    ],
    throwInternalFailure[ getToolPrompt @ settings, ## ] &
];

(* getToolPrompt[ _ ] := Missing[ ]; *)

getToolPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPrePrompt*)
getPrePrompt // beginDefinition;

getPrePrompt[ as_Association ] := toPromptString @ FirstCase[
    Unevaluated @ {
        as[ "LLMEvaluator", "ChatContextPreprompt" ],
        as[ "LLMEvaluator", "Pre" ],
        as[ "LLMEvaluator", "PromptTemplate" ],
        as[ "ChatContextPreprompt" ],
        as[ "Pre" ],
        as[ "PromptTemplate" ]
    },
    expr_ :> With[ { e = expr }, e /; MatchQ[ e, _String | _TemplateObject ] ]
];

getPrePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPostPrompt*)
getPostPrompt // beginDefinition;

getPostPrompt[ as_Association ] := toPromptString @ FirstCase[
    Unevaluated @ {
        as[ "LLMEvaluator", "ChatContextPostPrompt" ],
        as[ "LLMEvaluator", "Post" ],
        as[ "ChatContextPostPrompt" ],
        as[ "Post" ]
    },
    expr_ :> With[ { e = expr }, e /; MatchQ[ e, _String | _TemplateObject ] ]
];

getPostPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toPromptString*)
toPromptString // beginDefinition;
toPromptString[ string_String ] := string;
toPromptString[ template_TemplateObject ] := With[ { string = TemplateApply @ template }, string /; StringQ @ string ];
toPromptString[ _Missing | Automatic | Inherited | None ] := Missing[ ];
toPromptString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeMessageData*)
mergeMessageData // beginDefinition;
mergeMessageData[ messages_ ] := mergeMessages /@ SplitBy[ messages, Lookup[ "role" ] ];
mergeMessageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeMessages*)
mergeMessages // beginDefinition;

mergeMessages[ { } ] := Nothing;
mergeMessages[ { message_ } ] := message;
mergeMessages[ messages: { first_Association, __Association } ] :=
    Module[ { role, strings },
        role    = Lookup[ first   , "role"    ];
        strings = Lookup[ messages, "content" ];
        <|
            "role"    -> role,
            "content" -> StringDelete[ StringRiffle[ strings, "\n\n" ], "```\n\n```" ]
        |>
    ];

mergeMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectChatCells*)
selectChatCells // beginDefinition;

selectChatCells[ as_Association? AssociationQ, cell_CellObject, nbo_NotebookObject ] :=
    Block[
        {
            $maxChatCells = Replace[
                Lookup[ as, "ChatHistoryLength" ],
                Except[ _Integer? Positive ] :> $maxChatCells
            ]
        },
        $selectedChatCells = selectChatCells0[ cell, clearMinimizedChats @ nbo ]
    ];

selectChatCells // endDefinition;


selectChatCells0 // beginDefinition;

(* If `$finalCell` is defined, it means we are evaluating through the cell tray widget button. This can be invoked from
   a cell that is in the middle of other generated outputs, e.g. a message cell that lies between an input and output.
   In these cases, we want to make sure we don't delete chat output cells that come after the generated cells,
   since the user is just looking for chat feedback for the selected cell. *)
selectChatCells0[ cell_, cells: { __CellObject } ] := selectChatCells0[ cell, cells, $finalCell ];

(* If `$finalCell` is defined, we can use it to filter out any cells that follow it via this pattern: *)
selectChatCells0[ cell_, { before___, final_, ___ }, final_ ] := selectChatCells0[ cell, { before, final }, None ];

(* Otherwise, proceed with cell selection: *)
selectChatCells0[ cell_, cells: { __CellObject }, final_ ] := Enclose[
    Module[ { cellData, cellPosition, before, groupPos, selectedRange, filtered, rest, selectedCells },

        cellData = ConfirmMatch[
            cellInformation @ cells,
            { KeyValuePattern[ "CellObject" -> _CellObject ].. },
            "CellInformation"
        ];

        (* Position of the current evaluation cell *)
        cellPosition = ConfirmBy[
            First @ FirstPosition[ cellData, KeyValuePattern[ "CellObject" -> cell ] ],
            IntegerQ,
            "EvaluationCellPosition"
        ];

        (* Select all cells up to and including the evaluation cell *)
        before = Reverse @ Take[ cellData, cellPosition ];
        groupPos = ConfirmBy[
            First @ FirstPosition[ before, KeyValuePattern[ "Style" -> $$chatDelimiterStyle ], { Length @ before } ],
            IntegerQ,
            "ChatDelimiterPosition"
        ];
        selectedRange = Reverse @ Take[ before, groupPos ];

        (* Filter out ignored cells *)
        filtered = DeleteCases[ selectedRange, KeyValuePattern[ "Style" -> $$chatIgnoredStyle ] ];

        (* Delete output cells that come after the evaluation cell *)
        rest = deleteExistingChatOutputs @ Drop[ cellData, cellPosition ];

        (* Get the selected cell objects from the filtered cell info *)
        selectedCells = ConfirmMatch[
            Lookup[ Flatten @ { filtered, rest }, "CellObject" ],
            { __CellObject },
            "FilteredCellObjects"
        ];

        (* Limit the number of cells specified by ChatHistoryLength, starting from current cell and looking backwards *)
        ConfirmMatch[
            Reverse @ Take[ Reverse @ selectedCells, UpTo @ $maxChatCells ],
            { __CellObject },
            "ChatHistoryLengthCellObjects"
        ]
    ],
    throwInternalFailure[ selectChatCells0[ cell, cells, final ], ## ] &
];

selectChatCells0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deleteExistingChatOutputs*)
deleteExistingChatOutputs // beginDefinition;

(* When chat is triggered by an evaluation instead of a chat input, there can be generated cells between the
   evaluation cell and the previous chat output. For example:

       CellObject[ <Current evaluation cell> ]
       CellObject[ <Message/Print/Echo cells, etc.> ]
       CellObject[ <Output from the current evaluation cell> ]
       CellObject[ <Previous chat output> ] <--- We want to delete this cell, since it's from a previous evaluation

   At this point, the front end has already cleared previous output cells (messages, output, etc.), but the previous
   chat output cell is still there. We need to delete it so that the new chat output cell can be inserted in its place.
   `deleteExistingChatOutputs` gathers up all the generated cells that come after the evaluation cell and if it finds
   a chat output cell, it deletes it.
*)
deleteExistingChatOutputs[ cellData: { KeyValuePattern[ "CellObject" -> _CellObject ] ... } ] /; $autoAssistMode :=
    Module[ { delete, chatOutputs, cells },
        delete      = TakeWhile[ cellData, MatchQ @ KeyValuePattern[ "CellAutoOverwrite" -> True ] ];
        chatOutputs = Cases[ delete, KeyValuePattern[ "Style" -> $$chatOutputStyle ] ];
        cells       = Cases[ chatOutputs, KeyValuePattern[ "CellObject" -> cell_ ] :> cell ];
        NotebookDelete @ cells;
        DeleteCases[ delete, KeyValuePattern[ "CellObject" -> Alternatives @@ cells ] ]
    ];

deleteExistingChatOutputs[ cellData_ ] :=
    TakeWhile[ cellData, MatchQ @ KeyValuePattern[ "CellAutoOverwrite" -> True ] ];

deleteExistingChatOutputs // endDefinition;

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
(*dropDelimitedCells*)
dropDelimitedCells // beginDefinition;

dropDelimitedCells[ cells_List ] :=
    Drop[ cells, Max[ Position[ cellStyles @ cells, { ___, "ChatDelimiter"|"PageBreak", ___ }, { 1 } ], 0 ] ];

dropDelimitedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCurrentCellMessage*)
makeCurrentCellMessage // beginDefinition;

makeCurrentCellMessage[ settings_, { cells___, cell0_ } ] := Enclose[
    Module[ { modifiers, cell, role, content },
        { modifiers, cell } = ConfirmMatch[ extractModifiers @ cell0, { _, _ }, "Modifiers" ];
        role = ConfirmBy[ cellRole @ cell, StringQ, "CellRole" ];
        content = ConfirmBy[ Block[ { $CurrentCell = True }, CellToString @ cell ], StringQ, "Content" ];
        Flatten @ {
            expandModifierMessages[ settings, modifiers, { cells }, cell ],
            <| "role" -> role, "content" -> content |>
        }
    ],
    throwInternalFailure[ makeCurrentCellMessage[ settings, { cells, cell0 } ], ## ] &
];

makeCurrentCellMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*expandModifierMessages*)
expandModifierMessages // beginDefinition;

expandModifierMessages[ settings_, modifiers_List, history_, cell_ ] :=
    expandModifierMessage[ settings, #, history, cell ] & /@ modifiers;

expandModifierMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*expandModifierMessage*)
expandModifierMessage // beginDefinition;

expandModifierMessage[ settings_, modifier_, { cells___ }, cell_ ] := Enclose[
    Module[ { name, arguments, filled, prompt, string, role },
        name      = ConfirmBy[ modifier[ "PromptModifierName" ], StringQ, "ModifierName" ];
        arguments = ConfirmMatch[ modifier[ "PromptArguments" ], { ___String }, "Arguments" ];
        filled    = ConfirmMatch[ replaceArgumentTokens[ name, arguments, { cells, cell } ], { ___String }, "Tokens" ];
        prompt    = ConfirmMatch[ Quiet[ getLLMPrompt @ name, OptionValue::nodef ], _TemplateObject, "LLMPrompt" ];
        string    = ConfirmBy[ Quiet[ TemplateApply[ prompt, filled ], OptionValue::nodef ], StringQ, "TemplateApply" ];
        role      = ConfirmBy[ modifierMessageRole @ settings, StringQ, "Role" ];
        <| "role" -> role, "content" -> string |>
    ],
    throwInternalFailure[ expandModifierMessage[ modifier, { cells }, cell ], ## ] &
];

expandModifierMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*modifierMessageRole*)
modifierMessageRole[ KeyValuePattern[ "Model" -> model_String ] ] :=
    If[ TrueQ @ StringStartsQ[ toModelName @ model, "gpt-3.5", IgnoreCase -> True ],
        "user",
        "system"
    ];

modifierMessageRole[ ___ ] := "system";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*extractModifiers*)

$$inlineModifierCell = Alternatives[
    Cell[ _, "InlineModifierReference", ___ ],
    Cell[ BoxData @ Cell[ _, "InlineModifierReference", ___ ], ___ ]
];

extractModifiers // beginDefinition;

extractModifiers[ cell: Cell[ _String, ___ ] ] := { { }, cell };
extractModifiers[ cell: Cell[ TextData[ _String ], ___ ] ] := { { }, cell };

extractModifiers[ Cell[ TextData[ text: { ___, $$inlineModifierCell, ___ } ], a___ ] ] := {
    Cases[ text, cell: $$inlineModifierCell :> extractModifier @ cell ],
    Cell[ TextData @ DeleteCases[ text, $$inlineModifierCell ], a ]
};

extractModifiers[ Cell[ TextData[ modifier: $$inlineModifierCell ], a___ ] ] := {
    { extractModifier @ modifier },
    Cell[ "", a ]
};

extractModifiers[ cell_Cell ] := { { }, cell };

extractModifiers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*extractModifier*)
extractModifier // beginDefinition;
extractModifier[ Cell[ BoxData[ cell: Cell[ _, "InlineModifierReference", ___ ] ], ___ ] ] := extractModifier @ cell;
extractModifier[ Cell[ __, TaggingRules -> tags_, ___ ] ] := extractModifier @ tags;
extractModifier[ as: KeyValuePattern @ { "PromptModifierName" -> _String, "PromptArguments" -> _List } ] := as;
extractModifier // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCellMessage*)
makeCellMessage // beginDefinition;
makeCellMessage[ cell_Cell ] := <| "role" -> cellRole @ cell, "content" -> CellToString @ cell |>;
makeCellMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellRole*)
cellRole // beginDefinition;

cellRole[ Cell[
    __,
    TaggingRules -> KeyValuePattern[ "ChatNotebookSettings" -> KeyValuePattern[ "Role" -> role_String ] ],
    ___
] ] := ToLowerCase @ role;

cellRole[ Cell[ _, styles__String, OptionsPattern[ ] ] ] :=
    FirstCase[ { styles }, style_ :> With[ { role = $styleRoles @ style }, role /; StringQ @ role ], "user" ];

cellRole // endDefinition;


$styleRoles = <|
    "ChatInput"              -> "user",
    "ChatOutput"             -> "assistant",
    "AssistantOutput"        -> "assistant",
    "AssistantOutputWarning" -> "assistant",
    "AssistantOutputError"   -> "assistant",
    "ChatSystemInput"        -> "system"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeChunk*)
writeChunk // beginDefinition;

writeChunk[ container_, cell_, KeyValuePattern[ "BodyChunk" -> chunk_String ] ] :=
    writeChunk[ container, cell, chunk ];

writeChunk[ container_, cell_, chunk_String ] /; StringMatchQ[ chunk, "data: " ~~ __ ~~ "\n\n" ~~ __ ~~ ("\n\n"|"") ] :=
    writeChunk[ container, cell, # ] & /@ StringSplit[ chunk, "\n\n" ];

writeChunk[ container_, cell_, chunk_String ] /; StringMatchQ[ chunk, "data: " ~~ __ ~~ ("\n\n"|"") ] :=
    Module[ { json },
        json = StringDelete[ chunk, { StartOfString~~"data: ", ("\n\n"|"") ~~ EndOfString } ];
        writeChunk[ container, cell, chunk, Quiet @ Developer`ReadRawJSONString @ json ]
    ];

writeChunk[ container_, cell_, "" | "data: [DONE]" | "data: [DONE]\n\n" ] := Null;

writeChunk[ container_, cell_, chunk_String ] :=
    With[ { json = Quiet @ Developer`ReadRawJSONString @ chunk },
        writeChunk[ container, cell, chunk, json ] /; AssociationQ @ json
    ];

writeChunk[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "choices" -> { KeyValuePattern[ "delta" -> KeyValuePattern[ "content" -> text_String ] ], ___ } ]
] := writeChunk[ container, cell, chunk, text ];

writeChunk[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "choices" -> { KeyValuePattern @ { "delta" -> <| |>, "finish_reason" -> "stop" }, ___ } ]
] := Null;

writeChunk[ Dynamic[ container_ ], cell_, chunk_String, text_String ] := (

    appendStringContent[ container[ "FullContent"    ], text ];
    appendStringContent[ container[ "DynamicContent" ], text ];

    If[ TrueQ @ $dynamicSplit,
        (* Convert as much of the dynamic content as possible to static boxes and write to cell: *)
        splitDynamicContent[ container, cell ]
    ];

    If[ AbsoluteTime[ ] - $lastDynamicUpdate > 0.05,
        (* Trigger updating of dynamic content in current chat output cell *)
        $dynamicTrigger++;
        $lastDynamicUpdate = AbsoluteTime[ ]
    ];

    (* Handle auto-opening of assistant cells: *)
    Which[
        errorTaggedQ @ container, processErrorCell[ container, cell ],
        warningTaggedQ @ container, processWarningCell[ container, cell ],
        infoTaggedQ @ container, processInfoCell[ container, cell ],
        untaggedQ @ container, openChatCell @ cell,
        True, Null
    ]
);

writeChunk[ Dynamic[ container_ ], cell_, chunk_String, other_ ] := Null;

writeChunk // endDefinition;


$dynamicTrigger    = 0;
$lastDynamicUpdate = 0;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*splitDynamicContent*)
splitDynamicContent // beginDefinition;
splitDynamicContent // Attributes = { HoldFirst };

(* NotebookLocationSpecifier isn't available before 13.3 and splitting isn't yet supported in cloud: *)
splitDynamicContent[ container_, cell_ ] /; ! $dynamicSplit || $VersionNumber < 13.3 || $cloudNotebooks := Null;

splitDynamicContent[ container_, cell_ ] :=
    splitDynamicContent[ container, container[ "DynamicContent" ], cell, container[ "UUID" ] ];

splitDynamicContent[ container_, text_String, cell_, uuid_String ] :=
    splitDynamicContent[ container, StringSplit[ text, $dynamicSplitRules ], cell, uuid ];

splitDynamicContent[ container_, { static__String, dynamic_String }, cell_, uuid_String ] := Enclose[
    Catch @ Module[ { boxObject, reformatted, write, nbo },

        boxObject = ConfirmMatch[
            getBoxObjectFromBoxID[ cell, uuid ],
            _BoxObject | Missing[ "CellRemoved", ___ ],
            "BoxObject"
        ];

        If[ MatchQ[ boxObject, Missing[ "CellRemoved", ___ ] ],
            throwTop[ Quiet[ TaskRemove @ $lastTask, TaskRemove::timnf ]; Null ]
        ];

        reformatted = ConfirmMatch[
            Block[ { $dynamicText = False }, reformatTextData @ StringJoin @ static ],
            $$textDataList,
            "ReformatTextData"
        ];

        write = Cell[ TextData @ reformatted, Background -> None ];
        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];

        container[ "DynamicContent" ] = dynamic;

        With[ { boxObject = boxObject, write = write },
            splitDynamicTaskFunction @ NotebookWrite[
                System`NotebookLocationSpecifier[ boxObject, "Before" ],
                write,
                None,
                AutoScroll -> False
            ];
            splitDynamicTaskFunction @ NotebookWrite[
                System`NotebookLocationSpecifier[ boxObject, "Before" ],
                "\n" ,
                None,
                AutoScroll -> False
            ];
        ];

        $dynamicTrigger++;
        $lastDynamicUpdate = AbsoluteTime[ ];

    ],
    throwInternalFailure[ splitDynamicContent[ container, { static, dynamic }, cell, uuid ], ## ] &
];

(* There's nothing we can write as static content yet: *)
splitDynamicContent[ container_, { _ } | { }, cell_, uuid_ ] := Null;

splitDynamicContent // endDefinition;



splitDynamicTaskFunction = createFETask;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendStringContent*)
appendStringContent // beginDefinition;
appendStringContent // Attributes = { HoldFirst };

appendStringContent[ container_, text_String ] :=
    If[ StringQ @ container,
        container = StringDelete[ container <> convertUTF8 @ text, StartOfString~~Whitespace ],
        container = convertUTF8 @ text
    ];

appendStringContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toAPIKey*)
toAPIKey[ key_String ] := key;

toAPIKey[ Automatic ] := toAPIKey[ Automatic, None ];

toAPIKey[ Automatic, id_ ] := checkAPIKey @ FirstCase[
    Unevaluated @ {
        systemCredential[ "OPENAI_API_KEY" ],
        Environment[ "OPENAI_API_KEY" ],
        apiKeyDialog[ ]
    },
    e_ :> With[ { key = e }, key /; StringQ @ key ],
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

cloudSystemCredential[ name_, credential_EncryptedObject ] :=
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
checkAPIKey[ key_String ] /; MatchQ[ getModelList @ key, { __String } ] := checkAPIKey[ key ] = key;
checkAPIKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*apiKeyDialog*)
apiKeyDialog // beginDefinition;

apiKeyDialog[ ] :=
    Enclose @ Module[ { result, key },
        result = ConfirmBy[ showAPIKeyDialog[ ], AssociationQ ];
        key    = ConfirmBy[ result[ "APIKey" ], StringQ ];

        If[ result[ "Save" ], setSystemCredential[ "OPENAI_API_KEY", key ] ];

        key
    ];

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
                "Label"   -> "API Key",
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
            "Save" -> <| "Interpreter" -> "Boolean" |>
        },
        AppearanceRules -> {
            "Title"       -> "Please enter your OpenAI API key",
            "Description" -> $apiKeyDialogDescription
        }
    ],
    WindowSize     -> { 400, All },
    WindowElements -> { "StatusArea" }
];

showAPIKeyDialog // endDefinition;


$apiKeyDialogDescription := $apiKeyDialogDescription = Get @ FileNameJoin @ {
    PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "AIAssistant" ],
    "APIKeyDialogDescription.wl"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)

$promptDirectory := FileNameJoin @ {
    PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "AIAssistant" ],
    "Prompts"
};

$promptStrings := $promptStrings = Association @ Map[
    Function[
        StringDelete[
            StringTrim[ StringReplace[ StringDelete[ #, StartOfString~~$promptDirectory ], "\\" -> "/" ], "/" ],
            ".md"~~EndOfString
        ] -> StringReplace[ ByteArrayToString @ ReadByteArray @ #, "\r\n" -> "\n" ]
    ],
    FileNames[ "*.md", $promptDirectory, Infinity ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$promptTemplate*)
$promptTemplate = StringTemplate[ $promptStrings[ "Default" ], Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$promptComponents*)
(* TODO(cleanup): This is now only used for the "Generic" persona. *)
$promptComponents = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Generic*)
$promptComponents[ "Generic" ] = <| |>;
$promptComponents[ "Generic", "Pre"  ] = $promptStrings[ "Generic/Pre" ];
$promptComponents[ "Generic", "Post" ] = "";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$defaultRolePrompt*)
$defaultRolePrompt = TemplateApply[ $promptTemplate, $promptComponents[ "Generic" ] ];
$defaultRole = <| "role" -> "system", "content" -> $defaultRolePrompt |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*namedRolePrompt*)
namedRolePrompt // ClearAll;

namedRolePrompt[ name_String ] := Enclose[
    Module[ { data, pre, post },
        data = ConfirmBy[GetCachedPersonaData[name], AssociationQ];

        pre  = Lookup[ data, "Pre", TemplateApply @ Lookup[ data, "PromptTemplate" ] ];
        post = Lookup[ data, "Post" ];
        ConfirmBy[
            TemplateApply[
                $promptTemplate,
                DeleteMissing @ <| "Pre" -> pre, "Post" -> post |>
            ],
            StringQ
        ]
    ],
    (
        ChatbookWarning[
            "Error using named role prompt ``; falling back to default prompt.",
            InputForm[name]
        ];
        $defaultRolePrompt
    ) &
];

namedRolePrompt[ ___ ] := $defaultRolePrompt;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Models*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAIAssistantModels*)
getAIAssistantModels // beginDefinition;
getAIAssistantModels[ opts: OptionsPattern[ CreateChatNotebook ] ] := getModelList @ toAPIKey @ Automatic;
getAIAssistantModels // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getModelList*)
getModelList // beginDefinition;

(* NOTE: This function is also called in UI.wl *)
getModelList[ ] := getModelList @ toAPIKey @ Automatic;

getModelList[ key_String ] := getModelList[ key, Hash @ key ];

getModelList[ key_String, hash_Integer ] :=
    Module[ { resp },
        resp = URLExecute[
            HTTPRequest[
                "https://api.openai.com/v1/models",
                <| "Headers" -> <| "Content-Type" -> "application/json", "Authorization" -> "Bearer "<>key |> |>
            ],
            "RawJSON",
            Interactive -> False
        ];
        If[ FailureQ @ resp && StringStartsQ[ key, "org-", IgnoreCase -> True ],
            (*
                When viewing the account settings page on OpenAI's site, it describes the organization ID as something
                that's used in API requests, which may be confusing to someone who is looking for their API key and
                they come across this page first. This message is meant to catch these cases and steer the user in the
                right direction.

                TODO: When more services are supported, this should only apply when using an OpenAI endpoint.
            *)
            throwFailure[
                ChatbookAction::APIKeyOrganizationID,
                Hyperlink[ "https://platform.openai.com/account/api-keys" ],
                key
            ],
            getModelList[ hash, resp ]
        ]
    ];

(* Could not connect to the server (maybe server is down or no internet connection available) *)
getModelList[ hash_Integer, failure: Failure[ "ConnectionFailure", _ ] ] :=
    throwFailure[ ChatbookAction::ConnectionFailure, failure ];

(* Some other failure: *)
getModelList[ hash_Integer, failure_? FailureQ ] :=
    throwFailure[ ChatbookAction::ConnectionFailure2, failure ];

getModelList[ hash_, KeyValuePattern[ "data" -> data_ ] ] :=
    getModelList[ hash, data ];

getModelList[ hash_, models: { KeyValuePattern[ "id" -> _String ].. } ] :=
    getModelList[ _String, hash ] = Cases[ models, KeyValuePattern[ "id" -> id_String ] :> id ];

getModelList[ hash_, KeyValuePattern[ "error" -> as: KeyValuePattern[ "message" -> message_String ] ] ] :=
    Module[ { newKey, newHash },
        If[ StringStartsQ[ message, "Incorrect API key" ] && Hash @ systemCredential[ "OPENAI_API_KEY" ] === hash,
            newKey = apiKeyDialog[ ];
            newHash = Hash @ newKey;
            If[ StringQ @ newKey && newHash =!= hash,
                getModelList[ newKey, newHash ],
                throwFailure[ ChatbookAction::BadResponseMessage, message, as ]
            ],
            throwFailure[ ChatbookAction::BadResponseMessage, message, as ]
        ]
    ];

getModelList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Structured Tags*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Severity Tag String Patterns*)
$$whitespace  = Longest[ WhitespaceCharacter... ];
$$severityTag = "ERROR"|"WARNING"|"INFO";
$$tagPrefix   = StartOfString~~$$whitespace~~"["~~$$whitespace~~$$severityTag~~$$whitespace~~"]"~~$$whitespace;

$maxTagLength = Max[ StringLength /@ (List @@ $$severityTag) ] + 2;


errorTaggedQ // ClearAll;
errorTaggedQ[ s_  ] := taggedQ[ s, "ERROR" ];
errorTaggedQ[ ___ ] := False;


warningTaggedQ // ClearAll;
warningTaggedQ[ s_  ] := taggedQ[ s, "WARNING" ];
warningTaggedQ[ ___ ] := False;


infoTaggedQ // ClearAll;
infoTaggedQ[ s_  ] := taggedQ[ s, "INFO" ];
infoTaggedQ[ ___ ] := False;


untaggedQ // ClearAll;
untaggedQ[ as_Association? AssociationQ ] := untaggedQ @ as[ "FullContent" ];
untaggedQ[ s0_String? StringQ ] /; $alwaysOpen :=
    With[ { s = StringDelete[ $lastUntagged = s0, Whitespace ] },
        Or[ StringStartsQ[ s, Except[ "[" ] ],
            StringLength @ s >= $maxTagLength && ! StringStartsQ[ s, $$tagPrefix, IgnoreCase -> True ]
        ]
    ];

untaggedQ[ ___ ] := False;


taggedQ // ClearAll;
taggedQ[ s_ ] := taggedQ[ s, $$severityTag ];
taggedQ[ as_Association? AssociationQ, tag_ ] := taggedQ[ as[ "FullContent" ], tag ];
taggedQ[ s_String? StringQ, tag_ ] := StringStartsQ[ StringDelete[ s, Whitespace ], "["~~tag~~"]", IgnoreCase -> True ];
taggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeSeverityTag*)
removeSeverityTag // beginDefinition;
removeSeverityTag // Attributes = { HoldFirst };

removeSeverityTag[ s_Symbol? AssociationQ, cell_CellObject ] /; StringQ @ s[ "FullContent" ] :=
    Module[ { tag },
        tag = StringReplace[ s[ "FullContent" ], t:$$tagPrefix~~___~~EndOfString :> t ];
        s = untagString @ s;
        CurrentValue[ cell, { TaggingRules, "MessageTag" } ] = ToUpperCase @ StringDelete[ tag, Whitespace ]
    ];

removeSeverityTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*untagString*)
untagString // beginDefinition;

untagString[ as: KeyValuePattern @ { "FullContent" -> full_, "DynamicContent" -> dynamic_ } ] :=
    Association[ as, "FullContent" -> untagString @ full, "DynamicContent" -> untagString @ dynamic ];

untagString[ str_String? StringQ ] := StringDelete[ str, $$tagPrefix, IgnoreCase -> True ];

untagString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*processErrorCell*)
processErrorCell // beginDefinition;
processErrorCell // Attributes = { HoldFirst };

processErrorCell[ container_, cell_CellObject ] := (
    removeSeverityTag[ container, cell ];
    SetOptions[ cell, "AssistantOutputError" ];
    openChatCell @ cell
);

processErrorCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*processWarningCell*)
processWarningCell // beginDefinition;
processWarningCell // Attributes = { HoldFirst };

processWarningCell[ container_, cell_CellObject ] := (
    removeSeverityTag[ container, cell ];
    SetOptions[ cell, "AssistantOutputWarning" ];
    openChatCell @ cell
);

processWarningCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*processInfoCell*)
processInfoCell // beginDefinition;
processInfoCell // Attributes = { HoldFirst };

processInfoCell[ container_, cell_CellObject ] := (
    removeSeverityTag[ container, cell ];
    SetOptions[ cell, "AssistantOutput" ];
    $lastAutoOpen = $autoOpen;
    If[ TrueQ @ $autoOpen, openChatCell @ cell ]
);

processInfoCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*openChatCell*)
openChatCell // beginDefinition;

openChatCell[ cell_CellObject ] :=
    Module[ { prev, attached },
        prev = PreviousCell @ cell;
        attached = Cells[ prev, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ];
        NotebookDelete @ attached;
        SetOptions[
            cell,
            CellMargins     -> Inherited,
            CellOpen        -> Inherited,
            CellFrame       -> Inherited,
            ShowCellBracket -> Inherited,
            Initialization  -> Inherited
        ]
    ];

openChatCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertUTF8*)
convertUTF8 // beginDefinition;
convertUTF8[ string_String ] := convertUTF8[ string, True ];
convertUTF8[ string_String, True  ] := FromCharacterCode[ ToCharacterCode @ string, "UTF-8" ];
convertUTF8[ string_String, False ] := FromCharacterCode @ ToCharacterCode[ string, "UTF-8" ];
convertUTF8 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeReformattedCell*)
writeReformattedCell // beginDefinition;

writeReformattedCell[ settings_, KeyValuePattern[ "FullContent" -> string_ ], cell_ ] :=
    writeReformattedCell[ settings, string, cell ];

writeReformattedCell[ settings_, _ProgressIndicator, cell_CellObject ] :=
    writeReformattedCell[ settings, None, cell ];

writeReformattedCell[ settings_, None, cell_CellObject ] :=
    With[ { taggingRules = Association @ CurrentValue[ cell, TaggingRules ] },
        $lastChatString = None;
        If[ AssociationQ @ taggingRules[ "PageData" ],
            restoreLastPage[ settings, taggingRules, cell ],
            NotebookDelete @ cell
        ]
    ];

writeReformattedCell[ settings_, string_String, cell_CellObject ] := Enclose[
    Block[ { $dynamicText = False },
        Module[ { tag, open, label, pageData, uuid, new, output },

            tag      = ConfirmMatch[ CurrentValue[ cell, { TaggingRules, "MessageTag" } ], _String|Inherited, "Tag" ];
            open     = $lastOpen = cellOpenQ @ cell;
            label    = RawBoxes @ TemplateBox[ { }, "MinimizedChat" ];
            pageData = CurrentValue[ cell, { TaggingRules, "PageData" } ];
            uuid     = CreateUUID[ ];
            new      = reformatCell[ settings, string, tag, open, label, pageData, uuid ];
            output   = CellObject @ uuid;

            $lastChatString  = string;
            $reformattedCell = new;
            $lastChatOutput  = output;

            With[ { new = new, output = output },
                createFETask @ NotebookWrite[ cell, new, None, AutoScroll -> False ];
                createFETask @ attachChatOutputMenu @ output
            ]
        ]
    ],
    throwInternalFailure[ writeReformattedCell[ settings, string, cell ], ## ] &
];

writeReformattedCell[ settings_, other_, cell_CellObject ] :=
    createFETask @ NotebookWrite[
        cell,
        Cell[
            TextData @ {
                "An unexpected error occurred.\n\n",
                Cell @ BoxData @ ToBoxes @ catchAlways @ throwInternalFailure @
                    writeReformattedCell[ settings, other, cell ]
            },
            "ChatOutput",
            GeneratedCell     -> True,
            CellAutoOverwrite -> True
        ],
        None,
        AutoScroll -> False
    ];

writeReformattedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreLastPage*)
restoreLastPage // beginDefinition;

restoreLastPage[ settings_, rules_Association, cellObject_CellObject ] := Enclose[
    Module[ { pageData, b64, bytes, content, dingbat, uuid, cell },

        pageData = ConfirmBy[ rules[ "PageData" ], AssociationQ, "PageData" ];
        b64      = ConfirmBy[ pageData[ "Pages", pageData[ "CurrentPage" ] ], StringQ, "Base64" ];
        bytes    = ConfirmBy[ ByteArray @ b64, ByteArrayQ, "ByteArray" ];
        content  = ConfirmMatch[ BinaryDeserialize @ bytes, _TextData, "TextData" ];
        dingbat  = makeOutputDingbat @ settings;
        uuid     = CreateUUID[ ];

        cell = Cell[
            content,
            "ChatOutput",
            GeneratedCell     -> True,
            CellAutoOverwrite -> True,
            TaggingRules      -> rules,
            ExpressionUUID    -> uuid,
            If[ TrueQ[ rules[ "PageData", "PageCount" ] > 1 ],
                CellDingbat -> Cell[ BoxData @ TemplateBox[ { dingbat }, "AssistantIconTabbed" ], Background -> None ],
                CellDingbat -> Cell[ BoxData @ dingbat, Background -> None ]
            ]
        ];

        createFETask @ WithCleanup[
            NotebookWrite[
                cellObject,
                $reformattedCell = cell,
                None,
                AutoScroll -> False
            ],
            attachChatOutputMenu[ $lastChatOutput = CellObject @ uuid ]
        ]
    ],
    throwInternalFailure[ restoreLastPage[ settings, rules, cellObject ], ## ] &
];

restoreLastPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachChatOutputMenu*)
attachChatOutputMenu // beginDefinition;

attachChatOutputMenu[ cell_CellObject ] /; $cloudNotebooks := Null;

attachChatOutputMenu[ cell_CellObject ] := (
    $lastChatOutput = cell;
    NotebookDelete @ Cells[ cell, AttachedCell -> True, CellStyle -> "ChatMenu" ];
    AttachCell[
        cell,
        Cell[ BoxData @ TemplateBox[ { "ChatOutput", RGBColor[ "#ecf0f5" ] }, "ChatMenuButton" ], "ChatMenu" ],
        { Right, Top },
        Offset[ { -7, -7 }, { Right, Top } ],
        { Right, Top }
    ]
);

attachChatOutputMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reformatCell*)
reformatCell // beginDefinition;

reformatCell[ settings_, string_, tag_, open_, label_, pageData_, uuid_ ] := UsingFrontEnd @ Enclose[
    Module[ { content, rules, dingbat },

        content = ConfirmMatch[
            If[ TrueQ @ settings[ "AutoFormat" ], TextData @ reformatTextData @ string, TextData @ string ],
            TextData[ _String | _List ],
            "Content"
        ];

        rules = ConfirmBy[
            makeReformattedCellTaggingRules[ settings, string, tag, content, pageData ],
            AssociationQ,
            "TaggingRules"
        ];

        dingbat = makeOutputDingbat @ settings;

        Cell[
            content,
            If[ TrueQ @ $autoAssistMode,
                Switch[ tag,
                        "[ERROR]"  , "AssistantOutputError",
                        "[WARNING]", "AssistantOutputWarning",
                        _          , "AssistantOutput"
                ],
                "ChatOutput"
            ],
            GeneratedCell     -> True,
            CellAutoOverwrite -> True,
            TaggingRules      -> rules,
            If[ TrueQ[ rules[ "PageData", "PageCount" ] > 1 ],
                CellDingbat -> Cell[ BoxData @ TemplateBox[ { dingbat }, "AssistantIconTabbed" ], Background -> None ],
                CellDingbat -> Cell[ BoxData @ dingbat, Background -> None ]
            ],
            If[ TrueQ @ open,
                Sequence @@ { },
                Sequence @@ Flatten @ {
                    $closedChatCellOptions,
                    Initialization :> attachMinimizedIcon[ EvaluationCell[ ], label ]
                }
            ],
            ExpressionUUID -> uuid
        ]
    ],
    throwInternalFailure[ reformatCell[ settings, string, tag, open, label, pageData, uuid ], ## ] &
];

reformatCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeOutputDingbat*)
makeOutputDingbat // beginDefinition;
makeOutputDingbat[ as: KeyValuePattern[ "LLMEvaluator" -> config_Association ] ] := makeOutputDingbat[ as, config ];
makeOutputDingbat[ as_Association ] := makeOutputDingbat[ as, as ];
makeOutputDingbat[ as_, KeyValuePattern[ "PersonaIcon" -> icon_ ] ] := makeOutputDingbat[ as, icon ];
makeOutputDingbat[ as_, KeyValuePattern[ "Icon" -> icon_ ] ] := makeOutputDingbat[ as, icon ];
makeOutputDingbat[ as_, KeyValuePattern[ "Default" -> icon_ ] ] := makeOutputDingbat[ as, icon ];
makeOutputDingbat[ as_, _Association|_Missing|_Failure|None ] := TemplateBox[ { }, "AssistantIcon" ];
makeOutputDingbat[ as_, icon_ ] := toDingbatBoxes @ resizeDingbat @ icon;
makeOutputDingbat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeActiveOutputDingbat*)
makeActiveOutputDingbat // beginDefinition;

makeActiveOutputDingbat[ as: KeyValuePattern[ "LLMEvaluator" -> config_ ] ] := makeActiveOutputDingbat[ as, config ];
makeActiveOutputDingbat[ as_, KeyValuePattern[ "PersonaIcon" -> icon_ ] ] := makeActiveOutputDingbat[ as, icon ];
makeActiveOutputDingbat[ as_, KeyValuePattern[ "Icon" -> icon_ ] ] := makeActiveOutputDingbat[ as, icon ];

makeActiveOutputDingbat[ as_, KeyValuePattern[ "Active" -> icon_ ] ] :=
    Block[ { $noActiveProgress = True }, makeActiveOutputDingbat[ as, icon ] ];

makeActiveOutputDingbat[ as_, KeyValuePattern[ "Default" -> icon_ ] ] :=
    makeActiveOutputDingbat[ as, icon ];

makeActiveOutputDingbat[ as_, _Association|_Missing|_Failure|None ] :=
    makeActiveOutputDingbat[ as, RawBoxes @ TemplateBox[ { }, "AssistantIconActive" ] ];

makeActiveOutputDingbat[ as_, icon_ ] :=
    If[ TrueQ @ $noActiveProgress,
        TemplateBox[ { toDingbatBoxes @ resizeDingbat @ icon }, "ChatOutputStopButtonWrapper" ],
        TemplateBox[ { toDingbatBoxes @ resizeDingbat @ icon }, "ChatOutputStopButtonProgressWrapper" ]
    ];

makeActiveOutputDingbat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toDingbatBoxes*)
(* TODO: this could create a Dynamic with a unique trigger symbol that's only updated once per session *)

toDingbatBoxes // beginDefinition;
toDingbatBoxes[ icon_ ] := toDingbatBoxes[ icon ] = toCompressedBoxes @ icon;
toDingbatBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizeDingbat*)
resizeDingbat // beginDefinition;

resizeDingbat[ icon_ ] /; $resizeDingbats := Pane[
    icon,
    ContentPadding  -> False,
    FrameMargins    -> 0,
    ImageSize       -> { 35, 35 },
    ImageSizeAction -> "ShrinkToFit",
    Alignment       -> { Center, Center }
];

resizeDingbat[ icon_ ] := icon;

resizeDingbat // endDefinition;

$resizeDingbats = True;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeReformattedCellTaggingRules*)
makeReformattedCellTaggingRules // beginDefinition;

makeReformattedCellTaggingRules[
    settings_,
    string_,
    tag: _String|Inherited,
    content_,
    KeyValuePattern @ { "Pages" -> pages_Association, "PageCount" -> count_Integer, "CurrentPage" -> page_Integer }
] :=
    With[ { p = count + 1 },
    <|
        "CellToStringData" -> string,
        "MessageTag"       -> tag,
        "ChatData"         -> makeCompactChatData[ string, tag, settings ],
        "PageData"         -> <|
            "Pages"      -> Append[ pages, p -> BaseEncode @ BinarySerialize[ content, PerformanceGoal -> "Size" ] ],
            "PageCount"  -> p,
            "CurrentPage"-> p
        |>
    |>
];

makeReformattedCellTaggingRules[ settings_, string_, tag: _String|Inherited, content_, pageData_ ] := <|
    "CellToStringData" -> string,
    "MessageTag"       -> tag,
    "ChatData"         -> makeCompactChatData[ string, tag, settings ]
|>;

makeReformattedCellTaggingRules // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCompactChatData*)
makeCompactChatData // beginDefinition;

makeCompactChatData[ message_, tag_, as_ ] /; $cloudNotebooks := Inherited;

makeCompactChatData[
    message_,
    tag_,
    as: KeyValuePattern[ "Data" -> data: KeyValuePattern[ "Messages" -> messages_List ] ]
] :=
    BaseEncode @ BinarySerialize[
        Association[
            smallSettings @ KeyDrop[ as, "OpenAIKey" ],
            "MessageTag" -> tag,
            "Data" -> Association[
                data,
                "Messages" -> Append[ messages, <| "role" -> "assistant", "content" -> message |> ]
            ]
        ],
        PerformanceGoal -> "Size"
    ];

makeCompactChatData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FrontEnd Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachMinimizedIcon*)
attachMinimizedIcon // beginDefinition;

attachMinimizedIcon[ chatCell_CellObject, label_ ] :=
    Module[ { prev, cell },
        prev = PreviousCell @ chatCell;
        CurrentValue[ chatCell, Initialization ] = Inherited;
        cell = makeMinimizedIconCell[ label, chatCell ];
        NotebookDelete @ Cells[ prev, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ];
        With[ { prev = prev, cell = cell },
            If[ TrueQ @ BoxForm`sufficientVersionQ[ 13.2 ],
                FE`Evaluate @ FEPrivate`AddCellTrayWidget[ prev, "MinimizedChatIcon" -> <| "Content" -> cell |> ],
                AttachCell[ prev, cell, { "CellBracket", Top }, { 0, 0 }, { Right, Top } ]
            ]
        ]
    ];

attachMinimizedIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeMinimizedIconCell*)
makeMinimizedIconCell // beginDefinition;

makeMinimizedIconCell[ label_, chatCell_CellObject ] := Cell[
    BoxData @ MakeBoxes @ Button[
        MouseAppearance[ label, "LinkHand" ],
        With[ { attached = EvaluationCell[ ] }, NotebookDelete @ attached; openChatCell @ chatCell ],
        Appearance -> None
    ],
    "MinimizedChatIcon"
];

makeMinimizedIconCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withChatState*)
withChatState // beginDefinition;
withChatState // Attributes = { HoldFirst };
withChatState[ eval_ ] := withToolBox @ withBasePromptBuilder @ eval;
withChatState // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $chatContextDialogButtons;
    $chatContextDialogTemplateCells;
    $chatContextDialogStyles;
    $apiKeyDialogDescription;
    $promptStrings;
    $promptTemplate;
];

End[ ];
EndPackage[ ];
