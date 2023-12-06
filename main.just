# aia/main.just

RR := env_var('RR')

with ~/.justfile
with ~/sandbox/git_repos/repo.just
with ~/sandbox/git_repos/gem.just

# FIXME: justprep module process still has an issue with ~ and $HOME
module version /Users/dewayne/just_modules/version.just


# Preview man page
preview_man_page:
  kramdown-man {{RR}}/man/aia.1.md


# View man page
view_man_page: create_man_page
  man {{RR}}/man/aia.1


# Create man page
create_man_page:
  rake man

##########################################

# Tag the current commit, push it, then bump the version
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

