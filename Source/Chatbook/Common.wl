(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Common`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`$cloudNotebooks;
`$maxChatCells;
`$closedChatCellOptions;

`$chatDelimiterStyles;
`$chatIgnoredStyles;
`$chatInputStyles;
`$chatOutputStyles;
`$excludeHistoryStyles;
`$nestedCellStyles;
`$$chatDelimiterStyle;
`$$chatIgnoredStyle;
`$$chatInputStyle;
`$$chatOutputStyle;
`$$excludeHistoryStyle;
`$$nestedCellStyle;

`$$textDataList;

`$catchTopTag;
`beginDefinition;
`catchAlways;
`catchMine;
`catchTop;
`catchTopAs;
`endDefinition;
`importResourceFunction;
`messageFailure;
`messagePrint;
`throwFailure;
`throwInternalFailure;
`throwMessageDialog;
`throwTop;

`chatbookIcon;
`inlineTemplateBox;
`inlineTemplateBoxes;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`" ];

$cloudNotebooks := TrueQ @ CloudSystem`$CloudNotebooks;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$chatDelimiterStyles  = { "ChatBlockDivider", "ChatDelimiter", "ExcludedChatDelimiter" };
$chatIgnoredStyles    = { "ChatExcluded" };
$chatInputStyles      = { "ChatInput", "SideChat", "ChatQuery", "ChatSystemInput" };
$chatOutputStyles     = { "ChatOutput", "AssistantOutput", "AssistantOutputWarning", "AssistantOutputError" };
$excludeHistoryStyles = { "SideChat" };
$nestedCellStyles     = { "InlineFunctionReference", "InlineModifierReference", "InlinePersonaReference",
                          "ChatMenu", "ChatWidget", "InheritFromParent"
                          (* TODO: add a style name to cell dingbat cells and add it here *)
                        };

$maxChatCells := OptionValue[ CreateChatNotebook, "ChatHistoryLength" ];

$closedChatCellOptions :=
    If[ TrueQ @ $cloudNotebooks,
        Sequence @@ { },
        Sequence @@ { CellMargins -> -2, CellOpen -> False, CellFrame -> 0, ShowCellBracket -> False }
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Style Patterns*)
cellStylePattern // beginDefinition;
cellStylePattern[ { styles__String } ] := styles | { ___, Alternatives @ styles , ___ };
cellStylePattern // endDefinition;

$$chatDelimiterStyle  = cellStylePattern @ $chatDelimiterStyles ;
$$chatIgnoredStyle    = cellStylePattern @ $chatIgnoredStyles;
$$chatInputStyle      = cellStylePattern @ $chatInputStyles;
$$chatOutputStyle     = cellStylePattern @ $chatOutputStyles;
$$excludeHistoryStyle = cellStylePattern @ $excludeHistoryStyles;
$$nestedCellStyle     = cellStylePattern @ $nestedCellStyles;

$$textDataList        = { (_String|_Cell|_StyleBox|_ButtonBox)... };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
KeyValueMap[ Function[ MessageName[ Chatbook, #1 ] = #2 ], <|
    "APIKeyOrganizationID"            -> "The value specified for the API key appears to be an organization ID instead of an API key. Visit `1` to manage your API keys.",
    "BadResponseMessage"              -> "`1`",
    "ChannelFrameworkError"           -> "The channel framework is currently unavailable, please try installing from URL instead or try again later.",
    "ConnectionFailure"               -> "Server connection failure: `1`. Please try again later.",
    "ConnectionFailure2"              -> "Could not get a valid response from the server: `1`. Please try again later.",
    "ExpectedInstallableResourceType" -> "Expected a resource of type `1` instead of `2`.",
    "Internal"                        -> "An unexpected error occurred. `1`",
    "InvalidAPIKey"                   -> "Invalid value for API key: `1`",
    "InvalidArguments"                -> "Invalid arguments given for `1` in `2`.",
    "InvalidResourceSpecification"    -> "The argument `1` is not a valid resource specification.",
    "InvalidResourceURL"              -> "The specified URL does not represent a valid resource object.",
    "InvalidStreamingOutputMethod"    -> "Invalid streaming output method: `1`.",
    "ModelToolSupport"                -> "The model `1` does not support tools.",
    "NoAPIKey"                        -> "No API key defined.",
    "NoSandboxKernel"                 -> "Unable to start a sandbox kernel. This may mean that the number of currently running kernels exceeds the limit defined by $LicenseProcesses.",
    "NotImplemented"                  -> "Action \"`1`\" is not implemented.",
    "NotInstallableResourceType"      -> "Resource type `1` is not an installable resource type for chat notebooks. Valid types are `2`.",
    "RateLimitReached"                -> "Rate limit reached for requests. Please try again later.",
    "ResourceNotFound"                -> "Resource `1` not found.",
    "ResourceNotInstalled"            -> "The resource `1` is not installed.",
    "ServerOverloaded"                -> "The server is currently overloaded with other requests. Please try again later.",
    "ToolNotFound"                    -> "Tool `1` not found.",
    "UnknownResponse"                 -> "Unexpected response from OpenAI server",
    "UnknownStatusCode"               -> "Unexpected response from OpenAI server with status code `StatusCode`"
|> ];

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
(*optimizeEnclosures*)
optimizeEnclosures // ClearAll;
optimizeEnclosures // Attributes = { HoldFirst };
optimizeEnclosures[ s_Symbol ] := DownValues[ s ] = optimizeEnclosures0 @ DownValues @ s;

optimizeEnclosures0 // ClearAll;
optimizeEnclosures0[ expr_ ] :=
    ReplaceAll[
        expr,
        HoldPattern[ e: Enclose[ _ ] | Enclose[ _, _ ] ] :>
            With[ { new = addEnclosureTags[ e, $ConditionHold ] },
                RuleCondition[ new, True ]
            ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addEnclosureTags*)
addEnclosureTags // ClearAll;
addEnclosureTags // Attributes = { HoldFirst };

addEnclosureTags[ Enclose[ expr_ ], wrapper_ ] :=
    addEnclosureTags[ Enclose[ expr, #1 & ], wrapper ];

addEnclosureTags[ Enclose[ expr_, func_ ], wrapper_ ] :=
    Module[ { held, replaced },
        held = HoldComplete @ expr;
        replaced = held /. $enclosureTagRules;
        Replace[ replaced, HoldComplete[ e_ ] :> wrapper @ Enclose[ e, func, $enclosure ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$enclosureTagRules*)
$enclosureTagRules // ClearAll;
(* :!CodeAnalysis::Disable::NoSurroundingEnclose:: *)
$enclosureTagRules := $enclosureTagRules = Dispatch @ {
    expr_Enclose                                      :> expr,

    HoldPattern @ Confirm[ expr_ ]                    :> Confirm[ expr, Null, $enclosure ],
    HoldPattern @ Confirm[ expr_, info_ ]             :> Confirm[ expr, info, $enclosure ],

    HoldPattern @ ConfirmBy[ expr_, f_ ]              :> ConfirmBy[ expr, f, Null, $enclosure ],
    HoldPattern @ ConfirmBy[ expr_, f_, info_ ]       :> ConfirmBy[ expr, f, info, $enclosure ],

    HoldPattern @ ConfirmMatch[ expr_, patt_ ]        :> ConfirmMatch[ expr, patt, Null, $enclosure ],
    HoldPattern @ ConfirmMatch[ expr_, patt_, info_ ] :> ConfirmMatch[ expr, patt, info, $enclosure ],

    HoldPattern @ ConfirmQuiet[ expr_ ]               :> ConfirmQuiet[ expr, All, Null, $enclosure ],
    HoldPattern @ ConfirmQuiet[ expr_, patt_ ]        :> ConfirmQuiet[ expr, patt, Null, $enclosure ],
    HoldPattern @ ConfirmQuiet[ expr_, patt_, info_ ] :> ConfirmQuiet[ expr, patt, info, $enclosure ],

    HoldPattern @ ConfirmAssert[ expr_ ]              :> ConfirmAssert[ expr, Null, $enclosure ],
    HoldPattern @ ConfirmAssert[ expr_, info_ ]       :> ConfirmAssert[ expr, info, $enclosure ]
};

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
        optimizeEnclosures @ s;
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
(*Resource Functions*)
importResourceFunction // beginDefinition;
importResourceFunction::failure = "[ERROR] Failed to import resource function `1`. Aborting MX build.";
importResourceFunction // Attributes = { HoldFirst };

importResourceFunction[ symbol_Symbol, name_String ] /; Wolfram`ChatbookInternal`$BuildingMX := Enclose[
    Block[ { PrintTemporary },
        Module[ { sourceContext, targetContext, definition, replaced, newSymbol },

            sourceContext = ConfirmBy[ ResourceFunction[ name, "Context" ], StringQ ];
            targetContext = "Wolfram`Chatbook`ResourceFunctions`"<>name<>"`";
            definition    = ConfirmMatch[ ResourceFunction[ name, "DefinitionList" ], _Language`DefinitionList ];

            replaced = ConfirmMatch[
                ResourceFunction[ "ReplaceContext" ][ definition, sourceContext -> targetContext ],
                _Language`DefinitionList
            ];

            ConfirmMatch[ Language`ExtendedFullDefinition[ ] = replaced, _Language`DefinitionList ];

            newSymbol = ConfirmMatch[ Symbol[ targetContext<>name ], _Symbol? AtomQ ];

            ConfirmMatch[ symbol = newSymbol, newSymbol ]
        ]
    ],
    (Message[ importResourceFunction::failure, name ]; Abort[ ]) &
];

importResourceFunction[ symbol_Symbol, name_String ] :=
    symbol := symbol = Block[ { PrintTemporary }, ResourceFunction[ name, "Function" ] ];

importResourceFunction // endDefinition;

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
(*catchAlways*)
catchAlways // beginDefinition;
catchAlways // Attributes = { HoldFirst };
catchAlways[ eval_ ] := catchAlways[ eval, Chatbook ];
catchAlways[ eval_, sym_Symbol ] := Catch[ catchTop[ eval, sym ], $catchTopTag ];
catchAlways // endDefinition;

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
(*throwTop*)
throwTop // beginDefinition;
throwTop[ expr_ ] /; $catching := Throw[ Unevaluated @ expr, $catchTopTag ];
throwTop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*throwMessageDialog*)
throwMessageDialog // beginDefinition;

throwMessageDialog[ t_String, args___ ] /; StringQ @ MessageName[ Chatbook, t ] :=
    With[ { s = $messageSymbol },
        blockProtected[ { s }, MessageName[ s, t ] = MessageName[ Chatbook, t ] ];
        throwMessageDialog @ TemplateApply[
            MessageName[ s, t ],
            Replace[ { args }, { as_Association } :> as ],
            InsertionFunction -> Function @ ToString[ Short @ #, PageWidth -> 60 ]
        ]
    ];

throwMessageDialog[ message_ ] :=
    throwTop @ DefinitionNotebookClient`FancyMessageDialog[ "Chatbook", message ];

throwMessageDialog // endDefinition;

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

(* https://resources.wolframcloud.com/FunctionRepository/resources/MessageFailure *)
importResourceFunction[ messageFailure0, "MessageFailure" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*messagePrint*)
messagePrint // Attributes = { HoldFirst };
messagePrint[ args___ ] := WithCleanup[ $failed = False, messageFailure @ args, $failed = False ];

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

makeInternalFailureData[ eval_, Failure[ tag_, as_Association ], args___ ] :=
    StackInhibit @ Module[ { $stack = Stack[ _ ] },
        maskOpenAIKey @ <|
            "Evaluation" :> eval,
            "Failure"    -> Failure[ tag, Association[ KeyTake[ as, "Information" ], as ] ],
            "Arguments"  -> { args },
            "Stack"      :> $stack
        |>
    ];

makeInternalFailureData[ eval_, args___ ] :=
    StackInhibit @ Module[ { $stack = Stack[ _ ] },
        maskOpenAIKey @ <|
            "Evaluation" :> eval,
            "Arguments"  -> { args },
            "Stack"      :> $stack
        |>
    ];

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
                KeyTake[ as, { "Name", "Version", "ReleaseID" } ],
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
    If[ TrueQ @ $cloudNotebooks,
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
$settings := Module[ { settings, styleInfo, assoc },
    settings  = CurrentValue @ { TaggingRules, "ChatNotebookSettings" };
    styleInfo = CurrentValue @ { StyleDefinitions, "ChatStyleSheetInformation", TaggingRules };
    assoc     = Association @ Select[ Association /@ { settings, styleInfo }, AssociationQ ];
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
                    escapePipes @ truncatePartString @ ToString[
                        Unevaluated @ v,
                        InputForm,
                        CharacterEncoding -> "UTF-8"
                    ],
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
(* ::Subsubsection::Closed:: *)
(*escapePipes*)
escapePipes[ string_String ] := StringReplace[ string, "|" -> "\\|" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Assets*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatbookIcon*)
(*
    Gets an icon by name.
    The second argument specifies whether it is returned as a `TemplateBox` or the full expression.
    For efficiency, only use `False` when a template box cannot be used, i.e. when the stylesheet is not accessible.
*)
chatbookIcon // beginDefinition;
chatbookIcon[ name_String ] := chatbookIcon[ name, True ];
chatbookIcon[ name_String, True  ] := chatbookIcon[ name, Lookup[ $chatbookIcons, name ] ];
chatbookIcon[ name_String, False ] := inlineTemplateBox @ chatbookIcon[ name, True ];
chatbookIcon[ name_String, icon: Except[ _Missing ] ] := icon;
chatbookIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineTemplateBox*)
inlineTemplateBox // beginDefinition;

inlineTemplateBox[ TemplateBox[ args_, name_String ] ] :=
    With[ { func = $templateBoxDisplayFunctions @ name },
        TemplateBox[ args, name, DisplayFunction -> func ] /; MatchQ[ func, _Function ]
    ];

inlineTemplateBox[ RawBoxes[ box_TemplateBox ] ] :=
    RawBoxes @ inlineTemplateBox @ box;

inlineTemplateBox[ expr_ ] := expr;

inlineTemplateBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineTemplateBoxes*)
inlineTemplateBoxes // beginDefinition;

inlineTemplateBoxes[ expr_ ] :=
    ReplaceAll[
        expr,
        TemplateBox[ args_, name_String ] :>
            With[ { func = inlineTemplateBoxes @ $templateBoxDisplayFunctions @ name },
                TemplateBox[ args, name, DisplayFunction -> func ] /; MatchQ[ func, _Function ]
            ]
    ];

inlineTemplateBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$chatbookIcons*)
$chatbookIcons := $chatbookIcons =
    Developer`ReadWXFFile @ PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "Icons" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$templateBoxDisplayFunctions*)
$templateBoxDisplayFunctions := $templateBoxDisplayFunctions =
    Developer`ReadWXFFile @ PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "DisplayFunctions" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $debug = False;
    $chatbookIcons;
    $templateBoxDisplayFunctions;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];