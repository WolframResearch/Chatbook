#!/usr/bin/env wolframscript
(* The corpus measures of docs/cell-syntax.md, over the cells of notebook files.

   wolframscript -f Developer/CellSyntaxCorpus.wls roundtrip <notebooks or directories>
       Every cell that is not generated is read with an exact body and written back unchanged, with and without what
       reading recorded: the cell that comes back has to be identical. An Input or Code cell with boxes is also
       written back with (b) one identifier renamed, (c) one number changed, (d) a line appended, and (e) as a new
       cell. The result is compared with the expected cell, and then by the expressions that the kernel reads from the
       two. Needs a front end, which tokenizes code.

   wolframscript -f Developer/CellSyntaxCorpus.wls default <out.wxf> <notebooks or directories>
   wolframscript -f Developer/CellSyntaxCorpus.wls compare <a.wxf> <b.wxf>
       The default CellToString output of every cell, to compare two checkouts: run default in each one (the script
       loads the paclet of the checkout that it is in), then compare.

   A directory stands for its .nb files. The documentation directory of the system (.../Documentation/English/System)
   stands for the pages of $documentationPages. *)

PacletDirectoryLoad @ DirectoryName[ $InputFileName, 2 ];
Get[ "Wolfram`Chatbook`" ];

$documentationPages = Join[
    "ReferencePages/Symbols/" <> # <> ".nb" & /@ {
        "Association", "Map", "Graph", "StringCases", "TraditionalForm", "Manipulate", "Style", "Integrate", "Sum", "Product", "Limit",
        "D", "Series", "Table", "Solve", "Module", "StringReplace", "Grid", "Dynamic", "Button", "Cases", "Fold", "Piecewise",
        "FourierTransform", "Derivative", "Function", "Compile", "Block", "ReplaceAll", "Reduce", "Minimize", "Expectation", "Hyperlink",
        "TextCell", "Row", "Subscript", "With", "Assuming", "Plot"
    },
    "Tutorials/" <> # <> ".nb" & /@ {
        "TextualInputAndOutput", "TransformationRulesAndDefinitions", "ManipulatingEquationsAndInequalities", "Patterns",
        "ModularityAndTheNamingOfThings", "SymbolicCalculations", "Lists", "BasicObjects", "Calculus", "SeriesLimitsAndResidues",
        "LinearAlgebra", "IntroductionToDynamic", "WorkingWithStringPatterns"
    },
    {
        "ReferencePages/Formats/JSON.nb", "ReferencePages/Characters/Alpha.nb", "ReferencePages/Messages/General/argx.nb",
        "ReferencePages/ExternalEvaluationSystems/Python.nb", "ReferencePages/Programs/wolframscript.nb", "ReferencePages/MenuItems/SaveAs.nb",
        "ReferencePages/Entities/Planet.nb", "ReferencePages/Interpreters/City.nb", "Guides/StringManipulation.nb",
        "Guides/ListManipulation.nb", "Guides/FunctionalProgramming.nb", "Workflows/AddABannerToANotebook.nb", "HowTos/CreateASlideShow.nb",
        "WorkflowGuides/CellsAndGrouping.nb", "ExamplePages/3DLaplacians.nb"
    }
];

notebookFiles[ file_String ] := Which[
    ! DirectoryQ @ file, { file },
    DirectoryQ @ FileNameJoin @ { file, "ReferencePages" }, Select[ FileNameJoin @ { file, # } & /@ $documentationPages, FileExistsQ ],
    True, FileNames[ "*.nb", file ]
];

notebookCells[ file_String ] := cellList @ Quiet @ Get @ file;
cellList[ Notebook[ cells_, ___ ] ] := cellList @ cells;
cellList[ cells_List ] := Join @@ (cellList /@ cells);
cellList[ Cell[ CellGroupData[ cells_, ___ ], ___ ] ] := cellList @ cells;
cellList[ cell_Cell ] := { cell };
cellList[ _ ] := { };

generatedQ[ cell_Cell ] := MatchQ[ cell, Cell[ __, Wolfram`Chatbook`Common`$$generatedCellStyle, ___ ] ];

(* ---- reading and writing one cell ---- *)
readExact[ cell_Cell ] := Block[ { Wolfram`Chatbook`Common`$cellOriginals = <| |> },
    { CellToString[ cell, "IncludeXML" -> True, "PreserveBoxes" -> True ], Wolfram`Chatbook`Common`$cellOriginals }
];

written[ text_String, opts___ ] := Replace[
    TimeConstrained[ Quiet @ Wolfram`Chatbook`Common`cellsFromString[ text, opts ], 60, $TimedOut ],
    { KeyValuePattern[ "Cell" -> cell_ ] } :> cell
];

(* The body of the text of one cell tag, and the text with another body *)
bodyOf[ text_String ] := First @ StringCases[ text, RegularExpression[ "(?s)^<cell[^\\n]*>\\n(.*)\\n</cell>$" ] :> "$1" ];
withBody[ text_String, body_String ] := First @ StringCases[ text, RegularExpression[ "^<cell[^\\n]*>\\n" ] ] <> body <> "\n</cell>";

(* ---- what the kernel reads from a code cell, held: one expression for each statement ---- *)
heldOf[ Cell[ BoxData[ boxes_List, ___ ], ___ ] ] :=
    Flatten[ HoldComplete @@ (heldOf /@ DeleteCases[ boxes, _String? (StringMatchQ[ WhitespaceCharacter... | "\[IndentingNewLine]" ]) ]), 1, HoldComplete ];
heldOf[ Cell[ BoxData[ boxes_, ___ ], ___ ] ] := heldOf @ boxes;
heldOf[ boxes_ ] := DeleteCases[ TimeConstrained[ Quiet @ ToExpression[ boxes, StandardForm, HoldComplete ], 30, HoldComplete @ $Failed ], Null ];
parsedQ[ held_ ] := FreeQ[ held, $Failed ];

withoutIDs[ expr_ ] := DeleteCases[ expr, (ExpressionUUID | CellChangeTimes | CellID) -> _, Infinity ];

verdict[ new_Cell, expected_Cell ] := With[ { held = heldOf @ new, expectedHeld = heldOf @ expected },
    Which[
        withoutIDs @ new === withoutIDs @ expected, "identical",
        held === expectedHeld, "same expression",
        ! parsedQ @ expectedHeld, "did not parse before",
        ! parsedQ @ held, "PARSES NO MORE",
        True, "other expression"
    ]
];
verdict[ _Failure, _ ] := "refused";
verdict[ _, _ ] := "FAILED";

(* ---- the edit of one token: { edited body, expected boxes }, or None if the token is not found once in the text ---- *)
tokens[ RowBox @ { "(*", ___, "*)" }, _ ] := { };
tokens[ RowBox[ items_List ], position_ ] := Join @@ MapIndexed[ tokens[ #1, Join[ position, { 1 }, #2 ] ] &, items ];
tokens[ items_List, position_ ] := Join @@ MapIndexed[ tokens[ #1, Join[ position, #2 ] ] &, items ];
tokens[ token_String, position_ ] := { position -> token };
tokens[ _, _ ] := { };

$notCode = RegularExpression[ "(?s)\"(?:[^\"\\\\]|\\\\.)*\"|\\(\\*.*?\\*\\)|<RawBoxes>.*?</RawBoxes>|!\\[[^\\]\\n]*\\]\\([a-z]+://content-[^)]*\\)|<![a-z]+://[^!]*!>" ];
codeOnly[ body_String ] := StringReplace[ body, text: $notCode :> StringRepeat[ " ", StringLength @ text ] ];

tokenEdit[ boxes_, body_String, kind_, inText_, new_String ] := Module[ { all, chosen, places },
    all = tokens[ boxes, { } ];
    chosen = SelectFirst[ all, StringMatchQ[ Last @ #, kind ] &, None ];
    If[ chosen === None, Return @ None ];
    places = StringPosition[ codeOnly @ body, inText @ Last @ chosen, Overlaps -> False ];
    If[ Length @ places =!= Count[ all, _ -> Last @ chosen ], Return @ None ];
    With[ { token = If[ Last @ chosen === new, new <> "1", new ] },
        { StringReplacePart[ body, token, First @ places ], If[ First @ chosen === { }, token, ReplacePart[ boxes, First @ chosen -> token ] ] }
    ]
];
identifierInText[ name_String ] := RegularExpression[ "(?<![\\w$`#])(?<!\\\\\\[)" <> name <> "(?![\\w$`])" ];
numberInText[ number_String ] := RegularExpression[ "(?<![\\w$`.#%])" <> number <> "(?![\\d.`]|\\^\\^)" ];

(* ---- the record of a cell ---- *)
record[ cell_Cell ] /; generatedQ @ cell := <| "Generated" -> True |>;

record[ cell_Cell ] := Module[ { text, originals, edits = <| |>, boxes, body, style, arguments, edit },
    { text, originals } = readExact @ cell;
    If[ ! StringQ @ text, Return @ <| "Unchanged" -> "FAILED" |> ];
    If[ MatchQ[ cell, Cell[ BoxData[ _, ___ ], ___, "Input" | "Code", ___ ] ] && ByteCount @ cell < 2*^6,
        boxes     = cell[[ 1, 1 ]];
        body      = bodyOf @ text;
        style     = First @ Cases[ cell, "Input" | "Code", { 1 } ];
        arguments = Rest[ List @@ cell ];
        edit[ kind_, inText_, new_ ] := Replace[
            tokenEdit[ boxes, body, kind, inText, new ],
            { edited_, expected_ } :> verdict[ written[ withBody[ text, edited ], "Cells" -> <| "c1" -> cell |>, "Originals" -> originals ], Cell[ BoxData @ expected, Sequence @@ arguments ] ]
        ];
        edits = <|
            "b" -> edit[ RegularExpression[ "[A-Za-z][A-Za-z0-9]*" ], identifierInText, "zzq9" ],
            "c" -> edit[ RegularExpression[ "\\d+" ], numberInText, "7919" ],
            "d" -> verdict[
                written[ withBody[ text, body <> "\nzzq9 = 7919" ], "Cells" -> <| "c1" -> cell |>, "Originals" -> originals ],
                Cell[ BoxData @ Append[ Replace[ boxes, Except[ _List ] :> { boxes } ], RowBox @ { "zzq9", "=", "7919" } ], Sequence @@ arguments ]
            ],
            "e" -> verdict[ written[ "<cell style='" <> style <> "'>\n" <> body <> "\n</cell>" ], Cell[ First @ cell, style ] ]
        |>
    ];
    <|
        "Unchanged"                  -> If[ written[ text, "Cells" -> <| "c1" -> cell |>, "Originals" -> originals ] === cell, "identical", "DIFFERENT" ],
        "UnchangedWithoutOriginals"  -> If[ written[ text, "Cells" -> <| "c1" -> cell |> ] === cell, "identical", "DIFFERENT" ],
        edits
    |>
];

roundTrip[ files_List ] := Module[ { records },
    records = Join @@ Map[
        Function[ file,
            With[ { cells = notebookCells @ file },
                Print[ FileBaseName @ file, ": ", Length @ cells, " cells" ];
                Block[ { Wolfram`Chatbook`Common`$attachments = <| |>, Wolfram`Chatbook`Common`$notebookAttachments = <| |> },
                    Replace[ TimeConstrained[ record @ #, 300, $TimedOut ], Except[ _Association ] -> <| "Unchanged" -> "FAILED" |> ] & /@ cells
                ]
            ]
        ],
        files
    ];
    Print[ "notebooks: ", Length @ files, ", cells: ", Length @ records, ", generated (not written): ", Count[ records, KeyValuePattern[ "Generated" -> True ] ] ];
    Print[ "unchanged, with what reading recorded: ", Counts @ DeleteMissing @ Lookup[ records, "Unchanged" ] ];
    Print[ "unchanged, without it: ", Counts @ DeleteMissing @ Lookup[ records, "UnchangedWithoutOriginals" ] ];
    Print[ "Input and Code cells with boxes: ", Count[ records, KeyValuePattern[ "e" -> _ ] ] ];
    Scan[
        Print[ "(", First @ #, ") ", Last @ #, ": ", KeySort @ Counts @ DeleteCases[ DeleteMissing @ Lookup[ records, First @ # ], None ] ] &,
        { { "b", "one identifier renamed" }, { "c", "one number changed" }, { "d", "a line appended" }, { "e", "as a new cell" } }
    ];
];

defaultOutput[ out_String, files_List ] := Export[
    out,
    Association @ Map[ Function[ file, FileBaseName @ file -> Map[ Quiet @ CellToString @ # &, notebookCells @ file ] ], files ],
    "WXF"
];

compare[ a_String, b_String ] := With[ { old = Import[ a, "WXF" ], new = Import[ b, "WXF" ] },
    Print[ "cells: ", Total[ Length /@ old ], " and ", Total[ Length /@ new ] ];
    Print[ "different: ", If[ Keys @ old === Keys @ new, Total @ MapThread[ If[ Length @ #1 === Length @ #2, Count[ Transpose @ { #1, #2 }, { x_, y_ } /; x =!= y ], Infinity ] &, { Values @ old, Values @ new } ], "the notebooks differ" ] ];
];

Block[ { $AllowInternet = False },
    Replace[
        Rest @ $ScriptCommandLine,
        {
            { "roundtrip", files__ } :> UsingFrontEnd @ roundTrip[ Join @@ (notebookFiles /@ { files }) ],
            { "default", out_, files__ } :> defaultOutput[ out, Join @@ (notebookFiles /@ { files }) ],
            { "compare", a_, b_ } :> compare[ a, b ],
            _ :> Print[ "Usage: CellSyntaxCorpus.wls roundtrip <notebooks> | default <out.wxf> <notebooks> | compare <a.wxf> <b.wxf>" ]
        }
    ]
];
