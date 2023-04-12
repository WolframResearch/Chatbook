PacletObject[<|
	"Name" -> "Wolfram/LLMTools",
	"PublisherID" -> "Wolfram",
	"Version" -> "0.0.8",
	"WolframVersion" -> "13.2",
	"Description" -> "Wolfram tools for interacting with LLMs",
	"Creator" -> {
		"Connor Gray", "Theodore Gray", "Giulio Alessandrini",
		"Timothee Verdier", "Christopher Wolfram"
	},
	"Icon" -> "Assets/Images/PacletIcon.png",
	"Extensions" -> {
		{
			"Kernel",
			"Root" -> "Source",
			"Context" -> "Wolfram`LLMTools`",
			"Symbols" -> {
				"Wolfram`LLMTools`ImageSynthesize",
				"Wolfram`LLMTools`TextSynthesize",
				"Wolfram`LLMTools`CreateChat",
				"Wolfram`LLMTools`ChatEvaluate",
				"Wolfram`LLMTools`ChatObject",
				"Wolfram`LLMTools`ChatObjectQ"
			}
		},
		{
			"Kernel",
			"Root" -> "Source/Chatbook",
			"Context" -> "Wolfram`Chatbook`"
		},
		{
			"Kernel",
			"Root" -> "Source/ServerSentEventUtils",
			"Context" -> "Wolfram`ServerSentEventUtils`"
		},
		{
			"Kernel",
			"Root" -> "Source/APIFunctions",
			"Context" -> "Wolfram`APIFunctions`"
		},
		{
			"Kernel",
			"Root" -> "Source/OpenAILink",
			"Context" -> "Wolfram`OpenAILink`",
			"Symbols" -> {
				"Wolfram`OpenAILink`$OpenAIKey",
				"Wolfram`OpenAILink`$OpenAIUser",
				"Wolfram`OpenAILink`OpenAIChatMessageObject",
				"Wolfram`OpenAILink`OpenAIChatCompletionObject",
				"Wolfram`OpenAILink`OpenAITextCompletionObject",
				"Wolfram`OpenAILink`OpenAIChatComplete",
				"Wolfram`OpenAILink`OpenAITextComplete",
				"Wolfram`OpenAILink`OpenAITranscribeAudio",
				"Wolfram`OpenAILink`OpenAITranslateAudio",
				"Wolfram`OpenAILink`OpenAIGenerateImage",
				"Wolfram`OpenAILink`OpenAIEmbedding",
				"Wolfram`OpenAILink`OpenAIModels"
			}
		},
		{
			"Asset",
			"Root" -> "Assets",
			"Assets" -> {
				{"APIFunctions", "APIFunctions"}
			}
		},
		{"FrontEnd"},
		{"Documentation", "Language" -> "English"}
	}
|>]
