(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`InlineReferences`" ];

`insertPersonaInputBox;
`insertFunctionInputBox;
`insertModifierInputBox;
`insertTrailingFunctionInputBox;
`resolveLastInlineReference;
`resolveInlineReferences;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`FrontEnd`"         ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`PersonaInstaller`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$argumentDivider = "|";

$frameStyle     = Directive[ AbsoluteThickness[ 1 ], RGBColor[ "#a3c9f2" ] ];
$frameBaseStyle = { "InlineReferenceText", FontSize -> 0.95*Inherited };

$frameOptions = Sequence[
    RoundingRadius -> 2,
    FrameStyle     -> $frameStyle,
    FrameMargins   -> 2,
    ContentPadding -> False,
    BaseStyle      -> $frameBaseStyle
];

$lastInlineReferenceCell = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Resolve Inline References*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveInlineReferences*)
resolveInlineReferences // beginDefinition;

resolveInlineReferences[ _ ] /; CloudSystem`$CloudNotebooks := Null;

resolveInlineReferences[ cell_CellObject ] := (
    resolveLastInlineReference[ ];
    resolveInlineReferences[
        cell,
        Cells[ cell, CellStyle -> { "InlineModifierChooser", "InlineFunctionChooser", "InlinePersonaChooser" } ]
    ]
);

resolveInlineReferences[ _, { } ] := Null;

resolveInlineReferences[ cell_, cells: { ___CellObject } ] := resolveLastInlineReference /@ cells;

resolveInlineReferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveLastInlineReference*)
resolveLastInlineReference[ ] :=
    resolveLastInlineReference @ $lastInlineReferenceCell;

resolveLastInlineReference[ cell_CellObject ] :=
    resolveLastInlineReference[ cell, Developer`CellInformation @ cell ];

resolveLastInlineReference[ cell_CellObject, KeyValuePattern[ "Style" -> style_ ] ] :=
    resolveLastInlineReference[ cell, style ];

resolveLastInlineReference[ cell_CellObject, "InlineModifierChooser" ] := writeStaticModifierBox @ cell;
resolveLastInlineReference[ cell_CellObject, "InlineFunctionChooser" ] := writeStaticFunctionBox @ cell;
resolveLastInlineReference[ cell_CellObject, "InlinePersonaChooser"  ] := writeStaticPersonaBox @ cell;
resolveLastInlineReference[ ___ ] := Null;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Modifier Input*)
$modifierDataURL = "https://resources.wolframcloud.com/PromptRepository/category/modifier-prompts-data.json";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modifierCompletion*)
modifierCompletion // beginDefinition;
modifierCompletion[ "" ] := $modifierNames;
modifierCompletion[ string_String ] := Select[ $modifierNames, StringStartsQ[ string, IgnoreCase -> True ] ];
modifierCompletion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$modifierNames*)
$modifierNames := Select[
    DeleteDuplicates @ Flatten @ {
        CurrentValue @ { TaggingRules, "ChatNotebookSettings", "LLMEvaluator", "LLMEvaluatorName" },
        $availableModifierNames
    },
    StringQ
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$availableModifierNames*)
$availableModifierNames := Enclose[
    Module[ { modifierData, names },
        modifierData = ConfirmBy[ URLExecute[ $modifierDataURL, "RawJSON" ], AssociationQ, "ModifierData" ];
        names = Cases[
            modifierData[ "Resources" ],
            KeyValuePattern[ "Name" -> KeyValuePattern[ "Label" -> name_String ] ] :> name
        ];
        $availableModifierNames = ConfirmMatch[ Union @ names, { __? StringQ }, "Names" ]
    ],
    throwInternalFailure[ $availableModifierNames, ##1 ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*insertModifierInputBox*)
insertModifierInputBox // beginDefinition;

insertModifierInputBox[ cell_CellObject ] :=
    If[ MatchQ[
            Developer`CellInformation @ SelectedCells[ ],
            { KeyValuePattern @ { "Style" -> $$chatInputStyle } }
        ],
        insertModifierInputBox[ cell, parentNotebook @ cell ],
        NotebookWrite[ parentNotebook @ cell, "#" ]
    ];

insertModifierInputBox[ parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        resolveInlineReferences @ parent;
        uuid = CreateUUID[ ];
        cell = Cell[ BoxData @ ToBoxes @ modifierInputBox[ "", uuid ], "InlineModifierChooser", Background -> None ];
        NotebookWrite[ nbo, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertModifierInputBox[ args_List, cell_CellObject ] :=
    insertModifierInputBox[ args, cell, parentNotebook @ cell ];

insertModifierInputBox[ args_List, parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        resolveInlineReferences @ ParentCell @ parent;
        uuid = CreateUUID[ ];
        cell = Cell[ BoxData @ ToBoxes @ modifierInputBox[ args, uuid ], "InlineModifierChooser", Background -> None ];
        NotebookWrite[ parent, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertModifierInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modifierInputBox*)
modifierInputBox // beginDefinition;

modifierInputBox[ name_String, uuid_ ] := modifierInputBox[ { name }, uuid ];

modifierInputBox[ args_List, uuid_ ] :=
    DynamicModule[ { string = StringRiffle[ args, " "<>$argumentDivider<>" " ], cell },
        EventHandler[
            Style[
                Framed[
                    Grid[
                        {
                            {
                                "#",
                                InputField[
                                    Dynamic[
                                        string,
                                        Function[
                                            string = #;
                                            processModifierInput[ #, SelectedCells[ ], cell ]
                                        ]
                                    ],
                                    String,
                                    Alignment               -> { Left, Baseline },
                                    ContinuousAction        -> False,
                                    FieldCompletionFunction -> modifierCompletion,
                                    FieldSize               -> { { 15, Infinity }, Automatic },
                                    FieldHint               -> "PromptName",
                                    BaseStyle               -> $inputFieldStyle,
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
                    $frameOptions
                ],
                "Text",
                ShowStringCharacters -> False
            ],
            {
                { "KeyDown", "#" } :> NotebookWrite[ EvaluationNotebook[ ], "#" ],
                "EscapeKeyDown"    :> removeModifierInputBox @ cell,
                "ReturnKeyDown"    :> writeStaticModifierBox @ cell
            },
            PassEventsUp   -> False,
            PassEventsDown -> True
        ],
        Initialization :> (
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            $lastInlineReferenceCell = cell = EvaluationCell[ ];
        ),
        UnsavedVariables :> { cell }
    ];

modifierInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processModifierInput*)
processModifierInput // beginDefinition;

processModifierInput[ string_String, { cell_CellObject }, cell_CellObject ] := Null;

processModifierInput[ string_String, _List, cell_CellObject ] :=
    writeStaticModifierBox[ cell, functionInputSetting @ string ];

processModifierInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeStaticModifierBox*)
writeStaticModifierBox // beginDefinition;

writeStaticModifierBox[ cell_CellObject ] :=
    writeStaticModifierBox[ cell, functionInputSetting @ NotebookRead @ cell ];

writeStaticModifierBox[ cell_, $Failed ] := Null; (* box was already overwritten *)

writeStaticModifierBox[ cell_CellObject, { name_String? promptNameQ, args___ } ] /; ! TrueQ @ $removingBox :=
    Enclose[
        NotebookWrite[
            cell,
            Cell[
                BoxData @ ToBoxes @ staticModifierBox @ { name, args },
                "InlineModifierReference",
                TaggingRules -> <| "PromptModifierName" -> name, "PromptArguments" -> promptModifierArguments @ args |>,
                Background   -> None,
                Selectable   -> False
            ]
        ],
        throwInternalFailure[ writeStaticModifierBox[ cell, { name, args } ], ## ] &
    ];

writeStaticModifierBox[ cell_CellObject, args_List ] :=
    NotebookWrite[ cell, TextData[ "#" <> StringRiffle[ args, $argumentDivider ] ], After ];

writeStaticModifierBox // endDefinition;

promptModifierArguments[ args___ ] := Flatten @ { args };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeModifierInputBox*)
removeModifierInputBox // beginDefinition;
removeModifierInputBox[ cell_CellObject ] := Block[ { $removingBox = True }, writeStaticModifierBox @ cell ];
removeModifierInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*staticModifierBox*)
(* FIXME: this should _definitely_ be a template box *)
staticModifierBox // beginDefinition;

staticModifierBox[ args_List ] := Button[
    MouseAppearance[
        Mouseover[
            staticModifierBoxLabel[ args, RGBColor[ "#f1f8ff" ] ],
            staticModifierBoxLabel[ args, RGBColor[ "#ffffff" ] ]
        ],
        "LinkHand"
    ],
    insertModifierInputBox[ args, EvaluationCell[ ] ],
    ContentPadding -> False,
    FrameMargins   -> 0,
    Appearance     -> $suppressButtonAppearance
];

staticModifierBox // endDefinition;


staticModifierBoxLabel // beginDefinition;

staticModifierBoxLabel[ { name_, args___ }, background_ ] :=
    Style[
        Framed[
            Grid[
                {
                    Flatten @ {
                        Row @ { RawBoxes @ TemplateBox[ { }, "InlineReferenceIconHash" ], name },
                        styleFunctionArgument /@ { args }
                    }
                },
                Dividers   -> { { False, { True }, False }, False },
                FrameStyle -> RGBColor[ "#a3c9f2" ],
                Spacings   -> 0.5,
                Alignment  -> { Automatic, Baseline }
            ],
            Background -> background,
            $frameOptions
        ],
        ShowStringCharacters -> False,
        Selectable           -> False
    ];

staticModifierBoxLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Function Input*)
$functionDataURL = "https://resources.wolframcloud.com/PromptRepository/category/function-prompts-data.json";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*functionCompletion*)
functionCompletion // beginDefinition;
functionCompletion[ "" ] := $functionNames;
functionCompletion[ string_String ] := Select[ $functionNames, StringStartsQ[ string, IgnoreCase -> True ] ];
functionCompletion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$functionNames*)
$functionNames := Select[
    DeleteDuplicates @ Flatten @ {
        CurrentValue @ { TaggingRules, "ChatNotebookSettings", "LLMEvaluator", "LLMEvaluatorName" },
        $availableFunctionNames
    },
    StringQ
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$availableFunctionNames*)
$availableFunctionNames := Enclose[
    Module[ { functionData, names },
        functionData = ConfirmBy[ URLExecute[ $functionDataURL, "RawJSON" ], AssociationQ, "FunctionData" ];
        names = Cases[
            functionData[ "Resources" ],
            KeyValuePattern[ "Name" -> KeyValuePattern[ "Label" -> name_String ] ] :> name
        ];
        $availableFunctionNames = ConfirmMatch[ Union @ names, { __? StringQ }, "Names" ]
    ],
    throwInternalFailure[ $availableFunctionNames, ##1 ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*insertFunctionInputBox*)
insertFunctionInputBox // beginDefinition;

insertFunctionInputBox[ cell_CellObject ] :=
    If[ MatchQ[
            Developer`CellInformation @ SelectedCells[ ],
            { KeyValuePattern @ { "Style" -> $$chatInputStyle, "CursorPosition" -> { 0, _ } } }
        ],
        insertFunctionInputBox[ cell, parentNotebook @ cell ],
        NotebookWrite[ parentNotebook @ cell, "!" ]
    ];

insertFunctionInputBox[ parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        resolveInlineReferences @ parent;
        uuid = CreateUUID[ ];
        cell = Cell[ BoxData @ ToBoxes @ functionInputBox[ "", uuid ], "InlineFunctionChooser", Background -> None ];
        NotebookWrite[ nbo, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertFunctionInputBox[ args_List, cell_CellObject ] :=
    insertFunctionInputBox[ args, cell, parentNotebook @ cell ];

insertFunctionInputBox[ args_List, parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        resolveInlineReferences @ ParentCell @ parent;
        uuid = CreateUUID[ ];
        cell = Cell[ BoxData @ ToBoxes @ functionInputBox[ args, uuid ], "InlineFunctionChooser", Background -> None ];
        NotebookWrite[ parent, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertFunctionInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*functionInputBox*)
functionInputBox // beginDefinition;

functionInputBox[ name_String, uuid_ ] := functionInputBox[ { name }, uuid ];

(* TODO:
    * separate input boxes for arguments?
    * prefill argument hints based on resource metadata
*)
functionInputBox[ args_List, uuid_ ] :=
    DynamicModule[ { string = StringRiffle[ args, " "<>$argumentDivider<>" " ], cell },
        EventHandler[
            Style[
                Framed[
                    Grid[
                        {
                            {
                                "!",
                                InputField[
                                    Dynamic[
                                        string,
                                        Function[
                                            string = #;
                                            processFunctionInput[ #, SelectedCells[ ], cell ]
                                        ]
                                    ],
                                    String,
                                    Alignment               -> { Left, Baseline },
                                    ContinuousAction        -> False,
                                    FieldCompletionFunction -> functionCompletion,
                                    FieldSize               -> { { 15, Infinity }, Automatic },
                                    FieldHint               -> "PromptName",
                                    BaseStyle               -> $inputFieldStyle,
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
                    $frameOptions
                ],
                "Text",
                ShowStringCharacters -> False
            ],
            {
                { "KeyDown", "!" } :> NotebookWrite[ EvaluationNotebook[ ], "!" ],
                "EscapeKeyDown"    :> removeFunctionInputBox @ cell,
                "ReturnKeyDown"    :> writeStaticFunctionBox @ cell
            },
            PassEventsUp   -> False,
            PassEventsDown -> True
        ],
        Initialization :> (
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            $lastInlineReferenceCell = cell = EvaluationCell[ ];
        ),
        UnsavedVariables :> { cell }
    ];

functionInputBox // endDefinition;

$inputFieldStyle = {
    "Text",
    AutoOperatorRenderings -> { },
    PrivateFontOptions -> { "OperatorSubstitution" -> False }
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processFunctionInput*)
processFunctionInput // beginDefinition;

processFunctionInput[ string_String, { cell_CellObject }, cell_CellObject ] :=
    Null;

processFunctionInput[ string_String, _List, cell_CellObject ] :=
    writeStaticFunctionBox[ cell, functionInputSetting @ string ];

processFunctionInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeStaticFunctionBox*)
writeStaticFunctionBox // beginDefinition;

writeStaticFunctionBox[ cell_CellObject ] :=
    writeStaticFunctionBox[ cell, functionInputSetting @ NotebookRead @ cell ];

writeStaticFunctionBox[ cell_, $Failed ] := Null; (* box was already overwritten *)

writeStaticFunctionBox[ cell_CellObject, { name_String? promptNameQ, args___ } ] /; ! TrueQ @ $removingBox :=
    Enclose[
        NotebookWrite[
            cell,
            Cell[
                BoxData @ ToBoxes @ staticFunctionBox @ { name, args },
                "InlineFunctionReference",
                TaggingRules -> <| "PromptFunctionName" -> name, "PromptArguments" -> promptFunctionArguments @ args |>,
                Background   -> None,
                Selectable   -> False
            ]
        ],
        throwInternalFailure[ writeStaticFunctionBox[ cell, { name, args } ], ## ] &
    ];

writeStaticFunctionBox[ cell_CellObject, args_List ] :=
    NotebookWrite[ cell, TextData[ "!" <> StringRiffle[ args, $argumentDivider ] ], After ];

writeStaticFunctionBox // endDefinition;


promptFunctionArguments[ ] := { ">" };
promptFunctionArguments[ args___ ] := Flatten @ { args };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeFunctionInputBox*)
removeFunctionInputBox // beginDefinition;
removeFunctionInputBox[ cell_CellObject ] := Block[ { $removingBox = True }, writeStaticFunctionBox @ cell ];
removeFunctionInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*promptNameQ*)
promptNameQ[ id_String ] /; MemberQ[ $functionNames, id ] || MemberQ[ $modifierNames, id ] := True;
promptNameQ[ id_String? Internal`SymbolNameQ ] := If[ TrueQ @ promptNameQ0 @ id, promptNameQ[ id ] = True, False ];
promptNameQ[ ___ ] := False;

promptNameQ0[ name_String ] := Quiet @ Block[ { PrintTemporary },
    TrueQ @ Or[
        ResourceObject[ name ][ "ResourceType" ] === "Prompt",
        ResourceObject[ "Prompt: " <> name ][ "ResourceType" ] === "Prompt"
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*staticFunctionBox*)
(* FIXME: this should _definitely_ be a template box *)
staticFunctionBox // beginDefinition;

staticFunctionBox[ { name_String } ] := staticFunctionBox[ { name, ">" } ];

staticFunctionBox[ args_List ] := Button[
    MouseAppearance[
        Mouseover[
            staticFunctionBoxLabel[ args, RGBColor[ "#f1f8ff" ] ],
            staticFunctionBoxLabel[ args, RGBColor[ "#ffffff" ] ]
        ],
        "LinkHand"
    ],
    insertFunctionInputBox[ args, EvaluationCell[ ] ],
    ContentPadding -> False,
    FrameMargins   -> 0,
    Appearance     -> $suppressButtonAppearance
];

staticFunctionBox // endDefinition;

staticFunctionBoxLabel // beginDefinition;

(* staticFunctionBoxLabel[ { name_, args___ }, background_ ] := Style[
    Framed[
        Row @ Flatten @ {
            Riffle[
                Flatten @ {
                    Style[ name, "StandardForm", "Input" ],
                    styleFunctionArgument /@ { args }
                },
                Style[ "\[ThinSpace]:\[ThinSpace]", FontColor -> GrayLevel[ 0.6 ], FontWeight -> "DemiBold" ]
            ]
        },
        Background -> background,
        $frameOptions
    ],
    ShowStringCharacters -> False,
    Selectable           -> False
]; *)

staticFunctionBoxLabel[ { name_, args___ }, background_ ] :=
    Style[
        Framed[
            Grid[
                {
                    Flatten @ {
                        Style[ name, "StandardForm", "Input" ],
                        styleFunctionArgument /@ { args }
                    }
                },
                Dividers   -> { { False, { True }, False }, False },
                FrameStyle -> RGBColor[ "#a3c9f2" ],
                Spacings   -> 0.5,
                Alignment  -> { Automatic, Baseline }
            ],
            Background -> background,
            $frameOptions
        ],
        ShowStringCharacters -> False,
        Selectable           -> False
    ];

staticFunctionBoxLabel // endDefinition;


styleFunctionArgument // beginDefinition;

styleFunctionArgument[ ">" ] := RawBoxes @ TemplateBox[ { }, "InlineReferenceIconRight" ];
styleFunctionArgument[ "^" ] := RawBoxes @ TemplateBox[ { }, "InlineReferenceIconPrevious" ];
styleFunctionArgument[ "^^" ] := RawBoxes @ TemplateBox[ { }, "InlineReferenceIconHistory" ];

styleFunctionArgument[ $argumentDivider ] :=
    Style[ " " <> $argumentDivider <> " ", FontColor -> GrayLevel[ 0.6 ], FontWeight -> "DemiBold" ];

styleFunctionArgument[ argument_ ] := Style[ argument, FontSize -> 0.9*Inherited ];

styleFunctionArgument // endDefinition;

specArg[ expr_, opts___ ] := Style[ expr, opts, FontWeight -> Bold, FontColor -> Gray ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*insertTrailingFunctionInputBox*)
insertTrailingFunctionInputBox // beginDefinition;

insertTrailingFunctionInputBox[ cell_CellObject ] :=
    If[ MatchQ[ Developer`CellInformation @ SelectedCells[ ], { KeyValuePattern[ "Style" -> $$chatInputStyle ] } ],
        insertTrailingFunctionInputBox[ cell, parentNotebook @ cell ]
    ];

insertTrailingFunctionInputBox[ parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        resolveInlineReferences @ parent;
        uuid = CreateUUID[ ];
        cell = Cell[
            BoxData @ ToBoxes @ trailingFunctionInputBox[ "", uuid ],
            "InlineTrailingFunctionChooser",
            Background -> None
        ];
        NotebookWrite[ nbo, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertTrailingFunctionInputBox[ args_List, cell_CellObject ] :=
    insertTrailingFunctionInputBox[ args, cell, parentNotebook @ cell ];

insertTrailingFunctionInputBox[ args_List, parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        resolveInlineReferences @ ParentCell @ parent;
        uuid = CreateUUID[ ];
        cell = Cell[
            BoxData @ ToBoxes @ trailingFunctionInputBox[ args, uuid ],
            "InlineTrailingFunctionChooser",
            Background -> None
        ];
        NotebookWrite[ parent, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertTrailingFunctionInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*trailingFunctionInputBox*)
trailingFunctionInputBox // beginDefinition;

trailingFunctionInputBox[ name_String, uuid_ ] := trailingFunctionInputBox[ { name }, uuid ];

(* TODO:
    * separate input boxes for arguments?
    * prefill argument hints based on resource metadata
*)
trailingFunctionInputBox[ args_List, uuid_ ] := DynamicModule[ { string = StringRiffle[ args, $argumentDivider ], cell },
    EventHandler[
        Style[
            Framed[
                Grid[
                    {
                        {
                            InputField[
                                Dynamic[
                                    string,
                                    Function[
                                        string = StringDelete[ #, StartOfString~~">" ]
                                    ]
                                ],
                                String,
                                ContinuousAction        -> False,
                                FieldCompletionFunction -> functionCompletion,
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
                $frameOptions
            ],
            "Text",
            ShowStringCharacters -> False
        ],
        {
            { "KeyDown", ">" } :> NotebookWrite[ EvaluationNotebook[ ], ">" ],
            "ReturnKeyDown"    :> If[ string =!= "", writeStaticTrailingFunctionBox @ cell ],
            "TabKeyDown"       :> writeStaticTrailingFunctionBox @ cell
        },
        PassEventsUp -> False
    ],
    Initialization   :> { cell = EvaluationCell[ ], Quiet @ Needs[ "Wolfram`Chatbook`" -> None ] },
    UnsavedVariables :> { cell }
];

trailingFunctionInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeStaticTrailingFunctionBox*)
writeStaticTrailingFunctionBox // beginDefinition;

writeStaticTrailingFunctionBox[ cell_CellObject ] :=
    writeStaticTrailingFunctionBox[ cell, functionInputSetting @ NotebookRead @ cell ];

writeStaticTrailingFunctionBox[ cell_, $Failed ] := Null; (* box was already overwritten *)

writeStaticTrailingFunctionBox[ cell_CellObject, { name_String, args___ } ] /; MemberQ[ $functionNames, name ] :=
    Enclose[
        NotebookWrite[
            cell,
            Cell[
                BoxData @ ToBoxes @ staticTrailingFunctionBox @ { name, args },
                "InlinePersonaReference",
                TaggingRules -> <| "PromptFunctionName" -> name, "PromptArguments" -> promptFunctionArguments @ args |>,
                Background   -> None,
                Selectable   -> False
            ]
        ],
        throwInternalFailure[ writeStaticTrailingFunctionBox[ cell, { name, args } ], ## ] &
    ];

writeStaticTrailingFunctionBox[ cell_CellObject, args_List ] :=
    NotebookWrite[ cell, TextData[ ">" <> StringRiffle[ args, $argumentDivider ] ], After ];

writeStaticTrailingFunctionBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*staticTrailingFunctionBox*)

(* FIXME: this should _definitely_ be a template box *)
staticTrailingFunctionBox // beginDefinition;

staticTrailingFunctionBox[ args_List ] := Button[
    MouseAppearance[
        Mouseover[
            staticTrailingFunctionBoxLabel[ args, RGBColor[ "#f1f8ff" ] ],
            staticTrailingFunctionBoxLabel[ args, RGBColor[ "#ffffff" ] ]
        ],
        "LinkHand"
    ],
    insertTrailingFunctionInputBox[ args, EvaluationCell[ ] ],
    ContentPadding -> False,
    FrameMargins   -> 0,
    Appearance     -> $suppressButtonAppearance
];

staticTrailingFunctionBox // endDefinition;

staticTrailingFunctionBoxLabel // beginDefinition;

staticTrailingFunctionBoxLabel[ { name_, args___ }, background_ ] := Style[
    Framed[
        Row @ Flatten @ {
            Style[ "> ", FontColor -> GrayLevel[ 0.6 ], FontWeight -> Bold ],
            Riffle[
                Flatten @ {
                    Style[ name, "StandardForm", "Input" ],
                    Style[ #, FontSize -> 0.9 * Inherited ] & /@ { args }
                },
                Style[ "\[ThinSpace]:\[ThinSpace]", FontColor -> GrayLevel[ 0.6 ], FontWeight -> "DemiBold" ]
            ]
        },
        Background -> background,
        $frameOptions
    ],
    ShowStringCharacters -> False,
    Selectable           -> False
];

staticTrailingFunctionBoxLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*functionInputSetting*)
functionInputSetting // beginDefinition;
functionInputSetting[ cell_CellObject ] := functionInputSetting @ NotebookRead @ cell;
functionInputSetting[ (Cell|BoxData|TagBox)[ boxes_, ___ ] ] := functionInputSetting @ boxes;
functionInputSetting[ DynamicModuleBox[ { ___, _ = string_String, ___ }, ___ ] ] := functionInputSetting @ string;

functionInputSetting[ string_String ] :=
    DeleteCases[ StringTrim @ StringSplit[ StringTrim @ string, $functionArgSplitRules ], "" ];

functionInputSetting[ ___ ] := $Failed;
functionInputSetting // endDefinition;

$functionArgSplitRules = {
    $argumentDivider,
    "^^" :> "^^",
    "^"  :> "^",
    ">"  :> ">"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Persona Input*)
$personaDataURL = "https://resources.wolframcloud.com/PromptRepository/category/personas-data.json";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*personaCompletion*)
personaCompletion // beginDefinition;
personaCompletion[ "" ] := $personaNames;
personaCompletion[ string_String ] := Select[ $personaNames, StringStartsQ[ string, IgnoreCase -> True ] ];
personaCompletion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$personaNames*)
$personaNames := Select[
    DeleteDuplicates @ Flatten @ { Keys @ GetCachedPersonaData[ ], $availablePersonaNames },
    StringQ
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$availablePersonaNames*)
$availablePersonaNames := Enclose[
    Module[ { personaData, names },
        personaData = ConfirmBy[ URLExecute[ $personaDataURL, "RawJSON" ], AssociationQ, "PersonaData" ];
        names = Cases[
            personaData[ "Resources" ],
            KeyValuePattern[ "Name" -> KeyValuePattern[ "Label" -> name_String ] ] :> name
        ];
        $availablePersonaNames = ConfirmMatch[ Union @ names, { __? StringQ }, "Names" ]
    ],
    throwInternalFailure[ $availablePersonaNames, ##1 ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*insertPersonaInputBox*)
insertPersonaInputBox // beginDefinition;

insertPersonaInputBox[ cell_CellObject ] := insertPersonaInputBox[ cell, parentNotebook @ cell ];

insertPersonaInputBox[ parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        resolveInlineReferences @ parent;
        uuid = CreateUUID[ ];
        cell = Cell[ BoxData @ ToBoxes @ personaInputBox[ "", uuid ], "InlinePersonaChooser", Background -> None ];
        NotebookWrite[ nbo, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertPersonaInputBox[ name_String, cell_CellObject ] := insertPersonaInputBox[ name, cell, parentNotebook @ cell ];

insertPersonaInputBox[ name_String, parent_CellObject, nbo_NotebookObject ] :=
    Module[ { uuid, cell },
        resolveInlineReferences @ ParentCell @ parent;
        uuid = CreateUUID[ ];
        cell = Cell[ BoxData @ ToBoxes @ personaInputBox[ name, uuid ], "InlinePersonaChooser", Background -> None ];
        NotebookWrite[ parent, cell ];
        FrontEnd`MoveCursorToInputField[ nbo, uuid ]
    ];

insertPersonaInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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
                                Dynamic @ string,
                                String,
                                Alignment               -> { Left, Baseline },
                                ContinuousAction        -> True,
                                FieldCompletionFunction -> personaCompletion,
                                FieldSize               -> { { 15, Infinity }, Automatic },
                                BaseStyle               -> $inputFieldStyle,
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
                $frameOptions
            ],
            "Text",
            ShowStringCharacters -> False
        ],
        {
            "EscapeKeyDown" :> removePersonaInputBox @ cell,
            "ReturnKeyDown" :> writeStaticPersonaBox @ cell
        }
    ],
    Initialization :> (
        Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
        $lastInlineReferenceCell = cell = EvaluationCell[ ];
    ),
    UnsavedVariables :> { cell }
];

personaInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processPersonaInput*)
processPersonaInput // beginDefinition;

processPersonaInput[ string_String, { cell_CellObject }, cell_CellObject ] := Null;

processPersonaInput[ string_String, _List, cell_CellObject ] :=
    writeStaticPersonaBox[ cell, personaInputSetting @ string ];

processPersonaInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeStaticPersonaBox*)
writeStaticPersonaBox // beginDefinition;

writeStaticPersonaBox[ cell_CellObject ] :=
    writeStaticPersonaBox[ cell, personaInputSetting @ NotebookRead @ cell ];

writeStaticPersonaBox[ cell_, $Failed ] := Null; (* box was already overwritten *)

writeStaticPersonaBox[ cell_CellObject, name_String ] /; $removingBox :=
    NotebookWrite[ cell, TextData[ "@" <> name ], After ];

(* TODO: Should this also insert a space after? It might not be desirable if you wanted to follow with punctuation, e.g.
    "Hey [@Birdnardo], do something cool!"
*)
writeStaticPersonaBox[ cell_CellObject, name_String ] /; MemberQ[ $personaNames, name ] := Enclose[
    If[ ! MemberQ[ Keys @ GetCachedPersonaData[ ], name ],
        ConfirmBy[ PersonaInstall[ "Prompt: "<>name ], FileExistsQ, "PersonaInstall" ];
        ConfirmAssert[ MemberQ[ Keys @ GetCachedPersonaData[ ], name ], "GetCachedPersonaData" ]
    ];

    NotebookWrite[
        cell,
        Cell[
            BoxData @ ToBoxes @ staticPersonaBox @ name,
            "InlinePersonaReference",
            TaggingRules -> <| "PersonaName" -> name |>,
            Background -> None,
            Selectable -> False,
            Initialization :> With[ { parent = ParentCell @ EvaluationCell[ ] },
                CurrentValue[ parent, CellDingbat ] = Inherited;
                CurrentValue[ parent, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = name;
            ]
        ]
    ]
    ,
    throwInternalFailure[ writeStaticPersonaBox[ cell, name ], ## ] &
];

writeStaticPersonaBox[ cell_CellObject, name_String ] :=
    NotebookWrite[ cell, TextData[ "@"<>name ], After ];

writeStaticPersonaBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removePersonaInputBox*)
removePersonaInputBox // beginDefinition;
removePersonaInputBox[ cell_CellObject ] := Block[ { $removingBox = True }, writeStaticPersonaBox @ cell ];
removePersonaInputBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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
        Row @ { RawBoxes @ TemplateBox[ { }, "InlineReferenceIconAt" ], name },
        Background -> background,
        $frameOptions
    ],
    ShowStringCharacters -> False,
    Selectable           -> False
];

staticPersonaBoxLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*personaInputSetting*)
personaInputSetting // beginDefinition;
personaInputSetting[ string_String ] := string;
personaInputSetting[ cell_CellObject ] := personaInputSetting @ NotebookRead @ cell;
personaInputSetting[ (Cell|BoxData|TagBox)[ boxes_, ___ ] ] := personaInputSetting @ boxes;
personaInputSetting[ DynamicModuleBox[ { ___, _ = string_String, ___ }, ___ ] ] := string;
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
