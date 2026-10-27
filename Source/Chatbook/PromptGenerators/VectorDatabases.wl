(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`VectorDatabases`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

HoldComplete[
    System`VectorDatabaseObject,
    System`VectorDatabaseSearch
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::VectorDatabaseCloudDownload = "\
Warning: Local vector databases are out of date. Downloading updated vector databases...";

Chatbook::VectorDatabaseDownloadDeclined = "\
Semantic search indices are not available because the download was cancelled. \
Evaluate InstallVectorDatabases[] to install them.";

Chatbook::VectorDatabaseDownloadFailed = "\
Failed to download semantic search indices: `1`. \
Please check your internet connection and evaluate InstallVectorDatabases[] to try again.";

Chatbook::VectorDatabaseLoadFailed = "\
Failed to load the semantic search index \"`1`\". Evaluate InstallVectorDatabases[] to reinstall it.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$suppressDownloadWarning = False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Vector Databases*)
$vectorDatabases = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*DataRepositoryURIs*)
$vectorDatabases[ "DataRepositoryURIs" ] = <|
    "Version"         -> "1.2.0",
    "Bias"            -> 1.0,
    "SnippetFunction" -> getStreamSnippets[ "ResourceSystem" ],
    "Instructions"    -> None
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*DocumentationURIs*)
$vectorDatabases[ "DocumentationURIs" ] = <|
    "Version"         :> If[ $VersionNumber >= 15.0, "1.6.0", "1.5.0" ],
    "Bias"            -> 0.0,
    "SnippetFunction" -> getStreamSnippets[ "Documentation" ],
    "Instructions"    -> None
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*EntityValues*)
$vectorDatabases[ "EntityValues" ] = <|
    "Version"         -> "1.1.0",
    "Bias"            -> 0.0,
    "SnippetFunction" -> getStreamSnippets[ "Documentation" ],
    "Instructions"    :> getNamedSnippet[ "EntityValueInstructions" ]
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*FunctionRepositoryURIs*)
$vectorDatabases[ "FunctionRepositoryURIs" ] = <|
    "Version"         -> "1.3.0",
    "Bias"            -> 1.0,
    "SnippetFunction" -> getStreamSnippets[ "ResourceSystem" ],
    "Instructions"    -> None
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*NeuralNetRepositoryURIs*)
$vectorDatabases[ "NeuralNetRepositoryURIs" ] = <|
    "Version"         -> "1.2.0",
    "Bias"            -> 1.0,
    "SnippetFunction" -> getStreamSnippets[ "ResourceSystem" ],
    "Instructions"    -> None
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*PacletRepositoryURIs*)
$pacletRepositoryInstructions = "\
IMPORTANT: Always use PacletSymbol to reference symbols from paclets in the paclet repository \
(anything from https://paclets.com).";

$vectorDatabases[ "PacletRepositoryURIs" ] = <|
    "Version"         -> "1.2.0",
    "Bias"            -> 2.0,
    "SnippetFunction" -> getStreamSnippets[ "ResourceSystem" ],
    "Instructions"    -> { URL[ "paclet:ref/PacletSymbol#1" ], $pacletRepositoryInstructions }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*SourceSelector*)
$vectorDatabases[ "SourceSelector" ] = <|
    "Version"         -> "1.5.0",
    "Bias"            -> 0.0,
    "SnippetFunction" -> Identity,
    "Instructions"    -> None
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*WolframAlphaQueries*)
$vectorDatabases[ "WolframAlphaQueries" ] = <|
    "Version"         -> "1.3.0",
    "Bias"            -> 0.0,
    "SnippetFunction" -> Identity,
    "Instructions"    -> None
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other Settings*)
$vectorDBNames  := $vectorDBNames = Keys @ $vectorDatabases;
$allowDownload   = True;
$cacheEmbeddings = True;

(* Keep one memory-mapped index per vector database instead of re-opening it on every search: *)
$cacheUSearchIndexes = True;

(* Release the memory-mapped indexes after this many seconds without a search: *)
$usearchIndexIdleTime = 300;

(* Set when the user declines a download, repair or retry prompt. For the rest of the session, databases that are not
   installed (or are damaged) are skipped instead of prompting again, until InstallVectorDatabases[] is evaluated: *)
$vectorDBDownloadDeclined = False;

(* Set to the failure of a download that failed in a chat. For the rest of the session, later chats don't download
   again (databases that are not installed, or are damaged, are skipped), until InstallVectorDatabases[] is evaluated: *)
$vectorDBDownloadFailure = None;

$downloadProgress = <| |>;
$downloadStatus   = <| |>;

(* Databases that could not be loaded even after downloading them again. They are skipped for the rest of the session,
   until InstallVectorDatabases[] downloads them again: *)
$vectorDBLoadFailures = { };

(* Databases that are downloaded again even if their files look intact (see repairVectorDB): *)
$forcedVectorDBDownloads = { };

$embeddingDimension      = 384;
$maxNeighbors            = 250;
$maxEmbeddingDistance    = 150.0;
$embeddingService        = "Local";
$embeddingModel          = "SentenceBERT";
$embeddingAuthentication = Automatic;

(* Maximum number of cached search results and embeddings (the oldest half is dropped when exceeded): *)
$maxVectorDBSearchCacheSize = 100;
$maxEmbeddingCacheSize      = 1000;


$conversationVectorSearchPenalty = 1.0;

$relatedQueryCount = 5;
$relatedDocsCount  = 20;
$querySampleCount  = 10;

$relevantFileCount = 3;
$maxExtraFiles     = 20;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Remote Content Locations*)
$cdnBaseVectorDatabasesURL   = "https://files.wolframcdn.com/VectorDatabases";
$cloudBaseVectorDatabasesURL = "https://www.wolframcloud.com/obj/wolframai-content/VectorDatabases";

(* Each database is downloaded from these in order, until one succeeds (see downloadVectorDatabaseSources): *)
$vectorDBDownloadSources = { "CDN", "Cloud" };

$vectorDBDownloadURLs := $vectorDBDownloadURLs = AssociationMap[
    <|
        "CDN"   -> makeDownloadURL[ $cdnBaseVectorDatabasesURL  , # ],
        "Cloud" -> makeDownloadURL[ $cloudBaseVectorDatabasesURL, # ]
    |> &,
    $vectorDBNames
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Download Metadata*)
(* The tables below are generated by Scripts/UpdateDownloadMetadata.wls. Do not edit them manually. *)
(* BEGIN GENERATED: VectorDatabaseDownloadMetadata *)
(* Sizes of the downloaded archives (keyed by name and version): *)
$vectorDBArchiveSizes = <|
    { "DataRepositoryURIs"     , "1.2.0" } ->   5812001,
    { "DocumentationURIs"      , "1.5.0" } -> 348652827,
    { "DocumentationURIs"      , "1.6.0" } -> 369969648,
    { "EntityValues"           , "1.1.0" } ->  63998991,
    { "FunctionRepositoryURIs" , "1.3.0" } ->  61661803,
    { "NeuralNetRepositoryURIs", "1.2.0" } ->   2512274,
    { "PacletRepositoryURIs"   , "1.2.0" } ->  14170624,
    { "SourceSelector"         , "1.5.0" } -> 115700803,
    { "WolframAlphaQueries"    , "1.3.0" } ->  19410556
|>;

(* Expected sizes of the vector index files after extraction (keyed by name and version): *)
$vectorDBIndexSizes = <|
    { "DataRepositoryURIs"     , "1.2.0" } ->   9805776,
    { "DocumentationURIs"      , "1.5.0" } -> 564222592,
    { "DocumentationURIs"      , "1.6.0" } -> 593388624,
    { "EntityValues"           , "1.1.0" } -> 106272876,
    { "FunctionRepositoryURIs" , "1.3.0" } ->  98466704,
    { "NeuralNetRepositoryURIs", "1.2.0" } ->   4401488,
    { "PacletRepositoryURIs"   , "1.2.0" } ->  23555472,
    { "SourceSelector"         , "1.5.0" } -> 196093584,
    { "WolframAlphaQueries"    , "1.3.0" } ->  31829648
|>;

(* SHA-256 hashes of the downloaded archives (keyed by name and version): *)
$vectorDBDownloadHashes = <|
    { "DataRepositoryURIs"     , "1.2.0" } -> "e6eae133505af3d57d772f236f37b42298fa52d3d466ea5d26995f87af5be38e",
    { "DocumentationURIs"      , "1.5.0" } -> "e7fba9a6ff5154ac5e70034c04ab99631e70a5d47b6f721bb8ae8e78a21f8ab9",
    { "DocumentationURIs"      , "1.6.0" } -> "d3b6336dbaa26cb6300de12c3cc5e4f11e87a618222d8e631f47b622c5b478c8",
    { "EntityValues"           , "1.1.0" } -> "3f28b96a20b2041e24c947440c40c2eae4c631a0f44fa5590fa7760a53cb7ba5",
    { "FunctionRepositoryURIs" , "1.3.0" } -> "2ceea0ef96368bb1262875d8ee732d8f5fd7ee8d4ca7f1a99413354d4b548350",
    { "NeuralNetRepositoryURIs", "1.2.0" } -> "685add5d5d404f713375c1679b43d5abb1450e4e6673aeffdaf8a5d109a54d26",
    { "PacletRepositoryURIs"   , "1.2.0" } -> "b145b8bee6bfbe49461ad8dbcbf4bd970d497b1f59f93b6d38b33354abddb6cd",
    { "SourceSelector"         , "1.5.0" } -> "ab30dce8ee13ca04e09474220570c7bc5c206c066612d7717f8ac6f0d0cc03b6",
    { "WolframAlphaQueries"    , "1.3.0" } -> "97de69e0fa681b9e686c45aabac7b7c11508659c602c9c4331946f169b161bc7"
|>;

(* SHA-256 hashes of the vector index files after extraction (keyed by name and version): *)
$vectorDBIndexHashes = <|
    { "DataRepositoryURIs"     , "1.2.0" } -> "d69717e8a419562bb0b52ae84d19333add82e0fe20047d8423413cda3e00f144",
    { "DocumentationURIs"      , "1.5.0" } -> "c8bf047f33a1d04b2e1c2278fee70f3c700b1cc2141c210865133501142d7b61",
    { "DocumentationURIs"      , "1.6.0" } -> "29fdb2ec5681bfea5c445f1963a694dae4762500bc1661d65473f55331ee3921",
    { "EntityValues"           , "1.1.0" } -> "d56b31964bb2d93351bd8c1ea22966b5c758c5abf6374349f4d2ee62a01fabbc",
    { "FunctionRepositoryURIs" , "1.3.0" } -> "12c6cf606c5cdddb3584637edeac41d27e2e8359a77fbb77c4155235d552ae2b",
    { "NeuralNetRepositoryURIs", "1.2.0" } -> "6a24c6c7817d434233abb879201c4a4be8094a56f766079a17c19dfa3910b71c",
    { "PacletRepositoryURIs"   , "1.2.0" } -> "dd700b6ddbbd1a24d1e94bf145678e758467756122976ca6989a90ccff998420",
    { "SourceSelector"         , "1.5.0" } -> "278d783b58799cb02263f5d5c8518437cd9b543e9910971f0b102e0e6a54abe4",
    { "WolframAlphaQueries"    , "1.3.0" } -> "cf442349eacf48750144e33ee5f864a509f8ec323538363eb8fcaa113bf3666a"
|>;
(* END GENERATED: VectorDatabaseDownloadMetadata *)

(* Archive sizes for the versions used by the current Wolfram Language version: *)
$vectorDBDownloadSizes := AssociationMap[
    Lookup[ $vectorDBArchiveSizes, Key @ { #, $vectorDatabases[ #, "Version" ] }, Missing[ "NotAvailable" ] ] &,
    $vectorDBNames
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeDownloadURL*)
makeDownloadURL // beginDefinition;
makeDownloadURL[ base_String, name_String ] := makeDownloadURL[ base, name, $vectorDatabases[ name, "Version" ] ];
makeDownloadURL[ base_String, name_String, version_String ] := URLBuild @ { base, name, version, name <> ".zip" };
makeDownloadURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paths*)
$pacletVectorDBDirectory := FileNameJoin @ { $thisPaclet[ "Location" ], "Assets/VectorDatabases" };
$localVectorDBDirectory  := ChatbookFilesDirectory[ { "VectorDatabases", $versionString }, "EnsureDirectory" -> False ];
$cloudVectorDBDirectory  := PacletObject[ "Wolfram/NotebookAssistantCloudResources" ][ "AssetLocation", "VectorDatabases" ];

$versionString := StringReplace[ ToString @ $VersionNumber, { "."~~EndOfString :> "-0", "." -> "-" } ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Argument Patterns*)
$$vectorDatabase = HoldPattern[ _VectorDatabaseObject? System`Private`ValidQ ];

$$dbName        = _String? vectorDBNameQ;
$$dbNames       = { $$dbName... };
$$dbNameOrNames = $$dbName | $$dbNames;

$$vectorDatabaseSource = $$vectorDatabase | _? DirectoryQ | _? FileExistsQ;

(* Size and modification time (as a Unix time) of an index file: *)
$$indexFingerprint = { _Integer, _Integer };

(* Returned instead of a loaded database that is skipped, because its download was declined or failed, or because it
   could not be loaded even after downloading it again: *)
$$skippedVectorDB = $$downloadSkipped | Missing[ "LoadFailed", ___ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBNameQ*)
vectorDBNameQ // beginDefinition;
vectorDBNameQ[ name_String ] := MemberQ[ $vectorDBNames, name ];
vectorDBNameQ[ ___ ] := False;
vectorDBNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cache*)
$vectorDBSearchCache = <| |>;
$embeddingCache      = <| |>;
$loadedVectorDBs     = <| |>;

(* Set to True to verify index hashes even when the index file appears unchanged: *)
$verifyIndexHashes = False;

(* Results of hashing index files, keyed by file and fingerprint, so that an index is hashed at most once per session
   while it is unchanged: *)
$verifiedIndexFingerprints   = <| |>;
$maxVerifiedIndexFingerprints = 100;

$modificationDateTolerance = 2;

(* Persistent USearch index handles used by vectorDatabaseSearch: *)
$usearchIndexCache       = <| |>;
$usearchIndexVerified    = <| |>;
$usearchIndexFailures    = <| |>;
$usearchIndexLastUsed    = 0;
$usearchIndexReleaseTask = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::InvalidVectorDatabaseName         = "Expected a string for vector database name instead of `1`";
Chatbook::InvalidVectorDatabaseValues       = "Expected a list of strings for vector database values instead of `1`";
Chatbook::VectorDatabaseValuesFileNotFound  = "Values file not found: `1`";
Chatbook::InvalidVectorDatabaseDimensions   = "Dimensions of vectors (`1`) do not match expected dimensions (`2`)";
Chatbook::InvalidVectorDatabaseValuesLength = "The number of values (`1`) does not match the number of vectors (`2`)";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RegisterVectorDatabase*)
RegisterVectorDatabase // beginDefinition;

RegisterVectorDatabase[ source: $$vectorDatabaseSource ] :=
    catchMine @ RegisterVectorDatabase[ source, <| |> ];

RegisterVectorDatabase[ source: $$vectorDatabaseSource, as_Association ] :=
    catchMine @ registerVectorDatabase @ toVectorDatabaseInfo[ source, as ];

RegisterVectorDatabase // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toVectorDatabaseInfo*)
toVectorDatabaseInfo // beginDefinition;

toVectorDatabaseInfo[ source: $$vectorDatabaseSource, info0_Association ] := Enclose[
    Module[ { info, name, values, length, dim, bias, version, db, valueFunction, instructions, position },

        info = info0;

        name = getVectorDatabaseName[ source, info ];
        If[ ! StringQ @ name, throwFailure[ "InvalidVectorDatabaseName", name ] ];
        info[ "Name" ] = name;

        values = getVectorDatabaseValues[ source, info ];
        If[ ! MatchQ[ values, { ___String } ], throwFailure[ "InvalidVectorDatabaseValues", values ] ];
        info[ "Values" ] = values;

        { length, dim } = ConfirmMatch[
            getVectorDatabaseDimensions[ source, info ],
            { _Integer, _Integer },
            "Dimensions"
        ];

        If[ dim =!= $embeddingDimension, throwFailure[ "InvalidVectorDatabaseDimensions", dim, $embeddingDimension ] ];
        If[ Length @ values =!= length, throwFailure[ "InvalidVectorDatabaseValuesLength", Length @ values, length ] ];
        info[ "Dimensions" ] = { length, dim };

        bias = Lookup[ info, "Bias", 0.0 ];
        If[ ! NumberQ @ bias, throwFailure[ "InvalidVectorDatabaseBias", bias ] ];
        info[ "Bias" ] = bias;

        version = Lookup[ info, "Version", "1.0.0" ];
        If[ ! StringQ @ version, version = "1.0.0" ];
        info[ "Version" ] = version;

        db = ConfirmMatch[ getVectorDatabaseObject[ source, info ], $$vectorDatabase, "VectorDatabaseObject" ];
        info[ "VectorDatabaseObject" ] = db;

        valueFunction = Replace[ Lookup[ info, "SnippetFunction" ], $$unspecified -> Identity ];
        info[ "SnippetFunction" ] = valueFunction;

        instructions = Replace[ Lookup[ info, "Instructions" ], $$unspecified -> None ];
        info[ "Instructions" ] = instructions;

        position = Replace[ Lookup[ info, "InstructionsPosition" ], $$unspecified -> After ];
        info[ "InstructionsPosition" ] = position;

        info
    ],
    throwInternalFailure
];

toVectorDatabaseInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getVectorDatabaseName*)
getVectorDatabaseName // beginDefinition;
getVectorDatabaseName[ db: $$vectorDatabase, info_Association ] := Lookup[ info, "Name", db[ "ID" ] ];
getVectorDatabaseName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getVectorDatabaseValues*)
getVectorDatabaseValues // beginDefinition;

getVectorDatabaseValues[ source_, as: KeyValuePattern[ "Values" -> values_? FileExistsQ ] ] :=
    getVectorDatabaseValues[ values, as ];

getVectorDatabaseValues[ source_, KeyValuePattern[ "Values" -> values: Except[ $$unspecified ] ] ] :=
    values;

getVectorDatabaseValues[ dir_? DirectoryQ, info_ ] := Enclose[
    Module[ { name, infoFile, valuesFile },

        name       = ConfirmBy[ info[ "Name" ], StringQ, "Name" ];
        infoFile   = FileNameJoin @ { dir, name <> ".wxf" };
        valuesFile = FileNameJoin @ { dir, "Values.wxf" };

        If[ FileExistsQ @ valuesFile,
            getVectorDatabaseValues[ valuesFile, info ],
            getVectorDatabaseValues[ infoFile, info ]
        ]
    ],
    throwInternalFailure
];

getVectorDatabaseValues[ file_? FileExistsQ, info_ ] :=
    toVectorDatabaseValues @ Developer`ReadWXFFile @ ExpandFileName @ file;

getVectorDatabaseValues[ db: $$vectorDatabase, info_ ] :=
    getVectorDatabaseValues[ DirectoryName @ db[ "Location" ], info ];

getVectorDatabaseValues // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toVectorDatabaseValues*)
toVectorDatabaseValues // beginDefinition;
toVectorDatabaseValues[ v: { ___String } ] := v;
toVectorDatabaseValues[ KeyValuePattern[ "Metadata" -> KeyValuePattern[ Automatic -> v: { ___String } ] ] ] := v;
toVectorDatabaseValues // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getVectorDatabaseDimensions*)
getVectorDatabaseDimensions // beginDefinition;

getVectorDatabaseDimensions[ db: $$vectorDatabase, info_ ] :=
    db[ "Dimensions" ];

getVectorDatabaseDimensions[ dir_? DirectoryQ, info_Association ] := Enclose[
    Module[ { name, file },
        name = ConfirmBy[ info[ "Name" ], StringQ, "Name" ];
        file = ConfirmBy[ FileNameJoin @ { dir, name <> ".wxf" }, FileExistsQ, "File" ];
        getVectorDatabaseDimensions[ file, info ]
    ],
    throwInternalFailure
];

getVectorDatabaseDimensions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getVectorDatabaseObject*)
getVectorDatabaseObject // beginDefinition;

getVectorDatabaseObject[ source_, KeyValuePattern[ "VectorDatabaseObject" -> db: $$vectorDatabase ] ] :=
    db;

getVectorDatabaseObject[ db: $$vectorDatabase, info_ ] :=
    db;

getVectorDatabaseObject[ dir_? DirectoryQ, info_ ] := Enclose[
    Module[ { name, file },
        name = ConfirmBy[ info[ "Name" ], StringQ, "Name" ];
        file = ConfirmBy[ FileNameJoin @ { dir, name <> ".wxf" }, FileExistsQ, "File" ];
        getVectorDatabaseObject[ file, info ]
    ],
    throwInternalFailure
];

getVectorDatabaseObject[ file_? FileExistsQ, info_ ] :=
    VectorDatabaseObject @ Flatten @ File @ file;

getVectorDatabaseObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*registerVectorDatabase*)
registerVectorDatabase // beginDefinition;

registerVectorDatabase[ info_Association ] := Enclose[
    Module[ { name, version, bias, values, db, valueFunction, instructions, position },

        ConfirmAssert[ DirectoryQ @ $vectorDBDirectory, "DownloadCheck" ];

        name          = ConfirmBy[ info[ "Name" ], StringQ, "Name" ];
        version       = ConfirmBy[ info[ "Version" ], StringQ, "Version" ];
        bias          = ConfirmBy[ info[ "Bias" ], NumberQ, "Bias" ];
        values        = ConfirmMatch[ info[ "Values" ], { ___String }, "Values" ];
        db            = ConfirmMatch[ info[ "VectorDatabaseObject" ], $$vectorDatabase, "VectorDatabaseObject" ];
        valueFunction = ConfirmMatch[ info[ "SnippetFunction" ], Except[ $$unspecified ], "SnippetFunction" ];
        instructions  = ConfirmMatch[ info[ "Instructions" ], Except[ $$unspecified ], "Instructions" ];

        position = ConfirmMatch[
            Lookup[ info, "InstructionsPosition", After ],
            Except[ $$unspecified ],
            "InstructionsPosition"
        ];

        getVectorDB[ name ] = <| "Values" -> values, "VectorDatabaseObject" -> db |>;

        $vectorDatabases[ name ] = <|
            "Version"              -> version,
            "Bias"                 -> bias,
            "SnippetFunction"      -> valueFunction,
            "Instructions"         -> instructions,
            "InstructionsPosition" -> position
        |>;

        $vectorDBNames = DeleteDuplicates @ Append[ $vectorDBNames, name ];

        $RelatedDocumentationSources = Take[
            DeleteDuplicates @ Prepend[
                ConfirmMatch[ $defaultSources, { ___String }, "DefaultSources" ],
                name
            ],
            UpTo[ $maxSelectedSources ]
        ];

        Success[
            "VectorDatabaseRegistered",
            KeyTake[
                info,
                {
                    "Name",
                    "Version",
                    "Bias",
                    "SnippetFunction",
                    "Instructions",
                    "InstructionsPosition",
                    "VectorDatabaseObject"
                }
            ]
        ]
    ],
    throwInternalFailure
];

registerVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InstallVectorDatabases*)
InstallVectorDatabases // beginDefinition;

(* An explicit request to install, so a download that was declined or failed earlier in the session is tried again,
   and databases that could not be loaded are downloaded again: *)
InstallVectorDatabases[ ] :=
    catchMine @ Block[ { $pacletVectorDBDirectory = None, $suppressDownloadWarning = True },
        $vectorDBDownloadDeclined = False;
        $vectorDBDownloadFailure  = None;
        installVectorDatabases[ ]
    ];

InstallVectorDatabases // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*installVectorDatabases*)
installVectorDatabases // beginDefinition;

installVectorDatabases[ ] := Enclose[
    Module[ { dir, snippets, snippetDir },
        reinstallFailedVectorDBs[ ];
        dir = getVectorDBDirectory[ ];
        (* The download failed, and its message has been shown (see catchDownloadFailure): *)
        If[ MatchQ[ dir, Missing[ "DownloadFailed", _Failure ] ], throwTop @ Last @ dir ];
        If[ MatchQ[ dir, $$downloadDeclined ], throwFailure[ "VectorDatabaseDownloadDeclined" ] ];
        ConfirmBy[ dir, vectorDBDirectoryQ, "Location" ];
        snippets = ConfirmMatch[ InstallDocumentationResources[ ], _Success, "Snippets" ];
        snippetDir = ConfirmBy[ snippets[ "Location" ], DirectoryQ, "SnippetLocation" ];
        Success[ "VectorDatabasesInstalled", <| "Location" -> dir, "Snippets" -> snippetDir |> ]
    ],
    throwInternalFailure
];

installVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reinstallFailedVectorDBs*)
(* Downloads the databases that could not be loaded earlier in the session again, even if their files look intact: *)
reinstallFailedVectorDBs // beginDefinition;

reinstallFailedVectorDBs[ ] :=
    reinstallFailedVectorDBs @ $vectorDBLoadFailures;

reinstallFailedVectorDBs[ { } ] :=
    Null;

reinstallFailedVectorDBs[ names: { __String } ] := Enclose[
    Module[ { dir },
        dir = Block[ { $promptRedownload = False, $forcedVectorDBDownloads = names },
            downloadVectorDatabases[ $localVectorDBDirectory, KeyTake[ $vectorDBDownloadURLs, names ] ]
        ];
        If[ MatchQ[ dir, $$downloadDeclined ], throwFailure[ "VectorDatabaseDownloadDeclined" ] ];
        ConfirmBy[ dir, DirectoryQ, "Directory" ];
        clearVectorDBCaches /@ names;
        $vectorDBLoadFailures = Complement[ $vectorDBLoadFailures, names ];
        dir
    ],
    throwInternalFailure
];

reinstallFailedVectorDBs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Vector Database Utilities*)
$vectorDBDirectory := vectorDBDirectory[ ];

$noSemanticSearch := $noSemanticSearch = ! PacletObjectQ @ Quiet @ PacletInstall[ "SemanticSearch" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getVectorDBDirectory*)
getVectorDBDirectory // beginDefinition;

getVectorDBDirectory[ ] := Enclose[
    Catch @ Module[ { sources, dir },
        sources = {
            $pacletVectorDBDirectory,
            If[ $CloudEvaluation, $cloudVectorDBDirectory, Nothing ],
            $localVectorDBDirectory
        };

        dir = SelectFirst[
            sources,
            vectorDBDirectoryQ,
            ConfirmMatch[ downloadVectorDatabases[ ], $$downloadSkipped | _? vectorDBDirectoryQ, "Downloaded" ]
        ];

        If[ MatchQ[ dir, $$downloadSkipped ], Throw @ dir ];

        If[ $CloudEvaluation && dir === $cloudVectorDBDirectory,
            (* Automatically delete downloaded vector databases when NotebookAssistantCloudResources is available: *)
            releaseUSearchIndexes[ ];
            Quiet @ DeleteDirectory[
                ChatbookFilesDirectory[ "VectorDatabases", "EnsureDirectory" -> False ],
                DeleteContents -> True
            ]
        ];

        $vectorDBDirectory = dir
    ],
    throwInternalFailure
];

getVectorDBDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBDirectory*)
(* The directory that databases are loaded from for searches ($vectorDBDirectory). After a download was declined or
   failed, the databases that are installed in the local directory can still be used (getVectorDB skips the others), and
   InstallVectorDatabases[] resolves the directory again: *)
vectorDBDirectory // beginDefinition;

vectorDBDirectory[ ] := vectorDBDirectory @ getVectorDBDirectory[ ];

(* The chat was stopped while waiting for a download, so the directory is resolved again in the next chat: *)
vectorDBDirectory[ stopped: $$downloadStopped ] := stopped;

vectorDBDirectory[ skipped: $$downloadSkipped ] :=
    With[ { dir = $localVectorDBDirectory }, If[ DirectoryQ @ dir, $vectorDBDirectory = dir, skipped ] ];

vectorDBDirectory[ dir_String ] := dir;

vectorDBDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*vectorDBDirectoryQ*)
vectorDBDirectoryQ // beginDefinition;
vectorDBDirectoryQ[ dir_? DirectoryQ ] := AllTrue[ $vectorDBNames, vectorDBDirectoryQ0 @ FileNameJoin @ { dir, # } & ];
vectorDBDirectoryQ[ _ ] := False;
vectorDBDirectoryQ // endDefinition;

vectorDBDirectoryQ0 // beginDefinition;

vectorDBDirectoryQ0[ dir_? DirectoryQ ] := Enclose[
    Module[ { name, versionFile, expectedVersion, devQ, cloudQ },

        name            = ConfirmBy[ FileBaseName @ dir, StringQ, "Name" ];
        versionFile     = FileNameJoin @ { dir, "Version.wl" };
        expectedVersion = ConfirmBy[ $vectorDatabases[ name, "Version" ], StringQ, "ExpectedVersion" ];
        devQ            = pacletVectorDBDirectoryQ @ dir;
        cloudQ          = TrueQ[ $CloudEvaluation && pathWithinQ[ dir, Quiet @ $cloudVectorDBDirectory ] ];

        (* Bypass version check for development builds: *)
        If[ ! FileExistsQ @ versionFile && devQ, Put[ expectedVersion, versionFile ] ];

        TrueQ @ And[
            installedVectorDBVersion @ dir === expectedVersion,
            vectorDBFilesPresentQ[ dir, name ],
            vectorDBManifestValidQ @ dir,
            devQ || cloudQ || (vectorDBIndexSizeValidQ[ dir, name, expectedVersion ] && vectorDBIndexIntactQ[ dir, name, expectedVersion ])
        ]
    ],
    throwInternalFailure
];

vectorDBDirectoryQ0[ _ ] := False;

vectorDBDirectoryQ0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pacletVectorDBDirectoryQ*)
pacletVectorDBDirectoryQ // beginDefinition;

pacletVectorDBDirectoryQ[ dir_String ] := pathWithinQ[ dir, $pacletVectorDBDirectory ];

pacletVectorDBDirectoryQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pathWithinQ*)
(* Compares whole path components, so that e.g. "VectorDatabases-old" is not considered inside "VectorDatabases": *)
pathWithinQ // beginDefinition;

pathWithinQ[ path_String, root_String ] :=
    With[ { p = FileNameSplit @ ExpandFileName @ path, r = FileNameSplit @ ExpandFileName @ root },
        Length @ p >= Length @ r && Take[ p, Length @ r ] === r
    ];

pathWithinQ[ _, _ ] := False;

pathWithinQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installedVectorDBVersion*)
installedVectorDBVersion // beginDefinition;

installedVectorDBVersion[ dir_String ] :=
    With[ { file = FileNameJoin @ { dir, "Version.wl" } },
        If[ FileExistsQ @ file,
            Replace[ Quiet @ Get @ file, Except[ _String ] -> None ],
            Missing[ "NotInstalled" ]
        ]
    ];

installedVectorDBVersion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBFilesPresentQ*)
vectorDBFilesPresentQ // beginDefinition;

vectorDBFilesPresentQ[ dir_String, name_String ] := AllTrue[
    { name <> ".wxf", "Values.wxf", name <> "-vectors.usearch" },
    With[ { file = FileNameJoin @ { dir, # } }, FileExistsQ @ file && FileByteCount @ file > 0 ] &
];

vectorDBFilesPresentQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBIndexSizeValidQ*)
vectorDBIndexSizeValidQ // beginDefinition;

(* Without metadata for the version (see downloadedArchiveStatus), the index only needs to be non-empty (once it is
   installed, its size is also checked against the manifest): *)
vectorDBIndexSizeValidQ[ dir_String, name_String, version_String ] :=
    With[
        {
            expected = Lookup[ $vectorDBIndexSizes, Key @ { name, version } ],
            size     = FileByteCount @ FileNameJoin @ { dir, name <> "-vectors.usearch" }
        },
        If[ IntegerQ @ expected, size === expected, IntegerQ @ size && size > 0 ]
    ];

vectorDBIndexSizeValidQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBManifestValidQ*)
vectorDBManifestValidQ // beginDefinition;

vectorDBManifestValidQ[ dir_String ] :=
    With[ { file = FileNameJoin @ { dir, "Manifest.wxf" } },
        If[ FileExistsQ @ file,
            vectorDBManifestValidQ[ dir, Quiet @ Developer`ReadWXFFile @ file ],
            True
        ]
    ];

(* Files added by the operating system (e.g. .DS_Store) are not checked, since they can change at any time: *)
vectorDBManifestValidQ[ dir_String, KeyValuePattern[ "Files" -> files_Association ] ] :=
    AllTrue[
        Normal @ files,
        And[
            MatchQ[ #, _String -> _Integer ],
            ! manifestFileQ @ First @ # || Quiet @ FileByteCount @ FileNameJoin @ { dir, First @ # } === Last @ #
        ] &
    ];

vectorDBManifestValidQ[ dir_String, _ ] := False;

vectorDBManifestValidQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBIndexIntactQ*)
(* Detects same-size changes to the index file by comparing its size and modification time to the fingerprint recorded
   in the manifest. Hashing large indices takes seconds, so it is never done while the index is unchanged (e.g. during
   the first chat evaluation). The size of the index has already been checked, so if the fingerprint does not match, its
   modification time changed (e.g. the index was touched, copied, or restored from a backup). It is then hashed once to
   check whether it is still intact, and its new fingerprint is recorded if it is.
   Installs from older versions have no fingerprint (or one that records the modification date as a date list). They are
   adopted unless the index was modified after the install was completed, in which case it is hashed too. *)
vectorDBIndexIntactQ // beginDefinition;

vectorDBIndexIntactQ[ dir_String, name_String, version_String ] :=
    Module[ { file, manifestFile, manifest, fingerprint, recorded },
        file         = FileNameJoin @ { dir, name <> "-vectors.usearch" };
        manifestFile = FileNameJoin @ { dir, "Manifest.wxf" };
        manifest     = Replace[ If[ FileExistsQ @ manifestFile, Quiet @ Developer`ReadWXFFile @ manifestFile ], Except[ _Association ] -> <| |> ];
        fingerprint  = fileFingerprint @ file;
        recorded     = Lookup[ manifest, "IndexFingerprint" ];
        Which[
            TrueQ @ $verifyIndexHashes,
                verifiedIndexHashQ[ file, fingerprint, name, version ] && recordIndexFingerprint[ dir, manifest, fingerprint ],
            fingerprint === recorded,
                True,
            ! MatchQ[ recorded, $$indexFingerprint ] && ! modifiedAfterQ[ file, FileNameJoin @ { dir, "Version.wl" } ],
                recordIndexFingerprint[ dir, manifest, fingerprint ],
            verifiedIndexHashQ[ file, fingerprint, name, version ],
                recordIndexFingerprint[ dir, manifest, fingerprint ],
            True,
                False
        ]
    ];

vectorDBIndexIntactQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modifiedAfterQ*)
(* True if file1 was last modified more than a few seconds after file2 (file dates may only have one-second precision,
   and files extracted or copied together may have nearly identical dates): *)
modifiedAfterQ // beginDefinition;

modifiedAfterQ[ file1_String, file2_String ] := Quiet @ With[
    { d1 = FileDate[ file1, "Modification" ], d2 = FileDate[ file2, "Modification" ] },
    TrueQ[ DateObjectQ @ d1 && DateObjectQ @ d2 && AbsoluteTime @ d1 > AbsoluteTime @ d2 + $modificationDateTolerance ]
];

modifiedAfterQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fileFingerprint*)
(* Size and modification time. The modification time is recorded as a Unix time, so that it doesn't change with the time
   zone or daylight saving time. (In time zones whose UTC offset is not a whole number of hours, FileDate reports times
   with the offset rounded to whole hours, so after changing to or from such a time zone, the index is hashed once.) *)
fileFingerprint // beginDefinition;

fileFingerprint[ file_String ] := Quiet @ With[ { date = FileDate[ file, "Modification" ] },
    If[ FileExistsQ @ file && DateObjectQ @ date, { FileByteCount @ file, UnixTime @ date }, None ]
];

fileFingerprint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*indexHashValidQ*)
indexHashValidQ // beginDefinition;

(* An index can't be verified without metadata for its version (see downloadedArchiveStatus), so it is accepted: *)
indexHashValidQ[ file_String, name_String, version_String ] :=
    With[ { expected = Lookup[ $vectorDBIndexHashes, Key @ { name, version } ] },
        ! StringQ @ expected || Quiet @ FileHash[ file, "SHA256", All, "HexString" ] === expected
    ];

indexHashValidQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*verifiedIndexHashQ*)
(* Avoids hashing the same unchanged file more than once per session (e.g. a damaged index that is checked again in
   later chats): *)
verifiedIndexHashQ // beginDefinition;

verifiedIndexHashQ[ file_String, fingerprint_, name_String, version_String ] :=
    TrueQ @ Lookup[
        $verifiedIndexFingerprints,
        Key @ { file, fingerprint },
        If[ Length @ $verifiedIndexFingerprints >= $maxVerifiedIndexFingerprints, $verifiedIndexFingerprints = <| |> ];
        $verifiedIndexFingerprints[ { file, fingerprint } ] = indexHashValidQ[ file, name, version ]
    ];

verifiedIndexHashQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*recordIndexFingerprint*)
(* Best effort: if the manifest cannot be updated, the index will simply be verified again next time. *)
recordIndexFingerprint // beginDefinition;

recordIndexFingerprint[ dir_String, manifest_Association, fingerprint: $$indexFingerprint ] := (
    If[ manifest[ "IndexFingerprint" ] =!= fingerprint,
        Quiet @ writeManifestFile[
            FileNameJoin @ { dir, "Manifest.wxf" },
            <|
                "Version" -> installedVectorDBVersion @ dir,
                "Files"   -> manifestFileSizes @ dir,
                manifest,
                "IndexFingerprint" -> fingerprint
            |>
        ]
    ];
    True
);

recordIndexFingerprint[ _, _, _ ] := False;

recordIndexFingerprint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*manifestFileSizes*)
manifestFileSizes // beginDefinition;

manifestFileSizes[ dir_String ] := Association[
    FileNameTake[ #, -1 ] -> FileByteCount[ # ] & /@ Select[
        FileNames[ "*", dir ],
        ! DirectoryQ[ # ] && manifestFileQ @ FileNameTake[ #, -1 ] &
    ]
];

manifestFileSizes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*manifestFileQ*)
(* Whether a file in a vector database directory is listed in its manifest. The manifest itself, the install marker,
   temporary files, and files added by the operating system (e.g. .DS_Store or Thumbs.db) are not: *)
manifestFileQ // beginDefinition;

manifestFileQ[ name_String ] := ! Or[
    MemberQ[ { "Manifest.wxf", "Version.wl" }, name ],
    StringEndsQ[ name, ".tmp" ],
    StringStartsQ[ name, "." ],
    MemberQ[ { "thumbs.db", "desktop.ini" }, ToLowerCase @ name ]
];

manifestFileQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeManifestFile*)
(* Written to a temporary file first and then moved into place, so readers never see a partially written manifest: *)
writeManifestFile // beginDefinition;

writeManifestFile[ file_String, manifest_Association ] :=
    With[ { tmp = file <> "." <> createUUID[ ] <> ".tmp" },
        WithCleanup[
            If[ FileExistsQ @ Developer`WriteWXFFile[ tmp, manifest ],
                RenameFile[ tmp, file, OverwriteTarget -> True ],
                $Failed
            ],
            Quiet @ If[ FileExistsQ @ tmp, DeleteFile @ tmp ]
        ]
    ];

writeManifestFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeVectorDBManifest*)
(* Returns a Failure if the manifest can't be written, which fails the install (see unpackVectorDatabase0): *)
writeVectorDBManifest // beginDefinition;

writeVectorDBManifest[ dir_String, version_String ] := Enclose[
    Module[ { name, manifest, file },
        name = ConfirmBy[ FileBaseName @ StringDelete[ dir, ".staging" ~~ EndOfString ], StringQ, "Name" ];
        manifest = <|
            "Version"          -> version,
            "Files"            -> ConfirmBy[ manifestFileSizes @ dir, AssociationQ, "Files" ],
            "IndexFingerprint" -> ConfirmMatch[ fileFingerprint @ FileNameJoin @ { dir, name <> "-vectors.usearch" }, $$indexFingerprint, "Fingerprint" ]
        |>;
        file = FileNameJoin @ { dir, "Manifest.wxf" };
        ConfirmBy[ writeManifestFile[ file, manifest ], FileExistsQ, "Write" ]
    ],
    Function[ failure, Failure[ "VectorDatabaseManifestFailed", <| "Directory" -> dir, "Reason" -> failure |> ] ]
];

writeVectorDBManifest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateVectorDBFiles*)
(* Validates extracted vector database files without loading the index (truncated index files can crash the kernel): *)
validateVectorDBFiles // beginDefinition;

validateVectorDBFiles[ dir_String, name_String, version_String ] := Enclose[
    Module[ { info, values, length, dim },
        ConfirmAssert[ vectorDBFilesPresentQ[ dir, name ], "FilesPresent" ];
        ConfirmAssert[ vectorDBIndexSizeValidQ[ dir, name, version ], "IndexSize" ];
        info = ConfirmBy[ Quiet @ Developer`ReadWXFFile @ FileNameJoin @ { dir, name <> ".wxf" }, AssociationQ, "Info" ];
        { length, dim } = ConfirmMatch[ info[ "Dimensions" ], { _Integer, _Integer }, "Dimensions" ];
        ConfirmAssert[ dim === $embeddingDimension, "EmbeddingDimension" ];
        values = ConfirmMatch[
            catchQuiet @ toVectorDatabaseValues @ Developer`ReadWXFFile @ FileNameJoin @ { dir, "Values.wxf" },
            { ___String },
            "Values"
        ];
        ConfirmAssert[ Length @ values === length, "LengthCheck" ];
        True
    ],
    False &
];

validateVectorDBFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBDamagedQ*)
(* An existing install for the current version that fails validation (as opposed to a fresh install or an update): *)
vectorDBDamagedQ // beginDefinition;

vectorDBDamagedQ[ root_String, name_String ] :=
    With[ { dir = FileNameJoin @ { root, name } },
        TrueQ @ And[
            DirectoryQ @ dir,
            ! vectorDBDirectoryQ0 @ dir,
            MatchQ[ installedVectorDBVersion @ dir, _Missing | None | $vectorDatabases[ name, "Version" ] ]
        ]
    ];

vectorDBDamagedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*partialVectorDBDownloads*)
(* Leftovers of interrupted downloads and installs: partially downloaded archives, staging directories, and backups of
   replaced installs: *)
partialVectorDBDownloads // beginDefinition;

partialVectorDBDownloads[ root_String ] :=
    FileNames[ { "*.tmp", "*.staging", "*.old-*" }, root ];

partialVectorDBDownloads // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cleanupPartialDownloads*)
(* Only evaluated while holding the download lock, so the leftovers are not in use by another kernel. Backups are
   restored first (see restoreVectorDBBackup). *)
cleanupPartialDownloads // beginDefinition;

cleanupPartialDownloads[ root_String ] := Quiet[
    If[ DirectoryQ @ #, DeleteDirectory[ #, DeleteContents -> True ], DeleteFile @ # ] & /@ partialVectorDBDownloads @ root
];

cleanupPartialDownloads // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreVectorDBBackup*)
restoreVectorDBBackup // beginDefinition;

restoreVectorDBBackup[ root_String, name_String ] :=
    With[ { target = FileNameJoin @ { root, name } },
        If[ ! DirectoryQ @ target,
            With[ { backups = FileNames[ name <> ".old-*", root ] },
                If[ backups =!= { }, Quiet @ Check[ RenameDirectory[ Last @ Sort @ backups, target ], $Failed ] ]
            ]
        ]
    ];

restoreVectorDBBackup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*downloadVectorDatabases*)
downloadVectorDatabases // beginDefinition;

(* All of these need a condition, since a definition without patterns or conditions is always tried first: *)
downloadVectorDatabases[ ] /; ! $allowDownload :=
    Throw[ Missing[ "DownloadDisabled" ], $vdbTag ];

(* Downloads are not offered again after they were declined (InstallVectorDatabases[] clears the flag): *)
downloadVectorDatabases[ ] /; TrueQ @ $vectorDBDownloadDeclined :=
    Missing[ "DownloadDeclined" ];

(* A download that failed is not tried again in later chats (InstallVectorDatabases[] clears the flag): *)
downloadVectorDatabases[ ] /; FailureQ @ $vectorDBDownloadFailure :=
    Missing[ "DownloadFailed", $vectorDBDownloadFailure ];

(* A failed download doesn't abort the chat: its message is shown, and the databases that are not installed are
   skipped (see $$skippedVectorDB): *)
downloadVectorDatabases[ ] /; $allowDownload :=
    rememberVectorDBDownloadFailure @ catchDownloadFailure @ downloadVectorDatabases[
        $localVectorDBDirectory,
        $vectorDBDownloadURLs
    ];

(* Prompts are shown before the download lock is taken, so other kernels never have to wait for a dialog. The lock is
   taken for each download attempt instead (see downloadVectorDatabaseFiles), which checks again what still needs to be
   installed. *)
downloadVectorDatabases[ dir0_, urls0_Association ] := Enclose[
    Catch @ Module[ { dir, names, urls },

        If[ $CloudEvaluation && ! TrueQ @ $suppressDownloadWarning, messagePrint[ "VectorDatabaseCloudDownload" ] ];

        dir   = ConfirmBy[ ensureDownloadDirectory @ dir0, DirectoryQ, "Directory" ];
        names = ConfirmMatch[ vectorDBsToInstall[ dir, Keys @ urls0 ], { ___String }, "Names" ];
        If[ names === { }, Throw @ dir ];

        If[ ! confirmVectorDBRepair[ dir, names ], Throw @ declineVectorDBDownload[ ] ];

        urls = ConfirmBy[ KeyTake[ urls0, names ], AssociationQ, "URLs" ];
        ConfirmMatch[ downloadAndUnpackVectorDatabases[ dir, urls ], $$downloadDeclined | _? DirectoryQ, "Downloaded" ]
    ] // LogChatTiming[ "DownloadVectorDatabases" ],
    throwInternalFailure
];

downloadVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rememberVectorDBDownloadFailure*)
rememberVectorDBDownloadFailure // beginDefinition;

rememberVectorDBDownloadFailure[ failed: Missing[ "DownloadFailed", failure_ ] ] := (
    $vectorDBDownloadFailure = failure;
    failed
);

rememberVectorDBDownloadFailure[ result_ ] := result;

rememberVectorDBDownloadFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBsToInstall*)
(* Databases that are not installed or are not valid, and any that should be downloaded again even if their files look
   intact (see repairVectorDB): *)
vectorDBsToInstall // beginDefinition;

vectorDBsToInstall[ dir_String, names: { ___String } ] :=
    Select[ names, MemberQ[ $forcedVectorDBDownloads, # ] || ! vectorDBDirectoryQ0 @ FileNameJoin @ { dir, # } & ];

vectorDBsToInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*confirmVectorDBRepair*)
(* Asks before downloading databases again that are installed but damaged. Databases that are not installed yet, or
   that are installed for a different version, are downloaded without asking. *)
confirmVectorDBRepair // beginDefinition;

confirmVectorDBRepair[ dir_String, names: { ___String } ] :=
    With[ { damaged = If[ TrueQ @ $promptRedownload, Select[ names, vectorDBDamagedQ[ dir, # ] & ], { } ] },
        damaged === { } || confirmRedownload @ damaged
    ];

confirmVectorDBRepair // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*declineVectorDBDownload*)
(* The prompt already stopped the current chat (see confirmDownloadPrompt), so the declined databases are skipped
   instead of throwing a failure that would abort it: *)
declineVectorDBDownload // beginDefinition;
declineVectorDBDownload[ ] := ($vectorDBDownloadDeclined = True; Missing[ "DownloadDeclined" ]);
declineVectorDBDownload // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadAndUnpackVectorDatabases*)
downloadAndUnpackVectorDatabases // beginDefinition;

downloadAndUnpackVectorDatabases[ dir_String, urls_Association ] := Enclose[
    Module[ { names, total, results, failed },

        names = Keys @ urls;
        total = Total @ Cases[ Lookup[ $vectorDBDownloadSizes, names, 0 ], _Integer? Positive ];

        $downloadProgress = AssociationMap[ 0 &, names ];
        $progressText = downloadText[ "ProgressTextDownloadingSearchIndices" ];

        results = evaluateWithProgress[
            downloadVectorDatabaseFiles[ dir, urls ],
            <|
                "Text"             :> $progressText,
                "ElapsedTime"      -> Automatic,
                "RemainingTime"    -> Automatic,
                "ByteCountCurrent" :> Total @ $downloadProgress,
                "ByteCountTotal"   -> Max[ total, 1 ],
                "Progress"         -> Automatic
            |>
        ];

        ConfirmBy[ results, AssociationQ, "Results" ];
        failed = Keys @ Select[ results, ! StringQ @ # & ];

        Which[
            failed === { }, dir,
            MemberQ[ results, Missing[ "Cancelled" ] ], declineVectorDBDownload[ ],
            True, throwFailure[ "VectorDatabaseDownloadFailed", StringRiffle[ failed, ", " ] ]
        ]
    ],
    throwInternalFailure
];

downloadAndUnpackVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabaseFiles*)
(* Downloads (in parallel) and unpacks each vector database, retrying failures up to $maxDownloadAttempts times.
   Returns an association of name -> installed directory, or a Failure/Missing for those that could not be installed.
   The download lock is taken for each attempt, so that it is not held while the retry prompt is shown. *)
downloadVectorDatabaseFiles // beginDefinition;

downloadVectorDatabaseFiles[ dir_String, urls_Association ] := Enclose[
    Module[ { lock, pending, results, attempt, rate, round, newRate, sizes },

        lock    = FileNameJoin @ { dir, "download.lock" };
        pending = Keys @ urls;
        results = <| |>;
        attempt = 1;
        rate    = None;

        While[ pending =!= { } && attempt <= $maxDownloadAttempts,

            If[ attempt > 1,
                (* Archives that were kept (see finishVectorDatabaseDownload) are not downloaded again: *)
                sizes = Total @ Cases[
                    Lookup[ $vectorDBDownloadSizes, Select[ pending, ! archiveKeptQ @ results[ # ] & ], 0 ],
                    _Integer? Positive
                ];
                If[ ! confirmDownloadRetry[ StringRiffle[ pending, ", " ], sizes, rate ],
                    Scan[ (results[ # ] = Missing[ "Cancelled" ]) &, pending ];
                    Break[ ]
                ];
                Pause[ attempt - 1 ];
                $progressText = downloadText[ "ProgressTextDownloadingSearchIndices" ]
            ];

            { round, newRate } = ConfirmMatch[
                withDownloadLock[ lock, downloadVectorDatabaseAttempt[ dir, KeyTake[ urls, pending ] ] ],
                { _Association, _ },
                "Attempt"
            ];

            (* An attempt in which nothing was downloaded successfully doesn't tell how long downloading takes: *)
            If[ newRate =!= None, rate = newRate ];

            results = Join[ results, round ];
            pending = Select[ pending, ! StringQ @ results[ # ] & ];
            attempt++
        ];

        results
    ],
    throwInternalFailure
];

downloadVectorDatabaseFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabaseAttempt*)
(* Evaluated while holding the download lock. Returns { results, rate }, where results is an association of name ->
   installed directory, or a Failure for those that could not be installed, and rate is the observed download rate (or
   None, see observedDownloadRate). *)
downloadVectorDatabaseAttempt // beginDefinition;

downloadVectorDatabaseAttempt[ dir_String, urls_Association ] := Enclose[
    Catch @ Module[ { names, installed, kept, results, rate },

        prepareVectorDBDirectory[ dir, Keys @ urls ];

        (* Another kernel may have installed some of them while we were waiting for the lock: *)
        names     = ConfirmMatch[ vectorDBsToInstall[ dir, Keys @ urls ], { ___String }, "Names" ];
        installed = AssociationMap[ FileNameJoin @ { dir, # } &, Complement[ Keys @ urls, names ] ];

        (* Verified archives that could not be unpacked are kept, and unpacking them was just tried again (see
           tryUnpackingVectorDatabase), so they are not downloaded again: *)
        kept  = AssociationMap[ keptArchiveFailure[ dir, # ] &, Select[ names, FileExistsQ @ vectorDBArchiveFile[ dir, # ] & ] ];
        names = Select[ names, ! KeyExistsQ[ kept, # ] & ];
        If[ names === { }, Throw @ { Join[ installed, kept ], None } ];

        { results, rate } = ConfirmMatch[
            downloadVectorDatabaseSources[ dir, KeyTake[ urls, names ] ],
            { _Association, _ },
            "Download"
        ];

        { Join[ installed, kept, results ], rate }
    ],
    throwInternalFailure
];

downloadVectorDatabaseAttempt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareVectorDBDirectory*)
(* Evaluated while holding the download lock, so any leftovers of earlier downloads are no longer in use: *)
prepareVectorDBDirectory // beginDefinition;

prepareVectorDBDirectory[ dir_String, names: { ___String } ] := (
    (* Backups of every database are restored first, since cleaning up removes all of them: *)
    Scan[ restoreVectorDBBackup[ dir, # ] &, Union[ names, $vectorDBNames ] ];
    cleanupPartialDownloads @ dir;
    (* Try unpacking any complete zip files that might be left over from previous install attempts: *)
    catchQuiet @ tryUnpackingVectorDatabases @ dir;
);

prepareVectorDBDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabaseSources*)
(* Downloads each database from the CDN first. Those that could not be downloaded from there are downloaded from the
   cloud right away, without asking, so the retry prompt is only shown after both have failed. Returns { results, rate },
   where rate is the download rate of the successful downloads (see observedDownloadRate). *)
downloadVectorDatabaseSources // beginDefinition;

downloadVectorDatabaseSources[ dir_String, urls_Association ] := Enclose[
    Module[ { pending, results, bytes, time, sourceURLs, statuses, roundBytes, roundTime },

        pending = Keys @ urls;
        results = <| |>;
        bytes   = 0;
        time    = 0;

        Do[
            sourceURLs = Select[ AssociationMap[ urls[ #, source ] &, pending ], StringQ ];
            If[ sourceURLs =!= <| |>,
                If[ source =!= First @ $vectorDBDownloadSources,
                    $progressText = downloadText[ "ProgressTextDownloadingSearchIndices" ]
                ];

                { statuses, roundBytes, roundTime } = ConfirmMatch[
                    downloadVectorDatabaseRound[ dir, sourceURLs ],
                    { _Association, _Integer, _? NumberQ },
                    "Round"
                ];

                If[ roundBytes > 0, bytes += roundBytes; time += roundTime ];

                $progressText = downloadText[ "ProgressTextUnpackingFiles" ];
                results = Join[ results, Association @ KeyValueMap[ #1 -> finishVectorDatabaseDownload[ dir, #1, #2 ] &, statuses ] ];
                pending = Select[ pending, fallbackDownloadQ @ results[ # ] & ]
            ],
            { source, $vectorDBDownloadSources }
        ];

        { results, observedDownloadRate[ bytes, time ] }
    ],
    throwInternalFailure
];

downloadVectorDatabaseSources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fallbackDownloadQ*)
(* Whether a database is downloaded from the next source: it could not be downloaded (or was not tried) from the
   previous one. A verified archive that could not be unpacked is kept instead (see finishVectorDatabaseDownload). *)
fallbackDownloadQ // beginDefinition;
fallbackDownloadQ[ Failure[ "VectorDatabaseDownloadFailed", _ ] | _Missing ] := True;
fallbackDownloadQ[ _ ] := False;
fallbackDownloadQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabaseRound*)
(* Downloads from the given URLs in parallel. Returns { statuses, bytes, time }, where statuses is an association of
   name -> download status, and bytes is the number of bytes that were downloaded successfully in the given time: *)
downloadVectorDatabaseRound // beginDefinition;

downloadVectorDatabaseRound[ dir_String, urls_Association ] := Enclose[
    Module[ { start, tasks, statuses },
        start = AbsoluteTime[ ];
        $downloadStatus = <| |>;
        tasks = ConfirmMatch[
            KeyValueMap[ submitVectorDatabaseDownload[ dir, #1, #2 ] &, urls ],
            { ___TaskObject },
            "Tasks"
        ];
        (* Don't leave partial downloads behind if this is interrupted (e.g. the chat is stopped): *)
        CheckAbort[
            taskWait @ tasks;
            waitForDownloadHandlers @ Keys @ urls,
            deleteDownloadFiles @ Keys @ urls,
            PropagateAborts -> True
        ];
        statuses = AssociationMap[ Lookup[ $downloadStatus, #, <| |> ] &, Keys @ urls ];
        { statuses, successfulDownloadBytes @ statuses, AbsoluteTime[ ] - start }
    ],
    throwInternalFailure
];

downloadVectorDatabaseRound // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*successfulDownloadBytes*)
(* Error responses (e.g. a fast 404) are not counted, since they don't tell how long a download takes: *)
successfulDownloadBytes // beginDefinition;

successfulDownloadBytes[ statuses_Association ] := Total @ Cases[
    Values @ statuses,
    KeyValuePattern @ { "StatusCode" -> 200, "File" -> file_String } :>
        Replace[ Quiet @ FileByteCount @ file, Except[ _Integer ] -> 0 ]
];

successfulDownloadBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deleteDownloadFiles*)
(* Deletes the temporary files of the current download round (the tasks have already been removed by taskWait): *)
deleteDownloadFiles // beginDefinition;

deleteDownloadFiles[ names: { ___String } ] := Quiet[
    DeleteFile /@ Select[ Lookup[ Lookup[ $downloadStatus, names, <| |> ], "File", None ], StringQ[ # ] && FileExistsQ[ # ] & ]
];

deleteDownloadFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitVectorDatabaseDownload*)
submitVectorDatabaseDownload // beginDefinition;

submitVectorDatabaseDownload[ dir_String, name_String, url_String ] :=
    With[ { tmp = FileNameJoin @ { dir, name <> ".zip." <> createUUID[ ] <> ".tmp" } },
        $downloadProgress[ name ] = 0;
        $downloadStatus[ name ] = <| "File" -> tmp, "URL" -> url |>;
        URLDownloadSubmit[
            url,
            tmp,
            HandlerFunctions -> <|
                "TaskProgress" -> setDownloadProgress[ name, tmp ],
                "TaskFinished" -> setDownloadFinished[ name, tmp ]
            |>,
            HandlerFunctionsKeys -> { "ByteCountDownloaded", "ByteCountTotal", "StatusCode" }
        ]
    ];

submitVectorDatabaseDownload // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*waitForDownloadHandlers*)
(* Give asynchronous "TaskFinished" handlers a chance to run before checking results: *)
waitForDownloadHandlers // beginDefinition;

waitForDownloadHandlers[ names: { ___String } ] := TimeConstrained[
    While[
        ! AllTrue[ names, KeyExistsQ[ Lookup[ $downloadStatus, #, <| |> ], "StatusCode" ] & ],
        Internal`YieldAsynchronousTask[ ];
        Pause[ 0.01 ]
    ],
    5
];

waitForDownloadHandlers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*finishVectorDatabaseDownload*)
(* Checks a downloaded archive and installs it. Returns the installed directory, or a failure:
    * VectorDatabaseDownloadFailed if the download is not valid. The archive is deleted, and the database is downloaded
      again from the next source (see downloadVectorDatabaseSources).
    * VectorDatabaseUnpackFailed if a verified archive could not be installed (e.g. there is not enough disk space). The
      archive is kept, so that only installing it is tried again (see tryUnpackingVectorDatabase). *)
finishVectorDatabaseDownload // beginDefinition;

finishVectorDatabaseDownload[ dir_String, name_String, status_Association ] :=
    With[ { tmp = status[ "File" ], zip = vectorDBArchiveFile[ dir, name ] },
        Replace[
            finishVectorDatabaseDownload0[ dir, name, status, zip ],
            failure_Failure :> (
                Quiet[ DeleteFile /@ Select[ If[ archiveKeptQ @ failure, { tmp }, { tmp, zip } ], StringQ[ # ] && FileExistsQ[ # ] & ] ];
                failure
            )
        ]
    ];

finishVectorDatabaseDownload // endDefinition;


finishVectorDatabaseDownload0 // beginDefinition;

finishVectorDatabaseDownload0[ dir_, name_, status_, zip_ ] := Enclose[
    Module[ { tmp, size, verification, unpacked },
        tmp = ConfirmBy[ status[ "File" ], StringQ, "File" ];
        ConfirmAssert[ status[ "StatusCode" ] === 200, "StatusCode" ];
        ConfirmAssert[ FileExistsQ @ tmp, "Exists" ];
        size = FileByteCount @ tmp;
        ConfirmAssert[ validDownloadSizeQ[ size, $vectorDBDownloadSizes @ name, status[ "ByteCountTotal" ] ], "Size" ];
        verification = ConfirmMatch[ vectorDBArchiveStatus[ name, tmp ], "Verified"|"Unverified", "Hash" ];
        ConfirmBy[ RenameFile[ tmp, zip, OverwriteTarget -> True ], FileExistsQ, "Rename" ];
        unpacked = unpackVectorDatabase @ zip;
        Which[
            DirectoryQ @ unpacked,
                unpacked,
            verification === "Verified",
                Failure[ "VectorDatabaseUnpackFailed", <| "Name" -> name, "File" -> zip, "Reason" -> unpacked, "ArchiveKept" -> True |> ],
            (* Without metadata, an archive is only valid if it can be unpacked: *)
            True,
                ConfirmBy[ unpacked, DirectoryQ, "Unpack" ]
        ]
    ],
    Function[ failure, Failure[ "VectorDatabaseDownloadFailed", <| "Name" -> name, "URL" -> status[ "URL" ], "Reason" -> failure |> ] ]
];

finishVectorDatabaseDownload0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBArchiveFile*)
vectorDBArchiveFile // beginDefinition;
vectorDBArchiveFile[ dir_String, name_String ] := FileNameJoin @ { dir, name <> ".zip" };
vectorDBArchiveFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*archiveKeptQ*)
archiveKeptQ // beginDefinition;
archiveKeptQ[ Failure[ _, KeyValuePattern[ "ArchiveKept" -> True ] ] ] := True;
archiveKeptQ[ _ ] := False;
archiveKeptQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*keptArchiveFailure*)
keptArchiveFailure // beginDefinition;

keptArchiveFailure[ dir_String, name_String ] :=
    Failure[ "VectorDatabaseUnpackFailed", <| "Name" -> name, "File" -> vectorDBArchiveFile[ dir, name ], "ArchiveKept" -> True |> ];

keptArchiveFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBArchiveStatus*)
(* See downloadedArchiveStatus: *)
vectorDBArchiveStatus // beginDefinition;

vectorDBArchiveStatus[ name_String, file_String ] := downloadedArchiveStatus[
    Lookup[ $vectorDBDownloadHashes, Key @ { name, $vectorDatabases[ name, "Version" ] } ],
    file
];

vectorDBArchiveStatus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tryUnpackingVectorDatabases*)
tryUnpackingVectorDatabases // beginDefinition;

tryUnpackingVectorDatabases[ dir_? DirectoryQ ] :=
    Map[ tryUnpackingVectorDatabase, FileNames[ "*.zip", dir ] ];

tryUnpackingVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tryUnpackingVectorDatabase*)
(* Unpacks an archive that is left over from an earlier install attempt. Archives that are not valid are deleted. A
   verified archive is kept if it still can't be unpacked, so that it doesn't need to be downloaded again. An archive
   that can't be verified (there is no metadata for its version) is only valid if it can be unpacked. *)
tryUnpackingVectorDatabase // beginDefinition;

tryUnpackingVectorDatabase[ zip_? FileExistsQ ] :=
    Quiet @ With[ { name = FileBaseName @ zip },
        Replace[
            If[ vectorDBNameQ @ name && validDownloadSizeQ[ FileByteCount @ zip, $vectorDBDownloadSizes @ name, None ],
                vectorDBArchiveStatus[ name, zip ],
                "Invalid"
            ],
            {
                "Invalid" :> (DeleteFile @ zip; Missing[ "InvalidArchive", zip ]),
                verification_ :> With[ { res = catchQuiet @ unpackVectorDatabase @ zip },
                    If[ ! DirectoryQ @ res && verification =!= "Verified", DeleteFile @ zip ];
                    res
                ]
            }
        ]
    ];

tryUnpackingVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unpackVectorDatabase*)
(* Extracts into a staging directory, validates, and then swaps the result into place: *)
unpackVectorDatabase // beginDefinition;

unpackVectorDatabase[ zip_String? FileExistsQ ] :=
    With[ { staging = FileNameJoin @ { DirectoryName @ zip, FileBaseName @ zip <> ".staging" } },
        Replace[
            unpackVectorDatabase0[ zip, staging ],
            failure_Failure :> (Quiet @ DeleteDirectory[ staging, DeleteContents -> True ]; failure)
        ]
    ] // LogChatTiming[ "UnpackVectorDatabase" ];

unpackVectorDatabase // endDefinition;


unpackVectorDatabase0 // beginDefinition;

unpackVectorDatabase0[ zip_String, staging_String ] := Enclose[
    Module[ { name, version, root, target, old, installed },
        name    = ConfirmBy[ FileBaseName @ zip, StringQ, "Name" ];
        version = ConfirmBy[ $vectorDatabases[ name, "Version" ], StringQ, "Version" ];
        root    = ConfirmBy[ DirectoryName @ zip, DirectoryQ, "RootDirectory" ];
        target  = FileNameJoin @ { root, name };

        Quiet @ DeleteDirectory[ staging, DeleteContents -> True ];
        ConfirmBy[ CreateDirectory @ staging, DirectoryQ, "Staging" ];
        ConfirmMatch[ Quiet @ ExtractArchive[ zip, staging, OverwriteTarget -> True ], { __? FileExistsQ }, "Extracted" ];
        ConfirmAssert[ validateVectorDBFiles[ staging, name, version ], "Validate" ];
        ConfirmBy[ writeVectorDBManifest[ staging, version ], FileExistsQ, "Manifest" ];

        (* Version.wl marks the install as complete, so it's written last: *)
        Put[ version, FileNameJoin @ { staging, "Version.wl" } ];
        ConfirmAssert[ Get @ FileNameJoin @ { staging, "Version.wl" } === version, "VersionCheck" ];

        If[ DirectoryQ @ target,
            (* Memory-mapped index files cannot be moved or replaced on Windows: *)
            releaseUSearchIndexes[ ];
            old = target <> ".old-" <> createUUID[ ];
            ConfirmBy[ RenameDirectory[ target, old ], DirectoryQ, "MoveOld" ]
        ];

        installed = Quiet @ Check[ RenameDirectory[ staging, target ], $Failed ];
        If[ ! DirectoryQ @ installed,
            If[ StringQ @ old && DirectoryQ @ old && ! DirectoryQ @ target,
                Quiet @ Check[ RenameDirectory[ old, target ], $Failed ]
            ];
            ConfirmBy[ installed, DirectoryQ, "Install" ]
        ];

        If[ StringQ @ old && DirectoryQ @ old, Quiet @ DeleteDirectory[ old, DeleteContents -> True ] ];
        Quiet @ DeleteFile @ zip;
        target
    ],
    Function[ failure, Failure[ "VectorDatabaseUnpackFailed", <| "File" -> zip, "Reason" -> failure |> ] ]
];

unpackVectorDatabase0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*taskWait*)
taskWait // beginDefinition;
taskWait[ tasks_List ] := CheckAbort[ taskWait /@ tasks, Quiet[ TaskRemove /@ tasks ], PropagateAborts -> True ];
taskWait[ task_TaskObject ] := taskWait[ task, task[ "TaskStatus" ] ];
taskWait[ task_TaskObject, "Removed" ] := task;
taskWait[ task_TaskObject, _ ] := taskWaitYield @ task;
taskWait // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setDownloadProgress*)
setDownloadProgress // beginDefinition;

setDownloadProgress[ name_String, file_String ] := setDownloadProgress[ name, file, ## ] &;

(* Handlers of a download that was replaced (e.g. by the download from the next source) are ignored: *)
setDownloadProgress[ name_, file_, as_Association ] /; currentDownloadQ[ name, file ] := (
    If[ TrueQ @ Positive @ as[ "ByteCountDownloaded" ], $downloadProgress[ name ] = as[ "ByteCountDownloaded" ] ];
    If[ IntegerQ @ as[ "ByteCountTotal" ], $downloadStatus[ name, "ByteCountTotal" ] = as[ "ByteCountTotal" ] ];
);

setDownloadProgress[ _, ___ ] := Null;

setDownloadProgress // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setDownloadFinished*)
setDownloadFinished // beginDefinition;

setDownloadFinished[ name_String, file_String ] := setDownloadFinished[ name, file, ## ] &;

setDownloadFinished[ name_, file_, as_Association ] /; currentDownloadQ[ name, file ] :=
    $downloadStatus[ name, "StatusCode" ] = Lookup[ as, "StatusCode", None ];

setDownloadFinished[ _, ___ ] := Null;

setDownloadFinished // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*currentDownloadQ*)
currentDownloadQ // beginDefinition;
currentDownloadQ[ name_String, file_String ] := MatchQ[ $downloadStatus[ name ], KeyValuePattern[ "File" -> file ] ];
currentDownloadQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inVectorDBDirectory*)
inVectorDBDirectory // beginDefinition;
inVectorDBDirectory // Attributes = { HoldFirst };
inVectorDBDirectory[ eval_ ] := WithCleanup[ SetDirectory @ $vectorDBDirectory, eval, ResetDirectory[ ] ];
inVectorDBDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initializeVectorDatabases*)
initializeVectorDatabases // beginDefinition;

initializeVectorDatabases[ ] :=
    initializeVectorDatabases @ $vectorDBNames;

(* Loads the given vector databases and searches each one once, so that the first real search does not have to wait
   for them. This never starts a download: if the databases are not installed yet, the first real search downloads them
   as usual. *)
initializeVectorDatabases[ names: $$dbNames ] := Enclose[
    Block[ { $allowDownload = False },
        Catch[
            Module[ { vector },
                vector = ConfirmMatch[ getEmbedding[ "Hello" ], _NumericArray, "EmbeddingVector" ];
                catchAlways @ initializeVectorDatabase[ #, vector ] & /@ names
            ],
            $vdbTag
        ]
    ],
    throwInternalFailure
];

initializeVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializeVectorDatabase*)
initializeVectorDatabase // beginDefinition;

initializeVectorDatabase[ name_String, vector_NumericArray ] := Enclose[
    Catch @ Module[ { info, vectorDB },
        info = ConfirmMatch[ getVectorDB @ name, $$skippedVectorDB | _Association, "VectorDB" ];
        If[ MatchQ[ info, $$skippedVectorDB ], Throw @ info ];
        vectorDB = ConfirmMatch[ info[ "VectorDatabaseObject" ], $$vectorDatabase, "VectorDatabase" ];
        ConfirmMatch[
            inVectorDBDirectory @ VectorDatabaseSearch[
                vectorDB,
                vector,
                { "Index", "Distance" },
                MaxItems -> $maxNeighbors
            ],
            { ___Association },
            "Search"
        ];
        name
    ] // LogChatTiming[ { "InitializeVectorDatabase", name } ],
    throwInternalFailure
];

initializeVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getVectorDB*)
getVectorDB // beginDefinition;

(* Reuse the loaded database only while its index file is unchanged, since the index is read from disk during search: *)
getVectorDB[ name_String ] :=
    With[ { cached = $loadedVectorDBs[ name ] },
        cached[ "Data" ] /; AssociationQ @ cached && cached[ "Fingerprint" ] === loadedIndexFingerprint @ name
    ];

(* Returns a Missing (see $$skippedVectorDB) for a database that is skipped because its download was declined, or
   because it could not be loaded even after downloading it again. That is not cached, so the database can be used once
   it has been installed. *)
getVectorDB[ name_String ] := Enclose[
    Catch @ Module[ { data },
        If[ KeyExistsQ[ $loadedVectorDBs, name ], clearVectorDBCaches @ name ];
        data = ConfirmMatch[ loadVectorDB @ name, $$skippedVectorDB | $$loadedVectorDB, "Loaded" ];
        If[ MatchQ[ data, $$skippedVectorDB ], Throw @ data ];
        data = ConfirmMatch[ Association @ data, $$loadedVectorDB, "VectorDB" ];
        $loadedVectorDBs[ name ] = <| "Data" -> data, "Fingerprint" -> loadedIndexFingerprint @ name |>;
        data
    ],
    throwInternalFailure
];

getVectorDB // endDefinition;

$$loadedVectorDB = KeyValuePattern @ { "Values" -> { ___String }, "VectorDatabaseObject" -> $$vectorDatabase };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadedIndexFingerprint*)
(* This is checked for every search, and only needs to notice changes during the session, so it uses the modification
   date as reported by FileDate, which is quicker than converting it to a Unix time (see fileFingerprint): *)
loadedIndexFingerprint // beginDefinition;

loadedIndexFingerprint[ name_String ] :=
    With[ { file = FileNameJoin @ { $vectorDBDirectory, name, name <> "-vectors.usearch" } },
        Quiet @ With[ { date = FileDate[ file, "Modification" ] },
            If[ FileExistsQ @ file && DateObjectQ @ date, { FileByteCount @ file, First @ date }, None ]
        ]
    ];

loadedIndexFingerprint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadVectorDB*)
(* Loads a vector database, offering to re-download it if the local copy turns out to be unusable: *)
loadVectorDB // beginDefinition;

loadVectorDB[ name_String ] := Enclose[
    Catch @ Module[ { root, loaded },
        (* Resolve the directory first so that any download prompts/messages are not suppressed: *)
        root = ConfirmMatch[ $vectorDBDirectory, $$downloadSkipped | _? DirectoryQ, "RootDirectory" ];
        If[ MatchQ[ root, $$downloadSkipped ], Throw @ root ];
        (* Not offered for download again after it could not be loaded even after downloading it again: *)
        If[ MemberQ[ $vectorDBLoadFailures, name ], Throw @ Missing[ "LoadFailed", name ] ];
        loaded = catchQuiet @ loadVectorDB0 @ name;
        If[ MatchQ[ loaded, $$loadedVectorDB ], loaded, repairVectorDB @ name ]
    ],
    throwInternalFailure
];

loadVectorDB // endDefinition;


loadVectorDB0 // beginDefinition;

loadVectorDB0[ name_String ] := Enclose[
    Module[ { values, vectorDB, dims },

        (* Guard against files that were damaged after installation (a truncated index can crash the kernel): *)
        ConfirmAssert[ vectorDBDirectoryQ0 @ FileNameJoin @ { $vectorDBDirectory, name }, "Integrity" ];

        values   = ConfirmMatch[ loadVectorDBValues @ name, { ___String }, "Values" ];
        vectorDB = ConfirmMatch[ loadVectorDatabase @ name, $$vectorDatabase, "VectorDatabaseObject" ];
        dims     = ConfirmMatch[ inVectorDBDirectory @ vectorDB[ "Dimensions" ], { _Integer, _Integer }, "Dimensions" ];

        ConfirmAssert[ Length @ values === First @ dims, "LengthCheck" ];

        <| "Values" -> values, "VectorDatabaseObject" -> vectorDB |>
    ],
    throwInternalFailure
];

loadVectorDB0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*repairVectorDB*)
repairVectorDB // beginDefinition;

repairVectorDB[ name_String ] := Enclose[
    Catch @ Module[ { root, urls, dir },

        root = ConfirmBy[ $vectorDBDirectory, DirectoryQ, "RootDirectory" ];
        urls = $vectorDBDownloadURLs;

        (* Only local downloads can be repaired: *)
        If[ ! localVectorDBDirectoryQ @ root || ! KeyExistsQ[ urls, name ],
            throwFailure[ "VectorDatabaseLoadFailed", name ]
        ];

        (* This takes precedence over everything else (e.g. in initializeVectorDatabases), so no prompt is shown: *)
        If[ ! TrueQ @ $allowDownload, Throw[ Missing[ "DownloadDisabled" ], $vdbTag ] ];

        (* Downloads are not offered again after they were declined, so the database is skipped: *)
        If[ TrueQ @ $vectorDBDownloadDeclined, Throw @ Missing[ "DownloadDeclined", name ] ];

        (* Downloads are not tried again after one failed, so the database is skipped: *)
        If[ FailureQ @ $vectorDBDownloadFailure, Throw @ Missing[ "DownloadFailed", $vectorDBDownloadFailure ] ];

        If[ TrueQ @ $promptRedownload && ! confirmRedownload @ { name },
            Throw @ declineVectorDBDownload[ ]
        ];

        clearVectorDBCaches @ name;

        (* Loading failed, so it is downloaded again even if its files look intact. If the download fails, its message is
           shown, and the database is skipped (see catchDownloadFailure): *)
        dir = Block[ { $promptRedownload = False, $forcedVectorDBDownloads = Union[ $forcedVectorDBDownloads, { name } ] },
            ConfirmMatch[
                rememberVectorDBDownloadFailure @ catchDownloadFailure @ downloadVectorDatabases[ root, KeyTake[ urls, { name } ] ],
                $$downloadSkipped | _? DirectoryQ,
                "Download"
            ]
        ];

        (* A retry prompt was declined, or the download failed: *)
        If[ MatchQ[ dir, $$downloadSkipped ], Throw @ dir ];

        Replace[ catchQuiet @ loadVectorDB0 @ name, Except[ $$loadedVectorDB ] :> vectorDBLoadFailed @ name ]
    ],
    throwInternalFailure
];

repairVectorDB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*vectorDBLoadFailed*)
(* A database that could not be loaded even after downloading it again is skipped for the rest of the session, so that
   later chats don't offer to download it again. InstallVectorDatabases[] downloads it again. *)
vectorDBLoadFailed // beginDefinition;

vectorDBLoadFailed[ name_String ] := (
    $vectorDBLoadFailures = Union[ $vectorDBLoadFailures, { name } ];
    messagePrint[ "VectorDatabaseLoadFailed", name ];
    Missing[ "LoadFailed", name ]
);

vectorDBLoadFailed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*localVectorDBDirectoryQ*)
localVectorDBDirectoryQ // beginDefinition;

localVectorDBDirectoryQ[ dir_String ] :=
    With[ { local = $localVectorDBDirectory }, StringQ @ local && ExpandFileName @ dir === ExpandFileName @ local ];

localVectorDBDirectoryQ[ _ ] := False;

localVectorDBDirectoryQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clearVectorDBCaches*)
clearVectorDBCaches // beginDefinition;

clearVectorDBCaches[ name_String ] := (
    Quiet[ loadVectorDBValues[ name ] =. ];
    Quiet[ getVectorDB[ name ] =. ];
    $loadedVectorDBs      = KeyDrop[ $loadedVectorDBs, name ];
    $vectorDBSearchCache  = KeySelect[ $vectorDBSearchCache, ! MatchQ[ #, { name, _ } ] & ];
    $usearchIndexCache    = KeyDrop[ $usearchIndexCache, name ];
    $usearchIndexFailures = KeyDrop[ $usearchIndexFailures, name ];
);

clearVectorDBCaches // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadVectorDatabase*)
loadVectorDatabase // beginDefinition;

loadVectorDatabase[ name_String ] := Enclose[
    inVectorDBDirectory @ Module[ { dir, file },
        dir = ConfirmBy[ name, DirectoryQ, "Directory" ];
        file = ConfirmBy[ File @ FileNameJoin @ { dir, name<>".wxf" }, FileExistsQ, "File" ];
        ConfirmMatch[ VectorDatabaseObject @ file, $$vectorDatabase, "Database" ]
    ],
    throwInternalFailure
];

loadVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadVectorDBValues*)
loadVectorDBValues // beginDefinition;

loadVectorDBValues[ name_String ] := Enclose[
    Module[ { root, dir, file },
        root = ConfirmBy[ $vectorDBDirectory, DirectoryQ, "RootDirectory" ];
        dir = ConfirmBy[ FileNameJoin @ { root, name }, DirectoryQ, "Directory" ];
        file = ConfirmBy[ FileNameJoin @ { dir, "Values.wxf" }, FileExistsQ, "File" ];
        loadVectorDBValues[ name ] = ConfirmMatch[ Developer`ReadWXFFile @ file, { __String }, "Read" ]
    ],
    throwInternalFailure
];

loadVectorDBValues // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*vectorDBSearch*)
vectorDBSearch // beginDefinition;


(* Default arguments: *)
vectorDBSearch[ db: $$dbNameOrNames, prompt_String ] :=
    vectorDBSearch[ db, prompt, All ];

vectorDBSearch[ db: $$dbNameOrNames, All ] :=
    vectorDBSearch[ db, All, "Values" ];


(* Shortcuts: *)
vectorDBSearch[ $$dbNameOrNames, "", All ] := <|
    "EmbeddingVector" -> None,
    "SearchData"      -> Missing[ "NoInput" ],
    "Values"          -> { }
|>;

vectorDBSearch[ $$dbNameOrNames, "", "Results"|"Values" ] :=
    { };

vectorDBSearch[ { }, prompt_, prop_ ] :=
    { };


(* Cached results: *)
vectorDBSearch[ dbName: $$dbName, prompt_String, All ] :=
    With[ { result = $vectorDBSearchCache[ { dbName, prompt } ] },
        result /; AssociationQ @ result
    ];


(* Main definition for string prompt: *)
vectorDBSearch[ dbName: $$dbName, prompt_String, All ] := Enclose[
    Catch @ Module[
        {
            vectorDBInfo, vectorDB, allValues, embeddingVector, close,
            indices, distances, values, data, result, snippetFunction, instructionsFunction, instructionsPosition
        },

        vectorDBInfo    = getVectorDB @ dbName;

        (* A database that is skipped (e.g. because its download was declined) gives no results (which are not cached): *)
        If[ MatchQ[ vectorDBInfo, $$skippedVectorDB ], Throw @ skippedSearchResult @ vectorDBInfo ];

        vectorDBInfo    = ConfirmBy[ vectorDBInfo, AssociationQ, "VectorDBInfo" ];
        vectorDB        = ConfirmMatch[ vectorDBInfo[ "VectorDatabaseObject" ], $$vectorDatabase, "VectorDatabase" ];
        allValues       = ConfirmBy[ vectorDBInfo[ "Values" ], ListQ, "Values" ];
        embeddingVector = ConfirmMatch[ getEmbedding @ prompt, _NumericArray, "EmbeddingVector" ];

        close = ConfirmMatch[
            vectorDatabaseSearch[
                dbName,
                vectorDB,
                embeddingVector,
                $maxNeighbors
            ] // LogChatTiming[ "VectorDatabaseSearch" ],
            { ___Association },
            "PositionsAndDistances"
        ];

        indices   = ConfirmMatch[ close[[ All, "Index"    ]], { ___Integer }, "Indices"   ];
        distances = ConfirmMatch[ close[[ All, "Distance" ]], { ___Real    }, "Distances" ];
        values    = ConfirmBy[ allValues[[ indices ]], ListQ, "Values" ];

        ConfirmAssert[ Length @ indices === Length @ distances === Length @ values, "LengthCheck" ];

        snippetFunction      = Confirm[ getSnippetFunction @ dbName     , "SnippetFunction"      ];
        instructionsFunction = Confirm[ getInstructionsFunction @ dbName, "InstructionsFunction" ];

        instructionsPosition = Confirm[
            Lookup[ $vectorDatabases[ dbName ], "InstructionsPosition", After ],
            "InstructionsPosition"
        ];

        data = MapApply[
            <|
                "Value"                -> #1,
                "Index"                -> #2,
                "Distance"             -> #3,
                "Source"               -> dbName,
                "SnippetFunction"      -> snippetFunction,
                "Instructions"         -> instructionsFunction,
                "InstructionsPosition" -> instructionsPosition
            |> &,
            Transpose @ { values, indices, distances }
        ];

        result = <| "Values" -> DeleteDuplicates @ values, "Results" -> data, "EmbeddingVector" -> embeddingVector |>;

        (* Cache and verify: *)
        cacheVectorDBResult[ dbName, prompt, result ];
        ConfirmAssert[ $vectorDBSearchCache[ { dbName, prompt } ] === result, "CacheCheck" ];

        result
    ],
    throwInternalFailure
];


(* Main definition for a list of messages: *)
vectorDBSearch[ dbName: $$dbName, messages0: { __Association }, prop: "Values"|"Results" ] := Enclose[
    Catch @ Module[
        {
            messages, lastMessage,
            conversationString, lastMessageString, selectionString,
            conversationResults, lastMessageResults, selectionResults,
            combined, n, merged
        },

        (* TODO: asynchronously pre-cache embeddings for each type *)
        (* TODO: preprocess messages individually *)

        messages = DeleteCases[
            ConfirmMatch[ insertContextPrompt @ messages0, { __Association }, "Messages" ],
            KeyValuePattern[ "Content" -> "" | { } ]
        ];

        If[ messages === { }, Throw @ { } ];

        lastMessage = ConfirmMatch[
            FirstCase[ Reverse @ messages, KeyValuePattern[ "Role" -> "User" ] ],
            $$chatMessage,
            "LastMessage"
        ];

        conversationString = ConfirmBy[
            preprocessEmbeddingString @ getSmallContextString[
                messages,
                "SingleMessageTemplate" -> StringTemplate[ "`Content`" ]
            ],
            StringQ,
            "ConversationString"
        ];

        lastMessageString = ConfirmBy[
            preprocessEmbeddingString @ getSmallContextString[
                { lastMessage },
                "IncludeSystemMessage"  -> True,
                "SingleMessageTemplate" -> StringTemplate[ "`Content`" ]
            ],
            StringQ,
            "LastMessageString"
        ];

        selectionString =
            If[ StringQ @ $selectionPrompt,
                Replace[ preprocessEmbeddingString @ $selectionPrompt, "" -> None ],
                None
            ];

        If[ conversationString === "" || lastMessageString === "", Throw @ { } ];

        getEmbeddings @ Select[ { conversationString, lastMessageString, selectionString }, StringQ ];

        conversationResults = ConfirmMatch[
            MapAt[
                # + $conversationVectorSearchPenalty &,
                vectorDBSearch[ dbName, conversationString, "Results" ],
                { All, "Distance" }
            ],
            { KeyValuePattern[ { "Distance" -> _Real, "Value" -> _ } ]... },
            "ConversationResults"
        ];

        lastMessageResults =
            If[ lastMessageString === conversationString,
                { },
                ConfirmMatch[
                    vectorDBSearch[ dbName, lastMessageString, "Results" ],
                    { KeyValuePattern[ { "Distance" -> _Real, "Value" -> _ } ]... },
                    "LastMessageResults"
                ]
            ];

        selectionResults =
            If[ StringQ @ selectionString,
                ConfirmMatch[
                    vectorDBSearch[ dbName, selectionString, "Results" ],
                    { KeyValuePattern[ { "Distance" -> _Real, "Value" -> _ } ]... },
                    "SelectionResults"
                ],
                { }
            ];

        combined = SortBy[ Join[ conversationResults, lastMessageResults, selectionResults ], Lookup[ "Distance" ] ];

        n = Ceiling[ $maxNeighbors / 10 ];
        merged = Take[
            DeleteDuplicates @ Join[
                Take[ conversationResults, UpTo[ n ] ],
                Take[ lastMessageResults , UpTo[ n ] ],
                Take[ selectionResults   , UpTo[ n ] ],
                combined
            ],
            UpTo[ $maxNeighbors ]
        ];

        If[ prop === "Results",
            merged,
            DeleteDuplicates[ Lookup[ "Value" ] /@ merged ]
        ]
    ],
    throwInternalFailure
];


(* Properties: *)
vectorDBSearch[ db_, prompt_String, "EmbeddingVector" ] := Enclose[
    ConfirmMatch[ getEmbedding @ prompt, _NumericArray, "EmbeddingVector" ],
    throwInternalFailure
];

vectorDBSearch[ dbName: $$dbName, prompt_String, key_String ] := Enclose[
    Lookup[ ConfirmBy[ vectorDBSearch[ dbName, prompt, All ], AssociationQ, "Result" ], key ],
    throwInternalFailure
];

vectorDBSearch[ dbName: $$dbName, prompt_String, keys: { ___String } ] := Enclose[
    KeyTake[ ConfirmBy[ vectorDBSearch[ dbName, prompt, All ], AssociationQ, "Result" ], keys ],
    throwInternalFailure
];

vectorDBSearch[ dbName: $$dbName, prompts: { ___String }, prop_ ] :=
    AssociationMap[ vectorDBSearch[ dbName, #, prop ] &, prompts ];


(* Full list of possible values: *)
vectorDBSearch[ dbName: $$dbName, All, "Values" ] := Enclose[
    Catch @ Module[ { vectorDBInfo },
        vectorDBInfo = getVectorDB @ dbName;
        If[ MatchQ[ vectorDBInfo, $$skippedVectorDB ], Throw @ { } ];
        vectorDBInfo = ConfirmBy[ vectorDBInfo, AssociationQ, "VectorDB" ];
        ConfirmBy[ vectorDBInfo[ "Values" ], ListQ, "Values" ]
    ],
    throwInternalFailure
];

vectorDBSearch[ names: $$dbNames, All, "Values" ] :=
    Flatten[ vectorDBSearch[ #, All, "Values" ] & /@ names ];


(* Combine results from multiple vector databases: *)
vectorDBSearch[ names: $$dbNames, prompt_, prop: "Values"|"Results" ] := Enclose[
    Catch @ Module[ { results, sorted },

        results = ConfirmMatch[
            applyBias[ #, vectorDBSearch[ #, prompt, "Results" ] ] & /@ names,
            { { KeyValuePattern[ "Distance" -> _Real|_Integer ]... }... },
            "Results"
        ];

        sorted = SortBy[ Flatten @ results, #Distance & ];

        If[ prop === "Results" || sorted === { },
            sorted,
            ConfirmBy[ DeleteDuplicates @ Lookup[ sorted, "Value" ], ListQ, "Values" ]
        ]
    ],
    throwInternalFailure
];

vectorDBSearch[ names: $$dbNames, prompt_, All ] :=
    Merge[ vectorDBSearch[ #, prompt, All ] & /@ names, Flatten ];

vectorDBSearch[ All, prompt_ ] :=
    vectorDBSearch[ $vectorDBNames, prompt ];

vectorDBSearch[ All, prompt_, prop_ ] :=
    vectorDBSearch[ $vectorDBNames, prompt, prop ];


vectorDBSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skippedSearchResult*)
skippedSearchResult // beginDefinition;

skippedSearchResult[ missing: $$skippedVectorDB ] := <|
    "EmbeddingVector" -> None,
    "SearchData"      -> missing,
    "Values"          -> { },
    "Results"         -> { }
|>;

skippedSearchResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessEmbeddingString*)
preprocessEmbeddingString // beginDefinition;

preprocessEmbeddingString[ s: _String | { ___String } ] := StringReplace[
    StringTrim @ StringDelete[
        s,
        {
            Shortest[ "\\!\\(\\*MarkdownImageBox[\"![" ~~ __ ~~ "](" ~~ __ ~~ ")\"]\\)" ],
            $leftSelectionIndicator,
            $rightSelectionIndicator
        }
    ],
    Shortest[ "<speech-input>"~~___~~"<transcript>"~~transcript__~~"</transcript>"~~___~~"</speech-input>" ] :>
        StringTrim @ transcript
];

preprocessEmbeddingString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSnippetFunction*)
getSnippetFunction // beginDefinition;
getSnippetFunction[ name_String ] := getSnippetFunction[ name, $vectorDatabases[ name, "SnippetFunction" ] ];
getSnippetFunction[ name_String, $$unspecified ] := Identity;
getSnippetFunction[ name_String, function_ ] := function;
getSnippetFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSnippetAssetFunction*)
getSnippetAssetFunction // beginDefinition;

getSnippetAssetFunction[ name_String ] := Enclose[
    Module[ { dir, file, snippets, function },
        dir = ConfirmBy[ $thisPaclet[ "AssetLocation", "Snippets" ], DirectoryQ, "Directory" ];
        file = ConfirmBy[ FileNameJoin @ { dir, name <> ".wxf" }, FileExistsQ, "File" ];
        snippets = ConfirmBy[ Developer`ReadWXFFile @ file, AssociationQ, "Snippets" ];
        function = With[ { s = snippets }, Lookup[ s, # ] & ];
        If[ TrueQ @ $mxFlag, function, getSnippetAssetFunction[ name ] = function ]
    ],
    throwInternalFailure
];

getSnippetAssetFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getNamedSnippet*)
getNamedSnippet // beginDefinition;

getNamedSnippet[ name_String ] := Enclose[
    Module[ { root, dir, file, bytes, snippet },
        root = ConfirmBy[ $thisPaclet[ "AssetLocation", "Snippets" ], DirectoryQ, "Directory" ];
        dir = ConfirmBy[ FileNameJoin @ { root, "Markdown" }, DirectoryQ, "Directory" ];
        file = ConfirmBy[ FileNameJoin @ { dir, name <> ".md" }, FileExistsQ, "File" ];
        bytes = ConfirmBy[ ReadByteArray @ file, ByteArrayQ, "Bytes" ];
        snippet = ConfirmBy[ ByteArrayToString @ bytes, StringQ, "Snippet" ];
        If[ TrueQ @ $mxFlag, snippet, getNamedSnippet[ name ] = snippet ]
    ],
    throwInternalFailure
];

getNamedSnippet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getInstructionsFunction*)
getInstructionsFunction // beginDefinition;
getInstructionsFunction[ name_String ] := getInstructionsFunction[ name, $vectorDatabases[ name, "Instructions" ] ];
getInstructionsFunction[ name_String, $$unspecified ] := None;
getInstructionsFunction[ name_String, function_ ] := function;
getInstructionsFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyBias*)
applyBias // beginDefinition;
applyBias[ name_String, results_ ] := applyBias[ $vectorDatabases[ name, "Bias" ], results ];
applyBias[ None | _Missing | 0 | 0.0, results_ ] := results;
applyBias[ bias_, results_List ] := (applyBias[ bias, #1 ] &) /@ results;
applyBias[ bias_? NumberQ, as: KeyValuePattern[ "Distance" -> d: $$size ] ] := <| as, "Distance" -> d + bias |>;
applyBias // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertContextPrompt*)
insertContextPrompt // beginDefinition;

insertContextPrompt[ messages_ ] :=
    insertContextPrompt[ messages, $contextPrompt, $selectionPrompt ];

insertContextPrompt[ { before___, last_Association }, context_String, selection_String ] := {
    before,
    <| "Role" -> "User"  , "Content" -> context |>,
    <| "Role" -> "System", "Content" -> "User's currently selected text: \""<>selection<>"\"" |>,
    last
};

insertContextPrompt[ { before___, last_Association }, context_String, _ ] := {
    before,
    <| "Role" -> "User", "Content" -> context |>,
    last
};

insertContextPrompt[ messages_List, _, _ ] :=
    messages;

insertContextPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cacheVectorDBResult*)
cacheVectorDBResult // beginDefinition;

(* Each result is large (about 200 KB), so only the most recent searches are kept: *)
cacheVectorDBResult[ dbName: $$dbName, prompt_String, data_Association ] := (
    If[ ! AssociationQ @ $vectorDBSearchCache, $vectorDBSearchCache = <| |> ];
    If[ Length @ $vectorDBSearchCache >= $maxVectorDBSearchCacheSize,
        $vectorDBSearchCache = Take[ $vectorDBSearchCache, -Floor[ $maxVectorDBSearchCacheSize / 2 ] ]
    ];
    $vectorDBSearchCache[ { dbName, prompt } ] = data
);

cacheVectorDBResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*vectorDatabaseSearch*)
(*
    Gives the same result as `VectorDatabaseSearch[ db, vector, { "Index", "Distance" }, MaxItems -> n ]`.

    For file-backed USearch databases, VectorDatabaseSearch creates a new index and memory-maps (IndexView) the entire
    index file on every search, which takes 0.1-0.3 seconds for the larger databases. Instead, we keep one index handle
    per database and search it the same way that SemanticSearch's FindNearest does.

    The first search with each database file is checked against VectorDatabaseSearch, and the fast path is permanently
    disabled for a database on any mismatch or error.
*)
vectorDatabaseSearch // beginDefinition;

vectorDatabaseSearch[ name_String, db: $$vectorDatabase, vector_NumericArray, n_Integer ] :=
    vectorDatabaseSearch[ name, db, vector, n, touchUSearchIndex @ getUSearchIndex[ name, db ] ];

(* No usable index handle: *)
vectorDatabaseSearch[ name_, db_, vector_, n_, _Missing ] :=
    standardVectorDatabaseSearch[ db, vector, n ];

(* The index handle has already been checked against VectorDatabaseSearch: *)
vectorDatabaseSearch[ name_, db_, vector_, n_, index_Association ] /; usearchIndexVerifiedQ @ index :=
    With[ { result = usearchIndexSearch[ index, vector, n ] },
        If[ MatchQ[ result, { ___Association } ],
            result,
            disableUSearchIndex[ name, result ];
            standardVectorDatabaseSearch[ db, vector, n ]
        ]
    ];

(* First search with this database file, so make sure that the results are identical to VectorDatabaseSearch: *)
vectorDatabaseSearch[ name_, db_, vector_, n_, index_Association ] :=
    Module[ { expected, result },
        expected = standardVectorDatabaseSearch[ db, vector, n ];
        result   = usearchIndexSearch[ index, vector, n ];
        Which[
            result =!= expected,
                disableUSearchIndex[
                    name,
                    Failure[ "USearchIndexMismatch", <| "Expected" -> expected, "Actual" -> result |> ]
                ],
            MatchQ[ expected, { __Association } ],
                $usearchIndexVerified[ usearchIndexKey @ index ] = True
        ];
        expected
    ];

vectorDatabaseSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*standardVectorDatabaseSearch*)
standardVectorDatabaseSearch // beginDefinition;

standardVectorDatabaseSearch[ db_, vector_, n_ ] :=
    inVectorDBDirectory @ VectorDatabaseSearch[ db, vector, { "Index", "Distance" }, MaxItems -> n ];

standardVectorDatabaseSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getUSearchIndex*)
getUSearchIndex // beginDefinition;

(* Never keep index handles while building the MX file or when disabled by $cacheUSearchIndexes: *)
getUSearchIndex[ name_String, db_ ] /; TrueQ @ $mxFlag || ! TrueQ @ $cacheUSearchIndexes :=
    Missing[ "NotAvailable" ];

getUSearchIndex[ name_String, db_ ] /; KeyExistsQ[ $usearchIndexFailures, name ] :=
    Missing[ "Disabled" ];

getUSearchIndex[ name_String, db_ ] :=
    With[ { index = $usearchIndexCache[ name ] },
        index /; usearchIndexValidQ[ index, db ]
    ];

getUSearchIndex[ name_String, db_ ] :=
    Module[ { index },
        (* Release the previous handle (if any) before creating a new one: *)
        $usearchIndexCache = KeyDrop[ $usearchIndexCache, name ];
        index = createUSearchIndex @ db;
        If[ AssociationQ @ index,
            $usearchIndexCache[ name ] = index,
            disableUSearchIndex[ name, index ]
        ]
    ] // LogChatTiming[ "CreateUSearchIndex" ];

getUSearchIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*usearchIndexValidQ*)
(* An index handle is invalidated when the database is replaced or its index file changes (e.g. after a download): *)
usearchIndexValidQ // beginDefinition;

usearchIndexValidQ[ index_Association, db_ ] := TrueQ @ And[
    index[ "VectorDatabaseObject" ] === db,
    index[ "Directory" ] === $vectorDBDirectory,
    Quiet @ FileDate @ index[ "File" ] === index[ "FileDate" ]
];

usearchIndexValidQ[ _, _ ] := False;

usearchIndexValidQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*usearchIndexVerifiedQ*)
usearchIndexVerifiedQ // beginDefinition;
usearchIndexVerifiedQ[ index_Association ] := TrueQ @ $usearchIndexVerified @ usearchIndexKey @ index;
usearchIndexVerifiedQ // endDefinition;


usearchIndexKey // beginDefinition;
usearchIndexKey[ index_Association ] := Lookup[ index, { "VectorDatabaseObject", "File", "FileDate" } ];
usearchIndexKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createUSearchIndex*)
createUSearchIndex // beginDefinition;

createUSearchIndex[ db_ ] := catchUSearch @ Enclose[
    Module[ { functions, data, dimensions, location, file, date, handle },

        functions = ConfirmBy[ $usearchFunctions, AssociationQ, "Functions" ];

        (* This is the same data that VectorDatabaseSearch retrieves for FindNearest: *)
        data = ConfirmBy[
            inVectorDBDirectory @ functions[ "RetrieveFromDatabase" ][
                db,
                {
                    "DatabaseType",
                    "Dimensions",
                    "DistanceFunction",
                    "FeatureExtractor",
                    "VectorDatabase",
                    "VectorDatabaseInfo",
                    "WorkingPrecision"
                }
            ],
            AssociationQ,
            "Data"
        ];

        (* Only use the fast path for the kind of database that it replicates: *)
        ConfirmAssert[ data[ "DatabaseType"     ] === "USearch"           , "DatabaseType"       ];
        ConfirmAssert[ data[ "WorkingPrecision" ] === "Integer8"          , "WorkingPrecision"   ];
        ConfirmAssert[ data[ "DistanceFunction" ] === EuclideanDistance   , "DistanceFunction"   ];
        ConfirmAssert[ MatchQ[ data[ "FeatureExtractor" ], Identity|None ], "FeatureExtractor"   ];
        ConfirmAssert[ AssociationQ @ data[ "VectorDatabaseInfo" ]        , "VectorDatabaseInfo" ];

        dimensions = ConfirmMatch[ data[ "Dimensions" ], { _Integer? Positive, _Integer? Positive }, "Dimensions" ];
        location   = ConfirmMatch[ data[ "VectorDatabase" ], File[ _String ], "Location" ];
        file       = ConfirmBy[ inVectorDBDirectory @ ExpandFileName @ First @ location, FileExistsQ, "File" ];
        date       = ConfirmMatch[ FileDate @ file, _DateObject, "FileDate" ];

        handle = ConfirmBy[
            functions[ "deserializeIndex" ][ File @ file, data[ "VectorDatabaseInfo" ], "Read" ],
            ManagedLibraryExpressionQ,
            "Handle"
        ];

        <|
            "VectorDatabaseObject" -> db,
            "Directory"            -> $vectorDBDirectory,
            "File"                 -> file,
            "FileDate"             -> date,
            "Dimensions"           -> dimensions,
            "WorkingPrecision"     -> data[ "WorkingPrecision" ],
            "Functions"            -> functions,
            "Handle"               -> handle
        |>
    ],
    # &
];

createUSearchIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*usearchIndexSearch*)
(* Replicates FindNearest from SemanticSearch (VectorDatabase/OperationsUSearch.wl) using a persistent index handle: *)
usearchIndexSearch // beginDefinition;

usearchIndexSearch[ index_Association, vector_NumericArray, n_Integer ] := catchUSearch @ Enclose[
    Module[ { functions, handle, precision, size, dimension, vec, count, indices, elements },

        functions           = index[ "Functions"        ];
        handle              = index[ "Handle"           ];
        precision           = index[ "WorkingPrecision" ];
        { size, dimension } = index[ "Dimensions"       ];

        vec = ConfirmBy[ Normal @ vector, VectorQ[ #, RealValuedNumericQ ] &, "Vector" ];
        ConfirmAssert[ Length @ vec === dimension, "Dimension" ];

        count = Clip[ n, { 1, size } ];

        indices = ConfirmMatch[
            Normal @ functions[ "IndexSearch" ][ handle, functions[ "ToNumericArray" ][ vec, precision ], count ],
            { ___Integer },
            "Indices"
        ];

        indices = Take[ indices, UpTo[ count ] ];

        elements =
            If[ indices === { },
                { },
                ConfirmBy[ Normal @ functions[ "IndexGetVectors" ][ handle, indices, precision ], MatrixQ, "Elements" ]
            ];

        ConfirmAssert[ Length @ elements === Length @ indices, "LengthCheck" ];

        MapThread[ <| "Index" -> #1, "Distance" -> EuclideanDistance[ vec, #2 ] |> &, { indices, elements } ]
    ],
    # &
];

usearchIndexSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*disableUSearchIndex*)
disableUSearchIndex // beginDefinition;

disableUSearchIndex[ name_String, reason_ ] := (
    $usearchIndexCache = KeyDrop[ $usearchIndexCache, name ];
    (* Keep the reason for debugging, but make sure it doesn't hold on to an index handle (failures can contain held
       code, so the test must not evaluate the parts that it checks): *)
    $usearchIndexFailures[ name ] =
        reason /. h_ /; ManagedLibraryExpressionQ @ Unevaluated @ h :> Missing[ "Released" ];
    Missing[ "Disabled" ]
) // LogChatTiming[ { "DisableUSearchIndex", name } ];

disableUSearchIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*releaseUSearchIndexes*)
(* Index files stay memory-mapped as long as there's a handle, so this needs to be called before replacing them: *)
releaseUSearchIndexes // beginDefinition;
releaseUSearchIndexes[ ] := ($usearchIndexCache = <| |>;);
releaseUSearchIndexes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*touchUSearchIndex*)
(*
    Index handles are released after $usearchIndexIdleTime seconds without a search, so that an idle kernel does not
    keep the index files memory-mapped indefinitely. On Windows, a memory-mapped file cannot be replaced, which would
    prevent another kernel from updating the vector databases.
*)
touchUSearchIndex // beginDefinition;

touchUSearchIndex[ index_Association ] := (
    $usearchIndexLastUsed = AbsoluteTime[ ];
    If[ ! MatchQ[ $usearchIndexReleaseTask, _TaskObject ], scheduleUSearchIndexRelease @ $usearchIndexIdleTime ];
    index
);

touchUSearchIndex[ other_ ] := other;

touchUSearchIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*scheduleUSearchIndexRelease*)
scheduleUSearchIndexRelease // beginDefinition;

(* ScheduledTask does not accept arbitrary-precision numbers (e.g. from AbsoluteTime[ ]), so this uses whole seconds: *)
scheduleUSearchIndexRelease[ seconds_? NumberQ ] /; Positive @ seconds :=
    $usearchIndexReleaseTask = Replace[
        Quiet @ SessionSubmit @ ScheduledTask[ Quiet @ releaseIdleUSearchIndexes[ ], { Ceiling @ seconds } ],
        Except[ _TaskObject ] -> None
    ];

(* Handles are kept for the rest of the session when $usearchIndexIdleTime is not a positive number: *)
scheduleUSearchIndexRelease[ _ ] := Null;

scheduleUSearchIndexRelease // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*releaseIdleUSearchIndexes*)
releaseIdleUSearchIndexes // beginDefinition;

releaseIdleUSearchIndexes[ ] := (
    $usearchIndexReleaseTask = None;
    releaseIdleUSearchIndexes[ $usearchIndexIdleTime - (AbsoluteTime[ ] - $usearchIndexLastUsed) ]
);

(* Used recently, so check again later: *)
releaseIdleUSearchIndexes[ remaining_? Positive ] :=
    scheduleUSearchIndexRelease @ remaining;

releaseIdleUSearchIndexes[ _ ] :=
    releaseUSearchIndexes[ ];

releaseIdleUSearchIndexes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*catchUSearch*)
(* Uncaught failures from SemanticSearch internals would otherwise abort the evaluation: *)
catchUSearch // beginDefinition;
catchUSearch // Attributes = { HoldFirst };

catchUSearch[ eval_ ] := Quiet @ Catch[
    GeneralUtilities`CatchFailure @ eval,
    _,
    Failure[ "USearchException", <| "Value" -> #1, "Tag" -> #2 |> ] &
];

catchUSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$usearchFunctions*)
$usearchFunctions := getUSearchFunctions[ ];

getUSearchFunctions // beginDefinition;

getUSearchFunctions[ ] := Enclose[
    Module[ { names, functions },

        Needs[ "SemanticSearch`" -> None ];

        names = <|
            "deserializeIndex"     -> "SemanticSearch`PackageScope`deserializeIndex",
            "IndexGetVectors"      -> "SemanticSearch`PackageScope`IndexGetVectors",
            "IndexSearch"          -> "SemanticSearch`PackageScope`IndexSearch",
            "RetrieveFromDatabase" -> "SemanticSearch`PackageScope`RetrieveFromDatabase",
            "ToNumericArray"       -> "SemanticSearch`PackageScope`ToNumericArray"
        |>;

        ConfirmAssert[
            AllTrue[
                Append[ Values @ names, "GeneralUtilities`CatchFailure" ],
                NameQ @ # && ToExpression[ #, InputForm, System`Private`HasAnyEvaluationsQ ] &
            ],
            "Defined"
        ];

        functions = Symbol /@ names;

        If[ TrueQ @ $mxFlag, functions, getUSearchFunctions[ ] = functions ]
    ],
    # &
];

getUSearchFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Embeddings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getEmbedding*)
getEmbedding // beginDefinition;
getEmbedding // Options = { "CacheEmbeddings" -> $cacheEmbeddings };

getEmbedding[ string_String, opts: OptionsPattern[ ] ] :=
    With[ { embedding = $embeddingCache[ string ] },
        embedding /; NumericArrayQ @ embedding
    ];

getEmbedding[ string_String, opts: OptionsPattern[ ] ] := Enclose[
    First @ ConfirmMatch[ getEmbeddings[ { string }, opts ], { _NumericArray }, "Embedding" ],
    throwInternalFailure
];

getEmbedding // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getEmbeddings*)
getEmbeddings // beginDefinition;
getEmbeddings // Options = { "CacheEmbeddings" -> $cacheEmbeddings };

getEmbeddings[ { }, opts: OptionsPattern[ ] ] := { };

getEmbeddings[ strings: { __String }, opts: OptionsPattern[ ] ] :=
    If[ TrueQ @ OptionValue[ "CacheEmbeddings" ],
        getEmbeddings0 @ strings,
        Block[ { $cacheEmbeddings = False }, getAndCacheEmbeddings @ strings ]
    ] // LogChatTiming[ "GetEmbeddings" ];

getEmbeddings // endDefinition;


getEmbeddings0 // beginDefinition;

getEmbeddings0[ strings: { __String } ] := Enclose[
    Module[ { cache, notCached, vectors },
        (* Drop the oldest embeddings when the cache is full: *)
        If[ Length @ $embeddingCache >= $maxEmbeddingCacheSize,
            $embeddingCache = Take[ $embeddingCache, -Floor[ $maxEmbeddingCacheSize / 2 ] ]
        ];
        (* Look up results in a snapshot, since a preemptive evaluation could trim the cache before this finishes: *)
        cache     = $embeddingCache;
        notCached = Select[ strings, ! KeyExistsQ[ cache, # ] & ];
        vectors   = ConfirmMatch[ getAndCacheEmbeddings @ notCached, { ___NumericArray }, "CacheEmbeddings" ];
        ConfirmMatch[
            Lookup[ Join[ cache, AssociationThread[ notCached, vectors ] ], strings ],
            { __NumericArray },
            "Result"
        ]
    ],
    throwInternalFailure
];

getEmbeddings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAndCacheEmbeddings*)
getAndCacheEmbeddings // beginDefinition;

getAndCacheEmbeddings[ { } ] :=
    { };

getAndCacheEmbeddings[ strings: { __String } ] /; $embeddingModel === "SentenceBERT" := Enclose[
    Module[ { vectors },
        vectors = ConfirmBy[
            If[ AllTrue[ strings, StringMatchQ[ WhitespaceCharacter... ] ],
                Developer`ToPackedArray @ Rest @ sentenceBERTEmbedding @ Prepend[ strings, "hello" ],
                Developer`ToPackedArray @ sentenceBERTEmbedding @ strings
            ],
            Developer`PackedArrayQ,
            "PackedArray"
        ];

        ConfirmAssert[ Length @ strings === Length @ vectors, "LengthCheck" ];

        MapThread[ cacheEmbedding, { strings, vectors } ]
    ],
    throwInternalFailure
];

getAndCacheEmbeddings[ strings: { __String } ] := Enclose[
    Module[ { resp, vectors },
        resp = ConfirmBy[
            setServiceCaller @ ServiceExecute[
                $embeddingService,
                "RawEmbedding",
                { "input" -> strings, "model" -> $embeddingModel },
                Authentication -> $embeddingAuthentication
            ],
            AssociationQ,
            "EmbeddingResponse"
        ];

        vectors = ConfirmBy[
            Developer`ToPackedArray @ resp[[ "data", All, "embedding" ]],
            Developer`PackedArrayQ,
            "PackedArray"
        ];

        ConfirmAssert[ Length @ strings === Length @ vectors, "LengthCheck" ];

        MapThread[ cacheEmbedding, { strings, vectors } ]
    ],
    throwInternalFailure
];

getAndCacheEmbeddings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cacheEmbedding*)
cacheEmbedding // beginDefinition;
cacheEmbedding[ key_String, vector_ ] /; ! $cacheEmbeddings := toTinyVector @ vector;
cacheEmbedding[ key_String, vector_ ] := $embeddingCache[ key ] = toTinyVector @ vector;
cacheEmbedding // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sentenceBERTEmbedding*)
sentenceBERTEmbedding := getSentenceBERTEmbeddingFunction[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*getSentenceBERTEmbeddingFunction*)
getSentenceBERTEmbeddingFunction // beginDefinition;

getSentenceBERTEmbeddingFunction[ ] := Enclose[
    Module[ { name },

        Needs[ "SemanticSearch`" -> None ];

        name = ConfirmBy[
            SelectFirst[
                {
                    "SemanticSearch`SentenceBERTEmbedding",
                    "SemanticSearch`SemanticSearch`Private`SentenceBERTEmbedding"
                },
                NameQ @ # && ToExpression[ #, InputForm, System`Private`HasAnyEvaluationsQ ] &
            ],
            StringQ,
            "SymbolName"
        ];

        getSentenceBERTEmbeddingFunction[ ] = Symbol @ name
    ],
    throwInternalFailure
];

getSentenceBERTEmbeddingFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toTinyVector*)
toTinyVector // beginDefinition;
toTinyVector[ v_ ] := NumericArray[ 127.5 * Normalize @ v[[ 1;;$embeddingDimension ]] - 0.5, "Real16" ];
toTinyVector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
