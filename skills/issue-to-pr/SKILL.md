---
name: issue-to-pr
description: End-to-end GitHub workflow that takes an issue through implementation to merged PR. Use this skill when the user mentions working on a GitHub issue, wants to implement an issue, says "pick up issue #X", "work on issue", "implement this issue", or wants a complete issue-to-PR workflow. Also triggers for requests involving PR creation from issues, automated code review, or branch cleanup after merge.
---

# Issue to PR Workflow

A complete workflow for taking a GitHub issue from assessment through implementation, testing, PR creation, review, and merge — with automatic branch cleanup.

## Prerequisites

- Git repository with GitHub remote configured
- GitHub CLI (`gh`) installed and authenticated
- Write access to the repository

Verify setup before starting:
```bash
gh auth status
git remote -v
```

---

## Workflow Phases

### Phase 1: Issue Assessment

**Goal:** Understand exactly what the issue asks for before writing any code.

1. **Fetch the issue**
   ```bash
   gh issue view <issue-number> --json title,body,labels,assignees,milestone
   ```

2. **Analyze the issue content**
   - What is the problem or feature request?
   - What are the acceptance criteria (explicit or implied)?
   - Are there linked issues, PRs, or discussions?
   - What components/files are likely affected?

3. **Check for additional context**
   ```bash
   # Look for related issues or PRs
   gh issue list --search "related keywords"
   gh pr list --search "related keywords"
   ```

4. **Present assessment to user**
   Summarize:
   - Problem statement (1-2 sentences)
   - Scope of work
   - Affected areas of codebase
   - Any ambiguities or questions

**Decision point:** Get user confirmation before proceeding to planning.

---

### Phase 2: Implementation Planning

**Goal:** Create a concrete, reviewable plan before touching code.

1. **Explore the codebase**
   - Identify files that need changes
   - Understand existing patterns and conventions
   - Find related code that might be affected

2. **Draft implementation plan**
   Structure the plan as:
   ```
   ## Implementation Plan for Issue #<number>
   
   ### Changes Required
   1. [File/component]: [What changes and why]
   2. [File/component]: [What changes and why]
   ...
   
   ### Testing Strategy
   - Existing tests to verify: [list]
   - New tests needed: [list with descriptions]
   
   ### Risks & Considerations
   - [Any breaking changes, edge cases, or concerns]
   ```

3. **Present plan to user**
   Walk through each change and the reasoning.

**Decision point:** Get user approval of the plan before implementation.

---

### Phase 3: Branch Setup

**Goal:** Create a clean branch for the work.

1. **Ensure main branch is up to date**
   ```bash
   git fetch origin
   git checkout main
   git pull origin main
   ```

2. **Create feature branch**
   Use a descriptive branch name tied to the issue:
   ```bash
   git checkout -b <issue-number>-<short-description>
   # Example: git checkout -b 42-add-user-auth
   ```

---

### Phase 4: Implementation

**Goal:** Implement the changes according to the approved plan.

1. **Make changes incrementally**
   - Follow the plan step by step
   - Commit logical units of work
   - Use clear commit messages referencing the issue:
     ```
     feat: add authentication middleware (#42)
     
     - Implement JWT token validation
     - Add auth middleware to protected routes
     ```

2. **Keep the user informed**
   After each significant change, briefly explain what was done.

---

### Phase 5: Testing

**Goal:** Ensure changes work correctly and don't break existing functionality.

1. **Run existing tests**
   ```bash
   # Detect and run the project's test suite
   # Common patterns:
   npm test          # Node.js
   pytest            # Python
   go test ./...     # Go
   cargo test        # Rust
   ./gradlew test    # Java/Kotlin
   ```

2. **Analyze test coverage for changes**
   - Which existing tests cover the modified code?
   - What scenarios are NOT covered?

3. **Write new tests** for:
   - New functionality (happy path)
   - Edge cases and error conditions
   - Integration points with existing code

4. **Run full test suite**
   Ensure all tests pass before proceeding.

5. **Report test results to user**
   ```
   ## Test Results
   - Existing tests: X passed, Y failed
   - New tests added: Z
   - Coverage of new code: [summary]
   ```

**Decision point:** If tests fail, discuss with user before proceeding.

---

### Phase 6: PR Creation

**Goal:** Create a well-documented pull request.

1. **Push the branch**
   ```bash
   git push -u origin <branch-name>
   ```

2. **Create the PR**
   ```bash
   gh pr create \
     --title "<type>: <description> (#<issue-number>)" \
     --body "$(cat <<'EOF'
   ## Summary
   [Brief description of changes]
   
   ## Changes
   - [Change 1]
   - [Change 2]
   
   ## Testing
   - [How the changes were tested]
   - [New tests added]
   
   ## Checklist
   - [ ] Tests pass
   - [ ] Code follows project conventions
   - [ ] Documentation updated (if needed)
   
   Closes #<issue-number>
   EOF
   )"
   ```

3. **Link to the issue**
   The "Closes #X" in the PR body automatically links and will close the issue on merge.

---

### Phase 7: PR Review

**Goal:** Review the PR for quality before merging.

1. **Fetch PR diff**
   ```bash
   gh pr diff <pr-number>
   ```

2. **Review checklist**
   Evaluate the changes against:
   - [ ] **Correctness:** Does it solve the issue as specified?
   - [ ] **Code quality:** Clean, readable, follows conventions?
   - [ ] **Tests:** Adequate coverage? Tests are meaningful?
   - [ ] **Edge cases:** Are error conditions handled?
   - [ ] **Performance:** Any obvious inefficiencies?
   - [ ] **Security:** Any potential vulnerabilities?
   - [ ] **Documentation:** Comments where needed? README updates?

3. **Check CI status** (if applicable)
   ```bash
   gh pr checks <pr-number>
   ```

4. **Present review to user**
   ```
   ## PR Review: #<pr-number>
   
   ### Verdict: [APPROVE / REQUEST CHANGES]
   
   ### Findings
   - [Finding 1]
   - [Finding 2]
   
   ### Recommendations
   - [Any suggested improvements]
   ```

**Decision point:** Get user approval before merging.

---

### Phase 8: Merge and Cleanup

**Goal:** Merge the PR and clean up branches.

1. **Merge the PR**
   ```bash
   # Squash merge keeps history clean
   gh pr merge <pr-number> --squash --delete-branch
   ```
   
   The `--delete-branch` flag deletes the remote branch automatically.

2. **Clean up local branch**
   ```bash
   # Switch back to main
   git checkout main
   
   # Pull the merged changes
   git pull origin main
   
   # Delete the local feature branch
   git branch -d <branch-name>
   ```

3. **Verify cleanup**
   ```bash
   # Confirm remote branch is gone
   git fetch --prune
   git branch -r | grep <branch-name>  # Should return nothing
   
   # Confirm local branch is gone
   git branch | grep <branch-name>  # Should return nothing
   ```

4. **Confirm merge completion**
   ```
   ## Merge Complete ✓
   
   - Issue #<number>: Closed
   - PR #<pr-number>: Merged
   - Branch '<branch-name>': Deleted (local + remote)
   ```

5. **Proceed to Docker phase** if applicable (see Phase 9).

---

### Phase 9: Docker Rebuild & Restart (Conditional)

**Goal:** Rebuild affected Docker images and restart containers if needed.

This phase runs only if:
- The changes affected code that is part of a Docker image
- That Docker image exists locally

1. **Check if changes affect a Docker image**
   ```bash
   # Look for Dockerfile in the repo
   find . -name "Dockerfile*" -o -name "docker-compose*.yml" 2>/dev/null
   
   # Check if changed files are part of a Docker build context
   # Compare changed files against Dockerfile COPY/ADD instructions
   ```

2. **Check if the image exists locally**
   ```bash
   # List local images matching the project
   docker images | grep <project-name>
   
   # Or check docker-compose images
   docker-compose images
   ```

   If no local image exists, skip this phase entirely.

3. **Rebuild the image**
   ```bash
   # Single Dockerfile
   docker build -t <image-name>:<tag> .
   
   # Or with docker-compose
   docker-compose build <service-name>
   ```

4. **Check if container is running**
   ```bash
   # Check running containers
   docker ps --filter "ancestor=<image-name>" --format "{{.ID}} {{.Names}} {{.Status}}"
   
   # Or with docker-compose
   docker-compose ps
   ```

   If no container is running, the phase is complete after rebuild.

5. **Assess container type before restarting**
   
   Determine what kind of workload the container runs:
   
   | Container Type | Interruptible? | Ask User? |
   |----------------|----------------|-----------|
   | UI/Frontend (nginx, React dev server, static files) | Yes | No |
   | API Gateway / Web Server | Mostly yes (stateless requests) | No |
   | Backend API (stateless) | Yes | No |
   | Worker / Job Processor | **No** — may have jobs in progress | **Yes** |
   | Queue Consumer | **No** — may lose unacked messages | **Yes** |
   | Batch Processor | **No** — may corrupt partial results | **Yes** |
   | Database | **No** — may corrupt data | **Yes** |
   | Scheduler / Cron | **No** — may skip scheduled tasks | **Yes** |
   | Stream Processor | **No** — may lose in-flight data | **Yes** |
   
   **How to assess:**
   - Check the image name and container name for hints (`worker`, `processor`, `consumer`, `scheduler`, `db`, etc.)
   - Look at the Dockerfile CMD/ENTRYPOINT
   - Check docker-compose service definitions
   - Look for queue connections (Redis, RabbitMQ, Kafka, SQS)
   - Check if there's a health check or graceful shutdown handler

6. **For interruptible containers (UI, stateless API):**
   Restart without asking:
   ```bash
   # Stop and start with new image
   docker-compose up -d <service-name>
   
   # Or manually
   docker stop <container-id>
   docker run -d [same options as before] <new-image>
   ```

7. **For non-interruptible containers (workers, processors, queues):**
   
   First, gather information about running processes:
   ```bash
   # Check what's happening inside the container
   docker exec <container-id> ps aux
   
   # Check for active connections (if applicable)
   docker exec <container-id> netstat -an | grep ESTABLISHED
   
   # Check container logs for active work
   docker logs --tail 50 <container-id>
   ```
   
   **Present to user:**
   ```
   ## Container Restart Required
   
   Container: <name> (<image>)
   Type: Worker/Processor (may have in-flight work)
   
   ### Current State
   - Running processes: [list]
   - Active connections: [count]
   - Recent activity: [summary from logs]
   
   ### Risk Assessment
   - [What might be interrupted]
   - [Potential data loss or duplicate processing]
   
   ### Options
   1. **Restart now** — Accept potential interruption
   2. **Wait for idle** — Monitor until no active work, then restart
   3. **Graceful shutdown** — Send SIGTERM and wait for completion
   4. **Skip restart** — Leave old container running (manual restart later)
   
   Which option do you prefer?
   ```

   **Decision point:** Wait for user choice before proceeding.

8. **Execute user's choice**
   
   - **Option 1 (Restart now):**
     ```bash
     docker-compose up -d <service-name>
     ```
   
   - **Option 2 (Wait for idle):**
     ```bash
     # Poll until idle (implementation depends on workload)
     # Then restart
     docker-compose up -d <service-name>
     ```
   
   - **Option 3 (Graceful shutdown):**
     ```bash
     # Send SIGTERM and wait
     docker-compose stop -t 60 <service-name>
     docker-compose up -d <service-name>
     ```
   
   - **Option 4 (Skip):**
     Notify user that manual restart is needed later.

9. **Verify container is running**
   ```bash
   docker-compose ps <service-name>
   # or
   docker ps --filter "name=<container-name>"
   ```

10. **Confirm completion**
    ```
    ## Docker Update Complete ✓
    
    - Image '<image-name>': Rebuilt
    - Container '<container-name>': [Restarted / Skipped / Waiting]
    ```

---

### Phase 10: Final Confirmation

**Goal:** Summarize everything that was done.

```
## Workflow Complete ✓

### Issue & PR
- Issue #<number>: Closed
- PR #<pr-number>: Merged (squash)
- Branch '<branch-name>': Deleted (local + remote)

### Docker (if applicable)
- Image '<image-name>': Rebuilt
- Container '<container-name>': [Status]

### Summary
[One-line summary of what was implemented]
```

---

## Handling Common Situations

### Docker Image Not Found Locally
If the project uses Docker but no image exists locally:
```
Note: This project has a Dockerfile but no local image was found.
To enable automatic rebuild after merge, first build the image:
  docker-compose build
  # or
  docker build -t <image-name> .
```
Skip Phase 9 and continue to final confirmation.

### Multiple Docker Services Affected
If changes affect multiple services:
1. List all affected services
2. Rebuild all images
3. Assess each container independently (some may be UI, some may be workers)
4. Ask about non-interruptible containers as a batch if possible

### Container Has No Graceful Shutdown
If the container doesn't handle SIGTERM properly:
```
Warning: This container may not support graceful shutdown.
SIGTERM might be ignored, and SIGKILL will be sent after timeout.

Recommendation: Consider adding a signal handler to the application
before restarting, or choose "Restart now" and accept the interruption.
```

### Merge Conflicts
If conflicts arise during merge:
1. Notify the user immediately
2. Show the conflicting files
3. Offer to help resolve conflicts
4. Re-run tests after resolution

### CI Failures
If CI checks fail:
1. Fetch the failure logs: `gh pr checks <pr-number> --watch`
2. Analyze the failure
3. Propose fixes
4. Push fixes and wait for CI to re-run

### User Wants to Abort
At any phase, if the user wants to stop:
```bash
# If branch was created but not merged
git checkout main
git branch -D <branch-name>  # Force delete local
git push origin --delete <branch-name>  # Delete remote if pushed
```

### Continuing an Interrupted Workflow
If resuming work on an existing branch:
1. Check current state: `git status`, `git log --oneline -5`
2. Determine which phase to resume from
3. Continue from that phase

---

## Quick Reference

| Phase | Key Command | Decision Point |
|-------|------------|----------------|
| 1. Assess | `gh issue view <n>` | Confirm understanding |
| 2. Plan | Explore + draft plan | Approve plan |
| 3. Branch | `git checkout -b` | — |
| 4. Implement | Code + commit | — |
| 5. Test | Run test suite | Fix failures |
| 6. PR | `gh pr create` | — |
| 7. Review | `gh pr diff` | Approve merge |
| 8. Merge | `gh pr merge --squash --delete-branch` | — |
| 9. Docker | `docker-compose build && up -d` | Confirm restart (workers only) |
| 10. Done | Summary | — |

---

## Example Invocations

**Start fresh:**
> "Pick up issue #42 and implement it"

**Resume work:**
> "Continue working on issue #42, I think we were at the testing phase"

**Just review:**
> "Review PR #15 for issue #42"

**Skip to merge:**
> "The PR looks good, merge it and clean up"

**Skip Docker restart:**
> "Merge the PR but don't restart the containers, I'll do it during maintenance window"

**Force restart workers:**
> "Merge and restart everything, the queue is empty right now"
