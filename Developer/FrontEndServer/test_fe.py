#!/usr/bin/env python3
"""End-to-end smoke test for the front end server and fe.py.

Launches a fresh front end on a private Xvfb display, exercises the client commands against it, and stops it again.
Needs Xvfb and a licensed Wolfram installation. Takes about a minute.

    python3 Developer/FrontEndServer/test_fe.py            # launch, test, stop
    python3 Developer/FrontEndServer/test_fe.py -s 2400    # test an already running server (left running)
"""

import argparse
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
FE = [sys.executable, os.path.join(HERE, "fe.py")]

TEST_NOTEBOOK = r'''
Global`fetestPressed = 0; Global`fetestField = "abc";
CreateDocument[{
  Cell["Front end server test", "Title"],
  Cell[BoxData[ButtonBox["\"Press me\"", ButtonFunction :> (Global`fetestPressed += 1), Appearance -> Automatic,
    Evaluator -> Automatic, Method -> "Queued", BoxID -> "fetestButton"]], "Output"],
  Cell[BoxData[InputFieldBox[Dynamic[Global`fetestField], String, BoxID -> "fetestField"]], "Output"],
  Cell["Some searchable text", "Text"]
}, DockedCells -> {Cell[BoxData[ButtonBox["\"Docked\"", ButtonFunction :> (Global`fetestPressed += 10),
    Appearance -> Automatic, Evaluator -> Automatic, Method -> "Queued", BoxID -> "fetestDocked"]], "DockedCell"]},
  WindowTitle -> "FE Server Test", WindowMargins -> {{100, Automatic}, {Automatic, 60}}, WindowSize -> {520, 420}]
'''


class Runner:
    def __init__(self, server):
        self.server = server
        self.failures = []

    def fe(self, *args, check=True, timeout=240, stdin=None):
        cmd = FE + (["-s", str(self.server)] if self.server else []) + list(args)
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, input=stdin)
        if check and proc.returncode != 0:
            raise AssertionError(f"{' '.join(args)} failed ({proc.returncode}): {proc.stderr.strip() or proc.stdout.strip()}")
        return proc.stdout.strip()

    def fails(self, *args):
        """Run a command that is expected to fail; return its error output."""
        cmd = FE + (["-s", str(self.server)] if self.server else []) + list(args)
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=240)
        if proc.returncode == 0:
            raise AssertionError(f"{' '.join(args)} unexpectedly succeeded: {proc.stdout.strip()}")
        return proc.stderr

    def eval(self, code, *extra):
        return self.fe("eval", code, *extra)

    def test(self, name, func):
        start = time.time()
        try:
            func()
            print(f"ok    {name} ({time.time() - start:.1f}s)")
        except Exception as e:  # noqa: BLE001 - report every failure and keep going
            self.failures.append(name)
            print(f"FAIL  {name}: {e}")


def expect(actual, expected):
    if actual != expected:
        raise AssertionError(f"expected {expected!r}, got {actual!r}")


def run_tests(r):
    r.test("ping and info", lambda: json.loads(r.fe("--json", "info"))["Port"])
    r.test("evaluate", lambda: expect(r.eval("1 + 1"), "2"))
    r.test("multi-statement code", lambda: expect(r.eval("a = 2;\nb = 3;\na b"), "6"))
    r.test("main-link evaluation", lambda: expect(r.eval("First[$FrontEnd] === $ParentLink"), "True"))
    r.test("preemptive evaluation", lambda: expect(r.fe("--preemptive", "eval", "First[$FrontEnd] === $ParentLink"), "False"))
    r.test("messages and prints", lambda: expect(
        r.eval('Print["hi"]; 1/0; 3').splitlines(),
        ["3", "[message] Power::infy: Infinite expression 0^(-1) encountered.", "[print] hi"]))
    r.test("unicode", lambda: expect(r.eval('StringJoin["∫ αβ", " 😀"]', "--form", "String"), "∫ αβ 😀"))
    r.test("large request", lambda: expect(r.fe("eval", "-", stdin='StringLength["' + "x" * 3000000 + '"]'), "3000000"))
    r.test("large response", lambda: expect(len(r.eval('StringRepeat["ab", 500000]', "--form", "String",
                                                         "--max", "2000000")), 1000000))
    r.test("abort is contained", lambda: (expect("Interrupted" in r.fails("eval", "Abort[]"), True),
                                          expect(r.eval("1 + 1"), "2")))
    r.test("syntax error", lambda: expect("SyntaxError" in r.fails("eval", "1+"), True))
    r.test("Return in code", lambda: expect(r.eval('If[True, Return["early"]]; "late"'), '"early"'))
    r.test("JSON form", lambda: expect(json.loads(r.eval("<|\"a\" -> {1, 2}|>", "--form", "JSON")), {"a": [1, 2]}))
    r.test("packages stay loaded", lambda: (
        r.eval('BeginPackage["FETestPkg`"]\nfetestPkgFn::usage = ""\nBegin["`P`"]\nfetestPkgFn[x_] := x + 1\nEnd[]\n'
               'EndPackage[]'),
        expect(r.eval("{fetestPkgFn[1], Context[fetestPkgFn]}"), '{2, "FETestPkg`"}')))
    r.test("evaluate as a cell", lambda: expect(r.fe("eval", "--cell", "Range[3]").split("] ", 1)[1], "{1, 2, 3}"))
    r.test("cell syntax error", lambda: expect("SyntaxError" in r.fails("eval", "--cell", "Plot[x, {x, 0, 1}"), True))
    r.test("cell message text", lambda: expect("Infinite expression" in r.fe("eval", "--cell", "1/0"), True))
    r.test("missing code file", lambda: expect("File not found" in r.fails("eval", "@/nonexistent/code.wl"), True))
    r.test("JSON errors", lambda: expect(json.loads(subprocess.run(
        FE + (["-s", str(r.server)] if r.server else []) + ["--json", "cells", "No Such Notebook"],
        capture_output=True, text=True).stdout)["errorType"], "NotebookNotFound"))
    r.test("unknown key", lambda: expect("Unknown key name" in r.fails("key", "ctrl+NoSuchKey"), True))
    r.test("wait for idle", lambda: (r.fe("eval", "--cell", "--no-wait", "Pause[2]"), r.fe("wait")))

    r.eval(TEST_NOTEBOOK)
    time.sleep(1)
    r.test("notebooks", lambda: expect("FE Server Test" in r.fe("nbs"), True))
    r.test("cells", lambda: expect(len(r.fe("cells", "FE Server Test").splitlines()), 4))
    r.test("screenshot", lambda: expect(os.path.exists(r.fe("screenshot", "FE Server Test").split(" (")[0]), True))
    r.test("locate box", lambda: r.fe("locate", "--box", "fetestButton", "--notebook", "FE Server Test"))
    r.test("click box", lambda: (r.fe("click", "--box", "fetestButton", "--notebook", "FE Server Test"),
                                 time.sleep(0.8), expect(r.eval("Global`fetestPressed"), "1")))
    r.test("press box", lambda: (r.fe("press", "fetestButton", "--notebook", "FE Server Test"), time.sleep(0.8),
                                 expect(r.eval("Global`fetestPressed"), "2")))
    r.test("click docked box", lambda: (r.fe("click", "--box", "fetestDocked", "--notebook", "FE Server Test"),
                                        time.sleep(0.8), expect(r.eval("Global`fetestPressed"), "12")))
    r.test("type into field", lambda: (
        r.fe("click", "--box", "fetestField", "--notebook", "FE Server Test"), r.fe("key", "ctrl+a"),
        r.fe("type", 'Hello, World! {"q"} ~`@#$%^&*()_+'), r.fe("key", "Return"), time.sleep(0.8),
        expect(r.eval("Global`fetestField", "--form", "String"), 'Hello, World! {"q"} ~`@#$%^&*()_+')))
    r.test("locate text in a text cell", lambda: r.fe("locate", "--text", "searchable", "--notebook", "FE Server Test"))
    r.test("type into a cell", lambda: (
        r.fe("type", " more", "--cell", json.loads(r.fe("--json", "cells", "FE Server Test"))[3]["id"]),
        expect(r.fe("cells", "FE Server Test").splitlines()[3].endswith("Some searchable text more"), True)))
    r.test("read an attached cell", lambda: r.fe(
        "read", json.loads(r.fe("--json", "cells", "FE Server Test", "--attached"))[0]["ref"]))
    r.test("click image point", lambda: (r.fe("screenshot", "FE Server Test"), r.fe("click", "--image", "10,10")))
    r.test("messages window", lambda: r.fe("messages", "--clear"))
    r.test("click outside the screen", lambda: expect("outside the screen" in r.fails("click", "99999,99999"), True))
    r.test("ambiguous notebook", lambda: (
        r.eval('CreateDocument[{}, WindowTitle -> "FE Server Test 2"]'),
        expect("AmbiguousNotebook" in r.fails("cells", "Server Test"), True),
        r.fe("close", "FE Server Test 2")))
    r.test("close notebook", lambda: (r.fe("close", "FE Server Test"),
                                      expect("FE Server Test" in r.fe("nbs"), False)))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-s", "--server", help="test this running server instead of launching one")
    args = parser.parse_args()

    launched = None
    if not args.server:
        out = subprocess.run(FE + ["--json", "launch"], capture_output=True, text=True, timeout=300)
        if out.returncode != 0:
            print("launch failed:", out.stderr or out.stdout)
            return 1
        launched = json.loads(out.stdout)["port"]
        print(f"launched front end server on port {launched}")
    runner = Runner(args.server or launched)
    try:
        run_tests(runner)
    finally:
        if launched:
            subprocess.run(FE + ["-s", str(launched), "stop"], capture_output=True, text=True, timeout=60)
    print(f"\n{'FAILED: ' + ', '.join(runner.failures) if runner.failures else 'all tests passed'}")
    return 1 if runner.failures else 0


if __name__ == "__main__":
    sys.exit(main())
