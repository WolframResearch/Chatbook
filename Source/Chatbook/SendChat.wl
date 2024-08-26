(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`SendChat`" ];
Begin[ "`Private`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Needs[ "Wolfram`Chatbook`"               ];
Needs[ "Wolfram`Chatbook`Actions`"       ];
Needs[ "Wolfram`Chatbook`Common`"        ];
Needs[ "Wolfram`Chatbook`Personas`"      ];
Needs[ "Wolfram`Chatbook`Serialization`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$resizeDingbats            = True;
splitDynamicTaskFunction   = createFETask;
$defaultHandlerKeys        = { "Body", "BodyChunk", "BodyChunkProcessed", "StatusCode", "TaskStatus", "EventName" };
$chatSubmitDroppedHandlers = { "ChatPost", "ChatPre", "Resolved" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Severity Tag String Patterns*)
$$whitespace  = Longest[ WhitespaceCharacter... ];
$$severityTag = "ERROR"|"WARNING"|"INFO";
$$tagPrefix   = StartOfString~~$$whitespace~~"["~~$$whitespace~~$$severityTag~~$$whitespace~~"]"~~$$whitespace;
$maxTagLength = Max[ StringLength /@ (List @@ $$severityTag) ] + 2;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialization*)
$dynamicTrigger    = 0;
$lastDynamicUpdate = 0;
$buffer            = "";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SendChat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sendChat*)
sendChat // beginDefinition;

sendChat[ evalCell_, nbo_, settings0_ ] /; $useLLMServices := catchTopAs[ ChatbookAction ] @ Enclose[
    Module[ { settings, cells0, cells, target, messages, data, persona, cellTags, cell, cellObject, container, task },

        initFETaskWidget @ nbo;
        resolveInlineReferences @ evalCell;

        settings = ConfirmBy[ resolveAutoSettings @ settings0, AssociationQ, "ResolveSettings" ];
        cells0 = ConfirmMatch[ selectChatCells[ settings, evalCell, nbo ], { __CellObject }, "SelectChatCells" ];

        { cells, target } = ConfirmMatch[
            chatHistoryCellsAndTarget @ cells0 // LogChatTiming[ "ChatHistoryCellsAndTarget" ],
            { { __CellObject }, _CellObject | None },
            "HistoryAndTarget"
        ];

        $finishReason = None;
        $multimodalMessages = TrueQ @ settings[ "Multimodal" ];
        $chatIndicatorSymbol = chatIndicatorSymbol @ settings;

        If[ TrueQ @ settings[ "EnableChatGroupSettings" ],
            AppendTo[ settings, "ChatGroupSettings" -> getChatGroupSettings @ evalCell ];
            $currentChatSettings = settings;
        ];

        If[ ! settings[ "IncludeHistory" ], cells = { evalCell } ];

        { messages, data } = Reap[
            ConfirmMatch[
                constructMessages[ settings, cells ] // LogChatTiming[ "ConstructMessages" ],
                { __Association },
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
            ];
            $currentChatSettings = settings;
        ];

        AppendTo[ settings, "Data" -> data ];

        container = <|
            "DynamicContent" -> ProgressIndicator[ Appearance -> "Percolate" ],
            "FullContent"    -> ProgressIndicator[ Appearance -> "Percolate" ],
            "UUID"           -> CreateUUID[ ]
        |>;

        $reformattedCell = None;
        cellTags = CurrentValue[ evalCell, CellTags ];
        cell = activeAIAssistantCell[
            container,
            Association[ settings, "Container" :> container, "CellObject" :> cellObject, "Task" :> task ],
            cellTags
        ];

        Quiet[
            TaskRemove @ $lastTask;
            NotebookDelete @ $lastCellObject;
        ];

        $resultCellCache = <| |>;
        $debugLog = Internal`Bag[ ];

        If[ settings[ "SetCellDingbat" ] && ! TrueQ @ $cloudNotebooks && chatInputCellQ @ evalCell,
            SetOptions[
                evalCell,
                CellDingbat -> ReplaceAll[
                    CurrentValue[ evalCell, CellDingbat ],
                    TemplateBox[ { }, "ChatInputActiveCellDingbat" ] -> TemplateBox[ { }, "ChatInputCellDingbat" ]
                ]
            ] // LogChatTiming[ "SetCellDingbat" ]
        ];

        cellObject = $lastCellObject = ConfirmMatch[
            createNewChatOutput[ settings, target, cell ],
            _CellObject,
            "CreateOutput"
        ] // LogChatTiming[ "CreateChatOutput" ];

        applyHandlerFunction[
            settings,
            "ChatPre",
            <|
                "EvaluationCell" -> evalCell,
                "Messages"       -> messages,
                "CellObject"     -> cellObject,
                "Container"      :> container
            |>
        ];

        task = $lastTask = chatSubmit[ container, messages, cellObject, settings ];

        addHandlerArguments[ "Task" -> task ];

        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "CellObject" } ] = cellObject;
        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "Task"       } ] = task;

        If[ FailureQ @ task, throwTop @ writeErrorCell[ cellObject, task ] ];

        If[ task === $Canceled, StopChat @ cellObject ];

        task
    ],
    throwInternalFailure
];


(* TODO: this definition is obsolete once LLMServices is widely available: *)
sendChat[ evalCell_, nbo_, settings0_ ] := catchTopAs[ ChatbookAction ] @ Enclose[
    Module[
        {
            settings, cells0, cells, target, id, key, messages, req, data, persona,
            cellTags, cell, cellObject, container, task
        },

        initFETaskWidget @ nbo;
        resolveInlineReferences @ evalCell;

        settings = ConfirmBy[ resolveAutoSettings @ settings0, AssociationQ, "ResolveSettings" ];
        cells0 = ConfirmMatch[ selectChatCells[ settings, evalCell, nbo ], { __CellObject }, "SelectChatCells" ];

        { cells, target } = ConfirmMatch[
            chatHistoryCellsAndTarget @ cells0,
            { { __CellObject }, _CellObject | None },
            "HistoryAndTarget"
        ];

        $finishReason = None;
        $multimodalMessages = TrueQ @ settings[ "Multimodal" ];
        $chatIndicatorSymbol = chatIndicatorSymbol @ settings;

        If[ TrueQ @ settings[ "EnableChatGroupSettings" ],
            AppendTo[ settings, "ChatGroupSettings" -> getChatGroupSettings @ evalCell ];
            $currentChatSettings = settings;
        ];

        id  = Lookup[ settings, "ID" ];
        key = toAPIKey[ Automatic, id ];

        If[ ! settings[ "IncludeHistory" ], cells = { evalCell } ];

        If[ ! StringQ @ key, throwFailure[ "NoAPIKey" ] ];

        settings[ "OpenAIKey" ] = key;

        { req, data } = Reap[
            ConfirmMatch[
                makeHTTPRequest[ settings, messages = constructMessages[ settings, cells ] ],
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
            ];
            $currentChatSettings = settings;
        ];

        AppendTo[ settings, "Data" -> data ];

        container = <|
            "DynamicContent" -> ProgressIndicator[ Appearance -> "Percolate" ],
            "FullContent"    -> ProgressIndicator[ Appearance -> "Percolate" ],
            "UUID"           -> CreateUUID[ ]
        |>;

        $reformattedCell = None;
        cellTags = CurrentValue[ evalCell, CellTags ];
        cell = activeAIAssistantCell[
            container,
            Association[ settings, "Container" :> container, "CellObject" :> cellObject, "Task" :> task ],
            cellTags
        ];

        Quiet[
            TaskRemove @ $lastTask;
            NotebookDelete @ $lastCellObject;
        ];

        $resultCellCache = <| |>;
        $debugLog = Internal`Bag[ ];

        If[ settings[ "SetCellDingbat" ] && ! TrueQ @ $cloudNotebooks && chatInputCellQ @ evalCell,
            SetOptions[
                evalCell,
                CellDingbat -> ReplaceAll[
                    CurrentValue[ evalCell, CellDingbat ],
                    TemplateBox[ { }, "ChatInputActiveCellDingbat" ] -> TemplateBox[ { }, "ChatInputCellDingbat" ]
                ]
            ]
        ];

        cellObject = $lastCellObject = ConfirmMatch[
            createNewChatOutput[ settings, target, cell ],
            _CellObject,
            "CreateOutput"
        ];

        applyHandlerFunction[
            settings,
            "ChatPre",
            <|
                "EvaluationCell" -> evalCell,
                "Messages"       -> messages,
                "CellObject"     -> cellObject,
                "Container"      :> container
            |>
        ];

        task = $lastTask = chatSubmit[ container, req, cellObject, settings ];

        addHandlerArguments[ "Task" -> task ];

        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "CellObject" } ] = cellObject;
        CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "Task"       } ] = task;

        If[ FailureQ @ task, throwTop @ writeErrorCell[ cellObject, task ] ];

        If[ task === $Canceled, StopChat @ cellObject ];

        task
    ],
    throwInternalFailure
];

sendChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeHTTPRequest*)
makeHTTPRequest // beginDefinition;

(* cSpell: ignore ENDTOOLCALL, AIAPI *)
makeHTTPRequest[ settings_Association? AssociationQ, messages: { __Association } ] :=
    Enclose @ Module[
        { key, stream, model, tokens, temperature, topP, freqPenalty, presPenalty, data, body, apiCompletionURL },

        key              = ConfirmBy[ Lookup[ settings, "OpenAIKey" ], StringQ ];
        stream           = True;
        apiCompletionURL = ConfirmBy[ Lookup[ settings, "OpenAIAPICompletionURL" ], StringQ ];

        (* model parameters *)
        model       = Lookup[ settings, "Model"           , $DefaultModel ];
        tokens      = Lookup[ settings, "MaxTokens"       , Automatic     ];
        temperature = Lookup[ settings, "Temperature"     , 0.7           ];
        topP        = Lookup[ settings, "TopP"            , 1             ];
        freqPenalty = Lookup[ settings, "FrequencyPenalty", 0.1           ];
        presPenalty = Lookup[ settings, "PresencePenalty" , 0.1           ];

        data = DeleteCases[
            <|
                "messages"          -> prepareMessagesForHTTPRequest @ messages,
                "temperature"       -> temperature,
                "max_tokens"        -> tokens,
                "top_p"             -> topP,
                "frequency_penalty" -> freqPenalty,
                "presence_penalty"  -> presPenalty,
                "model"             -> toModelName @ model,
                "stream"            -> stream,
                "stop"              -> makeStopTokens @ settings
            |>,
            Automatic|_Missing
        ];

        body = ConfirmBy[ Developer`WriteRawJSONString[ data, "Compact" -> True ], StringQ ];

        $lastHTTPParameters = data;
        $lastRequest = HTTPRequest[
            apiCompletionURL,
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
(*makeStopTokens*)
makeStopTokens // beginDefinition;

makeStopTokens[ settings_Association ] :=
    Select[
        DeleteDuplicates @ Flatten @ {
            settings[ "StopTokens" ],
            If[ settings[ "ToolMethod" ] === "Simple", { "\n/exec", "/end" }, { "ENDTOOLCALL", "/end" } ],
            If[ TrueQ @ $AutomaticAssistance, "[INFO]", Nothing ]
        },
        StringQ
    ];

makeStopTokens // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatIndicatorSymbol*)
chatIndicatorSymbol // beginDefinition;
chatIndicatorSymbol[ settings_Association ] := chatIndicatorSymbol @ settings[ "ChatInputIndicator" ];
chatIndicatorSymbol[ $$unspecified ] := $chatIndicatorSymbol;
chatIndicatorSymbol[ None|"" ] := None;
chatIndicatorSymbol[ string_String? StringQ ] := string;
chatIndicatorSymbol // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareMessagesForHTTPRequest*)
prepareMessagesForHTTPRequest // beginDefinition;
prepareMessagesForHTTPRequest[ messages_List ] := $lastHTTPMessages = prepareMessageForHTTPRequest /@ messages;
prepareMessagesForHTTPRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareMessageForHTTPRequest*)
prepareMessageForHTTPRequest // beginDefinition;
prepareMessageForHTTPRequest[ message_Association? AssociationQ ] := AssociationMap[ prepareMessageRule, message ];
prepareMessageForHTTPRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareMessageRule*)
prepareMessageRule // beginDefinition;
prepareMessageRule[ "Role"|"role"       -> role_String ] := "role"    -> ToLowerCase @ role;
prepareMessageRule[ "Content"|"content" -> content_    ] := "content" -> prepareMessageContent @ content;
prepareMessageRule[ key_String          -> value_      ] := ToLowerCase @ key -> value;
prepareMessageRule // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareMessageContent*)
prepareMessageContent // beginDefinition;
prepareMessageContent[ content_String ] := content;
prepareMessageContent[ content_List   ] := prepareMessagePart /@ content;
prepareMessageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareMessagePart*)
prepareMessagePart // beginDefinition;
prepareMessagePart[ text_String         ] := prepareMessagePart @ <| "Type" -> "Text" , "Data" -> text  |>;
prepareMessagePart[ image_? graphicsQ   ] := prepareMessagePart @ <| "Type" -> "Image", "Data" -> image |>;
prepareMessagePart[ file_File           ] := prepareMessagePart @ <| "Type" -> partType @ file, "Data" -> file |>;
prepareMessagePart[ url_URL             ] := prepareMessagePart @ <| "Type" -> partType @ url , "Data" -> url  |>;
prepareMessagePart[ part_? AssociationQ ] := prepareMessagePart0 @ KeyMap[ ToLowerCase, part ];
prepareMessagePart // endDefinition;

prepareMessagePart0 // beginDefinition;

prepareMessagePart0[ part_Association ] := <|
    KeyDrop[ part, "data" ],
    prepareMessagePart0[ part[ "type" ], part[ "data" ] ]
|>;

prepareMessagePart0[ "Text" , text_   ] := <| "type" -> "text"     , "text"      -> prepareTextPart @ text    |>;
prepareMessagePart0[ "Image", img_    ] := <| "type" -> "image_url", "image_url" -> prepareImageURLPart @ img |>;
prepareMessagePart0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareImageURLPart*)
prepareImageURLPart // beginDefinition;
prepareImageURLPart[ URL[ url_String ] ] := <| "url" -> url |>;
prepareImageURLPart[ file_File ] := With[ { img = importImage @ file }, prepareImageURLPart @ img /; graphicsQ @ img ];
prepareImageURLPart[ image_ ] := prepareImageURLPart @ URL @ toImageURI @ image;
prepareImageURLPart // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*importImage*)
importImage // beginDefinition;
importImage[ file_File ] := importImage[ file, fastFileHash @ file ];
importImage[ file_, hash_Integer ] := With[ { img = $importImageCache[ file, hash ] }, img /; image2DQ @ img ];
importImage[ file_, hash_Integer ] := $importImageCache[ file ] = <| hash -> importImage0 @ file |>;
importImage // endDefinition;

$importImageCache = <| |>;

importImage0 // beginDefinition;
importImage0[ file_ ] := importImage0[ file, Import[ file, "Image" ] ];
importImage0[ file_, img_? graphicsQ ] := img;
importImage0 // endDefinition;

(* TODO: if an "ExternalFile" type of chat cell is defined, this should throw appropriate error text here *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareTextPart*)
prepareTextPart // beginDefinition;
prepareTextPart[ text_String? StringQ   ] := text;
prepareTextPart[ file_File? FileExistsQ ] := prepareTextPart @ readString @ file;
prepareTextPart[ url_URL                ] := prepareTextPart @ URLRead[ url, "Body" ];
prepareTextPart[ failure_Failure        ] := makeFailureString @ failure;
prepareTextPart // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*partType*)
partType // beginDefinition;
partType[ url_URL   ] := "Image"; (* this could determine type automatically, but it would likely be too slow *)
partType[ file_File ] := partType[ file, fastFileHash @ file ];
partType[ file_, hash_Integer ] := With[ { type = $partTypeCache[ file, hash ] }, type /; StringQ @ type ];
partType[ file_, hash_Integer ] := With[ { t = partType0 @ file }, $partTypeCache[ file ] = <| hash -> t |>; t ];
partType // endDefinition;

$partTypeCache = <| |>;

partType0 // beginDefinition;
partType0[ file_ ] := partType0[ file, FileFormat @ file ];
partType0[ file_, fmt_String ] := partType0[ file, fmt, FileFormatProperties[ fmt, "ImportElements" ] ];
partType0[ file_, fmt_, { ___, "Image", ___ } ] := "Image";
partType0[ file_, fmt_, _List ] := "Text";
partType0 // endDefinition;

(* TODO: if an "ExternalFile" type of chat cell is defined, this should throw appropriate error text here *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toImageURI*)
toImageURI // beginDefinition;

toImageURI[ image_? image2DQ ] :=
    toImageURI[ image, "JPEG" ];

toImageURI[ image_ ] :=
    toImageURI[ image, "PNG" ];

toImageURI[ image_, fmt_ ] := Enclose[
    Module[ { resized, uri },
        resized = ConfirmBy[ resizeMultimodalImage @ image, image2DQ, "Resized" ];
        uri     = ConfirmBy[ exportDataURI[ resized, fmt ], StringQ, "URI" ];
        toImageURI[ image ] = uri
    ],
    throwInternalFailure[ toImageURI @ image, ## ] &
];

toImageURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatSubmit*)
chatSubmit // beginDefinition;
chatSubmit // Attributes = { HoldFirst };

chatSubmit[ args__ ] := Quiet[
    rasterizeBlock @ chatSubmit0 @ args,
    {
        (* cSpell: ignore wname, invm, invk *)
        ServiceConnections`SavedConnections::wname,
        ServiceConnections`ServiceConnections::wname,
        URLSubmit::invm,
        URLSubmit::invk
    }
];

chatSubmit // endDefinition;

(* TODO: chatHandlers could probably filter valid keys instead of quieting URLSubmit::invm, but the list of available
         events is defined via a private symbol that might not be safe to use:
         URLUtilities`Submit`PackagePrivate`$eventNames
*)

chatSubmit0 // beginDefinition;
chatSubmit0 // Attributes = { HoldFirst };

chatSubmit0[ container_, messages: { __Association }, cellObject_, settings_ ] := Quiet[
    Needs[ "LLMServices`" -> None ];
    $lastChatSubmitResult = ReleaseHold[
        $lastChatSubmit = HoldForm @ applyProcessingFunction[
            settings,
            "ChatSubmit",
            HoldComplete[
                standardizeMessageKeys @ messages,
                makeLLMConfiguration @ settings,
                Authentication       -> settings[ "Authentication" ],
                HandlerFunctions     -> chatHandlers[ container, cellObject, settings ],
                HandlerFunctionsKeys -> chatHandlerFunctionsKeys @ settings,
                "TestConnection"     -> False
            ],
            <|
                "Container"             :> container,
                "Messages"              -> messages,
                "CellObject"            -> cellObject,
                "DefaultSubmitFunction" -> LLMServices`ChatSubmit
            |>,
            LLMServices`ChatSubmit
        ]
    ],
    { LLMServices`ChatSubmit::unsupported }
];

(* TODO: this definition is obsolete once LLMServices is widely available: *)
chatSubmit0[ container_, req_HTTPRequest, cellObject_, settings_ ] := (
    $buffer = "";
    applyProcessingFunction[
        settings,
        "ChatSubmit",
        HoldComplete[
            req,
            HandlerFunctions     -> chatHandlers[ container, cellObject, settings ],
            HandlerFunctionsKeys -> chatHandlerFunctionsKeys @ settings,
            CharacterEncoding    -> "UTF8"
        ],
        <|
            "Container"             :> container,
            "Request"               -> req,
            "CellObject"            -> cellObject,
            "DefaultSubmitFunction" -> URLSubmit
        |>,
        URLSubmit
    ]
);

chatSubmit0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeLLMConfiguration*)
makeLLMConfiguration // beginDefinition;

makeLLMConfiguration[ as: KeyValuePattern[ "Model" -> model_String ] ] :=
    makeLLMConfiguration @ Append[ as, "Model" -> { "OpenAI", model } ];

makeLLMConfiguration[ as_Association ] :=
    $lastLLMConfiguration = LLMConfiguration @ Association[
        KeyTake[ as, { "Model", "MaxTokens", "Temperature", "PresencePenalty" } ],
        "StopTokens" -> makeStopTokens @ as
    ];

makeLLMConfiguration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatHandlerFunctionsKeys*)
chatHandlerFunctionsKeys // beginDefinition;
chatHandlerFunctionsKeys[ as_? AssociationQ ] := chatHandlerFunctionsKeys[ as, as[ "HandlerFunctionsKeys" ] ];
chatHandlerFunctionsKeys[ as_, $$unspecified ] := $defaultHandlerKeys;
chatHandlerFunctionsKeys[ as_, keys_List ] := Union[ Select[ Flatten @ keys, StringQ ], $defaultHandlerKeys ];
chatHandlerFunctionsKeys[ as_, key_String ] := chatHandlerFunctionsKeys[ as, { key } ];
chatHandlerFunctionsKeys[ as_, invalid_ ] := (messagePrint[ "InvalidHandlerKeys", invalid ]; $defaultHandlerKeys);
chatHandlerFunctionsKeys // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatHandlers*)
chatHandlers // beginDefinition;
chatHandlers // Attributes = { HoldFirst };

chatHandlers[ container_, cellObject_, settings_ ] :=
    $lastHandlers = With[
        {
            autoOpen      = TrueQ @ $autoOpen,
            alwaysOpen    = TrueQ @ $alwaysOpen,
            autoAssist    = $AutomaticAssistance,
            dynamicSplit  = dynamicSplitQ @ settings,
            handlers      = getHandlerFunctions @ settings,
            useTasks      = feTaskQ @ settings,
            toolFormatter = getToolFormatter @ settings,
            stop          = makeStopTokens @ settings
        },
        {
            bodyChunkHandler    = Lookup[ handlers, "BodyChunkReceived", None ],
            taskFinishedHandler = Lookup[ handlers, "TaskFinished"     , None ]
        },
        <|
            KeyDrop[ handlers, $chatSubmitDroppedHandlers ],
            "BodyChunkReceived" -> Function @ catchAlways[
                withFETasks[ useTasks ] @ Block[
                    {
                        $alwaysOpen          = alwaysOpen,
                        $AutomaticAssistance = autoAssist,
                        $autoOpen            = autoOpen,
                        $customToolFormatter = toolFormatter,
                        $dynamicSplit        = dynamicSplit,
                        $settings            = settings
                    },
                    bodyChunkHandler[ #1 ];
                    Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                    checkFinishReason[ #1 ];
                    writeChunk[ Dynamic @ container, cellObject, #1 ]
                ]
            ],
            "TaskFinished" -> Function @ catchAlways[
                withFETasks[ useTasks ] @ Block[
                    {
                        $alwaysOpen          = alwaysOpen,
                        $AutomaticAssistance = autoAssist,
                        $autoOpen            = autoOpen,
                        $customToolFormatter = toolFormatter,
                        $dynamicSplit        = dynamicSplit,
                        $settings            = settings
                    },
                    taskFinishedHandler[ #1 ];
                    Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                    checkFinishReason[ #1 ];
                    logUsage @ container;
                    trimStopTokens[ container, stop ];
                    checkResponse[ $settings, Unevaluated @ container, cellObject, #1 ]
                ]
            ]
        |>
    ];

chatHandlers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*trimStopTokens*)
trimStopTokens // beginDefinition;
trimStopTokens // Attributes = { HoldFirst };

trimStopTokens[ container_, stop: { ___String } ] :=
    With[ { full = container[ "FullContent" ], dynamic = container[ "DynamicContent" ] },
        (
            container[ "DynamicContent" ] = StringDelete[ dynamic, stop~~EndOfString ];
            container[ "FullContent"    ] = StringDelete[ full   , stop~~EndOfString ];
        ) /; StringQ @ full
    ];

trimStopTokens[ container_, { ___String } ] :=
    Null;

trimStopTokens // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkFinishReason*)
checkFinishReason // beginDefinition;

checkFinishReason[ as_Association ] := checkFinishReason @ as[ "BodyChunk" ];
checkFinishReason[ _Missing ] := Null;

checkFinishReason[ chunk_String ] :=
    Module[ { reasons },
        reasons = StringCases[ chunk, "\"finish_reason\":\"" ~~ reason: Except[ "\"" ].. ~~ "\"" :> reason ];
        If[ MatchQ[ reasons, { ___, _String } ], $finishReason = Last @ reasons ]
    ];

checkFinishReason // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*feTaskQ*)
feTaskQ // beginDefinition;
feTaskQ[ settings_ ] := feTaskQ[ settings, settings[ "NotebookWriteMethod" ] ];
feTaskQ[ settings_, "ServiceLink"    ] := False;
feTaskQ[ settings_, "PreemptiveLink" ] := True;
feTaskQ[ settings_, $$unspecified    ] := True;
feTaskQ[ settings_, invalid_         ] := (messagePrint[ "InvalidWriteMethod", invalid ]; True);
feTaskQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*withFETasks*)
withFETasks // beginDefinition;
withFETasks[ False ] := Function[ eval, Block[ { createFETask = #1 & }, eval ], HoldFirst ];
withFETasks[ True  ] := #1 &;
withFETasks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeChunk*)
writeChunk // beginDefinition;

writeChunk[ container_, cell_, KeyValuePattern[ "BodyChunkProcessed" -> chunks_ ] ] :=
    With[ { chunk = StringJoin @ Select[ Flatten @ { chunks }, StringQ ] },
        If[ chunk === "",
            Null,
            writeChunk0[ container, cell, chunk, chunk ]
        ]
    ];

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk[ container_, cell_, KeyValuePattern[ "BodyChunk" -> chunk_String ] ] :=
    writeChunk[ container, cell, $buffer <> chunk ];

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk[ container_, cell_, chunk_String ] :=
    Module[ { ws, sep, parts, buffer },
        ws      = WhitespaceCharacter...;
        sep     = "\n\n" | "\r\n\r\n";
        parts   = StringTrim @ StringCases[ chunk, "data:" ~~ ws ~~ json: Except[ "\n" ].. ~~ sep :> json ];
        buffer  = StringDelete[ StringDelete[ chunk, "data:" ~~ ws ~~ parts ~~ sep ], StartOfString ~~ "\n".. ];
        $buffer = buffer;
        writeChunk0[ container, cell, #1 ] & /@ parts
    ];

writeChunk // endDefinition;


writeChunk0 // beginDefinition;

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[ container_, cell_, "" | "[DONE]" | "[DONE]\n\n" ] :=
    Null;

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[ container_, cell_, chunk_String ] :=
    writeChunk0[ container, cell, chunk, Quiet @ Developer`ReadRawJSONString @ chunk ];

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "choices" -> { KeyValuePattern[ "delta" -> KeyValuePattern[ "content" -> text_String ] ], ___ } ]
] := writeChunk0[ container, cell, chunk, text ];

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "choices" -> { KeyValuePattern @ { "delta" -> <| |>, "finish_reason" -> "stop" }, ___ } ]
] := Null;

(* TODO: this definition is obsolete once LLMServices is widely available: *)
writeChunk0[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "completion" -> text_String ]
] := writeChunk0[ container, cell, chunk, text ];

writeChunk0[ Dynamic[ container_ ], cell_, chunk_String, text_String ] := (

    appendStringContent[ container[ "FullContent"    ], text ];
    appendStringContent[ container[ "DynamicContent" ], text ];

    (* FIXME: figure out what to do here when there's a custom formatter *)
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

writeChunk0[ Dynamic[ container_ ], cell_, chunk_String, other_ ] :=
     Internal`StuffBag[ $chunkDebug, <| "chunk" -> chunk, "other" -> other |> ];

writeChunk0 // endDefinition;

$chunkDebug = Internal`Bag[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendStringContent*)
appendStringContent // beginDefinition;
appendStringContent // Attributes = { HoldFirst };

appendStringContent[ container_, text_String ] := Quiet[
    If[ StringQ @ container,
        container = autoCorrect @ StringDelete[ container <> convertUTF8 @ text, StartOfString~~Whitespace ],
        container = autoCorrect @ convertUTF8 @ text
    ],
    $CharacterEncoding::utf8
];

appendStringContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoCorrect*)
autoCorrect // beginDefinition;
autoCorrect[ string_String ] := StringReplace[ string, $llmAutoCorrectRules ];
autoCorrect // endDefinition;

(* cSpell: ignore evaliator *)
$llmAutoCorrectRules = Flatten @ {
    "wolfram_language_evaliator" -> "wolfram_language_evaluator",
    "\\!\\(\\*MarkdownImageBox[\"" ~~ Shortest[ uri__ ] ~~ "\"]\\)" :> uri,
    "\\!\\(MarkdownImageBox[\"" ~~ Shortest[ uri__ ] ~~ "\"]\\)" :> uri,
    "\"\\\\!\\\\(\\\\*MarkdownImageBox[\\\"" ~~ Shortest[ uri__ ] ~~ "\\\"]\\\\)\"" :> uri,
    "\"\\\\!\\\\(MarkdownImageBox[\\\"" ~~ Shortest[ uri__ ] ~~ "\\\"]\\\\)\"" :> uri,
    "<" ~~ Shortest[ scheme: LetterCharacter.. ~~ "://" ~~ id: Except[ "!" ].. ] ~~ ">" :>
        "<!" <> scheme <> "://" <> id <> "!>",
    "\\uf351" -> "\[FreeformPrompt]",
    "\n<|image_sentinel|>\n" :> "\n",
    "<|image_sentinel|>" :> "",
    $longNameCharacters
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*splitDynamicContent*)
splitDynamicContent // beginDefinition;
splitDynamicContent // Attributes = { HoldFirst };

(* NotebookLocationSpecifier isn't available before 13.3 and splitting isn't yet supported in cloud: *)
splitDynamicContent[ container_, cell_ ] /; Or[
    $InlineChat,
    ! $dynamicSplit,
    insufficientVersionQ[ "DynamicSplit" ],
    $cloudNotebooks
] := Null;

splitDynamicContent[ container_, cell_ ] :=
    splitDynamicContent[ container, container[ "DynamicContent" ], cell, container[ "UUID" ] ];

splitDynamicContent[ container_, text_String, cell_, uuid_String ] :=
    splitDynamicContent[ container, DeleteCases[ StringSplit[ text, $dynamicSplitRules ], "" ], cell, uuid ];

splitDynamicContent[ container_, { static__String, dynamic_String }, cell_, uuid_String ] := Enclose[
    Catch @ Module[ { boxObject, settings, reformatted, write, nbo },

        boxObject = ConfirmMatch[
            getBoxObjectFromBoxID[ cell, uuid ],
            _BoxObject | Missing[ "CellRemoved", ___ ],
            "BoxObject"
        ];

        If[ MatchQ[ boxObject, Missing[ "CellRemoved", ___ ] ],
            throwTop[ Quiet[ TaskRemove @ $lastTask, TaskRemove::timnf ]; Null ]
        ];

        settings = ConfirmBy[ $ChatHandlerData[ "ChatNotebookSettings" ], AssociationQ, "Settings" ];

        reformatted = ConfirmMatch[
            If[ TrueQ @ settings[ "AutoFormat" ],
                Block[ { $dynamicText = False }, reformatTextData @ StringJoin @ static ],
                { StringJoin @ static }
            ],
            $$textDataList,
            "ReformatTextData"
        ];

        write = Cell[ TextData @ reformatted, "None", Background -> None ];
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
                Cell[ "\n", "None" ],
                None,
                AutoScroll -> False
            ];
        ];

        $dynamicTrigger++;
        $lastDynamicUpdate = AbsoluteTime[ ];

    ],
    throwInternalFailure
];

(* There's nothing we can write as static content yet: *)
splitDynamicContent[ container_, { _ } | { }, cell_, uuid_ ] := Null;

splitDynamicContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkResponse*)
checkResponse // beginDefinition;

checkResponse[ settings: KeyValuePattern[ "ToolsEnabled" -> False ], container_, cell_, as_Association ] :=
    If[ TrueQ @ $AutomaticAssistance,
        writeResult[ settings, container, cell, as ],
        $nextTaskEvaluation = Hold @ writeResult[ settings, container, cell, as ]
    ];

(* FIXME: Look for "finish_reason":"stop" and check if response ends in a WL code block.
          If it does, process it as a tool call, since it wrote /exec after the code block. *)
checkResponse[ settings_, container_, cell_, as_Association ] /; toolFreeQ[ settings, container ] :=
    If[ TrueQ @ $AutomaticAssistance,
        writeResult[ settings, container, cell, as ],
        $nextTaskEvaluation = Hold @ writeResult[ settings, container, cell, as ]
    ];

checkResponse[ settings_, container_Symbol, cell_, as_Association ] :=
    If[ TrueQ @ $AutomaticAssistance,
        toolEvaluation[ settings, Unevaluated @ container, cell, as ],
        $nextTaskEvaluation = Hold @ toolEvaluation[ settings, Unevaluated @ container, cell, as ]
    ];

checkResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeResult*)
writeResult // beginDefinition;

writeResult[ settings_, container_, cell_, as_Association ] := Enclose[
    Catch @ Module[ { log, processed, body, data },

        If[ TrueQ @ $AutomaticAssistance,
            NotebookDelete @ Cells[ PreviousCell @ cell, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ]
        ];

        If[ settings[ "BypassResponseChecking" ], Throw @ writeReformattedCell[ settings, container, cell ] ];

        log = ConfirmMatch[ Internal`BagPart[ $debugLog, All ], { ___Association }, "DebugLog" ];
        processed = StringJoin @ Cases[ log, KeyValuePattern[ "BodyChunkProcessed" -> s_String ] :> s ];
        { body, data } = ConfirmMatch[ extractBodyData @ log, { _, _ }, "ExtractBodyData" ];

        $lastFullResponseData = <| "Body" -> body, "Processed" -> processed, "Data" -> data |>;

        Which[ MatchQ[ as[ "StatusCode" ], Except[ 200, _Integer ] ] || (processed === "" && AssociationQ @ data),
               writeErrorCell[ cell, $badResponse = Association[ as, "Body" -> body, "BodyJSON" -> data ] ]
               ,
               processed === body === "",
               writeErrorCell[ cell, $badResponse = Association[ as, "Error" -> "ServerResponseEmpty" ] ]
               ,
               True,
               writeReformattedCell[ settings, container, cell ]
        ]
    ],
    throwInternalFailure
];

writeResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractBodyData*)
extractBodyData // beginDefinition;

extractBodyData[ { ___, KeyValuePattern[ "TaskStatus" -> "Finished" ], rest__ } ] :=
    extractBodyData @ { rest };

extractBodyData[ log_List ] := Enclose[
    Catch @ Module[ { chunks, folded, data, xml },

        FirstCase[
            Reverse @ log,
            KeyValuePattern[ "BodyChunk" -> body: Except[ "", _String ] ] :>
                With[ { json = Quiet @ Developer`ReadRawJSONString @ body },
                    Throw @ { body, json } /; AssociationQ @ json
                ]
        ];

        chunks = Cases[ log, KeyValuePattern[ "BodyChunk" -> s: Except[ "", _String ] ] :> s ];
        folded = Fold[ StringJoin, "", chunks ];
        data   = Quiet @ Developer`ReadRawJSONString @ folded;

        If[ AssociationQ @ data, Throw @ { folded, data } ];

        xml = parseXMLResponse @ folded;
        If[ AssociationQ @ xml, Throw @ { folded, xml } ];

        FirstCase[
            Flatten @ StringCases[
                folded,
                (StartOfString|"\n") ~~ "data: " ~~ s: Except[ "\n" ].. ~~ "\n" :> s
            ],
            s_String :> With[ { json = Quiet @ Developer`ReadRawJSONString @ s },
                            { s, json } /; MatchQ[ json, KeyValuePattern[ "error" -> _ ] ]
                        ],
            { folded, Missing[ "NotAvailable" ] }
        ]
    ],
    throwInternalFailure
];

extractBodyData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseXMLResponse*)
parseXMLResponse // beginDefinition;

parseXMLResponse[ response_String ] :=
    If[ StringContainsQ[ response, "<" ~~ __ ~~ ">" ~~ ___ ~~ "</" ~~ ___ ~~ ">" ],
        parseXMLResponse[ Quiet @ ImportString[ response, "XML" ] ],
        $Failed
    ];

parseXMLResponse[ XMLObject[ ___ ][ ___, elem_XMLElement, ___ ] ] :=
    With[ { as = Association @ parseXMLElement @ elem },
        If[ AssociationQ @ as,
            as,
            $Failed
        ]
    ];

parseXMLResponse[ failure_? FailureQ ] := failure;

parseXMLResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseXMLElement*)
parseXMLElement // beginDefinition;

parseXMLElement[ XMLElement[ _, _List, content_List ] ] := parseXMLElement /@ content;
parseXMLElement[ XMLElement[ key_String, { ___ }, value_String ] ] := key -> value;
parseXMLElement[ XMLElement[ key_String, { ___ }, { value_String } ] ] := key -> value;
parseXMLElement[ XMLElement[ key_String, { ___ }, { values__String } ] ] := key -> { values };

parseXMLElement[ xml: XMLElement[ key_String, { ___ }, data_List ] ] :=
    With[ { as = parseXMLElement /@ data },
       If[ AssociationQ @ Association @ as,
           key -> Association @ as,
           xml
       ]
    ];

parseXMLElement // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Requests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolFreeQ*)
toolFreeQ // beginDefinition;
toolFreeQ[ settings_, KeyValuePattern[ "FullContent" -> s_ ] ] := toolFreeQ[ settings[ "ToolMethod" ], s ];
toolFreeQ[ method_, _ProgressIndicator ] := True;
toolFreeQ[ "Simple", s_String ] := simpleToolFreeQ @ s;
toolFreeQ[ _, s_String ] := toolFreeQ0 @ s;
toolFreeQ // endDefinition;

toolFreeQ0 // beginDefinition;
toolFreeQ0[ s_String ] := ! MatchQ[ toolRequestParser @ s, { _, _LLMToolRequest|_Failure } ];
toolFreeQ0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleToolFreeQ*)
simpleToolFreeQ // beginDefinition;
simpleToolFreeQ[ s_String ] := ! MatchQ[ simpleToolRequestParser @ s, { _, _LLMToolRequest|_Failure } ];
simpleToolFreeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolEvaluation*)
toolEvaluation // beginDefinition;

toolEvaluation[ settings_, container_Symbol, cell_, as_Association ] := Enclose[
    Module[
        {
            string, simple, parser, callPos, toolCall, toolResponse, output,
            messages, roles, response, newMessages, req, toolID, task
        },

        (* Ensure dynamic text is up to date: *)
        $dynamicTrigger++;
        $lastDynamicUpdate = AbsoluteTime[ ];

        string = ConfirmBy[ container[ "FullContent" ], StringQ, "FullContent" ];

        simple = settings[ "ToolMethod" ] === "Simple";
        parser = If[ simple, simpleToolRequestParser, toolRequestParser ];

        (* TODO: implement a `getToolRequestParser` that gives the appropriate parser based on ToolMethod *)
        { callPos, toolCall } = ConfirmMatch[
            parser[ Quiet[ convertUTF8[ string, True ], $CharacterEncoding::utf8 ] ],
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
        (* If[ simple, output = output <> "\n\n" <> $noRepeatMessage ]; *)

        messages = ConfirmMatch[
            removeBasePrompt[ settings[ "Data", "Messages" ], { "AutoAssistant" } ],
            { __Association },
            "Messages"
        ];

        roles = ConfirmMatch[ allowedMultimodalRoles @ settings, All | { __String }, "Roles" ];

        response =
            If[ roles === All || MemberQ[ roles, "System" ],
                expandMultimodalString @ ToString @ output,
                ToString @ output
            ];

        newMessages = Join[
            messages,
            {
                <| "Role" -> "assistant", "Content" -> appendToolCallEndToken[ settings, StringTrim @ string ] |>,
                makeToolResponseMessage[ settings, response ]
            }
        ];

        $finishReason = None;

        req = If[ TrueQ @ $useLLMServices,
                  ConfirmMatch[ constructMessages[ settings, newMessages ], { __Association }, "ConstructMessages" ],
                  (* TODO: this path will be obsolete when LLMServices is widely available *)
                  ConfirmMatch[ makeHTTPRequest[ settings, newMessages ], _HTTPRequest, "HTTPRequest" ]
              ];

        toolID = tinyHash @ toolResponse;
        $toolEvaluationResults[ toolID ] = toolResponse;

        appendToolResult[ container, settings, output, toolID ];

        (* Update dynamic text with tool result before waiting for the next response: *)
        $dynamicTrigger++;
        $lastDynamicUpdate = AbsoluteTime[ ];

        task = $lastTask = chatSubmit[ container, req, cell, settings ];

        addHandlerArguments[ "Task" -> task ];

        CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", "CellObject" } ] = cell;
        CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", "Task"       } ] = task;

        If[ FailureQ @ task, throwTop @ writeErrorCell[ cell, task ] ];

        If[ task === $Canceled, StopChat @ cell ];

        task
    ] // LogChatTiming[ "ToolEvaluation" ],
    throwInternalFailure
];

toolEvaluation // endDefinition;

(* $noRepeatMessage = "\
The user has already been provided with this result, so you do not need to repeat it.
Reply with /end if the tool call provides a satisfactory answer, otherwise respond normally."; *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolResponseMessage*)
makeToolResponseMessage // beginDefinition;
makeToolResponseMessage[ settings_, response_ ] := makeToolResponseMessage0[ serviceName @ settings, response ];
makeToolResponseMessage // endDefinition;

makeToolResponseMessage0 // beginDefinition;

makeToolResponseMessage0[ "Anthropic"|"MistralAI", response_ ] := <|
    "Role"    -> "User",
    "Content" -> Replace[ Flatten @ { "<system>", response, "</system>" }, { s__String } :> StringJoin @ s ]
|>;

makeToolResponseMessage0[ service_String, response_ ] :=
    <| "Role" -> "System", "Content" -> response |>;

makeToolResponseMessage0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*userToolResponseQ*)
userToolResponseQ // beginDefinition;
userToolResponseQ[ settings_ ] := MatchQ[ serviceName @ settings, "Anthropic"|"MistralAI" ];
userToolResponseQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*serviceName*)
serviceName // beginDefinition;
serviceName[ KeyValuePattern[ "Model" -> model_ ] ] := serviceName @ model;
serviceName[ { service_String, _String | $$unspecified } ] := service;
serviceName[ KeyValuePattern[ "Service" -> service_String ] ] := service;
serviceName[ _String | _Association | $$unspecified ] := "OpenAI";
serviceName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendToolCallEndToken*)
appendToolCallEndToken // beginDefinition;
appendToolCallEndToken[ settings_, string_String ] /; settings[ "ToolMethod" ] === "Simple" := string <> "\n/exec";
appendToolCallEndToken[ settings_, string_String ] := string <> "\nENDTOOLCALL";
appendToolCallEndToken // endDefinition;

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
(*appendToolResult*)
appendToolResult // beginDefinition;
appendToolResult // Attributes = { HoldFirst };

appendToolResult[ container_Symbol, KeyValuePattern[ "ToolMethod" -> "Simple" ], output_String, id_String ] :=
    Module[ { append },
        append = "\n/exec\nRESULT\n"<>output<>"\nENDRESULT(" <> id <> ")\n\n";
        container[ "FullContent"    ] = container[ "FullContent"    ] <> append;
        container[ "DynamicContent" ] = container[ "DynamicContent" ] <> append;
    ];

(* cSpell: ignore ENDRESULT *)
appendToolResult[ container_Symbol, settings_, output_String, id_String ] :=
    Module[ { append },
        append = "ENDTOOLCALL\nRESULT\n"<>output<>"\nENDRESULT(" <> id <> ")\n\n";
        container[ "FullContent"    ] = container[ "FullContent"    ] <> append;
        container[ "DynamicContent" ] = container[ "DynamicContent" ] <> append;
    ];

appendToolResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat History*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
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
    ] // LogChatTiming[ "SelectChatCells" ];

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
            First @ FirstPosition[
                before,
                Alternatives[
                    KeyValuePattern[ "Style" -> $$chatDelimiterStyle ],
                    KeyValuePattern[ "ChatNotebookSettings" -> KeyValuePattern[ "ChatDelimiter" -> True ] ]
                ],
                { Length @ before }
            ],
            IntegerQ,
            "ChatDelimiterPosition"
        ];
        selectedRange = Reverse @ Take[ before, groupPos ];

        (* Filter out ignored cells *)
        filtered = ConfirmMatch[ filterChatCells @ selectedRange, { ___Association }, "FilteredCellInfo" ];

        (* If all cells are excluded, do nothing *)
        If[ filtered === { }, throwTop @ Null ];

        (* Delete output cells that come after the evaluation cell *)
        rest = keepValidGeneratedCells @ Drop[ cellData, cellPosition ];

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
(*keepValidGeneratedCells*)
keepValidGeneratedCells // beginDefinition;

(* When chat is triggered by an evaluation instead of a chat input, there can be generated cells between the
   evaluation cell and the previous chat output. For example:

       CellObject[ <Current evaluation cell> ]
       CellObject[ <Message/Print/Echo cells, etc.> ]
       CellObject[ <Output from the current evaluation cell> ]
       CellObject[ <Previous chat output> ] <--- We want to delete this cell, since it's from a previous evaluation

   At this point, the front end has already cleared previous output cells (messages, output, etc.), but the previous
   chat output cell is still there. We need to delete it so that the new chat output cell can be inserted in its place.
   `keepValidGeneratedCells` gathers up all the generated cells that come after the evaluation cell and if it finds
   a chat output cell, it deletes it.
*)
keepValidGeneratedCells[ cellData: { KeyValuePattern[ "CellObject" -> _CellObject ] ... } ] /; $AutomaticAssistance :=
    Module[ { delete, chatOutputs, cells },
        delete      = TakeWhile[ cellData, MatchQ @ KeyValuePattern[ "CellAutoOverwrite" -> True ] ];
        chatOutputs = Cases[ delete, KeyValuePattern[ "Style" -> $$chatOutputStyle ] ];
        cells       = Cases[ chatOutputs, KeyValuePattern[ "CellObject" -> cell_ ] :> cell ];
        NotebookDelete @ cells;
        DeleteCases[ delete, KeyValuePattern[ "CellObject" -> Alternatives @@ cells ] ]
    ];

(* When chat is triggered by a normal chat input evaluation, we only want to keep the next chat output if it exists: *)
keepValidGeneratedCells[ cellData_ ] :=
    TakeWhile[ cellData, MatchQ @ KeyValuePattern @ { "CellAutoOverwrite" -> True, "Style" -> $$chatOutputStyle } ];

keepValidGeneratedCells // endDefinition;

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
(* ::Section::Closed:: *)
(*AutoAssistant Processing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tags*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorTaggedQ*)
errorTaggedQ // ClearAll;
errorTaggedQ[ s_  ] := taggedQ[ s, "ERROR" ];
errorTaggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*warningTaggedQ*)
warningTaggedQ // ClearAll;
warningTaggedQ[ s_  ] := taggedQ[ s, "WARNING" ];
warningTaggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*infoTaggedQ*)
infoTaggedQ // ClearAll;
infoTaggedQ[ s_  ] := taggedQ[ s, "INFO" ];
infoTaggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*untaggedQ*)
untaggedQ // ClearAll;
untaggedQ[ as_Association? AssociationQ ] := untaggedQ @ as[ "FullContent" ];
untaggedQ[ s0_String? StringQ ] /; $alwaysOpen :=
    With[ { s = StringDelete[ $lastUntagged = s0, Whitespace ] },
        Or[ StringStartsQ[ s, Except[ "[" ] ],
            StringLength @ s >= $maxTagLength && ! StringStartsQ[ s, $$tagPrefix, IgnoreCase -> True ]
        ]
    ];

untaggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*taggedQ*)
taggedQ // ClearAll;
taggedQ[ s_ ] := taggedQ[ s, $$severityTag ];
taggedQ[ as_Association? AssociationQ, tag_ ] := taggedQ[ as[ "FullContent" ], tag ];
taggedQ[ s_String? StringQ, tag_ ] := StringStartsQ[ StringDelete[ s, Whitespace ], "["~~tag~~"]", IgnoreCase -> True ];
taggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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
(* ::Subsubsection::Closed:: *)
(*untagString*)
untagString // beginDefinition;

untagString[ as: KeyValuePattern @ { "FullContent" -> full_, "DynamicContent" -> dynamic_ } ] :=
    Association[ as, "FullContent" -> untagString @ full, "DynamicContent" -> untagString @ dynamic ];

untagString[ str_String? StringQ ] := StringDelete[ str, $$tagPrefix, IgnoreCase -> True ];

untagString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Minimized Assistant Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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
(* ::Subsubsection::Closed:: *)
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
(* ::Subsubsection::Closed:: *)
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
(*Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WriteChatOutputCell*)
WriteChatOutputCell[ cell_, new_Cell, info_ ] /; $InlineChat :=
    writeInlineChatOutputCell[ cell, new, info ];

WriteChatOutputCell[
    cell_CellObject,
    new_Cell,
    info: KeyValuePattern @ { "ExpressionUUID" -> uuid_String, "ScrollOutput" -> scroll_ }
] :=
    Module[ { output },
        output = CellObject @ uuid;
        NotebookWrite[ cell, new, None, AutoScroll -> False ];
        attachChatOutputMenu @ output;
        scrollOutput[ TrueQ @ scroll, output ];
    ];

WriteChatOutputCell[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", WriteChatOutputCell, HoldForm @ WriteChatOutputCell @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createNewChatOutput*)
createNewChatOutput // beginDefinition;
createNewChatOutput[ settings_, target_, cell_Cell ] /; $InlineChat := createNewInlineOutput[ settings, target, cell ];
createNewChatOutput[ settings_, None, cell_Cell ] := cellPrint @ cell;
createNewChatOutput[ settings_, target_, cell_Cell ] /; settings[ "TabbedOutput" ] === False := cellPrint @ cell;
createNewChatOutput[ settings_, target_CellObject, cell_Cell ] := prepareChatOutputPage[ target, cell ];
createNewChatOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareChatOutputPage*)
prepareChatOutputPage // beginDefinition;

prepareChatOutputPage[ target_CellObject, cell_Cell ] := Enclose[
    Catch @ Module[ { prevCellExpr, prevPage, encoded, pageData, newCellObject },

        prevCellExpr = ConfirmMatch[ NotebookRead @ target, _Cell | $Failed, "NotebookRead" ];

        If[ FailureQ @ prevCellExpr,
            (* The target cell is gone, so just create a new one instead of trying to page outputs: *)
            Throw @ cellPrint @ cell
        ];

        If[ MatchQ[ prevCellExpr, Cell[ BoxData[ TagBox[ _, "DynamicTextDisplay", ___ ], ___ ], ___ ] ],
            (* The target cell is a left-over dynamic chat output that hasn't been cleaned up properly,
               so delete it and create a new chat output. *)
            NotebookDelete @ target;
            Throw @ cellPrint @ cell
        ];

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
    throwInternalFailure
];

prepareChatOutputPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*activeAIAssistantCell*)
activeAIAssistantCell // beginDefinition;
activeAIAssistantCell // Attributes = { HoldFirst };

activeAIAssistantCell[ container_, settings_Association? AssociationQ, cellTags_ ] :=
    activeAIAssistantCell[ container, settings, cellTags, Lookup[ settings, "ShowMinimized", Automatic ] ];

activeAIAssistantCell[
    container_,
    settings: KeyValuePattern[ "CellObject" :> cellObject_ ],
    cellTags0_,
    minimized_
] /; $cloudNotebooks :=
    With[
        {
            label     = RawBoxes @ TemplateBox[ { }, "MinimizedChatActive" ],
            id        = $SessionID,
            reformat  = dynamicAutoFormatQ @ settings,
            task      = Lookup[ settings, "Task" ],
            formatter = getFormattingFunction @ settings,
            cellTags  = Replace[ cellTags0, Except[ _String | { ___String } ] :> Inherited ],
            outer     = If[ TrueQ[ $WorkspaceChat||$InlineChat ], assistantMessageBox, # & ]
        },
        Module[ { x = 0 },
            ClearAttributes[ { x, cellObject }, Temporary ];
            Cell[
                BoxData @ outer @ ToBoxes @
                    If[ TrueQ @ reformat,
                        Dynamic[
                            Refresh[
                                x++;
                                If[ MatchQ[ $reformattedCell, _Cell ],
                                    Pause[ 1 ];
                                    NotebookWrite[ cellObject, $reformattedCell ];
                                    Remove[ x, cellObject ];
                                    ,
                                    catchTop @ dynamicTextDisplay[ container, formatter, reformat ]
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
                                catchTop @ dynamicTextDisplay[ container, formatter, reformat ]
                            ],
                            Initialization   :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ],
                            Deinitialization :> Quiet @ TaskRemove @ task
                        ]
                    ],
                "Output",
                "ChatOutput",
                Sequence @@ Flatten[ { $closedChatCellOptions } ],
                Selectable      -> False,
                Editable        -> False,
                If[ TrueQ @ settings[ "SetCellDingbat" ],
                    CellDingbat -> Cell[ BoxData @ makeActiveOutputDingbat @ settings, Background -> None ],
                    Sequence @@ { }
                ],
                CellTags           -> cellTags,
                CellTrayWidgets    -> <| "ChatFeedback" -> <| "Visible" -> False |> |>,
                PrivateCellOptions -> { "ContentsOpacity" -> 1 },
                TaggingRules       -> <| "ChatNotebookSettings" -> smallSettings @ settings |>
            ]
        ]
    ];

activeAIAssistantCell[
    container_,
    settings: KeyValuePattern[ "CellObject" :> cellObject_ ],
    cellTags0_,
    minimized_
] :=
    With[
        {
            label     = RawBoxes @ TemplateBox[ { }, "MinimizedChatActive" ],
            id        = $SessionID,
            reformat  = dynamicAutoFormatQ @ settings,
            task      = Lookup[ settings, "Task" ],
            uuid      = container[ "UUID" ],
            formatter = getFormattingFunction @ settings,
            cellTags  = Replace[ cellTags0, Except[ _String | { ___String } ] :> Inherited ],
            outer     = If[ TrueQ[ $WorkspaceChat||$InlineChat ], assistantMessageBox, # & ]
        },
        Cell[
            BoxData @ outer @ TagBox[
                ToBoxes @ Dynamic[
                    $dynamicTrigger;
                    (* `$dynamicTrigger` is used to precisely control when the dynamic updates, otherwise we can get an
                       FE crash if a NotebookWrite happens at the same time. *)
                    catchTop @ dynamicTextDisplay[ container, formatter, reformat ],
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
            If[ TrueQ @ $AutomaticAssistance && MatchQ[ minimized, True|Automatic ],
                Sequence @@ Flatten[ {
                    $closedChatCellOptions,
                    Initialization :> catchTop @ attachMinimizedIcon[ EvaluationCell[ ], label ]
                } ],
                Initialization -> None
            ],
            If[ TrueQ @ settings[ "SetCellDingbat" ],
                CellDingbat -> Cell[ BoxData @ makeActiveOutputDingbat @ settings, Background -> None ],
                Sequence @@ { }
            ],
            CellEditDuplicate  -> False,
            CellTags           -> cellTags,
            CellTrayWidgets    -> <| "ChatFeedback" -> <| "Visible" -> False |> |>,
            CodeAssistOptions  -> { "AutoDetectHyperlinks" -> False },
            Editable           -> True,
            LanguageCategory   -> None,
            LineIndent         -> 0,
            PrivateCellOptions -> { "ContentsOpacity" -> 1 },
            Selectable         -> True,
            ShowAutoSpellCheck -> False,
            ShowCursorTracker  -> False,
            TaggingRules       -> <| "ChatNotebookSettings" -> smallSettings @ settings |>,
            If[ scrollOutputQ @ settings,
                PrivateCellOptions -> { "TrackScrollingWhenPlaced" -> True },
                Sequence @@ { }
            ]
        ]
    ];

activeAIAssistantCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getFormattingFunction*)
getFormattingFunction // beginDefinition;

getFormattingFunction[ as_? AssociationQ ] :=
    getFormattingFunction[ as, getProcessingFunction[ as, "FormatChatOutput" ] ];

getFormattingFunction[ as_, func_ ] := (
    $ChatHandlerData[ "EventName" ] = "FormatChatOutput";
    func @ ##
) &;

getFormattingFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolFormatter*)
getToolFormatter // beginDefinition;

getToolFormatter[ as_? AssociationQ ] :=
    getToolFormatter[ as, getProcessingFunction[ as, "FormatToolCall" ] ];

getToolFormatter[ as_, func_ ] := (
    $ChatHandlerData[ "EventName" ] = "FormatToolCall";
    func @ ##
) &;

getToolFormatter // endDefinition;

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

dynamicTextDisplay[ container_, formatter_, reformat_ ] /; $highlightDynamicContent :=
    Block[ { $highlightDynamicContent = False },
        Framed[ dynamicTextDisplay[ container, formatter, reformat ], FrameStyle -> Purple ]
    ];

dynamicTextDisplay[ container_, formatter_, True ] := With[
    {
        data = <|
            "Status"    -> If[ StringQ @ container[ "DynamicContent" ], "Streaming", "Waiting" ],
            "Container" :> container,
            $ChatHandlerData
        |>
    },
    conformToExpression @ formatter[ container[ "DynamicContent" ], data ]
];

dynamicTextDisplay[ container_, formatter_, False ] /; StringQ @ container[ "DynamicContent" ] :=
    RawBoxes @ Cell @ TextData @ container[ "DynamicContent" ];

dynamicTextDisplay[ _Symbol, _, _ ] := ProgressIndicator[ Appearance -> "Percolate" ];

dynamicTextDisplay[ other_, _, _ ] := other;

dynamicTextDisplay // endDefinition;

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
(*makeOutputDingbat*)
makeOutputDingbat // beginDefinition;
makeOutputDingbat[ as: KeyValuePattern[ "LLMEvaluator" -> name_String ] ] := makeOutputDingbat[ as, name ];
makeOutputDingbat[ as: KeyValuePattern[ "LLMEvaluator" -> config_Association ] ] := makeOutputDingbat[ as, config ];
makeOutputDingbat[ as_Association ] := makeOutputDingbat[ as, as ];
makeOutputDingbat[ as_, name_String ] := makeOutputDingbat[ as, GetCachedPersonaData @ name ];
makeOutputDingbat[ as_, KeyValuePattern[ "PersonaIcon" -> icon_ ] ] := makeOutputDingbat[ as, icon ];
makeOutputDingbat[ as_, KeyValuePattern[ "Icon" -> icon_ ] ] := makeOutputDingbat[ as, icon ];
makeOutputDingbat[ as_, KeyValuePattern[ "Default" -> icon_ ] ] := makeOutputDingbat[ as, icon ];
makeOutputDingbat[ as_, _Association|_Missing|_Failure|None ] := TemplateBox[ { }, "AssistantIcon" ];
makeOutputDingbat[ as_, icon_ ] := toDingbatBoxes @ resizeDingbat @ icon;
makeOutputDingbat // endDefinition;

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

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toDingbatBoxes*)
toDingbatBoxes // beginDefinition;
toDingbatBoxes[ icon_ ] := toDingbatBoxes[ icon ] = toCompressedBoxes @ icon;
toDingbatBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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

writeReformattedCell[ settings_, string0_String, cell_CellObject ] := Enclose[
    Block[ { $dynamicText = False },
        Module[ { string, tag, scroll, open, label, pageData, cellTags, uuid, new, output, createTask, info },

            string = ConfirmBy[ StringTrim @ string0, StringQ, "String" ];

            tag = ConfirmMatch[
                Replace[ CurrentValue[ cell, { TaggingRules, "MessageTag" } ], $Failed -> Inherited ],
                _String|Inherited,
                "Tag"
            ];

            scroll   = scrollOutputQ[ settings, cell ];
            open     = $lastOpen = cellOpenQ @ cell;
            label    = RawBoxes @ TemplateBox[ { }, "MinimizedChat" ];
            pageData = CurrentValue[ cell, { TaggingRules, "PageData" } ];
            cellTags = CurrentValue[ cell, CellTags ];
            uuid     = CreateUUID[ ];
            new      = reformatCell[ settings, string, tag, open, label, pageData, cellTags, uuid ];
            output   = uuidToCellObject[ uuid, cell ];

            $lastChatString  = string;
            $reformattedCell = new;
            $lastChatOutput  = output;

            createTask = If[ TrueQ @ sufficientVersionQ[ "TaskWriteOutput" ], createFETask, Identity ];

            info = addProcessingArguments[
                "WriteChatOutputCell",
                <|
                    "EvaluationCell" -> output,
                    "Result"         -> string,
                    "ScrollOutput"   -> scroll,
                    "CellOpen"       -> open,
                    "ExpressionUUID" -> uuid
                |>
            ];

            With[ { new = new, info = info },
                createTask @ applyProcessingFunction[ settings, "WriteChatOutputCell", HoldComplete[ cell, new, info ] ]
            ];

            waitForCellObject[ settings, output ]
        ]
    ],
    throwInternalFailure
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
(*uuidToCellObject*)
uuidToCellObject // beginDefinition;
uuidToCellObject[ uuid_String, cell_CellObject ] /; $cloudNotebooks := uuidToCellObject[ uuid, parentNotebook @ cell ];
uuidToCellObject[ uuid1_String, NotebookObject[ _, uuid2_String ] ] := CellObject[ uuid1, uuid2 ];
uuidToCellObject[ uuid_String, _ ] := CellObject @ uuid;
uuidToCellObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*waitForCellObject*)
waitForCellObject // beginDefinition;

waitForCellObject[ settings_, cell_CellObject, timeout_: 1 ] :=
    If[ settings[ "HandlerFunctions", "ChatPost" ] =!= None,
        TimeConstrained[ While[ ! StringQ @ CurrentValue[ cell, ExpressionUUID ], Pause[ 0.05 ] ], timeout ];
        cell
    ];

waitForCellObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*scrollOutputQ*)
scrollOutputQ // beginDefinition;

scrollOutputQ[ settings_Association ] :=
    TrueQ @ Replace[ settings[ "TrackScrollingWhenPlaced" ],
                     $$unspecified :> sufficientVersionQ[ "TrackScrollingWhenPlaced" ]
            ];

scrollOutputQ[ settings_Association, cell_ ] := False;

scrollOutputQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*scrollOutput*)
scrollOutput // beginDefinition;

scrollOutput[ True, cell_ ] := (
    SelectionMove[ cell, Before, Cell, AutoScroll -> True ];
    SelectionMove[ cell, After , Cell, AutoScroll -> True ];
);

scrollOutput[ False, cell_ ] := Null;

scrollOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reformatCell*)
reformatCell // beginDefinition;

(* FIXME: why does this actually need UsingFrontEnd here? *)
reformatCell[ settings_, string_, tag_, open_, label_, pageData_, cellTags_, uuid_ ] := usingFrontEnd @ Enclose[
    Module[ { formatter, toolFormatter, content, rules, dingbat, outer },

        formatter = Confirm[ getFormattingFunction @ settings, "GetFormattingFunction" ];
        toolFormatter = Confirm[ getToolFormatter @ settings, "GetToolFormatter" ];

        content = Block[ { $customToolFormatter = toolFormatter },
            ConfirmMatch[
                If[ TrueQ @ settings[ "AutoFormat" ],
                    conformToTextData @ formatter[ string, settings ],
                    TextData @ string
                ],
                TextData[ _String | _List ],
                "Content"
            ]
        ];

        rules = ConfirmBy[
            makeReformattedCellTaggingRules[ settings, string, tag, content, pageData ],
            AssociationQ,
            "TaggingRules"
        ];

        dingbat = makeOutputDingbat @ settings;

        outer = If[ TrueQ @ $WorkspaceChat,
                    TextData @ {
                        Cell[
                            BoxData @ TemplateBox[ { Cell[ #, Background -> None ] }, "AssistantMessageBox" ],
                            Background -> None
                        ]
                    } &,
                    # &
                ];

        Cell[
            outer @ content,
            If[ TrueQ @ $AutomaticAssistance,
                Switch[ tag,
                        "[ERROR]"  , "AssistantOutputError",
                        "[WARNING]", "AssistantOutputWarning",
                        _          , "AssistantOutput"
                ],
                "ChatOutput"
            ],
            GeneratedCell     -> True,
            CellAutoOverwrite -> True,
            CellTags          -> cellTags,
            TaggingRules      -> rules,
            If[ TrueQ[ rules[ "PageData", "PageCount" ] > 1 ],
                CellDingbat -> Cell[ BoxData @ TemplateBox[ { dingbat }, "AssistantIconTabbed" ], Background -> None ],
                If[ TrueQ @ settings[ "SetCellDingbat" ],
                    CellDingbat -> Cell[ BoxData @ dingbat, Background -> None ],
                    Sequence @@ { }
                ]
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
    throwInternalFailure
];

reformatCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*conformToTextData*)
conformToTextData // beginDefinition;
conformToTextData[ text_TextData ] := text;
conformToTextData[ text_List ] := TextData @ Flatten @ Map[ conformToTextData0, Flatten @ { text } ];
conformToTextData[ expr_ ] := conformToTextData @ { expr };
conformToTextData // endDefinition;


conformToTextData0 // beginDefinition;
conformToTextData0[ text_String ] := text;
conformToTextData0[ (Cell|TextData)[ text_ ] ] := conformToTextData0 @ text;
conformToTextData0[ Cell[ text_, "ChatOutput" ] ] := conformToTextData0 @ text;
conformToTextData0[ text: $$textData ] := text;
conformToTextData0[ boxes_BoxData ] := Cell @ boxes;
conformToTextData0[ expr_ ] := With[ { b = ToBoxes @ expr }, conformToTextData0 @ b /; MatchQ[ b, $$textData ] ];
conformToTextData0[ expr_ ] := Cell @ BoxData @ ToBoxes @ expr;
conformToTextData0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*conformToExpression*)
conformToExpression // beginDefinition;
conformToExpression[ expr_ ] := RawBoxes @ Cell @ conformToTextData @ expr;
conformToExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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
    DeleteCases[ <|
            "CellToStringData" -> string,
            "MessageTag"       -> tag,
            "ChatData"         -> makeCompactChatData[ string, tag, settings ],
            "PageData"         -> <|
                "Pages"      -> Append[ pages, p -> BaseEncode @ BinarySerialize[ content, PerformanceGoal -> "Size" ] ],
                "PageCount"  -> p,
                "CurrentPage"-> p
            |>
        |>,
        Inherited
    ]
];

makeReformattedCellTaggingRules[ settings_, string_, tag: _String|Inherited, content_, pageData_ ] :=
    DeleteCases[
        <|
            "CellToStringData" -> string,
            "MessageTag"       -> tag,
            "ChatData"         -> makeCompactChatData[ string, tag, settings ]
        |>,
        Inherited
    ];

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
        DeleteCases[
            Association[
                smallSettings @ as,
                "MessageTag" -> tag,
                "Data" -> Association[
                    data,
                    "Messages" -> revertMultimodalContent @ Append[
                        messages,
                        <| "Role" -> "Assistant", "Content" -> message |>
                    ]
                ]
            ],
            Inherited
        ],
        PerformanceGoal -> "Size"
    ];

makeCompactChatData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*smallSettings*)
smallSettings // beginDefinition;
smallSettings[ as_Association ] := smallSettings0 @ KeyDrop[ as, { "OpenAIKey", "Tokenizer" } ] /. $exprToNameRules;
smallSettings // endDefinition;

smallSettings0 // beginDefinition;

smallSettings0[ as: KeyValuePattern[ "Model" -> model: KeyValuePattern[ "Icon" -> _ ] ] ] :=
    smallSettings0 @ <| as, "Model" -> KeyTake[ model, { "Service", "Name" } ] |>;

smallSettings0[ as_Association ] :=
    smallSettings0[ as, as[ "LLMEvaluator" ] ];

smallSettings0[ as_, KeyValuePattern[ "LLMEvaluatorName" -> name_String ] ] :=
    If[ AssociationQ @ GetCachedPersonaData @ name,
        Append[ as, "LLMEvaluator" -> name ],
        as
    ];

smallSettings0[ as_, _ ] :=
    as;

smallSettings0 // endDefinition;


$exprToNameRules := AssociationMap[ Reverse, $AvailableTools ];

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
    Lookup[ Options[ cell, Initialization ] /. HoldPattern @ EvaluationCell[ ] -> cell, Initialization ]
);

attachChatOutputMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeErrorCell*)
writeErrorCell // beginDefinition;
writeErrorCell[ cell_, failure_Failure ] := (createFETask @ NotebookDelete @ cell; failure);
writeErrorCell[ cell_, as_ ] := (createFETask @ NotebookWrite[ cell, errorCell @ as ]; Null);
writeErrorCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorCell*)
errorCell // beginDefinition;

errorCell[ failure_Failure ] :=
    Cell[ BoxData @ ToBoxes @ failure, "Output" ];

errorCell[ as_ ] := Enclose[
    Module[ { text },
        text = ConfirmMatch[ errorText @ as, _String|$$textDataList, "ErrorText" ];
        Cell[
            TextData @ Flatten @ {
                StyleBox[ "\[WarningSign] ", FontColor -> Darker @ Red, FontSize -> 1.5 Inherited ],
                If[ StringQ @ text,
                    {
                        text,
                        "\n\n",
                        Cell @ BoxData @ Quiet @ errorBoxes @ as
                    },
                    text
                ]
            },
            "Text",
            "ChatOutput",
            CellAutoOverwrite -> True,
            CellTrayWidgets   -> <| "ChatFeedback" -> <| "Visible" -> False |> |>,
            CodeAssistOptions -> { "AutoDetectHyperlinks" -> True },
            GeneratedCell     -> True,
            Initialization    -> None
        ]
    ],
    throwInternalFailure
];

errorCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorText*)
errorText // ClearAll;

errorText[ KeyValuePattern[ "Error" -> "ServerResponseEmpty" ] ] :=
    Chatbook::ServerResponseEmpty;

errorText[ KeyValuePattern[ "BodyJSON" -> json_ ] ] :=
    With[ { text = errorText0 @ json },
        text /; StringQ @ text || MatchQ[ text, $$textDataList ]
    ];

errorText[ KeyValuePattern[
    "BodyJSON" -> KeyValuePattern[ "Error"|"error" -> KeyValuePattern[ "Message"|"message" -> text_String ] ]
] ] := serverMessageTextData @ text;

errorText[ str_String ] := str;
errorText[ failure_Failure ] := ToString @ failure[ "Message" ];
errorText[ ___ ] := "An unexpected error occurred.";


(* Overrides for server messages can be defined here: *)
errorText0 // ClearAll;

errorText0[ KeyValuePattern[ "Error"|"error"|"GeneralResponseEntity" -> error_Association ] ] :=
    errorText0 @ error;

errorText0[ as: KeyValuePattern @ { "Code"|"code" -> code_, "Message"|"message" -> message_ } ] :=
    errorText0[ as, code, message ];

errorText0[ as: KeyValuePattern @ { "Message"|"message" -> message_ } ] :=
    errorText0[ as, None, message ];

errorText0[ as_, "model_not_found", message_String ] :=
    Module[ { link, help },
        If[ StringContainsQ[ message, "https://"|"http://" ],
            serverMessageTextData @ message,
            link = textLink[ "here", "https://platform.openai.com/docs/models/overview" ];
            help = { " Click ", link, " for information about available models." };
            Flatten @ {
                StringReplace[
                    StringTrim[ message, "." ] <> ".",
                    "`" ~~ model: Except[ "`" ].. ~~ "`" :> "\""<>model<>"\""
                ],
                help
            }
        ]
    ];

errorText0[ as_, "context_length_exceeded", message_String ] :=
    StringReplace[
        message,
        "Please reduce the length of the messages." ->
            "Try using chat delimiters in order to reduce the total size of conversations."
    ];

errorText0[ as_, code_, message_String ] :=
    serverMessageTextData @ message;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serverMessageTextData*)
serverMessageTextData // beginDefinition;

serverMessageTextData[ textData: _String | $$textDataList ] := Flatten @ {
    Chatbook::ServerMessageHeader,
    StyleBox[ #, FontOpacity -> 0.75, FontSlant -> Italic ] & /@ Flatten @ { textData }
};

serverMessageTextData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
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
errorBoxes[ as: KeyValuePattern[ "Error" -> "ServerResponseEmpty" ] ] :=
    ToBoxes @ messageFailure[ "ServerResponseEmpty", as ];

errorBoxes[ as: KeyValuePattern[ "StatusCode" -> 429 ] ] :=
    ToBoxes @ messageFailure[ "RateLimitReached", as ];

errorBoxes[ as: KeyValuePattern[ "StatusCode" -> code: Except[ 200 ] ] ] :=
    ToBoxes @ messageFailure[ "UnknownStatusCode", as ];

errorBoxes[ failure_Failure ] :=
    ToBoxes @ failure;

errorBoxes[ as___ ] :=
    ToBoxes @ messageFailure[ "UnknownResponse", as ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $autoSettingKeyPriority;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
