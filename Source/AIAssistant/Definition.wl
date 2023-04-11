(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AIAssistant`" ];

AIAssistant // ClearAll;

System`MenuAnchor;
System`MenuItem;
System`RawInputForm;

Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
$inDef = False;
$debug = True;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*beginDefinition*)
beginDefinition // ClearAll;
beginDefinition // Attributes = { HoldFirst };
beginDefinition::Unfinished =
"Starting definition for `1` without ending the current one.";

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
beginDefinition[ s_Symbol ] /; $debug && $inDef :=
    WithCleanup[
        $inDef = False
        ,
        Print @ TemplateApply[ beginDefinition::Unfinished, HoldForm @ s ];
        beginDefinition @ s
        ,
        $inDef = True
    ];
(* :!CodeAnalysis::EndBlock:: *)

beginDefinition[ s_Symbol ] :=
    WithCleanup[ Unprotect @ s; ClearAll @ s, $inDef = True ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*endDefinition*)
endDefinition // beginDefinition;
endDefinition // Attributes = { HoldFirst };

endDefinition[ s_Symbol ] := endDefinition[ s, DownValues ];

endDefinition[ s_Symbol, None ] := $inDef = False;

endDefinition[ s_Symbol, DownValues ] :=
    WithCleanup[
        AppendTo[ DownValues @ s,
                  e: HoldPattern @ s[ ___ ] :>
                      throwInternalFailure @ HoldForm @ e
        ],
        $inDef = False
    ];

endDefinition[ s_Symbol, SubValues  ] :=
    WithCleanup[
        AppendTo[ SubValues @ s,
                  e: HoldPattern @ s[ ___ ][ ___ ] :>
                      throwInternalFailure @ HoldForm @ e
        ],
        $inDef = False
    ];

endDefinition[ s_Symbol, list_List ] :=
    endDefinition[ s, # ] & /@ list;

endDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section:: *)
(*Resources*)

(* ::**************************************************************************************************************:: *)
(* ::Section:: *)
(*Messages*)
AIAssistant::Internal =
"An unexpected error occurred. `1`";

AIAssistant::NoAPIKey =
"No API key defined.";

AIAssistant::InvalidAPIKey =
"Invalid value for API key: `1`";

AIAssistant::UnknownResponse =
"Unexpected response from OpenAI server";

AIAssistant::UnknownStatusCode =
"Unexpected response from OpenAI server with status code `StatusCode`";

AIAssistant::BadResponseMessage =
"`1`";

(* ::**************************************************************************************************************:: *)
(* ::Section:: *)
(*Options*)
AIAssistant // Options = Normal[ $defaultAIAssistantSettings, Association ];

(* ::**************************************************************************************************************:: *)
(* ::Section:: *)
(*Main definition*)
AIAssistant[ opts: OptionsPattern[ ] ] :=
    Module[ { nbo, result },
        WithCleanup[
            nbo = CreateWindow[ WindowTitle -> "Untitled Chat Notebook", Visible -> False ],
            result = catchTop @ AIAssistant[ nbo, opts ],
            If[ FailureQ @ result,
                NotebookClose @ nbo,
                SetOptions[ nbo, Visible -> True ];
                SetSelectedNotebook @ nbo
            ]
        ]
    ];

AIAssistant[ nbo_NotebookObject, opts: OptionsPattern[ ] ] :=
    catchTop @ Enclose @ Module[ { key, id, settings, options },
        $birdChatLoaded = True;
        key = ConfirmBy[ toAPIKey @ OptionValue[ "OpenAIKey" ], StringQ ];
        id = CreateUUID[ ];
        $apiKeys[ id ] = key;
        settings = makeAIAssistantSettings[ <| "ID" -> id |>, opts ];
        options = makeAIAssistantNotebookOptions @ settings;
        SetOptions[ nbo, options ];
        CurrentValue[ nbo, { TaggingRules, "AIAssistantSettings" } ] = settings;
        nbo
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Commands*)
AIAssistant[ command_String, args___ ] := catchTop @ executeAIAssistantCommand[ command, args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Assistant Settings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$promptTemplate*)
$promptTemplate = StringTemplate[ $promptStrings[ "Default" ], Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$promptComponents*)
$promptComponents = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Birdnardo*)
$promptComponents[ "Birdnardo" ] = <| |>;
$promptComponents[ "Birdnardo", "Pre"  ] = $promptStrings[ "Birdnardo/Pre"  ];
$promptComponents[ "Birdnardo", "Post" ] = $promptStrings[ "Birdnardo/Post" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Generic*)
$promptComponents[ "Generic" ] = <| |>;
$promptComponents[ "Generic", "Pre"  ] = $promptStrings[ "Generic/Pre" ];
$promptComponents[ "Generic", "Post" ] = "";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Wolfie*)
$promptComponents[ "Wolfie" ] = <| |>;
$promptComponents[ "Wolfie", "Pre"  ] = $promptStrings[ "Wolfie/Pre"  ];
$promptComponents[ "Wolfie", "Post" ] = $promptStrings[ "Wolfie/Post" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$defaultRolePrompt*)
$defaultRolePrompt = TemplateApply[ $promptTemplate, $promptComponents[ "Birdnardo" ] ];
$defaultRole = <| "role" -> "system", "content" -> $defaultRolePrompt |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*namedRolePrompt*)
namedRolePrompt // ClearAll;

namedRolePrompt[ name_String ] := Enclose[
    Module[ { pre, post },
        pre  = $promptComponents[ name, "Pre"  ];
        post = $promptComponents[ name, "Post" ];
        ConfirmBy[
            TemplateApply[
                $promptTemplate,
                DeleteMissing @ <| "Pre" -> pre, "Post" -> post |>
            ],
            StringQ
        ]
    ],
    $defaultRolePrompt &
];

namedRolePrompt[ ___ ] := $defaultRolePrompt;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Appearance*)
$birdFontSize = 14;
$birdList := $birdList = ResourceFunction[ "PartyParrot" ][ "Birdnardo", "ImageList" ];
$birdIcon := $birdIcon = $birdList[[ 6 ]];
$defaultAssistantIcon := $defaultAssistantIcon = Magnify[ ImageResize[ $birdIcon, Scaled[ 0.5 ] ], 0.5 ];
$defaultAssistantIconActive := $defaultAssistantIconActive = Magnify[
    AnimatedImage[ (ImageResize[ #1, Scaled[ 0.5 ] ] &) /@ $birdList ],
    0.5
];

$birdCellLabelStatic = Cell @ BoxData @ TemplateBox[ { }, "AssistantIcon"       ];
$birdCellLabel       = Cell @ BoxData @ TemplateBox[ { }, "AssistantIconActive" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeAIAssistantNotebookOptions*)
makeAIAssistantNotebookOptions // beginDefinition;
makeAIAssistantNotebookOptions[ settings_ ] := Sequence[ StyleDefinitions -> makeAIAssistantStylesheet @ settings ];
makeAIAssistantNotebookOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeAIAssistantStylesheet*)
makeAIAssistantStylesheet // beginDefinition;

makeAIAssistantStylesheet[ defaults_Association ] :=
    Module[ { icon, iconActive, iconTF, iconActiveTF },

        $debugData   = defaults;
        icon         = getAssistantIcon @ defaults;
        iconActive   = getAssistantIconActive @ defaults;
        iconTF       = makeAssistantIconTemplateFunction @ icon;
        iconActiveTF = makeAssistantIconTemplateFunction @ iconActive;

        Notebook[
            {
                Cell[ StyleData[ StyleDefinitions -> "Default.nb" ] ],
                Sequence @@ Values @ KeyDrop[ $styleDataCells, { "AssistantIcon", "AssistantIconActive" } ],
                styleDataCell[ "AssistantIcon"      , TemplateBoxOptions -> { DisplayFunction -> iconTF       } ],
                styleDataCell[ "AssistantIconActive", TemplateBoxOptions -> { DisplayFunction -> iconActiveTF } ]
            },
            StyleDefinitions -> "PrivateStylesheetFormatting.nb"
        ] /.
            HoldPattern[ $defaultAIAssistantSettings ] :>
                RuleCondition @ Association[ $defaultAIAssistantSettings, defaults ]
    ];

makeAIAssistantStylesheet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*styleDataCell*)
styleDataCell // ClearAll;
styleDataCell[ a___ ] := styleDataCell[ a ] = styleDataCell0 @ a;

styleDataCell0 // beginDefinition;
styleDataCell0[ name_ ] := styleDataCell0[ name, { } ];
styleDataCell0[ name_, opts: OptionsPattern[ ] ] := styleDataCell0[ name, $styleDataCells @ name, Flatten @ { opts } ];
styleDataCell0[ name_, Cell[ a: StyleData[ name_, ___ ], b___ ], { c___ } ] := insertCellOptions[ Cell[ a, b ], c ];
styleDataCell0[ name_, _Missing, { c___ } ] := Cell[ StyleData @ name, c ];
styleDataCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertCellOptions*)
insertCellOptions // beginDefinition;

insertCellOptions[ expr_, { } ] := expr;

insertCellOptions[ Cell[ a: Except[ OptionsPattern[ ] ] ..., b: OptionsPattern[ ] ], c: OptionsPattern[ ] ] :=
    Cell[ a, mergeOptions[ { b }, { c } ] ];

insertCellOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeOptions*)
mergeOptions // beginDefinition;

mergeOptions[ a: { OptionsPattern[ ] }, b: { OptionsPattern[ ] } ] :=
    Module[ { delayed, names, flat, rules, normal },
        SetAttributes[ delayed, HoldAllComplete ];

        names  = Keys @ Association[ a, b ];
        flat   = Replace[ Flatten @ { b, a }, Verbatim[ RuleDelayed ][ x_, y_ ] :> Rule[ x, delayed @ y ], { 1 } ];
        rules  = Thread[ names -> OptionValue[ flat, names ] ];
        normal = Replace[ rules, Verbatim[ Rule ][ x_, delayed[ y_ ] ] :> RuleDelayed[ x, y ], { 1 } ];

        Sequence @@ DeleteDuplicatesBy[ normal, optionName ]
    ];

mergeOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*optionName*)
optionName // beginDefinition;
optionName[ (Rule|RuleDelayed)[ name_, _ ] ] := optionName @ name;
optionName[ name_String ] := name;
optionName[ sym_Symbol  ] := SymbolName @ sym;
optionName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Stylesheet Components*)

(* TODO: move this stuff to the stylesheet *)

$copyToClipboardButtonLabel := $copyToClipboardButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "HyperlinkCopyIcon" ],
            buttonFrameActive @ RawBoxes @ ReplaceAll[
                FrontEndResource[ "NotebookToolbarExpressions", "HyperlinkCopyIcon" ],
                RGBColor[ 0.2, 0.2, 0.2 ] -> RGBColor[ 0.2902, 0.58431, 0.8 ]
            ]
        ],
        "LinkHand"
    ],
    "Copy to clipboard"
];

$insertInputButtonLabel := $insertInputButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "InsertInputIcon" ],
            buttonFrameActive @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "InsertInputIconHover" ]
        ],
        "LinkHand"
    ],
    "Insert content as new input cell below"
];

$insertEvaluateButtonLabel := $insertEvaluateButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "EvaluateIcon" ],
            buttonFrameActive @ RawBoxes @ FrontEndResource[ "NotebookToolbarExpressions", "EvaluateIconHover" ]
        ],
        "LinkHand"
    ],
    "Insert content as new input cell below and evaluate"
];


evaluateLanguageLabel // ClearAll;

evaluateLanguageLabel[ name_String ] :=
    With[ { icon = $languageIcons @ name },
        fancyTooltip[
            MouseAppearance[ buttonMouseover[ buttonFrameDefault @ icon, buttonFrameActive @ icon ], "LinkHand" ],
            "Insert content as new input cell below and evaluate"
        ] /; MatchQ[ icon, _Graphics | _Image ]
    ];

evaluateLanguageLabel[ ___ ] := $insertEvaluateButtonLabel;


button // Attributes = { HoldRest };
button[ label_, code_ ] :=
    Button[
        label,
        code,
        Appearance -> Dynamic @ FEPrivate`FrontEndResource[ "FEExpressions", "SuppressMouseDownNinePatchAppearance" ]
    ];

buttonMouseover[ a_, b_ ] := Mouseover[ a, b ];
buttonFrameDefault[ expr_ ] := Framed[ buttonPane @ expr, FrameStyle -> None, Background -> None, FrameMargins -> 1 ];
buttonFrameActive[ expr_ ] := Framed[ buttonPane @ expr, FrameStyle -> GrayLevel[ 0.82 ], Background -> GrayLevel[ 1 ], FrameMargins -> 1 ];
buttonPane[ expr_ ] := Pane[ expr, ImageSize -> { 24, 24 }, ImageSizeAction -> "ShrinkToFit", Alignment -> { Center, Center } ];

fancyTooltip[ expr_, tooltip_ ] := Tooltip[
    expr,
    Framed[
        Style[
            tooltip,
            "Text",
            FontColor    -> RGBColor[ 0.53725, 0.53725, 0.53725 ],
            FontSize     -> 12,
            FontWeight   -> "Plain",
            FontTracking -> "Plain"
        ],
        Background   -> RGBColor[ 0.96078, 0.96078, 0.96078 ],
        FrameStyle   -> RGBColor[ 0.89804, 0.89804, 0.89804 ],
        FrameMargins -> 8
    ],
    TooltipDelay -> 0.15,
    TooltipStyle -> { Background -> None, CellFrame -> 0 }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAssistantIcon*)
getAssistantIcon // beginDefinition;
getAssistantIcon[ as_Association ] := getAssistantIcon[ as, Lookup[ as, "AssistantIcon", Automatic ] ];
getAssistantIcon[ KeyValuePattern[ "AssistantTheme" -> "Generic" ], Automatic ] := $icons[ "Generic" ];
getAssistantIcon[ KeyValuePattern[ "AssistantTheme" -> "Wolfie" ], Automatic ] := $icons[ "Wolfie" ];
getAssistantIcon[ as_, Automatic ] := $defaultAssistantIcon;
getAssistantIcon[ as_, None ] := Graphics[ { }, ImageSize -> 1 ];
getAssistantIcon[ as_, KeyValuePattern[ "Default" -> icon_ ] ] := icon;
getAssistantIcon[ as_, { icon_, _ } ] := icon;
getAssistantIcon[ as_, icon_ ] := icon;
getAssistantIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAssistantIconActive*)
getAssistantIconActive // beginDefinition;
getAssistantIconActive[ as_Association ] := getAssistantIconActive[ as, Lookup[ as, "AssistantIcon", Automatic ] ];
getAssistantIconActive[ KeyValuePattern[ "AssistantTheme" -> "Generic" ], Automatic ] := $icons[ "GenericActive" ];
getAssistantIconActive[ KeyValuePattern[ "AssistantTheme" -> "Wolfie" ], Automatic ] := $icons[ "Wolfie" ];
getAssistantIconActive[ as_, Automatic ] := $defaultAssistantIconActive;
getAssistantIconActive[ as_, None ] := Graphics[ { }, ImageSize -> 1 ];
getAssistantIconActive[ as_, KeyValuePattern[ "Active" -> icon_ ] ] := icon;
getAssistantIconActive[ as_, { _, icon_ } ] := icon;
getAssistantIconActive[ as_, icon_ ] := icon;
getAssistantIconActive // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeAssistantIconTemplateFunction*)
makeAssistantIconTemplateFunction // beginDefinition;
makeAssistantIconTemplateFunction[ icon_ ] := Function @ Evaluate @ MakeBoxes @ icon;
makeAssistantIconTemplateFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeAIAssistantSettings*)
makeAIAssistantSettings // beginDefinition;

makeAIAssistantSettings[ as_Association? AssociationQ, opts: OptionsPattern[ AIAssistant ] ] :=
    With[ { bcOpts = Options @ AIAssistant },
        KeyDrop[
            KeyMap[
                ToString,
                Association[ $defaultAIAssistantSettings, bcOpts, FilterRules[ { opts }, bcOpts ], as ]
            ],
            "OpenAIKey"
        ]
    ];

makeAIAssistantSettings[ opts: OptionsPattern[ AIAssistant ] ] := makeAIAssistantSettings[ <| |>, opts ];

makeAIAssistantSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AIAssistant Commands*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*executeAIAssistantCommand*)
executeAIAssistantCommand // beginDefinition;
executeAIAssistantCommand[ "RequestAIAssistant", args___ ] := requestAIAssistant @ args;
executeAIAssistantCommand[ "Loaded"            , args___ ] := $birdChatLoaded;
executeAIAssistantCommand[ "SetRole"           , args___ ] := setAIAssistantRole @ args;
executeAIAssistantCommand[ "Ask"               , args___ ] := askAIAssistant @ args;
executeAIAssistantCommand[ "Models"            , args___ ] := getAIAssistantModels @ args;
executeAIAssistantCommand // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAIAssistantModels*)
getAIAssistantModels // beginDefinition;
getAIAssistantModels[ opts: OptionsPattern[ AIAssistant ] ] := getModelList @ toAPIKey @ OptionValue[ "OpenAIKey" ];
getAIAssistantModels // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getModelList*)
getModelList // beginDefinition;

getModelList[ key_String ] := getModelList[ key, Hash @ key ];

getModelList[ key_String, hash_Integer ] :=
    getModelList[
        hash,
        URLExecute[
            HTTPRequest[
                "https://api.openai.com/v1/models",
                <| "Headers" -> <| "Content-Type" -> "application/json", "Authorization" -> "Bearer "<>key |> |>
            ],
            "RawJSON",
            Interactive -> False
        ]
    ];

getModelList[ hash_, KeyValuePattern[ "data" -> data_ ] ] :=
    getModelList[ hash, data ];

getModelList[ hash_, models: { KeyValuePattern[ "id" -> _String ].. } ] :=
    getModelList[ _String, hash ] = Cases[ models, KeyValuePattern[ "id" -> id_String ] :> id ];

getModelList[ hash_, KeyValuePattern[ "error" -> as: KeyValuePattern[ "message" -> message_ ] ] ] :=
    throwFailure[ AIAssistant::BadResponseMessage, message, as ];

getModelList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setAIAssistantRole*)
setAIAssistantRole[ role_String ] := setAIAssistantRole[ InputNotebook[ ], role ];
setAIAssistantRole[ nbo_NotebookObject, role_String ] := (
    CurrentValue[ nbo, { TaggingRules, "AIAssistantSettings", "RolePrompt" } ] = role;
    Null
);

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*askAIAssistant*)
askAIAssistant // beginDefinition;

askAIAssistant[ ] := askAIAssistant[ InputNotebook[ ] ];
askAIAssistant[ nbo_NotebookObject ] := askAIAssistant[ nbo, SelectedCells @ nbo ];
askAIAssistant[ nbo_NotebookObject, { selected_CellObject } ] :=
    Module[ { selection, cell, obj },
        selection = NotebookRead @ nbo;
        cell = chatQueryCell @ selection;
        SelectionMove[ selected, After, Cell ];
        obj = $lastQueryCell = cellPrint @ cell;
        SelectionMove[ obj, All, Cell ];
        SelectionEvaluateCreateCell @ nbo
    ];

askAIAssistant // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatQueryCell*)
chatQueryCell // beginDefinition;
chatQueryCell[ s_String ] := Cell[ StringTrim @ s, "ChatQuery", GeneratedCell -> False, CellAutoOverwrite -> False ];
chatQueryCell[ boxes_ ] := Cell[ BoxData @ boxes, "ChatQuery", GeneratedCell -> False, CellAutoOverwrite -> False ];
chatQueryCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section:: *)
(*Dependencies*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requestAIAssistant*)
requestAIAssistant // beginDefinition;

requestAIAssistant[ ] := requestAIAssistant @ EvaluationCell[ ];

requestAIAssistant[ evalCell_CellObject ] := requestAIAssistant[ evalCell, parentNotebook @ evalCell ];

requestAIAssistant[ evalCell_CellObject, nbo_NotebookObject ] :=
    requestAIAssistant[ evalCell, nbo, Association @ CurrentValue[ nbo, { TaggingRules, "AIAssistantSettings" } ] ];

requestAIAssistant[ evalCell_CellObject, nbo_NotebookObject, settings_Association? AssociationQ ] :=
    requestAIAssistant[ evalCell, nbo, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

requestAIAssistant[ evalCell_, nbo_, settings_, Automatic ] /; CloudSystem`$CloudNotebooks :=
    requestAIAssistant[ evalCell, nbo, settings, False ];

requestAIAssistant[ evalCell_, nbo_, settings_, Automatic ] :=
    Block[ { $autoOpen, $alwaysOpen },
        $autoOpen = $alwaysOpen = MemberQ[ CurrentValue[ evalCell, CellStyle ], "Text"|"ChatInput"|"ChatQuery" ];
        requestAIAssistant0[ evalCell, nbo, settings ]
    ];

requestAIAssistant[ evalCell_, nbo_, settings_, minimized_ ] :=
    Block[ { $alwaysOpen = alwaysOpenQ[ settings, minimized ] },
        $lastAlwaysOpen = $alwaysOpen;
        requestAIAssistant0[ evalCell, nbo, settings ]
    ];

requestAIAssistant // endDefinition;



requestAIAssistant0 // beginDefinition;

requestAIAssistant0[ evalCell_, nbo_, settings_ ] := catchTop @ Enclose[
    Module[ { id, key, cell, cellObject, container, req, task },
        id   = Lookup[ settings, "ID" ];
        key  = toAPIKey[ Automatic, id ];

        If[ ! StringQ @ key, throwFailure[ "NoAPIKey" ] ];

        req = ConfirmMatch[ makeHTTPRequest[ Append[ settings, "OpenAIKey" -> key ], nbo, evalCell ], _HTTPRequest ];

        container = ProgressIndicator[ Appearance -> "Percolate" ];
        cell = activeAIAssistantCell[ container, settings ];

        Quiet[
            TaskRemove @ $lastTask;
            NotebookDelete @ $lastCellObject;
        ];

        $resultCellCache = <| |>;
        $debugLog = Internal`Bag[ ];
        cellObject = $lastCellObject = cellPrint @ cell;

        task = Confirm[ $lastTask = submitAIAssistant[ container, req, cellObject, settings ] ]
    ],
    throwInternalFailure[ requestAIAssistant0[ evalCell, nbo, settings ], ## ] &
];

requestAIAssistant0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*alwaysOpenQ*)
alwaysOpenQ // beginDefinition;
alwaysOpenQ[ as_, True  ] := False;
alwaysOpenQ[ as_, False ] := True;
alwaysOpenQ[ as_, _     ] := StringQ @ as[ "RolePrompt" ] && StringFreeQ[ as[ "RolePrompt" ], $$severityTag ];
alwaysOpenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitAIAssistant*)
submitAIAssistant // beginDefinition;
submitAIAssistant // Attributes = { HoldFirst };

submitAIAssistant[ container_, req_, cellObject_, settings_ ] /; CloudSystem`$CloudNotebooks := Enclose[
    Module[ { resp, code, json, text },
        resp = ConfirmMatch[ URLRead @ req, _HTTPResponse ];
        code = ConfirmBy[ resp[ "StatusCode" ], IntegerQ ];
        ConfirmAssert[ resp[ "ContentType" ] === "application/json" ];
        json = Developer`ReadRawJSONString @ resp[ "Body" ];
        text = $lastMessageText = extractMessageText @ json;
        checkResponse[ settings, text, cellObject, json ]
    ],
    # & (* TODO: cloud error cell *)
];

submitAIAssistant[ container_, req_, cellObject_, settings_ ] :=
    With[ { autoOpen = TrueQ @ $autoOpen, alwaysOpen = TrueQ @ $alwaysOpen },
        URLSubmit[
            req,
            HandlerFunctions -> <|
                "BodyChunkReceived" -> Function[
                    catchTop @ Block[ { $autoOpen = autoOpen, $alwaysOpen = alwaysOpen },
                        Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                        writeChunk[ Dynamic @ container, cellObject, #1 ]
                    ]
                ],
                "TaskFinished" -> Function[
                    catchTop @ Block[ { $autoOpen = autoOpen, $alwaysOpen = alwaysOpen },
                        Internal`StuffBag[ $debugLog, $lastStatus = #1 ];
                        checkResponse[ settings, container, cellObject, #1 ]
                    ]
                ]
            |>,
            HandlerFunctionsKeys -> { "BodyChunk", "StatusCode", "Task", "TaskStatus", "EventName" },
            CharacterEncoding    -> "UTF8"
        ]
    ];

submitAIAssistant // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractMessageText*)
extractMessageText // beginDefinition;

extractMessageText[ KeyValuePattern[
    "choices" -> {
        KeyValuePattern[ "message" -> KeyValuePattern[ "content" -> message_String ] ],
        ___
    }
] ] := untagString @ message;

extractMessageText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*activeAIAssistantCell*)
activeAIAssistantCell // beginDefinition;
activeAIAssistantCell // Attributes = { HoldFirst };

activeAIAssistantCell[ container_, settings_ ] /; CloudSystem`$CloudNotebooks := (
    Cell[
        BoxData @ ToBoxes @ ProgressIndicator[ Appearance -> "Percolate" ],
        "Output",
        "ChatOutput",
        CellFrameLabels -> {
            { Cell @ BoxData @ TemplateBox[ { }, "AssistantIconActive" ], None },
            { None, None }
        }
    ]
);

activeAIAssistantCell[ container_, settings_Association? AssociationQ ] :=
    activeAIAssistantCell[ container, settings, Lookup[ settings, "ShowMinimized", Automatic ] ];

activeAIAssistantCell[ container_, settings_, minimized_ ] :=
    With[
        {
            label    = activeChatIcon[ ],
            id       = $SessionID,
            reformat = dynamicAutoFormatQ @ settings
        },
        Cell[
            BoxData @ ToBoxes @
                If[ TrueQ @ reformat,
                    Dynamic[
                        Refresh[
                            dynamicTextDisplay[ container, reformat ],
                            TrackedSymbols :> { },
                            UpdateInterval -> 0.2
                        ],
                        Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
                    ],
                    Dynamic[
                        dynamicTextDisplay[ container, reformat ],
                        Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
                    ]
                ],
            "Output",
            "ChatOutput",
            If[ MatchQ[ minimized, True|Automatic ],
                Sequence @@ Flatten[ {
                    $closedBirdCellOptions,
                    Initialization :> attachMinimizedIcon[ EvaluationCell[ ], label ]
                } ],
                Sequence @@ { }
            ],
            Selectable      -> False,
            Editable        -> False,
            CellFrameLabels -> {
                { Cell @ BoxData @ TemplateBox[ { }, "AssistantIconActive" ], None },
                { None, None }
            }
        ]
    ];

activeAIAssistantCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dynamicAutoFormatQ*)
dynamicAutoFormatQ // beginDefinition;
dynamicAutoFormatQ[ KeyValuePattern[ "DynamicAutoFormat" -> format: (True|False) ] ] := format;
dynamicAutoFormatQ[ KeyValuePattern[ "AutoFormat" -> format_ ] ] := TrueQ @ format;
dynamicAutoFormatQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dynamicTextDisplay*)
dynamicTextDisplay // beginDefinition;

dynamicTextDisplay[ text_String, True ] :=
    With[ { id = $SessionID },
        Dynamic[
            Refresh[
                Block[ { $dynamicText = True }, RawBoxes @ Cell @ TextData @ reformatTextData @ text ],
                TrackedSymbols :> { },
                UpdateInterval -> 0.2
            ],
            Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
        ]
    ];

dynamicTextDisplay[ text_String, False ] :=
    With[ { id = $SessionID },
        Dynamic[
            RawBoxes @ Cell @ TextData @ text,
            Initialization :> If[ $SessionID =!= id, NotebookDelete @ EvaluationCell[ ] ]
        ]
    ];

dynamicTextDisplay[ _Symbol, _ ] := ProgressIndicator[ Appearance -> "Percolate" ];

dynamicTextDisplay[ other_, _ ] := other;

dynamicTextDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookRead*)
notebookRead // beginDefinition;
notebookRead[ cells_ ] /; CloudSystem`$CloudNotebooks := cloudNotebookRead @ cells;
notebookRead[ cells_ ] := NotebookRead @ cells;
notebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookRead*)
cloudNotebookRead // beginDefinition;
cloudNotebookRead[ cells: { ___CellObject } ] := NotebookRead /@ cells;
cloudNotebookRead[ cell_ ] := NotebookRead @ cell;
cloudNotebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parentNotebook*)
parentNotebook // beginDefinition;
parentNotebook[ cell_CellObject ] /; CloudSystem`$CloudNotebooks := Notebooks @ cell;
parentNotebook[ cell_CellObject ] := ParentNotebook @ cell;
parentNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellPrint*)
cellPrint // beginDefinition;
cellPrint[ cell_Cell ] /; CloudSystem`$CloudNotebooks := cloudCellPrint @ cell;
cellPrint[ cell_Cell ] := MathLink`CallFrontEnd @ FrontEnd`CellPrintReturnObject @ cell;
cellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellPrint*)
cloudCellPrint // beginDefinition;

cloudCellPrint[ cell0_Cell ] :=
    Enclose @ Module[ { cellUUID, nbUUID, cell },
        cellUUID = CreateUUID[ ];
        nbUUID   = ConfirmBy[ cloudNotebookUUID[ ], StringQ ];
        cell     = Append[ DeleteCases[ cell0, ExpressionUUID -> _ ], ExpressionUUID -> cellUUID ];
        CellPrint @ cell;
        CellObject[ cellUUID, nbUUID ]
    ];

cloudCellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookUUID*)
cloudNotebookUUID // beginDefinition;
cloudNotebookUUID[ ] := cloudNotebookUUID[ EvaluationNotebook[ ] ];
cloudNotebookUUID[ NotebookObject[ _, uuid_String ] ] := uuid;
cloudNotebookUUID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkResponse*)
checkResponse // beginDefinition;

checkResponse[ settings_, container_, cell_, as: KeyValuePattern[ "StatusCode" -> Except[ 200, _Integer ] ] ] :=
    Module[ { log, body, data },
        log  = Internal`BagPart[ $debugLog, All ];
        body = StringJoin @ Cases[ log, KeyValuePattern[ "BodyChunk" -> s_String ] :> s ];
        data = Replace[ Quiet @ Developer`ReadRawJSONString @ body, $Failed -> Missing[ "NotAvailable" ] ];
        writeErrorCell[ cell, $badResponse = Association[ as, "Body" -> body, "BodyJSON" -> data ] ]
    ];

checkResponse[ settings_, container_, cell_, as_Association ] := (
    writeReformattedCell[ settings, container, cell ];
    Quiet @ NotebookDelete @ cell;
);

checkResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeErrorCell*)
writeErrorCell // ClearAll;
writeErrorCell[ cell_, as_ ] := NotebookWrite[ cell, errorCell @ as ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorCell*)
errorCell // ClearAll;
errorCell[ as_ ] :=
    Cell[
        TextData @ { errorText @ as, "\n\n", Cell @ BoxData @ errorBoxes @ as },
        "Text",
        "Message",
        "ChatOutput",
        GeneratedCell -> True,
        CellAutoOverwrite -> True
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorText*)
errorText // ClearAll;

errorText[ KeyValuePattern[ "BodyJSON" -> KeyValuePattern[ "error" -> KeyValuePattern[ "message" -> s_String ] ] ] ] :=
    s;

errorText[ ___ ] := "An unexpected error occurred.";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*errorBoxes*)
errorBoxes // ClearAll;

errorBoxes[ as: KeyValuePattern[ "StatusCode" -> code: Except[ 200 ] ] ] :=
    ToBoxes @ messageFailure[ AIAssistant::UnknownStatusCode, as ];

errorBoxes[ as_ ] :=
    ToBoxes @ messageFailure[ AIAssistant::UnknownResponse, as ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeHTTPRequest*)
makeHTTPRequest // beginDefinition;

makeHTTPRequest[ settings_Association? AssociationQ, nbo_NotebookObject, cell_CellObject ] :=
    makeHTTPRequest[ settings, selectChatCells[ settings, cell, nbo ] ];

makeHTTPRequest[ settings_Association? AssociationQ, cells: { __CellObject } ] :=
    makeHTTPRequest[ settings, notebookRead @ cells ];

makeHTTPRequest[ settings_Association? AssociationQ, cells: { __Cell } ] :=
    Module[ { role, messages, merged },
        role     = makeCurrentRole @ settings;
        messages = DeleteMissing @ Prepend[ makeCellMessage /@ cells, role ];
        merged   = If[ TrueQ @ Lookup[ settings, "MergeMessages" ], mergeMessageData @ messages, messages ];
        makeHTTPRequest[ settings, merged ]
    ];

makeHTTPRequest[ settings_Association? AssociationQ, messages: { __Association } ] :=
    Enclose @ Module[
        { key, stream, model, tokens, temperature, topP, freqPenalty, presPenalty, data, body },

        $lastSettings = settings;
        $lastMessages = messages;

        key         = ConfirmBy[ Lookup[ settings, "OpenAIKey" ], StringQ ];
        stream      = ! TrueQ @ CloudSystem`$CloudNotebooks;

        (* model parameters *)
        model       = Lookup[ settings, "Model"           , "gpt-3.5-turbo" ];
        tokens      = Lookup[ settings, "MaxTokens"       , Automatic       ];
        temperature = Lookup[ settings, "Temperature"     , 0.7             ];
        topP        = Lookup[ settings, "TopP"            , 1               ];
        freqPenalty = Lookup[ settings, "FrequencyPenalty", 0.1             ];
        presPenalty = Lookup[ settings, "PresencePenalty" , 0.1             ];

        data = DeleteCases[
            <|
                "messages"          -> messages,
                "temperature"       -> temperature,
                "max_tokens"        -> tokens,
                "top_p"             -> topP,
                "frequency_penalty" -> freqPenalty,
                "presence_penalty"  -> presPenalty,
                "model"             -> toModelName @ model,
                "stream"            -> stream
            |>,
            Automatic|_Missing
        ];

        body = ConfirmBy[ Developer`WriteRawJSONString[ data, "Compact" -> True ], StringQ ];

        $lastRequest = HTTPRequest[
            "https://api.openai.com/v1/chat/completions",
            <|
                "Headers" -> <|
                    "Content-Type"  -> "application/json",
                    "Authorization" -> "Bearer "<>key
                |>,
                "Body"   -> body,
                "Method" -> "POST"
            |>
        ]
    ];

makeHTTPRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toModelName*)
toModelName // beginDefinition;

toModelName[ name_String? StringQ ] :=
    toModelName0 @ StringReplace[
        ToLowerCase @ StringReplace[
            name,
            a_? LowerCaseQ ~~ b_? UpperCaseQ :> a<>"-"<>b
        ],
        "gpt"~~n:$$modelVersion~~EndOfString :> "gpt-"<>n
    ];

toModelName // endDefinition;

$$modelVersion = DigitCharacter.. ~~ (("." ~~ DigitCharacter...) | "");

(* cSpell:ignore chatgpt *)
toModelName0 // beginDefinition;
toModelName0[ "chat-gpt"|"chatgpt"|"gpt-3"|"gpt-3.5" ] := "gpt-3.5-turbo";
toModelName0[ name_String ] := StringReplace[ name, "gpt"~~n:DigitCharacter :> "gpt-"<>n ];
toModelName0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCurrentRole*)
makeCurrentRole // beginDefinition;
makeCurrentRole[ as_Association? AssociationQ ] := makeCurrentRole[ as, as[ "RolePrompt" ], as[ "AssistantTheme" ] ];
makeCurrentRole[ as_, None, _ ] := Missing[ ];
makeCurrentRole[ as_, role_String, _ ] := <| "role" -> "system", "content" -> role |>;
makeCurrentRole[ as_, Automatic, name_String ] := <| "role" -> "system", "content" -> namedRolePrompt @ name |>;
makeCurrentRole[ as_, _, _ ] := $defaultRole;
makeCurrentRole // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeMessageData*)
mergeMessageData // beginDefinition;
mergeMessageData[ messages_ ] := mergeMessages /@ SplitBy[ messages, Lookup[ "role" ] ];
mergeMessageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeMessages*)
mergeMessages // beginDefinition;

mergeMessages[ { } ] := Nothing;
mergeMessages[ { message_ } ] := message;
mergeMessages[ messages: { first_Association, __Association } ] :=
    Module[ { role, strings },
        role    = Lookup[ first   , "role"    ];
        strings = Lookup[ messages, "content" ];
        <|
            "role"    -> role,
            "content" -> StringRiffle[ strings, "\n\n" ]
        |>
    ];

mergeMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectChatCells*)
selectChatCells // beginDefinition;

selectChatCells[ as_Association? AssociationQ, cell_CellObject, nbo_NotebookObject ] :=
    Block[
        {
            $maxChatCells = Replace[
                Lookup[ as, "ChatHistoryLength" ],
                Except[ _Integer? Positive ] :> $maxChatCells
            ]
        },
        $selectedChatCells = selectChatCells0[ cell, nbo ]
    ];

selectChatCells // endDefinition;


selectChatCells0 // beginDefinition;

selectChatCells0[ cell_, nbo_NotebookObject ] :=
    selectChatCells0[ cell, Cells @ nbo ];

selectChatCells0[ cell_, { cells___, cell_, trailing0___ } ] :=
    Module[ { trailing, include, styles, delete, included, flat, filtered },
        trailing = { trailing0 };
        include = Keys @ TakeWhile[ AssociationThread[ trailing -> CurrentValue[ trailing, GeneratedCell ] ], TrueQ ];
        styles = cellStyles @ include;
        delete = Keys @ Select[ AssociationThread[ include -> MemberQ[ "ChatOutput" ] /@ styles ], TrueQ ];
        NotebookDelete @ delete;
        included = DeleteCases[ include, Alternatives @@ delete ];
        flat = dropDelimitedCells @ Flatten @ { cells, cell, included };
        filtered = clearMinimizedChats[ parentNotebook @ cell, flat ];
        Reverse @ Take[ Reverse @ filtered, UpTo @ $maxChatCells ]
    ];

selectChatCells0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clearMinimizedChats*)
clearMinimizedChats // beginDefinition;

clearMinimizedChats[ nbo_, cells_ ] /; CloudSystem`$CloudNotebooks := cells;

clearMinimizedChats[ nbo_NotebookObject, cells_List ] :=
    Module[ { outCells, closed, attached },
        outCells = Cells[ nbo, CellStyle -> "ChatOutput" ];
        closed = Keys @ Select[ AssociationThread[ outCells -> CurrentValue[ outCells, CellOpen ] ], Not ];
        attached = Cells[ nbo, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ];
        NotebookDelete @ Flatten @ { closed, attached };
        DeleteCases[ cells, Alternatives @@ closed ]
    ];

clearMinimizedChats // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clearMinimizedChat*)
clearMinimizedChat // beginDefinition;

clearMinimizedChat[ attached_CellObject, parentCell_CellObject ] :=
    Module[ { next },
        NotebookDelete @ attached;
        next = NextCell @ parentCell;
        If[ MemberQ[ cellStyles @ next, "ChatOutput" ] && TrueQ[ ! CurrentValue[ next, CellOpen ] ],
            NotebookDelete @ next;
            next,
            Nothing
        ]
    ];

clearMinimizedChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dropDelimitedCells*)
dropDelimitedCells // beginDefinition;

dropDelimitedCells[ cells_List ] :=
    Drop[ cells, Max[ Position[ cellStyles @ cells, { ___, "ChatDelimiter"|"PageBreak", ___ }, { 1 } ], 0 ] ];

dropDelimitedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellStyles*)
cellStyles // beginDefinition;
cellStyles[ cells_ ] /; CloudSystem`$CloudNotebooks := cloudCellStyles @ cells;
cellStyles[ cells_ ] := CurrentValue[ cells, CellStyle ];
cellStyles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellStyles*)
cloudCellStyles // beginDefinition;
cloudCellStyles[ cells_ ] := Cases[ notebookRead @ cells, Cell[ _, style___String, OptionsPattern[ ] ] :> { style } ];
cloudCellStyles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCellMessage*)
makeCellMessage // beginDefinition;
makeCellMessage[ cell: Cell[ __, "ChatOutput", ___ ] ] := <| "role" -> "assistant", "content" -> cellToString @ cell |>;
makeCellMessage[ cell_Cell ] := <| "role" -> "user", "content" -> cellToString @ cell |>;
makeCellMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeChunk*)
writeChunk // beginDefinition;

writeChunk[ container_, cell_, KeyValuePattern[ "BodyChunk" -> chunk_String ] ] :=
    writeChunk[ container, cell, chunk ];

writeChunk[ container_, cell_, chunk_String ] /; StringMatchQ[ chunk, "data: " ~~ __ ~~ "\n\n" ~~ __ ~~ ("\n\n"|"") ] :=
    writeChunk[ container, cell, # ] & /@ StringSplit[ chunk, "\n\n" ];

writeChunk[ container_, cell_, chunk_String ] /; StringMatchQ[ chunk, "data: " ~~ __ ~~ ("\n\n"|"") ] :=
    Module[ { json },
        json = StringDelete[ chunk, { StartOfString~~"data: ", ("\n\n"|"") ~~ EndOfString } ];
        writeChunk[ container, cell, chunk, Quiet @ Developer`ReadRawJSONString @ json ]
    ];

writeChunk[ container_, cell_, "" | "data: [DONE]" | "data: [DONE]\n\n" ] := Null;

writeChunk[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "choices" -> { KeyValuePattern[ "delta" -> KeyValuePattern[ "content" -> text_String ] ], ___ } ]
] := writeChunk[ container, cell, chunk, text ];

writeChunk[
    container_,
    cell_,
    chunk_String,
    KeyValuePattern[ "choices" -> { KeyValuePattern @ { "delta" -> <| |>, "finish_reason" -> "stop" }, ___ } ]
] := Null;

writeChunk[ Dynamic[ container_ ], cell_, chunk_String, text_String ] := (
    If[ StringQ @ container,
        container = StringDelete[ container <> convertUTF8 @ text, StartOfString~~Whitespace ],
        container = convertUTF8 @ text
    ];
    Which[
        errorTaggedQ @ container, processErrorCell[ container, cell ],
        warningTaggedQ @ container, processWarningCell[ container, cell ],
        infoTaggedQ @ container, processInfoCell[ container, cell ],
        untaggedQ @ container, openBirdCell @ cell,
        True, Null
    ]
);

writeChunk[ Dynamic[ container_ ], cell_, chunk_String, other_ ] := Null;

writeChunk // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Severity Tag String Patterns*)
$$whitespace  = Longest[ WhitespaceCharacter... ];
$$severityTag = "ERROR"|"WARNING"|"INFO";
$$tagPrefix   = StartOfString~~$$whitespace~~"["~~$$whitespace~~$$severityTag~~$$whitespace~~"]"~~$$whitespace;

$maxTagLength = Max[ StringLength /@ (List @@ $$severityTag) ] + 2;


errorTaggedQ // ClearAll;
errorTaggedQ[ s_String? StringQ ] := taggedQ[ s, "ERROR" ];
errorTaggedQ[ ___               ] := False;


warningTaggedQ // ClearAll;
warningTaggedQ[ s_String? StringQ ] := taggedQ[ s, "WARNING" ];
warningTaggedQ[ ___               ] := False;


infoTaggedQ // ClearAll;
infoTaggedQ[ s_String? StringQ ] := taggedQ[ s, "INFO" ];
infoTaggedQ[ ___               ] := False;


untaggedQ // ClearAll;
untaggedQ[ s0_String? StringQ ] /; $alwaysOpen :=
    With[ { s = StringDelete[ $lastUntagged = s0, Whitespace ] },
        Or[ StringStartsQ[ s, Except[ "[" ] ],
            StringLength @ s >= $maxTagLength && ! StringStartsQ[ s, $$tagPrefix, IgnoreCase -> True ]
        ]
    ];

untaggedQ[ ___ ] := False;


taggedQ // ClearAll;
taggedQ[ s_String? StringQ ] := taggedQ[ s, $$severityTag ];
taggedQ[ s_String? StringQ, tag_ ] := StringStartsQ[ StringDelete[ s, Whitespace ], "["~~tag~~"]", IgnoreCase -> True ];
taggedQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeSeverityTag*)
removeSeverityTag // beginDefinition;
removeSeverityTag // Attributes = { HoldFirst };

removeSeverityTag[ s_Symbol? StringQ, cell_CellObject ] :=
    Module[ { tag },
        tag = StringReplace[ s, t:$$tagPrefix~~___~~EndOfString :> t ];
        s = untagString @ s;
        CurrentValue[ cell, { TaggingRules, "MessageTag" } ] = ToUpperCase @ StringDelete[ tag, Whitespace ]
    ];

removeSeverityTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*untagString*)
untagString // beginDefinition;
untagString[ str_String? StringQ ] := StringDelete[ str, $$tagPrefix, IgnoreCase -> True ];
untagString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processErrorCell*)
processErrorCell // beginDefinition;
processErrorCell // Attributes = { HoldFirst };

processErrorCell[ container_, cell_CellObject ] := (
    $$errorString = container;
    removeSeverityTag[ container, cell ];
    (* TODO: Add an error icon? *)
    openBirdCell @ cell
);

processErrorCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processWarningCell*)
processWarningCell // beginDefinition;
processWarningCell // Attributes = { HoldFirst };

processWarningCell[ container_, cell_CellObject ] := (
    $$warningString = container;
    removeSeverityTag[ container, cell ];
    openBirdCell @ cell
);

processWarningCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processInfoCell*)
processInfoCell // beginDefinition;
processInfoCell // Attributes = { HoldFirst };

processInfoCell[ container_, cell_CellObject ] := (
    $$infoString = container;
    removeSeverityTag[ container, cell ];
    $lastAutoOpen = $autoOpen;
    If[ TrueQ @ $autoOpen, openBirdCell @ cell ]
);

processInfoCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*openBirdCell*)
openBirdCell // beginDefinition;

openBirdCell[ cell_CellObject ] :=
    Module[ { prev, attached },
        prev = PreviousCell @ cell;
        attached = Cells[ prev, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ];
        NotebookDelete @ attached;
        SetOptions[
            cell,
            CellMargins     -> Inherited,
            CellOpen        -> Inherited,
            CellFrame       -> Inherited,
            ShowCellBracket -> Inherited,
            Initialization  -> Inherited
        ]
    ];

openBirdCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachMinimizedIcon*)
attachMinimizedIcon // beginDefinition;

attachMinimizedIcon[ chatCell_CellObject, label_ ] :=
    Module[ { prev, cell },
        prev = PreviousCell @ chatCell;
        CurrentValue[ chatCell, Initialization ] = Inherited;
        cell = makeMinimizedIconCell[ label, chatCell ];
        NotebookDelete @ Cells[ prev, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" ];
        With[ { prev = prev, cell = cell },
            If[ TrueQ @ BoxForm`sufficientVersionQ[ 13.2 ],
                FE`Evaluate @ FEPrivate`AddCellTrayWidget[ prev, "MinimizedChatIcon" -> <| "Content" -> cell |> ],
                AttachCell[ prev, cell, { "CellBracket", Top }, { 0, 0 }, { Right, Top } ]
            ]
        ]
    ];

attachMinimizedIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeMinimizedIconCell*)
makeMinimizedIconCell // beginDefinition;

makeMinimizedIconCell[ label_, chatCell_CellObject ] := Cell[
    BoxData @ MakeBoxes @ Button[
        MouseAppearance[ label, "LinkHand" ],
        With[ { attached = EvaluationCell[ ] }, NotebookDelete @ attached;
        openBirdCell @ chatCell ],
        Appearance -> None
    ],
    "MinimizedChatIcon"
];

makeMinimizedIconCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertUTF8*)
convertUTF8 // beginDefinition;
convertUTF8[ string_String ] := FromCharacterCode[ ToCharacterCode @ string, "UTF-8" ];
convertUTF8 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeReformattedCell*)
writeReformattedCell // beginDefinition;

writeReformattedCell[ settings_, string_String, cell_CellObject ] :=
    With[
        {
            tag   = CurrentValue[ cell, { TaggingRules, "MessageTag" } ],
            open  = $lastOpen = cellOpenQ @ cell,
            label = staticChatIcon[ ]
        },
        Block[ { $dynamicText = False },
            NotebookWrite[
                cell,
                $reformattedCell = reformatCell[ settings, string, tag, open, label ],
                None,
                AutoScroll -> False
            ]
        ]
    ];

writeReformattedCell[ settings_, other_, cell_CellObject ] :=
    NotebookWrite[
        cell,
        Cell[
            TextData @ {
                "An unexpected error occurred.\n\n",
                Cell @ BoxData @ ToBoxes @ Catch[
                    throwInternalFailure @ writeReformattedCell[ settings, other, cell ],
                    $top
                ]
            },
            "Text",
            "ChatOutput",
            GeneratedCell     -> True,
            CellAutoOverwrite -> True
        ],
        None,
        AutoScroll -> False
    ];

writeReformattedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reformatCell*)
reformatCell // beginDefinition;

reformatCell[ settings_, string_, tag_, open_, label_ ] := Cell[
    If[ TrueQ @ settings[ "AutoFormat" ],
        TextData @ reformatTextData @ string,
        TextData @ string
    ],
    "Text",
    "ChatOutput",
    GeneratedCell     -> True,
    CellAutoOverwrite -> True,
    TaggingRules      -> <| "CellToStringData" -> string, "MessageTag" -> tag |>,
    If[ TrueQ @ open,
        Sequence @@ { },
        Sequence @@ Flatten @ {
            $closedBirdCellOptions,
            Initialization :> attachMinimizedIcon[ EvaluationCell[ ], label ]
        }
    ]
];

reformatCell // endDefinition;

reformatTextData // beginDefinition;

reformatTextData[ string_String ] := Flatten @ Map[
    makeResultCell,
    StringSplit[
        $reformattedString = string,
        {
            StringExpression[
                    Longest[ "```" ~~ lang: Except[ WhitespaceCharacter ].. /; externalLanguageQ @ lang ],
                    Shortest[ code__ ] ~~ "```"
                ] :> externalCodeCell[ lang, code ],
            Longest[ "```" ~~ ($wlCodeString|"") ] ~~ Shortest[ code__ ] ~~ "```" :>
                If[ NameQ[ "System`"<>code ], inlineCodeCell @ code, codeCell @ code ],
            "[" ~~ label: Except[ "[" ].. ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :> hyperlinkCell[ label, url ],
            "``" ~~ code: Except[ "`" ].. ~~ "``" :> inlineCodeCell @ code,
            "`" ~~ code: Except[ "`" ].. ~~ "`" :> inlineCodeCell @ code,
            "$$" ~~ math: Except[ "$" ].. ~~ "$$" :> mathCell @ math,
            "$" ~~ math: Except[ "$" ].. ~~ "$" :> mathCell @ math
        },
        IgnoreCase -> True
    ]
];

reformatTextData[ other_ ] := other;

reformatTextData // endDefinition;


$wlCodeString = Longest @ Alternatives[
    "Wolfram Language",
    "WolframLanguage",
    "Wolfram",
    "Mathematica"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*externalLanguageQ*)
externalLanguageQ // ClearAll;

externalLanguageQ[ $$externalLanguage ] := True;

externalLanguageQ[ str_String? StringQ ] := externalLanguageQ[ str ] =
    StringMatchQ[
        StringReplace[ StringTrim @ str, $externalLanguageRules, IgnoreCase -> True ],
        $$externalLanguage,
        IgnoreCase -> True
    ];

externalLanguageQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellOpenQ*)
cellOpenQ // beginDefinition;
cellOpenQ[ cell_CellObject ] /; CloudSystem`$CloudNotebooks := Lookup[ Options[ cell, CellOpen ], CellOpen, True ];
cellOpenQ[ cell_CellObject ] := CurrentValue[ cell, CellOpen ];
cellOpenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeResultCell*)
makeResultCell // beginDefinition;

makeResultCell[ expr_ ] /; $dynamicText :=
    Lookup[ $resultCellCache,
            HoldComplete @ expr,
            $resultCellCache[ HoldComplete @ expr ] = makeResultCell0 @ expr
    ];

makeResultCell[ expr_ ] := makeResultCell0 @ expr;

makeResultCell // endDefinition;


$resultCellCache = <| |>;


makeResultCell0 // beginDefinition;

makeResultCell0[ str_String ] := formatTextString @ str;

makeResultCell0[ codeCell[ code_String ] ] := makeInteractiveCodeCell @ StringTrim @ code;

makeResultCell0[ externalCodeCell[ lang_String, code_String ] ] :=
    makeInteractiveCodeCell[
        StringReplace[ StringTrim @ lang, $externalLanguageRules, IgnoreCase -> True ],
        StringTrim @ code
    ];

makeResultCell0[ inlineCodeCell[ code_String ] ] := Cell[
    BoxData @ stringTemplateInput @ code,
    "InlineFormula",
    FontFamily -> "Source Sans Pro"
];

makeResultCell0[ mathCell[ math_String ] ] :=
    With[ { boxes = Quiet @ InputAssistant`TeXAssistant @ StringTrim @ math },
        If[ MatchQ[ boxes, _RawBoxes ],
            Cell @ BoxData @ FormBox[ ToBoxes @ boxes, TraditionalForm ],
            makeResultCell0 @ inlineCodeCell @ math
        ]
    ];

makeResultCell0[ hyperlinkCell[ label_String, url_String ] ] := hyperlink[ label, url ];

makeResultCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatTextString*)
formatTextString // beginDefinition;
formatTextString[ str_String ] := StringSplit[ str, $stringFormatRules, IgnoreCase -> True ];
formatTextString // endDefinition;

$stringFormatRules = {
    "[" ~~ label: Except[ "[" ].. ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :> hyperlink[ label, url ],
    "***" ~~ text: Except[ "*" ].. ~~ "***" :> styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],
    "___" ~~ text: Except[ "_" ].. ~~ "___" :> styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],
    "**" ~~ text: Except[ "*" ].. ~~ "**" :> styleBox[ text, FontWeight -> Bold ],
    "__" ~~ text: Except[ "_" ].. ~~ "__" :> styleBox[ text, FontWeight -> Bold ],
    "*" ~~ text: Except[ "*" ].. ~~ "*" :> styleBox[ text, FontSlant -> Italic ],
    "_" ~~ text: Except[ "_" ].. ~~ "_" :> styleBox[ text, FontSlant -> Italic ]
};

styleBox // ClearAll;

styleBox[ text_String, a___ ] := styleBox[ formatTextString @ text, a ];
styleBox[ { text: _ButtonBox|_String }, a___ ] := StyleBox[ text, a ];
styleBox[ { (h: Cell|StyleBox)[ text_, a___ ] }, b___ ] := DeleteDuplicates @ StyleBox[ text, a, b ];

styleBox[ { a___, b: Except[ _ButtonBox|_Cell|_String|_StyleBox ], c___ }, d___ ] :=
    styleBox[ { a, Cell @ BoxData @ b, c }, d ];

styleBox[ a_, ___ ] := a;


hyperlink // ClearAll;

hyperlink[ label_String, uri_String ] /; StringStartsQ[ uri, "paclet:" ] := Cell[
    BoxData @ TagBox[
        ButtonBox[
            StyleBox[
                StringTrim[ label, (Whitespace|"`").. ],
                "SymbolsRefLink",
                ShowStringCharacters -> True,
                FontFamily -> "Source Sans Pro"
            ],
            BaseStyle ->
                Dynamic @ FEPrivate`If[
                    CurrentValue[ "MouseOver" ],
                    { "Link", FontColor -> RGBColor[ 0.8549, 0.39608, 0.1451 ] },
                    { "Link" }
                ],
            ButtonData -> uri,
            ContentPadding -> False
        ],
        MouseAppearanceTag[ "LinkHand" ]
    ],
    "InlineFormula",
    FontFamily -> "Source Sans Pro"
];

hyperlink[ label_String, url_String ] := hyperlink[ formatTextString @ label, url ];

hyperlink[ { label: _String|_StyleBox }, url_ ] := ButtonBox[
    label,
    BaseStyle  -> "Hyperlink",
    ButtonData -> { URL @ url, None },
    ButtonNote -> url
];

hyperlink[ a_, ___ ] := a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInteractiveCodeCell*)
makeInteractiveCodeCell // beginDefinition;

makeInteractiveCodeCell[ string_String ] /; $dynamicText :=
    Cell[
        BoxData @ string,
        "Input",
        Background           -> GrayLevel[ 0.95 ],
        CellFrame            -> GrayLevel[ 0.99 ],
        FontSize             -> $birdFontSize,
        ShowAutoStyles       -> False,
        ShowStringCharacters -> True,
        ShowSyntaxStyles     -> True,
        LanguageCategory     -> "Input"
    ];

makeInteractiveCodeCell[ string_String ] :=
    Module[ { display, handler },

        display = RawBoxes @ Cell[
            BoxData @ string,
            "Input",
            Background           -> GrayLevel[ 0.95 ],
            CellFrame            -> GrayLevel[ 0.99 ],
            CellFrameMargins     -> 5,
            FontSize             -> $birdFontSize,
            ShowAutoStyles       -> True,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True,
            LanguageCategory     -> "Input"
        ];

        handler = inlineInteractiveCodeCell[ display, string ];

        Cell @ BoxData @ ToBoxes @ handler
    ];

makeInteractiveCodeCell[ lang_String, code_String ] :=
    Module[ { cell, display, handler },
        cell = Cell[ code, "ExternalLanguage", FontSize -> $birdFontSize, System`CellEvaluationLanguage -> lang ];
        display = RawBoxes @ cell;
        handler = inlineInteractiveCodeCell[ display, cell ];
        Cell @ BoxData @ ToBoxes @ handler
    ];

makeInteractiveCodeCell // endDefinition;


inlineInteractiveCodeCell // beginDefinition;

inlineInteractiveCodeCell[ display_, string_ ] /; $dynamicText := display;

inlineInteractiveCodeCell[ display_, string_String ] /; CloudSystem`$CloudNotebooks :=
    Button[ display, CellPrint @ Cell[ BoxData @ string, "Input" ], Appearance -> None ];

inlineInteractiveCodeCell[ display_, cell_Cell ] /; CloudSystem`$CloudNotebooks :=
    Button[ display, CellPrint @ cell, Appearance -> None ];

inlineInteractiveCodeCell[ display_, string_ ] :=
    inlineInteractiveCodeCell[ display, string, contentLanguage @ string ];

inlineInteractiveCodeCell[ display_, string_, lang_ ] :=
    DynamicModule[ { attached },
        EventHandler[
            display,
            {
                "MouseEntered" :>
                    If[ TrueQ @ $birdChatLoaded,
                        attached =
                            AttachCell[
                                EvaluationCell[ ],
                                floatingButtonGrid[ attached, string, lang ],
                                { Left, Bottom },
                                0,
                                { Left, Top },
                                RemovalConditions -> { "MouseClickOutside", "MouseExit" }
                            ]
                    ]
            }
        ],
        TaggingRules -> <| "CellToStringData" -> string |>
    ];

inlineInteractiveCodeCell // endDefinition;


floatingButtonGrid // Attributes = { HoldFirst };
floatingButtonGrid[ attached_, string_, lang_ ] := Framed[
    Grid[
        {
            {
                button[ $copyToClipboardButtonLabel, NotebookDelete @ attached; CopyToClipboard @ string ],
                button[ $insertInputButtonLabel, insertCodeBelow[ string, False ]; NotebookDelete @ attached ],
                button[ evaluateLanguageLabel @ lang, insertCodeBelow[ string, True ]; NotebookDelete @ attached ]
            }
        },
        Alignment -> Top,
        Spacings  -> 0
    ],
    Background     -> GrayLevel[ 0.9764705882352941 ],
    RoundingRadius -> 2,
    FrameMargins   -> 3,
    FrameStyle     -> GrayLevel[ 0.82 ]
];

insertCodeBelow[ cell_Cell, evaluate_: False ] :=
    Module[ { cellObj, nbo },
        cellObj = topParentCell @ EvaluationCell[ ];
        nbo  = parentNotebook @ cellObj;
        SelectionMove[ cellObj, After, Cell ];
        NotebookWrite[ nbo, cell, All ];
        If[ TrueQ @ evaluate,
            SelectionEvaluateCreateCell @ nbo,
            SelectionMove[ nbo, After, CellContents ]
        ]
    ];

insertCodeBelow[ string_String, evaluate_: False ] := insertCodeBelow[ Cell[ BoxData @ string, "Input" ], evaluate ];


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*contentLanguage*)
contentLanguage // ClearAll;
contentLanguage[ Cell[ __, "CellEvaluationLanguage" -> lang_String, ___ ] ] := lang;
contentLanguage[ Cell[ __, System`CellEvaluationLanguage -> lang_String, ___ ] ] := lang;
contentLanguage[ ___ ] := "Wolfram";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*topParentCell*)
topParentCell // beginDefinition;
topParentCell[ cell_CellObject ] := With[ { p = ParentCell @ cell }, topParentCell @ p /; MatchQ[ p, _CellObject ] ];
topParentCell[ cell_CellObject ] := cell;
topParentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toCodeString*)
toCodeString // beginDefinition;

toCodeString[ s_String ] :=
    Enclose @ Module[ { boxes, styled },
        boxes  = RawBoxes @ Confirm @ Quiet @ stringTemplateInput @ s;
        styled = Style[ boxes, "InlineFormula", ShowAutoStyles -> True, ShowStringCharacters -> True ];
        ConfirmBy[ ToString[ styled, StandardForm ], StringQ ]
    ];

toCodeString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stringTemplateInput*)
stringTemplateInput // ClearAll;

stringTemplateInput[ s_String? StringQ ] :=
    UsingFrontEnd @ Enclose @ Confirm[ stringTemplateInput0 ][ s ];

stringTemplateInput[ ___ ] := $Failed;

stringTemplateInput0 // ClearAll;
stringTemplateInput0 := Enclose[
    Needs[ "DefinitionNotebookClient`" -> None ];
    ConfirmMatch[
        DefinitionNotebookClient`StringTemplateInput[ "x" ],
        Except[ _DefinitionNotebookClient`StringTemplateInput ]
    ];
    stringTemplateInput0 = DefinitionNotebookClient`StringTemplateInput
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$apiKeys*)
$apiKeys = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toAPIKey*)
toAPIKey // beginDefinition;

toAPIKey[ key_String ] := key;

toAPIKey[ Automatic ] := toAPIKey[ Automatic, None ];

toAPIKey[ Automatic, id_ ] := checkAPIKey @ FirstCase[
    Unevaluated @ {
        $apiKeys[ id ],
        SystemCredential[ "OPENAI_API_KEY" ],
        Environment[ "OPENAI_API_KEY" ],
        apiKeyDialog[ ]
    },
    e_ :> With[ { key = e }, key /; StringQ @ key ],
    throwFailure[ "NoAPIKey" ]
];

toAPIKey[ other___ ] := throwFailure[ "InvalidAPIKey", other ];

toAPIKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkAPIKey*)
checkAPIKey // beginDefinition;
checkAPIKey[ key_String ] /; MatchQ[ getModelList @ key, { __String } ] := checkAPIKey[ key ] = key;
checkAPIKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*apiKeyDialog*)
apiKeyDialog // beginDefinition;

apiKeyDialog[ ] :=
    Enclose @ Module[ { result, key },
        result = ConfirmBy[ showAPIKeyDialog[ ], AssociationQ ];
        key    = ConfirmBy[ result[ "APIKey" ], StringQ ];

        If[ result[ "Save" ], SystemCredential[ "OPENAI_API_KEY" ] = key ];

        key
    ];

apiKeyDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showAPIKeyDialog*)
showAPIKeyDialog // beginDefinition;

showAPIKeyDialog[ ] := AuthenticationDialog[
    FormObject[
        {
            "APIKey" -> <|
                "Masked"  -> True,
                "Label"   -> "API Key",
                "Control" -> Function[
                    InputField[
                        ##,
                        FieldMasked           -> True,
                        FieldHint             -> "sk-...XXXX",
                        DefaultBaseStyle      -> "FormField",
                        DefaultFieldHintStyle -> "FormFieldHint",
                        ImageSize             -> { Scaled[ 1 ], Automatic }
                    ]
                ]
            |>,
            "Save" -> <| "Interpreter" -> "Boolean" |>
        },
        AppearanceRules -> {
            "Title"       -> "Please enter your OpenAI API key",
            "Description" -> $apiKeyDialogDescription
        }
    ],
    WindowSize     -> { 400, All },
    WindowElements -> { "StatusArea" }
];

showAPIKeyDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cell to String Conversion*)

(* TODO: use Wolfram`Chatbook`Serialization`CellToString *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Config*)
$$delimiterStyle   = "PageBreak"|"ExampleDelimiter";
$$itemStyle        = "Item"|"Notes";
$$noCellLabelStyle = "ChatInput"|"ChatUserInput"|"ChatSystemInput"|"ChatContextDivider"|$$delimiterStyle;
$$docSearchStyle   = "ChatQuery";

(* Default character encoding for strings created from cells *)
$cellCharacterEncoding = "Unicode";

(* Set a max string length for output cells to avoid blowing up token counts *)
$maxOutputCellStringLength = 500;

(* Set a page width for expressions that need to be serialized as InputForm *)
$cellPageWidth = 100;

(* Whether to collect data that can help discover missing definitions *)
$cellToStringDebug = False;

(* Can be redefined locally depending on cell style *)
$showStringCharacters = True;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Conversion Rules*)

(* Rules to convert some 2D boxes into an infix form *)
$boxOp = <| SuperscriptBox -> "^", SubscriptBox -> "_" |>;

(* How to choose TemplateBox arguments for serialization *)
$templateBoxRules = <|
    "DateObject"       -> First,
    "HyperlinkDefault" -> First,
    "RefLink"          -> First,
    "RowDefault"       -> Identity
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Patterns*)

$boxOperators = Alternatives @@ Keys @ $boxOp;

$graphicsHeads = Alternatives[
    GraphicsBox,
    RasterBox,
    NamespaceBox,
    Graphics3DBox
];

(* Serialize the first argument of these and ignore the rest *)
$stringStripHeads = Alternatives[
    ButtonBox,
    CellGroupData,
    FormBox,
    FrameBox,
    ItemBox,
    PanelBox,
    RowBox,
    StyleBox,
    TagBox,
    TextData,
    TooltipBox
];

(* Boxes that should be ignored during serialization *)
$ignoredBoxPatterns = Alternatives[
    _CheckboxBox,
    _PaneSelectorBox,
    StyleBox[ _GraphicsBox, ___, "NewInGraphic", ___ ],
    Cell[ __, "ObjectNameTranslation", ___ ]
];

(* CellEvaluationLanguage appears to not be System` at startup, so use this for matching as a precaution *)
$$cellEvaluationLanguage = Alternatives[
    "CellEvaluationLanguage",
    _Symbol? (Function[
        Null,
        AtomQ @ Unevaluated @ # && SymbolName @ Unevaluated @ # === "CellEvaluationLanguage",
        HoldFirst
    ])
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Templates*)

(* Helper function to define string templates that handle WL (with backticks) *)
codeTemplate[ template_String? StringQ ] := StringTemplate[ template, Delimiters -> "%%" ];
codeTemplate[ template_ ] := template;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Stack Trace for Message Cells*)
$stackTraceTemplate = codeTemplate[ "\
%%String%%
BEGIN_STACK_TRACE
%%StackTrace%%
END_STACK_TRACE\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Explanation with Search Results*)
$searchQueryTemplate = codeTemplate[ "\
Please explain the following query text to me:
---
%%String%%
---
Try to include information about how this relates to the Wolfram Language if it makes sense to do so.

If there are any relevant search results, feel free to use them in your explanation. Do not include search results \
that are not relevant to the query.

%%SearchResults%%\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Wolfram Alpha Input*)
$wolframAlphaInputTemplate = codeTemplate[ "\
WolframAlpha[\"%%Query%%\"]

WOLFRAM_ALPHA_PARSED_INPUT: %%Code%%

" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellToString*)
cellToString // ClearAll;

(* Argument normalization *)
cellToString[ data: _TextData|_BoxData|_RawData ] := cellToString @ Cell @ data;
cellToString[ string_String? StringQ ] := cellToString @ Cell @ string;
cellToString[ cell_CellObject ] := cellToString @ NotebookRead @ cell;

(* Multiple cells to one string *)
cellToString[ Notebook[ cells_List, ___ ] ] := cellsToString @ cells;
cellToString[ Cell @ CellGroupData[ cells_List, _ ] ] := cellsToString @ cells;
cellToString[ nbo_NotebookObject ] := cellToString @ Cells @ nbo;
cellToString[ cells: { __CellObject } ] := cellsToString @ NotebookRead @ cells;

(* Drop cell label for some styles *)
cellToString[ Cell[ a__, $$noCellLabelStyle, b___, CellLabel -> _, c___ ] ] :=
    cellToString @ Cell[ a, b, c ];

(* Convert delimiters to equivalent markdown *)
cellToString[ Cell[ __, $$delimiterStyle, ___ ] ] := "\n---\n";

(* Styles that should include documentation search *)
cellToString[ Cell[ a__, $$docSearchStyle, b___ ] ] :=
    TemplateApply[
        $searchQueryTemplate,
        <|
            "String" -> cellToString @ DeleteCases[ Cell[ a, b ], CellLabel -> _ ],
            "SearchResults" -> docSearchResultString @ a
        |>
    ];

(* Prepend cell label to the cell string *)
cellToString[ Cell[ a___, CellLabel -> label_String, b___ ] ] :=
    With[ { str = cellToString @ Cell[ a, b ] }, label<>" "<>str /; StringQ @ str ];

(* Item styles *)
cellToString[ Cell[ a___, $$itemStyle, b___ ] ] :=
    With[ { str = cellToString @ Cell[ a, "Text", b ] },
        " * "<>str /; StringQ @ str
    ];

(* Cells showing raw data (ctrl-shift-e) *)
cellToString[ Cell[ RawData[ str_String ], ___ ] ] := str;

(* Include a stack trace for message cells when available *)
cellToString[ Cell[ a_, "Message", "MSG", b___ ] ] :=
    Module[ { string, stacks, stack, stackString },
        { string, stacks } = Reap[ cellToString0 @ Cell[ a, b ], $messageStack ];
        stack = First[ First[ stacks, $Failed ], $Failed ];
        If[ MatchQ[ stack, { __HoldForm } ] && Length @ stack >= 3
            ,
            stackString = StringRiffle[
                Cases[
                    stack,
                    HoldForm[ expr_ ] :> truncateStackString @ ToString[
                        Unevaluated @ expr,
                        InputForm,
                        CharacterEncoding -> $cellCharacterEncoding
                    ]
                ],
                "\n"
            ];
            TemplateApply[
                $stackTraceTemplate,
                <| "String" -> string, "StackTrace" -> stackString |>
            ]
            ,
            string
        ]
    ];

(* External language cells get converted to an equivalent ExternalEvaluate input *)
cellToString[ Cell[ code_, "ExternalLanguage", ___, $$cellEvaluationLanguage -> lang_String, ___ ] ] :=
    Module[ { string },
        string = cellToString0 @ code;
        "ExternalEvaluate[\""<>lang<>"\", \""<>string<>"\"]" /; StringQ @ string
    ];

(* Cached source string *)
cellToString[ _[ __, TaggingRules -> KeyValuePattern[ "CellToStringData" -> data_ ], ___ ] ] :=
    cellToString0 @ data;

(* Begin recursive serialization of the cell content *)
cellToString[ cell_ ] := cellToString0 @ cell;

cellToString0[ cell_ ] :=
    With[ { string = fasterCellToString @ cell },
        If[ StringQ @ string,
            string,
            slowCellToString @ cell
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellsToString*)
cellsToString // beginDefinition;

cellsToString[ cells_List ] :=
    With[ { strings = cellToString /@ cells },
        StringRiffle[ Select[ strings, StringQ ], "\n\n" ]
    ];

cellsToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sowMessageData*)
sowMessageData // ClearAll;

sowMessageData[ { _, _, _, _, line_Integer, counter_Integer, session_Integer, _ } ] :=
    With[ { stack = $lastStack = MessageMenu`MessageStackList[ line, counter, session ] },
        Sow[ stack, $messageStack ] /; MatchQ[ stack, { ___HoldForm } ]
    ];

sowMessageData[ ___ ] := Null;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fasterCellToString*)
fasterCellToString // beginDefinition;

fasterCellToString[ arg_ ] :=
    Block[ { $catchingStringFail = True },
        Catch[
            Module[ { string },
                string = fasterCellToString0 @ arg;
                If[ StringQ @ string,
                    Replace[ StringTrim @ string, "" -> Missing[ "NotFound" ] ],
                    $Failed
                ]
            ],
            $stringFail
        ]
    ];

fasterCellToString // endDefinition;


fasterCellToString0 // ClearAll;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Ignored/Skipped*)

fasterCellToString0[ $ignoredBoxPatterns ] := "";
fasterCellToString0[ $stringStripHeads[ a_, ___ ] ] := fasterCellToString0 @ a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*String Normalization*)

(* Add spacing between RowBox elements that are comma separated *)
fasterCellToString0[ "," ] := ", ";

(* IndentingNewline *)
fasterCellToString0[ FromCharacterCode[ 62371 ] ] := "\n\t";

(* StandardForm strings *)
fasterCellToString0[ a_String /; StringMatchQ[ a, "\""~~___~~("\\!"|"\!")~~___~~"\"" ] ] :=
    With[ { res = ToString @ ToExpression[ a, InputForm ] },
        If[ TrueQ @ $showStringCharacters,
            res,
            StringTrim[ res, "\"" ]
        ] /; FreeQ[ res, s_String /; StringContainsQ[ s, ("\\!"|"\!") ] ]
    ];

fasterCellToString0[ a_String /; StringContainsQ[ a, ("\\!"|"\!") ] ] :=
    With[ { res = stringToBoxes @ a }, res /; FreeQ[ res, s_String /; StringContainsQ[ s, ("\\!"|"\!") ] ] ];

(* Other strings *)
fasterCellToString0[ a_String ] :=
    ToString[
        If[ TrueQ @ $showStringCharacters, a, StringTrim[ a, "\"" ] ],
        CharacterEncoding -> $cellCharacterEncoding
    ];

fasterCellToString0[ a: { ___String } ] := StringJoin[ fasterCellToString0 /@ a ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Wolfram Alpha Input*)

fasterCellToString0[ NamespaceBox[
    "WolframAlphaQueryParseResults",
    DynamicModuleBox[
        { OrderlessPatternSequence[ Typeset`q$$ = query_String, Typeset`chosen$$ = code_String, ___ ] },
        ___
    ],
    ___
] ] := TemplateApply[ $wolframAlphaInputTemplate, <| "Query" -> query, "Code" -> code |> ];

fasterCellToString0[ NamespaceBox[
    "WolframAlphaQueryParseResults",
    DynamicModuleBox[ { ___, Typeset`chosen$$ = code_String, ___ }, ___ ],
    ___
] ] := code;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Graphics*)
fasterCellToString0[ box: $graphicsHeads[ ___ ] ] :=
    If[ TrueQ[ ByteCount @ box < $maxOutputCellStringLength ],
        (* For relatively small graphics expressions, we'll give an InputForm string *)
        makeGraphicsString @ box,
        (* Otherwise, give the same thing you'd get in a standalone kernel*)
        "-Graphics-"
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Template Boxes*)

(* Messages *)
fasterCellToString0[ TemplateBox[ args: { _, _, str_String, ___ }, "MessageTemplate" ] ] := (
    sowMessageData @ args; (* Look for stack trace data *)
    fasterCellToString0 @ str
);

(* Row *)
fasterCellToString0[ TemplateBox[ args_, "RowDefault", ___ ] ] := fasterCellToString0 @ args;

(* Tooltips *)
fasterCellToString0[ TemplateBox[ { a_, ___ }, "PrettyTooltipTemplate", ___ ] ] := fasterCellToString0 @ a;

(* Control-Equal Input *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "boxes" -> box_ ], "LinguisticAssistantTemplate" ] ] :=
    fasterCellToString0 @ box;

(* NotebookObject *)
fasterCellToString0[
    TemplateBox[ KeyValuePattern[ "label" -> label_String ], "NotebookObjectUUIDsUnsaved"|"NotebookObjectUUIDs" ]
] := "NotebookObject["<>label<>"]";

(* Entity *)
fasterCellToString0[ TemplateBox[ { _, box_, ___ }, "Entity" ] ] := fasterCellToString0 @ box;
fasterCellToString0[ TemplateBox[ { _, box_, ___ }, "EntityProperty" ] ] := fasterCellToString0 @ box;

(* Spacers *)
fasterCellToString0[ TemplateBox[ _, "Spacer1" ] ] := " ";

(* Other *)
fasterCellToString0[ TemplateBox[ args_, name_String, ___ ] ] :=
    With[ { s = fasterCellToString0 @ $templateBoxRules[ name ][ args ] },
        s /; StringQ @ s
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Math Boxes*)

(* Sqrt *)
fasterCellToString0[ SqrtBox[ a_ ] ] :=
    "Sqrt["<>fasterCellToString0 @ a<>"]";

(* Fraction *)
fasterCellToString0[ FractionBox[ a_, b_ ] ] :=
    "(" <> fasterCellToString0 @ a <> "/" <> fasterCellToString0 @ b <> ")";

(* Other *)
fasterCellToString0[ (box: $boxOperators)[ a_, b_ ] ] :=
    Module[ { a$, b$ },
        a$ = fasterCellToString0 @ a;
        b$ = fasterCellToString0 @ b;
        If[ StringQ @ a$ && StringQ @ b$,
            a$ <> $boxOp @ box <> b$,
            { a$, b$ }
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Other*)

fasterCellToString0[ BoxData[ boxes_List ] ] :=
    With[ { strings = fasterCellToString0 /@ boxes },
        StringRiffle[ strings, "\n" ] /; AllTrue[ strings, StringQ ]
    ];

fasterCellToString0[ BoxData[ boxes_ ] ] :=
    fasterCellToString0 @ boxes;

fasterCellToString0[ list_List ] :=
    With[ { strings = fasterCellToString0 /@ list },
        StringJoin @ strings /; AllTrue[ strings, StringQ ]
    ];

fasterCellToString0[ cell: Cell[ a_, ___ ] ] :=
    Block[ { $showStringCharacters = showStringCharactersQ @ cell }, fasterCellToString0 @ a ];

fasterCellToString0[ InterpretationBox[ _, expr_, ___ ] ] :=
    ToString[
        Unevaluated @ expr,
        InputForm,
        PageWidth         -> $cellPageWidth,
        CharacterEncoding -> $cellCharacterEncoding
    ];

fasterCellToString0[ GridBox[ grid_? MatrixQ, ___ ] ] :=
    Module[ { strings, tr, colSizes },
        strings = Map[ fasterCellToString0, grid, { 2 } ];
        (
            tr = Transpose @ strings;
            colSizes = Max /@ Map[ StringLength, tr, { 2 } ];
            StringRiffle[
                StringRiffle /@ Transpose @ Apply[
                    StringPadRight,
                    Transpose @ { tr, colSizes },
                    { 1 }
                ],
                "\n"
            ]
        ) /; AllTrue[ strings, StringQ, 2 ]
    ];

fasterCellToString0[ Cell[ TextData @ { _, _, text_String, _, Cell[ _, "ExampleCount", ___ ] }, ___ ] ] :=
    fasterCellToString0 @ text;

fasterCellToString0[ _[
    __,
    TaggingRules -> Association @ OrderlessPatternSequence[ "CellToStringData" -> data_, ___ ],
    ___
] ] := fasterCellToString0 @ data;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Missing Definition*)
fasterCellToString0[ a___ ] := (
    If[ TrueQ @ $cellToStringDebug, Internal`StuffBag[ $fasterCellToStringFailBag, HoldComplete @ a ] ];
    If[ TrueQ @ $catchingStringFail, Throw[ $Failed, $stringFail ], "" ]
);

$fasterCellToStringFailBag := $fasterCellToStringFailBag = Internal`Bag[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*truncateStackString*)
truncateStackString // beginDefinition;
truncateStackString[ str_String ] /; StringLength @ str <= 80 := str;
truncateStackString[ str_String ] := StringTake[ str, 80 ] <> "...";
truncateStackString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeGraphicsString*)
makeGraphicsString // beginDefinition;

makeGraphicsString[ gfx_ ] := makeGraphicsString[ gfx, makeGraphicsExpression @ gfx ];

makeGraphicsString[ gfx_, HoldComplete[ expr: _Graphics|_Graphics3D|_Image|_Image3D|_Graph ] ] :=
    StringReplace[
        ToString[
            Unevaluated @ expr,
            InputForm,
            PageWidth         -> $cellPageWidth,
            CharacterEncoding -> $cellCharacterEncoding
        ],
        "\r\n" -> "\n"
    ];

makeGraphicsString[
    GraphicsBox[
        NamespaceBox[ "NetworkGraphics", DynamicModuleBox[ { ___, _ = HoldComplete @ Graph[ a___ ], ___ }, ___ ] ],
        ___
    ],
    _
] := "Graph[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ GraphicsBox[ a___ ], _ ] :=
    "Graphics[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ Graphics3DBox[ a___ ], _ ] :=
    "Graphics3D[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ RasterBox[ a___ ], _ ] :=
    "Image[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ Raster3DBox[ a___ ], _ ] :=
    "Image3D[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeGraphicsExpression*)
makeGraphicsExpression // beginDefinition;
makeGraphicsExpression[ gfx_ ] := Quiet @ Check[ ToExpression[ gfx, StandardForm, HoldComplete ], $Failed ];
makeGraphicsExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stringToBoxes*)
stringToBoxes // beginDefinition;

stringToBoxes[ s_String /; StringMatchQ[ s, "\"" ~~ __ ~~ "\"" ] ] :=
    With[ { str = stringToBoxes @ StringTrim[ s, "\"" ] }, "\""<>str<>"\"" /; StringQ @ str ];

stringToBoxes[ string_String ] :=
    stringToBoxes[
        string,
        (* TODO: there could be a kernel implementation of this *)
        Quiet @ UsingFrontEnd @ MathLink`CallFrontEnd @ FrontEnd`UndocumentedTestFEParserPacket[ string, True ]
    ];

stringToBoxes[ string_, { BoxData[ boxes_ ], ___ } ] := boxes;
stringToBoxes[ string_, other_ ] := string;

stringToBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showStringCharactersQ*)
showStringCharactersQ // ClearAll;
showStringCharactersQ[ ___ ] := True;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeGridString*)
makeGridString // beginDefinition;

makeGridString[ grid_ ] :=
    Module[ { tr, colSizes },
        tr = Transpose @ grid;
        colSizes = Max /@ Map[ StringLength, tr, { 2 } ];
        StringRiffle[ StringRiffle /@ Transpose @ Apply[ StringPadRight, Transpose @ { tr, colSizes }, { 1 } ], "\n" ]
    ];

makeGridString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*slowCellToString*)
slowCellToString // beginDefinition;

slowCellToString[ cell_Cell ] :=
    Module[ { format, plain, string },

        format = If[ TrueQ @ $showStringCharacters, "InputText", "PlainText" ];
        plain  = Quiet @ UsingFrontEnd @ FrontEndExecute @ FrontEnd`ExportPacket[ cell, format ];
        string = Replace[ plain, { { s_String? StringQ, ___ } :> s, ___ :> $Failed } ];

        If[ StringQ @ string,
            Replace[ StringTrim[ string, WhitespaceCharacter ], "" -> Missing[ "NotFound" ] ],
            $Failed
        ]
    ];

slowCellToString[ boxes_BoxData ] := slowCellToString @ Cell @ boxes;
slowCellToString[ text_TextData ] := Block[ { $showStringCharacters = False }, slowCellToString @ Cell @ text ];
slowCellToString[ text_String   ] := slowCellToString @ TextData @ text;
slowCellToString[ boxes_        ] := slowCellToString @ BoxData @ boxes;

slowCellToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Documentation Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*docSearchResultString*)
docSearchResultString // ClearAll;

docSearchResultString[ query_String ] := Enclose[
    Module[ { search },
        search = ConfirmMatch[ documentationSearch @ query, { __String } ];
        StringJoin[
            "BEGIN_SEARCH_RESULTS\n",
            StringRiffle[ search, "\n" ],
            "\nEND_SEARCH_RESULTS"
        ]
    ],
    $noDocSearchResultsString &
];


docSearchResultString[ other_ ] :=
    With[ { str = cellToString @ other }, documentationSearch @ str /; StringQ @ str ];

docSearchResultString[ ___ ] := $noDocSearchResultsString;


documentationSearch[ query_String ] /; $localDocSearch := documentationSearch[ query ] =
    Module[ { result },
        Needs[ "DocumentationSearch`" -> None ];
        result = Association @ DocumentationSearch`SearchDocumentation[
            query,
            "MetaData" -> { "Title", "URI", "ShortenedSummary", "Score" },
            "Limit"    -> 5
        ];
        makeSearchResultString /@ Cases[
            result[ "Matches" ],
            { title_, uri_String, summary_, score_ } :>
                { title, "paclet:"<>StringTrim[ uri, "paclet:" ], summary, score }
        ]
    ];

documentationSearch[ query_String ] := documentationSearch[ query ] =
    Module[ { resp, flat, items },

        resp = URLExecute[
            "https://search.wolfram.com/search-api/search.json",
            {
                "query"           -> query,
                "limit"           -> "5",
                "disableSpelling" -> "true",
                "fields"          -> "title,summary,url,label",
                "collection"      -> "blogs,demonstrations,documentation10,mathworld,resources,wa_products"
            },
            "RawJSON"
        ];

        flat = Take[
            ReverseSortBy[ Flatten @ Values @ KeyTake[ resp[ "results" ], resp[ "sortOrder" ] ], #score & ],
            UpTo[ 5 ]
        ];

        items = Select[ flat, #score > 1 & ];

        makeSearchResultString /@ items
    ];


makeSearchResultString // ClearAll;

makeSearchResultString[ { title_, uri_String, summary_, score_ } ] :=
    TemplateApply[
        "* [`1`](`2`) - (score: `4`) `3`",
        { title, uri, summary, score }
    ];


makeSearchResultString[ KeyValuePattern[ "ad" -> True ] ] := Nothing;

makeSearchResultString[ KeyValuePattern @ { "fields" -> fields_Association, "score" -> score_ } ] :=
    makeSearchResultString @ Replace[
        Append[ fields, "score" -> score ],
        { s_String, ___ } :> s,
        { 1 }
    ];


makeSearchResultString[ KeyValuePattern @ {
    "summary" -> summary_String,
    "title"   -> name_String,
    "label"   -> "Built-in Symbol"|"Entity Type"|"Featured Example"|"Guide"|"Import/Export Format"|"Tech Note",
    "uri"     -> uri_String,
    "score"   -> score_
} ] := TemplateApply[
    "* [`1`](`2`) - (score: `4`) `3`",
    { name, "paclet:"<>StringTrim[ uri, "paclet:" ], summary, score }
];

makeSearchResultString[ KeyValuePattern @ {
    "summary" -> summary_String,
    "title"   -> name_String,
    "url"     -> url_String,
    "score"   -> score_
} ] := TemplateApply[ "* [`1`](`2`) - (score: `4`) `3`", { name, url, summary, score } ];


$noDocSearchResultsString = "BEGIN_DOCUMENTATION_SEARCH_RESULTS\n(no results found)\nEND_DOCUMENTATION_SEARCH_RESULTS";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getUsageString*)
getUsageString // beginDefinition;

getUsageString[ nb_Notebook ] := makeUsageString @ cellCases[
    firstMatchingCellGroup[ nb, Cell[ __, "ObjectNameGrid", ___ ], All ],
    Cell[ __, "ObjectNameGrid"|"Usage", ___ ]
];

getUsageString // endDefinition;


makeUsageString // beginDefinition;

makeUsageString[ usage_List ] := StringRiffle[ Flatten[ makeUsageString /@ usage ], "\n" ];

makeUsageString[ Cell[ BoxData @ GridBox[ grid_List, ___ ], "Usage", ___ ] ] := makeUsageString0 /@ grid;

makeUsageString[ Cell[ BoxData @ GridBox @ { { cell_, _ } }, "ObjectNameGrid", ___ ] ] :=
    "# " <> cellToString @ cell <> "\n";

makeUsageString // endDefinition;

makeUsageString0 // beginDefinition;
makeUsageString0[ list_List ] := StringTrim @ StringReplace[ StringRiffle[ cellToString /@ list ], Whitespace :> " " ];
makeUsageString0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getDetailsString*)
getDetailsString // beginDefinition;

getDetailsString[ nb_Notebook ] :=
    Module[ { notes },
        notes = cellToString /@ cellFlatten @ firstMatchingCellGroup[ nb, Cell[ __, "NotesSection", ___ ] ];
        If[ MatchQ[ notes, { __String } ],
            "## Notes\n\n" <> StringRiffle[ notes, "\n" ],
            ""
        ]
    ];

getDetailsString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getExamplesString*)
getExamplesString // beginDefinition;

getExamplesString[ nb_Notebook ] :=
    Module[ { examples },
        examples = cellToString /@ cellFlatten @ firstMatchingCellGroup[
            nb,
            Cell[ __, "PrimaryExamplesSection", ___ ]
        ];
        If[ MatchQ[ examples, { __String } ],
            "## Examples\n\n" <> StringRiffle[ examples, "\n" ],
            ""
        ]
    ];

getExamplesString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cell Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellMap*)
cellMap // beginDefinition;
cellMap[ f_, cells_List ] := (cellMap[ f, #1 ] &) /@ cells;
cellMap[ f_, Cell[ CellGroupData[ cells_, a___ ], b___ ] ] := Cell[ CellGroupData[ cellMap[ f, cells ], a ], b ];
cellMap[ f_, cell_Cell ] := f @ cell;
cellMap[ f_, Notebook[ cells_, opts___ ] ] := Notebook[ cellMap[ f, cells ], opts ];
cellMap[ f_, other_ ] := other;
cellMap // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellGroupMap*)
cellGroupMap // beginDefinition;
cellGroupMap[ f_, Notebook[ cells_, opts___ ] ] := Notebook[ cellGroupMap[ f, cells ], opts ];
cellGroupMap[ f_, cells_List ] := Map[ cellGroupMap[ f, # ] &, cells ];
cellGroupMap[ f_, Cell[ group_CellGroupData, a___ ] ] := Cell[ cellGroupMap[ f, f @ group ], a ];
cellGroupMap[ f_, other_ ] := other;
cellGroupMap // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellScan*)
cellScan // ClearAll;
cellScan[ f_, Notebook[ cells_, opts___ ] ] := cellScan[ f, cells ];
cellScan[ f_, cells_List ] := Scan[ cellScan[ f, # ] &, cells ];
cellScan[ f_, Cell[ CellGroupData[ cells_, _ ], ___ ] ] := cellScan[ f, cells ];
cellScan[ f_, cell_Cell ] := (f @ cell; Null);
cellScan[ ___ ] := Null;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellGroupScan*)
cellGroupScan // ClearAll;
cellGroupScan[ f_, Notebook[ cells_, opts___ ] ] := cellGroupScan[ f, cells ];
cellGroupScan[ f_, cells_List ] := Scan[ cellGroupScan[ f, # ] &, cells ];
cellGroupScan[ f_, Cell[ group_CellGroupData, ___ ] ] := (f @ group; cellGroupScan[ f, group ]);
cellGroupScan[ ___ ] := Null;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellCases*)
cellCases // beginDefinition;
cellCases[ cells_, patt_ ] := Cases[ cellFlatten @ cells, patt ];
cellCases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellFlatten*)
cellFlatten // beginDefinition;

cellFlatten[ cells_ ] :=
    Module[ { bag },
        bag = Internal`Bag[ ];
        cellScan[ Internal`StuffBag[ bag, # ] &, cells ];
        Internal`BagPart[ bag, All ]
    ];

cellFlatten // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*firstMatchingCellGroup*)
firstMatchingCellGroup // beginDefinition;

firstMatchingCellGroup[ nb_, patt_ ] := firstMatchingCellGroup[ nb, patt, "Content" ];

firstMatchingCellGroup[ nb_, patt_, All ] := Catch[
    cellGroupScan[
        Replace[ CellGroupData[ { header: patt, content___ }, _ ] :> Throw[ { header, content }, $cellGroupTag ] ],
        nb
    ];
    Missing[ "NotFound" ],
    $cellGroupTag
];

firstMatchingCellGroup[ nb_, patt_, "Content" ] := Catch[
    cellGroupScan[
        Replace[ CellGroupData[ { patt, content___ }, _ ] :> Throw[ { content }, $cellGroupTag ] ],
        nb
    ];
    Missing[ "NotFound" ],
    $cellGroupTag
];

firstMatchingCellGroup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error handling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*catchTop*)
catchTop // beginDefinition;
catchTop // Attributes = { HoldFirst };

catchTop[ eval_ ] :=
    Block[ { $catching = True, $failed = False, catchTop = # & },
        Catch[ eval, $top ]
    ];

catchTop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*throwFailure*)
throwFailure // beginDefinition;
throwFailure // Attributes = { HoldFirst };

throwFailure[ tag_String, params___ ] :=
    throwFailure[ MessageName[ AIAssistant, tag ], params ];

throwFailure[ msg_, args___ ] :=
    Module[ { failure },
        failure = messageFailure[ msg, Sequence @@ HoldForm /@ { args } ];
        If[ TrueQ @ $catching,
            Throw[ failure, $top ],
            failure
        ]
    ];

throwFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageFailure*)
messageFailure // beginDefinition;
messageFailure // Attributes = { HoldFirst };

messageFailure[ args___ ] :=
    Module[ { quiet },
        quiet = If[ TrueQ @ $failed, Quiet, Identity ];
        WithCleanup[
            StackInhibit @ quiet @ messageFailure0[ args ],
            $failed = True
        ]
    ];

messageFailure // endDefinition;

messageFailure0 := messageFailure0 = ResourceFunction[ "MessageFailure", "Function" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*throwInternalFailure*)
throwInternalFailure // beginDefinition;
throwInternalFailure // Attributes = { HoldFirst };

throwInternalFailure[ eval_, a___ ] :=
    throwFailure[ AIAssistant::Internal, $bugReportLink, HoldForm @ eval, a ];

throwInternalFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$bugReportLink*)
$bugReportLink := Hyperlink[
    "Report this issue \[RightGuillemet]",
    URLBuild @ <|
        "Scheme"   -> "https",
        "Domain"   -> "github.com",
        "Path"     -> { "rhennigan", "ResourceFunctions", "issues", "new" },
        "Query"    -> {
            "title"  -> "[AIAssistant] Insert Title Here",
            "body"   -> bugReportBody[ ],
            "labels" -> "bug,internal"
        }
    |>
];

bugReportBody[ ] := bugReportBody @ $thisResourceInfo;

bugReportBody[ as_Association? AssociationQ ] := $bugBody = TemplateApply[
    $bugReportBodyTemplate,
    Association[
        as,
        "SystemID"              -> $SystemID,
        "KernelVersion"         -> SystemInformation[ "Kernel"  , "Version" ],
        "FrontEndVersion"       -> $frontEndVersion,
        "Notebooks"             -> $Notebooks,
        "EvaluationEnvironment" -> $EvaluationEnvironment,
        "Stack"                 -> $bugReportStack,
        "Settings"              -> $settings
    ]
];


$frontEndVersion :=
    If[ TrueQ @ CloudSystem`$CloudNotebooks,
        Row @ { "Cloud: ", $CloudVersion },
        Row @ { "Desktop: ", UsingFrontEnd @ SystemInformation[ "FrontEnd", "Version" ] }
    ];


$settings :=
    Module[ { settings, assoc },
        settings = CurrentValue @ { TaggingRules, "AIAssistantSettings" };
        assoc = Association @ settings;
        If[ AssociationQ @ assoc,
            ToString @ ResourceFunction[ "ReadableForm" ][ KeyDrop[ assoc, "OpenAIKey" ], "DynamicAlignment" -> True ],
            settings
        ]
    ];


$bugReportBodyTemplate = StringTemplate[ "\
# Description
Describe the issue in detail here.

# Debug Data
| Property | Value |
| --- | --- |
| Name | `%%Name%%` |
| UUID | `%%UUID%%` |
| Version | `%%Version%%` |
| RepositoryLocation | `%%RepositoryLocation%%` |
| FunctionLocation | `%%FunctionLocation%%` |
| KernelVersion | `%%KernelVersion%%` |
| FrontEndVersion | `%%FrontEndVersion%%` |
| Notebooks | `%%Notebooks%%` |
| EvaluationEnvironment | `%%EvaluationEnvironment%%` |
| SystemID | `%%SystemID%%` |

## Settings
```
%%Settings%%
```

## Stack Data
```
%%Stack%%
```",
Delimiters -> "%%"
];


$bugReportStack := $stackString = StringRiffle[
    Replace[
        DeleteAdjacentDuplicates @ Cases[
            $stack = Stack[ _ ],
            HoldForm[ (s_Symbol) | (s_Symbol)[ ___ ] | (s_Symbol)[ ___ ][ ___ ] ] /;
                AtomQ @ Unevaluated @ s && Context @ s === Context @ AIAssistant :>
                    SymbolName @ Unevaluated @ s
        ],
        { a___, "throwInternalFailure", ___ } :> { a }
    ],
    "\n"
];

$thisResourceInfo := FirstCase[
    DownValues @ ResourceSystemClient`Private`resourceInfo,
    HoldPattern[ _ :> info: KeyValuePattern[ "SymbolName" -> Context @ AIAssistant <> "AIAssistant" ] ] :> info,
    <| |>
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Images*)

$languageIcons := $languageIcons = Enclose[
    ExternalEvaluate;
    Select[
        AssociationMap[
            ReleaseHold @ ExternalEvaluate`Private`GetLanguageRules[ #1, "Icon" ] &,
            ConfirmMatch[ ExternalEvaluate`Private`GetLanguageRules[ ], _List ]
        ],
        MatchQ[ _Graphics|_Image ]
    ],
    <| |> &
];


activeChatIcon // ClearAll;

activeChatIcon[ ] := activeChatIcon[ GrayLevel[ 0.4 ] ];
activeChatIcon[ fg_ ] := activeChatIcon[ fg, White ];
activeChatIcon[ fg_, bg_ ] := activeChatIcon[ fg, bg, 16 ];

activeChatIcon[ fg_, bg_, size_ ] :=
    Graphics[
        {
            fg,
            Thickness[ 0.0082061 ],
            $curves[ "ChatIconBoundary" ],
            bg,
            $curves[ "ChatIconBackground" ],
            Inset[
                ProgressIndicator[ Appearance -> "Necklace", ImageSize -> size / 2 ],
                Offset[ { 0, -6 }, ImageScaled @ { 0.5, 0.8 } ]
            ]
        },
        ImageSize -> size
    ];


staticChatIcon // ClearAll;

staticChatIcon[ ] := staticChatIcon[ GrayLevel[ 0.4 ] ];
staticChatIcon[ fg_ ] := staticChatIcon[ fg, White ];
staticChatIcon[ fg_, bg_ ] := staticChatIcon[ fg, bg, 16 ];

staticChatIcon[ fg_, bg_, size_ ] :=
    Graphics[
        {
            fg,
            Thickness[ 0.0082061 ],
            $curves[ "ChatIconBoundary" ],
            bg,
            $curves[ "ChatIconBackground" ],
            fg,
            $curves[ "ChatIconLines" ]
        },
        ImageSize -> size
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];