# aia/main.just
#

RR                := env_var('RR')
version_filepath  := env_var('RR') + "/.version"

with ~/.justfile

# FIXME: justprep module process still has an issue with ~ and $HOME
# FIXME: justprep does not like more than one space between module name and path.

module repo /Users/dewayne/sandbox/git_repos/repo.just
module gem /Users/dewayne/sandbox/git_repos/gem.just
module version /Users/dewayne/just_modules/version_versionaire.just
module git /Users/dewayne/just_modules/git.just


# Install Locally
install: update_toc_in_readmen flay
  rake install


# Create the TOC
update_toc_in_readmen:
  rake toc


# Static Code Check
flay: coverage
  flay {{RR}}


# View coverage report
coverage: test
  open {{RR}}/coverage/index.html


# Run Unit Tests
test:
  rake test


# Generate the Documentation
gen_doc: update_toc_in_readmen


##########################################

# Tag the current commit, push it, then bump the version
tag_push_and_bump: tag push bump


# Create a git tag for the current version
tag:
  git tag v`head -1 {{version_filepath}}`

# Push the git current working directory and all tags
push:
  git push
  git push origin --tags


alias inc := bump

# Increment version's level: major.minor.patch
@bump level='patch':
  #!/usr/bin/env ruby
  require 'versionaire'
  old_version = Versionaire::Version File.read("{{version_filepath}}").strip
  level = "{{level}}".to_sym
  new_version = old_version.bump level
  puts "Bumping #{level}:  #{old_version} to #{new_version}"
  File.open("{{version_filepath}}", 'w')
  .write(new_version.to_s + "\n")
  #
  `git add {{version_filepath}}`
