(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Serialization`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ErrorUtils`" ];

(* The body of a cell with "PreserveBoxes" (exactBody): the text that cellsFromString turns back into the content it was
   made from (see docs/cell-syntax.md). It is not made with boxToString. Code is the tokens of the boxes and text is a
   few forms of markdown, and everything else is written as <RawBoxes> or as an expression URI, so nothing is lost.
   Serialization.wl loads this file and then CellsFromString.wl, the writer of the syntax. The two share its private
   context and the configuration below. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* While the text of an exact body is made (see exactText): the boxes that each piece of markdown stands for so far *)
$cellPieces = <| |>;

(* The keys of the URIs that exact bodies made in $attachments, oldest first, with the bytes of their boxes. The oldest
   are dropped from $attachments beyond these limits, so that reading large notebooks does not keep them all. *)
$notebookAttachments        = <| |>;
$maxNotebookAttachments     = 200;
$maxNotebookAttachmentBytes = 2*^8;

(* Boxes that are longer than this as <RawBoxes> are written as an expression URI *)
$maxRawBoxesLength = 2000;

(* Styles of cells that hold code. A string in a cell of one of these styles (or in a Program or ExternalLanguage cell)
   is not markdown, so its exact body is the string as it is *)
$codeCellStyles    = { "Input", "Code", "Output", "Print", "Echo", "Message", "MSG" };
$$plainStringStyle = Alternatives @@ Join[ $codeCellStyles, { "Program", "ExternalLanguage" } ];

(* The start of a tag of the cell syntax (and what follows its "<"). Text that could be read as a tag is escaped in
   exact bodies *)
$$cellSyntaxTagName = ("/" | "") ~~ ("cell" | "RawBoxes" | "MakeBoxes" | "ToBoxes" | "selection");
$$cellSyntaxTag     = "<" ~~ $$cellSyntaxTagName;

(* Control characters: all but tab and line feed. A carriage return is one, since the line breaks of the syntax are
   line feeds. Exact bodies write them in <RawBoxes>, and cellsFromString refuses them. *)
$controlCharacters = "\\x00-\\x08\\x0b-\\x1f\\x7f";

(* Characters that can't be written in the text of an exact body: control characters and the characters of linear
   syntax *)
$$unwritableCharacter = RegularExpression[ "[" <> $controlCharacters <> "\\x{F7C0}-\\x{F7CD}]" ];

(* Linear syntax: its characters, and how it is typed after a backslash that is not itself escaped (the opener \!\( and
   the escapes of its characters). The front end reads it as boxes in the text of boxes, so it is not written in an
   exact body and cellsFromString refuses it. A \! without \( opens nothing (the thin space of LaTeX).
   In code and in boxes \* is linear syntax too. In markdown it is the escape of an asterisk. *)
$backslash           = "(?<!\\\\)(?:\\\\\\\\)*\\\\";
$linearSyntaxInText  = "[\\x{F7C0}-\\x{F7CD}]|" <> $backslash <> "(?:!\\\\\\(|:[fF]7[cC][0-9a-dA-D]|\\|00[fF]7[cC][0-9a-dA-D]";
$$linearSyntax       = RegularExpression[ $linearSyntaxInText <> "|\\*)" ];

(* A \! alone is the start of linear syntax in a token of code, since its \( can be the next token *)
$$linearSyntaxStart = RegularExpression[ $backslash <> "!" ];

(* The options of bold, italic and struck through text, as cellsFromString writes them and in the other forms that the
   front end has for them *)
$emphasisOptions = { FontWeight -> Bold, FontSlant -> Italic, FontVariations -> { "StrikeThrough" -> True } };

$$emphasisOption = Alternatives @@ Append[
    $emphasisOptions /. { Bold -> Bold | "Bold", Italic -> Italic | "Italic" },
    StripOnInput -> False
];

(* Characters in the private use area are written as long names in exact bodies *)
$$privateUseCharacter = RegularExpression[ "[\\x{E000}-\\x{F8FF}]" ];
$$longName            = RegularExpression[ "\\\\\\[\\w+\\]|\\\\:[0-9a-fA-F]{4}" ];

(* Operator characters that are written in ASCII in exact code *)
$operatorASCIIForms = <|
    "\[Rule]"               -> "->",
    "\[RuleDelayed]"        -> ":>",
    "\[Equal]"              -> "==",
    "\[NotEqual]"           -> "!=",
    "\[LessEqual]"          -> "<=",
    "\[GreaterEqual]"       -> ">=",
    "\[Function]"           -> "|->",
    "\[TwoWayRule]"         -> "<->",
    "\[LeftDoubleBracket]"  -> "[[",
    "\[RightDoubleBracket]" -> "]]",
    "\[LeftAssociation]"    -> "<|",
    "\[RightAssociation]"   -> "|>"
|>;

(* How many brackets a token of exact code opens, which gives the indentation after a \[IndentingNewLine] *)
$bracketDepth = <|
    "[" -> 1, "{" -> 1, "(" -> 1, "<|" -> 1, "[[" -> 2, "]" -> -1, "}" -> -1, ")" -> -1, "|>" -> -1, "]]" -> -2
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exact Bodies*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exactBody*)
exactBody // beginDefinition;
(* Tokens are checked one by one, but two of them can make a cell tag together ("<<" before "cell"). Then the code
   is written as boxes: *)
exactBody[ cell: Cell[ BoxData[ boxes_, ___ ], ___, $$plainStringStyle, ___ ] ] :=
    With[ { code = exactCode[ boxes, MemberQ[ cell, "Code" ] ] },
        If[ StringContainsQ[ code, $$cellTagStart, IgnoreCase -> True ], rawBoxes @ boxes, code ]
    ];

(* Boxes in a cell of text (a DisplayFormula, a table) are written as the inline cell that they would be in text: *)
exactBody[ Cell[ BoxData[ boxes_, ___ ], args___ ] ] :=
    exactText @ { Cell[ BoxData @ boxes, Sequence @@ Cases[ { args }, "TextTableForm" ] ] };

exactBody[ Cell[ text_String, ___, $$plainStringStyle, ___ ] ] := If[ unwritableTextQ @ text, rawBoxes @ text, text ];

exactBody[ Cell[ text_String, args___ ] ] := textBody[ { text }, { args } ];

(* The ExpressionUUID of an inline cell says nothing, and it would make every inline cell different from the next one
   that reads the same (see recordOriginal): *)
exactBody[ Cell[ TextData[ text_, ___ ], args___ ] ] :=
    textBody[ DeleteCases[ Flatten @ { text }, ExpressionUUID -> _, Infinity ], { args } ];

exactBody[ Cell[ content_, ___ ] ] := rawBoxes @ content;
exactBody // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*textBody*)
textBody // beginDefinition;

(* cellsFromString drops what bodyMarker finds at the start of a body. Text of the cell that starts that way has its
   first character as an entity, which is not a marker. (Most text starts with nothing that a marker starts with.) *)
textBody[ items_List, args_List ] :=
    With[ { body = exactText @ items },
        If[ StringStartsQ[ body, "#" | "-" | "*" | DigitCharacter ] && StringStartsQ[ body, bodyMarker @ args ],
            "&#" <> ToString @ First @ ToCharacterCode @ body <> ";" <> StringDrop[ body, 1 ],
            body
        ]
    ];

textBody // endDefinition;


$$listItemStyle = Alternatives[
    $$itemStyle, $$subItemStyle, $$subSubItemStyle, "ItemNumbered", "SubitemNumbered", "SubsubitemNumbered"
];

bodyMarker // beginDefinition;

(* What models write at the start of the body of a heading or of an item, as the default markdown has it, although
   the cell tag says it already. The argument is the styles and options of the cell. *)
bodyMarker[ { ___, $$headingStyle, ___ } ] := RegularExpression[ "#{1,6} +" ];
bodyMarker[ { ___, $$listItemStyle, ___ } ] := RegularExpression[ "(?:[*-]|\\d+\\.) +" ];
bodyMarker[ _List ] := RegularExpression[ "(?!)" ];

bodyMarker // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Code*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*exactCode*)
exactCode // beginDefinition;

(* Writes the pieces of the code in order:
   - A space goes on both sides of an infix operator and after a comma, but not at the start or the end of a line
     (gap is the space that is owed before the next piece of the line).
   - The cell's own spaces next to an infix operator or after a comma are left out, in whatever RowBox they are.
   - Code with spacing of its own (own, see ownSpacingQ) has neither: every token and space is written as it is.
   - A line after a \[IndentingNewLine] is indented by four spaces for each bracket that is open, not counting one that
     the line starts by closing.
   - A space goes between two tokens that would not read as the same two tokens without it (last is the token that
     was written just before, if nothing was written since). *)
exactCode[ boxes_, code_: False ] :=
    Module[ { pieces, count, own, depth, start, gap, last, next, write, token },
        pieces = Flatten @ { codePieces @ boxes };
        count  = Length @ pieces;
        own    = code || ownSpacingQ @ pieces;
        depth  = 0;
        start  = True;
        gap    = "";
        last   = None;

        write[ text_, after_ ] := With[ { written = { gap, text } }, gap = after; start = False; last = None; written ];

        token[ text_ ] :=
            With[ { written = write[ { If[ gap === "" && joinedQ[ last, text ], " ", "" ], text }, "" ] },
                last = text;
                written
            ];

        StringJoin @ Table[
            next = If[ i < count, pieces[[ i + 1 ]], None ];
            Replace[
                pieces[[ i ]],
                {
                    codeNewline         :> (start = True; gap = ""; last = None; "\n"),
                    codeIndent          :> (
                        start = True;
                        gap = "";
                        last = None;
                        { "\n", ConstantArray[ "    ", indentDepth[ depth, next ] ] }
                    ),
                    codeComma           :> write[ ",", If[ own, "", " " ] ],
                    codeOperator[ op_ ] :> If[ own, token @ op, write[ { If[ start, "", " " ], op }, " " ] ],
                    codeToken[ text_, ___ ] /; ! own && ownSpaceQ[ text, gap, next ] :> "",
                    (* A bracket joins nothing: *)
                    codeToken[ text_, ___ ] /; KeyExistsQ[ $bracketDepth, text ] :>
                        (depth += $bracketDepth @ text; write[ text, "" ]),
                    codeToken[ text_, ___ ] :> token @ text,
                    text_               :> write[ text, "" ]
                }
            ],
            { i, count }
        ]
    ];

exactCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ownSpaceQ*)
ownSpaceQ // beginDefinition;

(* True for a space token of the cell where a space is written anyway: after an infix operator or a comma (where a
   space is owed) and before an infix operator *)
ownSpaceQ[ token_String, gap_, next_ ] :=
    (gap === " " || MatchQ[ next, _codeOperator ]) && StringMatchQ[ token, " ".. ];

ownSpaceQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ownSpacingQ*)
ownSpacingQ // beginDefinition;

(* True for code whose spaces are content, which is read and written with exactly the spaces that it has: a Code cell,
   where the front end adds no spacing, and code that has a space token where reading would write a space (next to an
   infix operator or after a comma). cellsFromString asks this of the cell that it writes to. *)
ownSpacingQ[ pieces_List ] := Or[
    MatchQ[ pieces, { ___, codeComma | _codeOperator, codeToken[ space_ ], ___ } /; StringMatchQ[ space, " ".. ] ],
    MatchQ[ pieces, { ___, codeToken[ space_ ], _codeOperator, ___ } /; StringMatchQ[ space, " ".. ] ]
];

ownSpacingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*indentDepth*)
indentDepth // beginDefinition;
indentDepth[ depth_, codeToken[ token_, ___ ] ] := Max[ 0, depth + Min[ 0, Lookup[ $bracketDepth, token, 0 ] ] ];
indentDepth[ depth_, _ ] := Max[ 0, depth ];
indentDepth // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*joinedQ*)
joinedQ // beginDefinition;

(* True for two tokens that do not read as the same two tokens when they are written without a space between them:
   a x, 1 2, x_ ., % 2, # 1, n! !, f& &. CodeParser reads them written together, which makes no symbols: they are
   joined if a token, or a form that it makes of adjacent tokens (%2, #1, x_y), covers the place where they meet.
   A space joins nothing, and neither does a string (exactCode does not ask for brackets and commas). The \( of typed
   linear syntax is not asked about either: CodeParser reads all that follows it as one token, which the tokens of
   the boxes are not. *)
joinedQ[ a_String, b_String ] /; ! StringEndsQ[ a, $$separateToken | "\\(" ] && ! StringStartsQ[ b, $$separateToken ] :=
    With[ { key = { tokenClass @ a, tokenClass @ b } },
        Replace[
            $joinedTokens @ key,
            _Missing :> (
                If[ Length @ $joinedTokens >= $maxJoinedTokens, $joinedTokens = <| |> ];
                $joinedTokens[ key ] = joinedQ @@ Append[ key, StringLength @ First @ key ]
            )
        ]
    ];

joinedQ[ a_String, b_String, length_Integer ] := (
    Needs[ "CodeParser`" -> None ];
    ! FreeQ[
        CodeParser`CodeConcreteParse[ a <> b, "SourceConvention" -> "SourceCharacterIndex" ],
        (CodeParser`LeafNode | CodeParser`CompoundNode | CodeParser`ErrorNode)[
            _,
            _,
            KeyValuePattern[ CodeParser`Source -> { first_, last_ } /; first <= length < last ]
        ]
    ]
);

joinedQ[ _, _ ] := False;

joinedQ // endDefinition;

$$separateToken = " " | "\t" | "\"";

(* The answers for pairs of tokens that were seen. Reading the tokens is slow (0.5 ms), so a word of letters stands
   as "a" and a whole number as "1": every such name joins its neighbors as any other does. *)
$joinedTokens    = <| |>;
$maxJoinedTokens = 2000;


tokenClass // beginDefinition;
tokenClass[ "" ] := "";
tokenClass[ token_String ] := Which[ LetterQ @ token, "a", DigitQ @ token, "1", True, token ];

tokenClass // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*codePieces*)
codePieces // beginDefinition;

(* A comment is written as it is, without the spacing of code. A comment has no escapes, so one with the text of a long
   name in it (and not the character) can't be told from one with the character, and is written as boxes: *)
codePieces[ comment: RowBox @ { "(*", ___, "*)" } ] :=
    Module[ { tokens, text },
        tokens = Flatten[ comment //. RowBox[ boxes_List ] :> boxes ];
        text = If[ AllTrue[ tokens, StringQ ], StringJoin @ tokens, None ];
        If[ StringQ @ text && StringFreeQ[ text, $$longName ] && ! unwritableCodeQ @ text,
            Replace[
                tokens,
                { "\n" -> codeNewline, "\[IndentingNewLine]" -> codeIndent, token_ :> longNames @ token },
                { 1 }
            ],
            rawBoxes @ comment
        ]
    ];

codePieces[ RowBox @ { op: $$unspacedPrefixOperator, box_ } ] := { codeToken @ op, codePieces @ box };
codePieces[ RowBox[ boxes_List ] ] := codePieces /@ boxes;
codePieces[ boxes_List ] := codePieces /@ boxes;

(* Most tokens need nothing done to them, which one test tells. They are written as they are, e.g. a string with its
   escapes or a number with its marks. A token with \! is written as boxes also without the \( that linear syntax opens
   with, since that can be the next token: *)
codePieces[ token_String ] :=
    Lookup[
        $codeTokenPieces,
        token,
        Which[
            StringFreeQ[ token, $$specialCodeCharacter ], codeToken @ token,
            unwritableCodeQ @ token || StringContainsQ[ token, $$linearSyntaxStart ], rawBoxes @ token,
            True, codeToken[ longNames @ token, token ]
        ]
    ];

(* Conversion rules and selections mark text that is not content with Verbatim: *)
codePieces[ Verbatim[ Verbatim ][ marker_String ] ] := marker;
codePieces[ box_ ] := rawBoxes @ box;
codePieces // endDefinition;

(* The pieces of the tokens that are not written as they are: line breaks, commas, infix operators (which get spaces)
   and operator characters (which are written in ASCII) *)
$codeTokenPieces = Association[
    KeyValueMap[ #1 -> codeToken[ #2 ] &, $operatorASCIIForms ],
    # -> codeOperator @ Lookup[ $operatorASCIIForms, #, # ] & /@ List @@ $$spacedInfixOperator,
    "," -> codeComma,
    "\n" -> codeNewline,
    "\[IndentingNewLine]" -> codeIndent
];

(* A token without any of these is written as it is: it has no private use or control character, and nothing that could
   be a tag, a URI or linear syntax *)
$$specialCodeCharacter = RegularExpression[ "[" <> $controlCharacters <> "<\\x{E000}-\\x{F8FF}]|://|\\\\[!*:|]" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*exactText*)
exactText // beginDefinition;

(* Adjacent strings are joined first, since the text can't tell where one ends and the next begins. Bold or italic
   text and a table are written with what is before and after them in mind (see misplacedQ): *)
exactText[ items_List ] :=
    Block[ { $cellPieces = <| |> },
        With[ { joined = joinStrings @ items },
            StringJoin @ If[ FreeQ[ joined, $$starEmphasis | $$tableCell, { 1 } ],
                textPiece /@ joined,
                MapThread[
                    If[ misplacedQ[ #2, #1, #3 ], rawBoxes @ #2, textPiece @ #2 ] &,
                    { Prepend[ Most @ joined, None ], joined, Append[ Rest @ joined, None ] }
                ]
            ]
        ]
    ];

exactText // endDefinition;


joinStrings // beginDefinition;

(* Adjacent strings as one string. The writer joins what it reads the same way. *)
joinStrings[ items_List ] := Replace[
    Split[ items, StringQ @ #1 && StringQ @ #2 & ],
    { { strings__String } :> StringJoin @ strings, { item_ } :> item },
    { 1 }
];

joinStrings // endDefinition;


insideWordQ // beginDefinition;

(* cellsFromString reads asterisks as emphasis only where they are not inside of a word, so that 2*3*4 is text: after
   and before anything but a letter or a digit. Bold or italic text that touches one is written as boxes. *)
insideWordQ[ before_, after_ ] := Or[
    StringQ @ before && StringEndsQ[ before, RegularExpression[ "[A-Za-z0-9]" ] ],
    StringQ @ after && StringStartsQ[ after, RegularExpression[ "[A-Za-z0-9]" ] ]
];

insideWordQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*textPiece*)
(* Bold or italic text that is not struck through, whose markdown starts and ends with an asterisk *)
$$starEmphasis = StyleBox[ _String, Except[ FontVariations -> _, $$emphasisOption ].. ];

$$linkBox = Alternatives[
    ButtonBox[ _, OrderlessPatternSequence[ BaseStyle -> "Link" | "Hyperlink", ButtonData -> _, ___ ] ],
    TemplateBox[ { _, __ }, "HyperlinkURL" | "HyperlinkDefault" | "HyperlinkTemplate" | $$refLinkTemplate, ___ ]
];

(* A link that can be found again without knowing where its label ends. A backslash in the label escapes the character
   after it, as in plain text. The address can hold parentheses in pairs: *)
$$linkAddress  = Except[ "(" | ")" | WhitespaceCharacter ];
$$markdownLink = StringExpression[
    "[",
    (("\\" ~~ _) | Except[ "[" | "]" | "\n" | "\\" ])..,
    "](",
    ($$linkAddress | ("(" ~~ $$linkAddress... ~~ ")"))..,
    ")"
];

textGridQ // beginDefinition;

(* True for a grid whose entries are all plain text on one line, also in the TagBoxes that Grid, TableForm and Column
   put around it. Not handled: entries that are text in other boxes (the RowBox of a negative number). *)
textGridQ[ TagBox[ grid_, ___ ] ] := textGridQ @ grid;

textGridQ[ GridBox[ rows_? MatrixQ, ___ ] ] :=
    AllTrue[ Flatten @ rows, MatchQ[ text_String | TagBox[ text_String, HoldForm ] /; StringFreeQ[ text, "\n" ] ] ];

textGridQ[ _ ] := False;

textGridQ // endDefinition;

(* An inline cell that is written as a markdown table: the table that the chat formatter makes, and a grid of plain
   text in a cell without a style of its own *)
$$tableCell = Cell[ _BoxData, "TextTableForm", ___ ] | Cell[ BoxData[ _? textGridQ, ___ ], ___? OptionQ ];

misplacedQ // beginDefinition;

(* True for an item whose markdown cellsFromString would not find again between the items before and after it, so
   that it is written as boxes: bold or italic text that touches a word, and a table that is not on lines of its own
   (its last row would run on into the text after it). *)
misplacedQ[ $$starEmphasis, before_, after_ ] := insideWordQ[ before, after ];

misplacedQ[ $$tableCell, before_, after_ ] := ! And[
    before === None || StringQ @ before && StringEndsQ[ before, "\n" ],
    after === None || StringQ @ after && StringStartsQ[ after, "\n" ]
];

misplacedQ[ _, _, _ ] := False;

misplacedQ // endDefinition;

textPiece // beginDefinition;

(* Plain text. The part of a string from its first to its last character that can't be written is a string in
   <RawBoxes>: *)
textPiece[ text_String ] := StringJoin @ Replace[
    StringSplit[ text, raw: ($$unwritableCharacter ~~ ___ ~~ $$unwritableCharacter) | $$unwritableCharacter :> { raw } ],
    { { raw_ } :> rawBoxes @ raw, plain_ :> escapeText @ plain },
    { 1 }
];

textPiece[ Verbatim[ Verbatim ][ marker_String ] ] := marker;

(* Bold, italic and struck through: *)
textPiece[ box: StyleBox[ text_String, style: $$emphasisOption.. ] ] :=
    With[ { marker = emphasisMarker @ { style } },
        recordedMarkdown[ marker <> escapeText @ text <> StringReverse @ marker, box ] /;
            marker =!= "" && emphasisTextQ[ text, marker ]
    ];

(* Links: *)
textPiece[ box: (link: $$linkBox) | Cell[ BoxData[ link: $$linkBox, ___ ], ___ ] ] :=
    With[ { markdown = linkMarkdown @ link },
        recordedMarkdown[ markdown, box ] /;
            StringQ @ markdown && StringMatchQ[ markdown, $$markdownLink ] && ! unwritableCodeQ @ markdown
    ];

(* Math, in an inline cell without a style of its own: *)
textPiece[ box: Cell[ BoxData[ FormBox[ formula_, TraditionalForm, ___ ], ___ ], ___? OptionQ ] ] :=
    With[ { tex = formulaTeX @ formula },
        recordedMarkdown[ "$$" <> tex <> "$$", box ] /; StringQ @ tex && formulaTeXQ @ tex
    ];

(* Tables that the chat formatter made: *)
textPiece[ box: Cell[ _BoxData, "TextTableForm", ___ ] ] :=
    With[ { table = Block[ { $cellPageWidth = Infinity, $maxCellStringLength = Infinity }, boxToString @ box ] },
        recordedMarkdown[ longNames @ table, box ] /; StringQ @ table && StringStartsQ[ table, "|" ] && ! unwritableCodeQ @ table
    ];

(* A grid of plain text is the table of the default markdown, also if it has one row or one column. It has to be a
   table that cellsFromString reads as one, with a row of dashes (a grid of empty strings has none): *)
textPiece[ box: Cell[ BoxData[ grid_? textGridQ, ___ ], ___? OptionQ ] ] :=
    With[
        {
            table = Block[ { $cellPageWidth = Infinity, $maxCellStringLength = Infinity, $simplifyTables = False },
                boxToString @ Cell[ BoxData @ grid, "TextTableForm" ]
            ]
        },
        recordedMarkdown[ longNames @ table, box ] /; And[
            StringQ @ table,
            StringMatchQ[ table, RegularExpression[ "\\|[^\\n]*\\n\\|[ :|-]*-[ :|-]*\\|(?:\\n\\|[^\\n]*)+" ] ],
            ! unwritableCodeQ @ table
        ]
    ];

(* Inline code: *)
textPiece[ box: _Cell | _StyleBox | _TemplateBox ] :=
    With[ { code = inlineCode @ box },
        recordedMarkdown[ "``" <> code <> "``", box ] /; StringQ @ code && inlineCodeQ @ code
    ];

textPiece[ box_ ] := rawBoxes @ box;

textPiece // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*linkMarkdown*)
linkMarkdown // beginDefinition;

(* The link of the default markdown, which trims the label. The spaces at the ends of the label are put back: *)
linkMarkdown[ link: ButtonBox[ label_, ___ ] | TemplateBox[ { label_, ___ }, ___ ] ] :=
    Replace[
        Block[ { $escapeMarkdown = True }, boxToString @ link ],
        markdown_String :> longNames @ StringReplace[
            markdown,
            StartOfString ~~ "[" ~~ text__ ~~ "](" ~~ url__ ~~ EndOfString :>
                "[" <> labelSpaces[ label, StartOfString ~~ " ".. ] <> text <> labelSpaces[ label, " ".. ~~ EndOfString ] <> "](" <> url
        ]
    ];

linkMarkdown // endDefinition;


labelSpaces // beginDefinition;
labelSpaces[ label_String, spaces_ ] /; ! StringMatchQ[ label, " "... ] := StringJoin @ StringCases[ label, spaces ];
labelSpaces[ _, _ ] := "";
labelSpaces // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*escapeText*)
escapeText // beginDefinition;

(* Escapes what would be read as markdown, as one of the tags of the cell syntax, or as an HTML entity. Brackets are
   not escaped: a "\[" would look like the start of a long name, and a "[" can only start a link with a "](" after
   it. An underscore only marks emphasis next to a word boundary. *)
escapeText[ text_String ] := StringReplace[
    text,
    {
        "\\" -> "\\\\",
        char: "`" | "$" | "*" | "|" :> "\\" <> char,
        "](" -> "\\](",
        tildes: Repeated[ "~", { 2, Infinity } ] :> StringReplace[ tildes, "~" -> "\\~" ],
        (WordBoundary ~~ underscores: "_"..) | (underscores: "_".. ~~ WordBoundary) :>
            StringReplace[ underscores, "_" -> "\\_" ],
        "<" ~~ tag: ("!" | $$cellSyntaxTagName) :> "&lt;" <> tag,
        "&" ~~ entity: (("#" ~~ (("x" ~~ HexadecimalCharacter..) | DigitCharacter..)) | WordCharacter..) ~~ ";" :>
            "&amp;" <> entity <> ";",
        char: $$privateUseCharacter :> longName @ char
    },
    IgnoreCase -> True
];

escapeText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*emphasisMarker*)
emphasisMarker // beginDefinition;

emphasisMarker[ style_List ] := StringJoin[
    If[ MemberQ[ style, FontVariations -> _ ], "~~", "" ],
    If[ MemberQ[ style, FontWeight -> _ ], "**", "" ],
    If[ MemberQ[ style, FontSlant -> _ ], "*", "" ]
];

emphasisMarker // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*emphasisTextQ*)
emphasisTextQ // beginDefinition;

(* Emphasis opens before and closes after a character that is not white space (2 * 3 * 4 is text). It ends at the next
   marker, so struck through text can't hold a "~" (there is no escape for it alone): *)
emphasisTextQ[ text_String, marker_String ] := And[
    StringFreeQ[ text, "\n" | $$unwritableCharacter | If[ StringStartsQ[ marker, "~" ], "~", "\n" ] ],
    StringMatchQ[ text, Except[ WhitespaceCharacter ] | (Except[ WhitespaceCharacter ] ~~ ___ ~~ Except[ WhitespaceCharacter ]) ]
];

emphasisTextQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formulaTeX*)
formulaTeX // beginDefinition;

(* The input of the TeX input assistant can be in dollars of its own ("$n$"), which are not part of the formula. The
   original is recorded, so the formula is written back with them: *)
formulaTeX[ TemplateBox[ KeyValuePattern[ "input" -> tex_String ], "TeXAssistantTemplate", ___ ] ] :=
    StringReplace[ tex, RegularExpression[ "(?s)\\A(\\$\\$?)([^$]+)\\1\\z" ] :> "$2" ];

(* A formula of layout boxes alone is converted. This converter also works without a front end, unlike exporting to
   "TeXFragment": *)
formulaTeX[ boxes_ ] /; FreeQ[ boxes, _TemplateBox | _TagBox | _InterpretationBox | _ButtonBox | $$uriBox ] :=
    Quiet @ Check[ Convert`TeX`BoxesToTeX @ boxes, None ];

formulaTeX[ _ ] := None;

formulaTeX // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formulaTeXQ*)
formulaTeXQ // beginDefinition;

(* The formula ends at the next "$$", so the LaTeX can't hold one, or make one with the dollar signs around it: *)
formulaTeXQ[ tex_String ] := And[
    tex =!= "",
    StringFreeQ[ tex, "$$" | $$privateUseCharacter ],
    ! StringStartsQ[ tex, "$" ],
    ! StringEndsQ[ tex, "$" ],
    ! unwritableCodeQ @ tex
];

formulaTeXQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineCode*)
inlineCode // beginDefinition;
inlineCode[ StyleBox[ code_String, "TI" | "InlineCode" ] ] := code;
inlineCode[ Cell[ code_, "InlineCode" | "InlineFormula", ___ ] ] := inlineCodeText @ code;
inlineCode[ Cell[ BoxData[ template_TemplateBox, ___ ], ___ ] ] := inlineCode @ template;
inlineCode[ TemplateBox[ { Cell[ code_, ___ ] | code_ }, "ChatCodeInlineTemplate", ___ ] ] := inlineCodeText @ code;
inlineCode[ _ ] := None;
inlineCode // endDefinition;


inlineCodeText // beginDefinition;
inlineCodeText[ code_String ] := code;

(* Only tokens are tried, and nothing is recorded for them: with anything else the inline cell is written as boxes *)
inlineCodeText[ BoxData[ boxes_? codeTokensQ, ___ ] ] := Block[ { $cellOriginals = None }, exactCode @ boxes ];
inlineCodeText[ _ ] := None;
inlineCodeText // endDefinition;


codeTokensQ // beginDefinition;
codeTokensQ[ _String ] := True;
codeTokensQ[ RowBox[ boxes_List ] ] := AllTrue[ boxes, codeTokensQ ];
codeTokensQ[ _ ] := False;
codeTokensQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineCodeQ*)
inlineCodeQ // beginDefinition;

(* Nothing is escaped between the double backticks, so the code can't hold what would end it or be read as more than
   code: *)
inlineCodeQ[ code_String ] := And[
    code =!= "",
    StringFreeQ[ code, "``" | "\n" | $$privateUseCharacter ],
    ! StringStartsQ[ code, "`" ],
    ! StringEndsQ[ code, "`" ],
    ! unwritableCodeQ @ code
];

inlineCodeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*recordedMarkdown*)
recordedMarkdown // beginDefinition;

(* The markdown of a piece, with its boxes recorded. Markdown that already stands for other boxes in the cell (a
   formula typed as "n" and one typed as "$n$") can't stand for these too, so they are written as boxes: *)
recordedMarkdown[ markdown_String, box_ ] :=
    If[ Lookup[ $cellPieces, markdown, box ] === box,
        $cellPieces[ markdown ] = box;
        recordOriginal[ markdown, box ];
        markdown,
        rawBoxes @ box
    ];

recordedMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Raw Boxes and URIs*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rawBoxes*)
rawBoxes // beginDefinition;

(* LeafCount is checked first, since it is a lower bound of the length that needs no string: *)
rawBoxes[ boxes_ ] /; ! FreeQ[ boxes, $$uriBox ] || LeafCount @ boxes > $maxRawBoxesLength :=
    boxesURI @ boxes;

(* Text that looks like a tag or a URI can only be inside of a string here, where it can be written with an escape, so
   that nothing between the tags reads as either: *)
rawBoxes[ boxes_ ] :=
    With[
        {
            text = StringReplace[
                inputFormLine @ boxes,
                { "<" ~~ tag: $$cellSyntaxTagName :> "\\.3c" <> tag, "://content-" -> ":\\.2f/content-" },
                IgnoreCase -> True
            ]
        },
        If[ StringLength @ text > $maxRawBoxesLength,
            boxesURI @ boxes,
            recordOriginal[ text, boxes ];
            "<RawBoxes>" <> text <> "</RawBoxes>"
        ]
    ];

rawBoxes // endDefinition;

(* Graphics and dynamic boxes are always written as a URI: *)
$$uriBox = Alternatives[
    _GraphicsBox, _Graphics3DBox, _RasterBox, _Raster3DBox, _DynamicBox, _DynamicModuleBox, _DynamicWrapperBox, _Dynamic
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*boxesURI*)
boxesURI // beginDefinition;

(* The URI stands for the boxes themselves in $attachments, from which cellsFromString writes them back. They are stored
   as they are and not interpreted. A graphic (image: boxes that graphicsQ finds a graphic in, and
   what a lossy body takes for one) is the image link ![Image](attachment://...), in the form that is made an image
   for multimodal chats. The key is moved to the end of $notebookAttachments, and the oldest keys are dropped from
   $attachments beyond the limits (the newest one is always kept). A key that something else also made is dropped with
   them, which is not worth telling apart. *)
boxesURI[ boxes_ ] := boxesURI[ boxes, graphicsQ @ RawBoxes @ boxes ];

boxesURI[ boxes_, image_ ] :=
    Module[ { uri, key },
        uri = If[ TrueQ @ image,
                  MakeExpressionURI[ "Image", RawBoxes @ StyleBox[ boxes, "GraphicsRawBoxes" ] ],
                  MakeExpressionURI[ ToString @ Head @ boxes, RawBoxes @ boxes ]
              ];
        key = First @ StringCases[ uri, "://" ~~ k: Except[ ")" ].. ~~ ")" ~~ EndOfString :> k ];
        KeyDropFrom[ $notebookAttachments, key ];
        $notebookAttachments[ key ] = ByteCount @ boxes;
        While[
            And[
                Length @ $notebookAttachments > 1,
                Or[
                    Length @ $notebookAttachments > $maxNotebookAttachments,
                    Total @ $notebookAttachments > $maxNotebookAttachmentBytes
                ]
            ],
            KeyDropFrom[ $attachments, First @ Keys @ $notebookAttachments ];
            $notebookAttachments = Rest @ $notebookAttachments
        ];
        uri
    ];

boxesURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*recordOriginal*)
recordOriginal // beginDefinition;

(* Nothing is recorded for a cell without an id: *)
recordOriginal[ text_String, boxes_ ] /; AssociationQ @ $cellOriginals && StringQ @ $cellOriginalsKey :=
    With[ { key = $cellOriginalsKey },
        If[ ! KeyExistsQ[ $cellOriginals, key ], $cellOriginals[ key ] = <| |> ];
        $cellOriginals[[ Key @ key, Key @ text ]] = boxes
    ];

recordOriginal[ _String, _ ] := Null;

recordOriginal // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unwritableTextQ*)
unwritableTextQ // beginDefinition;

(* True for text that has no place in code or in a plain string: something that reads as a tag or a URI of the cell
   syntax, or a character that can't be written *)
unwritableTextQ[ text_String ] :=
    StringContainsQ[ text, $$cellSyntaxTag | $$unwritableCharacter | $$attachmentURI, IgnoreCase -> True ];

unwritableTextQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unwritableCodeQ*)
unwritableCodeQ // beginDefinition;

(* True for text that has no place in a token of code or in a piece of markdown: what unwritableTextQ finds, and linear
   syntax as it is typed *)
unwritableCodeQ[ text_String ] := unwritableTextQ @ text || StringContainsQ[ text, $$linearSyntax ];

unwritableCodeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*longNames*)
longNames // beginDefinition;
longNames[ text_String ] := StringReplace[ text, char: $$privateUseCharacter :> longName @ char ];
longNames // endDefinition;


longName // beginDefinition;

(* The long name of a character, or \:xxxx if it has none (kept for each of the private use characters that is seen): *)
longName[ char_String ] := longName[ char ] =
    StringTake[ ToString[ char, InputForm, CharacterEncoding -> "PrintableASCII" ], { 2, -2 } ];

longName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inputFormLine*)
inputFormLine // beginDefinition;

(* InputForm on one line in printable ASCII, with every symbol outside of System` written with its context: *)
inputFormLine[ expr_ ] :=
    Block[ { $Context = "System`", $ContextPath = { "System`" } },
        ToString[ Unevaluated @ expr, InputForm, PageWidth -> Infinity, CharacterEncoding -> "PrintableASCII" ]
    ];

inputFormLine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
