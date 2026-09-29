---
name: release
description: Use when cutting a release, bumping a project's version, pushing a version tag, publishing a GitHub release, or when a changelog's Unreleased section has accumulated entries and the user asks whether it is time to release
user_invocable: true
---

# Release

## Overview

A release is a reviewed change like any other, plus a tag. The version lives in exactly one place, the release notes are the changelog section the team wrote while shipping, and the tag is pushed only after that change is merged and CI is green. Automation publishes from the tag when the project has it; you publish by hand only when it does not.

**Project conventions override this skill.** Before anything else, read the project's own rules (`CLAUDE.md`, `CONTRIBUTING.md`, `RELEASING.md`, the release workflow under `.github/workflows/`). Where they differ from the steps below, follow them and say so.

## Usage

```
/release            # audit, then ask for the bump
/release minor      # patch | minor | major
/release 1.2.0      # exact version
```

## Step 1: Learn how this project versions itself

Find the single source of truth and the mechanism around it. Do not assume the generic layout.

| Question | Where to look |
|---|---|
| Which file holds the version? | `VERSION`, `package.json`, `pyproject.toml`, `Cargo.toml`, project docs. **If the docs name one file as the only source, edit only that file.** A `0.0.0` (or similar) sentinel in another manifest is deliberate; leave it. |
| Is there a changelog with an `Unreleased` section? | `CHANGELOG.md`. If yes, it is the release notes. |
| Does a tag trigger publishing? | A workflow with `on: push: tags:`. If yes, never run `gh release create` yourself. Read what it asserts (tag equals version, Unreleased empty, notes script). |
| Is there a release-notes script or a changelog CI check? | `scripts/`, the changelog workflow. Run them locally before opening the PR. |
| What else is versioned? | Docker image tags, docs that quote the version. Grep the old version; report matches, do not auto-edit. |

Report what you found in one short list before touching anything.

## Step 2: Choose the version, with the user

State the current version and recommend a bump with the reason. **Ask; never bump on your own, and never bump major without an explicit instruction.**

| Bump | When |
|---|---|
| **major** | The operator must act: removed or renamed setting, a migration that cannot be undone by restoring the previous backup, a newly mandatory external service, a breaking API change for a downstream consumer |
| **minor** | New user-visible capability, additive settings with working defaults, additive migrations |
| **patch** | Fixes, dependency refreshes, docs, internal work only |

Read the Unreleased entries to decide; the grouping headings usually say it already.

## Step 3: Pre-flight

All must hold, or stop and say which failed:

- Working tree clean, on the default branch, up to date with the remote.
- `gh auth status` succeeds.
- Every PR meant for this release is merged; the latest CI on the default branch is green.
- Nothing you are about to change is also being changed by an open PR.

## Step 4: The release change

On a branch, not on the default branch:

1. Set the new version in the single source-of-truth file. Nothing else, unless Step 1 found a documented second place.
2. Graduate the changelog: turn `## Unreleased` into `## X.Y.Z — YYYY-MM-DD` in the project's heading style, leave a fresh empty `## Unreleased` above it. Merge duplicate group headings that accumulated. Fix any entry that another entry in the same release has made stale ("read-only" when a later entry adds a write). Order entries so a reader who knows nothing sees the foundation before what builds on it.
3. Run the project's own checks locally: release-notes script for the new version, changelog check, docs-sync check, the usual test gate.
4. Commit as `release: cut X.Y.Z`, push, open a PR titled the same. Use the project's no-changelog escape hatch if the changelog check would otherwise demand a new Unreleased entry for the release itself.
5. Wait for CI. Merge only when every blocking check is green; do not chain "wait" and "merge" in one command.

## Step 5: Tag from the merged default branch

```bash
git checkout main && git pull --ff-only
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

If a workflow publishes from the tag, watch it finish and open the release page it created. Watch any image or package publishing workflow the tag also triggers. If nothing publishes from tags, create the release yourself with the graduated changelog section as the notes, not commit subjects.

## Step 6: Close out

- Report: old → new version, PR, tag, release URL, publishing workflow status.
- Say what the operator still has to do on running installs: rebuild or pull images, the project's update command, which services need a restart and which of those must be idle first.
- Confirm the working tree is clean and no release branch remains.

## Red flags — stop

- Editing a manifest the project says is a sentinel
- Committing the bump directly on the default branch
- Tagging before the release PR is merged, or from a branch
- Generating notes from `git log` when a changelog section exists
- Running `gh release create` when a tag workflow exists
- Bumping major because "a lot changed"; major is about what the operator must do, not volume
- "The lockfile should match the version" — only if the project says so

| Rationalization | Reality |
|---|---|
| "It's just a version bump, no PR needed" | The changelog graduation is the release notes everyone reads. It gets reviewed like code. |
| "The generic checklist is fine" | The project's checks refuse what the checklist would produce (tag ≠ version, Unreleased not empty). Read them first. |
| "I'll tag now and merge after" | The tag workflow checks out the tag, not the branch; a tag on unmerged work publishes unmerged work. |
