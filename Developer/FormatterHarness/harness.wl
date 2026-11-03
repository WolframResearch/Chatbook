(* ::Package:: *)

(* ::Title:: *)
(*Formatter differential-testing harness: shared definitions*)

(* Loaded by snapshot.wls, compare.wls, bench.wls and profile.wls. Run those through run.sh, which provides a front end
   under Xvfb (Wolfram Language code blocks need one for FrontEnd`ReparseBoxStructurePacket).

   The code under test is the Chatbook checkout at $CHATBOOK_REPO (default: the checkout that contains this directory).

   Everything that touches Chatbook internals is in the "Adapter" section below, so if the rewrite renames one of
   those symbols, that is the only place to update. *)

BeginPackage[ "FormatterHarness`" ];

(* The harness drives SendChat internals to simulate streaming, and its recursive helpers return early from Module: *)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::ReturnAmbiguous:: *)

$Repo;
$HarnessDir;
$CorpusDir;
$ChunkSize;
LoadChatbook;
CorpusFiles;
ReadCorpusFile;
SnapshotDocument;
FormatFinished;
FormatStreaming;
SimulateStream;
ResetPerResponseState;
WithFormatterEnvironment;
NormalizeOutput;
RoundTrip;
ToMarkdownString;
EncodeRecord;
DecodeRecord;
GeneratedSymbol;
ClickToCopyStub;
PoolList;
WriteWXF;
ReadWXF;
FirstDifference;
FormatDifference;
StringDifference;
GitInfo;
ParseArgs;
FilterFiles;
Abort2;

Begin[ "`Private`" ];

(* ::Section:: *)
(*Config*)

$HarnessDir = DirectoryName @ $InputFileName;
$CorpusDir  = FileNameJoin @ { $HarnessDir, "corpus" };
$Repo       = Replace[ Environment[ "CHATBOOK_REPO" ], $Failed :> FileNameDrop[ $HarnessDir, -2 ] ];
$ChunkSize  = 40;

Abort2[ msg__ ] := ( Print[ "ERROR: ", msg ]; Exit[ 1 ] );

(* Per-file overrides of the handler data that the formatter reads (see $baseHandlerData). Files with simple tool calls
   ("/wl ... /exec") are formatted like a chat using the "Simple" tool method. *)
$fileSettings = <|
    "f07-simple-toolcalls.md" -> <| "ToolMethod" -> "Simple" |>
|>;

(* ::Section:: *)
(*Loading*)

LoadChatbook[ ] := Module[ { mx, loaded, dir },
    If[ ! DirectoryQ @ $Repo, Abort2[ "CHATBOOK_REPO is not a directory: ", $Repo ] ];
    mx = FileNameJoin @ { $Repo, "Source", "Chatbook", "64Bit", "Chatbook.mx" };
    If[ FileExistsQ @ mx,
        Print[ "WARNING: ", mx, " exists and will be loaded instead of the source files. Delete it to test the source." ]
    ];
    (* No network access: branches that need it (e.g. WolframAlpha for free-form input in finished code blocks) take
       their offline path, which keeps the results the same on every machine: *)
    (* Scripts run their main body in Block[ { $AllowInternet = False }, ... ]. Do not assign $AllowInternet here:
       assignments persist across sessions (the paclet manager stores the setting). *)
    If[ TrueQ @ $AllowInternet, Abort2[ "Run the harness inside Block[ { $AllowInternet = False }, ... ]" ] ];
    PacletDirectoryLoad @ $Repo;
    UsingFrontEnd @ Null;
    Get[ "Wolfram`Chatbook`" ];
    loaded = Wolfram`Chatbook`Common`$thisPaclet;
    dir    = Quiet @ loaded[ "Location" ];
    If[ ! StringQ @ dir || ! StringStartsQ[ ExpandFileName @ dir, ExpandFileName @ $Repo ],
        Abort2[ "Loaded Chatbook from ", dir, " instead of ", $Repo ]
    ];
    (* $CloudBase stays Automatic until something resolves it (formatting ResourceFunction boxes does), and the
       cloudURLQ check for images that fail to import issues URLParse::invuri while it is Automatic. Resolve it up
       front, so results don't depend on which documents were formatted before: *)
    If[ $CloudBase === Automatic, $CloudBase = "https://www.wolframcloud.com/" ];
    setUpAttachments[ ];
    stubResourceFunctions[ ];
    dir
];

(* When Chatbook is loaded from source (not the MX build), some resource functions are downloaded the first time they
   are used, which needs network access. ClickToCopy is used to format tool call parameters, so it is replaced by an
   inert local stand-in (only if it is still the lazy download definition): *)
stubResourceFunctions[ ] :=
    If[ ! FreeQ[ OwnValues @ Wolfram`Chatbook`Common`clickToCopy, ResourceFunction ],
        Wolfram`Chatbook`Common`clickToCopy = FormatterHarness`ClickToCopyStub
    ];

(* Attachments referenced by the corpus (attachment:// and expression:// URIs). The keys are hashes of these
   expressions, so they must not change (the corpus refers to them by key): *)
setUpAttachments[ ] := (
    Wolfram`Chatbook`MakeExpressionURI[
        "Plot of Sin",
        Graphics[ { Hue[ 0.6 ], Thick, Line @ Table[ { x, Sin[ x ] }, { x, 0, 6.3, 0.3 } ] }, Axes -> True ]
    ];
    Wolfram`Chatbook`MakeExpressionURI[ "image", Image @ Table[ { i/16., 0.5, 1 - j/16. }, { i, 16 }, { j, 16 } ] ];
    Wolfram`Chatbook`MakeExpressionURI[ "result", { 1, 2, 3, 5, 8, 13 } ];
    Wolfram`Chatbook`MakeExpressionURI[ "Dataset", Dataset @ { <| "a" -> 1, "b" -> 2 |>, <| "a" -> 3, "b" -> 4 |> } ];
);

(* ::Section:: *)
(*Corpus*)

CorpusFiles[ ] := Sort @ FileNames[ "*.md", $CorpusDir ];

(* Read the exact bytes as UTF-8, so that "\r\n" and unusual characters are preserved: *)
(* Corpus files refer to their images as {{CorpusAssets}}/name.png, which becomes the absolute path of corpus/assets
   on this machine: *)
ReadCorpusFile[ file_String ] := Module[ { bytes },
    bytes = ReadByteArray @ file;
    If[ ByteArrayQ @ bytes,
        StringReplace[ ByteArrayToString[ bytes, "UTF-8" ], "{{CorpusAssets}}" -> FileNameJoin @ { $CorpusDir, "assets" } ],
        ""
    ]
];

(* Comma-separated file name patterns ("*" is a wildcard); patterns starting with "!" exclude files, e.g. "!a02*": *)
FilterFiles[ files_List, None ] := files;
FilterFiles[ files_List, pattern_String ] := Module[ { pats, include, exclude },
    pats    = StringTrim /@ StringSplit[ pattern, "," ];
    exclude = StringDrop[ #, 1 ] & /@ Select[ pats, StringStartsQ[ "!" ] ];
    include = Replace[ Select[ pats, ! StringStartsQ[ #, "!" ] & ], { } -> { "*" } ];
    Select[
        files,
        StringMatchQ[ FileNameTake @ #, include ] && ! StringMatchQ[ FileNameTake @ #, exclude ] &
    ]
];

(* ::Section:: *)
(*Adapter: Chatbook internals used by the harness*)

(* The handler data that the formatter reads during a chat. Tool short names make simple tool calls ("/wl") parse,
   and the settings are what writeDynamicChunkAsStatic and dynamicTextDisplay require: *)
baseHandlerData[ name_String ] := <|
    "ChatNotebookSettings" -> <|
        "AutoFormat"        -> True,
        "DynamicAutoFormat" -> True,
        "ToolMethod"        -> "Service",
        Lookup[ $fileSettings, name, <| |> ]
    |>,
    "ToolShortNames" -> Association @ KeyValueMap[
        Wolfram`Chatbook`Common`toolShortName[ #2 ] -> #2 &,
        Wolfram`Chatbook`$DefaultTools
    ]
|>;

(* Evaluates `eval` with the state that a new chat response starts with. SendChat.wl resets $resultCellCache and
   $staticCodeBlockCache for each response, and withChatState resets the thinking timers. Session-level memoization
   (importHTMLEntity, autoCorrectWLCodeBlock, $boxCache, importImage, ...) is intentionally left alone, since the real
   code keeps it for the whole session. *)
ResetPerResponseState[ ] := (
    Wolfram`Chatbook`Common`$resultCellCache      = <| |>;
    Wolfram`Chatbook`Common`$staticCodeBlockCache = <| |>;
    Wolfram`Chatbook`Common`$thinkingStart        = None;
    Wolfram`Chatbook`Common`$thinkingEnd          = None;
    Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked = None;
);

SetAttributes[ WithFormatterEnvironment, HoldRest ];
WithFormatterEnvironment[ name_String, eval_ ] :=
    Block[ { Wolfram`Chatbook`$ChatHandlerData = baseHandlerData @ name }, ResetPerResponseState[ ]; eval ];

FormatFinished[ text_String ] :=
    Wolfram`Chatbook`FormatChatOutput[ text, <| "Status" -> "Finished" |> ];

FormatStreaming[ text_String ] :=
    Wolfram`Chatbook`FormatChatOutput[ text, <| "Status" -> "Streaming" |> ];

(* The chunks that the LLM service delivers: whole characters, as UTF-8 byte strings (appendStringContent decodes them
   with convertUTF8): *)
streamChunks[ text_String, size_Integer ] :=
    FromCharacterCode @ ToCharacterCode[ #, "UTF-8" ] & /@ StringPartition[ text, UpTo @ size ];

(* Simulates what a streaming chat displays, using the real chunk handler (writeChunk0) and display function
   (dynamicTextDisplay) from SendChat.wl with the front end writes stubbed out:
   - each chunk goes through writeChunk0, which appends it to the container, splits completed code blocks, images and
     tool calls out of the dynamic content and formats them as static cells (writeDynamicChunkAsStatic), and
   - after each chunk, the dynamic content is formatted the way the output cell's Dynamic does it.
   The display is formatted after every chunk (the real display refreshes on a timer, so it skips some of these).
   Finally, the full content is formatted the way writeReformattedCell/reformatCell does it, with the static code
   block cache that the static writes filled in.
   Gives <| "Steps" -> { <| "Length" -> n, "Static" -> { cells... }, "Display" -> expr |>, ... },
            "Final" -> expr, "FullContent" -> string, "Timing" -> <| ... |> |> *)
SimulateStream[ text_String, size_Integer: $ChunkSize ] := Module[
    { container, bag, steps, settings, formatter, full, final, consumed = 0, timing = { }, tFinal },

    container = <|
        "DynamicContent"   -> ProgressIndicator[ Appearance -> "Percolate" ],
        "FullContent"      -> ProgressIndicator[ Appearance -> "Percolate" ],
        "UUID"             -> "harness-uuid",
        "DynamicBoxObject" -> BoxObject[ FrontEndObject[ ], 1 ]
    |>;

    settings  = Wolfram`Chatbook`$ChatHandlerData[ "ChatNotebookSettings" ];
    formatter = Wolfram`Chatbook`SendChat`Private`getFormattingFunction @ settings;
    bag       = Internal`Bag[ ];

    steps = Block[
        {
            Wolfram`Chatbook`Common`$alwaysOpen                    = False,
            Wolfram`Chatbook`SendChat`Private`$dynamicSplit        = True,
            Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked = None,
            Wolfram`Chatbook`SendChat`Private`openChatCell         = Function[ Null ],
            NotebookRead  = Null &,
            NotebookWrite = (Internal`StuffBag[ bag, #2 ]; Null) &
        },
        Map[
            Function[ chunk,
                Module[ { static, display, t1, t2 },
                    t1 = First @ AbsoluteTiming[
                        Wolfram`Chatbook`SendChat`Private`writeChunk0[ Dynamic @ container, None, chunk, chunk ]
                    ];
                    consumed += StringLength @ chunk;
                    static = Internal`BagPart[ bag, All ];
                    bag    = Internal`Bag[ ];
                    t2 = First @ AbsoluteTiming[
                        display = Wolfram`Chatbook`SendChat`Private`dynamicTextDisplay[ container, formatter, True ]
                    ];
                    AppendTo[ timing, { t1, t2 } ];
                    <| "Length" -> consumed, "Static" -> static, "Display" -> display |>
                ]
            ],
            streamChunks[ text, size ]
        ]
    ];

    full  = container[ "FullContent" ];
    tFinal = First @ AbsoluteTiming[ final = If[ StringQ @ full,
        Block[
            {
                Wolfram`Chatbook`Common`$dynamicText             = False,
                Wolfram`Chatbook`Common`$useStaticCodeBlockCache = True
            },
            formatter[ StringTrim @ full, settings ]
        ],
        Missing[ "NoContent" ]
    ] ];

    <|
        "Steps"       -> steps,
        "Final"       -> final,
        "FullContent" -> full,
        (* Seconds spent in writeChunk0 (which includes formatting static content) and in the display for each step,
           and in the final formatting: *)
        "Timing"      -> <| "Chunk" -> timing[[ All, 1 ]], "Display" -> timing[[ All, 2 ]], "Final" -> tFinal |>
    |>
];

(* Serialization back to markdown, as for chat history.
   serializeTraditionalForm (and serializeStandardFormString) in Serialization.wl memoize results that depend on
   Block-scoped flags at the time of the first call (e.g. $inlineCode), so the string for a math box depends on where
   the same box was first serialized in the session (for example, $O(1)$ in a table gives "O(1)" or "``O``(1)"
   depending on which earlier response contained it). The memoized values are cleared before each serialization, so
   each document's strings depend only on its own content: *)
ToMarkdownString[ RawBoxes[ Cell[ td_TextData, ___ ] ] ] := ToMarkdownString @ td;
ToMarkdownString[ td_TextData ] := (
    clearSerializationMemos[ ];
    Wolfram`Chatbook`CellToString @ Cell[ td, "ChatOutput" ]
);

$$patternPart = _Pattern | _Blank | _BlankSequence | _BlankNullSequence | _Optional | _Condition | _PatternTest | _Alternatives;

clearSerializationMemos[ ] := Scan[
    Function[ name,
        If[ Names @ name =!= { },
            ToExpression[ name, InputForm, Function[ s, DownValues[ s ] = Select[ DownValues[ s ], ! FreeQ[ First @ #, $$patternPart ] & ], HoldFirst ] ]
        ]
    ],
    {
        "Wolfram`Chatbook`Serialization`Private`serializeTraditionalForm",
        "Wolfram`Chatbook`Serialization`Private`serializeStandardFormString"
    }
];
ToMarkdownString[ other_ ] := Missing[ "NotTextData", Head @ other ];

(* ::Section:: *)
(*Snapshot of one document*)

(* Evaluates `eval`, giving { result, messages }. Messages are recorded as strings like "Part::partw". Uncaught throws,
   aborts and evaluations that take longer than $TimeLimit seconds give a Failure instead of stopping the script. *)
$TimeLimit = 600;

SetAttributes[ withMessages, HoldFirst ];
withMessages[ eval_ ] := Module[ { data },
    data = EvaluationData @ TimeConstrained[
        CheckAbort[
            Catch[ eval, _, Failure[ "UncaughtThrow", <| "Tag" -> #2, "Value" -> #1 |> ] & ],
            Failure[ "Aborted", <| |> ]
        ],
        $TimeLimit,
        Failure[ "TimedOut", <| "Seconds" -> $TimeLimit |> ]
    ];
    {
        data[ "Result" ],
        Cases[
            Lookup[ data, "MessagesExpressions", { } ],
            Hold[ Message[ m_MessageName, ___ ] ] :> ToString[ Unevaluated @ m, InputForm ]
        ]
    }
];

(* Computes everything for one corpus file, normalized and round-tripped through WXF, so it can be compared directly
   with the decoded golden record. `opts` can disable parts: "Stream" -> False. *)
SnapshotDocument[ file_String, opts___Rule ] := Module[
    { name, text, finished, streaming, stream, msgs = <| |>, doStream },
    name     = FileNameTake @ file;
    text     = ReadCorpusFile @ file;
    doStream = Lookup[ { opts }, "Stream", True ];

    WithFormatterEnvironment[ name,
        { finished, msgs[ "Finished" ] } = withMessages @ FormatFinished @ text
    ];
    WithFormatterEnvironment[ name,
        { streaming, msgs[ "Streaming" ] } = withMessages @ FormatStreaming @ text
    ];
    If[ TrueQ @ doStream,
        WithFormatterEnvironment[ name,
            { stream, msgs[ "Stream" ] } = withMessages @ SimulateStream @ text
        ]
    ];

    RoundTrip @ NormalizeOutput @ DeleteMissing @ <|
        "InputHash"       -> Hash[ text, "SHA256", "HexString" ],
        "InputLength"     -> StringLength @ text,
        "Finished"        -> finished,
        "FinishedString"  -> Quiet @ ToMarkdownString @ finished,
        "Streaming"       -> streaming,
        "StreamingString" -> Quiet @ ToMarkdownString @ streaming,
        If[ TrueQ @ doStream,
            "Stream" -> <|
                "ChunkSize"   -> $ChunkSize,
                "Steps"       -> stream[ "Steps" ],
                "Final"       -> stream[ "Final" ],
                "FinalString" -> Quiet @ ToMarkdownString @ stream[ "Final" ]
            |>,
            Nothing
        ],
        "Messages" -> msgs
    |>
];

(* ::Section:: *)
(*Normalization*)

(* Anything that differs between two runs of identical code, or that only identifies front end objects:
   - generated symbols (Module variables like cell$123, DynamicModule variables like x$$123, Unique symbols)
   - CellObject, BoxObject, NotebookObject and FrontEndObject references
   - UUIDs
   - the elapsed time in "Thought for N seconds" labels of literal think tags (it depends on how long formatting
     took between the first <think> and the closing tag while streaming) *)
$$uuid = Repeated[ HexadecimalCharacter, { 8 } ] ~~ "-" ~~ Repeated[ HexadecimalCharacter, { 4 } ] ~~ "-" ~~
         Repeated[ HexadecimalCharacter, { 4 } ] ~~ "-" ~~ Repeated[ HexadecimalCharacter, { 4 } ] ~~ "-" ~~
         Repeated[ HexadecimalCharacter, { 12 } ];

generatedSymbolQ = Function[
    s,
    StringMatchQ[ SymbolName @ Unevaluated @ s, (__ ~~ "$" ~~ ("$"|"") ~~ DigitCharacter..) | ("$" ~~ DigitCharacter..) ],
    HoldFirst
];

generatedSymbolName = Function[
    s,
    StringReplace[ SymbolName @ Unevaluated @ s, "$" ~~ d: ("$"|"") ~~ DigitCharacter.. ~~ EndOfString :> "$" <> d <> "N" ],
    HoldFirst
];

(* Labels of finished literal think tags: "Thought for a second" (a front end resource) or "Thought for N seconds" (a
   string made from a template). Both are replaced by "<ThoughtDurationLabel>". *)
$thoughtDurationPattern := $thoughtDurationPattern = Module[ { template, parts },
    template = Quiet @ Wolfram`Chatbook`Common`trRaw[ "FormattingThinkingComplete" ];
    parts    = If[ StringQ @ template, StringSplit[ template, "`time`", All ], { } ];
    If[ Length @ parts === 2,
        parts[[ 1 ]] ~~ DigitCharacter.. ~~ parts[[ 2 ]],
        "Thought for " ~~ DigitCharacter.. ~~ " seconds"
    ]
];

thoughtDurationLabelQ[ label_ ] := Or[
    ! FreeQ[ label, "FormattingThinkingCompleteSingular" ],
    ! FreeQ[ label, s_String /; StringMatchQ[ s, ("\""|"") ~~ $thoughtDurationPattern ~~ ("\""|"") ] ]
];

NormalizeOutput[ expr_ ] := ReplaceAll[
    expr,
    {
        s_Symbol? generatedSymbolQ :> RuleCondition @ GeneratedSymbol @ generatedSymbolName @ s,
        CellObject[ __ ]     :> CellObject[ "<normalized>" ],
        BoxObject[ __ ]      :> BoxObject[ "<normalized>" ],
        NotebookObject[ __ ] :> NotebookObject[ "<normalized>" ],
        FrontEndObject[ __ ] :> FrontEndObject[ "<normalized>" ],
        TemplateBox[ { c_, label_, meta_ }, name: "ThoughtsOpener"|"EmptyThoughts", rest___ ] /;
            thoughtDurationLabelQ @ label :>
                TemplateBox[ { c, "<ThoughtDurationLabel>", meta }, name, rest ],
        str_String /; StringContainsQ[ str, $$uuid ] :> RuleCondition @ StringReplace[ str, $$uuid -> "<UUID>" ],
        (* Entity boxes are only formatted when the entity is in the local entity store cache (the harness runs
           offline), so the same code gives different boxes depending on what this machine has cached. Compare the
           unformatted boxes, which every formatted Entity TemplateBox keeps as its second argument: *)
        TemplateBox[ { _, raw: RowBox @ { "Entity"|"EntityClass"|"EntityProperty", "[", ___ }, ___ }, "Entity"|"EntityClass"|"EntityProperty", ___ ] :>
            raw
    }
];

(* WXF round trip, so that fresh results are compared in the same form as results read from a golden file: *)
RoundTrip[ expr_ ] := BinaryDeserialize @ BinarySerialize @ expr;

(* ::Section:: *)
(*Encoding with a shared item pool*)

(* Streaming steps repeat most of their TextData items, so each distinct item is stored once in a pool, and outputs
   refer to items by index. *)
poolID[ pool_Symbol, item_ ] := Lookup[ pool, Key @ item, pool[ item ] = Length @ pool + 1 ];
SetAttributes[ poolID, HoldFirst ];

PoolList[ pool_Association ] := Keys @ pool;

encode[ pool_Symbol, RawBoxes[ Cell[ TextData[ items_List ], opts___ ] ] ] :=
    enc[ "RawCell", poolID[ pool, # ] & /@ items, { opts } ];
encode[ pool_Symbol, Cell[ TextData[ items_List ], opts___ ] ] :=
    enc[ "Cell", poolID[ pool, # ] & /@ items, { opts } ];
encode[ pool_Symbol, other_ ] :=
    enc[ "Other", { poolID[ pool, other ] }, { } ];
SetAttributes[ encode, HoldFirst ];

decode[ items_List, enc[ "RawCell", ids_List, opts_List ] ] := RawBoxes @ Cell[ TextData @ items[[ ids ]], Sequence @@ opts ];
decode[ items_List, enc[ "Cell", ids_List, opts_List ] ] := Cell[ TextData @ items[[ ids ]], Sequence @@ opts ];
decode[ items_List, enc[ "Other", { id_ }, _ ] ] := items[[ id ]];

$encodedKeys = { "Finished", "Streaming" };

EncodeRecord[ pool_Symbol, record_Association ] := Module[ { r = record },
    Scan[ If[ KeyExistsQ[ r, # ], r[ # ] = encode[ pool, Evaluate @ r[ # ] ] ] &, $encodedKeys ];
    If[ AssociationQ @ r[ "Stream" ],
        r[ "Stream", "Final" ] = encode[ pool, Evaluate @ r[ "Stream", "Final" ] ];
        r[ "Stream", "Steps" ] = Map[
            <|
                "Length"  -> #Length,
                "Static"  -> Map[ Function[ c, encode[ pool, c ] ], #Static ],
                "Display" -> encode[ pool, Evaluate @ #Display ]
            |> &,
            r[ "Stream", "Steps" ]
        ]
    ];
    r
];
SetAttributes[ EncodeRecord, HoldFirst ];

DecodeRecord[ items_List, record_Association ] := Module[ { r = record },
    Scan[ If[ KeyExistsQ[ r, # ], r[ # ] = decode[ items, r[ # ] ] ] &, $encodedKeys ];
    If[ AssociationQ @ r[ "Stream" ],
        r[ "Stream", "Final" ] = decode[ items, r[ "Stream", "Final" ] ];
        r[ "Stream", "Steps" ] = Map[
            <|
                "Length"  -> #Length,
                "Static"  -> Map[ decode[ items, # ] &, #Static ],
                "Display" -> decode[ items, #Display ]
            |> &,
            r[ "Stream", "Steps" ]
        ]
    ];
    r
];

WriteWXF[ file_String, expr_ ] := Module[ { bytes, stream },
    bytes  = BinarySerialize[ expr, PerformanceGoal -> "Size" ];
    stream = OpenWrite[ file, BinaryFormat -> True ];
    BinaryWrite[ stream, bytes ];
    Close @ stream;
    file
];

ReadWXF[ file_String ] := BinaryDeserialize @ ReadByteArray @ file;

(* ::Section:: *)
(*Differences*)

(* Gives None if the expressions are the same, otherwise <| "Position" -> pos, "Path" -> heads, "Expected" -> a,
   "Actual" -> b, "Note" -> ... |> for the first (depth-first, leftmost) subexpression that differs. *)
FirstDifference[ a_, b_ ] := firstDiff[ HoldComplete @ a, HoldComplete @ b, { }, { } ];

firstDiff[ HoldComplete[ a_ ], HoldComplete[ b_ ], pos_, path_ ] /; a === b := None;

firstDiff[ HoldComplete[ a_Association ], HoldComplete[ b_Association ], pos_, path_ ] /;
    AssociationQ @ Unevaluated @ a && AssociationQ @ Unevaluated @ b :=
    If[ Keys @ a =!= Keys @ b,
        diffResult[ HoldComplete @ a, HoldComplete @ b, pos, path, "association keys differ: " <>
            ToString[ Keys @ a, InputForm ] <> " vs " <> ToString[ Keys @ b, InputForm ] ],
        Catch @ Scan[
            Function[ k,
                With[ { d = firstDiff[ HoldComplete @@ { a[ k ] }, HoldComplete @@ { b[ k ] }, Append[ pos, Key @ k ], Append[ path, "<|" <> ToString[ k, InputForm ] <> "|>" ] ] },
                    If[ d =!= None, Throw @ d ]
                ]
            ],
            Keys @ a
        ] // Replace[ Null -> None ]
    ];

firstDiff[ HoldComplete[ a_ ], HoldComplete[ b_ ], pos_, path_ ] /; AtomQ @ Unevaluated @ a || AtomQ @ Unevaluated @ b :=
    diffResult[ HoldComplete @ a, HoldComplete @ b, pos, path, None ];

firstDiff[ HoldComplete[ a_ ], HoldComplete[ b_ ], pos_, path_ ] := Module[ { ha, hb, la, lb, n, d },
    ha = Extract[ Unevaluated @ a, { 0 }, HoldComplete ];
    hb = Extract[ Unevaluated @ b, { 0 }, HoldComplete ];
    If[ ha =!= hb, Return @ diffResult[ HoldComplete @ a, HoldComplete @ b, pos, path, "heads differ" ] ];
    la = Length @ Unevaluated @ a;
    lb = Length @ Unevaluated @ b;
    n  = Min[ la, lb ];
    d  = Catch @ Do[
        With[
            {
                r = firstDiff[
                    Extract[ Unevaluated @ a, { i }, HoldComplete ],
                    Extract[ Unevaluated @ b, { i }, HoldComplete ],
                    Append[ pos, i ],
                    Append[ path, headString @ ha <> "[" <> ToString @ i <> "]" ]
                ]
            },
            If[ r =!= None, Throw @ If[ la =!= lb, Append[ r, "Note" -> lengthNote[ ha, la, lb ] ], r ] ]
        ],
        { i, n }
    ];
    If[ AssociationQ @ d, Return @ d ];
    (* All common parts agree, so one has extra parts: *)
    diffResult[ HoldComplete @ a, HoldComplete @ b, pos, path, lengthNote[ ha, la, lb ] <> "; first extra part: " <>
        If[ la > lb,
            "expected has " <> showHeld[ Extract[ Unevaluated @ a, { n + 1 }, HoldComplete ], 300 ],
            "actual has " <> showHeld[ Extract[ Unevaluated @ b, { n + 1 }, HoldComplete ], 300 ]
        ]
    ]
];

lengthNote[ h_, la_, lb_ ] := headString @ h <> " has " <> ToString @ la <> " parts in expected, " <> ToString @ lb <> " in actual";

headString[ HoldComplete[ List ] ] := "{}";
headString[ HoldComplete[ h_Symbol ] ] := SymbolName @ Unevaluated @ h;
headString[ HoldComplete[ h_ ] ] := StringTake[ ToString[ Unevaluated @ h, InputForm ], UpTo[ 30 ] ];

diffResult[ a_, b_, pos_, path_, note_ ] := <|
    "Position" -> pos,
    "Path"     -> path,
    "Expected" -> a,
    "Actual"   -> b,
    "Note"     -> note
|>;

showHeld[ HoldComplete[ e_ ], n_Integer ] := Module[ { s },
    s = ToString[ Unevaluated @ e, InputForm, PageWidth -> Infinity ];
    If[ StringLength @ s > n, StringTake[ s, n ] <> "\[Ellipsis] (" <> ToString @ StringLength @ s <> " chars)", s ]
];

(* For two differing strings, show where they start to differ: *)
stringContext[ a_String, b_String ] := Module[ { i = 1, n = Min[ StringLength @ a, StringLength @ b ] },
    While[ i <= n && StringTake[ a, { i } ] === StringTake[ b, { i } ], i++ ];
    "strings differ at character " <> ToString @ i <> ": expected \"" <>
        StringTake[ a, { Max[ 1, i - 20 ], Min[ StringLength @ a, i + 40 ] } ] <> "\" vs actual \"" <>
        StringTake[ b, { Max[ 1, i - 20 ], Min[ StringLength @ b, i + 40 ] } ] <> "\""
];

FormatDifference[ d_Association, indent_String: "    " ] := Module[ { lines },
    lines = {
        "position: " <> ToString[ d[ "Position" ], InputForm ],
        "path:     " <> StringRiffle[ d[ "Path" ], " > " ],
        "expected: " <> showHeld[ d[ "Expected" ], 400 ],
        "actual:   " <> showHeld[ d[ "Actual" ], 400 ]
    };
    If[ MatchQ[ { d[ "Expected" ], d[ "Actual" ] }, { HoldComplete[ _String ], HoldComplete[ _String ] } ],
        AppendTo[ lines, "note:     " <> stringContext[ First @ d[ "Expected" ], First @ d[ "Actual" ] ] ]
    ];
    If[ StringQ @ d[ "Note" ], AppendTo[ lines, "note:     " <> d[ "Note" ] ] ];
    StringRiffle[ indent <> # & /@ lines, "\n" ]
];

(* Line diff for serialized strings: the first differing line with some context. *)
StringDifference[ a_String, b_String, indent_String: "    " ] := Module[ { la, lb, i = 1, n, ctx },
    la = StringSplit[ a, "\n", All ];
    lb = StringSplit[ b, "\n", All ];
    n  = Min[ Length @ la, Length @ lb ];
    While[ i <= n && la[[ i ]] === lb[[ i ]], i++ ];
    ctx[ l_, k_ ] := StringRiffle[
        Table[ indent <> "  " <> If[ j == k, "> ", "  " ] <> ToString @ j <> ": " <> trunc[ l[[ j ]], 200 ], { j, Max[ 1, k - 2 ], Min[ Length @ l, k + 2 ] } ],
        "\n"
    ];
    StringJoin[
        indent, "first differing line: ", ToString @ i, " (expected ", ToString @ Length @ la, " lines, actual ",
        ToString @ Length @ lb, " lines)\n",
        indent, "expected:\n", ctx[ la, i ], "\n",
        indent, "actual:\n", ctx[ lb, i ]
    ]
];
StringDifference[ a_, b_, indent_String: "    " ] :=
    indent <> "expected: " <> trunc[ ToString[ a, InputForm ], 300 ] <> "\n" <> indent <> "actual:   " <> trunc[ ToString[ b, InputForm ], 300 ];

trunc[ s_String, n_ ] := If[ StringLength @ s > n, StringTake[ s, n ] <> "\[Ellipsis]", s ];

(* ::Section:: *)
(*Misc*)

GitInfo[ dir_String ] := Module[ { run },
    run[ args__ ] := Replace[
        Quiet @ RunProcess[ { "git", "-C", dir, args } ],
        { KeyValuePattern @ { "ExitCode" -> 0, "StandardOutput" -> s_String } :> StringTrim @ s, _ :> Missing[ "NotAvailable" ] }
    ];
    <|
        "Commit" -> run[ "rev-parse", "HEAD" ],
        "Branch" -> run[ "rev-parse", "--abbrev-ref", "HEAD" ],
        "Dirty"  -> Replace[ run[ "status", "--porcelain", "--", "Source" ], s_String :> s =!= "" ]  (* uncommitted changes under Source/ *)
    |>
];

(* "--key=value" and "--flag" arguments, plus positional arguments: *)
ParseArgs[ args_List ] := Module[ { opts, pos },
    opts = Association @ Cases[
        args,
        s_String /; StringStartsQ[ s, "--" ] :> Replace[
            StringSplit[ StringDrop[ s, 2 ], "=", 2 ],
            { { k_, v_ } :> k -> v, { k_ } :> k -> True }
        ]
    ];
    pos = Select[ args, ! StringStartsQ[ #, "--" ] & ];
    <| "Options" -> opts, "Positional" -> pos |>
];

End[ ];
(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];
