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
    `vectorDBSearch,
    `withDownloadLock
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"         ];
Needs[ "Wolfram`Chatbook`Actions`" ];
Needs[ "Wolfram`Chatbook`Common`"  ];

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

$downloadLockPollInterval = 10;
$staleLockFileAge         = 60;

$downloadPromptFunction := defaultDownloadPrompt;
$downloadDialogWidth     = 480;

$downloadPromptAllowed := TrueQ @ And[ ! TrueQ @ $CloudEvaluation, TrueQ @ $Notebooks, TrueQ @ $dialogInputAllowed ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*confirmDownloadPrompt*)
confirmDownloadPrompt // beginDefinition;
confirmDownloadPrompt[ message_String ] /; ! $downloadPromptAllowed := True;

confirmDownloadPrompt[ message_String ] :=
    With[ { confirmed = TrueQ @ $downloadPromptFunction @ message },
        If[ ! confirmed, stopChatOnCancel[ ] ];
        confirmed
    ];

confirmDownloadPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stopChatOnCancel*)
(* If the download was cancelled during a chat evaluation, stop the chat so the output cell is not left in progress.
   Only done while a chat is evaluating, since StopChat[] would otherwise act on the most recent chat output. *)
stopChatOnCancel // beginDefinition;

stopChatOnCancel[ ] :=
    If[ MatchQ[ $ChatEvaluationCell, _CellObject ],
        Quiet @ catchAlways @ StopChat[ ];
    ];

stopChatOnCancel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*defaultDownloadPrompt*)
defaultDownloadPrompt // beginDefinition;

(* The text wraps to the window width, so it must not be wrapped in a fixed-width Pane that is wider than the window: *)
defaultDownloadPrompt[ message_String ] := ChoiceDialog[
    Style[ message, "DialogTextCommon", FontSize -> 14 ],
    { tr[ "DownloadButton" ] -> True, tr[ "CancelButton" ] -> False },
    WindowSize  -> { $downloadDialogWidth, FitAll },
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
(* ::Subsection::Closed:: *)
(*withDownloadLock*)
(* Like WithLock, but periodically breaks the lock if the kernel that created it is no longer running: *)
withDownloadLock // beginDefinition;
withDownloadLock // Attributes = { HoldRest };

withDownloadLock[ lock_String, eval_ ] := Catch[
    While[ True,
        breakStaleDownloadLock @ lock;
        WithLock[ File @ lock, Throw[ eval, $downloadLockTag ], TimeConstraint -> $downloadLockPollInterval ]
    ],
    $downloadLockTag
];

withDownloadLock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*breakStaleDownloadLock*)
breakStaleDownloadLock // beginDefinition;

breakStaleDownloadLock[ lock_String ] :=
    If[ FileExistsQ @ lock,
        With[ { info = Quiet @ Get @ lock },
            (* Re-read before deleting in case another kernel has just taken over the lock: *)
            If[ staleDownloadLockQ[ lock, info ] && Quiet @ Get @ lock === info, Quiet @ DeleteFile @ lock ]
        ]
    ];

breakStaleDownloadLock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*staleDownloadLockQ*)
staleDownloadLockQ // beginDefinition;

staleDownloadLockQ[ lock_, KeyValuePattern @ { "MachineName" -> m_String, "ProcessID" -> pid_Integer, "CreationTime" -> t_ } ] :=
    m === $MachineName && ! processRunningQ[ pid, t ];

(* Lock files left empty or unreadable by an interrupted write: *)
staleDownloadLockQ[ lock_, Null | $Failed | _String ] :=
    With[ { date = Quiet @ FileDate[ lock, "Modification" ] },
        DateObjectQ @ date && AbsoluteTime[ ] - AbsoluteTime @ date > $staleLockFileAge
    ];

staleDownloadLockQ[ _, _ ] := False;

staleDownloadLockQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processRunningQ*)
(* Errs on the side of True if the process table is unavailable. A process that started after the lock was created
   has only reused the PID of the kernel that created it. *)
processRunningQ // beginDefinition;

processRunningQ[ pid_Integer, created_ ] :=
    With[ { procs = Quiet @ SystemProcesses[ "PID" -> pid ] },
        Which[
            ! ListQ @ procs, True,
            procs === { }, False,
            True,
            With[ { start = Quiet @ First[ procs ][ "StartTime" ], time = Quiet @ DateObject @ created },
                ! TrueQ[ DateObjectQ @ start && DateObjectQ @ time && AbsoluteTime @ start > AbsoluteTime @ time + 5 ]
            ]
        ]
    ];

processRunningQ // endDefinition;

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