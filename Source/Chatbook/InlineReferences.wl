(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`InlineReferences`" ];

`insertPersonaInputBox;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`FrontEnd`"         ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`PersonaInstaller`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$personaDataURL = "https://resources.wolframcloud.com/PromptRepository/prompttype/personas-data.json";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*personaCompletion*)
personaCompletion // beginDefinition;
personaCompletion[ "" ] := $personaNames;
personaCompletion[ string_String ] := Select[ $personaNames, StringStartsQ[ string, IgnoreCase -> True ] ];
personaCompletion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$personaNames*)
$personaNames := DeleteDuplicates @ Join[ Keys @ GetCachedPersonaData[ ], $availablePersonaNames ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$availablePersonaNames*)
$availablePersonaNames := Enclose[
    Module[ { personaData, names },
        personaData = ConfirmBy[ URLExecute[ $personaDataURL, "RawJSON" ], AssociationQ, "PersonaData" ];
        names = Cases[
            personaData[ "Resources" ],
            KeyValuePattern[ "Name" -> KeyValuePattern[ "Label" -> name_String ] ] :> name
        ];
        $availablePersonaNames = ConfirmMatch[ names, { __? StringQ }, "Names" ]
    ],
    throwInternalFailure[ $availablePersonaNames, ##1 ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*insertPersonaInputBox*)
insertPersonaInputBox // beginDefinition;

insertPersonaInputBox[ cell_CellObject ] := insertPersonaInputBox[ cell, parentNotebook @ cell ];

insertPersonaInputBox[ parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        uuid = CreateUUID[ ];
        cell = Cell[ BoxData @ ToBoxes @ personaInputBox[ "", uuid ], "InlinePersonaChooser", Background -> None ];
        NotebookWrite[ nbo, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertPersonaInputBox[ name_String, cell_CellObject ] := insertPersonaInputBox[ name, cell, parentNotebook @ cell ];

insertPersonaInputBox[ name_String, parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        uuid = CreateUUID[ ];
        cell = Cell[ BoxData @ ToBoxes @ personaInputBox[ name, uuid ], "InlinePersonaChooser", Background -> None ];
        NotebookWrite[ parent, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertPersonaInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*personaInputBox*)
personaInputBox // beginDefinition;

personaInputBox[ name_String, uuid_ ] := DynamicModule[ { string = name, cell },
    EventHandler[
        Style[
            Framed[
                Grid[
                    {
                        {
                            "@",
                            InputField[
                                Dynamic[ string, writeStaticPersonaBox[ cell, string = # ] & ],
                                String,
                                ContinuousAction        -> False,
                                FieldCompletionFunction -> personaCompletion,
                                FieldSize               -> { { 15, Infinity }, { 0, Infinity } },
                                BaseStyle               -> { "Text" },
                                Appearance              -> "Frameless",
                                ContentPadding          -> False,
                                FrameMargins            -> 0,
                                BoxID                   -> uuid
                            ]
                        }
                    },
                    Spacings  -> 0,
                    Alignment -> { Automatic, Baseline }
                ],
                RoundingRadius -> 4,
                FrameStyle     -> RGBColor[ "#a3c9f2" ],
                FrameMargins   -> { { 4, 3 }, { 3, 3 } },
                ContentPadding -> False
            ],
            "Text",
            ShowStringCharacters -> False
        ],
        {
            "ReturnKeyDown" :> moveAndWriteStaticPersonaBox @ cell,
            "TabKeyDown"    :> moveAndWriteStaticPersonaBox @ cell(*,
            "EscapeKeyDown" :> Block[ { $personaNames = { } }, moveAndWriteStaticPersonaBox @ cell ]*)
        }
    ],
    Initialization   :> { cell = EvaluationCell[ ], Quiet @ Needs[ "Wolfram`Chatbook`" -> None ] },
    UnsavedVariables :> { cell }
];

personaInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*moveAndWriteStaticPersonaBox*)
moveAndWriteStaticPersonaBox // beginDefinition;
moveAndWriteStaticPersonaBox[ cell_CellObject ] := (SelectionMove[ cell, All, Cell ]; writeStaticPersonaBox @ cell);
moveAndWriteStaticPersonaBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeStaticPersonaBox*)
writeStaticPersonaBox // beginDefinition;

writeStaticPersonaBox[ cell_CellObject ] :=
    writeStaticPersonaBox[ cell, personaInputSetting @ NotebookRead @ cell ];

writeStaticPersonaBox[ cell_, $Failed ] := Null; (* box was already overwritten *)

(* TODO: Should this also insert a space after? It might not be desirable if you wanted to follow with punctuation, e.g.
    "Hey [@Birdnardo], do something cool!"
*)
writeStaticPersonaBox[ cell_CellObject, name_String ] /; MemberQ[ $personaNames, name ] := Enclose[
    If[ ! MemberQ[ Keys @ GetCachedPersonaData[ ], name ],
        ConfirmBy[ PersonaInstall @ name, FileExistsQ, "PersonaInstall" ];
        ConfirmAssert[ MemberQ[ Keys @ GetCachedPersonaData[ ], name ], "GetCachedPersonaData" ]
    ];
    CurrentValue[ ParentCell @ cell, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = name;
    NotebookWrite[
        cell,
        Cell[
            BoxData @ ToBoxes @ staticPersonaBox @ name,
            "InlinePersonaReference",
            TaggingRules -> <| "PersonaName" -> name |>,
            Background -> None,
            Selectable -> False
        ]
    ],
    throwInternalFailure[ writeStaticPersonaBox[ cell, name ], ## ] &
];

writeStaticPersonaBox[ cell_CellObject, name_String ] :=
    NotebookWrite[ cell, TextData[ "@"<>name ], After ];

writeStaticPersonaBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removePersonaBox*)
removePersonaBox // beginDefinition;
removePersonaBox[ cell_CellObject ] := removePersonaBox[ cell, personaInputSetting @ NotebookRead @ cell ];
removePersonaBox[ cell_CellObject, text_String ] := NotebookWrite[ cell, TextData[ "@"<>text ], After ];
removePersonaBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*staticPersonaBox*)
(* FIXME: this can be a template box *)
staticPersonaBox // beginDefinition;
staticPersonaBox[ name_String ] := Button[
    MouseAppearance[
        Mouseover[
            staticPersonaBoxLabel[ name, RGBColor[ "#f1f8ff" ] ],
            staticPersonaBoxLabel[ name, RGBColor[ "#ffffff" ] ]
        ],
        "LinkHand"
    ],
    insertPersonaInputBox[ name, EvaluationCell[ ] ],
    ContentPadding -> False,
    FrameMargins   -> 0,
    Appearance     -> $suppressButtonAppearance
];

staticPersonaBox // endDefinition;


staticPersonaBoxLabel // beginDefinition;

staticPersonaBoxLabel[ name_String, background_ ] := Style[
    Framed[
        "@" <> name,
        Background     -> background,
        RoundingRadius -> 4,
        FrameStyle     -> RGBColor[ "#a3c9f2" ],
        FrameMargins   -> { { 4, 3 }, { 3, 3 } },
        ContentPadding -> False,
        BaseStyle      -> "Text"
    ],
    ShowStringCharacters -> False,
    Selectable           -> False
];

staticPersonaBoxLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*personaInputSetting*)
personaInputSetting // beginDefinition;
personaInputSetting[ cell_CellObject ] := personaInputSetting @ NotebookRead @ cell;
personaInputSetting[ (Cell|BoxData|TagBox)[ boxes_, ___ ] ] := personaInputSetting @ boxes;
personaInputSetting[ DynamicModuleBox[ { _ = string_String }, ___ ] ] := string;
personaInputSetting[ ___ ] := $Failed;
personaInputSetting // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    Null
];

End[ ];
EndPackage[ ];
