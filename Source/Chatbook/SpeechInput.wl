(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`SpeechInput`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* TODO:
    * If model supports audio input, need to expand the audio box to the raw audio
    * Do we need to make the audio available to the evaluator tool?
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*String Templates*)
$speechInputTemplate = StringTemplate[ "\
<speech-input>
<audio>\\!\\(\\*AudioBox[\"`Audio`\"]\\)</audio>
<transcript>
`Transcript`
</transcript>
</speech-input>
" ];

$speechInputNoAudioTemplate = StringTemplate[ "\
<speech-input>
<audio>not available</audio>
<transcript>
`Transcript`
</transcript>
</speech-input>
" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatSpeechInput*)
formatSpeechInput // beginDefinition;

formatSpeechInput[ speech_String ] := Enclose[
    Module[ { audio, transcript, box },

        audio = ConfirmMatch[ parseAudio @ speech, _Audio|None, "Audio" ];
        transcript = ConfirmBy[ parseSpeechTranscript @ speech, StringQ, "Transcript" ];

        box = ConfirmMatch[
            templateBox[ <| "Audio" -> audio, "Transcript" -> transcript |>, "NotebookAssistantSpeechInput" ],
            _TemplateBox,
            "TemplateBox"
        ];

        Cell[ BoxData @ box, "NotebookAssistantSpeechInput", Background -> None ]
    ],
    throwInternalFailure
];

formatSpeechInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseAudio*)
parseAudio // beginDefinition;

parseAudio[ speech_String ] := Enclose[
    Catch @ Module[ { refs, ref, audio },

        refs = ConfirmMatch[
            StringCases[ speech, "<audio>" ~~ r__ ~~ "</audio>" :> r, 1 ],
            { ___String },
            "Refs"
        ];

        If[ refs === { }, Throw @ None ];

        ref = StringDelete[ First @ refs, { "\\!\\(\\*AudioBox[\"", "\"]\\)" } ];

        audio = ConfirmMatch[
            Quiet @ catchAlways @ GetExpressionURI[ ref, Tooltip -> False ],
            _Audio|_Failure,
            "Audio"
        ];

        If[ FailureQ @ audio,
            None,
            audio
        ]
    ],
    throwInternalFailure
];

parseAudio // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseSpeechTranscript*)
parseSpeechTranscript // beginDefinition;

parseSpeechTranscript[ speech_String ] := First[
    StringCases[ speech, Shortest[ "<transcript>" ~~ t___ ~~ "</transcript>" ] :> StringTrim @ t, 1 ],
    ""
];

parseSpeechTranscript // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*serializeSpeechInput*)
serializeSpeechInput // beginDefinition;

serializeSpeechInput[ TemplateBox[ as_, "NotebookAssistantSpeechInput", ___ ] ] :=
    serializeSpeechInput @ as;

serializeSpeechInput[ KeyValuePattern @ { "Audio" -> audio_, "Transcript" -> transcript_ } ] :=
    serializeSpeechInput[ audio, transcript ];

serializeSpeechInput[ audio_Audio, transcript0_String ] := Enclose[
    Module[ { reference, transcript },
        needsBasePrompt[ "NotebookAssistantSpeechInput" ];
        If[ toolSelectedQ[ "WolframLanguageEvaluator" ], needsBasePrompt[ "AudioBoxImporting" ] ];
        reference = ConfirmBy[ MakeExpressionURI[ "audio", "Recorded Speech Input", audio ], StringQ, "Reference" ];
        transcript = ConfirmBy[ StringTrim @ transcript0, StringQ, "Transcript" ];
        ConfirmBy[
            TemplateApply[ $speechInputTemplate, <| "Audio" -> reference, "Transcript" -> transcript |> ],
            StringQ,
            "SpeechInput"
        ]
    ],
    throwInternalFailure
];

serializeSpeechInput[ None, transcript0_String ] := Enclose[
    Catch @ Module[ { transcript },
        transcript = ConfirmBy[ StringTrim @ transcript0, StringQ, "Transcript" ];
        If[ transcript === "", Throw[ "" ] ];
        ConfirmBy[
            TemplateApply[ $speechInputNoAudioTemplate, <| "Transcript" -> transcript |> ],
            StringQ,
            "SpeechInput"
        ]
    ],
    throwInternalFailure
];

serializeSpeechInput[ None, None ] :=
    "";

serializeSpeechInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
