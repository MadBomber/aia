# lib/aia/aia_completion.zsh
# Setup a prompt completion for use with
# the zsh shell
#
# Prompt IDs come from $AIA_PROMPTS__DIR, or ~/.prompts when it is unset.

_aia_completion() {
  # The first argument after aia is a prompt ID; everything else is a file.
  if (( CURRENT == 2 )); then
    local prompts_dir="${AIA_PROMPTS__DIR:-$HOME/.prompts}"
    local -a prompt_ids
    if [[ -d "$prompts_dir" ]]; then
      prompt_ids=(${(f)"$(cd "$prompts_dir" && find . -name '*.md' -type f | sed -e 's|^\./||' -e 's/\.md$//')"})
    fi
    _describe 'prompt ID' prompt_ids
  else
    _files
  fi
}

# Register with the completion system, initializing it first if needed.
if ! (( $+functions[compdef] )); then
  autoload -Uz compinit && compinit
fi
compdef _aia_completion aia
