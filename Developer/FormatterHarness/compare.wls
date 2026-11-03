#!/usr/bin/env wolframscript
(* ::Package:: *)

(* Usage: ./run.sh compare [golden.wxf] [--strings] [--files=pattern,...] [--max=N]

   Recomputes the outputs in a golden file (see snapshot.wls) with the Chatbook code at $CHATBOOK_REPO and compares
   them. Prints one line per difference with the first differing subexpression, and a summary.

   Checks per corpus file:
     Finished, Streaming          FormatChatOutput boxes
     StreamSteps, StreamFinal     simulated streaming display (first differing step is shown) and final cell
     FinishedString, StreamingString, StreamFinalString
                                  CellToString serialization of the above
     Messages                     messages issued while formatting
   --strings compares only the serializations (and messages).
   Exit code: 0 if everything is identical, 1 otherwise. *)

Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "harness.wl" };

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::ReturnAmbiguous:: *)

(* The first step of the simulated stream that differs, with the number of differing steps: *)
streamDiff[ gold_Association, cur_Association ] := Module[ { gs, cs, n, diffs, first, i, d, part },
    gs = gold[ "Steps" ];
    cs = cur[ "Steps" ];
    n  = Min[ Length @ gs, Length @ cs ];
    diffs = Select[ Range @ n, gs[[ # ]] =!= cs[[ # ]] & ];
    If[ diffs === { } && Length @ gs === Length @ cs, Return @ None ];
    If[ diffs === { },
        Return[ "    number of steps differs: " <> ToString @ Length @ gs <> " expected, " <> ToString @ Length @ cs <> " actual" ]
    ];
    i = First @ diffs;
    { part, d } = Which[
        gs[[ i, "Static" ]] =!= cs[[ i, "Static" ]],
            { "static cells written", FormatterHarness`FirstDifference[ gs[[ i, "Static" ]], cs[[ i, "Static" ]] ] },
        gs[[ i, "Display" ]] =!= cs[[ i, "Display" ]],
            { "dynamic display", FormatterHarness`FirstDifference[ gs[[ i, "Display" ]], cs[[ i, "Display" ]] ] },
        True,
            { "step data", FormatterHarness`FirstDifference[ gs[[ i ]], cs[[ i ]] ] }
    ];
    StringJoin[
        "    ", ToString @ Length @ diffs, " of ", ToString @ n, " steps differ; first at step ", ToString @ i,
        " (after ", ToString @ gs[[ i, "Length" ]], " characters), in the ", part, ":\n",
        FormatterHarness`FormatDifference @ d
    ]
];

Block[ { $AllowInternet = False }, Module[
    {
        args, opts, goldenFile, golden, items, records, files, names, stringsOnly, maxShown, shown = 0, results = { },
        report, corpus, start
    },

    args        = FormatterHarness`ParseArgs @ Rest @ $ScriptCommandLine;
    opts        = args[ "Options" ];
    goldenFile  = ExpandFileName @ First[ args[ "Positional" ], FileNameJoin @ { FormatterHarness`$HarnessDir, "golden.wxf" } ];
    stringsOnly = TrueQ @ opts[ "strings" ];
    maxShown    = ToExpression @ Lookup[ opts, "max", "50" ];

    If[ ! FileExistsQ @ goldenFile, FormatterHarness`Abort2[ "Golden file not found: ", goldenFile ] ];
    golden = FormatterHarness`ReadWXF @ goldenFile;
    If[ ! MatchQ[ golden, KeyValuePattern[ "Format" -> "FormatterGolden/1" ] ], FormatterHarness`Abort2[ "Not a golden file: ", goldenFile ] ];
    items   = golden[ "Pool" ];
    records = golden[ "Records" ];

    FormatterHarness`LoadChatbook[ ];
    Print[ "Golden:   ", goldenFile, "  (", golden[ "Meta", "Repo" ], " ", golden[ "Meta", "Git", "Commit" ], ", ", golden[ "Meta", "Created" ], ")" ];
    Print[ "Chatbook: ", FormatterHarness`$Repo, "  ", FormatterHarness`GitInfo @ FormatterHarness`$Repo ];
    Print[ "Mode:     ", If[ stringsOnly, "CellToString serialization only", "boxes and serialization" ] ];
    Print[ "" ];

    corpus = AssociationMap[ FileNameJoin @ { FormatterHarness`$CorpusDir, # } &, Keys @ records ];
    names  = FileNameTake /@ FormatterHarness`FilterFiles[ Values @ corpus, Lookup[ opts, "files", None ] ];
    Scan[
        If[ ! FileExistsQ @ corpus @ #, Print[ "MISSING corpus file for golden record: ", # ] ] &,
        names
    ];
    names = Select[ names, FileExistsQ @ corpus @ # & ];
    Scan[
        Print[ "NOTE: corpus file not in golden (skipped): ", FileNameTake @ # ] &,
        Complement[ FormatterHarness`CorpusFiles[ ], Values @ corpus ]
    ];

    (* Records the outcome of one check and prints its difference: *)
    report[ name_, mode_, same_, detail_ ] := (
        AppendTo[ results, <| "File" -> name, "Mode" -> mode, "Same" -> same |> ];
        If[ ! same && shown < maxShown,
            shown++;
            Print[ "DIFF ", name, " [", mode, "]" ];
            Print[ detail ];
            Print[ "" ]
        ]
    );
    SetAttributes[ report, HoldAll ];

    start = AbsoluteTime[ ];
    Do[
        Module[ { gold, cur, stream, check, checkString },
            gold = FormatterHarness`DecodeRecord[ items, records @ name ];
            cur  = FormatterHarness`SnapshotDocument[ corpus @ name, "Stream" -> KeyExistsQ[ gold, "Stream" ] ];

            If[ gold[ "InputHash" ] =!= cur[ "InputHash" ],
                Print[ "WARNING: ", name, " changed since the golden file was made; differences are expected" ]
            ];

            check[ mode_, a_, b_ ] := With[ { d = FormatterHarness`FirstDifference[ a, b ] },
                report[ name, mode, d === None, FormatterHarness`FormatDifference @ d ]
            ];
            checkString[ mode_, a_, b_ ] := report[ name, mode, a === b, FormatterHarness`StringDifference[ a, b ] ];

            If[ ! stringsOnly,
                check[ "Finished", gold[ "Finished" ], cur[ "Finished" ] ];
                check[ "Streaming", gold[ "Streaming" ], cur[ "Streaming" ] ]
            ];
            checkString[ "FinishedString", gold[ "FinishedString" ], cur[ "FinishedString" ] ];
            checkString[ "StreamingString", gold[ "StreamingString" ], cur[ "StreamingString" ] ];

            If[ AssociationQ @ gold[ "Stream" ],
                stream = streamDiff[ gold[ "Stream" ], cur[ "Stream" ] ];
                If[ ! stringsOnly,
                    report[ name, "StreamSteps", stream === None, stream ];
                    check[ "StreamFinal", gold[ "Stream", "Final" ], cur[ "Stream", "Final" ] ]
                ];
                checkString[ "StreamFinalString", gold[ "Stream", "FinalString" ], cur[ "Stream", "FinalString" ] ]
            ];

            report[
                name,
                "Messages",
                gold[ "Messages" ] === cur[ "Messages" ],
                "    expected: " <> ToString[ gold[ "Messages" ], InputForm ] <> "\n    actual:   " <> ToString[ cur[ "Messages" ], InputForm ]
            ]
        ],
        { name, names }
    ];

    Print[ "==================== Summary ====================" ];
    Print[ "Files: ", Length @ names, "   checks: ", Length @ results, "   time: ", Round[ AbsoluteTime[ ] - start ], " s" ];
    Print[ Count[ results, KeyValuePattern[ "Same" -> True ] ], " identical / ", Count[ results, KeyValuePattern[ "Same" -> False ] ], " different" ];
    KeyValueMap[
        Print[ "  ", StringPadRight[ #1, 18 ], Count[ #2, True ], " identical / ", Count[ #2, False ], " different" ] &,
        GroupBy[ results, #Mode &, Lookup[ #, "Same" ] & ]
    ];
    With[ { bad = DeleteDuplicates[ #File & /@ Select[ results, ! #Same & ] ] },
        If[ bad =!= { }, Print[ "Files with differences: ", StringRiffle[ bad, ", " ] ] ]
    ];
    If[ shown >= maxShown && Count[ results, KeyValuePattern[ "Same" -> False ] ] > shown,
        Print[ "(only the first ", maxShown, " differences were printed; use --max=N to see more)" ]
    ];
    Exit @ If[ AllTrue[ results, #Same & ], 0, 1 ]
] ];

(* :!CodeAnalysis::EndBlock:: *)
