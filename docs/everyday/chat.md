# Chat Sessions

Chat mode turns AIA into an interactive conversation in your terminal. The model remembers everything said so far, and you can steer the session as you go with `/` directives: switch models, pull in files, save and restore checkpoints, and more.

## Starting a chat

```bash
aia --chat                              # an empty conversation
aia --chat code_review lib/order.rb     # run a prompt first, then keep talking
aia --chat notes.md todo.md             # no prompt: the files are your first message
git diff | aia --chat                   # no prompt: the piped text is your first message
aia --chat --role tutor --model claude-sonnet-4-5
```

When you start with a prompt ID (or a [pipeline](../prompts/pipelines.md)), AIA runs it as usual, prints the answer, and then drops you into the conversation with that exchange already in context.

## What you'll see

A chat opens with a banner showing the AIA version and the session's setup: the model(s), the libraries in use, how many tools are loaded, which MCP servers connected (or failed), and the crew of robots you can address with `@name`:

```text
       ,      ,        AIA v2.0.0 is Online
       (\____/)
        (_oo_)         Models: gpt-4o-mini
         (O)              DB: refreshed 2026-10-30 at 09:12
       __|||__    \)    Libs: ruby_llm v2.1.1, robot_lab v0.5.1, ...
     [/ Tobor \]  /    Tools: none loaded
    / \_______/ \/       MCP: (none configured)
   ...                  Crew: @tobor
```

Then the conversation starts:

```text
Entering interactive chat mode...
════════════════════════════════════════════════════════════════════
Follow up (cntl-D or 'exit' to end) #=>
How do I reverse a linked list in Ruby?

AI:
   You can reverse a singly linked list iteratively by walking it once
   and flipping each node's `next` pointer...

────────────────────────────────────────────────────────────────────
Follow up (cntl-D or 'exit' to end) #=>
```

Answers stream in as the model writes them. A spinner shows while AIA is waiting for the first words.

## Ending a chat

Any of these ends the session and prints `Chat session ended.`:

- Type `exit`
- Press ++ctrl+d++
- Press ++enter++ on an **empty line**
- Press ++ctrl+c++

!!! warning "An empty line ends the chat"
    Pressing ++enter++ without typing anything is the same as `exit`. If you hit it by accident, you'll need to start again (your input history is kept, see below).

## Typing input

Each message is a **single line**. Press ++enter++ to send it. For anything longer than a line (code, a log, a document), don't type it in: use `/include FILE`, `/insert FILE` or `/paste` instead (see [Directives in chat](#directives-in-chat)).

The input line supports the usual editing keys (arrows, ++home++, ++end++, ++ctrl+a++, ++ctrl+e++). Press ++up++ and ++down++ to step back through what you typed earlier. AIA keeps your last 50 entries in its history file, so they're still there next session. See [Output, History and Usage](output-and-history.md#chat-input-history).

### Your input is processed like a prompt

Each line you type goes through the same processing as a prompt file before it is sent:

- `$(command)` is replaced by the command's output, and `$VAR` / `${VAR}` by environment variables
- `<%= ... %>` ERB is evaluated
- `<!-- ... -->` comments are removed

```text
Follow up (cntl-D or 'exit' to end) #=>
Here is my git status, what should I commit first? $(git status --short)
```

This is handy, and it also means a stray `$(...)` in your text will run. See [ERB and Shell Expansion](../prompts/erb-and-shell.md).

## Directives in chat

A line that starts with `/` is a **directive**, a command for AIA rather than a message for the model. `/help` lists them all. If you mistype one, AIA tells you:

```text
Unknown directive: /modle  (use /help to see available directives)
```

When a directive produces output (a file, a web page, your clipboard), AIA shows it and then sends it to the model with a short note saying which directive it came from, so the model can use it. Directives that only change settings (`/model`, `/config`, `/checkpoint`) just print a confirmation.

The directives you'll use most in chat:

| Directive | What it does |
|-----------|--------------|
| `/help` | List every directive and its aliases |
| `/model [NAME[,NAME…]]` | Show the current model, or switch to another (see below) |
| `/models [TERMS]` (aliases `/available_models`, `/am`, `/llms`, …) | Search available models |
| `/config [KEY [VALUE]]` (alias `/cfg`) | Show all settings, show one, or change one |
| `/temperature N` (alias `/temp`), `/top_p N` (alias `/topp`) | Change those settings |
| `/include FILE` | Add a file, rendered like a prompt |
| `/insert FILE` (alias `/read`) | Add a file's raw text |
| `/paste` (alias `/clipboard`) | Add the clipboard contents |
| `/webpage URL` (aliases `/web`, `/website`) | Add a web page as Markdown (needs `PUREMD_API_KEY`) |
| `/skills [TERMS]`, `/skill NAME` | List skills, or add one to the conversation ([Roles and Skills](roles-and-skills.md)) |
| `/checkpoint`, `/restore`, `/clear`, `/review`, `/checkpoints` | Manage the conversation (see below) |
| `/tools [FILTER]`, `/mcp`, `/robots`, `/plugins` | Show loaded tools, MCP servers, the active robots, loaded plugins |
| `/cost` | Print this session's token and cost figures as CSV |
| `/say TEXT` | Speak text aloud with your system's speech command |
| `/ruby CODE` (alias `/rb`) | Run Ruby code (only when started with `--allow-ruby-eval`) |

Every directive, with all arguments and aliases, is in the [Directives reference](../reference/directives.md). Directives can also be used inside prompt files; see [Directives](../prompts/directives.md).

## Switching models mid-conversation

```text
/model
```

shows what you're talking to. To switch:

```text
/model claude-sonnet-4-5
/model gpt-4o,gemini-2.5-pro        # switch to several models at once
```

AIA rebuilds the session with the new model. The conversation so far comes with you: the old model writes a summary of the conversation, and the new model starts from that summary. This costs one extra request.

!!! note "`model_switch_history` has no effect in 2.0.0"
    `defaults.yml` and the 2.0.0 changelog describe a `model_switch_history` setting (`summarize`, `replay`, `clean`), but aia 2.0.0 never loads it, so every switch summarizes. For a fresh start, run `/clear` after `/model`.

When a switch carries history over, AIA tells you: `Switching to claude-sonnet-4-5 (conversation: summarize)...`

## Checkpoints: undo for conversations

Checkpoints let you save the conversation at a point and come back to it, which is useful for exploring a "what if" without polluting the main thread.

```text
/checkpoint before_refactor
Checkpoint 'before_refactor' created at position 6.

...try an approach, decide you don't like it...

/restore before_refactor
Context restored to checkpoint 'before_refactor' (position 6).
```

| Directive | Effect |
|-----------|--------|
| `/checkpoint [NAME]` (aliases `/ckp`, `/cp`) | Save the conversation. Without a name, checkpoints are numbered `1`, `2`, … |
| `/restore [NAME]` | Go back to a checkpoint. Without a name, goes back to the second most recent checkpoint (you need at least two). Checkpoints made after that point are discarded. |
| `/checkpoints` (alias `/checkpoints_list`) | List your checkpoints |
| `/review` (alias `/context`) | Show the conversation so far, with checkpoint markers |
| `/clear` | Forget the conversation but keep the system prompt (role, skills) |
| `/clear --all` | Forget everything, including the system prompt |

Checkpoints live in memory only. They disappear when the chat ends.

## Roles, skills and system prompts in chat

In chat, a `--role` and any `--skill`s go into the **system prompt**, so they shape every answer rather than just the first one. You can also supply system prompt text directly:

```bash
aia --chat --system-prompt "Answer in British English. Be concise."
```

To bring a skill in partway through a conversation, use `/skill NAME`. See [Roles and Skills](roles-and-skills.md).

## Talking to more than one model

Start a chat with several models and each one answers every message:

```bash
aia --chat --model gpt-4o,claude-sonnet-4-5
```

Each model runs as a named robot. Begin a message with `@name` to talk to just one of them, or `@crew` to address all of them explicitly:

```text
@tobor what do you think of the other answer?
```

Use `/robots` to see the names. Building and managing a crew of robots, including adding and removing members during a chat, is covered in [Crews](../extending/crews.md). Merging the answers into one with `--consensus` is covered in [Multiple Models and Consensus](../extending/multi-model.md).

## Special modes for the next message

A few directives change how AIA handles **only your next message**: `/verify` gets two independent answers and reconciles them, `/decompose` splits a task into parallel sub-tasks, `/debate` has the robots argue it out, and there are others (`/concurrent`, `/delegate`, `/spawn`, `/orchestrate`). Only one can be active at a time. They're explained in [Advanced Modes](../extending/advanced-modes.md).

## Other useful options for chat

| Option | Effect in chat |
|--------|----------------|
| `--tokens` / `--cost` | Show token use, time (and cost) after every answer |
| `--speak` | Read every answer aloud ([Images and Speech](../extending/images-and-speech.md)) |
| `--thinking` | Show `<think>…</think>` reasoning that some local models emit (hidden by default) |
| `--output FILE` | Record the conversation (your messages as `You:`, answers as `AI:`) |
| `--tools`, `--mcp` | Give the model [tools](../extending/tools.md) and [MCP servers](../extending/mcp.md) |

If you use [plugins](../prompts/plugins.md), AIA watches your plugins directory during a chat and loads, reloads or unloads plugin files as you add, edit or delete them, with no restart needed.

## See also

- [Reference: Directives](../reference/directives.md)
- [Context Files and Piping](context-and-piping.md)
- [Crews](../extending/crews.md)
- [Output, History and Usage](output-and-history.md)
