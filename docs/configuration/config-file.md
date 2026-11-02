# The Config File

Your personal configuration lives in one YAML file, `~/.config/aia/aia.yml`. Anything you set there becomes your default for every run, so you stop retyping the same options.

## Where aia looks

aia does not create a config file for you. It uses the first of these that exists:

1. `$XDG_CONFIG_HOME/aia/aia.yml`, if `XDG_CONFIG_HOME` is set
2. `~/.config/aia/aia.yml`
3. `~/Library/Application Support/aia/aia.yml` (macOS only)

It also reads **`./config/aia.yml` in the current directory**, if there is one. That file sits on top of your personal one, so a project can carry its own model, prompts directory or MCP servers. See [Configuration Precedence](precedence.md).

## Your first config file

Create the file with only the settings you want to change. Everything you leave out keeps its built-in default.

```bash
mkdir -p ~/.config/aia
$EDITOR ~/.config/aia/aia.yml
```

```yaml
# ~/.config/aia/aia.yml
models:
  - name: claude-sonnet-4-6

llm:
  temperature: 0.5

output:
  file: false      # don't leave a temp.md behind after every run
```

Check that aia picked it up:

```console
$ aia --dump /tmp/now.yml && grep -A3 '^models' /tmp/now.yml
Config successfully dumped to /tmp/now.yml
models:
- :name: claude-sonnet-4-6
  :role:
  :instance: 1
```

!!! tip "YAML gotchas"
    - Indent with spaces, never tabs.
    - `~` on its own means *null*, and a null in your config file is ignored — the built-in default stays. To switch something off, use `false`. (`~/notes` is still a path in your home directory.)
    - Quote values that YAML would otherwise reinterpret, such as `"yes"`, `"no"`, `"on"` or `"1.10"`.
    - If the file can't be parsed, aia carries on **without it** (printing a `MywayConfig: Failed to parse XDG config` warning, unless Ruby warnings are switched off), so a typo can quietly put you back on the defaults. Run `aia --dump` after editing.

## How the file is organized

The file uses the same sections as the built-in defaults. You can use as many or as few as you like:

| Section | What it controls |
|---|---|
| `models` | Which model or models answer. |
| `llm` | Temperature, max tokens and other generation parameters. |
| `prompts` | Where prompts and roles live; default role, skills and chat system prompt. |
| `skills` | Where skills live. |
| `output` | The response file, appending, chat input history. |
| `audio` | Speech: voice, speak command, speech and transcription models. |
| `image` | Image generation model, size, quality, style. |
| `tools` | Tool files to load, allow/reject lists, tool-call approval. |
| `flags` | On/off switches: chat, tokens, cost, speak, debug … |
| `logger` | Where the aia, LLM and MCP logs go and how detailed they are. |
| `mcp_servers` | MCP servers to connect to. |
| `concurrency` | Running MCP servers in parallel. |
| `paths` | aia's own directory and the plugins directory. |
| `require_libs` | Ruby libraries to load at startup. |

Every key, with its type and default, is in [Configuration Keys](../reference/config-keys.md).

## Recipes

### Use a different model by default

```yaml
models:
  - name: claude-haiku-4-5
```

Several entries run every prompt on every model:

```yaml
models:
  - name: gpt-4o
  - name: claude-sonnet-4-6
flags:
  consensus: true     # merge their answers into one
```

### Run local models

```yaml
models:
  - name: ollama/llama3.2
```

See [Local Models](../extending/local-models.md).

### Keep prompts in a project or a synced folder

```yaml
prompts:
  dir: ~/Dropbox/prompts
  roles_dir: ~/Dropbox/prompts/roles
skills:
  dir: ~/Dropbox/prompts/skills
```

`skills.dir` and `prompts.roles_dir` don't follow `prompts.dir` automatically. Also export `AIA_PROMPTS__DIR` so shell completion finds the same place, since the completion scripts can't read the config file and otherwise look in `~/.prompts` (see [Environment Variables](environment.md)).

### Always show tokens and cost

```yaml
flags:
  cost: true
  tokens: true
```

### Keep a running log of every answer

```yaml
output:
  file: ~/notes/aia_answers.md
  append: true
```

### Load your tools every time

```yaml
require_libs:
  - shared_tools
tools:
  paths:
    - ~/.config/aia/tools/weather_tool.rb
    - ~/.config/aia/tools/jira_tool.rb
  rejected:
    - delete
```

List individual `.rb` files under `tools.paths`; only `--tools` on the command line expands a directory. See [Tools](../extending/tools.md).

### Connect MCP servers

```yaml
mcp_servers:
  - name: filesystem
    command: npx
    args: ["-y", "@modelcontextprotocol/server-filesystem", "~/projects"]
```

See [MCP Servers](../extending/mcp.md) for every server option.

### Quieter or louder logs

```yaml
logger:
  aia:
    level: info
  llm:
    file: ~/.config/aia/logs/llm.log
    level: debug
```

## Alternate config files with `-c`

`-c FILE` (`--config-file FILE`) runs aia with a different config file **instead of** your personal one. Useful for switching between setups:

```bash
aia -c ~/.config/aia/local.yml --chat      # everything local
aia -c ~/.config/aia/work.yml standup      # work models and MCP servers
```

With `-c`, aia starts from its built-in defaults and applies only `FILE` and your command-line options. It ignores `~/.config/aia/aia.yml`, `./config/aia.yml` and the `AIA_*` environment variables — except `AIA_MODEL` and `AIA_PLUGINS_DIR`, which still apply. A missing file stops aia:

```console
$ aia -c ~/.config/aia/wrok.yml standup
ERROR: Config file not found: /Users/you/.config/aia/wrok.yml
```

## See what aia is using {#see-what-aia-is-using}

`--dump FILE` writes the complete, final configuration — defaults, files, environment and the other options on the same command line — and exits without running anything:

```bash
aia --dump /tmp/now.yml
aia -m gpt-4o -t 0.1 --dump /tmp/with_flags.yml   # include command-line options
```

The file must end in `.yml` or `.yaml`. In the output, keys inside each section are written with a leading colon (`:temperature: 0.7`); that is how YAML writes Ruby symbols and doesn't affect reading it.

Use `--dump` to debug settings, not to create your config file: it records every value, including paths already expanded and defaults you never chose, which then stop following future changes to aia's defaults.

Inside a chat session, `/config` shows the live configuration and `/config KEY VALUE` changes a setting for the rest of the session. See [Directives](../reference/directives.md).

## See also

- [Configuration Precedence](precedence.md)
- [Environment Variables](environment.md)
- [Configuration Keys](../reference/config-keys.md)
- [Security](security.md)
