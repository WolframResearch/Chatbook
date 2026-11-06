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
   means the next request will miss the cache once.

   The system prompt only includes the base prompt components that are determined by the settings (see
   withStaticBasePrompts in Prompting.wl). Components that become relevant because of the content of the conversation
   (e.g. "MarkdownImageBox" for a notebook that contains images, or "SpecialURIAudio" after a tool returns audio) are
   sent as hints in the turn messages instead, once per conversation. Instructions that should no longer be followed
   can't be removed from earlier messages either, so they are disabled with a hint. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxPromptCacheRecords = 256;
$promptCacheRecords    = <| |>;

(* Set by constructToolResponseMessages to the ID of the current turn's record while building the messages for a tool
   response: *)
$promptCacheTurnID = None;

$basePromptHintTemplate = StringTemplate[ "\
<system-hint>
Here are new instructions based on the current context that should be followed:

`1`
</system-hint>" ];

(* Components that are only meant for a single response, so they are sent again in each turn that needs them: *)
$perTurnBasePrompts = {
    "AutoAssistant",
    "NotebookAssistanceInstructionsHeader", (* the heading of the three below *)
    "NotebookAssistanceGettingStarted",
    "NotebookAssistanceErrorMessage",
    "NotebookAssistanceExtraInstructions"
};

$perTurnBasePromptHintTemplate = StringTemplate[ "\
<system-hint>
Here are instructions for your response to the user's latest message:

`1`
</system-hint>" ];

$disabledPromptHintTemplate = StringTemplate[ "\
<system-hint>
`1`
</system-hint>" ];

(* Instructions that are only meant for the start of a response, so they are disabled after a tool call: *)
$disabledPromptHints = <|
    "AutoAssistant" -> "\
You have already started this response with an [INFO], [WARNING], or [ERROR] tag, so do not write another one for the \
rest of this response.",
    "ToolCallFrequency" -> "\
The user's tool call frequency preference has been taken into account for this response. For the rest of this \
response, only make further tool calls if they are needed to respond to the user."
|>;

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
   and a conversation that loses a record misses the cache once.
   The record also has the base prompt components of the system prompt, for requests that are not made from the chat
   state that built it (see staticBasePromptNames). *)
setPromptCacheRecord // beginDefinition;

setPromptCacheRecord[ id_String, messages_List ] := (
    If[ ! KeyExistsQ[ $promptCacheRecords, id ] && Length @ $promptCacheRecords >= $maxPromptCacheRecords,
        (* Keep the cache from growing without bound by discarding the oldest half of the records: *)
        $promptCacheRecords = Take[ $promptCacheRecords, -Floor[ $maxPromptCacheRecords / 2 ] ]
    ];
    $promptCacheRecords[ id ] = <| "Messages" -> messages, "BasePrompt" -> staticBasePromptNames[ ] |>;
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
    With[ { n = lastUserInputPosition @ messages },
        Join[ DeleteCases[ Take[ messages, n ], _? promptCacheMessageQ ], Drop[ messages, n ] ]
    ];

dropReplayedTurnMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addTurnMessages*)
(* Appends the turn messages (prompt generator results and base prompt hints) after the user message of the current turn
   and creates the turn's record. The record ID is sown as chat data, so it can be written to the output cell.

   Requests that follow a tool call get the messages of the first request back (see toolEvaluation in SendChat.wl),
   so the turn messages are taken from the record instead, and hints that are needed because of the tool call are
   added to them. These are placed with the other turn messages before the response, which is where they are in the
   history of later turns. A hint that is first needed after a later tool call of the turn therefore comes before that
   turn's earlier tool calls, which misses the cache for them once. *)
addTurnMessages // beginDefinition;

addTurnMessages[ settings_Association, messages_List ] /; StringQ @ $promptCacheTurnID :=
    updateTurnMessages[ settings, messages, $promptCacheTurnID ];

addTurnMessages[ settings_Association, messages_List ] := Enclose[
    Module[ { role, generated, generatedMessages, turnMessages, id },
        role = ConfirmBy[ settings[ "PromptGeneratorMessageRole" ], StringQ, "Role" ];
        generated = ConfirmMatch[ applyPromptGenerators[ settings, messages ], { ___String }, "Generated" ];

        generatedMessages = <|
            "Role"            -> role,
            "Content"         -> #,
            "Temporary"       -> True,
            "PromptGenerated" -> True,
            "PromptCache"     -> True
        |> & /@ generated;

        turnMessages = Join[ generatedMessages, basePromptHints[ settings, Join[ messages, generatedMessages ] ] ];

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
(* ::Subsubsection::Closed:: *)
(*updateTurnMessages*)
updateTurnMessages // beginDefinition;

updateTurnMessages[ settings_Association, messages_List, id_String ] := Enclose[
    Module[ { pos, before, after, record, turn, rest, new },
        pos    = lastUserInputPosition @ messages;
        before = Take[ messages, pos ];
        after  = Drop[ messages, pos ];
        record = promptCacheRecord @ id;
        turn   = If[ AssociationQ @ record, record[ "Messages" ], Select[ after, promptCacheMessageQ ] ];
        rest   = DeleteCases[ after, _? promptCacheMessageQ ];

        new = ConfirmMatch[
            Join[
                basePromptHints[ settings, Join[ before, turn, rest ] ],
                disabledPromptHints[ settings, Join[ before, turn ] ]
            ],
            { ___Association },
            "New"
        ];

        If[ new =!= { }, setPromptCacheRecord[ id, Join[ turn, new ] ] ];
        Join[ before, turn, new, rest ]
    ],
    throwInternalFailure
];

updateTurnMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*lastUserInputPosition*)
lastUserInputPosition // beginDefinition;

lastUserInputPosition[ messages_List ] :=
    Length @ messages + 1 - First @ FirstPosition[ Reverse @ messages, _? userInputMessageQ, { Length @ messages + 1 }, { 1 } ];

lastUserInputPosition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*userInputMessageQ*)
userInputMessageQ // beginDefinition;
userInputMessageQ[ message: KeyValuePattern[ "Role" -> "User" ] ] := ! Or[ toolMessageQ @ message, temporaryMessageQ @ message ];
userInputMessageQ[ _ ] := False;
userInputMessageQ // endDefinition;

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
(*Base Prompt Hints*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*promptCacheBasePrompt*)
(* The base prompt that goes in the system prompt: *)
promptCacheBasePrompt // beginDefinition;

promptCacheBasePrompt[ ] :=
    With[ { static = staticBasePromptNames[ ] },
        If[ ListQ @ static, basePromptString @ static, $basePrompt ]
    ];

promptCacheBasePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*staticBasePromptNames*)
(* The base prompt components in the system prompt of the current turn: *)
staticBasePromptNames // beginDefinition;

staticBasePromptNames[ ] :=
    Replace[
        promptCacheRecord @ $promptCacheTurnID,
        {
            KeyValuePattern[ "BasePrompt" -> static_List ] :> static,
            _ :> If[ ListQ @ $staticBasePrompts, $staticBasePrompts, Missing[ "NotAvailable" ] ]
        }
    ];

staticBasePromptNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*basePromptHints*)
(* Gives hint messages with the base prompt components that have been collected for the current request, but have not
   been sent in this conversation yet (or in this turn, for $perTurnBasePrompts): *)
basePromptHints // beginDefinition;

(* Requests that are not made from a chat state (e.g. after tool calls for automatic assistance) don't know which base
   prompt components are needed: *)
basePromptHints[ settings_, messages_ ] /; ! TrueQ @ $chatState := { };

basePromptHints[ KeyValuePattern[ "BasePrompt" -> None ], messages_ ] := { };

basePromptHints[ settings_Association, messages_List ] := Enclose[
    Catch @ Module[ { static, needed, sent, new },
        static = staticBasePromptNames[ ];
        If[ ! ListQ @ static, Throw @ { } ];
        removeBasePrompt @ settings[ "ExcludedBasePrompts" ];
        needed = ConfirmMatch[ collectedBasePromptNames[ ], { ___String }, "Needed" ];
        sent   = Union[
            static,
            Complement[ sentBasePromptNames @ messages, $perTurnBasePrompts ],
            sentBasePromptNames @ Drop[ messages, lastUserInputPosition @ messages ]
        ];
        new = Select[ needed, ! MemberQ[ sent, # ] & ];
        DeleteCases[
            {
                basePromptHint[ $basePromptHintTemplate, Complement[ new, $perTurnBasePrompts ] ],
                basePromptHint[ $perTurnBasePromptHintTemplate, Intersection[ new, $perTurnBasePrompts ] ]
            },
            None
        ]
    ],
    throwInternalFailure
];

basePromptHints // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*basePromptHint*)
basePromptHint // beginDefinition;

basePromptHint[ template_, { } ] := None;

basePromptHint[ template_, names: { __String } ] :=
    With[ { string = basePromptString @ names },
        If[ StringTrim @ string === "",
            None,
            <|
                "Role"                 -> "System",
                "Content"              -> TemplateApply[ template, { string } ],
                "Temporary"            -> True,
                "PromptCache"          -> True,
                "BasePromptComponents" -> names
            |>
        ]
    ];

basePromptHint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sentBasePromptNames*)
sentBasePromptNames // beginDefinition;
sentBasePromptNames[ messages_List ] := Flatten @ Cases[ messages, KeyValuePattern[ "BasePromptComponents" -> c_ ] :> c ];
sentBasePromptNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*disabledPromptHints*)
(* Without prompt cache optimization, these instructions are removed from the system prompt after a tool call. Since
   the system prompt can't change, a hint is added to disable them for the rest of the response instead: *)
disabledPromptHints // beginDefinition;

disabledPromptHints[ settings_Association, messages_List ] := Enclose[
    Module[ { turn, static, sent, disabled, names },
        turn     = Drop[ messages, lastUserInputPosition @ messages ];
        static   = Replace[ staticBasePromptNames[ ], Except[ _List ] :> { } ];
        sent     = Union[ static, sentBasePromptNames @ turn ];
        disabled = Flatten @ Cases[ turn, KeyValuePattern[ "DisabledPromptHints" -> c_ ] :> c ];
        names = Complement[
            {
                If[ MemberQ[ sent, "AutoAssistant" ], "AutoAssistant", Nothing ],
                If[ NumberQ @ settings[ "ToolCallFrequency" ], "ToolCallFrequency", Nothing ]
            },
            disabled
        ];
        If[ names === { },
            { },
            {
                <|
                    "Role"                -> "System",
                    "Content"             -> TemplateApply[
                        $disabledPromptHintTemplate,
                        { StringRiffle[ Values @ KeyTake[ $disabledPromptHints, names ], "\n\n" ] }
                    ],
                    "Temporary"           -> True,
                    "PromptCache"         -> True,
                    "DisabledPromptHints" -> names
                |>
            }
        ]
    ],
    throwInternalFailure
];

disabledPromptHints // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mergePromptCacheKeys*)
(* Turn messages record which hints they contain, so when they are merged with other messages (see mergeMessages), the
   merged message gets all of them: *)
mergePromptCacheKeys // beginDefinition;

mergePromptCacheKeys[ messages_List ] := Select[
    <|
        "BasePromptComponents" -> Union @ Flatten @ Lookup[ messages, "BasePromptComponents", { } ],
        "DisabledPromptHints"  -> Union @ Flatten @ Lookup[ messages, "DisabledPromptHints" , { } ]
    |>,
    # =!= { } &
];

mergePromptCacheKeys // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
