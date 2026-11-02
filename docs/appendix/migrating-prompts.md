# Migrating Prompts

If your prompts are still in the old two-file format — a `.txt` file with `[PLACEHOLDERS]` and `//directives`, plus a `.json` file of past parameter values — this page shows how to convert them to the current single-file `.md` format with the `migrate_prompts` script.

## Old format vs. new format

**Before:** `~/.prompts/summarize.txt` …

```text
# ~/.prompts/summarize.txt
# Desc: Summarize the given document
//config temperature 0.3
//include shared_context.md

Summarize the following [DOCUMENT_TYPE] document
for a [TARGET AUDIENCE] reader:

[CONTENT]
```

… and `~/.prompts/summarize.json`, which held the values you'd typed before:

```json
{ "[DOCUMENT_TYPE]": ["report", "article", "paper"], "[CONTENT]": [] }
```

**After:** `~/.prompts/summarize.md`, exactly as the script writes it:

```markdown
---
name: summarize
description: Summarize the given document
temperature: 0.3
parameters:
  document_type: paper
  target_audience: null
  content: null
---

<%= include('shared_context.md') %>

Summarize the following <%= document_type %> document
for a <%= target_audience %> reader:

<%= content %>
```

Settings move into YAML front matter, placeholders become ERB, and each parameter gets a default (`null` means aia will ask for it).

The script puts each `//config` setting where aia 2.0 reads it. `model`, `temperature`, `top_p`, `next`, `pipeline`, `shell` and `erb` stay at the top level of the front matter; everything else goes under a `config:` key, at its place in the configuration (`//config tokens true` becomes `config:` / `flags:` / `tokens: true`). A key the script doesn't recognize, such as the removed `terse`, is put under `config:` as written and listed as a warning, so you can fix or delete it. See [Prompt Files](../prompts/prompt-files.md) and [Parameters](../prompts/parameters.md).

The script turns `//config model …` into a front-matter `model:`, and `//temperature` / `//top_p` into `temperature:` / `top_p:`. These keep working in 2.0. See [Prompt Files](../prompts/prompt-files.md#front-matter-keys).

## Get the script

`migrate_prompts` is not installed with the gem. It lives in the aia repository and needs nothing but Ruby:

```bash
git clone https://github.com/MadBomber/aia.git
cd aia
ruby bin/migrate_prompts --help
```

## Run it

Always start with a dry run. With no file arguments it scans your whole prompts directory (`$AIA_PROMPTS__DIR`, or `~/.prompts`), including subdirectories:

```console
$ ruby bin/migrate_prompts --dry-run --verbose
Scanning /Users/you/.prompts
Processing 2 .txt file(s)
  Flag: review.txt → review.txt-review (needs review)
  Migrate: summarize.txt → summarize.md
    YAML config keys: temperature
    Parameters: document_type, target_audience, content
    Description: Summarize the given document

Migration summary:
  Migrated:           1 files
  Flagged for review: 1 files (*.txt-review)
  Skipped:            0 files (*.md already exists)
```

Nothing is changed in a dry run. When the plan looks right, run it for real:

```bash
ruby bin/migrate_prompts
```

Or limit it to particular files or directories:

```bash
ruby bin/migrate_prompts ~/.prompts/writing/
ruby bin/migrate_prompts ~/.prompts/code_review.txt ~/.prompts/debug_help.txt
AIA_PROMPTS__DIR=~/old-prompts ruby bin/migrate_prompts --dry-run
```

| Option | Effect |
|---|---|
| `--dry-run` | Report what would happen; change nothing. |
| `--verbose` | Show the keys, parameters and description found in each file. |
| `--force` | Overwrite an existing `.md` file. Without it, a `.txt` whose `.md` already exists is skipped. |
| `--reprocess` | Look at `*.txt-review` files again and migrate the ones that now pass. |
| `-h`, `--help` | Show usage. |

The original `.txt` and `.json` files are left in place. Delete them yourself once you're happy with the `.md` versions.

## What gets converted

### Placeholders

| Old | New | Parameter |
|---|---|---|
| `[TOPIC]` | `<%= topic %>` | `topic` |
| `[FILE_NAME]` | `<%= file_name %>` | `file_name` |
| `[TARGET AUDIENCE]` | `<%= target_audience %>` | `target_audience` (spaces become underscores) |

Each parameter's default is the **most recent** value from the `.json` history file, or `null` (ask every time) if there is none.

### Directives

| Old line | Becomes |
|---|---|
| `//config KEY VALUE` or `//config KEY=VALUE` | `KEY: VALUE` at the top level for `model`, `temperature`, `top_p`, `next`, `pipeline`, `shell` and `erb`; otherwise under `config:` (`max_tokens` → `config:` / `llm:` / `max_tokens:`). Dotted keys nest under `config:` as written. `true`/`false` and numbers keep their types. |
| `//temp 0.3` | `temperature: 0.3` |
| `//topp 0.9` | `top_p: 0.9` |
| `//next other_prompt` | `next: other_prompt` |
| `//pipeline a, b, c` | `pipeline: [a, b, c]` |
| `//include FILE` | `<%= include('FILE') %>` |
| `//shell COMMAND` | ``<%= `COMMAND` %>``, which inserts the command's output |
| `//ruby CODE` | `<%= CODE %>`, with placeholders turned into parameter names |
| `//backend …` | Dropped. |
| Any other `//name …` | Left in the body unchanged, with an `Unrecognized directive` warning in the summary. |

When a directive argument contains a placeholder, it becomes the parameter: `//include [FILE]` turns into `<%= include(file) %>`.

A placeholder in a `//shell` command becomes an interpolated parameter: `//shell ls [DIR]` turns into ``<%= `ls #{dir}` %>``. See [ERB & Shell](../prompts/erb-and-shell.md).

### Everything else

| Old | New |
|---|---|
| `#!` shebang on line 1 | Kept on line 1, above the front matter. |
| `# ~/.prompts/name.txt` path comment | Dropped. |
| `# Desc: …` (and indented `#` continuation lines) | `description:` in front matter. |
| Other `# comment` lines | HTML comments (`<!-- … -->`), which aia strips before sending the prompt. |
| Text after `__END__` | One HTML comment at the end of the file. |
| Multi-line `<% … %>` blocks | Copied unchanged. |

## Files flagged for review

The script won't guess when a file is ambiguous. It renames `name.txt` to `name.txt-review` and leaves it for you when the file:

- contains a fenced code block (` ``` `), where a `[NAME]` might be code rather than a placeholder;
- has a placeholder inside ERB (`<%= [NAME] %>`);
- has bracketed text that looks like a placeholder attempt but isn't a clean one, such as `[LANGUAGE code]` or `[e.g. JSON]`.

Bracketed text that clearly isn't a placeholder — shell tests like `[ -z "$x" ]`, `[ActiveRecord::Base]`, `["a", "b"]`, camelCase, or anything 50 characters or longer — doesn't cause a flag.

To deal with a flagged file, either:

1. **Fix it and reprocess.** Edit the `.txt-review` file so its placeholders are clean `[UPPER_CASE]` names (or remove the brackets that aren't placeholders), then run the command below. A file with a fenced code block is flagged every time, so convert those by hand.

    ```bash
    ruby bin/migrate_prompts --reprocess --dry-run
    ruby bin/migrate_prompts --reprocess
    ```

    Files that now pass are renamed back to `.txt` and migrated; the rest stay flagged.

2. **Convert it by hand** into a new `.md` file using the format above, then delete the `.txt-review`.

## After migrating

1. Look over a few converted files, especially ones that had `//shell`, `//ruby` or `Unrecognized directive` warnings.
2. Run a converted prompt: `aia summarize report.md`. aia asks for each parameter whose default is `null`.
3. Remove the old `.txt` and `.json` files.

## See also

- [Prompt Files](../prompts/prompt-files.md)
- [Parameters](../prompts/parameters.md)
- [ERB & Shell](../prompts/erb-and-shell.md)
- [Upgrading to 2.0](upgrading-2.0.md)
