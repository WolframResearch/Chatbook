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
"chunk" and "delay" are optional and override the command line. Steps:
    {"content": "text"}     streamed as message.content (write "<think>...</think>" here for inline reasoning)
    {"thinking": "text"}    streamed as message.thinking (reasoning that the provider reports separately)
    {"pause": 1.5}          wait this many seconds before the next chunk
    {"tool": "wolfram_language_evaluator", "short": "wl", "arguments": {"code": "1 + 1"}}
                            a tool call, written in the format the request asks for, which ends the turn:
                              native tool_calls if the request lists "tools",
                              "TOOLCALL: name\\n{json}\\nENDARGUMENTS\\nENDTOOLCALL" if it stops at ENDTOOLCALL,
                              "/short\\nvalue\\n/exec" if it only stops at "\\n/exec"
Content is cut at the first stop token of the request (options.stop), like a real server.
The script file is read again for every chat request, so it can be edited while the server runs.

Usage: ollama_replay.py --script FILE [--port 11435] [--chunk 12] [--delay 0.03] [--log requests.jsonl]
"""
import argparse
import json
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


def plan(steps, fmt, stops):
    """Expand a turn into a list of ("content"|"thinking"|"pause"|"tool_calls", value) parts, applying stop tokens."""
    parts = []
    for step in steps:
        if "pause" in step:
            parts.append(("pause", float(step["pause"])))
        elif "thinking" in step:
            parts.append(("thinking", step["thinking"]))
        elif "content" in step or "tool" in step:
            if "tool" in step and fmt == "service":
                parts.append(("tool_calls", [{"function": {"name": step["tool"],
                                                           "arguments": step.get("arguments") or {}}}]))
                return parts
            text = step["content"] if "content" in step else tool_text(step, fmt)
            hits = [text.find(s) for s in stops if s and s in text]
            if hits:
                parts.append(("content", text[:min(hits)]))
                return parts
            parts.append(("content", text))
            if "tool" in step:
                return parts
    return parts


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
        parts = plan(turns[index], fmt, stops)
        chunk = int(script.get("chunk", ARGS.chunk))
        delay = float(script.get("delay", ARGS.delay))
        log({"method": "POST", "path": "/api/chat", "n": n, "turn": index, "toolFormat": fmt,
             "stream": body.get("stream"), "think": body.get("think"), "options": body.get("options"),
             "roles": [m.get("role") for m in messages], "last": str((messages or [{}])[-1].get("content"))[:300]})
        model = body.get("model") or MODEL
        if body.get("stream", True) is False:
            msg = {"role": "assistant", "content": "".join(v for k, v in parts if k == "content")}
            thinking = "".join(v for k, v in parts if k == "thinking")
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
                for i in range(0, len(value), chunk):
                    msg = {"role": "assistant", "content": ""}
                    msg[kind] = value[i:i + chunk]
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
