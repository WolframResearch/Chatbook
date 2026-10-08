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

$vectorDBDownloadDeclined = False;
$downloadLockPersistence  = Infinity;
$staleArtifactAge         = 120;
$downloadProgress         = <| |>;
$downloadStatus           = <| |>;

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
        $vectorDBDownloadDeclined = False;
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
    Module[ { name, versionFile, expectedVersion, devQ, cloudQ },

        name            = ConfirmBy[ FileBaseName @ dir, StringQ, "Name" ];
        versionFile     = FileNameJoin @ { dir, "Version.wl" };
        expectedVersion = ConfirmBy[ $vectorDatabases[ name, "Version" ], StringQ, "ExpectedVersion" ];
        devQ            = pacletVectorDBDirectoryQ @ dir;
        cloudQ          = TrueQ[ $CloudEvaluation && With[ { c = Quiet @ $cloudVectorDBDirectory }, StringQ @ c && StringStartsQ[ dir, c ] ] ];

        (* Bypass version check for development builds: *)
        If[ ! FileExistsQ @ versionFile && devQ, Put[ expectedVersion, versionFile ] ];

        TrueQ @ And[
            installedVectorDBVersion @ dir === expectedVersion,
            vectorDBFilesPresentQ[ dir, name ],
            vectorDBManifestValidQ @ dir,
            devQ || cloudQ || vectorDBIndexSizeValidQ[ dir, name, expectedVersion ]
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

pacletVectorDBDirectoryQ[ dir_String ] :=
    With[ { root = $pacletVectorDBDirectory }, StringQ @ root && StringStartsQ[ dir, root ] ];

pacletVectorDBDirectoryQ // endDefinition;

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

vectorDBIndexSizeValidQ[ dir_String, name_String, version_String ] :=
    With[ { expected = Lookup[ $vectorDBIndexSizes, Key @ { name, version } ] },
        IntegerQ @ expected && FileByteCount @ FileNameJoin @ { dir, name <> "-vectors.usearch" } === expected
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

vectorDBManifestValidQ[ dir_String, KeyValuePattern[ "Files" -> files_Association ] ] :=
    AllTrue[
        Normal @ files,
        MatchQ[ #, _String -> _Integer ] && Quiet @ FileByteCount @ FileNameJoin @ { dir, First @ # } === Last @ # &
    ];

vectorDBManifestValidQ[ dir_String, _ ] := False;

vectorDBManifestValidQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeVectorDBManifest*)
writeVectorDBManifest // beginDefinition;

writeVectorDBManifest[ dir_String, version_String ] := Enclose[
    Module[ { files, manifest, file },
        files = ConfirmMatch[ FileNames[ "*", dir ], { __String }, "Files" ];
        manifest = <|
            "Version" -> version,
            "Files"   -> Association[ FileNameTake[ #, -1 ] -> FileByteCount[ # ] & /@ Select[ files, FileExistsQ[ # ] && ! DirectoryQ[ # ] & ] ]
        |>;
        file = FileNameJoin @ { dir, "Manifest.wxf" };
        ConfirmBy[ Developer`WriteWXFFile[ file, manifest ], FileExistsQ, "Write" ]
    ],
    throwInternalFailure
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
            Quiet @ catchAlways @ toVectorDatabaseValues @ Developer`ReadWXFFile @ FileNameJoin @ { dir, "Values.wxf" },
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
partialVectorDBDownloads // beginDefinition;

partialVectorDBDownloads[ root_String ] :=
    Select[ FileNames[ { "*.tmp", "*.staging", "*.old-*" }, root ], staleArtifactQ ];

partialVectorDBDownloads[ root_String, name_String ] :=
    Select[ FileNames[ { name <> ".zip*.tmp", name <> ".staging", name <> ".old-*" }, root ], staleArtifactQ ];

partialVectorDBDownloads // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*staleArtifactQ*)
(* Files that are still being written (e.g. by another kernel) are not considered stale: *)
staleArtifactQ // beginDefinition;

staleArtifactQ[ file_String ] :=
    With[ { date = Quiet @ FileDate[ file, "Modification" ] },
        ! DateObjectQ @ date || AbsoluteTime[ ] - AbsoluteTime @ date > $staleArtifactAge
    ];

staleArtifactQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cleanupPartialDownloads*)
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

downloadVectorDatabases[ ] /; ! $allowDownload :=
    Throw[ Missing[ "DownloadDisabled" ], $vdbTag ];

downloadVectorDatabases[ ] /; TrueQ @ $vectorDBDownloadDeclined :=
    Quiet @ throwFailure[ "VectorDatabaseDownloadDeclined" ];

downloadVectorDatabases[ ] :=
    downloadVectorDatabases[ $localVectorDBDirectory, $vectorDBDownloadURLs ];

downloadVectorDatabases[ dir0_, urls0_Association ] := Enclose[
    Module[ { dir, lock },

        If[ $CloudEvaluation && ! TrueQ @ $suppressDownloadWarning, messagePrint[ "VectorDatabaseCloudDownload" ] ];

        dir  = ConfirmBy[ GeneralUtilities`EnsureDirectory @ dir0, DirectoryQ, "Directory" ];
        lock = FileNameJoin @ { dir, "download.lock" };

        WithLock[
            File @ lock,
            downloadVectorDatabasesLocked[ dir, urls0 ],
            PersistenceTime -> $downloadLockPersistence
        ]
    ] // LogChatTiming[ "DownloadVectorDatabases" ],
    throwInternalFailure
];

downloadVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabasesLocked*)
downloadVectorDatabasesLocked // beginDefinition;

downloadVectorDatabasesLocked[ dir_String, urls0_Association ] := Enclose[
    Catch @ Module[ { partial, names, installedQ, damaged, urls },

        Scan[ restoreVectorDBBackup[ dir, # ] &, Keys @ urls0 ];

        (* Names that have leftover artifacts from an interrupted download: *)
        partial = Select[ Keys @ urls0, partialVectorDBDownloads[ dir, # ] =!= { } & ];
        cleanupPartialDownloads @ dir;

        (* Try unpacking any complete zip files that might be left over from previous install attempts: *)
        Quiet @ catchAlways @ tryUnpackingVectorDatabases @ dir;

        (* Another kernel may have finished installing while we were waiting for the lock: *)
        names = Select[ Keys @ urls0, ! vectorDBDirectoryQ0 @ FileNameJoin @ { dir, # } & ];
        If[ names === { }, Throw @ dir ];

        (* If some databases are already installed, any that are missing entirely were likely deleted or lost: *)
        installedQ = AnyTrue[ $vectorDBNames, vectorDBDirectoryQ0 @ FileNameJoin @ { dir, # } & ];

        damaged = Select[
            names,
            MemberQ[ partial, # ] || vectorDBDamagedQ[ dir, # ] || (installedQ && ! FileExistsQ @ FileNameJoin @ { dir, # }) &
        ];

        If[ damaged =!= { } && TrueQ @ $promptRedownload,
            If[ ! confirmRedownload[ "DownloadTypeVectorDatabases", damaged, Total @ Cases[ Lookup[ $vectorDBDownloadSizes, damaged, 0 ], _Integer? Positive ] ],
                $vectorDBDownloadDeclined = True;
                throwFailure[ "VectorDatabaseDownloadDeclined" ]
            ]
        ];

        urls = ConfirmBy[ KeyTake[ urls0, names ], AssociationQ, "URLs" ];
        ConfirmBy[ downloadAndUnpackVectorDatabases[ dir, urls ], DirectoryQ, "Downloaded" ]
    ],
    throwInternalFailure
];

downloadVectorDatabasesLocked // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadAndUnpackVectorDatabases*)
downloadAndUnpackVectorDatabases // beginDefinition;

downloadAndUnpackVectorDatabases[ dir_String, urls_Association ] := Enclose[
    Module[ { names, total, results, failed },

        names = Keys @ urls;
        total = Total @ Cases[ Lookup[ $vectorDBDownloadSizes, names, 0 ], _Integer? Positive ];

        $downloadProgress = AssociationMap[ 0 &, names ];
        $progressText = trRaw[ "ProgressTextDownloadingSearchIndices" ];

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

        If[ failed =!= { },
            If[ MemberQ[ results, Missing[ "Cancelled" ] ],
                $vectorDBDownloadDeclined = True;
                throwFailure[ "VectorDatabaseDownloadDeclined" ],
                throwFailure[ "VectorDatabaseDownloadFailed", StringRiffle[ failed, ", " ] ]
            ]
        ];

        dir
    ],
    throwInternalFailure
];

downloadAndUnpackVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabaseFiles*)
(* Downloads (in parallel) and unpacks each vector database, retrying failures up to $maxDownloadAttempts times.
   Returns an association of name -> installed directory, or a Failure/Missing for those that could not be installed. *)
downloadVectorDatabaseFiles // beginDefinition;

downloadVectorDatabaseFiles[ dir_String, urls_Association ] := Enclose[
    Module[ { pending, results, attempt, start, rate, round, sizes },

        pending = Keys @ urls;
        results = <| |>;
        attempt = 1;
        rate    = None;

        While[ pending =!= { } && attempt <= $maxDownloadAttempts,

            If[ attempt > 1,
                sizes = Total @ Cases[ Lookup[ $vectorDBDownloadSizes, pending, 0 ], _Integer? Positive ];
                If[ ! confirmDownloadRetry[ StringRiffle[ pending, ", " ], sizes, rate ],
                    Scan[ (results[ # ] = Missing[ "Cancelled" ]) &, pending ];
                    Break[ ]
                ];
                Pause[ attempt - 1 ];
                $progressText = trRaw[ "ProgressTextRetryingSearchIndices" ]
            ];

            start = AbsoluteTime[ ];
            round = ConfirmBy[ downloadVectorDatabaseRound[ dir, KeyTake[ urls, pending ], attempt ], AssociationQ, "Round" ];
            rate  = observedDownloadRate[ Total @ Lookup[ $downloadProgress, pending, 0 ], AbsoluteTime[ ] - start ];

            $progressText = trRaw[ "ProgressTextUnpackingFiles" ];
            KeyValueMap[ (results[ #1 ] = finishVectorDatabaseDownload[ dir, #1, #2 ]) &, round ];

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
(*observedDownloadRate*)
observedDownloadRate // beginDefinition;
observedDownloadRate[ bytes_? Positive, time_? Positive ] := bytes / time;
observedDownloadRate[ _, _ ] := None;
observedDownloadRate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabaseRound*)
downloadVectorDatabaseRound // beginDefinition;

downloadVectorDatabaseRound[ dir_String, urls_Association, attempt_Integer ] := Enclose[
    Module[ { tasks },
        $downloadStatus = <| |>;
        tasks = ConfirmMatch[
            KeyValueMap[ submitVectorDatabaseDownload[ dir, #1, downloadURL[ #2, attempt ] ] &, urls ],
            { ___TaskObject },
            "Tasks"
        ];
        taskWait @ tasks;
        waitForDownloadHandlers @ Keys @ urls;
        AssociationMap[ Lookup[ $downloadStatus, #, <| |> ] &, Keys @ urls ]
    ],
    throwInternalFailure
];

downloadVectorDatabaseRound // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadURL*)
(* Alternate between the CDN and the cloud on each attempt: *)
downloadURL // beginDefinition;
downloadURL[ urls_Association, attempt_Integer ] := If[ OddQ @ attempt, urls[ "CDN" ], urls[ "Cloud" ] ];
downloadURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitVectorDatabaseDownload*)
submitVectorDatabaseDownload // beginDefinition;

submitVectorDatabaseDownload[ dir_String, name_String, url_String ] :=
    With[ { tmp = FileNameJoin @ { dir, name <> ".zip." <> CreateUUID[ ] <> ".tmp" } },
        $downloadProgress[ name ] = 0;
        $downloadStatus[ name ] = <| "File" -> tmp, "URL" -> url |>;
        URLDownloadSubmit[
            url,
            tmp,
            HandlerFunctions -> <|
                "TaskProgress" -> setDownloadProgress @ name,
                "TaskFinished" -> setDownloadFinished @ name
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
finishVectorDatabaseDownload // beginDefinition;

finishVectorDatabaseDownload[ dir_String, name_String, status_Association ] :=
    With[ { tmp = status[ "File" ], zip = FileNameJoin @ { dir, name <> ".zip" } },
        Replace[
            finishVectorDatabaseDownload0[ dir, name, status, zip ],
            failure_Failure :> (Quiet[ DeleteFile /@ Select[ { tmp, zip }, StringQ[ # ] && FileExistsQ[ # ] & ] ]; failure)
        ]
    ];

finishVectorDatabaseDownload // endDefinition;


finishVectorDatabaseDownload0 // beginDefinition;

finishVectorDatabaseDownload0[ dir_, name_, status_, zip_ ] := Enclose[
    Module[ { tmp, size },
        tmp = ConfirmBy[ status[ "File" ], StringQ, "File" ];
        ConfirmAssert[ status[ "StatusCode" ] === 200, "StatusCode" ];
        ConfirmAssert[ FileExistsQ @ tmp, "Exists" ];
        size = FileByteCount @ tmp;
        ConfirmAssert[ validDownloadSizeQ[ size, $vectorDBDownloadSizes @ name, status[ "ByteCountTotal" ] ], "Size" ];
        ConfirmAssert[ validDownloadHashQ[ name, tmp ], "Hash" ];
        ConfirmBy[ RenameFile[ tmp, zip, OverwriteTarget -> True ], FileExistsQ, "Rename" ];
        ConfirmBy[ unpackVectorDatabase @ zip, DirectoryQ, "Unpack" ]
    ],
    Function[ failure, Failure[ "VectorDatabaseDownloadFailed", <| "Name" -> name, "Reason" -> failure |> ] ]
];

finishVectorDatabaseDownload0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validDownloadSizeQ*)
(* The download must match the known size and, when available, the size reported by the server: *)
validDownloadSizeQ // beginDefinition;
validDownloadSizeQ[ size_Integer? Positive, known_Integer? Positive, total_ ] :=
    size === known && (! IntegerQ @ total || size === total);
validDownloadSizeQ[ _, _, _ ] := False;
validDownloadSizeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validDownloadHashQ*)
validDownloadHashQ // beginDefinition;

validDownloadHashQ[ name_String, file_String ] :=
    With[ { expected = Lookup[ $vectorDBDownloadHashes, Key @ { name, $vectorDatabases[ name, "Version" ] } ] },
        StringQ @ expected && Quiet @ FileHash[ file, "SHA256", All, "HexString" ] === expected
    ];

validDownloadHashQ // endDefinition;

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
tryUnpackingVectorDatabase // beginDefinition;

tryUnpackingVectorDatabase[ zip_? FileExistsQ ] :=
    Quiet @ With[ { name = FileBaseName @ zip },
        If[ vectorDBNameQ @ name && validDownloadSizeQ[ FileByteCount @ zip, $vectorDBDownloadSizes @ name, None ] && validDownloadHashQ[ name, zip ],
            With[ { res = catchAlways @ unpackVectorDatabase @ zip },
                If[ ! DirectoryQ @ res, DeleteFile @ zip ];
                res
            ],
            DeleteFile @ zip;
            Missing[ "InvalidArchive", zip ]
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
            old = target <> ".old-" <> CreateUUID[ ];
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

setDownloadProgress[ name_String ] := setDownloadProgress[ name, ## ] &;

setDownloadProgress[ name_, as_Association ] := (
    If[ TrueQ @ Positive @ as[ "ByteCountDownloaded" ], $downloadProgress[ name ] = as[ "ByteCountDownloaded" ] ];
    If[ IntegerQ @ as[ "ByteCountTotal" ] && AssociationQ @ $downloadStatus[ name ],
        $downloadStatus[ name, "ByteCountTotal" ] = as[ "ByteCountTotal" ]
    ];
);

setDownloadProgress[ _, ___ ] := Null;

setDownloadProgress // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setDownloadFinished*)
setDownloadFinished // beginDefinition;

setDownloadFinished[ name_String ] := setDownloadFinished[ name, ## ] &;

setDownloadFinished[ name_, as_Association ] /; AssociationQ @ $downloadStatus[ name ] :=
    $downloadStatus[ name, "StatusCode" ] = Lookup[ as, "StatusCode", None ];

setDownloadFinished[ _, ___ ] := Null;

setDownloadFinished // endDefinition;

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
initializeVectorDatabases[ ] := Block[ { $allowDownload = False }, Catch[ getVectorDB /@ $vectorDBNames, $vdbTag ] ];
initializeVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getVectorDB*)
getVectorDB // beginDefinition;

getVectorDB[ name_String ] := Enclose[
    getVectorDB[ name ] = ConfirmMatch[
        Association @ loadVectorDB @ name,
        $$loadedVectorDB,
        "VectorDB"
    ],
    throwInternalFailure
];

getVectorDB // endDefinition;

$$loadedVectorDB = KeyValuePattern @ { "Values" -> { ___String }, "VectorDatabaseObject" -> $$vectorDatabase };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadVectorDB*)
(* Loads a vector database, offering to re-download it if the local copy turns out to be unusable: *)
loadVectorDB // beginDefinition;

loadVectorDB[ name_String ] := Enclose[
    Module[ { loaded },
        (* Resolve the directory first so that any download prompts/messages are not suppressed: *)
        ConfirmBy[ $vectorDBDirectory, DirectoryQ, "RootDirectory" ];
        loaded = Quiet @ catchAlways @ loadVectorDB0 @ name;
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
    Module[ { root, urls },

        root = ConfirmBy[ $vectorDBDirectory, DirectoryQ, "RootDirectory" ];
        urls = $vectorDBDownloadURLs;

        (* Only local downloads can be repaired: *)
        If[ ! localVectorDBDirectoryQ @ root || ! KeyExistsQ[ urls, name ],
            throwFailure[ "VectorDatabaseLoadFailed", name ]
        ];

        If[ ! TrueQ @ $allowDownload, Throw[ Missing[ "DownloadDisabled" ], $vdbTag ] ];
        If[ TrueQ @ $vectorDBDownloadDeclined, Quiet @ throwFailure[ "VectorDatabaseDownloadDeclined" ] ];

        If[ TrueQ @ $promptRedownload && ! confirmRedownload[ "DownloadTypeVectorDatabase", { name }, $vectorDBDownloadSizes @ name ],
            $vectorDBDownloadDeclined = True;
            throwFailure[ "VectorDatabaseDownloadDeclined" ]
        ];

        clearVectorDBCaches @ name;

        Block[ { $promptRedownload = False },
            ConfirmBy[ downloadVectorDatabases[ root, KeyTake[ urls, { name } ] ], DirectoryQ, "Download" ]
        ];

        Replace[
            Quiet @ catchAlways @ loadVectorDB0 @ name,
            Except[ $$loadedVectorDB ] :> throwFailure[ "VectorDatabaseLoadFailed", name ]
        ]
    ],
    throwInternalFailure
];

repairVectorDB // endDefinition;

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
    $vectorDBSearchCache = KeyDrop[ $vectorDBSearchCache, name ];
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
            inVectorDBDirectory @ VectorDatabaseSearch[
                vectorDB,
                embeddingVector,
                { "Index", "Distance" },
                MaxItems -> $maxNeighbors
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
    Null
];

End[ ];
EndPackage[ ];
