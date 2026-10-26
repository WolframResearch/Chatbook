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

VerificationTest[
    $name   = "NeuralNetRepositoryURIs";
    $root   = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "VDBTest-" <> CreateUUID[ ] };
    $urls   = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadURLs;
    $prompts = { };
    DirectoryQ @ $root && AssociationQ @ $urls,
    True,
    SameTest -> MatchQ,
    TestID   -> "Setup@@Tests/VectorDatabaseDownloads.wlt:21,1-30,2"
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

download[ name_String ] := download[ name, KeyTake[ $urls, { name } ] ];
download[ name_String, urls_ ] :=
    Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadVectorDatabases[ $root, urls ];

dbDir[ ] := FileNameJoin @ { $root, $name };
validQ[ ] := Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBDirectoryQ0[ dbDir[ ] ];

truncateIndex[ ] := With[ { f = FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" } },
    With[ { b = ReadByteArray @ f }, DeleteFile @ f; BinaryWrite[ f, b[[ 1 ;; 100000 ]] ]; Close @ f ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt Helpers*)
VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime[ 100*^6, 1*^6 ],
    100.,
    SameTest -> Equal,
    TestID   -> "EstimateDownloadTime@@Tests/VectorDatabaseDownloads.wlt:57,1-62,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime[ 10*^6, None ],
    5.,
    SameTest -> Equal,
    TestID   -> "EstimateDownloadTime-FallbackRate@@Tests/VectorDatabaseDownloads.wlt:64,1-69,2"
]

VerificationTest[
    $prompts = { };
    withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ "small", 1*^6, 1*^6 ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-ShortNoPrompt@@Tests/VectorDatabaseDownloads.wlt:71,1-77,2"
]

VerificationTest[
    $prompts,
    { },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-ShortNoPrompt-Check@@Tests/VectorDatabaseDownloads.wlt:79,1-84,2"
]

VerificationTest[
    withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ "big", 370*^6, 1*^6 ] ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-LongPrompts@@Tests/VectorDatabaseDownloads.wlt:86,1-91,2"
]

VerificationTest[
    $prompts,
    { _String? (StringContainsQ[ "try again" ]) },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-LongPrompts-Check@@Tests/VectorDatabaseDownloads.wlt:93,1-98,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed = False },
        Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ "big", 370*^6, 1*^6 ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-HeadlessProceeds@@Tests/VectorDatabaseDownloads.wlt:100,1-107,2"
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
    TestID   -> "ConfirmDownloadPrompt-CancelStopsChat@@Tests/VectorDatabaseDownloads.wlt:121,1-128,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        countStopChat @ withPrompt[ True, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-AcceptDoesNotStopChat@@Tests/VectorDatabaseDownloads.wlt:130,1-137,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = None },
        countStopChat @ withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
    ],
    { False, { } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-CancelOutsideChatDoesNotStopChat@@Tests/VectorDatabaseDownloads.wlt:139,1-146,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        countStopChat @ withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ "big", 370*^6, 1*^6 ] ]
    ],
    { False, { { } } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-CancelStopsChat@@Tests/VectorDatabaseDownloads.wlt:148,1-155,2"
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
    TestID   -> "ConfirmDownloadPrompt-StopChatFailureStillDeclines@@Tests/VectorDatabaseDownloads.wlt:157,1-167,2"
]

(* Only an explicit "Cancel" declines: a prompt that could not be shown (e.g. ChoiceDialog::ninit in a front end that
   was launched by UsingFrontEnd in a headless kernel) proceeds as it does without a front end: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        countStopChat @ withPrompt[ $Failed, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-DialogFailedProceeds-GH#1612@@Tests/VectorDatabaseDownloads.wlt:171,1-178,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell,
            Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed = True,
            Wolfram`Chatbook`PromptGenerators`Common`$downloadPromptFunction = (Message[ ChoiceDialog::ninit, ChoiceDialog ]; $Failed) &
        },
        countStopChat @ Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ "big", 370*^6, 1*^6 ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-DialogNotInitializedProceeds-GH#1612@@Tests/VectorDatabaseDownloads.wlt:180,1-192,2"
]

(* Closing the dialog declines, like "Cancel": *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = $fakeChatCell },
        countStopChat @ withPrompt[ $Canceled, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadPrompt[ "message" ] ]
    ],
    { False, { { } } },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadPrompt-ClosedDialogDeclines-GH#1612@@Tests/VectorDatabaseDownloads.wlt:195,1-202,2"
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
    TestID   -> "HeadlessFrontEndQ-GH#1612@@Tests/VectorDatabaseDownloads.wlt:205,1-215,2"
]

VerificationTest[
    {
        Wolfram`Chatbook`PromptGenerators`Common`Private`headlessFrontEndQ[ ],
        Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed
    },
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "DownloadPromptAllowed-HeadlessKernel-GH#1612@@Tests/VectorDatabaseDownloads.wlt:217,1-225,2"
]

(* Prompt text is only built when the prompt is shown: *)
VerificationTest[
    Module[ { texts = 0, labels = 0, results },
        Internal`InheritedBlock[ { Wolfram`Chatbook`PromptGenerators`Common`downloadText },
            Wolfram`Chatbook`PromptGenerators`Common`downloadText[ name_String ] /; ! TrueQ @ $inDownloadText :=
                Block[ { $inDownloadText = True }, texts++; Wolfram`Chatbook`PromptGenerators`Common`downloadText @ name ];
            results = {
                Wolfram`Chatbook`PromptGenerators`Common`confirmRedownload[ "DownloadTypeVectorDatabases", { "A" }, 370*^6 ],
                Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ labels++; "label", 370*^6, 1*^6 ]
            }
        ];
        { results, texts, labels }
    ],
    { { True, True }, 0, 0 },
    SameTest -> MatchQ,
    TestID   -> "DownloadPrompts-NoTextWithoutPrompt-GH#1612@@Tests/VectorDatabaseDownloads.wlt:228,1-243,2"
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
    TestID   -> "FreshInstall@@Tests/VectorDatabaseDownloads.wlt:252,1-258,2"
]

VerificationTest[
    { $prompts, validQ[ ], FileNames[ "*", $root ] },
    { { }, True, { _String? (StringEndsQ[ $name ]), _String? (StringEndsQ[ "download.lock" ]) } | { _String? (StringEndsQ[ $name ]) } },
    SameTest -> MatchQ,
    TestID   -> "FreshInstall-NoPromptAndClean@@Tests/VectorDatabaseDownloads.wlt:260,1-265,2"
]

VerificationTest[
    Sort[ FileNameTake[ #, -1 ] & /@ FileNames[ "*", dbDir[ ] ] ],
    Sort @ { "Manifest.wxf", "NeuralNetRepositoryURIs-vectors.usearch", "NeuralNetRepositoryURIs.wxf", "Values.wxf", "Version.wl" },
    SameTest -> MatchQ,
    TestID   -> "FreshInstall-Files@@Tests/VectorDatabaseDownloads.wlt:267,1-272,2"
]

VerificationTest[
    Developer`ReadWXFFile @ FileNameJoin @ { dbDir[ ], "Manifest.wxf" },
    KeyValuePattern @ { "Version" -> "1.2.0", "Files" -> KeyValuePattern[ "NeuralNetRepositoryURIs-vectors.usearch" -> 4401488 ] },
    SameTest -> MatchQ,
    TestID   -> "FreshInstall-Manifest@@Tests/VectorDatabaseDownloads.wlt:274,1-279,2"
]

VerificationTest[
    $prompts = { };
    withPrompt[ False, download @ $name ],
    $root,
    SameTest -> MatchQ,
    TestID   -> "AlreadyInstalled-NoDownload@@Tests/VectorDatabaseDownloads.wlt:281,1-287,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Corrupt Install Detected*)
VerificationTest[
    truncateIndex[ ];
    validQ[ ],
    False,
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Detected@@Tests/VectorDatabaseDownloads.wlt:292,1-298,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBDamagedQ[ $root, $name ],
    True,
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-DamagedQ@@Tests/VectorDatabaseDownloads.wlt:300,1-305,2"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
        { withPrompt[ False, download @ $name ], Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined }
    ],
    { Missing[ "DownloadDeclined", ___ ], True },
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Declined@@Tests/VectorDatabaseDownloads.wlt:307,1-315,2"
]

VerificationTest[
    $prompts,
    { _String? (StringContainsQ[ #, "incomplete or corrupt" ] && StringContainsQ[ #, $name ] &) },
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Declined-Prompted@@Tests/VectorDatabaseDownloads.wlt:317,1-322,2"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
        withPrompt[ True, download @ $name ]
    ],
    $root,
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Accepted@@Tests/VectorDatabaseDownloads.wlt:324,1-332,2"
]

VerificationTest[
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Repaired@@Tests/VectorDatabaseDownloads.wlt:334,1-339,2"
]

VerificationTest[
    $prompts = { };
    DeleteFile @ FileNameJoin @ { dbDir[ ], "Values.wxf" };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "MissingFile-Repaired@@Tests/VectorDatabaseDownloads.wlt:341,1-349,2"
]

VerificationTest[
    With[ { m = FileNameJoin @ { dbDir[ ], "Values.wxf" } },
        With[ { b = ReadByteArray @ m }, DeleteFile @ m; BinaryWrite[ m, b[[ 1 ;; 100 ]] ]; Close @ m ]
    ];
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBManifestValidQ[ dbDir[ ] ],
    False,
    SameTest -> MatchQ,
    TestID   -> "Manifest-DetectsTruncatedValues@@Tests/VectorDatabaseDownloads.wlt:351,1-359,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    validQ[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Manifest-Repaired@@Tests/VectorDatabaseDownloads.wlt:361,1-367,2"
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
    TestID   -> "Manifest-IgnoresSystemFiles-GH#1612@@Tests/VectorDatabaseDownloads.wlt:370,1-390,2"
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
    TestID   -> "WriteVectorDBManifest-ReturnsFailure-GH#1612@@Tests/VectorDatabaseDownloads.wlt:393,1-404,2"
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
    TestID   -> "LoadVectorDB-SelfRepair@@Tests/VectorDatabaseDownloads.wlt:409,1-427,2"
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
    TestID   -> "RepairVectorDB-DownloadsIntactLookingFiles-GH#1612@@Tests/VectorDatabaseDownloads.wlt:430,1-462,2"
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
    TestID   -> "RepairVectorDB-InstallDownloadsAgain-GH#1612@@Tests/VectorDatabaseDownloads.wlt:465,1-491,2"
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
    TestID   -> "Declined-LaterSearchesSkip-GH#1612@@Tests/VectorDatabaseDownloads.wlt:517,1-550,2"
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
    TestID   -> "Declined-DownloadNotOfferedAgain-GH#1612@@Tests/VectorDatabaseDownloads.wlt:553,1-575,2"
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
    TestID   -> "Declined-LaterChatCompletes-GH#1612@@Tests/VectorDatabaseDownloads.wlt:578,1-600,2"
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
    TestID   -> "Declined-CurrentChatStops-GH#1612@@Tests/VectorDatabaseDownloads.wlt:603,1-634,2"
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
    TestID   -> "Declined-AllowDownloadWins-GH#1612@@Tests/VectorDatabaseDownloads.wlt:638,1-669,2"
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
    TestID   -> "Declined-SourceSelectorSkipped-GH#1612@@Tests/VectorDatabaseDownloads.wlt:672,1-689,2"
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
    TestID   -> "Declined-InstallClearsFlag-GH#1612@@Tests/VectorDatabaseDownloads.wlt:692,1-708,2"
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
    TestID   -> "Declined-InstallReturnsFailure-GH#1612@@Tests/VectorDatabaseDownloads.wlt:710,1-721,2"
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
    TestID   -> "LoadVectorDB-FailureMessageNotSilenced-GH#1612@@Tests/VectorDatabaseDownloads.wlt:724,1-745,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`catchTop[
        Wolfram`Chatbook`Common`catchQuiet @ Wolfram`Chatbook`Common`throwInternalFailure @ "quiet";
        Wolfram`Chatbook`Common`throwFailure[ "VectorDatabaseDownloadFailed", "test" ]
    ],
    Failure[ "Chatbook::VectorDatabaseDownloadFailed", _ ],
    { Chatbook::VectorDatabaseDownloadFailed },
    SameTest -> MatchQ,
    TestID   -> "CatchQuiet-DoesNotSilenceLaterMessages-GH#1612@@Tests/VectorDatabaseDownloads.wlt:747,1-756,2"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "Declined-Repaired-GH#1612@@Tests/VectorDatabaseDownloads.wlt:758,1-765,2"
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
    TestID   -> "RepairVectorDB-FailureSkippedLater-GH#1612@@Tests/VectorDatabaseDownloads.wlt:768,1-796,2"
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
    TestID   -> "IndexFingerprint-Recorded@@Tests/VectorDatabaseDownloads.wlt:821,1-826,2"
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
    TestID   -> "IndexFingerprint-UnixTime-GH#1612@@Tests/VectorDatabaseDownloads.wlt:829,1-838,2"
]

VerificationTest[
    countIndexHashes @ validQ[ ],
    { True, 0 },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-UnchangedNotHashed-GH#1612@@Tests/VectorDatabaseDownloads.wlt:840,1-845,2"
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
    TestID   -> "SameSizeCorruption-Detected@@Tests/VectorDatabaseDownloads.wlt:847,1-860,2"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "SameSizeCorruption-Repaired@@Tests/VectorDatabaseDownloads.wlt:862,1-869,2"
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
    TestID   -> "IndexFingerprint-TouchedHashedOnce-GH#1612@@Tests/VectorDatabaseDownloads.wlt:873,1-889,2"
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
    TestID   -> "IndexFingerprint-DateListFormatReadopted-GH#1612@@Tests/VectorDatabaseDownloads.wlt:893,1-906,2"
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
    TestID   -> "IndexFingerprint-LegacyInstallSameDatesAdopted@@Tests/VectorDatabaseDownloads.wlt:908,1-919,2"
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
    TestID   -> "IndexFingerprint-LegacyInstallAdopted@@Tests/VectorDatabaseDownloads.wlt:921,1-933,2"
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
    TestID   -> "IndexFingerprint-LegacyInstallModifiedRejected@@Tests/VectorDatabaseDownloads.wlt:935,1-949,2"
]

(* A damaged index is not hashed again while it is unchanged (e.g. in later chats after the download was declined): *)
VerificationTest[
    countIndexHashes @ validQ[ ],
    { False, 0 },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-DamagedHashedOncePerSession-GH#1612@@Tests/VectorDatabaseDownloads.wlt:952,1-957,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    validQ[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-LegacyInstallModifiedRepaired@@Tests/VectorDatabaseDownloads.wlt:959,1-965,2"
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
    TestID   -> "VerifyIndexHashes-HashesOncePerSession@@Tests/VectorDatabaseDownloads.wlt:967,1-986,2"
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
    TestID   -> "GetVectorDB-TouchedIndexHashedOnce-GH#1612@@Tests/VectorDatabaseDownloads.wlt:990,1-1014,2"
]

VerificationTest[
    validQ[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "GetVectorDB-NeverHashes-Restore@@Tests/VectorDatabaseDownloads.wlt:1016,1-1021,2"
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
    TestID   -> "GetVectorDB-CachedWhileUnchanged@@Tests/VectorDatabaseDownloads.wlt:1026,1-1048,2"
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
    TestID   -> "GetVectorDB-RevalidatesAfterCorruption@@Tests/VectorDatabaseDownloads.wlt:1050,1-1070,2"
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
    TestID   -> "DownloadLock-BreaksStaleLock@@Tests/VectorDatabaseDownloads.wlt:1075,1-1096,2"
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
    TestID   -> "DownloadLock-WaitsForLiveLock@@Tests/VectorDatabaseDownloads.wlt:1098,1-1121,2"
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
    TestID   -> "DownloadLock-ReleasedOnThrow@@Tests/VectorDatabaseDownloads.wlt:1123,1-1133,2"
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
    TestID         -> "DownloadLock-UnwritableDirectoryFails-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1158,1-1183,2"
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
    TestID   -> "DownloadLock-BreaksLockFromOtherMachine-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1187,1-1205,2"
]

(* If the process table can't be read, the lock is treated like one from another machine: *)
VerificationTest[
    Module[ { dir, lock, result },
        dir  = CreateDirectory[ ];
        lock = FileNameJoin @ { dir, "download.lock" };
        writeLockFile[ lock, $MachineName, $ProcessID ];
        result = Block[ { SystemProcesses = $Failed & },
            withShortLockTimes @ TimeConstrained[ Wolfram`Chatbook`PromptGenerators`Common`withDownloadLock[ lock, "acquired" ], 30, "timed out" ]
        ];
        WithCleanup[ { result, FileExistsQ @ lock }, DeleteDirectory[ dir, DeleteContents -> True ] ]
    ],
    { "acquired", False },
    SameTest -> MatchQ,
    TestID   -> "DownloadLock-BreaksLockWithoutProcessTable-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1208,1-1221,2"
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
    TestID         -> "DownloadLock-WaitIsLimited-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1224,1-1243,2"
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
    TestID         -> "DownloadLock-FileDateOffsetNotStale-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1247,1-1267,2"
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
    TestID   -> "DownloadLock-KeptUpToDateWhileHeld-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1270,1-1291,2"
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
    TestID   -> "DownloadLock-Reentrant-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1293,1-1307,2"
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
    TestID   -> "DownloadLock-NotHeldDuringPrompts-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1310,1-1346,2"
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
    TestID   -> "PacletVectorDBDirectoryQ-PathComponents@@Tests/VectorDatabaseDownloads.wlt:1351,1-1362,2"
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
    TestID   -> "LeftoverTmp-RemovedWithoutPrompt-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1369,1-1388,2"
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
    TestID   -> "LeftoverTmp-UpdateWithoutPrompt-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1391,1-1410,2"
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
    TestID   -> "NotInstalled-NotDamaged-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1413,1-1432,2"
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
    TestID   -> "InterruptedDownload-RemovesTemporaryFiles-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1435,1-1457,2"
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
    TestID   -> "InterruptedSwap-RestoresVectorDBBackup@@Tests/VectorDatabaseDownloads.wlt:1459,1-1470,2"
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
    TestID   -> "TruncatedLeftoverZip-Rejected@@Tests/VectorDatabaseDownloads.wlt:1472,1-1483,2"
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
    TestID   -> "CompleteLeftoverZip-Unpacked@@Tests/VectorDatabaseDownloads.wlt:1485,1-1495,2"
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
    TestID   -> "FailedDownload-RetriedAndClean@@Tests/VectorDatabaseDownloads.wlt:1500,1-1516,2"
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
    TestID   -> "Declined-RetryNotStartedAgain-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1519,1-1548,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`validDownloadSizeQ @@@ {
        { 100, 100, None },
        { 99, 100, None },
        { 99, 100, 99 },
        { 100, Missing[ "NotAvailable" ], 100 },
        { 0, 100, 0 }
    },
    { True, False, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "ValidDownloadSizeQ@@Tests/VectorDatabaseDownloads.wlt:1550,1-1561,2"
]

VerificationTest[
    Block[
        { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadHashes = <| |> },
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`validDownloadHashQ[
            $name,
            FileNameJoin @ { dbDir[ ], "Values.wxf" }
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ValidDownloadHashQ-MetadataRequired@@Tests/VectorDatabaseDownloads.wlt:1563,1-1574,2"
]

VerificationTest[
    Block[
        { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexSizes = <| |> },
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBIndexSizeValidQ[ dbDir[ ], $name, "1.2.0" ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "VectorDBIndexSize-MetadataRequired@@Tests/VectorDatabaseDownloads.wlt:1576,1-1584,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadURL[ <| "CDN" -> "a", "Cloud" -> "b" |>, # ] & /@ { 1, 2, 3 },
    { "a", "b", "a" },
    SameTest -> MatchQ,
    TestID   -> "DownloadURL-Alternates@@Tests/VectorDatabaseDownloads.wlt:1586,1-1591,2"
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
    TestID   -> "Snippets-CancelledQueueItemDoesNotDownload@@Tests/VectorDatabaseDownloads.wlt:1596,1-1607,2"
]

VerificationTest[
    $snipRoot = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "SnipTest-" <> CreateUUID[ ] };
    $prompts = { };
    withPrompt[ False, Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ $snipRoot, "ResourceSystem" ] ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "Snippets-FreshInstall@@Tests/VectorDatabaseDownloads.wlt:1609,1-1616,2"
]

VerificationTest[
    { $prompts, Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`streamableSnippetsDirectoryQ0[ FileNameJoin @ { $snipRoot, "ResourceSystem" } ], FileNames[ "*.staging", $snipRoot ] },
    { { }, True, { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-FreshInstall-Valid@@Tests/VectorDatabaseDownloads.wlt:1618,1-1623,2"
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
    TestID   -> "Snippets-Truncated-Detected@@Tests/VectorDatabaseDownloads.wlt:1625,1-1635,2"
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
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`validSnippetArchiveQ[ "ResourceSystem", zip ],
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`validSnippetArchiveQ[ "ResourceSystem", bad ]
            },
            Quiet[ DeleteFile /@ { zip, bad } ]
        ]
    ],
    { True, True, False },
    SameTest -> MatchQ,
    TestID   -> "Snippets-InvalidArchiveRejected@@Tests/VectorDatabaseDownloads.wlt:1637,1-1666,2"
]

VerificationTest[
    Block[
        { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetArchiveInfo = <| |> },
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`validSnippetArchiveQ[
            "ResourceSystem",
            FileNameJoin @ { $snipRoot, "ResourceSystem", "Snippets.wxfl" }
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "Snippets-MetadataRequired@@Tests/VectorDatabaseDownloads.wlt:1668,1-1679,2"
]

VerificationTest[
    Module[ { before, result },
        before = FileNames[ "ResourceSystem-*.zip", $TemporaryDirectory ];
        (* Interrupt after the archive has been downloaded: *)
        result = Block[ { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`validSnippetArchiveQ = (Abort[ ] &) },
            CheckAbort[ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ $snipRoot, "ResourceSystem", 1, None ], "aborted" ]
        ];
        { result, Complement[ FileNames[ "ResourceSystem-*.zip", $TemporaryDirectory ], before ] }
    ],
    { "aborted", { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-AbortCleansTemporaryFile@@Tests/VectorDatabaseDownloads.wlt:1681,1-1693,2"
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
    TestID   -> "Snippets-InstallClearsIndexCache@@Tests/VectorDatabaseDownloads.wlt:1695,1-1706,2"
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
    TestID   -> "Snippets-InterruptedSwap-RestoresBackup@@Tests/VectorDatabaseDownloads.wlt:1708,1-1723,2"
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
                Length @ $prompts,
                Length @ calls,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetsDir
            }
        ]
    ],
    { { { "" }, { "" }, { "" } }, 1, 1, True, $snipRoot },
    SameTest -> MatchQ,
    TestID   -> "Snippets-Declined-LaterLookupsSkip-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1746,1-1778,2"
]

VerificationTest[
    withTestSnippets @ Block[ { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDownloadDeclined = True },
        $prompts = { };
        { withPrompt[ True, Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ ] ], $prompts }
    ],
    { Missing[ "DownloadDeclined" ], { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-Declined-DownloadNotOfferedAgain-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1780,1-1788,2"
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
    TestID   -> "Snippets-LockNotHeldDuringPrompts-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1791,1-1813,2"
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
    TestID   -> "Snippets-Declined-AllowDownloadWins-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1816,1-1837,2"
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
    TestID   -> "Snippets-Declined-InstallClearsFlag-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1839,1-1859,2"
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
    TestID   -> "Snippets-Declined-InstallReturnsFailure-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1861,1-1872,2"
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
    TestID   -> "Snippets-DamagedCheckDoesNotSilenceMessages-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1875,1-1884,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Text Resources*)
$downloadTextKeys = {
    "DownloadButton",
    "DownloadDialogTitle",
    "DownloadRedownloadPrompt",
    "DownloadRetryPrompt",
    "DownloadTypeVectorDatabases",
    "DownloadTypeVectorDatabase",
    "DownloadTypeDocumentation",
    "DownloadLabelDocumentation",
    "DownloadSizeGB",
    "DownloadSizeMB",
    "DownloadSizeUnknown",
    "DownloadDurationMinutes",
    "DownloadDurationSeconds",
    "ProgressTextDownloadingSearchIndices",
    "ProgressTextRetryingSearchIndices",
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
    TestID   -> "TextResources-Files@@Tests/VectorDatabaseDownloads.wlt:1914,1-1925,2"
]

VerificationTest[
    Union @ Flatten @ Values @ Map[ Complement[ $downloadTextKeys, Keys @ # ] &, $textResources ],
    { },
    SameTest -> MatchQ,
    TestID   -> "TextResources-AllKeysPresent@@Tests/VectorDatabaseDownloads.wlt:1927,1-1932,2"
]

VerificationTest[
    CountDistinct[ Lookup[ #, $downloadTextKeys ] & /@ Values @ $textResources ],
    1,
    SameTest -> MatchQ,
    TestID   -> "TextResources-EnglishPlaceholders@@Tests/VectorDatabaseDownloads.wlt:1934,1-1939,2"
]

VerificationTest[
    CountDistinct @ Map[ Take[ Keys @ #, -Length @ $downloadTextKeys ] &, Values @ $textResources ],
    1,
    SameTest -> MatchQ,
    TestID   -> "TextResources-SameRelativeLocation@@Tests/VectorDatabaseDownloads.wlt:1941,1-1946,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`downloadText /@ $downloadTextKeys,
    Lookup[ readTextResources @ SelectFirst[ $textResourceFiles, StringEndsQ[ "TextResources" <> $PathnameSeparator <> "ChatbookStrings.tr" ] ], $downloadTextKeys ],
    SameTest -> MatchQ,
    TestID   -> "TextResources-HeadlessLookup@@Tests/VectorDatabaseDownloads.wlt:1948,1-1953,2"
]

VerificationTest[
    {
        Wolfram`Chatbook`PromptGenerators`Common`formatByteCount[ 370*^6 ],
        Wolfram`Chatbook`PromptGenerators`Common`formatByteCount[ 2.5*^9 ],
        Wolfram`Chatbook`PromptGenerators`Common`formatByteCount[ Missing[ ] ],
        Wolfram`Chatbook`PromptGenerators`Common`Private`formatDuration[ 45 ],
        Wolfram`Chatbook`PromptGenerators`Common`Private`formatDuration[ 600 ]
    },
    { "370 MB", "2.5 GB", "an unknown size", "45 seconds", "10 minutes" },
    SameTest -> MatchQ,
    TestID   -> "TextResources-Formatting@@Tests/VectorDatabaseDownloads.wlt:1955,1-1966,2"
]

(* Download text never uses a front end in a headless kernel, even for prompts (a front end launched by UsingFrontEnd
   would look up the text in the installed Chatbook paclet): *)
VerificationTest[
    Module[ { uses = 0, result },
        result = Block[ { Wolfram`Chatbook`Common`usingFrontEnd = Function[ Null, uses++; "text", HoldAllComplete ] },
            $prompts = { };
            {
                Wolfram`Chatbook`PromptGenerators`Common`downloadText /@ $downloadTextKeys,
                Wolfram`Chatbook`PromptGenerators`Common`formatByteCount[ 370*^6 ],
                withPrompt[ True, Wolfram`Chatbook`PromptGenerators`Common`confirmRedownload[ "DownloadTypeVectorDatabases", { "A" }, 370*^6 ] ],
                withPrompt[ True, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ "B", 370*^6, 1*^6 ] ],
                $prompts
            }
        ];
        { result, uses }
    ],
    {
        {
            { __String },
            "370 MB",
            True,
            True,
            {
                _String? (StringContainsQ[ #, "semantic search indices" ] && StringContainsQ[ #, "370 MB" ] &),
                _String? (StringContainsQ[ #, "B (about 370 MB)" ] && StringContainsQ[ #, "minutes" ] &)
            }
        },
        0
    },
    SameTest -> MatchQ,
    TestID   -> "TextResources-NoFrontEnd-GH#1612@@Tests/VectorDatabaseDownloads.wlt:1970,1-1999,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet[ DeleteDirectory[ #, DeleteContents -> True ] & /@ { $root, $snipRoot } ],
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "Cleanup@@Tests/VectorDatabaseDownloads.wlt:2004,1-2009,2"
]

(* :!CodeAnalysis::EndBlock:: *)
