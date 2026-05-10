---
name: repo-cleanup
description: Use when finishing a batch of work, before ending a session, or when the user asks to clean up the repo — checks for stale branches, uncommitted files, lingering worktrees, and Docker disk waste
---

# Repo Cleanup

Systematic check for stale git state and Docker build waste. Run all checks, report findings, and act on user decisions.

## Checks

Run all checks in parallel where possible, then present findings grouped by category.

### 1. Git: Uncommitted & Untracked Files

```bash
git status
```

**If clean:** Report "Working tree clean" and move on.

**If dirty:** Present each group separately:
- **Modified (staged):** List files, ask "Commit these?"
- **Modified (unstaged):** List files, ask "Stage and commit, or discard?"
- **Untracked:** List files, ask "Commit, add to .gitignore, or delete?"

Wait for user decision before acting. Never auto-commit or auto-delete.

### 2. Git: Stale Branches

```bash
# Local branches (exclude current)
git branch --format='%(refname:short) %(upstream:track)' | grep -v "^\*"

# Remote branches (exclude HEAD and main/master)
git branch -r --format='%(refname:short)' | grep -v 'HEAD\|/main$\|/master$'

# Worktrees
git worktree list
```

**For each local branch that isn't main/master:**
- Check if it's been merged: `git branch --merged main | grep <branch>`
- Check remote tracking status (gone, ahead, behind)
- Report: branch name, merged status, last commit date

**For remote branches** not matching any local branch and not main/master:
- Report as potentially stale

**For worktrees** beyond the main one:
- Report path and branch

Present all findings, then ask: "Delete stale branches? (I'll list which ones)"

If user confirms, delete merged local branches and their remotes. For worktrees, remove with `git worktree remove` before deleting the branch.

### 3. Docker: Disk Usage

```bash
docker system df
```

Present the table to the user, then check each category:

**Stopped containers:**
```bash
docker ps -a --filter status=exited --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}"
```

**Dangling images** (untagged, leftover from builds):
```bash
docker images -f dangling=true --format "table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
```

**Build cache:**
```bash
docker builder du --verbose 2>/dev/null | tail -5
```

**If waste found:** Summarize total reclaimable space across all categories, then ask:

> "Found X stopped containers, Y dangling images, Z build cache. Run `docker system prune` to reclaim ~N GB? (This removes stopped containers, dangling images, unused networks, and build cache. Running containers and tagged images are safe.)"

If user confirms:
```bash
docker system prune -f
```

Report space reclaimed from the output.

**If no waste:** Report "Docker is clean, nothing to prune."

## Output Format

```
## Repo Cleanup Report

### Git
- Working tree: [clean / N modified, M untracked]
- Branches: [N stale local, M stale remote]
- Worktrees: [clean / N lingering]

### Docker
- Disk usage: images X GB, containers Y GB, build cache Z GB
- Reclaimable: ~N GB (K stopped containers, J dangling images)

### Actions Needed
- [List of decisions needed from user]
```
