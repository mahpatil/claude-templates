# Claude Code Project Settings

Project-level [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration including custom commands, agents, hooks, and permission settings.

## Structure

| Path | Description |
|------|-------------|
| [commands/](./commands/) | Slash commands invoked via `/command-name` in Claude Code sessions |
| [agents/](./agents/) | Custom agent definitions for specialized tasks (code review, PR creation, testing) |
| [hooks/](./hooks/) | Shell scripts triggered on Claude Code lifecycle events |
| [settings.json](./settings.json) | Shared project settings: default model, allowed CLI commands, directory permissions |
| settings.local.json | Local-only overrides (not committed) for user-specific permissions |

## Commands

| Command | Description |
|---------|-------------|
| `/checkpoint` | Commit current changes to git |
| `/implement` | Scaffold and implement a feature |
| `/validate` | Validate code against project standards |
| `/raise-pr` | Create a pull request |
| `/fix-github-issue` | Analyze and fix a GitHub issue |
| `/idea-review` | Product review from multiple expert perspectives |
| `/idea-review-cust` | Customer-focused product critique |
| `/initialize` | Initialize a new project |
| `/incubate` | Incubate a new product idea |

## Agents

| Agent | Description |
|-------|-------------|
| code-reviewer | Automated code review |
| pr-agent | Pull request creation and management |
| tester | Test generation and execution |
