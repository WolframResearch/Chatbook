(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"           ];
Needs[ "Wolfram`Chatbook`Common`"    ];
Needs[ "Wolfram`Chatbook`CodeCheck`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*floatingButtonGrid*)
floatingButtonGrid // beginDefinition;

floatingButtonGrid[ cell_Cell, lang_ ] /; $cloudNotebooks :=
    Grid[
        {
            codeBlockButtons[ lang, EvaluationCell[ ], False ]
        },
        Alignment -> Top,
        Spacings  -> 0.2
    ];

floatingButtonGrid[ cell_Cell, lang_ ] :=
    Module[ { cellObj },
        cellObj = topParentCell @ EvaluationCell[ ];
        Grid[
            {
                Which[
                    TrueQ @ currentChatContainerSetting[ cellObj, "WorkspaceChat" ],
                        codeBlockWorkspaceButtons[ lang, EvaluationCell[ ], True ],
                    TrueQ @ currentChatContainerSetting[ cellObj, "SidebarChat" ],
                        codeBlockWorkspaceButtons[ lang, EvaluationCell[ ], "Sidebar" ],
                    True, (* Chatbook *)
                        codeBlockButtons[ lang, EvaluationCell[ ], False ]
                ]
            },
            Alignment -> Top,
            Spacings  -> 0.2
        ]
    ];

(* this is a placeholder during active stream-of-thought *)
floatingButtonGrid[ "Disabled", lang_ ] := buttonFrameDefault @ labeledIcon[ { "WorkspaceCodeBlockCopy", "Disabled" }, "FormattingCopyToClipboardLabel" ]

(* TODO: I'm assuming this still works on the cloud as written *)
(* For cloud notebooks (no attached cell) *)
floatingButtonGrid[ string_, lang_ ] := RawBoxes @ templateBox[
    {
        ToBoxes @ Grid[
            {
                codeBlockButtons[ lang, string, False ]
            },
            Alignment -> Top,
            Spacings  -> 0.2
        ]
    },
    "ChatCodeBlockButtonPanel"
];

floatingButtonGrid // endDefinition;

codeBlockButtons // beginDefinition;

codeBlockButtons[ lang_, target_, workspaceQ_ ] /; plaintextLanguageQ @ lang := {
    button[ $insertInputButtonLabel, insertCodeBelow[ target, False ] ],
    button[ If[ TrueQ @ workspaceQ, $copyToClipboardButtonLabelWorkspaceChat, $copyToClipboardButtonLabel ], copyCodeBlock @ target ]
};

codeBlockButtons[ lang_, target_, workspaceQ_ ] := {
    button[ evaluateLanguageLabel[ lang, workspaceQ ], insertCodeBelow[ target, True ] ],
    button[ $insertInputButtonLabel, insertCodeBelow[ target, False ] ],
    button[ If[ TrueQ @ workspaceQ, $copyToClipboardButtonLabelWorkspaceChat, $copyToClipboardButtonLabel ], copyCodeBlock @ target ]
};

codeBlockButtons // endDefinition;

codeBlockWorkspaceButtons // beginDefinition;

codeBlockWorkspaceButtons[ lang_, target_, _ ] /; plaintextLanguageQ @ lang := {
    button[ $copyToClipboardButtonLabelWorkspaceChat, copyCodeBlock @ target ]
};

codeBlockWorkspaceButtons[ lang_, target_, evaluate_ ] := {
    button[ $copyToClipboardButtonLabelWorkspaceChat, copyCodeBlock @ target ],
    button[ evaluateLanguageLabel[ lang, True ], insertCodeBelow[ target, evaluate ] ]
};

codeBlockWorkspaceButtons // endDefinition;

plaintextLanguageQ // beginDefinition;
plaintextLanguageQ[ language_String ] := MemberQ[ { "text", "plaintext" }, ToLowerCase @ language ];
plaintextLanguageQ[ ___ ] := False;
plaintextLanguageQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluateLanguageLabel*)
evaluateLanguageLabel[ name_String, False ] :=
    With[ { icon = $languageIcons @ name },
        fancyTooltip[
            MouseAppearance[
                buttonMouseover[
                    buttonFrameDefault[ buttonPane @ icon, False ],
                    buttonFrameHover[   buttonPane @ icon, False ],
                    buttonFramePressed[ buttonPane @ icon, False ]
                ],
                "LinkHand"
            ],
            tr[ "FormattingInsertContentAndEvaluateTooltip" ]
        ] /; MatchQ[ icon, _Graphics | _Image | _Dynamic ]
    ];

evaluateLanguageLabel[ name_String, True ] :=
    Catch @ Module[ { wl, icon, labeled },

        wl = wolframLanguageQ @ name;
        icon = If[ wl, chatbookExpression[ "WorkspaceCodeBlockInsertAndEvaluate" ], $languageIcons @ name ];
        If[ ! MatchQ[ icon, _Graphics | _Dynamic | _Image | _RawBoxes ], Throw @ $insertEvaluateButtonLabel ];
        labeled = labeledIcon[ icon, "FormattingInsertContentAndEvaluateLabel" ];

        fancyTooltip[
            MouseAppearance[
                buttonMouseover[
                    buttonFrameDefault[ labeled, True ],
                    buttonFrameHover[   labeled, True ],
                    buttonFramePressed[ labeled, True ]
                ],
                "LinkHand"
            ],
            (* In the assistant window, finding the target notebook can scan all open notebooks (the sidebar uses its
               own notebook), so wait until the tooltip is shown. Only front end values are tracked: the lookup reads
               Chatbook symbols that change on every catchTop call, which would otherwise rescan the notebooks while
               the tooltip is open, e.g. twice a second while a response streams. *)
            With[ { nbo = EvaluationNotebook[ ] }, Dynamic[ targetNotebookLabel @ nbo, TrackedSymbols :> { } ] ]
        ]
    ];

evaluateLanguageLabel[ ___ ] := $insertEvaluateButtonLabel;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*targetNotebookLabel*)
targetNotebookLabel // beginDefinition;

targetNotebookLabel[ nbo_NotebookObject ] :=
    targetNotebookLabel[ nbo, GetFocusedNotebook @ nbo ];

targetNotebookLabel[ nbo_, None ] :=
    tr[ "FormattingInsertContentAndEvaluateWorkspaceChatTooltipNew" ];

targetNotebookLabel[ nbo_, focused_NotebookObject ] :=
    targetNotebookLabel[ nbo, focused, AbsoluteCurrentValue[ focused, WindowTitle ] ];

targetNotebookLabel[ nbo_, focused_NotebookObject, title_ ] :=
    Row @ Flatten @ {
        trExprTemplate[ "FormattingInsertContentAndEvaluateWorkspaceChatTooltip" ][ <|
            "1" -> {
                chatbookExpression[ "WorkspaceFocusIndicatorNotebook" ],
                "\[ThinSpace]",
                Style[ formatNotebookTitle @ title, FontWeight -> Bold ]
            }
        |> ]
    };

targetNotebookLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Buttons*)
(* FIXME: move this stuff to the stylesheet *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Labels*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$copyToClipboardButtonLabel*)
$copyToClipboardButtonLabel := $copyToClipboardButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ "AssistantCopyClipboard", "FormattingCopyToClipboardLabel" ],
            buttonFrameHover   @ labeledIcon[ "AssistantCopyClipboard", "FormattingCopyToClipboardLabel" ],
            buttonFramePressed @ labeledIcon[ "AssistantCopyClipboard", "FormattingCopyToClipboardLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingCopyToClipboardTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$copyToClipboardButtonLabelWorkspaceChat*)
$copyToClipboardButtonLabelWorkspaceChat := $copyToClipboardButtonLabelWorkspaceChat = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ { "WorkspaceCodeBlockCopy", False }, "FormattingCopyToClipboardLabel" ],
            buttonFrameHover   @ labeledIcon[ { "WorkspaceCodeBlockCopy", False }, "FormattingCopyToClipboardLabel" ],
            buttonFramePressed @ labeledIcon[ { "WorkspaceCodeBlockCopy", False }, "FormattingCopyToClipboardLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingCopyToClipboardTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$insertInputButtonLabel*)
$insertInputButtonLabel := $insertInputButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ "AssistantCopyBelow", "FormattingInsertContentLabel" ],
            buttonFrameHover   @ labeledIcon[ "AssistantCopyBelow", "FormattingInsertContentLabel" ],
            buttonFramePressed @ labeledIcon[ "AssistantCopyBelow", "FormattingInsertContentLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingInsertContentTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$insertInputButtonLabelWorkspaceChat*)
$insertInputButtonLabelWorkspaceChat := $insertInputButtonLabelWorkspaceChat = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ "AssistantCopyRight", "FormattingInsertContentLabel" ],
            buttonFrameHover   @ labeledIcon[ "AssistantCopyRight", "FormattingInsertContentLabel" ],
            buttonFramePressed @ labeledIcon[ "AssistantCopyRight", "FormattingInsertContentLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingInsertContentTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$insertEvaluateButtonLabel*)
$insertEvaluateButtonLabel := $insertEvaluateButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ "AssistantEvaluate", "FormattingInsertContentAndEvaluateLabel" ],
            buttonFrameHover   @ labeledIcon[ "AssistantEvaluate", "FormattingInsertContentAndEvaluateLabel" ],
            buttonFramePressed @ labeledIcon[ "AssistantEvaluate", "FormattingInsertContentAndEvaluateLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingInsertContentAndEvaluateTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertCodeBelow*)
insertCodeBelow // beginDefinition;

insertCodeBelow[ code_ ] := insertCodeBelow[ code, False ];

insertCodeBelow[ cell_CellObject, "Sidebar" ] := insertCodeInUserNotebook[ parentNotebook @ cell, getCodeBlockContent @ cell, "Sidebar" ]

insertCodeBelow[ cell_CellObject, evaluate_ ] :=
    If[ TrueQ @ CurrentChatSettings[ cell, "WorkspaceChat" ] || TrueQ @ CurrentChatSettings[ cell, "SidebarChat" ],
        insertCodeInUserNotebook[ parentNotebook @ cell, getCodeBlockContent @ cell, evaluate ],
        insertCodeBelow[ getCodeBlockContent @ cell, evaluate ]
    ];

insertCodeBelow[ cell_Cell, evaluate_ ] :=
    Module[ { cellObj, nbo },
        cellObj = topParentCell @ EvaluationCell[ ];
        nbo = parentNotebook @ cellObj;
        If[ TrueQ @ CurrentChatSettings[ cellObj, "WorkspaceChat" ] || TrueQ @ CurrentChatSettings[ cellObj, "SidebarChat" ],
            insertCodeInUserNotebook[ nbo, getCodeBlockContent @ cell, evaluate ]
            ,
            insertAfterChatGeneratedCells[ cellObj, getCodeBlockContent @ cell ];
            If[ TrueQ @ evaluate,
                selectionEvaluateCreateCell @ nbo,
                SelectionMove[ nbo, After, CellContents ]
            ]
        ]
    ];

insertCodeBelow[ string_String, evaluate_ ] :=
    insertCodeBelow[ reparseCodeBoxes @ Cell[ BoxData @ string, "Input" ], evaluate ];

insertCodeBelow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertCodeInUserNotebook*)
insertCodeInUserNotebook // beginDefinition;

insertCodeInUserNotebook[ chatNB_NotebookObject, cell_Cell, "Sidebar" ] := Enclose[
    Module[ { currentSelections, activeSelection, remnantSelection, newCellPosition },

        (* determine the current selections *)
        currentSelections = Replace[ FE`Evaluate @ FEPrivate`GetCurrentSelections @ chatNB, Except[ _Association ] -> <| |> ];
        activeSelection = Lookup[ currentSelections, "ActiveSelection", None ];
        remnantSelection = Lookup[ currentSelections, "RemnantSelection", None ];

        (* pre-write: move the selection as needed *)
        (* If there is a remnant selection in the main content area, then make it the active selection *)
        If[ remnantSelection =!= None,
            With[ { s = remnantSelection }, FE`Evaluate @ FEPrivate`SetCurrentSelections @ <| "ActiveSelection" -> s |> ]
        ];
        (* If there is no selection in the notebook, then move the selection to the bottom *)
        If[ CurrentValue[ chatNB, "SelectionType" ] === None,
            SelectionMove[ chatNB, After, Notebook ]
        ];
        (* If there is at least one cell selected, then move the selection after the last selected cell *)
        With[ { sel = SelectedCells[ chatNB ] },
            If[ MatchQ[ sel, { __ } ],
                SelectionMove[ Last @ sel, After, Cell ]
            ]
        ];

        (* write the cell: utilize "AfterEvaluationGroup" to not break up Input/Output cells *)
        newCellPosition = PreviousCell @ NotebookSelection @ chatNB;
        If[ newCellPosition === None, (* at top of notebook, but may be within the first cell *)
            With[ { cellWithin = First[ SelectedCells[ chatNB ], None ] },
                If[ cellWithin === None,
                    NotebookWrite[ chatNB, cell, All ]
                    ,
                    NotebookWrite[ NotebookLocationSpecifier[ cellWithin, "AfterEvaluationGroup" ], cell, All ]
                ]
            ]
            ,
            NotebookWrite[ NotebookLocationSpecifier[ newCellPosition, "AfterEvaluationGroup" ], cell, All ]
        ];
        With[ { s = remnantSelection }, FE`Evaluate @ FEPrivate`SetCurrentSelections @ <| "RemnantSelection" -> s |> ];
        With[ { s = currentSelections }, FE`Evaluate @ FEPrivate`ReleaseSelectionObjects @ s ];

        selectionEvaluateCreateCell @ chatNB
    ],
    throwInternalFailure
];

insertCodeInUserNotebook[ chatNB_NotebookObject, cell_Cell, evaluate_ ] := Enclose[
    Module[ { nbo, cellObj },
        nbo = ConfirmMatch[ getNotebookForCodeInsertion @ chatNB, _NotebookObject, "UserNotebook" ];
        cellObj = ConfirmMatch[ getLastSelectedCell @ nbo, _CellObject|None, "SelectedCell" ];

        If[ cellObj === None
            ,
            SelectionMove[ nbo, After, Cell, AutoScroll -> True ];
            NotebookWrite[ nbo, preprocessInsertedCell @ cell, All ]
            ,
            insertAfterChatGeneratedCells[ cellObj, cell ]
        ];

        SetSelectedNotebook @ nbo;

        If[ TrueQ @ evaluate,
            selectionEvaluateCreateCell @ nbo,
            SelectionMove[ nbo, After, CellContents ]
        ]
    ],
    throwInternalFailure
];

insertCodeInUserNotebook[ chatNB_NotebookObject, code_String, evaluate_ ] :=
    insertCodeInUserNotebook[ chatNB, reparseCodeBoxes @ Cell[ BoxData @ code, "Input" ], evaluate ];

insertCodeInUserNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachCopiedTooltip*)
attachCopiedTooltip // beginDefinition;

attachCopiedTooltip[ ] :=
    AttachCell[
        EvaluationBox[ ],
        Cell[ BoxData[
            PaneBox[
                PanelBox[
                 GridBox[{{PaneBox[
                     DynamicBox[
                      StyleBox[
                       FEPrivate`ImportImage[
                        FrontEnd`FileName[{"Typeset", "ClickToCopy"}, "Checkmark.png"]],
                        Magnification -> 0.5`]],
                     BaselinePosition -> Scaled[0.1`] -> Baseline],
                    DynamicBox[
                     ToBoxes[FEPrivate`FrontEndResource["FEStrings",
                       "clicktocopyDoneTooltip"], StandardForm]]}},
                  GridBoxAlignment -> {"Columns" -> {{Left}}, "Rows" -> {{Baseline}}},
                   GridBoxItemSize -> {"Columns" -> {{Automatic}},
                    "Rows" -> {{Automatic}}},
                  GridBoxSpacings -> {"Columns" -> {{0.3`}}, "Rows" -> {{0}}}],
                 Alignment -> Center,
                 Appearance -> {"Default" ->
                    FrontEnd`FileName[{"Chatbook"}, "CopyTooltip.9.png"]}, ImageSize -> {100, Automatic},
                 FrameMargins -> {{0, 0}, {0, 0}},
                 BaseStyle -> {LineBreakWithin -> Automatic,
                   LinebreakAdjustments -> {1.`, 10, 1, 0, 1}, LineIndent -> 0,
                   Hyphenation -> False,
                   HyphenationOptions -> {"HyphenationCharacter" -> "\[Null]"},
                   FontFamily -> "Source Sans Pro", FontSize -> 12,
                   FontColor -> color @ "NA_ChatCodeBlockTemplateCopiedButtonFont"}],
                Alignment    -> { Center, Bottom },
                FrameMargins -> 0,
                ImageSize    -> { All, 60 }
            ]
        ] ],
        { Center, Bottom }, Offset[ { 0, -7 }, Automatic ], { Center, Center },
        RemovalConditions -> { "MouseExit" }
    ];

attachCopiedTooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*copyCodeBlock*)
copyCodeBlock // beginDefinition;
copyCodeBlock[ cell_CellObject ] := copyCodeBlock @ getCodeBlockContent @ cell;
copyCodeBlock[ code_String ] := (CopyToClipboard @ code; attachCopiedTooltip[ ]);
copyCodeBlock[ Cell[ BoxData[ cell_Cell, ___ ] ] ] := copyCodeBlock @ cell;
copyCodeBlock[ Cell[ code_String, ___ ] ] := copyCodeBlock @ code;
copyCodeBlock[ cell_Cell ] := (CopyToClipboard @ cell; attachCopiedTooltip[ ]);
copyCodeBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNotebookForCodeInsertion*)
getNotebookForCodeInsertion // beginDefinition;
getNotebookForCodeInsertion[ chatNB_NotebookObject ] := getNotebookForCodeInsertion[ chatNB, GetFocusedNotebook @ chatNB ];
getNotebookForCodeInsertion[ _, userNB_NotebookObject ] := userNB;
getNotebookForCodeInsertion[ _, None ] := CreateNotebook[ ];
getNotebookForCodeInsertion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getLastSelectedCell*)
getLastSelectedCell // beginDefinition;
getLastSelectedCell[ nbo_NotebookObject ] := getLastSelectedCell @ SelectedCells @ nbo;
getLastSelectedCell[ { ___, cell_CellObject } ] := cell;
getLastSelectedCell[ _ ] := None;
getLastSelectedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertAfterChatGeneratedCells*)
insertAfterChatGeneratedCells // beginDefinition;

(* FIXME: outputs do not inherit the "ChatGeneratedCell" tag from inputs in cloud notebooks, so this is a workaround *)
insertAfterChatGeneratedCells[ cellObj_CellObject, cell_Cell ] /; $cloudNotebooks := Enclose[
    Module[ { nbo },
        nbo = ConfirmMatch[ parentNotebook @ cellObj, _NotebookObject, "ParentNotebook" ];
        SelectionMove[ cellObj, After, CellContents ];
        SelectionMove[ nbo, All, Cell ];
        (* If the selection is in the next chat input cell, create cell immediately before so the next chat input
           stays at the bottom *)
        If[ MatchQ[ NotebookRead @ nbo, Cell[ _, "ChatInput", ___ ] ],
            SelectionMove[ nbo, Before, Cell ],
            SelectionMove[ nbo, After, Cell ]
        ];
        NotebookWrite[ nbo, preprocessInsertedCell @ cell, All ];
    ],
    throwInternalFailure
];

insertAfterChatGeneratedCells[ cellObj_CellObject, cell_Cell ] := Enclose[
    Module[ { nbo, allCells, cellsAfter, taggedQ, tagged, generated, skip, skipped, insertionPoint },

        nbo        = ConfirmMatch[ parentNotebook @ cellObj, _NotebookObject, "ParentNotebook" ];
        allCells   = ConfirmMatch[ Cells @ nbo, { __CellObject }, "AllCells" ];
        cellsAfter = Replace[ allCells, { { ___, cellObj, after___ } :> { after }, _ :> { } } ];
        taggedQ    = MemberQ[ Flatten @ List @ #, $chatGeneratedCellTag ] &;

        tagged = ConfirmBy[
            AssociationThread[ cellsAfter -> taggedQ /@ CurrentValue[ cellsAfter, CellTags ] ],
            AssociationQ,
            "Tagged"
        ];

        generated = ConfirmBy[
            AssociationThread[ cellsAfter -> CurrentValue[ cellsAfter, GeneratedCell ] ],
            AssociationQ,
            "Generated"
        ];

        skip = ConfirmBy[
            Merge[ { tagged, generated }, Apply @ Or ],
            AssociationQ,
            "Skip"
        ];

        skipped = ConfirmBy[ TakeWhile[ skip, TrueQ ], AssociationQ, "Inserted" ];
        insertionPoint = ConfirmMatch[ Last[ Keys @ skipped, cellObj ], _CellObject, "InsertionPoint" ];

        SelectionMove[ insertionPoint, After, Cell ];
        NotebookWrite[ nbo, preprocessInsertedCell @ cell, All ];
    ],
    throwInternalFailure
];

insertAfterChatGeneratedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*copyCode*)
copyCode // beginDefinition;
copyCode[ cell_CellObject ] := copyCode @ getCodeBlockContent @ cell;
copyCode[ code: _Cell|_String ] := CopyToClipboard @ stripMarkdownBoxes @ code;
copyCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessInsertedCell*)
preprocessInsertedCell // beginDefinition;
preprocessInsertedCell[ cell_ ] := addInsertedCellTags @ stripMarkdownBoxes @ cell;
preprocessInsertedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addInsertedCellTags*)
addInsertedCellTags // beginDefinition;

addInsertedCellTags[ Cell[ a__, CellTags -> tag_String, b___ ] ] :=
    addInsertedCellTags @ Cell[ a, CellTags -> { tag }, b ];

addInsertedCellTags[ Cell[ a__, CellTags -> { tags___String }, b___ ] ] :=
    Cell[ a, CellTags -> DeleteDuplicates @ { $chatGeneratedCellTag, tags }, b ];

addInsertedCellTags[ Cell[ a: Except[ CellTags -> _ ].. ] ] :=
    Cell[ a, CellTags -> { $chatGeneratedCellTag } ];

addInsertedCellTags // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripMarkdownBoxes*)
stripMarkdownBoxes // beginDefinition;

stripMarkdownBoxes[ Cell[ BoxData[ TagBox[ TooltipBox[ boxes_, _String ], "MarkdownImage", ___ ], ___ ], a___ ] ] :=
    Cell[ BoxData @ boxes, a ];

stripMarkdownBoxes[ Cell[ BoxData[ TagBox[ boxes_, "MarkdownImage", ___ ], a___ ], ___ ] ] :=
    Cell[ BoxData @ boxes, a ];

stripMarkdownBoxes[ expr: _Cell|_String ] :=
    expr;

stripMarkdownBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getCodeBlockContent*)
getCodeBlockContent // beginDefinition;
getCodeBlockContent[ cell_CellObject ] := getCodeBlockContent @ NotebookRead @ cell;

getCodeBlockContent[   Cell[    cData_, "ChatCode", cs:"Input", ___ ] ] := reparseCodeBoxes @ Cell[ cData, cs ];
getCodeBlockContent[   Cell[    cData_, cs:"ExternalLanguage", ___, CellEvaluationLanguage -> lang_, ___ ] ] := Cell[ cData, cs, CellEvaluationLanguage -> lang ];
getCodeBlockContent[   Cell[ b_BoxData, "ChatCodeBlock",        ___ ] ] := getCodeBlockContent @ First @ b; (* recurse into BoxData content if a ChatCodeBlock cell *)
getCodeBlockContent[   Cell[   BoxData[ c_Cell ],               ___ ] ] := getCodeBlockContent @ c;         (* recurse into any BoxData inline cells *)
getCodeBlockContent[ c:Cell[    cData_, cs_String,              ___ ] ] := c;                               (* stop recursion at unexpected cell structures *)

getCodeBlockContent[ TemplateBox[ { boxes_, ___ }, "ChatCodeBlockTemplate" | "NotebookAssistant`Sidebar`ChatCodeBlockTemplate", ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ DynamicModuleBox[ _, boxes_, ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ TagBox[ boxes_, _EventHandlerTag, ___ ] ] := getCodeBlockContent @ boxes;

getCodeBlockContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reparseCodeBoxes*)
reparseCodeBoxes // beginDefinition;

reparseCodeBoxes[ Cell[ BoxData[ s_String ], a___ ] ] /; $cloudNotebooks :=
    Cell[ BoxData @ usingFrontEnd @ stringToBoxes @ s, a ];

reparseCodeBoxes[ cell_Cell ] :=
    cell;

reparseCodeBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*button*)
button // beginDefinition;
button // Attributes = { HoldRest };

button[ label_, code_, opts___ ] := Button[
    label, code, opts,
    Appearance -> Dynamic @ FEPrivate`FrontEndResource[ "FEExpressions", "SuppressMouseDownNinePatchAppearance" ],
    BaselinePosition -> Baseline
];

button // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonMouseover*)
buttonMouseover[ a_, b_ ] := Mouseover[ a, b, BaselinePosition -> Baseline ];
buttonMouseover[ a_, b_, c_ ] := If[ $cloudNotebooks, buttonMouseover[ a, b ], NotebookTools`Mousedown[ a, b, c, BaselinePosition -> Baseline ] ]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonFrameDefault*)
buttonFrameDefault[ expr_, extendMarginsQ: True|False : True ] :=
    Framed[
        expr,
        FrameStyle       -> None,
        Background       -> None,
        BaselinePosition -> Baseline,
        FrameMargins     -> If[ extendMarginsQ, { { 0, 4 }, { 0, 0 } }, 0 ], (* If there's text then we need larger right-margins *)
        RoundingRadius   -> 2
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonFrameHover*)
buttonFrameHover[ expr_, extendMarginsQ: True|False : True ] :=
    Framed[
        expr,
        FrameStyle       -> color @ "NA_ChatCodeBlockTemplateButtonFrameHover",
        Background       -> color @ "NA_ChatCodeBlockTemplateButtonBackgroundHover",
        BaselinePosition -> Baseline,
        FrameMargins     -> If[ extendMarginsQ, { { 0, 4 }, { 0, 0 } }, 0 ], (* If there's text then we need larger right-margins *)
        RoundingRadius   -> 2
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonFramePressed*)
buttonFramePressed[ expr_, extendMarginsQ: True|False : True ] :=
    Framed[
        expr,
        FrameStyle       -> color @ "NA_ChatCodeBlockTemplateButtonFramePressed",
        Background       -> color @ "NA_ChatCodeBlockTemplateButtonBackgroundPressed",
        BaselinePosition -> Baseline,
        FrameMargins     -> If[ extendMarginsQ, { { 0, 4 }, { 0, 0 } }, 0 ], (* If there's text then we need larger right-margins *)
        RoundingRadius   -> 2
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonPane*)
buttonPane[ expr_ ] :=
    Pane[ expr, ImageSize -> { 24, 24 }, ImageSizeAction -> "ShrinkToFit", Alignment -> { Center, Center }, BaselinePosition -> Baseline ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*labeledIcon*)
labeledIcon // beginDefinition;


labeledIcon[ iconTemplateName_String, textResource_String ] :=
    labeledIcon[ { iconTemplateName, False }, textResource ];


labeledIcon[ { iconTemplateName_String, useTemplateBoxQ_ }, textResource_String ] :=
    labeledIcon[
        If[ useTemplateBoxQ,
            RawBoxes @ templateBox[ { }, iconTemplateName ],
            chatbookExpression @ iconTemplateName
        ],
        textResource
    ];

labeledIcon[ { iconTemplateName_String, "Disabled" }, textResource_String ] := Grid[
    {
        {
            buttonPane @ chatbookExpression @ iconTemplateName,
            Style[
                tr @ textResource,
                FontColor  -> color @ "NA_ChatCodeBlockTemplateButtonFontDisabled",
                FontFamily -> "Source Sans Pro",
                FontSize   -> 12
            ]
        }
    },
    Alignment        -> { Left, Baseline },
    BaselinePosition -> { 1, 2 },
    Spacings         -> { 0, 0 }
];

labeledIcon[ icon_, textResource_String ] := Grid[
    {
        {
            buttonPane @ icon,
            Style[
                tr @ textResource,
                FontColor  -> color @ "NA_ChatCodeBlockTemplateButtonFont",
                FontFamily -> "Source Sans Pro",
                FontSize   -> 12
            ]
        }
    },
    Alignment        -> { Left, Baseline },
    BaselinePosition -> { 1, 2 },
    Spacings         -> { 0, 0 }
];


labeledIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fancyTooltip*)
fancyTooltip[ expr_, tooltip_ ] := Tooltip[
    expr,
    Framed[
        Style[
            tooltip,
            "Text",
            FontColor    -> color @ "ChatOutputTooltipFont",
            FontSize     -> 12,
            FontWeight   -> "Plain",
            FontTracking -> "Plain"
        ],
        Background   -> color @ "ChatOutputTooltipBackground",
        FrameStyle   -> color @ "ChatOutputTooltipFrame",
        FrameMargins -> 8
    ],
    TooltipDelay -> 0.15,
    TooltipStyle -> { Background -> None, CellFrame -> 0 }
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
