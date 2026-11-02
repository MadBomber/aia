# Breaking Changes in AIA 2.0

AIA 2.0 is rebuilt on [robot_lab](https://github.com/MadBomber/robot_lab) and ruby_llm 2.1. It is not a drop-in replacement for 1.x. This page lists what changed between 1.1.1, the last 1.x release, and 2.0.0. Check each section before you upgrade.

## Requirements

| | 1.1.1 | 2.0.0 |
|---|---|---|
| Ruby | >= 3.2.0 | >= 4.0.9 |
| ruby_llm | ~> 1.12 | 2.1 (through robot_lab `~> 0.5, >= 0.5.1`) |
| ruby_llm-mcp | ~> 0.8 | not used, and it cannot be loaded alongside ruby_llm 2.1 |

## Command-line options

These options have been removed. Passing one now stops AIA with `ERROR: invalid option` and exit status 1.

| Removed option | What to do instead |
|---|---|
| `--terse` | Nothing. It was already deprecated and had no effect in 1.x. |
| `--regex PATTERN` | Nothing. Prompt parameters use ERB (`<%= param %>`), so a custom parameter regex is no longer meaningful. |
| `--skills-prefix PREFIX` | Point `--skills-dir` at the directory that holds your skill subdirectories. |

Check any scripts, aliases or cron jobs that pass these options.

## Configuration file

These keys have been removed from the configuration. AIA ignores them if they are still in your config file. The matching `AIA_*` environment variables are ignored too.

| Removed key | Notes |
|---|---|
| `flags.terse` | See `--terse` above. |
| `prompts.parameter_regex` | See `--regex` above. |
| `prompts.skills_prefix` | See `--skills-prefix` above. In 1.x it defaulted to `skills`. |

### Changed defaults

If you relied on one of these defaults, set the old value in your config file.

| Key | 1.1.1 default | 2.0.0 default |
|---|---|---|
| `llm.max_tokens` | `2048` | `32767` |
| `llm.top_p` | `1.0` | `nil` (the provider's default) |
| `audio.speak_command` | `afplay` | `say` |
| `audio.voice` | `alloy` | `nil` |
| `audio.speech_model` | `tts-1` | `nil` |
| `audio.transcription_model` | `whisper-1` | `nil` |

`afplay` plays audio files, not text, so `--speak` did not work with the old default. The audio model and voice defaults were OpenAI-specific. With `nil`, ruby_llm uses its own defaults.

## Chat directives

- **`/terse` has been removed.**
- **`/ruby` is disabled by default.** It runs arbitrary Ruby with AIA's full privileges. Start AIA with `--allow-ruby-eval` to enable it.
- **`/model` keeps the conversation.** When you switch models, the new model gets a summary of the conversation so far. To start fresh as 1.x did, set `model_switch_history: clean`.

Every other 1.x directive and alias still works.

## Custom tools

Tools loaded with `--tools` must use the ruby_llm 2 DSL. `param` no longer exists:

```ruby
# 1.x
param :text, desc: "Text to process"

# 2.0
parameter :text, description: "Text to process"
```

A tool still written the 1.x way raises `NoMethodError` when it loads.

## MCP servers

AIA now uses ruby_llm 2.1's built-in `RubyLLM::MCP` client instead of the `ruby_llm-mcp` gem. Servers listed under `mcp_servers:` still work, with these exceptions:

- **The `sse` and `ws` transports are gone.** Use the server's Streamable HTTP endpoint (`url:`) or run it over stdio (`command:`).
- **Server classes loaded with `--require` must subclass `RubyLLM::MCP`.** AIA no longer picks them up automatically.
- **Duplicate tool names are an error.** If two servers offer a tool with the same name, the second server fails to connect. Give one of them a `prefix:`.

## Embedding AIA in Ruby code

- `AIA.client` is now a `RobotLab::Robot` or a `RobotLab::Network`.
- `AIA::RubyLLMAdapter` and everything under `lib/aia/adapter/` have been removed.
- `AIA::HistoryManager` is now `AIA::VariableInputCollector`. The old name is gone.
- `AIA::ConfigSection` is gone. Use `MywayConfig::ConfigSection`.

## Files shipped in the gem

The gem no longer includes `docs/`, `examples/` or `mcp_servers/`. They are still in the [repository](https://github.com/MadBomber/aia).

## If you used a 2.0 pre-release

These were added in the 2.0 alpha and beta pre-releases and removed before 2.0.0. They never existed in 1.x.

- The KBS rule engine, the `/rules` directive, user-defined rule hooks and `--tool-filter-kbs`.
- The zvec, sqlite-vec and LSI tool filters. TF-IDF is the only tool filter. It is on by default and toggled with `-A` / `--[no-]auto-tool-filter`. This replaces the `tool_filter_a` setting.

`-A` used to mean `--tool-filter-kbs`. It now means `--auto-tool-filter`.
