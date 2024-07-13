(*
	Note: This context name was chosen to avoid being cleared by the Chatbook.wl
	loading code, which clears names in the Wolfram`Chatbook` context
*)
Wolfram`ChatbookStartupDump`$ContextInfo = {$Context, $ContextPath, $ContextAliases};
Wolfram`ChatbookStartupDump`$versionString = TextString @ $VersionNumber <> "." <> TextString @ $ReleaseNumber;

(*----------------------------------------*)
(* Add File > New > Chat-Enabled Notebook *)
(*----------------------------------------*)

(*
	Only add the new chat notebook menu commands in v13.3.0 and earlier.

	In v13.3.1 and later, these menu commands are built-in to the FE's
	MenuSetup.tr global menus definitions.
*)
If[ ! PacletNewerQ[ Wolfram`ChatbookStartupDump`$versionString, "13.3.0" ],
    Once[
        FrontEndExecute @ {
            FrontEnd`AddMenuCommands[
                "New",
                {
                    MenuItem[
                        "Chat-Enabled Notebook",
                        FrontEnd`KernelExecute[
							Needs[ "Wolfram`Chatbook`" -> None ];
                        	Symbol[ "Wolfram`Chatbook`CreateChatNotebook" ][ ]
						],
                        FrontEnd`MenuEvaluator -> Automatic,
                        FrontEnd`MenuKey[ "n", FrontEnd`Modifiers -> { FrontEnd`Command, FrontEnd`Option } ]
                    ]
                }
            ]
        },
        "FrontEndSession"
    ]
]

(*--------------------------------*)
(* Adds Help > Code Assistance... *)
(*--------------------------------*)
If[ PacletNewerQ[ Wolfram`ChatbookStartupDump`$versionString, "14.0.0" ],
	Once[
		FrontEndExecute @ {
			FrontEnd`AddMenuCommands[
				"OpenHelpLink",
				{
					MenuItem[
						"Code Assistance Chat\[Ellipsis]",
						FrontEnd`KernelExecute[
							Needs[ "Wolfram`Chatbook`" -> None ];
							Symbol[ "Wolfram`Chatbook`ShowCodeAssistance" ][ "Window" ]
						],
						FrontEnd`MenuEvaluator -> Automatic,
						FrontEnd`MenuKey[ "'", FrontEnd`Modifiers -> { FrontEnd`Command } ]
					],
					MenuItem[
						"Code Assistance for Selection",
						FrontEnd`KernelExecute[
							Needs[ "Wolfram`Chatbook`" -> None ];
							Symbol[ "Wolfram`Chatbook`ShowCodeAssistance" ][ "Inline" ]
						],
						FrontEnd`MenuEvaluator -> Automatic,
						FrontEnd`MenuKey[ "'", FrontEnd`Modifiers -> { FrontEnd`Control } ]
					]
				}
			]
		},
		"FrontEndSession"
	]
]

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
