# Environment Variables

Environment variables let you set aia's options per shell, per project (with a tool like direnv) or per command, without touching a config file. They also carry your provider API keys.

## Setting any config key: `AIA_*`

Every key in the configuration can be set with an environment variable. Take the key's dotted path, write it in capitals, join the levels with `__` (two underscores), and put `AIA_` in front:

| Config key | Environment variable |
|---|---|
| `llm.temperature` | `AIA_LLM__TEMPERATURE` |
| `prompts.dir` | `AIA_PROMPTS__DIR` |
| `output.file` | `AIA_OUTPUT__FILE` |
| `flags.tokens` | `AIA_FLAGS__TOKENS` |
| `logger.llm.level` | `AIA_LOGGER__LLM__LEVEL` |
| `require_libs` | `AIA_REQUIRE_LIBS` |

[Configuration Keys](../reference/config-keys.md) lists the variable for every key.

```bash
# for one command
AIA_OUTPUT__FILE=dates.md aia extract_dates contract.txt

# for the rest of the shell session
export AIA_PROMPTS__DIR=~/work/prompts
export AIA_SKILLS__DIR=~/work/prompts/skills
```

Environment variables override your config file and are overridden by command-line options. See [Configuration Precedence](precedence.md).

!!! note "How values are read"
    Environment values are text, so aia converts each one to the type of the setting it controls:

    - **On/off settings** accept `true`, `yes`, `on`, `1` and `false`, `no`, `off`, `0` (any case): `AIA_FLAGS__TOKENS=false`.
    - **Numbers** are converted: `AIA_LLM__TEMPERATURE=0.2`, `AIA_LLM__MAX_TOKENS=800`.
    - **Lists** are split on commas: `AIA_TOOLS__ALLOWED=read,write`, `AIA_TOOLS__PATHS=~/tools/a.rb,~/tools/b.rb`, `AIA_REQUIRE_LIBS=shared_tools,json`.

    A value that doesn't fit (for example `AIA_LLM__MAX_TOKENS=lots`) is kept as text, and the setting may then not work. Run `aia --dump check.yml` to see exactly what aia made of your variables.

## Variables with special handling

### `AIA_MODEL`

The model or models to use, in the same form as `-m`:

```bash
export AIA_MODEL=claude-haiku-4-5
export AIA_MODEL="gpt-4o,claude-sonnet-4-6"       # run both
export AIA_MODEL="gpt-4o=architect,gpt-4o=critic" # same model, two roles
export AIA_MODEL=ollama/llama3.2                  # provider prefix
```

`-m` on the command line wins over `AIA_MODEL`. `AIA_MODEL` also wins over the `models:` in a file given with `-c`.

### `AIA_PLUGINS_DIR`

The plugins directory (config key `paths.plugins_dir`). Note the name: it is `AIA_PLUGINS_DIR`, not `AIA_PATHS__PLUGINS_DIR`. `--plugins-dir` wins over it. Like `AIA_MODEL`, it still applies when you use `-c`. See [Plugins](../prompts/plugins.md).

```bash
export AIA_PLUGINS_DIR=~/.config/aia/plugins
```

### `AIA_PROMPTS__DIR` and `AIA_PROMPTS__ROLES_PREFIX`

These set `prompts.dir` and `prompts.roles_prefix` like any other variable. `AIA_PROMPTS__DIR` matters in one more place: the shell completion scripts from `aia --completion` read it directly, because they run in your shell and can't read the config file. They fall back to `~/.prompts` when it is unset. If you keep prompts somewhere other than `~/.prompts` and want completion, export `AIA_PROMPTS__DIR` rather than setting `prompts.dir` only in the config file.

### `AIA_SKILLS__DIR`

Sets `skills.dir`. Its default, `~/.prompts/skills`, does not follow `AIA_PROMPTS__DIR`, so if you move your prompts and keep skills beside them, set both.

## Provider API keys

Keys use each provider's usual variable name. Set the ones for the providers you use:

| Provider | Variable(s) |
|---|---|
| OpenAI | `OPENAI_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |
| Google Gemini | `GEMINI_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| Mistral | `MISTRAL_API_KEY` |
| Perplexity | `PERPLEXITY_API_KEY` |
| OpenRouter | `OPENROUTER_API_KEY` |
| xAI | `XAI_API_KEY` |
| GPUStack | `GPUSTACK_API_KEY` |
| AWS Bedrock | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_SESSION_TOKEN` |
| Google Vertex AI | `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` |

The default model, `gpt-4o-mini`, needs `OPENAI_API_KEY`. Local providers such as Ollama and LM Studio need no key.

`aia --list-providers` marks each provider that has a key with `(has API key)`; for that check aia looks for `<PROVIDER>_API_KEY` (for example `COHERE_API_KEY`).

```bash
export ANTHROPIC_API_KEY=sk-ant-...
aia -m claude-haiku-4-5 my_prompt
```

## Provider endpoints: `<PROVIDER>_API_BASE`

For any provider that has a configurable endpoint, `<PROVIDER>_API_BASE` points it somewhere else — a local server on a different port, a proxy, a self-hosted gateway. `<PROVIDER>` is the provider's slug from `aia --list-providers`, in capitals.

```bash
export OLLAMA_API_BASE=http://gpu-box.local:11434/v1
export OPENAI_API_BASE=https://llm-proxy.example.com/v1
```

See [Local Models](../extending/local-models.md).

## Other variables aia reads

| Variable | Used for |
|---|---|
| `PUREMD_API_KEY` | Required by the `/webpage` directive, which fetches pages through the pure.md service. |
| `XDG_CONFIG_HOME` | If set, aia looks for its config file at `$XDG_CONFIG_HOME/aia/aia.yml` first. See [The Config File](config-file.md#where-aia-looks). |
| `COLUMNS` | Width used to wrap `--list-tools` output. |
| `BUNDLE_GEMFILE` | Only when running `bin/aia` from a clone of the aia repository. |

## Variables aia sets for you

When aia runs your speak command (`--speak` with `--speak-command`, or the `/say` directive) it passes the speech model as `SPEECH_MODEL` in that command's environment.

## See also

- [The Config File](config-file.md)
- [Configuration Precedence](precedence.md)
- [Configuration Keys](../reference/config-keys.md)
- [Security](security.md) — keeping API keys safe
