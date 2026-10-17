---
name: implement-jira-feature
description: Implements a validated Jira feature end to end in this Spring Boot service - reads the ticket, plans, writes the code and its unit tests, runs the build, commits on a feature branch and opens a pull request. Use when asked to implement, develop or deliver a Jira issue (e.g. "implement SAAS-42").
argument-hint: <JIRA-KEY>
---

# Implement Jira feature $ARGUMENTS

You are delivering Jira issue `$ARGUMENTS` as a reviewable pull request. Work autonomously: this skill also runs
headless from Jenkins, where nobody can answer questions. Follow the steps in order.

## 1. Understand the ticket

1. Run `scripts/jira.sh get $ARGUMENTS`. It prints JSON with `summary`, `description`, `acceptanceCriteria`,
   `type`, `labels` and `subtasks`.
2. Delegate to the **jira-analyst** subagent: give it the ticket JSON and ask for an implementation plan.
3. If the analyst reports blocking open questions (missing acceptance criteria, contradictory requirements,
   a need for external systems or credentials), do NOT guess:
   - post the questions with `scripts/jira.sh comment $ARGUMENTS "<questions>"`
   - end your answer with the line `STATUS=NEEDS_CLARIFICATION` and stop.

## 2. Branch

`git switch -c feature/$ARGUMENTS-<short-kebab-summary>` from the current `main`. Never commit on `main`.

## 3. Implement

- Follow `CLAUDE.md` (package by feature, thin controllers, `ProblemDetail` errors, injected `Clock`).
- Read the closest existing feature (e.g. `com.firstsaas.project`) and mirror its structure.
- Keep the change scoped to the ticket. No drive-by refactors, no new dependency unless the ticket needs it
  (justify any new dependency in the PR body).

## 4. Unit tests

- Delegate to the **test-writer** subagent with: the ticket's acceptance criteria and the list of files you changed.
- Every acceptance criterion must map to at least one test. Edge cases: validation errors, not found, empty lists.

## 5. Verify

Run `./mvnw -B verify`. If it fails, read the failure, fix the cause (never delete, `@Disabled` or weaken tests,
never lower the coverage threshold) and retry. After 3 failed attempts, go to "Failure" below.

## 6. Review

Delegate to the **code-reviewer** subagent on `git diff main...HEAD`. Fix every finding marked BLOCKER or MAJOR,
then re-run `./mvnw -B verify`.

## 7. Commit and pull request

1. `git add` only the files you intended to change, then commit with message `$ARGUMENTS: <summary>`.
2. `git push -u origin feature/$ARGUMENTS-<short-kebab-summary>`
3. `gh pr create --base main --title "$ARGUMENTS: <summary>" --body "<body>"` where the body contains:
   - link to the ticket: `${JIRA_BASE_URL}/browse/$ARGUMENTS`
   - what changed and why (3-6 bullets)
   - the acceptance criteria as a checklist, each pointing to its test(s)
   - anything the reviewer must look at carefully

## 8. Final answer

End with exactly these two lines so the Jenkins job can parse them:

```
STATUS=DONE
PR_URL=<url printed by gh pr create>
```

## Failure

If you cannot reach a green build or the ticket cannot be delivered safely, do not push. Post a short Jira
comment explaining what blocked you, then end with `STATUS=FAILED`.
