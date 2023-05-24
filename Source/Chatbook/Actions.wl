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
`SendChat;
`StopChat;
`WidgetSend;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`Errors`"           ];
Needs[ "Wolfram`Chatbook`ErrorUtils`"       ];
Needs[ "Wolfram`Chatbook`PersonaInstaller`" ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`Serialization`"    ];
Needs[ "Wolfram`Chatbook`Formatting`"       ];
Needs[ "Wolfram`Chatbook`FrontEnd`"         ];
Needs[ "Wolfram`Chatbook`InlineReferences`" ];
Needs[ "Wolfram`Chatbook`Prompting`"        ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatbookAction*)
ChatbookAction[ "AIAutoAssist"         , args___ ] := catchMine @ AIAutoAssist @ args;
ChatbookAction[ "Ask"                  , args___ ] := catchMine @ AskChat @ args;
ChatbookAction[ "AttachCodeButtons"    , args___ ] := catchMine @ AttachCodeButtons @ args;
ChatbookAction[ "CopyChatObject"       , args___ ] := catchMine @ CopyChatObject @ args;
ChatbookAction[ "DisableAssistance"    , args___ ] := catchMine @ DisableAssistance @ args;
ChatbookAction[ "EvaluateChatInput"    , args___ ] := catchMine @ EvaluateChatInput @ args;
ChatbookAction[ "ExclusionToggle"      , args___ ] := catchMine @ ExclusionToggle @ args;
ChatbookAction[ "OpenChatBlockSettings", args___ ] := catchMine @ OpenChatBlockSettings @ args;
ChatbookAction[ "OpenChatMenu"         , args___ ] := catchMine @ OpenChatMenu @ args;
ChatbookAction[ "PersonaManage"        , args___ ] := catchMine @ PersonaManage @ args;
ChatbookAction[ "PersonaURLInstall"    , args___ ] := catchMine @ PersonaURLInstall @ args;
ChatbookAction[ "Send"                 , args___ ] := catchMine @ SendChat @ args;
ChatbookAction[ "StopChat"             , args___ ] := catchMine @ StopChat @ args;
ChatbookAction[ "TabLeft"              , args___ ] := catchMine @ TabLeft @ args;
ChatbookAction[ "TabRight"             , args___ ] := catchMine @ TabRight @ args;
ChatbookAction[ "WidgetSend"           , args___ ] := catchMine @ WidgetSend @ args;
ChatbookAction[ "InsertInlineReference", args___ ] := catchMine @ InsertInlineReference @ args;
ChatbookAction[ name_String            , args___ ] := catchMine @ throwFailure[ "NotImplemented", name, args ];
ChatbookAction[ args___                          ] := catchMine @ throwInternalFailure @ ChatbookAction @ args;

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
(*PersonaURLInstall*)
(* TODO: this will eventually get merged into the manage personas dialog instead of being a separate menu item *)

PersonaURLInstall // beginDefinition;

PersonaURLInstall[ dingbatCell_CellObject ] := Enclose[
    Catch @ Module[ { cellObject, installed, name },
        cellObject = ConfirmMatch[ topParentCell @ dingbatCell, _CellObject, "ParentCell" ];
        installed = PersonaInstallFromURL[ ];
        If[ installed === $Canceled, Throw @ $Canceled ];
        ConfirmAssert[ AssociationQ @ installed, "AssociationQ" ];
        name = ConfirmBy[ installed[ "Name" ], StringQ, "Name" ];
        ConfirmMatch[
            CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = name,
            name,
            "SetLLMEvaluator"
        ]
    ],
    throwInternalFailure[ PersonaURLInstall @ dingbatCell, ## ] &
];

PersonaURLInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*PersonaManage*)
PersonaManage[ a___ ] := Enclose[
    ConfirmBy[ PersonaInstallFromResourceSystem[ ], AssociationQ, "PersonaInstallFromResourceSystem" ],
    throwInternalFailure[ PersonaManage @ a, ## ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*PersonaURLInstall*)
(* FIXME: do the thing *)

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
rotateTabPage[ cell_CellObject, n_Integer ] /; $cloudNotebooks := rotateTabPage0[ cell, n ];
rotateTabPage[ cell_CellObject, n_Integer ] := rotateTabPage0[ parentCell @ cell, n ];
rotateTabPage // endDefinition;


rotateTabPage0 // beginDefinition;

rotateTabPage0[ cell_CellObject, n_Integer ] := Enclose[
    Module[ { pageData, pageCount, currentPage, newPage, encoded, content },

        pageData    = ConfirmBy[ <| CurrentValue[ cell, { TaggingRules, "PageData" } ] |>, AssociationQ, "PageData" ];
        pageCount   = ConfirmBy[ pageData[ "PageCount"   ], IntegerQ, "PageCount"   ];
        currentPage = ConfirmBy[ pageData[ "CurrentPage" ], IntegerQ, "CurrentPage" ];
        newPage     = Mod[ currentPage + n, pageCount, 1 ];
        encoded     = ConfirmMatch[ pageData[ "Pages", newPage ], _String, "EncodedContent" ];
        content     = ConfirmMatch[ BinaryDeserialize @ BaseDecode @ encoded, TextData[ _String|_List ], "Content" ];

        SelectionMove[ cell, All, CellContents, AutoScroll -> False ];
        NotebookWrite[ ParentNotebook @ cell, content, None, AutoScroll -> False ];
        SelectionMove[ cell, After, Cell, AutoScroll -> False ];
        CurrentValue[ cell, { TaggingRules, "PageData", "CurrentPage" } ] = newPage;
        SetOptions[ cell, CellAutoOverwrite -> True, GeneratedCell -> True ]
    ],
    throwInternalFailure[ rotateTabPage0[ cell, n ], ## ] &
];

rotateTabPage0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EvaluateChatInput*)
EvaluateChatInput // beginDefinition;

EvaluateChatInput[ ] := EvaluateChatInput @ EvaluationCell[ ];

EvaluateChatInput[ evalCell_CellObject? chatInputCellQ ] :=
    EvaluateChatInput[ evalCell, parentNotebook @ evalCell ];

EvaluateChatInput[ _CellObject | $Failed ] :=
    With[ { evalCell = EvaluationCell[ ] },
        EvaluateChatInput @ evalCell /; chatInputCellQ @ evalCell
    ];

EvaluateChatInput[ evalCell_CellObject, nbo_NotebookObject ] :=
    EvaluateChatInput[ evalCell, nbo, currentChatSettings @ nbo ];

EvaluateChatInput[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    withBasePromptBuilder @ Block[ { $autoAssistMode = False },
        clearMinimizedChats @ nbo;
        waitForLastTask[ ];
        sendChat[ evalCell, nbo, settings ]
    ];

EvaluateChatInput // endDefinition;

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
waitForLastTask[ task_TaskObject ] := TaskWait @ task;
waitForLastTask[ HoldPattern[ $lastTask ] ] := Null;
waitForLastTask // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AIAutoAssist*)
AIAutoAssist // beginDefinition;

AIAutoAssist[ cell_ ] /; $cloudNotebooks := Null;

AIAutoAssist[ cell_CellObject ] := AIAutoAssist[ cell, parentNotebook @ cell ];

AIAutoAssist[ cell_CellObject, nbo_NotebookObject ] := withBasePromptBuilder @
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

autoAssistQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*StopChat*)
StopChat // beginDefinition;

StopChat[ cell_CellObject ] := Enclose[
    Module[ { settings, container },
        settings = ConfirmBy[ currentChatSettings @ cell, AssociationQ, "ChatNotebookSettings" ];
        removeTask @ Lookup[ settings, "Task" ];
        container = ConfirmBy[ Lookup[ settings, "Container" ], StringQ, "Container" ];
        writeReformattedCell[ settings, container, cell ];
        Quiet @ NotebookDelete @ cell;
    ],
    throwInternalFailure[ StopChat @ cell, ## ] &
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
    With[ { chat = chatObject[ Append[ KeyMap[ Capitalize, #1 ], "Timestamp" -> Now ] & /@ messages ] },
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

AttachCodeButtons[ Dynamic[ attached_ ], cell_CellObject, string_, lang_ ] := (
    attached = AttachCell[
        EvaluationCell[ ],
        floatingButtonGrid[ attached, string, lang ],
        { Left, Bottom },
        Offset[ { 0, 13 }, { 0, 0 } ],
        { Left, Top },
        RemovalConditions -> { "MouseClickOutside", "MouseExit" }
    ]
);

AttachCodeButtons // endDefinition;

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

WidgetSend[ cell_CellObject ] := withBasePromptBuilder @
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

AskChat[ nbo_NotebookObject, { selected_CellObject } ] := withBasePromptBuilder @
    Module[ { selection, cell, obj },
        selection = NotebookRead @ nbo;
        cell = chatQueryCell @ selection;
        SelectionMove[ selected, After, Cell ];
        obj = cellPrint @ cell;
        SelectionMove[ obj, All, Cell ];
        SelectionEvaluateCreateCell @ nbo
    ];

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

SendChat[ ] := SendChat @ EvaluationCell[ ];

SendChat[ evalCell_CellObject, ___ ] /; MemberQ[ CurrentValue[ evalCell, CellStyle ], "ChatExcluded" ] := Null;

SendChat[ evalCell_CellObject ] := SendChat[ evalCell, parentNotebook @ evalCell ];

SendChat[ evalCell_CellObject, nbo_NotebookObject? queuedEvaluationsQ ] := Null;

SendChat[ evalCell_CellObject, nbo_NotebookObject ] :=
    SendChat[ evalCell, nbo, currentChatSettings @ nbo ];

SendChat[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    SendChat[ evalCell, nbo, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] /; $cloudNotebooks :=
    SendChat[ evalCell, nbo, settings, False ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] := withBasePromptBuilder @
    With[ { styles = cellStyles @ evalCell },
        Block[ { $autoOpen, $alwaysOpen = $alwaysOpen },
            $autoOpen = MemberQ[ styles, $$chatInputStyle ];
            $alwaysOpen = TrueQ[ $alwaysOpen || $autoOpen ];
            sendChat[ evalCell, nbo, addCellStyleSettings[ settings, styles ] ]
        ]
    ];

SendChat[ evalCell_, nbo_, settings_, minimized_ ] := withBasePromptBuilder @
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

        resolveInlineReferences @ evalCell;
        cells0 = ConfirmMatch[ selectChatCells[ settings0, evalCell, nbo ], { __CellObject }, "SelectChatCells" ];

        { cells, target } = ConfirmMatch[
            chatHistoryCellsAndTarget @ cells0,
            { { __CellObject }, _CellObject | None },
            "HistoryAndTarget"
        ];

        settings = ConfirmBy[ inheritSettings[ settings0, cells, evalCell ], AssociationQ, "InheritSettings" ];
        id       = Lookup[ settings, "ID" ];
        key      = toAPIKey[ Automatic, id ];

        If[ ! settings[ "IncludeHistory" ], cells = { evalCell } ];

        If[ ! StringQ @ key, throwFailure[ "NoAPIKey" ] ];

        { req, data } = Reap[
            ConfirmMatch[
                makeHTTPRequest[ Append[ settings, "OpenAIKey" -> key ], cells ],
                _HTTPRequest,
                "MakeHTTPRequest"
            ],
            $chatDataTag
        ];

        data = ConfirmBy[ Association @ Flatten @ data, AssociationQ, "Data" ];

        If[ data[ "RawOutput" ],
            persona = ConfirmBy[ GetCachedPersonaData[ "None" ], AssociationQ, "NonePersona" ];
            If[ AssociationQ @ settings[ "LLMEvaluator" ],
                settings[ "LLMEvaluator" ] = Association[ settings[ "LLMEvaluator" ], persona ],
                settings = Association[ settings, persona ]
            ]
        ];

        AppendTo[ settings, "Data" -> data ];

        container = ProgressIndicator[ Appearance -> "Percolate" ];

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
(*getLLMEvaluator*)
getLLMEvaluator // beginDefinition;
getLLMEvaluator[ as_Association ] := getLLMEvaluator[ as, Lookup[ as, "LLMEvaluator" ] ];
getLLMEvaluator[ as_, name_String ] := getLLMEvaluator[ as, getNamedLLMEvaluator @ name ];
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
    With[ { autoOpen = TrueQ @ $autoOpen, alwaysOpen = TrueQ @ $alwaysOpen, autoAssist = $autoAssistMode },
        URLSubmit[
            req,
            HandlerFunctions -> <|
                "BodyChunkReceived" -> Function @ catchTopAs[ ChatbookAction ][
                    Block[
                        {
                            $autoOpen       = autoOpen,
                            $alwaysOpen     = alwaysOpen,
                            $settings       = settings,
                            $autoAssistMode = autoAssist
                        },
                        Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                        writeChunk[ Dynamic @ container, cellObject, #1 ]
                    ]
                ],
                "TaskFinished" -> Function @ catchTopAs[ ChatbookAction ][
                    Block[
                        {
                            $autoOpen       = autoOpen,
                            $alwaysOpen     = alwaysOpen,
                            $settings       = settings,
                            $autoAssistMode = autoAssist
                        },
                        Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                        checkResponse[ settings, container, cellObject, #1 ]
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
                                    dynamicTextDisplay[ container, reformat ]
                                ],
                                TrackedSymbols :> { x },
                                UpdateInterval -> 0.2
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
                                dynamicTextDisplay[ container, reformat ]
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

activeAIAssistantCell[ container_, settings_, minimized_ ] :=
    With[
        {
            label    = RawBoxes @ TemplateBox[ { }, "MinimizedChatActive" ],
            id       = $SessionID,
            reformat = dynamicAutoFormatQ @ settings,
            task     = Lookup[ settings, "Task" ]
        },
        Cell[
            BoxData @ ToBoxes @
                If[ TrueQ @ reformat,
                    Dynamic[
                        Refresh[
                            dynamicTextDisplay[ container, reformat ],
                            TrackedSymbols :> { },
                            UpdateInterval -> 0.2
                        ],
                        Initialization   :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ],
                        Deinitialization :> Quiet @ TaskRemove @ task
                    ],
                    Dynamic[
                        dynamicTextDisplay[ container, reformat ],
                        Initialization   :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ],
                        Deinitialization :> Quiet @ TaskRemove @ task
                    ]
                ],
            "Output",
            "ChatOutput",
            If[ TrueQ @ $autoAssistMode && MatchQ[ minimized, True|Automatic ],
                Sequence @@ Flatten[ {
                    $closedChatCellOptions,
                    Initialization :> attachMinimizedIcon[ EvaluationCell[ ], label ]
                } ],
                Sequence @@ { }
            ],
            Selectable   -> False,
            Editable     -> False,
            CellDingbat  -> Cell[ BoxData @ makeActiveOutputDingbat @ settings, Background -> None ],
            TaggingRules -> <| "ChatNotebookSettings" -> settings |>
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
smallSettings // endDefinition

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

dynamicTextDisplay[ text_String, True ] :=
    With[ { id = $SessionID },
        Dynamic[
            Refresh[
                Block[ { $dynamicText = True }, RawBoxes @ Cell @ TextData @ reformatTextData @ text ],
                TrackedSymbols :> { },
                UpdateInterval -> 0.2
            ],
            Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
        ]
    ];

dynamicTextDisplay[ text_String, False ] :=
    With[ { id = $SessionID },
        Dynamic[
            RawBoxes @ Cell @ TextData @ text,
            Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
        ]
    ];

dynamicTextDisplay[ _Symbol, _ ] := ProgressIndicator[ Appearance -> "Percolate" ];

dynamicTextDisplay[ other_, _ ] := other;

dynamicTextDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkResponse*)
checkResponse // beginDefinition;

checkResponse[ settings_, container_, cell_, as: KeyValuePattern[ "StatusCode" -> Except[ 200, _Integer ] ] ] :=
    Module[ { log, chunks, folded, body, data },
        log    = Internal`BagPart[ $debugLog, All ];
        chunks = Cases[ log, KeyValuePattern[ "BodyChunk" -> s_String ] :> s ];
        folded = FoldList[ StringJoin, chunks ];
        { body, data } = FirstCase[
            folded,
            s_String :> With[ { json = Quiet @ Developer`ReadRawJSONString @ s },
                            { s, json } /; MatchQ[ json, KeyValuePattern[ "error" -> _ ] ]
                        ],
            { Last[ folded, Missing[ "NotAvailable" ] ], Missing[ "NotAvailable" ] }
        ];
        writeErrorCell[ cell, $badResponse = Association[ as, "Body" -> body, "BodyJSON" -> data ] ]
    ];

checkResponse[ settings_, container_, cell_, as_Association ] := (
    writeReformattedCell[ settings, container, cell ];
    (* Quiet @ NotebookDelete @ cell; *)
);

checkResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeErrorCell*)
writeErrorCell // ClearAll;
writeErrorCell[ cell_, as_ ] := NotebookWrite[ cell, errorCell @ as ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorCell*)
errorCell // ClearAll;
errorCell[ as_ ] :=
    Cell[
        TextData @ {
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

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorText*)
errorText // ClearAll;

errorText[ KeyValuePattern[ "BodyJSON" -> KeyValuePattern[ "error" -> KeyValuePattern[ "message" -> s_String ] ] ] ] :=
    s;

errorText[ ___ ] := "An unexpected error occurred.";

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

makeHTTPRequest[ settings_Association? AssociationQ, cells: { __Cell } ] :=
    makeHTTPRequest[ settings, makeChatMessages[ settings, cells ] ];

makeHTTPRequest[ settings_Association? AssociationQ, messages0: { __Association } ] :=
    Enclose @ Module[
        { messages, key, stream, model, tokens, temperature, topP, freqPenalty, presPenalty, data, body },

        If[ settings[ "AutoFormat" ], needsBasePrompt[ "Formatting" ] ];
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
                "stream"            -> stream
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
    Module[ { modifiers, cell, name, arguments, filled, string },
        { modifiers, cell } = ConfirmMatch[ extractModifiers @ cell0, { _, _ }, "Modifiers" ];
        name      = ConfirmBy[ extractPromptFunctionName @ cell, StringQ, "PromptFunctionName" ];
        arguments = ConfirmMatch[ extractPromptArguments @ cell, { ___String }, "PromptArguments" ];
        filled    = ConfirmMatch[ replaceArgumentTokens[ name, arguments, { cells, cell } ], { ___String }, "Tokens" ];
        string    = ConfirmBy[ getLLMPrompt[ name ] @@ filled, StringQ, "LLMPrompt" ];
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
getLLMPrompt[ name_String ] := Block[ { PrintTemporary }, Quiet @ getLLMPrompt0 @ name ];
getLLMPrompt // endDefinition;

getLLMPrompt0 // beginDefinition;
getLLMPrompt0[ name_ ] := With[ { t = System`LLMPrompt[ "Prompt: "<>name ] }, t /; MatchQ[ t, _TemplateObject ] ];
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

toModelName[ name_String? StringQ ] :=
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

makeCurrentRole[ as_, _, KeyValuePattern[ "BasePrompt" -> None ] ] :=
    Missing[ ];

makeCurrentRole[ as_, _, eval_Association ] :=
    <| "role" -> "system", "content" -> buildSystemPrompt @ Association[ as, eval ] |>;

makeCurrentRole[ as_, _, _ ] :=
    <| "role" -> "system", "content" -> buildSystemPrompt @ as |>;

makeCurrentRole // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buildSystemPrompt*)
buildSystemPrompt // beginDefinition;

buildSystemPrompt[ as_Association ] := StringTrim @ TemplateApply[
    $promptTemplate,
    Association[
        $promptComponents[ "Generic" ],
		Select[
			<|
				"Pre"  -> getPrePrompt @ as,
				"Post" -> getPostPrompt @ as,
                "Base" -> "%%BASE_PROMPT%%"
			|>,
			StringQ
		]
    ]
];

buildSystemPrompt // endDefinition;

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
        outCells = Cells[ nbo, CellStyle -> "ChatOutput" ];
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
        If[ MemberQ[ cellStyles @ next, "ChatOutput" ] && TrueQ[ ! CurrentValue[ next, CellOpen ] ],
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
    Module[ { name, arguments, filled, string, role },
        name      = ConfirmBy[ modifier[ "PromptModifierName" ], StringQ, "ModifierName" ];
        arguments = ConfirmMatch[ modifier[ "PromptArguments" ], { ___String }, "Arguments" ];
        filled    = ConfirmMatch[ replaceArgumentTokens[ name, arguments, { cells, cell } ], { ___String }, "Tokens" ];
        string    = ConfirmBy[ getLLMPrompt[ name ] @@ filled, StringQ, "LLMPrompt" ];
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
extractModifiers // beginDefinition;

extractModifiers[ cell: Cell[ _String, ___ ] ] := { { }, cell };
extractModifiers[ cell: Cell[ TextData[ _String ], ___ ] ] := { { }, cell };

extractModifiers[ Cell[ TextData[ text: { ___, Cell[ _, "InlineModifierReference", ___ ], ___ } ], a___ ] ] := {
    Cases[ text, cell: Cell[ _, "InlineModifierReference", ___ ] :> extractModifier @ cell ],
    Cell[ TextData @ DeleteCases[ text, Cell[ _, "InlineModifierReference", ___ ] ], a ]
};

extractModifiers[ Cell[ TextData[ modifier: Cell[ _, "InlineModifierReference", ___ ] ], a___ ] ] := {
    { extractModifier @ modifier },
    Cell[ "", a ]
};

extractModifiers[ cell_Cell ] := { { }, cell };

extractModifiers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*extractModifier*)
extractModifier // beginDefinition;
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
    "ChatInput"       -> "user",
    "ChatOutput"      -> "assistant",
    "ChatSystemInput" -> "system"
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
    If[ StringQ @ container,
        container = StringDelete[ container <> convertUTF8 @ text, StartOfString~~Whitespace ],
        container = convertUTF8 @ text
    ];
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

cloudSystemCredential[ name_ ] :=
    With[ { credential = SystemCredential @ name },
        credential /; StringQ @ credential
    ];

(* Workaround for CLOUD-22865 *)
cloudSystemCredential[ name_ ] :=
    Block[ { $SystemCredentialStore = $cloudCredentialStore },
        SystemCredential @ name
    ];

cloudSystemCredential // endDefinition;

$cloudCredentialStore := SystemCredentialStoreObject @ <|
    "Backend" -> "EncryptedFile",
    "Keyring" -> "Chatbook-"<>$MachineName
|>;

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

setCloudSystemCredential[ name_, value_ ] := Quiet[
    Check[ SystemCredential[ name ] = value,
           setCloudSystemCredential0[ name, value ],
           SystemCredential::nset
    ],
    SystemCredential::nset
];

setCloudSystemCredential // endDefinition;


setCloudSystemCredential0 // beginDefinition;

setCloudSystemCredential0[ name_, value_ ] :=
    Block[ { $SystemCredentialStore = $cloudCredentialStore },
        SystemCredential[ name ] = value
    ];

setCloudSystemCredential0 // endDefinition;

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

getModelList[ key_String ] := getModelList[ key, Hash @ key ];

getModelList[ key_String, hash_Integer ] :=
    getModelList[
        hash,
        URLExecute[
            HTTPRequest[
                "https://api.openai.com/v1/models",
                <| "Headers" -> <| "Content-Type" -> "application/json", "Authorization" -> "Bearer "<>key |> |>
            ],
            "RawJSON",
            Interactive -> False
        ]
    ];

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
errorTaggedQ[ s_String? StringQ ] := taggedQ[ s, "ERROR" ];
errorTaggedQ[ ___               ] := False;


warningTaggedQ // ClearAll;
warningTaggedQ[ s_String? StringQ ] := taggedQ[ s, "WARNING" ];
warningTaggedQ[ ___               ] := False;


infoTaggedQ // ClearAll;
infoTaggedQ[ s_String? StringQ ] := taggedQ[ s, "INFO" ];
infoTaggedQ[ ___               ] := False;


untaggedQ // ClearAll;
untaggedQ[ s0_String? StringQ ] /; $alwaysOpen :=
    With[ { s = StringDelete[ $lastUntagged = s0, Whitespace ] },
        Or[ StringStartsQ[ s, Except[ "[" ] ],
            StringLength @ s >= $maxTagLength && ! StringStartsQ[ s, $$tagPrefix, IgnoreCase -> True ]
        ]
    ];

untaggedQ[ ___ ] := False;


taggedQ // ClearAll;
taggedQ[ s_String? StringQ ] := taggedQ[ s, $$severityTag ];
taggedQ[ s_String? StringQ, tag_ ] := StringStartsQ[ StringDelete[ s, Whitespace ], "["~~tag~~"]", IgnoreCase -> True ];
taggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeSeverityTag*)
removeSeverityTag // beginDefinition;
removeSeverityTag // Attributes = { HoldFirst };

removeSeverityTag[ s_Symbol? StringQ, cell_CellObject ] :=
    Module[ { tag },
        tag = StringReplace[ s, t:$$tagPrefix~~___~~EndOfString :> t ];
        s = untagString @ s;
        CurrentValue[ cell, { TaggingRules, "MessageTag" } ] = ToUpperCase @ StringDelete[ tag, Whitespace ]
    ];

removeSeverityTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*untagString*)
untagString // beginDefinition;
untagString[ str_String? StringQ ] := StringDelete[ str, $$tagPrefix, IgnoreCase -> True ];
untagString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*processErrorCell*)
processErrorCell // beginDefinition;
processErrorCell // Attributes = { HoldFirst };

processErrorCell[ container_, cell_CellObject ] := (
    $$errorString = container;
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
    $$warningString = container;
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
    $$infoString = container;
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
convertUTF8[ string_String ] := FromCharacterCode[ ToCharacterCode @ string, "UTF-8" ];
convertUTF8 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeReformattedCell*)
writeReformattedCell // beginDefinition;

writeReformattedCell[ settings_, string_String, cell_CellObject ] :=
    With[
        {
            tag      = CurrentValue[ cell, { TaggingRules, "MessageTag" } ],
            open     = $lastOpen = cellOpenQ @ cell,
            label    = RawBoxes @ TemplateBox[ { }, "MinimizedChat" ],
            pageData = CurrentValue[ cell, { TaggingRules, "PageData" } ]
        },
        Block[ { $dynamicText = False },
            NotebookWrite[
                cell,
                $reformattedCell = reformatCell[ settings, string, tag, open, label, pageData ],
                None,
                AutoScroll -> False
            ]
        ]
    ];

writeReformattedCell[ settings_, other_, cell_CellObject ] :=
    NotebookWrite[
        cell,
        Cell[
            TextData @ {
                "An unexpected error occurred.\n\n",
                Cell @ BoxData @ ToBoxes @ Catch[
                    throwInternalFailure @ writeReformattedCell[ settings, other, cell ],
                    $catchTopTag
                ]
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
(*reformatCell*)
reformatCell // beginDefinition;

reformatCell[ settings_, string_, tag_, open_, label_, pageData_ ] := UsingFrontEnd @ Enclose[
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
            "ChatOutput",
            If[ TrueQ @ $autoAssistMode,
                Switch[ tag,
                        "[ERROR]"  , "AssistantOutputError",
                        "[WARNING]", "AssistantOutputWarning",
                        _          , "AssistantOutput"
                ],
                Sequence @@ { }
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
            ]
        ]
    ],
    throwInternalFailure[ reformatCell[ settings, string, tag, open, label, pageData ], ## ] &
];

reformatCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeOutputDingbat*)
makeOutputDingbat // beginDefinition;
makeOutputDingbat[ as: KeyValuePattern[ "LLMEvaluator" -> config_ ] ] := makeOutputDingbat[ as, config ];
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
    tag_,
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

makeReformattedCellTaggingRules[ settings_, string_, tag_, content_, pageData_ ] := <|
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
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    $chatContextDialogButtons;
    $chatContextDialogTemplateCells;
    $chatContextDialogStyles;
    $apiKeyDialogDescription;
    $promptStrings;
    $promptTemplate;
];

End[ ];
EndPackage[ ];
