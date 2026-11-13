# Directives Reference

This page lists every directive in AIA 2.0 in alphabetical order, with its aliases, arguments and an example. For an introduction, read [Directives](../prompts/directives.md) first.

## Syntax

| Where | Form | Notes |
|-------|------|-------|
| Chat | `/name arg1 arg2` | Must be on a line by itself. The name is case-insensitive. Arguments are split on spaces, and quotes don't group words. |
| Prompt file | `<%= name 'arg1', 'arg2' %>` | An ERB tag. Its result replaces the tag. A directive with no arguments is just `<%= name %>`. |

**Use in** shows where each directive is meant to be used:

- **Chat**: designed for interactive sessions.
- **Prompt**: returns text, so it is useful inside a prompt file.
- **Both**: useful in either place.

**Chat output** describes what happens to the result in a chat session:

- **Sent**: AIA prints the result and also sends it to the model as part of the conversation.
- **Shown**: AIA prints the result only. Nothing reaches the model.
- **Next prompt**: AIA turns on a mode that applies to your next message only.

## Summary

| Directive | Aliases | Use in | Chat output | Purpose |
|-----------|---------|--------|-------------|---------|
| [`/add_recruit`](#add_recruit) | `/add` | Chat | Shown | Add a persistent robot to the crew |
| [`/available_models`](#available_models) | `/am`, `/available`, `/models`, `/all_models`, `/llms` | Chat | Shown | Search the model list |
| [`/checkpoint`](#checkpoint) | `/ckp`, `/cp` | Chat | Shown | Save a point in the conversation |
| [`/checkpoints_list`](#checkpoints_list) | `/checkpoints` | Chat | Shown | List checkpoints |
| [`/clear`](#clear) | | Chat | Shown | Forget the conversation |
| [`/compare`](#compare) | `/cmp` | Chat | Shown | Ask several models the same thing |
| [`/concurrent`](#concurrent) | `/conc` | Chat | Next prompt | Query MCP server groups in parallel |
| [`/config`](#config) | `/cfg` | Chat | Shown | Show or change settings |
| [`/cost`](#cost) | | Chat | Shown | Token and cost report as CSV |
| [`/debate`](#debate) | | Chat | Next prompt | Multi-round debate between robots |
| [`/decompose`](#decompose) | | Chat | Next prompt | Split a prompt into parallel sub-tasks |
| [`/delegate`](#delegate) | `/del` | Chat | Next prompt | Assign sub-tasks to robots via TrakFlow |
| [`/drop_recruit`](#drop_recruit) | `/drop` | Chat | Shown | Remove a robot from the crew |
| [`/help`](#help) | | Chat | Shown | List all directives |
| [`/include`](#include) | | Both | Sent | Insert another file, processed as a prompt |
| [`/insert`](#insert) | `/read` | Both | Sent | Insert a file's raw text |
| [`/mcp`](#mcp) | | Chat | Shown | MCP server status and tools |
| [`/model`](#model) | | Chat | Shown | Show or switch the model |
| [`/orchestrate`](#orchestrate) | `/orch` | Chat | Next prompt | Three-tier orchestration |
| [`/paste`](#paste) | `/clipboard` | Both | Sent | Insert the clipboard contents |
| [`/plan`](#plan) | | Chat | Sent | Create a TrakFlow plan |
| [`/plugins`](#plugins) | | Chat | Shown | List loaded plugins |
| [`/reskill`](#reskill) | | Chat | Shown | Reset a crew member with new skills |
| [`/restore`](#restore) | | Chat | Shown | Go back to a checkpoint |
| [`/review`](#review) | `/context` | Chat | Shown | Show the conversation |
| [`/robot`](#robot) | | Chat | Shown | ASCII robot art |
| [`/robots`](#robots) | | Chat | Shown | Show the active robot(s) |
| [`/ruby`](#ruby) | `/rb` | Chat | Sent | Run Ruby (needs `--allow-ruby-eval`) |
| [`/say`](#say) | | Chat | Shown | Speak text aloud |
| [`/skill`](#skill) | | Both | Sent | Insert a skill's text |
| [`/skills`](#skills) | | Chat | Shown | List skills |
| [`/spawn`](#spawn) | | Chat | Next prompt | One-off specialist robot |
| [`/task`](#task) | | Chat | Sent | Create a TrakFlow task |
| [`/tasks`](#tasks) | `/tf` | Chat | Sent | Show TrakFlow ready tasks |
| [`/temperature`](#temperature) | `/temp` | Chat | Shown | Set temperature |
| [`/tools`](#tools) | | Chat | Shown | List available tools |
| [`/top_p`](#top_p) | `/topp` | Chat | Shown | Set top-p |
| [`/verify`](#verify) | | Chat | Next prompt | Two answers plus reconciliation |
| [`/webpage`](#webpage) | `/website`, `/web` | Both | Sent | Insert a web page as Markdown |

Front matter keys such as `next:` and `pipeline:` aren't directives. See [Prompt Files](../prompts/prompt-files.md#front-matter-keys). There are no `/next` or `/pipeline` chat directives.

---

## /add_recruit

**Aliases:** `/add` · **Use in:** Chat · **Chat output:** Shown

```text
/add_recruit NAME [PROVIDER/MODEL] [skill:ID[,ID...]] [SYSTEM PROMPT...]
```

Adds a robot named `NAME` to the crew. A recruit stays for the rest of the session, and you can address it with `@NAME`.

- With only a name, the recruit uses the session's model.
- Use `-` or `inherit` in place of a model to keep the session's model while still giving a system prompt.
- Each `skill:ID` token assigns one or more [skills](../everyday/roles-and-skills.md). The skills become the recruit's role.
- Everything after the model is the recruit's system prompt.

```text
/add_recruit critic openai/gpt-4o You are a blunt code reviewer.
/add tester - skill:rspec_writer
```

AIA replies `Recruited 'critic' into the crew (openai/gpt-4o).` If it can't add the recruit, it replies `Recruit failed: ...`. See [Crews](../extending/crews.md).

## /available_models

**Aliases:** `/am`, `/available`, `/models`, `/all_models`, `/llms` · **Use in:** Chat · **Chat output:** Shown

```text
/available_models [TERM ...]
```

Lists models with their provider, input price per million tokens, context window, modalities and capabilities.

- A plain term (or `+term`) keeps the models whose entry contains it.
- `-term`, `~term` or `!term` removes the models whose entry contains it.
- A term with `_to_`, such as `text_to_image`, filters by modality.
- If your current model has a `provider/` prefix, AIA asks that provider for its live model list instead.

```text
/models claude -haiku
/am text_to_image
```

## /checkpoint

**Aliases:** `/ckp`, `/cp` · **Use in:** Chat · **Chat output:** Shown

```text
/checkpoint [NAME]
```

Saves the current conversation under `NAME`. Without a name, checkpoints are numbered `1`, `2`, `3` and so on. Checkpoints last only for the current session.

```text
/checkpoint before_refactor
Checkpoint 'before_refactor' created at position 6.
```

## /checkpoints_list

**Aliases:** `/checkpoints` · **Use in:** Chat · **Chat output:** Shown

Lists the saved checkpoints with their position, the time each was created, and a preview of the last message you sent before it.

```text
/checkpoints

=== Available Checkpoints ===
  before_refactor: position 6, created 14:02:11
    → "Now refactor the parser to use a state machine"
=== End of Checkpoints ===
```

## /clear

**Use in:** Chat · **Chat output:** Shown

```text
/clear [--all]
```

Removes the conversation history from every robot in the session. The system prompt is kept unless you add `--all`. All checkpoints are deleted too.

```text
/clear
Chat context cleared.
```

## /compare

**Aliases:** `/cmp` · **Use in:** Chat · **Chat output:** Shown

```text
/compare PROMPT --models MODEL1,MODEL2[,...]
```

Sends the prompt to each listed model separately and prints each response under the model's name. The models don't see your conversation.

Every word that isn't part of `--models` belongs to the prompt.

```text
/compare Write a haiku about autumn --models gpt-4o-mini,claude-haiku-4-5
```

## /concurrent

**Aliases:** `/conc` · **Use in:** Chat · **Chat output:** Next prompt

Runs your next message with your MCP servers split into independent groups that are queried in parallel. This needs more than one MCP server that is relevant to the prompt, in at least two groups. Otherwise the message runs normally. To do this automatically on every prompt, use `--concurrent-auto`. See [MCP Servers](../extending/mcp.md).

```text
/concurrent
Compare the open GitHub issues with the TODOs in the local repository.
```

## /config

**Aliases:** `/cfg` · **Use in:** Chat · **Chat output:** Shown

```text
/config                  # show every setting
/config SECTION          # show one top-level section, e.g. llm, flags, output
/config KEY VALUE        # change a setting
```

`KEY` can be:

- An option name, such as `temperature`, `max_tokens`, `debug`, `verbose`, `consensus` or `tokens`
- A dotted path, such as `llm.max_tokens` or `output.file`

The change lasts for the rest of the session only. Model settings such as `temperature`, `top_p` and `llm.*` apply from your next message: AIA retunes the running robot, and every crewmate, without losing the conversation. See [Configuration Precedence](../configuration/precedence.md#when-layers-6-and-7-take-effect). AIA warns `Unknown config option 'x'` if it doesn't recognize the key.

```text
/config llm
/config debug true
/config llm.max_tokens 4000
```

!!! note "Value types"
    AIA converts the value to the setting's type: numbers for `temperature` or `llm.max_tokens`, true/false for on/off settings (`true`, `yes`, `on`, `1` / `false`, `no`, `off`, `0`), and comma-separated lists for list settings. A value that doesn't fit is stored as you typed it.

## /cost

**Use in:** Chat · **Chat output:** Shown

Prints a CSV table of the session's turns. It shows the model, input, output and total tokens, the cost and the elapsed time for each turn, followed by a `TOTAL` row. If an output file is set, the CSV is also appended to it.

```text
/cost

model,input_tokens,output_tokens,total_tokens,cost,elapsed
gpt-4o-mini,412,256,668,$0.00022,2.1s
TOTAL,412,256,668,$0.00022,2.1s
```

## /debate

**Use in:** Chat · **Chat output:** Next prompt

Your next message becomes the subject of a debate among the robots in the session. The debate runs at least 2 rounds and at most 5, and stops early when the robots agree. You need at least two robots, from several models (`--model a,b`) or from recruits. With only one robot, the message runs normally. See [Advanced Modes](../extending/advanced-modes.md).

```text
/debate
Should a small team start with a monolith or microservices?
```

## /decompose

**Use in:** Chat · **Chat output:** Next prompt

Splits your next message into independent sub-tasks, runs them in parallel, and combines the results. Timing figures show how long the work took in parallel compared with one after another. If the message can't usefully be split, it runs normally.

```text
/decompose
Summarize the pros and cons of Postgres, MySQL and SQLite for a mobile backend.
```

## /delegate

**Aliases:** `/del` · **Use in:** Chat · **Chat output:** Next prompt

Breaks your next message into sub-tasks, assigns each one to a robot in the crew, records the plan in TrakFlow, and runs it. This needs more than one robot and TrakFlow, which AIA starts on first use, creating the TrakFlow project if there is none. Otherwise the message runs normally.

```text
/delegate
Design the database schema, write the migration, and write tests for it.
```

## /drop_recruit

**Aliases:** `/drop` · **Use in:** Chat · **Chat output:** Shown

```text
/drop_recruit NAME
```

Removes a recruit from the crew.

```text
/drop critic
Dropped 'critic' from the crew.
```

## /help

**Use in:** Chat · **Chat output:** Shown

Lists every directive, including [custom ones](../prompts/directives.md#writing-your-own-directive), grouped by category with their aliases and descriptions.

## /include

**Use in:** Both · **Chat output:** Sent

```text
/include PATH                       # chat
<%= include 'PATH' %>               # prompt file
```

Inserts another file after processing it as a prompt. Its shell references, ERB and parameters are all handled, and it can include other files in turn. In a prompt file, `PATH` is relative to the directory of the file that contains the tag. In chat, it is relative to your current directory. Include loops are detected and stop with an error. `include` isn't available in executable or piped prompts. Use `insert` there.

```markdown
<%= include 'shared/house_style.md' %>
```

## /insert

**Aliases:** `/read` · **Use in:** Both · **Chat output:** Sent

```text
/insert PATH
<%= insert 'PATH' %>
```

Inserts a file's text exactly as it is, with no shell expansion, ERB or parameters. Paths resolve the same way as for `include`, or against the current directory when there is no prompt file.

```markdown
Review this code:

<%= insert 'lib/parser.rb' %>
```

## /mcp

**Use in:** Chat · **Chat output:** Shown

Shows how many MCP servers are defined, connected and failed. It lists each connected server's tools and the error for each failed server.

```text
/mcp

MCP Server Status
=================
Defined: 2  Connected: 1  Failed: 1

Connected Servers:
  github (26 tools)
    - list_issues
    ...
Failed Servers:
  postgres: connection refused
```

## /model

**Use in:** Chat · **Chat output:** Shown

```text
/model                       # show details of the current model(s)
/model MODEL[,MODEL...]      # switch to one or more models
```

With no argument, AIA shows the current model's details. With several models, it shows each one's provider, context window, prices and capabilities.

Switching keeps your conversation: by default the old model summarizes it for the new one. Set `model_switch_history` to `replay` (re-send your messages) or `clean` (start fresh). `MODEL` can also be an alias such as `sonnet` or `cheap`, or one you define under `model_aliases`.

See [Choosing Models](../everyday/models.md).

```text
/model claude-sonnet-4
/model gpt-4o,claude-sonnet-4
```

## /orchestrate

**Aliases:** `/orch` · **Use in:** Chat · **Chat output:** Next prompt

Treats your next message as a set of application requirements. Three tiers of robots work on it: an orchestrator, lead agents and specialists. See [Advanced Modes](../extending/advanced-modes.md).

```text
/orchestrate
Build a command-line tool that tracks reading habits, with a SQLite store and a weekly report.
```

## /paste

**Aliases:** `/clipboard` · **Use in:** Both · **Chat output:** Sent

Inserts the text on your system clipboard.

```text
/paste
```

```markdown
Fix the grammar in this paragraph:

<%= paste %>
```

## /plan

**Use in:** Chat · **Chat output:** Sent

```text
/plan DESCRIPTION
```

Creates a TrakFlow item from the description. AIA starts TrakFlow on first use, creating the TrakFlow project if there is none. If TrakFlow cannot start, AIA prints `TrakFlow not available. Run 'tf init' to initialize a project.`

```text
/plan Migrate the reporting jobs from cron to Solid Queue
```

## /plugins

**Use in:** Chat · **Chat output:** Shown

Lists the [plugins](../prompts/plugins.md) that are currently loaded, by file name without `.rb`.

## /reskill

**Use in:** Chat · **Chat output:** Shown

```text
/reskill NAME [skill:ID[,ID...]] [SYSTEM PROMPT...]
```

Clears a crew member's conversation and gives it new skills, a new system prompt, or both.

```text
/reskill critic skill:security_review
Reskilled 'critic' with security_review (clean slate).
```

## /restore

**Use in:** Chat · **Chat output:** Shown

```text
/restore [NAME]
```

Returns the conversation to a checkpoint. Everything after it is discarded, and so are any checkpoints saved after it. Without a name, AIA restores the checkpoint before the most recent one. That takes at least two checkpoints.

```text
/restore before_refactor
Context restored to checkpoint 'before_refactor' (position 6).
```

## /review

**Aliases:** `/context` · **Use in:** Chat · **Chat output:** Shown

Prints the conversation so far, one numbered line per message, with 📍 markers where checkpoints were saved. Long messages are shortened, and tool calls are summarized.

## /robot

**Use in:** Chat · **Chat output:** Shown

Prints AIA's ASCII robot.

## /robots

**Use in:** Chat · **Chat output:** Shown

Shows the active robot or robots and the mode: Single, Crew, Parallel, Pipeline or Consensus. For each robot it shows the model and provider, the cost per 1K input and output tokens, how many local and MCP tools it has, and its role.

## /ruby

**Aliases:** `/rb` · **Use in:** Chat · **Chat output:** Sent

```text
/ruby RUBY CODE
```

Evaluates one line of Ruby and sends the result to the model. **Disabled by default.** Enable it with `--allow-ruby-eval`, or with `flags: { allow_ruby_eval: true }` in `~/.config/aia/aia.yml`. While it is disabled, the directive only prints an error. While it is enabled, AIA prints a warning to STDERR before it runs the code. If the code raises an error, the error message is sent in place of a result.

```text
/ruby Dir.glob('spec/**/*_spec.rb').size
```

See [ERB & Shell](../prompts/erb-and-shell.md#running-ruby-in-chat-ruby) and [Security](../configuration/security.md).

## /say

**Use in:** Chat · **Chat output:** Shown

```text
/say TEXT
```

Speaks the text with your speak command (`--speak-command` or `audio.speak_command`; the macOS `say` command by default). With `say`, AIA uses your voice (`--voice` or `audio.voice`) if you've set one. Without text, AIA prints `Usage: /say TEXT` and sends nothing to the model. To have every response spoken, use `--speak`. See [Images & Speech](../extending/images-and-speech.md).

```text
/say The build is green
```

## /skill

**Use in:** Both · **Chat output:** Sent

```text
/skill ID
<%= skill 'ID' %>
```

Inserts the `SKILL.md` text of a skill from your skills directory (default `~/.prompts/skills`). `ID` can be the start of a skill's directory name, or a path that begins with `/`, `./`, `../` or `~/`, to a skill folder or to a `.md` / `.markdown` file. See [Roles & Skills](../everyday/roles-and-skills.md).

```text
/skill changelog
```

## /skills

**Use in:** Chat · **Chat output:** Shown

```text
/skills [TERM ...]
```

Lists the skills in your skills directory with their name and description. Terms filter the list by the text of each skill's front matter: a plain term must appear, and a `-term` must not.

```text
/skills ruby -rails
```

## /spawn

**Use in:** Chat · **Chat output:** Next prompt

```text
/spawn                                       # AIA picks a specialist for the next prompt
/spawn TYPE                                  # a specialist of this kind
/spawn NAME PROVIDER/MODEL [SYSTEM PROMPT]   # exactly the specialist you describe
```

Creates a one-off specialist robot to answer your next message. Unlike a [recruit](#add_recruit), a spawned specialist doesn't join the crew. In the full form, use `-` or `inherit` as the model to keep the session's model, and add `skill:<id>` to give the specialist a skill. A specialist gets the chief's tools and MCP servers. See [Crews](../extending/crews.md).

```text
/spawn security
Review this login controller for vulnerabilities: <%= insert 'app/controllers/sessions_controller.rb' %>
```

## /task

**Use in:** Chat · **Chat output:** Sent

```text
/task TITLE
```

Creates a TrakFlow task with the given title. Like `/plan`, it needs an initialized TrakFlow project.

```text
/task Add retry logic to the webhook sender
```

## /tasks

**Aliases:** `/tf` · **Use in:** Chat · **Chat output:** Sent

```text
/tasks             # ready tasks
/tasks summary     # project summary
```

Shows TrakFlow tasks that are ready to work on, or a summary of the project.

## /temperature

**Aliases:** `/temp` · **Use in:** Chat · **Chat output:** Shown

```text
/temperature VALUE
```

Sets the sampling temperature for the rest of the session. Lower values give more focused answers, and higher values give more varied ones. This is the same as `/config temperature VALUE`. In 2.0.0 the robot that is already running keeps its old temperature. The new value applies after you switch with `/model`, and to robots built later in the session.

```text
/temp 0.2
```

## /tools

**Use in:** Chat · **Chat output:** Shown

```text
/tools [FILTER]
```

Lists the tools the model can call, both local and MCP, with their descriptions. `FILTER` keeps only the tools whose name or description contains that text. See [Tools](../extending/tools.md).

```text
/tools file
```

## /top_p

**Aliases:** `/topp` · **Use in:** Chat · **Chat output:** Shown

```text
/top_p VALUE
```

Sets top-p (nucleus) sampling for the rest of the session. This is the same as `/config top_p VALUE`. Like `/temperature`, it doesn't change the robot that is already running until you switch with `/model`. Some providers reject requests that set both temperature and top-p.

## /verify

**Use in:** Chat · **Chat output:** Next prompt

```text
/verify [TEMPERATURE_DELTA]
```

Gets two independent answers to your next message, then reconciles them into one answer. This is useful for questions where a single answer might be confidently wrong.

```text
/verify
How many weekdays are there between 2026-11-02 and 2026-12-25 inclusive?
```

With several models configured, the verifiers use the first and second models and the reconciler uses the third (or the first, if there are only two). With one model, all three use it.

The optional `TEMPERATURE_DELTA` (a number of 0 or more) runs verifier A at the configured temperature minus the delta and verifier B at plus the delta, clamped to 0.0–1.0, so the two answers differ more. `/verify 0.3` with temperature 0.7 gives 0.4 and 1.0.

## /webpage

**Aliases:** `/website`, `/web` · **Use in:** Both · **Chat output:** Sent

```text
/webpage URL
<%= webpage 'URL' %>
```

Fetches a web page through the [pure.md](https://pure.md) service and inserts it as Markdown. This requires the `PUREMD_API_KEY` environment variable. Without it, AIA prints `ERROR: PUREMD_API_KEY is required in order to include a webpage`.

```text
/web https://docs.ruby-lang.org/en/master/NEWS_md.html
```

## See also

- [Directives](../prompts/directives.md): concepts, categories and writing your own
- [Chat Sessions](../everyday/chat.md): directives in everyday chat
- [CLI Options](cli.md): the command-line equivalents of many settings
