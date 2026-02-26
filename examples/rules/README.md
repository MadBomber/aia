# AIA User Rules

User rules extend the built-in KBS rule engine with custom classification,
model selection, MCP routing, quality gate, and learning rules.

## Setup

Place `.rb` files in `~/.config/aia/rules/`. AIA loads them alphabetically
at startup. Each file calls `AIA.rules_for(:kb_name)` to register rules
targeting a specific knowledge base.

## Available Knowledge Bases

| KB Name        | Purpose                              | Facts Available                |
|----------------|--------------------------------------|--------------------------------|
| `:classify`    | Categorize prompts by domain/intent  | `:turn_input`, `:context_file` |
| `:model_select`| Choose model based on classification | `:classification_decision`, `:model` |
| `:route`       | Activate MCP servers                 | `:classification_decision`, `:mcp_server` |
| `:gate`        | Pre-send quality checks              | `:turn_input`, `:context_stats`, `:session_stats` |
| `:learn`       | Post-response tracking               | `:response_outcome`, `:session_stats` |

## Examples

See the `.rb` files in this directory for working examples.
