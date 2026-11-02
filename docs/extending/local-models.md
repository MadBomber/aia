# Local Models and Providers

AIA works with any provider that [RubyLLM](https://rubyllm.com) supports, including models running on your own machine with Ollama or LM Studio. Local models keep your prompts on your computer, work offline and cost nothing per request.

## Providers and the `provider/` prefix

A provider is a service that serves models: OpenAI, Anthropic, Gemini, OpenRouter, Ollama and so on. To pick a provider explicitly, put its name in front of the model:

```bash
aia -m ollama/llama3.2 my_prompt
aia -m openrouter/anthropic/claude-sonnet-4-5 my_prompt
```

AIA treats the text before the first `/` as a provider only if RubyLLM knows a provider by that name. Model IDs that already contain a slash, such as `meta-llama/llama-4-maverick`, are left alone.

To see which providers are available, and which ones already have an API key set, run:

```bash
$ aia --list-providers
Registered RubyLLM providers:
------------------------------------------------------------
- anthropic
- gemini (has API key)
- lms (local)
- ollama (local)
- openai (has API key)
- openrouter (has API key)
...
```

A provider counts as "has API key" when `<PROVIDER>_API_KEY` is set, for example `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`.

### A default provider

If you use one provider all the time, set it with `--provider` and leave off the prefix:

```bash
aia --provider ollama -m llama3.2 my_prompt
```

A model that has its own prefix keeps it. `--provider` also tells `--list-models` which provider to ask:

```bash
$ aia --provider ollama --list-models

ollama models:
------------------------------------------------------------
- ollama/llama3.2:latest
- ollama/qwen3:8b

2 ollama model(s) available
```

`--list-models` asks the provider's server what it has right now. `--available-models` searches RubyLLM's built-in model catalogue instead, which mostly covers hosted models (see [Choosing Models](../everyday/models.md)).

### Provider gems

Some providers ship as separate gems named `ruby_llm-providers-<name>`. Install the gem and use its prefix: AIA loads it the first time it sees that prefix. You can also load one explicitly with `--require` (`--rq`). `--list-providers` lists every installed provider gem.

### Custom endpoints

For every provider, an environment variable named `<PROVIDER>_API_BASE` overrides the provider's endpoint, as long as the provider supports a custom endpoint:

```bash
export OLLAMA_API_BASE=http://gpu-box.local:11434/v1
export LMS_API_BASE=http://localhost:1234/v1
```

## Ollama

1. Install [Ollama](https://ollama.com) and download a model:

    ```bash
    brew install ollama        # macOS; see ollama.com for other systems
    ollama serve               # if it isn't already running
    ollama pull llama3.2
    ```

2. Use the `ollama/` prefix. AIA expects Ollama at `http://localhost:11434/v1`; if it runs elsewhere, set `OLLAMA_API_BASE` (see [Custom endpoints](#custom-endpoints)):

    ```bash
    aia -m ollama/llama3.2 my_prompt
    aia --chat -m ollama/llama3.2
    aia --provider ollama --list-models
    ```

## LM Studio

1. Install [LM Studio](https://lmstudio.ai), download a model, and start its local server (it listens on `http://localhost:1234/v1` by default).

2. Install the LM Studio provider gem:

    ```bash
    gem install ruby_llm-providers-lms
    ```

3. Use the `lms/` prefix with the model ID that LM Studio shows:

    ```bash
    aia -m lms/qwen/qwen3-coder-30b my_prompt
    aia --provider lms --list-models
    ```

The LM Studio provider talks to `http://localhost:1234/v1` unless you set `LMS_API_BASE`. It needs no API key.

## Mixing local and cloud models

Local and hosted models can be combined in the same session:

```bash
# Compare a local model with a hosted one
aia -m ollama/llama3.2,gpt-4o-mini my_prompt

# A local chief, plus a hosted crewmate recruited during the chat
aia --chat -m ollama/llama3.2
> /add_recruit expert anthropic/claude-sonnet-4-5 You answer the hard questions.
```

A crewmate or `/spawn` specialist with an explicit `provider/model` uses that provider, even when the chief is local. See [Crews](crews.md).

## Listing models from a chat

`/available_models` (also `/models`, `/am`, `/llms`) lists models from a chat. If your current models carry a provider prefix, it asks that provider's server for its live model list. Otherwise it searches RubyLLM's catalogue. Add words to filter the list:

```text
> /models qwen
```

## Tips

- **Pick a model that fits your hardware.** Smaller models answer faster, and larger ones follow instructions and call tools more reliably. Agent-style features (tools, `/decompose`, `/orchestrate`) need a model that's good at following instructions.
- **Concurrent requests queue up.** Multi-model runs, `@crew` broadcasts, `/debate` and `/decompose` send several requests at the same time. A single local server handles only a few at once, and the rest wait. For Ollama, raise `OLLAMA_NUM_PARALLEL`, or run fewer things at once.
- **There's no price for local models.** `--cost` shows costs only for models that RubyLLM has prices for. Token counts (`--tokens`) still work.
- **Timeouts.** Each model request may take up to 120 seconds. Long generations on a slow machine can go over that; a shorter prompt or a smaller model helps.

## See also

- [Choosing Models](../everyday/models.md)
- [Multiple Models](multi-model.md)
- [Environment variables](../configuration/environment.md)
