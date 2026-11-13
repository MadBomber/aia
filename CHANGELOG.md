# Changelog

## [Unreleased]

### Fixed

- **`--tokens` shows token counts again and `/cost` records them.** Every metrics site checked `result.raw.respond_to?(:input_tokens)`, but under ruby_llm 2 the raw `RubyLLM::Message` keeps its counts under `#tokens`. The check was always false, so `--tokens`/`--cost` printed nothing and `/cost` recorded 0 tokens. A new `AIA::Utility.token_usage(result)` reads the counts from `RobotLab::RobotResult` and the model id from the raw message. The chat loop, pipeline, @mention, decompose and session tracker paths all use it, and `/cost` prices each turn by that model id instead of the robot's name. Fixes #201.
- **A missing API key names the env var to set.** With no key for the chosen provider, aia printed ruby_llm's developer message with a `RubyLLM.configure` snippet. It now prints one line such as `OpenAI is not configured: set OPENAI_API_KEY`. For Vertex AI the hint names the variables robot_lab reads (`GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`) rather than the `VERTEXAI_*` names ruby_llm suggests. Providers whose key nothing reads from the environment (Cohere, Moonshot and others), and Bedrock and Azure, which raise their own message, keep ruby_llm's original message. Fixes #224.
- MCP servers that fail to connect are now reported on stderr when it is not a terminal, where the connection spinner prints nothing.
- **`/skills` no longer cuts front matter at a `---` inside a value.** The directive had its own front-matter reader that ended at the first `---` anywhere after the opening line, so a `SKILL.md` with `description: Review diffs---then summarize` was listed as `Review diffs`, and a `/skills summarize` search missed it. The listing now uses the shared `SkillUtils#parse_front_matter`, and the search text ends at a `---` that starts a line. (#223)
- **`--list-skills` and `--list-roles` accept dates in front matter.** `SkillUtils.parse_front_matter` now permits `Date` and `Time` values, so a SKILL.md or role file whose front matter has a line such as `updated: 2026-01-15` no longer loses all of its front matter: `--list-skills` showed "No front matter found" and `--list-roles` dropped the role's details.
- **`/config` keeps `=` inside values and shows nested keys.** `/config output.file notes=v2.md` stored `notesv2.md` because every `=` was stripped. Now only the separator in `/config KEY = VALUE` is removed. `/config temperature`, `/config llm.temperature`, `/config top_p`, `/temperature` and `/top_p` showed `nil`; viewing a key now resolves dot-notation and flat CLI names the same way setting one does. Fixes #204.
- **Stdio MCP servers start again with ruby_llm 2.2.** The patch that sends MCP server stderr to the log replaced `RubyLLM::MCP::Stdio#start` with a copy of the ruby_llm 2.1 body. Under 2.2, `Stdio` gets a lambda `env`, so every stdio server failed with `no implicit conversion of Proc into String` and no MCP tools loaded. The patch now calls the original `#start` and adds only the `err:` redirect to its `Open3.popen2` call, so it follows upstream's environment handling and spawn options. Fixes #203.
- **A directive that raises no longer ends the chat session.** `/include` or `/insert` of a missing file raised out of the chat loop, so aia printed `ChatLoop error: ...` and ended the session. The rest of the queued input and the conversation context were lost. `ChatLoop#resolve_directive` now rescues the error, shows `Error: <class>: <message>`, and waits for the next input. Fixes #202.
- **`--cost`, `/cost`, `/robots` and `/model` read prices through the ruby_llm 2 API.** `CostCalculator` and `wage_for` asked for `input_price_per_million`/`output_price_per_million`, which ruby_llm 2 removed, so every cost showed `N/A` or `$0.00000`. `/model` called `input_cost`/`output_cost`, which never existed, and printed an error for each model. All three now use `price(:input)`/`price(:output)`, and `/model` prints the modalities as `text, image, pdf -> text` instead of the raw object. Fixes #200.
- **`debug_me` is a runtime dependency.** `lib/aia.rb` requires `debug_me` on every load, but the gemspec declared it only for development, so an installed aia worked only because `trak_flow` happens to depend on it. It is now a runtime dependency. Fixes #198.
- **zsh and fish completion scripts complete prompt IDs.** The zsh script registered with the old `compctl -K` system but used `compsys` helpers, so TAB printed errors and completed nothing; it now registers with `compdef` (running `compinit` first when needed). The fish script's test was inverted, it re-registered a rule on every TAB, and it turned off file completion; it now offers prompt IDs for the first argument and leaves file completion on for later ones. Fixes #197.
- **`--require` strips spaces in a comma-separated list, and repeated `--tools` flags add up.** `--require "json, yaml"` tried to require `" yaml"` because the handler split on commas without stripping, unlike every other list flag. A second `--tools` flag replaced the first instead of appending. Fixes #196.
- **`--fuzzy` starts fzf, and cancelling it exits cleanly.** `AIA::Fzf` passed shell-quoted arguments to fzf through an argv array: `--prompt='Search term: '` split into three words (fzf rejected the stray `term:`), the header and prompt kept their backslashes, and the preview's `{1}` placeholder was escaped so fzf never filled it in. The arguments are now passed unquoted, with only the preview's directory and extension escaped. Cancelling the picker raises `AIA::PromptError`, so aia prints one line instead of a backtrace. Fixes #195.
- **`--provider` keeps a model name that is also a provider name.** In 2.1.0 a bare model name that is a RubyLLM provider slug was read as that provider's default model before `--provider` applied, so `--provider ollama -m mistral` asked the provider `mistral` for its `default` model and `AIA_MODEL=mistral --provider ollama` asked ollama for `default`. With `--provider`, such a name is now an ordinary model id under that provider (`ollama/mistral`), as the README and `--provider` help describe. Without `--provider`, a bare provider name still means that provider's default model (`--model claude_code`). Fixes #194.

- **Uppercase chat directives are recognized again.** `DirectiveProcessor#state_setting?` extracted the directive name without downcasing it, unlike its siblings `#directive?` and `#process`. Since state-setting names are stored lowercase, typing `/CLEAR` or `/Debate` in chat was treated as a non-state directive and its wrapper text was forwarded to the model instead of silently setting the mode. The name is now downcased to match the other methods, restoring the case-insensitive directive names the docs promise. (#174)

- **A bad command-line option fails the test run.** `test_helper.rb` installed its `exit` guard at load time, so it swallowed the exit Minitest raises while parsing an unrecognized option: `ruby -Itest test/foo_test.rb --no-such-option` ran the suite anyway and exited 0. The guard is now active only while a test is executing, so Minitest's option-parsing exit reaches the shell while aia's own exits during a test stay suppressed. A failing test file still exits non-zero.

- **The test suite no longer warns about redefined `VERSION` constants.** `test/aia/utility_test.rb` overrode `AIA::VERSION` and `RubyLLM::VERSION` with bare `const_set`, so every run printed four "already initialized constant" warnings, and an assertion failure skipped the restore. The test now swaps each constant through a `stub_const` helper that removes it before setting it and restores it in an `ensure`. (#179)

- **Docs site no longer references missing assets or the dead polyfill.io CDN.** `mkdocs.yml` pointed `extra_css`/`extra_javascript` at `assets/css/custom.css` and `assets/js/mathjax.js`, which do not exist under `docs/assets/` (only `images/` is present), so each 404'd on the published site; it also loaded `https://polyfill.io/v3/polyfill.min.js`, a domain decommissioned in 2024. All three references are removed. `mkdocs build --strict` does not validate `extra_*` paths, so it passed before and after. The MathJax CDN entry is unchanged.

- **The test suite no longer warns about a redefined `AIA.config`.** `test/aia/utility_test.rb` swapped `AIA.config` with `define_singleton_method` and restored it the same way, so `ruby -w` printed two "method redefined" warnings. It now uses a mocha stub, which mocha removes after the test. Fixes #192.
- **`--tools` files load once.** `ConfigValidator#require_tool_files` and `ToolLoader#load_tools` each required every `--tools` file, so a file that failed to load ran twice and printed its warning twice. The loop now lives only in `ToolLoader#require_tool_files`, which the validator calls, and each path is attempted once. Fixes #191.

### Changed

- **`SpawnHandler` reuses `Crew.model_opts`.** Its private copy of the model/provider override helper was identical to `Crew.model_opts` and is removed; `/spawn` behavior is unchanged. Fixes #181.

- **Recruit and reskill tools accept only skill-directory ids.** The `recruit_robot` and `reskill_robot` tools now take skill ids that name a skill within the configured skills directory and refuse ids written as filesystem paths (`/…`, `./…`, `../…`, `~/…`), returning the tool's usual error. Human-typed `/add_recruit` and `/reskill` directives are unchanged and still accept path-based skill ids.

### Removed

- **`TurnState#active_mcp_servers` is gone.** Its only reader left with the KBS removal, so `ChatLoop` was resetting a value nothing read after every turn. The accessor, its reset in `TurnState#clear!`, and `ChatLoop#clear_turn_mcp_filter` are deleted. (#187)

- **`McpParser` no longer copies an MCP server's `topics` key.** The JSON MCP config parser (`--mcp FILE`) copied `topics` into each parsed server for KBS routing; nothing has read it since KBS was removed, and robot_lab ignores it. `group` is still copied for `McpGrouper`. (#227)
- **Three private copies of the response model-id lookup are gone.** `MentionRouter#extract_model_id`, `ChatLoop#extract_model_id` and `SessionTracker#extract_model_id_from_raw` held the same "`model_id`, else `model`, else nil" logic. All three now call one `AIA::Utility.model_id_of(message)`, so a RubyLLM rename needs one edit. Behavior is unchanged. Fixes #182.

### Documentation

- **README "Building" section uses commands that exist.** It told contributors to run `just install`, `just gen_doc` and `just flay`, but the repo has no `justfile`. It now lists `rake install`, `mkdocs serve`/`mkdocs build`, and `flay lib`/`flog lib`. Fixes #225.
- **README examples use model IDs the bundled registry resolves, and Quick Start includes an API-key step.** The headline example `aia --chat -m gpt-4o,claude-3-5-sonnet,gemini-1.5-pro` stopped with `Unknown model`, and `gemini-1.5-pro` resolved to Vertex AI. README now uses `claude-sonnet-4-6` (anthropic) and `gemini-2.5-pro` (gemini) in place of `claude-3-5-sonnet`, `claude-3-sonnet`, `gemini-1.5-pro` and `gemini-pro`. Quick Start has a new step that exports a provider key and links to the installation page's list of variables. Fixes #205.
- **`mcp_servers/README.md` describes the files that exist.** It named the deleted `imcp.json` (its own example printed "MCP config file not found"), described only 3 of the 7 sample files, and linked to three dead pages. It now covers all seven files, uses only existing files in its examples, and links to modelcontextprotocol.io and the MCP servers repository. `mcp_servers/filesystem.json` exposes `.` instead of a developer-machine path. Fixes #199.
- **README tool and MCP examples point at files that exist.** The "Tool Examples" and "MCP Client Examples" blocks named `examples/tools/mcp/` (removed) and loaded MCP servers through `--tools`. They now point at `examples/tools/word_count_tool.rb`, `examples/plugins/` and `--mcp examples/mcp/filesystem.json`. Fixes #190.

- **README log level options match the CLI.** The "Debug Mode and Log Level Options" table and examples listed `--info`, `--warn`, `--error` and `--fatal`, which the option parser does not define (`aia --info` fails with `invalid option`). They now use `--log-level LEVEL` and `--log-to FILE`, as registered in `lib/aia/config/cli_parser.rb` and documented in `docs/reference/cli.md`. The `mcp` logger bullet above the table now matches `lib/aia/logger.rb` instead of naming a nonexistent `RubyLLM::MCP.logger`. Fixes #186.

- **README drops three chat directives that were never registered.** The README listed `/shell`, `/next` and `/pipeline` as chat directives and used them in examples, but none is registered (`directive?` returns false for each): shell runs through `$(...)` expansion, and sequencing uses the `next:`/`pipeline:` front-matter keys or the `-n`/`-p` CLI flags. The directive rows and examples now use those supported forms. Fixes #175.

- **README directive table lists every registered alias.** The `/paste` row showed no aliases, though `web_and_file_directives.rb` registers `alias clipboard paste`, and the `/available_models` row omitted `/available` and `/all_models`, both registered in `model_directives.rb`. Both rows now match the registered aliases and `docs/reference/directives.md`. Fixes #180.

- **README documents the `/ruby` security gate.** The `/ruby` (`/rb`) directive table row and example now state that it is disabled by default and requires `--allow-ruby-eval` (or `flags: { allow_ruby_eval: true }` in `~/.config/aia/aia.yml`), matching the gate in `lib/aia/directives/execution_directives.rb`.

- **README configuration tables match `defaults.yml` and the CLI.** The "Complete Configuration Reference" tables listed options removed in 2.0 (`--clear`, `--md`/`--[no-]markdown`) and keys that do not exist (`prompts.roles_dir`, `paths.config_file`, `embedding.model`), and showed stale defaults for `llm.max_tokens` (`2048` → `32767`), `llm.top_p` (`1.0` → unset) and `logger.mcp.file` (`STDOUT` → `~/.config/aia/logs/mcp.log`). The rows now agree with `lib/aia/config/defaults.yml` and `docs/reference/config-keys.md`.

### Added

- `/verify` accepts an optional temperature delta (`/verify 0.3`) that runs the two verifiers below and above the configured temperature, and assigns verifier/reconciler robots to the first, second and third configured models when several are given (Fixes #154)

## [2.1.0] - 2026-11-07

Coding-agent CLIs (Claude Code, Codex, GitHub Copilot) can be used as models, and a prompt file can ask for a special mode such as `debate` in its front matter. Batch runs now exit 1 when an LLM call fails. The unit test suite runs without API keys, a UTF-8 locale or a particular Ruby patch level, and every test file runs on its own.

### Added

- **Coding agents as models.** `--model claude_code/opus`, `codex/default` or `copilot/auto` sends prompts to the Claude Code, Codex or GitHub Copilot CLI in batch mode (stdin in, JSON out) through the `ruby_llm-providers-claude_code`, `-codex` and `-copilot` gems, which resume the agent's own session between turns. A bare provider name (`--model claude_code`) now means that provider's default model. Providers that answer `accepts_tools?` with `false` get no aia tools or MCP servers attached, with a one-line notice. An installed provider gem is found and loaded even when aia itself runs under Bundler (a `bin/aia` checkout, or an app that lists aia in its Gemfile) and the gem is not in that Gemfile, provided the bundle already satisfies the gem's dependencies.

- **`mode:` front matter key.** A prompt file can ask for one of the special modes that the chat directives `/debate`, `/verify`, `/decompose`, `/delegate`, `/spawn`, `/orchestrate` and `/concurrent` request, by naming it in its front matter: `mode: debate`. Prompts run from the command line, in a pipeline or as executable prompts then get that mode, which until now ran only in chat; a `/debate` line inside a prompt file was sent to the model as text. As in chat, a debate needs several robots (`--model a,b,c`).

### Fixed

- **`--provider` outranks `AIA_MODEL` and the config file.** `--provider claude_code` replaced the provider only of models given without a `<provider>/` prefix, so with `AIA_MODEL=lms/qwen3.8` exported the flag did nothing and the prompt still went to LM Studio. A command-line `--provider` now applies to every model that came from the environment or a config file, prefix or not, keeping their model names; it sets the provider, never the model, so `--model claude_code` (a bare provider name) remains the way to ask for a provider's default model. Models named on the command line with `--model` keep an explicit prefix, since both values come from the same place. When a provider gem cannot be loaded because aia is running under Bundler, the warning now names the Gemfile to add the `ruby_llm-providers-<slug>` gem to.

- **Batch runs exit 1 on LLM errors.** robot_lab shields a robot's exception into an `Error: ...` reply so one failing robot cannot crash a network, which left `aia prompt` printing a bad API key, rate limit or provider outage as the answer and exiting 0. A hook now records the real exception for each pipeline step: outside chat the step fails, the error goes to stderr and aia exits 1; in a chat session the error is shown and the session continues. Unshielded RubyLLM errors (image generation, provider setup) exit 1 with a one-line message instead of a backtrace.

- **`DelegateHandler` and `DelegateToForemanTool` load what they use.** `delegate_handler.rb` now requires `TaskDecomposer` and `TaskExecutor`, and `delegate_to_foreman_tool.rb` requires `TaskBoardTool`. Each worked only because its one caller also required those files, so loading either on its own and calling it raised `uninitialized constant`.

**Test suite**

- **Failing test runs exit non-zero.** `test_helper.rb`'s `exit` override, which stops aia's exit calls from ending a test run early, also swallowed Minitest's exit status, so `rake test` and single test files exited 0 when tests failed. The override now stands down after the suite runs.

- **Test suite loads on Ruby 4.1.** `ostruct` is a bundled gem since Ruby 4.0 and only reached the test bundle as a transitive dependency of `oj` 3.17.7; `oj` 3.17.8 dropped it, so `bundle update` left the suite unable to load `OpenStruct`. It is now a development dependency. The speech player test no longer stubs `ENV`, which Ruby 4.1 rejects as a shareable object.

- **Unit suite passes without API keys or a UTF-8 locale.** The network-building tests create real RubyLLM chats, which ruby_llm 2.1 refuses without a provider API key, so 37 tests errored unless `OPENAI_API_KEY` was set. They now skip that credential check; they never call an API. The gemspec version test errored under a non-UTF-8 locale; it now loads the gemspec and compares its version with `AIA::VERSION`. `test_helper.rb` requires `ostruct`, so test files that use `OpenStruct` also run on their own.

- **Every unit test file runs on its own.** Six files raised `uninitialized constant` when run alone, because aia loads a class each one uses lazily: `TaskDecomposer`, `TaskExecutor`, `TaskBoardTool` (one file each) and `ToolFilter::TFIDF` (three files). Each file now requires that class.

- **`ConfigTest` ignores the shell's `AIA_PLUGINS_DIR`.** The test that checks `paths.plugins_dir` defaults to `nil` read whatever the developer's shell had exported and failed, and the two tests that set the variable deleted it afterwards. All three now set the variable for their own run and restore it.

## [2.0.1] - 2026-11-02

### Fixed

- **`--chat` startup output is readable again.** ruby_llm 2.1 starts stdio MCP servers with their stderr connected to aia's, so server banners, npm notices, stack traces and validation dumps were printed over the "Connecting MCP servers" spinner and garbled it. That stderr now goes to `~/.config/aia/logs/mcp_servers.log`. Set `logger.mcp.server_stderr` to another path, `STDERR` (the 2.0.0 behavior) or `null` to discard it.

### Changed

- `logger.mcp.file` defaults to `~/.config/aia/logs/mcp.log` (was `STDOUT`), so MCP connection warnings no longer print over the spinner. Failed servers are still listed in the startup banner. A config file that sets `file: STDOUT` keeps the old behavior.
- Log directories are created when they don't exist.

## [2.0.0] - 2026-11-02

AIA 2.0 rebuilds the CLI on [robot_lab](https://github.com/MadBomber/robot_lab): every session is a crew of robots, MCP servers come from ruby_llm 2.1's built-in client, and any provider RubyLLM registers can be used. This entry summarizes everything since 1.1.1, the last 1.x release, including the `2.0.0.pre.alpha` and `2.0.0.pre.beta2` pre-releases.

**Requires** Ruby >= 4.0.9 · robot_lab `~> 0.6` · ruby_llm 2.1 (through robot_lab)

### Upgrading from 1.x

These changes can break an existing setup. [Upgrading to 2.0](docs/appendix/upgrading-2.0.md) has the details.

- **Ruby 4.0.9 or newer.**
- **Removed options:** `--terse`, `--regex`, `--skills-prefix` and `--md` / `--[no-]markdown`. Passing one now stops AIA with an invalid-option error. The config keys `flags.terse`, `prompts.parameter_regex`, `prompts.skills_prefix` and `output.markdown` are gone too, along with these keys nothing read: `flags.clear`, `embedding.model`, `tools.dir`, `roles.dir`, `prompts.roles_dir`, `prompts.tool`, `prompts.tools_prefix` and `paths.config_file`. Old config files that still set them load as before. Use `--skills-dir` in place of `--skills-prefix`.
- **Changed defaults:** `llm.max_tokens` is `32767` (was `2048`) and `llm.top_p` is `nil` (was `1.0`). `audio.speak_command` is `say`; it was `afplay`, which plays audio files, not text. `audio.voice`, `audio.speech_model` and `audio.transcription_model` are `nil` (were `alloy`, `tts-1` and `whisper-1`).
- **Custom tools must use the ruby_llm 2 DSL.** `param :text, desc: "..."` is now `parameter :text, description: "..."`. A tool still written the 1.x way raises `NoMethodError` when it loads.
- **MCP runs on ruby_llm 2.1's own client.** The `ruby_llm-mcp` gem is no longer used and cannot be loaded alongside ruby_llm 2.1. Servers listed under `mcp_servers:` keep working. Also:
  - Server classes loaded with `--require` must subclass `RubyLLM::MCP`.
  - `sse` and `ws` transports are gone; use the server's Streamable HTTP `url:` or a stdio `command:`.
  - When two servers offer a tool with the same name, the second now fails to connect. Give one of them a `prefix:`.
- **`/terse` has been removed.**
- **`/ruby` is off by default.** Enable it with `--allow-ruby-eval`.
- **`/model` keeps the conversation.** Switching models hands the new model a summary of the conversation so far. Set `model_switch_history: clean` to start fresh, as 1.x did.
- **Embedding AIA in Ruby code:** `AIA.client` is a `RobotLab::Robot` or `RobotLab::Network`. `RubyLLMAdapter` and `lib/aia/adapter/` are gone. `AIA::HistoryManager` is now `AIA::VariableInputCollector`, and `AIA::ConfigSection` is now `MywayConfig::ConfigSection`.
- **The gem no longer ships `docs/`, `examples/` or `mcp_servers/`.** They are in the [repository](https://github.com/MadBomber/aia).

If you used a 2.0 pre-release: the KBS rule engine, `/rules`, user-defined rule hooks and `--tool-filter-kbs` have been removed. Tool filtering is TF-IDF only and on by default, toggled with `-A` / `--[no-]auto-tool-filter`, which replaces `tool_filter_a`.

### Added

**Crews and multi-robot work**
- Every chat session is a crew, even with one model; its lead robot is the chief.
  - `/add_recruit` (`/add`) adds persistent members, `/drop_recruit` (`/drop`) removes them, and `/reskill` resets a member with a new role.
  - `skill:<id>` assigns roles from skills, and the chief can recruit and reskill members itself.
- `@crew` sends a prompt to every member. Leading `@a @b` addresses run concurrently, and a `@name` inside the body runs members as a pipeline.
- `/spawn <name> <provider/model> <prompt>` creates a one-shot specialist.
- Orchestration patterns:
  - multi-model parallel, consensus and pipeline networks
  - `/verify`: two independent answers plus a reconciler
  - `/debate`, which ends when the robots' answers converge
  - `/decompose` and `/delegate`
  - `/orchestrate`: three-tier lead and specialist planning
- Multi-model turns run their LLM calls concurrently.
- TrakFlow task tracking: the `/plan`, `/task` and `/tasks` directives, plus the `TaskBoardTool` and `DelegateToForemanTool` tools.

**MCP**
- All configured servers connect in parallel before the first robot is built. Each server process starts once and is shared by every robot, crewmate and network worker.
- Streamable HTTP servers can be configured with `url:`, `headers:` and `bearer_token:`.
- Servers accept `prefix:`, `only:`, `except:`, `requires_approval:` and `description:`.
- An `mcp_servers:` entry can name a `RubyLLM::MCP` subclass, such as `SharedTools::MCP::GitHub`. The class supplies its own command or URL, environment and timeout, and the server is known by the class's default name (`github`). A class whose `available?` returns false (a missing API key, say) is skipped with a note naming the missing variables. `--require` libraries load before servers connect, so the classes they define can be used.
- `tools.approval` (`--tool-approval ask|approve|deny`) handles approval-gated tool calls and servers' requests for input. `ask`, the default, prompts on the terminal.

**Providers and models**
- `AIA::ProviderRegistry` takes its provider list from RubyLLM. It loads `ruby_llm-providers-<slug>` gems on demand, and a `<SLUG>_API_BASE` variable overrides a provider's endpoint.
- `--provider` sets the default for model names without a provider prefix. `--list-providers` shows each provider, marked as local or as having an API key; `--list-models` lists a provider's live models.
- `/model` switches models mid-session, with fuzzy name matching. `model_switch_history` decides how the conversation carries over: `summarize` (default), `replay` or `clean`.
- `--[no-]thinking` hides or shows the `<think>` reasoning that local models stream.

**Skills, audio and output**
- `--skill` / `-s` injects skills into the system prompt in chat mode, and into each prompt in pipeline mode. The `SKILL.md` skills system itself arrived in 1.1.0.
- Audio:
  - `--speak-command` runs your own TTS script; `~/.config/aia/tts.sh` is a ready-made OpenAI one.
  - `--speech-model`, `--transcription-model` and `--voice` now take effect.
  - `--speak` shows a spinner for converting and for speaking.
- `--history-file` and `--no-history-file` now work.
- `tool_filter.timeout_s` sets the TF-IDF filter's timeout.

### Changed

- The example scripts and configs run on Anthropic (`claude-haiku-4-5`, `claude-sonnet-4-6`) and need only `ANTHROPIC_API_KEY`. The example tool plugins moved to `examples/plugins/`. New example 30 uses every shared_tools tool and MCP server.
- `/debate` shows each robot's response as soon as it finishes, under a `Round N · Name` heading, with one progress line per round. The transcript is still written to `--output`.
- Tool allowlists (`--allowed-tools`, `--rejected-tools`) and the chat tool filter match a tool class by the name the model calls it (`dns`), not its Ruby class name (`SharedTools::Tools::DnsTool`).
- Heavy subsystems load only when used: verification, decomposition, TrakFlow and the special-mode handlers.
- "Exiting AIA application..." now appears only when a chat session ends, not after `--version`, `--help` or a one-shot run.
- **One special mode per turn is now enforced.** `/verify`, `/decompose`, `/concurrent`, `/debate`, `/delegate`, `/spawn` and `/orchestrate` go through `TurnState#request`, so a later directive replaces an earlier one instead of both staying set. The `TurnState` `force_*` flags are read-only; handlers take the active mode with `TurnState#consume!`.

### Removed

- KBS rule engine: `RuleRouter`, `ExpertRouter`, `DynamicRuleBuilder`, `DecisionApplier` and the rules DSL.
- The zvec, sqlite-vec and LSI tool filters.
- Dependencies: `kbs`, `ruby_llm-mcp`, `zvec`, `sqlite-vec`, `informers`, `ostruct`, `securerandom`.
- The `--terse`, `--regex` and `--skills-prefix` options, the `/terse` directive, and their config keys.
- The unused `rules:` config section (`AIA_RULES__*`).
- Options and keys that had no effect: `--expert-routing`, `--load`, `--save`, `--md`, their `flags.*` / `output.markdown` keys, `concurrency.independent_servers`, the MCP server key `independent:`, and the config keys listed under Upgrading.
- `ModelSwitchHandler`, the disabled plain-language model switcher ("switch to claude"). `/model` switches models.
- Compatibility shims: the `AIA::HistoryManager` and `AIA::ConfigSection` aliases, and the `RobotFactory` forwarding methods `clear_tool_cache!`, `filtered_tools`, `resolve_system_prompt` and `build_identity_prompt` (call `ToolLoader` and `SystemPromptAssembler` directly).

### Fixed

- **MCP:**
  - `--no-mcp` is honored.
  - Streamable HTTP servers keep their `url`.
  - `--mcp-list --list-tools` uses the same connection path as the robots.
- **Model switching:** conversation history now carries over to crews. Prompt decomposition uses structured output again instead of always falling back to JSON parsing.
- **Errors and warnings now reach the terminal** (aia now writes them with `$stderr.puts` instead of `warn`).
- **Command-line errors:** an invalid option value (`-t hot`, `--tool-approval maybe`), a malformed `-m` spec or a missing `-m MODEL=ROLE` role file now prints a one-line `ERROR:` message and exits 1 instead of a Ruby backtrace.
- **Model search:** `--available-models` and `/available_models` capability terms such as `text_to_image` work again under ruby_llm 2.1 instead of crashing with `NoMethodError`.
- **Front-matter `model:`** no longer crashes the run after the model replies.
- **Settings changed while aia runs now reach the model:**
  - A prompt's front-matter `model:` switches models before that prompt runs; `temperature:`, `top_p:` and `config: llm:` retune the running robot.
  - `/temperature`, `/top_p` and `/config llm.*` apply from the next chat turn, to every crewmate, without losing the conversation.
  - `/config` converts values to the setting's type (numbers, true/false, lists) for every key, not just seven switches.
- **`model_switch_history` and `model_aliases` are loaded** from the config file, `-c` files and the environment. `/model` accepts aliases such as `sonnet` or `cheap`.
- **Environment variables are typed:** `AIA_FLAGS__X=false` turns a switch off, numbers such as `AIA_LLM__TEMPERATURE=0.2` become numbers, and `AIA_TOOLS__ALLOWED`, `AIA_TOOLS__REJECTED` and `AIA_TOOLS__PATHS` are split on commas.
- **`flags.shell` and `flags.erb`** set the default for every prompt; front matter still overrides them.
- **`tool_filter.timeout_s`** sets the chat tool filter's time limit.
- **`--dump`** includes `tool_filter`, `model_switch_history` and `model_aliases`, and `-c` files can set `tool_filter`.
- **Prompt loading:**
  - Prompt IDs with hyphens or subfolders (`code-review`, `dev/review`) load their file instead of being sent to the model as text. A prompt ID can also be a path (`./drafts/idea`).
  - `aia -p a,b` with no prompt ID runs `a` then `b`, and `aia -r role` alone runs the role file as the prompt.
  - The "prompt ID is required" message no longer says context files are enough.
  - A mistyped prompt ID reports `No prompt named 'x'` with spelling suggestions instead of `The following files do not exist`.
  - Piped text drops a leading `#!` line and keeps its front matter, and piped text that is one word or ends in `.md` is no longer read as a file name.
  - A required parameter declared only in an included file is asked for instead of stopping the run.
  - Parameters named after Ruby built-ins such as `format` or `test` render their values instead of failing with `ArgumentError` (prompt_manager 1.2.0; aia now requires `prompt_manager ~> 1.2`).
  - Front-matter `pipeline:` may be a comma-separated string.
- **Roles and skills:**
  - `--list-roles` and the `-m MODEL=ROLE` check use the configured prompts directory (`--prompts-dir`, config file), not only `AIA_PROMPTS__DIR`.
  - A role given as a path reaches the system prompt, in chat too.
  - The role in the system prompt is processed like a prompt: front matter removed, ERB and `$(...)` expanded.
  - `--skill` warns when the skills directory doesn't exist, and path skills load without one.
  - `--help` describes `--system-prompt` as literal text.
- **Chat and crews:**
  - `/compare` sends the whole argument string as the prompt, not just its first word.
  - An `@word` that names no crew member (an email address, `@deprecated`) goes to the model; only a mistyped name at the start of a message is held back.
  - `/spawn` specialists get the chief's tools and MCP servers, and `skill:<id>` in `/spawn` is applied.
  - The task-board tool reaches the robots: TrakFlow starts before the robot collects its tools.
  - `/verify` builds its robots with the model's provider, so `ollama/…` and other non-default providers work.
  - `/drop_recruit`, `/reskill` and duplicate-name checks ignore case, as `@mentions` do.
  - `/say` uses `--speak-command`, and its usage message is no longer sent to the model.
- **Tools, MCP and providers:**
  - `--list-tools` loads tools the way a session does (lazily loaded gems such as `shared_tools` included) and applies `--allowed-tools` / `--rejected-tools`.
  - `--mcp-list` and the banner apply `--mcp-use` and `--mcp-skip` together, as a session does.
  - `--mcp` JSON servers accept every YAML server key (`prefix`, `only`, `except`, `requires_approval`, `url`, `headers` …) in both JSON forms, and a `url` with no `type` is Streamable HTTP.
  - Ollama works without `OLLAMA_API_BASE`: it defaults to `http://localhost:11434/v1`, and `--list-models` honors `<PROVIDER>_API_BASE`.
  - The default image model is `gpt-image-1` (`dall-e-3` is no longer in RubyLLM's catalogue).
- **Output, speech and side effects:**
  - `--speak` speaks one-shot prompts and each pipeline step, not only chat replies.
  - New `audio.player` (`AIA_AUDIO__PLAYER`) plays the file a custom speak command writes. Unset, AIA uses the first of `afplay`, `mpv`, `ffplay` and `mpg123` on the `PATH` instead of always calling `afplay`.
  - TrakFlow starts on first use, so a session that records no tasks no longer creates `.trak_flow/` in the current directory. Pipelines touch TrakFlow only with `--track-pipeline`.
  - `--paint` no longer writes "Image saved to: …" into the output file.
  - `--completion` with an unsupported shell exits 1.
  - The completion scripts fall back to `~/.prompts` when `AIA_PROMPTS__DIR` is unset.
  - `--track-pipeline` updates the steps of the plan it created, in order, instead of matching any task whose title contains the prompt ID.
- **`--refresh DAYS` works again.** AIA keeps its model list in `<paths.aia_dir>/models.json` and refreshes it from the providers every `registry.refresh` days (default 7, `0` = never), as 1.x did. A failed refresh warns and keeps the existing list.
- **`bin/migrate_prompts`:**
  - `//shell COMMAND` becomes ``<%= `COMMAND` %>``, which inserts the command's output; it used to become `<%= system(...) %>`, which inserted `true`.
  - `//config` settings land where aia reads them: `model`, `temperature`, `top_p`, `next`, `pipeline`, `shell` and `erb` at the top of the front matter, everything else under `config:` at its place in the configuration. Unknown keys are kept under `config:` with a warning.
  - The report prints even when `RUBYOPT=-W0` silences Ruby warnings.
- **The fuzzy role picker** (`--fuzzy` with a role that isn't found) lists roles from `prompts.dir`/`prompts.roles_prefix`, including subdirectories, the same roles `--list-roles` shows.
- **Examples:** `16_directives.sh` lists the real directives, `15_parameters.sh` says AIA asks for every parameter, `21_executable_prompts.sh` notes that a piped file's shebang options are not applied, and `aia_config_orchestrator.yml` no longer claims to extend the base config.
- **Skill paths must be markdown.** A skill given as a file path (`--skill ./x.md`, `/skill ./x.md`) must end in `.md` or `.markdown`; any other file is refused with a warning instead of being sent to the model. Skill folders and skills by name are unchanged.
- **Unknown config keys are dropped at load.** Keys `defaults.yml` doesn't define, from a config file or an `AIA_*` variable, no longer linger in the configuration or show up in `--dump`.
- **Smaller fixes:**
  - The AI response is no longer written to the output file twice.
  - An unknown `@mention` is reported instead of being broadcast to every robot.
  - A pipeline's `next:` and `pipeline:` changes take effect mid-run.
  - Directives supplied by `--tools` work inside ERB prompts.
  - Ollama model tags resolve.
  - GPT-5 and o-series models get the right token and temperature parameters.
  - Pipeline metrics no longer crash.
  - `/clear`, `/checkpoint`, `/restore` and `/review` work with crews.
  - `/say` with no text no longer captures stdin.
  - Skill paths are confined to the skills directory.
  - `bin/aia` works with a relative `BUNDLE_GEMFILE`.

## [1.1.1] - 2026-05-01

### Bug Fixes

- **Ollama model pipeline context preservation**: Mainline fixed adapter replacement when provider-prefixed model names (for example `ollama/qwen3`) did not match resolved local model IDs, preserving conversation history across pipeline steps.
- **Role front matter model isolation**: Mainline restored the active model after role loading so a role file's `model:` metadata cannot unexpectedly replace the configured model.
- **Custom directive loading for ERB prompts**: Mainline loads tool files before PromptManager directive registration so directive classes provided by `--tools` are available inside ERB prompts.
- **Demo example path resolution** (`examples/prompts_dir/project_summary`): Corrected repository-relative paths used by the example prompt.

### Improvements

- **Demo scripts prefer working-tree binary** (`examples/common.sh`): Mainline demo scripts prepend `../bin` to `PATH` when local `bin/aia` is executable.

## [1.1.0] - 2026-04-23

### New Features

- **Skills system** (`lib/aia/skill_utils.rb`, `lib/aia/directives/web_and_file_directives.rb`): Mainline added `SKILL.md`-based skills, `/skill`, `/skills`, `--skill`, `--list-skills`, `--skills-dir`, `--skills-prefix`, path-based skill IDs, and shared `AIA::SkillUtils` helpers.
- **Path-based role resolution** (`lib/aia/prompt_handler.rb`, `lib/aia/config/cli_parser.rb`, `lib/aia/config/validator.rb`): `--role` and role loading now accept file-system paths in addition to configured role IDs.
- **Top-level `roles` and `skills` config sections** (`lib/aia/config/defaults.yml`): Added dedicated directory configuration while preserving prompt prefix settings.
- **Shared search-term parsing** (`lib/aia/directive.rb`): Directive filtering now uses common positive and negative term parsing.

### Bug Fixes

- **Direct skill file resolution**: Skill loading now accepts direct `.md` file paths as well as skill directories.
- **Skill path-prefix containment**: Mainline added realpath boundary checks to block sibling-directory prefix attacks.
- **Path-based role prefixing**: Config tailoring no longer prepends the roles prefix to path-based role IDs.

### Improvements

- **Model and skill filtering consistency**: `/llms` and `/skills` use the shared positive/negative search term behavior.
- **Skills CLI option placement**: Skill-related CLI flags now appear under Prompt Options.

## [1.0.0] - 2026-02-22

### Security Fixes
- **Command Injection Prevention**: Replaced backtick and string-interpolated `system()` calls with safe array-form invocations
  - `chat_processor_service.rb`: `` `#{cmd} #{file}` `` → `system(cmd, file)`
  - `fzf.rb`: Replaced backtick shell execution with `Open3.capture2('fzf', *args, stdin_data: input)`
  - `modality_handlers.rb`: Fixed 3 sites of `system("#{cmd} #{file}")` → `system(cmd, file)` with safe `which` check via `system('which', cmd, out: File::NULL, err: File::NULL)`
- **Audio Tempfile Hardening**: Replaced predictable audio file names with `Tempfile`
  - `speak()` and `text_to_audio_single()` use `Tempfile.new(['aia-tts-', '.mp3'])` with `ensure` cleanup via `unlink`
- **Narrowed Exception Handling**: Changed `rescue Exception` → `rescue StandardError` in `modality_handlers.rb` and `execution_directives.rb` to stop swallowing `Interrupt`, `SystemExit`, and `NoMemoryError`
- **Pinned Critical Dependencies**: Added pessimistic version constraints — `ruby_llm ~> 1.12`, `ruby_llm-mcp ~> 0.8`

### New Features
- **Error Class Hierarchy**: Six domain-specific error subclasses under `AIA::Error < StandardError` — `ConfigurationError`, `PromptError`, `ToolError`, `MCPError`, `AdapterError`, `DirectiveError`
- **`run_all.sh` Batch Runner**: Executes 18 non-interactive example scripts with timestamped log output, pass/fail summary, `--no-save` mode, and version banner

### Improvements
- **Consolidated MCP Connection**: Removed legacy synchronous MCP path; only the SimpleFlow fiber-based parallel implementation remains
  - Renamed `support_mcp_with_simple_flow` → `support_mcp`, `load_tools_with_mcp` → `load_tools`
- **Fzf Refactoring**: Replaced shell-string command building with array-based args via `Open3.capture2`

### Testing
- **Coverage**: Line 57% → 69%, branch 39% → 51%, 161 new tests (613 → 774 total)
  - `config/validator.rb`: 26% → 63% — prompt ID, context files, executable prompts, stdin, roles, fuzzy search, MCP listing, completion scripts, pipeline validation
  - `config/cli_parser.rb`: 26% → 81% — role validation, role listing, all 40+ CLI flags
  - `prompt_handler.rb`: 19% → 83% — prompt/role fetching, metadata application, shorthand conflicts, helper methods, error handling

### Documentation
- Added security documentation for `/ruby`, `/shell`, and ERB directives in `docs/security.md` and `docs/guides/chat.md`
- Corrected 19 documentation accuracy issues — removed fabricated features, fixed config paths, corrected front matter keys
- Added `run_all.sh` documentation to examples README
- Pre-release architecture review at `.architecture/reviews/1-0-0.md`

### Technical Changes
- Bumped version from 1.0.0-beta to 1.0.0
- Updated gem dependencies to latest compatible versions
- Full test suite: 774 runs, 0 failures, 0 errors, 0 skips

## [1.0.0-beta] - 2026-02-10

### Breaking Changes
- **Removed `--exec` / `-x` CLI Option**: Shebang auto-detection fully replaces the legacy `--exec` flag
  - Prompt files with `#!/usr/bin/env aia ...` on the first line are auto-detected and processed as executable prompts
  - Removed `executable_prompt` and `executable_prompt_file` config attributes
  - Removed legacy code path in validator and session
- **Removed deprecated `next` and `pipeline` directives**: These utility directive methods have been removed
  - `next` and `pipeline` are now handled exclusively via CLI flags and front matter
  - Removed `next` and `next=` methods from `AIA::Config`
- **Upgraded to prompt_manager gem v1.0.2**: Directive system now uses PM::Directive base class hierarchy
  - AIA directives inherit from `AIA::Directive < PM::Directive`
  - Directive registration uses centralized `PM::Directive.directive_subclasses`

### New Features
- **`/skill` and `/skills` Directives**: Access Claude Code skills from within AIA
  - `/skills` lists all available skills from `~/.claude/skills/`
  - `/skill <name>` includes a specific skill's context into the conversation
- **`model` Accessor on RubyLLMAdapter**: Added `model` method for programmatic access to the current model
- **Comprehensive Examples Directory**: 23 progressive demo scripts (00–22) covering all AIA features
  - Demos 00–05: Setup, basic usage, front matter, shell integration, ERB, shell+ERB
  - Demos 06–07: Prompt chaining and pipelines
  - Demos 08–10: Context files, roles, STDIN piping
  - Demos 11–13: Multi-model comparison, token usage, cost tracking
  - Demos 14–15: Output files and prompt parameters
  - Demo 16: Directives (built-in `include` and custom directive creation)
  - Demos 17–20: Require/conditionals, tools, local tools, MCP servers
  - Demo 21: Executable prompts (shebang auto-detection, frontmatter+ERB, STDIN piping)
  - Demo 22: Interactive chat mode (pure chat, prompt+chat, pipeline+chat, directives, live session)
  - All demos use isolated `aia_config.yml` via `-c` flag for reproducible runs
  - `common.sh` clears all `AIA_*` environment variables to prevent leakage

### Improvements
- **Directive Processor Refactoring**: Simplified directive detection and prefix handling
  - Improved directive prefix and method name validation
  - Streamlined directive processing logic
- **Enhanced Prompt Handler**: Added pipeline override logging and logger method
- **Error Handling Module**: Added `lib/aia/errors.rb` for centralized exception management
- **Test Coverage Improvements**: Added SimpleCov prelude, CLI parser tests, and enhanced Ollama adapter tests

### Documentation
- **Examples README**: Comprehensive guide with prerequisites, API key configuration, and per-demo documentation links to https://madbomber.github.io/aia/
- **Main README**: Added examples directory reference in "Examples & Tips" section; rewrote executable prompts section for shebang auto-detection
- **CLI Reference**: Removed `--exec` section; updated executable prompt documentation
- **Directives Reference**: Added `/skill` and `/skills` directive documentation
- **Model Directive**: Updated with detailed usage examples

### Technical Changes
- Bumped version from 0.11.1 to 1.0.0-beta
- Updated prompt_manager dependency to v1.0.2
- Updated json gem to 2.18.1
- Simplified directive registry (`lib/aia/directives/registry.rb`)
- Enhanced PromptHandler with expanded prompt processing logic (326+ lines added)
- Added `lib/aia/errors.rb` error handling module

## [0.11.1] - 2026-02-03

### New Features
- **`bin/migrate_prompts` Script**: Standalone Ruby script for migrating prompt files from prompt_manager v0.5.8 format to v1.0.0 format
  - Converts `.txt` + `.json` files to `.md` with YAML front matter and ERB parameters
  - Placeholder conversion: `[PLACEHOLDER]` → `<%= placeholder %>`
  - Space placeholder normalization: `[TECH STACK]` → `<%= tech_stack %>`
  - Directive migration: `//config`, `//temp`, `//topp`, `//include`, `//shell`, `//ruby`, `//backend`, `//next`, `//pipeline`
  - Comment conversion: `#` lines → HTML comments (preserves comments inside code fences and ERB blocks)
  - Code fence detection: files containing ``` fences are flagged as `.txt-review` for manual review
  - JSON history file migration: `.json` parameter history converted to YAML `parameters:` block in front matter
  - `--reprocess` option to re-examine `.txt-review` files and recover those that now process cleanly
  - `--dry-run` mode for safe previewing of changes
  - `--verbose` logging with detailed per-file output
  - `--force` to overwrite existing `.md` files
  - Supports both directory scanning and specific file arguments

## [0.11.0] - 2026-02-02

### New Features
- **`--list-tools` CLI Option**: List all available tools and exit
  - Shows tools loaded via `--require` and `--tools` options
  - Dual-mode output: plain text (word-wrapped, 3-sentence summaries) for terminal, full markdown with nested headings when STDOUT is redirected to a file or pipe
  - Combine with `--mcp-list` to also initialize and list tools from MCP servers, grouped by source
  - Example: `aia --require shared_tools --list-tools > tools.md`

- **`--mcp-list` Filtering**: `--mcp-list` now respects `--mcp-use` and `--mcp-skip` filters
  - When filters are active, header changes from "Configured MCP Servers" to "Active MCP Servers"
  - Shows only the servers that would actually be connected during a session

- **`--mcp-use` and `--mcp-skip` Server Selection**: Select or exclude specific MCP servers by name
  - `--mcp-use server1,server2` - whitelist specific servers (takes precedence)
  - `--mcp-skip server3` - blacklist specific servers

- **Multi-Model Environment Variable Support**: `AIA_MODEL` now supports inline role syntax
  - Example: `export AIA_MODEL="gpt-4o=architect,claude=security"`

### Breaking Changes
- **Removed `--adapter` CLI Option**: The LLM adapter configuration has been removed
  - AIA now exclusively uses `ruby_llm` as its AI interface layer
  - The `ai_client` adapter option is no longer available

### Improvements
- **CLI Refactoring**: Streamlined CLI option names and improved help text
  - Cleaner option grouping and descriptions in `--help` output

### Documentation
- **`--list-tools` and `--mcp-list`**: Added comprehensive documentation to `docs/cli-reference.md` with examples, output format tables, and usage patterns
- **README.md**: Added `--mcp-list` and `--list-tools` to Key Command-Line Options table
- **MCP Integration Guide**: Updated `docs/mcp-integration.md` with current CLI syntax and examples
- **Shared Tools Guide**: Created dedicated `docs/guides/shared-tools.md` with all 17 tools organized by category (Data & Analysis, Database, File & System Operations, Web & Network, Code Execution, Documents, Scheduling & Time, Workflow & Weather, Development & Reference)
- **MkDocs Navigation**: Added Shared Tools guide to site navigation

### Technical Changes
- Added `list_tools` attribute to `AIA::Config` for runtime flag storage
- Added `--list-tools` option to CLI parser in `setup_tool_options`
- Added `handle_list_tools` to `ConfigValidator` with dual-mode output (terminal vs redirected)
- Added `load_local_tools` with gem activation and Zeitwerk lazy-loading support for `--require` libraries
- Added `load_mcp_tools_grouped` returning tools organized by server name
- Added `quiet_mcp_logger` to suppress MCP connection noise during tool listing
- Added `filter_mcp_servers` and `mcp_filter_active?` to `ConfigValidator` for `--mcp-use`/`--mcp-skip` support
- Added `nest_markdown_headings` to properly nest markdown headings in tool descriptions under parent heading level
- Added `first_sentences` helper for terminal-mode description truncation
- Uses `word_wrapper` gem for terminal word wrapping
- Removed adapter selection logic and `--adapter` CLI option

## [0.10.2] - 2025-12-25

**Merry Christmas!**

### Breaking Changes
- **Renamed `--metrics` to `--tokens`**: The CLI flag for displaying token usage has been renamed
  - `--metrics` → `--tokens`
  - Environment variable: `AIA_FLAGS__TOKENS`
  - The `--cost` flag now automatically enables `--tokens`

### New Features
- **Parallel MCP Connections**: Replaced serial MCP server connections with fiber-based parallel execution using SimpleFlow
  - MCP servers now connect concurrently instead of sequentially
  - Total connection time reduced from sum(timeouts) to max(timeouts)
  - Added `simple_flow` gem dependency for lightweight pipeline-based concurrency

### Improvements
- **MCP Failure Feedback**: Added per-server error messages when MCP connections fail
  - Users now see which specific server failed and why (e.g., "⚠️  MCP: 'iMCP' failed - Connection timed out")
  - Previously only showed generic timeout message without identifying the failing server

### Bug Fixes
- **Ruby 4.0 Compatibility**: Fixed `NameError` in `lib/extensions/ruby_llm/modalities.rb`
  - Added `require 'ruby_llm'` before extending `RubyLLM::Model::Modalities`
  - Resolves "uninitialized constant RubyLLM" error on Ruby 4.0.0-preview2

### Technical Changes
- Added `simple_flow` gem dependency to gemspec
- Refactored MCP connection code in `lib/aia/ruby_llm_adapter.rb`:
  - Added `support_mcp_with_simple_flow` method using SimpleFlow::Pipeline
  - Added `build_mcp_connection_step`, `register_single_mcp_client`, `extract_mcp_results`, `report_mcp_connection_results` helper methods
  - Removed old serial methods: `support_mcp_lazy`, `register_mcp_clients`, `start_mcp_clients`, `reconcile_mcp_server_status`, `check_mcp_client_status`
  - Net reduction of ~60 lines of code with cleaner architecture

### Documentation
- **Multi-Model Concurrent Comparison**: Added prominent documentation highlighting the ability to query multiple LLMs simultaneously
  - Added "Concurrent Multi-Model Comparison" spotlight section to README.md
  - Added "Token Usage and Cost Tracking" subsection to Multi-Model Support in README.md
  - Added comprehensive "Token Usage and Cost Tracking" section to `docs/guides/models.md`
- **Token and Cost Flags**: Added documentation for `--tokens` and `--cost` flags
  - Updated `docs/cli-reference.md` with full flag descriptions
  - Updated `docs/configuration.md` with environment variable examples
  - Added "Token Usage and Cost Tracking" section to `docs/guides/chat.md`
  - Updated README.md Key Command-Line Options and Configuration tables

## [0.10.0] - 2025-12-23

### Breaking Changes
- **Environment Variable Naming Convention**: Updated to use nested naming with double underscore (`__`)
  - `AIA_PROMPTS_DIR` → `AIA_PROMPTS__DIR`
  - `AIA_OUT_FILE` → `AIA_OUTPUT__FILE`
  - `AIA_VERBOSE` → `AIA_FLAGS__VERBOSE`
  - `AIA_DEBUG` → `AIA_FLAGS__DEBUG`
  - `AIA_CHAT` → `AIA_FLAGS__CHAT`
  - `AIA_TEMPERATURE` → `AIA_LLM__TEMPERATURE`
  - `AIA_MARKDOWN` → `AIA_OUTPUT__MARKDOWN`
  - Note: `AIA_MODEL` remains unchanged (top-level, not nested)

### Bug Fixes
- **MCP Tool Timeout Handling**: Fixed issue where MCP tool timeouts corrupted conversation history
  - Added `repair_incomplete_tool_calls` method to add synthetic tool results when timeouts occur
  - Prevents "assistant message with 'tool_calls' must be followed by tool messages" API errors
  - Conversation can now continue gracefully after tool timeouts

- **Tool Crash Handling**: Fixed crash when tools throw non-StandardError exceptions (e.g., LoadError)
  - Changed `rescue StandardError` to `rescue Exception` to catch all error types
  - Added `handle_tool_crash` method that logs errors with 5-line traceback
  - Tool crashes no longer crash AIA - conversation continues gracefully

## [0.9.24] - 2025-12-17
### Fixes
- Ran into a problem with the `shared_tools` gem and the --require parameter of AIA which required changes to both gems.

### Improvements
- **`//tools` Directive Filter**: Added optional filter parameter to the `//tools` directive
  - Filter tools by name substring (case-insensitive)
  - Example: `//tools error` lists only tools with "error" in the name
  - Shows "No tools match the filter: [filter]" when no matches found
  - Header indicates when filtering is active: "Available Tools (filtered by 'filter')"

### Documentation
- Updated all shell completion scripts (`aia_completion.bash`, `aia_completion.zsh`, `aia_completion.fish`) to use new nested naming convention
- Updated `docs/configuration.md` with comprehensive environment variable documentation
- Updated `docs/cli-reference.md` environment variables section
- Updated `docs/prompt_management.md` with correct envar names
- Updated `docs/faq.md` with correct envar names
- Updated `docs/guides/basic-usage.md` shell setup examples

### Technical Changes
- Enhanced `lib/aia/ruby_llm_adapter.rb`:
  - Added `repair_incomplete_tool_calls` method for conversation integrity
  - Added `handle_tool_crash` method for graceful error handling
  - Removed debug statements

## [0.9.23] - 2025-12-06

### New Features
- **MCP Server Configuration**: Added native support for defining MCP (Model Context Protocol) servers in the config file
  - Configure MCP servers in `~/.aia/config.yml` under the `mcp_servers` key
  - Supports `name`, `command`, `args`, `env`, and `timeout` options per server
  - Automatic PATH resolution for commands (no absolute paths required)
  - Configurable timeouts for slow-starting servers (default: 8000ms)
  - Environment variable support for MCP server processes

### Improvements
- **Robot Display**: Added MCP server names to the robot ASCII art display
  - Shows "MCP: server1, server2, ..." when MCP servers are configured

### Technical Changes
- Added `load_mcp_servers` method to `lib/aia/config/base.rb` for automatic MCP client registration
- Added `resolve_command_path` method for PATH-based command resolution
- Added `mcp_servers?` and `mcp_server_names` helper methods to `lib/aia/utility.rb`
- Fixed `OpenStruct.merge` to skip nil values, preventing config file values from being overwritten
- Added `mcp_servers: nil` default to prevent merge issues with empty arrays

### Configuration Example
```yaml
# ~/.aia/config.yml
:mcp_servers:
  - name: "my-server"
    command: "my_mcp_server.rb"
    args: ["stdio"]
    timeout: 30000
    env:
      MY_VAR: "value"
```

## [0.9.22] - 2025-11-12

### Bug Fixes
- **TEST SUITE**: Fixed all Mocha test isolation issues causing stub contamination between tests
  - Added proper teardown methods with `super` calls to 13 test files to ensure Mocha cleanup
  - Fixed PromptHandlerTest missing teardown and config fields (erb, shell, roles_dir)
  - Fixed ModelsDirectiveTest to use consistent stubbing approach instead of mixing real and stubbed config
  - Fixed MultiModelIsolationTest to use stubs instead of direct instance variable manipulation
  - Fixed AIAIntegrationTest, ChatProcessorServiceTest, ContextManagerTest, DirectiveProcessorTest, RubyLLMAdapterTest, SessionTest, LocalProvidersTest, UtilityTest, AIAMockingTest, and AIAPropertyBasedTest to include proper Mocha cleanup
  - Test results improved from 2 failures, 2 errors to 0 failures, 0 errors (325 runs, 1018 assertions)

### Technical Changes
- Enhanced test isolation by ensuring all tests using Mocha stubs properly clean up via `super` in teardown
- Standardized stub usage pattern across test suite for consistency
- Eliminated stub leakage that caused "unexpected invocation" and "AIA was instantiated in one test but receiving invocations in another" errors

## [0.9.21] - 2025-10-08
### Bug Fixes
- **Checkpoint Directive Output**: Fixed `//checkpoint` directive to return empty string instead of status message (lib/aia/directives/configuration.rb:155)
  - Prevents checkpoint creation messages from entering AI context
  - Outputs confirmation to STDOUT instead for user feedback
  - Prevents potential AI manipulation of checkpoint system

## [0.9.20] - 2025-10-06
### Added
- **Enhanced Multi-Model Role System (ADR-005)**: Implemented per-model role assignment with inline syntax
  - New inline syntax: `--model MODEL[=ROLE][,MODEL[=ROLE]]...`
  - Example: `aia --model gpt-4o=architect,claude=security,gemini=performance design_doc.md`
  - Support for duplicate models with different roles: `gpt-4o=optimist,gpt-4o=pessimist,gpt-4o=realist`
  - Added `--list-roles` command to discover available role files
  - Display format shows instance numbers and roles: `gpt-4o #1 (optimist):`, `gpt-4o #2 (pessimist):`
  - Consensus mode drops role for neutral synthesis
  - Chat mode roles are immutable during session
  - Nested role path support: `--model gpt-4o=specialized/architect`
  - Full backward compatibility with existing `--role` flag

- **Config File Model Roles Support (ADR-005 v2)**:
  - Enhanced `model` key in config files to support array of hashes with roles
  - Format: `model: [{model: gpt-4o, role: architect}, {model: claude, role: security}]`
  - Mirrors internal data structure (array of hashes with `model`, `role`, `instance`, `internal_id`)
  - Supports models without roles: `model: [{model: gpt-4o}]`
  - Enables reusable model-role setups across sessions
  - Configuration precedence: CLI inline > CLI flag > Environment variable > Config file

- **Environment Variable Inline Syntax (ADR-005 v2)**:
  - Added support for inline role syntax in `AIA_MODEL` environment variable
  - Example: `export AIA_MODEL="gpt-4o=architect,claude=security,gemini=performance"`
  - Maintains backward compatibility with simple comma-separated model lists
  - Detects `=` to distinguish between formats

### Bug Fixes
- **Multi-Model Chat Cross-Talk**: Fixed bug where model instances with different roles could see each other's conversation history
  - Updated Session to properly extract `internal_id` from hash-based model specs (lib/aia/session.rb:47-68)
  - Fixed `parse_multi_model_response` to normalize display names to internal IDs (lib/aia/session.rb:538-570)
  - Each model instance now maintains completely isolated conversation context
  - Fixes issue where models would respond as if aware of other models' perspectives

### Improvements
- **Robot ASCII Display**: Updated `robot` method to extract and display only model names from new hash format (lib/aia/utility.rb:24-53)
  - Handles string, array of strings, and array of hashes formats
  - Shows clean model list: "gpt-4o, claude, gemini" instead of hash objects

### Testing
- Added comprehensive test suite for config file and environment variable model roles
  - test/aia/config_model_roles_test.rb: 8 tests covering array processing, env var parsing, YAML config files
- Added 15 tests for role parsing with inline syntax (test/aia/role_parsing_test.rb)
- Fixed Mocha test cleanup in multi_model_isolation_test.rb
- Full test suite: 306 runs, 980 assertions, 0 failures (1 pre-existing Mocha isolation issue)

### Technical Implementation
- Modified `config.model` to support array of hashes with model metadata: `{model:, role:, instance:, internal_id:}`
- Added `parse_models_with_roles` method with fail-fast validation (lib/aia/config/cli_parser.rb)
- Added `validate_role_exists` with helpful error messages showing available roles
- Added `list_available_roles` and `list_available_role_names` methods for role discovery
- Added `load_role_for_model` method to PromptHandler for per-model role loading (lib/aia/prompt_handler.rb)
- Enhanced RubyLLMAdapter to handle hash-based model specs and prepend roles per model
  - Added `extract_model_names` to extract model names from specs
  - Added `get_model_spec` to retrieve full spec by internal_id
  - Added `prepend_model_role` to inject role content into prompts
  - Added `format_model_display_name` for consistent display formatting
- Updated Session initialization to handle hash-based model specs for context managers
- Updated display formatting to show instance numbers and roles
- Maintained backward compatibility with string/array model configurations
- Added `process_model_array_with_roles` method in FileLoader (lib/aia/config/file_loader.rb:91-116)
- Enhanced `apply_file_config_to_struct` to detect and process model arrays with role hashes
- Enhanced `envar_options` to parse inline syntax for `:model` key (lib/aia/config/base.rb:212-217)

## [0.9.19] - 2025-10-06

### Bug Fixes
- **CRITICAL BUG FIX**: Fixed multi-model cross-talk issue (#118) where models could see each other's conversation history
- **BUG FIX**: Implemented complete two-level context isolation to prevent models from contaminating each other's responses
- **BUG FIX**: Fixed token count inflation caused by models processing combined conversation histories

### Technical Changes
- **Level 1 (Library)**: Implemented per-model RubyLLM::Context isolation - each model now has its own Context instance (lib/aia/ruby_llm_adapter.rb)
- **Level 2 (Application)**: Implemented per-model ContextManager isolation - each model maintains its own conversation history (lib/aia/session.rb)
- Added `parse_multi_model_response` method to extract individual model responses from combined output (lib/aia/session.rb:502-533)
- Enhanced `multi_model_chat` to accept Hash of per-model conversations (lib/aia/ruby_llm_adapter.rb:305-334)
- Updated ChatProcessorService to handle both Array (single model) and Hash (multi-model with per-model contexts) inputs (lib/aia/chat_processor_service.rb:68-83)
- Refactored RubyLLMAdapter:
  - Added `@contexts` hash to store per-model Context instances
  - Added `create_isolated_context_for_model` helper method (lines 84-99)
  - Added `extract_model_and_provider` helper method (lines 102-112)
  - Simplified `clear_context` from 92 lines to 40 lines (56% reduction)
- Updated directive handlers to work with per-model context managers
- Added comprehensive test coverage with 6 new tests for multi-model isolation
- Updated LocalProvidersTest to reflect Context-based architecture

### Architecture
- **ADR-002-revised**: Complete Multi-Model Isolation (see `.architecture/decisions/adrs/ADR-002-revised-multi-model-isolation.md`)
- Eliminated global state dependencies in multi-model chat sessions
- Maintained backward compatibility with single-model mode (verified with tests)

### Test Coverage
- Added `test/aia/multi_model_isolation_test.rb` with comprehensive isolation tests
- Tests cover: response parsing, per-model context managers, single-model compatibility, RubyLLM::Context isolation
- Full test suite: 282 runs, 837 assertions, 0 failures, 0 errors, 13 skips ✅

### Expected Behavior After Fix
Previously, when running multi-model chat with repeated prompts:
- ❌ Models would see BOTH their own AND other models' responses
- ❌ Models would report inflated counts (e.g., "5 times", "6 times" instead of "3 times")
- ❌ Token counts would be inflated due to contaminated context

Now with the fix:
- ✅ Each model sees ONLY its own conversation history
- ✅ Each model correctly reports its own interaction count
- ✅ Token counts accurately reflect per-model conversation size

### Usage Examples
```bash
# Multi-model chat now properly isolates each model's context
bin/aia --chat --model lms/openai/gpt-oss-20b,ollama/gpt-oss:20b --tokens

> pick a random language and say hello
# LMS: "Habari!" (Swahili)
# Ollama: "Kaixo!" (Basque)

> do it again
# LMS: "Habari!" (only sees its own previous response)
# Ollama: "Kaixo!" (only sees its own previous response)

> do it again
> how many times did you say hello to me?

# Both models correctly respond: "3 times"
# (Previously: LMS would say "5 times", Ollama "6 times" due to cross-talk)
```

## [0.9.18] - 2025-10-05

### Bug Fixes
- **BUG FIX**: Fixed RubyLLM provider error parsing to handle both OpenAI and LM Studio error formats
- **BUG FIX**: Fixed "String does not have #dig method" errors when parsing error responses from local providers
- **BUG FIX**: Enhanced error parsing to gracefully handle malformed JSON responses

### Improvements
- **ENHANCEMENT**: Removed debug output statements from RubyLLMAdapter for cleaner production logs
- **ENHANCEMENT**: Improved error handling with debug logging for JSON parsing failures

### Documentation
- **DOCUMENTATION**: Added Local Models entry to MkDocs navigation for better documentation accessibility

### Technical Changes
- Enhanced provider_fix extension to support multiple error response formats (lib/extensions/ruby_llm/provider_fix.rb)
- Cleaned up debug puts statements from RubyLLMAdapter and provider_fix
- Added robust JSON parsing with fallback error handling

## [0.9.17] - 2025-10-04

### New Features
- **NEW FEATURE**: Enhanced local model support with comprehensive validation and error handling
- **NEW FEATURE**: Added `lms/` prefix support for LM Studio models with automatic validation against loaded models
- **NEW FEATURE**: Enhanced `//models` directive to auto-detect and display local providers (Ollama and LM Studio)
- **NEW FEATURE**: Added model name prefix display in error messages for LM Studio (`lms/` prefix)

### Improvements
- **ENHANCEMENT**: Improved LM Studio integration with model validation against `/v1/models` endpoint
- **ENHANCEMENT**: Enhanced error messages showing exact model names with correct prefixes when validation fails
- **ENHANCEMENT**: Added environment variable support for custom LM Studio API base (`LMS_API_BASE`)
- **ENHANCEMENT**: Improved `//models` directive output formatting for local models with size and modified date for Ollama
- **ENHANCEMENT**: Enhanced multi-model support to seamlessly mix local and cloud models

### Documentation
- **DOCUMENTATION**: Added comprehensive local model documentation to README.md
- **DOCUMENTATION**: Created new docs/guides/local-models.md guide covering Ollama and LM Studio setup, usage, and troubleshooting
- **DOCUMENTATION**: Updated docs/guides/models.md with local provider sections including comparison table and workflow examples
- **DOCUMENTATION**: Enhanced docs/faq.md with 5 new FAQ entries covering local model usage, differences, and error handling

### Technical Changes
- Enhanced RubyLLMAdapter with LM Studio model validation (lib/aia/ruby_llm_adapter.rb)
- Updated models directive to query local provider endpoints (lib/aia/directives/models.rb)
- Added provider_fix extension for RubyLLM compatibility (lib/extensions/ruby_llm/provider_fix.rb)
- Added comprehensive test coverage with 22 new tests for local providers
- Updated dependencies: ruby_llm, webmock, crack, rexml
- Bumped Ruby bundler version to 2.7.2

### Bug Fixes
- **BUG FIX**: Fixed missing `lms/` prefix in LM Studio model listings
- **BUG FIX**: Fixed model validation error messages to show usable model names with correct prefixes
- **BUG FIX**: Fixed Ollama endpoint to use native API (removed incorrect `/v1` suffix)

### Usage Examples
```bash
# Use LM Studio with validation
aia --model lms/qwen/qwen3-coder-30b my_prompt

# Use Ollama
aia --model ollama/llama3.2 --chat

# Mix local and cloud models
aia --model ollama/llama3.2,gpt-4o-mini,claude-3-sonnet my_prompt

# List available local models
aia --model ollama/llama3.2 --chat
> //models
```

## [0.9.16] - 2025-09-26

### New Features
- **NEW FEATURE**: Added support for Ollama AI provider
- **NEW FEATURE**: Added support for Osaurus AI provider
- **NEW FEATURE**: Added support for LM Studio AI provider

### Improvements
- **ENHANCEMENT**: Expanded AI provider ecosystem with three new local/self-hosted model options
- **ENHANCEMENT**: Improved flexibility for users preferring local LLM deployments

## [0.9.15] - 2025-09-21

### New Features
- **NEW FEATURE**: Added `//paste` directive to insert clipboard contents into prompts
- **NEW FEATURE**: Added `//clipboard` alias for the paste directive

### Technical Changes
- Enhanced DirectiveProcessor with clipboard integration using the clipboard gem
- Added comprehensive test coverage for paste directive functionality

## [0.9.14] - 2025-09-19

### New Features
- **NEW FEATURE**: Added `//checkpoint` directive to create named snapshots of conversation context
- **NEW FEATURE**: Added `//restore` directive to restore context to a previous checkpoint
- **NEW FEATURE**: Enhanced `//context` (and `//review`) directive to display checkpoint markers in conversation history
- **NEW FEATURE**: Added `//cp` alias for checkpoint directive

### Improvements
- **ENHANCEMENT**: Context manager now tracks checkpoint positions for better context visualization
- **ENHANCEMENT**: Checkpoint system uses auto-incrementing integer names when no name is provided
- **ENHANCEMENT**: Restore directive defaults to last checkpoint when no name specified
- **ENHANCEMENT**: Clear context now also clears all checkpoints

### Bug Fixes
- **BUG FIX**: Fixed `//help` directive that was showing empty list of directives
- **BUG FIX**: Help directive now displays all directives from all registered modules
- **BUG FIX**: Help directive now shows proper descriptions and aliases for all directives
- **BUG FIX**: Help directive organizes directives by category for better readability

### Technical Changes
- Enhanced ContextManager with checkpoint storage and restoration capabilities
- Added checkpoint_positions method to track checkpoint locations in context
- Refactored help directive to collect directives from all registered modules
- Added comprehensive test coverage for checkpoint and restore functionality

## [0.9.13] - 2025-09-02
### New Features
- **NEW FEATURE**: Added `--tokens` flag to show token counts for each model
- **NEW FEATURE**: Added `--cost` flag to enable cost estimation for each model

### Improvements
- **DEPENDENCY**: Removed versionaire dependency, simplifying version management
- **ENHANCEMENT**: Improved test suite reliability and coverage
- **ENHANCEMENT**: Updated Gemfile.lock with latest dependency versions

### Bug Fixes
- **BUG FIX**: Fixed version handling issues by removing external versioning dependency

### Technical Changes
- Simplified version management by removing versionaire gem
- Enhanced test suite with improved assertions and coverage
- Updated various gem dependencies to latest stable versions

## [0.9.12] - 2025-08-28

### New Features
- **MAJOR NEW FEATURE**: Multi-model support - specify multiple AI models simultaneously with comma-separated syntax
- **NEW FEATURE**: `--consensus` flag to enable primary model consensus mode for synthesized responses from multiple models
- **NEW FEATURE**: `--no-consensus` flag to explicitly force individual responses from all models
- **NEW FEATURE**: Enhanced `//model` directive now shows comprehensive multi-model configuration details
- **NEW FEATURE**: Concurrent processing of multiple models for improved performance
- **NEW FEATURE**: Primary model concept - first model in list serves as consensus orchestrator
- **NEW FEATURE**: Multi-model error handling - invalid models reported but don't prevent valid models from working
- **NEW FEATURE**: Multi-model support in both batch and interactive chat modes
- **NEW FEATURE**: Comprehensive documentation website https://madbomber.github.io/aia/

### Improvements
- **ENHANCEMENT**: Enhanced `//model` directive output with detailed multi-model configuration display
- **ENHANCEMENT**: Improved error handling with graceful fallback when model initialization fails
- **ENHANCEMENT**: Better TTY handling in chat mode to prevent `Errno::ENXIO` errors in containerized environments
- **ENHANCEMENT**: Updated directive processor to use new module-based architecture for better maintainability
- **ENHANCEMENT**: Improved batch mode output file formatting consistency between STDOUT and file output

### Bug Fixes
- **BUG FIX**: Fixed DirectiveProcessor TypeError that prevented application startup with invalid directive calls
- **BUG FIX**: Fixed missing primary model output in batch mode output files
- **BUG FIX**: Fixed inconsistent formatting between STDOUT and file output in batch mode
- **BUG FIX**: Fixed TTY availability issues in chat mode for containerized environments
- **BUG FIX**: Fixed directive processing to use updated module-based registry system

### Technical Changes
- Fixed ruby_llm version to 1.5.1
- Added extra API_KEY configuration for new LLM providers
- Updated RubyLLMAdapter to support multiple model initialization and management
- Enhanced ChatProcessorService output handling for multi-model responses
- Improved Session class TTY error handling with proper exception catching
- Updated CLI parser to support multi-model flags and options
- Enhanced configuration system to support consensus mode settings

### Documentation
- **DOCUMENTATION**: Comprehensive README.md updates with multi-model usage examples and best practices
- **DOCUMENTATION**: Added multi-model section to README with detailed usage instructions
- **DOCUMENTATION**: Updated command-line options table with new multi-model flags
- **DOCUMENTATION**: Added practical multi-model examples for decision-making scenarios

### Usage Examples
```bash
# Basic multi-model usage
aia my_prompt -m gpt-4o-mini,gpt-3.5-turbo

# Enable consensus mode for synthesized response
aia my_prompt -m gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini --consensus

# Multi-model chat mode
aia --chat -m gpt-4o-mini,gpt-3.5-turbo

# View current multi-model configuration
//model  # Use in any prompt or chat session
```

### Migration Notes
- Existing single-model usage remains unchanged and fully compatible
- Multi-model is opt-in via comma-separated model names
- Default behavior without `--consensus` flag shows individual responses from all models
- Invalid model names are reported but don't prevent valid models from working

### TODO
- TODO: focus on log file consistency using Logger


## [0.9.11] - 2025-07-31
- added a cost per 1 million input tokens to available_models query output
- updated ruby_llm to version 1.4.0
- updated all other gem dependencies to their latest versions

## [0.9.10] - 2025-07-18
- updated ruby_llm-mcp to version 0.6.1 which solves problems with MCP tools not being installed

## [0.9.9] - 2025-07-10
- refactored the Session and Config classes into more testable method_missing
- updated the test suire for both the Session and Config classes
- added support for MCP servers coming into AIA via the shared_tools gem
- added +RubyLLM::MCP.support_complex_parameters! to patch ruby_llm gem until such time as it supports the more complex optional parameters in tool calls
- added an examples/tools/mcp directory with 2 MCP client definitions
- updated to ruby_llm-mcp gem version 0.5.1
- //model directive now dumps full model details
- //available_models now has context window size and capabilities for each model returned


## [0.9.8] - 2025-06-25
- fixing an issue with pipelined prompts
- now showing the complete modality of the model on the processing line.
- changed -p option from prompts_dir to pipeline
- found problem with simple cov and deep cov w/r/t their reported test coverage; they have problems with heredoc and complex conditionals.

## [0.9.7] - 2025-06-20

- **NEW FEATURE**: Added `--available_models` CLI option to list all available AI models
- **NEW FEATURE**: Added `//tools` to show a list of available tools and their description
- **BUG FIX**: Fixed SharedTools compatibility issue with models that don't support function calling
- **BUG FIX**: Fixed problem with piped text through STDIN not being handled correctly.
- **BUG FIX**: Fixed issue with output going to the default out_file evenhen --no-out_file is specified.
- **BUG FIX**: Fixed issue with executable prompt files by adding the --exec option
- **DOCUMENTATION**: Updated README for better clarity and structure
- **DEPENDENCY**: Updated Gemfile.lock with latest dependency versions

## [0.9.6] - 2025-06-13
- fixed issue 84 with the //llms directive
- changed the monkey patch to the RubyLLM::Model::Modalities class at the suggestions of the RubyLLM author in prep for a PR against that gem.
- added the shared_tools gem - need to add examples on how to use it with the --tools option
- added the ruby_llm-mcp gem in prep for MCP support in a later version
- added images/aia.png to README.md
- let claude code rewrite the README.md file.  Some details were dropped but overall in reads better.  Need to add the details to a wiki or other documentation site.

## [0.9.5] - 2025-06-04
- changed the RubyLLM::Modalities class to use method_missing for mode query
- hunting for why the //llms query directive is not finding image_to_image LLMs.

## [0.9.4] - 2025-06-03
- using RubyLLM v1.3.0
- setting up a docs infrastructure to behave like the ruby_llm gem's guides side
- fixed bug in the text-to-image workflow
- discovered that ruby_llm does not have high level support for audio modes
- need to pay attention to the test suite
- also need to ensure the non text2text modes are working

## [0.9.3rc1] - 2025-05-24
- using ruby_llm v1.3.0rc1
- added a models database refresh based on integer days interval with the --refresh option
- config file now has a "last_refresh" String in format YYYY-MM-DD
- enhanced the robot figure to show more config items including tools
- fixed bug with the --require option with the specified libraries were not being loaded.
- fixed a bug in the prompt_manager gem which is now at v0.5.5


## [0.9.2] - 2025-05-18
- removing the MCP experiment
- adding support for RubyLLM::Tool usage in place of the MCP stuff
- updated prompt_manager to v0.5.4 which fixed shell integration problem

## [0.9.1] - 2025-05-16
- rethink MCP approach in favor of just RubyLLM::Tool
- fixed problem with //clear
- fixed a problem with a priming prompt in a chat loop

## [0.9.0] - 2025-05-13
- Adding experimental MCP Client support
- removed the CLI options --erb and --shell but kept them in the config file with a default of true for both

## [0.8.6] - 2025-04-23
- Added a client adapter for the ruby_llm gem
- Added the adapter config item and the --adapter option to select at runtime which client to use ai_client or ruby_llm

## [0.8.5] - 2025-04-19
- documentation updates
- integrated the https://pure.md web service for inserting web pages into the context window
   - //include http?://example.com/stuff
   - //webpage http?://example.com/stuff

## [0.8.2] - 2025-04-18
- fixed problems with pre-loaded context and chat repl
- piped content into `aia --chat` is now a part of the context/instructions
- content via "aia --chat < some_file" is added to the context/instructions
- `aia --chat context_file.txt context_file2.txt` now works
- `aia --chat prompt_id context)file.txt` also works

## [0.8.1] - 2025-04-17
- bumped version to 0.8.1 after correcting merge conflicts

## [0.8.0] - 2025-04-15
- Updated PromptManager to v0.5.1 which has some of the functionality that was originally developed in the AIA.
- Enhanced README.md to include a comprehensive table of configuration options with defaults and associated environment variables.
- Added a note in README.md about the expandability of configuration options from a config file for dynamic prompt generation.
- Improved shell command protection by ensuring dangerous patterns are checked and confirmed before execution.
- Ensured version consistency across `.version`, `aia.gemspec`, and `lib/aia/version.rb`.
- Verified and updated documentation to ensure readiness for release on RubyGems.org.

## [0.7.1] - 2025-03-22
- Added `UIPresenter` class for handling user interface presentation.
- Added `DirectiveProcessor` class for processing chat-based directives.
- Added `HistoryManager` class for managing conversation and variable history.
- Added `ShellCommandExecutor` class for executing shell commands.
- Added `ChatProcessorService` class for managing conversation processing logic.
- Added `PromptProcessor` class for processing prompts.
- Enhanced `Session` class to manage interactive session logic.
- Updated `Config` class to handle new configuration options and defaults.
- Improved handling of chat prompts and AI interactions.
- Added support for dynamic content processing in prompts, including shell commands and ERB.
- Improved error handling and user feedback for directive processing.
- Enhanced logging and output options for chat sessions.

## [0.7.0] - 2025-03-17
- Major code refactoring for better organization and maintainability:
  - Extracted `DirectiveProcessor` class to handle chat-based directives
  - Extracted `HistoryManager` class for conversation and variable history management
  - Extracted `UIPresenter` class for UI-related functionality
  - Extracted `ChatProcessorService` class for prompt processing and AI interactions
  - Significantly reduced complexity of the `Session` class by applying separation of concerns
- Enhanced the `//clear` directive to properly reset conversation context
- Improved output handling to suppress STDOUT when chat mode is off and output file is specified
- Updated spinner format in the process_prompt method for better user experience

## [0.6.?] - WIP
- Implemented Tony Stark's Clean Slate Protocol on the develop branch

## [0.5.17] - 2024-05-17
- removed replaced `semver` with `versionaire`

## [0.5.16] - 2024-04-02
- fixed prompt pipelines
- added //next and //pipeline directives as shortcuts to //config [next,pipeline]
- Added new backend "client" as an internal OpenAI client
- Added --sm, --speech_model default: tts-1
- Added --tm, --transcription_model default: whisper-1
- Added --voice default: alloy (if "siri" and Mac? then uses cli tool "say")
- Added --image_size and --image_quality (--is --iq)

## [0.5.15] - 2024-03-30
- Added the ability to accept piped in text to be appended to the end of the prompt text: curl $URL | aia ad_hoc
- Fixed bugs with entering directives as follow-up prompts during a chat session

## [0.5.14] - 2024-03-09
- Directly access OpenAI to do text to speech when using the `--speak` option
- Added --voice to specify which voice to use
- Added --speech_model to specify which TTS model to use

## [0.5.13] - 2024-03-03
- Added CLI-utility `llm` as a backend processor

## [0.5.12] - 2024-02-24
- Happy Birthday Ruby!
- Added --next CLI option
- Added --pipeline CLI option

## [0.5.11] - 2024-02-18
- allow directives to return information that is inserted into the prompt text
- added //shell command directive
- added //ruby ruby_code directive
- added //include path_to_file directive

## [0.5.10] - 2024-02-03
- Added --roles_dir to isolate roles from other prompts if desired
- Changed --prompts to --prompts_dir to be consistent
- Refactored common fzf usage into its own tool class

## [0.5.9] - 2024-02-01
- Added a "I'm working" spinner thing when "--verbose" is used as an indication that the backend is in the process of composing its response to the prompt.

## [0.5.8] - 2024-01-17
- Changed the behavior of the --dump option.  It must now be followed by path/to/file.ext where ext is a supported config file format: yml, yaml, toml

## [0.5.7] - 2024-01-15
- Added ERB processing to the config_file

## [0.5.6] - 2024-01-15
- Adding processing for directives, shell integration and erb to the follow up prompt in a chat session
- some code refactoring.

## [0.5.3] - 2024-01-14
- adding ability to render markdown to the terminal using the "glow" CLI utility

## [0.5.2] - 2024-01-13
- wrap response when its going to the terminal

## [0.5.1] - 2024-01-12
- removed a wicked puts "loaded" statement
- fixed missed code when the options were changed to --out_file and --log_file
- fixed completion functions by updating $PROMPT_DIR to $AIA_PROMPTS_DIR to match the documentation.

## [0.5.0] - 2024-01-05
- breaking changes:
    - changed `--config` to `--config_file`
    - changed `--env` to `--shell`
    - changed `--output` to `--out_file`
        - changed default `out_file` to `STDOUT`

## [0.4.3] - 2023-12-31
- added --env to process embedded system environment variables and shell commands within a prompt.
- added --erb to process Embedded RuBy within a prompt because have embedded shell commands will only get you in a trouble.  Having ERB will really get you into trouble.  Remember the simple prompt is usually the best prompt.

## [0.4.2] - 2023-12-31
- added the --role CLI option to pre-pend a "role" prompt to the front of a primary prompt.

## [0.4.1] - 2023-12-31
- added a chat mode
- prompt directives now supported
- version bumped to match the `prompt_manager` gem

## [0.3.20] - 2023-12-28
- added work around to issue with multiple context files going to the `mods` backend
- added shellwords gem to sanitize prompt text on the command line

## [0.3.19] - 2023-12-26
- major code refactoring.
- supports config files \*.yml, \*.yaml and \*.toml
- usage implemented as a man page. --help will display the man page/
- added "--dump <yml|yaml|toml>" to send current configuration to STDOUT
- added "--completion <bash|fish|zsh>" to send a a completion function for the indicated shell to STDOUT
- added system environment variable (envar) over-rides of default config values uppercase environment variables prefixed with "AIA_" + config item name for example AIA_PROMPTS_DIR and AIA_MODEL.  All config items can be over-ridden by their corresponding envars.
- config value hierarchy is:
    1. values from config file  over-rides ...
    2. command line values      over-rides ...
    3. envar values             over-rides ...
    4. default values

## [0.3.0] - 2023-11-23

- Matching version to [prompt_manager](https://github.com/prompt_manager) This version allows for the user of history in the entry of values to prompt keywords.  KW_HISTORY_MAX is set at 5.  Changed CLI interaction to use historical selection and editing of prior keyword values.

## [0.1.0] - 2023-11-23

- Initial release
