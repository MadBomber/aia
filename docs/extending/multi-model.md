# Multiple Models and Consensus

AIA can send one prompt to several models at once. You can read their answers side by side, or have one model merge them into a single consensus answer. In a chat you can also switch models without losing the conversation.

## Asking several models at once

Give `--model` (`-m`) a comma-separated list:

```bash
aia -m gpt-4o-mini,claude-haiku-4-5 explain_recursion
```

All the models run in parallel. Each answer is labelled with the robot's name, its model and how long it took:

```text
**Tobor [gpt-4o-mini]** (2.1s):
Recursion is when a function calls itself...

**Zen [claude-haiku-4-5]** (1.8s):
A recursive function solves a problem by...
```

The first robot is always named **Tobor**. The others are named after their model family (Spark for gpt-4o-mini, Zen for Claude Haiku, Lyric for Claude Sonnet 4, Prism for Gemini Flash, and so on). If two robots would get the same name, the second gets a number (`Zen2`). These names are the handles you use with `@mentions` in chat; see [Crews](crews.md).

In the config file, list the models under `models`:

```yaml
models:
  - name: gpt-4o-mini
  - name: claude-haiku-4-5
```

Models can include a provider prefix, such as `ollama/llama3.2` or `openai/gpt-4o`. See [Local Models](local-models.md) and [Choosing Models](../everyday/models.md).

## Consensus: one merged answer

Add `--consensus` and the individual answers go to a synthesizer robot named **Weaver**. Weaver combines the best points into one answer:

```bash
aia --consensus -m gpt-4o-mini,claude-haiku-4-5,gemini-2.5-flash explain_recursion
```

Weaver uses the **first** model in your list, so put the model you trust most for writing first. The output shows each model's answer followed by Weaver's merged answer under the `consensus` label.

`--no-consensus` turns it off again (useful when your config file sets `flags.consensus: true`).

## Giving each model a role

A role is a prompt file in your roles directory (`~/.prompts/roles/` by default) that shapes how a model behaves. You can give each model its own role with `MODEL=ROLE`:

```bash
aia -m gpt-4o=architect,claude-sonnet-4-5=security_reviewer review_design design.md
```

AIA stops with an error if a role file doesn't exist. The role is added to that model's system prompt, so the same question gets an architect's answer and a security reviewer's answer.

The same model can appear more than once with different roles:

```bash
aia -m gpt-4o-mini=optimist,gpt-4o-mini=pessimist forecast
```

In YAML:

```yaml
models:
  - name: gpt-4o
    role: architect
  - name: claude-sonnet-4-5
    role: security_reviewer
```

[Roles and Skills](../everyday/roles-and-skills.md) explains how roles are written.


## Multiple models in chat

```bash
aia --chat -m gpt-4o-mini,claude-haiku-4-5
```

Each message you type goes to every model, and their answers show up together, or merged if you used `--consensus`. To talk to just one of them, address it by name:

```text
> @zen what do you think of Tobor's answer?
```

`/robots` lists the models in the session and their names. [Crews](crews.md) covers `@mentions` and adding more members.

For a more structured exchange, use `/debate` (the models answer each other over several rounds) or `/verify` (two independent answers plus a reconciliation). Both are described in [Advanced Modes](advanced-modes.md).

## Switching models during a chat

`/model` with no argument shows the current model or models. Give it model names to switch:

```text
> /model
> /model claude-sonnet-4-5
Switching to claude-sonnet-4-5 (conversation: summarize)...
> /model gpt-4o-mini,claude-haiku-4-5
```

The conversation so far comes with you: the old model writes a summary of the conversation, and the new model starts from that summary. This costs one extra request.

!!! note "`model_switch_history` has no effect in 2.0.0"
    `defaults.yml` and the 2.0.0 changelog describe a `model_switch_history` setting (`summarize`, `replay`, `clean`), but aia 2.0.0 never loads it, so every switch summarizes. For a fresh start, run `/clear` after `/model`.

Tools and MCP servers are turned off while AIA replays or summarizes, so the transfer can't cause side effects.

!!! note
    `/model` expects real model names. The short aliases from older AIA versions (`sonnet`, `fast`, `cheap`, ...) and switching by typing "switch to claude" are no longer supported.

## Costs and timing

Several models means several bills. Add `--tokens` to see token counts and response time after each turn, or `--cost` to see the price as well. See [Output and History](../everyday/output-and-history.md).

## See also

- [Choosing Models](../everyday/models.md)
- [Crews](crews.md)
- [Advanced Modes](advanced-modes.md)
- [Local Models](local-models.md)
