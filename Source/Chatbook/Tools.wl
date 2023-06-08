(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

(* cSpell: ignore TOOLCALL, ENDARGUMENTS, ENDTOOLCALL, pacletreadonly, noinit, playerpass *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

`$attachments;
`$defaultChatTools;
`$toolConfiguration;
`initTools;
`makeToolConfiguration;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"               ];
Needs[ "Wolfram`Chatbook`Common`"        ];
Needs[ "Wolfram`Chatbook`Serialization`" ];

PacletInstall[ "Wolfram/LLMFunctions" ];
Needs[ "Wolfram`LLMFunctions`" ];

System`LLMTool;
System`LLMConfiguration;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Configuration*)

$sandboxEvaluationTimeout = 30;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initTools*)
initTools // beginDefinition;

initTools[ ] := initTools[ ] = (

    If[ $CloudEvaluation && $VersionNumber <= 13.2,

        If[ PacletFind[ "ServiceConnection_OpenAI" ] === { },
            PacletInstall[ "ServiceConnection_OpenAI", PacletSite -> "https://pacletserver.wolfram.com" ]
        ];

        WithCleanup[
            Unprotect @ TemplateObject,
            TemplateObject // Options = DeleteDuplicatesBy[
                Append[ Options @ TemplateObject, MetaInformation -> <| |> ],
                ToString @* First
            ],
            Protect @ TemplateObject
        ]
    ];

    PacletInstall[ "Wolfram/LLMFunctions" ];
    Needs[ "Wolfram`LLMFunctions`" -> None ];
);

initTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeToolConfiguration*)
makeToolConfiguration // beginDefinition;

makeToolConfiguration[ ] := makeToolConfiguration @ Automatic;
makeToolConfiguration[ Inherited|Automatic ] := makeToolConfiguration @ Values @ $defaultChatTools;

makeToolConfiguration[ tool_LLMTool ] := makeToolConfiguration @ { tool };

makeToolConfiguration[ tools: { (Inherited|_LLMTool)... } ] := (
    initTools[ ];
    LLMConfiguration @ <|
        "Tools"      -> DeleteDuplicates @ Flatten @ Replace[ tools, Inherited :> Values @ $defaultChatTools, { 1 } ],
        "ToolPrompt" -> $toolPrompt
    |>
);

makeToolConfiguration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$toolConfiguration*)
$toolConfiguration := $toolConfiguration = LLMConfiguration @ <| "Tools" -> Values @ $defaultChatTools |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$toolPrompt*)
$toolPrompt := $toolPrompt = TemplateObject[
    {
        $toolPre,
        TemplateSequence[
            StringTemplate[
                "Name: `Name`\nDescription: `Description`\nArguments: `Parameters`\n\n",
                InsertionFunction -> toolTemplateDataString
            ],
            TemplateExpression[ #[ "Data" ] & /@ TemplateSlot[ "Tools" ] ]
        ],
        $toolPost
    },
    CombinerFunction  -> StringJoin,
    InsertionFunction -> TextString
];


$toolPre = "\
# Tool Instructions

You have access to system tools which can be used to do things, fetch data, compute, etc. while you create your response. Here are the available tools:

";


$toolPost = "

To call a tool, write the following at any time during your response:

```
TOOLCALL: <tool name>
{
	\"<parameter name 1>\": <value 1>
	\"<parameter name 2>\": <value 2>
}
ENDARGUMENTS
ENDTOOLCALL
```

The system will execute the requested tool call and you will receive a system message containing the result.

You can then use this result to finish writing your response for the user.

Here is a full example:

---

user:
How do I use AstroGraphics?

assistant:
Let me check the documentation for you. One moment...
TOOLCALL: documentation_lookup
{
	\"names\": \"AstroGraphics\"
}
ENDARGUMENTS
ENDTOOLCALL

system:
# Usage
AstroGraphics[primitives, options] represents a two-dimensional view of space and the celestial sphere.

# Basic Examples
<example text>

assistant:
To use [AstroGraphics](paclet:ref/AstroGraphics), you need to provide a list of graphics primitives and options. \
For example, <remainder of response>

---
";

toolTemplateDataString[ str_String ] := str;
toolTemplateDataString[ expr_ ] := ToString[ expr, InputForm ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Tools*)
$defaultChatTools := If[ TrueQ @ $CloudEvaluation,
                         KeyDrop[ $defaultChatTools0, { "wolfram_language_evaluator", "documentation_search" } ],
                         $defaultChatTools0
                     ];

$defaultChatTools0 = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DocumentationSearch*)
$defaultChatTools0[ "documentation_search" ] = LLMTool[
    <|
        "Name"        -> "documentation_search",
        "DisplayName" -> "Documentation Search",
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "PersonaDocumentation" ],
        "Description" -> "Search Wolfram Language documentation for symbols and more.",
        "Parameters"  -> {
            "query" -> <|
                "Interpreter" -> "String",
                "Help"        -> "A string representing a documentation search query",
                "Required"    -> True
            |>
        },
        "Function" -> documentationSearch
    |>,
    { }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationSearch*)
documentationSearch // beginDefinition;
documentationSearch[ KeyValuePattern[ "query" -> name_ ] ] := documentationSearch @ name;
documentationSearch[ names_List ] := StringRiffle[ documentationSearch /@ names, "\n\n" ];
documentationSearch[ name_String ] /; NameQ[ "System`" <> name ] := documentationLookup @ name;
documentationSearch[ query_String ] := documentationSearch[ query, documentationSearchAPI @ query ];
documentationSearch[ query_String, { } ] := ToString[ Missing[ "NoResults" ], InputForm ];
documentationSearch[ query_String, results_List ] := StringRiffle[ results, "\n" ];
documentationSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DocumentationLookup*)
$defaultChatTools0[ "documentation_lookup" ] = LLMTool[
    <|
        "Name"        -> "documentation_lookup",
        "DisplayName" -> "Documentation Lookup",
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "PersonaDocumentation" ],
        "Description" -> "Get documentation pages for Wolfram Language symbols.",
        "Parameters"  -> {
            "names" -> <|
                "Interpreter" -> DelimitedSequence[ "WolframLanguageSymbol", "," ],
                "Help"        -> "One or more Wolfram Language symbols separated by commas",
                "Required"    -> True
            |>
        },
        "Function" -> documentationLookup
    |>,
    { }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationLookup*)
documentationLookup // beginDefinition;

documentationLookup[ KeyValuePattern[ "names" -> name_ ] ] := documentationLookup @ name;
documentationLookup[ name_Entity ] := documentationLookup @ CanonicalName @ name;
documentationLookup[ names_List ] := StringRiffle[ documentationLookup /@ names, "\n\n---\n\n" ];

documentationLookup[ name_String ] := Enclose[
    Module[ { usage, details, examples, strings, body },
        usage    = ConfirmMatch[ documentationUsage @ name, _String|_Missing, "Usage" ];
        details  = ConfirmMatch[ documentationDetails @ name, _String|_Missing, "Details" ];
        examples = ConfirmMatch[ documentationBasicExamples @ name, _String|_Missing, "Examples" ];
        strings  = ConfirmMatch[ DeleteMissing @ { usage, details, examples }, { ___String }, "Strings" ];
        body     = If[ strings === { }, ToString[ Missing[ "NotFound" ], InputForm ], StringRiffle[ strings, "\n\n" ] ];
        "# " <> name <> "\n\n" <> body
    ],
    throwInternalFailure[ documentationLookup @ name, ## ] &
];

documentationLookup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationUsage*)
documentationUsage // beginDefinition;
documentationUsage[ name_String ] := documentationUsage[ name, wolframLanguageData[ name, "PlaintextUsage" ] ];
documentationUsage[ name_, missing_Missing ] := missing;
documentationUsage[ name_, usage_String ] := "## Usage\n\n" <> usage;
documentationUsage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationDetails*)
documentationDetails // beginDefinition;
documentationDetails[ name_String ] := Missing[ ]; (* TODO *)
documentationDetails // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationBasicExamples*)
documentationBasicExamples // beginDefinition;

documentationBasicExamples[ name_String ] :=
    documentationBasicExamples[ name, wolframLanguageData[ name, "DocumentationBasicExamples" ] ];

documentationBasicExamples[ name_, missing_Missing ] := missing;

documentationBasicExamples[ name_, examples_List ] := Enclose[
    Module[ { cells, strings },
        cells   = renumberCells @ Replace[ Flatten @ examples, RawBoxes[ cell_ ] :> cell, { 1 } ];
        strings = ConfirmMatch[ cellToString /@ cells, { ___String }, "CellToString" ];
        If[ strings === { },
            Missing[ ],
            StringDelete[ "## Basic Examples\n\n" <> StringRiffle[ strings, "\n\n" ], "```\n\n```" ]
        ]
    ],
    throwInternalFailure[ documentationBasicExamples[ name, examples ], ## ] &
];

documentationBasicExamples // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*cellToString*)
cellToString[ args___ ] := Block[ { $maxOutputCellStringLength = 100 }, CellToString @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*renumberCells*)
renumberCells // beginDefinition;
renumberCells[ cells_List ] := Block[ { $line = 0 }, renumberCell /@ Flatten @ cells ];
renumberCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*renumberCell*)
renumberCell // beginDefinition;

renumberCell[ Cell[ a__, "Input", b: (Rule|RuleDelayed)[ _, _ ]... ] ] :=
    Cell[ a, "Input", CellLabel -> "In[" <> ToString @ ++$line <> "]:=" ];

renumberCell[ Cell[ a__, "Output", b: (Rule|RuleDelayed)[ _, _ ]... ] ] :=
    Cell[ a, "Output", CellLabel -> "Out[" <> ToString @ $line <> "]=" ];

renumberCell[ Cell[ a__, style: "Print"|"Echo", b: (Rule|RuleDelayed)[ _, _ ]... ] ] :=
    Cell[ a, style, CellLabel -> "During evaluation of In[" <> ToString @ $line <> "]:=" ];

renumberCell[ cell_Cell ] := cell;

renumberCell // endDefinition;

$line = 0;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Evaluate*)

$sandboxEvaluateDescription = "\
Evaluate Wolfram Language code for the user in a separate sandboxed kernel. \
You do not need to tell the user the input code that you are evaluating. \
They will be able to inspect it if they want to. \
The user does not automatically see the result. \
You must include the result in your response in order for them to see it.

Example
---
user: Plot sin(x) from -5 to 5

assistant: Let me plot that for you. Just a moment...
TOOLCALL: sandbox_evaluate
{
	\"code\": \"Plot[Sin[x], {x, -10, 10}, AxesLabel -> {\\\"x\\\", \\\"sin(x)\\\"}]\"
}
ENDARGUMENTS
ENDTOOLCALL

system: ![result](expression://result-xxxx)

assistant: Here's the plot of $sin(x)$ from $-5$ to $5$:
![Plot](expression://result-xxxx)
";

$defaultChatTools0[ "wolfram_language_evaluator" ] = LLMTool[
    <|
        "Name"        -> "wolfram_language_evaluator",
        "DisplayName" -> "Wolfram Language Evaluator",
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ],
        "Description" -> $sandboxEvaluateDescription,
        "Parameters"  -> {
            "code" -> <|
                "Interpreter" -> Restricted[ "HeldExpression", All ],
                "Help"        -> "Wolfram Language code to evaluate",
                "Required"    -> True
            |>
        },
        "Function" -> sandboxEvaluate
    |>,
    { }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startSandboxKernel*)
startSandboxKernel // beginDefinition;

startSandboxKernel[ ] := Enclose[
    Module[ { pwFile, kernel, pid },

        Scan[ LinkClose, Select[ Links[ ], sandboxKernelQ ] ];

        (* pwFile = FileNameJoin @ { $InstallationDirectory, "Configuration", "Licensing", "playerpass" }; *)

        kernel = ConfirmMatch[
            LinkLaunch @ StringJoin[
                First @ $CommandLine,
                " -wstp -pacletreadonly -noinit -noicon",
                If[ FileExistsQ @ pwFile, " -pwfile \""<>pwFile<>"\"", "" ],
                " -run ChatbookSandbox" <> ToString @ $ProcessID
            ],
            _LinkObject,
            "LinkLaunch"
        ];

        (* Use StartProtectedMode instead of passing the -sandbox argument, since we need to initialize the FE first *)
        LinkWrite[ kernel, Unevaluated @ EvaluatePacket[ UsingFrontEnd @ Null; Developer`StartProtectedMode[ ] ] ];

        pid = pingSandboxKernel @ kernel;

        (* Reset line number and leave `In[1]:=` in the buffer *)
        LinkWrite[ kernel, Unevaluated @ EnterExpressionPacket[ $Line = 0 ] ];
        TimeConstrained[
            While[ ! MatchQ[ LinkRead @ kernel, _ReturnExpressionPacket ] ],
            10,
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
(*getSandboxKernel*)
getSandboxKernel // beginDefinition;
getSandboxKernel[ ] := getSandboxKernel @ Select[ Links[ ], sandboxKernelQ ];
getSandboxKernel[ { other__LinkObject, kernel_ } ] := (Scan[ LinkClose, { other } ]; getSandboxKernel @ { kernel });
getSandboxKernel[ { kernel_LinkObject } ] := checkSandboxKernel @ kernel;
getSandboxKernel[ { } ] := startSandboxKernel[ ];
getSandboxKernel // endDefinition;

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
(* ::Subsubsection::Closed:: *)
(*sandboxKernelQ*)
sandboxKernelQ[ LinkObject[ cmd_String, ___ ] ] := StringContainsQ[ cmd, "ChatbookSandbox" <> ToString @ $ProcessID ];
sandboxKernelQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sandboxEvaluate*)
sandboxEvaluate // beginDefinition;

sandboxEvaluate[ KeyValuePattern[ "code" -> code_ ] ] := sandboxEvaluate @ code;

sandboxEvaluate[ HoldComplete[ evaluation_ ] ] := Enclose[
    Module[ { kernel, null, packets, $timedOut, results, flat },

        $lastSandboxEvaluation = HoldComplete @ evaluation;

        kernel = ConfirmMatch[ getSandboxKernel[ ], _LinkObject, "GetKernel" ];

        LinkWrite[
            kernel,
            Unevaluated @ EnterExpressionPacket @ BinarySerialize[ HoldComplete @@ { evaluation } ]
        ];

        { null, { packets } } = Reap[
            TimeConstrained[
                While[ ! MatchQ[ Sow @ LinkRead @ kernel, _ReturnExpressionPacket ] ],
                $sandboxEvaluationTimeout,
                $timedOut
            ]
        ];

        If[ null === $timedOut,
            AppendTo[ packets, ReturnExpressionPacket @ BinarySerialize @ HoldComplete @ $TimedOut ]
        ];

        results = Cases[
            packets,
            ReturnExpressionPacket[ bytes_ByteArray ] :> BinaryDeserialize @ bytes
        ];

        flat = Flatten[ HoldComplete @@ results, 1 ];

        (* TODO: include prompting that explains how to use Out[n] to get previous results *)

        $lastSandboxResult = <|
            "String"  -> sandboxResultString @ flat,
            "Result"  -> flat,
            "Packets" -> packets
        |>
    ],
    throwInternalFailure[ sandboxEvaluate @ HoldComplete @ evaluation, ## ] &
];

sandboxEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*linkWriteEvaluation*)
linkWriteEvaluation // beginDefinition;
linkWriteEvaluation // Attributes = { HoldAllComplete };

linkWriteEvaluation[ kernel_, evaluation_ ] :=
    LinkWrite[
        kernel,
        Unevaluated @ EnterExpressionPacket @ BinarySerialize[ <| "Line" -> $Line, "Result" -> HoldComplete @@ { evaluation } |> ]
    ];

linkWriteEvaluation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sandboxResultString*)
sandboxResultString // beginDefinition;

(* TODO: show messages etc. *)
sandboxResultString[ HoldComplete[ Null..., expr: Except[ _Graphics|_Graphics3D ] ] ] :=
    With[ { string = ToString[ Unevaluated @ expr, InputForm, PageWidth -> 80 ] },
        "```\n"<>string<>"\n```" /; StringLength @ string < 240
    ];

sandboxResultString[ HoldComplete[ Null..., expr_ ] ] :=
    With[ { id = "result-"<>Hash[ Unevaluated @ expr, Automatic, "HexString" ] },
        $attachments[ id ] = HoldComplete @ expr;
        "![result](expression://" <> id <> ")"
    ];

sandboxResultString // endDefinition;

$attachments = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Documentation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wolframLanguageData*)
wolframLanguageData // beginDefinition;

wolframLanguageData[ name_, property_ ] := Enclose[
    wolframLanguageData[ name, property ] = ConfirmBy[ WolframLanguageData[ name, property ], Not@*FailureQ ],
    Missing[ "DataFailure" ] &
];

wolframLanguageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    $toolConfiguration;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
