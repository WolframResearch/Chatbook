(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Handlers`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `addHandlerArguments;
    `applyHandlerFunction;
    `getHandlerFunctions;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`FrontEnd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$handlerArguments = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Handler Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addHandlerArguments*)
addHandlerArguments // beginDefinition;
addHandlerArguments[ args_ ] := addHandlerArguments[ $handlerArguments, Association @ args ];
addHandlerArguments[ current_? AssociationQ, new_? AssociationQ ] := $handlerArguments = <| current, new |>;
addHandlerArguments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyHandlerFunction*)
applyHandlerFunction // beginDefinition;

applyHandlerFunction[ settings_, name_ ] := applyHandlerFunction[ settings, name, <| |> ];

applyHandlerFunction[ settings_Association, name_String, args0_ ] := Enclose[
    Module[ { args, handler },
        args = ConfirmBy[
            <|
                "EventName"            -> name,
                "ChatNotebookSettings" -> KeyDrop[ settings, { "Data", "OpenAIKey" } ],
                args0
            |>,
            AssociationQ,
            "HandlerArguments"
        ];
        $handlerArguments = ConfirmBy[ addHandlerArguments @ args, AssociationQ, "AddHandlerArguments" ];
        handler = Confirm[ getHandlerFunction[ settings, name ], "HandlerFunction" ];
        handler @ $handlerArguments
    ],
    throwInternalFailure[ applyHandlerFunction[ settings, name, args0 ], ## ] &
];

applyHandlerFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getHandlerFunction*)
getHandlerFunction // beginDefinition;

getHandlerFunction[ settings_Association, name_String ] :=
    getHandlerFunction[ settings, name, getHandlerFunctions @ settings ];

getHandlerFunction[ settings_, name_String, handlers_Association ] :=
    Replace[ Lookup[ handlers, name ],
             $$unspecified :> Lookup[ $DefaultChatHandlerFunctions, name, None ]
    ];

getHandlerFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getHandlerFunctions*)
getHandlerFunctions // beginDefinition;
getHandlerFunctions[ settings_Association ] := getHandlerFunctions[ settings, Lookup[ settings, "HandlerFunctions" ] ];
getHandlerFunctions[ _, handlers: KeyValuePattern[ "ResolvedHandlers" -> True ] ] := handlers;
getHandlerFunctions[ _, handlers_ ] := resolveHandlers @ handlers;
getHandlerFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveHandlers*)
resolveHandlers // beginDefinition;

resolveHandlers[ handlers: KeyValuePattern[ "ResolvedHandlers" -> True ] ] := handlers;

resolveHandlers[ handlers_Association ] := Enclose[
    AssociationMap[
        Apply @ Rule,
        <|
            ConfirmBy[ $DefaultChatHandlerFunctions, AssociationQ, "DefaultHandlers" ],
            ConfirmBy[ replaceCellContext @ handlers, AssociationQ, "Handlers" ],
            "ResolvedHandlers" -> True
        |>
    ],
    throwInternalFailure[ resolveHandlers @ handlers, ## ] &
];

resolveHandlers[ $$unspecified ] := resolveHandlers @ <| |>;

resolveHandlers[ handlers_ ] := (messagePrint[ "InvalidHandlers", handlers ]; resolveHandlers @ <| |>);

resolveHandlers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
