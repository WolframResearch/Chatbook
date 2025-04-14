(* ::Section::Closed:: *)
(*Package Header*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
BeginPackage[ "Wolfram`ChatbookVectorDatabaseBuilder`" ];

(* Exported symbols *)
`AddToVectorDatabaseData;
`BuildVectorDatabase;
`ExportVectorDatabaseData;
`GetEmbedding;
`ImportVectorDatabaseData;
`BuildSourceSelector;

Begin[ "`Private`" ];

Needs[ "Developer`"        -> None ];
Needs[ "GeneralUtilities`" -> None ];
Needs[ "Wolfram`Chatbook`" -> None ];

HoldComplete[
    System`CreateVectorDatabase,
    System`VectorDatabaseObject
];

(* Temporary deployment URL: https://www.wolframcloud.com/obj/wolframai-content/VectorDatabases/DocumentationURIs.zip *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Aliases*)
cachedTokenizer    = Wolfram`Chatbook`Common`cachedTokenizer;
ensureDirectory    = GeneralUtilities`EnsureDirectory;
packedArrayQ       = Developer`PackedArrayQ;
readRawJSONString  = Developer`ReadRawJSONString;
readWXFFile        = Developer`ReadWXFFile;
toPackedArray      = Developer`ToPackedArray;
writeRawJSONString = Developer`WriteRawJSONString;
writeWXFFile       = Developer`WriteWXFFile;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Patterns*)
$$vectorDatabase = _VectorDatabaseObject? System`Private`ValidQ;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Vector Databases*)
$defaultVectorDBSourceDirectory = FileNameJoin @ { DirectoryName @ $InputFileName, "SourceData" };
$vectorDBSourceDirectory       := getVectorDBSourceDirectory[ ];
$vectorDBTargetDirectory        = FileNameJoin @ { DirectoryName[ $InputFileName, 3 ], "Assets", "VectorDatabases" };

$incrementalBuildBatchSize = 512;
$dbConnectivity            = 16;
$dbExpansionAdd            = 256;
$dbExpansionSearch         = 2048;
$relativePaths             = Automatic;

$minCompressedVectors = 2^14;
$maxCompressedVectors = 2^18;

$sourceSelectorExcludedNames = {
    "WolframAlphaQueries"
};

$defaultSourceSelectorNames = Complement[
    FileBaseName /@ FileNames[ "*.wl", $defaultVectorDBSourceDirectory ],
    $sourceSelectorExcludedNames
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Embeddings*)
$embeddingDimension        = 384;
$embeddingType             = "Integer8";
$embeddingService          = "Local";
$embeddingModel            = "SentenceBERT";
$embeddingMaxTokens        = 8000;
$maxSnippetLength          = 4000;
$defaultEmbeddingLocation  = FileNameJoin @ { $CacheBaseDirectory, "ChatbookDeveloper", "Embeddings" };
$dataTag                   = "TextLiteral";
$tokenizer                := $tokenizer = cachedTokenizer[ "gpt-4o" ];

$embeddingLocation := $embeddingLocation = Replace[
    PersistentSymbol[ "ChatbookDeveloper/EmbeddingCacheLocation" ],
    Except[ _File | _String ] :> $defaultEmbeddingLocation
];

$embeddingCache = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Vector Databases*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ImportVectorDatabaseData*)
ImportVectorDatabaseData // ClearAll;

ImportVectorDatabaseData[ name_String ] :=
    Enclose @ Module[ { file },
        file = ConfirmBy[ getVectorDBSourceFile @ name, FileExistsQ, "File" ];
        ImportVectorDatabaseData @ File @ file
    ];

ImportVectorDatabaseData[ file_File ] :=
    Enclose @ ConfirmMatch[ jsonlImport @ file, { ___Association? AssociationQ }, "Data" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ExportVectorDatabaseData*)
ExportVectorDatabaseData // ClearAll;

ExportVectorDatabaseData[ name_String, data_List ] :=
    Enclose @ Module[ { dir, file },
        dir  = ConfirmBy[ ensureDirectory @ $vectorDBSourceDirectory, DirectoryQ, "Directory" ];
        file = ConfirmBy[ FileNameJoin @ { dir, name<>".jsonl" }, StringQ, "File" ];
        ExportVectorDatabaseData[ File @ file, data ]
    ];

ExportVectorDatabaseData[ file_File, data0_List ] :=
    Enclose @ Module[ { data },
        data = ConfirmBy[ toDBData @ data0, dbDataQ, "Data" ];
        ConfirmBy[ jsonlExport[ file, data ], FileExistsQ, "Export" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AddToVectorDatabaseData*)
AddToVectorDatabaseData // ClearAll;
AddToVectorDatabaseData // Options = { "Tag" -> "TextLiteral", "Rebuild" -> False };

AddToVectorDatabaseData[ name_String, data_List, opts: OptionsPattern[ ] ] :=
    Enclose @ Module[ { tag, newData, existingData, combined, exported, rebuilt },

        tag          = ConfirmBy[ OptionValue[ "Tag" ], StringQ, "Tag" ];
        newData      = ConfirmBy[ toDBData[ tag, data ], dbDataQ, "NewData" ];
        existingData = ConfirmBy[ ImportVectorDatabaseData @ name, dbDataQ, "ExistingData" ];
        combined     = Union[ existingData, newData ];
        exported     = ConfirmBy[ ExportVectorDatabaseData[ name, combined ], FileExistsQ, "Export" ];

        rebuilt = If[ TrueQ @ OptionValue[ "Rebuild" ],
                      ConfirmBy[ BuildVectorDatabase @ name, $$vectorDatabase, "Rebuild" ],
                      Missing[ "NotAvailable" ]
                  ];

        <| "Exported" -> exported, "Rebuilt" -> rebuilt |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*BuildVectorDatabase*)
BuildVectorDatabase // ClearAll;
BuildVectorDatabase // Options = {
    "Connectivity"    :> $dbConnectivity,
    "ExpansionAdd"    :> $dbExpansionAdd,
    "ExpansionSearch" :> $dbExpansionSearch,
    "RelativePaths"   :> $relativePaths
};

BuildVectorDatabase[ All, opts: OptionsPattern[ ] ] :=
    Block[
        {
            $dbConnectivity    = OptionValue[ "Connectivity"    ],
            $dbExpansionAdd    = OptionValue[ "ExpansionAdd"    ],
            $dbExpansionSearch = OptionValue[ "ExpansionSearch" ],
            $relativePaths     = checkRelativePaths[ OptionValue[ "RelativePaths" ], True ]
        },
        <|
            AssociationMap[ BuildVectorDatabase, FileBaseName /@ getVectorDBSourceFile @ All ],
            "SourceSelector" -> BuildSourceSelector[ ]
        |>
    ];

BuildVectorDatabase[ "SourceSelector", opts: OptionsPattern[ ] ] :=
    Block[
        {
            $dbConnectivity    = OptionValue[ "Connectivity"    ],
            $dbExpansionAdd    = OptionValue[ "ExpansionAdd"    ],
            $dbExpansionSearch = OptionValue[ "ExpansionSearch" ],
            $relativePaths     = checkRelativePaths[ OptionValue[ "RelativePaths" ], True ]
        },
        BuildSourceSelector[ ]
    ];

BuildVectorDatabase[ name_String, opts: OptionsPattern[ ] ] := Enclose[
    Block[
        {
            $dbConnectivity    = OptionValue[ "Connectivity"    ],
            $dbExpansionAdd    = OptionValue[ "ExpansionAdd"    ],
            $dbExpansionSearch = OptionValue[ "ExpansionSearch" ],
            $relativePaths     = checkRelativePaths[ OptionValue[ "RelativePaths" ], True ]
        },
        If[ TrueQ @ $relativePaths,
            ConfirmMatch[ inDBDirectory @ buildVectorDatabase @ name, $$vectorDatabase, "Build" ],
            ConfirmMatch[ buildVectorDatabase @ name, $$vectorDatabase, "Build" ]
        ]
    ]
];

BuildVectorDatabase[ id_, dir_, opts: OptionsPattern[ ] ] := Enclose[
    Block[
        {
            $vectorDBTargetDirectory = ConfirmBy[ GeneralUtilities`EnsureDirectory @ dir, DirectoryQ, "Directory" ],
            $relativePaths           = checkRelativePaths[ OptionValue[ "RelativePaths" ], False ]
        },
        BuildVectorDatabase[ id, opts ]
    ]
];


buildVectorDatabase // ClearAll;

buildVectorDatabase[ name_String ] :=
    Enclose @ Catch @ Module[ { dir, rel, src, db, valueBag, count, n, stream, values, built },

        loadEmbeddingCache[ ];

        dir = ConfirmBy[ ensureDirectory @ { $vectorDBTargetDirectory, name }, DirectoryQ, "Directory" ];

        rel = If[ TrueQ @ $relativePaths,
                  ConfirmBy[ ResourceFunction[ "RelativePath" ][ dir ], DirectoryQ, "Relative" ],
                  dir
              ];

        src = ConfirmBy[ getVectorDBSourceFile @ name, FileExistsQ, "File" ];

        DeleteFile /@ FileNames[ { "*.wxf", "*.usearch" }, dir ];
        ConfirmAssert[ FileNames[ { "*.wxf", "*.usearch" }, dir ] === { }, "ClearedFilesCheck" ];

        db = ConfirmMatch[
            CreateVectorDatabase[
                { },
                name,
                "Database"             -> "USearch",
                WorkingPrecision       -> $embeddingType,
                GeneratedAssetLocation -> rel,
                OverwriteTarget        -> True
            ],
            $$vectorDatabase,
            "Database"
        ];

        ConfirmBy[ setDBDefaults[ dir, name ], FileExistsQ, "SetDBDefaults" ];

        valueBag = Internal`Bag[ ];
        count = ConfirmMatch[ lineCount @ src, _Integer? Positive, "LineCount" ];
        n = 0;
        WithCleanup[
            stream = ConfirmMatch[ OpenRead @ src, _InputStream, "Stream" ],

            withProgress[
                While[
                    NumericArrayQ @ ConfirmMatch[ addBatch[ db, stream, valueBag ], _NumericArray|EndOfFile, "Add" ],
                    n = Internal`BagLength @ valueBag
                ],
                <|
                    "Text"          -> "Building database \""<>name<>"\"",
                    "ElapsedTime"   -> Automatic,
                    "RemainingTime" -> Automatic,
                    "ItemTotal"     :> count,
                    "ItemCurrent"   :> n,
                    "Progress"      :> Automatic
                |>,
                "Delay" -> 0,
                UpdateInterval -> 1
            ];

            saveEmbeddingCache[ ];

            values = Internal`BagPart[ valueBag, All ];

            ConfirmBy[ rewriteDBData[ rel, name ], FileExistsQ, "Rewrite" ];

            built = ConfirmMatch[
                If[ TrueQ @ $relativePaths,
                    VectorDatabaseObject @ File @ FileNameJoin @ { rel, name <> ".wxf" },
                    VectorDatabaseObject[ File @ FileNameJoin @ { dir, name <> ".wxf" }, OverwriteTarget -> True ]
                ],
                $$vectorDatabase,
                "Result"
            ];

            ConfirmAssert[ Length @ values === count, "ValueCount" ];
            ConfirmAssert[ First @ built[ "Dimensions" ] === count, "VectorCount" ];

            ConfirmBy[
                writeWXFFile[ FileNameJoin @ { dir, "Values.wxf" }, values, PerformanceGoal -> "Size" ],
                FileExistsQ,
                "Values"
            ];

            ConfirmBy[
                writeWXFFile[
                    FileNameJoin @ { dir, "EmbeddingInformation.wxf" },
                    <|
                        "Dimension" -> $embeddingDimension,
                        "Type"      -> $embeddingType,
                        "Model"     -> $embeddingModel,
                        "Service"   -> $embeddingService
                    |>
                ],
                FileExistsQ,
                "EmbeddingInformation"
            ],

            Close @ stream
        ];

        ConfirmMatch[ built, $$vectorDatabase, "Result" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inDBDirectory*)
inDBDirectory // ClearAll;
inDBDirectory // Attributes = { HoldFirst };

inDBDirectory[ eval_ ] :=
    WithCleanup[
        SetDirectory @ ensureDirectory @ $vectorDBTargetDirectory,
        eval,
        ResetDirectory[ ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkRelativePaths*)
checkRelativePaths // ClearAll;
checkRelativePaths[ relative: True|False, default_ ] := relative;
checkRelativePaths[ relative_, default: True|False ] := default;
checkRelativePaths[ relative_, default_ ] := True;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setDBDefaults*)
setDBDefaults // ClearAll;
setDBDefaults[ dir_, name_String ] :=
    Enclose @ Module[ { file, data },
        file = ConfirmBy[ FileNameJoin @ { dir, name<>".wxf" }, FileExistsQ, "File" ];
        data = ConfirmBy[ readWXFFile @ file, AssociationQ, "Data" ];
        ConfirmAssert[ AssociationQ @ data[ "VectorDatabaseInfo" ], "InfoCheck" ];
        data[ "VectorDatabaseInfo", "Connectivity" ] = ConfirmBy[ $dbConnectivity, IntegerQ, "Connectivity" ];
        data[ "VectorDatabaseInfo", "ExpansionAdd" ] = ConfirmBy[ $dbExpansionAdd, IntegerQ, "ExpansionAdd" ];
        data[ "VectorDatabaseInfo", "ExpansionSearch" ] = ConfirmBy[ $dbExpansionSearch, IntegerQ, "ExpansionSearch" ];
        ConfirmBy[ writeWXFFile[ file, data ], FileExistsQ, "Export" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addBatch*)
addBatch // ClearAll;

addBatch[ db_VectorDatabaseObject, stream_InputStream, valueBag_Internal`Bag ] :=
    Enclose @ Catch @ Module[ { batch, text, values, embeddings, added },

        batch = ConfirmMatch[
            readJSONLines[ stream, $incrementalBuildBatchSize ],
            { __Association } | EndOfFile,
            "Batch"
        ];

        If[ batch === EndOfFile, Throw @ EndOfFile ];

        $lastBatch = batch;
        text = ConfirmMatch[ batch[[ All, "Text" ]], { __String }, "Text" ];
        values = ConfirmMatch[ batch[[ All, "Value" ]], { __ }, "Values" ];
        embeddings = ConfirmBy[ $lastEmbedding = GetEmbedding @ text, NumericArrayQ, "Embeddings" ];
        ConfirmAssert[ Length @ values === Length @ embeddings, "LengthCheck" ];
        added = Confirm[ $lastAdded = AddToVectorDatabase[ db, embeddings ], "AddToVectorDatabase" ];
        Internal`StuffBag[ valueBag, values, 1 ];
        ConfirmMatch[ added[ "Dimensions" ], { Internal`BagLength @ valueBag, $embeddingDimension }, "DimensionCheck" ];
        embeddings
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*partition*)
partition // ClearAll;

partition[ arr_NumericArray, size_Integer? Positive ] :=
    Module[ { max, steps },
        max = Length @ arr;
        steps = Ceiling[ max / size ];
        Table[ arr[[ size * (i - 1) + 1 ;; Min[ size * i, max ] ]], { i, steps } ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rewriteDBData*)
rewriteDBData // ClearAll;
rewriteDBData[ dir_? DirectoryQ, name_String ] :=
    Enclose @ Module[ { file, data, wxfName, vectorsName, new },
        file = ConfirmBy[ FileNameJoin @ { dir, name<>".wxf" }, FileExistsQ, "File" ];
        data = ConfirmBy[ readWXFFile @ file, AssociationQ, "Data" ];
        wxfName = ConfirmBy[ FileNameTake @ file, StringQ, "WXFName" ];
        vectorsName = ConfirmBy[ name<>"-vectors.usearch", StringQ, "VectorName" ];
        new = ConfirmBy[ createNewDBData[ name, wxfName, vectorsName, data ], AssociationQ, "NewData" ];
        ConfirmBy[ writeWXFFile[ file, new ], FileExistsQ, "Export" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createNewDBData*)
createNewDBData // ClearAll;
createNewDBData[ name_String, wxfName_String, vectorsName_String, data_Association ] :=
    Association[
        data,
        "GeneratedAssetLocation" -> name,
        "Location"               -> File[ name <> "/" <> wxfName     ],
        "VectorDatabase"         -> File[ name <> "/" <> vectorsName ]
    ];

(* TODO: insert info about service, model, etc. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*normalize*)
normalize // ClearAll;
normalize[ vectors_? MatrixQ ] := toPackedArray[ Normalize /@ vectors ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toDBData*)
toDBData // ClearAll;
toDBData[ data_List ] := Reverse @ DeleteDuplicatesBy[ Reverse @ Union[ toDBData0 /@ data ], KeyTake @ { "Text", "Value" } ];
toDBData[ tag_String, data_List ] := Block[ { $dataTag = tag }, toDBData @ data ];

toDBData0 // ClearAll;
toDBData0[ as_Association          ] := KeySort @ trimSnippet @ <| "Tag" -> $dataTag, as |>;
toDBData0[ { text_String, value_ } ] := trimSnippet @ <| "Tag" -> $dataTag, "Text" -> text, "Value" -> value |>;
toDBData0[ text_String -> value_   ] := toDBData0 @ { text, value };
toDBData0[ text_String             ] := toDBData0 @ { text, text  };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*trimSnippet*)
trimSnippet // ClearAll;
trimSnippet[ str_String ] := StringTake[ str, UpTo[ $maxSnippetLength ] ];
trimSnippet[ as: KeyValuePattern[ "Text" -> text_ ] ] := <| as, "Text" -> trimSnippet @ text |>;
trimSnippet[ other_ ] := trimSnippet @ TextString @ other;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dbDataQ*)
dbDataQ // ClearAll;
dbDataQ[ data_List ] := AllTrue[ data, dbDataQ0 ];
dbDataQ[ ___ ] := False;

dbDataQ0 // ClearAll;
dbDataQ0[ KeyValuePattern @ { "Tag" -> _String, "Text" -> _String, "Value" -> _ } ] := True;
dbDataQ0[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*BuildSourceSelector*)
BuildSourceSelector // ClearAll;

BuildSourceSelector[ ] :=
    BuildSourceSelector @ $defaultSourceSelectorNames;

BuildSourceSelector[ names: { ___String } ] := Enclose @ inDBDirectory @
    Module[ { dbs, compressed, newVectors, values, arr, dir, rel, file, db, d, n, count },

        $currentAction = "Getting source databases";
        withProgress[
            dbs = ConfirmBy[ getSourceDatabases @ names, AssociationQ, "Databases" ];
            $currentAction = "Compressing vectors";
            compressed = compressVectors /@ dbs;
            $currentAction = "Packing vectors";
            newVectors = Developer`ToPackedArray @ Flatten[ Values @ compressed, 1 ];
            values = Flatten @ KeyValueMap[ ConstantArray[ #1, Length[ #2 ] ] &, compressed ];
            arr = NumericArray[ newVectors, "Integer8", "ClipAndRound" ],
            <| "Text" :> $currentAction, "ElapsedTime" -> Automatic |>,
            "Delay" -> 0,
            UpdateInterval -> 1
        ];

        dir = ConfirmBy[
            ensureDirectory @ FileNameJoin @ { $vectorDBTargetDirectory, "SourceSelector" },
            DirectoryQ,
            "Directory"
        ];

        rel = ConfirmBy[
            ResourceFunction[ "RelativePath" ][ dir ],
            DirectoryQ,
            "Relative"
        ];

        DeleteFile /@ FileNames[ { "*.wxf", "*.usearch" }, dir ];
        ConfirmAssert[ FileNames[ { "*.wxf", "*.usearch" }, dir ] === { }, "ClearedFilesCheck" ];

        ConfirmMatch[
            CreateVectorDatabase[
                { },
                "SourceSelector",
                "Database"             -> "USearch",
                WorkingPrecision       -> $embeddingType,
                GeneratedAssetLocation -> rel,
                OverwriteTarget        -> True
            ],
            $$vectorDatabase,
            "Database"
        ];

        ConfirmBy[ setDBDefaults[ dir, "SourceSelector" ], FileExistsQ, "SetDBDefaults" ];

        file = ConfirmBy[ FileNameJoin @ { dir, "SourceSelector.wxf" }, FileExistsQ, "File" ];
        db = ConfirmMatch[ VectorDatabaseObject @ File @ file, $$vectorDatabase, "DatabaseReload" ];
        d = $incrementalBuildBatchSize;
        n = 0;
        count = Length @ arr;

        withProgress[
            Do[
                n = i;
                AddToVectorDatabase[ db, arr[[ i + 1 ;; UpTo[ i + d ] ]] ],
                { i, 0, Length @ arr - 1, d }
            ],
            <|
                "Text"          -> "Building SourceSelector vector database",
                "ElapsedTime"   -> Automatic,
                "RemainingTime" -> Automatic,
                "ItemTotal"     :> count,
                "ItemCurrent"   :> n,
                "Progress"      :> Automatic
            |>,
            "Delay" -> 0,
            UpdateInterval -> 1
        ];

        ConfirmBy[ rewriteDBData[ rel, "SourceSelector" ], FileExistsQ, "Rewrite" ];

        ConfirmBy[
            writeWXFFile[ FileNameJoin @ { dir, "Values.wxf" }, values, PerformanceGoal -> "Size" ],
            FileExistsQ,
            "Values"
        ];

        db
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSourceDatabases*)
getSourceDatabases // ClearAll;
getSourceDatabases[ names: { ___String } ] :=
    Enclose @ WithCleanup[
        SetDirectory @ ensureDirectory @ $vectorDBTargetDirectory,
        ConfirmBy[
            AssociationMap[ getSourceDatabase, names ],
            AllTrue @ MatchQ @ $$vectorDatabase,
            "Databases"
        ],
        ResetDirectory[ ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSourceDatabase*)
getSourceDatabase // ClearAll;
getSourceDatabase[ name_String ] := Enclose[
    Module[ { dir, file },
        dir = ConfirmBy[ FileNameJoin @ { $vectorDBTargetDirectory, name }, DirectoryQ, "Directory" ];
        file = ConfirmBy[ FileNameJoin @ { dir, name <> ".wxf" }, FileExistsQ, "File" ];
        ConfirmMatch[ VectorDatabaseObject @ File @ file, $$vectorDatabase, "Database" ]
    ],
    BuildVectorDatabase @ name &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*compressVectors*)
compressVectors // ClearAll;
compressVectors[ db_ ] := compressVectors[ db, Automatic ];
compressVectors[ db_, count_ ] := RandomChoice /@ clusterVectors[ db, count ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clusterVectors*)
clusterVectors // ClearAll;

clusterVectors[ db_ ] :=
    clusterVectors[ db, Automatic ];

clusterVectors[ db: $$vectorDatabase, count_ ] :=
    clusterVectors[ db[ "Vectors" ], count ];

clusterVectors[ vectors_NumericArray, count_ ] :=
    clusterVectors[ DeleteDuplicates @ Normal @ NumericArray[ vectors, "Real64" ], count ];

clusterVectors[ vectors_List, count_ ] :=
    With[ { n = autoClusterCount[ vectors, count ] },
        If[ n === All,
            Developer`ToPackedArray[ List /@ vectors ],
            ResourceFunction[ "PrincipalAxisClustering" ][ vectors, n, Method -> Mean ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*autoClusterCount*)
autoClusterCount // ClearAll;

autoClusterCount[ vectors_, Automatic ] :=
    With[ { n = Length @ vectors },
        If[ n < $minCompressedVectors,
            All,
            Max[ $minCompressedVectors, Min[ $maxCompressedVectors, 2 ^ Floor[ 0.9 * Log2 @ Length @ vectors ] ] ]
        ]
    ];

autoClusterCount[ vectors_, count_ ] :=
    count;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Embeddings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GetEmbedding*)
GetEmbedding // ClearAll;

GetEmbedding[ string_String ] := First[ getEmbeddings @ { string }, $Failed ];
GetEmbedding[ KeyValuePattern[ "Text" -> string_String ] ] := GetEmbedding @ string;
GetEmbedding[ as: { __Association } ] := GetEmbedding @ as[[ All, "Text" ]];

GetEmbedding[ strings: { ___String } ] :=
    Enclose @ Module[ { embeddings, packed },
        embeddings = ConfirmBy[ getEmbeddings @ strings, AssociationQ, "Embeddings" ];
        packed = ConfirmBy[ NumericArray[ Lookup[ embeddings, strings ], "Integer8" ], NumericArrayQ, "Packed" ];
        packed
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getEmbeddings*)
getEmbeddings // ClearAll;
getEmbeddings[ strings0_List ] :=
    Module[ { strings },
        strings = DeleteDuplicates @ strings0;
        setProgress[ "Checking cache for", Length @ strings ];
        withProgress[
            getEmbeddings0 @ strings,
            <|
                "ElapsedTime" -> Automatic,
                "ItemAction"  :> $itemAction,
                "ItemName"    -> "embeddings",
                "ItemTotal"   :> $totalItems,
                "ItemCurrent" :> $currentItem
            |>,
            "OuterUpdateInterval" -> 1,
            UpdateInterval        -> 1
        ]
    ];


getEmbeddings0 // ClearAll;
getEmbeddings0[ strings_List ] :=
    Enclose @ Module[ { notCached },
        notCached = Select[ strings, Function @ PreemptProtect[ $currentItem++; MissingQ @ getCachedEmbedding @ # ] ];
        setProgress[ "Creating", Length @ notCached ];
        Confirm[ getAndCacheEmbeddings @ notCached, "GetAndCacheEmbeddings" ];
        setProgress[ "Checking", Length @ strings ];
        AssociationMap[ Function @ PreemptProtect[ $currentItem++; getCachedEmbedding @ # ], strings ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toByteVector*)
toByteVector // ClearAll;
toByteVector[ vector_ ] := NumericArray[ 127.5 * vector - 0.5, "Integer8", "ClipAndRound" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setProgress*)
setProgress // ClearAll;

setProgress[ text_String, total_Integer ] :=
    setProgress[ text, total, 0 ];

setProgress[ text_String, total_Integer, current_Integer ] := PreemptProtect[
    $itemAction  = text;
    $totalItems  = total;
    $currentItem = current;
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getCachedEmbedding*)
getCachedEmbedding // ClearAll;

getCachedEmbedding[ string_String ] :=
    With[ { embedding = $embeddingCache[ string ] },
        embedding /; NumericArrayQ @ embedding
    ];

getCachedEmbedding[ string_String ] :=
    If[ $embeddingModel === "SentenceBERT",
        Missing[ "NotCached" ],
        getCachedEmbedding[ string, embeddingHash @ string ]
    ];

getCachedEmbedding[ string_String, hash_String ] :=
    Catch @ Module[ { file, vector },
        file = embeddingLocation @ string;
        If[ ! FileExistsQ @ file, Throw @ Missing[ "NotCached" ] ];
        vector = readWXFFile @ file;
        If[ NumericArrayQ @ vector,
            getCachedEmbedding[ string, hash ] = vector,
            Failure[ "BadCachedVector", <| "File" -> file, "Vector" -> vector |> ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAndCacheEmbeddings*)
getAndCacheEmbeddings // ClearAll;
getAndCacheEmbeddings[ strings_List ] := Catch[ FixedPoint[ getAndCacheEmbeddings0, strings ], $tag ];


getAndCacheEmbeddings0 // ClearAll;

getAndCacheEmbeddings0[ { } ] := Throw[ "Done", $tag ];

getAndCacheEmbeddings0[ strings: { __String } ] := Enclose[
    Module[ { notCachedTokens, acc, n, batch, remaining, batchVectors },
        (* FIXME: filter out entries that are too large and issue a warning *)
        notCachedTokens = ConfirmMatch[ tokenCount /@ strings, { __Integer }, "Tokens" ];
        acc = Accumulate @ notCachedTokens;
        n = ConfirmBy[ LengthWhile[ acc, LessThan[ $embeddingMaxTokens ] ], Positive, "Count" ];
        { batch, remaining } = ConfirmMatch[ TakeDrop[ strings, UpTo @ n ], { { __String }, { ___String } }, "Batch" ];
        batchVectors = ConfirmBy[ createEmbeddings @ batch, AssociationQ, "Vectors" ];
        ConfirmAssert[ AllTrue[ batchVectors, NumericArrayQ ], "PackedArrayTest" ];
        If[ remaining === { }, Throw[ "Done", $tag ], remaining ]
    ],
    Throw[ #, $tag ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createEmbeddings*)
createEmbeddings // ClearAll;

createEmbeddings[ strings: { __String } ] /; $embeddingModel === "SentenceBERT" :=
    Catch @ Module[ { vectors, small, meta, pairs },
        $currentItem = If[ IntegerQ @ $currentItem, $currentItem + Length @ strings, Length @ strings ];
        vectors = Quiet @ toPackedArray @ sentenceBERTEmbedding @ strings;
        meta = <| "Strings" -> strings, "Vectors" -> vectors |>;
        If[ ! packedArrayQ @ vectors, Throw @ Failure[ "EmbeddingFailure", meta ] ];
        If[ Length @ vectors =!= Length @ strings, Throw @ Failure[ "EmbeddingShapeFailure", meta ] ];
        small = toByteVector@*Normalize /@ vectors[[ All, 1 ;; $embeddingDimension ]];
        pairs = Transpose @ { strings, small };
        Association[ cacheEmbedding /@ pairs ]
    ];

createEmbeddings[ strings: { __String } ] :=
    Catch @ Module[ { resp, vectors, small, meta, pairs },
        $currentItem = If[ IntegerQ @ $currentItem, $currentItem + Length @ strings, Length @ strings ];
        resp = ServiceExecute[ $embeddingService, "RawEmbedding", { "input" -> strings, "model" -> $embeddingModel } ];
        vectors = Quiet @ toPackedArray @ resp[[ "data", All, "embedding" ]];
        meta = <| "Strings" -> strings, "Response" -> resp, "Vectors" -> vectors |>;
        If[ ! packedArrayQ @ vectors, Throw @ Failure[ "EmbeddingServiceFailure", meta ] ];
        If[ Length @ vectors =!= Length @ strings, Throw @ Failure[ "EmbeddingShapeFailure", meta ] ];
        small = toByteVector@*Normalize /@ vectors[[ All, 1 ;; $embeddingDimension ]];
        pairs = Transpose @ { strings, small };
        Association[ cacheEmbedding /@ pairs ]
    ];

createEmbeddings[ { } ] :=
    <| |>;

createEmbeddings[ string_String ] :=
    First[ createEmbeddings @ { string }, $Failed ];

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
(* ::Subsection::Closed:: *)
(*cacheEmbedding*)
cacheEmbedding // ClearAll;

cacheEmbedding[ string_String, vector_NumericArray ] /; $embeddingModel === "SentenceBERT" := (
    $embeddingCache[ string ] = vector;
    string -> vector
);

cacheEmbedding[ string_String, vector_NumericArray ] :=
    cacheEmbedding[ string, vector, embeddingHash @ string ];

cacheEmbedding[ string_String, vector_NumericArray, hash_String ] :=
    Enclose @ Module[ { file },
        file = ConfirmBy[ embeddingLocation @ string, StringQ, "File" ];
        ensureDirectory @ DirectoryName @ file;
        ConfirmBy[ writeWXFFile[ file, vector ], FileExistsQ, "Export" ];
        ConfirmAssert @ NumericArrayQ @ readWXFFile @ file;
        $embeddingCache[ string ] = vector;
        string -> vector
    ];

cacheEmbedding[ { string_, vector_ } ] :=
    cacheEmbedding[ string, vector ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadEmbeddingCache*)
loadEmbeddingCache // ClearAll;

loadEmbeddingCache[ ] :=
    Enclose @ Catch @ Module[ { hash, file, cached, keys, values },

        hash = ConfirmBy[
            Hash[ { $embeddingModel, $embeddingService, $embeddingDimension, $embeddingType }, "SHA" ],
            IntegerQ,
            "Hash"
        ];

        file = ConfirmBy[
            FileNameJoin @ { $embeddingLocation, "EmbeddingCache_" <> IntegerString[ hash, 36 ] <> ".wxf" },
            StringQ,
            "File"
        ];

        If[ ! AssociationQ @ $embeddingCache, $embeddingCache = <| |> ];

        If[ ! FileExistsQ @ file, Throw @ $embeddingCache ];

        cached = ConfirmBy[ readWXFFile @ file, AssociationQ, "Cached" ];
        keys = ConfirmMatch[ cached[ "Keys" ], { ___String }, "Keys" ];
        values = ConfirmBy[ cached[ "Values" ], NumericArrayQ, "Values" ];

        MapIndexed[ ($embeddingCache[ #1 ] = values[[ First[ #2 ] ]]) &, keys ];
        $embeddingCache
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*saveEmbeddingCache*)
saveEmbeddingCache // ClearAll;

saveEmbeddingCache[ ] :=
    Enclose @ Module[ { hash, file, keys, values },

        loadEmbeddingCache[ ];

        hash = ConfirmBy[
            Hash[ { $embeddingModel, $embeddingService, $embeddingDimension, $embeddingType }, "SHA" ],
            IntegerQ,
            "Hash"
        ];

        file = ConfirmBy[
            FileNameJoin @ { $embeddingLocation, "EmbeddingCache_" <> IntegerString[ hash, 36 ] <> ".wxf" },
            StringQ,
            "File"
        ];

        ConfirmAssert[ AssociationQ @ $embeddingCache, "CacheCheck" ];

        keys = ConfirmMatch[ Keys @ $embeddingCache, { ___String }, "Keys" ];
        values = ConfirmBy[ NumericArray[ Values @ $embeddingCache, $embeddingType ], NumericArrayQ, "Values" ];

        writeWXFFile[ file, <| "Keys" -> keys, "Values" -> values |> ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getNamedEmbeddings*)
getNamedEmbeddings // ClearAll;
getNamedEmbeddings[ name_String, strings_List ] :=
    Enclose @ Module[ { embeddings },
        ConfirmBy[ loadNamedEmbeddingCache @ name, AssociationQ, "LoadCache" ];
        embeddings = ConfirmBy[ getEmbeddings @ strings, AssociationQ, "GetEmbeddings" ];
        ConfirmBy[ saveNamedEmbeddingCache[ name, embeddings ], AssociationQ, "Save" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadNamedEmbeddingCache*)
loadNamedEmbeddingCache // ClearAll;
loadNamedEmbeddingCache[ name_String ] :=
    Enclose @ Catch @ Module[ { file, data },
        file = FileNameJoin @ { $embeddingLocation, name<>".wxf" };
        If[ ! FileExistsQ @ file, Throw @ <| |> ];
        data = ConfirmBy[ readWXFFile @ file, AssociationQ, "Data" ];
        KeyValueMap[ Function[ getCachedEmbedding[ #1, embeddingHash @ #1 ] = #2 ], data ];
        data
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*saveNamedEmbeddingCache*)
saveNamedEmbeddingCache // ClearAll;
saveNamedEmbeddingCache[ name_String, data_Association ] :=
    Enclose @ Module[ { dir, file },
        dir = ConfirmBy[ ensureDirectory @ $embeddingLocation, DirectoryQ, "Directory" ];
        file = FileNameJoin @ { dir, name<>".wxf" };
        ConfirmBy[ writeWXFFile[ file, data ], FileExistsQ, "Export" ];
        data
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*tokenCount*)
tokenCount // ClearAll;
tokenCount[ str_String ] := Enclose[ tokenCount[ str ] = Length @ ConfirmMatch[ $tokenizer @ str, { ___Integer } ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*embeddingLocation*)
embeddingLocation // ClearAll;

embeddingLocation[ string_String ] :=
    embeddingLocation[ string, embeddingHash @ string ];

embeddingLocation[ string_String, hash_String ] :=
    Enclose @ Module[ { dir, file },
        dir  = ConfirmBy[ ensureDirectory @ $embeddingLocation, DirectoryQ, "Directory" ];
        file = ConfirmBy[ FileNameJoin @ { dir, StringTake[ hash, 3 ], hash<>".wxf" }, StringQ, "File" ];
        embeddingLocation[ string ] = file
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*embeddingHash*)
embeddingHash // ClearAll;
embeddingHash[ string_String ] :=
    Enclose @ Module[ { model, service, dimension, hash },
        model     = ConfirmBy[ $embeddingModel    , StringQ , "Model"     ];
        service   = ConfirmBy[ $embeddingService  , StringQ , "Service"   ];
        dimension = ConfirmBy[ $embeddingDimension, IntegerQ, "Dimension" ];
        hash      = ConfirmBy[ Hash[ { string, model, service, dimension }, "SHA", "HexString" ], StringQ, "Hash" ];
        embeddingHash[ string ] = hash
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getVectorDBSourceDirectory*)
getVectorDBSourceDirectory // ClearAll;

getVectorDBSourceDirectory[ ] := Enclose[
    getVectorDBSourceDirectory[ ] = Confirm @ SelectFirst[
        {
            ReleaseHold @ PersistentSymbol[ "ChatbookDeveloper/VectorDatabaseSourceDirectory" ],
            GeneralUtilities`EnsureDirectory @ $defaultVectorDBSourceDirectory
        },
        DirectoryQ,
        $Failed
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getVectorDBSourceFile*)
getVectorDBSourceFile // ClearAll;

getVectorDBSourceFile[ name_String ] :=
    Enclose @ Catch @ Module[ { dir, jsonl, wl, as, url, downloaded },
        dir = ConfirmBy[ getVectorDBSourceDirectory[ ], DirectoryQ, "Directory" ];
        jsonl = FileNameJoin @ { dir, name<>".jsonl" };
        If[ FileExistsQ @ jsonl, Throw @ jsonl ];
        wl = ConfirmBy[ FileNameJoin @ { dir, name<>".wl" }, FileExistsQ, "File" ];
        as = ConfirmBy[ Get @ wl, AssociationQ, "Data" ];
        url = ConfirmMatch[ as[ "Location" ], _String|_CloudObject|_URL, "URL" ];
        downloaded = ConfirmBy[ URLDownload[ url, jsonl ], FileExistsQ, "Download" ];
        ConfirmBy[ jsonl, FileExistsQ, "Result" ]
    ];

getVectorDBSourceFile[ All ] :=
    Enclose @ Module[ { dir, names },
        dir = ConfirmBy[ getVectorDBSourceDirectory[ ], DirectoryQ, "Directory" ];
        names = Union[ FileBaseName /@ FileNames[ { "*.jsonl", "*.wl" }, dir ] ];
        getVectorDBSourceFile /@ names
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withProgress*)
withProgress // ClearAll;
withProgress // Attributes = { HoldFirst };
withProgress[ eval_, a___ ] := Block[ { withProgress = # & }, Progress`EvaluateWithProgress[ eval, a ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*lineCount*)
lineCount // ClearAll;
lineCount[ file_? FileExistsQ ] :=
    Module[ { count, stream },
        Close /@ Streams @ ExpandFileName @ file;
        count = 0;
        WithCleanup[
            stream = OpenRead @ file,
            While[ Skip[ stream, String ] === Null, count++ ],
            Close @ stream
        ];
        count
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readJSONLines*)
readJSONLines // ClearAll;

readJSONLines[ stream_InputStream, n_Integer? Positive ] :=
    Enclose @ Catch @ Module[ { lines, utf8Lines, jsonData },
        lines = ConfirmMatch[ ReadList[ stream, String, n ], { ___String }, "Lines" ];
        If[ lines === { }, Throw @ EndOfFile ];
        utf8Lines = ConfirmMatch[ FromCharacterCode[ ToCharacterCode @ lines, "UTF-8" ], { __String }, "UTF8" ];
        jsonData = ConfirmMatch[ readRawJSONString /@ utf8Lines, { __Association? AssociationQ }, "JSON" ];
        jsonData
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*jsonlImport*)
jsonlImport // ClearAll;
jsonlImport[ file_? FileExistsQ ] :=
    Enclose @ Module[ { lines, fromJSON },
        lines    = ConfirmMatch[ readLines @ file, { ___String }, "Lines" ];
        fromJSON = ConfirmBy[ readRawJSONString @ #, Not@*FailureQ, "JSON" ] &;
        ConfirmMatch[ fromJSON /@ lines, { Except[ _? FailureQ ]... }, "Data" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*jsonlExport*)
jsonlExport // ClearAll;
jsonlExport[ file_, data_List ] :=
    Enclose @ Module[ { toJSON, lines },
        toJSON = ConfirmBy[ writeRawJSONString[ #, "Compact" -> True ], StringQ, "JSON" ] &;
        lines  = ConfirmMatch[ toJSON /@ data, { ___String? StringQ }, "Lines" ];
        ConfirmBy[ writeLines[ file, lines ], FileExistsQ, "Export" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readLines*)
readLines // ClearAll;
readLines[ file_ ] := Enclose @ StringSplit[ ConfirmBy[ readString @ file, StringQ, "String" ], "\n" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeLines*)
writeLines // ClearAll;
writeLines[ file_, lines: { ___String } ] := writeString[ file, StringRiffle[ lines, "\n" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readString*)
readString // ClearAll;
readString[ file_ ] :=
    Enclose @ Module[ { bytes },
        bytes = ConfirmBy[ readByteArray @ file, ByteArrayQ, "Bytes" ];
        ConfirmBy[ Check[ ByteArrayToString @ bytes, $Failed ], StringQ, "String" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeString*)
writeString // ClearAll;
writeString[ file_, string_String ] :=
    Enclose @ Module[ { bytes },
        bytes = ConfirmBy[ Check[ StringToByteArray @ string, $Failed ], ByteArrayQ, "Bytes" ];
        ConfirmBy[ writeByteArray[ file, bytes ], FileExistsQ, "Write" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readByteArray*)
readByteArray // ClearAll;
readByteArray[ file_ ] :=
    Enclose @ WithCleanup[
        Quiet @ Close @ file,
        ConfirmBy[ Replace[ ReadByteArray @ file, EndOfFile :> ByteArray @ { } ], ByteArrayQ ],
        Quiet @ Close @ file
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeByteArray*)
writeByteArray // ClearAll;
writeByteArray[ file_, bytes_ByteArray ] :=
    Enclose @ WithCleanup[
        Quiet @ Close @ file,
        ConfirmBy[ BinaryWrite[ file, bytes ], FileExistsQ ],
        Quiet @ Close @ file
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
(* :!CodeAnalysis::EndBlock:: *)