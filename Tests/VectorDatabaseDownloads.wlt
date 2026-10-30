(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/VectorDatabaseDownloads.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/VectorDatabaseDownloads.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)

VerificationTest[
    $name   = "NeuralNetRepositoryURIs";
    $root   = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "VDBTest-" <> CreateUUID[ ] };
    $urls   = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadURLs;
    $prompts = { };
    DirectoryQ @ $root && AssociationQ @ $urls,
    True,
    SameTest -> MatchQ,
    TestID   -> "Setup@@Tests/VectorDatabaseDownloads.wlt:22,1-31,2"
]

(* Helpers *)
withPrompt // Attributes = { HoldRest };
withPrompt[ answer_, eval_ ] :=
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed = True,
            Wolfram`Chatbook`PromptGenerators`Common`$downloadPromptFunction = (AppendTo[ $prompts, # ]; answer) &
        },
        eval
    ];

(* Gives the result of eval and the times that were estimated for trying a download again (see confirmDownloadRetry): *)
withRetryEstimates // Attributes = { HoldFirst };
withRetryEstimates[ eval_ ] :=
    Module[ { estimates = { }, result },
        result = Internal`InheritedBlock[ { Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime },
            (* Prepended, since a more general definition would otherwise be tried after the existing ones: *)
            DownValues @ Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime = Prepend[
                DownValues @ Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime,
                HoldPattern @ Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime[ args___ ] :>
                    Block[ { $inEstimate = True },
                        Last @ AppendTo[ estimates, Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime @ args ]
                    ] /; ! TrueQ @ $inEstimate
            ];
            eval
        ];
        { result, estimates }
    ];

download[ name_String ] := download[ name, KeyTake[ $urls, { name } ] ];
download[ name_String, urls_ ] :=
    Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadVectorDatabases[ $root, urls ];

dbDir[ ] := FileNameJoin @ { $root, $name };
validQ[ ] := Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBDirectoryQ0[ dbDir[ ] ];

truncateIndex[ ] := With[ { f = FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" } },
    With[ { b = ReadByteArray @ f }, DeleteFile @ f; BinaryWrite[ f, b[[ 1 ;; 100000 ]] ]; Close @ f ]
];

(* Stubs for URLDownloadSubmit and URLDownload, so that tests of failing downloads don't need the network. Responses
   are given by URL (any other URL gives a 404 response), and $requestedURLs records the requested URLs. A response can
   give the "StatusCode", the "Body" or a "File" with the content, the "ByteCountTotal" reported by the server (the
   size of the content by default), and a "Delay" in seconds: *)
$requestedURLs = { };
$notFound      = <| "StatusCode" -> 404, "Body" -> StringToByteArray[ "<Error><Code>NoSuchKey</Code></Error>" ] |>;

fakeResponse[ url_String ] := Lookup[ $fakeResponses, url, $notFound ];

writeFakeResponse[ file_String, response_Association ] := (
    Pause @ Lookup[ response, "Delay", 0 ];
    If[ StringQ @ response[ "File" ],
        CopyFile[ response[ "File" ], file, OverwriteTarget -> True ],
        BinaryWrite[ file, response[ "Body" ] ];
        Close @ file
    ];
    FileByteCount @ file
);

fakeURLDownloadSubmit[ url_String, file_String, opts___ ] := Module[ { response, size, total, handlers },
    AppendTo[ $requestedURLs, url ];
    response = fakeResponse @ url;
    size     = writeFakeResponse[ file, response ];
    total    = Lookup[ response, "ByteCountTotal", size ];
    handlers = Lookup[ Association @ Flatten @ { opts }, HandlerFunctions ];
    handlers[ "TaskProgress" ][ <| "ByteCountDownloaded" -> size, "ByteCountTotal" -> total |> ];
    handlers[ "TaskFinished" ][ <| "StatusCode" -> response[ "StatusCode" ], "ByteCountDownloaded" -> size, "ByteCountTotal" -> total |> ];
    (* A task that has already finished: *)
    TaskObject[ <| |> ]
];

fakeURLDownload[ url_String, file_String, props_List ] := Module[ { response, size },
    AppendTo[ $requestedURLs, url ];
    response = fakeResponse @ url;
    size     = writeFakeResponse[ file, response ];
    KeyTake[
        <|
            "File"       -> File @ file,
            "StatusCode" -> response[ "StatusCode" ],
            "Headers"    -> { "content-length" -> ToString @ Lookup[ response, "ByteCountTotal", size ] }
        |>,
        props
    ]
];

withFakeDownloads // Attributes = { HoldRest };
withFakeDownloads[ responses_Association, eval_ ] := Block[
    { $fakeResponses = responses, URLDownloadSubmit = fakeURLDownloadSubmit, URLDownload = fakeURLDownload },
    $requestedURLs = { };
    eval
];

(* Evaluates eval with a definition prepended to the definitions of f that gives result for the first n calls: *)
failFirstCalls // Attributes = { HoldAll };
failFirstCalls[ f_Symbol, n_Integer, result_, eval_ ] := Module[ { calls = 0 },
    Internal`InheritedBlock[ { f },
        DownValues[ f ] = Prepend[ DownValues @ f, HoldPattern[ f[ ___ ] ] :> Condition[ calls++; result, calls < n ] ];
        eval
    ]
];

$testURLs = <| $name -> <| "CDN" -> "https://cdn.test/" <> $name <> ".zip", "Cloud" -> "https://cloud.test/" <> $name <> ".zip" |> |>;
$cdnURL   = $testURLs[ $name, "CDN"   ];
$cloudURL = $testURLs[ $name, "Cloud" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt Helpers*)
VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime[ 100*^6, 1*^6 ],
    100.,
    SameTest -> Equal,
    TestID   -> "EstimateDownloadTime@@Tests/VectorDatabaseDownloads.wlt:141,1-146,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime[ 10*^6, None ],
    5.,
    SameTest -> Equal,
    TestID   -> "EstimateDownloadTime-FallbackRate@@Tests/VectorDatabaseDownloads.wlt:148,1-153,2"
]

VerificationTest[
    $prompts = { };
    withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ 1*^6, 1*^6 ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-ShortNoPrompt@@Tests/VectorDatabaseDownloads.wlt:155,1-161,2"
]

VerificationTest[
    $prompts,
    { },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-ShortNoPrompt-Check@@Tests/VectorDatabaseDownloads.wlt:163,1-168,2"
]

VerificationTest[
    withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ 370*^6, 1*^6 ] ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-LongPrompts@@Tests/VectorDatabaseDownloads.wlt:170,1-175,2"
]

VerificationTest[
    $prompts,
    { _String? (StringContainsQ[ "try again" ]) },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-LongPrompts-Check@@Tests/VectorDatabaseDownloads.wlt:177,1-182,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed = False },
        Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ 370*^6, 1*^6 ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-HeadlessProceeds@@Tests/VectorDatabaseDownloads.wlt:184,1-191,2"
]

(* Evaluates eval with a stubbed StopChat and returns { result, list of StopChat calls }: *)
countStopChat // Attributes = { HoldFirst };
countStopChat[ eval_ ] := Module[ { calls = { }, result },
    Block[ { Wolfram`Chatbook`Actions`StopChat },
        Wolfram`Chatbook`Actions`StopChat[ args___ ] := (AppendTo[ calls, { args } ]; Null);
        result = eval
    ];
    { result, calls }
];

$fakeChatCell = CellObject[ "00000000-0000-0000-0000-000000000000", "00000000-0000-0000-0000-000000000000" ];

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        countStopChat @ withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
    ],
    { False, { { } } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-CancelStopsChat@@Tests/VectorDatabaseDownloads.wlt:205,1-212,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        countStopChat @ withPrompt[ True, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-AcceptDoesNotStopChat@@Tests/VectorDatabaseDownloads.wlt:214,1-221,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = None },
        countStopChat @ withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
    ],
    { False, { } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-CancelOutsideChatDoesNotStopChat@@Tests/VectorDatabaseDownloads.wlt:223,1-230,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        countStopChat @ withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ 370*^6, 1*^6 ] ]
    ],
    { False, { { } } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-CancelStopsChat@@Tests/VectorDatabaseDownloads.wlt:232,1-239,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        Block[ { Wolfram`Chatbook`Actions`StopChat },
            Wolfram`Chatbook`Actions`StopChat[ ] := Wolfram`Chatbook`Common`throwInternalFailure @ "StopChatFailed";
            withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-StopChatFailureStillDeclines@@Tests/VectorDatabaseDownloads.wlt:241,1-251,2"
]

(* Only an explicit "Cancel" declines: a prompt that could not be shown (e.g. ChoiceDialog::ninit in a front end that
   was launched by UsingFrontEnd in a headless kernel) proceeds as it does without a front end: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        countStopChat @ withPrompt[ $Failed, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-DialogFailedProceeds-GH#1612@@Tests/VectorDatabaseDownloads.wlt:255,1-262,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell,
            Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed = True,
            Wolfram`Chatbook`PromptGenerators`Common`$downloadPromptFunction = (Message[ ChoiceDialog::ninit, ChoiceDialog ]; $Failed) &
        },
        countStopChat @ Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ 370*^6, 1*^6 ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-DialogNotInitializedProceeds-GH#1612@@Tests/VectorDatabaseDownloads.wlt:264,1-276,2"
]

(* Closing the dialog declines, like "Cancel": *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        countStopChat @ withPrompt[ $Canceled, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
    ],
    { False, { { } } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-ClosedDialogDeclines-GH#1612@@Tests/VectorDatabaseDownloads.wlt:279,1-286,2"
]

(* A front end launched by UsingFrontEnd in a headless kernel can't show dialogs: *)
VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`Private`headlessFrontEndQ @@@ {
        { FrontEndObject @ LinkObject[ "headless", 1, 1 ], LinkObject[ "headless", 1, 1 ] },
        { FrontEndObject @ LinkObject[ "notebook", 2, 1 ], LinkObject[ "headless", 1, 1 ] },
        { FrontEndObject @ LinkObject[ "notebook", 2, 1 ], unsetFrontEndLink },
        { Null, LinkObject[ "headless", 1, 1 ] }
    },
    { True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "HeadlessFrontEndQ-GH#1612@@Tests/VectorDatabaseDownloads.wlt:289,1-299,2"
]

(* A kernel without a front end. The tests can also run in a kernel with a front end (e.g. in CI, in UsingFrontEnd), so
   that is blocked: *)
VerificationTest[
    Block[ { $FrontEnd = Null, $Notebooks = False },
        {
            Wolfram`Chatbook`PromptGenerators`Common`Private`headlessFrontEndQ[ ],
            Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed
        }
    ],
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "DownloadPromptAllowed-HeadlessKernel-GH#1612@@Tests/VectorDatabaseDownloads.wlt:303,1-313,2"
]

(* Prompt text is only built when the prompt is shown: *)
VerificationTest[
    Module[ { texts = 0, results },
        Internal`InheritedBlock[ { Wolfram`Chatbook`PromptGenerators`Common`downloadText },
            Wolfram`Chatbook`PromptGenerators`Common`downloadText[ name_String ] /; ! TrueQ @ $inDownloadText :=
                Block[ { $inDownloadText = True }, texts++; Wolfram`Chatbook`PromptGenerators`Common`downloadText @ name ];
            results = {
                Wolfram`Chatbook`PromptGenerators`Common`confirmRedownload @ { "/a/b" },
                Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ 370*^6, 1*^6 ]
            }
        ];
        { results, texts }
    ],
    { { True, True }, 0 },
    SameTest -> MatchQ,
    TestID   -> "DownloadPrompts-NoTextWithoutPrompt-GH#1612@@Tests/VectorDatabaseDownloads.wlt:316,1-331,2"
]

(* Bulleted lines (file paths) get a hanging indent in the dialog, other messages are shown as they are: *)
VerificationTest[
    {
        Wolfram`Chatbook`PromptGenerators`Common`Private`downloadPromptContent[ "a:\n\n\[Bullet] /x/y\n\[Bullet] /z\n\nb?" ],
        Wolfram`Chatbook`PromptGenerators`Common`Private`downloadPromptContent[ "Try again?" ]
    },
    {
        Column[
            { "a:", "", Grid[ { { "\[Bullet]", "/x/y" } }, ___ ], Grid[ { { "\[Bullet]", "/z" } }, ___ ], "", "b?" },
            ___
        ],
        "Try again?"
    },
    SameTest -> MatchQ,
    TestID   -> "DownloadPrompts-PathsHangingIndent-GH#1612@@Tests/VectorDatabaseDownloads.wlt:334,1-348,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Vector Databases*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fresh Install*)
VerificationTest[
    $prompts = { };
    withPrompt[ False, download @ $name ],
    $root,
    SameTest -> MatchQ,
    TestID   -> "FreshInstall@@Tests/VectorDatabaseDownloads.wlt:357,1-363,2"
]

VerificationTest[
    { $prompts, validQ[ ], FileNames[ "*", $root ] },
    { { }, True, { _String? (StringEndsQ[ $name ]), _String? (StringEndsQ[ "download.lock" ]) } | { _String? (StringEndsQ[ $name ]) } },
    SameTest -> MatchQ,
    TestID   -> "FreshInstall-NoPromptAndClean@@Tests/VectorDatabaseDownloads.wlt:365,1-370,2"
]

VerificationTest[
    Sort[ FileNameTake[ #, -1 ] & /@ FileNames[ "*", dbDir[ ] ] ],
    Sort @ { "Manifest.wxf", "NeuralNetRepositoryURIs-vectors.usearch", "NeuralNetRepositoryURIs.wxf", "Values.wxf", "Version.wl" },
    SameTest -> MatchQ,
    TestID   -> "FreshInstall-Files@@Tests/VectorDatabaseDownloads.wlt:372,1-377,2"
]

VerificationTest[
    Developer`ReadWXFFile @ FileNameJoin @ { dbDir[ ], "Manifest.wxf" },
    KeyValuePattern @ { "Version" -> "1.2.0", "Files" -> KeyValuePattern[ "NeuralNetRepositoryURIs-vectors.usearch" -> 4401488 ] },
    SameTest -> MatchQ,
    TestID   -> "FreshInstall-Manifest@@Tests/VectorDatabaseDownloads.wlt:379,1-384,2"
]

VerificationTest[
    $prompts = { };
    withPrompt[ False, download @ $name ],
    $root,
    SameTest -> MatchQ,
    TestID   -> "AlreadyInstalled-NoDownload@@Tests/VectorDatabaseDownloads.wlt:386,1-392,2"
]

(* A local archive of the installed database, which the stubbed downloads serve (see withFakeDownloads). It is not the
   published archive, so it only matches the download metadata within withLocalVDBMetadata: *)
VerificationTest[
    $localVDBZip = FileNameJoin @ { $TemporaryDirectory, "VDBTest-local-" <> CreateUUID[ ] <> ".zip" };
    CreateArchive[ FileNameJoin @ { dbDir[ ], # } & /@ { $name <> ".wxf", "Values.wxf", $name <> "-vectors.usearch" }, $localVDBZip ];
    $localVDBMetadata = { FileByteCount @ $localVDBZip, FileHash[ $localVDBZip, "SHA256", All, "HexString" ] };
    { validQ[ ], $localVDBMetadata },
    { True, { _Integer? Positive, _String } },
    SameTest -> MatchQ,
    TestID   -> "LocalArchive-Setup-GH#1612@@Tests/VectorDatabaseDownloads.wlt:396,1-404,2"
]

withLocalVDBMetadata // Attributes = { HoldFirst };
withLocalVDBMetadata[ eval_ ] := With[
    { key = { $name, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDatabases[ $name, "Version" ] } },
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBArchiveSizes   = <| key -> First @ $localVDBMetadata |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadHashes = <| key -> Last @ $localVDBMetadata |>
        },
        eval
    ]
];

(* Downloads the test database from $testURLs into a new directory, using the stubbed downloads, and returns { True (or
   the result if it is not the directory), requested URLs, prompts, whether the database is installed, leftover files }: *)
stubbedDownload[ responses_Association ] := Module[ { dir, result },
    dir = CreateDirectory[ ];
    $prompts = { };
    result = withFakeDownloads[
        responses,
        Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
            withPrompt[
                False,
                Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadVectorDatabases[
                    dir,
                    $testURLs
                ]
            ]
        ]
    ];
    WithCleanup[
        {
            If[ result === dir, True, result ],
            $requestedURLs,
            $prompts,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBDirectoryQ0 @ FileNameJoin @ { dir, $name },
            FileNameTake /@ FileNames[ { "*.tmp", "*.zip", "*.staging" }, dir ]
        },
        DeleteDirectory[ dir, DeleteContents -> True ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Corrupt Install Detected*)
VerificationTest[
    truncateIndex[ ];
    validQ[ ],
    False,
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Detected@@Tests/VectorDatabaseDownloads.wlt:450,1-456,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBDamagedQ[ $root, $name ],
    True,
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-DamagedQ@@Tests/VectorDatabaseDownloads.wlt:458,1-463,2"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
        { withPrompt[ False, download @ $name ], Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined }
    ],
    { Missing[ "DownloadDeclined", ___ ], True },
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Declined@@Tests/VectorDatabaseDownloads.wlt:465,1-473,2"
]

VerificationTest[
    $prompts,
    { _String? (StringContainsQ[ #, "incomplete or corrupt" ] && StringContainsQ[ #, FileNameJoin @ { $root, $name } ] &) },
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Declined-Prompted@@Tests/VectorDatabaseDownloads.wlt:475,1-480,2"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
        withPrompt[ True, download @ $name ]
    ],
    $root,
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Accepted@@Tests/VectorDatabaseDownloads.wlt:482,1-490,2"
]

VerificationTest[
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Repaired@@Tests/VectorDatabaseDownloads.wlt:492,1-497,2"
]

VerificationTest[
    $prompts = { };
    DeleteFile @ FileNameJoin @ { dbDir[ ], "Values.wxf" };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "MissingFile-Repaired@@Tests/VectorDatabaseDownloads.wlt:499,1-507,2"
]

VerificationTest[
    With[ { m = FileNameJoin @ { dbDir[ ], "Values.wxf" } },
        With[ { b = ReadByteArray @ m }, DeleteFile @ m; BinaryWrite[ m, b[[ 1 ;; 100 ]] ]; Close @ m ]
    ];
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBManifestValidQ[ dbDir[ ] ],
    False,
    SameTest -> MatchQ,
    TestID   -> "Manifest-DetectsTruncatedValues@@Tests/VectorDatabaseDownloads.wlt:509,1-517,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    validQ[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Manifest-Repaired@@Tests/VectorDatabaseDownloads.wlt:519,1-525,2"
]

(* Files added by the operating system are not recorded in the manifest, and not checked if a manifest lists them: *)
VerificationTest[
    Module[ { junk, manifest },
        junk = FileNameJoin @ { dbDir[ ], # } & /@ { ".DS_Store", "Thumbs.db", "desktop.ini" };
        Scan[ (BinaryWrite[ #, ByteArray @ { 1, 2, 3 } ]; Close @ #) &, junk ];
        manifest = Developer`ReadWXFFile @ FileNameJoin @ { dbDir[ ], "Manifest.wxf" };
        WithCleanup[
            {
                Sort @ Keys @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`manifestFileSizes @ dbDir[ ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBManifestValidQ[
                    dbDir[ ],
                    <| manifest, "Files" -> <| manifest[ "Files" ], ".DS_Store" -> 6148 |> |>
                ],
                validQ[ ]
            },
            Quiet[ DeleteFile /@ junk ]
        ]
    ],
    { Sort @ { "NeuralNetRepositoryURIs-vectors.usearch", "NeuralNetRepositoryURIs.wxf", "Values.wxf" }, True, True },
    SameTest -> MatchQ,
    TestID   -> "Manifest-IgnoresSystemFiles-GH#1612@@Tests/VectorDatabaseDownloads.wlt:528,1-548,2"
]

(* A manifest that can't be written fails the install with a Failure (instead of an internal failure that is thrown): *)
VerificationTest[
    Module[ { dir },
        dir = CreateDirectory[ ];
        WithCleanup[
            Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`writeVectorDBManifest[ dir, "1.2.0" ],
            DeleteDirectory[ dir, DeleteContents -> True ]
        ]
    ],
    Failure[ "VectorDatabaseManifestFailed", _ ],
    SameTest -> MatchQ,
    TestID   -> "WriteVectorDBManifest-ReturnsFailure-GH#1612@@Tests/VectorDatabaseDownloads.wlt:551,1-562,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Self-Repair On Load*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False
        },
        truncateIndex[ ];
        $prompts = { };
        {
            withPrompt[ True, Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDB @ $name ],
            Length @ $prompts,
            validQ[ ]
        }
    ],
    { KeyValuePattern @ { "Values" -> { __String }, "VectorDatabaseObject" -> _VectorDatabaseObject }, 1, True },
    SameTest -> MatchQ,
    TestID   -> "LoadVectorDB-SelfRepair@@Tests/VectorDatabaseDownloads.wlt:567,1-585,2"
]

(* If loading fails for a reason that the install check can't see, the repair still downloads the database again: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory   = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory        = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs          = <| |>
        },
        Module[ { values, bytes },
            values = FileNameJoin @ { dbDir[ ], "Values.wxf" };
            (* Damage the values file without changing its size: *)
            bytes = Normal @ ReadByteArray @ values;
            DeleteFile @ values;
            BinaryWrite[ values, ByteArray @ ReplacePart[ bytes, Thread[ Range[ 1, 16 ] -> BitXor[ bytes[[ 1 ;; 16 ]], 255 ] ] ] ];
            Close @ values;
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`clearVectorDBCaches @ $name;
            $prompts = { };
            {
                validQ[ ],
                MatchQ[
                    withPrompt[ True, Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDB @ $name ],
                    KeyValuePattern[ "VectorDatabaseObject" -> _VectorDatabaseObject ]
                ],
                Length @ $prompts,
                MatchQ[ Quiet @ Developer`ReadWXFFile @ values, { __String } ],
                validQ[ ]
            }
        ]
    ],
    { True, True, 1, True, True },
    SameTest -> MatchQ,
    TestID   -> "RepairVectorDB-DownloadsIntactLookingFiles-GH#1612@@Tests/VectorDatabaseDownloads.wlt:588,1-620,2"
]

(* InstallVectorDatabases[] downloads databases again that could not be loaded: *)
VerificationTest[
    Module[ { seen },
        Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory = $root,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures   = { $name },
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadVectorDatabases = Function[
                    seen = {
                        #1,
                        Keys @ #2,
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$forcedVectorDBDownloads,
                        Wolfram`Chatbook`PromptGenerators`Common`$promptRedownload
                    };
                    #1
                ]
            },
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`reinstallFailedVectorDBs[ ],
                seen,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures
            }
        ]
    ],
    { $root, { $root, { "NeuralNetRepositoryURIs" }, { "NeuralNetRepositoryURIs" }, False }, { } },
    SameTest -> MatchQ,
    TestID   -> "RepairVectorDB-InstallDownloadsAgain-GH#1612@@Tests/VectorDatabaseDownloads.wlt:623,1-649,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Declined Downloads*)

(* Evaluates eval as if the test database in $root was the only vector database, installed in the local directory: *)
withTestVectorDBs // Attributes = { HoldFirst };
withTestVectorDBs[ eval_ ] := Block[
    {
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBNames           = { $name },
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadURLs    = KeyTake[ $urls, { $name } ],
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$pacletVectorDBDirectory = None,
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory  = $root,
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs         = <| |>,
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBSearchCache     = <| |>,
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory
    },
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory :=
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBDirectory[ ];
    eval
];

$declinedTestMessages = { <| "Role" -> "User", "Content" -> "How do I use a neural network for image classification?" |> };

(* After the download was declined, later searches skip the database instead of prompting again or failing: *)
VerificationTest[
    withTestVectorDBs @ Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
            Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell
        },
        truncateIndex[ ];
        $prompts = { };
        Module[ { results, calls },
            { results, calls } = countStopChat @ withPrompt[
                False,
                Table[
                    Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`vectorDBSearch[
                        $name,
                        "neural network",
                        "Values"
                    ],
                    3
                ]
            ];
            {
                results,
                Length @ $prompts,
                Length @ calls,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory,
                validQ[ ]
            }
        ]
    ],
    { { { }, { }, { } }, 1, 1, True, $root, False },
    SameTest -> MatchQ,
    TestID   -> "Declined-LaterSearchesSkip-GH#1612@@Tests/VectorDatabaseDownloads.wlt:675,1-708,2"
]

(* A database that was never installed is not downloaded either: *)
VerificationTest[
    Module[ { empty, result },
        empty  = CreateDirectory[ ];
        result = withTestVectorDBs @ Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory   = empty,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = True
            },
            $prompts = { };
            {
                withPrompt[ True, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadVectorDatabases[ ] ],
                withPrompt[ True, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name ],
                $prompts,
                FileNames[ "*", empty ]
            }
        ];
        DeleteDirectory[ empty, DeleteContents -> True ];
        result
    ],
    { Missing[ "DownloadDeclined" ], Missing[ "DownloadDeclined", ___ ], { }, { } },
    SameTest -> MatchQ,
    TestID   -> "Declined-DownloadNotOfferedAgain-GH#1612@@Tests/VectorDatabaseDownloads.wlt:711,1-733,2"
]

(* A later chat with the declined database completes: the other prompt generators still run, and nothing is thrown: *)
VerificationTest[
    withTestVectorDBs @ Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = True,
            Wolfram`Chatbook`$RelatedDocumentationSources = { "NeuralNetRepository" },
            Wolfram`Chatbook`$CurrentChatSettings = <| |>,
            Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell
        },
        truncateIndex[ ];
        $prompts = { };
        countStopChat @ withPrompt[
            True,
            Wolfram`Chatbook`Common`withChatState @ Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`Common`applyPromptGenerators[
                <| |>,
                { "RelatedDocumentation", LLMPromptGenerator[ "Other" &, "Messages" ] },
                $declinedTestMessages
            ]
        ]
    ],
    { { "Other" }, { } },
    SameTest -> MatchQ,
    TestID   -> "Declined-LaterChatCompletes-GH#1612@@Tests/VectorDatabaseDownloads.wlt:736,1-758,2"
]

(* The chat in which the download is declined is stopped, without a failure: *)
VerificationTest[
    withTestVectorDBs @ Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
            Wolfram`Chatbook`$RelatedDocumentationSources = { "NeuralNetRepository" },
            Wolfram`Chatbook`$CurrentChatSettings = <| |>,
            Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell
        },
        truncateIndex[ ];
        $prompts = { };
        Wolfram`Chatbook`Common`withChatState @ Block[ { Wolfram`Chatbook`Actions`StopChat },
            (* Like StopChat in a chat that is evaluating: *)
            Wolfram`Chatbook`Actions`StopChat[ ] := (Wolfram`Chatbook`Common`$chatStopRequested = True);
            {
                withPrompt[
                    False,
                    Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`Common`applyPromptGenerators[
                        <| |>,
                        { "RelatedDocumentation", LLMPromptGenerator[ "Other" &, "Messages" ] },
                        $declinedTestMessages
                    ]
                ],
                Length @ $prompts,
                Wolfram`Chatbook`Common`$chatStopRequested,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined
            }
        ]
    ],
    { { }, 1, True, True },
    SameTest -> MatchQ,
    TestID   -> "Declined-CurrentChatStops-GH#1612@@Tests/VectorDatabaseDownloads.wlt:761,1-792,2"
]

(* No prompt is shown when downloads are not allowed (e.g. in the Notebook Assistant's warm-up), even before a download
   was declined: *)
VerificationTest[
    withTestVectorDBs @ Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$allowDownload = False
        },
        truncateIndex[ ];
        $prompts = { };
        {
            withPrompt[
                True,
                Catch[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vdbTag
                ]
            ],
            Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory = $root },
                withPrompt[
                    True,
                    Catch[
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name,
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vdbTag
                    ]
                ]
            ],
            $prompts
        }
    ],
    { Missing[ "DownloadDisabled" ], Missing[ "DownloadDisabled" ], { } },
    SameTest -> MatchQ,
    TestID   -> "Declined-AllowDownloadWins-GH#1612@@Tests/VectorDatabaseDownloads.wlt:796,1-827,2"
]

(* Searches still use the default sources if the source selector is skipped: *)
VerificationTest[
    withTestVectorDBs @ Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBNames         = { $name, "SourceSelector" },
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadURLs  = KeyTake[ $urls, { $name, "SourceSelector" } ],
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = True
        },
        $prompts = { };
        {
            withPrompt[ True, Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`autoSelectSources[ "neural networks", 2 ] ],
            $prompts,
            FileNames[ "SourceSelector*", $root ]
        }
    ],
    { { "DocumentationURIs", "EntityValues" }, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "Declined-SourceSelectorSkipped-GH#1612@@Tests/VectorDatabaseDownloads.wlt:830,1-847,2"
]

(* InstallVectorDatabases[] is an explicit request, so it offers the download again: *)
VerificationTest[
    Module[ { seen },
        Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = True,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`installVectorDatabases = Function[
                    seen = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined;
                    Success[ "Stub", <| |> ]
                ]
            },
            { Wolfram`Chatbook`InstallVectorDatabases[ ], seen, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined }
        ]
    ],
    { Success[ "Stub", <| |> ], False, False },
    SameTest -> MatchQ,
    TestID   -> "Declined-InstallClearsFlag-GH#1612@@Tests/VectorDatabaseDownloads.wlt:850,1-866,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDBDirectory = Missing[ "DownloadDeclined" ] &
        },
        Wolfram`Chatbook`InstallVectorDatabases[ ]
    ],
    Failure[ _String? (StringEndsQ[ "VectorDatabaseDownloadDeclined" ]), _ ],
    { Wolfram`Chatbook`InstallVectorDatabases::VectorDatabaseDownloadDeclined },
    SameTest -> MatchQ,
    TestID   -> "Declined-InstallReturnsFailure-GH#1612@@Tests/VectorDatabaseDownloads.wlt:868,1-879,2"
]

(* A load failure that is caught quietly does not silence the messages of later failures in the same chat: *)
VerificationTest[
    Module[ { other },
        other = CreateDirectory[ ];
        WithCleanup[
            Block[
                {
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory      = $root,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory = other,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs        = <| |>
                },
                (* The index is damaged, and a database that is not in the local directory can't be repaired: *)
                truncateIndex[ ];
                Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDB @ $name
            ],
            DeleteDirectory[ other, DeleteContents -> True ]
        ]
    ],
    Failure[ "Chatbook::VectorDatabaseLoadFailed", _ ],
    { Chatbook::VectorDatabaseLoadFailed },
    SameTest -> MatchQ,
    TestID   -> "LoadVectorDB-FailureMessageNotSilenced-GH#1612@@Tests/VectorDatabaseDownloads.wlt:882,1-903,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`catchTop[
        Wolfram`Chatbook`Common`catchQuiet @ Wolfram`Chatbook`Common`throwInternalFailure @ "quiet";
        Wolfram`Chatbook`Common`throwFailure[ "VectorDatabaseDownloadFailed", "test" ]
    ],
    Failure[ "Chatbook::VectorDatabaseDownloadFailed", _ ],
    { Chatbook::VectorDatabaseDownloadFailed },
    SameTest -> MatchQ,
    TestID   -> "CatchQuiet-DoesNotSilenceLaterMessages-GH#1612@@Tests/VectorDatabaseDownloads.wlt:905,1-914,2"
]

(* A download failure that doesn't abort the chat doesn't silence the messages of later failures in the chat: *)
VerificationTest[
    Wolfram`Chatbook`Common`catchTop @ {
        Wolfram`Chatbook`PromptGenerators`Common`catchDownloadFailure @ Wolfram`Chatbook`Common`throwFailure[
            "VectorDatabaseDownloadFailed",
            "test"
        ],
        Wolfram`Chatbook`PromptGenerators`Common`catchDownloadFailure @ Wolfram`Chatbook`Common`throwFailure[
            "SnippetDownloadFailed",
            "test"
        ],
        Wolfram`Chatbook`Common`throwFailure[ "VectorDatabaseLoadFailed", "test" ]
    },
    Failure[ "Chatbook::VectorDatabaseLoadFailed", _ ],
    { Chatbook::VectorDatabaseDownloadFailed, Chatbook::SnippetDownloadFailed, Chatbook::VectorDatabaseLoadFailed },
    SameTest -> MatchQ,
    TestID   -> "CatchDownloadFailure-DoesNotSilenceLaterMessages-GH#1612@@Tests/VectorDatabaseDownloads.wlt:917,1-933,2"
]

(* Other failures are passed on: *)
VerificationTest[
    Wolfram`Chatbook`Common`catchTop[
        Wolfram`Chatbook`PromptGenerators`Common`catchDownloadFailure @ Wolfram`Chatbook`Common`throwFailure[
            "VectorDatabaseLoadFailed",
            "test"
        ];
        "not reached"
    ],
    Failure[ "Chatbook::VectorDatabaseLoadFailed", _ ],
    { Chatbook::VectorDatabaseLoadFailed },
    SameTest -> MatchQ,
    TestID   -> "CatchDownloadFailure-OtherFailuresPassedOn-GH#1612@@Tests/VectorDatabaseDownloads.wlt:936,1-948,2"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "Declined-Repaired-GH#1612@@Tests/VectorDatabaseDownloads.wlt:950,1-957,2"
]

(* A database that still can't be loaded after downloading it again is skipped in later chats, without asking again: *)
VerificationTest[
    withTestVectorDBs @ Module[ { downloads = 0, results },
        Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures     = { },
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDB0             = Failure[ "Test", <| |> ] &,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadVectorDatabases   = (downloads++; #1) &
            },
            $prompts = { };
            results = withPrompt[
                True,
                Table[
                    Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`vectorDBSearch[
                        $name,
                        "neural network",
                        "Values"
                    ],
                    3
                ]
            ];
            { results, Length @ $prompts, downloads, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures }
        ]
    ],
    { { { }, { }, { } }, 1, 1, { "NeuralNetRepositoryURIs" } },
    { Chatbook::VectorDatabaseLoadFailed },
    SameTest -> MatchQ,
    TestID   -> "RepairVectorDB-FailureSkippedLater-GH#1612@@Tests/VectorDatabaseDownloads.wlt:960,1-988,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Same-Size Index Corruption*)
flipIndexBytes[ ] := With[ { f = FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" } },
    With[ { b = Normal @ ReadByteArray @ f },
        DeleteFile @ f;
        BinaryWrite[ f, ByteArray @ ReplacePart[ b, Thread[ Range[ 1, 64 ] -> BitXor[ b[[ 1 ;; 64 ]], 255 ] ] ] ];
        Close @ f
    ]
];

(* Evaluates eval and returns { result, number of times an index file was hashed }: *)
countIndexHashes // Attributes = { HoldFirst };
countIndexHashes[ eval_ ] := Module[ { hashed = 0, result },
    Internal`InheritedBlock[ { FileHash },
        Unprotect @ FileHash;
        FileHash[ file_String, args___ ] /; ! TrueQ @ $inFileHash && StringEndsQ[ file, ".usearch" ] :=
            Block[ { $inFileHash = True }, hashed++; FileHash[ file, args ] ];
        result = eval
    ];
    { result, hashed }
];

VerificationTest[
    Developer`ReadWXFFile @ FileNameJoin @ { dbDir[ ], "Manifest.wxf" },
    KeyValuePattern[ "IndexFingerprint" -> { 4401488, _Integer } ],
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-Recorded@@Tests/VectorDatabaseDownloads.wlt:1013,1-1018,2"
]

(* The modification time is recorded as a Unix time, which does not depend on the time zone: *)
VerificationTest[
    With[ { f = FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" } },
        Developer`ReadWXFFile[ FileNameJoin @ { dbDir[ ], "Manifest.wxf" } ][ "IndexFingerprint" ] ===
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`fileFingerprint @ f ===
                { FileByteCount @ f, UnixTime @ FileDate[ f, "Modification" ] }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-UnixTime-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1021,1-1030,2"
]

VerificationTest[
    countIndexHashes @ validQ[ ],
    { True, 0 },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-UnchangedNotHashed-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1032,1-1037,2"
]

VerificationTest[
    Module[ { size },
        size = FileByteCount @ FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" };
        flipIndexBytes[ ];
        {
            FileByteCount @ FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" } === size,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBIndexSizeValidQ[ dbDir[ ], $name, "1.2.0" ],
            validQ[ ]
        }
    ],
    { True, True, False },
    SameTest -> MatchQ,
    TestID   -> "SameSizeCorruption-Detected@@Tests/VectorDatabaseDownloads.wlt:1039,1-1052,2"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "SameSizeCorruption-Repaired@@Tests/VectorDatabaseDownloads.wlt:1054,1-1061,2"
]

(* An unchanged index whose modification time changed (e.g. it was touched, copied, or restored from a backup) is hashed
   once to check that it is intact, and its new fingerprint is recorded, so it is not hashed again: *)
VerificationTest[
    Module[ { f, manifestFile, first, second },
        f = FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" };
        manifestFile = FileNameJoin @ { dbDir[ ], "Manifest.wxf" };
        SetFileDate[ f, Now - Quantity[ 1, "Days" ] ];
        first  = countIndexHashes @ validQ[ ];
        second = countIndexHashes @ validQ[ ];
        {
            first,
            second,
            Developer`ReadWXFFile[ manifestFile ][ "IndexFingerprint" ] === Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`fileFingerprint @ f
        }
    ],
    { { True, 1 }, { True, 0 }, True },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-TouchedHashedOnce-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1065,1-1081,2"
]

(* Manifests written by earlier builds recorded the modification date as a local date list, which changes with the time
   zone. They are adopted like installs without a fingerprint (here as if the manifest was written in UTC+2): *)
VerificationTest[
    Module[ { f, manifestFile, manifest, result },
        f = FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" };
        manifestFile = FileNameJoin @ { dbDir[ ], "Manifest.wxf" };
        manifest = Developer`ReadWXFFile @ manifestFile;
        manifest[ "IndexFingerprint" ] = { FileByteCount @ f, DateList @ TimeZoneConvert[ FileDate[ f, "Modification" ], 2 ] };
        Developer`WriteWXFFile[ manifestFile, manifest ];
        result = countIndexHashes @ validQ[ ];
        { result, Developer`ReadWXFFile[ manifestFile ][ "IndexFingerprint" ] }
    ],
    { { True, 0 }, { 4401488, _Integer } },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-DateListFormatReadopted-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1085,1-1098,2"
]

VerificationTest[
    Module[ { manifestFile },
        manifestFile = FileNameJoin @ { dbDir[ ], "Manifest.wxf" };
        (* Install from an older version whose files were all copied or extracted at the same time: *)
        DeleteFile @ manifestFile;
        Scan[ SetFileDate[ #, Now ] &, FileNames[ "*", dbDir[ ] ] ];
        Append[ countIndexHashes @ validQ[ ], KeyExistsQ[ Developer`ReadWXFFile @ manifestFile, "IndexFingerprint" ] ]
    ],
    { True, 0, True },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-LegacyInstallSameDatesAdopted@@Tests/VectorDatabaseDownloads.wlt:1100,1-1111,2"
]

VerificationTest[
    Module[ { f, manifestFile, manifest },
        f = FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" };
        manifestFile = FileNameJoin @ { dbDir[ ], "Manifest.wxf" };
        (* Simulate an install from an older version of Chatbook, which has no manifest: *)
        DeleteFile @ manifestFile;
        SetFileDate[ f, Now - Quantity[ 1, "Days" ] ];
        { validQ[ ], KeyExistsQ[ Developer`ReadWXFFile @ manifestFile, "IndexFingerprint" ] }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-LegacyInstallAdopted@@Tests/VectorDatabaseDownloads.wlt:1113,1-1125,2"
]

VerificationTest[
    Module[ { manifestFile },
        manifestFile = FileNameJoin @ { dbDir[ ], "Manifest.wxf" };
        DeleteFile @ manifestFile;
        (* Legacy install whose index was modified after it was installed: *)
        SetFileDate[ FileNameJoin @ { dbDir[ ], "Version.wl" }, Now - Quantity[ 1, "Days" ] ];
        flipIndexBytes[ ];
        (* The same damage was checked earlier, possibly within the same second, which would give the same fingerprint: *)
        SetFileDate[ FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" }, Now + Quantity[ 1, "Hours" ] ];
        Append[ countIndexHashes @ validQ[ ], FileExistsQ @ manifestFile ]
    ],
    { False, 1, False },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-LegacyInstallModifiedRejected@@Tests/VectorDatabaseDownloads.wlt:1127,1-1141,2"
]

(* A damaged index is not hashed again while it is unchanged (e.g. in later chats after the download was declined): *)
VerificationTest[
    countIndexHashes @ validQ[ ],
    { False, 0 },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-DamagedHashedOncePerSession-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1144,1-1149,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    validQ[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-LegacyInstallModifiedRepaired@@Tests/VectorDatabaseDownloads.wlt:1151,1-1157,2"
]

VerificationTest[
    Module[ { f, hashed },
        f = FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" };
        hashed = 0;
        Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$verifyIndexHashes = True,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$verifiedIndexFingerprints = <| |>
            },
            Internal`InheritedBlock[ { FileHash },
                Unprotect @ FileHash;
                FileHash[ file_, args___ ] /; ! TrueQ @ $inFileHash := Block[ { $inFileHash = True }, hashed++; FileHash[ file, args ] ];
                { validQ[ ], validQ[ ], hashed }
            ]
        ]
    ],
    { True, True, 1 },
    SameTest -> MatchQ,
    TestID   -> "VerifyIndexHashes-HashesOncePerSession@@Tests/VectorDatabaseDownloads.wlt:1159,1-1178,2"
]

(* Loading a database whose index was touched hashes it once (and doesn't offer to download it again), and loading it
   again later doesn't hash it: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$allowDownload = False
        },
        SetFileDate[ FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" }, Now - Quantity[ 2, "Days" ] ];
        $prompts = { };
        {
            MapAt[
                MatchQ[ #, KeyValuePattern[ "VectorDatabaseObject" -> _VectorDatabaseObject ] ] &,
                countIndexHashes @ withPrompt[ True, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name ],
                1
            ],
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs = <| |>;
            Last @ countIndexHashes @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name,
            $prompts
        }
    ],
    { { True, 1 }, 0, { } },
    SameTest -> MatchQ,
    TestID   -> "GetVectorDB-TouchedIndexHashedOnce-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1182,1-1206,2"
]

VerificationTest[
    validQ[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "GetVectorDB-NeverHashes-Restore@@Tests/VectorDatabaseDownloads.wlt:1208,1-1213,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Memoized Databases*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs = <| |>
        },
        Module[ { first, loads, second },
            first = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name;
            loads = 0;
            Internal`InheritedBlock[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDB0 },
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDB0[ n_String ] /; ! TrueQ @ $inLoad :=
                    Block[ { $inLoad = True }, loads++; Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDB0 @ n ];
                second = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name
            ];
            { MatchQ[ first, KeyValuePattern[ "VectorDatabaseObject" -> _VectorDatabaseObject ] ], second === first, loads }
        ]
    ],
    { True, True, 0 },
    SameTest -> MatchQ,
    TestID   -> "GetVectorDB-CachedWhileUnchanged@@Tests/VectorDatabaseDownloads.wlt:1218,1-1240,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory = $root,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs = <| |>
        },
        Module[ { result },
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name;
            (* Corrupt the index after it has been loaded and memoized: *)
            flipIndexBytes[ ];
            $prompts = { };
            result = withPrompt[ True, Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name ];
            { MatchQ[ result, KeyValuePattern[ "VectorDatabaseObject" -> _VectorDatabaseObject ] ], Length @ $prompts, validQ[ ] }
        ]
    ],
    { True, 1, True },
    SameTest -> MatchQ,
    TestID   -> "GetVectorDB-RevalidatesAfterCorruption@@Tests/VectorDatabaseDownloads.wlt:1242,1-1262,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Download Locks*)
VerificationTest[
    Module[ { dir, lock, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        (* A lock left behind by a kernel that was killed while holding it: *)
        Put[
            <|
                "Header"       -> "Wolfram Language lock file, created by WithLock[].",
                "UserName"     -> $UserName,
                "MachineName"  -> $MachineName,
                "ProcessID"    -> First @ Complement[ Range[ 900000, 900100 ], Lookup[ Normal @ SystemProcessData[ ], "PID" ] ],
                "CreationTime" -> DateString[ "ISODateTime" ]
            |>,
            lock
        ];
        result = TimeConstrained[ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ], 30, "timed out" ];
        WithCleanup[ { result, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { "acquired", False },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-BreaksStaleLock@@Tests/VectorDatabaseDownloads.wlt:1267,1-1288,2"
]

VerificationTest[
    Module[ { dir, lock, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        (* A lock held by a running kernel (this one) must not be broken: *)
        Put[
            <|
                "Header"       -> "Wolfram Language lock file, created by WithLock[].",
                "UserName"     -> $UserName,
                "MachineName"  -> $MachineName,
                "ProcessID"    -> $ProcessID,
                "CreationTime" -> DateString[ "ISODateTime" ]
            |>,
            lock
        ];
        result = Block[ { Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadLockPollInterval = 1 },
            TimeConstrained[ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ], 5, "waiting" ]
        ];
        WithCleanup[ { result, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { "waiting", True },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-WaitsForLiveLock@@Tests/VectorDatabaseDownloads.wlt:1290,1-1313,2"
]

VerificationTest[
    Module[ { dir, lock, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        result = Catch @ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, Throw[ "thrown" ] ];
        WithCleanup[ { result, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { "thrown", False },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-ReleasedOnThrow@@Tests/VectorDatabaseDownloads.wlt:1315,1-1325,2"
]

(* Writes a lock file as WithLock does, for a kernel with the given machine name and process ID: *)
writeLockFile[ lock_String, machine_String, pid_Integer ] := Put[
    <|
        "Header"       -> "Wolfram Language lock file, created by WithLock[].",
        "UserName"     -> $UserName,
        "MachineName"  -> machine,
        "ProcessID"    -> pid,
        "CreationTime" -> DateString[ "ISODateTime" ]
    |>,
    lock
];

(* Evaluates eval with short lock timings: *)
withShortLockTimes // Attributes = { HoldFirst };
withShortLockTimes[ eval_ ] := Block[
    {
        Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadLockPollInterval = 1,
        Wolfram`Chatbook`PromptGenerators`Common`Private`$staleDownloadLockAge     = 2
    },
    eval
];

(* If the lock file can't be created, this fails right away (instead of trying again and again): *)
VerificationTest[
    Module[ { dir, readOnly, time, result },
        dir      = CreateDirectory[ ];
        readOnly = CreateDirectory @ FileNameJoin @ { dir, "ReadOnly" };
        WithCleanup[
            Run[ "chmod 555 '" <> readOnly <> "'" ];
            (* The directory is still writable on Windows or as root (e.g. in CI), so a file takes its place there: *)
            If[ StringQ @ Quiet @ CreateFile @ FileNameJoin @ { readOnly, "probe" },
                DeleteDirectory[ readOnly, DeleteContents -> True ];
                CreateFile @ readOnly
            ];
            { time, result } = AbsoluteTiming @ Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[
                FileNameJoin @ { readOnly, "download.lock" },
                "acquired"
            ];
            { result, time < 10 },
            Run[ "chmod -R 755 '" <> dir <> "'" ];
            DeleteDirectory[ dir, DeleteContents -> True ]
        ]
    ],
    { Failure[ "Chatbook::DownloadLockFailed", _ ], True },
    { Chatbook::DownloadLockFailed },
    SameTest       -> MatchQ,
    TimeConstraint -> 60,
    TestID         -> "DownloadLock-UnwritableDirectoryFails-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1350,1-1375,2"
]

(* Locks from another machine (or after the machine name changed) are broken once they are no longer kept up to date
   (right away if they were last updated long ago): *)
VerificationTest[
    Module[ { dir, lock, old, fresh },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        writeLockFile[ lock, "other-machine", 12345 ];
        SetFileDate[ lock, Now - Quantity[ 1, "Days" ] ];
        old = AbsoluteTiming @ TimeConstrained[ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ], 30, "timed out" ];
        writeLockFile[ lock, "other-machine", 12345 ];
        fresh = AbsoluteTiming @ withShortLockTimes @ TimeConstrained[
            Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ],
            30,
            "timed out"
        ];
        WithCleanup[ { old[[ 2 ]], old[[ 1 ]] < 5, fresh[[ 2 ]], fresh[[ 1 ]] < 15, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { "acquired", True, "acquired", True, False },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-BreaksLockFromOtherMachine-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1379,1-1397,2"
]

(* If the process table can't be read, the lock is treated like one from another machine: *)
VerificationTest[
    Module[ { dir, lock, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        writeLockFile[ lock, $MachineName, $ParentProcessID ];
        result = Block[ { SystemProcesses = $Failed & },
            withShortLockTimes @ TimeConstrained[ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ], 30, "timed out" ]
        ];
        WithCleanup[ { result, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { "acquired", False },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-BreaksLockWithoutProcessTable-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1400,1-1413,2"
]

(* Waiting for a lock that is held by a running kernel is limited, and the lock is not broken: *)
VerificationTest[
    Module[ { dir, lock, time, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        writeLockFile[ lock, $MachineName, $ProcessID ];
        { time, result } = AbsoluteTiming @ Block[
            {
                Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadLockPollInterval = 1,
                Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadLockTimeout      = 3
            },
            Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ]
        ];
        WithCleanup[ { result, time < 15, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { Failure[ "Chatbook::DownloadLockTimeout", _ ], True, True },
    { Chatbook::DownloadLockTimeout },
    SameTest       -> MatchQ,
    TimeConstraint -> 60,
    TestID         -> "DownloadLock-WaitIsLimited-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1416,1-1435,2"
]

(* A lock that is kept up to date is not broken if its date is reported with a different UTC offset (as in time zones
   whose offset is not a whole number of hours): *)
VerificationTest[
    Module[ { dir, lock, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        writeLockFile[ lock, "other-machine", 12345 ];
        SetFileDate[ lock, Now - Quantity[ 45, "Minutes" ] ];
        result = Block[
            {
                Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadLockPollInterval = 1,
                Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadLockTimeout      = 3
            },
            Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ]
        ];
        WithCleanup[ { result, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { Failure[ "Chatbook::DownloadLockTimeout", _ ], True },
    { Chatbook::DownloadLockTimeout },
    SameTest       -> MatchQ,
    TimeConstraint -> 60,
    TestID         -> "DownloadLock-FileDateOffsetNotStale-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1439,1-1459,2"
]

(* The kernel holding the lock keeps it up to date, and stops doing so when it releases it: *)
VerificationTest[
    Module[ { dir, lock, tasks, result },
        dir   = CreateDirectory[ ];
        lock  = FileNameJoin @ { dir, "download.lock" };
        tasks = Length @ Tasks[ ];
        result = Block[ { Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadLockRefreshInterval = 1 },
            Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[
                lock,
                SetFileDate[ lock, Now - Quantity[ 1, "Hours" ] ];
                Pause[ 2.5 ];
                (* Compared to the date of a new file, since file dates can be reported with a different UTC offset: *)
                With[ { new = CreateFile @ FileNameJoin @ { dir, "new" } },
                    Abs[ UnixTime @ FileDate[ new, "Modification" ] - UnixTime @ FileDate[ lock, "Modification" ] ] < 60
                ]
            ]
        ];
        WithCleanup[ { result, FileExistsQ @ lock, Length @ Tasks[ ] === tasks }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { True, False, True },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-KeptUpToDateWhileHeld-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1462,1-1483,2"
]

VerificationTest[
    Module[ { dir, lock, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        result = withShortLockTimes @ TimeConstrained[
            Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "inner" ] ],
            10,
            "timed out"
        ];
        WithCleanup[ { result, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { "inner", False },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-Reentrant-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1485,1-1499,2"
]

VerificationTest[
    Module[ { created },
        created = DateString[ "ISODateTime" ];
        {
            Wolfram`Chatbook`PromptGenerators`Common`Private`lockHolderStatus[ $ParentProcessID, created ],
            Wolfram`Chatbook`PromptGenerators`Common`Private`lockHolderStatus[
                First @ Complement[ Range[ 900000, 900100 ], Lookup[ Normal @ SystemProcessData[ ], "PID" ] ],
                created
            ],
            (* The process started after the lock was created, so it only reused the PID: *)
            Wolfram`Chatbook`PromptGenerators`Common`Private`lockHolderStatus[
                $ParentProcessID,
                DateString[ Now - Quantity[ 30, "Days" ], "ISODateTime" ]
            ],
            Wolfram`Chatbook`PromptGenerators`Common`Private`lockHolderStatus[ $ProcessID, created ],
            Block[ { SystemProcesses = $Failed & },
                Wolfram`Chatbook`PromptGenerators`Common`Private`lockHolderStatus[ $ParentProcessID, created ]
            ]
        }
    ],
    { "Running", "Stopped", "Stopped", "Unknown", "Unknown" },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-HolderStatus-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1501,1-1524,2"
]

(* A lock held by another kernel that is running on this machine is not broken, even if it was not kept up to date
   (e.g. both kernels were suspended, or the kernel holding it is busy in a long evaluation): *)
VerificationTest[
    Module[ { dir, lock, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        writeLockFile[ lock, $MachineName, $ParentProcessID ];
        SetFileDate[ lock, Now - Quantity[ 1, "Days" ] ];
        result = withShortLockTimes @ Block[ { Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadLockTimeout = 4 },
            Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ]
        ];
        WithCleanup[ { result, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { Failure[ "Chatbook::DownloadLockTimeout", _ ], True },
    { Chatbook::DownloadLockTimeout },
    SameTest       -> MatchQ,
    TimeConstraint -> 60,
    TestID         -> "DownloadLock-LiveHolderNotBroken-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1528,1-1544,2"
]

(* A chat that is stopped while waiting for the lock stops waiting: *)
VerificationTest[
    Module[ { dir, lock, time, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        writeLockFile[ lock, $MachineName, $ParentProcessID ];
        { time, result } = AbsoluteTiming @ Block[ { Wolfram`Chatbook`Common`$chatStopRequested = True },
            Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ]
        ];
        WithCleanup[ { result, time < 5, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { Missing[ "DownloadStopped" ], True, True },
    SameTest       -> MatchQ,
    TimeConstraint -> 60,
    TestID         -> "DownloadLock-StoppedChatStopsWaiting-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1547,1-1561,2"
]

(* A database that is not installed is skipped in a chat that is stopped while waiting for another kernel's download,
   without remembering that for later chats, which download it (without asking, since it is not damaged): *)
VerificationTest[
    Module[ { empty, lock, result },
        empty  = CreateDirectory[ ];
        lock   = FileNameJoin @ { empty, "download.lock" };
        writeLockFile[ lock, $MachineName, $ParentProcessID ];
        result = withTestVectorDBs @ withLocalVDBMetadata @ Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory   = empty,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadURLs     = $testURLs,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadFailure  = None,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures     = { }
            },
            $prompts = { };
            withFakeDownloads[
                <| $cdnURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |> |>,
                withPrompt[ True, Module[ { stopped, requested, later },
                    stopped = Block[ { Wolfram`Chatbook`Common`$chatStopRequested = True },
                        Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`vectorDBSearch[
                            $name,
                            "neural network",
                            "Values"
                        ]
                    ];
                    requested = $requestedURLs;
                    DeleteFile @ lock;
                    later = Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ $name;
                    {
                        stopped,
                        requested,
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined,
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadFailure,
                        MatchQ[ later, KeyValuePattern[ "VectorDatabaseObject" -> _VectorDatabaseObject ] ],
                        $requestedURLs,
                        $prompts
                    }
                ] ]
            ]
        ];
        DeleteDirectory[ empty, DeleteContents -> True ];
        result
    ],
    { { }, { }, False, None, True, { $cdnURL }, { } },
    SameTest       -> MatchQ,
    TimeConstraint -> 120,
    TestID         -> "DownloadLock-StoppedChatSkipsOnlyThisChat-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1565,1-1611,2"
]

(* Download prompts are shown before the download lock is taken, so other kernels don't have to wait for a dialog: *)
VerificationTest[
    Module[ { empty, locks, badURLs, results },
        empty   = CreateDirectory[ ];
        locks   = { };
        badURLs = <| $name -> <|
            "CDN"   -> "https://files.wolframcdn.com/VectorDatabases/DoesNotExist/0.0.0/DoesNotExist.zip",
            "Cloud" -> "https://files.wolframcdn.com/VectorDatabases/DoesNotExist/0.0.0/DoesNotExist.zip"
        |> |>;
        results = Block[
            {
                Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed = True,
                Wolfram`Chatbook`PromptGenerators`Common`$downloadPromptFunction = (
                    AppendTo[ locks, FileNames[ "download.lock", { $root, empty } ] ];
                    False
                ) &,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
                Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts   = 2,
                Wolfram`Chatbook`PromptGenerators`Common`$longDownloadThreshold = -1
            },
            truncateIndex[ ];
            {
                (* Asks before downloading a damaged database again: *)
                download @ $name,
                (* Asks before trying a failed download again: *)
                Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadVectorDatabases[
                    empty,
                    badURLs
                ]
            }
        ];
        DeleteDirectory[ empty, DeleteContents -> True ];
        { results, locks }
    ],
    { { Missing[ "DownloadDeclined", ___ ], Missing[ "DownloadDeclined", ___ ] }, { { }, { } } },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-NotHeldDuringPrompts-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1614,1-1650,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Path Containment*)
VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$pacletVectorDBDirectory = FileNameJoin @ { $root, "VectorDatabases" } },
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`pacletVectorDBDirectoryQ /@ {
            FileNameJoin @ { $root, "VectorDatabases", $name },
            FileNameJoin @ { $root, "VectorDatabases-old", $name },
            FileNameJoin @ { $root, "VectorDatabases" }
        }
    ],
    { True, False, True },
    SameTest -> MatchQ,
    TestID   -> "PacletVectorDBDirectoryQ-PathComponents@@Tests/VectorDatabaseDownloads.wlt:1655,1-1666,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Leftover Artifacts*)
(* Leftovers of an interrupted download are removed by the next download (even if they are recent, e.g. the chat was
   stopped and sent again right away), and they are not a reason to ask before downloading: *)
VerificationTest[
    Module[ { tmp, staging },
        DeleteDirectory[ dbDir[ ], DeleteContents -> True ];
        tmp = FileNameJoin @ { $root, $name <> ".zip." <> CreateUUID[ ] <> ".tmp" };
        BinaryWrite[ tmp, ByteArray @ RandomInteger[ 255, 1000 ] ]; Close @ tmp;
        staging = CreateDirectory @ FileNameJoin @ { $root, $name <> ".staging" };
        $prompts = { };
        {
            Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
                withPrompt[ True, download @ $name ]
            ],
            $prompts,
            FileNames[ { "*.tmp", "*.staging" }, $root ],
            validQ[ ]
        }
    ],
    { $root, { }, { }, True },
    SameTest -> MatchQ,
    TestID   -> "LeftoverTmp-RemovedWithoutPrompt-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1673,1-1692,2"
]

(* An install for an older version with leftovers of an interrupted download is updated without asking: *)
VerificationTest[
    Module[ { tmp },
        Put[ "1.0.0", FileNameJoin @ { dbDir[ ], "Version.wl" } ];
        tmp = FileNameJoin @ { $root, $name <> ".zip." <> CreateUUID[ ] <> ".tmp" };
        BinaryWrite[ tmp, ByteArray @ RandomInteger[ 255, 1000 ] ]; Close @ tmp;
        $prompts = { };
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBDamagedQ[ $root, $name ],
            Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
                withPrompt[ False, download @ $name ]
            ],
            $prompts,
            FileNames[ "*.tmp", $root ],
            validQ[ ]
        }
    ],
    { False, $root, { }, { }, True },
    SameTest -> MatchQ,
    TestID   -> "LeftoverTmp-UpdateWithoutPrompt-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1695,1-1714,2"
]

(* A database that was never installed is downloaded without asking, even if other databases are installed: *)
VerificationTest[
    Module[ { other, tmp, seen, result },
        other = "DataRepositoryURIs";
        tmp = FileNameJoin @ { $root, other <> ".zip." <> CreateUUID[ ] <> ".tmp" };
        BinaryWrite[ tmp, ByteArray @ { 1, 2, 3 } ]; Close @ tmp;
        $prompts = { };
        result = Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadAndUnpackVectorDatabases = (seen = Keys[ #2 ]; #1) &
            },
            withPrompt[ False, download[ $name, KeyTake[ $urls, { $name, other } ] ] ]
        ];
        Quiet @ DeleteFile @ tmp;
        { result, seen, $prompts, validQ[ ] }
    ],
    { $root, { "DataRepositoryURIs" }, { }, True },
    SameTest -> MatchQ,
    TestID   -> "NotInstalled-NotDamaged-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1717,1-1736,2"
]

(* A download that is interrupted (e.g. the chat is stopped) doesn't leave temporary files or the lock behind: *)
VerificationTest[
    Module[ { dir, result },
        dir = CreateDirectory[ ];
        result = Block[ { Wolfram`Chatbook`Common`taskWaitYield },
            (* Interrupt as soon as the download has started: *)
            Wolfram`Chatbook`Common`taskWaitYield[ ___ ] := (
                TimeConstrained[ While[ FileNames[ "*.tmp", dir ] === { }, Pause[ 0.05 ] ], 30 ];
                Abort[ ]
            );
            CheckAbort[
                Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadVectorDatabases[
                    dir,
                    KeyTake[ $urls, { $name } ]
                ],
                "aborted"
            ]
        ];
        WithCleanup[ { result, FileNames[ "*", dir ] }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { "aborted", { } },
    SameTest -> MatchQ,
    TestID   -> "InterruptedDownload-RemovesTemporaryFiles-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1739,1-1761,2"
]

VerificationTest[
    Module[ { target, backup },
        target = dbDir[ ];
        backup = target <> ".old-test";
        RenameDirectory[ target, backup ];
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`restoreVectorDBBackup[ $root, $name ];
        { DirectoryQ @ target, DirectoryQ @ backup, validQ[ ] }
    ],
    { True, False, True },
    SameTest -> MatchQ,
    TestID   -> "InterruptedSwap-RestoresVectorDBBackup@@Tests/VectorDatabaseDownloads.wlt:1763,1-1774,2"
]

VerificationTest[
    Module[ { zip, src },
        src = FileNameJoin @ { $TemporaryDirectory, "VDBTest-src-" <> CreateUUID[ ] <> ".zip" };
        URLDownload[ $urls[ $name, "CDN" ], src ];
        zip = FileNameJoin @ { $root, $name <> ".zip" };
        With[ { b = ReadByteArray @ src }, BinaryWrite[ zip, b[[ 1 ;; 500000 ]] ]; Close @ zip ];
        { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`tryUnpackingVectorDatabase[ zip ], FileExistsQ @ zip, validQ[ ], DeleteFile @ src }
    ],
    { Missing[ "InvalidArchive", _ ], False, True, Null },
    SameTest -> MatchQ,
    TestID   -> "TruncatedLeftoverZip-Rejected@@Tests/VectorDatabaseDownloads.wlt:1776,1-1787,2"
]

VerificationTest[
    Module[ { zip },
        zip = FileNameJoin @ { $root, $name <> ".zip" };
        URLDownload[ $urls[ $name, "CDN" ], zip ];
        DeleteDirectory[ dbDir[ ], DeleteContents -> True ];
        { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`tryUnpackingVectorDatabase[ zip ], FileExistsQ @ zip, validQ[ ] }
    ],
    { _String? DirectoryQ, False, True },
    SameTest -> MatchQ,
    TestID   -> "CompleteLeftoverZip-Unpacked@@Tests/VectorDatabaseDownloads.wlt:1789,1-1799,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Failed Downloads*)
VerificationTest[
    Module[ { badURLs, res },
        badURLs = <| $name -> <|
            "CDN"   -> "https://files.wolframcdn.com/VectorDatabases/DoesNotExist/0.0.0/DoesNotExist.zip",
            "Cloud" -> "https://files.wolframcdn.com/VectorDatabases/DoesNotExist/0.0.0/DoesNotExist.zip"
        |> |>;
        DeleteDirectory[ dbDir[ ], DeleteContents -> True ];
        $prompts = { };
        res = Block[ { Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts = 2, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
            withPrompt[ True, download[ $name, badURLs ] ]
        ];
        { res, FileNames[ { "*.tmp", "*.zip", "*.staging" }, $root ], DirectoryQ @ dbDir[ ] }
    ],
    { Failure[ "Chatbook::VectorDatabaseDownloadFailed", _ ], { }, False },
    SameTest -> MatchQ,
    TestID   -> "FailedDownload-RetriedAndClean@@Tests/VectorDatabaseDownloads.wlt:1804,1-1820,2"
]

(* A declined retry is remembered, so the next search does not start the download again: *)
VerificationTest[
    Module[ { badURLs, res },
        badURLs = <| $name -> <|
            "CDN"   -> "https://files.wolframcdn.com/VectorDatabases/DoesNotExist/0.0.0/DoesNotExist.zip",
            "Cloud" -> "https://files.wolframcdn.com/VectorDatabases/DoesNotExist/0.0.0/DoesNotExist.zip"
        |> |>;
        $prompts = { };
        res = Block[
            {
                Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts   = 2,
                Wolfram`Chatbook`PromptGenerators`Common`$longDownloadThreshold = -1,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False
            },
            {
                withPrompt[ False, download[ $name, badURLs ] ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined,
                withTestVectorDBs @ withPrompt[ True, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadVectorDatabases[ ] ]
            }
        ];
        { res, $prompts, FileNames[ { "*.tmp", "*.zip", "*.staging" }, $root ], DirectoryQ @ dbDir[ ] }
    ],
    {
        { Missing[ "DownloadDeclined" ], True, Missing[ "DownloadDeclined" ] },
        { _String? (StringContainsQ[ "did not complete" ]) },
        { },
        False
    },
    SameTest -> MatchQ,
    TestID   -> "Declined-RetryNotStartedAgain-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1823,1-1852,2"
]

(* Without metadata for the archive's version, only the size reported by the server is checked: *)
VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`validDownloadSizeQ @@@ {
        { 100, 100, None },
        { 99, 100, None },
        { 99, 100, 99 },
        { 100, Missing[ "NotAvailable" ], 100 },
        { 99, Missing[ "NotAvailable" ], 100 },
        { 100, Missing[ "NotAvailable" ], None },
        { 0, 100, 0 },
        { 0, Missing[ "NotAvailable" ], None }
    },
    { True, False, False, True, False, True, False, False },
    SameTest -> MatchQ,
    TestID   -> "ValidDownloadSizeQ-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1855,1-1869,2"
]

(* An archive is verified if its hash matches the metadata, invalid if it doesn't, and unverified if there is no
   metadata for its version (it is then only installed if it can be unpacked and its contents are valid): *)
VerificationTest[
    {
        Wolfram`Chatbook`PromptGenerators`Common`downloadedArchiveStatus[ Last @ $localVDBMetadata, $localVDBZip ],
        Wolfram`Chatbook`PromptGenerators`Common`downloadedArchiveStatus[ StringRepeat[ "0", 64 ], $localVDBZip ],
        Wolfram`Chatbook`PromptGenerators`Common`downloadedArchiveStatus[ Missing[ "NotAvailable" ], $localVDBZip ],
        Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadHashes = <| |> },
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBArchiveStatus[ $name, $localVDBZip ]
        ],
        (* It is not the published archive: *)
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBArchiveStatus[ $name, $localVDBZip ]
    },
    { "Verified", "Invalid", "Unverified", "Unverified", "Invalid" },
    SameTest -> MatchQ,
    TestID   -> "DownloadedArchiveStatus-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1873,1-1887,2"
]

(* Without metadata, an installed index only needs to be non-empty, and it can't be verified by its hash. Metadata that
   doesn't match still fails: *)
VerificationTest[
    Module[ { dir, index, version, results },
        dir     = CreateDirectory[ ];
        index   = FileNameJoin @ { dir, $name <> "-vectors.usearch" };
        version = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDatabases[ $name, "Version" ];
        ExtractArchive[ $localVDBZip, dir ];
        results = {
            Block[
                {
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexSizes  = <| |>,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexHashes = <| |>
                },
                {
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBIndexSizeValidQ[ dir, $name, version ],
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`indexHashValidQ[ index, $name, version ]
                }
            ],
            Block[
                {
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexSizes  = <| { $name, version } -> 1 |>,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexHashes = <| { $name, version } -> StringRepeat[ "0", 64 ] |>
                },
                {
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBIndexSizeValidQ[ dir, $name, version ],
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`indexHashValidQ[ index, $name, version ]
                }
            ],
            (* The published metadata matches the index: *)
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBIndexSizeValidQ[ dir, $name, version ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`indexHashValidQ[ index, $name, version ]
            }
        };
        DeleteDirectory[ dir, DeleteContents -> True ];
        results
    ],
    { { True, True }, { False, False }, { True, True } },
    SameTest -> MatchQ,
    TestID   -> "VectorDBIndex-MissingMetadata-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1891,1-1930,2"
]

(* The metadata tables must cover every database and snippet version that the code references (including the versions
   used by other Wolfram Language versions). Run Scripts/UpdateDownloadMetadata.wls after changing a version. *)
heldVersions[ info_Association ] := Flatten @ Cases[
    Normal[ info, Association ],
    (Rule|RuleDelayed)[ "Version", v_ ] :> Cases[ HoldComplete @ v, s_String /; StringMatchQ[ s, DigitCharacter.. ~~ ("." ~~ DigitCharacter..).. ], Infinity ],
    { 1 }
];

$$sha256 = _String? (StringMatchQ[ Repeated[ HexadecimalCharacter, { 64 } ] ]);

VerificationTest[
    Module[ { dbs, keys, vdbCompleteQ, snippetKeys },
        dbs  = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDatabases;
        keys = Union @ Catenate @ KeyValueMap[
            Function[ { name, info }, { name, # } & /@ Union[ { info[ "Version" ] }, heldVersions @ info ] ],
            dbs
        ];
        vdbCompleteQ = Function[ key, And[
            MatchQ[ Lookup[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBArchiveSizes  , Key @ key ], _Integer? Positive ],
            MatchQ[ Lookup[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexSizes    , Key @ key ], _Integer? Positive ],
            MatchQ[ Lookup[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadHashes, Key @ key ], $$sha256 ],
            MatchQ[ Lookup[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexHashes   , Key @ key ], $$sha256 ]
        ] ];
        snippetKeys = Function[ name,
            { name, Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetVersions @ name }
        ] /@ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetTypes;
        {
            Length @ keys >= Length @ dbs,
            Select[ keys, ! vdbCompleteQ @ # & ],
            Select[
                snippetKeys,
                ! MatchQ[
                    Lookup[ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetArchiveInfo, Key @ # ],
                    { _Integer? Positive, $$sha256 }
                ] &
            ]
        }
    ],
    { True, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "DownloadMetadata-CoversReferencedVersions-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1942,1-1973,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Download Sources and Retries*)

(* Download rates are only estimated from successful downloads of a useful size: *)
VerificationTest[
    {
        Wolfram`Chatbook`PromptGenerators`Common`observedDownloadRate[ 240, 0.1 ],
        Wolfram`Chatbook`PromptGenerators`Common`observedDownloadRate[ 5*^6, 2.0 ],
        Wolfram`Chatbook`PromptGenerators`Common`observedDownloadRate[ 5*^6, 0 ],
        Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime[ 4*^6, None ]
    },
    { None, 2.5*^6, None, 2. },
    SameTest -> Equal,
    TestID   -> "ObservedDownloadRate-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1980,1-1990,2"
]

(* If the CDN download fails (error response, no connection, or a truncated archive), the cloud copy is downloaded right
   away, without asking: *)
VerificationTest[
    withLocalVDBMetadata @ Table[
        stubbedDownload @ <| $cdnURL -> cdn, $cloudURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |> |>,
        {
            cdn,
            {
                $notFound,
                <| "StatusCode" -> 0, "Body" -> StringToByteArray[ " " ] |>,
                <| "StatusCode" -> 200, "Body" -> ReadByteArray[ $localVDBZip ][[ 1 ;; 100000 ]] |>
            }
        }
    ],
    ConstantArray[ { True, { $cdnURL, $cloudURL }, { }, True, { } }, 3 ],
    SameTest -> MatchQ,
    TestID   -> "CDNFailure-CloudFallbackWithoutPrompt-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1994,1-2009,2"
]

VerificationTest[
    withLocalVDBMetadata @ stubbedDownload @ <| $cdnURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |> |>,
    { True, { $cdnURL }, { }, True, { } },
    SameTest -> MatchQ,
    TestID   -> "CDNSuccess-CloudNotRequested-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2011,1-2016,2"
]

(* The retry prompt is only shown after both sources failed, and the time it estimates for trying again (which decides
   whether to ask) uses the fallback rate (2 MB/s) instead of the rate of the error responses: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts   = 2,
            Wolfram`Chatbook`PromptGenerators`Common`$longDownloadThreshold = -1
        },
        withRetryEstimates @ stubbedDownload @ <|
            $cdnURL   -> <| $notFound, "Delay" -> 0.2 |>,
            $cloudURL -> <| $notFound, "Delay" -> 0.2 |>
        |>
    ],
    {
        {
            Missing[ "DownloadDeclined" ],
            { $cdnURL, $cloudURL },
            { _String? (StringContainsQ[ #, "did not complete" ] &) },
            False,
            { }
        },
        { _? (1 < # <= 2 &) }
    },
    SameTest -> MatchQ,
    TestID   -> "ErrorResponse-RetryEstimateUsesFallbackRate-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2020,1-2043,2"
]

(* Without metadata for the version, an archive with the size reported by the server is installed if it can be unpacked
   and its contents are valid: *)
withoutVDBMetadata // Attributes = { HoldFirst };
withoutVDBMetadata[ eval_ ] := Block[
    {
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBArchiveSizes   = <| |>,
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexSizes     = <| |>,
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadHashes = <| |>,
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexHashes    = <| |>
    },
    eval
];

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts = 1 },
        withoutVDBMetadata @ {
            stubbedDownload @ <| $cdnURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |> |>,
            (* An archive that can't be unpacked is downloaded from the cloud instead: *)
            stubbedDownload @ <|
                $cdnURL   -> <| "StatusCode" -> 200, "Body" -> ByteArray @ RandomInteger[ { 1, 255 }, 1000 ] |>,
                $cloudURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |>
            |>,
            (* The size reported by the server must match: *)
            stubbedDownload @ <|
                $cdnURL   -> <| "StatusCode" -> 200, "File" -> $localVDBZip, "ByteCountTotal" -> First @ $localVDBMetadata + 1 |>,
                $cloudURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip, "ByteCountTotal" -> First @ $localVDBMetadata + 1 |>
            |>
        }
    ],
    {
        { True, { $cdnURL }, { }, True, { } },
        { True, { $cdnURL, $cloudURL }, { }, True, { } },
        { Failure[ "Chatbook::VectorDatabaseDownloadFailed", _ ], { $cdnURL, $cloudURL }, { }, False, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "MissingMetadata-UnverifiedArchiveInstalled-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2058,1-2081,2"
]

(* Metadata that doesn't match the archive (its size, or its hash) still rejects it: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts = 1 },
        {
            stubbedDownload @ <| $cdnURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |>, $cloudURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |> |>,
            withLocalVDBMetadata @ Block[
                {
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadHashes = <|
                        { $name, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDatabases[ $name, "Version" ] } -> StringRepeat[ "0", 64 ]
                    |>
                },
                stubbedDownload @ <| $cdnURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |>, $cloudURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |> |>
            ]
        }
    ],
    ConstantArray[ { Failure[ "Chatbook::VectorDatabaseDownloadFailed", _ ], { $cdnURL, $cloudURL }, { }, False, { } }, 2 ],
    SameTest -> MatchQ,
    TestID   -> "MismatchedMetadata-ArchiveRejected-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2084,1-2101,2"
]

(* A verified archive is not downloaded again if it can't be unpacked: it is kept, and only unpacking it is tried again
   (so there is nothing to download, and no retry prompt): *)
VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`Common`$longDownloadThreshold = 0.5 },
        withLocalVDBMetadata @ failFirstCalls[
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`validateVectorDBFiles,
            1,
            False,
            stubbedDownload @ <| $cdnURL -> <| "StatusCode" -> 200, "File" -> $localVDBZip |> |>
        ]
    ],
    { True, { $cdnURL }, { }, True, { } },
    SameTest -> MatchQ,
    TestID   -> "VerifiedArchive-UnpackRetriedWithoutDownload-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2105,1-2117,2"
]

(* An archive that is kept is tried again by the next install, and it is deleted once it was unpacked: *)
VerificationTest[
    Module[ { dir, zip, results },
        dir = CreateDirectory[ ];
        zip = FileNameJoin @ { dir, $name <> ".zip" };
        CopyFile[ $localVDBZip, zip ];
        results = withLocalVDBMetadata @ {
            failFirstCalls[
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`validateVectorDBFiles,
                1,
                False,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`tryUnpackingVectorDatabase @ zip
            ],
            FileExistsQ @ zip,
            DirectoryQ @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`tryUnpackingVectorDatabase @ zip,
            FileExistsQ @ zip
        };
        WithCleanup[
            { results, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBDirectoryQ0 @ FileNameJoin @ { dir, $name } },
            DeleteDirectory[ dir, DeleteContents -> True ]
        ]
    ],
    { { Failure[ "VectorDatabaseUnpackFailed", _ ], True, True, False }, True },
    SameTest -> MatchQ,
    TestID   -> "VerifiedArchive-KeptUntilUnpacked-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2120,1-2144,2"
]

(* After a download failed in a chat, later chats skip the database without downloading it again (the failure is shown
   once). InstallVectorDatabases[] still tries again: *)
VerificationTest[
    Module[ { empty, result },
        empty  = CreateDirectory[ ];
        result = withTestVectorDBs @ Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory   = empty,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadFailure  = None,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures     = { },
                Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts                         = 1
            },
            withFakeDownloads[
                <| |>,
                Module[ { searches, chatRequests },
                    searches = Table[
                        Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`vectorDBSearch[
                            $name,
                            "neural network",
                            "Values"
                        ],
                        3
                    ];
                    chatRequests = Length @ $requestedURLs;
                    {
                        searches,
                        chatRequests,
                        Wolfram`Chatbook`InstallVectorDatabases[ ],
                        Length @ $requestedURLs,
                        FailureQ @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadFailure
                    }
                ]
            ]
        ];
        DeleteDirectory[ empty, DeleteContents -> True ];
        result
    ],
    {
        { { }, { }, { } },
        2,
        Failure[ _String? (StringEndsQ[ "::VectorDatabaseDownloadFailed" ]), _ ],
        4,
        True
    },
    { Chatbook::VectorDatabaseDownloadFailed, Wolfram`Chatbook`InstallVectorDatabases::VectorDatabaseDownloadFailed },
    SameTest -> MatchQ,
    TestID   -> "DownloadFailure-SessionBackoff-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2148,1-2194,2"
]

(* If the directory that is downloaded to can't be created, the chat continues without the databases, and later chats
   don't try again: *)
VerificationTest[
    Module[ { file, result },
        (* A file takes the place of the parent directory, so the directory can't be created (even as root): *)
        file   = CreateFile[ ];
        result = withTestVectorDBs @ Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory   = FileNameJoin @ { file, "15-0" },
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadFailure  = None,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures     = { }
            },
            withFakeDownloads[
                <| |>,
                {
                    Table[
                        Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`vectorDBSearch[
                            $name,
                            "neural network",
                            "Values"
                        ],
                        2
                    ],
                    $requestedURLs,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadFailure
                }
            ]
        ];
        DeleteFile @ file;
        result
    ],
    { { { }, { } }, { }, Failure[ "Chatbook::DownloadDirectoryFailed", _ ] },
    { Chatbook::DownloadDirectoryFailed },
    SameTest -> MatchQ,
    TestID   -> "DownloadDirectoryFailed-ChatContinues-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2198,1-2232,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streamable Snippets*)
VerificationTest[
    Block[
        { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined = True },
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[
            FileNameJoin @ { $TemporaryDirectory, "unused" },
            "ResourceSystem"
        ]
    ],
    Missing[ "Cancelled" ],
    SameTest -> MatchQ,
    TestID   -> "Snippets-CancelledQueueItemDoesNotDownload@@Tests/VectorDatabaseDownloads.wlt:2237,1-2248,2"
]

VerificationTest[
    $snipRoot = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "SnipTest-" <> CreateUUID[ ] };
    $prompts = { };
    withPrompt[ False, Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ $snipRoot, "ResourceSystem" ] ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "Snippets-FreshInstall@@Tests/VectorDatabaseDownloads.wlt:2250,1-2257,2"
]

VerificationTest[
    { $prompts, Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`streamableSnippetsDirectoryQ0[ FileNameJoin @ { $snipRoot, "ResourceSystem" } ], FileNames[ "*.staging", $snipRoot ] },
    { { }, True, { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-FreshInstall-Valid@@Tests/VectorDatabaseDownloads.wlt:2259,1-2264,2"
]

VerificationTest[
    Module[ { f },
        f = FileNameJoin @ { $snipRoot, "ResourceSystem", "Snippets.wxfl" };
        With[ { b = ReadByteArray @ f }, DeleteFile @ f; BinaryWrite[ f, b[[ 1 ;; 1000 ]] ]; Close @ f ];
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetIndexCache = KeyDrop[ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetIndexCache, "ResourceSystem" ];
        { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`streamableSnippetsDirectoryQ0[ FileNameJoin @ { $snipRoot, "ResourceSystem" } ], Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`snippetsDamagedQ[ $snipRoot, "ResourceSystem" ] }
    ],
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "Snippets-Truncated-Detected@@Tests/VectorDatabaseDownloads.wlt:2266,1-2276,2"
]

VerificationTest[
    Module[ { zip, bad, bytes, n },
        zip = FileNameJoin @ { $TemporaryDirectory, "ResourceSystem-" <> CreateUUID[ ] <> ".zip" };
        URLDownload[
            URLBuild @ {
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetBaseURL,
                "ResourceSystem",
                StringReplace[ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetVersions[ "ResourceSystem" ], "." -> "-" ] <> ".zip"
            },
            zip
        ];
        bad = FileNameJoin @ { $TemporaryDirectory, "ResourceSystem-bad-" <> CreateUUID[ ] <> ".zip" };
        bytes = Normal @ ReadByteArray @ zip;
        n = Length @ bytes;
        bytes[[ n - 1000 ;; n - 900 ]] = BitXor[ bytes[[ n - 1000 ;; n - 900 ]], 255 ];
        BinaryWrite[ bad, ByteArray @ bytes ];
        Close @ bad;
        WithCleanup[
            {
                FileByteCount @ bad === FileByteCount @ zip,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`snippetArchiveStatus[ "ResourceSystem", zip, None ],
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`snippetArchiveStatus[ "ResourceSystem", bad, None ]
            },
            Quiet[ DeleteFile /@ { zip, bad } ]
        ]
    ],
    { True, "Verified", "Invalid" },
    SameTest -> MatchQ,
    TestID   -> "Snippets-InvalidArchiveRejected@@Tests/VectorDatabaseDownloads.wlt:2278,1-2307,2"
]

(* Without metadata for the version, an archive can't be verified, and only the size reported by the server is checked: *)
VerificationTest[
    With[ { file = FileNameJoin @ { $snipRoot, "ResourceSystem", "Snippets.wxfl" } },
        Block[
            { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetArchiveInfo = <| |> },
            {
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`snippetArchiveStatus[ "ResourceSystem", file, None ],
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`snippetArchiveStatus[ "ResourceSystem", file, FileByteCount @ file ],
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`snippetArchiveStatus[ "ResourceSystem", file, FileByteCount @ file + 1 ]
            }
        ]
    ],
    { "Unverified", "Unverified", "Invalid" },
    SameTest -> MatchQ,
    TestID   -> "Snippets-MissingMetadata-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2310,1-2324,2"
]

(* The size reported by the server is read from the Content-Length header, which is never evaluated: *)
VerificationTest[
    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`contentLength /@ {
        <| "StatusCode" -> 200, "Headers" -> { "content-type" -> "application/zip", "content-length" -> "9948586" } |>,
        <| "Headers" -> { "Content-Length" -> " 240 " } |>,
        <| "Headers" -> { "content-length" -> "Print[1]" } |>,
        <| "Headers" -> { } |>,
        $Failed
    },
    { 9948586, 240, None, None, None },
    SameTest -> MatchQ,
    TestID   -> "Snippets-ContentLength-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2327,1-2338,2"
]

VerificationTest[
    Module[ { before, result },
        before = FileNames[ "ResourceSystem-*.zip", $TemporaryDirectory ];
        (* Interrupt after the archive has been downloaded: *)
        result = Block[ { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`snippetArchiveStatus = (Abort[ ] &) },
            CheckAbort[ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ $snipRoot, "ResourceSystem", 1, None ], "aborted" ]
        ];
        { result, Complement[ FileNames[ "ResourceSystem-*.zip", $TemporaryDirectory ], before ] }
    ],
    { "aborted", { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-AbortCleansTemporaryFile@@Tests/VectorDatabaseDownloads.wlt:2340,1-2352,2"
]

VerificationTest[
    Module[ { name },
        name = "ResourceSystem";
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetIndexCache[ name ] = <| "Stale" -> True |>;
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ $snipRoot, name ];
        Lookup[ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetIndexCache, name ]
    ],
    Except[ KeyValuePattern[ "Stale" -> True ] ],
    {},
    SameTest -> MatchQ,
    TestID   -> "Snippets-InstallClearsIndexCache@@Tests/VectorDatabaseDownloads.wlt:2354,1-2365,2"
]

VerificationTest[
    Module[ { target, backup },
        target = FileNameJoin @ { $snipRoot, "ResourceSystem" };
        backup = target <> ".old-test";
        RenameDirectory[ target, backup ];
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`restoreSnippetBackup[ $snipRoot, "ResourceSystem" ];
        {
            DirectoryQ @ target,
            DirectoryQ @ backup,
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`streamableSnippetsDirectoryQ0 @ target
        }
    ],
    { True, False, True },
    SameTest -> MatchQ,
    TestID   -> "Snippets-InterruptedSwap-RestoresBackup@@Tests/VectorDatabaseDownloads.wlt:2367,1-2382,2"
]

(* A local archive of the installed snippets, which the stubbed downloads serve (see withFakeDownloads). It is not the
   published archive, so it only matches the download metadata within withLocalSnippetMetadata: *)
VerificationTest[
    $localSnippetZip = FileNameJoin @ { $TemporaryDirectory, "SnipTest-local-" <> CreateUUID[ ] <> ".zip" };
    CreateArchive[ Select[ FileNames[ "*", FileNameJoin @ { $snipRoot, "ResourceSystem" } ], ! DirectoryQ @ # & ], $localSnippetZip ];
    $localSnippetMetadata = { FileByteCount @ $localSnippetZip, FileHash[ $localSnippetZip, "SHA256", All, "HexString" ] };
    $snippetURL = URLBuild @ {
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetBaseURL,
        "ResourceSystem",
        StringReplace[ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetVersions[ "ResourceSystem" ], "." -> "-" ] <> ".zip"
    };
    {
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`streamableSnippetsDirectoryQ0 @ FileNameJoin @ { $snipRoot, "ResourceSystem" },
        $localSnippetMetadata
    },
    { True, { _Integer? Positive, _String } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-LocalArchive-Setup-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2386,1-2402,2"
]

withLocalSnippetMetadata // Attributes = { HoldFirst };
withLocalSnippetMetadata[ eval_ ] := Block[
    {
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetArchiveInfo = <|
            { "ResourceSystem", Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetVersions[ "ResourceSystem" ] } ->
                $localSnippetMetadata
        |>
    },
    eval
];

(* Downloads the ResourceSystem snippets into a new directory, using the stubbed downloads, and returns { True (or the
   result if it is not the installed directory), requested URLs, prompts, whether the snippets are installed, leftover
   files }: *)
stubbedSnippetDownload[ responses_Association ] := Module[ { dir, target, result },
    dir    = CreateDirectory[ ];
    target = FileNameJoin @ { dir, "ResourceSystem" };
    $prompts = { };
    result = withFakeDownloads[
        responses,
        Block[ { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined = False },
            withPrompt[
                False,
                Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[
                    dir,
                    "ResourceSystem"
                ]
            ]
        ]
    ];
    WithCleanup[
        {
            If[ result === target, True, result ],
            $requestedURLs,
            $prompts,
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`streamableSnippetsDirectoryQ0 @ target,
            FileNameTake /@ FileNames[ { "*.zip", "*.staging", "*.old-*" }, dir ]
        },
        DeleteDirectory[ dir, DeleteContents -> True ];
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetIndexCache = KeyDrop[
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetIndexCache,
            "ResourceSystem"
        ]
    ]
];

(* Without metadata for the version, an archive with the size reported by the server is installed if it can be unpacked
   and its contents are valid: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts = 1,
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetArchiveInfo = <| |>
        },
        {
            stubbedSnippetDownload @ <| $snippetURL -> <| "StatusCode" -> 200, "File" -> $localSnippetZip |> |>,
            stubbedSnippetDownload @ <| $snippetURL -> <| "StatusCode" -> 200, "File" -> $localSnippetZip, "ByteCountTotal" -> 1 |> |>
        }
    ],
    {
        { True, { $snippetURL }, { }, True, { } },
        { Failure[ "SnippetDownloadFailed", _ ], { $snippetURL }, { }, False, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "Snippets-MissingMetadata-UnverifiedArchiveInstalled-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2452,1-2469,2"
]

(* Metadata that doesn't match the archive still rejects it: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts = 1 },
        stubbedSnippetDownload @ <| $snippetURL -> <| "StatusCode" -> 200, "File" -> $localSnippetZip |> |>
    ],
    { Failure[ "SnippetDownloadFailed", _ ], { $snippetURL }, { }, False, { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-MismatchedMetadata-Rejected-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2472,1-2479,2"
]

(* The time that is estimated for trying again (which decides whether to ask) uses the fallback rate (2 MB/s) instead
   of the rate of an error response: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts   = 2,
            Wolfram`Chatbook`PromptGenerators`Common`$longDownloadThreshold = -1
        },
        withRetryEstimates @ stubbedSnippetDownload @ <|
            $snippetURL -> <| "StatusCode" -> 401, "Body" -> ByteArray @ ConstantArray[ 32, 5000 ], "Delay" -> 0.2 |>
        |>
    ],
    {
        {
            Missing[ "Cancelled" ],
            { $snippetURL },
            { _String? (StringContainsQ[ #, "did not complete" ] &) },
            False,
            { }
        },
        { _? (4 < # <= 5 &) }
    },
    SameTest -> MatchQ,
    TestID   -> "Snippets-ErrorResponse-RetryEstimateUsesFallbackRate-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2483,1-2505,2"
]

(* A verified archive is not downloaded again if it can't be installed: it is kept, and only installing it is tried
   again (so there is nothing to download, and no retry prompt): *)
VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`Common`$longDownloadThreshold = 0.5 },
        withLocalSnippetMetadata @ failFirstCalls[
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`installSnippetArchive,
            1,
            Failure[ "Test", <| |> ],
            stubbedSnippetDownload @ <| $snippetURL -> <| "StatusCode" -> 200, "File" -> $localSnippetZip |> |>
        ]
    ],
    { True, { $snippetURL }, { }, True, { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-VerifiedArchive-InstallRetriedWithoutDownload-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2509,1-2521,2"
]

(* Evaluates eval as if the ResourceSystem snippets in $snipRoot were the only snippets, installed in the local
   directory: *)
withTestSnippets // Attributes = { HoldFirst };
withTestSnippets[ eval_ ] := Block[
    {
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetTypes = { "ResourceSystem" },
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetVersions = KeyTake[
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetVersions,
            { "ResourceSystem" }
        ],
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$pacletStreamableSnippetsDirectory = FileNameJoin @ { $snipRoot, "NotInstalled" },
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$localStreamableSnippetsDirectory  = $snipRoot,
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetIndexCache       = <| |>,
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetsDir
    },
    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetsDir :=
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`streamableSnippetsDirectory[ ];
    eval
];

(* After the download was declined, later lookups skip the snippets instead of prompting again or failing: *)
VerificationTest[
    withTestSnippets @ Block[
        {
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined = False,
            Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell
        },
        Module[ { f, results, calls },
            f = FileNameJoin @ { $snipRoot, "ResourceSystem", "Snippets.wxfl" };
            With[ { b = ReadByteArray @ f }, DeleteFile @ f; BinaryWrite[ f, b[[ 1 ;; 1000 ]] ]; Close @ f ];
            $prompts = { };
            { results, calls } = countStopChat @ withPrompt[
                False,
                Table[
                    Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`getStreamSnippets[
                        "ResourceSystem",
                        { "https://resources.wolframcloud.com/NeuralNetRepository/resources/test" }
                    ],
                    3
                ]
            ];
            {
                results,
                $prompts,
                Length @ calls,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetsDir
            }
        ]
    ],
    {
        { { "" }, { "" }, { "" } },
        (* The prompt lists the location of the damaged snippets: *)
        { _String? (StringContainsQ[ #, "\[Bullet] " <> FileNameJoin @ { $snipRoot, "ResourceSystem" } ] &) },
        1,
        True,
        $snipRoot
    },
    SameTest -> MatchQ,
    TestID   -> "Snippets-Declined-LaterLookupsSkip-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2544,1-2583,2"
]

VerificationTest[
    withTestSnippets @ Block[ { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined = True },
        $prompts = { };
        { withPrompt[ True, Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ ] ], $prompts }
    ],
    { Missing[ "DownloadDeclined" ], { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-Declined-DownloadNotOfferedAgain-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2585,1-2593,2"
]

(* The prompt is shown before the download lock is taken: *)
VerificationTest[
    withTestSnippets @ Module[ { locks = { } },
        Block[
            {
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined = False,
                Wolfram`Chatbook`PromptGenerators`Common`$longDownloadThreshold = -1,
                Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed = True,
                Wolfram`Chatbook`PromptGenerators`Common`$downloadPromptFunction = (
                    AppendTo[ locks, FileExistsQ @ FileNameJoin @ { $snipRoot, "download.lock" } ];
                    False
                ) &
            },
            {
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ ],
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ $snipRoot, "ResourceSystem", 2, None ],
                locks
            }
        ]
    ],
    { Missing[ "DownloadDeclined" ], Missing[ "Cancelled" ], { False, False } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-LockNotHeldDuringPrompts-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2596,1-2618,2"
]

(* No prompt is shown when downloads are not allowed (e.g. in the Notebook Assistant's warm-up): *)
VerificationTest[
    withTestSnippets @ Block[
        {
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined = False,
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$allowSnippetDownload    = False
        },
        $prompts = { };
        {
            withPrompt[
                True,
                Catch[
                    Wolfram`Chatbook`PromptGenerators`Common`getStreamSnippets[ "ResourceSystem", { "x" } ],
                    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadTag
                ]
            ],
            $prompts
        }
    ],
    { Missing[ "DownloadDisabled" ], { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-Declined-AllowDownloadWins-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2621,1-2642,2"
]

VerificationTest[
    Module[ { seen },
        Block[
            {
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined = True,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`installDocumentationResources = Function[
                    seen = Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined;
                    Success[ "Stub", <| |> ]
                ]
            },
            {
                Wolfram`Chatbook`InstallDocumentationResources[ ],
                seen,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined
            }
        ]
    ],
    { Success[ "Stub", <| |> ], False, False },
    SameTest -> MatchQ,
    TestID   -> "Snippets-Declined-InstallClearsFlag-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2644,1-2664,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`getStreamableSnippetsDir = Missing[ "DownloadDeclined" ] &
        },
        Wolfram`Chatbook`InstallDocumentationResources[ ]
    ],
    Failure[ _String? (StringEndsQ[ "SnippetDownloadDeclined" ]), _ ],
    { Wolfram`Chatbook`InstallDocumentationResources::SnippetDownloadDeclined },
    SameTest -> MatchQ,
    TestID   -> "Snippets-Declined-InstallReturnsFailure-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2666,1-2677,2"
]

(* Checking a damaged snippet directory does not silence the messages of later failures in the same chat: *)
VerificationTest[
    Wolfram`Chatbook`Common`catchTop[
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`streamableSnippetsDirectoryQ0 @ FileNameJoin @ { $snipRoot, "ResourceSystem" };
        Wolfram`Chatbook`Common`throwFailure[ "SnippetDownloadFailed", "ResourceSystem" ]
    ],
    Failure[ "Chatbook::SnippetDownloadFailed", _ ],
    { Chatbook::SnippetDownloadFailed },
    SameTest -> MatchQ,
    TestID   -> "Snippets-DamagedCheckDoesNotSilenceMessages-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2680,1-2689,2"
]

(* After a download failed in a chat, later chats skip the snippets without downloading them again (the failure is shown
   once). InstallDocumentationResources[] still tries again: *)
VerificationTest[
    Module[ { empty, result },
        empty  = CreateDirectory[ ];
        result = withTestSnippets @ Block[
            {
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$localStreamableSnippetsDirectory = empty,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined          = False,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadFailure           = None,
                Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts                                    = 1
            },
            withFakeDownloads[
                <| |>,
                Module[ { lookups, chatRequests },
                    lookups = Table[
                        Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`getStreamSnippets[
                            "ResourceSystem",
                            { "https://resources.wolframcloud.com/NeuralNetRepository/resources/test" }
                        ],
                        3
                    ];
                    chatRequests = Length @ $requestedURLs;
                    {
                        lookups,
                        chatRequests,
                        Wolfram`Chatbook`InstallDocumentationResources[ ],
                        Length @ $requestedURLs,
                        FailureQ @ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadFailure
                    }
                ]
            ]
        ];
        DeleteDirectory[ empty, DeleteContents -> True ];
        result
    ],
    {
        { { "" }, { "" }, { "" } },
        1,
        Failure[ _String? (StringEndsQ[ "::SnippetDownloadFailed" ]), _ ],
        2,
        True
    },
    { Chatbook::SnippetDownloadFailed, Wolfram`Chatbook`InstallDocumentationResources::SnippetDownloadFailed },
    SameTest -> MatchQ,
    TestID   -> "Snippets-DownloadFailure-SessionBackoff-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2693,1-2737,2"
]

(* If the directory that is downloaded to can't be created, the chat continues without the snippets, and later chats
   don't try again: *)
VerificationTest[
    Module[ { file, result },
        (* A file takes the place of the parent directory, so the directory can't be created (even as root): *)
        file   = CreateFile[ ];
        result = withTestSnippets @ Block[
            {
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$localStreamableSnippetsDirectory = FileNameJoin @ { file, "15-0" },
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined          = False,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadFailure           = None
            },
            withFakeDownloads[
                <| |>,
                {
                    Table[
                        Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`getStreamSnippets[
                            "ResourceSystem",
                            { "https://resources.wolframcloud.com/NeuralNetRepository/resources/test" }
                        ],
                        2
                    ],
                    $requestedURLs,
                    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadFailure
                }
            ]
        ];
        DeleteFile @ file;
        result
    ],
    { { { "" }, { "" } }, { }, Failure[ "Chatbook::DownloadDirectoryFailed", _ ] },
    { Chatbook::DownloadDirectoryFailed },
    SameTest -> MatchQ,
    TestID   -> "Snippets-DownloadDirectoryFailed-ChatContinues-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2741,1-2773,2"
]

(* Snippets that are not installed are skipped in a chat that is stopped while waiting for another kernel's download,
   without remembering that for later chats, which download them: *)
VerificationTest[
    Module[ { empty, lock, result },
        empty  = CreateDirectory[ ];
        lock   = FileNameJoin @ { empty, "download.lock" };
        writeLockFile[ lock, $MachineName, $ParentProcessID ];
        result = withTestSnippets @ Block[
            {
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$localStreamableSnippetsDirectory = empty,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined          = False,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadFailure           = None,
                Wolfram`Chatbook`PromptGenerators`Common`$maxDownloadAttempts                                    = 1
            },
            withFakeDownloads[
                <| |>,
                Module[ { lookup, stopped, requested, later },
                    lookup = Function[
                        Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`Common`getStreamSnippets[
                            "ResourceSystem",
                            { "https://resources.wolframcloud.com/NeuralNetRepository/resources/test" }
                        ]
                    ];
                    stopped   = Block[ { Wolfram`Chatbook`Common`$chatStopRequested = True }, lookup[ ] ];
                    requested = $requestedURLs;
                    DeleteFile @ lock;
                    (* The download is tried again (and fails, since nothing can be downloaded here): *)
                    later = lookup[ ];
                    {
                        stopped,
                        requested,
                        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined,
                        later,
                        Length @ $requestedURLs
                    }
                ]
            ]
        ];
        DeleteDirectory[ empty, DeleteContents -> True ];
        result
    ],
    { { "" }, { }, False, { "" }, 1 },
    { Chatbook::SnippetDownloadFailed },
    SameTest       -> MatchQ,
    TimeConstraint -> 120,
    TestID         -> "Snippets-StoppedChatSkipsOnlyThisChat-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2777,1-2821,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Text Resources*)
$downloadTextKeys = {
    "DownloadRedownloadPrompt",
    "DownloadRetryPrompt",
    "ProgressTextDownloadingSearchIndices",
    "ProgressTextUnpackingFiles"
};

readTextResources[ file_ ] := Association @ ToExpression @ First @ StringCases[
    ReadString @ file,
    "@@resource ChatbookStrings" ~~ WhitespaceCharacter... ~~ rules: Shortest[ "{" ~~ ___ ~~ "}" ] :> rules,
    1
];

VerificationTest[
    $textResourceFiles = FileNames[
        "ChatbookStrings.tr",
        FileNameJoin @ { Wolfram`Chatbook`Common`$thisPaclet[ "Location" ], "FrontEnd", "TextResources" },
        Infinity
    ];
    $textResources = AssociationMap[ readTextResources, $textResourceFiles ];
    Length @ $textResourceFiles,
    7,
    SameTest -> MatchQ,
    TestID   -> "TextResources-Files@@Tests/VectorDatabaseDownloads.wlt:2839,1-2850,2"
]

VerificationTest[
    Union @ Flatten @ Values @ Map[ Complement[ $downloadTextKeys, Keys @ # ] &, $textResources ],
    { },
    SameTest -> MatchQ,
    TestID   -> "TextResources-AllKeysPresent@@Tests/VectorDatabaseDownloads.wlt:2852,1-2857,2"
]

VerificationTest[
    CountDistinct[ Lookup[ #, $downloadTextKeys ] & /@ Values @ $textResources ],
    1,
    SameTest -> MatchQ,
    TestID   -> "TextResources-EnglishPlaceholders@@Tests/VectorDatabaseDownloads.wlt:2859,1-2864,2"
]

VerificationTest[
    CountDistinct @ Map[ Take[ Keys @ #, -Length @ $downloadTextKeys ] &, Values @ $textResources ],
    1,
    SameTest -> MatchQ,
    TestID   -> "TextResources-SameRelativeLocation@@Tests/VectorDatabaseDownloads.wlt:2866,1-2871,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`downloadText /@ $downloadTextKeys,
    Lookup[ readTextResources @ SelectFirst[ $textResourceFiles, StringEndsQ[ "TextResources" <> $PathnameSeparator <> "ChatbookStrings.tr" ] ], $downloadTextKeys ],
    SameTest -> MatchQ,
    TestID   -> "TextResources-HeadlessLookup@@Tests/VectorDatabaseDownloads.wlt:2873,1-2878,2"
]

(* Download text never uses a front end in a headless kernel, even for prompts (a front end launched by UsingFrontEnd
   would look up the text in the installed Chatbook paclet): *)
VerificationTest[
    Module[ { uses = 0, result },
        result = Block[ { Wolfram`Chatbook`Common`usingFrontEnd = Function[ Null, uses++; "text", HoldAllComplete ] },
            $prompts = { };
            {
                Wolfram`Chatbook`PromptGenerators`Common`downloadText /@ $downloadTextKeys,
                withPrompt[ True, Wolfram`Chatbook`PromptGenerators`Common`confirmRedownload @ { "/a/b", "/c/d" } ],
                withPrompt[ True, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ 370*^6, 1*^6 ] ],
                $prompts
            }
        ];
        { result, uses }
    ],
    {
        {
            { __String },
            True,
            True,
            {
                _String? (StringContainsQ[ #, "incomplete or corrupt:\n\n\[Bullet] /a/b\n\[Bullet] /c/d\n\n" ] &),
                "The download of some semantic search resources did not complete. Would you like to try again?"
            }
        },
        0
    },
    SameTest -> MatchQ,
    TestID   -> "TextResources-NoFrontEnd-GH#1612@@Tests/VectorDatabaseDownloads.wlt:2882,1-2909,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet[ DeleteFile /@ { $localVDBZip, $localSnippetZip } ];
    Quiet[ DeleteDirectory[ #, DeleteContents -> True ] & /@ { $root, $snipRoot } ],
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "Cleanup@@Tests/VectorDatabaseDownloads.wlt:2914,1-2920,2"
]

(* :!CodeAnalysis::EndBlock:: *)
