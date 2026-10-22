(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Attachments`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];
Needs[ "Wolfram`Chatbook`ACP`Common`"       ];

(* Attachments of the ACP window's messages (see docs/acp-window.md, "Attachments"): open notebooks and files of this
   computer that the user attaches to the next message with the "+" button at the input field.

   Rules:
   * The draft is the window record's "Attachments": references (notebook objects, file paths), never content, mirrored
     in the window's TaggingRules ({"ACP", "Attachments"}), so that it survives kernel restarts (R8). It belongs to one
     message: Send takes it (UI.wl's evaluateACPChat) and gives it back if the message is not sent.
   * The content is made when the message is sent, by a main link job (acpPrepareAttachmentsJob, queued with MCP.wl's
     acpMainLinkRun): converting notebooks (CellToString) and rasterizing graphics make front end calls and can take
     seconds, which no preemptive evaluation (the Send button, the pump) may do (R1, R3). The job checks between cells
     whether the preparation was cancelled (Stop, New), and hands its result to the pump (acpSchedule of UI.wl's
     acpPreparedPrompt), which starts or queues the turn.
   * Everything goes into the message's text block, after the typed text: one <attachment ...>...</attachment> block per
     attachment (acpPromptBlocks), so the agent tells them from what the user typed. Images (the graphics of notebooks,
     image files) are re-encoded (a bad image fails the preparation here, not the whole prompt at the agent) and sent as
     image blocks after the text block, with "[image n]" in the text, if the agent accepts images
     (promptCapabilities.image). Caps keep a message far below OpenCode's limits (20 MiB per attachment, 32 MiB per ACP
     message), with tighter ones for remote windows: ACPLink writes a message in one write, over ssh for them.
   * Notebooks, open ones and files, are read without evaluating anything in them (see "Reading Notebooks"): an attached
     notebook may come from anywhere, and its boxes can hold any expression.
   * Views: the "+" button and its menu (built when it is clicked), the draft's chips (a derived view, R6) and the user
     cell's chips, which are static boxes (inline options, front end resources, no kernel symbols), so a copied or saved
     cell renders anywhere. Names are display-safe (acpRemoteDisplayName); buttons name an attachment by its key, never by
     its name or path. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* Caps per message. "MessageBytes": the UTF-8 bytes of the text block and the base64 of the images; "Characters": the
   attachments' text (a notebook or file is cut with a note beyond it); "FileBytes": a file that is read; "Images": images
   sent; "ImageBytes": one re-encoded image (OpenCode's limits are 20 MiB per attachment and 32 MiB per ACP message). *)
$acpAttachmentLimits = <|
    "Local" -> <|
        "MessageBytes" -> 8 * 2^20,
        "Characters"   -> 600000,
        "FileBytes"    -> 8 * 2^20,
        "Images"       -> 10,
        "ImageBytes"   -> 3 * 2^20
    |>,
    "Remote" -> <|
        "MessageBytes" -> 2 * 2^20,
        "Characters"   -> 300000,
        "FileBytes"    -> 2 * 2^20,
        "Images"       -> 4,
        "ImageBytes"   -> 2^20
    |>
|>;

$acpMaxImageSize        = 1568; (* pixels of the longer side of an image that is sent *)
$acpImageResolution     = 144;  (* dpi at which graphics of notebooks are rasterized *)
$maxNotebookBytes       = 64 * 2^20;  (* a notebook (open, or a file) that is read: larger ones are refused *)
$maxDecompressedBytes   = 256 * 2^20; (* the memory that decompressing the data of graphics may take *)
$releaseSeconds         = 30;         (* the time and memory that evaluating the inert cells of a notebook may take *)
$releaseBytes           = 2^30;
$attachMenuNotebooks    = 15;   (* notebooks listed in the attach menu *)
$chipNameLength         = 32;   (* characters of an attachment's name on a chip (the tooltip has the whole name) *)
$menuTitleLength        = 40;   (* characters of a notebook's title in the attach menu *)
$binaryCheckBytes       = 8000; (* a NUL in the first bytes of a file means binary, as in git *)

$imageFormats = { "PNG", "JPEG", "GIF", "BMP", "WebP", "TIFF" };

(* Texts for the agent, not for the user (like the notebook tools' descriptions): they are not in the .tr files *)
$imagesNotSentNote = "[The [image n] placeholders stand for images that were not sent: the agent does not accept images.]";
$moreGraphicsNote  = "[More graphics of this notebook are shown as [graphics]: at most `1` images are sent with a message.]";
$noRoomNote        = "[More graphics of this notebook are shown as [graphics]: the message has no room for more images.]";
$fileCutNote       = "[The rest of this file is left out: it is too large to attach whole.]";

$$attachmentTag = ("/"|"") ~~ "attachment";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*State*)

(* Not reset if this file is reloaded during development. In the MX build they start out empty.
     $attachMenus        window -> the CellObject of its open attach menu
     $attachMenuEntries  window -> <| key -> listed notebook |> of the menu that was built last (its buttons pass keys) *)
If[ ! AssociationQ @ $attachMenus      , $attachMenus       = <| |> ];
If[ ! AssociationQ @ $attachMenuEntries, $attachMenuEntries = <| |> ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Draft*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpAttachmentRefs*)

(* The references of a draft (no content), without duplicates:
     <| "Kind" -> "Notebook", "Key", "Notebook" -> nbo, "Name" -> its file's name or window title, "Cells" -> n |>
     <| "Kind" -> "File", "Key", "Path" -> absolute path, "Name" -> file name, "Size" -> bytes |>
   A prompt notebook's message (PromptNotebook.wl) has a notebook reference with "Prompt" -> True, which never goes into
   the draft. Anything else (e.g. from TaggingRules a front end changed) is dropped. Rules lists (as the front end may
   give TaggingRules values back) are read as associations. *)
acpAttachmentRefs // beginDefinition;
acpAttachmentRefs[ refs_List ] := DeleteDuplicatesBy[ Select[ attachmentRef /@ refs, AssociationQ ], #[ "Key" ] & ];
acpAttachmentRefs[ _ ] := { };
acpAttachmentRefs // endDefinition;


attachmentRef // beginDefinition;

attachmentRef[ ref: { ___Rule } ] := attachmentRef @ Association @ ref;

attachmentRef[ ref: KeyValuePattern @ { "Kind" -> "Notebook", "Key" -> _String, "Notebook" -> _NotebookObject, "Name" -> _String } ] :=
    KeyTake[ ref, { "Kind", "Key", "Notebook", "Name", "Cells", "Prompt" } ];

attachmentRef[ ref: KeyValuePattern @ { "Kind" -> "File", "Key" -> _String, "Path" -> _String, "Name" -> _String } ] :=
    KeyTake[ ref, { "Kind", "Key", "Path", "Name", "Size" } ];

attachmentRef[ _ ] := Missing[ "NotAttachment" ];

attachmentRef // endDefinition;


(* The references of prepared attachments (to give them back to the draft) *)
acpAttachmentRefsOf // beginDefinition;
acpAttachmentRefsOf[ attachments_List ] := acpAttachmentRefs @ Cases[ attachments, KeyValuePattern[ "Ref" -> ref_ ] :> ref ];
acpAttachmentRefsOf[ _ ] := { };
acpAttachmentRefsOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Keys*)

(* Keys name attachments in button code and in the menu's entries: hashes, never names or paths *)
notebookKey // beginDefinition;
notebookKey[ nbo_NotebookObject ] := "nb-" <> IntegerString[ Hash[ nbo, "SHA256" ], 36 ];
notebookKey // endDefinition;

fileKey // beginDefinition;
fileKey[ path_String ] := "file-" <> IntegerString[ Hash[ path, "SHA256" ], 36 ];
fileKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpDraftAttachments*)
acpDraftAttachments // beginDefinition;
acpDraftAttachments[ window_Association ] := acpAttachmentRefs @ Lookup[ window, "Attachments", { } ];
acpDraftAttachments[ _ ] := { };
acpDraftAttachments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetDraftAttachments*)

(* The draft in the window record (never a partial record) and in the TaggingRules (R8) *)
acpSetDraftAttachments // beginDefinition;

acpSetDraftAttachments[ nbo_NotebookObject, refs0_List ] := With[ { refs = acpAttachmentRefs @ refs0 },
    acpWindowUpdate[ nbo, Function[ w, If[ KeyExistsQ[ w, "Status" ], <| w, "Attachments" -> refs |>, Missing[ "NotFound" ] ] ] ];
    acpFESet[ nbo, "Attachments", refs ];
    acpPublish[ ];
    refs
];

acpSetDraftAttachments // endDefinition;


(* Adds references to the draft (after the ones it has; one that is there already is not added again) *)
acpAddDraftAttachments // beginDefinition;
acpAddDraftAttachments[ nbo_NotebookObject, { } ] := acpDraftAttachments @ acpWindowGet @ nbo;
acpAddDraftAttachments[ nbo_NotebookObject, refs_List ] := acpSetDraftAttachments[ nbo, Join[ acpDraftAttachments @ acpWindowGet @ nbo, refs ] ];
acpAddDraftAttachments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*References*)

(* A listed notebook (NotebookTools.wl's acpAttachableNotebooks) as a reference: named by its file, else its window
   title. Makes front end calls. *)
notebookRef // beginDefinition;

notebookRef[ entry_Association ] := With[ { nbo = entry[ "NotebookObject" ] },
    <|
        "Kind"     -> "Notebook",
        "Key"      -> notebookKey @ nbo,
        "Notebook" -> nbo,
        "Name"     -> notebookName @ entry,
        "Cells"    -> Replace[ Quiet @ Cells @ nbo, { cells_List :> Length @ cells, _ -> None } ]
    |>
];

notebookRef // endDefinition;


notebookName // beginDefinition;

notebookName[ entry_Association ] := Which[
    StringQ @ entry[ "File" ] && StringLength @ entry[ "File" ] > 0, FileNameTake @ entry[ "File" ],
    StringQ @ entry[ "Title" ] && StringLength @ entry[ "Title" ] > 0, entry[ "Title" ],
    True, "Untitled"
];

notebookName // endDefinition;


(* An open notebook as a reference (PromptNotebook.wl: the prompt notebook of a message), named like the notebooks of
   the attach menu; Missing if it is not open. Makes front end calls. *)
acpNotebookAttachmentRef // beginDefinition;

acpNotebookAttachmentRef[ nbo_NotebookObject ] /; MemberQ[ Notebooks[ ], nbo ] := notebookRef @ <|
    "NotebookObject" -> nbo,
    "File"           -> Replace[ Quiet @ NotebookFileName @ nbo, Except[ _String ] -> None ],
    "Title"          -> Replace[ Quiet @ AbsoluteCurrentValue[ nbo, WindowTitle ], Except[ _String ] -> None ]
|>;

acpNotebookAttachmentRef[ _ ] := Missing[ "NotOpen" ];

acpNotebookAttachmentRef // endDefinition;


(* A file of this computer as a reference, or Missing for anything but a regular file *)
fileRef // beginDefinition;

fileRef[ File[ path_String ] ] := fileRef @ path;

fileRef[ path0_String ] := Module[ { path },
    path = Quiet @ ExpandFileName @ path0;
    If[ ! StringQ @ path || Quiet @ FileType @ path =!= File, Return[ Missing[ "NotFile" ], Module ] ];
    <|
        "Kind" -> "File",
        "Key"  -> fileKey @ path,
        "Path" -> path,
        "Name" -> FileNameTake @ path,
        "Size" -> Replace[ Quiet @ FileByteCount @ path, Except[ _Integer ] -> None ]
    |>
];

fileRef[ _ ] := Missing[ "NotFile" ];

fileRef // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpAttachmentsAction*)

(* ChatbookAction["ACP", name, nbo, args...] for the attachments (preemptive buttons, isolated by acpAction):
     "AttachMenu"        the "+" button: opens the attach menu
     "AttachNotebook"    a notebook of the menu (by the key of its entry)
     "AttachFiles"       the menu's file dialog (FileNameSetter, run by the front end): the chosen files
     "RemoveAttachment"  the x of a chip (by the attachment's key)
     "ShowAttachment"    a click on a notebook's chip: raises the notebook *)
acpAttachmentsAction // beginDefinition;

acpAttachmentsAction[ name_String, nbo_NotebookObject, args___ ] := (
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    attachmentsAction[ name, nbo, args ]
);

acpAttachmentsAction // endDefinition;


attachmentsAction // beginDefinition;
attachmentsAction[ "AttachMenu"      , nbo_NotebookObject                ] := toggleAttachMenu @ nbo;
attachmentsAction[ "AttachNotebook"  , nbo_NotebookObject, key_String    ] := attachNotebook[ nbo, key ];
attachmentsAction[ "AttachFiles"     , nbo_NotebookObject, files_        ] := attachFiles[ nbo, files ];
attachmentsAction[ "RemoveAttachment", nbo_NotebookObject, key_String    ] := removeAttachment[ nbo, key ];
attachmentsAction[ "ShowAttachment"  , nbo_NotebookObject, key_String    ] := showAttachment[ nbo, key ];
attachmentsAction[ name_, args___ ] := (acpLog[ "UnknownAction", { name, args } ]; Missing[ "UnknownAction", name ]);
attachmentsAction // endDefinition;


attachNotebook // beginDefinition;

attachNotebook[ nbo_NotebookObject, key_String ] := Module[ { entry },
    closeAttachMenu @ nbo;
    entry = Lookup[ Lookup[ $attachMenuEntries, nbo, <| |> ], key, None ];
    If[ ! AssociationQ @ entry || ! MemberQ[ Notebooks[ ], entry[ "NotebookObject" ] ], Return[ Null, Module ] ];
    acpAddDraftAttachments[ nbo, { notebookRef @ entry } ]
];

attachNotebook // endDefinition;


(* The front end's file dialog gives a file or a list of files ("OpenList"); folders and files that are gone are left
   out *)
attachFiles // beginDefinition;

attachFiles[ nbo_NotebookObject, files_ ] := Module[ { refs },
    closeAttachMenu @ nbo;
    refs = Select[ fileRef /@ Flatten @ { files }, AssociationQ ];
    If[ refs === { }, Null, acpAddDraftAttachments[ nbo, refs ] ]
];

attachFiles // endDefinition;


removeAttachment // beginDefinition;

removeAttachment[ nbo_NotebookObject, key_String ] :=
    acpSetDraftAttachments[ nbo, DeleteCases[ acpDraftAttachments @ acpWindowGet @ nbo, KeyValuePattern[ "Key" -> key ] ] ];

removeAttachment // endDefinition;


showAttachment // beginDefinition;

showAttachment[ nbo_NotebookObject, key_String ] := Replace[
    SelectFirst[ acpDraftAttachments @ acpWindowGet @ nbo, #[ "Key" ] === key &, None ],
    {
        KeyValuePattern @ { "Kind" -> "Notebook", "Notebook" -> target_NotebookObject } /; MemberQ[ Notebooks[ ], target ] :>
            (SetSelectedNotebook @ target; target),
        _ :> Null
    }
];

showAttachment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attach Menu*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpAttachButton*)

(* The "+" at the left of the input field: opens the attach menu, which is built when it is clicked (the open notebooks
   change all the time) *)
acpAttachButton // beginDefinition;

acpAttachButton[ nbo_NotebookObject ] := Tooltip[
    acpActionButton[
        blueHueButtonAppearance[
            chatbookIcon[ "WorkspaceToolbarIconSources", False, color @ "NA_BlueHueButtonIcon" ],
            { 24.5, 24.5 }
        ],
        { "AttachMenu", nbo },
        BoxID        -> "ACPAttachButton",
        FrameMargins -> 0
    ],
    acpLabel[ "AttachButtonTooltip" ]
];

acpAttachButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toggleAttachMenu*)

(* The menu is a cell attached to the "+" button (the evaluation box of its action), removed by a click outside it.
   It opens upwards from the input field at the bottom of the window, downwards from one at the top (an empty window).
   The "+" always opens a new menu: a click on it is a click outside an open menu, which the front end has removed by
   the time the action runs, so the kernel could not tell an open menu from one that was just closed. *)
toggleAttachMenu // beginDefinition;

toggleAttachMenu[ nbo_NotebookObject ] := (
    closeAttachMenu @ nbo;
    openAttachMenu @ nbo
);

toggleAttachMenu // endDefinition;


openAttachMenu // beginDefinition;

openAttachMenu[ nbo_NotebookObject ] := Module[ { entries, window, box, top, cell },
    If[ $FrontEnd === Null, Return[ Missing[ "NoFrontEnd" ], Module ] ];
    window  = acpWindowGet @ nbo;
    entries = Replace[ acpCatchAll @ acpAttachableNotebooks[ ], Except[ _List ] -> { } ];
    $attachMenuEntries[ nbo ] = Association[ notebookKey[ #[ "NotebookObject" ] ] -> # & /@ entries ];
    box = EvaluationBox[ ];
    If[ ! MatchQ[ box, _BoxObject ], Return[ Missing[ "NoButton" ], Module ] ];
    top  = Quiet @ Cells @ nbo === { };
    cell = AttachCell[
        box,
        attachMenuCell[ nbo, entries, window ],
        If[ top, { Left, Bottom }, { Left, Top } ],
        Offset[ { 0, If[ top, -2, 2 ] }, 0 ],
        If[ top, { Left, Top }, { Left, Bottom } ],
        RemovalConditions -> { "MouseClickOutside", "EvaluatorQuit" }
    ];
    If[ MatchQ[ cell, _CellObject ], $attachMenus[ nbo ] = cell ];
    cell
];

openAttachMenu // endDefinition;


(* True if a menu was open *)
closeAttachMenu // beginDefinition;

closeAttachMenu[ nbo_NotebookObject ] := With[ { cell = Lookup[ $attachMenus, nbo, None ] },
    KeyDropFrom[ $attachMenus, Key @ nbo ];
    If[ MatchQ[ cell, _CellObject ] && MatchQ[ Quiet @ ParentNotebook @ cell, _NotebookObject ],
        Quiet @ NotebookDelete @ cell;
        True,
        False
    ]
];

closeAttachMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachMenuCell*)

(* The menu: the open notebooks the notebook tools would list (front to back; those in the draft are checked and
   disabled), then "File..." (local windows) or "File on this computer..." (remote windows: the file is sent, its path is
   not), the front end's file dialog. Its buttons pass the key of a notebook's entry. *)
attachMenuCell // beginDefinition;

attachMenuCell[ nbo_NotebookObject, entries_List, window_ ] := Cell[
    BoxData @ ToBoxes @ attachMenuView[ nbo, entries, acpDraftAttachments @ window, acpRemoteQ @ window ],
    Background    -> None,
    CellFrame     -> 0,
    CellMargins   -> 0,
    CellTags      -> "ACPAttachMenu",
    Magnification -> Dynamic @ AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ]
];

attachMenuCell // endDefinition;


attachMenuView // beginDefinition;

attachMenuView[ nbo_NotebookObject, entries_List, draft_List, remote_ ] := Module[ { attached, shown, rows },
    attached = Lookup[ draft, "Key", { } ];
    shown    = Take[ entries, UpTo[ $attachMenuNotebooks ] ];
    rows     = Join[
        { menuHeader @ acpLabel[ "AttachMenuNotebooks" ] },
        If[ shown === { },
            { menuNote @ acpLabel[ "AttachMenuNoNotebooks" ] },
            menuNotebookRow[ nbo, #, MemberQ[ attached, notebookKey @ #[ "NotebookObject" ] ] ] & /@ shown
        ],
        If[ Length @ entries > Length @ shown,
            { menuNote @ acpLabel[ "AttachMenuMoreNotebooks", <| "n" -> Length @ entries - Length @ shown |> ] },
            { }
        ],
        { menuFileRow[ nbo, TrueQ @ remote ] }
    ];
    Framed[
        Column[ rows, Alignment -> Left, Dividers -> { None, { Length @ rows -> $menuFrame } }, Spacings -> { 0, { 0, { 0 }, 0.4, 0 } } ],
        Background     -> $menuBackground,
        BaseStyle      -> { FontFamily -> "Source Sans Pro", FontSize -> 13, LineBreakWithin -> False, $plainText },
        FrameMargins   -> { { 0, 0 }, { 4, 4 } },
        FrameStyle     -> $menuFrame,
        ImageSize      -> $menuWidth,
        RoundingRadius -> 4
    ]
];

attachMenuView // endDefinition;


menuNotebookRow // beginDefinition;

menuNotebookRow[ nbo_NotebookObject, entry_Association, attached_ ] := acpActionButton[
    menuRowLabel[
        $notebookIcon,
        acpRemoteDisplayName @ shorten[ Replace[ entry[ "Title" ], Except[ _String ] :> notebookName @ entry ], $menuTitleLength ],
        If[ TrueQ @ attached, Style[ "\[Checkmark]", FontColor -> $menuMuted ], "" ],
        ! TrueQ @ attached
    ],
    { "AttachNotebook", nbo, notebookKey @ entry[ "NotebookObject" ] },
    BoxID   -> "ACPAttachNotebook",
    Enabled -> ! TrueQ @ attached
];

menuNotebookRow // endDefinition;


(* The file dialog is run by the front end (FileNameSetter, several files at once); its setter runs the "AttachFiles"
   action. The value is a constant: the setter never stores anything. *)
menuFileRow // beginDefinition;

menuFileRow[ nbo_NotebookObject, remote_ ] := With[
    {
        setter = Function[
            Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", "AttachFiles", nbo, # ]
        ]
    },
    FileNameSetter[
        Dynamic[ "", setter ],
        "OpenList",
        Appearance  -> menuRowLabel[ $fileIcon, acpLabel @ If[ TrueQ @ remote, "AttachMenuFileLocal", "AttachMenuFile" ], "", True ],
        WindowTitle -> acpLabel[ "AttachFileDialogTitle" ]
    ]
];

menuFileRow // endDefinition;


menuRowLabel // beginDefinition;

menuRowLabel[ icon_, label_, right_, enabled_ ] := With[
    {
        row = Grid[
            { { iconPane @ icon, Style[ label, FontColor -> If[ TrueQ @ enabled, $menuFont, $menuMuted ] ], right } },
            Alignment -> { { Left, Left, Right }, Center },
            ItemSize  -> { { Automatic, Fit, Automatic } },
            Spacings  -> { 0.4, 0 }
        ]
    },
    If[ TrueQ @ enabled,
        Mouseover[ menuRowFrame[ row, None ], menuRowFrame[ row, $menuHover ] ],
        menuRowFrame[ row, None ]
    ]
];

menuRowLabel // endDefinition;


menuRowFrame // beginDefinition;

menuRowFrame[ row_, background_ ] := Framed[
    row,
    Background   -> background,
    FrameMargins -> { { 8, 8 }, { 2, 2 } },
    FrameStyle   -> None,
    ImageSize    -> { Full, Automatic }
];

menuRowFrame // endDefinition;


menuHeader // beginDefinition;
menuHeader[ text_String ] := Pane[ Style[ text, FontSize -> 11, FontColor -> $menuMuted ], FrameMargins -> { { 8, 8 }, { 2, 2 } } ];
menuHeader // endDefinition;

menuNote // beginDefinition;
menuNote[ text_String ] := Pane[ Style[ text, FontSlant -> Italic, FontColor -> $menuMuted ], FrameMargins -> { { 8, 8 }, { 2, 2 } } ];
menuNote // endDefinition;

$menuWidth      = 280;
$menuBackground := LightDarkSwitched[ GrayLevel[ 1 ], GrayLevel[ 0.16 ] ];
$menuFrame      := LightDarkSwitched[ GrayLevel[ 0.8 ], GrayLevel[ 0.35 ] ];
$menuHover      := color @ "NA_OverlayMenuItemBackgroundHover";
$menuFont       := color @ "NA_OverlayMenuFont";
$menuMuted      := acpColor[ "Muted" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Draft View*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpAttachmentsArea*)

(* Above the input field: the chips of the draft, and a note while the attachments of a message are prepared. A derived
   view (R6): it is rendered again only when the draft or the preparation changes. *)
acpAttachmentsArea // beginDefinition;
acpAttachmentsArea[ nbo_NotebookObject ] := acpWindowDerivedDynamic[ nbo, "Attachments", attachmentsSignature, attachmentsView ];
acpAttachmentsArea // endDefinition;


attachmentsSignature // beginDefinition;
attachmentsSignature[ window_Association ] := { acpDraftAttachments @ window, preparingCount @ window };
attachmentsSignature[ _ ] := None;
attachmentsSignature // endDefinition;


preparingCount // beginDefinition;
preparingCount[ window_Association ] := Replace[ Lookup[ window, "Preparing", None ], { KeyValuePattern[ "Attachments" -> a_List ] :> Length @ a, _ -> None } ];
preparingCount // endDefinition;


attachmentsView // beginDefinition;

attachmentsView[ nbo_NotebookObject ] := attachmentsView[ nbo, acpWindowGet @ nbo ];

attachmentsView[ nbo_NotebookObject, window_Association ] := Module[ { refs, preparing, items },
    refs      = acpDraftAttachments @ window;
    preparing = preparingCount @ window;
    items     = {
        If[ IntegerQ @ preparing, preparingNote @ preparing, Nothing ],
        If[ refs === { }, Nothing, Row[ draftChip[ nbo, # ] & /@ refs, Spacer[ 4 ] ] ]
    };
    If[ items === { },
        Spacer[ { 0, 0 } ],
        Pane[
            Column[ items, Alignment -> Left, Spacings -> 0.3 ],
            BaseStyle    -> { LineBreakWithin -> Automatic, LineIndent -> 0 },
            ImageMargins -> { { 0, 0 }, { 4, 0 } },
            ImageSize    -> { Full, Automatic }
        ]
    ]
];

attachmentsView[ _, _ ] := Spacer[ { 0, 0 } ];

attachmentsView // endDefinition;


preparingNote // beginDefinition;

preparingNote[ n_Integer ] := Row @ {
    chatbookIcon[ "PercolateProgressAnimation", False ],
    " ",
    Style[
        If[ n === 1, acpLabel[ "AttachmentsPreparingOne" ], acpLabel[ "AttachmentsPreparing", <| "n" -> n |> ] ],
        FontFamily -> "Source Sans Pro",
        FontSize   -> 12,
        FontSlant  -> Italic,
        FontColor  -> acpColor[ "Muted" ]
    ]
};

preparingNote // endDefinition;


(* A chip of the draft: the attachment's icon and name (a click raises a notebook), its kind and size in the tooltip, and
   an x that removes it *)
draftChip // beginDefinition;

draftChip[ nbo_NotebookObject, ref_Association ] := Framed[
    Grid[
        {
            {
                Tooltip[
                    If[ ref[ "Kind" ] === "Notebook",
                        acpActionButton[ chipLabel @ ref, { "ShowAttachment", nbo, ref[ "Key" ] }, BoxID -> "ACPShowAttachment" ],
                        chipLabel @ ref
                    ],
                    chipTooltip @ ref
                ],
                Tooltip[
                    acpActionButton[ $chipCloseGlyph, { "RemoveAttachment", nbo, ref[ "Key" ] }, BoxID -> "ACPRemoveAttachment" ],
                    acpLabel[ "AttachmentRemove" ]
                ]
            }
        },
        Alignment -> { Left, Center },
        Spacings  -> { 0.3, 0 }
    ],
    $chipFrameOptions
];

draftChip // endDefinition;


$chipCloseGlyph := Style[ "\[Times]", FontSize -> 13, FontColor -> GrayLevel[ 0.5 ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Chips*)

(* The parts of a chip, shared by the draft's chips and the user cell's (acpUserCellExpr), which are static boxes: inline
   options, front end resources (icons) and built-in boxes only *)
chipLabel // beginDefinition;

chipLabel[ a_Association ] := Row @ {
    iconPane @ chipIcon @ a,
    Spacer[ 3 ],
    Style[
        acpRemoteDisplayName @ shorten[ Replace[ Lookup[ a, "Name", "" ], Except[ _String ] -> "" ], $chipNameLength ],
        FontFamily      -> "Source Sans Pro",
        FontSize        -> 12,
        FontColor       -> $chipFont,
        LineBreakWithin -> False,
        $plainText
    ]
};

chipLabel // endDefinition;


(* Files get the review window's icon for their extension (Review.wl's acpFileIcon: static boxes) *)
chipIcon // beginDefinition;
chipIcon[ KeyValuePattern[ "Kind" -> "Notebook" ] ] := $notebookIcon;
chipIcon[ KeyValuePattern[ "Name" -> name_String ] ] := RawBoxes @ acpFileIcon @ name;
chipIcon[ _ ] := RawBoxes @ acpFileIcon @ { "ExtFile" };
chipIcon // endDefinition;


(* "Notebook, 12 cells", "File, 3.4 kB, /path/x.csv" (joined with a centered dot; paths display-safe) *)
chipTooltip // beginDefinition;

chipTooltip[ a_Association ] := Style[
    StringRiffle[
        {
            acpLabel @ Switch[ a[ "Kind" ], "Notebook", "AttachmentNotebook", "Image", "AttachmentImage", _, "AttachmentFile" ],
            Replace[ Lookup[ a, "Cells", None ], { n_Integer :> cellCountLabel @ n, _ -> Nothing } ],
            Replace[ Lookup[ a, "Size", None ], { n_Integer :> acpByteSizeLabel @ n, _ -> Nothing } ],
            Replace[ Lookup[ a, "Images", { } ], { l: { __ } :> imageCountLabel @ Length @ l, _ -> Nothing } ],
            Replace[ Lookup[ a, "Path", None ], { p_String :> acpRemoteDisplayName @ p, _ -> Nothing } ]
        },
        " \[CenterDot] "
    ],
    $plainText
];

chipTooltip // endDefinition;


cellCountLabel // beginDefinition;
cellCountLabel[ 1 ] := acpLabel[ "AttachmentCellsOne" ];
cellCountLabel[ n_Integer ] := acpLabel[ "AttachmentCells", <| "n" -> n |> ];
cellCountLabel // endDefinition;

imageCountLabel // beginDefinition;
imageCountLabel[ 1 ] := acpLabel[ "AttachmentImagesOne" ];
imageCountLabel[ n_Integer ] := acpLabel[ "AttachmentImages", <| "n" -> n |> ];
imageCountLabel // endDefinition;


(* "512 bytes", "3.4 kB", "12.1 MB" (powers of 1000, as file managers show sizes) *)
acpByteSizeLabel // beginDefinition;
acpByteSizeLabel[ n_Integer ] /; n < 1000 := acpLabel[ "AttachmentBytes", <| "n" -> n |> ];
acpByteSizeLabel[ n_Integer ] /; n < 10^6 := acpLabel[ "AttachmentKilobytes", <| "n" -> decimal[ n / 1000 ] |> ];
acpByteSizeLabel[ n_Integer ] := acpLabel[ "AttachmentMegabytes", <| "n" -> decimal[ n / 10^6 ] |> ];
acpByteSizeLabel // endDefinition;

decimal // beginDefinition;
decimal[ x_ ] := With[ { r = Round[ x, 0.1 ] }, If[ r == Round @ r, ToString @ Round @ r, ToString @ NumberForm[ N @ r, { Infinity, 1 } ] ] ];
decimal // endDefinition;


shorten // beginDefinition;
shorten[ s_String, n_Integer ] := If[ StringLength @ s > n, StringTake[ s, n - 1 ] <> "\[Ellipsis]", s ];
shorten // endDefinition;


iconPane // beginDefinition;
iconPane[ icon_ ] := Pane[ icon, ImageSize -> { 14, 14 }, ImageSizeAction -> "ShrinkToFit", BaselinePosition -> Scaled[ 0.2 ], ContentPadding -> False ];
iconPane // endDefinition;


(* The front end's notebook icon (as the Notebook Assistant's Sources show it; the colors are put into the front end's
   Dynamic as values) and a page for "File..." *)
$notebookIcon := With[ { gray = color @ "NA_OverlayMenuNotebookIcon_Gray", red = color @ "NA_OverlayMenuNotebookIcon_Red" },
    RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "FEBitmaps", "NotebookIcon" ][ gray, red ] ]
];

$fileIcon := RawBoxes @ acpFileIcon @ { "ExtFile" };

$plainText = PrivateFontOptions -> { "OperatorSubstitution" -> False };

$chipFont := color @ "NA_OverlayMenuFont";

$chipFrameOptions := Sequence[
    Background     -> LightDarkSwitched[ GrayLevel[ 0.95 ], GrayLevel[ 0.22 ] ],
    BaselinePosition -> Baseline,
    FrameMargins   -> { { 4, 4 }, { 1, 1 } },
    FrameStyle     -> LightDarkSwitched[ GrayLevel[ 0.82 ], GrayLevel[ 0.38 ] ],
    RoundingRadius -> 3
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*User Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpUserCellExpr*)

(* The user cell of a message (ChatModes/Evaluate.wl's workspaceChatInputCellExpr) with a row of static chips for its
   attachments after the typed text (prepared attachments, or the <| "Kind", "Name", "Path" |> of a replayed message).
   The chips' inline cell has CellToStringData ("[Attached notebook: Spec.nb]"), so a chat converted from the window
   shows the attachments by name. Without attachments it is the cell of today. *)
acpUserCellExpr // beginDefinition;

acpUserCellExpr[ input_, { }, uuid_String ] := workspaceChatInputCellExpr[ input, uuid ];

acpUserCellExpr[ input_, attachments_List, uuid_String ] := Replace[
    workspaceChatInputCellExpr[ input, uuid ],
    Cell[ BoxData[ TemplateBox[ { Cell[ content_, opts___ ] }, "UserMessageBox", t___ ] ], rest___ ] :>
        Cell[ BoxData @ TemplateBox[ { Cell[ withChips[ content, attachments ], opts ] }, "UserMessageBox", t ], rest ]
];

acpUserCellExpr // endDefinition;


withChips // beginDefinition;
withChips[ "", attachments_ ] := TextData @ { chipsCell @ attachments };
withChips[ TextData[ items_List ], attachments_ ] := TextData @ Join[ items, { "\n", chipsCell @ attachments } ];
withChips[ TextData[ item_ ], attachments_ ] := TextData @ { item, "\n", chipsCell @ attachments };
withChips[ content_, attachments_ ] := TextData @ { content, "\n", chipsCell @ attachments };
withChips // endDefinition;


chipsCell // beginDefinition;

(* The text is the TaggingRules' "CellToStringData" of a TagBox around the chips, which CellToString uses for the box
   (it does not for an inline cell) *)
chipsCell[ attachments_List ] := Cell[
    BoxData @ TagBox[
        ToBoxes @ Style[ Row[ staticChip /@ attachments, Spacer[ 4 ] ], "Text" ],
        "ACPAttachments",
        TaggingRules -> <| "CellToStringData" -> StringRiffle[ attachmentText /@ attachments, "\n" ] |>
    ],
    "Text",
    Background -> None
];

chipsCell // endDefinition;


staticChip // beginDefinition;
staticChip[ a_Association ] := Tooltip[ Framed[ chipLabel @ a, $chipFrameOptions ], chipTooltip @ a ];
staticChip // endDefinition;


(* "[Attached notebook: Spec.nb]" (the name as it is, for the text of a converted chat) *)
attachmentText // beginDefinition;

attachmentText[ a_Association ] := acpLabel[
    Switch[ a[ "Kind" ], "Notebook", "UserCellAttachmentNotebook", "Image", "UserCellAttachmentImage", _, "UserCellAttachmentFile" ],
    <| "name" -> acpRemoteDisplayName @ Replace[ Lookup[ a, "Name", "" ], Except[ _String ] -> "" ] |>
];

attachmentText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptCapabilities*)

(* What the window's agent accepts in prompts (promptCapabilities of its initialize response; "Known" -> False before
   it) *)
acpPromptCapabilities // beginDefinition;

acpPromptCapabilities[ window_Association ] := With[ { caps = Lookup[ window, "Capabilities", None ] },
    <|
        "Known"           -> AssociationQ @ caps,
        "Image"           -> promptCapabilityQ[ caps, "image" ],
        "Audio"           -> promptCapabilityQ[ caps, "audio" ],
        "EmbeddedContext" -> promptCapabilityQ[ caps, "embeddedContext" ]
    |>
];

acpPromptCapabilities[ _ ] := <| "Known" -> False, "Image" -> False, "Audio" -> False, "EmbeddedContext" -> False |>;

acpPromptCapabilities // endDefinition;


promptCapabilityQ // beginDefinition;
promptCapabilityQ[ caps_, name_String ] := MatchQ[ caps, KeyValuePattern[ "promptCapabilities" -> KeyValuePattern[ name -> True ] ] ];
promptCapabilityQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptBlocks*)

(* The "prompt" of session/prompt (pure): the text block first (OpenCode's slash commands and the mock agent's scenario
   selection read it), then the images. A message without attachments gives exactly one text block with the typed text.
   With attachments the text block is the typed text, then one block per attachment:
     <attachment type="notebook" name="Spec.nb">
     ...markdown...
     </attachment>
     <attachment type="file" name="data.csv" path="/abs/data.csv">
     ...
     </attachment>
   (the path only for local windows: a remote agent can't read this computer's files). Attribute values are escaped,
   and "<attachment" and "</attachment" in the content and in the typed text are made inert (acpInertAttachmentTags),
   so nothing closes a block early or passes for one. Images are image blocks after the text block (their "[image n]" in
   the text) if the agent accepts images (capabilities: the agentCapabilities of the initialize response); otherwise a
   note says that the placeholders stand for images that were not sent. *)
acpPromptBlocks // beginDefinition;

acpPromptBlocks[ text_String, { }, _, _ ] := { <| "type" -> "text", "text" -> text |> };

acpPromptBlocks[ text_String, attachments: { __Association }, capabilities_, remote_ ] := Module[ { images, imageQ, parts },
    images = SortBy[ Catenate @ Replace[ Lookup[ attachments, "Images", { } ], Except[ _List ] -> { }, { 1 } ], Lookup[ #, "Number", 0 ] & ];
    imageQ = promptCapabilityQ[ capabilities, "image" ];
    parts  = Join[
        If[ StringTrim @ text === "", { }, { acpInertAttachmentTags @ text } ],
        attachmentBlock[ #, TrueQ @ remote ] & /@ attachments,
        If[ images =!= { } && ! imageQ, { $imagesNotSentNote }, { } ]
    ];
    Join[
        { <| "type" -> "text", "text" -> StringRiffle[ parts, "\n\n" ] |> },
        If[ imageQ, imageBlock /@ images, { } ]
    ]
];

(* a turn without (valid) attachments *)
acpPromptBlocks[ text_String, _, _, _ ] := acpPromptBlocks[ text, { }, None, False ];

acpPromptBlocks // endDefinition;


attachmentBlock // beginDefinition;

attachmentBlock[ a_Association, remote_ ] := StringJoin[
    "<attachment",
    tagAttribute[ "type", If[ a[ "Kind" ] === "Notebook", "notebook", "file" ] ],
    tagAttribute[ "name", Replace[ Lookup[ a, "Name", "" ], Except[ _String ] -> "" ] ],
    If[ ! TrueQ @ remote && StringQ @ Lookup[ a, "Path", None ], tagAttribute[ "path", a[ "Path" ] ], "" ],
    ">\n",
    acpInertAttachmentTags @ Replace[ Lookup[ a, "Text", "" ], Except[ _String ] -> "" ],
    "\n</attachment>"
];

attachmentBlock // endDefinition;


tagAttribute // beginDefinition;

tagAttribute[ name_String, value_String ] := StringJoin[
    " ", name, "=\"",
    StringReplace[ value, { "&" -> "&amp;", "\"" -> "&quot;", "<" -> "&lt;", ">" -> "&gt;", "\r\n" | "\n" | "\r" | "\t" -> " " } ],
    "\""
];

tagAttribute // endDefinition;


imageBlock // beginDefinition;
imageBlock[ image_Association ] := <| "type" -> "image", "mimeType" -> image[ "MimeType" ], "data" -> BaseEncode @ image[ "Data" ] |>;
imageBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpInertAttachmentTags*)

(* Text in a message's text block never passes for an attachment's tags: the "<" of "<attachment" and "</attachment" (in
   any case) is written as "&lt;", and text that already looks like such an escape ("&lt;attachment", "&amp;lt;...",
   ...) gets one more "amp;", so acpUninertAttachmentTags reverses it exactly (the replay of a restored session shows the
   typed text as it was typed). Both rules run in one pass, like NotebookTools.wl's inertTags. *)
acpInertAttachmentTags // beginDefinition;

acpInertAttachmentTags[ text_String ] := StringReplace[
    text,
    {
        "&" ~~ escape: ("amp;"... ~~ "lt;" ~~ $$attachmentTag) :> "&amp;" <> escape,
        "<" ~~ tag: $$attachmentTag :> "&lt;" <> tag
    },
    IgnoreCase -> True
];

acpInertAttachmentTags // endDefinition;


acpUninertAttachmentTags // beginDefinition;

acpUninertAttachmentTags[ text_String ] := StringReplace[
    text,
    {
        "&amp;" ~~ escape: ("amp;"... ~~ "lt;" ~~ $$attachmentTag) :> "&" <> escape,
        "&lt;" ~~ tag: $$attachmentTag :> "<" <> tag
    },
    IgnoreCase -> True
];

acpUninertAttachmentTags // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpParseAttachmentBlocks*)

(* The typed text and the attachments of a message's text block as acpPromptBlocks made it (pure; a restored session's
   replay, Sessions.wl): <| "Text" -> the typed text, "Attachments" -> { <| "Kind", "Name", "Path" |>... } |> (names and
   paths unescaped, not display-safe yet). The blocks start at the beginning of the text or after a blank line; text
   without them is all typed text. *)
acpParseAttachmentBlocks // beginDefinition;

acpParseAttachmentBlocks[ text_String ] := Module[ { start, blocks },
    start = First[ StringPosition[ text, $blockStartRegex, 1 ], None ];
    If[ start === None, Return[ <| "Text" -> text, "Attachments" -> { } |>, Module ] ];
    blocks = StringCases[
        StringDrop[ text, First @ start - 1 ],
        RegularExpression[ $blockRegex ] :> parsedAttachment[ "$1", "$2", "$3" ]
    ];
    If[ blocks === { }, Return[ <| "Text" -> text, "Attachments" -> { } |>, Module ] ];
    <|
        "Text"        -> acpUninertAttachmentTags @ StringTrim @ StringTake[ text, First @ start - 1 ],
        "Attachments" -> blocks
    |>
];

acpParseAttachmentBlocks // endDefinition;


$blockStartRegex = RegularExpression[ "(?:^|\\n\\n)<attachment type=\"(?:notebook|file)\" name=\"" ];
$blockRegex      = "(?s)<attachment type=\"(notebook|file)\" name=\"([^\"]*)\"(?: path=\"([^\"]*)\")?>\\n.*?\\n</attachment>";


parsedAttachment // beginDefinition;

parsedAttachment[ type_String, name_String, path_String ] := <|
    "Kind" -> If[ type === "notebook", "Notebook", "File" ],
    "Name" -> unescapeAttribute @ name,
    If[ path === "", Nothing, "Path" -> unescapeAttribute @ path ]
|>;

parsedAttachment // endDefinition;


unescapeAttribute // beginDefinition;
unescapeAttribute[ s_String ] := StringReplace[ s, { "&quot;" -> "\"", "&lt;" -> "<", "&gt;" -> ">", "&amp;" -> "&" } ];
unescapeAttribute // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Preparation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPrepareAttachmentsJob*)

(* The main link job of a message with attachments (queued by UI.wl's evaluateACPChat with acpMainLinkRun): makes the
   content of the attachments of the window's "Preparing" (references), and hands the result to the pump
   (acpPreparedPrompt, UI.wl): <| "Attachments" -> prepared |> or a Failure with a "Notice" for the user. The job stops
   at the next cell once the preparation was cancelled (another token), and an abort (Alt+.) hands over a failure, so the
   draft goes back to the input field. *)
acpPrepareAttachmentsJob // beginDefinition;

acpPrepareAttachmentsJob[ nbo_NotebookObject, token_String ] := Module[ { prep, result },
    prep = Lookup[ Replace[ acpWindowGet @ nbo, Except[ _Association ] -> <| |> ], "Preparing", None ];
    If[ ! MatchQ[ prep, KeyValuePattern[ "Token" -> token ] ], Return[ Null, Module ] ];
    result = attachmentFailure[ "NoticeAttachmentsFailed", <| |> ];
    WithCleanup[
        result = acpCatchAll[
            prepareAttachments[ nbo, token, prep ],
            (acpLog[ "AttachmentsFailed", <| "Value" -> #1, "Tag" -> #2 |> ]; attachmentFailure[ "NoticeAttachmentsFailed", <| |> ]) &
        ],
        With[ { r = result }, acpSchedule @ acpPreparedPrompt[ nbo, token, r ] ]
    ]
];

acpPrepareAttachmentsJob // endDefinition;


(* Whether the preparation with token is still the window's (Stop, New and the timeout cancel it) *)
preparingQ // beginDefinition;
preparingQ[ nbo_NotebookObject, token_String ] := MatchQ[ acpWindowGet[ nbo, "Preparing", None ], KeyValuePattern[ "Token" -> token ] ];
preparingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prepareAttachments*)

prepareAttachments // beginDefinition;
prepareAttachments[ nbo_NotebookObject, token_String, prep_Association ] := acpPrepareAttachments[ nbo, Function[ preparingQ[ nbo, token ] ], prep ];
prepareAttachments // endDefinition;


(* The attachments (references) of prep for a message of the window nbo, with its caps and what its agent accepts:
   <| "Attachments" -> prepared |> or a Failure with a "Notice". activeQ is checked before each attachment and each cell:
   once it gives False, the preparation stops (Failure["Cancelled", ...]). Also used for a prompt notebook's message
   (PromptNotebook.wl), whose preparation is not the window's "Preparing". ctx: what the conversion of each attachment
   needs, and what the typed text and the attachments before it used ("ImageCount" of images, "Characters" of text,
   "Bytes" of the message: UTF-8 of the text, base64 of the images). *)
acpPrepareAttachments // beginDefinition;

acpPrepareAttachments[ nbo_NotebookObject, activeQ_, prep_Association ] := Catch[
    Module[ { window, caps, text, ctx, prepared, item },
        window = acpWindowGet @ nbo;
        caps   = acpPromptCapabilities @ window;
        text   = Replace[ Lookup[ prep, "Text", "" ], Except[ _String ] -> "" ];
        ctx    = <|
            "Remote"     -> acpRemoteQ @ window,
            "Limits"     -> attachmentLimits @ window,
            (* before the agent said what it accepts, images are made anyway; acpPromptBlocks decides when it sends *)
            "ImagesQ"    -> ! caps[ "Known" ] || caps[ "Image" ],
            "Agent"      -> Replace[ Lookup[ window, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ],
            "ActiveQ"    -> activeQ,
            "ImageCount" -> 0,
            "Characters" -> 0,
            "Bytes"      -> utf8Length @ text
        |>;
        prepared = Internal`Bag[ ];
        Do[
            If[ ! TrueQ @ activeQ[ ], Throw[ Failure[ "Cancelled", <| |> ], $attachmentTag ] ];
            { item, ctx } = prepareAttachment[ ref, ctx ];
            Internal`StuffBag[ prepared, item ],
            { ref, acpAttachmentRefs @ Lookup[ prep, "Attachments", { } ] }
        ];
        prepared = Internal`BagPart[ prepared, All ];
        checkMessageSize[ text, prepared, ctx ];
        <| "Attachments" -> prepared |>
    ],
    $attachmentTag
];

acpPrepareAttachments // endDefinition;


attachmentLimits // beginDefinition;
attachmentLimits[ window_ ] := $acpAttachmentLimits[ If[ acpRemoteQ @ window, "Remote", "Local" ] ];
attachmentLimits // endDefinition;


(* A failure that ends the preparation; its "Notice" is shown above the input field *)
attachmentFailure // beginDefinition;

attachmentFailure[ key_String, params_Association ] := Failure[ "AttachmentError", <|
    "MessageTemplate" -> "The attachments could not be prepared.",
    "Code"            -> key,
    "Notice"          -> acpLabel[ key, params ]
|> ];

attachmentFailure // endDefinition;


throwAttachment // beginDefinition;
throwAttachment[ key_String, params_Association ] := Throw[ attachmentFailure[ key, params ], $attachmentTag ];
throwAttachment // endDefinition;

$attachmentTag = "Wolfram`Chatbook`ACP`Attachments`Failure";


(* The whole message: its text (UTF-8) and the base64 of its images, within "MessageBytes" *)
checkMessageSize // beginDefinition;

checkMessageSize[ text_String, prepared_List, ctx_Association ] := Module[ { bytes, max },
    bytes = Total @ Join[
        { utf8Length @ text },
        utf8Length /@ Cases[ prepared, KeyValuePattern[ "Text" -> t_String ] :> t ],
        imageBytes /@ Catenate @ Cases[ prepared, KeyValuePattern[ "Images" -> l_List ] :> l ]
    ];
    max = ctx[ "Limits", "MessageBytes" ];
    If[ bytes > max,
        throwAttachment[ "NoticeAttachmentsTooLarge", <| "size" -> acpByteSizeLabel @ bytes, "max" -> acpByteSizeLabel @ max |> ]
    ];
    bytes
];

checkMessageSize // endDefinition;


utf8Length // beginDefinition;
utf8Length[ s_String ] := Length @ StringToByteArray[ s, "UTF-8" ];
utf8Length // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMessageSize*)

(* What a message (its typed text and prepared attachments) takes of the caps of one message: { bytes (the UTF-8 of its
   texts and the base64 of its images, as checkMessageSize counts them), images, characters of the attachments' text }.
   UI.wl merges queued messages into one only as far as they fit together (acpMessageFitsQ). *)
acpMessageSize // beginDefinition;

acpMessageSize[ text_String, attachments_List ] := With[
    {
        texts  = Cases[ attachments, KeyValuePattern[ "Text" -> t_String ] :> t ],
        images = Catenate @ Cases[ attachments, KeyValuePattern[ "Images" -> l_List ] :> l ]
    },
    {
        Total @ Join[ { utf8Length @ text }, utf8Length /@ texts, imageBytes /@ images ],
        Length @ images,
        Total[ StringLength /@ texts ]
    }
];

acpMessageSize // endDefinition;


(* Whether a message of that size (acpMessageSize) stays within the caps of one message of the window *)
acpMessageFitsQ // beginDefinition;

acpMessageFitsQ[ window_, { bytes_, images_, characters_ } ] := With[ { limits = attachmentLimits @ window },
    bytes <= limits[ "MessageBytes" ] && images <= limits[ "Images" ] && characters <= limits[ "Characters" ]
];

acpMessageFitsQ // endDefinition;


(* The bytes of an image in the message: its data as base64 *)
imageBytes // beginDefinition;
imageBytes[ image_Association ] := 4 * Ceiling[ Length @ image[ "Data" ] / 3 ];
imageBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prepareAttachment*)

(* One attachment: { prepared, ctx } or a thrown failure. Prepared attachments: <| "Kind", "Name", "Path" (files),
   "Ref" (the reference, to give it back to the draft), "Text", "Images" -> { <| "Number", "MimeType", "Data" |>... },
   "Cells" (notebooks), "Size" (files), "Truncated" |> *)
prepareAttachment // beginDefinition;

prepareAttachment[ ref: KeyValuePattern[ "Kind" -> "Notebook" ], ctx_Association ] := Module[ { name, cells },
    name  = acpRemoteDisplayName @ ref[ "Name" ];
    cells = notebookCells @ ref[ "Notebook" ];
    Replace[ cells, {
        _Missing :> throwAttachment[ "NoticeAttachmentClosed", <| "name" -> name |> ],
        Failure[ "NotebookTooLarge", KeyValuePattern[ "Size" -> size_ ] ] :> throwAttachment[
            "NoticeAttachmentTooLarge",
            <| "name" -> name, "size" -> acpByteSizeLabel @ size, "max" -> acpByteSizeLabel @ $maxNotebookBytes |>
        ],
        Except[ { ___Cell } ] :> throwAttachment[ "NoticeAttachmentNotebookUnreadable", <| "name" -> name |> ]
    } ];
    notebookAttachment[ ref, None, cells, ctx ]
];

(* A notebook file can be larger than other files: only its text and some of its graphics go into the message *)
prepareAttachment[ ref: KeyValuePattern[ "Kind" -> "File" ], ctx_Association ] := Module[ { path, name, nb, size, max, bytes },
    path = ref[ "Path" ];
    name = acpRemoteDisplayName @ ref[ "Name" ];
    nb   = MemberQ[ { "nb", "cdf" }, ToLowerCase @ FileExtension @ path ];
    If[ Quiet @ FileType @ path =!= File, throwAttachment[ "NoticeAttachmentMissing", <| "name" -> name |> ] ];
    size = Quiet @ FileByteCount @ path;
    max  = If[ nb, $maxNotebookBytes, ctx[ "Limits", "FileBytes" ] ];
    If[ ! IntegerQ @ size, throwAttachment[ "NoticeAttachmentMissing", <| "name" -> name |> ] ];
    If[ size > max,
        throwAttachment[ "NoticeAttachmentTooLarge", <| "name" -> name, "size" -> acpByteSizeLabel @ size, "max" -> acpByteSizeLabel @ max |> ]
    ];
    bytes = readFileBytes[ path, size ];
    If[ ! ByteArrayQ @ bytes, throwAttachment[ "NoticeAttachmentMissing", <| "name" -> name |> ] ];
    Which[
        nb,
            notebookAttachment[ <| ref, "Size" -> size |>, path, notebookFileCells[ bytes, name ], ctx ],
        StringQ @ acpImageFormat @ bytes,
            imageFileAttachment[ <| ref, "Size" -> size |>, bytes, ctx ],
        True,
            textFileAttachment[ <| ref, "Size" -> size |>, bytes, ctx ]
    ]
];

prepareAttachment // endDefinition;


(* Exactly n bytes from a stream of its own (never a device or pipe: the file is a regular file of that size) *)
readFileBytes // beginDefinition;

readFileBytes[ _String, 0 ] := ByteArray[ { } ];

readFileBytes[ path_String, n_Integer ] := Module[ { stream },
    stream = Quiet @ OpenRead[ path, BinaryFormat -> True ];
    If[ ! MatchQ[ stream, _InputStream ], Return[ $Failed, Module ] ];
    WithCleanup[ Quiet @ ReadByteArray[ stream, n ], Quiet @ Close @ stream ]
];

readFileBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookAttachment*)

(* An open notebook's cells, or the cells of a notebook file (as notebookCells and notebookFileCells read them): markdown
   (NotebookTools.wl's acpNotebookMarkdown), with its graphics rasterized as images ("[image n]" in the text, n counting
   the images of the whole message) while images can be sent and the message has room for them, else "[graphics]".
   Whether an image fits is known once the text is: fittedImages keeps the images whose placeholders are in the text (a
   cell that was cut or left out may have had some) and that fit into the message with it, and numbers them again. *)
notebookAttachment // beginDefinition;

notebookAttachment[ ref_Association, path_, cells_List, ctx_Association ] := Module[
    { count, made, skippedMax, skippedRoom, images, graphics, md, fitted, text, kept },
    count       = ctx[ "ImageCount" ];
    made        = 0; (* bytes of the images made so far *)
    skippedMax  = 0;
    skippedRoom = 0;
    images      = Internal`Bag[ ];
    graphics = Function[ box,
        Which[
            ! TrueQ @ ctx[ "ImagesQ" ],
                "[graphics]",
            count >= ctx[ "Limits", "Images" ],
                skippedMax++;
                "[graphics]",
            ctx[ "Bytes" ] + made >= ctx[ "Limits", "MessageBytes" ],
                skippedRoom++;
                "[graphics]",
            True,
                Replace[
                    rasterizedImage[ box, ctx[ "Limits", "ImageBytes" ] ],
                    {
                        image_Association :> (
                            count++;
                            made += imageBytes @ image;
                            Internal`StuffBag[ images, <| image, "Number" -> count |> ];
                            imagePlaceholder @ count
                        ),
                        _ :> "[graphics]"
                    }
                ]
        ]
    ];
    md = acpNotebookMarkdown[
        cells,
        <| "Graphics" -> graphics, "MaxCharacters" -> charactersLeft @ ctx, "ActiveQ" -> ctx[ "ActiveQ" ] |>
    ];
    If[ FailureQ @ md, Throw[ md, $attachmentTag ] ];
    fitted = fittedImages[ md[ "Markdown" ], Internal`BagPart[ images, All ], ctx ];
    kept   = fitted[ "Images" ];
    text   = StringJoin[
        fitted[ "Text" ],
        If[ skippedMax > 0, "\n\n" <> TemplateApply[ $moreGraphicsNote, { ctx[ "Limits", "Images" ] } ], "" ],
        If[ skippedRoom > 0 || fitted[ "Dropped" ], "\n\n" <> $noRoomNote, "" ]
    ];
    {
        <|
            "Kind"      -> ref[ "Kind" ],
            "Name"      -> ref[ "Name" ],
            "Path"      -> path,
            "Ref"       -> ref,
            "Text"      -> text,
            "Images"    -> kept,
            "Cells"     -> md[ "Cells" ],
            "Size"      -> Lookup[ ref, "Size", None ],
            "Truncated" -> md[ "Truncated" ]
        |>,
        <|
            ctx,
            "ImageCount" -> ctx[ "ImageCount" ] + Length @ kept,
            "Characters" -> ctx[ "Characters" ] + StringLength @ text,
            "Bytes"      -> ctx[ "Bytes" ] + utf8Length @ text + Total[ imageBytes /@ kept ]
        |>
    }
];

notebookAttachment // endDefinition;


charactersLeft // beginDefinition;
charactersLeft[ ctx_Association ] := Max[ 1, ctx[ "Limits", "Characters" ] - ctx[ "Characters" ] ];
charactersLeft // endDefinition;


(* The images of a notebook's markdown (numbered from ctx's "ImageCount" + 1 on) that go into the message: only those
   whose "[image n]" is in the text (the cell of one may have been cut or left out), and, from the last one on, only as
   many as fit into the message with the text (the others become "[graphics]" again: "Dropped"); numbered again without
   gaps. <| "Text", "Images", "Dropped" |> *)
fittedImages // beginDefinition;

fittedImages[ text0_String, images0_List, ctx_Association ] := Module[ { text, images, dropped, numbers },
    text    = text0;
    images  = Select[ images0, StringContainsQ[ text, imagePlaceholder[ #[ "Number" ] ] ] & ];
    dropped = False;
    While[
        images =!= { } && ctx[ "Bytes" ] + utf8Length @ text + Total[ imageBytes /@ images ] > ctx[ "Limits", "MessageBytes" ],
        text    = StringReplace[ text, imagePlaceholder[ Last[ images ][ "Number" ] ] -> "[graphics]" ];
        images  = Most @ images;
        dropped = True
    ];
    numbers = Lookup[ images, "Number", { } ];
    If[ numbers =!= ctx[ "ImageCount" ] + Range @ Length @ numbers,
        With[ { renumbered = acpRenumberImages[ { <| "Text" -> text, "Images" -> images |> }, ctx[ "ImageCount" ] ] },
            text   = renumbered[[ 1, "Text" ]];
            images = renumbered[[ 1, "Images" ]]
        ]
    ];
    <| "Text" -> text, "Images" -> images, "Dropped" -> dropped |>
];

fittedImages // endDefinition;


imagePlaceholder // beginDefinition;
imagePlaceholder[ n_Integer ] := "[image " <> ToString @ n <> "]";
imagePlaceholder // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpRenumberImages*)

(* The images of prepared attachments numbered offset + 1, offset + 2, ... in their order, and "[image n]" in their texts
   with them (one pass, so a new number is never taken for an old one). Used for the images that fit into a message
   (fittedImages) and for a merged queued message (UI.wl's queuedBatch), whose attachments were prepared for
   different messages, each numbering its images from 1. *)
acpRenumberImages // beginDefinition;

acpRenumberImages[ attachments_List ] := acpRenumberImages[ attachments, 0 ];

acpRenumberImages[ attachments_List, offset_Integer ] := Module[ { n = offset },
    Map[
        Function[ a,
            Module[ { images, map },
                images = Replace[ Lookup[ a, "Images", { } ], Except[ { ___Association } ] -> { } ];
                map    = Association @ Table[ image[ "Number" ] -> ++n, { image, images } ];
                If[ AllTrue[ Normal @ map, First[ # ] === Last[ # ] & ],
                    a,
                    <|
                        a,
                        "Text"   -> renumberedText[ Replace[ Lookup[ a, "Text", "" ], Except[ _String ] -> "" ], map ],
                        "Images" -> (<| #, "Number" -> map[ #[ "Number" ] ] |> & /@ images)
                    |>
                ]
            ]
        ],
        attachments
    ]
];

acpRenumberImages // endDefinition;


renumberedText // beginDefinition;

renumberedText[ text_String, map_Association ] := StringReplace[
    text,
    "[image " ~~ n: DigitCharacter.. ~~ "]" /; KeyExistsQ[ map, FromDigits @ n ] :> imagePlaceholder @ map @ FromDigits @ n
];

renumberedText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*imageFileAttachment*)

(* An image file: re-encoded (acpEncodeImage) and sent as an image block, "[image n]" its text. Refused when the agent
   does not accept images or the message has as many images as it may have. *)
imageFileAttachment // beginDefinition;

imageFileAttachment[ ref_Association, bytes_ByteArray, ctx_Association ] := Module[ { name, image, n },
    name = acpRemoteDisplayName @ ref[ "Name" ];
    If[ ! TrueQ @ ctx[ "ImagesQ" ], throwAttachment[ "NoticeAttachmentNoImages", <| "name" -> name, "agent" -> ctx[ "Agent" ] |> ] ];
    If[ ctx[ "ImageCount" ] >= ctx[ "Limits", "Images" ],
        throwAttachment[ "NoticeAttachmentTooManyImages", <| "max" -> ctx[ "Limits", "Images" ] |> ]
    ];
    image = acpReencodeImage[ bytes, ctx[ "Limits", "ImageBytes" ] ];
    If[ ! AssociationQ @ image, throwAttachment[ "NoticeAttachmentImage", <| "name" -> name |> ] ];
    n = ctx[ "ImageCount" ] + 1;
    {
        <|
            "Kind"      -> "File",
            "Name"      -> ref[ "Name" ],
            "Path"      -> ref[ "Path" ],
            "Ref"       -> ref,
            "Text"      -> imagePlaceholder @ n,
            "Images"    -> { <| image, "Number" -> n |> },
            "Size"      -> Lookup[ ref, "Size", None ],
            "Truncated" -> False
        |>,
        <| ctx, "ImageCount" -> n, "Bytes" -> ctx[ "Bytes" ] + utf8Length @ imagePlaceholder @ n + imageBytes @ image |>
    }
];

imageFileAttachment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*textFileAttachment*)

(* A text file (UTF-8, no NUL, few control characters): its text, cut with a note where the message has no more room.
   Other files are refused: an agent gets nothing useful from them (OpenCode drops binary files it can't show). *)
textFileAttachment // beginDefinition;

textFileAttachment[ ref_Association, bytes_ByteArray, ctx_Association ] := Module[ { text, left, cut },
    text = acpFileText @ bytes;
    If[ ! StringQ @ text, throwAttachment[ "NoticeAttachmentBinary", <| "name" -> acpRemoteDisplayName @ ref[ "Name" ] |> ] ];
    left = charactersLeft @ ctx;
    cut  = StringLength @ text > left;
    If[ cut, text = StringTake[ text, left ] <> "\n\n" <> $fileCutNote ];
    {
        <|
            "Kind"      -> "File",
            "Name"      -> ref[ "Name" ],
            "Path"      -> ref[ "Path" ],
            "Ref"       -> ref,
            "Text"      -> text,
            "Images"    -> { },
            "Size"      -> Lookup[ ref, "Size", None ],
            "Truncated" -> cut
        |>,
        <| ctx, "Characters" -> ctx[ "Characters" ] + StringLength @ text, "Bytes" -> ctx[ "Bytes" ] + utf8Length @ text |>
    }
];

textFileAttachment // endDefinition;


(* The text of a file's bytes, or None for a binary file (a NUL in its first bytes, bytes that are not UTF-8, or more than
   30% control characters, as OpenCode tells text files); a byte order mark is dropped and line ends become "\n" *)
acpFileText // beginDefinition;

acpFileText[ bytes_ByteArray ] := Module[ { text },
    If[ Length @ bytes === 0, Return[ "", Module ] ];
    If[ MemberQ[ Normal @ bytes[[ 1 ;; Min[ Length @ bytes, $binaryCheckBytes ] ]], 0 ], Return[ None, Module ] ];
    text = Quiet @ Check[ ByteArrayToString[ bytes, "UTF-8" ], $Failed ];
    If[ ! StringQ @ text, Return[ None, Module ] ];
    If[ StringCount[ text, RegularExpression[ "[\\x00-\\x08\\x0E-\\x1F\\x7F]" ] ] > 0.3 * StringLength @ text, Return[ None, Module ] ];
    StringReplace[ StringDelete[ text, StartOfString ~~ "\:feff" ], "\r\n" | "\r" -> "\n" ]
];

acpFileText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Reading Notebooks*)

(* Notebooks, open ones and files, are read without evaluating anything in them: an attached notebook may come from
   anywhere (a notebook the user opened, a file of a download folder), and its boxes can hold any expression, in options,
   interpretations and dynamic content, or in place of boxes. NotebookRead (and NotebookGet) would hand the kernel an open
   notebook's cells as an expression, which the kernel evaluates; so the front end writes an open notebook as the text of
   a notebook file (ExportPacket "NotebookString"), which is read like a notebook file (notebookTextCells):
   * The text is parsed held (inertHeld), and only if it has no linear syntax ("\!", "\(", "\*", or their characters)
     outside its strings and comments: the parser interprets such boxes, which runs code (a TemplateBox's
     InterpretationFunction runs although the result is held, verified in 15.0.1); the front end never writes that. The
     symbols that are new go to a context of their own, which is removed afterwards.
   * Every symbol of the held cells that is not inert ($inertSymbols: the heads of boxes, the options of boxes, cells and
     graphics, and some values) becomes inertSymbol["context`name"], and CompressedData[...] becomes inertCompressed[...]
     (inertCells); only then are the cells evaluated, within a time and memory limit (a last line of defense against
     large expressions). So nothing in them can run code: not their evaluation, not their conversion (CellToString
     evaluates the interpretations of some boxes), not the front end when it rasterizes their graphics (displayBoxes,
     which decompresses the data of the graphics that are rasterized).
   * What CellToString would parse and evaluate is made safe (NotebookTools.wl's acpDefusedCells, shared with the
     ReadNotebook tool): linear syntax in strings is neutralized (also "\!" typed as two characters, which it reads in
     a string literal), an inline WL code template is its code (CellToString runs it), videos and audio are
     placeholders (it would import them), raw data cells are text, and an inline InterpretationFunction is dropped. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookCells*)

(* The cells of an open notebook (front end calls) as notebookTextCells reads its text, or Missing if it is no longer
   open *)
notebookCells // beginDefinition;

notebookCells[ nbo_NotebookObject ] := If[ MemberQ[ Notebooks[ ], nbo ],
    Replace[
        Quiet @ FrontEndExecute @ FrontEnd`ExportPacket[ nbo, "NotebookString" ],
        { { text_String, ___ } :> notebookTextCells @ text, _ :> Missing[ "NotOpen" ] }
    ],
    Missing[ "NotOpen" ]
];

notebookCells[ _ ] := Missing[ "NotOpen" ];

notebookCells // endDefinition;


(* The cells of a notebook file (UTF-8, else Latin-1), or a thrown failure *)
notebookFileCells // beginDefinition;

notebookFileCells[ bytes_ByteArray, name_String ] := Replace[
    notebookTextCells @ Replace[
        Quiet @ Check[ ByteArrayToString[ bytes, "UTF-8" ], $Failed ],
        Except[ _String ] :> FromCharacterCode @ Normal @ bytes
    ],
    Except[ { ___Cell } ] :> throwAttachment[ "NoticeAttachmentUnreadable", <| "name" -> name |> ]
];

notebookFileCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookTextCells*)

(* The cells of a notebook file's text, inert and defused, cell groups flattened; Failure["NotebookTooLarge", ...] or
   $Failed (linear syntax outside strings, not one notebook, too large to evaluate) *)
notebookTextCells // beginDefinition;

notebookTextCells[ text_String ] /; StringLength @ text > $maxNotebookBytes :=
    Failure[ "NotebookTooLarge", <| "MessageTemplate" -> "The notebook is too large to attach.", "Size" -> StringLength @ text |> ];

notebookTextCells[ text_String ] := Module[ { held, cells },
    If[ StringContainsQ[ StringDelete[ text, $stringsAndComments ], $$linearSyntax ], Return[ $Failed, Module ] ];
    held  = parsedHeld @ text;
    (* a notebook file is comments and one Notebook expression (the front end's files: Nulls for the comments) *)
    cells = WithCleanup[
        Replace[
            Cases[ held, Notebook[ c_List, ___ ] :> inertHeld @ c, { 1 } ],
            { { c_inertHeld } :> releasedHeld @ inertCells @ c, _ -> $Failed }
        ],
        removeParsedSymbols[ ]
    ];
    If[ ListQ @ cells, acpDefusedCells @ Cases[ flattenCells @ cells, _Cell ], $Failed ]
];

notebookTextCells // endDefinition;


(* String literals (with their escapes) and comments of Wolfram Language input (comments as the front end writes them in
   notebook files: not nested). One that is not closed ends with the text, so that the search for its end is done once
   (an unclosed comment is a syntax error anyway). *)
$stringsAndComments = RegularExpression[ "(?s)\"(?:[^\"\\\\]++|\\\\.)*+(?:\"|\\z)|\\(\\*.*?(?:\\*\\)|\\z)" ];
$$linearSyntax      = RegularExpression[ "\\\\[!(*]|[\\x{f7c0}-\\x{f7cd}]" ];


(* The text parsed held, its new symbols in a context of their own *)
parsedHeld // beginDefinition;

parsedHeld[ text_String ] := Block[ { $Context = $parsedContext, $ContextPath = { "System`" } },
    Quiet @ ToExpression[ text, InputForm, inertHeld ]
];

parsedHeld // endDefinition;


removeParsedSymbols // beginDefinition;
removeParsedSymbols[ ] := With[ { names = $parsedContext <> "*" }, Quiet @ Remove @ names; Null ];
removeParsedSymbols // endDefinition;

$parsedContext = "Wolfram`Chatbook`ACP`Attachments`Parsed`";


flattenCells // beginDefinition;
flattenCells[ cells_List ] := cells //. Cell[ CellGroupData[ group_List, ___ ], ___ ] :> Sequence @@ group;
flattenCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inertCells*)

(* A held expression of a notebook (inertHeld[...]) with every symbol that is not inert replaced (with
   inertSymbol["context`name"]), CompressedData[...] with inertCompressed[...], and NCache[exact, approximate] with the
   approximate number; still held. Nothing is evaluated: symbols are compared by name (inertSymbolQ holds them). *)
inertCells // beginDefinition;

inertCells[ held_inertHeld ] := Module[ { h, rules },
    h = held /. {
        HoldPattern[ CompressedData[ s_String ] ] :> inertCompressed @ s,
        HoldPattern[ NCache[ _, x: (_Real | _Integer) ] ] :> x
    };
    rules = Cases[
        DeleteDuplicates @ Cases[ h, s_Symbol :> inertHeld @ s, { 0, Infinity }, Heads -> True ],
        inertHeld[ s_ ] /; ! inertSymbolQ @ s :> (HoldPattern @ s -> inertSymbol @ symbolFullName @ s)
    ];
    If[ rules === { }, h, h /. Dispatch @ rules ]
];

inertCells // endDefinition;


(* The held expression evaluated (nothing but inert symbols is left in it) within $releaseSeconds and $releaseBytes, or
   $Failed *)
releasedHeld // beginDefinition;
releasedHeld[ inertHeld[ e_ ] ] := MemoryConstrained[ TimeConstrained[ e, $releaseSeconds, $Failed ], $releaseBytes, $Failed ];
releasedHeld[ _ ] := $Failed;
releasedHeld // endDefinition;


inertSymbolQ // beginDefinition;
inertSymbolQ // Attributes = { HoldAllComplete };
inertSymbolQ[ s_Symbol ] := TrueQ @ Lookup[ $inertSymbols, symbolFullName @ s, False ];
inertSymbolQ // endDefinition;


symbolFullName // beginDefinition;
symbolFullName // Attributes = { HoldAllComplete };
symbolFullName[ s_Symbol ] := Context @ Unevaluated @ s <> SymbolName @ Unevaluated @ s;
symbolFullName // endDefinition;


(* Holds an expression of a notebook that was read (it is never evaluated until nothing but inert symbols is left in it) *)
inertHeld // Attributes = { HoldAllComplete };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$inertSymbols*)

(* The symbols that stay in the cells of a notebook that is read (inertCells), by full name: cells and their content, the
   heads of boxes, the options of boxes, cells and graphics (the kernel's Options), and values of options and graphics
   directives. None of them does anything when it is evaluated, also as a head. Made when it is first needed. *)
$inertSymbols := $inertSymbols = Module[ { heads, options },
    heads   = Symbol[ "System`" <> # ] & /@ Join[ $inertBoxNames, $optionHeadNames ];
    options = Cases[ Flatten[ Quiet[ Keys @ Options @ # ] & /@ heads ], s_Symbol :> symbolFullName @ s ];
    AssociationMap[
        True &,
        Union[
            "System`" <> # & /@ Join[ $inertBoxNames, $inertValueNames ],
            options,
            { symbolFullName @ inertHeld, symbolFullName @ inertCompressed }
        ]
    ]
];

$inertBoxNames = {
    "ActionMenuBox", "AdjustmentBox", "AnimatorBox", "Arrow3DBox", "ArrowBox", "Axis3DBox", "AxisBox", "BezierCurve3DBox",
    "BezierCurveBox", "BSplineCurve3DBox", "BSplineCurveBox", "BSplineSurface3DBox", "ButtonBox", "CheckboxBox",
    "CircleBox", "ColorSetterBox", "ConeBox", "ConicHullRegion3DBox", "ConicHullRegionBox", "CounterBox", "CuboidBox",
    "CylinderBox", "DiskBox", "DynamicBox", "DynamicModuleBox", "DynamicWrapperBox", "ErrorBox", "FilledCurveBox",
    "FormBox", "FractionBox", "FrameBox", "GeometricTransformation3DBox", "GeometricTransformationBox", "Graphics3DBox",
    "GraphicsBox", "GraphicsComplex3DBox", "GraphicsComplexBox", "GraphicsGridBox", "GraphicsGroup3DBox",
    "GraphicsGroupBox", "GridBox", "HexahedronBox", "InputFieldBox", "Inset3DBox", "InsetBox", "InterpretationBox",
    "ItemBox", "JoinedCurveBox", "LabeledGraphicsBox", "Line3DBox", "LineBox", "ListPickerBox", "LocatorBox",
    "LocatorPaneBox", "NamespaceBox", "OpenerBox", "OptionValueBox", "OverlayBox", "OverscriptBox", "PaneBox", "PanelBox",
    "PaneSelectorBox", "Point3DBox", "PointBox", "Polygon3DBox", "PolygonBox", "PolyhedronBox", "PopupMenuBox",
    "PrismBox", "ProgressIndicatorBox", "PyramidBox", "RadicalBox", "RadioButtonBox", "Raster3DBox", "RasterBox",
    "RectangleBox", "RotationBox", "RowBox", "SetterBox", "Slider2DBox", "SliderBox", "SphereBox", "SqrtBox", "StyleBox",
    "SubscriptBox", "SubsuperscriptBox", "SuperscriptBox", "TableViewBox", "TabViewBox", "TagBox", "TemplateArgBox",
    "TemplateBox", "TetrahedronBox", "Text3DBox", "TextBox", "TogglerBox", "TooltipBox", "TubeBezierCurveBox", "TubeBox",
    "TubeBSplineCurveBox", "UnderoverscriptBox", "UnderscriptBox", "ValueBox"
};

$optionHeadNames = {
    "Button", "Cell", "Column", "Framed", "Graphics", "Graphics3D", "Grid", "Image", "Inset", "Notebook", "Pane", "Panel",
    "Row", "Style", "Text", "Tooltip"
};

$inertValueNames = {
    (* cells and structure *)
    "Notebook", "Cell", "CellGroupData", "BoxData", "TextData", "StyleData", "RawData", "Open", "Closed",
    "List", "Rule", "RuleDelayed", "Association", "Null", "True", "False", "None", "Automatic", "All", "Inherited", "Full",
    "Function", "Slot", "SlotSequence", "Annotation", "URL", "TraditionalForm", "StandardForm", "InputForm", "OutputForm",
    (* options of cells that the kernel does not list *)
    "CellChangeTimes", "ExpressionUUID", "CellLabel", "CellTags", "CellID", "CellGroupingRules", "CellOpen",
    "GeneratedCell", "CellAutoOverwrite", "ShowCellLabel", "CellDingbat", "CellMargins", "CellFrame", "CellFrameMargins",
    "InitializationCell", "CellSize", "ButtonData", "ButtonNote", "ButtonFunction", "ButtonSource", "Active",
    "Magnification", "RasterInterpolation", "ColorFunction", "ColorFunctionScaling",
    (* numbers (no arithmetic: 10^10^10 is short; NCache[exact, number] is its number) *)
    "Infinity", "DirectedInfinity", "Rational", "Complex", "Pi", "E", "GoldenRatio", "Degree", "NCache", "NumericArray",
    "ByteArray",
    (* values *)
    "Bold", "Italic", "Plain", "Underlined", "Larger", "Smaller", "Tiny", "Small", "Medium", "Large", "Center", "Left",
    "Right", "Top", "Bottom", "Baseline", "Axis", "Before", "After", "Offset", "Scaled", "ImageScaled",
    (* colors and graphics directives *)
    "RGBColor", "GrayLevel", "Hue", "CMYKColor", "LABColor", "LCHColor", "LUVColor", "XYZColor", "Opacity", "Directive",
    "EdgeForm", "FaceForm", "Thickness", "AbsoluteThickness", "PointSize", "AbsolutePointSize", "Dashing",
    "AbsoluteDashing", "Arrowheads", "CapForm", "JoinForm", "Specularity", "Glow", "Thick", "Thin", "Dashed", "Dotted",
    "DotDashed", "Transparent"
};

(* Cells read from a notebook are made safe for CellToString by NotebookTools.wl's acpDefusedCells (shared with the
   ReadNotebook tool), applied here in notebookTextCells after the cells are inert. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*displayBoxes*)

(* The boxes of a notebook's graphics (inert, as notebookTextCells read them) as the front end is to rasterize them: their
   data decompressed (and made inert like the cells, within $maxDecompressedBytes), without what makes them interactive
   (dynamic content, interpretations, tags, tooltips), without the options whose values are inert and without inert
   primitives (such as the mouse-over style of a bar); Missing if anything inert is left, which the front end would show
   as an error *)
displayBoxes // beginDefinition;

displayBoxes[ box_ ] := Module[ { b },
    (* graphics boxes hold their arguments (RuleCondition: replacements are evaluated in them), so arrays written out in
       the notebook are made here (numbers only are left in them) *)
    b = box /. inertCompressed[ s_String ] :> RuleCondition @ decompressedData @ s;
    b = b /. HoldPattern[ (h: NumericArray | ByteArray)[ args___ ] ] :> RuleCondition @ h @ args;
    b = b //. $interactiveBoxRules;
    (* boxes hold their arguments: a Sequence[ ] in their options would stay *)
    b = DeleteCases[ b, (Rule | RuleDelayed)[ _, v_ ] /; ! FreeQ[ v, $$inert ], Infinity ];
    b = b //. list: { ___, _inertSymbol[ ___ ] | _inertSymbol, ___ } :> RuleCondition @ DeleteCases[ list, _inertSymbol[ ___ ] | _inertSymbol ];
    If[ FreeQ[ b, $$inert ], b, Missing[ "Inert" ] ]
];

displayBoxes // endDefinition;


$$inert = _inertSymbol | _inertCompressed;

$interactiveBoxRules = {
    DynamicBox[ content_List, ___ ]   :> content, (* e.g. the mouse-over style of a bar, and the bar *)
    DynamicBox[ ___ ]                 :> { },
    DynamicModuleBox[ _, body_, ___ ] :> body,
    DynamicWrapperBox[ body_, ___ ]   :> body,
    InterpretationBox[ body_, ___ ]   :> body,
    TagBox[ body_, ___ ]              :> body,
    TooltipBox[ body_, ___ ]          :> body
};


(* The data of CompressedData[s], inert like a notebook's cells, or something inert if it can't be decompressed within
   $maxDecompressedBytes (a small text can decompress to gigabytes) *)
decompressedData // beginDefinition;

decompressedData[ s_String ] := Replace[
    MemoryConstrained[ Quiet @ Uncompress[ s, inertHeld ], $maxDecompressedBytes, $Failed ],
    {
        held: inertHeld[ _ ] :> Replace[ releasedHeld @ inertCells @ held, $Failed -> inertSymbol[ "System`CompressedData" ] ],
        _ :> inertSymbol[ "System`CompressedData" ]
    }
];

decompressedData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Images*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpImageFormat*)

(* The format of an image file's bytes, by their signature: "PNG", "JPEG", "GIF", "BMP", "WebP", "TIFF", or None *)
acpImageFormat // beginDefinition;

acpImageFormat[ bytes_ByteArray ] := With[ { head = Normal @ bytes[[ 1 ;; Min[ 12, Length @ bytes ] ]] },
    Which[
        MatchQ[ head, { 137, 80, 78, 71, 13, 10, 26, 10, ___ } ], "PNG",
        MatchQ[ head, { 255, 216, 255, ___ } ], "JPEG",
        MatchQ[ head, { 71, 73, 70, 56, ___ } ], "GIF",
        MatchQ[ head, { 66, 77, ___ } ] && Length @ bytes > 26, "BMP",
        MatchQ[ head, { 82, 73, 70, 70, _, _, _, _, 87, 69, 66, 80 } ], "WebP",
        MatchQ[ head, { 73, 73, 42, 0, ___ } | { 77, 77, 0, 42, ___ } ], "TIFF",
        True, None
    ]
];

acpImageFormat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReencodeImage*)

(* An image file's bytes decoded and encoded again (acpEncodeImage), so that what is sent is always a valid image: an
   image block that the agent can't decode fails the whole prompt (OpenCode: "Image could not be decoded"). Gives
   <| "MimeType", "Data", "Width", "Height" |> or a Failure. *)
acpReencodeImage // beginDefinition;

acpReencodeImage[ bytes_ByteArray, maxBytes_Integer ] := Module[ { format, image },
    format = acpImageFormat @ bytes;
    If[ ! StringQ @ format, Return[ Failure[ "ImageUnreadable", <| "MessageTemplate" -> "The image could not be read." |> ], Module ] ];
    image = Quiet @ ImportByteArray[ bytes, format ];
    If[ MatchQ[ image, { __? ImageQ } ], image = First @ image ]; (* frames of an animated image *)
    If[ ! ImageQ @ image, Return[ Failure[ "ImageUnreadable", <| "MessageTemplate" -> "The image could not be read." |> ], Module ] ];
    acpEncodeImage[ image, maxBytes ]
];

acpReencodeImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpEncodeImage*)

(* An image as PNG (or as JPEG, which is smaller for photos), its longer side at most $acpMaxImageSize pixels, at most
   maxBytes; made smaller until it fits. Gives <| "MimeType", "Data", "Width", "Height" |> or a Failure. *)
acpEncodeImage // beginDefinition;

acpEncodeImage[ image0_? ImageQ, maxBytes_Integer ] := Catch @ Module[ { image, data },
    image = fitImage[ image0, $acpMaxImageSize ];
    Do[
        data = Quiet @ ExportByteArray[ image, "PNG" ];
        If[ ByteArrayQ @ data && Length @ data <= maxBytes, Throw @ encodedImage[ "image/png", data, image ] ];
        data = Quiet @ ExportByteArray[ RemoveAlphaChannel[ image, White ], "JPEG", "CompressionLevel" -> 0.2 ];
        If[ ByteArrayQ @ data && Length @ data <= maxBytes, Throw @ encodedImage[ "image/jpeg", data, image ] ];
        If[ Max @ ImageDimensions @ image < 256, Break[ ] ];
        image = ImageResize[ image, Scaled[ 0.5 ] ],
        { 4 }
    ];
    Failure[ "ImageTooLarge", <| "MessageTemplate" -> "The image is too large." |> ]
];

acpEncodeImage[ _, _ ] := Failure[ "ImageUnreadable", <| "MessageTemplate" -> "The image could not be read." |> ];

acpEncodeImage // endDefinition;


encodedImage // beginDefinition;
encodedImage[ mime_String, data_ByteArray, image_ ] := <| "MimeType" -> mime, "Data" -> data, "Width" -> ImageDimensions[ image ][[ 1 ]], "Height" -> ImageDimensions[ image ][[ 2 ]] |>;
encodedImage // endDefinition;


fitImage // beginDefinition;

fitImage[ image_, max_Integer ] := With[ { size = ImageDimensions @ image },
    If[ Max @ size > max, ImageResize[ image, Round[ size * max / Max @ size ] ], image ]
];

fitImage // endDefinition;


(* The image of a notebook's GraphicsBox or Graphics3DBox (inert, as notebookTextCells read it): its boxes as the front end
   shows them (displayBoxes), rasterized by the front end (main link), then encoded; Missing if it can't be (the graphics
   are then read as "[graphics]"). Without a front end (the pump of a kernel without a notebook front end) nothing is
   rasterized: Rasterize would start a front end there. *)
rasterizedImage // beginDefinition;

rasterizedImage[ _, _ ] /; ! MatchQ[ $FrontEnd, _FrontEndObject ] := Missing[ "NoFrontEnd" ];

rasterizedImage[ box_, maxBytes_Integer ] := Module[ { display, image },
    display = displayBoxes @ box;
    If[ MissingQ @ display, Return[ display, Module ] ];
    image = Quiet @ Rasterize[ RawBoxes @ display, "Image", ImageResolution -> $acpImageResolution ];
    If[ ! ImageQ @ image, Return[ Missing[ "NotRasterized" ], Module ] ];
    Replace[ acpEncodeImage[ image, maxBytes ], Except[ _Association ] -> Missing[ "NotEncoded" ] ]
];

rasterizedImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
