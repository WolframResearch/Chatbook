PacletObject[<|
	"Name" -> "Wolfram/Chatbook",
	"PublisherID" -> "Wolfram",
	"Version" -> "0.0.9",
	"WolframVersion" -> "13.2",
	"Description" -> "Wolfram tools for interacting with LLMs",
	"Creator" -> {
		"Connor Gray", "Theodore Gray", "Richard Hennigan"
	},
	"Icon" -> "Assets/Images/PacletIcon.png",
	"Extensions" -> {
		{"Kernel",
			"Root" -> "Source/Chatbook",
			"Context" -> "Wolfram`Chatbook`"
		},
		{"Kernel",
			"Root" -> "Source/ServerSentEventUtils",
			"Context" -> "Wolfram`ServerSentEventUtils`"},
		{"Kernel",
			"Root" -> "Source/AIAssistant",
			"Context" -> "Wolfram`AIAssistant`"},
		{"Asset",
			"Root" -> "Assets",
			"Assets" -> {
				{"AIAssistant", "AIAssistant"}
			}
		},
		{"FrontEnd"},
		{"Documentation", "Language" -> "English"}
	}
|>]
