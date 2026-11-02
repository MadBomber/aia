# Roles and Skills

Roles and skills are reusable blocks of instructions that you add to a prompt from the command line. A **role** says *who* the model should be ("a senior security reviewer"). A **skill** says *how* to do something ("our changelog format", "how to write a migration"). Keep them in files, and any prompt can use them.

## Roles

### Creating a role

A role is a Markdown file in the `roles` folder of your prompts directory:

```markdown title="~/.prompts/roles/reviewer.md"
You are a meticulous senior code reviewer.
Report bugs and security problems first, then readability, then style.
Quote the exact line you're commenting on.
```

The role ID is the path inside `roles/` without `.md`. Subfolders work: `~/.prompts/roles/lang/ruby_expert.md` is `lang/ruby_expert`.

### Using a role

```bash
aia --role reviewer code_review lib/payment.rb
aia -r lang/ruby_expert --chat
```

You can also give a path to a role file anywhere on disk. Start it with `/`, `./`, `../` or `~/`:

```bash
aia --role ./project_roles/onboarding_buddy.md explain setup.md
aia --role ~/team/roles/architect explain design.md     # .md is optional
```

!!! warning "Path roles and chat"
    In `--chat` mode AIA currently loads roles only from the roles folder of your prompts directory. A role given as a path is silently ignored in chat, so copy (or symlink) it into `~/.prompts/roles/` first.

What happens to the role depends on the mode:

| Mode | Where the role goes |
|------|---------------------|
| Running a prompt or [pipeline](../prompts/pipelines.md) | Placed in front of **each** prompt's text |
| `--chat` | Added to the **system prompt**, so it applies to every turn |
| `--role` with no prompt ID and no `--chat` | The role file itself is run as the prompt |

### Listing roles

```bash
aia --list-roles
```

prints each role with a table of its front matter (if it has any), so a `description:` in a role's front matter makes the list more useful:

```markdown title="~/.prompts/roles/reviewer.md"
---
description: Strict code reviewer, bugs first
---
You are a meticulous senior code reviewer. ...
```

Files and folders whose names start with `_` are left out of the list, which is a convenient way to hide drafts.

!!! note "Where `--list-roles` looks"
    `--list-roles` reads the prompts directory from the `AIA_PROMPTS__DIR` environment variable, falling back to `~/.prompts`. It doesn't see a directory set only with `--prompts-dir` or in a config file.

### A different role per model

When you run several models at once, each can play its own role. Append `=ROLE` to the model name:

```bash
aia --model gpt-4o=optimist,claude-sonnet-4-5=skeptic --chat
```

AIA checks that each role file exists before starting. If one doesn't, it lists the roles it found. (Like `--list-roles`, this check uses `AIA_PROMPTS__DIR` or `~/.prompts`.) More in [Multiple Models and Consensus](../extending/multi-model.md).

### Changing the roles folder name

The folder is called `roles` by default. To use a different subfolder of your prompts directory, pass `--roles-prefix NAME` or set `prompts.roles_prefix` in the config file.

## Skills

### What a skill looks like

A skill is a **folder** containing a `SKILL.md` file. That's the same layout Claude Code uses for its skills, so you can share skills between the two.

```text
~/.prompts/skills/
├── changelog/
│   └── SKILL.md
└── rails-migrations/
    └── SKILL.md
```

```markdown title="~/.prompts/skills/changelog/SKILL.md"
---
name: changelog
description: Write CHANGELOG entries in our Keep a Changelog style
---
When writing a changelog entry:
- Group changes under Added, Changed, Fixed, Removed.
- One line per change, starting with a verb.
- Link the PR number at the end of the line.
```

The front matter describes the skill for listings. Only the text **after** it is added to your prompt.

### Using skills

```bash
aia --skill changelog release_notes CHANGELOG.md
aia -s changelog,rails-migrations --chat
aia -s changelog -s house-style summarize notes.md      # repeatable
```

You don't have to type the whole name. If there's no folder with exactly that name, AIA uses the first folder (alphabetically) whose name **starts with** what you typed, so `-s rails` finds `rails-migrations`.

A path works too, either to a skill folder or straight to a Markdown file:

```bash
aia -s ./skills/release-checklist --chat
aia -s ~/notes/house_style.md summarize report.txt
```

If a skill can't be found, AIA prints a warning (`Warning: Skill 'x' not found in …`) and carries on without it.

| Mode | Where skills go |
|------|-----------------|
| Running a prompt or pipeline | Appended after **each** prompt's text |
| `--chat` | Added to the **system prompt** |

### Where skills live

AIA looks for skills in `~/.prompts/skills` by default. To use another folder:

```bash
aia --skills-dir ~/.claude/skills -s pdf --chat      # for one run
export AIA_SKILLS__DIR=~/.claude/skills              # for every run
```

or set `skills.dir` in your config file.

### Finding skills

From the command line:

```bash
aia --list-skills
```

lists every skill folder that has a `SKILL.md`, with a table of its front matter.

Inside a chat, `/skills` lists skills with their name and description, and takes search terms that are matched against each skill's front matter (case doesn't matter):

```text
/skills                   # everything
/skills rails             # skills mentioning "rails"
/skills test -rspec       # mentioning "test" but not "rspec"
```

Prefix a term with `-`, `~` or `!` to exclude it. A leading `+` is allowed for terms you want to require.

### Adding a skill partway through a chat

```text
/skill changelog
```

adds that skill's `SKILL.md` to the conversation. Name matching works the same way as `--skill`.

## Roles or skills or prompts?

| Use a… | When the text is… | Example |
|--------|-------------------|---------|
| **Role** | A persona or point of view that suits many tasks | "You are a patient Ruby tutor" |
| **Skill** | Know-how for one kind of task, useful across prompts | "How we write database migrations" |
| **Prompt** | The task itself | "Review this pull request" |
| **[Include](../prompts/directives.md)** | A shared fragment *inside* specific prompt files | A house style guide included by several prompts |

## See also

- [Running Prompts](running-prompts.md): the order in which AIA assembles role, prompt, skills and context
- [Chat Sessions](chat.md)
- [Multiple Models and Consensus](../extending/multi-model.md)
- [Config File](../configuration/config-file.md)
