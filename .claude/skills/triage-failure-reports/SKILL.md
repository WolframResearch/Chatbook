---
name: triage-failure-reports
description: >-
  Triage Chatbook's auto-generated bug-report issues on GitHub by grouping them
  on their Failure Data signature (the failing Wolfram Language function plus the
  confirmed expression/pattern), finding the canonical issue or the PR that
  resolves each cluster, and closing the rest with an explanatory comment. Use
  this whenever the user wants to dedupe, triage, or clean up GitHub issues - for
  example "find duplicates of #1550", "are any of these crash reports the same
  bug?", "close the issues already fixed by PR #906", "triage the open failure
  reports", or after landing a fix, "which open issues does this close?". It
  distinguishes true duplicates from look-alikes that fail in a different code
  path, verifies a candidate fixing PR actually touches the relevant code, and
  checks each report's Version/ReleaseID against the fix so reports filed on
  outdated versions are closed correctly and possible regressions are flagged.
---

# Triage duplicate issues by Failure Data signature

Chatbook posts machine-generated bug reports to GitHub. They pile up because the
same underlying bug gets reported many times across different services, versions,
and users. This skill turns that pile into a small number of signature-grouped
clusters, ties each cluster to the issue or PR that resolves it, and closes the
duplicates with a comment that tells the reporter where the real fix lives.

The hard part is **not** the closing - it's being sure two reports are actually
the same bug before you act on someone else's issue. Most of this skill is about
earning that confidence.

## How a Chatbook failure report is structured

Each report has an auto-generated `<details>` block. The fields that matter:

- **Debug Data table** - `Version` and `ReleaseID` (the git SHA the user was
  running). These drive the timeline check; do not skip them.
- **Settings table** - `Model`, e.g. `<|"Service" -> "OpenAI", "Name" -> Automatic|>`.
  Tells you which service/model triggered it.
- **Failure Data** - the heart of the signature:
  - `"Evaluation"` - the failing call, e.g.
    `Wolfram`Chatbook`Common`resolveFullModelSpec[<|"Service" -> "OpenAI", "Name" -> Automatic|>]`.
    The **short function name** (`resolveFullModelSpec`) is the primary key.
  - `"Expression"` - the value that broke a `Confirm*` check, e.g.
    `Missing["NoModelList"]`. (Unhandled-definition failures don't have this
    field; the bad value is a call argument instead - see the script's fallback.)
  - `"Pattern"` - what the value failed to match, e.g. `_List | Missing["NotConnected"]`.
  - `"Information"` - `Tag@@path:line,col`. Useful for the file; **ignore the
    line number** - it drifts between versions for the same bug.
- **Stack Data** - the call stack, e.g. `resolveAutoSettings0 -> EvaluateChatInput`.

### What makes two reports the same bug

Same **failing function** + same **confirmed expression** (and pattern, when
present). That's it. Everything else is allowed to vary:

- Different **service/model** (OpenAI vs Anthropic vs LocalEvaluator) - same bug.
- Different **line number** in `Information` - same bug, different version.
- Different **version/ReleaseID** - same bug reported over time.

The trap to avoid: the *same expression surfacing in a different function* is a
**sibling bug, not a duplicate**. For example `Missing["NoModelList"]` thrown
inside `resolveFullModelSpec` (chat evaluation) is a different bug from
`Missing["NoModelList"]` passed into `makeServiceModelMenu` (the model submenu UI),
even though both mention `NoModelList`. They get fixed by different PRs. Keyword
co-occurrence is a candidate filter, never a conclusion.

## Workflow

### 1. Establish the reference signature

If the user named a reference issue, read it (`gh issue view <N>`) and pull the
failing function + expression + pattern from its Failure Data. If they instead
handed you a set of reports or a fix, derive the signature from the cluster or
from the code the fix touches.

### 2. Search broadly for candidates

Search the **distinctive symbols** from the signature - typically the head of the
expression (`NoModelList`) and the failing function (`resolveFullModelSpec`):

```bash
gh issue list --state all --search "NoModelList" --json number,title,state
gh issue list --state all --search "resolveFullModelSpec" --json number,title,state
```

Two rules that matter:

- **Search `--state all`.** You want closed siblings too: the canonical issue may
  already be closed, and you must not re-close or miss it.
- **Use clean alphanumeric tokens.** GitHub's search tokenizer garbles backticks,
  brackets, and quotes - search `NoModelList`, not `Missing["NoModelList"]`.

Strong candidates appear in **every** term's results (intersection). The helper
script does this intersection for you.

### 3. Confirm each candidate against the signature

**Do not trust keyword co-occurrence.** Open each candidate's Failure Data and
verify the failing function and confirmed expression actually match. The helper
script extracts and groups these for you:

```bash
# Intersect the searches and print every candidate grouped by signature:
python .claude/skills/triage-failure-reports/scripts/extract_signatures.py \
  --search NoModelList --search resolveFullModelSpec

# Or inspect a hand-picked set:
python .claude/skills/triage-failure-reports/scripts/extract_signatures.py 1550 1545 547
```

Run it from the repo working directory so `gh` resolves the right repository. It
prints, per signature group, every issue with its state, version, service,
created date, and ReleaseID - exactly the columns you need for the next two steps.
Read `scripts/extract_signatures.py` if you need to adjust parsing for a report
format it doesn't recognize.

Confirm the groups make sense: the cluster you care about shares one function +
expression; anything in a different function is a sibling to set aside.

### 4. Identify and verify the resolver

Every cluster needs a single thing it is "resolved by". Two cases:

- **Duplicates of another issue.** Pick the canonical issue - usually the earliest,
  or the one with the clearest title/discussion. The rest are duplicates of it.
- **Fixed by a merged PR.** The user may name it ("these are fixed by #906"), or
  you find it (`gh pr list --search`, or the PR that last touched the failing
  function). **Verify it - don't take it on faith.** A `#NNNN` can be an issue or a
  PR (they share one number space), so confirm with `gh pr view <N>`, then check
  the diff actually addresses this signature:

```bash
gh pr view 906 --json number,title,state,mergedAt,mergeCommit
gh pr diff 906 | grep -iE 'makeServiceModelMenu|NoModelList'
```

You want to see the diff add or change handling for the *failing function* and the
*expression* (e.g. a new `makeServiceModelMenu[..., Missing["NoModelList"]]`
definition). If the diff doesn't touch the signature's code path, it is not the fix.

### 5. Verify the timeline - by version, not just date

This is the step that prevents wrong closes. A report can be filed *after* a fix
merged and still be the old bug, because the user was on a stale paclet. So compare
the **report's Version/ReleaseID** (from Debug Data) against the fix, not the
issue's creation date:

- Report version **predates** the fix -> the fix resolves it. Close it.
- Report version is **newer** than the fix and still shows the signature -> it is
  **not** resolved (possible regression). Do **not** close as fixed; flag it for a
  human and keep it open.
- An issue *created* after the merge but on an *older* version is still fixed - the
  version is what counts.

For an open canonical issue (not a merged PR), there's no version gate; you're just
folding duplicates into the one that stays open.

### 6. Close with an explanatory comment

Print the grouped findings first - what will be closed, under which canonical issue
or PR, and why - so each `gh` write you then make is an informed action. (Closing
and commenting are irreversible and land on other people's issues; the per-write
approval is the safety gate, and your verification in steps 3-5 is what makes that
approval meaningful.)

Comment, then close. Lead the comment with the GitHub-recognized phrasing so the
link is obvious, and pick the close reason that matches the situation:

| Situation | Comment leads with | Close reason |
| --- | --- | --- |
| Duplicate of another issue | `Duplicate of #<canonical>.` | `--reason "not planned"` |
| Fixed by a merged PR | `Fixed by #<pr>.` | `--reason completed` |

`gh` has no native "duplicate" reason; `not planned` is the honest fit because the
work is tracked elsewhere. A real merged fix is `completed`.

**Quoting matters.** WL signatures contain backticks, brackets, and quotes that a
shell will mangle (backticks trigger command substitution). Write the comment to a
file and use `--body-file`:

```bash
# comment.md  ->  "Duplicate of #1550 - same `resolveFullModelSpec` failure with
#                  `Missing[\"NoModelList\"]` ... Fixed by #1558. Closing as a duplicate."
gh issue comment 1545 --body-file comment.md
gh issue close   1545 --reason "not planned"
```

Reuse one comment file across a cluster. Use the scratchpad for fetched bodies and
comment files. Leave already-closed issues alone (just note them). Leave sibling
clusters open unless they have their own resolver.

## Worked example

The case this skill was built from:

- Reference **#1550**: `resolveFullModelSpec[<|... "Name" -> Automatic|>]` fails a
  `ConfirmMatch` with `Missing["NoModelList"]` against `_List | Missing["NotConnected"]`.
- Searching `NoModelList` x `resolveFullModelSpec` and grouping yielded **8** issues
  with that exact signature (1086, 1137, 1303, 1468, 1514, 1530, 1545, 1550) across
  OpenAI/Anthropic/DeepSeek/GoogleGemini/LocalEvaluator - all duplicates, fixed by
  PR #1558. Closed with `Duplicate of #1550` / `not planned`.
- Three more (#547, #969, #892) shared `Missing["NoModelList"]` but in
  `makeServiceModelMenu` - a **sibling**, not a duplicate. Verified PR **#906**
  added the `makeServiceModelMenu[..., Missing["NoModelList"]]` overload; their
  versions (1.4.1, 1.4.6, 1.5.2) all predate it, so closed with `Fixed by #906` /
  `completed`. #969 was *filed* after #906 merged but on old v1.4.6 - the version
  check, not the date, is what confirmed it.

## Gotchas

- Issues and PRs share one number sequence - confirm which a `#NNNN` is.
- GitHub search ignores/garbles backticks, brackets, quotes - search symbols.
- `Information` line numbers drift across versions - never match on them.
- Verify a claimed fixing PR's diff; "should be fixed by #X" is a hypothesis.
- Timeline check is by **version/ReleaseID**, not issue creation date.
- A shared expression in a different function is a sibling bug - close it only
  under its own resolver, never fold it into the wrong cluster.
