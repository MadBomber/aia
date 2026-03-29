<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

- [Special Projects Guide](#special-projects-guide)
  - [Table of Contents](#table-of-contents)
  - [Dynamic Model Switching](#dynamic-model-switching)
    - [@mention Routing](#mention-routing)
    - [Supported Phrases](#supported-phrases)
    - [How It Works](#how-it-works-1)
    - [Model Aliases](#model-aliases)
    - [Custom Aliases](#custom-aliases)
    - [Conversation History on Switch](#conversation-history-on-switch)
  - [MCP Server Concurrency](#mcp-server-concurrency)
    - [Configuration](#configuration)
    - [Three Ways to Trigger](#three-ways-to-trigger)
    - [Server Grouping](#server-grouping)
  - [TrakFlow Integration](#trakflow-integration)
    - [Setup](#setup)
    - [Chat Directives](#chat-directives)
    - [Pipeline Tracking](#pipeline-tracking)
    - [Session Continuity](#session-continuity)
  - [Expert Routing](#expert-routing)
    - [Enable](#enable)
    - [How It Works](#how-it-works-2)
    - [Example Flow](#example-flow)
  - [Verification Networks](#verification-networks)
    - [Usage](#usage)
    - [How It Works](#how-it-works-3)
  - [Prompt Decomposition](#prompt-decomposition)
    - [Usage](#usage-1)
    - [How It Works](#how-it-works-4)
  - [Session Tracking and Learning](#session-tracking-and-learning)
    - [What's Tracked](#whats-tracked)
    - [Learning Rules](#learning-rules)
  - [Configuration Reference](#configuration-reference)
    - [New Config Sections](#new-config-sections)
    - [MCP Server Metadata Fields](#mcp-server-metadata-fields)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

# Special Projects Guide

This guide documents the advanced features implemented from the Special Projects roadmap. Each feature builds on AIA v2's architecture of RobotFactory, ChatLoop, and the directive system.

## Table of Contents

1. [Dynamic Model Switching](#dynamic-model-switching)
2. [MCP Server Concurrency](#mcp-server-concurrency)
3. [TrakFlow Integration](#trakflow-integration)
4. [Expert Routing](#expert-routing)
5. [Verification Networks](#verification-networks)
6. [Prompt Decomposition](#prompt-decomposition)
7. [Session Tracking and Learning](#session-tracking-and-learning)
8. [Configuration Reference](#configuration-reference)

---

## Dynamic Model Switching

Switch models mid-chat using natural language instead of the formal `/model` directive.

### @mention Routing
In a multi-model network, route a message to a specific robot by prefixing its registered name with `@`:
```
@tobor Explain your reasoning step by step.
```
Use `/robots` to see the active crew and their `@mention` handles. The mention router scans the input for `@name` tokens, matches them against robot names, and routes the prompt only to the mentioned robots.

### Supported Phrases

- **Switch**: "switch to claude", "use GPT-4o", "try gemini"
- **Compare**: "compare claude and gemini", "hear from both models"
- **Capability**: "use something cheaper", "switch to the best model"

### How It Works

1. The classification KB detects model-change intent
2. `ModelSwitchHandler` extracts model names from the text
3. Names are resolved through `ModelAliasRegistry`
4. User is asked to confirm before switching
5. Robot is rebuilt with the new model(s)

### Model Aliases

Short names, provider names, and capability descriptors all resolve to model IDs:

| Alias | Resolves To |
|-------|------------|
| claude, sonnet | claude-sonnet-4-20250514 |
| opus | claude-opus-4-20250514 |
| haiku, fast | claude-haiku-4-5-20251001 |
| gpt4, gpt4o | gpt-4o |
| cheap, gpt4mini | gpt-4o-mini |
| best | claude-opus-4-20250514 |
| gemini, flash | gemini-2.0-flash |
| llama | llama-3.1-70b |
| anthropic | claude-sonnet-4-20250514 |
| openai | gpt-4o |
| google | gemini-2.0-flash |
| meta | llama-3.1-70b |
| coding | claude-sonnet-4-20250514 |
| vision | gpt-4o |

### Custom Aliases

Add custom aliases in your config:

```yaml
# ~/.config/aia/aia.yml
model_aliases:
  mymodel: my-custom-model-id
  team: our-fine-tuned-model
```

### Conversation History on Switch

Control what happens to conversation history when switching models:

```yaml
model_switch_history: clean      # fresh start (default)
model_switch_history: replay     # replay all messages to new model
model_switch_history: summarize  # summarize and inject context
```

---

## MCP Server Concurrency

When a prompt needs multiple independent MCP servers, AIA can fan out to a robot-per-server and merge results.

### Configuration

Add `topics` to your MCP server configs for domain-driven routing:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path"],
      "topics": ["files", "code", "directory"]
    },
    "database": {
      "command": "python",
      "args": ["-m", "mcp_server_sqlite"],
      "topics": ["data", "sql", "records"]
    }
  }
}
```

### Three Ways to Trigger

1. **Directive**: `/concurrent` before your prompt
2. **Auto-detection**: Set `concurrency.auto: true` in config
3. **Config-driven**: List independent servers in config

```yaml
# ~/.config/aia/aia.yml
concurrency:
  auto: true
  independent_servers: [filesystem, database, web_search]
  threshold: 2   # minimum independent servers to trigger
```

### Server Grouping

Servers can be grouped for sequential access:

```json
{
  "mcpServers": {
    "db_reader": {
      "command": "...",
      "group": "database"
    },
    "db_writer": {
      "command": "...",
      "group": "database"
    }
  }
}
```

Grouped servers run sequentially within their group; different groups run concurrently.

---

## TrakFlow Integration

TrakFlow is a distributed task tracking system for AI agents. AIA connects to it as an MCP server.

### Setup

```bash
# Add TrakFlow MCP to your AIA config
aia --mcp mcp_servers/trak_flow.json --chat
```

### Chat Directives

| Directive | Description |
|-----------|-------------|
| `/tasks` | Show ready tasks |
| `/tasks summary` | Show project summary |
| `/tf` | Alias for `/tasks` |
| `/plan <description>` | Create a TrakFlow plan |
| `/task <title>` | Create a single task |

### Pipeline Tracking

Enable automatic pipeline tracking in TrakFlow:

```yaml
flags:
  track_pipeline: true
```

When enabled, AIA creates a TrakFlow Plan for each pipeline and updates task status as steps complete:

```
Pipeline: summarize → analyze → recommend

TrakFlow Plan:
  Step 1: summarize  → started → completed ✓
  Step 2: analyze    → started → completed ✓
  Step 3: recommend  → started → in_progress...
```

### Session Continuity

When TrakFlow is connected and you start a chat session, AIA checks for open tasks from previous sessions:

```
Open tasks from previous sessions found:
  - Step 4: Review auth module (blocked - needs user input)
  - Task: Update documentation (ready)
```

---

## Expert Routing

Route different prompt types to specialist robots with different models and MCP servers.

### Enable

```yaml
flags:
  expert_routing: true
```

### How It Works

1. The prompt is categorized by domain (code, data, image, planning)
2. The best model for that domain is selected
3. Relevant MCP servers are activated
4. `ExpertRouter` builds a specialist robot with those specifics
5. The specialist handles the prompt instead of the default robot

### Example Flow

```
User: "Refactor the auth module"
  → Classification: domain=code
  → Model Selection: claude-sonnet (code task)
  → MCP Routing: filesystem server activated
  → Expert robot built with claude-sonnet + filesystem MCP
  → Specialist handles the prompt
```

---

## Verification Networks

Use consensus for quality — two robots independently answer, then a third reconciles.

### Usage

```
/verify
How does quantum entanglement work?
```

### How It Works

1. Two verifier robots independently answer the question
2. A reconciler compares both answers
3. The reconciler produces a final, verified answer noting agreements and uncertainties

---

## Prompt Decomposition

For complex prompts, a coordinator breaks them into independent sub-tasks, executes them in parallel, then synthesizes.

### Usage

```
/decompose
Research current AI safety approaches, compare them with historical precedents,
and recommend a framework for our team.
```

### How It Works

1. The robot analyzes the prompt and identifies 2-5 independent sub-tasks
2. Each sub-task runs separately
3. Results are synthesized into a coherent response

If the prompt cannot be meaningfully decomposed, it falls back to normal execution.

---

## Session Tracking and Learning

AIA tracks session metrics for the post-response learning loop.

### What's Tracked

Per turn:
- Model used
- Input length
- Token counts
- Cost estimate
- Routing decisions
- Timestamp

Session-wide:
- Total turns
- Total cost
- Total tokens
- Model switch events
- User feedback signals

### Learning Rules

The post-response learning step fires after each response:

| Rule | Signal | Meaning |
|------|--------|---------|
| `track_model_switch` | model_dissatisfaction | User switched models after a response |
| `track_success` | model_success | User accepted the response |
| `cost_tracking` | cost_update | Running cost total |

These signals are currently informational. Future versions can use them to automatically adjust routing rules.

---

## Configuration Reference

### New Config Sections

```yaml
# ~/.config/aia/aia.yml

# Model aliases (custom overrides)
model_aliases:
  mymodel: my-custom-model-id

# History mode on model switch
model_switch_history: clean  # clean | replay | summarize

# MCP concurrency
concurrency:
  auto: false
  independent_servers: []
  threshold: 2

# New flags
flags:
  track_pipeline: false   # Track pipelines in TrakFlow
  expert_routing: false   # Per-turn expert routing
```

### MCP Server Metadata Fields

```json
{
  "topics": ["code", "files"],
  "independent": true,
  "group": "database"
}
```

