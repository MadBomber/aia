# Quick Tour

A ten-minute walk through the things you'll do with AIA most often. Each stop links to the chapter that covers it in depth. You only need AIA installed and one API key (see [Installation](installation.md)).

!!! tip "Follow along without clutter"
    The examples pass `--no-output` so AIA doesn't also write each answer to `./temp.md`. If you've already set `output.file: ~` in your config file, you can leave it off.

## 1. Ask a question

The fastest way to use AIA is to pipe a question into it:

```bash
echo "What does the Unix 'tee' command do? One sentence." | aia --no-output
```

```text
AI: 
   **Tobor** (1.2s):
   `tee` reads standard input and writes it both to standard output and to one or more files.
```

When there's no prompt ID on the command line, whatever arrives on stdin *is* the prompt.

## 2. Save a prompt and run it by name

Prompts you use more than once belong in files. Create one in your prompts directory:

```bash
cat > ~/.prompts/explain.md <<'PROMPT'
Explain the following to a developer who is new to it.
Be brief, and give one concrete example.
PROMPT
```

The file name, without `.md`, is the **prompt ID**:

```bash
echo "Ruby's safe navigation operator" | aia --no-output explain
```

Now the prompt comes from the file and stdin is appended to it. See [Running Prompts](../everyday/running-prompts.md).

## 3. Give it files to work on

Any files listed after the prompt ID are added to the prompt as context:

```bash
aia --no-output explain lib/parser.rb
```

You can list as many files as you want. See [Context Files and Piping](../everyday/context-and-piping.md).

## 4. Fill in parameters

A prompt can declare parameters in YAML front matter and use them with ERB:

```markdown title="~/.prompts/translate.md"
---
parameters:
  language: Spanish
---
Translate the following text into <%= language %>. Keep the formatting.
```

```bash
echo "The meeting has moved to Thursday." | aia --no-output translate
```

```text
Value for language (Spanish): French

AI: 
   **Tobor** (0.9s):
   La réunion a été déplacée à jeudi.
```

Press ++enter++ to accept the default shown in parentheses. See [Parameters](../prompts/parameters.md).

## 5. Pull in live data with the shell

`$(command)` in a prompt is replaced by that command's output before the prompt is sent:

```markdown title="~/.prompts/commit_msg.md"
Write a conventional commit message for this change:

$(git diff --staged)
```

```bash
aia --no-output commit_msg
```

See [ERB and Shell Expansion](../prompts/erb-and-shell.md).

## 6. Chat

Add `--chat` to keep the conversation going after the first answer, or start a chat with no prompt at all:

```bash
aia --chat
```

```text
Entering interactive chat mode...
════════════════════════════════════════════════════════════
Follow up (cntl-D or 'exit' to end) #=>
What's a good name for a CLI that converts CSV to JSON?
```

Inside a chat, lines that start with `/` are **directives**: `/model`, `/include notes.md`, `/checkpoint`, `/help`. See [Chat Sessions](../everyday/chat.md).

## 7. Pick a model

```bash
aia --no-output --model claude-sonnet-4-5 explain lib/parser.rb
aia --available-models claude        # search the model catalog
```

See [Choosing Models](../everyday/models.md).

## 8. Ask several models at once

```bash
aia --no-output --model gpt-4o,claude-sonnet-4-5 explain lib/parser.rb
```

Each model answers in parallel. Add `--consensus` to have their answers merged into one. See [Multiple Models and Consensus](../extending/multi-model.md).

## 9. Put on a role

A role is a reusable persona stored in `~/.prompts/roles/`:

```bash
cat > ~/.prompts/roles/reviewer.md <<'ROLE'
You are a meticulous senior code reviewer. Point out bugs first, then style.
ROLE

aia --no-output --role reviewer explain lib/parser.rb
```

See [Roles and Skills](../everyday/roles-and-skills.md).

## 10. See what it costs

```bash
aia --no-output --cost explain lib/parser.rb
```

After the response AIA prints a table of input/output tokens, elapsed time and cost. See [Output, History and Usage](../everyday/output-and-history.md).

## Where to go from here

You've now seen most of what AIA does day to day. Two good next steps:

- [Your First Prompt](first-prompt.md): build a real, reusable prompt step by step
- [Running Prompts](../everyday/running-prompts.md): every way of telling AIA what to run

Later, when you want more: [Pipelines](../prompts/pipelines.md), [Tools](../extending/tools.md), [MCP Servers](../extending/mcp.md).
