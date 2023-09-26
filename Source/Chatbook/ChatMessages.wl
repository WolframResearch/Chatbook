(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatMessages`" ];

(* cSpell: ignore nodef *)

(* :!CodeAnalysis::BeginBlock:: *)

Wolfram`Chatbook`CellToChatMessage;

`$chatDataTag;
`constructMessages;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Actions`"          ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`FrontEnd`"         ];
Needs[ "Wolfram`Chatbook`InlineReferences`" ];
Needs[ "Wolfram`Chatbook`Models`"           ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`Prompting`"        ];
Needs[ "Wolfram`Chatbook`Serialization`"    ];
Needs[ "Wolfram`Chatbook`Tools`"            ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$$validMessageResult  = _Association? AssociationQ | _Missing | Nothing;
$$validMessageResults = $$validMessageResult | { $$validMessageResult ... };

$$inlineModifierCell = Alternatives[
    Cell[ _, "InlineModifierReference", ___ ],
    Cell[ BoxData @ Cell[ _, "InlineModifierReference", ___ ], ___ ]
];

$$promptArgumentToken = Alternatives[ ">", "^", "^^" ];

$promptTemplate = StringTemplate[ "%%Pre%%\n\n%%Group%%\n\n%%Base%%\n\n%%Tools%%\n\n%%Post%%", Delimiters -> "%%" ];

$cellRole = Automatic;

$styleRoles = <|
    "ChatInput"              -> "user",
    "ChatOutput"             -> "assistant",
    "AssistantOutput"        -> "assistant",
    "AssistantOutputWarning" -> "assistant",
    "AssistantOutputError"   -> "assistant",
    "ChatSystemInput"        -> "system"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CellToChatMessage*)
CellToChatMessage // Options = { "Role" -> Automatic };

CellToChatMessage[ cell_Cell, opts: OptionsPattern[ ] ] :=
    CellToChatMessage[ cell, <| "Cells" -> { cell }, "HistoryPosition" -> 0 |>, opts ];

CellToChatMessage[ cell_Cell, settings: KeyValuePattern[ "HistoryPosition" -> 0 ], opts: OptionsPattern[ ] ] :=
    Block[ { $cellRole = OptionValue[ "Role" ] },
        Replace[
            makeCurrentCellMessage[ settings, Lookup[ settings, "Cells", { cell } ] ],
            { message_? AssociationQ } :> message
        ]
    ];

(* TODO: this should eventually utilize "HistoryPosition" for dynamic compression rates *)
CellToChatMessage[ cell_Cell, settings_, opts: OptionsPattern[ ] ] :=
    Block[ { $cellRole = OptionValue[ "Role" ] },
        Replace[
            Flatten @ { makeCellMessage @ cell },
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

constructMessages[ settings_Association? AssociationQ, cells: { __CellObject } ] :=
    constructMessages[ settings, notebookRead @ cells ];

constructMessages[ settings_Association? AssociationQ, { cells___Cell, cell_Cell } ] /; $cloudNotebooks :=
    constructMessages[ settings, makeChatMessages[ settings, { cells, parseInlineReferences @ cell } ] ];

constructMessages[ settings_Association? AssociationQ, cells: { __Cell } ] :=
    constructMessages[ settings, makeChatMessages[ settings, cells ] ];

constructMessages[ settings_Association? AssociationQ, messages0: { __Association } ] :=
    Enclose @ Module[ { messages },
        If[ settings[ "AutoFormat" ], needsBasePrompt[ "Formatting" ] ];
        needsBasePrompt @ settings;
        messages = messages0 /. s_String :> RuleCondition @ StringReplace[ s, "%%BASE_PROMPT%%" -> $basePrompt ];
        $lastSettings = settings;
        $lastMessages = messages;
        Sow[ <| "Messages" -> messages |>, $chatDataTag ];
        messages
    ];

constructMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatMessages*)
makeChatMessages // beginDefinition;

makeChatMessages[ settings_, { cells___, cell_ ? promptFunctionCellQ } ] := (
    Sow[ <| "RawOutput" -> True |>, $chatDataTag ];
    makePromptFunctionMessages[ settings, { cells, cell } ]
);

makeChatMessages[ settings0_, cells_List ] := Enclose[
    Module[ { settings, role, message, toMessage, cell, history, messages, merged },
        settings  = ConfirmBy[ <| settings0, "HistoryPosition" -> 0, "Cells" -> cells |>, AssociationQ, "Settings" ];
        role      = makeCurrentRole @ settings;
        cell      = ConfirmMatch[ Last[ cells, $Failed ], _Cell, "Cell" ];
        toMessage = Confirm[ getCellMessageFunction @ settings, "CellMessageFunction" ];
        message   = ConfirmMatch[ toMessage[ cell, settings ], $$validMessageResults, "Message" ];

        history = ConfirmMatch[
            Reverse @ Flatten @ MapIndexed[
                toMessage[ #1, <| settings, "HistoryPosition" -> First[ #2 ] |> ] &,
                Reverse @ Most @ cells
            ],
            $$validMessageResults,
            "History"
        ];

        messages = DeleteMissing @ Flatten @ { role, history, message };
        merged   = If[ TrueQ @ Lookup[ settings, "MergeMessages" ], mergeMessageData @ messages, messages ];
        merged
    ],
    throwInternalFailure[ makeChatMessages[ settings0, cells ], ## ] &
];

makeChatMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getCellMessageFunction*)
getCellMessageFunction // beginDefinition;
getCellMessageFunction[ as_? AssociationQ ] := getCellMessageFunction[ as, as[ "CellToMessageFunction" ] ];
getCellMessageFunction[ as_, _Missing|Automatic|Inherited ] := CellToChatMessage;
getCellMessageFunction[ as_, toMessage_ ] := checkedMessageFunction @ replaceCellContext @ toMessage;
getCellMessageFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkedMessageFunction*)
checkedMessageFunction // beginDefinition;

checkedMessageFunction[ func_ ] :=
    checkedMessageFunction[ func, { ## } ] &;

checkedMessageFunction[ func_, { cell_, settings_ } ] :=
    Replace[
        func[ cell, settings ],
        {
            message_String? StringQ :> <| "role" -> cellRole @ cell, "content" -> message |>,
            Except[ $$validMessageResults ] :> CellToChatMessage[ cell, settings ]
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
    <| "role" -> "system", "content" -> role |>;

makeCurrentRole[ as_, Automatic|Inherited|_Missing, name_String ] :=
    With[ { prompt = namedRolePrompt @ name },
        <| "role" -> "system", "content" -> prompt |> /; StringQ @ prompt
    ];

makeCurrentRole[ as_, _, KeyValuePattern[ "BasePrompt" -> None ] ] := (
    needsBasePrompt @ None;
    Missing[ ]
);

makeCurrentRole[ as_, base_, eval_Association ] := (
    needsBasePrompt @ base;
    needsBasePrompt @ eval;
    <| "role" -> "system", "content" -> buildSystemPrompt @ Association[ as, eval ] |>
);

makeCurrentRole[ as_, base_, _ ] := (
    needsBasePrompt @ base;
    <| "role" -> "system", "content" -> buildSystemPrompt @ as |>
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
        as[ "ChatContextPreprompt" ],
        as[ "Pre" ],
        as[ "PromptTemplate" ]
    },
    expr_ :> With[ { e = expr }, e /; MatchQ[ e, _String | _TemplateObject ] ]
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

getToolPrompt[ settings_ ] := Enclose[
    Module[ { config, string },
        config = ConfirmMatch[ makeToolConfiguration @ settings, _System`LLMConfiguration ];
        ConfirmBy[ TemplateApply[ config[ "ToolPrompt" ], config[ "Data" ] ], StringQ ]
    ],
    throwInternalFailure[ getToolPrompt @ settings, ## ] &
];

getToolPrompt // endDefinition;

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
toPromptString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCurrentCellMessage*)
makeCurrentCellMessage // beginDefinition;

makeCurrentCellMessage[ settings_, { cells___, cell0_ } ] := Enclose[
    Module[ { modifiers, cell, role, content },
        { modifiers, cell } = ConfirmMatch[ extractModifiers @ cell0, { _, _ }, "Modifiers" ];
        role = ConfirmBy[ cellRole @ cell, StringQ, "CellRole" ];
        content = ConfirmBy[ Block[ { $CurrentCell = True }, CellToString @ cell ], StringQ, "Content" ];
        Flatten @ {
            expandModifierMessages[ settings, modifiers, { cells }, cell ],
            <| "role" -> role, "content" -> content |>
        }
    ],
    throwInternalFailure[ makeCurrentCellMessage[ settings, { cells, cell0 } ], ## ] &
];

makeCurrentCellMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCellMessage*)
makeCellMessage // beginDefinition;
makeCellMessage[ cell_Cell ] := <| "role" -> cellRole @ cell, "content" -> CellToString @ cell |>;
makeCellMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellRole*)
cellRole // beginDefinition;

cellRole[ cell_Cell ] :=
    With[ { role = $cellRole }, ToLowerCase @ role /; StringQ @ role ];

cellRole[ Cell[
    __,
    TaggingRules -> KeyValuePattern[ "ChatNotebookSettings" -> KeyValuePattern[ "Role" -> role_String ] ],
    ___
] ] := ToLowerCase @ role;

cellRole[ Cell[ _, styles__String, OptionsPattern[ ] ] ] :=
    FirstCase[ { styles }, style_ :> With[ { role = $styleRoles @ style }, role /; StringQ @ role ], "user" ];

cellRole // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mergeMessageData*)
mergeMessageData // beginDefinition;
mergeMessageData[ messages_ ] := mergeMessages /@ SplitBy[ messages, Lookup[ "role" ] ];
mergeMessageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mergeMessages*)
mergeMessages // beginDefinition;

mergeMessages[ { } ] := Nothing;
mergeMessages[ { message_ } ] := message;
mergeMessages[ messages: { first_Association, __Association } ] :=
    Module[ { role, strings },
        role    = Lookup[ first   , "role"    ];
        strings = Lookup[ messages, "content" ];
        <|
            "role"    -> role,
            "content" -> StringDelete[ StringRiffle[ strings, "\n\n" ], "```\n\n```" ]
        |>
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
            <| "role" -> "user", "content" -> string |>
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
        <| "role" -> role, "content" -> string |>
    ],
    throwInternalFailure[ expandModifierMessage[ modifier, { cells }, cell ], ## ] &
];

expandModifierMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modifierMessageRole*)
modifierMessageRole[ KeyValuePattern[ "Model" -> model_String ] ] :=
    If[ TrueQ @ StringStartsQ[ toModelName @ model, "gpt-3.5", IgnoreCase -> True ],
        "user",
        "system"
    ];

modifierMessageRole[ ___ ] := "system";

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
] := CellToString @ Cell[ TextData @ { a }, "ChatInput", b ];

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

argumentTokenToString[ "^", name_, { ___, cell_, _ } ] := CellToString @ cell;

argumentTokenToString[ "^^", name_, { history___, _ } ] := StringRiffle[ CellToString /@ { history }, "\n\n" ];

argumentTokenToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
