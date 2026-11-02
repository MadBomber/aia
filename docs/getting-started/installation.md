# Installation

This page gets AIA installed, connected to at least one model provider, and ready to run your first prompt. It takes about five minutes.

## What you need

| Requirement | Notes |
|-------------|-------|
| **Ruby 4.0.9 or later** | AIA 2.0 will not install on older Rubies. Check with `ruby --version`. |
| **An API key** for at least one provider | OpenAI, Anthropic, Google Gemini, and others. Or a local model server (Ollama, LM Studio) and no key at all. |
| **fzf** *(optional)* | Needed only for fuzzy prompt search (`aia --fuzzy`). |

!!! tip "Managing Ruby versions"
    If your system Ruby is older than 4.0.9, install a newer one with a version manager such as `rbenv`, `asdf`, `mise` or `chruby`. AIA does not need system-wide Ruby.

## Install the gem

```bash
gem install aia
```

Check that it worked:

```bash
aia --version
```

```text
2.0.0
```

## Connect a model provider

AIA reads provider API keys from environment variables. Set the one(s) for the providers you plan to use, in your `~/.bashrc`, `~/.zshrc` or equivalent:

```bash
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="..."
```

AIA also recognizes `DEEPSEEK_API_KEY`, `MISTRAL_API_KEY`, `PERPLEXITY_API_KEY`, `OPENROUTER_API_KEY`, `XAI_API_KEY` and `GPUSTACK_API_KEY`, the AWS variables for Bedrock (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_SESSION_TOKEN`), and `GOOGLE_CLOUD_PROJECT` / `GOOGLE_CLOUD_LOCATION` for Vertex AI.

To see which providers AIA knows about and which of them have a key:

```bash
aia --list-providers
```

```text
Registered RubyLLM providers:
------------------------------------------------------------
- anthropic (has API key)
- gemini
- ollama (local)
- openai (has API key)
...
```

!!! note "The default model"
    Out of the box AIA uses OpenAI's `gpt-4o-mini`, so it needs `OPENAI_API_KEY`. If you use a different provider, either pass `--model` every time or set your own default in the config file (below). See [Choosing Models](../everyday/models.md).

!!! warning "Keep keys out of prompts and config files you share"
    Environment variables are the safest place for keys. See [Security](../configuration/security.md).

## Create your prompts directory

AIA looks for prompts in `~/.prompts`. Create it, along with a folder for roles:

```bash
mkdir -p ~/.prompts/roles
```

If you'd rather keep prompts somewhere else (a git repository, a synced folder), point AIA at it:

```bash
export AIA_PROMPTS__DIR=~/Documents/prompts
```

or use `--prompts-dir DIR` on the command line, or set `prompts.dir` in the config file.

## Create a config file (optional)

You don't need a config file. AIA has sensible built-in defaults. When you want to change one permanently, create `~/.config/aia/aia.yml`. A small starting point:

```yaml
# ~/.config/aia/aia.yml
models:
  - name: claude-sonnet-4-5

prompts:
  dir: ~/.prompts

output:
  file: ~          # don't write responses to ./temp.md
```

!!! tip "Why `output.file: ~`?"
    By default AIA also writes every response to a file named `temp.md` in the current directory. Setting `output.file` to `~` (YAML for "nothing") turns that off. See [Output, History and Usage](../everyday/output-and-history.md).

You can capture the full set of settings AIA is using into a file to see what's available:

```bash
aia --dump my_settings.yml
```

Every key is described in the [Configuration Keys reference](../reference/config-keys.md).

## Shell completion (optional)

AIA can complete prompt IDs when you press ++tab++. It ships completion scripts for bash, zsh and fish:

=== "bash"

    ```bash
    aia --completion bash > ~/.aia_completion.bash
    echo 'source ~/.aia_completion.bash' >> ~/.bashrc
    ```

=== "zsh"

    ```bash
    aia --completion zsh > ~/.aia_completion.zsh
    echo 'source ~/.aia_completion.zsh' >> ~/.zshrc
    ```

=== "fish"

    ```bash
    aia --completion fish > ~/.config/fish/completions/aia.fish
    ```

The completion scripts read your prompts directory from `AIA_PROMPTS__DIR`, so export it even if you use the default:

```bash
export AIA_PROMPTS__DIR=~/.prompts
```

## Install fzf (optional)

[fzf](https://github.com/junegunn/fzf) lets you pick a prompt from a searchable list with a preview pane:

```bash
brew install fzf          # macOS
sudo apt install fzf      # Debian / Ubuntu
```

Then run `aia --fuzzy` (or `aia -f`). If fzf isn't installed, AIA tells you so and exits.

## Check that everything works

```bash
echo "Reply with the single word: ready" | aia --no-output
```

```text
AI: 
   **Tobor** (0.8s):
   ready
```

If you see a response, you're done. If not:

| Symptom | Likely cause |
|---------|--------------|
| `invalid option` | A typo in an option, or an option removed in 2.0. Run `aia --help`. |
| An authentication / API key error | The key for the model's provider isn't set in this shell. Run `aia --list-providers`. |
| `aia: command not found` | The gem's bin directory isn't on your `PATH`. Run `gem environment` and check `EXECUTABLE DIRECTORY`. |

More fixes are in the [FAQ and troubleshooting](../reference/faq.md) page.

## Upgrading from AIA 1.x

AIA 2.0 is not a drop-in replacement for 1.x. Removed options, changed defaults and the new tool format are listed in [Upgrading to 2.0](../appendix/upgrading-2.0.md). Older prompt files may need [migrating](../appendix/migrating-prompts.md).

## Next steps

- [Quick Tour](quick-tour.md): see the main features in ten minutes
- [Your First Prompt](first-prompt.md): write and run a prompt file
- [Config File](../configuration/config-file.md): make your settings permanent
