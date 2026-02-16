<!-- // .claude/commands/sync-md2mdx.md -->
Sync markup source files into MDX content files.

Arguments format: `<source-folder> <mdx-folder>` (e.g. `sync-md2mdx docs/raw content/blog`)

**ARGUMENTS:** $ARGUMENTS

## Folder resolution (in priority order)

1. **Parse ARGUMENTS** — if two space-separated paths are provided, use them directly.
2. **Read last-used folders** — read `~/.claude/sync-mdx-last.json` (JSON with `source` and `mdx` keys). If the file exists, offer those as the default and ask the user to confirm or override.
3. **Ask the user** — if no arguments and no saved state, ask for both paths.

After resolving the folders (whether from args, saved state, or user input), **always write them back** to `~/.claude/sync-mdx-last.json`:
```json
{ "source": "<resolved-source-folder>", "mdx": "<resolved-mdx-folder>" }
```

## Steps

### 1. Discover source files
- Recursively list all markup files in `<source-folder>` (`.md`, `.mdx`, `.markdown`, `.txt`, `.html` etc.)
- For each file, read its content to understand: title, slug/topic, headings, key concepts, and intended purpose.

### 2. Discover existing MDX files
- Recursively list all `.mdx` files in `<mdx-folder>`.
- For each MDX file, read its frontmatter and content to understand: title, slug, topic coverage.

### 3. Content-based matching (NOT filename-based)
- Match source files to MDX files by **semantic content**: compare titles, headings, topics, and key concepts — not filenames.
- Build a mapping:
  - **Matched**: source file has a corresponding MDX file covering the same topic
  - **Missing**: source file has no corresponding MDX file
  - **Orphaned**: MDX file has no corresponding source file (report only, do not delete)

### 4. Resolve image for each new MDX file

Before writing frontmatter, resolve the image path using this chain. The images directory is `public/images/insights/` (relative to the project root).

**Resolution chain (stop at first match):**

1. **Exact slug match** — glob for `public/images/insights/<slug>.*`. If found, use that path.
2. **Category image** — glob for `public/images/insights/<category>.*`. If found, use that path.
3. **Thematic copy** — pick the most thematically relevant image from those that exist, based on the post's category and tags. Use this mapping as a starting guide (adapt as the image library grows):
   - `ai-ml`, `engineering`, `education` → prefer `claude-code.png` or `microservices.png`
   - `zero-trust`, `security` → prefer `zero-trust.png`
   - `leadership`, `innovation`, `postitivity`, `personal-brand` → pick the closest available
   Then **copy** that image to `public/images/insights/<category>.png` using Bash (`cp`), so all future posts in this category reuse it automatically. Use the new `<category>.png` path.
4. **Default fallback** — if the `public/images/insights/` directory has no images at all, copy any project image (e.g. `public/images/hero.png`) to `public/images/insights/default.png` and use `/images/insights/default.png`.

**Never invent or guess a path** — only use a path after confirming the file exists or after copying it yourself.

Track which images were auto-resolved vs. exact matches for the summary.

### 5. Create missing MDX files
For each **missing** source file:
- Read the source file fully.
- Generate a proper MDX file with:
  - Frontmatter: `title`, `description`, `date` (today), `slug` (derived from title, kebab-case), and any other frontmatter fields present in sibling MDX files in `<mdx-folder>`.
  - **`image` field:** Use the resolved image path from Step 4.
  - Body: convert the source content into clean MDX — preserve headings, lists, code blocks; remove any source-specific artifacts.
  - Place the file in `<mdx-folder>` using the same relative subfolder structure as the source, or at root if flat.
- Match the frontmatter schema of existing MDX files in the target folder.

### 6. Summary report
Print a clear summary:
```
## Sync Summary

### Matched (no action needed)
- <source-file> → <mdx-file>
...

### Created (new MDX files)
- <mdx-file> (from <source-file>) [image: <how resolved — exact|category|thematic-copy|default>]
...

### Images auto-created (category fallbacks)
- public/images/insights/<category>.png  (copied from <source-image>)
...

### Orphaned MDX files (source not found — review manually)
- <mdx-file>
...
```

### 7. Commit and push
- Stage the newly created/modified MDX files and any auto-created images: `git add <mdx-folder> public/images/insights/`
- Commit with message: `chore: sync MDX content from source markup files\n\nAdded: <count> new MDX files, <count> auto-resolved images\nSources: <source-folder>`
- Push to the current branch: `git push`
- Confirm success or report any errors.
