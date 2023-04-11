<|
"Usage" -> {
    {
        "AIAssistant[]",
        "opens a notebook that can be used to chat with a cool bird."
    },
    {
        "AIAssistant[notebook]",
        "converts the given <+NotebookObject+> into a AIAssistant notebook."
    }
},
"Notes" -> {
    "<+AIAssistant+> requires an API key from [OpenAI](https://platform.openai.com/account/api-keys).",
    "Storing the API key with <+SystemCredential[\"OPENAI_API_KEY\"]=\"key\"+> will make the key persistently available to <+AIAssistant+>.",
    "<+AIAssistant+> is an interface to communicate with [Birdnardo](https://resources.wolframcloud.com/FunctionRepository/resources/BirdSay), a hyper-intelligent AI chat assistant from the future",
    "Birdnardo is pretty good at the Wolfram Language and can probably help you out (or at least entertain you).",
    "<+AIAssistant+> accepts the following options:",
    {
        { "AssistantIcon"    , "<+Automatic+>"    , "the image used to represent the chat assistant" },
        { "AssistantTheme"   , "\"Birdnardo\""    , "a named AI assistant" },
        { "AutoFormat"       , "<+True+>"         , "whether to automatically apply formatting to chat responses" },
        { "ChatHistoryLength", "15"               , "specifies the maximum number of previous cells to include in conversion context" },
        { "Model"            , "\"gpt-3.5-turbo\"", "the language model used to generate text" },
        { "RolePrompt"       , "<+Automatic+>"    , "a string that provides instructions to the chat assistant" }
    }
}
|>