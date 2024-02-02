# aia/main.just
#
# Support man pages with ...
# gem install kramdown-man
#

RR := env_var('RR')

# with ~/.justfile

# >>> /Users/dewayne/.justfile
# ~/.justfile
# brew install just
# gem install justprep OR brew install justprep for the Crystal version
# alias jj='justprep && just'
#
# See: https://cheatography.com/linux-china/cheat-sheets/justfile/
#

# high-level just directives

set fallback # search up for recipe name if not found locally.

set positional-arguments    := true
set allow-duplicate-recipes := true
set dotenv-load             := false

# my common variables

pwd         := env_var('PWD')

me          := justfile()

home          := env_var('HOME')
downloads_dir := env_var('HOME') + "/Downloads/"
documents_dir := env_var('HOME') + "/Documents/"

backup_dir  := env_var('JUST_BACKUP_DIR')
backup_file := trim_start_match(me, home)
my_backup   := backup_dir + backup_file
project     := "`basename $RR`"


# List available recipes
@list:
  echo
  echo "Available Recipes at"
  echo "$PWD"
  echo "are:"
  echo
  just -l --list-prefix 'jj ' --list-heading ''
  echo
  echo "jj <module_name> to see sub-tasks"
  echo


# Show help/usage for "just" command
@help: list
  just --help


# Backup .envrc & *.just files
@backup_support_files: _backup_all_just_files _backup_all_envrc_files


# Backup all changed just files to $JUST_BACKUP_DIR
@_backup_all_just_files:
  backup_just.rb


# backup all changed envrc files to ENVRC_BACKUP_DIR
@_backup_all_envrc_files:
  backup_envrc.rb


# Delete all mods saved conversations
mods_delete_all:
  mods -l | awk '{print $1}' | xargs -I {} mods -d {}


#################################################
## Private recipes

# Show private recipes
@show_private:     # Show private recipes
  grep -B 1 "^[@]_" {{justfile()}}


# Show the differences between this justfile and is last backup
@_just_diff_my_backup:
  # echo "me          -=> {{me}}"
  # echo "home        -=> {{home}}"
  # echo "backup_file -=> {{backup_file}}"
  # echo "my_backup   -=> {{my_backup}}"

  @diff {{me}} {{my_backup}}


# Replace current justfile with most recent backup
@_just_restore_me_from_backup:
  echo
  echo "Do this because I will not ..."
  echo
  echo "cp -f {{my_backup}} {{me}}"
  echo


# Edit the $JUSTPREP_FILENAME_IN file
@_just_edit_me:
  $EDITOR {{me}}
# <<< /Users/dewayne/.justfile

# FIXME: justprep module process still has an issue with ~ and $HOME
# FIXME: justprep does not like more than one space between module name and path.

module_repo := "/Users/dewayne/sandbox/git_repos/repo.just"
module_gem := "/Users/dewayne/sandbox/git_repos/gem.just"
module_version := "/Users/dewayne/just_modules/version.just"
module_git := "/Users/dewayne/just_modules/git.just"


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



# Module repo
@repo what='' args='':
  just -d . -f {{module_repo}} {{what}} {{args}}



# Module gem
@gem what='' args='':
  just -d . -f {{module_gem}} {{what}} {{args}}



# Module version
@version what='' args='':
  just -d . -f {{module_version}} {{what}} {{args}}



# Module git
@git what='' args='':
  just -d . -f {{module_git}} {{what}} {{args}}

