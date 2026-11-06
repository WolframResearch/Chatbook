(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptCache`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* With the "PromptCacheOptimization" setting enabled, messages that have been sent in a conversation are sent again
   unchanged in every later request, and new information is only appended, so the request prefix can be served from the
   LLM provider's prompt cache.

   Messages that are added to a chat turn without being part of its cells (e.g. prompt generator results) are placed
   after the user's message and kept in a "turn record". Chat history is rebuilt from cells for every request, so the
   output cell of the turn gets a small "PromptCacheID" tagging rule that refers to its record, and these messages are
   inserted before the cell's message when it appears in the history of later requests.

   Records are kept in memory only, since writing larger data to the notebook can be slow (especially in the cloud). If
   a record is no longer available (e.g. after restarting the kernel), the history is rebuilt from cells only, which
   means the next request will miss the cache once. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxPromptCacheRecords = 256;
$promptCacheRecords    = <| |>;

(* Set by constructToolResponseMessages to the ID of the current turn's record while building the messages for a tool
   response: *)
$promptCacheTurnID = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*promptCacheOptimizationQ*)
promptCacheOptimizationQ // beginDefinition;
promptCacheOptimizationQ[ settings_Association ] := TrueQ @ settings[ "PromptCacheOptimization" ];
promptCacheOptimizationQ[ _ ] := False;
promptCacheOptimizationQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*promptCacheMessageQ*)
(* Messages that belong to a turn record. These are also marked as "Temporary", so they are not displayed, saved, or
   included in search/title context, but unlike other temporary messages, they are not removed from later requests: *)
promptCacheMessageQ // beginDefinition;
promptCacheMessageQ[ KeyValuePattern[ "PromptCache" -> True ] ] := True;
promptCacheMessageQ[ _ ] := False;
promptCacheMessageQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Turn Records*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setPromptCacheRecord*)
(* The bound is on the number of records, which are shared by all conversations. The oldest records are discarded first,
   and a conversation that loses a record misses the cache once. *)
setPromptCacheRecord // beginDefinition;

setPromptCacheRecord[ id_String, messages_List ] := (
    If[ ! KeyExistsQ[ $promptCacheRecords, id ] && Length @ $promptCacheRecords >= $maxPromptCacheRecords,
        (* Keep the cache from growing without bound by discarding the oldest half of the records: *)
        $promptCacheRecords = Take[ $promptCacheRecords, -Floor[ $maxPromptCacheRecords / 2 ] ]
    ];
    $promptCacheRecords[ id ] = <| "Messages" -> messages |>;
    id
);

setPromptCacheRecord // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*promptCacheRecord*)
promptCacheRecord // beginDefinition;
promptCacheRecord[ id_String ] := Lookup[ $promptCacheRecords, id, Missing[ "NotAvailable" ] ];
promptCacheRecord[ _ ] := Missing[ "NotAvailable" ];
promptCacheRecord // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*promptCacheID*)
(* The record ID that is written to the output cell's tagging rules (see makeReformattedCellTaggingRules): *)
promptCacheID // beginDefinition;
promptCacheID[ KeyValuePattern[ "Data" -> KeyValuePattern[ "PromptCacheID" -> id_String ] ] ] := id;
promptCacheID[ Cell[ __, TaggingRules -> KeyValuePattern[ "PromptCacheID" -> id_String ], ___ ] ] := id;
promptCacheID[ _ ] := Inherited;
promptCacheID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Message Construction*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*promptCacheHistoryMessages*)
(* The messages that were added to the turn of a chat output cell, so they can be inserted before the cell's message
   when building the history: *)
promptCacheHistoryMessages // beginDefinition;

promptCacheHistoryMessages[ settings_? promptCacheOptimizationQ, cell_Cell ] :=
    Replace[ promptCacheRecord @ promptCacheID @ cell, { KeyValuePattern[ "Messages" -> m_List ] :> m, _ :> { } } ];

promptCacheHistoryMessages[ settings_, cell_ ] :=
    { };

promptCacheHistoryMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dropReplayedTurnMessages*)
(* Removes the turn messages that were inserted from the records of earlier turns, so that the copy of the messages that
   is written to the output cell ("ChatData") doesn't grow with each turn. These come before the user's message, and the
   current turn's turn messages come after it: *)
dropReplayedTurnMessages // beginDefinition;

dropReplayedTurnMessages[ messages_List ] :=
    With[ { n = Max[ 0, Position[ messages, KeyValuePattern[ "Role" -> "User" ], { 1 }, Heads -> False ] ] },
        Join[ DeleteCases[ Take[ messages, n ], _? promptCacheMessageQ ], Drop[ messages, n ] ]
    ];

dropReplayedTurnMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addTurnMessages*)
(* Appends the prompt generator results to the messages of the current turn and creates the turn's record. The record ID
   is sown as chat data, so it can be written to the output cell. Requests that follow a tool call get the messages of
   the first request back (see toolEvaluation in SendChat.wl), which already include these messages: *)
addTurnMessages // beginDefinition;

addTurnMessages[ settings_Association, messages_List ] /; StringQ @ $promptCacheTurnID :=
    messages;

addTurnMessages[ settings_Association, messages_List ] := Enclose[
    Module[ { role, generated, turnMessages, id },
        role = ConfirmBy[ settings[ "PromptGeneratorMessageRole" ], StringQ, "Role" ];
        generated = ConfirmMatch[ applyPromptGenerators[ settings, messages ], { ___String }, "Generated" ];

        turnMessages = <|
            "Role"            -> role,
            "Content"         -> #,
            "Temporary"       -> True,
            "PromptGenerated" -> True,
            "PromptCache"     -> True
        |> & /@ generated;

        (* The ID is also what tells requests that follow a tool call that the prompt generators already ran: *)
        id = ConfirmBy[ createUUID[ ], StringQ, "ID" ];
        If[ turnMessages =!= { }, setPromptCacheRecord[ id, turnMessages ] ];
        Sow[ <| "PromptCacheID" -> id |>, $chatDataTag ];

        Join[ messages, turnMessages ]
    ],
    throwInternalFailure
];

addTurnMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*constructToolResponseMessages*)
(* Constructs the messages for the request that follows a tool call (see toolEvaluation in SendChat.wl). The messages
   start with the messages of the turn's first request, which already include its turn messages: *)
constructToolResponseMessages // beginDefinition;

constructToolResponseMessages[ settings_Association, messages_List ] :=
    Block[ { $promptCacheTurnID = promptCacheID @ settings }, constructMessages[ settings, messages ] ];

constructToolResponseMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
