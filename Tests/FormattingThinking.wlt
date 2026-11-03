(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingThinking.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingThinking.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Characterization tests for think tags (literal <think>/<thinking> tags and reasoning summaries written as
   <think type='summary' id='...'>), the formatting of their contents, their labels and metadata, their serialization,
   and <speech-input> elements. They describe what the formatter currently does, so that a rewrite can be checked
   against them. Tests/Reasoning.wlt covers the reasoning stream conversion and chat messages; this file focuses on
   the formatter side.

   A think tag becomes an inline cell holding a template box with three arguments:
       { formatted thoughts, label boxes, metadata association }
   - closed tags give a "ThoughtsOpener" template box (collapsed, labeled "Thought for N seconds" or similar),
   - unterminated tags give a "ThinkingOpener" template box (expanded, labeled "Thinking..."), and
   - closed tags with only whitespace inside give an "EmptyThoughts" template box (label only).
   The metadata is <| "Type" -> "Literal" |> for literal tags and <| "Type" -> "Summary", "ID" -> ..., ... |> for
   reasoning summaries. CellToString reads it to write the tag back (see reasoningBoxToString in Reasoning.wl).

   Labels of literal tags depend on the global timers $thinkingStart and $thinkingEnd (reset for each chat by
   withChatState), and streaming output is cached in $resultCellCache (reset for each response by SendChat.wl), so
   every test runs in thinkingState, which gives each test a fresh copy of that state. *)

thinkingState // Attributes = { HoldFirst };
thinkingState[ eval_ ] := thinkingState[ eval, None, None, <| |> ];
thinkingState[ eval_, start_, end_ ] := thinkingState[ eval, start, end, <| |> ];
thinkingState[ eval_, start_, end_, data_Association ] := Block[
    {
        Wolfram`Chatbook`Common`$thinkingStart   = start,
        Wolfram`Chatbook`Common`$thinkingEnd     = end,
        Wolfram`Chatbook`Common`$resultCellCache = <| |>,
        Wolfram`Chatbook`Common`$reasoningData   = data
    },
    eval
];

(* Normalized TextData items (see NormalizeTextData in Tests/Common.wl): *)
thinkingFormat[ md_String ] := thinkingFormat[ md, "Finished" ];
thinkingFormat[ md_String, status_String ] := thinkingState @ NormalizeTextData @ FormatMarkdown[ md, status ];

(* Every think box in formatted items, as { template name, normalized thoughts, label, metadata }: *)
$$thinkingTemplate = "ThoughtsOpener" | "ThinkingOpener" | "EmptyThoughts";

thinkingBoxesIn[ items_ ] := Cases[
    items,
    TemplateBox[ { thoughts_, label_, meta_ }, name: $$thinkingTemplate, ___ ] :>
        { name, NormalizeTextData @ thoughts, label, meta },
    Infinity
];

thinkingBoxes[ md_String ] := thinkingBoxes[ md, "Finished" ];
thinkingBoxes[ md_String, status_String ] := thinkingState @ thinkingBoxesIn @ FormatMarkdown[ md, status ];

(* The normalized thoughts of the first think box: *)
thinkingThoughts[ md_String ] := thinkingThoughts[ md, "Finished" ];
thinkingThoughts[ md_String, status_String ] := First[ thinkingBoxes[ md, status ], { $Failed, $Failed } ][[ 2 ]];

(* Round trip through CellToString, ignoring the invisible spaces that come before some line breaks: *)
thinkingRoundTrip[ md_String ] := thinkingRoundTrip[ md, "Finished" ];
thinkingRoundTrip[ md_String, status_String ] :=
    thinkingState @ StringReplace[ MarkdownRoundTrip[ md, status ], " ".. ~~ "\n" -> "\n" ];

(* Patterns for the inline cells that hold the think boxes. The thinking cell has no line break after it, since it
   always extends to the end of the text: *)
thinkingThoughtsCell[ thoughts_, label_, meta_ ] :=
    Cell[ BoxData @ TemplateBox[ { thoughts, label, meta }, "ThoughtsOpener", ___ ], "ThoughtsOpener", ___ ];

thinkingOpenerCell[ thoughts_, label_, meta_ ] :=
    Cell[ BoxData @ TemplateBox[ { thoughts, label, meta }, "ThinkingOpener", ___ ], "ThinkingOpener", ___ ];

(* Empty thoughts use the "ThoughtsOpener" cell style with the "EmptyThoughts" template box: *)
thinkingEmptyCell[ label_, meta_ ] :=
    Cell[ BoxData @ TemplateBox[ { "", label, meta }, "EmptyThoughts", ___ ], "ThoughtsOpener", ___ ];

(* Plain thoughts, which could be stored as TextData (split into any number of strings) or as a string with no visible
   difference: *)
thinkingText[ s_String ] := _? (MatchQ[ NormalizeTextData @ #, TextData @ { s } | s ] &);

(* Labels. Fixed labels are front end resources, so they are localized by the front end; labels with a number of
   seconds are created in the kernel from the "FormattingThinkingComplete" template: *)
thinkingResourceLabel[ name_String ] :=
    DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", name ], ___ ], ___ ];

$thinkingActiveLabel    = thinkingResourceLabel[ "FormattingThinkingActive"           ]; (* "Thinking..."          *)
$thinkingFallbackLabel  = thinkingResourceLabel[ "FormattingThinkingCompleteFallback" ]; (* "Thought"              *)
$thinkingOneSecondLabel = thinkingResourceLabel[ "FormattingThinkingCompleteSingular" ]; (* "Thought for a second" *)

thinkingSecondsLabel[ n_Integer ] :=
    With[ { s = "Thought for " <> ToString @ n <> " seconds" }, ToBoxes @ s | s ];

$thinkingLiteralMeta = <| "Type" -> "Literal" |>;

(* Metadata with exactly these keys and values, in any order: *)
thinkingMeta[ rules___Rule ] := With[ { r = Sort @ { rules } }, _Association? (Sort @ Normal @ # === r &) ];

$$thinkingBullet = StyleBox[ "\[Bullet]", FontColor -> _ ];

(* The tool short names of the default tools, as in a chat, so that simple tool calls like "/wl" are recognized: *)
$thinkingHandlerData := <|
    "ToolShortNames" -> Association @ KeyValueMap[
        Wolfram`Chatbook`Common`toolShortName[ #2 ] -> #2 &,
        Wolfram`Chatbook`$DefaultTools
    ]
|>;

(* formatSpeechInput currently fails for every input (see the Speech Input section), so the speech tests replace it
   with this stub to check which text the parsing rules pass to it: *)
thinkingSpeechStub // ClearAll;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Think Tags*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Closed Tags*)

(* A closed <think> tag becomes a collapsed "ThoughtsOpener" box. Its trailing line break is trimmed at the end of
   the text. Without timers, literal tags get the fallback label: *)
VerificationTest[
    thinkingFormat[ "<think>Some thoughts</think>" ],
    { thinkingThoughtsCell[ thinkingText[ "Some thoughts" ], $thinkingFallbackLabel, $thinkingLiteralMeta ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Literal-Closed@@Tests/FormattingThinking.wlt:140,1-145,2"
]

(* <thinking> tags are treated the same as <think> tags: *)
VerificationTest[
    thinkingFormat[ "<thinking>Some thoughts</thinking>" ],
    { thinkingThoughtsCell[ thinkingText[ "Some thoughts" ], $thinkingFallbackLabel, $thinkingLiteralMeta ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thinking-Tag-Closed@@Tests/FormattingThinking.wlt:148,1-153,2"
]

(* Tags are matched case-insensitively: *)
VerificationTest[
    thinkingBoxes /@ { "<THINK>A</THINK>", "<Thinking>B</THINKING>", "<think>C</THINK>" },
    {
        { { "ThoughtsOpener", TextData @ { "A" }, $thinkingFallbackLabel, $thinkingLiteralMeta } },
        { { "ThoughtsOpener", TextData @ { "B" }, $thinkingFallbackLabel, $thinkingLiteralMeta } },
        { { "ThoughtsOpener", TextData @ { "C" }, $thinkingFallbackLabel, $thinkingLiteralMeta } }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Tags-Ignore-Case@@Tests/FormattingThinking.wlt:156,1-165,2"
]

(* The box is followed by a line break, so the text after it starts on a new line after a blank line: *)
VerificationTest[
    thinkingFormat[ "Before\n<think>\nSome thoughts\n</think>\nAfter" ],
    {
        "Before\n",
        thinkingThoughtsCell[ thinkingText[ "Some thoughts" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\nAfter"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Text-Before-And-After@@Tests/FormattingThinking.wlt:168,1-177,2"
]

(* Blank lines around the tags give the same result: *)
VerificationTest[
    thinkingFormat[ "Before\n\n<think>\nSome thoughts\n</think>\n\nAfter" ],
    thinkingFormat[ "Before\n<think>\nSome thoughts\n</think>\nAfter" ],
    SameTest -> MatchQ,
    TestID   -> "Thinking-Blank-Lines-Around@@Tests/FormattingThinking.wlt:180,1-185,2"
]

(* Text directly after the closing tag still starts on a new line: *)
VerificationTest[
    thinkingFormat[ "<think>x</think>Answer" ],
    { thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ], "\nAnswer" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Text-Directly-After@@Tests/FormattingThinking.wlt:188,1-193,2"
]

(* Extra blank lines after the closing tag are kept: *)
VerificationTest[
    thinkingFormat[ "<think>x</think>\n\n\nAnswer" ],
    { thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ], "\n\n\nAnswer" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Extra-Blank-Lines-After@@Tests/FormattingThinking.wlt:196,1-201,2"
]

(* Text directly before the opening tag stays on the same line: *)
VerificationTest[
    thinkingFormat[ "Answer:<think>x</think>" ],
    { "Answer:", thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Text-Directly-Before@@Tests/FormattingThinking.wlt:204,1-209,2"
]

(* A think tag in the middle of a paragraph is recognized, and the rest of the paragraph starts on a new line: *)
VerificationTest[
    thinkingFormat[ "Hello <think>x</think> world" ],
    {
        "Hello ",
        thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        s_String /; StringStartsQ[ s, "\n" ] && StringTrim @ s === "world"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Mid-Paragraph@@Tests/FormattingThinking.wlt:212,1-221,2"
]

(* Whitespace around the only think tag is trimmed: *)
VerificationTest[
    thinkingFormat[ "   <think>x</think>   " ],
    { thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Surrounding-Whitespace@@Tests/FormattingThinking.wlt:224,1-229,2"
]

(* Several think blocks are formatted separately: *)
VerificationTest[
    thinkingFormat[ "<think>A</think>\nMiddle\n<think>B</think>\nEnd" ],
    {
        thinkingThoughtsCell[ thinkingText[ "A" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\nMiddle\n",
        thinkingThoughtsCell[ thinkingText[ "B" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\nEnd"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Multiple-Blocks@@Tests/FormattingThinking.wlt:232,1-242,2"
]

(* Adjacent think blocks are separated by a single line break: *)
VerificationTest[
    thinkingFormat[ "<think type='summary' id='a'>A</think><think type='summary' id='b'>B</think>Done" ],
    {
        thinkingThoughtsCell[ thinkingText[ "A" ], $thinkingFallbackLabel, thinkingMeta[ "Type" -> "Summary", "ID" -> "a" ] ],
        "\n",
        thinkingThoughtsCell[ thinkingText[ "B" ], $thinkingFallbackLabel, thinkingMeta[ "Type" -> "Summary", "ID" -> "b" ] ],
        "\nDone"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Adjacent-Blocks@@Tests/FormattingThinking.wlt:245,1-255,2"
]

(* Consecutive summaries as Chatbook writes them (each closed with "\n</think>\n", see Reasoning.wl) are separated by
   a blank line: *)
VerificationTest[
    thinkingFormat[ "<think type='summary' id='a'>\nA\n</think>\n<think type='summary' id='b'>\nB\n</think>\nDone" ],
    {
        thinkingThoughtsCell[ thinkingText[ "A" ], $thinkingFallbackLabel, thinkingMeta[ "Type" -> "Summary", "ID" -> "a" ] ],
        "\n\n",
        thinkingThoughtsCell[ thinkingText[ "B" ], $thinkingFallbackLabel, thinkingMeta[ "Type" -> "Summary", "ID" -> "b" ] ],
        "\n\nDone"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Consecutive-Summaries@@Tests/FormattingThinking.wlt:259,1-269,2"
]

(* Think tags don't nest: the first closing tag ends the block, and the rest is plain text: *)
VerificationTest[
    thinkingFormat[ "<think>a<think>b</think>c</think>" ],
    {
        thinkingThoughtsCell[ thinkingText[ "a<think>b" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\nc</think>"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-First-Closing-Tag-Wins@@Tests/FormattingThinking.wlt:272,1-280,2"
]

(* Long thoughts are kept as a single string: *)
VerificationTest[
    thinkingThoughts[ "<think>" <> StringRepeat[ "word ", 2000 ] <> "</think>" ],
    TextData @ { s_String /; s === StringTrim @ StringRepeat[ "word ", 2000 ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Long-Thoughts@@Tests/FormattingThinking.wlt:283,1-288,2"
]

(* Unicode in thoughts is kept as is: *)
VerificationTest[
    thinkingThoughts[ "<think>\:4f60\:597d \[Alpha] \|01f600</think>" ],
    TextData @ { "\:4f60\:597d \[Alpha] \|01f600" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Unicode@@Tests/FormattingThinking.wlt:291,1-296,2"
]

(* With "\r\n" line endings, the tags are recognized, and the text around them is the same as with "\n": *)
VerificationTest[
    thinkingFormat[ "Before\r\n<think>\r\nSome thoughts\r\n</think>\r\nAfter" ],
    {
        "Before\n",
        thinkingThoughtsCell[ thinkingText[ "Some thoughts" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\nAfter"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-CRLF@@Tests/FormattingThinking.wlt:299,1-308,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Interaction With Other Blocks*)

(* Think tags inside a code block are part of the code: *)
VerificationTest[
    thinkingState @ {
        thinkingBoxesIn @ FormatMarkdown[ "```\n<think>x</think>\n```" ],
        FormatMarkdown[ "```\n<think>x</think>\n```" ]
    },
    {
        { },
        {
            Cell[
                BoxData @ TemplateBox[ { Cell[ "<think>x</think>", "ChatPreformatted", ___ ], "" }, "ChatCodeBlockTemplate" ],
                "ChatCodeBlock",
                ___
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Inside-Code-Block@@Tests/FormattingThinking.wlt:315,1-332,2"
]

(* Think tags inside inline code are part of the code: *)
VerificationTest[
    thinkingFormat[ "Use `<think>x</think>` tags" ],
    {
        "Use ",
        Cell[ BoxData @ TemplateBox[ { Cell[ "<think>x</think>", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive", ___ ],
        " tags"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Inside-Inline-Code@@Tests/FormattingThinking.wlt:335,1-344,2"
]

(* Line breaks between a think box and the block-level content around it: *)
VerificationTest[
    thinkingFormat[ "```python\nx=1\n```\n<think>x</think>\nBody" ],
    {
        Cell[ BoxData @ TemplateBox[ { _, "Python" }, "ChatCodeBlockTemplate" ], "ChatCodeBlock", ___ ],
        "\n",
        thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\nBody"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-After-Code-Block@@Tests/FormattingThinking.wlt:347,1-357,2"
]

VerificationTest[
    thinkingFormat[ "<think>x</think>\n```python\nx=1\n```" ],
    {
        thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\n",
        Cell[ BoxData @ TemplateBox[ { _, "Python" }, "ChatCodeBlockTemplate" ], "ChatCodeBlock", ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Before-Code-Block@@Tests/FormattingThinking.wlt:359,1-368,2"
]

VerificationTest[
    thinkingFormat[ "# Title\n<think>x</think>\nBody" ],
    {
        Cell[ BoxData @ PaneBox[ StyleBox[ "\"Title\"" | "Title", "Title", ___ ], ___ ], "InlineSection", ___ ],
        "\n",
        thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\nBody"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-After-Heading@@Tests/FormattingThinking.wlt:370,1-380,2"
]

VerificationTest[
    thinkingFormat[ "<think>t</think>\n## Heading\ntext" ],
    {
        thinkingThoughtsCell[ thinkingText[ "t" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\n",
        Cell[ BoxData @ PaneBox[ StyleBox[ "\"Heading\"" | "Heading", "Section", ___ ], ___ ], "InlineSection", ___ ],
        "\ntext"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Before-Heading@@Tests/FormattingThinking.wlt:382,1-392,2"
]

VerificationTest[
    thinkingFormat[ "<think>x</think>\n- a\n- b" ],
    {
        thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\n",
        Cell[ TextData @ { $$thinkingBullet, " a" }, "InlineItem" ],
        "\n",
        Cell[ TextData @ { $$thinkingBullet, " b" }, "InlineItem" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Before-List@@Tests/FormattingThinking.wlt:394,1-405,2"
]

(* After a list, the box starts on the next line, with or without a blank line before the tag: *)
VerificationTest[
    {
        thinkingFormat[ "- a\n- b\n<think>x</think>\nBody" ],
        thinkingFormat[ "- a\n- b\n\n<think>x</think>\nBody" ]
    },
    ConstantArray[
        {
            Cell[ TextData @ { $$thinkingBullet, " a" }, "InlineItem" ],
            "\n",
            Cell[ TextData @ { $$thinkingBullet, " b" }, "InlineItem" ],
            "\n",
            thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
            "\n\nBody"
        },
        2
    ],
    SameTest -> MatchQ,
    TestID   -> "Thinking-After-List@@Tests/FormattingThinking.wlt:408,1-426,2"
]

VerificationTest[
    thinkingFormat[ "<think>x</think>\n| a | b |\n|---|---|\n| 1 | 2 |" ],
    {
        thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\n",
        Cell[ _BoxData, "TextTableForm", ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Before-Table@@Tests/FormattingThinking.wlt:428,1-437,2"
]

VerificationTest[
    thinkingFormat[ "<think>x</think>\n---\nAfter" ],
    {
        thinkingThoughtsCell[ thinkingText[ "x" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\n",
        Cell[ _BoxData, "MarkdownDelimiter", ___ ],
        "\nAfter"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Before-Delimiter@@Tests/FormattingThinking.wlt:439,1-449,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unterminated Tags*)

(* A tag that hasn't been closed yet (while streaming) becomes an expanded "ThinkingOpener" box with the active
   label, and extends to the end of the text: *)
VerificationTest[
    thinkingFormat[ "<think>Still going" ],
    { thinkingOpenerCell[ thinkingText[ "Still going" ], $thinkingActiveLabel, $thinkingLiteralMeta ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Unterminated@@Tests/FormattingThinking.wlt:457,1-462,2"
]

VerificationTest[
    thinkingFormat[ "<thinking>Still going" ],
    { thinkingOpenerCell[ thinkingText[ "Still going" ], $thinkingActiveLabel, $thinkingLiteralMeta ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Unterminated-Thinking-Tag@@Tests/FormattingThinking.wlt:464,1-469,2"
]

(* Right after the opening tag and a line break, the box is shown with no thoughts yet: *)
VerificationTest[
    thinkingBoxes /@ { "<think>\n", "<thinking>\n", "<think type='summary'>" },
    {
        { { "ThinkingOpener", "", $thinkingActiveLabel, $thinkingLiteralMeta } },
        { { "ThinkingOpener", "", $thinkingActiveLabel, $thinkingLiteralMeta } },
        { { "ThinkingOpener", "", $thinkingActiveLabel, thinkingMeta[ "Type" -> "Summary" ] } }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Unterminated-Just-Opened@@Tests/FormattingThinking.wlt:472,1-481,2"
]

(* A closed block followed by an unterminated one: *)
VerificationTest[
    thinkingFormat[ "<think>A</think>\nMiddle\n<think>B" ],
    {
        thinkingThoughtsCell[ thinkingText[ "A" ], $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\nMiddle\n",
        thinkingOpenerCell[ thinkingText[ "B" ], $thinkingActiveLabel, $thinkingLiteralMeta ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Closed-Then-Unterminated@@Tests/FormattingThinking.wlt:484,1-493,2"
]

VerificationTest[
    thinkingFormat[ "<think type='summary' id='a'>A</think>\n<think>B" ],
    {
        thinkingThoughtsCell[ thinkingText[ "A" ], $thinkingFallbackLabel, thinkingMeta[ "Type" -> "Summary", "ID" -> "a" ] ],
        "\n\n",
        thinkingOpenerCell[ thinkingText[ "B" ], $thinkingActiveLabel, $thinkingLiteralMeta ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Summary-Then-Unterminated-Literal@@Tests/FormattingThinking.wlt:495,1-504,2"
]

(* The thinking box is shown the same way while streaming: *)
VerificationTest[
    thinkingFormat[ "<think>Still going", "Streaming" ],
    thinkingFormat[ "<think>Still going", "Finished" ],
    SameTest -> MatchQ,
    TestID   -> "Thinking-Unterminated-Streaming@@Tests/FormattingThinking.wlt:507,1-512,2"
]

(* The active label is used even when the summary has a stored duration: *)
VerificationTest[
    thinkingState[
        thinkingBoxesIn @ FormatMarkdown[ "<think type='summary' id='a'>x" ],
        None,
        None,
        <| "a" -> <| "Duration" -> 12.6 |> |>
    ],
    { { "ThinkingOpener", TextData @ { "x" }, $thinkingActiveLabel, thinkingMeta[ "Type" -> "Summary", "ID" -> "a", "Duration" -> 12.6 ] } },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Unterminated-Ignores-Duration@@Tests/FormattingThinking.wlt:515,1-525,2"
]

(* Formatting a thinking box starts the timer for literal tags (if it hasn't started yet), and leaves the end time
   alone. Summaries in progress start it too: *)
VerificationTest[
    {
        thinkingState[
            FormatMarkdown[ "<think>x" ];
            { NumberQ @ Wolfram`Chatbook`Common`$thinkingStart, Wolfram`Chatbook`Common`$thinkingEnd }
        ],
        thinkingState[
            FormatMarkdown[ "<think>x" ];
            { Wolfram`Chatbook`Common`$thinkingStart, Wolfram`Chatbook`Common`$thinkingEnd },
            5.,
            None
        ],
        thinkingState[
            FormatMarkdown[ "<think type='summary' id='a'>x" ];
            NumberQ @ Wolfram`Chatbook`Common`$thinkingStart
        ]
    },
    { { True, None }, { 5., None }, True },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Unterminated-Starts-Timer@@Tests/FormattingThinking.wlt:529,1-549,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Empty Thoughts*)

(* Closed tags with only whitespace inside show only the label, in an "EmptyThoughts" box with the "ThoughtsOpener"
   cell style: *)
VerificationTest[
    thinkingFormat /@ { "<think> </think>", "<thinking>\n\n</thinking>" },
    {
        { thinkingEmptyCell[ $thinkingFallbackLabel, $thinkingLiteralMeta ] },
        { thinkingEmptyCell[ $thinkingFallbackLabel, $thinkingLiteralMeta ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Empty-Whitespace@@Tests/FormattingThinking.wlt:557,1-565,2"
]

VerificationTest[
    thinkingFormat[ "<think>\n\n</think>\nAnswer" ],
    { thinkingEmptyCell[ $thinkingFallbackLabel, $thinkingLiteralMeta ], "\n\nAnswer" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Empty-Then-Text@@Tests/FormattingThinking.wlt:567,1-572,2"
]

(* Empty thoughts get the same labels as other closed tags: *)
VerificationTest[
    {
        thinkingState[ NormalizeTextData @ FormatMarkdown[ "<think>\n</think>\nAnswer" ], 10., 13. ],
        thinkingState[
            NormalizeTextData @ FormatMarkdown[ "<think type='summary' id='a'>\n</think>\nAnswer" ],
            None,
            None,
            <| "a" -> <| "Duration" -> 12.6 |> |>
        ]
    },
    {
        { thinkingEmptyCell[ thinkingSecondsLabel @ 3, $thinkingLiteralMeta ], "\n\nAnswer" },
        {
            thinkingEmptyCell[ thinkingSecondsLabel @ 13, thinkingMeta[ "Type" -> "Summary", "ID" -> "a", "Duration" -> 12.6 ] ],
            "\n\nAnswer"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Empty-Labels@@Tests/FormattingThinking.wlt:575,1-594,2"
]

(* Summary tags may have no content at all (a reasoning item without a summary still gets a tag to hold its
   signature), unlike literal tags (see the report for "<think></think>"): *)
VerificationTest[
    thinkingFormat /@ { "<think type='summary' id='a'></think>\nAnswer", "<think type='summary'>\n</think>\nAnswer" },
    {
        { thinkingEmptyCell[ $thinkingFallbackLabel, thinkingMeta[ "Type" -> "Summary", "ID" -> "a" ] ], "\n\nAnswer" },
        { thinkingEmptyCell[ $thinkingFallbackLabel, thinkingMeta[ "Type" -> "Summary" ] ], "\n\nAnswer" }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Empty-Summary@@Tests/FormattingThinking.wlt:598,1-606,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attributes and Metadata*)

(* Attributes that don't mark a reasoning summary (including unquoted values, which aren't parsed) give literal
   metadata: *)
VerificationTest[
    thinkingBoxes /@ {
        "<think >x</think>",
        "<think foo='bar'>x</think>",
        "<think type='other' id='a'>x</think>",
        "<think id='a'>x</think>",
        "<think type=summary id=a>x</think>"
    },
    ConstantArray[ { { "ThoughtsOpener", TextData @ { "x" }, $thinkingFallbackLabel, $thinkingLiteralMeta } }, 5 ],
    SameTest -> MatchQ,
    TestID   -> "Thinking-Attributes-Literal@@Tests/FormattingThinking.wlt:614,1-625,2"
]

(* type='summary' marks a reasoning summary. The ID is kept even if no reasoning data is stored for it: *)
VerificationTest[
    thinkingBoxes /@ {
        "<think type='summary' id='abc'>x</think>",
        "<think type=\"summary\" id=\"abc\">x</think>",
        "<think TYPE='SUMMARY' ID='abc'>x</think>",
        "<think\ntype = 'summary'\tid='abc'>x</think>",
        "<THINK type='summary' id='abc'>x</THINK>"
    },
    ConstantArray[
        { { "ThoughtsOpener", TextData @ { "x" }, $thinkingFallbackLabel, thinkingMeta[ "Type" -> "Summary", "ID" -> "abc" ] } },
        5
    ],
    SameTest -> MatchQ,
    TestID   -> "Thinking-Summary-Attributes@@Tests/FormattingThinking.wlt:628,1-642,2"
]

(* A summary without an ID: *)
VerificationTest[
    thinkingBoxes[ "<think type='summary'>x</think>" ],
    { { "ThoughtsOpener", TextData @ { "x" }, $thinkingFallbackLabel, thinkingMeta[ "Type" -> "Summary" ] } },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Summary-No-ID@@Tests/FormattingThinking.wlt:645,1-650,2"
]

(* An empty ID is still an ID: *)
VerificationTest[
    thinkingState[
        thinkingBoxesIn @ FormatMarkdown[ "<think type='summary' id=''>x</think>" ],
        None,
        None,
        <| "" -> <| "Duration" -> 12.6 |> |>
    ],
    { { "ThoughtsOpener", TextData @ { "x" }, thinkingSecondsLabel @ 13, thinkingMeta[ "Type" -> "Summary", "ID" -> "", "Duration" -> 12.6 ] } },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Summary-Empty-ID@@Tests/FormattingThinking.wlt:653,1-663,2"
]

(* Only the known keys of the stored reasoning data are copied into the metadata: *)
VerificationTest[
    thinkingState[
        thinkingBoxesIn @ FormatMarkdown[ "<think type='summary' id='abc'>x</think>" ],
        None,
        None,
        <|
            "abc" -> <|
                "Signature" -> ByteArray @ { 1, 2 },
                "CallID"    -> "rs_1",
                "Service"   -> "OpenAI",
                "Model"     -> "gpt",
                "Duration"  -> 7.4,
                "Extra"     -> 1
            |>
        |>
    ],
    {
        {
            "ThoughtsOpener",
            TextData @ { "x" },
            thinkingSecondsLabel @ 7,
            thinkingMeta[
                "Type"      -> "Summary",
                "ID"        -> "abc",
                "Signature" -> ByteArray @ { 1, 2 },
                "CallID"    -> "rs_1",
                "Service"   -> "OpenAI",
                "Model"     -> "gpt",
                "Duration"  -> 7.4
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Summary-Stored-Data@@Tests/FormattingThinking.wlt:666,1-700,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Labels*)

(* Summary labels use the stored duration, rounded (half to even) with a minimum of one second. Durations that
   aren't numbers give the fallback label: *)
VerificationTest[
    Map[
        thinkingState[
            thinkingBoxesIn[ FormatMarkdown[ "<think type='summary' id='a'>x</think>" ] ][[ 1, 3 ]],
            None,
            None,
            <| "a" -> # |>
        ] &,
        {
            <| "Duration" -> 0 |>,
            <| "Duration" -> 0.3 |>,
            <| "Duration" -> 1.5 |>,
            <| "Duration" -> 2.5 |>,
            <| "Duration" -> 61 |>,
            <| "Duration" -> Missing[ "NotAvailable" ] |>,
            <| "Duration" -> "5" |>,
            <| "Signature" -> ByteArray @ { 1 } |>
        }
    ],
    {
        $thinkingOneSecondLabel,
        $thinkingOneSecondLabel,
        thinkingSecondsLabel @ 2,
        thinkingSecondsLabel @ 2,
        thinkingSecondsLabel @ 61,
        $thinkingFallbackLabel,
        $thinkingFallbackLabel,
        $thinkingFallbackLabel
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Label-Summary-Durations@@Tests/FormattingThinking.wlt:708,1-739,2"
]

(* Literal tags are timed from $thinkingStart (set when a thinking box is first formatted) to $thinkingEnd (set when
   a closed box is first formatted), with the same rounding: *)
VerificationTest[
    Map[
        thinkingState[ thinkingBoxesIn[ FormatMarkdown[ "<think>x</think>" ] ][[ 1, 3 ]], #[[ 1 ]], #[[ 2 ]] ] &,
        { { 100., 105.4 }, { 100., 100.2 }, { 100., 101.6 }, { None, 105. } }
    ],
    { thinkingSecondsLabel @ 5, $thinkingOneSecondLabel, thinkingSecondsLabel @ 2, $thinkingFallbackLabel },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Label-Literal-Timers@@Tests/FormattingThinking.wlt:743,1-751,2"
]

(* Formatting a closed literal tag sets the end time if it isn't set yet, and keeps it otherwise. Summaries don't
   change the timers: *)
VerificationTest[
    {
        thinkingState[ FormatMarkdown[ "<think>x</think>" ]; NumberQ @ Wolfram`Chatbook`Common`$thinkingEnd ],
        thinkingState[ FormatMarkdown[ "<think>x</think>" ]; Wolfram`Chatbook`Common`$thinkingEnd, 100., 103. ],
        thinkingState[
            FormatMarkdown[ "<think type='summary' id='a'>x</think>" ];
            { Wolfram`Chatbook`Common`$thinkingStart, Wolfram`Chatbook`Common`$thinkingEnd },
            100.,
            None
        ]
    },
    { True, 103., { 100., None } },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Label-Literal-Sets-End-Timer@@Tests/FormattingThinking.wlt:755,1-769,2"
]

(* There is only one pair of timers per response, so every literal block gets the same time. Summaries use their own
   durations: *)
VerificationTest[
    {
        thinkingState[ thinkingBoxesIn[ FormatMarkdown[ "<think>A</think>\nB\n<think>C</think>" ] ][[ All, 3 ]], 10., 13. ],
        thinkingState[
            thinkingBoxesIn[ FormatMarkdown[ "<think type='summary' id='a'>A</think>\nB\n<think>C</think>" ] ][[ All, 3 ]],
            10.,
            13.,
            <| "a" -> <| "Duration" -> 30. |> |>
        ]
    },
    {
        { thinkingSecondsLabel @ 3, thinkingSecondsLabel @ 3 },
        { thinkingSecondsLabel @ 30, thinkingSecondsLabel @ 3 }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Label-Multiple-Blocks@@Tests/FormattingThinking.wlt:773,1-789,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Thoughts Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Markdown*)

(* Markdown inside the thoughts is formatted like other chat output: *)
VerificationTest[
    thinkingThoughts[ "<think>**Bold** and *italic* and ~~strike~~</think>" ],
    TextData @ {
        StyleBox[ "Bold", FontWeight -> Bold ],
        " and ",
        StyleBox[ "italic", FontSlant -> Italic ],
        " and ",
        StyleBox[ "strike", FontVariations -> { "StrikeThrough" -> True } ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Inline-Styles@@Tests/FormattingThinking.wlt:800,1-811,2"
]

VerificationTest[
    thinkingThoughts[ "<think>Plan:\n- one\n- two\n  - sub</think>" ],
    TextData @ {
        "Plan:\n",
        Cell[ TextData @ { $$thinkingBullet, " one" }, "InlineItem" ],
        "\n",
        Cell[ TextData @ { $$thinkingBullet, " two" }, "InlineItem" ],
        "\n",
        Cell[ TextData @ { "  ", $$thinkingBullet, " sub" }, "InlineSubitem" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Bullets@@Tests/FormattingThinking.wlt:813,1-825,2"
]

(* The thoughts are trimmed, so a list at the start has no line break before it: *)
VerificationTest[
    thinkingThoughts[ "<think>\n- a\n- b\n</think>" ],
    TextData @ {
        Cell[ TextData @ { $$thinkingBullet, " a" }, "InlineItem" ],
        "\n",
        Cell[ TextData @ { $$thinkingBullet, " b" }, "InlineItem" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Starts-With-List@@Tests/FormattingThinking.wlt:828,1-837,2"
]

VerificationTest[
    thinkingThoughts[ "<think>\n\n  indented first\nsecond  \n\n</think>" ],
    TextData @ { "indented first\nsecond" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Trimmed@@Tests/FormattingThinking.wlt:839,1-844,2"
]

VerificationTest[
    thinkingThoughts[ "<think>## Heading\ntext</think>" ],
    TextData @ {
        Cell[
            BoxData @ PaneBox[ StyleBox[ "\"Heading\"" | "Heading", "Section", ___, FontSize -> 22, ___ ], ___ ],
            "InlineSection",
            ___
        ],
        "\ntext"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Heading@@Tests/FormattingThinking.wlt:846,1-858,2"
]

VerificationTest[
    thinkingThoughts[ "<think>Use `Prime[5]` and `foo bar`</think>" ],
    TextData @ {
        "Use ",
        Cell[ BoxData @ RowBox @ { "Prime", "[", "5", "]" }, "InlineWL", ___ ],
        " and ",
        Cell[ BoxData @ TemplateBox[ { Cell[ "foo bar", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive", ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Inline-Code@@Tests/FormattingThinking.wlt:860,1-870,2"
]

VerificationTest[
    thinkingThoughts[ "<think>Compute $$x^2$$ and \\(y\\)</think>" ],
    TextData @ {
        "Compute ",
        Cell @ BoxData @ FormBox[
            TemplateBox[ KeyValuePattern @ { "input" -> "x^2", "state" -> "Boxes" }, "TeXAssistantTemplate" ],
            TraditionalForm
        ],
        " and ",
        Cell @ BoxData @ FormBox[
            TemplateBox[ KeyValuePattern @ { "input" -> "y", "state" -> "Boxes" }, "TeXAssistantTemplate" ],
            TraditionalForm
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Math@@Tests/FormattingThinking.wlt:872,1-888,2"
]

(* Single dollar signs around prices are not math: *)
VerificationTest[
    thinkingThoughts[ "<think>costs $5 and $10</think>" ],
    TextData @ { "costs $5 and $10" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Dollar-Signs@@Tests/FormattingThinking.wlt:891,1-896,2"
]

(* Underscores inside names are not emphasis: *)
VerificationTest[
    thinkingThoughts[ "<think>use snake_case_name and _emph_</think>" ],
    TextData @ { "use snake_case_name and ", StyleBox[ "emph", FontSlant -> Italic ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Underscores@@Tests/FormattingThinking.wlt:899,1-904,2"
]

VerificationTest[
    thinkingThoughts[ "<think>| a | b |\n|---|---|\n| 1 | 2 |</think>" ],
    TextData @ { Cell[ _BoxData, "TextTableForm", ___ ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Table@@Tests/FormattingThinking.wlt:906,1-911,2"
]

VerificationTest[
    thinkingThoughts[ "<think>> quoted\ntext</think>" ],
    TextData @ {
        Cell[ BoxData @ GridBox[ { { PaneBox[ "\"quoted\"" | "quoted", ___ ] } }, ___ ], "BlockQuote", ___ ],
        s_String /; StringTrim @ s === "text"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Block-Quote@@Tests/FormattingThinking.wlt:913,1-921,2"
]

VerificationTest[
    thinkingThoughts[ "<think>a\n\n---\n\nb</think>" ],
    TextData @ { "a\n", Cell[ _BoxData, "MarkdownDelimiter", ___ ], "\nb" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Delimiter@@Tests/FormattingThinking.wlt:923,1-928,2"
]

VerificationTest[
    thinkingThoughts[ "<think>See [docs](https://reference.wolfram.com/language/ref/Plus.html)</think>" ],
    TextData @ {
        "See ",
        ButtonBox[
            "docs",
            OrderlessPatternSequence[
                BaseStyle  -> "Hyperlink",
                ButtonData -> { URL[ "https://reference.wolfram.com/language/ref/Plus.html" ], None },
                ___
            ]
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Hyperlink@@Tests/FormattingThinking.wlt:930,1-945,2"
]

(* Markdown escapes and HTML entities in thoughts: *)
VerificationTest[
    thinkingThoughts /@ { "<think>a \\* b \\_c\\_</think>", "<think>fish &amp; chips</think>" },
    { TextData @ { "a * b _c_" }, TextData @ { "fish & chips" } },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Escapes@@Tests/FormattingThinking.wlt:948,1-953,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Code Blocks*)

(* Code blocks in thoughts are formatted as code blocks. While streaming they use the cheaper preformatted display: *)
VerificationTest[
    {
        thinkingThoughts[ "<think>```python\nprint(1)\n```</think>", "Finished" ],
        thinkingThoughts[ "<think>```python\nprint(1)\n```</think>", "Streaming" ]
    },
    {
        TextData @ {
            Cell[
                BoxData @ TemplateBox[ { c_ /; ! FreeQ[ c, Cell[ "print(1)", "ExternalLanguage", ___ ] ], "Python" }, "ChatCodeBlockTemplate" ],
                "ChatCodeBlock",
                ___
            ]
        },
        TextData @ {
            Cell[
                BoxData @ TemplateBox[ { Cell[ "print(1)", "ChatPreformatted", ___ ], "Python" }, "ChatCodeBlockTemplate" ],
                "ChatCodeBlock",
                ___
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Code-Block@@Tests/FormattingThinking.wlt:960,1-983,2"
]

VerificationTest[
    {
        thinkingThoughts[ "<think>\n```wl\n1+1\n```\n</think>\nok", "Finished" ],
        thinkingThoughts[ "<think>\n```wl\n1+1\n```\n</think>\nok", "Streaming" ]
    },
    {
        TextData @ {
            Cell[
                BoxData @ TemplateBox[ { Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "ChatCode", ___ ], "Wolfram" }, "ChatCodeBlockTemplate" ],
                "ChatCodeBlock",
                ___
            ]
        },
        TextData @ {
            Cell[
                (* The streaming display shows the language name as written; that belongs to the code block tests: *)
                BoxData @ TemplateBox[ { Cell[ BoxData[ "1+1" ], "ChatCodeActive", ___ ], "wl" | "Wolfram" }, "ChatCodeBlockTemplate" ],
                "ChatCodeBlock",
                ___
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-WL-Code-Block@@Tests/FormattingThinking.wlt:985,1-1009,2"
]

(* An unterminated code block in unterminated thoughts extends to the end. This is what is shown while both are being
   streamed, so the streaming display uses the cheap preformatted code: *)
VerificationTest[
    {
        thinkingBoxes[ "<think>```python\nprint(1)", "Finished" ],
        thinkingBoxes[ "<think>```python\nprint(1)", "Streaming" ]
    },
    {
        {
            {
                "ThinkingOpener",
                TextData @ {
                    Cell[
                        BoxData @ TemplateBox[
                            { c_ /; ! FreeQ[ c, Cell[ "print(1)", "ExternalLanguage", ___ ] ], "Python" },
                            "ChatCodeBlockTemplate"
                        ],
                        "ChatCodeBlock",
                        ___
                    ]
                },
                $thinkingActiveLabel,
                $thinkingLiteralMeta
            }
        },
        {
            {
                "ThinkingOpener",
                TextData @ {
                    Cell[
                        BoxData @ TemplateBox[ { Cell[ "print(1)", "ChatPreformatted", ___ ], "Python" }, "ChatCodeBlockTemplate" ],
                        "ChatCodeBlock",
                        ___
                    ]
                },
                $thinkingActiveLabel,
                $thinkingLiteralMeta
            }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Unterminated-Code-Block@@Tests/FormattingThinking.wlt:1013,1-1053,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Plain Text*)

(* Text in thoughts that looks like a tool call, a retry command, or another think tag stays plain text: *)
VerificationTest[
    thinkingThoughts /@ {
        "<think>TOOLCALL: fake\n{}\nENDTOOLCALL\nafter</think>",
        "<think>a\n/retry\nb</think>",
        "<think>a <thinking>b</thinking> c</think>",
        "<think>a <think type='summary' id='x'>b</think>",
        "<think>a\n<thinking>b</think>"
    },
    {
        TextData @ { "TOOLCALL: fake\n{}\nENDTOOLCALL\nafter" },
        TextData @ { "a\n/retry\nb" },
        TextData @ { "a <thinking>b</thinking> c" },
        TextData @ { "a <think type='summary' id='x'>b" },
        TextData @ { "a\n<thinking>b" }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Plain-Text@@Tests/FormattingThinking.wlt:1060,1-1077,2"
]

(* Simple tool calls ("/wl ... /exec") are formatted as tool calls outside of thoughts, but not inside: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = $thinkingHandlerData },
        {
            thinkingThoughts[ "<think>call:\n/wl\nPrime[5]\n/exec\ndone</think>" ],
            Cases[ thinkingFormat[ "call:\n/wl\nPrime[5]\n/exec\ndone" ], Cell[ _, "InlineToolCall", ___ ] ]
        }
    ],
    { TextData @ { "call:\n/wl\nPrime[5]\n/exec\ndone" }, { _Cell } },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Thoughts-Simple-Tool-Call-Plain@@Tests/FormattingThinking.wlt:1080,1-1090,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Escaped Markdown*)

(* Think tags in text with markdown escapes have the same metadata, formatted thoughts and line breaks around the box
   as without escapes: *)
VerificationTest[
    thinkingFormat[ "\\*not italic\\*\n<think>**bold**</think>\nafter" ],
    {
        "*not italic*\n",
        thinkingThoughtsCell[ TextData @ { StyleBox[ "bold", FontWeight -> Bold ] }, $thinkingFallbackLabel, $thinkingLiteralMeta ],
        "\n\nafter"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Escaped-Literal@@Tests/FormattingThinking.wlt:1098,1-1107,2"
]

VerificationTest[
    thinkingBoxes /@ {
        "\\*x\\*\n<think type='summary' id='abc'>**s** \\_y\\_</think>\nDone",
        "\\*x\\*\n<think>going \\* on",
        "\\*x\\*\n<thinking>y</thinking>\nDone",
        "\\*x\\*\n<think> </think>\nDone"
    },
    {
        {
            {
                "ThoughtsOpener",
                TextData @ { StyleBox[ "s", FontWeight -> Bold ], " _y_" },
                $thinkingFallbackLabel,
                thinkingMeta[ "Type" -> "Summary", "ID" -> "abc" ]
            }
        },
        { { "ThinkingOpener", TextData @ { "going * on" }, $thinkingActiveLabel, $thinkingLiteralMeta } },
        { { "ThoughtsOpener", TextData @ { "y" }, $thinkingFallbackLabel, $thinkingLiteralMeta } },
        { { "EmptyThoughts", "", $thinkingFallbackLabel, $thinkingLiteralMeta } }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Escaped-Tag-Types@@Tests/FormattingThinking.wlt:1109,1-1131,2"
]

(* The same in the streaming display: *)
VerificationTest[
    thinkingBoxes[ "\\*x\\*\n<think>going \\* on", "Streaming" ],
    { { "ThinkingOpener", TextData @ { "going * on" }, $thinkingActiveLabel, $thinkingLiteralMeta } },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Escaped-Streaming@@Tests/FormattingThinking.wlt:1134,1-1139,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streaming*)

(* Without code blocks in the thoughts, closed and empty think boxes are the same while streaming: *)
VerificationTest[
    Map[
        thinkingFormat[ #, "Streaming" ] === thinkingFormat[ #, "Finished" ] &,
        {
            "Before\n<think>\nSome **thoughts**\n- item\n</think>\nAfter",
            "<think type='summary' id='abc'>Summary</think>\nDone",
            "<think>\n</think>\nDone"
        }
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Streaming-Same-As-Finished@@Tests/FormattingThinking.wlt:1146,1-1158,2"
]

VerificationTest[
    thinkingState[ thinkingBoxesIn @ FormatMarkdown[ "<think>x</think>\nDone", "Streaming" ], 10., 13. ],
    { { "ThoughtsOpener", TextData @ { "x" }, thinkingSecondsLabel @ 3, $thinkingLiteralMeta } },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Streaming-Label@@Tests/FormattingThinking.wlt:1160,1-1165,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Literal Tags*)

(* Literal think boxes serialize as <think> tags, with the thoughts on their own lines, followed by a blank line: *)
VerificationTest[
    thinkingRoundTrip[ "<think>\nLiteral thoughts\n</think>\nThe answer." ],
    "<think>\nLiteral thoughts\n</think>\n\nThe answer.",
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Literal@@Tests/FormattingThinking.wlt:1176,1-1181,2"
]

(* <thinking> tags, other letter cases, and attributes that don't mark a summary are all written as <think>: *)
VerificationTest[
    thinkingRoundTrip /@ {
        "<thinking>Literal thoughts</thinking>\nDone",
        "<THINKING>Literal thoughts</THINKING>\nDone",
        "<think foo='bar'>Literal thoughts</think>\nDone"
    },
    ConstantArray[ "<think>\nLiteral thoughts\n</think>\n\nDone", 3 ],
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Normalized-Tags@@Tests/FormattingThinking.wlt:1184,1-1193,2"
]

(* An unterminated tag is written as a closed tag: *)
VerificationTest[
    thinkingRoundTrip /@ { "<think>Still going", "<think>\n" },
    { "<think>\nStill going\n</think>", "<think>\n\n</think>" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Unterminated@@Tests/FormattingThinking.wlt:1196,1-1201,2"
]

VerificationTest[
    thinkingRoundTrip[ "<think>\n\n</think>\nAnswer" ],
    "<think>\n\n</think>\n\nAnswer",
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Empty-Literal@@Tests/FormattingThinking.wlt:1203,1-1208,2"
]

VerificationTest[
    thinkingRoundTrip[ "<think>A</think>\nMiddle\n<think>B</think>\nEnd" ],
    "<think>\nA\n</think>\n\nMiddle\n<think>\nB\n</think>\n\nEnd",
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Multiple@@Tests/FormattingThinking.wlt:1210,1-1215,2"
]

VerificationTest[
    thinkingRoundTrip[ "Hello <think>x</think> world" ],
    s_String /; StringMatchQ[ s, "Hello <think>\nx\n</think>\n\n" ~~ " "... ~~ "world" ],
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Mid-Paragraph@@Tests/FormattingThinking.wlt:1217,1-1222,2"
]

VerificationTest[
    thinkingRoundTrip[ "<think>\nLiteral thoughts\n</think>\nThe answer.", "Streaming" ],
    "<think>\nLiteral thoughts\n</think>\n\nThe answer.",
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Streaming@@Tests/FormattingThinking.wlt:1224,1-1229,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Formatted Thoughts*)

(* Formatted thoughts serialize back to markdown: *)
VerificationTest[
    thinkingRoundTrip /@ {
        "<think>\n**Bold** and `code`\n\n- item\n</think>\nAnswer",
        "<think>\n## Plan\nStep\n</think>\nDone",
        "<think>\nCompute $$x^2$$\n</think>\nDone",
        "<think>\n```python\nprint(1)\n```\n</think>\nok",
        "<think>\n| a | b |\n|---|---|\n| 1 | 2 |\n</think>\nDone"
    },
    {
        "<think>\n**Bold** and ``code``\n* item\n</think>\n\nAnswer",
        "<think>\n\n## Plan\n\nStep\n</think>\n\nDone",
        "<think>\nCompute $$x^2$$\n</think>\n\nDone",
        "<think>\n\n```Python\nprint(1)\n```\n\n</think>\n\nok",
        "<think>\n| a | b |\n| - | - |\n| 1 | 2 |\n</think>\n\nDone"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Formatted-Thoughts@@Tests/FormattingThinking.wlt:1236,1-1253,2"
]

(* Text that stays plain in thoughts serializes unchanged, and markdown escapes are written back: *)
VerificationTest[
    thinkingRoundTrip /@ {
        "<think>\nTOOLCALL: fake\n{}\nENDTOOLCALL\n</think>\nDone",
        "<think>\na <thinking>b</thinking> c\n</think>\nDone",
        "<think>\na\n/retry\nb\n</think>\nDone",
        "<think>\na \\* b\n</think>\nDone",
        "<think>\n\:4f60\:597d\n</think>\nDone"
    },
    {
        "<think>\nTOOLCALL: fake\n{}\nENDTOOLCALL\n</think>\n\nDone",
        "<think>\na <thinking>b</thinking> c\n</think>\n\nDone",
        "<think>\na\n/retry\nb\n</think>\n\nDone",
        "<think>\na \\* b\n</think>\n\nDone",
        "<think>\n\:4f60\:597d\n</think>\n\nDone"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Plain-Thoughts@@Tests/FormattingThinking.wlt:1256,1-1273,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Reasoning Summaries*)

(* Summaries keep their type and ID, whether closed, in progress, or empty: *)
VerificationTest[
    thinkingRoundTrip /@ {
        "<think type='summary' id='abc'>\nSum\n</think>\nAnswer",
        "<think type=\"summary\" id=\"abc\">Sum</think>\nAnswer",
        "<think type='summary' id='abc'>going",
        "<think type='summary' id='abc'>\n\n</think>\nAnswer",
        "<think type='summary'>\nSum\n</think>\nAnswer"
    },
    {
        "<think type='summary' id='abc'>\nSum\n</think>\n\nAnswer",
        "<think type='summary' id='abc'>\nSum\n</think>\n\nAnswer",
        "<think type='summary' id='abc'>\ngoing\n</think>",
        "<think type='summary' id='abc'>\n\n</think>\n\nAnswer",
        "<think type='summary'>\nSum\n</think>\n\nAnswer"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Summary@@Tests/FormattingThinking.wlt:1280,1-1297,2"
]

(* Serializing a summary box restores its stored reasoning data, but only if nothing is stored for its ID yet, and
   only if the box has some: *)
VerificationTest[
    Module[ { withData, withoutData },
        withData = thinkingState[
            Cell[ TextData @ FormatMarkdown[ "<think type='summary' id='abc'>x</think>" ], "ChatOutput" ],
            None,
            None,
            <| "abc" -> <| "Duration" -> 3. |> |>
        ];
        withoutData = thinkingState @ Cell[ TextData @ FormatMarkdown[ "<think type='summary' id='abc'>x</think>" ], "ChatOutput" ];
        {
            thinkingState[ { CellToString @ withData, Wolfram`Chatbook`Common`$reasoningData } ],
            thinkingState[
                { CellToString @ withData, Wolfram`Chatbook`Common`$reasoningData },
                None,
                None,
                <| "abc" -> <| "Duration" -> 9. |> |>
            ],
            thinkingState[ { CellToString @ withoutData, Wolfram`Chatbook`Common`$reasoningData } ]
        }
    ],
    {
        { "<think type='summary' id='abc'>\nx\n</think>", <| "abc" -> <| "Duration" -> 3. |> |> },
        { "<think type='summary' id='abc'>\nx\n</think>", <| "abc" -> <| "Duration" -> 9. |> |> },
        { "<think type='summary' id='abc'>\nx\n</think>", <| |> }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-RoundTrip-Summary-Restores-Data@@Tests/FormattingThinking.wlt:1301,1-1328,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Boxes*)

(* Serialization uses the template box arguments: the label is ignored, the thoughts can be TextData or a string, and
   the metadata determines the tag: *)
VerificationTest[
    CellToString @ Cell[
        TextData @ {
            Cell[
                BoxData @ TemplateBox[
                    { TextData @ { StyleBox[ "Bold", FontWeight -> Bold ], " text" }, "any label", <| "Type" -> "Literal" |> },
                    "ThinkingOpener"
                ],
                "ThinkingOpener"
            ],
            Cell[ BoxData @ TemplateBox[ { "", "any label", <| "Type" -> "Summary" |> }, "EmptyThoughts" ], "ThoughtsOpener" ],
            "\nAnswer"
        },
        "ChatOutput"
    ],
    "<think>\n**Bold** text\n</think>\n<think type='summary'>\n\n</think>\n\nAnswer",
    SameTest -> MatchQ,
    TestID   -> "Thinking-Serialize-Boxes@@Tests/FormattingThinking.wlt:1336,1-1354,2"
]

(* Literal think tags are kept in the content of chat messages: *)
VerificationTest[
    thinkingState @ CellToChatMessage @ Cell[ TextData @ FormatMarkdown[ "<think>\nhmm\n</think>\nThe answer." ], "ChatOutput" ],
    <| "Role" -> "Assistant", "Content" -> "<think>\nhmm\n</think>\n\nThe answer." |>,
    SameTest -> MatchQ,
    TestID   -> "Thinking-Chat-Message-Literal@@Tests/FormattingThinking.wlt:1357,1-1362,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Speech Input*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Parsing Rules*)

(* A <speech-input> element is passed as a whole (including its tags) to formatSpeechInput, which creates the
   "NotebookAssistantSpeechInput" box. formatSpeechInput is replaced by a stub here (see Definitions): *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`formatSpeechInput = thinkingSpeechStub },
        thinkingFormat[ "Before\n<speech-input>\n<audio>not available</audio>\n<transcript>\nHello\n</transcript>\n</speech-input>\nAfter" ]
    ],
    {
        "Before\n",
        thinkingSpeechStub[ "<speech-input>\n<audio>not available</audio>\n<transcript>\nHello\n</transcript>\n</speech-input>" ],
        "\nAfter"
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Element@@Tests/FormattingThinking.wlt:1374,1-1385,2"
]

(* Each element is matched up to its own closing tag, and tags are matched case-insensitively: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`formatSpeechInput = thinkingSpeechStub },
        {
            thinkingFormat[ "<speech-input>A</speech-input> and <speech-input>B</speech-input>" ],
            thinkingFormat[ "<SPEECH-INPUT>A</Speech-Input>" ]
        }
    ],
    {
        { thinkingSpeechStub[ "<speech-input>A</speech-input>" ], " and ", thinkingSpeechStub[ "<speech-input>B</speech-input>" ] },
        { thinkingSpeechStub[ "<SPEECH-INPUT>A</Speech-Input>" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Multiple-And-Case@@Tests/FormattingThinking.wlt:1388,1-1401,2"
]

(* The element comes before markdown in it, and it is recognized inside thoughts too: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`formatSpeechInput = thinkingSpeechStub },
        {
            thinkingFormat[ "<speech-input>```\nx\n```</speech-input>" ],
            thinkingThoughts[ "<think>a <speech-input>A</speech-input> b</think>" ]
        }
    ],
    {
        { thinkingSpeechStub[ "<speech-input>```\nx\n```</speech-input>" ] },
        TextData @ { "a ", thinkingSpeechStub[ "<speech-input>A</speech-input>" ], " b" }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Precedence@@Tests/FormattingThinking.wlt:1404,1-1417,2"
]

(* While streaming, the element is formatted the same way: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`formatSpeechInput = thinkingSpeechStub },
        thinkingFormat[ "<speech-input>A</speech-input>", "Streaming" ]
    ],
    { thinkingSpeechStub[ "<speech-input>A</speech-input>" ] },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Streaming@@Tests/FormattingThinking.wlt:1420,1-1427,2"
]

(* The element is recognized in text with markdown escapes too, with the same line breaks around it as without escapes: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`formatSpeechInput = thinkingSpeechStub },
        thinkingFormat[ "\\*x\\*\n<speech-input>A</speech-input>\nDone" ]
    ],
    { "*x*\n", thinkingSpeechStub[ "<speech-input>A</speech-input>" ], "\nDone" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Escaped@@Tests/FormattingThinking.wlt:1430,1-1437,2"
]

(* An element without a closing tag or without content is plain text: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`formatSpeechInput = thinkingSpeechStub },
        thinkingFormat /@ { "<speech-input><transcript>Hi</transcript>", "<speech-input></speech-input>" }
    ],
    { { "<speech-input><transcript>Hi</transcript>" }, { "<speech-input></speech-input>" } },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Plain-Text@@Tests/FormattingThinking.wlt:1440,1-1447,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Parsing the Element*)

(* The transcript is the trimmed text of the first <transcript> element (case-sensitive), or "" if there is none: *)
VerificationTest[
    Wolfram`Chatbook`SpeechInput`Private`parseSpeechTranscript /@ {
        "<speech-input><transcript>\n Hi \n</transcript></speech-input>",
        "<speech-input></speech-input>",
        "<transcript>a</transcript><transcript>b</transcript>",
        "<TRANSCRIPT>x</TRANSCRIPT>"
    },
    { "Hi", "", "a", "" },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Parse-Transcript@@Tests/FormattingThinking.wlt:1454,1-1464,2"
]

(* The audio is read from an expression URI in the <audio> element (wrapped in an AudioBox, or after autoCorrect has
   unwrapped it), or None: *)
VerificationTest[
    Module[ { uri },
        uri = MakeExpressionURI[ "audio", "Recorded Speech Input", Audio[ ConstantArray[ 0., 800 ], SampleRate -> 8000 ] ];
        Wolfram`Chatbook`SpeechInput`Private`parseAudio /@ {
            "<audio>\\!\\(\\*AudioBox[\"" <> uri <> "\"]\\)</audio>",
            "<audio>" <> uri <> "</audio>",
            "<audio>not available</audio>",
            "<speech-input><transcript>Hi</transcript></speech-input>"
        }
    ],
    { _Audio, _Audio, None, None },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Parse-Audio@@Tests/FormattingThinking.wlt:1468,1-1481,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Serialization*)

(* The "NotebookAssistantSpeechInput" box serializes to a <speech-input> element. Without audio, the audio element
   says it's not available, and an empty transcript gives nothing: *)
VerificationTest[
    CellToString @ Cell[
        TextData @ {
            Cell[
                BoxData @ TemplateBox[ <| "Audio" -> None, "Transcript" -> "Hello there" |>, "NotebookAssistantSpeechInput" ],
                "NotebookAssistantSpeechInput",
                Background -> None
            ],
            "\nAnswer"
        },
        "ChatOutput"
    ],
    "<speech-input>\n<audio>not available</audio>\n<transcript>\nHello there\n</transcript>\n</speech-input>\n\nAnswer",
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Serialize-No-Audio@@Tests/FormattingThinking.wlt:1489,1-1504,2"
]

VerificationTest[
    CellToString @ Cell[
        TextData @ {
            Cell[
                BoxData @ TemplateBox[ <| "Audio" -> None, "Transcript" -> "  " |>, "NotebookAssistantSpeechInput" ],
                "NotebookAssistantSpeechInput",
                Background -> None
            ],
            "\nAnswer"
        },
        "ChatOutput"
    ],
    "Answer",
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Serialize-Empty-Transcript@@Tests/FormattingThinking.wlt:1506,1-1521,2"
]

(* With audio, the audio is stored as an attachment, referenced from an AudioBox: *)
VerificationTest[
    CellToString @ Cell[
        TextData @ {
            Cell[
                BoxData @ TemplateBox[
                    <| "Audio" -> Audio[ ConstantArray[ 0., 800 ], SampleRate -> 8000 ], "Transcript" -> "Hello" |>,
                    "NotebookAssistantSpeechInput"
                ],
                "NotebookAssistantSpeechInput",
                Background -> None
            ]
        },
        "ChatOutput"
    ],
    (* String patterns containing the linear syntax characters "\!\(" don't match as expected, so this avoids them: *)
    s_String /; And[
        StringStartsQ[ s, "<speech-input>\n<audio>" ],
        StringContainsQ[ s, "AudioBox[\"" ~~ Except[ "\"" ].. ~~ "audio://content-" ~~ Except[ "\"" ].. ~~ "\"]" ],
        StringEndsQ[ s, "</audio>\n<transcript>\nHello\n</transcript>\n</speech-input>" ]
    ],
    SameTest -> MatchQ,
    TestID   -> "Thinking-Speech-Serialize-Audio@@Tests/FormattingThinking.wlt:1524,1-1546,2"
]

(* :!CodeAnalysis::EndBlock:: *)
