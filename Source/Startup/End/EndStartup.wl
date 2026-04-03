(*
	Restore context values to what they were before Chatbook startup code
	started running.
*)
{$Context, $ContextPath, $ContextAliases} = Wolfram`ChatbookStartupDump`$ContextInfo;

(*------------------------------------*)
(* Adds Help > Notebook Assistance... *)
(*------------------------------------*)
(* Menu items were moved into the front end proper for 15.0 *)
If[ $Notebooks && ! BoxForm`sufficientVersionQ[ 15.0 ], Once[ Wolfram`Chatbook`EnableNotebookAssistance[ ], "FrontEndSession" ] ];

Wolfram`ChatbookStartupDump`$loadTime = SessionTime[ ] - Wolfram`ChatbookStartupDump`$loadStart;