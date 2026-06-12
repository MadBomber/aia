# Advanced Multi-Robot Capabilities Without Examples

AIA v2 includes several advanced multi-robot execution modes that have no demo
scripts yet. These are currently accessible only through chat-time directives
(`/verify`, `/debate`, etc.) inside a `--chat` session, but the underlying
handlers are self-contained and could equally be exposed via CLI flags, YAML
front matter, or `//` prompt-file directives in batch mode.

## Already Covered

`11_multi_model.sh` covers:
- Multi-model comparison mode (`-m modelA,modelB`)
- `--consensus` cooperative synthesis

## Missing Demos

| Feature | Handler | Min models | Current entry point |
|---|---|---|---|
| `/verify` self-review | `VerificationNetwork` | 1 | `/verify` in chat |
| `/decompose` parallel tasks | `PromptDecomposer` | 1 | `/decompose` in chat |
| `/spawn` specialist robots | `SpawnHandler` | 1 | `/spawn [type]` in chat |
| `/debate` multi-round | `DebateHandler` | 2 | `/debate` in chat |
| `@mention` routing | `MentionRouter` | 2 | `@robot_name question` in chat |
| Natural language model switch | `ModelSwitchHandler` | 1 | "switch to X" in chat |
| `/delegate` TrakFlow teams | `DelegateHandler` | 2 | `/delegate` in chat |

## Feature Details

### `/verify` Self-Review (`lib/aia/verification_network.rb`)
- Two robots independently answer the same question with slightly different system
  prompts to encourage independence, then a third "reconciler" robot compares both
  answers, identifies agreements and disagreements, and produces a final verified
  answer.
- All three robots use the same model (`config.models.first`) — no second model needed.
- Batch-capable: the handler takes a prompt string and returns a response with no
  interactive steps. Could be exposed as `--verify` CLI flag or `mode: verify`
  front matter.

### `/decompose` Parallel Tasks (`lib/aia/prompt_decomposer.rb`)
- A coordinator robot analyzes whether a complex prompt can be split into 2-5
  independent sub-tasks. If decomposable, specialist robots solve each in parallel
  and results are synthesized into a unified answer. Falls back to normal mode if
  the prompt is not decomposable.
- Single model is sufficient.
- Batch-capable: no interactivity required. Could be `--decompose` or `mode: decompose`.

### `/spawn` Specialist Robots (`lib/aia/spawn_handler.rb`)
- Dynamically creates a specialist robot on demand. The user can name a type
  (`/spawn security-expert`) or omit it and let the primary robot auto-detect the
  needed expertise. Spawned specialists are cached for reuse within the session.
  Optionally creates TrakFlow tasks when TrakFlow is available.
- Single model is sufficient.
- Batch-capable: specialist type could be specified via CLI flag or front matter.

### `/debate` Multi-Round (`lib/aia/debate_handler.rb`)
- Two or more robots debate a topic across rounds. Each round, every robot responds
  to the previous arguments. Stops when any robot says "CONVERGED" or after 5
  rounds. Displays formatted round-by-round output.
- Requires a 2-model network (`-m modelA,modelB`).
- Batch-capable: debate runs to completion without user input — could be `--debate`.

### `@mention` Routing (`lib/aia/mention_router.rb`)
- Directs a message to one specific robot in a multi-model network by name.
  Syntax: `@robot_name your question`. If the robot name is unknown, available
  robots are listed. Shows token metrics with `--tokens`.
- Requires a 2-model network.
- Genuinely interactive: the value is in the user directing conversation flow
  turn-by-turn; less meaningful as a one-shot batch operation.

### Natural Language Model Switch (`lib/aia/model_switch_handler.rb`)
- Detects model-change intent from natural language input, e.g. "switch to llama"
  or "use phi4-mini instead". Shows "Interpreted as: /model X" and prompts for
  confirmation (y/n). On confirmation, rebuilds the robot with the new model and
  transfers history. Also handles `model_compare` and `model_switch_capability` intents.
- Genuinely interactive: depends on the user directing the conversation.

### `/delegate` TrakFlow Teams (`lib/aia/delegate_handler.rb`)
- A lead robot breaks the prompt into subtasks and assigns each to team members via
  a TrakFlow plan. Each robot executes its subtask in order with full shared context.
  Shows the plan before execution, then step-by-step results.
- Requires a 2-model network and the TrakFlow gem.
- **Blocked**: `trak_flow` gem currently has a LoadError in this environment.
  Defer until the TrakFlow dependency is resolved.

## Batch Mode Extension Opportunities

`/verify`, `/decompose`, `/debate`, and `/spawn` are ready to be lifted out of
chat-only access. `@mention` routing and natural language model switching are
genuinely conversational and are better left as chat-only features.

| Feature | Suggested CLI flag | Suggested front matter key |
|---|---|---|
| `/verify` | `--verify` | `mode: verify` |
| `/decompose` | `--decompose` | `mode: decompose` |
| `/debate` | `--debate` | `mode: debate` |
| `/spawn` | `--spawn TYPE` | `mode: spawn` / `spawn_type: TYPE` |

## Demo Implementation Notes

- Chat-mode demos would use `expect` scripting like `22_chat_mode.sh`.
- Single-model demos can reuse `ollama/qwen3` from the setup script.
- Multi-model demos need a second model — `ollama/phi4-mini` (already used in
  `11_multi_model.sh`) is the natural choice.
- Suggested numbering: `23_verify.sh`, `24_decompose.sh`, `25_spawn.sh`,
  `26_debate.sh`, `27_mention_routing.sh`, `28_model_switching.sh`
- Skip `29_delegate.sh` until the TrakFlow LoadError is resolved.
