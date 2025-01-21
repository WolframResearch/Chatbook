(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Handlers`" ];
Begin[ "`Private`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$ChatHandlerData          = <| |>;
$handlerDroppedParameters = { "DefaultProcessingFunction" };
$settingsDroppedKeys      = { "Data", "OpenAIKey" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Handler Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addHandlerArguments*)
addHandlerArguments // beginDefinition;

addHandlerArguments[ args_ ] :=
    addHandlerArguments[ $ChatHandlerData, Association @ args ];

addHandlerArguments[ current_? AssociationQ, new_? AssociationQ ] /; AnyTrue[ new, AssociationQ ] := Enclose[
    $ChatHandlerData = ConfirmBy[ combineNestedHandlerData[ current, new ], AssociationQ, "AddHandlerArguments" ],
    throwInternalFailure
];

addHandlerArguments[ current_? AssociationQ, new_? AssociationQ ] :=
    $ChatHandlerData = <| current, new |>;

addHandlerArguments[ current_, new_? AssociationQ ] := (
    messagePrint[ "InvalidHandlerArguments", current ];
    $ChatHandlerData = new
);

addHandlerArguments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*combineNestedHandlerData*)
combineNestedHandlerData // beginDefinition;
combineNestedHandlerData[ as1_Association, as2_Association ] := combineNestedHandlerData0 @ { as1, as2 };
combineNestedHandlerData // endDefinition;

combineNestedHandlerData0 // beginDefinition;
combineNestedHandlerData0[ { as1_Association, as2_Association } ] := Merge[ { as1, as2 }, combineNestedHandlerData0 ];
combineNestedHandlerData0[ { value_ } ] := value;
combineNestedHandlerData0[ { _, value_ } ] := value;
combineNestedHandlerData0 // endDefinition;

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
                (* FIXME: Add settings at start of evaluation instead of each function call *)
                "ChatNotebookSettings" -> KeyDrop[ settings, $settingsDroppedKeys ],
                args0
            |>,
            AssociationQ,
            "HandlerArguments"
        ];
        $ChatHandlerData = ConfirmBy[ addHandlerArguments @ args, AssociationQ, "AddHandlerArguments" ];
        handler = Confirm[ getHandlerFunction[ settings, name ], "HandlerFunction" ];
        handler @ KeyDrop[ $ChatHandlerData, $handlerDroppedParameters ]
    ] // LogChatTiming[ name ],
    throwInternalFailure
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
    addProcessingArguments[ name, $ChatHandlerData, Association @ args ];

addProcessingArguments[ name_String, current_? AssociationQ, new_? AssociationQ ] :=
    $ChatHandlerData = <| current, new, "EventName" -> name |>;

addProcessingArguments[ name_String, current_, new_? AssociationQ ] := (
    messagePrint[ "InvalidHandlerArguments", current ];
    $ChatHandlerData = <| new, "EventName" -> name |>
);

addProcessingArguments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyProcessingFunction*)
applyProcessingFunction // beginDefinition;

applyProcessingFunction[ settings_, name_ ] :=
    applyProcessingFunction[ settings, name, HoldComplete[ ] ];

applyProcessingFunction[ settings_, name_, args_ ] :=
    applyProcessingFunction[ settings, name, args, <| |> ];

applyProcessingFunction[ settings_, name_, args_, params_ ] :=
    applyProcessingFunction[ settings, name, args, params, Automatic ];

applyProcessingFunction[ settings_Association, name_String, args_HoldComplete, params0_, default_ ] := Enclose[
    Module[ { params, function },
        params = ConfirmBy[ Association @ params0, AssociationQ, "ProcessingArguments" ];
        addProcessingArguments[
            name,
            <|
                (* FIXME: Add settings at start of evaluation instead of each function call *)
                "ChatNotebookSettings"      -> KeyDrop[ settings, $settingsDroppedKeys ],
                "DefaultProcessingFunction" -> default,
                params
            |>
        ];
        function = Confirm[ getProcessingFunction[ settings, name, default ], "ProcessingFunction" ];
        function @@ args
    ] // LogChatTiming[ name ],
    throwInternalFailure
];

applyProcessingFunction[ settings_, name_, args: Except[ _HoldComplete ], params_, default_ ] :=
    applyProcessingFunction[ settings, name, HoldComplete @ args, params, default ];

applyProcessingFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getProcessingFunction*)
getProcessingFunction // beginDefinition;

getProcessingFunction[ settings_Association, name_String ] :=
    getProcessingFunction[ settings, name, $DefaultChatProcessingFunctions[ name ] ];

getProcessingFunction[ settings_Association, name_String, default_ ] :=
    getProcessingFunction[ settings, name, default, getProcessingFunctions @ settings ];

getProcessingFunction[ settings_, name_String, a: $$unspecified, functions_Association ] :=
    Replace[ Lookup[ functions, name ],
             $$unspecified :> Lookup[
                $DefaultChatProcessingFunctions,
                name,
                throwInternalFailure @ getProcessingFunction[ settings, name, a, functions ]
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
addToMXInitialization[
    Null
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
