(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)
$defaultChatTools0[ "WebFetcher" ] = <|
    toolDefaultData[ "WebFetcher" ],
    "ShortName"          -> "web_fetch",
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconWebFetcher" ],
    "Description"        -> "Fetch plain text or image links from a URL.",
    "Function"           -> webFetch,
    "FormattingFunction" -> toolAutoFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"  -> {
        "url" -> <|
            "Interpreter" -> "URL",
            "Help"        -> "The URL",
            "Required"    -> True
        |>,
        "format" -> <|
            "Interpreter" -> { "Plaintext", "ImageLinks" },
            "Help"        -> "The type of content to retrieve (\"Plaintext\" or \"ImageLinks\")",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*webFetch*)
webFetch // beginDefinition;
webFetch[ KeyValuePattern @ { "url" -> url_, "format" -> fmt_ } ] := webFetch[ url, fmt ];
webFetch[ url_, "Plaintext" ] := fetchWebText @ url;
webFetch[ url: _URL|_String, fmt_String ] := webFetch[ url, fmt, Import[ url, { "HTML", fmt } ] ];
webFetch[ url_, "ImageLinks", { } ] := <| "Result" -> { }, "String" -> "No links found at " <> TextString @ url |>;
webFetch[ url_, "ImageLinks", links: { __String } ] := <| "Result" -> links, "String" -> StringRiffle[ links, "\n" ] |>;
webFetch[ url_, fmt_, result_String ] := shortenWebText @ niceWebText @ result;
webFetch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fetchWebText*)
fetchWebText // beginDefinition;

fetchWebText[ URL[ url_ ] ] :=
    fetchWebText @ url;

fetchWebText[ url_String ] :=
    fetchWebText[ url, $webSession ];

fetchWebText[ url_String, session_WebSessionObject ] := Enclose[
    Module[ { body, strings },
        ConfirmMatch[ WebExecute[ session, { "OpenPage" -> url } ], _Success | { __Success } ];
        Pause[ 3 ]; (* Allow time for the page to load *)
        body = ConfirmMatch[ WebExecute[ session, "LocateElements" -> "Tag" -> "body" ], { __WebElementObject } ];
        strings = ConfirmMatch[ WebExecute[ "ElementText" -> body ], { __String } ];
        shortenWebText @ niceWebText @ strings
    ],
    shortenWebText @ niceWebText @ Import[ url, { "HTML", "Plaintext" } ] &
];

fetchWebText[ url_String, _Missing | _? FailureQ ] :=
    shortenWebText @ niceWebText @ Import[ url, { "HTML", "Plaintext" } ];

fetchWebText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*shortenWebText*)
shortenWebText // beginDefinition;
shortenWebText[ text_String ] := shortenWebText[ text, toolOptionValue[ "WebFetcher", "MaxContentLength" ] ];
shortenWebText[ text_String, len_Integer? Positive ] := StringTake[ text, UpTo[ len ] ];
shortenWebText[ text_String, Infinity|All ] := text;
shortenWebText[ text_String, _ ] := shortenWebText[ text, $defaultWebTextLength ];
shortenWebText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*niceWebText*)
niceWebText // beginDefinition;
niceWebText[ str_String ] := StringReplace[ StringDelete[ str, "\r" ], Longest[ "\n"~~Whitespace~~"\n" ] :> "\n\n" ];
niceWebText[ strings_List ] := StringRiffle[ StringTrim[ niceWebText /@ strings ], "\n\n" ];
niceWebText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$webSession*)
$webSession := getWebSession[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getWebSession*)
getWebSession // beginDefinition;
getWebSession[ ] := getWebSession @ $currentWebSession;
getWebSession[ session_WebSessionObject? validWebSessionQ ] := session;
getWebSession[ session_WebSessionObject ] := (Quiet @ DeleteObject @ session; startWebSession[ ]);
getWebSession[ _ ] := startWebSession[ ];
getWebSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validWebSessionQ*)
validWebSessionQ // ClearAll;

validWebSessionQ[ session_WebSessionObject ] :=
    With[ { valid = Quiet @ StringQ @ WebExecute[ session, "PageURL" ] },
        If[ valid, True, Quiet @ DeleteObject @ session; False ]
    ];

validWebSessionQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*startWebSession*)
startWebSession // beginDefinition;

startWebSession[ ] := $currentWebSession =
    If[ TrueQ @ $CloudEvaluation,
        Missing[ "NotAvailable" ],
        StartWebSession[ Visible -> $webSessionVisible ]
    ];

startWebSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
