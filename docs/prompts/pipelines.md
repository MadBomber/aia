# Pipelines

A pipeline runs several prompts one after another in a single conversation. Each prompt can build on the answers to the prompts before it, which lets you split a big job into small, focused steps.

## How chaining works

All the prompts in a pipeline go to the same conversation. When the second prompt runs, the model has already seen the first prompt and its own answer to it. A later prompt can therefore say "the names above" or "your previous answer" and the model knows what it means.

For example, here are four small prompts:

```markdown
<!-- brainstorm.md -->
Suggest five names for a Ruby gem that formats log files.
```

```markdown
<!-- evaluate.md -->
Rate each of the names above from 1 to 5 for clarity and memorability.
```

```markdown
<!-- pick_best.md -->
Pick the single best name from your ratings and explain why in one sentence.
```

```markdown
<!-- tagline.md -->
Write a one-line tagline for the gem you picked.
```

Each one is easy to read and easy to improve on its own. Run together, they produce a researched answer.

## Defining a pipeline on the command line

The prompt ID you name on the command line runs first. Add more steps with `--pipeline` or `--next`.

=== "--pipeline (-p)"

    Give a comma-separated list of the prompt IDs to run after the first:

    ```bash
    aia --pipeline evaluate,pick_best,tagline brainstorm
    ```

=== "--next (-n)"

    Add one prompt ID per `--next`. You can repeat it:

    ```bash
    aia brainstorm --next evaluate --next pick_best --next tagline
    ```

Both commands run `brainstorm`, `evaluate`, `pick_best` and `tagline` in that order.

Without a prompt ID, the first prompt in `--pipeline` runs first: `aia -p brainstorm,evaluate,pick_best,tagline` runs the same chain.

Before it starts, AIA checks that every prompt ID given on the command line exists. If any is missing, nothing runs:

```text
Error: Prompt ID 'pick_bset' does not exist at /Users/you/.prompts/pick_bset.md
One or more prompt IDs do not exist.
```

## Defining a pipeline in front matter

If a set of prompts always runs together, record the chain in the prompt files.

**`next:`** names the single prompt to run after this one:

```markdown
---
next: explain_joke
---
Tell me a short, clean joke about computers.
```

**`pipeline:`** lists every prompt to run after this one:

```markdown
---
pipeline: [evaluate, pick_best, tagline]
---
Suggest five names for a Ruby gem that formats log files.
```

Now `aia brainstorm` runs the whole chain.

Keep these points in mind:

- `pipeline:` can be a YAML list or a comma-separated string: `pipeline: evaluate, pick_best, tagline`.
- A file can have `next:` or `pipeline:`, but not both.
- `next:` and `pipeline:` **replace** whatever steps were still waiting to run, including steps from `--pipeline` or `--next`. Use the command line or front matter for a chain, not both.
- Any step can set its own `next:`, so prompts can hand off to each other: `a` says `next: b`, `b` says `next: c`, and so on.
- AIA doesn't check prompt IDs from front matter in advance. A misspelled one stops the pipeline when that step is reached.

## What each step receives

| Input | Which steps get it |
|-------|--------------------|
| The prompt file's own text, after [parameters](parameters.md), [shell and ERB](erb-and-shell.md) are processed | That step |
| Text piped on STDIN | The **first** step only |
| Context files named on the command line | **Every** step |
| `--role` | **Every** step (placed in front) |
| `--skill` | **Every** step (placed after) |

Since context files are added to every step, you can give the same source material to a series of different questions:

```bash
aia --pipeline find_bugs,suggest_tests summarize_code lib/parser.rb
```

AIA asks for each step's parameters when that step starts.

## Output

AIA shows each step's response as soon as it arrives, with a separator line between steps. If an output file is set (the default is `temp.md`), each response is added to it. The file is emptied when the run starts unless you pass `--append`. Use `--no-output` to show the responses in the terminal only. See [Output & History](../everyday/output-and-history.md).

## Continuing in chat

Add `--chat` to keep talking once the pipeline finishes. The chat continues the same conversation, so you can ask about any step:

```bash
aia --chat --pipeline evaluate,pick_best brainstorm
```

## Tracking steps in TrakFlow

If you use TrakFlow for task tracking, `--track-pipeline` records the pipeline as a plan and marks each step as started, completed or failed. See [Advanced Modes](../extending/advanced-modes.md).

## Tips

- **Keep each step to one job.** Short, single-purpose prompts are easier to test and reuse in other pipelines.
- **Refer back explicitly.** Phrases such as "the list above" and "your previous answer" help the model connect the steps.
- **Test steps one at a time.** Run a prompt on its own, or with a context file that holds a sample of the previous step's output, before you add it to a chain.
- **Give parameters defaults** if the pipeline will run unattended, for example from cron.

## See also

- [Prompt Files](prompt-files.md): `next:` and `pipeline:` front matter keys
- [Running Prompts](../everyday/running-prompts.md): everyday command-line use
- [Chat Sessions](../everyday/chat.md): continuing after a pipeline
- [Multi-Model & Consensus](../extending/multi-model.md): sending one prompt to several models
