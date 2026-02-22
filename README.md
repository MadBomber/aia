<div align="center">
  <h1>AI Assistant (AIA)</h1>
  <img src="docs/assets/images/aia.png" alt="Robots waiter ready to take your order."><br />
  **The Prompt is the Code**<br />
  <p>Check out the new <a href="http://madbomber.github.io/aia/guides/models/?h=inline+role+syntax#inline-role-syntax">Inline Role Syntax</a> when working with multiple concurrent models.</p>
</div>

---

<details>
<summary><strong>Upgrading from v0.x?</strong> Click to see migration notes.</summary>

- **Prompt files** now use `.md` extension. Run `bin/migrate_prompts ~/.prompts` to convert existing prompts.
- **Environment variables** use double underscore (`__`) for nested config sections (e.g., `AIA_LLM__TEMPERATURE`, `AIA_FLAGS__DEBUG`).
- **Configuration files** use a nested YAML structure with sections like `llm:`, `prompts:`, `output:`, `flags:`, etc. See [defaults.yml](lib/aia/config/defaults.yml) for the complete schema.
- **File locations** follow the XDG Base Directory Specification. Config file is now at `~/.config/aia/aia.yml`.

See the [Configuration Guide](https://madbomber.github.io/aia/configuration/) for details.

</details>

---

AIA is a command-line utility that facilitates interaction with AI models through dynamic prompt management. It automates the management of pre-compositional prompts and executes generative AI commands with enhanced features including embedded directives, shell integration, embedded Ruby, history management, interactive chat, and prompt workflows.

AIA leverages the following Ruby gems:

- **[pm](https://github.com/madbomber/prompt_manager)** to manage prompts,
- **[ruby_llm](https://rubyllm.com)** to access LLM providers,
- **[ruby_llm-mcp](https://www.rubyllm-mcp.com)** for Model Context Protocol (MCP) support,
- and can use the **[shared_tools gem](https://github.com/madbomber/shared_tools)** which provides a collection of common ready-to-use MCP clients and functions for use with LLMs that support tools.

For more information on AIA visit these locations:

- **[The AIA Docs Website](https://madbomber.github.io/aia)**<br />
- **[Blog Series on AIA](https://madbomber.github.io/blog/engineering/AIA-Philosophy/)**

## Quick Start

1. **Install AIA:**
   ```bash
   gem install aia
   ```

2. **Install dependencies:**
   ```bash
   brew install fzf
   ```

3. **Create your first prompt:**
   ```bash
   mkdir -p ~/.prompts
   echo "What is [TOPIC]?" > ~/.prompts/what_is.md
   ```

4. **Run your prompt:**
   ```bash
   aia what_is
   ```
   You'll be prompted to enter a value for `[TOPIC]`, then AIA will send your question to the AI model.

5. **Start an interactive chat:**
   ```bash
   aia --chat

   # Or use multiple models for comparison
   aia --chat -m gpt-4o-mini,gpt-3.5-turbo
   ```

```plain

       ,      ,
       (\____/) AI Assistant (v1.0.0) is Online
        (_oo_)   gpt-4o-mini
         (O)       using ruby_llm
       __||__    \) model db was last refreshed on
     [/______\]  /    2025-06-18
    / \__AI__/ \/      You can share my tools
   /    /__\
  (\   /____\

```

---

## Concurrent Multi-Model Comparison

One of AIA's most powerful features is the ability to send a single prompt to multiple AI models simultaneously and compare their responses side-by-side—complete with token usage and cost tracking.

```bash
# Compare responses from 3 models with token counts and cost estimates
aia --chat -m gpt-4o,claude-3-5-sonnet,gemini-1.5-pro --tokens --cost
```

**Example output:**
```
You: What's the best approach for handling database migrations in a microservices architecture?

from: gpt-4o
Use a versioned migration strategy with backward compatibility...

from: claude-3-5-sonnet
Consider the Expand-Contract pattern for zero-downtime migrations...

from: gemini-1.5-pro
Implement a schema registry with event-driven synchronization...

┌─────────────────────────────────────────────────────────────────┐
│ Model               │ Input Tokens │ Output Tokens │ Cost      │
├─────────────────────────────────────────────────────────────────┤
│ gpt-4o              │ 156          │ 342           │ $0.0089   │
│ claude-3-5-sonnet   │ 156          │ 418           │ $0.0063   │
│ gemini-1.5-pro      │ 156          │ 387           │ $0.0041   │
└─────────────────────────────────────────────────────────────────┘
```

**Why this matters:**
- **Compare reasoning approaches** - See how different models tackle the same problem
- **Identify blind spots** - One model might catch something others miss
- **Cost optimization** - Find the best price/performance ratio for your use case
- **Consensus building** - Use `--consensus` to synthesize the best answer from all models

---

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Installation & Prerequisites](#installation--prerequisites)
    - [Requirements](#requirements)
    - [Installation](#installation)
    - [Setup Shell Completion](#setup-shell-completion)
  - [Basic Usage](#basic-usage)
    - [Command Line Interface](#command-line-interface)
    - [Key Command-Line Options](#key-command-line-options)
    - [Directory Structure](#directory-structure)
  - [Configuration](#configuration)
    - [Essential Configuration Options](#essential-configuration-options)
    - [Configuration Precedence](#configuration-precedence)
    - [Configuration Methods](#configuration-methods)
    - [Complete Configuration Reference](#complete-configuration-reference)
  - [Advanced Features](#advanced-features)
    - [Prompt Directives](#prompt-directives)
      - [Configuration Directive Examples](#configuration-directive-examples)
      - [Dynamic Content Examples](#dynamic-content-examples)
      - [Custom Directive Examples](#custom-directive-examples)
    - [Multi-Model Support](#multi-model-support)
      - [Basic Multi-Model Usage](#basic-multi-model-usage)
      - [Consensus Mode](#consensus-mode)
      - [Individual Responses Mode](#individual-responses-mode)
      - [Model Information](#model-information)
    - [Shell Integration](#shell-integration)
    - [Embedded Ruby (ERB)](#embedded-ruby-erb)
    - [Prompt Sequences](#prompt-sequences)
      - [Using --next](#using---next)
      - [Using --pipeline](#using---pipeline)
      - [Example Workflow](#example-workflow)
    - [Roles and System Prompts](#roles-and-system-prompts)
    - [RubyLLM::Tool Support](#rubyllmtool-support)
    - [MCP Server Configuration](#mcp-server-configuration)
  - [Examples & Tips](#examples--tips)
    - [Practical Examples](#practical-examples)
      - [Code Review Prompt](#code-review-prompt)
      - [Meeting Notes Processor](#meeting-notes-processor)
      - [Documentation Generator](#documentation-generator)
    - [Executable Prompts](#executable-prompts)
    - [Tips from the Author](#tips-from-the-author)
      - [The run Prompt](#the-run-prompt)
      - [The Ad Hoc One-shot Prompt](#the-ad-hoc-one-shot-prompt)
      - [Recommended Shell Setup](#recommended-shell-setup)
      - [Prompt Directory Organization](#prompt-directory-organization)
  - [Security Considerations](#security-considerations)
    - [Shell Command Execution](#shell-command-execution)
    - [Safe Practices](#safe-practices)
    - [Recommended Security Setup](#recommended-security-setup)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
    - [Error Messages](#error-messages)
    - [Debug Mode](#debug-mode)
    - [Performance Issues](#performance-issues)
  - [Development](#development)
    - [Testing](#testing)
    - [Building](#building)
    - [Architecture Notes](#architecture-notes)
  - [Contributing](#contributing)
    - [Reporting Issues](#reporting-issues)
    - [Development Setup](#development-setup)
    - [Areas for Improvement](#areas-for-improvement)
  - [Roadmap](#roadmap)
  - [License](#license)
  - [Articles on AIA](#articles-on-aia)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

## Installation & Prerequisites

### Requirements

- **Ruby**: >= 3.2.0
- **External Tools**:
  - [fzf](https://github.com/junegunn/fzf) - Command-line fuzzy finder

### Installation

```bash
# Install AIA gem
gem install aia

# Install required external tools (macOS)
brew install fzf

# Install required external tools (Linux)
# Ubuntu/Debian
sudo apt install fzf

# Arch Linux
sudo pacman -S fzf
```

### Setup Shell Completion

Get completion functions for your shell:

```bash
# For bash users
aia --completion bash >> ~/.bashrc

# For zsh users
aia --completion zsh >> ~/.zshrc

# For fish users
aia --completion fish >> ~/.config/fish/config.fish
```

## Basic Usage

### Command Line Interface

```bash
# Basic usage
aia [OPTIONS] PROMPT_ID [CONTEXT_FILES...]

# Interactive chat session
aia --chat [--role ROLE] [--model MODEL]

# Use a specific model
aia --model gpt-4 my_prompt

# Specify output file
aia --output result.md my_prompt

# Use a role/system prompt
aia --role expert my_prompt

# Enable fuzzy search for prompts
aia --fuzzy
```

### Key Command-Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--chat` | Start interactive chat session | `aia --chat` |
| `--model MODEL` | Specify AI model(s) to use. Supports `MODEL[=ROLE]` syntax | `aia --model gpt-4o-mini,gpt-3.5-turbo` or `aia --model gpt-4o=architect,claude=security` |
| `--consensus` | Enable consensus mode for multi-model | `aia --consensus` |
| `--no-consensus` | Force individual responses | `aia --no-consensus` |
| `--role ROLE` | Use a role/system prompt (default for all models) | `aia --role expert` |
| `--list-roles` | List available role files | `aia --list-roles` |
| `--output FILE` | Specify output file | `aia --output results.md` |
| `--fuzzy` | Use fuzzy search for prompts | `aia --fuzzy` |
| `--tokens` | Display token usage in chat mode | `aia --chat --tokens` |
| `--cost` | Include cost calculations with token usage | `aia --chat --cost` |
| `--mcp-list` | List configured MCP servers and exit | `aia --mcp-list` |
| `--list-tools` | List available tools and exit | `aia --require shared_tools --list-tools` |
| `--help` | Show complete help | `aia --help` |

### Directory Structure

```
~/.prompts/              # Default prompts directory
├── ask.md              # Simple question prompt
├── code_review.md      # Code review prompt
├── roles/              # Role/system prompts
│   ├── expert.md       # Expert role
│   └── teacher.md      # Teaching role
└── _prompts.log        # History log
```

## Configuration

### Essential Configuration Options

The most commonly used configuration options:

| Option | Default | Description |
|--------|---------|-------------|
| `model` | `gpt-4o-mini` | AI model to use |
| `prompts_dir` | `~/.prompts` | Directory containing prompts |
| `output` | `temp.md` | Default output file |
| `temperature` | `0.7` | Model creativity (0.0-1.0) |
| `chat` | `false` | Start in chat mode |

### Configuration Precedence

AIA determines configuration settings using this order (highest to lowest priority):

1. **Embedded config directives** (in prompt files): `/config model = gpt-4`
2. **Command-line arguments**: `--model gpt-4`
3. **Environment variables**: `export AIA_MODEL=gpt-4`
4. **Configuration files**: `~/.config/aia/aia.yml`
5. **Default values**: [defaults.yml](lib/aia/config/defaults.yml)

**Note:** When `-c` / `--config-file` is used, it replaces the user config and environment variables. Configuration resets to bundled defaults, then the specified file is applied, then CLI arguments take precedence.

### Configuration Methods

**Environment Variables:**
```bash
export AIA_MODEL=gpt-4
export AIA_PROMPTS__DIR=~/my-prompts
export AIA_LLM__TEMPERATURE=0.8
```

**Configuration File** (`~/.config/aia/aia.yml`):
```yaml
models:
  - name: gpt-4
prompts:
  dir: ~/my-prompts
llm:
  temperature: 0.8
flags:
  chat: false
```

**Embedded Directives** (in prompt files):
```
/config model = gpt-4
/config temperature = 0.8

Your prompt content here...
```

### Complete Configuration Reference

<details>
<summary>Click to view all configuration options</summary>

The configuration schema is defined in [defaults.yml](lib/aia/config/defaults.yml). Environment variables use the `AIA_` prefix with double underscores for nested keys.

**Mode & Display Flags:**

| Config Path | CLI Options | Default | Environment Variable |
|-------------|-------------|---------|---------------------|
| `flags.chat` | `--chat` | `false` | `AIA_FLAGS__CHAT` |
| `flags.fuzzy` | `-f`, `--fuzzy` | `false` | `AIA_FLAGS__FUZZY` |
| `flags.debug` | `-d`, `--debug` | `false` | `AIA_FLAGS__DEBUG` |
| `flags.verbose` | `-v`, `--verbose` | `false` | `AIA_FLAGS__VERBOSE` |
| `flags.tokens` | `--tokens` | `false` | `AIA_FLAGS__TOKENS` |
| `flags.cost` | `--cost` | `false` | `AIA_FLAGS__COST` |
| `flags.consensus` | `--[no-]consensus` | `false` | `AIA_FLAGS__CONSENSUS` |
| `flags.speak` | `--speak` | `false` | `AIA_FLAGS__SPEAK` |
| `flags.shell` | | `true` | `AIA_FLAGS__SHELL` |
| `flags.erb` | | `true` | `AIA_FLAGS__ERB` |
| `flags.clear` | `--clear` | `false` | `AIA_FLAGS__CLEAR` |
| `flags.no_mcp` | `--no-mcp` | `false` | `AIA_FLAGS__NO_MCP` |

**Model & LLM Parameters:**

| Config Path | CLI Options | Default | Environment Variable |
|-------------|-------------|---------|---------------------|
| `models` | `-m`, `--model` | `gpt-4o-mini` | `AIA_MODEL` |
| `llm.temperature` | `-t`, `--temperature` | `0.7` | `AIA_LLM__TEMPERATURE` |
| `llm.max_tokens` | `--max-tokens` | `2048` | `AIA_LLM__MAX_TOKENS` |
| `llm.top_p` | `--top-p` | `1.0` | `AIA_LLM__TOP_P` |
| `llm.frequency_penalty` | `--frequency-penalty` | `0.0` | `AIA_LLM__FREQUENCY_PENALTY` |
| `llm.presence_penalty` | `--presence-penalty` | `0.0` | `AIA_LLM__PRESENCE_PENALTY` |

**Prompts & Roles:**

| Config Path | CLI Options | Default | Environment Variable |
|-------------|-------------|---------|---------------------|
| `prompts.dir` | `--prompts-dir` | `~/.prompts` | `AIA_PROMPTS__DIR` |
| `prompts.extname` | | `.md` | `AIA_PROMPTS__EXTNAME` |
| `prompts.roles_prefix` | `--roles-prefix` | `roles` | `AIA_PROMPTS__ROLES_PREFIX` |
| `prompts.roles_dir` | | `~/.prompts/roles` | `AIA_PROMPTS__ROLES_DIR` |
| `prompts.role` | `-r`, `--role` | | `AIA_PROMPTS__ROLE` |
| `prompts.system_prompt` | `--system-prompt` | | `AIA_PROMPTS__SYSTEM_PROMPT` |
| `pipeline` | `-p`, `--pipeline` | `[]` | |
| | `-n`, `--next` | | |

**Output & Files:**

| Config Path | CLI Options | Default | Environment Variable |
|-------------|-------------|---------|---------------------|
| `output.file` | `-o`, `--[no-]output` | `temp.md` | `AIA_OUTPUT__FILE` |
| `output.append` | `-a`, `--[no-]append` | `false` | `AIA_OUTPUT__APPEND` |
| `output.markdown` | `--md`, `--[no-]markdown` | `true` | `AIA_OUTPUT__MARKDOWN` |
| `output.history_file` | `--history-file` | `~/.prompts/_prompts.log` | `AIA_OUTPUT__HISTORY_FILE` |
| `paths.aia_dir` | | `~/.config/aia` | `AIA_PATHS__AIA_DIR` |
| `paths.config_file` | `-c`, `--config-file` | `~/.config/aia/aia.yml` | `AIA_PATHS__CONFIG_FILE` |

**Audio & Image:**

| Config Path | CLI Options | Default | Environment Variable |
|-------------|-------------|---------|---------------------|
| `audio.voice` | `--voice` | `alloy` | `AIA_AUDIO__VOICE` |
| `audio.speak_command` | | `afplay` | `AIA_AUDIO__SPEAK_COMMAND` |
| `audio.speech_model` | `--sm`, `--speech-model` | `tts-1` | `AIA_AUDIO__SPEECH_MODEL` |
| `audio.transcription_model` | `--tm`, `--transcription-model` | `whisper-1` | `AIA_AUDIO__TRANSCRIPTION_MODEL` |
| `image.size` | `--is`, `--image-size` | `1024x1024` | `AIA_IMAGE__SIZE` |
| `image.quality` | `--iq`, `--image-quality` | `standard` | `AIA_IMAGE__QUALITY` |
| `image.style` | `--style`, `--image-style` | `vivid` | `AIA_IMAGE__STYLE` |
| `embedding.model` | | `text-embedding-ada-002` | `AIA_EMBEDDING__MODEL` |

**Tools & MCP:**

| Config Path | CLI Options | Default | Environment Variable |
|-------------|-------------|---------|---------------------|
| `tools.paths` | `--tools` | `[]` | `AIA_TOOLS__PATHS` |
| `tools.allowed` | `--at`, `--allowed-tools` | | `AIA_TOOLS__ALLOWED` |
| `tools.rejected` | `--rt`, `--rejected-tools` | | `AIA_TOOLS__REJECTED` |
| `mcp_servers` | | `[]` | |
| `mcp_use` | `--mu`, `--mcp-use` | | `AIA_MCP_USE` |
| `mcp_skip` | `--ms`, `--mcp-skip` | | `AIA_MCP_SKIP` |
| | `--mcp FILE` | | |
| | `--mcp-list` | | |
| `require_libs` | `--rq`, `--require` | `[]` | |

**Logging:**

| Config Path | CLI Options | Default | Environment Variable |
|-------------|-------------|---------|---------------------|
| `logger.aia.level` | `--log-level` | `warn` | `AIA_LOGGER__AIA__LEVEL` |
| `logger.aia.file` | `--log-to` | `STDOUT` | `AIA_LOGGER__AIA__FILE` |
| `logger.llm.level` | `--log-level` | `warn` | `AIA_LOGGER__LLM__LEVEL` |
| `logger.llm.file` | `--log-to` | `STDOUT` | `AIA_LOGGER__LLM__FILE` |
| `logger.mcp.level` | `--log-level` | `warn` | `AIA_LOGGER__MCP__LEVEL` |
| `logger.mcp.file` | `--log-to` | `STDOUT` | `AIA_LOGGER__MCP__FILE` |
| `registry.refresh` | `--refresh` | `7` (days) | `AIA_REGISTRY__REFRESH` |

**Utility:**

| CLI Options | Description |
|-------------|-------------|
| `--dump FILE` | Export current configuration to FILE and exit |
| `--completion SHELL` | Generate shell completion script (bash/zsh/fish) and exit |
| `--available-models [QUERY]` | List available models and exit |
| `--list-roles` | List available role files and exit |
| `--list-tools` | List available tools and exit |
| `--version` | Show version and exit |
| `-h`, `--help` | Show help and exit |

</details>

## Advanced Features

### Prompt Directives

Directives are special commands in prompt files that begin with `/` and provide dynamic functionality:

| Directive | Description | Example |
|-----------|-------------|---------|
| `/config` | Set configuration values | `/config model = gpt-4` |
| `/context` | Show context for this conversation with checkpoint markers | `/context` |
| `/checkpoint` | Create a named checkpoint of current context | `/checkpoint save_point` |
| `/restore` | Restore context to a previous checkpoint | `/restore save_point` |
| `/include` | Insert file contents | `/include path/to/file.txt` |
| `/paste` | Insert clipboard contents | `/paste` |
| `/skill` | Include a Claude Code skill | `/skill code-quality` |
| `/skills` | List available Claude Code skills | `/skills` |
| `/shell` | Execute shell commands | `/shell ls -la` |
| `/robot` | Show the pet robot ASCII art w/versions | `/robot` |
| `/ruby` | Execute Ruby code | `/ruby puts "Hello World"` |
| `/next` | Set next prompt in sequence | `/next summary` |
| `/pipeline` | Set prompt workflow | `/pipeline analyze,summarize,report` |
| `/clear` | Clear conversation history | `/clear` |
| `/help` | Show available directives | `/help` |
| `/model` | Show current model configuration | `/model` |
| `/available_models` | List available models | `/available_models` |
| `/tools` | Show available tools (optional filter by name) | `/tools` or `/tools file` |
| `/review` | Review current context with checkpoint markers | `/review` |

Directives can also be used in the interactive chat sessions.

#### Configuration Directive Examples

```bash
# Set model and temperature for this prompt
/config model = gpt-4
/config temperature = 0.9

# Enable chat mode and terse responses
/config chat = true
/config terse = true

Your prompt content here...
```

#### Dynamic Content Examples

```bash
# Include file contents
/include ~/project/README.md

# Paste clipboard contents
/paste

# Execute shell commands
/shell git log --oneline -10

# Run Ruby code
/ruby require 'json'; puts JSON.pretty_generate({status: "ready"})

Analyze the above information and provide insights.
```

#### Context Management with Checkpoints

AIA provides powerful context management capabilities in chat mode through checkpoint and restore directives:

```bash
# Create a checkpoint with automatic naming (1, 2, 3...)
/checkpoint

# Create a named checkpoint
/checkpoint important_decision

# Restore to the last checkpoint
/restore

# Restore to a specific checkpoint
/restore important_decision

# View context with checkpoint markers
/context
```

**Example Chat Session:**
```
You: Tell me about Ruby programming
AI: Ruby is a dynamic programming language...

You: /checkpoint ruby_basics

You: Now explain object-oriented programming
AI: Object-oriented programming (OOP) is...

You: /checkpoint oop_concepts

You: Actually, let's go back to Ruby basics
You: /restore ruby_basics

You: /context
=== Chat Context ===
Total messages: 4
Checkpoints: ruby_basics, oop_concepts

1. [System]: You are a helpful assistant
2. [User]: Tell me about Ruby programming
3. [Assistant]: Ruby is a dynamic programming language...

📍 [Checkpoint: ruby_basics]
----------------------------------------
4. [User]: Now explain object-oriented programming
=== End of Context ===
```

**Key Features:**
- **Auto-naming**: Checkpoints without names use incrementing integers (1, 2, 3...)
- **Named checkpoints**: Use meaningful names like `/checkpoint before_refactor`
- **Default restore**: `/restore` without a name restores to the last checkpoint
- **Context visualization**: `/context` shows checkpoint markers in conversation history
- **Clean slate**: `/clear` removes all context and checkpoints

#### Custom Directive Examples

You can extend AIA with custom directives by subclassing `AIA::Directive`. Use `desc` before a method to register it as a directive. Aliases are detected automatically via `alias_method`.

```ruby
# examples/directives/timestamp_directive.rb
module AIA
  class CustomDirectives < Directive
    desc "Insert current timestamp (optional strftime format, default: %Y-%m-%d %H:%M:%S)"
    def timestamp(args = [], context_manager = nil)
      format = args.empty? ? '%Y-%m-%d %H:%M:%S' : args.join(' ')
      Time.now.strftime(format)
    end
  end
end
```

**Usage:** Use the `--tools` option to load a directive file or a directory of files:
```bash
# Load custom directive
aia --tools examples/directives/timestamp_directive.rb --chat

# Use the custom directive in chat mode
/timestamp
/timestamp %Y-%m-%d
```

### Multi-Model Support

AIA supports running multiple AI models simultaneously, allowing you to:
- Compare responses from different models
- Get consensus answers from multiple AI perspectives
- Leverage the strengths of different models for various tasks

#### Basic Multi-Model Usage

Specify multiple models using comma-separated values with the `-m` flag:

```bash
# Use two models
aia my_prompt -m gpt-4o-mini,gpt-3.5-turbo

# Use three models
aia my_prompt -m gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini

# Works in chat mode too
aia --chat -m gpt-4o-mini,gpt-3.5-turbo
```

#### Consensus Mode

Use the `--consensus` flag to have the primary model (first in the list) synthesize responses from all models into a unified answer:

```bash
# Enable consensus mode
aia my_prompt -m gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini --consensus
```

**Consensus Output Format:**
```
from: gpt-4o-mini (consensus)
Based on the insights from multiple AI models, here is a comprehensive answer that
incorporates the best perspectives and resolves any contradictions...
```

#### Individual Responses Mode

By default (or with `--no-consensus`), each model provides its own response:

```bash
# Default behavior - show individual responses
aia my_prompt -m gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini

# Explicitly disable consensus
aia my_prompt -m gpt-4o-mini,gpt-3.5-turbo --no-consensus
```

**Individual Responses Output Format:**
```
from: gpt-4o-mini
Response from the first model...

from: gpt-3.5-turbo
Response from the second model...

from: gpt-5-mini
Response from the third model...
```

#### Model Information

View your current multi-model configuration using the `/model` directive:

```bash
# In any prompt file or chat session
/model
```

**Example Output:**
```
Multi-Model Configuration:
==========================
Model count: 3
Primary model: gpt-4o-mini (used for consensus when --consensus flag is enabled)
Consensus mode: false

Model Details:
--------------------------------------------------
1. gpt-4o-mini (primary)
2. gpt-3.5-turbo
3. gpt-5-mini
```

**Key Features:**
- **Primary Model**: The first model in the list serves as the consensus orchestrator
- **Concurrent Processing**: All models run simultaneously for better performance
- **Flexible Output**: Choose between individual responses or synthesized consensus
- **Error Handling**: Invalid models are reported but don't prevent valid models from working
- **Batch Mode Support**: Multi-model responses are properly formatted in output files

#### Token Usage and Cost Tracking

Monitor token consumption and estimate costs across all models with `--tokens` and `--cost`:

```bash
# Display token usage for each model
aia my_prompt -m gpt-4o,claude-3-sonnet --tokens

# Include cost estimates (automatically enables --tokens)
aia my_prompt -m gpt-4o,claude-3-sonnet --cost

# In chat mode with full tracking
aia --chat -m gpt-4o,claude-3-sonnet,gemini-pro --cost
```

**Token Usage Output:**
```
from: gpt-4o
Here's my analysis of the code...

from: claude-3-sonnet
Looking at this code, I notice...

Tokens: gpt-4o: input=245, output=312 | claude-3-sonnet: input=245, output=287
Cost: gpt-4o: $0.0078 | claude-3-sonnet: $0.0045 | Total: $0.0123
```

**Use Cases for Token/Cost Tracking:**
- **Budget management** - Monitor API costs in real-time during development
- **Model comparison** - Identify which models are most cost-effective for your tasks
- **Optimization** - Find the right balance between response quality and cost
- **Billing insights** - Track usage patterns across different model providers

### Local Model Support

AIA supports running local AI models through Ollama and LM Studio, providing privacy, offline capability, and cost savings.

#### Ollama Integration

[Ollama](https://ollama.ai) runs AI models locally on your machine.

```bash
# Install Ollama (macOS)
brew install ollama

# Pull a model
ollama pull llama3.2

# Use with AIA - prefix model name with 'ollama/'
aia --model ollama/llama3.2 my_prompt

# In chat mode
aia --chat --model ollama/llama3.2

# Combine with cloud models
aia --model ollama/llama3.2,gpt-4o-mini --consensus my_prompt
```

**Environment Variables:**
```bash
# Optional: Set custom Ollama API endpoint
export OLLAMA_API_BASE=http://localhost:11434
```

#### LM Studio Integration

[LM Studio](https://lmstudio.ai) provides a desktop application for running local models with an OpenAI-compatible API.

```bash
# 1. Install LM Studio from lmstudio.ai
# 2. Download and load a model in LM Studio
# 3. Start the local server in LM Studio

# Use with AIA - prefix model name with 'lms/'
aia --model lms/qwen/qwen3-coder-30b my_prompt

# In chat mode
aia --chat --model lms/your-model-name

# Mix local and cloud models
aia --model lms/local-model,gpt-4o-mini my_prompt
```

**Environment Variables:**
```bash
# Optional: Set custom LM Studio API endpoint (default: http://localhost:1234/v1)
export LMS_API_BASE=http://localhost:1234/v1
```

#### Listing Local Models

The `/models` directive automatically detects local providers and queries their endpoints:

```bash
# In a prompt file or chat session
/models

# Output will show:
# - Ollama models from http://localhost:11434/api/tags
# - LM Studio models from http://localhost:1234/v1/models
# - Cloud models from RubyLLM database
```

**Benefits of Local Models:**
- 🔒 **Privacy**: No data sent to external servers
- 💰 **Cost**: Zero API costs after initial setup
- 🚀 **Speed**: No network latency
- 📡 **Offline**: Works without internet connection
- 🔧 **Control**: Full control over model and parameters

### Shell Integration

AIA automatically processes shell patterns in prompts:

- **Environment variables**: `$HOME`, `${USER}`
- **Command substitution**: `$(date)`, `$(git branch --show-current)`

**Examples:**

```bash
# Dynamic system information
As a system administrator on a $(uname -s) platform, how do I optimize performance?

# Include file contents via shell
Here's my current configuration: $(cat ~/.bashrc | head -20)

# Use environment variables
My home directory is $HOME and I'm user $USER.
```

**Security Note**: Be cautious with shell integration. Review prompts before execution as they can run arbitrary commands.

### Embedded Ruby (ERB)

AIA supports full ERB processing in prompts for dynamic content generation:

```erb
<%# ERB example in prompt file %>
Current time: <%= Time.now %>
Random number: <%= rand(100) %>

<% if ENV['USER'] == 'admin' %>
You have admin privileges.
<% else %>
You have standard user privileges.
<% end %>

<%= AIA.config.model %> is the current model.
```

### Prompt Sequences

Chain multiple prompts for complex workflows:

#### Using --next

```bash
# Command line
aia analyze --next summarize --next report

# In prompt files
# analyze.md contains: /next summarize
# summarize.md contains: /next report
```

#### Using --pipeline

```bash
# Command line
aia research --pipeline analyze,summarize,report,present

# In prompt file
/pipeline analyze,summarize,report,present
```

#### Example Workflow

**research.md:**
```
/config model = gpt-4
/next analyze

Research the topic: [RESEARCH_TOPIC]
Provide comprehensive background information.
```

**analyze.md:**
```
/config output = analysis.md
/next summarize

Analyze the research data and identify key insights.
```

**summarize.md:**
```
/config output = summary.md

Create a concise summary of the analysis with actionable recommendations.
```

### Roles and System Prompts

Roles define the context and personality for AI responses:

```bash
# Use a predefined role
aia --role expert analyze_code.rb

# Roles are stored in ~/.prompts/roles/
# expert.md might contain:
# "You are a senior software engineer with 15 years of experience..."
```

**Creating Custom Roles:**

```bash
# Create a code reviewer role
cat > ~/.prompts/roles/code_reviewer.md << EOF
You are an experienced code reviewer. Focus on:
- Code quality and best practices
- Security vulnerabilities
- Performance optimizations
- Maintainability issues

Provide specific, actionable feedback.
EOF
```

**Per-Model Roles** (Multi-Model Role Assignment):

Assign different roles to different models using inline `model=role` syntax:

```bash
# Different perspectives on the same design
aia --model gpt-4o=architect,claude=security,gemini=performance design_doc.md

# Output shows each model with its role:
# from: gpt-4o (architect)
# The proposed microservices architecture provides good separation...
#
# from: claude (security)
# I'm concerned about the authentication flow between services...
#
# from: gemini (performance)
# The database access pattern could become a bottleneck...
```

**Multiple Perspectives** (Same Model, Different Roles):

```bash
# Get optimistic, pessimistic, and realistic views
aia --model gpt-4o=optimist,gpt-4o=pessimist,gpt-4o=realist business_plan.md

# Output shows instance numbers:
# from: gpt-4o #1 (optimist)
# This market opportunity is massive...
#
# from: gpt-4o #2 (pessimist)
# The competition is fierce and our runway is limited...
#
# from: gpt-4o #3 (realist)
# Given our current team size, we should focus on MVP first...
```

**Mixed Role Assignment:**

```bash
# Some models with roles, some with default
aia --model gpt-4o=architect,claude,gemini=performance --role security design.md
# gpt-4o gets architect (inline)
# claude gets security (default from --role)
# gemini gets performance (inline)
```

**Discovering Available Roles:**

```bash
# List all available role files
aia --list-roles

# Output:
# Available roles in ~/.prompts/roles:
#   - architect
#   - performance
#   - security
#   - code_reviewer
#   - specialized/senior_architect  # nested paths supported
```

**Role Organization:**

Roles can be organized in subdirectories:

```bash
# Create nested role structure
mkdir -p ~/.prompts/roles/specialized
echo "You are a senior software architect..." > ~/.prompts/roles/specialized/senior_architect.md

# Use nested roles
aia --model gpt-4o=specialized/senior_architect design.md
```

**Using Config Files for Model Roles:**

Define model-role assignments in your config file (`~/.config/aia/aia.yml`) for reusable setups:

```yaml
# Array of hashes format (mirrors internal structure)
models:
  - name: gpt-4o
    role: architect
  - name: claude
    role: security
  - name: gemini
    role: performance

# Also supports models without roles
models:
  - name: gpt-4o
    role: architect
  - name: claude      # No role assigned
```

Then simply run:

```bash
aia design_doc.md  # Uses model configuration from config file
```

**Using Environment Variables:**

Set default model-role assignments via environment variable:

```bash
# Set in your shell profile (.bashrc, .zshrc, etc.)
export AIA_MODEL="gpt-4o=architect,claude=security,gemini=performance"

# Or for a single command
AIA_MODEL="gpt-4o=architect,claude=security" aia design.md
```

**Configuration Precedence:**

When model roles are specified in multiple places, the precedence is:

1. **Command-line inline** (highest): `--model gpt-4o=architect`
2. **Command-line flag**: `--model gpt-4o --role architect`
3. **Environment variable**: `AIA_MODEL="gpt-4o=architect"`
4. **Config file** (lowest): `models` array in `~/.config/aia/aia.yml`

### RubyLLM::Tool Support

AIA supports function calling through RubyLLM tools for extended capabilities:

```bash
# Load tools from directory
aia --tools ~/my-tools/ --chat

# Load specific tool files
aia --tools weather.rb,calculator.rb --chat

# Filter tools
aia --tools ~/tools/ --allowed-tools weather,calc
aia --tools ~/tools/ --rejected-tools deprecated
```

**Tool Examples** (see `examples/tools/` directory):
- File operations (read, write, list)
- Shell command execution
- API integrations
- Data processing utilities

**MCP Client Examples** (see `examples/tools/mcp/` directory):

AIA supports Model Context Protocol (MCP) clients for extended functionality:

```bash
# GitHub MCP Server (requires: brew install github-mcp-server)
# Set GITHUB_PERSONAL_ACCESS_TOKEN environment variable
aia --tools examples/tools/mcp/github_mcp_server.rb --chat

# iMCP for macOS (requires: brew install --cask loopwork/tap/iMCP)
# Provides access to Notes, Calendar, Contacts, etc.
aia --tools examples/tools/mcp/imcp.rb --chat
```

These MCP clients require the `ruby_llm-mcp` gem and provide access to external services and data sources through the Model Context Protocol.

### MCP Server Configuration

AIA supports defining MCP (Model Context Protocol) servers directly in your configuration file. This allows MCP tools to be automatically loaded at startup without needing to specify them on the command line each time. When multiple MCP servers are configured, AIA connects to them **in parallel** using fiber-based concurrency (via the `simple_flow` gem) for faster startup.

#### Configuration Format

Add MCP servers to your `~/.config/aia/aia.yml` file:

```yaml
mcp_servers:
  - name: "server-name"
    command: "server_command"
    args: ["arg1", "arg2"]
    timeout: 30000  # milliseconds (default: 8000)
    env:
      ENV_VAR: "value"
```

#### Configuration Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `name` | Yes | - | Unique identifier for the MCP server |
| `command` | Yes | - | Executable command (absolute path or found in PATH) |
| `args` | No | `[]` | Array of command-line arguments |
| `timeout` | No | `8000` | Connection timeout in milliseconds |
| `env` | No | `{}` | Environment variables for the server process |

#### Example: GitHub MCP Server

The GitHub MCP server provides access to GitHub repositories, issues, pull requests, and more:

```yaml
# ~/.config/aia/aia.yml
mcp_servers:
  - name: "github"
    command: "github-mcp-server"
    args: ["stdio"]
    timeout: 15000
    env:
      GITHUB_PERSONAL_ACCESS_TOKEN: "ghp_your_token_here"
```

**Setup:**
```bash
# Install GitHub MCP server (macOS)
brew install github-mcp-server

# Or via npm
npm install -g @anthropic/github-mcp-server

# Set your GitHub token (recommended: use environment variable instead of config)
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_your_token_here"
```

#### Example: Hierarchical Temporal Memory (HTM)

```shell
gem install htm
```

See the [full HTM documentation](https://madbomber.github.io/htm) for database configuration and system environment variable usage.

A custom Ruby-based MCP server for accessing database-backed long term memory:

```yaml
# ~/.config/aia/aia.yml
mcp_servers:
  - name: "htm"
    command: "htm_mcp.rb"
    args: ["stdio"]
    timeout: 30000
    env:
      HTM_DBURL: "postgres://localhost:5432/htm_development"
      ...
```

**Notes:**
- The `command` can be just the executable name if it's in your PATH
- AIA automatically resolves command paths, so you don't need absolute paths
- Environment variables in the `env` section are passed only to that MCP server process

#### Example: Multiple MCP Servers

You can configure multiple MCP servers to provide different capabilities:

```yaml
# ~/.config/aia/aia.yml
mcp_servers:
  - name: "github"
    command: "github-mcp-server"
    args: ["stdio"]
    env:
      GITHUB_PERSONAL_ACCESS_TOKEN: "ghp_your_token_here"

  - name: "htm"
    command: "htm_mcp.rb"
    args: ["stdio"]
    timeout: 30000
    env:
      HTM_DBURL: "postgres://localhost:5432/htm_development"

  - name: "filesystem"
    command: "filesystem-mcp-server"
    args: ["stdio", "--root", "/Users/me/projects"]
```

#### Verifying MCP Server Configuration

When MCP servers are configured, AIA displays them in the startup robot:

```
       ,      ,
       (\____/) AI Assistant (v1.0.0) is Online
        (_oo_)   gpt-4o-mini (supports tools)
         (O)       using ruby_llm
       __||__    \) model db was last refreshed on
     [/______\]  /    2025-06-18
    / \__AI__/ \/      You can share my tools
   /    /__\              MCP: github, htm
  (\   /____\
```

Use the `/tools` directive in chat mode to see all available tools including those from MCP servers:

```bash
aia --chat
> /tools

Available Tools:
- github_create_issue: Create a new GitHub issue
- github_list_repos: List repositories for the authenticated user
- htm_query: Execute a query against the HTM database
- htm_insert: Insert a record into HTM
...

# Filter tools by name (case-insensitive)
> /tools github

Available Tools (filtered by 'github')
- github_create_issue: Create a new GitHub issue
- github_list_repos: List repositories for the authenticated user
```

#### Troubleshooting MCP Servers

If an MCP server fails to load, AIA will display a warning:

```
WARNING: MCP server 'github' command not found: github-mcp-server
WARNING: MCP server entry missing name or command: {...}
ERROR: Failed to load MCP server 'htm': Connection timeout
```

**Common Issues:**

| Problem | Solution |
|---------|----------|
| Command not found | Ensure the command is in your PATH or use absolute path |
| Connection timeout | Increase the `timeout` value |
| Missing environment variables | Add required env vars to the `env` section |
| Server hangs on startup | Check that all required environment variables are set |

**Debug Mode:**

Enable debug mode to see detailed MCP server loading information:

```bash
aia --debug --chat
```

**Shared Tools Collection:**
AIA can use the [shared_tools gem](https://github.com/madbomber/shared_tools) which provides a curated collection of commonly-used  tools (aka functions) via the --require option.

```bash
# Access shared tools automatically (included with AIA)
aia --require shared_tools/ruby_llm --chat

# To access just one specific shared tool
aia --require shared_tools/ruby_llm/edit_file --chat

# Combine with your own local custom RubyLLM-based tools
aia --require shared_tools/ruby_llm --tools ~/my-tools/ --chat
```

The above examples show the shared_tools being used within an interactive chat session.  They are also available in batch prompts as well using the same --require option.  You can also use the /ruby directive to require the shared_tools as well and using a require statement within an ERB block.

## Examples & Tips

For a hands-on introduction, see the [examples/](examples/) directory. It contains 20 progressive demo scripts that walk through AIA's batch mode features — from basic prompts through pipelines, multi-model comparison, tools, and MCP servers. Each script is self-contained and runnable with a local Ollama model.

### Practical Examples

#### Code Review Prompt
```bash
# ~/.prompts/code_review.md
/config model = gpt-4o-mini
/config temperature = 0.3

Review this code for:
- Best practices adherence
- Security vulnerabilities
- Performance issues
- Maintainability concerns

Code to review:
```

Usage: `aia code_review mycode.rb`

#### Meeting Notes Processor
```bash
# ~/.prompts/meeting_notes.md
/config model = gpt-4o-mini
/pipeline format,action_items

Raw meeting notes:
/include [NOTES_FILE]

Please clean up and structure these meeting notes.
```

#### Documentation Generator
```bash
# ~/.prompts/document.md
/config model = gpt-4o-mini
/shell find [PROJECT_DIR] -name "*.rb" | head -10

Generate documentation for the Ruby project shown above.
Include: API references, usage examples, and setup instructions.
```

#### Multi-Model Decision Making
```bash
# ~/.prompts/decision_maker.md
# Compare different AI perspectives on complex decisions

What are the pros and cons of [DECISION_TOPIC]?
Consider: technical feasibility, business impact, risks, and alternatives.

Analyze this thoroughly and provide actionable recommendations.
```

Usage examples:
```bash
# Get individual perspectives from each model
aia decision_maker -m gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini --no-consensus

# Get a synthesized consensus recommendation
aia decision_maker -m gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini --consensus

# Use with chat mode for follow-up questions
aia --chat -m gpt-4o-mini,gpt-3.5-turbo --consensus
```

### Executable Prompts

AIA auto-detects executable prompts by their shebang line (`#!`). Just add a shebang, make the file executable with `chmod +x`, and run it directly. No special flag is needed.

The option `--no-output` directs the output from the LLM to STDOUT so executable prompts can be good citizens on the *nix command line, receiving piped input via STDIN and sending output to STDOUT.

Create executable prompts:

**weather_report** (make executable with `chmod +x`):
```bash
#!/usr/bin/env aia run --no-output
# Get current storm activity for the east and south coast of the US

Summarize the tropical storm outlook fpr the Atlantic, Caribbean Sea and Gulf of America.

/webpage https://www.nhc.noaa.gov/text/refresh/MIATWOAT+shtml/201724_MIATWOAT.shtml
```

Usage:
```bash
./weather_report
./weather_report | glow  # Render the markdown with glow
```

### Tips from the Author

#### The run Prompt
```bash
# ~/.prompts/run.md
# Desc: A configuration only prompt file for use with executable prompts
#       Put whatever you want here to setup the configuration desired.
#       You could also add a system prompt to preface your intended prompt
```

Usage: `echo "What is the meaning of life?" | aia run`

#### The Ad Hoc One-shot Prompt
```bash
# ~/.prompts/ad_hoc.md
[WHAT_NOW_HUMAN]
```
Usage: `aia ad_hoc` - perfect for any quick one-shot question without cluttering shell history.

#### Recommended Shell Setup
```bash
# ~/.bashrc_aia
export AIA_PROMPTS__DIR=~/.prompts
export AIA_OUTPUT__FILE=./temp.md
export AIA_MODEL=gpt-4o-mini
export AIA_FLAGS__VERBOSE=true  # Shows spinner while waiting for LLM response

alias chat='aia --chat --terse'
ask() { echo "$1" | aia run --no-output; }
```

The `chat` alias and the `ask` function (shown above in HASH) are two powerful tools for interacting with the AI assistant. The `chat` alias allows you to engage in an interactive conversation with the AI assistant, while the `ask` function allows you to ask a question and receive a response. Later in this document the `run` prompt ID is discussed.  Besides using the run prompt ID here its also used in making executable prompt files.

#### Prompt Directory Organization
```
~/.prompts/
├── daily/           # Daily workflow prompts
├── development/     # Coding and review prompts
├── research/        # Research and analysis
├── roles/          # System prompts
└── workflows/      # Multi-step pipelines
```

## Security Considerations

### Shell Command Execution

**⚠️ Important Security Warning**

AIA executes shell commands and Ruby code embedded in prompts. This provides powerful functionality but requires caution:

- **Review prompts before execution**, especially from untrusted sources
- **Avoid storing sensitive data** in prompts (API keys, passwords)
- **Use parameterized prompts** instead of hardcoding sensitive values
- **Limit file permissions** on prompt directories if sharing systems

### Safe Practices

```bash
# ✅ Good: Use parameters for sensitive data
/config api_key = [API_KEY]

# ❌ Bad: Hardcode secrets
/config api_key = sk-1234567890abcdef

# ✅ Good: Validate shell commands
/shell ls -la /safe/directory

# ❌ Bad: Dangerous shell commands
/shell rm -rf / # Never do this!
```

### Recommended Security Setup

```bash
# Set restrictive permissions on prompts directory
chmod 700 ~/.prompts
chmod 600 ~/.prompts/*.md
```

## Troubleshooting

### Common Issues

**Prompt not found:**
```bash
# Check prompts directory
ls $AIA_PROMPTS__DIR

# Verify prompt file exists
ls ~/.prompts/my_prompt.md

# Use fuzzy search
aia --fuzzy
```

**Model errors:**
```bash
# List available models
aia --available-models

# Check model name spelling
aia --model gpt-4o  # Correct
aia --model gpt4    # Incorrect
```

**Shell integration not working:**
```bash
# Verify shell patterns
echo "Test: $(date)"  # Should show current date
echo "Home: $HOME"    # Should show home directory
```

**Configuration issues:**
```bash
# Dump current configuration to a file
aia --dump config_snapshot.yml

# Debug configuration loading
aia --debug my_prompt
```

### Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Prompt not found" | Missing prompt file | Check file exists and spelling |
| "Model not available" | Invalid model name | Use `--available-models` to list valid models |
| "Shell command failed" | Invalid shell syntax | Test shell commands separately first |
| "Configuration error" | Invalid config syntax | Check config file YAML syntax |

### Debug Mode and Log Level Options

AIA provides multiple log level options to control the verbosity of logging output. These options set the log level for all three loggers:
- **aia**: Used within the AIA codebase for application-level logging
- **llm**: Passed to the RubyLLM gem's configuration (`RubyLLM.logger`)
- **mcp**: Passed to the RubyLLM::MCP process (`RubyLLM::MCP.logger`)

| Option | Description |
|--------|-------------|
| `-d, --debug` | Enable debug output (most verbose) and set all loggers to DEBUG level |
| `--no-debug` | Disable debug output |
| `--info` | Set all loggers to INFO level |
| `--warn` | Set all loggers to WARN level (default) |
| `--error` | Set all loggers to ERROR level |
| `--fatal` | Set all loggers to FATAL level (least verbose) |

```bash
# Enable debug mode (most verbose - shows all log messages)
aia --debug my_prompt

# Combine with verbose for maximum output
aia --debug --verbose my_prompt

# Use info level for moderate logging
aia --info my_prompt

# Use error level to only see errors and fatal messages
aia --error my_prompt

# Use fatal level for minimal logging (only critical errors)
aia --fatal --chat
```

**Log Level Hierarchy** (from most to least verbose):
1. **debug** - All messages including detailed debugging information
2. **info** - Informational messages and above
3. **warn** - Warnings, errors, and fatal messages (default)
4. **error** - Only errors and fatal messages
5. **fatal** - Only critical/fatal messages

### Performance Issues

**Slow model responses:**
- Try smaller/faster models: `--model gpt-4o-mini`
- Reduce max_tokens: `--max-tokens 1000`
- Use lower temperature for faster responses: `--temperature 0.1`

**Large prompt processing:**
- Break into smaller prompts using `--pipeline`
- Use `/include` selectively instead of large files
- Consider model context limits

## Development

### Testing

```bash
# Run unit tests
rake test

# Run integration tests
rake integration

# Run all tests with coverage
rake all_tests
open coverage/index.html
```

### Building

```bash
# Install locally with documentation
just install

# Generate documentation
just gen_doc

# Static code analysis
just flay
```

### Architecture Notes

**ShellCommandExecutor Refactor:**
The `ShellCommandExecutor` is now a class (previously a module) with instance variables for cleaner encapsulation. Class-level methods remain for backward compatibility.

**Prompt Variable Fallback:**
Variables are always parsed from prompt text when no `.json` history file exists, ensuring parameter prompting works correctly.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

### Reporting Issues

When reporting issues, please include:
- AIA version: `aia --version`
- Ruby version: `ruby --version`
- Operating system
- Minimal reproduction example
- Error messages and debug output

### Development Setup

```bash
git clone https://github.com/MadBomber/aia.git
cd aia
bundle install
rake test
```

### Areas for Improvement

- Configuration UI for complex setups
- Better error handling and user feedback
- Performance optimization for large prompt libraries
- Enhanced security controls for shell integration

## Roadmap

- **Enhanced Search**: Restore full-text search within prompt files
- **UI Improvements**: Better configuration management for fzf and rg tools

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Articles on AIA

1. [The Philosophy of Prompt-Driven Development with AIA](https://madbomber.github.io/blog/engineering/AIA-Philosophy/)
2. [Mastering AIA's Batch Mode: From Simple Questions to Complex Workflows](https://madbomber.github.io/blog/engineering/AIA-Batch-Mode/)
3. [Building AI Workflows: AIA's Prompt Sequencing and Pipelines](https://madbomber.github.io/blog/engineering/AIA-Workflows/)
4. [Interactive AI Sessions: Mastering AIA's Chat Mode](https://madbomber.github.io/blog/engineering/AIA-Chat-Mode/)
5. [From Dynamic Prompts to Advanced Tool Integration](https://madbomber.github.io/blog/engineering/AIA-Advanced-Tool-Integration/)
