(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Common`" ];

`$maxChatCells;
`$closedChatCellOptions;

`$chatDelimiterStyles;
`$chatIgnoredStyles;
`$chatInputStyles;
`$chatOutputStyles;
`$excludeHistoryStyles;
`$$chatDelimiterStyle;
`$$chatIgnoredStyle;
`$$chatInputStyle;
`$$chatOutputStyle;
`$$excludeHistoryStyle;

`$catchTopTag;
`beginDefinition;
`catchTop;
`catchMine;
`catchTopAs;
`endDefinition;
`messageFailure;
`throwFailure;
`throwInternalFailure;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$chatDelimiterStyles  = { "ChatContextDivider", "ChatDelimiter", "ExcludedChatDelimiter" };
$chatIgnoredStyles    = { "ChatExcluded" };
$chatInputStyles      = { "ChatInput", "ChatInputSingle", "ChatQuery", "ChatSystemInput" };
$chatOutputStyles     = { "ChatOutput" };
$excludeHistoryStyles = { "ChatInputSingle" };

$maxChatCells = OptionValue[ CreateChatNotebook, "ChatHistoryLength" ];

$closedChatCellOptions :=
    If[ TrueQ @ CloudSystem`$CloudNotebooks,
        Sequence @@ { },
        Sequence @@ { CellMargins -> -2, CellOpen -> False, CellFrame -> 0, ShowCellBracket -> False }
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Style Patterns*)
$$chatDelimiterStyle  = Alternatives @@ $chatDelimiterStyles  | { ___, Alternatives @@ $chatDelimiterStyles , ___ };
$$chatIgnoredStyle    = Alternatives @@ $chatIgnoredStyles    | { ___, Alternatives @@ $chatIgnoredStyles   , ___ };
$$chatInputStyle      = Alternatives @@ $chatInputStyles      | { ___, Alternatives @@ $chatInputStyles     , ___ };
$$chatOutputStyle     = Alternatives @@ $chatOutputStyles     | { ___, Alternatives @@ $chatOutputStyles    , ___ };
$$excludeHistoryStyle = Alternatives @@ $excludeHistoryStyles | { ___, Alternatives @@ $excludeHistoryStyles, ___ };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::Internal =
"An unexpected error occurred. `1`";

Chatbook::NoAPIKey =
"No API key defined.";

Chatbook::InvalidAPIKey =
"Invalid value for API key: `1`";

Chatbook::UnknownResponse =
"Unexpected response from OpenAI server";

Chatbook::RateLimitReached =
"Rate limit reached for requests. Please try again later.";

Chatbook::UnknownStatusCode =
"Unexpected response from OpenAI server with status code `StatusCode`";

Chatbook::BadResponseMessage =
"`1`";

Chatbook::NotImplemented =
"Action \"`1`\" is not implemented.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
$debug           = True;
$failed          = False;
$inDef           = False;
$internalFailure = None;
$messageSymbol   = Chatbook;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*beginDefinition*)
beginDefinition // ClearAll;
beginDefinition // Attributes = { HoldFirst };
beginDefinition::Unfinished =
"Starting definition for `1` without ending the current one.";

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
beginDefinition[ s_Symbol ] /; $debug && $inDef :=
    WithCleanup[
        $inDef = False
        ,
        Print @ TemplateApply[ beginDefinition::Unfinished, HoldForm @ s ];
        beginDefinition @ s
        ,
        $inDef = True
    ];
(* :!CodeAnalysis::EndBlock:: *)

beginDefinition[ s_Symbol ] := WithCleanup[ Unprotect @ s; ClearAll @ s, $inDef = True ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*endDefinition*)
endDefinition // beginDefinition;
endDefinition // Attributes = { HoldFirst };

endDefinition[ s_Symbol ] := endDefinition[ s, DownValues ];

endDefinition[ s_Symbol, None ] := $inDef = False;

endDefinition[ s_Symbol, DownValues ] :=
    WithCleanup[
        AppendTo[ DownValues @ s, e: HoldPattern @ s[ ___ ] :> throwInternalFailure @ e ],
        $inDef = False
    ];

endDefinition[ s_Symbol, SubValues ] :=
    WithCleanup[
        AppendTo[ SubValues @ s, e: HoldPattern @ s[ ___ ][ ___ ] :> throwInternalFailure @ e ],
        $inDef = False
    ];

endDefinition[ s_Symbol, list_List ] := (endDefinition[ s, #1 ] &) /@ list;

endDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Error Handling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchTopAs*)
catchTopAs // beginDefinition;
catchTopAs[ sym_Symbol ] := Function[ eval, catchTop[ eval, sym ], { HoldAllComplete } ];
catchTopAs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchTop*)
catchTop // beginDefinition;
catchTop // Attributes = { HoldFirst };

catchTop[ eval_ ] := catchTop[ eval, Chatbook ];

catchTop[ eval_, sym_Symbol ] :=
    Block[
        {
            $messageSymbol = Replace[ $messageSymbol, Chatbook -> sym ],
            $catching      = True,
            $failed        = False,
            catchTop       = # &,
            catchTopAs     = (#1 &) &
        },
        Catch[ eval, $catchTopTag ]
    ];

catchTop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchMine*)
catchMine // beginDefinition;
catchMine // Attributes = { HoldFirst };
catchMine /: HoldPattern[ f_Symbol[ args___ ] := catchMine[ rhs_ ] ] := f[ args ] := catchTop[ rhs, f ];
catchMine[ eval_ ] := catchTop @ eval;
catchMine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*throwFailure*)
throwFailure // beginDefinition;
throwFailure // Attributes = { HoldFirst };

throwFailure[ msg_, args___ ] :=
    With[ { failure = messageFailure[ msg, args ] },
        If[ TrueQ @ $catching,
            Throw[ failure, $catchTopTag ],
            failure
        ]
    ];

throwFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*messageFailure*)
messageFailure // beginDefinition;
messageFailure // Attributes = { HoldFirst };

messageFailure[ t_String, args___ ] :=
    With[ { s = $messageSymbol },
        If[ StringQ @ MessageName[ s, t ],
            messageFailure[ MessageName[ s, t ], args ],
            If[ StringQ @ MessageName[ Chatbook, t ],
                blockProtected[ { s }, MessageName[ s, t ] = MessageName[ Chatbook, t ] ];
                messageFailure[ MessageName[ s, t ], args ],
                throwInternalFailure @ messageFailure[ t, args ]
            ]
        ]
    ];

messageFailure[ args___ ] :=
    Module[ { quiet, message },
        quiet   = If[ TrueQ @ $failed, Quiet, Identity ];
        message = messageFailure0;
        WithCleanup[
            StackInhibit @ quiet @ message @ args,
            $failed = True
        ]
    ];

messageFailure // endDefinition;

messageFailure0 := messageFailure0 = Block[ { PrintTemporary }, ResourceFunction[ "MessageFailure", "Function" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*messagePrint*)
messagePrint // beginDefinition;
messagePrint // Attributes = { HoldFirst };
messagePrint[ args___ ] := WithCleanup[ $failed = False, messageFailure @ args, $failed = False ];
messagePrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*blockProtected*)
blockProtected // beginDefinition;
blockProtected // Attributes = { HoldAll };
blockProtected[ { s___Symbol }, eval_ ] := Module[ { p }, WithCleanup[ p = Unprotect @ s, eval, Protect @@ p ] ];
blockProtected[ s_Symbol, eval_ ] := blockProtected[ { s }, eval ];
blockProtected // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*throwInternalFailure*)
throwInternalFailure // beginDefinition;
throwInternalFailure // Attributes = { HoldFirst };

throwInternalFailure[ HoldForm[ eval_ ], a___ ] := throwInternalFailure[ eval, a ];

throwInternalFailure[ eval_, a___ ] :=
    Block[ { $internalFailure = $lastInternalFailure = makeInternalFailureData[ eval, a ] },
        throwFailure[ Chatbook::Internal, $bugReportLink, $internalFailure ]
    ];

throwInternalFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInternalFailureData*)
makeInternalFailureData // Attributes = { HoldFirst };

makeInternalFailureData[ eval_, Failure[ tag_, as_Association ], args___ ] := maskOpenAIKey @ <|
    "Evaluation" :> eval,
    "Failure"    -> Failure[ tag, Association[ KeyTake[ as, "Information" ], as ] ],
    "Arguments"  -> { args }
|>;

makeInternalFailureData[ eval_, args___ ] := maskOpenAIKey @ <| "Evaluation" :> eval, "Arguments" -> { args } |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bug Report Link Generation*)

$issuesURL = "https://github.com/WolframResearch/Chatbook/issues/new";

$maxBugReportURLSize = 3500;
(*
    RFC 7230 recommends clients support 8000: https://www.rfc-editor.org/rfc/rfc7230#section-3.1.1
    Long bug report links might not work in old versions of IE,
    but using IE these days should probably be considered user error.
*)

$maxPartLength = 500;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$bugReportLink*)
$bugReportLink := Hyperlink[
    "Report this issue \[RightGuillemet]",
    trimURL @ URLBuild[ $issuesURL, { "title" -> "Insert Title Here", "labels" -> "bug", "body" -> bugReportBody[ ] } ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*bugReportBody*)
bugReportBody[ ] := bugReportBody @ PacletObject[ "Wolfram/Chatbook" ][ "PacletInfo" ];

bugReportBody[ as_Association? AssociationQ ] :=
    TemplateApply[
        $bugReportBodyTemplate,
        TemplateVerbatim /@ <|
            "DebugData" -> associationMarkdown[
                KeyTake[ as, { "Name", "Version" } ],
                "EvaluationEnvironment" -> $EvaluationEnvironment,
                "FrontEndVersion"       -> $frontEndVersion,
                "KernelVersion"         -> SystemInformation[ "Kernel", "Version" ],
                "SystemID"              -> $SystemID,
                "Notebooks"             -> $Notebooks,
                "DynamicEvaluation"     -> $DynamicEvaluation,
                "SynchronousEvaluation" -> $SynchronousEvaluation,
                "TaskEvaluation"        -> MatchQ[ $CurrentTask, _TaskObject ]
            ],
            "Stack"           -> $bugReportStack,
            "Settings"        -> associationMarkdown @ maskOpenAIKey @ $settings,
            "InternalFailure" -> markdownCodeBlock @ $internalFailure
        |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$bugReportBodyTemplate*)
$bugReportBodyTemplate = StringTemplate[ "\
Describe the issue in detail here. Attach any relevant screenshots or files. \
The section below was automatically generated. \
Remove any information that you do not wish to include in the report.

<details>
<summary>Debug Data</summary>

%%DebugData%%

## Settings

%%Settings%%

## Stack Data
```
%%Stack%%
```

## Failure Data

%%InternalFailure%%

</details>",
Delimiters -> "%%"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$frontEndVersion*)
$frontEndVersion :=
    If[ TrueQ @ CloudSystem`$CloudNotebooks,
        StringJoin[ "Cloud: ", ToString @ $CloudVersion ],
        StringJoin[ "Desktop: ", ToString @ UsingFrontEnd @ SystemInformation[ "FrontEnd", "Version" ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$bugReportStack*)
$bugReportStack := StringRiffle[
    Replace[
        DeleteAdjacentDuplicates @ Cases[
            Stack[ _ ],
            HoldForm[ (s_Symbol) | (s_Symbol)[ ___ ] | (s_Symbol)[ ___ ][ ___ ] ] /;
                AtomQ @ Unevaluated @ s && StringStartsQ[ Context @ s, "Wolfram`Chatbook`" ] :>
                    SymbolName @ Unevaluated @ s
        ],
        { a___, "throwInternalFailure", ___ } :> { a, "throwInternalFailure" }
    ],
    "\n"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$settings*)
$settings := Module[ { settings, assoc },
    settings = CurrentValue @ { TaggingRules, "ChatNotebookSettings" };
    assoc = Association @ settings;
    If[ AssociationQ @ assoc,
        KeyDrop[ assoc, "OpenAIKey" ],
        settings
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*trimURL*)
(* cSpell: ignore Fdetails *)
trimURL[ url_String ] := trimURL[ url, $maxBugReportURLSize ];

trimURL[ url_String, limit_Integer ] /; StringLength @ url <= limit := url;

trimURL[ url_String, limit_Integer ] :=
    Module[ { sp, bt, nl, before, after, base, take },
        sp     = ("+"|"%20")...;
        bt     = URLEncode[ "```" ];
        nl     = (URLEncode[ "\r\n" ] | URLEncode[ "\n" ])...;
        before = Longest[ "%23%23"~~sp~~"Failure"~~sp~~"Data"~~nl~~bt~~nl ];
        after  = Longest[ nl~~bt~~nl~~"%3C%2Fdetails%3E" ];
        base   = StringLength @ StringReplace[ url, a: before ~~ ___ ~~ b: after :> a <> "\n" <> b ];
        take   = UpTo @ Max[ limit - base, 80 ];
        With[ { t = take }, StringReplace[ url, a: before ~~ b__ ~~ c: after :> a <> StringTake[ b, t ] <> "\n" <> c ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*associationMarkdown*)
associationMarkdown[ data_Association? AssociationQ ] := StringJoin[
    "| Property | Value |\n| --- | --- |\n",
    StringRiffle[
        KeyValueMap[
            Function[
                { k, v },
                StringJoin @ StringJoin[
                    "| ",
                    ToString @ ToString[ Unevaluated @ k, CharacterEncoding -> "UTF-8" ],
                    " | ``",
                    truncatePartString @ ToString[ Unevaluated @ v, InputForm, CharacterEncoding -> "UTF-8" ],
                    "`` |"
                ],
                HoldAllComplete
            ],
            data
        ],
        "\n"
    ]
];

associationMarkdown[ rules___ ] := With[ { as = Association @ rules }, associationMarkdown @ as /; AssociationQ @ as ];
associationMarkdown[ other_   ] := markdownCodeBlock @ other;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*maskOpenAIKey*)
maskOpenAIKey[ expr_ ] :=
    With[ { mask = "**********" },
        ReplaceAll[
            expr /. HoldPattern[ "OpenAIKey" -> Except[ mask, _String ] ] :> ("OpenAIKey" -> mask),
            a: (KeyValuePattern[ "OpenAIKey" -> Except[ mask, _String ] ])? AssociationQ :>
                RuleCondition @ Insert[ a, "OpenAIKey" -> mask, Key[ "OpenAIKey" ] ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*markdownCodeBlock*)
markdownCodeBlock[ as_Association? AssociationQ ] :=
    "```\n<|\n" <> StringRiffle[ ruleToString /@ Normal[ as, Association ], "\n" ] <> "\n|>\n```\n";

markdownCodeBlock[ expr_ ] := StringJoin[
    "```\n",
    StringTake[ ToString[ expr, InputForm, PageWidth -> $maxPartLength ], UpTo @ $maxBugReportURLSize ],
    "\n```\n"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ruleToString*)
ruleToString[ a_ -> b_ ] := StringJoin[
    "  ",
    ToString[ Unevaluated @ a, InputForm ],
    " -> ",
    truncatePartString @ ToString[ Unevaluated @ b, InputForm ]
];

ruleToString[ a_ :> b_ ] := StringJoin[
    "  ",
    ToString[ Unevaluated @ a, InputForm ],
    " :> ",
    truncatePartString @ ToString[ Unevaluated @ b, InputForm ]
];

ruleToString[ other_ ] := truncatePartString @ ToString[ Unevaluated @ other, InputForm ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*truncatePartString*)
truncatePartString[ string_ ] := truncatePartString[ string, $maxPartLength ];

truncatePartString[ string_String, max_Integer ] :=
    If[ StringLength @ string > max, StringTake[ string, UpTo @ max ] <> "...", string ];

truncatePartString[ other_, max_Integer ] := truncatePartString[ ToString[ Unevaluated @ other, InputForm ], max ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    $debug = False;
];

End[ ];
EndPackage[ ];