## AIA and Pre-compositional AI Prompts

Pre-compositional templating of prompts using `AIA` endows prompt engineers with a significant level of power typically reserved for specialized gen-AI applications. `AIA` is a versatile command-line utility, with capabilities limited only by the imagination behind the prompts you create.

A pre-compositional prompt acts as a foundational template, which can be expanded into a fully fleshed-out prompt. This prompt is then handed off to a generative AI processor to transform into a response that meets your specific requirements.

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Introduction](#introduction)
    - [Large Language Models (LLM)](#large-language-models-llm)
    - [Running AIA](#running-aia)
    - [Set Up a Prompts Directory](#set-up-a-prompts-directory)
  - [AIA Supports Parameterized Prompts](#aia-supports-parameterized-prompts)
    - [Create a Parameterized Prompt](#create-a-parameterized-prompt)
    - [The Next Parts](#the-next-parts)
  - [Comments](#comments)
    - [Line Comments](#line-comments)
    - [End of File Block Comment](#end-of-file-block-comment)
  - [Directives](#directives)
    - [The `config` Directive](#the-config-directive)
    - [Parameter Substitution in Directives](#parameter-substitution-in-directives)
  - [Shell Integration](#shell-integration)
    - [Accessing System Environment Variables](#accessing-system-environment-variables)
      - [Contextual System Environment Variables](#contextual-system-environment-variables)
    - [Invoking Shell Commands](#invoking-shell-commands)
  - [Harnessing Ruby's Capabilities](#harnessing-rubys-capabilities)
    - [The Concept of Binding](#the-concept-of-binding)
    - [ERB Syntax at a Glance](#erb-syntax-at-a-glance)
    - [Conditional Logic](#conditional-logic)
    - [Accessing Current Data](#accessing-current-data)
  - [Summary of AIA Command-Line Tool](#summary-of-aia-command-line-tool)

<!-- Tocer[finish]: Auto-generated, don't remove. -->



## Introduction

The pre-compositional prompt management as utilized by the `AIA` (AI Assistant) command-line utility are a powerful extension to using the GPT technology in the terminal. If terminal programs and command-line interfaces (CLIs) aren't part of your workflow, then the current version of `AIA` may not be suitable for you.

`AIA` requires a Ruby environment.  To install and run `AIA` you must have Ruby installed on your system.  If you are not sure if your system has Ruby installed do this in your terminal to find out:

```shell
ruby --version
```

To install Ruby on your machine, follow the official [Ruby installation guide](https://www.ruby-lang.org/en/documentation/installation/).

With Ruby installed, you can set up `AIA` through your terminal with this command:

```shell
gem install aia
```

For the full potential of `AIA`, these CLI utilities are also needed:

```shell
brew install ripgrep fzf
```

For operating systems other than macOS, such as Linux or Windows, use their respective package managers (`apt`, `yum`, `dnf`, `scoop`, `choco`, etc.) to install the following tools:

- `ripgrep`: An advanced search tool akin to `grep`.
- `fzf`: A versatile command-line fuzzy finder.

### Large Language Models (LLM)

LLMs and GPTs (Generative Pre-trained Transformers) have sparked a revolution in AI by predicting text, word, sentence, pixel, and sound sequences that fit patterns initiated by a user prompt.  This revolution started when computer scientist realized that syntactic approaches to language translations were ineffective in creating good translations.  A statistical approach was created in which the probabilities of one set of language characters or phrases meant the same as another languages characters or phrases.

For example after analysing a large number of documents about the American government the phrase "The White" is most likely followed by "House."  Its not magic.  Its not thinking.  Its statistics or magic if you believe that matematics is magic.

### Running AIA

Executing the command:

```shell
aia
```

will prompt:

```shell
Please provide a prompt ID.
```

`AIA` requires a prompt ID to function. A prompt ID corresponds to the base name of a text file in your `prompts_dir` directory. To define your prompts directory, you can set an environment variable (`AIA_PROMPTS_DIR`) or specify the path directly as a command-line option.  To see all of the `AIA` command-line options do:

```shell
aia --help
```

### Set Up a Prompts Directory

The easiest way to tell `AIA` where the prompts directory is located is using the system environment variable $AIA_PROMPTS_DIR

```shell
export AIA_PROMPTS_DIR=~/my_prompts
mkdir $AIA_PROMPTS_DIR
```

## AIA Supports Parameterized Prompts

`AIA`'s first layer of pre-compositional prompt management is parameterization -— where placeholders within a prompt are replaced with user-defined values. By default, `AIA` considers any uppercase sequence within square brackets as a placeholder.

Examples of placeholders include:

- `[KEYWORD]`
- `[USER_ROLE]`
- `[COMPUTER_LANGUAGE]`

When using `AIA` with a sample prompt:

```shell
As a [ROLE], I want to [DO_SOMETHING].
```

`AIA` will ask for substitutions for each placeholder (keyword/parameter), saving your responses with the prompt file for future use. The last-used value for each placeholder is the default for subsequent uses of that specific prompt.

### Create a Parameterized Prompt

Let's create a simple yet flexible prompt file:

```shell
echo "[DO_WHAT]" > $AIA_PROMPTS_DIR/ad_hoc.txt
```

The associated "Prompt ID" is "ad_hoc" -— the basename of the file sans the ".txt" extension. Using the "ad_hoc" prompt ID:

```shell
aia ad_hoc
```

results in an interaction to specify a value for `[DO_WHAT]`. For instance, entering "tell me a joke" to replace "[DO_WHAT]" will generate a response but whether its a funny joke or a dad joke is completely up to the electrons that controll the statistics of the LLM. :)

### The Next Parts

Subsequent sections in this series cover:

- **Comments and Directives**: Lines starting with "#" are comments and ignored during processing. Lines starting with "//" are directives and are executed (e.g., "//config chat? = true" to set interactive chat mode for the prompt.)

- **Shell Integration**: Access to system environment variables and dynamic shell commands using the `--shell` option.

- **Embedded RuBy (ERB)**: For expert users, the option `--erb` allows Ruby code to be embedded in prompts (`<%= ruby_code %>`), offering unparalleled flexibility in prompt composition.  This is one way to embed current data into prompts for LLMs which do not have access to current real-time data.

> A pre-compositional prompt essentially serves as a template that expands into a full prompt, which is then processed by a generative AI to yield a tailored response.
>
> To recap, a prompt ID corresponds to the basename of a text file in a prompts directory. The simplest way to inform `AIA` of your prompts directory is through the environment variable `$AIA_PROMPTS_DIR`. For a prompt ID `ad_hoc`, `AIA` will read the prompt from `$AIA_PROMPTS_DIR/ad_hoc.txt`.
>
> NOTE: If you're on MacOS or another system where file extensions aren't visible in the terminal by default, consider adjusting your system settings to display file extensions.

## Comments

AI prompts can be thought of as programs that an AI processes to generate responses. Sometimes you get the desired outcome, and other times you don't. Iteration often precedes success, and you may later forget the rationale behind your original construction. Non-processable comments serve as documentation.

Comments can also shed light on the expected values for specific keywords or parameters.

Both comments and prompt content are fully searchable.

### Line Comments

A line beginning with the `#` character is treated as a line comment and is disregarded during prompt processing. Line comments are useful for providing metadata such as the file path, prompt description, author, or other identifying details.

Since line comments are searchable, they can also provide auxiliary context relevant to the prompt.

Below is an example of a `multi_step` prompt file with line comments:

```shell
# ~/prompts/multi_step.txt
# Description: A template for multi-step prompts

# Provide the LLM with the response format
[STEP_1]

# Define the role for the LLM
[STEP_2]

# Specify the task for the LLM
[STEP_3]
```

### End of File Block Comment

For content that doesn't fit into line comments, an end-of-file (EOF) comment block can be denoted as follows:

```shell
__END__
```

This indicates to `AIA` that no more prompt text follows.

Example EOF block comment in a prompt file:

```shell
Tell me some dad jokes.

__END__

1. I'm reading a book on anti-gravity. It's impossible to put down.
2. Did you hear about the restaurant on the moon? Great food, but no atmosphere.
3. What do you call fake spaghetti? An impasta.
```

## Directives

A directive is a line-specific action within the context of a prompt. It begins with the characters `//`. Here's the basic syntax of a directive:

```shell
//directive parameters
```

There should be no space between the `//` and the directive name, which is followed by at least one space before its parameters.

### The `config` Directive

Directives commonly adjust the configuration settings of a prompt. For example, to enter an interactive chat session without always using the `--chat` option, include a directive in the prompt file, as seen in `$AIA_PROMPTS_DIR/chat.txt`:

```shell
//config chat? = true
//config terse? = true

[WHAT IS ON YOUR MIND]
```

The first directive simulates the `--chat` command line option, while the second imitates `--terse`.

To start a chat session using this prompt, simply execute:

```shell
aia chat
```

You can modify any configuration items in a prompt, including the AI model, the response's output file, or the fine-tuned control parameters like temperature and `topp`.  Its also possible to direct the prompt to a backend processor other than the default.  (Current `AIA` supports two backend processors `mods` and `sgpt`.  `mods` is the default because of its significant flexibility.)

Additional directive commands were introduced in `AIA` v0.4.1, but might be deprecated due to the integration of embedded shell commands and Ruby sequences.

### Parameter Substitution in Directives

As discussed in Part 1, parameters in prompts are interchangeable. This is also true for directives:

```shell
//config terse? = [TERSE_YES_OR_NO]
```

While one could opt to use the `--terse` command line toggle directly, employing a directive allows the prompt to adapt between verbosity levels.

Parameter substitutions apply uniformly to directives, just like any other part of the prompt.

## Shell Integration

The `--shell` option permits shell integration, facilitating access to system environment variables (envars) and the execution of embedded shell commands within prompts.

### Accessing System Environment Variables

Incorporating envars within prompts is somewhat akin to parameter usage. With parameters, however, users are asked to provide the values for substitution. Conversely, when an envar is used, its value is automatically fetched from the shell and embedded.

Envars may be indicated by one of two patterns:

- `$UPPERCASE_WORD`
- `${UPPERCASE_WORD}`

For instance, consider the following prompts:

```shell
As a $ROLE ...
```

versus

```shell
As a [ROLE] ...
```

In the first example, the shell supplies the `$ROLE` value, whereas the second prompt implies interaction with the user to define `[ROLE]`.

In scenarios where multiple prompts utilize the same `ROLE`, it is practical to set an envar to circumvent the interactive step:

```shell
export ROLE="expert Ruby on Rails software developer"
aia example1 --shell -o response1.md
aia example2 --shell -o response2.md
# ...
```

#### Contextual System Environment Variables

With tools like `direnv`, you can set environment variables specific to your current directory tree context. On MacOS, `direnv` can be installed via `brew install direnv`.  There value only exists so long as you are working with the directory tree covered by the `.envrc` file the `direnv` uses to define its envars.

Imagine working in two project directory trees with different roles. In a `src` directory, your role is that of a software developer, whereas in a `doc` directory, you perform as a documentation specialist.

For the `src` directory, your `.envrc` file could be:

```shell
export ROLE="Crystal software developer"
```

Meanwhile, within the `doc` directory, `.envrc` might contain:

```shell
export ROLE="editorial assistant with experience writing documentation"
```

Now, consider this prompt, suitable for use in both contexts:

```shell
# ~/.prompts/review.txt

As a $ROLE, review the following file and suggest improvements.
```

Depending on the active directory, invoking the prompt in `src` yields suggestions tailored for Crystal source code, whereas in `doc`, it provides advice based on markdown-formatted documentation.

### Invoking Shell Commands

Additionally, the `--shell` option enables `AIA` to execute shell commands embedded in the prompt. The result of the shell command is then injected directly into the spot where the command is placed in the text file.

Here's the pattern for embedding a shell command:

```shell
$(...)
```

Whatever lies between the parentheses is executed as a shell command, ranging from the straightforward to the complex, depending on the desired outcome. Any output directed to `STDOUT` will be incorporated into the prompt text where specified.

For a practical example, consider this prompt which is intended for scrutinizing a system log file:

```shell
# ~/.prompts/summarize_log.txt
# Description: Examine a system log file for issues

As an experienced system administrator and senior DevOps engineer on the $(uname -v) platform, please review the following log entries and summarize any potential issues, providing recommendations for mitigation: $(tail -n $LOG_ENTRIES $LOG_FILE)
```



> A pre-compositional prompt serves as a foundational template. It's expanded into a fully-fledged prompt, ready to be handed off to a generative AI processor. The end goal is a response tailored to your specific requirements.


## Harnessing Ruby's Capabilities

The `AIA` command-line option `--erb` ebables the execution of embedded Ruby code within a prompt text file.

Ruby ERB (Embedded Ruby) is a system designed for interweaving Ruby code with text documents. This is especially useful for content that requires dynamic generation such as text files that undergo computation or data incorporation. 

ERB boasts numerous powerful features:

1. **Ruby Code Embedding**: Insert and execute any valid Ruby code inside a text document. Whether it's performing calculations or invoking methods, ERB's capabilities are far-reaching.

2. **Safe Evaluation**: ERB templates can be evaluated within a `binding` that exposes only select variables and methods. This precaution is crucial when dealing with untrusted template content.

3. **Control Structures**: Adopt Ruby control structures such as loops and conditionals within ERB, allowing conditional content inclusion.

4. **User-Friendly**: The ERB syntax is straightforward and blends seamlessly with usual text, providing a smooth experience for those familiar with HTML and similar languages.

5. **Included in Ruby's Standard Library**: ERB comes bundled with Ruby, negating the need for extra installations where Ruby is present.

6. **Industry Standard**: As the default engine for many Ruby frameworks, including Rails for views, ERB's reliability and support are well-established.

7. **Error Reporting**: ERB pinpoints errors with detailed stack traces, pointing out the exact line in the template to facilitate debugging.

8. **Commentary**: Integrate comments into an ERB template that remain hidden from the final output, parallel to Ruby comment syntax and the line comments used by `ai` which aids in documentation.

### The Concept of Binding

In Ruby — and ERB by extension — the 'binding' refers to the execution context, the sphere where Ruby objects bind to values. It's the scope within which Ruby objects are accessible; objects outside the binding remain out of reach.

With the `--erb` option in `AIA`, the binding for Ruby code in a prompt text file is confined to the file itself. You can define anything from scalar values to arrays and hashes, as well as methods or any other Ruby object type you might need. There is great freedom, yet the binding keeps a firm boundary — if an object is undefined within the prompt text, it remains inaccessible.

For a detailed exploration of the ERB syntax, refer to [this comprehensive guide](https://www.puppet.com/docs/puppet/latest/lang_template_erb.html).

### ERB Syntax at a Glance

Ruby code embedding with ERB offers two main patterns:

- `<% ruby code %>` for code execution only.
- `<%= ruby code %>` for code execution with output.

Both patterns support multi-line Ruby code; you're not constrained to a single line. 

Using the first pattern, `<% ... %>`, you define Ruby objects within the binding — setting variable values, declaring methods, and so forth — without generating any output to the prompt text.  After execution the ERB block is removed from the prompt text.

The second pattern, `<%= ... %>`, includes an equals sign '=' that signals the output of the ERB block to be inserted into the prompt text.  Like the first, the ERB block is removed but its output remains as part of the prompt text.

```ruby
<$ name = "Ruby" %>
Say hello to <%= name %> in three different languages.
```

In the first line the Ruby variable `name` was added to the binding as a Sring type with the value of "Ruby" so that in the second line the value of that variable could be accessed as used within the prompt text.


### Conditional Logic

ERB empowers you to create conditional prompts based on the available binding.

```ruby
<% "Ruby" == name %>
  Review these files: $(ls -1 *.rb) for duplicate code blocks.
M% else %>
  Review the grammar and spelling in these files $(ls -1 *.md)
<% end %>
```

### Accessing Current Data

By nature, large language models (LLMs) have a historical cut-off for training data. Only recently, generative AI tools granting real-time data access have been introduced. With ERB, you can complement LLM data by integrating up-to-date information directly into your prompts.

```ruby
<%
  require 'alphavantagerb'
  stock_info      = Alphavantage::Stock.new(
                      symbol: 'AAPL', 
                      key:    "your api key").quote
  current_price   = stock_info.price
  change          = stock_info.change
  change_percent  = stock_info.change_percent
%>

The latest stock information for Apple Inc. (AAPL) is as follows:
- Current Price: <%= current_price %>
- Change: <%= change %>
- Change (%): <%= change_percent %>

Generate a brief analysis of the stock performance based on this information.
```

This script illustrates how the ERB binding can extend to include external Ruby objects, though external libraries must be explicitly required within the ERB's binding.

## Summary of AIA Command-Line Tool

The AIA tool is a command-line interface designed to enable users to interact with an AI assistant, specifically with an AI model backend. It allows users to submit prompts, load context for AI processing, and receive responses from the AI model. The CLI tool is versatile and offers a range of options and configurations.

Key features of the AIA tool based on the user manual:

- **Command Syntax**: `aia [options]* PROMPT_ID [CONTEXT_FILE]* [-- EXTERNAL_OPTIONS+]`
- **Core Function**: Sends prompts to and receives responses from an AI backend.
- **Prompt ID**: A required argument that identifies the prompt to be processed.
- **Context Files**: Optional files that provide additional context for prompt processing.
- **External Options**: Additional backend-specific options can be passed after " -- ".

**Options Available**:
- Chat sessions (`--chat`) and turning off standard output for backend-only interaction.
- Shell completion scripts for various shell types (`--completion`).
- Configuration dumping (`--dump`).
- Environment variable substitution (`--shell`) and embedded Ruby execution (`--erb`).
- Model name specification (`--model`), and text-to-speech output (`--speak`).
- Terse response directive (`--terse`), checking for updates (`--version`), and backend specification (`-b`).
- Config files loading (`-c`), debugging mode activation (`-d`), prompt file editing (`-e`).
- Fuzzy matching for prompts search (`-f`), help display (`-h`), logging (`-l`).
- Markdown formatting (`-m`), output file specification (`-o`), and prompt directory setting (`-p`).
- Role ID to configure the AI's approach (`-r`), verbose output (`-v`).

**Configuration Hierarchy**:
- Environment variables prefixed with "AIA_" can alter default settings.
- Command-line options have precedence over environment variables.
- Config file settings and prompt directives within files can override other configurations.

**OpenAI Account Requirement**:
- Users must have an OpenAI access token specified through environment variables (`OPENAI_ACCESS_TOKEN` or `OPENAI_API_KEY`).

**Usage and Integration**:
- The tool is designed to be flexible, with the ability to customize output behavior and integrate auto-completion scripts into the shell environment.
- Configuration formats like YAML and TOML can be outputted using `--dump`.

**Prompt Directives**:
- Lines beginning with "//" in a prompt text file serve as directives, influencing behavior and configurations.

**Additional Information and Third-Party Tools**:
- The manual references additional documentation for OpenAI token access, as well as third-party CLI tools like `mods` and `sgpt` that integrate with AI services.

Through this tool, users have the ability to create highly customized interactions with an AI backend, using a command-line environment for efficient and programmable access to AI processing capabilities.

