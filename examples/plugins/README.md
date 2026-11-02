# AIA Plugins

A plugin is any `*.rb` file placed directly in the configured plugins
directory. At startup `AIA::PluginLoader` loads every one of them, and while
a session is running `AIA::PluginMonitor` watches the directory — edit a
plugin and it hot-reloads before your next prompt; delete one and its
definitions are cleanly removed from the running process. No restart needed.

## Pointing AIA at a plugins directory

There is no default plugins directory — you opt in with any one of:

```bash
aia --plugins-dir path/to/plugins ...          # CLI flag
export AIA_PLUGINS_DIR=path/to/plugins         # environment variable
```

```yaml
# ~/.aia/config.yml
paths:
  plugins_dir: /path/to/plugins
```

This repo's `.envrc` points `AIA_PLUGINS_DIR` at this directory, so running
`bin/aia` from the checkout loads all of these examples automatically.

## Three kinds of plugin

**1. LLM tools** — subclass `RubyLLM::Tool`, declare `description` and
`parameter`s, implement `execute`. The model can call these as function
tools during a chat. (Requires ruby_llm >= 2.0 — the DSL is
`parameter`/`description:`, not the 1.x `param`/`desc:`.)

**2. Prompt/ERB helpers** — plain top-level `def` methods. They become
available inside prompt templates via ERB (`<%= git_context %>`) and to the
`/ruby` directive. Top-level methods and constants are exactly what the
loader tracks for clean reload/unload.

**3. Slash directives** — subclass `AIA::Directive`, use the `desc`/method
pattern, and call `YourDirective.register_all` at the bottom of the file.
The method name becomes the slash command (`/joke`).

## The example plugins

| File | Kind | What it does |
|------|------|--------------|
| `cli_help_analyzer_tool.rb` | LLM tool | Reads a CLI utility's `--help` output and infers a draft tool schema — option candidates, positional args, proposed class names. Can even generate a draft RubyLLM tool plugin file for the command. |
| `foo.rb` | ERB helper | Minimal "hello world" of plugins: one top-level `foo` method that prints a banner. Handy for watching the hot-reload cycle work. |
| `git_context.rb` | ERB helper | `<%= git_context %>` injects the current branch, recent commits, and dirty files into a prompt; `git_context(commits: 10, diff: true)` adds the working-tree diff. Gives the model real repo context for commit messages and reviews. |
| `joke.rb` | Slash directive | `/joke` tells a random joke; `/joke dad`, `/joke pirate`, `/joke programming` pick a flavor. The reference example for directive plugins. |
| `jq_tool.rb` | LLM tool | Runs `jq` safely for JSON querying/transformation: filter, inline text or input file, and read-oriented flags (raw, slurp, null-input, compact, sort-keys). |
| `list_ruby_methods_tool.rb` | LLM tool | Recursively scans Ruby source and lists method definitions grouped by file, with line numbers and instance/class classification. Codebase inventory without shelling out. |
| `memory_tool.rb` | LLM tool | Long-term key/value memory backed by `RobotLab::Memory` (Redis when available, in-session Hash otherwise). Semantic search via robot_lab-document_store when loaded; substring search fallback. Actions: put, get, delete, list, search. |
| `quick_file_tool.rb` | ERB helper | `<%= quick_file_tool('README.md') %>` inlines a file into a prompt; `lines: '1-40'` selects a numbered range. Read-only. |
| `search_files_tool.rb` | LLM tool | Recursive code/text search via `ag` (The Silver Searcher) with stable, parseable output: paths, line numbers, matching lines. Read-only. |
| `search_replace_tool.rb` | LLM tool | Controlled search-and-replace on a single file: exact text by default, optional regex mode, replace-first vs replace-all, and dry-run preview. |

## Writing your own

Start from the nearest example above. Keep each plugin self-contained in one
file, require what it needs at the top, and prefer read-only behavior unless
the tool's whole point is modification (then offer a `dry_run`). While
iterating, leave `bin/aia --chat` running — the plugin monitor reports each
reload to stderr as you save.
