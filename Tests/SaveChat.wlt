(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/SaveChat.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/SaveChat.wlt:11,1-16,2"
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
    TestID   -> "Definitions@@Tests/SaveChat.wlt:24,1-181,2"
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
    TestID   -> "AutoSave-DoesNotWaitForTitle@@Tests/SaveChat.wlt:190,1-199,2"
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
    TestID   -> "AutoSave-TitleCallback@@Tests/SaveChat.wlt:201,1-217,2"
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
    TestID   -> "AutoSave-TitleCallbackUpdatesHistory@@Tests/SaveChat.wlt:219,1-231,2"
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
    TestID   -> "AutoSave-CachedTitle@@Tests/SaveChat.wlt:233,1-246,2"
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
    TestID   -> "AutoSave-PreviousTitleUntilReady@@Tests/SaveChat.wlt:248,1-262,2"
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
    TestID   -> "AutoSave-LateCallback@@Tests/SaveChat.wlt:264,1-278,2"
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
    TestID   -> "AutoSave-SupersededCallback@@Tests/SaveChat.wlt:280,1-295,2"
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
    TestID   -> "AutoSave-CallbackKeepsNewerMessages@@Tests/SaveChat.wlt:297,1-311,2"
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
    TestID   -> "AutoSave-CallbackDuringSave@@Tests/SaveChat.wlt:313,1-329,2"
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
    TestID   -> "AutoSave-DeferredTitles@@Tests/SaveChat.wlt:331,1-347,2"
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
    TestID   -> "AutoSave-RetryAfterFailure@@Tests/SaveChat.wlt:352,1-372,2"
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
    TestID   -> "AutoSave-RetryMaxLength@@Tests/SaveChat.wlt:374,1-387,2"
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
    TestID   -> "AutoSave-FailureFallback@@Tests/SaveChat.wlt:389,1-415,2"
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
    TestID   -> "AutoSave-APIErrorResponse@@Tests/SaveChat.wlt:417,1-447,2"
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
    TestID   -> "AutoSave-UnexpectedResponse@@Tests/SaveChat.wlt:449,1-461,2"
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
    TestID   -> "AutoSave-RetrySubmitFailure@@Tests/SaveChat.wlt:463,1-483,2"
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
    TestID   -> "AutoSave-CallbackInternalFailure@@Tests/SaveChat.wlt:485,1-498,2"
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
    TestID   -> "AutoSave-DeletedChat@@Tests/SaveChat.wlt:500,1-511,2"
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
    TestID   -> "AutoSave-TitleChangedInMeantime@@Tests/SaveChat.wlt:513,1-526,2"
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
    TestID   -> "AutoSave-TitleChangedDuringSave@@Tests/SaveChat.wlt:528,1-543,2"
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
    TestID   -> "ExplicitSave-WaitsForTitle@@Tests/SaveChat.wlt:548,1-559,2"
]

VerificationTest[
    withMockTitles @ Block[
        {
            Wolfram`Chatbook`Common`llmSynthesizeSubmit        = mockTitleSubmitTimed,
            Wolfram`Chatbook`Storage`Private`$backgroundTitles = Automatic,
            (* The tests can run with a front end (e.g. in CI), so simulate a kernel without one: *)
            $Notebooks = False
        },
        Module[ { uuid, result },
            uuid   = CreateUUID[ ];
            (* Without a front end, the callback might never run, so auto-saves wait for the title: *)
            result = SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
            { result[ "ConversationTitle" ], savedTitleState[ uuid ][ "Title" ] }
        ]
    ],
    { "Timed Title", "Timed Title" },
    SameTest -> MatchQ,
    TestID   -> "AutoSave-NoFrontEnd@@Tests/SaveChat.wlt:561,1-579,2"
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
    TestID   -> "AutoSave-BackgroundTitleQ@@Tests/SaveChat.wlt:581,1-597,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Pop Out From History*)
VerificationTest[
    withMockTitles @ UsingFrontEnd @ Module[ { windowUUID, poppedUUID, windowSettings, nbo },
        windowUUID = CreateUUID[ ];
        poppedUUID = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ windowUUID, "AutoSaveOnly" -> True ];
        SaveChat[ titleTestMessages[ 2 ], titleTestSettings @ poppedUUID, "AutoSaveOnly" -> True ];
        (* The settings of the assistant window, which has a different chat loaded: *)
        windowSettings = <|
            titleTestSettings @ windowUUID,
            "Tools"          -> { "NotebookEditor" },
            "SetCellDingbat" -> False,
            "Model"          -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>
        |>;
        nbo = Wolfram`Chatbook`ChatModes`UI`Private`popOutChatNB0[
            <| "AppName" -> $titleTestApp, "ConversationUUID" -> poppedUUID |>,
            windowSettings
        ];
        WithCleanup[
            {
                CurrentChatSettings[ nbo, "ConversationUUID" ] =!= windowUUID,
                CurrentChatSettings[ nbo, "AppName" ] =!= $titleTestApp,
                Wolfram`Chatbook`Common`resolveAutoSettings[
                    Wolfram`Chatbook`Common`currentChatSettings @ nbo
                ][ "AutoSaveConversations" ],
                Lookup[
                    Replace[
                        CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings" } ],
                        Except[ _Association ] -> <| |>
                    ],
                    { "ConversationUUID", "AppName", "AutoSaveConversations", "Tools", "SetCellDingbat" },
                    None
                ],
                CurrentChatSettings[ nbo, "Model" ],
                Count[ NotebookGet[ nbo ][[ 1 ]], Cell[ __, "ChatInput", ___ ], Infinity ],
                LoadChat[ $titleTestApp, windowUUID ][ "Messages" ] === titleTestMessages[ 1 ]
            },
            NotebookClose @ nbo
        ]
    ],
    {
        True,
        True,
        False,
        { None, None, None, None, None },
        KeyValuePattern @ { "Service" -> "OpenAI", "Name" -> "gpt-4o" },
        2,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "PopOutFromHistory-DropsWindowSettings@@Tests/SaveChat.wlt:602,1-652,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Open Sidebar As Assistant Window*)
VerificationTest[
    (* A headless front end has no sidebar, so an ordinary cell holding a scrolling content cell stands in for it: *)
    sidebarStandIn[ text_String ] := Cell[
        BoxData @ RowBox @ {
            Cell[
                BoxData @ RowBox @ {
                    Cell[ text, "NotebookAssistant`Sidebar`ChatInput", CellTags -> "SidebarTopCell" ],
                    Cell[ text <> " reply", "NotebookAssistant`Sidebar`ChatOutput", CellTags -> "SidebarTopCell" ]
                },
                "Text",
                CellTags -> "SidebarScrollingContentCell"
            ]
        },
        "Text"
    ];

    (* Presses the button and returns the notebook it opened: *)
    pressOpenSidebarAsWindow[ nbo_, sidebarCell_ ] := Module[ { button, before },
        button = Wolfram`Chatbook`ChatModes`UI`Private`sidebarOpenAsAssistantWindowButton[ nbo, sidebarCell ];
        before = Notebooks[ ];
        ReleaseHold @ Extract[ button, 2, Hold ];
        First[ Complement[ Notebooks[ ], before ], $Failed ]
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "OpenSidebarAsWindow-Definitions@@Tests/SaveChat.wlt:657,1-683,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { oldUUID, nbo, sidebarCell, window },
        oldUUID = CreateUUID[ ];
        nbo = CreateDocument[ { sidebarStandIn[ "SIDEBAR-FIRST" ] }, Visible -> False ];
        sidebarCell = First @ Cells @ nbo;
        CurrentChatSettings[ sidebarCell, "ConversationUUID" ] = oldUUID;
        CurrentChatSettings[ sidebarCell, "SidebarChat" ] = True;
        window = pressOpenSidebarAsWindow[ nbo, sidebarCell ];
        WithCleanup[
            {
                CurrentChatSettings[ window, "ConversationUUID" ] === oldUUID,
                TrueQ @ CurrentChatSettings[ window, "SidebarChat" ],
                CurrentChatSettings[ sidebarCell, "ConversationUUID" ] =!= oldUUID,
                StringQ @ CurrentChatSettings[ sidebarCell, "ConversationUUID" ]
            },
            Quiet[ NotebookClose /@ { window, nbo } ]
        ]
    ],
    { True, False, True, True },
    SameTest -> MatchQ,
    TestID   -> "OpenSidebarAsWindow-KeepsConversationUUID@@Tests/SaveChat.wlt:685,1-706,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { existingUUID, sidebarUUID, existing, nbo, sidebarCell, window },
        existingUUID = CreateUUID[ ];
        sidebarUUID  = CreateUUID[ ];
        (* An assistant window that already has an unrelated conversation: *)
        existing = ShowNotebookAssistance[
            None,
            "Window",
            "NewChat"              -> True,
            "ChatNotebookSettings" -> <| "ConversationUUID" -> existingUUID, "AutoSaveConversations" -> False |>
        ];
        SelectionMove[ existing, After, Notebook ];
        NotebookWrite[ existing, { Cell[ "MANGO-3", "ChatInput" ], Cell[ "MANGO-3 reply", "ChatOutput" ] } ];
        nbo = CreateDocument[ { sidebarStandIn[ "SIDEBAR-FIRST" ] }, Visible -> False ];
        sidebarCell = First @ Cells @ nbo;
        CurrentChatSettings[ sidebarCell, "ConversationUUID" ] = sidebarUUID;
        CurrentChatSettings[ sidebarCell, "SidebarChat" ] = True;
        window = pressOpenSidebarAsWindow[ nbo, sidebarCell ];
        WithCleanup[
            {
                MatchQ[ window, _NotebookObject ],
                MemberQ[ Notebooks[ ], existing ],
                CurrentChatSettings[ window, "ConversationUUID" ] === sidebarUUID,
                Cases[ NotebookRead @ Cells @ window, Cell[ s_String, ___ ] :> s ]
            },
            Quiet[ NotebookClose /@ { window, nbo, existing } ]
        ]
    ],
    { True, False, True, { "SIDEBAR-FIRST", "SIDEBAR-FIRST reply" } },
    SameTest -> MatchQ,
    TestID   -> "OpenSidebarAsWindow-ReplacesExistingWindow@@Tests/SaveChat.wlt:708,1-739,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load From History*)
VerificationTest[
    savedChatDirectory[ uuid_String ] := Last[
        FileNames[ "*_" <> uuid, ChatbookFilesDirectory[ { "SavedChats", $titleTestApp }, "EnsureDirectory" -> False ] ],
        Missing[ "NotSaved" ]
    ];

    (* An invisible stand-in for the assistant window, with the scrollbar hidden like attachOverlayMenu does: *)
    withHistoryTestWindow[ test_ ] := UsingFrontEnd @ Module[ { nbo = CreateDocument[ { }, Visible -> False ] },
        CurrentChatSettings[ nbo, "AppName" ] = $titleTestApp;
        WithCleanup[ test @ nbo, NotebookClose @ nbo ]
    ];

    scrollbarQ[ nbo_ ] := MemberQ[ AbsoluteCurrentValue[ nbo, WindowElements ], "VerticalScrollBar" ];
    overlayTags[ nbo_ ] := CurrentValue[ Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedOverlayMenu" ], CellTags ];

    (* Like a second click on the History button; the reopened History hides the scrollbar until it is closed: *)
    closeHistory[ nbo_ ] := (
        Wolfram`Chatbook`ChatModes`Common`toggleOverlayMenu[ nbo, None, "History" ];
        scrollbarQ @ nbo && overlayTags @ nbo === { }
    );
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadFromHistory-Definitions@@Tests/SaveChat.wlt:744,1-768,2"
]

(* An unreadable data.wxf (corrupt, or locked by another process) does not delete the chat: *)
VerificationTest[
    withMockTitles @ Module[ { uuid, dir },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        dir = savedChatDirectory @ uuid;
        WriteString[ FileNameJoin @ { dir, "data.wxf" }, "not a wxf file" ];
        Close @ FileNameJoin @ { dir, "data.wxf" };
        {
            LoadChat[ $titleTestApp, uuid ],
            DirectoryQ @ dir,
            FileExistsQ @ FileNameJoin @ { dir, "metadata.wxf" }
        }
    ],
    { Missing[ "Corrupt" ], True, True },
    SameTest -> MatchQ,
    TestID   -> "LoadChat-CorruptDataKeepsChat@@Tests/SaveChat.wlt:771,1-787,2"
]

(* A chat folder without data.wxf can't be recovered, so it is removed: *)
VerificationTest[
    withMockTitles @ Module[ { uuid, dir },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        dir = savedChatDirectory @ uuid;
        DeleteFile @ FileNameJoin @ { dir, "data.wxf" };
        { LoadChat[ $titleTestApp, uuid ], DirectoryQ @ dir }
    ],
    { Missing[ "NotFound" ], False },
    SameTest -> MatchQ,
    TestID   -> "LoadChat-MissingDataRemovesChat@@Tests/SaveChat.wlt:790,1-801,2"
]

(* Loading a History row whose chat is gone restores the scrollbar, shows History again and writes no error cell: *)
VerificationTest[
    withHistoryTestWindow @ Function[ nbo,
        Wolfram`Chatbook`ChatModes`UI`Private`hideVerticalScrollbar @ nbo;
        {
            Wolfram`Chatbook`ChatModes`UI`Private`loadConversation[
                nbo,
                None,
                <| "AppName" -> $titleTestApp, "ConversationUUID" -> CreateUUID[ ] |>
            ],
            overlayTags @ nbo,
            Cells @ nbo,
            closeHistory @ nbo
        }
    ],
    { Null, { "History" }, { }, True },
    SameTest -> MatchQ,
    TestID   -> "LoadFromHistory-StaleRow@@Tests/SaveChat.wlt:804,1-821,2"
]

(* Same for a chat whose data can't be read, which is kept: *)
VerificationTest[
    withMockTitles @ Module[ { uuid, dir },
        uuid = CreateUUID[ ];
        SaveChat[ titleTestMessages[ 1 ], titleTestSettings @ uuid, "AutoSaveOnly" -> True ];
        dir = savedChatDirectory @ uuid;
        WriteString[ FileNameJoin @ { dir, "data.wxf" }, "not a wxf file" ];
        Close @ FileNameJoin @ { dir, "data.wxf" };
        withHistoryTestWindow @ Function[ nbo,
            Wolfram`Chatbook`ChatModes`UI`Private`hideVerticalScrollbar @ nbo;
            {
                Wolfram`Chatbook`ChatModes`UI`Private`loadConversation[
                    nbo,
                    None,
                    <| "AppName" -> $titleTestApp, "ConversationUUID" -> uuid |>
                ],
                overlayTags @ nbo,
                Cells @ nbo,
                closeHistory @ nbo,
                DirectoryQ @ dir
            }
        ]
    ],
    { Null, { "History" }, { }, True, True },
    SameTest -> MatchQ,
    TestID   -> "LoadFromHistory-CorruptChat@@Tests/SaveChat.wlt:824,1-849,2"
]

(* The scrollbar is also restored when loading fails unexpectedly: *)
VerificationTest[
    withHistoryTestWindow @ Function[ nbo,
        Wolfram`Chatbook`ChatModes`UI`Private`hideVerticalScrollbar @ nbo;
        {
            Block[ { LoadChat = <| "ConversationUUID" -> 1 |> & },
                Head @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`ChatModes`UI`Private`loadConversation[
                    nbo,
                    None,
                    <| "AppName" -> $titleTestApp, "ConversationUUID" -> CreateUUID[ ] |>
                ]
            ],
            scrollbarQ @ nbo,
            overlayTags @ nbo
        }
    ],
    { Failure, True, { } },
    { General::ChatbookInternal },
    SameTest -> MatchQ,
    TestID   -> "LoadFromHistory-InternalFailure@@Tests/SaveChat.wlt:852,1-871,2"
]

(* Popping out a History row whose chat is gone opens no notebook, shows History again and writes no error cell: *)
VerificationTest[
    withHistoryTestWindow @ Function[ nbo,
        Module[ { before, result },
            before = Notebooks[ ];
            result = Wolfram`Chatbook`ChatModes`UI`Private`popOutChatNB0[
                <| "AppName" -> $titleTestApp, "ConversationUUID" -> CreateUUID[ ] |>,
                <| |>
            ];
            {
                result,
                Wolfram`Chatbook`ChatModes`UI`Private`popOutFromHistory[
                    nbo,
                    None,
                    <| "AppName" -> $titleTestApp, "ConversationUUID" -> CreateUUID[ ] |>
                ],
                Complement[ Notebooks[ ], before ],
                overlayTags @ nbo,
                Cells @ nbo,
                closeHistory @ nbo
            }
        ]
    ],
    { Missing[ "NotFound" ], Null, { }, { "History" }, { }, True },
    SameTest -> MatchQ,
    TestID   -> "PopOutFromHistory-StaleRow@@Tests/SaveChat.wlt:874,1-899,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*History Refresh*)

(* The default History view re-reads its chats when saved chats change (deleted or saved elsewhere): *)
VerificationTest[
    withHistoryTestWindow @ Function[ nbo,
        FirstCase[
            Wolfram`Chatbook`ChatModes`UI`Private`makeDefaultHistoryView0[
                nbo,
                None,
                Dynamic @ $historyTestPage,
                Dynamic @ $historyTestTotalPages
            ],
            DynamicWrapper[ _DynamicWrapper, update_, opts___ ] :> {
                ! FreeQ[ Unevaluated @ update, _Wolfram`Chatbook`ChatModes`UI`Private`readHistoryChats ],
                { opts }
            },
            Missing[ ],
            Infinity
        ]
    ],
    {
        True,
        {
            OrderlessPatternSequence[
                TrackedSymbols :> { Wolfram`Chatbook`Dynamics`Private`$savedChatsTrigger },
                SynchronousUpdating -> False
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "HistoryRefresh-DefaultViewTracksSavedChats@@Tests/SaveChat.wlt:906,1-934,2"
]

(* Deleting and saving chats update the trigger, and re-reading lists the current chats: *)
VerificationTest[
    withMockTitles @ Module[ { first, second, third, read, trigger, refreshTitles, shown, afterDelete, afterSave },
        first   = CreateUUID[ ];
        second  = CreateUUID[ ];
        third   = CreateUUID[ ];
        read    = Wolfram`Chatbook`ChatModes`UI`Private`readHistoryChats;
        trigger = Wolfram`Chatbook`Dynamics`Private`$savedChatsTrigger &;
        (* The app also has chats saved by earlier tests: *)
        refreshTitles = Sort @ Select[ Lookup[ #, "ConversationTitle" ], StringStartsQ[ "Refresh " ] ] &;
        SaveChat[ titleTestMessages[ 1 ], <| titleTestSettings @ first , "ConversationTitle" -> "Refresh One" |> ];
        SaveChat[ titleTestMessages[ 2 ], <| titleTestSettings @ second, "ConversationTitle" -> "Refresh Two" |> ];
        shown = read[ $titleTestApp, None ];
        afterDelete = { trigger[ ], DeleteChat[ $titleTestApp, first ]; trigger[ ], read[ $titleTestApp, shown ] };
        afterSave = {
            trigger[ ],
            SaveChat[ titleTestMessages[ 3 ], <| titleTestSettings @ third, "ConversationTitle" -> "Refresh Three" |> ];
            trigger[ ],
            read[ $titleTestApp, shown ]
        };
        {
            refreshTitles @ shown,
            Less @@ Most @ afterDelete,
            refreshTitles @ Last @ afterDelete,
            Less @@ Most @ afterSave,
            refreshTitles @ Last @ afterSave,
            (* If storage can't be read, the rows that are shown are kept: *)
            Block[ { ListSavedChats = $Failed & }, read[ $titleTestApp, shown ] === shown ]
        }
    ],
    {
        { "Refresh One", "Refresh Two" },
        True,
        { "Refresh Two" },
        True,
        { "Refresh Three", "Refresh Two" },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "HistoryRefresh-ReadsCurrentChats@@Tests/SaveChat.wlt:937,1-976,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    titleTestCleanup[ ];
    DirectoryQ @ ChatbookFilesDirectory[ { "SavedChats", $titleTestApp }, "EnsureDirectory" -> False ],
    False,
    SameTest -> MatchQ,
    TestID   -> "Cleanup@@Tests/SaveChat.wlt:981,1-987,2"
]

(* :!CodeAnalysis::EndBlock:: *)
