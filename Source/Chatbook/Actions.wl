(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Actions`" ];

`AskChat;
`ExclusionToggle;
`SendChat;
`WidgetSend;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"               ];
Needs[ "Wolfram`Chatbook`ErrorUtils`"    ];
Needs[ "Wolfram`Chatbook`Serialization`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

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

$closedChatCellOptions = Sequence[
    CellMargins     -> -2,
    CellOpen        -> False,
    CellFrame       -> 0,
    ShowCellBracket -> False
];

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
ChatbookAction // beginDefinition;

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

ChatbookAction[ "Ask"            , args___ ] := catchTop @ AskChat @ args;
ChatbookAction[ "Send"           , args___ ] := catchTop @ SendChat @ args;
ChatbookAction[ "WidgetSend"     , args___ ] := catchTop @ WidgetSend @ args;
ChatbookAction[ "ExclusionToggle", args___ ] := catchTop @ ExclusionToggle @ args;

ChatbookAction // endDefinition;

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
    Block[ { $alwaysOpen = True, cellPrint = cellPrintAfter @ cell },
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

SendChat[ evalCell_CellObject, nbo_NotebookObject ] :=
    SendChat[ evalCell, nbo, Association @ CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings" } ] ];

SendChat[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    SendChat[ evalCell, nbo, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] /; CloudSystem`$CloudNotebooks :=
    SendChat[ evalCell, nbo, settings, False ];

SendChat[ evalCell_, nbo_, settings_, Automatic ] :=
    Block[ { $autoOpen, $alwaysOpen = $alwaysOpen },
        $autoOpen = MemberQ[
            CurrentValue[ evalCell, CellStyle ],
            "Text"|"ChatInput"|"ChatQuery"|"ChatSystemInput"
        ];
        $alwaysOpen = TrueQ @ $alwaysOpen || $autoOpen;
        sendChat[ evalCell, nbo, settings ]
    ];

SendChat[ evalCell_, nbo_, settings_, minimized_ ] :=
    Block[ { $alwaysOpen = alwaysOpenQ[ settings, minimized ] },
        sendChat[ evalCell, nbo, settings ]
    ];

SendChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sendChat*)
sendChat // beginDefinition;

sendChat[ evalCell_, nbo_, settings_ ] := catchTop @ Enclose[
    Module[ { id, key, cell, cellObject, container, req, task },
        id   = Lookup[ settings, "ID" ];
        key  = toAPIKey[ Automatic, id ];

        If[ ! StringQ @ key, throwFailure[ "NoAPIKey" ] ];

        req = ConfirmMatch[ makeHTTPRequest[ Append[ settings, "OpenAIKey" -> key ], nbo, evalCell ], _HTTPRequest ];

        container = ProgressIndicator[ Appearance -> "Percolate" ];
        cell = activeAIAssistantCell[ container, settings ];

        Quiet[
            TaskRemove @ $lastTask;
            NotebookDelete @ $lastCellObject;
        ];

        $resultCellCache = <| |>;
        $debugLog = Internal`Bag[ ];
        cellObject = $lastCellObject = cellPrint @ cell;

        task = Confirm[ $lastTask = submitAIAssistant[ container, req, cellObject, settings ] ]
    ],
    throwInternalFailure[ sendChat[ evalCell, nbo, settings ], ## ] &
];

sendChat // endDefinition;

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

submitAIAssistant[ container_, req_, cellObject_, settings_ ] /; CloudSystem`$CloudNotebooks := Enclose[
    Module[ { resp, code, json, text },
        resp = ConfirmMatch[ URLRead @ req, _HTTPResponse ];
        code = ConfirmBy[ resp[ "StatusCode" ], IntegerQ ];
        ConfirmAssert[ resp[ "ContentType" ] === "application/json" ];
        json = Developer`ReadRawJSONString @ resp[ "Body" ];
        text = $lastMessageText = extractMessageText @ json;
        checkResponse[ settings, text, cellObject, json ]
    ],
    # & (* TODO: cloud error cell *)
];

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

activeAIAssistantCell[ container_, settings_ ] /; CloudSystem`$CloudNotebooks := (
    Cell[
        BoxData @ ToBoxes @ ProgressIndicator[ Appearance -> "Percolate" ],
        "ChatOutput",
        CellDingbat -> Cell[ BoxData @ TemplateBox[ { }, "AssistantIconActive" ], Background -> None ]
    ]
);

activeAIAssistantCell[ container_, settings_Association? AssociationQ ] :=
    activeAIAssistantCell[ container, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

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
            If[ MatchQ[ minimized, True|Automatic ],
                Sequence @@ Flatten[ {
                    $closedChatCellOptions,
                    Initialization :> attachMinimizedIcon[ EvaluationCell[ ], label ]
                } ],
                Sequence @@ { }
            ],
            Selectable  -> False,
            Editable    -> False,
            CellDingbat -> Cell[ BoxData @ TemplateBox[ { }, "AssistantIconActive" ], Background -> None ]
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
    Module[ { log, body, data },
        log  = Internal`BagPart[ $debugLog, All ];
        body = StringJoin @ Cases[ log, KeyValuePattern[ "BodyChunk" -> s_String ] :> s ];
        data = Replace[ Quiet @ Developer`ReadRawJSONString @ body, $Failed -> Missing[ "NotAvailable" ] ];
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
        TextData @ { errorText @ as, "\n\n", Cell @ BoxData @ errorBoxes @ as },
        "Text",
        "Message",
        "ChatOutput",
        GeneratedCell -> True,
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
        stream      = ! TrueQ @ CloudSystem`$CloudNotebooks;

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
makeCurrentRole[ as_, _, _ ] := $defaultRole;
makeCurrentRole // endDefinition;

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
            "content" -> StringRiffle[ strings, "\n\n" ]
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
        $selectedChatCells = selectChatCells0[ cell, nbo ]
    ];

selectChatCells // endDefinition;


selectChatCells0 // beginDefinition;

selectChatCells0[ cell_, nbo_NotebookObject ] :=
    selectChatCells0[ cell, Cells @ nbo ];

selectChatCells0[ cell_, { cells___, cell_, trailing0___ } ] :=
    Module[ { trailing, include, styles, delete, included, flat, filtered },
        trailing = { trailing0 };
        include = Keys @ TakeWhile[ AssociationThread[ trailing -> CurrentValue[ trailing, GeneratedCell ] ], TrueQ ];
        styles = cellStyles @ include;
        delete = Keys @ Select[ AssociationThread[ include -> MemberQ[ "ChatOutput" ] /@ styles ], TrueQ ];
        NotebookDelete @ delete;
        included = DeleteCases[ include, Alternatives @@ delete ];
        flat = dropDelimitedCells @ Flatten @ { cells, cell, included };
        filtered = dropExcludedCells @ clearMinimizedChats[ parentNotebook @ cell, flat ];
        Reverse @ Take[ Reverse @ filtered, UpTo @ $maxChatCells ]
    ];

selectChatCells0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dropExcludedCells*)
dropExcludedCells // beginDefinition;

dropExcludedCells[ cells_List ] :=
    Module[ { styles },
        styles = cellStyles @ cells;
        Keys @ Select[ AssociationThread[ cells -> MemberQ[ "ChatExcluded" ] /@ styles ], Not@*TrueQ ]
    ];

dropExcludedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clearMinimizedChats*)
clearMinimizedChats // beginDefinition;

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
        SystemCredential[ "OPENAI_API_KEY" ],
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

        If[ result[ "Save" ], SystemCredential[ "OPENAI_API_KEY" ] = key ];

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
    PacletObject[ "Wolfram/LLMTools" ][ "AssetLocation", "AIAssistant" ],
    "APIKeyDialogDescription.wl"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)

$promptDirectory := $promptDirectory = FileNameJoin @ {
    PacletObject[ "Wolfram/LLMTools" ][ "AssetLocation", "AIAssistant" ],
    "Prompts"
};

$promptStrings := $promptStrings = Association @ Map[
    Function[
        StringDelete[
            StringReplace[ ResourceFunction[ "RelativePath" ][ $promptDirectory, # ], "\\" -> "/" ],
            ".md"~~EndOfString
        ] -> ByteArrayToString @ ReadByteArray @ #
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

getModelList[ hash_, KeyValuePattern[ "error" -> as: KeyValuePattern[ "message" -> message_ ] ] ] :=
    throwFailure[ ChatbookAction::BadResponseMessage, message, as ];

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

reformatCell[ settings_, string_, tag_, open_, label_ ] := Cell[
    If[ TrueQ @ settings[ "AutoFormat" ],
        TextData @ reformatTextData @ string,
        TextData @ string
    ],
    "ChatOutput",
    GeneratedCell     -> True,
    CellAutoOverwrite -> True,
    TaggingRules      -> <| "CellToStringData" -> string, "MessageTag" -> tag |>,
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
(*reformatTextData*)
reformatTextData // beginDefinition;

reformatTextData[ string_String ] := Flatten @ Map[
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
                If[ NameQ[ "System`"<>code ], inlineCodeCell @ code, codeCell @ code ]
            ,
            "[" ~~ label: Except[ "[" ].. ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :> hyperlinkCell[ label, url ],
            "``" ~~ code: Except[ "`" ].. ~~ "``" :> inlineCodeCell @ code,
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

makeResultCell0[ inlineCodeCell[ code_String ] ] := Cell[
    BoxData @ stringTemplateInput @ code,
    "InlineFormula",
    FontFamily -> "Source Sans Pro"
];

makeResultCell0[ mathCell[ math_String ] ] :=
    With[ { boxes = Quiet @ InputAssistant`TeXAssistant @ StringTrim @ math },
        If[ MatchQ[ boxes, _RawBoxes ],
            Cell @ BoxData @ FormBox[ ToBoxes @ boxes, TraditionalForm ],
            makeResultCell0 @ inlineCodeCell @ math
        ]
    ];

makeResultCell0[ hyperlinkCell[ label_String, url_String ] ] := hyperlink[ label, url ];

makeResultCell0 // endDefinition;

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

hyperlink[ label_String, uri_String ] /; StringStartsQ[ uri, "paclet:" ] := Cell[
    BoxData @ TemplateBox[ { StringTrim[ label, (Whitespace|"`").. ], uri }, "TextRefLink" ],
    "InlineFormula",
    FontFamily -> "Source Sans Pro"
];

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
(*makeInteractiveCodeCell*)
makeInteractiveCodeCell // beginDefinition;

makeInteractiveCodeCell[ string_String ] /; $dynamicText :=
    codeBlockFrame[
        Cell[
            BoxData @ string,
            "Input",
            FontSize             -> 14,
            ShowAutoStyles       -> False,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True,
            LanguageCategory     -> "Input"
        ],
        string
    ];

makeInteractiveCodeCell[ string_String ] :=
    Module[ { display, handler },

        display = RawBoxes @ Cell[
            BoxData @ string,
            "Input",
            FontSize             -> 14,
            ShowAutoStyles       -> True,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True,
            LanguageCategory     -> "Input"
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
        BoxData @ FrameBox[
            cell,
            Background   -> GrayLevel[ 1 ],
            FrameMargins -> { { 10, 10 }, { 6, 6 } },
            FrameStyle   -> Directive[ AbsoluteThickness[ 1 ], GrayLevel[ 0.92941 ] ],
            ImageMargins -> { { 0, 0 }, { 8, 8 } },
            ImageSize    -> { Full, Automatic }
        ],
        "ChatCodeBlock",
        TaggingRules -> <| "CodeLanguage" -> lang |>
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
    DynamicModule[ { attached },
        EventHandler[
            display,
            {
                "MouseEntered" :> (
                    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                    (* TODO: create a ChatbookAction for this *)
                    attached = AttachCell[
                        EvaluationCell[ ],
                        floatingButtonGrid[ attached, string, lang ],
                        { Left, Bottom },
                        0,
                        { Left, Center },
                        RemovalConditions -> { "MouseClickOutside", "MouseExit" }
                    ]
                )
            }
        ],
        TaggingRules -> <| "CellToStringData" -> string |>
    ];

inlineInteractiveCodeCell // endDefinition;


floatingButtonGrid // Attributes = { HoldFirst };
floatingButtonGrid[ attached_, string_, lang_ ] := Framed[
    Grid[
        {
            {
                button[ $copyToClipboardButtonLabel, NotebookDelete @ attached; CopyToClipboard @ string ],
                button[ $insertInputButtonLabel, insertCodeBelow[ string, False ]; NotebookDelete @ attached ],
                button[ evaluateLanguageLabel @ lang, insertCodeBelow[ string, True ]; NotebookDelete @ attached ]
            }
        },
        Alignment -> Top,
        Spacings  -> 0
    ],
    Background     -> GrayLevel[ 0.9764705882352941 ],
    FrameMargins   -> 3,
    FrameStyle     -> GrayLevel[ 0.82 ],
    ImageMargins   -> 0,
    RoundingRadius -> 2
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
            buttonFrameDefault @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "HyperlinkCopyIcon" ],
            buttonFrameActive @ RawBoxes @ ReplaceAll[
                FrontEndResource[ "NotebookToolbarExpressions", "HyperlinkCopyIcon" ],
                RGBColor[ 0.2, 0.2, 0.2 ] -> RGBColor[ 0.2902, 0.58431, 0.8 ]
            ]
        ],
        "LinkHand"
    ],
    "Copy to clipboard"
];

$insertInputButtonLabel := $insertInputButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "InsertInputIcon" ],
            buttonFrameActive @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "InsertInputIconHover" ]
        ],
        "LinkHand"
    ],
    "Insert content as new input cell below"
];

$insertEvaluateButtonLabel := $insertEvaluateButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "EvaluateIcon" ],
            buttonFrameActive @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "EvaluateIconHover" ]
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
buttonFrameDefault[ expr_ ] := Framed[ buttonPane @ expr, FrameStyle -> None, Background -> None, FrameMargins -> 1 ];
buttonFrameActive[ expr_ ] := Framed[ buttonPane @ expr, FrameStyle -> GrayLevel[ 0.82 ], Background -> GrayLevel[ 1 ], FrameMargins -> 1 ];
buttonPane[ expr_ ] := Pane[ expr, ImageSize -> { 24, 24 }, ImageSizeAction -> "ShrinkToFit", Alignment -> { Center, Center } ];

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

stringTemplateInput[ s_String? NameQ ] /; Context @ s === "System`" :=
    hyperlink[ s, "paclet:ref/" <> Last @ StringSplit[ s, "`" ] ];

stringTemplateInput[ s_String? StringQ ] :=
    UsingFrontEnd @ Enclose @ Confirm[ stringTemplateInput0 ][ s ];

stringTemplateInput[ ___ ] := $Failed;

stringTemplateInput0 // ClearAll;
stringTemplateInput0 := Enclose[
    Needs[ "DefinitionNotebookClient`" -> None ];
    ConfirmMatch[
        DefinitionNotebookClient`StringTemplateInput[ "x" ],
        Except[ _DefinitionNotebookClient`StringTemplateInput ]
    ];
    stringTemplateInput0 = DefinitionNotebookClient`StringTemplateInput
];

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
    throwFailure[ ChatbookAction::Internal, $bugReportLink, HoldForm @ eval, a ];

throwInternalFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$bugReportLink*)
$bugReportLink := Hyperlink[
    "Report this issue \[RightGuillemet]",
    URLBuild @ <|
        "Scheme"   -> "https",
        "Domain"   -> "github.com",
        "Path"     -> { "ConnorGray", "LLMTools", "issues", "new" },
        "Query"    -> {
            "title"  -> "[Chatbook] Insert Title Here",
            "body"   -> bugReportBody[ ],
            "labels" -> "bug"
        }
    |>
];

bugReportBody[ ] := bugReportBody @ PacletObject[ "Wolfram/LLMTools" ][ "PacletInfo" ];

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
        "Settings"              -> $settings
    ]
];


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
```",
Delimiters -> "%%"
];


$bugReportStack := StringRiffle[
    Replace[
        DeleteAdjacentDuplicates @ Cases[
            Stack[ _ ],
            HoldForm[ (s_Symbol) | (s_Symbol)[ ___ ] | (s_Symbol)[ ___ ][ ___ ] ] /;
                AtomQ @ Unevaluated @ s && StringStartsQ[ Context @ s, "Wolfram`Chatbook`" ] :>
                    SymbolName @ Unevaluated @ s
        ],
        { a___, "throwInternalFailure", ___ } :> { a, "throwInternalFailure" }
    ],
    "\n"
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
