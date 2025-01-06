(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$workspaceChatWidth := $workspaceChatWidth = Switch[ $OperatingSystem, "MacOSX", 450, _, 360 ];

$notebookAssistanceBaseSettings = <|
    "AllowSelectionContext"     -> True,
    "AppName"                   -> "NotebookAssistance",
    "LLMEvaluator"              -> "NotebookAssistant",
    "MaxContextTokens"          -> 2^15,
    "MaxToolResponses"          -> 3,
    "Model"                     -> <| "Service" -> "LLMKit", "Name" -> Automatic |>,
    "PromptGenerators"          -> { "RelatedDocumentation" },
    "ServiceCaller"             -> "NotebookAssistance",
    "Tools"                     -> { "NotebookEditor" },
    "ToolSelectionType"         -> <| "DocumentationLookup" -> None, "DocumentationSearcher" -> None |>,
    "ToolOptions"               -> <|
        "WolframLanguageEvaluator" -> <| "AppendURIPrompt" -> True, "Method" -> "Session" |>
    |>
|>;

$notebookAssistanceWorkspaceSettings := <|
    $notebookAssistanceBaseSettings,
    "AutoGenerateTitle"     -> True,
    "AutoSaveConversations" -> True,
    "ConversationUUID"      -> CreateUUID[ ],
    "SetCellDingbat"        -> False,
    "TabbedOutput"          -> False,
    "WorkspaceChat"         -> True
|>;

$notebookAssistanceInlineSettings := <|
    $notebookAssistanceBaseSettings,
    "AutoGenerateTitle"     -> False,
    "AutoSaveConversations" -> False,
    "InlineChat"            -> True
|>;

$workspaceChatNotebookOptions := Sequence[
    DefaultNewCellStyle -> "AutoMoveToChatInputField",
    StyleDefinitions    -> FrontEnd`FileName[ { "Wolfram" }, "WorkspaceChat.nb", CharacterEncoding -> "UTF-8" ],
    TaggingRules        -> <|
        "ChatInputString"      -> "",
        "ChatNotebookSettings" -> $notebookAssistanceWorkspaceSettings,
        "ConversationTitle"    -> ""
    |>
];

(* TODO: set $serviceCaller from chat settings *)

$$notebookAssistanceMenuItem = "Inline"|"Window"|"ContentSuggestions";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EnableNotebookAssistance*)
EnableNotebookAssistance // beginDefinition;

EnableNotebookAssistance[ ] :=
    catchMine @ EnableNotebookAssistance @ Automatic;

EnableNotebookAssistance[ Automatic ] := catchMine @
    If[ $VersionNumber >= 14.1,
        enableNotebookAssistance @ { "Window", "ContentSuggestions" },
        enableNotebookAssistance @ { "Window" }
    ];

EnableNotebookAssistance[ keys: { $$notebookAssistanceMenuItem.. } ] :=
    catchMine @ enableNotebookAssistance @ DeleteDuplicates @ keys;

EnableNotebookAssistance[ key: $$notebookAssistanceMenuItem ] :=
    catchMine @ enableNotebookAssistance @ { key };

EnableNotebookAssistance // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$notebookAssistanceMenuItems*)
$notebookAssistanceMenuItems = <|
    "Inline" :> FrontEnd`AddMenuCommands[
        "OpenHelpLink",
        {
            MenuItem[
                FrontEndResource[ "ChatbookStrings", "MenuItemShowNotebookAssistanceInline" ],
                FrontEnd`KernelExecute[
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ShowNotebookAssistance" ][ "Inline" ]
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
                FrontEndResource[ "ChatbookStrings", "MenuItemShowNotebookAssistanceWindow" ],
                FrontEnd`KernelExecute[
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ShowNotebookAssistance" ][ "Window", "NewChat" -> True ]
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
(*enableNotebookAssistance*)
enableNotebookAssistance // beginDefinition;
enableNotebookAssistance[ k: { $$notebookAssistanceMenuItem.. } ] := FrontEndExecute @ Lookup[ $notebookAssistanceMenuItems, k ];
enableNotebookAssistance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowNotebookAssistance*)
ShowNotebookAssistance // beginDefinition;
ShowNotebookAssistance // Options = {
    "ChatNotebookSettings" -> <| |>,
    "EvaluateInput"        -> False,
    "ExtraInstructions"    -> None,
    "Input"                -> None,
    "NewChat"              -> Automatic
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)
Chatbook::MissingNotebookAssistanceInput = "No code assistance input defined for key `1`.";
Chatbook::InvalidExtraInstructions   = "Expected a string or None instead of `1` for ExtraInstructions.";

GeneralUtilities`SetUsage[ ShowNotebookAssistance, "\
ShowNotebookAssistance[] shows code assistance in a new or existing window.
ShowNotebookAssistance[\"type$\"] shows code assistance of the specified type for the currently selected notebook.
ShowNotebookAssistance[obj$, \"type$\"] shows code assistance of the specified type for the given front end object obj$.

* The value for \"type$\" can be \"Window\", \"Inline\", Automatic, or a string representing a predefined configuration.
* The value for obj$ can be a NotebookObject or a CellObject.
* The default value for \"type$\" is \"Window\" when obj$ is a NotebookObject, and \"Inline\" for a CellObject.
* ShowNotebookAssistance accepts the following options:
| EvaluateInput     | False     | Whether to evaluate the initial chat input                                      |
| ExtraInstructions | None      | Additional instructions to include in the system prompt for the LLM             |
| Input             | None      | The initial chat input string or Key[\"name$\"] to reference a predefined input |
| NewChat           | Automatic | Whether to start a new chat                                                     |
* If EvaluateInput is True, a value must be given for Input or InputName.
* Specifying NewChat \[Rule] True will clear the existing code assistance chat (if any).
* The setting for NewChat has no effect for Inline code assistance.
* Possible values for \"name$\" in Key[\"name$\"] can be found in Keys[$NotebookAssistanceInputs].\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Defaults*)

(* The zero argument form uses "Window" by default: *)
ShowNotebookAssistance[ opts: OptionsPattern[ ] ] :=
    catchMine @ ShowNotebookAssistance[ "Window", opts ];

(* Uses "Window" if given a NotebookObject: *)
ShowNotebookAssistance[ nbo_NotebookObject, opts: OptionsPattern[ ] ] :=
    catchMine @ ShowNotebookAssistance[ nbo, "Window", opts ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Window*)
ShowNotebookAssistance[ "Window", opts: OptionsPattern[ ] ] :=
    catchMine @ LogChatTiming @ withChatState @ LogChatTiming @ ShowNotebookAssistance[
        LogChatTiming @ getUserNotebook[ ],
        "Window",
        opts
    ];

ShowNotebookAssistance[ nbo: _NotebookObject|None, "Window"|Automatic, opts: OptionsPattern[ ] ] :=
    catchMine @ withChatState @ withExtraInstructions[
        OptionValue[ "ExtraInstructions" ],
        LogChatTiming @ showNotebookAssistanceWindow[
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
ShowNotebookAssistance[ "Inline", opts: OptionsPattern[ ] ] :=
    catchMine @ withChatState @ LogChatTiming @ ShowNotebookAssistance[ InputNotebook[ ], "Inline", opts ];

ShowNotebookAssistance[ nbo_NotebookObject, "Inline", opts: OptionsPattern[ ] ] :=
    catchMine @ withChatState @ withExtraInstructions[
        OptionValue[ "ExtraInstructions" ],
        showNotebookAssistanceInline[
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
ShowNotebookAssistance[ cell_CellObject, opts: OptionsPattern[ ] ] :=
    catchMine @ ShowNotebookAssistance[ cell, "Inline", opts ];

(* If given a CellObject, move selection to the cell, then use "Inline" on the parent notebook: *)
ShowNotebookAssistance[ cell0_CellObject, "Inline"|Automatic, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    withChatState @ Module[ { cell, nbo },
        (* Use the top-level parent in case cell0 is an attached or inline cell: *)
        cell = ConfirmMatch[ topParentCell @ cell0, _CellObject, "Cell" ];
        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "Notebook" ];
        SelectionMove[ cell, All, Cell ];
        ShowNotebookAssistance[ nbo, "Inline", opts ]
    ],
    throwInternalFailure
];

(* If given a CellObject, use "Window" on the parent notebook: *)
ShowNotebookAssistance[ cell_CellObject, "Window", opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    withChatState @ Module[ { nbo },
        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "Notebook" ];
        ShowNotebookAssistance[ nbo, "Window", opts ]
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
    |>,
    "NotebookToolbarInline" -> <|
        "DefaultObject" :> EvaluationNotebook[ ],
        "Type"          -> "Inline",
        "Options"       -> <| |>
    |>,
    "NotebookToolbarWindow" -> <|
        "DefaultObject" :> EvaluationNotebook[ ],
        "Type"          -> "Window",
        "Options"       -> <| "NewChat" -> True |>
    |>
|>;

$$alias        = Alternatives @@ Keys @ $aliasRules;
$$specialAlias = Alternatives[ "CellInsertionPoint" ];


ShowNotebookAssistance[ alias: $$specialAlias, opts: OptionsPattern[ ] ] :=
    catchMine @ ShowNotebookAssistance[ Automatic, alias, opts ];


ShowNotebookAssistance[ obj_, alias: $$specialAlias, opts: OptionsPattern[ ] ] :=
    catchMine @ Enclose[
        ConfirmMatch[ autoShowNotebookAssistance[ alias, obj, opts ], Null|_NotebookObject|_CellObject, "AutoShow" ],
        throwInternalFailure
    ];


ShowNotebookAssistance[ alias: $$alias, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    ShowNotebookAssistance[
        ConfirmMatch[ $aliasRules[ alias, "DefaultObject" ], _CellObject|_NotebookObject, "DefaultObject" ],
        alias,
        opts
    ],
    throwInternalFailure
];


ShowNotebookAssistance[ obj: _CellObject|_NotebookObject, alias: $$alias, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Module[ { type, options },
        type = ConfirmMatch[ $aliasRules[ alias, "Type" ], "Window"|"Inline", "Type" ];
        options = ConfirmBy[ $aliasRules[ alias, "Options" ], AssociationQ, "Options" ];
        ShowNotebookAssistance[ obj, type, opts, Sequence @@ Normal[ options, Association ] ]
    ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*End Definition*)
ShowNotebookAssistance // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*autoShowNotebookAssistance*)
autoShowNotebookAssistance // beginDefinition;

autoShowNotebookAssistance[ "CellInsertionPoint", obj0_, opts: OptionsPattern[ ] ] := Enclose[
    Catch @ Module[ { nbo, cells, obj },
        nbo = ConfirmMatch[ EvaluationNotebook[ ], _NotebookObject, "Notebook" ];
        cells = ConfirmMatch[ Cells @ nbo, { ___CellObject }, "Cells" ];
        obj = ConfirmMatch[ If[ obj0 === Automatic, nbo, obj0 ], _CellObject|_NotebookObject, "Object" ];

        (* It's an empty notebook, so start workspace chat with the getting started prompt: *)
        If[ cells === { }, Throw @ ShowNotebookAssistance[ obj, "GettingStarted", opts ] ];

        (* Otherwise open an inline chat without initial evaluation: *)
        SelectionMove[ nbo, Previous, Cell ];
        ShowNotebookAssistance[ obj, "Inline", opts ]
    ],
    throwInternalFailure
];

autoShowNotebookAssistance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withExtraInstructions*)
withExtraInstructions // beginDefinition;
withExtraInstructions // Attributes = { HoldRest };

withExtraInstructions[ instructions: $$string, eval_ ] :=
    Block[ { $notebookAssistanceExtraInstructions = instructions },
        needsBasePrompt[ "NotebookAssistanceExtraInstructions" ];
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
    With[ { input = getNotebookAssistanceInput @ name },
        If[ StringQ @ input,
            input,
            throwFailure[ "MissingNotebookAssistanceInput", name ]
        ]
    ];

validateOptionInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Notebook Assistance*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showNotebookAssistanceInline*)
showNotebookAssistanceInline // beginDefinition;

showNotebookAssistanceInline[ nbo_NotebookObject, input_, evaluate_, settings0_Association ] := Enclose[
    Module[ { settings, attached },

        settings = ConfirmBy[
            mergeChatSettings @ { $notebookAssistanceInlineSettings, settings0 },
            AssociationQ,
            "Settings"
        ];

        attached = attachInlineChatInput[ nbo, settings ];

        setInlineInputAndEvaluate[ attached, input, evaluate ]
    ],
    throwInternalFailure
];

showNotebookAssistanceInline[ _ ] :=
    Beep[ "No notebook selected for code assistance." ];

showNotebookAssistanceInline // endDefinition;

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
(*Notebook Assistance Window*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showNotebookAssistanceWindow*)
showNotebookAssistanceWindow // beginDefinition;

showNotebookAssistanceWindow[ source_, input_, evaluate_, new_, settings_Association ] :=
    Block[ { $notebookAssistanceWorkspaceSettings = mergeChatSettings @ { $notebookAssistanceWorkspaceSettings, settings } },
        showNotebookAssistanceWindow[ source, input, evaluate, new ]
    ];

showNotebookAssistanceWindow[ source_NotebookObject, input_, evaluate_, new_ ] := Enclose[
    Module[ { current, nbo, movedLastChatToSourcesIndicatorQ },

        current = ConfirmMatch[
            LogChatTiming @ findCurrentWorkspaceChat[ "NotebookAssistance" ],
            _NotebookObject | Missing[ "NotFound" ],
            "Existing"
        ];

        movedLastChatToSourcesIndicatorQ = MatchQ[ current, _NotebookObject ] && Cells[ current ] =!= {};

        If[ TrueQ @ new,
            Quiet @ NotebookClose @ current;
            current = Missing[ "NotFound" ]
        ];

        nbo = If[ MissingQ @ current,
                  ConfirmMatch[ LogChatTiming @ createWorkspaceChat @ source, _NotebookObject, "New" ],
                  ConfirmMatch[ LogChatTiming @ attachToLeft[ source, current ], _NotebookObject, "Attached" ]
              ];

        If[ movedLastChatToSourcesIndicatorQ,
            writeWorkspaceChatSubDockedCell[
                nbo,
                With[ { nbo = nbo },
                    Button[
                        MouseAppearance[
                            Style[
                                Row[ { trExprTemplate["WorkspaceToolbarSourcesSubTitleMoved"][ <| "1" -> chatbookIcon[ "WorkspaceToolbarIconHistorySmall", False ] |> ] } ],
                                "WorkspaceChatToolbarTitle", FontSlant -> Italic, FontWeight -> Plain
                            ],
                            "LinkHand"], (* using LinkHand to indicate the sub-docked cell is clickable *)
                        toggleOverlayMenu[ nbo, "History" ],
                        Appearance -> "Suppressed"
                    ]
                ]
            ]
        ];

        setNotebookAssistanceEvaluator @ nbo;

        LogChatTiming @ setWindowInputAndEvaluate[ nbo, input, evaluate ]
    ],
    throwInternalFailure
];


showNotebookAssistanceWindow[ None, input_, evaluate_, new_ ] := Enclose[
    Module[ { current, nbo },

        current = ConfirmMatch[
            findCurrentWorkspaceChat[ "NotebookAssistance" ],
            _NotebookObject | Missing[ "NotFound" ],
            "Existing"
        ];

        If[ TrueQ @ new,
            Quiet @ NotebookClose @ current;
            current = Missing[ "NotFound" ]
        ];

        nbo = If[ MissingQ @ current,
                  ConfirmMatch[ createWorkspaceChat[ ], _NotebookObject, "New" ],
                  current
              ];

        setNotebookAssistanceEvaluator @ nbo;

        setWindowInputAndEvaluate[ nbo, input, evaluate ]
    ],
    throwInternalFailure
];


showNotebookAssistanceWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setNotebookAssistanceEvaluator*)
setNotebookAssistanceEvaluator // beginDefinition;

setNotebookAssistanceEvaluator[ nbo_NotebookObject ] :=
    If[ AssociationQ @ Association @ CurrentValue[ nbo, { EvaluatorNames, "NotebookAssistance" } ],
        SetOptions[ nbo, Evaluator -> "NotebookAssistance" ]
    ];

setNotebookAssistanceEvaluator // endDefinition;

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
    Module[ { mag, width, margins, left, bottom, top, displayindex, displayleftedge },

        mag     = Replace[ AbsoluteCurrentValue[ source, Magnification ], Except[ _? NumberQ ] :> 1.0 ];
        width   = Ceiling @ ConfirmBy[ $workspaceChatWidth * mag, NumberQ, "Width" ];
        margins = ConfirmMatch[ windowMargins @ source, { { _, _ }, { _, _ } }, "Margins" ];
        
        displayindex = NotebookTools`NotebookDisplayIndex[source];
        displayleftedge = If[IntegerQ[displayindex],
            Replace[CurrentValue["ConnectedDisplays"][[displayindex]], {
                {___, "FullRegion" -> {{xmin_, _}, {_, _}}, ___} :> xmin,
                _ :> 0
            }],
            0
        ];

        left   = margins[[ 1, 1 ]];
        bottom = margins[[ 2, 1 ]];
        top    = margins[[ 2, 2 ]];

        left = left - width;
        If[ left < displayleftedge,
        	(* prevent the assistant from falling off the left edge of the display *)
        	left = displayleftedge;
        	(* Uncomment this to also slide the source notebook right, to avoid overlapping with the assistant *)
			(* SetOptions[source, WindowMargins -> ReplacePart[margins, {1,1} -> (left + width)]] *)
		];

        SetOptions[
            current,
            Magnification -> 0.85 * mag,
            WindowMargins -> { { left, Automatic }, { bottom, top } },
            WindowSize    -> { width, Automatic }
        ];

        If[ (* Starting in Mac 14.2, we can make sure the assistant notebook is on right "space". *)
            And[
                BoxForm`sufficientVersionQ[14.2],
                Internal`CachedSystemInformation["FrontEnd", "OperatingSystem"] === "MacOSX"
            ],
            FE`Evaluate @ Evaluate @ FEPrivate`MoveToActiveDesktop @ current
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


findCurrentWorkspaceChat[ ] :=
    findCurrentWorkspaceChat[ All, Notebooks[ ] ];


findCurrentWorkspaceChat[ appName_String ] :=
    findCurrentWorkspaceChat[ appName, Notebooks[ ] ];


findCurrentWorkspaceChat[ All | _String, { } ] :=
    Missing[ "NotFound" ];


findCurrentWorkspaceChat[ All, notebooks: { __NotebookObject } ] := FirstCase[
    selectByCurrentValue[ notebooks, { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" }, "Absolute" -> True ],
    _NotebookObject,
    Missing[ "NotFound" ]
];


findCurrentWorkspaceChat[ appName_String, notebooks: { __NotebookObject } ] := Enclose[
    Catch @ Module[ { wsNotebooks, appNotebooks },

        wsNotebooks = ConfirmMatch[
            selectByCurrentValue[
                notebooks,
                { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" },
                "Absolute" -> True
            ],
            { ___NotebookObject },
            "WorkspaceNotebooks"
        ];

        If[ wsNotebooks === { }, Throw @ Missing[ "NotFound" ] ];

        appNotebooks = ConfirmMatch[
            selectByCurrentValue[
                wsNotebooks,
                { TaggingRules, "ChatNotebookSettings", "AppName" },
                SameAs @ appName,
                "Absolute" -> True
            ],
            { ___NotebookObject },
            "AppNotebooks"
        ];

        FirstCase[ appNotebooks, _NotebookObject, Missing[ "NotFound" ] ]
    ]
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
(*Backwards Compatibility*)
ShowCodeAssistance = ShowNotebookAssistance;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
