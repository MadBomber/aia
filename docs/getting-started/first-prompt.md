# Your First Prompt

In this chapter you build one useful prompt, a code explainer, a step at a time. Along the way you meet the pieces every AIA prompt is made of: plain text, parameters, front matter, shell expansion, includes and chat.

## Step 1: A plain prompt

A prompt is just a Markdown file in your prompts directory (`~/.prompts`). Create `~/.prompts/explain_code.md`:

```markdown title="~/.prompts/explain_code.md"
Explain what the following code does, step by step.
Point out anything surprising or risky.
```

Run it, giving it a source file to explain:

```bash
aia --no-output explain_code app/models/user.rb
```

AIA reads the prompt file, appends the contents of `app/models/user.rb`, sends the result to the model, and prints the answer:

```text
AI: 
   **Tobor** (3.1s):
   This file defines a `User` model with ...
```

The bold name is the robot that answered. AIA gives each model it runs a name; with a single model it's always `Tobor`.

Two things to notice:

- **The prompt ID** is the file name without `.md`. A prompt in a subfolder includes the folder: `~/.prompts/dev/explain-code.md` is `dev/explain-code`.
- **Extra arguments are context files.** Everything after the prompt ID must be an existing file. AIA appends each one to the prompt.

!!! note "About `--no-output`"
    Without it, AIA also writes the response to `./temp.md`. That's handy when you want to keep an answer, and noise when you don't. You can turn it off permanently with `output.file: ~` in your config file. See [Output, History and Usage](../everyday/output-and-history.md).

## Step 2: Add a parameter

Make the explanation fit your reader. Add YAML front matter with a `parameters:` section, and use the parameter in the text with ERB (`<%= ... %>`):

```markdown title="~/.prompts/explain_code.md"
---
parameters:
  audience: a junior developer
---
Explain what the following code does, step by step, for <%= audience %>.
Point out anything surprising or risky.
```

Run it again. AIA now asks you for the value first:

```text
$ aia --no-output explain_code app/models/user.rb
Value for audience (a junior developer):
```

Press ++enter++ to accept the default in parentheses, or type something else (`a product manager`). A parameter whose default is empty (`audience:` with nothing after it) is **required**: AIA keeps it marked `(required)` and stops with an error if you don't give a value.

More in [Parameters](../prompts/parameters.md).

## Step 3: Choose the model when you run it

Pick the model with `--model` (`-m`) and tune how creative it is with `--temperature` (`-t`):

```bash
aia --no-output -m claude-sonnet-4-5 -t 0.3 explain_code app/models/user.rb
```

If you always want the same model, set it once in your config file instead. See [Choosing Models](../everyday/models.md).

## Step 4: Pull in live information

A prompt can run shell commands. `$(command)` is replaced with the command's output, and `$VAR` or `${VAR}` with an environment variable:

```markdown title="~/.prompts/explain_code.md"
---
parameters:
  audience: a junior developer
---
I'm working in a $(basename $(pwd)) project on $(uname -s).
The most recent commit touching these files was:

$(git log -1 --oneline)

Explain what the following code does, step by step, for <%= audience %>.
Point out anything surprising or risky.
```

Commands run when AIA loads the prompt, before anything is sent to the model. Because of that, only run prompts you trust. See [ERB and Shell Expansion](../prompts/erb-and-shell.md) and [Security](../configuration/security.md).

## Step 5: Reuse text with `include`

If several prompts share the same guidance, keep it in one file and include it. Create `~/.prompts/includes/house_style.md`:

```markdown title="~/.prompts/includes/house_style.md"
Use short paragraphs. Show code in fenced blocks with a language tag.
Never invent APIs; say "I'm not sure" instead.
```

and add one line to the prompt:

```markdown
<%= include 'includes/house_style.md' %>
```

`include` renders the other file (its own ERB and shell references are processed too). Use `insert` (alias `read`) instead to drop in a file's raw text untouched. See [Directives](../prompts/directives.md).

## Step 6: Keep talking

When the first answer raises more questions, add `--chat`:

```bash
aia --chat explain_code app/models/user.rb
```

AIA runs the prompt as before, then leaves you at a follow-up prompt with the whole conversation still in context:

```text
Follow up (cntl-D or 'exit' to end) #=>
Why is the callback on line 42 risky?
```

Type `exit`, press ++ctrl+d++, or press ++enter++ on an empty line to finish. See [Chat Sessions](../everyday/chat.md).

## Step 7: Keep comments out of the prompt

You can leave notes for yourself in a prompt file with HTML comments. They are stripped before the prompt is processed, so the model never sees them:

```markdown
<!-- v2: added house style include, 2026-10-30 -->
```

## The finished prompt

```markdown title="~/.prompts/explain_code.md"
---
parameters:
  audience: a junior developer
---
<!-- Explains a source file. Pass the file(s) as context. -->
I'm working in a $(basename $(pwd)) project on $(uname -s).
The most recent commit touching these files was:

$(git log -1 --oneline)

Explain what the following code does, step by step, for <%= audience %>.
Point out anything surprising or risky.

<%= include 'includes/house_style.md' %>
```

## Next steps

- [Running Prompts](../everyday/running-prompts.md): all the ways to choose what AIA runs
- [Prompt Files and Front Matter](../prompts/prompt-files.md): everything a prompt file can contain
- [Pipelines](../prompts/pipelines.md): chain this prompt into another
- [Executable Prompts](../prompts/executable-prompts.md): turn a prompt into a shell command
