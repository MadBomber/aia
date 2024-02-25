# AI Assistant (AIA)

`aia` is a command-line utility that facilitates interaction with AI models. It automates the management of pre-compositional prompts and executes generative AI (Gen-AI) commands on those prompts.

It leverages the `prompt_manager` gem to manage prompts for the `mods` and `sgpt` CLI utilities. It utilizes "ripgrep" for searching for prompt files.  It uses `fzf` for prompt selection based on a search term and fuzzy matching.

**Most Recent Change**: Refer to the [Changelog](CHANGELOG.md)

> v0.5.12
> - Supports Prompt Sequencing
> - Added --next option
> - Added --pipeline option
>
> v0.5.11
> - Allow directives to prepend content into the prompt text
> - Added //include  path_to_file
> - Added //shell    shell_command
> - Added //ruby     ruby code

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Installation](#installation)
  - [Usage](#usage)
  - [Configuration Using Envars](#configuration-using-envars)
  - [Shell Integration inside of a Prompt](#shell-integration-inside-of-a-prompt)
      - [Access to System Environment Variables](#access-to-system-environment-variables)
      - [Dynamic Shell Commands](#dynamic-shell-commands)
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
    - [Backend Directive Commands](#backend-directive-commands)
    - [Using Directives in Chat Sessions](#using-directives-in-chat-sessions)
  - [Prompt Sequences](#prompt-sequences)
    - [--next](#--next)
    - [--pipeline](#--pipeline)
    - [Best Practices ??](#best-practices-)
  - [All About ROLES](#all-about-roles)
    - [The --roles_dir (AIA_ROLES_DIR)](#the---roles_dir-aia_roles_dir)
    - [The --role Option](#the---role-option)
    - [Other Ways to Insert Roles into Prompts](#other-ways-to-insert-roles-into-prompts)
  - [External CLI Tools Used](#external-cli-tools-used)
  - [Shell Completion](#shell-completion)
  - [My Most Powerful Prompt](#my-most-powerful-prompt)
  - [My Configuration](#my-configuration)
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

Setup a system environment variable (envar) named "AIA_PROMPTS_DIR" that points to your prompts directory.  The default is in your HOME directory named ".prompts". The envar "AIA_ROLES_DIR" points to your role directory where you have prompts that define the different roles you want the LLM to assume when it is doing its work.  The default roles directory is inside the prompts directory.  Its name is "roles".

You may also want to install the completion script for your shell.  To get a copy of the completion script do:

`aia --completion bash`

`fish` and `zsh` are also available.


## Usage

The usage report obtained using either `-h` or `--help` is implemented as a standard `man` page.  You can use both `--help --verbose` of `-h -v` together to get not only the `aia` man page but also the usage report from the `backend` LLM processing tool.

```shell
$ aia --help
```

## Configuration Using Envars

The `aia` configuration defaults can be over-ridden by system environment variables *(envars)* with the prefix "AIA_" followed by the config item name also in uppercase. All configuration items can be over-ridden in this way by an envar.  The following table show a few examples.

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
| out_file       | STDOUT        | AIA_OUT_FILE |
| prompts_dir   | ~/.prompts    | AIA_PROMPTS_DIR |
| VERBOSE       | FALSE         | AIA_VERBOSE |


See the `@options` hash in the `cli.rb` file for a complete list.  There are some config items that do not necessarily make sense for use as an envar over-ride.  For example if you set `export AIA_DUMP_FILE=config.yaml` then `aia` would dump the current configuration config.yaml and exit every time it is ran until you finally `unset AIA_DUMP_FILE`

In addition to these config items for `aia` the optional command line parameters for the backend prompt processing utilities (mods and sgpt) can also be set using envars with the "AIA_" prefix.  For example "export AIA_TOPP=1.0" will set the "--topp 1.0" command line option for the `mods` utility when its used as the backend processor.

## Shell Integration inside of a Prompt

Using the option `--shell` enables `aia` to access your terminal's shell environment from inside the prompt text.

#### Access to System Environment Variables

`aia` can replace any system environment variable (envar) references in the prompt text with the value of the envar.  Patterns like $USER and ${USER} in the prompt will be replaced with that envar's value - the name of the user's account.  Any envar can be used.

#### Dynamic Shell Commands

Dynamic content can be inserted into the prompt using the pattern $(shell command) where the output of the shell command will replace the $(...) pattern.

Consider the power to tailoring a prompt to your specific operating system:

```
As a system administration on a $(uname -v) platform what is the best way to [DO_SOMETHING]
```

or insert content from a file in your home directory:

```
Given the following constraints $(cat ~/3_laws_of_robotics.txt) determine the best way to instruct my roomba to clean my kids room.
```

#### Chat Session Use

When you use the `--shell` option to start a chat session, shell integration is available in your follow up prompts.  Suppose you started up a chat session using a roll of "Ruby Expert" expecting to chat about changes that could be made to a specific class BUT you forgot to include the class source file as part of the context when you got started.  You could enter this as your follow up prompt to this to keep going:

```
The class I want to chat about refactoring is this one: $(cat my_class.rb)
```

That inserts the entire class source file into your follow up prompt.  You can continue chatting with you AI Assistant avout changes to the class.

## *E*mbedded *R*u*B*y (ERB)

The inclusion of dynamic content through the shell integration provided by the `--shell` option is significant.  `aia` also provides the full power of embedded Ruby code processing within the prompt text.

The `--erb` option turns the prompt text file into a fully functioning ERB template. The [Embedded Ruby (ERB) template syntax (2024)](https://bophin-com.ngontinh24.com/article/language-embedded-ruby-erb-template-syntax) provides a good overview of the syntax and power of ERB.

Most websites that have information about ERB will give examples of how to use ERB to generate dynamice HTML content for web-based applications.  That is a common use case for ERB.  `aia` on the other hand uses ERB to generate dynamic prompt text.

### Chat Session Behavior

In a chat session whether started by the `--chat` option or its equivalent with a directive within a prompt text file behaves a little differently w/r/t its binding and local variable assignments.  Since a chat session by definition has multiple prompts, setting a local variable in one prompt and expecting it to be available in a subsequent prompt does not work.  You need to use instance variables to accomplish this prompt to prompt carry over of information.

Also since follow up prompts are expected to be a single thing - sentence or paragraph - terminated by a single return, its likely that ERB enhance will be of benefit; but, you may find a use for it.

## Prompt Directives

Downstream processing directives were added to the `prompt_manager` gem used by `au` at version 0.4.1.  These directives are lines in the prompt text file that begin with "//" having this pattern:

```
//command parameters
```

There is no space between the "//" and the command.

### Parameter and Shell Substitution in Directives 

When you combine prompt directives with prompt parameters and shell envar substitutions you can get some powerful compositional prompts.

Here is an example of a pure generic directive.

```
//[DIRECTIVE_NAME] [DIRECTIVE_PARAMS]
```

When the prompt runs, you will be asked to provide a value for each of the parameters.  You could answer "shell" for the directive name and "calc 22/7" if you wanted a bad approximation of PI.

Try this prompt file:
```
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

```
//config chat? = true
//config terse? = true
```

A configuration item such as `--out_file` or `--model` has an associated value on the command line.  To set that value with the `//config` directive do it like this:

```
//config model = gpt-3.5-turbo
//config out_file = temp.md
//config backend = mods
```

BTW: the "=" is completely options.  Its actuall ignored as is ":=" if you were to choose that as your assignment operator.  Also the number of spaces between the item and the value is complete arbitrary.  I like to line things up so this syntax is just as valie:

```
//config model       gpt-3.5-turbo
//config out_file    temp.md
//config backend     mods
//config chat?       true
//config terse?      true
//config model       gpt-4
```

NOTE: if you specify the same config item name more than once within the prompt file, its the last one which will be set when the prompt is finally process through the LLM.  For example in the example above `gpt-4` will be the model used.  Being first does not count in this case.

#### //include

Example:
```
//include path_to_file
```

The `path_to_file` can be either absolute or relative.  If it is relative, it is achored at the PWD.  If the `path_to_file` includes envars, the `--shell` CLI option must be used to replace the envar in the directive with its actual value.

The file that is included will have any comments or directives excluded.  It is expected that the file will be a text file so that its content can be pre-pended to the existing prompt; however, if the file is a source code file (ex: file.rb) the source code will be included HOWEVER any comment line or line that starts with "//" will be excluded.

TODO:  Consider adding a command line option `--include_dir` to specify the place from which relative files are to come.

#### //ruby
Example:
```
//ruby any_code_that_returns_an_instance_of_String
```

This directive is in addition to ERB.  At this point the `//ruby` directive is limited by the current binding which is within the `AIA::Directives#ruby` method.  As such it is not likely to see much use.

However, sinces it implemented as a simple `eval(code)` then there is a potential for use like this:
```
//ruby load(some_ruby_file); execute_some_method
```

Each execution of a `//ruby` directive will be a fresh execution of the `AIA::Directives#ruby` method so you cannot carry local variables from one invocation to another; however, you could do something with instance variables or global variables.  You might even add something to the `AIA.config` object to be pasted on to the next invocation of the directive within the context of the same prompt.

#### //shell
Example:
```
//shell some_shell_command
```

It is expected that the shell command will return some text to STDOUT which will be pre-pending to the existing prompt text within the prompt file.

There are no limitations on what the shell command can be.  For example if you wanted to bypass the stripping of comments and directives from a file you could do something like this:
```
//shell cat path_to_file
```

Which does basically the same thing as the `//include` directive, except it uses the entire content of the file.  For relative file paths the same thing applies.  The file's path will be relative to the PWD.



### Backend Directive Commands

See the source code for the directives supported by the backends which at this time are configuration-based as well.

- [mods](lib/aia/tools/mods.rb)
- [sgpt](lib/aia/tools/sgpt.rb)

For example `mods` has a configuration item `topp` which can be set by a directive in a prompt text file directly.

```
//topp 1.5
```

If `mods` is not the backend the `//topp` direcive is ignored.

### Using Directives in Chat Sessions

Whe you are in a chat session, you may use a directive as a follow up prompt.  For example if you started the chat session with the option `--terse` expecting to get short answers from the backend; but, then you decide that you want more comprehensive answers you may do this:

```
//config terse? false
```

The directive is executed and a new follow up prompt can be entered with a more lengthy response generated from the backend.


## Prompt Sequences

Why would you need/want to use a sequence of prompts in a batch situation.  Maybe you have a complex prompt which exceeds the token limitations of your model for input so you need to break it up into multiple parts.  Or suppose its a simple prompt but the number of tokens on the output is limited and you do not get exactly the kind of full response for which you were looking.

Sometimes it takes a series of prompts to get the kind of response that you want.  The reponse from one prompt becomes a context for the next prompt.  This is easy to do within a `chat` session were you are manually entering and adjusting your prompts until you get the kind of response that you want.

If you need to do this on a regular basis or within a batch you can use `aia` and the `--next` and `--pipeline` command line options.

These two options specify the sequence of prompt IDs to be processed. Both options are available to be used within a prompt file using the `//config` directive.  Like all embedded directives you can take advantage of parameterization shell integration and Ruby.  I'm start to feel like TIm Tool man - more power!

Consider the condition in which you have 4 prompt IDs that need to be processed in sequence.  The IDs and associated prompt file names are:

| Promt ID | Prompt File |
| -------- | ----------- |
| one.     | one.txt     |
| two.     | two.txt     |
| three.   | three.txt   |
| four.    | four.txt    |


### --next

```shell
export AIA_OUT_FILE=temp.md 
aia one --next two
aia three --next four temp.md
```

or within each of the prompt files you use the config directive:

```
one.txt contains //config next two
two.txt contains //config next three
three.txt contains //config next four
```
BUT if you have more than two prompts in your sequence then consider using the --pipeline option.

### --pipeline

`aia one --pipeline two,three,four`

or inside of the `one.txt` prompt file use this directive:

`//config pipeline two,three,four`

### Best Practices ??

Since the response of one prompt is fed into the next prompt within the sequence instead of having all prompts write their response to the same out file, use these directives inside the associated prompt files:


| Prompt File | Directive |
| --- | --- |
| one.txt | //config out_file one.md |
| two.txt | //config out_file two.md |
| three.txt | //config out_file three.md |
| four.txt | //config out_file four.md |

This way you can see the response that was generated for each prompt in the sequence.

## All About ROLES

### The --roles_dir (AIA_ROLES_DIR)

There are two kinds of prompts
1. instructional - tells the LLM what to do
2. personification - tells the LLM who it should pretend to be when it does its transformational work.

That second kind of prompt is called a role.  Sometimes the role is incorporated into the instruction.  For example "As a magician make a rabbit appear out of a hat."  To reuse the same role in multiple prompts `aia` encourages you to designate a special `roles_dir` into which you put prompts that are specific to personification - roles.

The default `roles_dir` is a sub-directory of the `prompts_dir` named roles.  You can, however, put your `roles_dir` anywhere that makes sense to you.

### The --role Option

The `--role` option is used to identify a personification prompt within your roles directory which defines the context within which the LLM is to provide its response.  The text of the role ID is pre-pended to the text of the primary prompt to form a complete prompt to be processed by the backend.

For example consider:

```shell
aia -r ruby refactor my_class.rb
```

Within the roles directory the contents of the text file `ruby.txt` will be pre-pre-pended to the contents of the `refactor.txt` file from the prompts directory to produce a complete prompt.  That complete prompt will have any parameters followed by directives processed before sending the combined prompt text to the backend.

Note that `--role` is just a way of saying add this prompt text file to the front of this other prompt text file.  The contents of the "role" prompt could be anything.  It does not necessarily have be an actual role.

`aia` fully supports a directory tree within the `prompts_dir` as a way of organization or classification of your different prompt text files.

```shell
aia -r sw_eng doc_the_methods my_class.rb
```

In this example the prompt text file `$AIA_ROLES_DIR/sw_eng.txt` is prepended to the prompt text file `$AIA_PROMPTS_DIR/doc_the_methods.txt`


### Other Ways to Insert Roles into Prompts

Since `aia` supports parameterized prompts you could make a keyword like "[ROLE]" be part of your prompt.  For example consider this prompt:

```text
As a [ROLE] tell me what you think about [SUBJECT]
```

When this prompt is processed, `aia` will ask you for a value for the keyword "ROLE" and the keyword "SUBJECT" to complete the prompt.  Since `aia` maintains a history of your previous answers, you could just choose something that you used in the past or answer with a completely new value.

## External CLI Tools Used

To install the external CLI programs used by aia:
  
  brew install fzf mods rg glow

fzf
  Command-line fuzzy finder written in Go
  [https://github.com/junegunn/fzf](https://github.com/junegunn/fzf)

mods
  AI on the command-line
  [https://github.com/charmbracelet/mods](https://github.com/charmbracelet/mods)

rg
  Search tool like grep and The Silver Searcher
  [https://github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)

glow
  Render markdown on the CLI
  [https://github.com/charmbracelet/glow](https://github.com/charmbracelet/glow)

A text editor whose executable is setup in the
system environment variable 'EDITOR' like this:

  export EDITOR="subl -w"



## Shell Completion

You can setup a completion function in your shell that will complete on the prompt_id saved in your `prompts_dir` - functions for `bash`, `fish` and `zsh` are available.  To get a copy of these functions do this:

```shell
aia --completion bash
```

If you're not a fan of "born again" replace `bash` with one of the others.

Copy the function to a place where it can be installed in your shell's instance.  This might be a `.profile` or `.bashrc` file, etc.

## My Most Powerful Prompt

This is just between you and me so don't go blabbing this around to everyone.  My most power prompt is in a file named `ad_hoc.txt`. It looks like this:

> [WHAT NOW HUMAN]

Yep.  Just a single parameter for which I can provide a value of anything that is on my mind at the time.  Its advantage is that I do not pollute my shell's command history with lots of text.

Which do you think is better to have in your shell's history file?

```shell
mods "As a certified public accountant specializing in forensic audit and analysis of public company financial statements, what do you think of mine?  What is the best way to hide the millions dracma that I've skimmed?"  < financial_statement.txt
```

or

```shell
aia ad_hoc financial_statement.txt
```

Both do the same thing; however, `aia` does not put the text of the prompt into the shell's history file.... of course the keyword/parameter value is saved in the prompt's JSON file and the prompt with the response are logged unless `--no-log` is specified; but, its not messing up the shell history!

## My Configuration

I use the `bash` shell.  In my `.bashrc` file I source another file named `.bashrc__aia` which looks like this:

```shell
# ~/.bashic_aia
# AI Assistant

# These are the defaults:
export AIA_PROMPTS_DIR=~/.prompts
export AIA_OUT_FILE=./temp.md
export AIA_LOG_FILE=$AIA_PROMPTS_DIR/_prompts.log
export AIA_BACKEND=mods
export AIA_MODEL=gpt-4-1106-preview

# Not a default.  Invokes spinner.
export AIA_VERBOSE=true

alias chat='aia chat --terse'

# rest of the file is the completion function
```

Here is what my `chat` prompt file looks like:

```shell
# ~/.prompts/chat.txt
# Desc: Start a chat session

//config chat? = true

[WHAT]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

I've designed `aia` so that it should be easy to integrate other backend LLM processors.  If you've found one that you like, send me a pull request or a feature request.

When you find problems with `aia` please note them as an issue.  This thing was written mostly by a human and you know how error prone humans are.  There should be plenty of errors to find.

I've been thinking that the REGEX used to identify a keyword within a prompt could be a configuration item.  I chose to use square brackets and uppercase in the default regex; maybe, you have a collection of prompt files that use some other regex.  Why should it be one way and not the other.

Also I'm not happy with the way where I a some command line options for external command hard coded.  I think they should be part of the configuration as well.  For example the way I'm using `rg` and `fzf` may not be the way that you want to use them.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
