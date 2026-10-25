(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* Saved chats only go to this app, which is deleted at the end: *)
    $titleTestApp   = "ChatbookTestsBackgroundTitles";
    $mockTitleTasks = { };

    titleTestCleanup[ ] := (
        Quiet[ TaskRemove /@ $mockTitleTasks ];
        $mockTitleTasks = { };
        Quiet @ DeleteDirectory[
            ChatbookFilesDirectory[ { "SavedChats", $titleTestApp }, "EnsureDirectory" -> False ],
            DeleteContents -> True
        ];
        Quiet @ DeleteDirectory[
            ChatbookFilesDirectory[ { "Search", $titleTestApp }, "EnsureDirectory" -> False ],
            DeleteContents -> True
        ];
        If[ AssociationQ @ Wolfram`Chatbook`Search`Private`$chatSearchIndex,
            KeyDropFrom[ Wolfram`Chatbook`Search`Private`$chatSearchIndex, $titleTestApp ]
        ];
    );

    titleTestCleanup[ ];

    titleTestMessages[ n_Integer ] := Flatten @ Table[
        {
            <| "Role" -> "User"     , "Content" -> "Question " <> ToString @ i |>,
            <| "Role" -> "Assistant", "Content" -> "Answer "   <> ToString @ i |>
        },
        { i, n }
    ];

    titleTestSettings[ uuid_String ] := <|
        "AppName"               -> $titleTestApp,
        "ConversationUUID"      -> uuid,
        "AutoSaveConversations" -> True
    |>;

    (* Simulates the title LLM: requests stay pending until they are answered with respondTitle: *)
    mockTitleSubmit[ prompt_, evaluator_, callback_ ] := Module[ { task },
        AppendTo[ $mockTitleCallbacks, callback ];
        AppendTo[ $mockTitleEvaluators, evaluator ];
        AppendTo[ $mockTitleLLMKit, Wolfram`Chatbook`Common`$llmKit ];
        task = SessionSubmit @ ScheduledTask[ Null, { 3600 } ];
        AppendTo[ $mockTitleTasks, task ];
        task
    ];

    respondTitle[ i_Integer, response_, status_: 200 ] :=
        $mockTitleCallbacks[[ i ]][ response, <| "StatusCode" -> status |> ];

    (* Responds while the request is being submitted: *)
    mockTitleSubmitImmediate[ prompt_, evaluator_, callback_ ] := Module[ { task },
        task = mockTitleSubmit[ prompt, evaluator, callback ];
        callback[ "Immediate Title", <| "StatusCode" -> 200 |> ];
        task
    ];

    (* Responds after a short delay like a real request: *)
    mockTitleSubmitTimed[ prompt_, evaluator_, callback_ ] := (
        AppendTo[ $mockTitleCallbacks, callback ];
        SessionSubmit @ ScheduledTask[ callback[ "Timed Title", <| "StatusCode" -> 200 |> ], { 0.2 } ]
    );

    (* Fails like a request whose LLMKit check failed (see llmKitCheck): *)
    mockTitleSubmitCheckFailure[ prompt_, evaluator_, callback_ ] :=
        Wolfram`Chatbook`Common`throwFailureToChatOutput @ Failure[ "LLMKitCheck", <| "MessageTemplate" -> "Test" |> ];

    (* Returns something that isn't a task, which is an internal failure: *)
    mockTitleSubmitInvalid[ prompt_, evaluator_, callback_ ] :=
        $Failed;

    withMockTitles // Attributes = { HoldFirst };
    withMockTitles[ eval_ ] := Block[
        {
            Wolfram`Chatbook`Common`llmSynthesizeSubmit           = mockTitleSubmit,
            Wolfram`Chatbook`Common`$llmKitService                = "LLMKitTest",
            Wolfram`Chatbook`Storage`Private`$backgroundTitles    = True,
            Wolfram`Chatbook`Storage`Private`$generatedTitleCache = <| |>,
            Wolfram`Chatbook`Storage`Private`$titleTasks          = <| |>,
            Wolfram`Chatbook`Storage`Private`$titleTargets        = <| |>,
            Wolfram`Chatbook`Storage`Private`$deferredTitles      = <| |>,
            $mockTitleCallbacks  = { },
            $mockTitleEvaluators = { },
            $mockTitleLLMKit     = { }
        },
        eval
    ];

    (* Simulates LLMServices`ChatSubmit instead, so the response handlers of llmSynthesizeSubmit are used: *)
    mockChatSubmit[ messages_, config_, opts___ ] := Module[ { task },
        AppendTo[ $mockChatSubmitHandlers, Lookup[ { opts }, HandlerFunctions ] ];
        task = SessionSubmit @ ScheduledTask[ Null, { 3600 } ];
        AppendTo[ $mockTitleTasks, task ];
        task
    ];

    respondChatSubmit[ i_Integer, chunk_, status_Integer ] :=
        With[ { handlers = $mockChatSubmitHandlers[[ i ]] },
            handlers[ "BodyChunkReceived" ][ <| "BodyChunkProcessed" -> chunk, "StatusCode" -> status |> ];
            handlers[ "TaskFinished" ][ <| "StatusCode" -> status |> ]
        ];

    withMockChatSubmit // Attributes = { HoldFirst };
    withMockChatSubmit[ eval_ ] := Block[
        {
            LLMServices`ChatSubmit                                = mockChatSubmit,
            Wolfram`Chatbook`Common`$llmKit                       = False,
            Wolfram`Chatbook`Storage`Private`$backgroundTitles    = True,
            Wolfram`Chatbook`Storage`Private`$generatedTitleCache = <| |>,
            Wolfram`Chatbook`Storage`Private`$titleTasks          = <| |>,
            Wolfram`Chatbook`Storage`Private`$titleTargets        = <| |>,
            Wolfram`Chatbook`Storage`Private`$deferredTitles      = <| |>,
            $mockChatSubmitHandlers = { }
        },
        eval
    ];

    (* Reads the title from everywhere it is saved: *)
    savedTitleState[ uuid_String ] := Module[ { dirs, dir, meta, data, index, vectors },
        dirs = FileNames[
            "*_" <> uuid,
            ChatbookFilesDirectory[ { "SavedChats", $titleTestApp }, "EnsureDirectory" -> False ]
        ];
        If[ dirs === { }, Return[ Missing[ "NotSaved" ], Module ] ];
        dir     = Last @ dirs;
        meta    = Developer`ReadWXFFile @ FileNameJoin @ { dir, "metadata.wxf" };
        data    = Developer`ReadWXFFile @ FileNameJoin @ { dir, "data.wxf" };
        vectors = data[ "Vectors" ];
        index   = Quiet @ Developer`ReadWXFFile @ FileNameJoin @ {
            ChatbookFilesDirectory[ { "Search", $titleTestApp }, "EnsureDirectory" -> False ],
            "index.wxf"
        };
        <|
            "Title"       -> meta[ "ConversationTitle" ],
            "DataTitle"   -> data[ "ConversationTitle" ],
            "Messages"    -> Length @ data[ "Messages" ],
            "IndexTitle"  -> If[ AssociationQ @ index, index[ "Index", uuid, "ConversationTitle" ], None ],
            "TitleVector" -> If[ vectors === { },
                                 None,
                                 First @ vectors === Wolfram`Chatbook`Storage`Private`toInt8Vector @
                                     Wolfram`Chatbook`Common`getEmbedding @ meta[ "ConversationTitle" ]
                             ]
        |>
    ];

    (* The search index and title vectors only exist with semantic search: *)
    expectedTitleState[ title_String, messages_Integer ] := <|
        "Title"       -> title,
        "DataTitle"   -> title,
        "Messages"    -> messages,
        "IndexTitle"  -> If[ TrueQ @ Wolfram`Chatbook`Common`$noSemanticSearch, _, title ],
        "TitleVector" -> If[ TrueQ @ Wolfram`Chatbook`Common`$noSemanticSearch, None, True ]
    |>;
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Auto-Saving*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Background Titles*)
VerificationTest[
    withMockTitles @ Module[ { uuid, result },
        uuid   = CreateUUID[ ];
        result = SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        { result[ "ConversationTitle" ], Length @ $mockTitleCallbacks, savedTitleState[ uuid ][ "Title" ] }
    ],
    { "Untitled Chat", 1, "Untitled Chat" },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-DoesNotWaitForTitle"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, settings },
        uuid     = CreateUUID[ ];
        settings = titleTestSettings @ uuid;
        SaveChat[ titleTestMessages[ 1 ], settings, "AutoSaveOnly" -> True ];
        respondTitle[ 1, "Title A" ];
        {
            savedTitleState @ uuid,
            (* The title is cached, so the next save with the same messages uses it immediately: *)
            SaveChat[ titleTestMessages[ 1 ], settings, "AutoSaveOnly" -> True ][ "ConversationTitle" ],
            Length @ $mockTitleCallbacks
        }
    ],
    { expectedTitleState[ "Title A", 2 ], "Title A", 1 },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-TitleCallback"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, before },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        before = Wolfram`Chatbook`Dynamics`Private`$savedChatsTrigger;
        respondTitle[ 1, "Title A" ];
        (* The callback refreshes the history list, so it shows the new title: *)
        Wolfram`Chatbook`Dynamics`Private`$savedChatsTrigger > before
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "AutoSave-TitleCallbackUpdatesHistory"
]

VerificationTest[
    withMockTitles @ Module[ { first, second, result },
        first  = CreateUUID[ ];
        second = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ first, "AutoSaveOnly" -> True ];
        respondTitle[ 1, "Title A" ];
        (* The title for these messages is cached, so another chat with the same messages uses it right away: *)
        result = SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ second, "AutoSaveOnly" -> True ];
        { result[ "ConversationTitle" ], Length @ $mockTitleCallbacks, savedTitleState @ second }
    ],
    { "Title A", 1, expectedTitleState[ "Title A", 2 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-CachedTitle"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, settings, result },
        uuid     = CreateUUID[ ];
        settings = titleTestSettings @ uuid;
        SaveChat[ titleTestMessages[ 1 ], settings, "AutoSaveOnly" -> True ];
        respondTitle[ 1, "Title A" ];
        (* The previously saved title is kept until the new one is ready: *)
        result = SaveChat[ titleTestMessages[ 2 ], settings, "AutoSaveOnly" -> True ];
        respondTitle[ 2, "Title B" ];
        { result[ "ConversationTitle" ], Length @ $mockTitleCallbacks, savedTitleState @ uuid }
    ],
    { "Title A", 2, expectedTitleState[ "Title B", 4 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-PreviousTitleUntilReady"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, settings },
        uuid     = CreateUUID[ ];
        settings = titleTestSettings @ uuid;
        SaveChat[ titleTestMessages[ 1 ], settings, "AutoSaveOnly" -> True ];
        SaveChat[ titleTestMessages[ 2 ], settings, "AutoSaveOnly" -> True ];
        respondTitle[ 2, "Title B" ];
        (* A late response for an older save must not replace the newer title: *)
        respondTitle[ 1, "Title A" ];
        { savedTitleState @ uuid, Length @ Wolfram`Chatbook`Storage`Private`$generatedTitleCache }
    ],
    { expectedTitleState[ "Title B", 4 ], 2 },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-LateCallback"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, settings, superseded },
        uuid     = CreateUUID[ ];
        settings = titleTestSettings @ uuid;
        SaveChat[ titleTestMessages[ 1 ], settings, "AutoSaveOnly" -> True ];
        SaveChat[ titleTestMessages[ 2 ], settings, "AutoSaveOnly" -> True ];
        (* The chat was saved again before the first title arrived, so only the newer title is used: *)
        respondTitle[ 1, "Title A" ];
        superseded = savedTitleState[ uuid ][ "Title" ];
        respondTitle[ 2, "Title B" ];
        { superseded, savedTitleState @ uuid }
    ],
    { "Untitled Chat", expectedTitleState[ "Title B", 4 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-SupersededCallback"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, settings },
        uuid     = CreateUUID[ ];
        settings = titleTestSettings @ uuid;
        SaveChat[ titleTestMessages[ 5 ], settings, "AutoSaveOnly" -> True ];
        (* The title only depends on the first 10 messages, so this doesn't need a new title: *)
        SaveChat[ titleTestMessages[ 6 ], settings, "AutoSaveOnly" -> True ];
        respondTitle[ 1, "Title C" ];
        (* Only the title is updated, so the newer messages are kept: *)
        { Length @ $mockTitleCallbacks, savedTitleState @ uuid }
    ],
    { 1, expectedTitleState[ "Title C", 12 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-CallbackKeepsNewerMessages"
]

VerificationTest[
    withMockTitles @ Block[ { Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockTitleSubmitImmediate },
        Module[ { uuid, result },
            uuid   = CreateUUID[ ];
            result = SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
            (* The title arrived before the chat was written, so it's saved once the auto-save is done: *)
            {
                result[ "ConversationTitle" ],
                savedTitleState @ uuid,
                Wolfram`Chatbook`Storage`Private`$deferredTitles
            }
        ]
    ],
    { "Untitled Chat", expectedTitleState[ "Immediate Title", 2 ], <| |> },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-CallbackDuringSave"
]

VerificationTest[
    withMockTitles @ Module[ { uuid },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        (* A title that arrives during another auto-save is saved once that's done: *)
        Block[ { Wolfram`Chatbook`Storage`Private`$autoSaving = True }, respondTitle[ 1, "Title D" ] ];
        {
            Wolfram`Chatbook`Storage`Private`$deferredTitles,
            savedTitleState[ uuid ][ "Title" ],
            Wolfram`Chatbook`Storage`Private`applyDeferredTitles[ ];
            savedTitleState @ uuid
        }
    ],
    { <| _Integer -> "Title D" |>, "Untitled Chat", expectedTitleState[ "Title D", 2 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-DeferredTitles"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Failures*)
VerificationTest[
    withMockTitles @ Module[ { uuid },
        uuid = CreateUUID[ ];
        (* The chat does not use LLMKit: *)
        Block[ { Wolfram`Chatbook`Common`$llmKit = False },
            SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ]
        ];
        (* An invalid title is retried once with a higher temperature and the same LLMKit settings: *)
        Block[ { Wolfram`Chatbook`Common`$llmKit = True }, respondTitle[ 1, "Not a\ntitle" ] ];
        respondTitle[ 2, "Title E" ];
        {
            Length @ $mockTitleCallbacks,
            Lookup[ $mockTitleEvaluators, "Temperature" ],
            $mockTitleLLMKit,
            savedTitleState @ uuid
        }
    ],
    { 2, { 0.7, 1.0 }, { False, False }, expectedTitleState[ "Title E", 2 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-RetryAfterFailure"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, title },
        uuid = CreateUUID[ ];
        (* Too long for the first attempt (MaxLength 50), but not for the retry (MaxLength 60): *)
        title = "Comparing Interpolation Methods for Irregularly Scattered Measurement Data";
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        respondTitle[ 1, title ];
        respondTitle[ 2, title ];
        { Length @ $mockTitleCallbacks, savedTitleState @ uuid }
    ],
    { 2, expectedTitleState[ "Comparing Interpolation Methods for Irregularly Scattered Measurement Data", 2 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-RetryMaxLength"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, settings, thrown },
        uuid     = CreateUUID[ ];
        settings = titleTestSettings @ uuid;
        SaveChat[ titleTestMessages[ 1 ], settings, "AutoSaveOnly" -> True ];
        respondTitle[ 1, "Title A" ];
        SaveChat[ titleTestMessages[ 2 ], settings, "AutoSaveOnly" -> True ];
        (* Errors in the callback are not thrown into whatever evaluation it interrupted: *)
        thrown = Wolfram`Chatbook`Common`catchTop[
            respondTitle[ 2, Failure[ "APIError", <| "MessageTemplate" -> "Test error" |> ], 500 ];
            "NotThrown"
        ];
        respondTitle[ 3, "Not a\ntitle" ];
        {
            thrown,
            Length @ $mockTitleCallbacks,
            (* Same as a synchronous save when both attempts fail: *)
            savedTitleState @ uuid,
            (* The default title is not cached, so the next save tries again: *)
            SaveChat[ titleTestMessages[ 2 ], settings, "AutoSaveOnly" -> True ];
            Length @ $mockTitleCallbacks
        }
    ],
    { "NotThrown", 3, expectedTitleState[ "Untitled Chat", 4 ], 4 },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-FailureFallback"
]

VerificationTest[
    withMockChatSubmit @ Module[ { uuid, chatTask, thrown },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        (* An API error response arrives while another chat is running: *)
        chatTask = SessionSubmit @ ScheduledTask[ Null, { 3600 } ];
        AppendTo[ $mockTitleTasks, chatTask ];
        thrown = Block[ { Wolfram`Chatbook`Common`$lastTask = chatTask },
            Wolfram`Chatbook`Common`catchTop[
                respondChatSubmit[
                    1,
                    Failure[ "APIError", <| "MessageTemplate" -> "Test error", "StatusCode" -> 429 |> ],
                    429
                ];
                "NotThrown"
            ]
        ];
        (* The error is not thrown into that chat, its task is not removed, and the title is retried: *)
        respondChatSubmit[ 2, "Title H", 200 ];
        {
            thrown,
            chatTask[ "TaskStatus" ],
            Length @ $mockChatSubmitHandlers,
            savedTitleState @ uuid,
            Wolfram`Chatbook`Storage`Private`$titleTasks
        }
    ],
    { "NotThrown", Except[ "Removed" ], 2, expectedTitleState[ "Title H", 2 ], <| |> },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-APIErrorResponse"
]

VerificationTest[
    withMockChatSubmit @ Module[ { uuid },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        (* A response that can't be processed is an internal failure, which issues no messages and is retried: *)
        respondChatSubmit[ 1, Failure[ "BodyChunkProcessingFailure", <| "MessageTemplate" -> "Test" |> ], 200 ];
        respondChatSubmit[ 2, "Title H", 200 ];
        { Length @ $mockChatSubmitHandlers, savedTitleState @ uuid, Wolfram`Chatbook`Storage`Private`$titleTasks }
    ],
    { 2, expectedTitleState[ "Title H", 2 ], <| |> },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-UnexpectedResponse"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, chatTask, thrown },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        (* The retry can't be submitted, and the callback runs while another chat is running: *)
        chatTask = SessionSubmit @ ScheduledTask[ Null, { 3600 } ];
        AppendTo[ $mockTitleTasks, chatTask ];
        thrown = Block[
            {
                Wolfram`Chatbook`Common`$lastTask            = chatTask,
                Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockTitleSubmitCheckFailure
            },
            Wolfram`Chatbook`Common`catchTop[ respondTitle[ 1, "Not a\ntitle" ]; "NotThrown" ]
        ];
        (* The failure is not thrown into that chat, its task is not removed, and the saved title is kept: *)
        { thrown, chatTask[ "TaskStatus" ], Length @ $mockTitleCallbacks, savedTitleState @ uuid }
    ],
    { "NotThrown", Except[ "Removed" ], 1, expectedTitleState[ "Untitled Chat", 2 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-RetrySubmitFailure"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, thrown },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        (* Internal failures in the callback issue no messages and are not thrown into the evaluation it interrupted: *)
        thrown = Block[ { Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockTitleSubmitInvalid },
            Wolfram`Chatbook`Common`catchTop[ respondTitle[ 1, "Not a\ntitle" ]; "NotThrown" ]
        ];
        { thrown, savedTitleState @ uuid }
    ],
    { "NotThrown", expectedTitleState[ "Untitled Chat", 2 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-CallbackInternalFailure"
]

VerificationTest[
    withMockTitles @ Module[ { uuid },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        DeleteChat[ $titleTestApp, uuid ];
        respondTitle[ 1, "Title F" ];
        savedTitleState @ uuid
    ],
    Missing[ "NotSaved" ],
    SameTest -> MatchQ,
    TestID   -> "AutoSave-DeletedChat"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, settings },
        uuid     = CreateUUID[ ];
        settings = titleTestSettings @ uuid;
        SaveChat[ titleTestMessages[ 1 ], settings, "AutoSaveOnly" -> True ];
        SaveChat[ titleTestMessages[ 1 ], <| settings, "ConversationTitle" -> "Custom Title" |> ];
        (* The chat was saved with a different title in the meantime, so it's left alone: *)
        respondTitle[ 1, "Title G" ];
        savedTitleState @ uuid
    ],
    expectedTitleState[ "Custom Title", 2 ],
    SameTest -> MatchQ,
    TestID   -> "AutoSave-TitleChangedInMeantime"
]

VerificationTest[
    withMockTitles @ Module[ { uuid, dir, file, state },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        (* A save with a different title is in progress: it has written the metadata, but not the data yet: *)
        dir  = ChatbookFilesDirectory[ { "SavedChats", $titleTestApp }, "EnsureDirectory" -> False ];
        file = FileNameJoin @ { Last @ FileNames[ "*_" <> uuid, dir ], "metadata.wxf" };
        Developer`WriteWXFFile[ file, <| Developer`ReadWXFFile @ file, "ConversationTitle" -> "Custom Title" |> ];
        respondTitle[ 1, "Title G" ];
        state = savedTitleState @ uuid;
        { state[ "Title" ], state[ "DataTitle" ] }
    ],
    { "Custom Title", "Untitled Chat" },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-TitleChangedDuringSave"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Synchronous Titles*)
VerificationTest[
    withMockTitles @ Block[ { Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockTitleSubmitTimed },
        Module[ { uuid, result },
            uuid   = CreateUUID[ ];
            result = SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid ];
            { result[ "ConversationTitle" ], savedTitleState[ uuid ][ "Title" ] }
        ]
    ],
    { "Timed Title", "Timed Title" },
    SameTest -> MatchQ,
    TestID   -> "ExplicitSave-WaitsForTitle"
]

VerificationTest[
    withMockTitles @ Block[
        {
            Wolfram`Chatbook`Common`llmSynthesizeSubmit        = mockTitleSubmitTimed,
            Wolfram`Chatbook`Storage`Private`$backgroundTitles = Automatic
        },
        Module[ { uuid, result },
            uuid   = CreateUUID[ ];
            (* Without a front end, the callback might never run, so auto-saves wait for the title: *)
            result = SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
            { $Notebooks, result[ "ConversationTitle" ], savedTitleState[ uuid ][ "Title" ] }
        ]
    ],
    { False, "Timed Title", "Timed Title" },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-NoFrontEnd"
]

VerificationTest[
    With[ { q = Wolfram`Chatbook`Storage`Private`backgroundTitleQ, settings = titleTestSettings @ CreateUUID[ ] },
        Block[ { Wolfram`Chatbook`Storage`Private`$autoSaving = True },
            (* With the default $backgroundTitles, auto-saves only generate titles in the background with a front end,
               not in the cloud, and only for chats that have a ConversationUUID: *)
            {
                Block[ { $Notebooks = True , $CloudEvaluation = False }, q @ settings ],
                Block[ { $Notebooks = True , $CloudEvaluation = True  }, q @ settings ],
                Block[ { $Notebooks = False, $CloudEvaluation = False }, q @ settings ],
                Block[ { $Notebooks = True , $CloudEvaluation = False }, q @ KeyDrop[ settings, "ConversationUUID" ] ]
            }
        ]
    ],
    { True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-BackgroundTitleQ"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    titleTestCleanup[ ];
    DirectoryQ @ ChatbookFilesDirectory[ { "SavedChats", $titleTestApp }, "EnsureDirectory" -> False ],
    False,
    SameTest -> MatchQ,
    TestID   -> "Cleanup"
]

(* :!CodeAnalysis::EndBlock:: *)
