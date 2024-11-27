(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`NotebookFocus`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetFocusedNotebook*)
GetFocusedNotebook // beginDefinition;
GetFocusedNotebook[ ] := catchMine @ GetFocusedNotebook @ EvaluationNotebook[ ];
GetFocusedNotebook[ obj: $$feObj ] := catchMine @ getFocusedNotebook @ obj;
GetFocusedNotebook[ app: _String | All ] := catchMine @ GetFocusedNotebook @ findCurrentWorkspaceChat @ app;
GetFocusedNotebook[ _Missing ] := None;
GetFocusedNotebook // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getFocusedNotebook*)
getFocusedNotebook // beginDefinition;

getFocusedNotebook[ obj: $$feObj ] /; ! TrueQ @ CurrentChatSettings[ obj, "WorkspaceChat" ] :=
    If[ MatchQ[ obj, _NotebookObject ], obj, parentNotebook @ obj ];

getFocusedNotebook[ obj: $$feObj ] := Enclose[
    Module[ { locked },
        locked = ConfirmMatch[ getLockedNotebook @ obj, _NotebookObject | None, "Locked" ];
        If[ notebookObjectQ @ locked, locked, getUserNotebook[ ] ]
    ],
    throwInternalFailure
];

getFocusedNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Focus Indicator*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*focusedNotebookDisplay*)
focusedNotebookDisplay // beginDefinition;

focusedNotebookDisplay[ chatNB_ ] := Enclose[
    Catch @ Module[ { locked, notebooks, info, current, focused, label },

        locked = getLockedNotebook @ chatNB;

        notebooks = ConfirmMatch[
            Cases[ SourceNotebookObjectInformation[ ], KeyValuePattern[ "Included" -> True ] ],
            { ___Association },
            "Notebooks"
        ];

        If[ notebooks === { }, Throw @ Spacer[ 0 ] ];

        info = ConfirmMatch[ addFocusInfo[ locked, notebooks ], { __Association }, "Info" ];
        current = ConfirmBy[ First @ info, AssociationQ, "Current" ];
        focused = FirstCase[ info, KeyValuePattern[ "Focused" -> True ], current ];

        (* focusedNotebookDisplay is dynamically updated so this TaggingRules value should be kept current *)
        CurrentValue[ chatNB, { TaggingRules, "FocusWindowTitle" } ] = Lookup[ focused, "WindowTitle", None ];

        label = Grid[
            { {
                Toggler[
                    Dynamic @ CurrentChatSettings[ chatNB, "AllowSelectionContext" ],
                    {
                        True  -> $disableNotebookFocusLabel,
                        False -> $enableNotebookFocusLabel
                    },
                    BaselinePosition -> Baseline
                ],
                tr[ "WorkspaceFocusIndicatorFocus" ],
                focusedNotebookDisplay0[ chatNB, focused, locked, info ]
            } },
            Alignment        -> { Left, Baseline },
            BaseStyle        -> { "Text", FontColor -> GrayLevel[ 0.5 ], FontSize -> 13 },
            BaselinePosition -> { 1, 2 } (* align to the text *)
        ];

        Pane[ label, ImageMargins -> { { 0, 0 }, { 0, 0 } } ]
    ],
    throwInternalFailure
];

focusedNotebookDisplay // endDefinition;



focusedNotebookDisplay0 // beginDefinition;

focusedNotebookDisplay0[ chatNB_, focused_, locked_, info_ ] := Grid[
    { {
        currentNotebookButton @ focused,
        selectNotebookFocusMenu[ chatNB, locked, info ]
    } },
    Alignment        -> { Left, Baseline },
    BaselinePosition -> { 1, 1 }, (* align to the button *)
    Dividers         -> Center,
    FrameStyle       -> GrayLevel[ 0.75 ]
];

focusedNotebookDisplay0 // endDefinition;


$enableNotebookFocusLabel := $enableNotebookFocusLabel = Tooltip[
    chatbookIcon[ "WorkspaceFocusIndicatorUncheck", False ],
    tr[ "WorkspaceFocusIndicatorEnableTooltip" ]
];

$disableNotebookFocusLabel := $disableNotebookFocusLabel = Tooltip[
    chatbookIcon[ "WorkspaceFocusIndicatorCheck", False ],
    tr[ "WorkspaceFocusIndicatorDisableTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addFocusInfo*)
addFocusInfo // beginDefinition;

addFocusInfo[ locked_, notebooks_List ] :=
    MapIndexed[ addFocusInfo[ locked, #1, #2 ] &, notebooks ];

addFocusInfo[ locked_, as_Association, { idx_ } ] := <|
    "Current" -> idx === 1,
    "Focused" -> as[ "NotebookObject" ] === locked,
    as
|>;

addFocusInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*currentNotebookButton*)
currentNotebookButton // beginDefinition;

currentNotebookButton[ as: KeyValuePattern @ { "NotebookObject" -> nbo_NotebookObject, "WindowTitle" -> title_ } ] :=
    Button[
        currentNotebookButtonLabel @ Replace[
            formatNotebookTitle @ title,
            s_String :> FE`Evaluate @ FEPrivate`TruncateStringToWidth[ s, "Text", 200, Right ]
        ],
        SetSelectedNotebook @ nbo,
        Appearance       -> "Suppressed",
        BaseStyle        -> { "Text", FontColor -> GrayLevel[ 0.5 ], FontSize -> 13 },
        BaselinePosition -> Baseline
    ];

currentNotebookButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*currentNotebookButtonLabel*)
currentNotebookButtonLabel // beginDefinition;

currentNotebookButtonLabel[ title_ ] := Mouseover[
    Row[
        {
            chatbookIcon[ "WorkspaceFocusIndicatorNotebook", False ],
            Spacer[ 3 ],
            title
        },
        BaselinePosition -> Baseline
    ],
    Row[
        {
            chatbookIcon[ "WorkspaceFocusIndicatorNotebookActive", False ],
            Spacer[ 3 ],
            Style[ title, FontColor -> RGBColor[ 0.2, 0.51373, 0.67451, 1.0 ] ]
        },
        BaselinePosition -> Baseline
    ],
    BaselinePosition -> Baseline
];

currentNotebookButtonLabel // endDefinition;

$smallNotebookIcon := $smallNotebookIcon = chatbookIcon[ "WorkspaceFocusIndicatorNotebook", False ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectNotebookFocusMenu*)
selectNotebookFocusMenu // beginDefinition;

selectNotebookFocusMenu[ chatNB_, locked_, items: { current_Association, ___Association } ] :=
    selectNotebookFocusMenu[ chatNB, locked, current, SortBy[ items, Lookup[ "WindowTitle" ] ] ];

selectNotebookFocusMenu[ chatNB_, locked_, first_, rest_ ] := Tooltip[
    ActionMenu[
        chatbookIcon[ "WorkspaceFocusIndicatorCaret", False ],
        Flatten @ {
            currentNotebookAction[ chatNB, locked, first ],
            Delimiter,
            otherNotebookActions[ chatNB, locked, rest ]
        },
        Appearance       -> "Suppressed",
        BaseStyle        -> { "Text", FontColor -> GrayLevel[ 0.5 ], FontSize -> 13, Magnification -> Inherited / 0.85 },
        BaselinePosition -> Baseline
    ],
    tr[ "WorkspaceFocusIndicatorMenuTooltip" ]
];

selectNotebookFocusMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*currentNotebookAction*)
currentNotebookAction // beginDefinition;

currentNotebookAction[ chatNB_, locked_, as_Association ] :=
    currentNotebookAction[ chatNB, locked, as[ "WindowTitle" ], as[ "NotebookObject" ] ];

currentNotebookAction[ chatNB_, locked_, title_, nbo_ ] :=
    Row @ {
        Style[ "\[Checkmark] ", ShowContents -> locked === None ],
        tr[ "WorkspaceFocusIndicatorMenuAutomatic" ],
        " (",
        formatNotebookTitle @ title,
        ")"
    } :> (
        CurrentChatSettings[ chatNB, "AllowSelectionContext" ] = True;
        CurrentChatSettings[ chatNB, "FocusedNotebook" ] = Inherited
    );

currentNotebookAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*otherNotebookActions*)
otherNotebookActions // beginDefinition;
otherNotebookActions[ chatNB_, locked_, items_List ] := otherNotebookAction[ chatNB, locked, # ] & /@ items;
otherNotebookActions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*otherNotebookAction*)
otherNotebookAction // beginDefinition;

otherNotebookAction[ chatNB_, locked_, as_Association ] :=
    otherNotebookAction[ chatNB, locked, as[ "WindowTitle" ], as[ "NotebookObject" ] ];

otherNotebookAction[ chatNB_, locked_, title_, nbo_ ] :=
    Row @ { Style[ "\[Checkmark] ", ShowContents -> locked === nbo ], formatNotebookTitle @ title } :> (
        CurrentChatSettings[ chatNB, "AllowSelectionContext" ] = True;
        CurrentChatSettings[ chatNB, "FocusedNotebook" ] = nbo
    );

otherNotebookAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getLockedNotebook*)
getLockedNotebook // beginDefinition;
getLockedNotebook[ nbo_ ] := getLockedNotebook[ nbo, CurrentChatSettings[ nbo, "FocusedNotebook" ] ];
getLockedNotebook[ nbo_, focused_ ] := If[ TrueQ @ notebookObjectQ @ focused, focused, None ];
getLockedNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
