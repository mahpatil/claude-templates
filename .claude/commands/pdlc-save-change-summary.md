Write a timestamped documentation summary to `docs/fixes/` or `docs/features/` in the current project.

## How to use
- `/save-doc fix` — document a bug fix or set of fixes
- `/save-doc feature` — document a new feature or set of features
- `/save-doc fix terminal race condition` — with optional title hint
- `/save-doc feature agent prompt and phase filter` — with optional title hint

## Instructions

Parse `$ARGUMENTS` to determine:
- **type**: first word, either `fix` or `feature` (default `fix` if absent or unrecognised)
- **title hint**: remaining words joined (may be empty — infer from context)

Then follow these steps:

### 1. Determine what to document
Look at the current conversation context: what fixes or features were just discussed, implemented, or shipped? Identify all distinct changes. If a title hint was provided, use it to scope the summary; otherwise summarise everything relevant from the session.

### 2. Gather supporting detail
Run these commands to ground the summary in actual code changes:
```
git log --oneline -10
git show --stat HEAD
```
Use the output to confirm file names, commit hashes, and scope.

### 3. Generate the filename
- Timestamp: run `date -u +"%Y-%m-%dT%H:%M:%SZ"` to get an ISO-8601 UTC timestamp
- Slug: convert the title (hint or inferred) to lowercase-kebab-case, max 60 chars
- Filename pattern: `{timestamp}-{slug}.md`
- Destination:
  - `fix`/`fixes` → `docs/fixes/`
  - `feature`/`features` → `docs/features/`
- Create the directory if it doesn't exist: `mkdir -p docs/fixes` or `mkdir -p docs/features`

### 4. Write the file
Use this structure:

```markdown
# {Type} Summary — {timestamp}

## Overview
One-paragraph plain-English summary of what changed and why.

## Changes

### {Change title}
**Root cause / motivation:** …

**What was done:**
- File `path/to/file.ts`: description of change
- File `path/to/other.ts`: description of change

**How to verify:** …

### {Next change if any}
…

## Files changed

| File | Description |
|------|-------------|
| `path/to/file` | What changed |

## Commit
`{hash}` — {commit message}
```

Use the actual commit hash(es) from `git log`. Omit sections that are not applicable (e.g. "Root cause" for a feature).

### 5. Commit the file
Stage and commit the new doc file:
```
git add docs/
git commit -m "docs: add {type} summary — {slug}"
```

Do NOT push unless the user asks.

### 6. Confirm
Tell the user the path of the file that was written.
