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

$embeddingDimension      = 384;
$maxNeighbors            = 250;
$maxEmbeddingDistance    = 150.0;
$embeddingService        = "Local";
$embeddingModel          = "SentenceBERT";
$embeddingAuthentication = Automatic;


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

$vectorDBDownloadURLs := $vectorDBDownloadURLs = AssociationMap[
    <|
        "CDN"   -> makeDownloadURL[ $cdnBaseVectorDatabasesURL  , # ],
        "Cloud" -> makeDownloadURL[ $cloudBaseVectorDatabasesURL, # ]
    |> &,
    $vectorDBNames
];

$vectorDBDownloadSizes = <|
    "DataRepositoryURIs"      ->   5812001,
    "DocumentationURIs"       -> 369969648,
    "EntityValues"            ->  63998991,
    "FunctionRepositoryURIs"  ->  61661803,
    "NeuralNetRepositoryURIs" ->   2512274,
    "PacletRepositoryURIs"    ->  14170624,
    "SourceSelector"          -> 115700803,
    "WolframAlphaQueries"     ->  19410556
|>;

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

InstallVectorDatabases[ ] :=
    catchMine @ Block[ { $pacletVectorDBDirectory = None, $suppressDownloadWarning = True },
        installVectorDatabases[ ]
    ];

InstallVectorDatabases // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*installVectorDatabases*)
installVectorDatabases // beginDefinition;

installVectorDatabases[ ] := Enclose[
    Module[ { dir, snippets, snippetDir },
        dir = ConfirmBy[ getVectorDBDirectory[ ], vectorDBDirectoryQ, "Location" ];
        snippets = ConfirmMatch[ InstallDocumentationResources[ ], _Success, "Snippets" ];
        snippetDir = ConfirmBy[ snippets[ "Location" ], DirectoryQ, "SnippetLocation" ];
        Success[ "VectorDatabasesInstalled", <| "Location" -> dir, "Snippets" -> snippetDir |> ]
    ],
    throwInternalFailure
];

installVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Vector Database Utilities*)
$vectorDBDirectory := getVectorDBDirectory[ ];

$noSemanticSearch := $noSemanticSearch = ! PacletObjectQ @ Quiet @ PacletInstall[ "SemanticSearch" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getVectorDBDirectory*)
getVectorDBDirectory // beginDefinition;

getVectorDBDirectory[ ] := Enclose[
    Module[ { sources, dir },
        sources = {
            $pacletVectorDBDirectory,
            If[ $CloudEvaluation, $cloudVectorDBDirectory, Nothing ],
            $localVectorDBDirectory
        };

        dir = SelectFirst[
            sources,
            vectorDBDirectoryQ,
            ConfirmBy[ downloadVectorDatabases[ ], vectorDBDirectoryQ, "Downloaded" ]
        ];

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
(* ::Subsection::Closed:: *)
(*vectorDBDirectoryQ*)
vectorDBDirectoryQ // beginDefinition;
vectorDBDirectoryQ[ dir_? DirectoryQ ] := AllTrue[ $vectorDBNames, vectorDBDirectoryQ0 @ FileNameJoin @ { dir, # } & ];
vectorDBDirectoryQ[ _ ] := False;
vectorDBDirectoryQ // endDefinition;

vectorDBDirectoryQ0 // beginDefinition;

vectorDBDirectoryQ0[ dir_? DirectoryQ ] := Enclose[
    Module[ { name, existsQ, expected, versionFile, expectedVersion },

        name            = ConfirmBy[ FileBaseName @ dir, StringQ, "Name" ];
        existsQ         = FileExistsQ @ FileNameJoin @ { dir, # } &;
        expected        = { name <> ".wxf", "Values.wxf", name <> "-vectors.usearch" };
        versionFile     = FileNameJoin @ { dir, "Version.wl" };
        expectedVersion = ConfirmBy[ $vectorDatabases[ name, "Version" ], StringQ, "ExpectedVersion" ];

        (* Bypass version check for development builds: *)
        If[ ! FileExistsQ @ versionFile && StringStartsQ[ dir, $pacletVectorDBDirectory ],
            Put[ expectedVersion, versionFile ]
        ];

        TrueQ[ AllTrue[ expected, existsQ ] && FileExistsQ @ versionFile && Get @ versionFile === expectedVersion ]
    ],
    throwInternalFailure
];

vectorDBDirectoryQ0[ _ ] := False;

vectorDBDirectoryQ0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*downloadVectorDatabases*)
downloadVectorDatabases // beginDefinition;

(* Both of these need a condition, since a definition without patterns or conditions is always tried first: *)
downloadVectorDatabases[ ] /; ! $allowDownload :=
    Throw[ Missing[ "DownloadDisabled" ], $vdbTag ];

downloadVectorDatabases[ ] /; $allowDownload :=
    downloadVectorDatabases[ $localVectorDBDirectory, $vectorDBDownloadURLs ];

downloadVectorDatabases[ dir0_, urls0_Association ] := Enclose[
    Module[ { dir, lock, names, urls, sizes, tasks },

        If[ $CloudEvaluation && ! TrueQ @ $suppressDownloadWarning, messagePrint[ "VectorDatabaseCloudDownload" ] ];

        $extraDownloadTasks = Internal`Bag[ ];

        dir = ConfirmBy[ GeneralUtilities`EnsureDirectory @ dir0, DirectoryQ, "Directory" ];
        (* cleanupLegacyVectorDBFiles @ dir; *) (* function not defined *)

        (* Try unpacking any zip files that might be left over from previous install attempts: *)
        Quiet @ catchAlways @ tryUnpackingVectorDatabases @ dir;

        (* Download any remaining vector databases: *)
        names = Select[ $vectorDBNames, ! vectorDBDirectoryQ0 @ FileNameJoin @ { dir, # } & ];
        urls  = KeyTake[ urls0, names ];

        lock  = FileNameJoin @ { dir, "download.lock" };
        sizes = ConfirmMatch[ Values @ KeyTake[ $vectorDBDownloadSizes, names ], { __? Positive }, "Sizes" ];

        $downloadProgress = AssociationMap[ 0 &, names ];
        $progressText = "Downloading semantic search indices\[Ellipsis]";

        evaluateWithProgress[
            WithLock[
                File @ lock
                ,
                tasks = ConfirmMatch[ KeyValueMap[ downloadVectorDatabase @ dir, urls ], { __TaskObject }, "Download" ];
                ConfirmMatch[ taskWait @ tasks, { (_TaskObject|$Failed).. }, "TaskWait" ];
                ConfirmMatch[ taskWait @ $extraDownloadTasks, { (_TaskObject|$Failed)... }, "TaskWait" ];
                $progressText = "Unpacking files\[Ellipsis]";
                ConfirmBy[ unpackVectorDatabases @ dir, DirectoryQ, "Unpacked" ]
                ,
                PersistenceTime -> 180
            ],

            <|
                "Text"             :> $progressText,
                "ElapsedTime"      -> Automatic,
                "RemainingTime"    -> Automatic,
                "ByteCountCurrent" :> Total @ $downloadProgress,
                "ByteCountTotal"   -> Total @ sizes,
                "Progress"         -> Automatic
            |>
        ]
    ] // LogChatTiming[ "DownloadVectorDatabases" ],
    throwInternalFailure
];

downloadVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tryUnpackingVectorDatabases*)
tryUnpackingVectorDatabases // beginDefinition;

tryUnpackingVectorDatabases[ dir_? DirectoryQ ] :=
    Map[ tryUnpackingVectorDatabase, FileNames[ { "*.zip", "*.zip.tmp" }, dir ] ];

tryUnpackingVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tryUnpackingVectorDatabase*)
tryUnpackingVectorDatabase // beginDefinition;

tryUnpackingVectorDatabase[ zip_? FileExistsQ ] :=
    Quiet @ With[ { res = catchAlways @ unpackVectorDatabase @ zip },
        If[ FailureQ @ res, DeleteFile @ zip ];
        res
    ];

tryUnpackingVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unpackVectorDatabases*)
unpackVectorDatabases // beginDefinition;

unpackVectorDatabases[ dir_? DirectoryQ ] :=
    unpackVectorDatabases[ dir, FileNames[ "*.zip", dir ] ] // LogChatTiming[ "UnpackVectorDatabases" ];

unpackVectorDatabases[ dir_, zips: { __String } ] :=
    unpackVectorDatabases[ dir, zips, unpackVectorDatabase /@ zips ];

unpackVectorDatabases[ dir_, zips_, extracted: { { __String }.. } ] :=
    dir;

unpackVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unpackVectorDatabase*)
unpackVectorDatabase // beginDefinition;

unpackVectorDatabase[ zip_String? FileExistsQ ] := Enclose[
    Module[ { name, version, root, dir, res, versionFile },
        name = ConfirmBy[ FileBaseName @ StringDelete[ zip, ".tmp"~~EndOfString ], StringQ, "Name" ];
        version = ConfirmBy[ $vectorDatabases[ name, "Version" ], StringQ, "Version" ];
        root = ConfirmBy[ DirectoryName @ zip, DirectoryQ, "RootDirectory" ];
        dir = ConfirmBy[ GeneralUtilities`EnsureDirectory @ { root, name }, DirectoryQ, "Directory" ];
        (* Memory-mapped index files cannot be overwritten on Windows: *)
        releaseUSearchIndexes[ ];
        res = ConfirmMatch[ ExtractArchive[ zip, dir, OverwriteTarget -> True ], { __? FileExistsQ }, "Extracted" ];
        versionFile = FileNameJoin @ { dir, "Version.wl" };
        Put[ version, versionFile ];
        ConfirmAssert[ Get @ versionFile === version, "VersionCheck" ];
        DeleteFile @ zip;
        res
    ],
    throwInternalFailure
];

unpackVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*taskWait*)
taskWait // beginDefinition;
taskWait[ tasks_Internal`Bag ] := taskWait @ Internal`BagPart[ tasks, All ];
taskWait[ tasks_List ] := CheckAbort[ taskWait /@ tasks, Quiet[ TaskRemove /@ tasks ], PropagateAborts -> True ];
taskWait[ task_TaskObject ] := taskWait[ task, task[ "TaskStatus" ] ];
taskWait[ task_TaskObject, "Removed" ] := task;
taskWait[ task_TaskObject, _ ] := taskWaitYield @ task;
taskWait // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabase*)
downloadVectorDatabase // beginDefinition;

downloadVectorDatabase[ dir_ ] :=
    downloadVectorDatabase[ dir, ## ] &;

downloadVectorDatabase[ dir_, name_String, urls_Association ] :=
    downloadVectorDatabase[ dir, name, urls[ "CDN" ], urls[ "Cloud" ] ];

downloadVectorDatabase[ dir_, name_String, cdnURL_String, cloudURL_String ] := Enclose[
    Module[ { file, tmp },

        file = ConfirmBy[ FileNameJoin @ { dir, name<>".zip" }, StringQ, "File" ];
        tmp = file <> ".tmp";
        Quiet[ DeleteFile /@ { file, tmp } ];

        With[ { tmp = tmp, file = file },
            ConfirmMatch[
                URLDownloadSubmit[
                    cdnURL,
                    tmp,
                    HandlerFunctions -> <|
                        "TaskProgress" -> setDownloadProgress @ name,
                        "TaskFinished" -> checkVectorDatabaseDownload[ name, tmp, file, cloudURL ]
                    |>,
                    HandlerFunctionsKeys -> { "ByteCountDownloaded", "StatusCode" }
                ],
                _TaskObject,
                "Task"
            ]
        ]
    ] // LogChatTiming[ { "DownloadVectorDatabase", name } ],
    throwInternalFailure
];

downloadVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkVectorDatabaseDownload*)
checkVectorDatabaseDownload // beginDefinition;

checkVectorDatabaseDownload[ name_, tmp_, file_, cloudURL_ ] :=
    checkVectorDatabaseDownload[ name, tmp, file, cloudURL, # ] &;

checkVectorDatabaseDownload[ name_, tmp_String, file_String, cloudURL_, KeyValuePattern[ "StatusCode" -> 200 ] ] :=
    RenameFile[ tmp, file ];

(* CDN download failed, so try cloud: *)
checkVectorDatabaseDownload[
    name_String,
    tmp_String,
    file_String,
    cloudURL_String,
    result_
] := (
    Quiet @ DeleteFile @ tmp;
    Internal`StuffBag[
        $extraDownloadTasks,
        URLDownloadSubmit[
            cloudURL,
            tmp,
            HandlerFunctions -> <|
                "TaskProgress" -> setDownloadProgress @ name,
                "TaskFinished" -> (RenameFile[ tmp, file ] &)
            |>,
            HandlerFunctionsKeys -> { "ByteCountDownloaded", "StatusCode" }
        ]
    ]
);

checkVectorDatabaseDownload // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setDownloadProgress*)
setDownloadProgress // beginDefinition;
setDownloadProgress[ name_String ] := setDownloadProgress[ name, ## ] &;
setDownloadProgress[ name_, KeyValuePattern[ "ByteCountDownloaded" -> b_? Positive ] ] := $downloadProgress[ name ] = b;
setDownloadProgress // endDefinition;

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
    Module[ { vectorDB },
        vectorDB = ConfirmMatch[ getVectorDB[ name ][ "VectorDatabaseObject" ], $$vectorDatabase, "VectorDatabase" ];
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

getVectorDB[ name_String ] := Enclose[
    getVectorDB[ name ] = ConfirmMatch[
        Association @ loadVectorDB @ name,
        KeyValuePattern @ { "Values" -> { ___String }, "VectorDatabaseObject" -> $$vectorDatabase },
        "VectorDB"
    ],
    throwInternalFailure
];

getVectorDB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadVectorDB*)
loadVectorDB // beginDefinition;

loadVectorDB[ name_String ] := Enclose[
    Module[ { values, vectorDB, dims },

        values   = ConfirmMatch[ loadVectorDBValues @ name, { ___String }, "Values" ];
        vectorDB = ConfirmMatch[ loadVectorDatabase @ name, $$vectorDatabase, "VectorDatabaseObject" ];
        dims     = ConfirmMatch[ inVectorDBDirectory @ vectorDB[ "Dimensions" ], { _Integer, _Integer }, "Dimensions" ];

        ConfirmAssert[ Length @ values === First @ dims, "LengthCheck" ];

        <| "Values" -> values, "VectorDatabaseObject" -> vectorDB |>
    ],
    throwInternalFailure
];

loadVectorDB // endDefinition;

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
    With[ { result = $vectorDBSearchCache[ dbName, prompt ] },
        result /; AssociationQ @ result
    ];


(* Main definition for string prompt: *)
vectorDBSearch[ dbName: $$dbName, prompt_String, All ] := Enclose[
    Module[
        {
            vectorDBInfo, vectorDB, allValues, embeddingVector, close,
            indices, distances, values, data, result, snippetFunction, instructionsFunction, instructionsPosition
        },

        vectorDBInfo    = ConfirmBy[ getVectorDB @ dbName, AssociationQ, "VectorDBInfo" ];
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
        ConfirmAssert[ $vectorDBSearchCache[ dbName, prompt ] === result, "CacheCheck" ];

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
    Module[ { vectorDBInfo },
        vectorDBInfo = ConfirmBy[ getVectorDB @ dbName, AssociationQ, "VectorDB" ];
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

cacheVectorDBResult[ dbName: $$dbName, prompt_String, data_Association ] := (
    If[ ! AssociationQ @ $vectorDBSearchCache, $vectorDBSearchCache = <| |> ];
    If[ ! AssociationQ @ $vectorDBSearchCache[ dbName ], $vectorDBSearchCache[ dbName ] = <| |> ];
    $vectorDBSearchCache[ dbName, prompt ] = data
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
    Module[ { notCached },
        notCached = Select[ strings, ! KeyExistsQ[ $embeddingCache, # ] & ];
        ConfirmMatch[ getAndCacheEmbeddings @ notCached, { ___NumericArray }, "CacheEmbeddings" ];
        ConfirmMatch[ Lookup[ $embeddingCache, strings ], { __NumericArray }, "Result" ]
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
    $vectorDBDownloadSizes;
];

End[ ];
EndPackage[ ];
