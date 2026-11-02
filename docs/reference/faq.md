# FAQ & Troubleshooting

Answers to common questions, and fixes for the messages you are most likely to see. Error messages are quoted exactly as aia prints them, so you can search this page for yours.

## First steps

### Which API key do I need?

The one for the provider of the model you use. The default model, `gpt-4o-mini`, needs `OPENAI_API_KEY`; Claude models need `ANTHROPIC_API_KEY`; local models through Ollama or LM Studio need none. `aia --list-providers` marks the providers that have a key set:

```console
$ aia --list-providers | grep 'has API key'
- anthropic (has API key)
```

See [Environment Variables](../configuration/environment.md#provider-api-keys).

### How do I change the default model?

For one run, `-m`: `aia -m claude-haiku-4-5 my_prompt`. For every run, put it in `~/.config/aia/aia.yml`:

```yaml
models:
  - name: claude-haiku-4-5
```

or `export AIA_MODEL=claude-haiku-4-5`. See [Choosing Models](../everyday/models.md).

### How do I find a model's exact name?

```bash
aia --available-models sonnet               # search the model registry
aia --provider ollama --list-models         # what a provider is serving right now
```

### Why is there a `temp.md` in every directory I use aia in?

Responses are written to `temp.md` by default as well as to the screen. Pass `--no-output` or `-o somewhere.md`, or set it in your config file:

```yaml
output:
  file: false
```

(`file: ~` doesn't work: a null in the config file is ignored and the default remains.)

### How do I leave a chat session?

Type `exit`, press ++enter++ on an empty line, or press ++ctrl+c++. See [Chat Sessions](../everyday/chat.md).

### Where are my prompts?

In `~/.prompts`, unless you've set `--prompts-dir`, `prompts.dir` or `AIA_PROMPTS__DIR`. aia doesn't create the directory or ship any prompts; you write your own. See [Your First Prompt](../getting-started/first-prompt.md).

## Error messages

### `A prompt ID is required unless you use --chat, --fuzzy, --pipeline or --role, …`

You ran `aia` with nothing to send. Context files on their own are not a prompt. Give a prompt ID (`aia my_prompt`), a pipeline (`aia -p draft,polish`), a role (`aia -r editor`), start a chat (`aia --chat`), pick a prompt with `aia --fuzzy`, or pipe in some text.

### `No prompt named 'my_prompt' in … (and no file by that name).`

aia looked for `~/.prompts/my_prompt.md` and for a file called `my_prompt`, and found neither. If a prompt has a similar name, the message ends with `Did you mean: …?`. Usually it is:

- a typo in the prompt ID;
- a prompt in a different directory — check `ls ~/.prompts/my_prompt.md`, or add `--prompts-dir`;
- a prompt in a subdirectory — include the subdirectory: `aia dev/my_prompt`;
- a file with an extension other than `.md`.

### `Error: Prompt ID 'draftt' does not exist at /Users/you/.prompts/draftt.md`

One of the prompts in a pipeline (`-p`, `-n`, or `next:`/`pipeline:` in front matter) doesn't exist. aia checks them all before running anything and ends with `One or more prompt IDs do not exist.`

### `Unknown argument(s): _B` / `Did you mean: -B?`

An option was typed with an underscore instead of a dash. Use `-B`.

### `ERROR: invalid option: --terse`

The option doesn't exist. `--terse`, `--regex` and `--skills-prefix` were removed in 2.0; see [Upgrading to 2.0](../appendix/upgrading-2.0.md). Otherwise check spelling against `aia --help`.

### `ERROR: invalid argument: -t hot`

An option got a value of the wrong kind: `-t`, `--top-p` and the penalties need a number, `--max-tokens` and `--refresh` a whole number, and `--tool-approval` one of `ask`, `approve`, `deny`. The message names the option and the value it rejected.

### `Role file not found: …/roles/reviewer.md`

You used `-m MODEL=ROLE` and the role file doesn't exist. The message lists the roles that do exist. `aia --list-roles` shows what is available. See [Roles & Skills](../everyday/roles-and-skills.md).

### `Warning: Invalid role ID or file not found: roles/reviewer`

The role given with `-r` isn't in your roles directory. Run `aia --list-roles`, or give a path to the role file: `-r ./reviewer.md`.

### `ERROR: Config file not found: …`

The file given to `-c` doesn't exist. Check the path; `~` is expanded for you.

### `ERROR: Invalid log level 'loud'. Must be one of: debug, info, warn, error, fatal`

Use one of the five listed levels with `--log-level`.

### `Error: 'fzf' is not installed. Please install 'fzf' to use the --fuzzy option.`

Install fzf (`brew install fzf`, `apt install fzf` …) or name the prompt instead.

### `ERROR: --list-models requires --provider SLUG …`

`--list-models` asks one provider what it serves. Add `--provider`, for example `aia --provider ollama --list-models`, or search all known models with `--available-models`.

### `ERROR: unknown provider 'olama'. Registered providers: …`

The `--provider` slug isn't one aia knows. Pick one from the list printed with the error. A provider that comes from a separate gem appears once the gem is installed (or loaded with `--require`).

### `file/dir path is not valid: …` or `file should have *.rb extension: …`

`--tools` was given a path that doesn't exist, or a file that isn't `.rb`. Directories are fine; aia loads every `.rb` file in them.

### `NoMethodError` mentioning `param` when loading a tool

The tool is written for aia 1.x. Change `param :x, desc: "…"` to `parameter :x, description: "…"`. See [Upgrading to 2.0](../appendix/upgrading-2.0.md#custom-tools).

### `ERROR: /ruby is disabled. …`

`/ruby` is off by default. Start aia with `--allow-ruby-eval`, or set `flags.allow_ruby_eval: true` in `~/.config/aia/aia.yml`. Read [Security](../configuration/security.md) first.

### `ERROR: PUREMD_API_KEY is required in order to include a webpage`

`/webpage` fetches pages through the pure.md service, which needs an API key in `PUREMD_API_KEY`.

### `Warning: Skill 'x' not found in …` / `Warning: SKILL.md not found in …`

A skill named with `-s` or `/skill` isn't a subdirectory of your skills directory, or the subdirectory has no `SKILL.md`. Run `aia --list-skills`. Remember that the skills directory is `~/.prompts/skills` unless you set `skills.dir` / `--skills-dir`; it doesn't follow `--prompts-dir`.

### `Warning: configured plugins directory does not exist: …`

`--plugins-dir`, `paths.plugins_dir` or `AIA_PLUGINS_DIR` points at a missing directory. Create it or fix the setting.

### `ERROR: The shell 'tcsh' is not supported or the completion script is missing.`

`--completion` supports `bash`, `zsh` and `fish`.

## MCP servers and tools

### An MCP server shows as failed at startup

Failed servers are named in the startup banner, and `/mcp` in chat shows each one's error. Common causes:

- **The command isn't installed or not on your `PATH`.** Run the server's `command` and `args` yourself in a terminal.
- **Two servers offer a tool with the same name.** The second one fails. Add `prefix:` to one of them.
- **The server uses the `sse` or `ws` transport**, which aia 2.0 no longer supports. Use its Streamable HTTP `url:` or run it over stdio.
- **It took too long.** All servers together get `concurrency.mcp_timeout` seconds (120 by default) to connect; stragglers fail with `global connection timeout (120s)`.

`aia --mcp-list` shows what is configured; `aia --mcp-list --list-tools` connects to each server and lists its tools. See [MCP Servers](../extending/mcp.md).

### `WARNING: --mcp-use specified server(s) not found in config: …`

A name given to `--mcp-use` doesn't match any configured server. The next line lists the available names.

### `Warning: MCP config file not found: …` / `Warning: Invalid JSON in MCP config file …`

The file given to `--mcp` is missing or isn't valid JSON. aia skips it and carries on.

### The model never uses my tool

- Run `aia --list-tools` with the same `--tools` / `--require` options to confirm the tool loads.
- Check `--allowed-tools` and `--rejected-tools` (or `tools.allowed` / `tools.rejected`): they match by substring, so `--rt read` also removes `spreadsheet_reader`.
- The automatic tool filter offers only tools that look relevant to your prompt. Try `--no-auto-tool-filter`, or use `-v` to see which tools were offered on each turn.
- Not every model supports tool calling.

### Tool calls are refused when I run aia from a script

Tools from MCP servers marked `requires_approval:` ask before running. With no terminal to ask on, the default `ask` mode refuses. For unattended runs, decide explicitly with `--tool-approval approve` or `--tool-approval deny`. See [Security](../configuration/security.md#tool-approval).

## Configuration

### My setting isn't taking effect

Work through [Troubleshooting a setting](../configuration/precedence.md#troubleshooting-a-setting). The usual suspects:

- An exported `AIA_*` variable overriding your config file (`env | grep '^AIA_'`).
- A `config/aia.yml` in the current directory.
- A YAML mistake in `~/.config/aia/aia.yml`: if the file can't be parsed aia ignores the whole file.
- A `-c` file, which replaces your personal config entirely.
- A key that has no effect in 2.0.0 — these are marked in [Configuration Keys](config-keys.md).

`aia --dump /tmp/c.yml` shows the configuration aia ends up with.

### An `AIA_*` variable doesn't seem to work

aia converts each value to the setting's type (on/off words, numbers, comma-separated lists). A value that doesn't fit, such as `AIA_LLM__MAX_TOKENS=lots`, is kept as text and may not work. `aia --dump /tmp/c.yml` shows what aia made of it. See [Environment Variables](../configuration/environment.md).

### Can I have per-project settings?

Yes. Put a `config/aia.yml` in the project and run aia from the project's root; it is layered over your personal config. Or keep complete setups in separate files and pick one with `-c`.

### Shell completion doesn't offer my prompts

The completion scripts list `.md` files under `$AIA_PROMPTS__DIR`, or `~/.prompts` when it is unset. They can't read your config file, so if your prompts live somewhere else, export `AIA_PROMPTS__DIR` in your shell — setting `prompts.dir` in the config file isn't enough. See [`--completion`](cli.md#-completion-shell).

## Models and output

### I see `<think>` sections — or I want to see them

Some local models write their reasoning inside `<think>` tags. aia hides it by default; `--thinking` shows it.

### How do I see what a run costs?

`--tokens` shows tokens and elapsed time after each turn, `--cost` adds the price. In chat, `/cost` prints the session so far as CSV.

### Switching models with `/model` kept the old conversation

That's deliberate: the new model is given a summary of the conversation. Use `/clear` after switching if you want a fresh start.

### How do I get debugging information?

```bash
aia --debug --log-to /tmp/aia.log my_prompt
```

`--debug` sets all logs to debug level; `--log-to` collects them in one file. Use `--log-level info` for less detail.

### `migrate_prompts` runs but prints nothing

It reports through Ruby's warning channel, which `RUBYOPT=-W0` silences. Run `RUBYOPT= ruby bin/migrate_prompts --dry-run`. See [Migrating Prompts](../appendix/migrating-prompts.md).

## Getting help

- `aia --help` lists every option; `/help` in chat lists every directive.
- [Report an issue](https://github.com/MadBomber/aia/issues) on GitHub, including `aia --version`, the command you ran and the full message.

## See also

- [Command-Line Options](cli.md)
- [Configuration Keys](config-keys.md)
- [Configuration Precedence](../configuration/precedence.md)
- [Glossary](../appendix/glossary.md)
