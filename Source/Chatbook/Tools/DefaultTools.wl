(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Tools*)
(* Uncomment the following when the ChatPreferences tool is ready: *)
(* Get[ "Wolfram`Chatbook`Tools`DefaultToolDefinitions`ChatPreferences`" ]; *)
Get[ "Wolfram`Chatbook`Tools`DefaultToolDefinitions`DocumentationLookup`"      ];
Get[ "Wolfram`Chatbook`Tools`DefaultToolDefinitions`DocumentationSearcher`"    ];
Get[ "Wolfram`Chatbook`Tools`DefaultToolDefinitions`NotebookEditor`"           ];
Get[ "Wolfram`Chatbook`Tools`DefaultToolDefinitions`WebFetcher`"               ];
Get[ "Wolfram`Chatbook`Tools`DefaultToolDefinitions`WebImageSearcher`"         ];
Get[ "Wolfram`Chatbook`Tools`DefaultToolDefinitions`WebSearcher`"              ];
Get[ "Wolfram`Chatbook`Tools`DefaultToolDefinitions`WolframAlpha`"             ];
Get[ "Wolfram`Chatbook`Tools`DefaultToolDefinitions`WolframLanguageEvaluator`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)

(* Sort tools to their default ordering: *)
$defaultChatTools0 = Block[ { LLMTool },
    Map[
        LLMTool[ #, { } ] &,
        <| KeyTake[ $defaultChatTools0, $defaultToolOrder ], $defaultChatTools0 |>
    ]
];

End[ ];
EndPackage[ ];
