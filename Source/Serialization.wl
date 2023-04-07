BeginPackage["ConnorGray`Chatbook`Serialization`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[CellToString, "
CellToString[cell$] serializes a Cell expression as a string for use in chat.
"]

Begin["`Private`"]

Needs["ConnorGray`Chatbook`Errors`"]
Needs["ConnorGray`Chatbook`ErrorUtils`"]


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)

ClearAll[ "ConnorGray`Chatbook`Serialization`*"         ];
ClearAll[ "ConnorGray`Chatbook`Serialization`Private`*" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config*)
$$delimiterStyle   = "PageBreak"|"ExampleDelimiter";
$$noCellLabelStyle = "ChatUserInput"|"ChatSystemInput"|"ChatContextDivider"|$$delimiterStyle;
$$docSearchStyle   = "ChatQuery"; (* TODO: currently unused *)

(* Default character encoding for strings created from cells *)
$cellCharacterEncoding = "UTF-8";

(* Set a max string length for output cells to avoid blowing up token counts *)
$maxOutputCellStringLength = 500;

(* Set a page width for expressions that need to be serialized as InputForm *)
$cellPageWidth = 100;

(* Whether to collect data that can help discover missing definitions *)
$cellToStringDebug = False;

(* Can be redefined locally depending on cell style *)
$showStringCharacters = True;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Conversion Rules*)

(* Rules to convert some 2D boxes into an infix form *)
$boxOp = <| SuperscriptBox -> "^", SubscriptBox -> "_" |>;

(* How to choose TemplateBox arguments for serialization *)
$templateBoxRules = <|
    "DateObject"       -> First,
    "HyperlinkDefault" -> First,
    "RefLink"          -> First,
    "RowDefault"       -> Identity
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Patterns*)

$boxOperators = Alternatives @@ Keys @ $boxOp;

$graphicsHeads = Alternatives[
    GraphicsBox,
    RasterBox,
    NamespaceBox,
    Graphics3DBox
];

(* Serialize the first argument of these and ignore the rest *)
$stringStripHeads = Alternatives[
    ButtonBox,
    CellGroupData,
    FormBox,
    FrameBox,
    ItemBox,
    PanelBox,
    RowBox,
    StyleBox,
    TagBox,
    TextData,
    TooltipBox
];

(* Boxes that should be ignored during serialization *)
$ignoredBoxPatterns = Alternatives[
    _CheckboxBox,
    _PaneSelectorBox,
    StyleBox[ _GraphicsBox, ___, "NewInGraphic", ___ ]
];

(* CellEvaluationLanguage appears to not be System` at startup, so use this for matching as a precaution *)
$$cellEvaluationLanguage = Alternatives[
    "CellEvaluationLanguage",
    _Symbol? (Function[
        Null,
        AtomQ @ Unevaluated @ # && SymbolName @ Unevaluated @ # === "CellEvaluationLanguage",
        HoldFirst
    ])
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Templates*)

(* Helper function to define string templates that handle WL (with backticks) *)
codeTemplate[ template_String? StringQ ] := StringTemplate[ template, Delimiters -> "%%" ];
codeTemplate[ template_ ] := template;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Stack Trace for Message Cells*)
$stackTraceTemplate = codeTemplate[ "\
%%String%%
BEGIN_STACK_TRACE
%%StackTrace%%
END_STACK_TRACE\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Explanation with Search Results*)
$searchQueryTemplate = codeTemplate[ "\
Please explain the following query text to me:
---
%%String%%
---
Try to include information about how this relates to the Wolfram Language if it makes sense to do so.

If there are any relevant search results, feel free to use them in your explanation. Do not include search results \
that are not relevant to the query.

%%SearchResults%%\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Wolfram Alpha Input*)
$wolframAlphaInputTemplate = codeTemplate[ "\
WolframAlpha[\"%%Query%%\"]

WOLFRAM_ALPHA_PARSED_INPUT: %%Code%%

" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CellToString*)
CellToString // SetFallthroughError;

CellToString // Options = {
    CharacterEncoding -> $cellCharacterEncoding,
    "Debug"           -> $cellToStringDebug,
    PageWidth         -> $cellPageWidth
};

CellToString[ cell_, opts: OptionsPattern[ ] ] :=
    Block[
        {
            $cellCharacterEncoding = OptionValue[ "CharacterEncoding" ],
            $cellToStringDebug     = TrueQ @ OptionValue[ "Debug" ],
            $cellPageWidth         = OptionValue[ "PageWidth" ]
        },
        If[ ! StringQ @ $cellCharacterEncoding, $cellCharacterEncoding = "UTF-8" ];
        Replace[
            cellToString @ cell,
            (* TODO: give a failure here *)
            Except[ _String? StringQ ] :> ""
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellToString*)
cellToString // SetFallthroughError;

(* Argument normalization *)
cellToString[ data: _TextData|_BoxData|_RawData ] := cellToString @ Cell @ data;
cellToString[ string_String? StringQ ] := cellToString @ Cell @ string;
cellToString[ cell_CellObject ] := cellToString @ NotebookRead @ cell;

(* Multiple cells to one string *)
cellToString[ Notebook[ cells_List, ___ ] ] := cellsToString @ cells;
cellToString[ Cell @ CellGroupData[ cells_List, _ ] ] := cellsToString @ cells;
cellToString[ nbo_NotebookObject ] := cellToString @ Cells @ nbo;
cellToString[ cells: { __CellObject } ] := cellsToString @ NotebookRead @ cells;

(* Drop cell label for some styles *)
cellToString[ Cell[ a__, $$noCellLabelStyle, b___, CellLabel -> _, c___ ] ] :=
    cellToString @ Cell[ a, b, c ];

(* Convert delimiters to equivalent markdown *)
cellToString[ Cell[ __, $$delimiterStyle, ___ ] ] := "\n---\n";

(* Styles that should include documentation search *)
cellToString[ Cell[ a__, $$docSearchStyle, b___ ] ] :=
    TemplateApply[
        $searchQueryTemplate,
        <|
            "String" -> cellToString @ DeleteCases[ Cell[ a, b ], CellLabel -> _ ],
            "SearchResults" -> docSearchResultString @ a
        |>
    ];

(* Prepend cell label to the cell string *)
cellToString[ Cell[ a___, CellLabel -> label_String, b___ ] ] :=
    With[ { str = cellToString @ Cell[ a, b ] }, label<>" "<>str /; StringQ @ str ];

(* Cells showing raw data (ctrl-shift-e) *)
cellToString[ Cell[ RawData[ str_String ], ___ ] ] := str;

(* Include a stack trace for message cells when available *)
cellToString[ Cell[ a_, "Message", "MSG", b___ ] ] :=
    Module[ { string, stacks, stack, stackString },
        { string, stacks } = Reap[ cellToString0 @ Cell[ a, b ], $messageStack ];
        stack = First[ First[ stacks, $Failed ], $Failed ];
        If[ MatchQ[ stack, { __HoldForm } ] && Length @ stack >= 3
            ,
            stackString = StringRiffle[
                Cases[
                    stack,
                    HoldForm[ expr_ ] :> ToString[
                        Unevaluated @ expr,
                        InputForm,
                        CharacterEncoding -> $cellCharacterEncoding
                    ]
                ],
                "\n"
            ];
            TemplateApply[
                $stackTraceTemplate,
                <| "String" -> string, "StackTrace" -> stackString |>
            ]
            ,
            string
        ]
    ];

(* External language cells get converted to an equivalent ExternalEvaluate input *)
cellToString[ Cell[ code_, "ExternalLanguage", ___, $$cellEvaluationLanguage -> lang_String, ___ ] ] :=
    Module[ { string },
        string = cellToString0 @ code;
        "ExternalEvaluate[\""<>lang<>"\", \""<>string<>"\"]" /; StringQ @ string
    ];

(* Begin recursive serialization of the cell content *)
cellToString[ cell_ ] := cellToString0 @ cell;

cellToString0[ cell_ ] :=
    With[ { string = fasterCellToString @ cell },
        If[ StringQ @ string,
            string,
            slowCellToString @ cell
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellsToString*)
cellsToString // SetFallthroughError;
cellsToString[ cells_List ] :=
    With[ { strings = cellToString /@ cells },
        StringRiffle[ Select[ strings, StringQ ], "\n\n" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fasterCellToString*)
fasterCellToString[ arg_ ] :=
    Block[ { $catchingStringFail = True },
        Catch[
            Module[ { string },
                string = fasterCellToString0 @ arg;
                If[ StringQ @ string,
                    Replace[ StringTrim @ string, "" -> Missing[ "NotFound" ] ],
                    $Failed
                ]
            ],
            $stringFail
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Ignored/Skipped*)

fasterCellToString0[ $ignoredBoxPatterns ] := "";
fasterCellToString0[ $stringStripHeads[ a_, ___ ] ] := fasterCellToString0 @ a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*String Normalization*)

(* Add spacing between RowBox elements that are comma separated *)
fasterCellToString0[ "," ] := ", ";

(* IndentingNewline *)
fasterCellToString0[ FromCharacterCode[ 62371 ] ] := "\n\t";

(* StandardForm strings *)
fasterCellToString0[ a_String /; StringMatchQ[ a, "\""~~___~~"\!"~~___~~"\"" ] ] :=
    With[ { res = ToString @ ToExpression[ a, InputForm ] },
        If[ TrueQ @ $showStringCharacters,
            res,
            StringTrim[ res, "\"" ]
        ] /; FreeQ[ res, s_String /; StringContainsQ[ s, "\!" ] ]
    ];

fasterCellToString0[ a_String /; StringContainsQ[ a, "\!" ] ] :=
    With[ { res = stringToBoxes @ a }, res /; FreeQ[ res, s_String /; StringContainsQ[ s, "\!" ] ] ];

(* Other strings *)
fasterCellToString0[ a_String ] :=
    ToString[
        If[ TrueQ @ $showStringCharacters, a, StringTrim[ a, "\"" ] ],
        CharacterEncoding -> $cellCharacterEncoding
    ];

fasterCellToString0[ a: { ___String } ] := StringJoin[ fasterCellToString0 /@ a ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Wolfram Alpha Input*)

fasterCellToString0[ NamespaceBox[
    "WolframAlphaQueryParseResults",
    DynamicModuleBox[
        { OrderlessPatternSequence[ Typeset`q$$ = query_String, Typeset`chosen$$ = code_String, ___ ] },
        ___
    ],
    ___
] ] := TemplateApply[ $wolframAlphaInputTemplate, <| "Query" -> query, "Code" -> code |> ];

fasterCellToString0[ NamespaceBox[
    "WolframAlphaQueryParseResults",
    DynamicModuleBox[ { ___, Typeset`chosen$$ = code_String, ___ }, ___ ],
    ___
] ] := code;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Graphics*)
fasterCellToString0[ box: $graphicsHeads[ ___ ] ] :=
    If[ TrueQ[ ByteCount @ box < $maxOutputCellStringLength ],
        (* For relatively small graphics expressions, we'll give an InputForm string *)
        makeGraphicsString @ box,
        (* Otherwise, give the same thing you'd get in a standalone kernel*)
        "-Graphics-"
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Template Boxes*)

(* Messages *)
fasterCellToString0[ TemplateBox[ args: { _, _, str_String, ___ }, "MessageTemplate" ] ] := (
    sowMessageData @ args; (* Look for stack trace data *)
    fasterCellToString0 @ str
);

(* Row *)
fasterCellToString0[ TemplateBox[ args_, "RowDefault", ___ ] ] := fasterCellToString0 @ args;

(* Tooltips *)
fasterCellToString0[ TemplateBox[ { a_, ___ }, "PrettyTooltipTemplate", ___ ] ] := fasterCellToString0 @ a;

(* Control-Equal Input *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "boxes" -> box_ ], "LinguisticAssistantTemplate" ] ] :=
    fasterCellToString0 @ box;

(* NotebookObject *)
fasterCellToString0[
    TemplateBox[ KeyValuePattern[ "label" -> label_String ], "NotebookObjectUUIDsUnsaved"|"NotebookObjectUUIDs" ]
] := "NotebookObject["<>label<>"]";

(* Entity *)
fasterCellToString0[ TemplateBox[ { _, box_, ___ }, "Entity" ] ] := fasterCellToString0 @ box;

(* Other *)
fasterCellToString0[ TemplateBox[ args_, name_String, ___ ] ] :=
    With[ { s = fasterCellToString0 @ $templateBoxRules[ name ][ args ] },
        s /; StringQ @ s
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Math Boxes*)

(* Sqrt *)
fasterCellToString0[ SqrtBox[ a_ ] ] :=
    "Sqrt["<>fasterCellToString0 @ a<>"]";

(* Fraction *)
fasterCellToString0[ FractionBox[ a_, b_ ] ] :=
    "(" <> fasterCellToString0 @ a <> "/" <> fasterCellToString0 @ b <> ")";

(* Other *)
fasterCellToString0[ (box: $boxOperators)[ a_, b_ ] ] :=
    Module[ { a$, b$ },
        a$ = fasterCellToString0 @ a;
        b$ = fasterCellToString0 @ b;
        If[ StringQ @ a$ && StringQ @ b$,
            a$ <> $boxOp @ box <> b$,
            { a$, b$ }
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Other*)

fasterCellToString0[ BoxData[ string_String ] ] :=
    fasterCellToString0 @ string;

fasterCellToString0[ BoxData[ boxes_List ] ] :=
    With[ { strings = fasterCellToString0 /@ boxes },
        StringRiffle[ strings, "\n" ] /; AllTrue[ strings, StringQ ]
    ];

fasterCellToString0[ list_List ] :=
    With[ { strings = fasterCellToString0 /@ list },
        StringJoin @ strings /; AllTrue[ strings, StringQ ]
    ];

fasterCellToString0[ cell: Cell[ a_, ___ ] ] :=
    Block[ { $showStringCharacters = showStringCharactersQ @ cell }, fasterCellToString0 @ a ];

fasterCellToString0[ InterpretationBox[ _, expr_, ___ ] ] :=
    ToString[
        Unevaluated @ expr,
        InputForm,
        PageWidth         -> $cellPageWidth,
        CharacterEncoding -> $cellCharacterEncoding
    ];

fasterCellToString0[ GridBox[ grid_? MatrixQ, ___ ] ] :=
    Module[ { strings, tr, colSizes },
        strings = Map[ fasterCellToString0, grid, { 2 } ];
        (
            tr = Transpose @ strings;
            colSizes = Max /@ Map[ StringLength, tr, { 2 } ];
            StringRiffle[
                StringRiffle /@ Transpose @ Apply[
                    StringPadRight,
                    Transpose @ { tr, colSizes },
                    { 1 }
                ],
                "\n"
            ]
        ) /; AllTrue[ strings, StringQ, 2 ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Missing Definition*)
fasterCellToString0[ a___ ] := (
    If[ TrueQ @ $cellToStringDebug, Internal`StuffBag[ $fasterCellToStringFailBag, HoldComplete @ a ] ];
    If[ TrueQ @ $catchingStringFail, Throw[ $Failed, $stringFail ], "" ]
);

$fasterCellToStringFailBag := $fasterCellToStringFailBag = Internal`Bag[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*slowCellToString*)
slowCellToString // SetFallthroughError;

slowCellToString[ cell_ ] :=
    Module[ { plain, string },
        plain = Quiet @ UsingFrontEnd @ FrontEndExecute @ FrontEnd`ExportPacket[ cell, "PlainText" ];
        string = Replace[ plain, { { s_String? StringQ, ___ } :> s, ___ :> $Failed } ];
        StringTrim @ string /; StringQ @ string
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Additional Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stringToBoxes*)
stringToBoxes[ s_String /; StringMatchQ[ s, "\"" ~~ __ ~~ "\"" ] ] :=
    With[ { str = stringToBoxes @ StringTrim[ s, "\"" ] }, "\""<>str<>"\"" /; StringQ @ str ];

stringToBoxes[ string_String ] :=
    stringToBoxes[
        string,
        (* TODO: there could be a kernel implementation of this *)
        Quiet @ UsingFrontEnd @ MathLink`CallFrontEnd @ FrontEnd`UndocumentedTestFEParserPacket[ string, True ]
    ];

stringToBoxes[ string_, { BoxData[ boxes_ ], ___ } ] := boxes;
stringToBoxes[ string_, other_ ] := string;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeGraphicsString*)
makeGraphicsString // SetFallthroughError;

makeGraphicsString[ gfx_ ] := makeGraphicsString[ gfx, makeGraphicsExpression @ gfx ];

makeGraphicsString[ gfx_, HoldComplete[ expr: _Graphics|_Graphics3D|_Image|_Image3D|_Graph ] ] :=
    StringReplace[
        ToString[ Unevaluated @ expr, InputForm, PageWidth -> 100, CharacterEncoding -> "UTF8" ],
        "\r\n" -> "\n"
    ];

makeGraphicsString[
    GraphicsBox[
        NamespaceBox[ "NetworkGraphics", DynamicModuleBox[ { ___, _ = HoldComplete @ Graph[ a___ ], ___ }, ___ ] ],
        ___
    ],
    _
] := "Graph[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ GraphicsBox[ a___ ], _ ] :=
    "Graphics[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ Graphics3DBox[ a___ ], _ ] :=
    "Graphics3D[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ RasterBox[ a___ ], _ ] :=
    "Image[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ Raster3DBox[ a___ ], _ ] :=
    "Image3D[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeGraphicsExpression*)
makeGraphicsExpression[ gfx_ ] := Quiet @ Check[ ToExpression[ gfx, StandardForm, HoldComplete ], $Failed ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sowMessageData*)
sowMessageData[ { _, _, _, _, line_Integer, counter_Integer, session_Integer, _ } ] :=
    With[ { stack = MessageMenu`MessageStackList[ line, counter, session ] },
        Sow[ stack, $messageStack ] /; MatchQ[ stack, { __HoldForm } ]
    ];

sowMessageData[ ___ ] := Null;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showStringCharactersQ*)

(* This would normally give False for things like output cells, but the LLM needs to see the difference between symbols
   and strings. However, there might be cases in the future where we want to change this behavior, so this is left in
   as a stub definition for now. *)
showStringCharactersQ[ ___ ] := True;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*docSearchResultString*)
docSearchResultString // SetFallthroughError; (* FIXME: define this *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
