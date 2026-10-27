(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`ChatbookTests`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `$TestDefinitionsLoaded,
    `$TestNotebook;
    `ConstructWorkspaceContextMessages;
    `CreateChatCell;
    `CreateChatCells;
    `CreateTestChatNotebook;
    `FormatMarkdown;
    `MarkdownRoundTrip;
    `NormalizeTextData;
    `WithTestNotebook;
];

Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Wolfram`PacletCICD`$Debug = True;

Off[ General::shdw           ];
Off[ PacletInstall::samevers ];

If[ ! PacletObjectQ @ PacletObject[ "Wolfram/PacletCICD" ],
    PacletInstall[ "https://github.com/WolframResearch/PacletCICD/releases/download/v0.36.2/Wolfram__PacletCICD-0.36.2.paclet" ]
];

Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*abort*)
abort[ ] := (
    If[ $Context === "Wolfram`ChatbookTests`Private`", End[ ] ];
    If[ $Context === "Wolfram`ChatbookTests`", EndPackage[ ] ];
    cicd`ScriptConfirm[ $Failed ]
);

abort[ message__ ] := (
    cicd`ConsoleError @ SequenceForm @ message;
    abort[ ]
);

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*endDefinition*)
endDefinition[ sym_Symbol ] := sym[ args___ ] := abort[ "Invalid arguments in ", HoldForm @ sym @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$sourceDirectory = DirectoryName[ $InputFileName, 2 ];
$buildDirectory  = FileNameJoin @ { $sourceDirectory, "build", "Wolfram__Chatbook" };
$pacletDirectory = Quiet @ SelectFirst[ { $buildDirectory, $sourceDirectory }, PacletObjectQ @* PacletObject @* File ];
$mxFile          = FileNameJoin @ { $pacletDirectory, "Source", "Chatbook", "64Bit", "Chatbook.mx" };

$$rules = (Rule|RuleDelayed)[ _, _ ]..;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Paclet*)
If[ ! DirectoryQ @ $pacletDirectory, abort[ "Paclet directory ", $pacletDirectory, " does not exist!" ] ];
If[ $pacletDirectory =!= $buildDirectory, cicd`ConsoleWarning[ "Warning: Testing unbuilt paclet" ] ];
Quiet @ PacletDirectoryUnload @ $sourceDirectory;
PacletDataRebuild[ ];
PacletDirectoryLoad @ $pacletDirectory;
Get[ "Wolfram`Chatbook`" ];
If[ ! MemberQ[ $LoadedFiles, $mxFile ], cicd`ConsoleWarning[ "Warning: Paclet MX file was not loaded" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$TestNotebook*)
$TestNotebook = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WithTestNotebook*)
WithTestNotebook // ClearAll;
WithTestNotebook // Attributes = { HoldFirst };
WithTestNotebook // Options    = { NotebookClose -> True };

WithTestNotebook[ eval_, { args___ }, opts: OptionsPattern[ ] ] :=
    UsingFrontEnd @ Block[ { $TestNotebook = CreateTestChatNotebook @ args },
        WithCleanup[
            eval,
            If[ OptionValue @ NotebookClose, NotebookClose @ $TestNotebook ]
        ]
    ];

WithTestNotebook[ eval_, opts: $$rules ] :=
    WithTestNotebook[ eval, { }, opts ];

WithTestNotebook[ eval_, arg: Except[ _List ], opts: $$rules ] :=
    WithTestNotebook[ eval, { arg }, opts ];

WithTestNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateTestChatNotebook*)
CreateTestChatNotebook // ClearAll;

CreateTestChatNotebook[ opts: OptionsPattern[ ] ] :=
    CreateTestChatNotebook[ "ChatEnabled", opts ];

CreateTestChatNotebook[ content_List, opts: OptionsPattern[ ] ] :=
    CreateTestChatNotebook[ "ChatEnabled", content, opts ];

CreateTestChatNotebook[ "ChatEnabled", opts: OptionsPattern[ ] ] :=
    UsingFrontEnd @ CreateChatNotebook @ opts;

CreateTestChatNotebook[ "ChatDriven", opts: OptionsPattern[ ] ] :=
    UsingFrontEnd @ CreateChatDrivenNotebook @ opts;

CreateTestChatNotebook[ "ChatEnabled", cells: { ___Cell }, opts: OptionsPattern[ ] ] :=
    UsingFrontEnd @ CreateChatNotebook[ NotebookPut @ Notebook @ cells, opts ];

CreateTestChatNotebook[ "ChatDriven", cells: { ___Cell }, opts: OptionsPattern[ ] ] :=
    UsingFrontEnd @ With[ { nbo = CreateChatDrivenNotebook @ opts },
        SelectionMove[ nbo, All, Notebook ];
        NotebookWrite[ nbo, cells ];
        SelectionMove[ nbo, Before, Notebook ];
    ];

CreateTestChatNotebook[ type_String, cell_Cell, opts: OptionsPattern[ ] ] :=
    CreateTestChatNotebook[ type, { cell }, opts ];

CreateTestChatNotebook[ type_String, content_List, opts: OptionsPattern[ ] ] :=
    CreateTestChatNotebook[ type, CreateChatCells @ content, opts ];

CreateTestChatNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateChatCells*)
CreateChatCells // ClearAll;
CreateChatCells[ arg: Except[ _List ] ] := CreateChatCells @ { arg };
CreateChatCells[ arg: { Except[ $$rules ], $$rules } ] := CreateChatCells @ { arg };
CreateChatCells[ args_List ] := CreateChatCell /@ args;
CreateChatCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateChatCell*)
CreateChatCell // ClearAll;

CreateChatCell[ cell_Cell ] := cell;
CreateChatCell[ input_String ] := Cell[ input, "ChatInput" ];
CreateChatCell[ Delimiter ] := Cell[ "", "ChatDelimiter" ];

CreateChatCell[ { arg_, opts___ } ] :=
    With[ { cell = CreateChatCell @ arg, as = Association @ opts },
        Append[ cell, TaggingRules -> <| "ChatNotebookSettings" -> KeyMap[ ToString, as ] |> ] /;
            MatchQ[ cell, _Cell ] && AssociationQ @ as
    ];

CreateChatCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting Helpers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FormatMarkdown*)
(* Gives the list of TextData items that FormatChatOutput creates for a markdown string: *)
FormatMarkdown // ClearAll;
FormatMarkdown[ md_String ] := FormatMarkdown[ md, "Finished" ];
FormatMarkdown[ md_String, status: "Finished"|"Streaming" ] :=
    Replace[
        Wolfram`Chatbook`FormatChatOutput[ md, <| "Status" -> status |> ],
        {
            RawBoxes @ Cell[ TextData[ items_List ], ___ ] :> items,
            RawBoxes @ Cell[ TextData[ item_ ], ___ ] :> { item },
            other_ :> abort[ "Unexpected FormatChatOutput result: ", other ]
        }
    ];
FormatMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*NormalizeTextData*)
(* Removes differences that are not visible: adjacent strings are joined, empty strings are dropped, and spaces before
   a line break are removed. Applies to TextData nested at any depth too. *)
NormalizeTextData // ClearAll;
NormalizeTextData[ items_List ] := normalizeTextDataList[ normalizeNestedTextData /@ Flatten @ items ];
NormalizeTextData[ TextData[ items_ ] ] := TextData @ NormalizeTextData @ Flatten @ { items };
NormalizeTextData[ other_ ] := normalizeNestedTextData @ other;

(* Joins adjacent strings, drops empty strings, and removes spaces before line breaks: *)
normalizeTextDataList[ items_List ] :=
    DeleteCases[
        Flatten @ Replace[
            SplitBy[ items, StringQ ],
            { strings__String } :> StringReplace[ StringJoin @ strings, " ".. ~~ "\n" -> "\n" ],
            { 1 }
        ],
        ""
    ];

(* Normalizes the TextData anywhere inside an item, e.g. in the BoxData of a heading or a thoughts box: *)
normalizeNestedTextData[ expr_ ] :=
    ReplaceAll[ expr, TextData[ items_ ] :> TextData @ NormalizeTextData @ Flatten @ { items } ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MarkdownRoundTrip*)
(* Formats a markdown string and serializes the result back to a string, as is done for chat history: *)
MarkdownRoundTrip // ClearAll;
MarkdownRoundTrip[ md_String ] := MarkdownRoundTrip[ md, "Finished" ];
MarkdownRoundTrip[ md_String, status_String ] :=
    Wolfram`Chatbook`CellToString @ Cell[ TextData @ FormatMarkdown[ md, status ], "ChatOutput" ];
MarkdownRoundTrip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ConstructWorkspaceContextMessages*)
ConstructWorkspaceContextMessages // ClearAll;

ConstructWorkspaceContextMessages[ cells: { __Cell }, settings0_Association, messages: { __Association } ] :=
    UsingFrontEnd @ Module[ { nb, settings },
        WithCleanup[
            nb = NotebookPut @ Notebook @ cells;
            SelectionMove[ Last @ Cells @ nb, All, Cell ];
            settings = <|
                AbsoluteCurrentChatSettings @ nb,
                "AllowSelectionContext" -> True,
                "FocusedNotebook"       -> nb,
                "PromptGenerators"      -> { },
                "Tools"                 -> { },
                settings0
            |>;
            Block[
                {
                    Wolfram`Chatbook`$WorkspaceChat             = True,
                    Wolfram`Chatbook`Common`$evaluationNotebook = nb,
                    Wolfram`Chatbook`Common`$multimodalMessages = TrueQ @ settings[ "Multimodal" ]
                },
                Wolfram`Chatbook`Common`constructMessages[ settings, messages ]
            ],
            NotebookClose @ nb
        ]
    ];

ConstructWorkspaceContextMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
$TestDefinitionsLoaded = True;
(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
