# MCP Servers

The [Model Context Protocol](https://modelcontextprotocol.io) (MCP) is a standard way for programs to offer tools to an AI. Connect AIA to an MCP server, such as a filesystem server, a GitHub server or a database server, and the model can call that server's tools just like [local tools](tools.md).

AIA supports MCP servers that run as a local process (**stdio**) and servers you reach over HTTP (**Streamable HTTP**). The older SSE and WebSocket transports aren't supported.

## Configuring a server in your config file

List servers under `mcp_servers` in `~/.config/aia/aia.yml` (or in any file you pass with `-c`):

```yaml
mcp_servers:
  - name: filesystem
    command: npx
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"]
    timeout: 10000
```

Every server you configure is connected at startup, so its tools are available in every session.

| Key | Meaning |
|-----|---------|
| `name` | The name you use with `--mcp-use`, `--mcp-skip` and `/mcp` |
| `command`, `args` | The program to start, for stdio servers |
| `env` | Extra environment variables for the server process, such as API tokens |
| `cwd` (or `directory`) | Working directory for the server process |
| `url` | The endpoint of an HTTP server. If you give a `url`, the server uses Streamable HTTP |
| `headers`, `bearer_token`, `oauth` | Authentication for HTTP servers |
| `timeout` | How long to wait for the server to connect (see below) |
| `prefix` | A prefix added to every tool name from this server |
| `only`, `except` | Lists of tool names to keep or drop from this server |
| `requires_approval` | Make tool calls wait for your approval (see below) |
| `group` | Concurrency grouping (see [Running servers concurrently](#running-servers-concurrently)) |

An HTTP server with a token:

```yaml
mcp_servers:
  - name: tracker
    url: https://mcp.example.com/mcp
    headers:
      Authorization: "Bearer <your-token>"
```

### Timeouts

`timeout` sets how long AIA waits for one server to connect and report its tools. Values of **1000 or more are milliseconds** and smaller values are seconds, so `10000` and `10` both mean ten seconds. Without a timeout, a server gets 30 seconds.

All servers connect at the same time. The whole connection phase is also capped by `concurrency.mcp_timeout` (default 120 seconds), but never at less than your slowest server's own timeout. Servers started with `npx` or `uvx` can be slow the first time they download, so give them a generous timeout.

## Loading servers from a JSON file

`--mcp FILE` reads servers from a JSON file in the format used by Claude Desktop and VS Code. You can repeat it, and the servers are added to the ones in your config file:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "./docs"],
      "timeout": 10000
    }
  }
}
```

```bash
aia --mcp ~/mcp/filesystem.json --chat
aia --mcp github.json --mcp postgres.json my_prompt
```

A file without an `mcpServers` key is read as one server, named after the file: `{"command": "my-server", "args": ["--stdio"]}`. Here `command` may also be an array whose first element is the program.

!!! note "What JSON files carry"
    From a JSON file AIA reads `command`, `args`, `env`, `url`, `headers`, `type`, `timeout` and `group`. Settings such as `prefix`, `only`, `except` and `requires_approval` are read only from the YAML config file, so put servers that need them there.

## Choosing servers for a session

| Option | Effect |
|--------|--------|
| `--mcp-use NAMES` (`--mu`) | Connect only the named servers (comma-separated, repeatable) |
| `--mcp-skip NAMES` (`--ms`) | Connect every server except these |
| `--no-mcp` | Connect no MCP servers at all |
| `--mcp-list` | List the configured servers and exit |

```bash
aia --mcp-use filesystem,github --chat
aia --mcp-skip postgres my_prompt
aia --no-mcp quick_question
```

If a name given to `--mcp-use` doesn't match any configured server, AIA warns you and lists the names it knows:

```text
WARNING: --mcp-use specified server(s) not found in config: githb
         Available servers: filesystem, github
```

`--mcp-list` shows what's configured, after `--mcp-use` and `--mcp-skip` are applied:

```text
$ aia --mcp-list
Configured MCP servers:

  filesystem
    command: npx -y @modelcontextprotocol/server-filesystem /Users/me/projects
```

To see each server's **tools**, add `--list-tools`:

```bash
aia --list-tools --mcp-list
```

The config file equivalents are `mcp_use`, `mcp_skip` and `flags.no_mcp`.

## What happens at startup

AIA starts every selected server at once and shows a spinner line for each:

```text
[✔] Connecting MCP servers
  [✔] filesystem (14 tools)
  [✖] github (timed out)
```

A server that fails to connect is left out for the rest of the session, so AIA doesn't keep retrying it. Everything else carries on normally.

Inside a chat, `/mcp` shows the status of every server and the tools it offers:

```text
> /mcp

MCP Server Status
=================
Defined: 2  Connected: 1  Failed: 1

Connected Servers:
  filesystem (14 tools)
    - read_file
    - list_directory
    ...

Failed Servers:
  github: timed out after 10.0s
```

Every robot in the session shares the same server connections, including [crew members](crews.md) you recruit. Each server process starts only once.

## Requiring approval

To make a server's tool calls wait for your OK, set `requires_approval` in the YAML config:

```yaml
mcp_servers:
  - name: filesystem
    command: npx
    args: ["-y", "@modelcontextprotocol/server-filesystem", "."]
    requires_approval: true                     # every tool
  - name: github
    command: github-mcp-server
    args: ["stdio"]
    requires_approval: [create_issue, merge_pull_request]   # only these tools
```

What happens next depends on `--tool-approval` (`ask`, `approve` or `deny`). [Tools: approval](tools.md#tools-that-need-your-approval) explains the modes. In the same way, AIA asks you on the terminal when a server needs input from you, such as a value or a URL to visit.

## Two servers with the same tool name

Two tools can't share a name. When a server offers a tool with the same name as one from a server that's already connected, the second server is marked failed:

```text
github: tool 'search' is also offered by 'gitlab'; give one server a prefix:
```

Fix this by giving one of the servers a `prefix`:

```yaml
  - name: gitlab
    command: gitlab-mcp
    prefix: gitlab
```

## Running servers concurrently

When a question needs tools from several unrelated servers, AIA can split the work. One robot works with each group of servers, all at the same time, and a final robot merges their results.

- **In a chat**, type `/concurrent` (or `/conc`) before your next message. That message is handled this way.
- **For prompts run from the command line**, add `--concurrent-auto`, or set `concurrency.auto: true` in your config.

This happens only when there's more than one server. Servers that share the same `group` value stay together in one robot, and every server without a `group` gets its own. With `--concurrent-auto`, AIA splits the work only when there are at least `concurrency.threshold` groups (default 2). Otherwise the prompt runs normally.

```yaml
mcp_servers:
  - name: github
    command: github-mcp-server
    args: ["stdio"]
  - name: postgres
    command: postgres-mcp
    group: data
  - name: redis
    command: redis-mcp
    group: data          # runs together with postgres
concurrency:
  auto: true
  threshold: 2
  mcp_timeout: 120
```

## Troubleshooting

- **A server shows `(timed out)`.** Raise its `timeout`. The first `npx -y ...` run downloads the package and can take a while. Running the command yourself in a terminal shows whether it starts at all.
- **A server shows an error message.** Check `command`, `args` and `env`. The message is the error the server reported. Run with `--log-level debug` (or `-d`) for connection details. MCP activity goes to the MCP log; see [Configuration keys](../reference/config-keys.md) for `logger.mcp`.
- **`--mcp-use` gives no tools.** Check the warning about names that weren't found. Server names are case-sensitive.
- **The model ignores a server's tools in chat.** AIA's [automatic tool filter](tools.md#automatic-tool-filtering-in-chat) may not have matched your message to them. Mention what you want done more explicitly, or turn the filter off with `--no-auto-tool-filter`.
- **Too many tools.** Use `only:`/`except:` on the server, or `--allowed-tools`/`--rejected-tools`.

## See also

- [Tools](tools.md)
- [Advanced Modes](advanced-modes.md)
- [Security](../configuration/security.md)
- [CLI reference](../reference/cli.md)
