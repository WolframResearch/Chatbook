(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingToolCalls.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingToolCalls.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Inputs, tools and helpers used by the tests below.

   Notes for these tests:
   - While streaming, formatted parts are cached by their source text (and not by $ChatHandlerData), so every streaming
     test uses a tool call string that no other test uses (unique ENDRESULT IDs).
   - The default tool formatter shows parameters with the ClickToCopy resource function, which is only inlined in the
     built paclet. Tests that display tool parameters with it replace it with a stand-in to stay offline.
*)
VerificationTest[
    (* A finished tool call, as it appears in a response after Chatbook has evaluated the tool and appended the
       result. The text between "TOOLCALL:" and "RESULT" is what the LLM wrote: *)
    tcWebFetcher[ id_String ] := StringJoin[
        "TOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL\n",
        "RESULT\nok\nENDRESULT(", id, ")"
    ];

    (* The "Parameters" tagging rule of a web_fetcher tool call that's only parsed from its text: *)
    $tcWebFetcherQuery = "web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL";

    (* The TextData items of formatted output, with invisible string differences removed and cells replaced by their
       style names: *)
    tcStyles[ md_String ] := tcStyles[ md, "Finished" ];
    tcStyles[ md_String, status_String ] :=
        Replace[ NormalizeTextData @ FormatMarkdown[ md, status ], Cell[ _, style_String, ___ ] :> style, { 1 } ];

    (* All tool call and discarded material cells in formatted output: *)
    tcCells[ md_String ] := tcCells[ md, "Finished" ];
    tcCells[ md_String, status_String ] :=
        Cases[ FormatMarkdown[ md, status ], Cell[ _, "InlineToolCall"|"FailedToolCall"|"DiscardedMaterial", ___ ], Infinity ];

    (* The tagging rules of the first tool call cell (with sorted keys). CellToString reads "ToolCall" from these: *)
    tcTags[ md_String ] := tcTags[ md, "Finished" ];
    tcTags[ md_String, status_String ] := FirstCase[
        FormatMarkdown[ md, status ],
        Cell[ _, "InlineToolCall"|"FailedToolCall", ___, TaggingRules -> tags_, ___ ] :> KeySort @ tags,
        Missing[ "NoToolCall" ],
        Infinity
    ];

    (* Summarizes what a closed tool call shows:
       - "State": the initial open state (True/False) of a real opener (finished output), "Static" for the placeholder
         that only looks like a closed opener (streaming output), or "Loading" for the plain "Using tool..." label
         that's shown when the tool call can't be parsed
       - "Label": the "Used"/"Using" string resource
       - "Name": the displayed tool name
       - "Icon": the tool icon resource
       - "Progress": whether the active tool progress indicator is shown *)
    tcLabel[ Cell[ BoxData[ boxes_ ], ___ ] ] := tcLabel @ boxes;
    tcLabel[ boxes_ ] := Module[ { row },
        row = FirstCase[ boxes, GridBox[ { { _GraphicsBox, rest___ } }, ___ ] :> { rest }, { }, Infinity ];
        <|
            "State"    -> tcOpenerState @ boxes,
            "Label"    -> FirstCase[ row, FEPrivate`FrontEndResource[ "ChatbookStrings", s_String ] :> s, None, Infinity ],
            "Name"     -> FirstCase[ row, StyleBox[ s_String, ___, FontWeight -> "Plain", ___ ] :> ToExpression @ s, None, Infinity ],
            "Icon"     -> FirstCase[ row, FEPrivate`FrontEndResource[ "ChatbookExpressions", s_String ][ _ ] :> s, None, Infinity ],
            "Progress" -> ! FreeQ[ row, TagBox[ _, "ChatbookActiveToolProgress" ] ]
        |>
    ];

    (* The opener's DynamicModule variable holds its open state (its name is incidental): *)
    tcOpenerState[ DynamicModuleBox[ { Verbatim[ Set ][ _, state: True|False ] }, ___ ] ] := state;
    tcOpenerState[ TagBox[ _, Deploy, ___ ] ] := "Static";
    tcOpenerState[ DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingToolUsingLoading" ], _ ], ___ ] ] := "Loading";
    tcOpenerState[ other_ ] := Head @ other;

    (* The labels of the tabs in an expanded tool call and the selected tab: *)
    tcTabs[ boxes_ ] := FirstCase[
        boxes,
        TabViewBox[ tabs_, selected_, ___ ] :> { tabs[[ All, 2, 1 ]], selected },
        Missing[ "NoTabs" ],
        Infinity
    ];

    (* The raw tool call text shown in the "Raw" tab: *)
    tcRawView[ boxes_ ] := FirstCase[
        boxes,
        Cell[ BoxData @ PaneBox[ PaneBox[ s_String, ___ ], ___ ], "Text", "RawToolCall", ___ ] :> ToExpression @ s,
        Missing[ "NoRawView" ],
        Infinity
    ];

    (* The contents of the INPUT and OUTPUT sections of the "Interpreted" tab: *)
    tcInterpretedView[ boxes_ ] := FirstCase[
        boxes,
        HoldPattern[
            "\"Interpreted\"" -> FrameBox[
                TagBox[
                    GridBox[
                        {
                            { ItemBox[ PaneBox[ StyleBox[ "\"INPUT\"", ___ ], ___ ], ___ ] },
                            { FrameBox[ input_, ___ ] },
                            { ItemBox[ PaneBox[ StyleBox[ "\"OUTPUT\"", ___ ], ___ ], ___ ] },
                            { FrameBox[ output_, ___ ] }
                        },
                        ___
                    ],
                    "Column"
                ],
                ___
            ]
        ] :> <| "Input" -> tcSection @ input, "Output" -> tcSection @ output |>,
        Missing[ "NoInterpretedView" ],
        Infinity
    ];

    (* Parameter grids give their rows, the output section gives the formatted result (with invisible string
       differences in formatted markdown removed): *)
    tcSection[ TagBox[ GridBox[ rows_, ___ ], "Grid" ] ] := rows;
    tcSection[ InterpretationBox[ Cell[ BoxData @ PaneBox[ PaneBox[ content_, ___ ], ___ ], ___ ], ___ ] ] :=
        tcNormalizeCell @ content;
    tcSection[ InterpretationBox[ cell_Cell, ___ ] ] := cell;
    tcSection[ other_ ] := other;

    tcNormalizeCell[ Cell[ TextData[ items_ ], rest___ ] ] := Cell[ TextData @ NormalizeTextData @ Flatten @ { items }, rest ];
    tcNormalizeCell[ other_ ] := other;

    (* The content of an opener that is compressed until it's viewed (discarded material, or very large content).
       The text of each discarded row is normalized like tcStyles: *)
    tcDiscardedContent[ boxes_ ] := Replace[
        FirstCase[
            boxes,
            HoldPattern @ BaseDecode[ b64_String ] :> BinaryDeserialize @ BaseDecode @ b64,
            Missing[ "NoContent" ],
            Infinity
        ],
        Column[ rows_List, opts___ ] :> Column[ Replace[ rows, RawBoxes[ cell_ ] :> RawBoxes @ tcNormalizeCell @ cell, { 1 } ], opts ]
    ];

    (* Serializes formatted output back to markdown, ignoring spaces before line breaks: *)
    tcRoundTrip[ md_String ] := tcRoundTrip[ md, "Finished" ];
    tcRoundTrip[ md_String, status_String ] := StringReplace[ MarkdownRoundTrip[ md, status ], " ".. ~~ "\n" -> "\n" ];

    (* Stand-in for the ClickToCopy resource function: *)
    tcWithClickToCopy // Attributes = { HoldFirst };
    tcWithClickToCopy[ eval_ ] := Block[ { Wolfram`Chatbook`Common`clickToCopy = (Style[ #1, "TCClickToCopy" ] &) }, eval ];

    (* A copy of the built-in Wolfram Language evaluator tool with a stand-in function, so it can give a tool response
       without evaluating code. It keeps the built-in name, display name, short name, icons and formatting function: *)
    tcWLTool = LLMTool @ <|
        Replace[ Wolfram`Chatbook`$DefaultTools[ "WolframLanguageEvaluator" ], HoldPattern @ LLMTool[ as_, ___ ] :> as ],
        "Function" -> ("Out[1]= 2" &)
    |>;

    tcWLResponse = GenerateLLMToolResponse[
        LLMConfiguration @ <| "Tools" -> { tcWLTool } |>,
        LLMToolRequest[ "wolfram_language_evaluator", { "code" -> "1+1" }, "code" ]
    ];

    (* A custom tool that gives its input as the result, with the default ("Inherited") formatting function: *)
    tcEchoTool = Replace[
        LLMTool[ "echo_tool", { "x" -> "String" }, #x & ],
        HoldPattern @ LLMTool[ as_, rest___ ] :>
            LLMTool[ <| as, "DisplayName" -> "Echo Tool", "FormattingFunction" -> Inherited |>, rest ]
    ];

    tcEchoResponse = GenerateLLMToolResponse[
        LLMConfiguration @ <| "Tools" -> { tcEchoTool } |>,
        LLMToolRequest[ "echo_tool", { "x" -> "hi **there**" }, "echo" ]
    ];

    (* Handler data for the "Simple" tool method, where tools are called with commands like "/wl": *)
    $tcSimpleMethod = <|
        "ToolShortNames"       -> <| "wl" -> tcWLTool, "wa" -> Wolfram`Chatbook`$DefaultTools[ "WolframAlpha" ] |>,
        "ChatNotebookSettings" -> <| "ToolMethod" -> "Simple" |>
    |>;
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Definitions@@Tests/FormattingToolCalls.wlt:34,1-195,2"
]

VerificationTest[
    { Head @ tcWLTool, Head @ tcWLResponse, Head @ tcEchoTool, tcEchoResponse[ "Output" ], tcWLResponse[ "Output" ] },
    { LLMTool, LLMToolResponse, LLMTool, "hi **there**", "Out[1]= 2" },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Definitions-Tools@@Tests/FormattingToolCalls.wlt:197,1-202,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TOOLCALL Syntax*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Finished Tool Calls*)

(* A tool call from "TOOLCALL:" up to and including "ENDRESULT(id)" becomes a single "InlineToolCall" cell between
   the text before and after it. The blank lines around it are reduced to single line breaks: *)
VerificationTest[
    tcStyles[ "Before\n\n" <> tcWebFetcher[ "tc0001" ] <> "\n\nAfter" ],
    { "Before\n", "InlineToolCall", "\nAfter" },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Full-Items@@Tests/FormattingToolCalls.wlt:214,1-219,2"
]

(* When the ID isn't in the tool evaluation results (e.g. in a new session), the tool call is parsed from its text.
   The tagging rules keep the raw tool call text (used for serialization), the tool name as written, the display
   name of the matching tool, and the text between "TOOLCALL:" and "RESULT" as "Parameters" (this includes the tool
   name and the ENDARGUMENTS/ENDTOOLCALL lines). Icons and the result are not stored: *)
VerificationTest[
    tcTags[ "Before\n\n" <> tcWebFetcher[ "tc0002" ] <> "\n\nAfter" ],
    KeySort @ <|
        "Name"        -> "web_fetcher",
        "DisplayName" -> "Web Fetcher",
        "ToolCall"    -> tcWebFetcher[ "tc0002" ],
        "Parameters"  -> $tcWebFetcherQuery
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Full-TaggingRules@@Tests/FormattingToolCalls.wlt:225,1-235,2"
]

(* A finished tool call is a closed opener labeled "Used <display name>" with the tool's icon: *)
VerificationTest[
    tcLabel @ First @ tcCells[ "Before\n\n" <> tcWebFetcher[ "tc0003" ] <> "\n\nAfter" ],
    <|
        "State"    -> False,
        "Label"    -> "FormattingToolUsed",
        "Name"     -> "Web Fetcher",
        "Icon"     -> "ToolIconCallWebFetcher",
        "Progress" -> False
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Full-Label@@Tests/FormattingToolCalls.wlt:238,1-249,2"
]

(* The opener's content has two tabs, with "Interpreted" selected. "Raw" shows the raw tool call text: *)
VerificationTest[
    With[ { cell = First @ tcCells @ tcWebFetcher[ "tc0004" ] }, { tcTabs @ cell, tcRawView @ cell } ],
    { { { "\"Raw\"", "\"Interpreted\"" }, 2 }, tcWebFetcher[ "tc0004" ] },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Full-Tabs-And-Raw-View@@Tests/FormattingToolCalls.wlt:252,1-257,2"
]

(* When the parameters are only known as text, "Interpreted" shows them as a "Program" cell, and the result as
   formatted markdown: *)
VerificationTest[
    tcInterpretedView @ First @ tcCells @ tcWebFetcher[ "tc0005" ],
    <|
        "Input"  -> Cell[ $tcWebFetcherQuery, "Program", OrderlessPatternSequence[ FontSize -> 0.75 * Inherited, Background -> None ] ],
        "Output" -> Cell[ TextData @ { "ok" }, "Text", Background -> None ]
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Full-Interpreted-View@@Tests/FormattingToolCalls.wlt:261,1-269,2"
]

(* While streaming, the tool call is a static placeholder that looks like a closed opener (it has no content), with
   the same tagging rules: *)
VerificationTest[
    {
        tcStyles[ "Before\n\n" <> tcWebFetcher[ "tc0006" ] <> "\n\nAfter", "Streaming" ],
        tcLabel @ First @ tcCells[ "Before\n\n" <> tcWebFetcher[ "tc0007" ] <> "\n\nAfter", "Streaming" ],
        tcTags[ "Before\n\n" <> tcWebFetcher[ "tc0008" ] <> "\n\nAfter", "Streaming" ],
        tcTabs @ First @ tcCells[ tcWebFetcher[ "tc0009" ], "Streaming" ]
    },
    {
        { "Before\n", "InlineToolCall", "\nAfter" },
        <|
            "State"    -> "Static",
            "Label"    -> "FormattingToolUsed",
            "Name"     -> "Web Fetcher",
            "Icon"     -> "ToolIconCallWebFetcher",
            "Progress" -> False
        |>,
        KeySort @ <|
            "Name"        -> "web_fetcher",
            "DisplayName" -> "Web Fetcher",
            "ToolCall"    -> tcWebFetcher[ "tc0008" ],
            "Parameters"  -> $tcWebFetcherQuery
        |>,
        Missing[ "NoTabs" ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Full-Streaming@@Tests/FormattingToolCalls.wlt:273,1-299,2"
]

(* Tool calls serialize as their raw text: *)
VerificationTest[
    {
        tcRoundTrip[ "Before\n\n" <> tcWebFetcher[ "tc0010" ] <> "\n\nAfter" ],
        tcRoundTrip[ "Before\n\n" <> tcWebFetcher[ "tc0011" ] <> "\n\nAfter", "Streaming" ]
    },
    {
        "Before\n" <> tcWebFetcher[ "tc0010" ] <> "\nAfter",
        "Before\n" <> tcWebFetcher[ "tc0011" ] <> "\nAfter"
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Full-RoundTrip@@Tests/FormattingToolCalls.wlt:302,1-313,2"
]

(* "ENDRESULT" without an ID also ends a tool call: *)
VerificationTest[
    With[ { tool = "TOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nRESULT\nok\nENDRESULT" },
        {
            tcStyles[ tool <> "\nAfter" ],
            tcTags[ tool <> "\nAfter" ][ "ToolCall" ] === tool,
            tcLabel[ First @ tcCells[ tool <> "\nAfter" ] ][ "Label" ]
        }
    ],
    { { "InlineToolCall", "\nAfter" }, True, "FormattingToolUsed" },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-EndResult-Without-ID@@Tests/FormattingToolCalls.wlt:316,1-327,2"
]

(* An unknown tool is displayed with the name as written and the generic icon: *)
VerificationTest[
    With[ { md = "TOOLCALL: made_up_tool\n{\"x\":\"1\"}\nRESULT\nok\nENDRESULT(tc0012)\n\nDone." },
        { tcLabel @ First @ tcCells @ md, tcTags[ md ][ "DisplayName" ] }
    ],
    {
        <|
            "State"    -> False,
            "Label"    -> "FormattingToolUsed",
            "Name"     -> "made_up_tool",
            "Icon"     -> "ToolIconCallGenericTool",
            "Progress" -> False
        |>,
        "made_up_tool"
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Unknown-Tool@@Tests/FormattingToolCalls.wlt:330,1-346,2"
]

(* The tool name ends at the first line break or "{", so the JSON can be on the same line: *)
VerificationTest[
    tcTags[ "TOOLCALL: web_fetcher {\"url\":\"https://example.com\"}\nRESULT\nok\nENDRESULT(tc0013)" ][[ { "Name", "DisplayName" } ]],
    <| "Name" -> "web_fetcher", "DisplayName" -> "Web Fetcher" |>,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Name-Before-JSON@@Tests/FormattingToolCalls.wlt:349,1-354,2"
]

(* Trailing whitespace after ENDRESULT is not part of the stored tool call text: *)
VerificationTest[
    tcTags[ "Before\n" <> tcWebFetcher[ "tc0014" ] <> "   \nAfter" ][ "ToolCall" ],
    tcWebFetcher[ "tc0014" ],
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Trailing-Whitespace-Trimmed@@Tests/FormattingToolCalls.wlt:357,1-362,2"
]

(* A tool call doesn't have to start on its own line: *)
VerificationTest[
    tcStyles[ "See " <> tcWebFetcher[ "tc0015" ] <> " done" ],
    { "See ", "InlineToolCall", " done" },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Mid-Line@@Tests/FormattingToolCalls.wlt:365,1-370,2"
]

(* Consecutive tool calls are separate cells. One blank line between them becomes a single line break, and more blank
   lines become one blank line: *)
VerificationTest[
    {
        tcStyles[ "A\n\n" <> tcWebFetcher[ "tc0016" ] <> "\n\n" <> tcWebFetcher[ "tc0017" ] <> "\n\nB" ],
        tcStyles[ "A\n" <> tcWebFetcher[ "tc0018" ] <> tcWebFetcher[ "tc0019" ] <> "B" ],
        tcStyles[ "A\n" <> tcWebFetcher[ "tc0020" ] <> "\n\n\n\n" <> tcWebFetcher[ "tc0021" ] <> "B" ],
        tcRoundTrip[ "A\n\n" <> tcWebFetcher[ "tc0022" ] <> "\n\n" <> tcWebFetcher[ "tc0023" ] <> "\n\nB" ],
        tcRoundTrip[ "A\n\n" <> tcWebFetcher[ "tc0024" ] <> "\n\n\n" <> tcWebFetcher[ "tc0025" ] <> "\n\nB" ]
    },
    {
        { "A\n", "InlineToolCall", "\n", "InlineToolCall", "\nB" },
        { "A\n", "InlineToolCall", "InlineToolCall", "B" },
        { "A\n", "InlineToolCall", "\n\n", "InlineToolCall", "B" },
        "A\n" <> tcWebFetcher[ "tc0022" ] <> "\n" <> tcWebFetcher[ "tc0023" ] <> "\nB",
        "A\n" <> tcWebFetcher[ "tc0024" ] <> "\n\n" <> tcWebFetcher[ "tc0025" ] <> "\nB"
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Consecutive@@Tests/FormattingToolCalls.wlt:374,1-391,2"
]

(* A code block in a tool result doesn't end the tool call or become a separate code block: *)
VerificationTest[
    With[ { tool = "TOOLCALL: web_fetcher\n{\"url\":\"x\"}\nRESULT\n```wl\nIn[1]:= 1\n```\nENDRESULT(tc0522)" },
        { tcStyles[ tool <> "\nAfter" ], tcTags[ tool <> "\nAfter" ][ "ToolCall" ] === tool }
    ],
    { { "InlineToolCall", "\nAfter" }, True },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Result-With-Code-Block@@Tests/FormattingToolCalls.wlt:394,1-401,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fenced Tool Calls*)

(* An opening code fence (with or without a language) directly before "TOOLCALL:" is dropped, so the tool call isn't
   shown as a code block, and the stored tool call text doesn't include it. Only the opening fence is consumed, so
   these inputs end with the tool call. *)
VerificationTest[
    {
        tcStyles[ "Text\n```\n" <> tcWebFetcher[ "tc0523" ] ],
        tcTags[ "Text\n```\n" <> tcWebFetcher[ "tc0524" ] ][ "ToolCall" ],
        tcTags[ "```json  \n" <> tcWebFetcher[ "tc0525" ] ][ "ToolCall" ]
    },
    { { "Text\n", "InlineToolCall" }, tcWebFetcher[ "tc0524" ], tcWebFetcher[ "tc0525" ] },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Fence-Prefix-Removed@@Tests/FormattingToolCalls.wlt:410,1-419,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unterminated Tool Calls*)

(* Without ENDRESULT, a tool call extends to the end of the response. Until a result arrives it's labeled "Using
   <display name>" with a progress indicator, and "Parameters" is empty since there's no RESULT yet. This is the
   same in finished output (e.g. when a response stops while a tool is evaluating): *)
VerificationTest[
    With[ { md = "Before\n\nTOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL\n" },
        { tcStyles @ md, tcLabel @ First @ tcCells @ md, tcTags @ md }
    ],
    {
        { "Before\n", "InlineToolCall" },
        <|
            "State"    -> False,
            "Label"    -> "FormattingToolUsing",
            "Name"     -> "Web Fetcher",
            "Icon"     -> "ToolIconCallWebFetcher",
            "Progress" -> True
        |>,
        KeySort @ <|
            "Name"        -> "web_fetcher",
            "DisplayName" -> "Web Fetcher",
            "ToolCall"    -> "TOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL",
            "Parameters"  -> ""
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Unterminated-Finished@@Tests/FormattingToolCalls.wlt:428,1-450,2"
]

(* While streaming, a partial tool call is shown as soon as the tool name and the start of its JSON are known: *)
VerificationTest[
    With[ { md = "Before\n\nTOOLCALL: web_fetcher\n{\"url\":\"https://exa" },
        { tcStyles[ md, "Streaming" ], tcLabel @ First @ tcCells[ md <> "m", "Streaming" ], tcTags[ md <> "mp", "Streaming" ] }
    ],
    {
        { "Before\n", "InlineToolCall" },
        <|
            "State"    -> "Static",
            "Label"    -> "FormattingToolUsing",
            "Name"     -> "Web Fetcher",
            "Icon"     -> "ToolIconCallWebFetcher",
            "Progress" -> True
        |>,
        KeySort @ <|
            "Name"        -> "web_fetcher",
            "DisplayName" -> "Web Fetcher",
            "ToolCall"    -> "TOOLCALL: web_fetcher\n{\"url\":\"https://examp",
            "Parameters"  -> ""
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Unterminated-Streaming@@Tests/FormattingToolCalls.wlt:453,1-475,2"
]

(* A result that is still streaming in (no ENDRESULT yet) still shows "Using", but "Parameters" is known: *)
VerificationTest[
    With[ { md = "TOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\npartial result" },
        { tcLabel[ First @ tcCells[ md, "Streaming" ] ][[ { "Label", "Progress" } ]], tcTags[ md <> "s", "Streaming" ][ "Parameters" ] }
    ],
    { <| "Label" -> "FormattingToolUsing", "Progress" -> True |>, $tcWebFetcherQuery },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Unterminated-Streaming-Result@@Tests/FormattingToolCalls.wlt:478,1-485,2"
]

(* Partial tool calls serialize as the text received so far: *)
VerificationTest[
    tcRoundTrip[ "Before\nTOOLCALL: web_fetcher\n{\"url\":\"ht", "Streaming" ],
    "Before\nTOOLCALL: web_fetcher\n{\"url\":\"ht",
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Unterminated-RoundTrip@@Tests/FormattingToolCalls.wlt:488,1-493,2"
]

(* Before there's a "{" the tool call can't be parsed, so it only shows a "Using tool..." label without an opener,
   and only the tool call text is stored: *)
VerificationTest[
    {
        FormatMarkdown[ "TOOLCALL: web_fetcher" ],
        tcLabel[ First @ tcCells[ "TOOLCALL: web_fetch", "Streaming" ] ][ "State" ],
        tcRoundTrip[ "Text\n\nTOOLCALL: web_fetcher" ]
    },
    {
        {
            Cell[
                BoxData @ DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingToolUsingLoading" ], _ ], ___ ],
                "InlineToolCall",
                OrderlessPatternSequence[ Background -> None, TaggingRules -> <| "ToolCall" -> "TOOLCALL: web_fetcher" |> ]
            ]
        },
        "Loading",
        "Text\nTOOLCALL: web_fetcher"
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-No-Arguments-Loading@@Tests/FormattingToolCalls.wlt:497,1-516,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Neighboring Constructs*)

(* Tool calls are separated from neighboring blocks by single line breaks, and the blocks are still formatted: *)
VerificationTest[
    {
        tcStyles[ "## Heading\n" <> tcWebFetcher[ "tc0026" ] <> "\nText" ],
        tcStyles[ tcWebFetcher[ "tc0027" ] <> "\n## Heading\nText" ],
        tcStyles[ "- item one\n- item two\n" <> tcWebFetcher[ "tc0028" ] <> "\nText" ],
        tcStyles[ tcWebFetcher[ "tc0029" ] <> "\n- item one\n- item two" ],
        tcStyles[ "```wl\n1+1\n```\n" <> tcWebFetcher[ "tc0030" ] <> "\nText" ],
        tcStyles[ tcWebFetcher[ "tc0031" ] <> "\n```wl\n1+1\n```" ],
        tcStyles[ "<think>hmm</think>" <> tcWebFetcher[ "tc0032" ] <> "\nAfter" ],
        tcStyles[ "**Bold** text\n" <> tcWebFetcher[ "tc0033" ] <> "\n*Italic* after" ]
    },
    {
        { "InlineSection", "\n", "InlineToolCall", "\nText" },
        { "InlineToolCall", "\n", "InlineSection", "\nText" },
        { "InlineItem", "\n", "InlineItem", "\n", "InlineToolCall", "\nText" },
        { "InlineToolCall", "\n", "InlineItem", "\n", "InlineItem" },
        { "ChatCodeBlock", "\n", "InlineToolCall", "\nText" },
        { "InlineToolCall", "\n", "ChatCodeBlock" },
        { "ThoughtsOpener", "\n", "InlineToolCall", "\nAfter" },
        {
            StyleBox[ "Bold", FontWeight -> Bold ],
            " text\n",
            "InlineToolCall",
            "\n",
            StyleBox[ "Italic", FontSlant -> Italic ],
            " after"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Neighbors@@Tests/FormattingToolCalls.wlt:523,1-553,2"
]

(* The same while streaming, and with horizontal rules: *)
VerificationTest[
    {
        tcStyles[ "## Heading\n" <> tcWebFetcher[ "tc0039" ] <> "\n- item", "Streaming" ],
        tcStyles[ "```wl\n1+1\n```\n" <> tcWebFetcher[ "tc0040" ] <> "\n```wl\n2+2\n```", "Streaming" ],
        tcStyles[ "Text\n\n---\n" <> tcWebFetcher[ "tc0041" ] <> "\n---\nText" ]
    },
    {
        { "InlineSection", "\n", "InlineToolCall", "\n", "InlineItem" },
        { "ChatCodeBlock", "\n", "InlineToolCall", "\n", "ChatCodeBlock" },
        { "Text\n", "MarkdownDelimiter", "\n", "InlineToolCall", "\n", "MarkdownDelimiter", "\nText" }
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Neighbors-Streaming-And-Delimiters@@Tests/FormattingToolCalls.wlt:556,1-569,2"
]

(* Tool calls and "/retry" inside think tags are not formatted; they stay as text in the thoughts: *)
VerificationTest[
    Replace[
        FormatMarkdown[ "<think>" <> tcWebFetcher[ "tc0034" ] <> "\nBad.\n/retry</think>After" ],
        Cell[ BoxData @ TemplateBox[ { text_, ___ }, name_String ], ___ ] :> { name, NormalizeTextData @ text },
        { 1 }
    ],
    { { "ThoughtsOpener", TextData @ { tcWebFetcher[ "tc0034" ] <> "\nBad.\n/retry" } }, "\nAfter" },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Inside-Thinking-Not-Formatted@@Tests/FormattingToolCalls.wlt:572,1-581,2"
]

(* Escaped markdown characters elsewhere in the response take a different formatting path, which gives the same
   result around tool calls: *)
VerificationTest[
    {
        tcStyles[ "Intro\n\n" <> tcWebFetcher[ "tc0035" ] <> "\n\nCost \\$5." ],
        tcStyles[ "Intro\n\n" <> tcWebFetcher[ "tc0036" ] <> "\n\nCost \\$5.", "Streaming" ],
        tcTags[ "Cost \\$5.\n\nTOOLCALL: web_fetcher\n{\"url\":\"y\"}\nENDARGUMENTS\nENDTOOLCALL\n", "Streaming" ]
    },
    {
        { "Intro\n", "InlineToolCall", "\nCost $5." },
        { "Intro\n", "InlineToolCall", "\nCost $5." },
        KeySort @ <|
            "Name"        -> "web_fetcher",
            "DisplayName" -> "Web Fetcher",
            "ToolCall"    -> "TOOLCALL: web_fetcher\n{\"url\":\"y\"}\nENDARGUMENTS\nENDTOOLCALL",
            "Parameters"  -> ""
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Escaped-Text-Equivalent@@Tests/FormattingToolCalls.wlt:585,1-603,2"
]

(* Non-ASCII text in and around tool calls is kept as is, in the display and in serialization: *)
VerificationTest[
    With[
        {
            md = StringJoin[
                "R\[EAcute]sum\[EAcute] \[Sum] \:65e5\:672c\:8a9e\n\n",
                "TOOLCALL: web_fetcher\n{\"url\":\"https://\:4f8b\:3048.jp/caf\[EAcute]\"}\nENDARGUMENTS\nENDTOOLCALL\n",
                "RESULT\n\[CapitalOmega] ok \[Checkmark]\nENDRESULT(tc0037)\n\nDone \[Checkmark]"
            ]
        },
        {
            tcStyles @ md,
            tcTags[ md ][ "ToolCall" ],
            tcInterpretedView[ First @ tcCells @ md ][ "Output" ],
            tcRoundTrip @ md
        }
    ],
    {
        { "R\[EAcute]sum\[EAcute] \[Sum] \:65e5\:672c\:8a9e\n", "InlineToolCall", "\nDone \[Checkmark]" },
        "TOOLCALL: web_fetcher\n{\"url\":\"https://\:4f8b\:3048.jp/caf\[EAcute]\"}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\n\[CapitalOmega] ok \[Checkmark]\nENDRESULT(tc0037)",
        Cell[ TextData @ { "\[CapitalOmega] ok \[Checkmark]" }, "Text", Background -> None ],
        StringJoin[
            "R\[EAcute]sum\[EAcute] \[Sum] \:65e5\:672c\:8a9e\n",
            "TOOLCALL: web_fetcher\n{\"url\":\"https://\:4f8b\:3048.jp/caf\[EAcute]\"}\nENDARGUMENTS\nENDTOOLCALL\n",
            "RESULT\n\[CapitalOmega] ok \[Checkmark]\nENDRESULT(tc0037)\nDone \[Checkmark]"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Unicode@@Tests/FormattingToolCalls.wlt:606,1-634,2"
]

(* The LLM may write "\r\n" line breaks, while Chatbook appends the tool result with "\n". The tool call is still
   recognized, and its result is parsed (so it's labeled "Used"). The stored tool call text has "\n" line breaks: *)
VerificationTest[
    With[
        {
            tool = StringJoin[
                "TOOLCALL: web_fetcher\r\n{\"url\":\"https://example.com\"}\r\n",
                "ENDARGUMENTS\nENDTOOLCALL\nRESULT\nok\nENDRESULT(tc0038)"
            ]
        },
        {
            Count[ FormatMarkdown[ "A\r\n\r\n" <> tool <> "\n\nB" ], Cell[ _, "InlineToolCall", ___ ] ],
            tcLabel @ First @ tcCells[ "A\r\n\r\n" <> tool <> "\n\nB" ],
            tcTags[ "A\r\n\r\n" <> tool <> "\n\nB" ][ "ToolCall" ] === StringReplace[ tool, "\r\n" -> "\n" ]
        }
    ],
    {
        1,
        <|
            "State"    -> False,
            "Label"    -> "FormattingToolUsed",
            "Name"     -> "Web Fetcher",
            "Icon"     -> "ToolIconCallWebFetcher",
            "Progress" -> False
        |>,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Mixed-Line-Endings@@Tests/FormattingToolCalls.wlt:638,1-665,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Simple Tool Calls*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Recognition*)

(* A line with only "/command" starts a simple tool call, which is recognized when it has an ENDRESULT, even without
   a registered tool. Without the "Simple" tool method and tool evaluation results, it can't be parsed, so it shows
   the "Using tool..." label in finished output too: *)
VerificationTest[
    With[ { tool = "/wl\n1+1\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(tc0101)" },
        {
            tcStyles[ "Text\n" <> tool <> "\nAfter" ],
            tcTags[ "Text\n" <> tool <> "\nAfter" ],
            tcLabel[ First @ tcCells[ "Text\n" <> tool <> "\nAfter" ] ][ "State" ],
            tcRoundTrip[ "Text\n" <> tool <> "\nAfter" ]
        }
    ],
    {
        { "Text\n", "InlineToolCall", "\nAfter" },
        <| "ToolCall" -> "/wl\n1+1\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(tc0101)" |>,
        "Loading",
        "Text\n/wl\n1+1\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(tc0101)\nAfter"
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-EndResult@@Tests/FormattingToolCalls.wlt:678,1-695,2"
]

(* Without an ENDRESULT, the command must be the short name of a tool in $ChatHandlerData[ "ToolShortNames" ]. The
   tool call then extends to the end of the response (text after it is a quirk and not tested here). Other test files
   can leave $ChatHandlerData set globally, so the unregistered case sets it explicitly: *)
VerificationTest[
    {
        Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> }, tcStyles[ "Text\n/wl\n1+1\n/exec" ] ],
        Block[ { Wolfram`Chatbook`$ChatHandlerData = <| "ToolShortNames" -> <| "wl" -> tcWLTool |> |> },
            {
                tcStyles[ "Text\n/wl\n1+1\n/exec" ],
                tcTags[ "Text\n/wl\n1+1\n/exec" ],
                tcStyles[ "Text\n/wl\n1+113", "Streaming" ],
                tcLabel[ First @ tcCells[ "Text\n/wl\n1+114", "Streaming" ] ][ "State" ],
                (* Other commands are still text: *)
                tcStyles[ "Text\n/wa\nfoo\n/exec\nAfter" ]
            }
        ]
    },
    {
        { "Text\n/wl\n1+1\n/exec" },
        {
            { "Text\n", "InlineToolCall" },
            <| "ToolCall" -> "/wl\n1+1\n/exec" |>,
            { "Text\n", "InlineToolCall" },
            "Loading",
            { "Text\n/wa\nfoo\n/exec\nAfter" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Registered-Command@@Tests/FormattingToolCalls.wlt:700,1-726,2"
]

(* Lines that start with "/" but are not commands (or are unregistered commands without an ENDRESULT) stay as text:
   paths, commands followed by more text on the same line, a lone "/", and commands longer than 80 characters: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = <| "ToolShortNames" -> <| "wl" -> tcWLTool |> |> },
        {
            tcStyles[ "Use the path\n/usr/bin/env\nto run it." ],
            tcStyles[ "/imagine a cat\nmore" ],
            tcStyles[ "/wl is the command\nmore" ],
            tcStyles[ "/\nfoo\nENDRESULT(tc0102)" ],
            tcStyles[ "/" <> StringRepeat[ "a", 81 ] <> "\nfoo\nRESULT\nx\nENDRESULT(tc0103)" ],
            tcStyles[ "/" <> StringRepeat[ "a", 80 ] <> "\nfoo\nRESULT\nx\nENDRESULT(tc0104)" ]
        }
    ],
    {
        { "Use the path\n/usr/bin/env\nto run it." },
        { "/imagine a cat\nmore" },
        { "/wl is the command\nmore" },
        { "/\nfoo\nENDRESULT(tc0102)" },
        { "/" <> StringRepeat[ "a", 81 ] <> "\nfoo\nRESULT\nx\nENDRESULT(tc0103)" },
        { "InlineToolCall" }
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Slash-Lines-Not-ToolCalls@@Tests/FormattingToolCalls.wlt:730,1-751,2"
]

(* Whitespace before the command and spaces after it are allowed. The stored tool call text is trimmed: *)
VerificationTest[
    {
        tcStyles[ "Text\n   /wl\n1+1\n/exec\nRESULT\nx\nENDRESULT(tc0105)\nAfter" ],
        tcTags[ "Text\n   /wl\n1+1\n/exec\nRESULT\nx\nENDRESULT(tc0106)\nAfter" ],
        tcTags[ "Text\n/wl   \n1+1\n/exec\nRESULT\nx\nENDRESULT(tc0107)\nAfter" ]
    },
    {
        { "Text\n", "InlineToolCall", "\nAfter" },
        <| "ToolCall" -> "/wl\n1+1\n/exec\nRESULT\nx\nENDRESULT(tc0106)" |>,
        <| "ToolCall" -> "/wl   \n1+1\n/exec\nRESULT\nx\nENDRESULT(tc0107)" |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Whitespace@@Tests/FormattingToolCalls.wlt:754,1-767,2"
]

(* A code block that starts with an unregistered command (and has no ENDRESULT) is an ordinary code block: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> }, tcStyles[ "Code:\n```\n/wl\n1+1\n```\nAfter" ] ],
    { "Code:\n", "ChatCodeBlock", "\nAfter" },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Code-Block-Not-ToolCall@@Tests/FormattingToolCalls.wlt:770,1-775,2"
]

(* An opening code fence directly before a simple tool call is dropped, as for TOOLCALL: *)
VerificationTest[
    {
        tcStyles[ "Text\n```\n/wl\n1+1\n/exec\nRESULT\nx\nENDRESULT(tc0108)" ],
        tcTags[ "Text\n```wl\n/wl\n1+1\n/exec\nRESULT\nx\nENDRESULT(tc0109)" ]
    },
    {
        { "Text\n", "InlineToolCall" },
        <| "ToolCall" -> "/wl\n1+1\n/exec\nRESULT\nx\nENDRESULT(tc0109)" |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Fence-Prefix-Removed@@Tests/FormattingToolCalls.wlt:778,1-789,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Simple Tool Method*)

(* With the "Simple" tool method, simple tool calls are parsed with the registered tool: the label shows its display
   name and icon, and the parameters are parsed from the lines between the command and "/exec" (the code keeps its
   trailing line break). Without a result it's labeled "Using": *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = $tcSimpleMethod },
        tcWithClickToCopy @ With[ { md = "Text\n/wl\n1+1\n/exec" },
            { tcStyles @ md, tcLabel @ First @ tcCells @ md, tcTags @ md }
        ]
    ],
    {
        { "Text\n", "InlineToolCall" },
        <|
            "State"    -> False,
            "Label"    -> "FormattingToolUsing",
            "Name"     -> "Wolfram Language Evaluator",
            "Icon"     -> "ToolIconCallWolframLanguageEvaluator",
            "Progress" -> True
        |>,
        KeySort @ <|
            "Name"        -> "WolframLanguageEvaluator",
            "DisplayName" -> "Wolfram Language Evaluator",
            "ToolCall"    -> "/wl\n1+1\n/exec",
            "Parameters"  -> <| "code" -> "1+1\n" |>
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Method-Unterminated@@Tests/FormattingToolCalls.wlt:798,1-822,2"
]

(* With a result, it's labeled "Used". The parameters are shown in a grid with the default formatter (ClickToCopy),
   and the result is formatted as markdown: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = $tcSimpleMethod },
        tcWithClickToCopy @ With[ { md = "Text\n/wl\n1+1\n/exec\nRESULT\nOut[1]= **2**\nENDRESULT(tc0110)\nAfter" },
            {
                tcStyles @ md,
                tcLabel[ First @ tcCells @ md ][[ { "State", "Label", "Progress" } ]],
                tcTags[ md ][ "ToolCall" ],
                tcInterpretedView @ First @ tcCells @ md
            }
        ]
    ],
    {
        { "Text\n", "InlineToolCall", "\nAfter" },
        <| "State" -> False, "Label" -> "FormattingToolUsed", "Progress" -> False |>,
        "/wl\n1+1\n/exec\nRESULT\nOut[1]= **2**\nENDRESULT(tc0110)",
        <|
            "Input"  -> { { "\"code\"", StyleBox[ "\"1+1\\n\"", "TCClickToCopy", ___ ] } },
            "Output" -> Cell[ TextData @ { "Out[1]= ", StyleBox[ "2", FontWeight -> Bold ] }, "Text", Background -> None ]
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Method-Result@@Tests/FormattingToolCalls.wlt:826,1-848,2"
]

(* While streaming, parsed simple tool calls are static placeholders: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = $tcSimpleMethod },
        {
            tcLabel @ First @ tcCells[ "Text\n/wl\n1+115\n/exec\nRESULT\nOut[1]= 116\n", "Streaming" ],
            tcTags[ "Text\n/wl \n", "Streaming" ]
        }
    ],
    {
        <|
            "State"    -> "Static",
            "Label"    -> "FormattingToolUsing",
            "Name"     -> "Wolfram Language Evaluator",
            "Icon"     -> "ToolIconCallWolframLanguageEvaluator",
            "Progress" -> True
        |>,
        KeySort @ <|
            "Name"        -> "WolframLanguageEvaluator",
            "DisplayName" -> "Wolfram Language Evaluator",
            "ToolCall"    -> "/wl",
            "Parameters"  -> <| "code" -> "" |>
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Method-Streaming@@Tests/FormattingToolCalls.wlt:851,1-875,2"
]

(* Tools with several parameters take them one per line, or by name: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = $tcSimpleMethod },
        tcWithClickToCopy @ {
            tcTags[ "/wa\npopulation of France\n/exec" ][[ { "Name", "DisplayName", "Parameters" } ]],
            tcTags[ "/wa\nquery: population of France\n/exec" ][ "Parameters" ]
        }
    ],
    {
        <|
            "Name"        -> "WolframAlpha",
            "DisplayName" -> "Wolfram|Alpha",
            "Parameters"  -> <| "query" -> "population of France", "steps" -> "" |>
        |>,
        <| "query" -> "population of France", "steps" -> "" |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Method-Parameters@@Tests/FormattingToolCalls.wlt:878,1-895,2"
]

(* An ENDRESULT makes any command a tool call, but with the "Simple" tool method a command without a registered tool
   is a failed tool call. It's shown as a framed Failure in a "FailedToolCall" cell that stores the tool call text: *)
VerificationTest[
    {
        Block[ { Wolfram`Chatbook`$ChatHandlerData = $tcSimpleMethod },
            NormalizeTextData @ FormatMarkdown[ "Text\n/zz\nfoo\n/exec\nRESULT\nx\nENDRESULT(tc0111)\nAfter" ]
        ],
        (* The same happens when there are no registered tools: *)
        Block[ { Wolfram`Chatbook`$ChatHandlerData = <| "ChatNotebookSettings" -> <| "ToolMethod" -> "Simple" |> |> },
            tcCells[ "/wl\n1\n/exec\nRESULT\n1\nENDRESULT(tc0112)" ]
        ]
    },
    {
        {
            "Text\n",
            Cell[
                BoxData @ FrameBox[
                    InterpretationBox[
                        _,
                        Failure[ "InvalidToolCall", KeyValuePattern[ "MessageParameters" -> { "zz" } ] ],
                        ___
                    ],
                    OrderlessPatternSequence[ BaseStyle -> "Output", FrameMargins -> 10, ImageMargins -> { { 0, 0 }, { 10, 10 } }, ___ ]
                ],
                "FailedToolCall",
                OrderlessPatternSequence[ Background -> None, TaggingRules -> <| "ToolCall" -> "/zz\nfoo\n/exec\nRESULT\nx\nENDRESULT(tc0111)" |> ]
            ],
            "\nAfter"
        },
        {
            Cell[
                BoxData @ FrameBox[ InterpretationBox[ _, Failure[ "InvalidToolCall", _ ], ___ ], ___ ],
                "FailedToolCall",
                OrderlessPatternSequence[ Background -> None, TaggingRules -> <| "ToolCall" -> "/wl\n1\n/exec\nRESULT\n1\nENDRESULT(tc0112)" |> ]
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Simple-Method-Failed@@Tests/FormattingToolCalls.wlt:899,1-936,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Evaluation Results*)

(* When the ID of a tool call is in the tool evaluation results of the session, the tool call is described by the
   tool response: the tool's canonical name and display name, its formatting function, the interpreted parameters, and
   whether to show the opener initially open. Icons and the result are not stored in the tagging rules: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$toolEvaluationResults = <| "tc0201" -> tcEchoResponse |> },
        With[ { md = "Text\n\nTOOLCALL: echo_tool\n{\"x\":\"hi **there**\"}\nRESULT\nhi **there**\nENDRESULT(tc0201)\n\nAfter" },
            tcWithClickToCopy @ { tcStyles @ md, tcTags @ md, tcLabel @ First @ tcCells @ md }
        ]
    ],
    {
        { "Text\n", "InlineToolCall", "\nAfter" },
        KeySort @ <|
            "ID"                 -> "tc0201",
            "Name"               -> "EchoTool",
            "DisplayName"        -> "Echo Tool",
            "FormattingFunction" -> Inherited,
            "ToolCall"           -> "TOOLCALL: echo_tool\n{\"x\":\"hi **there**\"}\nRESULT\nhi **there**\nENDRESULT(tc0201)",
            "Parameters"         -> <| "x" -> "hi **there**" |>,
            "Open"               -> False
        |>,
        <|
            "State"    -> False,
            "Label"    -> "FormattingToolUsed",
            "Name"     -> "Echo Tool",
            "Icon"     -> "ToolIconCallGenericTool",
            "Progress" -> False
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Evaluation-Results-TaggingRules@@Tests/FormattingToolCalls.wlt:945,1-972,2"
]

(* The interpreted parameters are shown in a grid, and the tool's output as formatted markdown: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$toolEvaluationResults = <| "tc0202" -> tcEchoResponse |> },
        tcWithClickToCopy @ tcInterpretedView @ First @ tcCells[
            "TOOLCALL: echo_tool\n{\"x\":\"hi **there**\"}\nRESULT\nhi **there**\nENDRESULT(tc0202)"
        ]
    ],
    <|
        "Input"  -> { { "\"x\"", StyleBox[ "\"hi **there**\"", "TCClickToCopy", ___ ] } },
        "Output" -> Cell[ TextData @ { "hi ", StyleBox[ "there", FontWeight -> Bold ] }, "Text", Background -> None ]
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Evaluation-Results-Interpreted-View@@Tests/FormattingToolCalls.wlt:975,1-987,2"
]

(* A built-in tool's formatting function is used for the interpreted view: the Wolfram Language evaluator shows its
   code as a code block. Cells with the "Input" style in the formatted output are changed to "Output": *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$toolEvaluationResults = <| "tc0203" -> tcWLResponse |> },
        With[ { md = "TOOLCALL: wolfram_language_evaluator\n{\"code\":\"1+1\"}\nRESULT\nOut[1]= 2\nENDRESULT(tc0203)" },
            {
                tcTags[ md ][[ { "Name", "DisplayName", "FormattingFunction", "Parameters" } ]],
                tcInterpretedView @ First @ tcCells @ md
            }
        ]
    ],
    {
        <|
            "Name"               -> "WolframLanguageEvaluator",
            "DisplayName"        -> "Wolfram Language Evaluator",
            "FormattingFunction" -> Wolfram`Chatbook`Common`sandboxFormatter,
            "Parameters"         -> <| "code" -> "1+1" |>
        |>,
        <|
            "Input" -> {
                {
                    "\"code\"",
                    Cell[
                        BoxData @ TemplateBox[ { Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "ChatCode", "Input", ___ ], "Wolfram" }, "ChatCodeBlockTemplate" ],
                        "ChatCodeBlock"
                    ]
                }
            },
            "Output" -> Cell[ BoxData[ "\"Out[1]= 2\"" ], "Output" ]
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Evaluation-Results-Builtin-Formatter@@Tests/FormattingToolCalls.wlt:991,1-1022,2"
]

(* Simple tool calls ("/wl" ... "/exec") are looked up by their ID the same way, with or without the "Simple" tool
   method: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$toolEvaluationResults = <|
                "tc0208" -> tcWLResponse,
                "tc0209" -> tcWLResponse,
                "tc0210" -> tcWLResponse
            |>
        },
        With[ { md = "Text\n/wl\n1+1\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(" <> # <> ")\nAfter" & },
            {
                tcStyles @ md[ "tc0208" ],
                tcTags @ md[ "tc0208" ],
                tcLabel @ First @ tcCells @ md[ "tc0208" ],
                Block[ { Wolfram`Chatbook`$ChatHandlerData = $tcSimpleMethod },
                    tcTags[ md[ "tc0209" ] ][[ { "ID", "Name", "Parameters" } ]]
                ],
                tcRoundTrip @ md[ "tc0210" ]
            }
        ]
    ],
    {
        { "Text\n", "InlineToolCall", "\nAfter" },
        KeySort @ <|
            "ID"                 -> "tc0208",
            "Name"               -> "WolframLanguageEvaluator",
            "DisplayName"        -> "Wolfram Language Evaluator",
            "FormattingFunction" -> Wolfram`Chatbook`Common`sandboxFormatter,
            "ToolCall"           -> "/wl\n1+1\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(tc0208)",
            "Parameters"         -> <| "code" -> "1+1" |>,
            "Open"               -> False
        |>,
        <|
            "State"    -> False,
            "Label"    -> "FormattingToolUsed",
            "Name"     -> "Wolfram Language Evaluator",
            "Icon"     -> "ToolIconCallWolframLanguageEvaluator",
            "Progress" -> False
        |>,
        <| "ID" -> "tc0209", "Name" -> "WolframLanguageEvaluator", "Parameters" -> <| "code" -> "1+1" |> |>,
        "Text\n/wl\n1+1\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(tc0210)\nAfter"
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Evaluation-Results-Simple-Syntax@@Tests/FormattingToolCalls.wlt:1026,1-1070,2"
]

(* While streaming, tool calls with evaluation results are static placeholders too: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$toolEvaluationResults = <| "tc0204" -> tcWLResponse |> },
        tcLabel @ First @ tcCells[
            "TOOLCALL: wolfram_language_evaluator\n{\"code\":\"1+1\"}\nRESULT\nOut[1]= 2\nENDRESULT(tc0204)",
            "Streaming"
        ]
    ],
    <|
        "State"    -> "Static",
        "Label"    -> "FormattingToolUsed",
        "Name"     -> "Wolfram Language Evaluator",
        "Icon"     -> "ToolIconCallWolframLanguageEvaluator",
        "Progress" -> False
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Evaluation-Results-Streaming@@Tests/FormattingToolCalls.wlt:1073,1-1089,2"
]

(* The "OpenToolCallBoxes" setting ($openToolCallBoxes) makes openers initially open, but only for tool calls with
   evaluation results: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$toolEvaluationResults = <| "tc0205" -> tcWLResponse |>,
            Wolfram`Chatbook`Common`$openToolCallBoxes = True
        },
        {
            With[ { md = "TOOLCALL: wolfram_language_evaluator\n{\"code\":\"1+1\"}\nRESULT\nOut[1]= 2\nENDRESULT(tc0205)" },
                { tcLabel[ First @ tcCells @ md ][ "State" ], tcTags[ md ][ "Open" ] }
            ],
            tcLabel[ First @ tcCells @ tcWebFetcher[ "tc0206" ] ][ "State" ]
        }
    ],
    { { True, True }, False },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Evaluation-Results-Open@@Tests/FormattingToolCalls.wlt:1093,1-1109,2"
]

(* A Failure in the evaluation results gives a failed tool call: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$toolEvaluationResults = <|
                "tc0207" -> Failure[ "Oops", <| "MessageTemplate" -> "Something went wrong" |> ]
            |>
        },
        tcCells[ "TOOLCALL: echo_tool\n{\"x\":\"1\"}\nRESULT\nfail\nENDRESULT(tc0207)" ]
    ],
    {
        Cell[
            BoxData @ FrameBox[ InterpretationBox[ _, Failure[ "Oops", _ ], ___ ], ___ ],
            "FailedToolCall",
            OrderlessPatternSequence[ Background -> None, TaggingRules -> <| "ToolCall" -> "TOOLCALL: echo_tool\n{\"x\":\"1\"}\nRESULT\nfail\nENDRESULT(tc0207)" |> ]
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Evaluation-Results-Failure@@Tests/FormattingToolCalls.wlt:1112,1-1130,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FormatToolCall*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Labels*)

(* FormatToolCall gives an opener expression for a parsed tool call. Without a "DisplayName", the "Name" is shown as
   capitalized words (underscores become spaces, and anything after whitespace or "{" is dropped): *)
VerificationTest[
    {
        Head @ FormatToolCall[ "x", <| "Name" -> "my_cool_tool", "Result" -> "done", "ToolCall" -> "x", "Parameters" -> "q" |> ],
        tcLabel @ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "my_cool_tool", "Result" -> "done", "ToolCall" -> "x", "Parameters" -> "q" |> ],
        tcLabel[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> " my_cool_tool {\"a\":1}", "Result" -> "done", "ToolCall" -> "x", "Parameters" -> "q" |> ] ][ "Name" ],
        tcLabel[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "my_cool_tool\nmore", "Result" -> "done", "ToolCall" -> "x", "Parameters" -> "q" |> ] ][ "Name" ],
        (* A "DisplayName" string is used as is: *)
        tcLabel[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "my_cool_tool", "DisplayName" -> "Shiny", "Result" -> "done", "ToolCall" -> "x", "Parameters" -> "q" |> ] ][ "Name" ],
        tcLabel[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "my_cool_tool", "DisplayName" -> Missing[ "NotFound" ], "Result" -> "done", "ToolCall" -> "x", "Parameters" -> "q" |> ] ][ "Name" ]
    },
    {
        DynamicModule,
        <|
            "State"    -> False,
            "Label"    -> "FormattingToolUsed",
            "Name"     -> "My Cool Tool",
            "Icon"     -> "ToolIconCallGenericTool",
            "Progress" -> False
        |>,
        "My Cool Tool",
        "My Cool Tool",
        "Shiny",
        "My Cool Tool"
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Name@@Tests/FormattingToolCalls.wlt:1142,1-1168,2"
]

(* An explicitly empty "Result" means the tool is still running: "Using" with a progress indicator. A missing
   "Result" is shown as "Used": *)
VerificationTest[
    {
        tcLabel[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t", "Result" -> "", "ToolCall" -> "x", "Parameters" -> "q" |> ] ][[ { "State", "Label", "Progress" } ]],
        tcLabel[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t", "Result" -> "" |>, <| "Status" -> "Streaming" |> ] ][[ { "State", "Label", "Progress" } ]],
        tcLabel[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t" |>, <| "Status" -> "Streaming" |> ] ][[ { "State", "Label", "Progress" } ]]
    },
    {
        <| "State" -> False, "Label" -> "FormattingToolUsing", "Progress" -> True |>,
        <| "State" -> "Static", "Label" -> "FormattingToolUsing", "Progress" -> True |>,
        <| "State" -> "Static", "Label" -> "FormattingToolUsed", "Progress" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Using@@Tests/FormattingToolCalls.wlt:1172,1-1185,2"
]

(* The "Status" determines whether it's an opener or a static placeholder. Without the third argument, it depends on
   whether the output is streaming ($dynamicText). A third argument without "Status" means "Finished": *)
VerificationTest[
    {
        Head @ FormatToolCall[ "x", <| "Name" -> "t", "Result" -> "r" |>, <| "Status" -> "Streaming" |> ],
        Head @ FormatToolCall[ "x", <| "Name" -> "t", "Result" -> "r", "ToolCall" -> "x", "Parameters" -> "q" |>, <| "Status" -> "Finished" |> ],
        Block[ { Wolfram`Chatbook`Common`$dynamicText = True }, Head @ FormatToolCall[ "x", <| "Name" -> "t", "Result" -> "r" |> ] ],
        Block[ { Wolfram`Chatbook`Common`$dynamicText = False }, Head @ FormatToolCall[ "x", <| "Name" -> "t", "Result" -> "r", "ToolCall" -> "x", "Parameters" -> "q" |> ] ],
        Block[ { Wolfram`Chatbook`Common`$dynamicText = True }, Head @ FormatToolCall[ "x", <| "Name" -> "t", "Result" -> "r", "ToolCall" -> "x", "Parameters" -> "q" |>, <| |> ] ]
    },
    { Deploy, DynamicModule, Deploy, DynamicModule, DynamicModule },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Status@@Tests/FormattingToolCalls.wlt:1189,1-1200,2"
]

(* Without a name, the label is the "Using tool..." string resource: *)
VerificationTest[
    {
        FormatToolCall[ "x", <| |> ],
        FormatToolCall[ "x", <| "ToolCall" -> "x" |>, <| "Status" -> "Streaming" |> ]
    },
    {
        Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingToolUsingLoading" ],
        Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingToolUsingLoading" ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Loading@@Tests/FormattingToolCalls.wlt:1203,1-1214,2"
]

(* "Open" -> True gives an opener that is initially open: *)
VerificationTest[
    tcLabel[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t", "Result" -> "r", "ToolCall" -> "x", "Parameters" -> "q", "Open" -> True |> ] ][ "State" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Open@@Tests/FormattingToolCalls.wlt:1217,1-1222,2"
]

(* A Failure is shown framed, in both states: *)
VerificationTest[
    {
        FormatToolCall[ "x", Failure[ "Oops", <| "MessageTemplate" -> "Bad" |> ] ],
        FormatToolCall[ "x", Failure[ "Oops", <| "MessageTemplate" -> "Bad" |> ], <| "Status" -> "Streaming" |> ]
    },
    {
        Framed[
            Failure[ "Oops", <| "MessageTemplate" -> "Bad" |> ],
            OrderlessPatternSequence[ BaseStyle -> "Output", FrameMargins -> 10, ImageMargins -> { { 0, 0 }, { 10, 10 } }, ___ ]
        ],
        Framed[ Failure[ "Oops", <| "MessageTemplate" -> "Bad" |> ], ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Failure@@Tests/FormattingToolCalls.wlt:1225,1-1239,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Views*)

(* The "Raw" tab shows the "ToolCall" text, the "Interpreted" tab the parameters and result: *)
VerificationTest[
    With[ { boxes = ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t", "ToolCall" -> "raw call text", "Parameters" -> "query string\nline 2", "Result" -> "res" |> ] },
        { tcTabs @ boxes, tcRawView @ boxes, tcInterpretedView @ boxes }
    ],
    {
        { { "\"Raw\"", "\"Interpreted\"" }, 2 },
        "raw call text",
        <|
            "Input"  -> Cell[ "query string\nline 2", "Program", OrderlessPatternSequence[ FontSize -> 0.75 * Inherited, Background -> None ] ],
            "Output" -> Cell[ TextData @ { "res" }, "Text", Background -> None ]
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Views@@Tests/FormattingToolCalls.wlt:1246,1-1260,2"
]

(* Parameters given as an association are shown as a grid of name/value rows: *)
VerificationTest[
    tcWithClickToCopy @ FirstCase[
        ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t", "ToolCall" -> "x", "Parameters" -> <| "a" -> "1", "b" -> "two" |>, "Result" -> "r" |> ],
        GridBox[ { { "\"a\"", _ }, ___ }, opts___ ] :> { opts },
        Missing[ "NoGrid" ],
        Infinity
    ],
    {
        OrderlessPatternSequence[
            GridBoxAlignment -> { "Columns" -> { { Left } } },
            GridBoxDividers  -> { "Columns" -> { { True } }, "Rows" -> { { True } } },
            BaseStyle        -> { "Text", LineBreakWithin -> Automatic },
            ___
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Parameter-Grid@@Tests/FormattingToolCalls.wlt:1263,1-1280,2"
]

(* The "FormattingFunction" formats parameter values (with "Parameters" and the parameter name) and the result (with
   "Result"). Inherited (or no "FormattingFunction") uses ClickToCopy for parameters and formats string results as
   markdown, Automatic uses ClickToCopy for both, None shows the values as they are, and any other function is used
   as is: *)
VerificationTest[
    tcWithClickToCopy @ Table[
        tcInterpretedView @ ToBoxes @ FormatToolCall[
            "x",
            Join[
                <| "Name" -> "t", "ToolCall" -> "x", "Parameters" -> <| "a" -> "1" |>, "Result" -> "res **bold**" |>,
                formatter
            ]
        ],
        { formatter, { <| |>, <| "FormattingFunction" -> Inherited |>, <| "FormattingFunction" -> Automatic |>, <| "FormattingFunction" -> None |>, <| "FormattingFunction" -> (Style[ { ## }, "Custom" ] &) |> } }
    ],
    {
        <|
            "Input"  -> { { "\"a\"", StyleBox[ "\"1\"", "TCClickToCopy", ___ ] } },
            "Output" -> Cell[ TextData @ { "res ", StyleBox[ "bold", FontWeight -> Bold ] }, "Text", Background -> None ]
        |>,
        <|
            "Input"  -> { { "\"a\"", StyleBox[ "\"1\"", "TCClickToCopy", ___ ] } },
            "Output" -> Cell[ TextData @ { "res ", StyleBox[ "bold", FontWeight -> Bold ] }, "Text", Background -> None ]
        |>,
        <|
            "Input"  -> { { "\"a\"", StyleBox[ "\"1\"", "TCClickToCopy", ___ ] } },
            "Output" -> StyleBox[ "\"res **bold**\"", "TCClickToCopy", ___ ]
        |>,
        <| "Input" -> { { "\"a\"", "\"1\"" } }, "Output" -> "\"res **bold**\"" |>,
        <|
            "Input"  -> { { "\"a\"", StyleBox[ RowBox @ { "{", RowBox @ { "\"1\"", ",", "\"Parameters\"", ",", "\"a\"" }, "}" }, "Custom", ___ ] } },
            "Output" -> StyleBox[ RowBox @ { "{", RowBox @ { "\"res **bold**\"", ",", "\"Result\"" }, "}" }, "Custom", ___ ]
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Formatting-Functions@@Tests/FormattingToolCalls.wlt:1286,1-1318,2"
]

(* The default formatter shows non-string results as they are, and uses the "Result" of an association result: *)
VerificationTest[
    tcWithClickToCopy @ {
        tcInterpretedView[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t", "ToolCall" -> "x", "Parameters" -> "q", "Result" -> 42 |> ] ][ "Output" ],
        tcInterpretedView[ ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t", "ToolCall" -> "x", "Parameters" -> "q", "Result" -> <| "Result" -> "*it*" |> |> ] ][ "Output" ]
    },
    {
        "42",
        Cell[ TextData @ { StyleBox[ "it", FontSlant -> Italic ] }, "Text", Background -> None ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Auto-Formatter-Results@@Tests/FormattingToolCalls.wlt:1321,1-1332,2"
]

(* Markdown results are fully formatted, including code blocks. Like for built-in formatters, "Input" cells are changed
   to "Output", which includes the code cells of these code blocks: *)
VerificationTest[
    tcInterpretedView[
        ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t", "ToolCall" -> "x", "Parameters" -> "q", "Result" -> "See:\n\n```wl\nRange[3]\n```" |> ]
    ][ "Output" ],
    Cell[
        TextData @ {
            "See:\n",
            Cell[
                BoxData @ TemplateBox[ { Cell[ BoxData[ _ ], "ChatCode", "Output", ___ ], "Wolfram" }, "ChatCodeBlockTemplate" ],
                "ChatCodeBlock"
            ]
        },
        "Text",
        Background -> None
    ],
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Code-Block-Result@@Tests/FormattingToolCalls.wlt:1336,1-1353,2"
]

(* Very large opener content (over 50,000 bytes) is compressed until the opener is viewed (it's decompressed by a
   Dynamic when it's displayed): *)
VerificationTest[
    With[ { boxes = ToBoxes @ FormatToolCall[ "x", <| "Name" -> "t", "ToolCall" -> "x", "Parameters" -> "q", "Result" -> Range[ 10000 ] |> ] },
        {
            tcLabel[ boxes ][[ { "State", "Label", "Name" } ]],
            FreeQ[ boxes, TabViewBox ],
            Head @ tcDiscardedContent @ boxes,
            MatchQ[ FirstCase[ boxes, _DynamicBox? (! FreeQ[ #, BaseDecode ] &), None, Infinity ], _DynamicBox ]
        }
    ],
    {
        <| "State" -> False, "Label" -> "FormattingToolUsed", "Name" -> "T" |>,
        True,
        TabView,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-FormatToolCall-Large-Content-Compressed@@Tests/FormattingToolCalls.wlt:1357,1-1374,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom FormatToolCall*)

(* A "FormatToolCall" processing function replaces the default formatting. Its result is converted to boxes, and the
   cell keeps the same style and tagging rules, so it serializes the same way: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatHandlerData = <|
                "ChatNotebookSettings" -> <| "ProcessingFunctions" -> <| "FormatToolCall" -> (Framed[ #2[ "Name" ] ] &) |> |>
            |>
        },
        {
            NormalizeTextData @ FormatMarkdown[ "Text\n\n" <> tcWebFetcher[ "tc0301" ] <> "\n\nAfter" ],
            tcRoundTrip[ "Text\n\n" <> tcWebFetcher[ "tc0302" ] <> "\n\nAfter" ]
        }
    ],
    {
        {
            "Text\n",
            Cell[
                BoxData @ FrameBox[ "\"web_fetcher\"", ___ ],
                "InlineToolCall",
                OrderlessPatternSequence[
                    Background   -> None,
                    TaggingRules -> tags_ /; KeySort @ tags === KeySort @ <|
                        "Name"        -> "web_fetcher",
                        "DisplayName" -> "Web Fetcher",
                        "ToolCall"    -> tcWebFetcher[ "tc0301" ],
                        "Parameters"  -> $tcWebFetcherQuery
                    |>
                ]
            ],
            "\nAfter"
        },
        "Text\n" <> tcWebFetcher[ "tc0302" ] <> "\nAfter"
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Custom-Formatter@@Tests/FormattingToolCalls.wlt:1382,1-1416,2"
]

(* The processing function gets the tool call text and the full parsed tool call, including the icons and result
   that are not stored in the tagging rules. A Failure is passed the same way, and gives a "FailedToolCall" cell: *)
VerificationTest[
    Module[ { args, failedArgs, cells },
        Block[
            {
                Wolfram`Chatbook`$ChatHandlerData = <|
                    "ChatNotebookSettings" -> <| "ProcessingFunctions" -> <| "FormatToolCall" -> ((args = { ## }; "X") &) |> |>
                |>
            },
            cells = tcCells @ tcWebFetcher[ "tc0303" ]
        ];
        Block[
            {
                Wolfram`Chatbook`$ChatHandlerData = <|
                    "ChatNotebookSettings" -> <|
                        "ProcessingFunctions" -> <| "FormatToolCall" -> ((failedArgs = { ## }; "F") &) |>,
                        "ToolMethod"          -> "Simple"
                    |>
                |>
            },
            AppendTo[ cells, First @ tcCells[ "/zz\nfoo\n/exec\nRESULT\nx\nENDRESULT(tc0304)" ] ]
        ];
        { cells, args, failedArgs }
    ],
    {
        {
            Cell[ BoxData[ "\"X\"" ], "InlineToolCall", OrderlessPatternSequence[ Background -> None, TaggingRules -> _Association ] ],
            Cell[
                BoxData[ "\"F\"" ],
                "FailedToolCall",
                OrderlessPatternSequence[ Background -> None, TaggingRules -> <| "ToolCall" -> "/zz\nfoo\n/exec\nRESULT\nx\nENDRESULT(tc0304)" |> ]
            ]
        },
        {
            tcWebFetcher[ "tc0303" ],
            KeyValuePattern @ {
                "Name"        -> "web_fetcher",
                "DisplayName" -> "Web Fetcher",
                "Icon"        -> _,
                "CallIcon"    -> _Function,
                "ToolCall"    -> tcWebFetcher[ "tc0303" ],
                "Parameters"  -> $tcWebFetcherQuery,
                "Result"      -> "ok"
            }
        },
        { "/zz\nfoo\n/exec\nRESULT\nx\nENDRESULT(tc0304)", Failure[ "InvalidToolCall", _ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Custom-Formatter-Arguments@@Tests/FormattingToolCalls.wlt:1420,1-1468,2"
]

(* A "FormatToolCall" processing function of None uses the default formatting: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatHandlerData = <|
                "ChatNotebookSettings" -> <| "ProcessingFunctions" -> <| "FormatToolCall" -> None |> |>
            |>
        },
        tcLabel[ First @ tcCells @ tcWebFetcher[ "tc0305" ] ][[ { "State", "Label", "Name" } ]]
    ],
    <| "State" -> False, "Label" -> "FormattingToolUsed", "Name" -> "Web Fetcher" |>,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Custom-Formatter-None@@Tests/FormattingToolCalls.wlt:1471,1-1483,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Discarded Tool Calls*)

(* "/retry" discards the previous tool call and the text after it. In finished output, the discarded material is a
   closed gray opener labeled with the "FormattingDiscardedMaterial" string resource, followed by a line break: *)
VerificationTest[
    With[ { items = FormatMarkdown[ tcWebFetcher[ "tc0401" ] <> "\nBad.\n/retry\n" <> tcWebFetcher[ "tc0402" ] <> "\nDone." ] },
        {
            Replace[ NormalizeTextData @ items, Cell[ _, style_String, ___ ] :> style, { 1 } ],
            FirstCase[ items, Cell[ _, "DiscardedMaterial", opts___ ] :> { opts }, Missing[ ], Infinity ],
            tcOpenerState @ FirstCase[ items, Cell[ BoxData[ b_ ], "DiscardedMaterial", ___ ] :> b, Missing[ ], Infinity ],
            Union @ Cases[ items[[ 1 ]], FEPrivate`FrontEndResource[ "ChatbookStrings", s_String ] :> s, Infinity ],
            Union @ Cases[ items[[ 1 ]], FrontEnd`FileName[ { "Chatbook" }, file_String ] :> file, Infinity ],
            tcTags[ tcWebFetcher[ "tc0401" ] <> "\nBad.\n/retry\n" <> tcWebFetcher[ "tc0402" ] <> "\nDone." ][ "ToolCall" ]
        }
    ],
    {
        { "DiscardedMaterial", "\n", "InlineToolCall", "\nDone." },
        { Background -> None },
        False,
        { "FormattingDiscardedMaterial" },
        { "VerticalDividerDiscardedDefault.9.png", "VerticalDividerDiscardedHover.9.png", "VerticalDividerDiscardedPressed.9.png" },
        tcWebFetcher[ "tc0402" ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Finished@@Tests/FormattingToolCalls.wlt:1491,1-1512,2"
]

(* The discarded tool call and its text are formatted as usual (including markdown) and shown faded, one row per
   tool call. Line breaks within the discarded text are kept: *)
VerificationTest[
    {
        tcDiscardedContent @ FormatMarkdown[ tcWebFetcher[ "tc0403" ] <> "\nBad *one*.\n\nStill bad.\n/retry\nOK" ],
        tcDiscardedContent @ FormatMarkdown[ tcWebFetcher[ "tc0404" ] <> "\n/retry\nOK" ]
    },
    {
        Column[
            {
                RawBoxes @ Cell[
                    TextData @ {
                        Cell[ BoxData[ _DynamicModuleBox ], "InlineToolCall", ___, TaggingRules -> KeyValuePattern[ "ToolCall" -> tcWebFetcher[ "tc0403" ] ], ___ ],
                        "\nBad ",
                        StyleBox[ "one", FontSlant -> Italic ],
                        ".\n\nStill bad."
                    },
                    "Text",
                    OrderlessPatternSequence[ Background -> None, FontOpacity -> 0.5 ]
                ]
            },
            Spacings -> 0.5
        ],
        Column[ { RawBoxes @ Cell[ TextData @ { Cell[ _, "InlineToolCall", ___ ] }, "Text", OrderlessPatternSequence[ Background -> None, FontOpacity -> 0.5 ] ] }, Spacings -> 0.5 ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Discarded-Content@@Tests/FormattingToolCalls.wlt:1516,1-1541,2"
]

(* While streaming, the discarded material is a static placeholder without content: *)
VerificationTest[
    With[ { items = FormatMarkdown[ tcWebFetcher[ "tc0405" ] <> "\nBad.\n/retry\n" <> tcWebFetcher[ "tc0406" ] <> "\nDone.", "Streaming" ] },
        {
            Replace[ NormalizeTextData @ items, Cell[ _, style_String, ___ ] :> style, { 1 } ],
            tcOpenerState @ FirstCase[ items, Cell[ BoxData[ b_ ], "DiscardedMaterial", ___ ] :> b, Missing[ ], Infinity ],
            Union @ Cases[ items[[ 1 ]], FEPrivate`FrontEndResource[ "ChatbookStrings", s_String ] :> s, Infinity ],
            tcDiscardedContent @ items
        }
    ],
    {
        { "DiscardedMaterial", "\n", "InlineToolCall", "\nDone." },
        "Static",
        { "FormattingDiscardedMaterial" },
        Missing[ "NoContent" ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Streaming@@Tests/FormattingToolCalls.wlt:1544,1-1561,2"
]

(* Text before the discarded tool call is kept; everything from the tool call to "/retry" is discarded, including
   several paragraphs: *)
VerificationTest[
    tcStyles[ "Intro\n" <> tcWebFetcher[ "tc0407" ] <> "\nText A\n\nText B\n/retry\nFinal" ],
    { "Intro\n", "DiscardedMaterial", "\nFinal" },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Text-Before-Kept@@Tests/FormattingToolCalls.wlt:1565,1-1570,2"
]

(* Each "/retry" discards the tool call before it. Consecutive discarded tool calls are grouped into one opener, with
   one row per tool call, and while streaming into one placeholder: *)
VerificationTest[
    With[
        {
            md = StringJoin[
                tcWebFetcher[ #1 ], "\nBad one.\n/retry\n",
                tcWebFetcher[ #2 ], "\nBad two.\n/retry\n",
                tcWebFetcher[ #3 ], "\nDone."
            ] &
        },
        {
            tcStyles @ md[ "tc0425", "tc0426", "tc0427" ],
            tcStyles[ md[ "tc0428", "tc0429", "tc0430" ], "Streaming" ],
            Replace[
                tcDiscardedContent @ FormatMarkdown @ md[ "tc0431", "tc0432", "tc0433" ],
                Cell[ _, "InlineToolCall", ___, TaggingRules -> KeyValuePattern[ "ToolCall" -> s_ ], ___ ] :> s,
                Infinity
            ]
        }
    ],
    {
        { "DiscardedMaterial", "\n", "InlineToolCall", "\nDone." },
        { "DiscardedMaterial", "\n", "InlineToolCall", "\nDone." },
        Column[
            {
                RawBoxes @ Cell[ TextData @ { tcWebFetcher[ "tc0431" ], "\nBad one." }, "Text", ___ ],
                RawBoxes @ Cell[ TextData @ { tcWebFetcher[ "tc0432" ], "\nBad two." }, "Text", ___ ]
            },
            Spacings -> 0.5
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Grouped@@Tests/FormattingToolCalls.wlt:1574,1-1606,2"
]

(* Failed tool calls can be discarded too, and get their own row: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = $tcSimpleMethod },
        tcWithClickToCopy @ With[
            {
                md = StringJoin[
                    "/zz\nfoo\n/exec\nRESULT\nx\nENDRESULT(tc0434)\nBad.\n/retry\n",
                    "/wl\n1+1\n/exec\nRESULT\nerror\nENDRESULT(tc0435)\nWorse.\n/retry\nOK"
                ]
            },
            { tcStyles @ md, tcDiscardedContent @ FormatMarkdown @ md }
        ]
    ],
    {
        { "DiscardedMaterial", "\nOK" },
        Column[
            {
                RawBoxes @ Cell[
                    TextData @ {
                        Cell[
                            BoxData @ FrameBox[ InterpretationBox[ _, Failure[ "InvalidToolCall", _ ], ___ ], ___ ],
                            "FailedToolCall",
                            ___
                        ],
                        "\nBad."
                    },
                    "Text",
                    ___
                ],
                RawBoxes @ Cell[
                    TextData @ {
                        Cell[ _, "InlineToolCall", ___, TaggingRules -> KeyValuePattern[ "ToolCall" -> "/wl\n1+1\n/exec\nRESULT\nerror\nENDRESULT(tc0435)" ], ___ ],
                        "\nWorse."
                    },
                    "Text",
                    ___
                ]
            },
            Spacings -> 0.5
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Failed-ToolCall@@Tests/FormattingToolCalls.wlt:1609,1-1651,2"
]

(* "/retry" at the end of the response: *)
VerificationTest[
    {
        tcStyles[ tcWebFetcher[ "tc0408" ] <> "\nBad.\n/retry" ],
        tcStyles[ tcWebFetcher[ "tc0409" ] <> "\nBad.\n/retry", "Streaming" ],
        tcStyles[ tcWebFetcher[ "tc0410" ] <> "\nBad.\n   /retry  \n" ]
    },
    { { "DiscardedMaterial" }, { "DiscardedMaterial" }, { "DiscardedMaterial" } },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-At-End@@Tests/FormattingToolCalls.wlt:1654,1-1663,2"
]

(* "/retry" before any tool call is removed: *)
VerificationTest[
    tcStyles[ "/retry\n" <> tcWebFetcher[ "tc0411" ] <> "\nDone." ],
    { "InlineToolCall", "\nDone." },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Without-ToolCall@@Tests/FormattingToolCalls.wlt:1666,1-1671,2"
]

(* "/retry" must be followed by whitespace or the end of the response: *)
VerificationTest[
    tcStyles[ "Type /retrying to try again." ],
    { "Type /retrying to try again." },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Prefix-Not-Retry@@Tests/FormattingToolCalls.wlt:1674,1-1679,2"
]

(* A "/retry" line is never the command of a simple tool call, even when an ENDRESULT follows: *)
VerificationTest[
    tcStyles[ tcWebFetcher[ "tc0421" ] <> "\nBad\n/retry\nfoo\nENDRESULT(tc0422)" ],
    { "DiscardedMaterial", "\nfoo\nENDRESULT(tc0422)" },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Not-Simple-ToolCall@@Tests/FormattingToolCalls.wlt:1682,1-1687,2"
]

(* Simple tool calls can be discarded too: *)
VerificationTest[
    tcStyles[ "/wl\n1\n/exec\nRESULT\n1\nENDRESULT(tc0412)\nBad.\n/retry\n/wl\n2\n/exec\nRESULT\n2\nENDRESULT(tc0413)\nOK" ],
    { "DiscardedMaterial", "\n", "InlineToolCall", "\nOK" },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Simple-ToolCalls@@Tests/FormattingToolCalls.wlt:1690,1-1695,2"
]

(* Discarded material is not serialized (the line break after it is, so it leaves a blank line): *)
VerificationTest[
    tcRoundTrip[ "Intro\n" <> tcWebFetcher[ "tc0414" ] <> "\nBad.\n/retry\n" <> tcWebFetcher[ "tc0415" ] <> "\nDone." ],
    "Intro\n\n" <> tcWebFetcher[ "tc0415" ] <> "\nDone.",
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-RoundTrip@@Tests/FormattingToolCalls.wlt:1698,1-1703,2"
]

(* With escaped markdown characters, discarded text has its escapes removed, and the streaming display is the same: *)
VerificationTest[
    {
        tcStyles[ tcWebFetcher[ "tc0416" ] <> "\nBad \\$5.\n/retry\n" <> tcWebFetcher[ "tc0417" ] <> "\nOK \\$5", "Streaming" ],
        tcOpenerState @ FirstCase[
            FormatMarkdown[ tcWebFetcher[ "tc0418" ] <> "\nBad \\$5.\n/retry\n" <> tcWebFetcher[ "tc0419" ] <> "\nOK \\$5", "Streaming" ],
            Cell[ BoxData[ b_ ], "DiscardedMaterial", ___ ] :> b,
            Missing[ ],
            Infinity
        ],
        tcDiscardedContent @ FormatMarkdown[ tcWebFetcher[ "tc0420" ] <> "\nBad \\$5.\n/retry\nOK" ]
    },
    {
        { "DiscardedMaterial", "\n", "InlineToolCall", "\nOK $5" },
        "Static",
        Column[ { RawBoxes @ Cell[ TextData @ { Cell[ _, "InlineToolCall", ___ ], "\nBad $5." }, ___ ] }, ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-Retry-Escaped@@Tests/FormattingToolCalls.wlt:1706,1-1724,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*End Markers in Tool Output*)

(* Text in a tool's output that looks like the end marker must not end the tool call (GH#314). appendToolResult puts a
   backslash in the literal marker "ENDRESULT". The formatter's end marker is case-sensitive, so other text such as
   "sendResult" is left alone. *)
VerificationTest[
    tcAppendResult[ method_String, output_String ] := Module[ { container, start },
        start = If[ method === "Simple",
                    "/wl\n1+1",
                    "TOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS"
                ];
        container = <| "FullContent" -> start, "DynamicContent" -> start |>;
        Wolfram`Chatbook`SendChat`Private`appendToolResult[ container, <| "ToolMethod" -> method |>, output, "abc123xyz" ];
        container
    ];

    $tcMarkerOutputs = {
        "the marker ENDRESULT appears here",
        "before\nENDRESULT\nafter",
        "before\nENDRESULT(deadbeef)\nafter",
        "x = sendResult[ 1 ];",
        "before\nEndResult\nafter"
    };,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-EndMarker-Definitions-GH#314@@Tests/FormattingToolCalls.wlt:1733,1-1754,2"
]

(* The whole result stays in the tool call box: *)
VerificationTest[
    tcStyles[ tcAppendResult[ "Textual", # ][ "FullContent" ] <> "Done." ] & /@ $tcMarkerOutputs,
    ConstantArray[ { "InlineToolCall", "\nDone." }, Length @ $tcMarkerOutputs ],
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-EndMarker-Textual-GH#314@@Tests/FormattingToolCalls.wlt:1757,1-1762,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = $tcSimpleMethod },
        tcStyles[ tcAppendResult[ "Simple", # ][ "FullContent" ] <> "Done." ] & /@ $tcMarkerOutputs
    ],
    ConstantArray[ { "InlineToolCall", "\nDone." }, Length @ $tcMarkerOutputs ],
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-EndMarker-Simple-GH#314@@Tests/FormattingToolCalls.wlt:1764,1-1771,2"
]

(* The stored tool call text, and what parsePartialToolCallString shows for it when the tool result is no longer
   available (e.g. after restarting the kernel): *)
VerificationTest[
    With[
        {
            tool = tcTags[
                tcAppendResult[ "Textual", "before\nENDRESULT(deadbeef)\nsendResult[ 1 ]" ][ "FullContent" ] <> "Done."
            ][ "ToolCall" ]
        },
        { tool, Wolfram`Chatbook`Formatting`Private`parsePartialToolCallString[ tool ][ "Result" ] }
    ],
    {
        "TOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nbefore\nEND\\RESULT(deadbeef)\nsendResult[ 1 ]\nENDRESULT(abc123xyz)",
        "before\nEND\\RESULT(deadbeef)\nsendResult[ 1 ]"
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-EndMarker-ToolCallText-GH#314@@Tests/FormattingToolCalls.wlt:1775,1-1790,2"
]

(* The marker is case-sensitive, so words that contain it in another case don't end a tool call, including in the
   arguments: *)
VerificationTest[
    {
        tcStyles[ "TOOLCALL: wolfram_language_evaluator\n{\"code\":\"appendResult[ x ]\"}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nok\nENDRESULT(tc0701)\n\nDone." ],
        tcStyles[ "TOOLCALL: web_fetcher\n{\"url\":\"x\"}\nRESULT\nsee endresult here\nENDRESULT(tc0702)\n\nDone." ]
    },
    { { "InlineToolCall", "\nDone." }, { "InlineToolCall", "\nDone." } },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-EndMarker-Case-Sensitive-GH#314@@Tests/FormattingToolCalls.wlt:1794,1-1802,2"
]

(* Both content strings are updated, and while streaming the split point is the real end marker: *)
VerificationTest[
    With[ { container = tcAppendResult[ "Textual", "before\nENDRESULT(deadbeef)\nafter" ] },
        {
            container[ "DynamicContent" ] === container[ "FullContent" ],
            Block[ { Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked = None },
                StringEndsQ[
                    First @ Wolfram`Chatbook`SendChat`Private`splitDynamicContent[ container[ "DynamicContent" ] <> "Done." ],
                    "ENDRESULT(abc123xyz)\n"
                ]
            ]
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ToolCalls-EndMarker-DynamicContent-GH#314@@Tests/FormattingToolCalls.wlt:1805,1-1820,2"
]

(* :!CodeAnalysis::EndBlock:: *)
