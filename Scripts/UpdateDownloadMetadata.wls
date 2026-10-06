#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
    Regenerates the download metadata tables (archive sizes, extracted index sizes, and SHA-256 hashes) used to
    validate vector database and streamable snippet downloads.

    Run this whenever a vector database or snippet version is bumped:
    ```
    wolframscript -f Scripts/UpdateDownloadMetadata.wls
    ```

    Options:
        --check         Only check whether the tables cover every version referenced in the source (no downloads).
                        Exits with a non-zero code if the tables are out of date.
        --refresh       Re-download and re-hash every entry, instead of reusing existing entries.
        --verify-cloud  Also download the cloud copy of each vector database and verify it matches the CDN copy.

    Entries are keyed by name and version. Published files for a given version are immutable, so existing entries are
    reused unless --refresh is given. Entries for versions that are no longer referenced in the source are removed.
*)

BeginPackage[ "Wolfram`ChatbookScripts`" ];
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::NoSurroundingEnclose:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

logInfo[ msg_String ] := Print[ msg ];
logWarning[ msg_String ] := Print[ "Warning: " <> msg ];
logError[ msg_String ] := Print[ "Error: " <> msg ];

$checkOnly   = getBooleanArgument[ { "c", "check"        }, False ];
$refresh     = getBooleanArgument[ { "r", "refresh"      }, False ];
$verifyCloud = getBooleanArgument[ { "v", "verify-cloud" }, False ];

$vdbContext  = "Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`";
$rdocContext = "Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`";

$vdbFile  = cFile @ FileNameJoin @ { $pacletDir, "Source", "Chatbook", "PromptGenerators", "VectorDatabases.wl"      };
$rdocFile = cFile @ FileNameJoin @ { $pacletDir, "Source", "Chatbook", "PromptGenerators", "RelatedDocumentation.wl" };
$mxFile   = FileNameJoin @ { $pacletDir, "Source", "Chatbook", ToString @ $SystemWordLength <> "Bit", "Chatbook.mx" };

$workDir := $workDir = cDir @ CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "ChatbookMetadata-" <> CreateUUID[ ] };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Load Paclet Source*)
If[ FileExistsQ @ $mxFile,
    logWarning[ "Ignoring existing MX file so that current source definitions are used: " <> $mxFile ]
];

(* Common.wl has already loaded and verified the paclet directory. *)
WithCleanup[
    If[ FileExistsQ @ $mxFile, RenameFile[ $mxFile, $mxFile <> ".bak" ] ],
    cicd`ScriptConfirmMatch[ CheckAbort[ Get[ "Wolfram`Chatbook`" ], $Failed ], Except[ $Failed | _Failure ] ],
    If[ FileExistsQ[ $mxFile <> ".bak" ], RenameFile[ $mxFile <> ".bak", $mxFile ] ]
];

privateSymbol[ ctx_String, name_String ] := ToExpression[ ctx <> name, InputForm, Hold ];
privateValue[ ctx_String, name_String ] := ReleaseHold @ privateSymbol[ ctx, name ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*heldStrings*)
(* All string literals appearing in an unevaluated expression, following symbol references one level deep.
   This picks up every branch of version specifications like `If[ $VersionNumber >= 15.0, "1.6.0", "1.5.0" ]`. *)
heldStrings // Attributes = { HoldAllComplete };

heldStrings[ expr_ ] := Union @ Flatten @ {
    Cases[ Unevaluated @ expr, s_String :> s, { 0, Infinity }, Heads -> True ],
    Cases[
        Unevaluated @ expr,
        s_Symbol /; StringStartsQ[ Context @ Unevaluated @ s, "Wolfram`Chatbook`" ] :>
            Cases[ OwnValues @ s, (RuleDelayed|Rule)[ _, rhs_ ] :> heldStrings0 @ rhs ],
        { 0, Infinity },
        Heads -> True
    ]
};

heldStrings0 // Attributes = { HoldAllComplete };
heldStrings0[ expr_ ] := Cases[ Unevaluated @ expr, s_String :> s, { 0, Infinity }, Heads -> True ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*versionLikeQ*)
versionLikeQ[ s_String ] := StringMatchQ[ s, DigitCharacter.. ~~ (("." | "-") ~~ DigitCharacter..).. ];
versionLikeQ[ _ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Referenced Versions*)
vectorDBVersions[ ] := Module[ { dbs },
    dbs = cicd`ScriptConfirmBy[ privateValue[ $vdbContext, "$vectorDatabases" ], AssociationQ ];
    Sort @ Catenate @ KeyValueMap[
        Function[ { name, info },
            Catenate @ Cases[
                Normal[ info, Association ],
                (Rule|RuleDelayed)[ "Version", v_ ] :> ({ name, # } & /@ Select[ heldStrings @ v, versionLikeQ ]),
                { 1 }
            ]
        ],
        dbs
    ]
];

snippetVersions[ ] := Module[ { types, held },
    types = cicd`ScriptConfirmMatch[ privateValue[ $rdocContext, "$streamableSnippetTypes" ], { __String } ];
    held  = privateSymbol[ $rdocContext, "$streamableSnippetVersions" ];
    Sort @ DeleteDuplicates @ Replace[
        held,
        Hold[ s_Symbol ] :> Catenate @ Cases[ OwnValues @ s, (RuleDelayed|Rule)[ _, rhs_ ] :> snippetVersions0[ rhs, types ] ]
    ]
];

snippetVersions0 // Attributes = { HoldFirst };
snippetVersions0[ rhs_, types_ ] := Catenate @ Cases[
    Unevaluated @ rhs,
    (Rule|RuleDelayed)[ name_String /; MemberQ[ types, name ], v_ ] :> ({ name, # } & /@ Select[ heldStrings @ v, versionLikeQ ]),
    Infinity
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*URLs*)
vectorDBURL[ base_String, { name_String, version_String } ] :=
    URLBuild @ { base, name, version, name <> ".zip" };

snippetURL[ { name_String, version_String } ] :=
    URLBuild @ {
        privateValue[ $rdocContext, "$streamableSnippetBaseURL" ],
        name,
        StringReplace[ version, "." -> "-" ] <> ".zip"
    };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*download*)
download[ url_String ] := Enclose[
    Module[ { file, res, size, expected },
        file = FileNameJoin @ { $workDir, CreateUUID[ ] <> ".zip" };
        logInfo[ "Downloading " <> url ];
        res = Quiet @ URLDownload[ url, file, { "File", "StatusCode", "Headers" } ];
        ConfirmAssert[ MatchQ[ res, KeyValuePattern[ "StatusCode" -> 200 ] ], "StatusCode" ];
        size = ConfirmBy[ FileByteCount @ file, Positive, "Size" ];
        expected = SelectFirst[ res[ "Headers" ], StringMatchQ[ First @ #, "content-length", IgnoreCase -> True ] &, None ];
        If[ MatchQ[ expected, _ -> _String ],
            ConfirmAssert[ ToExpression @ Last @ expected === size, "ContentLength" ]
        ];
        <| "File" -> file, "Size" -> size, "Hash" -> ConfirmBy[ FileHash[ file, "SHA256", All, "HexString" ], StringQ, "Hash" ] |>
    ],
    Function[ failure, logError[ "Download failed: " <> url ]; failure ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extract*)
extract[ zip_String ] := Enclose[
    Module[ { dir },
        dir = ConfirmBy[ CreateDirectory @ FileNameJoin @ { $workDir, CreateUUID[ ] }, DirectoryQ, "Directory" ];
        ConfirmMatch[ ExtractArchive[ zip, dir ], { __String }, "Extracted" ];
        dir
    ],
    Function[ failure, logError[ "Failed to extract " <> zip ]; failure ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Vector Database Metadata*)
vectorDBMetadata[ key: { name_String, version_String } ] := Enclose[
    Module[ { cdn, cloud, dl, dir, index, cloudDL },
        cdn   = vectorDBURL[ privateValue[ $vdbContext, "$cdnBaseVectorDatabasesURL" ], key ];
        cloud = vectorDBURL[ privateValue[ $vdbContext, "$cloudBaseVectorDatabasesURL" ], key ];
        dl    = ConfirmBy[ download @ cdn, AssociationQ, "Download" ];
        dir   = ConfirmBy[ extract @ dl[ "File" ], DirectoryQ, "Extract" ];
        index = ConfirmBy[ FileNameJoin @ { dir, name <> "-vectors.usearch" }, FileExistsQ, "IndexFile" ];

        ConfirmAssert[
            AllTrue[ { name <> ".wxf", "Values.wxf" }, FileExistsQ @ FileNameJoin @ { dir, # } & ],
            "ExpectedFiles"
        ];

        If[ $verifyCloud,
            cloudDL = ConfirmBy[ download @ cloud, AssociationQ, "CloudDownload" ];
            If[ cloudDL[ "Hash" ] =!= dl[ "Hash" ],
                logError[ "Cloud copy does not match CDN copy for " <> name <> " " <> version ];
                Confirm @ $Failed
            ];
            Quiet @ DeleteFile @ cloudDL[ "File" ]
        ];

        WithCleanup[
            <| "ArchiveSize" -> dl[ "Size" ], "IndexSize" -> FileByteCount @ index, "Hash" -> dl[ "Hash" ] |>,
            Quiet[ DeleteFile @ dl[ "File" ]; DeleteDirectory[ dir, DeleteContents -> True ] ]
        ]
    ],
    Function[ failure, logError[ "Failed to get metadata for " <> ToString[ key, InputForm ] ]; failure ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Snippet Metadata*)
snippetMetadata[ key: { name_String, version_String } ] := Enclose[
    Module[ { dl, dir, meta },
        dl   = ConfirmBy[ download @ snippetURL @ key, AssociationQ, "Download" ];
        dir  = ConfirmBy[ extract @ dl[ "File" ], DirectoryQ, "Extract" ];
        meta = ConfirmBy[ Developer`ReadWXFFile @ FileNameJoin @ { dir, "Metadata.wxf" }, AssociationQ, "Metadata" ];
        ConfirmAssert[ meta[ "Name" ] === name && meta[ "Version" ] === version, "MetadataVersion" ];
        ConfirmAssert[ FileByteCount @ FileNameJoin @ { dir, "Snippets.wxfl" } === meta[ "PayloadSize" ], "PayloadSize" ];
        WithCleanup[
            <| "ArchiveSize" -> dl[ "Size" ], "Hash" -> dl[ "Hash" ] |>,
            Quiet[ DeleteFile @ dl[ "File" ]; DeleteDirectory[ dir, DeleteContents -> True ] ]
        ]
    ],
    Function[ failure, logError[ "Failed to get metadata for " <> ToString[ key, InputForm ] ]; failure ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Existing Metadata*)
existingVectorDBMetadata[ ] := Module[ { sizes, index, hashes },
    sizes  = privateValue[ $vdbContext, "$vectorDBArchiveSizes"   ];
    index  = privateValue[ $vdbContext, "$vectorDBIndexSizes"     ];
    hashes = privateValue[ $vdbContext, "$vectorDBDownloadHashes" ];
    Association @ Map[
        # -> <| "ArchiveSize" -> sizes @ #, "IndexSize" -> index @ #, "Hash" -> hashes @ # |> &,
        Intersection[ Keys @ sizes, Keys @ index, Keys @ hashes ]
    ]
];

existingSnippetMetadata[ ] := Map[
    Replace[ { size_Integer, hash_String } :> <| "ArchiveSize" -> size, "Hash" -> hash |> ],
    privateValue[ $rdocContext, "$streamableSnippetArchiveInfo" ]
];

completeEntryQ[ as_Association, keys_List ] := AllTrue[ keys, MatchQ[ as @ #, _Integer? Positive | _String? (StringLength @ # === 64 &) ] & ];
completeEntryQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*collect*)
collect[ keys_List, existing_Association, fetch_, required_List ] :=
    Association @ Map[
        Function[ key,
            key -> If[ ! $refresh && completeEntryQ[ Lookup[ existing, Key @ key ], required ],
                existing @ key,
                cicd`ScriptConfirmBy[ fetch @ key, AssociationQ ]
            ]
        ],
        keys
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Formatting*)
padRight[ s_String, n_Integer ] := s <> StringRepeat[ " ", Max[ 0, n - StringLength @ s ] ];
padLeft[ s_String, n_Integer ] := StringRepeat[ " ", Max[ 0, n - StringLength @ s ] ] <> s;

formatKey[ { name_, version_ }, nameWidth_, versionWidth_ ] :=
    "{ " <> padRight[ "\"" <> name <> "\"", nameWidth + 2 ] <> ", " <> padRight[ "\"" <> version <> "\"", versionWidth + 2 ] <> " }";

formatTable[ symbol_String, data_Association, valueFunction_ ] := Module[ { keys, nameWidth, versionWidth, values, valueWidth, lines },
    keys         = Sort @ Keys @ data;
    nameWidth    = Max[ StringLength /@ keys[[ All, 1 ]] ];
    versionWidth = Max[ StringLength /@ keys[[ All, 2 ]] ];
    values       = valueFunction /@ Lookup[ data, keys ];
    valueWidth   = Max[ StringLength /@ Select[ values, StringFreeQ[ "\"" ] ] /. -Infinity -> 0 ];
    lines = MapThread[
        "    " <> formatKey[ #1, nameWidth, versionWidth ] <> " -> " <> If[ StringFreeQ[ #2, "\"" ], padLeft[ #2, valueWidth ], #2 ] &,
        { keys, values }
    ];
    symbol <> " = <|\n" <> StringRiffle[ lines, ",\n" ] <> "\n|>;"
];

vectorDBBlock[ data_Association ] := StringRiffle[
    {
        "(* Sizes of the downloaded archives (keyed by name and version): *)",
        formatTable[ "$vectorDBArchiveSizes", data, ToString @ #ArchiveSize & ],
        "",
        "(* Expected sizes of the vector index files after extraction (keyed by name and version): *)",
        formatTable[ "$vectorDBIndexSizes", data, ToString @ #IndexSize & ],
        "",
        "(* SHA-256 hashes of the downloaded archives (keyed by name and version): *)",
        formatTable[ "$vectorDBDownloadHashes", data, "\"" <> #Hash <> "\"" & ]
    },
    "\n"
];

snippetBlock[ data_Association ] := StringRiffle[
    {
        "(* Expected archive sizes and SHA-256 hashes for downloaded snippet archives (keyed by name and version): *)",
        StringReplace[
            formatTable[ "$streamableSnippetArchiveInfo", data, "{ " <> padLeft[ ToString @ #ArchiveSize, 9 ] <> ", \"" <> #Hash <> "\" }" & ],
            "-> {  " -> "-> { "
        ]
    },
    "\n"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*replaceGeneratedBlock*)
replaceGeneratedBlock[ file_String, tag_String, content_String ] := Enclose[
    Module[ { text, nl, begin, end, pattern, replacement, new },
        text    = ConfirmBy[ ReadString @ file, StringQ, "Read" ];
        nl      = If[ StringContainsQ[ text, "\r\n" ], "\r\n", "\n" ];
        begin   = "(* BEGIN GENERATED: " <> tag <> " *)";
        end     = "(* END GENERATED: " <> tag <> " *)";
        pattern = Shortest[ begin ~~ ___ ~~ end ];
        ConfirmAssert[ StringCount[ text, pattern ] === 1, "Markers" ];
        replacement = begin <> nl <> StringReplace[ content, "\n" -> nl ] <> nl <> end;
        new = StringReplace[ text, pattern -> replacement, 1 ];
        If[ new === text,
            logInfo[ "No changes: " <> file ],
            ConfirmBy[ writeUTF8[ file, new ], FileExistsQ, "Write" ];
            logInfo[ "Updated: " <> file ]
        ];
        new =!= text
    ],
    Function[ failure, logError[ "Failed to update generated block " <> tag <> " in " <> file ]; failure ]
];

writeUTF8[ file_String, text_String ] := WithCleanup[
    BinaryWrite[ file, StringToByteArray[ text, "UTF-8" ] ],
    Close @ file
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)
$vdbKeys     = cicd`ScriptConfirmMatch[ vectorDBVersions[ ], { { _String, _String }.. } ];
$snippetKeys = cicd`ScriptConfirmMatch[ snippetVersions[ ], { { _String, _String }.. } ];

logInfo[ "Referenced vector database versions: " <> ToString[ $vdbKeys, InputForm ] ];
logInfo[ "Referenced snippet versions: " <> ToString[ $snippetKeys, InputForm ] ];

$existingVDB     = existingVectorDBMetadata[ ];
$existingSnippet = existingSnippetMetadata[ ];

If[ $checkOnly,
    $missing = Join[
        Complement[ $vdbKeys, Keys @ Select[ $existingVDB, completeEntryQ[ #, { "ArchiveSize", "IndexSize", "Hash" } ] & ] ],
        Complement[ $snippetKeys, Keys @ Select[ $existingSnippet, completeEntryQ[ #, { "ArchiveSize", "Hash" } ] & ] ]
    ];
    $stale = Join[ Complement[ Keys @ $existingVDB, $vdbKeys ], Complement[ Keys @ $existingSnippet, $snippetKeys ] ];
    If[ $missing === { } && $stale === { },
        logInfo[ "Download metadata is up to date." ];
        result = Success[ "UpToDate", <| |> ],
        If[ $missing =!= { }, logError[ "Missing download metadata for: " <> ToString[ $missing, InputForm ] ] ];
        If[ $stale   =!= { }, logWarning[ "Unreferenced download metadata for: " <> ToString[ $stale, InputForm ] ] ];
        logError[ "Run: wolframscript -f Scripts/UpdateDownloadMetadata.wls" ];
        Exit[ 1 ]
    ]
    ,
    $vdbData     = collect[ $vdbKeys, $existingVDB, vectorDBMetadata, { "ArchiveSize", "IndexSize", "Hash" } ];
    $snippetData = collect[ $snippetKeys, $existingSnippet, snippetMetadata, { "ArchiveSize", "Hash" } ];

    result = <|
        "VectorDatabases" -> replaceGeneratedBlock[ $vdbFile, "VectorDatabaseDownloadMetadata", vectorDBBlock @ $vdbData ],
        "Snippets"        -> replaceGeneratedBlock[ $rdocFile, "StreamableSnippetDownloadMetadata", snippetBlock @ $snippetData ]
    |>;

    cicd`ScriptConfirmMatch[ result, KeyValuePattern @ { "VectorDatabases" -> _? BooleanQ, "Snippets" -> _? BooleanQ } ]
];

Quiet @ DeleteDirectory[ $workDir, DeleteContents -> True ];

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];

Wolfram`ChatbookScripts`result
