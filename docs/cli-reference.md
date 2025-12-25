# CLI Reference

Complete reference for all AIA command-line arguments, options, and flags.

## Usage Patterns

```bash
# Basic usage
aia [options] [PROMPT_ID] [CONTEXT_FILE]*

# Chat mode
aia --chat [PROMPT_ID] [CONTEXT_FILE]*
aia --chat [CONTEXT_FILE]*

# Show help
aia --help

# Show version
aia --version
```

## Mode Options

### `--chat`
Begin a chat session with the LLM after processing all prompts in the pipeline.

```bash
aia --chat
aia --chat system_prompt
aia --chat my_prompt context.txt
```

### `-f, --fuzzy`
Use fuzzy matching for prompt search (requires `fzf` to be installed).

```bash
aia --fuzzy
aia -f
```

**Note**: If `fzf` is not installed, AIA will exit with an error.

### `--terse`
Adds a special instruction to the prompt asking the AI to keep responses short and to the point.

```bash
aia --terse my_prompt
aia --terse --chat
```

### `--tokens`
Display token usage information after each response in chat mode. Shows input tokens, output tokens, and model ID.

```bash
aia --chat --tokens
aia --chat --tokens --model gpt-4
```

### `--cost`
Include cost calculations with token usage. Automatically enables `--tokens`. Shows estimated cost based on the model's pricing.

```bash
aia --chat --cost
aia --chat --cost --model gpt-4,claude-3-sonnet
```

**Note**: `--cost` implies `--tokens`, so you don't need to specify both.

## Adapter Options

### `--adapter ADAPTER`
Interface that adapts AIA to the LLM. Currently supported: `ruby_llm`

```bash
aia --adapter ruby_llm
```

**Valid adapters**: `ruby_llm`

### `--available-models [QUERY]`
List (then exit) available models that match the optional query. Query is a comma-separated list of AND components.

```bash
# List all models
aia --available-models

# Filter by provider
aia --available-models openai

# Filter by capability and provider
aia --available-models openai,mini

# Filter by modality
aia --available-models text_to_text

# Complex filter
aia --available-models openai,gpt,text_to_image
```

## Model Options

### `-m MODEL, --model MODEL`
Name of the LLM model(s) to use. For multiple models, use comma-separated values.

Supports inline role assignment using `MODEL=ROLE` syntax to assign specific roles to individual models.

```bash
# Single model
aia --model gpt-4 my_prompt

# Multiple models (parallel processing)
aia --model "gpt-4,claude-3-sonnet,gemini-pro" my_prompt

# Short form
aia -m gpt-3.5-turbo my_prompt

# Single model with role (inline syntax)
aia --model gpt-4o=architect design_review.md

# Multiple models with different roles
aia --model "gpt-4o=architect,claude=security,gemini=performance" my_prompt

# Same model with multiple roles for diverse perspectives
aia --model "gpt-4o=optimist,gpt-4o=pessimist,gpt-4o=realist" project_plan.md

# Mixed: some models with roles, some without
aia --model "gpt-4o=expert,claude,gemini" my_prompt
```

**See also**: `--role` for applying a role to all models, `--list-roles` for discovering available roles.

### `--[no-]consensus`
Enable/disable consensus mode for multi-model responses. When enabled, AIA attempts to create a consensus response from multiple models.

```bash
# Enable consensus mode (requires multiple models)
aia --model "gpt-4,claude-3-sonnet" --consensus my_prompt

# Disable consensus mode (default: show individual responses)
aia --model "gpt-4,claude-3-sonnet" --no-consensus my_prompt
```

### `--sm, --speech-model MODEL`
Speech model to use for text-to-speech functionality.

```bash
aia --speech-model tts-1 --speak my_prompt
aia --sm tts-1-hd --speak my_prompt
```

### `--tm, --transcription-model MODEL`
Transcription model to use for speech-to-text functionality.

```bash
aia --transcription-model whisper-1 audio_file.wav
aia --tm whisper-1 my_audio.mp3
```

## File Options

### `-c, --config-file FILE`
Load configuration from a specific file.

```bash
aia --config-file /path/to/config.yml my_prompt
aia -c ~/.aia/custom_config.yml my_prompt
```

### `-o, --[no-]output [FILE]`
Output file for saving AI responses.

```bash
# Save to default file (temp.md)
aia --output my_prompt

# Save to specific file
aia --output output.txt my_prompt

# Use absolute path
aia --output /tmp/ai_response.md my_prompt

# Disable file output
aia --no-output my_prompt
```

### `-a, --[no-]append`
Append to output file instead of overwriting.

```bash
# Append mode
aia --output log.md --append my_prompt

# Overwrite mode (default)
aia --output log.md --no-append my_prompt
```

### `--[no-]history-file [FILE]`
Conversation history file for logging prompts and responses.

```bash
# Enable history logging to default location
aia --history-file my_prompt

# Log to specific file
aia --history-file /var/log/aia_history.log my_prompt

# Disable history logging
aia --no-history-file my_prompt
```

### `--md, --[no-]markdown`
Format output with Markdown.

```bash
# Enable Markdown formatting
aia --markdown my_prompt

# Disable Markdown formatting
aia --no-markdown my_prompt
```

## Prompt Options

### `--prompts-dir DIR`
Directory containing prompt files.

```bash
aia --prompts-dir /custom/prompts my_prompt
aia --prompts-dir ~/work/prompts my_prompt
```

### `--roles-prefix PREFIX`
Subdirectory name for role files (default: `roles`).

```bash
# Use custom roles directory
aia --roles-prefix personas --role expert

# Results in looking for roles in ~/.prompts/personas/expert.txt
```

### `-r, --role ROLE_ID`
Role ID to prepend to the prompt. This applies the same role to all models.

For per-model role assignment, use the inline `MODEL=ROLE` syntax with `--model` instead.

```bash
# Apply role to all models
aia --role expert my_prompt
aia -r teacher explain_concept

# With multiple models (same role for all)
aia --model "gpt-4,claude" --role architect design.md

# Per-model roles (inline syntax - see --model)
aia --model "gpt-4=architect,claude=security" design.md
```

**See also**: `--model` for inline role syntax, `--list-roles` for discovering available roles.

### `--list-roles`
List all available roles and exit. Shows role IDs and their descriptions from the roles directory.

```bash
# List all available roles
aia --list-roles

# Example output:
# Available roles in /Users/you/.prompts/roles:
#   architect    - Software architecture expert
#   security     - Security analysis specialist
#   performance  - Performance optimization expert
#   debugger     - Expert debugging assistant
#   optimist     - Positive perspective analyzer
#   pessimist    - Critical risk analyzer
#   realist      - Balanced pragmatic analyzer
```

Roles are discovered from:
- **Default location**: `~/.prompts/roles/`
- **Custom location**: Set via `--prompts-dir` and `--roles-prefix`
- **Nested directories**: Supports subdirectories like `roles/software/architect.txt`

**Use case**: Discover available roles before using them with `--role` or inline `MODEL=ROLE` syntax.

**See also**: `--role`, `--model`, `--prompts-dir`, `--roles-prefix`

### `-n, --next PROMPT_ID`
Next prompt to process (can be used multiple times to build a pipeline).

```bash
aia my_prompt --next second_prompt --next third_prompt
aia -n analysis -n summary my_prompt
```

### `-p PROMPTS, --pipeline PROMPTS`
Pipeline of comma-separated prompt IDs to process.

```bash
aia --pipeline "analysis,summary,report" my_data
aia -p "review,optimize,test" my_code.py
```

### `-x, --[no-]exec`
Designate an executable prompt file.

```bash
# Treat prompt as executable
aia --exec my_script_prompt

# Treat as regular prompt (default)
aia --no-exec my_script_prompt
```

### `--system-prompt PROMPT_ID`
System prompt ID to use for chat sessions.

```bash
aia --system-prompt helpful_assistant --chat
aia --system-prompt code_expert --chat my_code.py
```

### `--regex PATTERN`
Regex pattern to extract parameters from prompt text.

```bash
aia --regex '\{\{(\w+)\}\}' my_template_prompt
aia --regex '<%=\s*(\w+)\s*%>' erb_prompt
```

## AI Parameters

### `-t, --temperature TEMP`
Temperature for text generation (0.0 to 2.0). Higher values make output more creative and random.

```bash
# Conservative/focused
aia --temperature 0.1 analysis_prompt

# Balanced (default ~0.7)
aia --temperature 0.7 my_prompt

# Creative
aia --temperature 1.5 creative_writing

# Very creative
aia -t 2.0 brainstorm_ideas
```

### `--max-tokens TOKENS`
Maximum tokens for text generation.

```bash
aia --max-tokens 100 short_summary
aia --max-tokens 4000 detailed_analysis
```

### `--top-p VALUE`
Top-p sampling value (0.0 to 1.0). Alternative to temperature for controlling randomness.

```bash
aia --top-p 0.1 precise_answer
aia --top-p 0.9 creative_response
```

### `--frequency-penalty VALUE`
Frequency penalty (-2.0 to 2.0). Positive values discourage repetition.

```bash
# Discourage repetition
aia --frequency-penalty 0.5 my_prompt

# Encourage repetition
aia --frequency-penalty -0.5 my_prompt
```

### `--presence-penalty VALUE`
Presence penalty (-2.0 to 2.0). Positive values encourage discussing new topics.

```bash
# Encourage new topics
aia --presence-penalty 0.5 broad_discussion

# Focus on current topics
aia --presence-penalty -0.5 deep_dive
```

## Audio/Image Options

### `--speak`
Convert text to audio and play it. Uses the configured speech model and voice.

```bash
aia --speak my_prompt
aia --speak --voice nova my_prompt
```

### `--voice VOICE`
Voice to use for speech synthesis.

```bash
aia --voice alloy --speak my_prompt
aia --voice echo --speak my_prompt
aia --voice fable --speak my_prompt
aia --voice nova --speak my_prompt  
aia --voice onyx --speak my_prompt
aia --voice shimmer --speak my_prompt
```

### `--is, --image-size SIZE`
Image size for image generation.

```bash
aia --image-size 1024x1024 image_prompt
aia --is 1792x1024 wide_image
aia --is 1024x1792 tall_image
```

**Common sizes**: `256x256`, `512x512`, `1024x1024`, `1792x1024`, `1024x1792`

### `--iq, --image-quality QUALITY`
Image quality for image generation.

```bash
aia --image-quality standard image_prompt
aia --iq hd high_quality_image
```

**Values**: `standard`, `hd`

### `--style, --image-style STYLE`
Style for image generation.

```bash
aia --image-style vivid colorful_image
aia --style natural realistic_image
```

**Values**: `vivid`, `natural`

## Tool Options

### `--rq LIBS, --require LIBS`
Ruby libraries to require for Ruby directive execution.

```bash
aia --require json,csv data_processing_prompt
aia --rq "net/http,uri" web_request_prompt
```

### `--tools PATH_LIST`
Add tool file(s) or directories. Comma-separated paths.

```bash
# Single tool file
aia --tools ./my_tool.rb my_prompt

# Multiple tools
aia --tools "./tool1.rb,./tool2.rb" my_prompt

# Tool directory
aia --tools ./tools/ my_prompt

# Mixed paths
aia --tools "./tools/,./special_tool.rb" my_prompt
```

### `--at, --allowed-tools TOOLS_LIST`
Allow only these tools to be used. Security feature to restrict tool access.

```bash
# Allow specific tools
aia --allowed-tools "calculator,file_reader" my_prompt
aia --at "web_scraper,data_analyzer" analysis_prompt
```

### `--rt, --rejected-tools TOOLS_LIST`
Reject/block these tools from being used.

```bash
# Block dangerous tools
aia --rejected-tools "file_writer,system_command" my_prompt
aia --rt "network_access" secure_prompt
```

## Utility Options

### Log Level Options

AIA provides multiple log level options to control logging verbosity. These options set the log level for all three loggers:
- **aia**: Used within the AIA codebase for application-level logging
- **llm**: Passed to the RubyLLM gem's configuration (`RubyLLM.logger`)
- **mcp**: Passed to the RubyLLM::MCP process (`RubyLLM::MCP.logger`)

Only one log level option should be used at a time.

### `-d, --debug`
Enable debug output (most verbose) and set all loggers to DEBUG level. Also sets `$DEBUG_ME = true` for the debug_me gem.

```bash
aia --debug my_prompt
aia -d --chat
```

### `--no-debug`
Explicitly disable debug output. Sets `$DEBUG_ME = false`.

```bash
aia --no-debug my_prompt
```

### `--info`
Set all loggers to INFO level. Shows informational messages and above.

```bash
aia --info my_prompt
aia --info --chat
```

### `--warn`
Set all loggers to WARN level (this is the default). Shows warnings, errors, and fatal messages.

```bash
aia --warn my_prompt
```

### `--error`
Set all loggers to ERROR level. Shows only errors and fatal messages.

```bash
aia --error my_prompt
aia --error --chat
```

### `--fatal`
Set all loggers to FATAL level (least verbose). Shows only critical/fatal messages.

```bash
aia --fatal my_prompt
```

**Log Level Hierarchy** (from most to least verbose):
1. `debug` - All messages including detailed debugging information
2. `info` - Informational messages and above
3. `warn` - Warnings, errors, and fatal messages (default)
4. `error` - Only errors and fatal messages
5. `fatal` - Only critical/fatal messages

### `-v, --[no-]verbose`
Enable/disable verbose output.

```bash
# Verbose mode
aia --verbose my_prompt
aia -v my_prompt

# Quiet mode
aia --no-verbose my_prompt
```

### `--refresh DAYS`
Refresh models database interval in days.

```bash
# Refresh immediately
aia --refresh 0

# Refresh weekly
aia --refresh 7

# Refresh monthly
aia --refresh 30
```

### `--dump FILE`
Dump current configuration to a file for inspection or backup.

```bash
aia --dump current_config.yaml
aia --dump /tmp/aia_config_backup.yml
```

### `--completion SHELL`
Show completion script for shell integration.

```bash
# Bash completion
aia --completion bash > ~/.bash_completion.d/aia

# Zsh completion  
aia --completion zsh > ~/.zsh/completions/_aia

# Fish completion
aia --completion fish > ~/.config/fish/completions/aia.fish
```

**Supported shells**: `bash`, `zsh`, `fish`

### `--version`
Show AIA version and exit.

```bash
aia --version
```

### `-h, --help`
Show help message and exit.

```bash
aia --help
aia -h
```

## Usage Examples

### Basic Examples

```bash
# Simple prompt execution
aia hello_world

# Chat mode
aia --chat

# Use specific model
aia --model gpt-4 code_review my_script.py

# Fuzzy prompt selection
aia --fuzzy
```

### Advanced Examples

```bash
# Multi-model consensus
aia --model "gpt-4,claude-3-sonnet" --consensus analysis_prompt data.csv

# Creative writing with voice output
aia --model gpt-4 --temperature 1.2 --speak --voice nova story_prompt

# Secure tool usage
aia --tools ./safe_tools/ --allowed-tools "calculator,file_reader" --rejected-tools "system_command" analysis_prompt

# Pipeline with custom configuration
aia --pipeline "extract,analyze,summarize" --temperature 0.3 --max-tokens 2000 --output report.md data_source.txt

# Debug mode with verbose output
aia --debug --verbose --model claude-3-sonnet problematic_prompt
```

### Configuration Examples

```bash
# Use custom configuration
aia --config-file ./project_config.yml --prompts-dir ./project_prompts/ my_prompt

# Save output with markdown formatting
aia --output analysis.md --markdown --append data_analysis dataset.csv

# Audio processing
aia --transcription-model whisper-1 --speech-model tts-1-hd --voice echo audio_prompt audio_file.wav
```

## Exit Codes

- `0` - Success
- `1` - General error (invalid arguments, file not found, etc.)
- `2` - Configuration error
- `3` - Model/API error
- `4` - Tool execution error

## Environment Variables

Many CLI options have corresponding environment variables with the `AIA_` prefix.
Use double underscore (`__`) for nested configuration sections:

```bash
# Model configuration (top-level)
export AIA_MODEL="gpt-4"

# Model with inline role syntax
export AIA_MODEL="gpt-4o=architect"

# Multiple models with roles
export AIA_MODEL="gpt-4o=architect,claude=security,gemini=performance"

# LLM settings (nested under llm:)
export AIA_LLM__TEMPERATURE="0.8"

# Prompts settings (nested under prompts:)
export AIA_PROMPTS__DIR="/custom/prompts"

# Flags (nested under flags:)
export AIA_FLAGS__VERBOSE="true"
export AIA_FLAGS__DEBUG="false"
export AIA_FLAGS__CHAT="true"

# Output settings (nested under output:)
export AIA_OUTPUT__FILE="./output.md"
```

**Note**: The `AIA_MODEL` environment variable supports the same inline `MODEL=ROLE` syntax as the `--model` CLI option.

See [Configuration](configuration.md#environment-variables) for a complete list.

## Configuration Precedence

Options are resolved in this order (highest to lowest precedence):

1. Command line arguments (including inline `MODEL=ROLE` syntax)
2. Environment variables (including inline syntax in `AIA_MODEL`)
3. Configuration files (including array format with roles)
4. Built-in defaults

**Role-specific precedence**: When using the role feature, inline `MODEL=ROLE` syntax takes precedence over the `--role` flag, which takes precedence over roles in config files.

## Related Documentation

- [Configuration Guide](configuration.md) - Detailed configuration options
- [Getting Started](guides/getting-started.md) - Basic usage tutorial
- [Advanced Prompting](advanced-prompting.md) - Advanced usage patterns
- [Directives Reference](directives-reference.md) - Prompt directive reference