(* ::Package:: *)

(* ::Title:: *)
(*Gallery of the front end resources in Developer/Resources*)


(* ::Text:: *)
(*Usage:*)
(*    Get[ "path/to/Chatbook/Developer/ResourceGallery.wl" ];*)
(*    ResourceGallery[ ]*)


(* ::Section::Closed:: *)
(*Package Header*)


BeginPackage[ "Wolfram`ChatbookResourceGallery`" ];

ResourceGallery;

Begin[ "`Private`" ];


(* ::Section::Closed:: *)
(*Paths*)


$inputFileName      = Replace[ $InputFileName, "" :> NotebookFileName[ ] ];
$pacletDirectory    = DirectoryName[ $inputFileName, 2 ];
$resourcesDirectory = FileNameJoin @ { $pacletDirectory, "Developer", "Resources" };


(* ::Section::Closed:: *)
(*Load Resources*)


Get @ FileNameJoin @ { $pacletDirectory, "Developer", "FrontEndResourceBuilder.wl" };

color = Wolfram`Chatbook`Common`color;

(* Top level files (Styles.wl, etc.) are stylesheet definitions, not resources: *)
$resourceFiles := Select[
    FileNames[ { "*.wl", "*.wxf" }, $resourcesDirectory, Infinity ],
    StringContainsQ[ relativePath @ #, "/" ] &
];

relativePath[ file_String ] := StringRiffle[
    FileNameSplit @ StringDrop[ file, StringLength @ $resourcesDirectory + 1 ],
    "/"
];

relativeDirectory[ file_String ] := StringRiffle[ Most @ StringSplit[ relativePath @ file, "/" ], "/" ];

loadResource[ file_String ] := wrapBoxes @
    If[ FileExtension @ file === "wl",
        Lookup[ Wolfram`ChatbookFrontEndResourceBuilder`$ChatbookResources, FileBaseName @ file, Missing[ "NotLoaded" ] ],
        Import @ file
    ];

(* Resources written directly as boxes (e.g. GraphicsBox[ ... ]) need RawBoxes to display: *)
wrapBoxes[ expr: head_Symbol[ ___ ] ] /; boxHeadQ @ head := RawBoxes @ expr;
wrapBoxes[ expr_ ] := expr;

boxHeadQ[ head_Symbol ] := Context @ head === "System`" && StringEndsQ[ SymbolName @ head, "Box" ];


(* ::Section::Closed:: *)
(*Arguments for Function Resources*)


$activeBlue = LightDarkSwitched[ RGBColor[ "#187AED" ], RGBColor[ "#83ACF8" ] ];

$toolOpenerColors = <|
    "Default" -> LightDarkSwitched[ RGBColor[ 0.404, 0.545, 0.624 ], RGBColor[ 0.545, 0.639, 0.706 ] ],
    "Hover"   -> LightDarkSwitched[ RGBColor[ 0.537, 0.784, 0.91  ], RGBColor[ 0.702, 0.878, 0.98  ] ],
    "Pressed" -> LightDarkSwitched[ RGBColor[ 0.38,  0.651, 0.788 ], RGBColor[ 0.545, 0.784, 0.91  ] ]
|>;

blueHueFrame[ args_List, state_String, size_, transparentHover_ ] :=
    With[
        {
            background = Switch[ state,
                "Default", None,
                "Hover"  , If[ transparentHover, Transparent, color @ "Gray100_10" ],
                "Pressed", color @ "Blue_D4F0FF_385061"
            ],
            frameStyle = Switch[ state,
                "Default", None,
                "Hover"  , color @ "Blue_B1D5E8_607D8F",
                "Pressed", color @ "Blue_75C2EB_669CBD"
            ]
        },
        Function[
            f,
            Framed[
                RawBoxes[ f @@ args ],
                Alignment      -> { Center, Center },
                Background     -> background,
                FrameMargins   -> 0,
                FrameStyle     -> frameStyle,
                ImageSize      -> size,
                RoundingRadius -> 4
            ]
        ]
    ];

blueHue[ args_List, size_, transparentHover_: False ] :=
    blueHue3[ { args, args, args }, size, transparentHover ];

blueHue3[ { default_List, hover_List, pressed_List }, size_, transparentHover_: False ] := {
    "Default" -> blueHueFrame[ default, "Default", size, transparentHover ],
    "Hover"   -> blueHueFrame[ hover  , "Hover"  , size, transparentHover ],
    "Pressed" -> blueHueFrame[ pressed, "Pressed", size, transparentHover ]
};

prefixLabels[ prefix_String, states_List ] := Replace[ states, ( label_ -> spec_ ) :> ( prefix <> " " <> label -> spec ), { 1 } ];

closeStates[ kind_String, { default_List, hover_List, pressed_List } ] :=
    prefixLabels[ kind, { "Default" -> default, "Hover" -> hover, "Pressed" -> pressed } ];

$functionSpecs := $functionSpecs = <|
    "ChatbarChatBubbleIcon" -> {
        "Active"   -> { color @ "Blue_E0F2FC_344858", color @ "Blue_128ED1_7FC7FB" },
        "Inactive" -> { Transparent, LightDarkSwitched[ GrayLevel[ 0.537255, 0.5 ], GrayLevel[ 0.650980, 0.5 ] ] }
    },
    "ChatbarChatBubbleMinimizedIcon" -> {
        "Default"         -> { color @ "Blue_E0F2FC_344858", color @ "Blue_128ED1_7FC7FB" },
        "Hover / Pressed" -> { color @ "Gray100_10", color @ "Blue_128ED1_7FC7FB" }
    },
    "ChatbarSendIcon" -> Join[
        prefixLabels[ "Active"  , blueHue[ { color @ "Blue_128ED1_7FC7FB" }, { 24, 24 }, True ] ],
        prefixLabels[ "Inactive", blueHue[ { LightDarkSwitched[ GrayLevel[ 0.6509803, 0.5 ], GrayLevel[ 0.6509803, 0.5 ] ] }, { 24, 24 }, True ] ]
    ],
    "ChatbarSettingsIcon" -> blueHue3[
        { { LightDarkSwitched[ GrayLevel[ 0.651 ], GrayLevel[ 0.651 ] ] }, { color @ "Blue_128ED1_7FC7FB" }, { color @ "Blue_128ED1_7FC7FB" } },
        { 15, 15 },
        True
    ],
    "HideChatbarIcon" -> blueHue3[
        { { LightDarkSwitched[ GrayLevel[ 0.6509803 ], GrayLevel[ 0.6509803 ] ] }, { color @ "Blue_128ED1_7FC7FB" }, { color @ "Blue_128ED1_7FC7FB" } },
        { 15, 15 },
        True
    ],
    "ChatIconGeneric" -> { "Default" -> { color @ "Blue_E0F2FC_344858", color @ "Blue_128ED1_7FC7FB", 13 } },
    "Close" -> Join[
        closeStates[ "NonFatal", {
            { color @ "Orange_FAC14D_CD7E16", color @ "Orange_FAC14D_CD7E16", color @ "Gray20_94" },
            { color @ "Orange_FBC24E_F09215", color @ "Orange_FFE2A7_F09215", color @ "Gray20_94" },
            { color @ "Orange_F09215_B25B02", color @ "Orange_F09215_B25B02", color @ "Gray20_94" }
        } ],
        closeStates[ "Fatal", {
            { color @ "Red_FF8A7A_A74436", color @ "Red_FF8A7A_A74436", color @ "Gray20_94" },
            { color @ "Red_FFA597_CF5443", color @ "Red_FFCAC2_CF5443", color @ "Gray20_94" },
            { color @ "Red_ED6541_A72F1E", color @ "Red_ED6541_A72F1E", color @ "Gray20_94" }
        } ],
        closeStates[ "Blocked", {
            { color @ "Blue_7DC7EE_3389B9", color @ "Blue_7DC7EE_3389B9", color @ "Gray20_94" },
            { color @ "Blue_C8E9FB_3E9CD1", color @ "Blue_A3D5F0_3E9CD1", color @ "Gray20_94" },
            { color @ "Blue_3383AC_145F89", color @ "Blue_3383AC_145F89", color @ "Gray20_94" }
        } ]
    ],
    "ToolManagerAllChecked"  -> { "Default" -> { color @ "Gray65_63" }, "Hover" -> { $activeBlue } },
    "ToolManagerDownChevron" -> { "Default" -> { color @ "Gray65_63" }, "Hover" -> { $activeBlue } },
    "ToolManagerClear"       -> { "Default" -> { color @ "Gray50_75" }, "Hover" -> { $activeBlue } },
    "ToolManagerBin"         -> { "Default" -> { color @ "Gray65_63" }, "Hover" -> { $activeBlue }, "Disabled" -> { color @ "Gray80_49" } },
    "ToolManagerCog"         -> { "Default" -> { color @ "Gray65_63" }, "Hover" -> { $activeBlue }, "Disabled" -> { color @ "Gray80_49" } },
    "ToolManagerDelimiter"   -> { "Default" -> { color @ "Gray80_49" } },
    "ChatEvaluatingSpinner"  -> { "Default" -> { 20, color @ "Gray94_20", color @ "Blue_75C2EB_669CBD" } },
    "SendChatArrow"          -> blueHue[ { color @ "Blue_128ED1_7FC7FB", 13 }, { 24.5, 24.5 } ],
    "SendChatButton"         -> { "Default" -> { color @ "Blue_B1D5E8_607D8F", { 24, 24 }, 12, 18 } },
    "SendChatButtonLabel"    -> { "Default" -> { color @ "Blue_B1D5E8_607D8F", { 24, 24 }, 12 } },
    "StopChatButtonLabel"    -> { "Default" -> { color @ "Blue_B1D5E8_607D8F", { 24, 24 }, 18 } },
    "StopChatButton"         -> blueHue[ { 21 }, { 24.5, 24.5 } ],
    "SidebarFocusIndicatorCheck" -> {
        "Default" -> { Transparent, color @ "Blue_128ED1_7FC7FB" },
        "Hover"   -> { Transparent, color @ "Blue_75C2EB_669CBD" }
    },
    "SidebarFocusIndicatorUncheck" -> {
        "Default" -> { Transparent, color @ "Blue_128ED1_7FC7FB" },
        "Hover"   -> { Transparent, color @ "Blue_75C2EB_669CBD" }
    },
    "SidebarIconHide"                    -> blueHue[ { color @ "Blue_128ED1_7FC7FB" }, { 24, 24 } ],
    "WorkspaceToolbarIconHistory"        -> blueHue[ { color @ "Blue_128ED1_7FC7FB" }, { 24, 24 } ],
    "WorkspaceToolbarIconNew"            -> blueHue[ { color @ "Blue_128ED1_7FC7FB" }, { 24, 24 } ],
    "WorkspaceToolbarIconOpenAsChatbook" -> blueHue[ { color @ "Blue_128ED1_7FC7FB" }, { 24, 24 } ],
    "WorkspaceToolbarIconSources"        -> blueHue[ { color @ "Blue_128ED1_7FC7FB" }, { 24, 24 } ],
    "WorkspaceOutputRaftClipboardIcon"   -> blueHue[ { color @ "Blue_128ED1_7FC7FB" }, { 24, 24 } ],
    "WorkspaceOutputRaftShareIcon"       -> blueHue[ { color @ "Blue_128ED1_7FC7FB" }, { 24, 24 } ]
|>;

$toolCallIconSpec := KeyValueMap[ #1 -> { #2 } &, $toolOpenerColors ];

functionSpec[ name_String, f_Function ] :=
    Lookup[
        $functionSpecs,
        name,
        If[ StringStartsQ[ name, "ToolIconCall" ],
            $toolCallIconSpec,
            { "Guessed arguments" -> ConstantArray[ color @ "Blue_128ED1_7FC7FB", maxSlot @ f ] }
        ]
    ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::UnscopedObjectError:: *)
maxSlot[ f_Function ] := Max[ 0, Cases[ f, HoldPattern @ Slot[ n_Integer ] :> n, Infinity, Heads -> True ] ];
(* :!CodeAnalysis::EndBlock:: *)


(* ::Section::Closed:: *)
(*Resource States*)


$$mouseOver = (Dynamic | DynamicBox)[ (CurrentValue | FrontEnd`CurrentValue)[ "MouseOver" ], ___ ];

stateLabel[ False ] := "Default";
stateLabel[ True  ] := "Hover";
stateLabel[ other_ ] := ToString @ other;

(* Returns a list of { label, display } pairs: *)
resourceStates[ name_String, f_Function ] :=
    Replace[
        functionSpec[ name, f ],
        {
            ( label_ -> args_List ) :> { label, renderSafely @ RawBoxes[ f @@ args ] },
            ( label_ -> g_Function ) :> { label, renderSafely @ g @ f }
        },
        { 1 }
    ];

resourceStates[ _, RawBoxes[ boxes_ ] ] /; ! FreeQ[ boxes, PaneSelectorBox[ _List, $$mouseOver, ___ ] ] :=
    Map[
        Function[
            key,
            {
                stateLabel @ key,
                RawBoxes[ boxes //. PaneSelectorBox[ rules_List, $$mouseOver, rest___ ] :> PaneSelectorBox[ rules, key, rest ] ]
            }
        ],
        First @ Cases[ boxes, PaneSelectorBox[ rules_List, $$mouseOver, ___ ] :> Keys @ rules, { 0, Infinity } ]
    ];

(* Live cells are shown inline (RawBoxes turns them into inline cells); width is bounded since some use Scaled[ 1 ]: *)
resourceStates[ _, cell_Cell ] := { { None, Pane[ RawBoxes @ cell, ImageSize -> { 350, Automatic } ] } };
resourceStates[ _, img_Image ] := { { None, Image[ img, Magnification -> 2 ] } };
resourceStates[ _, _Missing ] := { { None, Style[ "Not loaded", Red ] } };
resourceStates[ _, expr_ ] := { { None, expr } };

renderSafely[ expr_ ] := Quiet @ Check[ expr, Style[ "Failed to render", Red ] ];

resourceKind[ _Function ] := "Function";
resourceKind[ RawBoxes[ boxes_ ] ] /; ! FreeQ[ boxes, $$mouseOver ] := "Boxes (mouseover)";
resourceKind[ _RawBoxes ] := "Boxes";
resourceKind[ expr_ ] := ToString @ Head @ expr;

kindDisplay[ name_String, cell_Cell ] := Column[
    { kindLabel @ resourceKind @ cell, openCellButton[ name, cell ] },
    Spacings -> 0.5
];

kindDisplay[ _, expr_ ] := kindLabel @ resourceKind @ expr;

kindLabel[ kind_String ] := Style[ kind, FontSize -> 11, FontColor -> GrayLevel[ 0.45 ] ];


(* ::Section::Closed:: *)
(*Open Cell in Window*)


(* "ChatInputField" is only defined in WorkspaceChat.nb; the sidebar styles come from CoreExtensions, which every notebook has: *)
cellStylesheet[ Cell[ _, "ChatInputField", ___ ] ] := FrontEnd`FileName[ { "Wolfram" }, "WorkspaceChat.nb", CharacterEncoding -> "UTF-8" ];
cellStylesheet[ _Cell ] := "Default.nb";

openCellButton[ name_String, cell_Cell ] :=
    With[ { stylesheet = cellStylesheet @ cell },
        Button[
            Style[ "Open in window", FontSize -> 10 ],
            CreateDocument[
                { cell },
                StyleDefinitions -> stylesheet,
                WindowSize       -> { 500, 700 },
                WindowTitle      -> name
            ],
            Method    -> "Queued",
            ImageSize -> Automatic
        ]
    ];


(* ::Section::Closed:: *)
(*Cell Bitmap Previews*)


$hiddenCell = Cell[ "", CellMargins -> 0, CellOpen -> False, CellElementSpacings -> { "ClosedCellHeight" -> 0 } ];

rasterizeCell[ cell_Cell, mode_String ] := Rasterize[
    Notebook[
        { $hiddenCell, cell, $hiddenCell },
        WindowSize       -> { 300, Automatic },
        StyleDefinitions -> cellStylesheet @ cell,
        LightDark        -> mode
    ],
    LightDark -> mode
];


(* ::Section::Closed:: *)
(*Display*)


stateGrid[ { { None, display_ } } ] := display;

stateGrid[ states_List ] := Grid[
    Partition[
        Apply[
            Column[ { #2, Style[ #1, FontFamily -> "Source Sans Pro", FontSize -> 10, FontColor -> GrayLevel[ 0.55 ] ] }, Alignment -> Center, Spacings -> 0.4 ] &,
            states,
            { 1 }
        ],
        UpTo[ 3 ]
    ],
    Alignment -> { Center, Bottom },
    Spacings  -> { 2, 1 }
];

inMode[ content_, mode_String ] := Style[
    Framed[
        content,
        Alignment      -> { Center, Center },
        Background     -> color @ "Gray100_10",
        FrameMargins   -> 10,
        FrameStyle     -> None,
        RoundingRadius -> 4
    ],
    LightDark -> mode
];

(* Unless $liveCells is True, cells are shown as bitmaps, rasterized separately for each mode: *)
modeDisplay[ _, cell_Cell, mode_String ] /; ! TrueQ @ $liveCells := renderSafely @ rasterizeCell[ cell, mode ];
modeDisplay[ name_String, expr_, _String ] := stateGrid @ resourceStates[ name, expr ];

resourceRow[ file_String ] :=
    With[ { expr = loadResource @ file, name = FileBaseName @ file },
        {
            Hyperlink[ Style[ FileNameTake @ file, FontFamily -> "Source Code Pro", FontSize -> 11 ], file ],
            kindDisplay[ name, expr ],
            inMode[ modeDisplay[ name, expr, "Light" ], "Light" ],
            inMode[ modeDisplay[ name, expr, "Dark"  ], "Dark"  ]
        }
    ];

resourceGrid[ files_List ] := Grid[
    Prepend[
        resourceRow /@ files,
        Style[ #, Bold, FontFamily -> "Source Sans Pro" ] & /@ { "File", "Kind", "Light", "Dark" }
    ],
    Alignment  -> { { Left, Left, Center, Center }, Center },
    Background -> { None, { GrayLevel[ 0.92 ], { None } } },
    Dividers   -> { None, { { GrayLevel[ 0.85 ] } } },
    Spacings   -> { 2, 1 }
];

galleryCells[ ] := Flatten @ {
    TextCell[ "Chatbook Front End Resources", "Title" ],
    TextCell[
        "Resources from Developer/Resources, loaded from source. Function resources are shown with the arguments "<>
            "they are called with in Chatbook, including hover and pressed states where they have them.",
        "Text"
    ],
    KeyValueMap[
        { TextCell[ #1, "Section" ], ExpressionCell[ resourceGrid @ #2, "Output" ] } &,
        KeySort @ GroupBy[ $resourceFiles, relativeDirectory ]
    ]
};


(* ::Section::Closed:: *)
(*ResourceGallery*)


(* "LiveCells" -> True shows Cell resources as live inline cells, which run their dynamic content (and load Chatbook): *)
Options[ ResourceGallery ] = { "LiveCells" -> False };

ResourceGallery[ OptionsPattern[ ] ] :=
    Block[ { $liveCells = TrueQ @ OptionValue[ "LiveCells" ] },
        CreateDocument[
            galleryCells[ ],
            ShowCellLabel -> False,
            WindowSize    -> { 1100, 900 },
            WindowTitle   -> "Chatbook Resource Gallery"
        ]
    ];


(* ::Section::Closed:: *)
(*Package Footer*)


End[ ];
EndPackage[ ];
