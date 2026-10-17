#!/usr/bin/env bash
# Picks validated Jira features and lets Claude Code implement each one on its own branch + pull request.
# Deterministic side effects (labels, transitions, comments) stay here; the agent only writes code.
#
# Env (on top of scripts/jira.sh):
#   JIRA_PROJECT            Jira project key (required unless JIRA_JQL is set)
#   JIRA_READY_STATUS       status meaning "validated, ready for dev" (default: Validated)
#   JIRA_REVIEW_STATUS      status to move to once the PR is open   (default: In Review)
#   JIRA_JQL                full JQL override
#   ANTHROPIC_API_KEY       used by Claude Code
#   CLAUDE_MODEL            default: claude-sonnet-5-5
#   CLAUDE_MAX_TURNS        default: 120
#   BASE_BRANCH             default: main
set -euo pipefail
cd "$(dirname "$0")/.."

READY_STATUS=${JIRA_READY_STATUS:-Validated}
REVIEW_STATUS=${JIRA_REVIEW_STATUS:-In Review}
BASE_BRANCH=${BASE_BRANCH:-main}
JQL=${JIRA_JQL:-"project = ${JIRA_PROJECT:?JIRA_PROJECT is required} AND status = \"$READY_STATUS\" \
AND issuetype in (Story, Task, Bug) \
AND (labels is EMPTY OR labels not in (claude-in-progress, claude-done, claude-failed)) \
ORDER BY priority DESC, created ASC"}

mkdir -p logs
keys=$(scripts/jira.sh search "$JQL")
if [ -z "$keys" ]; then
	echo "No validated feature waiting for implementation."
	exit 0
fi

failures=0
for key in $keys; do
	echo "=================== $key ==================="
	scripts/jira.sh label "$key" add claude-in-progress

	# Start every ticket from a clean, up-to-date base (a previous failed run may have left changes behind)
	git checkout -qf "$BASE_BRANCH"
	git clean -fdq
	git pull -q --ff-only origin "$BASE_BRANCH"

	set +e
	claude -p "Use the implement-jira-feature skill to implement Jira issue $key." \
		--model "${CLAUDE_MODEL:-claude-sonnet-5-5}" \
		--permission-mode acceptEdits \
		--max-turns "${CLAUDE_MAX_TURNS:-120}" \
		--output-format json >"logs/$key.json"
	exit_code=$?
	set -e

	result=$(jq -r '.result // ""' "logs/$key.json" 2>/dev/null || true)
	status=$(grep -oE '^STATUS=[A-Z_]+' <<<"$result" | tail -n1 | cut -d= -f2 || true)
	pr_url=$(grep -oE '^PR_URL=\S+' <<<"$result" | tail -n1 | cut -d= -f2- || true)

	scripts/jira.sh label "$key" remove claude-in-progress
	if [ "$exit_code" -eq 0 ] && [ "$status" = "DONE" ] && [ -n "$pr_url" ]; then
		scripts/jira.sh label "$key" add claude-done
		scripts/jira.sh comment "$key" "Implementation proposed by Claude Code, ready for review: $pr_url"
		scripts/jira.sh transition "$key" "$REVIEW_STATUS"
		echo "$key -> $pr_url"
	elif [ "$status" = "NEEDS_CLARIFICATION" ]; then
		# The agent already posted its questions on the ticket; it will be picked up again once the label is removed
		scripts/jira.sh label "$key" add claude-failed
		echo "$key -> needs clarification"
	else
		scripts/jira.sh label "$key" add claude-failed
		scripts/jira.sh comment "$key" "Claude Code could not deliver this ticket automatically (exit=$exit_code, status=${status:-none}). See Jenkins build ${BUILD_URL:-(local run)} artifact logs/$key.json."
		echo "$key -> FAILED"
		failures=$((failures + 1))
	fi
done

# Leave the workspace on the base branch for the next ticket / next run
git checkout -qf "$BASE_BRANCH"
[ "$failures" -eq 0 ]
