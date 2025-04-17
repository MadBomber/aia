3# AI Assistant (AIA)

```plain
     ,      ,               AIA is a command-line utility that facilitates
     (\____/) AI Assistant  interaction with AI models. It automates the
      (_oo_)   Fancy LLM    management of pre-compositional prompts and
        (O)     is Online   executes generative AI (Gen-AI) commands on those
      __||__    \)          prompts, taking advantage of modern LLMs'
    [/______\]  /           increased context window size. The application
   / \__AI__/ \/            now includes enhanced features such as directive
  /    /__\                 processing, history management, shell command
 (\   /____\                execution, and chat processing services.
```

AIA leverages the [prompt_manager gem](https://github.com/madbomber/prompt_manager) to manage prompts. It utilizes the [CLI tool fzf](https://github.com/junegunn/fzf) for prompt selection.

**Most Recent Change**: Refer to the [Changelog](CHANGELOG.md)

**Notable Recent Changes:**
- **Directive Processing in Chat and Prompts:** You can now use directives in chat sessions and prompt files with the syntax: `//command args`. Supported directives include:
  - `shell`/`sh`: Execute shell commands
  - `ruby`/`rb`: Execute Ruby code
  - `config`/`cfg`: Display or update configuration
  - `include`/`inc`: Include file content
  - `help`: Show available directives


<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Installation](#installation)
  - [Usage](#usage)
  - [Configuration Options](#configuration-options)
    - [Order of Precedence](#order-of-precedence)
    - [Expandable Configuration](#expandable-configuration)
  - [Shell Integration inside of a Prompt](#shell-integration-inside-of-a-prompt)
      - [Dynamic Shell Commands](#dynamic-shell-commands)
      - [Shell Command Safety](#shell-command-safety)
      - [Chat Session Use](#chat-session-use)
  - [*E*mbedded *R*u*B*y (ERB)](#embedded-ruby-erb)
    - [Chat Session Behavior](#chat-session-behavior)
  - [Prompt Directives](#prompt-directives)
    - [Parameter and Shell Substitution in Directives](#parameter-and-shell-substitution-in-directives)
    - [Directive Syntax](#directive-syntax)
    - [`aia` Specific Directive Commands](#aia-specific-directive-commands)
      - [//config](#config)
      - [//include](#include)
      - [//ruby](#ruby)
      - [//shell](#shell)
    - [Using Directives in Chat Sessions](#using-directives-in-chat-sessions)
  - [Prompt Sequences](#prompt-sequences)
    - [--next](#--next)
    - [--pipeline](#--pipeline)
    - [Best Practices ??](#best-practices-)
    - [Example pipline](#example-pipline)
  - [All About ROLES](#all-about-roles)
    - [The --roles_prefix (AIA_ROLES_PREFIX)](#the---roles_prefix-aia_roles_prefix)
    - [The --role Option](#the---role-option)
    - [Other Ways to Insert Roles into Prompts](#other-ways-to-insert-roles-into-prompts)
  - [External CLI Tools Used](#external-cli-tools-used)
  - [Shell Completion](#shell-completion)
  - [My Most Powerful Prompt](#my-most-powerful-prompt)
  - [My Configuration](#my-configuration)
  - [Executable Prompts](#executable-prompts)
  - [Development](#development)
  - [Contributing](#contributing)
  - [License](#license)

<!-- Tocer[finish]: Auto-generated, don't remove. -->


## Installation

Install the gem by executing:

    gem install aia

Install the command-line utilities by executing:

    brew install fzf

You will also need to establish a directory in your file system where your prompt text files, last used parameters and usage log files are kept.

Setup a system environment variable (envar) named "AIA_PROMPTS_DIR" that points to your prompts directory.  The default is in your HOME directory named ".prompts". The envar "AIA_ROLES_PREFIX" points to your role prefix where you have prompts that define the different roles you want the LLM to assume when it is doing its work.  The default roles prefix is "roles".

You may also want to install the completion script for your shell.  To get a copy of the completion script do:

```bash
aia --completion bash
```

`fish` and `zsh` are also available.

## What is a Prompt ID?

A prompt ID is the basename of a text file (extension *.txt) located in a prompts directory. The prompts directory is specified by the environment variable "AIA_PROMPTS_DIR". If this variable is not set, the default is in your HOME directory named ".prompts".  It can also be set on the command line with the `--prompts-dir` option.

This file contains the context and instructions for the LLM to follow. The prompt ID is what you use as an option on the command line to specify which prompt text file to use. Prompt files can have comments, parameters, directives and ERB blocks along with the instruction text to feed to the LLM. It can also have shell commands and use system environment variables.  Consider the following example:

```plaintext
#!/usr/bin/env aia run
# ~/.prompts/example.txt
# Desc: Be an example prompt with all? the bells and whistles

# Set the configuration for this prompt

//config model = gpt-4
//config temperature = 0.7
//config shell = true
//config erb = true
//config out_file = path/to/output.md

# Add some file content to the context/instructions

//include path/to/file
//shell cat path/to/file
$(cat path/to/file)

# Setup some workflows

//next next_prompt_id
//pipeline prompt_id_1, prompt_ie_2, prompt_id_3

# Execute some Ruby code

//ruby require 'some_library' # inserts into the context/instructions
<% some_ruby_things # not inserted into the context %>
<%= some_other_ruby_things # that are part of the context/instructions %>

Tell me how to do something for a $(uname -s) platform that would rename all
of the files in the directory $MY_DIRECTORY to have a prefix of for its filename
that is [PREFIX] and a ${SUFFIX}

# directives, ERB blocks and other junk can be used
# anywhere in the file mixing dynamic context/instructions with
# the static stuff.

__END__

Block comments that are not part of the context or instructions to
the LLM.  Stuff that is just here ofr documentation.
```

That is just about everything including the kitchen sink that a pre-compositional parameterized prompt file can have.  It can be an executable with a she-bang line and a special system prompt name `run` as shown in the example.  It has line comments that use the `#` symbol. It had end of file block comments that appear after the "__END__" line.  It has directive command that begin with the double slash `//` - an homage to IBM JCL.  It has shell variables in both forms.  It has shell commands.  It has parameters that default to a regex that uses square brackets and all uppercase characeters to define the parameter name whose value is to be given in a Q&A session before the prompt is sent to the LLM for processing.

It als has the ability to define a workflow of prompt IDs with either the //next or //pipeline directives.

You could say that instead of the prompt being part of a program, a program can be part of the prompt.  The prompt is the code!

By using ERB you can make parts of the context/instructions conditional. You can also use ERB to make parts of the context/instructions dynamic for example to pull information from a database or an API.

## Usage

The usage report is obtained with either `-h` or `--help` options.

```bash
$ aia --help
```

## Configuration Options

The following table provides a comprehensive list of configuration options, their default values, and the associated environment variables:

| Option                  | Default Value                   | Environment Variable      |
|-------------------------|---------------------------------|---------------------------|
| out_file                | temp.md                         | AIA_OUT_FILE              |
| log_file                | ~/.prompts/_prompts.log         | AIA_LOG_FILE              |
| prompts_dir             | ~/.prompts                      | AIA_PROMPTS_DIR           |
| roles_prefix            | roles                           | AIA_ROLES_PREFIX          |
| model                   | gpt-4o-mini                     | AIA_MODEL                 |
| speech_model            | tts-1                           | AIA_SPEECH_MODEL          |
| transcription_model     | whisper-1                       | AIA_TRANSCRIPTION_MODEL   |
| verbose                 | false                           | AIA_VERBOSE               |
| markdown                | true                            | AIA_MARKDOWN              |
| shell                   | false                           | AIA_SHELL                 |
| erb                     | false                           | AIA_ERB                   |
| chat                    | false                           | AIA_CHAT                  |
| clear                   | false                           | AIA_CLEAR                 |
| terse                   | false                           | AIA_TERSE                 |
| debug                   | false                           | AIA_DEBUG                 |
| fuzzy                   | false                           | AIA_FUZZY                 |
| speak                   | false                           | AIA_SPEAK                 |
| append                  | false                           | AIA_APPEND                |
| temperature             | 0.7                             | AIA_TEMPERATURE           |
| max_tokens              | 2048                            | AIA_MAX_TOKENS            |
| top_p                   | 1.0                             | AIA_TOP_P                 |
| frequency_penalty       | 0.0                             | AIA_FREQUENCY_PENALTY     |
| presence_penalty        | 0.0                             | AIA_PRESENCE_PENALTY      |
| image_size              | 1024x1024                       | AIA_IMAGE_SIZE            |
| image_quality           | standard                        | AIA_IMAGE_QUALITY         |
| image_style             | vivid                           | AIA_IMAGE_STYLE           |
| embedding_model         | text-embedding-ada-002          | AIA_EMBEDDING_MODEL       |
| speak_command           | afplay                          | AIA_SPEAK_COMMAND         |
| require_libs            | []                              | AIA_REQUIRE_LIBS          |

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

> TODO: If you do not like the default regex used to identify parameters within the prompt text, don't worry there is a way to configure it.  I will tell you later if I remember.

### Expandable Configuration

The configuration options are expandable through a config file, allowing you to add custom entries. For example, you can define a custom configuration item like "xyzzy" in your config file. This value can then be accessed in your prompts using `AIA.config.xyzzy` within a `//ruby` directive or an ERB block, enabling dynamic prompt generation based on your custom configurations.

## Shell Integration inside of a Prompt

Using the option `--shell` enables AIA to access your terminal's shell environment from inside the prompt text.

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

The catchphrase "the prompt is the code" within AIA means that you have the power to execute any command you want, but you must be careful not to execute commands that could cause harm. AIA is not going to protect you from doing something stupid. Sure that's a copout. I just can't think (actually I can) of all the ways you can mess things up writing code. Remember what we learned from Forrest Gump "Stupid is as stupid does." So don't do anything stupid. If someone gives you a prompt as says "run this with AIA" you had better review the prompt before processing it.

#### Chat Session Use

When you use the `--shell` option to start a chat session, shell integration is available in your follow up prompts. Suppose you started a chat session (--chat) using a role of "Ruby Expert" expecting to chat about changes that could be made to a specific class BUT you forgot to include the class source file as part of the context when you got started. You could enter this as your follow up prompt to keep going:

```plaintext
The class I want to chat about refactoring is this one: $(cat my_class.rb)
```

That inserts the entire class source file into your follow up prompt. You can continue chatting with you AI Assistant about changes to the class.

## *E*mbedded *R*u*B*y (ERB)

The inclusion of dynamic content through the shell integration provided by the `--shell` option is significant. AIA also provides the full power of embedded Ruby code processing within the prompt text.

The `--erb` option turns the prompt text file into a fully functioning ERB template. The [Embedded Ruby (ERB) template syntax (2024)](https://bophin-com.ngontinh24.com/article/language-embedded-ruby-erb-template-syntax) provides a good overview of the syntax and power of ERB.

Most websites that have information about ERB will give examples of how to use ERB to generate dynamic HTML content for web-based applications. That is a common use case for ERB. AIA on the other hand uses ERB to generate dynamic prompt text for LLM processing.


## Prompt Directives

Downstream processing directives were added to the `prompt_manager` gem used by AIA at version 0.4.1. These directives are lines in the prompt text file that begin with "//" having this pattern:

```bash
//command params
```

There is no space between the "//" and the command. Commands do not have to have params. These params are typically space delimited when more than one is required. It all depens on the command.

### Parameter and Shell Substitution in Directives

When you combine prompt directives with prompt parameters and shell envar substitutions you can get some powerful compositional prompts.

Here is an example of a pure generic directive.

```bash
//[DIRECTIVE_NAME] [DIRECTIVE_PARAMS]
```

When the prompt runs, you will be asked to provide a value for each of the parameters.  You could answer "shell" for the directive name and "calc 22/7" if you wanted a bad approximation of PI.

Try this prompt file:
```bash
//shell calc [FORMULA]

What does that number mean to you?
```

### Directive Syntax

Directives can be entered in chat or prompt files using the following syntax:
- `//command args`

Supported directives:
- `help`: Show available directives
- `shell` or `sh`: Execute a shell command
- `ruby` or `rb`: Execute Ruby code
- `config` or `cfg`: Show or update configuration
- `include` or `inc`: Include file content
- `next`: Set/Show the next prompt ID to be processed
- `pipeline`: Set/Extend/Show the workflow of prompt IDs

When a directive produces output, it is added to the chat context. If there is no output, you are prompted again.

### AIA Specific Directive Commands

At this time AIA only has a few directives which are detailed below.

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

BTW: the "=" is completely options.  Its actuall ignored as is ":=" if you were to choose that as your assignment operator.  Also the number of spaces between the item and the value is complete arbitrary.  I like to line things up so this syntax is just as valie:

```bash
//config model       gpt-3.5-turbo
//config out_file    temp.md
//config chat?       true
//config terse?      true
//config model       gpt-4
```

NOTE: if you specify the same config item name more than once within the prompt file, its the last one which will be set when the prompt is finally process through the LLM.  For example in the example above `gpt-4` will be the model used.  Being first does not count in this case.

#### //include

Example:
```bash
//include path_to_file
```

The `path_to_file` can be either absolute or relative.  If it is relative, it is achored at the PWD.  If the `path_to_file` includes envars, the `--shell` CLI option must be used to replace the envar in the directive with its actual value.

The file that is included will have any comments or directives excluded.  It is expected that the file will be a text file so that its content can be pre-pended to the existing prompt; however, if the file is a source code file (ex: file.rb) the source code will be included HOWEVER any comment line or line that starts with "//" will be excluded.


#### //ruby

The `//ruby` directive executes Ruby code. You can use this to perform complex operations or interact with Ruby libraries.

For example:
```ruby
//ruby puts "Hello from Ruby"
```

You can also use the `--rq` option to specify Ruby libraries to require before executing Ruby code:

```bash
# Command line
aia --rq json,csv my_prompt

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

TODO: are these cli tools still used?

To install the external CLI programs used by AIA:

  brew install fzf

fzf
  Command-line fuzzy finder written in Go
  [https://github.com/junegunn/fzf](https://github.com/junegunn/fzf)


## Shell Completion

You can setup a completion function in your shell that will complete on the prompt_id saved in your `prompts_dir` - functions for `bash`, `fish` and `zsh` are available.  To get a copy of these functions do this:

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

alias chat='aia --chat --shell --erb --terse'

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

## Development

**ShellCommandExecutor Refactor:**
The `ShellCommandExecutor` is now a class (previously a module). It stores the config object as an instance variable and provides cleaner encapsulation. For backward compatibility, class-level methods are available and delegate to instance methods internally.

**Prompt Variable Fallback:**
When processing a prompt file without a `.json` history file, variables are always parsed from the prompt text so you are prompted for values as needed.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

When you find problems with AIA please note them as an issue.  This thing was written mostly by a human and you know how error prone humans are.  There should be plenty of errors to find.

I'm not happy with the way where some command line options for external command are hard coded.  I'm specific talking about the way in which the `rg` and `fzf` tools are used.  Their options decide the basic look and feel of the search capability on the command line.  Maybe they should be part of the overall configuration so that users can tune their UI to the way they like.

## History of Development

I originally wrote a tiny script called `aip.rb` to experiment with parameterized prompts. That was in August of 2023. AIP meant AI Parameterized. Adding an extra P for Prompts just seemed to be a little silly. It lived in my [scripts repo](https://github.com/MadBomber/scripts) for a while. It became useful to me so of course I need to keep enhancing it. I moved it into my [experiments repo](https://github.com/MadBomber/experiments) and began adding features in a haphazard manner. No real plan or architecture. From those experiments I refactored out the [prompt_manager gem](https://github.com/MadBomber/prompt_manager) and the [ai_client gem](https://github.com/MadBomber/ai_client)(https://github.com/MadBomber/ai_client). The name was changed from AIP to AIA and it became a gem.

All of that undirected experimentation without a clear picture of where this thing was going resulted in chaotic code. I would use an Italian food dish to explain the organization but I think chaotic is more descriptive.

## Roadmap

- expose embedded parameter regex as a configuration option
- support for using Ruby-based functional callback tools
- support for Model Context Protocol

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
