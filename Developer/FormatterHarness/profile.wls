#!/usr/bin/env wolframscript
(* ::Package:: *)

(* Usage: ./run.sh profile [--files=pattern,...] [--out=NAME]

   Hot-spot breakdown of the CURRENT formatter (it instruments private functions of Formatting.wl and SendChat.wl by
   name, so it only works for code that still has them; functions that don't exist are skipped).

   Each instrumented function's calls are timed, and the time is split into self time (excluding time in other
   instrumented functions), so the buckets add up to the total. Three scenarios, each over the corpus, in a kernel
   warmed up on warmup.md, with each file formatted once (new content, per-response caches reset):
     Finished    FormatChatOutput[md, <| "Status" -> "Finished" |>]
     Streaming   FormatChatOutput[md, <| "Status" -> "Streaming" |>]
     Sequence    the simulated streaming sequence including static writes and the final cell
   Writes NAME.md (default profile-latest.md). Instrumentation adds overhead to small, frequent calls, so compare the
   instrumented total with the uninstrumented one (also measured). *)

Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "harness.wl" };

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::ReturnAmbiguous:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

$fmt  = "Wolfram`Chatbook`Formatting`Private`";
$send = "Wolfram`Chatbook`SendChat`Private`";
$cmn  = "Wolfram`Chatbook`Common`";

(* { symbol name, label } where a label of Automatic means the short symbol name: *)
$instrumented = {
    { $cmn  <> "autoCorrect",                "autoCorrect (LLM auto-correction rules)" },
    { $fmt  <> "importHTMLEntities",         "importHTMLEntities" },
    { $fmt  <> "importHTMLEntity",           "importHTMLEntity (ImportString HTML, memoized)" },
    { $fmt  <> "reformatTextData0",          "reformatTextData0 self: top-level StringSplit with $textDataFormatRules" },
    { $fmt  <> "reformatTextDataEscaped",    "reformatTextDataEscaped self: escaped-markdown path" },
    { $fmt  <> "reformatTextBeforeCodeBlock", Automatic },
    { $fmt  <> "splitToolCallSpacing",       Automatic },
    { $fmt  <> "discardBadToolCalls",        Automatic },
    { $fmt  <> "makeResultCell",             "makeResultCell self ($resultCellCache lookup)" },
    { $fmt  <> "makeResultCell0",            "ITEM" },
    { $fmt  <> "formatTextString",           "formatTextString self: StringSplit with $stringFormatRules" },
    { $fmt  <> "styleBox",                   Automatic },
    { $fmt  <> "makeCodeBlockCell",          Automatic },
    { $fmt  <> "cachedCodeBlockCell",        Automatic },
    { $fmt  <> "makeInteractiveCodeCell",    "makeInteractiveCodeCell self (code block cells)" },
    { $fmt  <> "parseCellGroupBlock",        "parseCellGroupBlock (In/Out transcript split)" },
    { $fmt  <> "wlStringToBoxes",            "wlStringToBoxes self" },
    { $cmn  <> "preprocessSandboxString",    Automatic },
    { $fmt  <> "autoCorrectWLCodeBlock",     "autoCorrectWLCodeBlock (CodeCheckFix, memoized)" },
    { $cmn  <> "stringToBoxes",              "stringToBoxes (front end ReparseBoxStructurePacket)" },
    { $cmn  <> "inlineExpressionURIs",       Automatic },
    { $fmt  <> "formatSpecialBoxes",         "formatSpecialBoxes self (StringReplace/ReplaceAll for special boxes)" },
    { $fmt  <> "formatNLInputSlow",          "formatNLInputSlow (WolframAlpha, offline here)" },
    { $fmt  <> "formatNLInputFast",          Automatic },
    { $fmt  <> "formatResourceFunctionSlow", Automatic },
    { $fmt  <> "formatResourceFunctionFast", Automatic },
    { $fmt  <> "formatPacletSymbol",         Automatic },
    { $fmt  <> "formatEntityBoxes",          Automatic },
    { $fmt  <> "formatDateObjectBoxes",      Automatic },
    { $fmt  <> "makeInlineCodeCell",         Automatic },
    { $fmt  <> "makeInlineWL",               Automatic },
    { $fmt  <> "almostCertainlyWLCodeQ",     Automatic },
    { $cmn  <> "makeTeXBoxes",               "makeTeXBoxes (TeX math)" },
    { $fmt  <> "toTeXBoxes",                 Automatic },
    { $fmt  <> "makeTableCell",              Automatic },
    { $fmt  <> "textTableForm",              "textTableForm (TableForm + ToBoxes)" },
    { $fmt  <> "formatRaw",                  "formatRaw (table cell text)" },
    { $fmt  <> "inlineToolCall",             Automatic },
    { $fmt  <> "parseToolCallString",        Automatic },
    { $fmt  <> "makeToolCallBoxLabel",       "makeToolCallBoxLabel (tool call boxes)" },
    { $fmt  <> "makeInlineToolCallCell",     Automatic },
    { $fmt  <> "image",                      "image (incl. Import of local files)" },
    { $fmt  <> "markdownImageBoxes",         Automatic },
    { $fmt  <> "hyperlink",                  Automatic },
    { $fmt  <> "formatThoughts",             Automatic },
    { $fmt  <> "thoughtsLabel",              Automatic },
    { $fmt  <> "makeDiscardedMaterialCell",  Automatic },
    { $fmt  <> "inlineSection",              Automatic },
    { $fmt  <> "formatTextToBoxes",          Automatic },
    { $fmt  <> "joinAdjacentStrings",        Automatic },
    { $send <> "writeChunk0",                "writeChunk0 self (SendChat chunk handler)" },
    { $send <> "appendStringContent",        "appendStringContent self (convertUTF8, append)" },
    { $send <> "splitDynamicContent",        "splitDynamicContent (static/dynamic split)" },
    { $send <> "writeDynamicChunkAsStatic",  "writeDynamicChunkAsStatic self" },
    { $send <> "dynamicTextDisplay",         "dynamicTextDisplay self" },
    { $send <> "dynamicProgressIndicatorQ",  Automatic },
    { $send <> "conformToTextData",          Automatic },
    { "Wolfram`Chatbook`FormatChatOutput",   "FormatChatOutput self" }
};

itemLabel[ h_[ lang_String, code_String ] ] /; SymbolName @ Unevaluated @ h === "codeBlockCell" :=
    "item: code block, " <> Which[
        TrueQ @ Symbol[ $fmt <> "wolframLanguageQ" ][ lang ], "Wolfram Language",
        TrueQ @ Symbol[ $fmt <> "externalLanguageQ" ][ lang ], "external language",
        True, "other language"
    ];
itemLabel[ _String ] := "item: text (formatTextString)";
itemLabel[ h_[ ___ ] ] := "item: " <> SymbolName @ Unevaluated @ h;
itemLabel[ other_ ] := "item: other";

(* ::Section:: *)
(*Instrumentation*)

$profile   = <| |>;
$childTime = 0.;

SetAttributes[ profiled, HoldRest ];
profiled[ label_String, eval_ ] := Module[ { t0, result, elapsed, saved = $childTime },
    $childTime = 0.;
    t0 = SessionTime[ ];
    result = eval;
    elapsed = SessionTime[ ] - t0;
    $profile[ label ] = Lookup[ $profile, label, { 0, 0. } ] + { 1, elapsed - $childTime };
    $childTime = saved + elapsed;
    result
];

(* Moves the definitions of f to a new symbol and makes f a timing wrapper around it. Recursive calls in the
   definitions still go through f, so they are timed separately. *)
instrument[ HoldComplete[ f_Symbol ], label_ ] := Module[ { dv, attrs },
    dv = DownValues @ f;
    If[ dv === { }, Return @ False ];
    attrs = Attributes @ f;
    With[ { o = Unique[ "FormatterProfileOriginal" ], l = label },
        SetAttributes[ o, DeleteCases[ attrs, Protected | ReadProtected | Locked ] ];
        DownValues[ o ] = Replace[
            dv,
            (* Conditions written on the left-hand side are part of the stored pattern, so replace f anywhere in it: *)
            HoldPattern[ lhs_ :> rhs_ ] :> ( ReplaceAll[ lhs, HoldPattern[ f ] :> o ] :> rhs ),
            { 1 }
        ];
        Unprotect @ f;
        DownValues[ f ] = { };
        If[ l === "ITEM",
            f[ args___ ] := profiled[ itemLabel @ args, o @ args ],
            f[ args___ ] := profiled[ l, o @ args ]
        ]
    ];
    True
];

withInstrumentation // Attributes = { HoldAll };
withInstrumentation[ eval_ ] := Module[ { held, existing },
    existing = Select[ $instrumented, Names[ First @ # ] =!= { } & ];
    held = ToExpression[ First @ #, InputForm, HoldComplete ] & /@ existing;
    Replace[
        Join @@ held,
        HoldComplete[ syms___ ] :> Internal`InheritedBlock[ { syms },
            MapThread[
                instrument[ #1, Replace[ #2[[ 2 ]], Automatic :> Last @ StringSplit[ #2[[ 1 ]], "`" ] ] ] &,
                { held, existing }
            ];
            eval
        ]
    ]
];

(* ::Section:: *)
(*Main*)

runScenario[ files_List, scenario_String ] := Module[ { f },
    f = Switch[ scenario,
        "Finished", FormatterHarness`FormatFinished,
        "Streaming", FormatterHarness`FormatStreaming,
        "Sequence", FormatterHarness`SimulateStream
    ];
    Total @ Map[
        Function[ file,
            With[ { text = FormatterHarness`ReadCorpusFile @ file },
                FormatterHarness`WithFormatterEnvironment[ FileNameTake @ file, First @ AbsoluteTiming @ f @ text ]
            ]
        ],
        files
    ]
];

ms[ x_ ] := ToString @ NumberForm[ 1000. x, { Infinity, 1 } ];

(* The instrumented code must give the same results, otherwise the profile is meaningless: *)
checkSame[ file_, scenario_ ] := Module[ { text = FormatterHarness`ReadCorpusFile @ file, f, a, b },
    f = Switch[ scenario,
        "Finished", FormatterHarness`FormatFinished,
        "Streaming", FormatterHarness`FormatStreaming,
        "Sequence", KeyTake[ FormatterHarness`SimulateStream @ #, { "Steps", "Final" } ] &
    ];
    a = FormatterHarness`WithFormatterEnvironment[ FileNameTake @ file, f @ text ];
    b = withInstrumentation @ FormatterHarness`WithFormatterEnvironment[ FileNameTake @ file, f @ text ];
    If[ a =!= b, Print[ "WARNING: instrumented results differ for ", FileNameTake @ file, " (", scenario, ")" ] ]
];

Block[ { $AllowInternet = False }, Module[ { args, opts, files, out, plain, prof, md = "", warm },
    args  = FormatterHarness`ParseArgs @ Rest @ $ScriptCommandLine;
    opts  = args[ "Options" ];
    files = FormatterHarness`FilterFiles[ FormatterHarness`CorpusFiles[ ], Lookup[ opts, "files", None ] ];
    out   = FileNameJoin @ { FormatterHarness`$HarnessDir, Lookup[ opts, "out", "profile-latest" ] <> ".md" };

    FormatterHarness`LoadChatbook[ ];
    warm = FormatterHarness`ReadCorpusFile @ FileNameJoin @ { FormatterHarness`$HarnessDir, "warmup.md" };
    FormatterHarness`WithFormatterEnvironment[ "warmup.md",
        FormatterHarness`FormatFinished @ warm; FormatterHarness`FormatStreaming @ warm; FormatterHarness`SimulateStream @ warm
    ];

    md = "Profile of " <> FormatterHarness`$Repo <> " (" <> ToString @ FormatterHarness`GitInfo[ FormatterHarness`$Repo ][ "Commit" ] <>
         "), " <> ToString @ Length @ files <> " files, " <> DateString[ "ISODateTime" ] <> "\n";

    Do[
        (* Each scenario runs twice: once uninstrumented for reference, then instrumented. Both see new content for
           session-memoized functions only in the first of the two runs, so run the instrumented one first: *)
        Module[ { total, rows, sum },
            checkSame[ First @ files, scenario ];
            $profile = <| |>;
            $childTime = 0.;
            total = withInstrumentation @ runScenario[ files, scenario ];
            plain = runScenario[ files, scenario ];
            sum   = Total[ Last /@ Values @ $profile ];
            rows  = ReverseSortBy[ KeyValueMap[ { #1, #2[[ 1 ]], #2[[ 2 ]] } &, $profile ], Last ];
            md = md <> "\n### " <> scenario <> "\n\n" <>
                "Instrumented total " <> ms @ total <> " ms (sum of buckets " <> ms @ sum <> " ms); repeated without instrumentation " <>
                ms @ plain <> " ms (memoized results are reused in that run).\n\n" <>
                "| function / item type | calls | self ms | % |\n|:---|---:|---:|---:|\n" <>
                StringRiffle[
                    Function[ r,
                        "| " <> StringReplace[ r[[ 1 ]], "|" -> "\\|" ] <> " | " <> ToString @ r[[ 2 ]] <> " | " <> ms @ r[[ 3 ]] <> " | " <>
                            ToString @ NumberForm[ 100. r[[ 3 ]] / sum, { Infinity, 1 } ] <> " |"
                    ] /@ Select[ rows, #[[ 3 ]] >= 0.0005 * sum & ],
                    "\n"
                ] <> "\n"
        ],
        { scenario, { "Finished", "Streaming", "Sequence" } }
    ];

    Export[ out, md, "Text" ];
    Print[ md ];
    Print[ "Wrote ", out ];
] ];

(* :!CodeAnalysis::EndBlock:: *)
