(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`LLMUtilities`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$llmSynthesizeAuthentication   = Automatic; (* TODO *)
$defaultLLMSynthesizeEvaluator = <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o-mini" |> |>; (* TODO *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LLM Utilities*)
$$llmPrompt = $$string|$$graphics|{ ($$string|$$graphics).. };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmSynthesize*)
llmSynthesize // beginDefinition;

llmSynthesize[ prompt: $$llmPrompt ] :=
    llmSynthesize[ prompt, $defaultLLMSynthesizeEvaluator ];

llmSynthesize[ prompt: $$llmPrompt, evaluator_Association ] := Enclose[
    ConfirmMatch[ llmSynthesize0[ prompt, evaluator, 1 ], Except[ "", _String ], "Result" ],
    throwInternalFailure
];

llmSynthesize // endDefinition;


llmSynthesize0 // beginDefinition;

llmSynthesize0[ prompt: $$llmPrompt, evaluator_Association, attempt_ ] := Enclose[
    Module[ { result, callback },
        result = $Failed;
        callback = Function[ result = # ];
        TaskWait @ llmSynthesizeSubmit[ prompt, evaluator, callback ];
        If[ MatchQ[ result, Failure[ "InvalidResponse", _ ] ] && attempt <= 3,
            Pause[ Exp @ attempt / E ];
            llmSynthesize0[ prompt, evaluator, attempt + 1 ],
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
    llmSynthesizeSubmit[ prompt, $defaultLLMSynthesizeEvaluator, callback ];

llmSynthesizeSubmit[ prompt0: $$llmPrompt, evaluator_Association, callback_ ] := Enclose[
    Module[ { prompt, messages, config, chunks, handlers, keys },

        prompt   = ConfirmMatch[ truncatePrompt[ prompt0, evaluator ], $$llmPrompt, "Prompt" ];
        messages = { <| "Role" -> "User", "Content" -> prompt |> };
        config   = LLMConfiguration @ evaluator;
        chunks   = Internal`Bag[ ];

        handlers = <|
            "BodyChunkReceived" -> Function[
                Internal`StuffBag[ chunks, # ]
            ],
            "TaskFinished" -> Function[
                Module[ { data, strings },
                    data = Internal`BagPart[ chunks, All ];
                    $lastSynthesizeSubmitLog = data;
                    strings = extractBodyChunks @ data;
                    If[ ! MatchQ[ strings, { __String } ],
                        callback[ Failure[ "InvalidResponse", <| "Data" -> data |> ], #1 ],
                        With[ { s = StringJoin @ strings }, callback[ s, #1 ] ]
                    ]
                ]
            ]
        |>;

        keys = { "BodyChunk", "BodyChunkProcessed", "StatusCode", "EventName" };

        setServiceCaller @ LLMServices`ChatSubmit[
            messages,
            config,
            Authentication       -> $llmSynthesizeAuthentication,
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
(*truncatePrompt*)
truncatePrompt // beginDefinition;

truncatePrompt[ string_String, evaluator_ ] :=  stringTrimMiddle[ string, modelContextLimit @ evaluator ];
truncatePrompt[ { strings___String }, evaluator_ ] := truncatePrompt[ StringJoin @ strings, evaluator ];

truncatePrompt[ prompts: { (_String|_Image).. }, evaluator_ ] := Enclose[
    Module[ { stringCount, images, imageCount, budget, imageBudget, resized, imageTokens, stringBudget },

        stringCount = Count[ prompts, _String ];
        images = Cases[ prompts, _Image  ];
        imageCount = Length @ images;
        budget = ConfirmBy[ modelContextLimit @ evaluator, IntegerQ, "Budget" ];
        imageBudget = Max[ 512, 2^(13 - imageCount) ];
        resized = Replace[ prompts, i_Image :> resizePromptImage[ i, imageBudget ], { 1 } ];
        imageTokens = Total @ Cases[ resized, i_Image :> imageTokenCount @ i ];

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

truncatePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizePromptImage*)
resizePromptImage // beginDefinition;

resizePromptImage[ image_Image ] := resizePromptImage[ image, 4096 ];

resizePromptImage[ image_Image, max_Integer ] := Enclose[
    Module[ { dims, size },
        dims = ConfirmMatch[ ImageDimensions @ image, { _Integer, _Integer }, "Dimensions" ];
        size = ConfirmBy[ Max[ dims, max ], IntegerQ, "Max" ];
        If[ size > max, ImageResize[ image, { UpTo[ max ], UpTo[ max ] } ], image ]
    ],
    throwInternalFailure
];

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
imageTokenCount[ img_Image ] := imageTokenCount @ ImageDimensions @ img;
imageTokenCount[ { w_Integer, h_Integer } ] := 85 + 170 * Ceiling[ h / 512 ] * Ceiling[ w / 512 ];
imageTokenCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractBodyChunks*)
extractBodyChunks // beginDefinition;

extractBodyChunks[ data_ ] := Enclose[
    ConfirmMatch[ DeleteCases[ Flatten @ { extractBodyChunks0 @ data }, "" ], { ___String }, "Result" ],
    throwInternalFailure
];

extractBodyChunks // endDefinition;


extractBodyChunks0 // beginDefinition;
extractBodyChunks0[ content_String ] := content;
extractBodyChunks0[ content_List ] := extractBodyChunks /@ content;
extractBodyChunks0[ KeyValuePattern[ "BodyChunkProcessed" -> content_ ] ] := extractBodyChunks0 @ content;
extractBodyChunks0[ KeyValuePattern[ "ContentDelta" -> content_ ] ] := extractBodyChunks0 @ content;
extractBodyChunks0[ KeyValuePattern @ { "Type" -> "Text", "Data" -> content_ } ] := extractBodyChunks0 @ content;
extractBodyChunks0[ KeyValuePattern @ { } ] := { };
extractBodyChunks0[ bag_Internal`Bag ] := extractBodyChunks0 @ Internal`BagPart[ bag, All ];
extractBodyChunks0[ Null ] := { };
extractBodyChunks0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
