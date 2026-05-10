---
name: codebase-audit-resolve
description: Use to work through GitHub issues tagged `codebase-audit` (created by the `codebase-audit-issues` skill). Processes them serially — branch, fix, PR, self-review loop, wait for green CI, merge, then move to the next. Sister skill to `codebase-audit` and `codebase-audit-issues`.
---

# Codebase Audit → Resolve

Serially resolve every open issue tagged `codebase-audit`. One issue at a time, end-to-end: branch → fix → PR → self-review loop → green CI → squash-merge → next.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`).
- Clean working tree on the default branch (typically `main` or `master`). If dirty, stop and tell the user.
- Branch protection / required checks are honored — never bypass.

## Selection & ordering

```bash
gh issue list \
  --label codebase-audit \
  --state open \
  --json number,title,labels,createdAt \
  --jq 'sort_by(
    (if any(.labels[]; .name == "severity:critical") then 0
     elif any(.labels[]; .name == "severity:warning") then 1
     else 2 end),
    .createdAt
  ) | .[] | "\(.number)\t\(.title)"'
```

Process order:
1. All `severity:critical` first (oldest first within the bucket)
2. Then `severity:warning`
3. Then `severity:info`

Skip any issue that already has an open PR linked (check `gh issue view <n> --json projectItems,closedByPullRequestsReferences` — if a PR is open, leave to a human).

If the user passed an explicit issue number, process only that one.

## Per-issue workflow

For each issue `#N`:

### 1. Sync and branch

```bash
git checkout main
git pull --ff-only
BRANCH="audit/${N}-$(echo "$TITLE" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-' | cut -c1-40)"
git checkout -b "$BRANCH"
```

Comment on the issue so others know it's being worked:
```bash
gh issue comment $N --body "Picking this up — branch \`$BRANCH\`."
```

### 2. Understand the finding

Read the issue body (`gh issue view $N`). The body contains the original finding, file path(s), and the suggested resolution. Read the referenced file(s) to verify the finding still applies — audit data can go stale.

If the finding is no longer valid (file was already fixed/removed/renamed), close the issue with an explanation and skip:
```bash
gh issue close $N --comment "No longer applicable: <reason>." --reason not_planned
```
Move to the next issue.

### 3. Implement the fix

Make the smallest change that resolves the finding. Stay on-scope — don't refactor adjacent code. If the fix touches more than ~50 lines or spans multiple unrelated areas, STOP and convert the issue into a parent + sub-issues instead of a single PR (comment on the issue and move on).

Run the project's tests/linters locally before pushing. If the project has a test command discoverable from `Makefile` / `package.json` scripts / `pyproject.toml`, run the relevant subset.

### 4. Commit and push

```bash
git add -A
git commit -m "<conventional-commit-style summary> (#$N)"
git push -u origin "$BRANCH"
```

Use `fix:`, `docs:`, `test:`, `chore:`, `refactor:` as appropriate based on the audit section.

### 5. Open the PR

```bash
gh pr create \
  --title "$(git log -1 --pretty=%s)" \
  --body "$(cat <<EOF
## Summary
Resolves #$N.

<1–3 bullets describing what changed and why>

## Test plan
- [ ] <bulleted checklist of how this was verified>

EOF
)" \
  --base main
```

Capture the PR number `P`.

### 6. Self-review loop

Do an internal review of the diff before asking for green CI. Two approaches in priority order:

1. **If the host has a code-review skill** (`code-review` / `superpowers:requesting-code-review` / `vercel:react-best-practices` / etc.): invoke it on PR `P` and capture findings.
2. **Else** apply this inline checklist to the diff:
   - Does it actually resolve the finding the issue describes?
   - Any introduced lint/type errors?
   - Any obvious test gaps for the changed code?
   - Any unrelated changes that should be reverted?
   - Any new dead code, TODOs, or commented-out blocks?
   - Are imports, exports, and public surface consistent?

Loop:

- For each non-trivial finding from the review, post a PR review comment via `gh pr comment $P --body "..."` (or inline review with `gh pr review $P --comment -b "..."`).
- Address each comment with a follow-up commit (`fix(review): ...`) and `git push`.
- Re-review until the checklist passes with no new findings.

Stop conditions for the loop (avoid infinite ping-pong):
- Two consecutive review passes produce no new findings → exit.
- More than 5 review iterations → stop, comment on the PR explaining what's still open, and move to the next issue. Do NOT merge.

### 7. Wait for green CI

```bash
gh pr checks $P --watch --fail-fast
```

If checks fail:
- Read the failing job logs (`gh run view <run-id> --log-failed` or `gh pr checks $P`).
- If the failure is caused by this PR, fix it and push. Return to step 6.
- If the failure is unrelated/flaky/infrastructure, post a comment noting the failure and move on without merging — do NOT force-merge.

If checks have not run within 10 minutes (no workflow triggered for this branch), post a comment and move on.

### 8. Merge

Only after CI is green AND the self-review loop exited cleanly:

```bash
gh pr merge $P --squash --delete-branch
```

Verify the issue closed automatically (the PR body has `Resolves #N`). If it didn't, close it manually with `gh issue close $N --reason completed`.

### 9. Cleanup and move on

```bash
git checkout main
git pull --ff-only
git branch -D "$BRANCH" 2>/dev/null || true
```

Then move to the next issue in the queue.

## Final report

When the queue is empty (or the user stops the run), summarize:

- Issues processed
- Merged successfully
- Closed without merging (reason for each)
- Left open mid-PR (link + reason)

## Safety

- NEVER force-push to `main` or any shared branch.
- NEVER merge over failing required checks. Don't pass `--admin` or `--no-verify`.
- NEVER bypass hooks (`--no-verify`, `--no-gpg-sign`).
- NEVER skip the self-review loop. Even tiny audit fixes get one review pass.
- NEVER batch multiple issues into one PR — the resolver works one-issue-per-PR by design so each fix is independently reviewable and revertible.
- Stop processing the queue and ask the user if you encounter: merge conflicts you can't auto-resolve, repeated CI failures, or an issue that needs a design decision.
