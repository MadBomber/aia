# AI Assistant (AIA)

`aia` is a command-line utility that integrates prameterized prompt management with generative AI (gen-AI) execution.

Uses the gem "prompt_manager" to manage the prompts sent to the `mods` command-line utility.  Uses the command line tools "ripgrep" to search for prompts to send and "fzf" to select the prompts that match the search term.

**Most Recent Change**

v0.4.1 - Added a chat mode.  Prompt directives are now supported.

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Installation](#installation)
  - [Usage](#usage)
  - [System Environment Variables (envar)](#system-environment-variables-envar)
  - [Prompt Directives](#prompt-directives)
  - [External CLI Tools Used](#external-cli-tools-used)
  - [Shell Completion](#shell-completion)
  - [Development](#development)
  - [Contributing](#contributing)
  - [License](#license)

<!-- Tocer[finish]: Auto-generated, don't remove. -->


## Installation

Install the gem by executing:

    gem install aia


Install the command-line utilities by executing:

    brew install mods fzf ripgrep

You will also need to establish a directory in your file system where your prompt text files, last used parameters and usage log files are kept.

Setup a system environment variable named "AIA_PROMPTS_DIR" that points to your prompts directory.  The default is in your HOME directory named ".prompts_dir"

You may also want to install the completion script for your shell.  To get a copy of the completion script do:

`aia --completion bash`

`fish` and `zsh` are also available.


## Usage

The usage report obtained using either `-h` or `--help` is implemented as a standard `man` page.  You can use both `--help --verbose` of `-h -v` together to get not only the `aia` man page but also the usage report from the `backend` LLM processing tool.

```text
$ aia --help

aia(1)                                   User Manuals                                  aia(1)

NAME
       aia - command-line interface for an AI assistant

SYNOPSIS
       aia [options]* PROMPT_ID [CONTEXT_FILE]* [-- EXTERNAL_OPTIONS+]

DESCRIPTION
       The aia command-line tool is an interface for interacting with an AI model backend,
       providing a simple way to send prompts and receive responses. The CLI supports various
       options to customize the interaction, load a configuration file, edit prompts, set
       debugging levels, and more.

ARGUMENTS
       PROMPT_ID
              This is a required argument.

       CONTEXT_FILES
              This is an optional argument.  One or more files can be added to the prompt as
              context for the backend gen-AI tool to process.

       EXTERNAL_OPTIONS
              External options are optional.  Anything that follow “ -- “ will be sent to the
              backend gen-AI tool.  For example “-- -C -m gpt4-128k” will send the options
              “-C -m gpt4-128k” to the backend gen-AI tool.  aia will not validate these
              external options before sending them to the backend gen-AI tool.

OPTIONS
       --chat begin a chat session with the backend after the initial prompt response;  will
              set --no-output so that the backend response comes to STDOUT.

       --completion SHELL_NAME

       --dump FORMAT

       --model NAME
              Name of the LLM model to use - default is gpt-4-1106-preview

       --speak
              Simple implementation. Uses the “say” command to speak the response.  Fun with
              --chat

       --terse
              Add a clause to the prompt text that instructs the backend to be terse in its
              response.

       --version
              Print Version - default is false

       -b, --[no]-backend LLM TOOL
              Specify the backend prompt resolver - default is mods

       -c, --config PATH_TO_CONFIG_FILE
              Load Config File - default is nil

       -d, --debug
              Turn On Debugging - default is false

       -e, --edit
              Edit the Prompt File - default is false

       -f, --fuzzy`
              Use Fuzzy Matching when searching for a prompt - default is false

       -h, --help
              Show Usage - default is false

       -l, --[no]-log PATH_TO_LOG_FILE
              Log FILEPATH - default is $HOME/.prompts/prompts.log

       -m, --[no]-markdown
              Format with Markdown - default is true

       -o, --[no]-output PATH_TO_OUTPUT_FILE
              Out FILENAME - default is ./temp.md

       -p, --prompts PATH_TO_DIRECTORY
              Directory containing the prompt files - default is ~/.prompts

       -v, --verbose
              Be Verbose - default is false

CONFIGURATION HIERARCHY
       System Environment Variables (envars) that are all uppercase and begin with “AIA_” can
       be used to over-ride the default configuration settings.  For example setting “export
       AIA_PROMPTS_DIR=~/Documents/prompts” will over-ride the default configuration;
       however, a config value provided by a command line options will over-ride an envar
       setting.

       Configuration values found in a config file will over-ride all other values set for a
       config item.

       ”//config” directives found inside a prompt file over-rides that config item
       regardless of where the value was set.

       For example “//config chat? = true” within a prompt will setup the chat back and forth
       chat session for that specific prompt regardless of the command line options or the
       envar AIA_CHAT settings

OpenAI ACCOUNT IS REQUIRED
       Additionally, the program requires an OpenAI access key, which can be specified using
       one of the following environment variables:

              • OPENAI_ACCESS_TOKEN

              • OPENAI_API_KEY

       Currently there is not specific standard for name of the OpenAI key.  Some programs
       use one name, while others use a different name.  Both of the envars listed above mean
       the same thing.  If you use more than one tool to access OpenAI resources, you may
       have to set several envars to the same key value.

       To acquire an OpenAI access key, first create an account on the OpenAI platform, where
       further documentation is available.

USAGE NOTES
       aia is designed for flexibility, allowing users to pass prompt ids and context files
       as arguments. Some options change the behavior of the output, such as --output for
       specifying a file or --no-output for disabling file output in favor of standard output
       (STDPIT).

       The --completion option displays a script that enables prompt ID auto-completion for
       bash, zsh, or fish shells. It’s crucial to integrate the script into the shell’s
       runtime to take effect.

       The --dump options will send the current configuration to STDOUT in the format
       requested.  Both YAML and TOML formats are supported.

PROMPT DIRECTIVES
       Within a prompt text file any line that begins with “//” is considered a prompt
       directive.  There are numerious prompt directives available.  In the discussion above
       on the configuration you learned about the “//config” directive.

       Detail discussion on individual prompt directives is TBD.  Most likely it will be
       handled in the github wiki <https://github.com/MadBomber/aia>

SEE ALSO

              • OpenAI Platform Documentation <https://platform.openai.com/docs/overview>
                 for more information on obtaining access tokens
                <https://platform.openai.com/account/api-keys>
                 and working with OpenAI models.

              • mods <https://github.com/charmbracelet/mods>
                 for more information on mods - AI for the command line, built for pipelines.
                LLM based AI is really good at interpreting the output of commands and
                returning the results in CLI friendly text formats like Markdown. Mods is a
                simple tool that makes it super easy to use AI on the command line and in
                your pipelines. Mods works with OpenAI
                <https://platform.openai.com/account/api-keys>
                 and LocalAI <https://github.com/go-skynet/LocalAI>

              • sgpt <https://github.com/tbckr/sgpt>
                 (aka shell-gpt) is a powerful command-line interface (CLI) tool designed for
                seamless interaction with OpenAI models directly from your terminal.
                Effortlessly run queries, generate shell commands or code, create images from
                text, and more, using simple commands. Streamline your workflow and enhance
                productivity with this powerful and user-friendly CLI tool.

AUTHOR
       Dewayne VanHoozer <dvanhoozer@gmail.com>

AIA                                       2024-01-01                                   aia(1)

```

## System Environment Variables (envar)

The `aia` configuration defaults can be over-ridden by envars with the prefix "AIA_" followed by the config item name also in uppercase. All configuration items can be over-ridden in this way by an envar.  The following table show a few examples.

| Config Item   | Default Value | envar key |
| ------------- | ------------- | --------- |
| backend       | mods          | AIA_BACKEND |
| config_file   | nil           | AIA_CONFIG_FILE |
| debug         | false         | AIA_DEBUG |
| edit          | false         | AIA_EDIT |
| extra         | ''            | AIA_EXTRA |
| fuzzy         | false         | AIA_FUZZY |
| log_file      | ~/.prompts/_prompts.log | AIA_LOG_FILE |
| markdown      | true          | AIA_MARKDOWN |
| model         | gpt-4-1106-preview | AIA_MODEL |
| output_file   | temp.md       | AIA_OUTPUT_FILE |
| prompts_dir   | ~/.prompts    | AIA_PROMPTS_DIR |
| VERBOSE       | FALSE         | AIA_VERBOSE |


See the `@options` hash in the `cli.rb` file for a complete list.  There are some config items that do not necessarily make sense for use as an envar over-ride.  For example if you set `export AIA_DUMP=yaml` then `aia` would dump a config file in HAML format and exit every time it is ran until you finally did `unset AIA_DUMP`

In addition to these config items for `aia` the optional command line parameters for the backend prompt processing utilities (mods and sgpt) can also be set using envars with the "AIA_" prefix.  For example "export AIA_TOPP=1.0" will set the "--topp 1.0" command line option for the `mods` utility when its used as the backend processor.

## Prompt Directives

Downstream processing directives were added to the `prompt_manager` gem at version 0.4.1.  These directives are lines in the prompt text file that begin with "//"

For example if a prompt text file has this line:

> //config chat? = true

That prompt will enter the chat loop regardles of the presents of a "--chat" CLI option or the setting of the envar AIA_CHAT.

BTW did I mention that `aia` supports a chat mode where you can send an initial prompt to the backend and then followup the backend's reponse with additional keyboard entered questions, instructions, prompts etc.

See the [AIA::Directives](lib/aia/directives.rb) class to see what directives are available on the fromend within `aia`.

See the [AIA::Mods](lib/aia/tools/mods.rb) class to for directives that are available to the `mods` backend.

See the [AIA::Sgpt](lib/aia/tools/sgpt.rb) class to for directives that are available to the `sgpt` backend.


## External CLI Tools Used

```text
External Tools Used
-------------------

To install the external CLI programs used by aia:
  brew install fzf mods rg

fzf
  Command-line fuzzy finder written in Go
  https://github.com/junegunn/fzf

mods
  AI on the command-line
  https://github.com/charmbracelet/mods

rg
  Search tool like grep and The Silver Searcher
  https://github.com/BurntSushi/ripgrep

A text editor whose executable is setup in the
system environment variable 'EDITOR' like this:

export EDITOR="subl -w"

```

## Shell Completion

You can setup a completion function in your shell that will complete on the prompt_id saved in your `prompts_dir` - functions for `bash`, `fish` and `zsh` are available.  To get a copy of these functions do this:

> `aia --completion bash`

If you're not a fan of "born again" replace `bash` with one of the others.

Copy the function to a place where it can be installed in your shell's instance.  This might be a `.profile` or `.bashrc` file, etc.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
