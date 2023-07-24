(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Sandbox`" ];

(* cSpell: ignore noinit pacletreadonly playerpass sntx *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

`fancyResultQ;
`sandboxEvaluate;
`simpleResultQ;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`Common`" ];
Needs[ "Wolfram`Chatbook`Tools`"  ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

$sandboxEvaluationTimeout = 30;

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
            TimeConstrained[ While[ LinkReadyQ @ kernel, LinkRead @ kernel ], 10, $TimedOut ],
            Except[ $TimedOut ],
            "InitialLinkRead"
        ];

        With[ { id = uuid }, LinkWrite[ kernel, Unevaluated @ EvaluatePacket @ { id, $ProcessID } ] ];

        ConfirmMatch[
            TimeConstrained[ While[ ! MatchQ[ return = LinkRead @ kernel, ReturnPacket @ { uuid, _ } ] ], 10 ],
            Except[ $TimedOut ],
            "LinkReadReturn"
        ];

        ConfirmBy[
            Replace[ return, ReturnPacket @ { _, pid_ } :> pid ],
            IntegerQ,
            "ProcessID"
        ]
    ]
];

pingSandboxKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Start Kernel*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startSandboxKernel*)
startSandboxKernel // beginDefinition;

startSandboxKernel[ ] := Enclose[
    Module[ { pwFile, kernel, readPaths, pid },

        Scan[ LinkClose, Select[ Links[ ], sandboxKernelQ ] ];

        (* pwFile = FileNameJoin @ { $InstallationDirectory, "Configuration", "Licensing", "playerpass" }; *)

        kernel = ConfirmMatch[ LinkLaunch @ $sandboxKernelCommandLine, _LinkObject, "LinkLaunch" ];

        readPaths = Replace[
            $toolOptions[ "WolframLanguageEvaluator", "AllowedReadPaths" ],
            _Missing :> $DefaultToolOptions[ "WolframLanguageEvaluator", "AllowedReadPaths" ]
        ];

        (* Use StartProtectedMode instead of passing the -sandbox argument, since we need to initialize the FE first *)
        With[ { read = $resolvedReadPaths = makePaths @ readPaths },
            LinkWrite[
                kernel,
                Unevaluated @ EvaluatePacket[
                    UsingFrontEnd @ Null;
                    Developer`StartProtectedMode[ "Read" -> read ]
                ]
            ]
        ];

        pid = pingSandboxKernel @ kernel;

        With[ { messages = $messageOverrides },
            LinkWrite[
                kernel,
                Unevaluated @ EnterExpressionPacket[
                    (* Preload some paclets: *)
                    Needs[ "FunctionResource`" -> None ];

                    (* Redefine some messages to provide hints to the LLM: *)
                    ReleaseHold @ messages;

                    (* Reset line number and leave `In[1]:=` in the buffer *)
                    $Line = 0
                ]
            ]
        ];

        TimeConstrained[
            While[ ! MatchQ[ LinkRead @ kernel, _ReturnExpressionPacket ] ],
            30,
            Confirm[ $Failed, "LineReset" ]
        ];

        If[ IntegerQ @ pid,
            kernel,
            Quiet @ LinkClose @ kernel;
            throwFailure[ "NoSandboxKernel" ]
        ]
    ],
    throwInternalFailure[ startSandboxKernel[ ], ## ] &
];

startSandboxKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePaths*)
makePaths // beginDefinition;
makePaths[ All ] := If[ $OperatingSystem === "Windows", # <> ":\\" & /@ CharacterRange[ "A", "Z" ], "/" ];
makePaths[ None ] := { };
makePaths[ paths_List ] := DeleteDuplicates @ Flatten[ makePaths /@ paths ];
makePaths[ path_String ] := path;
makePaths[ Automatic|Inherited|_Missing ] := Automatic;
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

sandboxEvaluate[ KeyValuePattern[ "code" -> code_ ] ] := sandboxEvaluate @ code;
sandboxEvaluate[ code_String ] := sandboxEvaluate @ toSandboxExpression @ code;
sandboxEvaluate[ HoldComplete[ xs__, x_ ] ] := sandboxEvaluate @ HoldComplete @ CompoundExpression[ xs, x ];

sandboxEvaluate[ HoldComplete[ evaluation_ ] ] := Enclose[
    Module[ { kernel, null, packets, $timedOut, results, flat },

        $lastSandboxEvaluation = HoldComplete @ evaluation;

        kernel = ConfirmMatch[ getSandboxKernel[ ], _LinkObject, "GetKernel" ];

        ConfirmMatch[ linkWriteEvaluation[ kernel, evaluation ], Null, "LinkWriteEvaluation" ];

        { null, { packets } } = Reap[
            TimeConstrained[
                While[ ! MatchQ[ Sow @ LinkRead @ kernel, _ReturnExpressionPacket ] ],
                $sandboxEvaluationTimeout,
                $timedOut
            ]
        ];

        If[ null === $timedOut,
            AppendTo[ packets, ReturnExpressionPacket @ HoldComplete @ $TimedOut ]
        ];

        results = Cases[ packets, ReturnExpressionPacket[ expr_ ] :> expr ];

        flat = Flatten[ HoldComplete @@ results, 1 ];

        (* TODO: include prompting that explains how to use Out[n] to get previous results *)

        $lastSandboxResult = <|
            "String"  -> sandboxResultString[ flat, packets ],
            "Result"  -> flat,
            "Packets" -> packets
        |>
    ],
    throwInternalFailure[ sandboxEvaluate @ HoldComplete @ evaluation, ## ] &
];

sandboxEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toSandboxExpression*)
toSandboxExpression // beginDefinition;

toSandboxExpression[ s_String ] := toSandboxExpression[ s, Quiet @ ToExpression[ s, InputForm, HoldComplete ] ];

toSandboxExpression[ s_, expr_HoldComplete ] := expr;

toSandboxExpression[ s_String, $Failed ] /; StringContainsQ[ s, "'" ] :=
    Module[ { new, held },
        new = StringReplace[ s, "'" -> "\"" ];
        held = Quiet @ ToExpression[ new, InputForm, HoldComplete ];
        If[ MatchQ[ held, _HoldComplete ],
            held,
            HoldComplete[ ToExpression[ s, InputForm ] ]
        ]
    ];

toSandboxExpression[ s_String, $Failed ] := HoldComplete @ ToExpression[ s, InputForm ];

toSandboxExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*linkWriteEvaluation*)
linkWriteEvaluation // beginDefinition;
linkWriteEvaluation // Attributes = { HoldAllComplete };

linkWriteEvaluation[ kernel_, evaluation_ ] :=
    With[ { eval = createEvaluationWithWarnings @ evaluation },
        LinkWrite[
            kernel,
            Unevaluated @ EnterExpressionPacket @ <|
                "Line"   -> $Line,
                "Result" -> HoldComplete @@ { ReleaseHold @ eval }
            |>
        ]
    ];

linkWriteEvaluation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createEvaluationWithWarnings*)
createEvaluationWithWarnings // beginDefinition;
createEvaluationWithWarnings // Attributes = { HoldAllComplete };

createEvaluationWithWarnings[ evaluation_ ] :=
    Module[ { held, undefined },
        held = Flatten @ HoldComplete @ evaluation;

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
    HoldComplete @ WithCleanup[
        eval,
        If[ MatchQ[ $MessageList, { __ } ], Message[ General::messages ] ]
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
(*sandboxResultString*)
sandboxResultString // beginDefinition;

sandboxResultString[ result_, packets_ ] := sandboxResultString @ result;

sandboxResultString[ HoldComplete[ KeyValuePattern @ { "Line" -> line_, "Result" -> result_ } ], packets_ ] :=
    StringRiffle[
        Flatten @ {
            makePacketMessages[ ToString @ line, packets ],
            "Out[" <> ToString @ line <> "]= " <> sandboxResultString @ Flatten @ HoldComplete @ result
        },
        "\n"
    ];

sandboxResultString[ HoldComplete[ ___, expr_? simpleResultQ ] ] :=
    With[ { string = ToString[ Unevaluated @ expr, InputForm, PageWidth -> 100 ] },
        If[ StringLength @ string < $toolResultStringLength,
            If[ StringContainsQ[ string, "\n" ], "\n" <> string, string ],
            StringJoin[
                "\n",
                ToString[
                    Unevaluated @ Short[ expr, 5 ],
                    OutputForm,
                    PageWidth -> 100
                ],
                "\n\n\n",
                makeExpressionURI[ "expression", "Formatted Result", Unevaluated @ expr ]
            ]
        ]
    ];

sandboxResultString[ HoldComplete[ ___, expr_ ] ] := makeExpressionURI @ Unevaluated @ expr;

sandboxResultString[ HoldComplete[ ] ] := "Null";

sandboxResultString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleResultQ*)
simpleResultQ // beginDefinition;
simpleResultQ // Attributes = { HoldAllComplete };
simpleResultQ[ expr_ ] := FreeQ[ Unevaluated @ expr, _? fancyResultQ ];
simpleResultQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fancyResultQ*)
fancyResultQ // beginDefinition;
fancyResultQ // Attributes = { HoldAllComplete };
fancyResultQ[ gfx_ ] /; MatchQ[ Unevaluated @ gfx, $$graphics ] := True;
fancyResultQ[ _Manipulate|_DynamicModule ] := True;
fancyResultQ[ _ ] := False;
fancyResultQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePacketMessages*)
makePacketMessages // beginDefinition;
makePacketMessages[ line_, packets_List ] := makePacketMessages[ line, # ] & /@ packets;
makePacketMessages[ line_String, TextPacket[ text_String ] ] := text;
makePacketMessages[ line_, _InputNamePacket|_MessagePacket|_OutputNamePacket|_ReturnExpressionPacket ] := Nothing;
makePacketMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Graphics Utilities*)

$$graphics = HoldPattern[ _GeoGraphics | _Graphics | _Graphics3D | _Image | _Image3D | _Legended ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*graphicsQ*)
graphicsQ[ $$graphics ] := True;
graphicsQ[ g_         ] := MatchQ[ Quiet @ Show @ g, $$graphics ];
graphicsQ[ ___        ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validGraphicsQ*)
validGraphicsQ[ g_? graphicsQ ] := getGraphicsErrors @ Unevaluated @ g === { };
validGraphicsQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getGraphicsErrors*)
getGraphicsErrors // beginDefinition;

(* TODO: hook this up to outputs to give feedback about pink boxes *)
getGraphicsErrors[ gfx_ ] :=
    Module[ { cell, nbo },
        cell = Cell @ BoxData @ MakeBoxes @ gfx;
        UsingFrontEnd @ WithCleanup[
            nbo = NotebookPut[ Notebook @ { cell }, Visible -> False ],
            SelectionMove[ First @ Cells @ nbo, All, Cell ];
            MathLink`CallFrontEnd @ FrontEnd`GetErrorsInSelectionPacket @ nbo,
            NotebookClose @ nbo
        ]
    ];

getGraphicsErrors // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)

(* Close previous sandbox kernel if package is being reloaded: *)
Scan[ LinkClose, Select[ Links[ ], sandboxKernelQ ] ];

If[ Wolfram`ChatbookInternal`$BuildingMX,
    $messageOverrides;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
