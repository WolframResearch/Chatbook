---
name: replay-chat
description: >-
  Run real Chatbook chats against a scripted, local fake LLM (a fake Ollama server, Developer/ReplayServer) instead of
  a real model, in a chat notebook, the Notebook Assistant window, or the sidebar. The answer streams through the whole
  real pipeline (LLMServices, streaming handlers, formatting, tool calls and the follow-up request) with exactly the
  text, chunk size and timing you script, every time, offline and for free. It can also send exact chunk boundaries,
  text containing stop tokens, and seeded random (fuzz) text, for stress-testing the streaming formatter. Use this
  whenever a task needs a chat
  response that is repeatable or specific - for example "reproduce this streaming/formatting bug", "check how a
  response with a table and a tool call renders", "run 100 chats to see if the front end crashes", "test what happens
  when the model writes X", "stress-test the formatter with garbage", "measure time to first token without network
  noise" - or when no model or LLMKit sign-in is available.
---

# Replaying scripted chats

The tools live in `Developer/ReplayServer/` (its README.md has the details):

- `ollama_replay.py` - the server (Python 3 standard library only).
- `ReplayChat.wl` - helpers that point a chat at the server, in a kernel attached to a front end.
- `Scripts/*.json` - example responses.

It works because Chatbook reaches Ollama through LLMServices, whose Ollama provider (LLMConnections, 15.0 and 16.0)
connects to `127.0.0.1:11435`. The server listens there and calls its only model `replay:latest`, so a chat just needs
`"Model" -> <|"Service" -> "Ollama", "Name" -> "replay:latest"|>`. Nothing in Chatbook is patched or stubbed.

For anything in the front end, use the drive-frontend skill (`fe.py`); this skill only adds the fake model.

## 1. Start the server

```bash
R=<repo>/Developer/ReplayServer
python3 $R/ollama_replay.py --script $R/Scripts/sine-tool.json --log /tmp/replay.jsonl &
```

- Only one server can use port 11435. Check first with `lsof -nP -iTCP:11435 -sTCP:LISTEN`: a real Ollama (or another
  agent's replay server) may be there. If so, use `--port N` and call `` Wolfram`ChatbookReplay`ReplaySetPort[N] ``
  in the front end's kernel (it lasts for that kernel session).
- `--chunk` (characters per chunk, default 12) and `--delay` (seconds between chunks, default 0.03) set the speed.
  `--no-stop` turns off stop tokens (see [Stress-testing the formatter](#stress-testing-the-formatter)).
- Stop it with `kill %1` or `pkill -f ollama_replay.py` when done.

## 2. Send a chat

Launch a front end with the development Chatbook (`$fe launch --chatbook <repo>`), then load the helpers:

```bash
$fe eval 'Get["<repo>/Developer/ReplayServer/ReplayChat.wl"]'
```

| Surface | How |
|---|---|
| Chat notebook | `` $fe eval 'Wolfram`ChatbookReplay`ReplayChatNotebook["prompt"]' `` - creates a notebook titled "ReplayChat" with a ChatInput cell and evaluates it (same code path as Shift+Enter). `"Evaluate" -> False` leaves it unsent, to send it with real keys. |
| Assistant window | `` $fe eval 'Wolfram`ChatbookReplay`ReplayAssistantWindow[]' `` (opens a new window), then `$fe ask 'prompt'` (types into the real input field). |
| Sidebar | `` $fe eval '$nb = CreateDocument[{}, WindowTitle -> "Host"]; Wolfram`ChatbookReplay`ReplaySidebar[$nb]' ``, then **in a separate eval** `` $fe eval 'Wolfram`ChatbookReplay`ReplayUseServer[$nb, "Sidebar" -> True]' ``, then `$fe ask 'prompt' --sidebar Host`. |

All of them accept `"Settings" -> <|...|>` for extra chat settings (e.g. `"LLMEvaluator"`, `"Tools"`), and
`ReplayUseServer[obj]` switches any existing chat notebook, window, or chat cell to the server.

Always confirm the chat really went to the server: the log must show `/api/chat` requests. If it doesn't, the chat
went to the default model, which makes a real (paid) request and gives a different answer.

- The sidebar creates its chat cell asynchronously, which can't happen while the kernel is busy, so
  `ReplayUseServer[..., "Sidebar" -> True]` must be a separate evaluation. It returns `$Failed` while the sidebar
  isn't ready; wait a second and retry.
- The helpers turn off `AutoGenerateTitle` (it would call a real model) and `AutoSaveConversations` (test chats would
  fill the user's History). Override them with `"Settings"` if that's what you're testing.

## 3. Check the result

```bash
python3 -c "import json,sys; [print(d.get('n'), d.get('path'), d.get('turn'), d.get('toolFormat') or d.get('event',''), d.get('chunks','')) for d in map(json.loads, open('/tmp/replay.jsonl'))]"
```

A tool-calling chat shows two `/api/chat` requests: turn 0 (the answer up to the tool call) and turn 1 (the answer to
the tool result), each followed by a `done` event. `client closed` means Chatbook stopped reading (a stop button, or a
client-side stop). Then look at it: `$fe cells ReplayChat`, `$fe screenshot ...`.

## 4. Write a script

```json
{"turns": [
  [{"content": "<think>\nreasoning\n</think>\n"},
   {"content": "Here's the code:\n\n```wl\n1 + 1\n```\n\n"},
   {"tool": "wolfram_language_evaluator", "short": "wl", "arguments": {"code": "1 + 1"}}],
  [{"content": "The result is 2.\n"}]
]}
```

- **Turns.** The turn used for a request is the number of assistant messages since the last user message, so turn 0
  answers the prompt, turn 1 the first tool result, and so on; the last turn repeats after that. A new prompt in the
  same chat starts at turn 0 again.
- **Steps.** `content` (plain response text), `thinking` (reasoning the provider reports separately; Chatbook shows it
  as a reasoning block), `pause` (seconds of silence, e.g. a slow model or a long tool argument), and `tool`. For
  stress tests there are also `chunks` and `fuzz` (see [Stress-testing the formatter](#stress-testing-the-formatter)).
- **Tool calls.** Write them with `tool` rather than as text: the server writes them in the format the request asks
  for, which depends on the settings. With default tools Chatbook uses the "Simple" format (`/wl\ncode\n/exec`,
  stop token `"\n/exec"`), with custom tools `TOOLCALL: ... ENDTOOLCALL`, and with `"ToolMethod" -> "Service"` native
  `tool_calls`. A tool call written in the wrong format fails like a confused model would (e.g. a
  `General::ChatbookInternal` failure from `parsePartialToolCallString` for `TOOLCALL:` text in a Simple-method chat).
  `short` is the tool's `"ShortName"` (`Source/Chatbook/Tools/DefaultToolDefinitions/*.wl`): `wl`, `wa`,
  `doc_search`, `create_nb`, ...
- **Stop tokens.** Content is cut at the first stop token of the request, as a real server does, even when the token
  falls across chunk boundaries. Text after the tool call is never sent.
- Optional top-level `"chunk"` and `"delay"` override the command line for that script.
- The script is read again for every request, so you can edit it between chats without restarting the server.

To replay a real model's answer, copy it from a real chat (e.g. `` $fe read CELLID --format Markdown `` gives
something close; the raw text is more faithful) into `content` steps, and split it where the model made tool calls.

## Stress-testing the formatter

These are optional tools, for when the task is about how streamed text is parsed or displayed (the streaming lexer,
formatting rules, partial code blocks/tables/math, think tags). For ordinary UI checks, a realistic `content` script
is the better test. Decide case by case whether you need them.

- **Choose the split points** with `{"chunks": [...]}`: each string is sent as one chunk, exactly. Use it to put a
  boundary inside a token (`` "`" | "``wl" ``, `"$" | "$x$"`, `"<thi" | "nk>"`, a table row split mid-cell). The
  boundaries, not the text, are what break streaming code. `Scripts/split-points.json` is an example.
- **Stream text that contains stop tokens** with `--no-stop` (or `"stop": false` in the script). By default the
  server cuts content at the request's stop tokens, so strings such as `/end`, `ENDTOOLCALL`, `\n/exec` or `[INFO]`
  never reach Chatbook. Without the cut, Chatbook's own client-side stop detection is what gets tested. Leave it on
  for anything involving tool calls, since the server then no longer ends a tool call.
- **Fuzz** with `{"fuzz": {...}}`: random text built from Markdown, LaTeX and WL fragments (fences, `$`, `\(`, table
  pipes, `<think>`, box syntax, emoji, zero-width spaces, ...), sent in random chunk sizes. Keys, all optional:
  `seed`, `length` (characters, default 2000), `chunk` (`[min, max]`, default `[1, 16]`), `fragments` (replaces the
  built-in list), `extra` (adds to it, e.g. `["/end", "TOOLCALL: "]`). `Scripts/fuzz.json` is an example.
  - Without a `seed`, every request gets a new one, so a loop of chats covers different text each time.
  - Each fuzzed response's log entry has `fuzz: [{seed, chunks, cutAtStopToken}]`. When a run fails, take the
    `chunks` from the log and replay them as a `chunks` step (the exact stream), or fix the `seed`.
  - Fuzz text is nonsense, so judge the result by robustness, not appearance: no `ChatbookInternal` failure in the
    output (`$fe cells`), no messages (`$fe messages`), the chat finishes (`done` in the log, kernel idle), and the
    front end survives. Ugly output is expected.
- `--delay 0` streams as fast as possible, to find races in the per-chunk handlers.

Once a failing stream has been found, shrink it: delete chunks from the `chunks` list until the failure goes away,
and keep the smallest one that still fails. That small stream belongs in a unit test (e.g. the formatter harness),
not just a replay script.

## Repeated runs

For stress tests (e.g. "does it crash in 100 chats"), loop over: send a chat, wait for two `done` events in the log
(or `$fe wait`), check `$fe servers` still answers, then close the notebook or press "New Chat". On macOS, crash
reports appear as `~/Library/Logs/DiagnosticReports/WolframNB-*.ips`. Lower `--delay` to stream faster than any model
would; set `--delay 0` to find races in the per-chunk handlers.

## Limits

- It fakes the Ollama API only, so service-specific code for other providers (OpenAI Responses reasoning summaries,
  Anthropic prompt caching, LLMKit) isn't exercised. Model-specific settings follow `$modelAutoSettings["Ollama"]`.
- Token counts and usage data in the final chunk are made up.
- It ignores the prompt: the answer is the script, whatever was asked.
