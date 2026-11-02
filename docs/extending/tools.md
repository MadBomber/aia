# Tools

Tools let the model *do* things while it answers: read the clock, look up DNS records, count words, query a database. You load them when you start AIA, and the model decides when to call them.

AIA can use any tool written for [RubyLLM](https://rubyllm.com/guides/tools), meaning a Ruby class that subclasses `RubyLLM::Tool`. You can load tools from a gem, from your own `.rb` files, or from MCP servers (see [MCP Servers](mcp.md)).

## Loading tools from a gem

Use `--require` (short form `--rq`) to load a gem at startup. AIA finds every tool the gem defines and gives them to the model.

The [shared_tools](https://github.com/madbomber/shared_tools) gem has a ready-made collection:

```bash
gem install shared_tools

aia --rq shared_tools --chat
```

Some of the tools it provides:

| Tool name | What it does |
|-----------|--------------|
| `current_date_time_tool` | Current date, time and time zone |
| `system_info_tool` | OS, CPU, memory and disk details |
| `dns_tool` | DNS lookups |
| `cron_tool` | Parse and explain cron expressions |
| `calculator` | Arithmetic |
| `weather_tool` | Weather lookups |
| `disk_tool` | File and directory operations |
| `clipboard_tool` | Read or write the system clipboard |
| `doc_tool`, `database_tool`, `browser_tool`, `computer_tool`, ... | More specialised tools |

To load several gems, separate them with commas (`--rq shared_tools,my_tools`) or repeat the option. To load gems every time, put them in your config file:

```yaml
# ~/.config/aia/aia.yml
require_libs:
  - shared_tools
```

!!! warning "Some tools act on your machine"
    Tools such as `disk_tool`, `computer_tool` and `eval_tool` can change files or run code. Load only the tools you trust, and use `--allowed-tools` to keep the list short. See [Security](../configuration/security.md).

## Loading your own tool files

Use `--tools` to load `.rb` files directly. You can pass a single file, a directory (AIA loads every `*.rb` file in it), or a comma-separated list of either:

```bash
aia --tools ~/my_tools/word_count_tool.rb my_prompt
aia --tools ~/my_tools --chat
aia --tools ~/my_tools,./project_tools --chat
```

AIA exits with an error if a path doesn't exist, or if you name a file that doesn't end in `.rb`.

To load the same files every time, list them in your config file:

```yaml
tools:
  paths:
    - ~/my_tools/word_count_tool.rb
```

### Writing a simple tool

A tool is a small Ruby class. Give it a name, a description the model can read, its parameters, and an `execute` method that returns a result:

```ruby
# ~/my_tools/word_count_tool.rb
require 'ruby_llm/tool'

class WordCountTool < RubyLLM::Tool
  def self.name = 'word_count'

  description <<~DESC
    Count words, characters, lines, and sentences in a given text.
    Useful for text analysis and content length checks.
  DESC

  parameter :text, type: :string, description: 'The text to analyze', required: true

  def execute(text:)
    words     = text.split(/\s+/).reject(&:empty?)
    sentences = text.split(/[.!?]+/).reject { |s| s.strip.empty? }

    { words: words.size, characters: text.length,
      lines: text.lines.size, sentences: sentences.size }
  end
end
```

Then ask for it in a prompt:

```bash
aia --tools ~/my_tools/word_count_tool.rb --chat
```

```text
> Use the word_count tool on this: "Ruby is a dynamic, open source programming language."
```

Some tips:

- **Write the description for the model.** The model chooses tools by their descriptions, and AIA's automatic tool filter (below) matches your prompt against them too. Say plainly what the tool does and when to use it.
- **Return data, not prose.** A Hash or String is fine; the model turns it into an answer.
- **Raise or return an error message when something goes wrong.** The model sees the error and can explain it or try again.
- A tool can define an `available?` method. If it returns `false`, AIA skips the tool at startup and prints `Info: Tool '<name>' is not available, skipping`.

See the [RubyLLM tools guide](https://rubyllm.com/guides/tools) for parameter types and other details.

## Seeing which tools are loaded

From the command line, `--list-tools` prints your local tools and exits:

```bash
aia --tools ~/my_tools --list-tools
```

Add `--mcp-list` to include the tools offered by your MCP servers, grouped by server:

```bash
aia --list-tools --mcp-list
```

On a terminal the list is plain text. When you pipe it or redirect it to a file, it's Markdown:

```bash
aia --list-tools --mcp-list > tools.md
```

!!! note
    `--list-tools` may not list tools from gems that load their tools lazily, such as `shared_tools`. To see everything that's really loaded, start a chat and use `/tools`.

Inside a chat, `/tools` lists every loaded tool, local and MCP. Give it a word to filter by name or description:

```text
> /tools
> /tools dns
```

Your AIA crew-management tools (`RecruitRobotTool` and `ReskillRobotTool`) always show up in these lists. They let the model add crewmates on its own; see [Crews](crews.md#letting-the-chief-recruit).

## Limiting which tools the model sees

Large tool collections can confuse a model, and some models stop calling tools at all when they get dozens of them. Narrow the set down:

```bash
# Only these tools
aia --rq shared_tools \
    --allowed-tools current_date_time_tool,system_info_tool,dns_tool \
    my_prompt

# Everything except these
aia --rq shared_tools --rejected-tools computer_tool,eval_tool --chat
```

The short forms are `--at` and `--rt`. A few details:

- Matching is a **case-insensitive substring** match on the tool name, so `--allowed-tools date` keeps `current_date_time_tool`.
- Both options take comma-separated lists and can be repeated.
- If you use both, `--allowed-tools` is applied first and `--rejected-tools` then removes from what's left.

The config file equivalents are `tools.allowed` and `tools.rejected`.

## Automatic tool filtering in chat

In a chat session AIA picks the tools that fit each turn. It compares your message with every tool's name, description and parameter names (local and MCP tools alike) and sends the model only the tools that score high enough, up to 30 per turn. This is on by default.

- When **no** tool matches a turn, the model gets **no** tools for that turn. If the model ignores a tool you expected it to use, name the tool or describe what it does in your message.
- To see which tools were chosen for each turn, run with `--verbose` or `--debug`:

  ```text
  Filtered tools (2): current_date_time_tool, dns_tool
  ```

- Turn it off to always send every allowed tool:

  ```bash
  aia --no-auto-tool-filter --chat
  ```

  The config file key is `flags.auto_tool_filter: false`.

`--load` and `--save` are accepted for saving tool-filter databases, but the current filter rebuilds its index at startup and doesn't use them.

## Tools that need your approval

Some tool calls must be approved before they run. That happens when an MCP server is configured with `requires_approval` (see [MCP Servers](mcp.md#requiring-approval)), or when a tool declares that it needs approval. MCP servers can also ask you for input mid-task.

`--tool-approval` decides what happens:

| Mode | Behaviour |
|------|-----------|
| `ask` (default) | AIA stops and asks on the terminal. With no terminal (for example in a script or pipe), the call is refused. |
| `approve` | Every call that needs approval runs without asking. MCP input requests are still asked on the terminal. |
| `deny` | Every call that needs approval is refused, and every MCP input request is declined. |

In `ask` mode a prompt looks like this:

```text
Tool 'delete_file' requires approval.
  arguments: path="notes/old.md"
  Allow it? [y/N]
```

Only `y` or `yes` approves the call. Questions go to stderr, so they don't mix with the model's answer.

When AIA refuses a call because nobody can answer, it says so:

```text
[AIA] Refused: tool 'delete_file' requires approval and there is no terminal to ask. Set tools.approval (--tool-approval) to approve or deny.
```

Set the default in your config file with `tools.approval: ask|approve|deny`, or with the `AIA_TOOLS__APPROVAL` environment variable.

## See also

- [MCP Servers](mcp.md): tools served by external processes
- [Crews](crews.md): give recruited robots the same tools
- [Security](../configuration/security.md): running tools safely
- [CLI reference](../reference/cli.md) and [Configuration keys](../reference/config-keys.md)
