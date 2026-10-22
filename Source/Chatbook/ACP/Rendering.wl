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
   "Working" header and, while that opener is open (it starts closed), one Dynamic per entity, each tracking that
   entity's change symbol. Opener state lives in $acpOpen and is toggled by preemptive EventHandlers
   (ChatbookAction[ "ACP", "ToggleOpen", turnID, key, default ]).
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
$liveImageSize       = { 320, 240 };  (* largest image size (points) in live views *)
$finalImageSize      = { 480, 360 };  (* largest image size (points) in final cells *)
$maxLineLength       = 300; (* one-line values (and the lines of diffs) *)
$diffContextLines    = 3;
$permissionPreviewHeight = 260;
$permissionArmDelay  = 0.4;  (* seconds before permission buttons accept clicks *)
$permissionScriptLines   = 80;  (* lines of a script (code mode) in the permission panel *)
$permissionScriptLength  = 20000; (* characters of those lines (which are not cut) in the permission panel *)
$permissionArgumentLines = 12;  (* lines of an argument (markdown) in the permission panel *)
$permissionCallLimit     = 12;  (* tool references of a script listed in the permission panel *)
$permissionHeadlineTools = 6;   (* tools named in the headline of the permission panel for a script *)
(* The panel is part of the attached input cell, which the front end lays out again on every keystroke and every update
   of the window, so it shows only a few lines of large requests (the rest is in the "View full ..." window,
   PermissionDetails.wl): *)
$permissionDiffLines     = 12;   (* rows of each file's diff (the first change with its context) *)
$permissionDiffFiles     = 3;    (* files whose diffs are shown *)
$permissionLineLength    = 160;  (* characters of a diff row (at most two lines in a narrow window) *)
$permissionCommandLines  = 12;   (* lines of a shell command *)
$permissionCommandLength = 4000; (* characters of those lines (which are not cut) *)
$permissionScopePatterns = 8;    (* patterns of a shell command named in the "Always allow" text *)

(* The parameters of the notebook tools (NotebookTools.wl), in the order they are shown *)
$notebookToolParameters = { "notebook", "cell", "position", "cells", "offset", "limit", "markdown" };
$clockTicks          = 5;    (* the Working header's elapsed time is refreshed every 5 publisher ticks (1 s) *)
$workOpenDefault     = False; (* the live "Working" opener starts closed: its header's label says what is happening *)
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
   code), so they are replaced with U+FFFD (neutralizeLinearSyntax, in Formatting.wl, which also does this for all the
   text that Chatbook's formatter formats). Typed backslashes are escaped by ToBoxes and need nothing. A search for each
   character as a literal string is fast: megabytes of patch text are checked in milliseconds. *)
acpNeutralizeLinearSyntax // beginDefinition;
acpNeutralizeLinearSyntax[ s_String ] := neutralizeLinearSyntax @ s;
acpNeutralizeLinearSyntax[ other_ ] := other;
acpNeutralizeLinearSyntax // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSafeText*)

(* The agent's text as it is shown (answers, thoughts, tool titles and their tooltips, status lines, tool input and
   output, permission requests, notices and errors): acpNeutralizeLinearSyntax, and the bidi controls and the line and
   paragraph separators shown as acpRemoteDisplayName shows them (a visible [[U+XXXX]] marker), so that text can't look
   different from what it is: with U+202E (right-to-left override) before "GNP.exe", a command would show "PNG.exe",
   also in the permission request that the user approves (the "Trojan Source" trick). The other characters that
   acpRemoteDisplayName shows (zero width joiners, variation selectors, ...) are left as they are: they are part of
   ordinary text, e.g. of emoji. Tabs and line breaks are kept. The review window's diffs and messages are made safe the
   same way (reviewSafeText, acpReviewSafeLines). Only for display: what goes back to the agent or into a notebook's
   content (NotebookTools.wl, the turn's markdown) keeps these characters and is only neutralized. A literal search for
   each character checks megabytes of text in milliseconds; the replacement runs only when one is there. *)
acpSafeText // beginDefinition;

acpSafeText[ s_String ] := acpNeutralizeLinearSyntax @ If[ AnyTrue[ $hiddenCharacters, StringContainsQ[ s, # ] & ],
    StringReplace[ s, $hiddenCharacterRules ],
    s
];

acpSafeText[ other_ ] := other;

acpSafeText // endDefinition;

(* ALM, LRM, RLM; the line and paragraph separators; LRE, RLE, PDF, LRO, RLO; LRI, RLI, FSI, PDI *)
$hiddenCharacters = FromCharacterCode /@ Join[ { 16^^61C, 16^^200E, 16^^200F }, Range[ 16^^2028, 16^^202E ], Range[ 16^^2066, 16^^2069 ] ];

(* The markers of acpRemoteDisplayName (made once per session) *)
$hiddenCharacterRules := $hiddenCharacterRules = Thread[ $hiddenCharacters -> (acpRemoteDisplayName /@ $hiddenCharacters) ];


(* The text of acpSafeText as the pieces that acpFitText cuts: its characters, a marker as one piece (a cut never leaves
   half a marker) *)
safeTextPieces // beginDefinition;

safeTextPieces[ s_String ] := With[ { safe = acpSafeText @ s },
    If[ StringContainsQ[ safe, "\:27e6" ],
        Flatten @ Replace[
            StringSplit[ safe, m: ("\:27e6U+" ~~ Repeated[ HexadecimalCharacter, { 4, 6 } ] ~~ "\:27e7") :> $marker[ m ] ],
            { $marker[ m_ ] :> m, t_String :> Characters @ t },
            { 1 }
        ],
        Characters @ safe
    ]
];

safeTextPieces // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFitText*)

(* acpFitText[ spec ] is one line of text that fits in the width available to it, with an ellipsis at its edge. The
   front end cuts the spec's object when it shows the view, and again when the window's width or magnification changes,
   and shows a tooltip only when it cut something. All of it happens in the front end (a DynamicBox with
   Evaluator -> None that uses only front end functions and no kernel symbols), so the view also works in a saved or
   copied cell without a kernel, and costs the kernel nothing. The width is computed, not measured (see acpFitWidth), so
   clipping panes are the safety net: if the width is off (e.g. a width computed for another stylesheet), the line is
   clipped instead of pushing what follows it out of the window. The object has its own pane, which clips it on the
   side where it is cut (a path keeps its file name), and the prefix and suffix stay whole while they fit.
   spec, an association:
     "Object"          the text to cut (one line; it goes into boxes: made display-safe here, see acpSafeText), or
                       the list of its pieces that are cut whole, e.g. a display-safe marker such as "\:27e6U+202E\:27e7"
                       of acpRemoteDisplayName (a string is cut by characters, and by whole markers: safeTextPieces)
     "ObjectStyle"     its font options, e.g. { FontFamily -> "Source Code Pro", FontSize -> 12 }; { }: the surrounding
                       font (FontFamily, FontSize, FontWeight and FontSlant are measured)
     "Side"            Right: cut the end (commands, patterns, queries); Left: cut the start (paths: keeps the file name)
     "Prefix", "Suffix"  text shown whole before and after the object: { { text, font options }... }
     "Width"           the width available to the whole line, in points at magnification 1: acpFitWidth[ ... ]
     "Tooltip"         what the tooltip shows (any expression) when the text was cut; None: no tooltip
     "Truncated"       True if the object was already shortened by the caller: the tooltip is always shown
     "DropPrefix"      False: the prefix is shown even when it leaves the object no room (a remote folder's host);
                       default True: it is dropped then (see fitDynamic)
     "MaxWidth"        the clipping panes' largest width: Full (default: the room that the enclosing box gives), or a
                       number of points for a line inside a box whose Full is not the room in the row: inside an
                       ActionMenu (the toolbar's model menu), Full is a fixed width of about 376 points (times the
                       magnification) whatever the window's width, which clipped a wider cut name without its ellipsis
   Widths are measured with FEPrivate`StringWidth (explicit font options, at the size the text is drawn at: see
   fitFontOptions), and the object is cut by bisection on the list of its characters (the front end can take and join
   lists, but has no string functions), with about Log2 of its length measurements. *)
acpFitText // beginDefinition;

acpFitText[ spec_Association ] := Block[ { $fitMaxWidth = Replace[ Lookup[ spec, "MaxWidth", Full ], Except[ _? NumberQ ] -> Full ] },
    acpFitText0 @ spec
];

acpFitText // endDefinition;


acpFitText0 // beginDefinition;

acpFitText0[ spec_Association ] := Module[
    { units, object, objectStyle, side, prefix, suffix, tooltip, truncated, width, fixed, full, cut, drop },
    units       = Replace[
        Lookup[ spec, "Object", "" ],
        {
            s_String               :> safeTextPieces @ s,
            pieces: { ___String }  :> acpSafeText /@ DeleteCases[ pieces, "" ],
            _                      -> { }
        }
    ];
    object      = StringJoin @ units;
    objectStyle = Replace[ Lookup[ spec, "ObjectStyle", { } ], Except[ _List ] -> { } ];
    side        = Replace[ Lookup[ spec, "Side", Right ], Except[ Left ] -> Right ];
    prefix      = fitSpans @ Lookup[ spec, "Prefix", { } ];
    suffix      = fitSpans @ Lookup[ spec, "Suffix", { } ];
    tooltip     = Lookup[ spec, "Tooltip", None ];
    truncated   = TrueQ @ Lookup[ spec, "Truncated", False ] && tooltip =!= None;
    width       = Lookup[ spec, "Width", None ];
    drop        = prefix =!= { } && Lookup[ spec, "DropPrefix", True ] =!= False;
    fixed       = Join[ prefix, If[ object === "", { }, { { object, objectStyle } } ], suffix ];
    full        = fitRowBoxes @ fixed;
    If[ object === "" || ! MatchQ[ width, _feHold ],
        Return[ fitPane @ If[ truncated, fitTooltipBoxes[ full, tooltip ], full ], Module ]
    ];
    cut  = fitCutFunction[ prefix, objectStyle, suffix, side, If[ tooltip === None, None, neutralizeLinearSyntax @ ToBoxes @ tooltip ], units, drop ];
    full = fitLineBoxes[ prefix, fitRowBoxes @ { { object, objectStyle } }, suffix, side ];
    fitPane @ fitDynamic[
        width,
        fitWidthSum[ fitWidth /@ prefix ],
        fitWidth @ { object, objectStyle },
        fitWidth @ { "\[Ellipsis]", objectStyle },
        fitFontOptions @ objectStyle,
        units,
        If[ truncated, fitTooltipBoxes[ full, tooltip ], full ],
        cut,
        side,
        fitWidthSum[ fitWidth /@ suffix ],
        drop
    ]
];

acpFitText0 // endDefinition;

(* The largest width of acpFitText's clipping panes (its spec's "MaxWidth"): *)
$fitMaxWidth = Full;


(* Expressions for the front end are built from pieces held in feHold, which are spliced together and then released
   from it (fitDynamic): *)
feHold // Attributes = { HoldAllComplete };


(* { { text, options }... } with display-safe text (acpSafeText) and font options, spans of no text dropped *)
fitSpans // beginDefinition;
fitSpans[ spans_List ] := Cases[ spans, { s_String /; s =!= "", o_List } :> { acpSafeText @ s, o } ];
fitSpans[ _ ] := { };
fitSpans // endDefinition;


(* The boxes of spans, adjacent spans with the same options joined into one string: *)
fitRowBoxes // beginDefinition;

fitRowBoxes[ spans_List ] := Replace[
    StyleBox[ ToBoxes @ StringJoin[ #[[ All, 1 ]] ], Sequence @@ #[[ 1, 2 ]] ] & /@ SplitBy[ spans, Last ],
    { { one_ } :> one, boxes_ :> RowBox @ boxes }
];

fitRowBoxes // endDefinition;


(* The line that the front end shows: the prefix, the object in its own clipping pane (the second safety net: it takes
   the room that the prefix and suffix leave, and clips the object on the side where it is cut, so a path whose width
   was computed too large still shows its file name), and the suffix, aligned on their baselines *)
fitLineBoxes // beginDefinition;

fitLineBoxes[ prefix_List, object_, suffix_List, side_ ] := GridBox[
    {
        Join[
            If[ prefix === { }, { }, { fitRowBoxes @ prefix } ],
            {
                PaneBox[
                    object,
                    ImageSize        -> { { 0, $fitMaxWidth }, Automatic },
                    ImageSizeAction  -> "Clip",
                    Alignment        -> If[ side === Left, Right, Left ],
                    BaselinePosition -> Baseline
                ]
            },
            If[ suffix === { }, { }, { fitRowBoxes @ suffix } ]
        ]
    },
    GridBoxAlignment -> { "Columns" -> { { Left } }, "Rows" -> { { Baseline } } },
    (* explicit: without it, the object's pane gets the width of the whole line rather than what the prefix leaves *)
    GridBoxItemSize  -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
    GridBoxSpacings  -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } },
    BaselinePosition -> { 1, 1 }
];

fitLineBoxes // endDefinition;


fitTooltipBoxes // beginDefinition;
fitTooltipBoxes[ boxes_, tooltip_ ] := TooltipBox[ boxes, neutralizeLinearSyntax @ ToBoxes @ tooltip, TooltipStyle -> "TextStyling" ];
fitTooltipBoxes // endDefinition;


(* The safety net: the line never takes more than the available width. String characters are hidden and operators are
   drawn as typed (the measurement does not substitute "-" or "->" either). *)
fitPane // beginDefinition;
fitPane[ boxes_ ] := Pane[
    RawBoxes @ boxes,
    ImageSize       -> { { 0, $fitMaxWidth }, Automatic },
    ImageSizeAction -> "Clip",
    BaselinePosition -> Baseline,
    BaseStyle       -> { LineBreakWithin -> False, ShowStringCharacters -> False, PrivateFontOptions -> { "OperatorSubstitution" -> False } }
];
fitPane // endDefinition;


(* The font options of a span for FEPrivate`StringWidth: the explicit ones, and those of the surrounding text, at the
   size that the text is drawn at: the font size times the magnification. The front end fits glyphs to the screen's
   pixels, so a text's width is not proportional to its font size: at magnification 0.85, 13-point text is about 4%
   wider than 0.85 times its width at magnification 1 (12 points: 3%; measured in a front end on Linux), and a width
   measured at magnification 1 and scaled left the ellipsis of a cut title 8 to 18 points beyond the edge, where the
   clipping pane cut it off. Measured at the drawn size, the width is right at every magnification (and the front end
   that draws the text measures it, on any platform and screen resolution). *)
fitFontOptions // beginDefinition;

fitFontOptions[ options_List ] := With[
    {
        family = Lookup[ options, FontFamily, feHold @ FrontEnd`AbsoluteCurrentValue[ FontFamily ] ],
        size   = Lookup[ options, FontSize  , feHold @ FrontEnd`AbsoluteCurrentValue[ FontSize   ] ],
        weight = Lookup[ options, FontWeight, feHold @ FrontEnd`AbsoluteCurrentValue[ FontWeight ] ],
        slant  = Lookup[ options, FontSlant , feHold @ FrontEnd`AbsoluteCurrentValue[ FontSlant  ] ],
        mag    = $fitMagnification
    },
    feHold @ { FontFamily -> family, FontSize -> size * mag, FontWeight -> weight, FontSlant -> slant }
];

fitFontOptions // endDefinition;

(* The magnification at the view's place, in the front end: *)
$fitMagnification = feHold @ FrontEnd`AbsoluteCurrentValue[ Magnification ];


(* The width of a span in points at magnification 1 (the unit of acpFitWidth): measured at the drawn size (see
   fitFontOptions) and divided by the magnification *)
fitWidth // beginDefinition;

fitWidth[ { text_String, options_List } ] := With[ { o = fitFontOptions @ options, m = $fitMagnification },
    feHold[ Part[ FEPrivate`StringWidth[ text, o ], 2 ] / m ]
];

fitWidth // endDefinition;


fitWidthSum // beginDefinition;
fitWidthSum[ { } ] := feHold[ 0 ];
fitWidthSum[ widths: { __feHold } ] := Replace[ Hold @@ widths, Hold[ w___ ] :> feHold @ Plus[ w ] ];
fitWidthSum // endDefinition;


(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::UnscopedObjectError:: *)
(* The pieces below hold slots (#, #1, ...) of the front end's functions, which fitDynamic puts together *)

(* The boxes of the cut text, a function of the state of the bisection, { kept, _, characters, ... }. The text is a
   string box that the front end joins by itself, "\"\[Ellipsis]...\"" (a string literal, whose quotes the line hides:
   see fitPane), so a copy without a kernel shows it too (ToBoxes, which an earlier version used here, needs a kernel:
   the cut title was blank). The pieces in the literal are the characters escaped as ToBoxes escapes them (a quote or
   a backslash), taken from the characters (#[[3]]) when none needs it, and from their escaped copy otherwise (the
   characters stay unescaped for StringWidth). *)
fitCutFunction // beginDefinition;

fitCutFunction[ prefix_, objectStyle_, suffix_, side_, tooltip_, chars_List, drop_ ] := Module[ { escaped, pieces, text, row },
    escaped = fitEscape /@ chars;
    pieces  = If[ escaped === chars, feHold @ #[[ 3 ]], With[ { e = escaped }, feHold @ e ] ];
    text = If[ side === Left,
        With[ { p = pieces }, feHold @ FEPrivate`StringJoin[ { "\"\[Ellipsis]", FEPrivate`StringJoin[ FEPrivate`Take[ p, -#[[ 1 ]] ] ], "\"" } ] ],
        With[ { p = pieces }, feHold @ FEPrivate`StringJoin[ { "\"", FEPrivate`StringJoin[ FEPrivate`Take[ p, #[[ 1 ]] ] ], "\[Ellipsis]\"" } ] ]
    ];
    row = fitLineBoxes[ prefix, StyleBox[ $fitObject, Sequence @@ objectStyle ], suffix, side ];
    (* the prefix is left out when it left the object no room (#[[6]], see fitDynamic) *)
    row = Replace[ row, GridBox[ { { pre_, rest___ } }, opts___ ] /; TrueQ @ drop :> GridBox[ { { FEPrivate`If[ feHold[ #[[ 6 ]] ], "", pre ], rest } }, opts ] ];
    row = If[ tooltip === None, row, TooltipBox[ row, tooltip, TooltipStyle -> "TextStyling" ] ];
    With[ { r = row /. $fitObject -> text }, feHold[ r & ] ]
];

fitCutFunction // endDefinition;


(* A piece of the text as it is inside a string literal box: *)
fitEscape // beginDefinition;
fitEscape[ s_String ] := StringTake[ ToBoxes @ s, { 2, -2 } ];
fitEscape // endDefinition;


(* One step of the bisection for the number of characters that fit: the state is { lo, hi, characters, font options,
   width for them, prefix dropped }, lo characters fit and more than hi don't. The font options are those of the drawn
   size and the width is in drawn points (see fitFontOptions): the measurements are compared as they are. *)
fitStep // beginDefinition;

fitStep[ side_ ] := With[ { take = If[ side === Left, feHold[ -#2 ], feHold[ #2 ] ] },
    feHold[
        (
            FEPrivate`If[
                FEPrivate`LessEqual[ Part[ FEPrivate`StringWidth[ FEPrivate`StringJoin[ FEPrivate`Take[ #1[[ 3 ]], take ] ], #1[[ 4 ]] ], 2 ], #1[[ 5 ]] ],
                { #2, #1[[ 2 ]], #1[[ 3 ]], #1[[ 4 ]], #1[[ 5 ]], #1[[ 6 ]] },
                { #1[[ 1 ]], #2 - 1, #1[[ 3 ]], #1[[ 4 ]], #1[[ 5 ]], #1[[ 6 ]] }
            ] &
        )[ #, FEPrivate`Floor[ 0.5 * ( #[[ 1 ]] + #[[ 2 ]] + 1 ) ] ] &
    ]
];

fitStep // endDefinition;


(* The DynamicBox: a function of the available width (#1), the widths of the prefix (#2), the object (#3) and the
   ellipsis (#4), the object's font (#5), the boxes when everything fits (#6), the function that gives the boxes of the
   cut text from the state of the bisection (#7), and the width of the suffix (#8) (the boxes are arguments, not in the
   function's body, so they are written once). When the prefix leaves the object less room than two ellipses (a very
   narrow or magnified window), the prefix is dropped and the object gets its room: "\[Ellipsis]y" rather than a "Read"
   clipped without an ellipsis. *)
fitDynamic // beginDefinition;

fitDynamic[ width_, prefix_, object_, ellipsis_, font_, chars_List, full_, cut_, side_, suffix_, droppable_ ] := Module[ { steps, state, held },
    (* the state: the width for the object's characters in drawn points (the font options #5 are those of the drawn
       size), and whether the prefix is dropped; an inner function, so that the test is written once *)
    state = With[
        {
            n    = Length @ chars,
            c    = chars,
            m    = $fitMagnification,
            drop = If[ TrueQ @ droppable, feHold @ FEPrivate`Less[ #1 - #2 - #8 - #4, 2 * #4 ], False ]
        },
        feHold @ ( { 0, n, c, #1, ( #2 - FEPrivate`If[ #3, 0, #4 ] ) * m, #3 } & )[ #5, #1 - #8 - #4, drop, #2 ]
    ];
    steps = Nest[ With[ { s = fitStep @ side, x = # }, feHold @ s @ x ] &, state, Max[ 1, Ceiling @ Log2[ Length @ chars + 1 ] ] ];
    held  = With[ { w = width, p = prefix, o = object, e = ellipsis, t = font, all = full, c = cut, s = steps, x = suffix },
        HoldComplete[
            (
                FEPrivate`If[
                    FEPrivate`And[ FEPrivate`NumericQ[ #1 ], FEPrivate`NumericQ[ #2 ], FEPrivate`NumericQ[ #3 ], FEPrivate`NumericQ[ #4 ], FEPrivate`NumericQ[ #8 ] ],
                    FEPrivate`If[ FEPrivate`LessEqual[ #2 + #3 + #8, #1 ], #6, #7[ s ] ],
                    #6
                ] &
            )[ w, p, o, e, t, all, c, x ]
        ]
    ];
    Replace[ held //. feHold[ e_ ] :> e, HoldComplete[ e_ ] :> DynamicBox[ e, Evaluator -> None ] ]
];

fitDynamic // endDefinition;

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFitWidth*)

(* acpFitWidth[ reserve ] / acpFitWidth[ reserve, { { text, font options }... } ]: the "Width" of acpFitText, in points
   at magnification 1: the width of the window's content area ("ViewSize", which excludes the scroll bar) less what the
   layout puts around the line (reserve: margins, frames, icons, spacings) and less the widths of the texts (e.g. the
   summary after a title, measured at the drawn size: fitWidth). It is evaluated in the view's place, and updated when
   the window's size or magnification changes.
   reserve is { screen, scaled }: magnification scales most of a layout, but not all of it, and the two parts are kept
   apart. screen is in screen points, which magnification does not scale: measured in a real front end, every cell
   reserves about 5 points at its right whatever the magnification (a top-level cell, and each inline cell in a
   BoxData), and frame lines have absolute thicknesses. scaled is in points at magnification 1 (margins, frame margins,
   icons, spacings). Treating the screen points as scaled ones, as an earlier version did, made the width too large at
   magnifications below 1 (a cut title's ellipsis was clipped) and too small above it (titles cut with room left, a
   toolbar label down to "\[Ellipsis]"). A number is a scaled reserve. The reserves were measured in a real front end
   on Linux at 96 dpi (see docs/acp-window.md, "Tool cards"), by drawing a bar of Full width in the line's place at
   magnifications 1 and 2: the room is room = ViewSize - screen - scaled * magnification, checked at 0.85 to 2.
   A safety margin of a few screen points ($fitSafetyMargin) takes up the rounding of each part to whole pixels; when
   the width is still too large (e.g. a copied cell in another notebook's stylesheet), the clipping panes of acpFitText
   clip the line. The width of the cell (FEPrivate`CellDisplayWidth) was not used: it is 0 for the inline cells that
   hold cards in the "Worked for" opener, and for a top-level cell it differs from the width its content gets. *)
acpFitWidth // beginDefinition;

acpFitWidth[ reserve_ ] := acpFitWidth[ reserve, { } ];

acpFitWidth[ reserve_, texts_List ] := With[
    {
        f = N[ First @ fitReserve @ reserve + $fitSafetyMargin ],
        r = N @ Last @ fitReserve @ reserve,
        w = fitWidthSum[ fitWidth /@ fitSpans @ texts ]
    },
    feHold[ ( Part[ FrontEnd`AbsoluteCurrentValue[ "ViewSize" ], 1 ] - f ) / FrontEnd`AbsoluteCurrentValue[ Magnification ] - r - w ]
];

acpFitWidth // endDefinition;


(* A reserve as { screen points, points at magnification 1 } (a number: points at magnification 1 only). Reserves
   are added as lists: { a, b } + { c, d }. *)
fitReserve // beginDefinition;
fitReserve[ { screen_? NumberQ, scaled_? NumberQ } ] := { screen, scaled };
fitReserve[ scaled_? NumberQ ] := { 0, scaled };
fitReserve // endDefinition;

(* Screen points left free at the end of a line that is cut: the layout puts each part on whole pixels, and at a
   fractional magnification (0.85) a line got up to about 4 pixels less room than its parts add up to *)
$fitSafetyMargin = 4;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFitSwitch*)

(* acpFitSwitch[ width, min, narrow, wide ]: a view that the front end shows as narrow while the width (an acpFitWidth)
   is less than min points, and as wide otherwise (also while the width is not known), e.g. a toolbar button's label
   that is dropped in a narrow window. acpFitWidthSwitch[ width, min, narrow, wide ]: the width narrow or wide (both
   acpFitWidth expressions) on the same condition, for a view that gets the room of what is dropped. Like acpFitText,
   all in the front end. *)
acpFitSwitch // beginDefinition;

acpFitSwitch[ width_feHold, min_? NumberQ, narrow_, wide_ ] := With[
    { test = fitNarrowTest[ width, min ], n = ToBoxes @ narrow, w = ToBoxes @ wide },
    RawBoxes @ Replace[
        HoldComplete[ FEPrivate`If[ test, n, w ] ] //. feHold[ e_ ] :> e,
        HoldComplete[ e_ ] :> DynamicBox[ e, Evaluator -> None ]
    ]
];

acpFitSwitch // endDefinition;


acpFitWidthSwitch // beginDefinition;

acpFitWidthSwitch[ width_feHold, min_? NumberQ, narrow_feHold, wide_feHold ] := With[
    { test = fitNarrowTest[ width, min ], n = narrow, w = wide },
    feHold @ FEPrivate`If[ test, n, w ]
];

acpFitWidthSwitch // endDefinition;


fitNarrowTest // beginDefinition;
fitNarrowTest[ width_feHold, min_ ] := With[ { w = width, m = N @ min }, feHold @ FEPrivate`And[ FEPrivate`NumericQ[ w ], FEPrivate`Less[ w, m ] ] ];
fitNarrowTest // endDefinition;

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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFreezeLiveView*)

(* Freezes the live view of a turn that is being finalized (UI.wl's acpFinalizeTurn): while its "Working" opener is
   open, the views of its entities are rendered (and cached) first, here in the pump rather than in the front end's
   evaluation of the frozen view; then the turn's change publication stops and its layout is bumped a last time
   (State.wl's acpFreezeTurnViews), so the front end shows the frozen view: the same boxes without Dynamics
   (liveLayout0). The view looks the same, except that the elapsed time stops. *)
acpFreezeLiveView // beginDefinition;

acpFreezeLiveView[ id_String ] := (
    If[ workOpenQ @ id, Scan[ acpEntityView[ id, # ] &, Replace[ acpTurnGet[ id, "Order", { } ], Except[ _List ] -> { } ] ] ];
    acpFreezeTurnViews @ id
);

acpFreezeLiveView // endDefinition;


liveLayout // beginDefinition;
liveLayout[ id_String ] := Replace[ acpIsolated @ withRenderContext @ liveLayout0 @ id, Except[ _RawBoxes ] :> unavailableBoxes[ ] ];
liveLayout // endDefinition;


liveLayout0 // beginDefinition;

(* A frozen turn (acpFreezeLiveView, while it is finalized) renders the same view without Dynamics: the entities' boxes
   and the header's label are put in directly, and the time this view was rendered is noted in the turn
   ("FrozenViewShownAt"): UI.wl's acpFinalizeTurn replaces the cell only once the front end has shown it. *)
liveLayout0[ id_String ] := Module[ { turn, open, frozen, items, boxes },
    turn = acpTurnGet @ id;
    If[ ! AssociationQ @ turn, Return[ unavailableBoxes[ ], Module ] ];
    open   = workOpenQ @ id;
    frozen = acpTurnViewsFrozenQ @ id;
    items  = If[ open, liveEntityItems[ id, turn, frozen ], { } ];
    boxes  = RawBoxes @ Cell[
        TextData @ Riffle[ Prepend[ items, workingHeaderCell[ id, open, frozen ] ], "\n" ],
        "Text",
        Background -> None
    ];
    If[ frozen, noteFrozenViewShown @ id ];
    boxes
];

liveLayout0 // endDefinition;


noteFrozenViewShown // beginDefinition;

noteFrozenViewShown[ id_String ] := acpTurnUpdate[
    id,
    <| "Turn" -> <| #, "FrozenViewShownAt" -> AbsoluteTime[ ] |>, "Changed" -> { }, "Layout" -> False |> &
];

noteFrozenViewShown // endDefinition;


(* Whether the "Working" opener of a live view is open. It starts closed ($workOpenDefault): the header's label
   (elapsed time and activity) says what is happening, and nothing is shown below it until the user opens it. The
   header's toggle passes the same default (workingHeader), so the two can't disagree. *)
workOpenQ // beginDefinition;
workOpenQ[ id_String ] := acpOpenQ[ id, "Work", $workOpenDefault ];
workOpenQ // endDefinition;


(* One inline cell per entity, each holding a Dynamic that tracks only that entity's symbol (frozen: the entity's
   boxes instead, see liveLayout0). Entities from subagent sessions get a "Subagent: title" header before the first
   one. *)
liveEntityItems // beginDefinition;

liveEntityItems[ id_String, turn_Association, frozen_ ] := Module[ { seen = { }, items = { }, child },
    Do[
        child = Lookup[ Replace[ turn[ "Entities", key ], Except[ _Association ] -> <| |> ], "Child", None ];
        If[ AssociationQ @ child && ! MemberQ[ seen, child[ "ID" ] ],
            AppendTo[ seen, child[ "ID" ] ];
            AppendTo[ items, subagentHeaderCell @ child ]
        ];
        AppendTo[ items, If[ TrueQ @ frozen, entityStaticCell[ id, key ], entityDynamicCell[ id, key ] ] ],
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


(* The same view as entityDynamicCell's, without the Dynamic (cached by acpEntityView; acpFreezeLiveView rendered it
   just before the turn was frozen) *)
entityStaticCell // beginDefinition;
entityStaticCell[ id_String, key_ ] := textBoxCell @ ToBoxes @ acpEntityView[ id, key ];
entityStaticCell // endDefinition;


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

(* Kernel-built opener header: chevron, "Working - 1m 5s - <activity>", and an FE-animated progress glyph. The label
   is its own small Dynamic tracking the turn's "Clock" symbol (bumped once a second by housekeeping), so updating it
   never rebuilds entity views. The opener starts closed (workOpenQ). *)
workingHeaderCell // beginDefinition;

workingHeaderCell[ id_String, open_, frozen_ ] := boxCell @ workingHeader[ id, open, frozen ];

workingHeaderCell // endDefinition;


workingHeader // beginDefinition;

(* frozen: the label as it is now, without the Dynamic (see liveLayout0) *)
workingHeader[ id_String, open_, frozen_ ] := With[
    {
        label = If[ TrueQ @ frozen,
            workingLabel @ id,
            With[ { sym = acpEntitySymbol[ id, "Clock" ] }, acpTrackedDynamic[ sym, workingLabel @ id ] ]
        ]
    },
    toggleHandler[
        Grid[
            {
                {
                    label,
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
        $workOpenDefault
    ]
];

workingHeader // endDefinition;


workingLabel // beginDefinition;

(* "Working - 12s - <activity>": the activity (e.g. the running tool's title) takes the rest of the line, cut in the
   front end like a tool card's title *)
workingLabel[ id_String ] := Replace[
    acpIsolated @ withRenderContext @ Module[ { turn, now, working, time, activity },
        turn = acpTurnGet @ id;
        now  = AbsoluteTime[ ];
        If[ ! AssociationQ @ turn,
            RawBoxes @ ToBoxes @ Style[ acpLabel[ "Working" ], FontSlant -> Italic ],
            working  = acpLabel[ "Working" ];
            time     = " \[CenterDot] " <> acpFormatDuration[ now - turn[ "StartTime" ] ] <> " \[CenterDot] ";
            activity = Replace[ acpTurnActivity[ turn, now ], s_String :> <| "Prefix" -> "", "Object" -> s, "Kind" -> "Text", "Suffix" -> "", "Truncated" -> False, "Tooltip" -> s |> ];
            (* a Grid, not a Row: the activity's clipping pane takes the rest of the line, not all of it *)
            RawBoxes @ ToBoxes @ Grid[
                {
                    {
                        Style[ working, FontSlant -> Italic ],
                        time,
                        titleView[ activity, acpFitWidth[ $workingReserve, { { working, { FontSlant -> Italic } }, { time, { } } } ] ]
                    }
                },
                Alignment        -> { Left, Baseline },
                BaselinePosition -> { 1, 1 },
                Spacings         -> { 0, 0 },
                BaseStyle        -> { LineBreakWithin -> False }
            ]
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
    boxes = Block[ { $renderMode = "Live", $cardContext = "Live", $turnID = id }, activateCodeBlocks @ renderEntity[ entity, key, turn ] ];
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


$renderMode   = "Live";
$turnID       = None;
$replayedTurn = False; (* True while the final cell of a replayed turn (a restored session) is rendered *)


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

renderEntity[ entity: KeyValuePattern[ "Type" -> "Message"    ], key_, turn_ ] := messageCell[ entity, key, turn ];
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

(* turn: the content blocks of a remote window's turn are on that host (resource links, see contentBlockView) *)
messageCell[ entity_Association, key_, turn_ ] := Cell[
    TextData @ Join[
        markdownItems[ entity[ "Text" ], key ],
        blockItems[ Lookup[ entity, "Blocks", { } ], turnRemote @ turn ]
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
    text   = acpPreprocessAnswer @ acpSafeText @ text0;
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
        items = textDataItems @ withUntrustedContent @ FormatChatOutput[ text, <| "Status" -> "Streaming" |> ];
        If[ TrueQ @ useCache && StringQ @ id, $turnResultCellCache[ id ] = $resultCellCache ]
    ];
    items
];

formatStreaming // endDefinition;


(* Finished formatting needs a front end for Wolfram Language code; without one (or if it fails), use the streaming
   formatter, which makes no front end calls. *)
finishedItems // beginDefinition;

finishedItems[ text0_String ] := Module[ { text, items },
    text = acpPreprocessAnswer @ acpSafeText @ text0;
    If[ StringTrim @ text === "", Return[ { }, Module ] ];
    items = If[ frontEndFormattingQ[ ],
        acpCatchAll[
            Block[ { $dynamicText = False, $resultCellCache = <| |> },
                textDataItems @ withUntrustedContent @ FormatChatOutput[ text, <| "Status" -> "Finished" |> ]
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


(* Non-text content blocks of messages (images, resource links). remote: the turn's "Remote" (acpTurnRemote: None for a
   local window's turn) *)
blockItems // beginDefinition;
blockItems[ { }, _ ] := { };
blockItems[ blocks_List, remote_ ] := Flatten @ Map[ { "\n", boxCell @ contentBlockView[ #, remote ] } &, blocks ];
blockItems // endDefinition;


turnRemote // beginDefinition;
turnRemote[ turn_Association ] := Replace[ Lookup[ turn, "Remote", None ], Except[ _Association ] -> None ];
turnRemote[ _ ] := None;
turnRemote // endDefinition;


(* The agent chooses the name, the URI and the type of a block: they are neutralized (linear syntax would make boxes
   of the agent's choice), and only web links (and a local agent's file links, its own files on this computer, as
   before) are clickable: any other scheme could reach an OS protocol handler (ms-msdt:, search-ms:, ...). A remote
   agent's file is not on this computer: its name is shown with the path on the host as a tooltip. *)
contentBlockView // beginDefinition;

contentBlockView[ block: KeyValuePattern[ "type" -> "image" ], _ ] := imageView @ block;

contentBlockView[ block: KeyValuePattern @ { "type" -> "resource_link", "uri" -> uri_String }, remote_ ] := Module[
    { name, safeURI },
    name    = Replace[ Lookup[ block, "name", uri ], Except[ _String ] -> uri ];
    name    = If[ AssociationQ @ remote, acpRemoteDisplayName @ name, acpSafeText @ name ];
    safeURI = acpNeutralizeLinearSyntax @ uri;
    Which[
        StringMatchQ[ uri, RegularExpression[ "(?i)https?://\\S+" ] ],
            Hyperlink[ name, safeURI ],
        ! AssociationQ @ remote && StringMatchQ[ uri, RegularExpression[ "(?i)file:\\S+" ] ],
            Hyperlink[ name, safeURI ],
        AssociationQ @ remote && StringStartsQ[ uri, "file:", IgnoreCase -> True ],
            Tooltip[
                Style[ name, FontFamily -> $codeFont, FontSize -> 12 ],
                acpLabel[
                    "ResourceLinkRemote",
                    <|
                        "host" -> acpRemoteDisplayName @ Replace[ Lookup[ remote, "Host", None ], Except[ _String ] -> "?" ],
                        "path" -> acpRemoteDisplayName @ remoteFilePath @ uri
                    |>
                ]
            ],
        True,
            Tooltip[ Style[ name, FontFamily -> $codeFont, FontSize -> 12 ], safeURI ]
    ]
];

contentBlockView[ KeyValuePattern @ { "type" -> "resource", "resource" -> KeyValuePattern[ "text" -> text_String ] }, _ ] :=
    RawBoxes @ codeBlock[ text, "text" ];

(* The type as the agent wrote it (ToString would interpret linear syntax in a string): *)
contentBlockView[ block_, _ ] := Style[
    StringJoin[
        "[",
        acpSafeText @ Replace[
            Lookup[ Replace[ block, Except[ _Association ] -> <| |> ], "type", "content" ],
            { s_String :> s, other_ :> ToString[ other, InputForm ] }
        ],
        "]"
    ],
    FontColor -> $mutedColor
];

contentBlockView // endDefinition;


(* The path of a file: URI (percent-decoded; the URI itself if it can't be decoded) *)
remoteFilePath // beginDefinition;
remoteFilePath[ uri_String ] := With[ { path = StringDelete[ uri, StartOfString ~~ ("file://" | "file:"), IgnoreCase -> True ] },
    Replace[ Quiet @ URLDecode @ path, Except[ _String ] -> path ]
];
remoteFilePath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeBlock*)

(* Chatbook code block cell (ChatCodeBlockTemplate) for text or code. Wolfram Language code gets Chatbook's own code
   formatting; finished WL formatting needs a front end, otherwise the streaming form is used. *)
codeBlock // beginDefinition;

(* The permission panel lives in the attached input cell, outside of any ChatOutput cell, where Chatbook's code block
   templates (and their Copy/Insert buttons) don't work: *)
codeBlock[ code_String, _String ] /; TrueQ @ $plainCodeBlocks := plainCodeBoxes @ code;

(* The code is agent- or tool-controlled, so the front end's linear syntax characters are neutralized (they would make
   the reparse of Wolfram Language code build boxes the agent chose, e.g. a DynamicBox that evaluates code when shown),
   and the bidi controls are shown as markers (acpSafeText: code can't look different from what it is; Copy and Insert
   take the markers too).
   Finished Wolfram Language formatting evaluates special boxes (DateObject options, Wolfram|Alpha and resource
   lookups), so it runs with no effects (withUntrustedContent). The streaming form makes no such evaluations. *)
codeBlock[ code0_String, lang_String ] := Module[ { code, finished, cell },
    code     = acpSafeText @ code0;
    finished = $renderMode === "Final" && (! wolframLanguageQ @ lang || frontEndFormattingQ[ ]);
    cell = If[ finished,
        Catch[ withUntrustedContent @ withCodeAsWritten @ Block[ { $dynamicText = False }, makeInteractiveCodeCell[ lang, code ] ], _, $Failed & ],
        $Failed
    ];
    If[ MatchQ[ cell, _Cell ],
        cell,
        Block[ { $dynamicText = True }, makeInteractiveCodeCell[ lang, code ] ]
    ]
];

codeBlock // endDefinition;


$plainCodeBlocks = False;


(* The agent's code is shown as it was written (and ran), and Copy and Insert take it as it is. Chatbook's own chats
   correct a model's Wolfram Language code before they show it: CodeCheckFix (my_var becomes myVar, a missing bracket is
   added), the sandbox's preprocessing (e.g. Import["<!...!>"] becomes InlinedExpression[...]), attachments put in place
   of expression URIs, code with In[n]:= / Out[n]= labels shown as a grid of cells, and the spaces around operators
   removed. None of that is right for an agent's tool input, and it takes seconds for large inputs (CodeCheckFix 27 s
   for 96 KB, the spacing 20 s for 126 KB, while the front end parses that in under a second) and keeps every input in
   memory. *)
withCodeAsWritten // beginDefinition;
withCodeAsWritten // Attributes = { HoldFirst };

withCodeAsWritten[ eval_ ] := Block[
    {
        preprocessSandboxString = Identity,
        autoCorrectWLCodeBlock  = Identity,
        inlineExpressionURIs    = Identity,
        parseCellGroupBlock     = Identity,
        adjustBoxSpacing        = Identity
    },
    eval
];

withCodeAsWritten // endDefinition;


plainCodeBoxes // beginDefinition;

plainCodeBoxes[ code_String ] := ToBoxes @ Framed[
    Style[
        acpSafeText @ code,
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

(* A finished thought of a single short line is that line, as in the final cell (stateless, no opener). The active
   thought stays "Thinking..." (its text may still be an unterminated "**Plann"); entitySignature includes the active
   state, so the view is rendered again once the thought is no longer the last entity. *)
thoughtCell[ entity_Association, key_, turn_ ] /; ! activeEntityQ[ key, turn ] && StringQ @ shortThoughtsText @ entity[ "Text" ] :=
    shortThoughtsCell[ entity, key ];

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


(* Static thoughts opener for the final cell, using Chatbook's ThoughtsOpener template (ShortThoughts for a single short
   line, as in Chatbook's own output: shortThoughtsText in Formatting.wl): *)
thoughtsOpenerCell // beginDefinition;

thoughtsOpenerCell[ entity_Association ] /; StringQ @ shortThoughtsText @ entity[ "Text" ] :=
    shortThoughtsCell[ entity, None ];

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


(* A thought of a single short line (e.g. the title of an OpenAI reasoning summary part), shown as that line with
   Chatbook's ShortThoughts template: no opener and no duration. The label is kept as the template's second argument, as
   in the other thoughts templates, but not shown. The line (without a bold wrapper that covers it) is formatted like
   any thought: neutralized and formatted as untrusted content (markdownItems: streamingItems in live views,
   finishedItems in final cells). key: the entity's key in live views (the streaming text cache), None in final cells *)
shortThoughtsCell // beginDefinition;

shortThoughtsCell[ entity_Association, key_ ] :=
    Cell[
        BoxData @ TemplateBox[
            {
                TextData @ markdownItems[ shortThoughtsText @ entity[ "Text" ], key ],
                ToBoxes @ thoughtLabel @ entity,
                <| "Type" -> "Literal" |>
            },
            "ShortThoughts"
        ],
        "ThoughtsOpener",
        Background -> None
    ];

shortThoughtsCell // endDefinition;


thoughtLabel // beginDefinition;

(* Replayed turns (restored sessions) have no timing: their thoughts are just "Thoughts" (note that None - None is 0) *)
thoughtLabel[ entity_Association ] := Module[ { secs },
    secs = Lookup[ entity, "LastTime", 0 ] - Lookup[ entity, "FirstTime", 0 ];
    Which[
        TrueQ @ $replayedTurn, acpLabel[ "ThoughtReplayed" ],
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

(* Header and body as boxes (typeset once): staticOpener writes the header once, above the body's pane *)
toolCard[ tool_Association, key_, turn_, open0_ ] /; $renderMode === "Final" :=
    staticOpener[ RawBoxes @ ToBoxes @ toolHeader[ tool, turn ], RawBoxes @ ToBoxes @ toolBody[ tool, key, turn ], TrueQ @ open0, cardStyle @ tool ];

toolCard[ tool_Association, key_, turn_, open0_ ] := Module[ { open, header },
    open   = If[ BooleanQ @ open0, open0, acpOpenQ[ $turnID, key, False ] ];
    header = toggleHandler[ cardHeaderGrid[ toolHeader[ tool, turn ], open ], $turnID, key, False ];
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
    (* ShowStringCharacters: a card copied into a notebook whose styles show string characters (Default.nb) shows its
       strings (the badge, the summary) without quotes, as in the window *)
    BaseStyle      -> { "Text", FontSize -> 13, LineBreakWithin -> Automatic, ShowStringCharacters -> False }
];

cardFrameOptions // endDefinition;


(* A tool card's header line, the same in live views (toolCard) and final cells (staticOpenerHeader): the header and
   the opener icon. open is True or False (live), or Dynamic[ Typeset`open ] (final: the icon follows the opener) *)
cardHeaderGrid // beginDefinition;
cardHeaderGrid[ header_, open_ ] := Grid[ { { header, openerIcon @ open } }, $headerGridOptions ];
cardHeaderGrid // endDefinition;


openerIcon // beginDefinition;

openerIcon[ open_Dynamic ] := PaneSelector[
    { True -> openerIcon @ True, False -> openerIcon @ False },
    open,
    ImageSize        -> Automatic,
    BaselinePosition -> Baseline
];

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

(* Front-end-only opener for the static final cell (state in a DynamicModule variable, toggled without the kernel).
   The header is written once, in the first row of a grid; the second row is a PaneSelector that shows the body when
   the card is open and Spacer[ { 0, 0 } ] when it is closed. With RowMinHeight -> 0 and the grid's baseline on the
   header (BaselinePosition -> { 1, 1 }), the closed card is exactly as tall as the header line, like a closed live
   card (a grid row is otherwise at least a line high, even when it shows nothing, and the default baseline added a
   few points at the top). The opener icon next to the header follows the state (a PaneSelector of the two icons,
   cardHeaderGrid with Dynamic[ Typeset`open ]).

   Only built-in boxes, Chatbook's opener icon templates and front-end-only Dynamics: the cell renders anywhere,
   including when it is copied or saved, and the header (with its title's fit DynamicBox and, with a badge, a fit
   switch) is stored once per card.

   Not a TemplateBox with an inline DisplayFunction (the earlier construct, which also stored the header once): pasting
   a copy of a final cell whose "Worked for" opener was open made the front end spin at 100% CPU (growing memory, never
   finishing) when the cards were such templates; a static inline-DisplayFunction template (a FrameBox of #1) still
   took 36 s for 8 cards. The same copy with the cards built from built-in boxes pastes in about a second (see
   docs/acp-window.md, "Tool cards"). Not the header in both panes either (OpenerView's and reviewOpener's way): that
   stores every card's header, with its fit DynamicBox, twice. *)
staticOpener // beginDefinition;

staticOpener[ header_, body_, open_, style_ ] := With[
    {
        h     = staticOpenerHeader @ header,
        b     = Pane[ body, ImageMargins -> { { 0, 0 }, { 0, 6 } } ],
        init  = TrueQ @ open,
        frame = cardFrameOptions @ style
    },
    DynamicModule[ { Typeset`open = init },
        Framed[
            Grid[
                {
                    { h },
                    {
                        PaneSelector[
                            { True -> b, False -> Spacer[ { 0, 0 } ] },
                            Dynamic @ Typeset`open,
                            ImageSize        -> Automatic,
                            BaselinePosition -> Top
                        ]
                    }
                },
                Alignment        -> { Left, Top },
                Spacings         -> { 0, 0 },
                RowMinHeight     -> 0,
                BaselinePosition -> { 1, 1 }
            ],
            frame
        ],
        DynamicModuleValues :> { }
    ]
];

staticOpener // endDefinition;


(* The clickable header of a staticOpener, with the opener icon of the current state: a click toggles Typeset`open,
   the variable of staticOpener's DynamicModule. The toggle uses only the front end's own functions (FEPrivate`Set and
   FEPrivate`If, as Chatbook's DiscardedMaterialOpener), so that the front end runs it without a kernel: with Not, a
   click in a saved copy with no kernel running started a kernel, and the card did not open. *)
staticOpenerHeader // beginDefinition;

staticOpenerHeader[ header_ ] := MouseAppearance[
    EventHandler[
        cardHeaderGrid[ header, Dynamic @ Typeset`open ],
        { "MouseDown" :> FEPrivate`Set[ Typeset`open, FEPrivate`If[ Typeset`open, False, True ] ] },
        Method -> "Preemptive", PassEventsDown -> Automatic, PassEventsUp -> True
    ],
    "LinkHand"
];

staticOpenerHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolHeader*)

(* icon, title, one-line summary, permission badge and status glyph. The title takes one line: the front end cuts it to
   the width that the rest leaves (see titleView). *)
toolHeader // beginDefinition;

toolHeader[ tool_Association, turn_ ] := Module[ { parts, summary, exitQ, glyph, title, badgeView },
    parts   = acpToolTitleParts[ tool, Automatic, turn ];
    summary = acpSafeText @ acpToolSummary @ tool;
    exitQ   = IntegerQ @ tool[ "ExitCode" ] && tool[ "ExitCode" ] =!= 0 && tool[ "ClientOutcome" ] === None;
    glyph   = statusGlyph @ tool;
    { title, badgeView } = headerTitleAndBadge[ parts, "Tool", summary, badgeLabel @ tool, glyph ];
    Grid[
        {
            Flatten @ {
                iconPane @ toolIcon @ tool,
                Style[ title, FontColor -> $toolLabelColor ],
                If[ summary === "", Nothing, Style[ summary, FontColor -> If[ exitQ, $amberText, $mutedColor ], FontSize -> 12, LineBreakWithin -> False ] ],
                Replace[ badgeView, None -> Nothing ],
                glyph
            }
        },
        $headerGridOptions
    ]
];

toolHeader // endDefinition;


(* The title and the badge of a card's header (type: "Tool" or "Permission", see headerTitleWidth). When the window is
   so narrow (or magnified) that the title's object would have less than $minObjectWidth points, the front end drops the
   badge and gives its room to the title (acpFitSwitch), so the status glyph and the opener stay in the card. A title
   without an object (cut as a whole: wholeTitleObject) keeps its badge only while all of it fits beside the badge, as
   when it was not cut: with the room of an object, "Stopped: ..." kept a "Stopped" badge and lost its verb. Gives
   { title, badge }, the badge None if there is none. *)
headerTitleAndBadge // beginDefinition;

headerTitleAndBadge[ parts0_Association, type_String, summary_String, badgeSpec_, glyph_ ] := Module[ { parts, wide, narrow, test },
    parts = wholeTitleObject @ parts0;
    wide = headerTitleWidth[ $cardContext, type, summary, badgeSpec, glyph ];
    If[ ! MatchQ[ badgeSpec, { _String, _String } ], Return[ { titleView[ parts, wide ], None }, Module ] ];
    (* the dropped badge leaves an empty column in the header's grid, which still takes its spacing *)
    narrow = headerTitleWidth[ $cardContext, type, summary, "Dropped", glyph ];
    (* the room that the fixed text leaves: parts0's, so a title without an object counts whole *)
    test   = headerTitleWidth[ $cardContext, type, summary, badgeSpec, glyph, Join[ titleSpans @ parts0[ "Prefix" ], titleSpans @ parts0[ "Suffix" ] ] ];
    {
        titleView[ parts, acpFitWidthSwitch[ test, $minObjectWidth, narrow, wide ] ],
        acpFitSwitch[ test, $minObjectWidth, "", badge @@ badgeSpec ]
    }
];

headerTitleAndBadge // endDefinition;

(* The least room for a title's object (points) that keeps a card's badge: an ellipsis and a few characters *)
$minObjectWidth = 24;


(* Splits backtick-delimited code spans out of a title (a string; neutralized here again, whatever the caller did). A
   title in parts (acpToolTitleParts) with a width (headerTitleWidth, acpFitWidth) takes one line, cut to that width in
   the front end (acpFitText): commands and patterns lose their end, paths their start (keeping the file name), and a
   tooltip shows the object's first lines when something was cut (or the object has more than one line). *)
titleView // beginDefinition;

(* A title as text (e.g. the permission panel's headline; the status line is an inline text cell: statusLineView). Code
   spans are always upright: in italic text they would otherwise render with a substitute font. String characters are
   hidden (a copy in a notebook whose stylesheet shows them showed quotes and escapes) and operators drawn as typed (a
   path's or a command's "-" is not a long minus sign), and a word joiner stands between a code span and the punctuation
   after it. *)
titleView[ title_String ] := Style[
    Row @ Replace[ noBreakBeforePunctuation @ titleSpans @ title, { s_String, o_List } :> If[ o === { }, s, Style[ s, Sequence @@ o ] ], { 1 } ],
    ShowStringCharacters -> False,
    PrivateFontOptions   -> { "OperatorSubstitution" -> False }
];

titleView[ parts0_Association, width_ ] := With[ { parts = wholeTitleObject @ parts0 },
    acpFitText @ <|
        "Prefix"      -> titleSpans @ parts[ "Prefix" ],
        "Object"      -> parts[ "Object" ],
        "ObjectStyle" -> If[ parts[ "Kind" ] === "Code", $codeSpanOptions, { } ],
        "Side"        -> If[ parts[ "Kind" ] === "Path", Left, Right ],
        "Suffix"      -> titleSpans @ parts[ "Suffix" ],
        "Width"       -> width,
        "Tooltip"     -> titleTooltip @ parts,
        "Truncated"   -> parts[ "Truncated" ]
    |>
];

titleView[ other_ ] := other;

titleView // endDefinition;


(* A title without an object and without code spans (e.g. "Preparing a command..." while the tool's input is still
   coming, or an agent's descriptive title) is its own text object, so that the front end cuts it at its end like any
   object (with an ellipsis and a tooltip) instead of the line being clipped *)
wholeTitleObject // beginDefinition;

wholeTitleObject[ parts: KeyValuePattern @ { "Prefix" -> title_String, "Object" -> "", "Suffix" -> "" } ] /;
    StringTrim @ title =!= "" && MatchQ[ titleSpans @ title, { { _String, { } } } ] :=
        <| parts, "Prefix" -> "", "Object" -> title, "Kind" -> "Text", "Tooltip" -> title |>;

wholeTitleObject[ parts_Association ] := parts;

wholeTitleObject // endDefinition;


$codeSpanOptions := { FontFamily -> $codeFont, FontSize -> 12, FontSlant -> Plain };


(* { { text, font options }... } of a title's text: code spans in backticks get the code font *)
titleSpans // beginDefinition;
titleSpans[ title_String ] := Replace[
    StringSplit[ acpSafeText @ title, "`" ~~ code: Except[ "`" ].. ~~ "`" :> codeSpan @ code ],
    s_String :> { s, { } },
    { 1 }
];
titleSpans // endDefinition;


codeSpan // beginDefinition;
codeSpan[ code_String ] := { code, $codeSpanOptions };
codeSpan // endDefinition;


(* Spans with a word joiner (U+2060, no line break) before the punctuation that starts a text span after a code span *)
noBreakBeforePunctuation // beginDefinition;

noBreakBeforePunctuation[ spans_List ] := MapIndexed[
    Function[
        { span, position },
        If[ First @ position > 1 && span[[ 2 ]] === { } && spans[[ First @ position - 1, 2 ]] =!= { } && StringStartsQ[ span[[ 1 ]], $$punctuation ],
            { "\[NoBreak]" <> span[[ 1 ]], { } },
            span
        ]
    ],
    spans
];

noBreakBeforePunctuation // endDefinition;

$$punctuation = "." | "," | ";" | ":" | "!" | "?" | ")" | "]" | "\[Ellipsis]";


(* The whole title with the object's first lines (wrapped, not wider than a typical window; see acpToolTitleParts) *)
titleTooltip // beginDefinition;

titleTooltip[ parts_Association ] := Pane[
    Style[
        Row @ {
            titleView @ parts[ "Prefix" ],
            Style[ acpSafeText @ parts[ "Tooltip" ], Sequence @@ If[ parts[ "Kind" ] === "Code", $codeSpanOptions, { } ] ],
            titleView @ parts[ "Suffix" ]
        },
        LineBreakWithin    -> Automatic,
        PrivateFontOptions -> { "OperatorSubstitution" -> False }
    ],
    ImageSize -> { UpTo[ $tooltipWidth ], Automatic }
];

titleTooltip // endDefinition;

$tooltipWidth = 480;


(* The width of a title in a card's header: what the line leaves after the card's frame, icon and opener, the summary,
   the badge and the status glyph, in the card's place (context: "Live", "Work" in the final cell's "Worked for" opener,
   "Tail" below it; see $cardContext). type: "Tool" (toolHeader) or "Permission" (permissionEntityCell). badgeSpec:
   the badge's { label, style }, None, or "Dropped" (a badge that the front end dropped: headerTitleAndBadge; its empty
   column still takes a $headerGap). texts: more text to leave room for (e.g. the title's own prefix and suffix, which
   leaves the room for its object) *)
headerTitleWidth // beginDefinition;

headerTitleWidth[ context_, type_, summary_String, badgeSpec_, glyph_ ] := headerTitleWidth[ context, type, summary, badgeSpec, glyph, { } ];

headerTitleWidth[ context_, type_, summary_String, badgeSpec_, glyph_, texts_List ] := acpFitWidth[
    Lookup[ $contextReserve, context, $contextReserve[ "Live" ] ] + {
        0,
        $cardReserve[ type ] +
            If[ summary === "", 0, $headerGap ] +
            Switch[ badgeSpec, { _String, _ }, $headerGap + $badgeChrome, "Dropped", $headerGap, _, 0 ] +
            glyphReserve @ glyph
    },
    Join[
        If[ summary === "", { }, { { summary, { FontSize -> 12 } } } ],
        Replace[ badgeSpec, { { label_String, _ } :> { { label, { FontSize -> 11 } } }, _ -> { } } ],
        glyphTexts @ glyph,
        texts
    ]
];

headerTitleWidth // endDefinition;


(* What a status glyph takes besides its text: *)
glyphReserve // beginDefinition;
glyphReserve[ Nothing ] := 0;
glyphReserve[ _Style ] := $headerGap;
glyphReserve[ _ ] := $headerGap + $progressIconWidth; (* the progress animation *)
glyphReserve // endDefinition;


glyphTexts // beginDefinition;
glyphTexts[ Style[ glyph_String, ___ ] ] := { { glyph, { FontWeight -> Bold } } };
glyphTexts[ _ ] := { };
glyphTexts // endDefinition;


(* The layout around titles, measured in a real front end with the ACPChat stylesheet (see acpFitWidth and
   docs/acp-window.md, "Tool cards"). $contextReserve is what a place takes from the window's content width outside a
   card, as { screen points, points at magnification 1 } (see acpFitWidth): the cell's margins, the template's frame
   and margins, the "Worked for" opener's indentation, and the screen points of the cells around the card (each
   reserves some at its right) and of frame lines. Inside a card everything scales, so these are in points at
   magnification 1: $cardReserve is what a card takes besides its title and the parts that headerTitleWidth adds (the
   frame, the icon, the opener; a standalone permission card (permissionEntityCell) has no opener: its title's room in a
   live view was ViewSize - 17 - (52.5 + 34.3 to 34.75) * magnification at 0.85 to 1.5, and 37.25 at 480 points and
   magnification 2, where tool cards also got about 4 points less than the linear model; 35.5 keeps all of them inside
   the room with the safety margin), $headerGap the space between two
   parts of a header, $badgeChrome a badge's frame. $workingReserve is what the Working header takes besides its
   label's text (the template, the opener's chevron, the progress animation, which magnification does not scale), as
   { screen points, points at magnification 1 } *)
$contextReserve    = <| "Live" -> { 17, 52.5 }, "Work" -> { 16.5, 75 }, "Tail" -> { 9.75, 50.25 } |>;
$cardReserve       = <| "Tool" -> 51, "Permission" -> 35.5 |>;
$headerGap         = 5.2;
$badgeChrome       = 11;
$progressIconWidth = 20;
$workingReserve    = { 13.25, 93 };

(* Where tool cards are rendered: "Live", "Work" (in the final cell's "Worked for" opener) or "Tail" (below it) *)
$cardContext = "Live";


iconPane // beginDefinition;
iconPane[ icon_ ] := Pane[ icon, ImageSize -> { 16, 16 }, ImageSizeAction -> "ShrinkToFit", BaselinePosition -> Scaled[ 0.2 ], ContentPadding -> False ];
iconPane // endDefinition;


(* The icons are DynamicBoxes of Chatbook's front end resources (chatbookIcon[ name, False ]), not Chatbook's
   "ToolIcon..." templates, whose DisplayFunction is the same DynamicBox: pasting a copy of a final cell whose "Worked
   for" opener was open took about 2 s per template icon (a copy of 4 read cards: 7 s with plain frames, 50 s with
   HEAD's openers; 40 cards never finished), and about half a second for the whole copy without the templates (see
   docs/acp-window.md, "Tool cards"). *)
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
                names =!= { } && AllTrue[ names, StringContainsQ[ #, "Context" | "Documentation" ] & ], chatbookIcon[ "ToolIconDocumentationSearcher", False ],
                True, chatbookIcon[ "WrenchIcon", False ]
            ],
        MatchQ[ name, "read" | "list" ] || (name === None && kind === "read"),
            chatbookIcon[ "ToolIconFileReader", False ],
        MatchQ[ name, "edit" | "write" | "patch" | "multiedit" ] || (name === None && MatchQ[ kind, "edit" | "delete" | "move" ]),
            $editIcon,
        name === "shell" || (name === None && kind === "execute"),
            chatbookIcon[ "ExternalLanguageIconShell", False ],
        MatchQ[ name, "glob" | "grep" | "codesearch" | "models" ] || (name === None && kind === "search"),
            chatbookIcon[ "ToolIconDocumentationSearcher", False ],
        name === "webfetch" || (name === None && kind === "fetch"),
            chatbookIcon[ "ToolIconWebFetcher", False ],
        name === "websearch",
            chatbookIcon[ "ToolIconWebSearcher", False ],
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
        (* a direct call of an MCP tool: "Name" is lower case (acpCanonicalToolName) *)
        StringQ @ name && StringContainsQ[ name, "WolframLanguageEvaluator", IgnoreCase -> True ],
            chatbookIcon[ "ToolIconWolframLanguageEvaluator", False ],
        StringQ @ name && StringContainsQ[ name, "WolframAlpha", IgnoreCase -> True ],
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


(* The badge of a tool card: { label, style } or None *)
badgeLabel // beginDefinition;

badgeLabel[ tool_Association ] := Module[ { outcome },
    outcome = Replace[ tool[ "Permission" ], { KeyValuePattern[ "Outcome" -> o_ ] :> o, _ -> None } ];
    Which[
        tool[ "ClientOutcome" ] === "Declined", { acpLabel[ "BadgeDeclined" ], "Neutral" },
        tool[ "ClientOutcome" ] === "Stopped" , { acpLabel[ "BadgeStopped"  ], "Neutral" },
        awaitingApprovalQ @ tool              , { acpLabel[ "BadgeAwaitingApproval" ], "Amber" },
        outcome === "once"                    , { acpLabel[ "BadgeAllowedOnce" ], "Neutral" },
        outcome === "always"                  , { acpLabel[ "BadgeAllowedAlways" ], "Neutral" },
        True                                  , None
    ]
];

badgeLabel // endDefinition;


(* style: "Amber" | "Red" | "Green" | anything else (neutral) *)
badge // beginDefinition;

badge[ text_String, style_String ] := Framed[
    Style[ text, FontSize -> 11, LineBreakWithin -> False, FontColor -> Switch[ style, "Amber", $amberText, "Red", $redText, "Green", $greenText, _, $mutedColor ] ],
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
                    { c_String, _ } | { _, c_String } :> section[ "SectionInput", codeView[ c, "text" ] ],
                    _ :> None
                }
            ],
        MatchQ[ name, "edit" | "write" | "patch" | "multiedit" ] && tool[ "Diffs" ] =!= { },
            None, (* the Changes section shows the diffs *)
        name === "execute",
            executeInputSection[ tool, key ],
        name === "subagent",
            subagentInputSection @ input,
        (* a direct call of the notebook tools (not in code mode): the same view as a call in a script *)
        StringQ @ acpNotebookToolName @ tool[ "RawName" ],
            Replace[ argumentsView[ input, False, $notebookToolParameters, <| |> ], view: Except[ None ] :> section[ "SectionInput", view ] ],
        (* a direct call of the Wolfram Language evaluator (not in code mode): its code as Wolfram Language (Chatbook's
           code formatting, Copy and Insert), as a call in a script shows it (executeCallView), and its other arguments *)
        wolframEvaluatorCallQ[ name, input ],
            section[ "SectionInput", wolframEvaluatorInputView @ input ],
        AssociationQ @ input && Length @ input > 0,
            section[ "SectionInput", rawInputGrid @ input ],
        True,
            None
    ]
];

inputSection // endDefinition;


wolframEvaluatorCallQ // beginDefinition;

(* "Name" of a direct call of an MCP tool is lower case (acpCanonicalToolName), e.g. "wolfram_wolframlanguageevaluator" *)
wolframEvaluatorCallQ[ name_String, input_Association ] :=
    StringContainsQ[ name, "WolframLanguageEvaluator", IgnoreCase -> True ] && StringQ @ Lookup[ input, "code", None ];

wolframEvaluatorCallQ[ _, _ ] := False;

wolframEvaluatorCallQ // endDefinition;


wolframEvaluatorInputView // beginDefinition;

wolframEvaluatorInputView[ input_Association ] := With[ { rest = KeyDrop[ input, "code" ] },
    If[ Length @ rest > 0,
        Column[ { codeView[ input[ "code" ], "Wolfram" ], rawInputGrid @ rest }, Spacings -> 0.4 ],
        codeView[ input[ "code" ], "Wolfram" ]
    ]
];

wolframEvaluatorInputView // endDefinition;


rawInputGrid // beginDefinition;

(* The agent's input: keys and values are shown as plain text (linear syntax neutralized) *)
rawInputGrid[ input_Association ] := Grid[
    KeyValueMap[
        { Style[ acpSafeText @ #1, FontColor -> $mutedColor, FontSize -> 12 ], inputValueView @ #2 } &,
        input
    ],
    Alignment -> { Left, Top },
    Spacings  -> { 1, 0.4 }
];

rawInputGrid // endDefinition;


inputValueView // beginDefinition;
inputValueView[ s_String ] /; StringContainsQ[ s, "\n" ] || StringLength @ s > 80 := codeView[ s, "text" ];
inputValueView[ s_String ] := Style[ acpSafeText @ s, FontFamily -> $codeFont, FontSize -> 12 ];
inputValueView[ other_ ] := Style[ acpSafeText @ shortJSON @ other, FontFamily -> $codeFont, FontSize -> 12 ];
inputValueView // endDefinition;


subagentInputSection // beginDefinition;
subagentInputSection[ input_Association ] := With[ { prompt = Lookup[ input, "prompt", None ] },
    If[ StringQ @ prompt,
        section[ "SectionInput", markdownView @ prompt ],
        section[ "SectionInput", rawInputGrid @ input ]
    ]
];
subagentInputSection[ _ ] := None;
subagentInputSection // endDefinition;


(* MCP code mode: each call is shown with its input (while the call runs, as far as the script shows it, see
   acpExecuteScript): the code of a Wolfram Language call with Chatbook's WL code formatting, the arguments of the
   notebook tools and of other tools as grids. The JavaScript is in a collapsed "Script" section. *)
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
                    { subOpener[ key, "Script", "SectionScript", codeView[ StringTrim @ script, "text" ] ] },
                    { }
                ]
            ],
            Spacings -> 0.5
        ]
    ]
];

executeInputSection // endDefinition;


(* One call of acpExecuteToolCalls. titles: the window titles of the notebooks that calls of the notebook tools name, as
   the permission panel has them (see notebookArgumentView); <| |> elsewhere. *)
executeCallView // beginDefinition;

executeCallView[ call_Association ] := executeCallView[ call, <| |> ];

executeCallView[ call_Association, titles_Association ] := Module[ { tool, code, arguments, more },
    tool      = call[ "Tool" ];
    code      = call[ "Code" ];
    arguments = call[ "Arguments" ];
    more      = TrueQ @ call[ "MoreArguments" ];
    Column[
        {
            Style[ acpSafeText @ shortenText[ acpMCPDisplayName @ tool, 80 ], FontColor -> $mutedColor, FontSize -> 12 ],
            Which[
                StringQ @ acpNotebookToolName @ tool,
                    Replace[ argumentsView[ arguments, more, $notebookToolParameters, titles ], None -> Nothing ],
                StringQ @ code,
                    codeView[ code, If[ StringContainsQ[ tool, "Wolfram" ], "Wolfram", "text" ] ],
                True,
                    Replace[ argumentsView[ arguments, more, All, titles ], None -> Nothing ]
            ]
        },
        Spacings -> 0.2
    ]
];

executeCallView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Tool call arguments*)

(* The arguments of a tool call as a grid of keys and values: the parameters of the notebook tools in their order
   ($notebookToolParameters, other keys are not used by the tools), or All keys. Values that a script does not write as
   literals are "(computed)" (see acpExecuteScript), and a last row stands for arguments that a spread or a computed
   key may add (more). The values are the agent's: they are shown as plain text, never formatted. None if there is
   nothing to show. *)
argumentsView // beginDefinition;

argumentsView[ _Missing, _, _, _ ] := computedView[ ];

argumentsView[ arguments_Association, more_, keys_, titles_Association ] := Module[ { shown, rows },
    shown = If[ keys === All, arguments, KeyTake[ arguments, keys ] ];
    rows  = KeyValueMap[ { argumentKeyView @ #1, argumentValueView[ #1, #2, titles ] } &, shown ];
    If[ TrueQ @ more, AppendTo[ rows, { argumentKeyView[ "\[Ellipsis]" ], computedView[ ] } ] ];
    If[ rows === { }, None, Grid[ rows, Alignment -> { Left, Top }, Spacings -> { 1, 0.4 } ] ]
];

argumentsView[ ___ ] := None;

argumentsView // endDefinition;


argumentKeyView // beginDefinition;
argumentKeyView[ key_ ] := Style[ acpSafeText @ shortenText[ ToString @ key, 40 ], FontColor -> $mutedColor, FontSize -> 12 ];
argumentKeyView // endDefinition;


argumentValueView // beginDefinition;

argumentValueView[ _, _Missing, _ ] := computedView[ ];
argumentValueView[ "notebook", spec_String, titles_Association ] := notebookArgumentView[ spec, Lookup[ titles, spec, None ] ];
argumentValueView[ "markdown", text_String, _ ] := codeView[ text, "text", argumentLimits[ ] ];
argumentValueView[ _, list: { (_String | _Integer | True | False | Null)... }, _ ] := codeText @ StringRiffle[ jsonText /@ list, ", " ];
argumentValueView[ _, value: (_Integer | True | False | Null), _ ] := codeText @ jsonText @ value;
argumentValueView[ _, value_, _ ] := inputValueView @ value;

argumentValueView // endDefinition;


(* The notebook of a call of the notebook tools: its window title and id, if the permission panel resolved the argument
   to one of the notebooks the tools reach (see acpNotebookTitles), else the argument as it is *)
notebookArgumentView // beginDefinition;

notebookArgumentView[ spec_String, KeyValuePattern @ { "ID" -> id_String, "Title" -> title_String } ] := Row[
    { Style[ acpSafeText @ shortenText[ title, 80 ], FontWeight -> "DemiBold" ], "  ", codeText @ id }
];

notebookArgumentView[ spec_String, _ ] := codeText @ spec;

notebookArgumentView // endDefinition;


codeText // beginDefinition;
codeText[ s_String ] := Style[ acpSafeText @ shortenText[ s, $maxLineLength ], FontFamily -> $codeFont, FontSize -> 12 ];
codeText // endDefinition;


jsonText // beginDefinition;
jsonText[ s_String ] := s;
jsonText[ n_Integer ] := ToString @ n;
jsonText[ True  ] := "true";
jsonText[ False ] := "false";
jsonText[ Null  ] := "null";
jsonText // endDefinition;


computedView // beginDefinition;
computedView[ ] := Style[ acpLabel[ "ScriptComputed" ], FontColor -> $mutedColor, FontSize -> 12, FontSlant -> Italic ];
computedView // endDefinition;


(* One line, at most n characters *)
shortenText // beginDefinition;
shortenText[ s_String, n_Integer ] := With[ { line = StringReplace[ s, WhitespaceCharacter.. -> " " ] },
    If[ StringLength @ line > n, StringTake[ line, n - 1 ] <> "\[Ellipsis]", line ]
];
shortenText // endDefinition;


(* The limits of markdown shown for an argument: fewer lines in the permission panel *)
argumentLimits // beginDefinition;
argumentLimits[ ] := Replace[ $argumentLines, { n_Integer :> <| codeViewLimits[ ], "Lines" -> n |>, _ :> codeViewLimits[ ] } ];
argumentLimits // endDefinition;

$argumentLines = Automatic;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Changes*)
changesSection // beginDefinition;

(* The cards of a final cell start closed, and a closed card is not laid out, so they keep $finalDiffLines rows; the
   expanded cards of an interrupted turn's last step (e.g. a large edit the user rejected) are laid out at once, so
   they keep only as many as live cards ($expandedFinalCard, see finalCell) *)
changesSection[ tool_Association, turn_ ] := If[ tool[ "Diffs" ] === { },
    None,
    section[
        "SectionChanges",
        Column[
            heightLimited @ acpDiffView[
                #,
                <|
                    "MaxLines"         -> If[ $renderMode === "Final" && ! TrueQ @ $expandedFinalCard, $finalDiffLines, $liveDiffLines ],
                    "ProjectDirectory" -> Lookup[ Replace[ turn, Except[ _Association ] -> <| |> ], "ProjectDirectory", None ]
                |>
            ] & /@ tool[ "Diffs" ],
            Spacings -> 0.6
        ]
    ]
];

changesSection // endDefinition;

$expandedFinalCard = False;

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
outputTextView[ text_String, limit_Integer ] := tailView[ text, limit ];
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
                    tailView[ acpStripToolOutput @ If[ StringQ @ #2, #2, shortJSON @ #2 ], limit ]
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

(* The tool call as the agent sent it, as JSON: a view for debugging, so it is kept small (the Input, Changes and Output
   sections show the texts in full): string values longer than $detailsValueLength characters are shortened (the JSON
   stays valid; the note below the block says how much was left out), the content is left out when it only repeats the
   raw output's text (OpenCode sends a tool's output in both), and the view has its own limits ($detailsLimits). *)
detailsSection[ tool_Association, key_ ] := Module[ { data, shortened, json, head },
    data = DeleteCases[
        <|
            "toolCallId" -> tool[ "ToolCallID" ],
            "name"       -> Replace[ tool[ "RawName" ], None -> Missing[ ] ],
            "kind"       -> Replace[ tool[ "Kind" ], None -> Missing[ ] ],
            "status"     -> tool[ "Status" ],
            "rawInput"   -> Replace[ tool[ "RawInput" ], None -> Missing[ ] ],
            "rawOutput"  -> Replace[ tool[ "RawOutput" ], None -> Missing[ ] ],
            "content"    -> Replace[ detailsContent @ tool, { } -> Missing[ ] ]
        |>,
        _Missing
    ];
    { data, shortened } = shortenDetailsValues @ data;
    json = shortJSON[ data, False ];
    head = codeHead[ json, Merge[ { codeViewLimits[ ], $detailsLimits }, Min ] ];
    subOpener[
        key,
        "Details",
        "SectionDetails",
        withTruncationNote[ heightLimited @ RawBoxes @ codeBlock[ head[ "Text" ], "text" ], <| head, "ShortenedCharacters" -> shortened |>, "More" ]
    ]
];

detailsSection // endDefinition;

$detailsValueLength = 2000;
$detailsLimits      = <| "Lines" -> 400, "Characters" -> 20000 |>;


(* The content of a tool call for Details: { } if it only holds texts that are also in the raw output *)
detailsContent // beginDefinition;

detailsContent[ tool_Association ] := Module[ { content, texts },
    content = textContentOnly @ tool[ "Content" ];
    texts   = Cases[ content, KeyValuePattern @ { "type" -> "content", "content" -> KeyValuePattern @ { "type" -> "text", "text" -> t_String } } :> t ];
    If[ content =!= { } && Length @ texts === Length @ content && SubsetQ[ Cases[ { tool[ "RawOutput" ] }, _String, Infinity ], texts ],
        { },
        content
    ]
];

detailsContent // endDefinition;


(* { data with its long string values shortened (keys stay), the number of characters left out } *)
shortenDetailsValues // beginDefinition;

shortenDetailsValues[ data_ ] := Module[ { omitted = 0, shorten },
    shorten = Function[
        s,
        If[ StringLength @ s > $detailsValueLength,
            omitted += StringLength @ s - $detailsValueLength;
            StringTake[ s, $detailsValueLength ] <> "\[Ellipsis]",
            s
        ]
    ];
    { mapStringValues[ shorten, data ], omitted }
];

shortenDetailsValues // endDefinition;


mapStringValues // beginDefinition;
mapStringValues[ f_, data_Association ] := mapStringValues[ f, # ] & /@ data;
mapStringValues[ f_, data_List ] := mapStringValues[ f, # ] & /@ data;
mapStringValues[ f_, s_String ] := f @ s;
mapStringValues[ f_, other_ ] := other;
mapStringValues // endDefinition;


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

(* The limits of code and text views (tool input and output, Details), per place: whole lines and characters. A live
   view shows a head that fits its code block (the "Active" template clips at 400 points, and live views have no scroll
   panes, see R6); the final cell shows everything, in panes of limited height that scroll (see heightLimited), up to a
   cap for pathological sizes; the "Panel" limit bounds only a permission request's raw-input values (rawInputGrid ->
   inputValueView), which have no "View full" link. A request's command, diff or script is shown with its own, smaller
   preview and a "View full ..." link to the details window (permissionPreview0: $permissionCommandLines and
   $permissionCommandLength for commands, permissionDiffPreview for diffs, $permissionScriptLines for scripts). *)
$codeViewLimits = <|
    "Live"  -> <| "Lines" -> 20  , "Characters" -> 1000   |>,
    "Final" -> <| "Lines" -> 2000, "Characters" -> 200000 |>,
    "Panel" -> <| "Lines" -> 120 , "Characters" -> 20000  |>
|>;

$finalViewHeight = 480; (* points; above the code block template's own 400-point pane, which scrolls first *)


codeViewLimits // beginDefinition;
codeViewLimits[ ] := $codeViewLimits @ Which[ TrueQ @ $plainCodeBlocks, "Panel", $renderMode === "Final", "Final", True, "Live" ];
codeViewLimits // endDefinition;


(* Code or text in a code block: whole lines within the limits (nothing is cut inside a line unless the first line alone
   is too long), and a note of what was left out below the block, never in it: Copy and Insert take the block's text.
   Wolfram Language code that was cut and is not complete is shown as text: as code it would be colored as a syntax
   error. *)
codeView // beginDefinition;

codeView[ code_String, lang_String ] := codeView[ code, lang, codeViewLimits[ ] ];

codeView[ code_String, lang_String, limits_Association ] := Module[ { head, shown },
    head  = codeHead[ code, limits ];
    shown = If[ wolframLanguageQ @ lang && truncatedQ @ head && ! SyntaxQ @ head[ "Text" ], "text", lang ];
    withTruncationNote[ heightLimited @ RawBoxes @ codeBlock[ head[ "Text" ], shown ], head, "More" ]
];

codeView // endDefinition;


(* Tool output: its last lines within the limits (lines: the number of lines for the place) *)
tailView // beginDefinition;

tailView[ text_String, lines_Integer ] := With[ { tail = codeTail[ text, <| codeViewLimits[ ], "Lines" -> lines |> ] },
    withTruncationNote[ heightLimited @ RawBoxes @ codeBlock[ tail[ "Text" ], "text" ], tail, "Earlier" ]
];

tailView // endDefinition;


(* Markdown (a subagent's prompt), formatted, within the limits *)
markdownView // beginDefinition;

markdownView[ text_String ] := With[ { head = codeHead[ text, codeViewLimits[ ] ] },
    withTruncationNote[
        heightLimited @ RawBoxes @ Cell[ TextData @ markdownItems[ head[ "Text" ], { "SubagentPrompt" } ], "Text", Background -> None ],
        head,
        "More"
    ]
];

markdownView // endDefinition;


(* <| "Text" -> the first lines of text within the limits, "OmittedLines", "OmittedCharacters" |>: only whole lines are
   kept, unless the first one alone is longer than the limit of characters *)
codeHead // beginDefinition;

codeHead[ text_String, limits_Association ] := Module[ { lines, n, k, shown },
    lines = StringSplit[ text, "\n", All ];
    n     = Length @ lines;
    k     = LengthWhile[ Accumulate[ StringLength /@ Take[ lines, UpTo @ limits[ "Lines" ] ] + 1 ], # <= limits[ "Characters" ] + 1 & ];
    Which[
        k >= n, truncation[ text, 0, 0 ],
        k > 0 , truncation[ StringRiffle[ Take[ lines, k ], "\n" ], n - k, 0 ],
        True  ,
            shown = StringTake[ First @ lines, limits[ "Characters" ] ];
            truncation[ shown, n - 1, StringLength @ First @ lines - StringLength @ shown ]
    ]
];

codeHead // endDefinition;


(* The same for the last lines; a last line that alone is too long loses its start *)
codeTail // beginDefinition;

codeTail[ text_String, limits_Association ] := Module[ { lines, n, k, shown },
    lines = StringSplit[ text, "\n", All ];
    n     = Length @ lines;
    k     = LengthWhile[ Accumulate[ StringLength /@ Reverse @ Take[ lines, -Min[ n, limits[ "Lines" ] ] ] + 1 ], # <= limits[ "Characters" ] + 1 & ];
    Which[
        k >= n, truncation[ text, 0, 0 ],
        k > 0 , truncation[ StringRiffle[ Take[ lines, -k ], "\n" ], n - k, 0 ],
        True  ,
            shown = StringTake[ Last @ lines, -limits[ "Characters" ] ];
            truncation[ shown, n - 1, StringLength @ Last @ lines - StringLength @ shown ]
    ]
];

codeTail // endDefinition;


truncation // beginDefinition;
truncation[ text_String, lines_Integer, characters_Integer ] := <| "Text" -> text, "OmittedLines" -> lines, "OmittedCharacters" -> characters |>;
truncation // endDefinition;


truncatedQ // beginDefinition;
truncatedQ[ t_Association ] := t[ "OmittedLines" ] > 0 || t[ "OmittedCharacters" ] > 0 || Lookup[ t, "ShortenedCharacters", 0 ] > 0;
truncatedQ // endDefinition;


(* The view with a note of what was left out, outside of it: below it ("More": a head, the omitted text came after it),
   or above it ("Earlier": a tail, the omitted text came before it). "ShortenedCharacters": characters left out of long
   values (see detailsSection). *)
withTruncationNote // beginDefinition;

withTruncationNote[ view_, truncation_Association, _ ] /; ! truncatedQ @ truncation := view;

withTruncationNote[ view_, truncation_Association, where_String ] := Module[ { lines, characters, shortened, note },
    lines      = If[ truncation[ "OmittedLines" ] > 0, acpLabel[ "Truncated" <> where <> "Lines", <| "n" -> truncation[ "OmittedLines" ] |> ], Nothing ];
    characters = If[ truncation[ "OmittedCharacters" ] > 0, acpLabel[ "Truncated" <> where <> "Characters", <| "n" -> truncation[ "OmittedCharacters" ] |> ], Nothing ];
    shortened  = If[ Lookup[ truncation, "ShortenedCharacters", 0 ] > 0, acpLabel[ "TruncatedLongValues", <| "n" -> truncation[ "ShortenedCharacters" ] |> ], Nothing ];
    note = Style[
        Row[ If[ where === "Earlier", { lines, characters, shortened }, { characters, lines, shortened } ], "  " ],
        FontColor -> $mutedColor,
        FontSize  -> 11
    ];
    Column[ If[ where === "Earlier", { note, view }, { view, note } ], Spacings -> 0.2 ]
];

withTruncationNote // endDefinition;


(* A view in the final cell is at most $finalViewHeight points high, and scrolls (live views have no scroll panes, see
   R6). In the ACP window a code block's template scrolls at 400 points, below this height, so code never gets two
   scroll panes; a copied cell in a notebook whose template has no pane (Chatbook.nb) gets this one. *)
heightLimited // beginDefinition;

heightLimited[ view_ ] /; $renderMode === "Final" && ! TrueQ @ $plainCodeBlocks := Pane[
    view,
    ImageSize          -> { Automatic, UpTo[ $finalViewHeight ] },
    Scrollbars         -> Automatic,
    AppearanceElements -> None
];

heightLimited[ view_ ] := view;

heightLimited // endDefinition;


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
   patches; a column without numbers, e.g. the old one of a new file, is left out). The chat's views use neither.
   A diff item may also hold its "Rows" (made by acpDiffRows and cut, e.g. by PermissionDetails.wl). A line diff that
   could not compare every changed line (see acpLineDiff) gets a note that says so. *)
acpDiffView // beginDefinition;

acpDiffView[ diff_Association ] := acpDiffView[ diff, <| |> ];

acpDiffView[ diff_Association, opts_Association ] /; KeyExistsQ[ diff, "type" ] && ! KeyExistsQ[ diff, "Path" ] :=
    acpDiffView[ normalDiff @ diff, opts ];

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
                    If[ omitted > 0, Style[ acpLabel[ "TruncatedMoreLines", <| "n" -> omitted |> ], FontColor -> $mutedColor, FontSize -> 11 ], Nothing ],
                    If[ diffAlignedQ @ diff, Nothing, Style[ acpLabel[ "DiffNotAligned" ], FontColor -> $mutedColor, FontSize -> 11 ] ]
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


(* A raw ACP diff (<| "type" -> "diff", "path", "oldText", "newText" |>) as a normalized diff item (see Transcript.wl);
   normalized items stay as they are *)
normalDiff // beginDefinition;

normalDiff[ diff_Association ] /; KeyExistsQ[ diff, "type" ] && ! KeyExistsQ[ diff, "Path" ] := <|
    "Path"        -> Replace[ Lookup[ diff, "path", "" ], Except[ _String ] -> "" ],
    "OldText"     -> Replace[ Lookup[ diff, "oldText", None ], Except[ _String ] -> None ],
    "NewText"     -> Replace[ Lookup[ diff, "newText", None ], Except[ _String ] -> None ],
    "Patch"       -> Replace[ Lookup[ diff, "patch", None ], Except[ _String ] -> None ],
    "Synthesized" -> False
|>;

normalDiff[ diff_Association ] := diff;

normalDiff // endDefinition;


(* False for a line diff whose changed lines could not all be compared line by line (acpLineDiffInfo) *)
diffAlignedQ // beginDefinition;

diffAlignedQ[ KeyValuePattern[ "Patch" -> _String ] | KeyValuePattern[ "Write" -> True ] | KeyValuePattern[ "Rows" -> _List ] ] := True;

diffAlignedQ[ diff_Association ] := TrueQ @ acpLineDiffInfo[
    Replace[ Lookup[ diff, "OldText", None ], Except[ _String ] -> "" ],
    Replace[ Lookup[ diff, "NewText", None ], Except[ _String ] -> "" ]
][ "Aligned" ];

diffAlignedQ // endDefinition;


diffHeader // beginDefinition;

diffHeader[ diff_Association, { a_, d_ }, root_ ] := Row[
    Flatten @ {
        Style[ diffPathLabel @ relativePath[ diff[ "Path" ], root ], FontFamily -> $codeFont, FontSize -> 12, FontWeight -> "DemiBold" ],
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


(* The path of a diff (the agent's text, like its lines): display-safe in the permission panel ($safeDiffLines, see
   diffLineText), where an invisible character must not disguise the file that is changed *)
diffPathLabel // beginDefinition;
diffPathLabel[ path_String ] /; TrueQ @ $safeDiffLines := acpRemoteDisplayName @ path;
diffPathLabel[ path_ ] := acpSafeText @ path;
diffPathLabel // endDefinition;


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

(* Rows that were made already (acpDiffRows), e.g. cut and made display-safe by the permission details window *)
diffRows[ KeyValuePattern[ "Rows" -> rows_List ], _, _ ] := rows;

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


(* The rows of a diff item (normalized, or a raw ACP diff) as acpDiffView shows them, with line numbers ({ op, line,
   old, new }) if numbers is True (for PermissionDetails.wl) *)
acpDiffRows // beginDefinition;
acpDiffRows[ diff_Association, numbers_ ] := diffRows[ normalDiff @ diff, $diffContextLines, TrueQ @ numbers ];
acpDiffRows // endDefinition;


(* The rows of acpDiffRows[ diff, True ] (with line numbers), made in parts: PermissionDetails.wl writes a large diff in
   steps of the pump, and making all rows of a file of 100,000 lines takes about 0.4 s. acpDiffRowSource[ diff ] takes a
   few milliseconds per 10,000 lines (the line diff is cached, acpLineDiff; the numbers and the collapsed context are
   computed on packed arrays, as numberLineOps and collapseContext do): <| "Kind", "Count" (the number of rows),
   "MaxNumbers" ({ old, new }: the largest line number in the rows, 0 for a column without numbers), ... |>.
   acpDiffSourceRows[ source, { a, b } ] gives rows a to b, and acpDiffSourceLineLengths[ source, { a, b } ] the lengths
   of their lines, without making the others. *)
acpDiffRowSource // beginDefinition;

acpDiffRowSource[ diff0_Association ] := With[ { diff = normalDiff @ diff0 },
    Which[
        (* rows that were made already, and patches (made whole: they are short) *)
        ListQ @ Lookup[ diff, "Rows", None ] || StringQ @ Lookup[ diff, "Patch", None ],
            rowsSource @ diffRows[ diff, $diffContextLines, True ],
        TrueQ @ Lookup[ diff, "Write", False ],
            writeSource @ StringSplit[ StringDelete[ Replace[ diff[ "NewText" ], Except[ _String ] -> "" ], "\n" ~~ EndOfString ], "\n", All ],
        True,
            opsSource @ acpLineDiff[ Replace[ diff[ "OldText" ], Except[ _String ] -> "" ], Replace[ diff[ "NewText" ], Except[ _String ] -> "" ] ]
    ]
];

acpDiffRowSource // endDefinition;


rowsSource // beginDefinition;

rowsSource[ rows_List ] := <|
    "Kind"       -> "Rows",
    "Rows"       -> rows,
    "Count"      -> Length @ rows,
    "MaxNumbers" -> Table[ Max[ 0, Cases[ rows, r_ /; Length @ r >= i && IntegerQ @ r[[ i ]] :> r[[ i ]] ] ], { i, { 3, 4 } } ]
|>;

rowsSource // endDefinition;


(* A "contents written" diff: its lines, unchanged, with new line numbers (see diffRows) *)
writeSource // beginDefinition;
writeSource[ lines_List ] := <| "Kind" -> "Write", "Lines" -> lines, "Count" -> Length @ lines, "MaxNumbers" -> { 0, Length @ lines } |>;
writeSource // endDefinition;


(* A line diff: the old and new line numbers of the ops (0 for none, as numberLineOps counts them) and the ops that
   collapseContext keeps ("Selected"), with those that become its ellipsis rows ("Ellipsis": 1) *)
opsSource // beginDefinition;

opsSource[ { } ] := rowsSource @ { };

opsSource[ ops_List ] := Module[ { n, types, oldQ, newQ, old, new, marks, keep, first, selected, ellipsis },
    n     = Length @ ops;
    types = ops[[ All, 1 ]];
    (* as numberLineOps: unchanged lines have both numbers, removed lines the old and added lines the new one *)
    oldQ  = Developer`ToPackedArray @ Lookup[ $oldLineMarks, types, 0 ];
    newQ  = Developer`ToPackedArray @ Lookup[ $newLineMarks, types, 0 ];
    old   = Accumulate @ oldQ * oldQ;
    new   = Accumulate @ newQ * newQ;
    marks = Developer`ToPackedArray @ Lookup[ $changeMarks, types, 0 ];
    If[ Total @ marks === 0 || Total @ marks === n,
        selected = Range @ n;
        ellipsis = ConstantArray[ 0, n ],
        keep     = Unitize @ ListCorrelate[ ConstantArray[ 1, 2 * $diffContextLines + 1 ], marks, { $diffContextLines + 1, $diffContextLines + 1 }, 0 ];
        first    = (1 - keep) * Prepend[ Most @ keep, 1 ];
        selected = Flatten @ SparseArray[ keep + first ][ "NonzeroPositions" ];
        ellipsis = first[[ selected ]]
    ];
    <|
        "Kind"       -> "Ops",
        "Ops"        -> ops,
        "Old"        -> old,
        "New"        -> new,
        "Selected"   -> selected,
        "Ellipsis"   -> ellipsis,
        "Count"      -> Length @ selected,
        (* the ellipsis rows have no numbers *)
        "MaxNumbers" -> { Max[ 0, old[[ selected ]] * (1 - ellipsis) ], Max[ 0, new[[ selected ]] * (1 - ellipsis) ] }
    |>
];

opsSource // endDefinition;

$oldLineMarks = <| "=" -> 1, "-" -> 1 |>;
$newLineMarks = <| "=" -> 1, "+" -> 1 |>;


acpDiffSourceRows // beginDefinition;

acpDiffSourceRows[ source_Association, { a_Integer, b_Integer } ] /; b < a := { };

acpDiffSourceRows[ KeyValuePattern[ "Rows" -> rows_List ], { a_Integer, b_Integer } ] := rows[[ a ;; b ]];

acpDiffSourceRows[ KeyValuePattern @ { "Kind" -> "Write", "Lines" -> lines_List }, { a_Integer, b_Integer } ] :=
    MapThread[ { "=", #1, None, #2 } &, { lines[[ a ;; b ]], Range[ a, b ] } ];

acpDiffSourceRows[ source: KeyValuePattern[ "Kind" -> "Ops" ], { a_Integer, b_Integer } ] := Module[ { selected, ops, rows, ellipses },
    selected = source[ "Selected" ][[ a ;; b ]];
    ops      = source[ "Ops" ][[ selected ]];
    rows     = Transpose @ {
        ops[[ All, 1 ]],
        ops[[ All, 2 ]],
        Replace[ source[ "Old" ][[ selected ]], 0 -> None, { 1 } ],
        Replace[ source[ "New" ][[ selected ]], 0 -> None, { 1 } ]
    };
    (* the ellipsis rows of collapseContext have no line numbers: *)
    ellipses = Flatten @ Position[ source[ "Ellipsis" ][[ a ;; b ]], 1, { 1 }, Heads -> False ];
    If[ ellipses =!= { }, rows[[ ellipses ]] = ConstantArray[ { "@", "\:22ef", None, None }, Length @ ellipses ] ];
    rows
];

acpDiffSourceRows // endDefinition;


acpDiffSourceLineLengths // beginDefinition;

acpDiffSourceLineLengths[ source_Association, { a_Integer, b_Integer } ] /; b < a := { };

acpDiffSourceLineLengths[ KeyValuePattern[ "Rows" -> rows_List ], { a_Integer, b_Integer } ] :=
    StringLength @ Replace[ rows[[ a ;; b, 2 ]], Except[ _String ] -> "", { 1 } ];

acpDiffSourceLineLengths[ KeyValuePattern @ { "Kind" -> "Write", "Lines" -> lines_List }, { a_Integer, b_Integer } ] :=
    StringLength @ lines[[ a ;; b ]];

acpDiffSourceLineLengths[ source: KeyValuePattern[ "Kind" -> "Ops" ], { a_Integer, b_Integer } ] := Module[ { selected, lengths },
    selected = source[ "Selected" ][[ a ;; b ]];
    lengths  = StringLength @ source[ "Ops" ][[ selected, 2 ]];
    (* an ellipsis row's line is one character *)
    lengths + source[ "Ellipsis" ][[ a ;; b ]] * (1 - lengths)
];

acpDiffSourceLineLengths // endDefinition;


(* Line numbers for a line diff: unchanged lines have both, removed lines the old and added lines the new one *)
numberLineOps // beginDefinition;

numberLineOps[ { } ] := { };

(* Counted with Accumulate: a large diff (a new file of 20,000 lines) is numbered in milliseconds *)
numberLineOps[ ops_List ] := Module[ { types, oldQ, newQ },
    types = ops[[ All, 1 ]];
    oldQ  = Boole @ StringMatchQ[ types, "=" | "-" ];
    newQ  = Boole @ StringMatchQ[ types, "=" | "+" ];
    Transpose @ {
        types,
        ops[[ All, 2 ]],
        MapThread[ If[ #1 === 1, #2, None ] &, { oldQ, Accumulate @ oldQ } ],
        MapThread[ If[ #1 === 1, #2, None ] &, { newQ, Accumulate @ newQ } ]
    }
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


(* Keeps `context` unchanged lines around each change; longer unchanged runs become an ellipsis row. Linear in the number
   of rows, with packed arrays: a row is kept if a change is at most `context` rows away (a moving sum of the changes),
   and the first row of each run that is not kept becomes the ellipsis row. A diff with only changes (e.g. a new file)
   is kept whole. *)
collapseContext // beginDefinition;

collapseContext[ ops_List, context_Integer ] := Module[ { n, marks, keep, first, selected, rows, ellipses },
    n     = Length @ ops;
    marks = Developer`ToPackedArray @ Lookup[ $changeMarks, ops[[ All, 1 ]], 0 ];
    If[ Total @ marks === 0 || Total @ marks === n, Return[ ops, Module ] ];
    keep     = Unitize @ ListCorrelate[ ConstantArray[ 1, 2 * context + 1 ], marks, { context + 1, context + 1 }, 0 ];
    first    = (1 - keep) * Prepend[ Most @ keep, 1 ];
    selected = Flatten @ SparseArray[ keep + first ][ "NonzeroPositions" ];
    rows     = ops[[ selected ]];
    ellipses = Flatten @ Position[ first[[ selected ]], 1, { 1 }, Heads -> False ];
    (* the ellipsis row has no line numbers: *)
    rows[[ ellipses ]] = PadRight[ { "@", "\:22ef" }, Length @ #, None ] & /@ rows[[ ellipses ]];
    rows
];

collapseContext // endDefinition;

$changeMarks = <| "+" -> 1, "-" -> 1 |>;


(* The diff lines. With full width, the line column takes the rest of the available width (so the line backgrounds
   span it, and long lines wrap at its edge). numbers: the positions of the line numbers in the rows that get a column
   (narrow and right-aligned, in front of the lines). *)
diffGrid // beginDefinition;

diffGrid[ rows: { { _, _ }... }, False, _ ] := Grid[
    diffRowItems /@ rows,
    Alignment  -> { Left, Baseline },
    Spacings   -> { 0.4, 0.1 },
    Background -> diffRowBackgrounds @ rows,
    (* code is drawn as typed: "-" is a hyphen (not a long minus), "*" a star, "->" two characters (OperatorSubstitution) *)
    BaseStyle  -> { FontFamily -> $codeFont, FontSize -> 12, LineBreakWithin -> Automatic, PrivateFontOptions -> { "OperatorSubstitution" -> False } }
];

diffGrid[ rows_List, full_, numbers_List ] := With[ { n = Length @ numbers },
    Grid[
        Join[ lineNumberItem /@ #[[ numbers ]], diffRowItems @ #[[ ;; 2 ]] ] & /@ rows,
        Alignment  -> { Join[ ConstantArray[ Right, n ], { Left, Left } ], Baseline },
        Spacings   -> { Join[ { 0.4 }, ConstantArray[ 0.7, n ], { 0.4, 0.4 } ], 0.1 },
        ItemSize   -> If[ TrueQ @ full, { Append[ ConstantArray[ Automatic, n + 1 ], Fit ], Automatic }, Automatic ],
        Background -> diffRowBackgrounds @ rows,
        (* code is drawn as typed: "-" is a hyphen (not a long minus), "*" a star, "->" two characters (OperatorSubstitution) *)
        BaseStyle  -> { FontFamily -> $codeFont, FontSize -> 12, LineBreakWithin -> Automatic, PrivateFontOptions -> { "OperatorSubstitution" -> False } }
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
diffRowItems[ { "@", l_ } ] := { "", Style[ diffLineText @ l, FontColor -> $mutedColor ] }; (* a hunk header is a patch's text too *)
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


(* Lines are display-safe like the review window's (acpReviewSafeLines: the bidi controls and line separators shown as
   markers, a line cut before a marker that would not fit), so that a line can't look different from what it is, in the
   permission panel ($safeDiffLines) where it is approved too *)
diffLineText // beginDefinition;
diffLineText[ "" ] := Style[ " ", ShowStringCharacters -> False ];
diffLineText[ l_String ] := Style[ First @ acpReviewSafeLines[ { l }, $maxLineLength ], ShowStringCharacters -> False ];
diffLineText // endDefinition;

$safeDiffLines = False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Other Entities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*permissionEntityCell*)

(* A permission request that doesn't belong to a tool call (e.g. access outside the project directory). The buttons are
   in the permission panel; this card only shows a passive badge. *)
permissionEntityCell // beginDefinition;

permissionEntityCell[ perm_Association, turn_ ] := Module[ { badgeSpec, title, badgeView },
    badgeSpec = Switch[ perm[ "Outcome" ],
        None       , { acpLabel[ "BadgeAwaitingApproval" ], "Amber" },
        "once"     , { acpLabel[ "BadgeAllowedOnce" ], "Neutral" },
        "always"   , { acpLabel[ "BadgeAllowedAlways" ], "Neutral" },
        "reject"   , { acpLabel[ "BadgeDeclined" ], "Neutral" },
        "cancelled", { acpLabel[ "BadgeCancelled" ], "Neutral" },
        _          , None
    ];
    { title, badgeView } = headerTitleAndBadge[ acpToolTitleParts[ perm, Automatic, turn ], "Permission", "", badgeSpec, Nothing ];
    boxCell @ Framed[
        Grid[
            {
                Flatten @ {
                    iconPane @ chatbookIcon[ "WrenchIcon", False ],
                    Style[ title, FontColor -> $toolLabelColor ],
                    Replace[ badgeView, None -> Nothing ]
                }
            },
            $headerGridOptions
        ],
        cardFrameOptions @ If[ perm[ "Outcome" ] === None, "Awaiting", "Default" ]
    ]
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
    {
        $renderMode              = "Final",
        $cardContext             = "Tail",
        $turnID                  = Lookup[ turn, "ID", None ],
        $replayedTurn            = TrueQ @ Lookup[ turn, "Replayed", False ],
        $acpNoFrontEndFormatting = TrueQ @ noFE || $acpNoFrontEndFormatting
    },
    Module[ { split, entities, items, work, status, answer },
        split    = acpTurnSplit @ turn;
        entities = turn[ "Entities" ];
        items    = { };

        (* Work (a replayed turn's thoughts without text are left out: OpenCode replays an empty reasoning part that
           the live turn did not show, which would be a "Thoughts" label with nothing in it) *)
        work = If[ TrueQ @ $replayedTurn, Select[ split[ "Work" ], ! emptyThoughtQ @ entities[ # ] & ], split[ "Work" ] ];
        If[ work =!= { },
            items = Join[ items, workItems[ turn, work ] ]
        ];

        (* Last step of an interrupted turn, expanded (its diffs as short as in live cards, see changesSection): *)
        Do[
            items = Join[ items, { Block[ { $expandedFinalCard = True }, finalEntityCell[ entities[ key ], key, turn, True ] ], "\n" } ],
            { key, split[ "Tail" ] }
        ];

        (* Answer *)
        answer = StringRiffle[ DeleteCases[ StringTrim[ entities[ #, "Text" ] ] & /@ split[ "Answer" ], "" ], "\n\n" ];
        If[ answer =!= "", items = Join[ items, finishedItems @ answer, { "\n" } ] ];
        items = Join[ items, Flatten[ blockItems[ entities[ #, "Blocks" ], turnRemote @ turn ] & /@ split[ "Answer" ] ] ];

        (* Status line or error *)
        status = If[ turn[ "Error" ] === None, acpTurnStatusLine @ turn, None ];
        Which[
            AssociationQ @ turn[ "Error" ],
                items = Join[ items, { boxCell @ acpErrorView[ turn[ "Error" ], Lookup[ turn, "Notebook", None ] ] } ],
            StringQ @ status,
                items = Join[ items, { boxCell @ statusLineView[ turn, status ] } ],
            answer === "" && split[ "Tail" ] === { },
                items = Join[
                    items,
                    {
                        boxCell @ Style[
                            (* a replayed turn without any output was cancelled (or its output was compacted) *)
                            acpLabel @ If[ TrueQ @ $replayedTurn && turn[ "Order" ] === { }, "ReplayNoReply", "DoneNoReply" ],
                            FontColor -> $mutedColor,
                            FontSlant -> Italic
                        ]
                    }
                ]
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


emptyThoughtQ // beginDefinition;
emptyThoughtQ[ KeyValuePattern @ { "Type" -> "Thought", "Text" -> text_ } ] := ! StringQ @ text || StringTrim @ text === "";
emptyThoughtQ[ _ ] := False;
emptyThoughtQ // endDefinition;


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

workedForOpenerCell[ turn_Association, keys_List ] := Block[ { $cardContext = "Work" }, workedForOpenerCell0[ turn, keys ] ];

workedForOpenerCell // endDefinition;


workedForOpenerCell0 // beginDefinition;

workedForOpenerCell0[ turn_Association, keys_List ] := Module[ { entities, seen = { }, content = { }, child },
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
        BoxData @ workOpenerBoxes[
            Cell[
                TextData @ trimItems @ content,
                "Text",
                FontColor  -> $workContentFontColor,
                FontSize   -> $workContentFontSize,
                Background -> None
            ],
            workedForLabelBoxes @ turn
        ],
        "ThoughtsOpener",
        Background   -> None,
        TaggingRules -> <|
            "ACPWork" -> <| "Duration" -> Replace[ Lookup[ turn, "EndTime" ], Except[ _? NumberQ ] -> AbsoluteTime[ ] ] - turn[ "StartTime" ] |>
        |>
    ]
];

workedForOpenerCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*workOpenerBoxes*)

(* The "Worked for" opener of the final cell: the boxes of Chatbook's ThoughtsOpener template (the closed and the open
   view in a PaneSelector, the header's italic label and chevron that darken on hover, the content in the
   ThinkingContent template's pane, the "Hide" footer), but front-end-only, like the tool cards (staticOpener): a click
   toggles the DynamicModule variable (its own name: the cards inside have theirs) with the front end's own functions
   (FEPrivate`Set / FEPrivate`If), the "Hide"
   label is a DynamicBox of a front end resource (not one of ToBoxes, which the template's needs the kernel for), the
   content pane is built-in boxes (not the ThinkingContent template), and DynamicModuleValues :> { } (the template's
   Automatic needs the kernel). The template version made a pasted copy wait for a kernel, and with many tool cards in
   its open view, a paste into a notebook without a kernel never finished (see docs/acp-window.md, "Copies and
   pastes"). inner: the content cell; label: the label's boxes. *)
workOpenerBoxes // beginDefinition;

workOpenerBoxes[ inner_Cell, label_ ] := With[
    {
        closed = workOpenerGrid @ { { workOpenerToggle @ workOpenerLabel[ label, "\:f442", "\:f43b" ] } },
        open   = workOpenerGrid @ {
            { workOpenerToggle @ workOpenerLabel[ label, "\:f443", "\:f449" ] },
            { workOpenerContent @ inner },
            { workOpenerToggle @ workOpenerHide[ ] }
        }
    },
    (* DynamicModuleBox holds its arguments: the boxes are made first *)
    DynamicModuleBox[
        { Typeset`workOpen$$ = False },
        StyleBox[
            PaneSelectorBox[
                { False -> closed, True -> open },
                Dynamic @ Typeset`workOpen$$,
                Alignment        -> Automatic,
                ImageSize        -> Automatic,
                ImageMargins     -> { { 0, 0 }, { 10, 10 } },
                BaseStyle        -> { },
                DefaultBaseStyle -> "OpenerView",
                BaselinePosition -> Baseline
            ],
            Deployed     -> False,
            StripOnInput -> False
        ],
        DynamicModuleValues :> { }
    ]
];

workOpenerBoxes // endDefinition;


workOpenerGrid // beginDefinition;

workOpenerGrid[ rows_List ] := GridBox[
    rows,
    GridBoxAlignment  -> { "Columns" -> { { Left } } },
    AutoDelete        -> False,
    GridBoxBackground -> { "Columns" -> { { Automatic } } },
    GridBoxItemSize   -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
    GridBoxSpacings   -> { "Columns" -> { { 0.2 } }, "Rows" -> { { 0.5 } } },
    BaselinePosition  -> { 1, 1 }
];

workOpenerGrid // endDefinition;


(* The header or footer line, darker under the pointer, which toggles the opener when clicked *)
workOpenerToggle // beginDefinition;

workOpenerToggle[ { normal_, hover_ } ] := TagBox[
    TagBox[
        PaneSelectorBox[
            { False -> normal, True -> hover },
            Dynamic @ CurrentValue[ "MouseOver" ],
            BaseStyle    -> { FontColor -> $labelColor, FontFamily -> "Source Sans Pro", FontSize -> 13.5, ShowStringCharacters -> False },
            ImageSize    -> Automatic,
            FrameMargins -> 0
        ],
        MouseAppearanceTag[ "Arrow" ]
    ],
    EventHandlerTag @ {
        "MouseClicked"  :> FEPrivate`Set[ Typeset`workOpen$$, FEPrivate`If[ Typeset`workOpen$$, False, True ] ],
        Method          -> "Preemptive",
        PassEventsDown  -> Automatic,
        PassEventsUp    -> True
    }
];

workOpenerToggle // endDefinition;


(* { normal, hover } views of a line of the opener: *)
workOpenerLabel // beginDefinition;

workOpenerLabel[ label_, chevron_String, hoverChevron_String ] := {
    GridBox[ { { StyleBox[ label, FontSlant -> "Italic" ], chevron } }, $workOpenerItemSize ],
    GridBox[ { { StyleBox[ label, FontSlant -> "Italic" ], hoverChevron } }, $workOpenerItemSize, BaseStyle -> { FontColor -> $labelHoverColor } ]
};

workOpenerLabel // endDefinition;


workOpenerHide // beginDefinition;

workOpenerHide[ ] := With[
    { hide = StyleBox[ DynamicBox @ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingHide" ], FontSlant -> "Italic" ] },
    {
        GridBox[ { { AdjustmentBox[ RotationBox[ "\:f443", BoxRotation -> 3.14159 ], BoxBaselineShift -> -0.2 ], hide } }, $workOpenerItemSize ],
        GridBox[
            { { AdjustmentBox[ RotationBox[ "\:f449", BoxRotation -> 3.14159 ], BoxBaselineShift -> -0.2 ], hide } },
            $workOpenerItemSize,
            BaseStyle -> { FontColor -> $labelHoverColor }
        ]
    }
];

workOpenerHide // endDefinition;


$workOpenerItemSize = GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } };


(* The content, as the ThinkingContent template shows it (a background and a divider at the left) *)
workOpenerContent // beginDefinition;

workOpenerContent[ inner_Cell ] := PaneBox[
    Cell[
        BoxData @ GridBox[
            {
                {
                    PaneBox[
                        Cell[ TextData @ { inner }, "Text", FontColor -> color @ "ThinkingContentFont", FontSize -> 12, Background -> None, Editable -> True ],
                        Alignment    -> Left,
                        ImageMargins -> { { 5, 5 }, { 5, 5 } },
                        ImageSize    -> { Scaled[ 1 ], Automatic }
                    ]
                }
            },
            AutoDelete        -> False,
            GridBoxBackground -> { "Columns" -> { { color @ "ThinkingContentBackground" } } },
            GridBoxItemSize   -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
            GridBoxDividers   -> {
                "ColumnsIndexed" -> { 1 -> Directive[ color @ "ThinkingContentDivider", AbsoluteThickness[ 2 ] ] },
                "Rows"           -> { { False } }
            }
        ],
        Background -> None
    ],
    Alignment    -> Left,
    ImageMargins -> { { 5, 0 }, { 0, 0 } }
];

workOpenerContent // endDefinition;


(* The label of the "Worked for" opener, with the time spent waiting for approval in a tooltip (acpWorkedForTooltip;
   the label is just the string otherwise). The ThoughtsOpener template shows the label in both panes of its hover
   PaneSelector (pointer outside or over the label), so both panes have the tooltip, whichever of them is shown.
   Wrapping the whole opener in a Tooltip instead would also show it over the opened content. A TooltipBox is a
   built-in box: copied or saved cells still render anywhere. *)
workedForLabelBoxes // beginDefinition;

workedForLabelBoxes[ turn_Association ] := With[ { now = AbsoluteTime[ ] },
    With[ { label = acpWorkedForLabel[ turn, now ], tooltip = acpWorkedForTooltip[ turn, now ] },
        ToBoxes @ If[ StringQ @ tooltip, Tooltip[ label, tooltip ], label ]
    ]
];

workedForLabelBoxes // endDefinition;


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


(* The status line ("You declined: run `rm -rf build`. Tell OpenCode what to do instead.") as an inline text cell: its
   lines break between words, as in a paragraph. As boxes (a row of the text and the code spans, titleView), the front
   end broke the line between the code span and the punctuation after it (a line starting with ". Tell ..."), also with
   a word joiner. Code spans are upright in the code font (titleSpans), the text is display-safe (acpSafeText), string
   characters are hidden and operators drawn as typed. It is the same view in every place: a built-in cell. *)
statusLineView // beginDefinition;
statusLineView[ turn_Association, status_String ] := RawBoxes @ Cell[
    TextData @ Replace[ titleSpans @ status, { s_String, o_List } :> If[ o === { }, s, StyleBox[ s, Sequence @@ o ] ], { 1 } ],
    "Text",
    FontColor            -> If[ turn[ "ClientCancel" ] === None && turn[ "StopReason" ] =!= "cancelled", $amberText, $mutedColor ],
    FontSlant            -> Italic,
    ShowStringCharacters -> False,
    PrivateFontOptions   -> { "OperatorSubstitution" -> False },
    Background           -> None
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


(* Small summary of the turn kept in the final cell's TaggingRules (no tool output). Most of it is the agent's text
   (stop reason, error, tool names and titles): every string in it is neutralized (see acpNeutralizeLinearSyntax). *)
compactTurnData // beginDefinition;

compactTurnData[ turn_Association ] := neutralizeLinearSyntax @ <|
    "Version"      -> 1,
    "ID"           -> Lookup[ turn, "ID", None ],
    "SessionID"    -> Lookup[ turn, "SessionID", None ],
    If[ TrueQ @ Lookup[ turn, "Replayed", False ], "Replayed" -> True, Nothing ],
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
(* The remote home folder is part of it: "Always allow" texts of a remote window resolve ~ with it. So are the titles of
   the notebooks that the request names, which the pump adds after the request arrived (the panel is shown again with
   them, and its buttons wait again before they accept clicks), and the time the request arrived: JSON-RPC ids repeat
   after a reconnect, so another request with the id of the one shown is shown too. *)
permissionSignature[ nbo_NotebookObject ] := Replace[
    acpIsolated @ Module[ { window, pending },
        window  = Replace[ acpWindowGet @ nbo, Except[ _Association ] -> <| |> ];
        pending = Lookup[ window, "PendingPermissions", <| |> ];
        If[ AssociationQ @ pending && Length @ pending > 0,
            {
                First @ Keys @ pending,
                Length @ pending,
                Lookup[ window, "ProjectDirectory", None ],
                acpWindowRemoteHome @ window,
                Lookup[ Replace[ First @ pending, Except[ _Association ] -> <| |> ], "ArrivedAt", None ],
                Lookup[ Replace[ First @ pending, Except[ _Association ] -> <| |> ], "NotebookTitles", None ]
            },
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
    { params, toolCall, tool, agent, project, paths, titles, headline, preview, full, options, armAt, scope, buttons },

    params   = Replace[ Lookup[ info, "Params", <| |> ], Except[ _Association ] -> <| |> ];
    toolCall = Replace[ Lookup[ params, "toolCall", <| |> ], Except[ _Association ] -> <| |> ];
    tool     = permissionTool[ info, toolCall ];
    agent    = windowAgentName @ window;
    project  = Replace[ Lookup[ window, "ProjectDirectory", None ], Except[ _String ] -> "" ];
    (* how paths are resolved: on this computer, or on a remote window's host (POSIX paths, ~ is the remote home) *)
    paths    = acpPathContext @ window;
    (* the window titles of the notebooks that the request names, resolved by the pump (see acpNotebookTitles) *)
    titles   = Replace[ Lookup[ info, "NotebookTitles", <| |> ], Except[ _Association ] -> <| |> ];
    (* the labels contain the project folder and paths, which can come from the agent: neutralized *)
    headline = acpSafeText @ permissionHeadline[ tool, toolCall, agent, project ];
    preview  = permissionPreview[ tool, project, titles ];
    (* what a "View full ..." link opens in the permission details window (PermissionDetails.wl), if the preview leaves
       part of it out *)
    full     = permissionFullKind @ tool;
    options  = Replace[ Lookup[ params, "options", { } ], Except[ _List ] -> { } ];
    armAt    = AbsoluteTime[ ] + $permissionArmDelay;
    (* once per card: the text below the buttons and the tooltip of "Always allow" *)
    scope    = If[ MemberQ[ options, KeyValuePattern[ "kind" -> "allow_always" ] ], acpSafeText @ alwaysScopeText[ tool, agent, project, paths ], None ];
    buttons  = permissionButton[ nbo, reqID, #, armAt, scope ] & /@ options;

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
                    If[ StringQ @ full, permissionViewLink[ nbo, acpPermissionKey[ reqID, info ], full ], None ],
                    Row[ buttons, Spacer[ 6 ] ],
                    If[ StringQ @ scope, Style[ scope, FontSize -> 11, FontColor -> $mutedColor, PrivateFontOptions -> { "OperatorSubstitution" -> False } ], None ]
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


(* A key for one pending request (an entry of the window's "PendingPermissions"), for button code: a hash, never the
   agent's text. JSON-RPC ids are counters of a connection that repeat after a reconnect, so the key is made from the
   request's turn, id, arrival time and tool call. *)
acpPermissionKey // beginDefinition;

acpPermissionKey[ reqID_, info_Association ] := IntegerString[
    Hash[
        {
            reqID,
            Lookup[ info, "TurnID", None ],
            Lookup[ info, "ArrivedAt", None ],
            Lookup[ Replace[ Lookup[ Replace[ Lookup[ info, "Params", <| |> ], Except[ _Association ] -> <| |> ], "toolCall", <| |> ], Except[ _Association ] -> <| |> ], "toolCallId", None ]
        },
        "SHA256"
    ],
    36
];

acpPermissionKey // endDefinition;


(* The "View full diff" (command, script) link below the preview: opens the request in the permission details window
   (ChatbookAction[ "ACP", "PermissionDetails", nbo, key ], PermissionDetails.wl) *)
permissionViewLink // beginDefinition;

permissionViewLink[ nbo_, key_String, kind_String ] := With[ { label = acpLabel[ "PermissionViewFull" <> kind ] },
    Tooltip[
        acpActionButton[
            MouseAppearance[
                Mouseover[
                    Style[ label, FontColor -> $toolLabelColor, FontSize -> 12 ],
                    Style[ label, FontColor -> $toolLabelColor, FontSize -> 12, FontVariations -> { "Underline" -> True } ]
                ],
                "LinkHand"
            ],
            { "PermissionDetails", nbo, key },
            BaseStyle -> { "Text", FontSize -> 12 },
            BoxID     -> "ACPPermissionDetails"
        ],
        acpLabel[ "PermissionViewFullTooltip" ]
    ]
];

permissionViewLink // endDefinition;


(* What the preview of a request leaves out (see permissionPreview0, in the same order): "Script", "Command", "Diff" or
   None *)
permissionFullKind // beginDefinition;

permissionFullKind[ tool_Association ] := Module[ { input, command, diffs },
    input   = Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ];
    command = SelectFirst[ Lookup[ input, { "command", "cmd" }, None ], StringQ, None ];
    diffs   = Replace[ tool[ "Diffs" ], Except[ _List ] -> { } ];
    Which[
        tool[ "Name" ] === "execute",
            Replace[
                SelectFirst[ Lookup[ input, { "code", "script" }, None ], StringQ, None ],
                { s_String /; headCutQ[ StringTrim @ s, $permissionScriptLines, $permissionScriptLength ] -> "Script", _ -> None }
            ],
        StringQ @ acpNotebookToolName @ tool[ "RawName" ],
            None,
        StringQ @ command,
            If[ headCutQ[ command, $permissionCommandLines, $permissionCommandLength ], "Command", None ],
        diffs =!= { },
            If[ Length @ diffs > $permissionDiffFiles || AnyTrue[ Take[ diffs, UpTo[ $permissionDiffFiles ] ], diffCutQ ], "Diff", None ],
        True,
            None
    ]
];

permissionFullKind // endDefinition;


(* Whether the panel's preview of a diff leaves out rows, or cuts a row *)
diffCutQ // beginDefinition;

diffCutQ[ diff_Association ] := With[ { rows = acpDiffRows[ diff, False ] },
    Length @ rows > $permissionDiffLines || AnyTrue[ Take[ rows, UpTo[ $permissionDiffLines ] ], StringLength @ #[[ 2 ]] > $permissionLineLength & ]
];

diffCutQ[ _ ] := False;

diffCutQ // endDefinition;


(* What the permission details window (PermissionDetails.wl) shows for a pending request: <| "Kind" -> "Diff" | "Command"
   | "Script" | None, "Headline" (neutralized), "Agent", "Remote" (paths are on the window's host), "Files" -> { <| "Path"
   (relative to the project folder), "Diff" (normalized), "Badge" -> "NewFile" | "ContentsWritten" | None |>... } (for
   diffs), "Text" (the command or the script) |>. Pure, apart from the turn store; no line diff is computed here. *)
acpPermissionDetailsData // beginDefinition;

acpPermissionDetailsData[ window_Association, _, info_Association ] := Module[
    { params, toolCall, tool, agent, project, input, kind },
    params   = Replace[ Lookup[ info, "Params", <| |> ], Except[ _Association ] -> <| |> ];
    toolCall = Replace[ Lookup[ params, "toolCall", <| |> ], Except[ _Association ] -> <| |> ];
    tool     = permissionTool[ info, toolCall ];
    agent    = windowAgentName @ window;
    project  = Replace[ Lookup[ window, "ProjectDirectory", None ], Except[ _String ] -> "" ];
    input    = Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ];
    kind     = Which[
        tool[ "Name" ] === "execute", If[ StringQ @ SelectFirst[ Lookup[ input, { "code", "script" }, None ], StringQ, None ], "Script", None ],
        StringQ @ acpNotebookToolName @ tool[ "RawName" ], None,
        StringQ @ SelectFirst[ Lookup[ input, { "command", "cmd" }, None ], StringQ, None ], "Command",
        MatchQ[ tool[ "Diffs" ], { __ } ], "Diff",
        True, None
    ];
    <|
        "Kind"     -> kind,
        "Headline" -> acpSafeText @ permissionHeadline[ tool, toolCall, agent, project ],
        "Agent"    -> agent,
        "Remote"   -> TrueQ @ acpRemoteQ @ window,
        "Files"    -> If[ kind === "Diff", permissionDetailsFile[ #, project ] & /@ tool[ "Diffs" ], { } ],
        "Text"     -> Switch[ kind,
            "Script" , StringTrim @ SelectFirst[ Lookup[ input, { "code", "script" }, None ], StringQ ],
            "Command", SelectFirst[ Lookup[ input, { "command", "cmd" }, None ], StringQ ],
            _        , None
        ]
    |>
];

acpPermissionDetailsData // endDefinition;


permissionDetailsFile // beginDefinition;

permissionDetailsFile[ diff0_Association, project_ ] := With[ { diff = normalDiff @ diff0 },
    <|
        "Path"  -> relativePath[ Replace[ diff[ "Path" ], Except[ _String ] -> "" ], project ],
        "Diff"  -> diff,
        "Badge" -> Which[
            TrueQ @ diff[ "Write" ], "ContentsWritten",
            diff[ "OldText" ] === None && StringQ @ diff[ "NewText" ] && ! StringQ @ diff[ "Patch" ], "NewFile",
            True, None
        ]
    |>
];

permissionDetailsFile // endDefinition;


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
        name === "execute",
            scriptHeadline[ tool, agent ],
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


(* A script (code mode): OpenCode's request names neither the tool it asks about nor its input, only "execute" and the
   script. The headline names every tool that the script names (anywhere, so that a decoy can't take the place of a real
   call; the edits of open notebooks first), "and other tools" unless these are surely all (scriptToolsShownQ), and
   none if it names none. *)
scriptHeadline // beginDefinition;

scriptHeadline[ tool_Association, agent_ ] := Module[ { references, tools, shown },
    references = acpExecuteToolReferences @ tool;
    tools      = editToolsFirst @ references[ "Tools" ];
    shown      = Take[ tools, UpTo[ $permissionHeadlineTools ] ];
    Which[
        tools === { },
            acpLabel[ "PermissionScript", <| "agent" -> agent |> ],
        scriptToolsShownQ[ references, shown ],
            acpLabel[ "PermissionScriptTools", <| "agent" -> agent, "tools" -> scriptToolList @ shown |> ],
        True,
            acpLabel[ "PermissionScriptToolsMore", <| "agent" -> agent, "tools" -> scriptToolList @ shown |> ]
    ]
];

scriptHeadline // endDefinition;


(* Whether the tools shown for a script's permission request are surely all that the request can be about: the
   script's references are complete (acpExecuteScript), all its tools are shown, and one of them changes open notebooks.
   Chatbook's permission rules make OpenCode ask about those tools, so if the script names none, it reaches the tool
   that the request is about in a way that can't be read (or the request is about a rule of the user's own). *)
scriptToolsShownQ // beginDefinition;

scriptToolsShownQ[ references_Association, shown_List ] := And[
    TrueQ @ references[ "Complete" ],
    Length @ shown === Length @ references[ "Tools" ],
    AnyTrue[ shown, notebookEditToolQ ]
];

scriptToolsShownQ // endDefinition;


(* Tools ("Server.Tool") with the notebook tools that change open notebooks first (Chatbook's permission rules make
   OpenCode ask for them, so the request is most likely for one of them), otherwise in their order *)
editToolsFirst // beginDefinition;
editToolsFirst[ tools_List ] := Join[ Select[ tools, notebookEditToolQ ], Select[ tools, ! notebookEditToolQ @ # & ] ];
editToolsFirst // endDefinition;


notebookEditToolQ // beginDefinition;
notebookEditToolQ[ name_String ] := MemberQ[ $acpNotebookEditTools, acpNotebookToolName @ name ];
notebookEditToolQ[ _ ] := False;
notebookEditToolQ // endDefinition;


scriptToolList // beginDefinition;
scriptToolList[ tools_List ] := StringRiffle[ shortenText[ acpMCPDisplayName @ #, 60 ] & /@ tools, ", " ];
scriptToolList // endDefinition;


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

(* titles: the window titles of the notebooks that the request names (see permissionCard) *)
permissionPreview[ tool_Association, project_ ] := permissionPreview[ tool, project, <| |> ];

permissionPreview[ tool_Association, project_, titles_Association ] := Block[
    { $plainCodeBlocks = True, $renderMode = "Final", $argumentLines = $permissionArgumentLines },
    permissionPreview0[ tool, project, titles ]
];

permissionPreview // endDefinition;


permissionPreview0 // beginDefinition;

(* A script and a call of the notebook tools come first: their input may have a "command" too, which is not what runs *)
permissionPreview0[ tool_Association, project_, titles_Association ] := Module[ { name, input, command, diffs, arguments },
    name      = tool[ "Name" ];
    input     = Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ];
    command   = SelectFirst[ Lookup[ input, { "command", "cmd" }, None ], StringQ, None ];
    diffs     = Replace[ tool[ "Diffs" ], Except[ _List ] -> { } ];
    arguments = If[ StringQ @ acpNotebookToolName @ tool[ "RawName" ], argumentsView[ input, False, $notebookToolParameters, titles ], None ];
    Which[
        name === "execute",
            scriptPreview[ tool, titles ],
        arguments =!= None,
            arguments,
        StringQ @ command,
            RawBoxes @ codeBlock[ previewHeadText[ command, $permissionCommandLines, $permissionCommandLength ], "text" ],
        diffs =!= { },
            permissionDiffPreview[ diffs, project ],
        Length @ input > 0,
            rawInputGrid @ input,
        True,
            None
    ]
];

permissionPreview0 // endDefinition;


(* The diffs of a request: the first $permissionDiffLines rows of each of the first $permissionDiffFiles files (the
   first change with its context), rows cut to $permissionLineLength characters and display-safe, and a note of the
   other files. The panel's link opens all of it (PermissionDetails.wl). *)
permissionDiffPreview // beginDefinition;

permissionDiffPreview[ diffs_List, project_ ] := Module[ { shown, more },
    shown = Take[ diffs, UpTo[ $permissionDiffFiles ] ];
    more  = Length @ diffs - Length @ shown;
    Block[ { $maxLineLength = $permissionLineLength, $safeDiffLines = True },
        Column[
            Flatten @ {
                acpDiffView[ #, <| "MaxLines" -> $permissionDiffLines, "ProjectDirectory" -> project |> ] & /@ shown,
                If[ more > 0,
                    Style[ If[ more === 1, acpLabel[ "PermissionMoreFilesOne" ], acpLabel[ "PermissionMoreFiles", <| "n" -> more |> ] ], FontColor -> $mutedColor, FontSize -> 11 ],
                    Nothing
                ]
            },
            Spacings -> 0.5
        ]
    ]
];

permissionDiffPreview // endDefinition;


(* A script (code mode): the tool references that it shows (edits of open notebooks first; see acpExecuteScript), and
   always the script itself, as plain text (it is the agent's), below them: the request names neither the tool it asks
   about nor its input, so what the user approves is the script *)
scriptPreview // beginDefinition;

scriptPreview[ tool_Association, titles_Association ] := Module[ { input, calls, shown, script },
    input  = Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ];
    calls  = acpExecuteToolCalls @ tool;
    calls  = Join[ Select[ calls, notebookEditToolQ @ #[ "Tool" ] & ], Select[ calls, ! notebookEditToolQ @ #[ "Tool" ] & ] ];
    shown  = Take[ calls, UpTo[ $permissionCallLimit ] ];
    script = SelectFirst[ Lookup[ input, { "code", "script" }, None ], StringQ, None ];
    If[ ! StringQ @ script,
        Return[ If[ Length @ input > 0, rawInputGrid @ input, None ], Module ]
    ];
    Column[
        Flatten @ {
            executeCallView[ #, titles ] & /@ shown,
            If[ Length @ calls > Length @ shown,
                Style[ acpLabel[ "PermissionMoreToolReferences", <| "n" -> Length @ calls - Length @ shown |> ], FontColor -> $mutedColor, FontSize -> 11 ],
                Nothing
            ],
            section[ "SectionScript", RawBoxes @ plainCodeBoxes @ scriptPreviewText @ StringTrim @ script ]
        },
        Spacings -> 0.6
    ]
];

scriptPreview // endDefinition;


(* The script in the permission panel: its first $permissionScriptLines lines, wrapped and not cut (the end of a long
   line can hold a call), and of those at most $permissionScriptLength characters, with a note of the rest. The
   panel's "View full script" link shows all of it. *)
scriptPreviewText // beginDefinition;
scriptPreviewText[ script_String ] := previewHeadText[ script, $permissionScriptLines, $permissionScriptLength ];
scriptPreviewText // endDefinition;


(* The first n lines of a text (a script, a shell command) and of those at most chars characters, with a note of the
   rest: lines are wrapped, not cut at a width, but a text longer than chars characters ends there (also in a line) *)
previewHeadText // beginDefinition;

previewHeadText[ text0_String, n_Integer, chars_Integer ] := Module[ { lines, text },
    lines = StringSplit[ text0, "\n", All ];
    text  = StringRiffle[ Take[ lines, UpTo[ n ] ], "\n" ];
    Which[
        StringLength @ text > chars,
            StringTake[ text, chars ] <> "\n" <> acpLabel[ "TruncatedMoreCharacters", <| "n" -> StringLength @ text0 - chars |> ],
        Length @ lines > n,
            text <> "\n" <> acpLabel[ "TruncatedMoreLines", <| "n" -> Length @ lines - n |> ],
        True,
            text
    ]
];

previewHeadText // endDefinition;


(* Whether previewHeadText leaves out part of a text *)
headCutQ // beginDefinition;

headCutQ[ text_String, n_Integer, chars_Integer ] := With[ { lines = StringSplit[ text, "\n", All ] },
    Length @ lines > n || StringLength @ StringRiffle[ Take[ lines, UpTo[ n ] ], "\n" ] > chars
];

headCutQ // endDefinition;


permissionButton // beginDefinition;

(* scope: the (neutralized) "Always allow" text of the card, its tooltip, or None *)
permissionButton[ nbo_, reqID_, option_Association, armAt_, scope_ ] := Module[ { kind, optionID, label, style },
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
    ] // If[ kind === "allow_always" && StringQ @ scope, Tooltip[ #, Style[ scope, PrivateFontOptions -> { "OperatorSubstitution" -> False } ] ], # ] &
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
     * file edits: all edits in the project.
   paths: acpPathContext of the window (a remote window's paths are POSIX paths on its host, ~ is the remote home; they
   are resolved by string operations only). *)
alwaysScopeText // beginDefinition;

alwaysScopeText[ tool_, agent_, project_ ] := alwaysScopeText[ tool, agent, project, acpPathContext @ None ];

alwaysScopeText[ tool_Association, agent_, project_, paths_Association ] := Module[
    { name, notebookTool, mcp, command, external, scan, references, tools, shown },
    name         = tool[ "Name" ];
    notebookTool = acpNotebookToolName @ tool[ "RawName" ];
    (* a script or a call of the notebook tools: OpenCode saves the tool (for all its uses), whatever the input says,
       so a "command" or path in it says nothing about the scope *)
    mcp      = name === "execute" || StringQ @ notebookTool;
    command  = If[ mcp, None, SelectFirst[ Lookup[ Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ], { "command", "cmd" }, None ], StringQ, None ] ];
    external = If[ mcp, None, externalDirectory[ tool, command, project, paths ] ];
    references = If[ name === "execute", acpExecuteToolReferences @ tool, <| "Tools" -> { }, "Complete" -> True |> ];
    tools      = editToolsFirst @ references[ "Tools" ];
    shown      = Take[ tools, UpTo[ $permissionHeadlineTools ] ];
    Which[
        StringQ @ external,
            acpLabel[ "PermissionAlwaysScopeExternal", <| "agent" -> agent, "dir" -> scopeDirectoryLabel[ external, paths ] |> ],
        (* the tool that a script asks about is one of the script's, as far as its text shows (see scriptHeadline) *)
        tools =!= { },
            acpLabel[
                If[ scriptToolsShownQ[ references, shown ], "PermissionAlwaysScopeScript", "PermissionAlwaysScopeScriptMore" ],
                <| "agent" -> agent, "project" -> projectLabel @ project, "tools" -> scriptToolList @ shown |>
            ],
        StringQ @ notebookTool,
            acpLabel[ "PermissionAlwaysScopeTool", <| "agent" -> agent, "project" -> projectLabel @ project, "tool" -> scriptToolList @ { tool[ "RawName" ] } |> ],
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


(* The first $permissionScopePatterns patterns and the number of the others (a command can have hundreds of
   subcommands) *)
patternList // beginDefinition;

patternList[ patterns: { __String } ] := With[ { shown = Take[ patterns, UpTo[ $permissionScopePatterns ] ] },
    StringRiffle[ "\"" <> shortenText[ #, 80 ] <> "\"" & /@ shown, ", " ] <>
        If[ Length @ patterns > Length @ shown, " " <> acpLabel[ "PermissionMorePatterns", <| "n" -> Length @ patterns - Length @ shown |> ], "" ]
];

patternList // endDefinition;


(* A directory outside the project for the scope text: a remote one abbreviated with the remote home and made
   display-safe (acpRemoteDisplayName) *)
scopeDirectoryLabel // beginDefinition;
scopeDirectoryLabel[ dir_String, paths: KeyValuePattern[ "Remote" -> True ] ] := acpRemoteDisplayName @ acpRemoteAbbreviate[ dir, Lookup[ paths, "Home", None ] ];
scopeDirectoryLabel[ dir_String, _ ] := dir;
scopeDirectoryLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*externalDirectory*)

(* The directory outside the project that the request is about (a file's directory, a directory itself, or a "cd"
   target of a shell command), or None. paths: acpPathContext of the window. A remote window's paths are on its host:
   they are never looked at on this computer (no DirectoryQ, ExpandFileName or FileNameJoin), but resolved as POSIX
   paths with string operations; cd targets and the paths of list/glob/grep are folders, other tools' paths are files
   (their folder is the scope). *)
externalDirectory // beginDefinition;

externalDirectory[ tool_Association, command_, project_String, paths: KeyValuePattern[ "Remote" -> True ] ] /; StringLength @ project > 0 :=
    remoteExternalDirectory[
        tool[ "Name" ],
        toolPaths @ tool,
        If[ StringQ @ command, shellDirectoryWords @ command, { } ],
        project,
        Lookup[ paths, "Home", None ]
    ];

externalDirectory[ tool_Association, command_, project_String, _ ] /; StringLength @ project > 0 := FirstCase[
    Join[
        If[ StringQ @ command, shellDirectoryTargets[ command, project ], { } ],
        Select[ absolutePath[ #, project ] & /@ toolPaths @ tool, StringQ ]
    ],
    p_String /; ! insideDirectoryQ[ p, project ] :> If[ TrueQ @ Quiet @ DirectoryQ @ p, p, Replace[ FileNameDrop[ p, -1 ], "" -> p ] ],
    None
];

externalDirectory[ _, _, _, _ ] := None;

externalDirectory // endDefinition;


(* The paths of a tool call: its raw input's path and its locations *)
toolPaths // beginDefinition;
toolPaths[ tool_Association ] := Join[
    Cases[ Lookup[ Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ], { "path", "filePath", "file_path" }, None ], _String ],
    Cases[ Replace[ tool[ "Locations" ], Except[ _List ] -> { } ], KeyValuePattern[ "path" -> p_String ] :> p ]
];
toolPaths // endDefinition;


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
shellDirectoryTargets[ command_String, project_String ] := Select[ absolutePath[ #, project ] & /@ shellDirectoryWords @ command, StringQ ];
shellDirectoryTargets // endDefinition;


(* The targets of cd/pushd/... in a shell command, unquoted, as written *)
shellDirectoryWords // beginDefinition;

shellDirectoryWords[ command_String ] := Flatten @ Map[
    Function[ words,
        If[ words =!= { } && MemberQ[ $shellDirectoryCommands, ToLowerCase @ First @ words ],
            unquote /@ Select[ Rest @ words, ! StringStartsQ[ #, "-" ] & ],
            { }
        ]
    ],
    shellCommandWords /@ shellSplitCommands @ command
];

shellDirectoryWords // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Remote paths*)

(* The absolute path on the host of a path in a remote tool call (None if it can't be known: a variable, a command
   substitution, ~user, or ~ with an unknown home) *)
remoteAbsolutePath // beginDefinition;

remoteAbsolutePath[ path_String, project_, home_ ] := Which[
    path === "" || StringContainsQ[ path, "$" | "`" ], None,
    path === "~", If[ StringQ @ home, home, None ],
    StringStartsQ[ path, "~/" ], If[ StringQ @ home, acpRemoteLexicalPath[ home <> StringDrop[ path, 1 ] ], None ],
    StringStartsQ[ path, "~" ], None,
    StringStartsQ[ path, "/" ], acpRemoteLexicalPath @ path,
    StringQ @ project && StringStartsQ[ project, "/" ], acpRemoteLexicalPath[ project <> "/" <> path ],
    True, None
];

remoteAbsolutePath[ _, _, _ ] := None;

remoteAbsolutePath // endDefinition;


(* Whether a remote path is the folder dir or in it (lexically: links are not resolved) *)
remoteInsideQ // beginDefinition;

remoteInsideQ[ path_String, dir_String ] := With[ { a = acpRemoteLexicalPath @ path, d = acpRemoteLexicalPath @ dir },
    a === d || d === "/" || StringStartsQ[ a, d <> "/" ]
];

remoteInsideQ[ _, _ ] := False;

remoteInsideQ // endDefinition;


(* The first folder outside the project: cd targets are folders, the paths of list/glob/grep too, other tools' paths are
   files (their parent folder is the scope) *)
remoteExternalDirectory // beginDefinition;

remoteExternalDirectory[ toolName_, paths_List, cdTargets_List, project_String, home_ ] := FirstCase[
    Join[
        { remoteAbsolutePath[ #, project, home ], True } & /@ cdTargets,
        { remoteAbsolutePath[ #, project, home ], MemberQ[ { "list", "glob", "grep" }, toolName ] } & /@ paths
    ],
    { p_String, dirQ_ } /; ! remoteInsideQ[ p, project ] :> If[ TrueQ @ dirQ, p, acpRemoteParent @ p ],
    None
];

remoteExternalDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpShellSavePatterns*)

(* An approximation of the patterns OpenCode saves for "Always allow" on a shell command: OpenCode parses the command and,
   for every simple command except directory changes (cd, pushd, ...), saves "<prefix> *", where the prefix is the
   command name plus as many words as its arity table says (e.g. "git status *", "npm run build *", "rm *").
   Gives <| "Patterns" -> { ... }, "Complete" -> False |> when more patterns may be saved than are listed: the command
   contains substitutions that OpenCode also looks into, or an unclosed quote (which the splitter runs to the end of the
   command, so later simple commands get no pattern of their own). The panel then shows the "nested commands" wording. *)
acpShellSavePatterns // beginDefinition;

acpShellSavePatterns[ command_String ] := <|
    "Patterns" -> DeleteDuplicates @ DeleteCases[ shellSavePattern @* shellCommandWords /@ shellSplitCommands @ command, None ],
    "Complete" -> ! StringContainsQ[ command, "$(" | "`" | "<(" | ">(" ] && ! shellUnclosedQuoteQ @ command
|>;

acpShellSavePatterns // endDefinition;


(* Whether the command has an unclosed single or double quote (the splitter then takes the rest of the command as one
   piece, so the commands after it get no pattern): remove escaped characters and complete quoted strings, and see if a
   lone quote is left *)
shellUnclosedQuoteQ // beginDefinition;
shellUnclosedQuoteQ[ command_String ] := StringContainsQ[
    StringDelete[
        StringDelete[ command, "\\" ~~ _ ],
        { "'" ~~ Except[ "'" ]... ~~ "'", "\"" ~~ ( ( "\\" ~~ _ ) | Except[ "\"" ] )... ~~ "\"" }
    ],
    "'" | "\""
];
shellUnclosedQuoteQ // endDefinition;


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


(* Splits a shell command into simple commands at unquoted &&, ||, ;, |, &, newlines and parentheses (not at the & of a
   redirection such as 2>&1 or &>). The command is read as tokens ($shellTokens: quoted strings, escaped characters,
   comments, here-document operators, separators, brackets and runs of other characters), so it takes time in
   proportion to its length.
   OpenCode saves the patterns of the command nodes of tree-sitter's parse, so comments and the bodies of here documents
   (from the line after "<<WORD" to the line that is WORD) are left out: they are not commands, and a command that
   writes a large file with cat <<EOF ... EOF is one command, whatever the file holds. But the text of "Always allow"
   must never name fewer patterns than OpenCode saves (an agent could hide a command in a comment or a here document
   that isn't one), so they are left out only where the shell certainly reads them so; anywhere else their words are
   read as commands, which can only name more patterns than OpenCode saves:
     * a comment is a # at the start of a word (after a blank, a separator or a parenthesis) to the end of its line;
     * a here document's operator is a << (not <<<) at the start of a word, with a plain word (letters, digits and _,
       not a digit first; maybe quoted as a whole, or after a backslash);
     * neither of them in brackets: ${...}, $[...], ((...)) and $((...)) (arithmetic, where << is a shift and # a
       base), [[...]] or `...`;
     * the body is skipped only if the line break after the operator is outside brackets too, at the same depth of
       parentheses, and a line that is the word follows (the bodies after one without it are read as commands).
   At most $maxHeredocs bodies are skipped. *)
shellSplitCommands // beginDefinition;

shellSplitCommands[ command_String ] := Module[
    {
        n, pos = 1, pieces = Internal`Bag[ ], current = Internal`Bag[ ], pending = { }, heredocs = 0, restart,
        paren = 0, arith = 0, brace = 0, bracket = 0, test = 0, tick = False, last = { None, 0 }, next, bodyEnd,
        flush, plainQ, wordStartQ, step
    },
    n = StringLength @ command;
    flush[ ] := (Internal`StuffBag[ pieces, StringJoin @ Internal`BagPart[ current, All ] ]; current = Internal`Bag[ ]);
    (* outside brackets, where comments and here documents are what they seem *)
    plainQ[ ] := arith === 0 && brace === 0 && bracket === 0 && test === 0 && ! tick;
    (* the characters that the comment token's lookbehind takes as the end of a word *)
    wordStartQ[ i_Integer ] := i === 1 || StringMatchQ[ StringTake[ command, { i - 1 } ], RegularExpression[ "[\\s;&|()]" ] ];
    (* One token at { start, end } in the command (comments: whether it is a token of $shellTokens, which can be a
       comment); gives the position after the bodies of here documents that it skips, or None *)
    step[ token_String, { start_Integer, end_Integer }, comments_ ] := (
        next = None;
        Switch[ token,
            "\n",
                flush[ ];
                If[ pending =!= { } && plainQ[ ] && AllTrue[ pending, #[ "Parentheses" ] === paren & ],
                    bodyEnd = heredocEnd[ command, end, pending ];
                    If[ bodyEnd > end, next = bodyEnd + 1 ]
                ];
                pending = { },
            "&&" | "||" | ";" | "|" | "&",
                flush[ ],
            "(",
                flush[ ];
                paren++;
                (* (( and $(( start arithmetic *)
                Which[ arith > 0, arith++, First @ last === "(" && Last @ last === start - 1, arith = 2 ],
            ")",
                flush[ ];
                paren = Max[ 0, paren - 1 ];
                If[ arith > 0, arith-- ],
            "${" | "$[" | "[[" | "]]" | "{" | "}" | "[" | "]" | "`",
                Switch[ token,
                    "${", brace++,
                    "{" , If[ brace > 0, brace++ ],
                    "}" , If[ brace > 0, brace-- ],
                    "$[", bracket++,
                    "[" , If[ bracket > 0, bracket++ ],
                    "]" , If[ bracket > 0, bracket-- ],
                    "[[", If[ bracket > 0, bracket += 2, test++ ],
                    "]]", Which[ bracket > 0, bracket = Max[ 0, bracket - 2 ], test > 0, test-- ],
                    "`" , tick = ! tick
                ];
                Internal`StuffBag[ current, token ],
            _,
                Which[
                    (* a comment is left out; in brackets its # is a character of a word, and the rest of its line is
                       read as tokens again, without comments *)
                    comments && StringStartsQ[ token, "#" ] && wordStartQ @ start,
                        If[ ! plainQ[ ],
                            Scan[
                                step[ StringTake[ token, # ], # + start - 1, False ] &,
                                StringPosition[ token, $shellTokensWithoutComments, Overlaps -> False ]
                            ]
                        ],
                    StringStartsQ[ token, "<<" ] && ! StringStartsQ[ token, "<<<" ],
                        If[ plainQ[ ] && wordStartQ @ start && heredocs < $maxHeredocs,
                            heredocs++;
                            AppendTo[ pending, Append[ heredocDelimiter @ token, "Parentheses" -> paren ] ]
                        ];
                        Internal`StuffBag[ current, token ],
                    True,
                        Internal`StuffBag[ current, token ]
                ]
        ];
        last = { token, end };
        next
    );
    While[ pos <= n,
        restart = None;
        Do[
            restart = step[ StringTake[ command, span ], span, True ];
            If[ IntegerQ @ restart, Break[ ] ],
            { span, StringPosition[ StringDrop[ command, pos - 1 ], $shellTokens, Overlaps -> False ] + (pos - 1) }
        ];
        If[ IntegerQ @ restart, last = { None, 0 } ];
        pos = If[ IntegerQ @ restart, restart, n + 1 ]
    ];
    flush[ ];
    Select[ StringTrim /@ Internal`BagPart[ pieces, All ], StringLength[ # ] > 0 & ]
];

shellSplitCommands // endDefinition;

$maxHeredocs = 16;

(* Tokens of a shell command, in this order: a single-quoted string (one that is not closed runs to the end), a
   double-quoted string with its escapes, an escaped character (also an escaped line break), a comment (a # at the start
   of a word: after a blank, a separator or a parenthesis, or at the start; the rest of its line), a here string (<<<), a
   here-document operator with a plain word (see shellSplitCommands; another << is two <), a redirection with & (2>&1,
   >&2, &>, &>>), a separator, a bracket (${, $[, [[, ]], {, }, [, ], `), a run of other characters (a blank before a #
   ends it), a lone < or >, a lone blank *)
$shellTokenPatterns = <|
    "Single"     -> "'[^']*'?",
    "Double"     -> "\"(?:[^\"\\\\]|\\\\[\\s\\S])*\"?",
    "Escape"     -> "\\\\[\\s\\S]",
    "Comment"    -> "(?<![^\\s;&|()])#[^\\n]*",
    "HereString" -> "<<<",
    "Heredoc"    -> "<<-?[ \\t]*(?:'[A-Za-z_][A-Za-z0-9_]*'|\"[A-Za-z_][A-Za-z0-9_]*\"|\\\\?[A-Za-z_][A-Za-z0-9_]*)(?=[\\s;&|<>()]|$)",
    "Redirect"   -> "[0-9]*[<>]&[0-9-]*|&>>?",
    "Separator"  -> "&&|\\|\\||[;|&\\n()]",
    "Bracket"    -> "\\$\\{|\\$\\[|\\[\\[|\\]\\]|[{}\\[\\]`]",
    "Run"        -> "(?:[^'\"\\\\;|&\\n()<>{}\\[\\]`$\\s]|\\$(?![{\\[])|[^\\S\\n](?!#))+",
    "Angle"      -> "[<>]",
    "Blank"      -> "[^\\S\\n]"
|>;

$shellTokens = RegularExpression @ StringRiffle[ Values @ $shellTokenPatterns, "|" ];

(* The same without comments (for the rest of a line after a # in brackets): a # and the blanks before it are
   characters of a run *)
$shellTokensWithoutComments = RegularExpression @ StringRiffle[
    Values @ Append[
        KeyDrop[ $shellTokenPatterns, "Comment" ],
        "Run" -> "(?:[^'\"\\\\;|&\\n()<>{}\\[\\]`$]|\\$(?![{\\[]))+"
    ],
    "|"
];


(* The word of a here-document operator ("<<EOF", "<< 'EOF'", "<<-\"EOF\"", "<<\\EOF") and whether leading tabs of its
   lines are removed (<<-) *)
heredocDelimiter // beginDefinition;

heredocDelimiter[ token_String ] := <|
    "Word" -> StringDelete[ StringTrim @ StringDelete[ token, StartOfString ~~ "<<" ~~ ("-" | "") ], "'" | "\"" | (StartOfString ~~ "\\") ],
    "Tabs" -> StringStartsQ[ token, "<<-" ]
|>;

heredocDelimiter // endDefinition;


(* The position of the last character of the here-document bodies that start after the line break at position nl: each
   body ends with a line that is its word (after leading tabs for <<-). The bodies are skipped up to the first one
   without such a line (the shell would take the rest of the command as its body, but what OpenCode's parse makes of
   it is not known): the position of the end of the bodies before it, or nl if it is the first. *)
heredocEnd // beginDefinition;

heredocEnd[ command_String, nl_Integer, delimiters_List ] := Module[ { lines, k = 0, end = nl },
    lines = StringSplit[ StringDrop[ command, nl ], "\n", All ];
    Catch[
        Do[
            With[ { i = FirstPosition[
                    If[ TrueQ @ delimiter[ "Tabs" ], StringDelete[ #, StartOfString ~~ "\t".. ] &, Identity ] /@ Drop[ lines, k ],
                    delimiter[ "Word" ],
                    None,
                    { 1 },
                    Heads -> False
                ] },
                If[ i === None, Throw @ Null ];
                end = end + Total[ StringLength /@ Take[ lines, { k + 1, k + First @ i } ] ] + First @ i;
                k   = k + First @ i
            ],
            { delimiter, delimiters }
        ]
    ];
    Min[ end, StringLength @ command ]
];

heredocEnd // endDefinition;


(* The words of a simple command as OpenCode sees them: leading variable assignments and redirections are not words,
   leading reserved words in command position are skipped (bash does not run them, and tree-sitter, which OpenCode
   parses with, does not make them command nodes: "if true; then rm x; fi" saves patterns for "true" and "rm", not for
   "if", "then" or "fi"), and a redirection glued to the command word ("cat<<EOF") is split off, so the command name is
   "cat", not "cat<<EOF". This only ever drops words the shell does not run as commands, so the text keeps naming at
   least what OpenCode saves. *)
shellCommandWords // beginDefinition;

shellCommandWords[ piece_String ] := Module[ { tokens, words = Internal`Bag[ ], skipNext = False, list },
    tokens = StringCases[ piece, (("\"" ~~ Shortest[ ___ ] ~~ "\"") | ("'" ~~ Shortest[ ___ ] ~~ "'") | Except[ WhitespaceCharacter | "\"" | "'" ]).. ];
    Do[
        Which[
            skipNext, skipNext = False,
            StringMatchQ[ t, DigitCharacter... ~~ (">>" | ">" | "<<<" | "<<" | "<" | "&>>" | "&>" | ">&" | "<&" | ">|") ],
                skipNext = True, (* the target follows *)
            StringMatchQ[ t, DigitCharacter... ~~ (">>" | ">" | "<<<" | "<<" | "<" | "&>>" | "&>" | ">&" | "<&" | ">|") ~~ __ ],
                Null,
            Internal`BagLength @ words === 0 && StringMatchQ[ t, (LetterCharacter | "_") ~~ (WordCharacter | "_")... ~~ "=" ~~ ___ ],
                Null,
            True,
                Internal`StuffBag[ words, t ]
        ],
        { t, tokens }
    ];
    list = Internal`BagPart[ words, All ];
    (* drop leading reserved words (command position), then split a redirection glued to the command word *)
    list = Drop[ list, LengthWhile[ list, MemberQ[ $shellReservedWords, # ] & ] ];
    Replace[ list, { first_String, rest___ } :> DeleteCases[ { shellCommandHead @ first, rest }, "" ] ]
];

shellCommandWords // endDefinition;

(* The reserved words of bash in command position: the shell runs none of them as a command, and OpenCode's parse makes
   no command node from them (the compound-command keywords, the negation, group braces). "time" and "coproc" are not
   here: tree-sitter-bash, which OpenCode uses, parses "time rm x" as the command "time", so OpenCode saves "time *".
   The conditional and arithmetic brackets ([[ ]] (( ))) are left out: ( and ) already split commands, and leaving [[ as
   the "command" of a test is no worse than naming a word inside it (the text only ever names more, never fewer). *)
$shellReservedWords = {
    "!", "{", "}", "if", "then", "else", "elif", "fi", "do", "done", "while", "until", "for", "case", "esac", "select",
    "in", "function"
};

(* The command name with a redirection glued to it removed ("cat<<EOF" -> "cat"): the part before the first unquoted
   redirection operator *)
shellCommandHead // beginDefinition;
shellCommandHead[ word_String ] := Replace[
    StringCases[ word, StartOfString ~~ head: Shortest[ ___ ] ~~ (DigitCharacter... ~~ ("<<<" | "<<" | ">>" | "&>>" | "&>" | ">&" | "<&" | ">|" | "<" | ">")) ~~ ___ :> head, 1 ],
    { { h_String } :> h, _ :> word }
];
shellCommandHead // endDefinition;


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
    acpIsolated @ Replace[
        acpWindowGet @ nbo,
        w_Association :> { KeyTake[ w, { "Status", "Error", "AgentInfo", "Agent", "ErrorDetailOpen" } ], acpWindowHostKey @ w }
    ],
    _Failure -> None
];
statusSignature // endDefinition;


statusContent // beginDefinition;
statusContent[ nbo_NotebookObject ] := Replace[ acpIsolated @ withRenderContext @ statusContent0 @ nbo, Except[ _RawBoxes ] :> RawBoxes[ "" ] ];
statusContent // endDefinition;


statusContent0 // beginDefinition;

(* A remote window names its host (short form) while it connects and once it is connected. "Disconnected" after an error
   (e.g. the agent exited, or ssh lost the connection) shows that error, with "Reconnect". *)
statusContent0[ nbo_NotebookObject ] := Module[ { window, agent, version, host, error, view },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Return[ RawBoxes[ "" ], Module ] ];
    agent   = windowAgentName @ window;
    version = Replace[ Lookup[ Replace[ Lookup[ window, "AgentInfo", None ], Except[ _Association ] -> <| |> ], "Version", "" ], Except[ _String ] -> "" ];
    host    = Replace[ acpWindowShortHost @ window, h_String :> acpRemoteDisplayName @ h ];
    error   = Lookup[ window, "Error", None ];
    view = Switch[ Lookup[ window, "Status", None ],
        "NoDirectory",
            Style[ acpLabel[ "ToolbarNoDirectory" ], FontColor -> $mutedColor ],
        "Connecting",
            Row @ {
                chatbookIcon[ "PercolateProgressAnimation", False ],
                " ",
                Style[
                    If[ StringQ @ host,
                        acpLabel[ "ToolbarConnectingRemote", <| "agent" -> agent, "host" -> host |> ],
                        acpLabel[ "ToolbarConnecting", <| "agent" -> agent |> ]
                    ],
                    FontColor -> $mutedColor
                ]
            },
        "Restoring",
            Row @ { chatbookIcon[ "PercolateProgressAnimation", False ], " ", Style[ acpLabel[ "ToolbarRestoring" ], FontColor -> $mutedColor ] },
        "Ready" | "Running",
            Style[
                collapseSpaces @ If[ StringQ @ host,
                    acpLabel[ "ToolbarReadyRemote", <| "agent" -> agent, "version" -> version, "host" -> host |> ],
                    acpLabel[ "ToolbarReady", <| "agent" -> agent, "version" -> version |> ]
                ],
                FontColor -> $mutedColor
            ],
        "Disconnected",
            If[ AssociationQ @ error,
                acpErrorView[
                    <| error, "Actions" -> DeleteDuplicates @ Append[ Replace[ Lookup[ error, "Actions", { } ], Except[ _List ] -> { } ], "Reconnect" ] |>,
                    nbo,
                    "Compact"
                ],
                Row @ {
                    Style[ acpLabel[ "ToolbarDisconnected" ], FontColor -> $mutedColor ],
                    " ",
                    actionButton[ nbo, "Reconnect", agent ]
                }
            ],
        "Error",
            acpErrorView[ Replace[ error, Except[ _Association ] -> <| "Message" -> acpLabel[ "ToolbarError" ] |> ], nbo, "Compact" ],
        _,
            ""
    ];
    RawBoxes @ ToBoxes @ Style[ view, FontSize -> 12 ]
];

statusContent0 // endDefinition;


(* "OpenCode  on host" for an agent without a version: one space *)
collapseSpaces // beginDefinition;
collapseSpaces[ s_String ] := StringTrim @ StringReplace[ s, " " ~~ " ".. -> " " ];
collapseSpaces // endDefinition;

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
   <| "Code", "Message", "Hint", "Output", "Detail"/"Data", "Actions" -> { "Reconnect"|"ChooseModel"|"LocateAgent"|"SignIn"|... } |>
   (acpErrorInfo, Connection.wl). Buttons call ChatbookAction[ "ACP", action, nbo ]. A remote window has no local program
   to locate: "LocateAgent" is dropped for it.
     * "Full" (final cells, the Review and picker windows): message, detail and buttons in a red box.
     * "Compact" (the toolbar status row): the message, one line under it (the last line of the output, e.g. ssh's
       "ubuntu@host: Permission denied (publickey).", or the first line of the hint), and the buttons on their own row,
       with "Details" when there is more: the hint and the output, with "Copy". Every line wraps, so a long message or
       ssh text never widens the toolbar (which would push the model/mode/effort menus out of the window). The open state
       is the window's "ErrorDetailOpen" (acpErrorKey of the error it belongs to: a new error starts closed).
   Both views turn line breaking on for all they contain ($errorTextStyle): docked cells (the toolbar, the folder
   picker's header) have LineBreakWithin -> False from the "DockedCell" style, and a LineBreakWithin of a string inside
   a Row does not reach the line that the Row makes. They show commands and paths as typed: without operator
   substitution, which draws "-" as a long minus sign and "->" as an arrow. *)
acpErrorView // beginDefinition;

acpErrorView[ error_Association ] := acpErrorView[ error, None, "Full" ];
acpErrorView[ error_Association, nbo_ ] := acpErrorView[ error, nbo, "Full" ];

acpErrorView[ error_Association, nbo_, "Compact" ] := Module[ { parts, buttons, more, open },
    parts   = acpErrorParts @ error;
    buttons = errorButtons[ error, nbo ];
    more    = TrueQ @ parts[ "MoreQ" ] && MatchQ[ nbo, _NotebookObject ];
    open    = more && acpWindowGet[ nbo, "ErrorDetailOpen", None ] === acpErrorKey @ error;
    Style[
        Column[
            DeleteCases[
                {
                    Row @ {
                        Style[ "\:26a0 ", FontColor -> $redText ],
                        Style[ parts[ "Message" ], FontColor -> $errorFont ]
                    },
                    If[ StringQ @ parts[ "Line" ] && ! open,
                        Style[ parts[ "Line" ], FontColor -> $mutedColor, FontSize -> 11 ],
                        None
                    ],
                    If[ open && StringQ @ parts[ "Details" ], errorDetailsBlock[ nbo, parts[ "Details" ] ], None ],
                    If[ buttons === { } && ! more,
                        None,
                        Row[ Append[ buttons, If[ more, errorDetailsToggle[ nbo, open ], Nothing ] ], Spacer[ 6 ] ]
                    ]
                },
                None
            ],
            Alignment -> Left,
            Spacings  -> 0.3
        ],
        Sequence @@ $errorTextStyle
    ]
];

acpErrorView[ error_Association, nbo_, _String ] := Module[ { message, detail, buttons },
    message = acpSafeText @ errorMessage @ error;
    detail  = acpSafeText @ Replace[ Lookup[ error, "Detail", None ], Except[ _String ] -> None ];
    buttons = errorButtons[ error, nbo ];
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
        BaseStyle      -> Join[ { "Text", FontSize -> 13 }, $errorTextStyle ]
    ]
];

acpErrorView[ _, ___ ] := "";

acpErrorView // endDefinition;


(* Wrapped lines start at the left edge (LineIndent -> 0), like text *)
$errorTextStyle = {
    LineBreakWithin    -> Automatic,
    LineIndent         -> 0,
    PrivateFontOptions -> { "OperatorSubstitution" -> False }
};


errorMessage // beginDefinition;
errorMessage[ error_Association ] := Replace[ Lookup[ error, "Message", None ], Except[ _String ] :> ToString @ Lookup[ error, "Code", "" ] ];
errorMessage // endDefinition;


(* The action buttons of an error (none without a window to act on) *)
errorButtons // beginDefinition;

errorButtons[ error_Association, nbo_NotebookObject ] := Module[ { actions },
    actions = Select[ Replace[ Lookup[ error, "Actions", { } ], Except[ _List ] -> { } ], StringQ ];
    If[ acpRemoteQ @ nbo, actions = DeleteCases[ actions, "LocateAgent" ] ];
    actionButton[ nbo, #, "OpenCode" ] & /@ actions
];

errorButtons[ _, _ ] := { };

errorButtons // endDefinition;


(* "Details" / "Hide details" (ChatbookAction[ "ACP", "ToggleErrorDetail", nbo ], UI.wl) *)
errorDetailsToggle // beginDefinition;

errorDetailsToggle[ nbo_NotebookObject, open_ ] := With[ { n = nbo },
    Button[
        buttonLabel[ acpLabel @ If[ TrueQ @ open, "ErrorDetailsHide", "ErrorDetailsShow" ], "Secondary" ],
        acpIsolated @ ChatbookAction[ "ACP", "ToggleErrorDetail", n ],
        Appearance -> None,
        Method     -> "Preemptive",
        BaseStyle  -> { "Text", FontSize -> 12 }
    ]
];

errorDetailsToggle // endDefinition;


(* The hint and the output of an open error, with "Copy" (ChatbookAction[ "ACP", "CopyErrorDetail", nbo ], UI.wl: the
   button carries no text, the action copies the window's current error) *)
errorDetailsBlock // beginDefinition;

errorDetailsBlock[ nbo_NotebookObject, details_String ] := With[ { n = nbo },
    Framed[
        Column[
            {
                Style[ details, FontFamily -> $codeFont, FontSize -> 11, FontColor -> $mutedColor, Sequence @@ $errorTextStyle ],
                Button[
                    buttonLabel[ acpLabel[ "ErrorDetailsCopy" ], "Secondary" ],
                    acpIsolated @ ChatbookAction[ "ACP", "CopyErrorDetail", n ],
                    Appearance -> None,
                    Method     -> "Preemptive",
                    BaseStyle  -> { "Text", FontSize -> 12 }
                ]
            },
            Alignment -> Left,
            Spacings  -> 0.4
        ],
        Background     -> $errorBackground,
        FrameStyle     -> None,
        FrameMargins   -> { { 6, 6 }, { 4, 4 } },
        RoundingRadius -> 4
    ]
];

errorDetailsBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpErrorParts*)

(* What the compact error view shows (pure): <| "Message", "Line", "Details", "MoreQ" |>.
     "Line"    -> the last line of "Output" (ssh's or the agent's own words, the most specific), else the first line of
                  "Hint", cut to $errorLineLength characters; None without either;
     "Details" -> the hint and the output, separated by a blank line (the output's last $errorDetailLines lines, at most
                  $errorDetailLength characters in all), or None;
     "MoreQ"   -> whether "Details" shows more than "Line".
   An error without "Hint" and "Output" (made before they existed, or by Git.wl/Review.wl) has its "Detail" split at
   the first blank line: two paragraphs are hint and output, one line is a hint, more lines are output. Every string is
   display-safe (acpSafeText). *)
acpErrorParts // beginDefinition;

acpErrorParts[ error_Association ] := Module[ { hint, output, detail, paragraphs, line, details },
    hint   = nonBlankString @ Lookup[ error, "Hint", None ];
    output = nonBlankString @ Lookup[ error, "Output", None ];
    detail = nonBlankString @ Lookup[ error, "Detail", None ];
    If[ hint === None && output === None && StringQ @ detail,
        paragraphs = StringSplit[ StringTrim @ detail, RegularExpression[ "\n[ \t]*\n" ], 2 ];
        { hint, output } = Which[
            Length @ paragraphs === 2, nonBlankString /@ paragraphs,
            StringContainsQ[ StringTrim @ detail, "\n" ], { None, detail },
            True, { detail, None }
        ]
    ];
    hint   = If[ StringQ @ hint, cutEnd[ StringTrim @ hint, $errorDetailLength ], None ];
    output = If[ StringQ @ output, cutStart[ lastLines[ StringTrim @ output, $errorDetailLines ], Max[ 200, $errorDetailLength - stringLength @ hint - 2 ] ], None ];
    line   = Which[
        StringQ @ output, Last @ StringSplit[ output, "\n" ],
        StringQ @ hint, First @ StringSplit[ hint, "\n" ],
        True, None
    ];
    If[ StringQ @ line, line = cutEnd[ StringTrim @ line, $errorLineLength ] ];
    details = Replace[ StringRiffle[ DeleteCases[ { hint, output }, None ], "\n\n" ], "" -> None ];
    <|
        "Message" -> acpSafeText @ errorMessage @ error,
        "Line"    -> acpSafeText @ line,
        "Details" -> acpSafeText @ details,
        "MoreQ"   -> StringQ @ details && details =!= line
    |>
];

acpErrorParts[ _ ] := <| "Message" -> "", "Line" -> None, "Details" -> None, "MoreQ" -> False |>;

acpErrorParts // endDefinition;


$errorLineLength   = 200;
$errorDetailLines  = 12;
$errorDetailLength = 1500;


nonBlankString // beginDefinition;
nonBlankString[ s_String ] /; StringLength @ StringTrim @ s > 0 := s;
nonBlankString[ _ ] := None;
nonBlankString // endDefinition;


stringLength // beginDefinition;
stringLength[ s_String ] := StringLength @ s;
stringLength[ _ ] := 0;
stringLength // endDefinition;


lastLines // beginDefinition;
lastLines[ s_String, n_Integer ] := With[ { lines = StringSplit[ s, "\n" ] }, If[ Length @ lines > n, StringRiffle[ Take[ lines, -n ], "\n" ], s ] ];
lastLines // endDefinition;


(* Texts cut to n characters with an ellipsis: keeping the start, or keeping the end *)
cutEnd // beginDefinition;
cutEnd[ s_String, n_Integer ] := If[ StringLength @ s > n, StringTake[ s, n - 1 ] <> "\[Ellipsis]", s ];
cutEnd // endDefinition;

cutStart // beginDefinition;
cutStart[ s_String, n_Integer ] := If[ StringLength @ s > n, "\[Ellipsis]" <> StringTake[ s, -(n - 1) ], s ];
cutStart // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpErrorKey*)

(* Identifies an error for the open state of its details ("ErrorDetailOpen"): a new error starts closed *)
acpErrorKey // beginDefinition;
acpErrorKey[ error_Association ] := Hash @ Lookup[ error, { "Code", "Message", "Hint", "Output", "Detail" }, None ];
acpErrorKey[ _ ] := None;
acpErrorKey // endDefinition;


actionButton // beginDefinition;

(* "Locate OpenCode...": a file chooser (the dialog is run by the front end, so no kernel evaluation waits for it); the
   chosen file becomes the program of the window's "ACPAgentCommandLine" setting. *)
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
