(*
	Restore context values to what they were before Chatbook startup code
	started running.
*)
{$Context, $ContextPath, $ContextAliases} = Wolfram`ChatbookStartupDump`$ContextInfo;

(*------------------------------------*)
(* Adds Help > Notebook Assistance... *)
(*------------------------------------*)
If[ $Notebooks, Once[ Wolfram`Chatbook`EnableNotebookAssistance[ ], "FrontEndSession" ] ];

Wolfram`ChatbookStartupDump`$loadTime = SessionTime[ ] - Wolfram`ChatbookStartupDump`$loadStart;