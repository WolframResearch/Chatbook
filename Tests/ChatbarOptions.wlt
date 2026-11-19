(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*chatbarStateSetterBar*)
VerificationTest[
    $openMinimizedKey = { PrivateFrontEndOptions, "InterfaceSettings", "NotebookAssistant", "Chatbar", "OpenMinimized" };
    $setterNotebook = UsingFrontEnd @ CreateDocument[ { }, Visible -> False ];
    $setterBoxes = ToBoxes @ Wolfram`Chatbook`ChatModes`UI`Private`chatbarStateSetterBar @ $setterNotebook,
    _DynamicModuleBox,
    SameTest -> MatchQ,
    TestID   -> "ChatbarStateSetterBar-Boxes"
]

(* Nothing in the menu runs on display; the state is only applied by the click actions: *)
VerificationTest[
    {
        FreeQ[ $setterBoxes, DynamicWrapperBox ],
        FreeQ[ $setterBoxes, Initialization ],
        FirstCase[ $setterBoxes, DynamicModuleBox[ { Verbatim[ Set ][ _, v_String ] }, ___ ] :> v, Missing[ ], { 0 } ]
    },
    { True, True, "Full" },
    SameTest -> MatchQ,
    TestID   -> "ChatbarStateSetterBar-NoDisplayActions"
]

(* Displaying the options menu must not change the global chat bar preferences: *)
VerificationTest[
    UsingFrontEnd @ Module[ { openMinimized, showChatbar, nbo = $setterNotebook, results },
        openMinimized = CurrentValue[ $FrontEnd, $openMinimizedKey ];
        showChatbar   = CurrentValue[ $FrontEnd, ShowChatbar ];
        WithCleanup[
            CurrentValue[ $FrontEnd, $openMinimizedKey ] = True;
            CurrentValue[ $FrontEnd, ShowChatbar ] = False;
            CurrentValue[ nbo, ShowChatbar ] = True;
            NotebookWrite[ nbo, Cell[ BoxData @ $setterBoxes, "Output" ] ];
            FrontEndExecute @ FrontEnd`Value @ 1;
            results = {
                CurrentValue[ $FrontEnd, $openMinimizedKey ],
                CurrentValue[ $FrontEnd, ShowChatbar ],
                CurrentValue[ nbo, ShowChatbar ]
            },
            NotebookClose @ nbo;
            CurrentValue[ $FrontEnd, $openMinimizedKey ] = openMinimized;
            CurrentValue[ $FrontEnd, ShowChatbar ] = showChatbar
        ];
        results
    ],
    { True, False, True },
    SameTest -> MatchQ,
    TestID   -> "ChatbarStateSetterBar-NoWriteOnDisplay"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*makeChatbarChatInputCellContent*)

(* The content's Magnification multiplies by the chatbar magnification, so making the content sets that value (if it
   isn't set yet) before the content is returned and first formatted, not only in its DynamicModule's Initialization: *)
VerificationTest[
    Module[ { calls = { } },
        Block[ { FE`Evaluate = (AppendTo[ calls, # ]; Null) & },
            Wolfram`Chatbook`Common`makeChatbarChatInputCellContent[ NotebookObject[ "chatbar-test" ], "" ]
        ];
        Cases[ calls, FrontEnd`CurrentValue[ FrontEnd`$FrontEnd, { ___, "Chatbar", key_ }, _ ] :> key, Infinity ]
    ],
    { "Magnification", "OpenMinimized" },
    SameTest -> MatchQ,
    TestID   -> "ChatbarContent-SettingsBeforeFirstFormat"
]

(* :!CodeAnalysis::EndBlock:: *)
