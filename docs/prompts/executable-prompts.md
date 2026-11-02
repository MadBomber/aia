# Executable Prompts

An executable prompt is a prompt file that you run like a shell script. Give it a shebang line and make it executable, and `./standup` asks the model your question with no `aia` command to type.

## Your first executable prompt

Create a file with `aia` on the shebang line:

```bash
cat > fun_fact <<'EOF'
#!/usr/bin/env -S aia --no-output
Tell me one surprising fun fact about a random animal.
Keep it to two sentences.
EOF

chmod +x fun_fact
./fun_fact
```

When you run `./fun_fact`, the system runs `aia --no-output ./fun_fact`. AIA sees that the file starts with `#!`, drops that first line, and uses the rest of the file as the prompt.

Anything that works in a regular prompt file also works here. That includes front matter, [parameters](parameters.md), [shell expansion and ERB](erb-and-shell.md):

```markdown
#!/usr/bin/env -S aia --no-output
---
temperature: 0.3
parameters:
  days: 1
---
Write a short stand-up update from these commits in $(basename $(pwd)):

<%= `git log --since="#{days} days ago" --oneline` %>
```

!!! tip "Parameters inside commands"
    Shell expansion runs **before** ERB, so a `$(...)` command can't see parameter values. A `<%= days %>` inside `$(...)` reaches the shell as literal text. When a command needs a parameter, run it with Ruby backticks inside ERB, as the last line above does.

## The shebang line

```text
#!/usr/bin/env -S aia --no-output
```

- **`-S`** tells `env` to split the rest of the line into separate arguments. Linux needs it. macOS splits shebang arguments without it, but `-S` works on both, so use it.
- **Put AIA options on the shebang line.** Any option from the [CLI reference](../reference/cli.md) can go there, such as `--model`, `--role`, `--tokens` or `-c my_config.yml`.
- **Use `--no-output`** unless you want a copy of each response in `temp.md` in whatever directory you run the script from.

A few useful variations:

```text
#!/usr/bin/env -S aia --no-output --model gpt-4o
#!/usr/bin/env -S aia --no-output --role ruby_expert
#!/usr/bin/env -S aia --chat
```

The last one answers the prompt and then opens a chat session so you can ask follow-up questions.

## Adding options and files when you run it

Arguments you type after the script name are passed to AIA. Options are applied to that run, and file names become [context files](../everyday/context-and-piping.md) added after the prompt:

```bash
./fun_fact --model claude-sonnet-4      # use a different model this time
./fun_fact --tokens                     # show token usage
./review_file lib/parser.rb             # add a file for the prompt to work on
```

Options from the shebang line and options you type are combined. For an option that holds a single value, such as `--temperature` or `--role`, the value you type wins. List options such as `--model`, `--next` and `--pipeline` **add** to what the shebang sets. If the shebang already names a model, typing `--model` runs both models side by side.

## Piping input into an executable prompt

Text piped into an executable prompt is added after the prompt:

```bash
git diff --cached | ./commit_message
```

```markdown
#!/usr/bin/env -S aia --no-output
---
temperature: 0.2
---
Write a conventional commit message for the staged diff below.
Subject line under 60 characters, then a short body.
```

Parameters still work when you pipe input. AIA reads your answers from the terminal, not from the pipe.

## Prompts without a file

The prompt doesn't have to be in a file at all. When you don't name a prompt ID, whatever arrives on STDIN **is** the prompt:

```bash
echo "Explain the difference between a process and a thread." | aia --no-output

aia --no-output < question.txt
```

Piped prompts are processed like a prompt file, with front matter, shell expansion and ERB.

!!! warning "Don't pipe a file that has a shebang"
    When you pipe a file that starts with `#!` into `aia`, the shebang line is sent to the model with the rest of the text. A front matter block after it is also not recognized. Run the file directly (`./fun_fact`) or pass it as an argument (`aia --no-output ./fun_fact`) instead.

## Where the response goes

The response is printed to standard output. It starts with an `AI:` label and each line is indented. The progress spinner goes to standard error, so redirecting standard output captures only the response:

```bash
./standup > standup.txt
./standup | pbcopy
```

To save responses to a file with AIA's own output handling, use `--output FILE` (and `--append` to keep earlier runs). See [Output & History](../everyday/output-and-history.md).

## Limitations

- **`include` is not available.** An executable prompt isn't in your prompts directory, so `<%= include 'file' %>` stops with an error. Use `<%= insert 'file' %>`, which reads the file as-is, relative to your current directory.
- **The prompt runs from your current directory.** Relative paths in `$(...)`, ERB and `insert` are resolved against the directory you run the script from, not the directory that holds the script.

## Ideas

- **Git hooks.** A `prepare-commit-msg` hook that runs `git diff --cached | ~/bin/commit_message`.
- **Daily reports.** A cron job that runs `./standup` and mails the result. Give every parameter a default so nothing waits for input.
- **Make targets.** `review: ; ./prompts/review_changes $(shell git diff --name-only)`.

!!! danger "Treat executable prompts as scripts"
    An executable prompt runs shell commands and Ruby code with your permissions. Read one before you run it, just as you would any other script. See [Security](../configuration/security.md).

## See also

- [Prompt Files](prompt-files.md): front matter and layout
- [ERB & Shell](erb-and-shell.md): dynamic content in a prompt
- [Context Files & Piping](../everyday/context-and-piping.md): more on STDIN and files
- [CLI Options](../reference/cli.md): every option you can put on the shebang line
