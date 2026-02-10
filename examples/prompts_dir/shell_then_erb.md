My OS is <%= "$(uname -s)".downcase %>.
My shell is <%= "$SHELL".split('/').last %>.
There are <%= "$(ls prompts_dir | wc -l)".strip %> files in prompts_dir.
Uptime output has <%= "$(uptime)".length %> characters.

Summarize the info above in one sentence.
