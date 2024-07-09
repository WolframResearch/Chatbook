(* ::Package:: *)

Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];


(* ::Section::Closed:: *)
(*Notebook*)


Cell[
    StyleData[ "Notebook" ],
    Background             -> White,
    CellInsertionPointCell -> Cell[ ],
    ClosingSaveDialog      -> False,
    DefaultNewCellStyle    -> "AutoMoveToChatInputField",
    DockedCells            -> $floatingChatDockedCells,
    Magnification          -> 0.85,
    PrivateNotebookOptions -> { "ExcludeFromShutdown" -> True },
    Selectable             -> False,
    ShowCellBracket        -> False,
    TaggingRules           -> <| "ChatNotebookSettings" -> <| "WorkspaceChat" -> True |> |>,
    WindowClickSelect      -> True,
    WindowElements         -> { "StatusArea", "VerticalScrollBar" },
    WindowFrameElements    -> { "CloseBox", "ResizeArea" },
    WindowMargins          -> { { 0, Automatic }, { Automatic, 0 } },
    WindowSize             -> { $sideChatWidth, Automatic },
    WindowTitle            -> "Code Assistance Chat",
    WindowToolbars         -> { }
]


(* ::Section::Closed:: *)
(*ChatInput*)


Cell[
    StyleData[ "ChatInput" ],
    Selectable      -> True,
    CellMargins     -> { { 40, 20 }, { 0, Inherited } },
    ShowCellBracket -> False
]


(* ::Section::Closed:: *)
(*ChatOutput*)


Cell[
    StyleData[ "ChatOutput" ],
    CellMargins     -> { { 40, 20 }, { Inherited, 0 } },
    ShowCellBracket -> False,
    Selectable      -> True
]


(* ::Section::Closed:: *)
(*ChatInputField*)


Cell[
    StyleData[ "ChatInputField" ],
    CellFrame        -> 1,
    CellFrameColor   -> GrayLevel[ 0.85 ],
    CellFrameMargins -> { { 5, 5 }, { 0, 0 } }
]


(* ::Section::Closed:: *)
(*AutoMoveToChatInputField*)


Cell[
    StyleData[ "AutoMoveToChatInputField" ],
    Initialization :> (
        NotebookDelete @ EvaluationCell[ ];
        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MoveToChatInputField", EvaluationNotebook[ ], True ];
    )
]


(* ::Section::Closed:: *)
(*Package Footer*)


End[ ];