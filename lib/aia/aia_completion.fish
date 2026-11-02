# lib/aia/aia_completion.fish
# Setup a prompt completion for use with the fish shell
#
# Prompt IDs come from $AIA_PROMPTS__DIR, or ~/.prompts when it is unset.

function __fish_aia_complete
  # Get the command line and current token
  set -l cmd_line (commandline -opc)
  set -l current_token (commandline -ct)
  
  # Check if we are currently completing the option that requires prompt IDs
  if set -q cmd_line[2]
    # Change directory to the prompts directory
    set -l prompts_dir ~/.prompts
    set -q AIA_PROMPTS__DIR; and set prompts_dir $AIA_PROMPTS__DIR
    if test -d $prompts_dir
      pushd $prompts_dir
      # Generate completions based on .md files in the prompts directory
      for file in (find . -name "*.md" -type f)
        set file (string replace -r '\.md$' '' -- $file)
        set file (string replace -r '^\./' '' -- $file)
        printf "%s\n" $file
      end
      popd
    end
  else
    # Use the default file completion if we are not completing a prompt ID
    complete -f -c aia -a "(commandline -ct)"
  end
end

# Register the completion function for the aia command
complete -c aia -a '(__fish_aia_complete)' -f


