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
(*chatbarMenuMagnification*)

(* The menu is attached to the notebook's right edge, so at high magnifications it must not get wider than the window,
   and otherwise it scales with the notebook as before: *)
VerificationTest[
    UsingFrontEnd @ Module[ { key, chatbarMag, menuMag, nbo, results },
        key = { PrivateFrontEndOptions, "InterfaceSettings", "NotebookAssistant", "Chatbar", "Magnification" };
        chatbarMag = CurrentValue[ $FrontEndSession, key ];
        menuMag = Setting @ Wolfram`Chatbook`ChatModes`UI`Private`chatbarMenuMagnification[ #1 ] &;
        WithCleanup[
            CurrentValue[ $FrontEndSession, key ] = 0.75;
            nbo = CreateDocument[ { }, Visible -> False, WindowSize -> { 606, 600 }, Magnification -> 2 ];
            results = { menuMag @ nbo * Wolfram`Chatbook`ChatModes`UI`Private`$coWidth };
            SetOptions[ nbo, WindowSize -> { 1200, 600 }, Magnification -> 1.5 ];
            AppendTo[ results, menuMag @ nbo ],
            NotebookClose @ nbo;
            CurrentValue[ $FrontEndSession, key ] = chatbarMag
        ];
        results
    ],
    { _? (# <= 606 - 13 &), _? (# == 1.5 * 0.75 &) },
    SameTest -> MatchQ,
    TestID   -> "ChatbarMenuMagnification-FitsWindow-GH#1795"
]

(* :!CodeAnalysis::EndBlock:: *)
