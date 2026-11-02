# Command-Line Options

This page lists every option `aia` accepts, grouped the way `aia --help` groups them. For each one you get what it does, its default, the configuration key and environment variable that set the same thing, and an example.

## Synopsis

```text
aia [options] [PROMPT_ID] [CONTEXT_FILE]*
aia [options] --chat [PROMPT_ID] [CONTEXT_FILE]*
```

- **`PROMPT_ID`** is the name of a prompt file in your prompts directory, without the `.md` extension. `aia code_review` runs `~/.prompts/code_review.md`; `aia dev/code_review` runs `~/.prompts/dev/code_review.md`.
- **`CONTEXT_FILE`** is any number of files whose contents are sent along with the prompt.
- If the first argument is not a prompt ID, aia treats it as a context file. If that file starts with a `#!` line, aia runs it as an [executable prompt](../prompts/executable-prompts.md).
- Text piped on standard input is added to the prompt. With no prompt ID, piped text *is* the prompt.

You need a prompt ID unless you use `--chat`, `--fuzzy`, `--pipeline` (its first prompt runs first) or `--role` (the role file runs as the prompt), pipe the prompt in, or run an executable prompt. Context files on their own are not enough:

```console
$ aia
A prompt ID is required unless you use --chat, --fuzzy, --pipeline or --role, pipe the prompt in, or run an executable prompt. Context files alone are not a prompt. Use -h or --help for help.
```

!!! note "Option values"
    An option that takes a list (`--pipeline`, `--skill`, `--tools`, `--allowed-tools`, `--mcp-use` …) takes it comma-separated, with no spaces unless you quote it. Options that add to a list (`-m`, `-s`, `-n`, `-p`, `--rq`, `--at`, `--rt`, `--mcp`, `--mu`, `--ms`) can be repeated.

!!! info "Reading the tables"
    **Config key** is the dotted path in `~/.config/aia/aia.yml` (see [Configuration Keys](config-keys.md)). **Env** is the matching environment variable (see [Environment Variables](../configuration/environment.md)). A dash means the option has no persistent equivalent.

---

## Mode Options

### `--chat`

Start an interactive chat session. If you also give a prompt ID (or a pipeline), aia runs it first and then keeps the conversation open. See [Chat Sessions](../everyday/chat.md).

| Default | Config key | Env |
|---|---|---|
| off | `flags.chat` | `AIA_FLAGS__CHAT` |

```bash
aia --chat
aia --chat code_review lib/parser.rb
```

### `-f`, `--fuzzy`

Pick the prompt interactively with [fzf](https://github.com/junegunn/fzf). aia stops immediately if `fzf` is not installed:

```console
$ aia --fuzzy
Error: 'fzf' is not installed. Please install 'fzf' to use the --fuzzy option.
```

| Default | Config key | Env |
|---|---|---|
| off | `flags.fuzzy` | `AIA_FLAGS__FUZZY` |

```bash
aia -f
aia --fuzzy --chat
```

### `--track-pipeline`

Record each step of a pipeline as a task in [TrakFlow](../extending/advanced-modes.md). It only takes effect when the current directory holds an initialized TrakFlow project; otherwise the pipeline runs untracked.

| Default | Config key | Env |
|---|---|---|
| off | `flags.track_pipeline` | `AIA_FLAGS__TRACK_PIPELINE` |

```bash
aia --track-pipeline research -p outline,draft
```

### `--concurrent-auto`

Run MCP servers that can work independently of each other in parallel, without asking for it turn by turn (the per-turn form is the `/concurrent` directive). Parallelism kicks in only when there are at least `concurrency.threshold` independent groups (default 2). See [MCP Servers](../extending/mcp.md).

| Default | Config key | Env |
|---|---|---|
| off | `concurrency.auto` | `AIA_CONCURRENCY__AUTO` |

### `-A`, `--[no-]auto-tool-filter`

Before each turn, offer the model only the tools whose descriptions are similar to your prompt (TF-IDF similarity). Turn it off with `--no-auto-tool-filter` to offer every loaded tool on every turn.

| Default | Config key | Env |
|---|---|---|
| on | `flags.auto_tool_filter` | `AIA_FLAGS__AUTO_TOOL_FILTER` |

```bash
aia --chat --no-auto-tool-filter --tools ~/my_tools
```

---

## Model Options

### `--available-models [QUERY]`

Search the model registry and exit. With no query it lists every known model. The query is comma-separated; every term must match. A term containing `_to_` filters by modality (`text_to_image`, `audio_to_text` …); any other term must appear in the model's line.

```console
$ aia --available-models claude-haiku
Available LLMs for claude-haiku:

- claude-haiku-4-5 (anthropic) text,image,pdf to text
- claude-haiku-4-5-20251001 (anthropic) text,image,pdf to text
...
```

```bash
aia --available-models anthropic,text_to_text
aia --available-models text_to_image
```

This option exits as soon as it is parsed, so put it last if you combine it with other options.

### `--provider SLUG`

The provider to use for model names given without a `provider/` prefix. It also selects the provider for `--list-models`. A model written with an explicit prefix (`ollama/llama3.2`) keeps its own provider. Run `aia --list-providers` to see the valid slugs.

| Default | Config key | Env |
|---|---|---|
| none (the model registry decides) | — | — |

```bash
aia --provider ollama -m llama3.2 my_prompt
aia --provider lms --list-models
```

### `--list-models`

List the models a provider is serving right now (it asks the provider, so a local server must be running) and exit. Requires `--provider`.

```console
$ aia --list-models
ERROR: --list-models requires --provider SLUG (use --available-models to search the full model registry)
```

```bash
aia --provider ollama --list-models
```

### `--list-providers`

List every provider aia can use and exit. Each line notes `(local)` for providers that run on your machine and `(has API key)` when a key for it is set.

```console
$ aia --list-providers

Registered RubyLLM providers:
------------------------------------------------------------
- anthropic
- gemini (has API key)
- ollama (local)
- openai
...

21 provider(s) registered
```

Provider gems named `ruby_llm-providers-<slug>` that are installed are loaded automatically and appear here. Libraries named with `--require` are loaded first, so a provider they register is listed too.

### `-m`, `--model MODEL`

The model, or models, to use. Format: `MODEL[=ROLE][,MODEL[=ROLE]]...`

- One model: `-m claude-haiku-4-5`
- With an explicit provider: `-m ollama/llama3.2`
- Several models run the same prompt in parallel: `-m gpt-4o,claude-sonnet-4-6`. See [Multi-Model & Consensus](../extending/multi-model.md).
- `=ROLE` gives that model its own [role](../everyday/roles-and-skills.md): `-m gpt-4o=architect,claude-sonnet-4-6=reviewer`. The role file must exist, or aia stops with `ERROR: Role file not found` and lists the roles it found.
- The same model can appear more than once, with different roles.

| Default | Config key | Env |
|---|---|---|
| `gpt-4o-mini` | `models` | `AIA_MODEL` (comma-separated) |

```bash
aia -m claude-sonnet-4-6 summarize report.pdf
aia -m gpt-4o=optimist,gpt-4o=pessimist --consensus forecast
```

### `--[no-]consensus`

With several models, have one more pass merge their answers into a single response instead of showing each answer separately.

| Default | Config key | Env |
|---|---|---|
| off | `flags.consensus` | `AIA_FLAGS__CONSENSUS` |

```bash
aia -m gpt-4o,claude-sonnet-4-6,gemini-2.5-pro --consensus architecture_question
```

### `--list-roles`

List the role files in your roles directory, with each role's front matter, and exit. Hidden files and directories whose names start with `_` are skipped.

```bash
aia --list-roles
```

### `--sm`, `--speech-model MODEL`

The text-to-speech model. aia passes it to your speak command as the `SPEECH_MODEL` environment variable. See [Images & Speech](../extending/images-and-speech.md).

| Default | Config key | Env |
|---|---|---|
| none | `audio.speech_model` | `AIA_AUDIO__SPEECH_MODEL` |

### `--tm`, `--transcription-model MODEL`

The speech-to-text model used for the whole session.

| Default | Config key | Env |
|---|---|---|
| none (provider default) | `audio.transcription_model` | `AIA_AUDIO__TRANSCRIPTION_MODEL` |

---

## File & Output Options

### `-c`, `--config-file FILE`

Load settings from `FILE` **instead of** your personal configuration. When you use it, aia starts from its built-in defaults, applies `FILE`, then your command-line options — `~/.config/aia/aia.yml`, a project `./config/aia.yml` and `AIA_*` environment variables are not used. (`AIA_MODEL` and `AIA_PLUGINS_DIR` are the exceptions; they still apply.) See [Configuration Precedence](../configuration/precedence.md).

```console
$ aia -c missing.yml my_prompt
ERROR: Config file not found: /home/you/missing.yml
```

```bash
aia -c ~/configs/local-ollama.yml --chat
```

### `-o`, `--[no-]output [FILE]`

Where the response is written, in addition to the terminal. Given without a file name, it means `temp.md`. A relative path is relative to the current directory. `--no-output` turns file output off.

| Default | Config key | Env |
|---|---|---|
| `temp.md` | `output.file` | `AIA_OUTPUT__FILE` |

```bash
aia -o review.md code_review lib/app.rb
aia --no-output quick_question
```

!!! tip
    Because the default is `temp.md`, every run leaves a `temp.md` in your current directory. Set `output.file: false` in your config file, or pass `--no-output`, if you don't want that. (`output.file: ~` does not work: a null in your config file is ignored and the default stays.)

### `-a`, `--[no-]append`

Add each response to the end of the output file instead of replacing it. Without it, aia empties the output file at the start of a session.

| Default | Config key | Env |
|---|---|---|
| off | `output.append` | `AIA_OUTPUT__APPEND` |

```bash
aia -a -o journal.md daily_reflection
```

### `--[no-]history-file [FILE]`

The file that holds the lines you type at the chat prompt, so the up-arrow recalls earlier input across sessions (the last 50 lines are loaded). When it grows past 10 MB aia renames it to `FILE.1` and starts a new one. `--no-history-file` turns chat input history off.

| Default | Config key | Env |
|---|---|---|
| `~/.prompts/_prompts.log` | `output.history_file` | `AIA_OUTPUT__HISTORY_FILE` |

```bash
aia --chat --history-file ~/.config/aia/chat_history
aia --chat --no-history-file
```

---

## Prompt Options

### `--prompts-dir DIR`

The directory that holds your prompt files.

| Default | Config key | Env |
|---|---|---|
| `~/.prompts` | `prompts.dir` | `AIA_PROMPTS__DIR` |

```bash
aia --prompts-dir ./prompts release_notes
```

### `--plugins-dir DIR`

A directory of Ruby plugin files. Every `*.rb` file directly inside it is loaded at startup; during a chat session aia watches the directory and reloads a plugin when you add, change or delete it. aia warns if the directory does not exist. See [Plugins](../prompts/plugins.md).

| Default | Config key | Env |
|---|---|---|
| none | `paths.plugins_dir` | `AIA_PLUGINS_DIR` |

```bash
aia --chat --plugins-dir ~/.config/aia/plugins
```

### `--roles-prefix PREFIX`

The subdirectory of the prompts directory that holds role files.

| Default | Config key | Env |
|---|---|---|
| `roles` | `prompts.roles_prefix` | `AIA_PROMPTS__ROLES_PREFIX` |

### `-r`, `--role ROLE_ID`

Put a role in front of the prompt. `ROLE_ID` is a file in the roles directory (`-r ruby_expert` reads `~/.prompts/roles/ruby_expert.md`) or a path to a file (`-r ./roles/reviewer.md`). With `--chat`, the role becomes part of the session's system prompt. Outside chat you still need a prompt ID: `aia -r tutor` on its own stops with `A prompt ID is required …`. See [Roles & Skills](../everyday/roles-and-skills.md).

| Default | Config key | Env |
|---|---|---|
| none | `prompts.role` | `AIA_PROMPTS__ROLE` |

```bash
aia -r ruby_expert code_review app/models/user.rb
aia --chat -r tutor
```

### `--skills-dir DIR`

The directory whose subdirectories are skills (each one holds a `SKILL.md`).

| Default | Config key | Env |
|---|---|---|
| `~/.prompts/skills` | `skills.dir` | `AIA_SKILLS__DIR` |

### `-s`, `--skill SKILL_IDS`

Add one or more skills, comma-separated, by name or by path. In chat mode the skills are added to the system prompt once, for the whole session. When running prompts, they are added to each prompt. See [Roles & Skills](../everyday/roles-and-skills.md).

| Default | Config key | Env |
|---|---|---|
| none | `prompts.skills` | — |

```bash
aia --chat -s code_review,security_audit
aia -s ./skills/house_style summarize notes.md
```

### `--list-skills`

List the skills in the skills directory and exit.

```bash
aia --list-skills
aia --skills-dir ./team_skills --list-skills
```

### `-n`, `--next PROMPT_ID`

Run `PROMPT_ID` after the current prompt. Pipeline prompts share one conversation, so each one sees the prompts and responses before it. Repeat `-n` to chain more. See [Pipelines](../prompts/pipelines.md).

| Default | Config key | Env |
|---|---|---|
| none | `pipeline` | `AIA_PIPELINE` (comma-separated) |

```bash
aia extract_facts report.pdf -n summarize -n translate_es
```

### `-p`, `--pipeline PROMPTS`

Run a comma-separated list of prompts in order. The prompt ID you give on the command line runs first; you need one unless you also use `--chat`. Every prompt in the list must exist before anything runs:

```console
$ aia research -p outline,draftt
Error: Prompt ID 'draftt' does not exist at /home/you/.prompts/draftt.md
One or more prompt IDs do not exist.
```

| Default | Config key | Env |
|---|---|---|
| `[]` | `pipeline` | `AIA_PIPELINE` (comma-separated) |

```bash
aia research -p outline,draft topic_notes.md
```

### `--system-prompt TEXT`

Use `TEXT` as the system prompt, in chat and in one-shot runs. The value is literal text; aia doesn't look up a prompt file. A role (`--role`) is added after it.

```bash
aia --system-prompt "Answer in one short paragraph." my_prompt
```

| Default | Config key | Env |
|---|---|---|
| none | `prompts.system_prompt` | `AIA_PROMPTS__SYSTEM_PROMPT` |

```bash
aia --chat --system-prompt house_rules
```

---

## Generation Parameters

These are passed to the model. Not every model honors every one.

### `-t`, `--temperature TEMP`

Randomness of the output; lower is more focused, higher more varied. Must be a number.

| Default | Config key | Env |
|---|---|---|
| `0.7` | `llm.temperature` | `AIA_LLM__TEMPERATURE` |

```bash
aia -t 0.2 extract_dates contract.txt
```

### `--max-tokens TOKENS`

Upper limit on the length of the response, in tokens. Must be an integer.

| Default | Config key | Env |
|---|---|---|
| `32767` | `llm.max_tokens` | `AIA_LLM__MAX_TOKENS` |

### `--top-p VALUE`

Nucleus sampling. Unset by default, because some models reject a request that sets both `temperature` and `top_p`.

| Default | Config key | Env |
|---|---|---|
| unset | `llm.top_p` | `AIA_LLM__TOP_P` |

### `--frequency-penalty VALUE`

Discourages repeating the same tokens.

| Default | Config key | Env |
|---|---|---|
| `0.0` | `llm.frequency_penalty` | `AIA_LLM__FREQUENCY_PENALTY` |

### `--presence-penalty VALUE`

Encourages moving on to new topics.

| Default | Config key | Env |
|---|---|---|
| `0.0` | `llm.presence_penalty` | `AIA_LLM__PRESENCE_PENALTY` |

A value that is not a number stops aia with an `invalid argument` error, for example `invalid argument: -t hot`.

---

## Audio & Image Options

See [Images & Speech](../extending/images-and-speech.md) for walkthroughs.

### `--speak`

Speak each response aloud after it is shown: every reply in a chat, the reply to a one-shot prompt, and each step of a pipeline. `--paint` results aren't spoken. See [Images & Speech](../extending/images-and-speech.md).

| Default | Config key | Env |
|---|---|---|
| off | `flags.speak` | `AIA_FLAGS__SPEAK` |

```bash
aia --speak --chat
```

### `--voice VOICE`

The voice. With the default speak command (`say`), it is passed as `say -v VOICE`.

| Default | Config key | Env |
|---|---|---|
| none | `audio.voice` | `AIA_AUDIO__VOICE` |

```bash
aia --speak --voice Samantha daily_briefing
```

### `--speak-command CMD`

The program that speaks. With `say`, aia calls `say [-v VOICE] TEXT`. Any other command is called as `CMD TEXT OUTFILE`; it must write an audio file to `OUTFILE`, which aia then plays with your audio player (`audio.player`; see [`config-keys`](config-keys.md)). The speech model is in `$SPEECH_MODEL`.

| Default | Config key | Env |
|---|---|---|
| `say` | `audio.speak_command` | `AIA_AUDIO__SPEAK_COMMAND` |

```bash
aia --speak --speak-command ~/bin/openai_tts.sh --speech-model tts-1-hd my_prompt
```

### `--paint`

Generate an image from the prompt instead of a text response. The image is saved next to the output file with a `.png` extension; the output file itself isn't written, and nothing is spoken.

| Default | Config key | Env |
|---|---|---|
| off | `flags.paint` | `AIA_FLAGS__PAINT` |

```bash
aia --paint logo_idea
```

### `--im`, `--image-model MODEL`

| Default | Config key | Env |
|---|---|---|
| `gpt-image-1` | `image.model` | `AIA_IMAGE__MODEL` |

### `--is`, `--image-size SIZE`

| Default | Config key | Env |
|---|---|---|
| `1024x1024` | `image.size` | `AIA_IMAGE__SIZE` |

### `--iq`, `--image-quality QUALITY`

| Default | Config key | Env |
|---|---|---|
| `standard` | `image.quality` | `AIA_IMAGE__QUALITY` |

### `--style`, `--image-style STYLE`

| Default | Config key | Env |
|---|---|---|
| `vivid` | `image.style` | `AIA_IMAGE__STYLE` |

```bash
aia --paint --is 1792x1024 --iq hd --style natural landscape
```

---

## Tool & Extension Options

### `--allow-ruby-eval`

Turn on the `/ruby` directive, which runs arbitrary Ruby code with aia's full privileges. Read [Security](../configuration/security.md) first.

| Default | Config key | Env |
|---|---|---|
| off | `flags.allow_ruby_eval` | `AIA_FLAGS__ALLOW_RUBY_EVAL` |

### `--rq`, `--require LIBS`

Ruby libraries (gems) to load at startup, comma-separated. Use it to load tool gems, provider gems, or code your prompts call. A library that can't be loaded produces a warning, not an error.

| Default | Config key | Env |
|---|---|---|
| `[]` | `require_libs` | `AIA_REQUIRE_LIBS` (comma-separated) |

```bash
aia --rq shared_tools --chat
```

### `--tools PATH_LIST`

Load tools from Ruby files. Each entry is a `.rb` file or a directory (every `*.rb` file in it is loaded). aia stops if a path does not exist or a file is not `.rb`:

```console
$ aia --tools README my_prompt
file/dir path is not valid: README
```

| Default | Config key | Env |
|---|---|---|
| `[]` | `tools.paths` | `AIA_TOOLS__PATHS` |

```bash
aia --chat --tools ~/my_tools,./project_tools/deploy_tool.rb
```

See [Tools](../extending/tools.md).

### `--at`, `--allowed-tools TOOLS_LIST`

Offer the model only the tools whose names contain one of these strings (case-insensitive, substring match — `--at file` keeps `read_file`, `write_file` and `file_search`).

| Default | Config key | Env |
|---|---|---|
| all | `tools.allowed` | `AIA_TOOLS__ALLOWED` |

### `--rt`, `--rejected-tools TOOLS_LIST`

Remove the tools whose names contain one of these strings (same matching as `--at`). Rejection is applied after `--at`.

| Default | Config key | Env |
|---|---|---|
| none | `tools.rejected` | `AIA_TOOLS__REJECTED` |

```bash
aia --chat --rq shared_tools --rt delete,shell
```

### `--tool-approval MODE`

What to do with tool calls that need approval (tools from an MCP server marked `requires_approval:`) and with an MCP server's requests for input:

- `ask` — show the tool and its arguments and ask `Allow it? [y/N]` on the terminal. With no terminal attached, the call is refused.
- `approve` — allow them all without asking.
- `deny` — refuse them all.

| Default | Config key | Env |
|---|---|---|
| `ask` | `tools.approval` | `AIA_TOOLS__APPROVAL` |

```bash
aia --tool-approval deny nightly_report
```

Any other value stops aia with `invalid argument: --tool-approval …`.

### `--list-tools`

List the local tools (from `--tools` and `--require`) with their descriptions, after `--allowed-tools` and `--rejected-tools` are applied, and exit. Add `--mcp-list` to connect to each MCP server and list its tools as well. When output is not a terminal, the list is written as Markdown.

```bash
aia --tools ~/my_tools --list-tools
aia --list-tools --mcp-list > tools.md
```

---

## Utility Options

### `--log-level LEVEL`

Set the level of all three logs (aia, LLM, MCP) to `debug`, `info`, `warn`, `error` or `fatal`. `debug` also turns on `--debug`.

```bash
aia --log-level info my_prompt
```

The level for each log can be set separately in the config file; see `logger.*` in [Configuration Keys](config-keys.md#logger).

### `-d`, `--debug`

Debug output: the same as `--log-level debug`. Also shows which tools were offered to the model on each turn.

| Default | Config key | Env |
|---|---|---|
| off | `flags.debug` | `AIA_FLAGS__DEBUG` |

### `--no-debug`

Turn debug output off, overriding a config file or environment setting.

### `--log-to FILE`

Send all three logs to `FILE` instead of their configured destinations.

```bash
aia --debug --log-to /tmp/aia.log --chat
```

### `-v`, `--[no-]verbose`

Print extra detail, such as the list of tools offered to the model on each turn.

| Default | Config key | Env |
|---|---|---|
| off | `flags.verbose` | `AIA_FLAGS__VERBOSE` |

### `--[no-]thinking`

Show the reasoning that some models (for example `qwen3` on Ollama) stream inside `<think>…</think>` tags. By default aia hides it and shows only the answer.

| Default | Config key | Env |
|---|---|---|
| off | `flags.thinking` | `AIA_FLAGS__THINKING` |

### `--tokens`

After each turn, show the tokens used and how long the response took.

| Default | Config key | Env |
|---|---|---|
| off | `flags.tokens` | `AIA_FLAGS__TOKENS` |

### `--cost`

Show the cost of each turn as well as tokens and time. Implies `--tokens`. In chat, `/cost` prints the session's totals as CSV.

| Default | Config key | Env |
|---|---|---|
| off | `flags.cost` | `AIA_FLAGS__COST` |

```bash
aia --cost -m gpt-4o,claude-sonnet-4-6 compare_designs
```

### `--refresh DAYS`

How often, in days, AIA refreshes its list of models. AIA keeps the list in `models.json` in its own directory (`paths.aia_dir`, `~/.config/aia` by default). When a session starts and the file is missing or more than `DAYS` days old, AIA asks the providers you have API keys for and the published RubyLLM catalogue for their current models, and saves the result. `0` turns refreshing off; AIA then uses the saved file if there is one, or the list that comes with RubyLLM. If the refresh fails (for example, offline), AIA warns and carries on with the list it already had.

The chat banner's `DB:` line shows when the list was last refreshed. `/models` searches this list. `--available-models` runs before the session starts, so it searches the list RubyLLM keeps for itself.

```bash
aia --refresh 0 --chat     # never refresh
aia --refresh 1 --chat     # refresh at most once a day
```

| Default | Config key | Env |
|---|---|---|
| `7` | `registry.refresh` | `AIA_REGISTRY__REFRESH` |

### `--dump FILE`

Write the complete configuration aia would run with — after config files, environment variables and the other options on the command line — to `FILE` and exit. `FILE` must end in `.yml` or `.yaml`.

```console
$ aia --dump current.yml
Config successfully dumped to current.yml
```

This is the quickest way to answer "where did that setting come from?". See [The Config File](../configuration/config-file.md#see-what-aia-is-using).

### `--completion SHELL`

Print a tab-completion script for `bash`, `zsh` or `fish` and exit. Any other shell name is an error (exit status 1). The script completes prompt IDs after `aia` by listing the `.md` files under **`$AIA_PROMPTS__DIR`**, or `~/.prompts` when that variable is unset. The script can't read your config file, so if your prompts live elsewhere, export `AIA_PROMPTS__DIR`. Elsewhere on the command line it falls back to ordinary file completion.

=== "bash"

    ```bash
    # ~/.bashrc
    export AIA_PROMPTS__DIR=~/.prompts
    eval "$(aia --completion bash)"
    ```

=== "zsh"

    ```zsh
    # ~/.zshrc
    export AIA_PROMPTS__DIR=~/.prompts
    eval "$(aia --completion zsh)"
    ```

=== "fish"

    ```fish
    # ~/.config/fish/config.fish
    set -gx AIA_PROMPTS__DIR ~/.prompts
    aia --completion fish | source
    ```

```console
$ aia --completion tcsh
ERROR: The shell 'tcsh' is not supported or the completion script is missing.
```

### `--mcp FILE`

Add MCP servers from a JSON file. Repeat it to load several files. The file can describe a single server (named after the file) or hold an `mcpServers` object, the format used by Claude Desktop and other MCP clients. A missing or malformed file produces a warning and is skipped. See [MCP Servers](../extending/mcp.md).

| Default | Config key | Env |
|---|---|---|
| none | adds to `mcp_servers` | — |

```bash
aia --chat --mcp ~/mcp/github.json --mcp ~/mcp/filesystem.json
```

### `--no-mcp`

Don't connect to any MCP server, even ones in your config file.

| Default | Config key | Env |
|---|---|---|
| off | `flags.no_mcp` | `AIA_FLAGS__NO_MCP` |

### `--mcp-list`

List the configured MCP servers (after `--mcp-use` / `--mcp-skip` filtering) and exit. Combine with `--list-tools` to also list each server's tools.

```console
$ aia --mcp-list
Configured MCP servers:

  github
    command: github-mcp-server stdio

  filesystem
    command: npx -y @modelcontextprotocol/server-filesystem /Users/you/projects
```

### `--mu`, `--mcp-use NAMES`

Use only these MCP servers (comma-separated names). aia warns about names that are not configured.

| Default | Config key | Env |
|---|---|---|
| all | `mcp_use` | `AIA_MCP_USE` (comma-separated) |

### `--ms`, `--mcp-skip NAMES`

Use every configured MCP server except these. Ignored when `--mcp-use` is given.

| Default | Config key | Env |
|---|---|---|
| none | `mcp_skip` | `AIA_MCP_SKIP` (comma-separated) |

```bash
aia --chat --mu github
aia --chat --ms slow_db_server
```

### `--version`

Print the version and exit.

```console
$ aia --version
2.0.0
```

### `-h`, `--help`

Print the option summary and exit.

---

## Exit status

aia exits with status `1` for an unknown option, a missing or invalid value (`-t hot`, `--tool-approval maybe`), a `-m MODEL=ROLE` whose role file is missing, a configuration error (such as a missing prompt or config file), or a failed `--list-models`. Each prints a one-line `ERROR:` message.

## See also

- [Configuration Keys](config-keys.md) — every setting, its type and default
- [Environment Variables](../configuration/environment.md)
- [Configuration Precedence](../configuration/precedence.md)
- [Directives](directives.md) — commands you use inside prompts and chat
