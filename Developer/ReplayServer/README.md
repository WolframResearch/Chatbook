# Replay Server

A fake Ollama server that streams scripted chat responses, so that real Chatbook chats can be run without a model:
repeatable, offline, free, and at any speed. Agents: see `.claude/skills/replay-chat/SKILL.md`.

| File | Purpose |
|---|---|
| `ollama_replay.py` | The server (Python 3 standard library only). `--help` describes the script format |
| `ReplayChat.wl` | Helpers (``Wolfram`ChatbookReplay` ``) that send chats to the server from a chat notebook, the Notebook Assistant window, or the sidebar |
| `Scripts/sine-tool.json` | Reasoning, a code block, a table, a Wolfram Language evaluator tool call, and an answer to the tool result |
| `Scripts/sine.json` | The same without the tool call |
| `Scripts/split-points.json` | Exact chunks that split a code fence, inline math, a table and a think tag mid-token |
| `Scripts/fuzz.json` | Random Markdown/LaTeX/WL text in random chunk sizes, different for every chat |

## How it works

Chatbook sends Ollama chats through LLMServices, whose Ollama provider (in LLMConnections) connects to
`127.0.0.1:11435`. The server listens there and reports one model, `replay:latest`, so selecting
`"Model" -> <|"Service" -> "Ollama", "Name" -> "replay:latest"|>` is all a chat needs. Chatbook itself is unchanged, so
everything after the HTTP request (streaming handlers, formatting, tool calls, follow-up requests) is the real code.

The server answers `/api/ps`, `/api/version`, `/api/tags`, `/api/show` and `/api/chat`. Chat responses are streamed
as NDJSON in chunks of `--chunk` characters every `--delay` seconds, are cut at the request's stop tokens, and tool
calls are written in whichever format the request expects (Simple `/exec`, `TOOLCALL:`, or native `tool_calls`).

For stress-testing the formatter, a script can also send exact chunks (to choose the split points), fuzzed text with a
logged seed, and `--no-stop` streams text that contains stop tokens.

## Quick start

```bash
python3 Developer/ReplayServer/ollama_replay.py --script Developer/ReplayServer/Scripts/sine-tool.json --log /tmp/replay.jsonl &
```

In a front end with Chatbook loaded:

```wl
Get[ "/path/to/Chatbook/Developer/ReplayServer/ReplayChat.wl" ];
Wolfram`ChatbookReplay`ReplayChatNotebook[ "Plot a sine wave and check that the code works." ]
```
