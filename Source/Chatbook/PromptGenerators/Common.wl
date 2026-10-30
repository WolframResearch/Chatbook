(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

HoldComplete[
    `$$downloadDeclined,
    `$$downloadSkipped,
    `$$downloadStopped,
    `$$prompt,
    `$defaultSources,
    `$downloadPromptFunction,
    `$longDownloadThreshold,
    `$maxDownloadAttempts,
    `$maxNeighbors,
    `$maxSelectedSources,
    `$promptRedownload,
    `$versionString,
    `catchDownloadFailure,
    `confirmDownloadPrompt,
    `confirmDownloadRetry,
    `confirmRedownload,
    `downloadedArchiveStatus,
    `downloadText,
    `downloadTextTemplate,
    `ensureDownloadDirectory,
    `estimateDownloadTime,
    `getNamedSnippet,
    `getSmallContextString,
    `getStreamSnippets,
    `initializeVectorDatabases,
    `insertContextPrompt,
    `observedDownloadRate,
    `validDownloadSizeQ,
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

(* Returned instead of an install location (or a loaded database) when the user declined a download: *)
$$downloadDeclined = Missing[ "DownloadDeclined", ___ ];

(* Returned instead of an install location (or a loaded database) when the chat was stopped while waiting for another
   kernel's download (see withDownloadLock). Unlike the others, this only applies to the current chat: *)
$$downloadStopped = Missing[ "DownloadStopped", ___ ];

(* Returned instead of an install location (or a loaded database) when a download is skipped, because the user declined
   it, because it failed earlier in the session (see catchDownloadFailure), or because the chat was stopped: *)
$$downloadSkipped = Missing[ "DownloadDeclined" | "DownloadFailed" | "DownloadStopped", ___ ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::InvalidPrompt = "\
Expected a string or a list of chat messages instead of `1`.";

Chatbook::DownloadDirectoryFailed = "\
Cannot download to `1` because the directory cannot be created. Check that its parent directory can be written to.";

Chatbook::DownloadLockFailed = "\
Cannot download to `1` because a lock file cannot be created there. Check that the directory can be written to.";

Chatbook::DownloadLockTimeout = "\
Timed out after waiting `2` minutes for another Wolfram Language session to finish downloading to `1`. \
Try again later.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Downloads*)
$maxDownloadAttempts   = 3;
$promptRedownload      = True;
$longDownloadThreshold = 30;
$fallbackDownloadRate  = 2.0*^6;

(* Download rates are only estimated from successful downloads of at least this many bytes (see observedDownloadRate): *)
$minDownloadRateBytes = 1*^6;

(* The failures of downloads that catchDownloadFailure catches: *)
$$downloadFailureName = Alternatives[
    "VectorDatabaseDownloadFailed",
    "SnippetDownloadFailed",
    "DownloadDirectoryFailed",
    "DownloadLockFailed",
    "DownloadLockTimeout"
];

(* Seconds for each attempt to take a download lock, seconds to wait between attempts (a chat that is stopped while
   waiting stops waiting before the next attempt), seconds between checks for a stale lock (which read the process
   table), and the total time to wait for a lock: *)
$downloadLockAttemptTime   = 0.2;
$downloadLockRetryInterval = 1;
$downloadLockPollInterval  = 10;
$downloadLockTimeout       = 600;

(* The kernel holding a download lock updates the lock file's modification date this often (in whole seconds), and
   locks that have not been updated for $staleDownloadLockAge seconds are broken (e.g. the kernel holding the lock was
   killed on another machine, or the machine name changed). Locks of kernels that are running on this machine are never
   broken (see staleDownloadLockQ): *)
$downloadLockRefreshInterval = 30;
$staleDownloadLockAge        = 180;

(* Lock files that can't be read (e.g. left empty by an interrupted write) are broken after this many seconds: *)
$staleLockFileAge = 60;

(* Lock files that were last updated longer ago than the stale age plus this margin are broken right away. The margin
   allows for file dates that are reported with a different UTC offset, e.g. in time zones whose offset is not a whole
   number of hours, or after a daylight saving time change: *)
$lockFileDateMargin = 7200;

(* Download locks held by this kernel: *)
$heldDownloadLocks = { };

(* The modification time of each lock file that this kernel is waiting for, and when it first saw that time: *)
$downloadLockObservations = <| |>;

$downloadPromptFunction := defaultDownloadPrompt;
$downloadDialogWidth     = 480;

(* Download prompts are only shown by a front end that can show dialogs: *)
$downloadPromptAllowed := TrueQ @ And[
    ! TrueQ @ $CloudEvaluation,
    TrueQ @ $Notebooks,
    TrueQ @ $dialogInputAllowed,
    ! headlessFrontEndQ[ ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*headlessFrontEndQ*)
(* True inside UsingFrontEnd in a headless kernel (e.g. in scripts or CI). $Notebooks is True there, but that front end
   has no windows, so ChoiceDialog fails (ChoiceDialog::ninit), and it resolves text resources from the installed
   Chatbook paclet: *)
headlessFrontEndQ // beginDefinition;
headlessFrontEndQ[ ] := headlessFrontEndQ[ $FrontEnd, System`UseFrontEndDump`$felink ];
headlessFrontEndQ[ FrontEndObject[ link_LinkObject ], link_LinkObject ] := True;
headlessFrontEndQ[ _, _ ] := False;
headlessFrontEndQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*downloadText*)
(* Text for download prompts and progress. A front end that can show the prompts also provides the translated text.
   Otherwise the text comes from this paclet's own text resources, since trRaw would launch a front end in a headless
   kernel, and that front end looks up the text in the installed Chatbook paclet: *)
downloadText // beginDefinition;

downloadText[ name_String ] /; $downloadPromptAllowed && MatchQ[ $FrontEnd, _FrontEndObject ] :=
    Replace[ Quiet @ FrontEndResource[ "ChatbookStrings", name ], Except[ _String ] :> trPaclet @ name ];

downloadText[ name_String ] :=
    trPaclet @ name;

downloadText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadTextTemplate*)
downloadTextTemplate // beginDefinition;
downloadTextTemplate[ name_String ] := StringTemplate @ downloadText @ name;
downloadTextTemplate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*confirmDownloadPrompt*)
(* The message is only evaluated if the prompt is shown. Only an explicit "Cancel" declines the download: if the prompt
   could not be shown (e.g. ChoiceDialog returned $Failed), the download proceeds as it does without a front end. *)
confirmDownloadPrompt // beginDefinition;
confirmDownloadPrompt // Attributes = { HoldFirst };

confirmDownloadPrompt[ message_ ] /; ! $downloadPromptAllowed := True;

confirmDownloadPrompt[ message_ ] :=
    downloadPromptResult @ Quiet[ $downloadPromptFunction @ message, ChoiceDialog::ninit ];

confirmDownloadPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadPromptResult*)
downloadPromptResult // beginDefinition;
downloadPromptResult[ True ] := True;
downloadPromptResult[ False | $Canceled ] := (stopChatOnCancel[ ]; False);
downloadPromptResult[ _ ] := True;
downloadPromptResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stopChatOnCancel*)
(* If the download was cancelled during a chat evaluation, stop the chat so the output cell is not left in progress.
   Only done while a chat is evaluating, since StopChat[] would otherwise act on the most recent chat output. *)
stopChatOnCancel // beginDefinition;

stopChatOnCancel[ ] :=
    If[ MatchQ[ $ChatEvaluationCell, _CellObject ],
        catchQuiet @ StopChat[ ];
    ];

stopChatOnCancel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*defaultDownloadPrompt*)
defaultDownloadPrompt // beginDefinition;

(* The text wraps to the window width, so it must not be wrapped in a fixed-width Pane that is wider than the window: *)
defaultDownloadPrompt[ message_String ] := ChoiceDialog[
    Style[ downloadPromptContent @ message, "DialogTextCommon", FontSize -> 14 ],
    { tr[ "OKButton" ] -> True, tr[ "CancelButton" ] -> False },
    WindowSize  -> { $downloadDialogWidth, FitAll },
    WindowTitle -> tr[ "WorkspaceWindowTitle" ]
];

defaultDownloadPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadPromptContent*)
(* Bulleted lines (e.g. the file paths from confirmRedownload) get a hanging indent, so that long paths that wrap stay
   readable: *)
downloadPromptContent // beginDefinition;

downloadPromptContent[ message_String ] /; StringContainsQ[ message, "\[Bullet] " ] :=
    Column[ downloadPromptLine /@ StringSplit[ message, "\n", All ], Spacings -> 0.4 ];

downloadPromptContent[ message_String ] :=
    message;

downloadPromptContent // endDefinition;


downloadPromptLine // beginDefinition;

downloadPromptLine[ line_String ] /; StringStartsQ[ line, "\[Bullet] " ] := Grid[
    { { "\[Bullet]", StringDrop[ line, 2 ] } },
    Alignment -> { Left, Baseline },
    Spacings  -> { 0.4, 0 },
    ItemSize  -> { { Automatic, Fit } }
];

downloadPromptLine[ line_String ] :=
    line;

downloadPromptLine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*confirmRedownload*)
(* Lists the install locations (rather than the internal names) of what is damaged, so that users can check them, e.g.
   for disk space or permissions: *)
confirmRedownload // beginDefinition;

confirmRedownload[ paths: { __String } ] := confirmDownloadPrompt @ downloadTextTemplate[ "DownloadRedownloadPrompt" ][
    StringRiffle[ ("\[Bullet] " <> #1 &) /@ paths, "\n" ]
];

confirmRedownload // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*confirmDownloadRetry*)
(* Only asks if trying again would take long (estimated from the size and download rate): *)
confirmDownloadRetry // beginDefinition;

confirmDownloadRetry[ bytes_, rate_ ] :=
    If[ estimateDownloadTime[ bytes, rate ] > $longDownloadThreshold,
        confirmDownloadPrompt @ downloadText[ "DownloadRetryPrompt" ],
        True
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
(*observedDownloadRate*)
(* The download rate in bytes per second, given the number of bytes of the successful (status 200) downloads and the
   time they took. Error responses (e.g. a fast 404) and tiny bodies say nothing about how long a download would take,
   so callers only count successful downloads, and anything less than $minDownloadRateBytes gives None, which makes
   estimateDownloadTime use the fallback rate: *)
observedDownloadRate // beginDefinition;
observedDownloadRate[ bytes_Integer, seconds_? Positive ] /; bytes >= $minDownloadRateBytes := N[ bytes / seconds ];
observedDownloadRate[ _, _ ] := None;
observedDownloadRate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validDownloadSizeQ*)
(* A download must match the known size of its archive, and the size reported by the server if it was reported. If
   there is no metadata for the archive's version, only the size reported by the server is checked (the archive must
   then be unpacked and validated before it is installed): *)
validDownloadSizeQ // beginDefinition;

validDownloadSizeQ[ size_Integer? Positive, known_Integer? Positive, total_ ] :=
    size === known && (! IntegerQ @ total || size === total);

validDownloadSizeQ[ size_Integer? Positive, _Missing, total_ ] :=
    ! IntegerQ @ total || size === total;

validDownloadSizeQ[ _, _, _ ] := False;

validDownloadSizeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*downloadedArchiveStatus*)
(* "Verified" if a downloaded archive has the expected SHA-256 hash and "Invalid" if it doesn't. If there is no
   metadata for the archive's version (e.g. Scripts/UpdateDownloadMetadata.wls was not run after a version change), it
   is "Unverified", and it is only installed if it can be unpacked and its contents are valid. A verified archive is
   kept if it can't be installed, so that only installing it needs to be tried again. *)
downloadedArchiveStatus // beginDefinition;

downloadedArchiveStatus[ expected_String, file_String ] :=
    If[ Quiet @ FileHash[ file, "SHA256", All, "HexString" ] === expected, "Verified", "Invalid" ];

downloadedArchiveStatus[ _Missing, _String ] :=
    "Unverified";

downloadedArchiveStatus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchDownloadFailure*)
(* Catches the failure of a download (its message has already been shown) and returns Missing[ "DownloadFailed",
   failure ] instead, so that a chat is not aborted by it and can continue without what could not be downloaded. Also
   returns the Missing[ "DownloadStopped" ] of a chat that was stopped while waiting for a download (see
   withDownloadLock). Any other failure is passed on. *)
catchDownloadFailure // beginDefinition;
catchDownloadFailure // Attributes = { HoldFirst };

(* The failure's message has been shown, and the chat continues, so catchHandled keeps it from silencing the messages
   of later failures in the chat: *)
catchDownloadFailure[ eval_ ] := catchHandled[ eval, downloadFailureHandler ];

catchDownloadFailure // endDefinition;


downloadFailureHandler // beginDefinition;

downloadFailureHandler[ failure: Failure[ tag_String, _ ], _ ] /; StringMatchQ[ tag, ___ ~~ "::" ~~ $$downloadFailureName ] :=
    Missing[ "DownloadFailed", failure ];

downloadFailureHandler[ stopped: $$downloadStopped, _ ] :=
    stopped;

downloadFailureHandler[ value_, tag_ ] :=
    Throw[ Unevaluated @ value, tag ];

downloadFailureHandler // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureDownloadDirectory*)
(* Creates the directory that is downloaded to if needed. If it can't be created (e.g. its parent directory is not
   writable), this throws a failure that catchDownloadFailure handles, like any other failed download. *)
ensureDownloadDirectory // beginDefinition;

ensureDownloadDirectory[ dir_String ] :=
    Replace[
        Quiet @ GeneralUtilities`EnsureDirectory @ dir,
        Except[ _String? DirectoryQ ] :> throwFailure[ "DownloadDirectoryFailed", dir ]
    ];

ensureDownloadDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withDownloadLock*)
(* Like WithLock, but the lock is kept up to date while it is held, so that other kernels can break locks that are no
   longer kept up to date (e.g. because the kernel holding them was killed). Waiting for the lock is limited to
   $downloadLockTimeout seconds. If the lock can't be taken, this throws a failure (see throwFailure). If the chat is
   stopped while waiting, this throws Missing[ "DownloadStopped" ] instead (see catchDownloadFailure), so the chat
   doesn't wait for the download, which is tried again in the next chat. Download prompts must not be shown while
   holding the lock, since other kernels would have to wait for them. *)
withDownloadLock // beginDefinition;
withDownloadLock // Attributes = { HoldRest };

(* Locks are not reentrant, so nested calls for a lock that this kernel already holds just evaluate: *)
withDownloadLock[ lock_String, eval_ ] /; MemberQ[ $heldDownloadLocks, lock ] :=
    eval;

withDownloadLock[ lock_String, eval_ ] := Catch[
    Module[ { start, checked, result },
        start   = AbsoluteTime[ ];
        checked = -Infinity;
        While[ True,
            If[ AbsoluteTime[ ] - checked >= $downloadLockPollInterval,
                breakStaleDownloadLock @ lock;
                checked = AbsoluteTime[ ]
            ];
            (* Messages from WithLock itself, e.g. when the lock file can't be created or a stale lock is removed. Each
               attempt is short, since WithLock keeps the kernel busy while it waits, unlike Pause: *)
            result = Quiet[
                WithLock[
                    File @ lock,
                    Throw[ withHeldDownloadLock[ lock, eval ], $downloadLockTag ],
                    TimeConstraint -> $downloadLockAttemptTime
                ],
                {
                    CreateDirectory::dirf,
                    CreateDirectory::privv,
                    CreateFile::privv,
                    WithLock::lock,
                    WithLock::stale,
                    WithLock::unlock
                }
            ];
            Which[
                (* WithLock fails right away if the lock file can't be created (e.g. the directory is not writable): *)
                result =!= $TimedOut,
                    Throw[ throwFailure[ "DownloadLockFailed", DirectoryName @ lock ], $downloadLockTag ],
                chatStopRequestedQ[ ],
                    Throw[ throwTop @ Missing[ "DownloadStopped" ], $downloadLockTag ],
                AbsoluteTime[ ] - start >= $downloadLockTimeout,
                    Throw[
                        throwFailure[ "DownloadLockTimeout", DirectoryName @ lock, Ceiling[ $downloadLockTimeout / 60 ] ],
                        $downloadLockTag
                    ],
                True,
                    Pause[ $downloadLockRetryInterval ]
            ]
        ]
    ],
    $downloadLockTag
];

withDownloadLock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*withHeldDownloadLock*)
(* Evaluates eval while the lock file's modification date is updated in the background. Scheduled tasks also run while
   waiting for downloads to finish, but not during a single long evaluation like ExtractArchive, which is why stale locks
   are only broken after several missed updates. *)
withHeldDownloadLock // beginDefinition;
withHeldDownloadLock // Attributes = { HoldRest };

withHeldDownloadLock[ lock_String, eval_ ] :=
    Module[ { task },
        Block[ { $heldDownloadLocks = Append[ $heldDownloadLocks, lock ] },
            WithCleanup[
                task = Quiet @ SessionSubmit @ ScheduledTask[ refreshDownloadLock @ lock, $downloadLockRefreshInterval ],
                eval,
                Quiet @ If[ MatchQ[ task, _TaskObject ], TaskRemove @ task ]
            ]
        ]
    ];

withHeldDownloadLock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*refreshDownloadLock*)
refreshDownloadLock // beginDefinition;
refreshDownloadLock[ lock_String ] := Quiet @ If[ FileExistsQ @ lock, SetFileDate @ lock ];
refreshDownloadLock // endDefinition;

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

(* A lock created by a kernel on this machine that is no longer running can be broken right away, and one that is still
   running keeps its lock however long it takes (e.g. if it was suspended, or is busy in a long evaluation that doesn't
   let it update the lock), since breaking it would delete the files that it is downloading or installing. Waiting for
   it is limited (see withDownloadLock). Any other lock is broken once the kernel holding it stops updating it (e.g. the
   lock is from another machine, or the process table is not available): *)
staleDownloadLockQ[ lock_, KeyValuePattern @ { "MachineName" -> m_String, "ProcessID" -> pid_Integer, "CreationTime" -> t_ } ] :=
    Switch[ If[ m === $MachineName, lockHolderStatus[ pid, t ], "Unknown" ],
        "Running", False,
        "Stopped", True,
        _        , downloadLockAge @ lock > $staleDownloadLockAge
    ];

(* Lock files left empty or unreadable by an interrupted write: *)
staleDownloadLockQ[ lock_, Null | $Failed | _String ] :=
    downloadLockAge @ lock > $staleLockFileAge;

staleDownloadLockQ[ lock_, _ ] :=
    downloadLockAge @ lock > $staleDownloadLockAge;

staleDownloadLockQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*downloadLockAge*)
(* Seconds for which this kernel has seen the lock file without it being updated (0 if its modification time isn't
   known, e.g. if the lock has just been released). This doesn't compare the modification time to the current time,
   since file dates can be reported with a different UTC offset (and the clocks of different machines can differ). *)
downloadLockAge // beginDefinition;

downloadLockAge[ lock_String ] :=
    With[ { time = Quiet @ FileDate[ lock, "Modification" ] },
        Which[
            ! DateObjectQ @ time, 0,
            UnixTime[ ] - UnixTime @ time > $staleDownloadLockAge + $lockFileDateMargin, Infinity,
            True, observedDownloadLockAge[ lock, UnixTime @ time ]
        ]
    ];

downloadLockAge // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*observedDownloadLockAge*)
observedDownloadLockAge // beginDefinition;

observedDownloadLockAge[ lock_String, time_Integer ] :=
    Replace[
        $downloadLockObservations @ lock,
        {
            { time, seen_ } :> AbsoluteTime[ ] - seen,
            _ :> (
                (* Only a few lock files are ever used, so this is reset in case paths keep changing (e.g. in tests): *)
                If[ Length @ $downloadLockObservations > 20, $downloadLockObservations = <| |> ];
                $downloadLockObservations[ lock ] = { time, AbsoluteTime[ ] };
                0
            )
        }
    ];

observedDownloadLockAge // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*lockHolderStatus*)
(* Whether the kernel on this machine with the given process ID that created a lock at the given time is "Running" or
   "Stopped", or "Unknown" if that can't be told (e.g. the process table is unavailable). A process that started after
   the lock was created has only reused the PID of the kernel that created it. This kernel's own locks are "Unknown",
   since it only holds a lock while it keeps it up to date (see withHeldDownloadLock). *)
lockHolderStatus // beginDefinition;

lockHolderStatus[ pid_Integer, _ ] /; pid === $ProcessID :=
    "Unknown";

lockHolderStatus[ pid_Integer, created_ ] :=
    With[ { procs = Quiet @ SystemProcesses[ "PID" -> pid ] },
        Which[
            ! ListQ @ procs, "Unknown",
            procs === { }, "Stopped",
            True,
            With[ { start = Quiet @ First[ procs ][ "StartTime" ], time = Quiet @ DateObject @ created },
                Which[
                    ! (DateObjectQ @ start && DateObjectQ @ time), "Unknown",
                    AbsoluteTime @ start > AbsoluteTime @ time + 5, "Stopped",
                    True, "Running"
                ]
            ]
        ]
    ];

lockHolderStatus // endDefinition;

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