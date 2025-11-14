(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`UI`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];


System`LightDark;
System`LightDarkSwitched;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$inputFieldPaneMargins       = { { 5, 5 }, { 0, 5 } };
$inputFieldGridMagnification = Inherited;
$inputFieldOuterBackground   = color @ "NA_ChatInputFieldBackgroundArea";
$initialInlineChatWidth      = Scaled[ 0.85 ];
$initialInlineChatHeight     = UpTo[ 300 ];
$inputFieldBox               = None;
$inlineChatScrollPosition    = 0.0;
$lastScrollPosition          = 0.0;
$maxHistoryItems             = 20;
$messageAuthorImagePadding   = { { 0, 0 }, { 0, 6 } };

$AppType = "WorkspaceChat";

$inputFieldOptions = Sequence[
    Alignment  -> { Automatic, Baseline },
    BoxID      -> "AttachedChatInputField",
    ImageSize  -> { Scaled[ 1 ], Automatic },
    FieldHint  -> tr[ "AttachedChatFieldHint" ],
    BaseStyle  -> { "Text", "TextStyleInputField" }, (* second BaseStyle makes contractions, line wrapping, etc. more text like *)
    Appearance -> "Frameless"
];

$inputFieldFrameOptions = Sequence[
    Alignment    -> { Automatic, Baseline },
    Background   -> color @ "NA_ChatInputFieldBackground",
    FrameMargins -> { { 5, 5 }, { 4, 4 } },
    FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], color @ "NA_ChatInputFieldFrame" ]
];

$actionMenuItemOptions = Sequence[
    BaseStyle      -> { FontColor -> color @ "NA_RaftMenuItemFont", FontSize -> 13 },
    ImageSize      -> Scaled[ 1. ],
    RoundingRadius -> 2
];

$useGravatarImages := useGravatarImagesQ[ ];

$userImageParams = <| "size" -> 40, "default" -> "404", "rating" -> "G" |>;

$defaultUserImage := $defaultUserImage =
    inlineTemplateBoxes @ RawBoxes @ TemplateBox[ { }, "WorkspaceDefaultUserIcon" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SideBar Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSideBarChatDockedCell*)
makeSideBarChatDockedCell // beginDefinition;

makeSideBarChatDockedCell[ ] := With[ { nbo = EvaluationNotebook[ ], sideBarCell = EvaluationCell[ ] },
    Cell[
        BoxData @ ToBoxes @ workspaceChatInitializer @ Framed[
            Grid[
                { {
                    LogChatTiming @ sideBarNewChatButton[ Dynamic @ nbo, Dynamic @ sideBarCell ], (* FIXME: these calling signatures no longer need the Dynamic heads *)
                    Item[ Spacer[ 0 ], ItemSize -> Fit ],
                    LogChatTiming @ sideBarSourcesButton[ Dynamic @ nbo, Dynamic @ sideBarCell ],
                    LogChatTiming @ sideBarHistoryButton[ Dynamic @ nbo, Dynamic @ sideBarCell ],
                    LogChatTiming @ sideBarOpenAsChatbookButton[ Dynamic @ nbo, Dynamic @ sideBarCell ]
                } },
                Alignment -> { Automatic, Center },
                Spacings  -> 0.2
            ],
            Background   -> color @ "NA_Toolbar",
            FrameStyle   -> color @ "NA_Toolbar",
            FrameMargins -> { { 5, 4 }, { 0, 1 } },
            ImageMargins -> 0
        ],
        CellTags      -> "SideBarDockedCell",
        Magnification -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ]
    ]
];

makeSideBarChatDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSideBarChatSubDockedCellExpression*)
makeSideBarChatSubDockedCellExpression // beginDefinition;

makeSideBarChatSubDockedCellExpression[ nbo_NotebookObject, sideBarCell_CellObject, content_ ] := Join[
    DeleteCases[ makeWorkspaceChatSubDockedCellExpression @ content, _[ Magnification | CellTags, _] ], 
    Cell[
        CellTags             -> "SideBarSubDockedCell",
        FontSize             -> 12,
        Magnification        -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ],
        ShowStringCharacters -> False ] ];

makeSideBarChatSubDockedCellExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeSideBarChatSubDockedCell*)
writeSideBarChatSubDockedCell // beginDefinition;

writeSideBarChatSubDockedCell[ nbo_NotebookObject, sideBarCell_CellObject, content_ ] := Enclose[
    Module[ { subDockedCell, lastDockedCell },
        subDockedCell = First[ Cells[ sideBarCell, CellTags -> "SideBarSubDockedCell" ], $Failed ];
        If[ ! FailureQ @ subDockedCell,
            (* if the sub-cell already exists then rewrite it *)
            WithCleanup[
                FrontEndExecute[ {
                    FrontEnd`SetOptions[ sideBarCell, Editable -> True ],
                    FrontEnd`NotebookWrite[ subDockedCell, makeSideBarChatSubDockedCellExpression[ nbo, sideBarCell, content ] ]
                } ]
                ,
                CurrentValue[ sideBarCell, Editable ] = Inherited
            ]
            ,
            (* else, write a new sub-cell after the last docked cell *)
            lastDockedCell = ConfirmMatch[ Last[ Cells[ sideBarCell, CellTags -> "SideBarDockedCell" ], $Failed ], _CellObject, "SideBarDockedCell" ];
            WithCleanup[
                FrontEndExecute[ {
                    FrontEnd`SetOptions[ sideBarCell, Editable -> True ],
                    FrontEnd`SelectionMove[ lastDockedCell, After, Cell ],
                    FrontEnd`NotebookWrite[ nbo, RowBox[ { "\n", makeSideBarChatSubDockedCellExpression[ nbo, sideBarCell, content ] } ] ]
                } ]
                ,
                CurrentValue[ sideBarCell, Editable ] = Inherited
            ]
        ];
        (* TODO: move selection to side bar chat's input field *)
    ],
    throwInternalFailure
]

writeSideBarChatSubDockedCell[ nbo_NotebookObject, sideBarCell_CellObject, WindowTitle ] := writeSideBarChatSubDockedCell[
    nbo,
    sideBarCell,
    Style[
        FE`Evaluate @ FEPrivate`TruncateStringToWidth[
            CurrentValue[ sideBarCell, { TaggingRules, "ConversationTitle" } ],
            "NotebookAssistant`SideBar`ToolbarTitle",
            #,
            Right
        ]&[ AbsoluteCurrentValue[ "ViewSize" ][[1]] - 10 ],
        "NotebookAssistant`SideBar`ToolbarTitle"
    ]
]

writeSideBarChatSubDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeSideBarChatSubDockedCell*)
removeSideBarChatSubDockedCell // beginDefinition;

removeSideBarChatSubDockedCell[ nbo_NotebookObject, sideBarCell_CellObject ] := Module[ { subDockedCell },
    subDockedCell = First[ Cells[ sideBarCell, CellTags -> "SideBarSubDockedCell" ], Missing @ "NoSideBarSubDockedCell" ];
    If[ ! MissingQ @ subDockedCell,
        WithCleanup[
            FrontEndExecute[ {
                FrontEnd`SetOptions[ sideBarCell, Editable -> True ],
                FrontEnd`SelectionMove[ subDockedCell, Before, Cell ],
                FrontEnd`FrontEndToken[ nbo, "DeletePrevious" ], (* remove the newline character before the sub-cell *)
                FrontEnd`NotebookDelete @ subDockedCell } ]
            ,
            CurrentValue[ sideBarCell, Editable ] = Inherited
        ]
    ]
];

removeSideBarChatSubDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeSideBarTopCell*)
removeSideBarTopCell // beginDefinition;

removeSideBarTopCell[ nbo_NotebookObject, sideBarTopCell_CellObject ] := WithCleanup[
    FrontEndExecute[ {
        FrontEnd`SetOptions[ sideBarCell, Editable -> True ],
        FrontEnd`SelectionMove[ sideBarTopCell, Before, Cell ],
        FrontEnd`FrontEndToken[ nbo, "DeletePrevious" ], (* remove the newline character before the top cell *)
        FrontEnd`NotebookDelete @ sideBarTopCell } ]
        ,
    CurrentValue[ sideBarCell, Editable ] = Inherited
];

removeSideBarTopCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeSideBarScrollingContentCell*)
removeSideBarScrollingContentCell // beginDefinition;

removeSideBarScrollingContentCell[ nbo_NotebookObject, sideBarCell_CellObject ] := Module[ { scrollablePaneCell },
    scrollablePaneCell = First[ Cells[ sideBarCell, CellTags -> "SideBarScrollingContentCell" ], Missing @ "NoScrollingSideBarCell" ];
    If[ ! MissingQ @ scrollablePaneCell,
        WithCleanup[
            FrontEndExecute[ {
                FrontEnd`SetOptions[ sideBarCell, Editable -> True ],
                FrontEnd`SelectionMove[ scrollablePaneCell, Before, Cell ],
                FrontEnd`FrontEndToken[ nbo, "DeletePrevious" ], (* remove the newline character before the top cell *)
                FrontEnd`NotebookDelete @ scrollablePaneCell } ]
            ,
            CurrentValue[ sideBarCell, Editable ] = Inherited
        ]
    ]
];

removeSideBarScrollingContentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarScrollingCell*)
sideBarScrollingCell // beginDefinition

sideBarScrollingCell[ nbo_NotebookObject, cells:{ ___Cell } ] :=
Module[ { sideBarCellObj, dockedCellObj, chatInputCellObj },
    sideBarCellObj = sideBarCellObject @ nbo;
    { dockedCellObj, chatInputCellObj } = Pick[ #, MatchQ[ #, "SideBarDockedCell" | "SideBarChatInputCell" ]& /@ CurrentValue[ #, CellTags ] ]& @ Cells[ sideBarCellObj ];

    With[ { sc = sideBarCellObj, cc = chatInputCellObj, dc = dockedCellObj },
        Cell[ BoxData @
            PaneBox[
                RowBox @ Riffle[ cells, "\n" ],
                AppearanceElements -> {},
                ImageSize -> 
                    Dynamic[
                        {
                            Scaled[ 1. ],
                            UpTo @ Round[
                                (AbsoluteCurrentValue[ "ViewSize" ][[2]]
                                - If[ CurrentValue[ PreviousCell[ ], CellTags ] === "SideBarSubDockedCell", AbsoluteCurrentValue[ PreviousCell[ ], { CellSize, 2 } ], 0 ]
                                - AbsoluteCurrentValue[ dc, { CellSize, 2 } ]
                                - AbsoluteCurrentValue[ cc, { CellSize, 2 } ])/(0.85*AbsoluteCurrentValue[ nbo, Magnification ])
                            ] } ],
                Scrollbars -> { False, True }
            ],
            Background    -> color @ "NA_NotebookBackground",
            CellTags      -> "SideBarScrollingContentCell",
            Magnification -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ]
        ] ]
]

sideBarScrollingCell // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarHistoryButton*)
sideBarHistoryButton // beginDefinition;

sideBarHistoryButton[ Dynamic[ nbo_ ], Dynamic[ sideBarCell_ ] ] := Button[
    Block[ { $AppType = "SideBarChat" }, toolbarButtonLabel[ "History" ] ],
    toggleOverlayMenu[ nbo, sideBarCell, "History" ],
    Appearance -> "Suppressed"
];

sideBarHistoryButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarSourcesButton*)
sideBarSourcesButton // beginDefinition;

sideBarSourcesButton[ Dynamic[ nbo_ ], Dynamic[ sideBarCell_ ] ] := Button[
    Block[ { $AppType = "SideBarChat" }, toolbarButtonLabel[ "Sources" ] ],
    toggleOverlayMenu[ nbo, sideBarCell, "Sources" ],
    Appearance -> "Suppressed"
];

sideBarSourcesButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarNewChatButton*)
sideBarNewChatButton // beginDefinition;

sideBarNewChatButton[ Dynamic[ nbo_ ], Dynamic[ sideBarCell_ ] ] :=
    Button[
        Block[ { $AppType = "SideBarChat" }, toolbarButtonLabel[ "New", "New", "New", True ] ]
        ,
        NotebookDelete @ Cells[ nbo, CellStyle -> "AttachedOverlayMenu", AttachedCell -> True ];
        removeSideBarScrollingContentCell[ nbo, sideBarCell ];
        removeSideBarChatSubDockedCell[ nbo, sideBarCell ];
        CurrentChatSettings[ sideBarCell, "ConversationUUID" ] = CreateUUID[ ];
        CurrentValue[ sideBarCell, { TaggingRules, "ConversationTitle" } ] = ""
        ,
        Appearance -> "Suppressed",
        Method     -> "Queued"
    ];

sideBarNewChatButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarOpenAsChatbookButton*)
sideBarOpenAsChatbookButton // beginDefinition;

sideBarOpenAsChatbookButton[ Dynamic[ nbo_ ], Dynamic[ sideBarCell_ ] ] := Button[
    Block[ { $AppType = "SideBarChat" }, toolbarButtonLabel[ "OpenAsChatbook", None ] ],
    NotebookPut @ cellsToChatNB[
        ReplaceRepeated[
            NotebookRead @ Cells[ First[ Cells[ sideBarCell, CellTags -> "SideBarScrollingContentCell" ], {} ], CellTags -> "SideBarTopCell" ], (* fail gracefully *)
            (* so far there's only one TemplateBox that needs to be unconverted *)
            TemplateBox[ a_, b : Alternatives[ "NotebookAssistant`SideBar`ChatCodeBlockTemplate" ], c___] :>
                RuleCondition[ TemplateBox[ a, StringReplace[ b, StartOfString ~~ "NotebookAssistant`SideBar`" -> "", c ] ], True ]
        ],
        CurrentValue[ sideBarCell, { TaggingRules, "ChatNotebookSettings" } ] ],
    Appearance -> "Suppressed",
    Method     -> "Queued"
];

sideBarOpenAsChatbookButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Workspace Chat*)

(* TODO: We'll eventually need to scope this by AppName *)
$WorkspaceChatInput = "";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeWorkspaceChatDockedCell*)
makeWorkspaceChatDockedCell // beginDefinition;

makeWorkspaceChatDockedCell[ ] := workspaceChatInitializer @ Framed[
    DynamicModule[ { nbo },
        Grid[
            { {
                LogChatTiming @ newChatButton @ Dynamic @ nbo,
                Item[ Spacer[ 0 ], ItemSize -> Fit ],
                LogChatTiming @ sourcesButton @ Dynamic @ nbo,
                LogChatTiming @ historyButton @ Dynamic @ nbo,
                LogChatTiming @ openAsChatbookButton @ Dynamic @ nbo
            } },
            Alignment -> { Automatic, Center },
            Spacings  -> 0.2
        ],
        Initialization :> (nbo = EvaluationNotebook[ ])
    ],
    Background   -> color @ "NA_Toolbar",
    FrameStyle   -> color @ "NA_Toolbar",
    FrameMargins -> { { 5, 4 }, { 0, 1 } },
    ImageMargins -> 0
];

makeWorkspaceChatDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeWorkspaceChatSubDockedCellExpression*)
makeWorkspaceChatSubDockedCellExpression // beginDefinition;

makeWorkspaceChatSubDockedCellExpression[ content_ ] := Cell[ BoxData @ ToBoxes @
    Framed[
        content,
        Background   -> color @ "NA_ToolbarTitleBackground",
        FrameMargins -> { { 7, 7 }, { 4, 4 } },
        FrameStyle   -> color @ "NA_ToolbarTitleBackground",
        ImageMargins -> 0,
        ImageSize    -> Scaled[1.]
    ],
    CellFrame          -> 0,
    CellFrameMargins   -> 0,
    CellMargins        -> { { -1, -5 }, { -1, -1 } },
    CellTags           -> "WorkspaceChatSubDockedCell",
    Magnification      -> Dynamic[ AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ] ]
];

makeWorkspaceChatSubDockedCellExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeWorkspaceChatSubDockedCell*)
writeWorkspaceChatSubDockedCell // beginDefinition;

writeWorkspaceChatSubDockedCell[ nbo_NotebookObject, content_ ] := (
CurrentValue[ nbo, DockedCells ] = Inherited;
CurrentValue[ nbo, DockedCells ] = {
    First @ Replace[ AbsoluteCurrentValue[ nbo, DockedCells ], c_Cell :> {c} ],
    makeWorkspaceChatSubDockedCellExpression[ content ] };
    (* Rewriting docked cells seems to steal focus from the chat input field, so restore it here: *)
    If[ SelectedCells @ nbo === { }, moveToChatInputField[ nbo, True ] ]
)

writeWorkspaceChatSubDockedCell[ nbo_NotebookObject, WindowTitle ] := writeWorkspaceChatSubDockedCell[
    nbo,
    Style[
        FE`Evaluate @ FEPrivate`TruncateStringToWidth[
            CurrentValue[ nbo, { TaggingRules, "ConversationTitle" } ],
            "WorkspaceChatToolbarTitle",
            #,
            Right
        ]&[ AbsoluteCurrentValue[ nbo, { WindowSize, 1 } ] - 10 ],
        "WorkspaceChatToolbarTitle"
    ]
]

writeWorkspaceChatSubDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeWorkspaceChatSubDockedCell*)
removeWorkspaceChatSubDockedCell // beginDefinition;

removeWorkspaceChatSubDockedCell[ nbo_NotebookObject ] := CurrentValue[ nbo, DockedCells ] = Inherited;

removeWorkspaceChatSubDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historyButton*)
historyButton // beginDefinition;

historyButton[ Dynamic[ nbo_ ] ] := Button[
    toolbarButtonLabel[ "History" ],
    toggleOverlayMenu[ nbo, None, "History" ],
    Appearance -> "Suppressed"
];

historyButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sourcesButton*)
sourcesButton // beginDefinition;

sourcesButton[ Dynamic[ nbo_ ] ] := Button[
    toolbarButtonLabel[ "Sources" ],
    toggleOverlayMenu[ nbo, None, "Sources" ],
    Appearance -> "Suppressed"
];

sourcesButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*newChatButton*)
newChatButton // beginDefinition;

newChatButton[ Dynamic[ nbo_ ] ] :=
	Button[
		toolbarButtonLabel[ "New", "New", "New", True ]
		,
		clearOverlayMenus @ nbo;
		NotebookDelete @ Cells @ nbo;
		removeWorkspaceChatSubDockedCell @ nbo;
		CurrentChatSettings[ nbo, "ConversationUUID" ] = CreateUUID[ ];
		CurrentValue[ nbo, { TaggingRules, "ConversationTitle" } ] = "";
		moveChatInputToTop @ nbo;
		,
		Appearance -> "Suppressed",
		Method     -> "Queued"
	];

newChatButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*openAsChatbookButton*)
openAsChatbookButton // beginDefinition;

openAsChatbookButton[ Dynamic[ nbo_ ] ] := Button[
    toolbarButtonLabel[ "OpenAsChatbook", None ],
    popOutChatNB @ nbo,
    Appearance -> "Suppressed",
    Method     -> "Queued"
];

openAsChatbookButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolbarButtonLabel*)
toolbarButtonLabel // beginDefinition;

toolbarButtonLabel[ name_String ] :=
    toolbarButtonLabel[ name, name ];

toolbarButtonLabel[ iconName_String, label_ ] :=
    toolbarButtonLabel[ iconName, label, iconName, False ];

toolbarButtonLabel[ iconName_String, label_, tooltipName: _String | None, lightStyleQ: True | False ] :=
    toolbarButtonLabel[ iconName, label, tooltipName, lightStyleQ ] =
		With[
            {
                default = If[ lightStyleQ,
                    toolbarButtonLabel0[ iconName, label, color @ "NA_ToolbarLightButtonFont", {FontColor -> color @ "NA_ToolbarLightButtonFont"}, {} ],
                    toolbarButtonLabel0[ iconName, label, color @ "NA_ToolbarFont",            {FontColor -> color @ "NA_ToolbarFont"}, {} ]
                ],
                (* active font same as hover font; light and regular buttons have the same hover and active states *) 
                hover   = toolbarButtonLabel0[ iconName, label, color @ "NA_ToolbarFontHover", {FontColor -> color @ "NA_ToolbarFontHover"}, {} ],
                active  = toolbarButtonLabel0[ iconName, label, color @ "NA_ToolbarFontHover", {FontColor -> color @ "NA_ToolbarFontHover"}, {} ]
            },
			buttonTooltip[
				mouseDown[
					Framed[ default, $toolbarButtonCommon[ label =!= None ], If[ lightStyleQ, $toolbarButtonLight, $toolbarButtonDefault ] ],
					Framed[ hover,   $toolbarButtonCommon[ label =!= None ], $toolbarButtonHover   ],
					Framed[ active,  $toolbarButtonCommon[ label =!= None ], $toolbarButtonActive  ]
				],
				tooltipName
			]
		]

toolbarButtonLabel // endDefinition;


toolbarButtonLabel0 // beginDefinition;

toolbarButtonLabel0[ iconName_String, labelName_String, color_, {styleOpts___}, {gridOpts___}] :=
    With[ { label = tr[ "WorkspaceToolbarButtonLabel"<>labelName ] },
        toolbarButtonLabel0[
            iconName,
            If[ StringQ @ label, Style @ label, label ],
            color,
            {styleOpts},
            {gridOpts}
        ]
    ];

toolbarButtonLabel0[ iconName_String, None, color_, {styleOpts___}, {gridOpts___}] :=
    Grid[
        { { chatbookIcon[ "WorkspaceToolbarIcon"<>iconName, False, color ] } },
        gridOpts,
        Spacings  -> 0.25,
        Alignment -> { {Left, Right}, Baseline },
        BaselinePosition -> { 1, 1 }
    ];

toolbarButtonLabel0[ iconName_String, label_, color_, {styleOpts___}, {gridOpts___}] :=
    Grid[
        { {
            chatbookIcon[ "WorkspaceToolbarIcon"<>iconName, False, color ],
            Style[ label, If[ $AppType === "SideBarChat", "NotebookAssistant`SideBar`ToolbarButtonLabel", "WorkspaceChatToolbarButtonLabel" ], styleOpts ]
        } },
        gridOpts,
        Spacings  -> 0.25,
        Alignment -> { {Left, Right}, Baseline },
        BaselinePosition -> { 1, 2 }
    ];

toolbarButtonLabel0 // endDefinition;

$toolbarButtonCommon[ hasLabelQ_ ] := Sequence[
    Alignment      -> { Center, Center },
    FrameMargins   -> { If[ hasLabelQ, { 1, 6 }, { 3, 3 } ], { 1, 1 } },
    ImageMargins   -> { { 0, 0 }, { 4, 4 } },
    ImageSize      -> { Automatic, 22 },
    RoundingRadius -> 3
];

$toolbarButtonDefault = Sequence[ Background -> color @ "NA_Toolbar", FrameStyle -> color @ "NA_Toolbar" ];
$toolbarButtonHover   = Sequence[ Background -> color @ "NA_ToolbarButtonBackgroundHover",   FrameStyle -> color @ "NA_ToolbarButtonFrameHover" ];
$toolbarButtonActive  = Sequence[ Background -> color @ "NA_ToolbarButtonBackgroundPressed", FrameStyle -> color @ "NA_ToolbarButtonFramePressed" ];
$toolbarButtonLight   = Sequence[ Background -> color @ "NA_ToolbarLightButtonBackground",   FrameStyle -> color @ "NA_ToolbarLightButtonFrame" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*buttonTooltip*)
buttonTooltip // beginDefinition;
buttonTooltip[ label_, None ] := label;
buttonTooltip[ label_, name_String ] := Tooltip[ label, tr[ "WorkspaceToolbarButtonTooltip"<>name ] ];
buttonTooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideBarChatInputCell*)

sideBarChatInputCell // beginDefinition;

sideBarChatInputCell[ ] := sideBarChatInputCell[ "" ]

sideBarChatInputCell[ initialContent_ ] := Cell[
    BoxData @ ToBoxes @ DynamicModule[ { thisNB, thisCell, sideBarCell, chatEvalCell, fieldContent = initialContent, returnKeyDownQ, input },
        EventHandler[
            Pane[
                Grid[
                    {
                        {
                            DynamicWrapper[
                                Framed[
                                    InputField[
                                        Dynamic @ fieldContent,
                                        Boxes,
                                        ContinuousAction -> True,
                                        $inputFieldOptions
                                    ],
                                    $inputFieldFrameOptions
                                ],
                                If[ TrueQ @ returnKeyDownQ,
                                    returnKeyDownQ = False;
                                    Wolfram`Chatbook`Common`evaluateSideBarChat[ thisNB, sideBarCell, input, Dynamic @ chatEvalCell ]
                                ],
                                SynchronousUpdating -> False,
                                TrackedSymbols      :> { returnKeyDownQ }
                            ],
                            (* no need to templatize an attached cell as it is ephemeral *)
                            PaneSelector[
                                {
                                    False ->
                                        Button[
                                            Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButtonLabel" ][ #1, #2, #3 ] ]&[
                                                color @ "NA_ChatInputFieldSendButtonFrameHover",
                                                color @ "NA_ChatInputFieldSendButtonBackgroundHover",
                                                27
                                            ],
                                            If[ ! validInputStringQ @ fieldContent, fieldContent = "", input = fieldContent; fieldContent = ""; returnKeyDownQ = True ],
                                            Appearance   -> "Suppressed",
                                            BoxID        -> "SideBarChatInputCellSendButton",
                                            FrameMargins -> 0,
                                            Method       -> "Preemptive"
                                        ],
                                    True ->
                                        Button[
                                            Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "StopChatButtonLabel" ][ #1, #2, #3 ] ]&[
                                                color @ "NA_ChatInputFieldSendButtonFrameHover",
                                                color @ "NA_ChatInputFieldSendButtonBackgroundHover",
                                                27
                                            ],
                                            Needs[ "Wolfram`Chatbook`" -> None ];
                                            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ],
                                            Appearance   -> "Suppressed",
                                            FrameMargins -> 0
                                        ]
                                },
                                Dynamic[ Wolfram`Chatbook`$ChatEvaluationCell === chatEvalCell ],
                                Alignment -> { Automatic, Baseline }
                            ]
                        },
                        {
                            Item[ Dynamic @ focusedNotebookDisplay[ thisNB, sideBarCell ], Alignment -> Left ],
                            SpanFromLeft
                        }
                    },
                    BaseStyle -> { Magnification -> $inputFieldGridMagnification },
                    Spacings  -> { 0.5, 0.0 }
                ],
                FrameMargins -> $inputFieldPaneMargins
            ],
            {
                "ReturnKeyDown" :> (
                    If[ ! validInputStringQ @ fieldContent,
                        fieldContent = ""
                        , (* The EventHandler, if queued, still won't update the dynamics until the payload is completed. Use a DynamicWrapper above to listen for the change and evaluate asynchronously. *)
                        input = fieldContent; fieldContent = ""; returnKeyDownQ = True
                    ])
            },
            Method -> "Preemptive"
        ],
        (* 15.0: the side bar is a Row of cells: docked cells, scrollable pane cell, footer cell (ChatInput) *)
        Initialization :> (thisNB = EvaluationNotebook[ ]; thisCell = EvaluationCell[ ]; sideBarCell = ParentCell @ thisCell)
    ],
    "ChatInputField",
    Background    -> $inputFieldOuterBackground,
    CellTags      -> "SideBarChatInputCell" ,
    Magnification -> Dynamic[ 0.85*AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ] ]
];

sideBarChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachWorkspaceChatInput*)
attachWorkspaceChatInput // beginDefinition;

attachWorkspaceChatInput[ nbo_NotebookObject ] := attachWorkspaceChatInput[ nbo, Bottom ]

attachWorkspaceChatInput[ nbo_NotebookObject, location : Top|Bottom ] := Enclose[
    Catch @ Module[ { current, tags, attached },

        current = Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ];
        tags    = CurrentValue[ current, CellTags ];

        (* Check if cell is already attached in the specified location: *)
        If[ MatchQ[ tags, { { ___, ToString @ location, ___ } } ],
            Throw @ ConfirmMatch[ First[ current, $Failed ], _CellObject, "CurrentCell" ]
        ];

        NotebookDelete @ current;

        attached = ConfirmMatch[
            AttachCell[
                nbo,
                attachedWorkspaceChatInputCell[ If[ location === Top, "Top", "Bottom" ] ],
                location,
                0,
                location
            ],
            _CellObject,
            "Attach"
        ];

        attached
    ],
    throwInternalFailure
];

attachWorkspaceChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachedWorkspaceChatInputCell*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::DynamicImageSize:: *)
attachedWorkspaceChatInputCell[ location_String ] := Cell[
    BoxData @ ToBoxes @ DynamicModule[ { thisNB },
        EventHandler[
            Pane[
                Grid[
                    {
                        {
                            RawBoxes @ TemplateBox[ { }, "ChatIconUser" ],
                            Framed[
                                InputField[
                                    Dynamic @ $WorkspaceChatInput,
                                    Boxes,
                                    ContinuousAction -> True,
                                    $inputFieldOptions
                                ],
                                $inputFieldFrameOptions
                            ],
                            (* no need to templatize an attached cell as it is ephemeral *)
                            PaneSelector[
                                {
                                    None -> Button[
                                        Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButtonLabel" ][ #1, #2, #3 ] ]&[
                                            color @ "NA_ChatInputFieldSendButtonFrameHover",
                                            color @ "NA_ChatInputFieldSendButtonBackgroundHover",
                                            27
                                        ],
                                        Needs[ "Wolfram`Chatbook`" -> None ];
                                        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                                            "EvaluateWorkspaceChat",
                                            thisNB,
                                            Dynamic @ $WorkspaceChatInput
                                        ],
                                        Appearance   -> "Suppressed",
                                        FrameMargins -> 0,
                                        Method       -> "Queued"
                                    ]
                                },
                                Dynamic @ Wolfram`Chatbook`$ChatEvaluationCell,
                                Button[
                                    Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "StopChatButtonLabel" ][ #1, #2, #3 ] ]&[
                                        color @ "NA_ChatInputFieldSendButtonFrameHover",
                                        color @ "NA_ChatInputFieldSendButtonBackgroundHover",
                                        27
                                    ],
                                    Needs[ "Wolfram`Chatbook`" -> None ];
                                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ],
                                    Appearance   -> "Suppressed",
                                    FrameMargins -> 0
                                ],
                                Alignment -> { Automatic, Baseline }
                            ]
                        },
                        {
                            Spacer[ 0 ],
                            Item[ Dynamic @ focusedNotebookDisplay[ thisNB, None ], Alignment -> Left ],
                            SpanFromLeft
                        }
                    },
                    BaseStyle -> { Magnification -> $inputFieldGridMagnification },
                    Spacings  -> { 0.5, 0.0 }
                ],
                FrameMargins -> $inputFieldPaneMargins,
                ImageSize ->
                    If[ location === "Top",
                        Dynamic @ {
                            Automatic,
                            AbsoluteCurrentValue[ thisNB, { WindowSize, 2 } ] /
                                AbsoluteCurrentValue[ thisNB, Magnification ]
                        },
                        Automatic
                    ]
            ],
            {
                "ReturnKeyDown" :> (
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "EvaluateWorkspaceChat",
                        thisNB,
                        Dynamic @ $WorkspaceChatInput
                    ]
                )
            },
            Method -> "Queued"
        ],
        Initialization :> (thisNB = EvaluationNotebook[ ])
    ],
    "ChatInputField",
    Background    -> $inputFieldOuterBackground,
    CellTags      -> location,
    Magnification :> AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ],
    Selectable    -> True
];
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*workspaceChatInitializer*)
workspaceChatInitializer // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::DynamicModule:: *)
workspaceChatInitializer[ expr_ ] :=
    DynamicModule[
        { },
        expr,
        Initialization :> initializeWorkspaceChat[ ],
        SynchronousInitialization -> False
    ];
(* :!CodeAnalysis::EndBlock:: *)

workspaceChatInitializer // endDefinition;

$workspaceChatInitialized = False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializeWorkspaceChat*)
initializeWorkspaceChat // beginDefinition;

initializeWorkspaceChat[ ] := initializeWorkspaceChat[ ] = LogChatTiming[
    LogChatTiming[ getEmbeddings[ { "Hello" } ], "InitializeEmbeddings" ];
    LogChatTiming[ cachedTokenizer[ "gpt-4o-text" ], "InitializeTokenizer" ];
    LogChatTiming[ $llmKitService, "InitializeLLMKitService" ];
    $workspaceChatInitialized = True,
    "InitializeWorkspaceChat"
];

initializeWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Moving input field between bottom/top of window*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*moveChatInputToTop*)
moveChatInputToTop // beginDefinition;

moveChatInputToTop[ nbo_NotebookObject ] :=
    Catch @ Module[ { attached },
        attached = Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField", CellTags -> "Bottom" ];
        If[ attached === { }, Throw @ Null ];
        NotebookDelete @ attached;
        ChatbookAction[ "AttachWorkspaceChatInput", nbo, Top ]
    ];

moveChatInputToTop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*moveChatInputToBottom*)
moveChatInputToBottom // beginDefinition;

moveChatInputToBottom[ nbo_NotebookObject ] :=
    Catch @ Module[ { attached },
        attached = Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField", CellTags -> "Top" ];
        If[ attached === { }, Throw @ Null ];
        NotebookDelete @ attached;
        ChatbookAction[ "AttachWorkspaceChatInput", nbo, Bottom ]
    ];

moveChatInputToBottom // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachInlineChatInput*)
attachInlineChatInput // beginDefinition;

attachInlineChatInput[ nbo_NotebookObject ] :=
    attachInlineChatInput[ nbo, <| |> ];

attachInlineChatInput[ nbo_NotebookObject, settings_Association ] :=
    If[ TrueQ @ userNotebookQ @ nbo,
        attachInlineChatInput[ nbo, settings, SelectedCells @ nbo ],
        Null
    ];

attachInlineChatInput[ nbo_NotebookObject, settings_Association, { root_CellObject } ] := Enclose[
    Module[ { selectionInfo, attached },

        NotebookDelete @ $lastAttachedInlineChat;
        NotebookDelete @ Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedChatInput" ];

        selectionInfo = ConfirmMatch[
            getSelectionInfo @ root,
            None | KeyValuePattern[ "CursorPosition" -> { _Integer, _Integer } ],
            "SelectionInfo"
        ];

        $lastScrollPosition       = 0.0;
        $inlineChatScrollPosition = 0.0;

        (* TODO: Watch the root cell for changes and remove (or disable) the attached chat if cell changed *)
        attached = ConfirmMatch[
            AttachCell[
                NotebookSelection @ nbo,
                inlineChatInputCell[ root, selectionInfo, settings ],
                { "WindowCenter", Bottom },
                0,
                { Center, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ],
            _CellObject,
            "Attach"
        ];

        SelectionMove[ attached, Before, CellContents ];
        FrontEndExecute @ FrontEnd`FrontEndToken[ "MoveNextPlaceHolder" ];

        $lastAttachedInlineChat = attached
    ],
    throwInternalFailure
];

(* TODO: moving the selection probably isn't ideal: *)
attachInlineChatInput[ nbo_NotebookObject, settings_, { } ] := Enclose[
    Module[ { root },
        SelectionMove[ nbo, Previous, Cell ];
        root = Replace[ SelectedCells @ nbo, { cell_CellObject } :> cell ];
        If[ MatchQ[ root, _CellObject ],
            attachInlineChatInput[ nbo, settings, { root } ],
            Null
        ]
    ],
    throwInternalFailure
];

(* FIXME: Need to handle multiple cell selections *)
attachInlineChatInput[ nbo_NotebookObject, settings_, { ___ } ] := Null;

attachInlineChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSelectionInfo*)
getSelectionInfo // beginDefinition;

getSelectionInfo[ cell_CellObject ] :=
    getSelectionInfo[ cell, cellInformation[ cell, { "ContentData", "CursorPosition" } ] ];

getSelectionInfo[ cell_, KeyValuePattern[ "CursorPosition" -> Except[ { _Integer, _Integer } ] ] ] :=
    None;

getSelectionInfo[ cell_, info_ ] :=
    getSelectionInfo[ cell, info, cellHash @ cell ];

getSelectionInfo[
    cell_CellObject,
    as: KeyValuePattern[ "CursorPosition" -> { _Integer, _Integer } ],
    hash_String
] := <|
    as,
    "CellObject" -> cell,
    "Hash"       -> hash
|>;

getSelectionInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellHash*)
cellHash // beginDefinition;
cellHash[ cell_CellObject ] := cellHash[ cell, FrontEndExecute @ FrontEnd`CryptoHash @ cell ];
cellHash[ cell_CellObject, KeyValuePattern @ { "DirtiableContentsHash" -> hash_String } ] := hash;
cellHash // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineChatInputCell*)
inlineChatInputCell // beginDefinition;

inlineChatInputCell[ root_CellObject, selectionInfo_, settings_ ] := Cell[
    BoxData @ inlineTemplateBox @ TemplateBox[
        {
            ToBoxes @ DynamicModule[ { messageCells = { }, cell },
                Dynamic[
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "DisplayInlineChat",
                        cell,
                        root,
                        selectionInfo,
                        Dynamic[ messageCells ]
                    ]
                ],

                UnsavedVariables :> { cell },

                (* ParentCell and ParentNotebook do not work for cells attached to NotebookSelection[ ],
                   so we create temporary overrides here. *)
                Initialization :> (
                    cell = EvaluationCell[ ];
                    parentCell[ cell ] = root;
                    parentNotebook[ cell ] = parentNotebook @ root;
                    attachInlineChatButtons[ EvaluationCell[ ], Dynamic @ messageCells ]
                ),

                Deinitialization :> Quiet[
                    $inputFieldBox = None;
                    Unset @ parentCell @ cell;
                    Unset @ parentNotebook @ cell;
                    ClearAll @ evaluateAttachedInlineChat;
                ]
            ]
        },
        "DropShadowPaneBox"
    ],
    "AttachedChatInput",
    Background    -> None,
    Magnification :> AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ],
    Selectable    -> True,
    TaggingRules  -> <| "ChatNotebookSettings" -> settings |>
];

inlineChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachInlineChatButtons*)
attachInlineChatButtons // beginDefinition;

attachInlineChatButtons[ cell_CellObject, messageCells_Dynamic ] := AttachCell[
    cell,
    inlineChatButtonsCell[ cell, messageCells ],
    { Right, Top },
    Offset[ { -57, -7 }, 0 ],
    { Left, Top }
];

attachInlineChatButtons // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineChatButtonsCell*)
inlineChatButtonsCell // beginDefinition;

(* TODO: define a template box for this in the stylesheet *)
inlineChatButtonsCell[ cell_CellObject, messageCells_Dynamic ] :=
    Cell @ BoxData @ GridBox[
        { { closeButton @ cell }, { popOutButton[ cell, messageCells ] } },
        AutoDelete      -> False,
        GridBoxItemSize -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } },
        GridBoxSpacings -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } }
    ];

inlineChatButtonsCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*closeButton*)
closeButton // beginDefinition;

closeButton[ cell_CellObject ] := ToBoxes @ Button[
    RawBoxes @ FrameBox[
        GraphicsBox[
            {
                color @ "NA_ChatOutputInlineButtonIcon",
                AbsoluteThickness[ 1 ],
                CapForm[ "Round" ],
                LineBox @ { { { -1, -1 }, { 1, 1 } }, { { 1, -1 }, { -1, 1 } } }
            },
            ImagePadding -> { { 0, 1 }, { 1, 0 } },
            ImageSize    -> { 6, 6 },
            PlotRange    -> 1
        ],
        Alignment      -> { Center, Center },
        Background     -> color @ "NA_ChatOutputInlineButtonBackground",
        ContentPadding -> False,
        FrameMargins   -> None,
        FrameStyle     -> color @ "NA_ChatOutputInlineButtonFrame",
        ImageSize      -> { 16, 16 },
        RoundingRadius -> 2,
        StripOnInput   -> False
    ],
    NotebookDelete @ cell,
    Appearance -> "Suppressed",
    Tooltip    -> ToBoxes @ tr["InlineChatButtonTooltipClose"]
];

closeButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*popOutButton*)
popOutButton // beginDefinition;

popOutButton[ cell_CellObject, messageCells_Dynamic ] := ToBoxes @ Button[
    RawBoxes @ FrameBox[
        GraphicsBox[
            {
                color @ "NA_ChatOutputInlineButtonIcon",
                AbsoluteThickness[ 1 ],
                CapForm[ "Round" ],
                LineBox @ {
                    { { -0.4, 0.8 }, { -0.8, 0.8 }, { -0.8, -0.8 }, { 0.8, -0.8 }, { 0.8, -0.4 } },
                    { { -0.1, -0.1 }, { 1, 1 } },
                    { { 0.2, 1 }, { 1, 1 }, { 1, 0.2 } }
                }
            },
            ImagePadding -> { { 0, 1 }, { 1, 0 } },
            ImageSize    -> { 10, 10 },
            PlotRange    -> 1
        ],
        Alignment      -> { Center, Center },
        Background     -> color @ "NA_ChatOutputInlineButtonBackground",
        ContentPadding -> False,
        FrameMargins   -> None,
        FrameStyle     -> color @ "NA_ChatOutputInlineButtonFrame",
        ImageSize      -> { 16, 16 },
        RoundingRadius -> 2,
        StripOnInput   -> False
    ],
    NotebookDelete @ cell;
    popOutWorkspaceChatNB @ messageCells,
    Appearance -> "Suppressed",
    Tooltip    -> ToBoxes @ tr["InlineChatButtonTooltipViewNotebookAssist"]
];

popOutButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*displayInlineChat*)
displayInlineChat // beginDefinition;

displayInlineChat[ cell_CellObject, root_CellObject, selectionInfo_, Dynamic[ messageCells_Symbol ] ] :=
    Module[ { inputField },

        inputField = inlineChatInputField[
            cell,
            root,
            selectionInfo,
            Dynamic @ CurrentValue[ cell, { TaggingRules, "ChatInputString" } ],
            Dynamic @ messageCells
        ];

        displayInlineChatMessages[ messageCells, inputField ]
    ];

displayInlineChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineChatInputField*)
inlineChatInputField // beginDefinition;

inlineChatInputField[
    cell_CellObject,
    root_CellObject,
    selectionInfo_,
    Dynamic[ currentInput_ ],
    Dynamic[ messageCells_ ]
] := (
    evaluateAttachedInlineChat[ ] := ChatbookAction[
        "EvaluateInlineChat",
        cell,
        root,
        selectionInfo,
        Dynamic @ currentInput,
        Dynamic @ messageCells
    ];
    EventHandler[
        Pane[
            Grid[
                {
                    {
                        RawBoxes @ inlineTemplateBox @ TemplateBox[ { }, "ChatIconUser" ],
                        Framed[
                            DynamicWrapper[
                                InputField[ Dynamic @ currentInput, String, $inputFieldOptions ],
                                $inputFieldBox = EvaluationBox[ ]
                            ],
                            $inputFieldFrameOptions
                        ],
                        (* FIXME: this needs a custom button *)
                        RawBoxes @ inlineTemplateBox @
                            DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButton" ][ #1, #2, 27 ] ]&[ RGBColor[ "#a3c9f2" ], RGBColor[ "#f1f7fd" ] ]
                    }
                },
                BaseStyle -> { Magnification -> $inputFieldGridMagnification*0.8 }
            ],
            FrameMargins -> $inputFieldPaneMargins
        ],
        {
            "ReturnKeyDown" :> (
                Needs[ "Wolfram`Chatbook`" -> None ];
                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                    "EvaluateInlineChat",
                    cell,
                    root,
                    selectionInfo,
                    Dynamic @ currentInput,
                    Dynamic @ messageCells
                ]
            )
        },
        Method -> "Queued"
    ]
);

inlineChatInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*moveToInlineChatInputField*)
moveToInlineChatInputField // beginDefinition;

moveToInlineChatInputField[ ] :=
    moveToInlineChatInputField @ $inputFieldBox;

moveToInlineChatInputField[ box_BoxObject ] := Quiet @ Catch[
    SelectionMove[ box, Before, Expression ];
    FrontEnd`MoveCursorToInputField[ parentNotebook @ box, "AttachedChatInputField" ],
    _
];

moveToInlineChatInputField[ None ] := Null;

moveToInlineChatInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*displayInlineChatMessages*)
displayInlineChatMessages // beginDefinition;

displayInlineChatMessages[ { }, inputField_ ] :=
    Pane[ inputField, ImageSize -> { $initialInlineChatWidth, Automatic } ];

displayInlineChatMessages[ cells: { __Cell }, inputField_ ] :=
    DynamicModule[ { w, h, size },

        (* TODO: use cell tagging rules instead so it remembers the size when refreshing *)
        w = $initialInlineChatWidth;
        h = $initialInlineChatHeight;
        size = { w, h };

        Column[
            {
                Pane[
                    Column[
                        formatInlineMessageCells /@ cells,
                        Alignment  -> Left,
                        BaseStyle  -> { Magnification -> 0.8 * Inherited },
                        ItemSize   -> { Fit, Automatic },
                        Spacings   -> 0.5
                    ],
                    FrameMargins       -> 5,
                    ImageSize          -> Dynamic[ size, Function[ { w, h } = size = # ] ],
                    Scrollbars         -> Automatic,
                    AppearanceElements -> { "ResizeArea" },
                    ScrollPosition     -> Dynamic[
                        { 0, $inlineChatScrollPosition },
                        Function[ $lastScrollPosition = $inlineChatScrollPosition = Last[ # ] ]
                    ]
                ],
                Pane[ inputField, ImageSize -> Dynamic[ { w, Automatic } ] ]
            },
            Alignment -> Left
        ],
        Initialization :> ($inlineChatScrollPosition = $lastScrollPosition)
    ];

displayInlineChatMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*scrollInlineChat*)
scrollInlineChat // beginDefinition;
scrollInlineChat[ ] := scrollInlineChat[ 500 ];
scrollInlineChat[ amount_ ] := (scrollInlineChat0[ amount ]; updateDynamics[ "InlineChatScrollPane" ]);
scrollInlineChat // endDefinition;

scrollInlineChat0 // beginDefinition;
scrollInlineChat0[ amount_ ] := scrollInlineChat0[ amount, $lastScrollPosition ];
scrollInlineChat0[ amount_? NumberQ, current_? NumberQ ] := $lastScrollPosition = current + amount;
scrollInlineChat0[ amount_? NumberQ, _  ] := $lastScrollPosition = amount;
scrollInlineChat0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatInlineMessageCells*)
formatInlineMessageCells // beginDefinition;

formatInlineMessageCells[ cell: Cell[ __, "ChatInput", ___ ] ] :=
    Item[
        Grid[
            { { RawBoxes @ cell, Pane[ userImage[ ], ImageMargins -> $messageAuthorImagePadding ] } },
            Alignment -> { Right, Top }
        ],
        Alignment -> Right
    ];

formatInlineMessageCells[ cell: Cell[ __, "ChatOutput", ___ ] ] :=
    Block[ { $InlineChat = True },
        Grid[
            {
                {
                    Pane[ assistantImage[ ], ImageMargins -> $messageAuthorImagePadding ],
                    RawBoxes @ InputFieldBox[
                        Append[ DeleteCases[ cell, Background -> _ ], Background -> None ],
                        Appearance -> None,
                        ImageSize  -> { Scaled[ 1 ], Automatic }
                    ]
                }
            },
            Alignment -> { Left, Top }
        ]
    ];

formatInlineMessageCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input Field Movement*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*moveToChatInputField*)
moveToChatInputField // beginDefinition;

(* TODO: support inline chat cells too *)
moveToChatInputField[ nbo_ ] :=
    moveToChatInputField[ nbo, $WorkspaceChat ];

moveToChatInputField[ nbo_NotebookObject, True ] := (
    moveToChatInputField0 @ nbo; (* TODO: Need to investigate why this is needed twice *)
    (* FIXME: Maybe this should use `FrontEndExecute @ FrontEnd`FrontEndToken[ "MoveNextPlaceHolder" ]`? *)
    moveToChatInputField0 @ nbo;
);

moveToChatInputField[ nbo_NotebookObject, False ] :=
    Null;

moveToChatInputField // endDefinition;


moveToChatInputField0 // beginDefinition;

moveToChatInputField0[ nbo_NotebookObject ] := (
    SelectionMove[
        First[ Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ], $Failed ],
        After,
        CellContents
    ];
    FrontEndExecute @ FrontEndToken[ nbo, "MovePrevious" ]
);

moveToChatInputField0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Message Decorations*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*assistantMessageLabel*)
assistantMessageLabel // beginDefinition;

assistantMessageLabel[ ] := Enclose[
    Catch @ Module[ { cell, persona },
        cell = topParentCell @ EvaluationCell[ ];
        persona = If[ MatchQ[ cell, _CellObject ], CurrentChatSettings[ cell, "LLMEvaluator" ], "NotebookAssistant" ];
        ConfirmMatch[ getPersonaMenuIcon @ persona, Except[ _getPersonaMenuIcon | _? FailureQ ], "Icon" ]
    ],
    throwInternalFailure
];

assistantMessageLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*userMessageLabel*)
userMessageLabel // beginDefinition;
userMessageLabel[ ] := userImage[ ];
userMessageLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*userName*)
userName // beginDefinition;

userName[ ] := FirstCase[
    Unevaluated @ { $CloudAccountName, CurrentValue[ "WolframCloudFullUserName" ], $Username },
    expr_ :> With[ { user = expr }, user /; StringQ @ user ],
    "You"
];

userName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*userImage*)
userImage // beginDefinition;

userImage[ ] :=
    If[ TrueQ @ $useGravatarImages,
        userImage @ FirstCase[
            Unevaluated @ { $CloudUserID, CurrentValue[ "WolframCloudUserName" ] },
            expr_ :> With[ { user = expr }, user /; StringQ @ user ]
        ],
        $defaultUserImage
    ];

userImage[ user_String ] := Enclose[
    Module[ { hash, url, image },
        hash  = Hash[ ToLowerCase @ StringTrim @ user, "MD5", "HexString" ];
        url   = ConfirmBy[ URLBuild[ { "https://www.gravatar.com/avatar/", hash }, $userImageParams ], StringQ, "URL" ];
        image = ConfirmBy[ Quiet @ Import @ url, ImageQ, "Image" ];
        userImage[ user ] = Show[ image, ImageSize -> 20 ]
    ],
    (userImage[ user ] = $defaultUserImage) &
];

userImage[ other_ ] :=
    $defaultUserImage;

userImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*useGravatarImagesQ*)
useGravatarImagesQ // beginDefinition;
useGravatarImagesQ[ ] := useGravatarImagesQ[ ] = TrueQ @ CurrentChatSettings[ $FrontEnd, "UseGravatarImages" ];
useGravatarImagesQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachAssistantMessageButtons*)
attachAssistantMessageButtons // beginDefinition;

attachAssistantMessageButtons[ cell_ ] /; $dynamicText || MatchQ[ $ChatEvaluationCell, _CellObject ] := Null;

attachAssistantMessageButtons[ cell_CellObject ] :=
    attachAssistantMessageButtons[ cell, CurrentChatSettings[ cell, "WorkspaceChat" ] ];

attachAssistantMessageButtons[ cell0_CellObject, True ] := Enclose[
    Catch @ Module[ { cell, includeFeedback, attached, sideBarCellQ },

        cell = topParentCell @ cell0;
        If[ ! MatchQ[ cell, _CellObject ], Throw @ Null ];
        sideBarCellQ = cellTaggedQ[ cell, "SideBarTopCell" ];

        (* If chat has been reloaded from history, it no longer has the necessary metadata for feedback: *)
        includeFeedback = StringQ @ CurrentValue[ cell, { TaggingRules, "ChatData" } ];

        (* Remove existing attached cell, if any: *)
        NotebookDelete @ Cells[ cell, AttachedCell -> True, CellStyle -> "ChatOutputTrayButtons" ];

        (* Attach new cell: *)
        attached = AttachCell[
            cell,
            Cell[
                BoxData @ assistantMessageButtons[ includeFeedback, sideBarCellQ ],
                "ChatOutputTrayButtons",
                Magnification -> AbsoluteCurrentValue[ cell, Magnification ]
            ],
            { Left, Bottom },
            (* The side bar's TemplateBox uses ImageMargins, so use Offset to undo those margins *)
            If[ sideBarCellQ, Offset[ { 15, 30 }, Automatic ], 0 ],
            { Left, Top },
            RemovalConditions -> "MouseExit"
        ]
    ],
    throwInternalFailure
];

attachAssistantMessageButtons[ cell_CellObject, _ ] :=
    Null;

attachAssistantMessageButtons // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*assistantMessageButtons*)
assistantMessageButtons // beginDefinition;

assistantMessageButtons[ includeFeedback_, sideBarCellQ_ ] :=
    ToBoxes @ DynamicModule[ { cell },
        Grid[
            { {
                Tooltip[ assistantCopyAsActionMenu[ Dynamic[ cell ] ], tr[ "WorkspaceOutputRaftCopyAsTooltip" ] ],
                Button[
                    Tooltip[ $regenerateLabel, tr[ "WorkspaceOutputRaftRegenerateTooltip" ] ],
                    ChatbookAction[ "RegenerateAssistantMessage", cell ],
                    Appearance -> "Suppressed",
                    Method     -> "Queued"
                ],
                Item[ Spacer[ 0 ], ItemSize -> Fit ],
                (* Waiting for sharing functionality to be implemented: *)
                (* Tooltip[ assistantShareAsActionMenu[ Dynamic[ cell ] ], tr[ "WorkspaceOutputRaftShareAsTooltip" ] ], *)
                If[ TrueQ @ includeFeedback,
                    Splice @ {
                        Button[
                            Tooltip[ $thumbsUpLabel, tr[ "WorkspaceOutputRaftFeedbackTooltip" ] ],
                            ChatbookAction[ "SendFeedback", cell, True ],
                            Appearance -> "Suppressed",
                            Method     -> "Queued"
                        ],
                        Button[
                            Tooltip[ $thumbsDownLabel, tr[ "WorkspaceOutputRaftFeedbackTooltip" ] ],
                            ChatbookAction[ "SendFeedback", cell, False ],
                            Appearance -> "Suppressed",
                            Method     -> "Queued"
                        ],
                        Spacer[ If[ sideBarCellQ, 60, 45 ] ] 
                    },
                    Nothing
                ]
            } },
            Alignment -> { Automatic, Center },
            Spacings -> 0
        ],
        Initialization :> (cell = ParentCell @ EvaluationCell[ ])
    ];

assistantMessageButtons // endDefinition;


$clipboardLabel  := $clipboardLabel  = chatbookIcon[ "WorkspaceOutputRaftClipboardIcon" , False ];
$regenerateLabel := $regenerateLabel = chatbookIcon[ "WorkspaceOutputRaftRegenerateIcon", False ];
$thumbsUpLabel   := $thumbsUpLabel   = chatbookIcon[ "WorkspaceOutputRaftThumbsUpIcon"  , False ];
$thumbsDownLabel := $thumbsDownLabel = chatbookIcon[ "WorkspaceOutputRaftThumbsDownIcon", False ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
assistantCopyAsActionMenu // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::DynamicModule:: *)
assistantCopyAsActionMenu[ Dynamic[ cell_ ] ] :=
DynamicModule[ { Typeset`menuActiveQ = False },
    EventHandler[
        PaneSelector[
            {
                "Default" ->
                    Framed[
                        chatbookIcon[ "WorkspaceOutputRaftClipboardIcon" , False, color @ "NA_OutputRaftIcon" ],
                        Background -> color @ "NA_NotebookBackground", RoundingRadius -> 3, FrameMargins -> 0, FrameStyle -> color @ "NA_NotebookBackground",
                        Alignment -> { Center, Center }, ImageSize -> { 22, 22 } ],
                "Hover" ->
                    Framed[
                        chatbookIcon[ "WorkspaceOutputRaftClipboardIcon" , False, color @ "NA_OutputRaftIcon" ],
                        Background -> color @ "NA_OutputRaftBackgroundHover", RoundingRadius -> 3, FrameMargins -> 0, FrameStyle -> color @ "NA_OutputRaftBackgroundHover",
                        Alignment -> { Center, Center }, ImageSize -> { 22, 22 } ],
                "Down" ->
                    Framed[
                        chatbookIcon[ "WorkspaceOutputRaftClipboardIcon" , False, color @ "NA_OutputRaftIconPressed" ],
                        Background -> color @ "NA_OutputRaftBackgroundPressed", RoundingRadius -> 3, FrameMargins -> 0, FrameStyle -> color @ "NA_OutputRaftBackgroundPressed",
                        Alignment -> { Center, Center }, ImageSize -> { 22, 22 } ] },
            Dynamic[
                Which[
                    Typeset`menuActiveQ, "Down",
                    CurrentValue[ "MouseOver" ], "Hover",
                    True, "Default" ]],
            ImageSize -> Automatic ],
        {
            "MouseDown" :> (
                Typeset`menuActiveQ = True;
                AttachCell[ EvaluationBox[ ],
                    Cell[ BoxData @ ToBoxes @
                        DynamicModule[ { },
                            Framed[
                                Grid[
                                    {
                                        { Style[ tr[ "WorkspaceOutputRaftCopyAs" ], FontColor -> color @ "NA_RaftMenuHeaderFont", FontSize -> 12 ] },
                                        { assistantActionMenuItem[ tr[ "WorkspaceOutputRaftCopyAsNotebookCells" ], ChatbookAction[ "CopyExplodedCells", cell ] ] },
                                        { assistantActionMenuItem[ tr[ "WorkspaceOutputRaftCopyAsPlainText" ], ChatbookAction[ "CopyPlainText", cell ] ] },
                                        { assistantActionMenuItem[ tr[ "WorkspaceOutputRaftCopyAsImage" ], ChatbookAction[ "CopyImage", cell ] ] }
                                    },
                                    Alignment -> Left,
                                    BaseStyle -> { FontFamily -> "Source Sans Pro" },
                                    Spacings  -> { 0, { 0, 0.5, { 0 } } }
                                ],
                                Background -> color @ "NA_RaftMenuBackground", FrameStyle -> color @ "NA_RaftMenuFrame", ImageSize -> 158, RoundingRadius -> 4 ],
                            InheritScope     -> True,
                            Initialization   :> (True), (* Deinitialization won't run without an Init *)
                            Deinitialization :> (Typeset`menuActiveQ = False)
                        ],
                        CellTags      -> "CustomActionMenu",
                        Magnification -> AbsoluteCurrentValue[ EvaluationNotebook[ ], Magnification ]*If[ cellTaggedQ[ topParentCell @ EvaluationCell[ ], "SideBarTopCell" ], 0.85, 1. ]
                    ],
                    { Left, Bottom }, 0, { Left, Top },
                    RemovalConditions -> "MouseExit" ]) },
        PassEventsDown -> True,
        Method -> "Preemptive",
        PassEventsUp -> True ]]
(* :!CodeAnalysis::EndBlock:: *)

assistantCopyAsActionMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*assistantShareAsActionMenu*)
assistantShareAsActionMenu // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::DynamicModule:: *)
assistantShareAsActionMenu[ Dynamic[ cell_ ] ] :=
DynamicModule[ { Typeset`menuActiveQ = False },
    EventHandler[
        PaneSelector[
            {
                "Default" ->
                    Framed[
                        chatbookIcon[ "WorkspaceOutputRaftShareIcon" , False, color @ "NA_OutputRaftIcon" ],
                        Background -> color @ "NA_NotebookBackground", RoundingRadius -> 3, FrameMargins -> 0, FrameStyle -> color @ "NA_NotebookBackground",
                        Alignment -> { Center, Center }, ImageSize -> { 22, 22 } ],
                "Hover" ->
                    Framed[
                        chatbookIcon[ "WorkspaceOutputRaftShareIcon" , False, color @ "NA_OutputRaftIcon" ],
                        Background -> color @ "NA_OutputRaftBackgroundHover", RoundingRadius -> 3, FrameMargins -> 0, FrameStyle -> color @ "NA_OutputRaftBackgroundHover",
                        Alignment -> { Center, Center }, ImageSize -> { 22, 22 } ],
                "Down" ->
                    Framed[
                        chatbookIcon[ "WorkspaceOutputRaftShareIcon" , False, color @ "NA_OutputRaftIconPressed" ],
                        Background -> color @ "NA_OutputRaftBackgroundPressed", RoundingRadius -> 3, FrameMargins -> 0, FrameStyle -> color @ "NA_OutputRaftBackgroundPressed",
                        Alignment -> { Center, Center }, ImageSize -> { 22, 22 } ] },
            Dynamic[
                Which[
                    Typeset`menuActiveQ, "Down",
                    CurrentValue[ "MouseOver" ], "Hover",
                    True, "Default" ]],
            ImageSize -> Automatic ],
        {
            "MouseDown" :> (
                Typeset`menuActiveQ = True;
                AttachCell[ EvaluationBox[ ],
                    Cell[ BoxData @ ToBoxes @
                        DynamicModule[ { },
                            Framed[
                                Grid[
                                    {
                                        { Style[ tr[ "WorkspaceOutputRaftShareAs" ], FontColor -> color @ "NA_RaftMenuHeaderFont", FontSize -> 12 ] },
                                        { assistantActionMenuItem[ tr[ "WorkspaceOutputRaftShareAsCloudDeployment" ], ChatbookAction[ "ShareAsCloudDeployment", cell ] ] },
                                        { assistantActionMenuItem[ tr[ "WorkspaceOutputRaftShareAsPDF" ], ChatbookAction[ "ShareAsPDF", cell ] ] },
                                        { assistantActionMenuItem[ tr[ "WorkspaceOutputRaftShareAsImage" ], ChatbookAction[ "ShareAsImage", cell ] ] }
                                    },
                                    Alignment -> Left,
                                    BaseStyle -> { FontFamily -> "Source Sans Pro" },
                                    Spacings -> { 0, { 0, 0.5, { 0 } } }
                                ],
                                Background -> color @ "NA_RaftMenuBackground", FrameStyle -> color @ "NA_RaftMenuFrame", ImageSize -> 158, RoundingRadius -> 4 ],
                            InheritScope -> True,
                            Initialization :> (True), (* Deinitialization won't run without an Init *)
                            Deinitialization :> (Typeset`menuActiveQ = False)
                        ],
                        CellTags -> "CustomActionMenu",
                        Magnification -> Inherited * 0.85 ],
                    { Right, Bottom }, 0, { Right, Top }, (* Because this is an attached cell, it has to exist within the NA window *)
                    RemovalConditions -> "MouseExit" ]) },
        PassEventsDown -> True,
        Method -> "Preemptive",
        PassEventsUp -> True ]]
(* :!CodeAnalysis::EndBlock:: *)

assistantShareAsActionMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*assistantActionMenuItem*)
assistantActionMenuItem // beginDefinition;

assistantActionMenuItem // Attributes = { HoldRest };

assistantActionMenuItem[ label_, clickAction_ ] :=
Button[
    mouseDown[
        Framed[ label, $actionMenuItemOptions, Background -> None, FrameStyle -> None ],
        Framed[ label, $actionMenuItemOptions, Background -> color @ "NA_RaftMenuItemBackgroundHover",   FrameStyle -> color @ "NA_RaftMenuItemFrameHover" ],
        Framed[ label, $actionMenuItemOptions, Background -> color @ "NA_RaftMenuItemBackgroundPressed", FrameStyle -> color @ "NA_RaftMenuItemFramePressed" ] ],
    clickAction;
    NotebookDelete[ Cells[ EvaluationNotebook[ ], AttachedCell -> True, CellTags -> "CustomActionMenu" ]],
    Appearance -> "Suppressed",
    Method     -> "Queued",
    ImageSize  -> Automatic ]

assistantActionMenuItem // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Notebook Conversion*)

(* TODO: move more of this conversion functionality to ConvertChatNotebook *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*popOutWorkspaceChatNB*)
popOutWorkspaceChatNB // beginDefinition;

popOutWorkspaceChatNB[ Dynamic[ cells_ ] ] :=
    popOutWorkspaceChatNB @ cells;

popOutWorkspaceChatNB[ cells0: { ___Cell } ] := Enclose[
    Module[ { cells, settings, nbo },
        NotebookClose @ findCurrentWorkspaceChat[ ];

        cells = cells0 //. $inlineToWorkspaceConversionRules;

        nbo = ConfirmMatch[
            createWorkspaceChat[ EvaluationNotebook[ ], cells ],
            _NotebookObject,
            "Notebook"
        ];

        moveToChatInputField @ nbo;

        settings = ConfirmBy[ AbsoluteCurrentChatSettings @ nbo, AssociationQ, "Settings" ];
        If[ TrueQ @ settings[ "AutoSaveConversations" ], SaveChat[ nbo, settings ] ];

        nbo
    ],
    throwInternalFailure
];

popOutWorkspaceChatNB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$inlineToWorkspaceConversionRules*)
$inlineToWorkspaceConversionRules := $inlineToWorkspaceConversionRules = Dispatch @ {
    Cell[ BoxData @ TemplateBox[ { Cell[ text_ ] }, "UserMessageBox", __ ], "ChatInput", ___ ] :>
        Cell[
            BoxData @ TemplateBox[
                { Cell[ Flatten @ TextData @ text, Background -> None, Selectable -> True, Editable -> True ] },
                "UserMessageBox"
            ],
            "ChatInput"
        ]
    ,
    Cell[
        BoxData @ TemplateBox[ { Cell[ text_, ___ ] }, "AssistantMessageBox", ___ ],
        "ChatOutput",
        ___,
        TaggingRules -> tags_,
        ___
    ] :>
        Cell[
            BoxData @ TemplateBox[
                { Cell[ Flatten @ TextData @ text, Background -> None, Editable -> True, Selectable -> True ] },
                "AssistantMessageBox"
            ],
            "ChatOutput",
            TaggingRules      -> tags,
            GeneratedCell     -> True,
            CellAutoOverwrite -> True
        ]
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SaveAsChatNotebook*)
SaveAsChatNotebook // beginDefinition;
(* FIXME: This seems to often lead to a crash in 14.1, so we might need a version check to make this 14.2+ *)
SaveAsChatNotebook[ nbo_NotebookObject ] := catchMine @ saveAsChatNB @ nbo;
SaveAsChatNotebook // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*saveAsChatNB*)
saveAsChatNB // beginDefinition;

saveAsChatNB[ targetObj_NotebookObject ] := Enclose[
    Catch @ Module[ { cellObjects, title, filepath, cells, settings, nbExpr },
        cellObjects = Cells @ targetObj;
        If[ ! MatchQ[ cellObjects, { __CellObject } ], Throw @ Null ];
        title = Replace[
            CurrentValue[ targetObj, { TaggingRules, "ConversationTitle" } ],
            "" | Except[ _String ] -> None
        ];
        filepath = SystemDialogInput[
            "FileSave",
            If[ title === None,
                "UntitledChat-" <> DateString[ "ISODate" ] <> ".nb",
                StringReplace[ title, " " -> "_" ] <> ".nb"
            ]
        ];
        Which[
            filepath === $Canceled,
                Null,
            StringQ @ filepath && StringEndsQ[ filepath, ".nb" ],
                cells = NotebookRead @ cellObjects;
                If[ ! MatchQ[ cells, { __Cell } ], Throw @ Null ];
                settings = CurrentChatSettings @ targetObj;
                nbExpr = ConfirmMatch[ cellsToChatNB[ cells, settings ], _Notebook, "Converted" ];
                ConfirmBy[ Export[ filepath, nbExpr, "NB" ], FileExistsQ, "Exported" ],
            True,
                Null
        ]
    ],
    throwInternalFailure
];

saveAsChatNB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*popOutChatNB*)
popOutChatNB // beginDefinition;
popOutChatNB[ nbo_NotebookObject ] := popOutChatNB[ NotebookGet @ nbo, CurrentChatSettings @ nbo ];
popOutChatNB[ Notebook[ cells_, ___ ], settings_ ] := popOutChatNB[ cells, settings ];
popOutChatNB[ cells: { ___Cell }, settings_ ] := NotebookPut @ cellsToChatNB[ cells, settings ];
popOutChatNB[ chat_Association, settings_Association ] := popOutChatNB0[ chat, settings ];
popOutChatNB // endDefinition;


popOutChatNB0 // beginDefinition;

popOutChatNB0[ id_, settings_Association ] := Enclose[
    Module[ { loaded, uuid, title, messages, dingbat, cells, options },
        loaded = ConfirmBy[ LoadChat @ id, AssociationQ, "Loaded" ];
        uuid = ConfirmBy[ loaded[ "ConversationUUID" ], StringQ, "UUID" ];
        title = ConfirmBy[ loaded[ "ConversationTitle" ], StringQ, "Title" ];
        messages = ConfirmBy[ loaded[ "Messages" ], ListQ, "Messages" ];
        dingbat = Cell[ BoxData @ makeOutputDingbat @ settings, Background -> None ];
        cells = ConfirmMatch[ updateCellDingbats[ ChatMessageToCell @ messages, dingbat ], { __Cell }, "Cells" ];
        options = Sequence @@ Normal[ settings, Association ];
        ConfirmMatch[ CreateChatNotebook[ cells, options ], _NotebookObject, "Notebook" ]
    ],
    throwInternalFailure
];

popOutChatNB0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overlay Menus*)
$notebookIcon := (RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "FEBitmaps", "NotebookIcon" ][ #1, #2 ] ])&[
    color @ "NA_OverlayMenuNotebookIcon_Gray",
    color @ "NA_OverlayMenuNotebookIcon_Red"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clearOverlayMenus*)
clearOverlayMenus // beginDefinition;

clearOverlayMenus[ nbo_NotebookObject ] := (
    restoreVerticalScrollbar @ nbo;
    NotebookDelete @ Cells[ nbo, CellStyle -> "AttachedOverlayMenu", AttachedCell -> True ]
);

clearOverlayMenus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toggleOverlayMenu*)
toggleOverlayMenu // beginDefinition;

toggleOverlayMenu[ nbo_NotebookObject, None(*appContainer*), name_String ] :=
    Module[ { cell },
        cell = First[
            Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedOverlayMenu", CellTags -> name ],
            Missing[ "NotAttached" ]
        ];

        If[ MissingQ @ cell,
            If[ name == "Sources",
                writeWorkspaceChatSubDockedCell[
                    nbo,
                    Style[
                        tr[ "WorkspaceToolbarSourcesSubTitle" ],
                        FontColor -> color @ "NA_SourcesDockedCellFont", FontFamily -> "Source Sans Pro", FontSlant -> Italic ] ],
                removeWorkspaceChatSubDockedCell[ nbo ]
            ];
            attachOverlayMenu[ nbo, None, name ];
            ,
            If[ CurrentValue[ nbo, { TaggingRules, "ConversationTitle" } ] =!= "",
                writeWorkspaceChatSubDockedCell[ nbo, WindowTitle ],
                removeWorkspaceChatSubDockedCell[ nbo ]
            ];
            restoreVerticalScrollbar @ nbo;
            NotebookDelete @ cell
        ]
    ];

(* Side bar is a single cell UI with a Row of inline cells *)
toggleOverlayMenu[ nbo_NotebookObject, sideBarCell_CellObject, name_String ] :=
    Module[ { cell },
        cell = First[
            Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedOverlayMenu", CellTags -> name ],
            Missing[ "NotAttached" ]
        ];

        If[ MissingQ @ cell,
            If[ name == "Sources",
                writeSideBarChatSubDockedCell[
                    nbo,
                    sideBarCell,
                    Style[
                        tr[ "WorkspaceToolbarSourcesSubTitle" ],
                        FontColor -> color @ "NA_SourcesDockedCellFont", FontFamily -> "Source Sans Pro", FontSlant -> Italic ] ]
                , (* ELSE *)
                removeSideBarChatSubDockedCell[ nbo, sideBarCell ]
            ];
            attachOverlayMenu[ nbo, sideBarCell, name ];
            , (* ELSE there's an existing overlay so get rid of it *)
            If[ CurrentValue[ sideBarCell, { TaggingRules, "ConversationTitle" } ] =!= "",
                writeSideBarChatSubDockedCell[ nbo, sideBarCell, WindowTitle ],
                removeSideBarChatSubDockedCell[ nbo, sideBarCell ]
            ];
            NotebookDelete @ cell
        ]
    ];

toggleOverlayMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*overlayMenu*)
overlayMenu // beginDefinition;
overlayMenu[ nbo_NotebookObject, appContainer_, "Sources" ] := sourcesOverlay[ nbo, appContainer ];
overlayMenu[ nbo_NotebookObject, appContainer_, "History" ] := historyOverlay[ nbo, appContainer ];
overlayMenu[ nbo_NotebookObject, appContainer_, "Loading" ] := loadingOverlay[ nbo, appContainer ];
overlayMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachOverlayMenu*)
attachOverlayMenu // beginDefinition;

attachOverlayMenu[ nbo_NotebookObject, appContainer:None, name_String ] := Enclose[
    hideVerticalScrollbar @ nbo;
    NotebookDelete @ Cells[ nbo, CellStyle -> "AttachedOverlayMenu", AttachedCell -> True ];
    AttachCell[
        nbo,
        Cell[
            BoxData @ ToBoxes @ attachedOverlayMenuFrame @ ConfirmMatch[ overlayMenu[ nbo, appContainer, name ], Except[ _overlayMenu ], "OverlayMenu" ],
            "AttachedOverlayMenu",
            CellTags -> name,
            Magnification -> Dynamic @ AbsoluteCurrentValue[ nbo, Magnification ]
        ],
        { Center, Top },
        0,
        { Center, Top }
    ],
    throwInternalFailure
];

attachOverlayMenu[ nbo_NotebookObject, sideBarCell_CellObject, name_String ] := Enclose[
    Module[ { anchor },
        NotebookDelete @ Cells[ nbo, CellStyle -> "AttachedOverlayMenu", AttachedCell -> True ];
        anchor = First[ Cells[ sideBarCell, CellTags -> "SideBarSubDockedCell" ], Missing @ "NoSubDockedCell" ];
        If[ MissingQ @ anchor,
            (* There should at least be a main "DockedCell" to attach to *)
            anchor = ConfirmMatch[ Last[ Cells[ sideBarCell, CellTags -> "SideBarDockedCell" ], $Failed ], _CellObject, "AttachOverlayToLastDockedCell" ] ];
        AttachCell[
            anchor,
            Cell[
                BoxData @ ToBoxes @ attachedOverlayMenuFrame @ ConfirmMatch[ overlayMenu[ nbo, sideBarCell, name ], Except[ _overlayMenu ], "OverlayMenu" ],
                "AttachedOverlayMenu",
                CellTags -> name,
                Magnification -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ]
            ],
            { Center, Bottom },
            0,
            { Center, Top }
        ]
    ],
    throwInternalFailure
];

attachOverlayMenu // endDefinition;


attachedOverlayMenuFrame // beginDefinition;

attachedOverlayMenuFrame[ content_ ] := Framed[
    content,
    Alignment    -> { Center, Top },
    Background   -> color @ "NA_NotebookBackground",
    FrameMargins -> { { 5, 5 }, { 2000, 5 } },
    FrameStyle   -> color @ "NA_NotebookBackground",
    ImageSize    -> { Scaled[ 1 ], Automatic }
]

attachedOverlayMenuFrame // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withLoadingOverlay*)
withLoadingOverlay // beginDefinition;

withLoadingOverlay // Attributes = { HoldRest };

withLoadingOverlay[ { nbo_NotebookObject, appContainer_ } ] :=
    Function[ eval, withLoadingOverlay[ { nbo, appContainer }, eval ], HoldFirst ];

withLoadingOverlay[ { nbo_NotebookObject, appContainer_ }, eval_ ] :=
    Module[ { attached },
        WithCleanup[
            attached = attachOverlayMenu[ nbo, appContainer, "Loading" ],
            eval,
            NotebookDelete @ attached
        ]
    ];

withLoadingOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadingOverlay*)
loadingOverlay // beginDefinition;

loadingOverlay[ _NotebookObject, appContainer_ ] := Pane[
    ProgressIndicator[ Appearance -> "Necklace" ],
    ImageMargins -> 50
];

loadingOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*restoreVerticalScrollbar*)
restoreVerticalScrollbar // beginDefinition;
restoreVerticalScrollbar[ nbo_NotebookObject ] := CurrentValue[ nbo, WindowElements ] = Inherited;
restoreVerticalScrollbar // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*hideVerticalScrollbar*)
hideVerticalScrollbar // beginDefinition;

hideVerticalScrollbar[ nbo_NotebookObject ] := CurrentValue[ nbo, WindowElements ] =
    DeleteCases[ AbsoluteCurrentValue[ nbo, WindowElements ], "VerticalScrollBar" ];

hideVerticalScrollbar // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Sources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sourcesOverlay*)
sourcesOverlay // beginDefinition;
sourcesOverlay[ nbo_NotebookObject, appContainer_ ] := notebookSources[ nbo, appContainer ]; (* TODO: combined menu that includes files etc. *)
sourcesOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookSources*)
notebookSources // beginDefinition;

(* FIXME: the sources overlay ends up too thin if there are no notebooks open *)
notebookSources[ appNotebook_, appContainer_ ] := Framed[
    Column[
        {
            Pane[
                Style[
                    tr[ "WorkspaceSourcesOpenNotebooks" ],
                    "Text",
                    FontSize   -> 14,
                    FontColor  -> color @ "NA_OverlayMenuFont",
                    FontWeight -> Bold
                ],
                FrameMargins -> { { 5, 5 }, { 3, 3 } }
            ],
            Pane[
                Dynamic @ Grid[
                    Cases[
                        SortBy[
                            If[ appContainer === None,
                                SourceNotebookObjectInformation[ ]
                                , (* ELSE the app is a sub-part of its notebook e.g. the side bar, so exclude its notebook *)
                                Select[ SourceNotebookObjectInformation[ ], #[ "NotebookObject" ] =!= appNotebook&]
                            ],
                            #[ "WindowTitle" ] & ],
                        KeyValuePattern @ { "NotebookObject" -> nbo_NotebookObject, "WindowTitle" -> title_ } :> {
                            Spacer[ 3 ],
                            inclusionCheckbox @ nbo,
                            Item[
                                Button[
                                    MouseAppearance[
                                        Grid[
                                            { {
                                                $notebookIcon,
                                                If[ MatchQ[ title, None|"" ], formatNotebookTitle @ title, Style[ title, color @ "NA_OverlayMenuFont" ] ]
                                            } },
                                            Alignment -> { Left, Baseline }
                                        ],
                                        "LinkHand"
                                    ],
                                    ToggleChatInclusion @ nbo,
                                    Alignment  -> Left,
                                    Appearance -> "Suppressed",
                                    BaseStyle  -> { "Text", FontSize -> 14, LineBreakWithin -> False }
                                ],
                                ItemSize -> Fit
                            ],
                            Button[
                                MouseAppearance[
                                    Mouseover[
                                        Style[ "   \[RightGuillemet]   ", FontColor -> color @ "NA_OverlayMenuFont_2" ],
                                        Style[ "   \[RightGuillemet]   ", FontColor -> color @ "NA_OverlayMenuFont" ]
                                    ],
                                    "LinkHand"
                                ],
                                SetSelectedNotebook @ nbo,
                                Alignment  -> Right,
                                Appearance -> "Suppressed",
                                BaseStyle  -> { "Text", FontFamily -> "Source Sans Pro", FontSize -> 22, FontWeight -> "Plain" }
                            ]
                        }
                    ],
                    Alignment -> { Left, Center },
                    Dividers  -> { False, { False, { color @ "NA_OverlayMenuFrame" }, False } },
                    Spacings  -> { Automatic, { 0, { 1 }, 0 } }
                ],
                FrameMargins -> { { 0, 0 }, { 5, 5 } }
            ]
        },
        Alignment -> Left,
        Background -> { color @ "NA_OverlayMenuHeaderBackground", color @ "NA_OverlayMenuBackground" },
        Dividers -> { None, { 2 -> color @ "NA_OverlayMenuFrame" } }
    ],
    RoundingRadius -> 3,
    FrameMargins   -> 0,
    FrameStyle     -> color @ "NA_OverlayMenuFrame"
];

notebookSources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatNotebookTitle*)
formatNotebookTitle // beginDefinition;
formatNotebookTitle[ None|"" ] := Style[ (*FIXME:TR*)"Unnamed Notebook", FontColor -> color @ "NA_OverlayMenuFont_2", FontSlant -> Italic ];
formatNotebookTitle[ title_String ] := title;
formatNotebookTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inclusionCheckbox*)
inclusionCheckbox // beginDefinition;

inclusionCheckbox[ nbo_NotebookObject ] :=
    Checkbox @ Dynamic[
        ! TrueQ @ CurrentChatSettings[ nbo, "ExcludeFromChat" ],
        ToggleChatInclusion[ nbo, #1 ] &
    ];

inclusionCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*History*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historyOverlay*)
historyOverlay // beginDefinition;

historyOverlay[ nbo_NotebookObject, appContainer_ ] :=
    DynamicModule[ { searching = False, query = "" },
        PaneSelector[
            {
                True  -> historySearchView[ nbo, appContainer, Dynamic @ searching, Dynamic @ query ],
                False -> historyDefaultView[ nbo, appContainer, Dynamic @ searching ]
            },
            Dynamic @ searching,
            ImageSize -> Automatic
        ]
    ];

historyOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historySearchView*)
historySearchView // beginDefinition;

historySearchView[ nbo_NotebookObject, appContainer_, Dynamic[ searching_ ], Dynamic[ query_ ] ] := Enclose[
    Catch @ Module[ { appName, header, view },
        appName = ConfirmBy[ CurrentChatSettings[ If[ appContainer === None, nbo, appContainer ], "AppName" ], StringQ, "AppName" ];

        header = ConfirmMatch[
            makeHistoryHeader @ historySearchField[ Dynamic @ query, Dynamic @ searching ],
            _Pane,
            "Header"
        ];

        view = ConfirmMatch[ makeHistorySearchResults[ nbo, appContainer, appName, Dynamic @ query ], _, "View" ];

        Framed[
            Column[
                { header, view },
                Alignment  -> Left,
                Background -> { color @ "NA_OverlayMenuHeaderBackground", color @ "NA_OverlayMenuBackground" },
                Dividers   -> { None, { 2 -> color @ "NA_OverlayMenuFrame" } }
            ],
            RoundingRadius -> 3,
            FrameMargins   -> 0,
            FrameStyle     -> color @ "NA_OverlayMenuFrame"
        ]
    ],
    throwInternalFailure
];

historySearchView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeHistorySearchResults*)
makeHistorySearchResults // beginDefinition;

makeHistorySearchResults[ nbo_NotebookObject, appContainer_, appName_String, Dynamic[ query_ ] ] := Dynamic[
    showSearchResults[ nbo, appContainer, appName, query ],
    TrackedSymbols :> { query }
];

makeHistorySearchResults // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showSearchResults*)
showSearchResults // beginDefinition;

showSearchResults[ nbo_, appContainer_, appName_, query_String ] := Enclose[
    DynamicModule[ { chats, display },
        chats = ConfirmMatch[ SearchChats[ appName, query ], { ___Association }, "Chats" ];
        display = Pane[ ProgressIndicator[ Appearance -> { "Percolate", color @ "NA_OverlayMenuPercolate" } ], ImageMargins -> 25 ];

        DynamicWrapper[
            Dynamic @ display,
            display =
                Grid[
                    makeHistoryMenuItem[ Dynamic @ chats, nbo, appContainer ] /@ chats,
                    Alignment -> { Left, Center },
                    Dividers  -> { False, { False, { color @ "NA_OverlayMenuFrame" }, False } },
                    Spacings  -> { Automatic, { 0, { 1 }, 0 } }
                ],
            TrackedSymbols :> { chats }
        ]
    ],
    throwInternalFailure
];

showSearchResults // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historySearchField*)
historySearchField // beginDefinition;

historySearchField[ Dynamic[ query_ ], Dynamic[ searching_ ] ] := Grid[
    { {
        InputField[
            Dynamic[ query ],
            String,
            BaseStyle        -> "Text",
            ContinuousAction -> True,
            FieldHint        -> "Search",
            ImageSize        -> { Full, Automatic }
        ],
        historySearchButton @ Dynamic @ searching
    } },
    Alignment -> { Automatic, Baseline }
];

historySearchField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historyDefaultView*)
historyDefaultView // beginDefinition;

historyDefaultView[ nbo_NotebookObject, appContainer_, Dynamic[ searching_ ] ] := Enclose[
    Catch @ Module[ { header, view },
        DynamicModule[ { page = 1, totalPages = Style["\[FilledCircle]", color @ "NA_OverlayMenuPercolate" ] },
            header = ConfirmMatch[ makeHistoryHeader @ historyPagination[ Dynamic @ searching, Dynamic @ page, Dynamic @ totalPages ], _Pane, "Header" ];
            view = ConfirmMatch[ makeDefaultHistoryView[ nbo, appContainer, Dynamic @ page, Dynamic @ totalPages ], _RawBoxes, "View" ];

            Framed[
                Column[
                    { header, view },
                    Alignment  -> Left,
                    Background -> { color @ "NA_OverlayMenuHeaderBackground", color @ "NA_OverlayMenuBackground" },
                    Dividers   -> { None, { 2 -> color @ "NA_OverlayMenuFrame" } }
                ],
                RoundingRadius -> 3,
                FrameMargins   -> 0,
                FrameStyle     -> color @ "NA_OverlayMenuFrame"
            ]
        ]
    ],
    throwInternalFailure
];

historyDefaultView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historyPagination*)
historyPagination // beginDefinition;

historyPagination[ Dynamic[ searching_ ], Dynamic[ page_ ], Dynamic[ totalPages_ ] ] := Grid[
    { {
        Grid[
            { {
                Button[
                    chatbookIcon @ "WorkspaceHistoryFirstPage",
                    page = 1,
                    Appearance       -> "Suppressed",
                    BaselinePosition -> Baseline,
                    Tooltip          -> tr @ "WorkspaceHistoryFirstPage" ],
                Button[
                    chatbookIcon @ "WorkspaceHistoryPreviousPage",
                    If[ IntegerQ @ page && page > 1, page -= 1 ],
                    Appearance       -> "Suppressed",
                    BaselinePosition -> Baseline,
                    Tooltip          -> tr @ "WorkspaceHistoryPreviousPage" ],
                With[{c1 = color @ "NA_OverlayMenuIcon_Blue", c2 = color @ "NA_OverlayMenuHistoryPaginationIcon"},
                    Dynamic[
                        Mouseover[
                            PopupMenu[
                                Dynamic[
                                    None, (* keep this value different from all the possible values so the default appearance, defined below, is used *)
                                    Function[ page = # ] ],
                                If[ IntegerQ @ totalPages && totalPages > 0, Range @ totalPages, { } ],
                                Style[
                                    Row[ { trExprTemplate["WorkspaceHistoryPageTemplate"][ <| "1" -> Dynamic[page], "2" -> Dynamic[totalPages] |> ] } ], (* This is what's actually displayed *)
                                    FontColor -> c2],
                                Appearance       -> None,
                                BaseStyle        -> {FontSize -> 12},
                                BaselinePosition -> Baseline,
                                MenuStyle        -> { Magnification -> 1 } (* This affects the popup list's display as well as the main display *)
                            ],
                            PopupMenu[
                                Dynamic[
                                    None, (* keep this value different from all the possible values so the default appearance, defined below, is used *)
                                    Function[ page = # ] ],
                                If[ IntegerQ @ totalPages && totalPages > 0, Range @ totalPages, { } ],
                                Style[
                                    Row[ { trExprTemplate["WorkspaceHistoryPageTemplate"][ <| "1" -> Dynamic[page], "2" -> Dynamic[totalPages] |> ] } ], (* This is what's actually displayed *)
                                    FontColor -> c1],
                                Appearance       -> None,
                                BaseStyle        -> {FontSize -> 12},
                                BaselinePosition -> Baseline,
                                MenuStyle        -> { Magnification -> 1 } (* This affects the popup list's display as well as the main display *)
                            ],
                            BaselinePosition -> Baseline
                        ],
                        TrackedSymbols :> { totalPages }
                    ]
                ],
                Button[
                    chatbookIcon @ "WorkspaceHistoryNextPage",
                    If[ IntegerQ @ page && IntegerQ @ totalPages && page < totalPages, page += 1 ],
                    Appearance       -> "Suppressed",
                    BaselinePosition -> Baseline,
                    Tooltip          -> tr @ "WorkspaceHistoryNextPage" ],
                Button[
                    chatbookIcon @ "WorkspaceHistoryLastPage",
                    If[ IntegerQ @ totalPages, page = totalPages, Beep[]],
                    Appearance       -> "Suppressed",
                    BaselinePosition -> Baseline,
                    Tooltip          -> tr @ "WorkspaceHistoryLastPage" ]
            } },
            BaselinePosition -> { 1, 2 }
        ],
        historySearchButton @ Dynamic @ searching
    } },
    Alignment -> { Automatic, Baseline },
    ItemSize -> { { Fit, Automatic } }
];

historyPagination // endDefinition;

historySearchButton @ Dynamic @ searching

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeDefaultHistoryView*)
makeDefaultHistoryView // beginDefinition;

makeDefaultHistoryView[ nbo_NotebookObject, appContainer_, Dynamic[ page_ ], Dynamic[ totalPages_ ] ] := Enclose[
    RawBoxes @ ToBoxes @ DynamicModule[ { display },
        display = Pane[ ProgressIndicator[ Appearance -> { "Percolate", color @ "NA_OverlayMenuPercolate" } ], ImageMargins -> 25 ];

        Pane[
            Dynamic[ display, TrackedSymbols :> { display } ],
            Alignment          -> { Center, Top },
            AppearanceElements -> { },
            FrameMargins       -> { { 0, 0 }, { 5, 5 } },
            ImageSize          -> Dynamic @ { Scaled[ 1 ], AbsoluteCurrentValue[ nbo, { WindowSize, 2 } ] },
            Scrollbars         -> Automatic
        ],

        Initialization            :> (display = catchAlways @ makeDefaultHistoryView0[ nbo, appContainer, Dynamic @ page, Dynamic @ totalPages ]),
        SynchronousInitialization -> False
    ],
    throwInternalFailure
];

makeDefaultHistoryView // endDefinition;


makeDefaultHistoryView0 // beginDefinition;

makeDefaultHistoryView0[ nbo_NotebookObject, appContainer_, Dynamic[ page_ ], Dynamic[ totalPages_ ] ] := Enclose[
    DynamicModule[ { appName, chats, display },
        display = Pane[ ProgressIndicator[ Appearance -> { "Percolate", color @ "NA_OverlayMenuPercolate" } ], ImageMargins -> 25 ];
        appName = ConfirmBy[ CurrentChatSettings[ If[ appContainer === None, nbo, appContainer ], "AppName" ], StringQ, "AppName" ];
        chats = ConfirmMatch[ ListSavedChats @ appName, { ___Association }, "Chats" ];
        
        DynamicWrapper[
            Dynamic @ display,
            display =
                Grid[
                    With[ { pages = Partition[ chats, UpTo @ $maxHistoryItems ] },
                        totalPages = Length @ pages;
                        If[ totalPages == 0,
                            { { "No history" } } (* FIXME: add text resource *)
                            ,
                            If[ Not[ IntegerQ @ page && page >= 1 && page <= totalPages ], page = 1 ];
                            makeHistoryMenuItem[ Dynamic @ chats, nbo, appContainer ] /@ pages[[ page ]]
                        ]
                    ],
                    Alignment -> { Left, Center },
                    Dividers  -> { False, { False, { color @ "NA_OverlayMenuFrame" }, False } },
                    Spacings  -> { Automatic, { 0, { 1 }, 0 } }
                ],
            TrackedSymbols :> { page, chats }
        ]
    ],
    throwInternalFailure
];

makeDefaultHistoryView0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeHistoryHeader*)
makeHistoryHeader // beginDefinition;

makeHistoryHeader[ extraContent_ ] := Pane[
    Grid[
        {
            {
                Style[ tr[ "WorkspaceHistoryTitle" ], "Text", FontSize -> 14, FontColor -> color @ "NA_OverlayMenuFont", FontWeight -> Bold ],
                extraContent
            }
        },
        Alignment -> { { Left, Right }, Center },
        ItemSize  -> { { Fit, Automatic }, Automatic }
    ],
    FrameMargins -> { { 5, 5 }, { 3, 3 } }
];

makeHistoryHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*searchButton*)
historySearchButton // beginDefinition;

historySearchButton[ Dynamic[ searching_ ] ] := Button[
    $searchButtonLabel,
    searching = ! TrueQ @ searching,
    Alignment  -> Right,
    Appearance -> "Suppressed"
];

historySearchButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeHistoryMenuItem*)
makeHistoryMenuItem // beginDefinition;

makeHistoryMenuItem[ chats_Dynamic, nbo_NotebookObject, appContainer_ ] :=
    makeHistoryMenuItem[ chats, nbo, appContainer, # ] &;

makeHistoryMenuItem[ Dynamic[ chats_ ], nbo_NotebookObject, appContainer_, chat_Association ] := Enclose[
    Module[ { title, date, timeString, default, hover },
        title = ConfirmBy[ chat[ "ConversationTitle" ], StringQ, "Title" ];
        date = DateObject[ ConfirmBy[ chat[ "Date" ], NumericQ, "Date" ], TimeZone -> 0 ];
        timeString = ConfirmBy[ relativeTimeString @ date, StringQ, "TimeString" ];

        default = Grid[
            { {
                title,
                Style[ timeString, FontColor -> color @ "NA_OverlayMenuFontSubtle" ]
            } },
            Alignment -> { { Left, Right }, Baseline },
            BaseStyle -> { "Text", FontSize -> 14, LineBreakWithin -> False },
            ItemSize  -> Fit
        ];

        hover = Grid[
            { {
                Button[
                    title,
                    loadConversation[ nbo, appContainer, chat ],
                    Alignment  -> Left,
                    Appearance -> "Suppressed",
                    BaseStyle  -> { "Text", FontSize -> 14, LineBreakWithin -> False },
                    Method     -> "Queued"
                ],
                Grid[
                    { {
                        Button[
                            $popOutButtonLabel,
                            popOutChatNB[ chat, CurrentChatSettings @ If[ appContainer === None, nbo, appContainer ] ],
                            Appearance -> "Suppressed",
                            Method     -> "Queued"
                        ],
                        Button[
                            $trashButtonLabel,
                            DeleteChat @ chat;
                            removeChatFromRows[ Dynamic @ chats, chat ],
                            Appearance -> "Suppressed",
                            Method     -> "Queued"
                        ]
                    } }
                ]
            } },
            Alignment  -> { { Left, Right }, Baseline },
            Background -> color @ "NA_OverlayMenuItemBackgroundHover",
            ItemSize   -> Fit
        ];

        {
            Style[ Spacer[ 3 ], TaggingRules -> <| "ConversationUUID" -> chat[ "ConversationUUID" ] |> ],
            Mouseover[ default, hover ],
            Spacer[ 3 ]
        }
    ],
    throwInternalFailure
];

makeHistoryMenuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeChatFromRows*)
removeChatFromRows // beginDefinition;

removeChatFromRows[ Dynamic[ chats_ ], KeyValuePattern[ "ConversationUUID" -> uuid_String ] ] :=
    chats = DeleteCases[ chats, KeyValuePattern[ "ConversationUUID" -> uuid ] ];

removeChatFromRows // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadConversation*)
loadConversation // beginDefinition;

loadConversation[ nbo_NotebookObject, None, id_ ] := Enclose[
    Module[ { loaded, uuid, title, messages, cells, cellObjects },

        loaded = ConfirmBy[ LoadChat @ id, AssociationQ, "Loaded" ];
        uuid = ConfirmBy[ loaded[ "ConversationUUID" ], StringQ, "UUID" ];
        title = ConfirmBy[ loaded[ "ConversationTitle" ], StringQ, "Title" ];
        messages = ConfirmBy[ loaded[ "Messages" ], ListQ, "Messages" ];
        cells = ConfirmMatch[ ChatMessageToCell[ messages, "Workspace" ], { __Cell }, "Cells" ];
        cellObjects = ConfirmMatch[ Cells @ nbo, { ___CellObject }, "CellObjects" ];
        ConfirmMatch[ NotebookDelete @ cellObjects, { Null... }, "Delete" ];
        NotebookDelete @ First[ Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ], $Failed ];

        WithCleanup[
            CurrentValue[ nbo, Selectable ] = True,
            SelectionMove[ nbo, Before, Notebook, AutoScroll -> True ];
            ConfirmMatch[ NotebookWrite[ nbo, cells, AutoScroll -> False ], Null, "Write" ];
            If[ Cells @ nbo === { }, NotebookWrite[ nbo, cells, AutoScroll -> False ] ],
            CurrentValue[ nbo, Selectable ] = Inherited
        ];

        ChatbookAction[ "AttachWorkspaceChatInput", nbo ];
        CurrentChatSettings[ nbo, "ConversationUUID" ] = uuid;
        CurrentValue[ nbo, { TaggingRules, "ConversationTitle" } ] = title;
        writeWorkspaceChatSubDockedCell[ nbo, WindowTitle ];
        restoreVerticalScrollbar @ nbo;
        moveToChatInputField[ nbo, True ]
    ] // withLoadingOverlay[ { nbo, None } ],
    throwInternalFailure
];

(* if we need to distinguish this further then condition on TrueQ @ CurrentValue[ sideBarCell, { TaggingRules, "ChatNotebookSettings", "SideBarChat" } ] *)
loadConversation[ nbo_NotebookObject, sideBarCell_CellObject, id_ ] := Enclose[
    Module[ { loaded, uuid, title, messages, cells, lastDockedCell, scrollablePaneCell },
        (* load new cells *)
        loaded = ConfirmBy[ LoadChat @ id, AssociationQ, "Loaded" ];
        uuid = ConfirmBy[ loaded[ "ConversationUUID" ], StringQ, "UUID" ];
        title = ConfirmBy[ loaded[ "ConversationTitle" ], StringQ, "Title" ];
        messages = ConfirmBy[ loaded[ "Messages" ], ListQ, "Messages" ];
        cells = ConfirmMatch[ ChatMessageToCell[ messages, "SideBar" ], { __Cell }, "Cells" ];
        
        (* all old top-cells are within an inline cell that scrolls. Overwrite that cell if it exists, otherwise create it anew *)
        scrollablePaneCell = First[ Cells[ sideBarCell, CellTags -> "SideBarScrollingContentCell" ], Missing @ "NoScrollingContent" ];
        If[ MissingQ @ scrollablePaneCell,
            lastDockedCell = ConfirmMatch[ Last[ Cells[ sideBarCell, CellTags -> "SideBarDockedCell" ], $Failed ], _CellObject, "SideBarDockedCell" ];
            WithCleanup[
                FrontEndExecute[ {
                    FrontEnd`SetOptions[ sideBarCell, Editable -> True ],
                    FrontEnd`SelectionMove[ lastDockedCell, After, Cell, AutoScroll -> True ],
                    FrontEnd`NotebookWrite[ nbo, RowBox[ { "\n", sideBarScrollingCell[ nbo, cells ] } ] ]
                } ]
                ,
                CurrentValue[ sideBarCell, Editable ] = Inherited
            ]
            , (* ELSE *)
            WithCleanup[
                FrontEndExecute[ {
                    FrontEnd`SetOptions[ sideBarCell, Editable -> True ],
                    FrontEnd`NotebookWrite[ scrollablePaneCell, sideBarScrollingCell[ nbo, cells ] ]
                } ]
                ,
                CurrentValue[ sideBarCell, Editable ] = Inherited
            ]
        ];
        
        CurrentChatSettings[ sideBarCell, "ConversationUUID" ] = uuid;
        CurrentValue[ sideBarCell, { TaggingRules, "ConversationTitle" } ] = title;
        writeSideBarChatSubDockedCell[ nbo, sideBarCell, WindowTitle ];
        (* TODO: moveToChatInputField[ nbo, True ] *)
    ] // withLoadingOverlay[ { nbo, sideBarCell } ],
    throwInternalFailure
];

loadConversation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Icons*)
$searchButtonLabel := $searchButtonLabel = chatbookIcon[ "WorkspaceHistorySearchIcon", False ];
$popOutButtonLabel := $popOutButtonLabel = chatbookIcon[ "WorkspaceHistoryPopOutIcon", False ];
$trashButtonLabel  := $trashButtonLabel  = chatbookIcon[ "WorkspaceHistoryTrashIcon" , False ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Global Progress Bar*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withSideBarGlobalProgress*)
withSideBarGlobalProgress // beginDefinition;
withSideBarGlobalProgress // Attributes = { HoldRest };

withSideBarGlobalProgress[ nbo_NotebookObject, eval_ ] := Enclose[
    Catch @ Module[ { sideBarCell, attachmentPoint, attached },

        (* first look for a sub-docked cell *)
        sideBarCell = ConfirmMatch[ sideBarCellObject @ nbo, _CellObject, "SideBarCell" ];
        attachmentPoint = Last[ Cells[ sideBarCell, CellTags -> "SideBarSubDockedCell" ], Missing @ "NoSubDockedCell" ];
        If[ MissingQ @ attachmentPoint,
            attachmentPoint = ConfirmMatch[ Last[ Cells[ sideBarCell, CellTags -> "SideBarDockedCell" ], $Failed ], _CellObject, "SideBarDockedCell" ];
        ];

        attached = ConfirmMatch[
            AttachCell[
                attachmentPoint,
                Cell[
                    BoxData @ ToBoxes @ $workspaceChatProgressBar,
                    "WorkspaceChatProgressBar",
                    FontSize -> 0.1,
                    Magnification -> AbsoluteCurrentValue[ nbo, Magnification ]
                ],
                { Center, Bottom },
                Offset[ { 0, 1 }, { 0, 0 } ],
                { Center, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ],
            _CellObject,
            "Attached"
        ];

        WithCleanup[ eval, NotebookDelete @ attached ]
    ],
    throwInternalFailure
];

withSideBarGlobalProgress // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withWorkspaceGlobalProgress*)
withWorkspaceGlobalProgress // beginDefinition;
withWorkspaceGlobalProgress // Attributes = { HoldRest };

withWorkspaceGlobalProgress[ nbo_NotebookObject, eval_ ] := Enclose[
    Catch @ Module[ { attached },

        attached = ConfirmMatch[
            AttachCell[
                nbo,
                Cell[
                    BoxData @ ToBoxes @ $workspaceChatProgressBar,
                    "WorkspaceChatProgressBar",
                    FontSize -> 0.1,
                    Magnification -> AbsoluteCurrentValue[ nbo, Magnification ]
                ],
                { Center, Top },
                Offset[ { 0, 1 }, { 0, 0 } ],
                { Center, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ],
            _CellObject,
            "Attached"
        ];

        WithCleanup[ eval, NotebookDelete @ attached ]
    ],
    throwInternalFailure
];

withWorkspaceGlobalProgress // endDefinition;


(* Work around VertexColors not understanding LightDarkSwitched. This must work in all versions 14.1, 14.2, etc. *)
$workspaceChatProgressBar := With[
    {
        darkModeQ = AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[], LightDark ] === "Dark"
    },
    {
        background  = Replace[ color @ "NA_ProgressBarEdgeColor",   l_LightDarkSwitched :> If[ darkModeQ, Last, First ][l] ],
        colorCenter = Replace[ color @ "NA_ProgressBarCenterColor", l_LightDarkSwitched :> If[ darkModeQ, Last, First ][l] ],
        colorEdges  = Replace[ color @ "NA_ProgressBarEdgeColor",   l_LightDarkSwitched :> If[ darkModeQ, Last, First ][l] ],
        duration    = 2.5
    },
    Graphics[
        {
            Thickness[ 1 ],
            Dynamic @ TemplateBox[
                { Clock[ { -0.2, 1.0 }, duration ], Clock[ { 0.0, 1.2 }, duration ] },
                "WorkspaceChatProgressBar",
                DisplayFunction -> Function[
                    LineBox[
                        {
                            { #1, 0 },
                            { (#1 + #2) / 2, 0 },
                            { #2, 0 }
                        },
                        VertexColors -> { colorEdges, colorCenter, colorEdges }
                    ]
                ]
            ]
        },
        AspectRatio      -> Full,
        Background       -> background,
        ImageMargins     -> 0,
        ImageSize        -> { Full, 4 },
        PlotRange        -> { { 0, 1 }, Automatic },
        PlotRangePadding -> None
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $inlineToWorkspaceConversionRules;
    $defaultUserImage;
    $smallNotebookIcon;
];

End[ ];
EndPackage[ ];
