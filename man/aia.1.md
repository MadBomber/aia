# aia 1 "2024-01-01" AIA "User Manuals"

## NAME

aia - Artificial Intelligence Assistant

## SYNOPSIS

`aia` [*options*] *PROMPT_NAME* [*CONTEXT_FILES*] [*EXTERNAL_OPTIONS*]

## DESCRIPTION

The `aia` utility provides front-end parameterized prompt management to backend gen-AI utilities such as `mods` and `sgpt`

*options* can appear anywhere on the command line.

TODO: write the "options" section

TODO: write the "see also" section

## ARGUMENTS

*PROMPT_NAME*
: This is a required argument.

*CONTEXT_FILES*
: This is an optional argument.  One or more files can be added to the prompt as context for the backend gen-AI tool to process.

*EXTERNAL_OPTIONS*
: External options are optional.  Anything that follow " -- " will be sent to the backend gen-AI tool.  For example "-- -C -m gpt4-128k" will send the options "-C -m gpt4-128k" to the backend gen-AI tool.  `aia` will not validate these external options before sending them to the backend gen-AI tool.

## OPTIONS

`-f`, `--flag` *VALUE*
: This is an option flag that takes a *VALUE* argument.

`-h`, `--help`
: Prints the help information for the command.

## EXAMPLES

Sends the prompt "ruby_expert" with is embedded parameters substituted for user input along with the file my_class.rb to the backend gen-AT tool for processing:

    $ aia ruby_expert some_class.rb

## AUTHOR

Dewayne VanHoozer <dvanhoozer@gmail.com>

## SEE ALSO

[bash(1)](man:bash.1) [other-man-page](other-man-page.1.md)
