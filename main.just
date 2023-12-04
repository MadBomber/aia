# aia/main.just

with ~/.justfile
with ~/sandbox/git_repos/repo.just
with ~/sandbox/git_repos/gem.just

# FIXME: module process still has an issue with ~ and $HOME
module version /Users/dewayne/just_modules/version.just
