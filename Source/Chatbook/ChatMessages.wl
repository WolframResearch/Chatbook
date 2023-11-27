(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatMessages`" ];

(* cSpell: ignore nodef *)

(* :!CodeAnalysis::BeginBlock:: *)

Wolfram`Chatbook`CellToChatMessage;

`$chatDataTag;
`$initialCellStringBudget;
`$multimodalMessages;
`$tokenBudget;
`$tokenPressure;
`cachedTokenizer;
`constructMessages;
`expandMultimodalString;
`getTokenizer;
`resizeMultimodalImage;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Actions`"          ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`FrontEnd`"         ];
Needs[ "Wolfram`Chatbook`Handlers`"         ];
Needs[ "Wolfram`Chatbook`InlineReferences`" ];
Needs[ "Wolfram`Chatbook`Models`"           ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`Prompting`"        ];
Needs[ "Wolfram`Chatbook`Serialization`"    ];
Needs[ "Wolfram`Chatbook`Settings`"         ];
Needs[ "Wolfram`Chatbook`Tools`"            ];
Needs[ "Wolfram`Chatbook`Utils`"            ];

$ContextAliases[ "tokens`" ] = "Wolfram`LLMFunctions`Utilities`Tokenization`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxMMImageSize          = 512;
$multimodalMessages      = False;
$tokenBudget             = 2^13;
$tokenPressure           = 0.0;
$reservedTokens          = 500; (* TODO: determine this at submit time *)
$cellStringBudget        = Automatic;
$initialCellStringBudget = $defaultMaxCellStringLength;
$$validMessageResult     = _Association? AssociationQ | _Missing | Nothing;
$$validMessageResults    = $$validMessageResult | { $$validMessageResult ... };

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
                    makeCellMessage @ cell,
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
        prompted  = addPrompts[ settings, messages0 ];
        messages  = prompted /. s_String :> RuleCondition @ StringReplace[ s, "%%BASE_PROMPT%%" -> $basePrompt ];
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

addPrompts[ settings_Association, messages_List ] :=
    addPrompts[ assembleCustomPrompt @ settings, messages ];

addPrompts[ None, messages_List ] :=
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
    throwInternalFailure[ assembleCustomPrompt[ settings, templated ], ## ] &
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
            $multimodalMessages = TrueQ @ settings[ "Multimodal" ],
            $tokenBudget        = settings[ "MaxContextTokens" ],
            $tokenPressure      = 0.0
        },
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
        $initialCellStringBudget = Replace[
            settings[ "MaxCellStringLength" ],
            Except[ $$size ] -> $defaultMaxCellStringLength
        ];

        toMessage = Function @ With[
            { msg = toMessage0[ #1, <| #2, "TokenBudget" -> $tokenBudget, "TokenPressure" -> $tokenPressure |> ] },
            tokenCheckedMessage[ settings, msg ]
        ];

        message = ConfirmMatch[ toMessage[ cell, settings ], $$validMessageResults, "Message" ];

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

cutMessageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenCount*)
tokenCount // beginDefinition;

tokenCount[ as_Association, message_ ] := Enclose[
    Module[ { tokenizer, content },
        tokenizer = getTokenizer @ as;
        content = ConfirmBy[ messageContent @ message, validContentQ, "Content" ];
        Length @ ConfirmMatch[ applyTokenizer[ tokenizer, content ], _List, "TokenCount" ]
    ],
    throwInternalFailure[ tokenCount[ as, message ], ## ] &
];

tokenCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyTokenizer*)
applyTokenizer // beginDefinition;
applyTokenizer[ tokenizer_, content_String ] := tokenizer @ content;
applyTokenizer[ tokenizer_, content_? graphicsQ ] := tokenizer @ content;
applyTokenizer[ tokenizer_, content_List ] := Flatten[ tokenizer /@ content ];
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

makeCurrentRole[ as_, None, _ ] :=
    Missing[ ];

makeCurrentRole[ as_, role_String, _ ] :=
    <| "Role" -> "System", "Content" -> role |>;

makeCurrentRole[ as_, Automatic|Inherited|_Missing, name_String ] :=
    With[ { prompt = namedRolePrompt @ name },
        <| "Role" -> "System", "Content" -> prompt |> /; StringQ @ prompt
    ];

makeCurrentRole[ as_, _, KeyValuePattern[ "BasePrompt" -> None ] ] := (
    needsBasePrompt @ None;
    Missing[ ]
);

makeCurrentRole[ as_, base_, eval_Association ] := (
    needsBasePrompt @ base;
    needsBasePrompt @ eval;
    <| "Role" -> "System", "Content" -> buildSystemPrompt @ Association[ as, KeyDrop[ eval, { "Tools" } ] ] |>
);

makeCurrentRole[ as_, base_, _ ] := (
    needsBasePrompt @ base;
    <| "Role" -> "System", "Content" -> buildSystemPrompt @ as |>
);

makeCurrentRole // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*namedRolePrompt*)
namedRolePrompt // ClearAll;

namedRolePrompt[ name_String ] := Enclose[
    Catch @ Module[ { data, pre, post, params },
        data   = ConfirmBy[ GetCachedPersonaData @ name, AssociationQ, "GetCachedPersonaData" ];
        pre    = Lookup[ data, "Pre", TemplateApply @ Lookup[ data, "PromptTemplate" ] ];
        post   = Lookup[ data, "Post" ];
        params = Select[ <| "Pre" -> pre, "Post" -> post |>, StringQ ];

        If[ params === <| |>,
            Missing[ "NotAvailable" ],
            ConfirmBy[ TemplateApply[ $promptTemplate, params ], StringQ, "TemplateApply" ]
        ]
    ],
    throwInternalFailure[ namedRolePrompt @ name, ## ] &
];

namedRolePrompt[ ___ ] := Missing[ "NotAvailable" ];

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
        as[ "PromptTemplate" ]
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
toPromptString[ string_String ] := string;
toPromptString[ template_TemplateObject ] := With[ { string = TemplateApply @ template }, string /; StringQ @ string ];
toPromptString[ _Missing | Automatic | Inherited | None ] := Missing[ ];

toPromptString[ prompts_List ] :=
    With[ { strings = DeleteMissing[ toPromptString /@ prompts ] },
        StringRiffle[ prompts, "\n\n" ] /; MatchQ[ strings, { ___String } ]
    ];

toPromptString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCurrentCellMessage*)
makeCurrentCellMessage // beginDefinition;

makeCurrentCellMessage[ settings_, { cells___, cell0_ } ] := Enclose[
    Module[ { modifiers, cell, role, content },
        { modifiers, cell } = ConfirmMatch[ extractModifiers @ cell0, { _, _ }, "Modifiers" ];
        role = ConfirmBy[ cellRole @ cell, StringQ, "CellRole" ];
        content = ConfirmBy[ Block[ { $CurrentCell = True }, makeMessageContent @ cell ], validContentQ, "Content" ];
        Flatten @ {
            expandModifierMessages[ settings, modifiers, { cells }, cell ],
            <| "Role" -> role, "Content" -> content |>
        }
    ],
    throwInternalFailure[ makeCurrentCellMessage[ settings, { cells, cell0 } ], ## ] &
];

makeCurrentCellMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeMessageContent*)
makeMessageContent // beginDefinition;

makeMessageContent[ cell_Cell ] /; $multimodalMessages := Enclose[
    Module[ { string, split, joined },
        string = ConfirmBy[ cellToString @ cell, StringQ, "CellToString" ];
        expandMultimodalString @ string
    ],
    throwInternalFailure[ makeMessageContent @ cell, ## ] &
];

makeMessageContent[ cell_Cell ] :=
    cellToString @ cell;

makeMessageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandMultimodalStrings*)
expandMultimodalString // beginDefinition;

expandMultimodalString[ string_String ] /; $multimodalMessages := Enclose[
    Module[ { split, joined },

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

        joined = FixedPoint[ Replace[ { a___, b_String, c_String, d___ } :> { a, b<>c, d } ], split ];
        Replace[ joined, { msg_String } :> msg ]
    ],
    throwInternalFailure[ expandMultimodalString @ string, ## ] &
];

expandMultimodalString[ string_String ] :=
    string;

expandMultimodalString // endDefinition;

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
cellToString[ cell_Cell ] := CellToString[ cell, "MaxCellStringLength" -> $cellStringBudget ];
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
makeCellMessage[ cell_Cell ] := <| "Role" -> cellRole @ cell, "Content" -> makeMessageContent @ cell |>;
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
mergeMessages[ messages: { first_Association, __Association } ] :=
    Module[ { role, content, stitch },
        role    = Lookup[ first, "Role" ];
        content = Flatten @ Lookup[ messages, "Content" ];
        stitch  = StringDelete[ #1, "```\n\n```" ] &;

        If[ AllTrue[ content, StringQ ],
            <|
                "Role"    -> role,
                "Content" -> stitch @ StringRiffle[ content, "\n\n" ]
            |>,
            <|
                "Role" -> role,
                "Content" -> FixedPoint[
                    Replace @ {
                        { a___, b_String, c_String, d___ } :> { a, stitch[ b<>"\n\n"<>c ], d },
                        { a___, b_String, { c_String, d___ }, e___ } :> { a, { stitch[ b<>"\n\n"<>c ], d }, e },
                        { a___, { b___, c_String }, d_String, e___ } :> { a, { b, stitch[ c<>"\n\n"<>d ] }, e }
                    },
                    content
                ]
            |>
        ]
    ];

mergeMessages // endDefinition;

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
$tokenizer := gpt2Tokenizer;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getTokenizer*)
getTokenizer // beginDefinition;
getTokenizer[ KeyValuePattern[ "Tokenizer" -> tokenizer: Except[ $$unspecified ] ] ] := tokenizer;
getTokenizer[ KeyValuePattern[ "Model" -> model_ ] ] := getTokenizer @ model;
getTokenizer[ model_ ] := cachedTokenizer @ toModelName @ model;
getTokenizer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cachedTokenizer*)
cachedTokenizer // beginDefinition;
cachedTokenizer[ All ] := AssociationMap[ cachedTokenizer, $cachedTokenizerNames ];
cachedTokenizer[ name_String ] := cachedTokenizer0 @ tokenizerName @ toModelName @ name;
cachedTokenizer // endDefinition;


cachedTokenizer0 // beginDefinition;

cachedTokenizer0[ "chat-bison" ] = ToCharacterCode[ #, "UTF8" ] &;

cachedTokenizer0[ "gpt-4-vision" ] :=
    If[ graphicsQ[ # ],
        gpt4ImageTokenizer[ # ],
        cachedTokenizer[ "gpt-4" ][ # ]
    ] &;

cachedTokenizer0[ model_String ] := Enclose[
    Quiet @ Module[ { name, tokenizer },
        initTools[ ];
        Quiet @ Needs[ "Wolfram`LLMFunctions`Utilities`Tokenization`" -> None ];
        name      = ConfirmBy[ tokens`FindTokenizer @ model, StringQ, "Name" ];
        tokenizer = ConfirmMatch[ tokens`LLMTokenizer[ Method -> name ], Except[ _tokens`LLMTokenizer ], "Tokenizer" ];
        ConfirmMatch[ tokenizer[ "test" ], _List, "TokenizerTest" ];
        cachedTokenizer0[ model ] = tokenizer
    ],
    gpt2Tokenizer &
];

cachedTokenizer0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenizerName*)
tokenizerName // beginDefinition;
tokenizerName[ name_String ] := SelectFirst[ $cachedTokenizerNames, StringContainsQ[ name, # ] &, name ];
tokenizerName // endDefinition;

$cachedTokenizerNames = { "gpt-4-vision", "gpt-4", "gpt-3.5", "gpt-2", "claude-2", "claude-instant-1", "chat-bison" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GPT-4 Vision Image Tokenizer *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizeMultimodalImage*)
resizeMultimodalImage // beginDefinition;

resizeMultimodalImage[ image0_ ] := Enclose[
    Module[ { image, dimensions, max, small, resized },
        image = ConfirmBy[ If[ image2DQ @ image0, image0, Rasterize @ image0 ], image2DQ, "Image" ];
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
(* ::Subsection::Closed:: *)
(*Fallback Tokenizer*)
gpt2Tokenizer := gpt2Tokenizer = ResourceFunction[ "GPTTokenizer" ][ ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    cachedTokenizer[ All ];
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
