(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`InlineReferences`" ];

`insertPersonaInputBox;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`FrontEnd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*insertPersonaInputBox*)
insertPersonaInputBox // beginDefinition;

insertPersonaInputBox[ cell_CellObject ] := insertPersonaInputBox[ cell, parentNotebook @ cell ];

insertPersonaInputBox[ parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        uuid = CreateUUID[ ];
        cell = Cell[ BoxData @ ToBoxes @ personaInputBox @ uuid, "InlinePersonaChooser", Background -> None ];
        NotebookWrite[ nbo, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertPersonaInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*personaInputBox*)
(* FIXME: create TemplateBox and hook up an action name *)
personaInputBox // beginDefinition;

personaInputBox[ uuid_ ] := EventHandler[
    DynamicModule[ { string },
        Style[
            Framed[
                Grid[
                    {
                        {
                            "@",
                            InputField[
                                Dynamic[ string ],
                                String,
                                ContinuousAction        -> False,
                                FieldCompletionFunction -> personaCompletion,
                                FieldSize               -> { { 6, Infinity }, { 0, Infinity } },
                                BaseStyle               -> { "Text", FontColor -> Darker @ Blue },
                                Appearance              -> "Frameless",
                                ContentPadding          -> False,
                                FrameMargins            -> 0,
                                BoxID                   -> uuid
                            ]
                        }
                    },
                    Spacings  -> 0,
                    Alignment -> { Automatic, Center }
                ],
                RoundingRadius -> 4,
                FrameStyle     -> LightBlue,
                FrameMargins   -> { { 4, 3 }, { 3, 3 } },
                ContentPadding -> False
            ],
            "Text",
            FontColor            -> Darker @ Blue,
            ShowStringCharacters -> False
        ]
    ],
    {
        "ReturnKeyDown" :> writeStaticPersonaBox[ EvaluationCell[ ] ],
        "EscapeKeyDown" :> removePersonaBox @ EvaluationCell[ ]
    }
];

personaInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*personaCompletion*)
personaCompletion // beginDefinition;
personaCompletion[ "" ] := $personaNames;
personaCompletion[ string_String ] := Select[ $personaNames, StringStartsQ @ string ];
personaCompletion // endDefinition;

(* TODO: placeholder definition *)
$personaNames := { "Birdnardo", "Helper", "Wolfie", "ELI5", "Talk Like a Pirate", "Opposite Day" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeStaticPersonaBox*)
writeStaticPersonaBox // beginDefinition;

writeStaticPersonaBox[ cell_CellObject ] :=
    writeStaticPersonaBox[ cell, personaInputSetting @ NotebookRead @ cell ];

writeStaticPersonaBox[ cell_CellObject, name_String ] /; MemberQ[ $personaNames, name ] := (
    CurrentValue[ ParentCell @ cell, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = name;
    NotebookWrite[
        cell,
        Cell[
            BoxData @ ToBoxes @ staticPersonaBox @ name,
            "InlinePersonaReference",
            TaggingRules -> <| "PersonaName" -> name |>,
            Background   -> None,
            Editable     -> False,
            Selectable   -> False
        ]
    ];
);

writeStaticPersonaBox[ cell_CellObject, name_String ] :=
    NotebookWrite[ cell, TextData[ "@"<>name ], After ];

writeStaticPersonaBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*staticPersonaBox*)
(* FIXME: this can be a template box *)
staticPersonaBox // beginDefinition;

staticPersonaBox[ name_String ] := Style[
    Framed[
        Grid[ { { "@", name } }, Spacings -> 0, Alignment -> { Automatic, Baseline } ],
        Background     -> GrayLevel[ 0.95 ],
        RoundingRadius -> 4,
        FrameStyle     -> GrayLevel[ 0.85 ],
        FrameMargins   -> { { 4, 3 }, { 3, 3 } },
        ContentPadding -> False,
        BaseStyle      -> "Text"
    ],
    FontColor            -> GrayLevel[ 0.4 ],
    ShowStringCharacters -> False,
    Selectable           -> False
];

staticPersonaBox // endDefinition;

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
