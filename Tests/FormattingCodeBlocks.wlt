(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Patterns and helpers used by the tests below. The patterns leave out details that do not change appearance or
   serialization, such as option order and the dynamic TranslationOptions setting. *)
VerificationTest[
    (* A code block: the template draws the frame and the buttons around the inner cell. The language argument picks
       the buttons (e.g. the evaluate button's language icon); it isn't shown as text: *)
    cbBlock[ inner_, lang_ ] :=
        Cell[ BoxData @ TemplateBox[ { inner, lang }, "ChatCodeBlockTemplate" ], "ChatCodeBlock" ];

    (* The same in the notebook assistant sidebar: *)
    cbSidebarBlock[ inner_, lang_ ] :=
        Cell[ BoxData @ TemplateBox[ { inner, lang }, "NotebookAssistant`Sidebar`ChatCodeBlockTemplate" ], "ChatCodeBlock" ];

    (* The inner cell of a finished Wolfram Language code block: *)
    cbWL[ boxes_ ] := Cell[
        BoxData @ boxes,
        "ChatCode",
        "Input",
        OrderlessPatternSequence[
            LanguageCategory     -> "Input",
            ShowAutoStyles       -> True,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True,
            ___
        ]
    ];

    (* The inner cell of a finished code block in a supported external language: *)
    cbExternal[ code_, lang_ ] := Cell @ BoxData @ Cell[
        code,
        "ExternalLanguage",
        OrderlessPatternSequence[
            CellEvaluationLanguage -> lang,
            FontSize               -> 13,
            Background             -> None,
            CellFrame              -> None,
            ___
        ]
    ];

    (* The inner cell of a finished code block in any other language (the tagging rules are read by CellToString): *)
    cbPreformatted[ code_, lang_ ] := Cell[
        code,
        "ChatPreformatted",
        TaggingRules -> KeyValuePattern @ { "CellToStringType" -> "InlineCodeCell", "CodeLanguage" -> lang }
    ];

    (* All code block cells in formatted output: *)
    cbCodeBlocks[ md_String ] := cbCodeBlocks[ md, "Finished" ];
    cbCodeBlocks[ md_String, status_String ] :=
        Cases[ FormatMarkdown[ md, status ], Cell[ _, "ChatCodeBlock", ___ ], Infinity ];

    (* The template's language argument and the inner cell style of the first code block: *)
    cbSummary[ md_String ] := cbSummary[ md, "Finished" ];
    cbSummary[ md_String, status_String ] := FirstCase[
        FormatMarkdown[ md, status ],
        Cell[ BoxData @ TemplateBox[ { inner_, lang_ }, _String ], "ChatCodeBlock", ___ ] :> { lang, cbInnerStyle @ inner },
        Missing[ "NoCodeBlock" ],
        Infinity
    ];

    cbInnerStyle[ Cell[ BoxData[ Cell[ _, style_String, ___ ] ] ] ] := style;
    cbInnerStyle[ Cell[ _, style_String, ___ ] ] := style;

    (* The code string shown in the first non-Wolfram Language code block: *)
    cbCode[ md_String ] := cbCode[ md, "Finished" ];
    cbCode[ md_String, status_String ] := FirstCase[
        FormatMarkdown[ md, status ],
        Cell[ code_String, "ExternalLanguage"|"ChatPreformatted", ___ ] :> code,
        Missing[ "NoCode" ],
        Infinity
    ];

    (* The boxes shown in the first finished Wolfram Language code block: *)
    cbBoxes[ md_String ] := FirstCase[
        FormatMarkdown[ md ],
        Cell[ BoxData[ boxes_ ], "ChatCode", ___ ] :> boxes,
        Missing[ "NoCode" ],
        Infinity
    ];

    (* Whether the code of the first streaming Wolfram Language block contains all of the given strings. The special
       boxes are currently embedded in the code string as linear syntax; this accepts any box form: *)
    cbStreamingShowsQ[ md_String, parts: { __String } ] :=
        With[
            {
                code = ToString[
                    FirstCase[ FormatMarkdown[ md, "Streaming" ], Cell[ BoxData[ b_ ], "ChatCodeActive" ] :> b, None, Infinity ],
                    InputForm
                ]
            },
            AllTrue[ parts, StringContainsQ[ code, # ] & ]
        ];

    (* A transcript of labeled In/Out rows: *)
    cbTranscript[ rows_ ] := {
        Cell[
            BoxData @ GridBox[
                rows,
                OrderlessPatternSequence[
                    GridBoxAlignment -> { "Columns" -> { Right, Left }, "Rows" -> { { Baseline } } },
                    ___
                ]
            ],
            "CellGroupBlock"
        ]
    };

    cbLabel[ label_String ] := StyleBox[ label, "CellLabelExpired" ];

    (* Joins a serialized string's invisible trailing spaces before line breaks: *)
    cbNormalizeString[ s_String ] := StringReplace[ s, " ".. ~~ "\n" -> "\n" ];

    (* Makes sure nothing in a test can reach the network: *)
    cbOffline // Attributes = { HoldAll };
    cbOffline[ eval_ ] := Block[ { $AllowInternet = False }, eval ];

    (* A small local image file for code blocks that only contain an image: *)
    $cbImageFile = FileNameJoin @ { $TemporaryDirectory, "chatbook-codeblocks-test.png" };
    Export[ $cbImageFile, Image @ { { 0, 1 }, { 1, 0 } } ];
    $cbImageMarkdown = "![alt](file://" <> $cbImageFile <> ")";
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Fenced Code Block Rule*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Wolfram Language Blocks*)

(* A finished Wolfram Language block is parsed into boxes (with spaces around infix operators removed) and shown in a
   "ChatCode"/"Input" cell. The language argument is always "Wolfram", whatever tag the model used: *)
VerificationTest[
    FormatMarkdown[ "```wl\n1+1\n```" ],
    { cbBlock[ cbWL @ RowBox @ { "1", "+", "1" }, "Wolfram" ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-WL-Finished"
]

(* While streaming, the code is shown as a plain string in a "ChatCodeActive" cell (no front end parsing). The streaming
   display swaps in the "...Active" template, which doesn't show the language argument (it's currently the tag as
   written), so streaming tests don't assert it: *)
VerificationTest[
    FormatMarkdown[ "```wl\n1+1\n```", "Streaming" ],
    { cbBlock[ Cell[ BoxData[ "1+1" ], "ChatCodeActive" ], _ ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-WL-Streaming"
]

(* All of these tags mean Wolfram Language. They're matched case-insensitively, as a whole, after trimming trailing
   spaces: *)
VerificationTest[
    cbSummary[ "```" <> # <> "\nx = 1\n```" ] & /@ {
        "wl",
        "WL",
        "wolfram",
        "Wolfram",
        "Wolfram Language",
        "wolfram language",
        "Wolfram_Language",
        "WolframLanguage",
        "wolframlanguage",
        "Wolfram_Language_Evaluator",
        "mathematica",
        "Mathematica",
        "wl   "
    },
    ConstantArray[ { "Wolfram", "ChatCode" }, 13 ],
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-WL-Language-Tags"
]

(* The same tags are recognized while streaming: *)
VerificationTest[
    Last @ cbSummary[ "```" <> # <> "\nx = 1\n```", "Streaming" ] & /@ { "wl", "wolfram", "Mathematica", "Wolfram Language", "wl   " },
    ConstantArray[ "ChatCodeActive", 5 ],
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-WL-Language-Tags-Streaming"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other Languages*)

(* A block without a language tag is preformatted text with an empty language: *)
VerificationTest[
    FormatMarkdown[ "```\nbar baz\n```" ],
    { cbBlock[ cbPreformatted[ "bar baz", "" ], "" ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-No-Language"
]

(* An unknown language keeps its tag, as the template's language and in the tagging rules that serialization reads: *)
VerificationTest[
    FormatMarkdown[ "```foo\nbar baz\n```" ],
    { cbBlock[ cbPreformatted[ "bar baz", "foo" ], "foo" ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Unknown-Language"
]

(* While streaming, every non-Wolfram Language block (including external languages) is a plain "ChatPreformatted"
   cell. (It currently has no tagging rules, so it serializes without a fence; that isn't asserted.) *)
VerificationTest[
    {
        FormatMarkdown[ "```\nbar baz\n```", "Streaming" ],
        FormatMarkdown[ "```foo\nbar baz\n```", "Streaming" ],
        FormatMarkdown[ "```python\nprint(1)\n```", "Streaming" ]
    },
    {
        { cbBlock[ Cell[ "bar baz", "ChatPreformatted", ___ ], _ ] },
        { cbBlock[ Cell[ "bar baz", "ChatPreformatted", ___ ], _ ] },
        { cbBlock[ Cell[ "print(1)", "ChatPreformatted", ___ ], _ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Other-Languages-Streaming"
]

(* Spaces before or after the language tag are ignored: *)
VerificationTest[
    FormatMarkdown /@ { "```python   \nprint(1)\n```", "``` python\nprint(1)\n```" },
    ConstantArray[ { cbBlock[ cbExternal[ "print(1)", "Python" ], "Python" ] }, 2 ],
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Info-String-Spaces"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fence Placement*)

(* Text before and after a block is separated from it by a single line break: *)
VerificationTest[
    NormalizeTextData @ FormatMarkdown[ # ] & /@ {
        "Text\n```wl\n1+1\n```\nMore",
        "Before\n\n```python\nx\n```\n\nAfter"
    },
    {
        { "Text\n", cbBlock[ cbWL @ RowBox @ { "1", "+", "1" }, "Wolfram" ], "\nMore" },
        { "Before\n", cbBlock[ cbExternal[ "x", "Python" ], "Python" ], "\nAfter" }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Surrounding-Text"
]

(* Streaming gives the same separators: *)
VerificationTest[
    NormalizeTextData @ FormatMarkdown[ "Before\n\n```python\nx\n```\n\nAfter", "Streaming" ],
    { "Before\n", cbBlock[ Cell[ "x", "ChatPreformatted", ___ ], _ ], "\nAfter" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Surrounding-Text-Streaming"
]

(* Additional blank lines around a block are kept, minus one on each side: *)
VerificationTest[
    NormalizeTextData @ FormatMarkdown[ "Before\n\n\n\n```python\nx\n```\n\n\n\nAfter" ],
    { "Before\n\n\n", cbBlock[ cbExternal[ "x", "Python" ], "Python" ], "\n\n\nAfter" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Extra-Blank-Lines"
]

(* Fences don't have to start or end a line: *)
VerificationTest[
    {
        FormatMarkdown[ "Text ```wl\n1+1\n``` more" ],
        FormatMarkdown[ "```python\nx = 1\n```Next text" ]
    },
    {
        { "Text ", cbBlock[ cbWL @ RowBox @ { "1", "+", "1" }, "Wolfram" ], " more" },
        { cbBlock[ cbExternal[ "x = 1", "Python" ], "Python" ], "Next text" }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Mid-Line-Fences"
]

(* Consecutive blocks: *)
VerificationTest[
    FormatMarkdown[ "```python\nx = 1\n```\n```wl\ny\n```" ],
    { cbBlock[ cbExternal[ "x = 1", "Python" ], "Python" ], "\n", cbBlock[ cbWL[ "y" ], "Wolfram" ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Consecutive-Blocks"
]

(* Triple backticks without a line break after the opening fence are inline code, not a code block: *)
VerificationTest[
    { FormatMarkdown[ "```1+1```" ], FormatMarkdown[ "```1+1```", "Streaming" ] },
    ConstantArray[
        {
            Cell[
                BoxData @ TemplateBox[ { Cell[ "1+1", ___ ] }, "ChatCodeInlineTemplate" ],
                "ChatCodeActive"
            ]
        },
        2
    ],
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Fence-Without-Line-Break"
]

(* A fence of six backticks works like three: the extra backticks are removed from the language tag, and the rest of
   the closing fence is not shown. (Four or five backticks don't work, see the quirks.) *)
VerificationTest[
    {
        FormatMarkdown[ "``````python\nx\n``````" ],
        FormatMarkdown[ "``````\nx\n``````" ],
        MarkdownRoundTrip[ "``````python\nx\n``````" ]
    },
    {
        { cbBlock[ cbExternal[ "x", "Python" ], "Python" ] },
        { cbBlock[ cbPreformatted[ "x", "" ], "" ] },
        "```Python\nx\n```"
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Six-Backtick-Fence"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unterminated Fences*)

(* A fence that is never closed runs to the end of the text. A finished response gives the same block as a closed
   fence: *)
VerificationTest[
    { FormatMarkdown[ "```wl\n1+1" ], FormatMarkdown[ "```python\nprint(1)" ] },
    {
        { cbBlock[ cbWL @ RowBox @ { "1", "+", "1" }, "Wolfram" ] },
        { cbBlock[ cbExternal[ "print(1)", "Python" ], "Python" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Unterminated-Finished"
]

(* While streaming, the partial block is shown as it arrives: *)
VerificationTest[
    NormalizeTextData @ FormatMarkdown[ #, "Streaming" ] & /@ { "Here:\n\n```wl\n1+1", "Here:\n\n```python\nprint(1)" },
    {
        { "Here:\n", cbBlock[ Cell[ BoxData[ "1+1" ], "ChatCodeActive" ], _ ] },
        { "Here:\n", cbBlock[ Cell[ "print(1)", "ChatPreformatted", ___ ], _ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Unterminated-Streaming"
]

(* An opening fence on its own is not shown: *)
VerificationTest[
    { FormatMarkdown[ "```" ], FormatMarkdown[ "Here:\n\n```", "Streaming" ] },
    { { }, { "Here:" } },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Opening-Fence-Only"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Code Content*)

(* Backticks inside a block are code, not inline code markup: *)
VerificationTest[
    { cbCode[ "```python\nx = `a` + ``b``\n```" ], cbCode[ "```python\nx = `a` + ``b``\n```", "Streaming" ] },
    { "x = `a` + ``b``", "x = `a` + ``b``" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Nested-Backticks"
]

(* Markdown inside a block is not formatted: *)
VerificationTest[
    FormatMarkdown[ "```markdown\n# Heading\n* item\n**bold**\n```" ],
    { cbBlock[ cbPreformatted[ "# Heading\n* item\n**bold**", "markdown" ], "markdown" ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Markdown-Not-Formatted"
]

(* The exception is an untagged block that contains nothing but a markdown table, which is shown as a table (models
   often fence tables). Tagged blocks currently do the same, which isn't asserted: *)
VerificationTest[
    FormatMarkdown[ "```\n| a | b |\n|---|---|\n| 1 | 2 |\n```" ],
    { Cell[ t_ /; ! FreeQ[ t, "\"a\"" ] && ! FreeQ[ t, "\"2\"" ], "TextTableForm", ___ ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Table-Only-Block"
]

(* Code that contains "TOOLCALL:" is not matched by the code block rule (tool call results can contain code blocks, so
   the tool call rules have to see it). The tool call is formatted instead: *)
VerificationTest[
    Module[ { items = FormatMarkdown[ "```\nTOOLCALL: foo\n```" ] },
        { Cases[ items, Cell[ _, "ChatCodeBlock", ___ ], Infinity ], Cases[ items, Cell[ _, "InlineToolCall", ___ ], Infinity ] }
    ],
    { { }, { _Cell } },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-ToolCall-Not-A-Code-Block"
]

(* Unicode is kept as is: *)
VerificationTest[
    {
        cbCode[ "```python\nprint('h\[EAcute]llo \[Checkmark]')\n```" ],
        cbBoxes[ "```wl\n\"\[Alpha]\[Beta]\" <> \"x\"\n```" ]
    },
    {
        "print('h\[EAcute]llo \[Checkmark]')",
        RowBox @ { "\"\[Alpha]\[Beta]\"", " ", "<>", " ", "\"x\"" }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Unicode"
]

(* "\r\n" line endings become "\n", including the ones inside the code (the front end would draw "\r\n" as a single
   line): *)
VerificationTest[
    FormatMarkdown[ "```python\r\nprint(1)\r\nprint(2)\r\n```" ],
    { cbBlock[ cbExternal[ "print(1)\nprint(2)", "Python" ], "Python" ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-CRLF-Line-Endings"
]

(* An empty block in an external language is an empty code cell: *)
VerificationTest[
    FormatMarkdown[ "```python\n\n```" ],
    { cbBlock[ cbExternal[ "", "Python" ], "Python" ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Empty-External-Block"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Neighboring Constructs*)

(* Headings directly before or after a block: *)
VerificationTest[
    {
        FormatMarkdown[ "```python\nx = 1\n```\n## Heading" ],
        FormatMarkdown[ "## Heading\n```python\nx = 1\n```" ]
    },
    {
        { cbBlock[ cbExternal[ "x = 1", "Python" ], "Python" ], "\n", Cell[ _, "InlineSection", ___ ] },
        { Cell[ _, "InlineSection", ___ ], "\n", cbBlock[ cbExternal[ "x = 1", "Python" ], "Python" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Next-To-Headings"
]

(* Blocks between bullet items, with and without indentation. Indented code is unindented (see stripCodePadding below),
   and the indentation before the opening fence stays in the text: *)
VerificationTest[
    {
        NormalizeTextData @ FormatMarkdown[ "* item\n```python\nx\n```\n* next" ],
        NormalizeTextData @ FormatMarkdown[ "* item\n  ```python\n  x = 1\n  ```\n* next" ]
    },
    {
        {
            Cell[ _, "InlineItem", ___ ],
            "\n",
            cbBlock[ cbExternal[ "x", "Python" ], "Python" ],
            "\n",
            Cell[ _, "InlineItem", ___ ]
        },
        {
            Cell[ _, "InlineItem", ___ ],
            "\n  ",
            cbBlock[ cbExternal[ "x = 1", "Python" ], "Python" ],
            "\n",
            Cell[ _, "InlineItem", ___ ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Between-Bullets"
]

(* A block indented under a numbered list item (numbered lists are plain text): *)
VerificationTest[
    NormalizeTextData @ FormatMarkdown[ "1. Step\n   ```python\n   x = 1\n   y = 2\n   ```\n2. Next" ],
    { "1. Step\n   ", cbBlock[ cbExternal[ "x = 1\ny = 2", "Python" ], "Python" ], "\n2. Next" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Numbered-List-Item"
]

(* Code blocks in text with escaped markdown characters keep their raw text, so they look the same as without
   escapes: *)
VerificationTest[
    {
        NormalizeTextData @ FormatMarkdown[ "Some \\*escaped\\* text\n\n```python\nx = 1\n```" ],
        NormalizeTextData @ FormatMarkdown[ "Some \\*escaped\\* text\n\n```wl\nx = 1\n```" ]
    },
    {
        { "Some *escaped* text\n", cbBlock[ cbExternal[ "x = 1", "Python" ], "Python" ] },
        { "Some *escaped* text\n", cbBlock[ cbWL @ RowBox @ { "x", "=", "1" }, "Wolfram" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Escaped-Markdown-Path"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Language Normalization*)

(* Aliases for external languages that can be evaluated in a notebook. The tag is matched case-insensitively and gives
   an "ExternalLanguage" cell with CellEvaluationLanguage set, and the normalized name as the template's language: *)
VerificationTest[
    FirstCase[
        FormatMarkdown[ "```" <> # <> "\nx = 1\n```" ],
        Cell[ BoxData @ TemplateBox[ { Cell @ BoxData @ Cell[ _, "ExternalLanguage", ___, CellEvaluationLanguage -> lang_, ___ ], label_ }, _ ], ___ ] :>
            { lang, label },
        Missing[ "NotExternal" ],
        Infinity
    ] & /@ {
        "js", "JS", "javascript", "JavaScript", "npm", "node", "Node", "nodejs",
        "bash", "BASH", "sh", "shell",
        "python", "r", "R", "sql", "SQL", "sqlite", "sql-jdbc", "java", "julia", "jupyter", "octave", "ruby"
    },
    {
        { "NodeJS", "NodeJS" }, { "NodeJS", "NodeJS" }, { "NodeJS", "NodeJS" }, { "NodeJS", "NodeJS" },
        { "NodeJS", "NodeJS" }, { "NodeJS", "NodeJS" }, { "NodeJS", "NodeJS" }, { "NodeJS", "NodeJS" },
        { "Shell", "Shell" }, { "Shell", "Shell" }, { "Shell", "Shell" }, { "Shell", "Shell" },
        { "Python", "Python" }, { "R", "R" }, { "R", "R" }, { "SQL", "SQL" }, { "SQL", "SQL" }, { "SQLite", "SQLite" },
        { "SQL-JDBC", "SQL-JDBC" }, { "Java", "Java" }, { "Julia", "Julia" }, { "Jupyter", "Jupyter" },
        { "Octave", "Octave" }, { "Ruby", "Ruby" }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-External-Language-Aliases"
]

(* Aliases only match the whole tag, so similar names are other languages: *)
VerificationTest[
    cbSummary[ "```" <> # <> "\nx = 1\n```" ] & /@ { "jsx", "zsh", "Python3", "c++", "txt" },
    {
        { "jsx"    , "ChatPreformatted" },
        { "zsh"    , "ChatPreformatted" },
        { "Python3", "ChatPreformatted" },
        { "c++"    , "ChatPreformatted" },
        { "txt"    , "ChatPreformatted" }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Aliases-Match-Whole-Tag"
]

(* Blank lines at the start and whitespace at the end of the code are removed (the shared indentation is removed too,
   see stripCodePadding below): *)
VerificationTest[
    { cbCode[ "```python\n\n\n  x = 1\n  y = 2\n\n\n```" ], cbCode[ "```python\n\n\n  x = 1\n  y = 2\n\n\n```", "Streaming" ] },
    { "x = 1\ny = 2", "x = 1\ny = 2" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Code-Whitespace-Trimmed"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*makeCodeBlockCell*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Images*)

(* A block that contains nothing but a markdown image is shown as the image, the same as an image outside a code
   block, whatever its language: *)
VerificationTest[
    Module[ { image = FormatMarkdown @ $cbImageMarkdown },
        {
            MatchQ[ image, { Cell[ BoxData @ PaneBox[ TagBox[ _, "MarkdownImage", ___ ], ___ ], ___ ] } ],
            FormatMarkdown[ "```\n" <> $cbImageMarkdown <> "\n```" ] === image,
            FormatMarkdown[ "```wl\n" <> $cbImageMarkdown <> "\n```" ] === image,
            FormatMarkdown[ "```\n" <> $cbImageMarkdown <> "\n```", "Streaming" ] === image
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Image-Only-Block"
]

(* An image with other text in the block stays code: *)
VerificationTest[
    cbCode[ "```\nSee " <> $cbImageMarkdown <> "\n```" ],
    "See " <> $cbImageMarkdown,
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Image-With-Text-Is-Code"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Plain Text*)

(* "text" and "plaintext" (any case) are plain text blocks with the language "Plaintext" (which gives them copy and insert
   buttons only): *)
VerificationTest[
    FormatMarkdown[ "```" <> # <> "\nhello\n```" ] & /@ { "text", "TEXT", "plaintext", "PlainText" },
    ConstantArray[ { cbBlock[ cbPreformatted[ "hello", "Plaintext" ], "Plaintext" ] }, 4 ],
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Plaintext-Languages"
]

(* Plain text blocks unescape double backslashes, since models escape them in text but not in code. Other markdown
   escapes are left alone, and code blocks in other languages are not unescaped: *)
VerificationTest[
    {
        cbCode[ "```text\na \\* b \\\\ c\n```" ],
        cbCode[ "```text\na \\* b \\\\ c\n```", "Streaming" ],
        cbCode[ "```python\na \\* b \\\\ c\n```" ],
        cbCode[ "```\na \\* b \\\\ c\n```" ]
    },
    { "a \\* b \\ c", "a \\* b \\ c", "a \\* b \\\\ c", "a \\* b \\\\ c" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Plaintext-Unescapes-Backslashes"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stripCodePadding*)

(* Indentation that every non-blank line shares (taken from the first line) is removed. If any line has less, the code
   is left as is: *)
VerificationTest[
    cbCode[ "```python\n" <> # <> "\n```" ] & /@ {
        "  a\n  b",
        "  a\n\n  b",
        "  a\n    b",
        "\ta\n\tb",
        "  a\nb",
        "    a\n  b"
    },
    {
        "a\nb",
        "a\n\nb",
        "a\n  b",
        "a\nb",
        "  a\nb",
        "    a\n  b"
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Strip-Padding"
]

VerificationTest[
    cbBoxes[ "```wl\n  x = 1;\n  y\n```" ],
    RowBox @ { RowBox @ { RowBox @ { "x", "=", "1" }, ";" }, "\[IndentingNewLine]", "y" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Strip-Padding-WL"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Static Code Block Cache*)

(* When $useStaticCodeBlockCache is set (as it is when a response is written), finished code blocks are cached for the
   current response, since the same blocks are formatted again when the final cell is written. Using the cache gives the
   same output as not using it, for every kind of block: *)
VerificationTest[
    With[ { md = "```python\nx = 1\n```\n\n```wl\n1+1\n```\n\n```text\na \\\\ b\n```\n\n```\n" <> $cbImageMarkdown <> "\n```" },
        With[ { uncached = FormatMarkdown @ md },
            Block[
                {
                    Wolfram`Chatbook`Common`$useStaticCodeBlockCache = True,
                    Wolfram`Chatbook`Common`$staticCodeBlockCache    = <| |>
                },
                { FormatMarkdown @ md === uncached, Length @ Wolfram`Chatbook`Common`$staticCodeBlockCache > 0 }
            ]
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Static-Cache-Same-Output"
]

(* Formatting the same blocks again uses the cached values as they are (here replaced by a marker string): *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$useStaticCodeBlockCache = True,
            Wolfram`Chatbook`Common`$staticCodeBlockCache    = <| |>
        },
        FormatMarkdown[ "```python\nx = 1\n```\n\n```wl\n1+1\n```" ];
        Wolfram`Chatbook`Common`$staticCodeBlockCache = "CACHED" & /@ Wolfram`Chatbook`Common`$staticCodeBlockCache;
        NormalizeTextData @ FormatMarkdown[ "```python\nx = 1\n```\n\n```wl\n1+1\n```" ]
    ],
    { "CACHED\nCACHED" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Static-Cache-Hit"
]

(* The cache is not used for streaming or when the flag is not set: *)
VerificationTest[
    {
        Block[
            {
                Wolfram`Chatbook`Common`$useStaticCodeBlockCache = True,
                Wolfram`Chatbook`Common`$staticCodeBlockCache    = <| |>
            },
            FormatMarkdown[ "```python\nx = 1\n```", "Streaming" ];
            Wolfram`Chatbook`Common`$staticCodeBlockCache
        ],
        Block[ { Wolfram`Chatbook`Common`$staticCodeBlockCache = <| |> },
            FormatMarkdown[ "```python\nx = 1\n```" ];
            Wolfram`Chatbook`Common`$staticCodeBlockCache
        ]
    },
    { <| |>, <| |> },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Static-Cache-Not-Used"
]

(* A block cached outside the sidebar is not reused in the sidebar, since the template differs: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$useStaticCodeBlockCache = True,
            Wolfram`Chatbook`Common`$staticCodeBlockCache    = <| |>
        },
        FormatMarkdown[ "```python\nx = 1\n```" ];
        Block[ { $SidebarChat = True }, FormatMarkdown[ "```python\nx = 1\n```" ] ]
    ],
    { cbSidebarBlock[ cbExternal[ "x = 1", "Python" ], "Python" ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Static-Cache-Sidebar"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Transcripts*)

(* Wolfram Language blocks with In[n]:= and Out[n]= labels are shown as a two-column grid of labels and cells. Each
   input is its own Wolfram Language code block, and each output is an "Output" cell: *)
VerificationTest[
    FormatMarkdown[ "```wl\nIn[1]:= 1+1\nOut[1]= 2\n```" ],
    cbTranscript @ {
        { cbLabel[ "In[1]:=" ], cbBlock[ cbWL @ RowBox @ { "1", "+", "1" }, "Wolfram" ] },
        { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "2" ], "Output" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-In-Out"
]

(* Outputs are parsed as Wolfram Language too: *)
VerificationTest[
    FormatMarkdown[ "```wl\nIn[1]:= Eigenvalues[m]\nOut[1]= {3, 1}\n```" ],
    cbTranscript @ {
        { cbLabel[ "In[1]:=" ], cbBlock[ cbWL @ RowBox @ { "Eigenvalues", "[", "m", "]" }, "Wolfram" ] },
        { cbLabel[ "Out[1]=" ], Cell[ BoxData @ RowBox @ { "{", RowBox @ { "3", ",", "1" }, "}" }, "Output" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Output-Boxes"
]

(* Several inputs, labels without a space after them, indented labels, and "Out[n]:=": *)
VerificationTest[
    {
        FormatMarkdown[ "```wl\nIn[2]:= f[x_] := x^2\nIn[3]:= f[3]\nOut[3]= 9\n```" ],
        FormatMarkdown[ "```wl\nIn[1]:=1+1\nOut[1]=2\n```" ],
        FormatMarkdown[ "```wl\n  In[1]:= 1+1\n  Out[1]= 2\n```" ],
        FormatMarkdown[ "```wl\nIn[1]:= x\nOut[1]:= x\n```" ]
    },
    {
        cbTranscript @ {
            { cbLabel[ "In[2]:=" ], cbBlock[ cbWL @ RowBox @ { RowBox @ { "f", "[", "x_", "]" }, ":=", RowBox @ { "x", "^", "2" } }, "Wolfram" ] },
            { cbLabel[ "In[3]:=" ], cbBlock[ cbWL @ RowBox @ { "f", "[", "3", "]" }, "Wolfram" ] },
            { cbLabel[ "Out[3]=" ], Cell[ BoxData[ "9" ], "Output" ] }
        },
        cbTranscript @ {
            { cbLabel[ "In[1]:=" ], cbBlock[ cbWL @ RowBox @ { "1", "+", "1" }, "Wolfram" ] },
            { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "2" ], "Output" ] }
        },
        cbTranscript @ {
            { cbLabel[ "In[1]:=" ], cbBlock[ cbWL @ RowBox @ { "1", "+", "1" }, "Wolfram" ] },
            { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "2" ], "Output" ] }
        },
        cbTranscript @ {
            { cbLabel[ "In[1]:=" ], cbBlock[ cbWL[ "x" ], "Wolfram" ] },
            { cbLabel[ "Out[1]:=" ], Cell[ BoxData[ "x" ], "Output" ] }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Label-Variants"
]

(* "In[n]=" (without the colon) is an input label too: *)
VerificationTest[
    FormatMarkdown[ "```wl\nIn[1]= x\nOut[1]= x\n```" ],
    cbTranscript @ {
        { cbLabel[ "In[1]=" ], cbBlock[ cbWL[ "x" ], "Wolfram" ] },
        { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "x" ], "Output" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-In-Label-Without-Colon"
]

(* A single In label still gives a one-row grid. (parseCellGroupBlock has a branch meant to show this as a plain code
   block, but it matches label names "In"/"Out" that are never produced.) *)
VerificationTest[
    FormatMarkdown[ "```wl\nIn[1]:= 1+1\n```" ],
    cbTranscript @ { { cbLabel[ "In[1]:=" ], cbBlock[ cbWL @ RowBox @ { "1", "+", "1" }, "Wolfram" ] } },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Single-In-Label"
]

VerificationTest[
    FormatMarkdown[ "```wl\nOut[1]= 2\n```" ],
    cbTranscript @ { { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "2" ], "Output" ] } },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Single-Out-Label"
]

(* Messages (sym::tag: text) are shown as message templates without a label: *)
VerificationTest[
    FormatMarkdown[ "```wl\nIn[1]:= 1/0\nPower::infy: Infinite expression 1/0 encountered.\nOut[1]= ComplexInfinity\n```" ],
    cbTranscript @ {
        { cbLabel[ "In[1]:=" ], cbBlock[ cbWL @ RowBox @ { "1", "/", "0" }, "Wolfram" ] },
        {
            "",
            TemplateBox[
                { "Power", "infy", "Infinite expression 1/0 encountered.", 2, 0, 0, 0, "Local" },
                "MessageTemplate",
                BaseStyle -> "MSG"
            ]
        },
        { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "ComplexInfinity" ], "Output" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Message"
]

(* A message on its own is a transcript too: *)
VerificationTest[
    FormatMarkdown[ "```wl\nPower::infy: Infinite expression 1/0 encountered.\n```" ],
    cbTranscript @ {
        { "", TemplateBox[ { "Power", "infy", "Infinite expression 1/0 encountered.", 2, 0, 0, 0, "Local" }, "MessageTemplate", ___ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Message-Only"
]

(* Echo output (">>") gets a guillemet label and the "Echo" style: *)
VerificationTest[
    FormatMarkdown[ "```wl\nIn[1]:= Echo[5]\n>> 5\nOut[1]= 5\n```" ],
    cbTranscript @ {
        { cbLabel[ "In[1]:=" ], cbBlock[ cbWL @ RowBox @ { "Echo", "[", "5", "]" }, "Wolfram" ] },
        { StyleBox[ "\[RightGuillemet]", "EchoDingbat" ], Cell[ BoxData[ "5" ], "Echo" ] },
        { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "5" ], "Output" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Echo"
]

(* EchoTiming output (a watch icon) gets the "EchoTiming" style: *)
VerificationTest[
    FormatMarkdown[ "```wl\nIn[1]:= EchoTiming[5]\n\[WatchIcon] 0.000012\nOut[1]= 5\n```" ],
    cbTranscript @ {
        { cbLabel[ "In[1]:=" ], cbBlock[ cbWL @ RowBox @ { "EchoTiming", "[", "5", "]" }, "Wolfram" ] },
        { StyleBox[ "\[WatchIcon]", "EchoDingbat" ], Cell[ BoxData[ "0.000012" ], "EchoTiming" ] },
        { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "5" ], "Output" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-EchoTiming"
]

(* Printed output ("During evaluation of In[n]:=") gets the "Print" style without a label, also without an input. (The
   printed text is currently parsed as Wolfram Language, which spaces prose like code; that isn't asserted.) *)
VerificationTest[
    {
        FormatMarkdown[ "```wl\nIn[1]:= Print[\"hi\"]\nDuring evaluation of In[1]:= hi\n```" ],
        FormatMarkdown[ "```wl\nDuring evaluation of In[5]:= 5\n```" ]
    },
    {
        cbTranscript @ {
            { cbLabel[ "In[1]:=" ], cbBlock[ cbWL @ RowBox @ { "Print", "[", "\"hi\"", "]" }, "Wolfram" ] },
            { "", Cell[ BoxData[ "hi" ], "Print" ] }
        },
        cbTranscript @ { { "", Cell[ BoxData[ "5" ], "Print" ] } }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Print"
]

(* Text before the first label is a plain text code block row without a label: *)
VerificationTest[
    FormatMarkdown[ "```wl\nHere is a transcript:\nIn[1]:= x\nOut[1]= x\n```" ],
    cbTranscript @ {
        { "", cbBlock[ cbPreformatted[ "Here is a transcript:", "Plaintext" ], "Plaintext" ] },
        { cbLabel[ "In[1]:=" ], cbBlock[ cbWL[ "x" ], "Wolfram" ] },
        { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "x" ], "Output" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Leading-Text"
]

(* Labels are not parsed while streaming or in other languages: *)
VerificationTest[
    {
        FormatMarkdown[ "```wl\nIn[1]:= 1+1\nOut[1]= 2\n```", "Streaming" ],
        FormatMarkdown[ "```text\nIn[1]:= 1+1\nOut[1]= 2\n```" ],
        FormatMarkdown[ "```\nIn[1]:= 1+1\nOut[1]= 2\n```" ]
    },
    {
        { cbBlock[ Cell[ BoxData[ "In[1]:= 1+1\nOut[1]= 2" ], "ChatCodeActive" ], _ ] },
        { cbBlock[ cbPreformatted[ "In[1]:= 1+1\nOut[1]= 2", "Plaintext" ], "Plaintext" ] },
        { cbBlock[ cbPreformatted[ "In[1]:= 1+1\nOut[1]= 2", "" ], "" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Not-Parsed"
]

(* Serializing a transcript keeps its labels, code, messages and outputs in order. (The current serialization is a
   markdown table, which is not asserted here.) *)
VerificationTest[
    StringMatchQ[
        MarkdownRoundTrip[ "```wl\nIn[1]:= 1/0\nPower::infy: Infinite expression 1/0 encountered.\nOut[1]= ComplexInfinity\n```" ],
        ___ ~~ "In[1]:=" ~~ ___ ~~ "1 / 0" ~~ ___ ~~ "Power::infy: Infinite expression 1/0 encountered." ~~ ___ ~~
            "Out[1]=" ~~ ___ ~~ "ComplexInfinity" ~~ ___
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Transcript-Serialization-Content"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Script Shebang Lines*)

(* A Wolfram Language script's shebang line isn't parsed as code. It's shown as a header above the code (like in the
   package editor) and kept in the TaggingRules of the cell that holds both: *)
VerificationTest[
    cbScript[ line_, inner_ ] := Cell[
        BoxData @ GridBox[ { { FrameBox[ StyleBox[ "\"" <> line <> "\"", ___ ], ___ ] }, { inner } }, ___ ],
        TaggingRules -> KeyValuePattern[ "ShebangLine" -> line ]
    ];
    $cbScript = "```wl\n#!/usr/bin/env wolframscript\n\nx = 1\n```";
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Shebang-Definitions-GH#896"
]

(* Blank lines between the shebang line and the code are dropped: *)
VerificationTest[
    FormatMarkdown[ $cbScript ],
    { cbBlock[ cbScript[ "#!/usr/bin/env wolframscript", cbWL @ RowBox @ { "x", "=", "1" } ], "Wolfram" ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Shebang-Finished-GH#896"
]

VerificationTest[
    FormatMarkdown[ $cbScript, "Streaming" ],
    { cbBlock[ cbScript[ "#!/usr/bin/env wolframscript", Cell[ BoxData[ "x = 1" ], "ChatCodeActive" ] ], _ ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Shebang-Streaming-GH#896"
]

(* Only Wolfram Language code that starts with a shebang line and has code after it gets the header. Other blocks
   (including code that starts with "#!" but no path, which is valid Wolfram Language) are formatted as usual: *)
VerificationTest[
    cbSummary /@ {
        "```wl\n#!/usr/bin/env wolframscript\n```",
        "```wl\nx = 1\n#!/usr/bin/env wolframscript\n```",
        "```wl\n#! & /@ Range[5]\nTotal[%]\n```",
        "```python\n#!/usr/bin/env python\nprint(1)\n```",
        "```\n#!/bin/sh\necho hi\n```"
    },
    {
        { "Wolfram", "ChatCode" },
        { "Wolfram", "ChatCode" },
        { "Wolfram", "ChatCode" },
        { "Python", "ExternalLanguage" },
        { "", "ChatPreformatted" }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Shebang-Other-Code-GH#896"
]

(* Code that's formatted as a transcript doesn't get the header. The shebang line is the plain text first row, as for
   any text before the first label: *)
VerificationTest[
    FormatMarkdown[ "```wl\n#!/usr/bin/env wolframscript\nIn[1]:= x\nOut[1]= x\n```" ],
    cbTranscript @ {
        { "", cbBlock[ cbPreformatted[ "#!/usr/bin/env wolframscript", "Plaintext" ], "Plaintext" ] },
        { cbLabel[ "In[1]:=" ], cbBlock[ cbWL[ "x" ], "Wolfram" ] },
        { cbLabel[ "Out[1]=" ], Cell[ BoxData[ "x" ], "Output" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Shebang-Transcript-GH#896"
]

(* The insert, evaluate and copy buttons only use the code below the header: *)
VerificationTest[
    Wolfram`Chatbook`Formatting`Private`getCodeBlockContent @ First @ cbCodeBlocks @ $cbScript,
    Cell[ BoxData @ RowBox @ { "x", "=", "1" }, "Input" ],
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Shebang-Button-Content-GH#896"
]

(* Copying a response as notebook cells gives an input cell with the code: *)
VerificationTest[
    Cases[ ExplodeCell @ Cell[ TextData @ FormatMarkdown[ "Text\n\n" <> $cbScript ], "ChatOutput" ], Cell[ _, Except[ "Text" ], ___ ] ],
    { Cell[ BoxData @ RowBox @ { "x", "=", "1" }, "Input", ___ ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Shebang-ExplodeCell-GH#896"
]

(* Chat history keeps the shebang line in front of the code: *)
VerificationTest[
    {
        MarkdownRoundTrip @ $cbScript,
        MarkdownRoundTrip[ $cbScript, "Streaming" ],
        Block[ { $SidebarChat = True }, MarkdownRoundTrip @ $cbScript ]
    },
    ConstantArray[ "```wl\n#!/usr/bin/env wolframscript\nx = 1\n```", 3 ],
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Shebang-Serialization-GH#896"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sidebar Template*)

(* In the notebook assistant sidebar the sidebar version of the template is used, with the same arguments. Streaming
   results are cached per response in $resultCellCache, whose keys don't include $SidebarChat, so the cache is cleared
   here (SendChat.wl resets it for each response): *)
VerificationTest[
    Block[ { $SidebarChat = True, Wolfram`Chatbook`Common`$resultCellCache = <| |> },
        {
            FormatMarkdown[ "```wl\n1+1\n```" ],
            FormatMarkdown[ "```python\nx\n```" ],
            FormatMarkdown[ "```foo\nx\n```" ],
            FormatMarkdown[ "```wl\nx\n```", "Streaming" ],
            FormatMarkdown[ "```foo\nx\n```", "Streaming" ]
        }
    ],
    {
        { cbSidebarBlock[ cbWL @ RowBox @ { "1", "+", "1" }, "Wolfram" ] },
        { cbSidebarBlock[ cbExternal[ "x", "Python" ], "Python" ] },
        { cbSidebarBlock[ cbPreformatted[ "x", "foo" ], "foo" ] },
        { cbSidebarBlock[ Cell[ BoxData[ "x" ], "ChatCodeActive" ], _ ] },
        { cbSidebarBlock[ Cell[ "x", "ChatPreformatted", ___ ], _ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Sidebar-Template"
]

(* The sidebar template serializes the same way: *)
VerificationTest[
    Block[ { $SidebarChat = True }, { MarkdownRoundTrip[ "```wl\n1+1\n```" ], MarkdownRoundTrip[ "```python\nx\n```" ] } ],
    { "```wl\n1 + 1\n```", "```Python\nx\n```" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Sidebar-Serialization"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Wolfram Language Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto Correction*)

(* Finished Wolfram Language code is corrected with CodeCheckFix before it's displayed, e.g. mismatched brackets and
   snake case names (which are patterns in Wolfram Language): *)
VerificationTest[
    {
        cbBoxes[ "```wl\nf[{{3}}}\n```" ],
        cbBoxes[ "```wl\nfirst_symbol = 1;\nfirst_symbol + 1\n```" ]
    },
    {
        RowBox @ { "f", "[", RowBox @ { "{", RowBox @ { "{", "3", "}" }, "}" }, "]" },
        RowBox @ { RowBox @ { RowBox @ { "firstSymbol", "=", "1" }, ";" }, "\[IndentingNewLine]", RowBox @ { "firstSymbol", "+", "1" } }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-AutoCorrect"
]

(* The corrected code is what gets serialized: *)
VerificationTest[
    MarkdownRoundTrip[ "```wl\nf[{{3}}}\n```" ],
    "```wl\nf[{{3}}]\n```",
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-AutoCorrect-Serialization"
]

(* Code is not corrected while streaming: *)
VerificationTest[
    FormatMarkdown[ "```wl\nf[{{3}}}\n```", "Streaming" ],
    { cbBlock[ Cell[ BoxData[ "f[{{3}}}" ], "ChatCodeActive" ], _ ] },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-AutoCorrect-Not-Streaming"
]

(* A trailing "/" line (a partial tool command) is removed from finished code: *)
VerificationTest[
    cbBoxes[ "```wl\nx = 1\n/\n```" ],
    RowBox @ { "x", "=", "1" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Trailing-Slash-Removed"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StringToBoxes*)

(* StringToBoxes[s, "WL"] does what code blocks do (correction and special boxes). StringToBoxes[s] only parses the
   string and adjusts spacing: *)
VerificationTest[
    {
        StringToBoxes[ "f[{{3}}}" ],
        StringToBoxes[ "f[{{3}}}", "WL" ],
        StringToBoxes[ "Placeholder[\"x\"]" ],
        StringToBoxes[ "Placeholder[\"x\"]", "WL" ]
    },
    {
        RowBox @ { RowBox @ { "f", "[", RowBox @ { "{", RowBox @ { "{", "3", "}" }, "}" } }, "}" },
        RowBox @ { "f", "[", RowBox @ { "{", RowBox @ { "{", "3", "}" }, "}" }, "]" },
        RowBox @ { "Placeholder", "[", "\"x\"", "]" },
        TagBox[ FrameBox[ "\"x\"" ], "Placeholder" ]
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-StringToBoxes-WL-Versus-Plain"
]

(* A string literal stays a single string box: *)
VerificationTest[
    {
        StringToBoxes[ "\"hello world\"" ],
        StringToBoxes[ "\"x\"" ],
        StringToBoxes[ "\"1+1\"" ],
        StringToBoxes[ "\"hello world\"", "WL" ]
    },
    { "\"hello world\"", "\"x\"", "\"1+1\"", "\"hello world\"" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-StringToBoxes-Quoted-String"
]

(* Invalid code is parsed as far as possible, and empty code is an empty string: *)
VerificationTest[
    { StringToBoxes[ "f[x" ], StringToBoxes[ "" ], StringToBoxes[ "", "WL" ] },
    { RowBox @ { "f", "[", "x" }, "", "" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-StringToBoxes-Invalid-Code"
]

VerificationTest[
    StringToBoxes[ 123 ],
    _Failure,
    { StringToBoxes::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-StringToBoxes-Invalid-Argument"
]

(* While streaming, both forms give the string unchanged, except that StringToBoxes[s] shows inlined expression URIs as
   a placeholder: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$dynamicText = True },
        {
            StringToBoxes[ "x = 1 + 2" ],
            StringToBoxes[ "x = 1 + 2", "WL" ],
            StringToBoxes[ "Show[InlinedExpression[\"attachment://content-abc12\"]]" ]
        }
    ],
    { "x = 1 + 2", "x = 1 + 2", "Show[\[LeftSkeleton]\[Ellipsis]\[RightSkeleton]]" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-StringToBoxes-Streaming"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Box Spacing*)

(* Spaces (up to three) around infix operators are removed, since the front end adds its own spacing. Tabs are kept: *)
VerificationTest[
    {
        StringToBoxes[ "x = 1 + 2" ],
        StringToBoxes[ "a  +  b" ],
        StringToBoxes[ "a\t+\tb" ],
        StringToBoxes[ "a+b-c*d/e^f" ],
        StringToBoxes[ "a && b || c == d === e != f =!= g < h <= i > j >= k -> l :> m" ]
    },
    {
        RowBox @ { "x", "=", RowBox @ { "1", "+", "2" } },
        RowBox @ { "a", "+", "b" },
        RowBox @ { "a", "\t", "+", "\t", "b" },
        RowBox @ { "a", "+", "b", "-", RowBox @ { "c", "*", RowBox @ { "d", "/", RowBox @ { "e", "^", "f" } } } },
        RowBox @ {
            RowBox @ {
                RowBox @ { "a", "&&", "b" },
                "||",
                RowBox @ {
                    RowBox @ { "c", "==", "d" },
                    "===",
                    RowBox @ { "e", "!=", "f" },
                    "=!=",
                    RowBox @ { "g", "<", "h", "<=", "i", ">", "j", ">=", "k" }
                }
            },
            "->",
            RowBox @ { "l", ":>", "m" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Box-Spacing-Infix-Operators"
]

(* Spaces after commas are removed too, but spaces around other operators are kept: *)
VerificationTest[
    { StringToBoxes[ "f[a, b, c]" ], StringToBoxes[ "\"a\" <> \"b\"" ] },
    {
        RowBox @ { "f", "[", RowBox @ { "a", ",", "b", ",", "c" }, "]" },
        RowBox @ { "\"a\"", " ", "<>", " ", "\"b\"" }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Box-Spacing-Commas"
]

(* Line breaks become indenting newlines: *)
VerificationTest[
    { StringToBoxes[ "x = 1;\ny = 2" ], StringToBoxes[ "Module[{x},\n  x + 1\n]" ] },
    {
        RowBox @ { RowBox @ { RowBox @ { "x", "=", "1" }, ";" }, "\[IndentingNewLine]", RowBox @ { "y", "=", "2" } },
        RowBox @ {
            "Module",
            "[",
            RowBox @ { RowBox @ { "{", "x", "}" }, ",", "\[IndentingNewLine]", "  ", RowBox @ { "x", "+", "1" } },
            "\[IndentingNewLine]",
            "]"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Box-Spacing-Newlines"
]

(* Comments are left untouched: *)
VerificationTest[
    { StringToBoxes[ "(* a + b, c *)" ], StringToBoxes[ "x = 1 (* a + b *)" ] },
    {
        RowBox @ { "(*", " ", RowBox @ { RowBox @ { "a", " ", "+", " ", "b" }, ",", " ", "c" }, " ", "*)" },
        RowBox @ { "x", "=", "1", " ", RowBox @ { "(*", " ", RowBox @ { "a", " ", "+", " ", "b" }, " ", "*)" } }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Box-Spacing-Comments"
]

(* In the cloud, operators are replaced by the characters the desktop front end would display for them: *)
VerificationTest[
    Block[ { $CloudEvaluation = True }, StringToBoxes[ "a -> b; c != d; <|x -> 1|>; g |-> h" ] ],
    RowBox @ {
        RowBox @ { "a", "\[Rule]", "b" },
        ";",
        " ",
        RowBox @ { "c", "\[NotEqual]", "d" },
        ";",
        " ",
        RowBox @ { "\[LeftAssociation]", RowBox @ { "x", "\[Rule]", "1" }, "\[RightAssociation]" },
        ";",
        " ",
        RowBox @ { "g", " ", "\[Function]", " ", "h" }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Box-Spacing-Cloud-Operators"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Inlined Expressions*)

(* Expression URIs in finished code (as markdown images or <!...!> references) are replaced by the boxes of the
   expression they refer to, and serialize as that expression: *)
VerificationTest[
    Module[ { uri, key },
        uri = MakeExpressionURI @ Range[ 3 ];
        key = First @ StringCases[ uri, "content-" ~~ (LetterCharacter|DigitCharacter).. ];
        {
            cbBoxes[ "```wl\nTotal[" <> uri <> "]\n```" ],
            cbBoxes[ "```wl\nTotal[<!attachment://" <> key <> "!>]\n```" ],
            MarkdownRoundTrip[ "```wl\nTotal[<!attachment://" <> key <> "!>]\n```" ]
        }
    ],
    {
        RowBox @ { "Total", "[", RowBox @ { "{", RowBox @ { "1", ",", "2", ",", "3" }, "}" }, "]" },
        RowBox @ { "Total", "[", RowBox @ { "{", RowBox @ { "1", ",", "2", ",", "3" }, "}" }, "]" },
        "```wl\nTotal[{1, 2, 3}]\n```"
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Inlined-Expressions"
]

(* Import and Get of an expression URI or key are shown as the expression too: *)
VerificationTest[
    Module[ { key },
        key = First @ StringCases[ MakeExpressionURI @ Range[ 3 ], "content-" ~~ (LetterCharacter|DigitCharacter).. ];
        {
            cbBoxes[ "```wl\nTotal[Import[\"<!attachment://" <> key <> "!>\"]]\n```" ],
            cbBoxes[ "```wl\nTotal[Get[\"" <> key <> "\"]]\n```" ],
            MarkdownRoundTrip[ "```wl\nTotal[Import[\"<!attachment://" <> key <> "!>\"]]\n```" ]
        }
    ],
    {
        RowBox @ { "Total", "[", RowBox @ { "{", RowBox @ { "1", ",", "2", ",", "3" }, "}" }, "]" },
        RowBox @ { "Total", "[", RowBox @ { "{", RowBox @ { "1", ",", "2", ",", "3" }, "}" }, "]" },
        "```wl\nTotal[{1, 2, 3}]\n```"
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Inlined-Expressions-Import-Get"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Special Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Freeform Prompt*)

(* While streaming, \[FreeformPrompt]["query"] is shown as a natural language input box without asking Wolfram|Alpha
   (the boxes are embedded in the code string as linear syntax): *)
VerificationTest[
    cbOffline @ cbStreamingShowsQ[
        "```wl\n\[FreeformPrompt][\"population of france\"]\n```",
        { "OverlayBox", "FreeformPrompt", "population of france" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-FreeformPrompt-Streaming"
]

(* A query that has not finished streaming in yet is shown the same way: *)
VerificationTest[
    cbOffline @ cbStreamingShowsQ[ "```wl\n\[FreeformPrompt][\"population of fr", { "OverlayBox", "population of fr" } ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-FreeformPrompt-Streaming-Partial"
]

(* An unterminated query in finished code also gets the input box without asking Wolfram|Alpha: *)
VerificationTest[
    cbOffline @ Cases[
        cbBoxes[ "```wl\n\[FreeformPrompt][\"population of fr" ],
        OverlayBox[ { FrameBox[ StyleBox[ q_String, ___ ], ___ ], StyleBox[ "\[FreeformPrompt]", ___ ] }, ___ ] :>
            StringContainsQ[ q, "population of fr" ],
        { 0, Infinity }
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-FreeformPrompt-Unterminated-Finished"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ResourceFunction*)

(* While streaming, ResourceFunction["Name"] is shown as an inert resource function box, without looking up the
   resource. The rest of the code stays as text: *)
VerificationTest[
    cbOffline @ cbStreamingShowsQ[
        "```wl\nResourceFunction[\"BirdSay\"][\"hi\"]\n```",
        { "FunctionResourceBox", "BirdSay", "hi" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-ResourceFunction-Streaming"
]

(* A partial name is shown the same way: *)
VerificationTest[
    cbOffline @ cbStreamingShowsQ[ "```wl\nResourceFunction[\"BirdS", { "FunctionResourceBox", "BirdS" } ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-ResourceFunction-Streaming-Partial"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PacletSymbol*)

(* PacletSymbol with a publisher/name paclet gets the paclet repository formatting, and serializes back to the
   original code: *)
VerificationTest[
    cbOffline @ {
        StringToBoxes[ "PacletSymbol[\"Wolfram/Chatbook\", \"FormatChatOutput\"]", "WL" ],
        MarkdownRoundTrip[ "```wl\nPacletSymbol[\"Wolfram/Chatbook\", \"FormatChatOutput\"]\n```" ]
    },
    {
        InterpretationBox[
            _,
            PacletSymbol[ "Wolfram/Chatbook", "FormatChatOutput" ],
            OrderlessPatternSequence[ BoxID -> "PacletSymbolBox", ___ ]
        ],
        "```wl\nPacletSymbol[\"Wolfram/Chatbook\", \"FormatChatOutput\"]\n```"
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-PacletSymbol-Repository"
]

(* Other paclet names, and arguments that are not strings, keep the ordinary typesetting: *)
VerificationTest[
    cbOffline @ {
        StringToBoxes[ "PacletSymbol[\"Chatbook\", \"Foo\"]", "WL" ],
        StringToBoxes[ "PacletSymbol[x, \"Foo\"]", "WL" ],
        MarkdownRoundTrip[ "```wl\nPacletSymbol[\"Chatbook\", \"Foo\"]\n```" ]
    },
    {
        RowBox @ { "PacletSymbol", "[", RowBox @ { "\"Chatbook\"", ",", "\"Foo\"" }, "]" },
        RowBox @ { "PacletSymbol", "[", RowBox @ { "x", ",", "\"Foo\"" }, "]" },
        "```wl\nPacletSymbol[\"Chatbook\", \"Foo\"]\n```"
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-PacletSymbol-Plain"
]

(* While streaming, the repository formatting is embedded in the code string: *)
VerificationTest[
    cbOffline @ cbStreamingShowsQ[
        "```wl\nPacletSymbol[\"Wolfram/Chatbook\", \"FormatChatOutput\"]\n```",
        { "InterpretationBox", "PacletSymbolBox" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-PacletSymbol-Streaming"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DateObject*)

(* DateObject with a literal date list is shown as a date. The date is evaluated, so the serialized code is the
   normalized DateObject: *)
VerificationTest[
    cbOffline @ {
        StringToBoxes[ "DateObject[{2024, 1, 15}, \"Day\"]", "WL" ],
        MarkdownRoundTrip[ "```wl\nDateObject[{2024, 1, 15}]\n```" ],
        MarkdownRoundTrip[ "```wl\nDateObject[{2024, 13, 45}]\n```" ]
    },
    {
        TemplateBox[ { _, RowBox @ { "DateObject", "[", ___, "]" } }, "DateObject", ___ ],
        "```wl\nDateObject[{2024, 1, 15}, \"Day\"]\n```",
        "```wl\nDateObject[{2025, 2, 14}, \"Day\"]\n```"
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-DateObject"
]

(* Other arguments are left as code, as is a literal date that doesn't evaluate to a date (here an unknown
   granularity). Nothing is done while streaming: *)
VerificationTest[
    cbOffline @ {
        StringToBoxes[ "DateObject[x]", "WL" ],
        StringToBoxes[ "DateObject[{a, b}]", "WL" ],
        StringToBoxes[ "DateObject[{2024, 1, 15}, \"Foo\"]", "WL" ],
        FormatMarkdown[ "```wl\nDateObject[{2024, 1, 15}, \"Day\"]\n```", "Streaming" ]
    },
    {
        RowBox @ { "DateObject", "[", "x", "]" },
        RowBox @ { "DateObject", "[", RowBox @ { "{", RowBox @ { "a", ",", "b" }, "}" }, "]" },
        RowBox @ { "DateObject", "[", RowBox @ { RowBox @ { "{", RowBox @ { "2024", ",", "1", ",", "15" }, "}" }, ",", "\"Foo\"" }, "]" },
        { cbBlock[ Cell[ BoxData[ "DateObject[{2024, 1, 15}, \"Day\"]" ], "ChatCodeActive" ], _ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-DateObject-Unchanged"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Entities*)

(* Entity, EntityClass and EntityProperty get their StandardForm typesetting when it gives a template box. This uses a
   local entity store, so no network access is needed. Unknown entities are left as code, and special boxes inside the
   arguments are still formatted: *)
VerificationTest[
    cbOffline @ WithCleanup[
        EntityRegister @ EntityStore[
            "ChatbookCodeBlocksTestThing" -> <|
                "Entities"      -> <| "a" -> <| "Label" -> "Alpha" |> |>,
                "Properties"    -> <| "Label" -> <| "Label" -> "label" |>, "size" -> <| "Label" -> "Size" |> |>,
                "EntityClasses" -> <| "all" -> <| "Entities" -> { "a" }, "Label" -> "All things" |> |>
            |>
        ],
        {
            StringToBoxes[ "Entity[\"ChatbookCodeBlocksTestThing\", \"a\"]", "WL" ],
            StringToBoxes[ "EntityClass[\"ChatbookCodeBlocksTestThing\", \"all\"]", "WL" ],
            StringToBoxes[ "EntityProperty[\"ChatbookCodeBlocksTestThing\", \"size\"]", "WL" ],
            StringToBoxes[ "Entity[\"ChatbookCodeBlocksTestThing\", \"zzz\"]", "WL" ],
            StringToBoxes[ "Entity[Placeholder[\"type\"], \"a\"]", "WL" ],
            MarkdownRoundTrip[ "```wl\nEntity[\"ChatbookCodeBlocksTestThing\", \"a\"]\n```" ]
        },
        EntityUnregister[ "ChatbookCodeBlocksTestThing" ]
    ],
    {
        TemplateBox[ { "\"Alpha\"", ___ }, "Entity", ___ ],
        TemplateBox[ { "\"All things\"", ___ }, "EntityClass", ___ ],
        TemplateBox[ { "\"Size\"", ___ }, "EntityProperty", ___ ],
        RowBox @ { "Entity", "[", RowBox @ { "\"ChatbookCodeBlocksTestThing\"", ",", "\"zzz\"" }, "]" },
        RowBox @ { "Entity", "[", RowBox @ { TagBox[ FrameBox[ "\"type\"" ], "Placeholder" ], ",", "\"a\"" }, "]" },
        "```wl\nEntity[\"ChatbookCodeBlocksTestThing\", \"a\"]\n```"
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Entity-Local-Store"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization*)

(* Wolfram Language blocks serialize as fenced "wl" code, whatever tag was used. The code is serialized from the boxes,
   so the spacing is the serializer's: *)
VerificationTest[
    MarkdownRoundTrip /@ { "```wl\n1+1\n```", "```mathematica\nf[x_] := x^2\n```", "```Wolfram Language\n\"a string\"\n```" },
    { "```wl\n1 + 1\n```", "```wl\nf[x_] := x ^ 2\n```", "```wl\n\"a string\"\n```" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Serialization-WL"
]

(* Multi-line code keeps its lines. (Continuation lines currently get a tab from the indenting newlines, which is not
   asserted here.) *)
VerificationTest[
    StringReplace[ MarkdownRoundTrip[ # ], "\n\t" -> "\n" ] & /@ {
        "```wolfram\nx = {1, 2, 3};\nTotal[x]\n```",
        "```wl\n(* comment *)\nx = 1\n```"
    },
    { "```wl\nx = {1, 2, 3};\nTotal[x]\n```", "```wl\n(* comment *)\nx = 1\n```" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Serialization-WL-Multiline"
]

(* External language blocks serialize with the normalized language name: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "```python\nprint(1)\n```",
        "```js\nconsole.log(1)\n```",
        "```bash\nls -la\n```",
        "```r\nx <- 1\n```",
        "```sql\nSELECT 1\n```"
    },
    {
        "```Python\nprint(1)\n```",
        "```NodeJS\nconsole.log(1)\n```",
        "```Shell\nls -la\n```",
        "```R\nx <- 1\n```",
        "```SQL\nSELECT 1\n```"
    },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Serialization-External"
]

(* Other blocks serialize with their language tag (none if there was none). Plain text blocks are tagged "Plaintext"
   and serialize the unescaped text: *)
VerificationTest[
    MarkdownRoundTrip /@ { "```foo\nbar baz\n```", "```\nbar baz\n```", "```zsh\necho hi\n```", "```text\nhello \\\\ world\n```" },
    { "```foo\nbar baz\n```", "```\nbar baz\n```", "```zsh\necho hi\n```", "```Plaintext\nhello \\ world\n```" },
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Serialization-Other"
]

(* Serialized code has the trimming and unindenting applied: *)
VerificationTest[
    MarkdownRoundTrip[ "```python\n\n  a\n    b\n\n```" ],
    "```Python\na\n  b\n```",
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Serialization-Stripped-Code"
]

(* Text around a block keeps its blank lines: *)
VerificationTest[
    cbNormalizeString @ MarkdownRoundTrip[ "Before\n\n```wl\n1+1\n```\n\nAfter" ],
    "Before\n\n```wl\n1 + 1\n```\n\nAfter",
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Serialization-Surrounding-Text"
]

(* An image-only block serializes as the image: *)
VerificationTest[
    MarkdownRoundTrip[ "```\n" <> $cbImageMarkdown <> "\n```" ],
    "![alt](" <> $cbImageFile <> ")",
    SameTest -> MatchQ,
    TestID   -> "CodeBlocks-Serialization-Image-Only-Block"
]

(* :!CodeAnalysis::EndBlock:: *)
