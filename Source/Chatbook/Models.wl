(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Models`" ];

(* cSpell: ignore chatgpt *)

(* :!CodeAnalysis::BeginBlock:: *)

`chatModelQ;
`getModelList;
`modelDisplayName;
`multimodalModelQ;
`snapshotModelQ;
`standardizeModelData;
`toModelName;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`Actions`"  ];
Needs[ "Wolfram`Chatbook`Dynamics`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$$modelVersion = DigitCharacter.. ~~ (("." ~~ DigitCharacter...) | "");

$defaultModelIcon = "";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenAI Models*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getModelList*)
getModelList // beginDefinition;

(* NOTE: This function is also called in UI.wl *)
getModelList[ ] := getModelList @ toAPIKey @ Automatic;

getModelList[ key_String ] := getModelList[ key, Hash @ key ];

getModelList[ Missing[ "DialogInputNotAllowed" ] ] := $fallbackModelList;

getModelList[ key_String, hash_Integer ] :=
    Module[ { resp },
        resp = URLExecute[
            HTTPRequest[
                "https://api.openai.com/v1/models",
                <| "Headers" -> <| "Content-Type" -> "application/json", "Authorization" -> "Bearer "<>key |> |>
            ],
            "RawJSON",
            Interactive -> False
        ];
        If[ FailureQ @ resp && StringStartsQ[ key, "org-", IgnoreCase -> True ],
            (*
                When viewing the account settings page on OpenAI's site, it describes the organization ID as something
                that's used in API requests, which may be confusing to someone who is looking for their API key and
                they come across this page first. This message is meant to catch these cases and steer the user in the
                right direction.

                TODO: When more services are supported, this should only apply when using an OpenAI endpoint.
            *)
            throwFailure[
                ChatbookAction::APIKeyOrganizationID,
                Hyperlink[ "https://platform.openai.com/account/api-keys" ],
                key
            ],
            getModelList[ hash, resp ]
        ]
    ];

(* Could not connect to the server (maybe server is down or no internet connection available) *)
getModelList[ hash_Integer, failure: Failure[ "ConnectionFailure", _ ] ] :=
    throwFailure[ ChatbookAction::ConnectionFailure, failure ];

(* Some other failure: *)
getModelList[ hash_Integer, failure_? FailureQ ] :=
    throwFailure[ ChatbookAction::ConnectionFailure2, failure ];

getModelList[ hash_, KeyValuePattern[ "data" -> data_ ] ] :=
    getModelList[ hash, data ];

getModelList[ hash_, models: { KeyValuePattern[ "id" -> _String ].. } ] :=
    Module[ { result },
        result = Cases[ models, KeyValuePattern[ "id" -> id_String ] :> id ];
        getModelList[ _String, hash ] = result;
        updateDynamics[ "Models" ];
        result
    ];

getModelList[ hash_, KeyValuePattern[ "error" -> as: KeyValuePattern[ "message" -> message_String ] ] ] :=
    Catch @ Module[ { newKey, newHash },
        If[ StringStartsQ[ message, "Incorrect API key" ] && Hash @ systemCredential[ "OPENAI_API_KEY" ] === hash,
            newKey = If[ TrueQ @ $dialogInputAllowed, apiKeyDialog[ ], Throw @ $fallbackModelList ];
            newHash = Hash @ newKey;
            If[ StringQ @ newKey && newHash =!= hash,
                getModelList[ newKey, newHash ],
                throwFailure[ ChatbookAction::BadResponseMessage, message, as ]
            ],
            throwFailure[ ChatbookAction::BadResponseMessage, message, as ]
        ]
    ];

getModelList // endDefinition;


$fallbackModelList = { "gpt-3.5-turbo", "gpt-3.5-turbo-16k", "gpt-4" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatModelQ*)
chatModelQ // beginDefinition;
chatModelQ[ _? (modelContains[ "instruct" ]) ] := False;
chatModelQ[ _? (modelContains[ StartOfString~~("gpt"|"ft:gpt") ]) ] := True;
chatModelQ[ _String ] := False;
chatModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modelContains*)
modelContains // beginDefinition;
modelContains[ patt_ ] := modelContains[ #, patt ] &;
modelContains[ m_String, patt_ ] := StringContainsQ[ m, WordBoundary~~patt~~WordBoundary, IgnoreCase -> True ];
modelContains // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modelName*)
modelName // beginDefinition;
modelName[ KeyValuePattern[ "Name" -> name_String ] ] := modelName @ name;
modelName[ name_String ] := toModelName @ name;
modelName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toModelName*)
toModelName // beginDefinition;

toModelName[ KeyValuePattern @ { "Service" -> service_, "Name"|"Model" -> model_ } ] :=
    toModelName @ { service, model };

toModelName[ { service_String, name_String } ] := toModelName @ name;

toModelName[ name_String? StringQ ] := toModelName[ name ] =
    If[ StringMatchQ[ name, "ft:"~~__~~":"~~__ ],
        name,
        toModelName0 @ StringReplace[
            ToLowerCase @ StringReplace[
                name,
                a_? LowerCaseQ ~~ b_? UpperCaseQ :> a<>"-"<>b
            ],
            "gpt"~~n:$$modelVersion~~EndOfString :> "gpt-"<>n
        ]
    ];

toModelName // endDefinition;

toModelName0 // beginDefinition;
toModelName0[ "chat-gpt"|"chatgpt"|"gpt-3"|"gpt-3.5" ] := "gpt-3.5-turbo";
toModelName0[ name_String ] := StringReplace[ name, "gpt"~~n:DigitCharacter :> "gpt-"<>n ];
toModelName0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*snapshotModelQ*)
snapshotModelQ // beginDefinition;

snapshotModelQ[ name_String? fineTunedModelQ ] := snapshotModelQ[ name ] =
    snapshotModelQ @ StringSplit[ name, ":" ][[ 2 ]];

snapshotModelQ[ name_String? StringQ ] := snapshotModelQ[ name ] =
    StringMatchQ[ toModelName @ name, "gpt-"~~__~~"-"~~Repeated[ DigitCharacter, { 4 } ]~~(""|"-preview") ];

snapshotModelQ[ other_ ] :=
    With[ { name = toModelName @ other }, snapshotModelQ @ name /; StringQ @ name ];

snapshotModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fineTunedModelQ*)
fineTunedModelQ // beginDefinition;
fineTunedModelQ[ name_String ] := StringMatchQ[ toModelName @ name, "ft:"~~__~~":"~~__ ];
fineTunedModelQ[ other_ ] := With[ { name = toModelName @ other }, fineTunedModelQ @ name /; StringQ @ name ];
fineTunedModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*multimodalModelQ*)
(* FIXME: this should be a queryable property from LLMServices: *)
multimodalModelQ // beginDefinition;
multimodalModelQ[ name_String? StringQ ] := StringContainsQ[ toModelName @ name, "gpt-"~~$$modelVersion~~"-vision" ];
multimodalModelQ[ other_ ] := With[ { name = toModelName @ other }, multimodalModelQ @ name /; StringQ @ name ];
multimodalModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modelDisplayName*)
modelDisplayName // beginDefinition;

modelDisplayName[ KeyValuePattern[ "DisplayName" -> name_String ] ] :=
    name;

modelDisplayName[ KeyValuePattern[ "Name" -> name_String ] ] :=
    modelDisplayName @ name;

modelDisplayName[{name_?StringQ, settings_?AssociationQ}] :=
	modelDisplayName[name]

modelDisplayName[ model_String ] := modelDisplayName[ model ] =
	If[ StringMatchQ[ model, "ft:"~~__~~":"~~__ ],
        fineTunedModelName @ model,
        modelDisplayName @ StringSplit[ model, "-"|" " ]
    ];

modelDisplayName[ { "gpt", rest___ } ] :=
	modelDisplayName @ { "GPT", rest };

modelDisplayName[ { before__, date_String } ] /; StringMatchQ[ date, Repeated[ DigitCharacter, { 4 } ] ] :=
    modelDisplayName @ { before, DateObject @ Flatten @ { 0, ToExpression @ StringPartition[ date, 2 ] } };

modelDisplayName[ { before__, "preview" } ] :=
    modelDisplayName @ { before } <> " (Preview)";

modelDisplayName[ { before___, date_DateObject } ] :=
    modelDisplayName @ {
		before,
		"(" <> DateString[ date, "MonthName" ] <> " " <> DateString[ date, "DayShort" ] <> ")"
	};

modelDisplayName[ { "GPT", version_String, rest___ } ] /; StringStartsQ[ version, DigitCharacter.. ] :=
    modelDisplayName @ { "GPT-"<>version, rest };

modelDisplayName[ parts: { __String } ] :=
	StringRiffle @ Capitalize @ parts;

modelDisplayName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fineTunedModelName*)
fineTunedModelName // beginDefinition;

fineTunedModelName[ name_String ] :=
    fineTunedModelName @ StringSplit[ name, ":" ];

fineTunedModelName[ { "ft", rest__ } ] :=
    fineTunedModelName @ { rest };

fineTunedModelName[ { model_String, id__String } ] :=
    StringJoin[
        StringDelete[ modelDisplayName @ model, " ("~~__~~")"~~EndOfString ],
        " (",
        Replace[ { id }, "" -> "::", { 1 } ],
        ")"
    ];

fineTunedModelName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modelIcon*)
modelIcon // beginDefinition;
modelIcon[ KeyValuePattern[ "Icon" -> icon_ ] ] := icon;
modelIcon[ KeyValuePattern[ "Name" -> name_String ] ] := modelIcon @ name;
modelIcon[ name0_String ] := With[ { name = toModelName @ name0 }, modelIcon @ name /; name =!= name0 ];
modelIcon[ name_String ] /; StringStartsQ[ name, "ft:" ] := modelIcon @ StringDelete[ name, StartOfString~~"ft:" ];
modelIcon[ gpt_String ] /; StringStartsQ[ gpt, "gpt-3.5" ] := RawBoxes @ TemplateBox[ { }, "ModelGPT35" ];
modelIcon[ gpt_String ] /; StringStartsQ[ gpt, "gpt-4" ] := RawBoxes @ TemplateBox[ { }, "ModelGPT4" ];
modelIcon[ name_String ] := $defaultModelIcon;
modelIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*standardizeModelData*)
standardizeModelData // beginDefinition;

standardizeModelData[ list_List ] :=
    Flatten[ standardizeModelData /@ list ];

standardizeModelData[ name_String ] := standardizeModelData[ name ] =
    standardizeModelData @ <| "Name" -> name |>;

standardizeModelData[ model: KeyValuePattern @ { "Name" -> _String, "DisplayName" -> _String, "Icon" -> _ } ] :=
    Association @ model;

standardizeModelData[ model_Association? AssociationQ ] :=
    standardizeModelData[ model ] = <|
        "Name"        -> modelName @ model,
        "DisplayName" -> modelDisplayName @ model,
        "Icon"        -> modelIcon @ model,
        model
    |>;

standardizeModelData[ service_String, models_List ] :=
    standardizeModelData[ service, # ] & /@ models;

standardizeModelData[ service_String, model_ ] :=
    With[ { as = standardizeModelData @ model },
        (standardizeModelData[ service, model ] = <| "Service" -> service, as |>) /; AssociationQ @ as
    ];

standardizeModelData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SetModel*)
Options[SetModel]={"SetLLMEvaluator"->True}

SetModel[args___]:=Catch[setModel[args],"SetModel"]

setModel[model_,opts:OptionsPattern[SetModel]]:=setModel[$FrontEndSession,model,opts]

setModel[scope_,model_Association,opts:OptionsPattern[SetModel]]:=(
  If[TrueQ[OptionValue["SetLLMEvaluator"]],
  	System`$LLMEvaluator=System`LLMConfiguration[System`$LLMEvaluator,model];
  ];
  CurrentValue[scope, {TaggingRules, "ChatNotebookSettings"}] = Join[
		Replace[CurrentValue[scope, {TaggingRules, "ChatNotebookSettings"}],Except[_Association]-><||>,{0}],
		model
  ]
)

setModel[scope_,name_String,opts:OptionsPattern[SetModel]]:=Enclose[With[{model=ConfirmBy[standardizeModelName[name],StringQ]},
  If[TrueQ[OptionValue["SetLLMEvaluator"]],
  	System`$LLMEvaluator=System`LLMConfiguration[System`$LLMEvaluator,<|"Model"->model|>];
  ];
  CurrentValue[scope, {TaggingRules, "ChatNotebookSettings","Model"}] = model
]
]

setModel[___]:=$Failed

standardizeModelName[gpt4_String]:="gpt-4"/;StringMatchQ[StringDelete[gpt4,WhitespaceCharacter|"-"|"_"],"gpt4",IgnoreCase->True]
standardizeModelName[gpt35_String]:="gpt-3.5-turbo"/;StringMatchQ[StringDelete[gpt35,WhitespaceCharacter|"-"|"_"],"gpt3.5"|"gpt3.5turbo",IgnoreCase->True]
standardizeModelName[name_String]:=name

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
