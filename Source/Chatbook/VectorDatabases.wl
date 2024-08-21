(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`VectorDatabases`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

HoldComplete[
    System`VectorDatabaseObject,
    System`VectorDatabaseSearch
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$vectorDBNames = { "DocumentationURIs", "WolframAlphaQueries" };

$embeddingDimension      = 256;
$maxNeighbors            = 50;
$maxEmbeddingDistance    = 150.0;
$embeddingService        = "OpenAI"; (* FIXME *)
$embeddingModel          = "text-embedding-3-small";
$embeddingAuthentication = Automatic; (* FIXME *)

$smallContextMessageCount        = 3;
$smallContextStringLength        = 8000;
$conversationVectorSearchPenalty = 16.0;

$relatedQueryCount = 5;
$relatedDocsCount  = 20;
$querySampleCount  = 10;

$relevantFileCount = 3;
$maxExtraFiles     = 20;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Remote Content Locations*)
$documentationSnippetBaseURL = "https://www.wolframcloud.com/obj/wolframai-content/DocumentationSnippets/Text";
$baseVectorDatabasesURL      = "https://www.wolframcloud.com/obj/wolframai-content/VectorDatabases";

(* TODO: these will be moved to the data repository: *)
$vectorDBDownloadURLs = AssociationMap[ $baseVectorDatabasesURL <> "/" <> # <> ".zip" &, $vectorDBNames ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paths*)
$pacletVectorDBDirectory := FileNameJoin @ { $thisPaclet[ "Location" ], "Assets/VectorDatabases" };
$localVectorDBDirectory  := FileNameJoin @ { ExpandFileName @ LocalObject @ $LocalBase, "Chatbook/VectorDatabases" };

(* TODO: need versioned URLs and paths *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Argument Patterns*)
$$vectorDatabase = _VectorDatabaseObject? System`Private`ValidQ;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cache*)
$vectorDBSearchCache = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedWolframAlphaQueries*)
RelatedWolframAlphaQueries // beginDefinition;

GeneralUtilities`SetUsage[ RelatedWolframAlphaQueries, "\
RelatedWolframAlphaQueries[\"string$\"] gives a list of Wolfram|Alpha queries that are semantically related to the \
conversational-style question specified by \"string$\".
RelatedWolframAlphaQueries[All] gives the full list of available Wolfram|Alpha sample queries." ];

RelatedWolframAlphaQueries[ prompt: _String | { ___String } ] :=
    catchMine @ RelatedWolframAlphaQueries[ prompt, Automatic ];

RelatedWolframAlphaQueries[ prompt: _String | { ___String }, Automatic ] := catchMine @ Enclose[
    ConfirmMatch[ vectorDBSearch[ "WolframAlphaQueries", prompt, "Values" ], { ___String }, "Queries" ],
    throwInternalFailure
];

RelatedWolframAlphaQueries[ prompt_, UpTo[ n_Integer ] ] :=
    RelatedWolframAlphaQueries[ prompt, n ];

RelatedWolframAlphaQueries[ prompt_, n_Integer ] := catchMine @ Enclose[
    ConfirmMatch[ Take[ RelatedWolframAlphaQueries[ prompt, Automatic ], UpTo @ n ], { ___String }, "Queries" ],
    throwInternalFailure
];

RelatedWolframAlphaQueries[ All ] := catchMine @ $uniqueWAQueries;

RelatedWolframAlphaQueries[ args___ ] := catchMine @ throwFailure[
    "InvalidArguments",
    RelatedWolframAlphaQueries,
    HoldForm @ RelatedWolframAlphaQueries @ args
];

RelatedWolframAlphaQueries // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedDocumentation*)
RelatedDocumentation // beginDefinition;

GeneralUtilities`SetUsage[ RelatedDocumentation, "\
RelatedDocumentation[\"string$\"] gives a list of documentation URIs that are semantically related to the \
conversational-style question specified by \"string$\".
RelatedDocumentation[All] gives the full list of available documentation URIs." ];

RelatedDocumentation[ prompt_ ] := catchMine @ RelatedDocumentation[ prompt, Automatic ];
RelatedDocumentation[ prompt_, Automatic ] := catchMine @ RelatedDocumentation[ prompt, "URIs" ];
RelatedDocumentation[ prompt_, count: _Integer | UpTo[ _Integer ] ] := RelatedDocumentation[ prompt, Automatic, count ];
RelatedDocumentation[ prompt_, property_ ] := catchMine @ RelatedDocumentation[ prompt, property, Automatic ];
RelatedDocumentation[ prompt_, Automatic, count_ ] := RelatedDocumentation[ prompt, "URIs", count ];

RelatedDocumentation[ prompt: _String | { ___String }, "URIs", Automatic ] := catchMine @ Enclose[
    ConfirmMatch[ vectorDBSearch[ "DocumentationURIs", prompt, "Values" ], { ___String }, "Queries" ],
    throwInternalFailure
];

RelatedDocumentation[ All, "URIs", Automatic ] := catchMine @ Enclose[
    Union @ ConfirmMatch[ vectorDBSearch[ "DocumentationURIs", All ], { __String }, "QueryList" ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, "Snippets", Automatic ] := catchMine @ Enclose[
    ConfirmMatch[
        DeleteMissing[ makeDocSnippets @ vectorDBSearch[ "DocumentationURIs", prompt, "Values" ] ],
        { ___String },
        "Snippets"
    ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, property_, UpTo[ n_Integer ] ] :=
    catchMine @ RelatedDocumentation[ prompt, property, n ];

RelatedDocumentation[ prompt_, property_, n_Integer ] := catchMine @ Enclose[
    Take[ ConfirmMatch[ RelatedDocumentation[ prompt, property, Automatic ], { ___String } ], UpTo @ n ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, property: "Results"|"Values"|"EmbeddingVector"|All, n_Integer ] := catchMine @ Enclose[
    Take[ ConfirmBy[ vectorDBSearch[ "DocumentationURIs", prompt, property ], ListQ, "Results" ], UpTo @ n ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, property: "Index"|"Distance", n_Integer ] := catchMine @ Enclose[
    Lookup[
        Take[
            ConfirmMatch[ RelatedDocumentation[ prompt, "Results", n ], { KeyValuePattern[ property -> _ ]... }, "Results" ],
            UpTo @ n
        ],
        property
    ],
    throwInternalFailure
];

RelatedDocumentation[ args___ ] := catchMine @ throwFailure[
    "InvalidArguments",
    RelatedDocumentation,
    HoldForm @ RelatedDocumentation @ args
];

RelatedDocumentation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Vector Database Utilities*)
$vectorDBDirectory := getVectorDBDirectory[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getVectorDBDirectory*)
getVectorDBDirectory // beginDefinition;

getVectorDBDirectory[ ] := Enclose[
    $vectorDBDirectory = SelectFirst[
        {
            $pacletVectorDBDirectory,
            $localVectorDBDirectory
        },
        vectorDBDirectoryQ,
        (* TODO: need a version of this that prompts the user with a dialog asking them to download *)
        ConfirmBy[ downloadVectorDatabases[ ], vectorDBDirectoryQ, "Downloaded" ]
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
    Module[ { name, existsQ, expected },
        name     = ConfirmBy[ FileBaseName @ dir, StringQ, "Name" ];
        existsQ  = FileExistsQ @ FileNameJoin @ { dir, # } &;
        expected = { name <> ".wxf", "Values.wxf", name <> "-vectors.usearch" };
        TrueQ @ AllTrue[ expected, existsQ ]
    ],
    throwInternalFailure
];

vectorDBDirectoryQ0[ _ ] := False;

vectorDBDirectoryQ0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*downloadVectorDatabases*)
downloadVectorDatabases // beginDefinition;

downloadVectorDatabases[ ] :=
    downloadVectorDatabases[ $localVectorDBDirectory, $vectorDBDownloadURLs ];

downloadVectorDatabases[ dir0_, urls_Association ] := Enclose[
    Module[ { names, sizes, dir, tasks },

        dir = ConfirmBy[ GeneralUtilities`EnsureDirectory @ dir0, DirectoryQ, "Directory" ];
        names = ConfirmMatch[ Keys @ urls, { __String }, "Names" ];
        sizes = ConfirmMatch[ getDownloadSize /@ Values @ urls, { __? Positive }, "Sizes" ];

        $downloadProgress = AssociationMap[ 0 &, names ];
        $progressText = "Downloading semantic search indices\[Ellipsis]";
        Progress`EvaluateWithProgress[
            tasks = ConfirmMatch[ KeyValueMap[ downloadVectorDatabase @ dir, urls ], { __TaskObject }, "Download" ];
            ConfirmMatch[ taskWait @ tasks, { __TaskObject }, "TaskWait" ];
            $progressText = "Unpacking files\[Ellipsis]";
            ConfirmBy[ unpackVectorDatabases @ dir, DirectoryQ, "Unpacked" ],
            With[ { s = Total @ sizes },
                <|
                    "Text"             :> $progressText,
                    "ElapsedTime"      -> Automatic,
                    "RemainingTime"    -> Automatic,
                    (* "ByteCountCurrent" :> Total @ $downloadProgress,
                    "ByteCountTotal"   -> Total @ sizes, *)
                    "Progress"         :> Total @ $downloadProgress / s
                |>
            ]
        ]
    ],
    throwInternalFailure
];

downloadVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getDownloadSize*)
getDownloadSize // beginDefinition;
getDownloadSize[ url_String ] := getDownloadSize @ CloudObject @ url;
getDownloadSize[ obj_CloudObject ] := FileByteCount @ obj;
getDownloadSize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unpackVectorDatabases*)
unpackVectorDatabases // beginDefinition;
unpackVectorDatabases[ dir_? DirectoryQ ] := unpackVectorDatabases[ dir, FileNames[ "*.zip", dir ] ];
unpackVectorDatabases[ dir_, zips: { __String } ] := unpackVectorDatabases[ dir, zips, unpackVectorDatabase /@ zips ];
unpackVectorDatabases[ dir_, zips_, extracted: { { __String }.. } ] := dir;
unpackVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unpackVectorDatabase*)
unpackVectorDatabase // beginDefinition;

unpackVectorDatabase[ zip_String? FileExistsQ ] := Enclose[
    Module[ { root, dir },
        root = ConfirmBy[ DirectoryName @ zip, DirectoryQ, "RootDirectory" ];
        dir = ConfirmBy[ GeneralUtilities`EnsureDirectory @ { root, FileBaseName @ zip }, DirectoryQ, "Directory" ];
        ConfirmMatch[ ExtractArchive[ zip, dir, OverwriteTarget -> True ], { __? FileExistsQ }, "Extracted" ]
    ],
    throwInternalFailure
];

unpackVectorDatabase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*taskWait*)
taskWait // beginDefinition;
taskWait[ tasks_List ] := taskWait /@ tasks;
taskWait[ task_TaskObject ] := taskWait[ task, task[ "TaskStatus" ] ];
taskWait[ task_TaskObject, "Removed" ] := task;
taskWait[ task_TaskObject, _ ] := TaskWait @ task;
taskWait // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadVectorDatabase*)
downloadVectorDatabase // beginDefinition;

downloadVectorDatabase[ dir_ ] :=
    downloadVectorDatabase[ dir, ## ] &;

downloadVectorDatabase[ dir_, name_String, url_String ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ FileNameJoin @ { dir, name<>".zip" }, StringQ, "File" ];
        ConfirmMatch[
            URLDownloadSubmit[
                url,
                file,
                HandlerFunctions     -> <| "TaskProgress" -> setDownloadProgress @ name |>,
                HandlerFunctionsKeys -> { "ByteCountDownloaded" }
            ],
            _TaskObject,
            "Task"
        ]
    ],
    throwInternalFailure
];

downloadVectorDatabase // endDefinition;

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
initializeVectorDatabases[ ] := getVectorDB /@ $vectorDBNames;
initializeVectorDatabases // endDefinition;

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

vectorDBSearch[ dbName_String, prompt_String ] :=
    vectorDBSearch[ dbName, prompt, All ];

vectorDBSearch[ dbName_String, All ] :=
    vectorDBSearch[ dbName, All, "Values" ];

vectorDBSearch[ dbName_String, "", All ] := <|
    "EmbeddingVector" -> None,
    "SearchData"      -> Missing[ "NoInput" ],
    "Values"          -> { }
|>;

vectorDBSearch[ dbName_String, prompt_String, All ] :=
    With[ { result = $vectorDBSearchCache[ dbName, prompt ] },
        result /; AssociationQ @ result
    ];

vectorDBSearch[ dbName_String, prompt_String, All ] := Enclose[
    Module[ { vectorDBInfo, vectorDB, allValues, embeddingVector, close, indices, distances, values, data, result },

        vectorDBInfo    = ConfirmBy[ getVectorDB @ dbName, AssociationQ, "VectorDBInfo" ];
        vectorDB        = ConfirmMatch[ vectorDBInfo[ "VectorDatabaseObject" ], $$vectorDatabase, "VectorDatabase" ];
        allValues       = ConfirmBy[ vectorDBInfo[ "Values" ], ListQ, "Values" ];
        embeddingVector = ConfirmMatch[ getEmbedding @ prompt, { __Real }, "EmbeddingVector" ];

        close = ConfirmMatch[
            inVectorDBDirectory @ VectorDatabaseSearch[
                vectorDB,
                embeddingVector,
                { "Index", "Distance" },
                MaxItems -> $maxNeighbors
            ],
            { ___Association },
            "PositionsAndDistances"
        ];

        indices   = ConfirmMatch[ close[[ All, "Index"    ]], { ___Integer }, "Indices"   ];
        distances = ConfirmMatch[ close[[ All, "Distance" ]], { ___Real    }, "Distances" ];

        values    = ConfirmBy[ allValues[[ indices ]], ListQ, "Values" ];

        ConfirmAssert[ Length @ indices === Length @ distances === Length @ values, "LengthCheck" ];

        data = MapApply[
            <| "Value" -> #1, "Index" -> #2, "Distance" -> #3 |> &,
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

vectorDBSearch[ dbName_String, prompt_String, key_String ] := Enclose[
    Lookup[ ConfirmBy[ vectorDBSearch[ dbName, prompt, All ], AssociationQ, "Result" ], key ],
    throwInternalFailure
];

vectorDBSearch[ dbName_String, prompt_String, keys: { ___String } ] := Enclose[
    KeyTake[ ConfirmBy[ vectorDBSearch[ dbName, prompt, All ], AssociationQ, "Result" ], keys ],
    throwInternalFailure
];

vectorDBSearch[ dbName_String, prompts: { ___String }, prop_ ] :=
    AssociationMap[ vectorDBSearch[ dbName, #, prop ] &, prompts ];

vectorDBSearch[ dbName_String, All, "Values" ] := Enclose[
    Module[ { vectorDBInfo },
        vectorDBInfo = ConfirmBy[ getVectorDB @ dbName, AssociationQ, "VectorDB" ];
        ConfirmBy[ vectorDBInfo[ "Values" ], ListQ, "Values" ]
    ],
    throwInternalFailure
];

vectorDBSearch[ dbName_String, messages: { __Association }, prop: "Values"|"Results" ] := Enclose[
    Catch @ Module[ { conversationString, lastMessageString, conversationResults, lastMessageResults, combined },

        conversationString = ConfirmBy[ getSmallContextString @ messages, StringQ, "ConversationString" ];
        lastMessageString = ConfirmBy[ getSmallContextString @ { Last @ messages }, StringQ, "LastMessageString" ];

        If[ conversationString === "" || lastMessageString === "", Throw @ { } ];

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

        combined = SortBy[ Join[ conversationResults, lastMessageResults ], Lookup[ "Distance" ] ];

        If[ prop === "Results",
            combined,
            DeleteDuplicates[ Lookup[ "Value" ] /@ combined ]
        ]
    ],
    throwInternalFailure
];

vectorDBSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cacheVectorDBResult*)
cacheVectorDBResult // beginDefinition;

cacheVectorDBResult[ dbName_String, prompt_String, data_Association ] := (
    If[ ! AssociationQ @ $vectorDBSearchCache, $vectorDBSearchCache = <| |> ];
    If[ ! AssociationQ @ $vectorDBSearchCache[ dbName ], $vectorDBSearchCache[ dbName ] = <| |> ];
    $vectorDBSearchCache[ dbName, prompt ] = data
);

cacheVectorDBResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getEmbedding*)
getEmbedding // beginDefinition;

getEmbedding[ string_String ] := Enclose[
    Catch @ Module[ { resp, vector },

        resp = ConfirmBy[
            setServiceCaller @ ServiceExecute[
                $embeddingService,
                "RawEmbedding",
                { "input" -> string, "model" -> $embeddingModel },
                Authentication -> $embeddingAuthentication
            ],
            AssociationQ,
            "EmbeddingResponse"
        ];

        vector = ConfirmBy[
            Developer`ToPackedArray @ Flatten @ resp[[ "data", All, "embedding" ]],
            Developer`PackedArrayQ,
            "PackedArray"
        ];

        getEmbedding[ string ] = ConfirmBy[
            toTinyVector @ vector,
            Developer`PackedArrayQ,
            "TinyVector"
        ]
    ],
    throwInternalFailure
];

getEmbedding // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toTinyVector*)
toTinyVector // beginDefinition;
toTinyVector[ v_ ] := 127.5 * Normalize @ v[[ 1;;$embeddingDimension ]] - 0.5;
toTinyVector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt Generation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*insertVectorDBPrompts*)
insertVectorDBPrompts // beginDefinition;

insertVectorDBPrompts[ messages_List, settings_Association ] := Enclose[
    Module[
        {
            conversation, relatedQueries, relatedDocs,
            randomQueries, queries, docSnippets, bestDocPage, docString,
            querySampleString, relatedDocsString
        },

        conversation = ConfirmMatch[ makeChatTranscript @ messages, { __Association }, "Conversation" ];

        relatedQueries = ConfirmMatch[
            Take[ vectorDBSearch[ "WolframAlphaQueries", conversation, "Values" ], UpTo[ $relatedQueryCount ] ],
            { ___String },
            "Queries"
        ];

        relatedDocs = ConfirmMatch[
            Take[ vectorDBSearch[ "DocumentationURIs", conversation, "Values" ], UpTo[ $relatedDocsCount ] ],
            { ___String },
            "Documentation"
        ];

        randomQueries = ConfirmMatch[ RandomSample[ $uniqueWAQueries, $querySampleCount ], { ___String }, "Random" ];
        queries = Take[ Join[ relatedQueries, randomQueries ], UpTo[ $querySampleCount ] ];

        docSnippets = ConfirmMatch[
            DeleteMissing[ makeDocSnippets @ relatedDocs ],
            { ___String },
            "DocumentationSnippets"
        ];

        bestDocPage = selectBestDocumentationPages[ messages, relatedDocs ];
        docString = If[ StringQ @ bestDocPage, bestDocPage, StringRiffle[ docSnippets, "\n---\n" ] ];

        querySampleString = $querySampleStringHeader <> StringRiffle[ queries, "\n" ];
        relatedDocsString = $relatedDocsStringHeader <> docString;

        $lastVectorDBPrompts = <|
            "Queries"       -> querySampleString,
            "Documentation" -> relatedDocsString
        |>;

        (* FIXME: implement as a prompt generator instead: *)
        stringReplaceSystemMessage[
            messages,
            {
                "$$SAMPLE_WL_QUERIES$$"   :> querySampleString,
                "$$SAMPLE_DOC_SNIPPETS$$" :> relatedDocsString
            }
        ]
    ],
    throwInternalFailure
];

insertVectorDBPrompts // endDefinition;

$querySampleStringHeader = "\
The Wolfram Alpha tool can accept a wide variety of inputs. \
Here are some example queries that would work in place of <topic> to give you a sense of what it can do:

";

$relatedDocsStringHeader = "\
Here are some Wolfram documentation snippets that might be helpful:

";


$uniqueWAQueries := Enclose[
    $uniqueWAQueries = Union @ ConfirmMatch[ vectorDBSearch[ "WolframAlphaQueries", All ], { __String }, "QueryList" ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectBestDocumentationPages*)
selectBestDocumentationPages // beginDefinition;

selectBestDocumentationPages[ messages_List, { } ] :=
    Missing[ "NotAvailable" ];

selectBestDocumentationPages[ messages_List, relatedDocs0: { __String } ] := Enclose[
    Catch @ Module[ { relatedDocs, snippets, transcript, prompt, response, pages },
        relatedDocs = Take[ relatedDocs0, UpTo[ 10 ] ];
        If[ relatedDocs === { }, Throw @ Missing[ "NotAvailable" ] ];
        snippets = StringRiffle[ makeDocSnippets @ relatedDocs, "\n\n---\n\n" ];
        transcript = ConfirmBy[ getSmallContextString @ messages, StringQ, "Transcript" ];

        prompt = ConfirmBy[
            TemplateApply[ $bestDocumentationPrompt, <| "Snippets" -> snippets, "Transcript" -> transcript |> ],
            StringQ,
            "Prompt"
        ];

        response = StringTrim @ ConfirmBy[ llmSynthesize @ prompt, StringQ, "Response" ];
        pages = makeDocSnippets @ Join[ StringCases[ response, relatedDocs ], Take[ relatedDocs, UpTo[ 3 ] ] ];

        If[ pages === { },
            Missing[ "NotAvailable" ],
            StringRiffle[ pages, "\n\n---\n\n" ]
        ]
    ],
    throwInternalFailure
];

selectBestDocumentationPages // endDefinition;


$bestDocumentationPrompt = StringTemplate[ "\
Your task is to read a chat transcript between a user and assistant, and then select the most relevant \
Wolfram Language documentation snippets that could help the assistant answer the user's latest message. \
Each snippet is uniquely identified by a URI (always starts with 'paclet:'). \

Here are the available documentation snippets to choose from:

%%Snippets%%

---

Here is the chat transcript:

%%Transcript%%

Choose up to 5 documentation snippets that would help answer the user's MOST RECENT message. \
Respond only with the corresponding URIs of the snippets and nothing else. \
If there are no relevant pages, respond with just the string \"none\"\
", Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeDocSnippets*)
makeDocSnippets // beginDefinition;

makeDocSnippets[ uris0: { ___String } ] := Enclose[
    Module[ { uris, data, snippets, strings },
        uris = DeleteDuplicates @ uris0;
        data = ConfirmBy[ getDocumentationSnippetData @ uris, AssociationQ, "Data" ];
        snippets = ConfirmMatch[ Values @ data, { ___Association }, "Snippets" ];
        strings = ConfirmMatch[ Lookup[ "String" ] /@ snippets, { ___String }, "Strings" ];
        strings
    ],
    throwInternalFailure
];

makeDocSnippets[ uri_String ] :=
    First @ makeDocSnippets @ { uri };

makeDocSnippets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stringReplaceSystemMessage*)
stringReplaceSystemMessage // beginDefinition;

stringReplaceSystemMessage[
    { sysMessage: KeyValuePattern @ { "Role" -> "System", "Content" -> content_ }, messages___ },
    rules_
] := {
    <| sysMessage, "Content" -> (content /. s_String :> RuleCondition @ StringReplace[ s, rules ]) |>,
    messages
};

stringReplaceSystemMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSmallContextString*)
getSmallContextString // beginDefinition;

getSmallContextString[ messages0: { ___Association } ] := Enclose[
    Catch @ Module[ { messages, recent, strings, string },
        messages = ConfirmMatch[ makeChatTranscript @ messages0, { ___Association }, "Messages" ];
        If[ messages === { }, Throw[ "" ] ];
        recent = revertMultimodalContent @ Reverse @ Take[ Reverse @ messages, UpTo[ $smallContextMessageCount ] ];
        strings = ConfirmMatch[ recent[[ All, "Content" ]], { __String }, "Strings" ];
        string = StringRiffle[ strings, "\n\n" ];
        If[ StringLength @ string > $smallContextStringLength,
            StringTake[ string, { -$smallContextStringLength, -1 } ],
            string
        ]
    ],
    throwInternalFailure
];

getSmallContextString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Documentation Snippets*)
$documentationSnippets = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getDocumentationSnippetData*)
getDocumentationSnippetData // beginDefinition;

getDocumentationSnippetData[ { } ] := <| |>;

getDocumentationSnippetData[ uris: { __String } ] := Enclose[
    Module[ { cached, missing },

        cached = ConfirmBy[
            AssociationMap[ getCachedDocumentationSnippet, uris ],
            AllTrue @ MatchQ[ _Missing | KeyValuePattern[ "String" -> _String ] ],
            "Cached"
        ];

        missing = ConfirmMatch[
            Union[ First /@ StringSplit[ Keys @ Select[ cached, MissingQ ], "#" ] ],
            { ___String },
            "Missing"
        ];

        fetchDocumentationSnippets @ missing;

        ConfirmBy[
            AssociationMap[ getCachedDocumentationSnippet, uris ],
            AllTrue @ MatchQ[ KeyValuePattern[ "String" -> _String ] ],
            "Result"
        ]
    ],
    throwInternalFailure
];

getDocumentationSnippetData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getCachedDocumentationSnippet*)
getCachedDocumentationSnippet // beginDefinition;
getCachedDocumentationSnippet[ uri_String ] := getCachedDocumentationSnippet @ StringSplit[ uri, "#" ];
getCachedDocumentationSnippet[ { base_String } ] := getCachedDocumentationSnippet @ { base, None };
getCachedDocumentationSnippet[ { base_String, fragment_ } ] := $documentationSnippets[ base, fragment ];
getCachedDocumentationSnippet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fetchDocumentationSnippets*)
fetchDocumentationSnippets // beginDefinition;

fetchDocumentationSnippets[ { } ] := { };

fetchDocumentationSnippets[ uris: { __String } ] :=
    Module[ { $results, tasks },
        $results = AssociationMap[ <| "URI" -> #1 |> &, uris ];
        tasks = fetchDocumentationSnippets0 @ $results /@ uris;
        TaskWait @ tasks;
        processDocumentationSnippetResults @ $results
    ];

fetchDocumentationSnippets // endDefinition;


fetchDocumentationSnippets0 // beginDefinition;
fetchDocumentationSnippets0 // Attributes = { HoldFirst };

fetchDocumentationSnippets0[ $results_ ] :=
    fetchDocumentationSnippets0[ $results, # ] &;

fetchDocumentationSnippets0[ $results_, uri_String ] := Enclose[
    Module[ { url, setResult, task },
        url = ConfirmBy[ toDocSnippetURL @ uri, StringQ, "URL" ];
        setResult = Function[ $results[ uri ] = <| $results @ uri, # |> ];

        task = URLSubmit[
            url,
            HandlerFunctions -> <|
                "BodyReceived"     -> setResult,
                "ConnectionFailed" -> Function[ $results[ uri ] = <| $results @ uri, # |> ]
            |>,
            HandlerFunctionsKeys -> { "BodyByteArray", "StatusCode", "Headers", "ContentType", "Cookies" }
        ];

        $results[ uri, "URL"  ] = url;
        $results[ uri, "Task" ] = task
    ],
    throwInternalFailure
];

fetchDocumentationSnippets0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toDocSnippetURL*)
toDocSnippetURL // beginDefinition;

toDocSnippetURL[ uri_String ] /; StringStartsQ[ uri, "paclet:" ] :=
    URLBuild @ { $documentationSnippetBaseURL, StringDelete[ uri, StartOfString~~"paclet:" ] <> ".wxf" };

toDocSnippetURL[ uri_String ] :=
    toDocSnippetURL0 @ URLParse[ uri, { "Domain", "Path" } ];

toDocSnippetURL // endDefinition;


toDocSnippetURL0 // beginDefinition;

toDocSnippetURL0[ { "resources.wolframcloud.com", { "", repo_String, "resources", name_String } } ] :=
    URLBuild @ { $documentationSnippetBaseURL, "Resources", repo, name <> ".wxf" };

toDocSnippetURL0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processDocumentationSnippetResults*)
processDocumentationSnippetResults // beginDefinition;
processDocumentationSnippetResults[ results_Association ] := processDocumentationSnippetResult /@ results;
processDocumentationSnippetResults // endDefinition;

(* TODO: retry failed results *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processDocumentationSnippetResult*)
processDocumentationSnippetResult // beginDefinition;

processDocumentationSnippetResult[ as_Association ] :=
    processDocumentationSnippetResult[ as, as[ "BodyByteArray" ], as[ "StatusCode" ] ];

processDocumentationSnippetResult[ as_, bytes_ByteArray, 200 ] :=
    processDocumentationSnippetResult[ as, Quiet @ Developer`ReadWXFByteArray @ bytes ];

processDocumentationSnippetResult[ as_, data_List ] :=
    Association[
        makeCombinedSnippet @ data,
        cacheDocumentationSnippetResult /@ data
    ];

processDocumentationSnippetResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCombinedSnippet*)
makeCombinedSnippet // beginDefinition;

makeCombinedSnippet[ { data_Association, ___ } ] := makeCombinedSnippet @ data;

makeCombinedSnippet[ data_Association ] := Enclose[
    Module[ { uri, base },
        uri = ConfirmBy[ data[ "URI" ], StringQ, "URI" ];
        base = ConfirmBy[ First @ StringSplit[ uri, "#" ], StringQ, "Base" ];
        cacheDocumentationSnippetResult[ { base, None }, data ]
    ],
    throwInternalFailure
];

makeCombinedSnippet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cacheDocumentationSnippetResult*)
cacheDocumentationSnippetResult // beginDefinition;

cacheDocumentationSnippetResult[ as_Association ] :=
    cacheDocumentationSnippetResult[ as[ "URI" ], as ];

cacheDocumentationSnippetResult[ uri_String, as_Association ] :=
    uri -> cacheDocumentationSnippetResult[ StringSplit[ uri, "#" ], as ];

cacheDocumentationSnippetResult[ { base_String, fragment: _String|None }, as_Association ] :=
    If[ AssociationQ @ $documentationSnippets[ base ],
        $documentationSnippets[ base, fragment ] = as,
        $documentationSnippets[ base ] = <| fragment -> as |>
    ];

cacheDocumentationSnippetResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
