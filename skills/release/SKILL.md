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
/release            # audit, classify; cut patch or minor, ask before major
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

## Step 2: Choose the version

Classify everything merged since the last version tag, not only the latest change. Read the diff and the Unreleased entries; where they disagree, the diff decides. The highest level among the unreleased changes is the level of the release. If a change sits between two levels, take the higher one.

| Bump | When |
|---|---|
| **major** | Whoever runs or consumes the project must act: removed or renamed setting, flag or command, a migration that cannot be undone by restoring the previous backup, a newly mandatory external service, a breaking API change for a downstream consumer |
| **minor** | New user-visible capability, additive settings with working defaults, additive migrations |
| **patch** | Fixes, dependency refreshes, docs, internal work only |

State the current version, the new version, the level and the reason. Then:

| Classified level | Level was given (`/release minor`, a calling workflow) | What to do |
|---|---|---|
| patch or minor | none, or the same | Proceed with the classified level, without asking |
| patch or minor | higher (`minor` given, change is patch) | Proceed with the given level, without asking |
| patch or minor | lower (`patch` given, change is minor) | Proceed with the classified level and say why |
| **major** | anything other than `major` or an exact major version from the user | **Do not bump. Ask the user.** |
| **major** | `major` or an exact major version, from the user | Proceed |

A level counts as "from the user" when the user typed it, or when a calling workflow relays the user's answer to the major-bump question below. A level a workflow chose by its own classification does not.

**Asking about a major bump:** say what breaks and for whom, what the operator or consumer must do, and offer three options: bump major now, bump minor instead, or hold. Only the user's answer to this question counts. An earlier general go-ahead ("just get it done", "release everything") is not approval for a major version. Whatever the user answers is then the level of the release.

If nobody is there to answer, cut no release at all, at any level. Leave the proposal where the user will find it: a comment on the PR that merged the breaking change, and the final report.

On a `0.x` project a breaking change is still this decision: ask, and propose what the project's convention says. If it has none, propose `0.(Y+1).0` and name `1.0.0` as the alternative.

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
- Cutting a major version on a general go-ahead, or because a level was passed in by a workflow rather than chosen by the user
- Cutting a patch or minor while a breaking change is merged and unreleased, when the user has not chosen that in answer to the major-bump question
- "The lockfile should match the version" — only if the project says so

| Rationalization | Reality |
|---|---|
| "It's just a version bump, no PR needed" | The changelog graduation is the release notes everyone reads. It gets reviewed like code. |
| "The generic checklist is fine" | The project's checks refuse what the checklist would produce (tag ≠ version, Unreleased not empty). Read them first. |
| "I'll tag now and merge after" | The tag workflow checks out the tag, not the branch; a tag on unmerged work publishes unmerged work. |
