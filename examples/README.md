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

`16_directives.sh` — Lists all available directives and demonstrates the `include` directive, which inserts and renders another prompt file at render time via `<%= include 'path/to/file' %>`. The demo includes a facts file into a quiz prompt.

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

## Directory Structure

```
examples/
  common.sh                    # Shared setup sourced by all demos
  aia_config.yml               # Generated by 00_setup_aia.sh
  aia_config_with_mcp.yml      # Config with MCP server (demo 20)
  prompts_dir/                 # All demo prompt files
    roles/                     # Role files (demo 09)
    includes/                  # Includable files (demo 16)
  context/                     # Context files (demo 08)
  tools/                       # Local tool files (demo 19)
  mcp/                         # MCP server configs (demo 20)
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
