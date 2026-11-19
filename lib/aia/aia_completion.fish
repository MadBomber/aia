# lib/aia/aia_completion.fish
# Setup a prompt completion for use with the fish shell
#
# Prompt IDs come from $AIA_PROMPTS__DIR, or ~/.prompts when it is unset.

function __fish_aia_prompt_ids
  set -l prompts_dir ~/.prompts
  set -q AIA_PROMPTS__DIR; and set prompts_dir $AIA_PROMPTS__DIR
  test -d $prompts_dir; or return

  for file in (cd $prompts_dir; and find . -name "*.md" -type f)
    set file (string replace -r '\.md$' '' -- $file)
    string replace -r '^\./' '' -- $file
  end
end

# The first argument after aia is a prompt ID; later arguments keep fish's
# ordinary file completion.
complete -c aia -n 'test (count (commandline -opc)) -eq 1' -f -a '(__fish_aia_prompt_ids)'
