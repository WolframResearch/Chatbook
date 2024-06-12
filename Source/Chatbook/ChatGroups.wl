(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatGroups`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`getChatGroupSettings;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`FrontEnd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$$supportedGroupingType = "TitleGrouping"|"SectionGrouping";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Group Settings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getChatGroupSettings*)
getChatGroupSettings // beginDefinition;
getChatGroupSettings[ cell_CellObject ] := <| "Prompt" -> getChatGroupPrompt @ cell |>;
getChatGroupSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Group Prompts*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getChatGroupPrompt*)
getChatGroupPrompt // beginDefinition;

getChatGroupPrompt[ cell_CellObject ] := Enclose[
    Catch @ Module[ { nbo, cells, cellsBefore, possibleGroupHeaders, $currentLevel, $bag, parents, prompts },

        nbo         = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];
        cells       = ConfirmMatch[ Cells @ nbo, { __CellObject }, "Cells" ];
        cellsBefore = Replace[ cells, { before___, cell, ___ } :> { before } ];

        If[ cellsBefore === { }, Throw @ Missing[ "NotAvailable" ] ];

        possibleGroupHeaders = Reverse @ DeleteCases[
            AssociationThread[ cellsBefore -> CurrentValue[ cellsBefore, CellGroupingRules ] ],
            Except[ { $$supportedGroupingType, _Integer } ]
        ];

        If[ possibleGroupHeaders === <| |>, Throw @ Missing[ "NotAvailable" ] ];

        $currentLevel = None;
        $bag          = Internal`Bag[ ];

        KeyValueMap[
            Function[
                { c, grouping },
                If[ cellGroupingOrder[ $currentLevel, grouping ] === 1,
                    $currentLevel = grouping;
                    Internal`StuffBag[ $bag, c ]
                ]
            ],
            possibleGroupHeaders
        ];

        parents = ConfirmMatch[ Reverse @ Internal`BagPart[ $bag, All ], { ___CellObject }, "Parents" ];

        If[ parents === { }, Throw @ Missing[ "NotAvailable" ] ];

        prompts = Select[
            CurrentValue[ parents, { TaggingRules, "ChatNotebookSettings", "ChatGroupSettings", "Prompt" } ],
            StringQ
        ];

        $lastChatGroupPrompt = If[ prompts === { }, Missing[ "NotAvailable" ], StringRiffle[ prompts, "\n\n" ] ]
    ],
    throwInternalFailure[ getChatGroupPrompt @ cell, ## ] &
];

getChatGroupPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellGroupingOrder*)
cellGroupingOrder // beginDefinition;
cellGroupingOrder[ KeyValuePattern[ "CellGroupingRules" -> a_ ], b_ ] := cellGroupingOrder[ a, b ];
cellGroupingOrder[ a_, KeyValuePattern[ "CellGroupingRules" -> b_ ] ] := cellGroupingOrder[ a, b ];
cellGroupingOrder[ { "SectionGrouping", _ }, { "TitleGrouping", _ } ] :=  1;
cellGroupingOrder[ { "TitleGrouping", _ }, { "SectionGrouping", _ } ] := -1;
cellGroupingOrder[ { type_, a_ }, { type_, b_ } ] := -Order[ a, b ];
cellGroupingOrder[ _String, { $$supportedGroupingType, _ } ] :=  1;
cellGroupingOrder[ { $$supportedGroupingType, _ }, _String ] := -1;
cellGroupingOrder[ None, _ ] :=  1;
cellGroupingOrder[ _, None ] := -1;
cellGroupingOrder[ _String, _String ] := 0;
cellGroupingOrder // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
