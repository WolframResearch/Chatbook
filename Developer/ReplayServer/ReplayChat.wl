(* ::Package:: *)

(* ::Text:: *)
(*Helpers for sending real Chatbook chats to the replay server (ollama_replay.py), in a chat notebook, the Notebook*)
(*Assistant window, or the sidebar. Load this in a kernel attached to a front end, after Chatbook:*)
(*    Get[ "/path/to/Chatbook/Developer/ReplayServer/ReplayChat.wl" ]*)
(*See .claude/skills/replay-chat/SKILL.md for how to use it.*)


BeginPackage[ "Wolfram`ChatbookReplay`" ];

$ReplayModel;
$ReplaySettings;
ReplaySetPort;
ReplayChatNotebook;
ReplayAssistantWindow;
ReplaySidebar;
ReplayUseServer;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`" -> None ];

(* The model the replay server reports. Chats with this model go to the Ollama provider of LLMServices: *)
$ReplayModel = <| "Service" -> "Ollama", "Name" -> "replay:latest" |>;

(* Settings added to every replay chat. Title generation would make a real request to another model, and saving
   would add the test chats to the user's chat history: *)
$ReplaySettings := <|
    "Model"                 -> $ReplayModel,
    "AutoGenerateTitle"     -> False,
    "AutoSaveConversations" -> False
|>;


(* ::Section::Closed:: *)
(*ReplaySetPort*)


(* The Ollama provider connects to 127.0.0.1:11435 by default; this changes the port for this kernel session: *)
ReplaySetPort[ port_Integer ] := ServiceExecute[ "Ollama", "SetOllamaPort", { "Port" -> port } ];


(* ::Section::Closed:: *)
(*ReplayChatNotebook*)


(* Creates a chat notebook that uses the replay server, with one ChatInput cell holding prompt. With "Evaluate" -> True
   the cell is evaluated (the same code path as Shift+Enter). Returns the NotebookObject. To send the chat with real
   keystrokes instead, use "Evaluate" -> False and then e.g. `fe.py focus --cell ID` and `fe.py key shift+Return`. *)
Options[ ReplayChatNotebook ] = { "Evaluate" -> True, "Settings" -> <| |>, "Title" -> "ReplayChat" };

ReplayChatNotebook[ prompt_String, opts: OptionsPattern[ ] ] :=
    Module[ { nbo },
        nbo = CreateDocument[
            { Cell[ prompt, "ChatInput" ] },
            WindowTitle      -> OptionValue[ "Title" ],
            StyleDefinitions -> "Chatbook.nb",
            WindowSize       -> { 800, 900 },
            TaggingRules     -> <| "ChatNotebookSettings" -> <| $ReplaySettings, OptionValue[ "Settings" ] |> |>
        ];
        If[ TrueQ @ OptionValue[ "Evaluate" ],
            SelectionMove[ First @ Cells @ nbo, All, Cell ];
            FrontEndTokenExecute[ nbo, "EvaluateCells" ]
        ];
        nbo
    ];


(* ::Section::Closed:: *)
(*ReplayAssistantWindow*)


(* Opens a new Notebook Assistant window that uses the replay server (replacing an open one). Given a prompt, it's
   sent right away; otherwise send one through the real input field with `fe.py ask 'prompt'`. *)
Options[ ReplayAssistantWindow ] = { "Settings" -> <| |> };

ReplayAssistantWindow[ opts: OptionsPattern[ ] ] :=
    ReplayAssistantWindow[ None, opts ];

ReplayAssistantWindow[ prompt: _String | None, opts: OptionsPattern[ ] ] :=
    Wolfram`Chatbook`ShowNotebookAssistance[
        "Window",
        "ChatNotebookSettings" -> <| $ReplaySettings, OptionValue[ "Settings" ] |>,
        "NewChat"              -> True,
        If[ StringQ @ prompt, Sequence @@ { "Input" -> prompt, "EvaluateInput" -> True }, Sequence @@ { } ]
    ];


(* ::Section::Closed:: *)
(*ReplaySidebar*)


(* Opens the Notebook Assistant sidebar of nbo. The sidebar creates its chat cell asynchronously (which can't happen
   while this kernel is busy), so call ReplayUseServer[ nbo, "Sidebar" -> True ] in a separate evaluation afterwards
   (it gives $Failed until the sidebar is ready), then send a prompt
   with `fe.py ask 'prompt' --sidebar NB`. *)
ReplaySidebar[ nbo_NotebookObject ] :=
    Wolfram`Chatbook`ShowNotebookAssistance[ nbo, "Sidebar" ];


(* ::Section::Closed:: *)
(*ReplayUseServer*)


(* Makes an existing chat use the replay server. Give it the assistant window, a chat notebook, or the notebook whose
   sidebar should use it (with "Sidebar" -> True). Returns the object whose settings were changed, or $Failed if the
   sidebar isn't ready yet. *)
Options[ ReplayUseServer ] = { "Sidebar" -> False };

ReplayUseServer[ nbo_NotebookObject, OptionsPattern[ ] ] :=
    If[ TrueQ @ OptionValue[ "Sidebar" ], ReplayUseServer @ sidebarCell @ nbo, setReplaySettings @ nbo ];

ReplayUseServer[ cell_CellObject, OptionsPattern[ ] ] := setReplaySettings @ cell;

ReplayUseServer[ $Failed, OptionsPattern[ ] ] := $Failed;

setReplaySettings[ obj_ ] := (
    KeyValueMap[ (Wolfram`Chatbook`CurrentChatSettings[ obj, #1 ] = #2) &, $ReplaySettings ];
    obj
);

(* The sidebar's chat cell (the parent of a helper cell attached to it), once its initialization has set its settings: *)
sidebarCell[ nbo_NotebookObject ] :=
    With[
        {
            cell = ParentCell @ First[
                Cells[ nbo, AttachedCell -> True, CellTags -> "NotebookAssistantSidebarAttachedHelperCell" ],
                $Failed
            ]
        },
        If[ MatchQ[ cell, _CellObject ] &&
            TrueQ @ CurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", "SidebarChat" } ],
            cell,
            $Failed
        ]
    ];


End[ ];
EndPackage[ ];
