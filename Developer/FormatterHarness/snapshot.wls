#!/usr/bin/env wolframscript
(* ::Package:: *)

(* Usage: ./run.sh snapshot [out.wxf] [--files=pattern,...] [--no-stream]

   Formats every corpus file with the Chatbook code at $CHATBOOK_REPO and writes a golden file containing, per file:
     - "Finished" and "Streaming": FormatChatOutput[md, <| "Status" -> ... |>]
     - "FinishedString" and "StreamingString": the CellToString serialization of those
     - "Stream": the simulated streaming display (static cells written and the dynamic display after each chunk) and
       the final reformatted cell, plus its serialization
     - "Messages": messages issued in each mode
   Outputs are normalized (see NormalizeOutput in harness.wl). Default output: golden.wxf next to this script. *)

Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "harness.wl" };

Block[ { $AllowInternet = False }, Module[ { args, opts, out, files, dir, pool = <| |>, records = <| |>, golden, start, withMsgs = { } },

    args  = FormatterHarness`ParseArgs @ Rest @ $ScriptCommandLine;
    opts  = args[ "Options" ];
    out   = ExpandFileName @ First[ args[ "Positional" ], FileNameJoin @ { FormatterHarness`$HarnessDir, "golden.wxf" } ];
    files = FormatterHarness`FilterFiles[ FormatterHarness`CorpusFiles[ ], Lookup[ opts, "files", None ] ];
    If[ files === { }, FormatterHarness`Abort2[ "No corpus files selected" ] ];

    dir = FormatterHarness`LoadChatbook[ ];
    Print[ "Chatbook: ", dir, "  ", FormatterHarness`GitInfo @ FormatterHarness`$Repo ];
    Print[ "Snapshotting ", Length @ files, " files to ", out ];

    start = AbsoluteTime[ ];
    Do[
        Module[ { name = FileNameTake @ file, t, rec },
            t = First @ AbsoluteTiming[
                rec = FormatterHarness`SnapshotDocument[ file, "Stream" -> ! TrueQ @ opts[ "no-stream" ] ]
            ];
            If[ AnyTrue[ rec[ "Messages" ], # =!= { } & ], AppendTo[ withMsgs, name -> DeleteCases[ rec[ "Messages" ], { } ] ] ];
            records[ name ] = FormatterHarness`EncodeRecord[ pool, rec ];
            Print[
                StringPadRight[ name, 34 ], " ",
                StringPadLeft[ ToString @ Round[ t, 0.01 ], 7 ], " s  ",
                If[ AssociationQ @ rec[ "Stream" ], ToString @ Length @ rec[ "Stream", "Steps" ] <> " steps", "" ]
            ]
        ],
        { file, files }
    ];

    golden = <|
        "Format" -> "FormatterGolden/1",
        "Meta"   -> <|
            "Repo"           -> FormatterHarness`$Repo,
            "Git"            -> FormatterHarness`GitInfo @ FormatterHarness`$Repo,
            "Created"        -> DateString[ "ISODateTime" ],
            "WolframVersion" -> $VersionNumber,
            "ChunkSize"      -> FormatterHarness`$ChunkSize,
            "Stream"         -> ! TrueQ @ opts[ "no-stream" ]
        |>,
        "Pool"    -> FormatterHarness`PoolList @ pool,
        "Records" -> records
    |>;

    FormatterHarness`WriteWXF[ out, golden ];

    Print[ "Wrote ", out, ": ", Length @ records, " files, ", Length @ pool, " distinct TextData items, ",
           Round[ FileByteCount @ out / 1024. ], " KB, ", Round[ AbsoluteTime[ ] - start ], " s" ];
    If[ withMsgs =!= { },
        Print[ "Messages were issued for these files (recorded in the golden file):" ];
        Scan[ Print[ "  ", #[[ 1 ]], ": ", ToString[ #[[ 2 ]], InputForm ] ] &, withMsgs ]
    ];
] ];
