(*
	Note: This context name was chosen to avoid being cleared by the Chatbook.wl
	loading code, which clears names in the Wolfram`Chatbook` context
*)
Wolfram`ChatbookStartupDump`$ContextInfo = {$Context, $ContextPath, $ContextAliases};

(*----------------------------------------*)
(* Add File > New > Chat-Enabled Notebook *)
(*----------------------------------------*)

Once[
	FrontEndExecute[{
		FrontEnd`AddMenuCommands["New", {
			MenuItem[
				"Chat-Enabled Notebook",
				FrontEnd`KernelExecute[(
					Needs["Wolfram`Chatbook`" -> None];
					Wolfram`Chatbook`CreateChatNotebook[]
				)],
				FrontEnd`MenuEvaluator -> Automatic,
				FrontEnd`MenuKey["n", FrontEnd`Modifiers -> {FrontEnd`Command, FrontEnd`Option}]
			]
		}]
	}],
    "FrontEndSession"
]

(*----------------------------*)
(* Add CreateNotebook["Chat"] *)
(*----------------------------*)

PrependTo[
    DownValues @ System`FEDump`createNotebook,
    HoldPattern[ System`FEDump`createNotebook[ "Chat", { System`FEDump`opts___ } ] ] :> (
        Needs[ "Wolfram`Chatbook`" -> None ];
        Wolfram`Chatbook`CreateChatNotebook[ System`FEDump`opts ]
    )
]

(*--------------------------------------------*)
(* Add Wolfram`Chatbook` to internal contexts *)
(*--------------------------------------------*)

Language`AddInternalContexts[ "Wolfram`Chatbook`*" ]
