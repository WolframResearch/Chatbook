(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

(* cSpell: ignore TOOLCALL, ENDARGUMENTS, ENDTOOLCALL, pacletreadonly, noinit, playerpass, Deflatten *)

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
Needs[ "Wolfram`Chatbook`Utils`"         ];

PacletInstall[ "Wolfram/LLMFunctions" ];
Needs[ "Wolfram`LLMFunctions`" ];

System`LLMTool;
System`LLMConfiguration;

(* TODO:
    WolframAlpha
    ImageSynthesize
    LongTermMemory
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Configuration*)

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
    "-pacletreadonly",
    "-run",
    "ChatbookSandbox" <> ToString @ $ProcessID
};

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


$toolPost := "

To call a tool, write the following on a new line at any time during your response:

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

You must write the TOOLCALL in your CURRENT response. \
Do not state that you will use a tool and end your message before making the tool call.

If a user asks you to use a specific tool, you MUST attempt to use that tool as requested, \
even if you think it will not work. \
If the tool fails, use any error message to explain why it failed. \
NEVER state that a tool cannot be used for a particular task without trying it first. \
You did not create these tools, so you do not know what they can and cannot do.

## Full examples
" <> $fullExamples;


toolTemplateDataString[ str_String ] := str;
toolTemplateDataString[ expr_ ] := ToString[ expr, InputForm ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Full Examples*)

$fullExamples := StringJoin[
    "\n---\n\n",
    StringRiffle[ Values @ KeyTake[ $fullExamples0, $fullExamplesKeys ], "\n\n---\n\n" ],
    "\n\n---\n"
];

$fullExamplesKeys :=
    If[ TrueQ @ $CloudEvaluation,
        { "AstroGraphicsDocumentation" },
        { "AstroGraphicsDocumentation", "PlotEvaluate", "TemporaryDirectory" }
    ];


$fullExamples0 = <| |>;


$fullExamples0[ "AstroGraphicsDocumentation" ] = "\
[user]
How do I use AstroGraphics?

[assistant]
Let me check the documentation for you. One moment...
TOOLCALL: documentation_lookup
{
	\"names\": \"AstroGraphics\"
}
ENDARGUMENTS
ENDTOOLCALL

[system]
Usage
AstroGraphics[primitives, options] represents a two-dimensional view of space and the celestial sphere.

Basic Examples
<example text>

[assistant]
To use [AstroGraphics](paclet:ref/AstroGraphics), you need to provide a list of graphics primitives and options. \
For example, <remainder of response>";


$fullExamples0[ "PlotEvaluate" ] = "\
[user]
Plot sin(x) from -5 to 5

[assistant]
TOOLCALL: wolfram_language_evaluator
{
	\"code\": \"Plot[Sin[x], {x, -10, 10}, AxesLabel -> {\\\"x\\\", \\\"sin(x)\\\"}]\"
}
ENDARGUMENTS
ENDTOOLCALL

[system]
Out[1]= ![result](expression://result-xxxx)

[assistant]
Here's the plot of $\\sin{x}$ from -5 to 5:
![Plot](expression://result-xxxx)";


$fullExamples0[ "TemporaryDirectory" ] = "\
[user]
Where is the temporary directory located?

[assistant]
TOOLCALL: documentation_search
{
	\"query\": \"location of temporary directory\"
}
ENDARGUMENTS
ENDTOOLCALL

[system]
* $TemporaryDirectory - (score: 9.6) $TemporaryDirectory gives the main system directory for temporary files.
* CreateDirectory - (score: 8.5) CreateDirectory[\"dir\"] creates ...

[assistant]
TOOLCALL: wolfram_language_evaluator
{
	\"code\": \"$TemporaryDirectory\"
}
ENDARGUMENTS
ENDTOOLCALL

[system]
Out[2]= \"C:\\Users\\UserName\\AppData\\Local\\Temp\"

[assistant]
The temporary directory is located at C:\\Users\\UserName\\AppData\\Local\\Temp.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Tools*)
$defaultChatTools := If[ TrueQ @ $CloudEvaluation,
                         KeyDrop[ $defaultChatTools0, $cloudUnsupportedTools ],
                         $defaultChatTools0
                     ];

$defaultChatTools0 = <| |>;

$cloudUnsupportedTools = { "wolfram_language_evaluator", "documentation_search" };

$defaultToolOrder = { "documentation_lookup", "documentation_search", "wolfram_alpha", "wolfram_language_evaluator" };

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

(* $sandboxEvaluateDescription = "\
Evaluate Wolfram Language code for the user in a separate sandboxed kernel. \
You do not need to tell the user the input code that you are evaluating. \
They will be able to inspect it if they want to. \
The user does not automatically see the result. \
You must include the result in your response in order for them to see it.

Example
---
user: Plot sin(x) from -5 to 5

assistant: Let me plot that for you. Just a moment...
TOOLCALL: wolfram_language_evaluator
{
	\"code\": \"Plot[Sin[x], {x, -10, 10}, AxesLabel -> {\\\"x\\\", \\\"sin(x)\\\"}]\"
}
ENDARGUMENTS
ENDTOOLCALL

system: Out[1]= ![result](expression://result-xxxx)

assistant: Here's the plot of $sin(x)$ from $-5$ to $5$:
![Plot](expression://result-xxxx)
"; *)

$sandboxEvaluateDescription = "\
Evaluate Wolfram Language code for the user in a separate sandboxed kernel. \
You do not need to tell the user the input code that you are evaluating. \
They will be able to inspect it if they want to. \
The user does not automatically see the result. \
You must include the result in your response in order for them to see it.
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

        kernel = ConfirmMatch[ LinkLaunch @ $sandboxKernelCommandLine, _LinkObject, "LinkLaunch" ];

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

        ConfirmMatch[ linkWriteEvaluation[ kernel, evaluation ], Null, "LinkWriteEvaluation" ];

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
            "String"  -> sandboxResultString[ flat, packets ],
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
        Unevaluated @ EnterExpressionPacket @ BinarySerialize[
            <| "Line" -> $Line, "Result" -> HoldComplete @@ { evaluation } |>
        ]
    ];

linkWriteEvaluation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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

sandboxResultString[ HoldComplete[ Null..., expr_ ] ] := sandboxResultString @ HoldComplete @ expr;

sandboxResultString[ HoldComplete[ expr: Except[ _Graphics|_Graphics3D ] ] ] :=
    With[ { string = ToString[ Unevaluated @ expr, InputForm, PageWidth -> 80 ] },
        string /; StringLength @ string < 240
    ];

sandboxResultString[ HoldComplete[ expr_ ] ] := makeExpressionURI @ Unevaluated @ expr;

sandboxResultString // endDefinition;

$attachments = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePacketMessages*)
makePacketMessages // beginDefinition;
makePacketMessages[ line_, packets_List ] := makePacketMessages[ line, # ] & /@ packets;
(* makePacketMessages[ line_String, TextPacket[ text_String ] ] /; StringStartsQ[ text, ">> " ] := text;
makePacketMessages[ line_String, TextPacket[ text_String ] ] := "During evaluation of In[" <> line <> "]:= " <> text; *)
makePacketMessages[ line_String, TextPacket[ text_String ] ] := text;
makePacketMessages[ line_, _InputNamePacket|_MessagePacket|_OutputNamePacket|_ReturnExpressionPacket ] := Nothing;
makePacketMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Wolfram Alpha*)

(* $wolframAlphaDescription = "Get Wolfram|Alpha results

## Wolfram Alpha Tool Guidelines
- Understands natural language queries about entities in chemistry, physics, geography, history, art, astronomy, and more.
- Performs mathematical calculations, date and unit conversions, formula solving, etc.
- Convert inputs to simplified keyword queries whenever possible (e.g. convert \"how many people live in France\" to \"France population\").
- Use ONLY single-letter variable names, with or without integer subscript (e.g., n, n1, n_1).
- Use named physical constants (e.g., 'speed of light') without numerical substitution.
- Include a space between compound units (e.g., \"\[CapitalOmega] m\" for \"ohm*meter\").
- To solve for a variable in an equation with units, consider solving a corresponding equation without units; exclude counting units (e.g., books), include genuine units (e.g., kg).
- If data for multiple properties is needed, make separate calls for each property.
- If a Wolfram Alpha result is not relevant to the query:
 -- If Wolfram provides multiple 'Assumptions' for a query, choose the more relevant one(s) without explaining the initial result. If you are unsure, ask the user to choose.
 -- Re-send the exact same 'input' with NO modifications, and add the 'assumption' parameter, formatted as a list, with the relevant values.
 -- ONLY simplify or rephrase the initial query if a more relevant 'Assumption' or other input suggestions are not provided.
 -- Do not explain each step unless user input is needed. Proceed directly to making a better API call based on the available assumptions.
 "; *)

$wolframAlphaDescription = "\
Use natural language queries with Wolfram|Alpha to get up-to-date computational results about entities in chemistry, \
physics, geography, history, art, astronomy, and more.";

$wolframAlphaIcon = RawBoxes @ PaneBox[
    DynamicBox @ FEPrivate`FrontEndResource[ "FEBitmaps", "InsertionAlpha" ],
    BaselinePosition -> Center -> Scaled[ 0.55 ]
];

$defaultChatTools0[ "wolfram_alpha" ] = LLMTool[
    <|
        "Name"        -> "wolfram_alpha",
        "DisplayName" -> "Wolfram Alpha",
        "Icon"        -> $wolframAlphaIcon,
        "Description" -> $wolframAlphaDescription,
        "Parameters"  -> {
            "input" -> <|
                "Interpreter" -> "String",
                "Help"        -> "the input",
                "Required"    -> True
            |>(*,
            "assumption" -> <|
                "Interpreter" -> "String",
                "Help"        -> "the assumption to use, passed back from a previous query with the same input.",
                "Required"    -> False
            |>*)
        },
        "Function" -> getWolframAlphaText
    |>,
    { }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getWolframAlphaText*)
getWolframAlphaText // beginDefinition;

getWolframAlphaText[ KeyValuePattern[ "input" -> query_String ] ] :=
    getWolframAlphaText @ query;

getWolframAlphaText[ query_String ] :=
    getWolframAlphaText[ query, WolframAlpha[ query, { All, { "Title", "Plaintext", "ComputableData", "Content" } } ] ];

getWolframAlphaText[ query_String, { } ] :=
    "No results returned";

getWolframAlphaText[ query_String, info_List ] :=
    getWolframAlphaText[ query, associationKeyDeflatten[ makeKeySequenceRule /@ info ] ];

getWolframAlphaText[ query_String, as_Association? AssociationQ ] :=
    getWolframAlphaText[ query, waResultText @ as ];

getWolframAlphaText[ query_String, result_String ] :=
    escapeMarkdownString @ result;

getWolframAlphaText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeKeySequenceRule*)
makeKeySequenceRule // beginDefinition;
makeKeySequenceRule[ { _, "Cell"|"Position"|"Scanner" } -> _ ] := Nothing;
makeKeySequenceRule[ key_ -> value_ ] := makeKeySequence @ key -> value;
makeKeySequenceRule // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeKeySequence*)
makeKeySequence // beginDefinition;

makeKeySequence[ { { path_String, n_Integer }, key_String } ] :=
    makeKeySequence @ Flatten @ { Reverse @ StringSplit[ path, ":" ], n, key };

makeKeySequence[ { path__String, 0, key_String } ] :=
    { path, key };

makeKeySequence[ { path__String, n_Integer, key_String } ] :=
    { path, "Data", n, key };

makeKeySequence // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*waResultText*)
waResultText // beginDefinition;
waResultText[ as_ ] := Block[ { $level = 1 }, StringRiffle[ Flatten @ Values[ waResultText0 /@ as ], "\n" ] ];
waResultText // endDefinition;


waResultText0 // beginDefinition;

waResultText0[ as: KeyValuePattern @ { "Title" -> title_String, "Data" -> data_ } ] :=
    StringRepeat[ "#", $level ] <> " " <> title <> "\n" <> waResultText0 @ data;

waResultText0[ as: KeyValuePattern[ _Integer -> _ ] ] :=
    waResultText0 /@ Values @ KeySort @ KeySelect[ as, IntegerQ ];

waResultText0[ KeyValuePattern @ { "Plaintext" -> text_String, "ComputableData" -> Hold[ expr_ ] } ] :=
    If[ ByteCount @ Unevaluated @ expr >= 500,
        If[ StringFreeQ[ text, "["|"]"|"\n" ],
            makeExpressionURI[ text, Unevaluated @ expr ] <> "\n",
            text <> "\n" <> makeExpressionURI[ Unevaluated @ expr ] <> "\n"
        ],
        text <> "\n"
    ];

waResultText0[ as: KeyValuePattern @ { "Plaintext" -> text_String, "ComputableData" -> expr: Except[ _Hold ] } ] :=
    waResultText0 @ Append[ as, "ComputableData" -> Hold @ expr ];

waResultText0[ KeyValuePattern @ { "Plaintext" -> text_String, "Content" -> content_ } ] :=
    If[ ByteCount @ content >= 500,
        If[ StringFreeQ[ text, "["|"]"|"\n" ],
            makeExpressionURI[ text, Unevaluated @ content ] <> "\n",
            text <> "\n" <> makeExpressionURI[ Unevaluated @ content ] <> "\n"
        ],
        text <> "\n"
    ];

waResultText0[ as_Association ] /; Length @ as === 1 :=
    waResultText0 @ First @ as;

waResultText0[ as_Association ] :=
    KeyValueMap[
        Function[
            StringJoin[
                StringRepeat[ "#", $level ],
                " ",
                ToString[ #1 ],
                "\n",
                Block[ { $level = $level + 1 }, waResultText0[ #2 ] ]
            ]
        ],
        as
    ];

waResultText0[ expr_ ] :=
    With[ { s = ToString[ Unevaluated @ expr, InputForm ] }, s <> "\n" /; StringLength @ s <= 100 ];

waResultText0[ expr_ ] :=
    makeExpressionURI @ Unevaluated @ expr <> "\n";

waResultText0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Expression URIs*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeExpressionURI*)
makeExpressionURI // beginDefinition;

makeExpressionURI[ expr_ ] :=
    makeExpressionURI[ Automatic, Unevaluated @ expr ];

makeExpressionURI[ label_, expr_ ] :=
    makeExpressionURI[ Automatic, label, Unevaluated @ expr ];

makeExpressionURI[ Automatic, label_, expr_ ] :=
    makeExpressionURI[ expressionURIScheme @ expr, label, Unevaluated @ expr ];

makeExpressionURI[ scheme_, Automatic, expr_ ] :=
    makeExpressionURI[ scheme, expressionURILabel @ expr, Unevaluated @ expr ];

makeExpressionURI[ scheme_, label_, expr_ ] :=
    With[ { id = "result-" <> Hash[ Unevaluated @ expr, Automatic, "HexString" ] },
        $attachments[ id ] = HoldComplete @ expr;
        "![" <> TextString @ label <> "](" <> TextString @ scheme <> "://" <> id <> ")"
    ];

makeExpressionURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*expressionURILabel*)
expressionURILabel // beginDefinition;
expressionURILabel // Attributes = { HoldAllComplete };
expressionURILabel[ _Graphics|_Graphics3D|_Image|_Image3D|_Legended|_RawBoxes ] := "image";
expressionURILabel[ _List|_Association ] := "data";
expressionURILabel[ _ ] := "result";
expressionURILabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*expressionURIScheme*)
expressionURIScheme // beginDefinition;
expressionURIScheme // Attributes = { HoldAllComplete };
expressionURIScheme[ _Graphics|_Graphics3D|_Image|_Image3D|_Legended|_RawBoxes ] := "attachment";
expressionURIScheme[ _ ] := "expression";
expressionURIScheme // endDefinition;

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

(* Sort tools to their default ordering: *)
$defaultChatTools0 = Association[ KeyTake[ $defaultChatTools0, $defaultToolOrder ], $defaultChatTools0 ];


If[ Wolfram`ChatbookInternal`$BuildingMX,
    $toolConfiguration;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
