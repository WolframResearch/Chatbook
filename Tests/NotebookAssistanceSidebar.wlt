(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/NotebookAssistanceSidebar.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/NotebookAssistanceSidebar.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Requested Settings*)

(* ShowNotebookAssistance's "ChatNotebookSettings" for a sidebar that is not initialized yet are kept, merged, for the
   Initialization of its docked cell; no settings keep nothing *)
VerificationTest[
    Block[ { Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`$requestedSidebarSettings = <| |> },
        Module[ { request, nbo = NotebookObject[ "fe", "nb" ] },
            request = Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`requestSidebarSettings;
            request[ nbo, $Failed, <| "NotebookEditing" -> True |> ];
            request[ nbo, $Failed, <| "Model" -> "m" |> ];
            request[ NotebookObject[ "fe", "other" ], $Failed, <| |> ];
            {
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`$requestedSidebarSettings,
                Wolfram`Chatbook`ChatModes`Common`applyRequestedSidebarSettings[ nbo, $Failed ],
                Length @ Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`$requestedSidebarSettings
            }
        ]
    ],
    { <| NotebookObject[ "fe", "nb" ] -> <| "NotebookEditing" -> True, "Model" -> "m" |> |>, Null, 1 },
    SameTest -> MatchQ,
    TestID   -> "Sidebar-RequestedSettings-Pending@@Tests/NotebookAssistanceSidebar.wlt:27,1-44,2"
]

(* FE-only: the docked cell's Initialization applies the kept settings to the sidebar cell and forgets them; an
   initialized sidebar gets them at once *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Block[ { Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`$requestedSidebarSettings = <| |> },
            Module[ { request, nbo, cell, editing, result },
                request = Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`requestSidebarSettings;
                nbo     = NotebookPut[ Notebook @ { Cell[ "x", "Text" ] }, Visible -> False ];
                cell    = First @ Cells @ nbo;
                editing := CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", "NotebookEditing" } ];
                request[ nbo, $Failed, <| "NotebookEditing" -> True |> ];
                SetOptions[ cell, TaggingRules -> <| "ChatNotebookSettings" -> <| "SidebarChat" -> True |> |> ];
                Wolfram`Chatbook`ChatModes`Common`applyRequestedSidebarSettings[ nbo, cell ];
                result = { editing, Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`$requestedSidebarSettings };
                CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", "NotebookEditing" } ] = False;
                request[ nbo, cell, <| "NotebookEditing" -> True |> ];
                result = Join[ result, { editing, Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`$requestedSidebarSettings } ];
                NotebookClose @ nbo;
                result
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | { True, <| |>, True, <| |> },
    SameTest -> MatchQ,
    TestID   -> "Sidebar-RequestedSettings-Apply-FEOnly@@Tests/NotebookAssistanceSidebar.wlt:48,1-72,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Editing Switch*)

(* Until the docked cell's Initialization has stored the sidebar cell, the switch's place shows a placeholder that the
   front end draws alone while the kernel is busy: the PaneSelector's test is a front end expression; its default has
   the front end's Necklace indicator, one hidden AnimatorBox, and a label whose opacity Dynamic is arithmetic only *)
VerificationTest[
    Module[ { boxes },
        boxes = ToBoxes @ DynamicModule[ { Typeset`v }, Wolfram`Chatbook`ChatModes`UI`Private`sidebarEditingSwitch @ Dynamic @ Typeset`v ];
        Cases[
            boxes,
            PaneSelectorBox[ { True -> _ }, Dynamic[ FEPrivate`MatchQ[ _, Verbatim[ _CellObject ] ], ___ ], default_, ___ ] :> {
                Cases[
                    default,
                    DynamicBox[ e_, ___ ] :> MatchQ[ Unevaluated @ e, FEPrivate`FrontEndResource[ "FEExpressions", "NecklaceAnimator" ][ ___ ] ],
                    { 0, Infinity }
                ],
                Count[ default, _AnimatorBox, { 0, Infinity } ],
                Cases[
                    default,
                    (FontOpacity -> Dynamic[ e_ ]) :> Complement[
                        Cases[ HoldComplete @ e, h_Symbol[ ___ ] :> h, { 1, Infinity }, Heads -> False ],
                        { Plus, Times, Cos }
                    ],
                    Infinity
                ]
            },
            { 0, Infinity }
        ]
    ],
    { { { True }, 1, { { } } } },
    SameTest -> MatchQ,
    TestID   -> "Sidebar-EditingSwitch-Placeholder@@Tests/NotebookAssistanceSidebar.wlt:81,1-108,2"
]

(* FE-only: the front end's MatchQ is True for the sidebar cell, but stays unevaluated while the variable has no value,
   which is why the placeholder is the PaneSelector's default rather than its False case *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Module[ { nbo, cell, result },
            nbo  = NotebookPut[ Notebook @ { Cell[ "x", "Text" ] }, Visible -> False ];
            cell = First @ Cells @ nbo;
            result = {
                MathLink`CallFrontEnd @ FrontEnd`Value @ FEPrivate`MatchQ[ cell, Blank[ CellObject ] ],
                TrueQ @ MathLink`CallFrontEnd @ FrontEnd`Value @ FEPrivate`MatchQ[ Global`noValue, Blank[ CellObject ] ]
            };
            NotebookClose @ nbo;
            result
        ]
    ],
    Missing[ "TestSkipped" ] | { True, False },
    SameTest -> MatchQ,
    TestID   -> "Sidebar-EditingSwitch-FrontEndTest-FEOnly@@Tests/NotebookAssistanceSidebar.wlt:112,1-129,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Agent Messages*)

(* The agent's text in a sidebar message is formatted markdown, live and final: LaTeX math becomes boxes, not the raw
   \( ... \) delimiters *)
VerificationTest[
    Module[ { entity, boxes },
        entity = <| "Type" -> "Message", "Text" -> "Added a plot of \\(\\sin x\\) from \\(-2\\pi\\), using **Plot**.\n", "Child" -> None |>;
        boxes  = Table[
            Block[ { Wolfram`Chatbook`ChatModes`Evaluate`Private`$sidebarAgentFinal = final },
                ToBoxes @ Wolfram`Chatbook`ChatModes`Evaluate`Private`sidebarAgentEntityView[ None, entity ]
            ],
            { final, { False, True } }
        ];
        { FreeQ[ #, s_String /; StringContainsQ[ s, "\\(" | "**" ] ], Count[ #, _FormBox, Infinity ] > 0 } & /@ boxes
    ],
    { { True, True }, { True, True } },
    SameTest -> MatchQ,
    TestID   -> "Sidebar-AgentMessage-FormattedMarkdown@@Tests/NotebookAssistanceSidebar.wlt:137,1-151,2"
]

(* :!CodeAnalysis::EndBlock:: *)
