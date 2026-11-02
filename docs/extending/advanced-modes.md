# Advanced Modes

In a chat, a few directives change how AIA handles your **next** message: double-checking an answer, splitting a big question into parts, letting robots debate, handing work to specialists, or running a full multi-robot build. This page covers each of them, plus AIA's task tracking with TrakFlow.

## How the modes work

Type the directive on its own line, then send your message:

```text
> /verify
Verification mode enabled for next prompt.
> Is it safe to call fork() in a multithreaded program?
```

- Each mode applies to **one** message and then switches off.
- Only one mode can be set at a time. A second mode directive replaces the first.
- These modes work only in chat sessions (`--chat`).
- If a mode can't run, AIA handles the message normally. Some modes say so first; others, such as `/debate` with fewer than two robots or `/concurrent` with fewer than two server groups, just answer normally. If a mode fails part-way, AIA prints `... failed: <reason>. Falling back to normal mode.`

| Directive | Alias | What happens to the next message |
|-----------|-------|-------------------------------|
| `/verify` | | Two independent answers, then a reconciled one |
| `/decompose` | | Split into sub-tasks that run at the same time, then combined |
| `/debate` | | The crew argues over several rounds until they agree |
| `/spawn [...]` | | A specialist robot answers it |
| `/delegate` | `/del` | The chief plans steps, assigns them to crewmates, and they work through them in order |
| `/concurrent` | `/conc` | Your MCP servers are split across robots that work at the same time (see [MCP Servers](mcp.md#running-servers-concurrently)) |
| `/orchestrate` | `/orch` | A three-level build from a requirements document |

## `/verify`: get a second opinion

Two robots on your current model answer the question independently. A third robot, the reconciler, compares the answers, notes where they agree and disagree, and writes a final answer that flags anything uncertain.

```text
> /verify
> What's the time complexity of Python's list.sort() on nearly-sorted data?
Running verification (2 independent + reconciliation)...
```

Use it for factual or technical questions where a confident but wrong answer would be costly. It makes three requests instead of one.

## `/decompose`: split a big question

The chief breaks your message into two to five independent sub-tasks. AIA runs them all at the same time and then combines the results into one answer.

```text
> /decompose
> Compare PostgreSQL, MySQL and SQLite for a small SaaS app: licensing, replication, and operational cost.
Decomposing prompt into sub-tasks...
Decomposed into 3 sub-tasks:
  1. Compare licensing of PostgreSQL, MySQL and SQLite ...
  2. Compare replication options ...
  3. Compare operational cost ...
Synthesizing results...
```

AIA then prints how long each part took and how much time running them in parallel saved:

```text
Benchmark:
  Decompose probe : 1.42s
  Sub-task 1      : 4.10s
  Sub-task 2      : 5.02s
  Sub-task 3      : 3.87s
  Synthesis       : 3.31s
  ─────────────────────────────────────────
  Sub-tasks serial est. : 13.00s  (sum of sub-task times)
  Sub-tasks concurrent  : 5.05s  (2.6x parallel speedup)
  Total flow wall time  : 9.80s  (compare against --tokens Time for a normal run)
```

With `--tokens`, AIA also shows the combined token use of all the parts. If the question can't usefully be split, AIA says `Prompt cannot be meaningfully decomposed. Running normally.` and answers it as usual. Sub-tasks can use your tools and MCP servers.

## `/debate`: let the crew argue

Every crew member answers. Then, round after round, each one reads the others' previous answers and responds. The debate ends when every robot says it agrees (by including the word `CONVERGED`), when a round's answers are very similar to the last round's, or after five rounds. There are always at least two rounds.

```bash
aia --chat -m gpt-4o-mini,claude-haiku-4-5
```

```text
> /debate
> Should a small team adopt microservices from day one?
Debate between Tobor, Zen...
  Round 1: Tobor...
  Round 1: Zen...
  ...
  Converged in round 3.
```

You get every round, labelled by robot:

```text
### Round 1
**Tobor**: ...
**Zen**: ...
### Round 2
...
```

You need at least two robots: several `-m` models, or crewmates you added with `/add_recruit`. If a robot fails in a round, its entry shows `[FAILED]` and the others carry on.

## `/spawn`: call in a specialist

`/spawn` creates a specialist robot to answer your next message. It doesn't join the crew; see [Crews](crews.md#recruits-versus-spawned-specialists).

```text
/spawn                                   # let the chief decide what kind of specialist
/spawn <type>                            # e.g. /spawn security_expert
/spawn <name> <provider/model> [skill:<id>...] <system prompt...>
```

```text
> /spawn
Spawn mode enabled (auto-detect) for next prompt.
> What are the tax implications of an 83(b) election?
Determining specialist type...
Specialist 'tax_attorney' responding...
```

- With no argument, the chief picks a specialist role and writes its instructions.
- With a type, the specialist is told it's a `<type>` specialist.
- The full form chooses the name, the model and the instructions. Use `-` or `inherit` as the model to keep the chief's model. The model can be on a different provider from the chief, for example a hosted expert in a local-model chat. `skill:<id>` adds a skill's text to the specialist's instructions, as it does for recruits.

AIA keeps up to five specialists per session and reuses one when you ask for the same role again. Specialists get the chief's tools and MCP servers, under the same tool-approval setting.

## `/delegate`: plan and hand off

The chief splits your request into steps and assigns each step to a crew member, choosing by their models. The members then work through the steps **in order**, and each step can see the results of the earlier ones.

```text
> /add_recruit writer
> /add_recruit editor anthropic/claude-sonnet-4-5 You are a strict copy editor.
> /delegate
> Write a 300-word announcement for our 2.0 release, then tighten it.
Tobor analyzing and delegating...
Plan with 2 tasks:
  1. Draft the announcement -> writer
  2. Edit for clarity and length -> editor
  writer: Draft the announcement...
  editor: Edit for clarity and length...
```

The result lists every step with its assignee:

```text
### Step 1: Draft the announcement (writer)
...
### Step 2: Edit for clarity and length (editor)
...
```

The plan is recorded as a short-lived plan in [TrakFlow](#task-tracking-with-trakflow). If the chief names a member that doesn't exist, the step goes to the chief.

## `/orchestrate`: a three-level build

`/orchestrate` is for large jobs such as building a small application from a requirements document. Your next message is treated as the **requirements**.

1. **Tobor**, the chief, splits the requirements into three to five architectural layers, such as infrastructure, data models, routes and views.
2. A **lead robot for each layer** breaks its layer into up to four concrete tasks and names a specialist for each. All the leads work at the same time.
3. A **specialist for each task** writes the actual file: code, a migration, a spec. All the specialists work at the same time.
4. Each lead summarizes its layer, and Tobor writes a final integration report.

```text
> /orchestrate
Orchestration mode enabled. Your next prompt is the application requirements.
> TaskFlow: a multi-user project and task manager. Ruby, Sinatra, Sequel (SQLite), ERB views. Users can sign up, create projects, ...
```

Type or paste the whole requirements document as that one message.

Everything is written to a new directory in the current folder, `orchestrated_build_YYYYMMDD_HHMMSS/`, including `INTEGRATION_REPORT.md`:

```text
Integration report: /Users/me/work/orchestrated_build_20261101_142233/INTEGRATION_REPORT.md
Build complete: /Users/me/work/orchestrated_build_20261101_142233
```

!!! warning
    This mode sends many requests, most of them at the same time. Use a capable model, keep an eye on `--cost`, and review the generated files before you use them.

A system prompt that tells the chief when to use `/spawn`, `/decompose` and `/delegate` works well together with this mode. Set one with `--system-prompt` or `prompts.system_prompt` in your config file.

## Task tracking with TrakFlow

AIA uses [TrakFlow](https://github.com/madbomber/trak_flow), a small local task tracker, to record plans and tasks. A TrakFlow project is marked by a `.trak_flow` directory. AIA starts TrakFlow only when a feature needs it: a task directive below, `/spawn` or `/delegate` work, `--track-pipeline`, or a model using the task-board tools. Then it looks for a `.trak_flow` directory in the current directory and its parents, and **creates one in the current directory** if it finds none. A session that uses none of these leaves nothing behind. The tasks themselves go in TrakFlow's database, which by default is `~/.config/trak_flow/tf.db`, shared by every project.

### Directives

| Directive | Effect |
|-----------|--------|
| `/tasks` (alias `/tf`) | List ready tasks (tasks with no open blockers) |
| `/tasks summary` | Count tasks by status |
| `/task <title>` | Create a task |
| `/plan <description>` | Create a task from a description |

```text
> /task Write release notes for 2.0
Task created: [tf-a1b2] Write release notes for 2.0
> /tasks
Ready tasks (1):
  - [tf-a1b2] Write release notes for 2.0 (open)
```

`/spawn` and `/delegate` also record their work there. TrakFlow's own `tf` command lets you view and manage the same tasks outside AIA.

### Tracking a pipeline

`--track-pipeline` records a [pipeline](../prompts/pipelines.md) run as a TrakFlow plan, with one step per prompt. Each step is marked in progress, completed or blocked (with the error) as AIA works through it. A prompt that appears twice in the pipeline gets two steps, and each run updates its own. Without `--track-pipeline`, a pipeline run doesn't touch TrakFlow:

```bash
aia --track-pipeline research --pipeline outline,draft
```

## See also

- [Crews](crews.md)
- [Multiple Models](multi-model.md)
- [MCP Servers](mcp.md)
- [Directives reference](../reference/directives.md)
