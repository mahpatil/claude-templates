# Claude Code Templates

Reusable templates for setting up [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in your projects.

## Templates

| Template | Description |
|----------|-------------|
| [CLAUDE.md](./CLAUDE.md) | Project context file template with placeholders for tech stack, architecture, coding standards, testing, security, and observability. Drop this into your repo root and fill in the `{{placeholders}}`. |
| [build-workflow.md](./build-workflow.md) | Reference workflow for using Claude Code alongside VS Code and Ghostty terminal, including terminal role assignments and a YAML-based context system. |

## Usage

1. Copy the template you need into your project
2. Replace the `{{PLACEHOLDER}}` values with your project details
3. Commit the file to your repo so Claude Code picks it up automatically
