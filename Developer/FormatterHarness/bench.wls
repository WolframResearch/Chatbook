#!/usr/bin/env wolframscript
(* ::Package:: *)

(* Usage: ./run.sh bench [--out=NAME] [--files=pattern,...] [--cold=default|all|none|pattern,...]
                         [--reps=N] [--seq-reps=N] [--baseline=FILE.wxf]

   Measures formatter time per corpus file with the Chatbook code at $CHATBOOK_REPO:
     cold F      first FormatChatOutput "Finished" call in a fresh kernel (separate process per file)
     cold seq    simulated streaming sequence (all chunks plus final cell) as the first thing in a fresh kernel
     first F/S   first "Finished"/"Streaming" call for this file in the benchmark kernel, which was warmed up on
                 warmup.md and the files before it (new content in a warm kernel: session memoization does not help)
     warm F/S    median of repeated calls (per-response caches reset before each call, as SendChat does)
     seq first   simulated streaming sequence total (first run), seq warm: median of repeated runs
     disp/step   median time of one dynamic display update during the warm sequence
   The cold columns are only measured for the --cold files (default: a few representative files; "all" takes about
   25 s per file).

   Writes NAME.wxf (raw numbers) and NAME.md (tables) next to this script (default NAME: bench-latest).
   With --baseline=FILE.wxf, also prints new/baseline time ratios. *)

Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "harness.wl" };

$defaultColdFiles = { "s01-plot-basic.md", "l01-plotting-guide.md", "l16-assistant-session.md", "l03-equation-solving.md" };

(* ::Section:: *)
(*Cold worker (runs in its own kernel)*)

coldWorker[ mode_String, file_String ] := Module[ { tLoad, text, name, t, res },
    name  = FileNameTake @ file;
    tLoad = First @ AbsoluteTiming @ FormatterHarness`LoadChatbook[ ];
    text  = FormatterHarness`ReadCorpusFile @ file;
    res = Switch[ mode,
        "finished",
            t = First @ AbsoluteTiming @ FormatterHarness`WithFormatterEnvironment[ name, FormatterHarness`FormatFinished @ text ];
            <| "File" -> name, "Mode" -> mode, "Load" -> tLoad, "First" -> t |>,
        "stream",
            Module[ { stream },
                t = First @ AbsoluteTiming[
                    stream = FormatterHarness`WithFormatterEnvironment[ name, FormatterHarness`SimulateStream @ text ]
                ];
                <|
                    "File"      -> name,
                    "Mode"      -> mode,
                    "Load"      -> tLoad,
                    "Sequence"  -> t,
                    "FirstStep" -> Total @ First @ Transpose @ { stream[ "Timing", "Chunk" ], stream[ "Timing", "Display" ] },
                    "Final"     -> stream[ "Timing", "Final" ]
                |>
            ]
    ];
    Print[ "COLD-RESULT " <> ExportString[ res, "RawJSON", "Compact" -> True ] ];
];

runColdWorker[ mode_String, file_String ] := Module[ { proc, out },
    proc = RunProcess[ { FileNameJoin @ { DirectoryName @ $InputFileName, "withfe.sh" }, "wolframscript", "-f", $InputFileName, "--cold-worker=" <> mode, file } ];
    out  = StringCases[ proc[ "StandardOutput" ], "COLD-RESULT " ~~ json: Except[ "\n" ].. :> json, 1 ];
    If[ out === { },
        Print[ "  cold worker failed for ", FileNameTake @ file, " (", mode, "): ", StringTake[ proc[ "StandardOutput" ] <> proc[ "StandardError" ], UpTo[ 500 ] ] ];
        Missing[ "Failed" ],
        ImportString[ First @ out, "RawJSON" ]
    ]
];

(* ::Section:: *)
(*Measurements in this kernel*)

(* At most `reps`, and at least 1, so that the repetitions take about `budget` seconds: *)
adaptiveReps[ reps_Integer, first_? NumberQ, budget_ ] := Max[ 1, Min[ reps, Ceiling[ budget / Max[ first, 10.^-6 ] ] ] ];

warmTimes[ name_String, f_, reps_Integer ] := Table[
    FormatterHarness`WithFormatterEnvironment[ name, First @ AbsoluteTiming @ f[ ] ],
    reps
];

benchFile[ file_String, reps_Integer, seqReps_Integer ] := Module[
    { name, text, firstF, firstS, seqFirst, seqWarm, warmF, warmS, stream, steps, disp },
    name = FileNameTake @ file;
    text = FormatterHarness`ReadCorpusFile @ file;

    firstF   = First @ warmTimes[ name, FormatterHarness`FormatFinished[ text ] &, 1 ];
    firstS   = First @ warmTimes[ name, FormatterHarness`FormatStreaming[ text ] &, 1 ];
    seqFirst = First @ warmTimes[ name, FormatterHarness`SimulateStream[ text ] &, 1 ];
    (* Fewer repetitions for slow files, so that a pathological file doesn't take minutes: *)
    warmF    = warmTimes[ name, FormatterHarness`FormatFinished[ text ] &, adaptiveReps[ reps, firstF, 5 ] ];
    warmS    = warmTimes[ name, FormatterHarness`FormatStreaming[ text ] &, adaptiveReps[ reps, firstS, 5 ] ];
    seqWarm  = Table[
        FormatterHarness`WithFormatterEnvironment[ name,
            First @ AbsoluteTiming[ stream = FormatterHarness`SimulateStream @ text ]
        ],
        adaptiveReps[ seqReps, seqFirst, 15 ]
    ];
    steps = Length @ stream[ "Steps" ];
    disp  = Median @ stream[ "Timing", "Display" ];
    <|
        "File"         -> name,
        "Bytes"        -> StringLength @ text,
        "Steps"        -> steps,
        "FirstF"       -> firstF,
        "WarmF"        -> Median @ warmF,
        "WarmFMin"     -> Min @ warmF,
        "FirstS"       -> firstS,
        "WarmS"        -> Median @ warmS,
        "WarmSMin"     -> Min @ warmS,
        "SeqFirst"     -> seqFirst,
        "SeqWarm"      -> Median @ seqWarm,
        "SeqWarmMin"   -> Min @ seqWarm,
        "SeqChunk"     -> Total @ stream[ "Timing", "Chunk" ],
        "SeqDisplay"   -> Total @ stream[ "Timing", "Display" ],
        "SeqFinal"     -> stream[ "Timing", "Final" ],
        "DisplayStep"  -> disp
    |>
];

(* ::Section:: *)
(*Report*)

ms[ x_? NumberQ ] := ToString @ NumberForm[ 1000. x, { Infinity, 1 } ];
ms[ _ ] := "";

$columns = {
    { "file", #File & },
    { "KB", ToString @ NumberForm[ #Bytes / 1024., { Infinity, 1 } ] & },
    { "steps", ToString @ #Steps & },
    { "cold F", ms @ Lookup[ #, "ColdF" ] & },
    { "cold seq", ms @ Lookup[ #, "ColdSeq" ] & },
    { "first F", ms @ #FirstF & },
    { "warm F", ms @ #WarmF & },
    { "first S", ms @ #FirstS & },
    { "warm S", ms @ #WarmS & },
    { "seq first", ms @ #SeqFirst & },
    { "seq warm", ms @ #SeqWarm & },
    { "disp/step", ms @ #DisplayStep & }
};

$totalKeys = { "FirstF", "WarmF", "FirstS", "WarmS", "SeqFirst", "SeqWarm", "SeqChunk", "SeqDisplay", "SeqFinal" };

markdownTable[ header_List, rows_List ] := StringRiffle[
    Join[
        { "| " <> StringRiffle[ header, " | " ] <> " |", "|" <> StringRiffle[ Prepend[ ConstantArray[ "---:", Length @ header - 1 ], ":---" ], "|" ] <> "|" },
        ( "| " <> StringRiffle[ #, " | " ] <> " |" & ) /@ rows
    ],
    "\n"
];

reportTables[ results_List, meta_Association ] := Module[ { rows, totals, totalRow, coldRows, md },
    rows   = Function[ r, #[[ 2 ]][ r ] & /@ $columns ] /@ results;
    totals = AssociationMap[ Total @ Lookup[ results, # ] &, $totalKeys ];
    totalRow = Join[
        { "**total**", ToString @ NumberForm[ Total @ Lookup[ results, "Bytes" ] / 1024., { Infinity, 1 } ], ToString @ Total @ Lookup[ results, "Steps" ] },
        { "", "" },
        ms /@ Lookup[ totals, { "FirstF", "WarmF", "FirstS", "WarmS", "SeqFirst", "SeqWarm" } ],
        { "" }
    ];
    (* Adversarial files (names starting with "a") can dominate the totals, so also give totals without them: *)
    With[ { normal = Select[ results, ! StringStartsQ[ #File, "a" ] & ] },
        totalRow = {
            totalRow,
            Join[
                { "**total without a-files**", ToString @ NumberForm[ Total @ Lookup[ normal, "Bytes" ] / 1024., { Infinity, 1 } ], ToString @ Total @ Lookup[ normal, "Steps" ] },
                { "", "" },
                ms /@ ( Total @ Lookup[ normal, # ] & /@ { "FirstF", "WarmF", "FirstS", "WarmS", "SeqFirst", "SeqWarm" } ),
                { "" }
            ]
        }
    ];
    md = StringJoin[
        "Chatbook: ", meta[ "Repo" ], " (", ToString @ meta[ "Git", "Branch" ], " ", ToString @ meta[ "Git", "Commit" ], ")\n",
        "Date: ", meta[ "Date" ], ", Wolfram ", ToString @ $VersionNumber, ", ", ToString @ $ProcessorCount, " cores\n",
        "Repetitions: ", ToString @ meta[ "Reps" ], " (F/S), ", ToString @ meta[ "SeqReps" ], " (sequence); chunk size ",
        ToString @ FormatterHarness`$ChunkSize, " characters. Times in ms.\n",
        "Chatbook load (incl. front end start) in the benchmark kernel: ", ms @ meta[ "LoadTime" ], " ms; warm-up: ",
        ms @ meta[ "WarmupTime" ], " ms\n\n",
        markdownTable[ First /@ $columns, Join[ rows, totalRow ] ], "\n\n",
        "Streaming sequence breakdown (seq warm run): writeChunk0 incl. static writes ", ms @ totals[ "SeqChunk" ],
        " ms, dynamic display ", ms @ totals[ "SeqDisplay" ], " ms, final cell ", ms @ totals[ "SeqFinal" ], " ms\n"
    ];
    coldRows = Select[ results, KeyExistsQ[ #, "ColdF" ] || KeyExistsQ[ #, "ColdSeq" ] & ];
    If[ coldRows =!= { },
        md = md <> "\nCold runs (fresh kernel per measurement):\n\n" <> markdownTable[
            { "file", "load", "first F", "load", "seq total", "first step", "final" },
            {
                #File,
                ms @ Lookup[ #, "ColdLoadF" ], ms @ Lookup[ #, "ColdF" ],
                ms @ Lookup[ #, "ColdLoadSeq" ], ms @ Lookup[ #, "ColdSeq" ], ms @ Lookup[ #, "ColdFirstStep" ], ms @ Lookup[ #, "ColdSeqFinal" ]
            } & /@ coldRows
        ] <> "\n"
    ];
    md
];

baselineReport[ results_List, baseline_Association ] := Module[ { base, keys, rows, ratio },
    base  = Association[ #File -> # & /@ baseline[ "Results" ] ];
    keys  = { "ColdF", "ColdSeq", "FirstF", "WarmF", "FirstS", "WarmS", "SeqFirst", "SeqWarm", "DisplayStep" };
    ratio[ a_? NumberQ, b_? NumberQ ] /; b > 0 := ToString @ NumberForm[ a / b, { Infinity, 2 } ];
    ratio[ ___ ] := "";
    rows = Function[ r,
        Prepend[ ratio[ Lookup[ r, # ], Lookup[ Lookup[ base, r[ "File" ], <| |> ], # ] ] & /@ keys, r[ "File" ] ]
    ] /@ Select[ results, KeyExistsQ[ base, #File ] & ];
    StringJoin[
        "\nRatios new/baseline (", baseline[ "Meta", "Repo" ], " ", ToString @ baseline[ "Meta", "Git", "Commit" ], "), < 1 is faster:\n\n",
        markdownTable[ Prepend[ keys, "file" ], rows ], "\n\n",
        "Totals: ",
        StringRiffle[
            Function[ k,
                With[ { files = Select[ results, KeyExistsQ[ base, #File ] && NumberQ @ Lookup[ #, k ] && NumberQ @ Lookup[ base[ #File ], k ] & ] },
                    k <> " " <> ratio[ Total @ Lookup[ files, k ], Total[ Lookup[ base[ #File ], k ] & /@ files ] ]
                ]
            ] /@ keys,
            ", "
        ],
        "\n"
    ]
];

(* ::Section:: *)
(*Main*)

Block[ { $AllowInternet = False }, Module[ { args, opts, files, coldSpec, coldFiles, reps, seqReps, out, cold = <| |>, tLoad, tWarm, results, meta, md, warmup },
    args = FormatterHarness`ParseArgs @ Rest @ $ScriptCommandLine;
    opts = args[ "Options" ];

    If[ StringQ @ opts[ "cold-worker" ],
        coldWorker[ opts[ "cold-worker" ], First @ args[ "Positional" ] ];
        Exit[ 0 ]
    ];

    files   = FormatterHarness`FilterFiles[ FormatterHarness`CorpusFiles[ ], Lookup[ opts, "files", None ] ];
    reps    = ToExpression @ Lookup[ opts, "reps", "10" ];
    seqReps = ToExpression @ Lookup[ opts, "seq-reps", "3" ];
    out     = FileNameJoin @ { FormatterHarness`$HarnessDir, Lookup[ opts, "out", "bench-latest" ] };
    coldSpec = Lookup[ opts, "cold", "default" ];
    coldFiles = Switch[ coldSpec,
        "none", { },
        "all", files,
        "default", Select[ files, MemberQ[ $defaultColdFiles, FileNameTake @ # ] & ],
        _, FormatterHarness`FilterFiles[ files, coldSpec ]
    ];

    (* Cold runs first, one at a time, so that they don't compete with each other or with the main run: *)
    If[ coldFiles =!= { }, Print[ "Cold runs (", Length @ coldFiles, " files, 2 kernels each)..." ] ];
    Do[
        With[ { f = Replace[ runColdWorker[ "finished", file ], Except[ _Association ] -> <| |> ],
                s = Replace[ runColdWorker[ "stream", file ], Except[ _Association ] -> <| |> ] },
            cold[ FileNameTake @ file ] = DeleteMissing @ <|
                "ColdLoadF"     -> Lookup[ f, "Load", Missing[ ] ],
                "ColdF"         -> Lookup[ f, "First", Missing[ ] ],
                "ColdLoadSeq"   -> Lookup[ s, "Load", Missing[ ] ],
                "ColdSeq"       -> Lookup[ s, "Sequence", Missing[ ] ],
                "ColdFirstStep" -> Lookup[ s, "FirstStep", Missing[ ] ],
                "ColdSeqFinal"  -> Lookup[ s, "Final", Missing[ ] ]
            |>;
            Print[ "  ", FileNameTake @ file, ": ", cold[ FileNameTake @ file ] ]
        ],
        { file, coldFiles }
    ];

    tLoad = First @ AbsoluteTiming @ FormatterHarness`LoadChatbook[ ];
    warmup = FormatterHarness`ReadCorpusFile @ FileNameJoin @ { FormatterHarness`$HarnessDir, "warmup.md" };
    tWarm = First @ AbsoluteTiming @ FormatterHarness`WithFormatterEnvironment[ "warmup.md",
        FormatterHarness`FormatFinished @ warmup;
        FormatterHarness`FormatStreaming @ warmup;
        FormatterHarness`SimulateStream @ warmup
    ];
    Print[ "Loaded in ", ms @ tLoad, " ms, warm-up ", ms @ tWarm, " ms. Benchmarking ", Length @ files, " files..." ];

    results = Map[
        Function[ file,
            With[ { r = benchFile[ file, reps, seqReps ] },
                Print[ "  ", StringPadRight[ r[ "File" ], 34 ], " warm F ", ms @ r[ "WarmF" ], " ms, warm S ", ms @ r[ "WarmS" ], " ms, seq ", ms @ r[ "SeqWarm" ], " ms" ];
                Join[ r, Lookup[ cold, r[ "File" ], <| |> ] ]
            ]
        ],
        files
    ];

    meta = <|
        "Repo"       -> FormatterHarness`$Repo,
        "Git"        -> FormatterHarness`GitInfo @ FormatterHarness`$Repo,
        "Date"       -> DateString[ "ISODateTime" ],
        "Reps"       -> reps,
        "SeqReps"    -> seqReps,
        "LoadTime"   -> tLoad,
        "WarmupTime" -> tWarm,
        "Machine"    -> $MachineName
    |>;

    md = reportTables[ results, meta ];
    If[ StringQ @ opts[ "baseline" ],
        md = md <> baselineReport[ results, FormatterHarness`ReadWXF @ ExpandFileName @ opts[ "baseline" ] ]
    ];

    FormatterHarness`WriteWXF[ out <> ".wxf", <| "Meta" -> meta, "Results" -> results |> ];
    Export[ out <> ".md", md, "Text" ];
    Print[ "" ];
    Print[ md ];
    Print[ "Wrote ", out, ".wxf and ", out, ".md" ];
] ];
