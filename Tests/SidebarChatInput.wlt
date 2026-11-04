(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/SidebarChatInput.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/SidebarChatInput.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $userNotebook = NotebookObject[ "user-notebook", "user-notebook" ];
    $sidebarCell  = CellObject[ "sidebar-cell" ];

    (* The (held) send handler of the sidebar chat input cell, which runs when the return key is pressed: *)
    $sendHandler = FirstCase[
        Wolfram`Chatbook`Common`makeSidebarChatInputCell[ ],
        HoldPattern @ DynamicWrapperBox[ _, handler_, ___ ] :> HoldComplete @ handler,
        Missing[ "NotFound" ],
        Infinity
    ];

    (* Runs the send handler for a sidebar in the user's notebook, with front end calls replaced by a log: *)
    runSidebarSend[ ] := Module[ { log = { } },
        Block[
            {
                Typeset`nbo$$            = $userNotebook,
                Typeset`sidebarCell$$    = $sidebarCell,
                Typeset`input$$          = "Reply with exactly: OK2",
                Typeset`returnKeyDownQ$$ = True,
                Typeset`chatEvalCell$$   = { },
                CurrentValue,
                FE`Evaluate                   = Function[ Null, { }, HoldAll ],
                Cells                         = Function[ { } ],
                NotebookDelete                = Function[ AppendTo[ log, { "NotebookDelete", ## } ] ],
                FrontEndExecute               = Function[ AppendTo[ log, { "FrontEndExecute", ## } ] ],
                SetOptions                    = Function[ AppendTo[ log, { "SetOptions", ## } ] ],
                Wolfram`Chatbook`Common`setCurrentValue = Function[ AppendTo[ log, { "setCurrentValue", ## } ] ],
                Wolfram`Chatbook`Common`cellTaggedQ     = False &,
                Wolfram`Chatbook`Common`evaluateSidebarChat = Function[ AppendTo[ log, { "evaluateSidebarChat", #1, #3 } ] ],
                Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized = True
            },
            CurrentValue /: Set[ CurrentValue[ args___ ], value_ ] := (AppendTo[ log, { "CurrentValue", args } ]; value);
            ReleaseHold @ $sendHandler;
            log
        ]
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/SidebarChatInput.wlt:25,1-66,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sidebar Send*)

(* Sending a sidebar message must not write the user's notebook options, e.g. WindowElements: *)
VerificationTest[
    runSidebarSend[ ],
    {
        { "CurrentValue", $sidebarCell, { TaggingRules, "CurrentSelections" } },
        { "NotebookDelete", { } },
        { "evaluateSidebarChat", $userNotebook, "Reply with exactly: OK2" }
    },
    SameTest -> MatchQ,
    TestID   -> "SidebarSend-LeavesNotebookOptions@@Tests/SidebarChatInput.wlt:73,1-82,2"
]

VerificationTest[
    FreeQ[ runSidebarSend[ ], { "setCurrentValue", $userNotebook, ___ } | { "SetOptions", $userNotebook, ___ } | WindowElements ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SidebarSend-NoWindowElementsWrite@@Tests/SidebarChatInput.wlt:84,1-89,2"
]

(* The front end runs the pre-built copy of the sidebar cell from the text resources, so it must match the source: *)
VerificationTest[
    Module[ { files },
        files = FileNameJoin @ { PacletObject[ "Wolfram/Chatbook" ][ "Location" ], #, "TextResources", "ChatbookResources.tr" } & /@
            { "FrontEnd", "DarkModeSupport" };
        {
            StringContainsQ[ ReadString @ #, "ChatModes`UI`Private`clearSidebarOverlayMenus[" ],
            StringContainsQ[ ReadString @ #, "ChatModes`UI`Private`clearOverlayMenus[" ]
        } & /@ Select[ files, FileExistsQ ]
    ],
    { { True, False }.. },
    SameTest -> MatchQ,
    TestID   -> "SidebarSend-PrebuiltResource@@Tests/SidebarChatInput.wlt:92,1-104,2"
]

(* :!CodeAnalysis::EndBlock:: *)
