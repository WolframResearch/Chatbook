#!/usr/bin/env python3
"""Scripted ACP (Agent Client Protocol) v1 mock agent for the ACPLink tests.

The mock speaks newline-delimited JSON-RPC 2.0 over stdin/stdout and uses the
Python 3 standard library only.  It is driven by JSON *scenario* files, so test
authors add behavior by adding files under Tests/MockAgent/scenarios/ (or a
directory passed with --scenario-dir) instead of editing this script.

Command line
------------
    python3 mock_acp_agent.py [--log FILE] [--scenario NAME] [--scenario-dir DIR]...
                              [--idle-timeout SEC] [--max-lifetime SEC]
                              [--ignore-eof] [--eof-exit-delay SEC] [--ignore-sigterm]
                              [--stdout-noise TEXT] [--start-delay SEC] [--stderr-line TEXT]...
                              [--stderr-split-delay SEC] [--exit-after-start CODE] [--preamble-lines N]

  --log FILE          append a JSON-lines wire log to FILE (see "Wire log" below)
  --scenario NAME     the process-wide scenario: its "agent" and "methods"
                      sections configure the agent, and its "steps" are the
                      default prompt scenario (default: base-hello)
  --scenario-dir DIR  extra directory searched (first) for NAME.json; repeatable
  --idle-timeout SEC  exit (code 124) after SEC seconds without any traffic (default 120)
  --max-lifetime SEC  exit (code 124) after SEC seconds no matter what (default 900)
  --ignore-eof        keep running when stdin reaches EOF (default: exit 0 on EOF)
  --eof-exit-delay S  on EOF, wait S seconds before exiting (default 0)
  --ignore-sigterm    log SIGTERM but keep running (default: log it and exit 143)

Launch phase (for ACPLink's "StandardInputPreamble" and "StandardInputPreambleTrigger"); it runs before the
reader starts, in this order:
  --stdout-noise TEXT     print TEXT and a newline on stdout first (a chatty login shell; not JSON)
  --start-delay SEC       then sleep SEC seconds (a launcher that is still connecting; default 0)
  --stderr-line TEXT      then print TEXT and a newline on stderr, flushed; repeatable, in order.  Each write is
                          logged before it happens, as {"event": "stderr_write", "text", "stdinPending"}, where
                          stdinPending is the number of bytes already waiting on stdin (0: nothing has been
                          written to the mock yet; -1: unknown)
  --stderr-split-delay S  write each --stderr-line in two halves; S seconds pass before every write but the first
  --exit-after-start CODE then log {"event": "stdin_check", "stdinPending"} and exit with CODE without reading stdin
  --preamble-lines N      then read N lines from stdin, with the same buffered stdin object the reader uses (so
                          nothing is lost), and log {"event": "preamble", "lines": [UTF-8 text], "base64": [raw]}
The first line read from stdin (preamble or message) is logged as {"event": "first_stdin"}; compare its "t" with
those of the stderr_write records.

Built-in methods
----------------
initialize, authenticate, session/new, session/load (replays history, including
tool calls), session/resume, session/fork, session/list, session/close,
session/delete, session/set_config_option, session/set_mode, session/prompt
(runs a scenario), session/cancel (notification).  Unknown requests get -32601.
Responses from the client to the mock's own requests are matched by id.

Sessions (emulating OpenCode 2.0.26 where it matters for a session list UI):
  session/new, session/fork  ids sess-1, sess-2, ...; "updatedAt" is the creation
                 time (ISO 8601 UTC with milliseconds, strictly increasing); the
                 title is agent.sessionTitle ("${createdAt}" substituted; OpenCode's
                 is "New session - ${createdAt}"), or none (the default).
  session/list   the sessions of this process plus agent.sessions (minus deleted
                 ones), newest "updatedAt" first (rows without one last).  "cwd"
                 filters by exact string match (a relative cwd is -32602);
                 agent.listPageSize > 0 pages with an opaque "nextCursor" (a bad
                 cursor is -32602); agent.listCursorOnLastPage makes a non-empty
                 last page carry a nextCursor too (to an empty page), as OpenCode does.
  session/load   replays agent.histories[sessionId], else agent.history (or what
                 recordHistory recorded), as session/update notifications, then
                 responds, then sends available_commands_update.  A session of
                 agent.sessions keeps its listed cwd, title and updatedAt.
  session/resume like load, without the replay.
  session/delete removes the session from the list (unknown ids: {} as well).
  agent.strictSessions: load/resume/fork of an unknown (or deleted) session is
                 -32602 "session not found", and one whose cwd differs from the
                 session's (trailing slashes ignored) is -32602 "does not belong
                 to cwd", like OpenCode; otherwise any id is accepted.
  agent.recordHistory: each prompt records a user_message_chunk and its session's
                 message/thought chunks (merged per message) and tool calls (a
                 tool_call plus one tool_call_update with the merged final state),
                 which a later session/load replays instead of agent.history.
  agent.titleFromPrompt: the first prompt of a session that has no title (or the
                 sessionTitle one) sets the title to the prompt text (50 chars).
  Prompts, session/set_config_option and session/set_mode update "updatedAt".
  MCP servers:   session/new and session/fork store the request's "mcpServers" with
                 the session (a fork without them keeps its source's), and session/load
                 and session/resume replace them if the request has the key; the
                 mcp_request step calls them.

Selecting a scenario for a prompt
---------------------------------
If the first word of the first text block of a session/prompt is
"scenario:<name>", the steps of <name>.json run for that prompt; otherwise the
steps of the --scenario scenario run.  Each prompt runs in its own thread, so the
mock keeps answering other requests (set_config_option, cancel, ...) meanwhile.

Scenario file format
--------------------
    {
      "description": "free text",
      "agent":   { ...overrides of DEFAULT_AGENT (initialize result, configOptions,
                   modes, availableCommands, history, histories, sessions,
                   listPageSize, listCursorOnLastPage, sessionTitle,
                   titleFromPrompt, recordHistory, strictSessions)... },
      "methods": { "<method>": {"result": {...}} | {"error": {"code": c, "message": m}}
                               | {"steps": [...]} },
      "steps":   [ step, ... ]
    }

"agent" and "methods" are only honored for the --scenario scenario.

Step types (every step also accepts "when" and "end"; see below):
  notify         {"update": {...}, "sessionId"?: sid, "repeat"?: n}
                 or {"method": m, "params": {...}} for an arbitrary notification
  request        {"method"?: "session/request_permission", "params"?: {...},
                  "as"?: name, "collide"?: bool, "id"?: explicit id,
                  "toolCallId"?, "title"?, "kind"?}
                 Ids count up from 0 like the ACP TypeScript SDK; "collide": true
                 reuses the id of the in-flight session/prompt.  Without "params"
                 a session/request_permission with options once/always/reject is sent.
  wait_response  {"request"?: name (default: the last request), "timeout"?: 30}
  wait_cancel    {"timeout"?: 30}   waits for session/cancel for this session
  on_cancel      {"cancel_requests"?: true, "delay"?: 0.03, "stopReason"?: "cancelled",
                  "respond"?: true, "steps"?: [...]}
                 Registers a cancel handler.  When session/cancel arrives (at any
                 later wait or between steps) the mock sends $/cancel_request for
                 each of its unanswered requests, runs "steps", responds to the
                 prompt with stopReason "cancelled", and ends the scenario.
  respond        {"result"?: {...}, "stopReason"?: s, "id"?: id}
                 Default result {"stopReason": "end_turn"}; "stopReason": "auto"
                 means "cancelled" if this prompt was cancelled, else "end_turn".
  respond_error  {"code"?: -32603, "message"?: "...", "data"?: ..., "id"?: id}
  delay          {"seconds": s}     (interrupted by cancel only after on_cancel)
  late_notify    {"delay"?: 0.5, "update": {...}}   notify after a delay; meant
                 for notifications that arrive after the prompt response
  send           {"message": <any JSON value>}      written as one line, verbatim
  raw            {"text": "...", "newline"?: true}  raw bytes, no JSON check
  stderr_spam    {"bytes"?: 100000, "line"?: "...", "background"?: false}
  slow_writer    {"interval"?: 3, "count"?: 3, "update"?: {...} | "method"/"params",
                  "split"?: 1, "chunk_delay"?: 0, "background"?: false}
                 one notification every interval seconds; "split": k writes each
                 line in k pieces, chunk_delay seconds apart
  spawn_child    {"name"?: s, "lifetime"?: 120, "depth"?: 1, "inherit_stdio"?: false}
                 a child in the mock's process group (depth 2 adds a grandchild)
  spawn_detached same, but the child gets its own session (start_new_session=True)
  mark           {"label": s}       writes an event to the wire log
  replay         {"interval"?: 0}   replays the session's history (as session/load
                 does), "interval" seconds between the updates; for "methods"
                 overrides of session/load (e.g. a slow replay, or one that fails)
  mcp_request    {"method": m, "params"?: {...}, "server"?: name, "as"?: name, "id"?: id,
                  "headers"?: {name: value | null}, "timeout"?: 30, "initialized"?: true}
                 Sends one JSON-RPC message to an MCP server of the session over MCP's
                 Streamable HTTP transport, the way OpenCode does, and waits for the
                 answer.  "server" names one of the session's "mcpServers" (see
                 Sessions; a run without a session uses the "mcpServers" of its own
                 request); the default is the first one of type "http".  The message is
                 a notification if m starts with "notifications/", else a request whose
                 id counts up from 0 (or is "id").  Without "params" the message has
                 none, except initialize: {"protocolVersion": "2025-11-25",
                 "capabilities": {}, "clientInfo": {"name": "mock-acp-agent", ...}}.
                 The POST has Content-Type application/json, Accept "application/json,
                 text/event-stream", the server's "headers", MCP-Protocol-Version (the
                 one negotiated by a successful initialize of this session and server;
                 never on initialize itself), and no Origin; "headers" then sets
                 (value) or removes (null) headers, by case-insensitive name.  The body
                 of the answer is read as JSON, or as an event stream (comments are
                 counted; the "message" event that answers the request is the
                 response, other "message" events are kept), and logged as an
                 mcp_response event (any HTTP status) or an mcp_error event (no HTTP
                 answer, "timeout" seconds passed, the step was cancelled, a 2xx
                 answer that is not a JSON-RPC message or an event stream that ends
                 without the response).  A request that times out or is cancelled (see
                 on_cancel) is followed by notifications/cancelled; a successful
                 initialize by notifications/initialized (unless "initialized": false).
                 Those notifications are logged like the step's own messages but get
                 "as": null.  Connections are HTTP/1.1 keep-alive connections, reused
                 by later steps (one retry on a fresh one when a reused one turns out
                 to be closed); proxies are never used.  MCP traffic counts as traffic
                 for --idle-timeout.
  exit           {"code"?: 0, "delay"?: 0}

"when" makes a step conditional:
  "when": "cancelled" | "not_cancelled"
  "when": {"cancelled": bool, "request": name, "outcome": "selected" | "cancelled" |
           "error" | "timeout" | [...], "optionId": id | [...], "responded": bool}
"end": true stops the scenario after that step.

String values of the form "${name}" are replaced (keeping the JSON type) by:
sessionId, promptId, lastRequestId, promptText, cwd, i (the "repeat" index),
pid; "${bytes:N}" becomes a string of N "x" characters.  "${name}" inside a longer
string is replaced textually (an object or array as JSON text).
The answers of earlier mcp_request steps of the same run are available as
"${mcpText:as}", "${mcpResult:as}" and "${mcpStatus:as}" ("as" is the step's
"as"; without ":as", the last mcp_request step):
  mcpText    the result's text: its "content" text blocks joined by newlines, or
             the JSON text of a result without "content"; for a JSON-RPC error its
             message, for mcp_error the error, else the body's text ("" if none)
  mcpResult  the JSON-RPC "result" (null if there is none)
  mcpStatus  the HTTP status (null for an mcp_error without an HTTP answer)

Wire log
--------
One JSON object per line: {"seq": n, "t": unixTime, "dir": d, ...} where d is
  "in"     {"msg": message received from the client}  ({"raw": text} if unparsable)
  "out"    {"msg": message sent to the client}         ({"raw": text} for raw steps)
  "event"  {"event": name, ...}: start, eof, exit, sigterm, scenario, scenario_end,
           cancel_seen, cancel_request_sent, wait_response, spawn, unexpected_response,
           duplicate_response, response_after_cancel_request, watchdog, mark, error,
           stderr_write, stdin_check, preamble, first_stdin, and those of mcp_request:
  mcp_request   {"as", "server", "method", "id", "url", "protocolVersion"}: before the POST
                ("id" null for a notification, "protocolVersion" the header sent or null)
  mcp_response  {"as", "server", "method", "id", "status", "contentType", "body",
                 "sse", "seconds"}: "body" is the JSON-RPC response (from the event
                stream, or the parsed JSON body), the body text if it is not JSON, or
                null if there is none (202); "sse" is null for a body that is not an
                event stream, else {"comments": number of comment lines,
                "messages": [the other "message" events, parsed]}
  mcp_error     {"as", "server", "method", "id", "error", "seconds"}, plus "status",
                "contentType", "body", "sse" (and "text", the body's text, if a body
                that is not an event stream is the problem) if an HTTP answer came
Out records are written before the bytes go to stdout.
"""

import argparse
import base64
import copy
import datetime
import http.client
import json
import os
import queue
import re
import signal
import socket
import subprocess
import sys
import threading
import time
import traceback
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SCENARIO_DIR = os.path.join(HERE, "scenarios")

DEFAULT_CONFIG_OPTIONS = [
    {"id": "model", "name": "Model", "category": "model", "type": "select", "currentValue": "m1",
     "options": [{"value": "m1", "name": "Model One"}, {"value": "m2", "name": "Model Two"}]},
    {"id": "effort", "name": "Effort", "category": "thought_level", "type": "select", "currentValue": "default",
     "options": [{"value": "default", "name": "Default"}, {"value": "high", "name": "High"}]},
    {"id": "mode", "name": "Session Mode", "category": "mode", "type": "select", "currentValue": "build",
     "options": [{"value": "build", "name": "Build"}, {"value": "plan", "name": "Plan"}]},
]

DEFAULT_AGENT = {
    "protocolVersion": 1,
    "agentCapabilities": {
        "loadSession": True,
        "promptCapabilities": {"image": True, "audio": False, "embeddedContext": True},
        "mcpCapabilities": {"http": True, "sse": False},
        "sessionCapabilities": {"close": {}, "list": {}, "resume": {}, "fork": {}, "delete": {},
                                "additionalDirectories": {}},
    },
    "authMethods": [],
    "agentInfo": {"name": "MockACPAgent", "title": "Mock ACP Agent", "version": "1.0.0"},
    "configOptions": DEFAULT_CONFIG_OPTIONS,
    "modes": {"currentModeId": "build",
              "availableModes": [{"id": "build", "name": "Build"}, {"id": "plan", "name": "Plan"}]},
    "availableCommands": [{"name": "init", "description": "guided setup"},
                          {"name": "review", "description": "review changes", "input": {"hint": "[branch]"}}],
    # replayed by session/load (as session/update notifications for the loaded session), in the shape OpenCode
    # replays a stored session: one user_message_chunk per user message (with its messageId), a tool call as a
    # pending tool_call (with rawInput) at once followed by one tool_call_update with its final state, one
    # agent_message_chunk per text part (with its own messageId); nothing marks the end of a turn
    "history": [
        {"sessionUpdate": "user_message_chunk", "messageId": "msg_old_user_1",
         "content": {"type": "text", "text": "old question"}},
        {"sessionUpdate": "tool_call", "toolCallId": "call_old", "name": "read", "title": "Read a.txt", "kind": "read",
         "status": "pending", "locations": [{"path": "/tmp/a.txt"}], "rawInput": {"path": "/tmp/a.txt"}},
        {"sessionUpdate": "tool_call_update", "toolCallId": "call_old", "status": "completed",
         "locations": [{"path": "/tmp/a.txt"}],
         "content": [{"type": "content", "content": {"type": "text", "text": "old file contents"}}],
         "rawOutput": {"output": "old file contents"}},
        {"sessionUpdate": "agent_message_chunk", "messageId": "msg_old_agent_1",
         "content": {"type": "text", "text": "old answer"}},
    ],
    # per-session replays, {sessionId: [update, ...]}; sessions without an entry replay "history"
    "histories": {},
    # listed by session/list in addition to the sessions created in this process
    "sessions": [{"sessionId": "old-1", "cwd": "/tmp", "title": "Old session",
                  "updatedAt": "2026-01-01T00:00:00Z"}],
    "listPageSize": 0,              # session/list page size; 0: everything on one page
    "listCursorOnLastPage": False,  # a non-empty last page has a nextCursor too (OpenCode)
    "sessionTitle": None,           # title of created sessions; "${createdAt}" is substituted
    "titleFromPrompt": False,       # the first prompt titles an untitled session
    "recordHistory": False,         # prompts record what session/load replays
    "strictSessions": False,        # load/resume/fork check the session and its cwd (OpenCode)
}

# session/update kinds that recordHistory records (OpenCode replays only messages, thoughts and tool calls)
RECORDED_UPDATES = ("user_message_chunk", "agent_message_chunk", "agent_thought_chunk", "tool_call", "tool_call_update")

# the initialize params of mcp_request steps without "params" (OpenCode 2.0.26 asks for 2025-11-25)
MCP_INITIALIZE_PARAMS = {"protocolVersion": "2025-11-25", "capabilities": {},
                         "clientInfo": {"name": "mock-acp-agent", "version": "1.0.0"}}

# errors of a request on a kept-alive connection that the server had closed meanwhile (retried on a new connection;
# http.client.RemoteDisconnected is a ConnectionResetError)
STALE_CONNECTION_ERRORS = (ConnectionResetError, ConnectionAbortedError, BrokenPipeError)

# seconds that the notifications/cancelled after a timed out or cancelled mcp_request may take at most
MCP_CANCEL_TIMEOUT = 5.0

# seconds that the rest of an event stream may take after the response (then the connection is not reused)
MCP_DRAIN_TIMEOUT = 2.0


def iso_utc(ms):
    """ISO 8601 UTC with milliseconds, like OpenCode's updatedAt: 2026-10-11T05:05:38.554Z."""
    t = datetime.datetime.fromtimestamp(ms / 1000.0, tz=datetime.timezone.utc)
    return t.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (ms % 1000)


def iso_to_seconds(s):
    """Seconds since the epoch of an ISO 8601 string, or None."""
    if not isinstance(s, str):
        return None
    try:
        t = datetime.datetime.fromisoformat(s[:-1] + "+00:00" if s.endswith("Z") else s)
    except ValueError:
        return None
    if t.tzinfo is None:
        t = t.replace(tzinfo=datetime.timezone.utc)
    return t.timestamp()


def encode_cursor(offset):
    """An opaque cursor (base64url JSON, like OpenCode's)."""
    raw = json.dumps({"offset": offset}, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def decode_cursor(cursor):
    """The offset of a cursor made by encode_cursor, or None."""
    if not isinstance(cursor, str) or not cursor:
        return None
    try:
        data = json.loads(base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)).decode("utf-8"))
    except Exception:
        return None
    offset = data.get("offset") if isinstance(data, dict) else None
    if isinstance(offset, bool) or not isinstance(offset, int) or offset < 0:
        return None
    return offset


def same_directory(a, b):
    """cwd comparison of session/load: exact, except for trailing slashes (OpenCode normalizes them)."""
    def norm(d):
        return (d.rstrip("/") or "/") if isinstance(d, str) else d
    return norm(a) == norm(b)


def idkey(rid):
    """Key for a JSON-RPC id that keeps 0 and "0" apart."""
    return json.dumps(rid)


class CancelledRun(Exception):
    pass


class EndRun(Exception):
    pass


class WireLog(object):
    def __init__(self, path):
        self.lock = threading.Lock()
        self.seq = 0
        self.f = open(path, "a", encoding="utf-8") if path else None

    def write(self, direction, **kw):
        if self.f is None:
            return
        with self.lock:
            self.seq += 1
            rec = {"seq": self.seq, "t": round(time.time(), 4), "dir": direction}
            rec.update(kw)
            try:
                self.f.write(json.dumps(rec, separators=(",", ":")) + "\n")
                self.f.flush()
            except Exception:
                pass

    def event(self, event_name, /, **kw):
        kw["event"] = event_name
        self.write("event", **kw)


def parse_json(text):
    """(value, True) for JSON text, (text, False) otherwise."""
    try:
        return json.loads(text), True
    except ValueError:
        return text, False


def close_quietly(conn):
    """Close an http.client connection; the shutdown also ends a read that another thread is blocked in."""
    sock = conn.sock
    if sock is not None:
        try:
            sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
    try:
        conn.close()
    except Exception:
        pass


def mcp_substitution(kind, rec):
    """The value of "${mcpText:...}", "${mcpResult:...}" or "${mcpStatus:...}" for the record of an mcp_request."""
    body = rec.get("body")
    result = body.get("result") if isinstance(body, dict) else None
    if kind == "mcpStatus":
        return rec.get("status")
    if kind == "mcpResult":
        return result
    if rec.get("event") == "mcp_error":
        return rec.get("error", "")
    if isinstance(result, dict) and isinstance(result.get("content"), list):
        return "\n".join(str(c.get("text", "")) for c in result["content"]
                         if isinstance(c, dict) and c.get("type") == "text")
    if isinstance(body, dict) and "result" in body:
        return json.dumps(result, separators=(",", ":"), ensure_ascii=False)
    if isinstance(body, dict) and isinstance(body.get("error"), dict):
        return str(body["error"].get("message", ""))
    if body is None:
        return ""
    return body if isinstance(body, str) else json.dumps(body, separators=(",", ":"), ensure_ascii=False)


class MCPExchange(object):
    """One JSON-RPC message POSTed to a Streamable HTTP MCP server, and its answer (the mcp_request step).

    run() does the HTTP work in a worker thread and sets done (notifying agent.cond) once the body has been read to its
    end and the connection is back in the agent's pool, so that the next exchange reuses it (the rest of an event
    stream has MCP_DRAIN_TIMEOUT seconds after the response; then the connection is closed instead).  abort() shuts
    the connection down, which ends a read that is still blocked."""

    def __init__(self, agent, url, headers, message, timeout):
        self.agent = agent
        self.url = url
        self.headers = headers
        self.message = message
        self.timeout = timeout
        self.lock = threading.Lock()
        self.conn = None
        self.aborted = False
        self.done = False
        self.answer = None      # {"status", "contentType", "body", "sse"}, with "error" (and "text") if it failed

    def start(self):
        threading.Thread(target=self.run, daemon=True).start()

    def finish(self, answer):
        with self.agent.cond:
            if not self.done:
                self.done = True
                self.answer = answer
            self.agent.cond.notify_all()

    def abort(self):
        with self.lock:
            self.aborted = True
            conn = self.conn
        if conn is not None:
            close_quietly(conn)

    def run(self):
        try:
            self.finish(self.exchange())
        except Exception as e:
            with self.lock:
                conn, self.conn = self.conn, None
            if conn is not None:
                close_quietly(conn)
            self.finish({"error": "%s: %s" % (type(e).__name__, e)})

    def exchange(self):
        parts = urllib.parse.urlsplit(self.url if isinstance(self.url, str) else "")
        if parts.scheme not in ("http", "https") or not parts.hostname:
            return {"error": "not an http(s) URL: %r" % (self.url,)}
        key = (parts.scheme, parts.hostname, parts.port)
        target = (parts.path or "/") + ("?" + parts.query if parts.query else "")
        body = json.dumps(self.message, separators=(",", ":")).encode("utf-8")
        for reuse in (True, False):
            conn, reused = self.agent.mcp_connection(key, self.timeout, reuse)
            with self.lock:
                if self.aborted:
                    close_quietly(conn)
                    return {"error": "aborted"}
                self.conn = conn
            try:
                conn.request("POST", target, body=body, headers=self.headers)
                resp = conn.getresponse()
                break
            except STALE_CONNECTION_ERRORS:
                close_quietly(conn)
                if not reused or self.aborted:
                    raise
        ctype = resp.getheader("Content-Type")
        mime = (ctype or "").split(";")[0].strip().lower()
        answer = {"status": resp.status, "contentType": ctype, "body": None, "sse": None}
        if mime == "text/event-stream":
            complete = self.read_event_stream(resp, conn, answer)
        else:
            complete = self.read_body(resp, mime, answer)
        with self.lock:
            keep = complete and not self.aborted and not resp.will_close
            self.conn = None
        if keep:
            self.agent.mcp_release(key, conn)
        else:
            close_quietly(conn)
        return answer

    def read_body(self, resp, mime, answer):
        """Read a body that is not an event stream (a 2xx answer to a request must be one JSON-RPC message); returns
        True: the body was read completely."""
        data = resp.read()
        text = data.decode("utf-8", "replace")
        body, is_json = parse_json(text) if data else (None, True)
        answer["body"] = body
        if 200 <= resp.status < 300 and "id" in self.message:
            if not data:
                answer.update(error="the %d answer has no body" % resp.status, text=text)
            elif mime != "application/json":
                answer.update(error="the %d answer has the Content-Type %r" % (resp.status, answer["contentType"]),
                              text=text)
            elif not (is_json and isinstance(body, dict)):
                answer.update(error="the %d answer is not a JSON-RPC message" % resp.status, text=text)
        return True

    def read_event_stream(self, resp, conn, answer):
        """Read an event stream up to its end; returns True if it was read completely.  The "message" event that
        answers the request is the response; after it the rest of the stream has MCP_DRAIN_TIMEOUT seconds."""
        rid = self.message.get("id")
        request = "id" in self.message
        sse = answer["sse"] = {"comments": 0, "messages": []}
        response = None
        drain_deadline = None
        data, kind = [], "message"
        while not self.aborted:
            if drain_deadline is not None:
                remaining = drain_deadline - time.time()
                if remaining <= 0 or conn.sock is None:
                    return False
                conn.sock.settimeout(remaining)
            try:
                line = resp.readline()
            except socket.timeout:
                if response is None:
                    raise
                return False
            if not line:
                break
            self.agent.touch()
            line = line.decode("utf-8", "replace").rstrip("\r\n")
            if not line:  # the end of an event
                if data and kind == "message" and response is None:
                    msg = parse_json("\n".join(data))[0]
                    if (request and isinstance(msg, dict) and msg.get("id") == rid
                            and ("result" in msg or "error" in msg)):
                        response = answer["body"] = msg
                        drain_deadline = time.time() + MCP_DRAIN_TIMEOUT
                    else:
                        sse["messages"].append(msg)
                data, kind = [], "message"
            elif line.startswith(":"):
                if response is None:
                    sse["comments"] += 1
            else:
                field, _, value = line.partition(":")
                value = value[1:] if value.startswith(" ") else value
                if field == "event":
                    kind = value
                elif field == "data":
                    data.append(value)
        if response is None and request:
            answer["error"] = "the event stream ended without the response"
        return not self.aborted


class Agent(object):
    def __init__(self, args):
        self.args = args
        self.log = WireLog(args.log)
        self.stdin = sys.stdin.buffer   # one buffered object for the preamble and the reader, so nothing is lost
        self.first_stdin_seen = False
        self.scenario_dirs = list(args.scenario_dir or []) + [DEFAULT_SCENARIO_DIR]
        self.out_lock = threading.Lock()
        self.cond = threading.Condition(threading.RLock())
        self.requests = queue.Queue()
        self.next_request_id = 0
        self.pending = {}           # idkey -> {"id", "method", "response", "cancel_requested"}
        self.sessions = {}          # sid -> {"cwd", "configOptions", "modes", "closed", "title", "updatedAt", ...}
        self.deleted = set()        # ids deleted with session/delete (no longer listed, not found when strict)
        self.session_counter = 0
        self.message_counter = 0    # messageIds that recordHistory makes up
        self.last_ms = 0            # the last updatedAt handed out (they strictly increase)
        self.cancel_counts = {}     # sid -> number of session/cancel notifications received
        self.next_mcp_id = 0        # ids of the mcp_request requests (one counter for every MCP server)
        self.mcp_versions = {}      # (sid, MCP server name) -> protocol version negotiated by initialize
        self.mcp_idle = {}          # (scheme, host, port) -> kept-alive HTTP connections not in use
        self.last_activity = time.time()
        self.started = time.time()
        self.global_scenario = self.load_scenario(args.scenario) if args.scenario else None
        if self.global_scenario is None:
            self.global_scenario = self.load_scenario("base-hello") or {"steps": [{"type": "respond"}]}
        self.agent_config = copy.deepcopy(DEFAULT_AGENT)
        self.agent_config.update(copy.deepcopy(self.global_scenario.get("agent", {})))
        self.method_overrides = self.global_scenario.get("methods", {})

    # ------------------------------------------------------------------ io
    def touch(self):
        self.last_activity = time.time()

    def exit(self, code, reason):
        self.log.event("exit", code=code, reason=reason)
        try:
            sys.stdout.flush()
            sys.stderr.flush()
        except Exception:
            pass
        os._exit(code)

    def write_bytes(self, data):
        try:
            sys.stdout.buffer.write(data)
            sys.stdout.buffer.flush()
        except (BrokenPipeError, OSError, ValueError):
            self.exit(0, "broken pipe")

    def send(self, obj):
        line = json.dumps(obj, separators=(",", ":")) + "\n"
        with self.out_lock:
            self.log.write("out", msg=obj)
            self.write_bytes(line.encode("utf-8"))
        self.touch()

    def send_raw(self, text, newline=True):
        data = text + ("\n" if newline else "")
        with self.out_lock:
            self.log.write("out", raw=data)
            self.write_bytes(data.encode("utf-8"))
        self.touch()

    def send_split(self, obj, pieces, chunk_delay):
        data = (json.dumps(obj, separators=(",", ":")) + "\n").encode("utf-8")
        pieces = max(1, min(int(pieces), len(data)))
        size = (len(data) + pieces - 1) // pieces
        with self.out_lock:
            self.log.write("out", msg=obj, split=pieces)
            for k in range(0, len(data), size):
                self.write_bytes(data[k:k + size])
                if k + size < len(data) and chunk_delay > 0:
                    time.sleep(chunk_delay)
        self.touch()

    def respond(self, rid, result):
        self.send({"jsonrpc": "2.0", "id": rid, "result": result})

    def respond_error(self, rid, code, message, data=None):
        err = {"code": code, "message": message}
        if data is not None:
            err["data"] = data
        self.send({"jsonrpc": "2.0", "id": rid, "error": err})

    def notify_update(self, sid, update, record=True):
        if record:
            self.record_update(sid, update)
        self.send({"jsonrpc": "2.0", "method": "session/update", "params": {"sessionId": sid, "update": update}})

    # ------------------------------------------------------------ scenarios
    def load_scenario(self, name):
        if not isinstance(name, str) or not re.match(r"^[A-Za-z0-9_.\-]+$", name):
            return None
        for d in self.scenario_dirs:
            path = os.path.join(d, name + ".json")
            if os.path.isfile(path):
                try:
                    with open(path, encoding="utf-8") as f:
                        scen = json.load(f)
                    scen.setdefault("name", name)
                    return scen
                except Exception as e:
                    self.log.event("error", where="load_scenario", scenario=name, error=repr(e))
                    return None
        return None

    # ----------------------------------------------------- outbound requests
    def alloc_request_id(self):
        with self.cond:
            rid = self.next_request_id
            self.next_request_id += 1
            return rid

    def register_request(self, rid, method):
        with self.cond:
            self.pending[idkey(rid)] = {"id": rid, "method": method, "response": None, "cancel_requested": False}

    def deliver_response(self, msg):
        with self.cond:
            p = self.pending.get(idkey(msg.get("id")))
            if p is None:
                self.log.event("unexpected_response", id=msg.get("id"))
            elif p["response"] is not None:
                self.log.event("duplicate_response", id=msg.get("id"))
            else:
                p["response"] = msg
                if p["cancel_requested"]:
                    self.log.event("response_after_cancel_request", id=msg.get("id"))
            self.cond.notify_all()

    def cancel_count(self, sid):
        with self.cond:
            return self.cancel_counts.get(sid, 0)

    # ------------------------------------------------------- MCP over HTTP
    def alloc_mcp_id(self):
        with self.cond:
            rid = self.next_mcp_id
            self.next_mcp_id += 1
            return rid

    def mcp_connection(self, key, timeout, reuse=True):
        """(connection, reused): an idle kept-alive connection to key = (scheme, host, port) if reuse, or a new one."""
        conn = None
        if reuse:
            with self.cond:
                idle = self.mcp_idle.get(key)
                conn = idle.pop() if idle else None
        if conn is not None:
            conn.timeout = timeout
            if conn.sock is not None:
                conn.sock.settimeout(timeout)
            return conn, True
        scheme, host, port = key
        cls = http.client.HTTPSConnection if scheme == "https" else http.client.HTTPConnection
        return cls(host, port, timeout=timeout), False

    def mcp_release(self, key, conn):
        """Keep a connection whose last answer was read completely for the next exchange."""
        with self.cond:
            self.mcp_idle.setdefault(key, []).append(conn)

    # ------------------------------------------------------------- inbound
    def note_first_stdin(self):
        if not self.first_stdin_seen:
            self.first_stdin_seen = True
            self.log.event("first_stdin")

    def stdin_pending(self):
        """The number of bytes waiting on stdin, without reading them (-1 if it can't be told)."""
        try:
            fd = sys.stdin.fileno()
            if os.name == "nt":
                import ctypes
                import msvcrt
                from ctypes import wintypes
                avail = wintypes.DWORD(0)
                ok = ctypes.windll.kernel32.PeekNamedPipe(wintypes.HANDLE(msvcrt.get_osfhandle(fd)), None, 0, None,
                                                          ctypes.byref(avail), None)
                return int(avail.value) if ok else -1
            import array
            import fcntl
            import termios
            buf = array.array("i", [0])
            fcntl.ioctl(fd, termios.FIONREAD, buf, True)
            return int(buf[0])
        except Exception:
            return -1

    def launch_phase(self):
        """--stdout-noise, --start-delay, --stderr-line, --exit-after-start, --preamble-lines (before the reader)."""
        a = self.args
        if a.stdout_noise is not None:
            self.send_raw(a.stdout_noise)
        if a.start_delay > 0:
            time.sleep(a.start_delay)
        pieces = []
        for line in a.stderr_line:
            data = (line + "\n").encode("utf-8")
            if a.stderr_split_delay > 0 and len(data) > 1:
                pieces += [data[:len(data) // 2], data[len(data) // 2:]]
            else:
                pieces.append(data)
        for k, piece in enumerate(pieces):
            if k > 0 and a.stderr_split_delay > 0:
                time.sleep(a.stderr_split_delay)
            self.log.event("stderr_write", text=piece.decode("utf-8", "replace"), stdinPending=self.stdin_pending())
            try:
                sys.stderr.buffer.write(piece)
                sys.stderr.buffer.flush()
            except Exception:
                pass
        if a.exit_after_start is not None:
            self.log.event("stdin_check", stdinPending=self.stdin_pending())
            self.exit(a.exit_after_start, "exit after start")
        if a.preamble_lines > 0:
            lines = []
            for _ in range(a.preamble_lines):
                try:
                    line = self.stdin.readline()
                except Exception:
                    line = b""
                if not line:
                    break
                self.note_first_stdin()
                lines.append(line)
            self.touch()
            self.log.event("preamble", lines=[l.decode("utf-8", "replace") for l in lines],
                           base64=[base64.b64encode(l).decode("ascii") for l in lines])

    def reader(self):
        stdin = self.stdin
        while True:
            try:
                line = stdin.readline()
            except Exception:
                line = b""
            if line:
                self.note_first_stdin()
            if not line:
                self.log.event("eof")
                if self.args.ignore_eof:
                    return
                if self.args.eof_exit_delay > 0:
                    time.sleep(self.args.eof_exit_delay)
                self.exit(0, "eof")
            self.touch()
            text = line.decode("utf-8", "replace").strip()
            if not text:
                continue
            try:
                msg = json.loads(text)
            except ValueError:
                self.log.write("in", raw=text)
                self.respond_error(None, -32700, "Parse error")
                continue
            self.log.write("in", msg=msg)
            for m in (msg if isinstance(msg, list) else [msg]):
                self.dispatch(m)

    def dispatch(self, m):
        if not isinstance(m, dict):
            self.respond_error(None, -32600, "Invalid Request")
        elif "method" in m and "id" in m:
            self.requests.put(m)
        elif "method" in m:
            if m["method"] == "session/cancel":
                sid = (m.get("params") or {}).get("sessionId")
                with self.cond:
                    self.cancel_counts[sid] = self.cancel_counts.get(sid, 0) + 1
                    self.cond.notify_all()
        elif "id" in m and ("result" in m or "error" in m):
            self.deliver_response(m)
        else:
            self.respond_error(m.get("id"), -32600, "Invalid Request")

    def watchdog(self):
        while True:
            time.sleep(0.5)
            now = time.time()
            if now - self.last_activity > self.args.idle_timeout:
                self.log.event("watchdog", reason="idle", seconds=self.args.idle_timeout)
                self.exit(124, "idle watchdog")
            if now - self.started > self.args.max_lifetime:
                self.log.event("watchdog", reason="lifetime", seconds=self.args.max_lifetime)
                self.exit(124, "lifetime watchdog")

    def main_loop(self):
        while True:
            try:
                m = self.requests.get(timeout=0.25)
            except queue.Empty:
                continue
            try:
                self.handle_request(m)
            except Exception as e:
                self.log.event("error", where="handle_request", error=repr(e), trace=traceback.format_exc())
                self.respond_error(m.get("id"), -32603, "Internal error: " + repr(e))

    # ------------------------------------------------------------- methods
    def now_iso(self):
        """The current time for "updatedAt", strictly later than the one handed out before."""
        with self.cond:
            ms = max(int(time.time() * 1000), self.last_ms + 1)
            self.last_ms = ms
        return iso_utc(ms)

    def new_session_record(self, sid, cwd, listed=None):
        """A session of this process; listed: its agent.sessions entry (keeps its cwd, title and updatedAt)."""
        cfg = self.agent_config
        rec = {"cwd": cwd, "configOptions": copy.deepcopy(cfg.get("configOptions") or []),
               "modes": copy.deepcopy(cfg.get("modes")), "closed": False, "title": None,
               "updatedAt": None, "additionalDirectories": None, "fallbackTitle": None,
               "history": None, "prompted": False, "mcpServers": None}
        if listed is not None:
            rec["cwd"] = listed.get("cwd", cwd)
            rec["title"] = listed.get("title")
            rec["updatedAt"] = listed.get("updatedAt")
            rec["additionalDirectories"] = listed.get("additionalDirectories")
        else:
            rec["updatedAt"] = self.now_iso()
            title = cfg.get("sessionTitle")
            if isinstance(title, str):
                rec["title"] = rec["fallbackTitle"] = title.replace("${createdAt}", rec["updatedAt"])
            if cfg.get("recordHistory"):
                rec["history"] = []
        with self.cond:
            self.sessions[sid] = rec
            self.deleted.discard(sid)
        return rec

    def listed_session(self, sid):
        """The agent.sessions entry of sid, unless it was deleted."""
        with self.cond:
            if sid in self.deleted:
                return None
        return next((copy.deepcopy(e) for e in (self.agent_config.get("sessions") or [])
                     if isinstance(e, dict) and e.get("sessionId") == sid), None)

    def touch_session(self, rec):
        rec["updatedAt"] = self.now_iso()

    def session_for_load(self, rid, method, params):
        """The record of the session that session/load|resume|fork names, or None after an error response."""
        sid = params.get("sessionId")
        cwd = params.get("cwd")
        strict = self.agent_config.get("strictSessions")
        with self.cond:
            rec = self.sessions.get(sid)
        if rec is None:
            listed = self.listed_session(sid)
            if strict and listed is None:
                self.respond_error(rid, -32602, "Invalid params: session not found: %s" % sid, {"sessionId": sid})
                return None
            if strict and not same_directory(listed.get("cwd"), cwd):
                self.respond_error(rid, -32602, "Invalid params: session %s does not belong to cwd: %s" % (sid, cwd),
                                   {"sessionId": sid, "cwd": cwd})
                return None
            if method == "session/fork":
                return listed or {"cwd": cwd}
            return self.new_session_record(sid, cwd, listed)
        if strict and not same_directory(rec.get("cwd"), cwd):
            self.respond_error(rid, -32602, "Invalid params: session %s does not belong to cwd: %s" % (sid, cwd),
                               {"sessionId": sid, "cwd": cwd})
            return None
        return rec

    def history_of(self, sid, rec):
        """The updates session/load replays for sid (rec: its record, or None)."""
        cfg = self.agent_config
        with self.cond:
            if rec is not None and rec.get("history") is not None:
                return copy.deepcopy(rec["history"])
            hist = (cfg.get("histories") or {}).get(sid)
            if hist is None:
                hist = cfg.get("history") or []
            hist = copy.deepcopy(hist)
            if rec is not None and cfg.get("recordHistory"):
                rec["history"] = copy.deepcopy(hist)  # later prompts add to it
            return hist

    def replay(self, sid, interval=0.0):
        """Replay a session's history (session/load)."""
        with self.cond:
            rec = self.sessions.get(sid)
        for update in self.history_of(sid, rec):
            if update.get("_unfinished"):
                continue  # a recorded tool call without a tool_call_update yet
            self.notify_update(sid, update, record=False)
            if interval > 0:
                time.sleep(interval)

    def new_message_id(self):
        with self.cond:
            self.message_counter += 1
            return "msg_mock_%d" % self.message_counter

    def record_prompt(self, sid, rec, prompt):
        """recordHistory: the user message of a session/prompt."""
        if rec.get("history") is None:
            if not self.agent_config.get("recordHistory"):
                return
            self.history_of(sid, rec)  # starts from what a load would have replayed
        mid = self.new_message_id()
        with self.cond:
            for block in prompt or []:
                if isinstance(block, dict):
                    rec["history"].append({"sessionUpdate": "user_message_chunk", "messageId": mid,
                                           "content": copy.deepcopy(block)})

    def record_update(self, sid, update):
        """recordHistory: a session/update the mock sends, stored the way OpenCode replays it."""
        if not isinstance(update, dict) or update.get("sessionUpdate") not in RECORDED_UPDATES:
            return
        with self.cond:
            rec = self.sessions.get(sid)
            hist = rec.get("history") if rec is not None else None
            if hist is None:
                return
            kind = update["sessionUpdate"]
            content = update.get("content")
            last = hist[-1] if hist else None
            if kind == "tool_call":
                hist.append(copy.deepcopy(update))
                hist.append({"sessionUpdate": "tool_call_update", "toolCallId": update.get("toolCallId"),
                             "_unfinished": True})
            elif kind == "tool_call_update":
                final = next((u for u in reversed(hist) if u.get("sessionUpdate") == "tool_call_update"
                              and u.get("toolCallId") == update.get("toolCallId")), None)
                if final is None:
                    hist.append(copy.deepcopy(update))
                else:
                    final.pop("_unfinished", None)
                    final.update(copy.deepcopy(update))
            elif (kind in ("agent_message_chunk", "agent_thought_chunk") and last is not None
                  and last.get("sessionUpdate") == kind
                  and update.get("messageId") in (None, last.get("messageId"))
                  and isinstance(content, dict) and content.get("type") == "text"
                  and isinstance(last.get("content"), dict) and last["content"].get("type") == "text"):
                last["content"]["text"] = last["content"].get("text", "") + content.get("text", "")
            else:
                entry = copy.deepcopy(update)
                if kind != "user_message_chunk" and "messageId" not in entry:
                    entry["messageId"] = "msg_mock_%d" % (self.message_counter + 1)
                    self.message_counter += 1
                hist.append(entry)

    def list_sessions(self, rid, params):
        cfg = self.agent_config
        cwd = params.get("cwd")
        if cwd is not None and not (isinstance(cwd, str) and os.path.isabs(cwd)):
            self.respond_error(rid, -32602, "Invalid params: cwd must be an absolute path: %s" % (cwd,),
                               {"field": "cwd"})
            return
        cursor = params.get("cursor")
        offset = 0
        if cursor is not None:
            offset = decode_cursor(cursor)
            if offset is None:
                self.respond_error(rid, -32602, "Invalid params: Invalid cursor", {"field": "cursor"})
                return
        with self.cond:
            rows = []
            for sid, rec in self.sessions.items():
                row = {"sessionId": sid, "cwd": rec["cwd"] or "/"}
                if rec.get("title") is not None:
                    row["title"] = rec["title"]
                if rec.get("updatedAt") is not None:
                    row["updatedAt"] = rec["updatedAt"]
                if rec.get("additionalDirectories"):
                    row["additionalDirectories"] = list(rec["additionalDirectories"])
                rows.append(row)
            known = set(self.sessions) | self.deleted
        rows += [copy.deepcopy(e) for e in (cfg.get("sessions") or [])
                 if isinstance(e, dict) and e.get("sessionId") not in known]
        if cwd is not None:
            rows = [r for r in rows if r.get("cwd") == cwd]

        def newest_first(row):
            t = iso_to_seconds(row.get("updatedAt"))
            return (1, 0) if t is None else (0, -t)
        rows.sort(key=newest_first)
        size = cfg.get("listPageSize") or 0
        page = rows[offset:offset + size] if size > 0 else rows[offset:]
        result = {"sessions": page}
        end = offset + len(page)
        if end < len(rows) or (page and cfg.get("listCursorOnLastPage")):
            result["nextCursor"] = encode_cursor(end)
        self.respond(rid, result)

    def session_state_result(self, sid, rec):
        res = {}
        if sid is not None:
            res["sessionId"] = sid
        if rec.get("configOptions"):
            res["configOptions"] = rec["configOptions"]
        if rec.get("modes"):
            res["modes"] = rec["modes"]
        return res

    def send_available_commands(self, sid):
        cmds = self.agent_config.get("availableCommands")
        if cmds:
            self.notify_update(sid, {"sessionUpdate": "available_commands_update", "availableCommands": cmds})

    def handle_request(self, m):
        method, rid, params = m["method"], m["id"], m.get("params") or {}
        override = self.method_overrides.get(method)
        if override is not None:
            if "error" in override:
                e = override["error"]
                self.respond_error(rid, e.get("code", -32603), e.get("message", "Error"), e.get("data"))
                return
            if "result" in override:
                self.respond(rid, override["result"])
                return
            if "steps" in override:
                sid = params.get("sessionId")
                run = Run(self, {"name": "methods/" + method, "steps": override["steps"]}, m, sid)
                threading.Thread(target=run.run, daemon=True).start()
                return
        cfg = self.agent_config
        if method == "initialize":
            requested = params.get("protocolVersion", 1)
            version = cfg["protocolVersion"]
            if isinstance(requested, int) and requested < version:
                version = requested
            self.respond(rid, {"protocolVersion": version, "agentCapabilities": cfg["agentCapabilities"],
                               "authMethods": cfg["authMethods"], "agentInfo": cfg["agentInfo"]})
        elif method == "authenticate":
            self.respond(rid, {})
        elif method in ("session/new", "session/fork"):
            source = None
            if method == "session/fork":
                source = self.session_for_load(rid, method, params)
                if source is None:
                    return
            with self.cond:
                self.session_counter += 1
                sid = "sess-%d" % self.session_counter
            rec = self.new_session_record(sid, params.get("cwd"))
            if params.get("additionalDirectories"):
                rec["additionalDirectories"] = list(params["additionalDirectories"])
            if "mcpServers" in params or source is None:
                rec["mcpServers"] = copy.deepcopy(params.get("mcpServers"))
            else:
                rec["mcpServers"] = copy.deepcopy(source.get("mcpServers"))
            if source is not None and rec.get("history") is not None:
                rec["history"] = self.history_of(params.get("sessionId"), source)  # a fork copies the messages
            self.respond(rid, self.session_state_result(sid, rec))
            self.send_available_commands(sid)
        elif method in ("session/load", "session/resume"):
            sid = params.get("sessionId")
            rec = self.session_for_load(rid, method, params)
            if rec is None:
                return
            rec["closed"] = False
            if params.get("additionalDirectories"):
                rec["additionalDirectories"] = list(params["additionalDirectories"])
            if "mcpServers" in params:
                rec["mcpServers"] = copy.deepcopy(params["mcpServers"])
            if method == "session/load":
                self.replay(sid)
            self.respond(rid, self.session_state_result(None, rec))
            self.send_available_commands(sid)
        elif method == "session/list":
            self.list_sessions(rid, params)
        elif method == "session/close":
            with self.cond:
                rec = self.sessions.get(params.get("sessionId"))
                if rec is not None:
                    rec["closed"] = True
            self.respond(rid, {})
        elif method == "session/delete":
            with self.cond:
                self.sessions.pop(params.get("sessionId"), None)
                self.deleted.add(params.get("sessionId"))
            self.respond(rid, {})
        elif method == "session/set_config_option":
            self.set_config_option(rid, params)
        elif method == "session/set_mode":
            with self.cond:
                rec = self.sessions.get(params.get("sessionId"))
            if rec is None:
                self.respond_error(rid, -32602, "Unknown session")
                return
            if rec.get("modes"):
                rec["modes"]["currentModeId"] = params.get("modeId")
            for opt in rec["configOptions"]:
                if opt.get("category") == "mode":
                    opt["currentValue"] = params.get("modeId")
            self.touch_session(rec)
            self.respond(rid, {})
        elif method == "session/prompt":
            self.start_prompt(m)
        else:
            self.respond_error(rid, -32601, "Method not found")

    def set_config_option(self, rid, params):
        with self.cond:
            rec = self.sessions.get(params.get("sessionId"))
        if rec is None:
            self.respond_error(rid, -32602, "Unknown session")
            return
        opt = next((o for o in rec["configOptions"] if o.get("id") == params.get("configId")), None)
        value = params.get("value")
        if opt is None:
            self.respond_error(rid, -32602, "Unknown configId")
            return
        if opt.get("type") == "select" and value not in [o.get("value") for o in opt.get("options", [])]:
            self.respond_error(rid, -32602, "Invalid value")
            return
        opt["currentValue"] = value
        if opt.get("category") == "mode" and rec.get("modes"):
            rec["modes"]["currentModeId"] = value
        self.touch_session(rec)  # OpenCode bumps updatedAt even if the value does not change
        self.respond(rid, {"configOptions": rec["configOptions"]})

    def start_prompt(self, m):
        params = m.get("params") or {}
        sid = params.get("sessionId")
        with self.cond:
            rec = self.sessions.get(sid)
        if rec is None:
            self.respond_error(m["id"], -32602, "Unknown session: %s" % sid)
            return
        text = ""
        for block in params.get("prompt") or []:
            if isinstance(block, dict) and block.get("type") == "text":
                text = block.get("text", "")
                break
        words = text.split()
        self.touch_session(rec)
        self.record_prompt(sid, rec, params.get("prompt"))
        if (self.agent_config.get("titleFromPrompt") and not rec.get("prompted")
                and rec.get("title") in (None, rec.get("fallbackTitle"))):
            title = " ".join(words[1:] if words and words[0].startswith("scenario:") else words)
            rec["title"] = title[:50] or "Untitled"
        rec["prompted"] = True
        scenario = self.global_scenario
        if words and words[0].startswith("scenario:"):
            name = words[0][len("scenario:"):]
            scenario = self.load_scenario(name)
            if scenario is None:
                self.log.event("error", where="start_prompt", error="unknown scenario", scenario=name)
                self.respond_error(m["id"], -32602, "Unknown scenario: %s" % name)
                return
        run = Run(self, scenario, m, sid)
        threading.Thread(target=run.run, daemon=True).start()

    # ------------------------------------------------------------ children
    def spawn(self, step, detached, run):
        name = step.get("name", "child")
        lifetime = float(step.get("lifetime", 120))
        depth = int(step.get("depth", 1))
        cmd = [sys.executable, os.path.abspath(__file__), "--child", name, str(lifetime), str(depth),
               self.args.log or "", "1" if detached else "0"]
        kw = {}
        if not step.get("inherit_stdio", False):
            kw.update(stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if detached:
            if os.name == "nt":
                kw["creationflags"] = 0x00000200 | 0x00000008  # CREATE_NEW_PROCESS_GROUP | DETACHED_PROCESS
            else:
                kw["start_new_session"] = True
        p = subprocess.Popen(cmd, close_fds=True, **kw)
        pgid = None
        if hasattr(os, "getpgid"):
            try:
                pgid = os.getpgid(p.pid)
            except OSError:
                pass
        self.log.event("spawn", kind="detached" if detached else "child", name=name, pid=p.pid, pgid=pgid,
                       parent=os.getpid(), lifetime=lifetime)
        run.vars["lastChildPid"] = p.pid
        return p


class Run(object):
    """One execution of a scenario's steps for one request (normally a session/prompt)."""

    def __init__(self, agent, scenario, request, sid):
        self.agent = agent
        self.scenario = scenario
        self.request = request
        self.sid = sid
        self.prompt_id = request["id"]
        self.cancel_base = agent.cancel_count(sid)
        self.responded = False
        self.on_cancel = None
        self.handling_cancel = False
        self.named = {}
        self.outcomes = {}
        self.my_requests = []
        self.last_request = None
        self.mcp_results = {}       # "as" name -> record of an mcp_request step
        self.last_mcp = None        # record of the last mcp_request step
        text = ""
        for block in (request.get("params") or {}).get("prompt") or []:
            if isinstance(block, dict) and block.get("type") == "text":
                text = block.get("text", "")
                break
        rec = agent.sessions.get(sid) or {}
        self.vars = {"sessionId": sid, "promptId": self.prompt_id, "promptText": text,
                     "cwd": rec.get("cwd"), "pid": os.getpid()}

    # ------------------------------------------------------------ helpers
    VAR = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::([^}]*))?\}")

    def lookup(self, match, extra):
        name, arg = match.group(1), match.group(2)
        if name == "bytes":
            return "x" * int(arg or 0)
        if name in ("mcpText", "mcpResult", "mcpStatus"):
            rec = self.mcp_results.get(arg) if arg else self.last_mcp
            return match.group(0) if rec is None else mcp_substitution(name, rec)
        if name in extra:
            return extra[name]
        if name == "lastRequestId":
            return self.last_request
        if name in self.vars:
            return self.vars[name]
        return match.group(0)

    def subst(self, obj, extra=None):
        extra = extra or {}
        if isinstance(obj, str):
            m = self.VAR.fullmatch(obj)
            if m:
                return self.lookup(m, extra)
            return self.VAR.sub(lambda mm: self.embed(self.lookup(mm, extra)), obj)
        if isinstance(obj, list):
            return [self.subst(x, extra) for x in obj]
        if isinstance(obj, dict):
            return dict((k, self.subst(v, extra)) for k, v in obj.items())
        return obj

    @staticmethod
    def embed(value):
        """The text of a value substituted inside a longer string (an object or array as JSON)."""
        if isinstance(value, (dict, list)):
            return json.dumps(value, separators=(",", ":"), ensure_ascii=False)
        return str(value)

    def cancelled(self):
        return self.agent.cancel_count(self.sid) > self.cancel_base

    def check_cancel(self):
        if self.on_cancel is not None and not self.handling_cancel and self.cancelled():
            raise CancelledRun()

    def wait(self, pred, timeout, cancellable=True):
        """Wait until pred() or timeout; raise CancelledRun if a registered cancel handler should run (cancellable)."""
        deadline = time.time() + float(timeout)
        with self.agent.cond:
            while True:
                if cancellable:
                    self.check_cancel()
                if pred():
                    return True
                remaining = deadline - time.time()
                if remaining <= 0:
                    return False
                self.agent.cond.wait(min(remaining, 0.25))

    def resolve_request(self, name):
        if name is None:
            return self.last_request
        return self.named.get(name, name)

    def classify(self, resp):
        if resp is None:
            return "timeout", None
        if "error" in resp:
            return "error", None
        outcome = ((resp.get("result") or {}).get("outcome") or {})
        kind = outcome.get("outcome")
        if kind in ("selected", "cancelled"):
            return kind, outcome.get("optionId")
        return "other", None

    def check_when(self, when):
        if when is None:
            return True
        if isinstance(when, str):
            when = {"cancelled": True} if when == "cancelled" else {"cancelled": False} if when == "not_cancelled" else {}
        if "cancelled" in when and self.cancelled() != bool(when["cancelled"]):
            return False
        if "responded" in when and self.responded != bool(when["responded"]):
            return False
        if "outcome" in when or "optionId" in when:
            rid = self.resolve_request(when.get("request"))
            outcome, option = self.outcomes.get(idkey(rid), ("none", None))
            if "outcome" in when:
                want = when["outcome"] if isinstance(when["outcome"], list) else [when["outcome"]]
                if outcome not in want:
                    return False
            if "optionId" in when:
                want = when["optionId"] if isinstance(when["optionId"], list) else [when["optionId"]]
                if option not in want:
                    return False
        return True

    # ------------------------------------------------------ mcp_request
    def mcp_servers(self):
        """The "mcpServers" of the run's session, or else those of the run's request."""
        with self.agent.cond:
            servers = (self.agent.sessions.get(self.sid) or {}).get("mcpServers")
        if servers is None:
            servers = (self.request.get("params") or {}).get("mcpServers")
        return [x for x in servers if isinstance(x, dict)] if isinstance(servers, list) else []

    def mcp_headers(self, server, version, overrides):
        """The headers of a POST to server: its own, MCP-Protocol-Version, ours (they win, as in OpenCode's MCP
        client), then the step's overrides (None removes one)."""
        headers = {}  # lower-case name -> (name, value)
        for h in server.get("headers") or []:
            if isinstance(h, dict) and isinstance(h.get("name"), str):
                headers[h["name"].lower()] = (h["name"], str(h.get("value", "")))
        if version is not None:
            headers["mcp-protocol-version"] = ("MCP-Protocol-Version", version)
        headers["content-type"] = ("Content-Type", "application/json")
        headers["accept"] = ("Accept", "application/json, text/event-stream")
        for name, value in overrides.items():
            if value is None:
                headers.pop(name.lower(), None)
            else:
                headers[name.lower()] = (name, str(value))
        return dict(headers.values())

    def mcp_exchange(self, server, wanted, method, params, rid, overrides, timeout, as_name=None, keep=False,
                     cancellable=True):
        """POST one message to server (None if no server of the session matched wanted), log the answer as an
        mcp_response or mcp_error event and return that record (keep: also for the "${mcp...}" substitutions).  After
        a timeout or a cancel, a request is followed by notifications/cancelled (and a cancel raises CancelledRun)."""
        a = self.agent
        name = server.get("name") if server is not None else wanted
        rec = {"as": as_name, "server": name, "method": method, "id": rid}
        if keep:  # finish() completes the record in place
            self.last_mcp = rec
            if as_name is not None:
                self.mcp_results[as_name] = rec
        started = time.time()

        def finish(event, **kw):
            a.touch()
            rec.update(kw)
            rec["seconds"] = round(time.time() - started, 3)
            a.log.event(event, **rec)
            rec["event"] = event
            return rec

        if server is None:
            return finish("mcp_error", error="the session has no MCP server of type http" if wanted is None
                          else "the session has no MCP server named %r" % (wanted,))
        if server.get("type") != "http":
            return finish("mcp_error", error="the MCP server %r is not of type http" % (name,))
        message = {"jsonrpc": "2.0", "method": method}
        if not method.startswith("notifications/"):
            message["id"] = rid
        if params is not None:
            message["params"] = params
        with a.cond:
            version = None if method == "initialize" else a.mcp_versions.get((self.sid, name))
        a.log.event("mcp_request", url=server.get("url"), protocolVersion=version, **rec)
        a.touch()
        exchange = MCPExchange(a, server.get("url"), self.mcp_headers(server, version, overrides), message, timeout)
        exchange.start()

        def abandon(error, reason):
            exchange.abort()
            finish("mcp_error", error=error)
            if "id" in message:
                self.mcp_exchange(server, wanted, "notifications/cancelled", {"requestId": rid, "reason": reason},
                                  None, overrides, min(timeout, MCP_CANCEL_TIMEOUT), cancellable=False)
            return rec

        try:
            answered = self.wait(lambda: exchange.done, timeout, cancellable)
        except CancelledRun:
            abandon("cancelled", "cancelled")
            raise
        if not answered:
            return abandon("no answer within %g seconds" % timeout, "timeout")
        return finish("mcp_error" if "error" in exchange.answer else "mcp_response", **exchange.answer)

    # -------------------------------------------------------------- run
    def run(self):
        a = self.agent
        a.log.event("scenario", name=self.scenario.get("name"), session=self.sid, request=self.prompt_id)
        try:
            try:
                for step in self.scenario.get("steps", []):
                    self.check_cancel()
                    self.do_step(step)
                    self.check_cancel()
            except CancelledRun:
                self.handle_cancel()
        except EndRun:
            pass
        except Exception as e:
            a.log.event("error", where="scenario", error=repr(e), trace=traceback.format_exc())
            if not self.responded:
                a.respond_error(self.prompt_id, -32603, "Mock scenario error: " + repr(e))
                self.responded = True
        a.log.event("scenario_end", name=self.scenario.get("name"), session=self.sid, request=self.prompt_id,
                    responded=self.responded)

    def handle_cancel(self):
        a = self.agent
        s = self.on_cancel
        self.handling_cancel = True
        a.log.event("cancel_seen", session=self.sid, request=self.prompt_id)
        time.sleep(float(s.get("delay", 0.03)))
        if s.get("cancel_requests", True):
            for rid in self.my_requests:
                with a.cond:
                    p = a.pending.get(idkey(rid))
                    unanswered = p is not None and p["response"] is None
                    if unanswered:
                        p["cancel_requested"] = True
                if unanswered:
                    a.log.event("cancel_request_sent", id=rid)
                    a.send({"jsonrpc": "2.0", "method": "$/cancel_request", "params": {"requestId": rid}})
        try:
            for step in s.get("steps", []):
                self.do_step(step)
        except EndRun:
            return
        if not self.responded and s.get("respond", True):
            a.respond(self.prompt_id, {"stopReason": s.get("stopReason", "cancelled")})
            self.responded = True

    def do_step(self, step):
        if not self.check_when(step.get("when")):
            return
        kind = step.get("type")
        fn = getattr(self, "step_" + str(kind), None)
        if fn is None:
            raise ValueError("unknown step type %r" % kind)
        fn(step)
        if step.get("end"):
            raise EndRun()

    # ------------------------------------------------------------ steps
    def step_notify(self, s):
        for i in range(int(s.get("repeat", 1))):
            extra = {"i": i}
            if "method" in s:
                self.agent.send({"jsonrpc": "2.0", "method": self.subst(s["method"], extra),
                                 "params": self.subst(s.get("params", {}), extra)})
            else:
                sid = self.subst(s.get("sessionId", "${sessionId}"), extra)
                self.agent.notify_update(sid, self.subst(s["update"], extra))

    def step_late_notify(self, s):
        time.sleep(float(s.get("delay", 0.5)))
        self.step_notify(s)

    def step_request(self, s):
        a = self.agent
        method = s.get("method", "session/request_permission")
        if s.get("collide"):
            rid = self.prompt_id
        elif "id" in s:
            rid = self.subst(s["id"])
        else:
            rid = a.alloc_request_id()
        if "params" in s:
            params = self.subst(s["params"])
        else:
            params = {"sessionId": self.sid,
                      "toolCall": {"toolCallId": self.subst(s.get("toolCallId", "call_perm")),
                                   "title": s.get("title", "Write y.txt"), "kind": s.get("kind", "edit"),
                                   "status": "pending"},
                      "options": [{"optionId": "once", "name": "Allow once", "kind": "allow_once"},
                                  {"optionId": "always", "name": "Always allow", "kind": "allow_always"},
                                  {"optionId": "reject", "name": "Reject", "kind": "reject_once"}]}
        a.register_request(rid, method)
        self.my_requests.append(rid)
        self.last_request = rid
        if "as" in s:
            self.named[s["as"]] = rid
        a.send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})

    def step_wait_response(self, s):
        a = self.agent
        rid = self.resolve_request(s.get("request"))
        key = idkey(rid)
        self.wait(lambda: (a.pending.get(key) or {}).get("response") is not None, s.get("timeout", 30))
        with a.cond:
            resp = (a.pending.get(key) or {}).get("response")
        outcome, option = self.classify(resp)
        self.outcomes[key] = (outcome, option)
        a.log.event("wait_response", id=rid, outcome=outcome, optionId=option)

    def step_wait_cancel(self, s):
        self.wait(lambda: self.cancelled(), s.get("timeout", 30))

    def step_on_cancel(self, s):
        self.on_cancel = s
        self.check_cancel()

    def step_respond(self, s):
        rid = self.subst(s["id"]) if "id" in s else self.prompt_id
        if "stopReason" in s:
            reason = s["stopReason"]
            if reason == "auto":
                reason = "cancelled" if self.cancelled() else "end_turn"
            result = {"stopReason": reason}
        else:
            result = self.subst(s.get("result", {"stopReason": "end_turn"}))
        self.agent.respond(rid, result)
        if rid == self.prompt_id:
            self.responded = True

    def step_respond_error(self, s):
        rid = self.subst(s["id"]) if "id" in s else self.prompt_id
        self.agent.respond_error(rid, s.get("code", -32603), s.get("message", "Internal error"),
                                 self.subst(s.get("data")))
        if rid == self.prompt_id:
            self.responded = True

    def step_delay(self, s):
        self.wait(lambda: False, s.get("seconds", 1))

    def step_send(self, s):
        self.agent.send(self.subst(s["message"]))

    def step_raw(self, s):
        self.agent.send_raw(self.subst(s.get("text", "")), s.get("newline", True))

    def step_mark(self, s):
        self.agent.log.event("mark", label=s.get("label"))

    def step_replay(self, s):
        self.agent.replay(self.sid, float(s.get("interval", 0)))

    def step_mcp_request(self, s):
        a = self.agent
        method = self.subst(s.get("method"))
        if not isinstance(method, str) or not method:
            raise ValueError("mcp_request needs a \"method\"")
        wanted = s.get("server")
        servers = self.mcp_servers()
        if wanted is None:
            server = next((x for x in servers if x.get("type") == "http"), None)
        else:
            server = next((x for x in servers if x.get("name") == wanted), None)
        if method.startswith("notifications/"):
            rid = None
        elif "id" in s:
            rid = self.subst(s["id"])
        else:
            rid = a.alloc_mcp_id()
        if "params" in s:
            params = self.subst(s["params"])
        else:
            params = copy.deepcopy(MCP_INITIALIZE_PARAMS) if method == "initialize" else None
        overrides = self.subst(s.get("headers") or {})
        timeout = float(s.get("timeout", 30))
        rec = self.mcp_exchange(server, wanted, method, params, rid, overrides, timeout, as_name=s.get("as"), keep=True)
        body = rec.get("body")
        result = body.get("result") if isinstance(body, dict) else None
        if method == "initialize" and rec["event"] == "mcp_response" and isinstance(result, dict):
            if isinstance(result.get("protocolVersion"), str):
                with a.cond:
                    a.mcp_versions[(self.sid, server.get("name"))] = result["protocolVersion"]
            if s.get("initialized", True):
                self.mcp_exchange(server, wanted, "notifications/initialized", None, None, overrides, timeout)

    def step_exit(self, s):
        time.sleep(float(s.get("delay", 0)))
        self.agent.exit(int(s.get("code", 0)), "exit step")

    def step_stderr_spam(self, s):
        def spam():
            total = int(s.get("bytes", 100000))
            line = (s.get("line") or "mock stderr spam " + "." * 60) + "\n"
            data = line.encode("utf-8")
            written = 0
            try:
                while written < total:
                    sys.stderr.buffer.write(data)
                    written += len(data)
                sys.stderr.buffer.flush()
            except Exception:
                pass
            self.agent.log.event("stderr_spam_done", bytes=written)
        if s.get("background"):
            threading.Thread(target=spam, daemon=True).start()
        else:
            spam()

    def step_slow_writer(self, s):
        def writer():
            for i in range(int(s.get("count", 3))):
                time.sleep(float(s.get("interval", 3)))
                extra = {"i": i}
                if "method" in s:
                    obj = {"jsonrpc": "2.0", "method": self.subst(s["method"], extra),
                           "params": self.subst(s.get("params", {}), extra)}
                else:
                    update = s.get("update") or {"sessionUpdate": "agent_message_chunk",
                                                 "content": {"type": "text", "text": "tick ${i} "}}
                    obj = {"jsonrpc": "2.0", "method": "session/update",
                           "params": {"sessionId": self.sid, "update": self.subst(update, extra)}}
                self.agent.send_split(obj, s.get("split", 1), float(s.get("chunk_delay", 0)))
        if s.get("background"):
            threading.Thread(target=writer, daemon=True).start()
        else:
            writer()

    def step_spawn_child(self, s):
        self.agent.spawn(s, False, self)

    def step_spawn_detached(self, s):
        self.agent.spawn(s, True, self)


def child_main(argv):
    """--child name lifetime depth logpath detached: a long-lived descendant for process-tree tests."""
    name, lifetime, depth, logpath, detached = argv[0], float(argv[1]), int(argv[2]), argv[3], argv[4]
    if depth > 1:
        p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--child", name + "/grandchild",
                              str(lifetime), str(depth - 1), logpath, detached],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             close_fds=True)
        if logpath:
            try:
                with open(logpath, "a", encoding="utf-8") as f:
                    f.write(json.dumps({"seq": 0, "t": round(time.time(), 4), "dir": "event", "event": "spawn",
                                        "kind": "grandchild", "name": name + "/grandchild", "pid": p.pid,
                                        "parent": os.getpid(), "lifetime": lifetime},
                                       separators=(",", ":")) + "\n")
            except Exception:
                pass
    time.sleep(lifetime)
    return 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--child":
        sys.exit(child_main(sys.argv[2:]))
    ap = argparse.ArgumentParser(description="Scripted ACP v1 mock agent")
    ap.add_argument("--log", default=None)
    ap.add_argument("--scenario", default=None)
    ap.add_argument("--scenario-dir", action="append", default=[])
    ap.add_argument("--idle-timeout", type=float, default=120.0)
    ap.add_argument("--max-lifetime", type=float, default=900.0)
    ap.add_argument("--ignore-eof", action="store_true")
    ap.add_argument("--eof-exit-delay", type=float, default=0.0)
    ap.add_argument("--ignore-sigterm", action="store_true")
    ap.add_argument("--stdout-noise", default=None)
    ap.add_argument("--start-delay", type=float, default=0.0)
    ap.add_argument("--stderr-line", action="append", default=[])
    ap.add_argument("--stderr-split-delay", type=float, default=0.0)
    ap.add_argument("--exit-after-start", type=int, default=None)
    ap.add_argument("--preamble-lines", type=int, default=0)
    args = ap.parse_args()

    agent = Agent(args)

    def on_sigterm(signum, frame):
        agent.log.event("sigterm", ignored=bool(args.ignore_sigterm))
        if not args.ignore_sigterm:
            agent.exit(143, "sigterm")

    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, on_sigterm)

    env = dict((k, v) for k, v in os.environ.items() if k.startswith("ACPLINK_") or k.startswith("MOCK_"))
    agent.log.event("start", pid=os.getpid(), pgid=os.getpgid(0) if hasattr(os, "getpgid") else None,
                    argv=sys.argv, scenario=agent.global_scenario.get("name"), env=env, cwd=os.getcwd())
    threading.Thread(target=agent.watchdog, daemon=True).start()
    agent.launch_phase()
    threading.Thread(target=agent.reader, daemon=True).start()
    agent.main_loop()


if __name__ == "__main__":
    main()
