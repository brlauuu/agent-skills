---
name: codebase-audit
description: Use when performing a comprehensive repository audit — architecture review, docs freshness, test coverage, dead code detection, agent-context-file accuracy (CLAUDE.md / AGENTS.md), and dependency health. Invoke with /codebase-audit or run unattended overnight.
---

# Codebase Audit

Comprehensive automated audit of the repository. Dispatches 6 parallel tasks and writes dated reports to `docs/audit/<agent>/YYYY-MM-DD/`, where `<agent>` is the name of the agent running the audit (e.g. `claude`, `codex`). Reports are stored locally for review — no GitHub issues are created here. Use the sister skill `codebase-audit-issues` to digest reports into GitHub issues, and `codebase-audit-resolve` to work through the resulting issues.

## Agent identifier

Use a short lowercase identifier for the agent running the audit:

- Claude Code → `claude`
- Codex CLI → `codex`
- Other → the platform's own short name

This appears in the report path so multiple agents can audit the same repo without collisions and the reports stay attributable.

## Platform note (Claude vs Codex)

This skill assumes the host agent can dispatch parallel sub-tasks:

- **Claude Code** — use the `Agent` tool with `subagent_type: "general-purpose"`. Send all 6 dispatches in a single message so they run in parallel.
- **Codex CLI** — use parallel `apply_patch`/shell task spawning, or run the 6 prompts as concurrent shell-driven sub-tasks. If your runtime cannot parallelize, run them sequentially — output is identical, only wall-clock differs.

Wherever this document says "subagent" or "task," substitute the equivalent on your platform.

## Required Output Files

A successful run MUST produce exactly these 7 files in `docs/audit/<agent>/YYYY-MM-DD/`. Do not invent other filenames (e.g. `audit.log`), do not consolidate into a single file, do not skip any.

1. `summary.md`
2. `architecture-review.md`
3. `docs-freshness.md`
4. `test-coverage.md`
5. `dead-code.md`
6. `agent-context-accuracy.md`
7. `dependency-health.md`

## Severity Levels

| Level | Meaning |
|---|---|
| **CRITICAL** | Broken tests, README/docs claims that contradict code, missing referenced files |
| **WARNING** | Low test coverage (<60%), outdated major deps, confirmed dead files |
| **INFO** | Minor staleness, structural suggestions, coverage below ideal but above threshold |

## Finding Format

Every finding in the report MUST use this exact format:

```
- **[SEVERITY]** One-line description
  - File: path/to/file.ext:line (if applicable)
  - Evidence: what you checked and what you found
```

## Orchestrator Steps

Follow these steps exactly. Do not skip steps or reorder them.

### Step 1: Detect repo shape

Before dispatching tasks, gather facts the subtasks will need:

- Detect package managers / language ecosystems present (e.g. `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `pom.xml`).
- Detect the agent context file: `CLAUDE.md`, `AGENTS.md`, or both. If neither exists, the agent-context-accuracy task should report INFO ("no agent context file present") and skip.
- Detect the test commands (look at `package.json` scripts, `Makefile`, `pyproject.toml [tool.pytest]`, `tox.ini`, etc.).

Pass these facts to each subtask as part of its prompt so the prompts stay language-agnostic.

### Step 2: Initialize Report Directory

1. Get today's date: `date +%Y-%m-%d`. Set `AGENT` to your platform identifier (`claude`, `codex`, …).
2. `mkdir -p docs/audit/$AGENT/YYYY-MM-DD`.
3. Create `docs/audit/<agent>/YYYY-MM-DD/summary.md`:
   ```markdown
   # Codebase Audit — YYYY-MM-DD

   > Status: IN PROGRESS (0/6)

   *Report is being generated. Section files appear as checks complete.*
   ```

### Step 3: Dispatch All 6 Tasks in Parallel

Dispatch all 6 tasks simultaneously. The 6 tasks:

1. **architecture-review** — "Analyze architecture"
2. **docs-freshness** — "Check docs freshness"
3. **test-coverage** — "Run test coverage"
4. **dead-code-detection** — "Detect dead code"
5. **agent-context-accuracy** — "Verify CLAUDE.md / AGENTS.md"
6. **dependency-health** — "Check dependency health"

Each task gets its prompt from the "Task Prompts" section below, prefixed with the repo-shape facts gathered in Step 1.

### Step 4: Collect Results Incrementally

As each task completes, immediately:

1. Write its results to a dedicated file in the report directory: `docs/audit/<agent>/YYYY-MM-DD/[section-name].md` (e.g. `architecture-review.md`).
2. Update the status line in `summary.md`: `> Status: IN PROGRESS (N/6)`.

If a task fails or returns empty results, write to its section file:
```markdown
## [Section Name]

- **[INFO]** Check returned no findings or failed to execute
```

### Step 5: Write Summary

After ALL 6 tasks complete:

1. Count findings by severity across all section files (grep for `**[CRITICAL]**`, `**[WARNING]**`, `**[INFO]**`).
2. Determine overall health:
   - Any CRITICAL → "Critical"
   - Any WARNING but no CRITICAL → "Needs Attention"
   - Only INFO or no findings → "Good"
3. Update `docs/audit/<agent>/YYYY-MM-DD/summary.md`:
   ```markdown
   # Codebase Audit — YYYY-MM-DD

   > Status: COMPLETE (6/6)

   ## Summary
   - Overall health: [Good / Needs Attention / Critical]
   - Findings: N critical, M warnings, K informational
   - Test coverage: <fill from test-coverage section>

   ## Section Reports
   - [Architecture Review](architecture-review.md)
   - [Docs Freshness](docs-freshness.md)
   - [Test Coverage](test-coverage.md)
   - [Dead Code](dead-code.md)
   - [Agent Context Accuracy](agent-context-accuracy.md)
   - [Dependency Health](dependency-health.md)
   ```

### Step 6: Verify Output

Before finalizing, verify every required file exists and is non-empty:

```bash
DIR="docs/audit/$AGENT/$(date +%Y-%m-%d)"
MISSING=()
for f in summary.md architecture-review.md docs-freshness.md test-coverage.md dead-code.md agent-context-accuracy.md dependency-health.md; do
  if [ ! -s "$DIR/$f" ]; then MISSING+=("$f"); fi
done
if [ "${#MISSING[@]}" -ne 0 ]; then
  echo "AUDIT INCOMPLETE — missing or empty: ${MISSING[*]}"
  exit 1
fi
```

If the check fails: identify which task(s) produced the missing section(s), re-dispatch only those, write their results, re-run verification. Do not proceed until it passes.

Do NOT substitute a combined log file for the 7 required files. Do NOT mark the audit complete while any file is missing or empty.

### Step 7: Finalize

1. Do NOT create GitHub issues here — that's the job of the sister skill `codebase-audit-issues`. Suggest running it next if there are CRITICAL/WARNING findings.
2. Do NOT commit or push — leave files as unstaged local changes.
3. Tell the user the report is ready at `docs/audit/<agent>/YYYY-MM-DD/` and list:
   - Finding counts by severity
   - The 7 files that were written (confirm Step 6 passed)

---

## Task Prompts

Each prompt below is generic. Prefix it with the repo-shape facts from Step 1 (languages, package managers, test commands, agent context file path) so the task can adapt to the project.

### Task 1: Architecture Review

**Description:** "Analyze architecture"

**Prompt:**

```
You are auditing this repository's architecture. Identify structural issues. Report findings in this exact format:

- **[SEVERITY]** One-line description
  - File: path/to/file.ext:line
  - Evidence: what you checked and what you found

SEVERITY is one of: CRITICAL, WARNING, INFO

## Checks

### 1. File structure vs agent context file
If CLAUDE.md or AGENTS.md exists and contains a "Repo Structure" tree (or equivalent), verify every path listed in that tree exists on disk. Report missing paths as CRITICAL.

### 2. Orphan files (no inbound imports)
For each source file in the project's main source directories (skip tests, generated code, framework entry points like `page.tsx`, `__init__.py`, `main.*`), grep the codebase for imports of that module. Report files with zero inbound imports as INFO (they may be dynamically loaded or entry points the heuristic missed).

### 3. Large files
Use `wc -l` on all source files. Flag any over 500 lines as INFO with the line count.

### 4. Circular dependencies
For each import found in step 2, check if the imported module also imports the importer. Report any circular pairs as WARNING.

Return ONLY the findings. If no findings, return "No architecture issues found."
```

### Task 2: Docs Freshness

**Description:** "Check docs freshness"

**Prompt:**

```
You are auditing this repository's documentation for staleness. Report findings in this exact format:

- **[SEVERITY]** One-line description
  - File: path/to/file.ext:line
  - Evidence: what the doc claims vs what's actually true

SEVERITY is one of: CRITICAL, WARNING, INFO

## Checks

### 1. README feature claims
Read README.md. For each feature listed in the "Features" section (or equivalent), spot-check that the feature has corresponding code, routes, or commands. Report features claimed but not implemented as CRITICAL.

### 2. README badges and version claims
Read badge lines and any "Requirements" / "Tech Stack" section in README. Compare claimed versions (language, framework, database) against actual config files (`package.json`, `pyproject.toml`, `Dockerfile`, `docker-compose.yml`, `go.mod`, etc.). Report mismatches as WARNING.

### 3. Guide / docs files
For each markdown file in `docs/`, `guide/`, or `documentation/`:
- Extract any route, component, file, command, or endpoint reference
- Verify each reference exists in the codebase
Report missing references as WARNING.

### 4. Status / roadmap docs
Read any file describing project status (e.g. `STATUS.md`, `ROADMAP.md`, `TODO.md`, or "Current State" sections). Spot-check items marked "done" — verify the code exists. Spot-check items marked "not yet done" — flag any that have actually been completed. Report stale status as INFO.

### 5. Other docs
Check files like `docs/development.md`, `docs/configuration.md`, `CONTRIBUTING.md` for references to files, commands, or structures that no longer exist. Report stale references as WARNING.

Return ONLY the findings. If no findings, return "No docs freshness issues found."
```

### Task 3: Test Coverage

**Description:** "Run test coverage"

**Prompt:**

```
You are auditing this repository's test coverage. You must RUN the actual test suites and parse the output. Report findings in this exact format:

- **[SEVERITY]** One-line description
  - File: path/to/file.ext
  - Evidence: coverage % or error message

SEVERITY is one of: CRITICAL, WARNING, INFO

## Checks

### 1. Run each test suite the project defines
Detect the test commands by reading `package.json` scripts, `Makefile`, `pyproject.toml`, `tox.ini`, `Cargo.toml`, etc. Run each suite with coverage enabled when supported (e.g. `pytest --cov`, `jest --coverage`, `go test -cover`, `cargo tarpaulin`).

If a command fails (missing deps, import errors), report as:
- **[CRITICAL]** <suite name> test suite failed to execute
  - Evidence: <first 5 lines of error output>

Then continue to the next suite — do not abort.

### 2. Parse coverage
For each suite, extract:
- Overall coverage percentage
- Per-file coverage percentages
- Files with 0% coverage
- Uncovered line ranges for files below 60%

### 3. Classify findings
- Overall coverage <60% → CRITICAL
- Overall coverage 60–80% → WARNING
- Individual files with 0% coverage → WARNING
- Individual files 60–80% → INFO
- ≥80% → no finding

### 4. Format output
Begin with a summary table:

| Component | Coverage | Status |
|-----------|----------|--------|
| <suite>   | XX%      | <severity> |

Then list individual file findings.

Return ONLY the table and findings.
```

### Task 4: Dead Code Detection

**Description:** "Detect dead code"

**Prompt:**

```
You are auditing this repository for dead code — files and exports that nothing references. Report findings in this exact format:

- **[SEVERITY]** One-line description
  - File: path/to/file.ext
  - Evidence: what you searched for and the result

SEVERITY is one of: CRITICAL, WARNING, INFO

## Checks

### 1. Dead source files
List all source files in the main source directories. Skip framework entry points and special files:
- Test files (`*test*`, `*spec*`, `tests/`, `__tests__/`)
- Build/config (`webpack.config.*`, `vite.config.*`, `next.config.*`, `tailwind.config.*`)
- Framework conventions (Next.js: `page.tsx`, `layout.tsx`, `route.ts`, `loading.tsx`, `error.tsx`, `not-found.tsx`; Python: `__init__.py`, `main.py`, `conftest.py`; Rails-like: anything auto-loaded)
- Generated code (`alembic/versions/`, `migrations/`, `*.pb.go`)

For remaining files, grep the codebase for imports of that module/file. If zero references found, report as WARNING (confirmed dead file).

### 2. Orphaned tests
List all test files. For each, infer the file under test from its name (e.g. `test_foo.py` → `foo.py`, `Foo.test.tsx` → `Foo.tsx`). If the file under test no longer exists, report as WARNING.

### 3. Unused exports (typed languages)
For TypeScript/Java/etc. exported symbols in shared library directories (`lib/`, `utils/`, `pkg/`), grep the rest of the source tree for usage. Report unused exports as INFO.

Return ONLY the findings. If no findings, return "No dead code detected."
```

### Task 5: Agent Context Accuracy

**Description:** "Verify CLAUDE.md / AGENTS.md"

**Prompt:**

```
You are auditing the agent context file (CLAUDE.md, AGENTS.md, or both — whichever exists) to verify it accurately describes the current state of the repository. Report findings in this exact format:

- **[SEVERITY]** One-line description
  - File: <context-file>:line (and the file it references, if any)
  - Evidence: what the context file claims vs what's actually true

SEVERITY is one of: CRITICAL, WARNING, INFO

If neither CLAUDE.md nor AGENTS.md exists, return: "No agent context file present — skipping."

## Checks

### 1. Repo Structure tree
If the context file contains a repo-structure tree, verify every path exists. Report missing paths as CRITICAL. Report paths that exist but contain different content than described as WARNING.

### 2. Tech Stack table
For each row in any "Tech Stack" / "Stack" / "Requirements" table, verify the version matches the actual config (`package.json`, `pyproject.toml`, `Dockerfile`, `docker-compose.yml`, `go.mod`, etc.). Report mismatches as WARNING.

### 3. "Done" / "Not yet done" sections
Spot-check 3–5 items on each list. Report items marked done that aren't actually done as CRITICAL. Report items marked not-yet-done that are in fact done as WARNING (file is stale).

### 4. Conventions
Spot-check claimed conventions (linter, formatter, path aliases, strict mode) against actual config files. Report mismatches as WARNING.

### 5. How to Run
Verify each command, make target, port, or service name listed under "How to Run" / "Getting Started" exists in `Makefile`, `package.json` scripts, `docker-compose.yml`, etc. Report mismatches as WARNING.

Return ONLY the findings. If no findings, return "Agent context file is accurate."
```

### Task 6: Dependency Health

**Description:** "Check dependency health"

**Prompt:**

```
You are auditing this repository's dependency health. Report findings in this exact format:

- **[SEVERITY]** One-line description
  - File: path/to/file.ext
  - Evidence: current version vs latest, or import details

SEVERITY is one of: CRITICAL, WARNING, INFO

## Checks (run the ones that apply to the detected ecosystems)

### 1. Outdated packages
- npm/pnpm/yarn: `npm outdated --json` (or `pnpm outdated --format json`).
- Python: `pip list --outdated --format json`, or `poetry show --outdated`.
- Rust: `cargo outdated`.
- Go: `go list -u -m all`.

For each outdated package:
- Major version bump → WARNING
- Minor/patch only → INFO
- If the command fails, report INFO and continue.

### 2. Lock files present and consistent
- `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` for Node
- `poetry.lock` / `uv.lock` / `Pipfile.lock` for Python
- `Cargo.lock` for Rust apps (libraries optionally)
- `go.sum` for Go
Report missing lock files for application repos as WARNING.

### 3. Unused dependencies
For each declared dependency, grep the source tree for imports of that package. Skip type-only packages (`@types/*`), build tools loaded via config (`postcss`, `autoprefixer`, `tailwindcss`, etc.), and stdlib-shadowing packages. Apply known import-name mappings (e.g. `psycopg2-binary` → `psycopg2`). Report packages with zero references as WARNING.

### 4. Missing dependencies
For each non-relative, non-stdlib import in the source tree, verify the package is declared. Report missing dependencies as CRITICAL.

Return ONLY the findings. If no findings, return "All dependencies are healthy."
```
