# examples/plugins/git_context.rb
#
# Inject a snapshot of the current git repo into a prompt with ERB:
#   <%= git_context %>                          # branch + recent commits + dirty files
#   <%= git_context(commits: 10, diff: true) %> # also include the working-tree diff
#
# Returns a String so it composes with <%= ... %>. Gives the model what you're
# actually working on, so it can write commit messages, review changes, or
# answer "what did I just do?" with real context instead of guesses.
#
# Edit this file while `bin/aia --chat` is running and the plugin monitor will
# hot-reload it — the next prompt uses the new version.

def git_context(commits: 5, diff: false)
  return "(not a git repository)" unless system("git rev-parse --git-dir > /dev/null 2>&1")

  branch = `git rev-parse --abbrev-ref HEAD`.strip
  log    = `git log --oneline -#{commits.to_i}`.strip
  status = `git status --short`.strip

  out = +"# Git context\n"
  out << "Branch: #{branch}\n\n"
  out << "Recent commits:\n#{log.empty? ? '(none)' : log}\n\n"
  out << (status.empty? ? "Working tree: clean\n" : "Uncommitted changes:\n#{status}\n")
  out << "\n```diff\n#{`git diff`.strip}\n```\n" if diff
  out
end
