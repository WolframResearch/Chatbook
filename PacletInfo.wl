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
			"Context" -> "Wolfram`LLMTools`"
		},
		{
			"Kernel",
			"Root" -> "Source/Chatbook",
			"Context" -> "Wolfram`LLMTools`Chatbook`"
		},
		{
			"Kernel",
			"Root" -> "Source/ServerSentEventUtils",
			"Context" -> "Wolfram`LLMTools`ServerSentEventUtils`"
		},
		{
			"Kernel",
			"Root" -> "Source/APIFunctions",
			"Context" -> "Wolfram`LLMTools`APIFunctions`",
			"Symbols" -> {
				"Wolfram`LLMTools`APIFunctions`ImageSynthesize",
				"Wolfram`LLMTools`APIFunctions`TextSynthesize",
				"Wolfram`LLMTools`APIFunctions`CreateChat",
				"Wolfram`LLMTools`APIFunctions`ChatEvaluate",
				"Wolfram`LLMTools`APIFunctions`ChatObject",
				"Wolfram`LLMTools`APIFunctions`ChatObjectQ"
			}
		},
		{
			"Kernel",
			"Root" -> "Source/OpenAILink",
			"Context" -> "Wolfram`LLMTools`OpenAILink`",
			"Symbols" -> {
				"Wolfram`LLMTools`OpenAILink`$OpenAIKey",
				"Wolfram`LLMTools`OpenAILink`$OpenAIUser",
				"Wolfram`LLMTools`OpenAILink`OpenAIChatMessageObject",
				"Wolfram`LLMTools`OpenAILink`OpenAIChatCompletionObject",
				"Wolfram`LLMTools`OpenAILink`OpenAITextCompletionObject",
				"Wolfram`LLMTools`OpenAILink`OpenAIChatComplete",
				"Wolfram`LLMTools`OpenAILink`OpenAITextComplete",
				"Wolfram`LLMTools`OpenAILink`OpenAITranscribeAudio",
				"Wolfram`LLMTools`OpenAILink`OpenAITranslateAudio",
				"Wolfram`LLMTools`OpenAILink`OpenAIGenerateImage",
				"Wolfram`LLMTools`OpenAILink`OpenAIEmbedding",
				"Wolfram`LLMTools`OpenAILink`OpenAIModels"
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
