# AI Assistant (AIA)

**The prompt is the code!**

```plain
     ,      ,                 AIA is a command-line utility that facilitates
     (\____/) AI Assistant    interaction with AI models. It automates the
      (_oo_)   Fancy LLM      management of pre-compositional prompts and
        (O)     is Online     executes generative AI (Gen-AI) commands on those
      __||__    \)            prompts. AIA includes enhanced features such as
    [/______\]  /               * embedded directives * shell integration
   / \__AI__/ \/                * embedded Ruby       * history management
  /    /__\                     * interactive chat    * prompt workflows
 (\   /____\                    # supports RubyLLM::Tool integration
```

AIA leverages the [prompt_manager gem](https://github.com/madbomber/prompt_manager) to manage prompts. It utilizes the [CLI tool fzf](https://github.com/junegunn/fzf) for prompt selection.

**Wiki**: [Checkout the AIA Wiki](https://github.com/MadBomber/aia/wiki)

**MCRubyLLM::Tool Support:** AIA now supports the integration of Tools for those models that support function callbacks.  See the --tools, --allowed_tools and --rejected_tools options.  Yes, functional callbacks provided for dynamic prompts just like the AIA directives, shell and ERB integrations so why have both?  Well, AIA is older that functional callbacks.  The AIA integrations are legacy but more than that not all models support functional callbacks.  That means the AIA integrationsß∑ are still viable ways to provided dynamic extra content to your prompts.

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Configuration Options](#configuration-options)
    - [Configuration Flexibility](#configuration-flexibility)
    - [Expandable Configuration](#expandable-configuration)
  - [The Local Model Registry Refresh](#the-local-model-registry-refresh)
    - [Important Note](#important-note)
  - [Shell Integration inside of a Prompt](#shell-integration-inside-of-a-prompt)
      - [Dynamic Shell Commands](#dynamic-shell-commands)
      - [Shell Command Safety](#shell-command-safety)
      - [Chat Session Use](#chat-session-use)
  - [Embedded Ruby (ERB)](#embedded-ruby-erb)
  - [Prompt Directives](#prompt-directives)
    - [Parameter and Shell Substitution in Directives](#parameter-and-shell-substitution-in-directives)
    - [Directive Syntax](#directive-syntax)
    - [Available Directives](#available-directives)
    - [Some Specific Directives](#some-specific-directives)
      - [//config](#config)
      - [//include](#include)
      - [//ruby](#ruby)
      - [//shell](#shell)
      - [//available_models](#available_models)
      - [//next](#next)
      - [//pipeline](#pipeline)
    - [Using Directives in Chat Sessions](#using-directives-in-chat-sessions)
  - [Prompt Sequences](#prompt-sequences)
    - [--next](#--next)
    - [--pipeline](#--pipeline)
    - [Best Practices ??](#best-practices-)
    - [Example pipeline](#example-pipeline)
  - [All About ROLES](#all-about-roles)
    - [The --roles_prefix (AIA_ROLES_PREFIX)](#the---roles_prefix-aia_roles_prefix)
    - [The --role Option](#the---role-option)
    - [Other Ways to Insert Roles into Prompts](#other-ways-to-insert-roles-into-prompts)
  - [External CLI Tools Used](#external-cli-tools-used)
  - [Shell Completion](#shell-completion)
  - [My Most Powerful Prompt](#my-most-powerful-prompt)
  - [My Configuration](#my-configuration)
  - [Executable Prompts](#executable-prompts)
  - [Usage](#usage)
  - [Development](#development)
  - [Contributing](#contributing)
  - [Roadmap](#roadmap)
  - [RubyLLM::Tool Support](#rubyllmtool-support)
    - [What Are RubyLLM Tools?](#what-are-rubyllm-tools)
    - [How to Use Tools](#how-to-use-tools)
      - [`--tools` Option](#--tools-option)
    - [Filtering the tool paths](#filtering-the-tool-paths)
      - [`--at`, `--allowed_tools` Option](#--at---allowed_tools-option)
      - [`--rt`, `--rejected_tools` Option](#--rt---rejected_tools-option)
    - [Creating Your Own Tools](#creating-your-own-tools)
  - [MCP Supported](#mcp-supported)
  - [License](#license)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

## Configuration Options

The following table provides a comprehensive list of configuration options, their default values, and the associated environment variables:

| Config Item Name     | CLI Options | Default Value               | Environment Variable      |
|----------------------|-------------|-----------------------------|---------------------------|
| adapter              | --adapter   | ruby_llm                    | AIA_ADAPTER               |
| aia_dir              |             | ~/.aia                      | AIA_DIR                   |
| append               | -a, --append | false                      | AIA_APPEND                |
| chat                 | --chat      | false                       | AIA_CHAT                  |
| clear                | --clear     | false                       | AIA_CLEAR                 |
| config_file          | -c, --config_file | ~/.aia/config.yml      | AIA_CONFIG_FILE           |
| debug                | -d, --debug | false                       | AIA_DEBUG                 |
| embedding_model      | --em, --embedding_model | text-embedding-ada-002 | AIA_EMBEDDING_MODEL       |
| erb                  |             | true                       | AIA_ERB                   |
| frequency_penalty    | --frequency_penalty | 0.0                  | AIA_FREQUENCY_PENALTY     |
| fuzzy                | -f, --fuzzy | false                       | AIA_FUZZY                 |
| image_quality        | --iq, --image_quality | standard          | AIA_IMAGE_QUALITY         |
| image_size           | --is, --image_size | 1024x1024           | AIA_IMAGE_SIZE            |
| image_style          | --style, --image_style | vivid            | AIA_IMAGE_STYLE           |
| log_file             | -l, --log_file | ~/.prompts/_prompts.log  | AIA_LOG_FILE              |
| markdown             | --md, --markdown | true                   | AIA_MARKDOWN              |
| max_tokens           | --max_tokens | 2048                      | AIA_MAX_TOKENS            |
| model                | -m, --model | gpt-4o-mini                 | AIA_MODEL                 |
| next                 | -n, --next  | nil                         | AIA_NEXT                  |
| out_file             | -o, --out_file | temp.md                  | AIA_OUT_FILE              |
| parameter_regex      | --regex     | '(?-mix:(\[[A-Z _|]+\]))' | AIA_PARAMETER_REGEX       |
| pipeline             | --pipeline  | []                          | AIA_PIPELINE              |
| presence_penalty     | --presence_penalty | 0.0                   | AIA_PRESENCE_PENALTY      |
| prompt_extname       |             | .txt                        | AIA_PROMPT_EXTNAME        |
| prompts_dir          | -p, --prompts_dir | ~/.prompts            | AIA_PROMPTS_DIR           |
| refresh              | --refresh   | 7 (days)                    | AIA_REFRESH               |
| require_libs         | --rq --require | []                       | AIA_REQUIRE_LIBS          |
| role                 | -r, --role  |                             | AIA_ROLE                  |
| roles_dir            |             | ~/.prompts/roles            | AIA_ROLES_DIR             |
| roles_prefix         | --roles_prefix | roles                    | AIA_ROLES_PREFIX          |
| shell                |             | true                        | AIA_SHELL                 |
| speak                | --speak     | false                       | AIA_SPEAK                 |
| speak_command        |             | afplay                      | AIA_SPEAK_COMMAND         |
| speech_model         | --sm, --speech_model | tts-1               | AIA_SPEECH_MODEL          |
| system_prompt        | --system_prompt |                         | AIA_SYSTEM_PROMPT         |
| temperature          | -t, --temperature | 0.7                   | AIA_TEMPERATURE           |
| terse                | --terse     | false                       | AIA_TERSE                 |
| tool_paths           | --tools     | []                          | AIA_TOOL_PATHS            |
| allowed_tools        | --at --allowed_tools  | nil               | AIA_ALLOWED_TOOLS         |
| rejected_tools       | --rt --rejected_tools | nil               | AIA_REJECTED_TOOLS         |
| top_p                | --top_p     | 1.0                         | AIA_TOP_P                 |
| transcription_model  | --tm, --transcription_model | whisper-1   | AIA_TRANSCRIPTION_MODEL   |
| verbose              | -v, --verbose | false                     | AIA_VERBOSE               |
| voice                | --voice     | alloy                       | AIA_VOICE                 |

These options can be configured via command-line arguments, environment variables, or configuration files.

### Configuration Flexibility

AIA determines configuration settings using the following order of precedence:

1. Embedded config directives
2. Command-line arguments
3. Environment variables
4. Configuration files
5. Default values

For example, let's consider the `model` option. Suppose the following conditions:

- Default value is "gpt-4o-mini"
- No entry in the config file
- No environment variable value for `AIA_MODEL`
- No command-line argument provided for `--model`
- No embedded directive like `//config model = some-fancy-llm`

In this scenario, the model used will be "gpt-4o-mini". However, you can override this default by setting the model at any level of the precedence order. Additionally, you can dynamically ask for user input by incorporating an embedded directive with a placeholder parameter, such as `//config model = [PROCESS_WITH_MODEL]`. When processing the prompt, AIA will prompt you to input a value for `[PROCESS_WITH_MODEL]`.

If you do not like the default regex used to identify parameters within the prompt text, don't worry there is a way to configure it using the `--regex` option.

### Expandable Configuration

The configuration options are expandable through a config file, allowing you to add custom entries. For example, you can define a custom configuration item like "xyzzy" in your config file. This value can then be accessed in your prompts using `AIA.config.xyzzy` within a `//ruby` directive or an ERB block, enabling dynamic prompt generation based on your custom configurations.

## The Local Model Registry Refresh

The `ruby_llm` gem maintains a registry of providers and models integrated with a new website that allows users to download the latest information about each model. This capability is scheduled for release in version 1.3.0 of the gem.

In anticipation of this new feature, the AIA tool has introduced the `--refresh` option, which specifies the number of days between updates to the centralized model registry. Here’s how the `--refresh` option works:

- A value of `0` (zero) updates the local model registry every time AIA is executed.
- A value of `1` (one) updates the local model registry once per day.
- etc.

The date of the last successful refresh is stored in the configuration file under the key `last_refresh`. The default configuration file is located at `~/.aia/config.yml`. When a refresh is successful, the `last_refresh` value is updated to the current date, and the updated configuration is saved in `AIA.config.config_file`.

### Important Note

This approach to saving the `last_refresh` date can become cumbersome, particularly if you maintain multiple configuration files for different projects. The `last_refresh` date is only updated in the currently active configuration file. If you switch to a different project with a different configuration file, you may inadvertently hit the central model registry again, even if your local registry is already up to date.

## Shell Integration inside of a Prompt

AIA configures the `prompt_manager` gem to be fully integrated with your local shell by default.  This is not an option - its a feature. If your prompt inclues text patterns like $HOME, ${HOME} or $(command) those patterns will be automatically replaced in the prompt text by the shell's value for those patterns.

#### Dynamic Shell Commands

Dynamic content can be inserted into the prompt using the pattern $(shell command) where the output of the shell command will replace the $(...) pattern. It will become part of the context / instructions for the prompt.

Consider the power of tailoring a prompt to your specific operating system:

```plaintext
As a system administration on a $(uname -v) platform what is the best way to [DO_SOMETHING]
```

Or insert content from a file in your home directory:

```plaintext
Given the following constraints $(cat ~/3_laws_of_robotics.txt) determine the best way to instruct my roomba to clean my kids room.
```

#### Shell Command Safety

The catchphrase "the prompt is the code" within AIA means that you have the power to execute any command you want, but you must be careful not to execute commands that could cause harm. AIA is not going to protect you from doing something dumb. Sure that's a copout. I just can't think (actually I can) of all the ways you can mess things up writing code. Remember what we learned from Forrest Gump "Stupid is as stupid does." So don't break the dumb law. If someone gives you a prompt as says "run this with AIA" you had better review the prompt before processing it.

#### Chat Session Use

Shell integration is available in your follow up prompts within a chat session. Suppose you started a chat session (--chat) using a role of "Ruby Expert" expecting to chat about changes that could be made to a specific class BUT you forgot to include the class source file as part of the context when you got started. You could enter this as your follow up prompt to keep going:

```plaintext
The class I want to chat about refactoring is this one: $(cat my_class.rb)
```

That inserts the entire class source file into your follow up prompt. You can continue chatting with your AI Assistant about changes to the class.

## Embedded Ruby (ERB)

The inclusion of dynamic content through the shell integration is significant. AIA also provides the full power of embedded Ruby code processing within the prompt text.

AIA takes advantage of the `prompt_manager` gem to enable ERB integration in prompt text as a default.  Its an always available feature of AIA prompts.  The [Embedded Ruby (ERB) template syntax (2024)](https://bophin-com.ngontinh24.com/article/language-embedded-ruby-erb-template-syntax) provides a good overview of the syntax and power of ERB.

Most websites that have information about ERB will give examples of how to use ERB to generate dynamic HTML content for web-based applications. That is a common use case for ERB. AIA on the other hand uses ERB to generate dynamic or conditional prompt text for LLM processing.

## Prompt Directives

Downstream processing directives were added to the `prompt_manager` gem used by AIA at version 0.4.1. These directives are lines in the prompt text file that begin with "//" having this pattern:

```bash
//command params
```

There is no space between the "//" and the command. Commands do not have to have params. These params are typically space delimited when more than one is required. It all depends on the command.

Some directives add their output to the context of the prompt.  Others do not.  For example the `//help` directives does not extend the context but the `//include` and `//shell` and `//ruby` will inset their output into the prompt context.

### Parameter and Shell Substitution in Directives

When you combine prompt directives with prompt parameters and shell envar substitutions you can get some powerful compositional prompts. Don't forget that ERB is also available within a prompt text file.

Here is an example of a pure generic directive.

```bash
//[DIRECTIVE_NAME] [DIRECTIVE_PARAMS]
```

When the prompt runs, you will be asked to provide a value for each of the prompt parameters. You could answer "shell" for the directive name and "calc 22/7" if you wanted a bad approximation of PI.

Try this prompt file:
```bash
//shell calc [FORMULA]

What does that number mean to you?
```

### Directive Syntax

Directives can be entered in chat or prompt files using the following syntax:
- `//command args`

### Available Directives

The following list of available directives was generated in an interactive `chat` session using the `//help` directive:

```plaintext
//available_models All Available models or query on [partial LLM or provider name] Examples: //llms ; //llms openai ; //llms claude
	Aliases://all_models  //am  //available  //llms  //models

//clear Clears the conversation history (aka context) same as //config clear = true

//config Without arguments it will print a list of all config items and their values _or_ //config item (for one item's value) _or_ //config item = value (to set a value of an item)
	Aliases://cfg

//help Generates this help content

//include Inserts the contents of a file  Example: //include path/to/file
	Aliases://import  //include_file

//model Shortcut for //config model _and_ //config model = value

//next Specify the next prompt ID to process after this one

//pipeline Specify a sequence pf prompt IDs to process after this one
	Aliases://workflow

//review Review the current context
	Aliases://context

//robot Display the ASCII art AIA robot.

//ruby Shortcut for a one line of ruby code; result is added to the context
	Aliases://rb

//say Use the system's say command to speak text //say some text

//shell Executes one line of shell code; result is added to the context
	Aliases://sh

//temperature Shortcut for //config temperature _and_ //config temperature = value
	Aliases://temp

//terse Inserts an instruction to keep responses short and to the point.

//top_p Shortcut for //config top_p _and_ //config top_p = value
	Aliases://topp

//webpage webpage inserted as markdown to context using https://pure.md
```

### Some Specific Directives

A few directives are detailed below. Others should be self explanatory.

#### //config

The `//config` directive within a prompt text file is used to tailor the specific configuration environment for the prompt.  All configuration items are available to have their values changed.  The order of value assignment for a configuration item starts with the default value which is replaced by the envar value which is replaced by the command line option value which is replaced by the value from the config file.

The `//config` is the last and final way of changing the value for a configuration item for a specific prompt.

The switch options are treated like booleans.  They are either `true` or `false`. Their name within the context of a `//config` directive always ends with a "?" character - question mark.

To set the value of a switch using ``//config` for example `--terse` or `--chat` to this:

```bash
//config chat? = true
//config terse? = true
```

A configuration item such as `--out_file` or `--model` has an associated value on the command line.  To set that value with the `//config` directive do it like this:

```bash
//config model = gpt-3.5-turbo
//config out_file = temp.md
```

BTW: the "=" is completely options.  Its actually ignored as is ":=" if you were to choose that as your assignment operator.  Also the number of spaces between the item and the value is complete arbitrary.  I like to line things up so this syntax is just as valie:

```bash
//config model       gpt-3.5-turbo
//config out_file    temp.md
//config chat?       true
//config terse?      true
//config model       gpt-4
```

NOTE: if you specify the same config item name more than once within the prompt file, it is the last one which will be set when the prompt is finally processed through the LLM.  For example in the example above `gpt-4` will be the model used.  Being first does not count in this case.

#### //include

Example:
```bash
//include path_to_file
```

The `path_to_file` can be either absolute or relative.  If it is relative, it is anchored at the PWD.  If the `path_to_file` includes envars, they will be substituted with their actual value.

The file that is included will have any comments or directives excluded.  It is expected that the file will be a text file so that its content can be pre-pended to the existing prompt; however, if the file is a source code file (ex: file.rb) the source code will be included HOWEVER any comment line or line that starts with "//" will be excluded.

#### //ruby

The `//ruby` directive executes Ruby code. You can use this to perform complex operations or interact with Ruby libraries.

For example:
```ruby
//ruby require 'amazing_print'
//ruby require 'json'
//ruby a_hash = JSON.parse('{"data": [1,2,3]}')
//ruby ap a_hash
```

You could have done all of that with ERB in your prompt file.

You can also use the `--require` option on the command line to specify Ruby libraries to require before executing Ruby code:

```bash
# Command line
aia --rq json,csv --require os my_prompt

# In chat
//ruby JSON.parse('{"data": [1,2,3]}')["data"]
```

#### //shell
Example:
```bash
//shell some_shell_command
```

It is expected that the shell command will return some text to STDOUT which will be pre-pending to the existing prompt text within the prompt file.

There are no limitations on what the shell command can be.  For example if you wanted to bypass the stripping of comments and directives from a file you could do something like this:
```bash
//shell cat path_to_file
```

Which does basically the same thing as the `//include` directive, except it uses the entire content of the file.  For relative file paths the same thing applies.  The file's path will be relative to the PWD.

#### //available_models

That is a long name for a directive so I generally use its shortcut `//llms`  See the `//help` directives for other shortcuts.

This directive is very useful in interactive chat sessions.  For example you may have started the chat session with one model but durning the conversation you want to switch to a different model but cannot remember the model ID to use.  So you type in `//llms` and get a list of 505 mode IDs, the provider and the modes.  That's too many to look through using just the mark 2 eyeball scanner. Use query parameters with the directive.

```plaintext
Follow up (cntl-D or 'exit' to end) #=>
//llms openai text_to_image

Available LLMs for openai and text_to_image:

- dall-e-2 (openai) text to image,text
- dall-e-3 (openai) text to image
- gpt-image-1 (openai) image,text to image

3 LLMs matching your query

Follow up (cntl-D or 'exit' to end) #=>
```

Each parameter on this directive is considered an AND component of the query.  You asked of modes that were from OpenAI AN had a text to image mode. The number of parameters for the //llms directive is no limited.

Let's say you are looking for a smallish model (7billion parameters) in the qwen family that has an image mode but you can't remember if its and input or output for the image.
ß∑
```plaintext
Follow up (cntl-D or 'exit' to end) #=>
//llms qwen 7b image

Available LLMs for qwen and 7b and image:

- qwen/qwen-2.5-vl-7b-instruct (openrouter) text,image to text
- qwen/qwen-2.5-vl-7b-instruct:free (openrouter) text,image to text

2 LLMs matching your query

Follow up (cntl-D or 'exit' to end) #=>
```


#### //next
Examples:
```bash
# Show the next promt ID
//next

# Set the next prompt ID
//next prompt_id

# Same as
//config next
//config next = prompt_id
```

#### //pipeline

Examples:
```bash
# Show the current prompt workflow
//pipeline

# Set the prompt workflow
//pipeline =  prompt_id_1, prompt_id_2, prompt_id_3

# Extend the prompt workflow
//pipeline <<  prompt_id_4, prompt_id_5, prompt_id_6

# Same as
//config pipeline
//config pipeline = prompt_id_1, prompt_id_2, prompt_id_3
//config pipeline <<  prompt_id_4, prompt_id_5, prompt_id_6
```

### Using Directives in Chat Sessions

Whe you are in a chat session, you may use a directive as a follow up prompt.  For example if you started the chat session with the option `--terse` expecting to get short answers from the LLM; but, then you decide that you want more comprehensive answers you may do this in a chat follow up:

```bash
//config terse? false
```

The directive is executed and a new follow up prompt can be entered with a more lengthy response generated from the LLM.

The directive `//clear` truncates your entire session context. The LLM will not remember anything you have discussed.

## Prompt Sequences

Why would you need/want to use a sequence of prompts in a batch situation. Maybe you have a complex prompt which exceeds the token limitations of your model for input so you need to break it up into multiple parts. Or suppose its a simple prompt but the number of tokens on the output is limited and you do not get exactly the kind of full response for which you were looking.

Sometimes it takes a series of prompts to get the kind of response that you want.  The reponse from one prompt becomes a context for the next prompt. This is easy to do within a `chat` session were you are manually entering and adjusting your prompts until you get the kind of response that you want.

If you need to do this on a regular basis or within a batch you can use AIA and the `--next` and `--pipeline` command line options.

These two options specify the sequence of prompt IDs to be processed. Both options are available to be used within a prompt file using the `//next` and `//pipeline` directives. Like all embedded directives you can take advantage of parameterization shell integration and Ruby.  With this kind of dynamic content and control flow in your prompts you will start to feel like Tim the Tool man - more power!

Consider the condition in which you have 4 prompt IDs that need to be processed in sequence.  The IDs and associated prompt file names are:

| Prompt ID | Prompt File |
| --------- | ----------- |
| one       | one.txt     |
| two       | two.txt     |
| three     | three.txt   |
| four      | four.txt    |


### --next

```bash
aia one --next two --out_file temp.md
aia three --next four temp.md -o answer.md
```

or within each of the prompt files you use the `//next` directive:

```bash
one.txt contains //next two
two.txt contains //next three
three.txt contains //next four
```
BUT if you have more than two prompts in your sequence then consider using the --pipeline option.

**The directive //next is short for //config next**

### --pipeline

```bash
aia one --pipeline two,three,four
```

or inside of the `one.txt` prompt file use this directive:

```bash
//pipeline two,three,four
```

**The directive //pipeline is short for //config pipeline**

### Best Practices ??


Since the response of one prompt is fed into the next prompt within the sequence instead of having all prompts write their response to the same out file, use these directives inside the associated prompt files:


| Prompt File | Directive |
| ----------- | --------- |
| one.txt     | //config out_file one.md |
| two.txt     | //config out_file two.md |
| three.txt   | //config out_file three.md |
| four.txt    | //config out_file four.md |

This way you can see the response that was generated for each prompt in the sequence.

### Example pipeline

TODO: the audio-to-text is still under development.

Suppose you have an audio file of a meeting.  You what to get a transcription of what was said in that meeting.  Sometimes raw transcriptions hide the real value of the recording so you have crafted a pompt that takes the raw transcriptions and does a technical summary with a list of action items.

Create two prompts named transcribe.txt and tech_summary.txt

```bash
# transcribe.txt
# Desc: takes one audio file
# note that there is no "prompt" text only the directive

//config model    whisper-1
//next            tech_summary
```

and

```bash
# tech_summary.txt

//config model    gpt-4o-mini
//config out_file meeting_summary.md

Review the raw transcript of a technical meeting,
summarize the discussion and
note any action items that were generated.

Format your response in markdown.
```

Now you can do this:

```bash
aia transcribe my_tech_meeting.m4a
```

You summary of the meeting is in the file `meeting_summary.md`


## All About ROLES

### The --roles_prefix (AIA_ROLES_PREFIX)

The second kind of prompt is called a role (aka system prompt). Sometimes the role is incorporated into the instruction. For example, "As a magician make a rabbit appear out of a hat." To reuse the same role in multiple prompts, AIA encourages you to designate a special subdirectory for prompts that are specific to personification - roles.

The default `roles_prefix` is set to 'roles'. This creates a subdirectory under the `prompts_dir` where role files are stored. Internally, AIA calculates a `roles_dir` value by joining `prompts_dir` and `roles_prefix`. It is recommended to keep the roles organized this way for better organization and management.

### The --role Option

The `--role` option is used to identify a personification prompt within your roles directory which defines the context within which the LLM is to provide its response.  The text of the role ID is pre-pended to the text of the primary prompt to form a complete prompt to be processed by the LLM.

For example consider:

```bash
aia -r ruby refactor my_class.rb
```

The role ID is `ruby` the prompt ID is `refactor` and my_class.rb is a context file.

Within the roles directory the contents of the text file `ruby.txt` will be pre-pre-pended to the contents of the `refactor.txt` file from the prompts directory to produce a complete prompt.  That complete prompt will have any parameters followed by directives processed before sending the combined prompt text and the content of the context file to the LLM.

Note that `--role` is just a way of saying add this prompt text file to the front of this other prompt text file.  The contents of the "role" prompt could be anything.  It does not necessarily have be an actual role.

AIA fully supports a directory tree within the `prompts_dir` as a way of organization or classification of your different prompt text files.

```bash
aia -r ruby sw_eng/doc_the_methods my_class.rb
```

In this example the prompt text file `$AIA_ROLES_PREFIX/ruby.txt` is prepended to the prompt text file `$AIA_PROMPTS_DIR/sw_eng/doc_the_methods.txt`

### Other Ways to Insert Roles into Prompts

Since AIA supports parameterized prompts you could make a keyword like "[ROLE]" be part of your prompt.  For example consider this prompt:

```text
As a [ROLE] tell me what you think about [SUBJECT]
```

When this prompt is processed, AIA will ask you for a value for the keyword "[ROLE]" and the keyword "[SUBJECT]" to complete the prompt.  Since AIA maintains a history of your previous answers, you could just choose something that you used in the past or answer with a completely new value.

## External CLI Tools Used

To install the external CLI programs used by AIA:

  brew install fzf

fzf
  Command-line fuzzy finder written in Go
  [https://github.com/junegunn/fzf](https://github.com/junegunn/fzf)


## Shell Completion

You can setup a completion function in your shell that will complete on the prompt_id saved in your `prompts_dir` - functions for `bash`, `fish` and `zsh` are available.  To get a copy of these functions do:

```bash
aia --completion bash
```

If you're not a fan of "born again" replace `bash` with one of the others.

Copy the function to a place where it can be installed in your shell's instance.  This might be a `.profile` or `.bashrc` file, etc.

## My Most Powerful Prompt

This is just between you and me so don't go blabbing this around to everyone.  My most power prompt is in a file named `ad_hoc.txt`. It looks like this:

```text
[WHAT_NOW_HUMAN]
```

Yep.  Just a single parameter for which I can provide a value of anything that is on my mind at the time.  Its advantage is that I do not pollute my shell's command history with lots of text.

```bash
aia ad_hoc
```

Or consider this executable prompt file:

```bash
#!/usr/bin/env aia run
[WHAT_NOW_HUMAN]
```

Where the `run` prompt ID has a `run.txt` file in the prompt directory that is basically empty.  Or maybe `run.txt` has some prompt instructions for how to run the prompt - some kind of meta-thinking instructions.

## My Configuration

I use the `bash` shell.  In my `.bashrc` file I source another file named `.bashrc__aia` which looks like this:

```bash
# ~/.bashic_aia
# AI Assistant

# These are the defaults:
export AIA_PROMPTS_DIR=~/.prompts
export AIA_OUT_FILE=./temp.md
export AIA_LOG_FILE=$AIA_PROMPTS_DIR/_prompts.log
export AIA_MODEL=gpt-4o-mini

# Not a default.  Invokes spinner.  If not true then there is no spinner
# for feedback while waiting for the LLM to respond.
export AIA_VERBOSE=true

alias chat='aia --chat --terse'

# rest of the file is the completion function
```



## Executable Prompts

With all of the capabilities of the AI Assistant, you can create your own executable prompts. These prompts can be used to automate tasks, generate content, or perform any other action that you can think of.  All you need to get started with executable prompts is a prompt that does not do anything.  For example consider my `run.txt` prompt.

```bash
# ~/.prompts/run.txt
# Desc: Run executable prompts coming in via STDIN
```

Remember that the '#' character indicates a comment line making the `run` prompt ID basically a do nothing prompt.

An executable prompt can reside anywhere either in your $PATH or not.  That is your choice.  It must however be executable.  Consider the following `top10` executable prompt:

```bash
#!/usr/bin/env aia run --no-out_file
# File: top10
# Desc: The tope 10 cities by population

what are the top 10 cities by population in the USA. Summarize what people
like about living in each city. Include an average cost of living. Include
links to the Wikipedia pages.  Format your response as a markdown document.
```

Make sure that it is executable.

```bash
chmod +x top10
```

The magic is in the first line of the prompt.  It is a shebang line that tells the system how to execute the prompt.  In this case it is telling the system to use the `aia` command line tool to execute the `run` prompt.  The `--no-out_file` option tells the AIA command line tool not to write the output of the prompt to a file.  Instead it will write the output to STDOUT.  The remaining content of this `top10` prompt is send via STDIN to the LLM.

Now just execute it like any other command in your terminal.

```bash
./top10
```

Since its output is going to STDOUT you can setup a pipe chain.  Using the CLI program `glow` to render markdown in the terminal
(brew install glow)

```bash
./top10 | glow
```

This executable prompt concept sets up the building blocks of a *nix CLI-based pipeline in the same way that the --pipeline and --next options and directives are used.

## Usage

The usage report is obtained with either `-h` or `--help` options.

```bash
aia --help
```

Key command-line options include:

- `--adapter ADAPTER`: Choose the LLM interface adapter to use. Valid options are 'ruby_llm' (default) or something else in the future. See [RubyLLM Integration Guide](README_RUBY_LLM.md) for details.
- `--model MODEL`: Specify which LLM model to use
- `--chat`: Start an interactive chat session
- `--role ROLE`: Specify a role/system prompt
- And many more (use --help to see all options)

**Note:** ERB and shell processing are now standard features and always enabled. This allows you to use embedded Ruby code and shell commands in your prompts without needing to specify any additional options.

## Development

**ShellCommandExecutor Refactor:**
The `ShellCommandExecutor` is now a class (previously a module). It stores the config object as an instance variable and provides cleaner encapsulation. For backward compatibility, class-level methods are available and delegate to instance methods internally.

**Prompt Variable Fallback:**
When processing a prompt file without a `.json` history file, variables are always parsed from the prompt text so you are prompted for values as needed.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

When you find problems with AIA please note them as an issue.  This thing was written mostly by a human and you know how error prone humans are.  There should be plenty of errors to find.

I'm not happy with the way where some command line options for external command are hard coded.  I'm specific talking about the way in which the `rg` and `fzf` tools are used.  Their options decide the basic look and feel of the search capability on the command line.  Maybe they should be part of the overall configuration so that users can tune their UI to the way they like.

## Roadmap

- restore the prompt text file search. currently fzf only looks a prompt IDs.
- continue integration of the ruby_llm gem
- support for Model Context Protocol

## RubyLLM::Tool Support

AIA supports function calling capabilities through the `RubyLLM::Tool` framework, enabling LLMs to execute custom functions during a chat session.

### What Are RubyLLM Tools?

Tools (or functions) allow LLMs to perform actions beyond generating text, such as:

- Retrieving real-time information
- Executing system commands
- Accessing external APIs
- Performing calculations

Check out the [examples/tools](examples/tools) directory which contains several ready-to-use tool implementations you can use as references.

### How to Use Tools

AIA provides three CLI options to manage function calling:

#### `--tools` Option

Specifies where to find tool implementations:

```bash
# Load tools from multiple sources
--tools /path/to/tools/directory,other/tools/dir,my_tool.rb

# Or use multiple --tools flags
--tools my_first_tool.rb --tools /tool_repo/tools
```

Each path can be:

- A Ruby file implementing a `RubyLLM::Tool` subclass
- A directory containing tool implementations (all Ruby files in that directory will be loaded)

Supporting files for tools can be placed in the same directory or subdirectories.

### Filtering the tool paths

The --tools option must have exact relative or absolute paths to the tool files to be used by AIA for function callbacks.  If you are specifying directories you may find yourself needing filter the entire set of tools to either allow some or reject others based upon some indicator in their file name.  The following two options allow you to specify multiple sub-strings to match the tolls paths against.  For example you might be comparing one version of a tool against another.  Their filenames could have version prefixes like tool_v1.rb and tool_v2.rb  Using the allowed and rejected filters you can choose one of the other when using an entire directory full of tools.

#### `--at`, `--allowed_tools` Option

Filters which tools to make available when loading from directories:

```bash
# Only allow tools with 'test' in their filename
--tools my_tools_directory --allowed_tools test
```

This is useful when you have many tools but only want to use specific ones in a session.

#### `--rt`, `--rejected_tools` Option

Excludes specific tools:

```bash
# Exclude tools with '_v1' in their filename
--tools my_tools_directory --rejected_tools _v1
```

Ideal for excluding older versions or temporarily disabling specific tools.

### Creating Your Own Tools

To create a custom tool:

1. Create a Ruby file that subclasses `RubyLLM::Tool`
2. Define the tool's parameters and functionality
3. Use the `--tools` option to load it in your AIA session

For implementation details, refer to the [examples in the repository](examples/tools) or the RubyLLM documentation.

## MCP Supported

Abandon all hope of seeing an MCP client added to AIA.  Maybe sometime in the future there will be a new gem "ruby_llm-mcp" that implements an MCP client as a native RubyLLM::Tool subclass.  If that every happens you would use it the same way you use any other RubyLLM::Tool subclass which AIA now supports.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
