# Configuration Keys

Every setting aia understands, section by section, with its type, default, environment variable and command-line option. The defaults shown are the ones built into aia 2.0.0.

Settings are written in YAML in `~/.config/aia/aia.yml` (see [The Config File](../configuration/config-file.md)). In this page a key is written as a dotted path: `llm.temperature` means

```yaml
llm:
  temperature: 0.7
```

The environment variable for a key is `AIA_` followed by the path in capitals, with `__` (two underscores) between levels: `llm.temperature` → `AIA_LLM__TEMPERATURE`. Read [Environment Variables](../configuration/environment.md) before using them for true/false settings.

To see the value of every key as aia will actually use it, run `aia --dump current.yml`.

!!! warning "Keys with no effect in 2.0.0"
    A few keys are still part of the configuration schema but nothing in aia 2.0.0 reads them. They are marked **No effect** below. Setting them does no harm, but don't expect a change.

---

## `llm` — generation parameters

| Key | Type | Default | Env | CLI | Meaning |
|---|---|---|---|---|---|
| `llm.temperature` | float | `0.7` | `AIA_LLM__TEMPERATURE` | `-t` | Randomness of the response. |
| `llm.max_tokens` | integer | `32767` | `AIA_LLM__MAX_TOKENS` | `--max-tokens` | Maximum length of the response. |
| `llm.top_p` | float | unset | `AIA_LLM__TOP_P` | `--top-p` | Nucleus sampling. Left unset because some models reject `temperature` and `top_p` together. |
| `llm.frequency_penalty` | float | `0.0` | `AIA_LLM__FREQUENCY_PENALTY` | `--frequency-penalty` | Penalizes repeated tokens. |
| `llm.presence_penalty` | float | `0.0` | `AIA_LLM__PRESENCE_PENALTY` | `--presence-penalty` | Encourages new topics. |

A prompt's front matter can set `temperature` and `top_p` for that prompt. See [Prompt Files](../prompts/prompt-files.md#front-matter-keys).

## `models` — which model(s) to use

A list. Each entry has a `name` and an optional `role`.

| Key | Type | Default | Env | CLI |
|---|---|---|---|---|
| `models` | list of `{name, role}` | `[{name: gpt-4o-mini}]` | `AIA_MODEL` | `-m`, `--model` |

```yaml
models:
  - name: claude-sonnet-4-6
  - name: ollama/llama3.2      # provider prefix
    role: reviewer             # a file in your roles directory
```

- A `name` can carry a provider prefix (`ollama/llama3.2`, `lms/qwen3`). The prefix is treated as a provider only if aia knows that provider; otherwise the whole string is the model name (as in `meta-llama/llama-4-maverick` on OpenRouter).
- More than one entry runs every prompt on every model. See [Multi-Model & Consensus](../extending/multi-model.md).
- `AIA_MODEL` takes the same comma-separated form as `-m`: `AIA_MODEL=gpt-4o,claude-sonnet-4-6`.

## `prompts` — where prompts, roles and skills come from

| Key | Type | Default | Env | CLI | Meaning |
|---|---|---|---|---|---|
| `prompts.dir` | path | `~/.prompts` | `AIA_PROMPTS__DIR` | `--prompts-dir` | Directory of prompt files. |
| `prompts.extname` | string | `.md` | `AIA_PROMPTS__EXTNAME` | — | File extension of prompt files. |
| `prompts.role` | string | unset | `AIA_PROMPTS__ROLE` | `-r`, `--role` | Role to apply. A role ID or a path to a file. |
| `prompts.roles_prefix` | string | `roles` | `AIA_PROMPTS__ROLES_PREFIX` | `--roles-prefix` | Subdirectory of `prompts.dir` holding role files. |
| `prompts.roles_dir` | path | `~/.prompts/roles` | `AIA_PROMPTS__ROLES_DIR` | — | Directory listed when you pick a role interactively. Keep it consistent with `prompts.dir` + `prompts.roles_prefix`. |
| `prompts.skills` | list | `[]` | — | `-s`, `--skill` | Skills to add to every prompt or chat session. |
| `prompts.system_prompt` | string | unset | `AIA_PROMPTS__SYSTEM_PROMPT` | `--system-prompt` | Prompt ID used as the chat system prompt. |
| `prompts.tool` | string | unset | `AIA_PROMPTS__TOOL` | — | **No effect.** |
| `prompts.tools_prefix` | string | `tools` | `AIA_PROMPTS__TOOLS_PREFIX` | — | **No effect.** |

## `roles`

| Key | Type | Default | Env | Meaning |
|---|---|---|---|---|
| `roles.dir` | path | `~/.prompts/roles` | `AIA_ROLES__DIR` | **No effect.** Roles are found under `prompts.dir`/`prompts.roles_prefix`. |

## `skills`

| Key | Type | Default | Env | CLI | Meaning |
|---|---|---|---|---|---|
| `skills.dir` | path | `~/.prompts/skills` | `AIA_SKILLS__DIR` | `--skills-dir` | Directory whose subdirectories are skills. It does **not** follow `prompts.dir`; set it too if you move your prompts. |

## `output` — files aia writes

| Key | Type | Default | Env | CLI | Meaning |
|---|---|---|---|---|---|
| `output.file` | path or `false` | `temp.md` | `AIA_OUTPUT__FILE` | `-o`, `--no-output` | Where responses (and, in chat, your messages) are written as well as shown. `false` turns it off. |
| `output.append` | boolean | `false` | `AIA_OUTPUT__APPEND` | `-a`, `--append` | Add to `output.file` instead of emptying it at the start of a session. |
| `output.markdown` | boolean | `true` | `AIA_OUTPUT__MARKDOWN` | `--md` | **No effect.** |
| `output.history_file` | path | `~/.prompts/_prompts.log` | `AIA_OUTPUT__HISTORY_FILE` | `--history-file`, `--no-history-file` | Chat input history (up-arrow recall). Rotated to `<file>.1` past 10 MB. |

## `audio` — speech

| Key | Type | Default | Env | CLI | Meaning |
|---|---|---|---|---|---|
| `audio.voice` | string | unset | `AIA_AUDIO__VOICE` | `--voice` | Voice name, passed to `say -v`. |
| `audio.speak_command` | string | `say` | `AIA_AUDIO__SPEAK_COMMAND` | `--speak-command` | Program that speaks responses. Other than `say`, it is called as `CMD TEXT OUTFILE` and the resulting file is played with `afplay`. |
| `audio.speech_model` | string | unset | `AIA_AUDIO__SPEECH_MODEL` | `--speech-model` | Passed to the speak command as `$SPEECH_MODEL`. |
| `audio.transcription_model` | string | unset | `AIA_AUDIO__TRANSCRIPTION_MODEL` | `--transcription-model` | Speech-to-text model for the session. |

Turning speech on is a flag: `flags.speak`.

## `image` — image generation

| Key | Type | Default | Env | CLI |
|---|---|---|---|---|
| `image.model` | string | `dall-e-3` | `AIA_IMAGE__MODEL` | `--image-model` |
| `image.size` | string | `1024x1024` | `AIA_IMAGE__SIZE` | `--image-size` |
| `image.quality` | string | `standard` | `AIA_IMAGE__QUALITY` | `--image-quality` |
| `image.style` | string | `vivid` | `AIA_IMAGE__STYLE` | `--image-style` |

Turning image generation on is a flag: `flags.paint` (`--paint`). See [Images & Speech](../extending/images-and-speech.md).

## `embedding`

| Key | Type | Default | Env | Meaning |
|---|---|---|---|---|
| `embedding.model` | string | `text-embedding-ada-002` | `AIA_EMBEDDING__MODEL` | **No effect.** |

## `tools` — local tools

| Key | Type | Default | Env | CLI | Meaning |
|---|---|---|---|---|---|
| `tools.paths` | list of paths | `[]` | `AIA_TOOLS__PATHS` | `--tools` | Ruby files to load as tools. In the config file list files, not directories (`--tools` expands directories for you). |
| `tools.allowed` | list | unset (all) | `AIA_TOOLS__ALLOWED` | `--allowed-tools` | Keep only tools whose name contains one of these strings. |
| `tools.rejected` | list | unset | `AIA_TOOLS__REJECTED` | `--rejected-tools` | Drop tools whose name contains one of these strings. |
| `tools.approval` | `ask` \| `approve` \| `deny` | `ask` | `AIA_TOOLS__APPROVAL` | `--tool-approval` | How to handle tool calls that need approval and MCP input requests. See [Security](../configuration/security.md#tool-approval). |
| `tools.dir` | path | `~/.prompts/tools` | `AIA_TOOLS__DIR` | — | **No effect.** Use `tools.paths` or `--tools`. |

!!! note
    In an environment variable, separate list items with commas: `AIA_TOOLS__ALLOWED=read,write`, `AIA_TOOLS__PATHS=~/tools/a.rb,~/tools/b.rb`.

## `flags` — on/off switches

| Key | Default | Env | CLI | Meaning |
|---|---|---|---|---|
| `flags.chat` | `false` | `AIA_FLAGS__CHAT` | `--chat` | Start a chat session. |
| `flags.cost` | `false` | `AIA_FLAGS__COST` | `--cost` | Show cost per turn. |
| `flags.debug` | `false` | `AIA_FLAGS__DEBUG` | `-d`, `--debug` | Debug output. |
| `flags.verbose` | `false` | `AIA_FLAGS__VERBOSE` | `-v` | Extra detail. |
| `flags.fuzzy` | `false` | `AIA_FLAGS__FUZZY` | `-f` | Choose the prompt with fzf. |
| `flags.tokens` | `false` | `AIA_FLAGS__TOKENS` | `--tokens` | Show tokens and elapsed time per turn. |
| `flags.no_mcp` | `false` | `AIA_FLAGS__NO_MCP` | `--no-mcp` | Don't connect to MCP servers. |
| `flags.speak` | `false` | `AIA_FLAGS__SPEAK` | `--speak` | Speak responses. |
| `flags.shell` | `true` | `AIA_FLAGS__SHELL` | — | Expand `$(...)` and `$VAR` in prompts. A prompt's `shell:` front matter overrides it. |
| `flags.erb` | `true` | `AIA_FLAGS__ERB` | — | Render ERB (`<%= %>`) in prompts. A prompt's `erb:` front matter overrides it. |
| `flags.clear` | `false` | `AIA_FLAGS__CLEAR` | — | **No effect.** Use the `/clear` directive. |
| `flags.consensus` | `false` | `AIA_FLAGS__CONSENSUS` | `--consensus` | Merge multi-model answers into one. |
| `flags.track_pipeline` | `false` | `AIA_FLAGS__TRACK_PIPELINE` | `--track-pipeline` | Track pipelines in TrakFlow. |
| `flags.expert_routing` | `false` | `AIA_FLAGS__EXPERT_ROUTING` | `--expert-routing` | **No effect.** |
| `flags.auto_tool_filter` | `true` | `AIA_FLAGS__AUTO_TOOL_FILTER` | `-A`, `--[no-]auto-tool-filter` | Offer only tools relevant to the prompt. |
| `flags.tool_filter_load` | `false` | `AIA_FLAGS__TOOL_FILTER_LOAD` | `--load` | **No effect.** |
| `flags.tool_filter_save` | `false` | `AIA_FLAGS__TOOL_FILTER_SAVE` | `--save` | **No effect.** |
| `flags.allow_ruby_eval` | `false` | `AIA_FLAGS__ALLOW_RUBY_EVAL` | `--allow-ruby-eval` | Enable the `/ruby` directive. |
| `flags.paint` | `false` | `AIA_FLAGS__PAINT` | `--paint` | Generate images instead of text. |
| `flags.thinking` | `false` | `AIA_FLAGS__THINKING` | `--[no-]thinking` | Show `<think>` reasoning blocks. |

## `tool_filter`

| Key | Type | Default | Env | Meaning |
|---|---|---|---|---|
| `tool_filter.timeout_s` | number | `10` | `AIA_TOOL_FILTER__TIMEOUT_S` | Seconds the chat tool filter may take per turn before it is skipped. |

## `logger` — log destinations and levels {#logger}

aia keeps three logs: `aia` (aia itself), `llm` (requests to the model) and `mcp` (MCP connections).

| Key | Type | Default | Env |
|---|---|---|---|
| `logger.aia.file` | `STDOUT`, `STDERR` or a path | `STDOUT` | `AIA_LOGGER__AIA__FILE` |
| `logger.aia.level` | `debug` … `fatal` | `warn` | `AIA_LOGGER__AIA__LEVEL` |
| `logger.aia.flush` | boolean | `true` | `AIA_LOGGER__AIA__FLUSH` |
| `logger.llm.file` | as above | `STDOUT` | `AIA_LOGGER__LLM__FILE` |
| `logger.llm.level` | as above | `warn` | `AIA_LOGGER__LLM__LEVEL` |
| `logger.llm.flush` | boolean | `true` | `AIA_LOGGER__LLM__FLUSH` |
| `logger.mcp.file` | as above | `STDOUT` | `AIA_LOGGER__MCP__FILE` |
| `logger.mcp.level` | as above | `warn` | `AIA_LOGGER__MCP__LEVEL` |
| `logger.mcp.flush` | boolean | `true` | `AIA_LOGGER__MCP__FLUSH` |

`--log-level` and `--log-to` override the level and file of all three at once. `flush: true` writes each entry immediately.

```yaml
logger:
  llm:
    file: ~/.config/aia/logs/llm.log
    level: info
```

## `pipeline`

| Key | Type | Default | Env | CLI |
|---|---|---|---|---|
| `pipeline` | list of prompt IDs | `[]` | `AIA_PIPELINE` | `-p`, `-n` |

Prompts to run in order. Usually given on the command line or in a prompt's front matter (`next:` / `pipeline:`). See [Pipelines](../prompts/pipelines.md).

## `registry`

| Key | Type | Default | Env | CLI | Meaning |
|---|---|---|---|---|---|
| `registry.refresh` | integer (days) | `7` | `AIA_REGISTRY__REFRESH` | `--refresh` | **No effect.** |

## `require_libs`

| Key | Type | Default | Env | CLI |
|---|---|---|---|---|
| `require_libs` | list of gem/library names | `[]` | `AIA_REQUIRE_LIBS` (comma-separated) | `--rq`, `--require` |

Libraries loaded at startup — tool gems such as `shared_tools`, provider gems, or code your prompts use.

## `mcp_servers`, `mcp_use`, `mcp_skip`

| Key | Type | Default | Env | CLI |
|---|---|---|---|---|
| `mcp_servers` | list of server definitions | `[]` | — | `--mcp FILE` adds to it |
| `mcp_use` | list of server names | unset (all) | `AIA_MCP_USE` (comma-separated) | `--mu`, `--mcp-use` |
| `mcp_skip` | list of server names | unset | `AIA_MCP_SKIP` (comma-separated) | `--ms`, `--mcp-skip` |

```yaml
mcp_servers:
  - name: filesystem
    command: npx
    args: ["-y", "@modelcontextprotocol/server-filesystem", "~/projects"]
  - name: docs
    url: https://mcp.example.com/mcp
    requires_approval: true
```

Each server has a `name` and either a `command` (with `args`, `env`) for a local stdio server or a `url` (with `headers` or `bearer_token`) for a Streamable HTTP server. Optional keys include `prefix`, `only`, `except`, `requires_approval`, `description` and `timeout`. All of them are explained in [MCP Servers](../extending/mcp.md).

## `paths`

| Key | Type | Default | Env | CLI | Meaning |
|---|---|---|---|---|---|
| `paths.aia_dir` | path | `~/.config/aia` | `AIA_PATHS__AIA_DIR` | — | aia's own directory. Chat history falls back to `<aia_dir>/chat_history` when `output.history_file` is unset. |
| `paths.config_file` | path | `~/.config/aia/aia.yml` | `AIA_PATHS__CONFIG_FILE` | — | **No effect.** The personal config file is always found by its standard location; use `-c` for another file. |
| `paths.plugins_dir` | path | unset | `AIA_PLUGINS_DIR` | `--plugins-dir` | Directory of Ruby plugin files. See [Plugins](../prompts/plugins.md). |

## `model_aliases`, `model_switch_history`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `model_aliases` | map | `{}` | Extra short names for `/model`, e.g. `writer: claude-sonnet-4-5`. Added to the built-in aliases (`sonnet`, `haiku`, `gpt4o`, `cheap`, `fast` …). |
| `model_switch_history` | `clean` \| `replay` \| `summarize` | `summarize` | What the new model gets when you switch models: a summary, every message re-sent, or nothing. Env: `AIA_MODEL_SWITCH_HISTORY`. |

## `concurrency` — parallel MCP servers

| Key | Type | Default | Env | CLI | Meaning |
|---|---|---|---|---|---|
| `concurrency.auto` | boolean | `false` | `AIA_CONCURRENCY__AUTO` | `--concurrent-auto` | Run independent MCP servers in parallel on every turn. |
| `concurrency.threshold` | integer | `2` | `AIA_CONCURRENCY__THRESHOLD` | — | Minimum number of independent server groups before running them in parallel. |
| `concurrency.mcp_timeout` | integer (seconds) | `120` | `AIA_CONCURRENCY__MCP_TIMEOUT` | — | Overall time allowed for connecting to all MCP servers at startup. Servers not connected by then are reported as failed and left out. |
| `concurrency.independent_servers` | list | `[]` | `AIA_CONCURRENCY__INDEPENDENT_SERVERS` | — | **No effect.** Every MCP server is treated as independent unless it shares a `group:` value with other servers in its definition. |

## `context_files`

| Key | Type | Default | Env |
|---|---|---|---|
| `context_files` | list of paths | `[]` | `AIA_CONTEXT_FILES` |

The context files for the run. aia fills it from the file names on the command line; anything you put here is sent in addition.

## `service`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `service.name` | string | `aia` | Internal identifier. Leave it alone. |

---

## Front matter vs. config keys

A prompt's YAML front matter can change configuration for the run. The short forms `model`, `temperature`, `top_p`, `next`, `pipeline`, `shell` and `erb` sit at the top level; anything else goes under a `config:` section using the same section names as this page:


```yaml
---
config:
  output:
    file: review.md
  flags:
    tokens: true
---
```

Setting the same thing both ways (say `temperature:` and `config.llm.temperature:`) is an error, as is using both `next:` and `pipeline:`. See [Prompt Files](../prompts/prompt-files.md).

## See also

- [The Config File](../configuration/config-file.md)
- [Environment Variables](../configuration/environment.md)
- [Configuration Precedence](../configuration/precedence.md)
- [Command-Line Options](cli.md)
