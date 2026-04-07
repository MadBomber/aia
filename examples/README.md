# AIA Examples — Batch Mode

These demo scripts progressively illustrate AIA's batch mode capabilities. Each script is self-contained and builds on concepts from earlier demos.

## Prerequisites

- AIA installed (`gem install aia`)
- Ollama installed and running (`ollama serve`)
- Run the setup script first:

```bash
cd examples
bash 00_setup_aia.sh
```

The setup script pulls the `qwen3` model and writes `aia_config.yml`, which all demos use via the `-c` flag for isolated, reproducible runs.

### Using Your Own API Keys and Models

These demos default to Ollama with the `qwen3` model so they run locally with no API keys required. However, local models can be slow depending on your hardware — some demos may take a while to complete.

For a faster experience, consider using a cloud provider's least expensive tool-capable model. Both `gpt-4o-mini` (OpenAI) and `claude-haiku-4-5` (Anthropic) are inexpensive, fast, support tool use, and will run these demos for pennies. You can easily change the setup to use any provider and model available through the [ruby_llm](https://rubyllm.com) gem. AIA supports OpenAI, Anthropic, Google Gemini, DeepSeek, Mistral, Perplexity, OpenRouter, AWS Bedrock, and local providers like Ollama and LM Studio.

To switch providers, edit `aia_config.yml` and change the model name:

```yaml
models:
  - name: gpt-4o-mini           # OpenAI  — fast and cheap
  - name: claude-haiku-4-5      # Anthropic — fast and cheap
  - name: gemini-2.0-flash      # Google
  - name: ollama/qwen3          # Ollama (local, no API key needed)
```

Set the corresponding API key as an environment variable (e.g., `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`). See the [RubyLLM configuration guide](https://rubyllm.com/configuration) for the full list of supported providers and their settings.

## Demo Scripts

### 00 — Setup

`00_setup_aia.sh` — Verifies that `aia` and `ollama` are installed, pulls the `qwen3` model, creates the `prompts_dir/` directory, and writes `aia_config.yml`. Run this once before any other demo.

Docs: [Getting Started](https://madbomber.github.io/aia/guides/getting-started/), [Installation](https://madbomber.github.io/aia/installation/), [Local Models](https://madbomber.github.io/aia/guides/local-models/)

### 01 — Basic Usage

`01_basic_usage.sh` — The simplest case: send a prompt file to a model and print the response. Demonstrates the `-c` config flag and `--no-output` to suppress file output.

Docs: [Basic Usage](https://madbomber.github.io/aia/guides/basic-usage/), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 02 — YAML Front Matter

`02_frontmatter.sh` — Shows how YAML front matter between `---` delimiters can embed configuration directly in a prompt file. Demonstrates the `temperature` shorthand to make responses more creative.

**Supported front matter keys:** `model`, `temperature`, `top_p`, `next`, `pipeline`, `shell`, `erb`

Docs: [Configuration](https://madbomber.github.io/aia/configuration/), [Prompt Management](https://madbomber.github.io/aia/prompt_management/)

### 03 — Shell Integration

`03_shell_integration.sh` — Demonstrates `$(command)` and `$ENVAR` expansion in prompts. Part 1 shows shell expansion on (default); Part 2 uses `shell: false` in front matter to pass the raw `$(...)` text through to the model.

Docs: [Advanced Prompting](https://madbomber.github.io/aia/advanced-prompting/), [Configuration](https://madbomber.github.io/aia/configuration/)

### 04 — ERB Templating

`04_erb_templating.sh` — Demonstrates `<%= expression %>` ERB tags in prompts. Part 1 shows ERB evaluation on (default); Part 2 uses `erb: false` in front matter to send the literal ERB tags to the model.

Docs: [Advanced Prompting](https://madbomber.github.io/aia/advanced-prompting/), [Configuration](https://madbomber.github.io/aia/configuration/)

### 05 — Shell Then ERB

`05_shell_then_erb.sh` — Demonstrates that shell expansion runs before ERB processing. Shell output becomes part of the Ruby expression that ERB evaluates. For example, `<%= "$(uname -s)".downcase %>` first expands to `<%= "Darwin".downcase %>`, then ERB produces `darwin`.

Docs: [Advanced Prompting](https://madbomber.github.io/aia/advanced-prompting/)

### 06 — Prompt Chaining

`06_prompt_chaining.sh` — Chains two prompts so the output of the first becomes context for the second. Part 1 uses the `--next` CLI flag; Part 2 uses the `next:` front matter key. Both produce the same result.

Docs: [Workflows and Pipelines](https://madbomber.github.io/aia/workflows-and-pipelines/), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 07 — Pipeline

`07_pipeline.sh` — Runs a four-step pipeline where each prompt refines the previous response: brainstorm names, evaluate them, pick the best, write a tagline. Uses `--pipeline` with comma-separated prompt IDs. Notes that the same chain can be defined via `pipeline:` in front matter.

Docs: [Workflows and Pipelines](https://madbomber.github.io/aia/workflows-and-pipelines/), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 08 — Context Files

`08_context_files.sh` — Attaches external file contents to a prompt using positional arguments after the prompt ID. The model receives both the prompt and the file contents, allowing it to reference them in its response.

Docs: [Basic Usage](https://madbomber.github.io/aia/guides/basic-usage/), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 09 — Roles

`09_roles.sh` — Demonstrates `--role` to prepend a reusable system prompt. Role files live in `prompts_dir/roles/` as `.md` files. Runs the same prompt three ways: no role (baseline), `--role pirate`, and `--role formal`, showing how roles change the response style.

Docs: [Working with Models — Per-Model Roles](https://madbomber.github.io/aia/guides/models/#per-model-roles), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 10 — STDIN Piping

`10_stdin_piping.sh` — Pipes text into AIA via STDIN. The piped content is appended to the prompt. Part 1 pipes a string with `echo`; Part 2 pipes the output of `ls -la`.

Docs: [Executable Prompts — Piping and Redirection](https://madbomber.github.io/aia/guides/executable-prompts/#piping-and-redirection), [Basic Usage](https://madbomber.github.io/aia/guides/basic-usage/)

### 11 — Multiple Models

`11_multi_model.sh` — Sends the same prompt to two models simultaneously using `-m model1,model2`. Part 1 shows **comparison mode** (default) where both responses are displayed side by side. Part 2 shows **cooperative mode** (`--consensus`) where the first model synthesizes a unified answer from both responses.

**Requires:** A second Ollama model (`phi4-mini`), auto-pulled if missing.

Docs: [Working with Models — Multi-Model Operations](https://madbomber.github.io/aia/guides/models/#multi-model-operations), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 12 — Token Usage

`12_token_usage.sh` — Demonstrates the `--tokens` flag, which displays input/output token counts after each response. Part 1 shows single-model usage; Part 2 shows a multi-model comparison table.

Docs: [Working with Models — Token Usage and Cost Tracking](https://madbomber.github.io/aia/guides/models/#token-usage-and-cost-tracking), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 13 — Cost Tracking

`13_cost_tracking.sh` — Demonstrates the `--cost` flag, which adds per-model cost estimates to the token usage table. Uses `gpt-4o-mini` (OpenAI) and `claude-haiku-4-5` (Anthropic) for a cross-provider cost comparison. `--cost` implies `--tokens`.

**Requires:** `OPENAI_API_KEY` and `ANTHROPIC_API_KEY` environment variables.

Docs: [Working with Models — Token Usage and Cost Tracking](https://madbomber.github.io/aia/guides/models/#token-usage-and-cost-tracking), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 14 — Output to File

`14_output_file.sh` — Demonstrates the `-o` flag for saving responses to a file. Part 1 writes to a file; Part 2 shows the default overwrite behavior; Part 3 uses `--append` to accumulate multiple responses in the same file.

Docs: [Basic Usage — Output Management](https://madbomber.github.io/aia/guides/basic-usage/#3-output-management), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 15 — Parameters

`15_parameters.sh` — Demonstrates prompt parameters defined in YAML front matter. Parameters create reusable templates with `<%= name %>` placeholders filled at runtime. Part 1 uses a prompt where all parameters have defaults (runs automatically). Part 2 has a required parameter (null default) that AIA prompts the user to enter interactively.

Docs: [Prompt Management](https://madbomber.github.io/aia/prompt_management/), [Advanced Prompting](https://madbomber.github.io/aia/advanced-prompting/)

### 16 — Directives

`16_directives.sh` — Lists all available directives and demonstrates two features. Part 1 uses the `include` directive, which inserts and renders another prompt file at render time via `<%= include 'path/to/file' %>`. Part 2 shows how to create a custom directive: a Ruby class inheriting from `AIA::Directive` with `desc`-annotated methods. The custom `timestamp` directive is loaded via `--tools` and used in a prompt with `<%= timestamp %>`.

Docs: [Directives Reference](https://madbomber.github.io/aia/directives-reference/), [Advanced Prompting](https://madbomber.github.io/aia/advanced-prompting/)

### 17 — Require and Conditionals

`17_require_and_conditionals.sh` — Two ERB power features. Part 1 uses `--rq json` to load the `json` gem so `JSON.pretty_generate` works inside ERB tags. Part 2 uses `<% if %>` / `<% elsif %>` / `<% else %>` control flow with a parameter to conditionally include different prompt sections based on the audience.

Docs: [Advanced Prompting — Conditional Execution](https://madbomber.github.io/aia/advanced-prompting/#conditional-execution), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 18 — Tools via --require

`18_tools.sh` — Loads `RubyLLM::Tool` subclasses from the `shared_tools` gem via `--rq shared_tools`. AIA discovers tools automatically and registers them for the model to call. The prompt asks three questions that require calling `current_date_time`, `system_info`, and `dns` tools.

**Requires:** `gem install shared_tools`

Docs: [Shared Tools](https://madbomber.github.io/aia/guides/shared-tools/), [Tools Integration](https://madbomber.github.io/aia/guides/tools/)

### 19 — Local Tools

`19_local_tools.sh` — Loads a local `RubyLLM::Tool` from a `.rb` file using `--tools tools/word_count_tool.rb`. Shows the full tool pattern: class definition, description, parameters, and execute method. The model calls the tool to analyze a text passage.

Docs: [Tools Integration — Creating Custom Tools](https://madbomber.github.io/aia/guides/tools/#creating-custom-tools), [CLI Reference](https://madbomber.github.io/aia/cli-reference/)

### 20 — MCP Servers

`20_mcp_servers.sh` — Demonstrates MCP (Model Context Protocol) server integration. Part 1 loads an MCP server from a JSON file via `--mcp mcp/filesystem.json` (Claude Desktop format). Part 2 uses `aia_config_with_mcp.yml` where the MCP server is defined in YAML within the config file itself.

**Requires:** Node.js / `npx` (for the `@modelcontextprotocol/server-filesystem` server).

Docs: [MCP Integration](https://madbomber.github.io/aia/mcp-integration/), [Configuration — MCP Server Configuration](https://madbomber.github.io/aia/configuration/#mcp-server-configuration)

### 21 — Executable Prompts

`21_executable_prompts.sh` — Demonstrates prompt files with a shebang line (`#!/usr/bin/env aia ...`) that can be run directly from the command line. AIA auto-detects the shebang and strips it before processing. Part 1 runs a minimal executable prompt directly. Part 2 runs an executable prompt that combines front matter, ERB, and shell expansion. Part 3 pipes a prompt file (shebang included) to AIA via STDIN, showing that the shebang is stripped automatically from piped input too.

Docs: [Executable Prompts](https://madbomber.github.io/aia/guides/executable-prompts/)

### 22 — Chat Mode

`22_chat_mode.sh` — Demonstrates interactive chat mode via the `--chat` flag. Uses `expect` to script the interactive sessions. Part 1 opens a pure chat with no initial prompt. Part 2 processes a prompt in batch mode first, then enters chat with that context in the conversation history. Part 3 runs a full pipeline (brainstorm, evaluate, pick best) to completion, then enters chat for follow-up questions about the results. Part 4 shows chat-mode directives like `/help`. The key takeaway: all batch processing completes before the chat session begins, and the model retains full context from the batch phase.

**Requires:** `expect` (pre-installed on macOS).

Docs: [Chat Guide](https://madbomber.github.io/aia/guides/chat/), [Directives Reference](https://madbomber.github.io/aia/directives-reference/), [Workflows and Pipelines](https://madbomber.github.io/aia/workflows-and-pipelines/)

### 23 — Verify Mode

`23_verify.sh` — Demonstrates `/verify` mode via `VerificationNetwork`. Two robots independently answer the same question with slightly different system prompts, then a third reconciler robot compares both answers and produces a final verified response. Part 1 verifies a factual question (causes of the 2008 financial crisis); Part 2 verifies a technical explanation (TCP three-way handshake).

**Requires:** `expect` (pre-installed on macOS).

Docs: [Advanced Prompting](https://madbomber.github.io/aia/advanced-prompting/), [Chat Guide](https://madbomber.github.io/aia/guides/chat/)

### 24 — Decompose Mode

`24_decompose.sh` — Demonstrates `/decompose` mode via `PromptDecomposer`. A coordinator robot analyzes whether a prompt can be split into 2–5 independent sub-tasks. If decomposable, specialist robots run each in parallel and results are synthesized into a single coherent response. Falls back to normal mode if the prompt is not decomposable. Part 1 uses a complex multi-part TCP/UDP question; Part 2 demonstrates the fallback with a simple question.

**Requires:** `expect` (pre-installed on macOS).

Docs: [Advanced Prompting](https://madbomber.github.io/aia/advanced-prompting/), [Chat Guide](https://madbomber.github.io/aia/guides/chat/)

### 25 — Spawn Mode

`25_spawn.sh` — Demonstrates `/spawn` mode via `SpawnHandler`. Dynamically creates a specialist robot on demand. Part 1 explicitly names a specialist type (`/spawn security-expert`) and asks a SQL injection question. Part 2 uses auto-detection (`/spawn` with no args) where the primary robot determines the needed expertise from the question content. Specialists are cached and reused within the session.

**Requires:** `expect` (pre-installed on macOS).

Docs: [Advanced Prompting](https://madbomber.github.io/aia/advanced-prompting/), [Chat Guide](https://madbomber.github.io/aia/guides/chat/)

### 26 — Debate Mode

`26_debate.sh` — Demonstrates `/debate` mode via `DebateHandler`. Two robots debate a topic across multiple rounds. Each round, every robot sees what the other said and responds. The debate ends when a robot says CONVERGED or after 5 rounds. `SimilarityScorer` also detects convergence by comparing round-to-round similarity. Uses `qwen3` (Tobor) vs `phi4-mini` (Quark) debating REST vs GraphQL.

**Requires:** `expect` (pre-installed on macOS), `phi4-mini` model (auto-pulled if missing).

Docs: [Advanced Prompting](https://madbomber.github.io/aia/advanced-prompting/), [Working with Models](https://madbomber.github.io/aia/guides/models/)

### 27 — @mention Routing

`27_mention_routing.sh` — Demonstrates `@mention` routing in a multi-model network. Prefixing a message with `@RobotName` directs it to a specific robot; only that robot responds. Robot names are assigned by AIA: `qwen3` becomes `Tobor`, `phi4-mini` becomes `Quark`. Part 1 routes to `@Tobor`; Part 2 routes to `@Quark`; Part 3 shows how an unknown `@mention` triggers a listing of available robot names. Part 4 opens interactive chat to mix directed and undirected turns freely.

**Requires:** `expect` (pre-installed on macOS), `phi4-mini` model (auto-pulled if missing).

Docs: [Chat Guide](https://madbomber.github.io/aia/guides/chat/), [Working with Models](https://madbomber.github.io/aia/guides/models/)

### 28 — Model Switching

`28_model_switching.sh` — Demonstrates the `/model` directive for switching models mid-conversation. Conversation history is transferred to the new model so it has full context of everything discussed before the switch. Part 1 asks a question with `qwen3` (Tobor), switches to `phi4-mini` (Quark) via `/model ollama/phi4-mini`, then asks a follow-up that requires the previous exchange for context.

**Requires:** `expect` (pre-installed on macOS), `phi4-mini` model (auto-pulled if missing).

Docs: [Chat Guide](https://madbomber.github.io/aia/guides/chat/), [Working with Models](https://madbomber.github.io/aia/guides/models/)

## Running All Demos

`run_all.sh` runs all non-interactive demo scripts in sequence and captures the combined output. It serves as a structural integration test — since LLM responses are non-deterministic, exact diffs between runs won't match, but you can spot missing sections, crashes, or changed command output.

```bash
cd examples

# Run all demos and save output to a timestamped log
bash run_all.sh

# Print to terminal only (no log file)
bash run_all.sh --no-save

# Save to your own file with tee
bash run_all.sh --no-save 2>&1 | tee my_run.log

# Show help
bash run_all.sh --help
```

Output logs are saved to `examples/output/run_YYYYMMDD_HHMMSS.log`. Compare runs with:

```bash
diff output/run_PREV.log output/run_LATEST.log
```

**What it runs:** Scripts 01-14, 16-19, and 21 (18 scripts total).

**What it skips:**

| Script | Reason |
|--------|--------|
| `00_setup_aia.sh` | Run manually first (pulls models, writes config) |
| `15_parameters.sh` | Part 2 prompts interactively for a required parameter |
| `20_mcp_servers.sh` | Requires Node.js/npx + MCP filesystem server |
| `22_chat_mode.sh` | Interactive chat session (uses `expect`) |
| `23_verify.sh` | Uses `expect` for interactive chat |
| `24_decompose.sh` | Uses `expect` for interactive chat |
| `25_spawn.sh` | Uses `expect` for interactive chat |
| `26_debate.sh` | Uses `expect` for interactive chat |
| `27_mention_routing.sh` | Uses `expect` for interactive chat |
| `28_model_switching.sh` | Uses `expect` for interactive chat |

The output includes a banner with version info, per-script pass/fail status, and a summary with counts.

## Directory Structure

```
examples/
  common.sh                    # Shared setup sourced by all demos
  run_all.sh                   # Batch runner for non-interactive demos
  aia_config.yml               # Generated by 00_setup_aia.sh
  aia_config_with_mcp.yml      # Config with MCP server (demo 20)
  prompts_dir/                 # All demo prompt files
    roles/                     # Role files (demo 09)
    includes/                  # Includable files (demo 16)
  context/                     # Context files (demo 08)
  directives/                  # Custom directive files (demo 16)
  tools/                       # Local tool files (demo 19)
  mcp/                         # MCP server configs (demo 20)
  output/                      # Timestamped run logs (git-ignored)
```

## Notes

- All demos use `-c aia_config.yml` to isolate from your personal AIA configuration. The `-c` flag replaces your user config with bundled defaults plus the specified file.
- `common.sh` clears all `AIA_*` environment variables to prevent leakage from your shell.
- Demos 11-12 require a second Ollama model (`phi4-mini`), which is auto-pulled.
- Demo 13 requires cloud API keys for OpenAI and Anthropic.
- Demo 18 requires the `shared_tools` gem.
- Demo 20 requires Node.js for the MCP filesystem server.

## Full Documentation

For complete AIA documentation, visit the [AIA documentation site](https://madbomber.github.io/aia/).
