(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Formatting.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Formatting.wlt:11,1-16,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TeX Escapes*)

(* Inside math the escape belongs to TeX rather than markdown, so the backslash has to reach the TeX parser
   intact for it to render a literal dollar sign: *)
VerificationTest[
    FirstCase[
        FormatChatOutput[ "Here is some TeX: $$\\$123.45 / \\$6.78$$" ],
        TemplateBox[ as_Association, "TeXAssistantTemplate" ] :> as,
        $Failed,
        Infinity
    ],
    KeyValuePattern @ {
        "input" -> "\\$123.45 / \\$6.78",
        "boxes" -> FormBox[ RowBox @ { "$123.45", "/", "$6.78" }, TraditionalForm ],
        "state" -> "Boxes"
    },
    SameTest -> MatchQ,
    TestID   -> "TeX-Escaped-Dollar@@Tests/Formatting.wlt:24,1-38,2"
]

(* The same holds for the other characters markdown escapes: *)
VerificationTest[
    FirstCase[
        FormatChatOutput[ "$$a \\_ b \\# c$$" ],
        TemplateBox[ as_Association, "TeXAssistantTemplate" ] :> as,
        $Failed,
        Infinity
    ],
    KeyValuePattern @ {
        "input" -> "a \\_ b \\# c",
        "boxes" -> FormBox[
            RowBox @ { StyleBox[ "a", "TI" ], "_", StyleBox[ "b", "TI" ], "#", StyleBox[ "c", "TI" ] },
            TraditionalForm
        ],
        "state" -> "Boxes"
    },
    SameTest -> MatchQ,
    TestID   -> "TeX-Escaped-Underscore-And-Hash@@Tests/Formatting.wlt:41,1-58,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Markdown Escapes*)

(* Outside of math the backslash only marks the escape, so it is dropped instead of being kept: *)
VerificationTest[
    FormatChatOutput[ "Cost: \\$5 and \\$6" ],
    RawBoxes @ Cell @ TextData @ { "Cost: $5 and $6" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-Dollar@@Tests/Formatting.wlt:65,1-70,2"
]

(* Escapes have to be restored before inline code is formatted. Otherwise the escape sentinel is still
   embedded in the string when the symbol name is looked up, so the code renders as ordinary inline code
   instead of resolving to a documentation link: *)
VerificationTest[
    FormatChatOutput[ "Try `\\$Failed` next" ],
    RawBoxes @ Cell @ TextData @ {
        "Try ",
        Cell @ BoxData @ TemplateBox[ { "$Failed", "paclet:ref/$Failed", _String }, "TextRefLink" ],
        " next"
    },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-Dollar-In-Inline-Code@@Tests/Formatting.wlt:75,1-84,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Documentation Links*)

(* Models sometimes wrap a documentation link in backticks. The link is what was meant, so it renders as a
   link rather than as code displaying the markdown verbatim: *)
VerificationTest[
    FormatChatOutput[ "See `[Table](paclet:ref/Table)` for details" ],
    RawBoxes @ Cell @ TextData @ {
        "See ",
        Cell @ BoxData @ TemplateBox[ { "Table", "paclet:ref/Table", _String }, "TextRefLink" ],
        " for details"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Ref-Link@@Tests/Formatting.wlt:92,1-101,2"
]

(* The same holds when the symbol name inside the link was escaped: *)
VerificationTest[
    FormatChatOutput[ "See `[\\$Failed](paclet:ref/\\$Failed)` for details" ],
    RawBoxes @ Cell @ TextData @ {
        "See ",
        Cell @ BoxData @ TemplateBox[ { "$Failed", "paclet:ref/$Failed", _String }, "TextRefLink" ],
        " for details"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Ref-Link-Escaped-Name@@Tests/Formatting.wlt:104,1-113,2"
]

(* Only a self-referential link is rewritten this way. A label that disagrees with the reference carries
   information that the link alone would lose, so it stays as code: *)
VerificationTest[
    FormatChatOutput[ "See `[Foo](paclet:ref/Bar)` for details" ],
    RawBoxes @ Cell @ TextData @ {
        "See ",
        Cell[
            BoxData @ TemplateBox[
                { Cell[ "[Foo](paclet:ref/Bar)", Background -> None ] },
                "ChatCodeInlineTemplate"
            ],
            "ChatCodeActive"
        ],
        " for details"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Ref-Link-Mismatched-Name@@Tests/Formatting.wlt:117,1-132,2"
]

(* Combination of link around the function head and escaped brackets around the arguments. *)
VerificationTest[
    Cases[
        FormatChatOutput[ "In Wolfram Language, use [Factorial2](paclet:ref/Factorial2)\\[42\\]." ],
        s_String /; StringContainsQ[ s, "[42]" ] :> s,
        Infinity
    ],
    { "[42]." },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-Brackets-After-Link@@Tests/Formatting.wlt:194,1-203,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ASCII art versus tool calls*)

VerificationTest[
    StringReplace[
        FirstCase[ FormatChatOutput[ "/\\\\_/\\\\\n( o.o )\n > ^ <" ], s_String :> s, $Failed, Infinity ],
        "\r\n" -> "\n"
    ],
    "/\\_/\\\n( o.o )\n > ^ <",
    SameTest -> MatchQ,
    TestID   -> "Markdown-ASCII-Art-Backslashes@@Tests/Formatting.wlt:134,1-142,2"
]

VerificationTest[
    ToCharacterCode /@ StringReplace[
        Cases[
            FormatChatOutput[ "```text\n /\\\\_/\\\\\\\\\n( o.o )\n > ^ <\n```" ],
            Cell[ code_, "ChatPreformatted", ___ ] :> code,
            Infinity
        ],
        "\r\n" -> "\n"
    ],
    ToCharacterCode /@ { " /\\_/\\\\\n( o.o )\n > ^ <" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-TextFence-Unescapes-ASCII-Art@@Tests/Formatting.wlt:144,1-156,2"
]

VerificationTest[
    StringReplace[
        Cases[
            FormatChatOutput[ "```python\nprint('\\\\')\n```" ],
            Cell[ code_, "ExternalLanguage", ___ ] :> code,
            Infinity
        ],
        "\r\n" -> "\n"
    ],
    { "print('\\\\')" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-CodeFence-Preserves-Code-Backslashes@@Tests/Formatting.wlt:158,1-170,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "/\\\\_/\\\\\n( o.o )\n > ^ <" ],
        Cell[ _, "InlineToolCall", ___ ],
        Infinity
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Markdown-ASCII-Art-Not-ToolCall@@Tests/Formatting.wlt:172,1-181,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "/external-tool.v1\n{}\nRESULT\nok\nENDRESULT(abc123)" ],
        Cell[ _, "InlineToolCall", ___ ],
        Infinity
    ],
    { _Cell },
    SameTest -> MatchQ,
    TestID   -> "Markdown-External-Slash-ToolCall@@Tests/Formatting.wlt:183,1-192,2"
]

VerificationTest[
    ToCharacterCode @ StringReplace[
        FirstCase[
            FormatChatOutput[ "<thinking>/\\\\_/\\\\\n( o.o )\n > ^ <</thinking>" ],
            TemplateBox[ { text_String, _ }, "ThoughtsOpener" ] :> text,
            $Failed,
            Infinity
        ],
        "\r\n" -> "\n"
    ],
    ToCharacterCode @ "/\\\\_/\\\\\n( o.o )\n > ^ <",
    SameTest -> MatchQ,
    TestID   -> "Thinking-Preserves-ASCII-Art@@Tests/Formatting.wlt:205,1-218,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[
            "Sure:\n\n```text\n /\\\\_/\\\\\\\\\n( o.o )\n > ^ <\n```\n\nAnother one:\n\n```text\n /\\\\_/\\\\  \n( -.- ) \n > ~ <\n```"
        ],
        TextData[ data_ ] :> Replace[
            data,
            { ___, s1_String, _Cell, s2_String, _Cell, ___ } /;
                StringEndsQ[ s1, "\n" ] && StringStartsQ[ s2, "\n" ] && StringEndsQ[ s2, "\n" ] :> True
        ],
        Infinity
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "Markdown-TextFence-Block-Separators@@Tests/Formatting.wlt:220,1-235,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Placeholders*)

(* Placeholder["description"] in WL code gets its StandardForm typesetting so it displays as a proper placeholder
   instead of plain code: *)
VerificationTest[
    FirstCase[
        StringToBoxes[ "data = Placeholder[\"your data\"];\ndoTheThing[data]", "WL" ],
        TagBox[ b_FrameBox, "Placeholder" ] :> b,
        $Failed,
        Infinity
    ],
    FrameBox[ "\"your data\"" ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Boxes@@Tests/Formatting.wlt:140,1-150,2"
]

(* Placeholder allows arbitrary label expressions, so these are formatted too by wrapping the already-parsed
   label boxes (avoiding a ToExpression round trip that could create symbols with unwanted contexts): *)
VerificationTest[
    FirstCase[
        StringToBoxes[ "DateListPlot[Placeholder[your data]]", "WL" ],
        TagBox[ b_FrameBox, "Placeholder" ] :> b,
        $Failed,
        Infinity
    ],
    FrameBox @ RowBox @ { "your", " ", "data" },
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Expression-Label@@Tests/Formatting.wlt:154,1-164,2"
]

(* String labels can contain escaped quotes: *)
VerificationTest[
    FirstCase[
        StringToBoxes[
            "data = Placeholder[\"{{\\\"Feb 12 2026\\\", 10}, {\\\"Mar 05 2026\\\", 14}, ...}\"];\nDateListPlot[data]",
            "WL"
        ],
        TagBox[ b_FrameBox, "Placeholder" ] :> b,
        $Failed,
        Infinity
    ],
    FrameBox[ "\"{{\\\"Feb 12 2026\\\", 10}, {\\\"Mar 05 2026\\\", 14}, ...}\"" ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Escaped-Quotes@@Tests/Formatting.wlt:167,1-180,2"
]

(* Placeholder takes at most one argument, so empty or multiple arguments are not valid labels and are left as-is: *)
VerificationTest[
    StringToBoxes[ "f[Placeholder[a, b], Placeholder[]]", "WL" ],
    boxes_ /; FreeQ[ boxes, TagBox[ _, "Placeholder", ___ ] ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Invalid-Arguments-Unchanged@@Tests/Formatting.wlt:183,1-188,2"
]

(* The full formatting path renders the placeholder in finished chat output: *)
VerificationTest[
    FirstCase[
        FormatChatOutput[ "```wl\ndata = Placeholder[\"your data\"];\ndoTheThing[data]\n```\n" ],
        TagBox[ b_FrameBox, "Placeholder" ] :> b,
        $Failed,
        Infinity
    ],
    FrameBox[ "\"your data\"" ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Formatted-Output@@Tests/Formatting.wlt:191,1-201,2"
]

(* While streaming, code is rendered from plain strings, so the placeholder appears as embedded linear syntax: *)
VerificationTest[
    Position[
        FormatChatOutput[
            "```wl\ndata = Placeholder[\"your data\"];\ndoTheThing[data]\n```\n",
            <| "Status" -> "Streaming" |>
        ],
        s_String /; StringContainsQ[ s, "TagBox" ] && StringContainsQ[ s, "Placeholder" ]
    ],
    { __ },
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Streaming@@Tests/Formatting.wlt:204,1-215,2"
]

(* A placeholder that has not finished streaming in yet is still rendered: *)
VerificationTest[
    Position[
        FormatChatOutput[ "```wl\ndata = Placeholder[\"your da", <| "Status" -> "Streaming" |> ],
        s_String /; StringContainsQ[ s, "TagBox" ] && StringContainsQ[ s, "Placeholder" ]
    ],
    { __ },
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Streaming-Partial@@Tests/Formatting.wlt:218,1-226,2"
]

(* Serializing the formatted boxes back to text for the LLM recovers the original code instead of losing the
   Placeholder head: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ RowBox @ { "data", "=", TagBox[ FrameBox[ "\"your data\"" ], "Placeholder" ], ";" },
        "Input"
    ],
    "```wl\ndata = Placeholder[\"your data\"];\n```",
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Serialization-RoundTrip@@Tests/Formatting.wlt:230,1-238,2"
]

(* Expression labels round-trip through serialization as well: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ RowBox @ { "DateListPlot", "[", TagBox[ FrameBox @ RowBox @ { "your", " ", "data" }, "Placeholder" ], "]" },
        "Input"
    ],
    "```wl\nDateListPlot[Placeholder[your data]]\n```",
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Serialization-RoundTrip-Expression-Label@@Tests/Formatting.wlt:241,1-249,2"
]
