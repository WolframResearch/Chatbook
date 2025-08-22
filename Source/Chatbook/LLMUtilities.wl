(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`LLMUtilities`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$llmSynthesizeAuthentication := If[ TrueQ @ $llmKit && StringQ @ $llmKitService, "LLMKit", Automatic ];

$defaultLLMSynthesizeEvaluator :=
    If[ TrueQ @ $llmKit && StringQ @ $llmKitService,
        <| "Model" -> <| "Service" -> $llmKitService, "Name" -> "gpt-4.1-nano" |> |>,
        <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1-nano" |> |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LLM Utilities*)
$$llmPromptString   = $$string   | KeyValuePattern @ { "Type" -> "Text" , "Data" -> $$string   };
$$llmPromptGraphics = $$graphics | KeyValuePattern @ { "Type" -> "Image", "Data" -> $$graphics };
$$llmPromptItem     = $$llmPromptString | $$llmPromptGraphics;
$$llmPrompt         = $$llmPromptItem | { $$llmPromptItem.. };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmChat*)
llmChat // beginDefinition;

llmChat[ messages: $$chatMessages ] :=
    llmChat[ messages, <| |> ];

llmChat[ messages: $$chatMessages, evaluator0_Association ] :=
    Enclose @ Module[ { evaluator, config, auth, response },

        evaluator = ConfirmBy[ resolveLLMConfiguration @ evaluator0, AssociationQ, "Evaluator" ];

        config = ConfirmMatch[
            LLMConfiguration @ evaluator,
            HoldPattern @ LLMConfiguration[ _Association? AssociationQ, ___ ],
            "Config"
        ];

        auth = Lookup[ evaluator, "Authentication", $llmSynthesizeAuthentication ];

        If[ auth === "LLMKit", llmKitCheck[ ] ];

        response = LLMServices`Chat[ messages, config, Authentication -> auth ];

        If[ FailureQ @ response, throwFailureToChatOutput @ response ];

        response
    ];

llmChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmSynthesize*)
llmSynthesize // beginDefinition;

llmSynthesize[ prompt: $$llmPrompt ] :=
    llmSynthesize[ prompt, <| |> ];

llmSynthesize[ prompt: $$llmPrompt, evaluator_Association ] := Enclose[
    ConfirmMatch[
        llmSynthesize0[ prompt, evaluator, 1 ],
        If[ MatchQ[ Flatten @ { evaluator[ "StopTokens" ] }, { __String } ], _String, Except[ "", _String ] ],
        "Result"
    ],
    throwInternalFailure
];

llmSynthesize // endDefinition;


llmSynthesize0 // beginDefinition;

llmSynthesize0[ prompt: $$llmPrompt, evaluator_Association, attempt_ ] := Enclose[
    Module[ { result, callback, task },
        result = $Failed;
        callback = Function[ result = # ];
        task = llmSynthesizeSubmit[ prompt, evaluator, callback ];
        If[ FailureQ @ task, throwFailureToChatOutput @ task ];
        TaskWait @ ConfirmMatch[ task, _TaskObject, "Task" ];

        If[ MatchQ[ result, Failure[ "InvalidResponse", _ ] ]
            ,
            If[ attempt > 3, throwFailureToChatOutput @ result ];
            Pause[ Exp @ attempt / E ];
            llmSynthesize0[ prompt, evaluator, attempt + 1 ]
            ,
            result
        ]
    ],
    throwInternalFailure
];

llmSynthesize0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmSynthesizeSubmit*)
llmSynthesizeSubmit // beginDefinition;

llmSynthesizeSubmit[ prompt: $$llmPrompt, callback_ ] :=
    llmSynthesizeSubmit[ prompt, <| |>, callback ];

llmSynthesizeSubmit[ prompt0: $$llmPrompt, evaluator0_Association, callback_ ] := Enclose[
    Module[ { evaluator, prompt, messages, config, chunks, allowEmpty, handlers, keys, auth },

        evaluator  = ConfirmBy[ resolveLLMConfiguration @ evaluator0, AssociationQ, "Evaluator" ];
        prompt     = ConfirmMatch[ truncatePrompt[ prompt0, evaluator ], $$llmPrompt, "Prompt" ];
        messages   = { <| "Role" -> "User", "Content" -> prompt |> };
        config     = LLMConfiguration @ evaluator;
        chunks     = Internal`Bag[ ];
        allowEmpty = MatchQ[ Flatten @ { evaluator[ "StopTokens" ] }, { __String } ];

        handlers = <|
            "BodyChunkReceived" -> Function[
                Internal`StuffBag[ chunks, # ]
            ],
            "TaskFinished" -> Function[
                Module[ { data, strings },
                    data = Internal`BagPart[ chunks, All ];
                    $lastSynthesizeSubmitLog = data;
                    strings = extractBodyChunks @ data;
                    Which[
                        MatchQ[ strings, { __String } ] || (allowEmpty && strings === { }),
                            With[ { s = StringJoin @ strings }, callback[ s, #1 ] ],
                        FailureQ @ strings,
                            callback[ strings, #1 ],
                        True,
                            callback[ makeInvalidResponseFailure @ data, #1 ]
                    ]
                ]
            ]
        |>;

        keys = { "BodyChunk", "BodyChunkProcessed", "StatusCode", "EventName" };

        auth = Lookup[ evaluator, "Authentication", $llmSynthesizeAuthentication ];

        If[ auth === "LLMKit", llmKitCheck[ ] ];

        setServiceCaller @ LLMServices`ChatSubmit[
            messages,
            config,
            Authentication       -> auth,
            HandlerFunctions     -> handlers,
            HandlerFunctionsKeys -> keys,
            "TestConnection"     -> False
        ]
    ],
    throwInternalFailure
];

llmSynthesizeSubmit // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveLLMConfiguration*)
resolveLLMConfiguration // beginDefinition;

resolveLLMConfiguration[ evaluator_Association ] := Enclose[
    Module[ { config },
        config = KeyMap[ ToString, evaluator /. { Verbatim[ Verbatim ][ value_ ] :> value, Automatic -> Inherited } ];
        If[ $chatState && Lookup[ config, "Authentication", "LLMKit" ] =!= "LLMKit", $llmKit = False ];
        ConfirmBy[
            mergeChatSettings @ { $defaultLLMSynthesizeEvaluator, config },
            AssociationQ,
            "Result"
        ]
    ],
    throwInternalFailure
];

resolveLLMConfiguration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInvalidResponseFailure*)
makeInvalidResponseFailure // beginDefinition;

makeInvalidResponseFailure[ data_List ] /; MemberQ[ data, KeyValuePattern[ "StatusCode" -> 504 ] ] := Failure[
    "InvalidResponse",
    <|
        "Message" -> "The server is currently unavailable (504 Gateway Time-out). Please try again later.",
        "Data"    -> data
    |>
];

makeInvalidResponseFailure[ data_List ] := Failure[
    "InvalidResponse",
    <|
        "Message" -> "The server returned an invalid response. Please try again later.",
        "Data"    -> data
    |>
];

makeInvalidResponseFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*truncatePrompt*)
truncatePrompt // beginDefinition;

truncatePrompt[ string_String, evaluator_ ] :=
    stringTrimMiddle[ string, modelContextLimit @ evaluator ];

truncatePrompt[ { strings___String }, evaluator_ ] :=
    truncatePrompt[ StringJoin @ strings, evaluator ];

truncatePrompt[ prompts: { ($$string|$$graphics).. }, evaluator_ ] := Enclose[
    Module[ { stringCount, images, imageCount, budget, imageBudget, resized, imageTokens, stringBudget },

        stringCount = Count[ prompts, _String ];
        images = Cases[ prompts, $$graphics ];
        imageCount = Length @ images;
        budget = ConfirmBy[ modelContextLimit @ evaluator, IntegerQ, "Budget" ];
        imageBudget = Max[ 512, 2^(13 - imageCount) ];
        resized = Replace[ prompts, i: $$graphics :> resizePromptImage[ i, imageBudget ], { 1 } ];
        imageTokens = Total @ Cases[ resized, i: $$graphics :> imageTokenCount @ i ];

        stringBudget = ConfirmMatch[
            Floor[ (budget - imageTokens) / stringCount ],
            _Integer? Positive,
            "StringBudget"
        ];

        ConfirmMatch[
            Replace[ resized, s_String :> stringTrimMiddle[ s, stringBudget ], { 1 } ],
            { (_String|_Image).. },
            "Result"
        ]
    ],
    throwInternalFailure
];

truncatePrompt[ prompts: { ___, _Association, ___ }, evaluator_ ] :=
    truncatePrompt[ Replace[ prompts, as_Association :> as[ "Data" ], { 1 } ], evaluator ];

truncatePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizePromptImage*)
resizePromptImage // beginDefinition;

resizePromptImage[ image_ ] := resizePromptImage[ image, 4096 ];

resizePromptImage[ image: $$image, max_Integer ] := Enclose[
    Module[ { dims, size },
        dims = ConfirmMatch[ ImageDimensions @ image, { _Integer, _Integer }, "Dimensions" ];
        size = ConfirmBy[ Max[ dims, max ], IntegerQ, "Max" ];
        If[ size > max, ImageResize[ image, { UpTo[ max ], UpTo[ max ] } ], image ]
    ],
    throwInternalFailure
];

resizePromptImage[ gfx: $$graphics, max_Integer ] :=
    resizePromptImage[ resizeMultimodalImage @ gfx, max ];

resizePromptImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modelContextLimit*)
modelContextLimit // beginDefinition;
modelContextLimit[ KeyValuePattern[ "Model" -> model_ ] ] := modelContextLimit @ model;
modelContextLimit[ KeyValuePattern[ "Name" -> model_String ] ] := modelContextLimit @ model;
modelContextLimit[ "gpt-4-turbo"|"gpt-4o"|"gpt-4o-mini" ] := 200000;
modelContextLimit[ _ ] := 8000;
modelContextLimit // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*imageTokenCount*)
imageTokenCount // beginDefinition;
imageTokenCount[ img: $$image ] := imageTokenCount @ ImageDimensions @ img;
imageTokenCount[ { w_Integer, h_Integer } ] := 85 + 170 * Ceiling[ h / 512 ] * Ceiling[ w / 512 ];
imageTokenCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractBodyChunks*)
extractBodyChunks // beginDefinition;

extractBodyChunks[ data_ ] := Enclose[
    Catch[
        ConfirmMatch[
            DeleteCases[ Flatten @ { extractBodyChunks0 @ data }, "" ],
            { (_String|_LLMToolRequest)... },
            "Result"
        ],
        $bodyChunksTag
    ],
    throwInternalFailure
];

extractBodyChunks // endDefinition;


extractBodyChunks0 // beginDefinition;

extractBodyChunks0[ content_String ] :=
    content;

extractBodyChunks0[ content_List ] :=
    extractBodyChunks0 /@ content;

extractBodyChunks0[ as: KeyValuePattern[ "ToolRequestsChunk" -> t_ ] ] :=
    { extractBodyChunks0 @ KeyDrop[ as, "ToolRequestsChunk" ], toolRequestsToStrings @ t };

extractBodyChunks0[ KeyValuePattern[ "BodyChunkProcessed" -> content_ ] ] :=
    extractBodyChunks0 @ content;

extractBodyChunks0[ KeyValuePattern[ "ContentChunk"|"ContentDelta" -> content_ ] ] :=
    extractBodyChunks0 @ content;

extractBodyChunks0[ KeyValuePattern @ { "Type" -> "Text", "Data" -> content_ } ] :=
    extractBodyChunks0 @ content;

extractBodyChunks0[ KeyValuePattern @ { } ] :=
    { };

extractBodyChunks0[ bag_Internal`Bag ] :=
    extractBodyChunks0 @ Internal`BagPart[ bag, All ];

extractBodyChunks0[ Null ] := { };

extractBodyChunks0[ Failure[
    "BodyChunkProcessingFailure",
    KeyValuePattern[ "MessageParameters" :> { ___, failure_Failure? apiFailureQ, ___ } ]
] ] := extractBodyChunks0 @ failure;

extractBodyChunks0[ fail_Failure? apiFailureQ ] :=
    throwFailureToChatOutput @ fail;

extractBodyChunks0[ fail: Failure[ "BodyChunkProcessingFailure", _ ] ] /;
    ! FreeQ[
        fail,
        Alternatives[
            KeyValuePattern @ {
                "MessageTemplate" :> "Unexpected value modification `1` changed for `2`.",
                "MessageParameters" -> { _, "stop" }
            },
            KeyValuePattern[ "Message" -> "Unexpected delta type" ]
        ]
    ] := { };

extractBodyChunks0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolRequestsToStrings*)
toolRequestsToStrings // beginDefinition;
toolRequestsToStrings[ requests_List ] := toolRequestsToStrings /@ requests;
toolRequestsToStrings[ req: HoldPattern[ _LLMToolRequest ] ] := toolRequestToString @ req;
toolRequestsToStrings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolRequestToString*)
toolRequestToString // beginDefinition;

(* TODO: we currently only support one tool call at a time, so extras are discarded *)
toolRequestToString[ req_ ] /; $receivedToolCall := "";

toolRequestToString[ req: HoldPattern[ _LLMToolRequest ] ] /; $simpleToolMethod := Enclose[
    Module[ { name, tool, command, params, argString },
        name = ConfirmBy[ req[ "Name" ], StringQ, "Name" ];
        tool = ConfirmMatch[ getToolByName @ name, _LLMTool, "Tool" ];
        command = ConfirmBy[ toolShortName @ tool, StringQ, "Command" ];
        params = ToString /@ ConfirmBy[ Association @ req[ "ParameterValues" ], AssociationQ, "ParameterValues" ];
        argString = ConfirmBy[ simpleParameterString @ params, StringQ, "ArgumentString" ];
        $receivedToolCall = True;
        StringJoin[ "\n/", command, "\n", argString ]
    ],
    throwInternalFailure
];

toolRequestToString[ req: HoldPattern[ _LLMToolRequest ] ] := Enclose[
    Module[ { name, params, json },
        name = ConfirmBy[ req[ "Name" ], StringQ, "Name" ];
        params = ConfirmMatch[ req[ "ParameterValues" ], KeyValuePattern @ { }, "ParameterValues" ];
        json = ConfirmBy[ Developer`ToJSON @ params, StringQ, "JSON" ];
        $receivedToolCall = True;
        StringJoin[ "\nTOOLCALL: ", name, "\n", json, "\n", "ENDARGUMENTS" ]
    ],
    throwInternalFailure
];

toolRequestToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleParameterString*)
simpleParameterString // beginDefinition;

simpleParameterString[ params_Association ] /; Length @ params === 1 :=
    ToString @ First @ params;

simpleParameterString[ params_Association ] /; AllTrue[ params, StringFreeQ[ "\n" ] ] :=
    StringRiffle[ Values @ params, "\n" ];

simpleParameterString[ params_Association ] :=
    StringRiffle[ KeyValueMap[ simpleParameterString, params ], "\n" ];

simpleParameterString[ name_String, value_ ] :=
    StringJoin[ name, ": ", ToString @ value ];

simpleParameterString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*apiFailureQ*)
apiFailureQ // beginDefinition;
apiFailureQ[ Failure[ "APIError", KeyValuePattern[ "StatusCode" -> Except[ 100|200, _Integer ] ] ] ] := True;
apiFailureQ[ _ ] := False;
apiFailureQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
