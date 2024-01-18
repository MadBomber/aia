# aia/main.just
#
# Support man pages with ...
# gem install kramdown-man
#

RR := env_var('RR')

with ~/.justfile

# FIXME: justprep module process still has an issue with ~ and $HOME
# FIXME: justprep does not like more than one space between module name and path.

module repo /Users/dewayne/sandbox/git_repos/repo.just
module gem /Users/dewayne/sandbox/git_repos/gem.just
module version /Users/dewayne/just_modules/version.just
module git /Users/dewayne/just_modules/git.just


# Install Locally
install: update_toc_in_readmen create_man_page flay
  rake install


# Create the TOC
update_toc_in_readmen:
  rake toc


# Preview man page
preview_man_page:
  kramdown-man {{RR}}/man/aia.1.md

# Static Code Check
flay: coverage
  flay {{RR}}


# View coverage report
coverage: test
  open {{RR}}/coverage/index.html


# Run Unit Tests
test:
  rake test
  

# View man page
view_man_page: create_man_page
  man {{RR}}/man/aia.1


# Create man page
create_man_page:
  rake man

##########################################

# Tag the current commit, push it, then bump the version
tag_push_and_bump: tag push bump


# Create a git tag for the current version
tag:
  git tag $(semver)

# Push the git current working directory and all tags
push:
  git push
  git push origin --tags


alias inc := bump

# Increament version's level: major.minor.patch
@bump level='patch':
  semver increment {{level}}
  echo "Now working on: $(semver)"
  git add {{RR}}/.semver

