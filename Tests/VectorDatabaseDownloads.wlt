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

VerificationTest[
    $name   = "NeuralNetRepositoryURIs";
    $root   = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "VDBTest-" <> CreateUUID[ ] };
    $urls   = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadURLs;
    $prompts = { };
    DirectoryQ @ $root && AssociationQ @ $urls,
    True,
    SameTest -> MatchQ,
    TestID   -> "Setup"
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
    TestID   -> "EstimateDownloadTime"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`estimateDownloadTime[ 10*^6, None ],
    5.,
    SameTest -> Equal,
    TestID   -> "EstimateDownloadTime-FallbackRate"
]

VerificationTest[
    $prompts = { };
    withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ "small", 1*^6, 1*^6 ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-ShortNoPrompt"
]

VerificationTest[
    $prompts,
    { },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-ShortNoPrompt-Check"
]

VerificationTest[
    withPrompt[ False, Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ "big", 370*^6, 1*^6 ] ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-LongPrompts"
]

VerificationTest[
    $prompts,
    { _String? (StringContainsQ[ "try again" ]) },
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-LongPrompts-Check"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`Common`Private`$downloadPromptAllowed = False },
        Wolfram`Chatbook`PromptGenerators`Common`confirmDownloadRetry[ "big", 370*^6, 1*^6 ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ConfirmDownloadRetry-HeadlessProceeds"
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
    TestID   -> "FreshInstall"
]

VerificationTest[
    { $prompts, validQ[ ], FileNames[ "*", $root ] },
    { { }, True, { _String? (StringEndsQ[ $name ]), _String? (StringEndsQ[ "download.lock" ]) } | { _String? (StringEndsQ[ $name ]) } },
    SameTest -> MatchQ,
    TestID   -> "FreshInstall-NoPromptAndClean"
]

VerificationTest[
    Sort[ FileNameTake[ #, -1 ] & /@ FileNames[ "*", dbDir[ ] ] ],
    Sort @ { "Manifest.wxf", "NeuralNetRepositoryURIs-vectors.usearch", "NeuralNetRepositoryURIs.wxf", "Values.wxf", "Version.wl" },
    SameTest -> MatchQ,
    TestID   -> "FreshInstall-Files"
]

VerificationTest[
    Developer`ReadWXFFile @ FileNameJoin @ { dbDir[ ], "Manifest.wxf" },
    KeyValuePattern @ { "Version" -> "1.2.0", "Files" -> KeyValuePattern[ "NeuralNetRepositoryURIs-vectors.usearch" -> 4401488 ] },
    SameTest -> MatchQ,
    TestID   -> "FreshInstall-Manifest"
]

VerificationTest[
    $prompts = { };
    withPrompt[ False, download @ $name ],
    $root,
    SameTest -> MatchQ,
    TestID   -> "AlreadyInstalled-NoDownload"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Corrupt Install Detected*)
VerificationTest[
    truncateIndex[ ];
    validQ[ ],
    False,
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Detected"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBDamagedQ[ $root, $name ],
    True,
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-DamagedQ"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
        { withPrompt[ False, download @ $name ], Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined }
    ],
    { Failure[ "Chatbook::VectorDatabaseDownloadDeclined", _ ], True },
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Declined"
]

VerificationTest[
    $prompts,
    { _String? (StringContainsQ[ #, "incomplete or corrupt" ] && StringContainsQ[ #, $name ] &) },
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Declined-Prompted"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False },
        withPrompt[ True, download @ $name ]
    ],
    $root,
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Accepted"
]

VerificationTest[
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "TruncatedIndex-Repaired"
]

VerificationTest[
    $prompts = { };
    DeleteFile @ FileNameJoin @ { dbDir[ ], "Values.wxf" };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "MissingFile-Repaired"
]

VerificationTest[
    With[ { m = FileNameJoin @ { dbDir[ ], "Values.wxf" } },
        With[ { b = ReadByteArray @ m }, DeleteFile @ m; BinaryWrite[ m, b[[ 1 ;; 100 ]] ]; Close @ m ]
    ];
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBManifestValidQ[ dbDir[ ] ],
    False,
    SameTest -> MatchQ,
    TestID   -> "Manifest-DetectsTruncatedValues"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    validQ[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Manifest-Repaired"
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
    TestID   -> "LoadVectorDB-SelfRepair"
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

VerificationTest[
    Developer`ReadWXFFile @ FileNameJoin @ { dbDir[ ], "Manifest.wxf" },
    KeyValuePattern[ "IndexFingerprint" -> { 4401488, { __? NumberQ } } ],
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-Recorded"
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
    TestID   -> "SameSizeCorruption-Detected"
]

VerificationTest[
    $prompts = { };
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    { Length @ $prompts, validQ[ ] },
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "SameSizeCorruption-Repaired"
]

VerificationTest[
    Module[ { f, manifestFile },
        f = FileNameJoin @ { dbDir[ ], $name <> "-vectors.usearch" };
        manifestFile = FileNameJoin @ { dbDir[ ], "Manifest.wxf" };
        (* An unchanged index whose modification date changed (e.g. restored from a backup) is verified by hash: *)
        SetFileDate[ f, Now - Quantity[ 1, "Days" ] ];
        {
            validQ[ ],
            Developer`ReadWXFFile[ manifestFile ][ "IndexFingerprint" ] === Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`fileFingerprint @ f
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-TouchedButIntact"
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
    TestID   -> "IndexFingerprint-LegacyInstallAdopted"
]

VerificationTest[
    Module[ { manifestFile },
        manifestFile = FileNameJoin @ { dbDir[ ], "Manifest.wxf" };
        DeleteFile @ manifestFile;
        (* Legacy install whose index was modified after it was installed: *)
        flipIndexBytes[ ];
        { validQ[ ], FileExistsQ @ manifestFile }
    ],
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-LegacyInstallModifiedRejected"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
    validQ[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "IndexFingerprint-LegacyInstallModifiedRepaired"
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
    TestID   -> "VerifyIndexHashes-HashesOncePerSession"
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
    TestID   -> "GetVectorDB-CachedWhileUnchanged"
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
    TestID   -> "GetVectorDB-RevalidatesAfterCorruption"
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
    TestID   -> "DownloadLock-BreaksStaleLock"
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
    TestID   -> "DownloadLock-WaitsForLiveLock"
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
    TestID   -> "DownloadLock-ReleasedOnThrow"
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
    TestID   -> "PacletVectorDBDirectoryQ-PathComponents"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Leftover Artifacts*)
VerificationTest[
    Module[ { tmp },
        DeleteDirectory[ dbDir[ ], DeleteContents -> True ];
        tmp = FileNameJoin @ { $root, $name <> ".zip." <> CreateUUID[ ] <> ".tmp" };
        BinaryWrite[ tmp, ByteArray @ RandomInteger[ 255, 1000 ] ]; Close @ tmp;
        SetFileDate[ tmp, Now - Quantity[ 1, "Hours" ] ];
        $prompts = { };
        Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDownloadDeclined = False }, withPrompt[ True, download @ $name ] ];
        { Length @ $prompts, FileExistsQ @ tmp, validQ[ ], FileNames[ "*.tmp", $root ] }
    ],
    { 1, False, True, { } },
    SameTest -> MatchQ,
    TestID   -> "StaleTmp-PromptsCleansAndReinstalls"
]

VerificationTest[
    Module[ { tmp },
        tmp = FileNameJoin @ { $root, "Other.zip." <> CreateUUID[ ] <> ".tmp" };
        BinaryWrite[ tmp, ByteArray @ { 1, 2, 3 } ]; Close @ tmp;
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`cleanupPartialDownloads[ $root ];
        WithCleanup[ FileExistsQ @ tmp, Quiet @ DeleteFile @ tmp ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "FreshTmp-NotDeleted"
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
    TestID   -> "InterruptedSwap-RestoresVectorDBBackup"
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
    TestID   -> "TruncatedLeftoverZip-Rejected"
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
    TestID   -> "CompleteLeftoverZip-Unpacked"
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
    TestID   -> "FailedDownload-RetriedAndClean"
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
    TestID   -> "ValidDownloadSizeQ"
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
    TestID   -> "ValidDownloadHashQ-MetadataRequired"
]

VerificationTest[
    Block[
        { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBIndexSizes = <| |> },
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBIndexSizeValidQ[ dbDir[ ], $name, "1.2.0" ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "VectorDBIndexSize-MetadataRequired"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`downloadURL[ <| "CDN" -> "a", "Cloud" -> "b" |>, # ] & /@ { 1, 2, 3 },
    { "a", "b", "a" },
    SameTest -> MatchQ,
    TestID   -> "DownloadURL-Alternates"
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
    TestID   -> "Snippets-CancelledQueueItemDoesNotDownload"
]

VerificationTest[
    $snipRoot = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "SnipTest-" <> CreateUUID[ ] };
    $prompts = { };
    withPrompt[ False, Quiet @ Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`downloadStreamableSnippets[ $snipRoot, "ResourceSystem" ] ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "Snippets-FreshInstall"
]

VerificationTest[
    { $prompts, Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`streamableSnippetsDirectoryQ0[ FileNameJoin @ { $snipRoot, "ResourceSystem" } ], FileNames[ "*.staging", $snipRoot ] },
    { { }, True, { } },
    SameTest -> MatchQ,
    TestID   -> "Snippets-FreshInstall-Valid"
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
    TestID   -> "Snippets-Truncated-Detected"
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
    TestID   -> "Snippets-InvalidArchiveRejected"
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
    TestID   -> "Snippets-MetadataRequired"
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
    TestID   -> "Snippets-AbortCleansTemporaryFile"
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
    TestID   -> "Snippets-InstallClearsIndexCache"
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
    TestID   -> "Snippets-InterruptedSwap-RestoresBackup"
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
    TestID   -> "TextResources-Files"
]

VerificationTest[
    Union @ Flatten @ Values @ Map[ Complement[ $downloadTextKeys, Keys @ # ] &, $textResources ],
    { },
    SameTest -> MatchQ,
    TestID   -> "TextResources-AllKeysPresent"
]

VerificationTest[
    CountDistinct[ Lookup[ #, $downloadTextKeys ] & /@ Values @ $textResources ],
    1,
    SameTest -> MatchQ,
    TestID   -> "TextResources-EnglishPlaceholders"
]

VerificationTest[
    CountDistinct @ Map[ Take[ Keys @ #, -Length @ $downloadTextKeys ] &, Values @ $textResources ],
    1,
    SameTest -> MatchQ,
    TestID   -> "TextResources-SameRelativeLocation"
]

VerificationTest[
    Wolfram`Chatbook`Common`trRaw /@ $downloadTextKeys,
    Lookup[ readTextResources @ SelectFirst[ $textResourceFiles, StringEndsQ[ "TextResources" <> $PathnameSeparator <> "ChatbookStrings.tr" ] ], $downloadTextKeys ],
    SameTest -> MatchQ,
    TestID   -> "TextResources-HeadlessLookup"
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
    TestID   -> "TextResources-Formatting"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet[ DeleteDirectory[ #, DeleteContents -> True ] & /@ { $root, $snipRoot } ],
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "Cleanup"
]

(* :!CodeAnalysis::EndBlock:: *)
