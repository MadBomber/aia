# aia 1 "2024-01-01" AIA "User Manuals"

## NAME
aia - command-line interface for an AI assistant  

## SYNOPSIS
aia [options]* PROMPT_ID [CONTEXT_FILE]* [-- EXTERNAL_OPTIONS+]  

## DESCRIPTION

The aia command-line tool is an interface for interacting with an AI model backend, providing a simple way to send prompts and receive responses. The CLI supports various options to customize the interaction, load a configuration file, edit prompts, set debugging levels, and more.

## ARGUMENTS

*PROMPT_ID*
: This is a required argument.

*CONTEXT_FILES*
: This is an optional argument.  One or more files can be added to the prompt as context for the backend gen-AI tool to process.

*EXTERNAL_OPTIONS*
: External options are optional.  Anything that follow " -- " will be sent to the backend gen-AI tool.  For example "-- -C -m gpt4-128k" will send the options "-C -m gpt4-128k" to the backend gen-AI tool.  `aia` will not validate these external options before sending them to the backend gen-AI tool.

## OPTIONS

`-c`, `--config` *PATH_TO_CONFIG_FILE*
: Load Config File - default: nil

`--dump` *FORMAT*
: Dump a Config File in [yaml | toml] to STDOUT - default: nil

`-e`, `--edit`
: Edit the Prompt File - default: false

`-d`, `--debug`
: Turn On Debugging - default: false

`-v`, `--verbose`
: Be Verbose - default: false

`--version`
: Print Version - default: false

`-h`, `--help`
: Show Usage - default: false

`-s`, `--search` *TERM*
: Search for prompts contain TERM - default: nil

`-f`, --fuzzy`
: Use Fuzzy Matching when searching for a prompt - default: false

`--completion` *SHELL_NAME*
: Show completion script for bash|zsh|fish - default: nil

`-o`, `--[no]-output` *PATH_TO_OUTPUT_FILE*
: Out FILENAME - default: ./temp.md

`-l`, `--[no]-log` *PATH_TO_LOG_FILE*
: Log FILEPATH - default: $HOME/.prompts/prompts.log

`-m`, `--[no]-markdown`
: Format with Markdown - default: true

`--model` *NAME*
: Name of the LLM model to use - default: gpt-4-1106-preview

`-p`, `--prompts` *PATH_TO_DIRECTORY*
: Directory containing the prompt files - default: ~/.prompts

`-b`, `--[no]-backend` *LLM TOOL*
: Specify the backend prompt resolver - default: :mods

## ENVIRONMENT  
The aia CLI uses the following environment variables:

- `AIA_PROMPTS_DIR`: Path to the directory containing prompts files - default: `$HOME/.prompts_dir`
- `AIA_BACKEND`: The AI command-line program used - default: `mods`
- `EDITOR`: The text editor used by the edit option - default: edit
- `AIA_MODEL`: The AI model specification - default: `gpt-4-1106-preview`
- `AIA_OUTPUT`: The default filename for output - default: `./temp.md`
- `AIA_PROMPT_LOG`: The default filepath for the prompts log - default: `$HOME/.prompts/_prompts.log`

Additionally, the program requires an OpenAI access key, which can be specified using one of the following environment variables:

- `OPENAI_ACCESS_TOKEN`
- `OPENAI_API_KEY`

Currently there is not specific standard for name of the OpenAI key.  Some programs use one name, while others use a different name.  Both of the envars listed above mean the same thing.  If you use more than one tool to access OpenAI resources, you may have to set several envars to the same key value.

To acquire an OpenAI access key, first create an account on the OpenAI platform, where further documentation is available.

## USAGE NOTES  
`aia` is designed for flexibility, allowing users to pass prompt ids and context files as arguments. Some options change the behavior of the output, such as `--output` for specifying a file or `--no-output` for disabling file output in favor of standard output.

The `--completion` option displays a script that enables prompt ID auto-completion for bash, zsh, or fish shells. It's crucial to integrate the script into the shell's runtime to take effect.

## SEE ALSO  
- [OpenAI Platform Documentation](https://platform.openai.com/docs/overview) for more information on [obtaining access tokens](https://platform.openai.com/account/api-keys) and working with OpenAI models.

- [mods](https://github.com/charmbracelet/mods) for more information on `mods` - AI for the command line, built for pipelines.  LLM based AI is really good at interpreting the output of commands and returning the results in CLI friendly text formats like Markdown. Mods is a simple tool that makes it super easy to use AI on the command line and in your pipelines. Mods works with [OpenAI](https://platform.openai.com/account/api-keys) and [LocalAI](https://github.com/go-skynet/LocalAI)

- [sgpt](https://github.com/tbckr/sgpt) (aka shell-gpt) is a powerful command-line interface (CLI) tool designed for seamless interaction with OpenAI models directly from your terminal. Effortlessly run queries, generate shell commands or code, create images from text, and more, using simple commands. Streamline your workflow and enhance productivity with this powerful and user-friendly CLI tool.

## AUTHOR

Dewayne VanHoozer <dvanhoozer@gmail.com>
