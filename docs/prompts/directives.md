# Directives

Directives are AIA's built-in commands. Some pull content into a prompt, such as a file, a web page or the clipboard. Others change settings, manage the conversation, or switch on a special mode for your next question. This page shows how to use them. Every directive is listed in the [Directives Reference](../reference/directives.md).

## Two ways to call a directive

A directive has the same name in both places, but you call it differently.

=== "In chat: /name"

    During a chat session, type a slash, the directive's name and any arguments on a line by themselves:

    ```text
    Follow up (cntl-D or 'exit' to end) #=>
    /temperature 0.2
    ```

    Arguments are split on spaces. Quotes don't group words.

=== "In a prompt file: ERB"

    Inside a prompt file, call the directive as an ERB tag. Put string arguments in quotes:

    ```markdown
    Summarize the article below in three bullet points.

    <%= webpage 'https://example.com/blog/release-notes' %>
    ```

    The directive's result replaces the tag before the prompt is sent.

Type `/help` in a chat session to list every directive with its aliases.

## What happens to a directive's output in chat

Directives fall into three groups, and each group behaves differently in chat:

| Kind | Examples | What happens |
|------|----------|--------------|
| **Content** | `/include`, `/insert`, `/webpage`, `/paste`, `/skill` | AIA prints the content and sends it to the model as part of the conversation, so you can ask about it next. |
| **Information and settings** | `/help`, `/tools`, `/config`, `/model`, `/review`, `/cost` | AIA prints the result or makes the change. Nothing is sent to the model. |
| **Next-prompt modes** | `/verify`, `/decompose`, `/debate`, `/spawn` | AIA confirms the mode. Your **next** message is handled in that mode, and then AIA returns to normal. |

Only one next-prompt mode can be active at a time. If you request a second one before your next message, it replaces the first.

If you type a slash command AIA doesn't know, it replies `Unknown directive: /foo  (use /help to see available directives)` and sends nothing to the model.

## A tour by category

### Composing prompts from other files

`include` and `insert` let you build prompts from reusable pieces.

| Directive | What you get |
|-----------|--------------|
| `include 'file'` | The file is processed as a prompt: shell expansion, ERB and parameters all apply. Included files can include other files. |
| `insert 'file'` (alias `read`) | The file's text exactly as it is. Nothing is processed. |

```markdown
---
parameters:
  code_file:
---
<%= include 'shared/review_guidelines.md' %>

Review this code:

<%= insert code_file %>
```

In a prompt file, paths are relative to the directory of the file that contains the tag. In chat, `/include notes.md` and `/insert notes.md` are relative to your current directory.

!!! note
    `include` needs to know which file it is in, so it works in prompt files in your prompts directory and in chat. Use `insert` in [executable prompts](executable-prompts.md) and in prompts piped on STDIN. If an include chain loops back to a file already being included, AIA stops with a circular-include error.

### Bringing in outside content

```text
/webpage https://ruby-lang.org/en/news/      # fetch a page as Markdown
/paste                                       # whatever is on your clipboard
/skill changelog                             # the text of a skill
/skills                                      # list the skills you have
```

`/webpage` (aliases `/website`, `/web`) uses the pure.md service, and needs the `PUREMD_API_KEY` environment variable set.

### Settings during a chat

```text
/model                     # show the current model(s)
/model claude-sonnet-4     # switch models and keep the conversation
/temperature 0.9           # also /temp
/top_p 0.5                 # also /topp
/config                    # show every setting
/config llm                # show one section
/config debug true         # change a setting
/cost                      # tokens and cost so far, as CSV
```

When you switch models with `/model`, the new model is given a summary of the conversation so far. In 2.0.0 this can't be changed (the `model_switch_history` setting isn't loaded); run `/clear` afterwards for a fresh start. See [Choosing Models](../everyday/models.md).

### Managing the conversation

```text
/checkpoint before_refactor   # save a named point (also /ckp, /cp)
/checkpoints                  # list saved points
/review                       # show the conversation with checkpoint markers
/restore before_refactor      # go back; later messages are discarded
/clear                        # forget everything except the system prompt
/clear --all                  # forget the system prompt too
```

`/restore` with no name goes back to the checkpoint before the most recent one. See [Chat Sessions](../everyday/chat.md).

### Special modes for the next prompt

```text
/verify
Is 2^61 - 1 prime?
```

The `/verify` directive above gets two independent answers and then reconciles them. Others in this group are `/decompose`, `/debate`, `/delegate`, `/concurrent`, `/orchestrate` and `/spawn`. The crew directives `/add_recruit`, `/drop_recruit` and `/reskill` manage a team of robots that you can address with `@name`. These are covered in [Advanced Modes](../extending/advanced-modes.md) and [Crews](../extending/crews.md).

### Looking around

```text
/help          # all directives
/tools         # tools the model can call; /tools file narrows the list
/mcp           # MCP servers: connected, failed, and their tools
/robots        # the active robot(s): model, cost per 1K tokens, tools, role
/models gpt    # models whose names contain "gpt" (-term excludes)
/plugins       # loaded plugin files
```

### Running code

```text
/ruby Date.today.cwday     # also /rb; needs --allow-ruby-eval
/say Build finished        # speak text aloud with the macOS say command
```

`/ruby` is off unless you start AIA with `--allow-ruby-eval`. See [ERB & Shell](erb-and-shell.md#running-ruby-in-chat-ruby).

## Which directives belong where

All directives can technically be called from both places, but most are designed for one of them:

- **In prompt files:** `include`, `insert`, `webpage`, `paste` and `skill`. These are the directives that return text.
- **In chat:** everything else. Settings belong in a prompt file's [front matter](prompt-files.md#front-matter-keys), not in a `/config` call inside ERB.

## Writing your own directive

A custom directive is a small Ruby file. Load it with `--tools`, the same option that loads tools:

```ruby
# ~/.prompts/tools/timestamp_directive.rb
module AIA
  class CustomDirectives < Directive
    desc "Insert current timestamp (optional strftime format)"
    def timestamp(args = [], context_manager = nil)
      format = args.empty? ? '%Y-%m-%d %H:%M:%S' : args.join(' ')
      Time.now.strftime(format)
    end
  end
end
```

```bash
aia --tools ~/.prompts/tools/timestamp_directive.rb --chat
```

Now `<%= timestamp %>` works in prompt files, and `/timestamp %Y-%m-%d` works in chat. The `desc` line is required. It registers the method as a directive and supplies its `/help` text. The `args` value is the list of words that follow the directive name.

For helper methods that only your ERB templates need, a [plugin](plugins.md) is simpler.

## See also

- [Directives Reference](../reference/directives.md): every directive, alias and argument
- [Chat Sessions](../everyday/chat.md): using directives interactively
- [ERB & Shell](erb-and-shell.md): the ERB that directives run inside
- [Plugins](plugins.md): your own helper methods for prompts
