PacletObject[<|
	"Name" -> "Wolfram/LLMTools",
	"PublisherID" -> "Wolfram",
	"Version" -> "0.0.9",
	"WolframVersion" -> "13.2",
	"Description" -> "Wolfram tools for interacting with LLMs",
	"Creator" -> {
		"Connor Gray", "Theodore Gray", "Giulio Alessandrini",
		"Timothee Verdier", "Richard Hennigan"
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
			"Root" -> "Source/APIFunctions",
			"Context" -> "Wolfram`APIFunctions`"},
		{"Kernel",
			"Root" -> "Source/AIAssistant",
			"Context" -> "Wolfram`AIAssistant`"},
		{"Asset",
			"Root" -> "Assets",
			"Assets" -> {
				{"APIFunctions", "APIFunctions"},
				{"AIAssistant", "AIAssistant"}
			}
		},
		{"FrontEnd"},
		{"Documentation", "Language" -> "English"}
	}
|>]
