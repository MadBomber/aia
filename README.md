<div align="center">
  <h1>AI Assistant (AIA)</h1>
  <img src="images/aia.png" alt="Robots waiter ready to take your order."><br />
  **The Prompt is the Code**
</div>

AIA is a command-line utility that facilitates interaction with AI models through dynamic prompt management. It automates the management of pre-compositional prompts and executes generative AI commands with enhanced features including embedded directives, shell integration, embedded Ruby, history management, interactive chat, and prompt workflows.

AIA leverages the [prompt_manager gem](https://github.com/madbomber/prompt_manager) to manage prompts, utilizes the [CLI tool fzf](https://github.com/junegunn/fzf) for prompt selection, and can use the [shared_tools gem](https://github.com/madbomber/shared_tools) which provides a collection of common ready-to-use functions for use with LLMs that support tools.

**Wiki**: [Checkout the AIA Wiki](https://github.com/MadBomber/aia/wiki)

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
   echo "What is [TOPIC]?" > ~/.prompts/ask.txt
   ```

4. **Run your prompt:**
   ```bash
   aia ask
   ```
   You'll be prompted to enter a value for `[TOPIC]`, then AIA will send your question to the AI model.

5. **Start an interactive chat:**
   ```bash
   aia --chat
   ```

```plain
     ,      ,
     (\____/) AI Assistant
      (_oo_)   Fancy LLM
        (O)     is Online
      __||__    \)
    [/______\]  /
   / \__AI__/ \/
  /    /__\
 (\   /____\
```

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
    - [Shell Integration](#shell-integration)
    - [Embedded Ruby (ERB)](#embedded-ruby-erb)
    - [Prompt Sequences](#prompt-sequences)
      - [Using --next](#using---next)
      - [Using --pipeline](#using---pipeline)
      - [Example Workflow](#example-workflow)
    - [Roles and System Prompts](#roles-and-system-prompts)
    - [RubyLLM::Tool Support](#rubyllmtool-support)
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
aia --out_file result.md my_prompt

# Use a role/system prompt
aia --role expert my_prompt

# Enable fuzzy search for prompts
aia --fuzzy
```

### Key Command-Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--chat` | Start interactive chat session | `aia --chat` |
| `--model MODEL` | Specify AI model to use | `aia --model gpt-4` |
| `--role ROLE` | Use a role/system prompt | `aia --role expert` |
| `--out_file FILE` | Specify output file | `aia --out_file results.md` |
| `--fuzzy` | Use fuzzy search for prompts | `aia --fuzzy` |
| `--help` | Show complete help | `aia --help` |

### Directory Structure

```
~/.prompts/              # Default prompts directory
├── ask.txt             # Simple question prompt
├── code_review.txt     # Code review prompt
├── roles/              # Role/system prompts
│   ├── expert.txt      # Expert role
│   └── teacher.txt     # Teaching role
└── _prompts.log        # History log
```

## Configuration

### Essential Configuration Options

The most commonly used configuration options:

| Option | Default | Description |
|--------|---------|-------------|
| `model` | `gpt-4o-mini` | AI model to use |
| `prompts_dir` | `~/.prompts` | Directory containing prompts |
| `out_file` | `temp.md` | Default output file |
| `temperature` | `0.7` | Model creativity (0.0-1.0) |
| `chat` | `false` | Start in chat mode |

### Configuration Precedence

AIA determines configuration settings using this order (highest to lowest priority):

1. **Embedded config directives** (in prompt files): `//config model = gpt-4`
2. **Command-line arguments**: `--model gpt-4`
3. **Environment variables**: `export AIA_MODEL=gpt-4`
4. **Configuration files**: `~/.aia/config.yml`
5. **Default values**

### Configuration Methods

**Environment Variables:**
```bash
export AIA_MODEL=gpt-4
export AIA_PROMPTS_DIR=~/my-prompts
export AIA_TEMPERATURE=0.8
```

**Configuration File** (`~/.aia/config.yml`):
```yaml
model: gpt-4
prompts_dir: ~/my-prompts
temperature: 0.8
chat: false
```

**Embedded Directives** (in prompt files):
```
//config model = gpt-4
//config temperature = 0.8

Your prompt content here...
```

### Complete Configuration Reference

<details>
<summary>Click to view all configuration options</summary>

| Config Item Name | CLI Options | Default Value | Environment Variable |
|------------------|-------------|---------------|---------------------|
| adapter | --adapter | ruby_llm | AIA_ADAPTER |
| aia_dir | | ~/.aia | AIA_DIR |
| append | -a, --append | false | AIA_APPEND |
| chat | --chat | false | AIA_CHAT |
| clear | --clear | false | AIA_CLEAR |
| config_file | -c, --config_file | ~/.aia/config.yml | AIA_CONFIG_FILE |
| debug | -d, --debug | false | AIA_DEBUG |
| embedding_model | --em, --embedding_model | text-embedding-ada-002 | AIA_EMBEDDING_MODEL |
| erb | | true | AIA_ERB |
| frequency_penalty | --frequency_penalty | 0.0 | AIA_FREQUENCY_PENALTY |
| fuzzy | -f, --fuzzy | false | AIA_FUZZY |
| image_quality | --iq, --image_quality | standard | AIA_IMAGE_QUALITY |
| image_size | --is, --image_size | 1024x1024 | AIA_IMAGE_SIZE |
| image_style | --style, --image_style | vivid | AIA_IMAGE_STYLE |
| log_file | -l, --log_file | ~/.prompts/_prompts.log | AIA_LOG_FILE |
| markdown | --md, --markdown | true | AIA_MARKDOWN |
| max_tokens | --max_tokens | 2048 | AIA_MAX_TOKENS |
| model | -m, --model | gpt-4o-mini | AIA_MODEL |
| next | -n, --next | nil | AIA_NEXT |
| out_file | -o, --out_file | temp.md | AIA_OUT_FILE |
| parameter_regex | --regex | '(?-mix:(\[[A-Z _\|]+\]))' | AIA_PARAMETER_REGEX |
| pipeline | --pipeline | [] | AIA_PIPELINE |
| presence_penalty | --presence_penalty | 0.0 | AIA_PRESENCE_PENALTY |
| prompt_extname | | .txt | AIA_PROMPT_EXTNAME |
| prompts_dir | -p, --prompts_dir | ~/.prompts | AIA_PROMPTS_DIR |
| refresh | --refresh | 7 (days) | AIA_REFRESH |
| require_libs | --rq --require | [] | AIA_REQUIRE_LIBS |
| role | -r, --role | | AIA_ROLE |
| roles_dir | | ~/.prompts/roles | AIA_ROLES_DIR |
| roles_prefix | --roles_prefix | roles | AIA_ROLES_PREFIX |
| shell | | true | AIA_SHELL |
| speak | --speak | false | AIA_SPEAK |
| speak_command | | afplay | AIA_SPEAK_COMMAND |
| speech_model | --sm, --speech_model | tts-1 | AIA_SPEECH_MODEL |
| system_prompt | --system_prompt | | AIA_SYSTEM_PROMPT |
| temperature | -t, --temperature | 0.7 | AIA_TEMPERATURE |
| terse | --terse | false | AIA_TERSE |
| tool_paths | --tools | [] | AIA_TOOL_PATHS |
| allowed_tools | --at --allowed_tools | nil | AIA_ALLOWED_TOOLS |
| rejected_tools | --rt --rejected_tools | nil | AIA_REJECTED_TOOLS |
| top_p | --top_p | 1.0 | AIA_TOP_P |
| transcription_model | --tm, --transcription_model | whisper-1 | AIA_TRANSCRIPTION_MODEL |
| verbose | -v, --verbose | false | AIA_VERBOSE |
| voice | --voice | alloy | AIA_VOICE |

</details>

## Advanced Features

### Prompt Directives

Directives are special commands in prompt files that begin with `//` and provide dynamic functionality:

| Directive | Description | Example |
|-----------|-------------|---------|
| `//config` | Set configuration values | `//config model = gpt-4` |
| `//include` | Insert file contents | `//include path/to/file.txt` |
| `//shell` | Execute shell commands | `//shell ls -la` |
| `//ruby` | Execute Ruby code | `//ruby puts "Hello World"` |
| `//next` | Set next prompt in sequence | `//next summary` |
| `//pipeline` | Set prompt workflow | `//pipeline analyze,summarize,report` |
| `//clear` | Clear conversation history | `//clear` |
| `//help` | Show available directives | `//help` |
| `//available_models` | List available models | `//available_models` |
| `//review` | Review current context | `//review` |

#### Configuration Directive Examples

```bash
# Set model and temperature for this prompt
//config model = gpt-4
//config temperature = 0.9

# Enable chat mode and terse responses
//config chat = true
//config terse = true

Your prompt content here...
```

#### Dynamic Content Examples

```bash
# Include file contents
//include ~/project/README.md

# Execute shell commands
//shell git log --oneline -10

# Run Ruby code
//ruby require 'json'; puts JSON.pretty_generate({status: "ready"})

Analyze the above information and provide insights.
```

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
# analyze.txt contains: //next summarize
# summarize.txt contains: //next report
```

#### Using --pipeline

```bash
# Command line
aia research --pipeline analyze,summarize,report,present

# In prompt file
//pipeline analyze,summarize,report,present
```

#### Example Workflow

**research.txt:**
```
//config model = gpt-4
//next analyze

Research the topic: [RESEARCH_TOPIC]
Provide comprehensive background information.
```

**analyze.txt:**
```
//config out_file = analysis.md
//next summarize

Analyze the research data and identify key insights.
```

**summarize.txt:**
```
//config out_file = summary.md

Create a concise summary of the analysis with actionable recommendations.
```

### Roles and System Prompts

Roles define the context and personality for AI responses:

```bash
# Use a predefined role
aia --role expert analyze_code.rb

# Roles are stored in ~/.prompts/roles/
# expert.txt might contain:
# "You are a senior software engineer with 15 years of experience..."
```

**Creating Custom Roles:**

```bash
# Create a code reviewer role
cat > ~/.prompts/roles/code_reviewer.txt << EOF
You are an experienced code reviewer. Focus on:
- Code quality and best practices
- Security vulnerabilities
- Performance optimizations
- Maintainability issues

Provide specific, actionable feedback.
EOF
```

### RubyLLM::Tool Support

AIA supports function calling through RubyLLM tools for extended capabilities:

```bash
# Load tools from directory
aia --tools ~/my-tools/ --chat

# Load specific tool files
aia --tools weather.rb,calculator.rb --chat

# Filter tools
aia --tools ~/tools/ --allowed_tools weather,calc
aia --tools ~/tools/ --rejected_tools deprecated
```

**Tool Examples** (see `examples/tools/` directory):
- File operations (read, write, list)
- Shell command execution
- API integrations
- Data processing utilities

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

The above examples show the shared_tools being used within an interactive chat session.  They are also available in batch prompts as well using the same --require option.  You can also use the //ruby directive to require the shared_tools as well and using a require statement within an ERB block.

## Examples & Tips

### Practical Examples

#### Code Review Prompt
```bash
# ~/.prompts/code_review.txt
//config model = gpt-4o-mini
//config temperature = 0.3

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
# ~/.prompts/meeting_notes.txt
//config model = gpt-4o-mini
//pipeline format,action_items

Raw meeting notes:
//include [NOTES_FILE]

Please clean up and structure these meeting notes.
```

#### Documentation Generator
```bash
# ~/.prompts/document.txt
//config model = gpt-4o-mini
//shell find [PROJECT_DIR] -name "*.rb" | head -10

Generate documentation for the Ruby project shown above.
Include: API references, usage examples, and setup instructions.
```

### Executable Prompts

Create reusable executable prompts:

**weather_report** (make executable with `chmod +x`):
```bash
#!/usr/bin/env aia run --no-out_file
# Get current weather for a city

//ruby require 'shared_tools/ruby_llm/current_weather'

What's the current weather in [CITY]?
Include temperature, conditions, and 3-day forecast.
Format as a brief, readable summary.
```

Usage:
```bash
./weather_report
# Prompts for city, outputs to stdout

./weather_report | glow  # Render with glow
```

### Tips from the Author

#### The run Prompt
```bash
# ~/.prompts/run.txt
# Desc: A configuration only prompt file for use with executable prompts
#       Put whatever you want here to setup the configuration desired.
#       You could also add a system prompt to preface your intended prompt
```

Usage: `echo "What is the meaning of life?" | aia run`

#### The Ad Hoc One-shot Prompt
```bash
# ~/.prompts/ad_hoc.txt
[WHAT_NOW_HUMAN]
```
Usage: `aia ad_hoc` - perfect for any quick one-shot question without cluttering shell history.

#### Recommended Shell Setup
```bash
# ~/.bashrc_aia
export AIA_PROMPTS_DIR=~/.prompts
export AIA_OUT_FILE=./temp.md
export AIA_MODEL=gpt-4o-mini
export AIA_VERBOSE=true  # Shows spinner while waiting for LLM response

alias chat='aia --chat --terse'
ask() { echo "$1" | aia run --no-out_file; }
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
//config api_key = [API_KEY]

# ❌ Bad: Hardcode secrets
//config api_key = sk-1234567890abcdef

# ✅ Good: Validate shell commands
//shell ls -la /safe/directory

# ❌ Bad: Dangerous shell commands
//shell rm -rf / # Never do this!
```

### Recommended Security Setup

```bash
# Set restrictive permissions on prompts directory
chmod 700 ~/.prompts
chmod 600 ~/.prompts/*.txt
```

## Troubleshooting

### Common Issues

**Prompt not found:**
```bash
# Check prompts directory
ls $AIA_PROMPTS_DIR

# Verify prompt file exists
ls ~/.prompts/my_prompt.txt

# Use fuzzy search
aia --fuzzy
```

**Model errors:**
```bash
# List available models
aia --available_models

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
# Check current configuration
aia --config

# Debug configuration loading
aia --debug --config
```

### Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Prompt not found" | Missing prompt file | Check file exists and spelling |
| "Model not available" | Invalid model name | Use `--available_models` to list valid models |
| "Shell command failed" | Invalid shell syntax | Test shell commands separately first |
| "Configuration error" | Invalid config syntax | Check config file YAML syntax |

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Enable debug mode
aia --debug my_prompt

# Combine with verbose for maximum output
aia --debug --verbose my_prompt
```

### Performance Issues

**Slow model responses:**
- Try smaller/faster models: `--model gpt-4o-mini`
- Reduce max_tokens: `--max_tokens 1000`
- Use lower temperature for faster responses: `--temperature 0.1`

**Large prompt processing:**
- Break into smaller prompts using `--pipeline`
- Use `//include` selectively instead of large files
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
- **Model Context Protocol**: Continue integration with ruby_llm gem
- **UI Improvements**: Better configuration management for fzf and rg tools
- **Performance**: Optimize prompt loading and processing
- **Security**: Enhanced sandboxing for shell command execution

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
