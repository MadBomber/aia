<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

- [AI Assistant (AIA)](#ai-assistant-aia)
  - [Installation](#installation)
  - [Usage](#usage)
  - [System Environment Variables (envars)](#system-environment-variables-envars)
  - [External CLI Tools Used](#external-cli-tools-used)
  - [Shell Completion](#shell-completion)
  - [Development](#development)
  - [Contributing](#contributing)
  - [License](#license)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

# AI Assistant (AIA)

**Under Development**

`aia` is a command-line utility that integrates prameterized prompt management with generative AI (gen-AI) execution.

Uses the gem "prompt_manager" to manage the prompts sent to the `mods` command-line utility.  Uses the command line tools "ripgrep" to search for prompts to send and "fzf" to select the prompts that match the search term.



## Installation

Install the gem by executing:

    gem install aia


Install the command-line utilities by executing:

    brew install mods fzf ripgrep

You will also need to establish a directory in your file system where your prompt text files, last used parameters and usage log files are kept.

Setup a system environment variable named "PROMPTS_DIR" that points to your prompts directory.  The default is in your HOME directory named ".prompts_dir"

You will also need to source the completion script.

TODO: May want to add a `setup` function to the command-line options that will create the directory, and do something with the completion function.

TODO: don't forget to mention have access token (API keys) setup as envars for the various backend services like OpenAI... if they are still in business.

## Usage

```text
$ aia --help

aia v0.0.5

Usage:  aia [options] prompt_id [context_file]* [-- external_options+]

Options
-------

Edit the Prompt File  -e --edit
 default: false

Turn On Debugging     -d --debug
 default: false

Be Verbose            -v --verbose
 default: false

Print Version         --version
 default: false

Show Usage            -h --help
 default: false

Use Fuzzy Matching    --fuzzy
 default: false

Out FILENAME          -o --output --no-output
 default: ./temp.md

Log FILEPATH          -l --log --no-log
 default: $HOME/.prompts/_prompts.log

Format with Markdown  -m --markdown --no-markdown --md --no-md
 default: true
```

Turn on `verbose` with `help` to see more usage information that includes system environment variables and external CLI tools that are used.

```text
$ aia --help --verbose
```

## System Environment Variables (envars)

From the verbose help text ...

```text

System Environment Variables Used
---------------------------------

The OUTPUT and PROMPT_LOG envars can be overridden
by cooresponding options on the command line.

Name            Default Value
--------------  -------------------------
PROMPTS_DIR     $HOME/.prompts_dir
AI_CLI_PROGRAM  mods
EDITOR          edit
MODS_MODEL      gpt-4-1106-preview
OUTPUT          ./temp.md
PROMPT_LOG      $PROMPTS_DIR/_prompts.log

These two are required for access the OpenAI
services.  The have the same value but different
programs use different envar names.

To get an OpenAI access key/token (same thing)
you must first create an account at OpenAI.
Here is the link:  https://platform.openai.com/docs/overview

OPENAI_ACCESS_TOKEN
OPENAI_API_KEY
```

## External CLI Tools Used

From the verbose help text ...

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

One of the executables with this gem is `aia_completion.sh` which contains a completion script for hte `aia` such that you specify the first few characters of a prompt ID on the command line and the shell will complete the rest of the ID for you.  It works with the `bash` shell but do not know whether it works with the other shells.

To set the completion you can execute aia_completion.sh` in your `.bashrc`  however, the PROMPTS_DIR environment variable must be set in order for prompt ID to work correctly.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
