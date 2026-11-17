# Case Study: Making gpt-6.1-sol the Default Model

This page walks through the changes that were needed to use OpenAI's gpt-6.1-sol as the default model. Unlike the [GPT 5.4 case study](gpt-5-4.md), most of the work was not about prompting: the model needs a different API endpoint and a different way of calling tools, and it uses tools more than earlier models, which exposed problems in code paths that the default model had not used before.

This is a companion to [How to Add Support for a New Model](../adding-model-support.md).

**gpt-6.1-sol characteristics:**
- Always reasons: the reasoning efforts `"None"` and `"Minimal"` are rejected (`"Low"` is the lowest)
- Function tools can't be combined with reasoning in the chat completions endpoint, so tools only work through the responses endpoint
- Calls tools natively every time, even when the prompt also describes a text-based tool call format
- Follows instructions literally, and looks things up (documentation, tools) before answering more often than GPT 5.4

---

## Part 1: Model Settings

### Settings keyed by model, not by family

Model names such as `gpt-6.1-sol` resolve to the `"GPT54Plus"` family (any GPT version from 5.4 on), which sets `"Reasoning" -> "None"`. gpt-6.1-sol rejects that value, but other models of the same generation don't (`gpt-6.1-terra`, `gpt-6-sol` and `gpt-6-luna` accept `"None"`), so a new family for "6.1" would have been wrong for them. `$modelAutoSettings` is also looked up by the model's base ID, which covers dated snapshots of the same model, so the settings are keyed by `"GPT61Sol"` (`Settings.wl`):

```wl
$modelAutoSettings[ Automatic, "GPT61Sol" ] = <|
    "EnableCustomTools"  -> True,
    "EnabledBasePrompts" -> {
        "FunctionRepositoryIntegration",
        "WolframLanguageEvaluatorToolInteractive",
        "FunctionRepositoryPreference",
        "ReasonableAssumptions",
        "WolframLanguageEvaluatorToolCode"
    },
    "HybridToolMethod"   -> False,
    "Reasoning"          -> "Medium",
    "ResponsesRequired"  -> True,
    "ToolMethod"         -> "Service"
|>;
```

Everything else falls through to `"GPT54Plus"`.

| Setting | Value | Why |
|---------|-------|-----|
| `"Reasoning"` | `"Medium"` | `"None"` is rejected. With `"Medium"` the model skips reasoning for easy requests and reasons before harder ones. |
| `"ToolMethod"` / `"HybridToolMethod"` | `"Service"` / `False` | The model never used the text-based tool call format in testing (neither did GPT 5.4), so the hybrid method only added prompt text. With native calls, the reasoning that led to a tool call is also sent back with it. |
| `"EnableCustomTools"` | `True` | See [Part 3](#part-3-custom-tools). |
| `"ResponsesRequired"` | `True` | See [Part 2](#part-2-the-default-model-and-the-responses-endpoint). |
| `"EnabledBasePrompts"` | adds three components | See [Issue 5](#issue-5-instructions-are-followed-literally). The entry replaces the list of the family, so it repeats the two components that `"GPT54Plus"` enables. |

### Finding out what the model accepts

The service's error messages are the quickest way to find a model's constraints. These are the two that determined the settings above:

```
Unsupported value: 'none' is not supported with the 'gpt-6.1-sol' model. Supported values are: 'low', 'medium', 'high', 'xhigh', and 'max'.

Function tools with reasoning_effort are not supported for gpt-6.1-sol in /v1/chat/completions. To use function tools, use /v1/responses or set reasoning_effort to 'none'.
```

Together they mean that tools need the responses endpoint, which in turn needs versions of `Wolfram/LLMFunctions` (2.4.0) and `LLMConnections` (1.1.0) that were not released yet when this work was done.

Without the responses endpoint (for example the `"OpenAI"` service with older paclets, or an explicit `"RequestMethod" -> "ChatCompletions"`), a chat with this model and tools fails with the second message. Setting `"ToolMethod" -> "Simple"` makes it work there, since prompt-based tools don't need function tools.

---

## Part 2: The Default Model and the Responses Endpoint

The default model is `<| "Service" -> "LLMKit", "Name" -> Automatic |>`, and the name is chosen from `$llmKitPreferredModels` (`Models.wl`). Three things are released independently: this version of Chatbook, the paclets that support the responses endpoint, and the LLMKit server's support for the model and the endpoint.

- **The model isn't offered by LLMKit yet.** `$llmKitPreferredModels` lists `gpt-6.1-sol` before `gpt-5.4`, and `chooseFirstAvailableModel` takes the first one that LLMKit lists as available for the user, so the default switches when the server starts to offer the model. If none can be used, the last entry is chosen.
- **The installed paclets don't support the responses endpoint** (`$responsesAPIAvailable` is `False`). A model with `"ResponsesRequired"` is skipped (`usableLLMKitModelQ`), so the default stays `gpt-5.4` with its existing behavior.
- **LLMKit and the responses endpoint.** `chooseRequestMethod` used to give `"ChatCompletions"` for everything that goes through LLMKit. It now gives `"Responses"` for models with `"ResponsesRequired"`, and still `"ChatCompletions"` for the other models.

**What the server has to guarantee:** Chatbook can't tell whether the LLMKit server supports the responses endpoint, only which models it lists. The server must therefore list `gpt-6.1-sol` (as a `"ChatCompletion"` type model, which is what `extractModelNames` reads) only once its responses endpoint works for it. When this was written, the server did not offer the model and its responses endpoint returned an error for every model, so the LLMKit path with the responses endpoint has not been run against a server. LLMFunctions also registers the endpoint only for the service named `"LLMKit"`, not for an `"OpenAI"` model with `"Authentication" -> "LLMKit"`.

For the `"OpenAI"` service nothing changed: models with `"EnableResponses"` use the responses endpoint when the paclets support it.

### Exported configurations

`GenerateLLMConfiguration` is used by LLMFunctions for its named configurations, which are sent to the chat completions endpoint (for example by `LLMSynthesize`). A configuration with gpt-6.1-sol and tools would fail there, so `generateLLMConfiguration` resolves its settings with `$responsesAPIAvailable` set to `False`, which keeps the model and tools it gave before.

---

## Part 3: Custom Tools

### The problem they solve

With native tool calls, the model writes a tool's arguments as JSON. For code and long markdown text that means escaping every quote and line break, and models make mistakes there (see [Issue 1 of the GPT 5.4 case study](gpt-5-4.md#issue-1-switching-to-hybrid-tool-calling), which is why GPT 5.4 uses the hybrid method). The responses endpoint has "custom" tools, whose input is plain text.

### Converting at the boundary

Only two tools benefit (`$customToolParameters` in `Tools/Common.wl`): the Wolfram Language evaluator (`"code"`) and the notebook creation tool (`"content"`). Rather than teaching every part of the tool pipeline about a second kind of tool call, the conversion happens where Chatbook talks to the service, and everything else is unchanged:

| Direction | Function | What it does |
|-----------|----------|--------------|
| Tool definitions sent | `toCustomTools` (called from `makeLLMConfiguration`) | Replaces the parameter schema with `"Parameters" -> None` and appends the parameter's description to the tool description |
| Tool call received | `fromCustomToolRequest` (called from `toolRequestsToStrings`) | Turns the input string into `{ "code" -> input }`, so the call is written to the response as the same `TOOLCALL: ...` text as any other service tool call |
| Chat history sent | `toCustomToolCallData` (called from `toolStringSplit`) and `toCustomToolCalls` (called from `prepareMessagesForLLM`) | Turns these calls, and the requests of their responses, back into calls with a string |

The service decides whether a call in the history is a function call or a custom tool call by the type of its parameter values, so the last step is what keeps the history consistent with the tool definitions.

Creating `LLMTool`, `LLMToolRequest` and `LLMToolResponse` objects takes 2–3 ms each, so the conversions avoid creating more of them. `toCustomTools` keeps the last converted tool for each tool name, and the calls of earlier messages are converted in `toolStringSplit`, which is where their objects are created from the message text anyway (`toCustomToolCallData` converts the data before the object is created). Only the call that was just evaluated is converted as an object, by `toCustomToolCalls`, which adds about 7 ms to the request that follows a tool call. [Issue 6](#issue-6-every-earlier-tool-call-made-requests-slower) has the cost of native tool calls as a whole.

Since the stored text of a tool call is the same as before, formatting, saved chats and switching models in the middle of a conversation need no changes.

### When the original schema is used

`customToolsQ` requires the responses endpoint (`responsesRequestQ @ settings`, which is `False` when the installed paclets don't support it) and `"EnableCustomTools"` for the model. Otherwise the tools are sent with their JSON schema as before: with `"RequestMethod" -> "ChatCompletions"`, with paclets that don't support the endpoint, and for all other models and services.

### Tool call examples

The system prompt has example conversations with tool calls. For a custom tool these now show the plain text input, so the examples don't suggest JSON (`formatToolCallExample`):

```
Assistant: TOOLCALL: wolfram_language_evaluator
Plot[Sin[x], {x, -5, 5}, AxesLabel -> {"x", "sin(x)"}]
```

---

## Part 4: Problems Found During Testing

Most of these come from using native tool calls and the responses endpoint for a default model that calls tools more often. The first three were not visible in single headless requests: they needed a real tool result with an image, a second turn, and a long tool loop.

### Issue 1: The model could not see images in tool results

**Problem:** With prompt-based tool calls, a tool's output is sent as a message whose content can include images, so the model sees the plots it makes. The responses endpoint gets the output of a native tool call as text only, so gpt-6.1-sol answered "I can't see the image itself" when asked about its own plot.

**Solution:** For the `"Service"` method with the responses endpoint, the images of a tool's output are sent in a message right after it (`toolResponseImagesMessage` in `SendChat.wl`). Like the other messages that are only for the request after a tool call, it's marked `"HoldTemporary"`, so it's not saved with the chat.

### Issue 2: Every follow-up after a plot failed

**Problem:** When the chat history is built from notebook cells, image links in a message are replaced by the images for multimodal models, in assistant messages too. The responses endpoint rejects images in assistant messages (`Invalid value: 'input_image'. Supported values are: 'output_text' and 'refusal'.`), so after a response that showed a plot, every later message in that chat failed. An assistant message with images was also not split into its tool calls (`rewriteServiceToolCalls` only handles text).

**Solution:** `allowedMultimodalRoles` gives `{ "User", "System" }` for the responses endpoint, so assistant messages keep the image links as text.

### Issue 3: Broken code cells in created notebooks

**Problem:** `autoCorrect` turns triple backticks around inline code into double backticks. The JSON arguments of a service tool call are on a single line, so the first and last code fence of the notebook content matched that rule, and the first code block of a created notebook became inline text.

**Solution:** The rule no longer matches text with an escaped newline, which a JSON-encoded code block always has.

### Issue 4: Responses that end without an answer

**Problem:** After `"MaxToolResponses"` tool calls (5 in the notebook assistant), the next tool call ends the chat without sending its result to the model, so the user gets tool calls and no answer. gpt-6.1-sol often looks up documentation before it evaluates code, so it gets closer to that limit than GPT 5.4 did.

**Solution:** With the responses endpoint, the response to the last tool call that is allowed comes with a hint telling the model to answer with what it has instead of calling another tool (`lastToolResponseMessage`). It's limited to that endpoint because services differ in which messages they accept after a tool's output.

### Issue 5: Instructions are followed literally

The model does what the prompt says, and not what earlier models did on their own. Four places needed clearer instructions:

- **Results without code.** Asked to make something ("Make a sphere out of little cubes"), the model evaluates code and answers with the result alone, as in the examples of the system prompt. The code is then only in the collapsed tool call, and a notebook user usually wants code to put in their notebook. The `"WolframLanguageEvaluatorToolCode"` base prompt component asks for the code along with the result. In a test of 15 prompts, the answer had the code in 4 without it and in all 15 with it, with little change in the time taken. The judges then noted that the code in the answer was often not the code that had been evaluated (a reversed sort order, another color, a table layout that was never run), mostly for evaluations with natural language input. The component now also says "Give the code as you evaluated it, apart from replacing things that only work in the tool (e.g. expression URIs)."
- **Resource functions.** Asked for the resistance of a resistor with given color bands, the model multiplied the numbers itself, although the documentation snippets listed `ResourceFunction["FromResistorColorCode"]`. The `"FunctionRepositoryPreference"` component (a dependency of `"FunctionRepositoryIntegration"`) tells it to use a resource function that does what the user asks for. That changed 0 of 3 to 3 of 3. The first wording had a side effect that the judges of the evaluation noted: asked for a running maximum, the model led with `ResourceFunction["AccumulateApply"]` and gave `FoldList[Max, list]` as the alternative. A second sentence ("If a built-in function does it just as simply, use the built-in function instead.") fixed that (3 of 3 with the built-in function first) without changing the resistor case.
- **Math delimiters.** The `"MathExpressions"` component said to "surround them with dollar signs: `$$x^2 + y^2$$`". The model used single dollar signs for inline math in about 90% of cases, and those are only recognized as math when they look like it (`probablyMathQ`), so text such as `$(1/2, 0)$` was shown as written. The component now says double dollar signs, also for inline math, which the model follows. This component is used for all models.

- **Questions instead of answers.** Asked to "Compute the weight of a dinosaur", the model only asked which dinosaur was meant, where GPT 5.4 picked one and showed how to change it. The `"ReasonableAssumptions"` component tells it to make a reasonable choice, say what it chose, and answer, and to ask first only when there is nothing reasonable to assume. With it the model answered for Tyrannosaurus rex in 2 of 2 runs, and still asked what to plot when the request was just "Plot it".

The first two and the last are disabled by default and enabled for this model with `"EnabledBasePrompts"` (the same mechanism as in the [GPT 5.4 case study](gpt-5-4.md#the-on-demand-base-prompt-mechanism)).

### Issue 6: Every earlier tool call made requests slower

**Problem:** With the `"Service"` tool method, the tool calls of earlier messages are rebuilt from the message text as `LLMToolRequest` and `LLMToolResponse` objects for every request. That took about 15 ms for each earlier tool call: 7 ms to create the objects (`toolStringSplit`), and 8 ms because `replaceUnicodeCharacters` created them again, including each response's copy of its tool (the description of the evaluator tool has one of the characters it replaces). A request in a chat with 20 earlier tool calls spent 300 ms on this before it was sent, and a response with several tool calls pays for each of its requests. With prompt-based tool calls, which is what the previous default used, the history stays text (4 ms for the same chat). The code was not new, and other models with the `"Service"` method had the same cost, but as the default it would have made every long chat slower.

**Solution:** `toolStringSplit` keeps the objects it creates (`$toolStringSplitCache`, at most 200 tool calls), with the conversion to custom tool calls and the replacement of special characters already applied, and `replaceUnicodeCharacters` returns the objects that it doesn't change as they are. A repeated request with 20 earlier tool calls now takes 7.5 ms to prepare. Each tool call still costs about 10 ms once, in the first request after it.

A related cost was in Issue 1: the service connection encodes the images of the tool message too (about 25 ms each), although the content of that message is not sent. When the images go into their own message, the tool message now only has the text.

### Smaller fixes

- The input of a custom tool call usually ends with a newline, which showed up as an empty line in the formatted tool call, so it's removed.
- The plot example in the system prompt was missing its closing bracket.

---

## Part 5: Evaluation

The model was compared against the previous default by running the same prompts through the real assistant pipeline (`AgentEvaluate` with the notebook assistant's settings, including prompt generators and tools) with both configurations, and having the transcripts judged blind (shuffled labels, tool call syntax rewritten to a neutral form). On 76 prompts, the judges preferred gpt-6.1-sol in 66, gpt-5.4 in 3 (all by a slight margin), and rated 7 as ties, with mean scores of 4.62 and 2.99 out of 5. For the 25 prompts that use Wolfram|Alpha or entity data it was 24, with 1 tie. The time to the first streamed output and the total time were the same for both (medians of 2.5 s and 13.0 s), although gpt-6.1-sol makes more tool calls (1.56 per prompt against 1.00). Four earlier rounds, made while the configuration was still changing, gave 39 of 45, 45 of 51, 43 of 51 and 20 of 25; the judges' notes of those rounds led to the changes described under Issue 5.

Chats that GPT 5.4 had started were also continued with gpt-6.1-sol, since their history has tool calls in the text format of the previous default. The model called its tools natively in 8 of 8 such chats and did not copy the text format.

Things that made this useful:

- **Use the real pipeline.** Results from a harness that only sends a system prompt and a user message did not match the assistant's behavior in earlier work.
- **Compare against the configuration users have now**, not the same model with different settings.
- **Record more than the answer**: the tool calls, whether they were native, time to the first output, token counts, and the images the user would see.
- **Read the judges' notes, not only the counts.** The side effect of the resource function instruction was in the issue lists of prompts that the model still won.
- **Check the front end, with more than one turn.** Issues 2 and 4 only showed up there.
- **Check the services the tools depend on, before and after a run.** In the middle of a run, the Wolfram|Alpha API stopped accepting connections from the test machine (the service itself was up, so possibly a rate limit set off by the test volume). From then on every natural language input waited 20 seconds and failed, which affected this model more because it uses that input whenever the tool description says to. The affected transcripts had to be left out, and the prompts that need Wolfram|Alpha were run again later, one kernel at a time and in small batches with pauses.

---

## Summary

### Files Changed

| File | Changes |
|------|---------|
| `Source/Chatbook/Settings.wl` | `"GPT61Sol"` settings, `chooseRequestMethod` for LLMKit |
| `Source/Chatbook/Models.wl` | `$llmKitPreferredModels`, `usableLLMKitModelQ` |
| `Source/Chatbook/Tools/Common.wl` | Custom tools section, plain text tool call examples |
| `Source/Chatbook/SendChat.wl` | Tools and history conversion calls, kept objects of earlier tool calls, tool response images, tool call limit hint, `autoCorrect` rule |
| `Source/Chatbook/Reasoning.wl` | `responsesRequestQ` |
| `Source/Chatbook/ChatMessages.wl` | No images in assistant messages for the responses endpoint |
| `Source/Chatbook/LLMUtilities.wl` | Conversion of received custom tool calls, exported configurations |
| `Source/Chatbook/Prompting.wl` | Three base prompt components, clearer math delimiters |
| `Source/Chatbook/CommonSymbols.wl` | Declarations of the conversion functions |
| `Source/Chatbook/Tools/Examples.wl` | Fixed the plot example |

### Key Takeaways

- **Check a new model's constraints against the service first.** Two error messages decided the endpoint, the tool method and the reasoning default.
- **Key settings by base ID when a family is not uniform.** Models of the same generation can differ in what they accept.
- **Convert at the boundary.** A new wire format for some tool calls did not need a new internal representation.
- **Measure a new default against what the previous default did, not against the same code path before the change.** Native tool calls had a cost for every earlier tool call that prompt-based tool calls never had. Comparing the path with itself showed no difference; comparing the two defaults showed 300 ms against 4 ms.
- **A new default exercises code paths the old one didn't.** Native tool calls and the responses endpoint had been available for other models, but their problems only became visible with a default model that uses them for everything.
- **A model that follows instructions literally shows where the instructions are vague.** Check what the prompt actually says before changing the model's settings.
- **Every dependency of the default needs a fallback or a stated requirement**: the installed paclets may not support what the model needs, and the server has to offer the model and its endpoint together.

### See Also

- [How to Add Support for a New Model](../adding-model-support.md)
- [Custom Tools](../settings/setting-groups/tools.md#custom-tools)
- [`"RequestMethod"`](../settings/setting-groups/model-and-service.md#requestmethod)
