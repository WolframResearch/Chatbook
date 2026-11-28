(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Serialization`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ErrorUtils`" ];

(* Reads text in the cell syntax of docs/cell-syntax.md, which CellToString writes with "IncludeXML" and
   "PreserveBoxes" (cellsFromString). Nothing is written to a notebook, and no code of the text is run, except for the
   <MakeBoxes> and <ToBoxes> tags, which are given to the kernel of the evaluator tool.
   Serialization.wl loads this file after ExactBodies.wl, the reader of the bodies. The two share its private context,
   so the writer uses what the reader defines. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* Seconds that the evaluation of one <MakeBoxes> or <ToBoxes> tag may take *)
$cellTagSeconds = 30;

(* Characters of the model's text that a message repeats *)
$maxQuotedLength = 80;

(* A symbol that the kernel reads from <RawBoxes> or options and that the scan before it did not see is made in this
   context, where it is refused, and not in a context of the user *)
$dataContext = "Wolfram`Chatbook`CellSyntax`Data`";

(* The state of a call. These variables only have values inside of the Block that sets them.
   Set by cellsFromString, for the whole text:
     $cells               "Cells": the existing cell of an id, as an association or a function
     $originals           "Originals": what CellToString recorded, <| id -> <| text -> boxes |> |>
     $sharedOriginals     the records of all cells as one (see sharedOriginals), made when they are first asked for
     $extraAttributes     "ExtraAttributes": the names of the attributes of the caller's own
     $tagCount            the number of cell tags that were read so far
   Set by blockCells, for one cell tag:
     $cellID              the id of the cell that is being written, whose own originals are looked up first
     $cellName            what a message calls the cell that it is about (it has a value outside of a tag too)
   Set by tagCell, while the content of a cell is made:
     $existingCell        the cell that the tag names, whose own templates a body can hold (None for a new cell)
   A refusal is thrown to $refused, which cellsFromString and evaluateToBoxes catch. *)
$cellName = "The text";

$tagAttributes = "((?:\\s+[A-Za-z]+=(?:'[^']*'|\"[^\"]*\"))*)";

$$selectionMarker = "<selection>" | "</selection>";

(* What the text is split by. A cell tag is read wherever it starts outside of a body, so tags can follow one another
   on a line.
   - A cell tag without a body, which only changes attributes.
   - A cell tag with a body. The body ends at the first </cell>, wherever that is: CellToString writes none in a body.
     The line breaks around a body are not part of it. *)
$blockRules = {
    RegularExpression[ "(?i)<cell" <> $tagAttributes <> "\\s*/>" ] :> cellTag[ "$1", None ],
    RegularExpression[ "(?i)<cell" <> $tagAttributes <> "\\s*>\\n?((?s:.*?))\\n?</cell>" ] :> cellTag[ "$1", "$2" ]
};

(* What the rules above leave between the cell tags: a cell tag that they did not read, and a closing tag *)
$$strayCellTag = RegularExpression[ "(?i)<cell[\\s>/]" ];
$$strayCellEnd = RegularExpression[ "(?i)</cell>" ];

(* A line of a body that starts with a cell tag: the tag of the body was not closed *)
$$cellTagLine = RegularExpression[ "(?mi)^<cell[\\s>/]" ];

(* A <RawBoxes> tag as a regular expression, in which "$1" is the text between the tags. A tag holds no other tag, so
   that text with many opening tags is not searched to its end from each of them. *)
$rawBoxesTag = "<RawBoxes>((?:(?!</?RawBoxes>).)*+)</RawBoxes>";

(* Boxes that run code when they are shown *)
$$dynamicHead = Alternatives[
    DynamicBox, DynamicModuleBox, DynamicWrapperBox, ActionMenuBox, Dynamic, DynamicModule, DynamicWrapper,
    EventHandlerTag
];

(* Options that make code run without being asked for, by the name that they are written with as a symbol or as a
   string: the ones that hold the code, and InitializationCell *)
$codeOptions = {
    "ButtonFunction", "CellDynamicExpression", "CellEpilog", "CellEvaluationFunction", "CellEventActions",
    "CellProlog", "ComponentwiseContextMenu", "ContextMenu", "Deinitialization", "Initialization",
    "InitializationCell", "NotebookDynamicExpression", "NotebookEventActions"
};

$$codeOption = (Rule | RuleDelayed)[ _? codeOptionQ, _ ];

(* The heads of plain data: boxes that typeset, and what their arguments and the values of options are made of. This is
   a list and not a test of names, since UnitBox and CoordinateBoundingBox are functions. Graphics are not plain data.
   A TemplateBox is not either: it shows and does what the stylesheet style of its name says, which for some styles
   is to evaluate or to open something on a click. *)
$$dataHead = Alternatives[
    AdjustmentBox, ButtonBox, ErrorBox, FormBox, FractionBox, FrameBox, GridBox, InterpretationBox, ItemBox,
    OverscriptBox, PaneBox, PanelBox, RadicalBox, RotationBox, RowBox, SqrtBox, StyleBox, SubscriptBox,
    SubsuperscriptBox, SuperscriptBox, TagBox, TooltipBox, UnderoverscriptBox, UnderscriptBox,
    List, Rule, RuleDelayed, Association, RGBColor, GrayLevel, Hue, CMYKColor, LightDarkSwitched, Opacity, Directive,
    URL, Cell, BoxData, TextData, Scaled, Offset, DirectedInfinity
];

(* Arithmetic on numbers and Inherited, as in the values of options (1.5*Inherited, 1/2) *)
$$number     = _Integer | _Real | Inherited;
$$arithmetic = (Times | Plus)[ ($$number | Power[ $$number, -1 ]).. ];

(* Boxes of plain data that act when they are evaluated or clicked: a TagBox whose tag is not a string (the kernel
   reads it as a function of the content), and a button that is not just a hyperlink (other styles and options carry
   functions) *)
$$hyperlinkOptions = OrderlessPatternSequence[
    BaseStyle -> "Hyperlink" | "Link",
    ButtonData -> _String | _URL | { _String | _URL, _ },
    (ButtonNote -> _)...
];

$$actingBox = TagBox[ _, Except[ _String ], ___ ] | Except[ ButtonBox[ _, $$hyperlinkOptions ], _ButtonBox ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Pieces*)

(* The parts of a body that are not typed text: the tags of the syntax and expression URIs. These are in code and in
   text. The names of tags are read without regard to case. *)
$tagPieceRules := $tagPieceRules = {
    RegularExpression[ "(?si)" <> $rawBoxesTag ] :> rawPiece[ "$1" ],
    RegularExpression[ "(?si)<(MakeBoxes|ToBoxes)([^>]*)>(.*?)</\\1>" ] :> evalPiece[ "$1", "$2", "$3" ],
    uri: ("![" ~~ Except[ "]" | "\n" ]... ~~ "](" ~~ $$attachmentURI ~~ ")") :> uriPiece @ uri,
    uri: ("<!" ~~ $$attachmentURI ~~ "!>") :> uriPiece @ uri
};

(* A tag of the syntax that the rules above did not read, since its other tag is missing *)
$$strayTag = RegularExpression[ "(?i)<(/?)(RawBoxes|MakeBoxes|ToBoxes)\\b" ];

(* The pieces of text. A backslash and the character after it are never the start of a piece, except for math.
   - Math is $$...$$, \(...\) or \[...\] (which is not a long name, \[Alpha]).
   - Asterisks are emphasis only where they are not inside of a word: the marker opens after and closes before
     anything but a letter or a digit, with no space on its inside. So 2*3*4 and 2 * 3 * 4 are text. Asterisks that
     open nothing are text as a whole run, so that no emphasis starts in the middle of them. Underscores are read the
     same way (CellToString escapes the ones at the ends of words).
   - Emphasis ends at its first closing marker, as CellToString writes it: "**a***b*" is two pieces. Bold can also
     hold italic, and italic bold, whose markers can touch the outer ones: "**a *b***".
   - An image link is a link: nothing is fetched.
   - A table is a header row and a row of dashes under it: other pipes are text.
   - A single backtick is not part of the syntax, but models write inline code that way. *)
$textPieceRules := $textPieceRules = Flatten @ {
    RegularExpression[ "(?s)\\\\\\((.+?)\\\\\\)" ] :> markdownPiece[ "Math", "$0", "$1" ],
    RegularExpression[ "(?s)\\\\\\[(?!\\w+\\])(.+?)\\\\\\]" ] :> markdownPiece[ "Math", "$0", "$1" ],
    (* The opener of linear syntax stays in the text, where it is refused: *)
    opener: "\\!\\(" :> opener,
    escape: ("\\" ~~ _) :> escape,
    $tagPieceRules,
    RegularExpression[ "``([^\\n]+?)``" ] :> markdownPiece[ "Code", "$0", "$1" ],
    RegularExpression[ "(?s)\\$\\$(.+?)\\$\\$" ] :> markdownPiece[ "Math", "$0", "$1" ],
    RegularExpression[ "~~(?=\\S)((?:\\\\.|[^\\\\\\n~])+?)(?<=\\S)~~" ] :> markdownPiece[ "Emphasis", "$0", "~~", "$1" ],
    RegularExpression[
        "(?<![A-Za-z0-9])(\\*{1,3})(?=\\S)((?:\\\\.|[^\\\\\\n*])+?)(?<=\\S)\\1(?![A-Za-z0-9])"
    ] :> markdownPiece[ "Emphasis", "$0", "$1", "$2" ],
    RegularExpression[
        "(?<![A-Za-z0-9])\\*\\*(?=\\S)((?:\\\\.|[^\\\\\\n*]|\\*(?=[^\\s*])(?:\\\\.|[^\\\\\\n*])+?(?<=\\S)\\*)+?)(?<=\\S)\\*\\*(?![A-Za-z0-9])"
    ] :> markdownPiece[ "Emphasis", "$0", "**", "$1" ],
    RegularExpression[
        "(?<![A-Za-z0-9])\\*(?=\\S)((?:\\\\.|[^\\\\\\n*]|\\*\\*(?=[^\\s*])(?:\\\\.|[^\\\\\\n*])+?(?<=\\S)\\*\\*)+?)(?<=\\S)\\*(?![A-Za-z0-9])"
    ] :> markdownPiece[ "Emphasis", "$0", "*", "$1" ],
    RegularExpression[ "\\*+" ] :> "$0",
    RegularExpression[
        "(?<!\\w)(_{1,3})(?=\\S)((?:\\\\.|[^\\\\\\n_]|(?<=\\w)_(?=\\w))+?)(?<=\\S)\\1(?!\\w)"
    ] :> markdownPiece[ "Emphasis", "$0", "$1", "$2" ],
    "!" ~~ link: $$markdownLink :> markdownPiece[ "Link", link, link ],
    link: $$markdownLink :> markdownPiece[ "Link", link, link ],
    RegularExpression[
        "\\|[^\\n]*\\n[ \\t]*\\|?(?:[ \\t]*:?-+:?[ \\t]*\\|)*[ \\t]*:?-+:?[ \\t]*\\|?[ \\t]*(?![^\\n])(?:\\n[ \\t]*\\|[^\\n]*)*"
    ] :> markdownPiece[ "Table", "$0", "$0" ],
    RegularExpression[ "`([^`\\n]+)`" ] :> markdownPiece[ "Code", "$0", "$1" ]
};

(* What plain text is read as, from left to right: an escape, a long name, an HTML entity *)
$textEscapes := $textEscapes = {
    "\\" ~~ char: ("\\" | "`" | "$" | "*" | "|" | "]" | "~" | "_" | "#") :> char,
    name: $$longName :> longNameCharacter @ name,
    entity: ("&" ~~ ("#" | "") ~~ WordCharacter.. ~~ ";") :> importHTMLEntities @ entity
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*cellsFromString*)
cellsFromString // beginDefinition;
cellsFromString // Options = { "Cells" -> <| |>, "Originals" -> <| |>, "ExtraAttributes" -> { } };

(* Gives a record for each cell tag of the text, in their order, or a Failure with a message for the model:
     <| "ID" -> id | None, "Cell" -> Cell[ ... ] | Missing[ "Unchanged" ],
        "Attributes" -> <| "Styles" -> { ... }, "Options" -> { ... } |>, "Extra" -> <| name -> value, ... |>, "Tag" -> n |>
   - "Cells" gives the existing cell of an id: an association, or a function that gives the Cell or a Missing.
   - "Originals" is what CellToString recorded in $cellOriginals.
   - "ExtraAttributes" are the names of attributes of the caller's own, which a cell tag can then have. They are not
     read here: "Extra" has the ones that the tag gives, with their values.
   - "Tag" is the number of the cell tag in the text, which a message names a new cell by. *)
cellsFromString[ text_String, OptionsPattern[ ] ] :=
    catchAlways @ Block[
        {
            $cells           = OptionValue[ "Cells" ],
            $originals       = Replace[ OptionValue[ "Originals" ], Except[ _Association ] -> <| |> ],
            $sharedOriginals = None,
            $extraAttributes = OptionValue[ "ExtraAttributes" ],
            $tagCount        = 0,
            $cellName        = "The text outside of cell tags"
        },
        Catch[
            Join @@ Map[
                blockCells,
                StringSplit[ StringDelete[ StringReplace[ text, "\r\n" | "\r" -> "\n" ], StartOfString ~~ "\:feff" ], $blockRules ]
            ],
            $refused
        ]
    ];

cellsFromString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*refuse*)
refuse // beginDefinition;

(* Ends the call with a message that says what the model has to change. `1` in a template is the cell it is about. *)
refuse[ template_String, parameters___ ] :=
    Throw[
        Failure[ "CellSyntax", <| "MessageTemplate" -> template, "MessageParameters" -> { $cellName, parameters } |> ],
        $refused
    ];

refuse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*quoted*)
quoted // beginDefinition;
quoted[ text_String ] /; StringLength @ text > $maxQuotedLength := StringTake[ text, $maxQuotedLength ] <> "...";
quoted[ text_String ] := text;
quoted // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Blocks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*blockCells*)
blockCells // beginDefinition;

(* Only cell tags are read. Between them there can be blank lines and the markers of a selection. *)
blockCells[ text_String ] := (
    requireNoCellTag @ text;
    If[ ! StringMatchQ[ StringDelete[ text, $$selectionMarker ], WhitespaceCharacter... ],
        refuse[
            "`1` is not read (`2`). Write each new cell as its own <cell style='...'> block: the tag on a line, the \
content on the next lines and </cell> on a line of its own. Blank lines between the blocks are fine.",
            quoted @ StringTrim @ StringDelete[ text, $$selectionMarker ]
        ]
    ];
    { }
);

blockCells[ cellTag[ attributeText_String, body_ ] ] :=
    Module[ { attributes, id },
        attributes = tagAttributes @ attributeText;
        id = Replace[ Lookup[ attributes, "id", None ], written_String :> tagID @ written ];
        $tagCount++;
        Block[
            {
                $cellName = If[ StringQ @ id, "Cell " <> id, "Cell tag " <> ToString @ $tagCount <> " (a new cell)" ],
                $cellID   = id
            },
            If[ StringQ @ body && StringContainsQ[ body, $$cellTagLine ],
                refuse[ "`1` has a line in its body that starts with <cell. Close every cell tag with </cell> before \
the next one starts. A <cell that is content does not start a line: in text it is written &lt;cell, and in code the \
line break before it is written as \\n inside of the string." ]
            ];
            { tagCell[ attributes, body, id ] }
        ]
    ];

blockCells // endDefinition;


(* The id of a cell as CellToString writes it (c3), for the forms that models write it in: C3, #c3, #3 and 3. The
   records of the cell and what is asked of the caller have this id. Any other id is as it is written. *)
tagID // beginDefinition;

tagID[ id_String ] := StringReplace[
    StringTrim @ id,
    StartOfString ~~ ("#" | "") ~~ ("c" | "C" | "") ~~ number: DigitCharacter.. ~~ EndOfString :> "c" <> number
];

tagID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*requireNoCellTag*)
requireNoCellTag // beginDefinition;

requireNoCellTag[ text_String ] := Which[
    StringContainsQ[ text, $$strayCellTag ],
        refuse[ "`1` has a cell tag that could not be read. Write <cell name='value' ...>, the body on the next \
lines and </cell> on a line of its own, or <cell name='value' .../> to change only the attributes of a cell." ],
    StringContainsQ[ text, $$strayCellEnd ],
        refuse[ "A </cell> has no cell tag that it closes. The body of a cell ends at its first </cell>, also inside \
of code or of a string. A </cell> that is content of a body is written &lt;/cell> in text, and in code \
\"</\" <> \"cell>\"." ]
];

requireNoCellTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*tagAttributes*)
tagAttributes // beginDefinition;

tagAttributes[ text_String ] := Association @ StringCases[
    text,
    {
        name: LetterCharacter.. ~~ "='" ~~ value: Except[ "'" ]... ~~ "'" :> name -> importHTMLEntities @ value,
        name: LetterCharacter.. ~~ "=\"" ~~ value: Except[ "\"" ]... ~~ "\"" :> name -> importHTMLEntities @ value
    }
];

tagAttributes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*tagCell*)
tagCell // beginDefinition;

(* The existing cell of an id is asked for once. A tag without a body leaves the content of its cell alone. *)
tagCell[ attributes_Association, body_, id_ ] :=
    Module[ { names, unknown, old, styles, options },
        names   = Join[ { "id", "style", "CellLabel", "CellTags", "options" }, $extraAttributes ];
        unknown = DeleteCases[ Keys @ attributes, "truncated" | Alternatives @@ names ];
        If[ unknown =!= { },
            refuse[
                "`1` has the attribute `2`, which is not one of `3` and `4`.",
                First @ unknown,
                StringRiffle[ Most @ names, ", " ],
                Last @ names
            ]
        ];
        old = If[ StringQ @ id, $cells @ id, None ];
        If[ StringQ @ id && ! MatchQ[ old, _Cell ],
            refuse[ "`1` does not exist. Use the id of a cell that was read, or leave the id out to write a new cell." ]
        ];
        If[ KeyExistsQ[ attributes, "truncated" ] && StringQ @ body,
            refuse[ "`1` has the attribute truncated, so its body was cut when it was read and is not the whole cell. \
Read the cell without a length limit and write that, or leave out the attribute if the body is new." ]
        ];
        { styles, options } = stylesAndOptions[ attributes, old ];
        <|
            "ID"         -> id,
            "Cell"       -> If[ body === None && old =!= None,
                                Missing[ "Unchanged" ],
                                Block[ { $existingCell = old },
                                    Cell[ cellContent[ Replace[ body, None -> "" ], old, styles ], Sequence @@ styles, Sequence @@ options ]
                                ]
                            ],
            "Attributes" -> <| "Styles" -> styles, "Options" -> options |>,
            "Extra"      -> KeyTake[ attributes, $extraAttributes ],
            "Tag"        -> $tagCount
        |>
    ];

tagCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attributes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stylesAndOptions*)
stylesAndOptions // beginDefinition;

(* The styles and options of the cell that a tag stands for. An attribute that is left out, or that says what the tag
   of the existing cell says, changes nothing. Any other value is the model's: it is checked as text of a body is (the
   options as data, see attributeOptions), and replaces what that attribute shows of the cell. An option that the tag
   does not show is kept. *)
stylesAndOptions[ attributes_Association, old_ ] :=
    Module[ { shown, styles, options },
        { shown, styles, options } = Replace[
            old,
            {
                Cell[ _, arguments___ ] :> {
                    cellAttributes @ old,
                    Cases[ { arguments }, _String ],
                    DeleteCases[ Cases[ { arguments }, _Rule | _RuleDelayed ], CellObject -> _ ]
                },
                None :> { <| |>, { }, { } }
            }
        ];
        KeyValueMap[
            Function[ { name, value },
                Which[
                    value === Lookup[ shown, name, "" ], Null,
                    name === "style", requireInert @ value; styles = StringTrim /@ StringSplit[ value, "," ],
                    True, options = replaceOptions[ options, attributeOptions[ name, value, options ], name ]
                ]
            ],
            KeyTake[ attributes, { "style", "CellLabel", "CellTags", "options" } ]
        ];
        { styles, options }
    ];

stylesAndOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attributeOptions*)
attributeOptions // beginDefinition;

attributeOptions[ "CellLabel", "", _ ] := { };
attributeOptions[ "CellLabel", label_String, _ ] := (requireInert @ label; { CellLabel -> label });

attributeOptions[ "CellTags", tags_String, _ ] := (
    requireInert @ tags;
    Replace[ StringSplit[ tags, "," ], { { } :> { }, { tag_ } :> { CellTags -> tag }, list_ :> { CellTags -> list } } ]
);

(* An option that is written as the tag of the cell showed it is the cell's own. A string stands for it while the
   others are parsed and checked, so that it is neither: they are the model's, and have to be plain data. The options
   that a tag never shows are not the model's to set. *)
attributeOptions[ "options", text_String, old_List ] :=
    Module[ { own, shown, markers, held },
        own     = Select[ old, cellAttributes[ Cell[ "", # ] ][ "options" ] =!= "" & ];
        shown   = cellAttributes[ Cell[ "", # ] ][ "options" ] & /@ own;
        markers = Array[ "Option " <> ToString @ # <> " of the cell" &, Length @ own ];
        held    = heldData[ "{" <> StringReplace[ text, Thread[ shown -> (ToString[ #, InputForm ] & /@ markers) ] ] <> "}", "options", text ];
        If[ ! With[ { marker = Alternatives @@ markers }, MatchQ[ held, HoldComplete @ { ((Rule | RuleDelayed)[ _Symbol, _ ] | marker)... } ] ],
            refuse[ "`1` has options that are not name -> value rules with commas between them: `2`", quoted @ text ]
        ];
        Replace[
            Cases[ held, _[ name: $$hiddenCellOption, _ ] :> name, { 2 } ],
            { name_, ___ } :> refuse[ "`1` has the option `2`, which a cell tag does not show and cannot set. Leave \
it out: the cell keeps its own.", name ]
        ];
        Replace[ checkedData[ held, "options", text ], Thread[ markers -> own ], { 1 } ]
    ];

attributeOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*replaceOptions*)
replaceOptions // beginDefinition;

(* Puts the options that an attribute gives in the place of the ones that it showed, so that an option keeps its
   position. A new option also replaces one of the same name that the attribute did not show. *)
replaceOptions[ options_List, new_List, attribute_String ] := Join[
    Replace[
        options,
        option: _[ name_, _ ] :> FirstCase[
            new,
            _[ name, _ ],
            If[ cellAttributes[ Cell[ "", option ] ][ attribute ] === "", option, Nothing ]
        ],
        { 1 }
    ],
    DeleteCases[ new, _[ Alternatives @@ options[[ All, 1 ]], _ ] ]
];

replaceOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Content*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellContent*)
cellContent // beginDefinition;

(* A delimiter has an empty body whatever its content is *)
cellContent[ "", old: Cell[ content_, ___ ], _ ] /; MatchQ[ old, Cell[ __, $$delimiterStyle, ___ ] ] := content;

(* A body that is what CellToString writes for the existing cell gives its content back, whatever it holds *)
cellContent[ body_String, old_, styles_List ] :=
    With[ { kind = bodyKind[ old, styles ] },
        If[ MatchQ[ old, _Cell ] && kind === contentKind @ old && StringDelete[ body, $$selectionMarker ] === Block[ { $cellOriginals = None }, exactBody @ old ],
            First @ old,
            Replace[
                kind,
                {
                    "Code"  :> refuse[ "`1` is a cell of code, and a body of code that is new or changed is not read yet." ],
                    "Plain" :> plainContent @ body,
                    "Text"  :> textContent[ body, old, styles ]
                }
            ]
        ]
    ];

cellContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*bodyKind*)
bodyKind // beginDefinition;

(* The kind of a body is that of the content of an existing cell, unless the tag gives the cell a style of another
   kind. The kind of a new cell is that of its style. *)
bodyKind[ old: Cell[ _, arguments___ ], styles_List ] /; styleKind @ styles === styleKind @ Cases[ { arguments }, _String ] :=
    contentKind @ old;

bodyKind[ _, styles_List ] := styleKind @ styles;

bodyKind // endDefinition;


styleKind // beginDefinition;

styleKind[ styles_List ] := Which[
    IntersectingQ[ styles, $codeCellStyles ], "Code",
    IntersectingQ[ styles, { "Program", "ExternalLanguage" } ], "Plain",
    True, "Text"
];

styleKind // endDefinition;


contentKind // beginDefinition;

(* What CellToString writes the content of a cell as. Boxes in a cell of text, and content that is neither text nor
   boxes, are written as a piece of text. *)
contentKind[ cell: Cell[ content_, ___ ] ] := Which[
    ! MatchQ[ cell, Cell[ _String | _BoxData, ___, $$plainStringStyle, ___ ] ], "Text",
    StringQ @ content, "Plain",
    True, "Code"
];

contentKind // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*plainContent*)
plainContent // beginDefinition;

(* A plain string is the body as it is. One that CellToString could not write that way is a string in <RawBoxes>. *)
plainContent[ body_String ] :=
    Replace[
        StringCases[ body, RegularExpression[ "(?si)\\A" <> $rawBoxesTag <> "\\z" ] :> rawData[ "$1" ] ],
        {
            { original[ string_String ] } :> string,
            { string_String } :> (requireInert @ string; string),
            _ :> (requireInert @ body; body)
        }
    ];

plainContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Originals*)
originalOr // beginDefinition;
originalOr // Attributes = { HoldRest };

(* A piece that CellToString recorded is put back as it was. It is the user's own content, which is marked with
   original so that it is not checked. The records of the cell itself are looked up first, then those of the other
   cells: a text that stands for different boxes there is not used. *)
originalOr[ text_String, new_ ] :=
    With[ { own = Lookup[ $originals, $cellID, <| |> ] },
        Replace[
            If[ KeyExistsQ[ own, text ], own @ text, Lookup[ sharedOriginals[ ], text, None ] ],
            { None :> new, boxes_ :> original @ boxes }
        ]
    ];

originalOr // endDefinition;


sharedOriginals // beginDefinition;

sharedOriginals[ ] := Replace[
    $sharedOriginals,
    None :> ($sharedOriginals = Merge[ Values @ $originals, Replace[ { { boxes_ .. } :> boxes, _ -> None } ] ])
];

sharedOriginals // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Text*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*textContent*)
textContent // beginDefinition;

(* A marker of the default markdown at the start of the body says what the style of the cell says already ("## " in a
   heading, "- " in an item), and is not content. One piece that is not text is the content of a cell of boxes, which
   CellToString writes that way (a formula in a DisplayFormula cell). Other content has the form that the cell had: a
   string, TextData of one item, or TextData of a list. *)
textContent[ body_String, old_, styles_List ] :=
    With[ { items = checkedItems @ textItems @ StringDelete[ StringDelete[ body, $$selectionMarker ], StartOfString ~~ bodyMarker @ styles ] },
        Which[
            items === { },
                "",
            MatchQ[ items, { Except[ _String ] } ] && (MatchQ[ old, Cell[ _BoxData, ___ ] ] || IntersectingQ[ styles, { "DisplayFormula", "DisplayFormulaNumbered", "Picture" } ]),
                Replace[ First @ items, { Cell[ content_BoxData, ___ ] :> content, box_ :> BoxData @ box } ],
            MatchQ[ items, { _String } ] && ! MatchQ[ old, Cell[ _TextData, ___ ] ],
                First @ items,
            MatchQ[ items, { _ } ] && MatchQ[ old, Cell[ TextData[ Except[ _List ], ___ ], ___ ] ],
                TextData @@ items,
            True,
                TextData @ items
        ]
    ];

textContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkedItems*)
checkedItems // beginDefinition;

(* Everything that is not the user's own content is checked, and then the marks of the user's content are taken off *)
checkedItems[ items_List ] := (
    requireInert @ TextData[ items /. _original -> "" ];
    DeleteCases[ joinStrings[ items /. original[ box_ ] :> box ], "" ]
);

checkedItems // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*textItems*)
textItems // beginDefinition;
textItems[ text_String ] := Flatten @ Map[ textItem, joinStrings @ StringSplit[ text, $textPieceRules ] ];
textItems // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*textItem*)
textItem // beginDefinition;

textItem[ text_String ] := (
    requireNoTag @ text;
    requireInertText[ text, $$linearSyntaxInText ];
    StringReplace[ text, $textEscapes ]
);

textItem[ rawPiece[ text_String ] ] := inlineBox @ rawData @ text;
textItem[ uriPiece[ uri_String ] ] := inlineBox @ uriBoxes @ uri;
textItem[ markdownPiece[ type_String, markdown_String, parts___String ] ] := originalOr[ markdown, markdownBoxes[ type, parts ] ];

textItem[ evalPiece[ arguments__String ] ] :=
    Replace[ evaluatedBoxes @ arguments, original[ boxes: Except[ _Cell ] ] :> original @ Cell @ BoxData @ boxes ];

textItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineBox*)
inlineBox // beginDefinition;

(* Boxes as an item of text. The front end only takes text there (see textItemQ): any other box directly in TextData,
   also inside of a StyleBox or of a link, corrupts the cell, so it goes into an inline cell. The user's own content
   is put back as it is if it is text, which boxes that were recorded in code are not. A new row of tokens is code, in
   an inline cell. *)
inlineBox[ original[ box_ ] ] := original @ If[ textItemQ @ box, box, Cell @ BoxData @ box ];
inlineBox[ box: Except[ _RowBox ]? textItemQ ] := box;
inlineBox[ boxes_ ] := Cell @ BoxData @ boxes;

inlineBox // endDefinition;


textItemQ // beginDefinition;

(* True for what the front end takes as an item of text or inside of one: strings, inline cells, the boxes that show
   one of its values (they are only in the user's own content), and a StyleBox, a link or a row of those. *)
textItemQ[ _String | _Cell | _ValueBox | _CounterBox | _OptionValueBox ] := True;
textItemQ[ (StyleBox | ButtonBox)[ item_, ___ ] ] := textItemQ @ item;
textItemQ[ RowBox[ items_List ] ] := AllTrue[ items, textItemQ ];
textItemQ[ _ ] := False;

textItemQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*longNameCharacter*)
longNameCharacter // beginDefinition;

(* The character of \[Name] or \:xxxx, or the text itself if there is no such character *)
longNameCharacter[ name_String ] := Replace[ Quiet @ ToExpression[ "\"" <> name <> "\"" ], Except[ _String ] :> name ];

longNameCharacter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*markdownBoxes*)
markdownBoxes // beginDefinition;

(* What new markdown becomes. Nothing here changes the text that a piece holds: the chat formatter is only used for
   tables, since it also turns inline code into links, and digits in a formula into text. *)
markdownBoxes[ "Code", code_String ] := Cell[ BoxData @ code, "InlineCode" ];

(* Emphasis and the label of a link can hold other pieces. The style goes to each run of text, as the front end has
   it. Two markers of asterisks or underscores are bold, one is italic and three are both. *)
markdownBoxes[ "Emphasis", marker_String, text_String ] :=
    With[ { count = If[ StringStartsQ[ marker, "~" ], 0, StringLength @ marker ] },
        Map[
            emphasized[ #, Pick[ $emphasisOptions, { count >= 2, OddQ @ count, count === 0 } ] ] &,
            textItems @ text
        ]
    ];

(* The label ends at the last "](" *)
markdownBoxes[ "Link", link_String ] :=
    Replace[
        StringCases[ link, StartOfString ~~ "[" ~~ label__ ~~ "](" ~~ url__ ~~ ")" ~~ EndOfString :> { label, url } ],
        {
            { { label_, url_ } } /; StringStartsQ[ url, "paclet:" ] :>
                ButtonBox[ linkLabel @ label, BaseStyle -> "Link", ButtonData -> url ],
            { { label_, url_ } } :>
                ButtonBox[ linkLabel @ label, BaseStyle -> "Hyperlink", ButtonData -> { URL @ url, None }, ButtonNote -> url ]
        }
    ];

markdownBoxes[ "Math", tex_String ] :=
    Replace[
        makeTeXBoxes @ tex,
        {
            RawBoxes[ formula: TemplateBox[ KeyValuePattern[ "state" -> "Boxes" ], "TeXAssistantTemplate", ___ ] ] :>
                Cell @ BoxData @ FormBox[ formula, TraditionalForm ],
            _ :> refuse[ "`1` has LaTeX that could not be read: `2`", quoted @ tex ]
        }
    ];

(* A table is made by the chat formatter. Code in a table (inline code and the text of a table cell) stays the text
   that it is and is not typeset, as inline code is anywhere else in a body. A caller's settings for reading cells are
   not meant for what the formatter reads on the way. The formatter has no escape for long names, so they are read
   first. *)
markdownBoxes[ "Table", table_String ] :=
    With[ { text = tableText @ StringReplace[ table, { "\\\\" -> "\\\\", name: $$longName :> longNameCharacter @ name } ] },
        Replace[
            Block[ { $includeCellXML = False, $preserveCellBoxes = False, wlStringToBoxes = # & },
                FormatChatOutput[ text, <| "Status" -> "Finished" |> ]
            ],
            {
                RawBoxes @ Cell[ TextData[ items_, ___ ], ___ ] :> preprocessExplodedCells @ Flatten @ { items },
                _ :> table
            }
        ]
    ];

markdownBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tableText*)
tableText // beginDefinition;

(* The text of a table as the chat formatter gets it. The formatter has rules of its own for URIs, images and code
   blocks, which are not the writer's, and the rule for text holds in a table as it does anywhere. So the text has none
   of these and no linear syntax, as it is typed and with its entities read (the formatter reads them first): an image
   link is a link (also in inline code, where its ! is lost), and the rest is refused. *)
tableText[ text_String ] :=
    With[ { links = StringReplace[ text, "!" ~~ link: $$markdownLink :> link ] },
        With[ { read = importHTMLEntities @ links },
            requireInertText[ read, $$linearSyntaxInText ];
            Replace[
                StringCases[ read, $$attachmentURI | "```" | ("![" ~~ Shortest[ ___ ] ~~ "](" ~~ Except[ ")" ].. ~~ ")"), 1 ],
                {
                    { "```" } :> refuse[ "`1` has three backticks in a table, where they are not read. Inline code is \
in single backticks." ],
                    { uri_ } /; StringMatchQ[ uri, $$attachmentURI ] :> refuse[ "`1` has the URI `2` in a table, \
where a URI is not read. Write it as <!`2`!> in the text of the cell, outside of the table.", uri ],
                    { _ } :> refuse[ "`1` has an image link in a table that could not be read. Write it as \
[label](address), without line breaks or spaces in the address." ]
                }
            ]
        ];
        links
    ];

tableText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*emphasized*)
emphasized // beginDefinition;

(* Inline cells and the user's own content keep their style *)
emphasized[ text_String, options_List ] := StyleBox[ text, Sequence @@ options ];

emphasized[ StyleBox[ text_, inner: (Alternatives @@ $emphasisOptions).. ], options_List ] :=
    StyleBox[ text, Sequence @@ Select[ $emphasisOptions, MemberQ[ Join[ options, { inner } ], # ] & ] ];

emphasized[ ButtonBox[ label_, rest___ ], options_List ] := ButtonBox[ emphasized[ label, options ], rest ];
emphasized[ other_, _List ] := other;

emphasized // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*linkLabel*)
linkLabel // beginDefinition;
linkLabel[ label_String ] := Replace[ joinStrings @ textItems @ label, { { item_ } :> item, items_List :> RowBox @ items } ];
linkLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tags and URIs*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requireNoTag*)
requireNoTag // beginDefinition;

requireNoTag[ text_String ] :=
    Replace[
        StringCases[ text, $$strayTag :> { "$1", "$2" }, 1 ],
        { { slash_, name_ } } :> refuse[
            "`1` has the tag <`2``3`> without the tag that `4` it. Write both tags, with what they hold between \
them. If the tag is meant as text, write it as &lt;`2``3`> in text. In code it is text inside of a string or a comment.",
            slash,
            name,
            If[ slash === "", "closes", "opens" ]
        ]
    ];

requireNoTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*rawData*)
rawData // beginDefinition;

(* The boxes that the text between <RawBoxes> tags stands for: what was recorded for it when it was read, marked as the
   user's own, or else what the model wrote, which has to pass the rule for its data (see dataQ).
   A TemplateBox that the existing cell holds is not the model's, also in boxes that the model changed around it: a
   string stands for it while the rest is read and checked, and the template of the cell is written in its place,
   marked as the user's own. *)
rawData[ text_String ] := originalOr[
    text,
    Replace[
        ownTemplates @ $existingCell,
        { inText_, inData_ } :> ReplaceAll[
            checkedData[ heldData[ StringReplace[ text, inText ], "<RawBoxes>", text ], "<RawBoxes>", text ],
            inData
        ]
    ]
];

rawData // endDefinition;


(* The templates of a cell as two lists of rules: from the text of each template to the text of the string that stands
   for it, and from the strings to the templates. A template is found by its text as CellToString writes it, so
   nothing of the user's is read or evaluated again, and a template of the model's is never taken for one of them.
   Not found: a template whose text <RawBoxes> has with an escape (it holds the text of a tag or of a URI). *)
ownTemplates // beginDefinition;

ownTemplates[ cell_ ] := With[ { templates = DeleteDuplicates @ Cases[ cell, _TemplateBox, Infinity ] },
    With[ { strings = Array[ "Template " <> ToString @ # <> " of the cell" &, Length @ templates ] },
        { Thread[ (inputFormLine /@ templates) -> (inputFormLine /@ strings) ], Thread[ strings -> original /@ templates ] }
    ]
];

ownTemplates // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*heldData*)
heldData // beginDefinition;

(* The expression that a text is, held. Nothing is evaluated and no symbol is made to get it:
   - Linear syntax is evaluated when it is parsed, also when the result is held, so it is refused before that.
   - CodeParser reads the text without making symbols. Only names of System` symbols that exist are let through. *)
heldData[ text_String, what_String, shown_String ] := (
    requireInertText[ text, $$linearSyntax ];
    Needs[ "CodeParser`" -> None ];
    Scan[
        Function[ name,
            If[ StringContainsQ[ name, "`" ] || ! NameQ[ "System`" <> name ],
                refuse[ "`1` has `2` with the symbol `3`, which is not written: boxes and plain data can only have \
symbols of the System context that exist, without a context mark: `4`", what, name, quoted @ shown ]
            ]
        ],
        Cases[ CodeParser`CodeTokenize @ text, CodeParser`LeafNode[ Symbol, name_String, _ ] :> name ]
    ];
    Block[ { $Context = $dataContext, $ContextPath = { "System`" } },
        Quiet @ Check[ ToExpression[ text, InputForm, HoldComplete ], $Failed ]
    ]
);

heldData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkedData*)
checkedData // beginDefinition;

(* What the model writes as an expression is only boxes and plain data (see dataQ): the kernel evaluates what it reads
   from a notebook, and the front end runs dynamic content when it shows it. The data is evaluated once it is known to
   be plain: an association and a fraction are only then what they are. *)
checkedData[ held: HoldComplete[ _ ], what_String, text_String ] := (
    If[ ! dataQ @ held, refuse[ If[ FreeQ[ held, TemplateBox ], $notDataText, $templateText ], what, quoted @ text ] ];
    ReleaseHold @ held
);

checkedData[ _, what_String, text_String ] :=
    refuse[ "`1` has `2` that are not a Wolfram Language expression: `3`", what, quoted @ text ];

checkedData // endDefinition;


$notDataText = "\
`1` has `2` that are not only boxes and plain data, so they are not written. Allowed: boxes that typeset (RowBox, \
FractionBox, StyleBox, GridBox and the like) with strings, numbers, lists, rules, associations, colors and System \
symbols without a value. Not allowed: a dynamic box, graphics, an option that holds code (ButtonFunction, \
CellEventActions, InitializationCell and the like), linear syntax in a string, a TagBox whose tag is not a string, a \
ButtonBox that is not a link (BaseStyle -> \"Hyperlink\" with ButtonData), and any other function or symbol with a \
value. What was written: `3`";

$templateText = "\
`1` has `2` with a TemplateBox, which is not written: a template shows and does what its stylesheet style says, which \
can run code on a click. Only a TemplateBox that the cell already has is kept: copy it unchanged from the cell as it \
was read, or leave it out. What was written: `3`";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dataQ*)
dataQ // beginDefinition;

(* The rule for data that the model writes (<RawBoxes>, new options, results of a sandboxed evaluator): True for a
   held expression that does nothing when it is shown, evaluated or clicked. Every head is one of plain data, every
   symbol is inert, no option holds code, no box acts and no string has linear syntax (which the front end reads in the
   text of boxes). Nothing of it is evaluated here. *)
dataQ[ held_HoldComplete ] :=
    With[ { data = held /. $$arithmetic -> 0 },
        And[
            FreeQ[ data, $$codeOption | $$actingBox | _String? (StringContainsQ[ $$linearSyntax ]) ],
            FreeQ[ data, _Symbol? activeSymbolQ, { 1, Infinity }, Heads -> True ],
            FreeQ[ data, head_[ ___ ] /; ! MatchQ[ Unevaluated @ head, $$dataHead ], { 1, Infinity } ]
        ]
    ];

dataQ // endDefinition;


activeSymbolQ // beginDefinition;
activeSymbolQ // Attributes = { HoldAllComplete };

(* True for a symbol that is not just itself when it is evaluated: one outside of System`, a variable of the system
   ($SessionID, $Assumptions) and a symbol with a value of its own (Now, a function that is loaded when its name is
   evaluated). OwnValues gives the value without evaluating the symbol. A value that is plain data itself is let
   through: the named colors (Red is RGBColor[1, 0, 0]) and Infinity. Of the 7,630 System` symbols of 16.0 without a
   $, none is changed by evaluation without having a value that OwnValues shows. *)
activeSymbolQ[ symbol_Symbol ] := Or[
    Context @ Unevaluated @ symbol =!= "System`",
    StringStartsQ[ SymbolName @ Unevaluated @ symbol, "$" ],
    Replace[
        Quiet @ OwnValues @ symbol,
        { { } -> False, { _ :> value_ } :> ! dataQ @ HoldComplete @ value, _ -> True }
    ]
];

activeSymbolQ // endDefinition;


codeOptionQ // beginDefinition;
codeOptionQ // Attributes = { HoldAllComplete };
codeOptionQ[ name_String ] := MemberQ[ $codeOptions, name ];
codeOptionQ[ name_Symbol ] := MemberQ[ $codeOptions, SymbolName @ Unevaluated @ name ];
codeOptionQ[ _ ] := False;
codeOptionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requireInert*)
requireInert // beginDefinition;

(* The check of what is made of the text of a body or of an attribute, after it is made: typed text, and what
   markdown, the chat formatter and the front end make of it. (The user's own content is not checked, and data that
   the model wrote is checked by dataQ.)
   - Text has no control characters and no characters of linear syntax.
   - Boxes have no string with linear syntax, also as it is typed (the front end reads that in the text of boxes), no
     dynamic box and no option that holds code. *)
requireInert[ text_String ] := requireInertText[ text, $$unwritableCharacter ];

requireInert[ TextData[ text_, ___ ] ] := (
    Scan[ requireInert, Cases[ Flatten @ { text }, _String ] ];
    requireInert @ BoxData @ DeleteCases[ Flatten @ { text }, _String ]
);

requireInert[ boxes_ ] := (
    requireInertText[ StringRiffle[ Cases[ boxes, _String, { 0, Infinity } ], "\n" ], $$linearSyntax ];
    If[ ! FreeQ[ boxes, $$dynamicHead[ ___ ] | $$codeOption ],
        refuse[ "`1` has boxes that would run code when the cell is shown (a dynamic box or an option that holds \
code), so they are not written." ]
    ]
);

requireInert // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*requireInertText*)
requireInertText // beginDefinition;

(* The rule for text: no control characters, and nothing that the pattern finds, which is linear syntax in the form
   that the text could have it *)
requireInertText[ text_String, pattern_ ] :=
    Replace[
        StringCases[ text, pattern | $$controlCharacter, 1 ],
        {
            { found_ } /; StringMatchQ[ found, $$controlCharacter ] :>
                refuse[ "`1` has control characters, likely from broken escapes. Write the characters as they are." ],
            { found_ } :>
                refuse[ "`1` has linear syntax (`2`), which is not written. \
Write boxes as <RawBoxes> and a backslash that is text as \\\\.", StringReplace[ found, c: $$unwritableCharacter :> "\\:" <> IntegerString[ First @ ToCharacterCode @ c, 16, 4 ] ] ]
        }
    ];

requireInertText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateToBoxes*)
evaluateToBoxes // beginDefinition;

(* What a <ToBoxes> or <MakeBoxes> tag does: gives <| "Boxes" -> boxes, "Output" -> text |>, or a Failure with a
   message for the model. The code is given as text, so that it is parsed in the kernel of the evaluator tool (whose
   settings are those of the chat), where the URIs in it are filled in as for the tool. Code with a comma outside of
   brackets gives no boxes (ToBoxes gets too many arguments). *)
evaluateToBoxes[ code_String, form: "StandardForm" | "TraditionalForm", tag: "ToBoxes" | "MakeBoxes" ] :=
    Catch[
        Module[ { result, output, held },
            If[ ! toolSelectedQ[ "WolframLanguageEvaluator" ],
                refuse[ "`1` has a <`2`> tag, which needs the Wolfram Language evaluator tool. Without it, write the \
boxes themselves as <RawBoxes>.", tag ]
            ];
            result = WolframLanguageToolEvaluate[
                tag <> "[" <> code <> ", " <> form <> "]",
                { "Result", "String" },
                Sequence @@ Map[
                    # -> toolOptionValue[ "WolframLanguageEvaluator", # ] &,
                    { "Method", "AllowedReadPaths", "AllowedWritePaths", "AllowedExecutePaths" }
                ],
                "TimeConstraint"        -> $cellTagSeconds,
                "Line"                  -> None,
                "AppendURIInstructions" -> False
            ];
            output = Replace[ result, { KeyValuePattern[ "String" -> string_String ] :> string, _ :> "None" } ];
            held = Replace[ result, { KeyValuePattern[ "Result" -> HoldCompleteForm[ boxes_ ] ] :> HoldComplete @ boxes, _ :> None } ];
            (* A result that is not boxes (the evaluation failed or ran out of time) is told apart without evaluating it: *)
            If[ ! MatchQ[ held, HoldComplete[ _String | (_Symbol? boxNameQ)[ ___ ] ] ],
                refuse[
                    "`1`: <`2`> gave no boxes for `3`. The output of the evaluator: `4`",
                    tag,
                    quoted @ code,
                    StringTake[ output, UpTo[ 500 ] ]
                ]
            ];
            <| "Boxes" -> First @ resultBoxes[ held, "<" <> tag <> ">" ], "Output" -> output |>
        ],
        $refused
    ];

evaluateToBoxes // endDefinition;


(* True for the name of a box. The symbol is the head of a result that is held, so it is not evaluated. *)
boxNameQ // beginDefinition;
boxNameQ // Attributes = { HoldAllComplete };

boxNameQ[ symbol_Symbol ] :=
    Context @ Unevaluated @ symbol === "System`" && StringEndsQ[ SymbolName @ Unevaluated @ symbol, "Box" ];

boxNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluatedBoxes*)
evaluatedBoxes // beginDefinition;

(* The boxes of a <MakeBoxes> or <ToBoxes> tag, which have the check of results behind them *)
evaluatedBoxes[ tag_String, attributes_String, code_String ] :=
    Replace[
        evaluateToBoxes[
            code,
            Replace[
                StringTrim @ attributes,
                {
                    "" -> "StandardForm",
                    s_ /; StringMatchQ[ s, "form=" ~~ ("'" | "\"") ~~ ("StandardForm" | "TraditionalForm") ~~ ("'" | "\"") ] :>
                        StringTake[ s, { 7, -2 } ],
                    _ :> refuse[ "`1` has <`2``3`>. The only attribute of this tag is form='StandardForm' or form='TraditionalForm'.", tag, attributes ]
                }
            ],
            If[ StringMatchQ[ tag, "ToBoxes", IgnoreCase -> True ], "ToBoxes", "MakeBoxes" ]
        ],
        { failure_Failure :> Throw[ failure, $refused ], result_ :> original @ result[ "Boxes" ] }
    ];

evaluatedBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resultBoxes*)
resultBoxes // beginDefinition;

(* What the evaluator gives is written as it is if it runs in the user's kernel, where the model's code runs anyway.
   The result of a sandboxed evaluator is only released in this kernel, and written, if it is plain data, as what a
   model writes itself has to be (dataQ). *)
resultBoxes[ held: HoldComplete[ _ ], what_String ] := (
    If[ ! useSessionQ[ ] && ! dataQ @ held,
        refuse[ "`1`: the boxes of `2` are not written. The evaluator runs in a sandbox, and they are not only \
boxes and plain data: they have a TemplateBox, dynamic content, options that hold code, graphics or other \
expressions. Write a result that is only typeset (numbers, formulas, grids), \
or write the code as an Input cell for the user to evaluate.", what ]
    ];
    original @@ held
);

resultBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*uriBoxes*)
uriBoxes // beginDefinition;

(* The boxes that a URI stands for in $attachments. Boxes that CellToString put there from a notebook are the user's
   own. Anything else is a value of the evaluator, which is typeset in this kernel and then follows the rule for
   results. *)
uriBoxes[ uri_String ] :=
    With[ { key = First @ StringCases[ uri, "content-" ~~ WordCharacter.. ] },
        Replace[
            Lookup[ $attachments, key ],
            {
                HoldComplete[ RawBoxes[ StyleBox[ boxes_, "GraphicsRawBoxes" ] | boxes_ ] ] /; KeyExistsQ[ $notebookAttachments, key ] :>
                    original @ boxes,
                HoldComplete[ RawBoxes[ boxes_ ] ] :>
                    resultBoxes[ HoldComplete @ boxes, "the URI " <> key ],
                HoldComplete[ expr_ ] :>
                    With[ { boxes = MakeBoxes[ expr, StandardForm ] }, resultBoxes[ HoldComplete @ boxes, "the URI " <> key ] ],
                _ :>
                    refuse[ "`1` has the URI `2`, which is not available any more (URIs do not outlast the kernel \
session, and only the newest ones of a notebook are kept). Read the cell again, or evaluate the expression again.", uri ]
            }
        ]
    ];

uriBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $tagPieceRules;
    $textPieceRules;
    $textEscapes;
];

End[ ];
EndPackage[ ];
