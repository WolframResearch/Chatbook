(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ToolCallIcons.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ToolCallIcons.wlt:11,1-16,2"
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
    TestID   -> "CallIcon-BuiltIn@@Tests/ToolCallIcons.wlt:26,1-31,2"
]

(* A tool that shares a built-in tool's name but has no "CallIcon" (e.g. an installed copy) uses the built-in glyph: *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolCallIcon[ <| "Name" -> "wolfram_alpha", "Function" -> Identity |> ][ RGBColor[ 1, 0, 0 ] ],
    Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconCallWolframAlpha" ][ RGBColor[ 1, 0, 0 ] ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-BuiltIn-Name-Fallback@@Tests/ToolCallIcons.wlt:34,1-39,2"
]

(* Tools without a "CallIcon" get the generic glyph, even if they define their own "Icon": *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolCallIcon[ <| "Name" -> "made_up_tool", "Function" -> Identity, "Icon" -> "X" |> ][
        RGBColor[ 1, 0, 0 ]
    ],
    Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconCallGenericTool" ][ RGBColor[ 1, 0, 0 ] ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-Generic@@Tests/ToolCallIcons.wlt:42,1-49,2"
]

(* Tools from the LLM Tool Repository without a "CallIcon" get the repository glyph: *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolCallIcon[
        <| "Name" -> "made_up_tool", "Function" -> Identity, "Origin" -> "LLMToolRepository" |>
    ][ RGBColor[ 1, 0, 0 ] ],
    Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconCallRepositoryTool" ][ RGBColor[ 1, 0, 0 ] ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-Repository@@Tests/ToolCallIcons.wlt:52,1-59,2"
]

(* A third-party "CallIcon" receives the color chosen by Chatbook: *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolCallIcon[
        <| "Name" -> "made_up_tool", "Function" -> Identity, "CallIcon" -> (Style[ "*", #1 ] &) |>
    ][ RGBColor[ 1, 0, 0 ] ],
    Style[ "*", RGBColor[ 1, 0, 0 ] ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-Custom@@Tests/ToolCallIcons.wlt:62,1-69,2"
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
    TestID   -> "CallIcon-Invalid-Fallback@@Tests/ToolCallIcons.wlt:72,1-87,2"
]

(* The catalog "Icon" used by the Tool Manager is unchanged by "CallIcon": *)
VerificationTest[
    Wolfram`Chatbook`Common`getToolIcon @ <| "Name" -> "made_up_tool", "Function" -> Identity |>,
    Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "WrenchIcon" ],
    SameTest -> MatchQ,
    TestID   -> "CallIcon-Catalog-Icon-Unchanged@@Tests/ToolCallIcons.wlt:90,1-95,2"
]

(* :!CodeAnalysis::EndBlock:: *)
