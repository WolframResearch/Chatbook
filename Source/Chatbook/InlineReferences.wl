(* ::Package:: *)

(* ::Section::Closed:: *)
(*Package Header*)

(* TODO: Figure out how to show autocomplete menu when field is empty *)

BeginPackage[ "Wolfram`Chatbook`InlineReferences`" ];

(* These symbols are hardcoded into the stylesheet and need to remain in this context: *)
`functionTemplateBoxes;
`modifierTemplateBoxes;
`personaTemplateBoxes;
`wlTemplateBoxes;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];



(* ::Section::Closed:: *)
(*Config*)


$argumentDivider = "|";

$frameStyle     = Directive[ AbsoluteThickness[ 1 ], RGBColor[ "#a3c9f2" ] ];
$frameBaseStyle = { "NotebookAssistant`InlineReferenceText", FontSize -> 0.95*Inherited };

$frameOptions = Sequence[
    RoundingRadius -> 2,
    FrameStyle     -> $frameStyle,
    FrameMargins   -> 2,
    ContentPadding -> False,
    BaseStyle      -> $frameBaseStyle
];

$lastInlineReferenceCell = None;


$$inlineReferenceStyle = "InlinePersonaReference"|"InlineModifierReference"|"InlineFunctionReference";
$$inlineReferenceCell  = Cell[ __, $$inlineReferenceStyle, ___ ];


(* ::Section::Closed:: *)
(*Resolve Inline References*)


(* ::Subsection::Closed:: *)
(*resolveInlineReferences*)


resolveInlineReferences // beginDefinition;

resolveInlineReferences[ cell_CellObject ] /; $cloudNotebooks := parseInlineReferences @ cell;

resolveInlineReferences[ cell_CellObject ] := (
    resolveLastInlineReference[ ];
    resolveInlineReferences[
        cell,
        Cells[ cell, CellStyle -> { "InlineModifierChooser", "InlineFunctionChooser", "InlinePersonaChooser",
                                    "InlineModifierReference", "InlineFunctionReference", "InlinePersonaReference"} ]
    ]
);

resolveInlineReferences[ _, { } ] := Null;

resolveInlineReferences[ cell_, cells: { ___CellObject } ] := resolveLastInlineReference /@ cells;

resolveInlineReferences // endDefinition;



(* ::Subsubsection::Closed:: *)
(*parseInlineReferences*)


parseInlineReferences // beginDefinition;

parseInlineReferences[ cellObject_CellObject ] :=
    parseInlineReferences[ cellObject, NotebookRead @ cellObject ];

parseInlineReferences[ cellObject_CellObject, cell_Cell ] :=
    parseInlineReferences[ cellObject, cell, CellToString @ cell ];

parseInlineReferences[ cellObject_CellObject, _Cell, text_String ] := Enclose[
    Module[ { parsed, nbo },
        parsed = ConfirmMatch[ StringSplit[ text, $parsingRules ], { (_String|_Cell)... }, "Parse" ];
        If[ MatchQ[ parsed, { ___, _Cell, ___ } ],
            SelectionMove[ cellObject, All, CellContents ];
            nbo = parentNotebook @ cellObject;
            NotebookWrite[ nbo, # ] & /@ parsed;
            FirstCase[
                parsed,
                Cell[ __, TaggingRules -> KeyValuePattern[ "PersonaName" -> name_String ], ___ ] :> (
                    If[ ! MemberQ[ Keys @ GetCachedPersonaData[ ], name ],
                        ConfirmBy[ ResourceInstall[ "Prompt: "<>name ], FileExistsQ, "ResourceInstall" ];
                        ConfirmAssert[ MemberQ[ Keys @ GetCachedPersonaData[ ], name ], "GetCachedPersonaData" ]
                    ];
                    CurrentValue[ cellObject, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = name;
                    CurrentValue[ cellObject, TaggingRules ] =
                        GeneralUtilities`ToAssociations @ CurrentValue[ cellObject, TaggingRules ]
                )
            ]
        ]
    ],
    throwInternalFailure[ parseInlineReferences[ cellObject, text ], ##1 ] &
];

parseInlineReferences[ cell_Cell ] /; ! TrueQ @ $cloudNotebooks || FreeQ[ cell, $$inlineReferenceCell ] := cell;

parseInlineReferences[ cell: Cell[ _, args___ ] ] := Enclose[
    Module[ { text, parsed },
        text   = ConfirmBy[ CellToString @ cell, StringQ, "CellToString" ];
        parsed = ConfirmMatch[ StringSplit[ text, $parsingRules ], { (_String|_Cell)... }, "Parse" ];
        If[ MatchQ[ parsed, { ___, _Cell, ___ } ],
            Cell[ TextData @ parsed, args ],
            cell
        ]
    ],
    throwInternalFailure[ parseInlineReferences @ cell, ##1 ] &
];

parseInlineReferences // endDefinition;



$$refArgs = Longest[ "|" ~~ Except[ WhitespaceCharacter ].. ~~ ("|"|"") ] | "";


$parsingRules := {
    "@" ~~ p: $personaNames                                :> parsePersona @ p,
    "#" ~~ m: ($modifierNames~~$$refArgs)                  :> parseModifier @ m,
    StartOfString ~~ "!" ~~ f: ($functionNames~~$$refArgs) :> parseFunction @ f
};


(* ::Subsubsubsection::Closed:: *)
(*parsePersona*)


parsePersona // beginDefinition;

parsePersona[ name_String ] /; MemberQ[ $personaNames, name ] :=
    Append[
        personaTemplateCell[ name, "Chosen", CreateUUID[ ] ],
        TaggingRules -> <| "PersonaName" -> name, "PromptArguments" -> { } |>
    ];

parsePersona // endDefinition;


(* ::Subsubsubsection::Closed:: *)
(*parseModifier*)


parseModifier // beginDefinition;

parseModifier[ text_String ] := parseModifier @ functionInputSetting @ text;

parseModifier[ { name_String, params___String } ] /; MemberQ[ $modifierNames, name ] :=
    Append[
        modifierTemplateCell[ name, { params }, "Chosen", CreateUUID[ ] ],
        TaggingRules -> <| "PromptModifierName" -> name, "PromptArguments" -> { params } |>
    ];

parseModifier // endDefinition;


(* ::Subsubsubsection::Closed:: *)
(*parseFunction*)


parseFunction // beginDefinition;

parseFunction[ text_String ] := parseFunction @ functionInputSetting @ text;

parseFunction[ { name_String, params___String } ] /; MemberQ[ $functionNames, name ] :=
    Append[
        functionTemplateCell[ name, { params }, "Chosen", CreateUUID[ ] ],
        TaggingRules -> <| "PromptFunctionName" -> name, "PromptArguments" -> { params } |>
    ];

parseFunction // endDefinition;



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



(* ::Section::Closed:: *)
(*Modifier Input*)


$modifierDataURL = "https://resources.wolframcloud.com/PromptRepository/category/modifier-prompts-data.json";



(* ::Subsection::Closed:: *)
(*modifierCompletion*)


modifierCompletion // beginDefinition;
modifierCompletion[ "" ] := $modifierNames;
modifierCompletion[ string_String ] := Select[ $modifierNames, StringStartsQ[ string, IgnoreCase -> True ] ];
modifierCompletion // endDefinition;



(* ::Subsubsection::Closed:: *)
(*$modifierNames*)


$modifierNames := Select[
    DeleteDuplicates @ Flatten @ {
        AbsoluteCurrentValue @ { TaggingRules, "ChatNotebookSettings", "LLMEvaluator", "LLMEvaluatorName" },
        $availableModifierNames
    },
    StringQ
];



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
                                    FieldHint               -> tr[ "InlineReferencesFieldHint" ],
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



(* ::Subsubsection::Closed:: *)
(*processModifierInput*)


processModifierInput // beginDefinition;

processModifierInput[ string_String, { cell_CellObject }, cell_CellObject ] := Null;

processModifierInput[ string_String, _List, cell_CellObject ] :=
    writeStaticModifierBox[ cell, functionInputSetting @ string ];

processModifierInput // endDefinition;



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



(* ::Subsubsection::Closed:: *)
(*removeModifierInputBox*)


removeModifierInputBox // beginDefinition;
removeModifierInputBox[ cell_CellObject ] := Block[ { $removingBox = True }, writeStaticModifierBox @ cell ];
removeModifierInputBox // endDefinition;



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



(* ::Section::Closed:: *)
(*Function Input*)


$functionDataURL = "https://resources.wolframcloud.com/PromptRepository/category/function-prompts-data.json";



(* ::Subsection::Closed:: *)
(*functionCompletion*)


functionCompletion // beginDefinition;
functionCompletion[ "" ] := $functionNames;
functionCompletion[ string_String ] := Select[ $functionNames, StringStartsQ[ string, IgnoreCase -> True ] ];
functionCompletion // endDefinition;



(* ::Subsubsection::Closed:: *)
(*$functionNames*)


$functionNames := Select[
    DeleteDuplicates @ Flatten @ {
        AbsoluteCurrentValue @ { TaggingRules, "ChatNotebookSettings", "LLMEvaluator", "LLMEvaluatorName" },
        $availableFunctionNames
    },
    StringQ
];



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
                                    FieldHint               -> tr[ "InlineReferencesFieldHint" ],
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



(* ::Subsubsection::Closed:: *)
(*processFunctionInput*)


processFunctionInput // beginDefinition;

processFunctionInput[ string_String, { cell_CellObject }, cell_CellObject ] :=
    Null;

processFunctionInput[ string_String, _List, cell_CellObject ] :=
    writeStaticFunctionBox[ cell, functionInputSetting @ string ];

processFunctionInput // endDefinition;



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



(* ::Subsubsection::Closed:: *)
(*removeFunctionInputBox*)


removeFunctionInputBox // beginDefinition;
removeFunctionInputBox[ cell_CellObject ] := Block[ { $removingBox = True }, writeStaticFunctionBox @ cell ];
removeFunctionInputBox // endDefinition;



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



(* ::Subsubsection::Closed:: *)
(*functionInputSetting*)


functionInputSetting // beginDefinition;
functionInputSetting[ cell_CellObject ] := functionInputSetting @ NotebookRead @ cell;
functionInputSetting[ (Cell|BoxData|TagBox)[ boxes_, ___ ] ] := functionInputSetting @ boxes;
functionInputSetting[ DynamicModuleBox[ { ___, _ = string_String, ___ }, ___ ] ] := functionInputSetting @ string;

functionInputSetting[ string_String ] :=
    DeleteCases[ StringTrim @ StringSplit[ StringTrim @ string, $functionArgSplitRules ], "" ];

functionInputSetting // endDefinition;

$functionArgSplitRules = {
    $argumentDivider,
    "^^" :> "^^",
    "^"  :> "^",
    ">"  :> ">"
};



(* ::Section::Closed:: *)
(*Persona Input*)


$personaDataURL = "https://resources.wolframcloud.com/PromptRepository/category/personas-data.json";



(* ::Subsection::Closed:: *)
(*personaCompletion*)


personaCompletion // beginDefinition;
personaCompletion[ "" ] := $personaNames;
personaCompletion[ string_String ] := Select[ $personaNames, StringStartsQ[ string, IgnoreCase -> True ] ];
personaCompletion // endDefinition;



(* ::Subsubsection::Closed:: *)
(*$personaNames*)


$personaNames := Select[
    DeleteDuplicates @ Flatten @ {
        AbsoluteCurrentValue @ { TaggingRules, "ChatNotebookSettings", "LLMEvaluator", "LLMEvaluatorName" },
        Keys @ GetCachedPersonaData[ "IncludeHidden" -> False ],
        $availablePersonaNames
    },
    StringQ
];



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



(* ::Subsubsection::Closed:: *)
(*processPersonaInput (unused?)*)


processPersonaInput // beginDefinition;

processPersonaInput[ string_String, { cell_CellObject }, cell_CellObject ] := Null;

processPersonaInput[ string_String, _List, cell_CellObject ] :=
    writeStaticPersonaBox[ cell, personaInputSetting @ string ];

processPersonaInput // endDefinition;



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
        ConfirmBy[ ResourceInstall[ "Prompt: "<>name ], FileExistsQ, "ResourceInstall" ];
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



(* ::Subsubsection::Closed:: *)
(*removePersonaInputBox*)


removePersonaInputBox // beginDefinition;
removePersonaInputBox[ cell_CellObject ] := Block[ { $removingBox = True }, writeStaticPersonaBox @ cell ];
removePersonaInputBox // endDefinition;



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



(* ::Subsubsection::Closed:: *)
(*personaInputSetting*)


personaInputSetting // beginDefinition;
personaInputSetting[ string_String ] := string;
personaInputSetting[ cell_CellObject ] := personaInputSetting @ NotebookRead @ cell;
personaInputSetting[ (Cell|BoxData|TagBox)[ boxes_, ___ ] ] := personaInputSetting @ boxes;
personaInputSetting[ DynamicModuleBox[ { ___, _ = string_String, ___ }, ___ ] ] := string;
(*personaInputSetting[ TemplateBox[assoc_?AssociationQ, "ChatbookPersona", ___]] := assoc["name"];*)
personaInputSetting // endDefinition;



(* ::Section::Closed:: *)
(*Template Utilities*)


overrideKeyEvents[expr_] :=
	EventHandler[expr, {
			{"KeyDown", "@"} :> NotebookWrite[EvaluationNotebook[], "@"],
			{"KeyDown", "#"} :> NotebookWrite[EvaluationNotebook[], "#"],
			{"KeyDown", "!"} :> NotebookWrite[EvaluationNotebook[], "!"]
		},
		PassEventsDown -> False,
		PassEventsUp -> False
	]


backspaceWhenEmpty[expr_, Hold[input_]] :=
	EventHandler[expr,
		{"KeyDown", "Backspace"} :> If[input === "", NotebookDelete[EvaluationCell[]]],
		PassEventsDown -> True
	]


(* ::Section::Closed:: *)
(*Persona Template*)


(* ::Subsection::Closed:: *)
(*personaCommitAction*)


SetAttributes[personaCommitAction, HoldRest]

personaCommitAction[action: "Enter", var_, state_] := (
	(*Print[{Hold[var], var, action}];*)
	(* Pressing enter should effectively accept the first match, if there is one *)
	Replace[personaCompletion[var], {match_, ___} :> (var = match)]
)

personaCommitAction[action_, var_, state_] := (
	(*Print[{Hold[var], var, action}];*)
	(* If the "ReturnKeyDown" trap was avoided, do the state change here *)
	setPersonaState[state, "Chosen", var]
)


(* ::Subsection::Closed:: *)
(*setPersonaState*)


SetAttributes[setPersonaState, HoldFirst]

setPersonaState[state_, "Input", input_] := (
	state = "Input";
	MathLink`CallFrontEnd[FrontEnd`BoxReferenceFind[
			FE`BoxReference[MathLink`CallFrontEnd[FrontEnd`Value[FEPrivate`Self[]]],
			{FE`Parent["ChatbookPersonaID"]}],
			AutoScroll -> True
		]];
	FrontEndExecute[FrontEnd`FrontEndToken["MoveNextPlaceHolder"]];
)

setPersonaState[state_, "Chosen", input_] :=
Enclose[
	With[{cellObj = EvaluationCell[]},
		state = "Chosen";
		SelectionMove[cellObj, All, Cell];
		FrontEndExecute[FrontEnd`FrontEndToken["MoveNext"]];
		CurrentValue[cellObj, {TaggingRules, "PersonaName"}] = input;

		If[ ! MemberQ[ Keys @ GetCachedPersonaData[ ], input ],
	        ConfirmBy[ ResourceInstall[ "Prompt: "<>input ], FileExistsQ, "ResourceInstall" ];
	        ConfirmAssert[ MemberQ[ Keys @ GetCachedPersonaData[ ], input ], "GetCachedPersonaData" ]
	    ];

		With[ { parent = ParentCell @ cellObj },
			CurrentValue[ parent, CellDingbat ] = Inherited;
			CurrentValue[ parent, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = input;
		]
	]
	,
	throwInternalFailure[ setPersonaState[state, "Chosen", input], ## ] &
]

setPersonaState[state_, "Replace", input_String] := (
	SelectionMove[EvaluationCell[], All, Cell];
	NotebookWrite[InputNotebook[], "@" <> input]
)


(* ::Subsection::Closed:: *)
(*personaTemplateBoxes*)


SetAttributes[personaTemplateBoxes, HoldRest];

personaTemplateBoxes[version: 1, input_, state_, uuid_, opts: OptionsPattern[]] /; state === "Input" :=
	EventHandler[
		Style[
			Framed[
				Grid[
					{
						{
							RawBoxes[TemplateBox[{}, "InlineReferenceIconAt"]],
							InputField[
								Dynamic @ input,
								String,
								Alignment			   -> { Left, Baseline },
								ContinuousAction		-> True,
								FieldCompletionFunction -> personaCompletion,
								System`CommitAction	 -> (personaCommitAction[#, input, state]&),
								TrapSelection -> False,
								BaselinePosition -> Baseline,
								FieldSize			   -> { { 15, Infinity }, Automatic },
								BaseStyle			   -> $inputFieldStyle,
								Appearance			  -> "Frameless",
								(*ContentPadding		  -> False,*)
								FrameMargins			-> 0,
								BoxID				   -> uuid
							] // overrideKeyEvents // backspaceWhenEmpty[#, Hold[input]]&
						}
					},
					Spacings  -> 0,
					Alignment -> { Automatic, Baseline },
					BaselinePosition -> {1,2}
				],
				BaselinePosition -> Baseline,
				FrameStyle -> RGBColor[0.227, 0.553, 0.694],
				ImageMargins -> {{1,1},{0,0}},
				$frameOptions
			],
			"Text",
			ShowStringCharacters -> False
		],
		{
			"EscapeKeyDown" :> setPersonaState[state, "Replace", input],
			"ReturnKeyDown" :> setPersonaState[state, If[Length[personaCompletion[input]] > 0 && input =!= "", "Chosen", "Replace"], input]
		}
	]

personaTemplateBoxes[version: 1, input_, state_, uuid_, opts: OptionsPattern[]] /; state === "Chosen" :=
	Button[
		NotebookTools`Mousedown @@ MapThread[
			Framed[
				Row[{RawBoxes[TemplateBox[{}, "InlineReferenceIconAt"]], input}],
				BaselinePosition -> Baseline,
				RoundingRadius -> 2,
				Background -> #1,
				FrameStyle -> #2,
				FrameMargins -> 2,
				ImageMargins -> {{1,1},{0,0}}]&,
			{
				{RGBColor[0.824, 0.918, 0.961], RGBColor[0.925, 0.976, 1.000], RGBColor[0.765, 0.878, 0.925]},
				{RGBColor[0.227, 0.553, 0.694], RGBColor[0.455, 0.737, 0.863], RGBColor[0.196, 0.510, 0.647]}
			}
		],
		setPersonaState[state, "Input", input]
		,
		Appearance -> "Suppressed",
		BaseStyle -> {},
		DefaultBaseStyle -> {},
		BaselinePosition -> Baseline
	]

(* FIXME: Add a personaTemplateBoxes rule for unknown version number *)


(* ::Subsection::Closed:: *)
(*personaTemplateCell*)


personaTemplateCell[input_String, state: ("Input" | "Chosen"), uuid_String] :=
Cell[BoxData[FormBox[
	TemplateBox[<|"input" -> input, "state" -> state, "uuid" -> uuid|>,
		"ChatbookPersona"
	], TextForm]],
	"InlinePersonaReference",
	Background -> None,
	Deployed -> True
]


(* ::Subsection::Closed:: *)
(*insertPersonaTemplate*)


insertPersonaTemplate[ cell_CellObject ] := insertPersonaTemplate[ cell, parentNotebook @ cell ];

insertPersonaTemplate[ parent_CellObject, nbo_NotebookObject ] :=
	Module[ { uuid, cellExpr },
		resolveInlineReferences @ parent;
		uuid = CreateUUID[ ];
		cellExpr = personaTemplateCell[ "", "Input", uuid ];
		NotebookWrite[ nbo, cellExpr ];
		(* FIXME: Can we get rid of the need for this UUID, and use BoxReference-something? *)
		FrontEnd`MoveCursorToInputField[ nbo, uuid ]
	];

insertPersonaTemplate[ name_String, cell_CellObject ] := insertPersonaTemplate[ name, cell, parentNotebook @ cell ];

insertPersonaTemplate[ name_String, parent_CellObject, nbo_NotebookObject ] :=
	Module[ { uuid, cellExpr },
		resolveInlineReferences @ ParentCell @ parent;
		uuid = CreateUUID[ ];
		cellExpr = personaTemplateCell[ name, "Input", uuid ];
		NotebookWrite[ parent, cellExpr ];
		FrontEnd`MoveCursorToInputField[ nbo, uuid ]
	];


(* ::Section::Closed:: *)
(*Modifier Template*)


(* ::Subsection::Closed:: *)
(*modifierCommitAction*)


SetAttributes[modifierCommitAction, HoldRest]

modifierCommitAction[action: "Enter", input_, params_, state_] := (
	(*Print[{Hold[var], var, action}];*)
	(* Pressing enter should effectively accept the first match, if there is one *)
	Replace[modifierCompletion[input], {match_, ___} :> (input = match)]
)

modifierCommitAction[action_, input_, params_, state_] := (
	(*Print[{Hold[var], var, action}];*)
	(* If the "ReturnKeyDown" trap was avoided, do the state change here *)
	setModifierState[state, "Chosen", input, params]
)


(* ::Subsection::Closed:: *)
(*setModifierState*)


SetAttributes[setModifierState, HoldFirst]

setModifierState[state_, "Input", input_, params_] := (
	state = "Input";
	MathLink`CallFrontEnd[FrontEnd`BoxReferenceFind[
			FE`BoxReference[MathLink`CallFrontEnd[FrontEnd`Value[FEPrivate`Self[]]],
			{FE`Parent["ChatbookModifierID"]}],
			AutoScroll -> True
		]];
	FrontEndExecute[FrontEnd`FrontEndToken["MoveNextPlaceHolder"]];
)

setModifierState[state_, "Chosen", input_, params_] :=
Enclose[
	With[{cellObj = EvaluationCell[]},
		state = "Chosen";
		SelectionMove[cellObj, All, Cell];
		FrontEndExecute[FrontEnd`FrontEndToken["MoveNext"]];
		CurrentValue[cellObj, TaggingRules] = <| "PromptModifierName" -> input, "PromptArguments" -> params |>;
	]
	,
	throwInternalFailure[ setModifierState[state, "Chosen", input, params], ## ] &
]

setModifierState[state_, "Replace", input_, params_] := (
	SelectionMove[EvaluationCell[], All, Cell];
	NotebookWrite[InputNotebook[], "#" <> toModifierString[input, params]]
)


(* ::Subsection::Closed:: *)
(*modifierTemplateBoxes*)


toModifierString[input_String, {params___String}] := StringRiffle[{input, params}, " | "]


fromModifierString[str_String] := Replace[ StringTrim /@ StringSplit[str, "|"],
	{ {first_, rest___} :> {first, {rest}}, _ :> {"", {}} }]


SetAttributes[modifierTemplateBoxes, HoldRest];

modifierTemplateBoxes[version: 1, input_, params_, state_, uuid_, opts: OptionsPattern[]] /; state === "Input" :=
	EventHandler[
		Style[
			Framed[
				Grid[
					{
						{
							RawBoxes[TemplateBox[{}, "InlineReferenceIconHash"]],
							InputField[
								Dynamic[
									toModifierString[input, params],
									({input, params} = fromModifierString[#])&
								],
								String,
								Alignment               -> { Left, Baseline },
								ContinuousAction        -> False,
								FieldCompletionFunction -> modifierCompletion,
								System`CommitAction -> (modifierCommitAction[#, input, params, state]&),
								BaselinePosition -> Baseline,
								FieldSize               -> { { 15, Infinity }, Automatic },
								FieldHint               -> tr[ "InlineReferencesFieldHint" ], (* FIXME: Is this right? *)
								BaseStyle               -> $inputFieldStyle,
								Appearance              -> "Frameless",
								(*ContentPadding          -> False,*)
								FrameMargins            -> 0,
								BoxID                   -> uuid
							] // overrideKeyEvents
						}
					},
					Spacings  -> 0,
					Alignment -> { Automatic, Baseline },
					BaselinePosition -> {1,2}
				],
				BaselinePosition -> Baseline,
				FrameStyle -> RGBColor[0.529, 0.776, 0.424],
				ImageMargins -> {{1,1},{0,0}},
				$frameOptions
			],
			"Text",
			ShowStringCharacters -> False
		],
		{
			(*{ "KeyDown", "#" } :> NotebookWrite[ EvaluationNotebook[ ], "#" ],*)
			"EscapeKeyDown" :> setModifierState[state, "Replace", input, params],
			"ReturnKeyDown" :> setModifierState[state,
				If[Length[modifierCompletion[input]] > 0 && input =!= "", "Chosen", "Replace"], input, params]
		}
	]

modifierTemplateBoxes[version: 1, input_, params_, state_, uuid_, opts: OptionsPattern[]] /; state === "Chosen" :=
	Button[
		NotebookTools`Mousedown @@ MapThread[
			Framed[
				Grid[{{
					Row[{RawBoxes[TemplateBox[{}, "InlineReferenceIconHash"]], input}],
					Map[
						Style[#, FontSize -> Inherited * 0.9]&,
						Replace[params, Except[_List] :> {}]
					] // Splice
					}},
					BaselinePosition -> {1,1},
					Dividers -> {Center, None},
					FrameStyle -> #2
				],
				BaselinePosition -> Baseline,
				RoundingRadius -> 2,
				Background -> #1,
				FrameStyle -> #2,
				FrameMargins -> 2,
				ImageMargins -> {{1,1},{0,0}}]&,
			{
				{RGBColor[0.894, 0.965, 0.847], RGBColor[0.961, 1.000, 0.937], RGBColor[0.796, 0.925, 0.733]},
				{RGBColor[0.529, 0.776, 0.424], RGBColor[0.647, 0.886, 0.545], RGBColor[0.408, 0.671, 0.294]}
			}
		],
		setModifierState[state, "Input", input, params]
		,
		Appearance -> "Suppressed",
		BaseStyle -> {},
		DefaultBaseStyle -> {},
		BaselinePosition -> Baseline
	]

(* FIXME: Add a modifierTemplateBoxes rule for unknown version number *)


(* ::Subsection::Closed:: *)
(*modifierTemplateCell*)


modifierTemplateCell[input_String, params_List, state: ("Input" | "Chosen"), uuid_String] :=
Cell[BoxData[FormBox[
	TemplateBox[<|"input" -> input, "params" -> params, "state" -> state, "uuid" -> uuid|>,
		"ChatbookModifier"
	], TextForm]],
	"InlineModifierReference",
	Background -> None,
	Deployed -> True
]


(* ::Subsection::Closed:: *)
(*insertModifierTemplate*)


insertModifierTemplate[ cell_CellObject ] :=
    If[ MatchQ[
            Developer`CellInformation @ SelectedCells[ ],
            { KeyValuePattern @ { "Style" -> $$chatInputStyle } }
        ],
        insertModifierTemplate[ cell, parentNotebook @ cell ],
        NotebookWrite[ parentNotebook @ cell, "#" ]
    ];

insertModifierTemplate[ parent_CellObject, nbo_NotebookObject ] :=
	Module[ { uuid, cellExpr },
		resolveInlineReferences @ parent;
		uuid = CreateUUID[ ];
		cellExpr = modifierTemplateCell[ "", {}, "Input", uuid ];
		NotebookWrite[ nbo, cellExpr ];
		(* FIXME: Can we get rid of the need for this UUID, and use BoxReference-something? *)
		FrontEnd`MoveCursorToInputField[ nbo, uuid ]
	];

insertModifierTemplate[ name_String, cell_CellObject ] := insertModifierTemplate[ name, cell, parentNotebook @ cell ];

insertModifierTemplate[ name_String, parent_CellObject, nbo_NotebookObject ] :=
	Module[ { uuid, cellExpr },
		resolveInlineReferences @ ParentCell @ parent;
		uuid = CreateUUID[ ];
		cellExpr = modifierTemplateCell[ name, {}, "Input", uuid ];
		NotebookWrite[ parent, cellExpr ];
		FrontEnd`MoveCursorToInputField[ nbo, uuid ]
	];


(* ::Section::Closed:: *)
(*Function Template*)


(* ::Subsection::Closed:: *)
(*functionCommitAction*)


SetAttributes[functionCommitAction, HoldRest]

functionCommitAction[action: "Enter", input_, params_, state_] := (
	(*Print[{action, input, params, state}];*)
	(* Pressing enter should effectively accept the first match, if there is one *)
	Replace[functionCompletion[input], {match_, ___} :> (input = match)]
)

functionCommitAction[action: "FieldCompletion", input_, params_, state_] := (
	(*Print[{action, input, params, state}];*)
	(* do nothing -- leave the interface in the "Input" state *)
	Null
)

functionCommitAction[action_, input_, params_, state_] := (
	(*Print[{action, input, params, state}];*)
	(* If the "ReturnKeyDown" trap was avoided, do the state change here *)
	setFunctionState[state, "Chosen", input, params]
)


(* ::Subsection::Closed:: *)
(*setFunctionState*)


SetAttributes[setFunctionState, HoldFirst]

setFunctionState[state_, "Input", input_, params_] := (
	state = "Input";
	MathLink`CallFrontEnd[FrontEnd`BoxReferenceFind[
			FE`BoxReference[MathLink`CallFrontEnd[FrontEnd`Value[FEPrivate`Self[]]],
			{FE`Parent["ChatbookFunctionID"]}],
			AutoScroll -> True
		]];
	FrontEndExecute[FrontEnd`FrontEndToken["MoveNextPlaceHolder"]];
)

setFunctionState[state_, "Chosen", input_, params_] :=
Enclose[
	With[{cellObj = EvaluationCell[]},
		state = "Chosen";
		SelectionMove[cellObj, All, Cell];
		FrontEndExecute[FrontEnd`FrontEndToken["MoveNext"]];
		CurrentValue[cellObj, TaggingRules] = <| "PromptFunctionName" -> input, "PromptArguments" -> params |>;
	]
	,
	throwInternalFailure[ setFunctionState[state, "Chosen", input, params], ## ]&
]

setFunctionState[state_, "Replace", input_, params_] := (
	SelectionMove[EvaluationCell[], All, Cell];
	NotebookWrite[InputNotebook[], "!" <> input]
)


(* ::Subsection::Closed:: *)
(*functionTemplateBoxes*)


toFunctionString[input_String, {params___String}] := StringRiffle[{input, params}, " | "]


fromFunctionString[str_String] := Replace[ functionInputSetting[str], {
	{} | {""} :> {"", {}},
	{first_} :> {first, {">"}},
	{first_, rest__} :> {first, {rest}}
}]


SetAttributes[functionTemplateBoxes, HoldRest];

functionTemplateBoxes[version: 1, input_, params_, state_, uuid_, opts: OptionsPattern[]] /; state === "Input" :=
	EventHandler[
		Style[
			Framed[
				Grid[
					{
						{
							RawBoxes[TemplateBox[{}, "InlineReferenceIconBang"]],
							InputField[
								Dynamic[
									toFunctionString[input, params],
									({input, params} = fromFunctionString[#])&
								],
								String,
								Alignment               -> { Left, Baseline },
								ContinuousAction        -> False,
								FieldCompletionFunction -> functionCompletion,
								System`CommitAction -> (functionCommitAction[#, input, params, state]&),
								BaselinePosition -> Baseline,
								FieldSize               -> { { 15, Infinity }, Automatic },
								FieldHint               -> tr[ "InlineReferencesFieldHint" ], (* FIXME: Is this right? *)
								BaseStyle               -> $inputFieldStyle,
								Appearance              -> "Frameless",
								(*ContentPadding          -> False,*)
								FrameMargins            -> 0,
								BoxID                   -> uuid
							] // overrideKeyEvents
						}
					},
					Spacings  -> 0,
					Alignment -> { Automatic, Baseline },
					BaselinePosition -> {1,2}
				],
				BaselinePosition -> Baseline,
				FrameStyle -> RGBColor[1.000, 0.608, 0.255],
				ImageMargins -> {{1,1},{0,0}},
				$frameOptions
			],
			"Text",
			ShowStringCharacters -> False
		],
		{
			(*{ "KeyDown", "!" } :> NotebookWrite[ EvaluationNotebook[ ], "!" ],*)
			"EscapeKeyDown" :> setFunctionState[state, "Replace", input, params],
			"ReturnKeyDown" :> setFunctionState[state,
				If[Length[functionCompletion[input]] > 0 && input =!= "", "Chosen", "Replace"], input, params]
		}
	]

functionTemplateBoxes[version: 1, input_, params_, state_, uuid_, opts: OptionsPattern[]] /; state === "Chosen" :=
	Button[
		NotebookTools`Mousedown @@ MapThread[
			Framed[
				Grid[{{
					Row[{RawBoxes[TemplateBox[{}, "InlineReferenceIconBang"]], input}],
					Replace[
						Replace[params, Except[_List] :> {}],
						{
							">" :> RawBoxes @ TemplateBox[{}, "InlineReferenceIconRight"],
							"^" :> RawBoxes @ TemplateBox[{}, "InlineReferenceIconPrevious"],
							"^^" :> RawBoxes @ TemplateBox[{}, "InlineReferenceIconHistory"],
							else_ :> Style[else, FontSize -> Inherited * 0.9]
						},
						{1}
					] // Splice
					}},
					BaselinePosition -> {1,1},
					Dividers -> {Center, None},
					FrameStyle -> #2
				],
				BaselinePosition -> Baseline,
				RoundingRadius -> 2,
				Background -> #1,
				FrameStyle -> #2,
				FrameMargins -> 2,
				ImageMargins -> {{1,1},{0,0}}]&,
			{
				{RGBColor[0.988, 0.910, 0.839], RGBColor[1., 0.957, 0.914], RGBColor[0.969, 0.831, 0.718]},
				{RGBColor[1.000, 0.608, 0.255], RGBColor[1., 0.765, 0.553], RGBColor[0.914, 0.522, 0.169]}
			}
		],
		setFunctionState[state, "Input", input, params]
		,
		Appearance -> "Suppressed",
		BaseStyle -> {},
		DefaultBaseStyle -> {},
		BaselinePosition -> Baseline
	]

(* FIXME: Add a functionTemplateBoxes rule for unknown version number *)


(* ::Subsection::Closed:: *)
(*functionTemplateCell*)


functionTemplateCell[input_String, params_List, state: ("Input" | "Chosen"), uuid_String] :=
Cell[BoxData[FormBox[
	TemplateBox[<|"input" -> input, "params" -> params, "state" -> state, "uuid" -> uuid|>,
		"ChatbookFunction"
	], TextForm]],
	"InlineFunctionReference",
	Background -> None,
	Deployed -> True
]


(* ::Subsection::Closed:: *)
(*insertFunctionTemplate*)


insertFunctionTemplate[ cell_CellObject ] :=
    If[ MatchQ[
            Developer`CellInformation @ SelectedCells[ ],
            { KeyValuePattern @ { "Style" -> $$chatInputStyle, "CursorPosition" -> { 0, _ } } }
        ],
        insertFunctionTemplate[ cell, parentNotebook @ cell ],
        NotebookWrite[ parentNotebook @ cell, "!" ]
    ];

insertFunctionTemplate[ parent_CellObject, nbo_NotebookObject ] :=
	Module[ { uuid, cellExpr },
		resolveInlineReferences @ parent;
		uuid = CreateUUID[ ];
		cellExpr = functionTemplateCell[ "", {}, "Input", uuid ];
		NotebookWrite[ nbo, cellExpr ];
		(* FIXME: Can we get rid of the need for this UUID, and use BoxReference-something? *)
		FrontEnd`MoveCursorToInputField[ nbo, uuid ]
	];

insertFunctionTemplate[ name_String, cell_CellObject ] := insertFunctionTemplate[ name, cell, parentNotebook @ cell ];

insertFunctionTemplate[ name_String, parent_CellObject, nbo_NotebookObject ] :=
	Module[ { uuid, cellExpr },
		resolveInlineReferences @ ParentCell @ parent;
		uuid = CreateUUID[ ];
		cellExpr = functionTemplateCell[ name, {}, "Input", uuid ];
		NotebookWrite[ parent, cellExpr ];
		FrontEnd`MoveCursorToInputField[ nbo, uuid ]
	];


(* ::Section::Closed:: *)
(*WL Template*)


(* ::Subsection::Closed:: *)
(*setWLState*)


SetAttributes[setWLState, HoldFirst]

setWLState[state_, "Input", input_] := (
	state = "Input";
	MathLink`CallFrontEnd[FrontEnd`BoxReferenceFind[
			FE`BoxReference[MathLink`CallFrontEnd[FrontEnd`Value[FEPrivate`Self[]]],
			{FE`Parent["ChatbookWLTemplateID"]}],
			AutoScroll -> True
		]];
	FrontEndExecute[FrontEnd`FrontEndToken["MoveNextPlaceHolder"]];
)

setWLState[state_, "Chosen", input_] :=
Enclose[
	With[{cellObj = EvaluationCell[]},
		state = "Chosen";
		SelectionMove[cellObj, All, Cell];
		FrontEndExecute[FrontEnd`FrontEndToken["MoveNext"]];
		CurrentValue[cellObj, TaggingRules] = <| "WLCode" -> input |>;
	]
	,
	throwInternalFailure[ setWLState[state, "Chosen", input], ## ]&
]

setWLState[ state_, "Replace", input_ ] := (
    SelectionMove[ EvaluationCell[ ], All, Cell ];
    NotebookWrite[
        InputNotebook[ ],
        First[
            FrontEndExecute @ FrontEnd`ExportPacket[ Cell @ BoxData @ RowBox @ { "\\", input }, "PlainText" ],
            "\\"
        ]
    ]
);


(* ::Subsection::Closed:: *)
(*wlTemplateBoxes*)


SetAttributes[wlTemplateBoxes, HoldRest];

wlTemplateBoxes[version: 1, input_, state_, uuid_, opts: OptionsPattern[]] /; state === "Input" :=
	EventHandler[
		Style[
			Framed[
				Grid[
					{
						{
							RawBoxes[TemplateBox[{}, "AssistantEvaluate"]],
							InputField[
								Dynamic[ input ],
								Boxes,
								Alignment               -> { Left, Baseline },
								ContinuousAction        -> False,
								BaselinePosition        -> Baseline,
								FieldSize               -> { { 5, Infinity }, Automatic },
								Appearance              -> "Frameless",
								(*ContentPadding          -> False,*)
								FrameMargins            -> 0,
								BoxID                   -> uuid,
                                BaseStyle -> {
                                    "Notebook",
                                    "Input",
                                    ShowCodeAssist   -> True,
                                    ShowSyntaxStyles -> True,
                                    FontFamily       -> "Source Sans Pro",
                                    FontSize         -> 14
                                }
							] // overrideKeyEvents
						}
					},
					Spacings         -> 0,
					Alignment        -> { Automatic, Baseline },
					BaselinePosition -> { 1, 2 }
				],
				BaselinePosition -> Baseline,
				FrameStyle       -> GrayLevel[0.9],
				ImageMargins     -> {{1,1},{0,0}},
				$frameOptions
			],
			"Text",
			ShowStringCharacters -> False
		],
		{
			(*{ "KeyDown", "!" } :> NotebookWrite[ EvaluationNotebook[ ], "!" ],*)
			"EscapeKeyDown" :> setWLState[state, "Replace", input],
			"ReturnKeyDown" :> setWLState[state, "Chosen", input]
		}
	]

wlTemplateBoxes[ version: 1, input_, state_, uuid_, opts: OptionsPattern[ ] ] /; state === "Chosen" :=
    Button[
        NotebookTools`Mousedown @@ MapThread[
            Framed[
                Grid[
                    {
                        {
                            RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ],
                            Style[
                                RawBoxes @ input,
                                "Input",
                                ShowCodeAssist       -> True,
                                ShowSyntaxStyles     -> True,
                                FontFamily           -> "Source Sans Pro",
                                FontSize             -> 14,
                                ShowStringCharacters -> True
                            ]
                        }
                    },
                    Spacings  -> 0,
                    Alignment -> { Automatic, Baseline }
                ],
                BaselinePosition -> { 1, 2 },
                RoundingRadius   -> 2,
                Background       -> #1,
                FrameStyle       -> #2,
                FrameMargins     -> 2,
                ImageMargins     -> { { 1, 1 }, { 0, 0 } }
            ] &,
            {
                { GrayLevel[ 0.95 ], GrayLevel[ 0.975 ], GrayLevel[ 1.0 ] },
                { GrayLevel[ 0.90 ], GrayLevel[ 0.800 ], GrayLevel[ 0.9 ] }
            }
        ],
        setWLState[ state, "Input", input ]
        ,
        Appearance       -> "Suppressed",
        BaseStyle        -> { },
        DefaultBaseStyle -> { },
        BaselinePosition -> Baseline
    ];

(* FIXME: Add a wlTemplateBoxes rule for unknown version number *)


(* ::Subsection::Closed:: *)
(*wlTemplateCell*)


wlTemplateCell[input_String, state: ("Input" | "Chosen"), uuid_String] :=
Cell[BoxData[FormBox[
	TemplateBox[<|"input" -> input, "state" -> state, "uuid" -> uuid|>,
		"ChatbookWLTemplate"
	], TextForm]],
	"InlineWLReference",
	Background -> None,
	Deployed -> True
]


(* ::Subsection::Closed:: *)
(*insertWLTemplate*)


insertWLTemplate[ cell_CellObject ] :=
    insertWLTemplate[ cell, parentNotebook @ cell ];

insertWLTemplate[ parent_CellObject, nbo_NotebookObject ] :=
	Module[ { uuid, cellExpr },
		resolveInlineReferences @ parent;
		uuid = CreateUUID[ ];
		cellExpr = wlTemplateCell[ "", "Input", uuid ];
		NotebookWrite[ nbo, cellExpr ];
		(* FIXME: Can we get rid of the need for this UUID, and use BoxReference-something? *)
		FrontEnd`MoveCursorToInputField[ nbo, uuid ]
	];

insertWLTemplate[ name_String, cell_CellObject ] := insertWLTemplate[ name, cell, parentNotebook @ cell ];

insertWLTemplate[ name_String, parent_CellObject, nbo_NotebookObject ] :=
	Module[ { uuid, cellExpr },
		resolveInlineReferences @ ParentCell @ parent;
		uuid = CreateUUID[ ];
		cellExpr = wlTemplateCell[ name, "Input", uuid ];
		NotebookWrite[ parent, cellExpr ];
		FrontEnd`MoveCursorToInputField[ nbo, uuid ]
	];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud Docked Cell*)

$cloudInlineReferenceButtons = Block[ { NotebookTools`Mousedown = Mouseover[ #1, #2 ] & },
    Grid[
        {
            {
                Style[ tr[ "InlineReferencesInsertLabel" ], "Text" ],
                Button[
                    First @ personaTemplateBoxes[ 1, "Persona", "Chosen", "PersonaInsertButton" ],
                    With[ { name = InputString[ tr[ "InlineReferencesInsertPersonaPrompt" ] ], uuid = CreateUUID[ ] },
                        If[ MemberQ[ $personaNames, name ],
                            NotebookWrite[
                                EvaluationNotebook[ ],
                                Append[
                                    personaTemplateCell[ name, "Chosen", uuid ],
                                    TaggingRules -> <| "PersonaName" -> name |>
                                ]
                            ];
                            CurrentValue[
                                EvaluationNotebook[ ], (* FIXME: figure out how to get selected cell in cloud *)
                                { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" }
                            ] = name;
                            ,
                            If[ StringQ @ name,
                                MessageDialog @ trStringTemplate[ "InlineReferencesInsertPersonaFail" ][
                                    <| "name" -> name |>
                                ]
                            ]
                        ]
                    ],
                    Appearance -> $suppressButtonAppearance,
                    Method     -> "Queued"
                ],
                Button[
                    First @ modifierTemplateBoxes[ 1, "Modifier", { }, "Chosen", "ModifierInsertButton" ],
                    With[ { s = InputString[ tr[ "InlineReferencesInsertModifierPrompt" ] ], uuid = CreateUUID[ ] },
                        Replace[
                            functionInputSetting @ s,
                            { name_String, args___String } :>
                                If[ MemberQ[ $modifierNames, name ],
                                    NotebookWrite[
                                        EvaluationNotebook[ ],
                                        Append[
                                            modifierTemplateCell[ name, { args }, "Chosen", uuid ],
                                            TaggingRules -> <|
                                                "PromptModifierName" -> name,
                                                "PromptArguments"    -> { args }
                                            |>
                                        ]
                                    ]
                                    ,
                                    If[ StringQ @ name,
                                        MessageDialog @ trStringTemplate[ "InlineReferencesInsertModifierFail" ][
                                            <| "name" -> name |>
                                        ]
                                    ]
                                ]
                        ]
                    ],
                    Appearance -> $suppressButtonAppearance,
                    Method     -> "Queued"
                ],
                Button[
                    First @ functionTemplateBoxes[ 1, "Function", { }, "Chosen", "FunctionInsertButton" ],
                    With[ { s = InputString[ tr[ "InlineReferencesInsertFunctionPrompt" ] ], uuid = CreateUUID[ ] },
                        Replace[
                            functionInputSetting @ s,
                            { name_String, args___String } :>
                                If[ MemberQ[ $functionNames, name ],
                                    NotebookWrite[
                                        EvaluationNotebook[ ],
                                        Append[
                                            functionTemplateCell[ name, { args }, "Chosen", uuid ],
                                            TaggingRules -> <|
                                                "PromptFunctionName" -> name,
                                                "PromptArguments"    -> { args }
                                            |>
                                        ]
                                    ]
                                    ,
                                    If[ StringQ @ name,
                                        MessageDialog @ trStringTemplate[ "InlineReferencesInsertFunctionFail" ][
                                            <| "name" -> name |>
                                        ]
                                    ]
                                ]
                        ]
                    ],
                    Appearance -> $suppressButtonAppearance,
                    Method     -> "Queued"
                ]
            }
        },
        Spacings -> 0.5
    ]
];


(* ::Section::Closed:: *)
(*Package Footer*)


addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
