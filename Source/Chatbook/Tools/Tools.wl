(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

HoldComplete[
    `$attachments;
    `$defaultChatTools;
    `$toolConfiguration;
    `$toolEvaluationResults;
    `$toolOptions;
    `$toolResultStringLength;
    `getToolByName;
    `getToolDisplayName;
    `getToolFormattingFunction;
    `getToolIcon;
    `initTools;
    `makeExpressionURI;
    `makeToolConfiguration;
    `makeToolResponseString;
    `resolveTools;
    `toolData;
    `toolName;
    `toolOptionValue;
    `toolRequestParser;
    `withToolBox;
];

Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Subcontexts*)
Get[ "Wolfram`Chatbook`Tools`Common`"          ];
Get[ "Wolfram`Chatbook`Tools`ToolOptions`"     ];
Get[ "Wolfram`Chatbook`Tools`DefaultTools`"    ];
Get[ "Wolfram`Chatbook`Tools`ChatPreferences`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
