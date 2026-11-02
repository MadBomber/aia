# Security

aia runs with your user account's permissions. Prompt files can run shell commands and Ruby, tools can act on your system, and whatever you send goes to a model provider. This page shows where each of those happens and how to keep it under control.

## Protect your API keys

- Keep provider keys in environment variables (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY` …), set in your shell profile or a secrets manager. aia has no config key for them, so they never need to be in `aia.yml`.
- Never write a key into a prompt file. Prompts get shared, committed and pasted into chats.
- MCP servers can carry credentials in your config file (`bearer_token:`, `headers:`, `env:`). If yours does, make the file private:

    ```bash
    chmod 600 ~/.config/aia/aia.yml
    ```

- `aia --dump FILE` writes your whole configuration, MCP credentials included. Don't share a dump without reading it.
- At `debug` level the LLM log records request details. Don't leave `--debug` or `--log-to` pointed at a shared location.

## What runs code

| Source | What it can do | Default | How to control it |
|---|---|---|---|
| `$(command)` and `$VAR` in a prompt file | Runs the command; inserts environment variables | On | `shell: false` in the prompt's front matter |
| ERB (`<%= %>`, `<% %>`) in a prompt file | Runs any Ruby | On | `erb: false` in the prompt's front matter |
| Text piped to `aia` with no prompt ID | Treated as a prompt, so `$(...)` and ERB in it run | On | Give a prompt ID; piped text is then appended as plain context |
| [Executable prompts](../prompts/executable-prompts.md) (`#!` files) | Same as any prompt file | — | Read before running |
| `/ruby` directive | Runs any Ruby | **Off** | `--allow-ruby-eval` / `flags.allow_ruby_eval` |
| `--tools`, `--require`, `tools.paths`, `require_libs` | Loads Ruby code into aia | Off | Only load code you trust |
| [Plugins](../prompts/plugins.md) directory | Loads every `*.rb` file in it, and reloads changes during chat | Off | Only put files you trust there |
| Tools the model calls | Whatever the tool does | — | `--at` / `--rt` |
| MCP servers | A local server is a program aia starts as you; a remote one is a service you connect to | Off | Configure only servers you trust; see below |

### Shell expansion and ERB in prompts

Prompt files are processed before they are sent: `$(command)` is replaced by the command's output, `$NAME` / `${NAME}` by the environment variable (upper-case names only), and ERB is evaluated as Ruby. That's what makes prompts dynamic — and it means **opening a prompt file with aia is running it**.

```markdown
---
description: Summarize today's commits
---
Summarize these commits for a standup:

$(git log --since=midnight --oneline)
```

Text inside fenced code blocks (```` ``` ```` or `~~~`) is left alone by shell expansion. Command output is never re-expanded, and it can't inject ERB.

If a prompt only needs plain text, switch processing off in its front matter:

```yaml
---
shell: false
erb: false
---
```

To switch it off for every prompt, set `flags.shell: false` and `flags.erb: false` in your config file; a prompt's own `shell:` / `erb:` front matter still wins. See [ERB & Shell](../prompts/erb-and-shell.md).

!!! warning "Piped text with no prompt ID is a prompt"
    `some_command | aia` (with no prompt ID) runs the piped text as a prompt, so `$(...)` and ERB in it are executed. Don't pipe untrusted content — a web page, an email, a downloaded file — into `aia` without a prompt ID. With a prompt ID (`some_command | aia summarize`), piped text and context files are appended as plain text and nothing in them runs.

### `/ruby`

The `/ruby` (`/rb`) directive evaluates Ruby inside aia with full privileges. It is off unless you start aia with `--allow-ruby-eval` or set `flags.allow_ruby_eval: true`. When it is off, using it prints an error and does nothing. When it is on, aia prints `WARNING: /ruby executing: …` to stderr every time.

Enable it only for sessions where you need it, never in a shared config file.

### Tools, libraries and plugins

Files given to `--tools`, gems given to `--require`, and files in the plugins directory are Ruby code that runs inside aia when it starts. Treat them like any program you install.

Tools are called by the model, not by you. A tool that writes files or runs commands can do so whenever the model decides to. To limit what the model can reach:

```bash
aia --chat --rq shared_tools --at read,search      # only tools whose names contain these
aia --chat --rq shared_tools --rt delete,shell,exec # everything except these
```

Matching is by substring, case-insensitive. Run `aia --list-tools` (with the same options) to see what is left. Note that the automatic tool filter (`-A`) chooses tools by relevance; it is not a security boundary.

## Tool approval

Tools from an MCP server marked `requires_approval: true` don't run until they're approved. The same rule covers an MCP server asking you for input. `tools.approval` (`--tool-approval`) decides what happens:

| Mode | Behavior |
|---|---|
| `ask` (default) | aia shows the tool and its arguments and asks `Allow it? [y/N]`. Anything but yes refuses. With no terminal (in a script or cron job), the call is refused. |
| `approve` | Every such call runs without asking. |
| `deny` | Every such call is refused. |

```yaml
mcp_servers:
  - name: github
    command: github-mcp-server
    args: ["stdio"]
    requires_approval: true
tools:
  approval: ask
```

Approval applies to every robot aia builds, including crew members and spawned specialists. It covers MCP servers marked `requires_approval:` and any tool whose author declared `requires_approval` in the tool itself. Other tools you load with `--tools` or `--require` run without asking, so restrict those with `--at` / `--rt`.

## MCP servers

- A **stdio** server (`command:`) is a program aia launches with your permissions. Install servers from sources you trust and pin their versions.
- A **remote** server (`url:`) receives your prompts' tool calls and whatever data they include.
- Expose only the tools you need with the server's `only:` / `except:` lists, and mark servers that can change things `requires_approval: true`.
- Use `--mcp-use NAMES` to connect only the servers a session needs, or `--no-mcp` to connect none.
- `aia --mcp-list --list-tools` shows exactly what each server offers before you use it.

See [MCP Servers](../extending/mcp.md).

## What leaves your machine

Everything in a request goes to the model provider: the prompt, roles and skills, context files, piped text, tool results and the conversation so far. If something must not leave your machine, use a [local model](../extending/local-models.md).

A few directives send data to other services:

- `/webpage URL` fetches the page through the pure.md service (and needs `PUREMD_API_KEY`).
- `/paste` puts your clipboard into the prompt — check what's on it.

## What aia writes to disk

| File | Contents | Control |
|---|---|---|
| `temp.md` in the current directory | Every response; in chat, your messages too | `-o FILE`, `--no-output`, `output.file: false` |
| `~/.prompts/_prompts.log` | Lines you type at the chat prompt | `--history-file FILE`, `--no-history-file` |
| Log files you configure | Activity; requests at `debug` level | `logger.*`, `--log-to` |

If you discuss sensitive material, turn the output and history files off or point them somewhere private.

## A short checklist

- [ ] API keys only in environment variables; `chmod 600` any config file that holds tokens.
- [ ] Read a prompt file, executable prompt or plugin before running one you didn't write.
- [ ] Don't pipe untrusted text into `aia` without a prompt ID.
- [ ] Leave `/ruby` off unless you need it this session.
- [ ] Restrict tools with `--at` / `--rt`; mark risky MCP servers `requires_approval: true`.
- [ ] Use `--tool-approval deny` for unattended runs that shouldn't change anything.
- [ ] Use a local model for data that must stay on your machine.

## See also

- [ERB & Shell](../prompts/erb-and-shell.md)
- [Tools](../extending/tools.md)
- [MCP Servers](../extending/mcp.md)
- [Environment Variables](environment.md)
