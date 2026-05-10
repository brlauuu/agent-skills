---
name: release
description: Use when creating a new software release, bumping the project version, publishing a new version tag, or generating a GitHub release
user_invocable: true
---

# Release

Create a new project release: detect version, bump it, update all version files, commit, tag, and publish a GitHub release with auto-generated notes.

## Usage

```
/release           # interactive: shows current version, asks for bump type
/release patch     # 0.1.0 → 0.1.1  (bug fixes only)
/release minor     # 0.1.0 → 0.2.0  (new features, backward-compatible)
/release major     # 0.1.0 → 1.0.0  (breaking changes)
/release 1.0.0     # set exact version
```

---

## Step 1: Audit versioning setup

Scan the repo root for version files in this priority order:

| File | How version is stored |
|------|----------------------|
| `VERSION` | Entire file content (plain version string) |
| `package.json` | `"version"` JSON field |
| `pyproject.toml` | `version = "..."` under `[tool.poetry]` or `[project]` |
| `Cargo.toml` | `version = "..."` under `[package]` |
| `setup.py` | `version=` argument |

Read every file that exists and record which ones contain the version. Display the current version and the full list of files that will be updated.

**If no version files are found:** Stop. Tell the user the project has no versioning setup and recommend adding a root `VERSION` file as the single source of truth:
```
echo "0.1.0" > VERSION
```
Explain that a flat `VERSION` file is the simplest approach for multi-language projects. Do not proceed with the release until versioning is in place.

---

## Step 2: Determine new version

If no argument was given, display:
```
Current version: X.Y.Z
Bump type? [patch] bug fixes  [minor] new features  [major] breaking changes
```

Wait for user input before proceeding.

Compute the new version by incrementing the appropriate semver component. When bumping minor, reset patch to 0. When bumping major, reset minor and patch to 0. Validate the new version is strictly greater than the current one.

---

## Step 3: Pre-flight checks

Run these and evaluate results:

```bash
git status --porcelain      # must be empty — dirty tree blocks release
git branch --show-current   # warn if not main/master, but don't block
gh auth status              # must succeed — no gh auth blocks release
```

- **Dirty working tree** → stop. Tell user to commit or stash changes first.
- **Not on main/master** → warn only. Ask user to confirm before continuing.
- **gh not authenticated** → stop. Tell user to run `gh auth login`.

---

## Step 4: Update version in all detected files

For each file found in Step 1:

| File | Update method |
|------|---------------|
| `VERSION` | Overwrite with `{NEW_VERSION}\n` |
| `package.json` | Edit the `"version"` field in-place |
| `pyproject.toml` | Replace `version = "OLD"` with `version = "NEW"` |
| `Cargo.toml` | Replace `version = "OLD"` under `[package]` only |
| `setup.py` | Replace `version="OLD"` argument |

After updating `package.json`, sync the lockfile:
```bash
cd <package.json directory> && npm install --package-lock-only
```

Also grep broadly for the old version string in common doc/config locations (README, Dockerfile, docker-compose.yml). Report any matches found and ask user if they should be updated — do not auto-update these.

---

## Step 5: Commit and tag

Stage only the version files that were updated:

```bash
git add VERSION package.json pyproject.toml Cargo.toml setup.py  # only those that exist
# Also add package-lock.json if package.json was updated
git commit -m "release: v{NEW_VERSION}"
git tag -a "v{NEW_VERSION}" -m "Release v{NEW_VERSION}"
```

---

## Step 6: Generate release notes

Get commits since the previous tag (or all commits if this is the first release):

```bash
LAST_TAG=$(git describe --tags --abbrev=0 HEAD~1 2>/dev/null || echo "")
if [ -n "$LAST_TAG" ]; then
  git log "$LAST_TAG"..HEAD --oneline --no-decorate
else
  git log HEAD --oneline --no-decorate
fi
```

Group by conventional commit prefix and format as markdown:

```
## Features
- feat(scope): description (#PR)

## Bug Fixes
- fix: description

## Performance
- perf: description

## Documentation
- docs: description

## Maintenance
- chore / refactor / test / other commits
```

Skip empty sections. Strip redundant merge commit lines (`Merge pull request #N`). Include PR numbers when present in commit subjects.

---

## Step 7: Push and publish

```bash
git push origin HEAD --tags
```

Then create the GitHub release:

```bash
gh release create "v{NEW_VERSION}" \
  --title "v{NEW_VERSION}" \
  --notes "$(cat <<'NOTES'
{GENERATED_RELEASE_NOTES}
NOTES
)"
```

---

## Step 8: Confirm

Report a concise summary:
- `{OLD_VERSION}` → `{NEW_VERSION}`
- Files updated: (list)
- Tag: `v{NEW_VERSION}`
- GitHub release: (URL from gh output)

If the project uses Docker and has a `make build` target, remind the user to rebuild images to bake in the new version.
