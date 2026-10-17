# Build environment for the Jira -> Claude Code job: JDK 25 for the Maven build, Node for Claude Code,
# git + gh to push branches and open PRs, jq/curl for the Jira helper.
FROM eclipse-temurin:25-jdk

ARG CLAUDE_CODE_VERSION=2.1.302

RUN apt-get update \
	&& apt-get install -y --no-install-recommends git jq curl ca-certificates gnupg \
	&& curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
	&& curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends nodejs gh \
	&& npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
	&& rm -rf /var/lib/apt/lists/*

# Jenkins runs the container with its own uid; this user only provides a home for local runs
RUN useradd -m -u 10001 agent
USER agent
