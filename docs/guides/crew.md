# Crews

Every AIA chat session is a **crew** — a small team of robots that share the
conversation. Even when you start with a single model, that model is the crew's
**chief**, and you can add more members on the fly, address them individually or
together, and have them build on each other's answers.

This guide covers how the crew works, how to address members, and how to grow or
shrink the crew while you chat.

## What a crew is

A crew is a network of robots backing one chat session:

- The **chief** is the lead robot — the first (or only) model you started with.
  It answers plain turns and is the model your `/model`, consensus, and
  history-transfer behavior revolve around.
- **Members** (also called recruits) are additional robots you add during the
  session. Each has a name, a provider/model, and its own system prompt, and is
  reachable by `@name`.

A single-model session is simply a crew of one. Multi-model sessions
(`-m model1,model2,...`) start as a crew with one member per model.

<svg width="640" height="280" viewBox="0 0 640 280" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Crew topology: a chief robot with recruited members addressed by @mention">
  <style>
    .lbl { font: 13px -apple-system, Segoe UI, sans-serif; fill: #e6e6e6; }
    .sub { font: 11px -apple-system, Segoe UI, sans-serif; fill: #9aa4b2; }
    .chief { fill: #1f6feb; }
    .member { fill: #2ea043; }
    .you { fill: #8957e5; }
    .edge { stroke: #6e7681; stroke-width: 1.5; fill: none; }
    .edge-bc { stroke: #d29922; stroke-width: 1.5; stroke-dasharray: 5 4; fill: none; }
  </style>
  <!-- You -->
  <rect class="you" x="20" y="120" rx="8" width="110" height="44"/>
  <text class="lbl" x="75" y="140" text-anchor="middle">You</text>
  <text class="sub" x="75" y="156" text-anchor="middle">the prompt</text>
  <!-- Chief -->
  <rect class="chief" x="250" y="120" rx="8" width="130" height="44"/>
  <text class="lbl" x="315" y="140" text-anchor="middle">chief</text>
  <text class="sub" x="315" y="156" text-anchor="middle">lead robot</text>
  <!-- Members -->
  <rect class="member" x="490" y="30"  rx="8" width="130" height="44"/>
  <text class="lbl" x="555" y="50"  text-anchor="middle">@researcher</text>
  <text class="sub" x="555" y="66"  text-anchor="middle">gpt-4o</text>
  <rect class="member" x="490" y="120" rx="8" width="130" height="44"/>
  <text class="lbl" x="555" y="140" text-anchor="middle">@critic</text>
  <text class="sub" x="555" y="156" text-anchor="middle">claude</text>
  <rect class="member" x="490" y="210" rx="8" width="130" height="44"/>
  <text class="lbl" x="555" y="230" text-anchor="middle">@local</text>
  <text class="sub" x="555" y="246" text-anchor="middle">ollama/qwen</text>
  <!-- edges -->
  <path class="edge" d="M130 142 H250"/>
  <path class="edge" d="M380 142 C 430 142, 440 52, 490 52"/>
  <path class="edge" d="M380 142 H490"/>
  <path class="edge" d="M380 142 C 430 142, 440 232, 490 232"/>
  <text class="sub" x="190" y="135" text-anchor="middle">plain turn</text>
  <text class="sub" x="435" y="120" text-anchor="middle">@name / @crew</text>
</svg>

## Seeing the crew

Use `/robots` to list the active crew, each member's model, and its `@mention`
handle:

```text
/robots
```

By default a robot's name is derived from its model name; recruited robots use
the name you give them.

## Addressing members with @mention

Prefix a name with `@` to direct a prompt at one member instead of the chief:

```text
> @critic Does this API design have any obvious flaws?
```

Only the addressed robot responds; the `@critic` prefix is stripped before the
prompt reaches it. Unknown names are reported (with the list of available
members) rather than silently broadcast.

### Addressing several members at once

You can mention more than one member. **Where** the mentions appear changes how
they run:

- **Leading address → concurrent.** When the prompt is nothing but `@names`
  followed by the message, every addressee runs at the same time, each in its
  own thread, and replies render as they finish:

  ```text
  > @researcher @critic what are the trade-offs of optimistic locking?
  ```

- **Body mention → sequential pipeline.** When a `@name` is woven into the body
  of the message, the mentioned members run one at a time, and each reply is
  injected into the other members' conversations so later members build on what
  earlier ones said:

  ```text
  > draft a plan @researcher then have @critic poke holes in it
  ```

  Here `@researcher` runs first; its answer is shared into `@critic`'s context
  before `@critic` runs, so the critique responds to the actual draft.

### Broadcasting to the whole crew

`@crew` is a reserved handle that broadcasts the message to **every** member,
concurrently:

```text
> @crew in one sentence, what is your specialty?
```

Because `crew` is reserved for broadcast, you cannot name a member `crew`.

> **Local models and concurrency.** A leading-address or `@crew` broadcast runs
> its members **concurrently** — several HTTP requests at once. When every member
> shares one local model server (e.g. all on `ollama/qwen3.6:latest`), those
> requests compete for the same instance: the server processes only
> `OLLAMA_NUM_PARALLEL` at a time and the rest queue, so a big task can blow past
> the per-request timeout and you'll see `Net::ReadTimeout` for several members.
> If you hit this, raise Ollama's parallelism (`OLLAMA_NUM_PARALLEL=4`,
> `OLLAMA_MAX_LOADED_MODELS=1`), give each member a smaller scoped task (see
> [skills](#giving-a-recruit-a-role-with-skills)), or address members one at a
> time (a body mention runs them sequentially) instead of broadcasting.

## Building a crew at runtime

### Recruiting a member

`/add_recruit` (alias `/add`) adds a persistent member to the crew. It stays for
the rest of the session and is reachable by `@name`.

```text
# Inherit the chief's model; give it a default persona
/add_recruit researcher

# Pick an explicit provider/model and write its system prompt
/add_recruit critic anthropic/claude-3-5-sonnet You are a ruthless design critic. Find flaws.

# A local model member
/add_recruit local ollama/qwen3.6:latest You are concise and fast.
```

Syntax:

```text
/add_recruit <name> [provider/model] [system prompt...]
```

- **`<name>`** — required, unique within the crew (and not `crew`).
- **`provider/model`** — optional. Omit it (give only a name) to inherit the
  chief's model and provider. Use `-` or `inherit` as the model token to inherit
  explicitly while still supplying a system prompt. `lms/...` maps to the
  `openai` provider for LM Studio.
- **system prompt** — everything after the model becomes the member's system
  prompt. Without one, the member gets a simple default persona.

Recruits inherit the chief's local tools and any connected MCP servers, so a new
member can do the same file/shell/MCP work the chief can without reopening
connections.

### Giving a recruit a role with skills

A bare crew of identical robots all do the same undifferentiated work. To divide
labor, assign each member a **skill** — a named, reusable system prompt (the same
skills used by `--skill` and `/skill`; list them with `/skills`). A skill becomes
the recruit's role:

```text
# One skill as the recruit's role
/add_recruit reviewer skill:security-review

# Skill + explicit model, then an extra instruction appended after the skill
/add_recruit reviewer ollama/qwen3.6:latest skill:security-review focus on the auth module

# Several skills at once (repeat the token or comma-separate)
/add_recruit reviewer - skill:security-review,ruby-style
```

The `skill:<id>` token may appear anywhere after the name; everything else is
parsed as the model (position 1) and an optional trailing system prompt. The
final role is the skill bodies joined, followed by any explicit prompt. An
unknown skill id is reported rather than silently ignored, so the recruit always
gets the role you intended.

This is how you turn a `@crew` broadcast from four identical answers into a real
division of labor — e.g. a security reviewer, a performance reviewer, a test
reviewer, and a style reviewer, each with its own skill.

### Re-skilling a member

`/reskill` resets a member to a **clean slate** (a fresh conversation) and gives
it a new role. The member keeps its `@name` and model:

```text
# Repurpose larry for the next phase
/reskill larry skill:test-writing

# Or hand it a freeform role
/reskill larry - you now summarize the other members' findings
```

Use it to recover a member that drifted off task, or to move the crew through
phases (review → fix → summarize) without re-creating robots.

### Dropping a member

`/drop_recruit` (alias `/drop`) removes a member by name:

```text
/drop_recruit researcher
```

The chief cannot be dropped — it is the session's lead robot.

## Recruits vs. spawned specialists

`/add_recruit` and `/spawn` look similar but serve different needs:

| | `/add_recruit` (`/add`) | `/spawn` |
|---|---|---|
| Lifetime | Persists for the whole session | One-shot, for the **next** prompt only |
| Joins the crew | Yes — shows in `/robots`, answers to `@name` | No — handles a single subtask, then is set aside |
| Best for | A standing teammate you'll address repeatedly | A throwaway specialist for one focused task |

Both accept the same explicit `name provider/model system prompt` form, so a
specialist you find yourself reaching for repeatedly is a good candidate to
promote from `/spawn` to `/add_recruit`.

See the [Directives Reference](../directives-reference.md) for the full
directive list and the [Working with Models](models.md) guide for multi-model
sessions, consensus mode, and dynamic model switching.
