# lib/aia/aia_completion.fish
# Setup a prompt completion for use with the fish shell
#
# This script assumes that the system environment
# variable AIA_PROMPTS__DIR has been set correctly

function __fish_aia_complete
  # Get the command line and current token
  set -l cmd_line (commandline -opc)
  set -l current_token (commandline -ct)
  
  # Check if we are currently completing the option that requires prompt IDs
  if set -q cmd_line[2]
    # Change directory to the prompts directory
    if test -d $AIA_PROMPTS__DIR
      pushd $AIA_PROMPTS__DIR
      # Generate completions based on .txt files in the AIA_PROMPTS__DIR directory
      for file in (find . -name "*.txt" -type f)
        set file (string replace -r '\.txt$' '' -- $file)
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


