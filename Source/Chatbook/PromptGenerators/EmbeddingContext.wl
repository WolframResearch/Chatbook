(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`EmbeddingContext`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$smallContextMessageCount = 10;
$smallContextStringLength = 8000;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Convert Chat Messages to String*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSmallContextString*)
getSmallContextString // beginDefinition;

getSmallContextString // Options = { "IncludeSystemMessage" -> False };

getSmallContextString[ messages0: { ___Association }, opts: OptionsPattern[ ] ] := Enclose[
    Catch @ Module[ { messages, string },
        messages = Reverse @ Take[ Reverse @ messages0, UpTo[ $smallContextMessageCount ] ];
        If[ messages === { }, Throw[ "" ] ];
        string = ConfirmBy[ messagesToString[ messages, opts ], StringQ, "String" ];
        If[ StringLength @ string > $smallContextStringLength,
            StringTake[ string, { -$smallContextStringLength, -1 } ],
            string
        ]
    ],
    throwInternalFailure
];

getSmallContextString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
