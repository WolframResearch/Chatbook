#!/usr/bin/env python3
"""
extract_signatures.py - pull the "Failure Data signature" out of Chatbook's
auto-generated GitHub bug reports so duplicates can be grouped and triaged.

Chatbook crash reports embed a structured block: a failing Wolfram Language
call ("Evaluation"), the confirmed value that broke a Confirm* check
("Expression"), the pattern it failed to match ("Pattern"), a file:line
("Information"), a Stack Data list, plus a Debug Data table with Version and
ReleaseID. Two reports are the SAME bug when the failing function + confirmed
expression match - not merely when they share a keyword. This script extracts
those fields and groups issues by (function, expression) so you can see the
clusters at a glance.

Usage:
    # Inspect specific issues:
    python extract_signatures.py 1550 1545 1530

    # Find candidates by searching (state=all). Each --search runs a separate
    # `gh issue list` search; an issue must match ALL of them (intersection)
    # to be included - this is the "take the intersection of term searches"
    # step done for you:
    python extract_signatures.py --search NoModelList --search resolveFullModelSpec

    # Combine searches with explicit numbers:
    python extract_signatures.py --search NoModelList 1086

    # Machine-readable output for further processing:
    python extract_signatures.py --search NoModelList --json

Options:
    --search TERM      Repeatable. `gh issue list --state STATE --search TERM`.
                       Issues must match every --search term to be included.
    --state STATE      open|closed|all for the searches (default: all).
    --repo OWNER/NAME  Passed through to gh (otherwise gh infers from cwd).
    --limit N          Max results per search (default: 200).
    --json             Emit parsed records as JSON instead of the text report.

Requires: gh (authenticated), Python 3.8+. No third-party dependencies.
Run it from the repo working directory so gh resolves the right repository.
"""
import argparse
import json
import re
import subprocess
import sys


def run_gh(args):
    """Call gh and return stdout as text; exit cleanly on failure."""
    try:
        proc = subprocess.run(
            ["gh", *args], capture_output=True, text=True, check=True
        )
    except FileNotFoundError:
        sys.exit("error: `gh` not found on PATH. Install/auth the GitHub CLI first.")
    except subprocess.CalledProcessError as exc:
        sys.exit(f"error: gh {' '.join(args)}\n{exc.stderr.strip()}")
    return proc.stdout


def search_numbers(term, repo, state, limit):
    args = ["issue", "list", "--state", state, "--search", term,
            "--limit", str(limit), "--json", "number"]
    if repo:
        args += ["--repo", repo]
    data = json.loads(run_gh(args) or "[]")
    return {item["number"] for item in data}


def get_issue(number, repo):
    args = ["issue", "view", str(number), "--json",
            "number,title,state,createdAt,closedAt,body"]
    if repo:
        args += ["--repo", repo]
    return json.loads(run_gh(args))


def _table_value(body, label):
    """Value from a `| Label | ``...`` |` Debug Data / Settings row. Anchored to
    end-of-line so values containing `|` (e.g. Model's <|...|>) aren't cut short."""
    m = re.search(r"^\|\s*" + re.escape(label) + r"\s*\|\s*(.+?)\s*\|\s*$",
                  body, re.M)
    if not m:
        return None
    # Strip the ``...`` code fence and a surrounding pair of quotes, leaving
    # `2.6.0` rather than ``"2.6.0"``. Associations like Model start with `<`
    # so the quote-strip leaves them untouched.
    return m.group(1).strip().strip("`").strip().strip('"')


def _first(body, pattern, flags=re.S):
    m = re.search(pattern, body, flags)
    return m.group(1).strip() if m else None


# A field key inside the Failure Data association ends the previous value.
_KEY_END = r'(?:,\s*"\w+"\s*-?[>:]>?|\|>|\n)'


def parse_signature(issue):
    body = issue.get("body") or ""

    version = _table_value(body, "Version")
    release = _table_value(body, "ReleaseID")
    model = _table_value(body, "Model")
    service = None
    if model:
        m = re.search(r'"Service"\s*->\s*"([^"]+)"', model)
        service = m.group(1) if m else None

    # The full failing call. Terminate at the next Failure Data key rather than
    # on the `|>` of an inline <|...|> association inside the call itself.
    eval_full = _first(
        body,
        r'"Evaluation"\s*:>\s*(.+?),\s*'
        r'"(?:Information|ConfirmationType|Pattern|Failure|Stack|Arguments)"',
    )
    if not eval_full:  # Evaluation is the last key in the block
        eval_full = _first(body, r'"Evaluation"\s*:>\s*(.+)', flags=0)
    function = eval_full.split("[", 1)[0].split("`")[-1].strip() if eval_full else None

    # Confirm* failures record the bad value as "Expression". Unhandled-definition
    # failures (e.g. the model submenu) instead pass it as a call argument, so
    # fall back to the first Missing[...] inside the call. Sharing a bad value
    # across *different* functions means sibling bugs, not duplicates.
    expression = _first(body, r'"Expression"\s*:>\s*(.+?)\s*' + _KEY_END)
    if not expression and eval_full:
        m = re.search(r'Missing\[\s*"[^"]+"\s*\]', eval_full)
        expression = m.group(0) if m else None
    pattern = _first(body, r'"Pattern"\s*->\s*(.+?)\s*' + _KEY_END)

    info = _first(body, r'"Information"\s*->\s*"([^"]+)"')
    info_file, info_loc = None, None
    if info:
        # e.g. Models@@Source/Chatbook/Models.wl:845,18-845,108
        tail = info.split("@@", 1)[-1]
        if ":" in tail:
            info_file, info_loc = tail.split(":", 1)
        else:
            info_file = tail

    stack_block = _first(body, r"##\s*Stack Data\s*`{3,}\s*(.*?)`{3,}")
    stack = []
    if stack_block:
        stack = [ln.strip() for ln in stack_block.splitlines() if ln.strip()]

    return {
        "number": issue.get("number"),
        "title": issue.get("title"),
        "state": issue.get("state"),
        "createdAt": issue.get("createdAt"),
        "closedAt": issue.get("closedAt"),
        "version": version,
        "releaseID": release,
        "service": service,
        "function": function,
        "expression": expression,
        "pattern": pattern,
        "infoFile": info_file,
        "infoLoc": info_loc,
        "stack": stack,
    }


def signature_key(rec):
    return (rec["function"] or "?", rec["expression"] or "?")


def print_report(records):
    groups = {}
    for rec in records:
        groups.setdefault(signature_key(rec), []).append(rec)

    # Largest clusters first; they're the most likely duplicate sets.
    for key, recs in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        function, expression = key
        print("=" * 78)
        print(f"SIGNATURE  function={function}  expression={expression}")
        print(f"           pattern={recs[0]['pattern']}")
        print(f"           file={recs[0]['infoFile']}  ({len(recs)} issue(s))")
        print(f"           stack-top={' -> '.join(recs[0]['stack'][-3:]) or '?'}")
        print("-" * 78)
        for r in sorted(recs, key=lambda r: r["number"]):
            flag = "  [CLOSED]" if r["state"] == "CLOSED" else ""
            print(f"  #{r['number']:<6} {r['state']:<6} v{r['version'] or '?':<8} "
                  f"{r['service'] or '?':<14} {(r['title'] or '')[:46]}{flag}")
            print(f"          created={r['createdAt']}  release={r['releaseID']}")
        print()


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("numbers", nargs="*", type=int, help="issue numbers")
    ap.add_argument("--search", action="append", default=[], metavar="TERM")
    ap.add_argument("--state", default="all", choices=["open", "closed", "all"])
    ap.add_argument("--repo", default=None)
    ap.add_argument("--limit", type=int, default=200)
    ap.add_argument("--json", action="store_true", dest="as_json")
    args = ap.parse_args()

    candidates = set(args.numbers)
    if args.search:
        sets = [search_numbers(t, args.repo, args.state, args.limit) for t in args.search]
        intersection = set.intersection(*sets) if sets else set()
        candidates |= intersection
        for term, s in zip(args.search, sets):
            print(f"# search {term!r}: {len(s)} hits", file=sys.stderr)
        print(f"# intersection of searches: {sorted(intersection)}", file=sys.stderr)

    if not candidates:
        sys.exit("No issues to inspect. Pass issue numbers and/or --search terms.")

    records = [parse_signature(get_issue(n, args.repo)) for n in sorted(candidates)]

    if args.as_json:
        print(json.dumps(records, indent=2))
    else:
        print_report(records)


if __name__ == "__main__":
    main()
