(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatMessages`" ];
Begin[ "`Private`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Needs[ "Wolfram`Chatbook`"               ];
Needs[ "Wolfram`Chatbook`Actions`"       ];
Needs[ "Wolfram`Chatbook`Common`"        ];
Needs[ "Wolfram`Chatbook`Personas`"      ];
Needs[ "Wolfram`Chatbook`Serialization`" ];

$ContextAliases[ "tokens`" ] = "Wolfram`LLMFunctions`Utilities`Tokenization`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxMMImageSize              = 512;
$multimodalMessages          = False;
$currentMessageMinimumTokens = 16;
$tokenBudget                 = 2^13;
$tokenPressure               = 0.0;
$reservedTokens              = 500; (* TODO: determine this at submit time *)
$cellStringBudget            = Automatic;
$initialCellStringBudget     = $defaultMaxCellStringLength;
$$validMessageResult         = _Association? AssociationQ | _Missing | Nothing;
$$validMessageResults        = $$validMessageResult | { $$validMessageResult ... };

$$inlineModifierCell = Alternatives[
    Cell[ _, "InlineModifierReference", ___ ],
    Cell[ BoxData[ Cell[ _, "InlineModifierReference", ___ ], ___ ], ___ ]
];

$$promptArgumentToken = Alternatives[ ">", "^", "^^" ];

$promptTemplate = StringTemplate[ "%%Pre%%\n\n%%Group%%\n\n%%Base%%\n\n%%Tools%%\n\n%%Post%%", Delimiters -> "%%" ];

$cellRole = Automatic;

$styleRoles = <|
    "ChatInput"              -> "User",
    "ChatOutput"             -> "Assistant",
    "AssistantOutput"        -> "Assistant",
    "AssistantOutputWarning" -> "Assistant",
    "AssistantOutputError"   -> "Assistant",
    "ChatSystemInput"        -> "System"
|>;

$cachedTokenizerNames = {
    "chat-bison",
    "claude-3",
    "claude",
    "generic",
    "gpt-2",
    "gpt-3.5",
    "gpt-4-turbo",
    "gpt-4-vision",
    "gpt-4"
};

$cachedTokenizers  = <| |>;
$fallbackTokenizer = "generic";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CellToChatMessage*)
CellToChatMessage // Options = { "Role" -> Automatic };

CellToChatMessage[ cell_Cell, opts: OptionsPattern[ ] ] :=
    catchMine @ CellToChatMessage[ cell, <| "Cells" -> { cell }, "HistoryPosition" -> 0 |>, opts ];

(* TODO: this should eventually utilize "HistoryPosition" for dynamic compression rates *)
CellToChatMessage[ cell_Cell, settings_Association? AssociationQ, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $cellRole = OptionValue[ "Role" ] },
        Replace[
            Flatten @ {
                If[ TrueQ @ Positive @ Lookup[ settings, "HistoryPosition", 0 ],
                    makeCellMessage[ cell, settings ],
                    makeCurrentCellMessage[
                        settings,
                        Replace[
                            Lookup[ settings, "Cells", { cell } ],
                            { c___, _Cell } :> { c, cell }
                        ]
                    ]
                ]
            },
            { message_? AssociationQ } :> message
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Message Construction*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*constructMessages*)
constructMessages // beginDefinition;

constructMessages[ _Association? AssociationQ, { } ] := { };

constructMessages[ settings_Association? AssociationQ, cells: { __CellObject } ] :=
    constructMessages[ settings, notebookRead @ cells ];

constructMessages[ settings_Association? AssociationQ, { cells___Cell, cell_Cell } ] /; $cloudNotebooks :=
    constructMessages[ settings, makeChatMessages[ settings, { cells, parseInlineReferences @ cell } ] ];

constructMessages[ settings_Association? AssociationQ, cells: { __Cell } ] :=
    constructMessages[ settings, makeChatMessages[ settings, cells ] ];

constructMessages[ settings_Association? AssociationQ, messages0: { __Association } ] :=
    Enclose @ Module[ { prompted, messages, processed },

        If[ settings[ "AutoFormat" ], needsBasePrompt[ "Formatting" ] ];
        needsBasePrompt @ settings;
        prompted = addPrompts[ settings, messages0 ];

        messages = prompted /.
            s_String :> RuleCondition @ StringTrim @ StringReplace[
                s,
                {
                    "%%BASE_PROMPT%%" :> $basePrompt,
                    (* cSpell: ignore ENDRESULT *)
                    "\nENDRESULT(" ~~ Repeated[ LetterCharacter|DigitCharacter, $tinyHashLength ] ~~ ")\n" :>
                        "\nENDRESULT\n"
                }
            ];

        processed = applyProcessingFunction[ settings, "ChatMessages", HoldComplete[ messages, $ChatHandlerData ] ];

        If[ ! MatchQ[ processed, $$validMessageResults ],
            messagePrint[ "InvalidMessages", getProcessingFunction[ settings, "ChatMessages" ], processed ];
            processed = messages
        ];

        processed //= DeleteCases @ KeyValuePattern[ "Content" -> "" ];
        Sow[ <| "Messages" -> processed |>, $chatDataTag ];

        $lastSettings = settings;
        $lastMessages = processed;

        processed
    ];

constructMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addPrompts*)
addPrompts // beginDefinition;

addPrompts[ settings_Association, messages_List ] := Enclose[
    Module[ { custom, workspace, prompt },
        custom    = ConfirmMatch[ assembleCustomPrompt @ settings, None|_String, "Custom"    ];
        workspace = ConfirmMatch[ getWorkspacePrompt @ settings  , None|_String, "Workspace" ];
        prompt    = StringRiffle[ Select[ { custom, workspace }, StringQ ], "\n\n" ];
        addPrompts[ prompt, messages ]
    ],
    throwInternalFailure
];

addPrompts[ None|"", messages_List ] :=
    messages;

addPrompts[ prompt_String, { sysMessage: KeyValuePattern[ "Role" -> "System" ], messages___ } ] := Enclose[
    Module[ { systemPrompt, newPrompt, newMessage },
        systemPrompt = ConfirmBy[ Lookup[ sysMessage, "Content" ]             , StringQ     , "SystemPrompt" ];
        newPrompt    = ConfirmBy[ StringJoin[ systemPrompt, "\n\n", prompt ]  , StringQ     , "NewPrompt"    ];
        newMessage   = ConfirmBy[ Append[ sysMessage, "Content" -> newPrompt ], AssociationQ, "NewMessage"   ];
        { newMessage, messages }
    ]
];

addPrompts[ prompt_String, { messages___ } ] := {
    <| "Role" -> "System", "Content" -> prompt |>,
    messages
};

addPrompts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*assembleCustomPrompt*)
assembleCustomPrompt // beginDefinition;
assembleCustomPrompt[ settings_Association ] := assembleCustomPrompt[ settings, Lookup[ settings, "Prompts" ] ];
assembleCustomPrompt[ settings_, $$unspecified ] := None;
assembleCustomPrompt[ settings_, prompt_String ] := prompt;
assembleCustomPrompt[ settings_, prompts: { ___String } ] := StringRiffle[ prompts, "\n\n" ];

assembleCustomPrompt[ settings_? AssociationQ, templated: { ___, _TemplateObject, ___ } ] := Enclose[
    Module[ { params, prompts },
        params  = ConfirmBy[ Association[ settings, $ChatHandlerData ], AssociationQ, "Params" ];
        prompts = Replace[ templated, t_TemplateObject :> applyPromptTemplate[ t, params ], { 1 } ];
        assembleCustomPrompt[ settings, prompts ] /; MatchQ[ prompts, { ___String } ]
    ],
    throwInternalFailure
];

assembleCustomPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyPromptTemplate*)
applyPromptTemplate // beginDefinition;

applyPromptTemplate[ template_TemplateObject, params_Association ] :=
    If[ FreeQ[ template, TemplateSlot[ _String, ___ ] ],
        TemplateApply @ template,
        TemplateApply[ template, params ]
    ];

applyPromptTemplate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatMessages*)
makeChatMessages // beginDefinition;

makeChatMessages[ settings_, cells_ ] :=
    Block[
        {
            $multimodalMessages      = TrueQ @ settings[ "Multimodal" ],
            $tokenBudget             = makeTokenBudget @ settings,
            $tokenPressure           = 0.0,
            $initialCellStringBudget = makeCellStringBudget @ settings,
            $chatInputIndicator      = mixedContentQ @ cells,
            $cellStringBudget, $conversionRules
        },
        $conversionRules = settings[ "ConversionRules" ];
        $cellStringBudget = $initialCellStringBudget;
        If[ settings[ "BasePrompt" ] =!= None, tokenCheckedMessage[ settings, $fullBasePrompt ] ];
        (* FIXME: need to account for persona/tool prompting as well *)
        makeChatMessages0[ settings, cells ]
    ];

makeChatMessages // endDefinition;


makeChatMessages0 // beginDefinition;

makeChatMessages0[ settings_, { cells___, cell_ ? promptFunctionCellQ } ] := (
    Sow[ <| "RawOutput" -> True |>, $chatDataTag ];
    makePromptFunctionMessages[ settings, { cells, cell } ]
);

makeChatMessages0[ settings0_, cells_List ] := Enclose[
    Module[ { settings, role, message, toMessage0, toMessage, cell, history, messages, merged },
        settings   = ConfirmBy[ <| settings0, "HistoryPosition" -> 0, "Cells" -> cells |>, AssociationQ, "Settings" ];
        role       = makeCurrentRole @ settings;
        cell       = ConfirmMatch[ Last[ cells, $Failed ], _Cell, "Cell" ];
        toMessage0 = Confirm[ getCellMessageFunction @ settings, "CellMessageFunction" ];

        $tokenBudgetLog = Internal`Bag[ ];

        toMessage = Function @ With[
            { msg = toMessage0[ #1, <| #2, "TokenBudget" -> $tokenBudget, "TokenPressure" -> $tokenPressure |> ] },
            tokenCheckedMessage[ settings, msg ]
        ];

        message = ConfirmMatch[
            (* Ensure _some_ content from current chat input is used, regardless of remaining tokens: *)
            Block[ { $tokenBudget = Max[ $tokenBudget, $currentMessageMinimumTokens ] }, toMessage[ cell, settings ] ],
            $$validMessageResults,
            "Message"
        ];

        history = ConfirmMatch[
            Reverse @ Flatten @ MapIndexed[
                toMessage[ #1, <| settings, "HistoryPosition" -> First[ #2 ] |> ] &,
                Reverse @ Most @ cells
            ],
            $$validMessageResults,
            "History"
        ];

        messages = addExcisedCellMessage @ DeleteMissing @ Flatten @ { role, history, message };

        merged = If[ TrueQ @ Lookup[ settings, "MergeMessages" ], mergeMessageData @ messages, messages ];
        $lastMessageList = merged
    ],
    throwInternalFailure[ makeChatMessages0[ settings0, cells ], ## ] &
];

makeChatMessages0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeTokenBudget*)
makeTokenBudget // beginDefinition;

makeTokenBudget[ settings_Association ] :=
    makeTokenBudget[ settings[ "MaxContextTokens" ], settings[ "TokenBudgetMultiplier" ] ];

makeTokenBudget[ max: $$size, $$unspecified ] :=
    max;

makeTokenBudget[ max: $$size, multiplier: $$size ] :=
    With[ { budget = Ceiling[ max * multiplier ] },
        budget /; MatchQ[ budget, $$size ]
    ];

makeTokenBudget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCellStringBudget*)
makeCellStringBudget // beginDefinition;
makeCellStringBudget[ settings_Association ] := makeCellStringBudget @ settings[ "MaxCellStringLength" ];
makeCellStringBudget[ max: $$size ] := max;
makeCellStringBudget[ Except[ $$size ] ] := $defaultMaxCellStringLength;
makeCellStringBudget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mixedContentQ*)
mixedContentQ // beginDefinition;

mixedContentQ[ cells: { ___Cell } ] := And[
    MemberQ[ cells, Cell[ __, $$chatInputStyle, ___ ] ],
    MemberQ[ cells, Cell[ _, Except[ $$chatInputStyle|$$chatOutputStyle, _String ], ___ ] ]
];

mixedContentQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addExcisedCellMessage*)
addExcisedCellMessage // beginDefinition;

addExcisedCellMessage[ messages: { ___Association } ] := Enclose[
    Module[ { split },
        split = SplitBy[ messages, MatchQ @ KeyValuePattern[ "Content" -> "[Cell Excised]" ] ];
        ConfirmMatch[ Flatten[ combineExcisedMessages /@ split ], { ___Association }, "Messages" ]
    ],
    throwInternalFailure[ addExcisedCellMessage @ messages, ## ] &
];

addExcisedCellMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*combineExcisedMessages*)
combineExcisedMessages // beginDefinition;

combineExcisedMessages[ messages: { msg: KeyValuePattern[ "Content" -> "[Cell Excised]" ], ___ } ] :=
    <| "Role" -> "System", "Content" -> "[" <> ToString @ Length @ messages <> " Cells Excised]" |>;

combineExcisedMessages[ messages_ ] := messages;

combineExcisedMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenCheckedMessage*)
tokenCheckedMessage // beginDefinition;

tokenCheckedMessage[
    as: KeyValuePattern[ "TokenizerName" -> "claude-3" ],
    message0: KeyValuePattern @ { "Role" -> "Assistant", "Content" -> Except[ _String ] }
] :=
    With[ { message = revertMultimodalContent @ message0 },
        tokenCheckedMessage[ as, message ] /; MatchQ[ message, KeyValuePattern[ "Content" -> _String ] ]
    ];

tokenCheckedMessage[ as_Association, message_ ] /; $cellStringBudget === Infinity := message;

tokenCheckedMessage[ as_Association, message_ ] := Enclose[
    Catch @ Module[ { count, budget, resized },

        count  = ConfirmMatch[ tokenCount[ as, message ], $$size, "Count" ];
        budget = ConfirmMatch[ $tokenBudget, $$size, "Budget" ];

        If[ count > budget,
            resized = cutMessageContent[ as, message, count, budget ];
            ConfirmAssert[ resized =!= message, "Resized" ];
            Throw @ tokenCheckedMessage[ as, resized ]
        ];

        $tokenBudget      = Max[ 0, budget - count ];
        $tokenPressure    = 1.0 - ($tokenBudget / as[ "MaxContextTokens" ]);
        $cellStringBudget = If[ $tokenBudget < $reservedTokens,
                                0,
                                Ceiling[ (1 - $tokenPressure) * $initialCellStringBudget ]
                            ];

        Internal`StuffBag[
            $tokenBudgetLog,
            <|
                "PreviousBudget"   -> budget,
                "TokenBudget"      -> $tokenBudget,
                "Pressure"         -> $tokenPressure,
                "CellStringBudget" -> $cellStringBudget,
                "MessageTokens"    -> count,
                "Message"          -> message
            |>
        ];

        message
    ],
    throwInternalFailure[ tokenCheckedMessage[ as, message ], ## ] &
];

tokenCheckedMessage // endDefinition;

$tokenBudgetLog = Internal`Bag[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cutMessageContent*)
cutMessageContent // beginDefinition;

cutMessageContent[ as_, message: KeyValuePattern[ "Content" -> content_String ], count_, budget_ ] := Enclose[
    Module[ { scale, resized },
        scale   = ConfirmBy[ 0.9 * N[ budget / count ], NumberQ, "Scale" ];
        resized = ConfirmBy[ truncateString[ content, Floor[ scale * StringLength @ content ] ], StringQ, "Resized" ];
        <| message, "Content" -> resized |>
    ],
    throwInternalFailure[ cutMessageContent[ as, message, count, budget ], ## ] &
];

cutMessageContent[ as_, message: KeyValuePattern[ "Content" -> _? graphicsQ ], count_, budget_ ] :=
    <| message, "Content" -> "" |>;

cutMessageContent[ as_, message: KeyValuePattern[ "Content" -> { a___, _? graphicsQ, b___ } ], count_, budget_ ] :=
    <| message, "Content" -> { a, b } |>;

cutMessageContent[ as_, message: KeyValuePattern[ "Content" -> { content___String } ], count_, budget_ ] :=
    cutMessageContent[ as, <| message, "Content" -> StringJoin @ content |>, count, budget ];

cutMessageContent[ as_, message_String, count_, budget_ ] :=
    cutMessageContent[ as, <| "Content" -> message, "Type" -> "Text" |>, count, budget ];

cutMessageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenCount*)
tokenCount // beginDefinition;

tokenCount[ as_, KeyValuePattern[ "TokenCount" -> n_Integer ] ] := n;

tokenCount[ as_, messages_List ] :=
    With[ { counts = tokenCount[ as, # ] & /@ messages },
        Total @ counts /; MatchQ[ counts, { ___Integer } ]
    ];

tokenCount[ as_Association, message_ ] := Enclose[
    Module[ { tokenizer, content },
        tokenizer = getTokenizer @ as;
        content = ConfirmBy[ messageContent @ message, validContentQ, "Content" ];
        Length @ ConfirmMatch[ applyTokenizer[ tokenizer, content ], _List, "TokenCount" ]
    ],
    throwInternalFailure
];

tokenCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*logUsage*)
logUsage // beginDefinition;

logUsage[ KeyValuePattern[ "FullContent" -> response_ ] ] :=
    logUsage @ response;

logUsage[ _ProgressIndicator ] :=
    Null;

logUsage[ response_String ] := logUsage[
    $ChatHandlerData[ "ChatNotebookSettings" ],
    $ChatHandlerData[ "Messages" ],
    response
];

logUsage[ settings_, messages_List, response_String ] :=
    logUsage[ settings, messages, response, $ChatHandlerData[ "Usage" ] ];

logUsage[ settings_, messages_List, response_String, usage_Association ] := Enclose[
    Module[ { prompt1, completion1, prompt2, completion2, prompt, completion, requests },

        prompt1     = ConfirmMatch[ usage[ "Prompt"     ]           , $$size, "Prompt1"     ];
        completion1 = ConfirmMatch[ usage[ "Completion" ]           , $$size, "Completion1" ];
        prompt2     = ConfirmMatch[ tokenCount[ settings, messages ], $$size, "Prompt2"     ];
        completion2 = ConfirmMatch[ tokenCount[ settings, response ], $$size, "Completion2" ];

        prompt     = prompt1     + prompt2;
        completion = completion1 + completion2;
        requests   = Replace[ usage[ "Requests" ], Except[ $$size ] :> 0 ] + 1;

        addHandlerArguments[ "Usage" -> <| "Prompt" -> prompt, "Completion" -> completion, "Requests" -> requests |> ]
    ],
    throwInternalFailure
];

logUsage[ settings_, messages_List, response_String, $$unspecified ] :=
    addHandlerArguments[
        "Usage" -> <|
            "Prompt"     -> tokenCount[ settings, messages ],
            "Completion" -> tokenCount[ settings, response ],
            "Requests"   -> 1
        |>
    ];

logUsage // endDefinition;

(* TODO: this could log usage by model since the model could technically change during a chat evaluation *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyTokenizer*)
applyTokenizer // beginDefinition;
applyTokenizer[ tokenizer_, content_String ] := tokenizer @ content;
applyTokenizer[ tokenizer_, content_? graphicsQ ] := tokenizer @ content;
applyTokenizer[ tokenizer_, content_List ] := Flatten[ applyTokenizer[ tokenizer, # ] & /@ content ];
applyTokenizer[ tokenizer_, KeyValuePattern[ "Data" -> data_ ] ] := tokenizer @ data;
applyTokenizer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageContent*)
messageContent // beginDefinition;

messageContent[ "[Cell Excised]" ] := "";
messageContent[ content_String ] := content;
messageContent[ KeyValuePattern[ "Content" -> content_ ] ] := messageContent @ content;
messageContent[ KeyValuePattern @ { "Type" -> "Text"|"Image", "Data" -> content_ } ] := messageContent @ content;

messageContent[ content_List ] :=
    With[ { s = messageContent /@ content },
        StringRiffle[ s, "\n\n" ] /; AllTrue[ s, StringQ ]
    ];

messageContent[ content_ ] := content;

messageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getCellMessageFunction*)
getCellMessageFunction // beginDefinition;
getCellMessageFunction[ as_ ] := checkedMessageFunction @ getProcessingFunction[ as, "CellToChatMessage" ];
getCellMessageFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkedMessageFunction*)
checkedMessageFunction // beginDefinition;

checkedMessageFunction[ CellToChatMessage ] :=
    CellToChatMessage;

checkedMessageFunction[ func_ ] :=
    checkedMessageFunction[ func, { ## } ] &;

checkedMessageFunction[ func_, { cell_, settings_ } ] :=
    Replace[
        func[ cell, settings ],
        {
            message_String? StringQ :> <| "Role" -> cellRole @ cell, "Content" -> message |>,
            Except[ $$validMessageResults ] :> CellToChatMessage[ cell, settings ] (* TODO: issue message here? *)
        }
    ];

checkedMessageFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCurrentRole*)
makeCurrentRole // beginDefinition;

makeCurrentRole[ as_Association? AssociationQ ] :=
    makeCurrentRole[ as, as[ "BasePrompt" ], as[ "LLMEvaluator" ] ];

makeCurrentRole[ as_, base_, name_String ] :=
    With[ { persona = GetCachedPersonaData @ name },
        makeCurrentRole[ as, base, persona ] /; AssociationQ @ persona
    ];

makeCurrentRole[ as_, base_, persona_Association ] := (
    needsBasePrompt @ base;
    needsBasePrompt @ persona;
    <| "Role" -> "System", "Content" -> buildSystemPrompt @ Association[ as, KeyDrop[ persona, { "Tools" } ] ] |>
);

makeCurrentRole[ as_, base_, _ ] := (
    needsBasePrompt @ base;
    <| "Role" -> "System", "Content" -> buildSystemPrompt @ as |>
);

makeCurrentRole // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*buildSystemPrompt*)
buildSystemPrompt // beginDefinition;

buildSystemPrompt[ as_Association ] := StringReplace[
    StringTrim @ TemplateApply[
        $promptTemplate,
        Select[
            <|
                "Pre"   -> getPrePrompt @ as,
                "Post"  -> getPostPrompt @ as,
                "Tools" -> getToolPrompt @ as,
                "Group" -> getGroupPrompt @ as,
                "Base"  -> "%%BASE_PROMPT%%"
            |>,
            StringQ
        ]
    ],
    Longest[ "\n\n".. ] -> "\n\n"
];

buildSystemPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPrePrompt*)
getPrePrompt // beginDefinition;

getPrePrompt[ as_Association ] := toPromptString @ FirstCase[
    Unevaluated @ {
        as[ "LLMEvaluator", "ChatContextPreprompt" ],
        as[ "LLMEvaluator", "Pre" ],
        as[ "LLMEvaluator", "PromptTemplate" ],
        as[ "LLMEvaluator", "Prompts" ],
        as[ "ChatContextPreprompt" ],
        as[ "Pre" ],
        as[ "PromptTemplate" ],
        as[ "Prompts" ]
    },
    expr_ :> With[ { e = expr },
        e /; MatchQ[ e, _String | _TemplateObject | { (_String|_TemplateObject) ... } ]
    ]
];

getPrePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPostPrompt*)
getPostPrompt // beginDefinition;

getPostPrompt[ as_Association ] := toPromptString @ FirstCase[
    Unevaluated @ {
        as[ "LLMEvaluator", "ChatContextPostPrompt" ],
        as[ "LLMEvaluator", "Post" ],
        as[ "ChatContextPostPrompt" ],
        as[ "Post" ]
    },
    expr_ :> With[ { e = expr }, e /; MatchQ[ e, _String | _TemplateObject ] ]
];

getPostPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolPrompt*)
getToolPrompt // beginDefinition;

getToolPrompt[ KeyValuePattern[ "ToolsEnabled" -> False ] ] := "";
getToolPrompt[ KeyValuePattern[ "Tools" -> { } | None ] ] := "";

getToolPrompt[ settings_ ] := Enclose[
    Module[ { config, string },
        config = ConfirmMatch[ makeToolConfiguration @ settings, _System`LLMConfiguration ];
        ConfirmBy[ TemplateApply[ config[ "ToolPrompt" ], toolPromptData @ config[ "Data" ] ], StringQ ]
    ],
    throwInternalFailure[ getToolPrompt @ settings, ## ] &
];

getToolPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolPromptData*)
toolPromptData // beginDefinition;

toolPromptData[ args: KeyValuePattern @ { "Tools" -> tools_List } ] :=
    Append[ args, "Tools" -> Replace[ tools, t_LLMTool :> TemplateVerbatim @ t, { 1 } ] ];

toolPromptData[ expr_ ] := expr;

toolPromptData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getGroupPrompt*)
getGroupPrompt // beginDefinition;
getGroupPrompt[ as_Association ] := getGroupPrompt[ as, as[ "ChatGroupSettings", "Prompt" ] ];
getGroupPrompt[ as_, prompt_String ] := prompt;
getGroupPrompt[ as_, _ ] := Missing[ "NotAvailable" ];
getGroupPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toPromptString*)
toPromptString // beginDefinition;

toPromptString[ expr_ ] := Enclose[
    Module[ { prompt },
        prompt = ConfirmMatch[ toPromptString0 @ expr, _String|_Missing, "PromptString" ];
        If[ StringQ @ prompt, StringTrim @ prompt, prompt ]
    ],
    throwInternalFailure
];

toPromptString // endDefinition;


toPromptString0 // beginDefinition;
toPromptString0[ string_String ] := string;
toPromptString0[ template_TemplateObject ] := With[ { string = TemplateApply @ template }, string /; StringQ @ string ];
toPromptString0[ _Missing | Automatic | Inherited | None ] := Missing[ ];

toPromptString0[ prompts_List ] :=
    With[ { strings = DeleteMissing[ toPromptString0 /@ prompts ] },
        StringRiffle[
            DeleteCases[ StringTrim[ strings, ("\r"|"\n").. ], "" ],
            "\n\n"
        ] /; MatchQ[ strings, { ___String } ]
    ];

toPromptString0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCurrentCellMessage*)
makeCurrentCellMessage // beginDefinition;

makeCurrentCellMessage[ settings_, { cells___, cell0_ } ] := Enclose[
    Module[ { modifiers, cell, role, content },
        { modifiers, cell } = ConfirmMatch[ extractModifiers @ cell0, { _, _ }, "Modifiers" ];
        role = ConfirmBy[ cellRole @ cell, StringQ, "CellRole" ];

        content = ConfirmBy[
            Block[ { $CurrentCell = True }, makeMessageContent[ cell, role, settings ] ],
            validContentQ,
            "Content"
        ];

        Flatten @ {
            expandModifierMessages[ settings, modifiers, { cells }, cell ],
            <| "Role" -> role, "Content" -> content |>
        }
    ],
    throwInternalFailure
];

makeCurrentCellMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeMessageContent*)
makeMessageContent // beginDefinition;

makeMessageContent[ cell_Cell, role_String, settings_ ] /; $multimodalMessages := Enclose[
    Module[ { string, roles },
        string = ConfirmBy[ cellToString @ cell, StringQ, "CellToString" ];
        roles = ConfirmMatch[ allowedMultimodalRoles @ settings, All | { ___String }, "Roles" ];
        If[ MatchQ[ roles, All | { ___, role, ___ } ],
            expandMultimodalString @ string,
            string
        ]
    ],
    throwInternalFailure
];

makeMessageContent[ cell_Cell, role_, settings_ ] :=
    cellToString @ cell;

makeMessageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*allowedMultimodalRoles*)
allowedMultimodalRoles // beginDefinition;
allowedMultimodalRoles[ settings_ ] := allowedMultimodalRoles0 @ toModelName @ settings[ "Model" ];
allowedMultimodalRoles // endDefinition;


allowedMultimodalRoles0 // beginDefinition;

allowedMultimodalRoles0[ model_String ] := allowedMultimodalRoles0[ model ] =
    If[ StringContainsQ[ model, WordBoundary~~"gpt-4o"~~WordBoundary ],
        { "User" },
        All
    ];

allowedMultimodalRoles0[ _Missing ] := All;

allowedMultimodalRoles0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandMultimodalStrings*)
expandMultimodalString // beginDefinition;

expandMultimodalString[ string_String ] /; $multimodalMessages := Enclose[
    Module[ { split, joined, typed },

        split = Flatten @ StringSplit[
            string,
            {
                md: Shortest[ "MarkdownImageBox[\"" ~~ link: ("![" ~~ __ ~~ "](" ~~ uri__ ~~ ")") ~~ "\"]" ] /;
                    expressionURIQ @ uri :> {
                        md,
                        ConfirmBy[ GetExpressionURI[ link, Tooltip -> False ], graphicsQ, "MarkdownImageBox" ]
                    },
                md: Shortest[ link: ("![" ~~ __ ~~ "](" ~~ uri__ ~~ ")") ] /; graphicsURIQ @ uri :> {
                    md,
                    ConfirmBy[ GetExpressionURI[ link, Tooltip -> False ], graphicsQ, "GetExpressionURI" ]
                }
            }
        ];

        joined = Flatten @ Replace[ SplitBy[ split, StringQ ], s: { _String, ___ } :> StringJoin @ s, { 1 } ];
        typed  = ConfirmMatch[ inferMultimodalTypes @ joined, { ___? AssociationQ } | { ___? StringQ }, "Typed" ];
        Replace[ typed, { msg_String } :> msg ]
    ],
    throwInternalFailure[ expandMultimodalString @ string, ## ] &
];

expandMultimodalString[ string_String ] :=
    string;

expandMultimodalString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*inferMultimodalTypes*)
inferMultimodalTypes // beginDefinition;

inferMultimodalTypes[ content_List ] := Enclose[
    Module[ { typed },
        typed = ConfirmMatch[ inferMultimodalTypes0 @ content, { ___? AssociationQ }, "Typed" ];
        If[ MatchQ[ typed, { KeyValuePattern[ "Type" -> "Text" ] .. } ],
            ConfirmMatch[ Lookup[ typed, "Data" ], { __String }, "TextData" ],
            typed
        ]
    ],
    throwInternalFailure
];

inferMultimodalTypes // endDefinition;

(* TODO: add a way to control image detail and insert "Detail" -> "..." here when appropriate: *)
inferMultimodalTypes0 // beginDefinition;
inferMultimodalTypes0[ content_List        ] := inferMultimodalTypes0 /@ content;
inferMultimodalTypes0[ content_String      ] := <| "Type" -> "Text" , "Data" -> content |>;
inferMultimodalTypes0[ content_? graphicsQ ] := <| "Type" -> "Image", "Data" -> ensureCompatibleImage @ content |>;
inferMultimodalTypes0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*ensureCompatibleImage*)
ensureCompatibleImage // beginDefinition;
ensureCompatibleImage[ img_RawBoxes ] := rasterize @ img; (* Workaround for 446030 *)
ensureCompatibleImage[ img_ ] /; $useRasterizationCompatibility && ! Image`PossibleImageQ @ img := rasterize @ img;
ensureCompatibleImage[ img_ ] := img;
ensureCompatibleImage // endDefinition;


$useRasterizationCompatibility := Enclose[
    $useRasterizationCompatibility =
        Or[ $CloudEvaluation,
            ! PacletNewerQ[ ConfirmBy[ PacletObject[ "ServiceConnection_OpenAI" ], PacletObjectQ ], "13.3.18" ]
        ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expressionURIQ*)
expressionURIQ // beginDefinition;
expressionURIQ[ uri_String ] := KeyExistsQ[ $attachments, StringDelete[ uri, StartOfString ~~ __ ~~ "://" ] ];
expressionURIQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*graphicsURIQ*)
graphicsURIQ // beginDefinition;

graphicsURIQ[ uri_String ] := MatchQ[
    Lookup[ $attachments, StringDelete[ uri, StartOfString ~~ __ ~~ "://" ] ],
    HoldComplete[ e_ ] /; graphicsQ @ Unevaluated @ e
];

graphicsURIQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellToString*)
cellToString // beginDefinition;

cellToString[ cell_Cell ] := CellToString[
    cell,
    "ContentTypes"        -> If[ TrueQ @ $multimodalMessages, { "Text", "Image" }, Automatic ],
    "MaxCellStringLength" -> $cellStringBudget
];

cellToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validContentQ*)
validContentQ[ string_String ] := StringQ @ string;
validContentQ[ content_List ] := AllTrue[ content, validContentPartQ ];
validContentQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validContentPartQ*)
validContentPartQ[ _String? StringQ ] := True;
validContentPartQ[ _URL | _File     ] := True;
validContentPartQ[ _? graphicsQ     ] := True;
validContentPartQ[ KeyValuePattern[ "Type" -> _String ] ] := True;
validContentPartQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCellMessage*)
makeCellMessage // beginDefinition;

makeCellMessage[ cell_Cell, settings_ ] :=
    With[ { role = cellRole @ cell },
        <|
            "Role"    -> role,
            "Content" -> makeMessageContent[ cell, role, settings  ]
        |>
    ];

makeCellMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellRole*)
cellRole // beginDefinition;

cellRole[ cell_Cell ] :=
    With[ { role = $cellRole }, role /; StringQ @ role ];

cellRole[ Cell[
    __,
    TaggingRules -> KeyValuePattern[ "ChatNotebookSettings" -> KeyValuePattern[ "Role" -> role_String ] ],
    ___
] ] := role;

cellRole[ Cell[ _, styles__String, OptionsPattern[ ] ] ] :=
    FirstCase[ { styles }, style_ :> With[ { role = $styleRoles @ style }, role /; StringQ @ role ], "User" ];

cellRole[ Cell[ _, OptionsPattern[ ] ] ] := "User";

cellRole // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mergeMessageData*)
mergeMessageData // beginDefinition;

mergeMessageData[ { sys: KeyValuePattern[ "Role" -> "System" ], rest___ } ] :=
    Flatten @ { sys, mergeMessageData0 @ { rest } };

mergeMessageData[ messages_List ] :=
    mergeMessageData0 @ messages;

mergeMessageData // endDefinition;

mergeMessageData0 // beginDefinition;
mergeMessageData0[ messages_List ] := Flatten[ mergeMessages /@ SplitBy[ messages, Lookup[ "Role" ] ] ];
mergeMessageData0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mergeMessages*)
mergeMessages // beginDefinition;

mergeMessages[ { } ] := Nothing;
mergeMessages[ { message_ } ] := message;
mergeMessages[ messages: { first_Association, __Association } ] := Enclose[
    Module[ { role, content, merged },
        role = ConfirmBy[ Lookup[ first, "Role" ], StringQ, "Role" ];

        content = Replace[
            Flatten @ Lookup[ messages, "Content" ],
            KeyValuePattern @ { "Type" -> "Text", "Data" -> s_String } :> s,
            { 1 }
        ];

        merged = ConfirmMatch[ mergeCodeBlocks @ content, { (_String|_Association)... }, "Merged" ];

        <| "Role" -> role, "Content" -> merged |>
    ],
    throwInternalFailure
];

mergeMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeCodeBlocks*)
mergeCodeBlocks // beginDefinition;

mergeCodeBlocks[ content_List ] := Enclose[
    Module[ { split, joined },
        split = SplitBy[ content, StringQ ];
        joined = Replace[ split, s: { __String } :> mergeCodeBlocks @ StringRiffle[ s, "\n\n" ], { 1 } ];
        Flatten @ joined
    ],
    throwInternalFailure
];

mergeCodeBlocks[ string0_String ] := Enclose[
    Catch @ Module[ { string, split, strings },
        string = StringReplace[ string0, "```\n\n"~~("\n"..)~~"```" :> "```\n\n```" ];

        split = StringSplit[
            string,
            Shortest[ "```" ~~ lang: Except[ WhitespaceCharacter ]... ~~ "\n" ~~ code__ ~~ "\n```" ] :>
                codeBlock[ StringTrim @ lang, StringTrim @ code ]
        ];

        strings = Replace[
            FixedPoint[
                Replace[
                    { a___, codeBlock[ lang_, code1_ ], "\n\n", codeBlock[ lang_, code2_ ], b___ } :>
                        { a, codeBlock[ lang, code1<>"\n\n"<>code2 ], b }
                ],
                split
            ],
            codeBlock[ lang_, code_ ] :> "```"<>lang<>"\n"<>code<>"\n```",
            { 1 }
        ];

        ConfirmAssert[ AllTrue[ strings, StringQ ], "StringCheck" ];

        mergeCodeBlocks[ string0 ] = StringJoin @ strings
    ],
    throwInternalFailure
];

mergeCodeBlocks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt Repository Integration*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*promptFunctionCellQ*)
promptFunctionCellQ[ Cell[ boxes_, ___, "ChatInput", ___ ] ] := inlineFunctionReferenceBoxesQ @ boxes;
promptFunctionCellQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*inlineFunctionReferenceBoxesQ*)
inlineFunctionReferenceBoxesQ[ (BoxData|TextData)[ boxes_ ] ] := inlineFunctionReferenceBoxesQ @ boxes;
inlineFunctionReferenceBoxesQ[ { box_, ___ } ] := inlineFunctionReferenceBoxesQ @ box;
inlineFunctionReferenceBoxesQ[ Cell[ __, TaggingRules -> tags_, ___ ] ] := inlineFunctionReferenceBoxesQ @ tags;
inlineFunctionReferenceBoxesQ[ KeyValuePattern[ "PromptFunctionName" -> _String ] ] := True;
inlineFunctionReferenceBoxesQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePromptFunctionMessages*)
makePromptFunctionMessages // beginDefinition;

(* cSpell: ignore nodef *)
makePromptFunctionMessages[ settings_, { cells___, cell0_ } ] := Enclose[
    Module[ { modifiers, cell, name, arguments, filled, prompt, string },
        (* Ensure Wolfram/LLMFunctions is installed and loaded before calling System`LLMPrompt[..] *)
        initTools[ ];

        { modifiers, cell } = ConfirmMatch[ extractModifiers @ cell0, { _, _ }, "Modifiers" ];
        name      = ConfirmBy[ extractPromptFunctionName @ cell, StringQ, "PromptFunctionName" ];
        arguments = ConfirmMatch[ extractPromptArguments @ cell, { ___String }, "PromptArguments" ];
        filled    = ConfirmMatch[ replaceArgumentTokens[ name, arguments, { cells, cell } ], { ___String }, "Tokens" ];
        prompt    = ConfirmMatch[ Quiet[ getLLMPrompt @ name, OptionValue::nodef ], _TemplateObject, "LLMPrompt" ];
        string    = ConfirmBy[ Quiet[ TemplateApply[ prompt, filled ], OptionValue::nodef ], StringQ, "TemplateApply" ];

        (* FIXME: handle named slots *)
        Flatten @ {
            expandModifierMessages[ settings, modifiers, { cells }, cell ],
            <| "Role" -> "User", "Content" -> string |>
        }
    ],
    throwInternalFailure[ makePromptFunctionMessages[ settings, { cells, cell0 } ], ## ] &
];

makePromptFunctionMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractPromptFunctionName*)
extractPromptFunctionName // beginDefinition;
extractPromptFunctionName[ Cell[ boxes_, ___, "ChatInput", ___ ] ] := extractPromptFunctionName @ boxes;
extractPromptFunctionName[ (BoxData|TextData)[ boxes_ ] ] := extractPromptFunctionName @ boxes;
extractPromptFunctionName[ { box_, ___ } ] := extractPromptFunctionName @ box;
extractPromptFunctionName[ Cell[ __, TaggingRules -> KeyValuePattern[ "PromptFunctionName" -> name_ ], ___ ] ] := name;
extractPromptFunctionName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Modifiers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandModifierMessages*)
expandModifierMessages // beginDefinition;

expandModifierMessages[ settings_, modifiers_List, history_, cell_ ] :=
    expandModifierMessage[ settings, #, history, cell ] & /@ modifiers;

expandModifierMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandModifierMessage*)
expandModifierMessage // beginDefinition;

expandModifierMessage[ settings_, modifier_, { cells___ }, cell_ ] := Enclose[
    Module[ { name, arguments, filled, prompt, string, role },
        name      = ConfirmBy[ modifier[ "PromptModifierName" ], StringQ, "ModifierName" ];
        arguments = ConfirmMatch[ modifier[ "PromptArguments" ], { ___String }, "Arguments" ];
        filled    = ConfirmMatch[ replaceArgumentTokens[ name, arguments, { cells, cell } ], { ___String }, "Tokens" ];
        prompt    = ConfirmMatch[ Quiet[ getLLMPrompt @ name, OptionValue::nodef ], _TemplateObject, "LLMPrompt" ];
        string    = ConfirmBy[ Quiet[ TemplateApply[ prompt, filled ], OptionValue::nodef ], StringQ, "TemplateApply" ];
        role      = ConfirmBy[ modifierMessageRole @ settings, StringQ, "Role" ];
        <| "Role" -> role, "Content" -> string |>
    ],
    throwInternalFailure[ expandModifierMessage[ modifier, { cells }, cell ], ## ] &
];

expandModifierMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modifierMessageRole*)
modifierMessageRole[ KeyValuePattern[ "Model" -> model_String ] ] :=
    If[ TrueQ @ StringStartsQ[ toModelName @ model, "gpt-3.5", IgnoreCase -> True ],
        "User",
        "System"
    ];

modifierMessageRole[ ___ ] := "System";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractModifiers*)
extractModifiers // beginDefinition;

extractModifiers[ cell: Cell[ _String, ___ ] ] := { { }, cell };
extractModifiers[ cell: Cell[ TextData[ _String ], ___ ] ] := { { }, cell };

extractModifiers[ Cell[ TextData[ text: { ___, $$inlineModifierCell, ___ } ], a___ ] ] := {
    Cases[ text, cell: $$inlineModifierCell :> extractModifier @ cell ],
    Cell[ TextData @ DeleteCases[ text, $$inlineModifierCell ], a ]
};

extractModifiers[ Cell[ TextData[ modifier: $$inlineModifierCell ], a___ ] ] := {
    { extractModifier @ modifier },
    Cell[ "", a ]
};

extractModifiers[ cell_Cell ] := { { }, cell };

extractModifiers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractModifier*)
extractModifier // beginDefinition;
extractModifier[ Cell[ BoxData[ cell: Cell[ _, "InlineModifierReference", ___ ] ], ___ ] ] := extractModifier @ cell;
extractModifier[ Cell[ __, TaggingRules -> tags_, ___ ] ] := extractModifier @ tags;
extractModifier[ as: KeyValuePattern @ { "PromptModifierName" -> _String, "PromptArguments" -> _List } ] := as;
extractModifier // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Common*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getLLMPrompt*)
getLLMPrompt // beginDefinition;

getLLMPrompt[ name_String ] :=
    getLLMPrompt[
        name,
        Quiet[
            Check[
                Block[ { PrintTemporary }, getLLMPrompt0 @ name ],
                (* TODO: a dialog might be better since a message could be missed in the messages window *)
                throwFailure[ "ResourceNotFound", name ],
                ResourceObject::notfname
            ],
            { ResourceObject::notfname, OptionValue::nodef }
        ]
    ];

getLLMPrompt[ name_String, prompt: _TemplateObject|_String ] := prompt;

getLLMPrompt // endDefinition;


getLLMPrompt0 // beginDefinition;
getLLMPrompt0[ name_ ] := With[ { t = Quiet @ System`LLMPrompt[ "Prompt: "<>name ] }, t /; MatchQ[ t, _TemplateObject ] ];
getLLMPrompt0[ name_ ] := System`LLMPrompt @ name;
getLLMPrompt0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractPromptArguments*)
extractPromptArguments // beginDefinition;
extractPromptArguments[ Cell[ boxes_, ___, "ChatInput", ___ ] ] := extractPromptArguments @ boxes;
extractPromptArguments[ (BoxData|TextData)[ boxes_ ] ] := extractPromptArguments @ boxes;
extractPromptArguments[ { box_, ___ } ] := extractPromptArguments @ box;
extractPromptArguments[ Cell[ __, TaggingRules -> KeyValuePattern[ "PromptArguments" -> args_ ], ___ ] ] := args;
extractPromptArguments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*replaceArgumentTokens*)
replaceArgumentTokens // beginDefinition;

replaceArgumentTokens[ name_String, args_List, { cells___, cell_ } ] :=
    Module[ { tokens, rules, arguments },
        tokens = Cases[ Union @ args, $$promptArgumentToken ];
        rules = AssociationMap[ argumentTokenToString[ #, name, { cells, cell } ] &, tokens ];
        arguments = Replace[ args, rules, { 1 } ];
        arguments
    ];

replaceArgumentTokens // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*argumentTokenToString*)
argumentTokenToString // beginDefinition;

argumentTokenToString[
    ">",
    name_,
    {
        ___,
        Cell[
            TextData @ { ___, Cell[ __, TaggingRules -> KeyValuePattern[ "PromptFunctionName" -> name_ ], ___ ], a___ },
            "ChatInput",
            b___
        ]
    }
] := cellToString @ Cell[ TextData @ { a }, "ChatInput", b ];

argumentTokenToString[
    ">",
    name_,
    {
        ___,
        Cell[
            TextData @ Cell[ __, TaggingRules -> KeyValuePattern[ "PromptFunctionName" -> name_ ], ___ ],
            "ChatInput",
            ___
        ]
    }
] := "";

argumentTokenToString[ "^", name_, { ___, cell_, _ } ] := cellToString @ cell;

argumentTokenToString[ "^^", name_, { history___, _ } ] := StringRiffle[ cellToString /@ { history }, "\n\n" ];

argumentTokenToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tokenization*)
$tokenizer := $gpt2Tokenizer;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getTokenizerName*)
getTokenizerName // beginDefinition;

getTokenizerName[ KeyValuePattern[ "TokenizerName"|"Tokenizer" -> name_String ] ] :=
    tokenizerName @ name;

getTokenizerName[ KeyValuePattern[ "Tokenizer" -> Except[ $$unspecified ] ] ] :=
    "Custom";

getTokenizerName[ KeyValuePattern[ "Model" -> model_ ] ] :=
    With[ { name = tokenizerName @ toModelName @ model },
        If[ MemberQ[ $cachedTokenizerNames, name ],
            name,
            $fallbackTokenizer
        ]
    ];

getTokenizerName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getTokenizer*)
getTokenizer // beginDefinition;
getTokenizer[ KeyValuePattern[ "Tokenizer" -> tokenizer: Except[ $$unspecified ] ] ] := tokenizer;
getTokenizer[ KeyValuePattern[ "TokenizerName" -> name_String ] ] := cachedTokenizer @ name;
getTokenizer[ KeyValuePattern[ "Model" -> model_ ] ] := cachedTokenizer @ toModelName @ model;
getTokenizer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cachedTokenizer*)
cachedTokenizer // beginDefinition;

cachedTokenizer[ All ] :=
    AssociationMap[ cachedTokenizer, $cachedTokenizerNames ];

cachedTokenizer[ id_String ] :=
    With[ { tokenizer = $cachedTokenizers[ tokenizerName @ toModelName @ id ] },
        tokenizer /; ! MatchQ[ tokenizer, $$unspecified ]
    ];

cachedTokenizer[ id_String ] := Enclose[
    Module[ { name, tokenizer },
        name      = ConfirmBy[ tokenizerName @ toModelName @ id, StringQ, "Name" ];
        tokenizer = findTokenizer @ name;
        If[ MissingQ @ tokenizer,
            (* Fallback to the GPT-2 tokenizer: *)
            tokenizer = ConfirmMatch[ $genericTokenizer, Except[ $$unspecified ], "GPT2Tokenizer" ];
            If[ TrueQ @ Wolfram`ChatbookInternal`$BuildingMX,
                tokenizer, (* Avoid caching fallback values into MX definitions *)
                cacheTokenizer[ name, tokenizer ]
            ],
            cacheTokenizer[ name, ConfirmMatch[ tokenizer, Except[ $$unspecified ], "Tokenizer" ] ]
        ]
    ],
    throwInternalFailure
];

cachedTokenizer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*cacheTokenizer*)
cacheTokenizer // beginDefinition;

cacheTokenizer[ name_String, tokenizer: Except[ $$unspecified ] ] := (
    $cachedTokenizerNames = Union[ $cachedTokenizerNames, { name } ];
    $cachedTokenizers[ name ] = tokenizer
);

cacheTokenizer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*findTokenizer*)
findTokenizer // beginDefinition;

findTokenizer[ model_String ] := Enclose[
    Quiet @ Module[ { name, tokenizer },
        initTools[ ];
        Quiet @ Needs[ "Wolfram`LLMFunctions`Utilities`Tokenization`" -> None ];
        name      = ConfirmBy[ tokens`FindTokenizer @ model, StringQ, "Name" ];
        tokenizer = ConfirmMatch[ tokens`LLMTokenizer[ Method -> name ], Except[ _tokens`LLMTokenizer ], "Tokenizer" ];
        ConfirmMatch[ tokenizer[ "test" ], _List, "TokenizerTest" ];
        tokenizer
    ],
    Missing[ "NotFound" ] &
];

findTokenizer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Pre-cached small tokenizer functions*)
$cachedTokenizers[ "chat-bison"   ] = ToCharacterCode[ #, "UTF8" ] &;
$cachedTokenizers[ "gpt-4-vision" ] = If[ graphicsQ @ #, gpt4ImageTokenizer, cachedTokenizer[ "gpt-4" ] ][ # ] &;
$cachedTokenizers[ "claude-3"     ] = If[ graphicsQ @ #, claude3ImageTokenizer, cachedTokenizer[ "claude" ] ][ # ] &;
$cachedTokenizers[ "generic"      ] = If[ graphicsQ @ #, { }, $gpt2Tokenizer @ # ] &;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenizerName*)
tokenizerName // beginDefinition;

tokenizerName[ "gpt-4-turbo-preview" ] = "gpt-4";
tokenizerName[ "gpt-4-turbo"         ] = "gpt-4-vision";
tokenizerName[ "gpt-4o"              ] = "gpt-4-vision";

tokenizerName[ name_String ] :=
    SelectFirst[
        ReverseSortBy[ $cachedTokenizerNames, StringLength ],
        StringContainsQ[ name, #, IgnoreCase -> True ] &,
        name
    ];

tokenizerName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GPT-4 Vision Image Tokenizer *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizeMultimodalImage*)
resizeMultimodalImage // beginDefinition;

resizeMultimodalImage[ image0_ ] := Enclose[
    Module[ { image, dimensions, max, small, resized },
        image = ConfirmBy[ If[ image2DQ @ image0, image0, rasterize @ image0 ], image2DQ, "Image" ];
        dimensions = ConfirmMatch[ ImageDimensions @ image, { _Integer, _Integer }, "Dimensions" ];
        max = ConfirmMatch[ $maxMMImageSize, _Integer? Positive, "MaxSize" ];
        small = ConfirmMatch[ AllTrue[ dimensions, LessThan @ max ], True|False, "Small" ];
        resized = ConfirmBy[ If[ small, image, ImageResize[ image, { UpTo @ max, UpTo @ max } ] ], ImageQ, "Resized" ];
        resizeMultimodalImage[ image0 ] = resized
    ],
    throwInternalFailure[ resizeMultimodalImage @ image0, ## ] &
];

resizeMultimodalImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*gpt4ImageTokenizer*)
gpt4ImageTokenizer // beginDefinition;
gpt4ImageTokenizer[ image_ ] := gpt4ImageTokenizer[ image, gpt4ImageTokenCount @ image ];
gpt4ImageTokenizer[ image_, count: $$size ] := ConstantArray[ 0, count ]; (* TODO: just a placeholder for counting *)
gpt4ImageTokenizer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*claude3ImageTokenizer*)
claude3ImageTokenizer // beginDefinition;
claude3ImageTokenizer[ image_ ] := claude3ImageTokenizer[ image, claude3ImageTokenCount @ image ];
claude3ImageTokenizer[ image_, count: $$size ] := ConstantArray[ 0, count ]; (* TODO: just a placeholder for counting *)
claude3ImageTokenizer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*gpt4ImageTokenCount*)
gpt4ImageTokenCount // beginDefinition;
gpt4ImageTokenCount[ image_ ] := gpt4ImageTokenCount[ image, gpt4ImageTokenCount0 @ image ];
gpt4ImageTokenCount[ image_, count: $$size ] := gpt4ImageTokenCount[ image ] = count;
gpt4ImageTokenCount // endDefinition;


gpt4ImageTokenCount0 // beginDefinition;
gpt4ImageTokenCount0[ image_ ] := gpt4ImageTokenCount0[ image, resizeMultimodalImage @ image ];
gpt4ImageTokenCount0[ image_, resized_Image ] := gpt4ImageTokenCount0[ image, ImageDimensions @ resized ];
gpt4ImageTokenCount0[ image_, { w_, h_ } ] := gpt4ImageTokenCount0[ w, h ];
gpt4ImageTokenCount0[ w_Integer, h_Integer ] := 85 + 170 * Ceiling[ h / 512 ] * Ceiling[ w / 512 ];
gpt4ImageTokenCount0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*claude3ImageTokenCount*)
claude3ImageTokenCount // beginDefinition;
claude3ImageTokenCount[ image_ ] := claude3ImageTokenCount[ image, claude3ImageTokenCount0 @ image ];
claude3ImageTokenCount[ image_, count: $$size ] := claude3ImageTokenCount[ image ] = count;
claude3ImageTokenCount // endDefinition;


claude3ImageTokenCount0 // beginDefinition;
claude3ImageTokenCount0[ image_ ] := claude3ImageTokenCount0[ image, resizeMultimodalImage @ image ];
claude3ImageTokenCount0[ image_, resized_Image ] := claude3ImageTokenCount0[ image, ImageDimensions @ resized ];
claude3ImageTokenCount0[ image_, { w_, h_ } ] := claude3ImageTokenCount0[ w, h ];
claude3ImageTokenCount0[ w_Integer, h_Integer ] := Ceiling[ (w * h) / 750 ];
claude3ImageTokenCount0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fallback Tokenizer*)
$gpt2Tokenizer := $gpt2Tokenizer = gpt2Tokenizer[ ];

(* https://resources.wolframcloud.com/FunctionRepository/resources/GPTTokenizer *)
importResourceFunction[ gpt2Tokenizer, "GPTTokenizer" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    cachedTokenizer[ All ];
    $gpt2Tokenizer;
    (* This is only needed to generate $gpt2Tokenizer once, so it can be removed to reduce MX file size: *)
    Remove[ "Wolfram`Chatbook`ResourceFunctions`GPTTokenizer`GPTTokenizer" ];
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
