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
  exit           {"code"?: 0, "delay"?: 0}

"when" makes a step conditional:
  "when": "cancelled" | "not_cancelled"
  "when": {"cancelled": bool, "request": name, "outcome": "selected" | "cancelled" |
           "error" | "timeout" | [...], "optionId": id | [...], "responded": bool}
"end": true stops the scenario after that step.

String values of the form "${name}" are replaced (keeping the JSON type) by:
sessionId, promptId, lastRequestId, promptText, cwd, i (the "repeat" index),
pid; "${bytes:N}" becomes a string of N "x" characters.  "${name}" inside a longer
string is replaced textually.

Wire log
--------
One JSON object per line: {"seq": n, "t": unixTime, "dir": d, ...} where d is
  "in"     {"msg": message received from the client}  ({"raw": text} if unparsable)
  "out"    {"msg": message sent to the client}         ({"raw": text} for raw steps)
  "event"  {"event": name, ...}: start, eof, exit, sigterm, scenario, scenario_end,
           cancel_seen, cancel_request_sent, wait_response, spawn, unexpected_response,
           duplicate_response, response_after_cancel_request, watchdog, mark, error
Out records are written before the bytes go to stdout.
"""

import argparse
import base64
import copy
import datetime
import json
import os
import queue
import re
import signal
import subprocess
import sys
import threading
import time
import traceback

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


class Agent(object):
    def __init__(self, args):
        self.args = args
        self.log = WireLog(args.log)
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

    # ------------------------------------------------------------- inbound
    def reader(self):
        stdin = sys.stdin.buffer
        while True:
            try:
                line = stdin.readline()
            except Exception:
                line = b""
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
               "history": None, "prompted": False}
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
            return self.VAR.sub(lambda mm: str(self.lookup(mm, extra)), obj)
        if isinstance(obj, list):
            return [self.subst(x, extra) for x in obj]
        if isinstance(obj, dict):
            return dict((k, self.subst(v, extra)) for k, v in obj.items())
        return obj

    def cancelled(self):
        return self.agent.cancel_count(self.sid) > self.cancel_base

    def check_cancel(self):
        if self.on_cancel is not None and not self.handling_cancel and self.cancelled():
            raise CancelledRun()

    def wait(self, pred, timeout):
        """Wait until pred() or timeout; raise CancelledRun if a registered cancel handler should run."""
        deadline = time.time() + float(timeout)
        with self.agent.cond:
            while True:
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
    threading.Thread(target=agent.reader, daemon=True).start()
    threading.Thread(target=agent.watchdog, daemon=True).start()
    agent.main_loop()


if __name__ == "__main__":
    main()
