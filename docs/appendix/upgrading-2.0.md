# Upgrading to 2.0

aia 2.0 is a rebuild, not a drop-in replacement for 1.x. This page lists what changes for you between 1.1.1, the last 1.x release, and 2.0.0 — work through it before upgrading — followed by a short tour of what's new.

## Requirements

| | 1.1.1 | 2.0.0 |
|---|---|---|
| Ruby | 3.2 or newer | **4.0.9 or newer** |

Install or upgrade with:

```bash
gem install aia
aia --version     # 2.0.0
```

The `ruby_llm-mcp` gem is no longer used, and it cannot be loaded alongside the version of ruby_llm that aia 2.0 needs. If you have it in a `--require` list or a Gemfile next to aia, remove it.

## Removed command-line options

Passing one of these now stops aia with an error and exit status 1:

```console
$ aia --terse my_prompt
ERROR: invalid option: --terse
       use --help for usage report
```

| Removed option | What to do instead |
|---|---|
| `--terse` | Nothing. It had no effect in 1.x. |
| `--regex PATTERN` | Nothing. Parameters are ERB (`<%= name %>`), so a custom placeholder pattern no longer means anything. |
| `--skills-prefix PREFIX` | Point `--skills-dir` at the directory that holds your skill subdirectories. |
| `--md`, `--[no-]markdown` | Nothing. Responses are written as the model returns them. |

Check shell aliases, scripts, cron jobs and executable prompts' `#!` lines for these.

## Configuration file

### Removed keys

These are ignored if they are still in your config file, as are their `AIA_*` environment variables. They don't appear in `aia --dump` either:

| Removed key | Notes |
|---|---|
| `flags.terse` | See `--terse`. |
| `prompts.parameter_regex` | See `--regex`. |
| `prompts.skills_prefix` | See `--skills-prefix`. |
| `output.markdown` | See `--md`. |
| `prompts.roles_dir`, `roles.dir` | Roles are always found in `prompts.dir`/`prompts.roles_prefix`. |
| `prompts.tool`, `prompts.tools_prefix`, `tools.dir` | Load tools with `--tools` or `tools.paths`. |
| `embedding.model` | Nothing used it. |
| `flags.clear` | Use the `/clear` directive. |
| `paths.config_file` | aia finds your config file in its standard place (`~/.config/aia/aia.yml`, or `$XDG_CONFIG_HOME/aia/aia.yml` when that is set); use `-c` for another one. |

### Changed defaults

If you relied on an old default, set it in your config file.

| Key | 1.1.1 default | 2.0.0 default |
|---|---|---|
| `llm.max_tokens` | `2048` | `32767` |
| `llm.top_p` | `1.0` | unset (the provider's default) |
| `audio.speak_command` | `afplay` | `say` |
| `audio.voice` | `alloy` | unset |
| `audio.speech_model` | `tts-1` | unset |
| `audio.transcription_model` | `whisper-1` | unset |

`afplay` plays audio files, not text, so `--speak` didn't work with the old default. The old voice and audio-model defaults only made sense for OpenAI. To keep OpenAI text-to-speech, use a script as your speak command — see [Images & Speech](../extending/images-and-speech.md).

To restore the old response-length cap, for example:

```yaml
llm:
  max_tokens: 2048
```

## Chat directives

- **`/terse` is gone.**
- **`/ruby` is off by default.** It runs any Ruby with aia's full privileges. Start aia with `--allow-ruby-eval` to use it. See [Security](../configuration/security.md).
- **`/model` keeps the conversation.** Switching models now hands the new model a summary of the conversation so far; in 1.x the new model started fresh. Set `model_switch_history: clean` to start fresh as 1.x did, or `replay` to re-send your messages. See [Chat Sessions](../everyday/chat.md#switching-models-mid-conversation).

Every other 1.x directive and alias still works.

## Custom tools

Tool files loaded with `--tools` must use the ruby_llm 2 style of declaring parameters. `param … desc:` is now `parameter … description:`:

```ruby
# 1.x
param :text, desc: "Text to process"

# 2.0
parameter :text, description: "Text to process"
```

A tool still written the 1.x way fails with `NoMethodError` when aia loads it. See [Tools](../extending/tools.md).

## MCP servers

Servers listed under `mcp_servers:` keep working, with three exceptions:

- **The `sse` and `ws` transports are gone.** Use the server's Streamable HTTP endpoint (`url:`) or run it locally over stdio (`command:`). A server still set to `sse` or `ws` is reported as failed at startup.
- **Two servers can't offer a tool with the same name.** The second one fails to connect. Give one of them a `prefix:` so its tool names are distinct.
- **Server classes loaded with `--require` must be `RubyLLM::MCP` subclasses**, and they are no longer picked up automatically. List them by class name under `mcp_servers:` (see [Naming a server class](../extending/mcp.md#naming-a-server-class)).

See [MCP Servers](../extending/mcp.md).

## Files no longer in the gem

The installed gem contains only what aia needs to run. The documentation, the `examples/` directory, the `mcp_servers/` samples and the `bin/migrate_prompts` script are in the [GitHub repository](https://github.com/MadBomber/aia) only.

## If you used a 2.0 pre-release

These existed in the 2.0 alpha and beta releases and were removed before 2.0.0:

- The KBS rule engine, the `/rules` directive, user-defined rule hooks and `--tool-filter-kbs`.
- The zvec, sqlite-vec and LSI tool filters. TF-IDF is the only tool filter; it is on by default and switched with `-A` / `--[no-]auto-tool-filter`. This replaces the `tool_filter_a` setting.

- `--expert-routing` (`flags.expert_routing`), `--load` and `--save` (`flags.tool_filter_load`, `flags.tool_filter_save`), `concurrency.independent_servers`, the MCP server key `independent:`, and switching models by typing "switch to claude". Passing one of these options is now an invalid-option error, and the keys are ignored. Use `/model` to switch models.

`-A` used to mean `--tool-filter-kbs`; it now means `--auto-tool-filter`.

## What's new in 2.0

A quick tour, with where to read more:

- **Any provider ruby_llm supports**, local or hosted. `--provider` sets the default for model names without a prefix, `--list-providers` shows what's available, and `--list-models` asks a provider what it is serving. [Choosing Models](../everyday/models.md), [Local Models](../extending/local-models.md)
- **Crews.** Every chat is a team of robots. Add members with `/add_recruit`, address them with `@name` or `@crew`, and spawn one-shot specialists with `/spawn`. [Crews](../extending/crews.md)
- **Multi-robot modes**: `/verify`, `/debate`, `/decompose`, `/delegate`, `/orchestrate`. [Advanced Modes](../extending/advanced-modes.md)
- **Multi-model turns run in parallel**, with `--consensus` to merge the answers. [Multi-Model & Consensus](../extending/multi-model.md)
- **MCP**: servers connect once, in parallel, and are shared by every robot; Streamable HTTP servers (`url:`); per-server `prefix:`, `only:`, `except:` and `requires_approval:`; and `--tool-approval`. [MCP Servers](../extending/mcp.md), [Security](../configuration/security.md#tool-approval)
- **`/model` mid-session**, carrying the conversation over.
- **Skills** with `-s` / `--skill`. [Roles & Skills](../everyday/roles-and-skills.md)
- **`--[no-]thinking`** hides or shows the `<think>` reasoning that some local models stream.
- **Speech**: `--speak-command`, `--speech-model`, `--transcription-model` and `--voice` all take effect. [Images & Speech](../extending/images-and-speech.md)
- **`--history-file` / `--no-history-file`** control chat input history.

## Upgrade checklist

- [ ] Ruby 4.0.9 or newer: `ruby -v`
- [ ] Remove `--terse`, `--regex` and `--skills-prefix` from scripts and aliases.
- [ ] Remove `flags.terse`, `prompts.parameter_regex` and `prompts.skills_prefix` from your config file (optional; they are ignored).
- [ ] Set `llm.max_tokens` or the `audio.*` keys if you relied on the old defaults.
- [ ] Update custom tools from `param … desc:` to `parameter … description:`.
- [ ] Switch MCP servers off `sse` / `ws`; add `prefix:` where two servers share a tool name.
- [ ] Add `--allow-ruby-eval` where you really use `/ruby`.
- [ ] Still on prompt_manager's old `.txt` + `.json` prompt format? See [Migrating Prompts](migrating-prompts.md).
- [ ] Run `aia --dump /tmp/check.yml` and look it over.

## See also

- [Migrating Prompts](migrating-prompts.md)
- [Configuration Keys](../reference/config-keys.md)
- [Command-Line Options](../reference/cli.md)
- [Changelog](https://github.com/MadBomber/aia/blob/main/CHANGELOG.md)
