(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Handlers`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `addHandlerArguments;
    `addProcessingArguments;
    `applyHandlerFunction;
    `applyProcessingFunction;
    `getHandlerFunctions;
    `getProcessingFunctions;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`FrontEnd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$ChatHandlerArguments = <| |>;

$handlerDroppedParameters = { "DefaultProcessingFunction" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Handler Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addHandlerArguments*)
addHandlerArguments // beginDefinition;

addHandlerArguments[ args_ ] :=
    addHandlerArguments[ $ChatHandlerArguments, Association @ args ];

addHandlerArguments[ current_? AssociationQ, new_? AssociationQ ] :=
    $ChatHandlerArguments = <| current, new |>;

addHandlerArguments[ current_, new_? AssociationQ ] := (
    messagePrint[ "InvalidHandlerArguments", current ];
    $ChatHandlerArguments = new
);

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
        $ChatHandlerArguments = ConfirmBy[ addHandlerArguments @ args, AssociationQ, "AddHandlerArguments" ];
        handler = Confirm[ getHandlerFunction[ settings, name ], "HandlerFunction" ];
        handler @ KeyDrop[ $ChatHandlerArguments, $handlerDroppedParameters ]
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
getHandlerFunctions[ _, handlers: KeyValuePattern[ "Resolved" -> True ] ] := handlers;
getHandlerFunctions[ _, handlers_ ] := resolveHandlers @ handlers;
getHandlerFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveHandlers*)
resolveHandlers // beginDefinition;

resolveHandlers[ handlers: KeyValuePattern[ "Resolved" -> True ] ] := handlers;

resolveHandlers[ handlers_Association ] := Enclose[
    AssociationMap[
        Apply @ Rule,
        <|
            ConfirmBy[ $DefaultChatHandlerFunctions, AssociationQ, "DefaultHandlers" ],
            ConfirmBy[ replaceCellContext @ handlers, AssociationQ, "Handlers" ],
            "Resolved" -> True
        |>
    ],
    throwInternalFailure[ resolveHandlers @ handlers, ## ] &
];

resolveHandlers[ $$unspecified ] := resolveHandlers @ <| |>;

resolveHandlers[ handlers_ ] := (messagePrint[ "InvalidHandlers", handlers ]; resolveHandlers @ <| |>);

resolveHandlers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Processing Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addProcessingArguments*)
addProcessingArguments // beginDefinition;

addProcessingArguments[ args_ ] :=
    With[ { as = Association @ args },
        addProcessingArguments[ Lookup[ as, "EventName" ], as ]
    ];

addProcessingArguments[ name_String, args_ ] :=
    addProcessingArguments[ name, $ChatHandlerArguments, Association @ args ];

addProcessingArguments[ name_String, current_? AssociationQ, new_? AssociationQ ] :=
    $ChatHandlerArguments = <| current, new, "EventName" -> name |>;

addProcessingArguments[ name_String, current_, new_? AssociationQ ] := (
    messagePrint[ "InvalidHandlerArguments", current ];
    $ChatHandlerArguments = <| new, "EventName" -> name |>
);

addProcessingArguments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyProcessingFunction*)
applyProcessingFunction // beginDefinition;

applyProcessingFunction[ settings_Association, name_String, args_HoldComplete ] :=
    applyProcessingFunction[ settings, name, args, Automatic ];

applyProcessingFunction[ settings_Association, name_String, args_HoldComplete, default_ ] := Enclose[
    Module[ { function },
        addHandlerArguments @ <|
            "EventName"                 -> name,
            "ChatNotebookSettings"      -> KeyDrop[ settings, { "Data", "OpenAIKey" } ],
            "DefaultProcessingFunction" -> default
        |>;
        function = Confirm[ getProcessingFunction[ settings, name, default ], "ProcessingFunction" ];
        function @@ args
    ],
    throwInternalFailure[ applyProcessingFunction[ settings, name, args, default ], ## ] &
];

applyProcessingFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getProcessingFunction*)
getProcessingFunction // beginDefinition;

getProcessingFunction[ settings_Association, name_String, default_ ] :=
    getProcessingFunction[ settings, name, default, getProcessingFunctions @ settings ];

getProcessingFunction[ settings_, name_String, a: $$unspecified, handlers_Association ] :=
    Replace[ Lookup[ handlers, name ],
             $$unspecified :> Lookup[
                $DefaultChatProcessingFunctions,
                name,
                throwInternalFailure @ getProcessingFunction[ settings, name, a, handlers ]
            ]
    ];

getProcessingFunction[ settings_, name_String, default_, handlers_Association ] :=
    Replace[ Lookup[ handlers, name ], $$unspecified :> default ];

getProcessingFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getProcessingFunctions*)
getProcessingFunctions // beginDefinition;
getProcessingFunctions[ as_Association ] := getProcessingFunctions[ as, Lookup[ as, "ProcessingFunctions" ] ];
getProcessingFunctions[ _, functions: KeyValuePattern[ "Resolved" -> True ] ] := functions;
getProcessingFunctions[ _, functions_ ] := resolveFunctions @ functions;
getProcessingFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveFunctions*)
resolveFunctions // beginDefinition;

resolveFunctions[ functions: KeyValuePattern[ "Resolved" -> True ] ] := functions;

resolveFunctions[ functions_Association ] := Enclose[
    AssociationMap[
        Apply @ Rule,
        <|
            ConfirmBy[ $DefaultChatProcessingFunctions, AssociationQ, "DefaultFunctions" ],
            ConfirmBy[ replaceCellContext @ functions, AssociationQ, "Functions" ],
            "Resolved" -> True
        |>
    ],
    throwInternalFailure[ resolveFunctions @ functions, ## ] &
];

resolveFunctions[ $$unspecified ] := resolveFunctions @ <| |>;

resolveFunctions[ functions_ ] := (messagePrint[ "InvalidFunctions", functions ]; resolveFunctions @ <| |>);

resolveFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
