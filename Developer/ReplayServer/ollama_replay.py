#!/usr/bin/env python3
"""Fake Ollama server that streams scripted chat responses, for testing Chatbook's real chat pipeline without a model.

Chatbook talks to it through LLMServices and the Ollama provider of LLMConnections, which connects to 127.0.0.1:11435
by default (the port this server uses), so a chat only has to select the model:
    "Model" -> <|"Service" -> "Ollama", "Name" -> "replay:latest"|>

It answers the requests LLMServices makes (/api/ps, /api/version, /api/tags, /api/show) and streams /api/chat as NDJSON
in chunks of --chunk characters every --delay seconds.

A script is a JSON file with a list of turns; each turn is a list of steps:
    {"turns": [[step, ...], [step, ...], ...], "chunk": 12, "delay": 0.03}
The turn that answers a request is the number of assistant messages after the last user message (so the first turn
answers the user's prompt, the second answers the first tool result, and so on); the last turn is repeated after that.
"chunk", "delay" and "stop" are optional and override the command line (--chunk, --delay, --no-stop). Steps:
    {"content": "text"}     streamed as message.content in chunks of --chunk characters
                            (write "<think>...</think>" here for inline reasoning)
    {"chunks": ["``", "`wl\\n", "x"]}
                            streamed as message.content, exactly these chunks (to choose the split points)
    {"fuzz": {"seed": 1, "length": 2000, "chunk": [1, 16], "fragments": [...], "extra": [...]}}
                            random content built from Markdown/LaTeX/WL fragments, in random chunk sizes; every key is
                            optional. "fragments" replaces the built-in list, "extra" adds to it. Without a seed each
                            request gets a new one. The log records the seed and the exact chunks of each fuzzed
                            response, so a failure can be replayed with a "chunks" step or the same seed.
    {"thinking": "text"}    streamed as message.thinking (reasoning that the provider reports separately)
    {"pause": 1.5}          wait this many seconds before the next chunk
    {"tool": "wolfram_language_evaluator", "short": "wl", "arguments": {"code": "1 + 1"}}
                            a tool call, written in the format the request asks for, which ends the turn:
                              native tool_calls if the request lists "tools",
                              "TOOLCALL: name\\n{json}\\nENDARGUMENTS\\nENDTOOLCALL" if it stops at ENDTOOLCALL,
                              "/short\\nvalue\\n/exec" if it only stops at "\\n/exec"
Content is cut at the first stop token of the request (options.stop), like a real server, unless stop tokens are
turned off with --no-stop or "stop": false. Turning them off lets any text through, but then a tool call isn't ended
by the server (Chatbook still detects its own end tokens on the client side).
The script file is read again for every chat request, so it can be edited while the server runs.

Usage: ollama_replay.py --script FILE [--port 11435] [--chunk 12] [--delay 0.03] [--no-stop] [--log requests.jsonl]
"""
import argparse
import json
import random
import sys
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MODEL = "replay:latest"
ARGS = None
LOCK = threading.Lock()
COUNT = [0]


def now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def log(entry):
    if ARGS.log:
        with LOCK, open(ARGS.log, "a") as f:
            f.write(json.dumps({"time": time.time(), **entry}) + "\n")


def turn_index(messages):
    """The number of assistant messages after the last user message."""
    n = 0
    for m in reversed(messages):
        if m.get("role") == "user":
            break
        if m.get("role") == "assistant":
            n += 1
    return n


def tool_format(body):
    stops = (body.get("options") or {}).get("stop") or []
    if body.get("tools"):
        return "service"
    if "\n/exec" in stops and "ENDTOOLCALL" not in stops:
        return "simple"
    return "textual"


def tool_text(step, fmt):
    args = step.get("arguments") or {}
    if fmt == "simple":
        if len(args) == 1:
            body = str(next(iter(args.values())))
        else:
            body = "\n".join(f"{k}: {v}" for k, v in args.items())
        return "/" + step.get("short", step["tool"]) + "\n" + body + "\n/exec"
    return "TOOLCALL: " + step["tool"] + "\n" + json.dumps(args) + "\nENDARGUMENTS\nENDTOOLCALL"


# Fragments that fuzz text is built from: Markdown, LaTeX and Wolfram Language syntax that the formatter has to
# recognize, in every combination and split at every point. Stop tokens and tool call syntax are left out (they end
# the response or start a tool call); add them with "extra" when that's what you're testing.
FUZZ_FRAGMENTS = [
    "```", "```wl\n", "```wolfram\n", "```python\n", "\n```\n", "`", "``", "$", "$$", "\\(", "\\)", "\\[", "\\]",
    "|", " | ", "\n|---|---|\n", "| a | b |\n", "**", "*", "_", "__", "~~", "#", "## ", "\n### ", "- ", "\n- ",
    "\n1. ", "\n> ", "<think>", "</think>", "\n<think>\n", "\n</think>\n", "[", "](", ")", "![", "](attachment://",
    "<!", "!>", "\\!\\(\\*", "RowBox[{", "}]", "\\:f442", "\\[Alpha]", "\\[", "Plot[Sin[x], {x, 0, Pi}]", "x^2",
    "\\frac{1}{2}", "\\begin{matrix}", "\\end{matrix}", "{", "}", "[", "]", "\"", "\\", "<", ">", "&", "\n", "\n\n",
    "\n\n\n", " ", "  ", "\t", "word ", "text ", "The answer is ", "1 + 1", "∑", "→", "日本語", "🎉", "👩‍👩‍👧", "é",
    "\u200b", "\u00a0", "\uf3b5",
]


def fuzz_chunks(spec):
    """Random text built from fragments, split into random chunk sizes. Returns (seed, chunks)."""
    seed = spec.get("seed")
    if seed is None:
        seed = random.randrange(2 ** 32)
    rng = random.Random(seed)
    fragments = list(spec.get("fragments") or FUZZ_FRAGMENTS) + list(spec.get("extra") or [])
    length = int(spec.get("length", 2000))
    low, high = spec.get("chunk", [1, 16])
    text = ""
    while len(text) < length:
        text += rng.choice(fragments)
    chunks, i = [], 0
    while i < len(text):
        size = rng.randint(int(low), int(high))
        chunks.append(text[i:i + size])
        i += size
    return seed, chunks


def cut_at_stop(chunks, stops):
    """Cut a list of chunks at the first stop token in their joined text, like a real server. Returns (chunks, cut)."""
    text = "".join(chunks)
    hits = [text.find(s) for s in stops if s and s in text]
    if not hits:
        return chunks, False
    end, out, pos = min(hits), [], 0
    for c in chunks:
        if pos + len(c) >= end:
            if end > pos:
                out.append(c[:end - pos])
            break
        out.append(c)
        pos += len(c)
    return out, True


def plan(steps, fmt, stops, chunk):
    """Expand a turn into a list of ("content"|"thinking", [chunks]), ("pause", seconds) and ("tool_calls", calls)
    parts, applying stop tokens to content. Also returns what was fuzzed, for the log."""
    parts, fuzzed = [], []
    split = lambda text: [text[i:i + chunk] for i in range(0, len(text), chunk)]
    for step in steps:
        if "pause" in step:
            parts.append(("pause", float(step["pause"])))
            continue
        if "thinking" in step:
            parts.append(("thinking", split(step["thinking"])))
            continue
        if "tool" in step and fmt == "service":
            parts.append(("tool_calls", [{"function": {"name": step["tool"],
                                                       "arguments": step.get("arguments") or {}}}]))
            return parts, fuzzed
        if "chunks" in step:
            chunks = [str(c) for c in step["chunks"]]
        elif "fuzz" in step:
            seed, chunks = fuzz_chunks(step["fuzz"] or {})
        elif "content" in step:
            chunks = split(step["content"])
        elif "tool" in step:
            chunks = split(tool_text(step, fmt))
        else:
            continue
        chunks, cut = cut_at_stop(chunks, stops)
        if "fuzz" in step:
            fuzzed.append({"seed": seed, "chunks": chunks, "cutAtStopToken": cut})
        parts.append(("content", chunks))
        if cut or "tool" in step:
            return parts, fuzzed
    return parts, fuzzed


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def send_json(self, obj, status=200):
        data = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def read_body(self):
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n) if n else b""
        try:
            return json.loads(raw or b"{}")
        except json.JSONDecodeError:
            return {"_raw": raw.decode("utf-8", "replace")}

    def do_GET(self):
        log({"method": "GET", "path": self.path})
        if self.path.startswith("/api/ps"):
            self.send_json({"models": []})
        elif self.path.startswith("/api/version"):
            self.send_json({"version": "0.12.0"})
        elif self.path.startswith("/api/tags"):
            self.send_json({"models": [{"name": MODEL, "model": MODEL, "modified_at": now(), "size": 1,
                                        "digest": "0" * 64,
                                        "details": {"format": "gguf", "family": "replay", "parameter_size": "1B",
                                                    "quantization_level": "Q4_0"}}]})
        elif self.path in ("", "/"):
            data = b"Ollama is running"
            self.send_response(200)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_json({"error": "not found"}, 404)

    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_POST(self):
        body = self.read_body()
        if self.path.startswith("/api/chat"):
            self.chat(body)
            return
        log({"method": "POST", "path": self.path, "body": body})
        if self.path.startswith("/api/show"):
            self.send_json({"modelfile": "", "parameters": "", "template": "{{ .Prompt }}",
                            "details": {"format": "gguf", "family": "replay"},
                            "model_info": {"general.architecture": "replay", "replay.context_length": 131072},
                            "capabilities": ["completion", "tools", "thinking"]})
        else:
            self.send_json({"error": "not supported by the replay server"}, 404)

    def chat(self, body):
        with LOCK:
            COUNT[0] += 1
            n = COUNT[0]
        with open(ARGS.script) as f:
            script = json.load(f)
        turns = script["turns"]
        messages = body.get("messages") or []
        index = min(turn_index(messages), len(turns) - 1)
        fmt = tool_format(body)
        stops = (body.get("options") or {}).get("stop") or []
        if ARGS.no_stop or script.get("stop") is False:
            stops = []
        chunk = max(1, int(script.get("chunk", ARGS.chunk)))
        delay = float(script.get("delay", ARGS.delay))
        parts, fuzzed = plan(turns[index], fmt, stops, chunk)
        entry = {"method": "POST", "path": "/api/chat", "n": n, "turn": index, "toolFormat": fmt,
                 "stream": body.get("stream"), "think": body.get("think"), "options": body.get("options"),
                 "roles": [m.get("role") for m in messages], "last": str((messages or [{}])[-1].get("content"))[:300]}
        if fuzzed:
            # Everything needed to replay this response exactly: the seeds, and the chunks as a "chunks" step.
            entry["fuzz"] = fuzzed
        log(entry)
        model = body.get("model") or MODEL
        if body.get("stream", True) is False:
            msg = {"role": "assistant", "content": "".join("".join(v) for k, v in parts if k == "content")}
            thinking = "".join("".join(v) for k, v in parts if k == "thinking")
            if thinking:
                msg["thinking"] = thinking
            calls = [c for k, v in parts if k == "tool_calls" for c in v]
            if calls:
                msg["tool_calls"] = calls
            self.send_json({"model": model, "created_at": now(), "message": msg, "done": True,
                            "done_reason": "stop", "prompt_eval_count": 100, "eval_count": 10})
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()
        count = 0
        try:
            for kind, value in parts:
                if kind == "pause":
                    time.sleep(value)
                    continue
                if kind == "tool_calls":
                    self.write_chunk({"model": model, "created_at": now(), "done": False,
                                      "message": {"role": "assistant", "content": "", "tool_calls": value}})
                    count += 1
                    continue
                for piece in value:
                    msg = {"role": "assistant", "content": ""}
                    msg[kind] = piece
                    self.write_chunk({"model": model, "created_at": now(), "message": msg, "done": False})
                    count += 1
                    time.sleep(delay)
            self.write_chunk({"model": model, "created_at": now(), "message": {"role": "assistant", "content": ""},
                              "done": True, "done_reason": "stop", "total_duration": 1, "load_duration": 1,
                              "prompt_eval_count": 100, "prompt_eval_duration": 1, "eval_count": count,
                              "eval_duration": 1})
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            log({"event": "client closed", "n": n, "chunks": count})
            return
        log({"event": "done", "n": n, "chunks": count})

    def write_chunk(self, obj):
        data = (json.dumps(obj) + "\n").encode()
        self.wfile.write(b"%x\r\n%s\r\n" % (len(data), data))
        self.wfile.flush()


def main():
    global ARGS
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--script", required=True, help="JSON script of the responses (see above)")
    p.add_argument("--port", type=int, default=11435)
    p.add_argument("--chunk", type=int, default=12, help="characters per streamed chunk (default: %(default)s)")
    p.add_argument("--delay", type=float, default=0.03, help="seconds between chunks (default: %(default)s)")
    p.add_argument("--no-stop", action="store_true",
                   help="ignore the stop tokens of requests, so that any text can be streamed")
    p.add_argument("--log", help="append one JSON line per request to this file")
    ARGS = p.parse_args()
    with open(ARGS.script) as f:
        json.load(f)["turns"]
    server = ThreadingHTTPServer(("127.0.0.1", ARGS.port), Handler)
    print(f"replay server on 127.0.0.1:{ARGS.port}", file=sys.stderr, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
