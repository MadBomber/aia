# Context Files and Piping

Most useful prompts are about *something*: a file, a diff, a log, a web page. This chapter shows how to hand that material to AIA, and how to send AIA's answers on to other programs.

## Context files

Every file you list after the prompt ID is read and appended to the prompt, in the order you list them:

```bash
aia code_review app/models/order.rb app/models/line_item.rb
```

Your shell expands wildcards before AIA sees them, so globs work:

```bash
aia summarize notes/2026-10-*.md
aia code_review lib/**/*.rb        # zsh, or bash with `shopt -s globstar`
```

Things to know:

- **Files must exist.** A missing file stops AIA before the model is called: `The following files do not exist: …`
- **Files are read as text** and pasted in as-is. AIA does not send images, PDFs or other binary files as attachments. Convert them to text first (for example with `pdftotext`).
- **There is no size check.** A large file is sent in full and counts against the model's context window and your token bill. Use `--tokens` to see how big a request was.
- **You need a prompt ID or `--chat`.** Context files on their own give AIA nothing to ask. With `--chat` and no prompt, the files become your first chat message.

## Piping text in

Anything you pipe into AIA is added to the prompt:

```bash
git diff --staged | aia commit_msg
kubectl logs api-7f9c --since=1h | aia find_errors
curl -s https://api.example.com/status | aia explain_json
```

With **no prompt ID**, the piped text *is* the prompt:

```bash
echo "Write a haiku about merge conflicts." | aia
pbpaste | aia --chat          # macOS: start a chat about whatever's on the clipboard
```

If the piped text starts with a `#!` line, that line is dropped before the text is used.

You can combine stdin and context files. The prompt comes first, then stdin, then the files:

```bash
git diff main | aia code_review CONTRIBUTING.md
```

## Pulling content in from inside a prompt

Instead of passing material on the command line, a prompt file can fetch it itself:

| In a prompt file | What it does |
|------------------|--------------|
| `$(git log --oneline -20)` | Replaced with the command's output |
| `$HOME`, `${PROJECT}` | Replaced with an environment variable (uppercase names only) |
| `<%= include 'includes/style.md' %>` | Inserts another prompt file, rendered |
| `<%= insert 'data/schema.sql' %>` | Inserts a file's raw text, untouched |

These are covered in [ERB and Shell Expansion](../prompts/erb-and-shell.md) and [Directives](../prompts/directives.md).

## Adding content during a chat

In a [chat session](chat.md) you can pull material in with directives:

| Directive | What it adds |
|-----------|--------------|
| `/include path/to/file.md` | A file, rendered like a prompt |
| `/insert path/to/file` (alias `/read`) | A file's raw text |
| `/paste` (alias `/clipboard`) | Whatever is on your system clipboard |
| `/webpage URL` (aliases `/web`, `/website`) | A web page converted to Markdown |

AIA shows you the directive's output and then sends it to the model with a note saying which directive produced it.

!!! note "`/webpage` needs a pure.md key"
    Web pages are fetched through the [pure.md](https://pure.md) service, which turns them into clean Markdown. Set `PUREMD_API_KEY` in your environment to use it. Without it you'll see `ERROR: PUREMD_API_KEY is required in order to include a webpage`.

## Piping AIA's answer onward

AIA prints the answer to standard output, so you can pipe or redirect it:

```bash
aia release_notes CHANGELOG.md > release_notes.txt
aia summarize report.txt | pbcopy
```

The terminal output is meant for reading: it starts with an `AI:` label, shows the name of the robot that answered, and indents every line. The progress spinner goes to stderr, so it won't end up in your file.

For a file without the indentation, use AIA's output file instead. It gets each response as plain Markdown after an `AI:` label:

```bash
aia --output release_notes.md release_notes CHANGELOG.md
```

See [Output, History and Usage](output-and-history.md).

## Patterns worth stealing

**Review only what changed**

```bash
git diff main...HEAD | aia code_review
```

**Explain an error you just hit**

```bash
bundle exec rake test 2>&1 | tail -50 | aia explain_failure
```

**Summarize a directory of notes and keep talking**

```bash
aia --chat summarize meetings/*.md
```

**Ask a question about a command's output, no prompt file needed**

```bash
{ echo "Which of these processes is using the most memory, and is that normal?"; ps aux | sort -nrk 4 | head -15; } | aia
```

## See also

- [Running Prompts](running-prompts.md): how AIA assembles the final text
- [ERB and Shell Expansion](../prompts/erb-and-shell.md)
- [Pipelines](../prompts/pipelines.md): feed one prompt's answer into the next
- [Security](../configuration/security.md): what to watch for when prompts run commands
