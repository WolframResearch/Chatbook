(*
	Restore context values to what they were before Chatbook startup code
	started running.
*)
{$Context, $ContextPath, $ContextAliases} = Wolfram`ChatbookStartupDump`$ContextInfo;
