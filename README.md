# AI Assistant (AIA)

`aia` is a command-line utility that facilitates interaction with AI models. It automates the management of pre-compositional prompts and executes generative AI (Gen-AI) commands on those prompts, taking advantage of modern LLMs' increased context window size. The application now includes enhanced features such as directive processing, history management, shell command execution, and chat processing services.

It leverages the `prompt_manager` gem to manage prompts. It utilizes "ripgrep" for searching for prompt files and uses `fzf` for prompt selection based on a search term and fuzzy matching.

**Most Recent Change**: Refer to the [Changelog](CHANGELOG.md)

> Just an FYI ... I am working in the `develop` branch to **fully integrate the ai_client gem**, which gives access to all models and all providers. Recent updates include the addition of `DirectiveProcessor`, `HistoryManager`, `ShellCommandExecutor`, and `ChatProcessorService` classes to enhance functionality and user experience.



<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Installation](#installation)
  - [Usage](#usage)
  - [Configuration Using Envars and Defaults](#configuration-using-envars-and-defaults)
  - [Shell Integration inside of a Prompt](#shell-integration-inside-of-a-prompt)
      - [Access to System Environment Variables](#access-to-system-environment-variables)
      - [Dynamic Shell Commands](#dynamic-shell-commands)
      - [Shell Command Safety](#shell-command-safety)
      - [Chat Session Use](#chat-session-use)
  - [*E*mbedded *R*u*B*y (ERB)](#embedded-ruby-erb)
    - [Chat Session Behavior](#chat-session-behavior)
  - [Prompt Directives](#prompt-directives)
    - [Parameter and Shell Substitution in Directives](#parameter-and-shell-substitution-in-directives)
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

    brew install fzf ripgrep

You will also need to establish a directory in your file system where your prompt text files, last used parameters and usage log files are kept.

Setup a system environment variable (envar) named "AIA_PROMPTS_DIR" that points to your prompts directory.  The default is in your HOME directory named ".prompts". The envar "AIA_ROLES_PREFIX" points to your role prefix where you have prompts that define the different roles you want the LLM to assume when it is doing its work.  The default roles prefix is "roles".

You may also want to install the completion script for your shell.  To get a copy of the completion script do:

```bash
aia --completion bash
```

`fish` and `zsh` are also available.


## Usage

The usage report obtained using either `-h` or `--help` is implemented as a standard `man` page.  You can use both `--help --verbose` of `-h -v` together to get not only the `aia` man page.

```bash
$ aia --help
```

## Configuration Using Envars and Defaults

The AIA application now includes a comprehensive configuration system that allows for flexible customization through environment variables, command-line options, and configuration files. The default configuration includes options for model selection, output handling, shell command safety, and more.

The `aia` configuration defaults can be overridden by system environment variables *(envars)* with the prefix "AIA_" followed by the config item name also in uppercase. All configuration items can be overridden in this way by an envar.  The following table shows a few examples.

| Config Item          | Default Value                  | envar key                |
| -------------------- | ------------------------------ | ------------------------ |
| config_file          | nil                            | AIA_CONFIG_FILE          |
| debug                | false                          | AIA_DEBUG                |
| fuzzy                | false                          | AIA_FUZZY                |
| log_file             | ~/.prompts/_prompts.log        | AIA_LOG_FILE             |
| markdown             | true                           | AIA_MARKDOWN             |
| model                | gpt-4o-mini                    | AIA_MODEL                |
| out_file             | temp.md                        | AIA_OUT_FILE             |
| prompts_dir          | ~/.prompts                     | AIA_PROMPTS_DIR          |
| roles_prefix         | roles                          | AIA_ROLES_PREFIX         |
| speech_model         | tts-1                          | AIA_SPEECH_MODEL         |
| transcription_model  | whisper-1                      | AIA_TRANSCRIPTION_MODEL  |
| verbose              | false                          | AIA_VERBOSE              |
| voice                | alloy                          | AIA_VOICE                |
| shell_confirm        | true                           | AIA_SHELL_CONFIRM        |
| strict_shell_safety  | false                          | AIA_STRICT_SHELL_SAFETY  |
| image_size           | 1024x1024                      | AIA_IMAGE_SIZE           |
| image_quality        | standard                       | AIA_IMAGE_QUALITY        |
| image_style          | vivid                          | AIA_IMAGE_STYLE          |



See the `@options` hash in the `cli.rb` file for a complete list.  There are some config items that do not necessarily make sense for use as an envar over-ride.  For example if you set `export AIA_DUMP_FILE=config.yaml` then `aia` would dump the current configuration config.yaml and exit every time it is ran until you finally `unset AIA_DUMP_FILE`

## Shell Integration inside of a Prompt

Using the option `--shell` enables `aia` to access your terminal's shell environment from inside the prompt text.

#### Access to System Environment Variables

`aia` can replace any system environment variable (envar) references in the prompt text with the value of the envar.  Patterns like $USER and ${USER} in the prompt will be replaced with that envar's value - the name of the user's account.  Any envar can be used.

#### Dynamic Shell Commands

Dynamic content can be inserted into the prompt using the pattern $(shell command) where the output of the shell command will replace the $(...) pattern.

Consider the power to tailoring a prompt to your specific operating system:

```plaintext
As a system administration on a $(uname -v) platform what is the best way to [DO_SOMETHING]
```

or insert content from a file in your home directory:

```plaintext
Given the following constraints $(cat ~/3_laws_of_robotics.txt) determine the best way to instruct my roomba to clean my kids room.
```

#### Shell Command Safety

To protect against potentially dangerous shell commands, AIA includes safety features that can be configured to your preference:

1. **Command Confirmation** (Default: Enabled)
   - When enabled, AIA will prompt for confirmation before executing potentially dangerous shell commands
   - Dangerous commands include those that could delete files (`rm -f`), format drives (`mkfs`), stop services, etc.
   - Enable/disable with `--shell-confirm` or `--no-shell-confirm` command line options
   - Configure with `AIA_SHELL_CONFIRM=true|false` environment variable
   - Set in a config directive with `//config shell_confirm=true|false`

2. **Strict Shell Safety** (Default: Disabled)
   - When enabled, AIA will completely block execution of potentially dangerous shell commands
   - Enable/disable with `--strict-shell-safety` or `--no-strict-shell-safety` command line options
   - Configure with `AIA_STRICT_SHELL_SAFETY=true|false` environment variable
   - Set in a config directive with `//config strict_shell_safety=true|false`

```bash
⚠️  WARNING: Potentially dangerous shell command detected:

    rm -rf temp_dir

Do you want to execute this command? [y/N]:
```

#### Chat Session Use

When you use the `--shell` option to start a chat session, shell integration is available in your follow up prompts.  Suppose you started up a chat session using a roll of "Ruby Expert" expecting to chat about changes that could be made to a specific class BUT you forgot to include the class source file as part of the context when you got started.  You could enter this as your follow up prompt to this to keep going:

```plaintext
The class I want to chat about refactoring is this one: $(cat my_class.rb)
```

That inserts the entire class source file into your follow up prompt.  You can continue chatting with you AI Assistant about changes to the class.

## *E*mbedded *R*u*B*y (ERB)

The inclusion of dynamic content through the shell integration provided by the `--shell` option is significant.  `aia` also provides the full power of embedded Ruby code processing within the prompt text.

The `--erb` option turns the prompt text file into a fully functioning ERB template. The [Embedded Ruby (ERB) template syntax (2024)](https://bophin-com.ngontinh24.com/article/language-embedded-ruby-erb-template-syntax) provides a good overview of the syntax and power of ERB.

Most websites that have information about ERB will give examples of how to use ERB to generate dynamice HTML content for web-based applications.  That is a common use case for ERB.  `aia` on the other hand uses ERB to generate dynamic prompt text.

### Chat Session Behavior

In a chat session whether started by the `--chat` option or its equivalent with a directive within a prompt text file behaves a little differently w/r/t its binding and local variable assignments.  Since a chat session by definition has multiple prompts, setting a local variable in one prompt and expecting it to be available in a subsequent prompt does not work.  You need to use instance variables to accomplish this prompt to prompt carry over of information.

Also since follow up prompts are expected to be a single thing - sentence or paragraph - terminated by a single return, its likely that ERB enhance will be of benefit; but, you may find a use for it.

## Prompt Directives

Downstream processing directives were added to the `prompt_manager` gem used by `au` at version 0.4.1.  These directives are lines in the prompt text file that begin with "//" having this pattern:

```bash
//command parameters
```

There is no space between the "//" and the command.

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

### `aia` Specific Directive Commands

At this time `aia` only has a few directives which are detailed below.

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

### Using Directives in Chat Sessions

Whe you are in a chat session, you may use a directive as a follow up prompt.  For example if you started the chat session with the option `--terse` expecting to get short answers from the LLM; but, then you decide that you want more comprehensive answers you may do this in a chat follow up:

```bash
//config terse? false
```

The directive is executed and a new follow up prompt can be entered with a more lengthy response generated from the LLM.


## Prompt Sequences

Why would you need/want to use a sequence of prompts in a batch situation.  Maybe you have a complex prompt which exceeds the token limitations of your model for input so you need to break it up into multiple parts.  Or suppose its a simple prompt but the number of tokens on the output is limited and you do not get exactly the kind of full response for which you were looking.

Sometimes it takes a series of prompts to get the kind of response that you want.  The reponse from one prompt becomes a context for the next prompt.  This is easy to do within a `chat` session were you are manually entering and adjusting your prompts until you get the kind of response that you want.

If you need to do this on a regular basis or within a batch you can use `aia` and the `--next` and `--pipeline` command line options.

These two options specify the sequence of prompt IDs to be processed. Both options are available to be used within a prompt file using the `//next` and `//pipeline` directives.  Like all embedded directives you can take advantage of parameterization shell integration and Ruby.  With this kind of dynamic content and control flow in your prompts you wil start to feel like Tim the Tool man - more power!

Consider the condition in which you have 4 prompt IDs that need to be processed in sequence.  The IDs and associated prompt file names are:

| Promt ID | Prompt File |
| -------- | ----------- |
| one.     | one.txt     |
| two.     | two.txt     |
| three.   | three.txt   |
| four.    | four.txt    |


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
| --- | --- |
| one.txt | //config out_file one.md |
| two.txt | //config out_file two.md |
| three.txt | //config out_file three.md |
| four.txt | //config out_file four.md |

This way you can see the response that was generated for each prompt in the sequence.

### Example pipline

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

The second kind of prompt is called a role (aka system prompt). Sometimes the role is incorporated into the instruction. For example, "As a magician make a rabbit appear out of a hat." To reuse the same role in multiple prompts, `aia` encourages you to designate a special subdirectory for prompts that are specific to personification - roles.

The default `roles_prefix` is set to 'roles'. This creates a subdirectory under the `prompts_dir` where role files are stored. Internally, `aia` calculates a `roles_dir` value by joining `prompts_dir` and `roles_prefix`. It is recommended to keep the roles organized this way for better organization and management.

### The --role Option

The `--role` option is used to identify a personification prompt within your roles directory which defines the context within which the LLM is to provide its response.  The text of the role ID is pre-pended to the text of the primary prompt to form a complete prompt to be processed by the LLM.

For example consider:

```bash
aia -r ruby refactor my_class.rb
```

The role ID is `ruby` the prompt ID is `refactor` and my_class.rb is a context file.

Within the roles directory the contents of the text file `ruby.txt` will be pre-pre-pended to the contents of the `refactor.txt` file from the prompts directory to produce a complete prompt.  That complete prompt will have any parameters followed by directives processed before sending the combined prompt text and the content of the context file to the LLM.

Note that `--role` is just a way of saying add this prompt text file to the front of this other prompt text file.  The contents of the "role" prompt could be anything.  It does not necessarily have be an actual role.

`aia` fully supports a directory tree within the `prompts_dir` as a way of organization or classification of your different prompt text files.

```bash
aia -r ruby sw_eng/doc_the_methods my_class.rb
```

In this example the prompt text file `$AIA_ROLES_PREFIX/ruby.txt` is prepended to the prompt text file `$AIA_PROMPTS_DIR/sw_eng/doc_the_methods.txt`


### Other Ways to Insert Roles into Prompts

Since `aia` supports parameterized prompts you could make a keyword like "[ROLE]" be part of your prompt.  For example consider this prompt:

```text
As a [ROLE] tell me what you think about [SUBJECT]
```

When this prompt is processed, `aia` will ask you for a value for the keyword "[ROLE]" and the keyword "[SUBJECT]" to complete the prompt.  Since `aia` maintains a history of your previous answers, you could just choose something that you used in the past or answer with a completely new value.

## External CLI Tools Used

TODO: are these cli tools still used?

To install the external CLI programs used by aia:

  brew install fzf ripgrep

fzf
  Command-line fuzzy finder written in Go
  [https://github.com/junegunn/fzf](https://github.com/junegunn/fzf)

ripgrep
  Search tool like grep and The Silver Searcher
  [https://github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)


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

The magic is in the first line of the prompt.  It is a shebang line that tells the system how to execute the prompt.  In this case it is telling the system to use the `aia` command line tool to execute the `run` prompt.  The `--no-out_file` option tells the `aia` command line tool not to write the output of the prompt to a file.  Instead it will write the output to STDOUT.  The remaining content of this `top10` prompt is send via STDIN to the LLM.

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

This CLI tool started life as a few lines of ruby in a file in my scripts repo.  I just kep growing as I decided to add more capability.  There was no real architecture to guide the design.  What was left ws a large code mess which is slowly being refactored into something more maintainable.  That work is taking place in the `develop` branch.  I welcome you help.  Take a look at what is going on in that branch and send me a PR against it.

Of course if you see something in the main branch send me a PR against that one so that we can fix the problem for all.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

When you find problems with `aia` please note them as an issue.  This thing was written mostly by a human and you know how error prone humans are.  There should be plenty of errors to find.

I'm not happy with the way where some command line options for external command are hard coded.  I'm specific talking about the way in which the `rg` and `fzf` tools are used.  Their options decide the basic look and feel of the search capability on the command line.  Maybe they should be part of the overall configuration so that users can tune their UI to the way they like.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
