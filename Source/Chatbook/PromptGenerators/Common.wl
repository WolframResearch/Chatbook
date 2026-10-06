(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

HoldComplete[
    `$$prompt,
    `$defaultSources,
    `$downloadPromptFunction,
    `$longDownloadThreshold,
    `$maxDownloadAttempts,
    `$maxNeighbors,
    `$maxSelectedSources,
    `$promptRedownload,
    `$versionString,
    `confirmDownloadPrompt,
    `confirmDownloadRetry,
    `confirmRedownload,
    `estimateDownloadTime,
    `formatByteCount,
    `getNamedSnippet,
    `getSmallContextString,
    `getStreamSnippets,
    `insertContextPrompt,
    `vectorDBSearch
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$prompt = $$string | { $$string... } | $$chatMessages;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::InvalidPrompt = "\
Expected a string or a list of chat messages instead of `1`.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Downloads*)
$maxDownloadAttempts   = 3;
$promptRedownload      = True;
$longDownloadThreshold = 30;
$fallbackDownloadRate  = 2.0*^6;

$downloadPromptFunction := defaultDownloadPrompt;

$downloadPromptAllowed := TrueQ @ And[ ! TrueQ @ $CloudEvaluation, TrueQ @ $Notebooks, TrueQ @ $dialogInputAllowed ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*confirmDownloadPrompt*)
confirmDownloadPrompt // beginDefinition;
confirmDownloadPrompt[ message_String ] /; ! $downloadPromptAllowed := True;
confirmDownloadPrompt[ message_String ] := TrueQ @ $downloadPromptFunction @ message;
confirmDownloadPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*defaultDownloadPrompt*)
defaultDownloadPrompt // beginDefinition;

defaultDownloadPrompt[ message_String ] := ChoiceDialog[
    Pane[ Style[ message, "DialogTextBasic", FontSize -> 14 ], ImageSize -> 450 ],
    { tr[ "DownloadButton" ] -> True, tr[ "CancelButton" ] -> False },
    WindowTitle -> tr[ "DownloadDialogTitle" ]
];

defaultDownloadPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*confirmRedownload*)
confirmRedownload // beginDefinition;

(* typeKey is the text resource name describing what is being downloaded, e.g. "DownloadTypeVectorDatabases": *)
confirmRedownload[ typeKey_String, names: { __String }, bytes_ ] := confirmDownloadPrompt @ trStringTemplate[
    "DownloadRedownloadPrompt"
][
    <|
        "type"  -> trRaw @ typeKey,
        "names" -> StringRiffle[ ("\[Bullet] " <> #1 &) /@ names, "\n" ],
        "size"  -> formatByteCount @ bytes
    |>
];

confirmRedownload // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*confirmDownloadRetry*)
confirmDownloadRetry // beginDefinition;

confirmDownloadRetry[ label_String, bytes_, rate_ ] :=
    With[ { time = estimateDownloadTime[ bytes, rate ] },
        If[ time > $longDownloadThreshold,
            confirmDownloadPrompt @ trStringTemplate[ "DownloadRetryPrompt" ][
                <| "label" -> label, "size" -> formatByteCount @ bytes, "time" -> formatDuration @ time |>
            ],
            True
        ]
    ];

confirmDownloadRetry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*estimateDownloadTime*)
estimateDownloadTime // beginDefinition;
estimateDownloadTime[ bytes_? Positive, rate_? Positive ] := N[ bytes / rate ];
estimateDownloadTime[ bytes_? Positive, _ ] := N[ bytes / $fallbackDownloadRate ];
estimateDownloadTime[ _, _ ] := 0.0;
estimateDownloadTime // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatByteCount*)
formatByteCount // beginDefinition;
formatByteCount[ bytes_? Positive ] /; bytes >= 10^9 := trStringTemplate[ "DownloadSizeGB" ][ ToString @ Round[ bytes / 10.^9, 0.1 ] ];
formatByteCount[ bytes_? Positive ] := trStringTemplate[ "DownloadSizeMB" ][ ToString @ Max[ 1, Round[ bytes / 10.^6 ] ] ];
formatByteCount[ _ ] := trRaw[ "DownloadSizeUnknown" ];
formatByteCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatDuration*)
formatDuration // beginDefinition;
formatDuration[ seconds_? NumberQ ] /; seconds >= 90 := trStringTemplate[ "DownloadDurationMinutes" ][ ToString @ Ceiling[ seconds / 60 ] ];
formatDuration[ seconds_? NumberQ ] := trStringTemplate[ "DownloadDurationSeconds" ][ ToString @ Ceiling @ seconds ];
formatDuration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Common Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePromptGenerators*)
resolvePromptGenerators // beginDefinition;

resolvePromptGenerators[ settings0_ ] := Enclose[
    Module[ { settings, generators, resolved },

        settings   = ConfirmBy[ settings0, AssociationQ, "Settings" ];
        generators = ConfirmBy[ settings[ "PromptGenerators" ], ListQ, "Generators" ];

        If[ featureEnabledQ[ "RelatedWolframAlphaResults", settings ],
            AppendTo[ generators, "RelatedWolframAlphaResults" ]
        ];

        If[ featureEnabledQ[ "RelatedWebSearchResults", settings ],
            AppendTo[ generators, "WebSearch" ]
        ];

        resolved = ConfirmMatch[
            DeleteDuplicates[ resolvePromptGenerator /@ Flatten[ generators ] ],
            { ___LLMPromptGenerator },
            "Resolved"
        ];

        settings[ "PromptGenerators" ] = resolved;

        settings
    ],
    throwInternalFailure
];

resolvePromptGenerators // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolvePromptGenerator*)
resolvePromptGenerator // beginDefinition;

resolvePromptGenerator[ gen: HoldPattern[ _LLMPromptGenerator ] ] :=
    gen;

resolvePromptGenerator[ name_String ] := Enclose[
    Lookup[
        ConfirmBy[ $defaultPromptGenerators, AssociationQ, "DefaultPromptGenerators" ],
        name,
        throwFailure[ "InvalidPromptGenerator", name ]
    ],
    throwInternalFailure
];

resolvePromptGenerator[ ParentList|$$unspecified ] := Nothing;

resolvePromptGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];