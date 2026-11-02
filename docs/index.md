# AIA User Manual

AIA ("AI Assistant") is a command-line program for working with large language models from your terminal. You keep your prompts as plain Markdown files, and AIA fills them in, sends them to the model of your choice, and gives you the answer, or keeps the conversation going in an interactive chat.

<div align="center" markdown>
![AIA](assets/images/aia.png){ width="320" }
</div>

This manual covers AIA 2.0.0.

## Who this manual is for

You use a terminal every day and you want an LLM to be part of that work, not a browser tab off to the side. You don't need to know Ruby to use AIA. Some optional features (ERB templates, custom tools) use Ruby, and the manual explains what you need when you get there.

## What you can do with AIA

- **Keep a library of prompts.** Each prompt is a `.md` file in your prompts directory (`~/.prompts` by default). You run one by name: `aia code_review`.
- **Fill in prompts with parameters.** A prompt can declare values such as `language` or `audience`. AIA asks for them when you run it.
- **Feed it your files and your shell.** Pass files on the command line, pipe text in on stdin, or embed `$(git diff)` in a prompt and AIA runs the command for you.
- **Chat.** `aia --chat` opens an interactive session. Use `/` directives in the chat to switch models, include files, save checkpoints, and more.
- **Use any model.** OpenAI, Anthropic, Google and the other providers RubyLLM supports, plus local models through Ollama or LM Studio. Pick one per run with `--model`.
- **Run several models at once.** `--model gpt-4o,claude-sonnet-4-5` sends the same prompt to both. Add `--consensus` and AIA combines their answers into one.
- **Chain prompts into pipelines.** One prompt's output becomes the next one's input.
- **Give the model tools.** Load Ruby tools or connect MCP servers so the model can read files, query APIs, or run commands, with your approval.
- **Track usage.** `--tokens` and `--cost` show token counts, time and cost after every response.

## A taste

```bash
# Ask a one-off question by piping it in
echo "Explain the difference between a process and a thread in two sentences." | aia

# Run a saved prompt against a file
aia summarize meeting_notes.txt

# Start a chat, with a role, on a specific model
aia --chat --role code_reviewer --model claude-sonnet-4-5
```

## How this manual is organized

| Part | What it covers |
|------|----------------|
| **Getting Started** | [Installation](getting-started/installation.md), a [Quick Tour](getting-started/quick-tour.md) of the main features, and [Your First Prompt](getting-started/first-prompt.md). Start here if you are new. |
| **Everyday Use** | [Running prompts](everyday/running-prompts.md), [chat sessions](everyday/chat.md), [context files and piping](everyday/context-and-piping.md), [roles and skills](everyday/roles-and-skills.md), [choosing models](everyday/models.md), and [output, history and usage reports](everyday/output-and-history.md). |
| **Writing Prompts** | [Prompt files and front matter](prompts/prompt-files.md), [parameters](prompts/parameters.md), [directives](prompts/directives.md), [ERB and shell expansion](prompts/erb-and-shell.md), [pipelines](prompts/pipelines.md), and [executable prompts](prompts/executable-prompts.md). |
| **Extending AIA** | [Tools](extending/tools.md), [MCP servers](extending/mcp.md), [multiple models and consensus](extending/multi-model.md), [crews](extending/crews.md), [local models](extending/local-models.md), [images and speech](extending/images-and-speech.md), and [advanced modes](extending/advanced-modes.md). |
| **Configuration** | The [config file](configuration/config-file.md), [environment variables](configuration/environment.md), [how settings override each other](configuration/precedence.md), and [security](configuration/security.md). |
| **Reference** | Every [command-line option](reference/cli.md), every [directive](reference/directives.md), every [configuration key](reference/config-keys.md), and the [FAQ and troubleshooting](reference/faq.md) page. |
| **Appendix** | [Upgrading to 2.0](appendix/upgrading-2.0.md), [migrating old prompts](appendix/migrating-prompts.md), and a [glossary](appendix/glossary.md). |

The Getting Started and Everyday Use parts are written to be read in order. The rest you can dip into when you need it.

## Getting help

- `aia --help` lists every option with a one-line description.
- In a chat session, `/help` lists every directive.
- Bugs and feature requests: <https://github.com/MadBomber/aia/issues>
- Changes between releases: the [changelog](https://github.com/MadBomber/aia/blob/main/CHANGELOG.md)

## Next steps

- [Install AIA](getting-started/installation.md)
- [Take the quick tour](getting-started/quick-tour.md)
