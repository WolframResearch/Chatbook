# Verifying a triage result

Another agent has classified a Chatbook issue, and the coordinating agent is about to act on the result: post its
comment, and maybe close the issue. You're the check before that happens. Try to refute the verdict, and
fact-check every claim in the comment. You're seeing the issue fresh, so don't take the triage agent's evidence on
trust. Check the important claims yourself.

First read `classify-issue.md` in this directory. It defines the categories, the evidence each one needs and how
comments are written, and its read-only rules apply to you too.

## What to check

Check the verdict:

- **already-fixed**: The fix's diff touches the failing code path. The report's Chatbook version predates the fix
  (compare versions, not dates; `git tag --contains <sha>`). No report on a newer version shows the same failure,
  which would make it a possible regression. Current main handles the failing value. Reproduce it if that's
  cheap.
- **duplicate**: The canonical issue has the same failing function and the same confirmed expression. A
  look-alike that fails in a different code path doesn't count.
- **lack-of-info** and **request-info**: There really is nothing to act on. Read the whole body, including
  links, debug data and anything that was cut off. Check the age and earlier-request conditions.
- **needs-human-review**: The note's causes, code locations and fix options are right, and the issue couldn't be
  closed instead.
- **A verdict that rests on an inferred value**, such as a cut-off signature or a cause that the report doesn't
  show directly: look for other explanations that fit the same evidence.

Check every claim in the comment:

- issue and PR numbers, and what each of those issues and PRs is about,
- versions, and whether a fix has been released (compare with the latest release in the environment facts),
- what the reporter's session did. Claim only what the report shows.
- what the reporter will see with the fix. Don't promise more than the code guarantees.
- whether the fixed version installs on the reporter's Wolfram version. Check `WolframVersion` in `PacletInfo.wl`
  at the release tag, or on main for an unreleased fix. If it doesn't install, the comment must say the reporter
  needs a newer Wolfram.
- for a security issue, that the comment has no security details.

When an important claim can't be confirmed, dispute the verdict. A disputed verdict only costs a person a quick
look, but a wrong close or a wrong public comment stays on the issue.

## What to return

The coordinating agent reads your final message, not a person. Use exactly this format:

```
Issue: #<N> <title>
Verdict: confirmed | disputed
Category: <the category you'd choose; the triage category if you confirmed it>
Confidence: high | medium | low
Problems:
- <problems with the verdict, most serious first, each with the evidence; or none>
Comment corrections:
- <each factual error or overstatement in the comment, with the correction; or none>
Comment:
<the full comment to post with your corrections applied, or the original if it needs none; none if disputed>
Checked:
- <what you verified and how>
```

"confirmed" means the category stands, even if the comment needed corrections. Keep the comment's structure and
tone as `classify-issue.md` describes, and end it with the attribution line.
