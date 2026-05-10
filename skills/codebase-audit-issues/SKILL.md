---
name: codebase-audit-issues
description: Use to digest codebase audit reports into GitHub issues. Reads the audit files written by the `codebase-audit` skill at `docs/audit/<agent>/YYYY-MM-DD/`, creates one GitHub issue per actionable finding (tagged `codebase-audit` plus section/severity tags), and deletes the consumed audit files. Sister skill to `codebase-audit` and `codebase-audit-resolve`.
---

# Codebase Audit → Issues

Turn a finished audit into trackable GitHub issues, then clean up the local audit files.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`).
- Repository has a GitHub remote configured (`git remote -v` shows `origin`).
- An audit report exists under `docs/audit/<agent>/<date>/` (produced by the `codebase-audit` skill).

If any prerequisite fails, stop and tell the user.

## Inputs

The skill operates on one report directory at a time. Selection rules:

1. If the user passed a path/date/agent argument, use that directly.
2. Otherwise, default to the most recent date directory found across all `<agent>` subdirectories under `docs/audit/`. If multiple agents have a report on the same most-recent date, ask the user which one to process.

```bash
# Find the most recent report
find docs/audit -mindepth 2 -maxdepth 2 -type d | sort -t/ -k4 -r | head -5
```

## Required Tags

Every issue created MUST carry these labels:

- `codebase-audit` — base label that the resolver skill keys off of (REQUIRED — create with `gh label create codebase-audit --color cccccc --description "Created by codebase-audit"` if missing)
- One **section** label, derived from the source file:
  - `architecture-review.md` → `audit:architecture`
  - `docs-freshness.md` → `audit:docs`
  - `test-coverage.md` → `audit:tests`
  - `dead-code.md` → `audit:dead-code`
  - `agent-context-accuracy.md` → `audit:agent-context`
  - `dependency-health.md` → `audit:deps`
- One **severity** label: `severity:critical`, `severity:warning`, or `severity:info`.

Plus optional context labels the agent may add when obviously applicable: `bug`, `documentation`, `dependencies`, `tech-debt`, `breaking-change`. Don't invent novel labels — only attach those already present in the repo (`gh label list --limit 200`) or the standard set above.

Before creating the first issue, ensure all required labels exist:

```bash
ensure_label() {
  local name="$1" color="$2" desc="$3"
  gh label list --limit 200 --json name --jq '.[].name' | grep -qx "$name" \
    || gh label create "$name" --color "$color" --description "$desc"
}
ensure_label codebase-audit cccccc "Created by codebase-audit"
ensure_label audit:architecture 0e8a16 "Architecture finding"
ensure_label audit:docs 0e8a16 "Docs finding"
ensure_label audit:tests 0e8a16 "Test coverage finding"
ensure_label audit:dead-code 0e8a16 "Dead code finding"
ensure_label audit:agent-context 0e8a16 "CLAUDE.md / AGENTS.md finding"
ensure_label audit:deps 0e8a16 "Dependency finding"
ensure_label severity:critical b60205 "Critical severity"
ensure_label severity:warning fbca04 "Warning severity"
ensure_label severity:info 0075ca "Informational severity"
```

## Issue Granularity

- **CRITICAL** finding → its own issue.
- **WARNING** finding → its own issue.
- **INFO** findings → consolidate per source file into a single tracking issue (e.g. `[audit] docs freshness — 7 informational findings`). Body lists each finding as a checklist item.

`summary.md` is metadata; do not turn it into an issue. Skip it.

## Steps

### Step 1: Pick the report

Determine `REPORT_DIR` (e.g. `docs/audit/claude/2026-05-10/`). Verify all 7 required files exist; if any are missing, tell the user the audit is incomplete and stop.

### Step 2: Detect already-filed findings (idempotency)

Re-running on the same report should NOT duplicate issues. Fingerprint each finding deterministically:

```
<section>::<severity>::<first-line-of-description>::<file-or-empty>
```

Before creating an issue, search existing `codebase-audit` issues for the fingerprint inside the body (we'll embed it as a hidden HTML comment):

```bash
gh issue list --label codebase-audit --state all --limit 1000 --json number,body \
  --jq '.[] | select(.body | contains("<!-- audit-fingerprint: '"$FP"' -->")) | .number'
```

If a match exists, skip creation for that finding. Track skip count and report it at the end.

### Step 3: Create issues

For each finding (or each consolidated INFO group):

1. Build the title:
   - CRITICAL/WARNING: `[audit] <section>: <one-line description>` (truncate to 80 chars)
   - INFO group: `[audit] <section>: N informational findings`
2. Build the body:

   ```markdown
   <!-- audit-fingerprint: <fingerprint> -->

   **Source:** `<REPORT_DIR>/<section-file>`
   **Severity:** <SEVERITY>
   **Detected by:** <agent> on <date>

   ## Finding

   <verbatim finding block from the report>

   ## Suggested resolution

   <agent's 1–3 sentence take on what should be done — keep it short and actionable; if unclear, write "needs investigation">
   ```

   For INFO groups, replace "Finding" with a checklist of all consolidated findings.
3. Create:
   ```bash
   gh issue create \
     --title "$TITLE" \
     --label codebase-audit,$SECTION_LABEL,$SEVERITY_LABEL$EXTRA_LABELS \
     --body "$BODY"
   ```
4. Record the resulting issue number.

### Step 4: Write a manifest

After all issues are created, write `<REPORT_DIR>/issues.md` listing each finding → issue number (or "skipped: duplicate of #N"). This is the audit trail — keep it brief:

```markdown
# Issues filed for <REPORT_DIR>

- #123 — [audit] docs: README claims feature X (CRITICAL)
- #124 — [audit] tests: pipeline coverage 42% (CRITICAL)
- skipped — architecture: orphan file utils/foo.py (already #98)
- ...
```

### Step 5: Delete the report directory

Only after Step 4 completes successfully:

```bash
rm -rf "$REPORT_DIR"
```

If the parent `docs/audit/<agent>/` directory is now empty, leave it (cheap to keep, helps the next audit).

### Step 6: Report back

Tell the user:
- Total issues created (with link to the filtered list: `gh issue list --label codebase-audit --state open --web`)
- Counts per severity
- Number of duplicates skipped
- That the report directory was deleted
- Suggest running `codebase-audit-resolve` to start working through the new issues

## Safety

- NEVER create issues without the `codebase-audit` label — the resolver skill depends on it.
- NEVER delete the report directory if any issue creation failed; leave files in place for re-run.
- NEVER commit `issues.md` or any audit files to git — they are local-only artifacts. Confirm `docs/audit/` is in `.gitignore` (or all of `docs/audit/**/*.md` is); add it if missing.
