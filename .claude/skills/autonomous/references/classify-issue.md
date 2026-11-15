# Classifying an issue

You're one of several agents, each investigating one Chatbook issue. A coordinating agent uses your result to
decide what to do with the issue. Your job is to investigate and classify. Work read only:

- Don't label, comment on, close or edit anything on GitHub.
- Read the code in the checkout of origin/main you were given, not in your working directory, which may be stale
  or on another branch. Don't change that checkout's files or branch.
- Don't launch a front end. Several agents run at once, and front ends started this way aren't isolated from
  each other.
- Put scratch files in a temporary directory.

## Categories

### ready

An agent could fix the issue and open a small PR with no further input from a person. All of these must hold:

- **The desired behavior is clear.** Either the issue states it, or there's only one sensible fix (for example,
  a crash on an unhandled value, or a wrong result with an obvious right answer). No product, design, API or
  wording decision is left open.
- **The cause is known.** A fix that guesses at the cause, such as catching the failure or adding a fallback for
  a value nobody can explain, hides the bug instead of fixing it. Maintainers have turned fixes like that down.
- **It can be checked here.** You can reproduce it, or at least verify it, with what this machine has (see the
  environment facts you were given), and a test in `Tests/` can cover the fix. A UI bug counts if the agent
  making the fix can check it in a real front end with the drive-frontend skill.
- **It's still broken on main.**
- **The fix is small.** It fits in a small, reviewable PR and doesn't put Chatbook's performance or security at
  risk.

The cause can be known even when there's a choice of fix: a narrow fix for the reported failure, or a broader one
for the underlying problem. That still counts as ready. Plan the narrow fix, and name the broader one so the PR
can explain why it wasn't taken.

If the issue itself proposes a specific fix and you find a problem with it (side effects, or callers that rely on
the current behavior), classify it as needs-human-review and explain the problem. Fixing it a different way would
override what the reporter explicitly asked for.

A machine-generated failure report counts as ready when its Failure Data identifies the failing function and the
bad value well enough to write the fix and a test, even without steps to reproduce.

### close

Use one of these reasons:

- **already-fixed**: the failing code path has been fixed in one of two ways:
  - You found the merged PR, and its diff touches that code path.
  - The failure came from outside Chatbook (another Wolfram component or an LLM service), and it no longer
    happens with the versions Chatbook now requires. For example, Chatbook requires Wolfram 15.0, whose
    LLMConnections replaced the 14.x LLM service connections. Show that the failing value is now handled,
    either from that component's current code or by reproducing it.

  A change that stops the failing code from running counts as a fix, even if nobody found out why it failed.
  Check the timeline by version, not by date: the report's Chatbook version (Version and ReleaseID in Debug Data)
  must predate the fix. For a fix outside Chatbook, compare the report's Wolfram version instead. If a report on
  a newer version still shows the failure, it may be a regression. Don't close it.
- **duplicate**: another issue, open or closed, has the same failure signature (the same failing function and the
  same confirmed expression). Name the canonical issue.
- **lack-of-info**: there's nothing to act on, and either the report is more than 30 days old, or a run asked
  for details at least 14 days ago (in a comment containing `<!-- autonomous:needs-info -->`) and got no
  reply. "Nothing to act on" means there's no description or failure data that identifies a code path, and the
  code gives no way to work out what went wrong.

### request-info

The report is as empty as one you'd close as lack-of-info, but it's less than 30 days old and nobody has asked
for details yet. Reporters get a chance to fill in the gaps before their report is closed.

### needs-human-review

Anything that can't be closed or worked on without a person. For example:

- A product, design, API or wording decision is open. Examples are new public functions, UX changes, and feature
  requests whose shape isn't settled. Issues that need input from another team also count.
- The issue proposes a fix that turns out to have a problem (see ready).
- It needs infrastructure, credentials, services, platforms or front ends that this machine doesn't have. Check
  the environment facts. Examples are an LLM service without an API key, macOS, cloud deployments that need
  secrets, and the cloud notebook UI.
- It's a plausible bug that hasn't been fixed, but its cause can't be pinned down from the report and the code.
- The problem is outside Chatbook (another Wolfram component or an LLM service), and it still happens on current
  versions, or you can't show that it doesn't. Don't close these: a person needs to make sure it gets reported to
  the right team. If the problem no longer happens on current versions, it's already-fixed.
- It's a support question or an account problem rather than a bug. A person can answer or route it.
- It touches security. Keep security details out of Comment, because it may be posted publicly. Put them in Why
  and Evidence, which only the coordinating agent reads.
- The change would be large or risky.

When you're torn between ready and needs-human-review, choose needs-human-review. A wrong "ready" wastes a whole
run on a PR that may be thrown away, while a wrong flag only costs a person a quick look. Closing someone's issue
also needs evidence, so don't close an issue as already-fixed or duplicate on a hunch. An old report with nothing
in it at all should still be closed as lack-of-info, not flagged.

## Examples

These are the maintainer's calls on real issues.

- **needs-human-review**:
  - #326: asks for a new public `RegisterLLMPersona` function, which is a design decision.
  - #515: needs a cloud API that holds GitHub credentials.
  - #548: needs input from the design team.
  - #1175: needs a DeepSeek connection to test.
  - #1731: the issue proposes changing an option's default, which would stop titles for chats that are saved
    automatically.
- **close as lack-of-info**: #1024 is a one-line report from ten months earlier, with no error text or debug
  data.
- **close as already-fixed**:
  - #1143: #1371 removed the code that failed.
  - #1146: #1814 stopped the failing tokenizer from running for current models, even though nobody found out why
    it failed.
- **ready**:
  - #1807: wrong serialization output, with the expected output given and the code located.
  - #1773: the Failure Data identified an unhandled `Missing["NotAvailable"]` in `personaDisplayName`.
- **Investigate before you judge by age**: #1033 looked stale, with an old version and an unexplained crash in the
  title. But its Failure Data showed a race on a shared global that is still on main, so it couldn't be closed.

## How to investigate

- **Read the issue and all its comments**: `gh issue view <N> --comments`.
- **Machine-generated failure reports** have a `<details>` block with Debug Data, Settings, Failure Data and Stack
  Data. For these, use the signature and version-timeline method in
  `.claude/skills/triage-failure-reports/SKILL.md`. Its `scripts/extract_signatures.py` groups reports by
  signature. On Windows, run it with `PYTHONUTF8=1`. Without it, the script fails on non-ASCII report text.
- **Look for duplicates and fixes**:
  - `gh issue list --state all --search "<symbol>"`
  - `gh pr list --state merged --search "<symbol>"`
  - `git log -S"<symbol>" --oneline` and `git log --grep`

  Run `git` commands in the checkout you were given. Search for plain alphanumeric symbols, not Wolfram Language
  syntax. `git tag --contains <sha>` shows which tags contain a fix, but not every tag is a release. Use the
  latest release from the environment facts to say whether a fix has been released.
- **Check the current code** to see whether the failing code path still exists and still fails.
- **Prefer reading code to running it.** If running Wolfram Language code would settle the question, keep it
  short and use `wolframscript`, loading the checkout you were given with `PacletDirectoryLoad`. Don't load the
  development Chatbook into the Wolfram MCP evaluator, because that can hang every Wolfram MCP tool.

## Comments

The comment field depends on the category:

- **close or request-info**: write the exact comment to post.
- **needs-human-review**: write a note for whoever picks the issue up. It may be posted on the issue, so write it
  for the issue's readers. Write "none" if the issue makes the reason obvious.
- **ready**: write "none".

How to write each kind of comment:

- **Already fixed**:
  1. Start with "Fixed by #N." For a fix outside Chatbook, name it instead, for example "Fixed in Wolfram 15.0,
     which Chatbook now requires."
  2. Explain briefly and specifically what failed and how the fix deals with it.
  3. For a Chatbook fix, say whether it has been released. Fixes merged after the latest release will be in the
     next one.
  4. End with "Closing as fixed."
- **Duplicate**:
  1. Start with "Duplicate of #N."
  2. Explain that both reports have the same failure signature.
  3. End with "Closing as a duplicate. Please follow #N for updates."
- **Lack of info**:
  1. Thank the reporter.
  2. Say what's missing.
  3. Invite a new report with the error details if it still happens on the latest version. The "Report this
     issue" link in the error message fills those details in.
  4. End with "Closing as there isn't enough information to act on."
- **Request info**:
  1. Thank the reporter.
  2. Say exactly what would help: the error message, the debug details that are generated automatically, the
     prompt, or the steps.
  3. Say that the issue will be closed if there's no reply within two weeks.
  4. Put `<!-- autonomous:needs-info -->` on its own line before the attribution line.

Keep the tone plain and friendly, without filler. End every comment with this line:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## What to return

The coordinating agent reads your final message, not a person. Use exactly this format:

```
Issue: #<N> <title>
Category: ready | close | request-info | needs-human-review
Close reason: already-fixed | duplicate | lack-of-info | none
Resolver: <the fixing PR, the canonical issue, or the component version, e.g. #1735 or Wolfram 15.0; or none>
Confidence: high | medium | low
Why: <2-4 sentences>
Evidence:
- <facts you checked: versions, PRs, code paths, searches>
Comment:
<the exact comment, the note, or none>
Plan: <ready only: the fix, the tests, the rough size, and any broader fix to mention in the PR; otherwise none>
Alternative: <the next most plausible category and why, unless your confidence is high>
```
