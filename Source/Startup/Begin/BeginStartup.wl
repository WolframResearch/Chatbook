(*
	Note: This context name was chosen to avoid being cleared by the Chatbook.wl
	loading code, which clears names in the Wolfram`Chatbook` context
*)
Wolfram`ChatbookStartupDump`$ContextInfo = {$Context, $ContextPath, $ContextAliases};

(*----------------------------------------*)
(* Add File > New > Chat-Enabled Notebook *)
(*----------------------------------------*)

FrontEndExecute[{
	FrontEnd`AddMenuCommands["New", {
		MenuItem[
			"Chat-Enabled Notebook",
			FrontEnd`KernelExecute[(
				Needs["Wolfram`Chatbook`" -> None];
				Wolfram`Chatbook`CreateChatNotebook[]
			)],
			FrontEnd`MenuEvaluator -> Automatic,
			MenuKey["n", FrontEnd`Modifiers -> {Command, Option}]
		]
	}]
}]
