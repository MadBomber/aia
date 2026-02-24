# Special Projects Guide

This guide documents the advanced features implemented from the Special Projects roadmap. Each feature builds on AIA v2's architecture of RobotFactory, RuleRouter, ChatLoop, and the directive system.

## Table of Contents

1. [Multi-KB Rule Engine](#multi-kb-rule-engine)
2. [Dynamic Model Switching](#dynamic-model-switching)
3. [MCP Server Concurrency](#mcp-server-concurrency)
4. [TrakFlow Integration](#trakflow-integration)
5. [Expert Routing](#expert-routing)
6. [Verification Networks](#verification-networks)
7. [Prompt Decomposition](#prompt-decomposition)
8. [Session Tracking and Learning](#session-tracking-and-learning)
9. [Configuration Reference](#configuration-reference)
10. [Writing Custom Rules](#writing-custom-rules)

---

## Multi-KB Rule Engine

AIA uses a Knowledge-Based System (KBS) with five separate knowledge bases, each handling one concern. Rules evaluate locally without any LLM call.

### KB Pipeline

```
User Input
    ↓
KB 1: Classification    → What kind of request is this?
KB 2: Model Selection   → Which model(s) should handle it?
KB 3: MCP/Tool Routing  → Which servers and tools are needed?
KB 4: Quality Gates     → Is this prompt ready to send?
    ↓
LLM executes
    ↓
KB 5: Post-Response     → What happened? What should we learn?
```

### How It Works

The `RuleRouter` evaluates KBs in order. Each KB writes its decisions to a shared `Decisions` struct. Downstream KBs read upstream decisions as facts.

```ruby
# RuleRouter evaluates before each robot.run()
decisions = rule_router.evaluate_turn(config, user_input)

# decisions.classifications  → [{domain: "code", source: "code_request"}]
# decisions.model_decisions  → [{model: "claude-...", reason: "code task"}]
# decisions.mcp_activations  → [{server: "filesystem", reason: "code domain"}]
# decisions.gate_actions     → [{action: "warn", message: "..."}]
```

### Default Classification Rules

| Rule | Triggers On | Domain |
|------|------------|--------|
| `code_request` | refactor, debug, implement, function, class, test, bug, fix | code |
| `data_request` | query, sql, database, table, schema, migration | data |
| `image_request` | draw, image, picture, diagram | image |
| `planning_request` | plan, task, project, roadmap, workflow | planning |
| `image_context_detection` | .png, .jpg, .gif, .webp, .svg context files | image |
| `audio_context_detection` | .mp3, .wav, .ogg, .m4a context files | audio |
| `code_context_detection` | .rb, .py, .js, .ts, .go context files | code |
| `short_factual_query` | Input < 100 chars | general (low complexity) |
| `complex_query` | Input > 500 chars | high complexity |

### Default Quality Gate Rules

| Rule | Condition | Action |
|------|-----------|--------|
| `prompt_too_vague` | Input < 10 chars | warn |
| `large_context_warning` | Context > 100KB | warn |
| `cost_warning` | Session cost > $5 | warn |

---

## Dynamic Model Switching

Switch models mid-chat using natural language instead of the formal `/model` directive.

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
| anthropic | claude-sonnet-4-20250514 |
| openai | gpt-4o |
| google | gemini-2.0-flash |
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

Add `topics` to your MCP server configs for KBS-driven routing:

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

1. Classification KB categorizes the prompt (code, data, image, planning)
2. Model Selection KB picks the best model for that domain
3. MCP Routing KB activates relevant servers
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

The learning KB (KB 5) fires after each response:

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

# Rules engine
rules:
  dir: ~/.config/aia/rules
  enabled: true
  store: memory           # memory | sqlite | hybrid
  db_path: ~/.config/aia/rules.db

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

---

## Writing Custom Rules

Create rules in `~/.config/aia/rules/*.rb` targeting specific KBs.

### File Naming

Files load alphabetically. Use numeric prefixes for ordering:

```
~/.config/aia/rules/
├── 01_my_classifications.rb
├── 02_model_preferences.rb
├── 03_routing_overrides.rb
└── 04_custom_gates.rb
```

### KB Targeting

```ruby
# ~/.config/aia/rules/02_model_preferences.rb

AIA.rules_for(:model_select) do
  rule "always_use_claude_for_ruby" do
    on :classification_decision, domain: "code"
    on :context_file, extension: ".rb"
    perform do |facts|
      decisions.add(:model_decision, model: "claude-sonnet-4-20250514")
    end
  end
end

AIA.rules_for(:gate) do
  rule "friday_cost_guard" do
    on :session_stats, total_cost: greater_than(1.0)
    perform do |facts|
      decisions.add(:gate, action: "warn",
        message: "Cost is over $1. Consider a cheaper model.")
    end
  end
end
```

### Available KBs

| KB Name | Purpose | Upstream Facts Available |
|---------|---------|------------------------|
| `:classify` | Categorize input | `:context_file`, `:turn_input` |
| `:model_select` | Choose model(s) | `:classification_decision`, `:model` |
| `:route` | Activate MCP servers | `:classification_decision`, `:model_decision_upstream`, `:mcp_server` |
| `:gate` | Quality checks | `:context_stats`, `:turn_input`, `:session_stats`, `:model_decision` |
| `:learn` | Post-response | `:response_outcome`, `:session_stats` |

### Fact Types

| Fact Type | Available In | Attributes |
|-----------|-------------|------------|
| `:context_file` | classify | path, extension, exists |
| `:turn_input` | classify, gate | text, length |
| `:context_stats` | gate | total_size, large |
| `:model` | model_select | name, role, provider, context_window, supports_vision, supports_audio, cost_tier |
| `:mcp_server` | route | name, topics, active |
| `:classification_decision` | model_select, route | domain, complexity, type, action, source |
| `:model_decision` | gate | model, reason |
| `:session_stats` | gate, learn | turn_count, total_cost, total_tokens |
| `:response_outcome` | learn | accepted, user_switched_model, model |

### Decision Types

```ruby
decisions.add(:classification, domain: "code", source: "my_rule")
decisions.add(:model_decision, model: "gpt-4o", reason: "vision needed")
decisions.add(:mcp_activate, server: "filesystem", reason: "code domain")
decisions.add(:gate, action: "warn", message: "Cost too high")
decisions.add(:learning, signal: "model_success", model: "gpt-4o")
```
