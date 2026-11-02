# ERB & Shell

Prompt files can hold dynamic content. Shell references such as `$(git status)` are replaced with command output, and ERB tags such as `<%= Date.today %>` are replaced with the result of Ruby code. Both are on by default.

## Shell expansion

| You write | AIA puts in its place |
|-----------|----------------------|
| `$HOME`, `${HOME}` | The environment variable's value, or nothing if it isn't set |
| `$(command)` | The command's standard output, with the trailing newline removed |
| `\$` | A literal `$` |

```markdown
I am working in $(pwd) on branch $(git branch --show-current).
My editor is $EDITOR.

Here is what changed since yesterday:

$(git log --since=yesterday --oneline)
```

A few rules keep shell expansion predictable:

- **Only uppercase names are variables.** `$HOME` and `$MY_TOKEN` are expanded. `$price`, `$5` and `$foo` are left as they are, so dollar amounts in your text are safe.
- **Fenced code blocks are left alone.** Anything between ```` ``` ```` or `~~~` fences reaches the model exactly as written. That way you can show the model a shell example without running it.
- **Command output is not expanded again.** If a command prints `$HOME` or `<%= ... %>`, that text reaches the model literally. Output can't trigger more expansion or inject Ruby.
- **A failing command stops the run.** If a `$(...)` command exits with a non-zero status, AIA stops and reports the command and its error output. Append `|| true` to a command if failure is acceptable: `$(grep TODO *.rb || true)`.
- **An unmatched `$(` is an error.** Escape a literal one as `\$(`.

## ERB

ERB is Ruby's template language. AIA renders every prompt file with ERB after shell expansion.

| Tag | Meaning |
|-----|---------|
| `<%= expression %>` | Insert the result of the expression |
| `<% code %>` | Run code without inserting anything (use it for `if`, `each` and similar) |
| `<%# comment %>` | A comment that never reaches the model |

```markdown
Today is <%= Date.today.strftime('%A, %B %-d') %>.

The project has <%= Dir.glob('lib/**/*.rb').size %> Ruby files:
<% Dir.glob('lib/**/*.rb').first(5).each do |f| %>
- <%= f %>
<% end %>

Ruby version: <%= RUBY_VERSION %>
```

Inside ERB you can use:

- [Parameters](parameters.md): `<%= name %>`
- [Directives](directives.md): `<%= include 'shared/header.md' %>`, `<%= webpage 'https://...' %>`
- [Plugins](plugins.md): your own helper methods and constants, loaded from the plugins directory
- Any Ruby code, including backticks: `` <%= `git rev-parse --short HEAD`.strip %> ``

## Shell runs first, then ERB

Shell expansion happens before ERB, so Ruby code can work on shell output:

```markdown
My OS is <%= "$(uname -s)".downcase %>.
My shell is <%= "$SHELL".split('/').last %>.
```

1. Shell expansion produces `My OS is <%= "Darwin".downcase %>.`
2. ERB produces `My OS is darwin.`

Put shell output inside quotes when you use it in Ruby, as shown above.

## Loading Ruby libraries with --require

ERB can already use the libraries AIA itself loads, such as `Date` and `JSON`. To use any other standard library or installed gem in your ERB, load it with `--require` (short form `--rq`). Separate several libraries with commas:

```markdown
<!-- ~/.prompts/sales_summary.md -->
Summarize these sales figures by region:

<% CSV.foreach('sales.csv', headers: true) do |row| %>
- <%= row['region'] %>: <%= row['total'] %>
<% end %>
```

```bash
aia --rq csv sales_summary
```

To load a library every time, list it in your config file:

```yaml
# ~/.config/aia/aia.yml
require_libs:
  - json
  - csv
```

If a library can't be loaded, AIA prints `Warning: Failed to require 'name'` and keeps going. The first ERB tag that needs the library then fails.

## Turning processing off for one file

Some prompts contain text that looks like shell or ERB but isn't. Examples are a prompt about writing ERB templates, or one that discusses `$(...)` syntax. Turn off the stage you don't want in that file's front matter:

```markdown
---
erb: false     # <%= ... %> is sent literally
shell: false   # $VAR and $(...) are sent literally
---
Explain what this ERB template does:

<%= render partial: 'user', collection: @users %>
```

Both settings default to `true`. Each one affects only the file it appears in.

## Chat input is processed too

Every message you type in a chat session goes through shell expansion and ERB too. You can type:

```text
Follow up (cntl-D or 'exit' to end) #=>
Explain the failures in this output: $(bundle exec rake test 2>&1 | tail -20)
```

To send a literal `$(` or `<%`, escape the dollar sign as `\$(`, or rephrase. If a message can't be processed, AIA shows the error and doesn't send the message.

## Running Ruby in chat: /ruby

The `/ruby` directive (alias `/rb`) runs a line of Ruby and sends the result to the model:

```text
Follow up (cntl-D or 'exit' to end) #=>
/ruby (1..20).select(&:even?).sum
```

`/ruby` is **off by default**. Turn it on for one session with `--allow-ruby-eval`:

```bash
aia --chat --allow-ruby-eval
```

or for every session in your config file:

```yaml
flags:
  allow_ruby_eval: true
```

While it's off, `/ruby` only prints an error message. While it's on, AIA prints `WARNING: /ruby executing: ...` to STDERR before running the code. If the code raises an error, the error message is sent to the model in place of a result.

## Security

!!! danger "Prompts are programs"
    ERB, backticks and `$(...)` in a prompt file run with your user's permissions as soon as the prompt is rendered. `--allow-ruby-eval` doesn't control them. It only controls the `/ruby` chat directive. Read any prompt file you didn't write before you run it, and don't render prompts from untrusted sources. See [Security](../configuration/security.md).

## See also

- [Parameters](parameters.md): values for your ERB tags
- [Plugins](plugins.md): reusable helper methods for ERB
- [Directives](directives.md): `include`, `insert` and other built-ins
- [Executable Prompts](executable-prompts.md): prompts you run like scripts
