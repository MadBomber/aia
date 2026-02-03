# Configuration

AIA provides a flexible configuration system with multiple layers of precedence, allowing you to customize behavior at different levels.

## Configuration Precedence

AIA follows a hierarchical configuration system (highest to lowest precedence):

1. **Embedded Directives** - `/config` directives in prompt files
2. **Command Line Arguments** - CLI flags and options
3. **Environment Variables** - Shell environment variables
4. **Configuration Files** - YAML configuration files
5. **Defaults** - Built-in default values

## Configuration Files

### Primary Configuration File

The main configuration file is located at `~/.config/aia/aia.yml` (following XDG Base Directory Specification):

```yaml
# ~/.config/aia/aia.yml - Main AIA configuration
# Uses nested structure - environment variables use double underscore for nesting

# Service identification
service:
  name: aia

# LLM Configuration
# Access: AIA.config.llm.adapter, AIA.config.llm.temperature, etc.
# Env: AIA_LLM__ADAPTER, AIA_LLM__TEMPERATURE, etc.
llm:
  adapter: ruby_llm           # AI adapter to use (currently only ruby_llm)
  temperature: 0.7            # Creativity/randomness (0.0-2.0)
  max_tokens: 2048            # Maximum response length
  top_p: 1.0                  # Nucleus sampling
  frequency_penalty: 0.0      # Repetition penalty (-2.0 to 2.0)
  presence_penalty: 0.0       # Topic penalty (-2.0 to 2.0)

# Models Configuration
# Access: AIA.config.models (array of ModelSpec objects)
# Each model has: name, role, instance, internal_id
models:
  - name: gpt-4o-mini
    role: ~                   # Optional role assignment

# Prompts Configuration
# Access: AIA.config.prompts.dir, AIA.config.prompts.roles_prefix, etc.
# Env: AIA_PROMPTS__DIR, AIA_PROMPTS__ROLES_PREFIX, etc.
prompts:
  dir: ~/.prompts             # Directory containing prompt files
  extname: .md                # Prompt file extension
  roles_prefix: roles         # Subdirectory name for role files
  roles_dir: ~/.prompts/roles # Full path to roles directory
  role: ~                     # Default role
  system_prompt: ~            # Default system prompt
  parameter_regex: ~          # Regex for parameter extraction

# Output Configuration
# Access: AIA.config.output.file, AIA.config.output.append, etc.
# Env: AIA_OUTPUT__FILE, AIA_OUTPUT__APPEND, etc.
output:
  file: temp.md               # Output file (null = no file output)
  append: false               # Append to output file instead of overwriting
  markdown: true              # Format output with Markdown
  history_file: ~/.prompts/_prompts.log  # Conversation history log

# Audio Configuration
# Access: AIA.config.audio.voice, AIA.config.audio.speak_command, etc.
# Env: AIA_AUDIO__VOICE, AIA_AUDIO__SPEAK_COMMAND, etc.
audio:
  voice: alloy                # Voice for speech synthesis
  speak_command: afplay       # Command to play audio files
  speech_model: tts-1         # Model for text-to-speech
  transcription_model: whisper-1  # Model for speech-to-text

# Image Configuration
# Access: AIA.config.image.model, AIA.config.image.size, etc.
# Env: AIA_IMAGE__MODEL, AIA_IMAGE__SIZE, etc.
image:
  model: dall-e-3             # Image generation model
  size: 1024x1024             # Default image size
  quality: standard           # Image quality (standard/hd)
  style: vivid                # Image style (vivid/natural)

# Embedding Configuration
# Access: AIA.config.embedding.model
# Env: AIA_EMBEDDING__MODEL
embedding:
  model: text-embedding-ada-002  # Embedding model

# Tools Configuration
# Access: AIA.config.tools.paths, AIA.config.tools.allowed, etc.
# Env: AIA_TOOLS__PATHS, AIA_TOOLS__ALLOWED, etc.
tools:
  paths: []                   # Paths to tool files/directories
  allowed: ~                  # Whitelist of allowed tools
  rejected: ~                 # Blacklist of rejected tools

# Flags (Boolean Options)
# Access: AIA.config.flags.chat, AIA.config.flags.debug, etc.
# Env: AIA_FLAGS__CHAT=true, AIA_FLAGS__DEBUG=true, etc.
flags:
  chat: false                 # Start in chat mode
  cost: false                 # Show cost calculations
  debug: false                # Enable debug logging
  verbose: false              # Show detailed output
  fuzzy: false                # Enable fuzzy prompt searching
  tokens: false               # Show token usage
  no_mcp: false               # Disable MCP server processing
  speak: false                # Convert text to speech
  terse: false                # Request shorter AI responses
  shell: true                 # Enable shell integration
  erb: true                   # Enable ERB processing
  clear: false                # Clear conversation history
  consensus: false            # Enable consensus mode for multi-model

# Logger Configuration
# Access: AIA.config.logger.aia.file, AIA.config.logger.llm.level, etc.
# Env: AIA_LOGGER__AIA__FILE, AIA_LOGGER__LLM__LEVEL, etc.
logger:
  aia:                        # AIA application logging
    file: STDOUT              # STDOUT, STDERR, or a file path
    level: warn               # debug, info, warn, error, fatal
    flush: true               # Immediate write (no buffering)
  llm:                        # RubyLLM gem logging
    file: STDOUT
    level: warn
    flush: true
  mcp:                        # RubyLLM::MCP gem logging
    file: STDOUT
    level: warn
    flush: true

# Pipeline/Workflow Configuration
# Access: AIA.config.pipeline (array of prompt IDs)
pipeline: []

# Model Registry Configuration
# Access: AIA.config.registry.refresh
# Env: AIA_REGISTRY__REFRESH
registry:
  refresh: 7                  # Days between model database refreshes (0 = disable)

# Required Ruby Libraries
# Access: AIA.config.require_libs (array)
require_libs: []

# MCP Servers Configuration
# Access: AIA.config.mcp_servers (array of server configs)
mcp_servers: []
#  - name: my-server
#    command: /path/to/server
#    args: []
#    env: {}
#    timeout: 8000

# Paths Configuration
# Access: AIA.config.paths.aia_dir, AIA.config.paths.config_file
# Env: AIA_PATHS__AIA_DIR, AIA_PATHS__CONFIG_FILE
paths:
  aia_dir: ~/.config/aia
  config_file: ~/.config/aia/aia.yml

# Context Files (set at runtime)
# Access: AIA.config.context_files (array of file paths)
context_files: []
```

### Model-Specific Configuration

You can create model-specific configuration files:

```yaml
# ~/.config/aia/models/gpt-4.yml
llm:
  temperature: 0.3
  max_tokens: 4000
  top_p: 0.95
```

```yaml
# ~/.config/aia/models/claude-3.yml
llm:
  temperature: 0.5
  max_tokens: 8000
```

## Environment Variables

All configuration options can be set via environment variables with the `AIA_` prefix.
Use double underscore (`__`) for nested configuration sections:

```bash
# LLM settings (nested under llm:)
export AIA_LLM__ADAPTER="ruby_llm"
export AIA_LLM__TEMPERATURE="0.8"
export AIA_LLM__MAX_TOKENS="2048"
export AIA_LLM__TOP_P="1.0"
export AIA_LLM__FREQUENCY_PENALTY="0.0"
export AIA_LLM__PRESENCE_PENALTY="0.0"

# Models (top-level, supports MODEL=ROLE syntax)
export AIA_MODEL="gpt-4"
export AIA_MODEL="gpt-4o=architect,claude=reviewer"

# Prompts settings (nested under prompts:)
export AIA_PROMPTS__DIR="/path/to/my/prompts"
export AIA_PROMPTS__EXTNAME=".md"
export AIA_PROMPTS__ROLES_PREFIX="roles"
export AIA_PROMPTS__ROLES_DIR="~/.prompts/roles"
export AIA_PROMPTS__ROLE="expert"
export AIA_PROMPTS__SYSTEM_PROMPT="my_system_prompt"
export AIA_PROMPTS__PARAMETER_REGEX='\{\{(\w+)\}\}'

# Output settings (nested under output:)
export AIA_OUTPUT__FILE="/tmp/aia_output.md"
export AIA_OUTPUT__APPEND="false"
export AIA_OUTPUT__MARKDOWN="true"
export AIA_OUTPUT__HISTORY_FILE="~/.prompts/_prompts.log"

# Audio settings (nested under audio:)
export AIA_AUDIO__VOICE="alloy"
export AIA_AUDIO__SPEAK_COMMAND="afplay"
export AIA_AUDIO__SPEECH_MODEL="tts-1"
export AIA_AUDIO__TRANSCRIPTION_MODEL="whisper-1"

# Image settings (nested under image:)
export AIA_IMAGE__MODEL="dall-e-3"
export AIA_IMAGE__SIZE="1024x1024"
export AIA_IMAGE__QUALITY="standard"
export AIA_IMAGE__STYLE="vivid"

# Embedding settings (nested under embedding:)
export AIA_EMBEDDING__MODEL="text-embedding-ada-002"

# Tools settings (nested under tools:)
export AIA_TOOLS__PATHS="/path/to/tools"
export AIA_TOOLS__ALLOWED="calculator,file_reader"
export AIA_TOOLS__REJECTED="dangerous_tool"

# Flags (nested under flags:)
export AIA_FLAGS__CHAT="true"
export AIA_FLAGS__COST="false"
export AIA_FLAGS__DEBUG="false"
export AIA_FLAGS__VERBOSE="true"
export AIA_FLAGS__FUZZY="false"
export AIA_FLAGS__TOKENS="true"
export AIA_FLAGS__NO_MCP="false"
export AIA_FLAGS__SPEAK="false"
export AIA_FLAGS__TERSE="false"
export AIA_FLAGS__SHELL="true"
export AIA_FLAGS__ERB="true"
export AIA_FLAGS__CLEAR="false"
export AIA_FLAGS__CONSENSUS="false"

# Logger settings (nested under logger:)
export AIA_LOGGER__AIA__FILE="~/.aia/aia.log"
export AIA_LOGGER__AIA__LEVEL="debug"
export AIA_LOGGER__AIA__FLUSH="true"
export AIA_LOGGER__LLM__FILE="STDOUT"
export AIA_LOGGER__LLM__LEVEL="info"
export AIA_LOGGER__LLM__FLUSH="true"
export AIA_LOGGER__MCP__FILE="STDERR"
export AIA_LOGGER__MCP__LEVEL="warn"
export AIA_LOGGER__MCP__FLUSH="true"

# Registry settings (nested under registry:)
export AIA_REGISTRY__REFRESH="7"

# Paths settings (nested under paths:)
export AIA_PATHS__AIA_DIR="~/.config/aia"
export AIA_PATHS__CONFIG_FILE="~/.config/aia/aia.yml"

# API Keys (handled by RubyLLM)
export OPENAI_API_KEY="your_key_here"
export ANTHROPIC_API_KEY="your_key_here"
export GOOGLE_API_KEY="your_key_here"
export OLLAMA_URL="http://localhost:11434"
```

## Command Line Arguments

All options can be overridden via command line arguments. See [CLI Reference](cli-reference.md) for complete details.

## Embedded Directives

Prompts can contain configuration directives that override all other settings:

```markdown
/config model claude-3-sonnet
/config temperature 0.9
/config max_tokens 1500

Write a creative story about...
```

## Logger Configuration

AIA uses the Lumberjack gem for logging and manages three separate loggers:

| Logger | Purpose |
|--------|---------|
| `aia` | Used within the AIA codebase for application-level logging |
| `llm` | Passed to the RubyLLM gem's configuration (`RubyLLM.logger`) |
| `mcp` | Passed to the RubyLLM::MCP process (`RubyLLM::MCP.logger`) |

### Configuration File Settings

Each logger can be configured independently in your `~/.config/aia/aia.yml`:

```yaml
logger:
  aia:
    file: STDOUT           # STDOUT, STDERR, or a file path (e.g., ~/.aia/aia.log)
    level: warn            # debug, info, warn, error, fatal
    flush: true            # true = immediate write, false = buffered
  llm:
    file: STDOUT
    level: warn
    flush: true
  mcp:
    file: STDOUT
    level: warn
    flush: true
```

**Note**: All three loggers can safely write to the same file path. AIA handles multi-process safe file writes with automatic log file rotation (daily).

### CLI Log Level Override

Command-line log level options override the config file settings for ALL loggers:

```bash
# Set all loggers to debug level
aia --debug my_prompt

# Set all loggers to info level
aia --info my_prompt

# Set all loggers to warn level (default)
aia --warn my_prompt

# Set all loggers to error level
aia --error my_prompt

# Set all loggers to fatal level
aia --fatal my_prompt
```

### Environment Variables

Logger settings can also be configured via environment variables:

```bash
# AIA logger settings
export AIA_LOGGER__AIA__FILE="~/.aia/aia.log"
export AIA_LOGGER__AIA__LEVEL="debug"
export AIA_LOGGER__AIA__FLUSH="true"

# LLM logger settings
export AIA_LOGGER__LLM__FILE="STDOUT"
export AIA_LOGGER__LLM__LEVEL="info"

# MCP logger settings
export AIA_LOGGER__MCP__FILE="STDERR"
export AIA_LOGGER__MCP__LEVEL="warn"
```

### Log Levels

| Level | Description |
|-------|-------------|
| `debug` | Most verbose - all messages including detailed debugging info |
| `info` | Informational messages and above |
| `warn` | Warnings, errors, and fatal messages (default) |
| `error` | Only errors and fatal messages |
| `fatal` | Least verbose - only critical/fatal messages |

### Example: File-Based Logging

```yaml
# ~/.config/aia/aia.yml - Log everything to files
logger:
  aia:
    file: ~/.config/aia/logs/aia.log
    level: info
    flush: true
  llm:
    file: ~/.config/aia/logs/llm.log
    level: debug
    flush: false
  mcp:
    file: ~/.config/aia/logs/mcp.log
    level: warn
    flush: true
```

## Advanced Configuration

### Multi-Model Configuration

Configure multiple models with role assignments:

```yaml
# Configure multiple models with roles
models:
  - name: gpt-4o
    role: architect        # Design and architecture decisions
  - name: claude-3-sonnet
    role: reviewer         # Code review and analysis
  - name: gpt-4o-mini
    role: ~                # No specific role (general use)
```

Use with: `aia --model "gpt-4o=architect,claude=reviewer" my_prompt`

Or use the `--consensus` flag to combine responses:
```bash
aia --model "gpt-4,claude-3-sonnet" --consensus my_prompt
```

### Tool Configuration

Configure tool paths and permissions:

```yaml
# Tool settings (nested structure)
tools:
  paths:
    - ~/.config/aia/tools
    - /usr/local/share/aia-tools
    - ./project-tools
  allowed:
    - file_reader
    - web_scraper
    - calculator
  rejected:
    - system_admin
    - file_writer
```

### MCP Server Configuration

Configure Model Context Protocol servers:

```yaml
# MCP servers (array of server configurations)
mcp_servers:
  - name: github
    command: /path/to/github-mcp-server
    args: []
    env:
      GITHUB_TOKEN: "${GITHUB_TOKEN}"
    timeout: 8000

  - name: filesystem
    command: mcp-server-filesystem
    args:
      - /allowed/path1
      - /allowed/path2
```

### Prompt Directory Structure

Configure how AIA organizes prompts:

```yaml
# Prompts configuration (nested structure)
prompts:
  dir: ~/.prompts
  extname: .md
  roles_prefix: roles       # ~/.prompts/roles/
  roles_dir: ~/.prompts/roles
  role: ~                   # Default role (null = none)
  system_prompt: ~          # Default system prompt
  parameter_regex: ~        # Custom parameter extraction regex
```

## Configuration Examples

### Development Setup

```yaml
# ~/.config/aia/aia.yml - Development setup
llm:
  adapter: ruby_llm
  temperature: 0.3

models:
  - name: gpt-4

prompts:
  dir: ./prompts

output:
  file: ./dev_output.md

tools:
  paths:
    - ./tools

flags:
  verbose: true
  debug: true
```

### Production Setup

```yaml
# ~/.config/aia/aia.yml - Production setup
llm:
  adapter: ruby_llm
  temperature: 0.7

models:
  - name: gpt-4o-mini

prompts:
  dir: /etc/aia/prompts

output:
  history_file: /var/log/aia_history.log

tools:
  paths:
    - /usr/share/aia-tools
  allowed:
    - safe_calculator
    - file_reader

flags:
  verbose: false
  debug: false
```

### Creative Writing Setup

```yaml
# ~/.config/aia/aia.yml - Creative writing
llm:
  adapter: ruby_llm
  temperature: 1.1
  max_tokens: 4000

models:
  - name: gpt-4

output:
  file: ~/writing/aia_output.md
  append: true
  markdown: true

audio:
  voice: nova

flags:
  speak: true
```

## Validation and Troubleshooting

### Check Configuration

Dump current configuration:

```bash
aia --dump config.yaml
```

### Validate Settings

```bash
# Test model access
aia --available-models

# Test configuration
aia --debug --verbose hello_world

# Test tools
aia --tools ./my_tools --debug test_prompt
```

### Common Issues

#### Model Not Found
- Check your API keys are set
- Verify the model name: `aia --available-models`
- Check network connectivity

#### Permission Errors  
- Verify file permissions on config directory
- Check tool file permissions
- Ensure API keys are correctly set

#### Tool Loading Errors
- Verify tool paths exist and are readable
- Check Ruby syntax in tool files
- Use `--debug` to see detailed error messages

## Configuration Migration

### Updating from Older Versions

AIA automatically migrates older configuration formats. To manually update:

```bash
# Backup current config
cp ~/.config/aia/aia.yml ~/.config/aia/aia.yml.backup

# Update configuration format
aia --migrate-config
```

### Configuration Templates

Generate configuration templates:

```bash
# Generate basic config
aia --generate-config basic > ~/.config/aia/aia.yml

# Generate advanced config with all options
aia --generate-config full > ~/.config/aia/aia.advanced.yml
```

## Best Practices

1. **Use Environment Variables** for sensitive data like API keys
2. **Use Configuration Files** for stable settings
3. **Use Command Line Arguments** for temporary overrides
4. **Use Embedded Directives** for prompt-specific settings
5. **Version Control** your configuration (excluding secrets)
6. **Test Changes** with `--debug` and `--verbose` flags
7. **Document Custom Configurations** for team sharing

## Security Considerations

- Never commit API keys to version control
- Use restrictive file permissions on config files: `chmod 600 ~/.config/aia/aia.yml`
- Limit tool access with `tools.allowed` in production
- Use separate configurations for different environments
- Regularly rotate API keys