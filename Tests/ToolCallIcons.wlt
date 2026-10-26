(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*getToolCallIcon*)

(* Built-in tools declare a "CallIcon" that uses their "ToolIconCall<name>" resource: *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolCallIcon[ Wolfram`Chatbook`Common`getToolByName[ "web_fetcher" ] ][ RGBColor[ 1, 0, 0 ] ],
    Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconCallWebFetcher" ][ RGBColor[ 1, 0, 0 ] ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-BuiltIn"
]

(* A tool that shares a built-in tool's name but has no "CallIcon" (e.g. an installed copy) uses the built-in glyph: *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolCallIcon[ <| "Name" -> "wolfram_alpha", "Function" -> Identity |> ][ RGBColor[ 1, 0, 0 ] ],
    Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconCallWolframAlpha" ][ RGBColor[ 1, 0, 0 ] ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-BuiltIn-Name-Fallback"
]

(* Tools without a "CallIcon" get the generic glyph, even if they define their own "Icon": *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolCallIcon[ <| "Name" -> "made_up_tool", "Function" -> Identity, "Icon" -> "X" |> ][
        RGBColor[ 1, 0, 0 ]
    ],
    Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconCallGenericTool" ][ RGBColor[ 1, 0, 0 ] ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-Generic"
]

(* Tools from the LLM Tool Repository without a "CallIcon" get the repository glyph: *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolCallIcon[
        <| "Name" -> "made_up_tool", "Function" -> Identity, "Origin" -> "LLMToolRepository" |>
    ][ RGBColor[ 1, 0, 0 ] ],
    Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconCallRepositoryTool" ][ RGBColor[ 1, 0, 0 ] ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-Repository"
]

(* A third-party "CallIcon" receives the color chosen by Chatbook: *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolCallIcon[
        <| "Name" -> "made_up_tool", "Function" -> Identity, "CallIcon" -> (Style[ "*", #1 ] &) |>
    ][ RGBColor[ 1, 0, 0 ] ],
    Style[ "*", RGBColor[ 1, 0, 0 ] ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-Custom"
]

(* A "CallIcon" that fails, or that isn't a function, falls back to the generic glyph: *)
VerificationTest[
    {
        Wolfram`Chatbook`Common`getToolCallIcon[
            <| "Name" -> "made_up_tool", "Function" -> Identity, "CallIcon" -> Function[ col, Style[ 1/0, col ] ] |>
        ][ RGBColor[ 1, 0, 0 ] ],
        Wolfram`Chatbook`Common`getToolCallIcon[
            <| "Name" -> "made_up_tool", "Function" -> Identity, "CallIcon" -> "not a function" |>
        ][ RGBColor[ 1, 0, 0 ] ]
    },
    {
        Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconCallGenericTool" ][ RGBColor[ 1, 0, 0 ] ],
        Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconCallGenericTool" ][ RGBColor[ 1, 0, 0 ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "CallIcon-Invalid-Fallback"
]

(* The catalog "Icon" used by the Tool Manager is unchanged by "CallIcon": *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolIcon @ <| "Name" -> "made_up_tool", "Function" -> Identity |>,
    Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "WrenchIcon" ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-Catalog-Icon-Unchanged"
]

(* :!CodeAnalysis::EndBlock:: *)
