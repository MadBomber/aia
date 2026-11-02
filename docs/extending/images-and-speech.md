# Images and Speech

AIA can turn a prompt into an image instead of text, and it can read chat replies out loud.

## Generating images with `--paint`

Add `--paint` and AIA sends each prompt to an image model instead of a chat model:

```bash
aia --paint logo_idea
```

```bash
echo "A lighthouse on a rocky coast at dusk, oil painting" > ~/.prompts/lighthouse.md
aia --paint lighthouse
```

By default the image is saved next to your output file with a `.png` extension. The default output file is `temp.md`, so the image lands in `temp.png`:

```text
Image saved to: temp.png
```

Choose the file with `-o`:

```bash
aia --paint -o images/lighthouse.md lighthouse    # writes images/lighthouse.png
```

With `--no-output` nothing is saved. AIA prints the image URL the provider returned instead, or `(image returned no URL)` if the provider sent the image data directly. Keep an output file when you use a model that returns image data rather than a URL.

Everything you know about prompts still applies: [parameters](../prompts/parameters.md), [directives](../prompts/directives.md), [ERB and shell](../prompts/erb-and-shell.md), and [pipelines](../prompts/pipelines.md) (each prompt in a pipeline makes its own image). `--paint` applies to prompts you run from the command line, not to chat sessions.

### Image options

| Option | Config key | Default | Meaning |
|--------|-----------|---------|---------|
| `--im`, `--image-model MODEL` | `image.model` | `dall-e-3` | The image model |
| `--is`, `--image-size SIZE` | `image.size` | `1024x1024` | Image dimensions |
| `--iq`, `--image-quality QUALITY` | `image.quality` | `standard` | Quality setting |
| `--style`, `--image-style STYLE` | `image.style` | `vivid` | Style setting |

```bash
aia --paint --im dall-e-3 --is 1792x1024 --iq hd --style natural lighthouse
```

!!! tip "If the default model isn't available"
    AIA's default image model is `dall-e-3`, but the current model catalogue may not list it. If `--paint` fails with a model error, choose a model the catalogue lists, such as `--im gpt-image-1`.

Which sizes, qualities and styles are accepted depends on the model and provider. Check the provider's documentation. To find image-capable models:

```bash
aia --available-models text_to_image
```

```text
Available LLMs for text_to_image:

- gpt-image-1 (azure) text,image to image
...
```

`text_to_image` matches models that take text and return an image. Add a provider name to narrow it: `--available-models text_to_image,openai`.

## Hearing replies with `--speak`

In a chat, `--speak` reads every reply aloud, including replies from crewmates you address with `@name`:

```bash
aia --chat --speak
aia --chat --speak --voice Samantha
```

`--speak` works in chat sessions. Prompts you run without `--chat` aren't spoken.

### The default: macOS `say`

By default AIA speaks with the macOS `say` command. `--voice` picks one of its voices; run `say -v '?'` to list them. Config keys: `flags.speak`, `audio.voice`.

### Using your own text-to-speech command

To use a cloud voice or another text-to-speech engine, point `--speak-command` at your own script:

```bash
aia --chat --speak --speak-command ~/bin/tts.sh
```

AIA runs the command with two arguments: the text to speak, and the path of an `.mp3` file to write. When the command has written that file, AIA plays it with `afplay`. `afplay` comes with macOS, so on other systems the file is written but not played. For example:

```bash
#!/usr/bin/env bash
# ~/bin/tts.sh TEXT OUTPUT_FILE
text="$1"; out="$2"
curl -s https://api.openai.com/v1/audio/speech \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg t "$text" --arg m "${SPEECH_MODEL:-tts-1}" \
        '{model:$m, voice:"alloy", input:$t}')" \
  -o "$out"
```

`--speech-model` (`--sm`) is handed to your command as the `SPEECH_MODEL` environment variable. AIA doesn't use it any other way. The config key for the command is `audio.speak_command` (default `say`).

### Speaking a single line: `/say`

In a chat, `/say` speaks the text you give it using the macOS `say` command and your `--voice`. Nothing is sent to the model:

```text
> /say The build is finished.
```

## Transcription model

`--transcription-model` (`--tm`, config `audio.transcription_model`) sets the default model RubyLLM uses for speech-to-text. AIA itself doesn't take voice input. The setting is there for [tools](tools.md) that transcribe audio.

## See also

- [Output and History](../everyday/output-and-history.md)
- [Chat Sessions](../everyday/chat.md)
- [CLI reference](../reference/cli.md)
