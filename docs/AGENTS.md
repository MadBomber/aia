### Local Agent Context: docs

## Setup & Commands

- **Build**: Run `bundle exec jekyll build` to generate the static site from Markdown documents and configurations.
- **Serve**: Execute `bundle exec jekyll serve` to start a local server and view the documentation site at `http://localhost:4000`.
- **Lint**: Use `mdl ./docs` to perform style and markdown checks on all documents within the `docs` directory.
- **Link Check**: Ensure all internal links are operational by executing `html-proofer --assume-extension ./_site`.

## Code Style & Patterns

- **YAML Front Matter**: All markdown files must use YAML front matter for metadata (`---` delimiters) as evident in `index.md`.
- **Environment Variables**: Use double underscores (e.g., `AIA_PROMPTS__DIR`) within configuration files as stated in `configuration.md`.
- **Comment Directives**: Use `#{}` for embedding Ruby in documentation, as seen in the Dynamic Configuration section of `advanced-prompting.md`.
- **Directive Prefix**: AIA directives use a single `/` prefix (e.g., `/skill`, `/llms`). Never document them with `//`.

## Implementation Details

- **Primary Index**: Start with `docs/index.md` for the main entry point of the documentation, containing core sections such as key features and quick start.
- **Guide Locations**: Individual guides, such as `guides/basic-usage.md` and `guides/image-generation.md`, offer in-depth tutorials and are referenced from `guides/index.md`.
- **Image Assets**: Store all images in `assets/images/`, referencing them relatively from documents, as used in `index.md` for the `aia.png`.
- **Examples Configuration**: Examples are categorized within `examples/` subdirectories (`mcp`, `prompts`, `tools`) and provide clear usage scenarios.
- **Command Line Reference**: `cli-reference.md` documents every CLI flag. `--list-skills` output is a formatted markdown document: H2 heading per skill ID followed by a two-column YAML front matter table.
- **Directives Reference**: `directives-reference.md` documents all `/`-prefixed chat directives.
  - `/skill <id>`: reads `SKILL.md` from the configured skills directory; errors print to stdout and return nil (not sent to AI).
  - `/skills [terms...]`: prints `skill_id: name\n  description` per skill; supports AND search terms and AND NOT terms with `-`/`~`/`!` prefix.
  - `/llms [terms...]`: lists AI models; supports the same AND/AND NOT search term syntax as `/skills`.
  - Skills directory resolves via: `AIA.config.skills.dir` → `$AIA_PROMPTS__DIR/$AIA_PROMPTS__SKILLS_PREFIX` → `~/.prompts/skills`.
- **Versioning Note**: Document any significant version changes and breaking updates in the `index.md` warnings, following the structure for version change notes.
