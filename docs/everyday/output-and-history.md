# Output, History and Usage

Where AIA's answers go, what it remembers between sessions, how to see token counts and costs, and how to turn on logging when something goes wrong.

## The output file

Besides printing each answer, AIA appends it to an **output file**. Out of the box that file is **`temp.md` in your current directory**.

- At the start of each run, AIA **empties** the output file (unless you ask it to append, below).
- Each answer is written after an `AI:` label. In chat mode, each of your messages is written too, after `You:`, so the file becomes a transcript.
- Token and cost tables from `--tokens` / `--cost`, and the CSV from `/cost`, are written there as well.

```markdown title="temp.md after a short chat"
AI: **Tobor** (2.4s):
Here's a summary of the report...

You: Which section has the most risk?

AI: Section 4, the vendor migration...
```

### Choosing where output goes

| You want… | Do this |
|-----------|---------|
| A specific file | `--output notes/answer.md` (`-o`). Relative paths are relative to where you run AIA. |
| The default `temp.md` | `-o` with no file name |
| No output file at all | `--no-output` |
| To add to the file instead of replacing it | `--append` (`-a`); `--no-append` to switch it back off |
| No output file, ever | `output.file: ~` in your config file |
| To always append | `output.append: true` in your config file |

```yaml
# ~/.config/aia/aia.yml
output:
  file: ~          # stop writing ./temp.md
```

!!! tip "Keep a running journal"
    `aia --chat -a -o ~/journal/ai.md` appends every chat to the same file, giving you a searchable log of everything you've asked.

When you [generate an image](../extending/images-and-speech.md) with `--paint`, the image is saved next to the output file with a `.png` extension (`temp.md` becomes `temp.png`).

## Chat input history

AIA remembers the lines you type in [chat](chat.md), so ++up++ and ++down++ bring back earlier messages, even from previous sessions. It keeps the last **50** entries.

| Setting | Default |
|---------|---------|
| `output.history_file` | `~/.prompts/_prompts.log` |

```bash
aia --chat --history-file ~/.config/aia/work_history    # use another file
aia --chat --no-history-file                            # don't save input history
```

If the history file grows beyond 10 MB, AIA renames it to `<file>.1` at the start of a session and starts a fresh one, printing `History log rotated: …`.

!!! note
    The history file holds what *you* typed, not the model's answers. For a record of the whole conversation, use the [output file](#the-output-file).

## Token counts and time: `--tokens`

```bash
aia --tokens summarize report.txt
```

After each answer AIA shows how many tokens went in and came out, and how long the answer took:

```text
┌─────────────┬───────┬────────┬───────┬──────┐
│ Model       │ Input │ Output │ Total │ Time │
├─────────────┼───────┼────────┼───────┼──────┤
│ gpt-4o-mini │  1843 │    212 │  2055 │ 2.3s │
└─────────────┴───────┴────────┴───────┴──────┘
```

That compact table is what you see after each chat turn. When you run a prompt without `--chat`, the same figures appear under a **Multi-Model Token Usage** heading with a `TOTAL` row, even for one model, because one-shot runs go through AIA's robot network.

Input tokens include everything sent: the role, the prompt, skills, piped text, context files and, in chat, the conversation so far. If a request is bigger than you expected, this is where you'll see it.

## Cost: `--cost`

`--cost` does everything `--tokens` does and adds what the answer cost, plus what 1,000 answers like it would cost:

```text
┌─────────────┬───────┬────────┬───────┬──────────┬───────┬──────┐
│ Model       │ Input │ Output │ Total │ Cost     │ x1000 │ Time │
├─────────────┼───────┼────────┼───────┼──────────┼───────┼──────┤
│ gpt-4o-mini │  1843 │    212 │  2055 │ $0.00040 │ $0.40 │ 2.3s │
└─────────────┴───────┴────────┴───────┴──────────┴───────┴──────┘
```

Prices come from the RubyLLM model catalog. When a model has no price listed (local models, very new models), the cost shows `N/A`.

With [several models](../extending/multi-model.md), you get one row per model under a **Multi-Model Token Usage** heading, plus a `TOTAL` row. Time in the total row is the slowest model's, because the models run in parallel.

### A whole session as CSV: `/cost`

In a chat, `/cost` prints one CSV row per turn so far, plus a totals row, with the columns `model,input_tokens,output_tokens,total_tokens,cost,elapsed`. The CSV is also appended to the output file, so it's easy to pull into a spreadsheet.

## Logging and debugging

AIA has three logs:

| Log | Records |
|-----|---------|
| `aia` | AIA's own activity, including the full configuration at startup (at debug level) |
| `llm` | Requests to and responses from model providers |
| `mcp` | Connections to [MCP servers](../extending/mcp.md) |

By default all three go to standard output and only show warnings and errors.

| Option | Effect |
|--------|--------|
| `--log-level LEVEL` | Set every log to `debug`, `info`, `warn`, `error` or `fatal` |
| `-d`, `--debug` | Shortcut for `--log-level debug` |
| `--no-debug` | Turn debug off again (handy when your config file turns it on) |
| `--log-to FILE` | Send all three logs to `FILE` instead of the terminal |
| `-v`, `--verbose` | Show extra detail, such as which tools were picked for each chat turn |

```bash
aia --debug --log-to /tmp/aia.log summarize report.txt
tail -f /tmp/aia.log            # in another terminal
```

Log files roll over daily. To set each log separately, use the `logger` section of the config file:

```yaml
# ~/.config/aia/aia.yml
logger:
  aia:
    file: ~/.config/aia/logs/aia.log
    level: info
  llm:
    file: ~/.config/aia/logs/llm.log
    level: debug
  mcp:
    file: STDERR
    level: warn
```

`file` can be a path, `STDOUT` or `STDERR`. `--log-level` and `--log-to` override these settings for one run. In a chat you can change log levels on the fly with `/config`, for example `/config logger.llm.level debug`.

## Saving your settings

`--dump FILE` writes the configuration AIA would use (after your config file, environment variables and command-line options are combined) to a YAML file, then exits:

```bash
aia --model claude-sonnet-4-5 -t 0.3 --dump current.yml
```

That's a quick way to check what a combination of settings resolves to, or to start a new config file. The file must end in `.yml` or `.yaml`. See [Config File](../configuration/config-file.md).

## See also

- [Chat Sessions](chat.md)
- [Context Files and Piping](context-and-piping.md): sending answers to other programs
- [Config File](../configuration/config-file.md)
- [Reference: Configuration Keys](../reference/config-keys.md)
