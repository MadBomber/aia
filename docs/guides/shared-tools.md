# Shared Tools

The [shared_tools gem](https://github.com/madbomber/shared_tools) provides a curated collection of ready-to-use tools for LLM-assisted workflows. These tools extend AIA's capabilities with file operations, web browsing, database access, system utilities, and more.

## Installation

The `shared_tools` gem is installed separately:

```bash
gem install shared_tools
```

## Usage

Load shared tools into AIA with the `--require` option:

```bash
# Load all shared tools
aia --require shared_tools --chat

# Load via the ruby_llm entry point (equivalent)
aia --require shared_tools/ruby_llm --chat

# Load a specific tool only
aia --require shared_tools/ruby_llm/edit_file --chat

# Combine with your own custom tools
aia --require shared_tools --tools ~/my-tools/ --chat

# Use in batch prompts (not just chat)
aia --require shared_tools my_prompt input.txt

# List what tools are available
aia --require shared_tools --list-tools
```

You can also load shared tools from within a prompt using a Ruby directive:

```ruby
/ruby
require 'shared_tools/ruby_llm'
```

Or using an ERB block:

```erb
<%= require 'shared_tools/ruby_llm'; '' %>
```

## Available Tools

> **Tip:** Run `aia --require shared_tools --list-tools` to see the current list from your installed version. Redirect to a file for full markdown descriptions: `aia --require shared_tools --list-tools > tools.md`

### Data & Analysis

#### `calculator`

Perform advanced mathematical calculations with comprehensive error handling and validation.
This tool supports basic arithmetic operations, parentheses, and common mathematical functions.
It uses Dentaku for safe evaluation of mathematical expressions without executing arbitrary code,
making it suitable for use in AI-assisted calculations where security is critical.
The tool returns formatted results with configurable precision and helpful error messages
when invalid expressions are provided.

Supported operations:
- Basic arithmetic: +, -, *, /, %
- Parentheses for grouping: ( )
- Exponentiation: ^ or pow(base, exponent)
- Comparison operators: =, <, >, <=, >=, !=
- Logical operators: and, or, not
- Mathematical functions: sqrt, round, roundup, rounddown, abs
- Trigonometric functions: sin, cos, tan

#### `composite_analysis`

Perform comprehensive multi-stage data analysis by orchestrating multiple specialized analysis steps
to provide complete insights from various data sources. This composite tool automatically
determines the appropriate data fetching method (web scraping for URLs, file reading for
local paths), analyzes data structure and content, generates statistical insights,
and suggests appropriate visualizations based on the data characteristics.
Ideal for exploratory data analysis workflows where you need a complete picture
from initial data loading through final insights. Handles CSV, JSON, and text data formats.

### Database

#### `database_tool`

Executes SQL commands (INSERT / UPDATE / SELECT / etc) on a database. Supports full read-write operations for data manipulation and schema management.

#### `database_query`

Execute safe, read-only database queries with automatic connection management and security controls.
This tool is designed for secure data retrieval operations only, restricting access to SELECT statements
to prevent any data modification. It includes automatic connection pooling, query result limiting,
query timeout support, and comprehensive error handling. The tool supports multiple database configurations
through environment variables and ensures all connections are properly closed after use.

Security features:
- SELECT-only queries (no INSERT, UPDATE, DELETE, DROP, etc.)
- Automatic LIMIT clause enforcement
- Query timeout protection
- Prepared statement support to prevent SQL injection
- Connection pooling with automatic cleanup

Supported databases: PostgreSQL, MySQL, SQLite, SQL Server, Oracle, and any database supported by Sequel.

### File & System Operations

#### `disk_tool`

A tool for interacting with a system. It is able to list, create, delete, move and modify directories and files.

#### `clipboard`

Read from or write to the system clipboard.

This tool provides cross-platform clipboard access:
- macOS: Uses pbcopy/pbpaste
- Linux: Uses xclip or xsel (must be installed)
- Windows: Uses clip/powershell

Actions: `read`, `write`, `clear`.

#### `system_info`

Retrieve system information including operating system, CPU, memory, and disk details.

This tool provides cross-platform system information:
- macOS: Uses system_profiler, sysctl, and df commands
- Linux: Uses /proc filesystem and df command
- Windows: Uses wmic and powershell commands

Categories: `all`, `os`, `cpu`, `memory`, `disk`, `network`.

#### `computer_tool`

A tool for interacting with a computer.

### Web & Network

#### `browser_tool`

Automates a web browser to perform various actions like visiting web pages, clicking elements, inspecting page content, and taking screenshots.

Actions:
1. `visit` - Navigate to a website
2. `page_inspect` - Get page HTML or summary
3. `ui_inspect` - Find elements by text content
4. `selector_inspect` - Find elements by CSS selector
5. `click` - Click an element by CSS selector
6. `text_field_set` - Enter text in input fields/text areas
7. `screenshot` - Take a screenshot of the page or specific element

#### `dns`

Perform DNS lookups and reverse DNS queries.

Uses Ruby's built-in Resolv library for cross-platform DNS resolution.

Actions:
- `lookup` - Resolve a hostname to IP addresses
- `reverse` - Perform reverse DNS lookup (IP to hostname)
- `mx` - Get MX (mail exchange) records for a domain
- `txt` - Get TXT records for a domain
- `ns` - Get NS (nameserver) records for a domain
- `all` - Get all available DNS records for a domain

Record types for lookup: `A` (IPv4), `AAAA` (IPv6), `CNAME`, `ANY`.

### Code Execution

#### `eval_tool`

Execute code in various programming languages (Ruby, Python, Shell).

**WARNING**: This tool executes arbitrary code. All code execution requires user authorization for security.

Actions:
- `ruby` - Execute Ruby code
- `python` - Execute Python code (requires python3 in system PATH)
- `shell` - Execute shell commands

### Documents

#### `doc_tool`

Read and process various document formats.

Actions:
- `pdf_read` - Read specific pages from a PDF document

The `page_numbers` parameter accepts single pages (`"5"`), multiple pages (`"1, 3, 5"`), and range notation (`"1-10"` or `"1, 3-5, 10"`).

### Scheduling & Time

#### `current_date_time`

Returns the current date, time, and timezone information from the system.
This tool provides accurate temporal context for AI assistants that need
to reason about time-sensitive information or schedule-related queries.

Returns: date (ISO 8601), time (24-hour), timezone name and UTC offset, Unix timestamp, day of week, and week number.

#### `cron`

Parse, validate, and explain cron expressions.

Supports standard 5-field cron format (minute, hour, day of month, month, day of week) with special characters: `*`, `,`, `-`, `/`.

Actions:
- `parse` - Parse and explain a cron expression
- `validate` - Check if a cron expression is valid
- `next` - Calculate the next N execution times
- `generate` - Generate a cron expression from a description

### Workflow & Weather

#### `workflow_manager`

Manage complex multi-step workflows with persistent state tracking across tool invocations.
This tool enables the creation and management of stateful workflows that can span multiple
AI interactions and tool calls. It provides workflow initialization, step-by-step execution,
status monitoring, and completion tracking. Each workflow maintains its state in persistent
storage, allowing for resumption of long-running processes and coordination between
multiple tools and AI interactions.

Workflow lifecycle:
1. **Start** - Initialize a new workflow with initial data (returns workflow_id)
2. **Step** - Execute multiple workflow steps using the workflow_id
3. **Status** - Check workflow progress and state at any time
4. **Complete** - Finalize the workflow and clean up resources

#### `weather_tool`

Retrieve comprehensive current weather information for any city worldwide using the OpenWeatherMap API.
This tool provides real-time weather data including temperature, atmospheric conditions, humidity,
and wind information. Requires the `OPENWEATHER_API_KEY` environment variable.

### Development & Reference

#### `error_handling_tool`

Reference tool demonstrating comprehensive error handling patterns and resilience strategies
for robust tool development. This tool showcases best practices for handling different
types of errors including validation errors, network failures, authorization issues,
and general exceptions. It implements retry mechanisms with exponential backoff,
proper resource cleanup, detailed error categorization, and user-friendly error messages.

## Related Documentation

- [Tools Guide](tools.md) - Custom tool development and configuration
- [Chat Mode](chat.md) - Using tools in interactive mode
- [MCP Integration](../mcp-integration.md) - Model Context Protocol tools
- [CLI Reference](../cli-reference.md) - `--require`, `--tools`, `--list-tools` options
