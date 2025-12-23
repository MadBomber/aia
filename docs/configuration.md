# Configuration

AIA provides a flexible configuration system with multiple layers of precedence, allowing you to customize behavior at different levels.

## Configuration Precedence

AIA follows a hierarchical configuration system (highest to lowest precedence):

1. **Embedded Directives** - `//config` directives in prompt files
2. **Command Line Arguments** - CLI flags and options
3. **Environment Variables** - Shell environment variables
4. **Configuration Files** - YAML configuration files
5. **Defaults** - Built-in default values

## Configuration Files

### Primary Configuration File

The main configuration file is located at `~/.aia/config.yml`:

```yaml
# ~/.aia/config.yml - Main AIA configuration

# Core Settings
adapter: ruby_llm              # AI adapter to use (currently only ruby_llm)
model: gpt-3.5-turbo          # Default AI model
prompts_dir: ~/.prompts        # Directory containing prompt files
roles_prefix: roles            # Subdirectory name for role files

# AI Parameters
temperature: 0.7               # Creativity/randomness (0.0-2.0)
max_tokens: 2000              # Maximum response length
top_p: 1.0                    # Nucleus sampling
frequency_penalty: 0.0        # Repetition penalty (-2.0 to 2.0)
presence_penalty: 0.0         # Topic penalty (-2.0 to 2.0)

# Output Settings
out_file: null                # Output file (null = no file output)
append: false                 # Append to output file instead of overwriting
markdown: true                # Format output with Markdown
verbose: false                # Show detailed output
debug: false                  # Enable debug logging

# Chat Settings
chat: false                   # Start in chat mode
terse: false                  # Request shorter AI responses
system_prompt: null           # Default system prompt for chat

# Audio/Speech Settings
speak: false                  # Convert text to speech
voice: alloy                  # Voice for speech synthesis
speech_model: tts-1           # Model for text-to-speech
transcription_model: whisper-1 # Model for speech-to-text

# Image Generation Settings
image_size: 1024x1024         # Default image size
image_quality: standard       # Image quality (standard/hd)
image_style: vivid           # Image style (vivid/natural)

# Search Settings
fuzzy: false                  # Enable fuzzy prompt searching
parameter_regex: null         # Regex for parameter extraction

# Tool Settings
tool_paths: []                # Paths to tool files/directories
allowed_tools: []             # Whitelist of allowed tools
rejected_tools: []            # Blacklist of rejected tools
require_libs: []              # Ruby libraries to require

# Workflow Settings
pipeline: []                  # Default prompt pipeline
executable_prompt: false     # Run prompts as executables

# Logging
log_file: null               # Log file path
refresh: 7                   # Model database refresh interval (days)
```

### Model-Specific Configuration

You can create model-specific configuration files:

```yaml
# ~/.aia/models/gpt-4.yml
temperature: 0.3
max_tokens: 4000
top_p: 0.95
```

```yaml
# ~/.aia/models/claude-3.yml  
temperature: 0.5
max_tokens: 8000
```

## Environment Variables

All configuration options can be set via environment variables with the `AIA_` prefix.
Use double underscore (`__`) for nested configuration sections:

```bash
# LLM settings (nested under llm:)
export AIA_LLM__TEMPERATURE="0.8"
export AIA_LLM__ADAPTER="ruby_llm"

# Models (top-level array, supports MODEL=ROLE syntax)
export AIA_MODEL="gpt-4"
export AIA_MODEL="gpt-4o=architect,claude=reviewer"

# Prompts settings (nested under prompts:)
export AIA_PROMPTS__DIR="/path/to/my/prompts"
export AIA_PROMPTS__ROLES_PREFIX="roles"

# API Keys (handled by RubyLLM)
export OPENAI_API_KEY="your_key_here"
export ANTHROPIC_API_KEY="your_key_here"
export GOOGLE_API_KEY="your_key_here"

# Flags (nested under flags:)
export AIA_FLAGS__CHAT="true"
export AIA_FLAGS__VERBOSE="true"
export AIA_FLAGS__DEBUG="false"

# Output settings (nested under output:)
export AIA_OUTPUT__FILE="/tmp/aia_output.md"
export AIA_OUTPUT__MARKDOWN="true"
export AIA_OUTPUT__LOG_FILE="~/.prompts/_prompts.log"

# Tools settings (nested under tools:)
export AIA_TOOLS__PATHS="/path/to/tools"
export AIA_TOOLS__REJECTED="dangerous_tool"

# Registry settings (nested under registry:)
export AIA_REGISTRY__REFRESH="7"

# Paths settings (nested under paths:)
export AIA_PATHS__AIA_DIR="~/.aia"
```

## Command Line Arguments

All options can be overridden via command line arguments. See [CLI Reference](cli-reference.md) for complete details.

## Embedded Directives

Prompts can contain configuration directives that override all other settings:

```markdown
//config model claude-3-sonnet
//config temperature 0.9
//config max_tokens 1500

Write a creative story about...
```

## Advanced Configuration

### Multi-Model Configuration

Configure multiple models with different settings:

```yaml
models:
  creative_writer:
    model: gpt-4
    temperature: 1.2
    max_tokens: 3000
    
  code_analyzer:
    model: claude-3-sonnet
    temperature: 0.1
    max_tokens: 4000
    
  quick_helper:
    model: gpt-3.5-turbo
    temperature: 0.7
    max_tokens: 1000
```

Use with: `aia --model creative_writer my_prompt`

### Tool Configuration

Configure tool paths and permissions:

```yaml
# Global tool settings
tool_paths:
  - ~/.aia/tools
  - /usr/local/share/aia-tools
  - ./project-tools

# Tool access control
allowed_tools:
  - file_reader
  - web_scraper
  - calculator

rejected_tools:
  - system_admin
  - file_writer
```

### MCP Client Configuration

Configure Model Context Protocol clients:

```yaml
mcp_clients:
  - name: github
    command: ["node", "/path/to/github-mcp-server"]
    env:
      GITHUB_TOKEN: "${GITHUB_TOKEN}"
      
  - name: filesystem
    command: ["mcp-server-filesystem"]
    args: ["/allowed/path1", "/allowed/path2"]
```

### Prompt Directory Structure

Configure how AIA organizes prompts:

```yaml
# Prompt organization
prompts_dir: ~/.prompts
roles_prefix: roles          # ~/.prompts/roles/
examples_prefix: examples    # ~/.prompts/examples/
templates_prefix: templates  # ~/.prompts/templates/

# Search paths (in order)
prompt_search_paths:
  - ~/.prompts
  - ~/.aia/system_prompts  
  - /usr/local/share/aia-prompts
```

## Configuration Examples

### Development Setup

```yaml
# ~/.aia/config.yml - Development setup
adapter: ruby_llm
model: gpt-4
temperature: 0.3
verbose: true
debug: true
out_file: ./dev_output.md
prompts_dir: ./prompts
tool_paths: [./tools]
```

### Production Setup

```yaml
# ~/.aia/config.yml - Production setup  
adapter: ruby_llm
model: gpt-3.5-turbo
temperature: 0.7
verbose: false
debug: false
log_file: /var/log/aia.log
prompts_dir: /etc/aia/prompts
tool_paths: [/usr/share/aia-tools]
allowed_tools: [safe_calculator, file_reader]
```

### Creative Writing Setup

```yaml
# ~/.aia/config.yml - Creative writing
adapter: ruby_llm
model: gpt-4
temperature: 1.1
max_tokens: 4000
speak: true
voice: nova
markdown: true
out_file: ~/writing/aia_output.md
append: true
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
aia --available_models

# Test configuration
aia --debug --verbose hello_world

# Test tools
aia --tools ./my_tools --debug test_prompt
```

### Common Issues

#### Model Not Found
- Check your API keys are set
- Verify the model name: `aia --available_models`
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
cp ~/.aia/config.yml ~/.aia/config.yml.backup

# Update configuration format
aia --migrate-config
```

### Configuration Templates

Generate configuration templates:

```bash
# Generate basic config
aia --generate-config basic > ~/.aia/config.yml

# Generate advanced config with all options
aia --generate-config full > ~/.aia/config.advanced.yml
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
- Use restrictive file permissions on config files: `chmod 600 ~/.aia/config.yml`
- Limit tool access with `allowed_tools` in production
- Use separate configurations for different environments
- Regularly rotate API keys