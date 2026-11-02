# Plugins

A plugin is a Ruby file of helper methods and constants that you want every prompt to use. Put plugin files in your plugins directory, and AIA loads them at startup so their methods can be called from ERB in any prompt. During a chat session, AIA also reloads plugins as you edit them.

## Setting the plugins directory

AIA has no default plugins directory. Plugins load only after you set one. You can set it three ways. They are listed here from lowest to highest priority:

=== "Config file"

    ```yaml
    # ~/.config/aia/aia.yml
    paths:
      plugins_dir: ~/.prompts/plugins
    ```

=== "Environment variable"

    ```bash
    export AIA_PLUGINS_DIR=~/.prompts/plugins
    ```

=== "Command line"

    ```bash
    aia --plugins-dir ~/.prompts/plugins my_prompt
    ```

`~` is expanded. If the directory you name doesn't exist, AIA prints `Warning: configured plugins directory does not exist: ...` and runs without plugins.

!!! note "The environment variable name"
    The variable is `AIA_PLUGINS_DIR`, not the `AIA_PATHS__PLUGINS_DIR` form you might expect from the other `AIA_*` settings.

## What counts as a plugin

AIA loads every `*.rb` file **directly inside** the plugins directory. It doesn't look in subdirectories, so you can keep helper files or work in progress in a subfolder.

Each plugin file can define:

- **Top-level methods** (`def` outside any class or module)
- **Top-level constants**, classes and modules

```ruby
# ~/.prompts/plugins/project.rb

TEAM = "Platform"

def today
  Time.now.strftime("%A, %B %-d %Y")
end

def recent_commits(count = 10)
  `git log --oneline -#{count}`.chomp
end

def file_or_empty(path)
  File.exist?(path) ? File.read(path) : ""
end
```

## Using plugin methods in prompts

Plugin methods and constants are available in ERB tags in every prompt file:

```markdown
---
parameters:
  count: 5
---
Today is <%= today %>. Write a status update for the <%= TEAM %> team
based on these recent commits:

<%= recent_commits(count.to_i) %>
```

```bash
aia --plugins-dir ~/.prompts/plugins standup
```

AIA also renders chat input with ERB, so you can call plugin methods while you chat:

```text
Follow up (cntl-D or 'exit' to end) #=>
Summarize <%= recent_commits(3) %>
```

The same methods can be called from the `/ruby` directive when it is enabled with `--allow-ruby-eval`. See [ERB & Shell](erb-and-shell.md#running-ruby-in-chat-ruby).

!!! warning "Plugin methods take priority over parameter names"
    If a plugin defines a method with the same name as one of a prompt's parameters, `<%= name %>` calls the plugin method and the parameter value is never used. The same applies to directives: a plugin method named `include` or `webpage` replaces that directive inside ERB. Give plugin methods distinctive names.

## Checking what is loaded

In a chat session, the `/plugins` directive lists the loaded plugins by file name (without `.rb`):

```text
Follow up (cntl-D or 'exit' to end) #=>
/plugins

Loaded Plugins
==============
project
```

If nothing is loaded, it prints `No plugins are loaded`.

## Live reload during chat

When you start AIA with `--chat`, AIA watches the plugins directory for the whole session and applies changes as you save them:

| You... | AIA... | Message (on STDERR) |
|--------|--------|---------------------|
| add a new `*.rb` file | loads it | `Plugin loaded: name` |
| save changes to a plugin | removes everything the old version defined, then loads the new version | `Plugin reloaded: name` |
| delete a plugin file | removes the methods and constants it defined | `Plugin unloaded: name` |

Because AIA removes the old definitions before it reloads a file, a method you rename or delete in a plugin stops working right away and doesn't linger under its old name.

AIA uses native file system events to notice changes, so they show up almost instantly. If file events aren't available, it checks the directory once per second instead.

Live reload only runs in chat mode. In a normal one-shot run, AIA loads plugins once at startup.

## When a plugin fails to load

If a plugin raises an error or has a syntax error while loading, AIA prints a warning and continues without it:

```text
Warning: Failed to load plugin '/Users/you/.prompts/plugins/project.rb': undefined local variable or method 'tody' for main
```

The other plugins still load. In chat mode, fix the file and save it, and AIA tries to load it again.

!!! danger "Plugins run as you"
    A plugin is ordinary Ruby that runs inside AIA with your user's permissions. It runs every time AIA starts. Only put files you wrote or trust in the plugins directory. See [Security](../configuration/security.md).

## Plugins compared with tools and directives

| You want... | Use |
|-------------|-----|
| Helper methods or constants for your own prompt templates | A plugin |
| Something the **model** can decide to call while it answers | A [tool](../extending/tools.md) |
| A `/command` you type in chat | A [directive](directives.md) |

## See also

- [ERB & Shell](erb-and-shell.md): where plugin methods are used
- [Parameters](parameters.md): prompt inputs and how names are resolved
- [Config Keys](../reference/config-keys.md): `paths.plugins_dir`
- [CLI Options](../reference/cli.md): `--plugins-dir`
