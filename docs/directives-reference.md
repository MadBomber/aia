# Directives Reference

Directives are special commands embedded in prompts that provide dynamic functionality. All directives begin with `//` and are processed before the prompt is sent to the AI model.

## Directive Syntax

```markdown
//directive_name arguments
```

Examples:
```markdown
//config model gpt-4
//include my_file.txt
//shell ls -la

<%= "Hello World" %>
```

## Configuration Directives

### `//config`
Configure AIA settings from within prompts.

**Syntax**: `//config [option] [value]`

**Examples**:
```markdown
//config model gpt-4
//config temperature 0.8
//config max_tokens 2000
//config verbose true
```

**Usage**:
- `//config` - Display all configuration
- `//config option` - Display specific configuration option
- `//config option value` - Set configuration option

**Aliases**: `//cfg`

### `//model`
Display or configure the AI model.

**Syntax**: `//model [model_name]`

**Examples**:
```markdown
//model gpt-4
//model claude-3-sonnet
//model
```

**Usage**:
- `//model` - Display current model configuration and details
- `//model name` - Set the model to use

For multi-model configurations, displays:
- Model count and primary model
- Consensus mode status
- Detailed information for each model including provider, context window, costs, and capabilities

### `//temperature`
Set the creativity/randomness of AI responses.

**Syntax**: `//temperature value`

**Examples**:
```markdown
//temperature 0.1    # Very focused
//temperature 0.7    # Balanced (default)
//temperature 1.2    # Creative
//temperature 2.0    # Very creative
```

**Aliases**: `//temp`

### `//top_p`
Set nucleus sampling parameter (alternative to temperature).

**Syntax**: `//top_p value`

**Examples**:
```markdown
//top_p 0.1     # Very focused
//top_p 0.9     # More diverse
```

**Aliases**: `//topp`

## File and Web Directives

### `//include`
Include content from files or websites.

**Syntax**: `//include path_or_url`

**Examples**:
```markdown
//include README.md
//include /path/to/config.yml
//include ~/Documents/notes.txt
//include https://example.com/page
```

**Features**:
- Supports tilde (`~`) and environment variable expansion
- Prevents circular inclusions
- Can include web pages (requires PUREMD_API_KEY)
- Handles both absolute and relative file paths

**Aliases**: `//import`

### `//webpage`
Include content from web pages (requires PUREMD_API_KEY).

**Syntax**: `//webpage url`

**Examples**:
```markdown
//webpage https://docs.example.com/api
//webpage https://github.com/user/repo/blob/main/README.md
```

**Prerequisites**:
Set the PUREMD_API_KEY environment variable:
```bash
export PUREMD_API_KEY="your_api_key"
```

**Aliases**: `//website`, `//web`

## Execution Directives

### `//shell`
Execute shell commands and include their output.

**Syntax**: `//shell command arguments`

**Examples**:
```markdown
//shell ls -la
//shell git status
//shell grep -n "TODO" *.rb
//shell ps aux | grep ruby
//shell curl -s https://api.github.com/user | jq '.name'
```

**Security Note**: Use with caution in shared environments. Commands execute with your current user permissions.

**Aliases**: `//sh`

### `//ruby`
Execute one line of Ruby code and include the result.

**Syntax**: `//ruby` (followed by Ruby code)

**Examples**:
```markdown
//ruby Time.now

//ruby Dir.pwd

//ruby File.read('config.yml')

//ruby [1,2,3,4,5].sum

//ruby "Hello, #{ENV['USER']}!"

//ruby require 'json'; JSON.pretty_generate({hello: 'world'})
```

**Features**:
- Full Ruby environment available
- Can use require for additional libraries (use `--require` CLI option)
- Access to all Ruby standard library
- Error handling with descriptive messages

**Aliases**: `//rb`

### `//say`
Speak text using system text-to-speech (macOS/Linux).

**Syntax**: `//say text to speak`

**Examples**:
```markdown
//say Build completed successfully
//say Warning: Check the logs
```

**Platform Support**:
- macOS: Uses built-in `say` command
- Linux: Requires `espeak` or similar TTS software

## Utility Directives

### `//tools`
Display available RubyLLM tools.

**Syntax**: `//tools`

**Example Output**:
```
Available Tools
===============

FileReader
----------
    Read and analyze file contents with support for multiple formats
    including text, JSON, YAML, and CSV files.

WebScraper
----------
    Extract and parse content from web pages with customizable
    selectors and filters.
```

### `//next`
Set the next prompt to execute in a workflow.

**Syntax**: `//next prompt_id`

**Examples**:
```markdown
//next analyze_results
//next generate_report
```

**Usage**:
- `//next` - Display current next prompt
- `//next prompt_id` - Set next prompt in workflow

### `//pipeline`
Define or modify a prompt workflow sequence.

**Syntax**: `//pipeline prompt1,prompt2,prompt3`

**Examples**:
```markdown
//pipeline extract_data,analyze,report
//pipeline code_review,optimize,test
```

**Usage**:
- `//pipeline` - Display current pipeline
- `//pipeline prompts` - Set pipeline sequence
- Can use comma-separated or space-separated prompt IDs

**Aliases**: `//workflow`

### `//terse`
Add instruction for brief responses.

**Syntax**: `//terse`

**Example**:
```markdown
//terse
Explain machine learning algorithms.
```

Adds: "Keep your response short and to the point." to the prompt.

### `//robot`
Generate ASCII art robot.

**Syntax**: `//robot`

Inserts a fun ASCII robot character for visual breaks in prompts.

## Context Management Directives

### `//checkpoint`
Create a named checkpoint of the current conversation context.

**Syntax**: `//checkpoint [name]`

**Examples**:
```markdown
//checkpoint                    # Auto-named checkpoint (1, 2, 3...)
//checkpoint important_decision # Named checkpoint
//checkpoint before_refactor    # Descriptive name
```

**Features**:
- **Auto-naming**: If no name provided, uses incrementing integers (1, 2, 3...)
- **Named checkpoints**: Use meaningful names for easy identification
- **Deep copying**: Safely stores complete conversation state
- **Chat mode only**: Only available during interactive chat sessions

**Usage**:
- `//checkpoint` - Create an auto-named checkpoint
- `//checkpoint name` - Create a checkpoint with specific name

**Aliases**: `//cp`

### `//restore`
Restore conversation context to a previously saved checkpoint.

**Syntax**: `//restore [name]`

**Examples**:
```markdown
//restore                      # Restore to last checkpoint
//restore important_decision    # Restore to named checkpoint
//restore 1                    # Restore to auto-named checkpoint
```

**Features**:
- **Default behavior**: Without a name, restores to the most recent checkpoint
- **Named restoration**: Restore to any previously saved checkpoint
- **Context truncation**: Removes all messages added after the checkpoint
- **Client refresh**: Automatically refreshes AI client context

**Usage**:
- `//restore` - Restore to the last checkpoint created
- `//restore name` - Restore to a specific named checkpoint
- Returns error message if checkpoint doesn't exist

### `//clear`
Clear conversation context in chat mode.

**Syntax**: `//clear`

**Usage**: Only available during chat sessions. Clears the conversation history and all checkpoints while keeping the session active.

### `//review`
Display current conversation context with checkpoint markers.

**Syntax**: `//review`

**Aliases**: `//context`

**Example Output**:
```
=== Chat Context ===
Total messages: 5
Checkpoints: ruby_basics, oop_concepts

1. [System]: You are a helpful assistant
2. [User]: Tell me about Ruby programming
3. [Assistant]: Ruby is a dynamic programming language...

📍 [Checkpoint: ruby_basics]
----------------------------------------
4. [User]: Now explain object-oriented programming
5. [Assistant]: Object-oriented programming (OOP) is...

📍 [Checkpoint: oop_concepts]
----------------------------------------
=== End of Context ===
```

**Features**:
- Shows complete conversation history with message numbers
- Displays checkpoint markers (📍) at their exact positions
- Lists all available checkpoints
- Truncates long messages for readability (200 characters)
- Shows total message count and checkpoint summary

## Model and Information Directives

### `//available_models`
List available AI models with filtering.

**Syntax**: `//available_models [filter1,filter2,...]`

**Examples**:
```markdown
//available_models
//available_models openai
//available_models gpt,4
//available_models text_to_image
//available_models claude,sonnet
```

**Filter Options**:
- Provider names: `openai`, `anthropic`, `google`, etc.
- Model names: `gpt`, `claude`, `gemini`, etc.
- Capabilities: `vision`, `function_calling`, `image_generation`
- Modalities: `text_to_text`, `text_to_image`, `image_to_text`

**Output includes**:
- Model name and provider
- Input cost per million tokens
- Context window size
- Input/output modalities
- Capabilities

**Aliases**: `//am`, `//available`, `//models`, `//all_models`, `//llms`

### `//compare`
Compare responses from multiple models.

**Syntax**: `//compare prompt --models model1,model2,model3`

**Examples**:
```markdown
//compare "Explain quantum computing" --models gpt-4,claude-3-sonnet,gemini-pro
//compare "Write a Python function to sort a list" --models gpt-3.5-turbo,gpt-4,claude-3-haiku
```

**Features**:
- Side-by-side model comparison
- Error handling for unavailable models
- Formatted output with clear model labels

**Aliases**: `//cmp`

### `//help`
Display available directives and their descriptions.

**Syntax**: `//help`

**Output**: Complete list of all directives with descriptions and aliases.

## Directive Processing Order

Directives are processed in the order they appear in the prompt:

1. **Configuration directives** (like `//config`, `//model`) are processed first
2. **File inclusion directives** (`//include`, `//webpage`) are processed next
3. **Execution directives** (`//shell`, `//ruby`) are processed
4. **Utility directives** are processed last

## Advanced Usage Patterns

### Combining Directives

```markdown
//config model gpt-4
//config temperature 0.3
//include project_context.md

Based on the project information above:
//shell git log --oneline -5

Analyze these recent commits and suggest improvements.
```

### Dynamic Configuration

```markdown
<% model_name = ENV['PREFERRED_MODEL'] || 'gpt-3.5-turbo' %>
//config model <%= model_name %>
//config temperature <%= ENV['AI_TEMPERATURE'] || '0.7' %>

Process this data with optimized settings.
```

### Conditional Execution

```markdown
<% if File.exist?('production.yml') %>
//include production.yml
<% else %>
//include development.yml
<% end %>

Configure the system based on environment.
```

### Workflow Automation

```markdown
//pipeline data_extraction,data_cleaning,analysis,reporting
//config model claude-3-sonnet
//config temperature 0.2

Begin automated data processing workflow.
```

## Error Handling

### Common Errors

**File Not Found**:
```
Error: File 'missing.txt' is not accessible
```

**Ruby Execution Error**:
```
This ruby code failed: invalid_syntax
SyntaxError: unexpected token
```

**Web Access Error**:
```
ERROR: PUREMD_API_KEY is required in order to include a webpage
```

**Missing Context Manager**:
```
Error: Context manager not available for //clear directive.
```

### Custom Directives

You can extend AIA with custom directives by creating Ruby files that define new directive methods:

```ruby
# examples/directives/ask.rb
module AIA
  class DirectiveProcessor
    private
    desc "A meta-prompt to LLM making its response available as part of the primary prompt"
    def ask(args, context_manager=nil)
      meta_prompt = args.empty? ? "What is meta-prompting?" : args.join(' ')
      AIA.config.client.chat(meta_prompt)
    end
  end
end
```

**Usage:** Load custom directives with the --tools option:

```bash
# Load custom directive
aia --tools examples/directives/ask.rb --chat

# Use the custom directive in prompts
//ask gather the latest closing data for the DOW, NASDAQ, and S&P 500
```

### Best Practices

1. **Test directives individually** before combining them
2. **Use absolute paths** for file includes when possible
3. **Handle errors gracefully** with conditional Ruby code
4. **Validate environment variables** before using them
5. **Use appropriate models** for different task types

## Security Considerations

- **Shell directives** execute with your user permissions
- **Ruby directives** have full access to the Ruby environment
- **File inclusion** can access any readable file
- **Web access** requires API keys and network access

### Safe Usage Tips

1. **Avoid shell commands** that modify system state in shared prompts
2. **Use environment variables** for sensitive data, not hardcoded values
3. **Validate inputs** in Ruby code before execution
4. **Limit file access** to necessary directories only
5. **Review prompts** from untrusted sources before execution

## Environment Variables for Directives

- `PUREMD_API_KEY` - Required for web page inclusion
- `PREFERRED_MODEL` - Default model selection
- `AI_TEMPERATURE` - Default temperature setting
- `AI_MAX_TOKENS` - Default token limit

## Related Documentation

- [CLI Reference](cli-reference.md) - Command-line options
- [Configuration](configuration.md) - Configuration file options
- [Advanced Prompting](advanced-prompting.md) - Advanced prompt techniques
- [Getting Started](guides/getting-started.md) - Basic usage tutorial
