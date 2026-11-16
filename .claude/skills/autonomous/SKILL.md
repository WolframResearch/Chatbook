---
name: autonomous
description: >-
  Make one unit of autonomous progress on Chatbook's GitHub backlog: review the oldest open PR labeled
  "autonomous" that isn't labeled "needs human review" yet (fix minor problems, recommend merging or not), or,
  if there is none, triage the five oldest unreviewed issues (flag them for human review, close them, or ask for
  details) and open a PR for the oldest one that's ready for autonomous work. Runs only when the user invokes
  /autonomous. Accepts "dry-run" (read-only) and specific issue numbers.
disable-model-invocation: true
argument-hint: "[dry-run] [issue numbers]"
---

# Autonomous work on issues and pull requests

One run of this skill makes one unit of progress without the user telling it what to work on. It either reviews
one PR that an earlier run opened, or triages a batch of issues and opens one PR. Each run is deliberately small:
the user reviews everything this skill produces and review is the bottleneck, so a run leaves behind at most one
PR review or one new PR, plus a summary that makes it quick to check.

Arguments: $ARGUMENTS

- **None**: a normal run.
- **`dry-run`**: read only. Investigate as usual, but don't label, comment, close, push or open anything. Report
  what you would have done. For issue work, stop after triage and say which issue you would work on and how.
- **Issue numbers** (for example `1034 1748`): triage those issues instead of the five oldest, and skip the PR
  review. Together with `dry-run`, this is how to check the triage rules against particular issues. Don't use
  issues that appear as examples in `references/classify-issue.md` for this check: the subagents just repeat
  the verdicts given there.

## Ground rules

- **Don't stop to ask.** The point of this skill is progress without guidance. Where you'd normally check with
  the user first (the task is ambiguous, conflicts with existing behavior, or might be a bad idea), the
  `needs human review` label and a comment saying why are how you check. Then move on.
- **Attribution.** End every comment, issue and PR description you post with this line:
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- **Never merge or close a PR.**
- **Security.** Anything that touches security goes to human review, with no security details in public text
  (a neutral comment, or none).
- **Leave the main checkout alone.** Other agents may be working in it. Fetch there, but do all work in
  worktrees.
- **Pass text with `--body-file`.** Write comments and PR descriptions to a file first. Wolfram Language code is
  full of backticks and quotes that the shell mangles.

The labels `autonomous`, `needs human review` and `merge recommended` already exist in the repository.

## Step 0: Set up

```bash
git fetch origin
git worktree add --detach ../Chatbook-autonomous origin/main 2>/dev/null || git -C ../Chatbook-autonomous checkout --detach origin/main
wolframscript -code 'Print["Wolfram: ", $Version]; Print["Latest Chatbook release: ", First[PacletFindRemote["Wolfram/Chatbook"]]["Version"]]; Print["API keys: ", Select[SystemCredentialKeys[], StringEndsQ["_API_KEY"]]]'
```

The second command creates or updates a read-only checkout of origin/main at `../Chatbook-autonomous`. The main
checkout may be behind origin or on another branch, so the triage subagents read the code there instead. The
third command's output tells the subagents what can be tested on this machine and whether a fix has been
released. Pass it to them as the environment facts.

## Step 1: Review a PR

Skip this step if the arguments name issues.

```bash
gh pr list --state open --label autonomous --search 'sort:created-asc -label:"needs human review"' --limit 1 --json number,title,url,headRefName
```

If nothing comes back, go to step 2. Otherwise review that PR. An earlier run opened it, so you're seeing it
fresh. Review it as critically as you would review someone else's work.

1. Read the PR description, the issue it closes, the whole diff and the CI results (`gh pr checks <N>`).
2. Check out the PR with `gh pr checkout <N> --worktree ../Chatbook-review/pr-<N>`. If git says the branch is
   already checked out in another worktree (the run that opened the PR may have left one), use that worktree and
   run `git pull --ff-only` there.
3. Check that the PR:
   - actually fixes the issue,
   - is correct,
   - has tests that would fail without the fix and aren't tautological,
   - follows AGENTS.md (tests, CodeInspector, and the performance rules if it touches the chat path),
   - is no bigger than it needs to be,
   - has an accurate description, including the broader fix it didn't take if it took a narrow one.

   Run the tests it adds or touches. The `code-review` skill (for example with `high <N>`) gives a useful
   second pass.
4. Sort what you find:
   - **Problems that should block merging but have a small fix that doesn't change the PR's approach.** For
     example: a wrong or missing test, a case the issue names that isn't handled, a CodeInspector issue, a CI
     failure the PR caused, a simple conflict with main, or an inaccurate description. Fix these, then commit
     and push to the PR branch. Use `gh pr edit` for the description. Resolve a conflict by merging origin/main
     into the branch. Don't rebase or force-push.
   - **Bigger problems**, such as a wrong approach, an open design decision or major rework. Don't fix these.
     Describe them in the summary.
   - **Nits** (naming, style, preferences). Don't fix these. At most, mention them in the summary.
5. Add the `merge recommended` label if, with your fixes, you would merge the PR as it is: it fixes the issue,
   the tests pass, and CI passed. If you pushed fixes, run the affected tests locally instead of waiting for CI
   to run again. The person who merges will see the new CI result. Always add the `needs human review` label,
   whatever the outcome, so the next run doesn't review the same PR.

Findings go in the summary, not in a PR comment. Then go to step 4.

## Step 2: Triage issues

If the arguments name issues, triage those. Otherwise:

```bash
gh issue list --state open --limit 30 \
  --search 'sort:created-asc -label:"needs human review" -linked:pr' \
  --json number,title,createdAt,comments \
  --jq '[.[] | select(((.comments[-1].body // "") | contains("<!-- autonomous:needs-info -->")) and ((.comments[-1].createdAt | fromdateiso8601) > (now - 14*86400)) | not)] | .[:5] | map({number, title})'
```

This lists the five oldest open issues that:

- aren't labeled `needs human review`,
- aren't linked to a PR (a PR from an earlier run, or from anyone else, is already handling them),
- aren't waiting on a reply to a request for details that a run posted in the last 14 days.

Launch one subagent per issue, all at once. Give each one this prompt:

> Read `<this skill's directory>/references/classify-issue.md` and follow it to classify issue #<N> of
> WolframResearch/Chatbook. A read-only checkout of origin/main is at `<absolute path of ../Chatbook-autonomous>`.
> Environment facts: <output of the wolframscript command>

As each result comes back, launch a verifier for it if its Comment isn't "none". That covers every close and
request-info, and every needs-human-review that has a note. Give the verifier this prompt:

> Read `<this skill's directory>/references/verify-result.md` and follow it to check the triage result below for
> issue #<N> of WolframResearch/Chatbook. A read-only checkout of origin/main is at
> `<absolute path of ../Chatbook-autonomous>`. Environment facts: <output of the wolframscript command>
>
> <the triage agent's full result>

Verifiers roughly double what triage costs, and that's worth it. The first time they ran, they found a factual
error in every comment they checked: a wrong version, advice that didn't apply to the reporter's Wolfram version,
or a promise the code didn't keep. Verification still runs in a dry run, so the report shows the comments that
would have been posted.

Wait until all the triage agents and verifiers have finished. They only investigate and don't write to GitHub.
You do the writing, after reading all their results, so every change goes through one place where it can be
checked. Flag the issue for human review instead of applying the result if:

- the verifier disputes the verdict. Write a note that gives both conclusions and their evidence.
- a close rests on thin evidence.
- two agents disagree about a duplicate.

Apply each result. Where the table says "the comment" or "the note", use the verifier's version, which has its
corrections. In a dry run, skip all of these writes.

| Result | What to do |
| --- | --- |
| needs-human-review | Add the `needs human review` label. Post the note as a comment if it records something worth keeping: a cause, code locations, fix options, or the decision that's needed. Skip the comment when the reason is obvious from the issue, as it is for a plain feature request. For a security issue, post a neutral comment or none (see Ground rules). |
| close | Post the comment, then close the issue: `--reason completed` if it's already fixed, `--duplicate-of <canonical issue>` if it's a duplicate, or `--reason "not planned"` if it lacks information. |
| request-info | Post the comment. It ends with the `<!-- autonomous:needs-info -->` marker. Don't add a label. If the reporter replies, the issue comes back with the new details. If not, it comes back after 14 days and gets closed. |
| ready | Nothing yet. |

If any issue is ready, take the oldest one to step 3. If none is, go to step 4. Don't start another batch. Run
the skill again in a fresh context instead: that's cheaper, and each run's summary stays short.

## Step 3: Fix the issue and open a PR

1. Create a worktree from up-to-date main:
   `git worktree add --no-track -b bugfix/<short-name> ../Chatbook-bugfix/<short-name> origin/main`. Use
   `feature/` instead of `bugfix/` for a feature.
2. Work as AGENTS.md describes. Start from the plan in the triage result:
   1. Reproduce the problem first, ideally as a failing test.
   2. Fix it, and add tests in `Tests/`. Read `docs/testing.md` before writing tests.
   3. Run the tests with TestReport and check the changed files with CodeInspector. To run development Chatbook
      code, use `wolframscript`. Don't load it into the Wolfram MCP evaluator, because that can hang every
      Wolfram MCP tool. If TestReport hangs, run the test files with `wolframscript` instead.
   4. If the change touches the chat path, measure it cold and warm.
3. Keep the PR small. If you took a narrow fix where a broader one exists, say so in the PR description: what the
   broader fix would be, and why you didn't take it.
4. If the work shows the issue isn't ready after all (it needs a decision, the cause isn't what triage thought,
   or it's much bigger), stop:
   1. Label the issue `needs human review`.
   2. Comment with what you found.
   3. Don't push the branch.

   Then try the next ready issue from this batch, if there is one. If there isn't, go to step 4.
5. If you notice a separate problem that doesn't belong in this PR, check that it isn't already filed, then file
   an issue for it with the `autonomous` label. Later runs triage it like any other issue. If it touches
   security, don't file it. Describe it in the summary instead.
6. Commit, push with `git push -u origin HEAD`, and open the PR. Put `Closes #<N>` in the description and add the
   `autonomous` label. Don't add `needs human review`: the next run reviews the PR and adds that label.

## Step 4: Summarize

End the run with a summary in the session. The user reads it to decide what to look at, so make it easy to skim
and link everything.

- **After a PR review**, give:
  - the PR,
  - whether you recommended merging,
  - the problems you found, most serious first,
  - the commits you pushed and what each one fixed,
  - any nits.
- **After triage**, list each issue with its outcome and a one-line reason:
  - closed, with the fixing PR or the canonical issue,
  - flagged, with the decision or resource it needs,
  - details requested,
  - ready.

  Then list what the verifiers caught: each correction to a comment and each verdict they disputed.

  If you opened a PR, also give its link, what it changes, how it's tested, the broader fix you didn't take, and
  any follow-up issues you filed.
- **After a dry run**, give the same summary, written as what you would have done.
