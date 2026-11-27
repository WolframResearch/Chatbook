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

exactBody[ Cell[ text_String, ___, $$plainStringStyle, ___ ] ] := If[ unwritableTextQ @ text, rawBoxes @ text, text ];

exactBody[ Cell[ content_, ___ ] ] := rawBoxes @ content;
exactBody // endDefinition;

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
(*Raw Boxes and URIs*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rawBoxes*)
rawBoxes // beginDefinition;

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
        "<RawBoxes>" <> text <> "</RawBoxes>"
    ];

rawBoxes // endDefinition;

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
