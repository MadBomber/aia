<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

- [Directives Reference](#directives-reference)
  - [Quick Reference](#quick-reference)
  - [Directive Syntax](#directive-syntax)
  - [Configuration Directives](#configuration-directives)
    - [`/config`](#config)
    - [`/model`](#model)
    - [`/temperature`](#temperature)
    - [`/top_p`](#top_p)
    - [`/cost`](#cost)
  - [File and Web Directives](#file-and-web-directives)
    - [`/include`](#include)
    - [`/paste`](#paste)
    - [`/webpage`](#webpage)
    - [`/skill`](#skill)
    - [`/skills`](#skills)
  - [Execution Directives](#execution-directives)
    - [`/ruby`](#ruby)
    - [`/say`](#say)
    - [`/concurrent`](#concurrent)
    - [`/verify`](#verify)
    - [`/decompose`](#decompose)
    - [`/debate`](#debate)
    - [`/delegate`](#delegate)
    - [`/spawn`](#spawn)
  - [Utility Directives](#utility-directives)
    - [`/tools`](#tools)
    - [`/rules`](#rules)
    - [`/next`](#next)
    - [`/pipeline`](#pipeline)
    - [`/mcp`](#mcp)
    - [`/robots`](#robots)
    - [`/terse`](#terse)
    - [`/robot`](#robot)
  - [Context Management Directives](#context-management-directives)
    - [`/checkpoint`](#checkpoint)
    - [`/restore`](#restore)
    - [`/clear`](#clear)
    - [`/review`](#review)
    - [`/checkpoints_list`](#checkpoints_list)
  - [TrakFlow Directives](#trakflow-directives)
    - [`/tasks`](#tasks)
    - [`/plan`](#plan)
    - [`/task`](#task)
  - [Model and Information Directives](#model-and-information-directives)
    - [`/available_models`](#available_models)
    - [`/compare`](#compare)
    - [`/help`](#help)
  - [Directive Processing Order](#directive-processing-order)
  - [Advanced Usage Patterns](#advanced-usage-patterns)
    - [Combining Directives](#combining-directives)
    - [Dynamic Configuration](#dynamic-configuration)
    - [Conditional Execution](#conditional-execution)
    - [Workflow Automation](#workflow-automation)
  - [Error Handling](#error-handling)
    - [Common Errors](#common-errors)
    - [Custom Directives](#custom-directives)
    - [Best Practices](#best-practices)
  - [Security Considerations](#security-considerations)
    - [Safe Usage Tips](#safe-usage-tips)
  - [Environment Variables for Directives](#environment-variables-for-directives)
  - [Related Documentation](#related-documentation)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

# Directives Reference

Directives are slash commands available during interactive chat sessions. All directives begin with `/` and are processed before the prompt is sent to the AI model.

Use `/help` at any time to see all available directives.

## Quick Reference

| Directive | Aliases | Description |
|-----------|---------|-------------|
| `/config` | `/cfg` | View or set configuration values |
| `/model` | | View or change the AI model |
| `/temperature` | `/temp` | Set temperature parameter |
| `/top_p` | `/topp` | Set top_p parameter |
| `/cost` | | Dump session cost/token metrics as CSV |
| `//include` | `//import` | Include file content at prompt load time (prompt_manager, not chat-time) |
| `/webpage` | `/website`, `/web` | Fetch and include web content |
| `/skill` | | Include a Claude Code skill |
| `/skills` | | List available Claude Code skills |
| `/paste` | `/clipboard` | Paste from system clipboard |
| `/ruby` | `/rb` | Execute Ruby code |
| `/say` | | Text-to-speech |
| `/concurrent` | `/conc` | Concurrent MCP server access |
| `/verify` | | Verification network (two answers + reconciliation) |
| `/decompose` | | Decompose prompt into parallel sub-tasks |
| `/debate` | | Multi-round debate between robots |
| `/delegate` | `/del` | Delegate subtasks via TrakFlow plan |
| `/spawn` | | Spawn a specialist robot |
| `/tools` | | List available tools |
| `/rules` | | Show decompiled KBS routing rules (optional filter) |
| `/mcp` | | MCP server connection status |
| `/robots` | | Show active robot configuration |
| `/robot` | | ASCII robot art |
| `/help` | | Show directive help |
| `/checkpoint` | `/ckp`, `/cp` | Create a conversation checkpoint |
| `/restore` | | Restore to a checkpoint |
| `/clear` | | Clear conversation context |
| `/review` | `/context` | Review conversation with checkpoint markers |
| `/checkpoints_list` | `/checkpoints` | List all checkpoints |
| `/tasks` | `/tf` | Show TrakFlow ready tasks |
| `/plan` | | Create a TrakFlow plan |
| `/task` | | Create a TrakFlow task |
| `/available_models` | `/am`, `/available`, `/all_models`, `/models`, `/llms` | List available AI models |
| `/compare` | `/cmp` | Compare responses from multiple models |
| `next` | | YAML front matter key: set next prompt in workflow (prompt_manager) |
| `pipeline` | `workflow` | YAML front matter key: define prompt workflow sequence (prompt_manager) |

## Directive Syntax

```markdown
/directive_name arguments
```

Examples:
```markdown
/config temperature 0.8
/model gpt-4o, claude-sonnet-4
/debate
Should we use a monolith or microservices?
```

## Configuration Directives

### `/config`
Configure AIA settings from within prompts.

**Syntax**: `/config [option] [value]`

**Examples**:
```markdown
/config model gpt-4
/config temperature 0.8
/config max_tokens 2000
/config verbose true
```

**Usage**:
- `/config` - Display all configuration
- `/config option` - Display specific configuration option
- `/config option value` - Set configuration option

**Aliases**: `/cfg`

### `/model`
Display or switch the AI model. Changes take effect immediately — the client is recreated with the new model(s) without restarting the session.

**Syntax**: `/model [model_spec]`

**Examples**:
```markdown
/model                                        # Show current model details
/model gpt-4o-mini                            # Switch to a single model
/model claude-sonnet-4                        # Switch provider (Anthropic)
/model gpt-4o, claude-sonnet-4                # Switch to multi-model
/model gpt-4o=architect, claude=security      # Multi-model with roles
```

**Usage**:
- `/model` - Display current model configuration and details
- `/model name` - Switch to a single model (any provider)
- `/model name1, name2` - Switch to multi-model configuration
- `/model name1=role1, name2=role2` - Multi-model with per-model roles

Comma-separated values follow the same `MODEL[=ROLE]` syntax used by the `--model` CLI flag.

For single-model display, shows full model details including provider, context window, pricing, and capabilities.

For multi-model configurations, displays:
- Model count and primary model
- Consensus mode status
- Detailed information for each model including provider, context window, costs, and capabilities

### `/temperature`
Set the creativity/randomness of AI responses.

**Syntax**: `/temperature value`

**Examples**:
```markdown
/temperature 0.1    # Very focused
/temperature 0.7    # Balanced (default)
/temperature 1.2    # Creative
/temperature 2.0    # Very creative
```

**Aliases**: `/temp`

### `/top_p`
Set nucleus sampling parameter (alternative to temperature).

**Syntax**: `/top_p value`

**Examples**:
```markdown
/top_p 0.1     # Very focused
/top_p 0.9     # More diverse
```

**Aliases**: `/topp`

### `/cost`
Dump session cost and token metrics as CSV.

**Syntax**: `/cost`

**Example Output**:
```
model,input_tokens,output_tokens,total_tokens,cost,elapsed,similarity
gpt-4o,1234,567,1801,$0.01234,2.3s,ref
claude-sonnet-4-20250514,1234,890,2124,$0.00987,3.1s,87.2%
TOTAL,2468,1457,3925,$0.02221,3.1s,
```

**Features**:
- Shows per-turn breakdown: model, token counts, cost, elapsed time
- Includes similarity scores when multi-model mode is active
- Appends CSV to output file when `--output` is configured
- Totals row at the bottom summarizes the session

## File and Web Directives

### `/include`
Include content from files into a prompt file.

> **Note**: `/include` (also written as `//include` in prompt files) is handled by the
> `prompt_manager` gem **during prompt loading**, before AIA processes the prompt.
> It is NOT a chat-time directive — you cannot type `/include` at the chat prompt and
> have it evaluated interactively. The inclusion happens when the prompt file is read
> from disk, so the included content is already present by the time AIA sees the prompt.

**Syntax** (inside a `.md` prompt file): `//include path_or_url`

**Examples** (in prompt files):
```markdown
//include README.md
//include /path/to/config.yml
//include ~/Documents/notes.md
```

**Features**:
- Supports tilde (`~`) and environment variable expansion
- Prevents circular inclusions
- Handles both absolute and relative file paths

**Aliases**: `//import`

### `/paste`
Insert content from the system clipboard.

**Syntax**: `/paste`

**Examples**:
```markdown
/paste
```

**Features**:
- Inserts the current clipboard contents directly into the prompt
- Useful for quickly including copied text, code, or data
- Works across different platforms (macOS, Linux, Windows)
- Handles multi-line clipboard content

**Aliases**: `/clipboard`

### `/webpage`
Include content from web pages (requires PUREMD_API_KEY).

**Syntax**: `/webpage url`

**Examples**:
```markdown
/webpage https://docs.example.com/api
/webpage https://github.com/user/repo/blob/main/README.md
```

**Prerequisites**:
Set the PUREMD_API_KEY environment variable:
```bash
export PUREMD_API_KEY="your_api_key"
```

**Aliases**: `/website`, `/web`

### `/skill`
Include a Claude Code skill into the conversation context.

**Syntax**: `/skill skill_name`

**Examples**:
```markdown
/skill code-quality          # Exact match
/skill code                  # Prefix match (finds first match starting with "code")
/skill frontend-design       # Exact match
/skill front                 # Prefix match (finds "frontend-design")
```

**Features**:
- Reads `SKILL.md` from `~/.claude/skills/<skill_name>/`
- Supports prefix matching: `/skill code` finds the first subdirectory starting with "code"
- Exact matches take priority over prefix matches
- Returns the skill content for inclusion in the prompt

**Error Handling**:
- Missing skill name: `Error: /skill requires a skill name`
- No matching directory: `Error: No skill matching 'name' found in ~/.claude/skills`
- Directory exists but no SKILL.md: `Error: Skill directory 'name' has no SKILL.md`

### `/skills`
List all available Claude Code skills.

**Syntax**: `/skills`

**Example Output**:
```
Available Skills
================
  algorithmic-art
  api-developer
  code-assist
  code-quality
  frontend-design

Total: 5 skills
```

**Features**:
- Lists subdirectory basenames from `~/.claude/skills/`
- Sorted alphabetically
- Displays to STDOUT only (does not inject content into the prompt)

## Execution Directives

### `/ruby`
Execute arbitrary Ruby code and insert the result.

**Syntax**: `/ruby expression`

**Examples**:
```markdown
/ruby Time.now.strftime('%Y-%m-%d')
/ruby Dir.glob('*.rb').size
/ruby ENV['USER']
```

**Features**:
- Evaluates the Ruby expression and inserts the string result into the prompt
- Has full access to the Ruby environment and loaded gems
- Returns error details if execution fails

**Aliases**: `/rb`

### `/say`
Speak text using system text-to-speech (macOS/Linux).

**Syntax**: `/say text to speak`

**Examples**:
```markdown
/say Build completed successfully
/say Warning: Check the logs
```

**Platform Support**:
- macOS: Uses built-in `say` command
- Linux: Requires `espeak` or similar TTS software

### `/concurrent`
Execute the next prompt with concurrent MCP server access. AIA groups independent MCP servers and queries them in parallel, then synthesizes the results.

**Syntax**: `/concurrent`

**Examples**:
```markdown
/concurrent
What files changed this week and are there any open issues related to them?
```

**Features**:
- Enables concurrent MCP mode for the next prompt only
- Independent MCP servers are queried in parallel
- A "Weaver" synthesizer robot merges the results
- Requires at least 2 MCP servers to be connected

**Aliases**: `/conc`

### `/verify`
Run the next prompt through a verification network. Two independent robots answer the same question, then a reconciler compares and merges the responses.

**Syntax**: `/verify`

**Examples**:
```markdown
/verify
Is this SQL query safe from injection attacks?
```

**Features**:
- Two robots independently answer the prompt
- A third robot reconciles any differences
- Increases confidence in factual or analytical answers
- Requires a multi-model or network configuration

### `/decompose`
Decompose the next prompt into parallel sub-tasks. The prompt is broken into independent pieces, each solved separately, then the results are combined.

**Syntax**: `/decompose`

**Examples**:
```markdown
/decompose
Analyze this codebase: review the test coverage, check for security issues, and assess performance.
```

**Features**:
- Automatically identifies independent sub-tasks in the prompt
- Sub-tasks are executed in parallel when possible
- Results are synthesized into a single response
- Best for prompts with multiple distinct aspects

### `/debate`
Enable multi-round debate between robots in the network. Robots argue different perspectives and converge toward a consensus answer.

**Syntax**: `/debate`

**Examples**:
```markdown
/debate
Should we use microservices or a monolith for this project?
```

**Features**:
- Runs up to 5 rounds of debate between network robots
- Each robot sees all previous arguments before responding
- Debate ends early when robots signal convergence (CONVERGED keyword)
- Results include all debate rounds formatted as markdown
- Writes debate history to network memory for context
- Requires a multi-model network (2+ models)

### `/delegate`
Delegate subtasks to specific robots via a structured TrakFlow plan. The lead robot decomposes the prompt into a JSON task plan, and robots execute steps sequentially.

**Syntax**: `/delegate`

**Examples**:
```markdown
/delegate
Build a REST API with authentication, rate limiting, and documentation.
```

**Features**:
- Lead robot creates a structured task decomposition (JSON)
- TaskCoordinator creates a TrakFlow plan from the decomposition
- Each subtask is assigned to and executed by a specific robot
- Prior step results flow as context into subsequent steps
- Creates a full execution trace with per-step results
- Requires a multi-model network

**Aliases**: `/del`

### `/spawn`
Spawn a specialist robot for the next prompt. Creates (or reuses) a dynamically configured robot tuned for a specific domain.

**Syntax**: `/spawn [specialist_type]`

**Examples**:
```markdown
/spawn security
Audit this authentication module for vulnerabilities.

/spawn
Write a comprehensive test suite for the User model.
```

**Features**:
- With a type argument: spawns a specialist of the named type (e.g., `security`, `testing`, `performance`)
- Without a type: auto-detects the best specialist type from the prompt content
- Specialist robots are cached and reused within the session
- Creates a TrakFlow task when task coordination is active
- Specialist inherits the current model but gets a domain-specific system prompt

## Utility Directives

### `/tools`
Display available RubyLLM tools with optional filtering.

**Syntax**: `/tools [filter]`

**Parameters**:
- `filter` (optional) - Case-insensitive substring to filter tool names

**Examples**:
```markdown
/tools           # List all available tools
/tools file      # List tools with "file" in the name
/tools analyzer  # List tools with "analyzer" in the name
```

**Example Output** (unfiltered):
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

**Example Output** (filtered with `/tools file`):
```
Available Tools (filtered by 'file')
====================================

FileReader
----------
    Read and analyze file contents with support for multiple formats
    including text, JSON, YAML, and CSV files.
```

**Notes**:
- When no tools match the filter, displays "No tools match the filter: [filter]"
- Filtering is case-insensitive (e.g., "File", "FILE", and "file" all match)

### `/rules`
Show decompiled KBS routing rules across all knowledge bases, with optional substring filtering.

**Syntax**: `/rules [filter]`

**Parameters**:
- `filter` (optional) - Case-insensitive substring to narrow which rules are displayed

**Examples**:
```markdown
/rules              # Show all KBS routing rules
/rules tool         # Show only rules containing "tool"
/rules mcp          # Show rules related to MCP routing
/rules domain       # Show domain-matching rules
```

**Example Output** (unfiltered):
```
KBS Rules
=========

route_kb (3 rules)
------------------

  rule :route_to_file_tool do
    condition { input.include?("file") }
    action    { activate :FileReaderTool }
  end

  rule :route_to_web_tool do
    condition { input.include?("http") || input.include?("url") }
    action    { activate :WebScraperTool }
  end
```

**Example Output** (filtered with `/rules tool`):
```
KBS Rules (filtered by 'tool')
===============================

route_kb (2 rules)
------------------

  rule :route_to_file_tool do
    condition { input.include?("file") }
    action    { activate :FileReaderTool }
  end
```

**Notes**:
- Rules are grouped by knowledge base name with a count
- Each rule's full decompiled source is shown with two-space indentation
- When no rules match the filter, displays "No rules match the filter: [filter]"
- When no rule router is available, displays "No rule router available"
- Filtering is case-insensitive

### `/next`
Declare the next prompt to execute after this one in a workflow.

> **Note**: `next` is a **YAML front matter key** written at the top of a `.md` prompt
> file, not a chat-time slash command. It is processed by the prompt loader when the
> file is read, not interactively during a chat session.

**Syntax** (YAML front matter in a prompt file):
```yaml
---
next: analyze_results
---
Your prompt body here.
```

**Examples** (prompt files with `next` front matter):
```yaml
---
next: generate_report
---
Summarize the extracted data.
```

```yaml
---
next: finalize
---
Analyze the results and identify key findings.
```

**Usage**: When AIA finishes running a prompt that has a `next` key in its front
matter, it automatically loads and executes the named prompt next.

### `/pipeline`
Declare an ordered sequence of prompts to run as a workflow.

> **Note**: `pipeline` is a **YAML front matter key** written at the top of a `.md`
> prompt file, not a chat-time slash command. It is processed by the prompt loader
> when the file is read, not interactively during a chat session. The alias
> `workflow` is also accepted as a front matter key.

**Syntax** (YAML front matter in a prompt file):
```yaml
---
pipeline: prompt1, prompt2, prompt3
---
Your prompt body here.
```

**Examples** (prompt files with `pipeline` front matter):
```yaml
---
pipeline: extract_data, analyze, report
---
Begin the automated data processing workflow.
```

```yaml
---
workflow: code_review, optimize, test
---
Start the code quality pipeline.
```

**Usage**: When AIA loads a prompt that has a `pipeline` (or `workflow`) key in its
front matter, it queues all listed prompts in order and runs them sequentially.

**Aliases**: `workflow` (as a front matter key)

### `/mcp`
Show MCP server connection status and available tools per server.

**Syntax**: `/mcp`

**Example Output**:
```
MCP Server Status
=================
Defined: 5  Connected: 3  Failed: 2

Connected Servers:
  github (12 tools)
    - github_create_issue
    - github_list_repos
    ...
  filesystem (4 tools)
    - read_file
    - write_file
    ...

Failed Servers:
  slack: Connection refused
  jira: Authentication failed
```

**Features**:
- Shows count of defined, connected, and failed MCP servers
- Lists each connected server with its tool count and tool names
- Shows error details for failed server connections
- Respects `--mcp-use` and `--mcp-skip` filtering

### `/robots`
Show active robot configuration — the current robot or network topology.

**Syntax**: `/robots`

**Example Output** (single robot):
```
Active Robot
============
Mode: Single

  Tobor
    Model:    gpt-4o (openai)
    Wage:     $0.0050 in / $0.0150 out per 1K tokens
    Tools:    8 (3 local, 5 mcp)
    Role:     (default)
```

**Example Output** (multi-model network):
```
Active Robots
=============
Mode: Consensus Network (3 robots)

  Tobor
    Model:    gpt-4o (openai)
    Wage:     $0.0050 in / $0.0150 out per 1K tokens
    Tools:    5 (2 local, 3 mcp)
    Role:     architect

  Spark
    Model:    claude-sonnet-4-20250514 (anthropic)
    Wage:     $0.0030 in / $0.0150 out per 1K tokens
    Tools:    5 (2 local, 3 mcp)
    Role:     security

  Weaver
    Model:    gpt-4o (openai)
    Wage:     $0.0050 in / $0.0150 out per 1K tokens
    Tools:    0
    Role:     (default)
```

**Features**:
- Shows mode: Single, Parallel, Consensus, or Pipeline
- Displays robot name, model, provider, cost, tools, and role
- For networks, shows all robots including the Weaver synthesizer

### `/terse`
*Deprecated.* Previously added an instruction for concise responses. Now a no-op.

### `/robot`
Generate ASCII art robot.

**Syntax**: `/robot`

Inserts a fun ASCII robot character for visual breaks in prompts.

## Context Management Directives

### `/checkpoint`
Create a named checkpoint of the current conversation context.

**Syntax**: `/checkpoint [name]`

**Examples**:
```markdown
/checkpoint                    # Auto-named checkpoint (1, 2, 3...)
/checkpoint important_decision # Named checkpoint
/checkpoint before_refactor    # Descriptive name
```

**Features**:
- **Auto-naming**: If no name provided, uses incrementing integers (1, 2, 3...)
- **Named checkpoints**: Use meaningful names for easy identification
- **Deep copying**: Safely stores complete conversation state
- **Chat mode only**: Only available during interactive chat sessions

**Usage**:
- `/checkpoint` - Create an auto-named checkpoint
- `/checkpoint name` - Create a checkpoint with specific name

**Aliases**: `/ckp`, `/cp`

### `/restore`
Restore conversation context to a previously saved checkpoint.

**Syntax**: `/restore [name]`

**Examples**:
```markdown
/restore                      # Restore to last checkpoint
/restore important_decision    # Restore to named checkpoint
/restore 1                    # Restore to auto-named checkpoint
```

**Features**:
- **Default behavior**: Without a name, restores to the most recent checkpoint
- **Named restoration**: Restore to any previously saved checkpoint
- **Context truncation**: Removes all messages added after the checkpoint
- **Client refresh**: Automatically refreshes AI client context

**Usage**:
- `/restore` - Restore to the last checkpoint created
- `/restore name` - Restore to a specific named checkpoint
- Returns error message if checkpoint doesn't exist

### `/clear`
Clear conversation context in chat mode.

**Syntax**: `/clear`

**Usage**: Only available during chat sessions. Clears the conversation history and all checkpoints while keeping the session active.

### `/review`
Display current conversation context with checkpoint markers.

**Syntax**: `/review`

**Aliases**: `/context`

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

### `/checkpoints_list`
List all saved checkpoints with their positions and timestamps.

**Syntax**: `/checkpoints_list`

**Example Output**:
```
=== Available Checkpoints ===
  1: position 4, created 14:32:07
    → "Tell me about Ruby programming"
  before_refactor: position 8, created 14:45:22
    → "Now refactor the User model"
=== End of Checkpoints ===
```

**Features**:
- Shows checkpoint name, conversation position, and creation time
- Includes a preview of the last user message at the checkpoint
- Displays "No checkpoints available." when none exist

**Aliases**: `/checkpoints`

## TrakFlow Directives

TrakFlow is AIA's built-in task tracking system for managing multi-step work.

### `/tasks`
Show TrakFlow ready tasks and project summary.

**Syntax**: `/tasks [summary]`

**Examples**:
```markdown
/tasks              # Show ready tasks
/tasks summary      # Show project summary
```

**Features**:
- Without arguments: lists tasks that are ready to be worked on
- With `summary`: shows the overall project status
- Returns an initialization message if TrakFlow is not set up

**Aliases**: `/tf`

### `/plan`
Create a TrakFlow plan from a description. The description is decomposed into actionable tasks.

**Syntax**: `/plan description`

**Examples**:
```markdown
/plan Build user authentication with login, signup, and password reset
/plan Refactor the payment module into separate service objects
```

### `/task`
Create a single TrakFlow task.

**Syntax**: `/task title`

**Examples**:
```markdown
/task Add input validation to the registration form
/task Write integration tests for the API endpoints
```

## Model and Information Directives

### `/available_models`
List available AI models with filtering.

**Syntax**: `/available_models [filter1,filter2,...]`

**Examples**:
```markdown
/available_models
/available_models openai
/available_models gpt,4
/available_models text_to_image
/available_models claude,sonnet
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

**Aliases**: `/am`, `/available`, `/models`, `/all_models`, `/llms`

### `/compare`
Compare responses from multiple models.

**Syntax**: `/compare prompt --models model1,model2,model3`

**Examples**:
```markdown
/compare "Explain quantum computing" --models gpt-4,claude-3-sonnet,gemini-pro
/compare "Write a Python function to sort a list" --models gpt-3.5-turbo,gpt-4,claude-3-haiku
```

**Features**:
- Side-by-side model comparison
- Error handling for unavailable models
- Formatted output with clear model labels

**Aliases**: `/cmp`

### `/help`
Display available directives and their descriptions.

**Syntax**: `/help`

**Output**: Complete list of all directives with descriptions and aliases.

## Directive Processing Order

Directives are processed in the order they appear in the prompt:

1. **Configuration directives** (like `/config`, `/model`) are processed first
2. **File inclusion directives** (`/include`, `/webpage`) are processed next
3. **ERB directives** (`<%= %>`) are processed
4. **Utility directives** are processed last

## Advanced Usage Patterns

### Combining Directives

```markdown
/config model gpt-4
/config temperature 0.3
/include project_context.md

Based on the project information above:
<%= `git log --oneline -5` %>

Analyze these recent commits and suggest improvements.
```

### Dynamic Configuration

```markdown
<% model_name = ENV['PREFERRED_MODEL'] || 'gpt-3.5-turbo' %>
/config model <%= model_name %>
/config temperature <%= ENV['AI_TEMPERATURE'] || '0.7' %>

Process this data with optimized settings.
```

### Conditional Execution

```markdown
<% if File.exist?('production.yml') %>
/include production.yml
<% else %>
/include development.yml
<% end %>

Configure the system based on environment.
```

### Workflow Automation

```markdown
/pipeline data_extraction,data_cleaning,analysis,reporting
/config model claude-3-sonnet
/config temperature 0.2

Begin automated data processing workflow.
```

## Error Handling

### Common Errors

**File Not Found**:
```
Error: File 'missing.md' is not accessible
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

### Custom Directives

You can extend AIA with custom directives by subclassing `AIA::Directive`:

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

**Usage:** Load custom directives with the `--tools` option:

```bash
# Load custom directive
aia --tools examples/directives/timestamp_directive.rb --chat

# Use in chat mode
/timestamp
/timestamp %Y-%m-%d
```

See `examples/directives/` for more examples.

### Best Practices

1. **Test directives individually** before combining them
2. **Use absolute paths** for file includes when possible
3. **Handle errors gracefully** with conditional Ruby code
4. **Validate environment variables** before using them
5. **Use appropriate models** for different task types

## Security Considerations

- **ERB shell execution** (`<%= \`...\` %>`) executes with your user permissions
- **ERB Ruby code** (`<%= ... %>`) has full access to the Ruby environment
- **File inclusion** can access any readable file
- **Web access** requires API keys and network access

### Safe Usage Tips

1. **Avoid ERB shell commands** that modify system state in shared prompts
2. **Use environment variables** for sensitive data, not hardcoded values
3. **Validate inputs** in ERB code before execution
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
