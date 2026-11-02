# Choosing Models

AIA can talk to any model that RubyLLM supports: OpenAI, Anthropic, Google Gemini, DeepSeek, Mistral, OpenRouter, xAI, AWS Bedrock, local servers and more. This chapter shows how to pick a model, find the exact name to use, and tune how it answers.

## The default

Unless you say otherwise, AIA uses **`gpt-4o-mini`** from OpenAI, which needs `OPENAI_API_KEY`. To use something else, choose one of the methods below.

## Choosing a model

=== "For one run"

    ```bash
    aia --model claude-sonnet-4-5 summarize report.txt
    aia -m gemini-2.5-flash --chat
    ```

=== "For your shell session"

    ```bash
    export AIA_MODEL=claude-sonnet-4-5
    ```

    `AIA_MODEL` takes a comma-separated list, just like `--model`.

=== "Permanently"

    ```yaml
    # ~/.config/aia/aia.yml
    models:
      - name: claude-sonnet-4-5
    ```

=== "Mid-chat"

    ```text
    /model claude-sonnet-4-5
    ```

    See [Chat Sessions](chat.md#switching-models-mid-conversation).

An option on the command line beats `AIA_MODEL`, which beats the config file. The full order is in [Precedence](../configuration/precedence.md).

## Model names

There are two ways to write a model name.

**A catalog ID** such as `gpt-4o`, `claude-sonnet-4-5` or `gemini-2.5-flash`. RubyLLM knows which provider serves it.

**`provider/model`** such as `ollama/llama3.2`, `openrouter/anthropic/claude-sonnet-4-5` or `gpustack/qwen3`. Use this form for local servers and for gateways that serve other companies' models. AIA treats the part before the first `/` as a provider only if it is a registered provider (see `--list-providers`). Otherwise the whole string is used as the model name, which is why catalog IDs like `meta-llama/llama-4-maverick` still work.

If most of your models come from one provider, set it once with `--provider` and leave the prefix off:

```bash
aia --provider ollama -m llama3.2 --chat        # same as -m ollama/llama3.2
```

If AIA can't find the model you asked for, it stops before running anything:

```text
<RubyLLM's "model not found" message>
Requested model(s): claude-sonet-4-5
Run 'aia --available-models' to see available models.
```

## Finding a model

### Search the catalog: `--available-models`

RubyLLM ships a catalog of known models. Search it with `--available-models`, giving a comma-separated list of terms that must **all** match:

```bash
aia --available-models                     # everything
aia --available-models claude              # names/providers containing "claude"
aia --available-models openai,mini         # both terms
```

```text
Available LLMs for openai and mini:

- gpt-4.1-mini (openai) text,image,pdf to text
- gpt-4.1-mini-2025-04-14 (openai) text,image,pdf to text
- gpt-4o-mini (openai) text,image,pdf to text
...

53 LLMs matching your query
```

Each line shows the model ID, its provider, and what goes in and comes out. Terms are matched as plain text against the whole line (case matters), so a provider name such as `anthropic` or an input type such as `pdf` works as a filter too.

!!! warning "Capability terms"
    A term containing `_to_` (such as `text_to_image`) is meant to filter by capability, but in 2.0.0 it stops with a `NoMethodError`. Filter on the line's text instead, for example `aia --available-models "to image"`.

### Ask a provider what it serves: `--list-models`

The catalog doesn't know about models on your own Ollama or LM Studio server, or brand-new ones. Ask the provider directly:

```bash
aia --provider ollama --list-models
```

```text
ollama models:
------------------------------------------------------------
- ollama/llama3.2
- ollama/qwen3:8b

2 ollama model(s) available
```

`--list-models` needs `--provider`. Without it you'll get `ERROR: --list-models requires --provider SLUG (use --available-models to search the full model registry)`.

### See which providers you can use: `--list-providers`

```bash
aia --list-providers
```

lists every registered provider, marking local ones with `(local)` and ones with a key in your environment with `(has API key)`. Provider gems you load with `--require` show up too.

### Searching from inside a chat

```text
/models claude
/models gpt -mini          # "gpt" but not "mini"
```

If your current model has a provider prefix (for example `ollama/…`), `/models` asks that provider for its live list. Otherwise it searches the catalog. Exclude terms with `-`, `~` or `!`.

## Tuning the answers

| Option | Config key | Default | What it does |
|--------|-----------|---------|--------------|
| `-t`, `--temperature N` | `llm.temperature` | `0.7` | Higher is more varied and creative, lower is more focused and repeatable |
| `--max-tokens N` | `llm.max_tokens` | `32767` | The most the model may write in one answer |
| `--top-p N` | `llm.top_p` | *(unset)* | Nucleus sampling. Leave unset unless you know you need it: some models reject requests that set both temperature and top-p |
| `--frequency-penalty N` | `llm.frequency_penalty` | `0.0` | Discourages repeating the same words |
| `--presence-penalty N` | `llm.presence_penalty` | `0.0` | Encourages moving on to new topics |

```bash
aia -t 0.2 extract_fields invoice.txt         # precise
aia -t 1.0 brainstorm                         # loose
```

AIA leaves out settings a model doesn't accept. For example, temperature isn't sent to models that don't support it, and for local providers the default `max_tokens` isn't sent at all, because their context windows are small.

## Using more than one model

Give `--model` a comma-separated list and every model answers in parallel:

```bash
aia -m gpt-4o,claude-sonnet-4-5,gemini-2.5-flash explain_code lib/parser.rb
aia -m gpt-4o,claude-sonnet-4-5 --consensus explain_code lib/parser.rb
```

Each model can have its own [role](roles-and-skills.md#a-different-role-per-model) (`-m gpt-4o=optimist,claude-sonnet-4-5=skeptic`), and the same model can appear more than once. How the answers are shown, compared and combined is covered in [Multiple Models and Consensus](../extending/multi-model.md).

## Local models

Models running on your own machine through Ollama, LM Studio or GPUStack need no API key and send nothing off your machine. Use the `provider/model` form:

```bash
aia -m ollama/llama3.2 --chat
```

Setup, endpoints and tips are in [Local Models](../extending/local-models.md).

## See also

- [Multiple Models and Consensus](../extending/multi-model.md)
- [Local Models](../extending/local-models.md)
- [Output, History and Usage](output-and-history.md): token counts and costs per model
- [CLI reference](../reference/cli.md)
