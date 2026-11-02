# Glossary

The terms this manual uses, in alphabetical order, with a pointer to where each is explained.

**@mention**
: Writing `@name` in a chat message to send it to a particular crew member, or `@crew` to send it to all of them. See [Crews](../extending/crews.md).

**Chat session**
: An interactive conversation started with `--chat`. The model remembers earlier turns until you `/clear` them. See [Chat Sessions](../everyday/chat.md).

**Checkpoint**
: A named point in a chat conversation, saved with `/checkpoint`, that you can go back to with `/restore`. See [Chat Sessions](../everyday/chat.md).

**Chief**
: The lead robot of a crew — the one that answers when you don't address anyone in particular. See [Crews](../extending/crews.md).

**Config file**
: The YAML file holding your default settings, `~/.config/aia/aia.yml`. A project can add `./config/aia.yml`, and `-c FILE` substitutes another. See [The Config File](../configuration/config-file.md).

**Consensus**
: With several models, an extra step that merges their answers into one response (`--consensus`). See [Multi-Model & Consensus](../extending/multi-model.md).

**Context file**
: A file named on the command line after the prompt ID. Its contents are sent along with the prompt. See [Context Files & Piping](../everyday/context-and-piping.md).

**Crew**
: The team of robots behind a chat session. Every chat is a crew, even with one model; you add members with `/add_recruit`. See [Crews](../extending/crews.md).

**Directive**
: A command that starts with `/`, such as `/model`, `/clear` or `/webpage`. You type directives in chat; some also work inside prompt files. aia handles them itself rather than sending them to the model. See [Directives](../prompts/directives.md) and the [Directives reference](../reference/directives.md).

**ERB**
: Embedded Ruby — `<%= … %>` tags in a prompt file that are replaced with the result of Ruby code. Parameters and `include` are written this way. See [ERB & Shell](../prompts/erb-and-shell.md).

**Executable prompt**
: A prompt file whose first line is a `#!` line that runs `aia`, so you can run the file directly like a script. See [Executable Prompts](../prompts/executable-prompts.md).

**Front matter**
: The YAML block between `---` lines at the top of a prompt file. It holds the description, parameters, `next:` / `pipeline:` and other settings. See [Prompt Files](../prompts/prompt-files.md).

**History file**
: The file that keeps the lines you type at the chat prompt, for up-arrow recall. Default `~/.prompts/_prompts.log`. See [Output & History](../everyday/output-and-history.md).

**MCP (Model Context Protocol)**
: An open protocol for giving models access to tools and data provided by separate programs or services. See [MCP Servers](../extending/mcp.md).

**MCP server**
: A program (run locally over *stdio*) or a web service (over *Streamable HTTP*) that offers tools through MCP. Configured under `mcp_servers:` or with `--mcp`. See [MCP Servers](../extending/mcp.md).

**Model**
: The LLM that answers, such as `gpt-4o-mini` (the default) or `claude-sonnet-4-6`. Chosen with `-m`. See [Choosing Models](../everyday/models.md).

**Multi-model**
: Running the same prompt on several models at once, by giving `-m` a comma-separated list. See [Multi-Model & Consensus](../extending/multi-model.md).

**Output file**
: The file each response is written to, as well as the terminal. Default `temp.md` in the current directory; change it with `-o` or turn it off with `--no-output`. See [Output & History](../everyday/output-and-history.md).

**Parameter**
: A named blank in a prompt, written `<%= name %>` and declared in the front matter. aia asks you for a value when the parameter has no default. See [Parameters](../prompts/parameters.md).

**Pipeline**
: A sequence of prompts run one after another in the same conversation, so each sees the responses before it. Built with `-p`, `-n`, or `next:` / `pipeline:` in front matter. See [Pipelines](../prompts/pipelines.md).

**Plugin**
: A Ruby file in your plugins directory that aia loads at startup and reloads when it changes during a chat. See [Plugins](../prompts/plugins.md).

**Prompt**
: The text you send to the model. In aia it usually comes from a prompt file, but it can also be piped in or typed in chat.

**Prompt file**
: A Markdown file (`.md`) in your prompts directory that contains a prompt, optionally with front matter, parameters, ERB and shell expansion. See [Prompt Files](../prompts/prompt-files.md).

**Prompt ID**
: A prompt file's name without `.md`. `aia code_review` runs `~/.prompts/code_review.md`. In 2.0.0, use only letters, digits and underscores, and keep prompt files at the top level of the prompts directory. See [Prompt Files](../prompts/prompt-files.md#prompt-ids).

**Prompts directory**
: Where aia looks for prompt files. Default `~/.prompts`; change it with `--prompts-dir` or `AIA_PROMPTS__DIR`.

**Provider**
: The service or local server that runs a model: `openai`, `anthropic`, `gemini`, `ollama`, `lms` and so on. `aia --list-providers` lists them. See [Choosing Models](../everyday/models.md).

**Provider prefix**
: A provider name written in front of a model name, as in `ollama/llama3.2`, to say which provider should run it.

**Recruit**
: A crew member you add with `/add_recruit`. It stays for the rest of the session and answers to `@name`. See [Crews](../extending/crews.md).

**Robot**
: aia's name for one configured model connection — a model plus its role, tools and conversation. A chat session has at least one (the chief).

**Role**
: A prompt file in the roles directory (`~/.prompts/roles/`) that tells the model who to be, such as "senior Ruby reviewer". Applied with `-r`. See [Roles & Skills](../everyday/roles-and-skills.md).

**Shell expansion**
: Replacing `$(command)` in a prompt file with the command's output, and `$NAME` with an environment variable, before the prompt is sent. See [ERB & Shell](../prompts/erb-and-shell.md).

**Skill**
: A reusable set of instructions stored as a directory containing a `SKILL.md` file, added to a prompt or chat with `-s`. See [Roles & Skills](../everyday/roles-and-skills.md).

**Specialist**
: A one-shot robot created with `/spawn` to handle the next prompt only. See [Crews](../extending/crews.md).

**System prompt**
: Standing instructions given to the model before the conversation. In chat, aia builds it from `--system-prompt`, the role and any skills.

**Thinking**
: Reasoning that some models write inside `<think>…</think>` tags before answering. Hidden unless you pass `--thinking`.

**Token**
: The unit models count text in — roughly three-quarters of an English word. Limits and prices are in tokens; `--tokens` and `--cost` show usage.

**Tool**
: A function the model can call to act or look something up — read a file, search the web, query a database. Tools come from Ruby files (`--tools`), gems (`--require`) or MCP servers. See [Tools](../extending/tools.md).

**Tool approval**
: The check aia applies before running tools from an MCP server marked `requires_approval:`. Controlled by `--tool-approval`. See [Security](../configuration/security.md#tool-approval).

**Tool filter**
: Automatic narrowing of the tools offered to the model on each turn to those relevant to your prompt. On by default; `--no-auto-tool-filter` turns it off.

**TrakFlow**
: A task-tracking tool aia can use to record pipelines (`--track-pipeline`) and plans (`/plan`, `/task`, `/tasks`). See [Advanced Modes](../extending/advanced-modes.md).

## See also

- [Command-Line Options](../reference/cli.md)
- [Configuration Keys](../reference/config-keys.md)
- [FAQ & Troubleshooting](../reference/faq.md)
