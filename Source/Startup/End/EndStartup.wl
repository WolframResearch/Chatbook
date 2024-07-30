(*
	Restore context values to what they were before Chatbook startup code
	started running.
*)
{$Context, $ContextPath, $ContextAliases} = Wolfram`ChatbookStartupDump`$ContextInfo;

(*--------------------------------*)
(* Adds Help > Code Assistance... *)
(*--------------------------------*)
(* Once code assistance is ready, this "14.1.0" can be changed to "14.0.0" to enable it for 14.1 users: *)
If[ PacletNewerQ[ Wolfram`ChatbookStartupDump`$versionString, "14.1.0" ],
	Wolfram`Chatbook`EnableCodeAssistance[ ]
]