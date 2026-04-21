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
$sidebarScrollPosition;        (* never has a value, uses Unique to create variables per sidebar *)
$assistantTier               = "Basic";

$inputFieldOptions = Sequence[
    Alignment  -> { Automatic, Baseline },
    Appearance -> "Frameless",
    BaseStyle  -> { "Text", "TextStyleInputField" }, (* second BaseStyle makes contractions, line wrapping, etc. more text like *)
    BoxID      -> "AttachedChatInputField",
    ImageSize  -> { Scaled[ 1 ], Automatic }
];

$inputFieldFrameOptions = Sequence[
    Alignment      -> { Automatic, Baseline },
    Background     -> color @ "NA_ChatInputFieldBackground",
    FrameMargins   -> { { 7, 3 }, { 3, 3 } },
    FrameStyle     -> Directive[ AbsoluteThickness[ 1.75 ], color @ "NA_ChatInputFieldFrame" ],
    RoundingRadius -> 8
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

blueHueButtonAppearance[ "ChatbarMinimized" ] :=
mouseDown[
    Framed[
        chatbookIcon[ "ChatbarChatBubbleMinimizedIcon", False, color @ "NA_ChatbarMinimizedButtonIconBackground1", color @ "NA_BlueHueButtonIcon" ],
        Alignment      -> { Center, Center },
        Background     -> color @ "NA_ChatbarMinimizedButtonBackground",
        FrameMargins   -> 0,
        FrameStyle     -> color @ "NA_ChatbarMinimizedButtonFrame",
        ImageSize      -> { 32, 32 },
        RoundingRadius -> 8
    ],
    Framed[
        chatbookIcon[ "ChatbarChatBubbleMinimizedIcon", False, color @ "NA_ChatbarMinimizedButtonIconBackground2", color @ "NA_BlueHueButtonIcon" ],
        Alignment      -> { Center, Center },
        Background     -> color @ "NA_ChatbarMinimizedButtonBackgroundHover",
        FrameMargins   -> 0,
        FrameStyle     -> color @ "NA_ChatbarMinimizedButtonFrameHover",
        ImageSize      -> { 32, 32 },
        RoundingRadius -> 8
    ],
    Framed[
        chatbookIcon[ "ChatbarChatBubbleMinimizedIcon", False, color @ "NA_ChatbarMinimizedButtonIconBackground2", color @ "NA_BlueHueButtonIcon" ],
        Alignment      -> { Center, Center },
        Background     -> color @ "NA_ChatbarMinimizedButtonBackgroundPressed",
        FrameMargins   -> 0,
        FrameStyle     -> color @ "NA_ChatbarMinimizedButtonFramePressed",
        ImageSize      -> { 32, 32 },
        RoundingRadius -> 8
    ]
]

blueHueButtonAppearance[ icon_, imageSize_, frameMargins_:0 ] := blueHueButtonAppearance[ { icon, icon, icon }, imageSize, frameMargins ]

blueHueButtonAppearance[ { default_, hover_, pressed_ }, imageSize_, frameMargins_:0 ] :=
mouseDown[
    Framed[
        default,
        Alignment      -> { Center, Center },
        Background     -> None,
        FrameMargins   -> frameMargins,
        FrameStyle     -> None,
        ImageSize      -> imageSize,
        RoundingRadius -> 4
    ],
    Framed[
        hover,
        Alignment      -> { Center, Center },
        Background     -> color @ "NA_BlueHueButtonBackgroundHover",
        FrameMargins   -> frameMargins,
        FrameStyle     -> color @ "NA_BlueHueButtonFrameHover",
        ImageSize      -> imageSize,
        RoundingRadius -> 4
    ],
    Framed[
        pressed,
        Alignment      -> { Center, Center },
        Background     -> color @ "NA_BlueHueButtonBackgroundPressed",
        FrameMargins   -> frameMargins,
        FrameStyle     -> color @ "NA_BlueHueButtonFramePressed",
        ImageSize      -> imageSize,
        RoundingRadius -> 4
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sidebar Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSidebarChatDockedCell*)
makeSidebarChatDockedCell // beginDefinition;

makeSidebarChatDockedCell[ ] := With[ { nbo = EvaluationNotebook[ ], sidebarCell = EvaluationCell[ ] },
    Cell[
        BoxData @ ToBoxes @ DynamicModule[ { thisCell },
            Framed[
                Grid[
                    { {
                        sidebarNewChatButton[ nbo, sidebarCell ],
                        Item[ Spacer[ 0 ], ItemSize -> Fit ],
                        sidebarSourcesButton[ nbo, sidebarCell ],
                        sidebarHistoryButton[ nbo, sidebarCell ],
                        sidebarOpenAsAssistantWindowButton[ nbo, sidebarCell ],
                        sidebarHideButton @ nbo
                    } },
                    Alignment -> { Automatic, Center },
                    Spacings  -> 0.2
                ],
                Background   -> color @ "NA_Toolbar",
                FrameStyle   -> color @ "NA_Toolbar",
                FrameMargins -> { { 2, 0 }, { 0, 1 } },
                ImageMargins -> 0
            ],
            SynchronousInitialization -> False,
            Initialization :> ((* 473816: this runs whenever the kernel is quit, so avoid duplicating existing cell *)
                thisCell = EvaluationCell[ ];
                
                withLoadingOverlay[ { nbo, sidebarCell } ] @ (
                    (* create the chat input cell first, then the scrolling cell *)
                    If[ NextCell[ thisCell, CellStyle -> "ChatInputField" ] === None,
                        NotebookWrite[ NotebookLocationSpecifier[ thisCell, "After" ], makeSidebarChatInputCell[ nbo, sidebarCell ] ]
                    ];
                    If[ Cells[ sidebarCell, AttachedCell -> True, CellTags -> "NotebookAssistantSidebarAttachedHelperCell" ] === { },
                        AttachCell[ sidebarCell, Cell[ "", CellTags -> "NotebookAssistantSidebarAttachedHelperCell" ], { Left, Top }, 0, { Left, Top } ]
                    ];
                    If[ CurrentValue[ sidebarCell, { TaggingRules, "ChatNotebookSettings", "SidebarChat" } ] === Inherited,
                        setCurrentValue[ sidebarCell, TaggingRules, <| "ChatNotebookSettings" -> NotebookAssistanceSidebarSettings[ ], "ConversationTitle" -> "" |> ]
                    ];
                    If[ Not @ TrueQ @ $workspaceChatInitialized,
                        initializeWorkspaceChat[ ]
                    ];
                    With[ { chatInputCell = NextCell[ thisCell, CellStyle -> "ChatInputField" ] },
                        FrontEnd`MoveCursorToInputField[ nbo, "AttachedChatInputField", chatInputCell, chatInputCell ]
                    ];
                );

                ReleaseHold @ $sidebarChatInitialAction;
            )
        ],
        "NotebookAssistant`Sidebar`DockedCell",
        CellFrame        -> 0,
        CellFrameMargins -> 0,
        CellTags         -> "SidebarDockedCell",
        Magnification    -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ]
    ]
];

makeSidebarChatDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeSidebarChatTitleCell*)
writeSidebarChatTitleCell // beginDefinition;

(* chat title cells are added below the top stripe *)
writeSidebarChatTitleCell[ nbo_NotebookObject, sidebarCell_CellObject, WindowTitle ] := Enclose[
    Module[ { chatTitleCell, topStripeCell, content, cellExpr },
        content = Style[
            FE`Evaluate @ FEPrivate`TruncateStringToWidth[
                CurrentValue[ sidebarCell, { TaggingRules, "ConversationTitle" } ],
                "NotebookAssistant`Sidebar`ToolbarTitle",
                #,
                Right
            ]&[ AbsoluteCurrentValue[ "ViewSize" ][[1]] - 10 ],
            "NotebookAssistant`Sidebar`ToolbarTitle"
        ];
        
        cellExpr = Join[
            Insert[
                DeleteCases[
                    makeWorkspaceChatSubDockedCellExpression[ content, color @ "NA_ToolbarTitleBackground", "SidebarChatTitleCell" ],
                    _[ Magnification, _]
                ],
                "NotebookAssistant`Sidebar`ChatTitleCell",
                2
            ],
            Cell[
                Deletable            -> True, (* this cell can be replaced so override Deletable -> False inherited from the main sidebar cell *)
                FontSize             -> 12,
                Magnification        -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ],
                ShowStringCharacters -> False
            ]
        ];

        chatTitleCell = First[ Cells[ sidebarCell, CellTags -> "SidebarChatTitleCell" ], $Failed ];
        If[ ! FailureQ @ chatTitleCell,
            (* if the sub-cell already exists then rewrite it *)
            NotebookWrite[ chatTitleCell, cellExpr ]
            ,
            (* else, write a new sub-cell after the top stripe *)
            topStripeCell = ConfirmMatch[ First[ Cells @ sidebarCell, $Failed ], _CellObject, "SidebarChatTopStripeCell" ];
            NotebookWrite[ NotebookLocationSpecifier[ topStripeCell, "After" ], cellExpr ]
        ];
    ],
    throwInternalFailure
]

writeSidebarChatTitleCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeSidebarChatSubDockedCell*)
removeSidebarChatSubDockedCell // beginDefinition;

removeSidebarChatSubDockedCell[ nbo_NotebookObject, sidebarCell_CellObject ] :=
    NotebookDelete /@ Cells[ sidebarCell, CellTags -> "SidebarSourcesDockedCell" | "SidebarChatTitleCell" ];

removeSidebarChatSubDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeSidebarTopCell*)
removeSidebarTopCell // beginDefinition;

removeSidebarTopCell[ nbo_NotebookObject, sidebarTopCell_CellObject ] := NotebookDelete @ sidebarTopCell;

removeSidebarTopCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSidebarChatScrollingCell*)

makeSidebarChatScrollingCell // beginDefinition;

(* This is an "empty" cell used for new sidebar chats
    * see resource NotebookAssistantSidebarCell.wl
    * this cell is overwritten during evaluateSidebarChat because we detect that this cell has no inline cells *)
makeSidebarChatScrollingCell[ nbo_NotebookObject, dockedCell_CellObject, chatIntputCell_CellObject ] :=
Cell[ BoxData @ ToBoxes @
    Pane[
        Grid[
            {
                { Style[ tr @ "SidebarOverlayAskAnything" , "TextStyling", FontColor -> color @ "NA_OverlayAskAnythingFontColor", FontFamily -> "Source Sans Pro", FontSize -> 19 ] },
                { chatbookIcon[ "SidebarAskAnythingArrowIcon" , False ] } },
            Alignment -> { Center, Center },
            Spacings  -> { 0, 0 }
        ],
        Alignment          -> { Center, Bottom },
        AppearanceElements -> { },
        FrameMargins       -> { { 0, 0 }, { 33, 0 } },
        ImageSize ->
            Dynamic @ {(* run entirely in the front end evaluator *)
                Scaled[ 1. ],
                FEPrivate`Round[
                    (FrontEnd`AbsoluteCurrentValue[ "ViewSize" ][[2]]
                    - 7 (* the top bar that better separates the sidebar from the default toolbar *)
                    - FrontEnd`AbsoluteCurrentValue[     dockedCell, { CellSize, 2 } ]
                    - FrontEnd`AbsoluteCurrentValue[ chatIntputCell, { CellSize, 2 } ]
                    )/(0.85*FrontEnd`AbsoluteCurrentValue[ nbo, Magnification ])
                ] },
        Scrollbars -> { False, False }
    ],
    "NotebookAssistant`Sidebar`ScrollingContentCell",
    Background    -> color @ "NA_NotebookBackground",
    CellTags      -> "SidebarScrollingContentCell",
    Deletable     -> True, (* this cell can be replaced so override Deletable -> False inherited from the main sidebar cell *)
    Magnification -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ]
]

(* This version is perhaps more efficient if the CellObjects already exist as we can reference them directly in the dynamic ImageSize *)
makeSidebarChatScrollingCell[ nbo_NotebookObject, sidebarCell_CellObject, cells:{ ___Cell } ] := Enclose[
    Unset[$sidebarScrollPosition];
    With[ { sym = Unique @ $sidebarScrollPosition },
        Function[ { cell1, cell2 },
            Cell[ BoxData @
                PaneBox[
                    RowBox @ cells,
                    AppearanceElements -> {},
                    ImageSize -> 
                        Dynamic @ {(* run entirely in the front end evaluator *)
                            Scaled[ 1. ],
                            FEPrivate`Round[
                                (FrontEnd`AbsoluteCurrentValue[ "ViewSize" ][[2]]
                                - 7 (* the top bar that better separates the sidebar from the default toolbar *)
                                - If[ FEPrivate`NumericQ @ #1, #1, 0 ]
                                - If[ FEPrivate`NumericQ @ #2, #2, 0 ]
                                - If[ FEPrivate`NumericQ @ #3, #3, 0 ]
                                )/(0.85*FrontEnd`AbsoluteCurrentValue[ nbo, Magnification ])
                            ]&[
                                FrontEnd`AbsoluteCurrentValue[ FrontEnd`PreviousCell[ CellTags -> "SidebarChatTitleCell" ], { CellSize, 2 } ],
                                FrontEnd`AbsoluteCurrentValue[ cell1, { CellSize, 2 } ],
                                FrontEnd`AbsoluteCurrentValue[ cell2, { CellSize, 2 } ]
                            ] },
                    Scrollbars     -> { False, Automatic },
                    ScrollPosition -> Dynamic @ sym
                ],
                "NotebookAssistant`Sidebar`ScrollingContentCell",
                Background    -> color @ "NA_NotebookBackground",
                CellTags      -> "SidebarScrollingContentCell",
                Deletable     -> True, (* this cell can be replaced so override Deletable -> False inherited from the main sidebar cell *)
                Magnification -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ],
                TaggingRules  -> <| "ScrollPositionSymbol" :> sym |>
            ]
        ] @@ ConfirmMatch[ Cells[ sidebarCell, CellTags -> "SidebarDockedCell" | "SidebarChatInputCell" ], { _CellObject, _CellObject }, "MakeScrollingSidebarCell"]
    ]
    ,
    throwInternalFailure
];

makeSidebarChatScrollingCell // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeSidebarScrollingCellContent*)
removeSidebarScrollingCellContent // beginDefinition;

removeSidebarScrollingCellContent[ nbo_NotebookObject, sidebarCell_CellObject ] := Module[ { scrollablePaneCell },
    scrollablePaneCell = First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], Missing @ "NoScrollingSidebarCell" ];
    If[ ! MissingQ @ scrollablePaneCell, NotebookDelete /@ Cells[ scrollablePaneCell ] ]
];

removeSidebarScrollingCellContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Sidebar toolbar buttons*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sidebarHistoryButton*)
sidebarHistoryButton // beginDefinition;

sidebarHistoryButton[ nbo_NotebookObject, sidebarCell_CellObject ] := Button[
    blueHueButtonAppearance[
        toolbarButtonLabel[ "WorkspaceToolbarIconHistory", "WorkspaceToolbarButtonLabelHistory", "WorkspaceToolbarButtonTooltipHistory" ],
        { Automatic, 24 },
        { { 5, 5 }, { 0, 0 } }
    ],
    toggleOverlayMenu[ nbo, sidebarCell, "History" ],
    Appearance -> "Suppressed"
];

sidebarHistoryButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sidebarSourcesButton*)
sidebarSourcesButton // beginDefinition;

sidebarSourcesButton[ nbo_NotebookObject, sidebarCell_CellObject ] := Button[
    blueHueButtonAppearance[
        toolbarButtonLabel[ "WorkspaceToolbarIconSources", "WorkspaceToolbarButtonLabelSources", "WorkspaceToolbarButtonTooltipSources" ],
        { Automatic, 24 },
        { { 5, 5 }, { 0, 0 } }
    ],
    toggleOverlayMenu[ nbo, sidebarCell, "Sources" ],
    Appearance -> "Suppressed"
];

sidebarSourcesButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sidebarNewChatButton*)
sidebarNewChatButton // beginDefinition;

sidebarNewChatButton[ nbo_NotebookObject, sidebarCell_CellObject ] :=
    Button[
        blueHueButtonAppearance[
            toolbarButtonLabel[ "WorkspaceToolbarIconNew", "WorkspaceToolbarButtonLabelNew", "WorkspaceToolbarButtonTooltipNew" ],
            { Automatic, 24 },
            { { 5, 5 }, { 0, 0 } }
        ]
        ,
        NotebookDelete @ Cells[ nbo, CellStyle -> "AttachedOverlayMenu", AttachedCell -> True ];
        removeSidebarScrollingCellContent[ nbo, sidebarCell ];
        removeSidebarChatSubDockedCell[ nbo, sidebarCell ];
        CurrentChatSettings[ sidebarCell, "ConversationUUID" ] = CreateUUID[ ];
        setCurrentValue[ sidebarCell, { TaggingRules, "ConversationTitle" }, "" ]
        ,
        Appearance -> "Suppressed",
        Method     -> "Queued"
    ];

sidebarNewChatButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sidebarOpenAsAssistantWindowButton*)
sidebarOpenAsAssistantWindowButton // beginDefinition;

sidebarOpenAsAssistantWindowButton[ nbo_NotebookObject, sidebarCell_CellObject ] := Button[
    blueHueButtonAppearance[
        toolbarButtonLabel[ "WorkspaceToolbarIconOpenAsChatbook", None, "SidebarToolbarButtonTooltipOpenAsWindowedAssistant" ],
        { 24, 24 }
    ],
    With[
        {
            newNB = ShowNotebookAssistance[ nbo, "Window",
                "ChatNotebookSettings" -> KeyDrop[ CurrentValue[ sidebarCell, { TaggingRules, "ChatNotebookSettings" } ], "SidebarChat" ] ]
        },
        If[ MatchQ[ newNB, _NotebookObject ],
            SelectionMove[ newNB, Before, Notebook ];
            NotebookWrite[
                newNB,
                ReplaceRepeated[
                    NotebookRead @ Cells[ First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], {} ], CellTags -> "SidebarTopCell" ], (* fail gracefully *)
                    (* so far there's only one TemplateBox that needs to be unconverted *)
                    {
                        Cell[ a___, CellTags -> { b___, "SidebarTopCell", c___ }, d___ ] :>
                            RuleCondition[ Cell[ a, CellTags -> { b, c }, d ], True ],
                        Cell[ a___, CellTags -> "SidebarTopCell" | { }, b___ ] :>
                            RuleCondition[ Cell[ a, b ], True ],
                        Cell[ a_, b___String, c_String /; StringStartsQ[ c, "NotebookAssistant`Sidebar`" ], d___ ] :>
                            RuleCondition[ Cell[ a, b, StringReplace[ c, StartOfString ~~ "NotebookAssistant`Sidebar`" -> "" ], d ], True ],
                        TemplateBox[ a_, b_String /; StringStartsQ[ b, "NotebookAssistant`Sidebar`" ], c___] :>
                            RuleCondition[ TemplateBox[ a, StringReplace[ b, StartOfString ~~ "NotebookAssistant`Sidebar`" -> "" ], c ], True ]
                    }
                ]
            ];
            attachWorkspaceChatInput @ newNB;
            With[ { chatTitle = CurrentValue[ sidebarCell, { TaggingRules, "ConversationTitle" } ] },
                If[ chatTitle =!= "",
                    setCurrentValue[ newNB, { TaggingRules, "ConversationTitle" }, chatTitle ];
                    writeWorkspaceChatTitleDockedCell[ newNB, WindowTitle ]
                ]
            ];
            
            (* remove sidebar and its content *)
            NotebookDelete @ Cells[ nbo, CellStyle -> "AttachedOverlayMenu", AttachedCell -> True ];
            removeSidebarScrollingCellContent[ nbo, sidebarCell ];
            removeSidebarChatSubDockedCell[ nbo, sidebarCell ];
            CurrentChatSettings[ sidebarCell, "ConversationUUID" ] = CreateUUID[ ];
            setCurrentValue[ sidebarCell, { TaggingRules, "ConversationTitle" }, "" ];
            FrontEndTokenExecute[ nbo, "HideSidebar" ];
        ]
    ],
    Appearance -> "Suppressed",
    Method     -> "Queued"
];

sidebarOpenAsAssistantWindowButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sidebarHideButton*)

sidebarHideButton // beginDefinition;

sidebarHideButton[ nbo_NotebookObject ] := Button[
    blueHueButtonAppearance[
        toolbarButtonLabel[ "SidebarIconHide", None, "SidebarToolbarButtonTooltipHideSidebar" ],
        { 24, 24 }
    ],
    setCurrentValue[ $FrontEndSession, "ShowNotebookAssistant", False ];
    FrontEndTokenExecute[nbo, "HideSidebar"],
    Appearance -> "Suppressed"
]

sidebarHideButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sidebarChatInputCellSendButton*)
sidebarChatInputCellSendButton // beginDefinition;

Attributes[ sidebarChatInputCellSendButton ] = { HoldAll };

sidebarChatInputCellSendButton[ fieldContent_, input_, returnKeyDownQ_, chatEvalCell_ ] :=
PaneSelector[
    {
        False ->
            Button[
                blueHueButtonAppearance[ chatbookIcon[ "SendChatArrow", False, color @ "NA_BlueHueButtonIcon", 13 ], { 24.5, 24.5 } ],
                If[ ! validInputStringQ @ fieldContent, fieldContent = "", input = fieldContent; fieldContent = ""; returnKeyDownQ = True ],
                Appearance   -> "Suppressed",
                BoxID        -> "SidebarChatInputCellSendButton",
                FrameMargins -> 0,
                Method       -> "Preemptive"
            ],
        True ->
            Button[
                blueHueButtonAppearance[ chatbookIcon[ "StopChatButton", False, 21 ], { 24.5, 24.5 } ],
                Needs[ "Wolfram`Chatbook`" -> None ];
                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ],
                Appearance   -> "Suppressed",
                FrameMargins -> 0
            ]
    },
    Dynamic[ Wolfram`Chatbook`$ChatEvaluationCell === chatEvalCell ],
    Alignment        -> { Automatic, Baseline },
    BaselinePosition -> Baseline
];

sidebarChatInputCellSendButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSidebarChatInputCell*)

makeSidebarChatInputCell // beginDefinition;

makeSidebarChatInputCell[ nbo_NotebookObject, sidebarCell_CellObject ] := Cell[
    BoxData @ ToBoxes @ DynamicModule[
        {
            thisCell, chatEvalCell,
            fieldContent = "", returnKeyDownQ, input,
            kernelWasQuitQ = False, cachedSessionID = $SessionID,
            focusArea = "", (* initialization is synchronous, else we could use a progress indicator here *)
            scrollPosition
        },
        EventHandler[
            EventHandler[
                Pane[
                    Grid[
                        {
                            {
                                DynamicWrapper[
                                    Framed[
                                        Grid[
                                            { {
                                                Pane[
                                                    sidebarChatInputField[ Dynamic @ fieldContent ],
                                                    AppearanceElements -> { },
                                                    ImageSize          -> { Scaled[ 1 ], UpTo[ 100 ] },
                                                    Scrollbars         -> { False, Automatic },
                                                    ScrollPosition     -> Dynamic @ scrollPosition
                                                ],
                                                sidebarChatInputCellSendButton[ fieldContent, input, returnKeyDownQ, chatEvalCell ]
                                            } }, Alignment -> { Left, Center }
                                        ],
                                        $inputFieldFrameOptions
                                    ]
                                    ,
                                    If[ TrueQ @ returnKeyDownQ,
                                        clearOverlayMenus @ nbo;
                                        returnKeyDownQ = False;
                                        Needs[ "Wolfram`Chatbook`" -> None ];
                                        If[ kernelWasQuitQ,
                                            If[ Not @ TrueQ @ $workspaceChatInitialized, initializeWorkspaceChat[ ] ];
                                            kernelWasQuitQ = False ];
                                        evaluateSidebarChat[ nbo, sidebarCell, input, Dynamic @ chatEvalCell ]
                                    ];
                                    (* spooky action at a distance: regenerating a side bar ChatOutput cell *)
                                    If[ cellTaggedQ[ thisCell, "RegenerateChatOutput" ],
                                        chatEvalCell = CurrentValue[ sidebarCell, { TaggingRules, "ChatEvaluationCell" } ]; (* get the CellObject stored in the TaggingRules *)
                                        FrontEndExecute[ {
                                            FrontEnd`SetOptions[ thisCell, CellTags -> "SidebarChatInputCell" ],
                                            FrontEnd`SetValue @ FEPrivate`Set[ FrontEnd`CurrentValue[ sidebarCell, { TaggingRules, "ChatEvaluationCell" } ], Inherited ]
                                        } ];
                                        If[ Head @ chatEvalCell === CellObject, ChatCellEvaluate[ chatEvalCell, nbo ] ]
                                    ]
                                    ,
                                    SynchronousUpdating -> False,
                                    TrackedSymbols      :> { returnKeyDownQ } (* changes to TaggingRules are automatically tracked *)
                                ]
                            },
                            {
                                Item[ Dynamic @ focusArea, Alignment -> Left ],
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
                        ]),
                    { "MenuCommand", "HandleShiftReturn" } :> (NotebookWrite[ InputNotebook[ ], "\n" ]; scrollPosition = { 0, Scaled[ 1 ] })
                },
                Method         -> "Preemptive",
                PassEventsDown -> False
            ],
            {
                "MouseDown" :> (FE`Evaluate @ FEPrivate`SnapshotMainNotebookSelection @ nbo)
            },
            Method         -> "Preemptive",
            PassEventsDown -> True
        ],
        (* 15.0: the side bar is a Row of cells: docked cells, scrollable pane cell, footer cell (ChatInput) *)
        Initialization :> (
            thisCell = EvaluationCell[ ];
            kernelWasQuitQ = cachedSessionID =!= $SessionID;
            cachedSessionID = $SessionID;
            focusArea = focusedNotebookDisplay[ nbo, sidebarCell ]
        )
    ],
    "ChatInputField",
    Background    -> $inputFieldOuterBackground,
    CellTags      -> "SidebarChatInputCell",
    Magnification -> Dynamic[ 0.85*AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ] ]
];

makeSidebarChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sidebarChatInputField*)
sidebarChatInputField // beginDefinition;

sidebarChatInputField[ Dynamic[ fieldContent_ ] ] :=
Overlay[
    {
        InputField[
            Dynamic @ fieldContent,
            Boxes,
            Alignment  -> { Automatic, Baseline },
            Appearance -> "Frameless",
            BaseStyle  -> { "Text", "TextStyleInputField", FontColor -> LightDarkSwitched @ GrayLevel[ 0.2 ], FontSize  -> 13 },
            BoxID      -> "AttachedChatInputField",
            ContinuousAction -> True,
            ImageSize  -> { Scaled[ 1 ], Automatic }
        ],
        With[ { fieldHintBoxes =
            ToBoxes @ Grid[ {
                {
                    chatbookIcon[ "ChatIconGeneric", False, LightDarkSwitched @ RGBColor["#E0F2FC"], LightDarkSwitched @ RGBColor["#128ED1"], 14 ],
                    Style[ tr[ "ChatbarFieldHint" ],
                        "Text", "TextStyleInputField",
                        FontColor       -> LightDarkSwitched @ GrayLevel[ 0.74902 ],
                        FontSize        -> 13,
                        LineBreakWithin -> False
                    ]
                } }, Alignment -> { Left, Center }, BaselinePosition -> { 1, 2 }, Spacings -> { 10, 0 }
            ] },
            Dynamic @ RawBoxes @ If[ fieldContent === "", fieldHintBoxes, "" ]
        ]
    },
    { 1, 2 },
    1,
    Alignment -> { Left, Baseline }
]

sidebarChatInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chatbar*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Chatbar UI elements*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarInputField*)
chatbarInputField // beginDefinition;

(* FieldHint implemented as an Overlay such that it can appear while the text caret is present in an empty field *)
chatbarInputField[ Dynamic[ fieldContent_ ], Dynamic[ mouseOverQ_ ], Dynamic[ selectionWithinQ_ ], size_ ] :=
Overlay[
    {
        InputField[
            Dynamic @ fieldContent,
            Boxes,
            Alignment        -> { Automatic, Baseline },
            Appearance       -> "Frameless",
            BaselinePosition -> Baseline,
            BaseStyle        -> { "Text", "TextStyleInputField", FontColor -> LightDarkSwitched @ GrayLevel[ 0.2 ], FontSize -> 15, FontSlant -> "Plain" },
            BoxID            -> "AttachedChatInputField",
            ContinuousAction -> True,
            ImageSize        -> size,
            TrapEnterKey     -> False (* needed for shift+enter support for addint new lines *)
        ],
        With[ { fieldHintBoxes =
            ToBoxes @ Row[
                {
                    PaneSelector[
                        {
                            True  -> chatbookIcon[ "ChatbarChatBubbleIcon", False,
                                LightDarkSwitched[ RGBColor["#E0F2FC"], RGBColor["#344858"] ],
                                LightDarkSwitched[ RGBColor["#128ED1"], RGBColor["#7FC7FB"] ]
                            ],
                            False -> chatbookIcon[ "ChatbarChatBubbleIcon", False,
                                LightDarkSwitched[ RGBColor["#F9F9F9"], RGBColor["#333333"] ],
                                LightDarkSwitched[ RGBColor["#898989"], RGBColor["#A6A6A6"] ]
                            ]
                        },
                        Dynamic[ selectionWithinQ || mouseOverQ ],
                        BaselinePosition -> Baseline,
                        ImageMargins -> { { 0, 6 }, { 0, 0 } },
                        ImageSize        -> All
                    ],
                    Style[ tr[ "ChatbarFieldHint" ],
                        "Text", "TextStyleInputField",
                        FontColor       -> LightDarkSwitched @ RGBColor["#898989"],
                        FontSize        -> 15,
                        FontSlant       -> "Plain",
                        LineBreakWithin -> False
                    ]
                },
                StripOnInput -> True
            ] },
            RawBoxes @ DynamicBox @ If[ selectionWithinQ || fieldContent =!= "", "", fieldHintBoxes ]
        ]
    },
    { 1, 2 },
    1,
    Alignment        -> { Left, Baseline },
    BaselinePosition -> Baseline
]

chatbarInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarSendButton*)
chatbarSendButton // beginDefinition;

Attributes[ chatbarSendButton ] = { HoldRest };

chatbarSendButton[ nbo_NotebookObject, fieldContent_, selectionWithinQ_ ] :=
Button[
    PaneSelector[
        {
            True  -> blueHueButtonAppearance[ chatbookIcon[ "ChatbarSendIcon", False, color @ "NA_BlueHueButtonIcon" ], { 24, 24 } ],
            False -> blueHueButtonAppearance[ chatbookIcon[ "ChatbarSendIcon", False, color @ "NA_BlueHueButtonIconInactive" ], { 24, 24 } ]
        },
        Dynamic @ selectionWithinQ,
        ImageSize -> Automatic
    ],
    If[ ! validInputStringQ @ fieldContent,
        fieldContent = ""
        ,
        With[ { input = fieldContent }, fieldContent = ""; chatbarWriteAndEvaluateChatInputCell[ nbo, None, False, input ] ]
    ],
    Appearance   -> "Suppressed",
    BoxID        -> "SidebarChatInputCellSendButton",
    FrameMargins -> 0,
    Method       -> "Preemptive"
]

chatbarSendButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarMinimizeButton*)
chatbarMinimizeButton // beginDefinition;

Attributes[ chatbarMinimizeButton ] = { HoldAll };

chatbarMinimizeButton[ minimizedQ_ ] :=
Button[
    blueHueButtonAppearance[
        {
            chatbookIcon[ "HideChatbarIcon", False, color @ "NA_BlueHueButtonIconInactive" ],
            chatbookIcon[ "HideChatbarIcon", False, color @ "NA_BlueHueButtonIcon" ],
            chatbookIcon[ "HideChatbarIcon", False, color @ "NA_BlueHueButtonIcon" ]
        },
        { 15, 15 }
    ],
    minimizedQ = True,
    Appearance   -> "Suppressed",
    ImageMargins -> { { 1, 0 }, { 1, 0 } },
    ImageSize    -> Automatic
]

chatbarMinimizeButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuTick*)
menuTick[ Dynamic[ val_ ], text_ ] :=
Row[
    {
        Style[
            Graphics[
                Line[ { { -0.4, 0.5 }, { 0, 0 }, { 0.8, 1 } } ],
                AspectRatio      -> Automatic,
                BaselinePosition -> (Center -> Center),
                BaseStyle        -> { AbsoluteThickness[ 1.5 ], LightDarkSwitched[ GrayLevel[ 0.35 ], GrayLevel[ 0.892 ] ], JoinForm[ "Round" ], CapForm[ "Round" ] },
                ImagePadding     -> { { 2, 2 }, { 2, 2 } },
                ImageSize        -> { 14, 14 }
            ],
            ShowContents -> Dynamic @ val
        ],
        Spacer[ 3 ],
        text
    },
    StripOnInput -> True
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarOptionsMenu*)
chatbarOptionsMenu // beginDefinition;

chatbarOptionsMenu[ nbo_NotebookObject, Dynamic[ minimizedQ_ ] ] :=
ActionMenu[
    blueHueButtonAppearance[
        {
            chatbookIcon[ "ChatbarSettingsIcon", False, color @ "NA_BlueHueButtonIconInactive" ],
            chatbookIcon[ "ChatbarSettingsIcon", False, color @ "NA_BlueHueButtonIcon" ],
            chatbookIcon[ "ChatbarSettingsIcon", False, color @ "NA_BlueHueButtonIcon" ]
        },
        { 15, 15 }
    ],
    {
        menuTick[
            Dynamic @ AbsoluteCurrentValue[ nbo, "ShowChatbar" ],
            "[[Show Chatbar in this Notebook]]"
        ] :> (
            CurrentValue[ nbo, "ShowChatbar" ] = !AbsoluteCurrentValue[ nbo, "ShowChatbar" ]),
        Delimiter,
        menuTick[
            Dynamic @ AbsoluteCurrentValue[ $FrontEndSession, "ShowChatbar" ],
            "[[Show Chatbar in All Notebooks by Default]]"
        ] :> (
            CurrentValue[ $FrontEnd, "ShowChatbar" ] = !AbsoluteCurrentValue[ $FrontEndSession, "ShowChatbar" ];
            CurrentValue[ nbo, "ShowChatbar" ] = Inherited),
        menuTick[
            Dynamic @ TrueQ @ AbsoluteCurrentValue[ $FrontEndSession, { PrivateFrontEndOptions, "InterfaceSettings", "NotebookAssistant", "Chatbar", "OpenMinimized" } ],
            "[[Minimize Chatbar in All Notebooks by Default]]"
        ] :> (
            minimizedQ = CurrentValue[ $FrontEnd, { PrivateFrontEndOptions, "InterfaceSettings", "NotebookAssistant", "Chatbar", "OpenMinimized" } ] =
                Not @ TrueQ @ AbsoluteCurrentValue[ $FrontEndSession, { PrivateFrontEndOptions, "InterfaceSettings", "NotebookAssistant", "Chatbar", "OpenMinimized" } ])
    },
    Appearance       -> None,
    DefaultBaseStyle -> {},
    ImageMargins     -> { { 1, 0 }, { 0, 1 } },
    ImageSize        -> Automatic,
    Method           -> "Preemptive"
]

chatbarOptionsMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarMaximizeButton*)
chatbarMaximizeButton // beginDefinition;

Attributes[ chatbarMaximizeButton ] = { HoldAll };

chatbarMaximizeButton[ nbo_, chatbarCell_, minimizedQ_, minimizeOverrideQ_, selectionWithinQ_ ] :=
Button[
    blueHueButtonAppearance @ "ChatbarMinimized"
    ,
    minimizedQ = False;
    minimizeOverrideQ = TrueQ @ FE`Evaluate @ FEPrivate`SidebarExtensionInformation[ nbo, { "NotebookAssistant", "Active" } ];
    With[ { n = nbo, c = chatbarCell },
        FE`Evaluate @ FEPrivate`ExpressionEvaluateQueued @ FrontEnd`MoveCursorToInputField[ n, "AttachedChatInputField", c, c ]
    ],
    Appearance -> "Suppressed",
    ImageSize  -> Automatic
]

chatbarMaximizeButton // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeChatbarChatInputCellContent*)


(* this is a temporary solution that should do the right thing on desktop and cloud
   we are not simply using $CloudConnected because it will attempt to connect you if you are not
   https://jira.wolfram.com/jira/browse/CLOUD-25562 *)
cloudAuthenticatedQ[ ] := ($CloudUserID =!= None)

(* on desktop FE, check if they have credentials stored (what you see in the splash screen)
   note: $Notebooks is True in a cloud kernel! *)
cloudCredentialsQ[ ] /; $Notebooks && !$CloudEvaluation := CurrentValue[ "WolframCloudConnected" ]
(* in a cloud session, check if there is a user ID set *)
cloudCredentialsQ[ ] /; $CloudEvaluation := cloudAuthenticatedQ[ ]
(* we can still check this in a standalone kernel because it will get set by LLMKitDialog *)
cloudCredentialsQ[ ] /; !($Notebooks || $CloudEvaluation) := cloudAuthenticatedQ[ ]


makeChatbarChatInputCellContent // beginDefinition;

makeChatbarChatInputCellContent[ ] := makeChatbarChatInputCellContent[ EvaluationNotebook[ ], "" ]

makeChatbarChatInputCellContent[ nbo_NotebookObject, initialText_:"" ] :=
    Style[ #, Magnification -> Dynamic @
        AbsoluteCurrentValue[ $FrontEndSession, { PrivateFrontEndOptions, "InterfaceSettings", "NotebookAssistant", "Chatbar", "Magnification" } ]
    ]& @
    DynamicModule[ { thisCell, minimizedQ, minimizeOverrideQ = False, mouseOverQ = False, selectionWithinQ = False },
        DynamicWrapper[
            PaneSelector[
                {
                    False ->
                        Grid[
                            { {
                                DynamicModule[ { connectionLevel = "Loading" },
                                    DynamicWrapper[
                                        PaneSelector[
                                            {
                                                "Loading" -> chatbarLoading[ ],
                                                "Enabled" -> chatbarInputFieldEnabled[ { nbo, initialText }, mouseOverQ, selectionWithinQ ],
                                                "SignIn"  -> chatbarSignIn[ selectionWithinQ ]
                                            },
                                            Dynamic @ connectionLevel,
                                            ImageSize -> Automatic
                                        ],
                                        connectionLevel = If[ cloudCredentialsQ[ ], "Enabled", "SignIn" ],
                                        SynchronousUpdating -> False
                                    ]
                                ]
                                ,
                                Framed[
                                    Grid[
                                        {
                                            { chatbarMinimizeButton[ minimizedQ ] },
                                            { chatbarOptionsMenu[ nbo, Dynamic @ minimizedQ ] }
                                        },
                                        Alignment -> { Left, Baseline },
                                        Spacings  -> { 0, 0 }
                                    ],
                                    Background     -> LightDarkSwitched[ GrayLevel[ 1 ], GrayLevel[0.0980392] ],
                                    FrameMargins   -> 0,
                                    FrameStyle     -> None,
                                    ImageMargins   -> { { 2, 0 }, { 0, 0 } },
                                    RoundingRadius -> 1
                                ]
                            } },
                            Spacings  -> { 0, 0 }
                        ],
                    True -> chatbarMaximizeButton[ nbo, thisCell, minimizedQ, minimizeOverrideQ, selectionWithinQ ]
                },
                Dynamic @ minimizedQ,
                (* prevent the chatbar from being right up against the notebook window *)
                FrameMargins -> { { 13, 13 }, { 13, 0 } },
                ImageSize    -> Automatic
            ]
            ,
            FEPrivate`Set[ mouseOverQ, FrontEnd`CurrentValue[ "MouseOver" ] ];
            FEPrivate`Set[ selectionWithinQ, FrontEnd`CurrentValue[ "SelectionWithin" ] ];
            Function[
                If[ And[ Not @ TrueQ @ minimizeOverrideQ, # ], FEPrivate`Set[ minimizedQ, True ] ];
                If[ Not @ #, FEPrivate`Set[ minimizeOverrideQ, False ] ];
            ][ TrueQ @ FEPrivate`SidebarExtensionInformation[ nbo, { "NotebookAssistant", "Active" } ] ]
            ,
            Evaluator -> None
        ],
        Initialization :> (
            thisCell = EvaluationCell[ ];
            FE`Evaluate @ {
                (* auto-instantiate the magnification and minimized state if they don't yet have $FrontEnd values *)
                FrontEnd`CurrentValue[
                    FrontEnd`$FrontEnd,
                    { PrivateFrontEndOptions, "InterfaceSettings", "NotebookAssistant", "Chatbar", "Magnification" },
                    FEPrivate`Switch[ FEPrivate`$SystemID, "MacOSX-ARM64", 1., "MacOSX-x86-64", 1., _, .75 ]
                ],
                FrontEnd`CurrentValue[
                    FrontEnd`$FrontEnd,
                    { PrivateFrontEndOptions, "InterfaceSettings", "NotebookAssistant", "Chatbar", "OpenMinimized" },
                    False
                ],
                FEPrivate`Set[
                    minimizedQ,
                    TrueQ @ FrontEnd`AbsoluteCurrentValue[
                        FrontEnd`$FrontEndSession,
                        { PrivateFrontEndOptions, "InterfaceSettings", "NotebookAssistant", "Chatbar", "OpenMinimized" }
                    ]
                ]
            }
        )
    ];

makeChatbarChatInputCellContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarSignIn*)

chatbarSignIn // beginDefinition;

Attributes[ chatbarSignIn ] = { HoldAll };

chatbarSignIn[ selectionWithinQ_ ] :=
Button[
    Framed[
        Grid[
            { {
                PaneSelector[
                    {
                        True  -> chatbookIcon[ "ChatbarChatBubbleIcon", False,
                            LightDarkSwitched[ RGBColor["#E0F2FC"], RGBColor["#344858"] ],
                            LightDarkSwitched[ RGBColor["#128ED1"], RGBColor["#7FC7FB"] ]
                        ],
                        False -> chatbookIcon[ "ChatbarChatBubbleIcon", False,
                            LightDarkSwitched[ RGBColor["#F9F9F9"], RGBColor["#2E2E2E"] ],
                            LightDarkSwitched[ RGBColor["#898989"], RGBColor["#C1C1C1"] ]
                        ]
                    },
                    Dynamic @ selectionWithinQ,
                    BaselinePosition -> Baseline,
                    ImageSize        -> All
                ],
                Style[
                    "[[Sign in to use assistant chat]]",
                    FontColor -> (
                        Dynamic[
                            If[ selectionWithinQ, #1, #2 ]
                        ]&[ LightDarkSwitched[ RGBColor["#128ED1"], RGBColor["#7FC7FB"] ], LightDarkSwitched[ RGBColor["#333333"], RGBColor["#F5F5F5"] ] ])
                ]
            } },
            BaseStyle -> {
                "Text", "TextStyleInputField", (* second style makes contractions, line wrapping, etc. more text like *)
                FontFamily -> "Roboto",
                FontSize        -> 15,
                FontSlant       -> "Plain",
                LineBreakWithin -> False }
        ],
        Alignment      -> { Automatic, Center },
        Background     -> (
            Dynamic[
                If[ selectionWithinQ, #1, #2 ]
            ]&[ LightDarkSwitched[ RGBColor["#D4F0FF"], RGBColor["#385061"] ], LightDarkSwitched[ RGBColor["#E5E5E5"], RGBColor["#494949"] ] ]),
        FrameMargins   -> { { 12, 1 }, { 1, 1 } },
        FrameStyle     -> None,
        ImageSize      -> { Scaled[ 1 ], 32 },
        RoundingRadius -> 9
    ],
    CloudConnect[ ],
    Appearance -> "Suppressed",
    ImageSize  -> Automatic,
    Method     -> "Queued"
];

chatbarSignIn // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarLoading*)

chatbarLoading // beginDefinition;

chatbarLoading[ ] :=
Button[
    Framed[
        ProgressIndicator[ Appearance -> { "Percolate", LightDarkSwitched[ RGBColor["#898989"], RGBColor["#A6A6A6"] ] } ],
        Alignment      -> { Automatic, Center },
        Background     -> LightDarkSwitched[ RGBColor["#E5E5E5"], RGBColor["#494949"] ],
        FrameMargins   -> { { 12, 1 }, { 1, 1 } },
        FrameStyle     -> None,
        ImageSize      -> { Scaled[ 1 ], 32 },
        RoundingRadius -> 9
    ],
    CloudConnect[ ],
    Appearance -> "Suppressed",
    ImageSize  -> Automatic,
    Method     -> "Queued"
];

chatbarLoading // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarInputFieldEnabled*)

chatbarInputFieldEnabled // beginDefinition;

Attributes[ chatbarInputFieldEnabled ] = { HoldRest };

chatbarInputFieldEnabled[ { nbo_NotebookObject, initialText_ }, mouseOverQ_, selectionWithinQ_ ] :=
RawBoxes @ TagBox[ ToBoxes @ #, "NotebookSelectionSnapshotExclusionZone" ]& @
DynamicModule[ { fieldContent = initialText, scrollPosition },
    EventHandler[(* pre-emptive mouse-down event for selection snapshot, moves selection into field *)
        EventHandler[(* pre-emptive mouse-down event for return key *)
            Framed[
                Grid[
                    { {
                        Pane[
                            chatbarInputField[ Dynamic @ fieldContent, Dynamic @ mouseOverQ, Dynamic @ selectionWithinQ, { Scaled[ 1 ], Automatic } ],
                            AppearanceElements -> { },
                            ImageSize          -> { Scaled[ 1 ], UpTo[ 100 ] },
                            Scrollbars         -> { False, Automatic },
                            ScrollPosition     -> Dynamic @ scrollPosition
                        ],
                        chatbarSendButton[ nbo, fieldContent, mouseOverQ || selectionWithinQ ]
                    } },
                    Alignment        -> { Left, Center },
                    BaselinePosition -> { 1, 1 },
                    Spacings         -> { 0, 0 }
                ],
                Alignment      -> { Automatic, Center },
                Background     -> color @ "NA_ChatInputFieldBackground",
                FrameMargins   -> { { 12, 7 }, { 7, 7 } },
                FrameStyle     -> (
                    Dynamic[
                        If[ mouseOverQ || selectionWithinQ, #1, #2 ]
                    ]&[ LightDarkSwitched[ RGBColor["#75C2EB"], RGBColor["#669CBD"] ], LightDarkSwitched[ RGBColor["#A6A6A6"], RGBColor["#646464"] ] ]),
                RoundingRadius -> 9
            ],
            {
                "ReturnKeyDown" :> If[ ! validInputStringQ @ fieldContent,
                    fieldContent = ""
                    ,
                    With[ { input = fieldContent }, fieldContent = ""; chatbarWriteAndEvaluateChatInputCell[ nbo, None, False, input ] ]
                ],
                { "MenuCommand", "HandleShiftReturn" } :> (NotebookWrite[ InputNotebook[ ], "\n" ]; scrollPosition = { 0, Scaled[ 1 ] })
            },
            Method         -> "Preemptive",
            PassEventsDown -> False
        ],
        {
            "MouseDown" :> (FE`Evaluate @ FEPrivate`SnapshotMainNotebookSelection @ nbo)
        },
        Method         -> "Preemptive",
        PassEventsDown -> True
    ],
    SynchronousInitialization -> False,
    Initialization :> (AttachCell[ EvaluationBox[ ], chatbarInputFieldEnabledTierIndicator[ ], { Left, Top }, Offset[ { -5, 5 }, Automatic ], { Left, Top } ])
];

chatbarInputFieldEnabled // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatbarWriteAndEvaluateChatInputCell*)
chatbarWriteAndEvaluateChatInputCell // beginDefinition;

chatbarWriteAndEvaluateChatInputCell[ nbo_NotebookObject, anchor:_CellObject | None, selectionAtTopQ:True|False, input_ ] := Enclose[
    Module[ { text, uuid, cellExpr, cellObject },

        cellObject = None;
        text = makeBoxesInputMoreTextLike @ input;
        uuid = ConfirmBy[ CreateUUID[ ], StringQ, "UUID" ];

        cellExpr = Cell[ text, "ChatInput", CellTags -> uuid ];

        (* FIXME: could really use selection snapshot... *)
        If[ anchor === None || MatchQ[ anchor, _CellObject ] && FailureQ @ Developer`CellInformation @ anchor,
            SelectionMove[ nbo, If[ selectionAtTopQ, Before, After ], Notebook, AutoScroll -> True ];
            NotebookWrite[ nbo, cellExpr ]
            ,
            NotebookWrite[ NotebookLocationSpecifier[ anchor, "After" ], cellExpr ]
        ];
        cellObject = First[ Cells[ nbo, CellTags -> uuid, CellStyle -> "ChatInput" ], Missing[ "CellNotAvailable" ] ];
        ConfirmMatch[ cellObject, _CellObject, "FooterChatInputCellObject" ];
        setCurrentValue[ cellObject, CellTags, Inherited ];
        
        SelectionMove[ cellObject, All, Cell ];
        FrontEndTokenExecute[ nbo, "EvaluateCells" ]
    ],
    throwInternalFailure
];

chatbarWriteAndEvaluateChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarInputFieldEnabledTierIndicatorFrame*)

chatbarInputFieldEnabledTierIndicatorFrame // beginDefinition;

chatbarInputFieldEnabledTierIndicatorFrame[ text_ ] :=
Framed[
    Style[
        text,
        FontColor      -> LightDarkSwitched @ GrayLevel[ 1 ],
        FontTracking   -> "SemiCondensed",
        FontVariations -> { "CapsType" -> "AllCaps" },
        FontWeight     -> "SemiBold"
    ],
    Background     -> LightDarkSwitched @ RGBColor["#0092D1"],
    ContentPadding -> False,
    FrameMargins   -> { { 6, 6 }, { 3, 3 } },
    FrameStyle     -> LightDarkSwitched @ GrayLevel[ 1 ],
    RoundingRadius -> 7
]

chatbarInputFieldEnabledTierIndicatorFrame // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chatbarInputFieldEnabledTierIndicator*)

chatbarInputFieldEnabledTierIndicator // beginDefinition;

chatbarInputFieldEnabledTierIndicator[ ] :=
PaneSelector[
    {
        "Basic"    -> Graphics[ Background -> None, ImageSize -> { 1, 1 } ],
        "Pro"      -> chatbarInputFieldEnabledTierIndicatorFrame @ "Pro",
        "Research" -> chatbarInputFieldEnabledTierIndicatorFrame @ "Research"
    },
    Dynamic @ $assistantTier,
    ImageSize -> Automatic
]

chatbarInputFieldEnabledTierIndicator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Workspace (windowed) assistant UI elements*)

(* TODO: We'll eventually need to scope this by AppName *)
$WorkspaceChatInput = "";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeWorkspaceChatDockedCell*)
makeWorkspaceChatDockedCell // beginDefinition;

makeWorkspaceChatDockedCell[ ] := With[ { nbo = EvaluationNotebook[ ] },
    Framed[
        DynamicModule[ { },
            Grid[
                { {
                    newChatButton @ nbo,
                    Item[ Spacer[ 0 ], ItemSize -> Fit ],
                    sourcesButton @ nbo,
                    historyButton @ nbo,
                    openAsChatbookButton @ nbo
                } },
                Alignment -> { Automatic, Center },
                Spacings  -> 0.2
            ],
            SynchronousInitialization :> False,
            Initialization :> If[ Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ] === { } || Not @ TrueQ @ $workspaceChatInitialized,
                withLoadingOverlay[ { nbo, None } ] @ (
                    (* create the chat input cell first, then initialize chat *)
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    With[ { chatInputCell = Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                                "AttachWorkspaceChatInput",
                                nbo,
                                If[ Cells[ nbo ] =!= { }, Bottom, Top ]
                            ]
                        },
                        If[ Not @ TrueQ @ $workspaceChatInitialized, initializeWorkspaceChat[ ] ];
                        FrontEnd`MoveCursorToInputField[ nbo, "AttachedChatInputField", chatInputCell, chatInputCell ]
                    ];
                    restoreVerticalScrollbar @ nbo
                )
            ]
        ],
        Background   -> color @ "NA_Toolbar",
        FrameStyle   -> color @ "NA_Toolbar",
        FrameMargins -> { { 2, 4 }, { 0, 1 } },
        ImageMargins -> 0
    ]
];

makeWorkspaceChatDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeWorkspaceChatSubDockedCellExpression*)
makeWorkspaceChatSubDockedCellExpression // beginDefinition;

makeWorkspaceChatSubDockedCellExpression[ content_, bgColor_, tag_String ] := Cell[ BoxData @ ToBoxes @
    Framed[
        content,
        Alignment    -> { Center, Center },
        Background   -> bgColor,
        FrameMargins -> { { 7, 7 }, { 4, 4 } },
        FrameStyle   -> bgColor,
        ImageMargins -> 0,
        ImageSize    -> Scaled[1.]
    ],
    CellFrame          -> 0,
    CellFrameMargins   -> 0,
    CellMargins        -> { { -1, -5 }, { -1, -1 } },
    CellTags           -> tag,
    Magnification      -> Dynamic[ AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ] ]
];

makeWorkspaceChatSubDockedCellExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeWorkspaceChatSourcesDockedCell*)
writeWorkspaceChatSourcesDockedCell // beginDefinition;

writeWorkspaceChatSourcesDockedCell[ nbo_NotebookObject, content_ ] := (
setCurrentValue[ nbo, DockedCells,
    Replace[
        DeleteCases[ AbsoluteCurrentValue[ nbo, DockedCells ], Cell[ ___, CellTags -> "WorkspaceChatSourcesDockedCell", ___ ] ],
        { a:Cell[ ___, "NotebookAssistant`TopStripe", ___ ], b__Cell } :> {
            a,
            makeWorkspaceChatSubDockedCellExpression[
                content,
                color @ "NA_ToolbarTitleBackground",
                "WorkspaceChatSourcesDockedCell"
            ],
            b
        }
    ]
]
);

writeWorkspaceChatSourcesDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeWorkspaceChatTitleDockedCell*)
writeWorkspaceChatTitleDockedCell // beginDefinition;

writeWorkspaceChatTitleDockedCell[ nbo_NotebookObject, WindowTitle ] := (
setCurrentValue[ nbo, DockedCells,
    Replace[
        DeleteCases[ AbsoluteCurrentValue[ nbo, DockedCells ], Cell[ ___, CellTags -> "WorkspaceChatTitleDockedCell", ___ ] ],
        { a:Cell[ ___, "NotebookAssistant`TopStripe", ___ ], b__Cell } :> {
            a,
            makeWorkspaceChatSubDockedCellExpression[
                Style[
                    FE`Evaluate @ FEPrivate`TruncateStringToWidth[
                        CurrentValue[ nbo, { TaggingRules, "ConversationTitle" } ],
                        "WorkspaceChatToolbarTitle",
                        #,
                        Right
                    ]&[ AbsoluteCurrentValue[ nbo, { WindowSize, 1 } ] - 10 ],
                    "WorkspaceChatToolbarTitle"
                ],
                color @ "NA_ToolbarTitleBackground",
                "WorkspaceChatTitleDockedCell"
            ],
            b
        }
    ]
]
);

writeWorkspaceChatTitleDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeWorkspaceChatSubDockedCell*)
removeWorkspaceChatSubDockedCell // beginDefinition;

removeWorkspaceChatSubDockedCell[ nbo_NotebookObject ] := setCurrentValue[ nbo, DockedCells, Inherited ];

removeWorkspaceChatSubDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Workspace toolbar buttons*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historyButton*)
historyButton // beginDefinition;

historyButton[ nbo_NotebookObject ] := Button[
    blueHueButtonAppearance[
        toolbarButtonLabel[ "WorkspaceToolbarIconHistory", "WorkspaceToolbarButtonLabelHistory", "WorkspaceToolbarButtonTooltipHistory" ],
        { Automatic, 24 },
        { { 5, 5 }, { 0, 0 } }
    ],
    toggleOverlayMenu[ nbo, None, "History" ],
    Appearance -> "Suppressed"
];

historyButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sourcesButton*)
sourcesButton // beginDefinition;

sourcesButton[ nbo_NotebookObject ] := Button[
    blueHueButtonAppearance[
        toolbarButtonLabel[ "WorkspaceToolbarIconSources", "WorkspaceToolbarButtonLabelSources", "WorkspaceToolbarButtonTooltipSources" ],
        { Automatic, 24 },
        { { 5, 5 }, { 0, 0 } }
    ],
    toggleOverlayMenu[ nbo, None, "Sources" ],
    Appearance -> "Suppressed"
];

sourcesButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*newChatButton*)
newChatButton // beginDefinition;

newChatButton[ nbo_NotebookObject ] :=
    Button[
        blueHueButtonAppearance[
            toolbarButtonLabel[ "WorkspaceToolbarIconNew", "WorkspaceToolbarButtonLabelNew", "WorkspaceToolbarButtonTooltipNew" ],
            { Automatic, 24 },
            { { 5, 5 }, { 0, 0 } }
        ]
        ,
        clearOverlayMenus @ nbo;
        NotebookDelete @ Cells @ nbo;
        removeWorkspaceChatSubDockedCell @ nbo;
        CurrentChatSettings[ nbo, "ConversationUUID" ] = CreateUUID[ ];
        setCurrentValue[ nbo, { TaggingRules, "ConversationTitle" }, "" ];
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

openAsChatbookButton[ nbo_NotebookObject ] := Button[
    blueHueButtonAppearance[
        toolbarButtonLabel[ "WorkspaceToolbarIconOpenAsChatbook", None, "SidebarToolbarButtonTooltipOpenAsWindowedAssistant" ],
        { 24, 24 }
    ],
    popOutChatNB @ nbo,
    Appearance -> "Suppressed",
    Method     -> "Queued"
];

openAsChatbookButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolbarButtonLabel*)
toolbarButtonLabel // beginDefinition;

toolbarButtonLabel[ iconName_String, label_String, tooltip:_String | None ] :=
If[ tooltip === None, #, Tooltip[ #, tr @ tooltip ] ]& @
Grid[
    { {
        chatbookIcon[ iconName, False, color @ "NA_BlueHueButtonIcon" ],
        tr @ label
    } },
    Alignment        -> { Left, Baseline },
    BaselinePosition -> { 1, 2 },
    BaseStyle        -> "NotebookAssistant`Sidebar`ToolbarButtonLabel",
    Spacings         -> { 0.3, 0 }
]

toolbarButtonLabel[ iconName_String, None, tooltip:_String | None ] :=
If[ tooltip === None, #, Tooltip[ #, tr @ tooltip ] ]& @ chatbookIcon[ iconName, False, color @ "NA_BlueHueButtonIcon" ]

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
(*workspaceInputField*)
workspaceInputField // beginDefinition;

(* FieldHint implemented as an Overlay such that it can appear while the text caret is present in an empty field *)
workspaceInputField[ Dynamic[ cachedChatInput_ ] ] :=
Overlay[
    {
        InputField[
            Dynamic[ $WorkspaceChatInput, Function[ cachedChatInput = $WorkspaceChatInput = # ] ], (* store a local copy of the text in case the kernel was quit *)
            Boxes,
            Alignment        -> { Automatic, Baseline },
            Appearance       -> "Frameless",
            BaselinePosition -> Baseline,
            BaseStyle        -> { "Text", "TextStyleInputField", FontColor -> LightDarkSwitched @ RGBColor["#333333"], FontSize -> 15, FontSlant -> "Plain" },
            BoxID            -> "AttachedChatInputField",
            ContinuousAction -> True,
            ImageSize        -> { Scaled[ 1 ], Automatic }
        ],
        With[ { fieldHintBoxes =
            ToBoxes @ Row[
                {
                    chatbookIcon[ "ChatIconGeneric", False, LightDarkSwitched @ RGBColor["#E0F2FC"], LightDarkSwitched @ RGBColor["#128ED1"], 13 ],
                    Style[ tr[ "ChatbarFieldHint" ],
                        "Text", "TextStyleInputField",
                        FontColor       -> LightDarkSwitched @ RGBColor["#898989"],
                        FontSize        -> 15,
                        FontSlant       -> "Plain",
                        LineBreakWithin -> False
                    ]
                },
                Spacer @ 0,
                StripOnInput -> True
            ] },
            RawBoxes @ DynamicBox @ If[ cachedChatInput === "", fieldHintBoxes, "" ]
        ]
    },
    { 1, 2 },
    1,
    Alignment -> { Left, Baseline }
]

workspaceInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachedWorkspaceChatInputCell*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::DynamicImageSize:: *)
attachedWorkspaceChatInputCell[ location_String ] := Cell[
    BoxData @ ToBoxes @ DynamicModule[ { thisNB, cachedSessionID = $SessionID, cachedChatInput = "", kernelWasQuitQ = False },
        EventHandler[
            Pane[
                Grid[
                    {
                        {
                            Framed[
                                Grid[
                                    { {
                                        workspaceInputField[ Dynamic @ cachedChatInput ],
                                        (* no need to templatize an attached cell as it is ephemeral *)
                                        PaneSelector[
                                            {
                                                None -> Button[
                                                    blueHueButtonAppearance[ chatbookIcon[ "SendChatArrow", False, color @ "NA_BlueHueButtonIcon", 13 ], { 24.5, 24.5 } ],
                                                    Needs[ "Wolfram`Chatbook`" -> None ];
                                                    (* in case kernel was quit and the user hasn't typed something new into the search field, restore it to the cached value *)
                                                    If[ kernelWasQuitQ,
                                                        If[ Not @ TrueQ @ $workspaceChatInitialized, initializeWorkspaceChat[ ] ];
                                                        If[ $WorkspaceChatInput =!= cachedChatInput, $WorkspaceChatInput = cachedChatInput ];
                                                        kernelWasQuitQ = False ];
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
                                                blueHueButtonAppearance[ chatbookIcon[ "StopChatButton", False, 21 ], { 24.5, 24.5 } ],
                                                Needs[ "Wolfram`Chatbook`" -> None ];
                                                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ],
                                                Appearance   -> "Suppressed",
                                                FrameMargins -> 0
                                            ],
                                            Alignment -> { Automatic, Baseline }
                                        ]
                                    } },
                                    Alignment        -> { Left, Baseline },
                                    BaselinePosition -> { 1, 1 },
                                    Spacings         -> { 0, 0 }
                                ],
                                $inputFieldFrameOptions
                            ]
                        },
                        {
                            Item[ Dynamic @ focusedNotebookDisplay[ thisNB, None ], Alignment -> Left ]
                        }
                    },
                    Alignment -> { Left, Baseline },
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
                    (* in case kernel was quit and the user hasn't typed something new into the search field, restore it to the cached value *)
                    If[ kernelWasQuitQ,
                        If[ Not @ TrueQ @ $workspaceChatInitialized, initializeWorkspaceChat[ ] ];
                        If[ $WorkspaceChatInput =!= cachedChatInput, $WorkspaceChatInput = cachedChatInput ];
                        kernelWasQuitQ = False ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "EvaluateWorkspaceChat",
                        thisNB,
                        Dynamic @ $WorkspaceChatInput
                    ]
                )
            },
            Method -> "Queued"
        ],
        Initialization :> (thisNB = EvaluationNotebook[ ]; kernelWasQuitQ = cachedSessionID =!= $SessionID; cachedSessionID = $SessionID)
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

initializeWorkspaceChat[ ] := LogChatTiming[
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
                            DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButton" ][ #1, { 24, 24 }, 12, 18 ] ]&[ RGBColor[ "#a3c9f2" ] ]
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
    attachAssistantMessageButtons[ cell, Or @@ Lookup[ CurrentChatSettings @ cell, { "WorkspaceChat", "SidebarChat" }, False, TrueQ ] ];

attachAssistantMessageButtons[ cell0_CellObject, True ] := Enclose[
    Catch @ Module[ { cell, includeFeedback, attached, sidebarCellQ },

        cell = topParentCell @ cell0;
        If[ ! MatchQ[ cell, _CellObject ], Throw @ Null ];
        sidebarCellQ = cellTaggedQ[ cell, "SidebarTopCell" ];

        (* If chat has been reloaded from history, it no longer has the necessary metadata for feedback: *)
        includeFeedback = StringQ @ CurrentValue[ cell, { TaggingRules, "ChatData" } ];

        (* Remove existing attached cell, if any: *)
        NotebookDelete @ Cells[ cell, AttachedCell -> True, CellStyle -> "ChatOutputTrayButtons" ];

        (* Attach new cell: *)
        attached = AttachCell[
            cell,
            Cell[
                BoxData @ assistantMessageButtons[ includeFeedback, sidebarCellQ ],
                "ChatOutputTrayButtons",
                Magnification -> AbsoluteCurrentValue[ cell, Magnification ]
            ],
            { Left, Bottom },
            (* The side bar's TemplateBox uses ImageMargins, so use Offset to undo those margins *)
            If[ sidebarCellQ, Offset[ { 23, 30 }, Automatic ], Offset[ { 8, 0 }, Automatic ] ],
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

assistantMessageButtons[ includeFeedback_, sidebarCellQ_ ] :=
    ToBoxes @ DynamicModule[ { Typeset`cell },
        Grid[
            { {
                Tooltip[ assistantCopyAsActionMenu[ Dynamic[ Typeset`cell ] ], tr[ "WorkspaceOutputRaftCopyAsTooltip" ] ],
                Button[
                    Tooltip[
                        blueHueButtonAppearance[ chatbookIcon[ "WorkspaceOutputRaftRegenerateIcon", False ], { 24, 24 } ],
                        tr[ "WorkspaceOutputRaftRegenerateTooltip" ]
                    ],
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    If[ Not @ TrueQ @ $workspaceChatInitialized, initializeWorkspaceChat[ ] ]; (* in case kernel was quit *)
                    ChatbookAction[ "RegenerateAssistantMessage", Typeset`cell, sidebarCellQ ],
                    Appearance -> "Suppressed",
                    Method     -> "Queued"
                ],
                Item[ Spacer[ 0 ], ItemSize -> Fit ],
                (* Waiting for sharing functionality to be implemented: *)
                (* Tooltip[ assistantShareAsActionMenu[ Dynamic[ Typeset`cell ] ], tr[ "WorkspaceOutputRaftShareAsTooltip" ] ], *)
                If[ TrueQ @ includeFeedback,
                    Splice @ {
                        Button[
                            Tooltip[
                                blueHueButtonAppearance[ chatbookIcon[ "WorkspaceOutputRaftThumbsUpIcon", False ], { 24, 24 } ],
                                tr[ "WorkspaceOutputRaftFeedbackTooltip" ]
                            ],
                            ChatbookAction[ "SendFeedback", Typeset`cell, True ],
                            Appearance -> "Suppressed",
                            Method     -> "Queued"
                        ],
                        Button[
                            Tooltip[
                                blueHueButtonAppearance[ chatbookIcon[ "WorkspaceOutputRaftThumbsDownIcon", False ], { 24, 24 } ],
                                tr[ "WorkspaceOutputRaftFeedbackTooltip" ]
                            ],
                            ChatbookAction[ "SendFeedback", Typeset`cell, False ],
                            Appearance -> "Suppressed",
                            Method     -> "Queued"
                        ],
                        Spacer[ If[ sidebarCellQ, 40, 27 ] ]
                    },
                    Nothing
                ]
            } },
            Alignment -> { Automatic, Center },
            Spacings -> 0
        ],
        Initialization :> (Typeset`cell = ParentCell @ EvaluationCell[ ])
    ];

assistantMessageButtons // endDefinition;

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
                        chatbookIcon[ "WorkspaceOutputRaftClipboardIcon" , False, color @ "NA_BlueHueButtonIcon" ],
                        Background -> None, RoundingRadius -> 4, FrameMargins -> 0, FrameStyle -> None,
                        Alignment -> { Center, Center }, ImageSize -> { 24, 24 } ],
                "Hover" ->
                    Framed[
                        chatbookIcon[ "WorkspaceOutputRaftClipboardIcon" , False, color @ "NA_BlueHueButtonIcon" ],
                        Background -> color @ "NA_BlueHueButtonBackgroundHover", RoundingRadius -> 4, FrameMargins -> 0, FrameStyle -> color @ "NA_BlueHueButtonFrameHover",
                        Alignment -> { Center, Center }, ImageSize -> { 24, 24 } ],
                "Down" ->
                    Framed[
                        chatbookIcon[ "WorkspaceOutputRaftClipboardIcon" , False, color @ "NA_BlueHueButtonIcon" ],
                        Background -> color @ "NA_BlueHueButtonBackgroundPressed", RoundingRadius -> 4, FrameMargins -> 0, FrameStyle -> color @ "NA_BlueHueButtonFramePressed",
                        Alignment -> { Center, Center }, ImageSize -> { 24, 24 } ] },
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
                        Magnification -> AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ]*If[ cellTaggedQ[ topParentCell @ EvaluationCell[ ], "SidebarTopCell" ], 0.85, 1. ]
                    ],
                    Sequence @@ If[ Last[ MousePosition[ "ViewScaled" ], 0 ] > 0.78, { { Left, Top }, 0, { Left, Bottom } }, { { Left, Bottom }, 0, { Left, Top } } ],
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
            attachOverlayMenu[ nbo, None, name ];
            ,
            restoreVerticalScrollbar @ nbo;
            NotebookDelete @ cell
        ]
    ];

(* Side bar is a single cell UI with a Row of inline cells *)
toggleOverlayMenu[ nbo_NotebookObject, sidebarCell_CellObject, name_String ] := Enclose[
    Module[ { overlayCell, sourcesDockedCell, lastDockedCell },
        overlayCell = First[
            Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedOverlayMenu", CellTags -> name ],
            Missing[ "NotAttached" ]
        ];

        sourcesDockedCell = ConfirmMatch[ Last[ Cells[ sidebarCell, CellTags -> "SidebarSourcesDockedCell" ], Missing[ ] ], _CellObject | _Missing, "SidebarSourcesDockedCell" ];

        If[ MissingQ @ overlayCell,
            If[ name == "Sources",
                lastDockedCell = ConfirmMatch[ Last[ Cells[ sidebarCell, CellTags -> "SidebarDockedCell" ], $Failed ], _CellObject, "SidebarDockedCell" ];
                If[ MissingQ @ sourcesDockedCell,
                    NotebookWrite[
                        NotebookLocationSpecifier[ lastDockedCell, "After" ],
                        Join[
                            Insert[
                                DeleteCases[
                                    makeWorkspaceChatSubDockedCellExpression[
                                        Style[
                                            tr[ "WorkspaceToolbarSourcesSubTitle" ],
                                            FontColor  -> LightDarkSwitched[ RGBColor["#898989"], RGBColor["#898989"] ],
                                            FontFamily -> "Source Sans Pro",
                                            FontSlant  -> Italic
                                        ],
                                        LightDarkSwitched[ RGBColor["#E5E5E5"], RGBColor["#2C2C2C"] ],
                                        "SidebarSourcesDockedCell"
                                    ],
                                    _[ Magnification, _]
                                ],
                                "NotebookAssistant`Sidebar`SubDockedCell",
                                2
                            ],
                            Cell[
                                Deletable            -> True, (* this cell can be replaced so override Deletable -> False inherited from the main sidebar cell *)
                                FontSize             -> 12,
                                Magnification        -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ],
                                ShowStringCharacters -> False
                            ]
                        ]
                    ]
                ];
            ];
            attachOverlayMenu[ nbo, sidebarCell, name ];
            , (* ELSE there's an existing overlay so get rid of it *)
            NotebookDelete @ sourcesDockedCell;
            NotebookDelete @ overlayCell
        ]
    ],
    throwInternalFailure
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
            BoxData @ ToBoxes @ If[ name == "Sources",
                Column[
                    {
                        Framed[
                            Style[
                                tr[ "WorkspaceToolbarSourcesSubTitle" ],
                                FontColor  -> LightDarkSwitched[ RGBColor["#898989"], RGBColor["#898989"] ],
                                FontFamily -> "Source Sans Pro",
                                FontSlant  -> Italic
                            ],
                            Alignment    -> { Center, Center },
                            Background   -> LightDarkSwitched[ RGBColor["#E5E5E5"], RGBColor["#2C2C2C"] ],
                            FrameMargins -> { { 7, 7 }, { 4, 4 } },
                            FrameStyle   -> LightDarkSwitched[ RGBColor["#E5E5E5"], RGBColor["#2C2C2C"] ],
                            ImageMargins -> 0,
                            ImageSize    -> Scaled[ 1. ]
                        ],
                        attachedOverlayMenuFrame[
                            nbo,
                            None,
                            ConfirmMatch[ overlayMenu[ nbo, appContainer, name ], Except[ _overlayMenu ], "OverlayMenu" ],
                            LightDarkSwitched[ RGBColor["#FFFFFF"], RGBColor["#191919"] ]
                        ]
                    },
                    Spacings -> { 0, 0 }
                ],
                attachedOverlayMenuFrame[
                    nbo,
                    None,
                    ConfirmMatch[ overlayMenu[ nbo, appContainer, name ], Except[ _overlayMenu ], "OverlayMenu" ],
                    color @ "NA_ChatInputFieldBackgroundArea"
                ]
            ],
            "AttachedOverlayMenu",
            CellTags -> name,
            Magnification -> Dynamic @ AbsoluteCurrentValue[ nbo, Magnification ]
        ],
        { Left, Top },
        0,
        { Left, Top }
    ],
    throwInternalFailure
];

attachOverlayMenu[ nbo_NotebookObject, sidebarCell_CellObject, name_String ] := Enclose[
    Module[ { anchor },
        NotebookDelete @ Cells[ nbo, CellStyle -> "AttachedOverlayMenu", AttachedCell -> True ];
        anchor = If[ name == "Sources",
            ConfirmMatch[ Last[ Cells[ sidebarCell, CellTags -> "SidebarSourcesDockedCell" ], $Failed ], _CellObject, "AttachOverlayToSourcesDockedCell" ]
            ,
            ConfirmMatch[ Last[ Cells[ sidebarCell, CellTags -> "SidebarDockedCell" ], $Failed ], _CellObject, "AttachOverlayToLastDockedCell" ]
        ];
        AttachCell[
            anchor,
            Cell[
                BoxData @ ToBoxes @ attachedOverlayMenuFrame[
                    nbo,
                    sidebarCell,
                    ConfirmMatch[ overlayMenu[ nbo, sidebarCell, name ], Except[ _overlayMenu ], "OverlayMenu" ],
                    If[ name == "Sources", LightDarkSwitched[ RGBColor["#FFFFFF"], RGBColor["#191919"] ], color @ "NA_ChatInputFieldBackgroundArea" ]
                ],
                "AttachedOverlayMenu",
                CellTags      -> name,
                Magnification -> Dynamic[ 0.85*AbsoluteCurrentValue[ nbo, Magnification ] ]
            ],
            { Left, Bottom },
            0,
            { Left, Top }
        ]
    ],
    throwInternalFailure
];

attachOverlayMenu // endDefinition;


attachedOverlayMenuFrame // beginDefinition;

attachedOverlayMenuFrame[ nbo_NotebookObject, appContainer_, content_, bgColor_ ] := Framed[
    content,
    Alignment    -> { Left, Top },
    Background   -> bgColor,
    FrameMargins -> { { 5, 5 }, { 5, 5 } },
    FrameStyle   -> bgColor,
    If[ MatchQ[ appContainer, _CellObject ],
        ImageSize -> Dynamic[ AbsoluteCurrentValue[ appContainer, "ViewSize" ]/(0.85*AbsoluteCurrentValue[ nbo, Magnification ]) ]
        ,
        ImageSize -> Dynamic @ { Scaled[ 1. ], 1.2*AbsoluteCurrentValue[ nbo, { WindowSize, 2 } ] }
    ]
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
    ProgressIndicator[ Appearance -> { "Necklace", color @ "NA_SidebarToolbarFrame" } ],
    Alignment    -> { Center, Automatic },
    ImageMargins -> { { 0, 0 }, { 0, 50 } },
    ImageSize    -> Scaled[ 1 ]
];

loadingOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*restoreVerticalScrollbar*)
restoreVerticalScrollbar // beginDefinition;
restoreVerticalScrollbar[ nbo_NotebookObject ] := setCurrentValue[ nbo, WindowElements, Inherited ];
restoreVerticalScrollbar // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*hideVerticalScrollbar*)
hideVerticalScrollbar // beginDefinition;

hideVerticalScrollbar[ nbo_NotebookObject ] := setCurrentValue[ nbo, WindowElements, DeleteCases[ AbsoluteCurrentValue[ nbo, WindowElements ], "VerticalScrollBar" ] ];

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
                    Function[ results,
                        If[ results === { },
                            { {
                                Pane[
                                    Style[ tr[ "WorkspaceSourcesNoOpenNotebooks" ], FontFamily -> "Source Sans Pro", FontSlant -> "Italic" ],
                                    Alignment -> { Center, Center }, ImageSize -> { Scaled[ 1 ], 30 } ] } },
                            results ]
                    ] @
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
    DynamicModule[ { searching = False, query = "", overlayCell },
        PaneSelector[
            {
                True  -> historySearchView[ nbo, appContainer, Dynamic @ searching, Dynamic @ query, Dynamic @ overlayCell ],
                False -> historyDefaultView[ nbo, appContainer, Dynamic @ searching ]
            },
            Dynamic @ searching,
            ImageSize -> Automatic
        ],

        Initialization   :> (overlayCell = EvaluationCell[ ]),
        Deinitialization :> (
            If[ MatchQ[ appContainer, _CellObject ],
                FrontEnd`MoveCursorToInputField[ nbo, "AttachedChatInputField", appContainer, appContainer ],
                moveToChatInputField[ nbo, True ]
            ]
        )
    ];

historyOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historySearchView*)
historySearchView // beginDefinition;

historySearchView[ nbo_NotebookObject, appContainer_, Dynamic[ searching_ ], Dynamic[ query_ ], Dynamic[ overlayCell_ ] ] := Enclose[
    Catch @ Module[ { appName, header, view },
        appName = ConfirmBy[ CurrentChatSettings[ If[ appContainer === None, nbo, appContainer ], "AppName" ], StringQ, "AppName" ];

        header = ConfirmMatch[
            makeHistoryHeader @ historySearchField[ nbo, Dynamic @ query, Dynamic @ searching, Dynamic @ overlayCell ],
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
            Background     -> color @ "NA_OverlayMenuBackground",
            RoundingRadius -> 3,
            FrameMargins   -> { { 0, 0 }, { 5, 0 } },
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

historySearchField[ nbo_NotebookObject, Dynamic[ query_ ], Dynamic[ searching_ ], Dynamic[ overlayCell_ ] ] := Grid[
    { {
        Overlay[
            {
                DynamicModule[ { },
                    InputField[
                        Dynamic[ query ],
                        String,
                        BaseStyle        -> "Text",
                        BoxID            -> "ChatHistorySearchField",
                        ContinuousAction -> True,
                        ImageSize        -> { Full, Automatic }
                    ],
                    Initialization            :> FrontEnd`MoveCursorToInputField[ nbo, "ChatHistorySearchField", overlayCell, overlayCell ],
                    SynchronousInitialization -> False
                ],
                Dynamic @ Pane[
                    Style[
                        If[ query === "", tr[ "WorkspaceHistoryFieldHint" ], "" ],
                        "Text", "FieldHintStyle", LineBreakWithin -> False, FontSize -> 15 ],
                    ImageMargins -> { { 14, 0 }, { 0, 0 } } ]
            },
            { 1, 2 },
            1,
            Alignment        -> { Left, Baseline },
            BaselinePosition -> Baseline ],
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

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeDefaultHistoryView*)
makeDefaultHistoryView // beginDefinition;

makeDefaultHistoryView[ nbo_NotebookObject, appContainer_, Dynamic[ page_ ], Dynamic[ totalPages_ ] ] := Enclose[
    RawBoxes @ ToBoxes @ DynamicModule[ { display },
        display = Pane[ ProgressIndicator[ Appearance -> { "Percolate", color @ "NA_OverlayMenuPercolate" } ], ImageMargins -> 25 ];

        Pane[
            Dynamic[ display, TrackedSymbols :> { display } ],
            Alignment          -> { Left, Top },
            AppearanceElements -> { },
            FrameMargins       -> { { 0, 0 }, { 5, 5 } },
            If[ MatchQ[ appContainer, _CellObject ],
                With[ { dc = First[ Cells[ appContainer ] ] },
                    ImageSize ->
                        Dynamic @ {(* run entirely in the front end evaluator *)
                            Scaled[ 1. ],
                            UpTo @ FEPrivate`Round[
                                (FrontEnd`AbsoluteCurrentValue[ "ViewSize" ][[2]]
                                - 40 (* history menu header and frame margins at 100% magnification *)
                                - FrontEnd`AbsoluteCurrentValue[ dc, { CellSize, 2 } ])/(0.85*AbsoluteCurrentValue[ nbo, Magnification ])] }
                ]
                ,
                ImageSize -> Dynamic @ { Scaled[ 1 ], AbsoluteCurrentValue[ nbo, { WindowSize, 2 } ] }
            ],
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
    chatbookIcon[ "WorkspaceHistorySearchIcon", False ],
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
            Alignment        -> { { Left, Right }, Baseline },
            BaselinePosition -> { { 1, 1 }, Baseline },
            BaseStyle        -> { "Text", FontSize -> 14, LineBreakWithin -> False },
            ItemSize         -> Fit
        ];

        hover = Grid[
            { {
                Button[
                    title,
                    loadConversation[ nbo, appContainer, chat ],
                    Alignment        -> Left,
                    Appearance       -> "Suppressed",
                    BaseStyle        -> { "Text", FontSize -> 14, LineBreakWithin -> False },
                    BaselinePosition -> Baseline,
                    Method           -> "Queued"
                ],
                Grid[
                    { {
                        Button[
                            chatbookIcon[ "WorkspaceHistoryPopOutIcon", False ],
                            popOutChatNB[ chat, CurrentChatSettings @ If[ appContainer === None, nbo, appContainer ] ],
                            Appearance       -> "Suppressed",
                            BaselinePosition -> Center -> Center,
                            Method           -> "Queued"
                        ],
                        Button[
                            chatbookIcon[ "WorkspaceHistoryTrashIcon" , False ],
                            DeleteChat @ chat;
                            removeChatFromRows[ Dynamic @ chats, chat ],
                            Appearance       -> "Suppressed",
                            BaselinePosition -> Center -> Center,
                            Method           -> "Queued"
                        ]
                    } },
                    BaselinePosition -> { { 1, 1 }, Baseline }
                ]
            } },
            Alignment        -> { { Left, Right }, Baseline },
            Background       -> color @ "NA_OverlayMenuItemBackgroundHover",
            BaselinePosition -> { { 1, 1 }, Baseline },
            ItemSize         -> Fit
        ];

        {
            Style[ Spacer[ 3 ], TaggingRules -> <| "ConversationUUID" -> chat[ "ConversationUUID" ] |> ],
            Mouseover[ default, hover, BaselinePosition -> Baseline ],
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
            setCurrentValue[ nbo, Selectable, True ],
            SelectionMove[ nbo, Before, Notebook, AutoScroll -> True ];
            ConfirmMatch[ NotebookWrite[ nbo, cells, AutoScroll -> False ], Null, "Write" ];
            If[ Cells @ nbo === { }, NotebookWrite[ nbo, cells, AutoScroll -> False ] ],
            setCurrentValue[ nbo, Selectable, Inherited ]
        ];

        ChatbookAction[ "AttachWorkspaceChatInput", nbo ];
        CurrentChatSettings[ nbo, "ConversationUUID" ] = uuid;
        setCurrentValue[ nbo, { TaggingRules, "ConversationTitle" }, title ];
        writeWorkspaceChatTitleDockedCell[ nbo, WindowTitle ];
        restoreVerticalScrollbar @ nbo;
        moveToChatInputField[ nbo, True ]
    ] // withLoadingOverlay[ { nbo, None } ],
    throwInternalFailure
];

(* if we need to distinguish this further then condition on TrueQ @ CurrentValue[ sidebarCell, { TaggingRules, "ChatNotebookSettings", "SidebarChat" } ] *)
loadConversation[ nbo_NotebookObject, sidebarCell_CellObject, id_ ] := Enclose[
    Module[ { loaded, uuid, title, messages, cells, lastDockedCell, scrollablePaneCell },
        (* load new cells *)
        loaded = ConfirmBy[ LoadChat @ id, AssociationQ, "Loaded" ];
        uuid = ConfirmBy[ loaded[ "ConversationUUID" ], StringQ, "UUID" ];
        title = ConfirmBy[ loaded[ "ConversationTitle" ], StringQ, "Title" ];
        messages = ConfirmBy[ loaded[ "Messages" ], ListQ, "Messages" ];
        cells = ConfirmMatch[ ChatMessageToCell[ messages, "Sidebar" ], { __Cell }, "Cells" ];
        
        (* all old top-cells are within an inline cell that scrolls. Overwrite that cell if it exists, otherwise create it anew *)
        scrollablePaneCell = First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], Missing @ "NoScrollingContent" ];
        If[ MissingQ @ scrollablePaneCell,
            lastDockedCell = ConfirmMatch[ Last[ Cells[ sidebarCell, CellTags -> "SidebarDockedCell" ], $Failed ], _CellObject, "SidebarDockedCell" ];
            NotebookWrite[ NotebookLocationSpecifier[ lastDockedCell, "After" ], makeSidebarChatScrollingCell[ nbo, sidebarCell, cells ] ]
            , (* ELSE *)
            NotebookWrite[ scrollablePaneCell, makeSidebarChatScrollingCell[ nbo, sidebarCell, cells ] ]
        ];
        
        CurrentChatSettings[ sidebarCell, "ConversationUUID" ] = uuid;
        setCurrentValue[ sidebarCell, { TaggingRules, "ConversationTitle" }, title ];
        writeSidebarChatTitleCell[ nbo, sidebarCell, WindowTitle ];
        (* TODO: moveToChatInputField[ nbo, True ] *)
    ] // withLoadingOverlay[ { nbo, sidebarCell } ],
    throwInternalFailure
];

loadConversation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Global Progress Bar*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withSidebarGlobalProgress*)
withSidebarGlobalProgress // beginDefinition;
withSidebarGlobalProgress // Attributes = { HoldRest };

withSidebarGlobalProgress[ nbo_NotebookObject, eval_ ] := Enclose[
    Catch @ Module[ { sidebarCell, topStripeCell },

        sidebarCell = ConfirmMatch[ sidebarCellObject @ nbo, _CellObject, "SidebarCell" ];
        topStripeCell = ConfirmMatch[
            First[ Cells[ sidebarCell, CellStyle -> "NotebookAssistant`TopStripe" ], None ],
            _CellObject,
            "SidebarTopStripeCellObject"
        ];
        
        setCurrentValue[ topStripeCell, { TaggingRules, "ProgressIndicator" }, True ];
        WithCleanup[ eval, setCurrentValue[ topStripeCell, { TaggingRules, "ProgressIndicator" }, False ] ]
    ],
    throwInternalFailure
];

withSidebarGlobalProgress // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withWorkspaceGlobalProgress*)
withWorkspaceGlobalProgress // beginDefinition;
withWorkspaceGlobalProgress // Attributes = { HoldRest };

withWorkspaceGlobalProgress[ nbo_NotebookObject, eval_ ] := Enclose[
    Catch @ Module[ { topStripeCell },

        topStripeCell = ConfirmMatch[
            First[ Cells[ nbo, DockedCell -> True, CellStyle -> "NotebookAssistant`TopStripe" ], None ],
            _CellObject,
            "WorkspaceTopStripeCellObject"
        ];
        setCurrentValue[ topStripeCell, { TaggingRules, "ProgressIndicator" }, True ];
        WithCleanup[ eval, setCurrentValue[ topStripeCell, { TaggingRules, "ProgressIndicator" }, False ] ]
    ],
    throwInternalFailure
];

withWorkspaceGlobalProgress // endDefinition;


(* Work around VertexColors not understanding LightDarkSwitched. *)
$workspaceChatProgressBar := With[
    {
        darkModeQ = AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[], LightDark ] === "Dark"
    },
    {(* (* save for posterity *)
        background  = Replace[ color @ "NA_ProgressBarEdgeColor",   l_LightDarkSwitched :> If[ darkModeQ, Last, First ][l] ],
        colorCenter = Replace[ color @ "NA_ProgressBarCenterColor", l_LightDarkSwitched :> If[ darkModeQ, Last, First ][l] ],
        colorEdges  = Replace[ color @ "NA_ProgressBarEdgeColor",   l_LightDarkSwitched :> If[ darkModeQ, Last, First ][l] ],
        *)
        background  = Replace[ LightDarkSwitched[ RGBColor["#128ED1"], RGBColor["#7FC7FB"] ], l_LightDarkSwitched :> If[ darkModeQ, Last, First ][l] ],
        colorCenter = Replace[ LightDarkSwitched[ RGBColor["#E0F2FC"], RGBColor["#F5F5F5"] ], l_LightDarkSwitched :> If[ darkModeQ, Last, First ][l] ],
        colorEdges  = Replace[ LightDarkSwitched[ RGBColor["#128ED1"], RGBColor["#7FC7FB"] ], l_LightDarkSwitched :> If[ darkModeQ, Last, First ][l] ],
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
        ImageSize        -> { Full, 6 },
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
