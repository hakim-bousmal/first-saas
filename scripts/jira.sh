#!/usr/bin/env bash
# Minimal Jira Cloud REST client used by the scan job and by the implement-jira-feature skill.
#
# Env: JIRA_BASE_URL (https://xxx.atlassian.net), JIRA_USER (email), JIRA_API_TOKEN,
#      JIRA_AC_FIELD (optional, custom field holding acceptance criteria, e.g. customfield_10035)
#
# Usage:
#   jira.sh search "<JQL>"                 -> issue keys, one per line
#   jira.sh get KEY                        -> ticket as compact JSON (ADF converted to text)
#   jira.sh comment KEY "text"
#   jira.sh label KEY add|remove LABEL
#   jira.sh transition KEY "Status name"   -> no-op with a warning if the transition is not available
set -euo pipefail

: "${JIRA_BASE_URL:?JIRA_BASE_URL is required}"
: "${JIRA_USER:?JIRA_USER is required}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN is required}"

api() {
	local method=$1 path=$2
	shift 2
	curl -fsS -u "$JIRA_USER:$JIRA_API_TOKEN" -X "$method" \
		-H 'Accept: application/json' -H 'Content-Type: application/json' \
		"$JIRA_BASE_URL/rest/api/3$path" "$@"
}

# Atlassian Document Format -> plain text, keeping paragraphs and list items readable
ADF_TO_TEXT='
def adf:
  if type == "object" then
    if .type == "text" then .text
    elif .type == "hardBreak" then "\n"
    else
      (if .type == "listItem" then "- " else "" end)
      + ((.content // []) | map(adf) | join(""))
      + (if (.type | IN("paragraph", "heading", "codeBlock", "blockquote", "rule")) then "\n" else "" end)
    end
  elif type == "string" then .
  else "" end;'

cmd=${1:-}
case "$cmd" in
search)
	api GET "/search/jql" -G \
		--data-urlencode "jql=$2" \
		--data-urlencode "fields=key" \
		--data-urlencode "maxResults=${MAX_RESULTS:-5}" |
		jq -r '.issues[].key'
	;;
get)
	fields="summary,description,issuetype,priority,labels,components,subtasks,status"
	[ -n "${JIRA_AC_FIELD:-}" ] && fields="$fields,$JIRA_AC_FIELD"
	api GET "/issue/$2?fields=$fields" |
		jq --arg ac "${JIRA_AC_FIELD:-}" "$ADF_TO_TEXT"'
		{
			key,
			summary: .fields.summary,
			type: .fields.issuetype.name,
			status: .fields.status.name,
			priority: .fields.priority.name,
			labels: .fields.labels,
			components: [.fields.components[]?.name],
			description: (.fields.description | adf),
			acceptanceCriteria: (if $ac == "" then null else (.fields[$ac] | adf) end),
			subtasks: [.fields.subtasks[]? | {key, summary: .fields.summary}]
		}'
	;;
comment)
	body=$(jq -n --arg text "$3" '{body: {type: "doc", version: 1, content: [
		{type: "paragraph", content: [{type: "text", text: $text}]}]}}')
	api POST "/issue/$2/comment" -d "$body" >/dev/null
	;;
label)
	body=$(jq -n --arg op "$3" --arg label "$4" '{update: {labels: [{($op): $label}]}}')
	api PUT "/issue/$2" -d "$body"
	;;
transition)
	id=$(api GET "/issue/$2/transitions" | jq -r --arg name "$3" \
		'.transitions[] | select((.name | ascii_downcase) == ($name | ascii_downcase) or (.to.name | ascii_downcase) == ($name | ascii_downcase)) | .id' | head -n1)
	if [ -z "$id" ]; then
		echo "WARN: transition '$3' not available for $2" >&2
		exit 0
	fi
	api POST "/issue/$2/transitions" -d "{\"transition\": {\"id\": \"$id\"}}"
	;;
*)
	sed -n '2,15p' "$0"
	exit 1
	;;
esac
