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

Needs[ "Wolfram`Chatbook`"               ];
Needs[ "Wolfram`Chatbook`ErrorUtils`"    ];
Needs[ "Wolfram`Chatbook`Serialization`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$chatDelimiterStyles = { "ChatContextDivider", "ChatDelimiter" };
$chatIgnoredStyles   = { "ChatExcluded" };
$chatInputStyles     = { "ChatInput", "ChatQuery", "ChatSystemInput" };
$chatOutputStyles    = { "ChatOutput" };

$maxChatCells = OptionValue[ CreateChatNotebook, "ChatHistoryLength" ];

$$externalLanguage = "Java"|"Julia"|"Jupyter"|"NodeJS"|"Octave"|"Python"|"R"|"Ruby"|"Shell"|"SQL"|"SQL-JDBC";

$externalLanguageRules = Flatten @ {
    "JS"         -> "NodeJS",
    "Javascript" -> "NodeJS",
    "NPM"        -> "NodeJS",
    "Node"       -> "NodeJS",
    "Bash"       -> "Shell",
    "SH"         -> "Shell",
    Cases[ $$externalLanguage, lang_ :> (lang -> lang) ]
};

$closedChatCellOptions :=
    If[ TrueQ @ CloudSystem`$CloudNotebooks,
        Sequence @@ { },
        Sequence @@ { CellMargins -> -2, CellOpen -> False, CellFrame -> 0, ShowCellBracket -> False }
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Style Patterns*)
$$chatDelimiterStyle = Alternatives @@ $chatDelimiterStyles | { ___, Alternatives @@ $chatDelimiterStyles, ___ };
$$chatIgnoredStyle   = Alternatives @@ $chatIgnoredStyles   | { ___, Alternatives @@ $chatIgnoredStyles  , ___ };
$$chatInputStyle     = Alternatives @@ $chatInputStyles     | { ___, Alternatives @@ $chatInputStyles    , ___ };
$$chatOutputStyle    = Alternatives @@ $chatOutputStyles    | { ___, Alternatives @@ $chatOutputStyles   , ___ };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
$inDef = False;
$debug = True;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*beginDefinition*)
beginDefinition // ClearAll;
beginDefinition // Attributes = { HoldFirst };
beginDefinition::Unfinished =
"Starting definition for `1` without ending the current one.";

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
beginDefinition[ s_Symbol ] /; $debug && $inDef :=
    WithCleanup[
        $inDef = False
        ,
        Print @ TemplateApply[ beginDefinition::Unfinished, HoldForm @ s ];
        beginDefinition @ s
        ,
        $inDef = True
    ];
(* :!CodeAnalysis::EndBlock:: *)

beginDefinition[ s_Symbol ] :=
    WithCleanup[ Unprotect @ s; ClearAll @ s, $inDef = True ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*endDefinition*)
endDefinition // beginDefinition;
endDefinition // Attributes = { HoldFirst };

endDefinition[ s_Symbol ] := endDefinition[ s, DownValues ];

endDefinition[ s_Symbol, None ] := $inDef = False;

endDefinition[ s_Symbol, DownValues ] :=
    WithCleanup[
        AppendTo[ DownValues @ s,
                  e: HoldPattern @ s[ ___ ] :>
                      throwInternalFailure @ HoldForm @ e
        ],
        $inDef = False
    ];

endDefinition[ s_Symbol, SubValues  ] :=
    WithCleanup[
        AppendTo[ SubValues @ s,
                  e: HoldPattern @ s[ ___ ][ ___ ] :>
                      throwInternalFailure @ HoldForm @ e
        ],
        $inDef = False
    ];

endDefinition[ s_Symbol, list_List ] :=
    endDefinition[ s, # ] & /@ list;

endDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatbookAction*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)
ChatbookAction::Internal =
"An unexpected error occurred. `1`";

ChatbookAction::NoAPIKey =
"No API key defined.";

ChatbookAction::InvalidAPIKey =
"Invalid value for API key: `1`";

ChatbookAction::UnknownResponse =
"Unexpected response from OpenAI server";

ChatbookAction::RateLimitReached =
"Rate limit reached for requests. Please try again later.";

ChatbookAction::UnknownStatusCode =
"Unexpected response from OpenAI server with status code `StatusCode`";

ChatbookAction::BadResponseMessage =
"`1`";

ChatbookAction::NotImplemented =
"Action \"`1`\" is not implemented.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Dispatcher Definitions*)
ChatbookAction[ "Ask"              , args___ ] := catchTop @ AskChat @ args;
ChatbookAction[ "AttachCodeButtons", args___ ] := catchTop @ AttachCodeButtons @ args;
ChatbookAction[ "AIAutoAssist"     , args___ ] := catchTop @ AIAutoAssist @ args;
ChatbookAction[ "CopyChatObject"   , args___ ] := catchTop @ CopyChatObject @ args;
ChatbookAction[ "ExclusionToggle"  , args___ ] := catchTop @ ExclusionToggle @ args;
ChatbookAction[ "EvaluateChatInput", args___ ] := catchTop @ EvaluateChatInput @ args;
ChatbookAction[ "OpenChatMenu"     , args___ ] := catchTop @ OpenChatMenu @ args;
ChatbookAction[ "Send"             , args___ ] := catchTop @ SendChat @ args;
ChatbookAction[ "StopChat"         , args___ ] := catchTop @ StopChat @ args;
ChatbookAction[ "WidgetSend"       , args___ ] := catchTop @ WidgetSend @ args;
ChatbookAction[ name_String        , args___ ] := catchTop @ throwFailure[ ChatbookAction::NotImplemented, name, args ];
ChatbookAction[ args___                      ] := catchTop @ throwInternalFailure @ HoldForm @ ChatbookAction @ args;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EvaluateChatInput*)
EvaluateChatInput // beginDefinition;

EvaluateChatInput[ ] := EvaluateChatInput @ EvaluationCell[ ];

EvaluateChatInput[ evalCell_CellObject ] := EvaluateChatInput[ evalCell, parentNotebook @ evalCell ];

EvaluateChatInput[ evalCell_CellObject, nbo_NotebookObject ] :=
    EvaluateChatInput[ evalCell, nbo, Association @ CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings" } ] ];

EvaluateChatInput[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    Block[ { $autoAssistMode = False }, sendChat[ evalCell, nbo, settings ] ];

EvaluateChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AIAutoAssist*)
AIAutoAssist // beginDefinition;

AIAutoAssist[ cell_ ] /; CloudSystem`$CloudNotebooks := Null;

AIAutoAssist[ cell_CellObject ] := AIAutoAssist[ cell, parentNotebook @ cell ];

AIAutoAssist[ cell_CellObject, nbo_NotebookObject ] :=
    If[ autoAssistQ[ cell, nbo ],
        Block[ { $autoAssistMode = True }, SendChat @ cell ],
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
        CurrentValue[ nbo,  { TaggingRules, "ChatNotebookSettings", "Assistance" } ],
        CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", "Assistance" } ]
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

        settings = ConfirmBy[
            Association @ CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ],
            AssociationQ,
            "ChatNotebookSettings"
        ];

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
        encodedString = ConfirmBy[ CurrentValue[ cell, { TaggingRules, "ChatData" } ], StringQ ];
        chatData      = ConfirmBy[ BinaryDeserialize @ BaseDecode @ encodedString, AssociationQ ];
        messages      = ConfirmMatch[ chatData[ "Data", "Messages" ], { __Association? AssociationQ } ];
        chatObject    = Confirm @ constructChatObject @ messages;
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
    With[ { chat = System`CreateChat[ Append[ KeyMap[ Capitalize, #1 ], "Timestamp" -> Now ] & /@ messages ] },
        chat /; MatchQ[ chat, _System`ChatObject ]
    ];

constructChatObject[ messages_List ] :=
    Dataset[ KeyMap[ Capitalize ] /@ messages ];

constructChatObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenChatMenu*)
OpenChatMenu // beginDefinition;
OpenChatMenu[ "ChatInput"  , cell_CellObject ] := openChatInputMenu @ cell;
OpenChatMenu[ "ChatOutput" , cell_CellObject ] := openChatOutputMenu @ cell;
OpenChatMenu[ "ChatSection", cell_CellObject ] := openChatSectionDialog @ cell;
OpenChatMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openChatInputMenu*)
openChatInputMenu // beginDefinition;

openChatInputMenu[ cell0_CellObject ] :=
    With[ { cell = ParentCell @ cell0 },
        AttachCell[
            cell,
            chatInputMenu @ cell,
            { Right, Top },
            Offset[ { -7, -7 }, { 0, 0 } ],
            { Right, Top },
            RemovalConditions -> { "EvaluatorQuit", "MouseClickOutside" }
        ]
    ];

openChatInputMenu // endDefinition;


chatInputMenu[ cell_CellObject ] := Pane[
    RawBoxes @ TemplateBox[
        {
            ToBoxes @ Grid[
                {
                    {
                        inputMenuLabel[ "Temperature" ],
                        inputMenuLabel @ Slider[
                            Dynamic @ AbsoluteCurrentValue[
                                cell,
                                { TaggingRules, "ChatNotebookSettings", "Temperature" }
                            ],
                            { 0, 2 },
                            ImageSize  -> { 100, Automatic },
                            Appearance -> "Labeled"
                        ]
                    },
                    {
                        inputMenuLabel[ "Model" ],
                        PopupMenu[
                            Dynamic @ AbsoluteCurrentValue[
                                cell,
                                { TaggingRules, "ChatNotebookSettings", "Model" }
                            ],
                            {
                                "gpt-3.5-turbo" -> inputMenuLabel @ Row @ {
                                    RawBoxes @ TemplateBox[ { }, "OpenAILogo" ], " ", "GPT-3.5"
                                },
                                "gpt-4" -> inputMenuLabel @ Row @ {
                                    RawBoxes @ TemplateBox[ { }, "OpenAILogo" ], " ", "GPT-4"
                                }
                            }
                        ]
                    }
                },
                Alignment -> { Left, Baseline },
                Spacings  -> { 1, 1 }
            ],
            FrameMargins   -> 7,
            Background     -> GrayLevel[ 1 ],
            RoundingRadius -> 3,
            FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], GrayLevel[ 0.85 ] ],
            ImageMargins   -> 0,
            ImageSize      -> { Full, Automatic }
        },
        "Highlighted"
    ],
    ImageSize -> { 250, Automatic }
];


inputMenuLabel[ text_ ] := Style[ text, "ChatMenuLabel" ];


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openChatOutputMenu*)
openChatOutputMenu // beginDefinition;

openChatOutputMenu[ cell_CellObject ] := AttachCell[
    ParentCell @ cell,
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
openChatSectionDialog[ cell0_CellObject ] := createChatContextDialog @ ParentCell @ cell0;
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

WidgetSend[ cell_CellObject ] :=
    Block[ { $alwaysOpen = True, cellPrint = cellPrintAfter @ cell, $finalCell = cell },
        SendChat @ cell
    ];

WidgetSend // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AskChat*)
AskChat // beginDefinition;

AskChat[ ] := AskChat[ InputNotebook[ ] ];

AskChat[ nbo_NotebookObject ] := AskChat[ nbo, SelectedCells @ nbo ];

AskChat[ nbo_NotebookObject, { selected_CellObject } ] :=
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
    SendChat[ evalCell, nbo, Association @ CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings" } ] ];

SendChat[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    SendChat[ evalCell, nbo, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] /; CloudSystem`$CloudNotebooks :=
    SendChat[ evalCell, nbo, settings, False ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] :=
    Block[ { $autoOpen, $alwaysOpen = $alwaysOpen },
        $autoOpen = MemberQ[ CurrentValue[ evalCell, CellStyle ], $$chatInputStyle ];
        $alwaysOpen = TrueQ @ $alwaysOpen || $autoOpen;
        sendChat[ evalCell, nbo, settings ]
    ];

SendChat[ evalCell_, nbo_, settings_, minimized_ ] :=
    Block[ { $alwaysOpen = alwaysOpenQ[ settings, minimized ] },
        sendChat[ evalCell, nbo, settings ]
    ];

SendChat // endDefinition;

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

sendChat[ evalCell_, nbo_, settings0_ ] := catchTop @ Enclose[
    Module[ { cells, settings, id, key, req, data, cell, cellObject, container, task },

        cells    = ConfirmMatch[ selectChatCells[ settings0, evalCell, nbo ], { __CellObject }, "SelectChatCells" ];
        settings = ConfirmBy[ inheritSettings[ settings0, cells, evalCell ], AssociationQ, "InheritSettings" ];
        id       = Lookup[ settings, "ID" ];
        key      = toAPIKey[ Automatic, id ];

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

        AppendTo[ settings, "Data" -> data ];

        container = ProgressIndicator[ Appearance -> "Percolate" ];

        $reformattedCell = None;
        cell = activeAIAssistantCell[
            container,
            Association[ settings, "Task" :> task, "Container" :> container, "CellObject" :> cellObject ]
        ];

        Quiet[
            TaskRemove @ $lastTask;
            NotebookDelete @ $lastCellObject;
        ];

        $resultCellCache = <| |>;
        $debugLog = Internal`Bag[ ];
        cellObject = $lastCellObject = cellPrint @ cell;
        task = Confirm[ $lastTask = submitAIAssistant[ container, req, cellObject, settings ] ];
    ],
    throwInternalFailure[ sendChat[ evalCell, nbo, settings0 ], ## ] &
];

sendChat // endDefinition;

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
] :=
    mergeSettings[
        settings,
        Association @ CurrentValue[ delimiter, { TaggingRules, "ChatNotebookSettings" } ],
        Association @ CurrentValue[ evalCell, { TaggingRules, "ChatNotebookSettings" } ]
    ];

inheritSettings[ settings_Association, _, evalCell_CellObject ] :=
    mergeSettings[
        settings,
        <| |>,
        Association @ CurrentValue[ evalCell, { TaggingRules, "ChatNotebookSettings" } ]
    ];

inheritSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeSettings*)
mergeSettings // beginDefinition;

mergeSettings[ settings_? AssociationQ, group_? AssociationQ, cell_? AssociationQ ] :=
    Association[ settings, Complement[ group, settings ], Complement[ cell, settings ] ];\

mergeSettings // endDefinition;\

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*alwaysOpenQ*)
alwaysOpenQ // beginDefinition;
alwaysOpenQ[ _, _ ] /; $alwaysOpen := True;
alwaysOpenQ[ as_, True  ] := False;
alwaysOpenQ[ as_, False ] := True;
alwaysOpenQ[ as_, _     ] := StringQ @ as[ "RolePrompt" ] && StringFreeQ[ as[ "RolePrompt" ], $$severityTag ];
alwaysOpenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitAIAssistant*)
submitAIAssistant // beginDefinition;
submitAIAssistant // Attributes = { HoldFirst };

submitAIAssistant[ container_, req_, cellObject_, settings_ ] :=
    With[ { autoOpen = TrueQ @ $autoOpen, alwaysOpen = TrueQ @ $alwaysOpen },
        URLSubmit[
            req,
            HandlerFunctions -> <|
                "BodyChunkReceived" -> Function[
                    catchTop @ Block[ { $autoOpen = autoOpen, $alwaysOpen = alwaysOpen },
                        Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                        writeChunk[ Dynamic @ container, cellObject, #1 ]
                    ]
                ],
                "TaskFinished" -> Function[
                    catchTop @ Block[ { $autoOpen = autoOpen, $alwaysOpen = alwaysOpen },
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
] /; CloudSystem`$CloudNotebooks :=
    With[
        {
            label    = RawBoxes @ TemplateBox[ { }, "MinimizedChatActive" ],
            id       = $SessionID,
            reformat = dynamicAutoFormatQ @ settings
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
                            Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
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
                            Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
                        ]
                    ],
                "Output",
                "ChatOutput",
                Sequence @@ Flatten[ { $closedChatCellOptions } ],
                Selectable   -> False,
                Editable     -> False,
                CellDingbat  -> Cell[ BoxData @ TemplateBox[ { }, "AssistantIconActive" ], Background -> None ],
                TaggingRules -> <| "ChatNotebookSettings" -> settings |>
            ]
        ]
    ];

activeAIAssistantCell[ container_, settings_, minimized_ ] :=
    With[
        {
            label    = RawBoxes @ TemplateBox[ { }, "MinimizedChatActive" ],
            id       = $SessionID,
            reformat = dynamicAutoFormatQ @ settings
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
                        Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
                    ],
                    Dynamic[
                        dynamicTextDisplay[ container, reformat ],
                        Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
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
            CellDingbat  -> Cell[ BoxData @ TemplateBox[ { }, "AssistantIconActive" ], Background -> None ],
            TaggingRules -> <| "ChatNotebookSettings" -> settings |>
        ]
    ];

activeAIAssistantCell // endDefinition;

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
    Quiet @ NotebookDelete @ cell;
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
    ToBoxes @ messageFailure[ ChatbookAction::RateLimitReached, as ];

errorBoxes[ as: KeyValuePattern[ "StatusCode" -> code: Except[ 200 ] ] ] :=
    ToBoxes @ messageFailure[ ChatbookAction::UnknownStatusCode, as ];

errorBoxes[ as_ ] :=
    ToBoxes @ messageFailure[ ChatbookAction::UnknownResponse, as ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeHTTPRequest*)
makeHTTPRequest // beginDefinition;

makeHTTPRequest[ settings_Association? AssociationQ, nbo_NotebookObject, cell_CellObject ] :=
    makeHTTPRequest[ settings, selectChatCells[ settings, cell, nbo ] ];

makeHTTPRequest[ settings_Association? AssociationQ, cells: { __CellObject } ] :=
    makeHTTPRequest[ settings, notebookRead @ cells ];

makeHTTPRequest[ settings_Association? AssociationQ, cells: { __Cell } ] :=
    Module[ { role, message, history, messages, merged },
        role     = makeCurrentRole @ settings;
        message  = Block[ { $CurrentCell = True }, makeCellMessage @ Last @ cells ];
        history  = Reverse[ makeCellMessage /@ Reverse @ Most @ cells ];
        messages = DeleteMissing @ Flatten @ { role, history, message };
        merged   = If[ TrueQ @ Lookup[ settings, "MergeMessages" ], mergeMessageData @ messages, messages ];
        makeHTTPRequest[ settings, merged ]
    ];

makeHTTPRequest[ settings_Association? AssociationQ, messages: { __Association } ] :=
    Enclose @ Module[
        { key, stream, model, tokens, temperature, topP, freqPenalty, presPenalty, data, body },

        $lastSettings = settings;
        $lastMessages = messages;

        key         = ConfirmBy[ Lookup[ settings, "OpenAIKey" ], StringQ ];
        (* stream      = ! TrueQ @ CloudSystem`$CloudNotebooks; *)
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
makeCurrentRole[ as_Association? AssociationQ ] := makeCurrentRole[ as, as[ "RolePrompt" ], as[ "AssistantTheme" ] ];
makeCurrentRole[ as_, None, _ ] := Missing[ ];
makeCurrentRole[ as_, role_String, _ ] := <| "role" -> "system", "content" -> role |>;
makeCurrentRole[ as_, Automatic, name_String ] := <| "role" -> "system", "content" -> namedRolePrompt @ name |>;
makeCurrentRole[ as_, _, _ ] := <| "role" -> "system", "content" -> buildSystemPrompt @ as |>;
makeCurrentRole // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buildSystemPrompt*)
buildSystemPrompt // beginDefinition;

buildSystemPrompt[ as_Association ] := TemplateApply[
    $promptTemplate,
    Association[
        $promptComponents[ "Generic" ],
    Select[
        <|
            "Pre"  -> Lookup[ as, "ChatContextPreprompt"  ],
            "Post" -> Lookup[ as, "ChatContextPostPrompt" ]
        |>,
        StringQ
    ]
    ]
];

buildSystemPrompt // endDefinition;

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

clearMinimizedChats[ nbo_, cells_ ] /; CloudSystem`$CloudNotebooks := cells;

clearMinimizedChats[ nbo_NotebookObject, cells_List ] :=
    Module[ { outCells, closed, attached },
        outCells = Cells[ nbo, CellStyle -> "ChatOutput" ];
        closed = Keys @ Select[ AssociationThread[ outCells -> CurrentValue[ outCells, CellOpen ] ], Not ];
        attached = Cells[ nbo, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ];
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
(*cellStyles*)
cellStyles // beginDefinition;
cellStyles[ cells_ ] /; CloudSystem`$CloudNotebooks := cloudCellStyles @ cells;
cellStyles[ cells_ ] := CurrentValue[ cells, CellStyle ];
cellStyles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellStyles*)
cloudCellStyles // beginDefinition;
cloudCellStyles[ cells_ ] := Cases[ notebookRead @ cells, Cell[ _, style___String, OptionsPattern[ ] ] :> { style } ];
cloudCellStyles // endDefinition;

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
] ] := role;

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
        untaggedQ @ container, openBirdCell @ cell,
        True, Null
    ]
);

writeChunk[ Dynamic[ container_ ], cell_, chunk_String, other_ ] := Null;

writeChunk // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toAPIKey*)
toAPIKey // beginDefinition;

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

toAPIKey // endDefinition;

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
            StringReplace[ ResourceFunction[ "RelativePath" ][ $promptDirectory, # ], "\\" -> "/" ],
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
$promptComponents = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Birdnardo*)
$promptComponents[ "Birdnardo" ] = <| |>;
$promptComponents[ "Birdnardo", "Pre"  ] = $promptStrings[ "Birdnardo/Pre"  ];
$promptComponents[ "Birdnardo", "Post" ] = $promptStrings[ "Birdnardo/Post" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Generic*)
$promptComponents[ "Generic" ] = <| |>;
$promptComponents[ "Generic", "Pre"  ] = $promptStrings[ "Generic/Pre" ];
$promptComponents[ "Generic", "Post" ] = "";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Wolfie*)
$promptComponents[ "Wolfie" ] = <| |>;
$promptComponents[ "Wolfie", "Pre"  ] = $promptStrings[ "Wolfie/Pre"  ];
$promptComponents[ "Wolfie", "Post" ] = $promptStrings[ "Wolfie/Post" ];

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
    Module[ { pre, post },
        pre  = $promptComponents[ name, "Pre"  ];
        post = $promptComponents[ name, "Post" ];
        ConfirmBy[
            TemplateApply[
                $promptTemplate,
                DeleteMissing @ <| "Pre" -> pre, "Post" -> post |>
            ],
            StringQ
        ]
    ],
    $defaultRolePrompt &
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
    (* TODO: Add an error icon? *)
    openBirdCell @ cell
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
    openBirdCell @ cell
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
    $lastAutoOpen = $autoOpen;
    If[ TrueQ @ $autoOpen, openBirdCell @ cell ]
);

processInfoCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*openBirdCell*)
openBirdCell // beginDefinition;

openBirdCell[ cell_CellObject ] :=
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

openBirdCell // endDefinition;

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
            tag   = CurrentValue[ cell, { TaggingRules, "MessageTag" } ],
            open  = $lastOpen = cellOpenQ @ cell,
            label = RawBoxes @ TemplateBox[ { }, "MinimizedChat" ]
        },
        Block[ { $dynamicText = False },
            NotebookWrite[
                cell,
                $reformattedCell = reformatCell[ settings, string, tag, open, label ],
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
                    $top
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

reformatCell[ settings_, string_, tag_, open_, label_ ] := UsingFrontEnd @ Cell[
    If[ TrueQ @ settings[ "AutoFormat" ],
        TextData @ reformatTextData @ string,
        TextData @ string
    ],
    "ChatOutput",
    GeneratedCell     -> True,
    CellAutoOverwrite -> True,
    TaggingRules      -> <|
        "CellToStringData" -> string,
        "MessageTag"       -> tag,
        "ChatData"         -> makeCompactChatData[ string, tag, settings ]
    |>,
    If[ TrueQ @ open,
        Sequence @@ { },
        Sequence @@ Flatten @ {
            $closedChatCellOptions,
            Initialization :> attachMinimizedIcon[ EvaluationCell[ ], label ]
        }
    ]
];

reformatCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCompactChatData*)
makeCompactChatData // beginDefinition;

makeCompactChatData[ message_, tag_, as_ ] /; CloudSystem`$CloudNotebooks := Inherited;

makeCompactChatData[
    message_,
    tag_,
    as: KeyValuePattern[ "Data" -> data: KeyValuePattern[ "Messages" -> messages_List ] ]
] :=
    BaseEncode @ BinarySerialize[
        Association[
            KeyDrop[ as, "OpenAIKey" ],
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
(* ::Subsubsection::Closed:: *)
(*reformatTextData*)
reformatTextData // beginDefinition;

reformatTextData[ string_String ] := joinAdjacentStrings @ Flatten @ Map[
    makeResultCell,
    StringSplit[
        $reformattedString = string,
        {
            StringExpression[
                    Longest[ "```" ~~ lang: Except[ WhitespaceCharacter ].. /; externalLanguageQ @ lang ],
                    Shortest[ code__ ] ~~ ("```"|EndOfString)
                ] :> externalCodeCell[ lang, code ]
            ,
            Longest[ "```" ~~ ($wlCodeString|"") ] ~~ Shortest[ code__ ] ~~ ("```"|EndOfString) :>
                If[ nameQ[ "System`"<>code ], inlineCodeCell @ code, codeCell @ code ]
            ,
            "\n" ~~ w:" "... ~~ "* " ~~ item: Longest[ Except[ "\n" ].. ] :> bulletCell[ w, item ],
            "\n" ~~ h:"#".. ~~ " " ~~ sec: Longest[ Except[ "\n" ].. ] :> sectionCell[ StringLength @ h, sec ],
            "[" ~~ label: Except[ "[" ].. ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :> hyperlinkCell[ label, url ],
            "\\`" :> "`",
            "\\$" :> "$",
            "``" ~~ code__ ~~ "``" /; StringFreeQ[ code, "``" ] :> inlineCodeCell @ code,
            "`" ~~ code: Except[ WhitespaceCharacter ].. ~~ "`" /; inlineSyntaxQ @ code :> inlineCodeCell @ code,
            "`" ~~ code: Except[ "`" ].. ~~ "`" :> inlineCodeCell @ code,
            "$$" ~~ math: Except[ "$" ].. ~~ "$$" :> mathCell @ math,
            "$" ~~ math: Except[ "$" ].. ~~ "$" :> mathCell @ math
        },
        IgnoreCase -> True
    ]
];

reformatTextData[ other_ ] := other;

reformatTextData // endDefinition;


$wlCodeString = Longest @ Alternatives[
    "Wolfram Language",
    "WolframLanguage",
    "Wolfram",
    "Mathematica"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineSyntaxQ*)
inlineSyntaxQ[ s_String ] := ! StringStartsQ[ s, "`" ] && Internal`SymbolNameQ[ unescapeInlineMarkdown @ s<>"x", True ];
inlineSyntaxQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*joinAdjacentStrings*)
joinAdjacentStrings // beginDefinition;
joinAdjacentStrings[ content_List ] := joinAdjacentStrings0 /@ SplitBy[ content, StringQ ];
joinAdjacentStrings // endDefinition;

joinAdjacentStrings0 // beginDefinition;

joinAdjacentStrings0[ { strings__String } ] :=
    StringReplace[ StringJoin @ strings, c: Except[ "\n" ]~~"\n"~~EndOfString :> c<>" \n" ];

joinAdjacentStrings0[ { other___ } ] := other;

joinAdjacentStrings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*nameQ*)
nameQ[ "*"|"**" ] := False;
nameQ[ s_String? StringQ ] := StringFreeQ[ s, Verbatim[ "*" ] | Verbatim[ "@" ] ] && NameQ @ s;
nameQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*externalLanguageQ*)
externalLanguageQ // ClearAll;

externalLanguageQ[ $$externalLanguage ] := True;

externalLanguageQ[ str_String? StringQ ] := externalLanguageQ[ str ] =
    StringMatchQ[
        StringReplace[ StringTrim @ str, $externalLanguageRules, IgnoreCase -> True ],
        $$externalLanguage,
        IgnoreCase -> True
    ];

externalLanguageQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellOpenQ*)
cellOpenQ // beginDefinition;
cellOpenQ[ cell_CellObject ] /; CloudSystem`$CloudNotebooks := Lookup[ Options[ cell, CellOpen ], CellOpen, True ];
cellOpenQ[ cell_CellObject ] := CurrentValue[ cell, CellOpen ];
cellOpenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeResultCell*)
makeResultCell // beginDefinition;

makeResultCell[ expr_ ] /; $dynamicText :=
    Lookup[ $resultCellCache,
            HoldComplete @ expr,
            $resultCellCache[ HoldComplete @ expr ] = makeResultCell0 @ expr
    ];

makeResultCell[ expr_ ] := makeResultCell0 @ expr;

makeResultCell // endDefinition;


$resultCellCache = <| |>;


makeResultCell0 // beginDefinition;

makeResultCell0[ str_String ] := formatTextString @ str;

makeResultCell0[ codeCell[ code_String ] ] := makeInteractiveCodeCell @ StringTrim @ code;

makeResultCell0[ externalCodeCell[ lang_String, code_String ] ] :=
    makeInteractiveCodeCell[
        StringReplace[ StringTrim @ lang, $externalLanguageRules, IgnoreCase -> True ],
        StringTrim @ code
    ];

makeResultCell0[ inlineCodeCell[ code_String ] ] := makeInlineCodeCell @ code;

makeResultCell0[ mathCell[ math_String ] ] :=
    With[ { boxes = Quiet @ InputAssistant`TeXAssistant @ StringTrim @ math },
        If[ MatchQ[ boxes, _RawBoxes ],
            Cell @ BoxData @ FormBox[ ToBoxes @ boxes, TraditionalForm ],
            makeResultCell0 @ inlineCodeCell @ math
        ]
    ];

makeResultCell0[ hyperlinkCell[ label_String, url_String ] ] := hyperlink[ label, url ];

makeResultCell0[ bulletCell[ whitespace_String, item_String ] ] := Flatten @ {
    $tinyLineBreak,
    whitespace,
    StyleBox[ "\[Bullet]", FontColor -> GrayLevel[ 0.5 ] ],
    " ",
    reformatTextData @ item,
    $tinyLineBreak
};

makeResultCell0[ sectionCell[ n_, section_String ] ] := Flatten @ {
    "\n",
    StyleBox[ formatTextString @ section, sectionStyle @ n, "InlineSection", FontSize -> .8*Inherited ],
    $tinyLineBreak
};

makeResultCell0 // endDefinition;


sectionStyle[ 1 ] := "Section";
sectionStyle[ 2 ] := "Subsection";
sectionStyle[ 3 ] := "Subsubsection";
sectionStyle[ 4 ] := "Subsubsubsection";
sectionStyle[ _ ] := "Subsubsubsubsection";

$tinyLineBreak = StyleBox[ "\n", "TinyLineBreak", FontSize -> 3 ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatTextString*)
formatTextString // beginDefinition;

formatTextString[ str_String ] := StringSplit[
    StringReplace[ str, { StartOfString~~"\n\n" -> "\n", "\n\n"~~EndOfString -> "\n" } ],
    $stringFormatRules,
    IgnoreCase -> True
];

formatTextString // endDefinition;

$stringFormatRules = {
    "[" ~~ label: Except[ "[" ].. ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :> hyperlink[ label, url ],
    "***" ~~ text: Except[ "*" ].. ~~ "***" :> styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],
    "___" ~~ text: Except[ "_" ].. ~~ "___" :> styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],
    "**" ~~ text: Except[ "*" ].. ~~ "**" :> styleBox[ text, FontWeight -> Bold ],
    "__" ~~ text: Except[ "_" ].. ~~ "__" :> styleBox[ text, FontWeight -> Bold ],
    "*" ~~ text: Except[ "*" ].. ~~ "*" :> styleBox[ text, FontSlant -> Italic ],
    "_" ~~ text: Except[ "_" ].. ~~ "_" :> styleBox[ text, FontSlant -> Italic ]
};

styleBox // ClearAll;

styleBox[ text_String, a___ ] := styleBox[ formatTextString @ text, a ];
styleBox[ { text: _ButtonBox|_String }, a___ ] := StyleBox[ text, a ];
styleBox[ { (h: Cell|StyleBox)[ text_, a___ ] }, b___ ] := DeleteDuplicates @ StyleBox[ text, a, b ];

styleBox[ { a___, b: Except[ _ButtonBox|_Cell|_String|_StyleBox ], c___ }, d___ ] :=
    styleBox[ { a, Cell @ BoxData @ b, c }, d ];

styleBox[ a_, ___ ] := a;


hyperlink // ClearAll;

hyperlink[ label_String, uri_String ] /; StringStartsQ[ uri, "paclet:" ] :=
    Cell @ BoxData @ TemplateBox[ { StringTrim[ label, (Whitespace|"`").. ], uri }, "TextRefLink" ];

hyperlink[ label_String, url_String ] := hyperlink[ formatTextString @ label, url ];

hyperlink[ { label: _String|_StyleBox }, url_ ] := ButtonBox[
    label,
    BaseStyle  -> "Hyperlink",
    ButtonData -> { URL @ url, None },
    ButtonNote -> url
];

hyperlink[ a_, ___ ] := a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInlineCodeCell*)
makeInlineCodeCell // beginDefinition;

makeInlineCodeCell[ s_String? nameQ ] /; Context @ s === "System`" :=
    hyperlink[ s, "paclet:ref/" <> Last @ StringSplit[ s, "`" ] ];

makeInlineCodeCell[ s_String? LowerCaseQ ] := StyleBox[ unescapeInlineMarkdown @ s, "TI" ];

makeInlineCodeCell[ code_String ] /; $dynamicText := Cell[
    BoxData @ TemplateBox[ { stringToBoxes @ unescapeInlineMarkdown @ code }, "ChatCodeInlineTemplate" ],
    "ChatCodeActive"
];

makeInlineCodeCell[ code0_String ] :=
    With[ { code = unescapeInlineMarkdown @ code0 },
        If[ SyntaxQ @ code,
            Cell[
                BoxData @ TemplateBox[ { stringToBoxes @ code }, "ChatCodeInlineTemplate" ],
                "ChatCode",
                Background -> GrayLevel[ 1 ]
            ],
            Cell[
                BoxData @ TemplateBox[ { Cell[ code, Background -> GrayLevel[ 1 ] ] }, "ChatCodeInlineTemplate" ],
                "ChatCodeActive",
                Background -> GrayLevel[ 1 ]
            ]
        ]
    ];

makeInlineCodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unescapeInlineMarkdown*)
unescapeInlineMarkdown // beginDefinition;
unescapeInlineMarkdown[ str_String ] := StringReplace[ str, { "\\`" -> "`", "\\$" -> "$" } ];
unescapeInlineMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInteractiveCodeCell*)
makeInteractiveCodeCell // beginDefinition;

(* TODO: define template boxes for these *)
makeInteractiveCodeCell[ string_String ] /; $dynamicText :=
    codeBlockFrame[ Cell[ BoxData @ string, "ChatCodeActive" ], string ];

makeInteractiveCodeCell[ string_String ] :=
    Module[ { display, handler },
        display = RawBoxes @ Cell[
            BoxData @ stringToBoxes @ string,
            "ChatCode",
            "Input",
            Background -> GrayLevel[ 1 ]
        ];
        handler = inlineInteractiveCodeCell[ display, string ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, string ]
    ];

makeInteractiveCodeCell[ lang_String, code_String ] :=
    Module[ { cell, display, handler },
        cell = Cell[ code, "ExternalLanguage", FontSize -> 14, System`CellEvaluationLanguage -> lang ];
        display = RawBoxes @ Cell[
            code,
            "ExternalLanguage",
            System`CellEvaluationLanguage -> lang,
            FontSize   -> 14,
            Background -> None,
            CellFrame  -> None
        ];
        handler = inlineInteractiveCodeCell[ display, cell ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, code, lang ]
    ];

makeInteractiveCodeCell // endDefinition;


codeBlockFrame[ cell_, string_ ] := codeBlockFrame[ cell, string, "Wolfram" ];

codeBlockFrame[ cell_, string_, lang_ ] :=
    Cell[
        BoxData @ TemplateBox[ { cell }, "ChatCodeBlockTemplate" ],
        "ChatCodeBlock",
        Background -> None
    ];


inlineInteractiveCodeCell // beginDefinition;

inlineInteractiveCodeCell[ display_, string_ ] /; $dynamicText := display;

inlineInteractiveCodeCell[ display_, string_String ] /; CloudSystem`$CloudNotebooks :=
    Button[ display, CellPrint @ Cell[ BoxData @ string, "Input" ], Appearance -> None ];

inlineInteractiveCodeCell[ display_, cell_Cell ] /; CloudSystem`$CloudNotebooks :=
    Button[ display, CellPrint @ cell, Appearance -> None ];

inlineInteractiveCodeCell[ display_, string_ ] :=
    inlineInteractiveCodeCell[ display, string, contentLanguage @ string ];

inlineInteractiveCodeCell[ display_, string_, lang_ ] :=
    DynamicModule[ { $CellContext`attached },
        EventHandler[
            display,
            {
                "MouseEntered" :> (
                    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "AttachCodeButtons",
                        Dynamic[ $CellContext`attached ],
                        EvaluationCell[ ],
                        string,
                        lang
                    ]
                )
            }
        ],
        TaggingRules -> <| "CellToStringType" -> "InlineInteractiveCodeCell", "CodeLanguage" -> lang |>,
        UnsavedVariables :> { $CellContext`attached }
    ];

inlineInteractiveCodeCell // endDefinition;


floatingButtonGrid // Attributes = { HoldFirst };
floatingButtonGrid[ attached_, string_, lang_ ] := RawBoxes @ TemplateBox[
    {
        ToBoxes @ Grid[
            {
                {
                    button[ evaluateLanguageLabel @ lang, insertCodeBelow[ string, True ]; NotebookDelete @ attached ],
                    button[ $insertInputButtonLabel, insertCodeBelow[ string, False ]; NotebookDelete @ attached ],
                    button[ $copyToClipboardButtonLabel, NotebookDelete @ attached; CopyToClipboard @ string ]
                }
            },
            Alignment -> Top,
            Spacings -> 0.2,
            FrameStyle -> GrayLevel[ 0.85 ]
        ]
    },
    "ChatCodeBlockButtonPanel"
];

insertCodeBelow[ cell_Cell, evaluate_: False ] :=
    Module[ { cellObj, nbo },
        cellObj = topParentCell @ EvaluationCell[ ];
        nbo  = parentNotebook @ cellObj;
        SelectionMove[ cellObj, After, Cell ];
        NotebookWrite[ nbo, cell, All ];
        If[ TrueQ @ evaluate,
            SelectionEvaluateCreateCell @ nbo,
            SelectionMove[ nbo, After, CellContents ]
        ]
    ];

insertCodeBelow[ string_String, evaluate_: False ] := insertCodeBelow[ Cell[ BoxData @ string, "Input" ], evaluate ];


(* FIXME: move this stuff to the stylesheet *)

$copyToClipboardButtonLabel := $copyToClipboardButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ TemplateBox[ { }, "AssistantCopyClipboard" ],
            buttonFrameActive @ RawBoxes @ TemplateBox[ { }, "AssistantCopyClipboard" ]
        ],
        "LinkHand"
    ],
    "Copy to clipboard"
];

$insertInputButtonLabel := $insertInputButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ TemplateBox[ { }, "AssistantCopyBelow" ],
            buttonFrameActive @ RawBoxes @ TemplateBox[ { }, "AssistantCopyBelow" ]
        ],
        "LinkHand"
    ],
    "Insert content as new input cell below"
];

$insertEvaluateButtonLabel := $insertEvaluateButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ],
            buttonFrameActive @ RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ]
        ],
        "LinkHand"
    ],
    "Insert content as new input cell below and evaluate"
];


evaluateLanguageLabel // ClearAll;

evaluateLanguageLabel[ name_String ] :=
    With[ { icon = $languageIcons @ name },
        fancyTooltip[
            MouseAppearance[ buttonMouseover[ buttonFrameDefault @ icon, buttonFrameActive @ icon ], "LinkHand" ],
            "Insert content as new input cell below and evaluate"
        ] /; MatchQ[ icon, _Graphics | _Image ]
    ];

evaluateLanguageLabel[ ___ ] := $insertEvaluateButtonLabel;



$languageIcons := $languageIcons = Enclose[
    ExternalEvaluate;
    Select[
        AssociationMap[
            ReleaseHold @ ExternalEvaluate`Private`GetLanguageRules[ #1, "Icon" ] &,
            ConfirmMatch[ ExternalEvaluate`Private`GetLanguageRules[ ], _List ]
        ],
        MatchQ[ _Graphics|_Image ]
    ],
    <| |> &
];


buttonMouseover[ a_, b_ ] := Mouseover[ a, b ];

buttonFrameDefault[ expr_ ] :=
    Framed[
        buttonPane @ expr,
        FrameStyle     -> GrayLevel[ 0.95 ],
        Background     -> GrayLevel[ 1 ],
        FrameMargins   -> 0,
        RoundingRadius -> 2
    ];

buttonFrameActive[ expr_ ] :=
    Framed[
        buttonPane @ expr,
        FrameStyle     -> GrayLevel[ 0.82 ],
        Background     -> GrayLevel[ 1 ],
        FrameMargins   -> 0,
        RoundingRadius -> 2
    ];

buttonPane[ expr_ ] :=
    Pane[ expr, ImageSize -> { 24, 24 }, ImageSizeAction -> "ShrinkToFit", Alignment -> { Center, Center } ];

fancyTooltip[ expr_, tooltip_ ] := Tooltip[
    expr,
    Framed[
        Style[
            tooltip,
            "Text",
            FontColor    -> RGBColor[ 0.53725, 0.53725, 0.53725 ],
            FontSize     -> 12,
            FontWeight   -> "Plain",
            FontTracking -> "Plain"
        ],
        Background   -> RGBColor[ 0.96078, 0.96078, 0.96078 ],
        FrameStyle   -> RGBColor[ 0.89804, 0.89804, 0.89804 ],
        FrameMargins -> 8
    ],
    TooltipDelay -> 0.15,
    TooltipStyle -> { Background -> None, CellFrame -> 0 }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*contentLanguage*)
contentLanguage // ClearAll;
contentLanguage[ Cell[ __, "CellEvaluationLanguage" -> lang_String, ___ ] ] := lang;
contentLanguage[ Cell[ __, System`CellEvaluationLanguage -> lang_String, ___ ] ] := lang;
contentLanguage[ ___ ] := "Wolfram";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FrontEnd Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellInformation*)
cellInformation // beginDefinition;

cellInformation[ nbo_NotebookObject ] := cellInformation @ Cells @ nbo;

cellInformation[ cells: { ___CellObject } ] := Map[
    Association,
    Transpose @ {
        Thread[ "CellObject" -> cells ],
        Developer`CellInformation @ cells,
        Thread[ "CellAutoOverwrite" -> CurrentValue[ cells, CellAutoOverwrite ] ]
    }
];

cellInformation[ cell_CellObject ] := Association[
    "CellObject" -> cell,
    Developer`CellInformation @ cell,
    "CellAutoOverwrite" -> CurrentValue[ cell, CellAutoOverwrite ]
];

cellInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*button*)
button // Attributes = { HoldRest };
button[ label_, code_ ] :=
    Button[
        label,
        code,
        Appearance -> Dynamic @ FEPrivate`FrontEndResource[ "FEExpressions", "SuppressMouseDownNinePatchAppearance" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stringTemplateInput*)
(* TODO: use something simpler/faster *)

stringTemplateInput // ClearAll;

stringTemplateInput[ s_String? StringQ ] := stringToBoxes @ s;

stringTemplateInput[ ___ ] := $Failed;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stringToBoxes*)
stringToBoxes // beginDefinition;
stringToBoxes[ s_String ] /; $dynamicText := s;
stringToBoxes[ s_String ] := removeExtraBoxSpaces @ MathLink`CallFrontEnd @ FrontEnd`ReparseBoxStructurePacket @ s;
stringToBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeExtraBoxSpaces*)
removeExtraBoxSpaces // beginDefinition;
removeExtraBoxSpaces[ row: RowBox @ { "(*", ___, "*)" } ] := row;
removeExtraBoxSpaces[ RowBox[ items_List ] ] := RowBox[ removeExtraBoxSpaces /@ DeleteCases[ items, " " ] ];
removeExtraBoxSpaces[ other_ ] := other;
removeExtraBoxSpaces // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*topParentCell*)
topParentCell // beginDefinition;
topParentCell[ cell_CellObject ] := With[ { p = ParentCell @ cell }, topParentCell @ p /; MatchQ[ p, _CellObject ] ];
topParentCell[ cell_CellObject ] := cell;
topParentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookRead*)
notebookRead // beginDefinition;
notebookRead[ cells_ ] /; CloudSystem`$CloudNotebooks := cloudNotebookRead @ cells;
notebookRead[ cells_ ] := NotebookRead @ cells;
notebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookRead*)
cloudNotebookRead // beginDefinition;
cloudNotebookRead[ cells: { ___CellObject } ] := NotebookRead /@ cells;
cloudNotebookRead[ cell_ ] := NotebookRead @ cell;
cloudNotebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parentNotebook*)
parentNotebook // beginDefinition;
parentNotebook[ cell_CellObject ] /; CloudSystem`$CloudNotebooks := Notebooks @ cell;
parentNotebook[ cell_CellObject ] := ParentNotebook @ cell;
parentNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellPrintAfter*)
cellPrintAfter // ClearAll;

cellPrintAfter[ target_ ][ cell_ ] := cellPrintAfter[ target, cell ];

cellPrintAfter[ target_CellObject, cell: Cell[ __, ExpressionUUID -> uuid_, ___ ] ] := (
    SelectionMove[ target, After, Cell, AutoScroll -> False ];
    NotebookWrite[ parentNotebook @ target, cell ];
    CellObject @ uuid
);

cellPrintAfter[ target_CellObject, cell_Cell ] :=
    cellPrintAfter[ target, Append[ cell, ExpressionUUID -> CreateUUID[ ] ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellPrint*)
cellPrint // beginDefinition;
cellPrint[ cell_Cell ] /; CloudSystem`$CloudNotebooks := cloudCellPrint @ cell;
cellPrint[ cell_Cell ] := MathLink`CallFrontEnd @ FrontEnd`CellPrintReturnObject @ cell;
cellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellPrint*)
cloudCellPrint // beginDefinition;

cloudCellPrint[ cell0_Cell ] :=
    Enclose @ Module[ { cellUUID, nbUUID, cell },
        cellUUID = CreateUUID[ ];
        nbUUID   = ConfirmBy[ cloudNotebookUUID[ ], StringQ ];
        cell     = Append[ DeleteCases[ cell0, ExpressionUUID -> _ ], ExpressionUUID -> cellUUID ];
        CellPrint @ cell;
        CellObject[ cellUUID, nbUUID ]
    ];

cloudCellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookUUID*)
cloudNotebookUUID // beginDefinition;
cloudNotebookUUID[ ] := cloudNotebookUUID[ EvaluationNotebook[ ] ];
cloudNotebookUUID[ NotebookObject[ _, uuid_String ] ] := uuid;
cloudNotebookUUID // endDefinition;

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
        With[ { attached = EvaluationCell[ ] }, NotebookDelete @ attached; openBirdCell @ chatCell ],
        Appearance -> None
    ],
    "MinimizedChatIcon"
];

makeMinimizedIconCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Error Handling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchTop*)
catchTop // beginDefinition;
catchTop // Attributes = { HoldFirst };
catchTop[ eval_ ] := Block[ { $catching = True, $failed = False, catchTop = #1 & }, Catch[ eval, $top ] ];
catchTop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*throwFailure*)
throwFailure // beginDefinition;
throwFailure // Attributes = { HoldFirst };

throwFailure[ tag_String, params___ ] :=
    throwFailure[ MessageName[ ChatbookAction, tag ], params ];

throwFailure[ msg_, args___ ] :=
    Module[ { failure },
        failure = messageFailure[ msg, Sequence @@ HoldForm /@ { args } ];
        If[ TrueQ @ $catching,
            Throw[ failure, $top ],
            failure
        ]
    ];

throwFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*messageFailure*)
messageFailure // beginDefinition;
messageFailure // Attributes = { HoldFirst };

messageFailure[ args___ ] :=
    Module[ { quiet },
        quiet = If[ TrueQ @ $failed, Quiet, Identity ];
        WithCleanup[
            StackInhibit @ quiet @ messageFailure0[ args ],
            $failed = True
        ]
    ];

messageFailure // endDefinition;

messageFailure0 := messageFailure0 = ResourceFunction[ "MessageFailure", "Function" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*throwInternalFailure*)
throwInternalFailure // beginDefinition;
throwInternalFailure // Attributes = { HoldFirst };

throwInternalFailure[ eval_, a___ ] :=
    Block[ { $internalFailure = HoldForm @ eval },
        throwFailure[ ChatbookAction::Internal, $bugReportLink, $internalFailure, a ]
    ];

throwInternalFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$bugReportLink*)
$bugReportLink := Hyperlink[
    "Report this issue \[RightGuillemet]",
    URLBuild @ <|
        "Scheme"   -> "https",
        "Domain"   -> "github.com",
        "Path"     -> { "ConnorGray", "Chatbook", "issues", "new" },
        "Query"    -> {
            "title"  -> "[Chatbook] Insert Title Here",
            "body"   -> bugReportBody[ ],
            "labels" -> "bug"
        }
    |>
];

bugReportBody[ ] := bugReportBody @ PacletObject[ "Wolfram/Chatbook" ][ "PacletInfo" ];

bugReportBody[ as_Association? AssociationQ ] := TemplateApply[
    $bugReportBodyTemplate,
    Association[
        as,
        "SystemID"              -> $SystemID,
        "KernelVersion"         -> SystemInformation[ "Kernel"  , "Version" ],
        "FrontEndVersion"       -> $frontEndVersion,
        "Notebooks"             -> $Notebooks,
        "EvaluationEnvironment" -> $EvaluationEnvironment,
        "Stack"                 -> $bugReportStack,
        "Settings"              -> $settings,
        "InternalFailure"       -> internalFailureString @ $internalFailure
    ]
];

internalFailureString[ HoldForm[ fail_ ] ] := internalFailureString @ Unevaluated @ fail;
internalFailureString[ fail_ ] := StringTake[ ToString[ Unevaluated @ fail, InputForm ], UpTo[ 200 ] ];


$frontEndVersion :=
    If[ TrueQ @ CloudSystem`$CloudNotebooks,
        Row @ { "Cloud: ", $CloudVersion },
        Row @ { "Desktop: ", UsingFrontEnd @ SystemInformation[ "FrontEnd", "Version" ] }
    ];


$settings :=
    Module[ { settings, assoc },
        settings = CurrentValue @ { TaggingRules, "ChatNotebookSettings" };
        assoc = Association @ settings;
        If[ AssociationQ @ assoc,
            ToString @ ResourceFunction[ "ReadableForm" ][ KeyDrop[ assoc, "OpenAIKey" ], "DynamicAlignment" -> True ],
            settings
        ]
    ];


$bugReportBodyTemplate = StringTemplate[ "\
# Description
Describe the issue in detail here.

# Debug Data
| Property | Value |
| --- | --- |
| Name | `%%Name%%` |
| Version | `%%Version%%` |
| KernelVersion | `%%KernelVersion%%` |
| FrontEndVersion | `%%FrontEndVersion%%` |
| Notebooks | `%%Notebooks%%` |
| EvaluationEnvironment | `%%EvaluationEnvironment%%` |
| SystemID | `%%SystemID%%` |

## Settings
```
%%Settings%%
```

## Stack Data
```
%%Stack%%
```

## Failure Expression
```
%%InternalFailure%%
```
",
Delimiters -> "%%"
];


$bugReportStack := StringRiffle[
    Replace[
        DeleteAdjacentDuplicates @ Cases[
            Stack[ _ ],
            HoldForm[ (s_Symbol) | (s_Symbol)[ ___ ] | (s_Symbol)[ ___ ][ ___ ] ] /; AtomQ @ Unevaluated @ s :>
                SymbolName @ Unevaluated @ s
        ],
        { a___, "throwInternalFailure", ___ } :> { a, "throwInternalFailure" }
    ],
    "\n"
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    $chatContextDialogButtons;
    $chatContextDialogTemplateCells;
    $chatContextDialogStyles;
    $apiKeyDialogDescription;
    $promptStrings;
    $copyToClipboardButtonLabel;
    $insertInputButtonLabel;
    $insertEvaluateButtonLabel;
    $languageIcons;
];

End[ ];
EndPackage[ ];
