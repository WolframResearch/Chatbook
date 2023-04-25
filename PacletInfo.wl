PacletObject[<|
	"Name" -> "Wolfram/Chatbook",
	"PublisherID" -> "Wolfram",
	"Version" -> "0.0.10",
	"WolframVersion" -> "13.2",
	"Description" -> "Wolfram tools for interacting with LLMs",
	"License" -> "MIT",
	"Creator" -> {
		"Connor Gray", "Theodore Gray", "Richard Hennigan"
	},
	"Icon" -> "Assets/Images/PacletIcon.png",
	(* NOTE: The BeginStartup and EndStartup contexts are special, and need to
		be listed first and last, respectively, among all contexts provided by
		this paclet. This is a workaround used to prevent the contexts from this
		paclet from being present in $ContextPath post Kernel-startup. *)
	"Loading" -> "Startup",
    "PrimaryContext" -> "Wolfram`Chatbook`",
	"Extensions" -> {
		{"Kernel", "Root" -> "Source/Startup/Begin", "Context" -> "Wolfram`Chatbook`BeginStartup`"},
		{"Kernel",
			"Root" -> "Source/Chatbook",
			"Context" -> "Wolfram`Chatbook`"
		},
		{"Kernel",
			"Root" -> "Source/ServerSentEventUtils",
			"Context" -> "Wolfram`ServerSentEventUtils`"},
		{"Kernel", "Root" -> "Source/Startup/End", "Context" -> "Wolfram`Chatbook`EndStartup`"},
		{"Asset",
			"Root" -> "Assets",
			"Assets" -> {
				{"AIAssistant", "AIAssistant"}
			}
		},
		{"FrontEnd"}
	}
|>]
