BeginPackage["ConnorGray`Chatbook`ServiceUtils`"]

ChatServiceData

RegisterChatService

Begin["`Private`"]

$DefaultChatService="OpenAI";

ConnorGray`Chatbook`$ChatService = $DefaultChatService;

If[!AssociationQ[$ChatServiceData],
	$ChatServiceData=<||>
];

RegisterChatService[name_,data_Association?AssociationQ]:=$ChatServiceData[name]=data

ChatServiceData[name_,prop_]:=Lookup[Lookup[$ChatServiceData,name,<||>],prop,defaultChatServiceData[name,prop]]

defaultChatServiceData[name_,"ChatRequestFunction"]:=defaultChatRequest[name,##]&

defaultChatRequest[service_,messages_, tokenLimit_, temperature_] := Module[{apiKey},
	apiKey = ChatServiceData[service,"AuthorizationKey"];

	RaiseConfirmMatch[messages, {___?AssociationQ}];

	(* FIXME: Produce a better error message if this credential key doesn't
		exist; tell the user that they need to set SystemCredential. *)
	If[!StringQ[apiKey],
		Raise[
			ChatbookError,
			<| "SystemCredentialKey" -> ChatServiceData[service,"AuthorizationKey"] |>,
			"unexpected result getting OpenAI API Key from SystemCredential: ``",
			InputForm[apiKey]
		];
	];

	URLRead[
		ChatServiceData[service,"HTTPRequestFunction"][
			<|
				"TokenLimit"->tokenLimit,
				"Temperature"->temperature,
				"Messages"->messages
			|>]
	]
]

defaultChatServiceData[name_,"AuthorizationKey"]:=SystemCredential[defaultChatServiceData[name,"AuthKeyName"]]
defaultChatServiceData[_,prop_]:=Missing["NotAvailable",prop]


Get["ConnorGray`Chatbook`Services`"<>FileNameTake[#]<>"`"]&/@FileNames[All,FileNameJoin[{
	PacletObject["ConnorGray/Chatbook"]["Location"],"Source","Services"}]]


End[]

EndPackage[]
