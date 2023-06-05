(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

`$defaultChatTools;
`$toolConfiguration;
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeToolConfiguration*)
makeToolConfiguration // beginDefinition;

makeToolConfiguration[ ] := makeToolConfiguration @ Automatic;
makeToolConfiguration[ Inherited|Automatic ] := makeToolConfiguration @ Values @ $defaultChatTools;

makeToolConfiguration[ tool_LLMTool ] := makeToolConfiguration @ { tool };

makeToolConfiguration[ tools: { (Inherited|_LLMTool)... } ] := LLMConfiguration @ <|
    "Tools"      -> DeleteDuplicates @ Flatten @ Replace[ tools, Inherited :> Values @ $defaultChatTools, { 1 } ],
    "ToolPrompt" -> $toolPrompt
|>;

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
$defaultChatTools = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DocumentationSearch*)
$defaultChatTools[ "documentation_search" ] = LLMTool[
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
$defaultChatTools[ "documentation_lookup" ] = LLMTool[
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
Evaluate Wolfram Language code for the user in a sandboxed environment. \
The result will be displayed in the chat for the user to see.

Example
---
user: What's the 1337th prime number?

assistant: Let me calculate that for you. Just a moment...
TOOLCALL: sandbox_evaluate
{
	\"code\": \"Prime[1337]\"
}
ENDARGUMENTS
ENDTOOLCALL
"

$defaultChatTools[ "sandbox_evaluate" ] = LLMTool[
    <|
        "Name"        -> "sandbox_evaluate",
        "DisplayName" -> "Sandbox Evaluate",
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ],
        "ShowResult"  -> True, (* TODO: make this work *)
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
(*$sandBoxKernel*)

(* Close previous $sandboxKernel links in case package was reloaded *)
Scan[ LinkClose, Cases[ Links[ ], LinkObject[ _String? (StringContainsQ[ "SandboxEvaluateTag" ]), ___ ] ] ];

$sandBoxKernel := $sandBoxKernel =
    Module[ { kernel },
        kernel = LinkLaunch @ StringJoin[
            First @ $CommandLine,
            " -wstp -pacletreadonly -sandbox -noinit -noicon -run SandboxEvaluateTag"
        ];
        While[ LinkReadyQ @ kernel, LinkRead @ kernel ];
        kernel
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sandboxEvaluate*)
sandboxEvaluate // beginDefinition;

sandboxEvaluate[ KeyValuePattern[ "code" -> code_ ] ] := sandboxEvaluate @ code;

sandboxEvaluate[ HoldComplete[ evaluation_ ] ] :=
    Module[ { null, packets, results, flat },

        $lastSandboxEvaluation = HoldComplete @ evaluation;

        LinkWrite[
            $sandBoxKernel,
            Unevaluated @ EnterExpressionPacket @ BinarySerialize @ evaluation
        ];

        { null, { packets } } = Reap[
            TimeConstrained[
                While[ ! MatchQ[ Sow @ LinkRead @ $sandBoxKernel, _ReturnExpressionPacket ] ],
                10
            ]
        ];

        results = Cases[
            packets,
            ReturnExpressionPacket[ bytes_ByteArray ] :> BinaryDeserialize[ bytes, HoldComplete ]
        ];

        flat = Flatten[ HoldComplete @@ results, 1 ];

        <|
            "String"  -> sandboxResultString @ flat,
            "Result"  -> flat,
            "Packets" -> packets
        |>
    ];

sandboxEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sandboxResultString*)
sandboxResultString // beginDefinition;

(* TODO: show messages etc. *)
sandboxResultString[ HoldComplete[ expr_ ] ] := StringJoin[
    "[[DISPLAY]]\n",
    CellToString @ Cell[ BoxData @ MakeBoxes @ expr, "Output" ]
];

sandboxResultString // endDefinition;

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

End[ ];
EndPackage[ ];
