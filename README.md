# AI Assistant (AIA)

A Ruby command-line interface for interacting with various AI services using the `ai_client` and `prompt_manager` gems.

## Installation

To install the AI Assistant, run:

```bash
$ gem install aia
```

## Overview

The AIA project provides a flexible interface for working with AI models through standardized prompt management.

### Key Features

- **Proper Variable Substitution:** Utilizes the `prompt_manager` gem.
- **Directive Handling:** Extend functionality for commands via directives.
- **Multi-Provider Support:** Facilitates interaction with various AI providers through `ai_client`.
- **Conversation Mode:** Handles history and context management effectively.
- **Pipeline Processing:** Processes sequential AI operations.
- **Shell Command Execution:** Executes shell commands within prompts.
- **Embedded Ruby Support:** Allows dynamic content within prompts.

## Usage

### Basic Usage

```bash
# Basic prompt with ID
aia PROMPT_ID

# Including context files
aia PROMPT_ID context_file1 context_file2
```

### Command Line Options

```bash
# Enable chat mode after initial prompt
aia --chat PROMPT_ID

# Start chat mode directly with role
aia -r ROLE_ID --chat

# Start chat mode without a system prompt
aia --chat

# Specify the model to use
aia --model openai/gpt-4o-mini PROMPT_ID

# Process shell commands in prompt
aia --shell PROMPT_ID

# Process ERB in prompt
aia --erb PROMPT_ID

# Use a specific role
aia -r ROLE_ID PROMPT_ID

# Output to file instead of STDOUT
aia -o output.txt PROMPT_ID

# Enable fuzzy matching for prompt search
aia -f PROMPT_ID
```

### Prompt Management

```bash
# Specify custom prompt directory
aia -p /path/to/prompts PROMPT_ID

# Specify custom roles directory
aia --roles_dir /path/to/roles PROMPT_ID

# Set up prompt pipeline processing
aia --pipeline prompt1,prompt2,prompt3

# Set next prompt to process
aia -n NEXT_PROMPT_ID PROMPT_ID
```

### AI Model Parameters

```bash
# Set temperature (0.0-1.0)
aia -t 0.8 PROMPT_ID

# Set maximum tokens
aia --max_tokens 4096 PROMPT_ID

# Adjust other model parameters
aia --top_p 0.9 --frequency_penalty 0.1 --presence_penalty 0.1 PROMPT_ID
```

### Media Generation

```bash
# Enable speech output
aia --speak PROMPT_ID

# Specify voice for speech
aia --voice alloy PROMPT_ID

# Image generation settings
aia --image_size 1024x1024 --image_quality standard --image_style vivid PROMPT_ID
```

### Chat Directives

In chat mode, you can use directives directly from the chat prompt:

```bash
# Shell command execution
//shell ls -la
#!shell: ls -la

# Ruby code execution
//ruby puts "Hello, World!"
#!ruby: puts "Hello, World!"

# Configuration management
//config                  # Display all configuration settings
//config key              # Display value for a specific key
//config key=value        # Update configuration
#!config: key=value       # Alternative syntax

# Include file content
//include path/to/file
#!include: path/to/file

# Help
//help                    # Show available directives
#!help:
```

**Note:** Outputs from `//config` and `//help` directives are not added to the chat context.

## Configuration

AIA can be configured through environment variables or configuration files.

### Environment Variables

All configuration options can be set with environment variables in the format `AIA_OPTION_NAME`:

```bash
# Set default model
export AIA_MODEL=openai/gpt-4o-mini

# Set prompt directory
export AIA_PROMPTS_DIR=/path/to/prompts

# Enable shell command processing
export AIA_SHELL=true
```

### Configuration Files

Load configuration from YAML or TOML files:

```bash
# Load from config file
aia -c config.yml PROMPT_ID

# Dump current config to file
aia --dump config.yml
```

## Requirements

- Ruby >= 3.2.0
- Dependencies: `ai_client`, `amazing_print`, `prompt_manager`, `os`, `reline`, `shellwords`, `toml-rb`, `tty-screen`, `tty-spinner`, `versionaire`

## License

The gem is available as open-source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
