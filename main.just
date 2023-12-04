# aia/main.just

RR := env_var('RR')

with ~/.justfile
with ~/sandbox/git_repos/repo.just
with ~/sandbox/git_repos/gem.just

# FIXME: module process still has an issue with ~ and $HOME
module version /Users/dewayne/just_modules/version.just



##########################################
tag_push_and_bump: tag push bump

tag:
  git tag $(semver)

push:
  git push
  git push origin --tags

@bump:
  semver increment patch
  echo "Now working on: $(semver)"
  git add {{RR}}/.semver

