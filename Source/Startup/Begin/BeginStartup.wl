Wolfram`ChatbookStartupDump`$loadStart = SessionTime[ ];
(*
	Note: This context name was chosen to avoid being cleared by the Chatbook.wl
	loading code, which clears names in the Wolfram`Chatbook` context
*)
Wolfram`ChatbookStartupDump`$ContextInfo = {$Context, $ContextPath, $ContextAliases};
Wolfram`ChatbookStartupDump`$versionString = TextString @ $VersionNumber <> "." <> TextString @ $ReleaseNumber;

(*----------------------------*)
(* Add CreateNotebook["Chat"] *)
(*----------------------------*)

Scan[
	PrependTo[ DownValues @ System`FEDump`createNotebook, # ] &,
	{
		HoldPattern[ System`FEDump`createNotebook[ "ChatEnabled", { System`FEDump`opts___ } ] ] :> (
			Needs[ "Wolfram`Chatbook`" -> None ];
			Wolfram`Chatbook`CreateChatNotebook[ System`FEDump`opts ]
		),
		HoldPattern[ System`FEDump`createNotebook[ "ChatDriven", { System`FEDump`opts___ } ] ] :> (
			Needs[ "Wolfram`Chatbook`" -> None ];
			Wolfram`Chatbook`CreateChatDrivenNotebook[ System`FEDump`opts ]
		),
		HoldPattern[ System`FEDump`createNotebook[ "PromptResource", { System`FEDump`opts___ } ] ] :> (
			Needs[ "ResourceSystemClient`" -> None ];
			ResourceSystemClient`CreateResourceNotebook[ "Prompt", "SuppressProgressBar" -> True ]
		)
	}
]

(*--------------------------------------------*)
(* Add Wolfram`Chatbook` to internal contexts *)
(*--------------------------------------------*)

Language`AddInternalContexts[ "Wolfram`Chatbook`*" ]
