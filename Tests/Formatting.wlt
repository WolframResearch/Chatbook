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

VerificationTest[
    FirstCase[
        FormatChatOutput[ "Before \\[x^2\\] after" ],
        TemplateBox[ as_Association, "TeXAssistantTemplate" ] :> as,
        $Failed,
        Infinity
    ],
    KeyValuePattern @ {
        "input" -> "x^2",
        "state" -> "Boxes"
    },
    SameTest -> MatchQ,
    TestID   -> "TeX-Whitespace-Delimited-Brackets@@Tests/Formatting.wlt:60,1-73,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Markdown Escapes*)

(* Outside of math the backslash only marks the escape, so it is dropped instead of being kept: *)
VerificationTest[
    FormatChatOutput[ "Cost: \\$5 and \\$6" ],
    RawBoxes @ Cell @ TextData @ { "Cost: $5 and $6" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-Dollar@@Tests/Formatting.wlt:80,1-85,2"
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
    TestID   -> "Markdown-Escaped-Dollar-In-Inline-Code@@Tests/Formatting.wlt:90,1-99,2"
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
    TestID   -> "Inline-Code-Ref-Link@@Tests/Formatting.wlt:107,1-116,2"
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
    TestID   -> "Inline-Code-Ref-Link-Escaped-Name@@Tests/Formatting.wlt:119,1-128,2"
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
    TestID   -> "Inline-Code-Ref-Link-Mismatched-Name@@Tests/Formatting.wlt:132,1-147,2"
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
    TestID   -> "Markdown-Escaped-Brackets-After-Link@@Tests/Formatting.wlt:150,1-159,2"
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
    TestID   -> "Markdown-ASCII-Art-Backslashes@@Tests/Formatting.wlt:165,1-173,2"
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
    TestID   -> "Markdown-TextFence-Unescapes-ASCII-Art@@Tests/Formatting.wlt:175,1-187,2"
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
    TestID   -> "Markdown-CodeFence-Preserves-Code-Backslashes@@Tests/Formatting.wlt:189,1-201,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "/\\\\_/\\\\\n( o.o )\n > ^ <" ],
        Cell[ _, "InlineToolCall", ___ ],
        Infinity
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Markdown-ASCII-Art-Not-ToolCall@@Tests/Formatting.wlt:203,1-212,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "/external-tool.v1\n{}\nRESULT\nok\nENDRESULT(abc123)" ],
        Cell[ _, "InlineToolCall", ___ ],
        Infinity
    ],
    { _Cell },
    SameTest -> MatchQ,
    TestID   -> "Markdown-External-Slash-ToolCall@@Tests/Formatting.wlt:214,1-223,2"
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
    TestID   -> "Thinking-Preserves-ASCII-Art@@Tests/Formatting.wlt:225,1-238,2"
]

VerificationTest[
    FirstCase[
        FormatChatOutput[ "<THINKING>fish &amp; chips /\\\\_/\\\\</THINKING>" ],
        TemplateBox[ { text_String, _ }, "ThoughtsOpener" ] :> text,
        $Failed,
        Infinity
    ],
    "fish & chips /\\\\_/\\\\",
    SameTest -> MatchQ,
    TestID   -> "Thinking-Escapes-Ignore-Case-And-Import-HTML@@Tests/Formatting.wlt:240,1-250,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[
            "Sure:\n\n```text\n /\\\\_/\\\\\\\\\n( o.o )\n > ^ <\n```\n\nAnother one:\n\n```text\n /\\\\_/\\\\  \n( -.- ) \n > ~ <\n```"
        ],
        TextData[ data_ ] :> Replace[
            data,
            { ___, "Sure: \n", _Cell, "\nAnother one: \n", _Cell, ___ } :> True
        ],
        Infinity
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "Markdown-TextFence-Block-Separators@@Tests/Formatting.wlt:252,1-266,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "Here is some code:\n\n```text\n1+1\n```" ],
        TextData[ { "Here is some code: \n", Cell[ _, "ChatCodeBlock", ___ ] } ] :> True,
        Infinity
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "Markdown-TextFence-Text-Before-Code@@Tests/Formatting.wlt:268,1-277,2"
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
    TestID   -> "Placeholder-Boxes@@Tests/Formatting.wlt:285,1-295,2"
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
    TestID   -> "Placeholder-Expression-Label@@Tests/Formatting.wlt:299,1-309,2"
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
    TestID   -> "Placeholder-Escaped-Quotes@@Tests/Formatting.wlt:312,1-325,2"
]

(* Placeholder takes at most one argument, so empty or multiple arguments are not valid labels and are left as-is: *)
VerificationTest[
    StringToBoxes[ "f[Placeholder[a, b], Placeholder[]]", "WL" ],
    boxes_ /; FreeQ[ boxes, TagBox[ _, "Placeholder", ___ ] ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Invalid-Arguments-Unchanged@@Tests/Formatting.wlt:328,1-333,2"
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
    TestID   -> "Placeholder-Formatted-Output@@Tests/Formatting.wlt:336,1-346,2"
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
    TestID   -> "Placeholder-Streaming@@Tests/Formatting.wlt:349,1-360,2"
]

(* A placeholder that has not finished streaming in yet is still rendered: *)
VerificationTest[
    Position[
        FormatChatOutput[ "```wl\ndata = Placeholder[\"your da", <| "Status" -> "Streaming" |> ],
        s_String /; StringContainsQ[ s, "TagBox" ] && StringContainsQ[ s, "Placeholder" ]
    ],
    { __ },
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Streaming-Partial@@Tests/Formatting.wlt:363,1-371,2"
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
    TestID   -> "Placeholder-Serialization-RoundTrip@@Tests/Formatting.wlt:375,1-383,2"
]

(* Expression labels round-trip through serialization as well: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ RowBox @ { "DateListPlot", "[", TagBox[ FrameBox @ RowBox @ { "your", " ", "data" }, "Placeholder" ], "]" },
        "Input"
    ],
    "```wl\nDateListPlot[Placeholder[your data]]\n```",
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Serialization-RoundTrip-Expression-Label@@Tests/Formatting.wlt:386,1-394,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Color Swatches*)

(* Color constructors with literal numeric arguments get their StandardForm typesetting, so they display as interactive
   color swatches instead of plain code: *)
VerificationTest[
    StringToBoxes[ "RGBColor[1, 0, 0]", "WL" ],
    TemplateBox[ KeyValuePattern[ "color" -> RGBColor[ 1, 0, 0 ] ], "RGBColorSwatchTemplate", ___ ],
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-RGBColor@@Tests/Formatting.wlt:402,1-407,2"
]

(* Every supported color model is converted: *)
VerificationTest[
    Cases[
        StringToBoxes[
            "{CMYKColor[0, 1, 1, 0], GrayLevel[0.5], Hue[0.3], LABColor[50, 20, 30], LCHColor[50, 20, 30], LUVColor[50, 20, 30], XYZColor[0.5, 0.5, 0.5]}",
            "WL"
        ],
        TemplateBox[ KeyValuePattern[ "color" -> color_ ], name_String, ___ ] :> { name, color },
        Infinity
    ],
    {
        { "CMYKColorSwatchTemplate"     , CMYKColor[ 0, 1, 1, 0 ]   },
        { "GrayLevelColorSwatchTemplate", GrayLevel[ 0.5 ]          },
        { "HueColorSwatchTemplate"      , Hue[ 0.3 ]                },
        { "LABColorSwatchTemplate"      , LABColor[ 50, 20, 30 ]    },
        { "LCHColorSwatchTemplate"      , LCHColor[ 50, 20, 30 ]    },
        { "LUVColorSwatchTemplate"      , LUVColor[ 50, 20, 30 ]    },
        { "XYZColorSwatchTemplate"      , XYZColor[ 0.5, 0.5, 0.5 ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-All-Color-Models@@Tests/Formatting.wlt:410,1-430,2"
]

(* LightDarkSwitched and ThemeColor typeset to their own template boxes rather than a "...ColorSwatchTemplate": *)
VerificationTest[
    Cases[
        StringToBoxes[ "{LightDarkSwitched[RGBColor[1, 0, 0], RGBColor[0, 1, 0]], LightDarkSwitched[RGBColor[1, 0, 0]]}", "WL" ],
        TemplateBox[ as_Association, name_String, ___ ] :> { name, as },
        Infinity
    ],
    {
        { "LightDarkSwitched" , KeyValuePattern @ { "light" -> RGBColor[ 1, 0, 0 ], "dark" -> RGBColor[ 0, 1, 0 ] } },
        { "LightDarkSwitched1", KeyValuePattern[ "light" -> RGBColor[ 1, 0, 0 ] ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-LightDarkSwitched@@Tests/Formatting.wlt:433,1-445,2"
]

VerificationTest[
    Cases[
        StringToBoxes[ "{ThemeColor[\"Background\"], ThemeColor[{0.3 -> \"Foreground\", 0.7 -> \"Background\"}]}", "WL" ],
        TemplateBox[ as_Association, name_String, ___ ] :> { name, as },
        Infinity
    ],
    {
        { "ThemeColor"       , KeyValuePattern[ "name" -> "Background" ] },
        { "ThemeColorBlended", KeyValuePattern @ { "frac1" -> 0.3, "name1" -> "Foreground", "frac2" -> 0.7, "name2" -> "Background" } }
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-ThemeColor@@Tests/Formatting.wlt:447,1-459,2"
]

(* Swatches are substituted in place inside larger expressions: *)
VerificationTest[
    StringToBoxes[ "Graphics[{RGBColor[1, 0, 0], Disk[]}]", "WL" ],
    RowBox @ {
        "Graphics",
        "[",
        RowBox @ {
            "{",
            RowBox @ {
                TemplateBox[ KeyValuePattern[ "color" -> RGBColor[ 1, 0, 0 ] ], "RGBColorSwatchTemplate", ___ ],
                ",",
                RowBox @ { "Disk", "[", "]" }
            },
            "}"
        },
        "]"
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Nested-In-Expression@@Tests/Formatting.wlt:462,1-480,2"
]

(* Arguments that are not literal numbers (symbols, patterns, unevaluated expressions) do not typeset as swatches in the
   front end either, so the code is left as-is: *)
VerificationTest[
    StringToBoxes[ "{RGBColor[Red, Green, Blue], Hue[N[1/3]], RGBColor[1, 0], Cases[expr, RGBColor[r_, g_, b_]]}", "WL" ],
    boxes_ /; FreeQ[ boxes, _TemplateBox ],
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Non-Numeric-Arguments-Unchanged@@Tests/Formatting.wlt:484,1-489,2"
]

(* When a color is not converted, special boxes inside its arguments are still formatted: *)
VerificationTest[
    StringToBoxes[ "RGBColor[Placeholder[\"red\"], 0, 0]", "WL" ],
    RowBox @ { "RGBColor", "[", RowBox @ { TagBox[ FrameBox[ "\"red\"" ], "Placeholder" ], ",", "0", ",", "0" }, "]" },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Inner-Special-Boxes-Still-Formatted@@Tests/Formatting.wlt:492,1-497,2"
]

(* The full formatting path renders swatches in finished chat output, both in code and in sandbox output rows: *)
VerificationTest[
    Cases[
        FormatChatOutput[ "```wl\nIn[1]:= RGBColor[1, 0, 0]\nOut[1]= RGBColor[1, 0, 0]\n```\n" ],
        Cell[ BoxData[ swatch_TemplateBox ], style: "ChatCode"|"Output", ___ ] :> { style, swatch },
        Infinity
    ],
    {
        { "ChatCode", TemplateBox[ KeyValuePattern[ "color" -> RGBColor[ 1, 0, 0 ] ], "RGBColorSwatchTemplate", ___ ] },
        { "Output"  , TemplateBox[ KeyValuePattern[ "color" -> RGBColor[ 1, 0, 0 ] ], "RGBColorSwatchTemplate", ___ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Formatted-Output@@Tests/Formatting.wlt:500,1-512,2"
]

(* Serializing the formatted boxes back to text for the LLM recovers the original code: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ StringToBoxes[ "{RGBColor[1, 0, 0], Hue[0.3], GrayLevel[0.5]}", "WL" ],
        "Output"
    ],
    "```wl\n{RGBColor[1, 0, 0], Hue[0.3], GrayLevel[0.5]}\n```",
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Serialization-RoundTrip@@Tests/Formatting.wlt:515,1-523,2"
]

(* LightDarkSwitched and ThemeColor, including their one-argument and blended variants, round-trip as well: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ StringToBoxes[
            "{LightDarkSwitched[RGBColor[1, 0, 0], RGBColor[0, 1, 0]], LightDarkSwitched[RGBColor[1, 0, 0]], ThemeColor[\"Background\"], ThemeColor[{0.3 -> \"Foreground\", 0.7 -> \"Background\"}]}",
            "WL"
        ],
        "Output"
    ],
    "```wl\n{LightDarkSwitched[RGBColor[1, 0, 0], RGBColor[0, 1, 0]], LightDarkSwitched[RGBColor[1, 0, 0]], ThemeColor[\"Background\"], ThemeColor[{0.3 -> \"Foreground\", 0.7 -> \"Background\"}]}\n```",
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Serialization-RoundTrip-LightDarkSwitched-ThemeColor@@Tests/Formatting.wlt:526,1-537,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Those template boxes have precomputed serialization rules, so they do not need the front end stylesheet lookup that
   undeclared template boxes fall back to: *)
VerificationTest[
    Wolfram`Chatbook`Serialization`Private`$templateBoxRules[ #1 ][ #2 ] & @@@ {
        { "LightDarkSwitched" , <| "light" -> RGBColor[ 1, 0, 0 ], "dark" -> RGBColor[ 0, 1, 0 ] |> },
        { "LightDarkSwitched1", <| "light" -> RGBColor[ 1, 0, 0 ] |> },
        { "ThemeColor"        , <| "name" -> "Background" |> },
        { "ThemeColorBlended" , <| "frac1" -> 0.3, "name1" -> "Foreground", "frac2" -> 0.7, "name2" -> "Background" |> }
    },
    {
        "LightDarkSwitched[RGBColor[1, 0, 0], RGBColor[0, 1, 0]]",
        "LightDarkSwitched[RGBColor[1, 0, 0]]",
        "ThemeColor[\"Background\"]",
        "ThemeColor[{0.3 -> \"Foreground\", 0.7 -> \"Background\"}]"
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Serialization-Precomputed-Rules@@Tests/Formatting.wlt:544,1-559,2"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Dynamic Attachments*)

(* Each insertion of dynamic content needs fresh boxes. Reusing cached Manipulate boxes aliases their generated
   DynamicModule identities, so a second reference to the same expression does not work independently: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Formatting`Private`$boxCache = <| |> },
        With[ { uri = MakeExpressionURI @ Manipulate[ x, { x, 0, 1 } ] },
            FormatChatOutput @ StringRiffle[ { uri, uri }, "\n\n" ]
        ];
        Wolfram`Chatbook`Formatting`Private`$boxCache
    ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "Manipulate-Boxes-Are-Not-Cached@@Tests/Formatting.wlt:569,1-579,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Textual Tool Calls*)

VerificationTest[
    Wolfram`Chatbook`Formatting`Private`discardBadToolCalls @ StringSplit[
        StringRiffle[
            {
                "TOOLCALL: wolfram_language_evaluator\n{}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\n$Failed\nENDRESULT(first)",
                "/retry",
                "TOOLCALL: wolfram_language_evaluator\n{}\nENDARGUMENTS\nENDTOOLCALL",
                "Here is the plot:\n\n![Weather plot](attachment://content)\n\n- highs and lows"
            },
            "\n\n"
        ],
        Wolfram`Chatbook`Formatting`Private`$textDataFormatRules
    ],
    {
        Wolfram`Chatbook`Formatting`Private`discardedMaterial[
            Wolfram`Chatbook`Formatting`Private`inlineToolCallCell[ _String ],
            ""
        ],
        "\n",
        Wolfram`Chatbook`Formatting`Private`retriedToolCallCell[
            "TOOLCALL: wolfram_language_evaluator\n{}\nENDARGUMENTS\nENDTOOLCALL\n\n" <>
            "Here is the plot:\n\n![Weather plot](attachment://content)\n\n- highs and lows"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Textual-Tool-Call-Trailing-Text@@Tests/Formatting.wlt:273,1-302,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Formatting`Private`$dynamicText = False },
        Wolfram`Chatbook`Formatting`Private`retriedToolCall[
            "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\n\nFabricated result"
        ]
    ],
    Cell[ BoxData[ _ ], "Text", ___ ],
    SameTest -> MatchQ,
    TestID   -> "Textual-Tool-Call-Incomplete-Retry-Fails"
]

VerificationTest[
    FreeQ[
        Block[ { Wolfram`Chatbook`Formatting`Private`$dynamicText = False },
            Wolfram`Chatbook`Formatting`Private`retriedToolCall[
                "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\n\nFabricated result"
            ]
        ],
        _Failure
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Textual-Tool-Call-Incomplete-Retry-Does-Not-Render-Failure"
]

VerificationTest[
    Wolfram`Chatbook`Formatting`Private`formatChatOutput[
        StringRiffle[
            {
                "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nfailed\nENDRESULT(first)",
                "/retry",
                "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\n\nFabricated result"
            },
            "\n\n"
        ],
        "Finished"
    ],
    RawBoxes @ Cell @ TextData @ {
        Cell[ _, "DiscardedMaterial", ___ ],
        _String,
        Cell[ BoxData[ _ ], "Text", ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Textual-Tool-Call-Incomplete-Retry-Finished-Output"
]

VerificationTest[
    Wolfram`Chatbook`Formatting`Private`formatChatOutput[
        StringRiffle[
            {
                "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nfailed\nENDRESULT(first)",
                "/retry",
                "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL"
            },
            "\n\n"
        ],
        "Streaming"
    ],
    RawBoxes @ Cell @ TextData @ {
        Cell[ _, "DiscardedMaterial", ___ ],
        _String,
        Cell[ _, "InlineToolCall", ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Textual-Tool-Call-Incomplete-Retry-Streams"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Formatting`Private`$dynamicText = False },
        Wolfram`Chatbook`Formatting`Private`retriedToolCall[
            "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\ntool output\nENDRESULT(abc123)"
        ]
    ],
    Cell[ _, "InlineToolCall", ___ ],
    SameTest -> MatchQ,
    TestID   -> "Textual-Tool-Call-Completed-Retry-Succeeds"
]

VerificationTest[
    Wolfram`Chatbook`Formatting`Private`discardBadToolCalls @ StringSplit[
        StringRiffle[
            {
                "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nfirst failure\nENDRESULT(first)",
                "/retry",
                "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nsecond failure\nENDRESULT(second)",
                "/retry",
                "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\n\nFabricated result"
            },
            "\n\n"
        ],
        Wolfram`Chatbook`Formatting`Private`$textDataFormatRules
    ],
    {
        Wolfram`Chatbook`Formatting`Private`discardedMaterial[ ___ ],
        "\n",
        Wolfram`Chatbook`Formatting`Private`discardedMaterial[ ___ ],
        "\n",
        Wolfram`Chatbook`Formatting`Private`retriedToolCallCell[
            "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\n\nFabricated result"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Textual-Tool-Call-Multiple-Retries"
]

VerificationTest[
    StringSplit[
        "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\ntool output\nENDRESULT(abc123)\n\nTrailing text",
        Wolfram`Chatbook`Formatting`Private`$textDataFormatRules
    ],
    {
        Wolfram`Chatbook`Formatting`Private`inlineToolCallCell[
            "TOOLCALL: test\n{}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\ntool output\nENDRESULT(abc123)"
        ],
        "\n\nTrailing text"
    },
    SameTest -> MatchQ,
    TestID   -> "Textual-Tool-Call-Completed-Result@@Tests/Formatting.wlt:304,1-317,2"
]

VerificationTest[
    StringSplit[
        "Leading text\n\nTOOLCALL: test\n{\n\t\"code\": \"1 + 1",
        Wolfram`Chatbook`Formatting`Private`$textDataFormatRules
    ],
    {
        "Leading text\n\n",
        Wolfram`Chatbook`Formatting`Private`inlineToolCallCell[
            "TOOLCALL: test\n{\n\t\"code\": \"1 + 1"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Textual-Tool-Call-Partial-Streaming@@Tests/Formatting.wlt:319,1-332,2"
]
