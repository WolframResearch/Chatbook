(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Rendering`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* Box rendering for ACP turns (see docs/acp-window.md, "State model", Rendering): live views, entity views, tool cards, diff view, permission panel,
   toolbar views and the final output cell.

   Live views (rule R6): the active output cell holds one Dynamic that tracks the turn's layout symbol. It renders the
   "Working" header and one Dynamic per entity, each tracking that entity's change symbol. Opener state lives in
   $acpOpen and is toggled by preemptive EventHandlers (ChatbookAction[ "ACP", "ToggleOpen", turnID, key, default ]).
   Live views contain no scroll panes and no DynamicModule-state openers. Everything the front end evaluates runs inside
   acpIsolated and renders a harmless placeholder when the kernel-side state is missing (e.g. after a kernel restart).

   The final output cell (acpFinalCell) is static and uses Chatbook's own templates (AssistantMessageBox, ThoughtsOpener,
   ChatCodeBlockTemplate) plus front-end-only DynamicModule openers for tool cards. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$liveOutputLines     = 12;   (* tail of tool output shown in live views *)
$finalOutputLines    = 200;  (* tail of tool output kept in the final cell *)
$liveDiffLines       = 40;
$finalDiffLines      = 400;
$liveCodeLines       = 30;
$liveImageSize       = { 320, 240 };  (* largest image size (points) in live views *)
$finalImageSize      = { 480, 360 };  (* largest image size (points) in final cells *)
$maxLineLength       = 300;
$diffContextLines    = 3;
$permissionPreviewHeight = 260;
$permissionArmDelay  = 0.4;  (* seconds before permission buttons accept clicks *)
$clockTicks          = 5;    (* the Working header's elapsed time is refreshed every 5 publisher ticks (1 s) *)
$cacheSweepTicks     = 50;
$codeFont            = "Source Code Pro";

(* Text color for "Worked for" content, overriding the gray ThinkingContent style: *)
$workContentFontColor = ThemeColor[ "Foreground" ];
$workContentFontSize  = 14;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Colors*)
$labelColor        := color @ "ThinkingOpenerFont";
$labelHoverColor   := color @ "ThinkingOpenerFontHover";
$toolLabelColor    := color @ "NA_ChatOutputToolCallLabelFont";
$cardBackground    := color @ "NA_ChatOutputToolCallOpenerBackground";
$cardFrame         := color @ "NA_ChatOutputToolCallOpenerFrame";
$cardFrameHover    := color @ "NA_ChatOutputToolCallOpenerFrameHover";
$amberBackground   := color @ "ErrorMessageNonFatalBackground";
$amberFrame        := color @ "ErrorMessageNonFatalFrame";
$amberFont         := color @ "ErrorMessageNonFatalFont";
$errorBackground   := color @ "ErrorMessageFatalBackground";
$errorFrame        := color @ "ErrorMessageFatalFrame";
$errorFont         := color @ "ErrorMessageFatalFont";
$sectionLabelColor := LightDarkSwitched[ GrayLevel[ 0.45 ], GrayLevel[ 0.7 ] ];
$mutedColor        := LightDarkSwitched[ GrayLevel[ 0.45 ], GrayLevel[ 0.68 ] ];
$amberText         := LightDarkSwitched[ RGBColor[ 0.70, 0.42, 0.0 ], RGBColor[ 0.96, 0.72, 0.32 ] ];
$redText           := LightDarkSwitched[ RGBColor[ 0.78, 0.16, 0.12 ], RGBColor[ 1.0, 0.48, 0.42 ] ];
$greenText         := LightDarkSwitched[ RGBColor[ 0.12, 0.52, 0.22 ], RGBColor[ 0.45, 0.82, 0.50 ] ];
$addedBackground   := LightDarkSwitched[ RGBColor[ 0.90, 0.97, 0.91 ], RGBColor[ 0.11, 0.24, 0.14 ] ];
$removedBackground := LightDarkSwitched[ RGBColor[ 1.0, 0.92, 0.92 ], RGBColor[ 0.30, 0.12, 0.12 ] ];
$hunkBackground    := LightDarkSwitched[ GrayLevel[ 0.94 ], GrayLevel[ 0.22 ] ];
$badgeBackground   := LightDarkSwitched[ GrayLevel[ 0.92 ], GrayLevel[ 0.28 ] ];
$primaryButton     := LightDarkSwitched[ RGBColor[ 0.07, 0.47, 0.80 ], RGBColor[ 0.30, 0.60, 0.90 ] ];
$primaryButtonHover := LightDarkSwitched[ RGBColor[ 0.05, 0.40, 0.70 ], RGBColor[ 0.38, 0.67, 0.95 ] ];
$secondaryButton   := LightDarkSwitched[ GrayLevel[ 1.0 ], GrayLevel[ 0.22 ] ];
$secondaryButtonHover := LightDarkSwitched[ GrayLevel[ 0.94 ], GrayLevel[ 0.30 ] ];
$secondaryButtonFrame := LightDarkSwitched[ GrayLevel[ 0.75 ], GrayLevel[ 0.45 ] ];

(* Colors for other files (Review.wl), so that all ACP views use the same palette *)
acpColor // beginDefinition;
acpColor[ "Muted"           ] := $mutedColor;
acpColor[ "GreenText"       ] := $greenText;
acpColor[ "RedText"         ] := $redText;
acpColor[ "AmberText"       ] := $amberText;
acpColor[ "ToolLabel"       ] := $toolLabelColor;
acpColor[ "CardFrame"       ] := $cardFrame;
acpColor[ "CardBackground"  ] := $cardBackground;
acpColor[ "AmberBackground" ] := $amberBackground;
acpColor[ "AmberFrame"      ] := $amberFrame;
acpColor[ "AmberFont"       ] := $amberFont;
acpColor[ "ErrorBackground" ] := $errorBackground;
acpColor[ "ErrorFrame"      ] := $errorFrame;
acpColor[ "ErrorFont"       ] := $errorFont;
acpColor // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpNeutralizeLinearSyntax*)

(* Text from the agent or the repository (diff lines, file names and contents, git's messages) is shown as strings in
   boxes. The private-use characters U+F7C0 to U+F7CD of the front end's linear syntax would make the front end turn
   such a string into boxes chosen by whoever wrote the text (styles that hide text, or dynamic content that evaluates
   code), so they are replaced with U+FFFD. Typed backslashes are escaped by ToBoxes and need nothing. *)
acpNeutralizeLinearSyntax // beginDefinition;

(* A search for each character as a literal string is fast (megabytes of patch text are checked in milliseconds); a
   pattern of alternatives would be much slower. *)
acpNeutralizeLinearSyntax[ s_String ] := If[ AnyTrue[ $linearSyntaxCharacters, StringContainsQ[ s, # ] & ],
    StringReplace[ s, Alternatives @@ $linearSyntaxCharacters -> "\:fffd" ],
    s
];

acpNeutralizeLinearSyntax[ other_ ] := other;

acpNeutralizeLinearSyntax // endDefinition;

$linearSyntaxCharacters = Characters @ FromCharacterCode @ Range[ 63424, 63437 ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withRenderContext*)

(* Boxes are always created with only System` and Global` on $ContextPath, so every Chatbook symbol in them (e.g. in
   button actions) is written with its full context name and still resolves when the boxes are evaluated later. *)
withRenderContext // beginDefinition;
withRenderContext // Attributes = { HoldFirst };
withRenderContext[ eval_ ] := Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" } }, eval ];
withRenderContext // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Caches*)

(* Per-entity live render cache: { turnID, key } -> { signature, boxes } *)
If[ ! AssociationQ @ $renderCache, $renderCache = <| |> ];
(* Formatted stable prefix of streaming text: { turnID, key } -> <| "Length", "Hash", "Items" |> *)
If[ ! AssociationQ @ $textCache, $textCache = <| |> ];
(* Per-turn Chatbook $resultCellCache: turnID -> _Association *)
If[ ! AssociationQ @ $turnResultCellCache, $turnResultCellCache = <| |> ];

$housekeepingRegistered = False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpDropRenderCache*)

(* Drops all cached boxes for a turn (called after finalization; also done periodically for dropped turns). *)
acpDropRenderCache // beginDefinition;

acpDropRenderCache[ id_String ] := (
    $renderCache = KeySelect[ $renderCache, ! MatchQ[ #, { id, _ } ] & ];
    $textCache   = KeySelect[ $textCache  , ! MatchQ[ #, { id, _ } ] & ];
    KeyDropFrom[ $turnResultCellCache, id ];
    Null
);

acpDropRenderCache // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Housekeeping*)
ensureHousekeeping // beginDefinition;

ensureHousekeeping[ ] := If[ ! TrueQ @ $housekeepingRegistered,
    acpRegisterHousekeeping[ "RenderingClock"     , clockTick         , $clockTicks      ];
    acpRegisterHousekeeping[ "RenderingCacheSweep", sweepRenderCaches , $cacheSweepTicks ];
    $housekeepingRegistered = True
];

ensureHousekeeping // endDefinition;


(* Refreshes the elapsed time in the Working header of every running turn: *)
clockTick // beginDefinition;

clockTick[ ] := Scan[
    If[ runningTurnQ @ $acpTurns[ # ], acpMarkDirty[ #, { "Clock" } ] ] &,
    Keys @ $acpTurns
];

clockTick // endDefinition;


runningTurnQ // beginDefinition;
runningTurnQ[ turn_Association ] := Lookup[ turn, "Status" ] === "Running";
runningTurnQ[ _ ] := False;
runningTurnQ // endDefinition;


sweepRenderCaches // beginDefinition;

sweepRenderCaches[ ] := Module[ { live },
    live = Keys @ $acpTurns;
    $renderCache = KeySelect[ $renderCache, MemberQ[ live, First @ # ] & ];
    $textCache   = KeySelect[ $textCache  , MemberQ[ live, First @ # ] & ];
    $turnResultCellCache = KeySelect[ $turnResultCellCache, MemberQ[ live, # ] & ];
];

sweepRenderCaches // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Live View*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpLiveView*)

(* Expression for the body of the active output cell (UI.wl wraps ToBoxes @ acpLiveView[ turnID ] in an
   AssistantMessageBoxActive template). The outer Dynamic tracks only the turn's layout symbol. *)
acpLiveView // beginDefinition;

acpLiveView[ id_String ] := (
    ensureHousekeeping[ ];
    acpTrackedDynamic[ acpLayoutSymbol @ id, liveLayout @ id ]
);

acpLiveView // endDefinition;


liveLayout // beginDefinition;
liveLayout[ id_String ] := Replace[ acpIsolated @ withRenderContext @ liveLayout0 @ id, Except[ _RawBoxes ] :> unavailableBoxes[ ] ];
liveLayout // endDefinition;


liveLayout0 // beginDefinition;

liveLayout0[ id_String ] := Module[ { turn, open, items },
    turn = acpTurnGet @ id;
    If[ ! AssociationQ @ turn, Return[ unavailableBoxes[ ], Module ] ];
    open  = acpOpenQ[ id, "Work", True ];
    items = If[ open, liveEntityItems[ id, turn ], { } ];
    RawBoxes @ Cell[
        TextData @ Riffle[ Prepend[ items, workingHeaderCell[ id, open ] ], "\n" ],
        "Text",
        Background -> None
    ]
];

liveLayout0 // endDefinition;


(* One inline cell per entity, each holding a Dynamic that tracks only that entity's symbol.
   Entities from subagent sessions get a "Subagent: title" header before the first one. *)
liveEntityItems // beginDefinition;

liveEntityItems[ id_String, turn_Association ] := Module[ { seen = { }, items = { }, child },
    Do[
        child = Lookup[ Replace[ turn[ "Entities", key ], Except[ _Association ] -> <| |> ], "Child", None ];
        If[ AssociationQ @ child && ! MemberQ[ seen, child[ "ID" ] ],
            AppendTo[ seen, child[ "ID" ] ];
            AppendTo[ items, subagentHeaderCell @ child ]
        ];
        AppendTo[ items, entityDynamicCell[ id, key ] ],
        { key, turn[ "Order" ] }
    ];
    items
];

liveEntityItems // endDefinition;


entityDynamicCell // beginDefinition;

entityDynamicCell[ id_String, key_ ] := With[ { sym = acpEntitySymbol[ id, key ] },
    textBoxCell @ ToBoxes @ acpTrackedDynamic[ sym, acpEntityView[ id, key ] ]
];

entityDynamicCell // endDefinition;


subagentHeaderCell // beginDefinition;

subagentHeaderCell[ child_Association ] := boxCell @ Style[
    acpLabel[ "SubagentHeader", <| "title" -> Replace[ child[ "Title" ], Except[ _String ] -> "" ] |> ],
    FontColor -> $labelColor,
    FontWeight -> "DemiBold",
    FontSize -> 13
];

subagentHeaderCell // endDefinition;


unavailableBoxes // beginDefinition;
unavailableBoxes[ ] := RawBoxes @ ToBoxes @ Style[ acpLabel[ "TurnUnavailable" ], "Text", FontColor -> $mutedColor, FontSlant -> Italic ];
unavailableBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Working header*)

(* Kernel-built opener header: chevron, "Working - 1m 05s - <activity>", and an FE-animated progress glyph. The label
   is its own small Dynamic tracking the turn's "Clock" symbol (bumped once a second by housekeeping), so updating it
   never rebuilds entity views. *)
workingHeaderCell // beginDefinition;

workingHeaderCell[ id_String, open_ ] := boxCell @ workingHeader[ id, open ];

workingHeaderCell // endDefinition;


workingHeader // beginDefinition;

workingHeader[ id_String, open_ ] := With[ { sym = acpEntitySymbol[ id, "Clock" ] },
    toggleHandler[
        Grid[
            {
                {
                    acpTrackedDynamic[ sym, workingLabel @ id ],
                    Style[ If[ TrueQ @ open, "\:f443", "\:f442" ], FontColor -> $labelColor ],
                    chatbookIcon[ "PercolateProgressAnimation", False ]
                }
            },
            Alignment        -> { Left, Baseline },
            BaselinePosition -> { 1, 1 },
            Spacings         -> { 0.4, 0 },
            BaseStyle        -> { FontColor -> $labelColor, FontFamily -> "Source Sans Pro", FontSize -> 13.5 }
        ],
        id,
        "Work",
        True
    ]
];

workingHeader // endDefinition;


workingLabel // beginDefinition;

workingLabel[ id_String ] := Replace[
    acpIsolated @ withRenderContext @ Module[ { turn, now },
        turn = acpTurnGet @ id;
        now  = AbsoluteTime[ ];
        If[ ! AssociationQ @ turn,
            RawBoxes @ ToBoxes @ Style[ acpLabel[ "Working" ], FontSlant -> Italic ],
            RawBoxes @ ToBoxes @ Row @ Flatten @ {
                Style[ acpLabel[ "Working" ], FontSlant -> Italic ],
                " \[CenterDot] ",
                acpFormatDuration[ now - turn[ "StartTime" ] ],
                " \[CenterDot] ",
                titleView @ acpTurnActivityLabel[ turn, now ]
            }
        ]
    ],
    Except[ _RawBoxes ] :> RawBoxes[ "" ]
];

workingLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toggleHandler*)

(* Preemptive click handler that toggles the kernel-side open state of { turnID, key }: *)
toggleHandler // beginDefinition;

toggleHandler[ expr_, id_String, key_, default_ ] := With[ { k = key, d = TrueQ @ default },
    MouseAppearance[
        EventHandler[
            expr,
            { "MouseClicked" :> acpIsolated @ ChatbookAction[ "ACP", "ToggleOpen", id, k, d ] },
            Method         -> "Preemptive",
            PassEventsDown -> Automatic,
            PassEventsUp   -> True
        ],
        "LinkHand"
    ]
];

toggleHandler // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Entity Views*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpEntityView*)

(* Boxes for one entity of a running turn. Cached per { turnID, key } and only re-rendered when the entity's version,
   its open state, or its "active" state (e.g. the last thought while the turn runs) changes. *)
acpEntityView // beginDefinition;

acpEntityView[ id_String, key_ ] := Replace[
    acpIsolated @ withRenderContext @ entityView0[ id, key ],
    Except[ _RawBoxes ] :> RawBoxes[ "" ]
];

acpEntityView // endDefinition;


entityView0 // beginDefinition;

entityView0[ id_String, key_ ] := Module[ { turn, entity, signature, cached, boxes },
    turn = acpTurnGet @ id;
    If[ ! AssociationQ @ turn, Return[ unavailableBoxes[ ], Module ] ];
    entity = Lookup[ turn[ "Entities" ], Key @ key, Missing[ ] ];
    If[ ! AssociationQ @ entity, Return[ RawBoxes[ "" ], Module ] ];
    signature = entitySignature[ id, key, entity, turn ];
    cached = Lookup[ $renderCache, Key @ { id, key }, None ];
    If[ MatchQ[ cached, { signature, _ } ], Return[ RawBoxes @ Last @ cached, Module ] ];
    boxes = Block[ { $renderMode = "Live", $turnID = id }, activateCodeBlocks @ renderEntity[ entity, key, turn ] ];
    $renderCache[ { id, key } ] = { signature, boxes };
    RawBoxes @ boxes
];

entityView0 // endDefinition;


entitySignature // beginDefinition;

entitySignature[ id_String, key_, entity_Association, turn_Association ] := {
    Lookup[ entity, "Version", 0 ],
    KeySelect[ $acpOpen, MatchQ[ { id, Join[ key, { ___ } ] } ] ],
    activeEntityQ[ key, turn ],
    Lookup[ turn, "ClientCancel", None ]
};

entitySignature // endDefinition;


activeEntityQ // beginDefinition;
activeEntityQ[ key_, turn_Association ] := runningTurnQ @ turn && ! acpTurnEndedQ @ turn && turn[ "Order" ] =!= { } && Last @ turn[ "Order" ] === key;
activeEntityQ // endDefinition;


$renderMode = "Live";
$turnID     = None;


(* Live views show code blocks with the "Active" templates (no scroll pane capturing the mouse wheel, no buttons): *)
activateCodeBlocks // beginDefinition;
activateCodeBlocks[ boxes_ ] := ReplaceAll[
    boxes,
    TemplateBox[ args_, name: "ChatCodeBlockTemplate" | "NotebookAssistant`Sidebar`ChatCodeBlockTemplate", opts___ ] :>
        TemplateBox[ args, name <> "Active", opts ]
];
activateCodeBlocks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*renderEntity*)

(* Returns an inline Cell (boxes) for an entity in the current $renderMode ("Live" or "Final"). *)
renderEntity // beginDefinition;

renderEntity[ entity: KeyValuePattern[ "Type" -> "Message"    ], key_, _     ] := messageCell[ entity, key ];
renderEntity[ entity: KeyValuePattern[ "Type" -> "Thought"    ], key_, turn_ ] := thoughtCell[ entity, key, turn ];
renderEntity[ entity: KeyValuePattern[ "Type" -> "Tool"       ], key_, turn_ ] := toolCardCell[ entity, key, turn, Automatic ];
renderEntity[ entity: KeyValuePattern[ "Type" -> "Permission" ], _   , turn_ ] := permissionEntityCell[ entity, turn ];
renderEntity[ entity: KeyValuePattern[ "Type" -> "Notice"     ], _   , _     ] := noticeCell @ entity;
renderEntity[ entity: KeyValuePattern[ "Type" -> "Plan"       ], _   , _     ] := planCell @ entity;
renderEntity[ _, _, _ ] := "";

renderEntity // endDefinition;


(* Every inline cell created here goes through boxCell/textBoxCell (BoxData) or has the "Text" style (TextData).
   Inline BoxData cells inside a ChatOutput cell would otherwise show strings in the code font; a cell style is not
   enough, the boxes themselves need a "Text" StyleBox (verified in a front end). Cells made by Chatbook's formatter
   (code blocks, inline code, thoughts openers) keep their own styles. *)
boxCell // beginDefinition;
boxCell[ expr_ ] := Cell[ BoxData @ ToBoxes @ Style[ expr, "Text" ], "Text", Background -> None ];
boxCell // endDefinition;

textBoxCell // beginDefinition;
textBoxCell[ boxes_ ] := Cell[ BoxData @ StyleBox[ boxes, "Text" ], "Text", Background -> None ];
textBoxCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Text Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*messageCell*)
messageCell // beginDefinition;

messageCell[ entity_Association, key_ ] := Cell[
    TextData @ Join[
        markdownItems[ entity[ "Text" ], key ],
        blockItems @ Lookup[ entity, "Blocks", { } ]
    ],
    "Text",
    Background -> None
];

messageCell // endDefinition;


(* Formats markdown text for the current render mode. Live: tail-only streaming formatting; Final: finished. *)
markdownItems // beginDefinition;

markdownItems[ text_String, key_ ] /; $renderMode === "Live" := streamingItems[ $turnID, key, text ];
markdownItems[ text_String, _ ] := finishedItems @ text;
markdownItems[ _, _ ] := { };

markdownItems // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Streaming (tail-only) formatting*)

(* The text is split at the last blank line outside an open code fence. The stable prefix is formatted once (new parts
   are formatted incrementally and cached by length); only the tail is re-formatted on each update. *)
streamingItems // beginDefinition;

streamingItems[ id_, key_, text0_String ] := Module[ { text, split, prefix, tail, cache, items, newPart },
    text   = acpPreprocessAnswer @ text0;
    split  = stableSplitPosition @ text;
    prefix = StringTake[ text, split ];
    tail   = StringDrop[ text, split ];
    cache  = Lookup[ $textCache, Key @ { id, key }, <| "Length" -> 0, "Hash" -> Hash[ "" ], "Items" -> { } |> ];

    (* The prefix only grows while text is appended; anything else invalidates the cache: *)
    If[ cache[ "Length" ] > StringLength @ prefix || Hash @ StringTake[ prefix, cache[ "Length" ] ] =!= cache[ "Hash" ],
        cache = <| "Length" -> 0, "Hash" -> Hash[ "" ], "Items" -> { } |>
    ];

    If[ StringLength @ prefix > cache[ "Length" ],
        newPart = StringDrop[ prefix, cache[ "Length" ] ];
        items = joinItems[ cache[ "Items" ], formatStreaming[ id, newPart, True ] ];
        cache = <| "Length" -> StringLength @ prefix, "Hash" -> Hash @ prefix, "Items" -> items |>;
        If[ StringQ @ id, $textCache[ { id, key } ] = cache ]
    ];

    joinItems[ cache[ "Items" ], formatStreaming[ id, tail, False ] ]
];

streamingItems // endDefinition;


(* Position after the last blank line ("\n\n") that is not inside an open code fence (0 if none): *)
stableSplitPosition // beginDefinition;

stableSplitPosition[ text_String ] := Module[ { fences, blanks },
    blanks = StringPosition[ text, "\n\n" ][[ All, 2 ]];
    If[ blanks === { }, Return[ 0, Module ] ];
    fences = StringPosition[ text, StartOfLine ~~ (" "|"\t")... ~~ ("```"|"~~~") ][[ All, 1 ]];
    SelectFirst[ Reverse @ blanks, EvenQ @ Count[ fences, f_ /; f < # ] &, 0 ]
];

stableSplitPosition // endDefinition;


formatStreaming // beginDefinition;

formatStreaming[ _, text_String, _ ] /; StringTrim @ text === "" := { };

formatStreaming[ id_, text_String, useCache_ ] := Module[ { cache, items },
    cache = If[ TrueQ @ useCache && StringQ @ id, Lookup[ $turnResultCellCache, id, <| |> ], <| |> ];
    Block[ { $dynamicText = True, $resultCellCache = cache },
        items = textDataItems @ FormatChatOutput[ text, <| "Status" -> "Streaming" |> ];
        If[ TrueQ @ useCache && StringQ @ id, $turnResultCellCache[ id ] = $resultCellCache ]
    ];
    items
];

formatStreaming // endDefinition;


(* Finished formatting needs a front end for Wolfram Language code; without one (or if it fails), use the streaming
   formatter, which makes no front end calls. *)
finishedItems // beginDefinition;

finishedItems[ text0_String ] := Module[ { text, items },
    text = acpPreprocessAnswer @ text0;
    If[ StringTrim @ text === "", Return[ { }, Module ] ];
    items = If[ frontEndFormattingQ[ ],
        acpCatchAll[
            Block[ { $dynamicText = False, $resultCellCache = <| |> },
                textDataItems @ FormatChatOutput[ text, <| "Status" -> "Finished" |> ]
            ]
        ],
        None
    ];
    Which[
        ListQ @ items && FreeQ[ items, _Failure | $Failed ],
            items,
        items === None,
            formatStreaming[ None, text, False ],
        True,
            (* Front end formatting was attempted and failed (tests check this log entry): *)
            acpLog[ "FinishedFormattingFallback", <| "TurnID" -> $turnID, "Result" -> Short[ items, 3 ] |> ];
            formatStreaming[ None, text, False ]
    ]
];

finishedItems // endDefinition;


frontEndFormattingQ // beginDefinition;
frontEndFormattingQ[ ] := ! TrueQ @ $acpNoFrontEndFormatting && ($FrontEnd =!= Null || TrueQ @ $CloudEvaluation);
frontEndFormattingQ // endDefinition;

$acpNoFrontEndFormatting = False;


textDataItems // beginDefinition;
textDataItems[ RawBoxes[ Cell[ TextData[ items_List ], ___ ] ] ] := items;
textDataItems[ RawBoxes[ Cell[ TextData[ item_ ], ___ ] ] ] := { item };
textDataItems[ RawBoxes[ Cell[ s_String, ___ ] ] ] := { s };
textDataItems[ RawBoxes[ boxes_ ] ] := { textBoxCell @ boxes };
textDataItems[ s_String ] := { s };
textDataItems[ other_ ] := { boxCell @ other };
textDataItems // endDefinition;


(* Joins two lists of TextData items that came from separately formatted blocks (the formatter trims the blank line
   between them): *)
joinItems // beginDefinition;

joinItems[ { }, b_List ] := b;
joinItems[ a_List, { } ] := a;
joinItems[ a_List, b_List ] := Join[ a, { If[ blockItemQ @ Last @ a, "\n", "\n\n" ] }, b ];

joinItems // endDefinition;


blockItemQ // beginDefinition;
blockItemQ[ Cell[ __, "ChatCodeBlock" | "InlineSection" | "InlineItem" | "InlineSubitem" | "TextTableForm" | "BlockQuote" | "MarkdownDelimiter" | "ThoughtsOpener" | "ThinkingOpener", ___ ] ] := True;
blockItemQ[ s_String ] := StringEndsQ[ s, "\n" ];
blockItemQ[ _ ] := False;
blockItemQ // endDefinition;


(* Non-text content blocks of messages (images, resource links): *)
blockItems // beginDefinition;
blockItems[ { } ] := { };
blockItems[ blocks_List ] := Flatten @ Map[ { "\n", boxCell @ contentBlockView @ # } &, blocks ];
blockItems // endDefinition;


contentBlockView // beginDefinition;

contentBlockView[ block: KeyValuePattern[ "type" -> "image" ] ] := imageView @ block;

contentBlockView[ block: KeyValuePattern @ { "type" -> "resource_link", "uri" -> uri_String } ] :=
    Hyperlink[ Replace[ Lookup[ block, "name", uri ], Except[ _String ] -> uri ], uri ];

contentBlockView[ KeyValuePattern @ { "type" -> "resource", "resource" -> KeyValuePattern[ "text" -> text_String ] } ] :=
    RawBoxes @ codeBlock[ text, "text" ];

contentBlockView[ block_ ] := Style[ "[" <> ToString @ Lookup[ Replace[ block, Except[ _Association ] -> <| |> ], "type", "content" ] <> "]", FontColor -> $mutedColor ];

contentBlockView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeBlock*)

(* Chatbook code block cell (ChatCodeBlockTemplate) for text or code. Wolfram Language code gets Chatbook's own code
   formatting; finished WL formatting needs a front end, otherwise the streaming form is used. *)
codeBlock // beginDefinition;

(* The permission panel lives in the attached input cell, outside of any ChatOutput cell, where Chatbook's code block
   templates (and their Copy/Insert buttons) don't work: *)
codeBlock[ code_String, _String ] /; TrueQ @ $plainCodeBlocks := plainCodeBoxes @ code;

codeBlock[ code_String, lang_String ] := Module[ { finished, cell },
    finished = $renderMode === "Final" && (! wolframLanguageQ @ lang || frontEndFormattingQ[ ]);
    cell = If[ finished,
        Catch[ Block[ { $dynamicText = False }, makeInteractiveCodeCell[ lang, code ] ], _, $Failed & ],
        $Failed
    ];
    If[ MatchQ[ cell, _Cell ],
        cell,
        Block[ { $dynamicText = True }, makeInteractiveCodeCell[ lang, code ] ]
    ]
];

codeBlock // endDefinition;


$plainCodeBlocks = False;


plainCodeBoxes // beginDefinition;

plainCodeBoxes[ code_String ] := ToBoxes @ Framed[
    Style[
        code,
        FontFamily         -> $codeFont,
        FontSize           -> 12,
        LineBreakWithin    -> Automatic,
        ShowStringCharacters -> False,
        PrivateFontOptions -> { "OperatorSubstitution" -> False }
    ],
    Background     -> LightDarkSwitched[ GrayLevel[ 0.98 ], GrayLevel[ 0.13 ] ],
    FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], $cardFrame ],
    FrameMargins   -> { { 8, 8 }, { 5, 5 } },
    ImageSize      -> Full,
    RoundingRadius -> 4
];

plainCodeBoxes // endDefinition;


wolframLanguageQ // beginDefinition;
wolframLanguageQ[ lang_String ] := MemberQ[ { "wolfram", "wl", "mathematica", "wolfram language" }, ToLowerCase @ lang ];
wolframLanguageQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Thoughts*)
thoughtCell // beginDefinition;

thoughtCell[ entity_Association, _, _ ] /; $renderMode === "Final" := thoughtsOpenerCell @ entity;

thoughtCell[ entity_Association, key_, turn_ ] := Module[ { id, active, open, label, header, body },
    id     = $turnID;
    active = activeEntityQ[ key, turn ];
    open   = acpOpenQ[ id, key, False ];
    label  = If[ active, acpLabel[ "Thinking" ], thoughtLabel @ entity ];
    header = toggleHandler[
        Grid[
            { { Style[ label, FontSlant -> Italic ], If[ TrueQ @ open, "\:f443", "\:f442" ] } },
            Alignment -> { Left, Baseline },
            Spacings  -> { 0.3, 0 },
            BaseStyle -> { FontColor -> $labelColor, FontFamily -> "Source Sans Pro", FontSize -> 13.5 }
        ],
        id,
        key,
        False
    ];
    body = If[ TrueQ @ open && StringTrim @ entity[ "Text" ] =!= "",
        textBoxCell @ TemplateBox[ { TextData @ markdownItems[ entity[ "Text" ], key ] }, "ThinkingContent" ],
        None
    ];
    textBoxCell @ If[ body === None,
        ToBoxes @ header,
        GridBox[ { { ToBoxes @ header }, { body } }, GridBoxAlignment -> { "Columns" -> { { Left } } }, GridBoxSpacings -> { "Rows" -> { { 0.5 } } } ]
    ]
];

thoughtCell // endDefinition;


(* Static thoughts opener for the final cell, using Chatbook's ThoughtsOpener template: *)
thoughtsOpenerCell // beginDefinition;

thoughtsOpenerCell[ entity_Association ] :=
    Cell[
        BoxData @ TemplateBox[
            { TextData @ finishedItems @ entity[ "Text" ], ToBoxes @ thoughtLabel @ entity, <| "Type" -> "Literal" |> },
            If[ StringTrim @ entity[ "Text" ] === "", "EmptyThoughts", "ThoughtsOpener" ]
        ],
        "ThoughtsOpener",
        Background -> None
    ];

thoughtsOpenerCell // endDefinition;


thoughtLabel // beginDefinition;

thoughtLabel[ entity_Association ] := Module[ { secs },
    secs = Lookup[ entity, "LastTime", 0 ] - Lookup[ entity, "FirstTime", 0 ];
    Which[
        ! NumberQ @ secs, acpLabel[ "Thought" ],
        Round @ secs <= 1, acpLabel[ "ThoughtForOneSecond" ],
        True, acpLabel[ "ThoughtForSeconds", <| "n" -> Round @ secs |> ]
    ]
];

thoughtLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Cards*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolCardCell*)

(* open: Automatic (live: $acpOpen state, closed by default; final: closed), True or False *)
toolCardCell // beginDefinition;

toolCardCell[ tool_Association, key_, turn_, open_ ] := boxCell @ toolCard[ tool, key, turn, open ];

toolCardCell // endDefinition;


toolCard // beginDefinition;

toolCard[ tool_Association, key_, turn_, open0_ ] /; $renderMode === "Final" :=
    staticOpener[ toolHeader[ tool, turn ], RawBoxes @ ToBoxes @ toolBody[ tool, key, turn ], TrueQ @ open0, cardStyle @ tool ];

toolCard[ tool_Association, key_, turn_, open0_ ] := Module[ { open, header },
    open   = If[ BooleanQ @ open0, open0, acpOpenQ[ $turnID, key, False ] ];
    header = toggleHandler[ Grid[ { { toolHeader[ tool, turn ], openerIcon @ open } }, $headerGridOptions ], $turnID, key, False ];
    Framed[
        If[ TrueQ @ open,
            Grid[ { { header }, { toolBody[ tool, key, turn ] } }, Alignment -> { Left, Top }, Spacings -> { 0, 0.6 } ],
            header
        ],
        cardFrameOptions @ cardStyle @ tool
    ]
];

toolCard // endDefinition;


$headerGridOptions := Sequence[
    Alignment        -> { Left, Baseline },
    BaselinePosition -> { 1, 1 },
    Spacings         -> { 0.4, 0 }
];


cardStyle // beginDefinition;
cardStyle[ tool_Association ] := If[ awaitingApprovalQ @ tool, "Awaiting", "Default" ];
cardStyle // endDefinition;


cardFrameOptions // beginDefinition;

cardFrameOptions[ style_ ] := Sequence[
    Background     -> If[ style === "Awaiting", $amberBackground, $cardBackground ],
    FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], If[ style === "Awaiting", $amberFrame, $cardFrame ] ],
    FrameMargins   -> { { 6, 6 }, { 3, 3 } },
    ImageMargins   -> { { 0, 0 }, { 4, 4 } },
    RoundingRadius -> 6,
    BaseStyle      -> { "Text", FontSize -> 13, LineBreakWithin -> Automatic }
];

cardFrameOptions // endDefinition;


openerIcon // beginDefinition;
openerIcon[ open_ ] := RawBoxes @ TemplateBox[ { $toolLabelColor }, If[ TrueQ @ open, "DiscardedMaterialCloserIcon", "DiscardedMaterialOpenerIcon" ] ];
openerIcon // endDefinition;


awaitingApprovalQ // beginDefinition;
awaitingApprovalQ[ KeyValuePattern[ "Permission" -> KeyValuePattern[ "Outcome" -> None ] ] ] := True;
awaitingApprovalQ[ KeyValuePattern @ { "Type" -> "Permission", "Outcome" -> None } ] := True;
awaitingApprovalQ[ _ ] := False;
awaitingApprovalQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*staticOpener*)

(* Front-end-only opener for the static final cell (state in a DynamicModule variable, toggled without the kernel). *)
staticOpener // beginDefinition;

staticOpener[ header_, body_, open_, style_ ] := With[
    {
        h          = header,
        b          = body,
        init       = TrueQ @ open,
        iconOpen   = openerIcon @ True,
        iconClosed = openerIcon @ False,
        frame      = cardFrameOptions @ style
    },
    (* The header and body boxes appear only once (the open state only switches the icon and shows/hides the body): *)
    DynamicModule[ { Typeset`open = init },
        Framed[
            Column[
                {
                    MouseAppearance[
                        EventHandler[
                            Grid[
                                {
                                    {
                                        h,
                                        PaneSelector[
                                            { True -> iconOpen, False -> iconClosed },
                                            Dynamic @ Typeset`open,
                                            ImageSize        -> Automatic,
                                            BaselinePosition -> Baseline
                                        ]
                                    }
                                },
                                $headerGridOptions
                            ],
                            { "MouseDown" :> FEPrivate`Set[ Typeset`open, Not[ Typeset`open ] ] },
                            Method -> "Preemptive", PassEventsDown -> Automatic, PassEventsUp -> True
                        ],
                        "LinkHand"
                    ],
                    PaneSelector[
                        (* Spacer[{0,0}] rather than "": an empty string still takes up a line of height *)
                        { True -> Pane[ b, ImageMargins -> { { 0, 0 }, { 0, 6 } } ], False -> Spacer[ { 0, 0 } ] },
                        Dynamic @ Typeset`open,
                        ImageSize -> Automatic
                    ]
                },
                Alignment -> Left,
                Spacings  -> 0
            ],
            frame
        ],
        DynamicModuleValues :> { }
    ]
];

staticOpener // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolHeader*)

(* icon, title, one-line summary, permission badge and status glyph *)
toolHeader // beginDefinition;

toolHeader[ tool_Association, turn_ ] := Module[ { title, summary, exitQ },
    title   = acpToolTitle[ tool, Automatic, turn ];
    summary = acpToolSummary @ tool;
    exitQ   = IntegerQ @ tool[ "ExitCode" ] && tool[ "ExitCode" ] =!= 0 && tool[ "ClientOutcome" ] === None;
    Grid[
        {
            Flatten @ {
                iconPane @ toolIcon @ tool,
                Style[ titleView @ title, FontColor -> $toolLabelColor ],
                If[ summary === "", Nothing, Style[ summary, FontColor -> If[ exitQ, $amberText, $mutedColor ], FontSize -> 12 ] ],
                badgeView @ tool,
                statusGlyph @ tool
            }
        },
        $headerGridOptions
    ]
];

toolHeader // endDefinition;


(* Splits backtick-delimited code spans out of a title: *)
titleView // beginDefinition;

(* Code spans are always upright: an italic status line would otherwise render them with a substitute font *)
titleView[ title_String ] := Row @ StringSplit[
    title,
    "`" ~~ code: Except[ "`" ].. ~~ "`" :> Style[ code, FontFamily -> $codeFont, FontSize -> 12, FontSlant -> Plain ]
];

titleView[ other_ ] := other;

titleView // endDefinition;


iconPane // beginDefinition;
iconPane[ icon_ ] := Pane[ icon, ImageSize -> { 16, 16 }, ImageSizeAction -> "ShrinkToFit", BaselinePosition -> Scaled[ 0.2 ], ContentPadding -> False ];
iconPane // endDefinition;


toolIcon // beginDefinition;

toolIcon[ tool_Association ] := Module[ { name, kind, names },
    name = tool[ "Name" ];
    kind = tool[ "Kind" ];
    Which[
        name === "execute",
            names = acpExecuteToolNames @ tool;
            Which[
                MemberQ[ names, "Wolfram Language Evaluator" ], chatbookIcon[ "ToolIconWolframLanguageEvaluator", False ],
                MemberQ[ names, "Wolfram|Alpha" | "Wolfram|Alpha Context" ], chatbookIcon[ "ToolIconWolframAlpha", False ],
                names =!= { } && AllTrue[ names, StringContainsQ[ #, "Context" | "Documentation" ] & ], RawBoxes @ TemplateBox[ { }, "ToolIconDocumentationSearcher" ],
                True, chatbookIcon[ "WrenchIcon", False ]
            ],
        MatchQ[ name, "read" | "list" ] || (name === None && kind === "read"),
            RawBoxes @ TemplateBox[ { }, "ToolIconFileReader" ],
        MatchQ[ name, "edit" | "write" | "patch" | "multiedit" ] || (name === None && MatchQ[ kind, "edit" | "delete" | "move" ]),
            $editIcon,
        name === "shell" || (name === None && kind === "execute"),
            chatbookIcon[ "ExternalLanguageIconShell", False ],
        MatchQ[ name, "glob" | "grep" | "codesearch" | "models" ] || (name === None && kind === "search"),
            RawBoxes @ TemplateBox[ { }, "ToolIconDocumentationSearcher" ],
        name === "webfetch" || (name === None && kind === "fetch"),
            RawBoxes @ TemplateBox[ { }, "ToolIconWebFetcher" ],
        name === "websearch",
            RawBoxes @ TemplateBox[ { }, "ToolIconWebSearcher" ],
        name === "skill",
            chatbookIcon[ "ToolIconDocumentationLookup", False ],
        name === "question",
            glyphIcon[ "?" ],
        MatchQ[ name, "todowrite" | "todoread" ],
            glyphIcon[ "\:2611" ],
        name === "subagent",
            glyphIcon[ "\:21b3" ],
        name === "lsp",
            glyphIcon[ "{ }" ],
        name === "invalid",
            glyphIcon[ "\:26a0" ],
        StringQ @ name && StringContainsQ[ name, "WolframLanguageEvaluator" ],
            chatbookIcon[ "ToolIconWolframLanguageEvaluator", False ],
        StringQ @ name && StringContainsQ[ name, "WolframAlpha" ],
            chatbookIcon[ "ToolIconWolframAlpha", False ],
        True,
            chatbookIcon[ "WrenchIcon", False ]
    ]
];

toolIcon // endDefinition;


(* A character in the tool label color, for tools Chatbook has no icon for: *)
glyphIcon // beginDefinition;
glyphIcon[ glyph_String ] := Style[ glyph, FontColor -> $toolLabelColor, FontSize -> 13, FontWeight -> Bold, FontFamily -> "Source Sans Pro" ];
glyphIcon // endDefinition;


(* Small pencil glyph (Chatbook has no edit icon): *)
$editIcon := Graphics[
    {
        $toolLabelColor,
        CapForm[ "Round" ],
        AbsoluteThickness[ 2.2 ],
        Line @ { { 0.3, 0.3 }, { 0.85, 0.85 } },
        Polygon @ { { 0.1, 0.1 }, { 0.32, 0.2 }, { 0.2, 0.32 } }
    },
    ImageSize -> { 14, 14 },
    PlotRange -> { { 0, 1 }, { 0, 1 } }
];


badgeView // beginDefinition;

badgeView[ tool_Association ] := Module[ { outcome },
    outcome = Replace[ tool[ "Permission" ], { KeyValuePattern[ "Outcome" -> o_ ] :> o, _ -> None } ];
    Which[
        tool[ "ClientOutcome" ] === "Declined", badge[ acpLabel[ "BadgeDeclined" ], "Neutral" ],
        tool[ "ClientOutcome" ] === "Stopped" , badge[ acpLabel[ "BadgeStopped"  ], "Neutral" ],
        awaitingApprovalQ @ tool              , badge[ acpLabel[ "BadgeAwaitingApproval" ], "Amber" ],
        outcome === "once"                    , badge[ acpLabel[ "BadgeAllowedOnce" ], "Neutral" ],
        outcome === "always"                  , badge[ acpLabel[ "BadgeAllowedAlways" ], "Neutral" ],
        True                                  , Nothing
    ]
];

badgeView // endDefinition;


(* style: "Amber" | "Red" | "Green" | anything else (neutral) *)
badge // beginDefinition;

badge[ text_String, style_String ] := Framed[
    Style[ text, FontSize -> 11, FontColor -> Switch[ style, "Amber", $amberText, "Red", $redText, "Green", $greenText, _, $mutedColor ] ],
    Background     -> Switch[ style, "Amber", $amberBackground, "Red", $errorBackground, "Green", $addedBackground, _, $badgeBackground ],
    FrameStyle     -> Switch[ style, "Amber", $amberFrame, "Red", $errorFrame, _, None ],
    FrameMargins   -> { { 4, 4 }, { 0, 1 } },
    RoundingRadius -> 3,
    BaselinePosition -> Baseline
];

badge // endDefinition;

(* The badge for other files (Review.wl) *)
acpBadge // beginDefinition;
acpBadge[ text_String, style_String ] := badge[ text, style ];
acpBadge // endDefinition;


statusGlyph // beginDefinition;

statusGlyph[ tool_Association ] := Which[
    tool[ "ClientOutcome" ] =!= None,
        Nothing,
    awaitingApprovalQ @ tool,
        Nothing,
    MatchQ[ tool[ "Status" ], "pending" | "in_progress" ],
        If[ $renderMode === "Final", Nothing, chatbookIcon[ "PercolateProgressAnimation", False ] ],
    tool[ "Status" ] === "failed",
        Style[ "\:2717", FontColor -> $redText, FontWeight -> Bold ],
    tool[ "Status" ] === "completed" && IntegerQ @ tool[ "ExitCode" ] && tool[ "ExitCode" ] =!= 0,
        Nothing, (* the amber "exit n" summary says it all *)
    tool[ "Status" ] === "completed",
        Style[ "\:2713", FontColor -> $greenText, FontWeight -> Bold ],
    True,
        Nothing
];

statusGlyph // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolBody*)

(* Sections shown when a tool card is open: Input, Changes (diffs), Output, Details (collapsed). *)
toolBody // beginDefinition;

toolBody[ tool_Association, key_, turn_ ] := Module[ { sections },
    sections = DeleteCases[
        {
            inputSection[ tool, key ],
            changesSection[ tool, turn ],
            outputSection @ tool,
            detailsSection[ tool, key ]
        },
        None
    ];
    If[ sections === { },
        Style[ acpLabel[ "SummaryNoOutput" ], FontColor -> $mutedColor ],
        Grid[ List /@ sections, Alignment -> { Left, Top }, Spacings -> { 0, 0.8 } ]
    ]
];

toolBody // endDefinition;


section // beginDefinition;
section[ labelKey_String, content_ ] := Column[
    { Style[ acpLabel[ labelKey ], FontSize -> 11, FontWeight -> "DemiBold", FontColor -> $sectionLabelColor ], content },
    Spacings -> 0.3
];
section // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Input*)
inputSection // beginDefinition;

inputSection[ tool_Association, key_ ] := Module[ { name, input },
    name  = tool[ "Name" ];
    input = tool[ "RawInput" ];
    Which[
        name === "shell" || (name === None && tool[ "Kind" ] === "execute" && StringQ @ Lookup[ Replace[ input, Except[ _Association ] -> <| |> ], "command", None ]),
            Replace[
                Lookup[ Replace[ input, Except[ _Association ] -> <| |> ], { "command", "cmd" }, None ],
                {
                    { c_String, _ } | { _, c_String } :> section[ "SectionInput", RawBoxes @ codeBlock[ truncateHead[ c, codeLineLimit[ ] ], "text" ] ],
                    _ :> None
                }
            ],
        MatchQ[ name, "edit" | "write" | "patch" | "multiedit" ] && tool[ "Diffs" ] =!= { },
            None, (* the Changes section shows the diffs *)
        name === "execute",
            executeInputSection[ tool, key ],
        name === "subagent",
            subagentInputSection @ input,
        AssociationQ @ input && Length @ input > 0,
            section[ "SectionInput", rawInputGrid @ input ],
        True,
            None
    ]
];

inputSection // endDefinition;


codeLineLimit // beginDefinition;
codeLineLimit[ ] := If[ $renderMode === "Final", 4 * $liveCodeLines, $liveCodeLines ];
codeLineLimit // endDefinition;


rawInputGrid // beginDefinition;

rawInputGrid[ input_Association ] := Grid[
    KeyValueMap[
        { Style[ #1, FontColor -> $mutedColor, FontSize -> 12 ], inputValueView @ #2 } &,
        input
    ],
    Alignment -> { Left, Top },
    Spacings  -> { 1, 0.4 }
];

rawInputGrid // endDefinition;


inputValueView // beginDefinition;
inputValueView[ s_String ] /; StringContainsQ[ s, "\n" ] || StringLength @ s > 80 := RawBoxes @ codeBlock[ truncateHead[ s, codeLineLimit[ ] ], "text" ];
inputValueView[ s_String ] := Style[ s, FontFamily -> $codeFont, FontSize -> 12 ];
inputValueView[ other_ ] := Style[ shortJSON @ other, FontFamily -> $codeFont, FontSize -> 12 ];
inputValueView // endDefinition;


subagentInputSection // beginDefinition;
subagentInputSection[ input_Association ] := With[ { prompt = Lookup[ input, "prompt", None ] },
    If[ StringQ @ prompt,
        section[ "SectionInput", RawBoxes @ Cell[ TextData @ markdownItems[ truncateHead[ prompt, codeLineLimit[ ] ], { "SubagentPrompt" } ], "Text", Background -> None ] ],
        section[ "SectionInput", rawInputGrid @ input ]
    ]
];
subagentInputSection[ _ ] := None;
subagentInputSection // endDefinition;


(* MCP code mode: each inner Wolfram Language call is shown with Chatbook's WL code formatting; the JavaScript is in a
   collapsed "Script" section. *)
executeInputSection // beginDefinition;

executeInputSection[ tool_Association, key_ ] := Module[ { calls, views, script },
    calls  = acpExecuteToolCalls @ tool;
    views  = executeCallView /@ calls;
    script = Replace[ Lookup[ Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ], "code", None ], Except[ _String ] -> None ];
    If[ views === { } && script === None, Return[ None, Module ] ];
    section[
        "SectionInput",
        Column[
            Join[
                views,
                If[ StringQ @ script,
                    { subOpener[ key, "Script", "SectionScript", RawBoxes @ codeBlock[ truncateHead[ StringTrim @ script, codeLineLimit[ ] ], "text" ] ] },
                    { }
                ]
            ],
            Spacings -> 0.5
        ]
    ]
];

executeInputSection // endDefinition;


executeCallView // beginDefinition;

executeCallView[ call_Association ] := Module[ { name, code },
    name = First @ acpExecuteToolNames @ <| "RawOutput" -> <| "metadata" -> <| "toolCalls" -> { <| "tool" -> call[ "Tool" ] |> } |> |> |>;
    code = call[ "Code" ];
    Column[
        {
            Style[ name, FontColor -> $mutedColor, FontSize -> 12 ],
            If[ StringQ @ code,
                RawBoxes @ codeBlock[ truncateHead[ code, codeLineLimit[ ] ], If[ StringContainsQ[ call[ "Tool" ], "Wolfram" ], "Wolfram", "text" ] ],
                If[ AssociationQ @ call[ "Input" ], rawInputGrid @ call[ "Input" ], Nothing ]
            ]
        },
        Spacings -> 0.2
    ]
];

executeCallView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Changes*)
changesSection // beginDefinition;

changesSection[ tool_Association, turn_ ] := If[ tool[ "Diffs" ] === { },
    None,
    section[
        "SectionChanges",
        Column[
            acpDiffView[
                #,
                <|
                    "MaxLines"         -> If[ $renderMode === "Final", $finalDiffLines, $liveDiffLines ],
                    "ProjectDirectory" -> Lookup[ Replace[ turn, Except[ _Association ] -> <| |> ], "ProjectDirectory", None ]
                |>
            ] & /@ tool[ "Diffs" ],
            Spacings -> 0.6
        ]
    ]
];

changesSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Output*)
outputSection // beginDefinition;

outputSection[ tool_Association ] := Module[ { name, texts, images, views, failed, limit },
    name   = tool[ "Name" ];
    failed = tool[ "Status" ] === "failed";
    texts  = Select[ acpStripToolOutput /@ toolTexts @ tool, StringTrim[ # ] =!= "" & ];
    images = toolImages @ tool;
    limit  = If[ $renderMode === "Final", $finalOutputLines, $liveOutputLines ];

    (* File edits: the success text ("Created file successfully: ...") is only shown in Details *)
    If[ MatchQ[ name, "edit" | "write" | "patch" | "multiedit" ] && ! failed, texts = { } ];
    (* Declined/stopped calls: "The user declined this tool call", "Tool execution interrupted", ... only repeat the badge *)
    If[ tool[ "ClientOutcome" ] =!= None, texts = DeleteCases[ texts, _? acpClientInterruptionTextQ ] ];
    If[ texts === { } && images === { }, Return[ None, Module ] ];

    views = Join[
        If[ name === "execute" && ! failed, Flatten[ executeOutputView[ #, limit ] & /@ texts ], outputTextView[ #, limit ] & /@ texts ],
        imageView /@ images
    ];
    section[ If[ failed && tool[ "ClientOutcome" ] === None, "SectionError", "SectionOutput" ], Column[ views, Spacings -> 0.4 ] ]
];

outputSection // endDefinition;


toolTexts // beginDefinition;
toolTexts[ tool_Association ] := Module[ { texts },
    texts = Cases[
        tool[ "Content" ],
        KeyValuePattern @ { "type" -> "content", "content" -> KeyValuePattern @ { "type" -> "text", "text" -> t_String } } :> t
    ];
    If[ texts === { } && tool[ "Status" ] === "failed",
        Cases[ { tool[ "RawOutput" ] }, KeyValuePattern[ "error" -> e_String ] :> e ],
        texts
    ]
];
toolTexts // endDefinition;


toolImages // beginDefinition;
toolImages[ tool_Association ] := Cases[
    tool[ "Content" ],
    KeyValuePattern @ { "type" -> "content", "content" -> img: KeyValuePattern[ "type" -> "image" ] } :> img
];
toolImages // endDefinition;


outputTextView // beginDefinition;
outputTextView[ text_String, limit_Integer ] := RawBoxes @ codeBlock[ truncateTail[ text, limit ], "text" ];
outputTextView // endDefinition;


(* OpenCode's execute tool returns a JSON object mapping the script's result keys to text: *)
executeOutputView // beginDefinition;

executeOutputView[ text_String, limit_Integer ] := Module[ { json },
    json = If[ StringStartsQ[ StringTrim @ text, "{" ], Quiet @ Developer`ReadRawJSONString @ text, $Failed ];
    If[ AssociationQ @ json && Length @ json > 0,
        KeyValueMap[
            Column[
                {
                    Style[ #1, FontColor -> $mutedColor, FontSize -> 12 ],
                    RawBoxes @ codeBlock[ truncateTail[ acpStripToolOutput @ If[ StringQ @ #2, #2, shortJSON @ #2 ], limit ], "text" ]
                },
                Spacings -> 0.2
            ] &,
            json
        ],
        { outputTextView[ text, limit ] }
    ]
];

executeOutputView // endDefinition;


imageView // beginDefinition;

imageView[ block: KeyValuePattern[ "data" -> data_String ] ] := Module[ { format, image },
    (* An explicit format avoids loading every importer to guess it: *)
    format = Replace[
        ToLowerCase @ Replace[ Lookup[ block, "mimeType", "" ], Except[ _String ] -> "" ],
        { "image/png" -> "PNG", "image/jpeg" | "image/jpg" -> "JPEG", "image/gif" -> "GIF", "image/webp" -> "WebP", "image/svg+xml" -> "SVG", _ -> Automatic }
    ];
    image = Quiet @ Check[
        If[ format === Automatic, ImportByteArray @ BaseDecode @ data, ImportByteArray[ BaseDecode @ data, format ] ],
        $Failed
    ];
    If[ ImageQ @ image,
        Image[ image, ImageSize -> imageDisplaySize[ image, If[ $renderMode === "Final", $finalImageSize, $liveImageSize ] ] ],
        Style[ acpLabel[ "ImageUnavailable" ], FontColor -> $mutedColor ]
    ]
];

imageView[ _ ] := Style[ acpLabel[ "ImageUnavailable" ], FontColor -> $mutedColor ];

imageView // endDefinition;


(* Natural size (one point per pixel, like an Image with ImageSize -> Automatic at 100% magnification), scaled down
   (never up) to fit in { maxWidth, maxHeight } points. An explicit size is used because the front end stretched small
   images to the UpTo[...] width. *)
imageDisplaySize // beginDefinition;

imageDisplaySize[ image_? ImageQ, max_ ] := imageDisplaySize[ ImageDimensions @ image, max ];

imageDisplaySize[ { w_Integer? Positive, h_Integer? Positive }, { maxW_, maxH_ } ] :=
    Max[ 1, # ] & /@ Round[ { w, h } * Min[ 1, maxW / w, maxH / h ] ];

imageDisplaySize[ _, { maxW_, _ } ] := UpTo @ maxW;

imageDisplaySize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Details*)
detailsSection // beginDefinition;

detailsSection[ tool_Association, key_ ] := Module[ { data, json },
    data = DeleteCases[
        <|
            "toolCallId" -> tool[ "ToolCallID" ],
            "name"       -> Replace[ tool[ "RawName" ], None -> Missing[ ] ],
            "kind"       -> Replace[ tool[ "Kind" ], None -> Missing[ ] ],
            "status"     -> tool[ "Status" ],
            "rawInput"   -> Replace[ tool[ "RawInput" ], None -> Missing[ ] ],
            "rawOutput"  -> Replace[ tool[ "RawOutput" ], None -> Missing[ ] ],
            "content"    -> Replace[ textContentOnly @ tool[ "Content" ], { } -> Missing[ ] ]
        |>,
        _Missing
    ];
    json = shortJSON[ data, False ];
    subOpener[ key, "Details", "SectionDetails", RawBoxes @ codeBlock[ truncateHead[ json, If[ $renderMode === "Final", 400, 80 ] ], "text" ] ]
];

detailsSection // endDefinition;


(* Image data is replaced by a placeholder in Details: *)
textContentOnly // beginDefinition;
textContentOnly[ content_List ] := Replace[ content, KeyValuePattern[ "type" -> "image" ] :> <| "type" -> "image" |>, { 2 } ];
textContentOnly[ _ ] := { };
textContentOnly // endDefinition;


shortJSON // beginDefinition;
shortJSON[ expr_ ] := shortJSON[ expr, True ];
shortJSON[ expr_, compact_ ] := Replace[
    Quiet @ Developer`WriteRawJSONString[ expr, "Compact" -> TrueQ @ compact ],
    Except[ _String ] :> ToString[ expr, InputForm ]
];
shortJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*subOpener*)

(* Collapsed section inside a card. Live: state in $acpOpen under Append[ key, name ]; final: front-end-only state. *)
subOpener // beginDefinition;

subOpener[ _, _String, labelKey_String, content_ ] /; $renderMode === "Final" := With[ { c = content, label = subOpenerLabel @ labelKey },
    DynamicModule[ { Typeset`open = False },
        PaneSelector[
            {
                False -> EventHandler[
                    Row @ { label, " ", openerIcon @ False },
                    { "MouseDown" :> FEPrivate`Set[ Typeset`open, True ] },
                    Method -> "Preemptive", PassEventsDown -> Automatic, PassEventsUp -> True
                ],
                True -> Column[
                    {
                        EventHandler[
                            Row @ { label, " ", openerIcon @ True },
                            { "MouseDown" :> FEPrivate`Set[ Typeset`open, False ] },
                            Method -> "Preemptive", PassEventsDown -> Automatic, PassEventsUp -> True
                        ],
                        c
                    },
                    Spacings -> 0.3
                ]
            },
            Dynamic @ Typeset`open,
            ImageSize -> Automatic
        ],
        DynamicModuleValues :> { }
    ]
];

subOpener[ key_, name_String, labelKey_String, content_ ] := Module[ { subKey, open, header },
    subKey = Append[ key, name ];
    open   = acpOpenQ[ $turnID, subKey, False ];
    header = toggleHandler[ Row @ { subOpenerLabel @ labelKey, " ", openerIcon @ open }, $turnID, subKey, False ];
    If[ open, Column[ { header, content }, Spacings -> 0.3 ], header ]
];

subOpener // endDefinition;


subOpenerLabel // beginDefinition;
subOpenerLabel[ labelKey_String ] := Style[ acpLabel[ labelKey ], FontSize -> 11, FontWeight -> "DemiBold", FontColor -> $sectionLabelColor ];
subOpenerLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Truncation*)

(* Keeps the last n lines (tool output) with a note about the omitted lines: *)
truncateTail // beginDefinition;

truncateTail[ text_String, n_Integer ] := Module[ { lines, omitted },
    lines   = truncateLine /@ StringSplit[ text, "\n", All ];
    omitted = Max[ 0, Length @ lines - n ];
    StringRiffle[
        If[ omitted > 0, Prepend[ Take[ lines, -n ], acpLabel[ "TruncatedEarlierLines", <| "n" -> omitted |> ] ], lines ],
        "\n"
    ]
];

truncateTail // endDefinition;


(* Keeps the first n lines (code and input): *)
truncateHead // beginDefinition;

truncateHead[ text_String, n_Integer ] := Module[ { lines, omitted },
    lines   = truncateLine /@ StringSplit[ text, "\n", All ];
    omitted = Max[ 0, Length @ lines - n ];
    StringRiffle[
        If[ omitted > 0, Append[ Take[ lines, n ], acpLabel[ "TruncatedMoreLines", <| "n" -> omitted |> ] ], lines ],
        "\n"
    ]
];

truncateHead // endDefinition;


truncateLine // beginDefinition;
truncateLine[ line_String ] := If[ StringLength @ line > $maxLineLength, StringTake[ line, $maxLineLength ] <> "\[Ellipsis]", line ];
truncateLine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Diff View*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpDiffView*)

(* acpDiffView[ diff, opts ] renders a normalized diff item (see Transcript.wl) or a raw ACP diff
   (<| "type" -> "diff", "path", "oldText", "newText" |>) as a line diff: header "path (+a -d)" with a "new file" /
   "contents written" badge, and red/green tinted lines with unchanged runs collapsed to a few lines of context.
   opts: "MaxLines" (default Infinity), "Context" (3), "ProjectDirectory" (for relative paths), "Header" (False: no
   header line, e.g. when the caller shows the path itself), "Omitted" (lines the caller already left out of the diff,
   added to the "n more lines" note), "FullWidth" (True: the frame and the line backgrounds fill the available width;
   long lines still wrap), "LineNumbers" (True: columns with the old and new line numbers, from the hunk headers of
   patches; a column without numbers, e.g. the old one of a new file, is left out). The chat's views use neither. *)
acpDiffView // beginDefinition;

acpDiffView[ diff_Association ] := acpDiffView[ diff, <| |> ];

acpDiffView[ diff_Association, opts_Association ] /; KeyExistsQ[ diff, "type" ] && ! KeyExistsQ[ diff, "Path" ] :=
    acpDiffView[
        <|
            "Path"        -> Replace[ Lookup[ diff, "path", "" ], Except[ _String ] -> "" ],
            "OldText"     -> Replace[ Lookup[ diff, "oldText", None ], Except[ _String ] -> None ],
            "NewText"     -> Replace[ Lookup[ diff, "newText", None ], Except[ _String ] -> None ],
            "Patch"       -> Replace[ Lookup[ diff, "patch", None ], Except[ _String ] -> None ],
            "Synthesized" -> False
        |>,
        opts
    ];

acpDiffView[ diff_Association, opts_Association ] := Module[ { full, rows, maxLines, shown, omitted, header },
    full     = TrueQ @ Lookup[ opts, "FullWidth", False ];
    rows     = diffRows[ diff, Lookup[ opts, "Context", $diffContextLines ], TrueQ @ Lookup[ opts, "LineNumbers", False ] ];
    maxLines = Replace[ Lookup[ opts, "MaxLines", Infinity ], Except[ _Integer? Positive ] -> Infinity ];
    omitted  = If[ maxLines === Infinity, 0, Max[ 0, Length @ rows - maxLines ] ];
    shown    = If[ omitted > 0, Take[ rows, maxLines ], rows ];
    omitted  = omitted + Replace[ Lookup[ opts, "Omitted", 0 ], Except[ _Integer? NonNegative ] -> 0 ];
    header   = If[ Lookup[ opts, "Header", True ] === False,
        Nothing,
        diffHeader[ diff, acpDiffStats @ diff, Lookup[ opts, "ProjectDirectory", None ] ]
    ];
    Framed[
        Column[
            DeleteCases[
                {
                    header,
                    If[ shown === { }, Nothing, diffGrid[ shown, full, lineNumberColumns @ rows ] ],
                    If[ omitted > 0, Style[ acpLabel[ "TruncatedMoreLines", <| "n" -> omitted |> ], FontColor -> $mutedColor, FontSize -> 11 ], Nothing ]
                },
                Nothing
            ],
            Spacings -> 0.3
        ],
        Background     -> LightDarkSwitched[ GrayLevel[ 1.0 ], GrayLevel[ 0.16 ] ],
        FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], $cardFrame ],
        FrameMargins   -> { { 6, 6 }, { 4, 4 } },
        RoundingRadius -> 4,
        If[ full, ImageSize -> Full, Sequence @@ { } ]
    ]
];

acpDiffView[ _, ___ ] := "";

acpDiffView // endDefinition;


diffHeader // beginDefinition;

diffHeader[ diff_Association, { a_, d_ }, root_ ] := Row[
    Flatten @ {
        Style[ relativePath[ diff[ "Path" ], root ], FontFamily -> $codeFont, FontSize -> 12, FontWeight -> "DemiBold" ],
        "  ",
        If[ a > 0 || TrueQ @ diff[ "Write" ], Style[ "+" <> ToString @ a, FontColor -> $greenText, FontSize -> 12 ], Nothing ],
        If[ d > 0, { " ", Style[ "\[Minus]" <> ToString @ d, FontColor -> $redText, FontSize -> 12 ] }, Nothing ],
        Which[
            TrueQ @ diff[ "Write" ], { "  ", badge[ acpLabel[ "BadgeContentsWritten" ], "Neutral" ] },
            diff[ "OldText" ] === None && StringQ @ diff[ "NewText" ] && ! StringQ @ diff[ "Patch" ], { "  ", badge[ acpLabel[ "BadgeNewFile" ], "Neutral" ] },
            True, Nothing
        ]
    }
];

diffHeader // endDefinition;


relativePath // beginDefinition;
relativePath[ path_String, root_String ] /; StringStartsQ[ path, StringTrim[ root, "/" ~~ EndOfString ] <> "/" ] :=
    StringDrop[ path, StringLength @ StringTrim[ root, "/" ~~ EndOfString ] + 1 ];
relativePath[ path_String, _ ] := path;
relativePath[ _, _ ] := "";
relativePath // endDefinition;


(* Rows: { "+"|"-"|"="|"@", line }, or with line numbers (numbers True) { op, line, old, new }: the line's numbers in the
   old and the new file, or None *)
diffRows // beginDefinition;

diffRows[ diff_Association, context_ ] := diffRows[ diff, context, False ];

diffRows[ KeyValuePattern[ "Patch" -> patch_String ], _, numbers_ ] :=
    If[ TrueQ @ numbers, numberPatchRows @ acpPatchRows @ patch, acpPatchRows @ patch ];

(* Synthesized "contents written" diffs show the content without marking every line as added (with new line numbers): *)
diffRows[ diff: KeyValuePattern[ "Write" -> True ], _, numbers_ ] := With[
    { lines = StringSplit[ StringDelete[ Replace[ diff[ "NewText" ], Except[ _String ] -> "" ], "\n" ~~ EndOfString ], "\n", All ] },
    If[ TrueQ @ numbers, MapIndexed[ { "=", #1, None, First @ #2 } &, lines ], { "=", # } & /@ lines ]
];

diffRows[ diff_Association, context_Integer, numbers_ ] := With[
    { ops = acpLineDiff[ Replace[ diff[ "OldText" ], Except[ _String ] -> "" ], Replace[ diff[ "NewText" ], Except[ _String ] -> "" ] ] },
    collapseContext[ If[ TrueQ @ numbers, numberLineOps @ ops, ops ], context ]
];

diffRows[ diff_Association, _, numbers_ ] := diffRows[ diff, $diffContextLines, numbers ];

diffRows // endDefinition;


(* Line numbers for a line diff: unchanged lines have both, removed lines the old and added lines the new one *)
numberLineOps // beginDefinition;

numberLineOps[ ops_List ] := Module[ { old = 0, new = 0 },
    Replace[
        #,
        {
            { "=", l_ } :> { "=", l, ++old, ++new },
            { "-", l_ } :> { "-", l, ++old, None },
            { "+", l_ } :> { "+", l, None, ++new },
            { op_, l_ } :> { op, l, None, None }
        }
    ] & /@ ops
];

numberLineOps // endDefinition;


(* Line numbers for the rows of a patch, counted from the start lines in the hunk headers ("@@ -a,b +c,d @@"). Rows
   before the first hunk header, or after one that can't be read, have none. *)
numberPatchRows // beginDefinition;

numberPatchRows[ rows_List ] := Module[ { old = None, new = None },
    Function[ row,
        Switch[ First @ row,
            "@", { old, new } = hunkStart @ row[[ 2 ]]; { "@", row[[ 2 ]], None, None },
            "=", With[ { r = { "=", row[[ 2 ]], old, new } }, old = nextLineNumber @ old; new = nextLineNumber @ new; r ],
            "-", With[ { r = { "-", row[[ 2 ]], old, None } }, old = nextLineNumber @ old; r ],
            "+", With[ { r = { "+", row[[ 2 ]], None, new } }, new = nextLineNumber @ new; r ],
            _  , { First @ row, row[[ 2 ]], None, None }
        ]
    ] /@ rows
];

numberPatchRows // endDefinition;


(* { old start, new start } of a hunk header, or { None, None } *)
hunkStart // beginDefinition;

hunkStart[ header_String ] := Replace[
    StringCases[
        header,
        StartOfString ~~ "@@ -" ~~ a: DigitCharacter.. ~~ (("," ~~ DigitCharacter..) | "") ~~ " +" ~~ c: DigitCharacter.. :>
            { FromDigits @ a, FromDigits @ c },
        1
    ],
    { { start_ } :> start, _ -> { None, None } }
];

hunkStart // endDefinition;


nextLineNumber // beginDefinition;
nextLineNumber[ n_Integer ] := n + 1;
nextLineNumber[ _ ] := None;
nextLineNumber // endDefinition;


(* Keeps `context` unchanged lines around each change; longer unchanged runs become an ellipsis row: *)
collapseContext // beginDefinition;

collapseContext[ ops_List, context_Integer ] := Module[ { changed, keep, rows = { }, skipping = False },
    changed = Flatten @ Position[ ops, { "+" | "-", __ }, { 1 } ];
    If[ changed === { }, Return[ ops, Module ] ];
    keep = Union @ Flatten[ Range[ Max[ 1, # - context ], Min[ Length @ ops, # + context ] ] & /@ changed ];
    Do[
        If[ MemberQ[ keep, i ],
            AppendTo[ rows, ops[[ i ]] ]; skipping = False,
            (* the ellipsis row has no line numbers: *)
            If[ ! skipping, AppendTo[ rows, PadRight[ { "@", "\:22ef" }, Length @ ops[[ i ]], None ] ]; skipping = True ]
        ],
        { i, Length @ ops }
    ];
    rows
];

collapseContext // endDefinition;


(* The diff lines. With full width, the line column takes the rest of the available width (so the line backgrounds
   span it, and long lines wrap at its edge). numbers: the positions of the line numbers in the rows that get a column
   (narrow and right-aligned, in front of the lines). *)
diffGrid // beginDefinition;

diffGrid[ rows: { { _, _ }... }, False, _ ] := Grid[
    diffRowItems /@ rows,
    Alignment  -> { Left, Baseline },
    Spacings   -> { 0.4, 0.1 },
    Background -> diffRowBackgrounds @ rows,
    BaseStyle  -> { FontFamily -> $codeFont, FontSize -> 12, LineBreakWithin -> Automatic }
];

diffGrid[ rows_List, full_, numbers_List ] := With[ { n = Length @ numbers },
    Grid[
        Join[ lineNumberItem /@ #[[ numbers ]], diffRowItems @ #[[ ;; 2 ]] ] & /@ rows,
        Alignment  -> { Join[ ConstantArray[ Right, n ], { Left, Left } ], Baseline },
        Spacings   -> { Join[ { 0.4 }, ConstantArray[ 0.7, n ], { 0.4, 0.4 } ], 0.1 },
        ItemSize   -> If[ TrueQ @ full, { Append[ ConstantArray[ Automatic, n + 1 ], Fit ], Automatic }, Automatic ],
        Background -> diffRowBackgrounds @ rows,
        BaseStyle  -> { FontFamily -> $codeFont, FontSize -> 12, LineBreakWithin -> Automatic }
    ]
];

diffGrid // endDefinition;


(* The positions of the old (3) and new (4) line numbers in numbered rows that have a column: those with a number in some
   row (of all rows, so a diff cut at MaxLines keeps its columns). The old column of a new file and the new one of a
   deleted file are left out. *)
lineNumberColumns // beginDefinition;
lineNumberColumns[ rows_List ] := Select[ { 3, 4 }, Function[ i, AnyTrue[ rows, Length @ # >= i && IntegerQ @ #[[ i ]] & ] ] ];
lineNumberColumns // endDefinition;


diffRowItems // beginDefinition;
diffRowItems[ { "+", l_ } ] := { Style[ "+", FontColor -> $greenText ], diffLineText @ l };
diffRowItems[ { "-", l_ } ] := { Style[ "\[Minus]", FontColor -> $redText ], diffLineText @ l };
diffRowItems[ { "@", l_ } ] := { "", Style[ l, FontColor -> $mutedColor ] };
diffRowItems[ { _, l_ }   ] := { "", diffLineText @ l };
diffRowItems // endDefinition;


diffRowBackgrounds // beginDefinition;

diffRowBackgrounds[ rows_List ] := {
    None,
    Replace[ rows[[ All, 1 ]], { "+" -> $addedBackground, "-" -> $removedBackground, "@" -> $hunkBackground, _ -> None }, { 1 } ]
};

diffRowBackgrounds // endDefinition;


lineNumberItem // beginDefinition;
lineNumberItem[ n_Integer ] := Style[ IntegerString @ n, FontColor -> $mutedColor, FontSize -> 10 ];
lineNumberItem[ _ ] := "";
lineNumberItem // endDefinition;


diffLineText // beginDefinition;
diffLineText[ l_String ] := Style[ If[ l === "", " ", truncateLine @ acpNeutralizeLinearSyntax @ l ], ShowStringCharacters -> False ];
diffLineText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Other Entities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*permissionEntityCell*)

(* A permission request that doesn't belong to a tool call (e.g. access outside the project directory). The buttons are
   in the permission panel; this card only shows a passive badge. *)
permissionEntityCell // beginDefinition;

permissionEntityCell[ perm_Association, turn_ ] := boxCell @ Framed[
    Grid[
        {
            Flatten @ {
                iconPane @ chatbookIcon[ "WrenchIcon", False ],
                Style[ titleView @ acpToolTitle[ perm, Automatic, turn ], FontColor -> $toolLabelColor ],
                Switch[ perm[ "Outcome" ],
                    None    , badge[ acpLabel[ "BadgeAwaitingApproval" ], "Amber" ],
                    "once"  , badge[ acpLabel[ "BadgeAllowedOnce" ], "Neutral" ],
                    "always", badge[ acpLabel[ "BadgeAllowedAlways" ], "Neutral" ],
                    "reject", badge[ acpLabel[ "BadgeDeclined" ], "Neutral" ],
                    "cancelled", badge[ acpLabel[ "BadgeCancelled" ], "Neutral" ],
                    _       , Nothing
                ]
            }
        },
        $headerGridOptions
    ],
    cardFrameOptions @ If[ perm[ "Outcome" ] === None, "Awaiting", "Default" ]
];

permissionEntityCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*noticeCell*)
noticeCell // beginDefinition;

noticeCell[ notice_Association ] := boxCell @ Row[
    {
        Style[ noticeGlyph @ notice, FontColor -> If[ notice[ "Kind" ] === "Error", $redText, $amberText ] ],
        " ",
        Style[ noticeText @ notice, FontColor -> $mutedColor, FontSlant -> Italic, FontSize -> 13 ]
    }
];

noticeCell // endDefinition;


noticeGlyph // beginDefinition;
noticeGlyph[ KeyValuePattern[ "Kind" -> "Retry" ] ] := "\:21bb";
noticeGlyph[ KeyValuePattern[ "Kind" -> "Compaction" ] ] := "\:2261";
noticeGlyph[ KeyValuePattern[ "Kind" -> "Error" ] ] := "\:26a0";
noticeGlyph[ _ ] := "\:2139";
noticeGlyph // endDefinition;


noticeText // beginDefinition;

noticeText[ KeyValuePattern @ { "Kind" -> "Retry", "Data" -> data_Association } ] := Module[ { rateLimited, retries, duration },
    rateLimited = data[ "ErrorType" ] === "provider.rate-limit";
    retries     = Replace[ data[ "LastAttempt" ], Except[ _Integer ] -> 2 ] - 1;
    duration    = Replace[ data[ "EndTime" ], Except[ _? NumberQ ] -> AbsoluteTime[ ] ] - Replace[ data[ "StartTime" ], Except[ _? NumberQ ] -> AbsoluteTime[ ] ];
    If[ TrueQ @ data[ "Active" ],
        acpLabel[ If[ rateLimited, "NoticeRetryingRateLimited", "NoticeRetryingError" ], <| "attempt" -> data[ "LastAttempt" ] |> ],
        acpLabel[ If[ rateLimited, "NoticeRetriedRateLimited", "NoticeRetriedError" ], <| "n" -> Max[ 1, retries ], "time" -> acpFormatDuration @ duration |> ]
    ]
];

noticeText[ KeyValuePattern @ { "Kind" -> "Compaction", "Data" -> KeyValuePattern[ "Status" -> status_ ] } ] := Switch[ status,
    "completed", acpLabel[ "NoticeCompacted" ],
    "failed"   , acpLabel[ "NoticeCompactionFailed" ],
    _          , acpLabel[ "NoticeCompacting" ]
];

noticeText[ KeyValuePattern[ "Text" -> text_String ] ] := text;
noticeText[ _ ] := "";

noticeText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*planCell*)
planCell // beginDefinition;

planCell[ plan_Association ] := boxCell @ Grid[
    Cases[
        Lookup[ plan, "Entries", { } ],
        entry_Association :> {
            Switch[ Lookup[ entry, "status", "pending" ],
                "completed"  , Style[ "\:2611", FontColor -> $greenText ],
                "in_progress", Style[ "\:25d0", FontColor -> $amberText ],
                _            , Style[ "\:2610", FontColor -> $mutedColor ]
            ],
            Style[ Replace[ Lookup[ entry, "content", "" ], Except[ _String ] -> "" ], If[ entry[ "status" ] === "completed", FontColor -> $mutedColor, Nothing ] ]
        }
    ],
    Alignment -> { Left, Baseline },
    Spacings  -> { 0.5, 0.3 }
];

planCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Final Cell*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFinalCell*)

(* The static output cell that replaces the live view when a turn is finalized:
     * a closed "Worked for ..." opener (Chatbook's ThoughtsOpener template, with normally-styled content) holding the
       work items, or plain ThoughtsOpeners if the work was only thinking;
     * for turns that did not end normally, the last step's items (expanded) and a status line;
     * the answer, formatted with FormatChatOutput "Finished" (falls back to front-end-free formatting);
     * an error box for failed turns.
   TaggingRules hold "CellToStringData" (markdown), a compact "ACPTurn" record and "ChatNotebookSettings". *)
acpFinalCell // beginDefinition;

acpFinalCell[ id_String ] := acpFinalCell @ acpTurnGet @ id;

acpFinalCell[ turn: KeyValuePattern @ { "Order" -> _List, "Entities" -> _Association, "StartTime" -> _? NumberQ } ] :=
    withRenderContext @ Block[ { $catching = True }, (* Chatbook failures throw to our Catch instead of being returned *)
        Module[ { cell },
            cell = acpCatchAll @ finalCell[ turn, False ];
            If[ ! validFinalCellQ @ cell,
                acpLog[ "FinalCellFallback", <| "TurnID" -> Lookup[ turn, "ID" ], "Result" -> Short[ cell, 3 ] |> ];
                cell = acpCatchAll @ finalCell[ turn, True ]
            ];
            If[ validFinalCellQ @ cell, cell, minimalFinalCell @ turn ]
        ]
    ];

acpFinalCell[ _ ] := minimalFinalCell @ <| |>;

acpFinalCell // endDefinition;


validFinalCellQ // beginDefinition;
validFinalCellQ[ cell_Cell ] := FreeQ[ cell, _Failure | $Failed ];
validFinalCellQ[ _ ] := False;
validFinalCellQ // endDefinition;


finalCell // beginDefinition;

finalCell[ turn_Association, noFE_ ] := Block[
    { $renderMode = "Final", $turnID = Lookup[ turn, "ID", None ], $acpNoFrontEndFormatting = TrueQ @ noFE || $acpNoFrontEndFormatting },
    Module[ { split, entities, items, status, answer },
        split    = acpTurnSplit @ turn;
        entities = turn[ "Entities" ];
        items    = { };

        (* Work *)
        If[ split[ "Work" ] =!= { },
            items = Join[ items, workItems[ turn, split[ "Work" ] ] ]
        ];

        (* Last step of an interrupted turn, expanded: *)
        Do[
            items = Join[ items, { finalEntityCell[ entities[ key ], key, turn, True ], "\n" } ],
            { key, split[ "Tail" ] }
        ];

        (* Answer *)
        answer = StringRiffle[ DeleteCases[ StringTrim[ entities[ #, "Text" ] ] & /@ split[ "Answer" ], "" ], "\n\n" ];
        If[ answer =!= "", items = Join[ items, finishedItems @ answer, { "\n" } ] ];
        items = Join[ items, Flatten[ blockItems @ entities[ #, "Blocks" ] & /@ split[ "Answer" ] ] ];

        (* Status line or error *)
        status = If[ turn[ "Error" ] === None, acpTurnStatusLine @ turn, None ];
        Which[
            AssociationQ @ turn[ "Error" ],
                items = Join[ items, { boxCell @ acpErrorView[ turn[ "Error" ], Lookup[ turn, "Notebook", None ] ] } ],
            StringQ @ status,
                items = Join[ items, { boxCell @ statusLineView[ turn, status ] } ],
            answer === "" && split[ "Tail" ] === { },
                items = Join[ items, { boxCell @ Style[ acpLabel[ "DoneNoReply" ], FontColor -> $mutedColor, FontSlant -> Italic ] } ]
        ];

        Cell[
            BoxData @ TemplateBox[
                { Cell[ TextData @ trimItems @ items, Background -> None, Editable -> True, Selectable -> True ] },
                "AssistantMessageBox"
            ],
            "ChatOutput",
            GeneratedCell     -> True,
            CellAutoOverwrite -> True,
            TaggingRules      -> <|
                "CellToStringData"     -> acpTurnToMarkdown @ turn,
                "ACPTurn"              -> compactTurnData @ turn,
                "ChatNotebookSettings" -> <| "ACPWindow" -> True |>
            |>
        ]
    ]
];

finalCell // endDefinition;


(* Work items: one closed "Worked for" opener, or plain ThoughtsOpeners if the work was only thinking. *)
workItems // beginDefinition;

workItems[ turn_Association, keys_List ] := Module[ { entities },
    entities = turn[ "Entities" ];
    If[ AllTrue[ keys, entities[ #, "Type" ] === "Thought" & ],
        Flatten[ { thoughtsOpenerCell @ entities[ # ], "\n" } & /@ keys ],
        { workedForOpenerCell[ turn, keys ], "\n" }
    ]
];

workItems // endDefinition;


workedForOpenerCell // beginDefinition;

workedForOpenerCell[ turn_Association, keys_List ] := Module[ { entities, seen = { }, content = { }, child },
    entities = turn[ "Entities" ];
    Do[
        child = Lookup[ entities[ key ], "Child", None ];
        If[ AssociationQ @ child && ! MemberQ[ seen, child[ "ID" ] ],
            AppendTo[ seen, child[ "ID" ] ];
            content = Join[ content, { subagentHeaderCell @ child, "\n" } ]
        ];
        content = Join[ content, { finalEntityCell[ entities[ key ], key, turn, False ], "\n" } ],
        { key, keys }
    ];
    Cell[
        BoxData @ TemplateBox[
            {
                TextData @ {
                    Cell[
                        TextData @ trimItems @ content,
                        "Text",
                        FontColor  -> $workContentFontColor,
                        FontSize   -> $workContentFontSize,
                        Background -> None
                    ]
                },
                ToBoxes @ acpWorkedForLabel @ turn,
                <| "Type" -> "ACPWork", "Duration" -> Replace[ Lookup[ turn, "EndTime" ], Except[ _? NumberQ ] -> AbsoluteTime[ ] ] - turn[ "StartTime" ] |>
            },
            "ThoughtsOpener"
        ],
        "ThoughtsOpener",
        Background -> None
    ]
];

workedForOpenerCell // endDefinition;


finalEntityCell // beginDefinition;
finalEntityCell[ tool: KeyValuePattern[ "Type" -> "Tool" ], key_, turn_, open_ ] := toolCardCell[ tool, key, turn, open ];
finalEntityCell[ entity_Association, key_, turn_, _ ] := renderEntity[ entity, key, turn ];
finalEntityCell[ _, _, _, _ ] := "";
finalEntityCell // endDefinition;


trimItems // beginDefinition;
trimItems[ items_List ] := Module[ { list = DeleteCases[ items, "" ] },
    While[ list =!= { } && Last @ list === "\n", list = Most @ list ];
    list
];
trimItems // endDefinition;


statusLineView // beginDefinition;
statusLineView[ turn_Association, status_String ] := Style[
    titleView @ status,
    FontColor -> If[ turn[ "ClientCancel" ] === None && turn[ "StopReason" ] =!= "cancelled", $amberText, $mutedColor ],
    FontSlant -> Italic
];
statusLineView // endDefinition;


minimalFinalCell // beginDefinition;

minimalFinalCell[ turn_ ] := Cell[
    BoxData @ TemplateBox[
        {
            Cell[
                TextData @ {
                    If[ MatchQ[ turn, KeyValuePattern @ { "Order" -> _List, "Entities" -> _Association } ],
                        Replace[ Quiet @ acpCatchAll @ Block[ { $catching = True }, acpTurnToMarkdown @ turn ], Except[ _String ] :> acpLabel[ "TurnUnavailable" ] ],
                        acpLabel[ "TurnUnavailable" ]
                    ]
                },
                Background -> None, Editable -> True, Selectable -> True
            ]
        },
        "AssistantMessageBox"
    ],
    "ChatOutput",
    GeneratedCell     -> True,
    CellAutoOverwrite -> True,
    TaggingRules      -> <| "ChatNotebookSettings" -> <| "ACPWindow" -> True |> |>
];

minimalFinalCell // endDefinition;


(* Small summary of the turn kept in the final cell's TaggingRules (no tool output): *)
compactTurnData // beginDefinition;

compactTurnData[ turn_Association ] := <|
    "Version"      -> 1,
    "ID"           -> Lookup[ turn, "ID", None ],
    "SessionID"    -> Lookup[ turn, "SessionID", None ],
    "Prompt"       -> Replace[ Lookup[ turn, "Prompt", "" ], s_String /; StringLength @ s > 2000 :> StringTake[ s, 2000 ] ],
    "StartTime"    -> Lookup[ turn, "StartTime", None ],
    "EndTime"      -> Lookup[ turn, "EndTime", None ],
    "StopReason"   -> Lookup[ turn, "StopReason", None ],
    "ClientCancel" -> Lookup[ turn, "ClientCancel", None ],
    "Error"        -> Replace[ Lookup[ turn, "Error", None ], e_Association :> KeyTake[ e, { "Code", "Message" } ] ],
    "Usage"        -> Lookup[ turn, "Usage", None ],
    "ContextUsage" -> Lookup[ turn, "ContextUsage", None ],
    "WaitingTime"  -> Lookup[ turn, "WaitingTime", 0 ],
    "Tools"        -> Cases[
        Lookup[ Lookup[ turn, "Entities", <| |> ], Lookup[ turn, "Order", { } ] ],
        tool: KeyValuePattern[ "Type" -> "Tool" ] :> <|
            "ToolCallID"    -> tool[ "ToolCallID" ],
            "Name"          -> tool[ "Name" ],
            "Kind"          -> tool[ "Kind" ],
            "Title"         -> acpToolTitle[ tool, Automatic, turn ],
            "Status"        -> tool[ "Status" ],
            "ClientOutcome" -> tool[ "ClientOutcome" ],
            "ExitCode"      -> tool[ "ExitCode" ]
        |>
    ]
|>;

compactTurnData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window Views*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stableDynamic*)

(* A view that tracks the window's change symbol but only re-renders when `signature` changes. The window symbol is
   bumped on every turn update, so this keeps buttons from being rebuilt (and clicks lost) while a turn streams.
   Embed the result directly; don't wrap it in another Dynamic that tracks the window symbol. *)
stableDynamic // beginDefinition;
stableDynamic // Attributes = { HoldRest };

stableDynamic[ HoldComplete[ s_Symbol ], signature_, view_ ] :=
    DynamicModule[ { sig = None },
        DynamicWrapper[
            Dynamic[ sig; view, TrackedSymbols :> { sig } ],
            s; With[ { new = signature }, If[ new =!= sig, sig = new ] ],
            TrackedSymbols :> { s }
        ],
        DynamicModuleValues :> { },
        UnsavedVariables    :> { sig }
    ];

stableDynamic // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPermissionPanel*)

(* Card for the first pending permission request of the window (shown above the input field while requests are
   pending; empty otherwise). Buttons are Preemptive, ignore clicks during the first 0.4 s, and call
   ChatbookAction[ "ACP", "PermissionResponse", nbo, requestID, optionId ]. *)
acpPermissionPanel // beginDefinition;

acpPermissionPanel[ nbo_NotebookObject ] := stableDynamic[
    acpWindowSymbol @ nbo,
    permissionSignature @ nbo,
    permissionPanelContent @ nbo
];

acpPermissionPanel // endDefinition;


permissionSignature // beginDefinition;
permissionSignature[ nbo_NotebookObject ] := Replace[
    acpIsolated @ Module[ { pending },
        pending = acpWindowGet[ nbo, "PendingPermissions", <| |> ];
        If[ AssociationQ @ pending && Length @ pending > 0,
            { First @ Keys @ pending, Length @ pending, acpWindowGet[ nbo, "ProjectDirectory", None ] },
            None
        ]
    ],
    _Failure -> None
];
permissionSignature // endDefinition;


permissionPanelContent // beginDefinition;

permissionPanelContent[ nbo_NotebookObject ] := Replace[
    acpIsolated @ withRenderContext @ permissionPanelContent0 @ nbo,
    Except[ _RawBoxes ] :> RawBoxes[ "" ]
];

permissionPanelContent // endDefinition;


permissionPanelContent0 // beginDefinition;

permissionPanelContent0[ nbo_NotebookObject ] := Module[ { window, pending, reqID, info },
    window  = acpWindowGet @ nbo;
    pending = If[ AssociationQ @ window, Lookup[ window, "PendingPermissions", <| |> ], <| |> ];
    If[ ! AssociationQ @ pending || Length @ pending === 0, Return[ RawBoxes[ "" ], Module ] ];
    reqID = First @ Keys @ pending;
    info  = First @ pending;
    RawBoxes @ ToBoxes @ permissionCard[ nbo, window, reqID, info, 1, Length @ pending ]
];

permissionPanelContent0 // endDefinition;


permissionCard // beginDefinition;

permissionCard[ nbo_, window_Association, reqID_, info_Association, i_Integer, n_Integer ] := Module[
    { params, toolCall, tool, agent, project, headline, preview, options, armAt, buttons, scope },

    params   = Replace[ Lookup[ info, "Params", <| |> ], Except[ _Association ] -> <| |> ];
    toolCall = Replace[ Lookup[ params, "toolCall", <| |> ], Except[ _Association ] -> <| |> ];
    tool     = permissionTool[ info, toolCall ];
    agent    = windowAgentName @ window;
    project  = Replace[ Lookup[ window, "ProjectDirectory", None ], Except[ _String ] -> "" ];
    headline = permissionHeadline[ tool, toolCall, agent, project ];
    preview  = permissionPreview[ tool, project ];
    options  = Replace[ Lookup[ params, "options", { } ], Except[ _List ] -> { } ];
    armAt    = AbsoluteTime[ ] + $permissionArmDelay;
    buttons  = permissionButton[ nbo, reqID, #, armAt, tool, agent, project ] & /@ options;
    scope    = If[ MemberQ[ options, KeyValuePattern[ "kind" -> "allow_always" ] ], alwaysScopeText[ tool, agent, project ], None ];

    Framed[
        Column[
            DeleteCases[
                {
                    Row @ Flatten @ {
                        Style[ "\:26a0 ", FontColor -> $amberText ],
                        Style[ titleView @ headline, FontWeight -> "DemiBold", FontSize -> 14, FontColor -> $amberFont ],
                        If[ n > 1, { "   ", Style[ acpLabel[ "PermissionQueue", <| "i" -> i, "n" -> n |> ], FontColor -> $mutedColor, FontSize -> 12 ] }, Nothing ]
                    },
                    If[ preview === None,
                        None,
                        Pane[ preview, ImageSize -> { Full, UpTo[ $permissionPreviewHeight ] }, Scrollbars -> { False, Automatic }, AppearanceElements -> None ]
                    ],
                    Row[ buttons, Spacer[ 6 ] ],
                    If[ StringQ @ scope, Style[ scope, FontSize -> 11, FontColor -> $mutedColor ], None ]
                },
                None
            ],
            Spacings -> 0.6
        ],
        Background     -> $amberBackground,
        FrameStyle     -> Directive[ AbsoluteThickness[ 1.5 ], $amberFrame ],
        FrameMargins   -> { { 10, 10 }, { 8, 8 } },
        RoundingRadius -> 8,
        ImageSize      -> Full,
        BaseStyle      -> { "Text", FontSize -> 13 }
    ]
];

permissionCard // endDefinition;


(* The tool entity the request belongs to (if the turn still exists), otherwise a tool-like association built from
   the request's toolCall: *)
permissionTool // beginDefinition;

permissionTool[ info_Association, toolCall_Association ] := Module[ { turn, key, entity },
    turn   = Replace[ Lookup[ info, "TurnID", None ], { id_String :> acpTurnGet @ id, _ -> None } ];
    key    = Lookup[ info, "ToolKey", None ];
    entity = If[ AssociationQ @ turn && ListQ @ key, Lookup[ turn[ "Entities" ], Key @ key, None ], None ];
    If[ MatchQ[ entity, KeyValuePattern[ "Type" -> "Tool" ] ],
        entity,
        <|
            "Type"       -> If[ StringQ @ Lookup[ toolCall, "name", None ], "Tool", "Permission" ],
            "Name"       -> acpCanonicalToolName @ Lookup[ toolCall, "name", None ],
            "RawName"    -> Replace[ Lookup[ toolCall, "name", None ], Except[ _String ] -> None ],
            "Kind"       -> Replace[ Lookup[ toolCall, "kind", None ], Except[ _String ] -> None ],
            "Title"      -> Replace[ Lookup[ toolCall, "title", None ], Except[ _String ] -> None ],
            "RawInput"   -> Lookup[ toolCall, "rawInput", None ],
            "Locations"  -> Replace[ Lookup[ toolCall, "locations", { } ], Except[ _List ] -> { } ],
            "Diffs"      -> Cases[ Replace[ Lookup[ toolCall, "content", { } ], Except[ _List ] -> { } ], d: KeyValuePattern[ "type" -> "diff" ] :> d ],
            "Status"     -> "pending",
            "ClientOutcome" -> None,
            "Permission" -> None,
            "Params"     -> <| "toolCall" -> toolCall |>,
            "Content"    -> { },
            "ExitCode"   -> None
        |>
    ]
];

permissionTool // endDefinition;


windowAgentName // beginDefinition;
windowAgentName[ window_Association ] := Replace[
    Lookup[ Replace[ Lookup[ window, "AgentInfo", None ], Except[ _Association ] -> <| |> ], "Name", Lookup[ window, "Agent", "OpenCode" ] ],
    Except[ _String ] -> "OpenCode"
];
windowAgentName[ _ ] := "OpenCode";
windowAgentName // endDefinition;


permissionHeadline // beginDefinition;

permissionHeadline[ tool_Association, toolCall_Association, agent_, project_ ] := Module[ { name, path },
    name = tool[ "Name" ];
    path = permissionPath[ tool, toolCall, project ];
    Which[
        tool[ "Type" ] === "Permission" || name === "external_directory",
            acpLabel[ "PermissionExternal", <| "agent" -> agent, "path" -> path |> ],
        name === "shell" || (name === None && tool[ "Kind" ] === "execute"),
            acpLabel[ "PermissionRun", <| "agent" -> agent |> ],
        MatchQ[ name, "edit" | "patch" | "multiedit" ],
            acpLabel[ "PermissionEdit", <| "agent" -> agent, "path" -> path |> ],
        name === "write",
            acpLabel[ "PermissionWrite", <| "agent" -> agent, "path" -> path |> ],
        name === "read",
            acpLabel[ "PermissionRead", <| "agent" -> agent, "path" -> path |> ],
        True,
            acpLabel[ "PermissionGeneric", <| "agent" -> agent, "action" -> permissionAction @ tool |> ]
    ]
];

permissionHeadline // endDefinition;


permissionAction // beginDefinition;
permissionAction[ tool_Association ] := acpToolAction[ tool, <| |> ];
permissionAction // endDefinition;


permissionPath // beginDefinition;
permissionPath[ tool_Association, toolCall_Association, project_ ] := Module[ { path },
    path = FirstCase[
        {
            SelectFirst[ Lookup[ Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ], { "path", "filePath", "file_path" }, None ], StringQ, None ],
            Replace[ tool[ "Locations" ], { { KeyValuePattern[ "path" -> p_String ], ___ } :> p, _ -> None } ],
            Replace[ toolCall[ "title" ], Except[ _String ] -> None ]
        },
        _String,
        ""
    ];
    If[ StringQ @ project && project =!= "", relativePath[ path, project ], path ]
];
permissionPath // endDefinition;


permissionPreview // beginDefinition;

permissionPreview[ tool_Association, project_ ] := Block[ { $plainCodeBlocks = True }, permissionPreview0[ tool, project ] ];

permissionPreview // endDefinition;


permissionPreview0 // beginDefinition;

permissionPreview0[ tool_Association, project_ ] := Module[ { name, command, diffs },
    name    = tool[ "Name" ];
    command = SelectFirst[ Lookup[ Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ], { "command", "cmd" }, None ], StringQ, None ];
    diffs   = Replace[ tool[ "Diffs" ], Except[ _List ] -> { } ];
    Which[
        StringQ @ command,
            RawBoxes @ Block[ { $renderMode = "Final" }, codeBlock[ command, "text" ] ],
        diffs =!= { },
            Column[ acpDiffView[ #, <| "MaxLines" -> $finalDiffLines, "ProjectDirectory" -> project |> ] & /@ diffs, Spacings -> 0.5 ],
        name === "execute",
            Column[ Block[ { $renderMode = "Final" }, executeCallView /@ acpExecuteToolCalls @ tool ], Spacings -> 0.5 ],
        AssociationQ @ tool[ "RawInput" ] && Length @ tool[ "RawInput" ] > 0,
            rawInputGrid @ tool[ "RawInput" ],
        True,
            None
    ]
];

permissionPreview0 // endDefinition;


permissionButton // beginDefinition;

permissionButton[ nbo_, reqID_, option_Association, armAt_, tool_, agent_, project_ ] := Module[ { kind, optionID, label, style },
    kind     = Lookup[ option, "kind", "" ];
    optionID = Lookup[ option, "optionId", "" ];
    label    = Switch[ kind,
        "allow_once"                     , acpLabel[ "PermissionAllowOnce" ],
        "allow_always"                   , acpLabel[ "PermissionAllowAlways" ],
        "reject_once" | "reject_always"  , acpLabel[ "PermissionReject" ],
        _                                , Replace[ Lookup[ option, "name", optionID ], Except[ _String ] -> ToString @ optionID ]
    ];
    style = If[ kind === "allow_once", "Primary", "Secondary" ];
    With[ { n = nbo, r = reqID, o = optionID, t = armAt },
        Button[
            buttonLabel[ label, style ],
            acpIsolated @ If[ AbsoluteTime[ ] >= t, ChatbookAction[ "ACP", "PermissionResponse", n, r, o ] ],
            Appearance -> None,
            Method     -> "Preemptive",
            BaseStyle  -> { "Text", FontSize -> 13 }
        ]
    ] // If[ kind === "allow_always", Tooltip[ #, alwaysScopeText[ tool, agent, project ] ], # ] &
];

permissionButton[ ___ ] := Nothing;

permissionButton // endDefinition;


buttonLabel // beginDefinition;

buttonLabel[ label_String, style_String ] := Mouseover[
    buttonFrame[ label, style, False ],
    buttonFrame[ label, style, True ]
];

buttonLabel // endDefinition;


buttonFrame // beginDefinition;

buttonFrame[ label_String, "Primary", hover_ ] := Framed[
    Style[ label, FontColor -> White, FontWeight -> "DemiBold" ],
    Background     -> If[ hover, $primaryButtonHover, $primaryButton ],
    FrameStyle     -> If[ hover, $primaryButtonHover, $primaryButton ],
    FrameMargins   -> { { 10, 10 }, { 3, 3 } },
    RoundingRadius -> 4
];

buttonFrame[ label_String, _, hover_ ] := Framed[
    Style[ label, FontColor -> $amberFont ],
    Background     -> If[ hover, $secondaryButtonHover, $secondaryButton ],
    FrameStyle     -> $secondaryButtonFrame,
    FrameMargins   -> { { 10, 10 }, { 3, 3 } },
    RoundingRadius -> 4
];

buttonFrame // endDefinition;


(* What "Always allow" means for this request (OpenCode stores the grant in its database for the project). ACP does not
   send the patterns OpenCode saves, so they are derived the way OpenCode does (see acpShellSavePatterns):
     * access outside the project folder (any tool, including a "cd" in a shell command): that directory;
     * shell commands: one "<prefix> *" pattern per subcommand;
     * file edits: all edits in the project. *)
alwaysScopeText // beginDefinition;

alwaysScopeText[ tool_Association, agent_, project_ ] := Module[ { name, command, external, scan },
    name     = tool[ "Name" ];
    command  = SelectFirst[ Lookup[ Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ], { "command", "cmd" }, None ], StringQ, None ];
    external = externalDirectory[ tool, command, project ];
    Which[
        StringQ @ external,
            acpLabel[ "PermissionAlwaysScopeExternal", <| "agent" -> agent, "dir" -> external |> ],
        StringQ @ command,
            scan = acpShellSavePatterns @ command;
            Which[
                scan[ "Patterns" ] === { },
                    acpLabel[ "PermissionAlwaysScopeGeneric", <| "agent" -> agent, "project" -> projectLabel @ project |> ],
                TrueQ @ scan[ "Complete" ],
                    acpLabel[ "PermissionAlwaysScopeShell", <| "agent" -> agent, "project" -> projectLabel @ project, "patterns" -> patternList @ scan[ "Patterns" ] |> ],
                True,
                    acpLabel[ "PermissionAlwaysScopeShellRelated", <| "agent" -> agent, "project" -> projectLabel @ project, "patterns" -> patternList @ scan[ "Patterns" ] |> ]
            ],
        MatchQ[ name, "edit" | "write" | "patch" | "multiedit" ],
            acpLabel[ "PermissionAlwaysScopeEdit", <| "agent" -> agent, "project" -> projectLabel @ project |> ],
        True,
            acpLabel[ "PermissionAlwaysScopeGeneric", <| "agent" -> agent, "project" -> projectLabel @ project |> ]
    ]
];

alwaysScopeText // endDefinition;


patternList // beginDefinition;
patternList[ patterns: { __String } ] := StringRiffle[ "\"" <> # <> "\"" & /@ patterns, ", " ];
patternList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*externalDirectory*)

(* The directory outside the project that the request is about (a file's directory, a directory itself, or a "cd"
   target of a shell command), or None *)
externalDirectory // beginDefinition;

externalDirectory[ tool_Association, command_, project_String ] /; StringLength @ project > 0 := Module[ { paths },
    paths = Join[
        Cases[ Lookup[ Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ], { "path", "filePath", "file_path" }, None ], _String ],
        Cases[ Replace[ tool[ "Locations" ], Except[ _List ] -> { } ], KeyValuePattern[ "path" -> p_String ] :> p ]
    ];
    FirstCase[
        Join[
            If[ StringQ @ command, shellDirectoryTargets[ command, project ], { } ],
            Select[ absolutePath[ #, project ] & /@ paths, StringQ ]
        ],
        p_String /; ! insideDirectoryQ[ p, project ] :> If[ TrueQ @ Quiet @ DirectoryQ @ p, p, Replace[ FileNameDrop[ p, -1 ], "" -> p ] ],
        None
    ]
];

externalDirectory[ _, _, _ ] := None;

externalDirectory // endDefinition;


absolutePath // beginDefinition;
absolutePath[ path_String, project_String ] := Which[
    path === "" || StringContainsQ[ path, "$" | "`" ], None,
    path === "~", $HomeDirectory,
    StringStartsQ[ path, "~/" ], FileNameJoin @ { $HomeDirectory, StringDrop[ path, 2 ] },
    StringStartsQ[ path, "/" ] || StringMatchQ[ path, LetterCharacter ~~ ":" ~~ ___ ], path,
    True, FileNameJoin @ { project, path }
];
absolutePath[ _, _ ] := None;
absolutePath // endDefinition;


insideDirectoryQ // beginDefinition;
insideDirectoryQ[ path_String, dir_String ] := With[
    {
        p = StringTrim[ Quiet @ ExpandFileName @ path, "/" ~~ EndOfString ],
        d = StringTrim[ Quiet @ ExpandFileName @ dir, "/" ~~ EndOfString ]
    },
    p === d || StringStartsQ[ p, d <> "/" ] || StringStartsQ[ p, d <> "\\" ]
];
insideDirectoryQ // endDefinition;


(* Absolute targets of cd/pushd/... in a shell command (relative to the project folder) *)
shellDirectoryTargets // beginDefinition;

shellDirectoryTargets[ command_String, project_String ] := Flatten @ Map[
    Function[ words,
        If[ words =!= { } && MemberQ[ $shellDirectoryCommands, ToLowerCase @ First @ words ],
            Select[ absolutePath[ unquote @ #, project ] & /@ Select[ Rest @ words, ! StringStartsQ[ #, "-" ] & ], StringQ ],
            { }
        ]
    ],
    shellCommandWords /@ shellSplitCommands @ command
];

shellDirectoryTargets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpShellSavePatterns*)

(* An approximation of the patterns OpenCode saves for "Always allow" on a shell command: OpenCode parses the command and,
   for every simple command except directory changes (cd, pushd, ...), saves "<prefix> *", where the prefix is the
   command name plus as many words as its arity table says (e.g. "git status *", "npm run build *", "rm *").
   Gives <| "Patterns" -> { ... }, "Complete" -> False if the command contains substitutions that OpenCode also looks
   into (so more patterns may be saved) |>. *)
acpShellSavePatterns // beginDefinition;

acpShellSavePatterns[ command_String ] := <|
    "Patterns" -> DeleteDuplicates @ DeleteCases[ shellSavePattern @* shellCommandWords /@ shellSplitCommands @ command, None ],
    "Complete" -> ! StringContainsQ[ command, "$(" | "`" | "<(" | ">(" ]
|>;

acpShellSavePatterns // endDefinition;


shellSavePattern // beginDefinition;
shellSavePattern[ { } ] := None;
shellSavePattern[ words_List ] /; MemberQ[ $shellDirectoryCommands, ToLowerCase @ First @ words ] := None;
shellSavePattern[ words: { __String } ] := StringRiffle[ shellCommandPrefix @ words, " " ] <> " *";
shellSavePattern // endDefinition;


(* OpenCode's prefix rule: the longest known prefix (up to 3 words) gives the number of words to keep; otherwise 1 *)
shellCommandPrefix // beginDefinition;
shellCommandPrefix[ words_List ] := Catch[
    Do[
        With[ { arity = Lookup[ $shellCommandArity, StringRiffle[ Take[ words, i ], " " ], None ] },
            If[ IntegerQ @ arity, Throw @ Take[ words, UpTo[ arity ] ] ]
        ],
        { i, Min[ Length @ words, 3 ], 1, -1 }
    ];
    Take[ words, 1 ]
];
shellCommandPrefix // endDefinition;


(* Splits a shell command into simple commands at unquoted &&, ||, ;, |, &, newlines and parentheses *)
shellSplitCommands // beginDefinition;

shellSplitCommands[ command_String ] := Module[ { chars, pieces = { }, current = "", quote = None, i = 1, n, c },
    chars = Characters @ command;
    n = Length @ chars;
    While[ i <= n,
        c = chars[[ i ]];
        Which[
            quote === None && c === "\\" && i < n,
                current = current <> c <> chars[[ i + 1 ]]; i += 2; Continue[ ],
            quote === None && MemberQ[ { "'", "\"" }, c ],
                quote = c; current = current <> c,
            quote =!= None && c === quote,
                quote = None; current = current <> c,
            quote === None && MemberQ[ { ";", "|", "&", "\n", "(", ")" }, c ] && ! (c === "&" && StringEndsQ[ current, ">" | "<" ]) && ! (c === "&" && i < n && chars[[ i + 1 ]] === ">"),
                AppendTo[ pieces, current ]; current = "",
            True,
                current = current <> c
        ];
        i++
    ];
    Select[ StringTrim /@ Append[ pieces, current ], StringLength[ # ] > 0 & ]
];

shellSplitCommands // endDefinition;


(* The words of a simple command as OpenCode sees them: leading variable assignments and redirections are not words *)
shellCommandWords // beginDefinition;

shellCommandWords[ piece_String ] := Module[ { tokens, words = { }, skipNext = False },
    tokens = StringCases[ piece, (("\"" ~~ Shortest[ ___ ] ~~ "\"") | ("'" ~~ Shortest[ ___ ] ~~ "'") | Except[ WhitespaceCharacter | "\"" | "'" ]).. ];
    Do[
        Which[
            skipNext, skipNext = False,
            StringMatchQ[ t, DigitCharacter... ~~ (">>" | ">" | "<<<" | "<<" | "<" | "&>>" | "&>" | ">&" | "<&" | ">|") ],
                skipNext = True, (* the target follows *)
            StringMatchQ[ t, DigitCharacter... ~~ (">>" | ">" | "<<<" | "<<" | "<" | "&>>" | "&>" | ">&" | "<&" | ">|") ~~ __ ],
                Null,
            words === { } && StringMatchQ[ t, (LetterCharacter | "_") ~~ (WordCharacter | "_")... ~~ "=" ~~ ___ ],
                Null,
            True,
                AppendTo[ words, t ]
        ],
        { t, tokens }
    ];
    words
];

shellCommandWords // endDefinition;


unquote // beginDefinition;
unquote[ s_String ] /; StringLength @ s >= 2 && MemberQ[ { "\"", "'" }, StringTake[ s, 1 ] ] && StringTake[ s, -1 ] === StringTake[ s, 1 ] :=
    StringTake[ s, { 2, -2 } ];
unquote[ s_String ] := s;
unquote // endDefinition;


$shellDirectoryCommands = { "cd", "chdir", "popd", "pushd", "push-location", "set-location" };

(* OpenCode's command arity table (from its bash tool): the number of words that identify a command *)
$shellCommandArity = <|
    "cat" -> 1, "cd" -> 1, "chmod" -> 1, "chown" -> 1, "cp" -> 1, "echo" -> 1, "env" -> 1, "export" -> 1, "grep" -> 1,
    "kill" -> 1, "killall" -> 1, "ln" -> 1, "ls" -> 1, "mkdir" -> 1, "mv" -> 1, "ps" -> 1, "pwd" -> 1, "rm" -> 1,
    "rmdir" -> 1, "sleep" -> 1, "source" -> 1, "tail" -> 1, "touch" -> 1, "unset" -> 1, "which" -> 1,
    "aws" -> 3, "az" -> 3, "bazel" -> 2, "brew" -> 2, "bun" -> 2, "bun run" -> 3, "bun x" -> 3, "cargo" -> 2,
    "cargo add" -> 3, "cargo run" -> 3, "cdk" -> 2, "cf" -> 2, "cmake" -> 2, "composer" -> 2, "consul" -> 2,
    "consul kv" -> 3, "crictl" -> 2, "deno" -> 2, "deno task" -> 3, "doctl" -> 3, "docker" -> 2, "docker builder" -> 3,
    "docker compose" -> 3, "docker container" -> 3, "docker image" -> 3, "docker network" -> 3, "docker volume" -> 3,
    "eksctl" -> 2, "eksctl create" -> 3, "firebase" -> 2, "flyctl" -> 2, "gcloud" -> 3, "gh" -> 3, "git" -> 2,
    "git config" -> 3, "git remote" -> 3, "git stash" -> 3, "go" -> 2, "gradle" -> 2, "helm" -> 2, "heroku" -> 2,
    "hugo" -> 2, "ip" -> 2, "ip addr" -> 3, "ip link" -> 3, "ip netns" -> 3, "ip route" -> 3, "kind" -> 2,
    "kind create" -> 3, "kubectl" -> 2, "kubectl kustomize" -> 3, "kubectl rollout" -> 3, "kustomize" -> 2, "make" -> 2,
    "mc" -> 2, "mc admin" -> 3, "minikube" -> 2, "mongosh" -> 2, "mysql" -> 2, "mvn" -> 2, "ng" -> 2, "npm" -> 2,
    "npm exec" -> 3, "npm init" -> 3, "npm run" -> 3, "npm view" -> 3, "npx" -> 2, "nvm" -> 2, "nx" -> 2,
    "openssl" -> 2, "openssl req" -> 3, "openssl x509" -> 3, "pip" -> 2, "pipenv" -> 2, "pnpm" -> 2, "pnpm dlx" -> 3,
    "pnpm exec" -> 3, "pnpm run" -> 3, "poetry" -> 2, "podman" -> 2, "podman container" -> 3, "podman image" -> 3,
    "psql" -> 2, "pulumi" -> 2, "pulumi stack" -> 3, "python" -> 2, "pyenv" -> 2, "rake" -> 2, "rbenv" -> 2,
    "redis-cli" -> 2, "rustup" -> 2, "serverless" -> 2, "sfdx" -> 3, "skaffold" -> 2, "sls" -> 2, "sst" -> 2,
    "swift" -> 2, "systemctl" -> 2, "terraform" -> 2, "terraform workspace" -> 3, "tmux" -> 2, "turbo" -> 2, "ufw" -> 2,
    "vault" -> 2, "vault auth" -> 3, "vault kv" -> 3, "vercel" -> 2, "volta" -> 2, "wp" -> 2, "yarn" -> 2,
    "yarn dlx" -> 3, "yarn run" -> 3
|>;


projectLabel // beginDefinition;
projectLabel[ dir_String ] /; dir =!= "" := dir;
projectLabel[ _ ] := "this project";
projectLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpToolbarStatusView*)

(* Connection status for the toolbar: "Connecting to OpenCode...", "OpenCode 2.0.26", errors with action buttons, etc.
   There is deliberately no "MCP starting" indicator: OpenCode often never sends the second available_commands_update
   that lists the MCP prompts (the MCP server's prompt listing can time out) even though its tools work; while a turn
   waits, the Working header says "Waiting for OpenCode... (MCP servers may still be starting)" instead. *)
acpToolbarStatusView // beginDefinition;

acpToolbarStatusView[ nbo_NotebookObject ] := stableDynamic[
    acpWindowSymbol @ nbo,
    statusSignature @ nbo,
    statusContent @ nbo
];

acpToolbarStatusView // endDefinition;


statusSignature // beginDefinition;
statusSignature[ nbo_NotebookObject ] := Replace[
    acpIsolated @ Replace[ acpWindowGet @ nbo, w_Association :> KeyTake[ w, { "Status", "Error", "AgentInfo", "Agent" } ] ],
    _Failure -> None
];
statusSignature // endDefinition;


statusContent // beginDefinition;
statusContent[ nbo_NotebookObject ] := Replace[ acpIsolated @ withRenderContext @ statusContent0 @ nbo, Except[ _RawBoxes ] :> RawBoxes[ "" ] ];
statusContent // endDefinition;


statusContent0 // beginDefinition;

statusContent0[ nbo_NotebookObject ] := Module[ { window, agent, version, view },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Return[ RawBoxes[ "" ], Module ] ];
    agent   = windowAgentName @ window;
    version = Replace[ Lookup[ Replace[ Lookup[ window, "AgentInfo", None ], Except[ _Association ] -> <| |> ], "Version", "" ], Except[ _String ] -> "" ];
    view = Switch[ Lookup[ window, "Status", None ],
        "NoDirectory",
            Style[ acpLabel[ "ToolbarNoDirectory" ], FontColor -> $mutedColor ],
        "Connecting",
            Row @ { chatbookIcon[ "PercolateProgressAnimation", False ], " ", Style[ acpLabel[ "ToolbarConnecting", <| "agent" -> agent |> ], FontColor -> $mutedColor ] },
        "Ready" | "Running",
            Style[ StringTrim @ acpLabel[ "ToolbarReady", <| "agent" -> agent, "version" -> version |> ], FontColor -> $mutedColor ],
        "Disconnected",
            Row @ {
                Style[ acpLabel[ "ToolbarDisconnected" ], FontColor -> $mutedColor ],
                " ",
                actionButton[ nbo, "Reconnect", agent ]
            },
        "Error",
            acpErrorView[ Replace[ Lookup[ window, "Error", None ], Except[ _Association ] -> <| "Message" -> acpLabel[ "ToolbarError" ] |> ], nbo, "Compact" ],
        _,
            ""
    ];
    RawBoxes @ ToBoxes @ Style[ view, FontSize -> 12 ]
];

statusContent0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpUsageMeterView*)

(* Context usage, e.g. "8.3k / 200k" (+ cost when known and nonzero); amber above 80%. *)
acpUsageMeterView // beginDefinition;

acpUsageMeterView[ nbo_NotebookObject ] := stableDynamic[
    acpWindowSymbol @ nbo,
    Replace[ acpIsolated @ acpWindowGet[ nbo, "Usage", None ], _Failure | _Missing -> None ],
    usageContent @ nbo
];

acpUsageMeterView // endDefinition;


usageContent // beginDefinition;
usageContent[ nbo_NotebookObject ] := Replace[
    acpIsolated @ withRenderContext @ RawBoxes @ ToBoxes @ usageMeter @ acpWindowGet[ nbo, "Usage", None ],
    Except[ _RawBoxes ] :> RawBoxes[ "" ]
];
usageContent // endDefinition;


usageMeter // beginDefinition;

usageMeter[ usage_Association ] := Module[ { used, size, cost, high },
    used = Lookup[ usage, "used", Lookup[ usage, "Used", None ] ];
    size = Lookup[ usage, "size", Lookup[ usage, "Size", None ] ];
    cost = Lookup[ usage, "cost", Lookup[ usage, "Cost", None ] ];
    If[ ! IntegerQ @ used || ! IntegerQ @ size || size <= 0, Return[ "", Module ] ];
    high = used / size > 0.8;
    Tooltip[
        Row @ Flatten @ {
            Style[ acpLabel[ "UsageMeter", <| "used" -> tokenCount @ used, "size" -> tokenCount @ size |> ], FontColor -> If[ high, $amberText, $mutedColor ] ],
            Replace[ costAmount @ cost, { a_? Positive :> { " \[CenterDot] ", Style[ acpLabel[ "UsageCost", <| "cost" -> ToString @ NumberForm[ a, { Infinity, 2 } ] |> ], FontColor -> $mutedColor ] }, _ -> Nothing } ]
        },
        Column @ DeleteCases[
            {
                acpLabel[ "UsageTooltip", <| "used" -> used, "size" -> size |> ],
                If[ high, acpLabel[ "UsageHigh" ], Nothing ]
            },
            Nothing
        ]
    ]
];

usageMeter[ _ ] := "";

usageMeter // endDefinition;


costAmount // beginDefinition;
costAmount[ KeyValuePattern[ "amount" -> a_? NumberQ ] ] := a;
costAmount[ a_? NumberQ ] := a;
costAmount[ _ ] := None;
costAmount // endDefinition;


tokenCount // beginDefinition;
tokenCount[ n_Integer ] := Which[
    n < 1000     , ToString @ n,
    n < 10000    , ToString @ NumberForm[ N[ n / 1000 ], { 2, 1 } ] <> "k",
    n < 1000000  , ToString @ Round[ n / 1000 ] <> "k",
    True         , ToString @ NumberForm[ N[ n / 1000000 ], { 3, 1 } ] <> "M"
];
tokenCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpErrorView*)

(* Chatbook-style error box with the friendly message, details, and action buttons. error is
   <| "Code", "Message", "Detail"/"Data", "Actions" -> { "Reconnect"|"ChooseModel"|"LocateAgent"|"SignIn"|... } |>.
   Buttons call ChatbookAction[ "ACP", action, nbo ]. *)
acpErrorView // beginDefinition;

acpErrorView[ error_Association ] := acpErrorView[ error, None, "Full" ];
acpErrorView[ error_Association, nbo_ ] := acpErrorView[ error, nbo, "Full" ];

acpErrorView[ error_Association, nbo_, mode_String ] := Module[ { message, detail, actions, buttons },
    message = Replace[ Lookup[ error, "Message", "" ], Except[ _String ] :> ToString @ Lookup[ error, "Code", "" ] ];
    detail  = Replace[ Lookup[ error, "Detail", None ], Except[ _String ] -> None ];
    actions = Replace[ Lookup[ error, "Actions", { } ], Except[ _List ] -> { } ];
    buttons = If[ MatchQ[ nbo, _NotebookObject ], actionButton[ nbo, #, "OpenCode" ] & /@ Select[ actions, StringQ ], { } ];
    If[ mode === "Compact",
        Row @ Flatten @ { Style[ "\:26a0 ", FontColor -> $redText ], Style[ message, FontColor -> $errorFont ], If[ buttons === { }, Nothing, { " ", Row[ buttons, Spacer[ 4 ] ] } ] },
        Framed[
            Grid[
                {
                    {
                        Style[ "\:26a0", FontColor -> $redText, FontSize -> 16 ],
                        Column[
                            DeleteCases[
                                {
                                    Style[ message, FontColor -> $errorFont, FontWeight -> "DemiBold" ],
                                    If[ StringQ @ detail, Style[ detail, FontColor -> $mutedColor, FontSize -> 12 ], None ],
                                    If[ buttons === { }, None, Row[ buttons, Spacer[ 6 ] ] ]
                                },
                                None
                            ],
                            Spacings -> 0.4
                        ]
                    }
                },
                Alignment -> { Left, Top },
                Spacings  -> { 0.6, 0 }
            ],
            Background     -> $errorBackground,
            FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], $errorFrame ],
            FrameMargins   -> { { 10, 10 }, { 8, 8 } },
            RoundingRadius -> 6,
            ImageMargins   -> { { 0, 0 }, { 6, 6 } },
            BaseStyle      -> { "Text", FontSize -> 13 }
        ]
    ]
];

acpErrorView[ _, ___ ] := "";

acpErrorView // endDefinition;


actionButton // beginDefinition;

(* "Locate OpenCode...": a file chooser (the dialog is run by the front end, so no kernel evaluation waits for it); the
   chosen file becomes the window's "ACPAgentExecutable" setting. *)
actionButton[ nbo_NotebookObject, "LocateAgent", agent_ ] := With[
    {
        setter = Function[
            Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", "SetAgentExecutable", nbo, # ]
        ]
    },
    FileNameSetter[
        Dynamic[ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACP", "AgentExecutable" } ], setter ],
        "Open",
        Appearance  -> buttonLabel[ Replace[ acpLabel[ "ActionLocateAgent", <| "agent" -> agent |> ], "ActionLocateAgent" -> "LocateAgent" ], "Secondary" ],
        BaseStyle   -> { "Text", FontSize -> 12 },
        WindowTitle -> acpLabel[ "LocateAgentDialogTitle", <| "agent" -> agent |> ]
    ]
];

actionButton[ nbo_NotebookObject, action_String, agent_ ] := With[ { n = nbo, a = action },
    Button[
        buttonLabel[ Replace[ acpLabel[ "Action" <> action, <| "agent" -> agent |> ], "Action" <> action -> action ], "Secondary" ],
        acpIsolated @ ChatbookAction[ "ACP", a, n ],
        Appearance -> None,
        Method     -> "Preemptive",
        BaseStyle  -> { "Text", FontSize -> 12 }
    ]
];

actionButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
