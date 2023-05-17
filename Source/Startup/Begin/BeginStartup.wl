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
			],
			MenuItem[
				"Chat-Driven Notebook",
				FrontEnd`KernelExecute[(
					Needs["Wolfram`Chatbook`" -> None];
					Wolfram`Chatbook`CreateChatDrivenNotebook[]
				)],
				FrontEnd`MenuEvaluator -> Automatic
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
    HoldPattern[ System`FEDump`createNotebook[ "ChatEnabled", { System`FEDump`opts___ } ] ] :> (
        Needs[ "Wolfram`Chatbook`" -> None ];
        Wolfram`Chatbook`CreateChatNotebook[ System`FEDump`opts ]
    )
]

PrependTo[
    DownValues @ System`FEDump`createNotebook,
    HoldPattern[ System`FEDump`createNotebook[ "ChatDriven", { System`FEDump`opts___ } ] ] :> (
        Needs[ "Wolfram`Chatbook`" -> None ];
        Wolfram`Chatbook`CreateChatDrivenNotebook[ System`FEDump`opts ]
    )
]

(*--------------------------------------------*)
(* Add Wolfram`Chatbook` to internal contexts *)
(*--------------------------------------------*)

Language`AddInternalContexts[ "Wolfram`Chatbook`*" ]
