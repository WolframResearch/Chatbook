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
(*Configuration*)
$vectorDBNames = { "DocumentationURIs", "WolframAlphaQueries" };

$embeddingDimension      = 256;
$maxNeighbors            = 50;
$maxEmbeddingDistance    = 150.0;
$embeddingService        = "OpenAI"; (* FIXME *)
$embeddingModel          = "text-embedding-3-small";
$embeddingAuthentication = Automatic; (* FIXME *)


$conversationVectorSearchPenalty = 1.0;

$relatedQueryCount = 5;
$relatedDocsCount  = 20;
$querySampleCount  = 10;

$relevantFileCount = 3;
$maxExtraFiles     = 20;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Remote Content Locations*)
$baseVectorDatabasesURL = "https://www.wolframcloud.com/obj/wolframai-content/VectorDatabases";

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
(*Vector Database Utilities*)
$vectorDBDirectory := getVectorDBDirectory[ ];

$noSemanticSearch := $noSemanticSearch = ! PacletObjectQ @ Quiet @ PacletInstall[ "SemanticSearch" ];

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

        evaluateWithProgress[

            tasks = ConfirmMatch[ KeyValueMap[ downloadVectorDatabase @ dir, urls ], { __TaskObject }, "Download" ];
            ConfirmMatch[ taskWait @ tasks, { __TaskObject }, "TaskWait" ];
            $progressText = "Unpacking files\[Ellipsis]";
            ConfirmBy[ unpackVectorDatabases @ dir, DirectoryQ, "Unpacked" ],

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
(*evaluateWithProgress*)
(* This is a workaround for EvaluateWithProgress never printing a progress panel when called normally in a chat: *)
evaluateWithProgress // beginDefinition;
evaluateWithProgress // Attributes = { HoldFirst };

evaluateWithProgress[ args___ ] /; $Notebooks && $EvaluationEnvironment === "Session" :=
    Module[ { container, dialog },

        container = ProgressIndicator[ Appearance -> "Percolate" ];

        dialog = CreateDialog[
            Pane[ Dynamic @ container, ImageMargins -> { { 5, 5 }, { 10, 5 } } ],
            WindowTitle -> Dynamic[ $progressText ]
        ];

        WithCleanup[
            Progress`EvaluateWithProgress[
                args,
                "Container" :> container,
                "Delay"     -> 0
            ],
            NotebookClose @ dialog;
            Remove @ container;
        ]
    ];

evaluateWithProgress[ args___ ] :=
    Progress`EvaluateWithProgress @ args;

evaluateWithProgress // endDefinition;

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
    ] // LogChatTiming[ { "DownloadVectorDatabase", name } ],
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
            ] // LogChatTiming[ "VectorDatabaseSearch" ],
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

vectorDBSearch[ dbName_String, messages0: { __Association }, prop: "Values"|"Results" ] := Enclose[
    Catch @ Module[
        {
            messages,
            conversationString, lastMessageString, selectionString,
            conversationResults, lastMessageResults, selectionResults,
            combined, n, merged
        },

        (* TODO: asynchronously pre-cache embeddings for each type *)

        messages = ConfirmMatch[ insertContextPrompt @ messages0, { __Association }, "Messages" ];

        conversationString = ConfirmBy[ getSmallContextString @ messages, StringQ, "ConversationString" ];

        lastMessageString = ConfirmBy[
            getSmallContextString[ { Last @ messages }, "IncludeSystemMessage" -> True ],
            StringQ,
            "LastMessageString"
        ];

        selectionString = If[ StringQ @ $selectionPrompt, $selectionPrompt, None ];

        If[ conversationString === "" || lastMessageString === "", Throw @ { } ];

        preloadEmbeddings @ { conversationString, lastMessageString, selectionString };

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

vectorDBSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preloadEmbeddings*)
preloadEmbeddings // beginDefinition;
(* FIXME: find a way to asynchronously fetch embeddings (ServiceSubmit isn't working) *)
preloadEmbeddings[ strings: { (_String|None)... } ] := Null;
preloadEmbeddings // endDefinition;

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
    ] // LogChatTiming[ "GetEmbedding" ],
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
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
