(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`ShowCodeAssistance`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$workspaceChatWidth := $workspaceChatWidth = Switch[ $OperatingSystem, "MacOSX", 450, _, 360 ];

$codeAssistanceBaseSettings = <|
    "AppName"           -> "CodeAssistance",
    "LLMEvaluator"      -> "NotebookAssistant",
    "PromptGenerators"  -> { "RelatedDocumentation" },
    "ServiceCaller"     -> "CodeAssistance",
    "ToolOptions"       -> <| "WolframLanguageEvaluator" -> <| "AppendURIPrompt" -> True, "Method" -> "Session" |> |>,
    "Tools"             -> { "NotebookEditor" },
    "ToolSelectionType" -> <| "DocumentationLookup" -> None, "DocumentationSearcher" -> None |>
|>;

$codeAssistanceWorkspaceSettings := <|
    $codeAssistanceBaseSettings,
    "AutoGenerateTitle"     -> True,
    "AutoSaveConversations" -> True,
    "ConversationUUID"      -> CreateUUID[ ],
    "SetCellDingbat"        -> False,
    "TabbedOutput"          -> False,
    "WorkspaceChat"         -> True
|>;

$codeAssistanceInlineSettings := <|
    $codeAssistanceBaseSettings,
    "AutoGenerateTitle"     -> False,
    "AutoSaveConversations" -> False,
    "InlineChat"            -> True
|>;

$workspaceChatNotebookOptions := Sequence[
    DefaultNewCellStyle -> "AutoMoveToChatInputField",
    StyleDefinitions    -> FrontEnd`FileName[ { "Wolfram" }, "WorkspaceChat.nb", CharacterEncoding -> "UTF-8" ],
    TaggingRules        -> <|
        "ChatInputString"      -> "",
        "ChatNotebookSettings" -> $codeAssistanceWorkspaceSettings,
        "ConversationTitle"    -> ""
    |>
];

(* TODO: set $serviceCaller from chat settings *)

$$codeAssistanceMenuItem = "Inline"|"Window"|"ContentSuggestions";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EnableCodeAssistance*)
EnableCodeAssistance // beginDefinition;

EnableCodeAssistance[ ] :=
    catchMine @ EnableCodeAssistance @ Automatic;

EnableCodeAssistance[ Automatic ] := catchMine @
    If[ $VersionNumber >= 14.1,
        enableCodeAssistance @ { "Window", "ContentSuggestions" },
        enableCodeAssistance @ { "Window" }
    ];

EnableCodeAssistance[ keys: { $$codeAssistanceMenuItem.. } ] :=
    catchMine @ enableCodeAssistance @ DeleteDuplicates @ keys;

EnableCodeAssistance[ key: $$codeAssistanceMenuItem ] :=
    catchMine @ enableCodeAssistance @ { key };

EnableCodeAssistance // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$codeAssistanceMenuItems*)
$codeAssistanceMenuItems = <|
    "Inline" :> FrontEnd`AddMenuCommands[
        "OpenHelpLink",
        {
            MenuItem[
                FrontEndResource[ "ChatbookStrings", "MenuItemShowCodeAssistanceInline" ],
                FrontEnd`KernelExecute[
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ShowCodeAssistance" ][ "Inline" ]
                ],
                FrontEnd`MenuEvaluator -> Automatic,
                FrontEnd`MenuKey[ "'", FrontEnd`Modifiers -> { "Control", "Shift" } ]
            ]
        }
    ],

    "Window" :> FrontEnd`AddMenuCommands[
        "OpenHelpLink",
        {
            MenuItem[
                FrontEndResource[ "ChatbookStrings", "MenuItemShowCodeAssistanceWindow" ],
                FrontEnd`KernelExecute[
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ShowCodeAssistance" ][ "Window", "NewChat" -> True ]
                ],
                FrontEnd`MenuEvaluator -> Automatic,
                Evaluate[
                    If[ $OperatingSystem === "MacOSX",
                        FrontEnd`MenuKey[ "'", FrontEnd`Modifiers -> { "Control" } ],
                        FrontEnd`MenuKey[ "'", FrontEnd`Modifiers -> { "Command" } ]
                    ]
                ]
            ]
        }
    ],

    "ContentSuggestions" :> FrontEnd`AddMenuCommands[
        "DuplicatePreviousOutput",
        {
            MenuItem[
                FrontEndResource[ "ChatbookStrings", "MenuItemShowContentSuggestions" ],
                FrontEnd`KernelExecute[
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ShowContentSuggestions" ][ ]
                ],
                FrontEnd`MenuEvaluator -> Automatic,
                Evaluate[
                    If[ $OperatingSystem === "MacOSX",
                        FrontEnd`MenuKey[ "k", FrontEnd`Modifiers -> { "Control" } ],
                        FrontEnd`MenuKey[ "k", FrontEnd`Modifiers -> { "Command" } ]
                    ]
                ],
                Method -> "Queued"
            ]
        }
    ]
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*enableCodeAssistance*)
enableCodeAssistance // beginDefinition;
enableCodeAssistance[ k: { $$codeAssistanceMenuItem.. } ] := FrontEndExecute @ Lookup[ $codeAssistanceMenuItems, k ];
enableCodeAssistance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowCodeAssistance*)
ShowCodeAssistance // beginDefinition;
ShowCodeAssistance // Options = {
    "ChatNotebookSettings" -> <| |>,
    "EvaluateInput"        -> False,
    "ExtraInstructions"    -> None,
    "Input"                -> None,
    "NewChat"              -> Automatic
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)
Chatbook::MissingCodeAssistanceInput = "No code assistance input defined for key `1`.";
Chatbook::InvalidExtraInstructions   = "Expected a string or None instead of `1` for ExtraInstructions.";

GeneralUtilities`SetUsage[ ShowCodeAssistance, "\
ShowCodeAssistance[] shows code assistance in a new or existing window.
ShowCodeAssistance[\"type$\"] shows code assistance of the specified type for the currently selected notebook.
ShowCodeAssistance[obj$, \"type$\"] shows code assistance of the specified type for the given front end object obj$.

* The value for \"type$\" can be \"Window\", \"Inline\", or Automatic.
* The value for obj$ can be a NotebookObject or a CellObject.
* The default value for \"type$\" is \"Window\" when obj$ is a NotebookObject, and \"Inline\" for a CellObject.
* ShowCodeAssistance accepts the following options:
| EvaluateInput     | False     | Whether to evaluate the initial chat input                                      |
| ExtraInstructions | None      | Additional instructions to include in the system prompt for the LLM             |
| Input             | None      | The initial chat input string or Key[\"name$\"] to reference a predefined input |
| NewChat           | Automatic | Whether to start a new chat                                                     |
* If EvaluateInput is True, a value must be given for Input or InputName.
* Specifying NewChat \[Rule] True will clear the existing code assistance chat (if any).
* The setting for NewChat has no effect for Inline code assistance.
* Possible values for \"name$\" in Key[\"name$\"] can be found in Keys[$CodeAssistanceInputs].\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Defaults*)

(* The zero argument form uses "Window" by default: *)
ShowCodeAssistance[ opts: OptionsPattern[ ] ] :=
    catchMine @ ShowCodeAssistance[ "Window", opts ];

(* Uses "Window" if given a NotebookObject: *)
ShowCodeAssistance[ nbo_NotebookObject, opts: OptionsPattern[ ] ] :=
    catchMine @ ShowCodeAssistance[ nbo, "Window", opts ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Window*)
ShowCodeAssistance[ "Window", opts: OptionsPattern[ ] ] :=
    catchMine @ LogChatTiming @ withChatState @ LogChatTiming @ ShowCodeAssistance[
        LogChatTiming @ getUserNotebook[ ],
        "Window",
        opts
    ];

ShowCodeAssistance[ nbo: _NotebookObject|None, "Window"|Automatic, opts: OptionsPattern[ ] ] :=
    catchMine @ withChatState @ withExtraInstructions[
        OptionValue[ "ExtraInstructions" ],
        LogChatTiming @ showCodeAssistanceWindow[
            nbo,
            LogChatTiming @ validateOptionInput @ OptionValue[ "Input" ],
            OptionValue[ "EvaluateInput" ],
            OptionValue[ "NewChat" ],
            OptionValue[ "ChatNotebookSettings" ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Inline*)
ShowCodeAssistance[ "Inline", opts: OptionsPattern[ ] ] :=
    catchMine @ withChatState @ LogChatTiming @ ShowCodeAssistance[ InputNotebook[ ], "Inline", opts ];

ShowCodeAssistance[ nbo_NotebookObject, "Inline", opts: OptionsPattern[ ] ] :=
    catchMine @ withChatState @ withExtraInstructions[
        OptionValue[ "ExtraInstructions" ],
        showCodeAssistanceInline[
            nbo,
            LogChatTiming @ validateOptionInput @ OptionValue[ "Input" ],
            OptionValue[ "EvaluateInput" ],
            OptionValue[ "ChatNotebookSettings" ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*From CellObjects*)

(* A CellObject uses "Inline" by default: *)
ShowCodeAssistance[ cell_CellObject, opts: OptionsPattern[ ] ] :=
    catchMine @ ShowCodeAssistance[ cell, "Inline", opts ];

(* If given a CellObject, move selection to the cell, then use "Inline" on the parent notebook: *)
ShowCodeAssistance[ cell0_CellObject, "Inline"|Automatic, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    withChatState @ Module[ { cell, nbo },
        (* Use the top-level parent in case cell0 is an attached or inline cell: *)
        cell = ConfirmMatch[ topParentCell @ cell0, _CellObject, "Cell" ];
        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "Notebook" ];
        SelectionMove[ cell, All, Cell ];
        ShowCodeAssistance[ nbo, "Inline", opts ]
    ],
    throwInternalFailure
];

(* If given a CellObject, use "Window" on the parent notebook: *)
ShowCodeAssistance[ cell_CellObject, "Window", opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    withChatState @ Module[ { nbo },
        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "Notebook" ];
        ShowCodeAssistance[ nbo, "Window", opts ]
    ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Named Aliases*)
$aliasRules = <|
    "ErrorMessage" -> <|
        "DefaultObject" :> EvaluationCell[ ],
        "Type"          -> "Inline",
        "Options"       -> <|
            "Input"         -> Key[ "ErrorMessage" ],
            "EvaluateInput" -> True
        |>
    |>,
    "GettingStarted" -> <|
        "DefaultObject" :> EvaluationNotebook[ ],
        "Type"          -> "Window",
        "Options"       -> <|
            "Input"                -> Key[ "GettingStarted" ],
            "EvaluateInput"        -> True,
            "NewChat"              -> True,
            "ChatNotebookSettings" -> <| "MinimumResponsesToSave" -> 2 |>
        |>
    |>
|>;

$$alias        = Alternatives @@ Keys @ $aliasRules;
$$specialAlias = Alternatives[ "CellInsertionPoint" ];


ShowCodeAssistance[ alias: $$specialAlias, opts: OptionsPattern[ ] ] :=
    catchMine @ ShowCodeAssistance[ Automatic, alias, opts ];


ShowCodeAssistance[ obj_, alias: $$specialAlias, opts: OptionsPattern[ ] ] :=
    catchMine @ Enclose[
        ConfirmMatch[ autoShowCodeAssistance[ alias, obj, opts ], Null|_NotebookObject|_CellObject, "AutoShow" ],
        throwInternalFailure
    ];


ShowCodeAssistance[ alias: $$alias, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    ShowCodeAssistance[
        ConfirmMatch[ $aliasRules[ alias, "DefaultObject" ], _CellObject|_NotebookObject, "DefaultObject" ],
        alias,
        opts
    ],
    throwInternalFailure
];


ShowCodeAssistance[ obj: _CellObject|_NotebookObject, alias: $$alias, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Module[ { type, options },
        type = ConfirmMatch[ $aliasRules[ alias, "Type" ], "Window"|"Inline", "Type" ];
        options = ConfirmBy[ $aliasRules[ alias, "Options" ], AssociationQ, "Options" ];
        ShowCodeAssistance[ obj, type, opts, Sequence @@ Normal[ options, Association ] ]
    ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*End Definition*)
ShowCodeAssistance // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*autoShowCodeAssistance*)
autoShowCodeAssistance // beginDefinition;

autoShowCodeAssistance[ "CellInsertionPoint", obj0_, opts: OptionsPattern[ ] ] := Enclose[
    Catch @ Module[ { nbo, cells, obj },
        nbo = ConfirmMatch[ EvaluationNotebook[ ], _NotebookObject, "Notebook" ];
        cells = ConfirmMatch[ Cells @ nbo, { ___CellObject }, "Cells" ];
        obj = ConfirmMatch[ If[ obj0 === Automatic, nbo, obj0 ], _CellObject|_NotebookObject, "Object" ];

        (* It's an empty notebook, so start workspace chat with the getting started prompt: *)
        If[ cells === { }, Throw @ ShowCodeAssistance[ obj, "GettingStarted", opts ] ];

        (* Otherwise open an inline chat without initial evaluation: *)
        SelectionMove[ nbo, Previous, Cell ];
        ShowCodeAssistance[ obj, "Inline", opts ]
    ],
    throwInternalFailure
];

autoShowCodeAssistance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withExtraInstructions*)
withExtraInstructions // beginDefinition;
withExtraInstructions // Attributes = { HoldRest };

withExtraInstructions[ instructions: $$string, eval_ ] :=
    Block[ { $codeAssistanceExtraInstructions = instructions },
        needsBasePrompt[ "CodeAssistanceExtraInstructions" ];
        eval
    ];

withExtraInstructions[ None, eval_ ] :=
    eval;

withExtraInstructions[ other_, eval_ ] :=
    throwFailure[ "InvalidExtraInstructions", other ];

withExtraInstructions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateOptionInput*)
validateOptionInput // beginDefinition;

validateOptionInput[ input: $$string | None ] :=
    input;

validateOptionInput[ Key[ name_String ] ] :=
    With[ { input = getCodeAssistanceInput @ name },
        If[ StringQ @ input,
            input,
            throwFailure[ "MissingCodeAssistanceInput", name ]
        ]
    ];

validateOptionInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Code Assistance*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showCodeAssistanceInline*)
showCodeAssistanceInline // beginDefinition;

showCodeAssistanceInline[ nbo_NotebookObject, input_, evaluate_, settings0_Association ] := Enclose[
    Module[ { settings, attached },

        settings = ConfirmBy[
            mergeChatSettings @ { $codeAssistanceInlineSettings, settings0 },
            AssociationQ,
            "Settings"
        ];

        attached = attachInlineChatInput[ nbo, settings ];

        setInlineInputAndEvaluate[ attached, input, evaluate ]
    ],
    throwInternalFailure
];

showCodeAssistanceInline[ _ ] :=
    Beep[ "No notebook selected for code assistance." ];

showCodeAssistanceInline // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setInlineInputAndEvaluate*)
setInlineInputAndEvaluate // beginDefinition;

setInlineInputAndEvaluate[ attached_CellObject, input_, evaluate_ ] := (
    If[ StringQ @ input, CurrentValue[ attached, { TaggingRules, "ChatInputString" } ] = input ];
    If[ TrueQ @ evaluate, evaluateAttachedInlineChat[ ] ];
    attached
);

setInlineInputAndEvaluate[ Null, input_, evaluate_ ] :=
    Null;

setInlineInputAndEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Code Assistance Window*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showCodeAssistanceWindow*)
showCodeAssistanceWindow // beginDefinition;

showCodeAssistanceWindow[ source_, input_, evaluate_, new_, settings_Association ] :=
    Block[ { $codeAssistanceWorkspaceSettings = mergeChatSettings @ { $codeAssistanceWorkspaceSettings, settings } },
        showCodeAssistanceWindow[ source, input, evaluate, new ]
    ];

showCodeAssistanceWindow[ source_NotebookObject, input_, evaluate_, new_ ] := Enclose[
    Module[ { current, nbo },

        current = ConfirmMatch[
            LogChatTiming @ findCurrentWorkspaceChat[ ],
            _NotebookObject | Missing[ "NotFound" ],
            "Existing"
        ];

        If[ TrueQ @ new,
            Quiet @ NotebookClose @ current;
            current = Missing[ "NotFound" ]
        ];

        nbo = If[ MissingQ @ current,
                  ConfirmMatch[ LogChatTiming @ createWorkspaceChat @ source, _NotebookObject, "New" ],
                  ConfirmMatch[ LogChatTiming @ attachToLeft[ source, current ], _NotebookObject, "Attached" ]
              ];

        LogChatTiming @ setWindowInputAndEvaluate[ nbo, input, evaluate ]
    ],
    throwInternalFailure
];


showCodeAssistanceWindow[ None, input_, evaluate_, new_ ] := Enclose[
    Module[ { current, nbo },
        current = ConfirmMatch[ findCurrentWorkspaceChat[ ], _NotebookObject | Missing[ "NotFound" ], "Existing" ];

        If[ TrueQ @ new,
            Quiet @ NotebookClose @ current;
            current = Missing[ "NotFound" ]
        ];

        nbo = If[ MissingQ @ current,
                  ConfirmMatch[ createWorkspaceChat[ ], _NotebookObject, "New" ],
                  current
              ];

        setWindowInputAndEvaluate[ nbo, input, evaluate ]
    ],
    throwInternalFailure
];


showCodeAssistanceWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setWindowInputAndEvaluate*)
setWindowInputAndEvaluate // beginDefinition;

setWindowInputAndEvaluate[ nbo_NotebookObject, input_, evaluate_ ] := (
    If[ StringQ @ input,
        CurrentValue[ nbo, { TaggingRules, "ChatInputString" } ] = input;
    ];

    If[ TrueQ @ evaluate,
        ChatbookAction[
            "EvaluateWorkspaceChat",
            nbo,
            Dynamic @ CurrentValue[ nbo, { TaggingRules, "ChatInputString" } ]
        ]
    ];

    nbo
);

setWindowInputAndEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachToLeft*)
attachToLeft // beginDefinition;

attachToLeft[ source_NotebookObject, current_NotebookObject ] := Enclose[
    Module[ { mag, width, margins, left, bottom, top },

        mag     = Replace[ AbsoluteCurrentValue[ source, Magnification ], Except[ _? NumberQ ] :> 1.0 ];
        width   = Ceiling @ ConfirmBy[ $workspaceChatWidth * mag, NumberQ, "Width" ];
        margins = ConfirmMatch[ windowMargins @ source, { { _, _ }, { _, _ } }, "Margins" ];

        left   = margins[[ 1, 1 ]];
        bottom = margins[[ 2, 1 ]];
        top    = margins[[ 2, 2 ]];

        If[ NonPositive[ left - width ],
            left   = width;
            bottom = bottom;
            top    = top;
        ];

        SetOptions[
            current,
            Magnification -> 0.85 * mag,
            WindowMargins -> { { left - width, Automatic }, { bottom, top } },
            WindowSize    -> { width, Automatic }
        ];

        SetSelectedNotebook @ current;
        moveToChatInputField[ current, True ];

        current
    ],
    throwInternalFailure
];

attachToLeft // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*windowMargins*)
windowMargins // beginDefinition;
windowMargins[ nbo_NotebookObject ] := windowMargins[ nbo, AbsoluteCurrentValue[ nbo, WindowMargins ] ];
windowMargins[ nbo_, margins: { { _, _ }, { _, _ } } ] := margins;
windowMargins[ nbo_, margins_? NumberQ ] := { { margins, margins }, { margins, margins } };
windowMargins // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*findCurrentWorkspaceChat*)
findCurrentWorkspaceChat // beginDefinition;

findCurrentWorkspaceChat[ ] := FirstCase[
    selectByCurrentValue[ Notebooks[ ], { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" }, "Absolute" -> True ],
    _NotebookObject,
    Missing[ "NotFound" ]
];

findCurrentWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateWorkspaceChat*)
CreateWorkspaceChat // beginDefinition;
CreateWorkspaceChat[ ] := catchMine @ LogChatTiming @ createWorkspaceChat[ ];
CreateWorkspaceChat[ nbo_NotebookObject ] := catchMine @ LogChatTiming @ createWorkspaceChat @ nbo;
CreateWorkspaceChat // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createWorkspaceChat*)
createWorkspaceChat // beginDefinition;

createWorkspaceChat[ ] :=
    createWorkspaceChat[ { } ];

createWorkspaceChat[ cells: { ___Cell } ] := Enclose[
    Module[ { nbo },
        nbo = ConfirmMatch[
            NotebookPut @ Notebook[ cells, $workspaceChatNotebookOptions ],
            _NotebookObject,
            "Notebook"
        ];
        (* Do we need to move to input field here? *)
        SetOptions[
            nbo,
            WindowMargins -> { { 0, Automatic }, { Automatic, 0 } },
            WindowSize    -> { $workspaceChatWidth, Automatic }
        ];

        nbo
    ],
    throwInternalFailure
];

createWorkspaceChat[ source_NotebookObject ] :=
    createWorkspaceChat[ source, { } ];

createWorkspaceChat[ source_NotebookObject, cells: { ___Cell } ] := Enclose[
    Module[ { nbo },

        nbo = ConfirmMatch[
            NotebookPut @ Notebook[ cells, $workspaceChatNotebookOptions ],
            _NotebookObject,
            "Notebook"
        ];

        (* Do we need to move to input field here? *)
        ConfirmMatch[ attachToLeft[ source, nbo ], _NotebookObject, "Attached" ]
    ],
    throwInternalFailure
];

createWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
