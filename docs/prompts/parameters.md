# Parameters

Parameters turn one prompt file into a template you can use for many inputs. You declare them in the front matter, use them in the body with ERB tags, and AIA asks you for any values it needs when the prompt runs.

## Declaring parameters

List each parameter under `parameters:` in the front matter. The value you give it is its **default**. A parameter with no value (or `null`) is **required**.

```markdown
---
parameters:
  name:              # required: AIA will ask for it
  language: Spanish  # optional: defaults to Spanish
  tone: friendly     # optional: defaults to friendly
---
Write a short greeting for <%= name %> in <%= language %>.
Use a <%= tone %> tone. Keep it to two sentences.
```

In the body, `<%= name %>` is replaced by the parameter's value. Parameters use ERB syntax. The `[NAME]` placeholders from AIA 1.x are not supported. See [Migrating Prompts](../appendix/migrating-prompts.md) to convert older prompts.

!!! tip "Naming"
    Use lowercase `snake_case` names such as `file_name` or `target_audience`. A name that starts with a capital letter is read by ERB as a Ruby constant, and the prompt fails to render.

## Answering the questions

When the prompt runs, AIA asks for every declared parameter in the order you listed them. The default appears in parentheses:

```text
$ aia --no-output greeting
Value for name (required): Maria
Value for language (Spanish):
Value for tone (friendly): formal
```

- Type a value and press ++enter++ to use it.
- Press ++enter++ on an empty line, or ++ctrl+d++, to accept the default.
- For a required parameter, an empty answer stops AIA with `Parameter 'name' is required.`
- ++ctrl+c++ cancels with `Variable input interrupted.`

Each answer is a string. A default in the front matter keeps its YAML type, so `count: 3` is the number 3 until you type over it.

AIA reads answers from your terminal even when the prompt's input is piped, so you can mix parameters with piping:

```bash
git diff | aia --no-output review_diff
Value for focus (correctness): security
```

!!! note "Answers are not remembered"
    AIA doesn't save your answers between runs. If you find yourself typing the same value every time, make it the default in the front matter.

## Using parameters in the body

A parameter is just a value inside ERB, so you can do more than print it.

**Conditional text:**

```markdown
---
parameters:
  audience: developer
---
<% if audience == "developer" %>
Explain how Ruby's garbage collector works, including generational GC.
<% elsif audience == "manager" %>
Explain what garbage collection is and why it matters for performance.
Keep it non-technical.
<% else %>
Explain garbage collection as if I were ten years old.
<% end %>

Keep your answer to one paragraph.
```

**Transforming the value:**

```markdown
---
parameters:
  topic:
---
Write a blog post titled "<%= topic.split.map(&:capitalize).join(' ') %>".
```

**Reading a file whose name you supply:**

```markdown
---
parameters:
  file_name:
---
Review this file for bugs:

<%= File.read(file_name) %>
```

## Parameters and included files

When a prompt pulls in another file with `<%= include 'path/to/file.md' %>`, the included file sees the same parameter values as the file that includes it. You answer each question once, and both files use the answer. See [Directives](directives.md#composing-prompts-from-other-files).

## Parameters in pipelines

In a [pipeline](pipelines.md), AIA asks for each prompt's parameters when that prompt's turn comes. If a pipeline will run unattended, give every parameter a default.

## Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| A tag renders as nothing | The name inside `<%= %>` doesn't match any declared parameter. Unknown names render as an empty string. Check the spelling. |
| `parameters must be a mapping` | `parameters:` must hold `name: value` pairs, not a list. |
| You're asked for a value you thought had a default | `name:` with nothing after it means *required*. Give it a value. |
| The literal text `<%= name %>` reaches the model | The front matter sets `erb: false`. Remove that line. |

## See also

- [Prompt Files](prompt-files.md): front matter and file layout
- [ERB & Shell](erb-and-shell.md): everything ERB can do
- [Pipelines](pipelines.md): parameters across multiple prompts
- [Executable Prompts](executable-prompts.md): parameterized scripts you run directly
