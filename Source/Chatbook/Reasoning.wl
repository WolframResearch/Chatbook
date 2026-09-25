(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Reasoning`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(*
    Reasoning models used through the Responses API return a readable summary of their reasoning along with an encrypted
    copy of the full reasoning (a signature). The summary is displayed, but only the signature is sent back to the model
    in later requests.

    In the string representation of a response, a reasoning summary is written as:

        <think type='summary' id='...'>
        summary text
        </think>

    The id refers to an entry in `$reasoningData`, which holds the signature and some metadata. This data is also kept in
    the third argument of the "ThinkingOpener"/"ThoughtsOpener" template boxes (which are serialized when constructing
    chat messages from cells) and in the attachments of saved chats, so it can be restored in a new kernel session.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$requestMethods = { "ChatCompletions", "Responses" };

(* Reasoning data received from the Responses API, keyed by the ids used in think tags: *)
$reasoningData = <| |>;

(* The id of the reasoning summary that is currently being streamed (if any): *)
$reasoningStreamID = None;

(* Keys that are stored for each reasoning item: *)
$reasoningDataKeys = { "Signature", "CallID", "Service", "Model" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Request Method*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requestMethod*)
requestMethod // beginDefinition;

requestMethod[ settings_Association ] :=
    requestMethod[ settings, settings[ "RequestMethod" ] ];

requestMethod[ settings_, "Responses" ] :=
    If[ TrueQ @ $responsesAPIAvailable, "Responses", throwFailure[ "ResponsesAPIUnavailable" ] ];

requestMethod[ settings_, "ChatCompletions" | $$unspecified ] :=
    "ChatCompletions";

requestMethod[ settings_, invalid_ ] := (
    messagePrint[ "InvalidRequestMethod", invalid ];
    "ChatCompletions"
);

requestMethod // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reasoningServiceName*)

(* Signatures can only be decrypted by the service that created them (e.g. a signature from an OpenAI account can't be
   used with LLMKit), so the service is stored with each signature: *)
reasoningServiceName // beginDefinition;
reasoningServiceName[ settings_Association ] /; settings[ "Authentication" ] === "LLMKit" := "LLMKit";
reasoningServiceName[ settings_Association ] := serviceName @ settings;
reasoningServiceName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Think Tags*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*thinkTagAttributes*)
thinkTagAttributes // beginDefinition;

thinkTagAttributes[ attributes_String ] := Association @ StringCases[
    attributes,
    {
        name: (WordCharacter|"-").. ~~ WhitespaceCharacter... ~~ "=" ~~ WhitespaceCharacter... ~~
            "'" ~~ value: Except[ "'" ]... ~~ "'" :>
                ToLowerCase @ name -> value,
        name: (WordCharacter|"-").. ~~ WhitespaceCharacter... ~~ "=" ~~ WhitespaceCharacter... ~~
            "\"" ~~ value: Except[ "\"" ]... ~~ "\"" :>
                ToLowerCase @ name -> value
    }
];

thinkTagAttributes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*summaryAttributesQ*)
summaryAttributesQ // beginDefinition;
summaryAttributesQ[ attributes_String ] := summaryAttributesQ @ thinkTagAttributes @ attributes;
summaryAttributesQ[ KeyValuePattern[ "type" -> type_String ] ] := ToLowerCase @ type === "summary";
summaryAttributesQ[ _Association ] := False;
summaryAttributesQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reasoningIDs*)
reasoningIDs // beginDefinition;

reasoningIDs[ string_String ] := DeleteDuplicates @ Cases[
    StringCases[ string, "<think" ~~ attributes: $$thinkTagAttributes ~~ ">" :> thinkTagAttributes @ attributes ],
    as_? summaryAttributesQ :> Lookup[ as, "id", Nothing ]
];

reasoningIDs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openSummaryTag*)
openSummaryTag // beginDefinition;
openSummaryTag[ id_String ] := "<think type='summary' id='" <> id <> "'>\n";
openSummaryTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*summaryString*)
summaryString // beginDefinition;
summaryString[ id_String, summary_String ] := openSummaryTag @ id <> StringTrim @ summary <> "\n</think>\n";
summaryString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*newReasoningID*)
newReasoningID // beginDefinition;
newReasoningID[ ] := IntegerString[ Hash @ CreateUUID[ ], 36, 13 ];
newReasoningID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Reasoning Data*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*storeReasoningData*)
storeReasoningData // beginDefinition;

storeReasoningData[ settings_Association, id_String, part_Association ] :=
    With[ { signature = part[ "Signature" ] },
        If[ ByteArrayQ @ signature,
            $reasoningData[ id ] = DeleteMissing @ <|
                "Signature" -> signature,
                "CallID"    -> Lookup[ part, "CallID", Missing[ "NotAvailable" ] ],
                "Service"   -> reasoningServiceName @ settings,
                "Model"     -> Replace[ toModelName @ settings, Except[ _String ] -> Missing[ "NotAvailable" ] ]
            |>
        ]
    ];

storeReasoningData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*restoreReasoningData*)
restoreReasoningData // beginDefinition;

(* Restores reasoning data from template box metadata (e.g. when a notebook is opened in a new kernel session): *)
restoreReasoningData[ meta: KeyValuePattern @ { "ID" -> id_String, "Signature" -> _? ByteArrayQ } ] :=
    If[ ! KeyExistsQ[ $reasoningData, id ],
        $reasoningData[ id ] = KeyTake[ meta, $reasoningDataKeys ]
    ];

restoreReasoningData[ _Association ] :=
    Null;

restoreReasoningData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reasoningMetadata*)
reasoningMetadata // beginDefinition;

(* Converts think tag attributes into the metadata stored in "ThinkingOpener"/"ThoughtsOpener" template boxes: *)
reasoningMetadata[ attributes_String ] :=
    reasoningMetadata @ thinkTagAttributes @ attributes;

reasoningMetadata[ as_Association ] /; summaryAttributesQ @ as :=
    reasoningMetadata[ as, Lookup[ as, "id", None ] ];

reasoningMetadata[ _Association ] :=
    <| "Type" -> "Literal" |>;

reasoningMetadata[ as_, id_String ] :=
    <| "Type" -> "Summary", "ID" -> id, KeyTake[ Lookup[ $reasoningData, id, <| |> ], $reasoningDataKeys ] |>;

reasoningMetadata[ as_, None ] :=
    <| "Type" -> "Summary" |>;

reasoningMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streaming*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resetReasoningStream*)
resetReasoningStream // beginDefinition;
resetReasoningStream[ ] := $reasoningStreamID = None;
resetReasoningStream // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertReasoningChunks*)

(* Rewrites the reasoning chunks of a Responses API stream as content chunks that contain think tags, so that they can
   be handled the same way as any other streamed text. The summary is streamed as it arrives, and the signature arrives
   in a "ResponseContent" chunk once the reasoning item is complete. *)
convertReasoningChunks // beginDefinition;

convertReasoningChunks[ settings_Association, as: KeyValuePattern[ "BodyChunkProcessed" -> chunks_List ] ] :=
    <| as, "BodyChunkProcessed" -> Flatten[ convertReasoningChunk[ settings, # ] & /@ chunks ] |>;

convertReasoningChunks[ settings_Association, as_ ] :=
    as;

convertReasoningChunks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertReasoningChunk*)
convertReasoningChunk // beginDefinition;

convertReasoningChunk[ settings_, chunk: KeyValuePattern[ "ReasoningChunk" -> text_String ] ] := <|
    KeyDrop[ chunk, { "ReasoningChunk", "Type" } ],
    "ContentChunk" -> If[ StringQ @ $reasoningStreamID,
                          text,
                          openSummaryTag[ $reasoningStreamID = newReasoningID[ ] ] <> StringDelete[ text, StartOfString ~~ WhitespaceCharacter.. ]
                      ]
|>;

convertReasoningChunk[ settings_, chunk: KeyValuePattern[ "ResponseContent" -> parts_List ] ] := <|
    KeyDrop[ chunk, "ResponseContent" ],
    "ContentChunk" -> StringJoin[ reasoningPartString[ settings, # ] & /@ parts ]
|>;

(* Anything else that arrives while a summary is still open ends the summary: *)
convertReasoningChunk[ settings_, chunk: KeyValuePattern[ ("ContentChunk"|"ToolRequestsChunk"|"FinishReason") -> _ ] ] /;
    StringQ @ $reasoningStreamID :=
        { <| "ContentChunk" -> closeReasoningStream[ ] |>, chunk };

convertReasoningChunk[ settings_, chunk_ ] :=
    chunk;

convertReasoningChunk // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*closeReasoningStream*)
closeReasoningStream // beginDefinition;
closeReasoningStream[ ] := ($reasoningStreamID = None; "\n</think>\n");
closeReasoningStream // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reasoningPartString*)
reasoningPartString // beginDefinition;

(* The summary for this item has already been streamed, so this just needs to store its data and close the tag: *)
reasoningPartString[ settings_, part: KeyValuePattern[ "Type" -> "Reasoning" ] ] /; StringQ @ $reasoningStreamID := (
    storeReasoningData[ settings, $reasoningStreamID, part ];
    closeReasoningStream[ ]
);

(* Nothing was streamed for this item (e.g. an empty summary), so the complete summary string is created here: *)
reasoningPartString[ settings_, part: KeyValuePattern[ "Type" -> "Reasoning" ] ] :=
    With[ { id = newReasoningID[ ], summary = Replace[ Lookup[ part, "Data" ], Except[ _String ] -> "" ] },
        If[ ByteArrayQ @ part[ "Signature" ] || StringTrim @ summary =!= "",
            storeReasoningData[ settings, id, part ];
            summaryString[ id, summary ],
            ""
        ]
    ];

(* Other types of content are streamed separately: *)
reasoningPartString[ settings_, _ ] :=
    "";

reasoningPartString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertReasoningContent*)

(* Converts reasoning parts in the content of a non-streamed response to text parts containing think tags: *)
convertReasoningContent // beginDefinition;

convertReasoningContent[ settings_Association, content_List ] := (
    resetReasoningStream[ ];
    Replace[
        content,
        part: KeyValuePattern[ "Type" -> "Reasoning" ] :>
            <| "Type" -> "Text", "Data" -> reasoningPartString[ settings, part ] |>,
        { 1 }
    ]
);

convertReasoningContent[ settings_Association, content_ ] :=
    content;

convertReasoningContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertReasoningMessages*)

(* Replaces reasoning summaries in assistant messages with their signatures when using the Responses API, or removes
   them otherwise. Summary text is never sent back to the model. *)
convertReasoningMessages // beginDefinition;

convertReasoningMessages[ settings_Association, messages_List ] :=
    With[
        {
            service = If[ requestMethod @ settings === "Responses", reasoningServiceName @ settings, None ]
        },
        convertReasoningMessage[ service, # ] & /@ messages
    ];

convertReasoningMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertReasoningMessage*)
convertReasoningMessage // beginDefinition;

convertReasoningMessage[ service_, message: KeyValuePattern @ { "Role" -> "Assistant", "Content" -> content_ } ] :=
    <| message, "Content" -> convertReasoningMessageContent[ service, content ] |>;

convertReasoningMessage[ service_, message_ ] :=
    message;

convertReasoningMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertReasoningMessageContent*)
convertReasoningMessageContent // beginDefinition;

convertReasoningMessageContent[ service_, content_String ] /; StringFreeQ[ content, "<think" ] :=
    content;

convertReasoningMessageContent[ service_, content_String ] :=
    Module[ { parts },
        parts = splitReasoningSummaries[ service, content ];
        If[ FreeQ[ parts, KeyValuePattern[ "Type" -> "Reasoning" ] ],
            StringTrim @ StringJoin @ Cases[ parts, _String ],
            Replace[
                parts,
                s_String :> If[ StringTrim @ s === "", Nothing, <| "Type" -> "Text", "Data" -> StringTrim @ s |> ],
                { 1 }
            ]
        ]
    ];

convertReasoningMessageContent[ service_, content_List ] /; FreeQ[ content, s_String /; ! StringFreeQ[ s, "<think" ] ] :=
    content;

convertReasoningMessageContent[ service_, content_List ] :=
    DeleteCases[
        Flatten @ Replace[
            content,
            {
                s_String :> Developer`ToList @ convertReasoningMessageContent[ service, s ],
                KeyValuePattern @ { "Type" -> "Text", "Data" -> s_String } /; ! StringFreeQ[ s, "<think" ] :>
                    Developer`ToList @ convertReasoningMessageContent[ service, s ]
            },
            { 1 }
        ],
        ""
    ];

convertReasoningMessageContent[ service_, content_ ] :=
    content;

convertReasoningMessageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*splitReasoningSummaries*)
splitReasoningSummaries // beginDefinition;

splitReasoningSummaries[ service_, content_String ] := StringSplit[
    content,
    Shortest[ "<think" ~~ attributes: $$thinkTagAttributes ~~ ">" ~~ ___ ~~ ("</think>"|EndOfString) ] /;
        summaryAttributesQ @ attributes :>
            reasoningMessagePart[ service, thinkTagAttributes @ attributes ]
];

splitReasoningSummaries // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reasoningMessagePart*)
reasoningMessagePart // beginDefinition;

reasoningMessagePart[ service_String, KeyValuePattern[ "id" -> id_String ] ] :=
    reasoningMessagePart[ service, Lookup[ $reasoningData, id ] ];

(* Only the signature is sent, and only to the service that created it: *)
reasoningMessagePart[ service_String, KeyValuePattern @ { "Signature" -> signature_? ByteArrayQ, "Service" -> service_ } ] :=
    <| "Type" -> "Reasoning", "Signature" -> signature |>;

reasoningMessagePart[ _, _ ] :=
    Nothing;

reasoningMessagePart // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reasoningBoxToString*)
reasoningBoxToString // beginDefinition;

reasoningBoxToString[ thoughts_String, meta: KeyValuePattern @ { "Type" -> "Summary", "ID" -> id_String } ] := (
    restoreReasoningData @ meta;
    summaryString[ id, thoughts ]
);

reasoningBoxToString[ thoughts_String, KeyValuePattern[ "Type" -> "Summary" ] ] :=
    "<think type='summary'>\n" <> thoughts <> "\n</think>\n";

reasoningBoxToString[ thoughts_String, _ ] :=
    "<think>\n" <> thoughts <> "\n</think>\n";

reasoningBoxToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
