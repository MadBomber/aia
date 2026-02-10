# Migrating Prompts

AIA includes a migration tool for converting prompt files from the legacy prompt_manager v0.5.8 format to the v1.0.0 format. This guide covers the migration process, what changes, and how to handle files that need manual attention.

## Why Migrate?

The prompt_manager gem moved from a two-file format (`.txt` + `.json`) with `[PLACEHOLDER]` syntax to a single `.md` file with YAML front matter and ERB parameters. The new format provides:

- **Self-contained prompts** — metadata, parameters, and body in one file
- **Standard ERB** — `<%= param %>` instead of custom `[PARAM]` syntax
- **YAML front matter** — structured configuration instead of `/` directives
- **Markdown body** — native rendering support in editors and documentation tools

## Format Comparison

### Old Format (v0.5.8)

Two files per prompt:

**`my_prompt.md`**
```
# ~/.prompts/my_prompt.md
# Desc: Summarize the given document
/config temperature 0.3
/include shared_context.md

Summarize the following [DOCUMENT_TYPE] document:

[CONTENT]
```

**`my_prompt.json`** (parameter history)
```json
{
  "[DOCUMENT_TYPE]": ["report", "article", "paper"],
  "[CONTENT]": ["..."]
}
```

### New Format (v1.0.0)

Single file:

**`my_prompt.md`** (same filename, single file now)
```markdown
---
name: my_prompt
description: Summarize the given document
temperature: 0.3
parameters:
  document_type: paper
  content: null
---

<%= include('shared_context.md') %>

Summarize the following <%= document_type %> document:

<%= content %>
```

## Running the Migration

The migration script is at `bin/migrate_prompts`. It requires no external dependencies beyond Ruby's standard library.

### Basic Usage

```bash
# Scan the entire prompts directory (uses $AIA_PROMPTS__DIR or ~/.prompts)
bin/migrate_prompts

# Preview changes without modifying files
bin/migrate_prompts --dry-run

# Migrate with detailed output
bin/migrate_prompts --verbose

# Migrate specific files or directories
bin/migrate_prompts ~/.prompts/development/
bin/migrate_prompts ~/.prompts/code_review.md ~/.prompts/debug_help.md
```

### CLI Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would change without modifying any files |
| `--verbose` | Show detailed transformation info for each file |
| `--force` | Overwrite existing `.md` files (default: skip if `.md` exists) |
| `--reprocess` | Re-examine `*.txt-review` files and recover those that now pass |
| `-h`, `--help` | Show usage help |

### Environment

The script uses `AIA_PROMPTS__DIR` to locate the prompts directory. If unset, it defaults to `~/.prompts`.

```bash
# Use a custom prompts directory
AIA_PROMPTS__DIR=~/my-prompts bin/migrate_prompts --dry-run
```

## What Gets Migrated

### Placeholders

Standard `[PLACEHOLDER]` tokens become ERB expressions:

| Old | New |
|-----|-----|
| `[TOPIC]` | `<%= topic %>` |
| `[FILE_NAME]` | `<%= file_name %>` |
| `[TECH STACK]` | `<%= tech_stack %>` (spaces normalized to underscores) |

### Directives

Prompt directives are migrated to YAML front matter or ERB calls:

| Old Directive | New Location |
|---------------|--------------|
| `/config temperature 0.3` | `temperature: 0.3` in YAML |
| `/config top_p 0.9` | `top_p: 0.9` in YAML |
| `/temp 0.5` | `temperature: 0.5` in YAML |
| `/topp 0.8` | `top_p: 0.8` in YAML |
| `/next follow_up` | `next: follow_up` in YAML |
| `/pipeline step1, step2` | `pipeline: [step1, step2]` in YAML |
| `/include file.md` | `<%= include('file.md') %>` in body |
| `/shell command` | `<%= system('command') %>` in body |
| `/ruby expression` | `<%= expression %>` in body |
| `/backend ...` | Silently removed (deprecated) |

### Comments

Lines beginning with `#` (outside of code fences and ERB blocks) are converted to HTML comments:

```
# Old format: this is a comment
```

Becomes:

```html
<!-- this is a comment -->
```

Multi-line comment blocks are grouped:

```html
<!--
First line of comment
Second line of comment
-->
```

Comments inside code fences (` ``` `) and multi-line ERB blocks (`<% ... %>`) are preserved as-is.

### Metadata

The script extracts metadata from the old format's header conventions:

- **File path comments** (`# ~/.prompts/name.md`) — removed
- **Description lines** (`# Desc: ...`) — moved to `description:` in YAML front matter
- **Prompt name** — derived from the filename (e.g., `code_review.md` → `name: code_review`)

### Parameter History

If a `.json` file exists alongside the `.md` file, the most recent value for each parameter is used as the default in the YAML `parameters:` block:

```yaml
parameters:
  document_type: paper    # last value from JSON history
  content: null           # no history available
```

### Content After `__END__`

Content below an `__END__` marker is wrapped in an HTML comment at the end of the `.md` file:

```html
<!--
Original content that was below __END__
-->
```

## Flagged Files

Files that contain constructs requiring manual review are renamed to `*.txt-review` instead of being migrated. The most common reasons a file gets flagged:

- **Code fences** (` ``` `) — the script cannot reliably distinguish between code fence content and prompt body text that might contain placeholders
- **Placeholders inside ERB blocks** — `[PARAM]` tokens within `<% ... %>` need manual conversion to Ruby variables
- **Ambiguous bracket expressions** — bracket content that looks like a placeholder but doesn't match the clean `[ALL_CAPS]` pattern

### Reviewing Flagged Files

After the initial migration, check the flagged files:

```bash
# List all flagged files
find ~/.prompts -name '*.txt-review'

# Preview what the migration would produce
bin/migrate_prompts --dry-run --verbose ~/.prompts/my_prompt.txt-review
```

For each flagged file, you have three options:

1. **Reprocess** — if the issue was transient, use `--reprocess` to try again
2. **Manual conversion** — create the `.md` file by hand following the new format
3. **Leave as-is** — flagged files don't affect AIA's operation with existing prompts

### Reprocessing Flagged Files

The `--reprocess` option re-examines all `*.txt-review` files. Files that now pass validation are renamed back to `*.txt` and migrated to `*.md`:

```bash
# Preview which files would be recovered
bin/migrate_prompts --reprocess --dry-run

# Recover files that now pass
bin/migrate_prompts --reprocess
```

The reprocess summary shows how many files were recovered versus still flagged:

```
Reprocess summary:
  Recovered: 22 files (*.txt-review → *.txt → *.md)
  Still flagged: 19 files (unchanged)
```

## Step-by-Step Migration Workflow

### 1. Preview the Migration

Start with a dry run to understand the scope of changes:

```bash
bin/migrate_prompts --dry-run --verbose
```

Review the output. Note how many files will be migrated, flagged, or skipped.

### 2. Run the Migration

```bash
bin/migrate_prompts --verbose
```

The script creates `.md` files alongside the original `.txt` files. It does not delete the originals.

### 3. Review the Results

```bash
# Check the summary counts
# Verify a few migrated files look correct
cat ~/.prompts/my_prompt.md

# List flagged files
find ~/.prompts -name '*.txt-review'
```

### 4. Reprocess Flagged Files

```bash
bin/migrate_prompts --reprocess --dry-run
bin/migrate_prompts --reprocess
```

### 5. Handle Remaining Flagged Files

For files still flagged after reprocessing, create `.md` versions manually. Common patterns:

**Files with outer ` ```markdown ` wrappers** — strip the outer fence, keep nested fences, extract metadata into YAML front matter.

**Files with placeholders inside ERB** — convert `[PARAM]` to Ruby variable references inside the ERB block:

```ruby
# Old
<% path = '[MODEL_FILENAME]' %>

# New
<% path = model_filename %>
```

**Files with `__END__` containing code fences** — wrap the post-`__END__` content in HTML comments or restructure as needed.

### 6. Clean Up Originals

Once you've verified the migration is correct, remove the old files:

```bash
# Remove original .txt files that have corresponding .md files
find ~/.prompts -name '*.txt' -exec sh -c '
  for f; do
    md="${f%.txt}.md"
    [ -f "$md" ] && rm "$f"
  done
' _ {} +

# Remove .json history files
find ~/.prompts -name '*.json' -delete
```

## Troubleshooting

### "No .txt files found"

The script couldn't find any `.txt` files in the prompts directory. Verify the path:

```bash
echo $AIA_PROMPTS__DIR
ls ~/.prompts/*.txt
```

### File skipped because .md already exists

By default, the script skips files that already have a corresponding `.md` file. Use `--force` to overwrite:

```bash
bin/migrate_prompts --force ~/.prompts/my_prompt.md
```

### Unrecognized directive warnings

Directives that the script doesn't know how to convert are preserved in the body as-is and reported as warnings. Review these manually after migration.

### Placeholder not converted

The script only converts clean placeholders matching `[ALL_CAPS_WITH_UNDERSCORES]`. Other bracket patterns (e.g., `[camelCase]`, `[with:colons]`) are left unchanged. This is intentional to avoid converting code that happens to contain brackets.

## Related Documentation

- [Prompt Management](../prompt_management.md) — organizing and managing your prompt collection
- [Advanced Prompting](../advanced-prompting.md) — ERB templates and dynamic prompts
- [Workflows & Pipelines](../workflows-and-pipelines.md) — multi-step prompt sequences
- [Configuration](../configuration.md) — AIA configuration reference
