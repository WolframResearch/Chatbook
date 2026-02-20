(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Sandbox`" ];
Begin[ "`Private`" ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

$ContextAliases[ "sp`" ] = "Wolfram`Chatbook`SandboxParsing`";
(* :!CodeAnalysis::Disable::UnexpectedLetterlikeCharacter:: *)
sp`\[FreeformPrompt];
sp`InlinedExpression;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$SandboxKernel             = None;
$appendURIPrompt          := toolOptionValue[ "WolframLanguageEvaluator", "AppendURIPrompt"          ];
$includeDefinitions       := toolOptionValue[ "WolframLanguageEvaluator", "IncludeDefinitions"       ];
$sandboxEvaluationTimeout := toolOptionValue[ "WolframLanguageEvaluator", "EvaluationTimeConstraint" ];
$sandboxPingTimeout       := toolOptionValue[ "WolframLanguageEvaluator", "PingTimeConstraint"       ];
$evaluatorMethod          := toolOptionValue[ "WolframLanguageEvaluator", "Method"                   ];
$readPaths                := toolOptionValue[ "WolframLanguageEvaluator", "AllowedReadPaths"         ];
$writePaths               := toolOptionValue[ "WolframLanguageEvaluator", "AllowedWritePaths"        ];
$executePaths             := toolOptionValue[ "WolframLanguageEvaluator", "AllowedExecutePaths"      ];
$cloudEvaluatorLocation    = "/Chatbook/Tools/WolframLanguageEvaluator/Evaluate";
$cloudLineNumber           = 1;
$cloudSession              = None;
$maxSandboxMessages        = 10;
$maxMessageParameterLength = 100;
$toolOutputPageWidth       = 100;
$kernelQuit                = False;
$verifiedResult            = True;

(* Tests for expressions that lose their initialized status when sending over a link: *)
$initializationTests = Join[

    (* Pattern matching: *)
    HoldComplete @@ Cases[
        HoldComplete[
            _AstroPosition? Astronomy`AstroPositionQ,
            _ChatObject? System`Private`HoldNoEntryQ,
            _Dataset? System`Private`HoldNoEntryQ,
            _Rational? AtomQ
        ],
        p_ :> Function[ Null, MatchQ[ Unevaluated @ #, p ], HoldAllComplete ]
    ],

    (* Test functions that need to hold their argument: *)
    HoldComplete @@ Cases[
        HoldComplete[
            AudioQ,
            BoundaryMeshRegionQ,
            DateObjectQ,
            GraphQ,
            MeshRegionQ,
            SparseArrayQ,
            TimeObjectQ,
            TreeQ,
            VideoQ
        ],
        q_ :> Function[ Null, q @ Unevaluated @ #, HoldAllComplete ]
    ],

    (* Test functions that already hold: *)
    HoldComplete[
        StructuredArray`HeldStructuredArrayQ
    ]
];

$sandboxKernelCommandLine := StringRiffle @ {
    ToString[
        If[ $OperatingSystem === "Windows",
            FileNameJoin @ { $InstallationDirectory, "WolframKernel" },
            First @ $CommandLine
        ],
        InputForm
    ],
    "-wstp",
    "-noicon",
    "-noinit",
    "-pacletreadonly",
    "-run",
    "ChatbookSandbox" <> ToString @ $ProcessID
};

$$outputForm := $$outputForm = Alternatives @@ $OutputForms;

$nlpData = <| |>;

$$simpleTemplateBoxName = Alternatives[
    "DateObject",
    "Entity",
    "EntityClass",
    "EntityProperty",
    "Quantity",
    "QuantityMixedUnit1",
    "QuantityMixedUnit2",
    "QuantityMixedUnit3",
    "QuantityMixedUnit4",
    "QuantityMixedUnit5",
    "QuantityMixedUnit6",
    "QuantityPostfix",
    "QuantityPrefix"
];

$$holdFormH = (HoldForm|HoldCompleteForm);

$$probableFailure = Alternatives[
    $Aborted,
    $Canceled,
    $Failed,
    _Failure,
    _Missing
];

$$pathItem = _String | $$unspecified | ParentList | All | None | _Hold | _HoldComplete | _HoldCompleteForm;
$$pathSpec = $$pathItem | { $$pathItem... };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::InvalidEvaluatorCode     = "Invalid evaluator code: `1`.";
Chatbook::InvalidEvaluatorProperty = "Invalid evaluator property: `1`.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframLanguageToolEvaluate*)
WolframLanguageToolEvaluate // beginDefinition;

WolframLanguageToolEvaluate // Options = {
    "AllowedExecutePaths"   -> Automatic,
    "AllowedReadPaths"      -> Automatic,
    "AllowedWritePaths"     -> Automatic,
    "AppendRetryNotice"     -> False,
    "AppendURIInstructions" -> True,
    "IncludeDefinitions"    -> Automatic,
    "Line"                  -> Automatic,
    "MaxCharacterCount"     -> 10000,
    "Method"                -> Automatic,
    "PageWidth"             -> Infinity,
    "TimeConstraint"        -> 60
};

WolframLanguageToolEvaluate[ code_, opts: OptionsPattern[ ] ] :=
    catchMine @ WolframLanguageToolEvaluate[ Unevaluated @ code, "String", opts ];

WolframLanguageToolEvaluate[ code_? validCodeQ, property_? validPropertyQ, opts: OptionsPattern[ ] ] :=
    catchMine @ wolframLanguageToolEvaluate[
        code,
        property,
        optionsAssociation[ WolframLanguageToolEvaluate, opts ]
    ];

WolframLanguageToolEvaluate[ code_ /; ! validCodeQ @ code, property_, opts: OptionsPattern[ ] ] :=
    catchMine @ throwFailure[ "InvalidEvaluatorCode", HoldForm @ code ];

WolframLanguageToolEvaluate[ code_, property_ /; ! validPropertyQ @ property, opts: OptionsPattern[ ] ] :=
    catchMine @ throwFailure[ "InvalidEvaluatorProperty", HoldForm @ property ];

WolframLanguageToolEvaluate // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validCodeQ*)
validCodeQ // beginDefinition;
validCodeQ // Attributes = { HoldAllComplete };
validCodeQ[ code_String ] := StringQ @ code && ! StringMatchQ[ code, WhitespaceCharacter... ];
validCodeQ[ { __ } ] := True;
validCodeQ[ HoldComplete[ __ ] ] := True;
validCodeQ[ ___ ] := False;
validCodeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validPropertyQ*)
$$propertyName = "Packets"|"Result"|"SessionMX"|"String";

validPropertyQ // beginDefinition;
validPropertyQ[ $$propertyName ] := True;
validPropertyQ[ All|Automatic ] := True;
validPropertyQ[ { $$propertyName... } ] := True;
validPropertyQ[ ___ ] := False;
validPropertyQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*wolframLanguageToolEvaluate*)
wolframLanguageToolEvaluate // beginDefinition;
wolframLanguageToolEvaluate // Attributes = { HoldFirst };

wolframLanguageToolEvaluate[ code_, property_, opts_Association ] := Enclose[
    Block[
        {
            $returnFullResult         = True,
            $appendRetryNotice        = getOption[ "AppendRetryNotice"    , opts ],
            $appendURIInstructions    = getOption[ "AppendURIInstructions", opts ],
            $evaluatorMethod          = getOption[ "Method"               , opts ],
            $executePaths             = getOption[ "AllowedExecutePaths"  , opts ],
            $includeDefinitions       = getOption[ "IncludeDefinitions"   , opts ],
            $readPaths                = getOption[ "AllowedReadPaths"     , opts ],
            $sandboxEvaluationTimeout = getOption[ "TimeConstraint"       , opts ],
            $toolOutputPageWidth      = getOption[ "PageWidth"            , opts ],
            $toolResultStringLength   = getOption[ "MaxCharacterCount"    , opts ],
            $writePaths               = getOption[ "AllowedWritePaths"    , opts ],
            $Line                     = getOption[ "Line"                 , opts ]
        },
        getProperty[ sandboxEvaluate @ preprocessCodeForTool @ code, property ]
    ],
    throwInternalFailure
];

wolframLanguageToolEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getOption*)
getOption // beginDefinition;

getOption[ name_String, opts_Association ] := getOption[ name, Lookup[ opts, name ] ];

getOption[ "AppendRetryNotice", $$unspecified ] := False;
getOption[ "AppendRetryNotice", append: True|False ] := append;
getOption[ "AppendRetryNotice", append_ ] := throwFailure[ "InvalidOptionValue", "AppendRetryNotice", append ];

getOption[ "AppendURIInstructions", $$unspecified ] := True;
getOption[ "AppendURIInstructions", append: True|False ] := append;
getOption[ "AppendURIInstructions", append_ ] := throwFailure[ "InvalidOptionValue", "AppendURIInstructions", append ];

getOption[ "Method", $$unspecified ] := Automatic;
getOption[ "Method", method: "Cloud"|"Local"|"Session"|None ] := method;
getOption[ "Method", method_ ] := throwFailure[ "InvalidOptionValue", "Method", method ];

getOption[ "PageWidth", $$unspecified ] := $toolOutputPageWidth;
getOption[ "PageWidth", width: $$size ] := Floor @ width;
getOption[ "PageWidth", width_ ] := throwFailure[ "InvalidOptionValue", "PageWidth", width ];

getOption[ "MaxCharacterCount", $$unspecified ] := Infinity;
getOption[ "MaxCharacterCount", count_Integer? Positive ] := count;
getOption[ "MaxCharacterCount", All|Infinity ] := Infinity;
getOption[ "MaxCharacterCount", count_ ] := throwFailure[ "InvalidOptionValue", "MaxCharacterCount", count ];

getOption[ "TimeConstraint", $$unspecified ] := Infinity;
getOption[ "TimeConstraint", time_Integer? Positive ] := time;
getOption[ "TimeConstraint", Infinity ] := Infinity;
getOption[ "TimeConstraint", time_ ] := throwFailure[ "InvalidOptionValue", "TimeConstraint", time ];

getOption[ "Line", $$unspecified ] := $Line;
getOption[ "Line", line_Integer? Positive ] := line;
getOption[ "Line", line_ ] := throwFailure[ "InvalidOptionValue", "Line", line ];

getOption[ "IncludeDefinitions", $$unspecified ] := $includeDefinitions;
getOption[ "IncludeDefinitions", include: True|False ] := include;
getOption[ "IncludeDefinitions", include_ ] := throwFailure[ "InvalidOptionValue", "IncludeDefinitions", include ];

getOption[ "AllowedReadPaths"   , paths_ ] := getAllowedPaths[ "AllowedReadPaths"   , paths ];
getOption[ "AllowedWritePaths"  , paths_ ] := getAllowedPaths[ "AllowedWritePaths"  , paths ];
getOption[ "AllowedExecutePaths", paths_ ] := getAllowedPaths[ "AllowedExecutePaths", paths ];

getOption // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAllowedPaths*)
getAllowedPaths // beginDefinition;
getAllowedPaths[ name_, $$unspecified ] := $DefaultToolOptions[ "WolframLanguageEvaluator", name ];
getAllowedPaths[ name_, paths: $$pathSpec ] := paths;
getAllowedPaths[ name_String, paths_ ] := throwFailure[ "InvalidOptionValue", name, paths ];
getAllowedPaths // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getProperty*)
getProperty // beginDefinition;
getProperty[ as_Association, property_String ] := Lookup[ as, property ];
getProperty[ as_Association, All|Automatic ] := as;
getProperty[ as_Association, properties_List ] := AssociationMap[ getProperty[ as, # ] &, properties ];
getProperty // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessCodeForTool*)
preprocessCodeForTool // beginDefinition;
preprocessCodeForTool // Attributes = { HoldAllComplete };

preprocessCodeForTool[ code: _String | _HoldComplete ] :=
    code;

preprocessCodeForTool[ code_List ] := Enclose[
    StringJoin @ ConfirmMatch[ makeInlineExpressionString /@ Unevaluated @ code, { __String }, "Inlined" ],
    throwInternalFailure
];

preprocessCodeForTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInlineExpressionString*)
makeInlineExpressionString // beginDefinition;
makeInlineExpressionString // Attributes = { HoldAllComplete };

makeInlineExpressionString[ fragment_String ] :=
    fragment;

makeInlineExpressionString[ expr_ ] := Enclose[
    Module[ { link, key },
        link = ConfirmBy[ MakeExpressionURI @ Unevaluated @ expr, StringQ, "Link" ];
        key = ConfirmBy[ expressionURIKey @ link, StringQ, "Key" ];
        "InlinedExpression[\"attachment://" <> key <> "\"]"
    ],
    throwInternalFailure
];

makeInlineExpressionString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SandboxLinguisticAssistantData*)
SandboxLinguisticAssistantData // beginDefinition;
SandboxLinguisticAssistantData[ query_String ] := catchMine @ SandboxLinguisticAssistantData[ query, _ ];
SandboxLinguisticAssistantData[ query_String, patt_ ] := catchMine @ sandboxLinguisticAssistantData[ query, patt ];
SandboxLinguisticAssistantData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sandboxLinguisticAssistantData*)
sandboxLinguisticAssistantData // beginDefinition;

sandboxLinguisticAssistantData[ query_String, patt_ ] :=
    sandboxLinguisticAssistantData[ query, patt, $nlpData[ query ] ];

sandboxLinguisticAssistantData[ query_String, patt_, _Missing ] := (
    parseControlEquals[ query, patt ];
    $nlpData[ query, HoldPattern @ patt ]
);

sandboxLinguisticAssistantData[ query_String, patt_, data_Association ] :=
    sandboxLinguisticAssistantData[ query, patt, data, data[ HoldPattern[ patt ] ] ];

sandboxLinguisticAssistantData[ query_String, patt_, _Association, _Missing ] := (
    parseControlEquals[ query, patt ];
    $nlpData[ query, HoldPattern @ patt ]
);

sandboxLinguisticAssistantData[ query_String, patt_, _Association, data_Association ] :=
    data;

sandboxLinguisticAssistantData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Kernel Management*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Get Kernel*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSandboxKernel*)
getSandboxKernel // beginDefinition;
getSandboxKernel[ ] := getSandboxKernel @ Select[ Links[ ], sandboxKernelQ ];
getSandboxKernel[ { other__LinkObject, kernel_ } ] := (Scan[ LinkClose, { other } ]; getSandboxKernel @ { kernel });
getSandboxKernel[ { kernel_LinkObject } ] := checkSandboxKernel @ kernel;
getSandboxKernel[ { } ] := startSandboxKernel[ ];
getSandboxKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Kernel Status*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sandboxKernelQ*)
sandboxKernelQ[ LinkObject[ cmd_String, ___ ] ] := StringContainsQ[ cmd, "ChatbookSandbox" <> ToString @ $ProcessID ];
sandboxKernelQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkSandboxKernel*)
checkSandboxKernel // beginDefinition;
checkSandboxKernel[ kernel_LinkObject ] /; IntegerQ @ pingSandboxKernel @ kernel := kernel;
checkSandboxKernel[ kernel_LinkObject ] := startSandboxKernel[ ];
checkSandboxKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pingSandboxKernel*)
pingSandboxKernel // beginDefinition;

pingSandboxKernel[ kernel_LinkObject ] := Enclose[
    Module[ { uuid, return },

        uuid   = CreateUUID[ ];
        return = $Failed;

        ConfirmMatch[
            TimeConstrained[
                While[ LinkReadyQ @ kernel, LinkRead @ kernel ],
                $sandboxPingTimeout,
                $TimedOut
            ],
            Except[ $TimedOut ],
            "InitialLinkRead"
        ];

        With[ { id = uuid }, LinkWrite[ kernel, Unevaluated @ EvaluatePacket @ { id, $ProcessID } ] ];

        ConfirmMatch[
            TimeConstrained[
                While[ ! MatchQ[ return = LinkRead @ kernel, ReturnPacket @ { uuid, _ } ] ],
                $sandboxPingTimeout,
                $TimedOut
            ],
            Except[ $TimedOut ],
            "LinkReadReturn"
        ];

        ConfirmBy[
            Replace[ return, ReturnPacket @ { _, pid_ } :> pid ],
            IntegerQ,
            "ProcessID"
        ]
    ] // LogChatTiming[ "PingSandboxKernel" ]
];

pingSandboxKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$currentLineNumber*)
$currentLineNumber := If[ $CloudEvaluation, $cloudLineNumber, getCurrentLineNumber[ ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getCurrentLineNumber*)
getCurrentLineNumber // beginDefinition;

getCurrentLineNumber[ ] := getCurrentLineNumber @ getSandboxKernel[ ];

getCurrentLineNumber[ kernel_LinkObject ] := Enclose[
    Module[ { return },

        return = $Failed;

        LinkWrite[ kernel, Unevaluated @ EvaluatePacket @ $Line ];

        ConfirmMatch[
            TimeConstrained[
                While[ ! MatchQ[ return = LinkRead @ kernel, ReturnPacket[ _Integer ] ] ],
                $sandboxPingTimeout,
                $TimedOut
            ],
            Except[ $TimedOut ],
            "LinkReadReturn"
        ];

        ConfirmBy[
            Replace[ return, ReturnPacket[ n_Integer ] :> n ],
            IntegerQ,
            "LineNumber"
        ]
    ],
    throwInternalFailure
];

getCurrentLineNumber // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Start Kernel*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startSandboxKernel*)
startSandboxKernel // beginDefinition;

startSandboxKernel[ ] := Enclose[
    Module[ { kernel, readPaths, writePaths, executePaths, pid },

        Scan[ LinkClose, Select[ Links[ ], sandboxKernelQ ] ];

        kernel = ConfirmMatch[ LinkLaunch @ $sandboxKernelCommandLine, _LinkObject, "LinkLaunch" ];

        readPaths = makeReadPaths @ $readPaths;
        writePaths = makeWritePaths @ $writePaths;
        executePaths = makeExecutePaths @ $executePaths;

        (* Use StartProtectedMode instead of passing the -sandbox argument, since we need to initialize the FE first *)
        With[ { read = readPaths, write = writePaths, execute = executePaths },
            LinkWrite[
                kernel,
                Unevaluated @ EvaluatePacket[
                    UsingFrontEnd @ Null;
                    SetOptions[ First @ Streams[ "stdout" ], PageWidth -> Infinity ];
                    Developer`StartProtectedMode[ "Read" -> read, "Write" -> write, "Execute" -> execute ]
                ]
            ]
        ];

        pid = pingSandboxKernel @ kernel;

        With[ { messages = $messageOverrides },
            LinkWrite[
                kernel,
                Unevaluated @ EnterExpressionPacket[
                    (* Redefine some messages to provide hints to the LLM: *)
                    ReleaseHold @ messages;

                    (* Reset line number and leave `In[1]:=` in the buffer *)
                    $Line = 0
                ]
            ]
        ];

        TimeConstrained[
            While[ ! MatchQ[ LinkRead @ kernel, _ReturnExpressionPacket ] ],
            $sandboxPingTimeout,
            Confirm[ $Failed, "LineReset" ]
        ];

        If[ IntegerQ @ pid,
            $SandboxKernel = kernel,
            Quiet @ LinkClose @ kernel;
            throwFailure[ "NoSandboxKernel" ]
        ]
    ] // LogChatTiming[ "StartSandboxKernel" ],
    throwInternalFailure
];

startSandboxKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeReadPaths*)
makeReadPaths // beginDefinition;
makeReadPaths[ spec_ ] := replaceAutoPath[ makePaths @ spec, $defaultReadPaths, "AllowedReadPaths" ];
makeReadPaths // endDefinition;

$defaultReadPaths := $defaultReadPaths = Select[
    {
        $InstallationDirectory,
        $TemporaryDirectory,
        FileNameJoin @ { $BaseDirectory, "Paclets" },
        FileNameJoin @ { $BaseDirectory, "Autoload", "PacletManager" },
        FileNameJoin @ { $UserBaseDirectory, "Paclets" },
        FileNameJoin @ { $UserBaseDirectory, "Autoload", "PacletManager" },
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData" },
        FileNameJoin @ { $UserBaseDirectory, "Knowledgebase" },
        FileNameJoin @ { $UserBaseDirectory, "Logs" },
        SystemInformation[ "FrontEnd", "DocumentationInformation" ][ "Directory" ],
        ExpandFileName @ URL @ $LocalBase
    },
    StringQ
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeWritePaths*)
makeWritePaths // beginDefinition;
makeWritePaths[ spec_ ] := replaceAutoPath[ makePaths @ spec, $defaultWritePaths, "AllowedWritePaths" ];
makeWritePaths // endDefinition;

$defaultWritePaths := $defaultWritePaths = Select[
    {
        $TemporaryDirectory,
        FileNameJoin @ { $BaseDirectory, "Paclets" },
        FileNameJoin @ { $BaseDirectory, "Autoload", "PacletManager" },
        FileNameJoin @ { $UserBaseDirectory, "Paclets" },
        FileNameJoin @ { $UserBaseDirectory, "Autoload", "PacletManager" },
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "CloudObject", "Authentication" },
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Parallel", "Preferences" },
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Credentials" },
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Astro" },
        FileNameJoin @ { $UserBaseDirectory, "Knowledgebase" },
        FileNameJoin @ { $UserBaseDirectory, "Logs" },
        FileNameJoin @ { ExpandFileName @ URL @ $LocalBase, "Resources" }
    },
    StringQ
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeExecutePaths*)
makeExecutePaths // beginDefinition;
makeExecutePaths[ spec_ ] := replaceAutoPath[ makePaths @ spec, $defaultExecutePaths, "AllowedExecutePaths" ];
makeExecutePaths // endDefinition;

$defaultExecutePaths := $defaultExecutePaths = Select[
    {
        FileNameJoin @ { $InstallationDirectory, "SystemFiles", "Links" },
        FileNameJoin @ { $InstallationDirectory, "SystemFiles", "Libraries" },
        FileNameJoin @ { $InstallationDirectory, "SystemFiles", "Components" },
        FileNameJoin @ { $InstallationDirectory, "SystemFiles", "Java", $SystemID },
        FileNameJoin @ { $InstallationDirectory, "SystemFiles", "Converters", "Binaries", $SystemID },
        FileNameJoin @ { $InstallationDirectory, "SystemFiles", "Autoload", "PacletManager", "LibraryResources" },
        Switch[ $OperatingSystem,
                "Windows", FileNameJoin @ { $InstallationDirectory, "WolframKernel.exe" },
                "MacOSX" , FileNameJoin @ { $InstallationDirectory, "MacOS", "WolframKernel" },
                "Unix"   , FileNameJoin @ { $InstallationDirectory, "Executables", "wolfram" }
        ],
        FileNameJoin @ { $BaseDirectory, "Paclets" },
        FileNameJoin @ { $UserBaseDirectory, "Paclets" }
    },
    StringQ
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*replaceAutoPath*)
replaceAutoPath // beginDefinition;
replaceAutoPath // Attributes = { HoldRest };

replaceAutoPath[ paths_, default_, inherit_String ] :=
    DeleteDuplicates @ Flatten @ Replace[
        DeleteDuplicates @ Flatten @ { paths },
        {
            Automatic :> default,
            Inherited|ParentList :> Replace[
                makePaths @ $DefaultToolOptions[ "WolframLanguageEvaluator", inherit ],
                Automatic :> default
            ]
        },
        { 1 }
    ];

replaceAutoPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePaths*)
makePaths // beginDefinition;
makePaths[ All ] := If[ $OperatingSystem === "Windows", # <> ":\\" & /@ CharacterRange[ "A", "Z" ], "/" ];
makePaths[ None ] := { };
makePaths[ paths_List ] := DeleteDuplicates @ Flatten[ makePaths /@ Flatten @ paths ];
makePaths[ path_String ] := path;
makePaths[ h: _Hold|_HoldComplete|_HoldCompleteForm ] := makePaths @ ReleaseHold @ h;
makePaths[ ParentList|Inherited ] := ParentList;
makePaths[ $$unspecified ] := Automatic;
makePaths // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$messageOverrides*)
$messageOverrides := $messageOverrides = Flatten @ Apply[
    HoldComplete,
    ReadList[
        PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "SandboxMessages" ],
        HoldComplete @ Expression
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluate*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sandboxEvaluate*)
sandboxEvaluate // beginDefinition;

sandboxEvaluate[ eval_ ] :=
    Block[ { $kernelQuit = False, $verifiedResult = True },
        sandboxEvaluate0 @ eval
    ];

sandboxEvaluate // endDefinition;


sandboxEvaluate0 // beginDefinition;

sandboxEvaluate0[ KeyValuePattern[ "code" -> code_ ] ] := sandboxEvaluate0 @ code;
sandboxEvaluate0[ code_String ] := sandboxEvaluate0 @ toSandboxExpression @ code // LogChatTiming[ "SandboxEvaluate" ];
sandboxEvaluate0[ HoldComplete[ xs__, x_ ] ] := sandboxEvaluate0 @ HoldComplete @ CompoundExpression[ xs, x ];
sandboxEvaluate0[ HoldComplete[ eval_ ] ] /; useCloudSandboxQ[ ] := cloudSandboxEvaluate @ HoldComplete @ eval;
sandboxEvaluate0[ HoldComplete[ eval_ ] ] /; useSessionQ[ ] := sessionEvaluate @ HoldComplete @ eval;

sandboxEvaluate0[ HoldComplete[ evaluation_ ] ] := Enclose[
    Module[ { kernel, null, packets, $sandboxTag, $timedOut, $kernelQuit, results, flat, initialized, final },

        $lastSandboxMethod = "Local";
        $lastSandboxEvaluation = HoldComplete @ evaluation;
        kernel = ConfirmMatch[ getSandboxKernel[ ], _LinkObject, "GetKernel" ];

        ConfirmMatch[ linkWriteEvaluation[ kernel, evaluation ], Null, "LinkWriteEvaluation" ];

        { null, { packets } } = ConfirmMatch[
            Reap[
                Sow[ Nothing, $sandboxTag ];
                TimeConstrained[
                    Quiet[
                        Check[
                            While[
                                ! MatchQ[
                                    Sow[ deserializePacket @ LinkRead @ kernel, $sandboxTag ],
                                    _LinkRead|_ReturnExpressionPacket|$Failed
                                ]
                            ],
                            $kernelQuit,
                            { LinkObject::linkd, LinkObject::linkn }
                        ],
                        { LinkObject::linkd, LinkObject::linkn }
                    ],
                    2 * $sandboxEvaluationTimeout,
                    $timedOut
                ],
                $sandboxTag
            ],
            { _, { _List } },
            "LinkRead"
        ];

        If[ null === $timedOut,
            AppendTo[
                packets,
                With[ { fail = timeConstraintFailure @ $sandboxEvaluationTimeout },
                    ReturnExpressionPacket @ HoldComplete @ fail
                ]
            ]
        ];

        If[ null === $kernelQuit,
            AppendTo[
                packets,
                With[ { fail = kernelQuitFailure[ ] },
                    ReturnExpressionPacket @ HoldComplete @ fail
                ]
            ]
        ];

        results = Cases[ packets, ReturnExpressionPacket[ expr_ ] :> expr ];

        flat = Flatten[ HoldComplete @@ results, 1 ];

        initialized = initializeExpressions @ flat;

        (* TODO: include prompting that explains how to use Out[n] to get previous results *)

        final = $lastSandboxResult = ConfirmBy[
            verifyResult @ <|
                "String"  -> sandboxResultString[ initialized, packets ],
                "Result"  -> sandboxResult @ initialized,
                "Packets" -> packets
            |>,
            AssociationQ,
            "Verified"
        ];

        If[ TrueQ @ $ChatNotebookEvaluation || TrueQ @ $returnFullResult,
            final,
            final[ "String" ]
        ]
    ],
    throwInternalFailure
];

sandboxEvaluate0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*useCloudSandboxQ*)
useCloudSandboxQ // beginDefinition;
useCloudSandboxQ[ ] := useCloudSandboxQ @ $evaluatorMethod;
useCloudSandboxQ[ "Cloud" ] := True;
useCloudSandboxQ[ $$unspecified ] := TrueQ @ $CloudEvaluation;
useCloudSandboxQ[ _ ] := False;
useCloudSandboxQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*useSessionQ*)
useSessionQ // beginDefinition;
useSessionQ[ ] := useSessionQ @ $evaluatorMethod;
useSessionQ[ "Session"|None ] := True;
useSessionQ[ $$unspecified ] := False;
useSessionQ[ _ ] := False;
useSessionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deserializePacket*)
deserializePacket // beginDefinition;

deserializePacket[ ReturnExpressionPacket[ b_ByteArray ] ] :=
    ReturnExpressionPacket @ BinaryDeserialize[ b, HoldComplete ];

deserializePacket[ packet_ ] :=
    packet;

deserializePacket // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudSandboxEvaluate*)
cloudSandboxEvaluate // beginDefinition;

cloudSandboxEvaluate[ HoldComplete[ evaluation_ ] ] := Enclose[
    Catch @ Module[ { api, held, wxf, definitions, response, result, packets, initialized },

        $lastSandboxMethod = "Cloud";
        $lastSandboxEvaluation = HoldComplete @ evaluation;

        api = ConfirmMatch[ getCloudEvaluatorAPI[ ], _CloudObject|_Failure, "CloudEvaluator" ];
        If[ FailureQ @ api, Throw @ api ];
        held = ConfirmMatch[ makeCloudEvaluation @ evaluation, HoldComplete[ _ ], "Evaluation" ];
        wxf = ConfirmBy[ BinarySerialize[ held, PerformanceGoal -> "Size" ], ByteArrayQ, "WXF" ];
        definitions = makeCloudDefinitionsWXF @ HoldComplete @ evaluation;

        (* TODO: figure out a way to handle kernel quitting like the desktop evaluator *)
        response = ConfirmMatch[
            URLExecute[
                HTTPRequest[
                    api,
                    <|
                        "Method" -> "POST",
                        "Body" -> {
                            "Evaluation" -> BaseEncode @ wxf,
                            "TimeConstraint" -> $sandboxEvaluationTimeout,
                            If[ ByteArrayQ @ definitions  , "Definitions" -> BaseEncode @ definitions  , Nothing ],
                            If[ ByteArrayQ @ $cloudSession, "SessionMX"   -> BaseEncode @ $cloudSession, Nothing ]
                        }
                    |>
                ],
                "WXF",
                TimeConstraint -> 2*$sandboxEvaluationTimeout
            ],
            KeyValuePattern[ (Rule|RuleDelayed)[ "Result", _HoldComplete|_Hold ] ] | _Failure,
            "Response"
        ];

        If[ FailureQ @ response, Throw @ response ];

        result = HoldComplete @@ ConfirmMatch[ Lookup[ response, "Result" ], _HoldComplete|_Hold, "Result" ];
        packets = TextPacket /@ Flatten @ { response[ "OutputLog" ], response[ "MessagesText" ] };
        initialized = initializeExpressions @ result;

        $lastSandboxResult = ConfirmBy[
            verifyResult @ <|
                "String"    -> sandboxResultString[ initialized, packets ],
                "Result"    -> sandboxResult @ initialized,
                "Packets"   -> packets,
                "SessionMX" -> setCloudSessionString @ response
            |>,
            AssociationQ,
            "Verified"
        ]
    ],
    throwInternalFailure
];

cloudSandboxEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setCloudSessionString*)
setCloudSessionString // beginDefinition;
setCloudSessionString[ KeyValuePattern[ "SessionMX" -> mx_ ] ] := setCloudSessionString @ mx;
setCloudSessionString[ mx_ByteArray ] := $cloudSession = mx;
setCloudSessionString[ s_String ] := setCloudSessionString @ ByteArray @ s;
setCloudSessionString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCloudEvaluation*)
makeCloudEvaluation // beginDefinition;
makeCloudEvaluation // Attributes = { HoldAllComplete };

makeCloudEvaluation[ evaluation_ ] :=
    With[ { line = $cloudLineNumber++ },
        makeLinkWriteEvaluation[ $Line = line; evaluation ]
    ];

makeCloudEvaluation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getCloudEvaluatorAPI*)
getCloudEvaluatorAPI // beginDefinition;

getCloudEvaluatorAPI[ ] :=
    getCloudEvaluatorAPI @ CloudObject @ $cloudEvaluatorLocation;

getCloudEvaluatorAPI[ target: $$cloudObject ] :=
    Module[ { deployed },
        deployed = deployCloudEvaluator @ target;
        If[ validCloudEvaluatorQ @ deployed,
            getCloudEvaluatorAPI[ ] = deployed,
            getCloudEvaluatorAPI[ ] = Failure[
                "CloudEvaluatorUnavailable",
                <|
                    "MessageTemplate"   -> "No cloud evaluator available.",
                    "MessageParameters" -> { }
                |>
            ]
        ]
    ];

getCloudEvaluatorAPI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*validCloudEvaluatorQ*)
validCloudEvaluatorQ // beginDefinition;

validCloudEvaluatorQ[ obj: $$cloudObject ] := MatchQ[
    URLExecute[ obj, { "Evaluation" -> BaseEncode @ BinarySerialize @ HoldComplete[ 1 + 1 ] }, "WXF" ],
    KeyValuePattern[ (Rule|RuleDelayed)[ "Result", HoldComplete[ 2 ] ] ]
];

validCloudEvaluatorQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*deployCloudEvaluator*)
deployCloudEvaluator // beginDefinition;

deployCloudEvaluator[ target: $$cloudObject ] := With[ { messages = $messageOverrides },
    CloudDeploy[
        APIFunction[
            {
                "Evaluation"     -> "String",
                "Definitions"    -> "String" -> None,
                "SessionMX"      -> "String" -> None,
                "TimeConstraint" -> "Number" -> $sandboxEvaluationTimeout
            },
            Function @ Module[ { file },

                (* Clear existing global symbols *)
                Remove[ "Global`*" ];

                (* Define custom message text *)
                ReleaseHold @ messages;

                (* Forward user definitions *)
                If[ StringQ @ #Definitions,
                    Language`ExtendedFullDefinition[ ] = BinaryDeserialize @ BaseDecode[ #Definitions ]
                ];

                (* Restore definitions from previous session *)
                file = FileNameJoin @ { $TemporaryDirectory, "Session.mx" };
                If[ StringQ @ #SessionMX,
                    BinaryWrite[ file, ByteArray[ #SessionMX ] ];
                    Close @ file;
                    Get @ file;
                ];

                (* Evaluate the input *)
                BinarySerialize[
                    Append[
                        EvaluationData[
                            HoldComplete @@ {
                                TimeConstrained[
                                    BinaryDeserialize[ BaseDecode[ #Evaluation ], ReleaseHold ],
                                    #TimeConstraint,
                                    Failure[
                                        "EvaluationTimeExceeded",
                                        <|
                                            "MessageTemplate"   -> "Evaluation exceeded the `1` second time limit.",
                                            "MessageParameters" -> { #TimeConstraint }
                                        |>
                                    ]
                                ]
                            }
                        ],
                        (* Save any new definitions as a session byte array *)
                        "SessionMX" -> (
                            DumpSave[ file, "Global`", "SymbolAttributes" -> False ];
                            ReadByteArray @ file
                        )
                    ],
                    PerformanceGoal -> "Size"
                ]
            ],
            "Binary"
        ],
        target,
        EvaluationPrivileges -> None,
        Permissions          -> "Private"
    ]
];

deployCloudEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionEvaluate*)
sessionEvaluate // beginDefinition;

sessionEvaluate[ HoldComplete[ eval0_ ] ] := Enclose[
    Module[ { response, eval, result, packets, initialized },

        $lastSandboxMethod = "Session";
        $lastSandboxEvaluation = HoldComplete @ eval0;

        response = $Failed;
        eval = makeLinkWriteEvaluation @ eval0;

        With[ { held = eval, tc = $sandboxEvaluationTimeout },
            response = evaluationData[
                HoldComplete @@ {
                    TimeConstrained[
                        ReleaseHold @ held,
                        tc,
                        Failure[
                            "EvaluationTimeExceeded",
                            <|
                                "MessageTemplate"   -> "Evaluation exceeded the `1` second time limit.",
                                "MessageParameters" -> { tc }
                            |>
                        ]
                    ]
                }
            ]
        ];

        If[ $WorkspaceChat, NotebookDelete @ Cells[ $evaluationNotebook, CellStyle -> "PrintTemporary" ] ];

        result = HoldComplete @@ ConfirmMatch[ Lookup[ response, "Result" ], _HoldComplete|_Hold, "Result" ];
        packets = TextPacket /@ response[ "OutputLog" ];
        initialized = result;

        $lastSandboxResult = ConfirmBy[
            verifyResult @ <|
                "String"  -> sandboxResultString[ initialized, packets ],
                "Result"  -> sandboxResult @ initialized,
                "Packets" -> packets
            |>,
            AssociationQ,
            "Verified"
        ]
    ],
    throwInternalFailure
];

sessionEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializeExpressions*)
initializeExpressions // beginDefinition;

initializeExpressions[ flat: HoldComplete @ Association @ OrderlessPatternSequence[ "Initialized" -> pos0_, ___ ] ] :=
    With[ { pos = { 1, Key[ "Result" ], ## } & @@@ pos0 },
        ReplacePart[ flat, Thread[ pos -> Extract[ flat, pos ] ] ]
    ];

initializeExpressions[ HoldComplete[ failure_ ] ] :=
    With[ { as = <| "Line" -> $currentLineNumber-1, "Result" -> HoldComplete @ failure, "Initialized" -> { } |> },
        HoldComplete @ as
    ];

initializeExpressions[ failed: HoldComplete[ _Failure|$Failed|$Aborted ] ] :=
    failed;

initializeExpressions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toSandboxExpression*)
toSandboxExpression // beginDefinition;

toSandboxExpression[ s_String ] := $lastSandboxExpression =
    Block[ { $Context = $Context, $ContextPath = Prepend[ $ContextPath, "Wolfram`Chatbook`SandboxParsing`" ] },
        $lastSandboxString = s;
        toSandboxExpression[ s, toHeldExpression @ preprocessSandboxString @ s ]
    ];

toSandboxExpression[ s_, expr_HoldComplete ] :=
    expr;

toSandboxExpression[ s_String, $Failed ] /; StringContainsQ[ s, "'" ] :=
    Module[ { new, held },
        new = preprocessSandboxString @ StringReplace[ s, "'" -> "\"" ];
        held = toHeldExpression @ new;
        (
            sandboxStringNormalize[ s ] = new;
            held
        ) /; MatchQ[ held, _HoldComplete ]
    ];

toSandboxExpression[ s_String, $Failed ] /; StringContainsQ[ s, StartOfLine~~"// " ] :=
    Module[ { new, held },
        new = preprocessSandboxString @ StringReplace[
            s,
            StartOfLine ~~ "// " ~~ c: Except[ "\n" ].. ~~ "\n" :> "(*"<>c<>"*)\n"
        ];
        held = toHeldExpression @ new;
        (
            sandboxStringNormalize[ s ] = new;
            held
        ) /; MatchQ[ held, _HoldComplete ]
    ];

toSandboxExpression[ s_String, $Failed ] :=
    Module[ { openers, closers, new, held },
        openers = StringCount[ s, "[" ];
        closers = StringCount[ s, "]" ];
        (
            new = s <> StringRepeat[ "]", openers - closers ];
            held = toHeldExpression @ new;
            If[ MatchQ[ held, _HoldComplete ],
                sandboxStringNormalize[ s ] = new;
                held,
                HoldComplete[ ToExpression[ s, InputForm ] ]
            ]
        ) /; openers > closers
    ];

toSandboxExpression[ s_String, $Failed ] :=
    HoldComplete @ ToExpression[ s, InputForm ];

toSandboxExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toHeldExpression*)
toHeldExpression // beginDefinition;

toHeldExpression[ s_String ] :=
    expandSandboxMacros @ Replace[
        DeleteCases[ Quiet @ ToExpression[ s, InputForm, HoldComplete ], Null ],
        {
            HoldComplete[ xs__, CompoundExpression[ x_, Null ] ] :> Replace[
                HoldComplete @ CompoundExpression[ xs, x, Null ],
                HoldPattern[ CompoundExpression[ y_, Null ] ] :> y,
                { 2 }
            ],
            HoldComplete[ xs__, x_ ] :> Replace[
                HoldComplete @ CompoundExpression[ xs, x ],
                HoldPattern[ CompoundExpression[ y_, Null ] ] :> y,
                { 2 }
            ]
        }
    ];

toHeldExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessSandboxString*)
preprocessSandboxString // beginDefinition;

preprocessSandboxString[ s_String ] := sandboxStringNormalize[ s ] = StringReplace[
    autoCorrect @ s,
    {
        "\[FreeformPrompt]\"" ~~ query: Except[ "\"" ].. ~~ "\"" :>
            "\[FreeformPrompt][\"" <> query <> "\"]",
        "\[FreeformPrompt](\"" ~~ query: Except[ "\"" ].. ~~ "\")" :>
            "\[FreeformPrompt][\"" <> query <> "\"]",
        "\[FreeformPrompt](" ~~ query: Except[ ")" ].. ~~ ")" :>
            "\[FreeformPrompt][" <> query <> "]",
        "\[FreeformPrompt][" ~~ query: Except[ "\"" ].. ~~ "]" /; StringFreeQ[ query, "[" | "]" ] :>
            "\[FreeformPrompt][\"" <> query <> "\"]",
        "\[FreeformPrompt]\"" ~~ query: Except[ "\"" ].. ~~ "\"" /; StringFreeQ[ query, "[" | "]" ] :>
            "\[FreeformPrompt][\"" <> query <> "\"]",
        ("Import"|"Get") ~~ "[\"<!" ~~ uri: Except[ "!" ].. ~~ "!>\"]" :>
            "InlinedExpression[\"" <> uri <> "\"]",
        ("Import"|"Get") ~~ "[\"!["~~___~~"](" ~~ uri: (__ ~~ "://" ~~ key__) ~~ ")\"]" /; expressionURIKeyQ @ key :>
            "InlinedExpression[\"" <> uri <> "\"]",
        ("Import"|"Get") ~~ "[\"" ~~ key__ ~~ "\"]" /; expressionURIKeyQ @ key :>
            "InlinedExpression[\"attachment://" <> key <> "\"]",
        "\"!["~~___~~"](" ~~ uri: (__ ~~ "://" ~~ key__) ~~ ")\"" /; expressionURIKeyQ @ key :>
            "InlinedExpression[\"" <> uri <> "\"]",
        "!["~~___~~"](" ~~ uri: (__ ~~ "://" ~~ key__) ~~ ")" /; expressionURIKeyQ @ key :>
            "InlinedExpression[\"" <> uri <> "\"]",
        "<!" ~~ uri: Except[ "!" ].. ~~ "!>" :>
            "InlinedExpression[\"" <> uri <> "\"]",
        "\n/"~~EndOfString :> ""
    }
];

preprocessSandboxString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandSandboxMacros*)
expandSandboxMacros // beginDefinition;

expandSandboxMacros[ expr_HoldComplete ] := Enclose[
    Catch @ Module[ { msgBag, expanded },

        msgBag = Internal`Bag[ ];

        expanded = expr /. {
            sp`\[FreeformPrompt][ a___ ] :>
                With[ { e = ConfirmMatch[ parseControlEquals[ msgBag, HoldComplete @ a ], _$ConditionHold, "Parse" ] },
                    RuleCondition[ e, True ]
                ]
            ,
            sp`InlinedExpression[ uri_String ] :>
                With[ { e = ConfirmMatch[ parseExpressionURI[ msgBag, uri ], _$ConditionHold, "ExpressionURI" ] },
                    RuleCondition[ e, True ]
                ]
        };

        With[ { messages = Internal`BagPart[ msgBag, All ] },
            Replace[
                expanded,
                HoldComplete[ e___ ] :> HoldComplete[ Scan[ Print, messages ]; StackBegin @ Unevaluated @ e ]
            ]
        ]
    ],
    throwInternalFailure
];

expandSandboxMacros[ $Failed ] := $Failed;

expandSandboxMacros // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseExpressionURI*)
parseExpressionURI // beginDefinition;

parseExpressionURI[ messages_, uri_String ] := Enclose[
    Module[ { expression, message },
        expression = ConfirmMatch[
            catchAlways @ Quiet @ GetExpressionURI[ uri, $ConditionHold ],
            _Failure|_$ConditionHold,
            "GetExpressionURI"
        ];

        If[ FailureQ @ expression
            ,
            message = ConfirmBy[ expression[ "Message" ], StringQ, "Message" ];
            Internal`StuffBag[ messages, "[ERROR] " <> message ];
            $ConditionHold @@ { expression }
            ,
            expression
        ]
    ],
    throwInternalFailure
];

parseExpressionURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseControlEquals*)
parseControlEquals // beginDefinition;

parseControlEquals[ q_String ] := parseControlEquals[ q, _ ];

parseControlEquals[ q_String, patt_ ] :=
    Module[ { bag },
        bag = Internal`Bag[ ];
        Replace[
            parseControlEquals[ bag, HoldComplete[ q, patt ] ],
            $ConditionHold[ expr_ ] :> HoldComplete[ expr ]
        ]
    ];

parseControlEquals[ messages_, HoldComplete[ q_String ] ] :=
    parseControlEquals[ messages, HoldComplete[ q, _ ] ];

parseControlEquals[ messages_, HoldComplete[ q_String, patt_ ] ] :=
    parseControlEquals0[
        messages,
        q,
        makeInterpretationPattern @ patt,
        semanticInterpretation[ q, _, HoldComplete, AmbiguityFunction -> All ]
    ];

parseControlEquals[ messages_Internal`Bag, HoldComplete[ a___ ] ] := (
    Internal`StuffBag[ messages, "[ERROR] invalid arguments in " <> smallExpressionString @ sp`\[FreeformPrompt] @ a ];
    $ConditionHold @ $Failed
);

parseControlEquals // endDefinition;


parseControlEquals0 // beginDefinition;

(* ambiguity: *)
parseControlEquals0[ messages_Internal`Bag, q_String, patt_, HoldComplete[ a_AmbiguityList ] ] := Enclose[
    Catch @ Module[ { expanded, matching, selected, alternates, parsed },
        expanded = ConfirmMatch[ expandAmbiguityLists @ a, { HoldComplete[ _ ].. }, "ExpandAmbiguityLists" ];
        matching = Cases[ expanded, HoldComplete[ patt ] ];
        If[ matching === { }, Throw @ parseControlEquals0[ messages, q, patt, $Failed ] ];
        selected = ConfirmMatch[ First @ matching, HoldComplete[ _ ], "Selected" ];
        alternates = ConfirmMatch[ Rest @ matching, { HoldComplete[ _ ]... }, "Alternates" ];
        If[ alternates === { }, Throw @ parseControlEquals0[ messages, q, patt, selected ] ];
        Internal`StuffBag[
            messages,
            StringJoin[
                "[WARNING] Interpreted \"", q, "\" as ",
                smallExpressionString @@ selected,
                " with other possible interpretations: ",
                Cases[ alternates, HoldComplete[ e_ ] :> "\n\t" <> smallExpressionString @ e ]
            ]
        ];
        parsed = selected //. HoldPattern @ AmbiguityList[ { x_, ___ }, ___ ] :> x;
        If[ ! AssociationQ @ $nlpData[ q ], $nlpData[ q ] = <| |> ];
        $nlpData[ q, patt ] = <| "Alternates" -> alternates, "Parse" -> parsed, "Pattern" -> patt, "Query" -> q |>;
        $ConditionHold @@ parsed
    ],
    throwInternalFailure
];

(* no ambiguity: *)
parseControlEquals0[ messages_Internal`Bag, q_String, patt_, HoldComplete[ expr_ ] ] :=
    Module[ { parsed },
        If[ MatchQ[ HoldComplete @ expr, HoldComplete @ patt ],
            Internal`StuffBag[ messages, "[INFO] Interpreted \"" <> q <> "\" as: " <> smallExpressionString @ expr ];
            parsed = HoldComplete[ expr ] //. HoldPattern @ AmbiguityList[ { x_, ___ }, ___ ] :> x;
            If[ ! AssociationQ @ $nlpData[ q ], $nlpData[ q ] = <| |> ];
            $nlpData[ q, patt ] = <| "Parse" -> parsed, "Pattern" -> patt, "Query" -> q |>;
            $ConditionHold @@ parsed,
            parseControlEquals0[ messages, q, patt, $Failed ]
        ]
    ];

(* parsing failed: *)
parseControlEquals0[ messages_Internal`Bag, q_String, patt_, _? FailureQ ] := (
    Internal`StuffBag[ messages, "[ERROR] Failed to interpret \"" <> q <> "\" as valid WL input." ];
    If[ ! AssociationQ @ $nlpData[ q ], $nlpData[ q ] = <| |> ];
    $nlpData[ q, patt ] = <| "Parse" -> $Failed, "Pattern" -> patt, "Query" -> q |>;
    $ConditionHold @ $Failed
);

parseControlEquals0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInterpretationPattern*)
makeInterpretationPattern // beginDefinition;
makeInterpretationPattern // Attributes = { HoldAllComplete };

makeInterpretationPattern[ h_Symbol ] := HoldPattern @ Blank @ h;
makeInterpretationPattern[ "Date"|"date" ] := _DateObject;
makeInterpretationPattern[ "Unit"|"unit" ] := _Quantity;
makeInterpretationPattern[ type_String ] := HoldPattern @ Quantity[ _, type ] | (Entity|EntityClass)[ type, ___ ];

makeInterpretationPattern[ patt_ ] :=
    HoldPattern @ patt /. {
        (* quasi-safe pattern tests: *)
        Verbatim[ PatternTest ][ p_, DateObjectQ ] :> PatternTest[ p, strictPatternTest[ _DateObject, DateObjectQ ] ],
        Verbatim[ PatternTest ][ p_, QuantityQ   ] :> PatternTest[ p, strictPatternTest[ _Quantity  , QuantityQ   ] ],

        (* prevent potentially dangerous evaluation leaks: *)
        Verbatim[ PatternTest ][ p_, _ ] :> p,
        Verbatim[ Condition   ][ p_, _ ] :> p
    };

makeInterpretationPattern // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*strictPatternTest*)
strictPatternTest // beginDefinition;
strictPatternTest[ p_, q_ ] := Function[ Null, MatchQ[ Unevaluated @ #, p ] && q @ Unevaluated @ #, HoldAllComplete ];
strictPatternTest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandAmbiguityLists*)
expandAmbiguityLists // beginDefinition;
expandAmbiguityLists // Attributes = { HoldAllComplete };

expandAmbiguityLists[ expr_ ] :=
    Module[ { lists, held, marked, expanded },

        lists = <| |>;
        held = HoldComplete @ expr;

        marked = ReplaceRepeated[
            held,
            HoldPattern @ AmbiguityList[ { items__ }, ___ ] /; FreeQ[ HoldComplete @ items, AmbiguityList ] :>
                With[ { id = Hash @ HoldComplete @ items },
                    lists[ id ] = HoldComplete @ items;
                    ambiguityList @ id /; True
                ]
        ];

        expanded = FixedPoint[ expandOnceMarked @ lists, marked, 50 ];

        Select[ Cases[ expanded, e_ :> HoldComplete @ e ], FreeQ @ ambiguityList ]
    ];

expandAmbiguityLists // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandOnceMarked*)
expandOnceMarked // beginDefinition;

expandOnceMarked[ lists_ ] :=
    expandOnceMarked[ lists, # ] &;

expandOnceMarked[ lists_, marked_HoldComplete ] :=
    Catch @ Module[ { rules },
        rules = DeleteDuplicates @ Flatten @ Cases[
            marked,
            ambiguityList[ id_ ] :> Cases[ lists[ id ], e_ :> ambiguityList @ id :> e ],
            Infinity,
            Heads -> True
        ];
        If[ rules === { }, Throw @ marked ];
        DeleteDuplicates @ Flatten[ HoldComplete @@ ((marked /. # &) /@ rules) ]
    ];

expandOnceMarked // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*smallExpressionString*)
smallExpressionString // beginDefinition;
smallExpressionString // Attributes = { HoldAllComplete };
smallExpressionString[ expr_ ] := smallExpressionString[ expr, $toolOutputPageWidth ];
smallExpressionString[ expr_, n_ ] := stringTrimMiddle[ ToString[ Unevaluated @ expr, InputForm ], n ];
smallExpressionString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*semanticInterpretation*)
semanticInterpretation // beginDefinition;

semanticInterpretation[ in_, patt: Verbatim[ _ ], args___ ] := Verbatim @ semanticInterpretation[ in, patt, args ] =
    SemanticInterpretation[ in, patt, args ];

semanticInterpretation[ in_, patt_, args___ ] := Verbatim @ semanticInterpretation[ in, patt, args ] =
    SemanticInterpretation[ in, _? (Function[ Null, MatchQ[ Unevaluated @ #, patt ], HoldAllComplete ]), args ];

semanticInterpretation[ args___ ] := Verbatim @ semanticInterpretation[ args ] =
    SemanticInterpretation @ args;

semanticInterpretation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*sandboxStringNormalize*)
sandboxStringNormalize // beginDefinition;
sandboxStringNormalize[ s_String ] := s;
sandboxStringNormalize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluationData*)
evaluationData // beginDefinition;
evaluationData // Attributes = { HoldAllComplete };

evaluationData[ eval_ ] := Enclose[
    Module[ { outputs, result, stopped, $fail },
        $suppressMessageCollection = False;
        outputs = Internal`Bag[ ];
        result = $fail;
        stopped = <| |>;
        Internal`HandlerBlock[
            { "Message", evaluationMessageHandler[ stopped, outputs ] },
            Internal`HandlerBlock[
                { "Wolfram.System.Print.Veto", evaluationPrintHandler @ outputs },
                result = Quiet @ Quiet[ catchEverything @ eval, $stackTag::begin ]
            ]
        ];
        ConfirmAssert[ result =!= $fail, "EvaluationFailure" ];
        setOutput @ result;
        ConfirmBy[ makeEvaluationResultData[ result, outputs ], AssociationQ, "ResultData" ]
    ],
    throwInternalFailure
];

evaluationData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setOutput*)
setOutput // beginDefinition;
setOutput // Attributes = { SequenceHold };

setOutput[ HoldComplete[ KeyValuePattern[ "Result" -> HoldComplete[ result___ ] ] ] ] :=
    setOutput[ Replace[ $Line, Except[ _Integer ] :> 1 ], HoldComplete @ result ];

setOutput[ HoldComplete[ fail_Failure ] ] :=
    setOutput[ Replace[ $Line, Except[ _Integer ] :> 1 ], HoldComplete @ fail ];

setOutput[ line_Integer, HoldComplete[ result_ ] ] :=
    WithCleanup[
        Unprotect @ Out,
        Out[ line ] := result,
        Protect @ Out;
        $Line = line + 1
    ];

setOutput[ line_Integer, HoldComplete[ result___ ] ] :=
    setOutput[ line, HoldComplete @ Sequence @ result ];

setOutput // endDefinition;

(* TODO: Should probably also set things like In[], InString[], etc. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluationPrintHandler*)
evaluationPrintHandler // beginDefinition;
evaluationPrintHandler[ out_Internal`Bag ] := evaluationPrintHandler[ out, # ] &;
evaluationPrintHandler[ out_Internal`Bag, output_ ] := (Internal`StuffBag[ out, makePrintText @ output ]; False);
evaluationPrintHandler // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePrintText*)
makePrintText // beginDefinition;
makePrintText[ out_ ] := makePrintText[ Replace[ $Line, Except[ _Integer ] :> 1 ], out ];
makePrintText[ n_Integer, out_ ] := makePrintText[ "During evaluation of In[" <> ToString @ n <> "]:= ", out ];
makePrintText[ lbl_String, HoldComplete[ out__ ] ] := StringJoin[ lbl, ToString @ Unevaluated @ SequenceForm @ out ];
makePrintText[ lbl_, HoldComplete[ ] ] := "";
makePrintText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluationMessageHandler*)
evaluationMessageHandler // beginDefinition;
evaluationMessageHandler // Attributes = { HoldFirst };
(* `stopped` is a held association that's used to mark messages that have triggered a `General::stop`, and `outputs`
   contains the message and print text to be inserted into to the tool output for the LLM. *)
evaluationMessageHandler[ stopped_, outputs_ ] := evaluationMessageHandler0[ stopped, outputs, # ] &;
evaluationMessageHandler // endDefinition;


evaluationMessageHandler0 // beginDefinition;
evaluationMessageHandler0 // Attributes = { HoldFirst };

(* Message is not from LLM code or we've collected too many, so we don't want to insert it into the tool response: *)
evaluationMessageHandler0[ _, _, _ ] /; $suppressMessageCollection := Null;

(* Messages that are so frequent we don't want to waste time analyzing them: *)
evaluationMessageHandler0[ _, _, Hold[ Message[ $CharacterEncoding::utf8 | General::newsym, ___ ], _ ] ] := Null;

(* Message already triggered a General::stop, so do nothing: *)
evaluationMessageHandler0[ stopped_, outputs_, Hold[ Message[ mn_, ___ ], _ ] ] /; stopped @ HoldComplete @ mn := Null;

(* Message is locally quiet, so do nothing: *)
evaluationMessageHandler0[ _, _, Hold[ message_? messageQuietedQ, _ ] ] := Null;

(* Message has triggered a `General::stop`, but it's locally quiet, so mark it and otherwise do nothing: *)
evaluationMessageHandler0[
    stopped_,
    _,
    Hold[ Message[ General::stop, (HoldForm|HoldCompleteForm)[ msg_? messageQuietedQ ] ], _ ]
] := (
    stopped[ HoldComplete @ msg ] = True;
    Null
);

(* Already collected the max number of messages, so do nothing: *)
evaluationMessageHandler0[ _, outputs_Internal`Bag, _ ] /; Internal`BagLength @ outputs > $maxSandboxMessages := (
    $suppressMessageCollection = True;
    Null
);

(* Otherwise, collect message text: *)
evaluationMessageHandler0[ stopped_, outputs_, Hold[ message_, _ ] ] :=
    Block[ { $suppressMessageCollection = True }, (* Any messages occurring in here are not from LLM code *)
        (* If message is General::stop, tag the message in its argument as stopped so it won't be collected again: *)
        checkMessageStop[ stopped, message ];
        (* Create message text and save it: *)
        Internal`StuffBag[ outputs, makeMessageText @ message ]
    ];

evaluationMessageHandler0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*checkMessageStop*)
checkMessageStop // beginDefinition;
checkMessageStop // Attributes = { HoldAllComplete };

checkMessageStop[ stopped_, Message[ General::stop, (HoldForm|HoldCompleteForm)[ stop_ ] ] ] :=
    stopped[ HoldComplete @ stop ] = True;

checkMessageStop[ stopped_, _Message ] := Null;

checkMessageStop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeMessageText*)
makeMessageText // beginDefinition;
makeMessageText // Attributes = { HoldAllComplete };

makeMessageText[ Message[ mn: MessageName[ sym_Symbol, tag__String ], args0___ ] ] :=
    Module[ { template, label, args },
        template = SelectFirst[ { messageOverrideTemplate @ mn, mn, MessageName[ General, tag ] }, StringQ ];
        label    = ToString @ Unevaluated @ mn;
        args     = HoldCompleteForm /@ Unevaluated @ { args0 };
        If[ StringQ @ template,
            applyMessageTemplate[ label, template, args ],
            undefinedMessageText[ label, args ]
        ]
    ];

makeMessageText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageOverrideTemplate*)
messageOverrideTemplate // beginDefinition;
messageOverrideTemplate // Attributes = { HoldAllComplete };
messageOverrideTemplate[ mn_MessageName ] := Lookup[ $messageOverrideTemplates, HoldComplete @ mn ];
messageOverrideTemplate // endDefinition;


$messageOverrideTemplates := $messageOverrideTemplates = Association @ Cases[
    $messageOverrides,
    HoldPattern[ mn_MessageName = template_String ] :> (HoldComplete @ mn -> template)
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyMessageTemplate*)
applyMessageTemplate // beginDefinition;

applyMessageTemplate[ label_String, template_String, args_List ] := Enclose[
    Module[ { short },
        short = ConfirmMatch[ shortenMessageParameters @ args, { ___String }, "ShortenMessageParameters" ];
        label <> ": " <> ToString @ StringForm[ template, Sequence @@ short ]
    ],
    throwInternalFailure
];

applyMessageTemplate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*shortenMessageParameters*)
shortenMessageParameters // beginDefinition;
shortenMessageParameters // Attributes = { HoldAllComplete };
shortenMessageParameters[ { } ] := { };
shortenMessageParameters[ args_List ] := shortenMessageParameter[ countLargeParameters @ args ] /@ Unevaluated @ args;
shortenMessageParameters // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*countLargeParameters*)
countLargeParameters // beginDefinition;
countLargeParameters // Attributes = { HoldFirst };
countLargeParameters[ { } ] := 0;
countLargeParameters[ { args__ } ] := Length @ Select[ HoldComplete @ args, largeParameterQ ];
countLargeParameters // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*largeParameterQ*)
largeParameterQ // beginDefinition;
largeParameterQ[ _String ] := True;
largeParameterQ[ $$atomic ] := False;
largeParameterQ[ (HoldForm|HoldCompleteForm)[ expr_ ] ] := largeParameterQ @ expr;
largeParameterQ[ _ ] := True;
largeParameterQ // Attributes = { HoldAllComplete };
largeParameterQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*shortenMessageParameter*)
shortenMessageParameter // beginDefinition;

shortenMessageParameter[ count_Integer? NonNegative ] :=
    With[ { len = Max[ 50, Ceiling[ $maxMessageParameterLength / Max[ 1, count ] ] ] },
        Function[ Null, shortenMessageParameter[ len, Unevaluated @ # ], HoldAllComplete ]
    ];

shortenMessageParameter[ len_Integer? NonNegative, expr_ ] :=
    stringTrimMiddle[ messageParameterToString @ expr, len ];

shortenMessageParameter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*messageParameterToString*)
messageParameterToString // beginDefinition;
messageParameterToString // Attributes = { HoldAllComplete };
messageParameterToString[ (HoldCompleteForm|HoldForm)[ expr_ ] ] := messageParameterToString @ expr;
messageParameterToString[ Power[ expr_, -1 ] ] := messageParameterToString[ 1 / expr ];
messageParameterToString[ expr_ ] := fixLineEndings @ ToString[ Unevaluated @ expr, InputForm ];
messageParameterToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*undefinedMessageText*)
undefinedMessageText // beginDefinition;

undefinedMessageText[ label_String, args_List ] := Enclose[
    Module[ { short },
        short = ConfirmMatch[ shortenMessageParameters @ args, { ___String }, "ShortenMessageParameters" ];
        StringJoin[
            label,
            ": ",
            "-- Message text not found -- ",
            "(" <> # <> ")" & /@ short
        ]
    ],
    throwInternalFailure
];

undefinedMessageText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageQuietedQ*)
messageQuietedQ // beginDefinition;
messageQuietedQ // Attributes = { HoldAllComplete };

messageQuietedQ[ Message[ msg_, ___ ] ] :=
    messageQuietedQ @ msg;

messageQuietedQ[ msg: MessageName[ _Symbol, tag___ ] ] :=
    With[ { msgEval = msg },
        TrueQ @ Or[
            MatchQ[ msgEval, _$Off ],
            inheritingOffQ[ msgEval, tag ],
            messageQuietedQ0 @ msg
        ]
    ];

messageQuietedQ // endDefinition;


messageQuietedQ0 // beginDefinition;
messageQuietedQ0 // Attributes = { HoldAllComplete };

messageQuietedQ0[ msg: MessageName[ _Symbol, tag___ ] ] :=
    Module[ { stack, msgOrGeneral, msgPatt },

        stack        = localStack @ Lookup[ Internal`QuietStatus[ ], Stack ];
        msgOrGeneral = generalMessagePattern @ msg;
        msgPatt      = All | { ___, msgOrGeneral, ___ };

        TrueQ @ And[
            (* check if msg is not quiet via third arg of Quiet: *)
            FreeQ[ stack, { _, _, msgPatt }, 2 ],
            (* check if msg is not quieted via second arg of Quiet: *)
            ! FreeQ[ stack, { _, msgPatt, _ }, 2 ]
        ]
    ];

messageQuietedQ0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inheritingOffQ*)
inheritingOffQ // beginDefinition;
inheritingOffQ[ _String, ___ ] := False;
inheritingOffQ[ msg_, tag_ ] := MatchQ[ MessageName[ General, tag ], _$Off ];
inheritingOffQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*localStack*)
localStack // beginDefinition;

localStack[ (HoldForm|HoldCompleteForm) @ { ___, { ___, { $stackTag::begin }, ___ }, stack___ } ] :=
    localStack @ HoldCompleteForm @ { stack };

localStack[ (HoldForm|HoldCompleteForm) @ { stack___, { ___, { $stackTag::end }, ___ }, ___ } ] :=
    localStack @ HoldCompleteForm @ { stack };

localStack[ stack_ ] := stack;

localStack // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generalMessagePattern*)
generalMessagePattern // beginDefinition;
generalMessagePattern // Attributes = { HoldAllComplete };

generalMessagePattern[ msg: MessageName[ _Symbol, tag___ ] ] :=
    If[ StringQ @ msg,
        HoldPattern @ msg,
        HoldPattern[ msg | MessageName[ General, tag ] ]
    ];

generalMessagePattern // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*catchEverything*)
catchEverything // beginDefinition;
catchEverything // Attributes = { HoldAllComplete };

catchEverything[ e_ ] :=
    Internal`InheritedBlock[ { Catch, Throw },
        Catch[
            Unprotect[ Catch, Throw ];
            PrependTo[ DownValues @ Catch, HoldPattern[ Catch[ expr_ ] /; $forceTagged ] :> Catch[ expr, $untagged ] ];
            PrependTo[ DownValues @ Throw, HoldPattern[ Throw[ expr_ ] /; $forceTagged ] :> Throw[ expr, $untagged ] ];
            Protect[ Catch, Throw ]
        ];
        catchEverything0 @ CheckAbort[
            overrideTagForcing @ Catch[ handleKernelQuit @ contained @ e, _, uncaughtThrow ],
            $Aborted,
            PropagateAborts -> False
        ]
    ];

catchEverything // endDefinition;


catchEverything0 // beginDefinition;
catchEverything0 // Attributes = { SequenceHold };

catchEverything0[ contained[ result___ ] ] :=
    result;

catchEverything0[ $Aborted ] :=
    makeHeldResultAssociation @ $Aborted;

catchEverything0[ uncaughtThrow[ uncaught_, $untagged ] ] := (
    Message[ Throw::nocatch, HoldCompleteForm @ Throw @ uncaught ];
    makeHeldResultAssociation @ Hold @ Throw @ uncaught
);

catchEverything0[ uncaughtThrow[ code_Integer, $kernelExitTag ] ] := (
    $kernelQuit = True;
    Message[ General::quit, code ];
    makeHeldResultAssociation @ kernelExit @ code
);

catchEverything0[ uncaughtThrow[ uncaught__ ] ] := (
    Message[ Throw::nocatch, HoldCompleteForm @ Throw @ uncaught ];
    makeHeldResultAssociation @ Hold @ Throw @ uncaught
);

catchEverything0[ uncaught_ ] :=
    catchEverything0 @ uncaughtThrow @ uncaught;

catchEverything0[ uncaught___ ] :=
    catchEverything0 @ uncaughtThrow @ Sequence @ uncaught;

catchEverything0 // endDefinition;

(* TODO: Figure out a reliable way to intercept Exit and Quit.
   Note: Quit is locked in cloud, so we can't use a Block to redefine it. *)

contained // Attributes = { SequenceHold };
uncaughtThrow // Attributes = { HoldAllComplete };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*overrideTagForcing*)
overrideTagForcing // beginDefinition;
overrideTagForcing // Attributes = { HoldAllComplete };
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)
overrideTagForcing[ eval_ ] :=
    Module[ { protected },
        Replace[
            $tagOverrideSymbols,
            HoldComplete[ symbols__Symbol ] :>
                Internal`InheritedBlock[ { symbols },
                    protected = Unprotect @ symbols;
                    overrideTagForcing0 /@ Unevaluated @ { symbols };
                    Protect @ protected;
                    Block[ { $forceTagged = True }, eval ]
                ]
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)
overrideTagForcing // endDefinition;


overrideTagForcing0 // beginDefinition;
overrideTagForcing0 // Attributes = { HoldAllComplete };

overrideTagForcing0[ symbol_Symbol ] := PrependTo[
    DownValues @ symbol,
    HoldPattern[ symbol[ args___ ] /; $forceTagged ] :>
        Block[ { $forceTagged = False }, symbol @ args ]
];

overrideTagForcing0 // endDefinition;

(* Some system symbols will have a mix of top-level and kernel evaluation.
   This lets us disable tag forcing for these symbols in cases where an untagged Throw is issued by top-level code,
   but handled by the kernel (where overriding DownValues has no effect). Without this override, we would get:
   ```wl
   In[1]:= WolframLanguageToolEvaluate["ContinuedFraction[Pi, 5]", Method -> "Session"]

   Out[1]= "Throw::nocatch: Uncaught Throw[{3, 7, 15, 1, 292}] returned to top level.
   General::messages: Messages were generated which may indicate errors.

   Out[1]= Hold[Throw[{3, 7, 15, 1, 292}]]"
   ```
*)
$tagOverrideSymbols = HoldComplete[
    ContinuedFraction
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handleKernelQuit*)
handleKernelQuit // beginDefinition;
handleKernelQuit // Attributes = { HoldAllComplete };
handleKernelQuit[ eval_ ] := handleQuit @ handleExit @ eval;
handleKernelQuit // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handleExit*)
handleExit // beginDefinition;
handleExit // Attributes = { HoldAllComplete };

handleExit[ eval_ ] := Internal`InheritedBlock[ { Exit },
    Unprotect @ Exit;
    PrependTo[ DownValues @ Exit, HoldPattern @ Exit[ code_Integer ] :> Throw[ code, $kernelExitTag ] ];
    PrependTo[ DownValues @ Exit, HoldPattern @ Exit[ ] :> Throw[ 0, $kernelExitTag ] ];
    Protect @ Exit;
    eval
];

handleExit // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handleQuit*)
handleQuit // beginDefinition;
handleQuit // Attributes = { HoldAllComplete };

(* Quit is locked in cloud, so we can't use a Block to redefine it.
   Instead, we'll replace literal occurrences of Quit with our own override. *)
handleQuit[ eval_ ] /; $CloudEvaluation :=
    Module[ { held, released },

        held = ReplaceAll[
            HoldComplete @ eval,
            {
                HoldPattern @ Quit[ ] :> quitOverride[ ],
                HoldPattern @ Quit[ code_Integer ] :> quitOverride @ code
            }
        ];

        released = ReleaseHold @ held;

        released /. quitOverride -> Quit
    ];

handleQuit[ eval_ ] := Internal`InheritedBlock[ { Quit },
    Unprotect @ Quit;
    PrependTo[ DownValues @ Quit, HoldPattern @ Quit[ ] :> Throw[ 0, $kernelExitTag ] ];
    PrependTo[ DownValues @ Quit, HoldPattern @ Quit[ code_Integer ] :> Throw[ code, $kernelExitTag ] ];
    Protect @ Quit;
    eval
];

handleQuit // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*quitOverride*)
quitOverride // beginDefinition;
quitOverride[ ] := Throw[ 0, $kernelExitTag ];
quitOverride[ code_Integer ] := Throw[ code, $kernelExitTag ];
quitOverride // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeHeldResultAssociation*)
makeHeldResultAssociation // beginDefinition;
makeHeldResultAssociation // Attributes = { HoldAllComplete };

makeHeldResultAssociation[ e_ ] :=
    HoldComplete @@ { <| "Line" -> $Line, "Result" -> HoldComplete @ e, "Initialized" -> { } |> };

makeHeldResultAssociation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeEvaluationResultData*)
makeEvaluationResultData // beginDefinition;
makeEvaluationResultData // Attributes = { SequenceHold };

makeEvaluationResultData[ result_, outputs_Internal`Bag ] :=
    makeEvaluationResultData[ result, Internal`BagPart[ outputs, All ] ];

makeEvaluationResultData[ result_, outputs: { ___String } ] :=
    <|
        "Result"    :> result,
        "OutputLog" -> outputs
    |>;

makeEvaluationResultData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*linkWriteEvaluation*)
linkWriteEvaluation // beginDefinition;
linkWriteEvaluation // Attributes = { HoldAllComplete };

linkWriteEvaluation[ kernel_, evaluation_ ] :=
    With[ { eval = toWXFEvaluation @ includeDefinitions @ makeLinkWriteEvaluation @ evaluation },
        LinkWrite[ kernel, Unevaluated @ EnterExpressionPacket @ BinaryDeserialize[ eval, BinarySerialize ] ]
    ];

linkWriteEvaluation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toWXFEvaluation*)
toWXFEvaluation // beginDefinition;
toWXFEvaluation[ HoldComplete[ eval_ ] ] := BinarySerialize @ Unevaluated @ eval;
toWXFEvaluation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeLinkWriteEvaluation*)
makeLinkWriteEvaluation // beginDefinition;
makeLinkWriteEvaluation // Attributes = { HoldAllComplete };

makeLinkWriteEvaluation[ evaluation_ ] := Enclose[
    Module[ { eval, constrained },
        eval = ConfirmMatch[ createEvaluationWithWarnings @ evaluation, HoldComplete[ _ ], "Warnings" ];
        constrained = ConfirmMatch[ addTimeConstraint @ eval, HoldComplete[ _ ], "TimeConstraint" ];
        ConfirmMatch[ addInitializations @ constrained, HoldComplete[ _ ], "Initializations" ]
    ],
    throwInternalFailure
];

makeLinkWriteEvaluation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*includeDefinitions*)
includeDefinitions // beginDefinition;

includeDefinitions[ eval_HoldComplete ] :=
    includeDefinitions[ eval, $includeDefinitions ];

includeDefinitions[ h: HoldComplete[ eval___ ], True|$$unspecified ] :=
    With[ { def = Language`ExtendedFullDefinition @ h },
        HoldComplete[ Language`ExtendedFullDefinition[ ] = def; eval ] /; MatchQ[ def, _Language`DefinitionList ]
    ];

includeDefinitions[ h_HoldComplete, _ ] :=
    h;

includeDefinitions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCloudDefinitionsWXF*)
makeCloudDefinitionsWXF // beginDefinition;

makeCloudDefinitionsWXF[ eval_HoldComplete ] :=
    makeCloudDefinitionsWXF[ eval, $includeDefinitions ];

makeCloudDefinitionsWXF[ h_HoldComplete, True|$$unspecified ] :=
    With[ { def = Language`ExtendedFullDefinition @ h },
        BinarySerialize[ def, PerformanceGoal -> "Size" ] /; MatchQ[ def, _Language`DefinitionList ]
    ];

makeCloudDefinitionsWXF[ h_HoldComplete, _ ] :=
    None;

makeCloudDefinitionsWXF // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addInitializations*)
addInitializations // beginDefinition;

addInitializations[ eval_HoldComplete ] := addInitializations[ eval, $initializationTest ];

addInitializations[ HoldComplete[ eval_ ], initializedQ_ ] :=
    HoldComplete @ With[
        {
            result = Replace[ HoldComplete @@ { eval }, HoldComplete[ ] :> HoldComplete @ Sequence[ ] ]
        },
        <|
            "Line"        -> $Line,
            "Result"      -> result,
            "Initialized" -> Position[ result, _? initializedQ, Heads -> True ]
        |>
    ];

addInitializations // endDefinition;


$initializationTest := $initializationTest = Module[ { tests, slot, func },
    tests = Flatten[ HoldComplete @@ Cases[ $initializationTests, f_ :> HoldComplete @ f @ slot[ 1 ] ] ];
    func = Replace[ tests, HoldComplete[ t___ ] :> Function[ Null, Quiet @ TrueQ @ Or @ t, HoldAllComplete ] ];
    func /. slot -> Slot
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addTimeConstraint*)
addTimeConstraint // beginDefinition;
addTimeConstraint[ eval_HoldComplete ] := addTimeConstraint[ eval, $sandboxEvaluationTimeout ];
addTimeConstraint[ eval_, t_ ] := addTimeConstraint[ eval, t, timeConstraintFailure @ t ];
addTimeConstraint[ HoldComplete[ eval_ ], t_, fail_Failure ] := HoldComplete @ TimeConstrained[ eval, t, fail ];
addTimeConstraint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*timeConstraintFailure*)
timeConstraintFailure // beginDefinition;

timeConstraintFailure[ t_? Positive ] := Failure[
    "EvaluationTimeExceeded",
    <|
        "MessageTemplate"   -> "Evaluation exceeded the `1` second time limit.",
        "MessageParameters" -> { t }
    |>
];

timeConstraintFailure[ q: HoldPattern[ _Quantity ] ] :=
    With[ { s = UnitConvert[ q, "Seconds" ] },
        timeConstraintFailure @ QuantityMagnitude @ s /; QuantityUnit @ s === "Seconds"
    ];

timeConstraintFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*kernelQuitFailure*)
kernelQuitFailure // beginDefinition;

kernelQuitFailure[ ] := Failure[
    "KernelQuit",
    <|
        "MessageTemplate"   -> "The kernel quit unexpectedly during an evaluation.",
        "MessageParameters" -> { }
    |>
];

kernelQuitFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createEvaluationWithWarnings*)
createEvaluationWithWarnings // beginDefinition;
createEvaluationWithWarnings // Attributes = { HoldAllComplete };

createEvaluationWithWarnings[ evaluation_ ] :=
    Module[ { held, undefined },
        held = Flatten @ HoldComplete @ Block[ { PrintTemporary = Print }, StackBegin @ Unevaluated @ evaluation ];

        undefined = Flatten[ HoldComplete @@ Cases[
            Unevaluated @ evaluation,
            s_Symbol? undefinedSymbolQ :> HoldComplete @ s,
            Infinity,
            Heads -> True
        ] ];

        (* TODO: add other warnings *)
        addWarnings[ held, <| "UndefinedSymbols" -> undefined |> ]
    ];

createEvaluationWithWarnings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addWarnings*)
addWarnings // beginDefinition;

addWarnings[ HoldComplete[ eval__ ], as: KeyValuePattern[ "UndefinedSymbols" -> HoldComplete[ ] ] ] :=
    addWarnings[ HoldComplete[ eval ], KeyDrop[ as, "UndefinedSymbols" ] ];

addWarnings[ HoldComplete[ eval__ ], as: KeyValuePattern[ "UndefinedSymbols" -> HoldComplete[ s_Symbol ] ] ] :=
    addWarnings[ HoldComplete[ Message[ Symbol::undefined, s ]; eval ], KeyDrop[ as, "UndefinedSymbols" ] ];

addWarnings[ HoldComplete[ eval__ ], as: KeyValuePattern[ "UndefinedSymbols" -> HoldComplete[ s__Symbol ] ] ] :=
    addWarnings[
        HoldComplete[ Message[ Symbol::undefined2, StringRiffle[ { s }, ", " ] ]; eval ],
        KeyDrop[ as, "UndefinedSymbols" ]
    ];

addWarnings[ HoldComplete[ eval_  ], _ ] := addMessageHandler @ HoldComplete @ eval;
addWarnings[ HoldComplete[ eval__ ], _ ] := addMessageHandler @ HoldComplete @ CompoundExpression @ eval;

addWarnings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addMessageHandler*)
addMessageHandler // beginDefinition;

addMessageHandler[ HoldComplete[ eval_ ] ] :=
    With[ { nlSym = Entity|EntityProperty|EntityClass|Quantity|DateObject|ExampleData },
        HoldComplete @ Module[ { $issueNLMessage = False, $nlMessageType },
            WithCleanup[
                Internal`HandlerBlock[
                    {
                        "Message",
                        Function[
                            If[ #[[ 2 ]] && ! FreeQ[ #, nlSym ],
                                $issueNLMessage = True;
                                $nlMessageType  = FirstCase[ #, nlSym, None, Infinity, Heads -> True ]
                            ]
                        ]
                    },
                    eval
                ],
                If[ $issueNLMessage, Message[ General::usenl, $nlMessageType ] ]
            ]
        ]
    ];

addMessageHandler // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*undefinedSymbolQ*)
undefinedSymbolQ // ClearAll;
undefinedSymbolQ // Attributes = { HoldAllComplete };

undefinedSymbolQ[ symbol_Symbol ] := TrueQ @ And[
    AtomQ @ Unevaluated @ symbol,
    Unevaluated @ symbol =!= Internal`$EFAIL,
    Context @ Unevaluated @ symbol === "Global`",
    StringStartsQ[ SymbolName @ Unevaluated @ symbol, _? UpperCaseQ ],
    ! System`Private`HasAnyEvaluationsQ @ symbol
];

undefinedSymbolQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*verifyResult*)
verifyResult // beginDefinition;

verifyResult[ as_Association ] := Enclose[
    Module[ { verified },
        verified = ConfirmMatch[ verifiedResultQ @ as, True|False, "Verified" ];
        If[ ! verified, ConfirmBy[ needsBasePrompt[ "WolframLanguageEvaluatorToolTrouble" ], StringQ, "RetryPrompt" ] ];
        <| as, "Verified" -> verified |>
    ],
    throwInternalFailure
];

verifyResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*verifiedResultQ*)
verifiedResultQ // beginDefinition;

verifiedResultQ[ as: KeyValuePattern[ "Result" -> result_HoldCompleteForm ] ] := And[
    $verifiedResult,
    verifiedExpressionResultQ @ result,
    verifiedStringResultQ @ as[ "String" ]
];

verifiedResultQ[ KeyValuePattern[ "Result" -> _Failure ] ] :=
    False;

verifiedResultQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*verifiedExpressionResultQ*)
verifiedExpressionResultQ // beginDefinition;
verifiedExpressionResultQ[ $$holdFormH[ _? probableFailureQ ] ] := False;
verifiedExpressionResultQ[ $$holdFormH[ ___ ] ] := True;
verifiedExpressionResultQ[ _ ] := False;
verifiedExpressionResultQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*probableFailureQ*)
probableFailureQ // beginDefinition;
probableFailureQ[ $$probableFailure ] := True;
probableFailureQ[ { exprs__ } ] := AllTrue[ HoldComplete @ exprs, probableFailureQ ];
probableFailureQ[ _ ] := False;
probableFailureQ // Attributes = { HoldAllComplete };
probableFailureQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*verifiedStringResultQ*)
verifiedStringResultQ // beginDefinition;
verifiedStringResultQ[ "" ] := False;
verifiedStringResultQ[ string_String ] := StringFreeQ[ string, "General::messages" ];
verifiedStringResultQ[ _ ] := False;
verifiedStringResultQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sandboxResult*)
sandboxResult // beginDefinition;
sandboxResult[ HoldComplete @ Association @ OrderlessPatternSequence[ "Result" -> res_, ___ ] ] := sandboxResult @ res;
sandboxResult[ HoldComplete[ held_HoldComplete ] ] := sandboxResult @ held;
sandboxResult[ HoldComplete[ ___, kernelExit[ code_Integer ] ] ] := Failure[ "KernelQuit", <| "ExitCode" -> code |> ];
sandboxResult[ HoldComplete[ ___, expr_ ] ] := HoldCompleteForm @ expr;
sandboxResult[ res_ ] := HoldCompleteForm @ res;
sandboxResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sandboxResultString*)
sandboxResultString // beginDefinition;

sandboxResultString[ result_, packets_ ] :=
    mergeComments @ appendRetryNotice @ checkDocSearchMessageStrings @ sandboxResultString0[
        preprocessForResultString @ result,
        packets
    ];

sandboxResultString // endDefinition;


sandboxResultString0 // beginDefinition;

sandboxResultString0[ result_, packets_ ] := sandboxResultString0 @ result;

sandboxResultString0[ HoldComplete[ KeyValuePattern @ { "Line" -> line_, "Result" -> result_ } ], packets_ ] :=
    appendURIInstructions[
        StringTrim @ StringRiffle[
            Flatten @ {
                makePacketMessages[ ToString @ line, packets ],
                If[ MatchQ[ Unevaluated @ result, HoldComplete[ _kernelExit ] ],
                    "",
                    "\nOut[" <> ToString @ line <> "]= " <> sandboxResultString0 @ Flatten @ HoldComplete @ result
                ]
            },
            "\n"
        ],
        Flatten @ HoldComplete @ result
    ];

sandboxResultString0[ expr_HoldComplete ] :=
    With[ { string = sandboxResultString1 @ expr },
        If[ StringContainsQ[ string, "\n" ],
            "\n" <> string,
            string
        ]
    ];

sandboxResultString0 // endDefinition;


sandboxResultString1 // beginDefinition;

sandboxResultString1[ HoldComplete[ ___, expr_? outputFormQ ] ] :=
    sandboxResultString2 @ ToString[ Unevaluated @ expr, PageWidth -> $toolOutputPageWidth ];

sandboxResultString1[ HoldComplete[ ___, expr_? simpleResultQ ] ] :=
    sandboxResultString2 @ ToString[ Unevaluated @ expr, InputForm, PageWidth -> $toolOutputPageWidth ];

sandboxResultString1[ HoldComplete[ ___, expr_ ] ] :=
    makeExpressionURI @ Unevaluated @ expr;

sandboxResultString1[ HoldComplete[ ] ] :=
    "Null";

sandboxResultString1 // endDefinition;


sandboxResultString2 // beginDefinition;
sandboxResultString2[ str_String ] := stringTrimMiddle[ fixLineEndings @ str, $toolResultStringLength ];
sandboxResultString2 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessForResultString*)
preprocessForResultString // beginDefinition;

preprocessForResultString[ expr_ ] := ReplaceAll[
    expr,
    {
        gfx_? safeGraphicsQ :>
            RuleCondition @ markdownExpression @ MakeExpressionURI[ ToString @ Head @ Unevaluated @ gfx, gfx ]
    }
];

preprocessForResultString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*safeGraphicsQ*)
safeGraphicsQ // beginDefinition;
safeGraphicsQ // Attributes = { HoldAllComplete };
safeGraphicsQ[ e_ ] := graphicsQ @ Unevaluated @ e;
safeGraphicsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeComments*)
mergeComments // beginDefinition;

mergeComments[ string_String ] := StringReplace[
    string,
    {
        "*)" ~~ WhitespaceCharacter... ~~ "\n" ~~ WhitespaceCharacter... ~~ "(*" -> "\n\n",
        "*)" ~~ WhitespaceCharacter... ~~ "(*" -> "\n"
    }
];

mergeComments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendRetryNotice*)
appendRetryNotice // beginDefinition;

appendRetryNotice[ string_String ] :=
    If[ $appendRetryNotice =!= False && StringContainsQ[ string, "General::messages" ],
        string<>"\n\n"<>$retryMessage,
        string
    ];

appendRetryNotice // endDefinition;

$retryMessage = "(* \
IMPORTANT! If this tool call failed to provide the desired result for any reason, \
you MUST write /retry before making the next tool call. \
*)";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendURIInstructions*)
appendURIInstructions // beginDefinition;

appendURIInstructions[ expr_, ___ ] /; $appendURIInstructions === False := expr;

appendURIInstructions[ as: KeyValuePattern @ { "String" -> s_, "Result" -> expr_ } ] :=
    <| as, "String" -> appendURIInstructions[ s, expr ] |>;

appendURIInstructions[ string_String, expr_ ] /; $appendURIPrompt :=
    appendURIInstructions0[ string, expr ];

appendURIInstructions[ string_String, HoldComplete[ e_? simpleFormattingQ ] ] :=
    string;

appendURIInstructions[ string_String, HoldComplete[ ___, expr_ ] ] := Enclose[
    Module[ { uri, key },
        uri = ConfirmBy[
            makeExpressionURI[ "expression", "Formatted Result", Unevaluated @ expr ],
            StringQ,
            "ExpressionURI"
        ];

        key = ConfirmBy[ expressionURIKey @ uri, StringQ, "ExpressionURIKey" ];

        If[ StringContainsQ[ string, key ],
            string,
            string <> "\n\n(* "<> uri <>" *)"
        ]
    ],
    throwInternalFailure
];

appendURIInstructions[ string_String, HoldComplete[ ] ] :=
    appendURIInstructions[ string, HoldComplete @ Sequence[ ] ];

appendURIInstructions // endDefinition;


appendURIInstructions0 // beginDefinition;

appendURIInstructions0[ string_String, (HoldForm|HoldCompleteForm)[ expr_ ] ] :=
    appendURIInstructions0[ string, HoldComplete @ expr ];

appendURIInstructions0[ string_String, HoldComplete[ ___, expr_? appendURIQ ] ] := Enclose[
    Module[ { uri, key, message },

        uri = ConfirmBy[
            makeExpressionURI[ "expression", "Formatted Result", Unevaluated @ expr ],
            StringQ,
            "ExpressionURI"
        ];

        key     = ConfirmBy[ expressionURIKey @ uri, StringQ, "ExpressionURIKey" ];
        message = ConfirmBy[ TemplateApply[ $uriPromptTemplate, key ], StringQ, "URIPrompt" ];

        string <> "\n\n" <> message
    ],
    throwInternalFailure
];

appendURIInstructions0[ string_String, _ ] := string;

appendURIInstructions0 // endDefinition;


$uriPromptTemplate = StringTemplate[ "\
(* You can inline this expression in future evaluator inputs or WL code blocks using the syntax: <!expression://%%1%%!>

Always use this syntax when referring to this expression instead of writing it out manually.
This syntax is only available to you. Do not mention it to the user. *)\
", Delimiters -> "%%" ];

(* FIXME: there should be post processing that automatically strips this message if the URI is no longer available *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendURIQ*)
appendURIQ // beginDefinition;
appendURIQ // Attributes = { HoldAllComplete };

appendURIQ[ expr_ ] := TrueQ @ Or[
    ByteCount @ Unevaluated @ expr > 500,
    graphicsQ @ Unevaluated @ expr,
    ! simpleFormattingQ @ expr
];

appendURIQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkDocSearchMessageStrings*)
checkDocSearchMessageStrings // beginDefinition;
checkDocSearchMessageStrings[ string_String ] /; toolSelectedQ[ "DocumentationSearcher" ] := string;
checkDocSearchMessageStrings[ string_String ] := StringDelete[ string, $docSearchMessageStrings ];
checkDocSearchMessageStrings // endDefinition;

$docSearchMessageStrings = {
    " Use the documentation searcher tool to find solutions.",
    " Use the documentation searcher tool to find alternatives."
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*outputFormQ*)
outputFormQ // beginDefinition;
outputFormQ[ $$outputForm[ ___ ] ] := True;
outputFormQ[ _ ] := False;
outputFormQ // Attributes = { HoldAllComplete };
outputFormQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializedQ*)
initializedQ // beginDefinition;
initializedQ // Attributes = { HoldAllComplete };
initializedQ[ expr_ ] := $initializationTest @ Unevaluated @ expr;
initializedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleResultQ*)
simpleResultQ // beginDefinition;
simpleResultQ // Attributes = { HoldAllComplete };
simpleResultQ[ expr_ ] := FreeQ[ Unevaluated @ expr, _? fancyResultQ ];
simpleResultQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleFormattingQ*)
simpleFormattingQ // beginDefinition;
simpleFormattingQ // Attributes = { HoldAllComplete };

simpleFormattingQ[ _String ] := True;

simpleFormattingQ[ e_ ] := simpleFormattingQ[ HoldPattern @ Verbatim[ e ] ] =
    simpleFormattingQ0[ Unevaluated @ MakeBoxes @ e /. markdownExpression[ str_String ] :> str ];

simpleFormattingQ // endDefinition;

simpleFormattingQ0 // beginDefinition;
simpleFormattingQ0[ _String ] := True;
simpleFormattingQ0[ TemplateBox[ _, $$simpleTemplateBoxName, ___ ] ] := True;
simpleFormattingQ0[ RowBox[ boxes_List ] ] := AllTrue[ boxes, simpleFormattingQ0 ];
simpleFormattingQ0[ ___ ] := False;
simpleFormattingQ0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fancyResultQ*)
fancyResultQ // beginDefinition;
fancyResultQ // Attributes = { HoldAllComplete };
fancyResultQ[ _Manipulate|_DynamicModule|_Video|_Audio|_Tree ] := True;
fancyResultQ[ gfx_ ] := graphicsQ @ Unevaluated @ gfx;
fancyResultQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePacketMessages*)
makePacketMessages // beginDefinition;

makePacketMessages[ line_, packets_List ] := Enclose[
    Module[ { strings },
        $appendGeneralMessage = False;
        strings = ConfirmMatch[ makePacketMessage /@ packets, { ___String }, "Strings" ];
        If[ ConfirmBy[ $appendGeneralMessage && ! $kernelQuit, BooleanQ, "AppendGeneralMessage" ],
            Append[ strings, ConfirmBy[ $generalMessageText, StringQ, "GeneralMessage" ] ],
            strings
        ]
    ],
    throwInternalFailure
];

makePacketMessages // endDefinition;


$generalMessageText := Enclose[
    Module[ { string },
        string = ConfirmBy[ $messageOverrideTemplates[ HoldComplete[ General::messages ] ], StringQ, "String" ];
        $generalMessageText = "General::messages: " <> string
    ],
    throwInternalFailure @ $generalMessageText &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makePacketMessage*)
$$noMessagePacket = _InputNamePacket|_MessagePacket|_OutputNamePacket|_ReturnExpressionPacket|_LinkRead|$Failed;

makePacketMessage // beginDefinition;
makePacketMessage[ $$noMessagePacket ] := Nothing;
makePacketMessage[ TextPacket[ text_ ] ] := makePacketMessage @ text;

makePacketMessage[ text_String ] :=
    If[ StringStartsQ[ text, Except[ WhitespaceCharacter ].. ~~ "::" ~~ Except[ WhitespaceCharacter ].. ],
        $appendGeneralMessage = True;
        text,
        text
    ];

makePacketMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sandboxFormatter*)
sandboxFormatter // beginDefinition;

sandboxFormatter[ code_String, "Parameters", "code" ] :=
    RawBoxes @ makeInteractiveCodeCell[
        "Wolfram",
        inlineExpressionURIs @ sandboxStringNormalize @ code
    ];

sandboxFormatter[ KeyValuePattern[ "Result" -> result_ ], "Result" ] :=
    sandboxFormatter[ result, "Result" ];

sandboxFormatter[ result_, "Result" ] :=
    RawBoxes @ makeInteractiveCodeCell[ "Wolfram", Cell[ BoxData @ MakeBoxes @ result, "Input" ] ];

sandboxFormatter[ result_, ___ ] := result;

sandboxFormatter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineExpressionURIs*)
inlineExpressionURIs // beginDefinition;

inlineExpressionURIs[ boxes_ ] := boxes /. {
    RowBox @ { "InlinedExpression", "[", uri_String, "]" } :>
        With[ { e = Quiet @ ToExpression[ uri, StandardForm, inlineExpressionURI ] },
            e /; True
        ]
};

inlineExpressionURIs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineExpressionURI*)
inlineExpressionURI // beginDefinition;
inlineExpressionURI // Attributes = { HoldAllComplete };

inlineExpressionURI[ uri_String ] :=
    With[ { expr = Quiet @ catchAlways @ GetExpressionURI[ uri, HoldComplete ] },
        inlineExpressionURI[ uri, expr ]
    ];

inlineExpressionURI[ uri_, failed_? FailureQ ] :=
    makeCachedBoxes @ failed;

inlineExpressionURI[ uri_, HoldComplete[ expr_? makeCachedBoxesQ ] ] :=
    makeCachedBoxes @ expr;

inlineExpressionURI[ uri_, HoldComplete[ expr_ ] ] :=
    With[ { boxes = makeCachedBoxes @ expr },
        If[ smallBoxesQ @ boxes,
            boxes,
            makeCachedBoxes @ IconizedObject[ expr, Automatic, Method -> Compress ]
        ]
    ];

inlineExpressionURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCachedBoxesQ*)
makeCachedBoxesQ // beginDefinition;
makeCachedBoxesQ // Attributes = { HoldAllComplete };
makeCachedBoxesQ[ audio_Audio ] := AudioQ @ Unevaluated @ audio;
makeCachedBoxesQ[ video_Video ] := VideoQ @ Unevaluated @ video;
makeCachedBoxesQ[ graph_Graph ] := GraphQ @ Unevaluated @ graph;
makeCachedBoxesQ[ expr_ ] := graphicsQ @ Unevaluated @ expr;
makeCachedBoxesQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCachedBoxes*)
makeCachedBoxes // beginDefinition;
makeCachedBoxes // Attributes = { HoldAllComplete };
makeCachedBoxes[ expr_ ] := Verbatim[ makeCachedBoxes @ expr ] = MakeBoxes @ expr;
makeCachedBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*smallBoxesQ*)
smallBoxesQ // beginDefinition;
smallBoxesQ[ TagBox[ box_, ___ ] ] := smallBoxesQ @ box;
smallBoxesQ[ TemplateBox[ boxes_List, "CopyTag", ___ ] ] := AnyTrue[ boxes, smallBoxesQ ];
smallBoxesQ[ RowBox @ { ___, StyleBox[ _, "NonInterpretableSummary", ___ ], ___ } ] := True;
smallBoxesQ[ _InterpretationBox ] := True;
smallBoxesQ[ _GraphicsBox | _Graphics3DBox ] := True;

smallBoxesQ[ boxes_RowBox ] :=
    Module[ { graphicsCount, withoutGraphics },
        graphicsCount   = 0;
        withoutGraphics = boxes /. _GraphicsBox|_Graphics3DBox :> RuleCondition[ graphicsCount++; "" ];
        graphicsCount  <= 3 && ByteCount @ withoutGraphics <= 10000
    ];

smallBoxesQ[ boxes_ ] := ByteCount @ boxes <= 10000;

smallBoxesQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AppendURIInstructions*)
AppendURIInstructions // beginDefinition;
AppendURIInstructions[ arg__ ] := catchMine @ Block[ { $appendURIPrompt = True }, appendURIInstructions @ arg ];
AppendURIInstructions // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)

(* Close previous sandbox kernel if package is being reloaded: *)
Scan[ LinkClose, Select[ Links[ ], sandboxKernelQ ] ];

addToMXInitialization[
    $generalMessageText;
    $initializationTest;
    $messageOverrides;
    $messageOverrideTemplates;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
