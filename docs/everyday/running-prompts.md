# Running Prompts

This chapter covers every way to tell AIA what to send: a saved prompt, text on stdin, a fuzzy search, an executable prompt file, or nothing at all (straight into chat). It also explains how AIA builds the final text that the model sees.

## The command line in one picture

```text
aia [options] [PROMPT_ID] [CONTEXT_FILE]*
aia [options] --chat [PROMPT_ID] [CONTEXT_FILE]*
```

- **Options** start with `-` or `--` and can go anywhere on the line.
- **PROMPT_ID** names a prompt file in your prompts directory.
- **CONTEXT_FILE**s are files whose contents are appended to the prompt.

## Running a saved prompt

A prompt ID is the name of a prompt file in your prompts directory without the `.md` extension:

| File | Prompt ID |
|------|-----------|
| `~/.prompts/summarize.md` | `summarize` |
| `~/.prompts/code_review.md` | `code_review` |

```bash
aia summarize report.txt
aia code_review lib/*.rb
```

Prompt files can live in subfolders, and their names can contain hyphens. `~/.prompts/dev/code-review.md` has the ID `dev/code-review`. You can also name a prompt file by its path, starting with `/`, `./`, `../` or `~/`, such as `aia ./drafts/idea.md`.

Use a different prompts directory for one run with `--prompts-dir DIR`, or permanently with `AIA_PROMPTS__DIR` or `prompts.dir` in the config file.

### How AIA decides what's a prompt ID

AIA treats the first argument as a prompt ID only when **both** of these are true:

1. It is *not* the name of an existing file in the current directory, and
2. `<prompts dir>/<argument>.md` exists.

Otherwise the first argument is treated as a context file like the rest. So if you have a file called `summarize` in your working directory, `aia summarize notes.txt` will treat both as context files (and, with no prompt ID, stop with `A prompt ID is required…`). Rename the file or run from another directory.

If the first argument has no extension and is neither a prompt nor a file, AIA reports it as a missing prompt and suggests close matches:

```text
No prompt named 'code_reveiw' in /Users/you/.prompts (and no file by that name).
Did you mean: code_review?
```

Every other argument must be an existing file. If one isn't, AIA stops before calling the model:

```text
The following files do not exist: notes.txt
```

## Asking without a prompt file

When you give no prompt ID, whatever you pipe in becomes the prompt:

```bash
echo "Suggest five names for a Ruby gem that parses invoices." | aia
git diff | aia            # the diff itself is the prompt
aia < question.txt
```

When you *do* give a prompt ID, piped text is appended to that prompt instead:

```bash
git diff --staged | aia commit_msg
```

See [Context Files and Piping](context-and-piping.md) for more patterns.

!!! tip "Interactive input still works after a pipe"
    After reading stdin, AIA reconnects to your terminal, so a piped prompt can still ask you for [parameter](../prompts/parameters.md) values, and `--chat` still works.

## Picking a prompt with fuzzy search

If [fzf](https://github.com/junegunn/fzf) is installed, `--fuzzy` (`-f`) opens a searchable list of your prompts with a preview of each:

```bash
aia --fuzzy
aia -f --chat           # pick a prompt, then keep chatting
```

Press ++esc++ to cancel.

## Running a prompt file directly

If the first file on the command line starts with a `#!` line, AIA treats that file as the prompt itself (the `#!` line is dropped). That is what makes [executable prompts](../prompts/executable-prompts.md) work:

```bash
aia ./weekly_report.md        # first line is #!/usr/bin/env aia ...
./weekly_report.md            # same thing, after chmod +x
```

## Chat with no prompt

`--chat` on its own starts an empty conversation:

```bash
aia --chat
aia --chat design_notes.md    # context files become your first message
```

See [Chat Sessions](chat.md).

## Running several prompts in a row

Use `--pipeline` (`-p`) or `--next` (`-n`) to run more than one prompt, each building on the last. Give the first prompt ID on the command line as usual; outside `--chat`, `--pipeline` on its own stops with `A prompt ID is required…`:

```bash
aia extract --pipeline summarize,translate report.txt
aia extract --next summarize report.txt
```

Pipelines are covered in [Pipelines](../prompts/pipelines.md).

## What the model actually receives

For each prompt, AIA assembles the text in this order:

1. The **role**, if you gave `--role` (see [Roles and Skills](roles-and-skills.md))
2. The **prompt** itself, after its parameters, shell references and ERB are filled in
3. Any **skills** you gave with `--skill`
4. Anything piped in on **stdin**
5. The contents of each **context file**, in the order you listed them

Each part is separated by a blank line. In chat mode the skills go into the system prompt instead, so they apply to every turn. A role from your roles folder also goes into the system prompt, in every mode (see [Roles and Skills](roles-and-skills.md)).

!!! note "A role on its own"
    `aia --role editor` with no prompt ID and no `--chat` runs the role file itself as the prompt. Add a prompt ID (`aia --role editor tighten draft.md`) to use the role as the system prompt for that prompt instead.

## Changing settings for one run

Most configuration can be overridden with an option. The ones you'll reach for most:

| Option | Effect |
|--------|--------|
| `-m`, `--model MODEL` | Which model to use ([Choosing Models](models.md)) |
| `-t`, `--temperature N` | Randomness of the answer (default `0.7`) |
| `--max-tokens N` | Cap the length of the answer (default `32767`) |
| `-r`, `--role ROLE` | Prepend a role |
| `-s`, `--skill IDS` | Append skills |
| `-o`, `--output [FILE]` / `--no-output` | Where to save the answer ([Output, History and Usage](output-and-history.md)) |
| `-c`, `--config-file FILE` | Use FILE instead of `~/.config/aia/aia.yml`; it also replaces your `AIA_*` environment variables (except `AIA_MODEL` and `AIA_PLUGINS_DIR`) |
| `--tokens` / `--cost` | Show usage after each answer |

The complete list is in the [CLI reference](../reference/cli.md); how options, environment variables and config files combine is explained in [Precedence](../configuration/precedence.md).

## Commands that just answer a question and exit

These don't call a model. They print information and quit:

| Command | Shows |
|---------|-------|
| `aia --help` | All options |
| `aia --version` | The installed version |
| `aia --available-models [QUERY]` | Models in the catalog ([Choosing Models](models.md)) |
| `aia --list-providers` | Registered providers and which have API keys |
| `aia --provider SLUG --list-models` | The live models a provider serves |
| `aia --list-roles` | Your role files and their front matter |
| `aia --list-skills` | Your skills |
| `aia --list-tools` | Loaded tools (add `--mcp-list` to include MCP server tools) |
| `aia --mcp-list` | Configured MCP servers |
| `aia --dump FILE.yml` | Writes your effective configuration to a YAML file |
| `aia --completion bash\|zsh\|fish` | A shell completion script |

## Stopping AIA

Press ++ctrl+c++ to interrupt AIA at any time. It prints `Interrupted. Exiting...` and exits with status 130. Configuration errors (a missing prompt, a bad file name, an unknown option) exit with status 1 and a message on stderr, so AIA behaves well in scripts.

## Common messages

| Message | Meaning |
|---------|---------|
| `A prompt ID is required unless you use --chat, --fuzzy, --pipeline or --role, …` | You ran `aia` with nothing to send. Context files alone aren't a prompt: add a prompt ID, `--chat`, or piped text. |
| `Error: Prompt ID 'x' does not exist at …` | A prompt named in `--pipeline`/`--next` isn't in your prompts directory. |
| `No prompt named 'x' in … (and no file by that name).` | The prompt ID is misspelled, or the prompt is in another directory. AIA suggests close matches. |
| `The following files do not exist: …` | A context file name is wrong. |
| `Unknown argument(s): _x … Did you mean: -x?` | You typed `_` instead of `-` in front of an option. |

## See also

- [Context Files and Piping](context-and-piping.md)
- [Chat Sessions](chat.md)
- [Prompt Files and Front Matter](../prompts/prompt-files.md)
- [CLI reference](../reference/cli.md)
