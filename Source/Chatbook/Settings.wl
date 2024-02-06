(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Settings`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `$defaultChatSettings;
    `currentChatSettings;
    `getPrecedingDelimiter;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`FrontEnd`"          ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$cloudInheritanceFix := $cloudNotebooks && ! PacletNewerQ[ $CloudVersionNumber, "1.67.1" ];

(* cSpell: ignore AIAPI *)
$defaultChatSettings = <|
    "Assistance"                -> Automatic,
    "AutoFormat"                -> True,
    "BasePrompt"                -> Automatic,
    "ChatContextPreprompt"      -> Automatic,
    "ChatDrivenNotebook"        -> False,
    "ChatHistoryLength"         -> 100,
    "ChatInputIndicator"        -> Automatic,
    "DynamicAutoFormat"         -> Automatic,
    "EnableChatGroupSettings"   -> False,
    "EnableLLMServices"         -> Automatic, (* TODO: remove this once LLMServices is widely available *)
    "FrequencyPenalty"          -> 0.1,
    "HandlerFunctions"          :> $DefaultChatHandlerFunctions,
    "HandlerFunctionsKeys"      -> Automatic,
    "IncludeHistory"            -> Automatic,
    "InitialChatCell"           -> True,
    "LLMEvaluator"              -> "CodeAssistant",
    "MaxCellStringLength"       -> Automatic,
    "MaxContextTokens"          -> Automatic,
    "MaxOutputCellStringLength" -> Automatic,
    "MaxTokens"                 -> Automatic,
    "MergeMessages"             -> True,
    "Model"                     :> $DefaultModel,
    "Multimodal"                -> Automatic,
    "NotebookWriteMethod"       -> Automatic,
    "OpenAIAPICompletionURL"    -> "https://api.openai.com/v1/chat/completions",
    "OpenAIKey"                 -> Automatic, (* TODO: remove this once LLMServices is widely available *)
    "PresencePenalty"           -> 0.1,
    "ProcessingFunctions"       :> $DefaultChatProcessingFunctions,
    "Prompts"                   -> { },
    "ShowMinimized"             -> Automatic,
    "StreamingOutputMethod"     -> Automatic,
    "Temperature"               -> 0.7,
    "Tokenizer"                 -> Automatic,
    "ToolCallFrequency"         -> Automatic,
    "ToolOptions"               :> $DefaultToolOptions,
    "Tools"                     -> Automatic,
    "ToolSelectionType"         -> <| |>,
    "ToolsEnabled"              -> Automatic,
    "TopP"                      -> 1,
    "TrackScrollingWhenPlaced"  -> Automatic,
    "VisiblePersonas"           -> $corePersonaNames
|>;

$cachedGlobalSettings := $cachedGlobalSettings = getGlobalSettingsFile[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Argument Patterns*)
$$validRootSettingValue = Inherited | _? (AssociationQ@*Association);
$$frontEndObject        = HoldPattern[ $FrontEnd | _FrontEndObject ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Defaults*)
$ChatAbort    = None;
$ChatPost     = None;
$ChatPre      = None;
$DefaultModel = <| "Service" -> "OpenAI", "Name" -> "gpt-4" |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Handler Functions*)
$DefaultChatHandlerFunctions = <|
    "ChatAbort" :> $ChatAbort,
    "ChatPost"  :> $ChatPost,
    "ChatPre"   :> $ChatPre
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Processing Functions*)
$DefaultChatProcessingFunctions = <|
    "CellToChatMessage"   -> CellToChatMessage,
    "ChatMessages"        -> (#1 &),
    "ChatSubmit"          -> Automatic,
    "FormatChatOutput"    -> FormatChatOutput,
    "FormatToolCall"      -> FormatToolCall,
    "WriteChatOutputCell" -> WriteChatOutputCell
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentChatSettings*)

(* TODO: need to support something like CurrentChatSettings[scope, {"key1", "key2", ...}] for nested values *)

GeneralUtilities`SetUsage[ CurrentChatSettings, "\
CurrentChatSettings[obj$, \"key$\"] gives the current chat settings for the CellObject or NotebookObject obj$ for the specified key.
CurrentChatSettings[obj$] gives all current chat settings for obj$.
CurrentChatSettings[] is equivalent to CurrentChatSettings[EvaluationCell[]].
CurrentChatSettings[\"key$\"] is equivalent to CurrentChatSettings[EvaluationCell[], \"key$\"].\
" ];

CurrentChatSettings[ ] := catchMine @
    If[ TrueQ @ $Notebooks,
        CurrentChatSettings @ $currentEvaluationObject,
        $defaultChatSettings
    ];

CurrentChatSettings[ key_String ] := catchMine @
    If[ TrueQ @ $Notebooks,
        CurrentChatSettings[ $currentEvaluationObject, key ],
        Lookup[ $defaultChatSettings, key, Inherited ]
    ];

CurrentChatSettings[ cell_CellObject ] := catchMine @
    With[ { parent = Quiet @ parentCell @ cell },
        If[ MatchQ[ parent, Except[ cell, _CellObject ] ],
            CurrentChatSettings @ parent,
            currentChatSettings @ cell
        ]
    ];

CurrentChatSettings[ cell_CellObject, key_String ] := catchMine @
    With[ { parent = Quiet @ parentCell @ cell },
        If[ MatchQ[ parent, Except[ cell, _CellObject ] ],
            CurrentChatSettings[ parent, key ],
            currentChatSettings[ cell, key ]
        ]
    ];

CurrentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] := catchMine @
    If[ TrueQ @ $Notebooks,
        currentChatSettings @ obj,
        $defaultChatSettings
    ];

CurrentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := catchMine @
    If[ TrueQ @ $Notebooks,
        currentChatSettings[ obj, key ],
        Lookup[ $defaultChatSettings, key, Inherited ]
    ];

CurrentChatSettings[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", CurrentChatSettings, HoldForm @ CurrentChatSettings @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UpValues*)
CurrentChatSettings /: HoldPattern @ Set[ CurrentChatSettings[ args___ ], value_ ] :=
    catchTop[ setCurrentChatSettings[ args, value ], CurrentChatSettings ];

CurrentChatSettings /: HoldPattern @ Unset[ CurrentChatSettings[ args___ ] ] :=
    catchTop[ unsetCurrentChatSettings @ args, CurrentChatSettings ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setCurrentChatSettings*)
setCurrentChatSettings // beginDefinition;
setCurrentChatSettings[ args___ ] /; $CloudEvaluation := setCurrentChatSettings0 @ args;
setCurrentChatSettings[ args___ ] := UsingFrontEnd @ setCurrentChatSettings0 @ args;
setCurrentChatSettings // endDefinition;


setCurrentChatSettings0 // beginDefinition;

(* Root settings: *)
setCurrentChatSettings0[ value: $$validRootSettingValue ] :=
    setCurrentChatSettings1[ $FrontEnd, value ];

setCurrentChatSettings0[ obj: $$feObj, value: $$validRootSettingValue ] :=
    setCurrentChatSettings1[ obj, value ];

(* Key settings: *)
setCurrentChatSettings0[ key_String? StringQ, value_ ] :=
    setCurrentChatSettings1[ $FrontEnd, key, value ];

setCurrentChatSettings0[ obj: $$feObj, key_String? StringQ, value_ ] :=
    setCurrentChatSettings1[ obj, key, value ];

(* Invalid scope: *)
setCurrentChatSettings0[ obj: Except[ $$feObj ], a__ ] := throwFailure[
    "InvalidFrontEndScope",
    obj,
    CurrentChatSettings,
    HoldForm @ setCurrentChatSettings0[ obj, a ]
];

(* Invalid key: *)
setCurrentChatSettings0[ obj: $$feObj, key_, value_ ] := throwFailure[
    "InvalidSettingsKey",
    key,
    CurrentChatSettings,
    HoldForm @ setCurrentChatSettings0[ obj, key, value ]
];

(* Invalid root settings: *)
setCurrentChatSettings0[ value: Except[ $$validRootSettingValue ] ] := throwFailure[
    "InvalidRootSettings",
    value,
    CurrentChatSettings,
    HoldForm @ setCurrentChatSettings0 @ value
];

setCurrentChatSettings0[ obj: $$feObj, value: Except[ $$validRootSettingValue ] ] := throwFailure[
    "InvalidRootSettings",
    value,
    CurrentChatSettings,
    HoldForm @ setCurrentChatSettings0 @ value
];

setCurrentChatSettings0 // endDefinition;


setCurrentChatSettings1 // beginDefinition;

setCurrentChatSettings1[ scope: $$feObj, Inherited ] :=
    If[ TrueQ @ $CloudEvaluation,
        setCurrentChatSettingsCloud[ scope, Inherited ],
        CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = Inherited
    ];

setCurrentChatSettings1[ scope: $$feObj, value_ ] :=
    With[ { as = Association @ value },
        If[ TrueQ @ $CloudEvaluation,
            setCurrentChatSettingsCloud[ scope, as ],
            CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = as
        ] /; AssociationQ @ as
    ];

setCurrentChatSettings1[ scope: $$feObj, key_String? StringQ, value_ ] :=
    If[ TrueQ @ $CloudEvaluation,
        setCurrentChatSettingsCloud[ scope, key, value ],
        CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", key } ] = value
    ];

setCurrentChatSettings1 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setCurrentChatSettingsCloud*)
setCurrentChatSettingsCloud // beginDefinition;

setCurrentChatSettingsCloud[ scope: $$frontEndObject, value_ ] :=
    With[ { as = Association @ value },
        (
            setGlobalChatSettings @ as;
            CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = as
        ) /; AssociationQ @ as
    ];

setCurrentChatSettingsCloud[ scope: $$frontEndObject, Inherited ] := (
    setGlobalChatSettings @ Inherited;
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = Inherited
);

setCurrentChatSettingsCloud[ scope: $$frontEndObject, key_String? StringQ, value_ ] := (
    setGlobalChatSettings[ key, value ];
    Needs[ "GeneralUtilities`" -> None ];
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", key } ] = value;
    CurrentValue[ scope, TaggingRules ] = GeneralUtilities`ToAssociations @ CurrentValue[ scope, TaggingRules ];
    value
);

setCurrentChatSettingsCloud[ scope: $$feObj, value_ ] :=
    With[ { as = Association @ value },
        (CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = as) /; AssociationQ @ as
    ];

setCurrentChatSettingsCloud[ scope: $$feObj, Inherited ] := (
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = Inherited
);

setCurrentChatSettingsCloud[ scope: $$feObj, key_String? StringQ, value_ ] := (
    Needs[ "GeneralUtilities`" -> None ];
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", key } ] = value;
    CurrentValue[ scope, TaggingRules ] = GeneralUtilities`ToAssociations @ CurrentValue[ scope, TaggingRules ];
    value
);

setCurrentChatSettingsCloud // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setGlobalChatSettings*)
setGlobalChatSettings // beginDefinition;

setGlobalChatSettings[ Inherited ] :=
    storeGlobalSettings @ <| |>;

setGlobalChatSettings[ settings_Association? AssociationQ ] :=
    storeGlobalSettings @ settings;

setGlobalChatSettings[ key_String? StringQ, Inherited ] := Enclose[
    Module[ { settings },
        settings = ConfirmBy[ getGlobalSettingsFile[ ], AssociationQ, "ReadSettings" ];
        KeyDropFrom[ settings, key ];
        ConfirmBy[ storeGlobalSettings @ settings, StringQ, "StoreSettings" ];
        $cachedGlobalSettings = settings;
        Inherited
    ],
    throwInternalFailure
];

setGlobalChatSettings[ key_String? StringQ, value_ ] := Enclose[
    Module[ { settings },
        settings = ConfirmBy[ getGlobalSettingsFile[ ], AssociationQ, "ReadSettings" ];
        settings[ key ] = value;
        ConfirmBy[ storeGlobalSettings @ settings, StringQ, "StoreSettings" ];
        $cachedGlobalSettings = settings;
        value
    ],
    throwInternalFailure
];

setGlobalChatSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getGlobalChatSettings*)
getGlobalChatSettings // beginDefinition;

getGlobalChatSettings[ ] :=
    mergeChatSettings @ Flatten @ { $defaultChatSettings, getGlobalSettingsFile[ ] };

getGlobalChatSettings[ key_String? StringQ ] :=
    getGlobalChatSettings[ getGlobalChatSettings[ ], key ];

getGlobalChatSettings[ settings_Association? AssociationQ, key_String? StringQ ] :=
    Lookup[ settings, key, Lookup[ $defaultChatSettings, key, Inherited ] ];

getGlobalChatSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getGlobalSettingsFile*)
getGlobalSettingsFile // beginDefinition;

getGlobalSettingsFile[ ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ $globalSettingsFile, StringQ, "GlobalSettingsFile" ];
        $cachedGlobalSettings =
            If[ FileExistsQ @ file,
                ConfirmBy[ Developer`ReadWXFFile @ file, AssociationQ, "ReadSettings" ],
                <| |>
            ]
    ],
    Function[
        Quiet @ DeleteFile @ $globalSettingsFile;
        throwInternalFailure[ getGlobalSettingsFile[ ], ## ]
    ]
];

getGlobalSettingsFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*storeGlobalSettings*)
storeGlobalSettings // beginDefinition;

storeGlobalSettings[ settings_Association? AssociationQ ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ $globalSettingsFile, StringQ, "GlobalSettingsFile" ];
        ConfirmBy[ Developer`WriteWXFFile[ file, settings ], StringQ, "StoreSettings" ];
        $cachedGlobalSettings = settings;
        file
    ],
    throwInternalFailure
];

storeGlobalSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$globalSettingsFile*)
$globalSettingsFile := Enclose[
    Module[ { dir },
        dir  = ConfirmBy[ $ResourceInstallationDirectory, DirectoryQ, "ResourceInstallationDirectory" ];
        $globalSettingsFile = ConfirmBy[ FileNameJoin @ { dir, "GlobalChatSettings.wxf" }, StringQ, "File" ]
    ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unsetCurrentChatSettings*)
unsetCurrentChatSettings // beginDefinition;

(* Root settings: *)
unsetCurrentChatSettings[ ] := unsetCurrentChatSettings0 @ $FrontEnd;
unsetCurrentChatSettings[ obj: $$feObj ] := unsetCurrentChatSettings0 @ obj;

(* Key settings: *)
unsetCurrentChatSettings[ key_? StringQ ] := unsetCurrentChatSettings0[ $FrontEnd, key ];
unsetCurrentChatSettings[ obj: $$feObj, key_? StringQ ] := unsetCurrentChatSettings0[ obj, key ];

(* Invalid scope: *)
unsetCurrentChatSettings[ obj: Except[ $$feObj ], a___ ] := throwFailure[
    "InvalidFrontEndScope",
    obj,
    CurrentChatSettings,
    HoldForm @ unsetCurrentChatSettings[ obj, a ]
];

(* Invalid key: *)
unsetCurrentChatSettings[ obj: $$feObj, key_ ] := throwFailure[
    "InvalidSettingsKey",
    key,
    CurrentChatSettings,
    HoldForm @ unsetCurrentChatSettings[ obj, key ]
];

unsetCurrentChatSettings // endDefinition;

unsetCurrentChatSettings0 // beginDefinition;

(* FIXME: make this work in cloud *)
unsetCurrentChatSettings0[ obj: $$feObj ] :=
    (CurrentValue[ obj, { TaggingRules, "ChatNotebookSettings" } ] = Inherited);

unsetCurrentChatSettings0[ obj: $$feObj, key_? StringQ ] :=
    (CurrentValue[ obj, { TaggingRules, "ChatNotebookSettings" } ] = Inherited);

unsetCurrentChatSettings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentChatSettings*)
currentChatSettings // beginDefinition;

currentChatSettings[ fe: $$frontEndObject ] /; $cloudNotebooks :=
    getGlobalChatSettings[ ];

currentChatSettings[ fe: $$frontEndObject, key_String ] /; $cloudNotebooks :=
    getGlobalChatSettings[ key ];

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] := (
    verifyInheritance @ obj;
    currentChatSettings0 @ obj
);

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := (
    verifyInheritance @ obj;
    currentChatSettings0[ obj, key ]
);

currentChatSettings[ cell0_CellObject ] := Catch @ Enclose[
    Module[ { cell, cellInfo, styles, nbo, delimiter, settings },

        verifyInheritance @ cell0;

        cell     = cell0;
        cellInfo = ConfirmBy[ cellInformation @ cell, AssociationQ, "CellInformation" ];
        styles   = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings0 @ cell ];

        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];

        delimiter = ConfirmMatch[ getPrecedingDelimiter[ cell, nbo ], _CellObject|_Missing, "Delimiter" ];

        settings = Select[
            Map[ Association,
                 Flatten @ {
                    absoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ],
                    CurrentValue[ DeleteMissing @ { delimiter, cell }, { TaggingRules, "ChatNotebookSettings" } ]
                 }
            ],
            AssociationQ
        ];

        ConfirmBy[
            mergeChatSettings @ Flatten @ { $defaultChatSettings, $cachedGlobalSettings, settings },
            AssociationQ,
            "CombinedSettings"
        ]
    ],
    throwInternalFailure[ currentChatSettings @ cell0, ## ] &
];

currentChatSettings[ cell0_CellObject, key_String ] := Catch @ Enclose[
    Module[ { cell, cellInfo, styles, nbo, cells, delimiter, values },

        verifyInheritance @ cell0;

        cell     = cell0;
        cellInfo = ConfirmBy[ cellInformation @ cell, AssociationQ, "CellInformation" ];
        styles   = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings0[ cell, key ] ];

        nbo   = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];
        cells = ConfirmMatch[ Cells @ nbo, { __CellObject }, "ChatCells" ];

        (* There are apparently temporary mystery cells that get created that aren't in the root cell list which are
           then immediately removed. These inherit the style specified by `DefaultNewCellStyle`. In chat-driven
           notebooks, this is set to "ChatInput", which has a dynamic cell dingbat that needs to resolve
           `currentChatSettings`. In this case, we have special behavior here to prevent a failure. Since that new
           temporary cell doesn't get displayed anyway, we don't need to actually resolve the chat settings for it,
           so we just return a default value instead. Yes, this is an ugly hack.
        *)
        If[ And[ MemberQ[ styles, $$chatInputStyle ], (*It's a "ChatInput" cell*)
                 ! MemberQ[ cells, cell ], (*It's not in the list of cells*)
                 MatchQ[ CurrentValue[ nbo, DefaultNewCellStyle ], $$chatInputStyle ] (*Due to DefaultNewCellStyle*)
            ],
            Throw @ Lookup[ $cachedGlobalSettings, key, Lookup[ $defaultChatSettings, key, Inherited ] ]
        ];

        delimiter = ConfirmMatch[ getPrecedingDelimiter[ cell, nbo, cells ], _CellObject|_Missing, "Delimiter" ];

        values = CurrentValue[ DeleteMissing @ { cell, delimiter }, { TaggingRules, "ChatNotebookSettings", key } ];

        (* TODO: this should also use `mergeChatSettings` in case the values are associations *)
        FirstCase[
            values,
            Except[ Inherited ],
            Replace[
                absoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", key } ],
                Inherited :> Lookup[ $cachedGlobalSettings, key, Lookup[ $defaultChatSettings, key, Inherited ] ]
            ]
        ]
    ],
    throwInternalFailure[ currentChatSettings[ cell0, key ], ## ] &
];

currentChatSettings // endDefinition;


currentChatSettings0 // beginDefinition;

currentChatSettings0[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession ] :=
    Association[
        $defaultChatSettings,
        $cachedGlobalSettings,
        Replace[
            Association @ absoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings" } ],
            Except[ _? AssociationQ ] :> <| |>
        ]
    ];

currentChatSettings0[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := Replace[
    absoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", key } ],
    Inherited :> Lookup[ $cachedGlobalSettings, key, Lookup[ $defaultChatSettings, key, Inherited ] ]
];

currentChatSettings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*absoluteCurrentValue*)
absoluteCurrentValue // beginDefinition;

(* Workaround for AbsoluteCurrentValue not properly inheriting TaggingRules in cloud notebooks: *)
absoluteCurrentValue[ cell_CellObject, { TaggingRules, "ChatNotebookSettings" } ] /; $cloudInheritanceFix :=
    mergeChatSettings @ {
        Replace[
            Association @ AbsoluteCurrentValue[ parentNotebook @ cell, { TaggingRules, "ChatNotebookSettings" } ],
            Except[ _? AssociationQ ] -> <| |>
        ],
        Replace[
            Association @ AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ],
            Except[ _? AssociationQ ] -> <| |>
        ]
    };

absoluteCurrentValue[ cell_CellObject, { TaggingRules, "ChatNotebookSettings", key_ } ] /; $cloudInheritanceFix :=
    Replace[
        AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", key } ],
        Inherited :> AbsoluteCurrentValue[ parentNotebook @ cell, { TaggingRules, "ChatNotebookSettings", key } ]
    ];

absoluteCurrentValue[ args___ ] :=
    AbsoluteCurrentValue @ args;

absoluteCurrentValue // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeChatSettings*)
mergeChatSettings // beginDefinition;
mergeChatSettings[ a_List ] := mergeChatSettings0 @ a //. $mergeSettingsDispatch;
mergeChatSettings // endDefinition;

mergeChatSettings0 // beginDefinition;
mergeChatSettings0[ { a___, Inherited.., b___ } ] := mergeChatSettings0 @ { a, b };
mergeChatSettings0[ { a_? AssociationQ, b__? AssociationQ } ] := DeleteMissing @ Merge[ { a, b }, mergeChatSettings0 ];
mergeChatSettings0[ { a___, Except[ _? AssociationQ ].., b__? AssociationQ } ] := mergeChatSettings0 @ { a, b };
mergeChatSettings0[ { __, e: Except[ _? AssociationQ ] } ] := e;
mergeChatSettings0[ { e_ } ] := e;
mergeChatSettings0[ { } ] := Missing[ ];
mergeChatSettings0 // endDefinition;


$mergeSettingsDispatch := $mergeSettingsDispatch = Dispatch @ Flatten @ {
    DownValues @ mergeChatSettings0,
    HoldPattern @ Merge[ { a___, b_, b_, c___ }, mergeChatSettings0 ] :> Merge[ { a, b, c }, mergeChatSettings0 ],
    HoldPattern @ Merge[ { a_ }, mergeChatSettings0 ] :> a
};

(* TODO: need to apply special merging/inheritance for things like "Prompts" *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPrecedingDelimiter*)
getPrecedingDelimiter // beginDefinition;

getPrecedingDelimiter[ cell_CellObject ] :=
    getPrecedingDelimiter[ cell, parentNotebook @ cell ];

getPrecedingDelimiter[ cell_CellObject, nbo_NotebookObject ] :=
    getPrecedingDelimiter[ cell, nbo, Cells @ nbo ];

getPrecedingDelimiter[ cell_CellObject, nbo_, { before0___CellObject, cell_, ___ } ] :=
    Module[ { before, delimiterTest, pos },
        before = Reverse @ { before0 };
        delimiterTest = AbsoluteCurrentValue[ before, { TaggingRules, "ChatNotebookSettings", "ChatDelimiter" } ];
        pos = FirstPosition[ delimiterTest, True ];
        If[ MissingQ @ pos, Missing[ "NotAvailable" ], Extract[ before, pos ] ]
    ];

getPrecedingDelimiter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$currentEvaluationObject*)
$currentEvaluationObject := $FrontEndSession;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*verifyInheritance*)
verifyInheritance // beginDefinition;
verifyInheritance[ obj_ ] /; $SynchronousEvaluation || $cloudNotebooks := True;
verifyInheritance[ obj_? inheritingQ ] := True;
verifyInheritance[ obj: $$feObj ] := With[ { verified = verifyInheritance0 @ obj }, inheritingQ @ obj ];
verifyInheritance // endDefinition;


verifyInheritance0 // beginDefinition;

(* Repair tagging rules at top-level and set the inheritance flag: *)
verifyInheritance0[ fe_FrontEndObject ] := Enclose[
    Module[ { tags },

        tags = ConfirmMatch[
            trToAssociations @ CurrentValue[ fe, TaggingRules ],
            _? AssociationQ | Inherited,
            "Tags"
        ];

        CurrentValue[ fe, TaggingRules ] = tags;
        CurrentValue[ fe, { TaggingRules, "ChatNotebookSettings", "InheritanceTest" } ] = True;

        ConfirmBy[ CurrentValue[ fe, TaggingRules ], AssociationQ, "Verify" ]
    ],
    throwInternalFailure[ verifyInheritance0 @ fe, ## ] &
];

(* Otherwise, recurse upwards repairing tagging rules: *)
verifyInheritance0[ obj: Except[ _FrontEndObject, $$feObj ] ] :=
    Module[ { parent, tags },
        parent = feParentObject @ obj;
        tags   = verifyInheritance0 @ parent;
        repairTaggingRules[ obj, tags ]
    ];

verifyInheritance0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inheritingQ*)
inheritingQ // beginDefinition;

inheritingQ[ obj: $$feObj ] :=
    TrueQ @ Replace[
        AbsoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", "InheritanceTest" } ],
        $Failed -> True
    ];

inheritingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*repairTaggingRules*)
repairTaggingRules // beginDefinition;

repairTaggingRules[ box_BoxObject, parentTags_Association? AssociationQ ] := parentTags;

repairTaggingRules[ obj: $$feObj, parentTags_Association? AssociationQ ] := Enclose[
    Module[ { tags, keep },

        tags = ConfirmMatch[
            trToAssociations @ CurrentValue[ obj, TaggingRules ],
            _? AssociationQ | Inherited,
            "Tags"
        ];

        keep = ConfirmMatch[
            associationComplement[ tags, parentTags ],
            _? AssociationQ | Inherited,
            "Complement"
        ];

        If[ keep[ "ChatNotebookSettings", "InheritanceTest" ],
            keep[ "ChatNotebookSettings", "InheritanceTest" ] =.
        ];

        If[ keep === <| |>,
            CurrentValue[ obj, TaggingRules ] = Inherited,
            CurrentValue[ obj, TaggingRules ] = keep
        ]
    ],
    throwInternalFailure[ repairTaggingRules[ obj, parentTags ], ## ] &
];

repairTaggingRules // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*trToAssociations*)
trToAssociations // beginDefinition;
trToAssociations[ expr_ ] := Replace[ trToAssociations0 @ expr, { } | <| |> -> Inherited ];
trToAssociations // endDefinition;

trToAssociations0 // beginDefinition;

trToAssociations0[ as_Association? AssociationQ ] :=
    Replace[
        DeleteCases[ trToAssociations /@ as /. HoldPattern @ trToAssociations[ expr_ ] :> expr, <| |> | Inherited ],
        <| |> -> Inherited
    ];

trToAssociations0[ { rules: (Rule|RuleDelayed)[ _, _ ].. } ] :=
    trToAssociations0 @ Association @ rules;

trToAssociations0[ expr_ ] :=
    expr;

trToAssociations0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*associationComplement*)
associationComplement // beginDefinition;

associationComplement[ as1_? AssociationQ, as2_? AssociationQ ] :=
    Module[ { complement, common },
        complement = Complement[ as1, as2 ];
        common     = Intersection[ Keys @ complement, Keys @ as2 ];
        Scan[ Function[ complement[ # ] = associationComplement[ as1[ # ], as2[ # ] ] ], common ];
        complement
    ];

associationComplement[ as1: { (Rule|RuleDelayed)[ _, _ ]... }, as2_ ] :=
    associationComplement[ Association @ as1, as2 ];

associationComplement[ as1_, as2: { (Rule|RuleDelayed)[ _, _ ]... } ] :=
    associationComplement[ as1, Association @ as2 ];

associationComplement[ as_, _ ] := as;

associationComplement // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $mergeSettingsDispatch;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
